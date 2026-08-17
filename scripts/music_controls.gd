extends HBoxContainer

const PLAYLIST = [
	preload("res://music/QD-ANOTH.mo3"),
	preload("res://music/blueberry.mo3"),
	preload("res://music/coffee.mo3"),
	preload("res://music/defy_groove.mo3"),
	preload("res://music/dilik_-_hanashiro.compat.mo3"),
	
	preload("res://music/doc1429_-_february.mo3"),
	preload("res://music/doc1429_-_october.mo3"), 
	preload("res://music/echoing.mo3"), 
	preload("res://music/fastbass.mo3"), 
	preload("res://music/hirvih_-_wings.mo3"), 
	preload("res://music/music_for_chips.mo3"), 

	preload("res://music/rm_-_winning.mo3"),
	preload("res://music/scalesof.mo3"),
	preload("res://music/smile.mo3"),
	preload("res://music/soda7_-_coffee_at_morning.mo3"),
	preload("res://music/vincenzo_-_desert_cream.mo3"),
	preload("res://music/cool_nightmare.mo3"),
	preload("res://music/bombastic-968.mo3"),
]
const PL_VOL = [
	0.0, 2.0, 0.0, -1.0, 2.0,   0.0, 0.0, -2.0, 0.0, 2.0, 4.5,   -1.2, -1.0, 0.0, 0.0, 0.0, -1.2, -1.0
]

const mute_icon = preload("res://icons/AudioStreamPlayer.svg")
const RECENT_SKINS_MAX := 8

@onready var player: AudioStreamPlayer = $AudioStreamPlayer

@onready var volume: float = $CenterContainer/HSlider.value
var index: int
var config: Dictionary = {}

func _ready() -> void:
	var json = FileAccess.get_file_as_string("user://config.json")
	if json:
		var dict = JSON.parse_string(json)
		if dict && dict is Dictionary: config = dict
	init_config_values.call_deferred()
	_on_h_slider_value_changed(volume)
	if config.get("is_looping", false):
		index = config.get("index", 0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		config.volume = volume
		config.index = index
		config.bg_color = %BGcolor.color.to_html(false)
		config.grid_color = %GridColor.color.to_html()
		config.zoom = %Camera2D.zoom.x
		config.campos_x = %Camera2D.position.x
		config.campos_y = %Camera2D.position.y
		config.anim_split_offset = %FrameHSplitter.split_offset
		config.thumb_size = %FramesDock.thumb_size
		config.show_collisions = get_tree().current_scene.show_collisions
		config.autoreload = %Editor.is_item_checked(%Editor.get_item_index(3))
		save_config()


func save_config() -> void:
	var json: String = JSON.stringify(config)
	var file: FileAccess = FileAccess.open("user://config.json", FileAccess.WRITE)
	if !file:
		return
	file.store_string(json)
	file.close()


func get_recent_skins() -> Array:
	var recents: Array = []
	var raw = config.get("recent_skins", [])
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
	config.recent_skins = recents
	save_config()


func remove_recent_skin(path: String) -> void:
	var recents: Array = get_recent_skins()
	var existing: int = _recent_index(recents, path)
	if existing < 0:
		return
	recents.remove_at(existing)
	config.recent_skins = recents
	save_config()


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

func init_config_values() -> void:
	$Loop.button_pressed = config.get("is_looping", false)
	$Mute.button_pressed = config.get("is_muted", true)
	play_music()
	_on_mute_toggled($Mute.button_pressed)
	$CenterContainer/HSlider.value = config.get("volume", volume)
	
	%ZoomLevel.text = %Camera2D.zoom_template_text % [config.get("zoom", 1.0) * 100.0]
	%Camera2D.zoom = Vector2.ONE * config.get("zoom", 1.0)
	%Camera2D.position.x = config.get("campos_x", 0.0)
	%Camera2D.position.y = config.get("campos_y", 0.0)
	%FrameHSplitter.split_offset = int(config.get("anim_split_offset", -380))
	
	var grid_color = %GridColor
	grid_color.color = Color.from_string(config.get("grid_color", ""), grid_color.color)
	grid_color.color_changed.emit(grid_color.color)
	var bg_color = %BGcolor
	bg_color.color = Color.from_string(config.get("bg_color", ""), bg_color.color)
	bg_color.color_changed.emit(bg_color.color)
	
	var thumb := clampi(int(config.get("thumb_size", 96)), 32, 256)
	%ThumbSize.value = thumb
	%FramesDock.set_thumb_size(thumb)
	var show_col: bool = config.get("show_collisions", false)
	%Editor.set_item_checked(%Editor.get_item_index(2), show_col)
	get_tree().current_scene.show_collisions = show_col
	%Editor.set_item_checked(%Editor.get_item_index(3), config.get("autoreload", true))

func go_next() -> void:
	index = wrapi(index + 1, 0, PLAYLIST.size())

func play_music() -> void:
	player.stream = PLAYLIST[index]
	player.play()
	player.stream_paused = $Mute.button_pressed
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), PL_VOL[index])


func _on_mute_toggled(toggled_on: bool) -> void:
	if toggled_on:
		$Mute.icon = null
	else:
		$Mute.icon = mute_icon
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), toggled_on)
	player.stream_paused = toggled_on
	config.is_muted = toggled_on
	$Next.disabled = toggled_on


func _on_h_slider_value_changed(value: float) -> void:
	volume = value
	player.volume_linear = value


func _on_loop_toggled(toggled_on: bool) -> void:
	config.is_looping = toggled_on


func _on_next_pressed() -> void:
	go_next()
	play_music()


func _on_audio_stream_player_finished() -> void:
	if !config.get("is_looping"):
		go_next()
	play_music()
