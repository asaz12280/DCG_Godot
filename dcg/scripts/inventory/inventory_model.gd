class_name InventoryModel
extends RefCounted

signal changed

const ItemStackSorterScript := preload("res://scripts/inventory/item_stack_sorter.gd")
const ItemStackSaveCodecScript := preload("res://scripts/inventory/item_stack_save_codec.gd")

var slot_limit: int = 50
var stacks: Array[Dictionary] = []


func clear() -> void:
	if stacks.is_empty():
		return
	stacks.clear()
	changed.emit()


func setup(max_slots: int) -> void:
	slot_limit = maxi(max_slots, 0)
	if stacks.size() > slot_limit:
		stacks.resize(slot_limit)
	changed.emit()


func add_item(item_def: ItemDef, quantity: int = 1) -> bool:
	if item_def == null or quantity <= 0:
		return false

	var remaining := quantity
	var item_max_stack := item_def.get_max_stack()
	for index in range(stacks.size()):
		var stack := stacks[index]
		if item_max_stack <= 1:
			continue
		if stack.get("id") == item_def.id and int(stack.get("quantity", 1)) < int(stack.get("max_stack", 1)):
			var room := int(stack.get("max_stack", 1)) - int(stack.get("quantity", 1))
			var moved := mini(room, remaining)
			stack["quantity"] = int(stack.get("quantity", 1)) + moved
			stacks[index] = stack
			remaining -= moved
			if remaining <= 0:
				changed.emit()
				return true

	while remaining > 0 and stacks.size() < slot_limit:
		var moved_to_new_stack := mini(item_max_stack, remaining)
		stacks.append(item_def.to_stack(moved_to_new_stack))
		remaining -= moved_to_new_stack

	changed.emit()
	return remaining <= 0


func add_stack(stack: Dictionary) -> bool:
	if stack.is_empty():
		return false
	var item_def := _load_item_from_stack(stack)
	if item_def != null:
		if ItemStackSaveCodecScript.has_persistent_state(stack):
			if stacks.size() >= slot_limit:
				return false
			var saved_stack: Dictionary = ItemStackSaveCodecScript.stack_from_entry(stack, item_def, 1)
			stacks.append(saved_stack)
			changed.emit()
			return true
		return add_item(item_def, int(stack.get("quantity", 1)))
	if stacks.size() >= slot_limit:
		return false
	stacks.append(stack.duplicate(true))
	changed.emit()
	return true


func can_accept_stack(stack: Dictionary) -> bool:
	if stack.is_empty():
		return false
	var quantity := int(stack.get("quantity", 1))
	if quantity <= 0:
		return false
	var item_def := _load_item_from_stack(stack)
	if item_def == null:
		return stacks.size() < slot_limit

	var remaining := quantity
	var item_max_stack := item_def.get_max_stack()
	for existing_stack in stacks:
		if item_max_stack <= 1:
			break
		if existing_stack.get("id") != item_def.id:
			continue
		var max_stack := int(existing_stack.get("max_stack", 1))
		if max_stack <= 1:
			continue
		var room := max_stack - int(existing_stack.get("quantity", 1))
		if room <= 0:
			continue
		remaining -= mini(room, remaining)
		if remaining <= 0:
			return true

	var free_slots := maxi(slot_limit - stacks.size(), 0)
	while remaining > 0 and free_slots > 0:
		remaining -= mini(item_max_stack, remaining)
		free_slots -= 1
	return remaining <= 0


func remove_stack_at(index: int) -> Dictionary:
	if index < 0 or index >= stacks.size():
		return {}
	var stack := stacks[index].duplicate(true)
	stacks.remove_at(index)
	changed.emit()
	return stack


func replace_stack_at(index: int, stack: Dictionary) -> bool:
	if index < 0 or index >= stacks.size() or stack.is_empty():
		return false
	var item_def := _load_item_from_stack(stack)
	if item_def == null:
		return false
	var replacement: Dictionary = ItemStackSaveCodecScript.stack_from_entry(stack, item_def, int(stack.get("quantity", 1)))
	stacks[index] = replacement
	changed.emit()
	return true


func consume_stack_quantity(index: int, quantity: int) -> int:
	if index < 0 or index >= stacks.size() or quantity <= 0:
		return 0
	var stack := stacks[index]
	var current_quantity := int(stack.get("quantity", 1))
	var consumed := mini(current_quantity, quantity)
	if consumed <= 0:
		return 0
	var remaining := current_quantity - consumed
	if remaining <= 0:
		stacks.remove_at(index)
	else:
		stack["quantity"] = remaining
		stacks[index] = stack
	changed.emit()
	return consumed


