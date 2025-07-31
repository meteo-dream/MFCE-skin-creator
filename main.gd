extends Control

const PROJECT_NAME := "MF: CE Skin Editor v%s"

const BAD_NAMES = [
	"object", "script", "_init", "_enter_tree", "_exit_tree", "_ready",
	"_process", "extends", "refcounted", "func ", "func()",
]
const SETTINGS_DICT_NAMES = [
	"animation_speeds", "animation_regions", "animation_loops", "animation_durations",
]
@onready var version_label: Label = %VersionLabel
@onready var version_string: String = ProjectSettings.get_setting("application/config/version", "")

@onready var save_dialog: FileDialog = $SaveDialog
@onready var open_dialog: FileDialog = $OpenDialog
@onready var new_save_dialog: FileDialog = $NewSaveDialog

@onready var modal_window: Window = %ModalWindow
@onready var confirm_dialog: ConfirmationDialog = %ConfirmationDialog
@onready var confirm_new_state: ConfirmationDialog = %ConfirmationNewState
@onready var image_creation_dialog: AcceptDialog = %ImageCreationDialog
@onready var options_dialog: Window = %OptionsDialog
@onready var about_window: Window = %AboutWindow

var skin_settings: Dictionary
var current_skin_setting: PlayerSkin
var misc_files: Dictionary

var current_folder_skin: String
var skin_name: String

@onready var preview: AnimatedSprite2D = %Preview
@onready var scene: Node2D = get_tree().current_scene
@onready var sprite_view: SpriteView = %SpriteView

@onready var spinbox_frame: SpinBox = %Frame
@onready var spinbox_speed: SpinBox = %Speed
@onready var spinbox_frames: SpinBox = %Frames
@onready var spinbox_duration: SpinBox = %Duration

@onready var anim_option: OptionButton = %AnimOption
@onready var state_option: OptionButton = %StateSelect

# Rect2
@onready var rect_x: SpinBox = %RectX
@onready var rect_y: SpinBox = %RectY
@onready var rect_w: SpinBox = %RectW
@onready var rect_h: SpinBox = %RectH

var current_frame: AtlasTexture
var pending_state: int
var pending_frames: int
var no_frame_del_popup: bool

@onready var confirm_state_text := confirm_new_state.dialog_text

func _ready() -> void:
	_set_controls_working(false)
	if DisplayServer.get_swap_cancel_ok():
		var options_par = options_dialog.get_node("MarginContainer/VBoxContainer3/HBoxContainer")
		options_par.move_child(options_par.get_node("OK"), 1)
		options_par.move_child(options_par.get_node("Cancel"), 3)
		var modal_par = modal_window.get_node("MarginContainer/VBoxContainer/HBoxContainer")
		modal_par.move_child(modal_par.get_node("OK"), 1)
		modal_par.move_child(modal_par.get_node("Cancel"), 3)
	
	anim_option.gui_input.connect(func(event: InputEvent):
		if anim_option.disabled: return
		if event is InputEventMouseButton && event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var idx = _get_option_scrolled_index(anim_option, 1)
				anim_option.select(idx)
				set_animation(idx)
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				var idx = _get_option_scrolled_index(anim_option, -1)
				anim_option.select(idx)
				set_animation(idx)
	)
	
	save_dialog.title = "Save Directory (Skin Root Folder)"
	save_dialog.dir_selected.connect(save_file)
	open_dialog.title = "Open a Directory (Skin Root Folder)"
	open_dialog.dir_selected.connect(open_file)
	new_save_dialog.dir_selected.connect(new_save_file)
	new_save_dialog.title = "Save Directory"
	#open_dialog.popup_centered()
	
	for anim in PlayerSkin.ANIMS:
		anim_option.add_item(anim)
	
	for state in PlayerSkin.STATES:
		state_option.add_item(state)
	
	#get_viewport().gui_focus_changed
	
	get_tree().root.min_size = Vector2(400, 400)
	get_tree().root.size_changed.connect(_on_window_resized)
	
	version_label.text = PROJECT_NAME % [version_string]


func _anim_finished() -> void:
	%Play.button_pressed = false
	play_toggled(false)

func _frame_changed() -> void:
	set_frame(preview.frame)
	_update_preview()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if !%Autoreload.button_pressed: return
		if current_skin_setting:
			_update_animations()
			update_anim_options()


func _update_animations() -> void:
	_set_controls_working(false)
	var prev_frame: int = int(spinbox_frame.value)
	preview.sprite_frames = current_skin_setting.gen_animated_sprites(true)
	set_frame(prev_frame)
	update_anim_time()
	_set_controls_working(true)

