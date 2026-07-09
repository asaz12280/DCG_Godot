extends RefCounted


static func toggle_lock(lock_map: Dictionary, key: Variant) -> bool:
	var lock_key := str(key)
	if bool(lock_map.get(lock_key, false)):
		lock_map.erase(lock_key)
		return false
	lock_map[lock_key] = true
	return true


static func is_locked(lock_map: Dictionary, key: Variant) -> bool:
	return bool(lock_map.get(str(key), false))


static func locked_index_array(lock_map: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for key in lock_map.keys():
		if bool(lock_map[key]):
			result.append(int(str(key)))
	result.sort()
	return result


static func locked_string_array(lock_map: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for key in lock_map.keys():
		if bool(lock_map[key]):
			result.append(str(key))
	return result


static func cleanup_index_locks(lock_map: Dictionary, item_count: int) -> void:
	for key in lock_map.keys():
		var index := int(key)
		if index < 0 or index >= item_count:
			lock_map.erase(key)


static func rebuild_index_locks_from_stacks(lock_map: Dictionary, current_items: Array[Dictionary], locked_stacks: Array[Dictionary]) -> void:
	lock_map.clear()
	var signatures: Array[String] = []
	for stack in locked_stacks:
		signatures.append(stack_signature(stack))
	for index in range(current_items.size()):
		var signature := stack_signature(current_items[index])
		if signatures.has(signature):
			lock_map[str(index)] = true
			signatures.erase(signature)


static func cleanup_equipment_locks(lock_map: Dictionary, equipment_slot_ids: Array[StringName]) -> void:
	for key in lock_map.keys():
		if not equipment_slot_ids.has(StringName(str(key))):
			lock_map.erase(key)


static func is_needed_stack(stack: Dictionary, needed_item_paths: Dictionary) -> bool:
	return needed_item_paths.has(stack_item_path(stack))


static func tooltip_context_for_path(item_path: String, needed_item_state: Dictionary) -> Dictionary:
	return {
		"is_needed": needed_sources_for_path(item_path, needed_item_state).size() > 0,
		"needed_sources": needed_sources_for_path(item_path, needed_item_state),
	}


static func needed_sources_for_path(item_path: String, needed_item_state: Dictionary) -> Array[StringName]:
	var normalized_path := item_path.strip_edges()
	var sources: Array[StringName] = []
	if normalized_path == "":
		return sources
	if needed_state_has_path(needed_item_state, "quest_item_paths", normalized_path):
		sources.append(&"quest")
	if needed_state_has_path(needed_item_state, "storage_upgrade_item_paths", normalized_path):
		sources.append(&"storage_upgrade")
	if needed_state_has_path(needed_item_state, "workbench_item_paths", normalized_path):
		sources.append(&"workbench")
	if needed_state_has_path(needed_item_state, "recipe_item_paths", normalized_path):
		sources.append(&"recipe")
	if needed_state_has_path(needed_item_state, "manual_item_paths", normalized_path):
		sources.append(&"manual")
	return sources


static func needed_state_has_path(needed_item_state: Dictionary, state_key: String, item_path: String) -> bool:
	var paths: Array = needed_item_state.get(state_key, []) as Array
	for path in paths:
		if str(path) == item_path:
			return true
	return false


static func stack_item_path(stack: Dictionary) -> String:
	return str(stack.get("resource_path", stack.get("item_path", ""))).strip_edges()


static func path_array(paths: Array) -> Array[String]:
	var result: Array[String] = []
	for path in paths:
		var normalized_path := str(path).strip_edges()
		if normalized_path != "":
			result.append(normalized_path)
	result.sort()
	return result


static func path_array_to_map(paths: Array) -> Dictionary:
	var result := {}
	for path in path_array(paths):
		result[path] = true
	return result


static func stack_signature(stack: Dictionary) -> String:
	return "%s|%d|%d" % [
		str(stack.get("resource_path", stack.get("item_path", ""))),
		int(stack.get("catalog_number", 0)),
		int(stack.get("quantity", 1)),
	]
