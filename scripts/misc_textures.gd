extends RefCounted
class_name MiscTextures

## Skin-root PNGs loaded by MFCE SkinsManager._load_misc_files into misc_textures.

const FILES := {
	"selector": { "dest_name": "selector.png" },
	"death": { "dest_name": "death.png" },
	"checkpoint_max": { "dest_name": "checkpoint_max.png" },
	"map_icon": { "dest_name": "map_icon.png" },
}

const DESCRIPTIONS := {
	"selector": "Menu player-head selector. Copied to the skin root as selector.png.",
	"death": "Shown when the player dies. Copied to the skin root as death.png.",
	"checkpoint_max": "Max-checkpoint texture. Copied to the skin root as checkpoint_max.png.",
	"map_icon": "World map icon. Copied to the skin root as map_icon.png.",
}


static func defaults() -> Dictionary:
	var out := {}
	for key in FILES:
		out[key] = ""
	return out


static func inject(skin_root: String) -> Dictionary:
	var out := defaults()
	if skin_root.is_empty():
		return out
	for key in FILES:
		var dest_name := str(FILES[key].get("dest_name", ""))
		if !dest_name.is_empty() && FileAccess.file_exists(skin_root.path_join(dest_name)):
			out[key] = dest_name
	return out


static func file_for(path: PackedStringArray) -> Dictionary:
	var meta = FILES.get("/".join(path), {})
	return meta if meta is Dictionary else {}


static func editor_schema() -> Dictionary:
	return {
		"defaults": defaults(),
		"descriptions": DESCRIPTIONS,
		"png_files": FILES,
		"reset_includes_files": true,
		"hint": "PNG files in the skin root. The game loads these as misc textures. Leave empty to use the character defaults.",
	}
