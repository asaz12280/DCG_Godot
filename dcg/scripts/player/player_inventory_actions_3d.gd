extends RefCounted

const WEAPON_HARDPOINT_SLOT_IDS: Array[StringName] = [&"weapon_mag", &"weapon_grip", &"weapon_muzzle", &"weapon_scope", &"weapon_stock", &"weapon_tactic"]


static func can_move_inventory_stack_to_safe_pocket(player: Node, stack_index: int) -> bool:
	var inventory_model = player.get("inventory_model")
	var safe_pocket_model = player.get("safe_pocket_model")
	if stack_index < 0 or stack_index >= inventory_model.stacks.size():
		return false
	return safe_pocket_model.can_accept_stack(inventory_model.stacks[stack_index])


static func move_inventory_stack_to_safe_pocket(player: Node, stack_index: int) -> bool:
	var inventory_model = player.get("inventory_model")
	var safe_pocket_model = player.get("safe_pocket_model")
	if not can_move_inventory_stack_to_safe_pocket(player, stack_index):
		return false
	var removed_stack: Dictionary = inventory_model.remove_stack_at(stack_index)
	if removed_stack.is_empty():
		return false
	if not safe_pocket_model.add_stack(removed_stack):
		inventory_model.add_stack(removed_stack)
		return false
	return true


static func can_move_safe_pocket_stack_to_inventory(player: Node, stack_index: int) -> bool:
	var inventory_model = player.get("inventory_model")
	var safe_pocket_model = player.get("safe_pocket_model")
	if stack_index < 0 or stack_index >= safe_pocket_model.stacks.size():
		return false
	return inventory_model.can_accept_stack(safe_pocket_model.stacks[stack_index])


static func move_safe_pocket_stack_to_inventory(player: Node, stack_index: int) -> bool:
	var inventory_model = player.get("inventory_model")
	var safe_pocket_model = player.get("safe_pocket_model")
	if not can_move_safe_pocket_stack_to_inventory(player, stack_index):
		return false
	var removed_stack: Dictionary = safe_pocket_model.remove_stack_at(stack_index)
	if removed_stack.is_empty():
		return false
	if not inventory_model.add_stack(removed_stack):
		safe_pocket_model.add_stack(removed_stack)
		return false
	return true


static func can_equip_inventory_stack(player: Node, stack_index: int, slot_id: StringName = &"") -> bool:
	var inventory_model = player.get("inventory_model")
	var equipment_model = player.get("equipment_model")
	if stack_index < 0 or stack_index >= inventory_model.stacks.size():
		return false
	var stack := inventory_model.stacks[stack_index] as Dictionary
	if WEAPON_HARDPOINT_SLOT_IDS.has(slot_id):
		return can_attach_inventory_stack_to_weapon(player, stack_index, StringName(player.call("_get_equipped_weapon_slot_id")))
	var target_slot := slot_id
	if target_slot == &"":
		target_slot = default_equipment_slot_for_stack(player, stack)
	if target_slot == &"" or not equipment_model.has_slot(target_slot) or not equipment_model.is_empty(target_slot):
		return false
	var item_def := player.call("_load_item_from_stack", stack) as ItemDef
	return equipment_model.can_equip(target_slot, item_def)


static func equip_inventory_stack(player: Node, stack_index: int, slot_id: StringName = &"") -> bool:
	var inventory_model = player.get("inventory_model")
	var equipment_model = player.get("equipment_model")
	if WEAPON_HARDPOINT_SLOT_IDS.has(slot_id):
		return attach_inventory_stack_to_weapon(player, stack_index, StringName(player.call("_get_equipped_weapon_slot_id")))
	if not can_equip_inventory_stack(player, stack_index, slot_id):
		if not can_move_inventory_stack_to_equipment_slot(player, stack_index, slot_id):
			return false
	var stack := inventory_model.stacks[stack_index] as Dictionary
	var target_slot := slot_id
	if target_slot == &"":
		target_slot = default_equipment_slot_for_stack(player, stack)
	if not equipment_model.is_empty(target_slot) and target_slot != &"":
		return _move_inventory_stack_to_occupied_equipment_slot(player, stack_index, target_slot)
	var removed_stack: Dictionary = inventory_model.remove_stack_at(stack_index)
	if removed_stack.is_empty():
		return false
	if not equipment_model.equip_stack(target_slot, removed_stack):
		inventory_model.add_stack(removed_stack)
		return false
	return true


