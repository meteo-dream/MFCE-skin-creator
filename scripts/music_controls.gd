extends HBoxContainer
class_name MusicControls

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

@onready var player: AudioStreamPlayer = $AudioStreamPlayer
@onready var volume: float = $CenterContainer/HSlider.value
var index: int


func _ready() -> void:
	_on_h_slider_value_changed(volume)
	if Config.data.get("is_looping", false):
		index = int(Config.data.get("index", 0))
	$Loop.button_pressed = Config.data.get("is_looping", false)
	$Mute.button_pressed = Config.data.get("is_muted", true)
	play_music()
	_on_mute_toggled($Mute.button_pressed)
	$CenterContainer/HSlider.value = Config.data.get("volume", volume)


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
	Config.data.is_muted = toggled_on
	$Next.disabled = toggled_on


func _on_h_slider_value_changed(value: float) -> void:
	volume = value
	player.volume_linear = value


func _on_loop_toggled(toggled_on: bool) -> void:
	Config.data.is_looping = toggled_on


func _on_next_pressed() -> void:
	go_next()
	play_music()


func _on_audio_stream_player_finished() -> void:
	if !Config.data.get("is_looping"):
		go_next()
	play_music()
