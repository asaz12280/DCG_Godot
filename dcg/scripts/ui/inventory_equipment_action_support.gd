class_name InventoryEquipmentActionSupport
extends RefCounted

const WeaponAttachmentServiceScript := preload("res://scripts/combat/weapon_attachment_service.gd")

var _owner: Control


func _init(owner: Control) -> void:
	_owner = owner


func context_drop(stack_index: int, stack: Dictionary, screen_position: Vector2, random_near_player: bool) -> void:
	if _panel().is_open():
		return
	_drop_controller().call("drop_stack_at", _backpack_model(), stack_index, stack, screen_position, _player(), random_near_player)


func context_use(stack_index: int) -> void:
	var player := _player()
	if player == null or not player.has_method("use_inventory_stack"):
		return
	player.call("use_inventory_stack", stack_index)
	_finish_action()


func context_unload_ammo(stack_index: int) -> void:
	unload_backpack_weapon_ammo_to_backpack(stack_index)
	_finish_action()


func context_equipment_unload_ammo(slot_id: StringName) -> void:
	unload_equipment_weapon_ammo_to_backpack(slot_id)
	_finish_action()


func context_equipment_drop(slot_id: StringName, screen_position: Vector2) -> void:
	var player := _player()
	if player != null and player.has_method("drop_equipment_slot"):
		player.call("drop_equipment_slot", slot_id)
	_finish_action()


func unequip_equipment_slot(slot_id: StringName) -> bool:
	var player := _player()
	if player == null or not player.has_method("unequip_equipment_slot"):
		return false
	if not bool(player.call("unequip_equipment_slot", slot_id)):
		return false
	_finish_action()
	return true


func open_weapon_mod_panel_for_backpack_stack(stack_index: int) -> bool:
	var state := _owner.call("_weapon_mod_panel_state_for_backpack_stack", stack_index) as Dictionary
	if not bool(_panel().call("open", &"backpack_weapon", state)):
		return false
	_owner.set("_weapon_mod_backpack_stack_index", stack_index)
	_detail_panel().call("close")
	_finish_action()
	return true


func open_weapon_mod_panel_for_slot(slot_id: StringName) -> bool:
	var player := _player()
	if slot_id == &"" or player == null or not player.has_method("get_weapon_mod_panel_state"):
		return false
	var state: Dictionary = player.call("get_weapon_mod_panel_state", slot_id)
	if not bool(state.get("has_weapon", false)) or not bool(_panel().call("open", slot_id, state)):
		return false
	_owner.set("_weapon_mod_backpack_stack_index", -1)
	_detail_panel().call("close")
	_finish_action()
	return true


func open_item_detail_panel_for_stack(stack: Dictionary) -> bool:
	var state := _owner.call("_tooltip_state_for_stack", stack) as Dictionary
	if state.is_empty():
		return false
	close_weapon_mod_panel()
	_detail_panel().call("open", state)
	_context_menu().call("close_all")
	_owner.queue_redraw()
	return true


func close_weapon_mod_panel() -> void:
	_owner.call("_clear_weapon_mod_drag")
	_owner.set("_weapon_mod_backpack_stack_index", -1)
	_panel().call("close")
	_owner.call("_clear_equipment_drag")
	_owner.call("_clear_quick_slot_drag")


func close_item_detail_panel() -> void:
	if not bool(_detail_panel().call("is_open")):
		return
	_detail_panel().call("close")
	_owner.queue_redraw()


func refresh_weapon_mod_panel_state() -> void:
	var backpack_index := int(_owner.get("_weapon_mod_backpack_stack_index"))
	if backpack_index >= 0:
		_panel().call("refresh", _owner.call("_weapon_mod_panel_state_for_backpack_stack", backpack_index))
		return
	var weapon_slot := StringName(str(_panel().get("weapon_slot")))
	var player := _player()
	if weapon_slot == &"" or player == null or not player.has_method("get_weapon_mod_panel_state"):
		return
	_panel().call("refresh", player.call("get_weapon_mod_panel_state", weapon_slot))


func attach_dragged_stack_to_open_weapon_hardpoint(hardpoint_slot: StringName) -> bool:
	if int(_owner.get("_weapon_mod_backpack_stack_index")) >= 0:
		return attach_dragged_stack_to_backpack_weapon_hardpoint(hardpoint_slot)
	var player := _player()
	var weapon_slot := StringName(str(_panel().get("weapon_slot")))
	if weapon_slot == &"" or player == null or not player.has_method("attach_inventory_stack_to_weapon_hardpoint"):
		return false
	var dragging_index := int(_drop_controller().get("dragging_stack_index"))
	if not bool(player.call("attach_inventory_stack_to_weapon_hardpoint", dragging_index, weapon_slot, hardpoint_slot)):
		return false
	refresh_weapon_mod_panel_state()
	_context_menu().call("close_all")
	_owner.queue_redraw()
	return true


