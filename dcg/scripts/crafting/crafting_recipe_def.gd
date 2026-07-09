class_name CraftingRecipeDef
extends Resource

@export var id: StringName = &""
@export var station_id: StringName = &"workbench"
@export var display_name_key: StringName = &""
@export var description_key: StringName = &""
@export var output_item_path := ""
@export_range(1, 999, 1) var output_quantity := 1
@export var ingredient_costs: Array[Dictionary] = []
@export var required_upgrade_id: StringName = &""
@export var required_blueprint_item_path := ""


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("CraftingRecipeDef requires id.")
	if station_id == &"":
		errors.append("CraftingRecipeDef requires station_id.")
	if output_item_path == "" or not ResourceLoader.exists(output_item_path):
		errors.append("CraftingRecipeDef requires a valid output_item_path.")
	if output_quantity <= 0:
		errors.append("CraftingRecipeDef output_quantity must be positive.")
	if ingredient_costs.is_empty():
		errors.append("CraftingRecipeDef requires at least one ingredient.")
	for index in range(ingredient_costs.size()):
		var cost := ingredient_costs[index]
		var item_path := str(cost.get("item_path", ""))
		var quantity := int(cost.get("quantity", 0))
		if item_path == "" or not ResourceLoader.exists(item_path):
			errors.append("CraftingRecipeDef ingredient %d has invalid item_path." % index)
		if quantity <= 0:
			errors.append("CraftingRecipeDef ingredient %d requires positive quantity." % index)
	if required_blueprint_item_path != "" and not ResourceLoader.exists(required_blueprint_item_path):
		errors.append("CraftingRecipeDef required_blueprint_item_path is invalid.")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()
