extends SceneTree

const BaseRecipeServiceScript := preload("res://scripts/base/base_recipe_service.gd")
const BaseNeededItemServiceScript := preload("res://scripts/base/base_needed_item_service.gd")
const WorkbenchRecipe := preload("res://data/crafting_recipes/workbench_ammo_9mm.tres")
const PolishedAmmoRecipe := preload("res://data/crafting_recipes/workbench_ammo_9mm_polished.tres")
const ExtendedMagazineRecipe := preload("res://data/crafting_recipes/workbench_extended_magazine.tres")
const BlueprintRecipe := preload("res://data/crafting_recipes/workbench_reclaimed_wire.tres")

const WORKBENCH_UPGRADE_ID := "workbench_level_1"
const JUNK_PATH := "res://data/items/loot/junk.tres"
const WIRE_PATH := "res://data/items/electronics/wire.tres"
const AMMO_PATH := "res://data/items/ammo/ammo_9mm.tres"
const POLISHED_AMMO_PATH := "res://data/items/ammo/ammo_9mm_polished.tres"
const MAGAZINE_PATH := "res://data/items/attachments/extended_magazine.tres"
const BLUEPRINT_PATH := "res://data/items/recipes/blueprint.tres"

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_recipe_def()
	_validate_recipe_unlock_gate()
	_validate_blueprint_locked_recipe_integration()
	_validate_missing_material_paths()
	_validate_recipe_rows_and_selection()
	_validate_craft_execution()
	_validate_needed_item_integration()
	if _errors.is_empty():
		print("[base_recipe_service] OK recipe=data_valid unlock=workbench blueprint=gate list=rows selection=save materials=needed_paths craft=stash")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_recipe_def() -> void:
	if WorkbenchRecipe == null or not WorkbenchRecipe.has_method("is_valid") or not bool(WorkbenchRecipe.call("is_valid")):
		_errors.append("Workbench ammo recipe should load and validate.")
	if str(WorkbenchRecipe.get("output_item_path")) != "res://data/items/ammo/ammo_9mm.tres":
		_errors.append("Workbench ammo recipe should output 9mm ammo.")
	if int(WorkbenchRecipe.get("output_quantity")) != 20:
		_errors.append("Workbench ammo recipe should output a small ammo stack.")
	if PolishedAmmoRecipe == null or not PolishedAmmoRecipe.has_method("is_valid") or not bool(PolishedAmmoRecipe.call("is_valid")):
		_errors.append("Polished ammo recipe should load and validate.")
	if str(PolishedAmmoRecipe.get("output_item_path")) != POLISHED_AMMO_PATH:
		_errors.append("Polished ammo recipe should output the lower-wear 9mm ammo.")
	if int(PolishedAmmoRecipe.get("output_quantity")) != 12:
		_errors.append("Polished ammo recipe should output a smaller high-grade ammo stack.")
	if ExtendedMagazineRecipe == null or not ExtendedMagazineRecipe.has_method("is_valid") or not bool(ExtendedMagazineRecipe.call("is_valid")):
		_errors.append("Extended magazine recipe should load and validate.")
	if str(ExtendedMagazineRecipe.get("output_item_path")) != MAGAZINE_PATH:
		_errors.append("Extended magazine recipe should output the extended magazine item.")
	if BlueprintRecipe == null or not BlueprintRecipe.has_method("is_valid") or not bool(BlueprintRecipe.call("is_valid")):
		_errors.append("Blueprint-gated reclaimed wire recipe should load and validate.")
	if str(BlueprintRecipe.get("required_blueprint_item_path")) != BLUEPRINT_PATH:
		_errors.append("Reclaimed wire recipe should require the template blueprint item.")


