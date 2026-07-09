class_name UIManagerContainerTransfer
extends RefCounted


static func transfer_slot(manager, slot_index: int, stack: Dictionary) -> void:
	if manager.active_ui != manager.UI_CONTAINER:
		return
	if manager._active_container == null or not is_instance_valid(manager._active_container):
		return
	if stack.is_empty():
		manager._set_container_status(manager._text(&"ui.container.slot_empty", "Slot is empty."))
		return
	if not manager._active_container.has_method("get_container_inventory_model"):
		manager._set_container_status(manager._text(&"ui.container.transfer_unavailable", "Transfer unavailable."))
		return
	var container_model: RefCounted = manager._active_container.call("get_container_inventory_model")
	var backpack_model: RefCounted = _get_player_inventory_model(manager)
	if container_model == null or backpack_model == null:
		manager._set_container_status(manager._text(&"ui.container.transfer_unavailable", "Transfer unavailable."))
		return
	if not _can_backpack_accept_stack(backpack_model, stack):
		manager._set_container_status(manager._text(&"ui.container.backpack_full", "Backpack is full."))
		return
	var removed_stack: Dictionary = container_model.call("remove_from_slot", slot_index, int(stack.get("quantity", 1)))
	if removed_stack.is_empty():
		manager._set_container_status(manager._text(&"ui.container.slot_empty", "Slot is empty."))
		return
	if not _add_stack_to_backpack(backpack_model, removed_stack):
		container_model.call("add_stack", removed_stack)
		manager._set_container_status(manager._text(&"ui.container.backpack_full", "Backpack is full."))
		return
	manager._set_container_status(manager._text(&"ui.container.moved_to_backpack", "Moved to backpack."))


static func _get_player_inventory_model(manager) -> RefCounted:
	var search_root: Node = null
	if manager.is_inside_tree() and manager.get_tree() != null:
		search_root = manager.get_tree().current_scene
		if search_root == null:
			search_root = manager.get_tree().root
	if search_root == null:
		return null
	var player := search_root.find_child("Player3D", true, false)
	if player == null or not player.has_method("get_inventory_model"):
		return null
	return player.call("get_inventory_model") as RefCounted


static func _can_backpack_accept_stack(backpack_model: RefCounted, stack: Dictionary) -> bool:
	var remaining := int(stack.get("quantity", 1))
	if remaining <= 0:
		return false
	var item_path := str(stack.get("resource_path", stack.get("item_path", "")))
	var max_stack := maxi(int(stack.get("max_stack", 1)), 1)
	var existing_stacks: Array = backpack_model.call("get_display_items")
	for existing in existing_stacks:
		if typeof(existing) != TYPE_DICTIONARY:
			continue
		var existing_stack := existing as Dictionary
		if str(existing_stack.get("resource_path", "")) != item_path or max_stack <= 1:
			continue
		var room := max_stack - int(existing_stack.get("quantity", 1))
		if room <= 0:
			continue
		remaining -= mini(room, remaining)
		if remaining <= 0:
			return true
	var free_slots := maxi(int(backpack_model.get("slot_limit")) - existing_stacks.size(), 0)
	while remaining > 0 and free_slots > 0:
		remaining -= mini(max_stack, remaining)
		free_slots -= 1
	return remaining <= 0


static func _add_stack_to_backpack(backpack_model: RefCounted, stack: Dictionary) -> bool:
	var item_path := str(stack.get("resource_path", stack.get("item_path", "")))
	if item_path == "" or not ResourceLoader.exists(item_path):
		return backpack_model.call("add_stack", stack)
	var item_def := load(item_path) as ItemDef
	if item_def == null:
		return backpack_model.call("add_stack", stack)
	return bool(backpack_model.call("add_item", item_def, int(stack.get("quantity", 1))))
