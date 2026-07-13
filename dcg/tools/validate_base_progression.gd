extends SceneTree

const WorkbenchUpgrade := preload("res://data/base_upgrades/workbench_level_1.tres")
const CraftingRecipeCatalogScript := preload("res://scripts/crafting/crafting_recipe_catalog.gd")

const WOOD_PATH := "res://data/items/crafting/wood.tres"

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_workbench_upgrade()
	_validate_active_recipe_paths()
	if _errors.is_empty():
		print("[base_progression] OK upgrade=wood5 recipes=2 references=clean")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _validate_workbench_upgrade() -> void:
	if WorkbenchUpgrade == null or not WorkbenchUpgrade.has_method("is_valid") or not bool(WorkbenchUpgrade.call("is_valid")):
		_errors.append("Workbench Level 1 should load and validate.")
		return
	var costs: Array = WorkbenchUpgrade.get("item_costs") as Array
	if costs.size() != 1:
		_errors.append("Workbench Level 1 should have one active item cost.")
		return
	var cost := costs[0] as Dictionary
	if str(cost.get("item_path", "")) != WOOD_PATH or int(cost.get("quantity", 0)) != 5:
		_errors.append("Workbench Level 1 should cost five wood.")
	if load(WOOD_PATH) == null:
		_errors.append("Workbench material path should resolve.")


func _validate_active_recipe_paths() -> void:
	var recipes: Array[Resource] = CraftingRecipeCatalogScript.recipe_defs()
	if recipes.size() != 2:
		_errors.append("Current workbench progression should expose two recipes.")
	for recipe in recipes:
		if recipe == null or load(str(recipe.get("output_item_path"))) == null:
			_errors.append("Every active recipe output should resolve.")
