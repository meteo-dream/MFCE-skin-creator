extends TextureRect
class_name SpriteView

#var is_huge: bool

var rect_draw: Rect2 = Rect2(0,0,3,3) :
	set(val):
		rect_draw = val
		queue_redraw()

#func _process(delta: float) -> void:
	# TODO: Fix rel_rect displaying incorrectly with EXPAND_FIT_HEIGHT
	#if !texture: return
	#is_huge = (
		#64 + %FrameVSplitter/Top.size.y + (size.x / texture.get_size().x) * texture.get_size().y >
		#get_tree().root.size.y
	#)
	#
	#if is_huge:
		#expand_mode = ExpandMode.EXPAND_FIT_HEIGHT
	#else:
		#expand_mode = ExpandMode.EXPAND_FIT_HEIGHT_PROPORTIONAL


func _draw() -> void:
	if !texture:
		return
	if texture.get_size().x == 0 || texture.get_size().y == 0: return
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
	
