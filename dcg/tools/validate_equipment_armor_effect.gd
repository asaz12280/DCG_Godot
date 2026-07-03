extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const Armor := preload("res://data/items/armor/light_armor.tres")
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_armor_equipment_effect()
	_validate_boundaries()
	if _errors.is_empty():
		print("[equipment_armor_effect] OK equip=armor damage=reduced ui=visible boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_armor_equipment_effect() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame

	var player := scene.get_node_or_null("Player3D")
	var status_panel := scene.get_node_or_null("HUD/StatusTopMenuPanel")
	if player == null or status_panel == null:
		_errors.append("Gameplay scene should include Player3D and StatusTopMenuPanel.")
		_free_node(scene)
		return
	if not player.has_method("add_item_resource") or not player.has_method("equip_inventory_stack"):
		_errors.append("Player should expose inventory-to-equipment flow for armor validation.")
		_free_node(scene)
		return

	var base_defense := float(player.call("get_total_defense"))
	var health_before_no_armor := float(player.get("health"))
	player.call("apply_damage", DamageEventScript.new(8.0, null, null, [&"validation"]))
	var no_armor_loss := health_before_no_armor - float(player.get("health"))
	player.call("restore_health_to_full")

	if not player.call("add_item_resource", Armor, 1):
		_errors.append("Player backpack should accept light armor for equipment.")
	var armor_index := _find_stack_index(player, 8)
	if armor_index < 0:
		_errors.append("Light armor should be visible in backpack before equipment.")
	elif not bool(player.call("equip_inventory_stack", armor_index, &"armor")):
		_errors.append("Light armor should equip into the armor slot.")

	var equipment: RefCounted = player.call("get_equipment_model")
	var armor_stack: Dictionary = equipment.call("get_slot", &"armor") if equipment != null else {}
	if int(armor_stack.get("catalog_number", 0)) != 8:
		_errors.append("Armor equipment slot should contain No.8 light armor.")
	var armor_defense := float(player.call("get_total_defense"))
	if armor_defense <= base_defense:
		_errors.append("Equipped armor should increase player total defense.")
	var effect_state: Dictionary = player.call("get_armor_effect_state")
	if not bool(effect_state.get("equipped", false)) or float(effect_state.get("defense_bonus", 0.0)) <= 0.0:
		_errors.append("Player armor effect state should expose equipped armor and defense bonus.")

	var health_before_armor := float(player.get("health"))
	player.call("apply_damage", DamageEventScript.new(8.0, null, null, [&"validation"]))
	var armored_loss := health_before_armor - float(player.get("health"))
	if armored_loss >= no_armor_loss:
		_errors.append("Armor should reduce incoming damage compared with no armor.")
	if roundi(armored_loss) != 4:
		_errors.append("Light armor should reduce an 8 damage hit to 4 damage, got %.2f." % armored_loss)

	status_panel.call("open_status")
	var display_state: Dictionary = status_panel.call("get_display_state")
	var equipment_text := str(display_state.get("equipment", ""))
	if not equipment_text.contains("護甲") or not equipment_text.contains("防護效果") or not equipment_text.contains("-4"):
		_errors.append("Status panel should visibly explain the equipped armor damage reduction.")

	_free_node(scene)


func _find_stack_index(player: Node, catalog_number: int) -> int:
	var inventory: RefCounted = player.call("get_inventory_model")
	if inventory == null:
		return -1
	var stacks: Array = inventory.get("stacks")
	for index in range(stacks.size()):
		var stack: Dictionary = stacks[index]
		if int(stack.get("catalog_number", 0)) == catalog_number:
			return index
	return -1


func _validate_boundaries() -> void:
	var item_source := FileAccess.get_file_as_string("res://scripts/items/item_def.gd")
	if not item_source.contains("defense_bonus"):
		_errors.append("ItemDef should expose a data-driven defense_bonus for armor.")
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["get_equipment_defense_bonus", "get_armor_effect_state", "defense_bonus"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should compute armor defense through %s." % required)
	var equipment_source := FileAccess.get_file_as_string("res://scripts/equipment/equipment_model.gd")
	for forbidden in ["apply_damage", "DamageEvent", "StatusTopMenuPanel", "InventoryEquipmentUI"]:
		if equipment_source.contains(forbidden):
			_errors.append("EquipmentModel should not own armor combat/UI behavior: %s." % forbidden)
	var status_source := FileAccess.get_file_as_string("res://scripts/ui/status_top_menu_panel.gd")
	for forbidden in ["apply_damage", "DamageEvent", "equip_inventory_stack", "defense_bonus ="]:
		if status_source.contains(forbidden):
			_errors.append("StatusTopMenuPanel should display armor effect without owning combat/equipment mutation: %s." % forbidden)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
