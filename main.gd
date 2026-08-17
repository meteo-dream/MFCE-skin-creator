extends Control
class_name Main

const PROJECT_NAME := "MF: CE Skin Editor v%s"

enum FileMenu { NEW, OPEN, SAVE, SAVE_AS }
enum EditorMenu { SETTINGS, SEP_EDITOR, SHOW_COLLISION, AUTORELOAD }
enum SkinMenu { CREATE_MISSING, BROWSE_ANIM, RELOAD, SEP_OVERRIDES, BROWSE_OVERRIDES, SEP_SKIN, OPTIONS }
enum HelpMenu { ABOUT }

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
@onready var editor_settings_window: Window = %EditorSettings

var skin_settings: Dictionary
var current_skin_setting: PlayerSkin
var misc_files: Dictionary

var current_folder_skin: String
var skin_name: String
var _loop_offsets: Dictionary = {}

@onready var preview: AnimatedSprite2D = %Preview
@onready var scene: Node2D = get_tree().current_scene
@onready var frames_strip: FramesStrip = %FramesDock
@onready var add_frames_dialog: AddFramesDialog = %AddFramesDialog
@onready var edit_frame_dialog: EditFrameDialog = %EditFrameDialog

@onready var spinbox_frame: SpinBox = %Frame
@onready var spinbox_speed: SpinBox = %Speed
@onready var spinbox_frames: SpinBox = %Frames
@onready var spinbox_duration: SpinBox = %Duration

@onready var anim_option: OptionButton = %AnimOption
@onready var state_option: OptionButton = %StateSelect

var current_frame: AtlasTexture
var pending_state: int
var pending_frames: int
var no_frame_del_popup: bool
var unsaved_changes: bool#:
	#set(to):
		#var _start: String = "(*) " if to else ""
		#DisplayServer.window_set_title(_start + ProjectSettings.get_setting("application/config/name"))
		#unsaved_changes = to
var _updating_loop_offset := false

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
	
	var an_popup: PopupMenu = anim_option.get_popup()
	an_popup.max_size = DisplayServer.screen_get_usable_rect().size
	#an_popup.wrap_controls = false
	for anim in PlayerSkin.ANIMS:
		anim_option.add_item(anim)
	#an_popup.child_controls_changed()
	#anim_option.toggled.connect(_update_anim_option_size, CONNECT_DEFERRED)
	
	for state in PlayerSkin.STATES:
		state_option.add_item(state)
	
	frames_strip.frame_selected.connect(set_frame)
	frames_strip.frames_reordered.connect(_on_frames_reordered)
	frames_strip.add_frames_pressed.connect(_on_add_frames_pressed)
	frames_strip.edit_frame_pressed.connect(_on_edit_frame_pressed)
	frames_strip.delete_frame_pressed.connect(_on_delete_frame_pressed)
	add_frames_dialog.frames_chosen.connect(add_frames_from_rects)
	edit_frame_dialog.region_changed.connect(apply_frame_region)
	%File.id_pressed.connect(_on_file_menu_id_pressed)
	%Editor.id_pressed.connect(_on_editor_menu_id_pressed)
	%Skin.id_pressed.connect(_on_skin_menu_id_pressed)
	%Help.id_pressed.connect(_on_help_menu_id_pressed)
	%ThumbSize.value_changed.connect(_on_thumb_size_changed)
	
	get_tree().root.min_size = Vector2(400, 400)
	get_tree().root.size_changed.connect(_on_window_resized)
	
	version_label.text = PROJECT_NAME % [version_string]
	%WelcomeSubtitle.text = PROJECT_NAME % [version_string]
	_refresh_welcome_recents()
	
	await get_tree().process_frame
	_on_window_resized()


func _update_anim_option_size(to: bool) -> void:
	if !to: return
	var current_screen: int = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_usable_rect(current_screen).size
	var an_popup: PopupMenu = anim_option.get_popup()
	#an_popup.child_controls_changed()
	an_popup.min_size.y = min(an_popup.min_size.y, screen_size.y)
	an_popup.size.y = min(an_popup.min_size.y, an_popup.size.y)