func _get_option_scrolled_index(_option: OptionButton, by: int) -> int:
	for i in _option.item_count:
		var idx = wrapi(_option.get_selected_id() + by + (i * signi(by)), 0, _option.item_count)
		if !_option.is_item_disabled(idx):
			return idx
	return _option.get_selected_id()

## Disables/Enables controls for editing.
func _set_controls_working(val: bool) -> void:
	rect_x.editable = val
	rect_y.editable = val
	rect_w.editable = val
	rect_h.editable = val
	
	spinbox_frame.editable = val
	spinbox_speed.editable = val
	spinbox_frames.editable = val
	spinbox_duration.editable = val
	
	anim_option.disabled = !val
	state_option.disabled = !val
	%Play.disabled = !val
	%Stop.disabled = !val
	%Save.disabled = !val
	%SaveAs.disabled = !val
	%Loop.disabled = !val
	%ReloadTexture.disabled = !val
	%Browse.disabled = !val
	%FillBlanks.disabled = !val
	%Options.disabled = !val

#region FileButtons
## Called when "save" button is pressed.
func save_pressed() -> void:
	if !current_folder_skin:
		save_dialog.popup_centered()
	else:
		save_file(current_folder_skin)

## Called when "save as" button is pressed.
func save_as_pressed() -> void:
	save_dialog.popup_centered()

## Called when "open" button is pressed.
func open_pressed() -> void:
	open_dialog.popup_centered()

## Called when "new" button is pressed.
func new_pressed() -> void:
	new_save_dialog.popup_centered()

## Called when "play" button toggled.
func play_toggled(toggle: bool) -> void:
	if toggle:
		%Play.text = "Pause"
		preview.play()
	else:
		%Play.text = "Play"
		preview.pause()
		_update_preview()

## Called when "stop" button gets pressed.
func stop_pressed() -> void:
	preview.stop()
	_update_preview()
	play_toggled(false)
	%Play.button_pressed = false

## Called when "loop" checkbox gets toggled.
func loop_pressed(toggle: bool) -> void:
	current_skin_setting.animation_loops[preview.animation] = toggle
	preview.sprite_frames.set_animation_loop(preview.animation, toggle)

## Called when "create anims" button gets pressed.
func _on_fill_blanks_pressed() -> void:
	confirm_new_state.dialog_text = confirm_state_text % [
		current_folder_skin.path_join(state_option.get_item_text(state_option.get_selected_id()))
	]
	remove_theme_stylebox_override(&"normal")
	confirm_new_state.popup_centered()

func reload_textures() -> void:
	_update_animations()
	update_anim_options()

func _on_browse_pressed() -> void:
	print("Browsing: " + current_folder_skin.path_join(current_skin_setting.name))
	OS.shell_open(current_folder_skin.path_join(current_skin_setting.name))
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
		value = max_frames - 1
	elif value >= max_frames:
		value = 0
	
	spinbox_frame.value = value
	
	if preview.animation:
		preview.frame = value
		set_duration(preview.sprite_frames.get_frame_duration(preview.animation, value))
	
	_update_preview()

var _last_frame_amount: int
var _frame_setter_cooldown: bool

func _process(_delta: float) -> void:
	if _frame_setter_cooldown:
		if modal_window.visible: return
		_frame_setter_cooldown = false

## Setter for current amount of frames in current animation, changes "frames" spinbox value.
func set_frames(value: int) -> void:
	value = max(value, 1)
	if modal_window.visible: return
	if !_frame_setter_cooldown && _last_frame_amount > value && !no_frame_del_popup:
		modal_window.size = Vector2i(100, 100)
		modal_window.popup_centered()
		pending_frames = value
		spinbox_frames.value = _last_frame_amount
		return
	spinbox_frames.value = value
	
	prints(_last_frame_amount, value)
	
	# BUG: This should be a loop
	if _last_frame_amount < value:
		print("Adding a new frame!")
		if preview.animation:
			var new_atlas: AtlasTexture = preview.sprite_frames.get_frame_texture(preview.animation, preview.frame).duplicate()
			current_skin_setting.animation_durations[preview.animation].append(1.0)
			preview.sprite_frames.add_frame(
				preview.animation,
				new_atlas
			)
			current_skin_setting.animation_regions[preview.animation].push_back(new_atlas.region)
		update_anim_time()
	
	elif _last_frame_amount > value:
		if preview.animation:
			var max_frames: int = preview.sprite_frames.get_frame_count(preview.animation) - 1
			preview.sprite_frames.remove_frame(preview.animation, max_frames)
			current_skin_setting.animation_regions[preview.animation].pop_back()
			current_skin_setting.animation_durations[preview.animation].pop_back()
		update_anim_time()
	
	_last_frame_amount = value

