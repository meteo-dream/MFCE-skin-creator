extends PanelContainer
class_name HistoryDock

signal seek_requested(action_index: int)
signal open_changed(open: bool)

const REDO_COLOR := Color(1.0, 1.0, 1.0, 0.4)
const BEGINNING_COLOR := Color(0.7, 0.7, 0.7, 1.0)
const FLOAT_MIN_WIDTH := 220
const FLOAT_HEIGHT := 600

@onready var float_button: Button = $VBox/TitleBar/FloatButton
@onready var close_button: Button = $VBox/TitleBar/CloseButton
@onready var list: ItemList = $VBox/HistoryList

var _updating := false
var _floating := false
var _split: SplitContainer
var _window: Window


func _ready() -> void:
	mouse_force_pass_scroll_events = false
	list.mouse_force_pass_scroll_events = false
	_split = get_parent() as SplitContainer
	_window = %HistoryWindow
	add_to_group("history_dock")
	float_button.pressed.connect(toggle_floating)
	close_button.pressed.connect(_on_close_pressed)
	list.item_selected.connect(_on_item_selected)
	_window.close_requested.connect(_on_window_close)
	_update_float_button()


func is_open() -> bool:
	if _floating:
		return _window.visible
	return visible


func is_floating() -> bool:
	return _floating


func set_open(open: bool, emit_change: bool = true) -> void:
	if open == is_open():
		return
	if _floating:
		if open:
			_window.show()
			_window.grab_focus()
		else:
			_window.hide()
	else:
		visible = open
	if emit_change:
		open_changed.emit(is_open())


func toggle_floating() -> void:
	set_floating(!_floating)


func set_floating(floating: bool, emit_change: bool = true) -> void:
	if floating == _floating:
		return
	var keep_open := is_open()
	var origin := Vector2i(get_global_rect().position)
	var sz := size
	if floating:
		_undock()
		_window.size = Vector2i(maxi(int(sz.x), FLOAT_MIN_WIDTH), FLOAT_HEIGHT)
		if origin != Vector2i.ZERO:
			_window.position = origin
	else:
		_redock()
	if keep_open:
		if _floating:
			if origin == Vector2i.ZERO:
				_window.popup_centered()
			else:
				_window.show()
		else:
			visible = true
	elif _floating:
		_window.hide()
	else:
		visible = false
	_update_float_button()
	if emit_change:
		open_changed.emit(is_open())


func refresh(undo_redo: UndoRedo) -> void:
	if !is_inside_tree():
		return
	_updating = true
	list.clear()
	var count := undo_redo.get_history_count()
	var current := undo_redo.get_current_action()
	for i in range(count - 1, -1, -1):
		var action_name := undo_redo.get_action_name(i)
		if action_name.is_empty():
			action_name = "Action %d" % (i + 1)
		list.add_item(action_name)
		var idx := list.item_count - 1
		list.set_item_metadata(idx, i)
		if i > current:
			list.set_item_custom_fg_color(idx, REDO_COLOR)
	list.add_item("The Beginning")
	var begin_idx := list.item_count - 1
	list.set_item_metadata(begin_idx, -1)
	list.set_item_custom_fg_color(begin_idx, BEGINNING_COLOR)
	var select_idx := begin_idx if current < 0 else (count - 1 - current)
	if select_idx >= 0 && select_idx < list.item_count:
		list.select(select_idx)
		list.ensure_current_is_visible()
	_updating = false


func apply_window_rect(rect: Rect2i) -> void:
	if rect.size.x < _window.min_size.x || rect.size.y < _window.min_size.y:
		return
	_window.position = rect.position
	_window.size = rect.size


func get_window_rect() -> Rect2i:
	return Rect2i(_window.position, _window.size)


func _undock() -> void:
	var parent := get_parent()
	if parent:
		parent.remove_child(self)
	_window.add_child(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	visible = true
	_floating = true


func _redock() -> void:
	_window.hide()
	if get_parent() == _window:
		_window.remove_child(self)
		if _split:
			_split.add_child(self)
	_floating = false
	layout_mode = 2
	size_flags_horizontal = Control.SIZE_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(200, 0)
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0


func _on_window_close() -> void:
	set_floating(false)


func _on_close_pressed() -> void:
	set_open(false)


func _on_item_selected(index: int) -> void:
	if _updating:
		return
	if index < 0 || index >= list.item_count:
		return
	seek_requested.emit(int(list.get_item_metadata(index)))


func _update_float_button() -> void:
	if !float_button:
		return
	if _floating:
		float_button.tooltip_text = "Dock"
	else:
		float_button.tooltip_text = "Make Floating"
