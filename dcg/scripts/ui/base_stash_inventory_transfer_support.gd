extends RefCounted

const BaseStashInventoryMarkerSupportScript := preload("res://scripts/ui/base_stash_inventory_marker_support.gd")


static func store_backpack_stack(ui: Control, stack_index: int) -> bool:
	var backpack_items: Array = ui.get("backpack_items")
	if stack_index < 0 or stack_index >= backpack_items.size():
		return false
	if BaseStashInventoryMarkerSupportScript.is_locked(ui.get("locked_backpack_slots"), stack_index):
		_set_status(ui, &"ui.stash.locked_item")
		ui.queue_redraw()
		return false
	var backpack_model = ui.get("backpack_model")
	var removed_stack: Dictionary = backpack_model.remove_stack_at(stack_index)
	if removed_stack.is_empty():
		return false
	if not _add_removed_stack_to_stash(ui, removed_stack):
		backpack_model.add_stack(removed_stack)
		_set_status(ui, &"ui.stash.stash_full")
		_refresh_display(ui)
		return false
	_set_status(ui, &"ui.stash.saved")
	_refresh_display(ui)
	return true


static func store_all_backpack_items(ui: Control) -> Dictionary:
	var result: Dictionary = {
		"moved": 0,
		"skipped_locked": 0,
		"failed": 0,
	}
	# 從尾端開始搬移，避免背包壓縮後影響尚未處理的索引。
	# 鎖定項目會在搬移後依照原本物品堆疊重新對應回目前索引。
	var backpack_items: Array = ui.get("backpack_items")
	var locked_backpack_slots: Dictionary = ui.get("locked_backpack_slots")
	var original_locked: Dictionary = locked_backpack_slots.duplicate(true)
	var locked_stacks: Array[Dictionary] = []
	for index in range(backpack_items.size()):
		if bool(original_locked.get(str(index), false)):
			locked_stacks.append(backpack_items[index].duplicate(true))
	for index in range(backpack_items.size() - 1, -1, -1):
		if bool(original_locked.get(str(index), false)):
			result["skipped_locked"] = int(result.get("skipped_locked", 0)) + 1
			continue
		if store_backpack_stack(ui, index):
			result["moved"] = int(result.get("moved", 0)) + 1
		else:
			result["failed"] = int(result.get("failed", 0)) + 1
	BaseStashInventoryMarkerSupportScript.rebuild_index_locks_from_stacks(locked_backpack_slots, ui.get("backpack_items"), locked_stacks)
	if int(result.get("failed", 0)) > 0:
		_set_status(ui, &"ui.stash.store_all_partial")
	elif int(result.get("moved", 0)) > 0:
		_set_status(ui, &"ui.stash.store_all_done")
	elif int(result.get("skipped_locked", 0)) > 0:
		_set_status(ui, &"ui.stash.store_all_locked_only")
	else:
		_set_status(ui, &"ui.stash.store_all_empty")
	_refresh_display(ui)
	return result


static func store_safe_pocket_stack(ui: Control, stack_index: int) -> bool:
	var safe_pocket_items: Array = ui.get("safe_pocket_items")
	if stack_index < 0 or stack_index >= safe_pocket_items.size():
		return false
	if BaseStashInventoryMarkerSupportScript.is_locked(ui.get("locked_safe_pocket_slots"), stack_index):
		_set_status(ui, &"ui.stash.locked_item")
		ui.queue_redraw()
		return false
	var safe_pocket_model = ui.get("safe_pocket_model")
	var removed_stack: Dictionary = safe_pocket_model.remove_stack_at(stack_index)
	if removed_stack.is_empty():
		return false
	if not _add_removed_stack_to_stash(ui, removed_stack):
		safe_pocket_model.add_stack(removed_stack)
		_set_status(ui, &"ui.stash.stash_full")
		_refresh_display(ui)
		return false
	_set_status(ui, &"ui.stash.saved")
	_refresh_display(ui)
	return true