## Setter for current speed of selected animation, changes "speed" spinbox value. 
func set_anim_speed(value: float) -> void:
	value = clampf(value, 0.0, 120.0)
	
	spinbox_speed.value = value
	
	current_skin_setting.animation_speeds[preview.animation] = value
	
	if preview.animation:
		preview.sprite_frames.set_animation_speed(preview.animation, value)
	update_anim_time()

## Setter for current duration of selected animation, changes "duration" spinbox value. 
func set_duration(value: float) -> void:
	value = clampf(value, 0.0, 120.0)
	
	spinbox_duration.value = value
	
	current_skin_setting.animation_durations[preview.animation][preview.frame] = value
	
	if preview.animation:
		var texture = preview.sprite_frames.get_frame_texture(preview.animation, preview.frame)
		preview.sprite_frames.set_frame(preview.animation, preview.frame, texture, value)
	update_anim_time()
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
	set_duration(preview.sprite_frames.get_frame_duration(preview.animation, preview.frame))
	update_anim_time()
	
	%Loop.button_pressed = preview.sprite_frames.get_animation_loop(anim_name)
	play_toggled(false)
	%Play.button_pressed = false

var _last_state: int = -1

## Calls when "Powerup" A.K.A (State) option button changes selected item.
func set_state(idx: int) -> void:
	var state: String = state_option.get_item_text(idx)
	
	if !skin_settings.has(state):
		pending_state = idx
		if _last_state != -1:
			state_option.select(_last_state)
		return ask_about_missing_state()
	_last_state = idx
	current_skin_setting = skin_settings[state]
	preview.sprite_frames = current_skin_setting.gen_animated_sprites()
	#state_option.select(state)
	update_anim_options()
	
	if !preview.sprite_frames.has_animation(&"appear"):
		return
	anim_option.select(0)
	set_animation(0)
	set_frame(0)
	
	#current_skin_setting.rebuild_all_animations()
	#await current_skin_setting.rebuild_all_done

## Updates preview(animated sprite).
func _update_preview() -> void:
	var frame := preview.frame
	var item_text := anim_option.get_item_text(anim_option.selected)
	if !preview.sprite_frames.has_animation(item_text):
		push_warning("Preview update fail: Animation '%s' doesn't exist." % [item_text])
		return
	var texture := preview.sprite_frames.get_frame_texture(item_text, frame)
	
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
	current_folder_skin = path
	skin_name = path.get_slice("/", path.get_slice_count("/") - 1)
	version_label.text = PROJECT_NAME % [version_string] + ("\n" + current_folder_skin)
	reset_options_dialog()
	for skin in skin_settings.keys():
		var full_path: String = path + "/" + skin + "/"
		print("Saving skin: " + skin)
		var dir_acc: DirAccess = DirAccess.open(path)
		if !dir_acc.dir_exists(skin):
			dir_acc.make_dir(skin)
		var err = ResourceSaver.save(skin_settings[skin], full_path + "/skin_settings.tres")
		if err:
			OS.alert("Error: " + error_string(err), "Save Failed!")

## Opens folder where skins located.
func open_file(path: String) -> void:
	print("Loading folder content: %s" % path)
	current_folder_skin = path
	
	var has_basic_struct: bool
	for dir in DirAccess.get_directories_at(path):
		if dir == PlayerSkin.STATES[0]:
			has_basic_struct = true
		
		if load_skin_settings_from_file(dir, path):
			continue
	
	if !has_basic_struct:
		OS.alert("Please select a skin root directory that contains suit folders.")
		open_dialog.current_dir = path
		open_dialog.popup_centered.call_deferred()
		return
	
	load_misc_files(path)
	
	skin_name = path.get_slice("/", path.get_slice_count("/") - 1)
	reset_options_dialog()
	set_state(0)
	state_option.select(0)
	version_label.text = PROJECT_NAME % [version_string] + ("\n" + current_folder_skin)
	
	_set_controls_working(true)

