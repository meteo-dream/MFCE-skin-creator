extends Node

const EDITOR_SCALE_MIN := 0.75
const EDITOR_SCALE_MAX := 4.0


## Connects a signal to a callable without throwing errors if it's already connected
func _connect(sig: Signal, callable: Callable, flags: int = 0) -> bool:
	if callable.is_null() || !callable.is_valid(): return true
	if sig.is_connected(callable): return true
	sig.connect(callable, flags)
	return false


## Disconnects a signal from a callable without throwing errors if it's already disconnected
func _disconnect(sig: Signal, callable: Callable) -> bool:
	if callable.is_null() || !callable.is_valid(): return true
	if !sig.is_connected(callable): return true
	sig.disconnect(callable)
	return false


func editor_scale() -> float:
	var root := get_tree().current_scene
	if root && "editor_scale" in root:
		return clampf(float(root.editor_scale), EDITOR_SCALE_MIN, EDITOR_SCALE_MAX)
	return 1.0


func fit_window_scale(win: Window, min_w: float, min_h: float) -> void:
	var s := editor_scale()
	if is_equal_approx(win.content_scale_factor, s):
		return
	win.content_scale_factor = s
	win.min_size = Vector2i(roundi(min_w * s), roundi(min_h * s))


func clamp_window_to_screen(win: Window) -> void:
	var screen_id := DisplayServer.SCREEN_OF_MAIN_WINDOW
	var wid := win.get_window_id()
	if wid != DisplayServer.INVALID_WINDOW_ID:
		screen_id = DisplayServer.window_get_current_screen(wid)
	var usable := DisplayServer.screen_get_usable_rect(screen_id)
	if win.size.y > usable.size.y:
		win.size.y = usable.size.y
	if win.size.x > usable.size.x:
		win.size.x = usable.size.x


func logical_to_screen(logical: Vector2i) -> Vector2i:
	var s := editor_scale()
	return DisplayServer.window_get_position() + Vector2i(roundi(logical.x * s), roundi(logical.y * s))


func replace_first(from: String, what: String, forwhat: String):
	var idx = from.find(what)
	if idx == -1: return from
	return from.substr(0, idx) + forwhat + from.substr(idx + what.length())
