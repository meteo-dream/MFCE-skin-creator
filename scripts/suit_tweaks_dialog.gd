extends Window
class_name SuitTweaksDialog

signal tweak_changed(path: PackedStringArray, new_value: Variant, old_value: Variant)
signal reset_requested

const SPIN_SCRIPT := preload("res://scripts/spinbox.gd")
const COLOR_SCRIPT := preload("res://scripts/color_pick_button.gd")

@onready var list: VBoxContainer = %TweakList
@onready var reset_button: Button = %ResetTweaks
@onready var close_button: Button = %CloseTweaks
@onready var hint_label: Label = %Hint

var _updating := false
var _ignore_close := false
var _controls: Dictionary = {}
var _values: Dictionary = {}
var _defaults: Dictionary = {}
var _descriptions: Dictionary = {}
var _limits: Dictionary = {}
var _skip: Array = []
var _choices: Dictionary = {}


func _ready() -> void:
	exclusive = false
	transient = true
	popup_window = false
	unresizable = false
	close_requested.connect(_on_close_requested)
	focus_entered.connect(_on_focus_entered)
	close_button.pressed.connect(hide)
	reset_button.pressed.connect(func(): reset_requested.emit())


func _on_focus_entered() -> void:
	_ignore_close = true
	get_tree().create_timer(0.15).timeout.connect(func(): _ignore_close = false)


func _on_close_requested() -> void:
	if _ignore_close:
		return
	hide()


func bind(window_title: String, tweaks: Dictionary, schema: Dictionary) -> void:
	title = window_title
	if hint_label:
		hint_label.text = str(schema.get("hint", hint_label.text))
	_defaults = schema.get("defaults", {})
	_descriptions = schema.get("descriptions", {})
	_limits = schema.get("limits", {})
	_skip = schema.get("skip", [])
	_choices = schema.get("choices", {})
	_values = tweaks
	_rebuild()


func sync_value(path: PackedStringArray, value: Variant) -> void:
	var key := _path_key(path)
	if !_controls.has(key):
		return
	_updating = true
	_set_control(_controls[key], value)
	_updating = false


func _rebuild() -> void:
	_updating = true
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	_controls.clear()
	if _values.is_empty() || _defaults.is_empty():
		_updating = false
		return
	for key in _defaults.keys():
		if key in _skip:
			continue
		var value: Variant = _values.get(key, _defaults[key])
		if value is Dictionary:
			_add_section(key, value)
		else:
			_add_row(PackedStringArray([key]), value, false)
	_updating = false


func _add_section(key: String, nested: Dictionary) -> void:
	var header := Label.new()
	header.text = SuitTweaks.display_name(key)
	header.tooltip_text = _desc(key)
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85, 1))
	list.add_child(header)
	var nested_defaults: Dictionary = _defaults[key] if _defaults.get(key) is Dictionary else nested
	var order: Array = nested_defaults.keys()
	for sub in order:
		_add_row(PackedStringArray([key, str(sub)]), nested.get(sub, nested_defaults[sub]), true)


