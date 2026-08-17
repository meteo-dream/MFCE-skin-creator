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
	if Engine.is_editor_hint(): return
	var user_screen: Rect2i = DisplayServer.screen_get_usable_rect()
	if user_screen.size.y < ProjectSettings.get_setting("display/window/size/viewport_height"):
		var wind_size = DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
		DisplayServer.window_set_size(Vector2i(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			user_screen.size.y - 12 - wind_size.y
		))
		get_tree().root.move_to_center()

func _notification(what: int) -> void:
	if Engine.is_editor_hint(): return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Close confirmation is handled by Main when the skin has unsaved edits.
		pass


func _ready() -> void:
	if Engine.is_editor_hint(): return
	process_loaded_config(Config.data)
	Config.apply_to_scene.call_deferred()

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


func process_loaded_config(config: Dictionary = {}) -> void:
	if !w_min_size:
		w_min_size = get_window().min_size
	var current_screen := DisplayServer.window_get_current_screen(get_window().get_window_id())
	var saved_scale := 0.0
	if config.has("editor_scale"):
		saved_scale = clampf(float(config.editor_scale), Util.EDITOR_SCALE_MIN, Util.EDITOR_SCALE_MAX)
	var used_saved := saved_scale >= Util.EDITOR_SCALE_MIN
	if used_saved:
		editor_scale = saved_scale
	elif editor_scale < 0.5:
		if OS.get_name() != "Windows":
			editor_scale = DisplayServer.screen_get_scale(current_screen)
		elif DisplayServer.screen_get_dpi(current_screen) > 120:
			editor_scale = 2.0
		else:
			editor_scale = 1.0
	editor_scale = clampf(editor_scale, Util.EDITOR_SCALE_MIN, Util.EDITOR_SCALE_MAX)
	
	var _scr_size: Vector2i = DisplayServer.screen_get_size(current_screen)
	if (!used_saved && editor_scale >= 2.0 &&
		_scr_size.x >= 1920 && _scr_size.y >= 1600
	):
		get_window().min_size = Vector2i(1600, 800)
		get_window().size = Vector2i(1920, 1540)
		
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		get_tree().root.move_to_center()
	
	apply_editor_scale(editor_scale)


func apply_editor_scale(ui_scale: float) -> void:
	ui_scale = clampf(ui_scale, Util.EDITOR_SCALE_MIN, Util.EDITOR_SCALE_MAX)
	var old := editor_scale if editor_scale >= Util.EDITOR_SCALE_MIN else 1.0
	editor_scale = ui_scale
	get_window().content_scale_factor = ui_scale
	ProjectSettings.set_setting("display/window/stretch/scale", ui_scale)
	if !is_equal_approx(old, ui_scale):
		for win: Window in get_tree().root.find_children("*", "Window", true, false):
			if win == get_window() || win is FileDialog:
				continue
			if win is PopupMenu:
				# Parent window scale already applies; extra factor mis-sizes native popups.
				win.content_scale_factor = 1.0
				continue
			scale_window(win)
	%Camera2D.sync_to_editor_scale()
	if !is_equal_approx(%EditorScale.value, ui_scale * 100.0):
		%EditorScale.set_value_no_signal(roundf(ui_scale * 100.0))


func scale_window(win: Window) -> void:
	var old := win.content_scale_factor
	if old <= 0.0:
		old = 1.0
	if is_equal_approx(old, editor_scale):
		return
	var ratio := editor_scale / old
	var new_size := Vector2i(roundi(win.size.x * ratio), roundi(win.size.y * ratio))
	var new_min := Vector2i(roundi(win.min_size.x * ratio), roundi(win.min_size.y * ratio))
	var center := Vector2(win.position) + Vector2(win.size) * 0.5
	# Drop min_size before shrinking; otherwise the window stays clamped large.
	if new_min.x < win.min_size.x || new_min.y < win.min_size.y:
		win.min_size = new_min
	win.content_scale_factor = editor_scale
	win.min_size = new_min
	if win.wrap_controls:
		win.reset_size()
	else:
		win.size = new_size
	if !win.visible || win.get_window_id() == DisplayServer.INVALID_WINDOW_ID:
		return
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	var win_size := win.size
	if win_size.x > usable.size.x:
		win_size.x = usable.size.x
	if win_size.y > usable.size.y:
		win_size.y = usable.size.y
	if win_size != win.size:
		win.size = win_size
	var pos := Vector2i((center - Vector2(win_size) * 0.5).round())
	pos.x = clampi(pos.x, usable.position.x, usable.position.x + maxi(usable.size.x - win_size.x, 0))
	pos.y = clampi(pos.y, usable.position.y, usable.position.y + maxi(usable.size.y - win_size.y, 0))
	win.position = pos


func _on_bg_color_changed(_color: Color) -> void:
	RenderingServer.set_default_clear_color(_color)


func _on_grid_color_changed(_color: Color) -> void:
	color = _color


func _on_collisions_toggled(toggled_on: bool) -> void:
	show_collisions = toggled_on