func _validate_recipe_unlock_gate() -> void:
	var locked_state: Dictionary = BaseRecipeServiceScript.get_state_from_save_data(_save_data(false, []))
	if not (locked_state.get("needed_item_paths", []) as Array).is_empty():
		_errors.append("Recipe materials should not be marked before the required workbench upgrade is purchased.")
	if not (locked_state.get("blocked_recipe_ids", []) as Array).has("workbench_ammo_9mm"):
		_errors.append("Locked recipe should be reported as blocked.")
	var available_state: Dictionary = BaseRecipeServiceScript.get_state_from_save_data(_save_data(true, []))
	if not (available_state.get("available_recipe_ids", []) as Array).has("workbench_ammo_9mm"):
		_errors.append("Workbench ammo recipe should become available after Workbench Lv.1.")


func _validate_blueprint_locked_recipe_integration() -> void:
	var before_research: Dictionary = BaseRecipeServiceScript.get_state_from_save_data(_save_data(true, [
		{"item_path": JUNK_PATH, "quantity": 3},
	]))
	if (before_research.get("available_recipe_ids", []) as Array).has("workbench_reclaimed_wire"):
		_errors.append("Blueprint-gated recipe should not become available before research.")
	if not (before_research.get("blocked_recipe_ids", []) as Array).has("workbench_reclaimed_wire"):
		_errors.append("Blueprint-gated recipe should be reported as blocked before research.")

	var researched_save := _save_data(true, [
		{"item_path": JUNK_PATH, "quantity": 3},
	])
	researched_save["researched_blueprints"] = {BLUEPRINT_PATH: true}
	var after_research: Dictionary = BaseRecipeServiceScript.get_state_from_save_data(researched_save)
	if not (after_research.get("available_recipe_ids", []) as Array).has("workbench_reclaimed_wire"):
		_errors.append("Researched blueprint should make the matching recipe available.")
	var rows := BaseRecipeServiceScript.get_recipe_rows(researched_save, &"workbench")
	if not _row_ids(rows).has("workbench_reclaimed_wire"):
		_errors.append("Researched blueprint recipe should appear in workbench recipe rows.")
	var craft_result: Dictionary = BaseRecipeServiceScript.craft_from_save_data(researched_save, &"workbench_reclaimed_wire")
	if not bool(craft_result.get("success", false)):
		_errors.append("Researched blueprint recipe should craft when materials are stocked.")
	else:
		var crafted_save: Dictionary = craft_result.get("save_data", {}) as Dictionary
		if _stack_quantity(crafted_save.get("stash", []) as Array, WIRE_PATH) != 2:
			_errors.append("Researched blueprint recipe should add wire output to stash.")


func _validate_missing_material_paths() -> void:
	var missing_all: Dictionary = BaseRecipeServiceScript.get_state_from_save_data(_save_data(true, []))
	var missing_all_paths: Array = missing_all.get("needed_item_paths", []) as Array
	if not missing_all_paths.has(JUNK_PATH) or not missing_all_paths.has(WIRE_PATH):
		_errors.append("Recipe service should mark missing junk and wire for the ammo recipe.")

	var missing_wire: Dictionary = BaseRecipeServiceScript.get_state_from_save_data(_save_data(true, [
		{"item_path": JUNK_PATH, "quantity": 4},
	]))
	var missing_wire_paths: Array = missing_wire.get("needed_item_paths", []) as Array
	if missing_wire_paths.has(JUNK_PATH) or not missing_wire_paths.has(WIRE_PATH):
		_errors.append("Recipe service should clear fully stocked recipe materials while keeping missing materials marked across all recipes.")

	var complete: Dictionary = BaseRecipeServiceScript.get_state_from_save_data(_save_data(true, [
		{"item_path": JUNK_PATH, "quantity": 4},
		{"item_path": WIRE_PATH, "quantity": 2},
	]))
	if not (complete.get("needed_item_paths", []) as Array).is_empty():
		_errors.append("Recipe service should clear recipe needed paths when all known recipe ingredients are stocked.")


