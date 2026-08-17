extends Control
class_name Main

const PROJECT_NAME := "MF: CE Skin Editor v%s"
const ICON_PLAY := preload("res://icons/Play.svg")
const ICON_PAUSE := preload("res://icons/Pause.svg")
const BACKGROUND_FPS := 10

enum FileMenu { NEW, OPEN, SAVE, SAVE_AS }
enum EditMenu { UNDO, REDO }
enum EditorMenu { SETTINGS, SEP_EDITOR, SHOW_COLLISION, AUTORELOAD, SEP_HISTORY, HISTORY }
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
@onready var unsaved_dialog: ConfirmationDialog = %UnsavedDialog
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
var _loop_offsets_by_suit: Dictionary = {}

var undo_redo := UndoRedo.new()
var _saved_version: int = 0
var _applying_history := false
var _seeking_history := false
var _updating_ui := false
var _pending_after_unsaved: Callable
var _edit_region_before := Rect2()
var _edit_region_suit: String
var _edit_region_anim: StringName
var _edit_region_frame: int = -1

@onready var preview: AnimatedSprite2D = %Preview
@onready var scene: Node2D = get_tree().current_scene
@onready var frames_strip: FramesStrip = %FramesDock
@onready var history_dock: HistoryDock = %HistoryDock
@onready var add_frames_dialog: AddFramesDialog = %AddFramesDialog
@onready var edit_frame_dialog: EditFrameDialog = %EditFrameDialog

@onready var spinbox_frame: SpinBox = %Frame
@onready var spinbox_speed: SpinBox = %Speed
@onready var spinbox_frames: SpinBox = %Frames
@onready var spinbox_duration: SpinBox = %Duration

@onready var anim_option: OptionButton = %AnimOption
@onready var state_option: OptionButton = %StateSelect
@onready var play_button: Button = %Play
@onready var stop_button: Button = %Stop
@onready var add_frames_button: Button = %AddFrames
@onready var edit_frame_button: Button = %EditFrame
@onready var delete_frame_button: Button = %DeleteFrame
@onready var loop_checkbox: CheckBox = %Loop
@onready var loop_offset_spin: SpinBox = %LoopOffset
@onready var anim_time_label: Label = %AnimTime

var current_frame: AtlasTexture
var pending_state: int
var pending_frames: int
var no_frame_del_popup: bool
var unsaved_changes: bool = false:
	set(to):
		if unsaved_changes == to:
			return
		unsaved_changes = to
		_update_window_title()
var _updating_loop_offset := false
var _recent_menu_path: String
var _editor_settings_snapshot: Dictionary = {}

@onready var confirm_state_text := confirm_new_state.dialog_text

func _ready() -> void:
	_set_controls_working(false)
	_active_max_fps = Engine.max_fps
	_update_background_fps()
	
	if DisplayServer.get_swap_cancel_ok():
		var options_par = options_dialog.get_node("MarginContainer/VBoxContainer3/HBoxContainer")
		options_par.move_child(options_par.get_node("OK"), 1)
		options_par.move_child(options_par.get_node("Cancel"), 3)
		var modal_par = modal_window.get_node("MarginContainer/VBoxContainer/HBoxContainer")
		modal_par.move_child(modal_par.get_node("OK"), 1)
		modal_par.move_child(modal_par.get_node("Cancel"), 3)
		var settings_par = editor_settings_window.get_node("MarginContainer/VBox/Buttons")
		settings_par.move_child(settings_par.get_node("OK"), 1)
		settings_par.move_child(settings_par.get_node("Cancel"), 3)
		settings_par.move_child(settings_par.get_node("Apply"), 5)
	
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
	_setup_toolbar_hotkeys()
	_setup_dock_shortcut_forwarding()
	add_frames_dialog.frames_chosen.connect(add_frames_from_rects)
	edit_frame_dialog.region_changed.connect(apply_frame_region)
	edit_frame_dialog.confirmed.connect(_on_edit_frame_confirmed)
	%File.id_pressed.connect(_on_file_menu_id_pressed)
	_setup_file_shortcuts()
	_setup_menu_shortcuts()
	_setup_menu_bar_scale_fix()
	%Edit.id_pressed.connect(_on_edit_menu_id_pressed)
	%Editor.id_pressed.connect(_on_editor_menu_id_pressed)
	%Skin.id_pressed.connect(_on_skin_menu_id_pressed)
	%Help.id_pressed.connect(_on_help_menu_id_pressed)
	frames_strip.thumb_size_changed.connect(_on_frames_thumb_size_changed)
	frames_strip.floating_changed.connect(_on_frames_dock_floating_changed)
	
	_setup_history()
	get_tree().root.min_size = Vector2(400, 400)
	get_tree().root.size_changed.connect(_on_window_resized)
	get_tree().root.close_requested.connect(_on_app_close_requested)
	
	version_label.text = PROJECT_NAME % [version_string]
	%WelcomeSubtitle.text = PROJECT_NAME % [version_string]
	%WelcomePanel.show()
	_refresh_welcome_recents()
	_update_window_title()
	
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
	play_button.button_pressed = false
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
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_app_focused = false
			_update_background_fps()
			_sync_preview_playback()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_app_focused = true
			_update_background_fps()
			if %Editor.is_item_checked(%Editor.get_item_index(EditorMenu.AUTORELOAD)) && current_skin_setting:
				_update_animations()
				update_anim_options()
			_sync_preview_playback()


func _setup_toolbar_hotkeys() -> void:
	for button in [add_frames_button, edit_frame_button, delete_frame_button, play_button, stop_button]:
		button.focus_mode = Control.FOCUS_NONE
	add_frames_button.tooltip_text = "Add frames from the animation spritesheet. (A)"
	edit_frame_button.tooltip_text = "Edit the selected frame region on the spritesheet. (E)"
	delete_frame_button.tooltip_text = "Remove the selected frame(s) from the animation. (Del)"
	play_button.tooltip_text = "Toggles between Play and Pause. (Space)"
	stop_button.tooltip_text = "Stop animation and set frame to 0. (Esc)"


func _gui_is_editing_text() -> bool:
	return _gui_is_editing_text_in(get_viewport())


func _gui_is_editing_text_in(vp: Viewport) -> bool:
	var focus := vp.gui_get_focus_owner()
	return focus is LineEdit || focus is TextEdit || focus is CodeEdit


func _is_editor_dock_window(win: Window) -> bool:
	return win == %FramesWindow || win == %HistoryWindow


