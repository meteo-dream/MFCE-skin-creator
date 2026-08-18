extends RefCounted
class_name GlobalSounds

## Skin-root OGGs loaded by MFCE SkinsManager from _global_sounds/.
## Keys match CharacterManager.GLOBAL_SOUNDS_BASE (uncommented).

const FOLDER := "_global_sounds"

const DESCRIPTIONS := {
	"1up": "Played when gaining a life.",
	"block_appear": "Played when a block or power-up appears.",
	"block_break": "Played when a block breaks.",
	"block_bump": "Played when bumping a block from below.",
	"bonus_activate": "Played when activating a bonus item such as a stopwatch.",
	"bonus_reserve": "Played when storing an item in the reserve box.",
	"bonus_run_out": "Played when a bonus timer runs out.",
	"bonus_stopwatch": "Played while the stopwatch bonus is active.",
	"boomerang_spin": "Played while a boomerang is spinning in the air.",
	"bowser_be_happy": "Played when Bowser is defeated.",
	"bowser_hurt": "Played when Bowser takes damage.",
	"checkpoint_switch": "Played when activating a checkpoint.",
	"coin": "Played when collecting a coin.",
	"enemy_bump": "Played when an attack fails to defeat an enemy.",
	"enemy_freeze": "Played when freezing an enemy.",
	"enemy_kick": "Played when defeating an enemy with a kick or similar attack.",
	"enemy_stomp": "Played when stomping an enemy.",
	"fireball_bump": "Played when a fireball hits a wall or an enemy without defeating it.",
	"game_over": "Played on the game over screen.",
	"head_bump": "Played when the player bumps their head on a ceiling.\nOnly when the corresponding skin tweak is enabled.",
	"hud_acceptance": "Played as a HUD confirm sound.",
	"hud_pause_close": "Played when closing the pause menu.",
	"hud_pause_open": "Played when opening the pause menu.",
	"hud_time_hurry": "Played when time is running low.",
	"hud_time_score": "Played when remaining time is converted to score.",
	"level_complete": "Played when completing a level.",
	"level_cutscene_song": "Played as the level intro cutscene song.",
	"map_level_enter": "Played when entering a level from the world map.",
	"menu_enter": "Played when confirming a menu item.",
	"menu_fade_out": "Played when fading out of a menu or the map.",
	"menu_failure": "Played when a menu action fails.",
	"menu_mouse_hover": "Played when hovering a menu item with the mouse.",
	"menu_select": "Played when moving the menu cursor.",
	"menu_select_short": "Played as a short menu selection sound.",
	"menu_start_song": "Played when selecting Start on the main menu.",
	"menu_toggle": "Played when toggling a menu option.",
	"message_box": "Played when a message from a message box is opening.",
	"p_switch": "Played as P-Switch music.",
	"p_switch_activate": "Played when activating a P-Switch.",
	"pipe_cutscene": "Played during pipe cutscenes.",
	"spring_bounce": "Played when bouncing on a springboard.",
	"starman": "Played as Starman music.",
	"stun": "Played when Thwomp falls, a castle brick begins to fall, or similar.",
	"stun_beetroot": "Played when a beetroot collides with a block.",
	"water_splash_in": "Played when entering water.",
	"water_splash_out": "Played when leaving water.",
}


static func files() -> Dictionary:
	var out := {}
	for key in DESCRIPTIONS.keys():
		out[key] = { "dest_name": "%s.ogg" % key, "kind": "ogg" }
	return out


static func defaults() -> Dictionary:
	var out := {}
	for key in DESCRIPTIONS.keys():
		out[key] = PackedStringArray()
	return out


static func sounds_dir(skin_root: String) -> String:
	if skin_root.is_empty():
		return ""
	return skin_root.path_join(FOLDER)


static func inject(skin_root: String) -> Dictionary:
	var out := defaults()
	var dir := sounds_dir(skin_root)
	if dir.is_empty():
		return out
	for key in DESCRIPTIONS.keys():
		out[key] = SuitSounds.list_existing(dir, key)
	return out


static func file_for(path: PackedStringArray) -> Dictionary:
	if path.is_empty():
		return {}
	var key := path[path.size() - 1]
	if key not in DESCRIPTIONS.keys():
		return {}
	return { "dest_name": "%s.ogg" % key, "kind": "ogg" }


static func editor_schema() -> Dictionary:
	return {
		"defaults": defaults(),
		"descriptions": DESCRIPTIONS,
		"file_pickers": files(),
		"reset_includes_files": true,
		"expand_file_pickers": true,
		"sort_keys": true,
		"hint": "OGG files in this skin's _global_sounds folder. Each sound can have up to 11 variations. Leave empty to use the game's default global sounds.",
	}
