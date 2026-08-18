extends MarginContainer
class_name SuitTweaksDialog

signal tweak_changed(path: PackedStringArray, new_value: Variant, old_value: Variant)
signal resettable_changed

const SPIN_SCRIPT := preload("res://scripts/spinbox.gd")
const COLOR_SCRIPT := preload("res://scripts/color_pick_button.gd")
const IMAGE_FILE_BUTTON := preload("res://image_file_button.tscn")
const REVERT_ICON := preload("res://icons/ReloadSmall.svg")

@onready var list: VBoxContainer = %TweakList
@onready var hint_label: Label = %Hint

var heading := ""
var _updating := false
var _controls: Dictionary = {}
var _revert_buttons: Dictionary = {}
var _values: Dictionary = {}
var _defaults: Dictionary = {}
var _descriptions: Dictionary = {}
var _limits: Dictionary = {}
var _skip: Array = []
var _choices: Dictionary = {}
var _png_files: Dictionary = {}
var _skin_root := ""
var _blank_normal := StyleBoxEmpty.new()
var _blank_normal_box: StyleBoxEmpty
var _icon_hover := StyleBoxFlat.new()
var _icon_pressed := StyleBoxFlat.new()


func _ready() -> void:
	_setup_icon_button_styles()


func _setup_icon_button_styles() -> void:
	_blank_normal.set_content_margin_all(0)
	for box in [_icon_hover, _icon_pressed]:
		box.set_content_margin_all(0)
		box.set_border_width_all(0)
		box.set_expand_margin_all(0)
		box.set_corner_radius_all(3)
		box.corner_detail = 5
	_blank_normal_box = _blank_normal.duplicate()
	_blank_normal_box.content_margin_left = 3
	_icon_hover.bg_color = Color(1, 1, 1, 0.1)
	_icon_pressed.bg_color = Color(1, 1, 1, 0.16)


func _apply_icon_button_styles(button: BaseButton) -> void:
	button.add_theme_stylebox_override("normal", _blank_normal)
	button.add_theme_stylebox_override("hover", _icon_hover)
	button.add_theme_stylebox_override("pressed", _icon_pressed)
	button.add_theme_stylebox_override("hover_pressed", _icon_pressed)
	button.add_theme_stylebox_override("focus", _blank_normal)
	button.add_theme_constant_override("h_separation", 0)
	button.add_theme_constant_override("align_to_largest_stylebox", 0)


func _apply_checkbox_styles(box: CheckBox) -> void:
	box.add_theme_stylebox_override("normal", _blank_normal_box)
	box.add_theme_stylebox_override("pressed", _blank_normal_box)
	box.add_theme_stylebox_override("hover", _icon_hover)
	box.add_theme_stylebox_override("hover_pressed", _icon_hover)
	box.add_theme_stylebox_override("focus", _blank_normal_box)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(22, 22)


func bind(window_title: String, tweaks: Dictionary, schema: Dictionary) -> void:
	heading = window_title
	if hint_label:
		hint_label.text = str(schema.get("hint", hint_label.text))
	_defaults = schema.get("defaults", {})
	_descriptions = schema.get("descriptions", {})
	_limits = schema.get("limits", {})
	_skip = schema.get("skip", [])
	_choices = schema.get("choices", {})
	_png_files = schema.get("png_files", {})
	_skin_root = str(schema.get("skin_root", ""))
	_values = tweaks
	_rebuild()


func sync_value(path: PackedStringArray, value: Variant) -> void:
	var key := _path_key(path)
	if !_controls.has(key):
		return
	_updating = true
	_set_control(_controls[key], value)
	_updating = false
	_update_revert_visible(path)


func _rebuild() -> void:
	_updating = true
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	_controls.clear()
	_revert_buttons.clear()
	if _values.is_empty() || _defaults.is_empty():
		_updating = false
		_update_reset_button()
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
	_update_reset_button()


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
	var path_copy := path.duplicate()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
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
	var revert := Button.new()
	revert.icon = REVERT_ICON
	revert.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	revert.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	revert.focus_mode = Control.FOCUS_NONE
	revert.custom_minimum_size = Vector2(22, 16)
	_apply_icon_button_styles(revert)
	revert.tooltip_text = "Revert Value"
	revert.pressed.connect(func(): _revert_property(path_copy))
	row.add_child(revert)
	_revert_buttons[_path_key(path_copy)] = revert
	var control := _make_control(path_copy, value)
	if control:
		control.tooltip_text = _desc(key)
		row.add_child(control)
		_controls[_path_key(path_copy)] = control
	row.tooltip_text = _desc(key)
	list.add_child(row)
	var end_pad := Control.new()
	end_pad.custom_minimum_size = Vector2(4, 0)
	row.add_child(end_pad)
	_update_revert_visible(path_copy)


