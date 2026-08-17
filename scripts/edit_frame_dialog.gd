extends ConfirmationDialog
class_name EditFrameDialog

signal region_changed(rect: Rect2)

enum SnapMode { PIXEL, GRID, AUTOSLICE }

const HANDLE_SCREEN := 8.0
const HANDLE_HIT := 12.0
const AUTOSLICE_ALPHA := 0.01
const GRID_COLOR := Color(1.0, 1.0, 1.0, 0.15)
const SLICE_COLOR := Color(0.3, 0.7, 1.0, 1.0)

static var session_snap_mode: SnapMode = SnapMode.PIXEL
static var session_snap_offset := Vector2.ZERO
static var session_snap_step := Vector2(8, 8)
static var session_snap_separation := Vector2.ZERO

@onready var preview: SheetPreview = %SheetPreview
@onready var scroll: ScrollContainer = %SheetScroll
@onready var zoom_label: Label = %ZoomLabel
@onready var rect_x: SpinBox = %RectX
@onready var rect_y: SpinBox = %RectY
@onready var rect_w: SpinBox = %RectW
@onready var rect_h: SpinBox = %RectH
@onready var snap_mode_option: OptionButton = %SnapMode
@onready var grid_snap_bar: HBoxContainer = %GridSnap
@onready var snap_off_x: SpinBox = %SnapOffX
@onready var snap_off_y: SpinBox = %SnapOffY
@onready var snap_step_x: SpinBox = %SnapStepX
@onready var snap_step_y: SpinBox = %SnapStepY
@onready var snap_sep_x: SpinBox = %SnapSepX
@onready var snap_sep_y: SpinBox = %SnapSepY

var region := Rect2()
var _original := Rect2()
var _updating_spins := false
var _updating_grid := false
var _dragging := false
var _creating := false
var _drag_index := -1
var _drag_from := Vector2.ZERO
var _rect_prev := Rect2()
var _cancelled := true
var _autoslice_cache: Array[Rect2] = []
var _autoslice_dirty := true
var _autoslice_tex: Texture2D

const PIVOTS: Array[Vector2] = [
	Vector2(1, 1), # 0 top-left
	Vector2(0, 1), # 1 top
	Vector2(0, 1), # 2 top-right
	Vector2(0, 0), # 3 right
	Vector2(0, 0), # 4 bottom-right
	Vector2(0, 0), # 5 bottom
	Vector2(1, 0), # 6 bottom-left
	Vector2(1, 0), # 7 left
]


func _ready() -> void:
	exclusive = true
	transient = true
	unresizable = false
	ok_button_text = "OK"
	title = "Edit Frame"
	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled)
	preview.draw.connect(_on_preview_draw)
	preview.zoom_changed.connect(_on_zoom_changed)
	scroll.gui_input.connect(_on_scroll_input)
	var content: Control = $VBox
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(980, 480)
	_compact_grid_spins()
	var zoom_bar: Control = scroll.get_parent().get_node("ZoomBar")
	zoom_bar.reset_size()
	zoom_bar.size = zoom_bar.get_combined_minimum_size()
	snap_mode_option.add_item("Pixel Snap", SnapMode.PIXEL)
	snap_mode_option.add_item("Grid Snap", SnapMode.GRID)
	snap_mode_option.add_item("Auto Slice", SnapMode.AUTOSLICE)
	_sync_snap_controls()


func get_original_region() -> Rect2:
	return _original


func has_pending_change() -> bool:
	return region != _original


func setup(atlas: Texture2D, start_region: Rect2) -> void:
	if atlas != _autoslice_tex:
		_autoslice_dirty = true
		_autoslice_tex = atlas
		_autoslice_cache.clear()
	preview.set_sheet_texture(atlas)
	_original = start_region
	_cancelled = true
	_apply_region(start_region, false)
	_update_grid_ranges()
	_sync_snap_controls()
	if session_snap_mode == SnapMode.AUTOSLICE:
		_update_autoslice()
	preview.zoom_reset()
	if !visibility_changed.is_connected(_on_visibility_changed_fit):
		visibility_changed.connect(_on_visibility_changed_fit)


func _on_visibility_changed_fit() -> void:
	if visible:
		if session_snap_mode == SnapMode.AUTOSLICE && _autoslice_dirty:
			_update_autoslice()
		await get_tree().process_frame
		preview.zoom_fit()


