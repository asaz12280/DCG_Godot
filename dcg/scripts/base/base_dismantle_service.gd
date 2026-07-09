class_name BaseDismantleService
extends RefCounted

const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const DismantleRecipeCatalogScript := preload("res://scripts/crafting/dismantle_recipe_catalog.gd")
const ItemStackSaveCodecScript := preload("res://scripts/inventory/item_stack_save_codec.gd")
const DisassembleStationUpgrade := preload("res://data/base_upgrades/workbench_disassemble_station.tres")

const SELECTED_DISMANTLE_KEY := "selected_dismantle_ids"
const DEFAULT_STASH_CAPACITY := 250


static func get_state_from_save_data(save_data: Dictionary, station_id: StringName = &"workbench") -> Dictionary:
	var rows := get_dismantle_rows(save_data, station_id)
	var selected_id := _selected_dismantle_id_for_context(save_data, station_id)
	var selected_row_value: Variant = _find_row(rows, selected_id)
	var selected_row: Dictionary = selected_row_value as Dictionary if typeof(selected_row_value) == TYPE_DICTIONARY else {}
	var can_dismantle := not selected_row.is_empty() and bool(selected_row.get("can_dismantle", false))
	return {
		"dismantle_unlocked": _is_dismantle_unlocked(save_data),
		"dismantle_rows": rows,
		"selected_dismantle_id": str(selected_id),
		"selected_dismantle_row": selected_row,
		"can_dismantle": can_dismantle,
		"reason": _dismantle_reason(save_data, selected_row),
		"selected_dismantle_ids": _dictionary(save_data.get(SELECTED_DISMANTLE_KEY, {})),
	}


static func get_dismantle_rows(save_data: Dictionary, station_id: StringName = &"workbench", selected_dismantle_id: StringName = &"") -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if station_id != &"workbench" or not _is_dismantle_unlocked(save_data):
		return rows
	var selected_id := selected_dismantle_id
	if selected_id == &"":
		selected_id = _saved_dismantle_selection(save_data, station_id)
	var stash: Array = _stash_array(save_data.get("stash", []))
	for index in range(stash.size()):
		var entry: Variant = stash[index]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		for recipe in _available_recipes(save_data, station_id):
			var row := _dismantle_row_from_stack(entry as Dictionary, index, recipe, save_data)
			if not row.is_empty():
				rows.append(row)
	if not rows.is_empty() and (selected_id == &"" or _find_row(rows, selected_id) == null):
		selected_id = StringName(str(rows[0].get("id", "")))
	for index in range(rows.size()):
		var row := rows[index]
		row["is_selected"] = selected_id != &"" and str(row.get("id", "")) == str(selected_id)
		rows[index] = row
	return rows


static func get_selected_dismantle_id(save_data: Dictionary, station_id: StringName = &"workbench") -> StringName:
	var rows := get_dismantle_rows(save_data, station_id, _saved_dismantle_selection(save_data, station_id))
	for row in rows:
		if bool(row.get("is_selected", false)):
			return StringName(str(row.get("id", "")))
	return &""


static func select_dismantle_item(save_manager: Node, station_id: StringName, dismantle_id: StringName) -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_slot_data") or not save_manager.has_method("save_slot_data"):
		return {"success": false, "reason": "no_save"}
	var slot_index := _current_slot_index(save_manager)
	var save_data: Dictionary = save_manager.call("get_slot_data", slot_index)
	var result := select_dismantle_item_in_save_data(save_data, station_id, dismantle_id)
	if not bool(result.get("success", false)):
		return result
	if not bool(save_manager.call("save_slot_data", slot_index, result.get("save_data", {}) as Dictionary)):
		return {"success": false, "reason": "save_failed", "save_data": save_data.duplicate(true)}
	return result


