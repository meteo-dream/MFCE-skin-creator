extends PanelContainer
class_name FramesStrip

signal frame_selected(index: int)
signal selection_changed(indices: PackedInt32Array)
signal frames_reordered(indices: PackedInt32Array, to: int)
signal add_frames_pressed
signal duplicate_frame_pressed
signal edit_frame_pressed
signal delete_frame_pressed
signal move_frame_left_pressed
signal move_frame_right_pressed
signal reverse_frames_pressed
signal open_in_explorer_pressed
signal thumb_size_changed(size: int)
signal floating_changed(floating: bool)

const THUMB_MIN := 32
const THUMB_MAX := 256
const THUMB_STEP := 8
const DROP_LINE := Color(0.45, 0.68, 1.0, 0.95)
const FLOAT_MIN_WIDTH := 640
const FLOAT_MIN_HEIGHT := 240

enum ItemMenu { OPEN_IN_EXPLORER }

var thumb_size := 64

@onready var list: ItemList = %FrameList
@onready var add_button: Button = %AddFrames
@onready var duplicate_button: Button = %DuplicateFrame
@onready var edit_button: Button = %EditFrame
@onready var delete_button: Button = %DeleteFrame
@onready var move_left_button: Button = %MoveFrameLeft
@onready var move_right_button: Button = %MoveFrameRight
@onready var reverse_button: Button = %ReverseFrames

var _updating := false
var _drop_index := -1
var _primary_index := 0
var _range_anchor := 0
var _edge_layer: Control
var _v_edge: Control
var _h_edge: Control
var _scroll_drag_bar: ScrollBar
var _floating := false
var _split: SplitContainer
var _window: Window
var _float_button: Button
var _docked_split_offset := 0
var _item_menu: PopupMenu


func _ready() -> void:
	mouse_force_pass_scroll_events = false
	list.mouse_force_pass_scroll_events = false
	list.select_mode = ItemList.SELECT_MULTI
	list.allow_reselect = true
	list.multi_selected.connect(_on_multi_selected)
	list.item_clicked.connect(_on_item_clicked)
	list.empty_clicked.connect(_on_empty_clicked)
	list.item_activated.connect(_on_item_activated)
	list.gui_input.connect(_on_list_gui_input)
	list.draw.connect(_on_list_draw)
	list.set_drag_forwarding(_on_get_drag_data, _on_can_drop_data, _on_drop_data)
	add_button.pressed.connect(func(): add_frames_pressed.emit())
	duplicate_button.pressed.connect(func(): duplicate_frame_pressed.emit())
	edit_button.pressed.connect(func(): edit_frame_pressed.emit())
	delete_button.pressed.connect(func(): delete_frame_pressed.emit())
	move_left_button.pressed.connect(func(): move_frame_left_pressed.emit())
	move_right_button.pressed.connect(func(): move_frame_right_pressed.emit())
	reverse_button.pressed.connect(func(): reverse_frames_pressed.emit())
	_setup_item_menu()
	_setup_scroll_edges()
	_split = get_parent() as SplitContainer
	_window = %FramesWindow
	_float_button = $VBox/FrameHSplitter/FramesSide/Toolbar/FloatButton
	_float_button.pressed.connect(toggle_floating)
	_window.close_requested.connect(_on_window_close)
	_update_float_button()


func set_enabled(enabled: bool) -> void:
	add_button.disabled = !enabled
	edit_button.disabled = !enabled
	list.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if _v_edge:
		_v_edge.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if _h_edge:
		_h_edge.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	_update_frame_edit_buttons()


func set_thumb_size(thumb_px: int) -> void:
	var next := clampi(thumb_px, THUMB_MIN, THUMB_MAX)
	if next == thumb_size && list.fixed_icon_size.x == next:
		return
	thumb_size = next
	list.fixed_icon_size = Vector2i(thumb_size, thumb_size)
	list.fixed_column_width = thumb_size + 32
	list.force_update_list_size()
	thumb_size_changed.emit(thumb_size)


func is_floating() -> bool:
	return _floating


func get_docked_split_offset() -> int:
	if !_floating && _split:
		return _read_split_offset(_split)
	return _docked_split_offset


