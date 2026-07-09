class_name BaseNeededItemService
extends RefCounted

const SAVE_KEY := "needed_item_marks"

const BaseStorageUpgradeServiceScript := preload("res://scripts/base/base_storage_upgrade_service.gd")
const BaseWorkbenchServiceScript := preload("res://scripts/base/base_workbench_service.gd")
const BaseRecipeServiceScript := preload("res://scripts/base/base_recipe_service.gd")
const QuestCatalogScript := preload("res://scripts/quests/quest_catalog.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")


static func get_state(save_manager: Node) -> Dictionary:
	return get_state_from_save_data(_get_save_data(save_manager))


static func get_state_from_save_data(save_data: Dictionary) -> Dictionary:
	var storage_upgrade := _storage_upgrade_needed_paths(save_data)
	var workbench := _workbench_needed_paths(save_data)
	var upgrade := _merge_path_maps([storage_upgrade, workbench])
	var quest := _quest_needed_paths(save_data)
	var recipe := _recipe_needed_paths(save_data)
	var automatic := _merge_path_maps([upgrade, quest, recipe])
	var manual := _manual_marks(save_data)
	var combined := automatic.duplicate(true)
	for item_path in manual.keys():
		combined[str(item_path)] = true
	return {
		"item_paths": _sorted_keys(combined),
		"automatic_item_paths": _sorted_keys(automatic),
		"upgrade_item_paths": _sorted_keys(upgrade),
		"storage_upgrade_item_paths": _sorted_keys(storage_upgrade),
		"workbench_item_paths": _sorted_keys(workbench),
		"recipe_item_paths": _sorted_keys(recipe),
		"quest_item_paths": _sorted_keys(quest),
		"manual_item_paths": _sorted_keys(manual),
	}


static func toggle_manual_mark(save_manager: Node, item_path: String) -> Dictionary:
	var normalized_path := item_path.strip_edges()
	if normalized_path == "":
		return {"success": false, "reason": "invalid_item_path"}
	if save_manager == null or not save_manager.has_method("get_slot_data") or not save_manager.has_method("save_slot_data"):
		return {"success": false, "reason": "no_save"}
	var slot_index := _current_slot_index(save_manager)
	var save_data: Dictionary = save_manager.call("get_slot_data", slot_index)
	if save_data.is_empty():
		return {"success": false, "reason": "no_save"}
	var marks := _manual_marks(save_data)
	var is_marked := false
	if bool(marks.get(normalized_path, false)):
		marks.erase(normalized_path)
	else:
		marks[normalized_path] = true
		is_marked = true
	save_data[SAVE_KEY] = marks
	if not bool(save_manager.call("save_slot_data", slot_index, save_data)):
		return {"success": false, "reason": "save_failed"}
	return {
		"success": true,
		"is_marked": is_marked,
		"state": get_state_from_save_data(save_manager.call("get_slot_data", slot_index)),
	}


static func is_needed(save_data: Dictionary, item_path: String) -> bool:
	var state := get_state_from_save_data(save_data)
	return (state.get("item_paths", []) as Array).has(item_path)


static func _storage_upgrade_needed_paths(save_data: Dictionary) -> Dictionary:
	var result := {}
	if save_data.is_empty():
		return result
	var next_upgrade := _next_storage_upgrade(save_data)
	if next_upgrade == null:
		return result
	return _missing_upgrade_cost_paths(save_data, next_upgrade)


static func _workbench_needed_paths(save_data: Dictionary) -> Dictionary:
	var result := {}
	if save_data.is_empty():
		return result
	var next_upgrade := BaseWorkbenchServiceScript.get_next_upgrade_for_save_data(save_data)
	if next_upgrade == null:
		return result
	return _missing_upgrade_cost_paths(save_data, next_upgrade)


static func _recipe_needed_paths(save_data: Dictionary) -> Dictionary:
	var result := {}
	if save_data.is_empty():
		return result
	for item_path in BaseRecipeServiceScript.get_needed_item_paths(save_data):
		result[item_path] = true
	return result


