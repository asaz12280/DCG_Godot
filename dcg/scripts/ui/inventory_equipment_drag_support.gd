class_name InventoryEquipmentDragSupport
extends RefCounted

const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")

var _owner: Control
var _dragging_equipment_slot: StringName = &""
var _dragging_equipment_stack: Dictionary = {}
var _equipment_drag_position := Vector2.ZERO
var _dragging_weapon_mod_slot: StringName = &""
var _dragging_weapon_mod_stack: Dictionary = {}
var _weapon_mod_drag_position := Vector2.ZERO
var _dragging_quick_slot_key := -1
var _dragging_quick_slot_stack: Dictionary = {}
var _quick_slot_drag_position := Vector2.ZERO


func _init(owner: Control) -> void:
	_owner = owner


func clear_all() -> void:
	clear_weapon_mod_drag()
	clear_quick_slot_drag()
	clear_equipment_drag()


func start_weapon_mod_drag(hardpoint_slot: StringName, mouse_position: Vector2) -> bool:
	var panel: RefCounted = _owner.get("_weapon_mod_panel") as RefCounted
	if panel.get("weapon_slot") == &"" or hardpoint_slot == &"":
		return false
	var stack := _owner.call("_weapon_mod_stack_for_slot", hardpoint_slot) as Dictionary
	if stack.is_empty():
		return false
	_dragging_weapon_mod_slot = hardpoint_slot
	_dragging_weapon_mod_stack = stack.duplicate(true)
	_weapon_mod_drag_position = mouse_position
	_close_competing_interactions()
	clear_equipment_drag()
	_owner.queue_redraw()
	return true


func update_weapon_mod_drag(mouse_position: Vector2) -> void:
	_weapon_mod_drag_position = mouse_position
	_owner.queue_redraw()


func finish_weapon_mod_drag(mouse_position: Vector2) -> bool:
	if not is_dragging_weapon_mod():
		return false
	var handled := false
	if int(_owner.call("_get_backpack_stack_index_at", mouse_position)) >= 0:
		handled = unequip_dragged_weapon_mod_to_backpack()
	clear_weapon_mod_drag()
	_owner.queue_redraw()
	return handled


func unequip_dragged_weapon_mod_to_backpack() -> bool:
	if int(_owner.get("_weapon_mod_backpack_stack_index")) >= 0:
		return _unequip_dragged_backpack_weapon_mod_to_backpack()
	var player: Node = _owner.get("player") as Node
	var panel: RefCounted = _owner.get("_weapon_mod_panel") as RefCounted
	var weapon_slot := StringName(str(panel.get("weapon_slot")))
	if player == null or not player.has_method("unequip_weapon_mod_to_inventory"):
		return false
	if weapon_slot == &"" or _dragging_weapon_mod_slot == &"":
		return false
	if not bool(player.call("unequip_weapon_mod_to_inventory", weapon_slot, _dragging_weapon_mod_slot)):
		return false
	_owner.call("_refresh_weapon_mod_panel_state")
	return true


func _unequip_dragged_backpack_weapon_mod_to_backpack() -> bool:
	var backpack_model: RefCounted = _owner.get("backpack_model") as RefCounted
	var weapon_index := int(_owner.get("_weapon_mod_backpack_stack_index"))
	if weapon_index < 0 or weapon_index >= backpack_model.get("stacks").size() or _dragging_weapon_mod_slot == &"":
		return false
	var stacks: Array = backpack_model.get("stacks") as Array
	var weapon_stack := (stacks[weapon_index] as Dictionary).duplicate(true)
	var mods: Dictionary = weapon_stack.get("weapon_mods", {}) as Dictionary
	var removed_value: Variant = mods.get(str(_dragging_weapon_mod_slot), mods.get(_dragging_weapon_mod_slot, {}))
	if typeof(removed_value) != TYPE_DICTIONARY or (removed_value as Dictionary).is_empty():
		return false
	var removed_stack := (removed_value as Dictionary).duplicate(true)
	mods.erase(str(_dragging_weapon_mod_slot))
	mods.erase(_dragging_weapon_mod_slot)
	weapon_stack["weapon_mods"] = mods.duplicate(true)
	if not bool(backpack_model.call("can_accept_stack", removed_stack)):
		return false
	if not bool(backpack_model.call("replace_stack_at", weapon_index, weapon_stack)):
		return false
	if not bool(backpack_model.call("add_stack", removed_stack)):
		mods[str(_dragging_weapon_mod_slot)] = removed_stack
		weapon_stack["weapon_mods"] = mods.duplicate(true)
		backpack_model.call("replace_stack_at", weapon_index, weapon_stack)
		return false
	_owner.call("_refresh_weapon_mod_panel_state")
	return true


func is_dragging_weapon_mod() -> bool:
	return _dragging_weapon_mod_slot != &"" and not _dragging_weapon_mod_stack.is_empty()


func clear_weapon_mod_drag() -> void:
	_dragging_weapon_mod_slot = &""
	_dragging_weapon_mod_stack.clear()
	_weapon_mod_drag_position = Vector2.ZERO


func draw_dragged_weapon_mod_item() -> void:
	_draw_dragged_item(_weapon_mod_drag_position, _dragging_weapon_mod_stack, &"mod")


func start_quick_slot_drag(quick_key: int, mouse_position: Vector2) -> bool:
	var state := _owner.call("_get_quick_slot_state_by_key", quick_key) as Dictionary
	if state.is_empty() or int(state.get("key", -1)) < 3 or int(state.get("key", -1)) > 8:
		return false
	if not bool(state.get("assigned", false)):
		return false
	var stack := state.get("stack", {}) as Dictionary
	if stack.is_empty():
		return false
	_dragging_quick_slot_key = int(state.get("key", quick_key))
	_dragging_quick_slot_stack = stack.duplicate(true)
	_quick_slot_drag_position = mouse_position
	_close_competing_interactions()
	clear_weapon_mod_drag()
	clear_equipment_drag()
	_owner.queue_redraw()
	return true


