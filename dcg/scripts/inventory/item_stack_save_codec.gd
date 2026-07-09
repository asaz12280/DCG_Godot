class_name ItemStackSaveCodec
extends RefCounted

const DURABILITY_KEYS := [
	"current_durability",
	"max_durability",
	"original_max_durability",
	"repair_max_durability_loss",
	"durability_penalty_ratio",
	"durability_wear_progress",
]

const WEAPON_MOD_KEYS := [
	"weapon_mods",
]


static func get_item_path(stack: Dictionary) -> String:
	var resource_path := str(stack.get("resource_path", ""))
	if resource_path != "":
		return resource_path
	return str(stack.get("item_path", ""))


static func has_durability_data(stack: Dictionary) -> bool:
	if bool(stack.get("has_durability", false)):
		return true
	for key in ["current_durability", "max_durability", "original_max_durability", "repair_max_durability_loss"]:
		if int(stack.get(key, 0)) > 0:
			return true
	return false


static func has_persistent_state(stack: Dictionary) -> bool:
	if has_durability_data(stack):
		return true
	for key in WEAPON_MOD_KEYS:
		if not stack.has(key):
			continue
		var value: Variant = stack[key]
		if typeof(value) == TYPE_DICTIONARY and not (value as Dictionary).is_empty():
			return true
		if typeof(value) != TYPE_DICTIONARY and value != null:
			return true
	return false


static func to_save_entry(stack: Dictionary) -> Dictionary:
	var item_path := get_item_path(stack)
	var quantity := int(stack.get("quantity", 1))
	if item_path == "" or quantity <= 0:
		return {}
	var entry := {
		"item_path": item_path,
		"quantity": quantity,
	}
	copy_persistent_state(stack, entry)
	return entry


static func stack_from_entry(entry: Dictionary, item_def: ItemDef, quantity_override: int = -1) -> Dictionary:
	if item_def == null:
		return {}
	var quantity := quantity_override if quantity_override > 0 else int(entry.get("quantity", 1))
	var stack := item_def.to_stack(maxi(quantity, 1))
	copy_persistent_state(entry, stack)
	return stack


static func copy_persistent_state(source: Dictionary, target: Dictionary) -> Dictionary:
	if has_durability_data(source):
		for key in DURABILITY_KEYS:
			if source.has(key):
				target[key] = source[key]
	for key in WEAPON_MOD_KEYS:
		if source.has(key):
			target[key] = (source[key] as Dictionary).duplicate(true) if typeof(source[key]) == TYPE_DICTIONARY else source[key]
	return target