func set_docked_split_offset(offset: int) -> void:
	_docked_split_offset = offset
	if !_floating && _split:
		_apply_split_offset(_split, offset)


func _apply_split_offset(split: SplitContainer, offset: int) -> void:
	split.split_offsets = PackedInt32Array([offset])


func _read_split_offset(split: SplitContainer) -> int:
	var offsets := split.split_offsets
	if offsets.is_empty():
		return split.split_offset
	return offsets[0]


func toggle_floating() -> void:
	set_floating(!_floating)


func set_floating(floating: bool, emit_change: bool = true) -> void:
	if floating == _floating:
		return
	var origin := Vector2i(get_global_rect().position)
	var sz := size
	if floating:
		_undock()
		Util.fit_window_scale(_window, 480, 200)
		var s := Util.editor_scale()
		_window.size = Vector2i(
			maxi(roundi(sz.x * s), roundi(FLOAT_MIN_WIDTH * s)),
			maxi(roundi(sz.y * s), roundi(FLOAT_MIN_HEIGHT * s))
		)
		if origin == Vector2i.ZERO:
			_window.popup_centered()
		else:
			_window.position = Util.logical_to_screen(origin)
			_window.show()
		Util.clamp_window_to_screen(_window)
	else:
		_redock()
		visible = true
	_update_float_button()
	if emit_change:
		floating_changed.emit(_floating)


func apply_window_rect(rect: Rect2i) -> void:
	Util.fit_window_scale(_window, 480, 200)
	if rect.size.x < _window.min_size.x || rect.size.y < _window.min_size.y:
		rect.size = Vector2i(
			maxi(rect.size.x, _window.min_size.x),
			maxi(rect.size.y, _window.min_size.y)
		)
	_window.position = rect.position
	_window.size = rect.size
	Util.clamp_window_to_screen(_window)


func get_window_rect() -> Rect2i:
	return Rect2i(_window.position, _window.size)