func _is_foreign_window_focused() -> bool:
	for win: Window in get_tree().root.find_children("*", "Window", true, false):
		if !win.visible || win == get_tree().root:
			continue
		if win.theme_type_variation == "TooltipPanel" || win.get_flag(Window.FLAG_NO_FOCUS):
			continue
		if _is_editor_dock_window(win):
			continue
		if win.has_focus():
			return true
	return false


func _setup_dock_shortcut_forwarding() -> void:
	for win: Window in [%FramesWindow, %HistoryWindow]:
		win.window_input.connect(_on_editor_dock_window_input.bind(win))


func _on_editor_dock_window_input(event: InputEvent, win: Window) -> void:
	if !(event is InputEventKey):
		return
	var key := event as InputEventKey
	if _gui_is_editing_text_in(win) && !key.is_command_or_control_pressed():
		return
	var root := get_tree().root
	root.push_input(event)
	if root.is_input_handled():
		win.set_input_as_handled()


func _is_toolbar_hotkey(key: InputEventKey) -> bool:
	if key.alt_pressed || key.shift_pressed || key.is_command_or_control_pressed():
		return false
	match key.keycode:
		KEY_SPACE, KEY_ESCAPE, KEY_A, KEY_E, KEY_DELETE:
			return true
	return false


func _input(event: InputEvent) -> void:
	if !(event is InputEventKey) || !event.pressed || event.echo:
		return
	var key := event as InputEventKey
	if !_is_toolbar_hotkey(key):
		return
	if get_viewport().gui_is_dragging():
		if key.keycode != KEY_ESCAPE:
			get_viewport().set_input_as_handled()
		return
	if _gui_is_editing_text() || _is_foreign_window_focused():
		return
	match key.keycode:
		KEY_SPACE:
			if play_button.disabled:
				return
			play_button.button_pressed = !play_button.button_pressed
		KEY_ESCAPE:
			if stop_button.disabled:
				return
			stop_pressed()
		KEY_A:
			if add_frames_button.disabled:
				return
			_on_add_frames_pressed()
		KEY_E:
			if edit_frame_button.disabled:
				return
			_on_edit_frame_pressed()
		KEY_DELETE:
			if delete_frame_button.disabled:
				return
			_on_delete_frame_pressed()
		_:
			return
	get_viewport().set_input_as_handled()


func _update_animations() -> void:
	var resume: bool = play_button.button_pressed || (preview && preview.is_playing())
	_set_controls_working(false)
	var prev_frame: int = int(spinbox_frame.value)
	preview.sprite_frames = current_skin_setting.gen_animated_sprites(true)
	_load_loop_offsets()
	set_frame(prev_frame)
	update_anim_time()
	_refresh_frames_strip()
	_set_controls_working(true)
	if resume:
		preview.play()
		play_button.button_pressed = true
		play_button.icon = ICON_PAUSE


func _sync_preview_playback() -> void:
	if !preview || !is_instance_valid(play_button):
		return
	if play_button.button_pressed:
		if !preview.is_playing():
			preview.play()
		play_button.icon = ICON_PAUSE
	else:
		if preview.is_playing():
			preview.pause()
		play_button.icon = ICON_PLAY

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
	play_button.disabled = !val
	stop_button.disabled = !val
	loop_checkbox.disabled = !val
	loop_offset_spin.editable = val
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
	_scale_shown_dialog(dialog)

func popup_one_dialog(dialog: Window) -> void:
	if dialog.visible:
		if dialog.mode == Window.MODE_MINIMIZED:
			dialog.mode = Window.MODE_WINDOWED
		dialog.grab_focus()
		return
	dialog.popup_centered()
	_scale_shown_dialog(dialog)


func _scale_shown_dialog(dialog: Window) -> void:
	if dialog is FileDialog && !dialog.force_native:
		return
	scene.scale_window(dialog)


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
	_confirm_unsaved(
		func(): popup_one_dialog(open_dialog),
		"Save changes to this skin before opening another?"
	)

## Called when "new" button is pressed.
func new_pressed() -> void:
	_confirm_unsaved(
		func(): popup_one_dialog(new_save_dialog),
		"Save changes to this skin before creating a new one?"
	)

## Called when "play" button toggled.
func play_toggled(toggle: bool) -> void:
	if toggle:
		play_button.icon = ICON_PAUSE
		frames_strip.select_frame(preview.frame, true)
		preview.play()
	else:
		play_button.icon = ICON_PLAY
		preview.pause()
		_update_preview()
		frames_strip.select_frame(preview.frame, true)

## Called when "stop" button gets pressed.
func stop_pressed() -> void:
	preview.stop()
	play_toggled(false)
	play_button.button_pressed = false
	_update_preview()
	frames_strip.select_frame(preview.frame, true)

## Called when "loop" checkbox gets toggled.
func loop_pressed(toggle: bool) -> void:
	if _updating_ui || _applying_history || !current_skin_setting || !preview.animation:
		return
	var anim := String(preview.animation)
	var old: bool = current_skin_setting.animation_loops.get(anim, toggle)
	if old == toggle:
		return
	var suit := _current_suit()
	_commit_edit(
		("%s Loop (%s)" % ["Enable" if toggle else "Disable", anim]),
		_apply_loop.bind(suit, anim, toggle),
		_apply_loop.bind(suit, anim, old)
	)

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

func _key_shortcut(keycode: Key, ctrl := false, shift := false) -> Shortcut:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.shift_pressed = shift
	ev.command_or_control_autoremap = ctrl
	var sc := Shortcut.new()
	sc.events = [ev]
	return sc


func _setup_file_shortcuts() -> void:
	%File.set_item_shortcut(%File.get_item_index(FileMenu.NEW), _key_shortcut(KEY_N, true), true)
	%File.set_item_shortcut(%File.get_item_index(FileMenu.OPEN), _key_shortcut(KEY_O, true), true)
	%File.set_item_shortcut(%File.get_item_index(FileMenu.SAVE), _key_shortcut(KEY_S, true), true)
	%File.set_item_shortcut(%File.get_item_index(FileMenu.SAVE_AS), _key_shortcut(KEY_S, true, true), true)


func _setup_menu_shortcuts() -> void:
	%Skin.set_item_shortcut(%Skin.get_item_index(SkinMenu.RELOAD), _key_shortcut(KEY_R, true), true)
	%Skin.set_item_shortcut(%Skin.get_item_index(SkinMenu.BROWSE_ANIM), _key_shortcut(KEY_B, true), true)
	%Skin.set_item_shortcut(%Skin.get_item_index(SkinMenu.CREATE_MISSING), _key_shortcut(KEY_N, true, true), true)
	%Editor.set_item_shortcut(%Editor.get_item_index(EditorMenu.SHOW_COLLISION), _key_shortcut(KEY_L, true), true)
	%Help.set_item_shortcut(%Help.get_item_index(HelpMenu.ABOUT), _key_shortcut(KEY_F1), true)


