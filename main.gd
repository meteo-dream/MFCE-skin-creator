extends Control

@onready var save_dialog: FileDialog = $SaveDialog
@onready var open_dialog: FileDialog = $OpenDialog

var skin_settings: Dictionary
var current_skin_setting: PlayerSkin

var current_folder_skin: String

@onready var preview: AnimatedSprite2D = %Preview
@onready var scene: Node2D = get_tree().current_scene

@onready var spinbox_frame: SpinBox = %Frame
@onready var spinbox_speed: SpinBox = %Speed
@onready var spinbox_frames: SpinBox = %Frames


@onready var anim_option: OptionButton = %AnimOption
@onready var state_option: OptionButton = %StateSelect

@onready var sprite_view: SpriteView = %SpriteView

# Rect2
@onready var rect_x: SpinBox = %RectX
@onready var rect_y: SpinBox = %RectY
@onready var rect_w: SpinBox = %RectW
@onready var rect_h: SpinBox = %RectH

var current_frame: AtlasTexture

func _ready() -> void:
	_set_controls_working(false)
	
	save_dialog.title = "Save Directory (Skin Root Folder)"
	save_dialog.dir_selected.connect(save_file)
	open_dialog.title = "Open a Directory (Skin Root Folder)"
	open_dialog.dir_selected.connect(open_file)
	#open_dialog.popup_centered()
	
	for anim in PlayerSkin.ANIMS:
		anim_option.add_item(anim)
	
	for state in PlayerSkin.STATES:
		state_option.add_item(state)
	
	#get_viewport().gui_focus_changed
	
	get_tree().root.min_size = Vector2(320, 256)
	get_tree().root.size_changed.connect(_on_window_resized)


func _anim_finished() -> void:
	%Play.button_pressed = false
	play_toggled(false)

func _frame_changed() -> void:
	set_frame(preview.frame)
	_update_preview()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if current_skin_setting:
			_update_animations()


func _update_animations() -> void:
	_set_controls_working(false)
	preview.sprite_frames = current_skin_setting.gen_animated_sprites(true)
	_set_controls_working(true)

## Disables/Enables controls for editing.
func _set_controls_working(val: bool) -> void:
	rect_x.editable = val
	rect_y.editable = val
	rect_w.editable = val
	rect_h.editable = val
	
	spinbox_frame.editable = val
	spinbox_speed.editable = val
	spinbox_frames.editable = val
	
	anim_option.disabled = !val
	state_option.disabled = !val
	%Play.disabled = !val
	%Stop.disabled = !val
	%Save.disabled = !val
	%Loop.disabled = !val
	%ReloadTexture.disabled = !val

#region FileButtons
## Called when "save" button pressed.
func save_pressed() -> void:
	save_dialog.popup_centered()

## Called when "open" button pressed.
func open_pressed() -> void:
	open_dialog.popup_centered()

## Called when "play" button toggled.
func play_toggled(toggle: bool) -> void:
	if toggle:
		%Play.text = "Pause Animation"
		preview.play()
	else:
		%Play.text = "Play Animation"
		preview.pause()
		_update_preview()

## Called when "stop" button pressed.
func stop_pressed() -> void:
	preview.stop()
	_update_preview()
	play_toggled(false)
	%Play.button_pressed = false

func loop_pressed(toggle: bool) -> void:
	current_skin_setting.animation_loops[preview.animation] = toggle
	preview.sprite_frames.set_animation_loop(preview.animation, toggle)

func reload_textures() -> void:
	_update_animations()
#endregion FileButtons

#region AnimationButtons
## Calls when "frame" spinbox changed.
func frame_val_changed(value: float) -> void:
	set_frame(int(spinbox_frame.value))

## Calls when "speed" spinbox changed
func speed_val_changed(value: float) -> void:
	set_anim_speed(float(value))

## Calls when "frames" spinbox changed
func frames_val_changed(value: float) -> void:
	set_frames(int(value))

