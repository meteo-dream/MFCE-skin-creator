extends Window
class_name SkinSettingsDialog

enum Tab { OPTIONS, MISC, SOUNDS, GLOBAL }
enum Field { NAME, THEY, THEM, THEIR, ALIAS }

signal dismissed
signal reset_pressed
signal options_field_changed(field: Field, new_value: String)

@onready var tabs: TabContainer = %SettingsTabs
@onready var misc_textures: SuitTweaksDialog = %MiscTexturesDialog
@onready var global_sounds: SuitTweaksDialog = %GlobalSoundsDialog
@onready var global_tweaks: SuitTweaksDialog = %GlobalSkinTweaksDialog
@onready var display_name_line: LineEdit = %DisplayNameLine
@onready var they_line: LineEdit = %TheyLine
@onready var them_line: LineEdit = %ThemLine
@onready var their_line: LineEdit = %TheirLine
@onready var description_line: LineEdit = %DescriptionLine
@onready var reset_button: Button = %ResetTweaks
@onready var close_button: Button = %CloseTweaks

var _ignore_close := false
var _updating := false


func _ready() -> void:
	exclusive = false
	transient = true
	popup_window = false
	unresizable = false
	close_requested.connect(_on_close_requested)
	focus_entered.connect(_on_focus_entered)
	tabs.tab_changed.connect(_on_tab_changed)
	reset_button.pressed.connect(func(): reset_pressed.emit())
	close_button.pressed.connect(dismiss)
	misc_textures.resettable_changed.connect(update_reset_button)
	global_sounds.resettable_changed.connect(update_reset_button)
	global_tweaks.resettable_changed.connect(update_reset_button)
	_connect_field(display_name_line, Field.NAME)
	_connect_field(they_line, Field.THEY)
	_connect_field(them_line, Field.THEM)
	_connect_field(their_line, Field.THEIR)
	_connect_field(description_line, Field.ALIAS)
	if tabs.get_tab_count() >= 4:
		tabs.set_tab_title(Tab.OPTIONS, "Name")
		tabs.set_tab_title(Tab.MISC, "Misc Textures")
		tabs.set_tab_title(Tab.SOUNDS, "Global Sounds")
		tabs.set_tab_title(Tab.GLOBAL, "Global Skin Tweaks")
	_update_title()
	update_reset_button()


func _connect_field(line: LineEdit, field: Field) -> void:
	line.text_changed.connect(func(text: String): _on_field_text_changed(field, text))


func current_tab() -> Tab:
	return tabs.current_tab as Tab


func open_on_tab(tab: Tab) -> void:
	tabs.current_tab = int(tab)
	_update_title()
	update_reset_button()


func dismiss() -> void:
	dismissed.emit()
	hide()


func update_title() -> void:
	_update_title()


func set_updating(on: bool) -> void:
	_updating = on


func field_line(field: Field) -> LineEdit:
	match field:
		Field.NAME:
			return display_name_line
		Field.THEY:
			return they_line
		Field.THEM:
			return them_line
		Field.THEIR:
			return their_line
		Field.ALIAS:
			return description_line
	return display_name_line


func field_value(field: Field) -> String:
	return field_line(field).text


func set_field_value(field: Field, value: String) -> void:
	var line := field_line(field)
	var text := value.to_upper() if field == Field.NAME else value
	if line.text == text:
		return
	_updating = true
	line.text = text
	_updating = false


func load_options(name_placeholder: String, display_name: String, they: String, them: String, alias: String, their: String) -> void:
	_updating = true
	display_name_line.placeholder_text = name_placeholder
	display_name_line.text = display_name.to_upper()
	they_line.text = they
	them_line.text = them
	description_line.text = alias
	their_line.text = their
	_updating = false
	update_reset_button()


func options_at_defaults() -> bool:
	return (
		display_name_line.text.is_empty()
		&& they_line.text.is_empty()
		&& them_line.text.is_empty()
		&& their_line.text.is_empty()
		&& description_line.text.is_empty()
	)


func update_reset_button() -> void:
	if !reset_button:
		return
	var can_reset := false
	match current_tab():
		Tab.OPTIONS:
			can_reset = !options_at_defaults()
		Tab.MISC:
			can_reset = misc_textures.has_resettable_changes()
		Tab.SOUNDS:
			can_reset = global_sounds.has_resettable_changes()
		Tab.GLOBAL:
			can_reset = global_tweaks.has_resettable_changes()
	reset_button.disabled = !can_reset
	reset_button.tooltip_text = (
		"Reset this tab's values to their defaults."
		if can_reset
		else "Nothing to reset."
	)


func _on_field_text_changed(field: Field, text: String) -> void:
	if _updating:
		return
	var value := text
	if field == Field.NAME:
		value = text.to_upper()
		if display_name_line.text != value:
			var col := display_name_line.caret_column
			_updating = true
			display_name_line.text = value
			display_name_line.caret_column = mini(col, value.length())
			_updating = false
	options_field_changed.emit(field, value)
	update_reset_button()


func _on_tab_changed(_tab: int) -> void:
	_update_title()
	update_reset_button()


func _update_title() -> void:
	match tabs.current_tab:
		Tab.OPTIONS:
			title = "Skin Options"
		Tab.MISC:
			title = "Misc Textures"
		Tab.SOUNDS:
			title = "Global Sounds"
		Tab.GLOBAL:
			title = "Global Skin Tweaks"


func _on_focus_entered() -> void:
	_ignore_close = true
	get_tree().create_timer(0.15).timeout.connect(func(): _ignore_close = false)


func _on_close_requested() -> void:
	if _ignore_close:
		return
	dismiss()