func _setup_menu_bar_scale_fix() -> void:
	var bar := %File.get_parent() as MenuBar
	if bar == null:
		return
	for child in bar.get_children():
		var popup := child as PopupMenu
		if popup == null:
			continue
		popup.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
		popup.about_to_popup.connect(_fix_menu_bar_popup_position.bind(popup))
		popup.visibility_changed.connect(_on_menu_bar_popup_visibility.bind(popup))


func _on_menu_bar_popup_visibility(popup: PopupMenu) -> void:
	if popup.visible:
		_fix_menu_bar_popup_position(popup)


func _fix_menu_bar_popup_position(popup: PopupMenu) -> void:
	var bar := popup.get_parent() as MenuBar
	if bar == null:
		return
	var idx := -1
	for i in bar.get_menu_count():
		if bar.get_menu_popup(i) == popup:
			idx = i
			break
	if idx < 0:
		return
	var item := _menu_bar_item_rect(bar, idx)
	var local := Vector2(item.position.x, bar.size.y)
	var ui_scale := get_window().content_scale_factor
	if ui_scale <= 0.0:
		ui_scale = 1.0
	# MenuBar places native popups with an unscaled item offset. Rebuild from
	# logical UI coords * content_scale_factor so fractional scales (75%, 150%, …)
	# match 100%/200%.
	var logical := bar.get_global_transform_with_canvas() * local
	popup.position = Vector2i((Vector2(get_window().position) + logical * ui_scale).round())


func _menu_bar_item_rect(bar: MenuBar, index: int) -> Rect2:
	var style: StyleBox = bar.get_theme_stylebox("normal")
	var style_min := style.get_minimum_size() if style else Vector2.ZERO
	var h_sep := bar.get_theme_constant("h_separation")
	var font := bar.get_theme_font("font")
	var font_size := bar.get_theme_font_size("font_size")
	var offset := 0.0
	for i in index:
		if bar.is_menu_hidden(i):
			continue
		var prev_size := font.get_string_size(bar.get_menu_title(i), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size) + style_min
		offset += prev_size.x + h_sep
	var item_size := font.get_string_size(bar.get_menu_title(index), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size) + style_min
	item_size.y = bar.size.y
	if bar.is_layout_rtl():
		return Rect2(bar.size.x - offset - item_size.x, 0.0, item_size.x, item_size.y)
	return Rect2(offset, 0.0, item_size.x, item_size.y)


func _on_editor_menu_id_pressed(id: int) -> void:
	match id:
		EditorMenu.SETTINGS:
			_open_editor_settings()
		EditorMenu.SHOW_COLLISION:
			var idx: int = %Editor.get_item_index(id)
			%Editor.toggle_item_checked(idx)
			scene.show_collisions = %Editor.is_item_checked(idx)
		EditorMenu.AUTORELOAD:
			%Editor.toggle_item_checked(%Editor.get_item_index(id))
		EditorMenu.HISTORY:
			var hist_idx: int = %Editor.get_item_index(id)
			%Editor.toggle_item_checked(hist_idx)
			history_dock.set_open(%Editor.is_item_checked(hist_idx), false)
			_on_window_resized()


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


func _open_editor_settings() -> void:
	if editor_settings_window.visible:
		show_one_dialog(editor_settings_window)
		return
	_editor_settings_snapshot = _live_editor_settings()
	_sync_editor_settings_controls(_editor_settings_snapshot)
	show_one_dialog(editor_settings_window)


func _live_editor_settings() -> Dictionary:
	return {
		"bg_color": RenderingServer.get_default_clear_color(),
		"grid_color": scene.color,
		"thumb_size": frames_strip.thumb_size,
		"editor_scale": scene.editor_scale,
		"camera_origin_y": %Camera2D.origin_offset_y,
	}


func _sync_editor_settings_controls(values: Dictionary) -> void:
	%BGcolor.color = values.bg_color
	%GridColor.color = values.grid_color
	%ThumbSize.set_value_no_signal(values.thumb_size)
	%EditorScale.set_value_no_signal(roundf(float(values.editor_scale) * 100.0))
	%CameraOriginY.set_value_no_signal(float(values.camera_origin_y))


func _apply_editor_settings_from_controls() -> void:
	scene._on_bg_color_changed(%BGcolor.color)
	scene._on_grid_color_changed(%GridColor.color)
	frames_strip.set_thumb_size(int(%ThumbSize.value))
	scene.apply_editor_scale(%EditorScale.value / 100.0)
	%Camera2D.set_origin_offset_y(%CameraOriginY.value)
	_editor_settings_snapshot = _live_editor_settings()


func _on_editor_settings_ok_pressed() -> void:
	_apply_editor_settings_from_controls()
	editor_settings_window.hide()


func _on_editor_settings_apply_pressed() -> void:
	_apply_editor_settings_from_controls()


func _on_editor_settings_canceled() -> void:
	if !_editor_settings_snapshot.is_empty():
		_sync_editor_settings_controls(_editor_settings_snapshot)
	editor_settings_window.hide()


func _on_frames_thumb_size_changed(thumb_px: int) -> void:
	if int(%ThumbSize.value) != thumb_px:
		%ThumbSize.set_value_no_signal(thumb_px)
	if editor_settings_window.visible:
		_editor_settings_snapshot.thumb_size = thumb_px
#endregion FileButtons


#region History
func _setup_history() -> void:
	undo_redo.max_steps = 256
	undo_redo.version_changed.connect(_on_history_changed)
	_setup_edit_shortcuts()
	unsaved_dialog.ok_button_text = "Save"
	unsaved_dialog.add_button("Don't Save", true, "discard")
	unsaved_dialog.confirmed.connect(_on_unsaved_save_pressed)
	unsaved_dialog.custom_action.connect(_on_unsaved_custom_action)
	unsaved_dialog.canceled.connect(_on_unsaved_canceled)
	save_dialog.canceled.connect(_on_save_dialog_canceled)
	save_dialog.close_requested.connect(_on_save_dialog_canceled)
	history_dock.seek_requested.connect(_seek_history)
	history_dock.open_changed.connect(_on_history_dock_open_changed)
	history_dock.refresh(undo_redo)
	_reset_history()


func _setup_edit_shortcuts() -> void:
	%Edit.set_item_shortcut(%Edit.get_item_index(EditMenu.UNDO), _key_shortcut(KEY_Z, true), true)
	var redo_sc := _key_shortcut(KEY_Y, true)
	redo_sc.events.append_array(_key_shortcut(KEY_Z, true, true).events)
	%Edit.set_item_shortcut(%Edit.get_item_index(EditMenu.REDO), redo_sc, true)


