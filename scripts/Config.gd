extends Node

const PATH := "user://config.json"
const RECENT_SKINS_MAX := 8

var data: Dictionary = {}


func _init() -> void:
	load_file()


func _ready() -> void:
	get_tree().root.close_requested.connect(collect_and_save)


func load_file() -> void:
	var json := FileAccess.get_file_as_string(PATH)
	if json.is_empty():
		return
	var parsed = JSON.parse_string(json)
	if parsed is Dictionary:
		data = parsed


func save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if !file:
		return
	file.store_string(JSON.stringify(data))
	file.close()


func collect_and_save() -> void:
	collect_from_scene()
	save()


func apply_to_scene() -> void:
	var scene := get_tree().current_scene
	if !scene:
		return
	var camera := _n("Camera2D") as Camera2D
	if camera:
		camera.set_logical_zoom(data.get("zoom", 1.0))
		camera.origin_offset_y = float(data.get("camera_origin_y", -32.0))
		camera.position.x = data.get("campos_x", 0.0)
		camera.position.y = data.get("campos_y", 0.0)
	var splitter := _n("FrameHSplitter") as SplitContainer
	if splitter:
		splitter.split_offset = int(data.get("anim_split_offset", -380))
	var grid_color := _n("GridColor") as ColorPickerButton
	if grid_color:
		grid_color.color = Color.from_string(data.get("grid_color", ""), grid_color.color)
		scene.color = grid_color.color
	var bg_color := _n("BGcolor") as ColorPickerButton
	if bg_color:
		bg_color.color = Color.from_string(data.get("bg_color", ""), bg_color.color)
		RenderingServer.set_default_clear_color(bg_color.color)
	var frames_dock := _n("FramesDock") as FramesStrip
	var thumb := clampi(int(data.get("thumb_size", 64)), 32, 256)
	var thumb_spin := _n("ThumbSize") as SpinBox
	if thumb_spin:
		thumb_spin.value = thumb
	if frames_dock:
		frames_dock.set_thumb_size(thumb)
	var editor := _n("Editor") as PopupMenu
	var show_col: bool = data.get("show_collisions", false)
	if editor:
		editor.set_item_checked(editor.get_item_index(Main.EditorMenu.SHOW_COLLISION), show_col)
		editor.set_item_checked(editor.get_item_index(Main.EditorMenu.AUTORELOAD), data.get("autoreload", true))
	scene.show_collisions = show_col
	var history_split := _n("HistoryHSplit") as SplitContainer
	if history_split:
		history_split.split_offset = int(data.get("history_split_offset", 10000))
	var history_dock := _n("HistoryDock") as HistoryDock
	var hist_vis: bool = data.get("history_visible", false)
	if history_dock:
		if data.get("history_floating", false):
			history_dock.set_floating(true, false)
			history_dock.apply_window_rect(Rect2i(
				int(data.get("history_win_x", 0)),
				int(data.get("history_win_y", 0)),
				int(data.get("history_win_w", 280)),
				int(data.get("history_win_h", 600))
			))
		history_dock.set_open(hist_vis, false)
	if editor:
		editor.set_item_checked(editor.get_item_index(Main.EditorMenu.HISTORY), hist_vis)
	if frames_dock && data.get("frames_floating", false):
		frames_dock.set_floating(true, false)
		frames_dock.apply_window_rect(Rect2i(
			int(data.get("frames_win_x", 0)),
			int(data.get("frames_win_y", 0)),
			int(data.get("frames_win_w", 900)),
			int(data.get("frames_win_h", 280))
		))
	var origin_spin := _n("CameraOriginY") as SpinBox
	if origin_spin && camera:
		origin_spin.set_value_no_signal(camera.origin_offset_y)
	if camera:
		camera.apply_layout_change()


func collect_from_scene() -> void:
	var scene := get_tree().current_scene
	if !scene:
		return
	var music := _n("MusicControls") as MusicControls
	if music:
		data.volume = music.volume
		data.index = music.index
	if "color" in scene:
		data.grid_color = scene.color.to_html()
	if "editor_scale" in scene:
		data.editor_scale = scene.editor_scale
	if "show_collisions" in scene:
		data.show_collisions = scene.show_collisions
	data.bg_color = RenderingServer.get_default_clear_color().to_html(false)
	var camera := _n("Camera2D") as Camera2D
	if camera:
		data.zoom = camera.logical_zoom
		data.campos_x = camera.position.x
		data.campos_y = camera.position.y
		data.camera_origin_y = camera.origin_offset_y
	var splitter := _n("FrameHSplitter") as SplitContainer
	if splitter:
		data.anim_split_offset = splitter.split_offset
	var frames_dock := _n("FramesDock") as FramesStrip
	if frames_dock:
		data.thumb_size = frames_dock.thumb_size
		data.frames_floating = frames_dock.is_floating()
		if frames_dock.is_floating():
			var frames_rect: Rect2i = frames_dock.get_window_rect()
			data.frames_win_x = frames_rect.position.x
			data.frames_win_y = frames_rect.position.y
			data.frames_win_w = frames_rect.size.x
			data.frames_win_h = frames_rect.size.y
	var editor := _n("Editor") as PopupMenu
	if editor:
		data.autoreload = editor.is_item_checked(editor.get_item_index(Main.EditorMenu.AUTORELOAD))
		data.history_visible = editor.is_item_checked(editor.get_item_index(Main.EditorMenu.HISTORY))
	var history_dock := _n("HistoryDock") as HistoryDock
	if history_dock:
		if !editor:
			data.history_visible = history_dock.is_open()
		data.history_floating = history_dock.is_floating()
		var hist_rect: Rect2i = history_dock.get_window_rect()
		data.history_win_x = hist_rect.position.x
		data.history_win_y = hist_rect.position.y
		data.history_win_w = hist_rect.size.x
		data.history_win_h = hist_rect.size.y
	var history_split := _n("HistoryHSplit") as SplitContainer
	if history_split:
		data.history_split_offset = history_split.split_offset


func get_recent_skins() -> Array:
	var recents: Array = []
	var raw = data.get("recent_skins", [])
	if !(raw is Array):
		return recents
	for item in raw:
		if !(item is String) || item.is_empty():
			continue
		var path: String = _normalize_skin_path(item)
		if _recent_index(recents, path) >= 0:
			continue
		recents.append(path)
		if recents.size() >= RECENT_SKINS_MAX:
			break
	return recents


func add_recent_skin(path: String) -> void:
	path = _normalize_skin_path(path)
	if path.is_empty():
		return
	var recents: Array = get_recent_skins()
	var existing: int = _recent_index(recents, path)
	if existing >= 0:
		recents.remove_at(existing)
	recents.push_front(path)
	while recents.size() > RECENT_SKINS_MAX:
		recents.pop_back()
	data.recent_skins = recents
	save()


func remove_recent_skin(path: String) -> void:
	var recents: Array = get_recent_skins()
	var existing: int = _recent_index(recents, path)
	if existing < 0:
		return
	recents.remove_at(existing)
	data.recent_skins = recents
	save()


func _n(unique: String) -> Node:
	var scene := get_tree().current_scene
	if !scene:
		return null
	return scene.get_node_or_null("%" + unique)


func _normalize_skin_path(path: String) -> String:
	return path.replace("\\", "/").rstrip("/")


func _recent_index(recents: Array, path: String) -> int:
	var norm := _normalize_skin_path(path)
	var ignore_case := OS.get_name() == "Windows"
	for i in recents.size():
		var other: String = recents[i]
		if ignore_case:
			if other.to_lower() == norm.to_lower():
				return i
		elif other == norm:
			return i
	return -1
