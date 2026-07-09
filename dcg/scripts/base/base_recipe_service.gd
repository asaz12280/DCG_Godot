class_name BaseRecipeService
extends RefCounted

const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const CraftingRecipeCatalogScript := preload("res://scripts/crafting/crafting_recipe_catalog.gd")

const SELECTED_RECIPES_KEY := "selected_recipe_ids"


static func get_state_from_save_data(save_data: Dictionary) -> Dictionary:
	var available_recipes: Array[String] = []
	var blocked_recipes: Array[String] = []
	var missing_material_paths := {}
	for recipe in CraftingRecipeCatalogScript.recipe_defs():
		if not _is_recipe_valid(recipe):
			continue
		var recipe_id := str(recipe.get("id"))
		if not _is_recipe_unlocked(save_data, recipe):
			blocked_recipes.append(recipe_id)
			continue
		available_recipes.append(recipe_id)
		var missing := _missing_recipe_material_paths(save_data, recipe)
		for item_path in missing.keys():
			missing_material_paths[item_path] = true
	available_recipes.sort()
	blocked_recipes.sort()
	return {
		"available_recipe_ids": available_recipes,
		"blocked_recipe_ids": blocked_recipes,
		"needed_item_paths": _sorted_keys(missing_material_paths),
		"recipe_rows": get_recipe_rows(save_data),
		"selected_recipe_ids": _dictionary(save_data.get(SELECTED_RECIPES_KEY, {})),
	}


static func get_needed_item_paths(save_data: Dictionary) -> Array[String]:
	var state := get_state_from_save_data(save_data)
	return state.get("needed_item_paths", []) as Array[String]


static func craft(save_manager: Node, recipe_id: StringName) -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_slot_data") or not save_manager.has_method("save_slot_data"):
		return {"success": false, "reason": "no_save"}
	var slot_index := _current_slot_index(save_manager)
	var save_data: Dictionary = save_manager.call("get_slot_data", slot_index)
	var result := craft_from_save_data(save_data, recipe_id)
	if not bool(result.get("success", false)):
		return result
	if not bool(save_manager.call("save_slot_data", slot_index, result.get("save_data", {}) as Dictionary)):
		return {"success": false, "reason": "save_failed", "save_data": save_data.duplicate(true)}
	return result


static func craft_selected(save_manager: Node, station_id: StringName) -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_slot_data") or not save_manager.has_method("save_slot_data"):
		return {"success": false, "reason": "no_save"}
	var slot_index := _current_slot_index(save_manager)
	var save_data: Dictionary = save_manager.call("get_slot_data", slot_index)
	var result := craft_selected_from_save_data(save_data, station_id)
	if not bool(result.get("success", false)):
		return result
	if not bool(save_manager.call("save_slot_data", slot_index, result.get("save_data", {}) as Dictionary)):
		return {"success": false, "reason": "save_failed", "save_data": save_data.duplicate(true)}
	return result


static func craft_selected_from_save_data(save_data: Dictionary, station_id: StringName) -> Dictionary:
	var recipe := get_selected_recipe(save_data, station_id)
	if recipe == null:
		return {"success": false, "reason": "no_recipe", "save_data": save_data.duplicate(true)}
	return craft_from_save_data(save_data, StringName(str(recipe.get("id"))))


static func craft_from_save_data(save_data: Dictionary, recipe_id: StringName) -> Dictionary:
	if save_data.is_empty():
		return {"success": false, "reason": "no_save", "save_data": {}}
	var recipe := get_recipe_by_id(recipe_id)
	if recipe == null:
		return {"success": false, "reason": "invalid_recipe", "save_data": save_data.duplicate(true)}
	if not _is_recipe_unlocked(save_data, recipe):
		return {"success": false, "reason": "locked_recipe", "save_data": save_data.duplicate(true), "recipe_id": str(recipe_id)}
	var missing := _missing_recipe_material_paths(save_data, recipe)
	if not missing.is_empty():
		return {
			"success": false,
			"reason": "missing_items",
			"save_data": save_data.duplicate(true),
			"recipe_id": str(recipe_id),
			"missing_item_paths": _sorted_keys(missing),
		}
	var output_item_path := str(recipe.get("output_item_path"))
	var output_item := _load_item(output_item_path)
	if output_item == null:
		return {"success": false, "reason": "invalid_output", "save_data": save_data.duplicate(true), "recipe_id": str(recipe_id)}
	var updated := save_data.duplicate(true)
	var stash: Array = _stash_array(updated.get("stash", []))
	for cost in _ingredient_costs(recipe):
		stash = _remove_item_cost(stash, str(cost.get("item_path", "")), int(cost.get("quantity", 0)))
	stash = _add_item_to_stash(stash, output_item, int(recipe.get("output_quantity")))
	updated["stash"] = stash
	return {
		"success": true,
		"reason": "ok",
		"recipe_id": str(recipe_id),
		"output_item_path": output_item_path,
		"output_quantity": int(recipe.get("output_quantity")),
		"save_data": updated,
		"state": get_state_from_save_data(updated),
	}


