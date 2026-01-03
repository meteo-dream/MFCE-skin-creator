@tool
extends Node2D

@export
var grid_size: Vector2 = Vector2.ONE * 16.0 :
	set(value):
		grid_size = value
		queue_redraw()

@export
var color: Color = Color.DIM_GRAY :
	set(value):
		queue_redraw()
		color = value

@export
var show_collisions: bool:
	set(value):
		show_collisions = value
		$Preview/CollisionsRect.update_rect()
		$Preview/CollisionsRect.queue_redraw()
@export
var editor_scale: float

var w_min_size: Vector2i

func _init() -> void:
	var user_screen: Rect2i = DisplayServer.screen_get_usable_rect()
	if user_screen.size.y < ProjectSettings.get_setting("display/window/size/viewport_height"):
		var wind_size = DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
		DisplayServer.window_set_size(Vector2i(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			user_screen.size.y - 12 - wind_size.y
		))
		DisplayServer.window_set_position(
			(user_screen.size / 2) - (DisplayServer.window_get_size() / 2) + (wind_size / 2)
		)

func _notification(what: int) -> void:
	if Engine.is_editor_hint(): return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


func _ready() -> void:
	process_loaded_config()

func _draw():
	var vp_size: = get_viewport_rect().size
	var cam_pos: = Vector2.ZERO
	var vp_right: = vp_size.x
	var vp_bottom: = vp_size.y
	
	var leftmost: = -vp_right + cam_pos.x
	var topmost: = -vp_bottom + cam_pos.y
	
	var left: float = ceil(leftmost / grid_size.x) * grid_size.x
	var bottommost: = vp_bottom + cam_pos.y
	for x in range(0, (vp_size.x / grid_size.x) * 2 + 1):
		draw_line(Vector2(left, topmost), Vector2(left, bottommost), color)
		left += grid_size.x

	var top: float = ceil(topmost / grid_size.y) * grid_size.y
	var rightmost: = vp_right + cam_pos.x
	for y in range(0, (vp_size.y / grid_size.y) * 2 + 1):
		draw_line(Vector2(leftmost, top), Vector2(rightmost, top), color)
		top += grid_size.y
	
	draw_line(Vector2(0, vp_size.y),Vector2(0, -vp_size.y), Color.GREEN)
	draw_line(Vector2(vp_size.x, 0),Vector2(-vp_size.x, 0), Color.RED)


func process_loaded_config() -> void:
	if !w_min_size:
		w_min_size = get_window().min_size
	var current_screen := DisplayServer.window_get_current_screen(get_window().get_window_id())
	var non_windows_scale := DisplayServer.screen_get_scale(current_screen)
	if editor_scale < 0.5:
		if OS.get_name() != "Windows":
			editor_scale = non_windows_scale
		elif DisplayServer.screen_get_dpi(current_screen) > 120:
			editor_scale = 2.0
		else:
			editor_scale = 1.0
	
	var _scr_size: Vector2i = DisplayServer.screen_get_size(current_screen)
	if (editor_scale >= 2.0 && 
		_scr_size.x >= 1920 && _scr_size.y >= 1600
	):
		get_window().min_size = Vector2i(1600, 800)
		get_window().size = Vector2i(1920, 1540)
		
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		get_window().position = (
			(_scr_size / 2) - (get_window().size / 2)
		)
	
	if editor_scale >= 0.5:
		get_window().content_scale_factor = editor_scale
		ProjectSettings.set_setting("display/window/stretch/scale", editor_scale)


func _on_bg_color_changed(_color: Color) -> void:
	RenderingServer.set_default_clear_color(_color)


func _on_grid_color_changed(_color: Color) -> void:
	color = _color


func _on_collisions_toggled(toggled_on: bool) -> void:
	show_collisions = toggled_on