static func _missing_upgrade_cost_paths(save_data: Dictionary, upgrade_def: Resource) -> Dictionary:
	var result := {}
	var stash: Array = _stash_array(save_data.get("stash", []))
	for cost in _item_costs(upgrade_def):
		var item_path := str(cost.get("item_path", ""))
		var required := int(cost.get("quantity", 0))
		if item_path == "" or required <= 0:
			continue
		if _stash_quantity(stash, item_path) < required:
			result[item_path] = true
	return result


static func _quest_needed_paths(save_data: Dictionary) -> Dictionary:
	var result := {}
	if save_data.is_empty():
		return result
	var quests := _dictionary(save_data.get("quests", {}))
	for quest_def in QuestCatalogScript.quest_defs():
		if quest_def == null or not quest_def.has_method("is_valid") or not bool(quest_def.call("is_valid")):
			continue
		var quest_id := str(quest_def.get("id"))
		var raw_state := _dictionary(quests.get(quest_id, QuestStateScript.create_inactive(quest_def)))
		var state := QuestStateScript.normalize(raw_state, quest_def)
		var state_name := str(state.get("state", QuestStateScript.STATE_ACTIVE))
		if [QuestStateScript.STATE_INACTIVE, QuestStateScript.STATE_READY, QuestStateScript.STATE_COMPLETED].has(state_name):
			continue
		_add_quest_objective_paths(result, quest_def, state)
	return result


static func _add_quest_objective_paths(result: Dictionary, quest_def: Resource, quest_state: Dictionary) -> void:
	var objective_type := str(quest_def.get("objective_type"))
	if not ["collect", "extract", "extract_any"].has(objective_type):
		return
	var progress := _dictionary(quest_state.get("progress", {}))
	var objectives := _objectives(quest_def)
	if objective_type == "extract_any" and _has_any_completed_item_objective(objectives, progress):
		return
	for objective in objectives:
		var item_path := str(objective.get("item_path", ""))
		var required := int(objective.get("quantity", 0))
		if item_path == "" or required <= 0:
			continue
		if int(progress.get(item_path, 0)) < required:
			result[item_path] = true


static func _has_any_completed_item_objective(objectives: Array, progress: Dictionary) -> bool:
	for objective in objectives:
		var item_path := str(objective.get("item_path", ""))
		var required := int(objective.get("quantity", 0))
		if item_path != "" and required > 0 and int(progress.get(item_path, 0)) >= required:
			return true
	return false


static func _next_storage_upgrade(save_data: Dictionary) -> Resource:
	return BaseStorageUpgradeServiceScript.get_next_upgrade_for_save_data(save_data)


static func _manual_marks(save_data: Dictionary) -> Dictionary:
	var result := {}
	var value: Variant = save_data.get(SAVE_KEY, {})
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in (value as Dictionary).keys():
		var item_path := str(key).strip_edges()
		if item_path != "" and bool((value as Dictionary).get(key, false)):
			result[item_path] = true
	return result


static func _item_costs(upgrade_def: Resource) -> Array:
	if upgrade_def == null:
		return []
	var value: Variant = upgrade_def.get("item_costs")
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _objectives(quest_def: Resource) -> Array:
	if quest_def == null:
		return []
	var value: Variant = quest_def.get("objectives")
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _stash_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _dictionary(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


static func _stash_quantity(stash: Array, item_path: String) -> int:
	var total := 0
	for entry in stash:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stack := entry as Dictionary
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path:
			total += int(stack.get("quantity", 0))
	return total


static func _get_save_data(save_manager: Node) -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_slot_data"):
		return {}
	var data: Dictionary = save_manager.call("get_slot_data", _current_slot_index(save_manager))
	return data.duplicate(true)


static func _current_slot_index(save_manager: Node) -> int:
	if save_manager != null and save_manager.has_method("get_current_slot_index"):
		return int(save_manager.call("get_current_slot_index"))
	return 1


static func _sorted_keys(source: Dictionary) -> Array[String]:
	var values: Array[String] = []
	for key in source.keys():
		values.append(str(key))
	values.sort()
	return values


static func _merge_path_maps(sources: Array) -> Dictionary:
	var result := {}
	for source_value in sources:
		if typeof(source_value) != TYPE_DICTIONARY:
			continue
		var source := source_value as Dictionary
		for item_path in source.keys():
			if bool(source.get(item_path, false)):
				result[str(item_path)] = true
	return result