static func can_craft_recipe(save_data: Dictionary, recipe: Resource) -> bool:
	return _is_recipe_valid(recipe) and _is_recipe_unlocked(save_data, recipe) and _missing_recipe_material_paths(save_data, recipe).is_empty()


static func get_first_craftable_recipe(save_data: Dictionary, station_id: StringName = &"") -> Resource:
	for recipe in get_available_recipes(save_data, station_id):
		if can_craft_recipe(save_data, recipe):
			return recipe
	return null


static func get_selected_recipe(save_data: Dictionary, station_id: StringName) -> Resource:
	var recipe_id := get_selected_recipe_id(save_data, station_id)
	return get_recipe_by_id(recipe_id) if recipe_id != &"" else null


static func get_selected_recipe_id(save_data: Dictionary, station_id: StringName) -> StringName:
	var saved_id := _saved_recipe_selection(save_data, station_id)
	if saved_id != &"":
		var saved_recipe := get_recipe_by_id(saved_id)
		if _is_recipe_available_for_station(save_data, saved_recipe, station_id):
			return saved_id
	var first_craftable := get_first_craftable_recipe(save_data, station_id)
	if first_craftable != null:
		return StringName(str(first_craftable.get("id")))
	var available := get_available_recipes(save_data, station_id)
	if not available.is_empty():
		return StringName(str(available[0].get("id")))
	return &""


static func select_recipe(save_manager: Node, station_id: StringName, recipe_id: StringName) -> Dictionary:
	if save_manager == null or not save_manager.has_method("get_slot_data") or not save_manager.has_method("save_slot_data"):
		return {"success": false, "reason": "no_save"}
	var slot_index := _current_slot_index(save_manager)
	var save_data: Dictionary = save_manager.call("get_slot_data", slot_index)
	var result := select_recipe_in_save_data(save_data, station_id, recipe_id)
	if not bool(result.get("success", false)):
		return result
	if not bool(save_manager.call("save_slot_data", slot_index, result.get("save_data", {}) as Dictionary)):
		return {"success": false, "reason": "save_failed", "save_data": save_data.duplicate(true)}
	return result


static func select_recipe_in_save_data(save_data: Dictionary, station_id: StringName, recipe_id: StringName) -> Dictionary:
	if save_data.is_empty():
		return {"success": false, "reason": "no_save", "save_data": {}}
	var recipe := get_recipe_by_id(recipe_id)
	if not _is_recipe_available_for_station(save_data, recipe, station_id):
		return {
			"success": false,
			"reason": "recipe_unavailable",
			"save_data": save_data.duplicate(true),
			"recipe_id": str(recipe_id),
		}
	var updated := save_data.duplicate(true)
	var selected := _dictionary(updated.get(SELECTED_RECIPES_KEY, {}))
	selected[str(station_id)] = str(recipe_id)
	updated[SELECTED_RECIPES_KEY] = selected
	return {
		"success": true,
		"reason": "ok",
		"save_data": updated,
		"selected_recipe_id": str(recipe_id),
		"recipe_rows": get_recipe_rows(updated, station_id, recipe_id),
	}


static func get_recipe_by_id(recipe_id: StringName) -> Resource:
	for recipe in CraftingRecipeCatalogScript.recipe_defs():
		if _is_recipe_valid(recipe) and StringName(str(recipe.get("id"))) == recipe_id:
			return recipe
	return null


static func get_all_recipes() -> Array[Resource]:
	var recipes: Array[Resource] = []
	for recipe in CraftingRecipeCatalogScript.recipe_defs():
		if _is_recipe_valid(recipe):
			recipes.append(recipe)
	return recipes


static func describe_recipe_cost(recipe: Resource) -> String:
	var parts: Array[String] = []
	for cost in _ingredient_costs(recipe):
		parts.append("%s x%d" % [_item_name(str(cost.get("item_path", ""))), int(cost.get("quantity", 0))])
	return ", ".join(parts)


