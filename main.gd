extends Control

@onready var save_dialog: FileDialog = $SaveDialog
@onready var open_dialog: FileDialog = $OpenDialog

var skin_settings: Dictionary
var current_skin_setting: PlayerSkin

var current_folder_skin: String


@onready var preview: AnimatedSprite2D = %Preview
@onready var scene: Node2D = get_parent().get_parent()

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
	
	save_dialog.dir_selected.connect(save_file)
	open_dialog.dir_selected.connect(open_file)
	open_dialog.popup_centered()
	#open_dialog.current_path = mf_cam_path
	
	
	for anim in PlayerSkin.ANIMS:
		anim_option.add_item(anim)
	
	for state in PlayerSkin.STATES:
		state_option.add_item(state)
	
	#open_file(test)

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


#region FileButtons
func save_pressed() -> void:
	save_dialog.popup_centered()

func open_pressed() -> void:
	open_dialog.popup_centered()

func play_toggled(toggle: bool) -> void:
	if toggle:
		preview.play()
	else:
		preview.pause()
		_update_preview()

func stop_pressed() -> void:
	preview.stop()
	_update_preview()

#endregion FileButtons

#region AnimationButtons
func frame_val_changed(value: float) -> void:
	set_frame(int(spinbox_frame.value))

func speed_val_changed(value: float) -> void:
	set_anim_speed(int(value))

func frames_val_changed(value: float) -> void:
	set_frames(int(value))

# setters
func set_frame(value: int) -> void:
	var max_frames: int = preview.sprite_frames.get_frame_count(preview.animation)
	#print(value)
	if value < 0:
		value = max_frames
	elif value >= max_frames:
		value = 0
	
	spinbox_frame.value = value
	
	if preview.animation:
		preview.frame = value
	
	_update_preview()

var _last_frame_amount: int 

func set_frames(value: int) -> void:
	value = clampi(value, 1, 255)
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

func set_anim_speed(value: int) -> void:
	value = clampi(value, 0, 120)
	
	spinbox_speed.value = value
	
	current_skin_setting.animation_speeds[preview.animation] = value
	
	if preview.animation:
		preview.sprite_frames.set_animation_speed(preview.animation, value) 


func set_animation(idx: int) -> void:
	var anim_name: String = anim_option.get_item_text(idx)
	preview.animation = anim_name
	
	set_anim_speed(preview.sprite_frames.get_animation_speed(anim_name))
	_update_preview()
	var frame_count: int = preview.sprite_frames.get_frame_count(preview.animation)
	_last_frame_amount = frame_count
	set_frames(frame_count)


func set_state(idx: int) -> void:
	var state: String = state_option.get_item_text(idx)
	
	current_skin_setting = skin_settings[state]
	preview.sprite_frames = current_skin_setting.gen_animated_sprites()
	#state_option.select(state)
	update_anim_options()
	
	anim_option.select(0)
	set_animation(0)
	set_frame(0)
	
	var frame_count: int = preview.sprite_frames.get_frame_count(preview.animation)
	_last_frame_amount = frame_count
	set_frames(frame_count)


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


func _update_rect_slice() -> void:
	var frame := preview.frame
	var texture := preview.sprite_frames.get_frame_texture(anim_option.get_item_text(anim_option.selected), frame)
	
	if texture is AtlasTexture:
		sprite_view.texture = texture.atlas
		texture.region = _spin_val_to_rect()
		sprite_view.rect_draw = texture.region

func _spin_val_to_rect() -> Rect2:
	return Rect2(rect_x.value, rect_y.value, rect_w.value, rect_h.value)

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

func save_file(path: String) -> void:
	for skin in skin_settings.keys():
		var full_path: String = path + "/" + skin + "/"
		print(skin)
		var dir_acc: DirAccess = DirAccess.open(path)
		if !dir_acc.dir_exists(skin):
			dir_acc.make_dir(skin)
		ResourceSaver.save(skin_settings[skin], full_path + "/skin_settings.tres")
	

func open_file(path: String) -> void:
	print("Loading folder conent: %s" % path)
	current_folder_skin = path
	
	for dir in DirAccess.get_directories_at(current_folder_skin):
		var settings_path := path + "/" + dir + "/" + "skin_settings.tres"
		
		if !FileAccess.file_exists(settings_path):
			print("No skin for: " + settings_path)
			continue
		
		skin_settings[dir] = ResourceLoader.load(settings_path, "Resource", ResourceLoader.CACHE_MODE_REPLACE)
	
	set_state(0)
	
	_set_controls_working(true)
	
	# TODO: Make validation for resource
	

func update_anim_options() -> void:
	var frames: SpriteFrames = current_skin_setting.gen_animated_sprites()
	preview.sprite_frames = frames
	
	for i in anim_option.item_count:
		var anim: String = anim_option.get_item_text(i)
		
		if !frames.has_animation(anim):
			anim_option.set_item_disabled(i, true)
		else:
			anim_option.set_item_disabled(i, false)