func _compact_grid_spins() -> void:
	for spin in [snap_off_x, snap_off_y, snap_step_x, snap_step_y, snap_sep_x, snap_sep_y]:
		spin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		spin.custom_minimum_size.x = 64
		spin.get_line_edit().custom_minimum_size.x = 32


func _sync_snap_controls() -> void:
	_updating_grid = true
	snap_mode_option.select(int(session_snap_mode))
	grid_snap_bar.visible = session_snap_mode == SnapMode.GRID
	snap_off_x.value = session_snap_offset.x
	snap_off_y.value = session_snap_offset.y
	snap_step_x.value = session_snap_step.x
	snap_step_y.value = session_snap_step.y
	snap_sep_x.value = session_snap_separation.x
	snap_sep_y.value = session_snap_separation.y
	_updating_grid = false
	preview.queue_redraw()


func _update_grid_ranges() -> void:
	if !preview.texture:
		return
	var tex_size := preview.texture.get_size()
	_updating_grid = true
	snap_off_x.min_value = -tex_size.x
	snap_off_x.max_value = tex_size.x
	snap_off_y.min_value = -tex_size.y
	snap_off_y.max_value = tex_size.y
	snap_step_x.max_value = tex_size.x
	snap_step_y.max_value = tex_size.y
	snap_sep_x.max_value = tex_size.x
	snap_sep_y.max_value = tex_size.y
	_updating_grid = false


func _on_snap_mode_selected(index: int) -> void:
	@warning_ignore("int_as_enum_without_cast")
	session_snap_mode = index
	grid_snap_bar.visible = session_snap_mode == SnapMode.GRID
	if session_snap_mode == SnapMode.AUTOSLICE && _autoslice_dirty:
		_update_autoslice()
	preview.queue_redraw()


func _on_snap_off_x_changed(value: float) -> void:
	if _updating_grid:
		return
	session_snap_offset.x = value
	preview.queue_redraw()


func _on_snap_off_y_changed(value: float) -> void:
	if _updating_grid:
		return
	session_snap_offset.y = value
	preview.queue_redraw()


func _on_snap_step_x_changed(value: float) -> void:
	if _updating_grid:
		return
	session_snap_step.x = value
	preview.queue_redraw()


func _on_snap_step_y_changed(value: float) -> void:
	if _updating_grid:
		return
	session_snap_step.y = value
	preview.queue_redraw()


func _on_snap_sep_x_changed(value: float) -> void:
	if _updating_grid:
		return
	session_snap_separation.x = value
	preview.queue_redraw()


func _on_snap_sep_y_changed(value: float) -> void:
	if _updating_grid:
		return
	session_snap_separation.y = value
	preview.queue_redraw()


func _snap_scalar_separation(offset: float, step: float, target: float, separation: float) -> float:
	if is_zero_approx(step):
		return target
	var a := snappedf(target - offset, step + separation) + offset
	var b := a
	if target >= 0.0:
		b -= separation
	else:
		b += step
	return a if absf(target - a) < absf(target - b) else b


func _snap_point(target: Vector2) -> Vector2:
	target.x = _snap_scalar_separation(
		session_snap_offset.x, session_snap_step.x, target.x, session_snap_separation.x
	)
	target.y = _snap_scalar_separation(
		session_snap_offset.y, session_snap_step.y, target.y, session_snap_separation.y
	)
	return target


func _snap_sheet_pos(pos: Vector2) -> Vector2:
	match session_snap_mode:
		SnapMode.PIXEL:
			return pos.snappedf(1)
		SnapMode.GRID:
			return _snap_point(pos)
		_:
			return pos


func _apply_region(rect: Rect2, emit_change: bool = true) -> void:
	rect = rect.abs()
	rect.position = rect.position.round()
	rect.size = rect.size.round()
	if rect.size.x < 1.0:
		rect.size.x = 1.0
	if rect.size.y < 1.0:
		rect.size.y = 1.0
	region = rect
	_sync_spins()
	preview.queue_redraw()
	if emit_change:
		region_changed.emit(region)


func _sync_spins() -> void:
	_updating_spins = true
	rect_x.value = region.position.x
	rect_y.value = region.position.y
	rect_w.value = region.size.x
	rect_h.value = region.size.y
	_updating_spins = false


