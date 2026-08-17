extends PanelContainer
class_name FramesStrip

signal frame_selected(index: int)
signal frames_reordered(from: int, to: int)
signal add_frames_pressed
signal edit_frame_pressed
signal delete_frame_pressed

const THUMB_MIN := 32
const THUMB_MAX := 256
const DROP_LINE := Color(0.45, 0.68, 1.0, 0.95)

var thumb_size := 96

@onready var list: ItemList = %FrameList
@onready var add_button: Button = %AddFrames
@onready var edit_button: Button = %EditFrame
@onready var delete_button: Button = %DeleteFrame

var _updating := false
var _drop_index := -1


func _ready() -> void:
	mouse_force_pass_scroll_events = false
	list.mouse_force_pass_scroll_events = false
	list.item_selected.connect(_on_item_selected)
	list.item_activated.connect(_on_item_activated)
	list.draw.connect(_on_list_draw)
	list.set_drag_forwarding(_on_get_drag_data, _on_can_drop_data, _on_drop_data)
	add_button.pressed.connect(func(): add_frames_pressed.emit())
	edit_button.pressed.connect(func(): edit_frame_pressed.emit())
	delete_button.pressed.connect(func(): delete_frame_pressed.emit())


func set_enabled(enabled: bool) -> void:
	add_button.disabled = !enabled
	edit_button.disabled = !enabled
	delete_button.disabled = !enabled || list.item_count <= 1
	list.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func set_thumb_size(size: int) -> void:
	thumb_size = clampi(size, THUMB_MIN, THUMB_MAX)
	list.fixed_icon_size = Vector2i(thumb_size, thumb_size)
	list.fixed_column_width = thumb_size + 48
	list.force_update_list_size()


func rebuild(sprite_frames: SpriteFrames, anim: StringName, selected: int) -> void:
	_updating = true
	list.clear()
	if !sprite_frames || !sprite_frames.has_animation(anim):
		_updating = false
		return
	var count := sprite_frames.get_frame_count(anim)
	for i in count:
		var tex: Texture2D = sprite_frames.get_frame_texture(anim, i)
		var icon: Texture2D = tex
		if tex is AtlasTexture:
			icon = tex.duplicate()
		var duration := sprite_frames.get_frame_duration(anim, i)
		list.add_item(_item_text(i, duration), icon)
	if count > 0:
		var idx := clampi(selected, 0, count - 1)
		list.select(idx)
		list.ensure_current_is_visible()
	delete_button.disabled = count <= 1 || add_button.disabled
	_updating = false


func select_frame(index: int) -> void:
	if _updating:
		return
	if index < 0 || index >= list.item_count:
		return
	if list.is_selected(index):
		return
	_updating = true
	list.select(index)
	list.ensure_current_is_visible()
	_updating = false


func update_item_text(index: int, duration: float) -> void:
	if index < 0 || index >= list.item_count:
		return
	list.set_item_text(index, _item_text(index, duration))


func update_frame(index: int, sprite_frames: SpriteFrames, anim: StringName) -> void:
	if index < 0 || index >= list.item_count:
		return
	if !sprite_frames || !sprite_frames.has_animation(anim):
		return
	var tex: Texture2D = sprite_frames.get_frame_texture(anim, index)
	var icon: Texture2D = tex
	if tex is AtlasTexture:
		icon = tex.duplicate()
	list.set_item_icon(index, icon)
	list.set_item_text(index, _item_text(index, sprite_frames.get_frame_duration(anim, index)))


func _item_text(index: int, duration: float) -> String:
	if is_equal_approx(duration, 1.0):
		return str(index)
	return "%d [× %.2f]" % [index, duration]


func _on_item_selected(index: int) -> void:
	if _updating:
		return
	frame_selected.emit(index)


func _on_item_activated(_index: int) -> void:
	edit_frame_pressed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_drop_index(-1)


func _on_get_drag_data(at_position: Vector2) -> Variant:
	if add_button.disabled || list.item_count <= 1:
		return null
	var idx := list.get_item_at_position(at_position, true)
	if idx < 0:
		return null
	var preview := TextureRect.new()
	preview.texture = list.get_item_icon(idx)
	preview.custom_minimum_size = Vector2(thumb_size, thumb_size)
	preview.size = Vector2(thumb_size, thumb_size)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.modulate = Color(1, 1, 1, 0.85)
	list.set_drag_preview(preview)
	return { "type": "frames_strip_frame", "index": idx }


func _on_can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if !_is_frame_drag(data):
		_set_drop_index(-1)
		return false
	_set_drop_index(_get_insert_index(at_position))
	return true


func _on_drop_data(at_position: Vector2, data: Variant) -> void:
	if !_is_frame_drag(data):
		_set_drop_index(-1)
		return
	var from: int = data["index"]
	var to := _get_insert_index(at_position)
	_set_drop_index(-1)
	if from < 0 || from >= list.item_count:
		return
	if to == from || to == from + 1:
		return
	frames_reordered.emit(from, to)


func _is_frame_drag(data: Variant) -> bool:
	return data is Dictionary && data.get("type") == "frames_strip_frame"


func _get_insert_index(at_position: Vector2) -> int:
	if list.item_count <= 0:
		return 0
	var idx := list.get_item_at_position(at_position, true)
	if idx < 0:
		idx = list.get_item_at_position(at_position, false)
		if idx < 0:
			return list.item_count
	var rect := list.get_item_rect(idx, false)
	var pos := at_position + Vector2(list.get_h_scroll_bar().value, list.get_v_scroll_bar().value)
	if pos.x >= rect.position.x + rect.size.x * 0.5:
		return idx + 1
	return idx


func _set_drop_index(index: int) -> void:
	if _drop_index == index:
		return
	_drop_index = index
	list.queue_redraw()


func _on_list_draw() -> void:
	if _drop_index < 0 || list.item_count <= 0:
		return
	var scroll := Vector2(list.get_h_scroll_bar().value, list.get_v_scroll_bar().value)
	var x: float
	var top: float
	var bottom: float
	if _drop_index >= list.item_count:
		var rect := list.get_item_rect(list.item_count - 1, false)
		rect.position -= scroll
		x = rect.position.x + rect.size.x
		top = rect.position.y
		bottom = rect.position.y + rect.size.y
	else:
		var rect := list.get_item_rect(_drop_index, false)
		rect.position -= scroll
		x = rect.position.x
		top = rect.position.y
		bottom = rect.position.y + rect.size.y
	list.draw_line(Vector2(x, top + 2.0), Vector2(x, bottom - 2.0), DROP_LINE, 3.0)