## Creates new skin in a specified folder.
func new_save_file(path: String) -> void:
	if DirAccess.dir_exists_absolute(path.path_join("small")):
		return OS.alert("Directory is not empty!")
	print("Creating new skin at: %s" % path)
	var err: String = AnimGenerator.gen_image_files("small", path)
	image_creation_dialog.dialog_text = err
	image_creation_dialog.popup_centered()
	if "Error" in err: return
	
	# Resetting all variables in case a previous skin was loaded
	skin_settings = {}
	current_folder_skin = path
	pending_state = 0
	misc_files = {}
	load_misc_files(path)
	_on_dialog_new_settings_confirmed()
	
	skin_name = path.get_slice("/", path.get_slice_count("/") - 1)
	reset_options_dialog()
	set_state(0)
	state_option.select(0)
	version_label.text = PROJECT_NAME % [version_string] + ("\n" + current_folder_skin)
	
	_set_controls_working(true)

## Loads skin_settings.tres from file system. Returns true if failed.
func load_skin_settings_from_file(suit: String, path: String) -> bool:
	var settings_path := path + "/" + suit + "/" + "skin_settings.tres"
		
	if !FileAccess.file_exists(settings_path):
		print("No skin for: " + settings_path)
		return true
	
	skin_settings[suit] = _load_skin_settings(settings_path, suit)
	return false