func _on_edit_menu_id_pressed(id: int) -> void:
	match id:
		EditMenu.UNDO:
			_undo_pressed()
		EditMenu.REDO:
			_redo_pressed()


func _can_undo_redo() -> bool:
	if !current_skin_setting:
		return false
	for dialog in [
		add_frames_dialog, edit_frame_dialog, modal_window, confirm_dialog,
		confirm_new_state, options_dialog, unsaved_dialog, save_dialog,
		open_dialog, new_save_dialog, editor_settings_window, about_window,
		image_creation_dialog,
	]:
		if dialog && dialog.visible:
			return false
	return true


func _undo_pressed() -> void:
	if !_can_undo_redo() || !undo_redo.has_undo():
		return
	undo_redo.undo()


func _redo_pressed() -> void:
	if !_can_undo_redo() || !undo_redo.has_redo():
		return
	undo_redo.redo()


func _reset_history() -> void:
	undo_redo.clear_history(false)
	_saved_version = undo_redo.get_version()
	unsaved_changes = false
	_on_history_changed()


func _mark_saved() -> void:
	_saved_version = undo_redo.get_version()
	unsaved_changes = false
	_on_history_changed()


func _on_history_changed() -> void:
	var dirty := _has_unsaved_changes()
	if unsaved_changes != dirty:
		unsaved_changes = dirty
	_update_undo_redo_menu()
	_update_window_title()
	if !_seeking_history && history_dock:
		history_dock.refresh(undo_redo)


func _on_history_dock_open_changed(open: bool) -> void:
	var idx: int = %Editor.get_item_index(EditorMenu.HISTORY)
	if %Editor.is_item_checked(idx) != open:
		%Editor.set_item_checked(idx, open)
	_on_window_resized()


func _on_frames_dock_floating_changed(_floating: bool) -> void:
	_on_window_resized()


func _seek_history(action_index: int) -> void:
	if !_can_undo_redo():
		history_dock.refresh(undo_redo)
		return
	_seeking_history = true
	while undo_redo.get_current_action() > action_index:
		if !undo_redo.undo():
			break
	while undo_redo.get_current_action() < action_index:
		if !undo_redo.redo():
			break
	_seeking_history = false
	_on_history_changed()


func _has_unsaved_changes() -> bool:
	if !current_skin_setting:
		return false
	if undo_redo.get_version() != _saved_version:
		return true
	if edit_frame_dialog.visible && edit_frame_dialog.has_pending_change():
		return true
	return false


func _update_undo_redo_menu() -> void:
	var undo_idx: int = %Edit.get_item_index(EditMenu.UNDO)
	var redo_idx: int = %Edit.get_item_index(EditMenu.REDO)
	var can_undo := _can_undo_redo() && undo_redo.has_undo()
	var can_redo := _can_undo_redo() && undo_redo.has_redo()
	%Edit.set_item_disabled(undo_idx, !can_undo)
	%Edit.set_item_disabled(redo_idx, !can_redo)
	var undo_name := undo_redo.get_current_action_name()
	%Edit.set_item_text(undo_idx, "Undo" if undo_name.is_empty() else "Undo %s" % undo_name)
	if can_redo:
		var redo_action := undo_redo.get_current_action() + 1
		var redo_name := undo_redo.get_action_name(redo_action)
		%Edit.set_item_text(redo_idx, "Redo" if redo_name.is_empty() else "Redo %s" % redo_name)
	else:
		%Edit.set_item_text(redo_idx, "Redo")


func _update_window_title() -> void:
	var title: String = str(ProjectSettings.get_setting("application/config/name", PROJECT_NAME))
	if current_folder_skin:
		title += " - " + (skin_name if !skin_name.is_empty() else current_folder_skin)
	if _has_unsaved_changes():
		title = "* " + title
	DisplayServer.window_set_title(title)


func _commit_edit(
	action_name: String,
	do_method: Callable,
	undo_method: Callable,
	merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE,
	execute: bool = true
) -> void:
	if _applying_history:
		if execute:
			do_method.call()
		return
	undo_redo.create_action(action_name, merge_mode)
	undo_redo.add_do_method(do_method)
	undo_redo.add_undo_method(undo_method)
	undo_redo.commit_action(execute)
	_on_history_changed()


func _current_suit() -> String:
	return str(current_skin_setting.name) if current_skin_setting else ""


func _snapshot_frames(anim: StringName) -> Dictionary:
	return {
		"regions": current_skin_setting.animation_regions[anim].duplicate(),
		"durations": current_skin_setting.animation_durations[anim].duplicate(),
		"frame": preview.frame,
	}


func _commit_frames_change(
	action_name: String,
	suit: String,
	anim: StringName,
	before: Dictionary,
	merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE
) -> void:
	var after := _snapshot_frames(anim)
	if before.regions == after.regions && before.durations == after.durations:
		return
	_commit_edit(
		action_name,
		_restore_anim_frames.bind(suit, String(anim), after.regions, after.durations, after.frame),
		_restore_anim_frames.bind(suit, String(anim), before.regions, before.durations, before.frame),
		merge_mode,
		false
	)


func _focus_anim(suit: String, anim: String, frame: int = -1) -> void:
	if !skin_settings.has(suit):
		return
	if !current_skin_setting || str(current_skin_setting.name) != suit:
		for i in state_option.item_count:
			if state_option.get_item_text(i) == suit:
				state_option.select(i)
				set_state(i)
				break
	if preview.animation != anim:
		for i in anim_option.item_count:
			if anim_option.get_item_text(i) == anim && !anim_option.is_item_disabled(i):
				anim_option.select(i)
				set_animation(i)
				break
	if frame >= 0:
		set_frame(frame)


func _restore_anim_frames(suit: String, anim: String, regions: Array, durations: Array, select_frame: int) -> void:
	_applying_history = true
	var skin: PlayerSkin = skin_settings.get(suit)
	if !skin:
		_applying_history = false
		return
	skin.animation_regions[anim] = regions.duplicate()
	skin.animation_durations[anim] = durations.duplicate()
	skin.baked_frames = null
	if current_skin_setting == skin:
		preview.sprite_frames = skin.gen_animated_sprites(true)
		update_anim_options()
	_focus_anim(suit, anim, select_frame)
	if preview.sprite_frames && preview.sprite_frames.has_animation(preview.animation):
		_last_frame_amount = preview.sprite_frames.get_frame_count(preview.animation)
		_updating_ui = true
		spinbox_frames.value = _last_frame_amount
		_updating_ui = false
		update_anim_time()
		_refresh_frames_strip()
		_update_loop_offset_spin()
	_applying_history = false


