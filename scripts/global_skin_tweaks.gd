extends RefCounted
class_name GlobalSkinTweaks

## Defaults and comments match MFCE CharacterManager.DEFAULT_GLOBAL_SKIN_TWEAKS.

const DEFAULTS := {
	"force_override_death_sound": false,
	"load_sounds_from_siblings_on_fallback": true,
	"checkpoint_sound_delay_sec": 0.5,
	"force_override_menu_select_sound": true,
	"force_override_level_complete_music": false,
	"boomerang_spin_sound_delay_sec": 0.5,
	"enable_starman_run_out_sound": false,
	"stopwatch_sound_delay_sec": 0.55,
	"particles_process_material": {
		"particle_flag_disable_z": true,
		"emission_shape": "sphere",
		"emission_sphere_radius": 24,
		"emission_box_extents": [1, 1],
		"angle_min": -180,
		"angle_max": 180,
		"direction": [1, 0],
		"spread": 180,
		"initial_velocity_min": 25,
		"initial_velocity_max": 75,
		"gravity": [0, 0],
		"scale_min": 0.1,
		"scale_max": 0.3,
		"hue_variation_min": 0.0,
		"hue_variation_max": 0.0,
	},
}

const DESCRIPTIONS := {
	"particles_process_material": "Anything wider than 128 pixels on all sides may be cut off and disappear.",
	"particle_flag_disable_z": "Should the texture rotate along its velocity?",
	"emission_shape": "Can be point, box, or sphere.",
	"emission_sphere_radius": "From 0.01 to 128. In pixels, the in-game size is double this value.",
	"emission_box_extents": "From 0.01 to 100. In pixels, the in-game size is double this value.",
	"angle_min": "From -180 to 180.",
	"angle_max": "From -180 to 180.",
	"direction": "X is left/right, Y is up/down. Negative and positive values respectively.",
	"spread": "From 0 to 180.",
	"initial_velocity_min": "From 0 to 1000.",
	"initial_velocity_max": "From 0 to 1000.",
	"gravity": "Any positive or negative value.",
	"scale_min": "From 0 to 1000.",
	"scale_max": "From 0 to 1000.",
	"hue_variation_min": "From -1.0 to 1.0. -1, 0, and 1 are white; pick values in between.",
	"hue_variation_max": "From -1.0 to 1.0. -1, 0, and 1 are white; pick values in between.",
	"force_override_death_sound": "If on, the custom death sound also overrides level-specific death sounds. Otherwise only the default SMW death sound is overridden.",
	"load_sounds_from_siblings_on_fallback": "If a sound has a sibling and only one is in the skin, the sibling uses it too (pipe_in/pipe_out, enemy_bump/block_bump, etc).",
	"checkpoint_sound_delay_sec": "Delay in seconds before the checkpoint sound plays.",
	"force_override_menu_select_sound": "Use this skin's menu select sound even when a level overrides it.",
	"force_override_level_complete_music": "Use this skin's level complete music even when a level overrides it.",
	"boomerang_spin_sound_delay_sec": "Delay in seconds between boomerang spin sound loops.",
	"enable_starman_run_out_sound": "Play a sound when starman is about to run out.",
	"stopwatch_sound_delay_sec": "Delay in seconds for the stopwatch sound.",
}

const LIMITS := {
	"emission_sphere_radius": { "min": 0.01, "max": 128.0, "step": 0.01 },
	"emission_box_extents": { "min": 0.01, "max": 100.0, "step": 0.01 },
	"angle_min": { "min": -180.0, "max": 180.0, "step": 1.0 },
	"angle_max": { "min": -180.0, "max": 180.0, "step": 1.0 },
	"direction": { "step": 0.1 },
	"spread": { "min": 0.0, "max": 180.0, "step": 1.0 },
	"initial_velocity_min": { "min": 0.0, "max": 1000.0, "step": 1.0 },
	"initial_velocity_max": { "min": 0.0, "max": 1000.0, "step": 1.0 },
	"gravity": { "step": 1.0 },
	"scale_min": { "min": 0.0, "max": 1000.0, "step": 0.01 },
	"scale_max": { "min": 0.0, "max": 1000.0, "step": 0.01 },
	"hue_variation_min": { "min": -1.0, "max": 1.0, "step": 0.01 },
	"hue_variation_max": { "min": -1.0, "max": 1.0, "step": 0.01 },
	"checkpoint_sound_delay_sec": { "min": 0.0, "max": 10.0, "step": 0.01 },
	"boomerang_spin_sound_delay_sec": { "min": 0.0, "max": 10.0, "step": 0.01 },
	"stopwatch_sound_delay_sec": { "min": 0.0, "max": 10.0, "step": 0.01 },
}

const CHOICES := {
	"emission_shape": ["point", "box", "sphere"],
}


static func defaults() -> Dictionary:
	return DEFAULTS.duplicate(true)


static func merge_loaded(parsed: Dictionary) -> Dictionary:
	return SuitTweaks.merge_with_defaults(parsed, defaults())


static func editor_schema() -> Dictionary:
	return {
		"defaults": DEFAULTS,
		"descriptions": DESCRIPTIONS,
		"limits": LIMITS,
		"skip": [],
		"choices": CHOICES,
		"hint": "Skin-wide flags used by the game. Saved to global_skin_tweaks.json in the skin root.",
	}
