extends SpinBox

@export var disable_scroll: bool = false
@onready var line: LineEdit = get_line_edit()

var _syncing_line := false


func _ready() -> void:
	# LineEdit has its own Ctrl+Z stack. That reverts the displayed text without
	# changing Range.value, so the next arrow/wheel step is applied on top of the
	# undone value (1.00 shown, 1.10 stored → next click becomes 1.20).
	line.shortcut_keys_enabled = false
	line.gui_input.connect(_on_gui_input)
	value_changed.connect(_on_value_changed)
	if !disable_scroll:
		mouse_force_pass_scroll_events = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _on_value_changed(_value: float) -> void:
	_sync_line_from_value()


func _sync_line_from_value() -> void:
	if !line || _syncing_line:
		return
	var text := _format_line_text()
	if line.text == text:
		return
	_syncing_line = true
	var caret := line.caret_column
	line.text = text
	line.caret_column = mini(caret, text.length())
	_syncing_line = false


func _format_line_text() -> String:
	var num := String.num(value, _step_decimals(step))
	if line.is_editing():
		return num
	if !prefix.is_empty():
		num = prefix + " " + num
	if !suffix.is_empty():
		num += " " + suffix
	return num


func _step_decimals(p_step: float) -> int:
	var abs_step := absf(p_step)
	if abs_step < 1e-12:
		return 12
	var decimals := 0
	var probe := abs_step
	while decimals < 12 && probe < 1.0 - 1e-12:
		probe *= 10.0
		decimals += 1
	return decimals


func _on_gui_input(event: InputEvent) -> void:
	if !editable:
		return
	if event is InputEventKey && event.pressed && !event.echo && event.is_command_or_control_pressed() && !event.alt_pressed:
		match event.keycode:
			KEY_A:
				line.select_all()
				line.accept_event()
			KEY_C:
				if line.has_selection():
					DisplayServer.clipboard_set(line.get_selected_text())
				line.accept_event()
			KEY_X:
				if line.has_selection():
					DisplayServer.clipboard_set(line.get_selected_text())
					line.delete_text(line.get_selection_from_column(), line.get_selection_to_column())
				line.accept_event()
			KEY_V:
				line.insert_text_at_caret(DisplayServer.clipboard_get())
				line.accept_event()
			KEY_Z, KEY_Y:
				# Keep Range and text aligned, then let the editor undo/redo shortcut run.
				_sync_line_from_value()
		return
	if disable_scroll:
		return
	if event is InputEventMouseButton:
		if ![MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP].has(event.button_index):
			return
		line.grab_focus()
