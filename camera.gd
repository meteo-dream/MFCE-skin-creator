extends Camera2D


var launch_dir: Vector2

func _process(delta: float) -> void:
	if launch_dir != Vector2.ZERO:
		global_position += launch_dir
		launch_dir = lerp(launch_dir, Vector2.ZERO, delta * 2)
		
		if launch_dir.is_zero_approx():
			launch_dir = Vector2.ZERO

var dragging: bool

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
		var zoom_delta: float = 0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_delta += 0.05 * (1 + int(Input.is_action_pressed("ui_zoom_extra")) * 5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_delta -= 0.05 * (1 + int(Input.is_action_pressed("ui_zoom_extra")) * 5)
			
		zoom.x += zoom_delta
		zoom.y += zoom_delta
			
		zoom = clamp(zoom, Vector2.ONE * 0.5, Vector2.ONE * 15.0)
			
		
		if Input.is_action_pressed("ui_drag_camera"):
			launch_dir = Vector2.ZERO
	
