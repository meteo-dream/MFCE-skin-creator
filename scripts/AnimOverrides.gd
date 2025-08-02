extends Node

const FILE_VERSION := "1"
const OVERRIDES_DIR := "user://slicing_overrides"
const OFFSETS_PATH := "res://engine/objects/players/prefabs/offsets_%s.txt"


func _ready() -> void:
	_initialize_overrides()
	

func _initialize_overrides() -> void:
	# Creating a folder "slicing_overrides" at user directory
	if !DirAccess.dir_exists_absolute(OVERRIDES_DIR):
		DirAccess.make_dir_absolute(OVERRIDES_DIR)
	print("File Version: %s" % FILE_VERSION)
	# Checking if there are files that could be accidentally overriden. Packing those files into an archive
	var override: bool = _overrides_check_for_version()
	
	# Creating files for the user to override when needed
	for i in AnimGenerator.TEXTURES.keys():
		# Spritesheet image
		if !FileAccess.file_exists(_get_override_path(i)) || override:
			var img: Image = AnimGenerator.TEXTURES[i].get_image()
			img.save_png(_get_override_path(i))
		
		# Slicing settings (Rect2 arrays)
		if !FileAccess.file_exists(_get_override_path(i, false)) || override:
			var file := FileAccess.open(_get_override_path(i, false), FileAccess.WRITE)
			var engine_true_suit_name = "full" if !i in ["small", "super", "frog"] else i
			var txt = FileAccess.get_file_as_string(OFFSETS_PATH % [engine_true_suit_name])
			file.store_string(txt)
			file.close()
			
			#img.save_png(_get_override_path(i))

func _overrides_check_for_version() -> bool:
	# Create a version file
	if !FileAccess.file_exists(OVERRIDES_DIR.path_join("version.txt")):
		var file = FileAccess.open(OVERRIDES_DIR.path_join("version.txt"), FileAccess.WRITE)
		file.store_string(FILE_VERSION)
		file.close()
		return false
	
	var version_str = FileAccess.get_file_as_string(OVERRIDES_DIR.path_join("version.txt")) \
		.left(4)
	# If version.txt contents are the same as FILE_VERSION, assume it's the same Skin Editor version
	if int(version_str) == int(FILE_VERSION):
		return false
	
	# Otherwise, create a backup archive of old files
	if !DirAccess.dir_exists_absolute("user://BACKUPS"):
		DirAccess.make_dir_absolute("user://BACKUPS")
	var writer = ZIPPacker.new()
	var err = writer.open("user://BACKUPS/Backup-Version_%s.zip" % [version_str])
	if err != OK:
		push_error(err)
		return true
	
	for i in DirAccess.get_files_at(OVERRIDES_DIR):
		if !i.ends_with(".tres") && !i.ends_with(".png"):
			continue
		writer.start_file(i)
		writer.write_file(FileAccess.get_file_as_bytes(OVERRIDES_DIR.path_join(i)))
		writer.close_file()

	writer.close()
	
	var _file = FileAccess.open(OVERRIDES_DIR.path_join("version.txt"), FileAccess.WRITE)
	_file.store_string(FILE_VERSION)
	_file.close()
	return true


func _get_override_path(suit: String, image: bool = true) -> String:
	return OVERRIDES_DIR.path_join(("offsets_" if !image else "") + suit + (".tres" if !image else ".png"))
