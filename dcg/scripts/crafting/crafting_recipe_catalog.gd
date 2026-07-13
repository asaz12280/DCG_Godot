class_name CraftingRecipeCatalog
extends RefCounted

const WorkbenchAmmoS := preload("res://data/crafting_recipes/workbench_ammo_S.tres")
const WorkbenchExtendedMagazine := preload("res://data/crafting_recipes/workbench_extended_magazine.tres")

const RECIPES := [
	WorkbenchAmmoS,
	WorkbenchExtendedMagazine,
]


static func recipe_defs() -> Array[Resource]:
	var result: Array[Resource] = []
	for recipe in RECIPES:
		if recipe != null:
			result.append(recipe)
	return result


static func recipes_for_station(station_id: StringName) -> Array[Resource]:
	var result: Array[Resource] = []
	for recipe in recipe_defs():
		if StringName(str(recipe.get("station_id"))) == station_id:
			result.append(recipe)
	return result