# We are parsing the file manually to avoid malicious code execution, while still maintaining
# compatibility with old skins! Although any mention of scripts is now ignored.
func _load_skin_settings(path: String, power: String) -> PlayerSkin:
	var output := PlayerSkin.new()
	var file = FileAccess.open(path, FileAccess.READ)
	if !file:
		OS.alert("Error accessing skin settings at:
	%s" % path)
		return null
	if file.get_length() > 2_097_152:
		OS.alert("Error: File is larger than the limit of 2 MB:
	%s" % path)
		return null
	
	var reading_buffer: String
	var dict_index_buffer: Dictionary = {}
	
	while !file.eof_reached():
		var line = file.get_line()
		if reading_buffer.is_empty():
			for i in SETTINGS_DICT_NAMES:
				if line.begins_with(i) && !i in dict_index_buffer:
					reading_buffer = i
					dict_index_buffer[reading_buffer] = []
		if reading_buffer.is_empty():
			continue
		var starting_pos: int
		if len(dict_index_buffer[reading_buffer]) == 0:
			var ind_start = line.find("{")
			if ind_start >= 0:
				dict_index_buffer[reading_buffer].append(file.get_position() - len(line) + ind_start - 1)
				starting_pos = ind_start
		if len(dict_index_buffer[reading_buffer]) == 1:
			var ind_start = line.find("}", starting_pos)
			if ind_start >= 0:
				dict_index_buffer[reading_buffer].append(file.get_position() - len(line) + ind_start - 1)
				reading_buffer = ""
				continue
	
	for i in dict_index_buffer:
		if len(dict_index_buffer[i]) != 2:
			print("Array size mismatch: %s" % i)
			continue
		file.seek(dict_index_buffer[i][0])
		
		var dict_str: String = file.get_buffer(dict_index_buffer[i][1] - dict_index_buffer[i][0]).get_string_from_utf8()
		if !dict_str: continue
		
		dict_str += "}"
		var clean_dict: String = dict_str
		for bad_string in BAD_NAMES:
			clean_dict = clean_dict.replacen(bad_string, "")
		var parsed = str_to_var(clean_dict)
		#print(parsed)
		if parsed && parsed is Dictionary:
			output[i] = parsed
		else:
			print_rich("[color=orange][Skins Manager] Warning: %s: Field %s is invalid. Loaded defaults.[/color]" % [power, i])
	
	output.name = power
	output.res_path = path.get_base_dir()
	return output

## Loads txt files
func load_misc_files(path: String) -> void:
	misc_files.name = ""
	if FileAccess.file_exists(path.path_join("name.txt")):
		misc_files.name = FileAccess.get_file_as_string(path.path_join("name.txt")).left(15)
	misc_files.story = ["", "", ""]
	var file_path = path.path_join("story.txt")
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			for i in 3:
				if file.eof_reached(): break
				var _line = file.get_line().left(15 if i < 2 else 50)
				if _line:
					misc_files.story[i] = _line

## Disables animations that are unavailable for current state.
func update_anim_options() -> void:
	var frames: SpriteFrames = current_skin_setting.gen_animated_sprites()
	preview.sprite_frames = frames
	
	for i in anim_option.item_count:
		var anim: String = anim_option.get_item_text(i)
		
		if !frames.has_animation(anim):
			anim_option.set_item_disabled(i, true)
		else:
			anim_option.set_item_disabled(i, false)

## Updates animation duration display counter.
func update_anim_time() -> void:
	if !preview.animation || !preview.sprite_frames:
		%AnimTime.text = "-"
		return
	var frame_count = preview.sprite_frames.get_frame_count(preview.animation)
	if frame_count > 100:
		%AnimTime.text = "Too long"
		return
	var number: float = 0.0
	for i in frame_count:
		var relative_duration = preview.sprite_frames.get_frame_duration(preview.animation, i)
		var absolute_duration = relative_duration / abs(preview.sprite_frames.get_animation_speed(preview.animation))
		number += absolute_duration
		
	if is_finite(number) && number > 999:
		%AnimTime.text = "999+ sec"
		return
	%AnimTime.text = "%s sec" % String.num(number, 4)

## Logic for side panel resizing.
func _on_h_split_container_dragged(_offset: int) -> void:
	_on_window_resized()

func _on_window_resized() -> void:
	var size_x = %FrameHSplitter.size.x
	if %FrameHSplitter.split_offset < -size_x + 384:
		%FrameHSplitter.split_offset = -size_x + 384

#region ModalBoxActions
## Displayed when decreasing total frames count
func _on_fill_blanks_ok_pressed() -> void:
	if !modal_window.visible: return
	if %DontAskAgain.button_pressed:
		no_frame_del_popup = true
	modal_window.hide()
	print("Reducing total frame count to %d" % pending_frames)
	_frame_setter_cooldown = true
	set_frames(pending_frames)

## "This suit is incomplete. Create default animation settings?"
func ask_about_missing_state() -> void:
	if confirm_dialog.visible: return
	confirm_dialog.popup_centered()

## The "This action will create placeholder image files..." confirmation action
func _on_dialog_new_state_confirmed() -> void:
	var suit_name := current_skin_setting.name
	var out := AnimGenerator.gen_image_files(suit_name, current_folder_skin)
	#load_skin_settings_from_file(suit_name, current_folder_skin)
	#current_skin_setting = skin_settings[suit_name]
	_update_animations()
	update_anim_options()
	image_creation_dialog.dialog_text = out
	image_creation_dialog.popup_centered()

## The "This suit is incomplete..." confirmation action
func _on_dialog_new_settings_confirmed() -> void:
	var item := state_option.get_item_text(pending_state)
	var er := AnimGenerator.copy_settings(item, current_folder_skin)
	if er != "Success":
		return OS.alert(er)
	
	if load_skin_settings_from_file(item, current_folder_skin):
		return
	
	state_option.select(pending_state)
	set_state(pending_state)

## Skin Options button
func options_pressed() -> void:
	if options_dialog.visible:
		if options_dialog.mode == Window.MODE_MINIMIZED:
			options_dialog.mode = Window.MODE_WINDOWED
		options_dialog.grab_focus()
		return
	options_dialog.popup_centered()

func reset_options_dialog() -> void:
	options_dialog.hide()
	%DisplayNameLine.placeholder_text = skin_name.to_upper()
	%DisplayNameLine.text = misc_files.name
	%TheyLine.text = misc_files.story[0]
	%ThemLine.text = misc_files.story[1]
	%DescriptionLine.text = misc_files.story[2]

func options_confirmed() -> void:
	options_dialog.hide()
	
	if %DisplayNameLine.text != misc_files.name:
		misc_files.name = %DisplayNameLine.text
		var file = FileAccess.open(current_folder_skin.path_join("name.txt"), FileAccess.WRITE)
		file.store_line(misc_files.name)
		file.close()
	if (
		%TheyLine.text != misc_files.story[0] ||
		%ThemLine.text != misc_files.story[1] ||
		%DescriptionLine.text != misc_files.story[2]
	):
		misc_files.story[0] = %TheyLine.text
		misc_files.story[1] = %ThemLine.text
		misc_files.story[2] = %DescriptionLine.text
		var file = FileAccess.open(current_folder_skin.path_join("story.txt"), FileAccess.WRITE)
		file.store_line(misc_files.story[0])
		file.store_line(misc_files.story[1])
		file.store_line(misc_files.story[2])
		file.close()

#endregion ModalBoxActions


func _on_display_name_line_text_changed(new_text: String) -> void:
	%DisplayNameLine.text = new_text.to_upper()


func _on_about_pressed() -> void:
	if about_window.visible:
		if about_window.mode == Window.MODE_MINIMIZED:
			about_window.mode = Window.MODE_WINDOWED
		about_window.grab_focus()
		return
	about_window.show()