func consume_item(item_def: ItemDef, quantity: int = 1) -> int:
	if item_def == null or quantity <= 0:
		return 0

	var remaining := quantity
	var index := stacks.size() - 1
	while index >= 0 and remaining > 0:
		var stack := stacks[index]
		if not _stack_matches_item(stack, item_def):
			index -= 1
			continue
		var current_quantity := int(stack.get("quantity", 1))
		var consumed := mini(current_quantity, remaining)
		current_quantity -= consumed
		remaining -= consumed
		if current_quantity <= 0:
			stacks.remove_at(index)
		else:
			stack["quantity"] = current_quantity
			stacks[index] = stack
		index -= 1

	var consumed_total := quantity - remaining
	if consumed_total > 0:
		changed.emit()
	return consumed_total


func split_stack_at(index: int, quantity: int) -> bool:
	if index < 0 or index >= stacks.size():
		return false
	if stacks.size() >= slot_limit:
		return false
	var stack := stacks[index]
	var current_quantity := int(stack.get("quantity", 1))
	var split_quantity := clampi(quantity, 1, current_quantity - 1)
	if current_quantity <= 1 or split_quantity <= 0:
		return false
	stack["quantity"] = current_quantity - split_quantity
	stacks[index] = stack

	var new_stack := stack.duplicate(true)
	new_stack["quantity"] = split_quantity
	stacks.append(new_stack)
	changed.emit()
	return true


func merge_or_swap_stack(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= stacks.size():
		return false
	if to_index < 0 or to_index >= stacks.size():
		return false
	if from_index == to_index:
		return false

	var from_stack := stacks[from_index]
	var to_stack := stacks[to_index]
	if _can_merge_stacks(from_stack, to_stack):
		var max_stack := int(to_stack.get("max_stack", 1))
		var to_quantity := int(to_stack.get("quantity", 1))
		var from_quantity := int(from_stack.get("quantity", 1))
		var room := max_stack - to_quantity
		if room <= 0:
			return false
		var moved := mini(room, from_quantity)
		to_stack["quantity"] = to_quantity + moved
		from_stack["quantity"] = from_quantity - moved
		stacks[to_index] = to_stack
		if int(from_stack.get("quantity", 0)) <= 0:
			stacks.remove_at(from_index)
		else:
			stacks[from_index] = from_stack
		changed.emit()
		return true

	if int(from_stack.get("catalog_number", 0)) != int(to_stack.get("catalog_number", 0)):
		stacks[from_index] = to_stack
		stacks[to_index] = from_stack
		changed.emit()
		return true

	return false


func _can_merge_stacks(from_stack: Dictionary, to_stack: Dictionary) -> bool:
	if int(from_stack.get("catalog_number", 0)) != int(to_stack.get("catalog_number", 0)):
		return false
	if str(from_stack.get("type", "")) == "key" or str(to_stack.get("type", "")) == "key":
		return false
	var max_stack := int(to_stack.get("max_stack", 1))
	if max_stack <= 1:
		return false
	if int(to_stack.get("quantity", 1)) >= max_stack:
		return false
	return true


func _stack_matches_item(stack: Dictionary, item_def: ItemDef) -> bool:
	if stack.is_empty() or item_def == null:
		return false
	if str(stack.get("resource_path", "")) == item_def.resource_path:
		return true
	return str(stack.get("id", "")) == str(item_def.id)


func organize(sort_mode: StringName = &"type") -> void:
	ItemStackSorterScript.sort_stacks_in_place(stacks, sort_mode)
	changed.emit()


func get_used_slots() -> int:
	return stacks.size()


func get_total_weight() -> float:
	var total := 0.0
	for stack in stacks:
		total += float(stack.get("weight", 0.0)) * float(stack.get("quantity", 1))
	return total


func get_display_items() -> Array[Dictionary]:
	return stacks.duplicate(true)


func _load_item_from_stack(stack: Dictionary) -> ItemDef:
	var item_path := ItemStackSaveCodecScript.get_item_path(stack)
	if item_path == "" or not ResourceLoader.exists(item_path):
		return null
	return load(item_path) as ItemDef