func _apply_loop(suit: String, anim: String, enabled: bool) -> void:
	_applying_history = true
	var skin: PlayerSkin = skin_settings.get(suit)
	if skin:
		skin.animation_loops[anim] = enabled
		if skin.baked_frames && skin.baked_frames.has_animation(anim):
			skin.baked_frames.set_animation_loop(anim, enabled)
	_focus_anim(suit, anim)
	if preview.sprite_frames && preview.sprite_frames.has_animation(anim):
		preview.sprite_frames.set_animation_loop(anim, enabled)
	_updating_ui = true
	loop_checkbox.button_pressed = enabled
	_updating_ui = false
	_applying_history = false


func _apply_speed(suit: String, anim: String, value: float) -> void:
	_applying_history = true
	var skin: PlayerSkin = skin_settings.get(suit)
	if skin:
		skin.animation_speeds[anim] = value
		if skin.baked_frames && skin.baked_frames.has_animation(anim):
			skin.baked_frames.set_animation_speed(anim, value)
	_focus_anim(suit, anim)
	set_anim_speed(value)
	_applying_history = false


func _apply_duration(suit: String, anim: String, frame: int, value: float) -> void:
	var values := {}
	values[frame] = value
	_apply_durations(suit, anim, values, frame)


func _apply_durations(suit: String, anim: String, values: Dictionary, select_frame: int) -> void:
	_applying_history = true
	var skin: PlayerSkin = skin_settings.get(suit)
	var keys: Array = values.keys()
	keys.sort()
	if skin && skin.animation_durations.has(anim):
		for key in keys:
			var frame := int(key)
			if frame < 0 || frame >= skin.animation_durations[anim].size():
				continue
			var value := float(values[key])
			skin.animation_durations[anim][frame] = value
			if skin.baked_frames && skin.baked_frames.has_animation(anim) && frame < skin.baked_frames.get_frame_count(anim):
				var texture = skin.baked_frames.get_frame_texture(anim, frame)
				skin.baked_frames.set_frame(anim, frame, texture, value)
	_focus_anim(suit, anim, select_frame)
	if current_skin_setting && str(current_skin_setting.name) == suit && preview.animation == anim && preview.sprite_frames:
		var selected := PackedInt32Array()
		var count := preview.sprite_frames.get_frame_count(anim)
		for key in keys:
			var frame := int(key)
			if frame < 0 || frame >= count:
				continue
			var value := float(values[key])
			var texture = preview.sprite_frames.get_frame_texture(anim, frame)
			preview.sprite_frames.set_frame(anim, frame, texture, value)
			selected.append(frame)
			frames_strip.update_item_text(frame, value)
		if select_frame >= 0 && select_frame < count:
			set_duration(float(values.get(select_frame, preview.sprite_frames.get_frame_duration(anim, select_frame))))
		if !selected.is_empty():
			frames_strip.select_indices(selected, select_frame)
		update_anim_time()
	_applying_history = false


func _apply_frame_region_at(suit: String, anim: String, frame: int, rect: Rect2) -> void:
	_applying_history = true
	var skin: PlayerSkin = skin_settings.get(suit)
	if skin && skin.animation_regions.has(anim) && frame >= 0 && frame < skin.animation_regions[anim].size():
		skin.animation_regions[anim][frame] = rect
		if skin.baked_frames && skin.baked_frames.has_animation(anim) && frame < skin.baked_frames.get_frame_count(anim):
			var tex := skin.baked_frames.get_frame_texture(anim, frame)
			if tex is AtlasTexture:
				tex.region = rect
	_focus_anim(suit, anim, frame)
	apply_frame_region(rect)
	_applying_history = false


func _apply_loop_offset(suit: String, anim: String, value: int) -> void:
	_applying_history = true
	if !_loop_offsets_by_suit.has(suit):
		_loop_offsets_by_suit[suit] = _default_loop_offsets()
	_loop_offsets_by_suit[suit][anim] = value
	_focus_anim(suit, anim)
	_loop_offsets = _loop_offsets_by_suit[suit]
	_update_loop_offset_spin()
	_applying_history = false


func _confirm_unsaved(after: Callable, message: String) -> void:
	if !_has_unsaved_changes():
		after.call()
		return
	_pending_after_unsaved = after
	unsaved_dialog.dialog_text = message
	popup_one_dialog(unsaved_dialog)


func _on_app_close_requested() -> void:
	if unsaved_dialog.visible:
		return
	_confirm_unsaved(_quit_app, "Save changes to this skin before closing?")


func _quit_app() -> void:
	Config.collect_and_save()
	get_tree().quit()


func _on_unsaved_save_pressed() -> void:
	if !current_folder_skin:
		popup_one_dialog(save_dialog)
		return
	save_file(current_folder_skin)


func _on_unsaved_custom_action(action: String) -> void:
	if action != "discard":
		return
	var cb := _pending_after_unsaved
	_pending_after_unsaved = Callable()
	if cb.is_valid():
		cb.call()


func _on_unsaved_canceled() -> void:
	_pending_after_unsaved = Callable()


func _on_save_dialog_canceled() -> void:
	_pending_after_unsaved = Callable()


func _run_pending_after_save() -> void:
	if !_pending_after_unsaved.is_valid():
		return
	var cb := _pending_after_unsaved
	_pending_after_unsaved = Callable()
	cb.call()
#endregion History


#region AnimationButtons
## Calls when "frame" spinbox changed.
func frame_val_changed(value: float) -> void:
	set_frame(int(spinbox_frame.value))

## Calls when "speed" spinbox changed
func speed_val_changed(value: float) -> void:
	if _updating_ui || _applying_history || !current_skin_setting || !preview.animation:
		return
	var anim := String(preview.animation)
	var old := float(current_skin_setting.animation_speeds.get(anim, 0.0))
	var new_val := clampf(value, 0.0, 120.0)
	if is_equal_approx(old, new_val):
		return
	_commit_edit(
		"Set Speed (%s)" % anim,
		_apply_speed.bind(_current_suit(), anim, new_val),
		_apply_speed.bind(_current_suit(), anim, old),
		UndoRedo.MERGE_ENDS
	)

## Calls when "frames" spinbox changed
func frames_val_changed(value: float) -> void:
	if _updating_ui || _applying_history:
		return
	set_frames.call_deferred(int(value))

