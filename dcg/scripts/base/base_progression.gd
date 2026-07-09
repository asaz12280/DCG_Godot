class_name BaseProgression
extends RefCounted

const WORKBENCH_LEVEL_1 := &"workbench_level_1"
const WORKBENCH_FIX_STATION := &"workbench_fix_station"
const WORKBENCH_DISASSEMBLE_STATION := &"workbench_disassemble_station"
const STORAGE_EXPANSION_LEVEL_1 := &"storage_expansion_level_1"
const STORAGE_EXPANSION_LEVEL_2 := &"storage_expansion_level_2"


static func can_purchase_upgrade(save_data: Dictionary, upgrade_def: Resource) -> Dictionary:
	if upgrade_def == null or not upgrade_def.has_method("is_valid") or not upgrade_def.is_valid():
		return {"can_purchase": false, "reason": "invalid_upgrade"}
	var upgrade_id := StringName(str(upgrade_def.get("id")))
	if is_upgrade_purchased(save_data, upgrade_id):
		return {"can_purchase": false, "reason": "already_owned"}
	for required_upgrade_id in _required_upgrade_ids(upgrade_def):
		if not is_upgrade_purchased(save_data, required_upgrade_id):
			return {"can_purchase": false, "reason": "missing_prerequisite", "upgrade_id": str(required_upgrade_id)}
	if int(save_data.get("money", 0)) < int(upgrade_def.get("money_cost")):
		return {"can_purchase": false, "reason": "missing_money"}
	var stash: Array = _stash_array(save_data.get("stash", []))
	var item_costs: Array = _item_costs(upgrade_def)
	for cost in item_costs:
		var item_path := str(cost.get("item_path", ""))
		var required := int(cost.get("quantity", 0))
		if _stash_quantity(stash, item_path) < required:
			return {"can_purchase": false, "reason": "missing_items", "item_path": item_path}
	return {"can_purchase": true, "reason": "ok"}


static func purchase_upgrade(save_data: Dictionary, upgrade_def: Resource) -> Dictionary:
	var check: Dictionary = can_purchase_upgrade(save_data, upgrade_def)
	if not bool(check.get("can_purchase", false)):
		return {
			"success": false,
			"reason": str(check.get("reason", "unknown")),
			"save_data": save_data.duplicate(true),
		}

	var updated := save_data.duplicate(true)
	var stash: Array = _stash_array(updated.get("stash", []))
	var item_costs: Array = _item_costs(upgrade_def)
	for cost in item_costs:
		stash = _remove_item_cost(stash, str(cost.get("item_path", "")), int(cost.get("quantity", 0)))
	updated["stash"] = stash
	updated["money"] = maxi(int(updated.get("money", 0)) - int(upgrade_def.get("money_cost")), 0)
	var upgrades: Dictionary = _upgrades_dict(updated.get("base_upgrades", {}))
	upgrades[str(upgrade_def.get("id"))] = {
		"purchased": true,
		"required_upgrade_ids": _string_array(_required_upgrade_ids(upgrade_def)),
		"starter_ammo_bonus": int(upgrade_def.get("starter_ammo_bonus")),
		"storage_capacity_bonus": int(upgrade_def.get("storage_capacity_bonus")),
	}
	updated["base_upgrades"] = upgrades
	return {
		"success": true,
		"reason": "ok",
		"save_data": updated,
	}


static func is_upgrade_purchased(save_data: Dictionary, upgrade_id: StringName) -> bool:
	var upgrades: Dictionary = _upgrades_dict(save_data.get("base_upgrades", {}))
	var value: Variant = upgrades.get(str(upgrade_id), false)
	if typeof(value) == TYPE_DICTIONARY:
		return bool((value as Dictionary).get("purchased", false))
	return bool(value)


static func get_starter_ammo_bonus(save_data: Dictionary) -> int:
	var upgrades: Dictionary = _upgrades_dict(save_data.get("base_upgrades", {}))
	var bonus := 0
	for value in upgrades.values():
		if typeof(value) == TYPE_DICTIONARY and bool((value as Dictionary).get("purchased", false)):
			bonus += int((value as Dictionary).get("starter_ammo_bonus", 0))
	return maxi(bonus, 0)


static func get_storage_capacity_bonus(save_data: Dictionary) -> int:
	var upgrades: Dictionary = _upgrades_dict(save_data.get("base_upgrades", {}))
	var bonus := 0
	for value in upgrades.values():
		if typeof(value) == TYPE_DICTIONARY and bool((value as Dictionary).get("purchased", false)):
			bonus += int((value as Dictionary).get("storage_capacity_bonus", 0))
	return maxi(bonus, 0)


static func get_stash_capacity(save_data: Dictionary, base_capacity: int) -> int:
	return maxi(base_capacity, 0) + get_storage_capacity_bonus(save_data)


static func describe_cost(upgrade_def: Resource) -> String:
	if upgrade_def == null:
		return ""
	var parts: Array[String] = []
	var money_cost := int(upgrade_def.get("money_cost"))
	if money_cost > 0:
		parts.append("$%d" % money_cost)
	var item_costs: Array = _item_costs(upgrade_def)
	for cost in item_costs:
		parts.append("%s x%d" % [_item_name(str(cost.get("item_path", ""))), int(cost.get("quantity", 0))])
	return ", ".join(parts)


static func _stash_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _upgrades_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


static func _item_costs(upgrade_def: Resource) -> Array:
	if upgrade_def == null:
		return []
	var value: Variant = upgrade_def.get("item_costs")
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _required_upgrade_ids(upgrade_def: Resource) -> Array[StringName]:
	var result: Array[StringName] = []
	if upgrade_def == null:
		return result
	var value: Variant = upgrade_def.get("required_upgrade_ids")
	if typeof(value) != TYPE_ARRAY:
		return result
	for id_value in (value as Array):
		var upgrade_id := StringName(str(id_value))
		if upgrade_id != &"":
			result.append(upgrade_id)
	return result


static func _string_array(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


static func _stash_quantity(stash: Array, item_path: String) -> int:
	var total := 0
	for entry in stash:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str((entry as Dictionary).get("item_path", "")) == item_path:
			total += int((entry as Dictionary).get("quantity", 0))
	return total


static func _remove_item_cost(stash: Array, item_path: String, quantity: int) -> Array:
	var remaining := quantity
	var result: Array[Dictionary] = []
	for entry in stash:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = (entry as Dictionary).duplicate(true)
		var stack_path := str(stack.get("item_path", ""))
		var stack_quantity := int(stack.get("quantity", 0))
		if stack_path == item_path and remaining > 0:
			var removed := mini(stack_quantity, remaining)
			stack_quantity -= removed
			remaining -= removed
		if stack_quantity > 0:
			result.append({"item_path": stack_path, "quantity": stack_quantity})
	return result


static func _item_name(item_path: String) -> String:
	if item_path == "" or not ResourceLoader.exists(item_path):
		return "Unknown"
	var item_def := load(item_path) as ItemDef
	if item_def == null:
		return "Unknown"
	var name_key := str(item_def.name_key)
	if name_key != "":
		var translated := TranslationServer.translate(name_key)
		if translated != name_key and translated != "":
			return translated
	return item_def.display_name if item_def.display_name != "" else str(item_def.id)
