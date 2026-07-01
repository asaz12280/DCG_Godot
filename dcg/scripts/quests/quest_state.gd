class_name QuestState
extends RefCounted

const STATE_INACTIVE := "inactive"
const STATE_ACTIVE := "active"
const STATE_READY := "ready"
const STATE_COMPLETED := "completed"


static func create(quest_def: Resource) -> Dictionary:
	return {
		"id": str(quest_def.get("id")) if quest_def != null else "",
		"state": STATE_ACTIVE,
		"progress": {},
		"claimed": false,
	}


static func normalize(raw_state: Dictionary, quest_def: Resource = null) -> Dictionary:
	var quest_id := str(raw_state.get("id", quest_def.get("id") if quest_def != null else ""))
	var state := str(raw_state.get("state", STATE_ACTIVE))
	if not [STATE_INACTIVE, STATE_ACTIVE, STATE_READY, STATE_COMPLETED].has(state):
		state = STATE_ACTIVE
	var progress_value: Variant = raw_state.get("progress", {})
	var progress: Dictionary = progress_value.duplicate(true) if typeof(progress_value) == TYPE_DICTIONARY else {}
	return {
		"id": quest_id,
		"state": state,
		"progress": progress,
		"claimed": bool(raw_state.get("claimed", state == STATE_COMPLETED)),
	}


static func update_from_extracted_items(raw_state: Dictionary, quest_def: Resource, extracted_items: Array) -> Dictionary:
	var state := normalize(raw_state, quest_def)
	if quest_def == null or not bool(quest_def.call("is_valid")):
		return state
	if str(state.get("state", "")) == STATE_COMPLETED:
		return state

	var progress: Dictionary = state.get("progress", {}) as Dictionary
	for objective in _objectives(quest_def):
		var item_path := str(objective.get("item_path", ""))
		var required := int(objective.get("quantity", 0))
		var extracted_quantity := _count_item(extracted_items, item_path)
		var current := maxi(int(progress.get(item_path, 0)), extracted_quantity)
		progress[item_path] = mini(current, required)

	state["progress"] = progress
	if _is_ready(progress, quest_def):
		state["state"] = STATE_READY
	else:
		state["state"] = STATE_ACTIVE
	return state


static func can_claim(raw_state: Dictionary, quest_def: Resource) -> bool:
	var state := normalize(raw_state, quest_def)
	return str(state.get("state", "")) == STATE_READY and not bool(state.get("claimed", false))


static func claim_reward(save_data: Dictionary, raw_state: Dictionary, quest_def: Resource) -> Dictionary:
	var state := normalize(raw_state, quest_def)
	if not can_claim(state, quest_def):
		return {
			"success": false,
			"reason": "not_ready",
			"save_data": save_data.duplicate(true),
			"quest_state": state,
		}

	var updated_save := save_data.duplicate(true)
	updated_save["money"] = maxi(int(updated_save.get("money", 0)) + int(quest_def.get("reward_money")), 0)
	var stash: Array = _stash_array(updated_save.get("stash", []))
	for reward in _reward_items(quest_def):
		stash = _add_stack(stash, str(reward.get("item_path", "")), int(reward.get("quantity", 0)))
	updated_save["stash"] = stash
	state["state"] = STATE_COMPLETED
	state["claimed"] = true
	return {
		"success": true,
		"reason": "ok",
		"save_data": updated_save,
		"quest_state": state,
	}


static func to_save_data(raw_state: Dictionary, quest_def: Resource = null) -> Dictionary:
	return normalize(raw_state, quest_def)


static func _is_ready(progress: Dictionary, quest_def: Resource) -> bool:
	var objective_type := str(quest_def.get("objective_type"))
	var objectives: Array = _objectives(quest_def)
	if objective_type == "extract_any":
		for objective in objectives:
			var item_path := str(objective.get("item_path", ""))
			var required := int(objective.get("quantity", 0))
			if int(progress.get(item_path, 0)) >= required:
				return true
		return false
	for objective in objectives:
		var item_path := str(objective.get("item_path", ""))
		var required := int(objective.get("quantity", 0))
		if int(progress.get(item_path, 0)) < required:
			return false
	return true


static func _count_item(items: Array, item_path: String) -> int:
	var total := 0
	for entry in items:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str((entry as Dictionary).get("item_path", "")) == item_path:
			total += int((entry as Dictionary).get("quantity", 0))
	return total


static func _add_stack(stash: Array, item_path: String, quantity: int) -> Array:
	if item_path == "" or quantity <= 0:
		return stash
	var result: Array = stash.duplicate(true)
	for index in range(result.size()):
		if typeof(result[index]) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = result[index]
		if str(stack.get("item_path", "")) == item_path:
			stack["quantity"] = int(stack.get("quantity", 0)) + quantity
			result[index] = stack
			return result
	result.append({"item_path": item_path, "quantity": quantity})
	return result


static func _stash_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _objectives(quest_def: Resource) -> Array:
	var value: Variant = quest_def.get("objectives")
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _reward_items(quest_def: Resource) -> Array:
	var value: Variant = quest_def.get("reward_items")
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)