## Calls when "duration" spinbox changed
func duration_val_changed(value: float) -> void:
	if _updating_ui || _applying_history || !current_skin_setting || !preview.animation:
		return
	var anim := String(preview.animation)
	if !current_skin_setting.animation_durations.has(anim):
		return
	var selected := frames_strip.get_selected_indices()
	if selected.is_empty():
		selected = PackedInt32Array([preview.frame])
	var new_val := clampf(value, 0.0, 120.0)
	var old_map := {}
	var new_map := {}
	var changed := false
	for i in selected:
		if i < 0 || i >= current_skin_setting.animation_durations[anim].size():
			continue
		var old := float(current_skin_setting.animation_durations[anim][i])
		old_map[i] = old
		new_map[i] = new_val
		if !is_equal_approx(old, new_val):
			changed = true
	if !changed || new_map.is_empty():
		return
	var action := "Set Duration (%s #%d)" % [anim, int(new_map.keys()[0])]
	if new_map.size() > 1:
		action = "Set Duration (%s, %d frames)" % [anim, new_map.size()]
	_commit_edit(
		action,
		_apply_durations.bind(_current_suit(), anim, new_map.duplicate(), preview.frame),
		_apply_durations.bind(_current_suit(), anim, old_map.duplicate(), preview.frame),
		UndoRedo.MERGE_ENDS
	)

#region SpinboxSetters

# Use this setters to set a value
## Setter for current frame of current animation, changes "frame" spinbox value. 
func set_frame(value: int) -> void:
	var max_frames: int = preview.sprite_frames.get_frame_count(preview.animation)
	if value < 0: # Warp value
		value = max_frames - 1
	elif value >= max_frames:
		value = 0
	
	_updating_ui = true
	spinbox_frame.value = value
	_updating_ui = false
	
	if preview.animation:
		preview.frame = value
		set_duration(preview.sprite_frames.get_frame_duration(preview.animation, value))
	
	_update_preview()
	frames_strip.select_frame(value, play_button.button_pressed || preview.is_playing())

var _last_frame_amount: int
var _frame_setter_cooldown: bool
var _awaiting_frame_warning: bool
var _old_window_mode: DisplayServer.WindowMode
var _active_max_fps: int = 0
var _app_focused := true

func _process(_delta: float) -> void:
	if Input.mouse_mode > Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if DisplayServer.window_get_mode() != _old_window_mode:
		_old_window_mode = DisplayServer.window_get_mode()
		_on_window_resized()
		_update_background_fps()
	if _frame_setter_cooldown:
		if modal_window.visible: return
		_frame_setter_cooldown = false


func _update_background_fps() -> void:
	var throttle := (
		!_app_focused
		|| DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED
	)
	var target := BACKGROUND_FPS if throttle else _active_max_fps
	if Engine.max_fps != target:
		Engine.max_fps = target

## Setter for current amount of frames in current animation, changes "frames" spinbox value.
func set_frames(value: int) -> void:
	value = max(value, 1)
	if modal_window.visible || _awaiting_frame_warning:
		_sync_frames_spinbox()
		return
	if !_frame_setter_cooldown && _last_frame_amount > value && !no_frame_del_popup:
		pending_frames = value
		_sync_frames_spinbox()
		_prompt_reduce_frames()
		return
	
	if !preview.animation:
		push_error("No preview animation; total frames will not change")
		return
	
	var before := {}
	var should_record := !_applying_history && _last_frame_amount != value
	if should_record:
		before = _snapshot_frames(preview.animation)
	
	_updating_ui = true
	spinbox_frames.value = value
	_updating_ui = false
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
		set_frame(value - 1)
	
	elif _last_frame_amount > value:
		print("Deleting frames! Amount: %d" % [abs(value - _last_frame_amount)])
		for i in abs(_last_frame_amount - value):
			var max_frames: int = preview.sprite_frames.get_frame_count(preview.animation) - 1
			preview.sprite_frames.remove_frame(preview.animation, max_frames)
			current_skin_setting.animation_regions[preview.animation].pop_back()
			current_skin_setting.animation_durations[preview.animation].pop_back()
		update_anim_time()
		prints("preview frame: ", spinbox_frame.value, value)
		if int(spinbox_frame.value) >= value:
			set_frame(value - 1)
	
	_last_frame_amount = value
	_refresh_frames_strip()
	_update_loop_offset_spin()
	if should_record && !before.is_empty():
		_commit_frames_change(
			"Set Frame Count (%s)" % String(preview.animation),
			_current_suit(),
			preview.animation,
			before,
			UndoRedo.MERGE_ENDS
		)


func _prompt_reduce_frames() -> void:
	_awaiting_frame_warning = true
	while (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		|| Input.is_key_pressed(KEY_DOWN)
		|| Input.is_key_pressed(KEY_UP)
		|| Input.is_physical_key_pressed(KEY_DOWN)
		|| Input.is_physical_key_pressed(KEY_UP)
	):
		_sync_frames_spinbox()
		await get_tree().process_frame
	_sync_frames_spinbox()
	if !is_inside_tree() || modal_window.visible:
		_awaiting_frame_warning = false
		return
	spinbox_frames.release_focus()
	var line := spinbox_frames.get_line_edit()
	if line:
		line.release_focus()
	modal_window.size = Vector2i(100, 100)
	popup_one_dialog(modal_window)
	_awaiting_frame_warning = false


func _sync_frames_spinbox() -> void:
	_updating_ui = true
	spinbox_frames.value = _last_frame_amount
	var line := spinbox_frames.get_line_edit()
	if line:
		line.text = str(_last_frame_amount)
	_updating_ui = false


## Setter for current speed of selected animation, changes "speed" spinbox value. 
func set_anim_speed(value: float) -> void:
	value = clampf(value, 0.0, 120.0)
	
	_updating_ui = true
	spinbox_speed.value = value
	_updating_ui = false
	
	current_skin_setting.animation_speeds[preview.animation] = value
	
	if preview.animation:
		preview.sprite_frames.set_animation_speed(preview.animation, value)
	update_anim_time()

## Setter for current duration of selected animation, changes "duration" spinbox value. 
func set_duration(value: float) -> void:
	value = clampf(value, 0.0, 120.0)
	
	_updating_ui = true
	spinbox_duration.value = value
	_updating_ui = false
	
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
	
	_updating_ui = true
	loop_checkbox.button_pressed = preview.sprite_frames.get_animation_loop(anim_name)
	_updating_ui = false
	_update_loop_offset_spin()
	play_toggled(false)
	play_button.button_pressed = false
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
	if current_skin_setting:
		_loop_offsets_by_suit[str(current_skin_setting.name)] = _loop_offsets.duplicate()
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