func update_quick_slot_drag(mouse_position: Vector2) -> void:
	_quick_slot_drag_position = mouse_position
	_owner.queue_redraw()


func finish_quick_slot_drag(mouse_position: Vector2) -> bool:
	if not is_dragging_quick_slot():
		return false
	var source_key := _dragging_quick_slot_key
	var target_key := int(_owner.call("_get_quick_item_key_at", mouse_position))
	var handled := false
	var player: Node = _owner.get("player") as Node
	if target_key >= 3:
		if target_key == source_key:
			handled = true
		elif player != null and player.has_method("move_quick_slot_to_key"):
			handled = bool(player.call("move_quick_slot_to_key", source_key, target_key))
	elif not (_owner.call("_panel_rect") as Rect2).has_point(mouse_position):
		if player != null and player.has_method("clear_quick_slot_for_key"):
			handled = bool(player.call("clear_quick_slot_for_key", source_key))
	clear_quick_slot_drag()
	_owner.queue_redraw()
	return handled


func clear_quick_slot_drag() -> void:
	_dragging_quick_slot_key = -1
	_dragging_quick_slot_stack.clear()
	_quick_slot_drag_position = Vector2.ZERO


func is_dragging_quick_slot() -> bool:
	return _dragging_quick_slot_key >= 3 and not _dragging_quick_slot_stack.is_empty()


func draw_dragged_quick_slot_item() -> void:
	_draw_dragged_item(_quick_slot_drag_position, _dragging_quick_slot_stack, &"quick")


func start_equipment_drag(slot_id: StringName, mouse_position: Vector2) -> bool:
	var equipment_model: RefCounted = _owner.get("equipment_model") as RefCounted
	if equipment_model == null or slot_id == &"" or not equipment_model.has_method("get_slot"):
		return false
	var stack: Dictionary = equipment_model.call("get_slot", slot_id)
	if stack.is_empty():
		return false
	_dragging_equipment_slot = slot_id
	_dragging_equipment_stack = stack.duplicate(true)
	_equipment_drag_position = mouse_position
	_close_competing_interactions()
	_owner.queue_redraw()
	return true


func update_equipment_drag(mouse_position: Vector2) -> void:
	_equipment_drag_position = mouse_position
	_owner.queue_redraw()


func finish_equipment_drag(mouse_position: Vector2) -> bool:
	if not is_dragging_equipment():
		return false
	var target_stack_index := int(_owner.call("_get_backpack_stack_index_at", mouse_position))
	var target_equipment_slot := StringName(_owner.call("_get_equipment_slot_id_at", mouse_position))
	var handled := false
	if target_stack_index >= 0:
		handled = unequip_dragged_equipment_to_backpack()
	elif target_equipment_slot != &"":
		handled = move_dragged_equipment_to_equipment_slot(target_equipment_slot)
	elif not (_owner.call("_panel_rect") as Rect2).has_point(mouse_position):
		handled = drop_dragged_equipment_to_world(mouse_position)
	clear_equipment_drag()
	_owner.queue_redraw()
	return handled


func unequip_dragged_equipment_to_backpack() -> bool:
	var player: Node = _owner.get("player") as Node
	if player == null or not player.has_method("unequip_equipment_slot") or _dragging_equipment_slot == &"":
		return false
	return bool(player.call("unequip_equipment_slot", _dragging_equipment_slot))


func move_dragged_equipment_to_equipment_slot(target_slot: StringName) -> bool:
	if _dragging_equipment_slot == &"" or target_slot == &"" or _dragging_equipment_slot == target_slot:
		return false
	var player: Node = _owner.get("player") as Node
	if player == null or not player.has_method("swap_equipment_slots"):
		return false
	return bool(player.call("swap_equipment_slots", _dragging_equipment_slot, target_slot))


func drop_dragged_equipment_to_world(mouse_position: Vector2) -> bool:
	if _dragging_equipment_slot == &"" or _dragging_equipment_stack.is_empty():
		return false
	var drop_controller: RefCounted = _owner.get("_drop_controller") as RefCounted
	return bool(drop_controller.call("drop_equipment_stack_at", _dragging_equipment_slot, _dragging_equipment_stack, mouse_position, _owner.get("player")))


func is_dragging_equipment() -> bool:
	return _dragging_equipment_slot != &"" and not _dragging_equipment_stack.is_empty()


func clear_equipment_drag() -> void:
	_dragging_equipment_slot = &""
	_dragging_equipment_stack.clear()
	_equipment_drag_position = Vector2.ZERO


func draw_dragged_equipment_item() -> void:
	_draw_dragged_item(_equipment_drag_position, _dragging_equipment_stack, &"equipment")


func _draw_dragged_item(position: Vector2, stack: Dictionary, kind: StringName) -> void:
	var slot_size: Vector2 = _owner.get("_scaled_slot_size") as Vector2
	var drag_rect := Rect2(position - slot_size * 0.5, slot_size)
	var painter: RefCounted = _owner.get("_painter") as RefCounted
	painter.call("slot", drag_rect, UISurfacePaletteScript.drag_slot_fill(kind), UISurfacePaletteScript.drag_slot_border(kind))
	_owner.call("_paint_item_label", drag_rect, stack)


func _close_competing_interactions() -> void:
	var context_menu: RefCounted = _owner.get("_context_menu") as RefCounted
	var drop_controller: RefCounted = _owner.get("_drop_controller") as RefCounted
	context_menu.call("close_all")
	drop_controller.call("clear")