func _spin_to_rect() -> Rect2:
	return Rect2(rect_x.value, rect_y.value, rect_w.value, rect_h.value)


func _on_rect_spin_changed(_value: float) -> void:
	if _updating_spins:
		return
	_apply_region(_spin_to_rect())


func _region_local_rect() -> Rect2:
	return Rect2(preview.sheet_to_local(region.position), preview.sheet_to_local(region.size))


func _handle_points_local() -> Array[Vector2]:
	var r := _region_local_rect()
	return [
		r.position,
		Vector2(r.position.x + r.size.x * 0.5, r.position.y),
		Vector2(r.end.x, r.position.y),
		Vector2(r.end.x, r.position.y + r.size.y * 0.5),
		r.end,
		Vector2(r.position.x + r.size.x * 0.5, r.end.y),
		Vector2(r.position.x, r.end.y),
		Vector2(r.position.x, r.position.y + r.size.y * 0.5),
	]


func _get_overlapping_handle(local_pos: Vector2) -> int:
	if session_snap_mode == SnapMode.AUTOSLICE:
		return -1
	var points := _handle_points_local()
	for i in points.size():
		if local_pos.distance_to(points[i]) <= HANDLE_HIT:
			return i
	return -1


func _cursor_for_handle(index: int) -> Control.CursorShape:
	match index:
		0, 4:
			return Control.CURSOR_FDIAGSIZE
		2, 6:
			return Control.CURSOR_BDIAGSIZE
		1, 5:
			return Control.CURSOR_VSIZE
		3, 7:
			return Control.CURSOR_HSIZE
	return Control.CURSOR_ARROW


func _sheet_panel() -> Control:
	return scroll.get_parent() as Control


func _is_over_zoom_bar() -> bool:
	var zoom_bar: Control = _sheet_panel().get_node("ZoomBar")
	return zoom_bar.get_global_rect().has_point(zoom_bar.get_global_mouse_position())


func _is_over_scroll_chrome() -> bool:
	var mouse := scroll.get_global_mouse_position()
	if !scroll.get_global_rect().has_point(mouse):
		return false
	var hbar := scroll.get_h_scroll_bar()
	var vbar := scroll.get_v_scroll_bar()
	if hbar && hbar.visible && hbar.get_global_rect().has_point(mouse):
		return true
	if vbar && vbar.visible && vbar.get_global_rect().has_point(mouse):
		return true
	if hbar && vbar && hbar.visible && vbar.visible:
		var corner := Rect2(
			Vector2(vbar.global_position.x, hbar.global_position.y),
			Vector2(vbar.size.x, hbar.size.y)
		)
		if corner.has_point(mouse):
			return true
	return false


func _is_over_sheet_chrome() -> bool:
	return _is_over_zoom_bar() || _is_over_scroll_chrome()


func _set_edit_cursor(cursor: Control.CursorShape) -> void:
	preview.mouse_default_cursor_shape = cursor
	scroll.mouse_default_cursor_shape = cursor


func _autoslice_at(sheet_pos: Vector2) -> int:
	for i in _autoslice_cache.size():
		if _autoslice_cache[i].has_point(sheet_pos):
			return i
	return -1


func _select_autoslice(sheet_pos: Vector2) -> bool:
	var idx := _autoslice_at(sheet_pos)
	if idx < 0:
		return false
	var chosen := _autoslice_cache[idx]
	var merge := (
		(Input.is_key_pressed(KEY_CTRL) || Input.is_key_pressed(KEY_META))
		&& !Input.is_key_pressed(KEY_SHIFT)
		&& !Input.is_key_pressed(KEY_ALT)
	)
	if merge:
		chosen = chosen.expand(region.position)
		chosen = chosen.expand(region.end)
	_apply_region(chosen)
	return true


