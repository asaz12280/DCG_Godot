extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const AmmoBallisticsServiceScript := preload("res://scripts/combat/ammo_ballistics_service.gd")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Ammo := preload("res://data/items/ammo/ammo_9mm.tres")
const PolishedAmmo := preload("res://data/items/ammo/ammo_9mm_polished.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_validate_item_data()
	_validate_service()
	await _validate_sustained_fire_recoil()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[weapon_recoil_handling] OK data=weapon/ammo service=recoil fire=random_horizontal sustained=offset boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_data() -> void:
	if Pistol.weapon_horizontal_recoil <= 0.0:
		_errors.append("Pistol-S should expose authored horizontal recoil.")
	if Ammo.ammo_recoil_multiplier != 1.0:
		_errors.append("Baseline Ammo-S should keep neutral 1.0 recoil multiplier.")
	if PolishedAmmo.ammo_recoil_multiplier >= Ammo.ammo_recoil_multiplier:
		_errors.append("Polished Ammo-S should reduce recoil compared with baseline Ammo-S.")
	var weapon_stack := Pistol.to_stack(1)
	if absf(float(weapon_stack.get("weapon_horizontal_recoil", 0.0)) - Pistol.weapon_horizontal_recoil) > 0.001:
		_errors.append("Weapon stacks should expose horizontal recoil for UI and save-independent planning.")
	var ammo_stack := PolishedAmmo.to_stack(4)
	if absf(float(ammo_stack.get("ammo_recoil_multiplier", 0.0)) - PolishedAmmo.ammo_recoil_multiplier) > 0.001:
		_errors.append("Ammo stacks should expose ammo_recoil_multiplier for UI and planning.")


func _validate_service() -> void:
	if AmmoBallisticsServiceScript.recoil_multiplier(null) != 1.0:
		_errors.append("Missing ammo should keep neutral recoil multiplier.")
	if absf(AmmoBallisticsServiceScript.recoil_multiplier(PolishedAmmo) - PolishedAmmo.ammo_recoil_multiplier) > 0.001:
		_errors.append("AmmoBallisticsService should read Polished Ammo-S recoil multiplier.")
	var heavy_recoil_ammo := ItemDef.new()
	heavy_recoil_ammo.item_type = "ammo"
	heavy_recoil_ammo.ammo_recoil_multiplier = 1.4
	if absf(AmmoBallisticsServiceScript.recoil_multiplier(heavy_recoil_ammo) - 1.4) > 0.001:
		_errors.append("AmmoBallisticsService should support authored higher-recoil ammo too.")


func _validate_sustained_fire_recoil() -> void:
	var baseline := await _fire_two_shots_with_ammo(Ammo)
	var polished := await _fire_two_shots_with_ammo(PolishedAmmo)
	if baseline.is_empty() or polished.is_empty():
		return
	var first: Dictionary = baseline.get("first", {}) as Dictionary
	var second: Dictionary = baseline.get("second", {}) as Dictionary
	var spread: Dictionary = baseline.get("spread", {}) as Dictionary
	if not bool(first.get("active", false)):
		_errors.append("First shot should record active weapon recoil state.")
	var baseline_range := Pistol.weapon_horizontal_recoil * Ammo.ammo_recoil_multiplier
	var polished_range := Pistol.weapon_horizontal_recoil * PolishedAmmo.ammo_recoil_multiplier
	if absf(float(first.get("applied_angle_degrees", 99.0))) > baseline_range + 0.001:
		_errors.append("First shot recoil should stay inside the +/-H recoil fan.")
	if absf(float(first.get("horizontal_impulse_degrees", 0.0))) <= 0.001:
		_errors.append("First shot should apply horizontal recoil to the fired projectile.")
	if absf(float(first.get("accumulated_angle_degrees", 0.0))) <= 0.001:
		_errors.append("First shot should expose a non-zero recoil offset for reticle feedback.")
	if absf(float(second.get("applied_angle_degrees", 99.0))) > baseline_range + 0.001:
		_errors.append("Second shot recoil should stay inside the +/-H recoil fan.")
	if bool(spread.get("active", true)):
		_errors.append("Fresh durability recoil validation should not depend on low-durability spread.")
	var polished_first: Dictionary = polished.get("first", {}) as Dictionary
	if absf(float(polished_first.get("applied_angle_degrees", 99.0))) > polished_range + 0.001:
		_errors.append("Polished Ammo-S shot recoil should stay inside its reduced recoil fan.")
	if polished_range >= baseline_range:
		_errors.append("Polished Ammo-S should reduce the maximum horizontal recoil fan compared with baseline Ammo-S.")
	if absf(float(polished_first.get("ammo_recoil_multiplier", 0.0)) - PolishedAmmo.ammo_recoil_multiplier) > 0.001:
		_errors.append("Recoil state should expose the loaded ammo recoil multiplier.")


func _validate_source_boundaries() -> void:
	var item_source := FileAccess.get_file_as_string("res://scripts/items/item_def.gd")
	for required in ["weapon_horizontal_recoil", "ammo_recoil_multiplier"]:
		if not item_source.contains(required):
			_errors.append("ItemDef should own recoil data field: %s." % required)
	var service_source := FileAccess.get_file_as_string("res://scripts/combat/ammo_ballistics_service.gd")
	if not service_source.contains("recoil_multiplier"):
		_errors.append("AmmoBallisticsService should own ammo recoil multiplier math.")
	for forbidden in ["InventoryModel", "EquipmentModel", "RaidHudPanel"]:
		if service_source.contains(forbidden):
			_errors.append("AmmoBallisticsService should stay combat-math only and not depend on %s." % forbidden)
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["_projectile_direction_with_recoil", "_random_weapon_recoil_angle", "get_last_weapon_recoil_state"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should bridge recoil handling through %s." % required)
	var equipment_source := FileAccess.get_file_as_string("res://scripts/player/player_equipment_controller_3d.gd")
	for required in ["AmmoBallisticsServiceScript.recoil_multiplier", "current_loaded_ammo_item", "ammo_recoil_multiplier"]:
		if not equipment_source.contains(required):
			_errors.append("PlayerEquipmentController3D should own ammo recoil handling through %s." % required)
	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	for forbidden in ["weapon_horizontal_recoil", "ammo_recoil_multiplier"]:
		if weapon_source.contains(forbidden):
			_errors.append("WeaponController3D should not own equipment or ammo recoil persistence: %s." % forbidden)
	var tooltip_source := FileAccess.get_file_as_string("res://scripts/ui/item_stack_tooltip_presenter.gd")
	for required in ["ui.item.weapon_recoil_format", "ui.item.ammo_recoil_multiplier_format"]:
		if not tooltip_source.contains(required):
			_errors.append("Shared item tooltip presenter should show recoil stat key: %s." % required)


func _fire_two_shots_with_ammo(ammo_def: ItemDef) -> Dictionary:
	var context := await _spawn_context()
	if context.is_empty():
		return {}
	var player: Node = context["player"]
	var weapon: Node = context["weapon"]
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_stack(_durable_pistol_stack(12, 12))
	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Recoil validation should equip a fresh Pistol-S.")
		_free_node(context["scene"])
		return {}
	await process_frame
	_load_weapon_with_ammo(weapon, ammo_def, 3)
	_press_primary_fire(player)
	var first_recoil: Dictionary = player.call("get_last_weapon_recoil_state")
	var first_spread: Dictionary = player.call("get_last_weapon_spread_state")
	if weapon.has_method("force_cooldown_ready"):
		weapon.call("force_cooldown_ready")
	_press_primary_fire(player)
	var second_recoil: Dictionary = player.call("get_last_weapon_recoil_state")
	_free_node(context["scene"])
	return {
		"first": first_recoil,
		"second": second_recoil,
		"spread": first_spread,
	}


func _load_weapon_with_ammo(weapon: Node, ammo_def: ItemDef, quantity: int) -> void:
	weapon.set("current_ammo", 0)
	weapon.set("reserve_ammo", 0)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")
	var moved := int(weapon.call("reload_from_item", ammo_def, quantity))
	if moved != quantity:
		_errors.append("Validation ammo should load %d rounds, got %d." % [quantity, moved])
	if weapon.has_method("force_cooldown_ready"):
		weapon.call("force_cooldown_ready")


func _press_primary_fire(player: Node) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	player.call("_unhandled_input", event)


func _spawn_context() -> Dictionary:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player := scene.get_node_or_null("Player3D")
	var weapon := player.get_node_or_null("WeaponController3D") if player != null else null
	if player == null:
		_errors.append("Gameplay scene should include Player3D.")
		_free_node(scene)
		return {}
	if weapon == null:
		_errors.append("Player3D should include WeaponController3D.")
		_free_node(scene)
		return {}
	return {
		"scene": scene,
		"player": player,
		"weapon": weapon,
	}


func _durable_pistol_stack(current: int, maximum: int) -> Dictionary:
	var stack := Pistol.to_stack(1)
	stack["current_durability"] = current
	stack["max_durability"] = maximum
	stack["original_max_durability"] = Pistol.max_durability
	stack["repair_max_durability_loss"] = Pistol.repair_max_durability_loss
	stack["durability_penalty_ratio"] = Pistol.durability_penalty_ratio
	return stack


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