func _undock() -> void:
	if _split:
		_docked_split_offset = _read_split_offset(_split)
	var parent := get_parent()
	if parent:
		parent.remove_child(self)
	_window.add_child(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	visible = true
	_floating = true


func _redock() -> void:
	_window.hide()
	if get_parent() == _window:
		_window.remove_child(self)
		if _split:
			_split.add_child(self)
			_apply_split_offset(_split, _docked_split_offset)
	_floating = false
	size_flags_horizontal = Control.SIZE_FILL
	size_flags_vertical = Control.SIZE_FILL
	custom_minimum_size = Vector2(0, 200)
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0


func _on_window_close() -> void:
	set_floating(false)


func _update_float_button() -> void:
	if !_float_button:
		return
	if _floating:
		_float_button.tooltip_text = "Dock"
	else:
		_float_button.tooltip_text = "Make Floating"


func get_selected_indices() -> PackedInt32Array:
	return list.get_selected_items()


func rebuild(sprite_frames: SpriteFrames, anim: StringName, selected: int, keep_selected: PackedInt32Array = PackedInt32Array()) -> void:
	_updating = true
	list.clear()
	if !sprite_frames || !sprite_frames.has_animation(anim):
		_updating = false
		_update_frame_edit_buttons()
		return
	var count := sprite_frames.get_frame_count(anim)
	for i in count:
		var tex: Texture2D = sprite_frames.get_frame_texture(anim, i)
		var icon: Texture2D = tex
		if tex is AtlasTexture:
			icon = tex.duplicate()
		var duration := sprite_frames.get_frame_duration(anim, i)
		list.add_item(_item_text(i, duration), icon)
	if count > 0:
		var to_select := PackedInt32Array()
		for i in keep_selected:
			if i >= 0 && i < count:
				to_select.append(i)
		if to_select.is_empty():
			to_select.append(clampi(selected, 0, count - 1))
		for i in to_select.size():
			list.select(to_select[i], i == 0)
		_primary_index = clampi(selected, 0, count - 1)
		_range_anchor = _primary_index
		if list.is_selected(_primary_index):
			list.select(_primary_index, false)
		list.ensure_current_is_visible()
	_update_frame_edit_buttons()
	_updating = false


func select_frame(index: int, collapse_multi := false) -> void:
	if _updating:
		return
	if index < 0 || index >= list.item_count:
		return
	if !collapse_multi && list.is_selected(index):
		_primary_index = index
		return
	var items := list.get_selected_items()
	if items.size() == 1 && items[0] == index:
		_primary_index = index
		if collapse_multi:
			list.ensure_current_is_visible()
		return
	_updating = true
	list.select(index)
	_primary_index = index
	_range_anchor = index
	list.ensure_current_is_visible()
	_update_frame_edit_buttons()
	_updating = false


func select_indices(indices: PackedInt32Array, primary: int = -1) -> void:
	if _updating:
		return
	_updating = true
	var first := true
	for i in indices:
		if i < 0 || i >= list.item_count:
			continue
		list.select(i, first)
		first = false
	if first && primary >= 0 && primary < list.item_count:
		list.select(primary)
		_primary_index = primary
	elif primary >= 0 && primary < list.item_count && list.is_selected(primary):
		list.select(primary, false)
		_primary_index = primary
	_range_anchor = _primary_index
	list.ensure_current_is_visible()
	_update_frame_edit_buttons()
	_updating = false


func update_item_text(index: int, duration: float) -> void:
	if index < 0 || index >= list.item_count:
		return
	list.set_item_text(index, _item_text(index, duration))


func update_frame(index: int, sprite_frames: SpriteFrames, anim: StringName) -> void:
	if index < 0 || index >= list.item_count:
		return
	if !sprite_frames || !sprite_frames.has_animation(anim):
		return
	var tex: Texture2D = sprite_frames.get_frame_texture(anim, index)
	var icon: Texture2D = tex
	if tex is AtlasTexture:
		icon = tex.duplicate()
	list.set_item_icon(index, icon)
	list.set_item_text(index, _item_text(index, sprite_frames.get_frame_duration(anim, index)))


func _item_text(index: int, duration: float) -> String:
	if is_equal_approx(duration, 1.0):
		return str(index)
	return "%d [× %.2f]" % [index, duration]


func _update_frame_edit_buttons() -> void:
	var idle := add_button.disabled || list.item_count <= 0
	duplicate_button.disabled = idle
	var selected := list.get_selected_items()
	if selected.is_empty() && _primary_index >= 0 && _primary_index < list.item_count:
		selected = PackedInt32Array([_primary_index])
	var min_i := 0
	var max_i := 0
	if !selected.is_empty():
		min_i = selected[0]
		max_i = selected[0]
		for i in selected:
			min_i = mini(min_i, i)
			max_i = maxi(max_i, i)
	delete_button.disabled = idle || list.item_count <= 1
	move_left_button.disabled = idle || selected.is_empty() || min_i <= 0
	move_right_button.disabled = idle || selected.is_empty() || max_i >= list.item_count - 1
	reverse_button.disabled = idle || selected.size() < 2


func _emit_selection(primary: int) -> void:
	if primary >= 0 && primary < list.item_count && list.is_selected(primary):
		_primary_index = primary
		frame_selected.emit(primary)
	else:
		var items := list.get_selected_items()
		if items.is_empty():
			return
		_primary_index = items[items.size() - 1]
		frame_selected.emit(_primary_index)
	selection_changed.emit(list.get_selected_items())


func _on_empty_clicked(_at_position: Vector2, mouse_button_index: int) -> void:
	if _updating || mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	var items := list.get_selected_items()
	if items.size() <= 1:
		return
	var keep := _primary_index
	if keep < 0 || keep >= list.item_count || !list.is_selected(keep):
		keep = items[0]
	_updating = true
	list.select(keep)
	_primary_index = keep
	_range_anchor = keep
	_updating = false
	_update_frame_edit_buttons()
	selection_changed.emit(list.get_selected_items())


func _on_multi_selected(_index: int, _selected: bool) -> void:
	if _updating:
		return
	_update_frame_edit_buttons()
	selection_changed.emit(list.get_selected_items())


func _on_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if _updating:
		return
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		if add_button.disabled:
			return
		if !list.is_selected(index):
			_updating = true
			list.select(index)
			_updating = false
			_range_anchor = index
			_emit_selection(index)
		_popup_item_menu()
		return
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	if !Input.is_key_pressed(KEY_SHIFT) && !Input.is_key_pressed(KEY_CTRL) && !Input.is_key_pressed(KEY_META):
		_range_anchor = index
	_emit_selection(index)


func _setup_item_menu() -> void:
	_item_menu = PopupMenu.new()
	_item_menu.add_item("Open in File Explorer", ItemMenu.OPEN_IN_EXPLORER)
	add_child(_item_menu)
	_item_menu.id_pressed.connect(_on_item_menu_id_pressed)


func _popup_item_menu() -> void:
	if !_item_menu:
		return
	Util.fit_window_scale(_item_menu, 180, 32)
	_item_menu.reset_size()
	_item_menu.position = DisplayServer.mouse_get_position()
	_item_menu.popup()


func _on_item_menu_id_pressed(id: int) -> void:
	match id:
		ItemMenu.OPEN_IN_EXPLORER:
			open_in_explorer_pressed.emit()


func _on_item_activated(_index: int) -> void:
	edit_frame_pressed.emit()


func _on_list_gui_input(event: InputEvent) -> void:
	if _handle_thumb_scroll(event):
		list.accept_event()
		return
	if event is InputEventMouse && _exact_item_at(event.position) < 0:
		# ItemList expands the last column into empty space and the scrollbar inset.
		event.position = Vector2(-1e6, -1e6)
	if add_button.disabled || !(event is InputEventKey) || !event.pressed:
		return
	var key := event as InputEventKey
	if _navigate_from_key(key):
		list.accept_event()
		return
	if key.echo:
		return
	if key.keycode == KEY_A && key.is_command_or_control_pressed():
		_select_all()
		list.accept_event()


func _handle_thumb_scroll(event: InputEvent) -> bool:
	if !(event is InputEventMouseButton) || !event.pressed:
		return false
	if !event.is_command_or_control_pressed():
		return false
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		set_thumb_size(thumb_size + THUMB_STEP)
		return true
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		set_thumb_size(thumb_size - THUMB_STEP)
		return true
	return false


func _select_all() -> void:
	if list.item_count <= 0:
		return
	_updating = true
	for i in list.item_count:
		list.select(i, i == 0)
	_range_anchor = 0
	_updating = false
	_update_frame_edit_buttons()
	_emit_selection(0)


func _navigate_from_key(key: InputEventKey) -> bool:
	if key.alt_pressed || key.is_command_or_control_pressed():
		return false
	var count := list.item_count
	if count <= 0:
		return false
	var cols := _visible_column_count()
	var next := _primary_index
	match key.keycode:
		KEY_LEFT:
			next = _primary_index - 1
		KEY_RIGHT:
			next = _primary_index + 1
		KEY_UP:
			if _primary_index < cols:
				return true
			next = _primary_index - cols
		KEY_DOWN:
			if _primary_index + cols >= count:
				return true
			next = _primary_index + cols
		KEY_PAGEUP:
			next = _primary_index - cols * 4
		KEY_PAGEDOWN:
			next = _primary_index + cols * 4
		KEY_HOME:
			next = 0
		KEY_END:
			next = count - 1
		_:
			return false
	next = clampi(next, 0, count - 1)
	_select_keyboard_index(next, key.shift_pressed)
	return true


func _visible_column_count() -> int:
	if list.item_count <= 1:
		return 1
	var y := list.get_item_rect(0, false).position.y
	var cols := 1
	for i in range(1, list.item_count):
		if !is_equal_approx(list.get_item_rect(i, false).position.y, y):
			break
		cols += 1
	return maxi(cols, 1)


func _select_keyboard_index(next: int, extend: bool) -> void:
	_updating = true
	if extend:
		if _range_anchor < 0 || _range_anchor >= list.item_count:
			_range_anchor = _primary_index
		list.select(next, true)
		var a := mini(_range_anchor, next)
		var b := maxi(_range_anchor, next)
		for i in range(a, b + 1):
			list.select(i, false)
	else:
		_range_anchor = next
		list.select(next, true)
	_primary_index = next
	list.ensure_current_is_visible()
	_updating = false
	_update_frame_edit_buttons()
	_emit_selection(next)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_drop_index(-1)
	elif what == NOTIFICATION_RESIZED || what == NOTIFICATION_SORT_CHILDREN:
		_layout_scroll_edges()


func _exact_item_at(local_pos: Vector2) -> int:
	if list.item_count <= 0:
		return -1
	var scroll := Vector2(list.get_h_scroll_bar().value, list.get_v_scroll_bar().value)
	for i in list.item_count:
		var rect := list.get_item_rect(i, false)
		rect.position -= scroll
		if rect.has_point(local_pos):
			return i
	return -1


func _setup_scroll_edges() -> void:
	_edge_layer = Control.new()
	_edge_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_edge_layer)
	_v_edge = _make_scroll_edge(_on_v_edge_gui_input)
	_h_edge = _make_scroll_edge(_on_h_edge_gui_input)
	_edge_layer.add_child(_v_edge)
	_edge_layer.add_child(_h_edge)
	var vbar := list.get_v_scroll_bar()
	var hbar := list.get_h_scroll_bar()
	if vbar:
		vbar.visibility_changed.connect(_layout_scroll_edges)
	if hbar:
		hbar.visibility_changed.connect(_layout_scroll_edges)


