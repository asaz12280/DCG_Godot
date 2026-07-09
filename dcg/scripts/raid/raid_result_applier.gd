class_name RaidResultApplier
extends Node

const StashModelScript := preload("res://scripts/base/stash_model.gd")
const RaidResultSchema := preload("res://scripts/raid/raid_result.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")
const FirstSalvageQuest := preload("res://data/quests/first_salvage.tres")
const CASH_ITEM_PATH := "res://data/items/currency/cash.tres"

@export var raid_session_path: NodePath = NodePath("../RaidSession")
@export var player_path: NodePath = NodePath("../Player3D")

var last_apply_result: Dictionary = {}


func _ready() -> void:
	var session := get_node_or_null(raid_session_path)
	if session != null and session.has_signal("raid_completed"):
		session.raid_completed.connect(apply_raid_result)


func apply_raid_result(result: Dictionary) -> bool:
	last_apply_result = {
		"attempted": true,
		"applied": false,
		"reason": "",
	}
	if str(result.get("outcome", "")) == RaidResultSchema.OUTCOME_DEAD:
		var safe_pocket_stored := _store_safe_pocket_items(result.get("kept_safe_pocket_items", []))
		_clear_player_inventory()
		last_apply_result = {
			"attempted": true,
			"applied": true,
			"death_loss": true,
			"safe_pocket_stored": safe_pocket_stored,
			"reason": "dead_inventory_cleared_safe_pocket_returned" if safe_pocket_stored else "dead_inventory_cleared",
		}
		return true
	if str(result.get("outcome", "")) != RaidResultSchema.OUTCOME_EXTRACTED:
		last_apply_result["reason"] = "not_extracted"
		return false

	var save_manager := _get_save_manager()
	if save_manager == null:
		last_apply_result["reason"] = "missing_save_manager"
		return false
	if not save_manager.has_method("get_current_slot_index") or not save_manager.has_method("get_slot_data") or not save_manager.has_method("save_slot_data"):
		last_apply_result["reason"] = "invalid_save_manager"
		return false

	var slot_index := int(save_manager.get_current_slot_index())
	var save_data: Dictionary = save_manager.get_slot_data(slot_index)
	if save_data.is_empty():
		last_apply_result["reason"] = "missing_save_slot"
		return false

	var extracted_items: Variant = result.get("extracted_items", [])
	var extracted_money := 0
	if typeof(extracted_items) == TYPE_ARRAY:
		for stack in extracted_items as Array:
			if typeof(stack) == TYPE_DICTIONARY:
				var stack_dict := stack as Dictionary
				if _is_cash_stack(stack_dict):
					extracted_money += _cash_value(stack_dict)

	var stored_item_count := _store_extracted_items(save_data, extracted_items)
	_store_extracted_equipment(save_data, result.get(RaidResultSchema.KEY_EXTRACTED_EQUIPMENT, {}))
	save_data["money"] = maxi(int(save_data.get("money", 0)) + int(result.get("money_delta", 0)) + extracted_money, 0)
	_update_first_salvage_quest(save_data, extracted_items)
	var saved := bool(save_manager.save_slot_data(slot_index, save_data))
	if not saved:
		last_apply_result["reason"] = "save_failed"
		return false

	if save_manager.has_method("set_pending_raid_loadout"):
		save_manager.call("set_pending_raid_loadout", _extracted_loadout_from_result(result))
	_clear_player_inventory()
	last_apply_result = {
		"attempted": true,
		"applied": true,
		"slot_index": slot_index,
		"stash_count": (save_data.get("stash", []) as Array).size() if typeof(save_data.get("stash", [])) == TYPE_ARRAY else 0,
		"stored_item_count": stored_item_count,
		"pending_loadout": true,
	}
	return true


func _get_save_manager() -> Node:
	var main_loop := Engine.get_main_loop() as SceneTree
	var tree_root := main_loop.root if main_loop != null else null
	if tree_root != null:
		var manager := tree_root.get_node_or_null("SaveGameManager")
		if manager != null:
			return manager
		manager = tree_root.find_child("SaveGameManager", true, false)
		if manager != null:
			return manager
	if is_inside_tree():
		return get_node_or_null("/root/SaveGameManager")
	return null


func _clear_player_inventory() -> void:
	var player := get_node_or_null(player_path)
	if player == null:
		return
	var inventory: Variant = player.get_inventory_model() if player.has_method("get_inventory_model") else null
	if inventory != null and inventory.has_method("clear"):
		inventory.clear()
	var safe_pocket: Variant = player.get_safe_pocket_model() if player.has_method("get_safe_pocket_model") else null
	if safe_pocket != null and safe_pocket.has_method("clear"):
		safe_pocket.clear()
	var equipment: Variant = player.get_equipment_model() if player.has_method("get_equipment_model") else null
	if equipment != null and equipment.has_method("clear"):
		equipment.clear()


