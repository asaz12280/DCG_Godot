class_name RaidLoadoutTransfer
extends RefCounted


static func build_from_player(player: Node) -> Dictionary:
	if player == null:
		return {}
	var backpack_data := _inventory_to_data(player.call("get_inventory_model") if player.has_method("get_inventory_model") else null)
	var safe_pocket_data := _inventory_to_data(player.call("get_safe_pocket_model") if player.has_method("get_safe_pocket_model") else null)
	var equipment_data := _equipment_to_data(player.call("get_equipment_model") if player.has_method("get_equipment_model") else null)
	return {
		"version": 1,
		"source": "base_3d",
		"backpack": backpack_data,
		"safe_pocket": safe_pocket_data,
		"equipment": equipment_data,
	}


static func apply_to_player(player: Node, loadout: Dictionary) -> bool:
	if player == null or loadout.is_empty():
		return false
	var inventory: Variant = player.call("get_inventory_model") if player.has_method("get_inventory_model") else null
	var safe_pocket: Variant = player.call("get_safe_pocket_model") if player.has_method("get_safe_pocket_model") else null
	var equipment: Variant = player.call("get_equipment_model") if player.has_method("get_equipment_model") else null
	if inventory == null or equipment == null:
		return false

	var loaded_all := true
	if inventory.has_method("clear"):
		inventory.call("clear")
	if inventory.has_method("setup") and player.has_method("get_total_backpack_slots"):
		inventory.call("setup", int(player.call("get_total_backpack_slots")))
	loaded_all = _load_inventory_data(inventory, loadout.get("backpack", [])) and loaded_all
	if safe_pocket != null:
		if safe_pocket.has_method("clear"):
			safe_pocket.call("clear")
		if safe_pocket.has_method("setup") and player.has_method("get_total_safe_pocket_slots"):
			safe_pocket.call("setup", int(player.call("get_total_safe_pocket_slots")))
		loaded_all = _load_inventory_data(safe_pocket, loadout.get("safe_pocket", [])) and loaded_all

	if equipment.has_method("load_save_data"):
		loaded_all = bool(equipment.call("load_save_data", loadout.get("equipment", {}))) and loaded_all
	return loaded_all


static func get_backpack_data(loadout: Dictionary) -> Array:
	var value: Variant = loadout.get("backpack", [])
	return value as Array if typeof(value) == TYPE_ARRAY else []


static func get_equipment_data(loadout: Dictionary) -> Dictionary:
	var value: Variant = loadout.get("equipment", {})
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func get_safe_pocket_data(loadout: Dictionary) -> Array:
	var value: Variant = loadout.get("safe_pocket", [])
	return value as Array if typeof(value) == TYPE_ARRAY else []


static func _inventory_to_data(inventory: Variant) -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	if inventory == null:
		return data
	var stacks: Array = []
	if inventory.has_method("get_display_items"):
		stacks = inventory.call("get_display_items")
	elif "stacks" in inventory:
		stacks = inventory.get("stacks")
	for value in stacks:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := value as Dictionary
		var item_path := str(stack.get("resource_path", stack.get("item_path", "")))
		var quantity := int(stack.get("quantity", 1))
		if item_path == "" or quantity <= 0:
			continue
		data.append({
			"item_path": item_path,
			"quantity": quantity,
		})
	return data


static func _equipment_to_data(equipment: Variant) -> Dictionary:
	if equipment == null or not equipment.has_method("to_save_data"):
		return {"slots": {}}
	return equipment.call("to_save_data")


static func _load_inventory_data(inventory: Variant, raw_data: Variant) -> bool:
	if typeof(raw_data) != TYPE_ARRAY:
		return false
	var loaded_all := true
	for value in raw_data as Array:
		if typeof(value) != TYPE_DICTIONARY:
			loaded_all = false
			continue
		var entry := value as Dictionary
		var item_path := str(entry.get("item_path", entry.get("resource_path", "")))
		var quantity := int(entry.get("quantity", 0))
		if item_path == "" or quantity <= 0 or not ResourceLoader.exists(item_path):
			loaded_all = false
			continue
		var item := load(item_path) as ItemDef
		if item == null or not bool(inventory.call("add_item", item, quantity)):
			loaded_all = false
	return loaded_all