static func can_swap_inventory_stack_with_equipment_slot(player: Node, stack_index: int, target_slot: StringName) -> bool:
	var inventory_model = player.get("inventory_model")
	var equipment_model = player.get("equipment_model")
	if target_slot == &"" or inventory_model == null or equipment_model == null:
		return false
	if stack_index < 0 or stack_index >= inventory_model.stacks.size():
		return false
	if not equipment_model.has_slot(target_slot) or equipment_model.is_empty(target_slot):
		return false
	var source_stack: Dictionary = inventory_model.stacks[stack_index] as Dictionary
	var target_stack: Dictionary = equipment_model.get_slot(target_slot)
	if source_stack.is_empty() or target_stack.is_empty():
		return false
	var source_def := player.call("_load_item_from_stack", source_stack) as ItemDef
	if source_def == null:
		return false
	if not equipment_model.can_equip(target_slot, source_def):
		return false
	return inventory_model.can_accept_stack(target_stack)


static func can_move_inventory_stack_to_equipment_slot(player: Node, stack_index: int, slot_id: StringName) -> bool:
	return can_swap_inventory_stack_with_equipment_slot(player, stack_index, slot_id)


static func _move_inventory_stack_to_occupied_equipment_slot(player: Node, stack_index: int, target_slot: StringName) -> bool:
	var inventory_model = player.get("inventory_model")
	var equipment_model = player.get("equipment_model")
	if target_slot == &"" or not can_move_inventory_stack_to_equipment_slot(player, stack_index, target_slot):
		return false
	var target_stack: Dictionary = equipment_model.get_slot(target_slot)
	if target_stack.is_empty():
		return false
	var moved_stack: Dictionary = inventory_model.remove_stack_at(stack_index)
	if moved_stack.is_empty():
		return false
	var removed_target: Dictionary = equipment_model.unequip(target_slot)
	if removed_target.is_empty():
		inventory_model.add_stack(moved_stack)
		return false
	if not equipment_model.equip_stack(target_slot, moved_stack):
		equipment_model.equip_stack(target_slot, removed_target)
		inventory_model.add_stack(moved_stack)
		return false
	if not inventory_model.can_accept_stack(target_stack) or not inventory_model.add_stack(target_stack):
		var restored_moved: Dictionary = equipment_model.unequip(target_slot)
		if not restored_moved.is_empty():
			equipment_model.equip_stack(target_slot, target_stack)
		inventory_model.add_stack(moved_stack)
		return false
	return true


static func can_swap_equipment_slots(player: Node, source_slot_id: StringName, target_slot_id: StringName) -> bool:
	var equipment_model = player.get("equipment_model")
	if source_slot_id == &"" or target_slot_id == &"" or source_slot_id == target_slot_id:
		return false
	if equipment_model == null or not equipment_model.has_slot(source_slot_id) or not equipment_model.has_slot(target_slot_id):
		return false
	var source_stack: Dictionary = equipment_model.get_slot(source_slot_id)
	var target_stack: Dictionary = equipment_model.get_slot(target_slot_id)
	if source_stack.is_empty():
		return false
	var source_item := player.call("_load_item_from_stack", source_stack) as ItemDef
	if source_item == null:
		return false
	if not equipment_model.can_equip(target_slot_id, source_item):
		return false
	if target_stack.is_empty():
		return true
	var target_item := player.call("_load_item_from_stack", target_stack) as ItemDef
	if target_item == null:
		return false
	return equipment_model.can_equip(source_slot_id, target_item)


