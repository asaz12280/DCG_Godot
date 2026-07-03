class_name RaidLossRules
extends RefCounted


static func build_death_context_from_player(player: Node) -> Dictionary:
	var lost_items := collect_backpack_items(player)
	lost_items.append_array(collect_equipment_items(player))
	return {
		"lost_items": lost_items,
		"kept_safe_pocket_items": collect_safe_pocket_items(player),
		"loss_rule": "backpack_equipment_lost_safe_pocket_returned",
	}


static func collect_backpack_items(player: Node) -> Array[Dictionary]:
	if player == null or not player.has_method("get_inventory_model"):
		return []
	var inventory: Variant = player.get_inventory_model()
	if inventory == null or not inventory.has_method("get_display_items"):
		return []

	var lost_items: Array[Dictionary] = []
	for stack in inventory.get_display_items():
		if typeof(stack) != TYPE_DICTIONARY:
			continue
		var item_path := str(stack.get("resource_path", stack.get("item_path", "")))
		var quantity := int(stack.get("quantity", 1))
		if item_path == "" or quantity <= 0:
			continue
		lost_items.append({
			"item_path": item_path,
			"quantity": quantity,
		})
	return lost_items


static func collect_safe_pocket_items(player: Node) -> Array[Dictionary]:
	if player != null and player.has_method("get_safe_pocket_model"):
		var safe_pocket: Variant = player.get_safe_pocket_model()
		if safe_pocket != null and safe_pocket.has_method("get_display_items"):
			return _normalize_stacks(safe_pocket.get_display_items())
	return []


static func collect_equipment_items(player: Node) -> Array[Dictionary]:
	if player == null or not player.has_method("get_equipment_model"):
		return []
	var equipment: Variant = player.get_equipment_model()
	if equipment == null or not equipment.has_method("get_slots"):
		return []
	var stacks: Array[Dictionary] = []
	var slots: Dictionary = equipment.call("get_slots")
	for stack in slots.values():
		if typeof(stack) == TYPE_DICTIONARY:
			stacks.append((stack as Dictionary).duplicate(true))
	return _normalize_stacks(stacks)


static func _normalize_stacks(stacks: Variant) -> Array[Dictionary]:
	if typeof(stacks) != TYPE_ARRAY:
		return []
	var normalized_items: Array[Dictionary] = []
	for stack in stacks as Array:
		if typeof(stack) != TYPE_DICTIONARY:
			continue
		var item_path := str(stack.get("resource_path", stack.get("item_path", "")))
		var quantity := int(stack.get("quantity", 1))
		if item_path == "" or quantity <= 0:
			continue
		normalized_items.append({
			"item_path": item_path,
			"quantity": quantity,
		})
	return normalized_items
