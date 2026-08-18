extends SpinBox

@export var disable_scroll: bool = false
@onready var line: LineEdit = get_line_edit()

func _ready() -> void:
	line.gui_input.connect(_on_gui_input)
	if !disable_scroll:
		mouse_force_pass_scroll_events = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _on_gui_input(event: InputEvent) -> void:
	if !editable: return
	if disable_scroll:
		return
	if event is InputEventMouseButton:
		if ![MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP].has(event.button_index): return
		line.grab_focus()
	