## Calls when "duration" spinbox changed
func duration_val_changed(value: float) -> void:
	set_duration(float(value))
#region SpinboxSetters

# Use this setters to set a value
## Setter for current frame of current animation, changes "frame" spinbox value. 
func set_frame(value: int) -> void:
	var max_frames: int = preview.sprite_frames.get_frame_count(preview.animation)
	if value < 0: # Warp value
		value = max_frames
	elif value >= max_frames:
		value = 0
	
	spinbox_frame.value = value
	
	if preview.animation:
		preview.frame = value
	
	_update_preview()

var _last_frame_amount: int 

## Setter for current amount of frames in current animation, changes "frames" spinbox value.
func set_frames(value: int) -> void:
	value = max(value, 1)
	spinbox_frames.value = value
	
	if _last_frame_amount < value:
		print("Adding a new frame!")
		if preview.animation:
			var new_atlas: AtlasTexture = preview.sprite_frames.get_frame_texture(preview.animation, preview.frame).duplicate()
			preview.sprite_frames.add_frame(
				preview.animation,
				new_atlas
				)
			current_skin_setting.animation_regions[preview.animation].push_back(new_atlas.region)
	
	elif _last_frame_amount > value:
		if preview.animation:
			var max_frames: int = preview.sprite_frames.get_frame_count(preview.animation) - 1
			preview.sprite_frames.remove_frame(preview.animation, max_frames)
			current_skin_setting.animation_regions[preview.animation].pop_back()
			
	
	_last_frame_amount = value

## Setter for current speed of selected animation, changes "speed" spinbox value. 
func set_anim_speed(value: float) -> void:
	value = clampf(value, 0.0, 120.0)
	
	spinbox_speed.value = value
	
	current_skin_setting.animation_speeds[preview.animation] = value
	
	if preview.animation:
		preview.sprite_frames.set_animation_speed(preview.animation, value)

## Setter for current duration of selected animation, changes "duration" spinbox value. 
func set_duration(value: float) -> void:
	value = clampf(value, 0.0, 120.0)
	
	spinbox_speed.value = value
	
	current_skin_setting.animation_speeds[preview.animation] = value
	
	if preview.animation:
		preview.sprite_frames.set_animation_speed(preview.animation, value)
#endregion SpinboxSetters

## Calls when "Animation" option button changes selected item.
func set_animation(idx: int) -> void:
	var anim_name: String = anim_option.get_item_text(idx)
	preview.animation = anim_name
	
	set_anim_speed(preview.sprite_frames.get_animation_speed(anim_name))
	_update_preview()
	var frame_count: int = preview.sprite_frames.get_frame_count(preview.animation)
	_last_frame_amount = frame_count
	set_frames(frame_count)
	
	%Loop.button_pressed = preview.sprite_frames.get_animation_loop(anim_name)
	play_toggled(false)
	%Play.button_pressed = false

## Calls when "Powerup" A.K.A (State) option button changes selected item.
func set_state(idx: int) -> void:
	var state: String = state_option.get_item_text(idx)
	
	#if !skin_settings.has(state):
	#	return OS.alert("Please make sure ")
	current_skin_setting = skin_settings[state]
	preview.sprite_frames = current_skin_setting.gen_animated_sprites()
	#state_option.select(state)
	update_anim_options()
	
	anim_option.select(0)
	set_animation(0)
	set_frame(0)
	
	#current_skin_setting.rebuild_all_animations()
	#await current_skin_setting.rebuild_all_done

## Updates preview(animated sprite).
func _update_preview() -> void:
	var frame := preview.frame
	var texture := preview.sprite_frames.get_frame_texture(anim_option.get_item_text(anim_option.selected), frame)
	
	if texture is AtlasTexture:
		sprite_view.texture = texture.atlas
		sprite_view.rect_draw = texture.region
		current_frame = texture
		_rect_to_spin_val(texture.region)
	else:
		sprite_view.texture = texture

