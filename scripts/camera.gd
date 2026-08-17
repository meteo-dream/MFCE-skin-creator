extends Camera2D

var zoom_min := 0.5
var zoom_max := 64.0
const ZOOM_INCREMENT: float = 6

@onready var zoom_template_text = %ZoomLevel.text
var has_user_moved: bool
var _chrome_offset := Vector2.ZERO
var logical_zoom: float = 1.0
var origin_offset_y: float = -32.0


func _ready() -> void:
	_refresh_zoom_label()
	Util._connect(%PreviewOverlay.resized, apply_layout_change)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_reset_view"):
		update_camera_position()
		has_user_moved = false
	
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("ui_drag_camera"):
			var rel: Vector2 = event.relative
			rel.x *= 1.0 / zoom.x
			rel.y *= 1.0 / zoom.y
			
			global_position -= rel
			if !has_user_moved && rel != Vector2.ZERO:
				has_user_moved = true
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP || event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _is_mouse_over_ui_dock():
				return
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
			else:
				zoom_out()


func _camera_zoom_from_logical(logical: float) -> float:
	return logical / Util.editor_scale()


func _refresh_zoom_label() -> void:
	%ZoomLevel.text = zoom_template_text % [logical_zoom * 100.0]


func set_logical_zoom(logical: float) -> void:
	logical_zoom = clampf(logical, zoom_min, zoom_max)
	zoom = Vector2.ONE * _camera_zoom_from_logical(logical_zoom)
	_refresh_zoom_label()
	_chrome_offset = get_camera_position()


func set_origin_offset_y(origin_y: float) -> void:
	if is_equal_approx(origin_offset_y, origin_y):
		return
	origin_offset_y = origin_y
	apply_layout_change()


func sync_to_editor_scale() -> void:
	zoom = Vector2.ONE * _camera_zoom_from_logical(logical_zoom)
	_refresh_zoom_label()
	apply_layout_change()


func _is_mouse_over_ui_dock() -> bool:
	return _is_mouse_over_docked_control("%FramesDock") || _is_mouse_over_docked_control("%HistoryDock")


func _is_mouse_over_docked_control(node_path: String) -> bool:
	if !has_node(node_path):
		return false
	var control: Control = get_node(node_path)
	if !control.visible || !control.is_visible_in_tree():
		return false
	if control.get_parent() is Window:
		return false
	return control.get_global_rect().has_point(control.get_global_mouse_position())


func _preview_view_center() -> Vector2:
	var overlay := %PreviewOverlay as Control
	if !overlay.is_visible_in_tree() || overlay.size.x <= 1.0 || overlay.size.y <= 1.0:
		return get_viewport_rect().size * 0.5
	return overlay.get_global_rect().get_center()


func get_camera_position() -> Vector2:
	var z := Vector2(maxf(zoom.x, 0.0001), maxf(zoom.y, 0.0001))
	return (get_viewport_rect().size * 0.5 - _preview_view_center()) / z + Vector2(0.0, origin_offset_y)


func update_camera_position() -> void:
	_chrome_offset = get_camera_position()
	position = _chrome_offset


func apply_layout_change() -> void:
	var new_offset := get_camera_position()
	if has_user_moved:
		position += new_offset - _chrome_offset
	else:
		position = new_offset
	_chrome_offset = new_offset


func zoom_in() -> void:
	_nudge_logical_zoom(1.0)


func zoom_out() -> void:
	_nudge_logical_zoom(-1.0)


func _nudge_logical_zoom(direction: float) -> void:
	var alt := int(!Input.is_action_pressed(&"ui_zoom_extra")) + 1
	var step := roundf(log(logical_zoom) * (12.0 * alt) / log(2.0))
	var next := pow(2.0, (step + ZOOM_INCREMENT * direction) / (12.0 * alt))
	var clamped := clampf(next, zoom_min, zoom_max)
	update_zoom(zoom, _camera_zoom_from_logical(clamped) * Vector2.ONE)
	logical_zoom = clamped
	_refresh_zoom_label()

func update_zoom(old_zoom: Vector2, new_zoom: Vector2) -> void:
	var screen_width = get_viewport_rect().size.x
	var screen_height = get_viewport_rect().size.y
	var mouse_x = get_viewport().get_mouse_position().x
	var mouse_y = get_viewport().get_mouse_position().y
	var pixels_difference_x = (screen_width / old_zoom.x) - (screen_width / new_zoom.y)
	var pixels_difference_y = (screen_height / old_zoom.y) - (screen_height / new_zoom.y)
	var side_ratio_x = (mouse_x - (screen_width / 2)) / screen_width
	var side_ratio_y = (mouse_y - (screen_height / 2)) / screen_height
	position.x += pixels_difference_x * side_ratio_x
	position.y += pixels_difference_y * side_ratio_y
	zoom = new_zoom
	_chrome_offset = get_camera_position()
	if has_user_moved:
		if position != get_screen_center_position():
			position = get_screen_center_position()
	elif position != _chrome_offset:
		position = _chrome_offset
