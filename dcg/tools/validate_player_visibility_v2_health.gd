extends SceneTree

const DIRECTION_DOC := "res://docs/design/player_visibility_v2_direction.md"
const QUEUE_DOC := "res://docs/tasks/player_visibility_v2_task_queue.md"
const AUDIT_DOC := "res://docs/tasks/player_visibility_v2_health_audit.md"

var _required_files := PackedStringArray([
	"res://scripts/ui/ui_manager.gd",
	"res://scripts/inventory/inventory_model.gd",
	"res://scripts/combat/weapon_controller_3d.gd",
	"res://scripts/combat/weapon_ammo_model.gd",
	"res://scripts/combat/projectile_3d.gd",
	"res://scripts/combat/projectile_hit_feedback_3d.gd",
	"res://scripts/loot/loot_container_3d.gd",
	"res://scripts/inventory/container_inventory_model.gd",
	"res://scripts/equipment/equipment_model.gd",
	"res://scripts/raid/raid_loadout_transfer.gd",
	"res://scenes/combat/projectile_3d.tscn",
	"res://scenes/combat/projectile_hit_feedback_3d.tscn",
	"res://scenes/ui/container_inventory_ui.tscn",
	"res://tools/validate_container_open_flow.gd",
	"res://tools/validate_equipment_model.gd",
	"res://tools/validate_ammo_reload_model.gd",
	"res://tools/validate_reload_flow.gd",
	"res://tools/validate_reload_ui.gd",
	"res://tools/validate_projectile_3d.gd",
	"res://tools/validate_projectile_hit.gd",
	"res://tools/validate_shooting_feedback_hud.gd",
	"res://tools/validate_top_menu_panels.gd",
	"res://tools/validate_codex_item_consistency.gd",
	"res://tools/validate_base_to_raid_loadout.gd",
	"res://tools/validate_raid_return_to_base_3d.gd",
	"res://tools/validate_player_visible_v2_slice.gd",
	"res://tools/validate_base_3d_runtime_hud.gd",
	"res://scripts/ui/status_top_menu_panel.gd",
	"res://scenes/ui/status_top_menu_panel.tscn",
	"res://scripts/ui/map_top_menu_panel.gd",
	"res://scenes/ui/map_top_menu_panel.tscn",
	"res://scripts/player/player_controller_3d.gd",
	"res://scenes/base/base_3d.tscn",
	"res://scenes/player/player_3d.tscn",
	"res://data/items/weapons/pistol_9mm.tres",
	"res://data/items/ammo/ammo_9mm.tres",
])

var _audit_required_terms := PackedStringArray([
	"3D Base interaction wiring pending",
	"2D Base screen",
	"hardwired starter pistol resolved",
	"starter loadout coupling",
	"direct container-to-backpack grant resolved",
	"missing container capacity UI resolved",
	"Ammo/Magazine model baseline resolved",
	"visible projectile baseline resolved",
	"EquipmentModel baseline resolved",
	"Top Menu placeholder panels",
	"oversized Raid HUD",
])

var _guardrail_terms := PackedStringArray([
	"`PlayerController3D`",
	"`InventoryModel`",
	"`EquipmentModel`",
	"`WeaponController3D`",
	"`LootContainer3D`",
	"`ContainerInventoryUI`",
	"`UIManager`",
])

var _ui_surface_terms := PackedStringArray([
	"UI_BACKPACK",
	"UI_QUESTS",
	"UI_STATUS",
	"UI_MAP",
	"UI_CODEX",
	"UI_CONTAINER",
	"open_container_inventory",
])