static func select_dismantle_item_in_save_data(save_data: Dictionary, station_id: StringName, dismantle_id: StringName) -> Dictionary:
	if save_data.is_empty():
		return {"success": false, "reason": "no_save", "save_data": {}}
	if not _is_dismantle_unlocked(save_data):
		return {"success": false, "reason": "dismantle_locked", "save_data": save_data.duplicate(true)}
	var rows := get_dismantle_rows(save_data, station_id, dismantle_id)
	if _find_row(rows, dismantle_id) == null:
		return {
			"success": false,
			"reason": "dismantle_unavailable",
			"save_data": save_data.duplicate(true),
			"dismantle_id": str(dismantle_id),
		}
	var updated := save_data.duplicate(true)
	var selected := _dictionary(updated.get(SELECTED_DISMANTLE_KEY, {}))
	selected[str(station_id)] = str(dismantle_id)
	updated[SELECTED_DISMANTLE_KEY] = selected
	return {
		"success": true,
		"reason": "ok",
		"save_data": updated,
		"selected_dismantle_id": str(dismantle_id),
		"dismantle_rows": get_dismantle_rows(updated, station_id, dismantle_id),
	}


static func dismantle_selected(save_manager: Node, station_id: StringName = &"workbench") -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_slot_data") or not save_manager.has_method("save_slot_data"):
		return {"success": false, "reason": "no_save", "action_type": "dismantle"}
	var slot_index := _current_slot_index(save_manager)
	var save_data: Dictionary = save_manager.call("get_slot_data", slot_index)
	var result := dismantle_selected_from_save_data(save_data, station_id)
	result["action_type"] = "dismantle"
	if not bool(result.get("success", false)):
		return result
	if not bool(save_manager.call("save_slot_data", slot_index, result.get("save_data", {}) as Dictionary)):
		return {"success": false, "reason": "save_failed", "save_data": save_data.duplicate(true), "action_type": "dismantle"}
	return result


static func dismantle_selected_from_save_data(save_data: Dictionary, station_id: StringName = &"workbench") -> Dictionary:
	var selected_id := _selected_dismantle_id_for_context(save_data, station_id)
	if selected_id == &"":
		return {"success": false, "reason": "no_dismantle_items", "save_data": save_data.duplicate(true)}
	return dismantle_from_save_data(save_data, selected_id)


static func dismantle_from_save_data(save_data: Dictionary, dismantle_id: StringName) -> Dictionary:
	if save_data.is_empty():
		return {"success": false, "reason": "no_save", "save_data": {}}
	if not _is_dismantle_unlocked(save_data):
		return {"success": false, "reason": "dismantle_locked", "save_data": save_data.duplicate(true)}
	var rows := get_dismantle_rows(save_data, &"workbench", dismantle_id)
	var row_value: Variant = _find_row(rows, dismantle_id)
	if typeof(row_value) != TYPE_DICTIONARY:
		return {"success": false, "reason": "dismantle_unavailable", "save_data": save_data.duplicate(true), "dismantle_id": str(dismantle_id)}
	var row := row_value as Dictionary
	if not bool(row.get("can_dismantle", false)):
		return {"success": false, "reason": str(row.get("blocked_reason", "stash_full")), "save_data": save_data.duplicate(true), "dismantle_id": str(dismantle_id)}
	var updated := save_data.duplicate(true)
	var stash: Array = _stash_array(updated.get("stash", []))
	var source_index := int(row.get("source_index", -1))
	if source_index < 0 or source_index >= stash.size():
		return {"success": false, "reason": "dismantle_unavailable", "save_data": save_data.duplicate(true), "dismantle_id": str(dismantle_id)}
	stash = _remove_input_at(stash, source_index, int(row.get("input_quantity", 1)))
	for output in row.get("output_stacks", []) as Array:
		var item_path := str((output as Dictionary).get("item_path", ""))
		var item_def := _load_item(item_path)
		if item_def == null:
			return {"success": false, "reason": "invalid_output", "save_data": save_data.duplicate(true), "dismantle_id": str(dismantle_id)}
		stash = _add_item_to_stash(stash, item_def, int((output as Dictionary).get("quantity", 0)))
	updated["stash"] = stash
	return {
		"success": true,
		"reason": "ok",
		"dismantle_id": str(dismantle_id),
		"input_item_path": str(row.get("input_item_path", "")),
		"input_name": str(row.get("input_name", "")),
		"output_text": str(row.get("output_text", "")),
		"save_data": updated,
		"state": get_state_from_save_data(updated, &"workbench"),
	}


