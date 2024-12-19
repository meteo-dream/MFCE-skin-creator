extends TextureRect
class_name SpriteView

var rect_draw: Rect2 = Rect2(0,0,3,3) :
	set(val):
		rect_draw = val
		queue_redraw()

func _draw() -> void:
	if !texture:
		return
	var rel_rect: Rect2 = rect_draw
	var scale_rel: Vector2 = Vector2(
		(size.x / texture.get_size().x),
		(size.y / texture.get_size().y)
		)
	
	rel_rect.position.x *= scale_rel.x
	rel_rect.position.y *= scale_rel.y
	
	rel_rect.size.x *= scale_rel.x
	rel_rect.size.y *= scale_rel.y
	
	draw_rect(rel_rect, Color.RED, false)
	
