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
	var img: Image = Image.load_from_file(AnimOverrides.OVERRIDES_DIR.path_join(suit + ".png"))
	if !img:
		printerr("Error loading overriden image. Using defaults.")
		img = TEXTURES[suit].get_image()
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


static func get_offset_dict(suit: String, ignore_overrides: bool = false) -> Dictionary:
	if !ignore_overrides && FileAccess.file_exists(AnimOverrides._get_override_path(suit, false)):
		var new_offsets := load_offsets_from_file(AnimOverrides._get_override_path(suit, false))
		if !new_offsets.is_empty() && new_offsets.get("offsets"):
			return new_offsets.offsets
		else:
			printerr("The override offsets_%s.tres is invalid!" % suit)
	
	if suit in ["small", "super", "frog"]:
		return load_offsets_from_file(AnimOverrides.OFFSETS_PATH % suit)
	return load_offsets_from_file(AnimOverrides.OFFSETS_PATH % "full")


static func load_offsets_from_file(path: String) -> Dictionary:
	var output := {}
	var file = FileAccess.open(path, FileAccess.READ)
	if !file: return {}
	
	var reading_buffer: String
	var dict_index_buffer: Dictionary = {}
	const OFFSETS_STR = "offsets"
	
	while !file.eof_reached():
		var line = file.get_line()
		if reading_buffer.is_empty():
			if line.begins_with(OFFSETS_STR) && !OFFSETS_STR in dict_index_buffer:
				reading_buffer = OFFSETS_STR
				dict_index_buffer[reading_buffer] = []
		if reading_buffer.is_empty():
			continue
		var starting_pos: int
		if len(dict_index_buffer[reading_buffer]) == 0:
			var ind_start = line.find("{")
			if ind_start >= 0:
				dict_index_buffer[reading_buffer].append(file.get_position() - len(line) + ind_start - 1)
				starting_pos = ind_start
		if len(dict_index_buffer[reading_buffer]) == 1:
			var ind_start = line.find("}", starting_pos)
			if ind_start >= 0:
				dict_index_buffer[reading_buffer].append(file.get_position() - len(line) + ind_start - 1)
				reading_buffer = ""
				continue
	
	for i in dict_index_buffer:
		file.seek(dict_index_buffer[i][0])
		
		var dict_str: String = file.get_buffer(dict_index_buffer[i][1] - dict_index_buffer[i][0]).get_string_from_utf8()
		if !dict_str: continue
		
		dict_str += "}"
		var clean_dict: String = dict_str
		for bad_string in Main.BAD_NAMES:
			clean_dict = clean_dict.replacen(bad_string, "")
		
		var _i: int = 0
		while _i < len(clean_dict):
			if clean_dict.substr(_i, 5) != "Rect2":
				_i += 1
				continue
			var _opening := clean_dict.find("(", _i + 1)
			var subst := clean_dict.substr(_opening + 1, clean_dict.find(")", _i + 1) - _opening - 1)
			var parsed_rect_str := ",".join(Array(subst.split(",")).map(
				func(elem: String):
					var expression := Expression.new()
					expression.parse(elem)
					if expression.has_execute_failed():
						return elem
					return expression.execute()
			))
			#print(parsed_rect_str)
			clean_dict = Util.replace_first(clean_dict, subst, parsed_rect_str)
			
			_i += 1
			
		var parsed = str_to_var(clean_dict)
		#print(parsed)
		if parsed && parsed is Dictionary:
			output[i] = parsed
	
	return output
	
