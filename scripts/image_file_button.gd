extends MenuButton
class_name ImageFileButton

## Dropdown that shows a PNG filename. Replace opens a native file dialog;
## Open in File Explorer reveals the copied file. The parent copies on file_chosen.

signal file_chosen(path: String)

const ITEM_REPLACE := 0
const ITEM_REVEAL := 1

static var last_dir := ""

@export var empty_text := "Select PNG..."
@export var dialog_title := "Select PNG"
@export var filters := PackedStringArray(["*.png ; PNG Images"])

var _filename := ""
var _abs_path := ""

@onready var _dialog: FileDialog = $FileDialog


func _ready() -> void:
	flat = false
	clip_text = true
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_dialog.use_native_dialog = true
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.filters = filters
	_dialog.title = dialog_title
	_dialog.file_selected.connect(_on_file_selected)
	var popup := get_popup()
	popup.id_pressed.connect(_on_id_pressed)
	popup.about_to_popup.connect(_rebuild_menu)
	_refresh_text()
	_rebuild_menu()


func set_display(filename: String, abs_path: String = "") -> void:
	_filename = filename
	_abs_path = abs_path
	_refresh_text()
	if is_node_ready():
		_rebuild_menu()


func get_filename() -> String:
	return _filename


func _refresh_text() -> void:
	text = _filename if !_filename.is_empty() else empty_text


func _rebuild_menu() -> void:
	var popup := get_popup()
	popup.clear()
	popup.add_item("Replace..." if !_filename.is_empty() else "Select PNG...", ITEM_REPLACE)
	popup.add_item("Open in File Explorer", ITEM_REVEAL)
	var can_reveal := !_abs_path.is_empty() && FileAccess.file_exists(_abs_path)
	popup.set_item_disabled(popup.get_item_index(ITEM_REVEAL), !can_reveal)


func _on_id_pressed(id: int) -> void:
	match id:
		ITEM_REPLACE:
			_popup_dialog()
		ITEM_REVEAL:
			_reveal()


func _popup_dialog() -> void:
	get_popup().hide()
	if !last_dir.is_empty() && DirAccess.dir_exists_absolute(last_dir):
		_dialog.current_dir = last_dir
	_dialog.popup_centered()


func _on_file_selected(path: String) -> void:
	last_dir = path.get_base_dir()
	file_chosen.emit(path)


func _reveal() -> void:
	if _abs_path.is_empty():
		return
	var path := _abs_path
	if !path.is_absolute_path():
		path = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		OS.shell_show_in_file_manager(path)
	elif DirAccess.dir_exists_absolute(path.get_base_dir()):
		OS.shell_open(path.get_base_dir())