var _inventory_forbidden_terms := PackedStringArray([
	"WeaponController3D",
	"EquipmentModel",
	"UIManager",
	"LootContainer3D",
	"PlayerController3D",
])

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_required_docs()
	_validate_required_paths()
	_validate_documented_known_debts()
	_validate_guarded_boundaries()
	_validate_ui_manager_surface()
	_validate_inventory_independence()
	_validate_equipment_independence()
	_validate_known_current_risks_are_visible()
	_validate_queue_mentions_health_check()
	if _errors.is_empty():
		print("[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_required_docs() -> void:
	for raw_path in PackedStringArray([DIRECTION_DOC, QUEUE_DOC, AUDIT_DOC]):
		var path := String(raw_path)
		if not FileAccess.file_exists(path):
			_errors.append("Missing required V2 health document: %s" % path)


func _validate_required_paths() -> void:
	for raw_path in _required_files:
		var path := String(raw_path)
		if not FileAccess.file_exists(path):
			_errors.append("Missing required gameplay path for V2 health baseline: %s" % path)


func _validate_documented_known_debts() -> void:
	var audit_text := _read_text(AUDIT_DOC)
	for raw_term in _audit_required_terms:
		var term := String(raw_term)
		_expect_contains(audit_text, term, "Health audit must document current debt: %s" % term)


func _validate_guarded_boundaries() -> void:
	var direction_text := _read_text(DIRECTION_DOC)
	var audit_text := _read_text(AUDIT_DOC)
	for raw_term in _guardrail_terms:
		var term := String(raw_term)
		_expect_contains(direction_text, term, "V2 direction must define ownership for %s." % term)
		_expect_contains(audit_text, term, "V2 health audit must protect ownership for %s." % term)


func _validate_ui_manager_surface() -> void:
	var ui_manager_text := _read_text("res://scripts/ui/ui_manager.gd")
	for raw_term in _ui_surface_terms:
		var term := String(raw_term)
		_expect_contains(ui_manager_text, term, "UIManager should expose top-menu surface term %s." % term)


func _validate_inventory_independence() -> void:
	var inventory_text := _read_text("res://scripts/inventory/inventory_model.gd")
	for raw_term in _inventory_forbidden_terms:
		var term := String(raw_term)
		if inventory_text.contains(term):
			_errors.append("InventoryModel should stay UI/equipment/combat independent, but contains %s." % term)


func _validate_equipment_independence() -> void:
	var equipment_text := _read_text("res://scripts/equipment/equipment_model.gd")
	for term in PackedStringArray(["Control", "UIManager", "WeaponController3D", "PlayerController3D", "LootContainer3D", "SaveGameManager"]):
		if equipment_text.contains(term):
			_errors.append("EquipmentModel should stay UI/player/combat/save-service independent, but contains %s." % term)
	for required in PackedStringArray(["class_name EquipmentModel", "can_equip", "equip_item", "unequip", "to_save_data", "load_save_data"]):
		_expect_contains(equipment_text, required, "EquipmentModel should expose %s." % required)


func _validate_known_current_risks_are_visible() -> void:
	var player_scene_text := _read_text("res://scenes/player/player_3d.tscn")
	if player_scene_text.contains("weapon_def = ExtResource(\"3_pistol\")") or player_scene_text.contains("data/items/weapons/pistol_9mm.tres"):
		_errors.append("Player scene should not hardwire No.5 pistol after V2 task thirteen.")

	var player_text := _read_text("res://scripts/player/player_controller_3d.gd")
	for required in PackedStringArray(["_sync_weapon_from_equipment", "get_equipped_item", "equip_weapon", "clear_weapon"]):
		_expect_contains(player_text, required, "PlayerController3D should sync EquipmentModel weapons through %s." % required)

	var weapon_text := _read_text("res://scripts/combat/weapon_controller_3d.gd")
	for required in PackedStringArray(["no_weapon", "equip_weapon", "clear_weapon", "has_weapon"]):
		_expect_contains(weapon_text, required, "WeaponController3D should expose equipment-bound weapon API %s." % required)
	for required in PackedStringArray(["WeaponAmmoModelScript", "get_ammo_model", "add_reserve_ammo_from_item", "set_reserve_ammo_from_item"]):
		_expect_contains(weapon_text, required, "WeaponController3D should keep ammo state model-backed through %s." % required)
	_expect_contains(weapon_text, "current_ammo", "Current fake ammo counter risk should remain visible until ammo model tasks remove it.")
	_expect_contains(weapon_text, "reserve_ammo", "Current reserve ammo counter risk should remain visible until ammo model tasks remove it.")
	for required in PackedStringArray(["DEFAULT_PROJECTILE_SCENE", "projectile_scene", "_spawn_projectile", "_on_projectile_hit"]):
		_expect_contains(weapon_text, required, "WeaponController3D should keep visible projectile firing through %s." % required)
	if weapon_text.contains("intersect_ray"):
		_errors.append("WeaponController3D should not return to direct hitscan intersect_ray after V2 task eighteen.")

	var projectile_text := _read_text("res://scripts/combat/projectile_3d.gd")
	for forbidden in PackedStringArray(["InventoryModel", "EquipmentModel", "UIManager", "PlayerController3D"]):
		if projectile_text.contains(forbidden):
			_errors.append("Projectile3D should stay combat-only and independent from %s." % forbidden)

	var ammo_model_text := _read_text("res://scripts/combat/weapon_ammo_model.gd")
	for forbidden in PackedStringArray(["Control", "InventoryEquipmentUI", "UIManager", "PlayerController3D", "LootContainer3D"]):
		if ammo_model_text.contains(forbidden):
			_errors.append("WeaponAmmoModel should stay combat-data only and independent from %s." % forbidden)

	var container_text := _read_text("res://scripts/loot/loot_container_3d.gd")
	if container_text.contains("add_item_resource"):
		_errors.append("Direct container-to-backpack grant should stay removed after V2 task eight.")
	_expect_contains(container_text, "ContainerInventoryModelScript", "LootContainer3D should prepare container-owned inventory after V2 task eight.")
	_expect_contains(container_text, "open_container_inventory", "LootContainer3D should request UIManager container UI after V2 task eight.")


func _validate_queue_mentions_health_check() -> void:
	var queue_text := _read_text(QUEUE_DOC)
	_expect_contains(queue_text, "validate_gameplay_architecture.gd", "V2 task queue should keep gameplay architecture validation.")
	_expect_contains(queue_text, "validate_player_visibility_v2_health.gd", "V2 task queue should name the V2 health check validator.")
	_expect_contains(queue_text, "validate_player_visible_v2_slice.gd", "V2 task queue should name the player-visible slice validator.")


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("Cannot read %s" % path)
		return ""
	return file.get_as_text()


func _expect_contains(content: String, needle: String, message: String) -> void:
	if not content.contains(needle):
		_errors.append(message)
