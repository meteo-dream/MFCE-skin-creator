extends RefCounted
class_name SuitSounds

## Per-suit OGGs loaded by MFCE SkinsManager from {suit}/sounds/.
## Keys match CharacterManager.DEFAULT_SUIT_SOUNDS.

const FILES := {
	"jump": { "dest_name": "jump.ogg", "kind": "ogg" },
	"swim": { "dest_name": "swim.ogg", "kind": "ogg" },
	"hurt": { "dest_name": "hurt.ogg", "kind": "ogg" },
	"powerup": { "dest_name": "powerup.ogg", "kind": "ogg" },
	"powerup_no_transform": { "dest_name": "powerup_no_transform.ogg", "kind": "ogg" },
	"pipe_in": { "dest_name": "pipe_in.ogg", "kind": "ogg" },
	"pipe_out": { "dest_name": "pipe_out.ogg", "kind": "ogg" },
	"look_up": { "dest_name": "look_up.ogg", "kind": "ogg" },
	"attack": { "dest_name": "attack.ogg", "kind": "ogg" },
	"skid": { "dest_name": "skid.ogg", "kind": "ogg" },
	"grab": { "dest_name": "grab.ogg", "kind": "ogg" },
	"kick": { "dest_name": "kick.ogg", "kind": "ogg" },
	"ice_slide": { "dest_name": "ice_slide.ogg", "kind": "ogg" },
	"jump_small": { "dest_name": "jump_small.ogg", "kind": "ogg" },
}

const DESCRIPTIONS := {
	"jump": "Played when jumping.",
	"swim": "Played when swimming.",
	"hurt": "Played when taking damage.",
	"powerup": "Played when powering up.",
	"powerup_no_transform": "Played when collecting a power-up that does not change suit.",
	"pipe_in": "Played when entering a pipe.",
	"pipe_out": "Played when exiting a pipe.",
	"look_up": "Played when looking up, if that animation is enabled.",
	"attack": "Played when launching a projectile.",
	"skid": "Played when skidding, if enabled in aesthetics tweaks in-game.",
	"grab": "Played when grabbing something.",
	"kick": "Played when throwing an object while holding it.",
	"ice_slide": "Played when ice-sliding.",
	"jump_small": "Played when hop-walking as frog.",
}

const FOLDER := "sounds"
const ATTACK_SUITS := ["fireball", "iceball", "beetroot", "boomerang"]
const MAX_VARIATIONS := 11
const NUMBERED_VARIATIONS := 10


static func defaults() -> Dictionary:
	var out := {}
	for key in FILES:
		out[key] = PackedStringArray()
	return out


static func variation_dest_names(key: String) -> PackedStringArray:
	var names := PackedStringArray()
	names.append("%s.ogg" % key)
	for i in NUMBERED_VARIATIONS:
		names.append("%s_%d.ogg" % [key, i])
	return names


static func dest_names_for_count(key: String, count: int) -> PackedStringArray:
	count = clampi(count, 0, MAX_VARIATIONS)
	if count <= 0:
		return PackedStringArray()
	if count == 1:
		return PackedStringArray(["%s.ogg" % key])
	var names := PackedStringArray()
	for i in count:
		names.append("%s_%d.ogg" % [key, i])
	return names


static func empty_slots(dir: String, key: String) -> PackedStringArray:
	var names := PackedStringArray()
	if key.is_empty():
		return names
	for dest_name in variation_dest_names(key):
		if dir.is_empty() || !FileAccess.file_exists(dir.path_join(dest_name)):
			names.append(dest_name)
	return names


static func list_existing(dir: String, key: String) -> PackedStringArray:
	var names := PackedStringArray()
	if dir.is_empty() || key.is_empty():
		return names
	for dest_name in variation_dest_names(key):
		if FileAccess.file_exists(dir.path_join(dest_name)):
			names.append(dest_name)
		if names.size() >= MAX_VARIATIONS:
			break
	return names


static func sounds_dir(skin_root: String, suit: String) -> String:
	if skin_root.is_empty() || suit.is_empty():
		return ""
	return skin_root.path_join(suit).path_join(FOLDER)


static func dest_path(skin_root: String, suit: String, dest_name: String) -> String:
	var dir := sounds_dir(skin_root, suit)
	if dir.is_empty() || dest_name.is_empty():
		return ""
	return dir.path_join(dest_name)


static func inject(skin_root: String, suit: String) -> Dictionary:
	var out := defaults()
	var dir := sounds_dir(skin_root, suit)
	if dir.is_empty():
		return out
	for key in FILES:
		out[key] = list_existing(dir, key)
	return out


static func file_for(path: PackedStringArray) -> Dictionary:
	var meta = FILES.get("/".join(path), {})
	return meta if meta is Dictionary else {}


static func skip_for_suit(suit: String) -> Array:
	var skip: Array = []
	if suit not in ATTACK_SUITS:
		skip.append("attack")
	if suit == "frog":
		skip.append("skid")
	else:
		skip.append("jump_small")
	return skip


static func files_for_suit(suit: String) -> Dictionary:
	var skip := skip_for_suit(suit)
	var out := {}
	for key in FILES:
		if key in skip:
			continue
		out[key] = FILES[key]
	return out


static func editor_schema(suit: String = "") -> Dictionary:
	return {
		"defaults": defaults(),
		"descriptions": DESCRIPTIONS,
		"file_pickers": FILES,
		"skip": skip_for_suit(suit),
		"reset_includes_files": true,
		"expand_file_pickers": true,
		"hint": "OGG files in this suit's sounds folder. Each sound can have up to 11 variations (name.ogg, or name_0.ogg through name_9.ogg). Click the arrow to list them. Leave empty to use the game's default suit sounds.",
	}
