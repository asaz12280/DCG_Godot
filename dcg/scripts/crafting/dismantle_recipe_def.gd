class_name DismantleRecipeDef
extends Resource

@export var id: StringName = &""
@export var station_id: StringName = &"workbench"
@export var display_name_key: StringName = &""
@export var description_key: StringName = &""
@export var input_item_path := ""
@export_range(1, 999, 1) var input_quantity := 1
@export var output_stacks: Array[Dictionary] = []
@export var required_upgrade_id: StringName = &""


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("DismantleRecipeDef requires id.")
	if station_id == &"":
		errors.append("DismantleRecipeDef requires station_id.")
	if input_item_path == "" or not ResourceLoader.exists(input_item_path):
		errors.append("DismantleRecipeDef requires a valid input_item_path.")
	if input_quantity <= 0:
		errors.append("DismantleRecipeDef input_quantity must be positive.")
	if output_stacks.is_empty():
		errors.append("DismantleRecipeDef requires at least one output stack.")
	for index in range(output_stacks.size()):
		var stack := output_stacks[index]
		var item_path := str(stack.get("item_path", ""))
		var quantity := int(stack.get("quantity", 0))
		if item_path == "" or not ResourceLoader.exists(item_path):
			errors.append("DismantleRecipeDef output %d has invalid item_path." % index)
		if quantity <= 0:
			errors.append("DismantleRecipeDef output %d requires positive quantity." % index)
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()
