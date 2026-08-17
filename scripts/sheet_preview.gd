extends TextureRect
class_name SheetPreview

signal zoom_changed(zoom: float)

const SCALE_RATIO := 1.2
const MIN_ZOOM := 0.01
const MAX_ZOOM := 128.0
const CHECKER := preload("res://alpha_text.png")

var sheet_zoom: float = 1.0
var _panning := false
var _pan_last := Vector2.ZERO
var _checker: TextureRect


func _ready() -> void:
	expand_mode = EXPAND_IGNORE_SIZE
	stretch_mode = STRETCH_SCALE
	texture_filter = TEXTURE_FILTER_NEAREST
	mouse_filter = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_ensure_checker()


func _ensure_checker() -> void:
	if _checker:
		return
	_checker = TextureRect.new()
	_checker.texture = CHECKER
	_checker.expand_mode = EXPAND_IGNORE_SIZE
	_checker.stretch_mode = STRETCH_TILE
	_checker.texture_filter = TEXTURE_FILTER_NEAREST
	_checker.mouse_filter = MOUSE_FILTER_IGNORE
	_checker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_checker.show_behind_parent = true
	add_child(_checker)
	move_child(_checker, 0)


func get_scroll() -> ScrollContainer:
	var node := get_parent()
	while node:
		if node is ScrollContainer:
			return node
		node = node.get_parent()
	return null


func set_sheet_texture(tex: Texture2D) -> void:
	texture = tex
	_apply_zoom()


func set_zoom(zoom: float) -> void:
	sheet_zoom = clampf(zoom, MIN_ZOOM, MAX_ZOOM)
	_apply_zoom()
	zoom_changed.emit(sheet_zoom)


func zoom_on_position(factor: float, scroll_local_pos: Vector2) -> void:
	if !texture:
		return
	var old_zoom := sheet_zoom
	set_zoom(sheet_zoom * factor)
	var scroll := get_scroll()
	if !scroll || is_zero_approx(old_zoom):
		return
	var offset := Vector2(scroll.scroll_horizontal, scroll.scroll_vertical)
	offset = (offset + scroll_local_pos) / old_zoom * sheet_zoom - scroll_local_pos
	scroll.scroll_horizontal = int(offset.x)
	scroll.scroll_vertical = int(offset.y)


func zoom_toward_cursor(factor: float) -> void:
	var scroll := get_scroll()
	var pos := scroll.get_local_mouse_position() if scroll else get_local_mouse_position()
	zoom_on_position(factor, pos)


func zoom_in() -> void:
	zoom_toward_cursor(SCALE_RATIO)


func zoom_out() -> void:
	zoom_toward_cursor(1.0 / SCALE_RATIO)


func zoom_reset() -> void:
	set_zoom(1.0)


func zoom_fit() -> void:
	if !texture:
		return
	var scroll := get_scroll()
	if !scroll:
		return
	var margin := (scroll.size * 0.1).clamp(Vector2.ZERO, Vector2(64, 64))
	var display := scroll.size - margin
	if display.x <= 1.0 || display.y <= 1.0:
		return
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 || tex_size.y <= 0.0:
		return
	var ratio := display / tex_size
	var fit_zoom: float = minf(ratio.x, ratio.y)
	if fit_zoom > 1.0:
		fit_zoom = floorf(fit_zoom)
	elif !is_zero_approx(fit_zoom):
		fit_zoom = 1.0 / ceilf(1.0 / fit_zoom)
	set_zoom(fit_zoom)


func local_to_sheet(local_pos: Vector2) -> Vector2:
	return local_pos / sheet_zoom


func sheet_to_local(sheet_pos: Vector2) -> Vector2:
	return sheet_pos * sheet_zoom


func _apply_zoom() -> void:
	if texture:
		custom_minimum_size = texture.get_size() * sheet_zoom
		size = custom_minimum_size
	else:
		custom_minimum_size = Vector2.ZERO
	queue_redraw()


func handle_zoom_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton && event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_toward_cursor(SCALE_RATIO)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_toward_cursor(1.0 / SCALE_RATIO)
			return true
	return false


func _gui_input(event: InputEvent) -> void:
	if handle_zoom_event(event):
		accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
			_pan_last = event.global_position
			accept_event()
	elif event is InputEventMouseMotion && _panning:
		var scroll := get_scroll()
		if scroll:
			var delta: Vector2 = event.global_position - _pan_last
			_pan_last = event.global_position
			scroll.scroll_horizontal -= int(delta.x)
			scroll.scroll_vertical -= int(delta.y)
		accept_event()
