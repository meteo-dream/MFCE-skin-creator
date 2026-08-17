extends ConfirmationDialog
class_name AddFramesDialog

signal frames_chosen(rects: Array[Rect2], atlas: Texture2D)

enum DominantParam { FRAME_COUNT, SIZE }
enum InsertMode { END, BEGINNING, AFTER_SELECTED }

static var session_insert_mode: InsertMode = InsertMode.END

@onready var preview: SheetPreview = %SheetPreview
@onready var scroll: ScrollContainer = %SheetScroll
@onready var zoom_label: Label = %ZoomLabel
@onready var spin_h: SpinBox = %SpinH
@onready var spin_v: SpinBox = %SpinV
@onready var spin_size_x: SpinBox = %SpinSizeX
@onready var spin_size_y: SpinBox = %SpinSizeY
@onready var spin_sep_x: SpinBox = %SpinSepX
@onready var spin_sep_y: SpinBox = %SpinSepY
@onready var spin_off_x: SpinBox = %SpinOffX
@onready var spin_off_y: SpinBox = %SpinOffY
@onready var insert_mode_option: OptionButton = %InsertMode

var _updating := false
var _dominant: DominantParam = DominantParam.FRAME_COUNT
var _frames_selected: Dictionary = {} ## sheet index -> selection order
var _selected_count := 0
var _last_frame_selected := -1
var _toggled_this_drag: Dictionary = {}
var _last_tex_size := Vector2i.ZERO


func _ready() -> void:
	exclusive = true
	transient = true
	unresizable = false
	ok_button_text = "Add Frames"
	title = "Select Frames"
	confirmed.connect(_on_confirmed)
	preview.draw.connect(_on_preview_draw)
	preview.gui_input.connect(_on_preview_input)
	preview.zoom_changed.connect(_on_zoom_changed)
	scroll.gui_input.connect(_on_scroll_input)
	get_ok_button().disabled = true
	var content: Control = $HBox
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(880, 520)
	insert_mode_option.clear()
	insert_mode_option.add_item("Add at End", InsertMode.END)
	insert_mode_option.add_item("Add at Beginning", InsertMode.BEGINNING)
	insert_mode_option.add_item("Add After Selected Frame", InsertMode.AFTER_SELECTED)
	insert_mode_option.select(int(session_insert_mode))
	_fit_zoom_bar()


func setup(atlas: Texture2D) -> void:
	if !atlas:
		return
	preview.set_sheet_texture(atlas)
	var tex_size := Vector2i(atlas.get_size())
	var keep_settings := tex_size == _last_tex_size && _last_tex_size != Vector2i.ZERO
	_last_tex_size = tex_size
	_clear_selection()
	_updating = true
	if !keep_settings:
		spin_h.min_value = 1
		spin_v.min_value = 1
		spin_h.max_value = 128
		spin_v.max_value = 128
		spin_h.value = 4
		spin_v.value = 4
		spin_sep_x.value = 0
		spin_sep_y.value = 0
		spin_off_x.value = 0
		spin_off_y.value = 0
		_dominant = DominantParam.FRAME_COUNT
	_updating = false
	_sheet_spin_changed(_dominant)
	preview.zoom_reset()
	_update_ok_button()
	insert_mode_option.select(int(session_insert_mode))
	if !visibility_changed.is_connected(_on_visibility_changed_fit):
		visibility_changed.connect(_on_visibility_changed_fit)


func _fit_zoom_bar() -> void:
	var zoom_bar: Control = scroll.get_parent().get_node("ZoomBar")
	zoom_bar.reset_size()
	zoom_bar.size = zoom_bar.get_combined_minimum_size()


func _input(event: InputEvent) -> void:
	if !visible:
		return
	var panel := scroll.get_parent() as Control
	if !panel.get_global_rect().has_point(panel.get_global_mouse_position()):
		return
	if preview.handle_zoom_event(event):
		get_viewport().set_input_as_handled()


