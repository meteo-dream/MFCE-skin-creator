extends TextureRect
class_name SheetPreview

signal zoom_changed(zoom: float)

const SCALE_RATIO := 1.2
const BUTTON_STEPS := 6
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


func zoom_on_position(factor: float, view_pos: Vector2) -> void:
	if !texture || is_zero_approx(sheet_zoom):
		return
	var scroll := get_scroll()
	var old_zoom := sheet_zoom
	var sheet_pos := view_pos / old_zoom
	if scroll:
		var old_offset := Vector2(scroll.scroll_horizontal, scroll.scroll_vertical)
		sheet_pos = (old_offset + view_pos - position) / old_zoom
	set_zoom(old_zoom * factor)
	if !scroll || is_equal_approx(old_zoom, sheet_zoom):
		return
	_sync_scroll_layout(scroll)
	_set_scroll(scroll, position + sheet_pos * sheet_zoom - view_pos)


func zoom_toward_cursor(factor: float) -> void:
	var scroll := get_scroll()
	var pos := scroll.get_local_mouse_position() if scroll else get_local_mouse_position()
	zoom_on_position(factor, pos)


func zoom_toward_view_center(factor: float) -> void:
	var scroll := get_scroll()
	var pos := scroll.size * 0.5 if scroll else size * 0.5
	zoom_on_position(factor, pos)


func zoom_in() -> void:
	zoom_toward_view_center(pow(SCALE_RATIO, BUTTON_STEPS))


func zoom_out() -> void:
	zoom_toward_view_center(1.0 / pow(SCALE_RATIO, BUTTON_STEPS))


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


func _sync_scroll_layout(scroll: ScrollContainer) -> void:
	var host := get_parent() as Control
	if host:
		host.update_minimum_size()
	scroll.update_minimum_size()
	scroll.get_minimum_size()
	scroll.notification(Container.NOTIFICATION_SORT_CHILDREN)
	if host:
		host.notification(Container.NOTIFICATION_SORT_CHILDREN)


func _set_scroll(scroll: ScrollContainer, offset: Vector2) -> void:
	var content := size
	var hbar := scroll.get_h_scroll_bar()
	var vbar := scroll.get_v_scroll_bar()
	if hbar:
		hbar.max_value = maxf(hbar.max_value, maxf(content.x, offset.x + hbar.page))
	if vbar:
		vbar.max_value = maxf(vbar.max_value, maxf(content.y, offset.y + vbar.page))
	scroll.scroll_horizontal = int(round(offset.x))
	scroll.scroll_vertical = int(round(offset.y))


func handle_zoom_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton && event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_toward_cursor(SCALE_RATIO)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_toward_cursor(1.0 / SCALE_RATIO)
			return true
	return false


func handle_pan_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			if !_is_over_pan_area():
				return false
			_panning = true
			_pan_last = event.global_position
			return true
		if !_panning:
			return false
		_panning = false
		return true
	if event is InputEventMouseMotion && _panning:
		var scroll := get_scroll()
		if scroll:
			var delta: Vector2 = event.global_position - _pan_last
			_pan_last = event.global_position
			scroll.scroll_horizontal -= int(delta.x)
			scroll.scroll_vertical -= int(delta.y)
		return true
	return false


func _is_over_pan_area() -> bool:
	var mouse := get_global_mouse_position()
	var scroll := get_scroll()
	if !scroll:
		return get_global_rect().has_point(mouse)
	if !scroll.get_global_rect().has_point(mouse):
		return false
	var hbar := scroll.get_h_scroll_bar()
	var vbar := scroll.get_v_scroll_bar()
	if hbar && hbar.visible && hbar.get_global_rect().has_point(mouse):
		return false
	if vbar && vbar.visible && vbar.get_global_rect().has_point(mouse):
		return false
	if hbar && vbar && hbar.visible && vbar.visible:
		var corner := Rect2(
			Vector2(vbar.global_position.x, hbar.global_position.y),
			Vector2(vbar.size.x, hbar.size.y)
		)
		if corner.has_point(mouse):
			return false
	var zoom_bar: Control = scroll.get_parent().get_node_or_null("ZoomBar")
	if zoom_bar && zoom_bar.get_global_rect().has_point(mouse):
		return false
	return true


func _input(event: InputEvent) -> void:
	if !is_visible_in_tree():
		return
	if handle_pan_event(event):
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if handle_zoom_event(event):
		accept_event()
		return
	if handle_pan_event(event):
		accept_event()
