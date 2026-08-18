extends RefCounted
class_name SuitTweaks

## Defaults and merge rules match MFCE CharacterManager / SkinsManager.

const SKIP_IN_EDITOR := ["loop_frame_offsets"]

const DEFAULTS := {
	"look_up_animation": false,
	"attack_air_animation": false,
	"separate_run_animation": false,
	"idle_animation": false,
	"idle_activate_after_sec": 10.0,
	"kick_ground_animation": false,
	"warp_animation": true,
	"skid_sound_loop_delay": 0.1,
	"head_bump_sound": false,
	"fall_animation": true,
	"separate_swim_idle_animation": false,
	"frog_restart_swim_on_direction_change": false,
	"emit_particles": {
		"enabled": false,
		"color": "#ffffffff",
		"show_behind": true,
		"lifetime_sec": 0.5,
		"amount_ratio": 0.5,
		"local_coords": false,
		"offset": [0, 0],
	},
	"loop_frame_offsets": {
		"appear": -1,
		"attack": -1,
		"attack_air": -1,
		"back": -1,
		"climb": -1,
		"crouch": -1,
		"default": -1,
		"fall": -1,
		"grab": -1,
		"hold_crouch": -1,
		"hold_default": -1,
		"hold_fall": -1,
		"hold_jump": -1,
		"hold_walk": -1,
		"jump": -1,
		"kick": -1,
		"skid": -1,
		"slide": -1,
		"swim": 6,
		"swim_idle": -1,
		"swim_up": -1,
		"swim_down": -1,
		"walk": -1,
		"warp": -1,
		"win": -1,
		"look_up": -1,
		"p_run": -1,
		"p_jump": -1,
		"p_fall": -1,
		"idle": -1,
		"hold_swim": -1,
		"hold_look_up": -1,
	},
}

const DESCRIPTIONS := {
	"look_up_animation": "'look_up' & 'hold_look_up': triggered by pressing up. Will also make a sound, if it exists.",
	"attack_air_animation": "'attack_air': shooting a projectile in mid-air plays this animation. No effect for suits without attacking.",
	"separate_run_animation": "'p_run', 'p_jump', 'p_fall': running at max speed triggers these. No effect without constant running.",
	"idle_animation": "'idle': when no input is made, this animation plays after a specified amount of time.",
	"idle_activate_after_sec": "From 0.1 to 9999. No effect if idle animation is disabled.",
	"kick_ground_animation": "The 'kick' animation also plays when kicking things without holding anything (e.g. shells).",
	"warp_animation": "'warp'; if off, warping vertically uses 'jump', and 'crouch' or 'default'.",
	"skid_sound_loop_delay": "Delay in seconds between each playback of the skidding sound (0.05 to 2.0).",
	"head_bump_sound": "Play global sound 'head_bump' on every touch of ceiling.",
	"fall_animation": "If off, 'fall' and its hold/p variants are replaced by 'jump'.",
	"separate_swim_idle_animation": "If 'swim' looping is off, 'swim_idle' plays right after. Default on for frog.",
	"frog_restart_swim_on_direction_change": "Frog suit: restart swim/swim_up/swim_down from frame 0 when changing direction.",
	"emit_particles": "Particles for the in-game character.",
	"enabled": "If no texture is set, the default texture will be starman particles.",
	"color": "Particles will be modulated by this color.",
	"show_behind": "Particles will be rendered behind the player.",
	"lifetime_sec": "From 0.04 to 600. Higher values spawn new particles less often.",
	"amount_ratio": "From 0 to 1. Maximum particle amount is 48, multiplied by this.",
	"local_coords": "Should particles follow the player? If on, may fix jitter on movement.",
	"offset": "Offset particles by this Vector2 (x, y).",
}

const LIMITS := {
	"idle_activate_after_sec": { "min": 0.1, "max": 9999.0, "step": 0.1 },
	"skid_sound_loop_delay": { "min": 0.05, "max": 2.0, "step": 0.01 },
	"lifetime_sec": { "min": 0.04, "max": 600.0, "step": 0.1 },
	"amount_ratio": { "min": 0.0, "max": 1.0, "step": 0.01 },
	"offset": { "step": 1.0 },
}