static func swap_equipment_slots(player: Node, source_slot_id: StringName, target_slot_id: StringName) -> bool:
	var equipment_model = player.get("equipment_model")
	if not can_swap_equipment_slots(player, source_slot_id, target_slot_id):
		return false
	var source_stack: Dictionary = equipment_model.get_slot(source_slot_id)
	var target_stack: Dictionary = equipment_model.get_slot(target_slot_id)
	var moved_stack: Dictionary = equipment_model.unequip(source_slot_id)
	if moved_stack.is_empty():
		return false
	if not equipment_model.equip_stack(target_slot_id, moved_stack):
		equipment_model.equip_stack(source_slot_id, moved_stack)
		return false
	if target_stack.is_empty():
		return true
	if not equipment_model.equip_stack(source_slot_id, target_stack):
		var rollback: Dictionary = equipment_model.unequip(target_slot_id)
		if not rollback.is_empty():
			equipment_model.equip_stack(source_slot_id, rollback)
		return false
	return true

static func can_attach_inventory_stack_to_weapon(player: Node, stack_index: int, weapon_slot_id: StringName = &"") -> bool:
	var inventory_model = player.get("inventory_model")
	var equipment_model = player.get("equipment_model")
	if stack_index < 0 or stack_index >= inventory_model.stacks.size():
		return false
	var target_weapon_slot: StringName = weapon_slot_id if weapon_slot_id != &"" else StringName(player.call("_get_equipped_weapon_slot_id"))
	if target_weapon_slot == &"" or equipment_model == null or not equipment_model.has_method("can_attach_weapon_mod"):
		return false
	return bool(equipment_model.call("can_attach_weapon_mod", target_weapon_slot, inventory_model.stacks[stack_index]))


static func can_attach_inventory_stack_to_weapon_hardpoint(player: Node, stack_index: int, weapon_slot_id: StringName, hardpoint_slot: StringName) -> bool:
	var inventory_model = player.get("inventory_model")
	var equipment_model = player.get("equipment_model")
	if stack_index < 0 or stack_index >= inventory_model.stacks.size():
		return false
	if weapon_slot_id == &"" or hardpoint_slot == &"" or equipment_model == null or not equipment_model.has_method("can_attach_weapon_mod_to_hardpoint"):
		return false
	return bool(equipment_model.call("can_attach_weapon_mod_to_hardpoint", weapon_slot_id, hardpoint_slot, inventory_model.stacks[stack_index]))


static func attach_inventory_stack_to_weapon(player: Node, stack_index: int, weapon_slot_id: StringName = &"") -> bool:
	var inventory_model = player.get("inventory_model")
	var equipment_model = player.get("equipment_model")
	if not can_attach_inventory_stack_to_weapon(player, stack_index, weapon_slot_id):
		return false
	var target_weapon_slot: StringName = weapon_slot_id if weapon_slot_id != &"" else StringName(player.call("_get_equipped_weapon_slot_id"))
	var removed_stack: Dictionary = inventory_model.remove_stack_at(stack_index)
	if removed_stack.is_empty():
		return false
	if not bool(equipment_model.call("attach_weapon_mod", target_weapon_slot, removed_stack)):
		inventory_model.add_stack(removed_stack)
		return false
	player.call("_sync_weapon_from_equipment")
	return true


static func attach_inventory_stack_to_weapon_hardpoint(player: Node, stack_index: int, weapon_slot_id: StringName, hardpoint_slot: StringName) -> bool:
	var inventory_model = player.get("inventory_model")
	var equipment_model = player.get("equipment_model")
	if not can_attach_inventory_stack_to_weapon_hardpoint(player, stack_index, weapon_slot_id, hardpoint_slot):
		return false
	var removed_stack: Dictionary = inventory_model.remove_stack_at(stack_index)
	if removed_stack.is_empty():
		return false
	if not bool(equipment_model.call("attach_weapon_mod_to_hardpoint", weapon_slot_id, hardpoint_slot, removed_stack)):
		inventory_model.add_stack(removed_stack)
		return false
	player.call("_sync_weapon_from_equipment")
	return true