func _anim_finished() -> void:
	%Play.button_pressed = false
	play_toggled(false)

func _anim_looped() -> void:
	if !preview:
		return
	for anim in _loop_offsets.keys():
		if int(_loop_offsets[anim]) < 0:
			continue
		if preview.animation == anim:
			preview.frame = int(_loop_offsets[anim])

func _frame_changed() -> void:
	set_frame(preview.frame)
	_update_preview()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if !%Editor.is_item_checked(%Editor.get_item_index(EditorMenu.AUTORELOAD)): return
		if current_skin_setting:
			_update_animations()
			update_anim_options()


func _update_animations() -> void:
	_set_controls_working(false)
	var prev_frame: int = int(spinbox_frame.value)
	preview.sprite_frames = current_skin_setting.gen_animated_sprites(true)
	_load_loop_offsets()
	set_frame(prev_frame)
	update_anim_time()
	_refresh_frames_strip()
	_set_controls_working(true)

func _get_option_scrolled_index(_option: OptionButton, by: int) -> int:
	for i in _option.item_count:
		var idx = wrapi(_option.get_selected_id() + by + (i * signi(by)), 0, _option.item_count)
		if !_option.is_item_disabled(idx):
			return idx
	return _option.get_selected_id()

## Disables/Enables controls for editing.
func _set_controls_working(val: bool) -> void:
	spinbox_frame.editable = val
	spinbox_speed.editable = val
	spinbox_frames.editable = val
	spinbox_duration.editable = val
	
	anim_option.disabled = !val
	state_option.disabled = !val
	%Play.disabled = !val
	%Stop.disabled = !val
	%Loop.disabled = !val
	%LoopOffset.editable = val
	%File.set_item_disabled(%File.get_item_index(FileMenu.SAVE), !val)
	%File.set_item_disabled(%File.get_item_index(FileMenu.SAVE_AS), !val)
	%Skin.set_item_disabled(%Skin.get_item_index(SkinMenu.CREATE_MISSING), !val)
	%Skin.set_item_disabled(%Skin.get_item_index(SkinMenu.BROWSE_ANIM), !val)
	%Skin.set_item_disabled(%Skin.get_item_index(SkinMenu.RELOAD), !val)
	%Skin.set_item_disabled(%Skin.get_item_index(SkinMenu.OPTIONS), !val)
	frames_strip.set_enabled(val)


func show_one_dialog(dialog: Window) -> void:
	if dialog.visible:
		if dialog.mode == Window.MODE_MINIMIZED:
			dialog.mode = Window.MODE_WINDOWED
		dialog.grab_focus()
		return
	dialog.show()
	if dialog is FileDialog && !dialog.force_native:
		return
	if dialog.content_scale_factor != scene.editor_scale:
		dialog.content_scale_factor = scene.editor_scale
		dialog.size *= scene.editor_scale
		dialog.min_size *= scene.editor_scale
		var usable_size = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen(0)).size
		if dialog.size.y > usable_size.y:
			dialog.size.y = usable_size.y
		if dialog.size.x > usable_size.x:
			dialog.size.x = usable_size.x
		dialog.move_to_center()

func popup_one_dialog(dialog: Window) -> void:
	if dialog.visible:
		if dialog.mode == Window.MODE_MINIMIZED:
			dialog.mode = Window.MODE_WINDOWED
		dialog.grab_focus()
		return
	dialog.popup_centered()
	if dialog is FileDialog && !dialog.force_native:
		return
	if dialog.content_scale_factor != scene.editor_scale:
		dialog.content_scale_factor = scene.editor_scale
		dialog.size *= scene.editor_scale
		dialog.min_size *= scene.editor_scale
		var usable_size = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen(0)).size
		if dialog.size.y > usable_size.y:
			dialog.size.y = usable_size.y
		if dialog.size.x > usable_size.x:
			dialog.size.x = usable_size.x
		dialog.move_to_center()


#region FileButtons
## Called when "save" button is pressed.
func save_pressed() -> void:
	if !current_folder_skin:
		popup_one_dialog(save_dialog)
	else:
		save_file(current_folder_skin)

