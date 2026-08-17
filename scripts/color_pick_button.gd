extends ColorPickerButton

var old_value

func _ready() -> void:
	old_value = color
	gui_input.connect(_on_gui_input)
	picker_created.connect(_on_picker_created, CONNECT_ONE_SHOT)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			color = old_value
			color_changed.emit(color)

func _on_picker_created() -> void:
	var dialog = get_popup()
	get_tree().current_scene.scale_window(dialog)