static func defaults_for_suit(suit: String) -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate(true)
	if suit == "frog":
		out.separate_swim_idle_animation = true
	return out


static func editor_schema(suit: String = "") -> Dictionary:
	return {
		"defaults": defaults_for_suit(suit),
		"descriptions": DESCRIPTIONS,
		"limits": LIMITS,
		"skip": SKIP_IN_EDITOR,
		"choices": {},
		"hint": "Per-powerup flags used by the game. Loop frame offsets stay on the animation panel. Saved to suit_tweaks.json.",
	}


static func merge_with_defaults(parsed: Dictionary, defaults: Dictionary) -> Dictionary:
	var loaded: Dictionary = defaults.duplicate(true)
	for key in parsed.keys():
		var value = parsed[key]
		if key in loaded && loaded[key] is Dictionary && value is Dictionary:
			for sub in value.keys():
				loaded[key][sub] = _coerce(loaded[key].get(sub), value[sub])
			continue
		if key in loaded:
			loaded[key] = _coerce(loaded[key], value)
		else:
			loaded[key] = value
	return loaded


static func merge_loaded(parsed: Dictionary, suit: String) -> Dictionary:
	var loaded := merge_with_defaults(parsed, defaults_for_suit(suit))
	if parsed.has("loop_frame_offsets") && parsed.loop_frame_offsets is Dictionary:
		for anim in parsed.loop_frame_offsets.keys():
			loaded.loop_frame_offsets[str(anim)] = int(parsed.loop_frame_offsets[anim])
	return loaded


const _TITLE_SMALL_WORDS := [
	"a", "an", "the",
	"and", "but", "or", "nor", "for", "yet", "so",
	"as", "at", "by", "in", "of", "on", "to", "from", "with", "per", "via",
	"into", "onto", "over", "upon", "after", "before", "about", "under",
]


static func display_name(key: String) -> String:
	var words := str(key).replace("_", " ").split(" ", false)
	var last := words.size() - 1
	for i in words.size():
		var lower := str(words[i]).to_lower()
		if i != 0 && i != last && lower in _TITLE_SMALL_WORDS:
			words[i] = lower
		else:
			words[i] = lower.capitalize()
	return " ".join(words)


static func description_for(key: String) -> String:
	return str(DESCRIPTIONS.get(key, ""))


static func limits_for(key: String) -> Dictionary:
	var lim = LIMITS.get(key, {})
	return lim if lim is Dictionary else {}


static func is_html_color(value: Variant) -> bool:
	return value is String && (value as String).is_valid_html_color()


static func is_vec2(value: Variant) -> bool:
	if value is Vector2 || value is Vector2i:
		return true
	if value is Array && value.size() == 2:
		return typeof(value[0]) in [TYPE_INT, TYPE_FLOAT] && typeof(value[1]) in [TYPE_INT, TYPE_FLOAT]
	return false


static func to_vec2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	if value is Array && value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


static func vec2_to_json(value: Vector2) -> Array:
	return [value.x, value.y]


static func color_to_html(color: Color) -> String:
	return "#%s" % color.to_html(true)


static func get_at(root: Dictionary, path: PackedStringArray) -> Variant:
	var cur: Variant = root
	for key in path:
		if !(cur is Dictionary) || !cur.has(key):
			return null
		cur = cur[key]
	return cur


static func set_at(root: Dictionary, path: PackedStringArray, value: Variant) -> void:
	if path.is_empty():
		return
	var cur: Dictionary = root
	for i in path.size() - 1:
		var key := path[i]
		if !(cur.get(key) is Dictionary):
			cur[key] = {}
		cur = cur[key]
	cur[path[path.size() - 1]] = value


static func _coerce(default_val: Variant, value: Variant) -> Variant:
	if default_val is bool:
		return bool(value)
	if default_val is int:
		return int(value)
	if default_val is float:
		return float(value)
	if default_val is String:
		return str(value)
	if is_vec2(default_val):
		return vec2_to_json(to_vec2(value))
	return value