func _validate_recipe_rows_and_selection() -> void:
	var ammo_ready := _save_data(true, [
		{"item_path": JUNK_PATH, "quantity": 2},
		{"item_path": WIRE_PATH, "quantity": 1},
	])
	var rows := BaseRecipeServiceScript.get_recipe_rows(ammo_ready, &"workbench")
	if rows.size() != 3:
		_errors.append("Workbench recipe rows should list baseline ammo, polished ammo, and extended magazine recipes.")
	var selected_ids := _selected_ids(rows)
	if not selected_ids.has("workbench_ammo_9mm"):
		_errors.append("Recipe rows should select the craftable ammo recipe when no saved selection exists.")
	if not _row_ids(rows).has("workbench_ammo_9mm_polished"):
		_errors.append("Recipe rows should expose the polished low-wear ammo recipe.")
	var polished_row := _row_by_id(rows, "workbench_ammo_9mm_polished")
	if polished_row.is_empty() or bool(polished_row.get("can_craft", true)):
		_errors.append("Polished ammo row should be visible but blocked when extra materials are missing.")
	if not _row_ids(rows).has("workbench_extended_magazine"):
		_errors.append("Recipe rows should expose the extended magazine recipe.")
	var magazine_row := _row_by_id(rows, "workbench_extended_magazine")
	if magazine_row.is_empty() or bool(magazine_row.get("can_craft", true)):
		_errors.append("Extended magazine row should be visible but blocked when its extra materials are missing.")

	var selected_result: Dictionary = BaseRecipeServiceScript.select_recipe_in_save_data(_save_data(true, [
		{"item_path": JUNK_PATH, "quantity": 4},
		{"item_path": WIRE_PATH, "quantity": 2},
	]), &"workbench", &"workbench_extended_magazine")
	if not bool(selected_result.get("success", false)):
		_errors.append("Recipe service should allow selecting an unlocked workbench recipe.")
		return
	var selected_save: Dictionary = selected_result.get("save_data", {}) as Dictionary
	if str((selected_save.get("selected_recipe_ids", {}) as Dictionary).get("workbench", "")) != "workbench_extended_magazine":
		_errors.append("Selected recipe should be stored in save data by station.")
	var selected_recipe := BaseRecipeServiceScript.get_selected_recipe(selected_save, &"workbench")
	if selected_recipe == null or str(selected_recipe.get("id")) != "workbench_extended_magazine":
		_errors.append("Recipe service should resolve the saved selected workbench recipe.")
	var craft_result: Dictionary = BaseRecipeServiceScript.craft_selected_from_save_data(selected_save, &"workbench")
	if not bool(craft_result.get("success", false)):
		_errors.append("Craft selected should produce the selected workbench recipe when materials are stocked.")
	else:
		var crafted_save: Dictionary = craft_result.get("save_data", {}) as Dictionary
		if _stack_quantity(crafted_save.get("stash", []) as Array, MAGAZINE_PATH) != 1:
			_errors.append("Craft selected should add the selected extended magazine output.")