func _make_control(path: PackedStringArray, value: Variant) -> Control:
	var key := path[path.size() - 1]
	var png := _png_meta(path)
	if !png.is_empty():
		return _make_png_picker(path, str(value) if value != null else "", png)
	if _choices.has(key):
		return _make_choice(path, str(value), _choices[key])
	if value is bool:
		var box := CheckBox.new()
		box.button_pressed = value
		_apply_checkbox_styles(box)
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
		spin.allow_greater = !lim.has("max")
		spin.allow_lesser = !lim.has("min")
		_apply_spin_step(spin, lim, value)
		spin.value = float(value)
		spin.value_changed.connect(func(v: float):
			if spin.rounded:
				_emit_change(path, int(v))
			else:
				_emit_change(path, v)
		)
		return spin
	return null


func _make_png_picker(path: PackedStringArray, value: String, meta: Dictionary) -> Control:
	var picker := IMAGE_FILE_BUTTON.instantiate()
	var dest_name := str(meta.get("dest_name", ""))
	var dest_path := _skin_root.path_join(dest_name) if !_skin_root.is_empty() && !dest_name.is_empty() else ""
	picker.set_meta("dest_path", dest_path)
	var exists := !value.is_empty() && !dest_path.is_empty() && FileAccess.file_exists(dest_path)
	picker.set_display(value if exists else "", dest_path if exists else "")
	picker.file_chosen.connect(func(src: String): _emit_change(path, src))
	return picker


func _png_meta(path: PackedStringArray) -> Dictionary:
	var meta = _png_files.get(_path_key(path), {})
	return meta if meta is Dictionary else {}


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
			spin.allow_lesser = false
		if lim.has("max"):
			spin.max_value = float(lim.max)
			spin.allow_greater = false
		_apply_spin_step(spin, lim, vec.x)
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
	spin.step = 0.01
	spin.custom_arrow_step = 1.0
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.value = value
	return spin


## LIMITS "step" only affects arrow buttons. Typed values are not snapped to it.
func _apply_spin_step(spin: SpinBox, lim: Dictionary, value: Variant) -> void:
	var is_int := value is int
	var arrow := float(lim.get("step", 1.0 if is_int else 0.01))
	spin.custom_arrow_step = arrow
	if is_int && !lim.has("step"):
		spin.step = 1.0
		spin.rounded = true
		return
	spin.rounded = false
	if arrow > 0.0:
		spin.step = minf(arrow, 0.01)
	else:
		spin.step = 0.01


func _set_control(control: Control, value: Variant) -> void:
	if control.has_method("set_display"):
		var dest_path := str(control.get_meta("dest_path", ""))
		@warning_ignore("shadowed_variable_base_class")
		var name := str(value)
		var exists := !name.is_empty() && !dest_path.is_empty() && FileAccess.file_exists(dest_path)
		control.set_display(name if exists else "", dest_path if exists else "")
		return
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


func _revert_property(path: PackedStringArray) -> void:
	if _updating:
		return
	var default_value: Variant = _copy_value(SuitTweaks.get_at(_defaults, path))
	if default_value == null:
		return
	_emit_change(path, default_value)


func _update_revert_visible(path: PackedStringArray) -> void:
	var key := _path_key(path)
	if _revert_buttons.has(key):
		(_revert_buttons[key] as Button).visible = !_is_at_default(path)
	_update_reset_button()


func has_resettable_changes() -> bool:
	for key in _revert_buttons.keys():
		if _png_files.has(key):
			continue
		if !_is_at_default(PackedStringArray(str(key).split("/"))):
			return true
	return false


func _update_reset_button() -> void:
	resettable_changed.emit()


func _is_at_default(path: PackedStringArray) -> bool:
	var default_value: Variant = SuitTweaks.get_at(_defaults, path)
	if default_value == null:
		return true
	return _values_equal(SuitTweaks.get_at(_values, path), default_value)


func _copy_value(value: Variant) -> Variant:
	if value is Array:
		return value.duplicate()
	if value is Dictionary:
		return value.duplicate(true)
	return value


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