## Called when "save as" button is pressed.
func save_as_pressed() -> void:
	popup_one_dialog(save_dialog)

## Called when "open" button is pressed.
func open_pressed() -> void:
	popup_one_dialog(open_dialog)

## Called when "new" button is pressed.
func new_pressed() -> void:
	popup_one_dialog(new_save_dialog)

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
	popup_one_dialog(confirm_new_state)

func reload_textures() -> void:
	_update_animations()
	update_anim_options()

func _on_browse_pressed() -> void:
	var _path := current_folder_skin.path_join(current_skin_setting.name)
	print("Browsing: " + _path)
	OS.shell_open(_path)

func _on_browse_overrides_pressed() -> void:
	print("Browsing: " + AnimOverrides.OVERRIDES_DIR)
	OS.shell_open(OS.get_user_data_dir().path_join("slicing_overrides"))


func _on_file_menu_id_pressed(id: int) -> void:
	match id:
		FileMenu.NEW:
			new_pressed()
		FileMenu.OPEN:
			open_pressed()
		FileMenu.SAVE:
			save_pressed()
		FileMenu.SAVE_AS:
			save_as_pressed()


func _on_editor_menu_id_pressed(id: int) -> void:
	match id:
		EditorMenu.SETTINGS:
			show_one_dialog(editor_settings_window)
		EditorMenu.SHOW_COLLISION:
			var idx: int = %Editor.get_item_index(id)
			%Editor.toggle_item_checked(idx)
			scene.show_collisions = %Editor.is_item_checked(idx)
		EditorMenu.AUTORELOAD:
			%Editor.toggle_item_checked(%Editor.get_item_index(id))


func _on_skin_menu_id_pressed(id: int) -> void:
	match id:
		SkinMenu.CREATE_MISSING:
			_on_fill_blanks_pressed()
		SkinMenu.BROWSE_ANIM:
			_on_browse_pressed()
		SkinMenu.RELOAD:
			reload_textures()
		SkinMenu.BROWSE_OVERRIDES:
			_on_browse_overrides_pressed()
		SkinMenu.OPTIONS:
			options_pressed()


func _on_help_menu_id_pressed(id: int) -> void:
	if id == HelpMenu.ABOUT:
		_on_about_pressed()


func _on_thumb_size_changed(value: float) -> void:
	frames_strip.set_thumb_size(int(value))
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
	set_frames.call_deferred(int(value))

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
	frames_strip.select_frame(value)

var _last_frame_amount: int
var _frame_setter_cooldown: bool
var _old_window_mode: DisplayServer.WindowMode

func _process(_delta: float) -> void:
	if Input.mouse_mode > Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if DisplayServer.window_get_mode() != _old_window_mode:
		_old_window_mode = DisplayServer.window_get_mode()
		_on_window_resized()
	if _frame_setter_cooldown:
		if modal_window.visible: return
		_frame_setter_cooldown = false

## Setter for current amount of frames in current animation, changes "frames" spinbox value.
func set_frames(value: int) -> void:
	value = max(value, 1)
	if modal_window.visible: return
	if !_frame_setter_cooldown && _last_frame_amount > value && !no_frame_del_popup:
		modal_window.size = Vector2i(100, 100)
		popup_one_dialog(modal_window)
		pending_frames = value
		spinbox_frames.value = _last_frame_amount
		return
	
	if !preview.animation:
		push_error("No preview animation; total frames will not change")
		return
	
	spinbox_frames.value = value
	#prints(_last_frame_amount, value)
	
	if _last_frame_amount < value:
		print("Adding new frames! Amount: %d" % [value - _last_frame_amount])
		for i in abs(value - _last_frame_amount):
			var new_atlas: AtlasTexture = preview.sprite_frames.get_frame_texture(preview.animation, preview.frame).duplicate()
			current_skin_setting.animation_durations[preview.animation].append(1.0)
			preview.sprite_frames.add_frame(
				preview.animation,
				new_atlas
			)
			current_skin_setting.animation_regions[preview.animation].push_back(new_atlas.region)
		update_anim_time()
		unsaved_changes = true
		set_frame(value - 1)
	
	elif _last_frame_amount > value:
		print("Deleting frames! Amount: %d" % [abs(value - _last_frame_amount)])
		for i in abs(_last_frame_amount - value):
			var max_frames: int = preview.sprite_frames.get_frame_count(preview.animation) - 1
			preview.sprite_frames.remove_frame(preview.animation, max_frames)
			current_skin_setting.animation_regions[preview.animation].pop_back()
			current_skin_setting.animation_durations[preview.animation].pop_back()
		update_anim_time()
		unsaved_changes = true
		prints("preview frame: ", spinbox_frame.value, value)
		if int(spinbox_frame.value) >= value:
			set_frame(value - 1)
	
	_last_frame_amount = value
	_refresh_frames_strip()
	_update_loop_offset_spin()

