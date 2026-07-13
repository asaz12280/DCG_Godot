class_name PlayerQuickSlotController3D
extends RefCounted

const ItemConsumableServiceScript := preload("res://scripts/items/item_consumable_service.gd")

var _owner: Node
var _model: RefCounted
var _inventory: InventoryModel


func _init(owner: Node, model: RefCounted, inventory: InventoryModel) -> void:
	_owner = owner
	_model = model
	_inventory = inventory


func get_quick_bar_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		_owner.call("_quick_weapon_slot_state", 1, &"primary_weapon"),
		_owner.call("_quick_weapon_slot_state", 2, &"sidearm"),
		_owner.call("_quick_weapon_slot_state", 0, &"melee", "V"),
	]
	if _model == null:
		return result
	var slots_state: Variant = _model.call("get_slots_state", _inventory.stacks)
	if typeof(slots_state) != TYPE_ARRAY:
		return result
	for slot_state in slots_state as Array:
		if typeof(slot_state) != TYPE_DICTIONARY:
			continue
		var state: Dictionary = (slot_state as Dictionary).duplicate(true)
		state["kind"] = "item"
		var key_value := int(state.get("key", -1))
		state["active"] = key_value == int(_owner.get("_selected_quick_item_key")) and is_slot_still_valid(key_value)
		state["display_text"] = _owner.call("_stack_display_name", state.get("stack", {}) as Dictionary)
		result.append(state)
	return result


func get_quick_slot_state(key_number: int) -> Dictionary:
	var quick_state: Variant = _model.call("get_slots_state", _inventory.stacks)
	if typeof(quick_state) != TYPE_ARRAY:
		return {}
	for raw_state in quick_state as Array:
		if typeof(raw_state) != TYPE_DICTIONARY:
			continue
		var state := raw_state as Dictionary
		if int(state.get("key", -1)) == int(key_number):
			return state.duplicate(true)
	return {}


func assign_inventory_stack(key_number: int, stack_index: int) -> bool:
	if not is_quick_key_number(key_number) or stack_index < 0 or stack_index >= _inventory.stacks.size() or _model == null:
		return false
	var stack := _inventory.stacks[stack_index] as Dictionary
	if not is_stack_usable(stack):
		return false
	var item_def := _owner.call("_load_item_from_stack", stack) as ItemDef
	if not ItemConsumableServiceScript.is_usable_stack(stack, item_def):
		return false
	var assigned_variant: Variant = _model.call("assign_inventory_stack", key_number, stack_index, stack)
	if typeof(assigned_variant) != TYPE_BOOL or not bool(assigned_variant):
		return false
	_owner.emit_signal("inventory_changed")
	sync_selected_after_slot_change(key_number)
	return true


func clear_slot(key_number: int) -> bool:
	var normalized := int(key_number)
	if not is_quick_key_number(normalized) or _model == null:
		return false
	var removed: Variant = _model.call("clear_slot", normalized)
	if typeof(removed) != TYPE_BOOL or not bool(removed):
		return false
	if int(_owner.get("_selected_quick_item_key")) == normalized:
		_owner.set("_selected_quick_item_key", -1)
		_owner.call("_sync_held_weapon_visuals")
	_owner.emit_signal("inventory_changed")
	return true


func move_slot(from_key: int, to_key: int) -> bool:
	var normalized_from := int(from_key)
	var normalized_to := int(to_key)
	if not is_quick_key_number(normalized_from) or not is_quick_key_number(normalized_to) or normalized_from == normalized_to or _model == null:
		return false
	var resolved: Variant = _model.call("resolve_stack_index", normalized_from, _inventory.stacks)
	if typeof(resolved) != TYPE_INT:
		return false
	var stack_index := int(resolved)
	if stack_index < 0 or stack_index >= _inventory.stacks.size():
		return false
	var moved: Variant = _model.call("assign_inventory_stack", normalized_to, stack_index, _inventory.stacks[stack_index])
	if typeof(moved) != TYPE_BOOL or not bool(moved):
		return false
	if int(_owner.get("_selected_quick_item_key")) == normalized_from:
		_owner.set("_selected_quick_item_key", normalized_to)
	_owner.emit_signal("inventory_changed")
	sync_selected_after_slot_change(normalized_from)
	sync_selected_after_slot_change(normalized_to)
	return true


func select_slot(key_number: int) -> bool:
	if not is_quick_key_number(key_number) or _model == null:
		return false
	var resolved: Variant = _model.call("resolve_stack_index", key_number, _inventory.stacks)
	if typeof(resolved) != TYPE_INT:
		return false
	if int(resolved) < 0:
		if int(_owner.get("_selected_quick_item_key")) == key_number:
			_owner.set("_selected_quick_item_key", -1)
			_owner.call("_sync_held_weapon_visuals")
		return false
	_owner.set("_selected_quick_item_key", key_number)
	_owner.call("_set_melee_mode", false)
	_owner.call("_sync_held_weapon_visuals")
	return true


func use_selected() -> bool:
	if not has_selected_item():
		return false
	return use_slot(int(_owner.get("_selected_quick_item_key")))


func has_selected_item() -> bool:
	var selected := int(_owner.get("_selected_quick_item_key"))
	if not is_quick_key_number(selected) or _model == null:
		return false
	var resolved: Variant = _model.call("resolve_stack_index", selected, _inventory.stacks)
	return typeof(resolved) == TYPE_INT and int(resolved) >= 0


func selected_item_stack() -> Dictionary:
	var selected := int(_owner.get("_selected_quick_item_key"))
	if not is_quick_key_number(selected):
		return {}
	var state := get_quick_slot_state(selected)
	if not bool(state.get("assigned", false)):
		return {}
	return (state.get("stack", {}) as Dictionary).duplicate(true)


func use_slot(key_number: int) -> bool:
	if not is_quick_key_number(key_number) or _model == null:
		return false
	var resolved: Variant = _model.call("resolve_stack_index", key_number, _inventory.stacks)
	if typeof(resolved) != TYPE_INT or int(resolved) < 0:
		return false
	return bool(_owner.call("use_inventory_stack", int(resolved)))


func sync_selected_after_slot_change(key_number: int) -> void:
	var normalized := int(key_number)
	if not is_quick_key_number(normalized) or int(_owner.get("_selected_quick_item_key")) != normalized:
		return
	if not bool(get_quick_slot_state(normalized).get("assigned", false)):
		_owner.set("_selected_quick_item_key", -1)
		_owner.call("_sync_held_weapon_visuals")


func is_slot_still_valid(key_number: int) -> bool:
	if not is_quick_key_number(key_number):
		return false
	var state := get_quick_slot_state(key_number)
	return not state.is_empty() and bool(state.get("assigned", false))


func is_quick_key_number(key_number: int) -> bool:
	return key_number >= 3 and key_number <= 8


func is_stack_usable(stack: Dictionary) -> bool:
	return int(stack.get("quantity", 0)) > 0