func attach_dragged_stack_to_backpack_weapon_hardpoint(hardpoint_slot: StringName) -> bool:
	var dragging_index := int(_drop_controller().get("dragging_stack_index"))
	if hardpoint_slot == &"" or dragging_index < 0:
		return false
	var weapon_index := int(_owner.get("_weapon_mod_backpack_stack_index"))
	var backpack := _backpack_model()
	var stacks: Array = backpack.get("stacks") as Array
	if weapon_index < 0 or weapon_index >= stacks.size() or dragging_index == weapon_index:
		return false
	var weapon_stack := (stacks[weapon_index] as Dictionary).duplicate(true)
	var weapon_def := _owner.call("_load_item_from_stack", weapon_stack) as ItemDef
	var attachment_stack := stacks[dragging_index] as Dictionary
	var attachment_def := _owner.call("_load_item_from_stack", attachment_stack) as ItemDef
	if weapon_def == null or attachment_def == null:
		return false
	if attachment_def.item_type != "attachment" or WeaponAttachmentServiceScript.mod_slot_for_attachment(attachment_def, weapon_def) != hardpoint_slot:
		return false
	if not WeaponAttachmentServiceScript.weapon_mod_stack(weapon_stack, hardpoint_slot).is_empty():
		return false
	if dragging_index < weapon_index:
		weapon_index -= 1
		_owner.set("_weapon_mod_backpack_stack_index", weapon_index)
	var removed_stack: Dictionary = backpack.call("remove_stack_at", dragging_index)
	if removed_stack.is_empty():
		return false
	stacks = backpack.get("stacks") as Array
	weapon_stack = (stacks[weapon_index] as Dictionary).duplicate(true)
	var mods: Dictionary = weapon_stack.get("weapon_mods", {}) as Dictionary
	mods[str(hardpoint_slot)] = removed_stack.duplicate(true)
	weapon_stack["weapon_mods"] = mods.duplicate(true)
	if not bool(backpack.call("replace_stack_at", weapon_index, weapon_stack)):
		backpack.call("add_stack", removed_stack)
		return false
	refresh_weapon_mod_panel_state()
	_context_menu().call("close_all")
	_owner.queue_redraw()
	return true


func handle_weapon_mod_panel_click(screen_position: Vector2) -> bool:
	if not bool(_panel().call("is_open")):
		return false
	var hit := _panel().call("hit_slot", screen_position, _owner.get("_ui_scale"), _owner.get("_layout_viewport_size")) as Dictionary
	return bool(hit.get("handled", false))


func unload_backpack_weapon_ammo_to_backpack(weapon_index: int) -> bool:
	var backpack := _backpack_model()
	var stacks: Array = backpack.get("stacks") as Array
	if weapon_index < 0 or weapon_index >= stacks.size():
		return false
	var weapon_stack := (stacks[weapon_index] as Dictionary).duplicate(true)
	var ammo_state: Dictionary = weapon_stack.get("weapon_ammo_state", {}) as Dictionary
	var loaded_count := maxi(int(ammo_state.get("loaded_ammo", 0)), 0)
	var ammo_item := _owner.call("_load_ammo_item_from_weapon_state", ammo_state) as ItemDef
	if ammo_item == null or loaded_count <= 0 or not bool(backpack.call("can_accept_stack", ammo_item.to_stack(loaded_count))):
		return false
	ammo_state["loaded_ammo"] = 0
	weapon_stack["weapon_ammo_state"] = ammo_state.duplicate(true)
	if not bool(backpack.call("replace_stack_at", weapon_index, weapon_stack)):
		return false
	if not bool(backpack.call("add_item", ammo_item, loaded_count)):
		ammo_state["loaded_ammo"] = loaded_count
		weapon_stack["weapon_ammo_state"] = ammo_state.duplicate(true)
		backpack.call("replace_stack_at", weapon_index, weapon_stack)
		return false
	if weapon_index == int(_owner.get("_weapon_mod_backpack_stack_index")):
		refresh_weapon_mod_panel_state()
	return true


func unload_equipment_weapon_ammo_to_backpack(slot_id: StringName) -> bool:
	var player := _player()
	if player == null or not player.has_method("unload_equipped_weapon_ammo_to_backpack"):
		return false
	if slot_id != &"primary_weapon" and slot_id != &"sidearm":
		return false
	var previous_active_slot := &""
	if player.has_method("get_equipped_weapon_slot_id"):
		previous_active_slot = StringName(str(player.call("get_equipped_weapon_slot_id")))
	if previous_active_slot != slot_id and player.has_method("set_active_weapon_slot"):
		player.call("set_active_weapon_slot", slot_id)
	var result: Variant = player.call("unload_equipped_weapon_ammo_to_backpack")
	if previous_active_slot != &"" and previous_active_slot != slot_id and player.has_method("set_active_weapon_slot"):
		player.call("set_active_weapon_slot", previous_active_slot)
	if typeof(result) == TYPE_DICTIONARY and bool((result as Dictionary).get("success", false)):
		refresh_weapon_mod_panel_state()
		return true
	return false


func get_weapon_mod_slot_id_at(screen_position: Vector2) -> StringName:
	if not bool(_panel().call("is_open")):
		return &""
	var hit := _panel().call("hit_slot", screen_position, _owner.get("_ui_scale"), _owner.get("_layout_viewport_size")) as Dictionary
	return StringName(str(hit.get("slot_id", ""))) if bool(hit.get("handled", false)) else &""


func move_safe_pocket_stack_to_backpack(stack_index: int) -> bool:
	var player := _player()
	if player == null or not player.has_method("move_safe_pocket_stack_to_inventory"):
		return false
	if not bool(player.call("move_safe_pocket_stack_to_inventory", stack_index)):
		return false
	_finish_action()
	return true


func _finish_action() -> void:
	_context_menu().call("close_all")
	_drop_controller().call("clear")
	_owner.queue_redraw()


func _player() -> Node:
	return _owner.get("player") as Node


func _backpack_model() -> RefCounted:
	return _owner.get("backpack_model") as RefCounted


func _panel() -> RefCounted:
	return _owner.get("_weapon_mod_panel") as RefCounted


func _detail_panel() -> RefCounted:
	return _owner.get("_item_detail_panel") as RefCounted


func _context_menu() -> RefCounted:
	return _owner.get("_context_menu") as RefCounted


func _drop_controller() -> RefCounted:
	return _owner.get("_drop_controller") as RefCounted
