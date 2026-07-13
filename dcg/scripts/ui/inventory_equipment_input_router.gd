class_name InventoryEquipmentInputRouter
extends RefCounted

var _owner: Control


func _init(owner: Control) -> void:
	_owner = owner


func handle_gui_input(event: InputEvent) -> void:
	if not bool(_owner.get("is_open")):
		return
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	_owner.set("_last_mouse_position", event.position)
	_owner.queue_redraw()
	for pair in [
		["_is_dragging_quick_slot", "_update_quick_slot_drag"],
		["_is_dragging_weapon_mod", "_update_weapon_mod_drag"],
		["_is_dragging_equipment", "_update_equipment_drag"],
	]:
		if bool(_owner.call(pair[0])):
			_owner.call(pair[1], event.position)
			_owner.accept_event()
			return
	var drop_controller := _drop_controller()
	if bool(drop_controller.call("is_dragging")):
		drop_controller.call("update_drag", event.position)
		_owner.accept_event()
		return
	if bool(_context_menu().call("handle_mouse_motion", event)):
		_owner.accept_event()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	_owner.set("_last_mouse_position", event.position)
	var hit_stack_index := int(_owner.call("_get_backpack_stack_index_at", event.position))
	var hit_safe_pocket_index := int(_owner.call("_get_safe_pocket_slot_index_at", event.position))
	var hit_equipment_slot := StringName(_owner.call("_get_equipment_slot_id_at", event.position))
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _handle_right_click(event, hit_equipment_slot):
			return
	var backpack_items: Array = _owner.get("backpack_items") as Array
	if bool(_context_menu().call("handle_mouse_button", event, hit_stack_index, backpack_items, _owner.call("_get_backpack_slots"))):
		_owner.accept_event()
		return
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _handle_left_press(event, hit_stack_index, hit_safe_pocket_index, hit_equipment_slot):
			return
	if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_release(event)


func _handle_right_click(event: InputEventMouseButton, hit_equipment_slot: StringName) -> bool:
	_drop_controller().call("clear")
	if bool(_weapon_mod_panel().call("is_open")):
		_context_menu().call("close_all")
		_owner.accept_event()
		return true
	if hit_equipment_slot != &"" and not (_owner.call("_equipment_stack_for_slot", hit_equipment_slot) as Dictionary).is_empty():
		_context_menu().call("open_equipment_context_menu", hit_equipment_slot, event.position)
		_owner.call("_close_item_detail_panel")
		_owner.accept_event()
		return true
	return false


