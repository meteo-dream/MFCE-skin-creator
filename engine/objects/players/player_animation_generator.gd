extends Node
class_name AnimGenerator

const TEXTURES: Dictionary = {
	"small": preload("res://engine/objects/players/mario_small.png"),
	"super": preload("res://engine/objects/players/mario_super.png"),
	"fireball": preload("res://engine/objects/players/mario_fireball.png"),
	"beetroot": preload("res://engine/objects/players/mario_beetroot.png"),
	"green_lui": preload("res://engine/objects/players/mario_green_lui.png"),
	"boomerang": preload("res://engine/objects/players/mario_boomerang.png"),
	"iceball": preload("res://engine/objects/players/mario_iceball.png"),
	"frog": preload("res://engine/objects/players/mario_frog.png"),
}
const SETTINGS: Dictionary = {
	"small": ("res://engine/objects/players/prefabs/suit_small.txt"),
	"super": ("res://engine/objects/players/prefabs/suit_super.txt"),
	"fireball": ("res://engine/objects/players/prefabs/suit_fireball.txt"),
	"beetroot": ("res://engine/objects/players/prefabs/suit_beetroot.txt"),
	"green_lui": ("res://engine/objects/players/prefabs/suit_green_lui.txt"),
	"boomerang": ("res://engine/objects/players/prefabs/suit_boomerang.txt"),
	"iceball": ("res://engine/objects/players/prefabs/suit_iceball.txt"),
	"frog": ("res://engine/objects/players/prefabs/suit_frog.txt"),
}
const OFFSETS_SMALL: Dictionary = {
	"appear": [Rect2(32*3, 0, 32, 64), Rect2(32*4, 0, 32, 64), Rect2(32*0, 0, 32, 64)],
	"attack": [Rect2(32*5, 0, 32, 64)],
	"attack_air": [Rect2(32*8, 0, 32, 64), Rect2(32*9, 0, 32, 64), Rect2(32*10, 0, 32, 64)],
	"back": [Rect2(32*16, 0, 32, 64)],
	"climb": [Rect2(32*12, 0, 32, 64)],
	"crouch": [Rect2(32*7, 0, 32, 64)],
	"default": [Rect2(32*0, 0, 32, 64)],
	"fall": [Rect2(32*6, 0, 32, 64)],
	"grab": [Rect2(32*3, 64, 32, 64), Rect2(32*4, 64, 32, 64)],
	"hold_crouch": [Rect2(32*7, 64, 32, 64)],
	"hold_default": [Rect2(32*0, 64, 32, 64)],
	"hold_fall": [Rect2(32*1, 64, 32, 64)],
	"hold_jump": [Rect2(32*1, 64, 32, 64)],
	"hold_look_up": [Rect2(32*0, 64, 32, 64)],
	"hold_swim": [Rect2(32*8, 0, 32, 64), Rect2(32*11, 0, 32, 64)],
	"hold_walk": [Rect2(32*1, 64, 32, 64), Rect2(32*2, 64, 32, 64), Rect2(32*0, 64, 32, 64)],
	"idle": [Rect2(32*0, 0, 32, 64)],
	"jump": [Rect2(32*6, 0, 32, 64)],
	"kick": [Rect2(32*5, 64, 32, 64)],
	"look_up": [Rect2(32*0, 0, 32, 64)],
	"p_run": [Rect2(32*1, 0, 32, 64), Rect2(32*2, 0, 32, 64), Rect2(32*0, 0, 32, 64)],
	"p_fall": [Rect2(32*6, 0, 32, 64)],
	"p_jump": [Rect2(32*6, 0, 32, 64)],
	"skid": [Rect2(32*15, 0, 32, 64)],
	"slide": [Rect2(32*13, 0, 32, 64)],
	"swim": [Rect2(32*8, 0, 32, 64), Rect2(32*9, 0, 32, 64), Rect2(32*10, 0, 32, 64), Rect2(32*11, 0, 32, 64)],
	"walk": [Rect2(32*1, 0, 32, 64), Rect2(32*2, 0, 32, 64), Rect2(32*0, 0, 32, 64)],
	"warp": [Rect2(32*14, 0, 32, 64)],
	"win": [Rect2(32*16, 64, 32, 64)],
}
const OFFSETS_SUPER: Dictionary = {
	"appear": [Rect2(48*3, 0, 48, 64), Rect2(48*4, 0, 48, 64), Rect2(48*2, 0, 48, 64)],
	"attack": [Rect2(48*5, 0, 48, 64)],
	"attack_air": [Rect2(48*8, 0, 48, 64), Rect2(48*9, 0, 48, 64), Rect2(48*10, 0, 48, 64)],
	"back": [Rect2(48*16, 0, 48, 64)],
	"climb": [Rect2(48*12, 0, 48, 64)],
	"crouch": [Rect2(48*7, 0, 48, 64)],
	"default": [Rect2(48*0, 0, 48, 64)],
	"fall": [Rect2(48*6, 0, 48, 64)],
	"grab": [Rect2(48*3, 64, 48, 64), Rect2(48*4, 64, 48, 64)],
	"hold_crouch": [Rect2(48*7, 64, 48, 64)],
	"hold_default": [Rect2(48*0, 64, 48, 64)],
	"hold_fall": [Rect2(48*1, 64, 48, 64)],
	"hold_jump": [Rect2(48*1, 64, 48, 64)],
	"hold_look_up": [Rect2(48*0, 64, 48, 64)],
	"hold_swim": [Rect2(48*8, 0, 48, 64), Rect2(48*11, 0, 48, 64)],
	"hold_walk": [Rect2(48*1, 64, 48, 64), Rect2(48*2, 64, 48, 64), Rect2(48*0, 64, 48, 64)],
	"idle": [Rect2(48*0, 0, 48, 64)],
	"jump": [Rect2(48*6, 0, 48, 64)],
	"kick": [Rect2(48*5, 64, 48, 64)],
	"look_up": [Rect2(48*0, 0, 48, 64)],
	"p_run": [Rect2(48*1, 0, 48, 64), Rect2(48*2, 0, 48, 64), Rect2(48*0, 0, 48, 64)],
	"p_fall": [Rect2(48*6, 0, 48, 64)],
	"p_jump": [Rect2(48*6, 0, 48, 64)],
	"skid": [Rect2(48*15, 0, 48, 64)],
	"slide": [Rect2(48*13, 0, 48, 64)],
	"swim": [Rect2(48*8, 0, 48, 64), Rect2(48*9, 0, 48, 64), Rect2(48*10, 0, 48, 64), Rect2(48*11, 0, 48, 64)],
	"walk": [Rect2(48*1, 0, 48, 64), Rect2(48*2, 0, 48, 64), Rect2(48*0, 0, 48, 64)],
	"warp": [Rect2(48*14, 0, 48, 64)],
	"win": [Rect2(48*16, 64, 48, 64)],
}
const OFFSETS_FULL: Dictionary = {
	"appear": [Rect2(48*3, 0, 48, 64), Rect2(48*2, 0, 48, 64)],
	"attack": [Rect2(48*4, 0, 48, 64)],
	"attack_air": [Rect2(48*7, 0, 48, 64), Rect2(48*8, 0, 48, 64), Rect2(48*9, 0, 48, 64)],
	"back": [Rect2(48*15, 0, 48, 64)],
	"climb": [Rect2(48*11, 0, 48, 64)],
	"crouch": [Rect2(48*6, 0, 48, 64)],
	"default": [Rect2(48*0, 0, 48, 64)],
	"fall": [Rect2(48*5, 0, 48, 64)],
	"grab": [Rect2(48*3, 64, 48, 64), Rect2(48*4, 64, 48, 64)],
	"hold_crouch": [Rect2(48*6, 64, 48, 64)],
	"hold_default": [Rect2(48*0, 64, 48, 64)],
	"hold_fall": [Rect2(48*1, 64, 48, 64)],
	"hold_jump": [Rect2(48*1, 64, 48, 64)],
	"hold_look_up": [Rect2(48*0, 64, 48, 64)],
	"hold_swim": [Rect2(48*7, 0, 48, 64), Rect2(48*10, 0, 48, 64)],
	"hold_walk": [Rect2(48*1, 64, 48, 64), Rect2(48*2, 64, 48, 64), Rect2(48*0, 64, 48, 64)],
	"idle": [Rect2(48*0, 0, 48, 64)],
	"jump": [Rect2(48*5, 0, 48, 64)],
	"kick": [Rect2(48*5, 64, 48, 64)],
	"look_up": [Rect2(48*0, 0, 48, 64)],
	"p_run": [Rect2(48*1, 0, 48, 64), Rect2(48*2, 0, 48, 64), Rect2(48*0, 0, 48, 64)],
	"p_fall": [Rect2(48*5, 0, 48, 64)],
	"p_jump": [Rect2(48*5, 0, 48, 64)],
	"skid": [Rect2(48*14, 0, 48, 64)],
	"slide": [Rect2(48*12, 0, 48, 64)],
	"swim": [Rect2(48*7, 0, 48, 64), Rect2(48*8, 0, 48, 64), Rect2(48*9, 0, 48, 64), Rect2(48*10, 0, 48, 64)],
	"walk": [Rect2(48*1, 0, 48, 64), Rect2(48*2, 0, 48, 64), Rect2(48*0, 0, 48, 64)],
	"warp": [Rect2(48*13, 0, 48, 64)],
	"win": [Rect2(48*15, 64, 48, 64)],
}
const OFFSETS_FROG: Dictionary = {
	"appear": [Rect2(48*3, 0, 48, 72), Rect2(48*4, 0, 48, 72), Rect2(48*5, 0, 48, 72), Rect2(48*6, 0, 48, 72), Rect2(48*6, 72, 48, 72)],
	"attack": [Rect2(48*2, 0, 48, 72)],
	"attack_air": [Rect2(48*7, 0, 48, 72), Rect2(48*8, 0, 48, 72), Rect2(48*9, 0, 48, 72)],
	"back": [Rect2(48*15, 0, 48, 72)],
	"climb": [Rect2(48*11, 0, 48, 72)],
	"crouch": [Rect2(48*0, 0, 48, 72)],
	"default": [Rect2(48*0, 0, 48, 72)],
	"fall": [Rect2(48*2, 0, 48, 72)],
	"grab": [Rect2(48*3, 72, 48, 72), Rect2(48*4, 72, 48, 72)],
	"hold_crouch": [Rect2(48*0, 72, 48, 72)],
	"hold_default": [Rect2(48*0, 72, 48, 72)],
	"hold_fall": [Rect2(48*1, 72, 48, 72)],
	"hold_jump": [Rect2(48*1, 72, 48, 72)],
	"hold_look_up": [Rect2(48*0, 72, 48, 72)],
	"hold_swim": [Rect2(48*1, 72, 48, 72)],
	"hold_walk": [Rect2(48*1, 72, 48, 72), Rect2(48*2, 72, 48, 72), Rect2(48*0, 72, 48, 72)],
	"idle": [Rect2(48*0, 0, 48, 72)],
	"jump": [Rect2(48*2, 0, 48, 72)],
	"kick": [Rect2(48*5, 72, 48, 72)],
	"look_up": [Rect2(48*0, 0, 48, 72)],
	"p_run": [Rect2(48*0, 0, 48, 72), Rect2(48*1, 0, 48, 72), Rect2(48*2, 0, 48, 72)],
	"p_fall": [Rect2(48*2, 0, 48, 72)],
	"p_jump": [Rect2(48*2, 0, 48, 72)],
	"skid": [Rect2(48*0, 0, 48, 72)],
	"slide": [Rect2(48*12, 0, 48, 72)],
	"swim": [Rect2(48*7, 0, 48, 72), Rect2(48*8, 0, 48, 72), Rect2(48*9, 0, 48, 72)],
	"walk": [Rect2(48*0, 0, 48, 72), Rect2(48*1, 0, 48, 72), Rect2(48*2, 0, 48, 72)],
	"warp": [Rect2(48*13, 0, 48, 72)],
	"win": [Rect2(48*15, 72, 48, 72)],
	"swim_down": [Rect2(48*9, 72, 48, 72), Rect2(48*10, 72, 48, 72), Rect2(48*11, 72, 48, 72)],
	"swim_up": [Rect2(48*12, 72, 48, 72), Rect2(48*13, 72, 48, 72), Rect2(48*14, 72, 48, 72)],
	"swim_idle": [Rect2(48*7, 72, 48, 72), Rect2(48*8, 72, 48, 72)],
}

