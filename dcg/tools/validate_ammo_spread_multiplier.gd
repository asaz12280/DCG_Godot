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
	await _validate_fire_path_uses_loaded_ammo_spread_multiplier()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[ammo_spread_multiplier] OK data=ammo service=spread fire=loaded_ammo tooltip=shared boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_data() -> void:
	if Ammo.ammo_spread_multiplier != 1.0:
		_errors.append("Baseline Ammo-S should keep the neutral 1.0 spread multiplier.")
	if PolishedAmmo.ammo_spread_multiplier >= Ammo.ammo_spread_multiplier:
		_errors.append("Polished Ammo-S should tighten spread compared with baseline Ammo-S.")
	var stack := PolishedAmmo.to_stack(4)
	if absf(float(stack.get("ammo_spread_multiplier", 0.0)) - PolishedAmmo.ammo_spread_multiplier) > 0.001:
		_errors.append("Ammo stacks should expose ammo_spread_multiplier for UI and planning.")


func _validate_service() -> void:
	if AmmoBallisticsServiceScript.spread_multiplier(null) != 1.0:
		_errors.append("Missing ammo should keep the neutral spread multiplier.")
	if absf(AmmoBallisticsServiceScript.spread_multiplier(PolishedAmmo) - 0.75) > 0.001:
		_errors.append("AmmoBallisticsService should read Polished Ammo-S spread multiplier.")
	var loose_ammo := ItemDef.new()
	loose_ammo.item_type = "ammo"
	loose_ammo.ammo_spread_multiplier = 1.5
	if absf(AmmoBallisticsServiceScript.spread_multiplier(loose_ammo) - 1.5) > 0.001:
		_errors.append("AmmoBallisticsService should support authored higher-spread ammo too.")


func _validate_fire_path_uses_loaded_ammo_spread_multiplier() -> void:
	var context := await _spawn_context()
	if context.is_empty():
		return
	var player: Node = context["player"]
	var weapon: Node = context["weapon"]
	var equipment: RefCounted = player.call("get_equipment_model")
	var backpack_model: InventoryModel = player.call("get_inventory_model")
	backpack_model.clear()
	backpack_model.setup(50)
	backpack_model.add_stack(_durable_pistol_stack(5, 12))
	if not bool(player.call("equip_inventory_stack", 0, &"primary_weapon")):
		_errors.append("Ammo spread validation should equip a worn pistol.")
		_free_node(context["scene"])
		return
	await process_frame

	_load_weapon_with_ammo(weapon, Ammo, 2)
	_press_primary_fire(player)
	await process_frame
	var baseline_spread: Dictionary = player.call("get_last_weapon_spread_state")
	if not bool(baseline_spread.get("active", false)):
		_errors.append("Baseline ammo should still report low-durability spread.")
	if absf(float(baseline_spread.get("ammo_spread_multiplier", 0.0)) - 1.0) > 0.001:
		_errors.append("Baseline ammo should keep a 1.0 spread multiplier in spread state.")
	if absf(float(baseline_spread.get("base_spread_degrees", 0.0)) - float(baseline_spread.get("spread_degrees", -1.0))) > 0.001:
		_errors.append("Baseline ammo should not change the base low-durability spread.")

	if not bool(equipment.call("equip_stack", &"primary_weapon", _durable_pistol_stack(5, 12))):
		_errors.append("Ammo spread validation should reset the worn pistol for polished ammo.")
		_free_node(context["scene"])
		return
	await process_frame
	_load_weapon_with_ammo(weapon, PolishedAmmo, 2)
	_press_primary_fire(player)
	await process_frame
	var polished_spread: Dictionary = player.call("get_last_weapon_spread_state")
	if not bool(polished_spread.get("active", false)):
		_errors.append("Polished ammo should still report low-durability spread.")
	if absf(float(polished_spread.get("ammo_spread_multiplier", 0.0)) - 0.75) > 0.001:
		_errors.append("Polished ammo should report its 0.75 spread multiplier in spread state.")
	var expected_spread := float(polished_spread.get("base_spread_degrees", 0.0)) * PolishedAmmo.ammo_spread_multiplier
	if absf(float(polished_spread.get("spread_degrees", 0.0)) - expected_spread) > 0.001:
		_errors.append("Polished ammo should scale base low-durability spread to %.2f, got %.2f." % [expected_spread, float(polished_spread.get("spread_degrees", 0.0))])
	if float(polished_spread.get("spread_degrees", 0.0)) >= float(baseline_spread.get("spread_degrees", 0.0)):
		_errors.append("Polished ammo should tighten the low-durability spread compared with baseline ammo.")

	_free_node(context["scene"])


func _validate_source_boundaries() -> void:
	var item_source := FileAccess.get_file_as_string("res://scripts/items/item_def.gd")
	if not item_source.contains("ammo_spread_multiplier"):
		_errors.append("ItemDef should own ammo_spread_multiplier data.")
	var service_source := FileAccess.get_file_as_string("res://scripts/combat/ammo_ballistics_service.gd")
	for forbidden in ["InventoryModel", "EquipmentModel", "SaveGameManager", "RaidHudPanel"]:
		if service_source.contains(forbidden):
			_errors.append("AmmoBallisticsService should stay combat-math only and not depend on %s." % forbidden)
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["_current_ammo_spread_multiplier", "_projectile_direction_with_durability_spread", "get_last_weapon_spread_state"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should bridge loaded ammo spread through equipment helper term %s." % required)
	var equipment_source := FileAccess.get_file_as_string("res://scripts/player/player_equipment_controller_3d.gd")
	for required in ["AmmoBallisticsServiceScript.spread_multiplier", "current_loaded_ammo_item", "ammo_spread_multiplier"]:
		if not equipment_source.contains(required):
			_errors.append("PlayerEquipmentController3D should own loaded ammo spread through %s." % required)
	var tooltip_source := FileAccess.get_file_as_string("res://scripts/ui/item_stack_tooltip_presenter.gd")
	if not tooltip_source.contains("ui.item.ammo_spread_multiplier_format"):
		_errors.append("Shared item tooltip presenter should show ammo spread multiplier.")


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