func _make_scroll_edge(handler: Callable) -> Control:
	var edge := Control.new()
	edge.mouse_filter = Control.MOUSE_FILTER_STOP
	edge.gui_input.connect(handler)
	edge.visible = false
	return edge


func _layout_scroll_edges() -> void:
	if !_edge_layer || !_v_edge || !_h_edge:
		return
	var vbar := list.get_v_scroll_bar()
	var hbar := list.get_h_scroll_bar()
	_place_scroll_edge(_v_edge, vbar, true)
	_place_scroll_edge(_h_edge, hbar, false)


func _place_scroll_edge(edge: Control, bar: ScrollBar, vertical: bool) -> void:
	if !bar || !bar.visible || add_button.disabled:
		edge.visible = false
		edge.size = Vector2.ZERO
		return
	var bar_g := bar.get_global_rect()
	var layer_g := _edge_layer.get_global_rect()
	if vertical:
		var gap := layer_g.end.x - bar_g.end.x
		if gap <= 0.5:
			edge.visible = false
			edge.size = Vector2.ZERO
			return
		edge.position = Vector2(bar_g.end.x, bar_g.position.y) - _edge_layer.global_position
		edge.size = Vector2(gap, bar_g.size.y)
	else:
		var gap := layer_g.end.y - bar_g.end.y
		if gap <= 0.5:
			edge.visible = false
			edge.size = Vector2.ZERO
			return
		edge.position = Vector2(bar_g.position.x, bar_g.end.y) - _edge_layer.global_position
		edge.size = Vector2(bar_g.size.x, gap)
	edge.visible = true


