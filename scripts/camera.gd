extends Camera2D

var zoom_min := 0.5
var zoom_max := 32.0
const ZOOM_INCREMENT: float = 6
var zoom_speed := 0.1

@onready var zoom_template_text = %ZoomLevel.text
var has_user_moved: bool
var _chrome_offset := Vector2.ZERO

func _ready() -> void:
	%ZoomLevel.text = zoom_template_text % [1 * 100.0]

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


func _is_mouse_over_ui_dock() -> bool:
	if _is_mouse_over_control("%FramesDock"):
		return true
	return _is_mouse_over_docked_history()


func _is_mouse_over_control(node_path: String) -> bool:
	if !has_node(node_path):
		return false
	var control: Control = get_node(node_path)
	if !control.visible || !control.is_visible_in_tree():
		return false
	return control.get_global_rect().has_point(control.get_global_mouse_position())


func _is_mouse_over_docked_history() -> bool:
	if !has_node("%HistoryDock"):
		return false
	var dock: Control = %HistoryDock
	if !dock.visible || !dock.is_visible_in_tree():
		return false
	if dock.get_parent() is Window:
		return false
	return dock.get_global_rect().has_point(dock.get_global_mouse_position())


func _history_dock_width() -> float:
	if !has_node("%HistoryDock"):
		return 0.0
	var dock: Control = %HistoryDock
	if !dock.visible || !dock.is_visible_in_tree():
		return 0.0
	if dock.get_parent() is Window:
		return 0.0
	return dock.size.x


func get_camera_position() -> Vector2:
	var dock_h := 0.0
	if has_node("%FramesDock"):
		dock_h = %FramesDock.size.y
	var menu_h := 0.0
	if has_node("%MenuPanel"):
		menu_h = %MenuPanel.size.y
	var hist_w := _history_dock_width()
	# Right-side dock: look further right so the sprite stays in the remaining preview.
	return Vector2(hist_w * 0.5 / zoom.x, -32.0 + dock_h * 0.5 / zoom.y - menu_h * 0.5 / zoom.y)


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
	var _alt = int(!Input.is_action_pressed(&"ui_zoom_extra")) + 1
	var current_zoom_step: float = round(log(zoom.x) * (12.0 * _alt) / log(2.0))
	var new_zoom: float = pow(2.0, (current_zoom_step + ZOOM_INCREMENT) / (12.0 * _alt))
	var clamped_zoom = minf(new_zoom, zoom_max)
	#print(new_zoom)
	%ZoomLevel.text = zoom_template_text % [clamped_zoom * 100.0]
	update_zoom(zoom, clamped_zoom * Vector2.ONE)

func zoom_out() -> void:
	var _alt = int(!Input.is_action_pressed(&"ui_zoom_extra")) + 1
	var current_zoom_step: float = round(log(zoom.x) * (12.0 * _alt) / log(2.0))
	var new_zoom: float = pow(2.0, (current_zoom_step - ZOOM_INCREMENT) / (12.0 * _alt))
	var clamped_zoom = maxf(new_zoom, zoom_min)
	#print(new_zoom)
	%ZoomLevel.text = zoom_template_text % [clamped_zoom * 100.0]
	update_zoom(zoom, clamped_zoom * Vector2.ONE)

func update_zoom(old_zoom: Vector2, new_zoom: Vector2) -> void:
	var screen_width = get_viewport_rect().size.x #- %FrameHSplitter/Panel.size.x / zoom.x
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
