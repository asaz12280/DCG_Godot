class_name PlayerQuickSlotModel
extends RefCounted

const QUICK_KEY_MIN := 3
const QUICK_KEY_MAX := 8

var slots: Dictionary = {}


func assign_inventory_stack(key_number: int, stack_index: int, stack: Dictionary) -> bool:
	if not is_quick_key(key_number) or stack_index < 0 or stack.is_empty():
		return false
	_clear_existing_assignment_for_stack(stack_index)
	slots[key_number] = {
		"stack_index": stack_index,
		"item_id": str(stack.get("id", "")),
		"name_key": str(stack.get("name_key", "")),
	}
	return true


func clear_slot(key_number: int) -> bool:
	if not is_quick_key(key_number):
		return false
	slots.erase(key_number)
	return true


func resolve_stack_index(key_number: int, inventory_stacks: Array[Dictionary]) -> int:
	if not is_quick_key(key_number) or not slots.has(key_number):
		return -1
	var slot := slots.get(key_number, {}) as Dictionary
	var preferred_index := int(slot.get("stack_index", -1))
	var item_id := str(slot.get("item_id", ""))
	if preferred_index >= 0 and preferred_index < inventory_stacks.size():
		var preferred_stack := inventory_stacks[preferred_index]
		if str(preferred_stack.get("id", "")) == item_id and int(preferred_stack.get("quantity", 0)) > 0:
			return preferred_index
	for index in range(inventory_stacks.size()):
		var stack := inventory_stacks[index]
		if str(stack.get("id", "")) == item_id and int(stack.get("quantity", 0)) > 0:
			slots[key_number]["stack_index"] = index
			return index
	return -1


func get_slot_state(key_number: int, inventory_stacks: Array[Dictionary]) -> Dictionary:
	var stack_index := resolve_stack_index(key_number, inventory_stacks)
	if stack_index < 0:
		return {
			"key": key_number,
			"key_label": str(key_number),
			"assigned": false,
			"stack_index": -1,
			"stack": {},
		}
	return {
		"key": key_number,
		"key_label": str(key_number),
		"assigned": true,
		"stack_index": stack_index,
		"stack": inventory_stacks[stack_index].duplicate(true),
	}


func get_slots_state(inventory_stacks: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key_number in range(QUICK_KEY_MIN, QUICK_KEY_MAX + 1):
		result.append(get_slot_state(key_number, inventory_stacks))
	return result


func _clear_existing_assignment_for_stack(stack_index: int) -> void:
	for key_number in slots.keys():
		var slot := slots.get(key_number, {}) as Dictionary
		if int(slot.get("stack_index", -1)) == stack_index:
			slots.erase(key_number)


func is_quick_key(key_number: int) -> bool:
	return key_number >= QUICK_KEY_MIN and key_number <= QUICK_KEY_MAX