static func get_needed_item_paths(save_data: Dictionary) -> Array[String]:
	var result := {}
	if save_data.is_empty() or _is_dismantle_unlocked(save_data):
		return []
	for cost in _item_costs(DisassembleStationUpgrade):
		var item_path := str(cost.get("item_path", ""))
		if item_path != "":
			result[item_path] = true
	return _sorted_keys(result)


static func _dismantle_row_from_stack(entry: Dictionary, source_index: int, recipe: Resource, save_data: Dictionary) -> Dictionary:
	if recipe == null or not _is_recipe_valid(recipe):
		return {}
	var item_path := ItemStackSaveCodecScript.get_item_path(entry)
	if item_path == "" or item_path != str(recipe.get("input_item_path")):
		return {}
	var input_quantity := int(recipe.get("input_quantity"))
	if int(entry.get("quantity", 1)) < input_quantity:
		return {}
	var item_def := _load_item(item_path)
	if item_def == null:
		return {}
	var outputs := _output_stacks(recipe)
	var stash_after_input := _remove_input_at(_stash_array(save_data.get("stash", [])), source_index, input_quantity)
	var capacity_check := _can_add_outputs(stash_after_input, outputs, save_data)
	var recipe_id := StringName(str(recipe.get("id")))
	return {
		"id": _dismantle_id(source_index, recipe_id),
		"recipe_id": str(recipe_id),
		"source": "stash",
		"source_index": source_index,
		"input_item_path": item_path,
		"input_name": _item_name(item_def),
		"input_quantity": input_quantity,
		"output_stacks": outputs,
		"output_text": _describe_outputs(outputs),
		"can_dismantle": bool(capacity_check.get("can_add", false)),
		"blocked_reason": str(capacity_check.get("reason", "ok")),
	}


static func _available_recipes(save_data: Dictionary, station_id: StringName) -> Array[Resource]:
	var result: Array[Resource] = []
	for recipe in DismantleRecipeCatalogScript.recipe_defs():
		if not _is_recipe_available_for_station(save_data, recipe, station_id):
			continue
		result.append(recipe)
	return result


static func _is_recipe_available_for_station(save_data: Dictionary, recipe: Resource, station_id: StringName) -> bool:
	if not _is_recipe_valid(recipe):
		return false
	if station_id != &"" and StringName(str(recipe.get("station_id"))) != station_id:
		return false
	var required_upgrade_id := StringName(str(recipe.get("required_upgrade_id")))
	if required_upgrade_id != &"" and not BaseProgressionScript.is_upgrade_purchased(save_data, required_upgrade_id):
		return false
	return true


static func _is_recipe_valid(recipe: Resource) -> bool:
	return recipe != null and recipe.has_method("is_valid") and bool(recipe.call("is_valid"))


static func _dismantle_reason(save_data: Dictionary, selected_row: Dictionary) -> String:
	if not _is_dismantle_unlocked(save_data):
		return "dismantle_locked"
	if selected_row.is_empty():
		return "no_dismantle_items"
	if not bool(selected_row.get("can_dismantle", false)):
		return str(selected_row.get("blocked_reason", "stash_full"))
	return "ready"


static func _is_dismantle_unlocked(save_data: Dictionary) -> bool:
	return BaseProgressionScript.is_upgrade_purchased(save_data, StringName(str(DisassembleStationUpgrade.id)))


static func _dismantle_id(source_index: int, recipe_id: StringName) -> String:
	return "stash:%d:%s" % [source_index, str(recipe_id)]


static func _find_row(rows: Array, dismantle_id: StringName) -> Variant:
	for row_value in rows:
		if typeof(row_value) == TYPE_DICTIONARY and str((row_value as Dictionary).get("id", "")) == str(dismantle_id):
			return row_value
	return null


static func _saved_dismantle_selection(save_data: Dictionary, station_id: StringName) -> StringName:
	var selected := _dictionary(save_data.get(SELECTED_DISMANTLE_KEY, {}))
	return StringName(str(selected.get(str(station_id), "")))


