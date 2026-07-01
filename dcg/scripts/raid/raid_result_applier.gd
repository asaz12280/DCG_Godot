class_name RaidResultApplier
extends Node

const StashModelScript := preload("res://scripts/base/stash_model.gd")
const RaidResultSchema := preload("res://scripts/raid/raid_result.gd")

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

	var stash := StashModelScript.new()
	var stash_data: Array = []
	var existing_stash: Variant = save_data.get("stash", [])
	if typeof(existing_stash) == TYPE_ARRAY:
		stash_data = existing_stash as Array
	stash.load_save_data(stash_data)

	var extracted_items: Variant = result.get("extracted_items", [])
	if typeof(extracted_items) == TYPE_ARRAY:
		for stack in extracted_items as Array:
			if typeof(stack) == TYPE_DICTIONARY:
				stash.add_stack(_to_stash_stack(stack))

	save_data["stash"] = stash.to_save_data()
	save_data["money"] = maxi(int(save_data.get("money", 0)) + int(result.get("money_delta", 0)), 0)
	var saved := bool(save_manager.save_slot_data(slot_index, save_data))
	if not saved:
		last_apply_result["reason"] = "save_failed"
		return false

	_clear_player_inventory()
	last_apply_result = {
		"attempted": true,
		"applied": true,
		"slot_index": slot_index,
		"stash_count": (save_data["stash"] as Array).size(),
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
	if player == null or not player.has_method("get_inventory_model"):
		return
	var inventory: Variant = player.get_inventory_model()
	if inventory != null and inventory.has_method("clear"):
		inventory.clear()


func _to_stash_stack(stack: Dictionary) -> Dictionary:
	var normalized := stack.duplicate(true)
	if not normalized.has("resource_path"):
		normalized["resource_path"] = str(normalized.get("item_path", ""))
	return normalized