func _on_insert_mode_selected(index: int) -> void:
	session_insert_mode = index


func get_insert_mode() -> InsertMode:
	return session_insert_mode


func _on_visibility_changed_fit() -> void:
	if visible:
		await get_tree().process_frame
		preview.zoom_fit()


func _get_frame_count() -> Vector2i:
	return Vector2i(int(spin_h.value), int(spin_v.value))


func _get_frame_size() -> Vector2i:
	return Vector2i(maxi(int(spin_size_x.value), 1), maxi(int(spin_size_y.value), 1))


func _get_offset() -> Vector2i:
	return Vector2i(int(spin_off_x.value), int(spin_off_y.value))


func _get_separation() -> Vector2i:
	return Vector2i(int(spin_sep_x.value), int(spin_sep_y.value))


func _sheet_spin_changed(param: DominantParam) -> void:
	if _updating || !preview.texture:
		return
	_updating = true
	_dominant = param
	var texture_size := Vector2i(preview.texture.get_size())
	var size := texture_size - _get_offset()
	size.x = maxi(size.x, 1)
	size.y = maxi(size.y, 1)
	match _dominant:
		DominantParam.SIZE:
			var frame_size := _get_frame_size()
			var offset_max := texture_size - frame_size
			spin_off_x.max_value = maxi(offset_max.x, 0)
			spin_off_y.max_value = maxi(offset_max.y, 0)
			var sep_max := size - frame_size * 2
			spin_sep_x.max_value = maxi(sep_max.x, 0)
			spin_sep_y.max_value = maxi(sep_max.y, 0)
			var separation := _get_separation()
			var denom := frame_size + separation
			denom.x = maxi(denom.x, 1)
			denom.y = maxi(denom.y, 1)
			var count := (size + separation) / denom
			spin_h.value = maxi(count.x, 1)
			spin_v.value = maxi(count.y, 1)
		DominantParam.FRAME_COUNT:
			var count := _get_frame_count()
			var offset_max := texture_size - count
			spin_off_x.max_value = maxi(offset_max.x, 0)
			spin_off_y.max_value = maxi(offset_max.y, 0)
			var gap_count := count - Vector2i.ONE
			if gap_count.x == 0:
				spin_sep_x.max_value = maxi(size.x, 0)
			else:
				spin_sep_x.max_value = maxi((size.x - count.x) / gap_count.x, 0)
			if gap_count.y == 0:
				spin_sep_y.max_value = maxi(size.y, 0)
			else:
				spin_sep_y.max_value = maxi((size.y - count.y) / gap_count.y, 0)
			var separation := _get_separation()
			var frame_size := (size - separation * gap_count) / count
			spin_size_x.value = maxi(frame_size.x, 1)
			spin_size_y.value = maxi(frame_size.y, 1)
	_updating = false
	_clear_selection()
	preview.queue_redraw()


func _on_h_changed(_value: float) -> void:
	_sheet_spin_changed(DominantParam.FRAME_COUNT)


func _on_v_changed(_value: float) -> void:
	_sheet_spin_changed(DominantParam.FRAME_COUNT)


func _on_size_x_changed(_value: float) -> void:
	_sheet_spin_changed(DominantParam.SIZE)


func _on_size_y_changed(_value: float) -> void:
	_sheet_spin_changed(DominantParam.SIZE)


func _on_sep_or_off_changed(_value: float) -> void:
	_sheet_spin_changed(_dominant)


func _clear_selection() -> void:
	_frames_selected.clear()
	_selected_count = 0
	_last_frame_selected = -1
	_toggled_this_drag.clear()
	_update_ok_button()


func _ordered_indices() -> Array[int]:
	var pairs: Array = []
	for idx in _frames_selected:
		pairs.append([_frames_selected[idx], int(idx)])
	pairs.sort_custom(func(a, b): return a[0] < b[0])
	var result: Array[int] = []
	for pair in pairs:
		result.append(pair[1])
	return result


