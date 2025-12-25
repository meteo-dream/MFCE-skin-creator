extends HBoxContainer

const PLAYLIST = [
	preload("res://music/QD-ANOTH.XM"),
	preload("res://music/blueberry.xm"),
	preload("res://music/coffee.xm"),
	preload("res://music/defy_groove.mod"),
	preload("res://music/dilik_-_hanashiro.compat.xm"),
	
	preload("res://music/doc1429_-_february.xm"),
	preload("res://music/doc1429_-_october.xm"), 
	preload("res://music/echoing.mod"), 
	preload("res://music/fastbass.mod"), 
	preload("res://music/hirvih_-_wings.mod"), 
	preload("res://music/music_for_chips.xm"), 

	preload("res://music/rm_-_winning.mod"),
	preload("res://music/scalesof.mod"),
	preload("res://music/smile.mod"),
	preload("res://music/soda7_-_coffee_at_morning.mod"),
	preload("res://music/vincenzo_-_desert_cream.it"),
	preload("res://music/cool_nightmare.mod"),
	preload("res://music/bombastic-968.mod"),
]
const PL_VOL = [
	0.0, 2.0, 0.0, -1.0, 2.0,   0.0, 0.0, -2.0, 0.0, 2.0, 4.5,   -1.2, -1.0, 0.0, 0.0, 0.0, -1.2, -1.0
]

const mute_icon = preload("res://icons/AudioStreamPlayer.png")
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
	play_music()

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		config.volume = volume
		config.index = index
		config.bg_color = $"../Color/MarginContainer/BGcolor".color.to_html(false)
		config.grid_color = $"../Color/MarginContainer2/GridColor".color.to_html()
		config.zoom = %Camera2D.zoom.x
		var json: String = JSON.stringify(config)
		
		var file: FileAccess = FileAccess.open("user://config.json", FileAccess.WRITE)
		file.store_string(json)
		file.close()

func init_config_values() -> void:
	$Loop.button_pressed = config.get("is_looping", false)
	$Mute.button_pressed = config.get("is_muted", false)
	_on_mute_toggled($Mute.button_pressed)
	$CenterContainer/HSlider.value = config.get("volume", volume)
	
	%ZoomLevel.text = %Camera2D.zoom_template_text % [config.get("zoom", 1.0) * 100.0]
	%Camera2D.zoom = Vector2.ONE * config.get("zoom", 1.0)
	%Camera2D.reset_physics_interpolation()
	
	var grid_color = $"../Color/MarginContainer2/GridColor"
	grid_color.color = Color.from_string(config.get("grid_color", ""), grid_color.color)
	grid_color.color_changed.emit(grid_color.color)
	var bg_color = $"../Color/MarginContainer/BGcolor"
	bg_color.color = Color.from_string(config.get("bg_color", ""), bg_color.color)
	bg_color.color_changed.emit(bg_color.color)

func go_next() -> void:
	index = wrapi(index + 1, 0, PLAYLIST.size())

func play_music() -> void:
	player.stream = PLAYLIST[index]
	player.play()
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
