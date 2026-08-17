extends Node2D

@onready var scene = get_tree().current_scene
@onready var preview: AnimatedSprite2D = %Preview
@onready var state_select: OptionButton = %StateSelect
@export var rects: Dictionary = {
	"small": Rect2(-10, -28, 20, 28),
	"super": Rect2(-10, -52, 20, 52),
	"frog": Rect2(-10, -46, 20, 46),
}
var which_rect: String = "small"

func _draw() -> void:
	if !scene: return
	if !scene.show_collisions: return
	if !which_rect in rects: return
	draw_rect(rects[which_rect], Color("#0099b36b"))
	draw_rect(rects[which_rect], Color("#0099b3"), false)

func _ready() -> void:
	preview.animation_changed.connect(update_rect)
	preview.sprite_frames_changed.connect(update_rect)

func update_rect() -> void:
	if !scene.show_collisions: return
	if preview.animation in ["crouch", "hold_crouch"]:
		which_rect = "small"
		queue_redraw()
		return
	var state: String = state_select.get_item_text(state_select.get_selected_id())
	if state == "small":
		which_rect = "small"
	elif state == "frog":
		which_rect = "frog"
	else:
		which_rect = "super"
	queue_redraw()