func _position_to_frame_index(local_pos: Vector2) -> int:
	var offset := _get_offset()
	var frame_size := _get_frame_size()
	var separation := _get_separation()
	var block_size := frame_size + separation
	if block_size.x <= 0 || block_size.y <= 0:
		return -1
	var position := Vector2i(preview.local_to_sheet(local_pos)) - offset
	if position.x < 0 || position.y < 0:
		return -1
	if position.x % block_size.x >= frame_size.x || position.y % block_size.y >= frame_size.y:
		return -1
	var frame := position / block_size
	var frame_count := _get_frame_count()
	if frame.x >= frame_count.x || frame.y >= frame_count.y:
		return -1
	return frame_count.x * frame.y + frame.x


func _toggle_frame(idx: int) -> void:
	if _frames_selected.has(idx):
		_frames_selected.erase(idx)
	else:
		_frames_selected[idx] = _selected_count
		_selected_count += 1
	if _frames_selected.is_empty():
		_selected_count = 0


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton && event.pressed && event.button_index == MOUSE_BUTTON_LEFT:
		var idx := _position_to_frame_index(event.position)
		if idx != -1:
			if event.shift_pressed && _last_frame_selected >= 0:
				var from := _last_frame_selected
				var to := idx
				var diff := absi(to - from)
				var dir := signi(to - from)
				for i in diff + 1:
					var this_idx := from + i * dir
					_toggled_this_drag[this_idx] = true
					if event.ctrl_pressed:
						_frames_selected.erase(this_idx)
					elif !_frames_selected.has(this_idx):
						_frames_selected[this_idx] = _selected_count
						_selected_count += 1
			else:
				_toggled_this_drag[idx] = true
				_toggle_frame(idx)
		if _last_frame_selected != idx || idx != -1:
			_last_frame_selected = idx
			preview.queue_redraw()
			_update_ok_button()
	elif event is InputEventMouseButton && !event.pressed && event.button_index == MOUSE_BUTTON_LEFT:
		_toggled_this_drag.clear()
	elif event is InputEventMouseMotion && event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var idx := _position_to_frame_index(event.position)
		if idx != -1 && !_toggled_this_drag.has(idx):
			_toggled_this_drag[idx] = true
			_toggle_frame(idx)
			_last_frame_selected = idx
			preview.queue_redraw()
			_update_ok_button()
	if _frames_selected.is_empty():
		_selected_count = 0


func _on_scroll_input(event: InputEvent) -> void:
	if preview.handle_zoom_event(event):
		scroll.accept_event()


func _on_zoom_changed(zoom: float) -> void:
	zoom_label.text = "%d %%" % int(round(zoom * 100.0))


func _on_zoom_out_pressed() -> void:
	preview.zoom_out()


func _on_zoom_in_pressed() -> void:
	preview.zoom_in()


func _on_zoom_fit_pressed() -> void:
	preview.zoom_fit()


func _on_select_all_pressed() -> void:
	var count := _get_frame_count()
	var total := count.x * count.y
	for i in total:
		if !_frames_selected.has(i):
			_frames_selected[i] = _selected_count
			_selected_count += 1
	preview.queue_redraw()
	_update_ok_button()


func _on_select_none_pressed() -> void:
	_clear_selection()
	preview.queue_redraw()


func _update_ok_button() -> void:
	var ok := get_ok_button()
	if !ok:
		return
	if _frames_selected.is_empty():
		ok.disabled = true
		ok_button_text = "No Frames Selected"
	else:
		ok.disabled = false
		var n := _frames_selected.size()
		ok_button_text = "Add %d Frame(s)" % n if n != 1 else "Add 1 Frame"


func _draw_shadowed_line(from: Vector2, to: Vector2) -> void:
	preview.draw_line(from + Vector2.ONE, to + Vector2.ONE, Color(0, 0, 0, 0.3), 1.0)
	preview.draw_line(from, to, Color(1, 1, 1, 0.3), 1.0)