## Setter for current speed of selected animation, changes "speed" spinbox value. 
func set_anim_speed(value: float) -> void:
	value = clampf(value, 0.0, 120.0)
	
	#if spinbox_speed.value != value:
	#	unsaved_changes = true
	spinbox_speed.value = value
	
	current_skin_setting.animation_speeds[preview.animation] = value
	
	if preview.animation:
		preview.sprite_frames.set_animation_speed(preview.animation, value)
	update_anim_time()

## Setter for current duration of selected animation, changes "duration" spinbox value. 
func set_duration(value: float) -> void:
	value = clampf(value, 0.0, 120.0)
	
	#if spinbox_duration.value != value:
	#	unsaved_changes = true
	spinbox_duration.value = value
	
	current_skin_setting.animation_durations[preview.animation][preview.frame] = value
	
	if preview.animation:
		var texture = preview.sprite_frames.get_frame_texture(preview.animation, preview.frame)
		preview.sprite_frames.set_frame(preview.animation, preview.frame, texture, value)
	update_anim_time()
	frames_strip.update_item_text(preview.frame, value)
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
	_update_loop_offset_spin()
	play_toggled(false)
	%Play.button_pressed = false
	_refresh_frames_strip()

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
	_load_loop_offsets()
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
		current_frame = texture
	else:
		current_frame = null


func _refresh_frames_strip() -> void:
	if !preview.sprite_frames || !preview.animation:
		frames_strip.rebuild(null, &"", 0)
		return
	frames_strip.rebuild(preview.sprite_frames, preview.animation, preview.frame)


func _current_atlas() -> Texture2D:
	if !preview.sprite_frames || !preview.animation:
		return null
	var tex := preview.sprite_frames.get_frame_texture(preview.animation, preview.frame)
	if tex is AtlasTexture:
		return tex.atlas
	return tex


func apply_frame_region(rect: Rect2) -> void:
	if !current_frame:
		return
	current_frame.region = rect
	preview.queue_redraw()
	if current_skin_setting && preview.animation:
		current_skin_setting.animation_regions[preview.animation][preview.frame] = rect
	frames_strip.update_frame(preview.frame, preview.sprite_frames, preview.animation)


func add_frames_from_rects(rects: Array[Rect2], atlas: Texture2D) -> void:
	if !preview.animation || rects.is_empty():
		return
	var anim := preview.animation
	var regions: Array = current_skin_setting.animation_regions[anim]
	var durations: Array = current_skin_setting.animation_durations[anim]
	var at_position := -1
	match add_frames_dialog.get_insert_mode():
		AddFramesDialog.InsertMode.BEGINNING:
			at_position = 0
		AddFramesDialog.InsertMode.AFTER_SELECTED:
			at_position = preview.frame + 1
		_:
			at_position = -1
	var insert_index := regions.size() if at_position < 0 else at_position
	var frame_pos := at_position
	for rect in rects:
		var at := AtlasTexture.new()
		at.atlas = atlas
		at.region = rect
		preview.sprite_frames.add_frame(anim, at, 1.0, frame_pos)
		regions.insert(insert_index, rect)
		durations.insert(insert_index, 1.0)
		if frame_pos >= 0:
			frame_pos += 1
		insert_index += 1
	var count := preview.sprite_frames.get_frame_count(anim)
	_last_frame_amount = count
	spinbox_frames.value = count
	unsaved_changes = true
	update_anim_time()
	var select_idx := count - 1
	if at_position >= 0:
		select_idx = mini(insert_index - 1, count - 1)
	set_frame(select_idx)
	_refresh_frames_strip()