func _on_v_edge_gui_input(event: InputEvent) -> void:
	_on_scroll_edge_gui_input(list.get_v_scroll_bar(), event)


func _on_h_edge_gui_input(event: InputEvent) -> void:
	_on_scroll_edge_gui_input(list.get_h_scroll_bar(), event)


func _on_scroll_edge_gui_input(bar: ScrollBar, event: InputEvent) -> void:
	if !bar || !bar.visible:
		return
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_scroll_drag_bar = bar
			_apply_bar_from_mouse(bar)
		else:
			_scroll_drag_bar = null
		accept_event()
	elif event is InputEventMouseMotion && _scroll_drag_bar == bar:
		_apply_bar_from_mouse(bar)
		accept_event()
	elif event is InputEventMouseButton && (
		event.button_index == MOUSE_BUTTON_WHEEL_UP || event.button_index == MOUSE_BUTTON_WHEEL_DOWN
	):
		var step := bar.page / 8.0 if bar.page > 0.0 else 1.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			bar.value -= step
		else:
			bar.value += step
		accept_event()


func _apply_bar_from_mouse(bar: ScrollBar) -> void:
	var local := bar.get_local_mouse_position()
	var span := maxf(bar.size.x if bar is HScrollBar else bar.size.y, 1.0)
	var t := clampf((local.x if bar is HScrollBar else local.y) / span, 0.0, 1.0)
	var travel := maxf(bar.max_value - bar.min_value - bar.page, 0.0)
	bar.value = bar.min_value + travel * t