func _handle_left_press(event: InputEventMouseButton, hit_stack_index: int, hit_safe_pocket_index: int, hit_equipment_slot: StringName) -> bool:
	var quick_key := int(_owner.call("_get_quick_item_key_at", event.position))
	if quick_key >= 3 and bool(_owner.call("_start_quick_slot_drag", quick_key, event.position)):
		return _accept()
	var store_all_rect: Rect2 = _owner.get("_store_all_button_rect") as Rect2
	if bool(_owner.get("_store_all_button_visible")) and store_all_rect.has_point(event.position):
		_context_menu().call("close_all")
		_drop_controller().call("clear")
		_owner.emit_signal("store_all_requested")
		return _accept()
	var organize_rect: Rect2 = _owner.get("_organize_button_rect") as Rect2
	if organize_rect.has_point(event.position):
		_owner.call("organize_backpack")
		return _accept()
	var hit_weapon_mod_slot := StringName(_owner.call("_get_weapon_mod_slot_id_at", event.position))
	if hit_weapon_mod_slot != &"" and bool(_owner.call("_start_weapon_mod_drag", hit_weapon_mod_slot, event.position)):
		return _accept()
	if bool(_owner.call("_handle_weapon_mod_panel_click", event.position)):
		return _accept()
	if hit_equipment_slot != &"" and event.double_click and bool(_owner.call("_unequip_equipment_slot", hit_equipment_slot)):
		return _accept()
	if hit_equipment_slot != &"":
		if not bool(_owner.call("_open_weapon_mod_panel_for_slot", hit_equipment_slot)):
			_owner.call("_open_item_detail_panel_for_stack", _owner.call("_equipment_stack_for_slot", hit_equipment_slot))
		if bool(_owner.call("_start_equipment_drag", hit_equipment_slot, event.position)):
			return _accept()
	var safe_items: Array = _owner.get("safe_pocket_items") as Array
	if hit_safe_pocket_index >= 0 and hit_safe_pocket_index < safe_items.size():
		var stack := (safe_items[hit_safe_pocket_index] as Dictionary).duplicate(true)
		if event.double_click and bool(_owner.call("_move_safe_pocket_stack_to_backpack", hit_safe_pocket_index)):
			_owner.call("_open_item_detail_panel_for_stack", stack)
			return _accept()
		_owner.call("_open_item_detail_panel_for_stack", stack)
		return _accept()
	var backpack_items: Array = _owner.get("backpack_items") as Array
	if hit_stack_index >= 0 and hit_stack_index < backpack_items.size():
		if event.double_click:
			_owner.call("equip_backpack_stack", hit_stack_index)
			return _accept()
		if not bool(_owner.call("_open_weapon_mod_panel_for_backpack_stack", hit_stack_index)):
			_owner.call("_open_item_detail_panel_for_stack", backpack_items[hit_stack_index])
		_context_menu().call("close_all")
		_drop_controller().call("start_drag", hit_stack_index, backpack_items[hit_stack_index], event.position)
		return _accept()
	if hit_stack_index >= 0 and hit_stack_index < int(_owner.call("_get_backpack_slots")):
		if bool(_weapon_mod_panel().call("is_open")) or bool(_item_detail_panel().call("is_open")):
			_owner.call("_close_weapon_mod_panel")
			_owner.call("_close_item_detail_panel")
			return _accept()
	return false


func _handle_left_release(event: InputEventMouseButton) -> void:
	for pair in [
		["_is_dragging_weapon_mod", "_finish_weapon_mod_drag"],
		["_is_dragging_quick_slot", "_finish_quick_slot_drag"],
		["_is_dragging_equipment", "_finish_equipment_drag"],
	]:
		if bool(_owner.call(pair[0])):
			_owner.call(pair[1], event.position)
			_owner.accept_event()
			return
	var drop_controller := _drop_controller()
	if not bool(drop_controller.call("is_dragging")):
		return
	var target_quick_key := int(_owner.call("_get_quick_item_key_at", event.position))
	if target_quick_key >= 3 and bool(_owner.call("assign_backpack_stack_to_quick_slot", drop_controller.get("dragging_stack_index"), target_quick_key)):
		drop_controller.call("clear")
		_owner.accept_event()
		return
	var target_weapon_mod_slot := StringName(_owner.call("_get_weapon_mod_slot_id_at", event.position))
	if target_weapon_mod_slot != &"":
		_owner.call("_attach_dragged_stack_to_open_weapon_hardpoint", target_weapon_mod_slot)
		drop_controller.call("clear")
		_owner.accept_event()
		return
	drop_controller.call(
		"finish_drag",
		_owner.get("backpack_model"),
		event.position,
		_owner.call("_panel_rect"),
		_owner.call("_get_backpack_stack_index_at", event.position),
		_owner.get("player"),
		_owner.call("_get_equipment_slot_id_at", event.position),
		_owner.call("_get_safe_pocket_slot_index_at", event.position),
		true
	)
	_owner.accept_event()


func _accept() -> bool:
	_owner.accept_event()
	return true


func _drop_controller() -> RefCounted:
	return _owner.get("_drop_controller") as RefCounted


func _context_menu() -> RefCounted:
	return _owner.get("_context_menu") as RefCounted


func _weapon_mod_panel() -> RefCounted:
	return _owner.get("_weapon_mod_panel") as RefCounted


func _item_detail_panel() -> RefCounted:
	return _owner.get("_item_detail_panel") as RefCounted