func _ready() -> void:
	pass

static func copy_settings(suit: String, path: String) -> String:
	if !suit in SETTINGS:
		return "Unrecognized suit"
	var new_path: String = path.path_join(suit)
	if !DirAccess.dir_exists_absolute(new_path):
		var er: Error = DirAccess.make_dir_absolute(new_path)
		if er: return "Error creating a directory: %s" % error_string(er)
	var file := FileAccess.open(new_path.path_join("skin_settings.tres"), FileAccess.WRITE)
	if !file:
		return "Error opening a file: %s" % error_string(FileAccess.get_open_error())
	var txt = FileAccess.get_file_as_string(SETTINGS[suit])
	file.store_string(txt)
	return "Success"

static func gen_image_files(suit: String, path: String) -> String:
	if !suit in TEXTURES:
		return "Error: " + error_string(ERR_INVALID_PARAMETER)
	var img: Image = TEXTURES[suit].get_image()
	var _offsets: Dictionary = get_offset_dict(suit)
	var created_count: int = 0
	for i: String in _offsets.keys():
		var _suit_folder := path.path_join(suit)
		if !DirAccess.dir_exists_absolute(_suit_folder):
			DirAccess.make_dir_absolute(_suit_folder)
		var _path := _suit_folder.path_join(i + ".png")
		if FileAccess.file_exists(_path):
			print("File exists: " + _path)
		else:
			var out := gen_animation_image(i, _offsets, img)
			var err: Error = out.save_png(_path)
			if err: return "Error saving to %s: %s" % [_path, error_string(err)]
			created_count += 1
	
	if created_count > 0:
		return "Successfully created %d images for %s suit" % [created_count, suit]
	return "No images have been created"

static func gen_animation_image(anim_name: String, _offsets: Dictionary, sprite_sheet: Image) -> Image:
	var offset: Array = _offsets[anim_name]
	var merged_rect := Rect2(Vector2i.ZERO, Vector2i(0, offset[0].size.y))
	for rect: Rect2 in offset:
		merged_rect = merged_rect.grow_side(SIDE_RIGHT, rect.size.x)
		#print(merged_rect)
	var out := Image.create_empty(int(merged_rect.size.x), int(merged_rect.size.y), false, Image.FORMAT_RGBA8)
	var next_pos := merged_rect.position
	for rect: Rect2 in offset:
		var cut := sprite_sheet.get_region(rect)
		#print(rect)
		out.blit_rect(cut, Rect2i(Vector2i.ZERO, rect.size), next_pos)
		next_pos.x += offset[0].size.x
	return out

static func get_offset_dict(suit: String) -> Dictionary:
	match suit:
		"small": return OFFSETS_SMALL
		"super": return OFFSETS_SUPER
		"frog":  return OFFSETS_FROG
	return OFFSETS_FULL