static func get_available_recipes(save_data: Dictionary, station_id: StringName = &"") -> Array[Resource]:
	var result: Array[Resource] = []
	for recipe in CraftingRecipeCatalogScript.recipe_defs():
		if _is_recipe_available_for_station(save_data, recipe, station_id):
			result.append(recipe)
	return result


static func get_recipe_rows(save_data: Dictionary, station_id: StringName = &"", selected_recipe_id: StringName = &"") -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var selected_id := selected_recipe_id
	if selected_id == &"" and station_id != &"":
		selected_id = get_selected_recipe_id(save_data, station_id)
	for recipe in get_available_recipes(save_data, station_id):
		var recipe_id := StringName(str(recipe.get("id")))
		var missing := _missing_recipe_material_paths(save_data, recipe)
		var output_item_path := str(recipe.get("output_item_path"))
		rows.append({
			"id": str(recipe_id),
			"station_id": str(recipe.get("station_id")),
			"name": _recipe_name(recipe),
			"output_item_path": output_item_path,
			"output_name": _item_name(output_item_path),
			"output_quantity": int(recipe.get("output_quantity")),
			"cost_text": describe_recipe_cost(recipe),
			"missing_item_paths": _sorted_keys(missing),
			"can_craft": missing.is_empty(),
			"is_selected": selected_id != &"" and recipe_id == selected_id,
		})
	return rows


static func _missing_recipe_material_paths(save_data: Dictionary, recipe: Resource) -> Dictionary:
	var result := {}
	var stash: Array = _stash_array(save_data.get("stash", []))
	for cost in _ingredient_costs(recipe):
		var item_path := str(cost.get("item_path", ""))
		var required := int(cost.get("quantity", 0))
		if item_path == "" or required <= 0:
			continue
		if _stash_quantity(stash, item_path) < required:
			result[item_path] = true
	return result


static func _is_recipe_valid(recipe: Resource) -> bool:
	return recipe != null and recipe.has_method("is_valid") and bool(recipe.call("is_valid"))


static func _is_recipe_unlocked(save_data: Dictionary, recipe: Resource) -> bool:
	if save_data.is_empty():
		return false
	var required_upgrade_id := StringName(str(recipe.get("required_upgrade_id")))
	if required_upgrade_id != &"" and not BaseProgressionScript.is_upgrade_purchased(save_data, required_upgrade_id):
		return false
	var blueprint_path := str(recipe.get("required_blueprint_item_path"))
	if blueprint_path != "":
		var researched_blueprints := _dictionary(save_data.get("researched_blueprints", {}))
		if not bool(researched_blueprints.get(blueprint_path, false)):
			return false
	return true


static func _is_recipe_available_for_station(save_data: Dictionary, recipe: Resource, station_id: StringName) -> bool:
	if not _is_recipe_valid(recipe):
		return false
	if station_id != &"" and StringName(str(recipe.get("station_id"))) != station_id:
		return false
	return _is_recipe_unlocked(save_data, recipe)


static func _ingredient_costs(recipe: Resource) -> Array:
	if recipe == null:
		return []
	var value: Variant = recipe.get("ingredient_costs")
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


static func _add_item_to_stash(stash: Array, item_def: ItemDef, quantity: int) -> Array:
	if item_def == null or quantity <= 0:
		return stash
	var result: Array = []
	for entry in stash:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stack := entry as Dictionary
		var item_path := str(stack.get("item_path", stack.get("resource_path", "")))
		var stack_quantity := int(stack.get("quantity", 0))
		if item_path != "" and stack_quantity > 0:
			result.append({"item_path": item_path, "quantity": stack_quantity})
	var remaining := quantity
	var max_stack := item_def.get_max_stack()
	for index in range(result.size()):
		var stack: Dictionary = result[index]
		if str(stack.get("item_path", "")) != item_def.resource_path:
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


static func _load_item(item_path: String) -> ItemDef:
	if item_path == "" or not ResourceLoader.exists(item_path):
		return null
	return load(item_path) as ItemDef


static func _item_name(item_path: String) -> String:
	var item_def := _load_item(item_path)
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
	var output_name := _item_name(str(recipe.get("output_item_path")))
	return output_name


static func _saved_recipe_selection(save_data: Dictionary, station_id: StringName) -> StringName:
	if station_id == &"":
		return &""
	var selected := _dictionary(save_data.get(SELECTED_RECIPES_KEY, {}))
	return StringName(str(selected.get(str(station_id), "")))


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
