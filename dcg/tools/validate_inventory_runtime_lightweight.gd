extends SceneTree


const PLAYER_CONTROLLER_PATH := "res://scripts/player/player_controller_3d.gd"
const PLAYER_TIMED_ACTION_PATH := "res://scripts/player/player_timed_action_controller_3d.gd"
const INVENTORY_UI_PATH := "res://scripts/ui/inventory_equipment_ui.gd"
const EQUIPMENT_CONTROLLER_PATH := "res://scripts/player/player_equipment_controller_3d.gd"
const INVENTORY_ITEM_RESOLVER_PATH := "res://scripts/ui/inventory_item_resolver.gd"
const WEAPON_AMMO_MODEL_PATH := "res://scripts/combat/weapon_ammo_model.gd"
const PLAYER_HUD_PATH := "res://scripts/ui/player_hud_3d.gd"
const PLAYER_HUD_PAINTER_PATH := "res://scripts/ui/player_hud_painter.gd"
const LOOT_CONTAINER_PATH := "res://scripts/loot/loot_container_3d.gd"
const BASE_INTERACTION_PATH := "res://scripts/base/base_interaction_controller_3d.gd"
const LOCALIZATION_PATH := "res://data/localization/game_text.csv"


var _errors: Array[String] = []


func _initialize() -> void:
	_validate_item_use_progress_throttle()
	_validate_reload_event_driven()
	_validate_timed_action_hud()
	_validate_timed_action_interaction_blocks()
	_validate_inventory_ui_event_driven()
	_validate_item_def_caches()
	_validate_ammo_count_change_guard()
	if _errors.is_empty():
		print("[inventory_runtime_lightweight] OK reload=timer item_use=timer inventory_ui=event_driven item_load=cache ammo_counts=quiet")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _validate_item_use_progress_throttle() -> void:
	var source := _read_text(PLAYER_TIMED_ACTION_PATH)
	_require(source.contains("ITEM_USE_PROGRESS_EMIT_STEP"), "Timed action item use progress must have an emit step.")
	_require(source.contains("func _should_emit_item_use_state"), "Timed action item use progress must be throttled before emitting.")
	_require(source.contains("_last_item_use_emit_progress"), "Timed action controller must remember last emitted item use progress.")
	_require(source.contains("var _item_use_timer: Timer"), "Timed action item use should run from a Timer while active.")
	_require(source.contains("func _start_item_use_timer"), "Timed action item use should start a focused Timer.")
	_require(not source.contains("_update_item_use(delta)"), "Timed action controller must not poll item use from _physics_process.")


func _validate_reload_event_driven() -> void:
	var source := _read_text(PLAYER_TIMED_ACTION_PATH)
	_require(source.contains("var _reload_timer: Timer"), "Timed action reload should run from a Timer while active.")
	_require(source.contains("func _start_reload_timer"), "Timed action reload should start a focused Timer.")
	_require(not source.contains("_update_reload(delta)"), "Timed action controller must not poll reload from _physics_process.")


func _validate_timed_action_hud() -> void:
	var hud_source := _read_text(PLAYER_HUD_PATH)
	var painter_source := _read_text(PLAYER_HUD_PAINTER_PATH)
	_require(hud_source.contains("_timed_action_progress"), "PlayerHud3D should compute timed-action progress locally from start/end time.")
	_require(hud_source.contains("_timed_action_remaining_text"), "PlayerHud3D should expose remaining seconds text for timed actions.")
	_require(painter_source.contains("_timed_action_screen_position"), "Timed-action progress bars should anchor to the player, not the crosshair.")
	_require(painter_source.contains("ui.raid_hud.reloading") and painter_source.contains("_timed_action_remaining_text"), "Reload progress label should show remaining seconds.")
	var localization := _read_text(LOCALIZATION_PATH)
	_require(localization.contains("ui.timed_action.seconds_format"), "Localization should include timed action seconds format.")


func _validate_timed_action_interaction_blocks() -> void:
	var player_source := _read_text(PLAYER_CONTROLLER_PATH)
	var loot_source := _read_text(LOOT_CONTAINER_PATH)
	var base_interaction_source := _read_text(BASE_INTERACTION_PATH)
	var localization := _read_text(LOCALIZATION_PATH)
	_require(player_source.contains("func is_timed_action_active"), "PlayerController should expose timed-action busy state.")
	_require(loot_source.contains("_player_is_timed_action_busy"), "LootContainer3D should block opening while player is reloading or using an item.")
	_require(base_interaction_source.contains("_player_is_timed_action_busy"), "BaseInteractionController3D should block station interaction while player is reloading or using an item.")
	_require(localization.contains("prompt.player_busy"), "Localization should include player busy prompt text.")


func _validate_inventory_ui_event_driven() -> void:
	var source := _read_text(INVENTORY_UI_PATH)
	_require(not source.contains("func _process("), "InventoryEquipmentUI must not poll hover/redraw every frame.")


func _validate_item_def_caches() -> void:
	var equipment_source := _read_text(EQUIPMENT_CONTROLLER_PATH)
	_require(equipment_source.contains("_item_def_lookup_by_path"), "PlayerEquipmentController3D must cache loaded ItemDef resources by path.")
	_require(equipment_source.contains("func _cache_item_def"), "PlayerEquipmentController3D must centralize ItemDef cache updates.")
	var ui_source := _read_text(INVENTORY_UI_PATH)
	_require(ui_source.contains("_item_def_cache_by_path"), "InventoryEquipmentUI must cache direct ItemDef loads by path.")
	var resolver_source := _read_text(INVENTORY_ITEM_RESOLVER_PATH)
	_require(resolver_source.contains("_item_by_path"), "InventoryItemResolver must cache ItemDef path lookups.")


func _validate_ammo_count_change_guard() -> void:
	var source := _read_text(WEAPON_AMMO_MODEL_PATH)
	_require(source.contains("if loaded_ammo == next_loaded and reserve_ammo == next_reserve"), "WeaponAmmoModel.set_counts must avoid emitting unchanged counts.")


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("Unable to read %s" % path)
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _require(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
