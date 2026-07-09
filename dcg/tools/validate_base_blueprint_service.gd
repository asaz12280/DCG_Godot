extends SceneTree

const BaseBlueprintServiceScript := preload("res://scripts/base/base_blueprint_service.gd")
const BaseRecipeServiceScript := preload("res://scripts/base/base_recipe_service.gd")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const BlueprintRecipe := preload("res://data/crafting_recipes/workbench_reclaimed_wire.tres")

const WORKBENCH_UPGRADE_ID := "workbench_level_1"
const BLUEPRINT_PATH := "res://data/items/recipes/blueprint.tres"
const JUNK_PATH := "res://data/items/loot/junk.tres"
const WIRE_PATH := "res://data/items/electronics/wire.tres"

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_blueprint_recipe_data()
	_validate_research_state()
	_validate_research_execution()
	await _validate_save_round_trip()
	if _errors.is_empty():
		print("[base_blueprint_service] OK blueprint=data_valid research=stash unlock=recipe save=round_trip")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_blueprint_recipe_data() -> void:
	if BlueprintRecipe == null or not BlueprintRecipe.has_method("is_valid") or not bool(BlueprintRecipe.call("is_valid")):
		_errors.append("Blueprint-gated reclaimed wire recipe should load and validate.")
		return
	if str(BlueprintRecipe.get("required_blueprint_item_path")) != BLUEPRINT_PATH:
		_errors.append("Reclaimed wire recipe should require the template blueprint item.")
	if str(BlueprintRecipe.get("output_item_path")) != WIRE_PATH:
		_errors.append("Reclaimed wire recipe should output wire.")


func _validate_research_state() -> void:
	var locked_save := _save_data(false, [{ "item_path": BLUEPRINT_PATH, "quantity": 1 }])
	var locked_state: Dictionary = BaseBlueprintServiceScript.get_state_from_save_data(locked_save, &"workbench")
	if bool(locked_state.get("can_research", false)):
		_errors.append("Blueprint research should wait until the required workbench upgrade is purchased.")

	var ready_save := _save_data(true, [{ "item_path": BLUEPRINT_PATH, "quantity": 1 }])
	var ready_state: Dictionary = BaseBlueprintServiceScript.get_state_from_save_data(ready_save, &"workbench")
	var rows: Array = ready_state.get("blueprint_rows", []) as Array
	if rows.size() != 1:
		_errors.append("Blueprint state should expose one template workbench blueprint row.")
	if not bool(ready_state.get("can_research", false)):
		_errors.append("Blueprint state should become researchable when the blueprint item is in stash.")

	var recipe_state: Dictionary = BaseRecipeServiceScript.get_state_from_save_data(ready_save)
	if not (recipe_state.get("blocked_recipe_ids", []) as Array).has("workbench_reclaimed_wire"):
		_errors.append("Blueprint-gated recipe should remain blocked before research.")


func _validate_research_execution() -> void:
	var missing_result: Dictionary = BaseBlueprintServiceScript.research_blueprint_from_save_data(_save_data(true, []), BLUEPRINT_PATH, &"workbench")
	if bool(missing_result.get("success", false)) or str(missing_result.get("reason", "")) != "missing_blueprint":
		_errors.append("Blueprint research should reject missing blueprint items.")

	var result: Dictionary = BaseBlueprintServiceScript.research_blueprint_from_save_data(_save_data(true, [
		{"item_path": BLUEPRINT_PATH, "quantity": 1},
		{"item_path": JUNK_PATH, "quantity": 3},
	]), BLUEPRINT_PATH, &"workbench")
	if not bool(result.get("success", false)):
		_errors.append("Blueprint research should succeed when the station is ready and the blueprint is in stash.")
		return
	var updated: Dictionary = result.get("save_data", {}) as Dictionary
	if _stack_quantity(updated.get("stash", []) as Array, BLUEPRINT_PATH) != 0:
		_errors.append("Blueprint research should consume one blueprint item from stash.")
	if not bool((updated.get("researched_blueprints", {}) as Dictionary).get(BLUEPRINT_PATH, false)):
		_errors.append("Blueprint research should persist the researched blueprint path.")

	var recipe_state: Dictionary = BaseRecipeServiceScript.get_state_from_save_data(updated)
	if not (recipe_state.get("available_recipe_ids", []) as Array).has("workbench_reclaimed_wire"):
		_errors.append("Researched blueprint should unlock its matching workbench recipe.")
	var craft_result: Dictionary = BaseRecipeServiceScript.craft_from_save_data(updated, &"workbench_reclaimed_wire")
	if not bool(craft_result.get("success", false)):
		_errors.append("Unlocked blueprint recipe should craft when materials are stocked.")
	else:
		var crafted_save: Dictionary = craft_result.get("save_data", {}) as Dictionary
		if _stack_quantity(crafted_save.get("stash", []) as Array, WIRE_PATH) != 2:
			_errors.append("Unlocked reclaimed wire recipe should add wire to stash.")

	var duplicate_result: Dictionary = BaseBlueprintServiceScript.research_blueprint_from_save_data(updated, BLUEPRINT_PATH, &"workbench")
	if bool(duplicate_result.get("success", false)) or str(duplicate_result.get("reason", "")) != "already_researched":
		_errors.append("Blueprint research should reject duplicate research attempts.")


func _validate_save_round_trip() -> void:
	var save_manager := SaveGameManagerScript.new()
	save_manager.save_root_path = "user://validation_base_blueprint_service"
	root.add_child(save_manager)
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	var save_data := _save_data(true, [{"item_path": BLUEPRINT_PATH, "quantity": 1}])
	save_data["researched_blueprints"] = {BLUEPRINT_PATH: true}
	if not save_manager.save_slot_data(1, save_data):
		_errors.append("SaveGameManager should save researched blueprint data.")
	else:
		var loaded: Dictionary = save_manager.get_slot_data(1)
		if not bool((loaded.get("researched_blueprints", {}) as Dictionary).get(BLUEPRINT_PATH, false)):
			_errors.append("SaveGameManager should round-trip researched blueprint paths.")
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.queue_free()


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
		"selected_recipe_ids": {},
		"researched_blueprints": {},
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


func _cleanup_validation_root(root_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(root_path)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute("%s/slot_1.json" % absolute)
		DirAccess.remove_absolute(absolute)
