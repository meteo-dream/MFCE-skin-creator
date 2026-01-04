extends ColorPickerButton

var old_value

func _ready() -> void:
	old_value = color
	gui_input.connect(_on_gui_input)
	pressed.connect(_on_picker_created)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			color = old_value
			color_changed.emit(color)

func _on_picker_created() -> void:
	await get_tree().process_frame
	var colorpick = get_popup()
	_set_scale()
	Util._connect(colorpick.size_changed, _set_scale, CONNECT_ONE_SHOT)

func _set_scale() -> void:
	var dialog = get_popup()
	var scene = get_tree().current_scene
	if dialog.content_scale_factor != scene.editor_scale:
		dialog.content_scale_factor = scene.editor_scale
	dialog.size *= scene.editor_scale
	dialog.min_size *= scene.editor_scale
	var usable_size = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen(0)).size
	if dialog.size.y > usable_size.y:
		dialog.size.y = usable_size.y
	if dialog.size.x > usable_size.x:
		dialog.size.x = usable_size.x
	if dialog.position.x + dialog.size.x > usable_size.x:
		dialog.position.x = usable_size.x - dialog.size.x
	if dialog.position.y + dialog.size.y > usable_size.y:
		dialog.position.y = usable_size.y - dialog.size.y
	
