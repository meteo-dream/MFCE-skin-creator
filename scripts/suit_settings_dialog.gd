extends Window
class_name SuitSettingsDialog

enum Tab { SUIT, SOUNDS }

signal dismissed
signal reset_pressed

@onready var tabs: TabContainer = %SettingsTabs
@onready var suit_tweaks: SuitTweaksDialog = %SuitTweaksDialog
@onready var suit_sounds: SuitTweaksDialog = %SuitSoundsDialog
@onready var reset_button: Button = %ResetTweaks
@onready var close_button: Button = %CloseTweaks

var _ignore_close := false


func _ready() -> void:
	exclusive = false
	transient = true
	popup_window = false
	unresizable = false
	close_requested.connect(_on_close_requested)
	focus_entered.connect(_on_focus_entered)
	tabs.tab_changed.connect(_on_tab_changed)
	reset_button.pressed.connect(func(): reset_pressed.emit())
	close_button.pressed.connect(dismiss)
	suit_tweaks.resettable_changed.connect(update_reset_button)
	suit_sounds.resettable_changed.connect(update_reset_button)
	if tabs.get_tab_count() >= 2:
		tabs.set_tab_title(Tab.SUIT, "Suit Tweaks")
		tabs.set_tab_title(Tab.SOUNDS, "Suit Sounds")
	_update_title()
	update_reset_button()


func current_tab() -> Tab:
	return tabs.current_tab as Tab


func open_on_tab(tab: Tab) -> void:
	tabs.current_tab = int(tab)
	_update_title()
	update_reset_button()


func dismiss() -> void:
	dismissed.emit()
	hide()


func update_title() -> void:
	_update_title()


func update_reset_button() -> void:
	if !reset_button:
		return
	var can_reset := false
	match current_tab():
		Tab.SUIT:
			can_reset = suit_tweaks.has_resettable_changes()
		Tab.SOUNDS:
			can_reset = suit_sounds.has_resettable_changes()
	reset_button.disabled = !can_reset
	reset_button.tooltip_text = (
		"Reset this tab's values to their defaults."
		if can_reset
		else "Nothing to reset."
	)


func _on_tab_changed(_tab: int) -> void:
	_update_title()
	update_reset_button()


func _update_title() -> void:
	match tabs.current_tab:
		Tab.SUIT:
			title = suit_tweaks.heading if !suit_tweaks.heading.is_empty() else "Suit Tweaks"
		Tab.SOUNDS:
			title = suit_sounds.heading if !suit_sounds.heading.is_empty() else "Suit Sounds"


func _on_focus_entered() -> void:
	_ignore_close = true
	get_tree().create_timer(0.15).timeout.connect(func(): _ignore_close = false)


func _on_close_requested() -> void:
	if _ignore_close:
		return
	dismiss()