static func _selected_dismantle_id_for_context(save_data: Dictionary, station_id: StringName) -> StringName:
	var rows := get_dismantle_rows(save_data, station_id, _saved_dismantle_selection(save_data, station_id))
	for row in rows:
		if bool(row.get("is_selected", false)):
			return StringName(str(row.get("id", "")))
	return &""


static func _remove_input_at(stash: Array, source_index: int, quantity: int) -> Array:
	var result: Array = []
	for index in range(stash.size()):
		var value: Variant = stash[index]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := (value as Dictionary).duplicate(true)
		if index == source_index:
			var remaining := int(stack.get("quantity", 1)) - quantity
			if remaining <= 0:
				continue
			stack["quantity"] = remaining
		result.append(stack)
	return result


static func _can_add_outputs(stash_after_input: Array, outputs: Array, save_data: Dictionary) -> Dictionary:
	var simulated := stash_after_input.duplicate(true)
	for output_value in outputs:
		if typeof(output_value) != TYPE_DICTIONARY:
			return {"can_add": false, "reason": "invalid_output"}
		var output := output_value as Dictionary
		var item_def := _load_item(str(output.get("item_path", "")))
		if item_def == null:
			return {"can_add": false, "reason": "invalid_output"}
		simulated = _add_item_to_stash(simulated, item_def, int(output.get("quantity", 0)))
	var capacity := BaseProgressionScript.get_stash_capacity(save_data, DEFAULT_STASH_CAPACITY)
	return {"can_add": simulated.size() <= capacity, "reason": "ok" if simulated.size() <= capacity else "stash_full"}


static func _add_item_to_stash(stash: Array, item_def: ItemDef, quantity: int) -> Array:
	if item_def == null or quantity <= 0:
		return stash
	var result: Array = []
	for entry in stash:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stack := (entry as Dictionary).duplicate(true)
		var item_path := ItemStackSaveCodecScript.get_item_path(stack)
		var stack_quantity := int(stack.get("quantity", 0))
		if item_path != "" and stack_quantity > 0:
			stack["item_path"] = item_path
			stack["quantity"] = stack_quantity
			result.append(stack)
	var remaining := quantity
	var max_stack := item_def.get_max_stack()
	for index in range(result.size()):
		var stack: Dictionary = result[index]
		if ItemStackSaveCodecScript.get_item_path(stack) != item_def.resource_path:
			continue
		var stack_quantity := int(stack.get("quantity", 0))
		var room := max_stack - stack_quantity
		if room <= 0:
			continue
		var moved := mini(room, remaining)
		stack["quantity"] = stack_quantity + moved
		result[index] = stack
		remaining -= moved
		if remaining <= 0:
			return result
	while remaining > 0:
		var moved_to_new_stack := mini(max_stack, remaining)
		result.append({"item_path": item_def.resource_path, "quantity": moved_to_new_stack})
		remaining -= moved_to_new_stack
	return result


static func _output_stacks(recipe: Resource) -> Array:
	if recipe == null:
		return []
	var value: Variant = recipe.get("output_stacks")
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _item_costs(upgrade_def: Resource) -> Array:
	if upgrade_def == null:
		return []
	var value: Variant = upgrade_def.get("item_costs")
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _describe_outputs(outputs: Array) -> String:
	var parts: Array[String] = []
	for output_value in outputs:
		if typeof(output_value) != TYPE_DICTIONARY:
			continue
		var output := output_value as Dictionary
		parts.append("%s x%d" % [_item_name(_load_item(str(output.get("item_path", "")))), int(output.get("quantity", 0))])
	return ", ".join(parts)


static func _stash_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


static func _dictionary(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


static func _load_item(item_path: String) -> ItemDef:
	if item_path == "" or not ResourceLoader.exists(item_path):
		return null
	return load(item_path) as ItemDef


static func _item_name(item_def: ItemDef) -> String:
	if item_def == null:
		return "Unknown"
	var name_key := str(item_def.name_key)
	if name_key != "":
		var translated := TranslationServer.translate(name_key)
		if translated != name_key and translated != "":
			return translated
	return item_def.display_name if item_def.display_name != "" else str(item_def.id)


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
