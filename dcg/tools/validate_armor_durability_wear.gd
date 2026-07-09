extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const LightArmor := preload("res://data/items/armor/light_armor.tres")
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_armor_wears_on_player_hit()
	await _validate_worn_armor_preserves_in_death_loss()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[armor_durability_wear] OK hit=wears final_hit=breaks next_hit=no_protection death=preserves_worn_armor boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_armor_wears_on_player_hit() -> void:
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

	var no_armor_loss := _damage_loss(player, _ballistic_hit())
	if not bool(equipment.call("equip_stack", &"armor", _durable_armor_stack(3, 80))):
		_errors.append("Validation should equip durable armor.")
		_free_node(scene)
		return
	var protected_loss := _damage_loss(player, _ballistic_hit())
	var worn_state: Dictionary = player.call("get_active_armor_durability_state")
	if int(worn_state.get("current_durability", 0)) != 2:
		_errors.append("A damage event should wear equipped armor from 3 to 2 durability.")
	if protected_loss >= no_armor_loss:
		_errors.append("Armor should still protect on the hit that wears it.")

	if not bool(equipment.call("equip_stack", &"armor", _durable_armor_stack(1, 80))):
		_errors.append("Validation should equip nearly broken armor.")
		_free_node(scene)
		return
	var final_protected_loss := _damage_loss(player, _ballistic_hit())
	var broken_state: Dictionary = player.call("get_active_armor_durability_state")
	if int(broken_state.get("current_durability", -1)) != 0:
		_errors.append("The final protected hit should wear armor down to zero durability.")
	if not bool(broken_state.get("durability_is_broken", false)):
		_errors.append("Armor worn to zero should be marked broken.")
	if final_protected_loss >= no_armor_loss:
		_errors.append("Armor should still protect during the hit that breaks it.")

	var broken_loss := _damage_loss(player, _ballistic_hit())
	if not is_equal_approx(broken_loss, no_armor_loss):
		_errors.append("The next hit after armor breaks should behave like no armor, got %.2f vs %.2f." % [broken_loss, no_armor_loss])
	var effect_state: Dictionary = player.call("get_armor_effect_state")
	if float(effect_state.get("defense_bonus", -1.0)) != 0.0:
		_errors.append("Broken armor should expose zero defense after wear.")
	if float(effect_state.get("armor_protection_level", -1.0)) != 0.0:
		_errors.append("Broken armor should expose zero protection after wear.")
	_free_node(scene)


func _validate_worn_armor_preserves_in_death_loss() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	var player := scene.get_node_or_null("Player3D")
	var session := scene.get_node_or_null("RaidSession")
	if player == null:
		_errors.append("Gameplay scene should include Player3D for death-loss armor wear validation.")
		_free_node(scene)
		return
	if session == null:
		_errors.append("Gameplay scene should include RaidSession for death-loss armor wear validation.")
		_free_node(scene)
		return
	var equipment: RefCounted = player.call("get_equipment_model")
	if equipment == null:
		_errors.append("Player should expose equipment for death-loss armor wear validation.")
		_free_node(scene)
		return
	if not bool(equipment.call("equip_stack", &"armor", _durable_armor_stack(2, 80))):
		_errors.append("Validation should equip armor before lethal damage.")
		_free_node(scene)
		return
	player.call("apply_damage", _lethal_hit())
	if not bool(player.get("is_dead")):
		_errors.append("Lethal hit should kill the player for death-loss validation.")
	if not bool(session.get("dead")):
		_errors.append("Lethal hit should register a dead raid session.")
	var result: Dictionary = session.call("build_result")
	var lost_items: Array = result.get("lost_items", []) as Array
	if not _stack_has_durability(lost_items, LightArmor.resource_path, 1, 80):
		_errors.append("Raid death result should preserve post-hit worn armor durability: %s." % JSON.stringify(lost_items))
	if str(result.get("loss_rule", "")) != "backpack_equipment_lost_safe_pocket_returned":
		_errors.append("Raid death result should keep the existing backpack/equipment loss rule.")
	_free_node(scene)


func _validate_source_boundaries() -> void:
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["_apply_equipped_armor_durability_wear", "ItemDurabilityServiceScript.apply_use_wear", "get_active_armor_durability_state"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should bridge armor hit wear through %s." % required)
	var loss_source := FileAccess.get_file_as_string("res://scripts/raid/raid_loss_rules.gd")
	if not loss_source.contains("collect_equipment_items"):
		_errors.append("RaidLossRules should collect equipment items for worn armor death drops.")
	var durability_source := FileAccess.get_file_as_string("res://scripts/items/item_durability_service.gd")
	if not durability_source.contains("apply_use_wear"):
		_errors.append("ItemDurabilityService should own durability use-wear math.")
	for forbidden in ["ArmorMitigationServiceScript", "SaveGameManager", "StatusTopMenuPanel"]:
		if durability_source.contains(forbidden):
			_errors.append("ItemDurabilityService should not depend on armor combat/UI/save systems: %s." % forbidden)
	var equipment_source := FileAccess.get_file_as_string("res://scripts/equipment/equipment_model.gd")
	for forbidden in ["apply_damage", "DamageEvent", "ArmorMitigationServiceScript"]:
		if equipment_source.contains(forbidden):
			_errors.append("EquipmentModel should not own armor hit-wear behavior: %s." % forbidden)


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


func _lethal_hit() -> DamageEvent:
	var event: DamageEvent = DamageEventScript.new(999.0, null, null, [&"gun", &"validation", &"lethal"])
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


func _stack_has_durability(stacks: Array, item_path: String, current: int, maximum: int) -> bool:
	for entry in stacks:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stack := entry as Dictionary
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path and int(stack.get("current_durability", -1)) == current and int(stack.get("max_durability", -1)) == maximum:
			return true
	return false


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