func _refresh_frames_strip(keep_selected: PackedInt32Array = PackedInt32Array()) -> void:
	if !preview.sprite_frames || !preview.animation:
		frames_strip.rebuild(null, &"", 0)
		return
	frames_strip.rebuild(preview.sprite_frames, preview.animation, preview.frame, keep_selected)


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
	var before := _snapshot_frames(anim)
	var regions: Array = current_skin_setting.animation_regions[anim]
	var durations: Array = current_skin_setting.animation_durations[anim]
	var n := rects.size()
	var noun := "Frame" if n == 1 else "%d Frames" % n
	var insert_mode := add_frames_dialog.get_insert_mode()
	var after_frame := preview.frame
	var at_position := -1
	var action := "Add %s at End (%s)" % [noun, String(anim)]
	match insert_mode:
		AddFramesDialog.InsertMode.BEGINNING:
			at_position = 0
			action = "Add %s at Start (%s)" % [noun, String(anim)]
		AddFramesDialog.InsertMode.AFTER_SELECTED:
			at_position = after_frame + 1
			action = "Add %s after #%d (%s)" % [noun, after_frame, String(anim)]
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
	_updating_ui = true
	spinbox_frames.value = count
	_updating_ui = false
	update_anim_time()
	var select_idx := count - 1
	if at_position >= 0:
		select_idx = mini(insert_index - 1, count - 1)
	set_frame(select_idx)
	_refresh_frames_strip()
	_commit_frames_change(action, _current_suit(), anim, before)


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
	_edit_region_before = region
	_edit_region_suit = _current_suit()
	_edit_region_anim = preview.animation
	_edit_region_frame = preview.frame
	edit_frame_dialog.setup(atlas, region)
	popup_one_dialog(edit_frame_dialog)


func _on_edit_frame_confirmed() -> void:
	if !current_frame:
		return
	var new_rect := current_frame.region
	if new_rect == _edit_region_before:
		return
	_commit_edit(
		"Edit Region (%s #%d)" % [String(_edit_region_anim), _edit_region_frame],
		_apply_frame_region_at.bind(_edit_region_suit, String(_edit_region_anim), _edit_region_frame, new_rect),
		_apply_frame_region_at.bind(_edit_region_suit, String(_edit_region_anim), _edit_region_frame, _edit_region_before),
		UndoRedo.MERGE_DISABLE,
		false
	)


func _on_delete_frame_pressed() -> void:
	if !preview.animation:
		return
	var indices := frames_strip.get_selected_indices()
	if indices.is_empty():
		indices = PackedInt32Array([preview.frame])
	_remove_frames_at(indices)


func _remove_frame_at(index: int) -> void:
	_remove_frames_at(PackedInt32Array([index]))


func _remove_frames_at(indices: PackedInt32Array) -> void:
	var anim := preview.animation
	var count := preview.sprite_frames.get_frame_count(anim)
	if count <= 1:
		return
	var to_delete: Array[int] = []
	for i in indices:
		if i >= 0 && i < count && !to_delete.has(i):
			to_delete.append(i)
	to_delete.sort()
	if to_delete.size() >= count:
		to_delete.remove_at(0)
	if to_delete.is_empty():
		return
	var before := _snapshot_frames(anim)
	for i in range(to_delete.size() - 1, -1, -1):
		var index: int = to_delete[i]
		preview.sprite_frames.remove_frame(anim, index)
		current_skin_setting.animation_regions[anim].remove_at(index)
		current_skin_setting.animation_durations[anim].remove_at(index)
	_last_frame_amount = preview.sprite_frames.get_frame_count(anim)
	_updating_ui = true
	spinbox_frames.value = _last_frame_amount
	_updating_ui = false
	update_anim_time()
	var next := mini(to_delete[0], _last_frame_amount - 1)
	set_frame(next)
	_refresh_frames_strip()
	var action := "Delete Frame #%d (%s)" % [to_delete[0], String(anim)]
	if to_delete.size() > 1:
		action = "Delete %d Frames (%s)" % [to_delete.size(), String(anim)]
	_commit_frames_change(action, _current_suit(), anim, before)


func _on_frames_reordered(indices: PackedInt32Array, to: int) -> void:
	if !preview.animation:
		return
	var anim := preview.animation
	var count := preview.sprite_frames.get_frame_count(anim)
	if to < 0 || to > count:
		return
	var moving: Array[int] = []
	for i in indices:
		if i >= 0 && i < count && !moving.has(i):
			moving.append(i)
	moving.sort()
	if moving.is_empty():
		return
	var removed_before := 0
	for i in moving:
		if i < to:
			removed_before += 1
	var insert_at := to - removed_before
	var noop := true
	for j in moving.size():
		if moving[j] != insert_at + j:
			noop = false
			break
	if noop:
		return
	var before := _snapshot_frames(anim)
	var texs: Array = []
	var durs: Array = []
	var regs: Array = []
	var dur_data: Array = []
	for i in range(moving.size() - 1, -1, -1):
		var idx: int = moving[i]
		texs.push_front(preview.sprite_frames.get_frame_texture(anim, idx))
		durs.push_front(preview.sprite_frames.get_frame_duration(anim, idx))
		preview.sprite_frames.remove_frame(anim, idx)
		regs.push_front(current_skin_setting.animation_regions[anim].pop_at(idx))
		dur_data.push_front(current_skin_setting.animation_durations[anim].pop_at(idx))
	for j in texs.size():
		preview.sprite_frames.add_frame(anim, texs[j], durs[j], insert_at + j)
		current_skin_setting.animation_regions[anim].insert(insert_at + j, regs[j])
		current_skin_setting.animation_durations[anim].insert(insert_at + j, dur_data[j])
	update_anim_time()
	var new_selected := PackedInt32Array()
	for j in moving.size():
		new_selected.append(insert_at + j)
	set_frame(insert_at)
	_refresh_frames_strip(new_selected)
	var action := "Move Frame #%d to #%d (%s)" % [moving[0], insert_at, String(anim)]
	if moving.size() > 1:
		action = "Move %d Frames to #%d (%s)" % [moving.size(), insert_at, String(anim)]
	_commit_frames_change(action, _current_suit(), anim, before)

#endregion AnimationButtons

func _close_welcome() -> void:
	%WelcomePanel.hide()


func _refresh_welcome_recents() -> void:
	var recents: Array = Config.get_recent_skins()
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
		btn.gui_input.connect(_on_recent_skin_gui_input.bind(path))
		%RecentList.add_child(btn)


func _on_recent_skin_pressed(path: String) -> void:
	_confirm_unsaved(
		func(): open_file(path, true),
		"Save changes to this skin before opening another?"
	)


