extends VBoxContainer
class_name ImageFileButton

## Filename chip that asks the parent to open a shared file dialog.
## Replace / Select emits pick_requested. Add Variation(s) emits add_requested.

signal pick_requested
signal add_requested
signal variation_removed(index: int)
signal expansion_changed(expanded: bool)

const ITEM_REPLACE := 0
const ITEM_ADD := 1
const ITEM_REVEAL := 2
const EXPAND_ICON := preload("res://icons/GuiOptionArrow.svg")
const REMOVE_ICON := preload("res://icons/Remove.svg")

static var last_dir := ""

@export var empty_text := "Select PNG..."
@export var dialog_title := "Select PNG"
@export var filters := PackedStringArray(["*.png ; PNG Images"])
@export var allow_multiple := false
@export var max_files := 11

var _filenames: PackedStringArray = PackedStringArray()
var _abs_paths: PackedStringArray = PackedStringArray()
var _expanded := false
var _blank_normal := StyleBoxEmpty.new()
var _icon_hover := StyleBoxFlat.new()
var _icon_pressed := StyleBoxFlat.new()
var _expand_icon_pressed := StyleBoxFlat.new()

@onready var _menu: MenuButton = %Menu
@onready var _expand: Button = %Expand
@onready var _list_panel: Control = %ListPanel
@onready var _list: VBoxContainer = %List


func _ready() -> void:
	_setup_icon_button_styles()
	_menu.flat = false
	_menu.clip_text = true
	_menu.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_menu.alignment = HORIZONTAL_ALIGNMENT_LEFT
	#_menu.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_menu.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_expand.focus_mode = Control.FOCUS_NONE
	_expand.toggle_mode = true
	_expand.flat = false
	_expand.text = ""
	_expand.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_expand.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	#_expand.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_icon_button_styles(_expand)
	_expand.add_theme_stylebox_override("pressed", _expand_icon_pressed)
	_expand.add_theme_stylebox_override("hover_pressed", _expand_icon_pressed)
	_expand.pressed.connect(_toggle_expanded)
	var popup := _menu.get_popup()
	popup.id_pressed.connect(_on_id_pressed)
	popup.about_to_popup.connect(_rebuild_menu)
	_refresh()


func set_display(filename: String, abs_path: String = "") -> void:
	var names := PackedStringArray()
	var paths := PackedStringArray()
	if !filename.is_empty():
		names.append(filename)
		paths.append(abs_path)
	set_files(names, paths)


func set_files(filenames: PackedStringArray, abs_paths: PackedStringArray = PackedStringArray()) -> void:
	_filenames = filenames.duplicate()
	_abs_paths = abs_paths.duplicate()
	if _filenames.size() <= 1:
		_expanded = false
	_refresh()


func set_expanded(on: bool) -> void:
	var want := on && _filenames.size() > 1
	if _expanded == want:
		_refresh_expand()
		return
	_expanded = want
	_refresh_expand()
	expansion_changed.emit(_expanded)


func get_filename() -> String:
	return _filenames[0] if !_filenames.is_empty() else ""


func get_filenames() -> PackedStringArray:
	return _filenames.duplicate()


func get_abs_paths() -> PackedStringArray:
	return _abs_paths.duplicate()


func _setup_icon_button_styles() -> void:
	_blank_normal.set_content_margin_all(0)
	for box in [_icon_hover, _icon_pressed, _expand_icon_pressed]:
		box.set_content_margin_all(0)
		box.set_border_width_all(0)
		box.set_expand_margin_all(0)
		box.set_corner_radius_all(3)
		box.corner_detail = 5
	_icon_hover.bg_color = Color(1, 1, 1, 0.1)
	_icon_pressed.bg_color = Color(1, 1, 1, 0.16)
	_expand_icon_pressed.bg_color = Color(0, 0, 0, 0.6)


