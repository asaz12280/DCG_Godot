extends SceneTree

const DIRECTION_DOC := "res://docs/design/player_visibility_v2_direction.md"
const QUEUE_DOC := "res://docs/tasks/player_visibility_v2_task_queue.md"
const AUDIT_DOC := "res://docs/tasks/player_visibility_v2_health_audit.md"

var _required_files := PackedStringArray([
	"res://scripts/ui/ui_manager.gd",
	"res://scripts/inventory/inventory_model.gd",
	"res://scripts/combat/weapon_controller_3d.gd",
	"res://scripts/loot/loot_container_3d.gd",
	"res://scripts/inventory/container_inventory_model.gd",
	"res://scenes/ui/container_inventory_ui.tscn",
	"res://tools/validate_container_open_flow.gd",
	"res://scripts/player/player_controller_3d.gd",
	"res://scenes/base/base_3d.tscn",
	"res://scenes/player/player_3d.tscn",
	"res://data/items/weapons/pistol_9mm.tres",
	"res://data/items/ammo/ammo_9mm.tres",
])

var _audit_required_terms := PackedStringArray([
	"3D Base interaction wiring pending",
	"2D Base screen",
	"hardwired starter pistol",
	"starter loadout coupling",
	"direct container-to-backpack grant resolved",
	"missing container capacity UI resolved",
	"fake ammo counters",
	"hitscan firing",
	"missing EquipmentModel",
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


func _validate_known_current_risks_are_visible() -> void:
	var player_scene_text := _read_text("res://scenes/player/player_3d.tscn")
	_expect_contains(player_scene_text, "weapon_def = ExtResource(\"3_pistol\")", "Current hardwired starter pistol risk should remain visible until task thirteen removes it.")

	var weapon_text := _read_text("res://scripts/combat/weapon_controller_3d.gd")
	_expect_contains(weapon_text, "current_ammo", "Current fake ammo counter risk should remain visible until ammo model tasks remove it.")
	_expect_contains(weapon_text, "reserve_ammo", "Current reserve ammo counter risk should remain visible until ammo model tasks remove it.")
	_expect_contains(weapon_text, "intersect_ray", "Current hitscan firing risk should remain visible until projectile tasks remove it.")

	var container_text := _read_text("res://scripts/loot/loot_container_3d.gd")
	if container_text.contains("add_item_resource"):
		_errors.append("Direct container-to-backpack grant should stay removed after V2 task eight.")
	_expect_contains(container_text, "ContainerInventoryModelScript", "LootContainer3D should prepare container-owned inventory after V2 task eight.")
	_expect_contains(container_text, "open_container_inventory", "LootContainer3D should request UIManager container UI after V2 task eight.")


func _validate_queue_mentions_health_check() -> void:
	var queue_text := _read_text(QUEUE_DOC)
	_expect_contains(queue_text, "validate_gameplay_architecture.gd", "V2 task queue should keep gameplay architecture validation.")
	_expect_contains(queue_text, "validate_player_visibility_v2_health.gd", "V2 task queue should name the V2 health check validator.")


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("Cannot read %s" % path)
		return ""
	return file.get_as_text()


func _expect_contains(content: String, needle: String, message: String) -> void:
	if not content.contains(needle):
		_errors.append(message)
