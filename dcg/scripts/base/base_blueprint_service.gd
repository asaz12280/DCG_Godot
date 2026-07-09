class_name BaseBlueprintService
extends RefCounted

const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const BaseRecipeServiceScript := preload("res://scripts/base/base_recipe_service.gd")

const RESEARCHED_BLUEPRINTS_KEY := "researched_blueprints"


static func get_state_from_save_data(save_data: Dictionary, station_id: StringName = &"") -> Dictionary:
	var rows := _blueprint_rows(save_data, station_id)
	return {
		"has_save": not save_data.is_empty(),
		"station_id": str(station_id),
		"blueprint_rows": rows,
		"researched_blueprints": _dictionary(save_data.get(RESEARCHED_BLUEPRINTS_KEY, {})),
		"can_research": _has_researchable_row(rows),
	}


static func research_blueprint(save_manager: Node, blueprint_item_path: String, station_id: StringName = &"") -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_slot_data") or not save_manager.has_method("save_slot_data"):
		return {"success": false, "reason": "no_save"}
	var slot_index := _current_slot_index(save_manager)
	var save_data: Dictionary = save_manager.call("get_slot_data", slot_index)
	var result := research_blueprint_from_save_data(save_data, blueprint_item_path, station_id)
	if not bool(result.get("success", false)):
		return result
	if not bool(save_manager.call("save_slot_data", slot_index, result.get("save_data", {}) as Dictionary)):
		return {"success": false, "reason": "save_failed", "save_data": save_data.duplicate(true)}
	return result


static func research_first_available(save_manager: Node, station_id: StringName = &"") -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_slot_data"):
		return {"success": false, "reason": "no_save"}
	var save_data: Dictionary = save_manager.call("get_slot_data", _current_slot_index(save_manager))
	for row in _blueprint_rows(save_data, station_id):
		if bool(row.get("can_research", false)):
			return research_blueprint(save_manager, str(row.get("blueprint_item_path", "")), station_id)
	return {"success": false, "reason": "no_researchable_blueprint", "save_data": save_data.duplicate(true)}


static func research_blueprint_from_save_data(save_data: Dictionary, blueprint_item_path: String, station_id: StringName = &"") -> Dictionary:
	var normalized_path := blueprint_item_path.strip_edges()
	if save_data.is_empty():
		return {"success": false, "reason": "no_save", "save_data": {}}
	if normalized_path == "" or not ResourceLoader.exists(normalized_path):
		return {"success": false, "reason": "invalid_blueprint", "save_data": save_data.duplicate(true)}
	var recipe := _recipe_for_blueprint(save_data, normalized_path, station_id)
	if recipe == null:
		return {
			"success": false,
			"reason": "blueprint_unavailable",
			"save_data": save_data.duplicate(true),
			"blueprint_item_path": normalized_path,
		}
	var researched := _dictionary(save_data.get(RESEARCHED_BLUEPRINTS_KEY, {}))
	if bool(researched.get(normalized_path, false)):
		return {
			"success": false,
			"reason": "already_researched",
			"save_data": save_data.duplicate(true),
			"blueprint_item_path": normalized_path,
			"recipe_id": str(recipe.get("id")),
		}
	var stash := _stash_array(save_data.get("stash", []))
	if _stash_quantity(stash, normalized_path) <= 0:
		return {
			"success": false,
			"reason": "missing_blueprint",
			"save_data": save_data.duplicate(true),
			"blueprint_item_path": normalized_path,
			"recipe_id": str(recipe.get("id")),
		}
	var updated := save_data.duplicate(true)
	updated["stash"] = _remove_item_cost(stash, normalized_path, 1)
	researched[normalized_path] = true
	updated[RESEARCHED_BLUEPRINTS_KEY] = researched
	return {
		"success": true,
		"reason": "ok",
		"save_data": updated,
		"blueprint_item_path": normalized_path,
		"recipe_id": str(recipe.get("id")),
		"state": get_state_from_save_data(updated, station_id),
	}