static func store_equipment_slot(ui: Control, slot_id: StringName) -> bool:
	var equipment_model = ui.get("equipment_model")
	if equipment_model == null or not equipment_model.has_method("unequip"):
		return false
	if BaseStashInventoryMarkerSupportScript.is_locked(ui.get("locked_equipment_slots"), str(slot_id)):
		_set_status(ui, &"ui.stash.locked_item")
		ui.queue_redraw()
		return false
	var removed_stack: Dictionary = equipment_model.call("unequip", slot_id)
	if removed_stack.is_empty():
		return false
	if not _add_removed_stack_to_stash(ui, removed_stack):
		if equipment_model.has_method("equip_stack"):
			equipment_model.call("equip_stack", slot_id, removed_stack)
		_set_status(ui, &"ui.stash.stash_full")
		_refresh_display(ui)
		return false
	_set_status(ui, &"ui.stash.saved")
	_refresh_display(ui)
	return true


static func withdraw_stash_stack(ui: Control, stack_index: int) -> bool:
	var stash_items: Array = ui.get("stash_items")
	if stack_index < 0 or stack_index >= stash_items.size():
		return false
	if BaseStashInventoryMarkerSupportScript.is_locked(ui.get("locked_stash_slots"), stack_index):
		_set_status(ui, &"ui.stash.locked_item")
		ui.queue_redraw()
		return false
	# 先寫入倉庫存檔，再加入背包；任何失敗路徑都還原舊倉庫快照，
	# 避免存檔資料與記憶體模型不同步。
	var stash_model = ui.get("stash_model")
	var backpack_model = ui.get("backpack_model")
	var previous_stash: Array[Dictionary] = stash_model.to_save_data()
	var removed_stack: Dictionary = stash_model.remove_stack_at(stack_index)
	if removed_stack.is_empty():
		return false
	if not backpack_model.can_accept_stack(removed_stack):
		stash_model.load_save_data(previous_stash)
		_set_status(ui, &"ui.stash.backpack_full")
		_refresh_display(ui)
		return false
	if not bool(ui.call("_save_stash")):
		stash_model.load_save_data(previous_stash)
		_set_status(ui, &"ui.stash.save_failed")
		_refresh_display(ui)
		return false
	if not backpack_model.add_stack(removed_stack):
		stash_model.load_save_data(previous_stash)
		ui.call("_save_stash")
		_set_status(ui, &"ui.stash.withdraw_failed")
		_refresh_display(ui)
		return false
	_set_status(ui, &"ui.stash.saved")
	_refresh_display(ui)
	return true


static func _add_removed_stack_to_stash(ui: Control, removed_stack: Dictionary) -> bool:
	if not _stash_can_accept_stack(ui, removed_stack):
		return false
	# 對 UI 來說，倉庫寫入必須像交易一樣處理：
	# 先變更模型並存檔，若存檔失敗就回復舊模型。
	var stash_model = ui.get("stash_model")
	var previous_stash: Array[Dictionary] = stash_model.to_save_data()
	if not stash_model.add_stack(removed_stack):
		return false
	if not bool(ui.call("_save_stash")):
		stash_model.load_save_data(previous_stash)
		_set_status(ui, &"ui.stash.save_failed")
		return false
	return true


static func _stash_can_accept_stack(ui: Control, stack: Dictionary) -> bool:
	if stack.is_empty():
		return false
	var stash_model = ui.get("stash_model")
	var stash_capacity := int(ui.get("stash_capacity"))
	var item_def := _load_item_from_stack(stack)
	if item_def == null:
		return stash_model.get_stack_count() < stash_capacity
	var remaining := int(stack.get("quantity", 1))
	var item_max_stack := item_def.get_max_stack()
	var existing_stacks: Array = stash_model.get("stacks")
	for existing_stack in existing_stacks:
		if item_max_stack <= 1:
			break
		if str(existing_stack.get("resource_path", "")) != item_def.resource_path:
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
	var free_slots := maxi(stash_capacity - stash_model.get_stack_count(), 0)
	while remaining > 0 and free_slots > 0:
		remaining -= mini(item_max_stack, remaining)
		free_slots -= 1
	return remaining <= 0


static func _load_item_from_stack(stack: Dictionary) -> ItemDef:
	var item_path := str(stack.get("resource_path", stack.get("item_path", "")))
	if item_path == "" or not ResourceLoader.exists(item_path):
		return null
	return load(item_path) as ItemDef


static func _refresh_display(ui: Control) -> void:
	ui.call("_refresh_display_items")
	ui.queue_redraw()


static func _set_status(ui: Control, status_key: StringName) -> void:
	ui.set("_status_key", status_key)
