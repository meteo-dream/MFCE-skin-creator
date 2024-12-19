extends Resource
class_name PlayerSkin

const ANIMS: Array[String] = [
	"appear",
	"attack",
	"attack_air",
	"back",
	"climb",
	"crouch",
	"default",
	"fall",
	"grab",
	"hold_crouch",
	"hold_default",
	"hold_fall",
	"hold_jump",
	"hold_walk",
	"kick",
	"jump",
	"skid",
	"slide",
	"swim",
	"walk",
	"warp",
	"win", ]

const STATES: Array[String] = [
	"small",
	"super",
	"iceball",
	"green_lui",
	"fireball",
	"boomerang",
	"beetroot"
]

const RECT_ZERO: Rect2 = Rect2(0,0,0,0)

@export var name: StringName = &"small" # State name
@export var animation_speeds: Dictionary = {
	"appear": 30,
	"attack": 10,
	"attack_air": 15,
	"back": 0,
	"climb": 0,
	"crouch": 0,
	"default": 0,
	"fall": 0,
	"grab": 5,
	"hold_crouch": 0,
	"hold_default": 0,
	"hold_fall": 0,
	"hold_jump": 0,
	"hold_walk": 6,
	"jump": 0,
	"kick": 4,
	"skid": 0,
	"slide": 0,
	"swim": 8,
	"walk": 6,
	"warp": 0,
	"win": 0,
}
@export var animation_regions: Dictionary = {
	"appear": [
		Rect2(0, 0, 32, 64),
		Rect2(32, 0, 32, 64),
		Rect2(64, 0, 32, 64),
	],
	"attack": [
		Rect2(0, 0, 32, 64),
	],
	"attack_air": [
		Rect2(0, 0, 32, 64),
		Rect2(32, 0, 32, 64),
		Rect2(64, 0, 32, 64),
	],
	"back": [
		Rect2(0, 0, 32, 64),
	],
	"climb": [
		Rect2(0, 0, 32, 64),
	],
	"crouch": [
		Rect2(0, 0, 32, 64),
	],
	"default": [
		Rect2(0, 0, 32, 64),
	],
	"fall": [
		Rect2(0, 0, 32, 64),
	],
	"grab": [
		Rect2(0, 0, 32, 64),
		Rect2(32, 0, 32, 64),
	],
	"hold_crouch": [
		Rect2(0, 0, 32, 64),
	],
	"hold_default": [
		Rect2(0, 0, 32, 64),
	],
	"hold_fall": [
		Rect2(0, 0, 32, 64),
	],
	"hold_jump": [
		Rect2(0, 0, 32, 64),
	],
	"hold_walk": [
		Rect2(0, 0, 32, 64),
		Rect2(32, 0, 32, 64),
		Rect2(64, 0, 32, 64),
	],
	"jump": [
		Rect2(0, 0, 32, 64),
	],
	"kick": [
		Rect2(0, 0, 32, 64),
	],
	"skid": [
		Rect2(0, 0, 32, 64),
	],
	"slide": [
		Rect2(0, 0, 32, 64),
	],
	"swim": [
		Rect2(0, 0, 32, 64),
		Rect2(32, 0, 32, 64),
		Rect2(64, 0, 32, 64),
		Rect2(0, 0, 32, 64),
		Rect2(32, 0, 32, 64),
		Rect2(64, 0, 32, 64),
		Rect2(96, 0, 32, 64),
		Rect2(128, 0, 32, 64),
	],
	"walk": [
		Rect2(0, 0, 32, 64),
		Rect2(32, 0, 32, 64),
		Rect2(64, 0, 32, 64),
	],
	"warp": [
		Rect2(0, 0, 32, 64),
	],
	"win": [
		Rect2(0, 0, 32, 64),
	],
}
@export var animation_loops: Dictionary = {
	"appear": true,
	"attack": false,
	"attack_air": false,
	"back": false,
	"climb": false,
	"crouch": false,
	
	"default": false,
	"fall": false,
	"grab": false,
	"hold_crouch": false,
	"hold_default": false,
	
	"hold_fall": false,
	"hold_jump": false,
	"hold_walk": true,
	"jump": false,
	"kick": false,
	
	"skid": false,
	"slide": false,
	"swim": true,
	"walk": true,
	"warp": true,
	"win": true,
}

var baked_frames: SpriteFrames

func gen_animated_sprites(force_regen: bool = false) -> SpriteFrames:
	if baked_frames:
		if force_regen:
			baked_frames.free()
		else:
			return baked_frames
	
	var frames := SpriteFrames.new()
	var res_path := resource_path.get_base_dir()
	
	for anim in ANIMS:
		if !frames.has_animation(anim):
			frames.add_animation(anim)
		
		frames.set_animation_loop(anim, animation_loops[anim])
		frames.set_animation_speed(anim, animation_speeds[anim])
		
		var img_file := res_path + "/" + anim + ".png"
		if !FileAccess.file_exists(img_file):
			print("No image for: ", anim)
			frames.remove_animation(anim)
			continue
		
		var image: Image = Image.load_from_file(img_file)
		var img_texture := ImageTexture.create_from_image(image)
		
		for anim_reg in animation_regions[anim]:
			
			if anim_reg == RECT_ZERO:
				print("Rect is zero for: ", anim)
			
			var atlas := AtlasTexture.new()
			atlas.atlas = img_texture
			atlas.region = anim_reg
			
			frames.add_frame(anim, atlas)
	
	baked_frames = frames
	return frames

signal rebuild_done
signal rebuild_all_done

## Rebuild animation
func rebuild_animation(animation: String) -> void:
	if !baked_frames:
		push_error("Animation frames is null call gen_animated_sprites()!")
		return
	if animation.is_empty():
		push_error("Animation is variable is empty!")
		print_stack()
		return
	
	var res_path := resource_path.get_base_dir()
	var img_file := res_path + "/" + animation + ".png"
	
	if FileAccess.file_exists(img_file):
		if baked_frames.has_animation(animation): # Delets all animation frames 
			baked_frames.remove_animation(animation)
		
		baked_frames.add_animation(animation)
		baked_frames.set_animation_speed(animation, animation_speeds[animation])
		
		var image := Image.load_from_file(img_file)
		var img_texture := ImageTexture.create_from_image(image)
		
		var atlas := AtlasTexture.new()
		
		for reg in animation_regions[animation]:
			if reg == RECT_ZERO:
				print("Rect is zero for: ", animation)
			atlas.atlas = img_texture
		
	else:
		if baked_frames.has_animation(animation): 
			baked_frames.remove_animation(animation)
	
	rebuild_done.emit()

## Rebuilds all animations
func rebuild_all_animations() -> void:
	for animation in ANIMS:
		rebuild_animation(animation)
	
	rebuild_all_done.emit()