func _on_add_frames_pressed() -> void:
	var atlas := _current_atlas()
	if !atlas:
		return
	add_frames_dialog.setup(atlas)
	popup_one_dialog(add_frames_dialog)


func _on_edit_frame_pressed() -> void:
	var atlas := _current_atlas()
	if !atlas:
		return
	var region := current_frame.region if current_frame else Rect2(Vector2.ZERO, atlas.get_size())
	edit_frame_dialog.setup(atlas, region)
	popup_one_dialog(edit_frame_dialog)


func _on_delete_frame_pressed() -> void:
	if !preview.animation:
		return
	if preview.sprite_frames.get_frame_count(preview.animation) <= 1:
		return
	_remove_frame_at(preview.frame)


func _remove_frame_at(index: int) -> void:
	var anim := preview.animation
	var count := preview.sprite_frames.get_frame_count(anim)
	if count <= 1:
		return
	preview.sprite_frames.remove_frame(anim, index)
	current_skin_setting.animation_regions[anim].remove_at(index)
	current_skin_setting.animation_durations[anim].remove_at(index)
	_last_frame_amount = count - 1
	spinbox_frames.value = _last_frame_amount
	unsaved_changes = true
	update_anim_time()
	set_frame(mini(index, _last_frame_amount - 1))
	_refresh_frames_strip()


func _on_frames_reordered(from: int, to: int) -> void:
	if !preview.animation:
		return
	var anim := preview.animation
	var count := preview.sprite_frames.get_frame_count(anim)
	if from < 0 || from >= count || to < 0 || to > count:
		return
	if from == to || from == to - 1:
		return
	var tex := preview.sprite_frames.get_frame_texture(anim, from)
	var dur := preview.sprite_frames.get_frame_duration(anim, from)
	preview.sprite_frames.remove_frame(anim, from)
	var insert_at := to - 1 if from < to else to
	preview.sprite_frames.add_frame(anim, tex, dur, insert_at)
	_move_array_item(current_skin_setting.animation_regions[anim], from, insert_at)
	_move_array_item(current_skin_setting.animation_durations[anim], from, insert_at)
	unsaved_changes = true
	update_anim_time()
	set_frame(insert_at)
	_refresh_frames_strip()


func _move_array_item(arr: Array, from: int, insert_at: int) -> void:
	var item = arr.pop_at(from)
	arr.insert(insert_at, item)

#endregion AnimationButtons

func _close_welcome() -> void:
	%WelcomePanel.hide()


func _refresh_welcome_recents() -> void:
	var recents: Array = %MusicControls.get_recent_skins()
	for child in %RecentList.get_children():
		%RecentList.remove_child(child)
		child.free()
	%RecentEmpty.visible = recents.is_empty()
	%RecentScroll.visible = !recents.is_empty()
	for path in recents:
		var btn := Button.new()
		btn.text = path
		btn.tooltip_text = path
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 28
		btn.pressed.connect(_on_recent_skin_pressed.bind(path))
		%RecentList.add_child(btn)


func _on_recent_skin_pressed(path: String) -> void:
	open_file(path, true)


## Saves folders where skins located.
func save_file(path: String) -> void:
	current_folder_skin = path
	skin_name = path.get_slice("/", path.get_slice_count("/") - 1)
	version_label.text = PROJECT_NAME % [version_string] + ("\n" + current_folder_skin)
	reset_options_dialog()
	var mark_as_saved: bool = true
	for skin in skin_settings.keys():
		var full_path: String = path + "/" + skin + "/"
		print("Saving skin: " + skin)
		var dir_acc: DirAccess = DirAccess.open(path)
		if !dir_acc.dir_exists(skin):
			dir_acc.make_dir(skin)
		var err = ResourceSaver.save(skin_settings[skin], full_path + "/skin_settings.tres")
		if err:
			OS.alert("Error: " + error_string(err), "Save Failed!")
			mark_as_saved = false
			break
	_save_loop_offsets()
	unsaved_changes = mark_as_saved

