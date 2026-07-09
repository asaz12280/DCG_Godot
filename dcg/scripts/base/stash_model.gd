class_name StashModel
extends RefCounted

signal changed

const ItemStackSorterScript := preload("res://scripts/inventory/item_stack_sorter.gd")
const ItemStackSaveCodecScript := preload("res://scripts/inventory/item_stack_save_codec.gd")

var stacks: Array[Dictionary] = []


func clear() -> void:
	if stacks.is_empty():
		return
	stacks.clear()
	changed.emit()


func add_item(item_def: ItemDef, quantity: int = 1) -> bool:
	if item_def == null or quantity <= 0:
		return false

	var remaining := quantity
	var item_max_stack := item_def.get_max_stack()
	for index in range(stacks.size()):
		var stack := stacks[index]
		if not _can_merge_item(stack, item_def):
			continue
		var room := int(stack.get("max_stack", 1)) - int(stack.get("quantity", 1))
		var moved := mini(room, remaining)
		stack["quantity"] = int(stack.get("quantity", 1)) + moved
		stacks[index] = stack
		remaining -= moved
		if remaining <= 0:
			changed.emit()
			return true

	while remaining > 0:
		var moved_to_new_stack := mini(item_max_stack, remaining)
		stacks.append(item_def.to_stack(moved_to_new_stack))
		remaining -= moved_to_new_stack

	changed.emit()
	return true


func add_stack(stack: Dictionary) -> bool:
	var item_def := _load_item_from_stack(stack)
	if item_def == null:
		return false
	if ItemStackSaveCodecScript.has_persistent_state(stack):
		stacks.append(ItemStackSaveCodecScript.stack_from_entry(stack, item_def, 1))
		changed.emit()
		return true
	return add_item(item_def, int(stack.get("quantity", 1)))


func remove_item(item_def: ItemDef, quantity: int = 1) -> bool:
	if item_def == null or quantity <= 0:
		return false
	if get_item_quantity(item_def) < quantity:
		return false

	var remaining := quantity
	var index := stacks.size() - 1
	while index >= 0 and remaining > 0:
		var stack := stacks[index]
		if str(stack.get("resource_path", "")) != item_def.resource_path:
			index -= 1
			continue
		var stack_quantity := int(stack.get("quantity", 1))
		var removed := mini(stack_quantity, remaining)
		stack_quantity -= removed
		remaining -= removed
		if stack_quantity <= 0:
			stacks.remove_at(index)
		else:
			stack["quantity"] = stack_quantity
			stacks[index] = stack
		index -= 1

	changed.emit()
	return true


func remove_stack_at(index: int) -> Dictionary:
	if index < 0 or index >= stacks.size():
		return {}
	var stack := stacks[index].duplicate(true)
	stacks.remove_at(index)
	changed.emit()
	return stack


func get_stacks() -> Array[Dictionary]:
	return stacks.duplicate(true)


func get_stack_count() -> int:
	return stacks.size()


func organize(sort_mode: StringName = &"type") -> void:
	ItemStackSorterScript.sort_stacks_in_place(stacks, sort_mode)
	changed.emit()


func get_item_quantity(item_def: ItemDef) -> int:
	if item_def == null:
		return 0
	var total := 0
	for stack in stacks:
		if str(stack.get("resource_path", "")) == item_def.resource_path:
			total += int(stack.get("quantity", 1))
	return total


func to_save_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for stack in stacks:
		var entry: Dictionary = ItemStackSaveCodecScript.to_save_entry(stack)
		if entry.is_empty():
			continue
		data.append(entry)
	return data


func load_save_data(data: Array) -> bool:
	stacks.clear()
	var loaded_all := true
	for entry in data:
		if typeof(entry) != TYPE_DICTIONARY:
			loaded_all = false
			continue
		var item_path := str(entry.get("item_path", ""))
		var quantity := int(entry.get("quantity", 0))
		if not ResourceLoader.exists(item_path):
			loaded_all = false
			continue
		var item_def := load(item_path) as ItemDef
		if item_def == null or quantity <= 0:
			loaded_all = false
			continue
		if ItemStackSaveCodecScript.has_persistent_state(entry as Dictionary):
			stacks.append(ItemStackSaveCodecScript.stack_from_entry(entry as Dictionary, item_def, 1))
		else:
			add_item(item_def, quantity)
	changed.emit()
	return loaded_all


func _can_merge_item(stack: Dictionary, item_def: ItemDef) -> bool:
	if str(stack.get("resource_path", "")) != item_def.resource_path:
		return false
	if item_def.get_max_stack() <= 1:
		return false
	var max_stack := int(stack.get("max_stack", 1))
	if max_stack <= 1:
		return false
	return int(stack.get("quantity", 1)) < max_stack


func _load_item_from_stack(stack: Dictionary) -> ItemDef:
	var item_path := ItemStackSaveCodecScript.get_item_path(stack)
	if item_path == "":
		return null
	return load(item_path) as ItemDef
