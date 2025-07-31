extends Camera2D

var zoom_min := 0.5
var zoom_max := 32.0
const ZOOM_INCREMENT: float = 6
var zoom_speed := 0.1

var launch_dir: Vector2

func _process(delta: float) -> void:
	if launch_dir != Vector2.ZERO:
		global_position += launch_dir
		launch_dir = lerp(launch_dir, Vector2.ZERO, delta * 2)
		
		if launch_dir.is_zero_approx():
			launch_dir = Vector2.ZERO

var dragging: bool
@onready var zoom_template_text = %ZoomLevel.text

func _ready() -> void:
	%ZoomLevel.text = zoom_template_text % [1 * 100.0]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_reset_view"):
		position = Vector2.ZERO
		launch_dir = Vector2.ZERO
	
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("ui_drag_camera"):
			var rel: Vector2 = event.relative
			rel.x *= 1.0 / zoom.x
			rel.y *= 1.0 / zoom.y
			
			global_position -= rel
			launch_dir = Vector2.ZERO
			dragging = true
		elif Input.is_action_just_released("ui_drag_camera") && dragging:
			launch_dir = -event.relative
			launch_dir.x *= 1.0 / zoom.x
			launch_dir.y *= 1.0 / zoom.y
			dragging = false
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()
		
		if Input.is_action_pressed("ui_drag_camera"):
			launch_dir = Vector2.ZERO
	
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
	reset_physics_interpolation()
	zoom = new_zoom
	if position != get_screen_center_position():
		position = get_screen_center_position()
	reset_physics_interpolation()
