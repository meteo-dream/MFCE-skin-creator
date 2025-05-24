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
	preload("res://music/bombastic-968.mod"),
]
const PL_VOL = [
	0.0, 2.0, 0.0, -1.0, 2.0,   0.0, 0.0, -2.0, 0.0, 2.0, 4.5,   -1.2, -1.0, 0.0, 0.0, 0.0, -1.0
]

const mute_icon = preload("res://icons/AudioStreamPlayer.png")
@onready var player: AudioStreamPlayer = $AudioStreamPlayer

@onready var volume: float = $CenterContainer/HSlider.value
var is_looping: bool
var index: int

func _ready() -> void:
	_on_h_slider_value_changed(volume)
	play_music()

func go_next() -> void:
	index = wrapi(index + 1, 0, 17)

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


func _on_h_slider_value_changed(value: float) -> void:
	volume = value
	player.volume_linear = value


func _on_loop_toggled(toggled_on: bool) -> void:
	is_looping = toggled_on


func _on_next_pressed() -> void:
	go_next()
	play_music()


func _on_audio_stream_player_finished() -> void:
	if !is_looping:
		go_next()
	play_music()
