extends RefCounted

const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const RaidLoadoutTransferScript := preload("res://scripts/raid/raid_loadout_transfer.gd")


static func load_starter_inventory(player: Node) -> void:
	var inventory_model = player.get("inventory_model")
	if inventory_model.get_used_slots() > 0:
		return
	var starter_loadout: Resource = player.get("starter_loadout")
	if starter_loadout != null and starter_loadout.has_method("add_to_inventory"):
		starter_loadout.add_to_inventory(inventory_model)


static func load_saved_base_equipment(player: Node) -> bool:
	if player == null:
		return false
	var equipment_model = player.get("equipment_model")
	if equipment_model == null or not equipment_model.has_method("load_save_data"):
		return false
	var save_manager := player.get_node_or_null("/root/SaveGameManager")
	if save_manager == null or not save_manager.has_method("get_current_slot_index") or not save_manager.has_method("get_slot_data"):
		return false
	var slot_index := int(save_manager.get_current_slot_index())
	var save_data: Dictionary = save_manager.get_slot_data(slot_index)
	var equipment_data: Variant = save_data.get("equipment", {})
	if not _has_saved_equipment(equipment_data):
		return false
	return bool(equipment_model.call("load_save_data", equipment_data))


static func load_pending_raid_loadout(player: Node) -> bool:
	var save_manager := player.get_node_or_null("/root/SaveGameManager")
	if save_manager == null or not save_manager.has_method("consume_pending_raid_loadout"):
		return false
	var loadout: Dictionary = save_manager.call("consume_pending_raid_loadout")
	if loadout.is_empty():
		return false
	return RaidLoadoutTransferScript.apply_to_player(player, loadout)


static func apply_base_upgrade_effects(player: Node, weapon_controller: Node) -> void:
	if weapon_controller == null:
		return
	var save_manager := player.get_node_or_null("/root/SaveGameManager")
	if save_manager == null or not save_manager.has_method("get_current_slot_index") or not save_manager.has_method("get_slot_data"):
		return
	var slot_index := int(save_manager.get_current_slot_index())
	var save_data: Dictionary = save_manager.get_slot_data(slot_index)
	var starter_ammo_bonus := BaseProgressionScript.get_starter_ammo_bonus(save_data)
	if starter_ammo_bonus <= 0:
		return
	weapon_controller.set("reserve_ammo", int(weapon_controller.get("reserve_ammo")) + starter_ammo_bonus)
	if weapon_controller.has_method("_sync_ammo_result"):
		weapon_controller.call("_sync_ammo_result")


static func carried_weight(player: Node) -> float:
	var inventory_model = player.get("inventory_model")
	var safe_pocket_model = player.get("safe_pocket_model")
	return inventory_model.get_total_weight() + safe_pocket_model.get_total_weight() + equipment_weight(player)


static func equipment_weight(player: Node) -> float:
	var equipment_model = player.get("equipment_model")
	var total := 0.0
	for stack_value in equipment_model.get_slots().values():
		if typeof(stack_value) != TYPE_DICTIONARY:
			continue
		var equipment_stack: Dictionary = stack_value as Dictionary
		total += weapon_stack_total_weight(equipment_stack)
	return total


static func stack_weight_with_weapon_mods(stack: Dictionary) -> float:
	var total := float(stack.get("weight", 0.0)) * float(stack.get("quantity", 1))
	var mods: Dictionary = stack.get("weapon_mods", {}) as Dictionary
	for mod_stack_value in mods.values():
		if typeof(mod_stack_value) != TYPE_DICTIONARY:
			continue
		var mod_stack: Dictionary = mod_stack_value as Dictionary
		total += float(mod_stack.get("weight", 0.0)) * float(mod_stack.get("quantity", 1))
	return total


static func weapon_total_weight(stack: Dictionary, ammo_item: ItemDef, loaded_ammo: int) -> float:
	var total := stack_weight_with_weapon_mods(stack)
	if ammo_item != null:
		total += float(ammo_item.weight) * float(maxi(loaded_ammo, 0))
	return total


static func weapon_stack_total_weight(stack: Dictionary) -> float:
	var ammo_state: Dictionary = stack.get("weapon_ammo_state", {}) as Dictionary
	var ammo_item: ItemDef = null
	var ammo_path := str(ammo_state.get("ammo_item_path", "")).strip_edges()
	if ammo_path != "" and ResourceLoader.exists(ammo_path):
		var loaded_item := load(ammo_path) as ItemDef
		if loaded_item != null and loaded_item.item_type == "ammo":
			ammo_item = loaded_item
	return weapon_total_weight(stack, ammo_item, int(ammo_state.get("loaded_ammo", 0)))


static func _has_saved_equipment(equipment_data: Variant) -> bool:
	if typeof(equipment_data) != TYPE_DICTIONARY:
		return false
	var slots_value: Variant = (equipment_data as Dictionary).get("slots", {})
	if typeof(slots_value) != TYPE_DICTIONARY:
		return false
	for stack_value in (slots_value as Dictionary).values():
		if typeof(stack_value) == TYPE_DICTIONARY and not (stack_value as Dictionary).is_empty():
			return true
	return false