func _apply_icon_button_styles(button: BaseButton) -> void:
	button.add_theme_stylebox_override("normal", _blank_normal)
	button.add_theme_stylebox_override("hover", _icon_hover)
	button.add_theme_stylebox_override("pressed", _icon_pressed)
	button.add_theme_stylebox_override("hover_pressed", _icon_pressed)
	button.add_theme_stylebox_override("focus", _blank_normal)
	button.add_theme_constant_override("h_separation", 0)
	button.add_theme_constant_override("align_to_largest_stylebox", 0)


func _refresh() -> void:
	_refresh_text()
	if is_node_ready():
		_rebuild_menu()
		_rebuild_list()
		_refresh_expand()


func _refresh_text() -> void:
	if !is_node_ready():
		return
	if _filenames.is_empty():
		_menu.text = empty_text
	elif _filenames.size() == 1:
		_menu.text = _filenames[0]
	else:
		_menu.text = "%s + %d" % [_filenames[0], _filenames.size() - 1]


func _refresh_expand() -> void:
	if !is_node_ready():
		return
	var can_expand := allow_multiple && _filenames.size() > 1
	_expand.visible = can_expand
	_expand.icon = EXPAND_ICON
	_expand.tooltip_text = "Hide variations" if _expanded else "Show all variations"
	_list_panel.visible = can_expand && _expanded


func _rebuild_menu() -> void:
	var popup := _menu.get_popup()
	popup.clear()
	var pick_text := empty_text
	if !_filenames.is_empty():
		pick_text = "Replace..."
	popup.add_item(pick_text, ITEM_REPLACE)
	if allow_multiple:
		popup.add_item("Add Variation(s)...", ITEM_ADD)
		popup.set_item_disabled(
			popup.get_item_index(ITEM_ADD),
			_filenames.is_empty() || _filenames.size() >= max_files
		)
	popup.add_item("Open in File Explorer", ITEM_REVEAL)
	var can_reveal := false
	for path in _abs_paths:
		if !path.is_empty() && (FileAccess.file_exists(path) || DirAccess.dir_exists_absolute(path.get_base_dir())):
			can_reveal = true
			break
	popup.set_item_disabled(popup.get_item_index(ITEM_REVEAL), !can_reveal)


func _rebuild_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var show_delete := _filenames.size() > 1
	for i in _filenames.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var name_btn := Button.new()
		name_btn.flat = true
		name_btn.clip_text = true
		name_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_btn.text = _filenames[i]
		name_btn.tooltip_text = "Open in File Explorer"
		name_btn.focus_mode = Control.FOCUS_NONE
		var path := _abs_paths[i] if i < _abs_paths.size() else ""
		name_btn.pressed.connect(_reveal_path.bind(path))
		row.add_child(name_btn)
		if show_delete:
			var trash := Button.new()
			trash.icon = REMOVE_ICON
			trash.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			trash.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
			trash.focus_mode = Control.FOCUS_NONE
			trash.custom_minimum_size = Vector2(22, 16)
			trash.tooltip_text = "Delete this variation"
			_apply_icon_button_styles(trash)
			var idx := i
			trash.pressed.connect(func(): variation_removed.emit(idx))
			row.add_child(trash)
		_list.add_child(row)


func _toggle_expanded() -> void:
	set_expanded(!_expanded)


func _on_id_pressed(id: int) -> void:
	match id:
		ITEM_REPLACE:
			_menu.get_popup().hide()
			pick_requested.emit()
		ITEM_ADD:
			_menu.get_popup().hide()
			add_requested.emit()
		ITEM_REVEAL:
			_reveal()


func _reveal() -> void:
	if _abs_paths.is_empty():
		return
	if _abs_paths.size() == 1:
		_reveal_path(_abs_paths[0])
		return
	var folder := _abs_paths[0].get_base_dir()
	if DirAccess.dir_exists_absolute(folder):
		OS.shell_open(folder)


func _reveal_path(path: String) -> void:
	if path.is_empty():
		return
	if !path.is_absolute_path():
		path = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		OS.shell_show_in_file_manager(path)
	elif DirAccess.dir_exists_absolute(path.get_base_dir()):
		OS.shell_open(path.get_base_dir())
