class_name DismantleRecipeCatalog
extends RefCounted

const WorkbenchPistolParts := preload("res://data/dismantle_recipes/workbench_pistol_9mm_parts.tres")
const WorkbenchLightArmorParts := preload("res://data/dismantle_recipes/workbench_light_armor_parts.tres")

const RECIPES := [
	WorkbenchPistolParts,
	WorkbenchLightArmorParts,
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