func _to_stash_stack(stack: Dictionary) -> Dictionary:
	var normalized := stack.duplicate(true)
	if not normalized.has("resource_path"):
		normalized["resource_path"] = str(normalized.get("item_path", ""))
	return normalized


func _extracted_loadout_from_result(result: Dictionary) -> Dictionary:
	return {
		"version": 1,
		"source": "raid_extraction",
		"backpack": [],
		"safe_pocket": [],
		"equipment": _extracted_equipment_dict(result.get(RaidResultSchema.KEY_EXTRACTED_EQUIPMENT, {})),
	}


func _is_cash_stack(stack: Dictionary) -> bool:
	var path := str(stack.get("item_path", ""))
	if path == "":
		path = str(stack.get("resource_path", ""))
	return path == CASH_ITEM_PATH


func _cash_value(stack: Dictionary) -> int:
	return maxi(int(stack.get("quantity", 0)), 0) * maxi(int(stack.get("value", 1)), 1)


func _store_safe_pocket_items(items: Variant) -> bool:
	if typeof(items) != TYPE_ARRAY:
		return false
	var safe_items := items as Array
	if safe_items.is_empty():
		return true
	var save_manager := _get_save_manager()
	if save_manager == null:
		return false
	if not save_manager.has_method("get_current_slot_index") or not save_manager.has_method("get_slot_data") or not save_manager.has_method("save_slot_data"):
		return false

	var slot_index := int(save_manager.get_current_slot_index())
	var save_data: Dictionary = save_manager.get_slot_data(slot_index)
	if save_data.is_empty():
		return false

	var stash := StashModelScript.new()
	var stash_data: Array = []
	var existing_stash: Variant = save_data.get("stash", [])
	if typeof(existing_stash) == TYPE_ARRAY:
		stash_data = existing_stash as Array
	stash.load_save_data(stash_data)
	for stack in safe_items:
		if typeof(stack) == TYPE_DICTIONARY:
			stash.add_stack(_to_stash_stack(stack as Dictionary))
	save_data["stash"] = stash.to_save_data()
	return bool(save_manager.save_slot_data(slot_index, save_data))


func _store_extracted_items(save_data: Dictionary, items: Variant) -> int:
	if typeof(items) != TYPE_ARRAY:
		return 0
	var stash := StashModelScript.new()
	var stash_data: Array = []
	var existing_stash: Variant = save_data.get("stash", [])
	if typeof(existing_stash) == TYPE_ARRAY:
		stash_data = existing_stash as Array
	stash.load_save_data(stash_data)

	var stored_count := 0
	for stack in items as Array:
		if typeof(stack) != TYPE_DICTIONARY:
			continue
		var stack_dict := stack as Dictionary
		if _is_cash_stack(stack_dict):
			continue
		if stash.add_stack(_to_stash_stack(stack_dict)):
			stored_count += 1

	save_data["stash"] = stash.to_save_data()
	return stored_count


func _store_extracted_equipment(save_data: Dictionary, equipment_data: Variant) -> void:
	if typeof(equipment_data) != TYPE_DICTIONARY:
		return
	var equipment_dict := equipment_data as Dictionary
	if not equipment_dict.has("slots"):
		return
	save_data["equipment"] = equipment_dict.duplicate(true)


func _extracted_equipment_dict(equipment_data: Variant) -> Dictionary:
	if typeof(equipment_data) != TYPE_DICTIONARY:
		return {"slots": {}}
	var equipment_dict := equipment_data as Dictionary
	if not equipment_dict.has("slots"):
		return {"slots": {}}
	return equipment_dict.duplicate(true)


func _update_first_salvage_quest(save_data: Dictionary, extracted_items: Variant) -> void:
	if typeof(extracted_items) != TYPE_ARRAY:
		return
	var quests: Dictionary = _quests_dict(save_data.get("quests", {}))
	var quest_id := str(FirstSalvageQuest.get("id"))
	if not quests.has(quest_id):
		return
	var current_state: Dictionary = quests.get(quest_id, {}) as Dictionary
	quests[quest_id] = QuestStateScript.update_from_extracted_items(current_state, FirstSalvageQuest, extracted_items as Array)
	save_data["quests"] = quests


func _quests_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
