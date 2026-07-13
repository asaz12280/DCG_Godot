extends RefCounted


static func open(owner: Control) -> Dictionary:
	var inventory_ui := find_inventory_ui(owner)
	var opened_reference := false
	if inventory_ui == null or not inventory_ui.has_method("open_inventory"):
		return {"inventory_ui": inventory_ui, "opened": opened_reference}
	if is_open(inventory_ui):
		return {"inventory_ui": inventory_ui, "opened": opened_reference}
	inventory_ui.call("open_inventory")
	opened_reference = true
	return {"inventory_ui": inventory_ui, "opened": opened_reference}


static func close(owner: Control, inventory_ui: Control, opened_reference: bool, should_close_reference: bool) -> void:
	configure_actions(owner, inventory_ui, false)
	if should_close_reference and inventory_ui != null and opened_reference and inventory_ui.has_method("close_inventory"):
		inventory_ui.call("close_inventory")


static func find_inventory_ui(owner: Control) -> Control:
	var parent := owner.get_parent()
	if parent != null:
		var sibling := parent.get_node_or_null("InventoryEquipmentUI") as Control
		if sibling != null:
			return sibling
	var tree := owner.get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.find_child("InventoryEquipmentUI", true, false) as Control


static func is_open(inventory_ui: Control) -> bool:
	if inventory_ui == null:
		return false
	if inventory_ui.has_method("get_display_state"):
		var state: Dictionary = inventory_ui.call("get_display_state")
		return bool(state.get("is_open", false))
	return bool(inventory_ui.visible)


static func sync_scroll(inventory_ui: Control, backpack_scroll_row: int) -> void:
	if inventory_ui == null:
		return
	inventory_ui.set("backpack_scroll_row", backpack_scroll_row)
	inventory_ui.queue_redraw()


static func configure_actions(owner: Control, inventory_ui: Control, is_enabled: bool) -> void:
	if inventory_ui == null:
		return
	if inventory_ui.has_method("set_store_all_action_visible"):
		inventory_ui.call("set_store_all_action_visible", is_enabled)
	if inventory_ui.has_method("set_overlay_scrim_visible"):
		inventory_ui.call("set_overlay_scrim_visible", not is_enabled)
	if not inventory_ui.has_signal("store_all_requested"):
		return
	var callable := Callable(owner, "_on_inventory_reference_store_all_requested")
	if is_enabled:
		if not inventory_ui.is_connected("store_all_requested", callable):
			inventory_ui.connect("store_all_requested", callable)
	elif inventory_ui.is_connected("store_all_requested", callable):
		inventory_ui.disconnect("store_all_requested", callable)


static func open_weapon_slot(inventory_ui: Control, slot_id: StringName) -> bool:
	if inventory_ui == null:
		return false
	if inventory_ui.has_method("_open_weapon_mod_panel_for_slot"):
		return bool(inventory_ui.call("_open_weapon_mod_panel_for_slot", slot_id))
	return false