## Opens folder where skins located.
func open_file(path: String, from_recent: bool = false) -> void:
	print("Loading folder content: %s" % path)
	var previous_folder := current_folder_skin
	current_folder_skin = path
	
	var has_basic_struct: bool
	if DirAccess.dir_exists_absolute(path):
		for dir in DirAccess.get_directories_at(path):
			if dir == PlayerSkin.STATES[0]:
				has_basic_struct = true
			
			if load_skin_settings_from_file(dir, path):
				continue
	
	if !has_basic_struct:
		current_folder_skin = previous_folder
		if from_recent:
			OS.alert("Could not open skin:\n%s" % path)
			%MusicControls.remove_recent_skin(path)
			_refresh_welcome_recents()
		else:
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
	
	%MusicControls.add_recent_skin(path)
	_set_controls_working(true)
	_close_welcome()

## Creates new skin in a specified folder.
func new_save_file(path: String) -> void:
	if DirAccess.dir_exists_absolute(path.path_join("small")):
		return OS.alert("Directory is not empty!")
	print("Creating new skin at: %s" % path)
	var err: String = AnimGenerator.gen_image_files("small", path)
	image_creation_dialog.dialog_text = err
	popup_one_dialog(image_creation_dialog)
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
	
	%MusicControls.add_recent_skin(path)
	_set_controls_working(true)
	_close_welcome()

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
	misc_files.story = ["", "", "", ""]
	var file_path = path.path_join("story.txt")
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			for i in 4:
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

func _default_loop_offsets() -> Dictionary:
	var offsets := {}
	for anim in PlayerSkin.ANIMS:
		offsets[anim] = -1
	offsets["swim"] = 6
	return offsets


func _suit_tweaks_path(suit: String) -> String:
	if !current_folder_skin || suit.is_empty():
		return ""
	return current_folder_skin.path_join(suit).path_join("suit_tweaks.json")


func _load_loop_offsets() -> void:
	_loop_offsets = _default_loop_offsets()
	if !current_folder_skin:
		_update_loop_offset_spin()
		return
	var suit := str(current_skin_setting.name) if current_skin_setting else ""
	var suit_path := _suit_tweaks_path(suit)
	var all_path := _suit_tweaks_path("_all_suits")
	var path := ""
	if suit_path && FileAccess.file_exists(suit_path):
		path = suit_path
	elif FileAccess.file_exists(all_path):
		path = all_path
	if path:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			var offsets = parsed.get("loop_frame_offsets")
			if offsets is Dictionary:
				for key in offsets:
					_loop_offsets[str(key)] = int(offsets[key])
	_update_loop_offset_spin()


func _save_loop_offsets() -> void:
	if !current_folder_skin || !current_skin_setting:
		return
	var path := _suit_tweaks_path(str(current_skin_setting.name))
	if !path:
		return
	var data: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			data = parsed
	else:
		var all_path := _suit_tweaks_path("_all_suits")
		if FileAccess.file_exists(all_path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(all_path))
			if parsed is Dictionary:
				data = parsed.duplicate(true)
	data["loop_frame_offsets"] = _loop_offsets.duplicate()
	var dir := path.get_base_dir()
	if !DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if !file:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _get_loop_offset(anim: StringName) -> int:
	if !anim:
		return -1
	for key in _loop_offsets.keys():
		if anim == key:
			return int(_loop_offsets[key])
	return -1


func _update_loop_offset_spin() -> void:
	var spin: SpinBox = %LoopOffset
	var offset := _get_loop_offset(preview.animation)
	var max_frame := 0
	if preview.sprite_frames && preview.animation:
		max_frame = maxi(preview.sprite_frames.get_frame_count(preview.animation) - 1, 0)
	_updating_loop_offset = true
	spin.max_value = max_frame
	spin.value = offset
	_updating_loop_offset = false
	if offset < 0:
		%Loop.tooltip_text = "Whether the animation should loop."
	else:
		%Loop.tooltip_text = "Whether the animation should loop.\nLoop Frame Offset %d: after looping, playback continues from this frame." % offset