func _on_preview_draw() -> void:
	if !preview.texture:
		return
	var frame_count := _get_frame_count()
	var separation := _get_separation()
	var draw_offset := Vector2(_get_offset()) * preview.sheet_zoom
	var draw_sep := Vector2(separation) * preview.sheet_zoom
	var draw_frame_size := Vector2(_get_frame_size()) * preview.sheet_zoom
	var draw_size := draw_frame_size * Vector2(frame_count) + draw_sep * Vector2(frame_count - Vector2i.ONE)
	_draw_shadowed_line(draw_offset, draw_offset + Vector2(0, draw_size.y))
	for i in frame_count.x - 1:
		var start := draw_offset + Vector2(i * draw_sep.x + (i + 1) * draw_frame_size.x, 0)
		if separation.x == 0:
			_draw_shadowed_line(start, start + Vector2(0, draw_size.y))
		else:
			preview.draw_rect(Rect2(start, Vector2(draw_sep.x, draw_size.y)), Color(1, 1, 1, 0.3))
	_draw_shadowed_line(draw_offset + Vector2(draw_size.x, 0), draw_offset + Vector2(draw_size.x, draw_size.y))
	_draw_shadowed_line(draw_offset, draw_offset + Vector2(draw_size.x, 0))
	for i in frame_count.y - 1:
		var start := draw_offset + Vector2(0, i * draw_sep.y + (i + 1) * draw_frame_size.y)
		if separation.y == 0:
			_draw_shadowed_line(start, start + Vector2(draw_size.x, 0))
		else:
			preview.draw_rect(Rect2(start, Vector2(draw_size.x, draw_sep.y)), Color(1, 1, 1, 0.3))
	_draw_shadowed_line(draw_offset + Vector2(0, draw_size.y), draw_offset + Vector2(draw_size.x, draw_size.y))
	var ordered := _ordered_indices()
	var font := preview.get_theme_font(&"font")
	var font_size := preview.get_theme_font_size(&"font_size")
	var accent := Color(0.44, 0.73, 0.98)
	for i in ordered.size():
		var idx: int = ordered[i]
		var x := idx % frame_count.x
		var y := idx / frame_count.x
		var pos := draw_offset + Vector2(x, y) * (draw_frame_size + draw_sep)
		preview.draw_rect(Rect2(pos + Vector2(5, 5), draw_frame_size - Vector2(10, 10)), Color(0, 0, 0, 0.35))
		preview.draw_rect(Rect2(pos, draw_frame_size), Color.BLACK, false, 2.0)
		preview.draw_rect(Rect2(pos + Vector2(2, 2), draw_frame_size - Vector2(4, 4)), accent, false, 2.0)
		var text := str(i)
		var string_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if string_size.x + 6 < draw_frame_size.x && string_size.y / 2 + 10 < draw_frame_size.y:
			preview.draw_string_outline(font, pos + Vector2(5, 7 + string_size.y / 2), text, HORIZONTAL_ALIGNMENT_LEFT, string_size.x, font_size, 1, Color.BLACK)
			preview.draw_string(font, pos + Vector2(5, 7 + string_size.y / 2), text, HORIZONTAL_ALIGNMENT_LEFT, string_size.x, font_size, Color.WHITE)


func _on_confirmed() -> void:
	if !preview.texture || _frames_selected.is_empty():
		return
	var frame_count := _get_frame_count()
	var frame_size := _get_frame_size()
	var offset := _get_offset()
	var separation := _get_separation()
	var rects: Array[Rect2] = []
	for idx in _ordered_indices():
		var coords := Vector2(idx % frame_count.x, idx / frame_count.x)
		rects.append(Rect2(Vector2(offset) + coords * Vector2(frame_size + separation), Vector2(frame_size)))
	frames_chosen.emit(rects, preview.texture)