## Updates current frame of animation.
func _update_rect_slice() -> void:
	var frame := preview.frame
	var texture := preview.sprite_frames.get_frame_texture(anim_option.get_item_text(anim_option.selected), frame)
	
	if texture is AtlasTexture:
		sprite_view.texture = texture.atlas
		texture.region = _spin_val_to_rect()
		sprite_view.rect_draw = texture.region

## Gets value of spinboxes(rect_x, rect_y, rect_w, rect_h) and turns it in Rect2.
func _spin_val_to_rect() -> Rect2:
	return Rect2(rect_x.value, rect_y.value, rect_w.value, rect_h.value)
	
## Gets rect2 and sets it in spinboxes(rect_x, rect_y, rect_w, rect_h).
func _rect_to_spin_val(val: Rect2) -> void:
	rect_x.value = val.position.x
	rect_y.value = val.position.y
	rect_w.value = val.size.x
	rect_h.value = val.size.y

#endregion AnimationButtons

#region PreviewRect 
enum RECT_COMP{
	X = 0,
	Y,
	W,
	H
}

## Calls when any of spinboxes (rect_x, rect_y, rect_w, rect_h)
func update_rect(value: float, rect_comp: RECT_COMP) -> void:
	match rect_comp:
		RECT_COMP.X:
			rect_x.value = value
		RECT_COMP.Y:
			rect_y.value = value
		RECT_COMP.W:
			rect_w.value = value
		RECT_COMP.H:
			rect_h.value = value
	
	var rect := _spin_val_to_rect()
	current_frame.region = rect
	preview.queue_redraw()
	current_skin_setting.animation_regions[preview.animation][preview.frame] = rect
	_update_rect_slice()

#endregion PreviewRect

## Saves folders where skins located.
func save_file(path: String) -> void:
	for skin in skin_settings.keys():
		var full_path: String = path + "/" + skin + "/"
		print(skin)
		var dir_acc: DirAccess = DirAccess.open(path)
		if !dir_acc.dir_exists(skin):
			dir_acc.make_dir(skin)
		ResourceSaver.save(skin_settings[skin], full_path + "/skin_settings.tres")


## Opens folder where skins located.
func open_file(path: String) -> void:
	print("Loading folder content: %s" % path)
	current_folder_skin = path
	
	var has_basic_struct: bool
	for dir in DirAccess.get_directories_at(current_folder_skin):
		if dir == PlayerSkin.STATES[0]:
			has_basic_struct = true
		var settings_path := path + "/" + dir + "/" + "skin_settings.tres"
		
		if !FileAccess.file_exists(settings_path):
			print("No skin for: " + settings_path)
			continue
		
		skin_settings[dir] = ResourceLoader.load(settings_path, "Resource", ResourceLoader.CACHE_MODE_REPLACE)
	
	if !has_basic_struct:
		OS.alert("The folder specified does not contain a directory named '%s'" % PlayerSkin.STATES[0])
		open_dialog.popup_centered.call_deferred()
		return
	set_state(0)
	
	_set_controls_working(true)
	
	# TODO: Make validation for resource


func new_pressed() -> void:
	pass # Replace with function body.


## Disables animation that unavalible for current state.
func update_anim_options() -> void:
	var frames: SpriteFrames = current_skin_setting.gen_animated_sprites()
	preview.sprite_frames = frames
	
	for i in anim_option.item_count:
		var anim: String = anim_option.get_item_text(i)
		
		if !frames.has_animation(anim):
			anim_option.set_item_disabled(i, true)
		else:
			anim_option.set_item_disabled(i, false)


func _on_h_split_container_dragged(_offset: int) -> void:
	_on_window_resized()

func _on_window_resized() -> void:
	var size_x = %FrameHSplitter.size.x
	#print(size_x)
	if %FrameHSplitter.split_offset < -size_x + 384:
		%FrameHSplitter.split_offset = -size_x + 384
