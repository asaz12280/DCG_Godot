class_name RaidLossRules
extends RefCounted

const ItemStackSaveCodecScript := preload("res://scripts/inventory/item_stack_save_codec.gd")


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
	return _normalize_stacks(inventory.get_display_items())


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
		var entry: Dictionary = ItemStackSaveCodecScript.to_save_entry(stack)
		if entry.is_empty():
			continue
		normalized_items.append(entry)
	return normalized_items
