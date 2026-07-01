class_name StashVendor
extends RefCounted

const SELLABLE_TYPES: Array[String] = ["loot", "valuable", "currency", "intel"]


static func sell_all_junk(stash_data: Array, starting_money: int = 0) -> Dictionary:
	var remaining_stash: Array[Dictionary] = []
	var sold_stacks: Array[Dictionary] = []
	var money_delta := 0

	for entry in stash_data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = (entry as Dictionary).duplicate(true)
		var item_def: ItemDef = _load_item_from_stack(stack)
		var quantity := maxi(int(stack.get("quantity", 0)), 0)
		if item_def == null or quantity <= 0:
			continue
		if _can_sell(item_def):
			var stack_value := maxi(item_def.value, 0) * quantity
			money_delta += stack_value
			sold_stacks.append({
				"item_path": item_def.resource_path,
				"quantity": quantity,
				"value": stack_value,
			})
		else:
			remaining_stash.append({
				"item_path": item_def.resource_path,
				"quantity": quantity,
			})

	return {
		"money": maxi(starting_money, 0) + money_delta,
		"money_delta": money_delta,
		"remaining_stash": remaining_stash,
		"sold_stacks": sold_stacks,
	}


static func get_sellable_value(stash_data: Array) -> int:
	var result: Dictionary = sell_all_junk(stash_data, 0)
	return int(result.get("money_delta", 0))


static func has_sellable_items(stash_data: Array) -> bool:
	return get_sellable_value(stash_data) > 0


static func _can_sell(item_def: ItemDef) -> bool:
	if item_def == null:
		return false
	if item_def.is_quest_item:
		return false
	if item_def.value <= 0:
		return false
	return SELLABLE_TYPES.has(item_def.item_type)


static func _load_item_from_stack(stack: Dictionary) -> ItemDef:
	var item_path := str(stack.get("item_path", stack.get("resource_path", "")))
	if item_path == "" or not ResourceLoader.exists(item_path):
		return null
	return load(item_path) as ItemDef