func _handle_edit_input(event: InputEvent) -> bool:
	var local_pos := preview.get_local_mouse_position()
	var sheet_pos := preview.local_to_sheet(local_pos)
	if event is InputEventMouseMotion && !_dragging:
		if session_snap_mode == SnapMode.AUTOSLICE:
			if _autoslice_at(sheet_pos) >= 0:
				_set_edit_cursor(Control.CURSOR_POINTING_HAND)
			else:
				_set_edit_cursor(Control.CURSOR_ARROW)
			return false
		var handle := _get_overlapping_handle(local_pos)
		if handle >= 0:
			_set_edit_cursor(_cursor_for_handle(handle))
		elif _region_local_rect().has_point(local_pos):
			_set_edit_cursor(Control.CURSOR_MOVE)
		else:
			_set_edit_cursor(Control.CURSOR_CROSS)
		return false
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_from = _snap_sheet_pos(sheet_pos)
			_rect_prev = region
			_creating = false
			_drag_index = _get_overlapping_handle(local_pos)
			if session_snap_mode == SnapMode.AUTOSLICE:
				_dragging = false
				_select_autoslice(sheet_pos)
				return true
			_dragging = true
			if _drag_index < 0:
				if _region_local_rect().has_point(local_pos):
					_drag_index = -2
					_drag_from = sheet_pos
				else:
					_creating = true
		else:
			_dragging = false
			_creating = false
			_drag_index = -1
		return true
	if event is InputEventMouseMotion && _dragging:
		var new_pos := _snap_sheet_pos(sheet_pos)
		if _creating:
			if new_pos == _drag_from:
				return true
			var rect := Rect2(_drag_from, Vector2.ZERO)
			rect = rect.expand(new_pos)
			_apply_region(rect)
			return true
		if _drag_index == -2:
			var delta := sheet_pos - _drag_from
			var moved := Rect2(_rect_prev.position + delta, _rect_prev.size)
			if session_snap_mode == SnapMode.PIXEL:
				moved.position = moved.position.snappedf(1)
			elif session_snap_mode == SnapMode.GRID:
				moved.position = _snap_point(moved.position)
			_apply_region(moved)
			return true
		if _drag_index >= 0:
			var pivot: Vector2 = _rect_prev.position + _rect_prev.size * PIVOTS[_drag_index]
			var rect := Rect2(pivot, Vector2.ZERO)
			var lock_x := _drag_index == 1 || _drag_index == 5
			var lock_y := _drag_index == 3 || _drag_index == 7
			if lock_x:
				new_pos.x = _rect_prev.get_center().x
			elif lock_y:
				new_pos.y = _rect_prev.get_center().y
			rect = rect.expand(new_pos)
			if lock_x:
				rect.size.x = _rect_prev.size.x
				rect.position.x = _rect_prev.position.x
			elif lock_y:
				rect.size.y = _rect_prev.size.y
				rect.position.y = _rect_prev.position.y
			_apply_region(rect)
		return true
	return false


func _input(event: InputEvent) -> void:
	if !visible:
		return
	var panel := _sheet_panel()
	var over_panel := panel.get_global_rect().has_point(panel.get_global_mouse_position())
	var over_chrome := _is_over_sheet_chrome()
	if over_panel && !over_chrome && preview.handle_zoom_event(event):
		get_viewport().set_input_as_handled()
		return
	if _dragging || (over_panel && !over_chrome):
		if _handle_edit_input(event):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_set_edit_cursor(Control.CURSOR_ARROW)


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


func _update_autoslice() -> void:
	_autoslice_dirty = false
	_autoslice_cache.clear()
	if !preview.texture:
		return
	var image := preview.texture.get_image()
	if !image:
		return
	if image.is_compressed():
		image.decompress()
	var width := image.get_width()
	var height := image.get_height()
	var data := image.get_data()
	var format := image.get_format()
	var bpp := 0
	var alpha_ofs := -1
	match format:
		Image.FORMAT_RGBA8:
			bpp = 4
			alpha_ofs = 3
		Image.FORMAT_LA8:
			bpp = 2
			alpha_ofs = 1
		_:
			bpp = 0
	for y in height:
		var x := 0
		while x < width:
			var opaque := false
			if bpp > 0 && alpha_ofs >= 0:
				opaque = data[(y * width + x) * bpp + alpha_ofs] > int(AUTOSLICE_ALPHA * 255.0)
			else:
				opaque = image.get_pixel(x, y).a > AUTOSLICE_ALPHA
			if !opaque:
				x += 1
				continue
			var found := false
			for i in _autoslice_cache.size():
				var slice := _autoslice_cache[i]
				if !slice.grow(1.5).has_point(Vector2(x, y)):
					continue
				slice = slice.expand(Vector2(x, y))
				slice = slice.expand(Vector2(x + 1, y + 1))
				_autoslice_cache[i] = slice
				x = int(slice.position.x + slice.size.x) - 1
				var merged := true
				while merged:
					merged = false
					var j := 0
					while j < _autoslice_cache.size():
						if j == i:
							j += 1
							continue
						var other := _autoslice_cache[j]
						if slice.grow(1.0).intersects(other):
							slice = slice.expand(other.position)
							slice = slice.expand(other.position + other.size)
							_autoslice_cache[i] = slice
							_autoslice_cache.remove_at(j)
							if j < i:
								i -= 1
							merged = true
						else:
							j += 1
				found = true
				break
			if !found:
				_autoslice_cache.append(Rect2(x, y, 1, 1))
			x += 1
	preview.queue_redraw()


