extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const LightArmor := preload("res://data/items/armor/light_armor.tres")
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_broken_armor_provides_no_protection()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[broken_armor_effect] OK broken=no_protection full=protects state=durability boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_broken_armor_provides_no_protection() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	var player := scene.get_node_or_null("Player3D")
	if player == null:
		_errors.append("Gameplay scene should include Player3D.")
		_free_node(scene)
		return
	var equipment: RefCounted = player.call("get_equipment_model")
	if equipment == null:
		_errors.append("Player should expose an equipment model.")
		_free_node(scene)
		return

	var no_armor_defense := float(player.call("get_total_defense"))
	var no_armor_loss := _damage_loss(player, _ballistic_hit())
	var full_stack := _durable_armor_stack(80, 80)
	if not bool(equipment.call("equip_stack", &"armor", full_stack)):
		_errors.append("Validation should equip full durability armor.")
		_free_node(scene)
		return
	var full_defense := float(player.call("get_total_defense"))
	var full_protection := float(player.call("get_equipment_armor_protection_level"))
	var full_loss := _damage_loss(player, _ballistic_hit())
	if full_defense <= no_armor_defense:
		_errors.append("Full armor should increase effective defense.")
	if full_protection <= 0.0:
		_errors.append("Full armor should expose a protection level.")
	if full_loss >= no_armor_loss:
		_errors.append("Full armor should reduce ballistic damage compared with no armor.")

	var broken_stack := _durable_armor_stack(0, 80)
	if not bool(equipment.call("equip_stack", &"armor", broken_stack)):
		_errors.append("Validation should equip broken armor.")
		_free_node(scene)
		return
	var broken_state: Dictionary = player.call("get_active_armor_durability_state")
	if not bool(broken_state.get("durability_is_broken", false)):
		_errors.append("Player should expose broken armor durability state.")
	var effect_state: Dictionary = player.call("get_armor_effect_state")
	if float(effect_state.get("defense_bonus", -1.0)) != 0.0:
		_errors.append("Broken armor should report zero defense bonus.")
	if float(effect_state.get("armor_protection_level", -1.0)) != 0.0:
		_errors.append("Broken armor should report zero protection level.")
	if not bool(effect_state.get("durability_is_broken", false)):
		_errors.append("Armor effect state should preserve broken durability visibility.")
	var broken_defense := float(player.call("get_total_defense"))
	var broken_loss := _damage_loss(player, _ballistic_hit())
	if not is_equal_approx(broken_defense, no_armor_defense):
		_errors.append("Broken armor should not add defense, got %.2f vs base %.2f." % [broken_defense, no_armor_defense])
	if not is_equal_approx(broken_loss, no_armor_loss):
		_errors.append("Broken armor should take no-armor damage, got %.2f vs %.2f." % [broken_loss, no_armor_loss])
	_free_node(scene)


func _validate_source_boundaries() -> void:
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["get_active_armor_durability_state", "_is_equipped_armor_broken", "get_equipment_defense_bonus", "get_equipment_armor_protection_level"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should bridge armor durability through %s." % required)
	var service_source := FileAccess.get_file_as_string("res://scripts/items/item_durability_service.gd")
	if not service_source.contains("normalize_stack"):
		_errors.append("ItemDurabilityService should own armor stack durability normalization.")
	var equipment_source := FileAccess.get_file_as_string("res://scripts/equipment/equipment_model.gd")
	for forbidden in ["apply_damage", "ArmorMitigationServiceScript", "StatusTopMenuPanel"]:
		if equipment_source.contains(forbidden):
			_errors.append("EquipmentModel should not own broken armor combat/UI behavior: %s." % forbidden)
	var status_source := FileAccess.get_file_as_string("res://scripts/ui/status_top_menu_panel.gd")
	for forbidden in ["durability_is_broken =", "current_durability =", "equip_stack"]:
		if status_source.contains(forbidden):
			_errors.append("StatusTopMenuPanel should display armor state without mutating durability: %s." % forbidden)


func _damage_loss(player: Node, event: DamageEvent) -> float:
	if player.has_method("restore_health_to_full"):
		player.call("restore_health_to_full")
	else:
		player.set("health", player.call("get_total_max_health"))
	var before := float(player.get("health"))
	player.call("apply_damage", event)
	return before - float(player.get("health"))


func _ballistic_hit() -> DamageEvent:
	var event: DamageEvent = DamageEventScript.new(24.0, null, null, [&"gun", &"validation"])
	event.armor_penetration_level = 0.0
	return event


func _durable_armor_stack(current: int, maximum: int) -> Dictionary:
	var stack := LightArmor.to_stack(1)
	stack["current_durability"] = current
	stack["max_durability"] = maximum
	stack["original_max_durability"] = LightArmor.max_durability
	stack["repair_max_durability_loss"] = LightArmor.repair_max_durability_loss
	stack["durability_penalty_ratio"] = LightArmor.durability_penalty_ratio
	return stack


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