static func unequip_weapon_mod_to_inventory(player: Node, weapon_slot_id: StringName, hardpoint_slot: StringName) -> bool:
	var inventory_model = player.get("inventory_model")
	var equipment_model = player.get("equipment_model")
	if equipment_model == null or not equipment_model.has_method("unequip_weapon_mod"):
		return false
	var removed_stack: Dictionary = equipment_model.call("unequip_weapon_mod", weapon_slot_id, hardpoint_slot)
	if removed_stack.is_empty():
		return false
	if not inventory_model.add_stack(removed_stack):
		equipment_model.call("attach_weapon_mod", weapon_slot_id, removed_stack)
		return false
	player.call("_sync_weapon_from_equipment")
	return true


static func can_unequip_equipment_slot(player: Node, slot_id: StringName) -> bool:
	var inventory_model = player.get("inventory_model")
	var equipment_model = player.get("equipment_model")
	if equipment_model == null or not equipment_model.has_slot(slot_id):
		return false
	var stack: Dictionary = equipment_model.get_slot(slot_id)
	if stack.is_empty():
		return false
	return inventory_model.can_accept_stack(stack)


static func unequip_equipment_slot(player: Node, slot_id: StringName) -> bool:
	var inventory_model = player.get("inventory_model")
	var equipment_model = player.get("equipment_model")
	if not can_unequip_equipment_slot(player, slot_id):
		return false
	var removed_stack: Dictionary = equipment_model.unequip(slot_id)
	if removed_stack.is_empty():
		return false
	if not inventory_model.add_stack(removed_stack):
		equipment_model.equip_stack(slot_id, removed_stack)
		return false
	return true


static func can_drop_equipment_slot(player: Node, slot_id: StringName) -> bool:
	var equipment_model = player.get("equipment_model")
	if equipment_model == null or not equipment_model.has_slot(slot_id):
		return false
	var stack: Dictionary = equipment_model.get_slot(slot_id)
	return not stack.is_empty()


static func drop_equipment_slot(player: Node, slot_id: StringName) -> bool:
	var equipment_model = player.get("equipment_model")
	if not can_drop_equipment_slot(player, slot_id):
		return false
	var removed_stack: Dictionary = equipment_model.unequip(slot_id)
	return not removed_stack.is_empty()


static func default_equipment_slot_for_stack(player: Node, stack: Dictionary) -> StringName:
	var equipment_model = player.get("equipment_model")
	var item_def := player.call("_load_item_from_stack", stack) as ItemDef
	if item_def == null:
		return &""
	if item_def.item_type == "weapon":
		if item_def.tags.has(&"melee"):
			if equipment_model.is_empty(&"melee"):
				return &"melee"
		else:
			if equipment_model.is_empty(&"primary_weapon"):
				return &"primary_weapon"
			if equipment_model.is_empty(&"sidearm"):
				return &"sidearm"
	if item_def.item_type == "armor":
		if (item_def.tags.has(&"helmet") or str(item_def.id).contains("helmet")) and equipment_model.is_empty(&"helmet"):
			return &"helmet"
		if equipment_model.is_empty(&"armor"):
			return &"armor"
	if item_def.item_type == "backpack" and equipment_model.is_empty(&"backpack"):
		return &"backpack"
	if item_def.item_type == "attachment":
		if _has_item_slot_tag(item_def, &"glasses") and equipment_model.is_empty(&"glasses"):
			return &"glasses"
		if _has_item_slot_tag(item_def, &"headset") and equipment_model.is_empty(&"headset"):
			return &"headset"
		if equipment_model.is_empty(&"charm_1"):
			return &"charm_1"
		if equipment_model.is_empty(&"charm_2"):
			return &"charm_2"
	if item_def.item_type == "totem":
		if equipment_model.is_empty(&"charm_1"):
			return &"charm_1"
		if equipment_model.is_empty(&"charm_2"):
			return &"charm_2"
	return &""


static func _has_item_slot_tag(item_def: ItemDef, slot_tag: StringName) -> bool:
	if item_def == null:
		return false
	if item_def.get_attachment_slot_tags().has(slot_tag):
		return true
	return item_def.tags.has(slot_tag)