func _draw_snap_grid() -> void:
	if !preview.texture:
		return
	var tex_size := preview.texture.get_size()
	var local_size := preview.size
	if session_snap_step.x > 0.0:
		if is_zero_approx(session_snap_separation.x):
			var n := floorf((0.0 - session_snap_offset.x) / session_snap_step.x)
			var x := session_snap_offset.x + n * session_snap_step.x
			while x <= tex_size.x:
				if x >= 0.0:
					var lx := preview.sheet_to_local(Vector2(x, 0)).x
					preview.draw_line(Vector2(lx, 0), Vector2(lx, local_size.y), GRID_COLOR)
				x += session_snap_step.x
		else:
			var stride := session_snap_step.x + session_snap_separation.x
			var n := floorf((0.0 - session_snap_offset.x) / stride)
			var x := session_snap_offset.x + n * stride
			var sep_w := preview.sheet_to_local(Vector2(session_snap_separation.x, 0)).x
			while x <= tex_size.x + session_snap_separation.x:
				var line_x := x + session_snap_step.x
				if line_x >= 0.0 && line_x <= tex_size.x:
					var lx := preview.sheet_to_local(Vector2(line_x, 0)).x
					preview.draw_rect(Rect2(lx, 0, sep_w, local_size.y), GRID_COLOR)
				x += stride
	if session_snap_step.y > 0.0:
		if is_zero_approx(session_snap_separation.y):
			var n := floorf((0.0 - session_snap_offset.y) / session_snap_step.y)
			var y := session_snap_offset.y + n * session_snap_step.y
			while y <= tex_size.y:
				if y >= 0.0:
					var ly := preview.sheet_to_local(Vector2(0, y)).y
					preview.draw_line(Vector2(0, ly), Vector2(local_size.x, ly), GRID_COLOR)
				y += session_snap_step.y
		else:
			var stride := session_snap_step.y + session_snap_separation.y
			var n := floorf((0.0 - session_snap_offset.y) / stride)
			var y := session_snap_offset.y + n * stride
			var sep_h := preview.sheet_to_local(Vector2(0, session_snap_separation.y)).y
			while y <= tex_size.y + session_snap_separation.y:
				var line_y := y + session_snap_step.y
				if line_y >= 0.0 && line_y <= tex_size.y:
					var ly := preview.sheet_to_local(Vector2(0, line_y)).y
					preview.draw_rect(Rect2(0, ly, local_size.x, sep_h), GRID_COLOR)
				y += stride


func _on_preview_draw() -> void:
	if !preview.texture:
		return
	if session_snap_mode == SnapMode.GRID:
		_draw_snap_grid()
	elif session_snap_mode == SnapMode.AUTOSLICE:
		for slice in _autoslice_cache:
			var sr := Rect2(preview.sheet_to_local(slice.position), preview.sheet_to_local(slice.size))
			preview.draw_rect(sr, SLICE_COLOR, false, 2.0)
	var r := _region_local_rect()
	preview.draw_rect(r, Color(0.3, 0.7, 1.0, 0.12), true)
	preview.draw_rect(r, Color(0.3, 0.7, 1.0, 1.0), false, 2.0)
	if session_snap_mode == SnapMode.AUTOSLICE:
		return
	for p in _handle_points_local():
		var hr := Rect2(p - Vector2.ONE * HANDLE_SCREEN * 0.5, Vector2.ONE * HANDLE_SCREEN)
		preview.draw_rect(hr, Color.WHITE, true)
		preview.draw_rect(hr, Color.BLACK, false, 1.0)


func _on_confirmed() -> void:
	_cancelled = false
	region_changed.emit(region)


func _on_canceled() -> void:
	if !_cancelled:
		return
	_apply_region(_original)
