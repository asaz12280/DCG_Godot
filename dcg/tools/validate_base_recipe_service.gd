extends SceneTree

const CraftingRecipeCatalogScript := preload("res://scripts/crafting/crafting_recipe_catalog.gd")
const AmmoRecipe := preload("res://data/crafting_recipes/workbench_ammo_S.tres")
const MagazineRecipe := preload("res://data/crafting_recipes/workbench_extended_magazine.tres")

const ACTIVE_RECIPE_IDS := [&"workbench_ammo_S", &"workbench_extended_magazine"]

var _errors: Array[String] = []


func _initialize() -> void:
	var recipes: Array[Resource] = CraftingRecipeCatalogScript.recipe_defs()
	if recipes.size() != ACTIVE_RECIPE_IDS.size():
		_errors.append("Workbench catalog should expose exactly two active recipes.")
	for recipe in [AmmoRecipe, MagazineRecipe]:
		_validate_recipe(recipe)
	for recipe_id in ACTIVE_RECIPE_IDS:
		if not _has_recipe_id(recipes, recipe_id):
			_errors.append("Workbench catalog is missing active recipe %s." % recipe_id)
	_finish()


func _validate_recipe(recipe: Resource) -> void:
	if recipe == null or not recipe.has_method("is_valid") or not bool(recipe.call("is_valid")):
		_errors.append("Active workbench recipe should load and validate.")
		return
	var output_path := str(recipe.get("output_item_path"))
	if load(output_path) == null:
		_errors.append("Recipe output should resolve: %s." % output_path)
	if str(recipe.get("required_blueprint_item_path")) != "":
		_errors.append("Current recipes should not require inactive blueprint content.")
	for ingredient in recipe.get("ingredient_costs") as Array:
		if typeof(ingredient) != TYPE_DICTIONARY:
			_errors.append("Recipe ingredient should be a dictionary.")
			continue
		var ingredient_path := str((ingredient as Dictionary).get("item_path", ""))
		if load(ingredient_path) == null:
			_errors.append("Recipe ingredient should resolve: %s." % ingredient_path)


func _has_recipe_id(recipes: Array[Resource], recipe_id: StringName) -> bool:
	for recipe in recipes:
		if recipe != null and StringName(str(recipe.get("id"))) == recipe_id:
			return true
	return false


func _finish() -> void:
	if _errors.is_empty():
		print("[base_recipe_service] OK active=2 outputs=valid ingredients=valid blueprint=inactive")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)