func _input(event: InputEvent) -> void:
	if _scroll_drag_bar == null:
		return
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && !event.pressed:
		_scroll_drag_bar = null
		return
	if event is InputEventMouseMotion:
		_apply_bar_from_mouse(_scroll_drag_bar)
		get_viewport().set_input_as_handled()


func _on_get_drag_data(at_position: Vector2) -> Variant:
	if add_button.disabled || list.item_count <= 1:
		return null
	var idx := _exact_item_at(at_position)
	if idx < 0:
		return null
	if !list.is_selected(idx):
		_updating = true
		list.select(idx)
		_updating = false
		frame_selected.emit(idx)
		selection_changed.emit(list.get_selected_items())
	var indices := list.get_selected_items()
	if indices.is_empty():
		indices = PackedInt32Array([idx])
	list.set_drag_preview(_make_drag_preview(idx, indices.size()))
	return { "type": "frames_strip_frame", "index": idx, "indices": indices }


func _make_drag_preview(idx: int, count: int) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(thumb_size, thumb_size)
	root.size = Vector2(thumb_size, thumb_size)
	var preview := TextureRect.new()
	preview.texture = list.get_item_icon(idx)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.modulate = Color(1, 1, 1, 0.85)
	root.add_child(preview)
	if count > 1:
		var badge := Label.new()
		badge.text = str(count)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		badge.offset_right = -4
		badge.offset_bottom = -2
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 4)
		root.add_child(badge)
	return root


func _on_can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if !_is_frame_drag(data):
		_set_drop_index(-1)
		return false
	_set_drop_index(_get_insert_index(at_position))
	return true


func _on_drop_data(at_position: Vector2, data: Variant) -> void:
	if !_is_frame_drag(data):
		_set_drop_index(-1)
		return
	var indices := _drag_indices(data)
	var to := _get_insert_index(at_position)
	_set_drop_index(-1)
	if indices.is_empty():
		return
	if _is_noop_reorder(indices, to):
		return
	frames_reordered.emit(indices, to)


func _drag_indices(data: Dictionary) -> PackedInt32Array:
	if data.has("indices"):
		return PackedInt32Array(data["indices"])
	return PackedInt32Array([int(data.get("index", -1))])


func _is_noop_reorder(indices: PackedInt32Array, to: int) -> bool:
	var moving: Array[int] = []
	for i in indices:
		if i >= 0 && i < list.item_count:
			moving.append(i)
	moving.sort()
	if moving.is_empty():
		return true
	var removed_before := 0
	for i in moving:
		if i < to:
			removed_before += 1
	var new_insert := to - removed_before
	for j in moving.size():
		if moving[j] != new_insert + j:
			return false
	return true


func _is_frame_drag(data: Variant) -> bool:
	return data is Dictionary && data.get("type") == "frames_strip_frame"


func _get_insert_index(at_position: Vector2) -> int:
	if list.item_count <= 0:
		return 0
	var idx := _exact_item_at(at_position)
	if idx < 0:
		idx = list.get_item_at_position(at_position, false)
		if idx < 0:
			return list.item_count
	var rect := list.get_item_rect(idx, false)
	var pos := at_position + Vector2(list.get_h_scroll_bar().value, list.get_v_scroll_bar().value)
	if pos.x >= rect.position.x + rect.size.x * 0.5:
		return idx + 1
	return idx


func _set_drop_index(index: int) -> void:
	if _drop_index == index:
		return
	_drop_index = index
	list.queue_redraw()


func _on_list_draw() -> void:
	_layout_scroll_edges()
	if _drop_index < 0 || list.item_count <= 0:
		return
	var scroll := Vector2(list.get_h_scroll_bar().value, list.get_v_scroll_bar().value)
	var x: float
	var top: float
	var bottom: float
	if _drop_index >= list.item_count:
		var rect := list.get_item_rect(list.item_count - 1, false)
		rect.position -= scroll
		x = rect.position.x + rect.size.x
		top = rect.position.y
		bottom = rect.position.y + rect.size.y
	else:
		var rect := list.get_item_rect(_drop_index, false)
		rect.position -= scroll
		x = rect.position.x
		top = rect.position.y
		bottom = rect.position.y + rect.size.y
	list.draw_line(Vector2(x, top + 2.0), Vector2(x, bottom - 2.0), DROP_LINE, 3.0)