func _validate_craft_execution() -> void:
	var locked_result: Dictionary = BaseRecipeServiceScript.craft_from_save_data(_save_data(false, [
		{"item_path": JUNK_PATH, "quantity": 2},
		{"item_path": WIRE_PATH, "quantity": 1},
	]), &"workbench_ammo_9mm")
	if bool(locked_result.get("success", false)) or str(locked_result.get("reason", "")) != "locked_recipe":
		_errors.append("Craft execution should reject recipes before their workbench unlock.")

	var missing_result: Dictionary = BaseRecipeServiceScript.craft_from_save_data(_save_data(true, [
		{"item_path": JUNK_PATH, "quantity": 2},
	]), &"workbench_ammo_9mm")
	if bool(missing_result.get("success", false)) or not (missing_result.get("missing_item_paths", []) as Array).has(WIRE_PATH):
		_errors.append("Craft execution should reject missing ingredients and report missing paths.")

	var result: Dictionary = BaseRecipeServiceScript.craft_from_save_data(_save_data(true, [
		{"item_path": JUNK_PATH, "quantity": 2},
		{"item_path": WIRE_PATH, "quantity": 1},
		{"item_path": AMMO_PATH, "quantity": 55},
	]), &"workbench_ammo_9mm")
	if not bool(result.get("success", false)):
		_errors.append("Craft execution should succeed when recipe ingredients are stocked.")
		return
	var updated: Dictionary = result.get("save_data", {}) as Dictionary
	var updated_stash: Array = updated.get("stash", []) as Array
	if _stack_quantity(updated_stash, JUNK_PATH) != 0 or _stack_quantity(updated_stash, WIRE_PATH) != 0:
		_errors.append("Craft execution should consume recipe ingredients from stash.")
	if _stack_quantity(updated_stash, AMMO_PATH) != 75:
		_errors.append("Craft execution should add output ammo to stash.")
	if _stack_count(updated_stash, AMMO_PATH) != 2:
		_errors.append("Craft execution should split output by ItemDef max_stack when merging into stash.")

	var polished_result: Dictionary = BaseRecipeServiceScript.craft_from_save_data(_save_data(true, [
		{"item_path": JUNK_PATH, "quantity": 3},
		{"item_path": WIRE_PATH, "quantity": 2},
	]), &"workbench_ammo_9mm_polished")
	if not bool(polished_result.get("success", false)):
		_errors.append("Craft execution should craft polished low-wear ammo when its materials are stocked.")
	else:
		var polished_save: Dictionary = polished_result.get("save_data", {}) as Dictionary
		if _stack_quantity(polished_save.get("stash", []) as Array, POLISHED_AMMO_PATH) != 12:
			_errors.append("Polished ammo recipe should add its lower-wear ammo output to stash.")


func _validate_needed_item_integration() -> void:
	var needed_state: Dictionary = BaseNeededItemServiceScript.get_state_from_save_data(_save_data(true, []))
	var recipe_paths: Array = needed_state.get("recipe_item_paths", []) as Array
	if not recipe_paths.has(JUNK_PATH) or not recipe_paths.has(WIRE_PATH):
		_errors.append("Needed item service should expose recipe material paths.")
	var automatic_paths: Array = needed_state.get("automatic_item_paths", []) as Array
	if not automatic_paths.has(JUNK_PATH) or not automatic_paths.has(WIRE_PATH):
		_errors.append("Recipe materials should flow into automatic needed item paths.")


func _save_data(workbench_purchased: bool, stash: Array) -> Dictionary:
	var upgrades := {}
	if workbench_purchased:
		upgrades[WORKBENCH_UPGRADE_ID] = {"purchased": true}
	return {
		"difficulty_id": "normal",
		"money": 0,
		"stash": stash.duplicate(true),
		"base_upgrades": upgrades,
		"quests": {},
	}


func _stack_quantity(stash: Array, item_path: String) -> int:
	var total := 0
	for entry in stash:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stack := entry as Dictionary
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path:
			total += int(stack.get("quantity", 0))
	return total


func _stack_count(stash: Array, item_path: String) -> int:
	var count := 0
	for entry in stash:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stack := entry as Dictionary
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path:
			count += 1
	return count


func _row_ids(rows: Array) -> Array[String]:
	var ids: Array[String] = []
	for value in rows:
		if typeof(value) == TYPE_DICTIONARY:
			ids.append(str((value as Dictionary).get("id", "")))
	return ids


func _selected_ids(rows: Array) -> Array[String]:
	var ids: Array[String] = []
	for value in rows:
		if typeof(value) == TYPE_DICTIONARY and bool((value as Dictionary).get("is_selected", false)):
			ids.append(str((value as Dictionary).get("id", "")))
	return ids


func _row_by_id(rows: Array, recipe_id: String) -> Dictionary:
	for value in rows:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == recipe_id:
			return value as Dictionary
	return {}
