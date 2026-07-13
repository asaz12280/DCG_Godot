extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const ItemDurabilityServiceScript := preload("res://scripts/items/item_durability_service.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_validate_service_combat_penalty_state()
	await _validate_fire_path_applies_low_durability_spread()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[low_durability_spread] OK service=penalty fresh=stable low=spread wear=preserved boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_service_combat_penalty_state() -> void:
	var fresh: Dictionary = ItemDurabilityServiceScript.combat_penalty_state(_durable_pistol_stack(12, 12), Pistol)
	if bool(fresh.get("active", true)) or float(fresh.get("spread_degrees", -1.0)) != 0.0:
		_errors.append("Fresh equipment should not produce a durability combat penalty.")
	var low: Dictionary = ItemDurabilityServiceScript.combat_penalty_state(_durable_pistol_stack(5, 12), Pistol)
	if not bool(low.get("active", false)) or str(low.get("source", "")) != "low_durability":
		_errors.append("Equipment at or below half durability should produce a low_durability combat penalty.")
	if float(low.get("spread_degrees", 0.0)) <= 0.0:
		_errors.append("Low durability should produce positive spread degrees.")
	if float(low.get("damage_multiplier", 0.0)) != 1.0:
		_errors.append("This slice should not change damage; only spread is active.")
	var broken: Dictionary = ItemDurabilityServiceScript.combat_penalty_state(_durable_pistol_stack(0, 12), Pistol)
	if str(broken.get("source", "")) != "depleted_durability" or float(broken.get("spread_degrees", 0.0)) <= float(low.get("spread_degrees", 0.0)):
		_errors.append("Depleted durability should produce a stronger spread penalty than low durability.")


func _validate_fire_path_applies_low_durability_spread() -> void:
	var context := await _spawn_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var weapon: Node = context["weapon"]
	var equipment: RefCounted = player.call("get_equipment_model")
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_stack(_durable_pistol_stack(12, 12))
	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Low durability spread validation should equip a fresh No.5 pistol.")
		_free_node(context["scene"])
		return
	await process_frame
	_prepare_weapon_to_fire(weapon, 2)
	_press_primary_fire(player)
	await process_frame
	var fresh_spread: Dictionary = player.call("get_last_weapon_spread_state")
	if bool(fresh_spread.get("active", true)):
		_errors.append("Fresh durability shot should not apply spread.")
	if int(weapon.get("current_ammo")) != 1:
		_errors.append("Fresh durability shot should still consume one loaded round.")

	if not bool(equipment.call("equip_stack", &"primary_weapon", _durable_pistol_stack(5, 12))):
		_errors.append("Low durability spread validation should replace equipment with a worn pistol.")
		_free_node(context["scene"])
		return
	await process_frame
	_prepare_weapon_to_fire(weapon, 2)
	_press_primary_fire(player)
	await process_frame
	var low_spread: Dictionary = player.call("get_last_weapon_spread_state")
	if not bool(low_spread.get("active", false)):
		_errors.append("Low durability shot should record an active spread penalty.")
	if str(low_spread.get("source", "")) != "low_durability":
		_errors.append("Low durability shot should report low_durability as the spread source.")
	if absf(float(low_spread.get("applied_angle_degrees", 0.0))) <= 0.01:
		_errors.append("Low durability shot should apply a non-zero deterministic spread angle.")
	if float(low_spread.get("spread_degrees", 0.0)) <= 0.0:
		_errors.append("Low durability shot should expose positive spread degrees for UI/debug use.")
	if int(low_spread.get("current_durability", 0)) != 5 or int(low_spread.get("max_durability", 0)) != 12:
		_errors.append("Spread state should describe pre-shot equipment durability.")
	var primary_stack: Dictionary = equipment.call("get_slot", &"primary_weapon")
	if int(primary_stack.get("current_durability", 0)) != 4:
		_errors.append("Low durability shot should still apply normal durability wear after firing.")
	if int(weapon.get("current_ammo")) != 1:
		_errors.append("Low durability shot should still consume one loaded round.")

	_free_node(context["scene"])


func _validate_source_boundaries() -> void:
	var durability_source := FileAccess.get_file_as_string("res://scripts/items/item_durability_service.gd")
	if not durability_source.contains("combat_penalty_state"):
		_errors.append("ItemDurabilityService should own combat penalty calculation.")
	for forbidden in ["WeaponController3D", "PlayerController3D", "RaidHudPanel"]:
		if durability_source.contains(forbidden):
			_errors.append("ItemDurabilityService combat penalty math should stay model-only: %s." % forbidden)
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["_projectile_direction_with_durability_spread", "get_last_weapon_spread_state", "combat_penalty_state"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should bridge durability penalty into fired direction through %s." % required)
	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	for forbidden in ["ItemDurabilityServiceScript", "EquipmentModel", "get_equipment_model"]:
		if weapon_source.contains(forbidden):
			_errors.append("WeaponController3D should not directly read equipment durability: %s." % forbidden)


func _prepare_weapon_to_fire(weapon: Node, ammo: int) -> void:
	weapon.set("current_ammo", ammo)
	weapon.set("reserve_ammo", 0)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")
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