func _add_row(path: PackedStringArray, value: Variant, indented: bool) -> void:
	var key := path[path.size() - 1]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if indented:
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(12, 0)
		row.add_child(pad)
	var label := Label.new()
	label.text = SuitTweaks.display_name(key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.tooltip_text = _desc(key)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	var control := _make_control(path, value)
	if control:
		control.tooltip_text = _desc(key)
		row.add_child(control)
		_controls[_path_key(path)] = control
	row.tooltip_text = _desc(key)
	list.add_child(row)


func _make_control(path: PackedStringArray, value: Variant) -> Control:
	var key := path[path.size() - 1]
	if _choices.has(key):
		return _make_choice(path, str(value), _choices[key])
	if value is bool:
		var box := CheckBox.new()
		box.button_pressed = value
		box.custom_minimum_size = Vector2(26, 26)
		box.toggled.connect(func(on: bool): _emit_change(path, on))
		return box
	if SuitTweaks.is_html_color(value):
		var picker := ColorPickerButton.new()
		picker.set_script(COLOR_SCRIPT)
		picker.custom_minimum_size = Vector2(96, 28)
		picker.edit_alpha = true
		picker.color = Color.from_string(str(value), Color.WHITE)
		picker.color_changed.connect(func(color: Color): _emit_change(path, SuitTweaks.color_to_html(color)))
		return picker
	if SuitTweaks.is_vec2(value):
		return _make_vec2(path, SuitTweaks.to_vec2(value))
	if value is int || value is float:
		var spin := SpinBox.new()
		spin.set_script(SPIN_SCRIPT)
		spin.custom_minimum_size = Vector2(108, 0)
		spin.size_flags_horizontal = Control.SIZE_SHRINK_END
		var lim := _limits_for(key)
		spin.min_value = float(lim.get("min", -99999.0))
		spin.max_value = float(lim.get("max", 99999.0))
		spin.step = float(lim.get("step", 1.0 if value is int else 0.01))
		spin.allow_greater = !lim.has("max")
		spin.allow_lesser = !lim.has("min")
		spin.value = float(value)
		spin.rounded = is_equal_approx(spin.step, 1.0)
		spin.value_changed.connect(func(v: float):
			if spin.rounded:
				_emit_change(path, int(v))
			else:
				_emit_change(path, v)
		)
		return spin
	return null


func _make_choice(path: PackedStringArray, value: String, options: Variant) -> Control:
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(108, 0)
	opt.size_flags_horizontal = Control.SIZE_SHRINK_END
	var selected := 0
	var i := 0
	for item in options:
		var text := str(item)
		opt.add_item(text)
		if text == value:
			selected = i
		i += 1
	opt.select(selected)
	opt.item_selected.connect(func(idx: int): _emit_change(path, opt.get_item_text(idx)))
	return opt


func _make_vec2(path: PackedStringArray, vec: Vector2) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var spin_x := _make_axis_spin(vec.x)
	var spin_y := _make_axis_spin(vec.y)
	var lim := _limits_for(path[path.size() - 1])
	for spin in [spin_x, spin_y]:
		if lim.has("min"):
			spin.min_value = float(lim.min)
		if lim.has("max"):
			spin.max_value = float(lim.max)
		if lim.has("step"):
			spin.step = float(lim.step)
			spin.rounded = is_equal_approx(spin.step, 1.0)
	spin_x.prefix = "X:"
	spin_y.prefix = "Y:"
	var emit := func(_v: float):
		_emit_change(path, SuitTweaks.vec2_to_json(Vector2(spin_x.value, spin_y.value)))
	spin_x.value_changed.connect(emit)
	spin_y.value_changed.connect(emit)
	box.add_child(spin_x)
	box.add_child(spin_y)
	box.set_meta("spin_x", spin_x)
	box.set_meta("spin_y", spin_y)
	return box


func _make_axis_spin(value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.set_script(SPIN_SCRIPT)
	spin.custom_minimum_size = Vector2(72, 0)
	spin.step = 1.0
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.value = value
	return spin


func _set_control(control: Control, value: Variant) -> void:
	if control is CheckBox:
		(control as CheckBox).button_pressed = bool(value)
	elif control is ColorPickerButton:
		(control as ColorPickerButton).color = Color.from_string(str(value), Color.WHITE)
	elif control is SpinBox:
		(control as SpinBox).value = float(value)
	elif control is OptionButton:
		var opt := control as OptionButton
		var text := str(value)
		for i in opt.item_count:
			if opt.get_item_text(i) == text:
				opt.select(i)
				return
	elif control is HBoxContainer && control.has_meta("spin_x"):
		var vec := SuitTweaks.to_vec2(value)
		(control.get_meta("spin_x") as SpinBox).value = vec.x
		(control.get_meta("spin_y") as SpinBox).value = vec.y


func _emit_change(path: PackedStringArray, new_value: Variant) -> void:
	if _updating:
		return
	var old_value: Variant = SuitTweaks.get_at(_values, path)
	if _values_equal(old_value, new_value):
		return
	tweak_changed.emit(path, new_value, old_value)


func _values_equal(a: Variant, b: Variant) -> bool:
	if SuitTweaks.is_vec2(a) || SuitTweaks.is_vec2(b):
		return SuitTweaks.to_vec2(a).is_equal_approx(SuitTweaks.to_vec2(b))
	if a is float || b is float:
		return is_equal_approx(float(a), float(b))
	return a == b


func _path_key(path: PackedStringArray) -> String:
	return "/".join(path)


func _desc(key: String) -> String:
	return str(_descriptions.get(key, ""))


func _limits_for(key: String) -> Dictionary:
	var lim = _limits.get(key, {})
	return lim if lim is Dictionary else {}
