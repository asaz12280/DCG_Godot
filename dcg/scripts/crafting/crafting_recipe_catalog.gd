class_name CraftingRecipeCatalog
extends RefCounted

const WorkbenchAmmo9mm := preload("res://data/crafting_recipes/workbench_ammo_9mm.tres")
const WorkbenchAmmo9mmPolished := preload("res://data/crafting_recipes/workbench_ammo_9mm_polished.tres")
const WorkbenchExtendedMagazine := preload("res://data/crafting_recipes/workbench_extended_magazine.tres")
const WorkbenchReclaimedWire := preload("res://data/crafting_recipes/workbench_reclaimed_wire.tres")

const RECIPES := [
	WorkbenchAmmo9mm,
	WorkbenchAmmo9mmPolished,
	WorkbenchExtendedMagazine,
	WorkbenchReclaimedWire,
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
