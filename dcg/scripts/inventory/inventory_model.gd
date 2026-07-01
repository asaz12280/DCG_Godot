class_name InventoryModel
extends RefCounted

signal changed

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
	for index in range(stacks.size()):
		var stack := stacks[index]
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
		var moved_to_new_stack := mini(maxi(item_def.max_stack, 1), remaining)
		stacks.append(item_def.to_stack(moved_to_new_stack))
		remaining -= moved_to_new_stack

	changed.emit()
	return remaining <= 0


func add_stack(stack: Dictionary) -> bool:
	if stacks.size() >= slot_limit:
		return false
	stacks.append(stack.duplicate(true))
	changed.emit()
	return true


func remove_stack_at(index: int) -> Dictionary:
	if index < 0 or index >= stacks.size():
		return {}
	var stack := stacks[index].duplicate(true)
	stacks.remove_at(index)
	changed.emit()
	return stack


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
	var max_stack := int(to_stack.get("max_stack", 1))
	if max_stack <= 1:
		return false
	if int(to_stack.get("quantity", 1)) >= max_stack:
		return false
	return true


func organize() -> void:
	stacks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var type_a := str(a.get("type", ""))
		var type_b := str(b.get("type", ""))
		if type_a == type_b:
			return str(a.get("name_key", a.get("name", ""))) < str(b.get("name_key", b.get("name", "")))
		return type_a < type_b
	)
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