func _on_loop_offset_changed(value: float) -> void:
	if _updating_loop_offset || !preview.animation:
		return
	_loop_offsets[str(preview.animation)] = int(value)
	_save_loop_offsets()
	_update_loop_offset_spin()


## Updates animation duration display counter.
func update_anim_time() -> void:
	if !preview.animation || !preview.sprite_frames:
		%AnimTime.text = "-"
		return
	var frame_count = preview.sprite_frames.get_frame_count(preview.animation)
	if frame_count > 200:
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
	_on_window_resized(true)

func _on_window_resized(_force_update: bool = false) -> void:
	if !%Camera2D.has_user_moved:
		%Camera2D.update_camera_position()

#region ModalBoxActions
## Displayed when decreasing total frames count
func _on_fill_blanks_ok_pressed() -> void:
	if !modal_window.visible: return
	if %DontAskAgain.button_pressed:
		no_frame_del_popup = true
	modal_window.hide()
	_frame_setter_cooldown = true
	print("Reducing total frame count to %d" % pending_frames)
	set_frames(pending_frames)


func _on_modal_canceled() -> void:
	modal_window.hide()

## "This suit is incomplete. Create default animation settings?"
func ask_about_missing_state() -> void:
	if confirm_dialog.visible: return
	popup_one_dialog(confirm_dialog)

## The "This action will create placeholder image files..." confirmation action
func _on_dialog_new_state_confirmed() -> void:
	var suit_name := current_skin_setting.name
	var out := AnimGenerator.gen_image_files(suit_name, current_folder_skin)
	#load_skin_settings_from_file(suit_name, current_folder_skin)
	#current_skin_setting = skin_settings[suit_name]
	_update_animations()
	update_anim_options()
	image_creation_dialog.dialog_text = out
	popup_one_dialog(image_creation_dialog)

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
	var enabled_count: int = 0
	for i in anim_option.item_count:
		if !anim_option.is_item_disabled(i):
			enabled_count += 1
		if enabled_count >= 2:
			return
	
	_on_dialog_new_state_confirmed()

## Skin Options button
func options_pressed() -> void:
	popup_one_dialog(options_dialog)

func reset_options_dialog() -> void:
	options_dialog.hide()
	if !misc_files: return
	%DisplayNameLine.placeholder_text = skin_name.to_upper()
	%DisplayNameLine.text = misc_files.name
	%TheyLine.text = misc_files.story[0]
	%ThemLine.text = misc_files.story[1]
	%DescriptionLine.text = misc_files.story[2]
	%TheirLine.text = misc_files.story[3]

func options_confirmed() -> void:
	if !misc_files: return
	options_dialog.hide()
	
	if %DisplayNameLine.text != misc_files.name:
		misc_files.name = %DisplayNameLine.text
		var file = FileAccess.open(current_folder_skin.path_join("name.txt"), FileAccess.WRITE)
		file.store_line(misc_files.name)
		file.close()
	if (
		%TheyLine.text != misc_files.story[0] ||
		%ThemLine.text != misc_files.story[1] ||
		%DescriptionLine.text != misc_files.story[2] ||
		%TheirLine.text != misc_files.story[3]
	):
		misc_files.story[0] = %TheyLine.text
		misc_files.story[1] = %ThemLine.text
		misc_files.story[2] = %DescriptionLine.text
		misc_files.story[3] = %TheirLine.text
		var file = FileAccess.open(current_folder_skin.path_join("story.txt"), FileAccess.WRITE)
		file.store_line(misc_files.story[0])
		file.store_line(misc_files.story[1])
		file.store_line(misc_files.story[2])
		file.store_line(misc_files.story[3])
		file.close()

#endregion ModalBoxActions


func _on_display_name_line_text_changed(new_text: String) -> void:
	%DisplayNameLine.text = new_text.to_upper()


func _on_about_pressed() -> void:
	show_one_dialog(about_window)