func _on_recent_skin_gui_input(event: InputEvent, path: String) -> void:
	if !(event is InputEventMouseButton) || !event.pressed || event.button_index != MOUSE_BUTTON_RIGHT:
		return
	_recent_menu_path = path
	%RecentSkinMenu.popup(Rect2i(DisplayServer.mouse_get_position(), Vector2i.ZERO))
	%RecentList.get_viewport().set_input_as_handled()


func _on_recent_skin_menu_id_pressed(id: int) -> void:
	if id != 0 || _recent_menu_path.is_empty():
		return
	Config.remove_recent_skin(_recent_menu_path)
	_recent_menu_path = ""
	_refresh_welcome_recents()


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
	_save_all_loop_offsets()
	if mark_as_saved:
		_mark_saved()
		_run_pending_after_save()
	else:
		_pending_after_unsaved = Callable()

func _folder_has_suit(path: String) -> bool:
	if !DirAccess.dir_exists_absolute(path):
		return false
	for dir in DirAccess.get_directories_at(path):
		if dir in PlayerSkin.STATES:
			return true
	return false


func _first_available_state_index() -> int:
	for i in PlayerSkin.STATES.size():
		if skin_settings.has(PlayerSkin.STATES[i]):
			return i
	if current_folder_skin:
		for i in PlayerSkin.STATES.size():
			if DirAccess.dir_exists_absolute(current_folder_skin.path_join(PlayerSkin.STATES[i])):
				return i
	return 0


## Opens folder where skins located.
func open_file(path: String, from_recent: bool = false) -> void:
	print("Loading folder content: %s" % path)
	if !_folder_has_suit(path):
		if from_recent:
			OS.alert("Could not open skin:\n%s" % path)
			Config.remove_recent_skin(path)
			_refresh_welcome_recents()
		else:
			OS.alert("Please select a skin root directory that contains suit folders.")
			open_dialog.current_dir = path
			open_dialog.popup_centered.call_deferred()
		return
	
	current_folder_skin = path
	skin_settings = {}
	current_skin_setting = null
	_last_state = -1
	for dir in DirAccess.get_directories_at(path):
		load_skin_settings_from_file(dir, path)
	
	_loop_offsets_by_suit.clear()
	_loop_offsets.clear()
	load_misc_files(path)
	
	skin_name = path.get_slice("/", path.get_slice_count("/") - 1)
	reset_options_dialog()
	var state_idx := _first_available_state_index()
	set_state(state_idx)
	state_option.select(state_idx)
	version_label.text = PROJECT_NAME % [version_string] + ("\n" + current_folder_skin)
	
	Config.add_recent_skin(path)
	_set_controls_working(true)
	_close_welcome()
	_reset_history()

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
	_loop_offsets_by_suit.clear()
	_loop_offsets.clear()
	load_misc_files(path)
	_on_dialog_new_settings_confirmed()
	
	skin_name = path.get_slice("/", path.get_slice_count("/") - 1)
	reset_options_dialog()
	set_state(0)
	state_option.select(0)
	version_label.text = PROJECT_NAME % [version_string] + ("\n" + current_folder_skin)
	
	Config.add_recent_skin(path)
	_set_controls_working(true)
	_close_welcome()
	_reset_history()

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
	var suit := str(current_skin_setting.name) if current_skin_setting else ""
	if suit && _loop_offsets_by_suit.has(suit):
		_loop_offsets = _loop_offsets_by_suit[suit]
		_update_loop_offset_spin()
		return
	_loop_offsets = _default_loop_offsets()
	if !current_folder_skin:
		if suit:
			_loop_offsets_by_suit[suit] = _loop_offsets
		_update_loop_offset_spin()
		return
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
	if suit:
		_loop_offsets_by_suit[suit] = _loop_offsets
	_update_loop_offset_spin()


func _save_all_loop_offsets() -> void:
	if current_skin_setting:
		_loop_offsets_by_suit[str(current_skin_setting.name)] = _loop_offsets.duplicate()
	for suit in _loop_offsets_by_suit.keys():
		_save_loop_offsets_for(str(suit), _loop_offsets_by_suit[suit])


func _save_loop_offsets() -> void:
	if !current_skin_setting:
		return
	_save_loop_offsets_for(str(current_skin_setting.name), _loop_offsets)


func _save_loop_offsets_for(suit: String, offsets: Dictionary) -> void:
	if !current_folder_skin || suit.is_empty():
		return
	var path := _suit_tweaks_path(suit)
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
	data["loop_frame_offsets"] = offsets.duplicate()
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
	var spin: SpinBox = loop_offset_spin
	var offset := _get_loop_offset(preview.animation)
	var max_frame := 0
	if preview.sprite_frames && preview.animation:
		max_frame = maxi(preview.sprite_frames.get_frame_count(preview.animation) - 1, 0)
	_updating_loop_offset = true
	spin.max_value = max_frame
	spin.value = offset
	_updating_loop_offset = false
	if offset < 0:
		loop_checkbox.tooltip_text = "Whether the animation should loop."
	else:
		loop_checkbox.tooltip_text = "Whether the animation should loop.\nLoop Frame Offset %d: after looping, playback continues from this frame." % offset


func _on_loop_offset_changed(value: float) -> void:
	if _updating_loop_offset || _updating_ui || _applying_history || !preview.animation:
		return
	var anim := String(preview.animation)
	var old := _get_loop_offset(preview.animation)
	var new_val := int(value)
	if old == new_val:
		return
	_commit_edit(
		"Set Loop Offset (%s)" % anim,
		_apply_loop_offset.bind(_current_suit(), anim, new_val),
		_apply_loop_offset.bind(_current_suit(), anim, old),
		UndoRedo.MERGE_ENDS
	)


## Updates animation duration display counter.
func update_anim_time() -> void:
	if !preview.animation || !preview.sprite_frames:
		anim_time_label.text = "-"
		return
	var frame_count = preview.sprite_frames.get_frame_count(preview.animation)
	if frame_count > 200:
		anim_time_label.text = "Too long"
		return
	var number: float = 0.0
	for i in frame_count:
		var relative_duration = preview.sprite_frames.get_frame_duration(preview.animation, i)
		var absolute_duration = relative_duration / abs(preview.sprite_frames.get_animation_speed(preview.animation))
		number += absolute_duration
		
	if is_finite(number) && number > 999:
		anim_time_label.text = "999+ sec"
		return
	anim_time_label.text = "%s sec" % String.num(number, 4)


## Logic for side panel resizing.
func _on_h_split_container_dragged(_offset: int) -> void:
	_on_window_resized(true)

func _on_window_resized(_force_update: bool = false) -> void:
	%Camera2D.apply_layout_change()

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
	_sync_frames_spinbox()

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
