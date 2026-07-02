class_name ContainerInventoryModel
extends RefCounted

signal changed

var capacity: int = 4
var slots: Array[Dictionary] = []


func _init(slot_count: int = 4) -> void:
	setup(slot_count)


func setup(slot_count: int = 4) -> void:
	capacity = maxi(slot_count, 0)
	var resized_slots: Array[Dictionary] = []
	for index in range(capacity):
		if index < slots.size():
			resized_slots.append(slots[index].duplicate(true))
		else:
			resized_slots.append({})
	slots = resized_slots
	changed.emit()


func clear() -> void:
	if _is_empty():
		return
	for index in range(slots.size()):
		slots[index] = {}
	changed.emit()


func get_capacity() -> int:
	return capacity


func get_used_slots() -> int:
	var used := 0
	for stack in slots:
		if not stack.is_empty():
			used += 1
	return used


func get_empty_slots() -> int:
	return maxi(capacity - get_used_slots(), 0)


func get_slots() -> Array[Dictionary]:
	return slots.duplicate(true)


func get_slot(index: int) -> Dictionary:
	if not is_valid_slot(index):
		return {}
	return slots[index].duplicate(true)


func is_valid_slot(index: int) -> bool:
	return index >= 0 and index < slots.size()


func add_item(item_def: ItemDef, quantity: int = 1) -> bool:
	if item_def == null or quantity <= 0:
		return false

	var draft: Array[Dictionary] = slots.duplicate(true)
	var remaining := quantity
	remaining = _fill_existing_stacks(draft, item_def, remaining)
	remaining = _fill_empty_slots(draft, item_def, remaining)
	if remaining > 0:
		return false

	slots = draft
	changed.emit()
	return true


func add_stack(stack: Dictionary) -> bool:
	var item_def := _load_item_from_stack(stack)
	if item_def == null:
		return false
	return add_item(item_def, int(stack.get("quantity", 1)))


func remove_from_slot(index: int, quantity: int = 1) -> Dictionary:
	if not is_valid_slot(index) or quantity <= 0:
		return {}
	var stack := slots[index]
	if stack.is_empty():
		return {}

	var current_quantity := int(stack.get("quantity", 1))
	var removed_quantity := mini(quantity, current_quantity)
	var removed_stack := stack.duplicate(true)
	removed_stack["quantity"] = removed_quantity

	current_quantity -= removed_quantity
	if current_quantity <= 0:
		slots[index] = {}
	else:
		stack["quantity"] = current_quantity
		slots[index] = stack
	changed.emit()
	return removed_stack


func clear_slot(index: int) -> bool:
	if not is_valid_slot(index) or slots[index].is_empty():
		return false
	slots[index] = {}
	changed.emit()
	return true


func to_save_data() -> Dictionary:
	var saved_slots: Array[Dictionary] = []
	for stack in slots:
		if stack.is_empty():
			saved_slots.append({})
			continue
		var item_path := str(stack.get("resource_path", ""))
		var quantity := int(stack.get("quantity", 1))
		if item_path == "" or quantity <= 0:
			saved_slots.append({})
			continue
		saved_slots.append({
			"item_path": item_path,
			"quantity": quantity,
		})
	return {
		"capacity": capacity,
		"slots": saved_slots,
	}


func load_save_data(data: Dictionary) -> bool:
	var loaded_all := true
	var loaded_capacity := maxi(int(data.get("capacity", capacity)), 0)
	var saved_slots: Array = data.get("slots", [])
	capacity = loaded_capacity
	slots.clear()

	for index in range(capacity):
		slots.append({})
		if typeof(saved_slots) != TYPE_ARRAY or index >= saved_slots.size():
			continue
		var entry: Variant = saved_slots[index]
		if typeof(entry) != TYPE_DICTIONARY or (entry as Dictionary).is_empty():
			continue
		var entry_dictionary := entry as Dictionary
		var item_path := str(entry_dictionary.get("item_path", ""))
		var quantity := int(entry_dictionary.get("quantity", 0))
		if item_path == "" or not ResourceLoader.exists(item_path) or quantity <= 0:
			loaded_all = false
			continue
		var item_def := load(item_path) as ItemDef
		if item_def == null:
			loaded_all = false
			continue
		var stack_quantity := mini(quantity, maxi(item_def.max_stack, 1))
		slots[index] = item_def.to_stack(stack_quantity)
		if stack_quantity != quantity:
			loaded_all = false

	changed.emit()
	return loaded_all


func _fill_existing_stacks(draft: Array[Dictionary], item_def: ItemDef, quantity: int) -> int:
	var remaining := quantity
	for index in range(draft.size()):
		if remaining <= 0:
			break
		var stack := draft[index]
		if not _can_merge_item(stack, item_def):
			continue
		var room := int(stack.get("max_stack", 1)) - int(stack.get("quantity", 1))
		var moved := mini(room, remaining)
		stack["quantity"] = int(stack.get("quantity", 1)) + moved
		draft[index] = stack
		remaining -= moved
	return remaining


func _fill_empty_slots(draft: Array[Dictionary], item_def: ItemDef, quantity: int) -> int:
	var remaining := quantity
	for index in range(draft.size()):
		if remaining <= 0:
			break
		if not draft[index].is_empty():
			continue
		var moved_to_new_stack := mini(maxi(item_def.max_stack, 1), remaining)
		draft[index] = item_def.to_stack(moved_to_new_stack)
		remaining -= moved_to_new_stack
	return remaining


func _can_merge_item(stack: Dictionary, item_def: ItemDef) -> bool:
	if stack.is_empty():
		return false
	if str(stack.get("resource_path", "")) != item_def.resource_path:
		return false
	var max_stack := int(stack.get("max_stack", 1))
	if max_stack <= 1:
		return false
	return int(stack.get("quantity", 1)) < max_stack


func _load_item_from_stack(stack: Dictionary) -> ItemDef:
	var item_path := str(stack.get("resource_path", stack.get("item_path", "")))
	if item_path == "" or not ResourceLoader.exists(item_path):
		return null
	return load(item_path) as ItemDef


func _is_empty() -> bool:
	for stack in slots:
		if not stack.is_empty():
			return false
	return true