static func is_blueprint_researched(save_data: Dictionary, blueprint_item_path: String) -> bool:
	var researched := _dictionary(save_data.get(RESEARCHED_BLUEPRINTS_KEY, {}))
	return bool(researched.get(blueprint_item_path, false))


static func _blueprint_rows(save_data: Dictionary, station_id: StringName) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if save_data.is_empty():
		return rows
	var researched := _dictionary(save_data.get(RESEARCHED_BLUEPRINTS_KEY, {}))
	var stash := _stash_array(save_data.get("stash", []))
	for recipe in BaseRecipeServiceScript.get_all_recipes():
		if recipe == null:
			continue
		if station_id != &"" and StringName(str(recipe.get("station_id"))) != station_id:
			continue
		var blueprint_path := str(recipe.get("required_blueprint_item_path"))
		if blueprint_path == "":
			continue
		var station_ready := _recipe_station_ready(save_data, recipe)
		var is_researched := bool(researched.get(blueprint_path, false))
		var in_stash := _stash_quantity(stash, blueprint_path) > 0
		rows.append({
			"blueprint_item_path": blueprint_path,
			"blueprint_name": _item_name(blueprint_path),
			"recipe_id": str(recipe.get("id")),
			"recipe_name": _recipe_name(recipe),
			"station_id": str(recipe.get("station_id")),
			"station_ready": station_ready,
			"in_stash": in_stash,
			"is_researched": is_researched,
			"can_research": station_ready and in_stash and not is_researched,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("recipe_id", "")) < str(b.get("recipe_id", "")))
	return rows


static func _recipe_for_blueprint(save_data: Dictionary, blueprint_item_path: String, station_id: StringName) -> Resource:
	for recipe in BaseRecipeServiceScript.get_all_recipes():
		if recipe == null:
			continue
		if station_id != &"" and StringName(str(recipe.get("station_id"))) != station_id:
			continue
		if str(recipe.get("required_blueprint_item_path")) != blueprint_item_path:
			continue
		if _recipe_station_ready(save_data, recipe):
			return recipe
	return null


static func _recipe_station_ready(save_data: Dictionary, recipe: Resource) -> bool:
	var required_upgrade_id := StringName(str(recipe.get("required_upgrade_id")))
	if required_upgrade_id == &"":
		return true
	return BaseProgressionScript.is_upgrade_purchased(save_data, required_upgrade_id)


static func _has_researchable_row(rows: Array[Dictionary]) -> bool:
	for row in rows:
		if bool(row.get("can_research", false)):
			return true
	return false


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


static func _remove_item_cost(stash: Array, item_path: String, quantity: int) -> Array:
	var remaining := quantity
	var result: Array = []
	for entry in stash:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stack := (entry as Dictionary).duplicate(true)
		var stack_path := str(stack.get("item_path", stack.get("resource_path", "")))
		var stack_quantity := int(stack.get("quantity", 0))
		if stack_path == item_path and remaining > 0:
			var removed := mini(stack_quantity, remaining)
			stack_quantity -= removed
			remaining -= removed
		if stack_path != "" and stack_quantity > 0:
			result.append({"item_path": stack_path, "quantity": stack_quantity})
	return result


static func _item_name(item_path: String) -> String:
	if item_path == "" or not ResourceLoader.exists(item_path):
		return "Unknown"
	var item_def := load(item_path) as ItemDef
	if item_def == null:
		return "Unknown"
	var name_key := str(item_def.name_key)
	if name_key != "":
		var translated := TranslationServer.translate(name_key)
		if translated != name_key and translated != "":
			return translated
	return item_def.display_name if item_def.display_name != "" else str(item_def.id)


static func _recipe_name(recipe: Resource) -> String:
	if recipe == null:
		return "Unknown"
	var name_key := str(recipe.get("display_name_key"))
	if name_key != "":
		var translated := TranslationServer.translate(name_key)
		if translated != name_key and translated != "":
			return translated
	return _item_name(str(recipe.get("output_item_path")))


static func _current_slot_index(save_manager: Node) -> int:
	if save_manager != null and save_manager.has_method("get_current_slot_index"):
		return int(save_manager.call("get_current_slot_index"))
	return 1
