class_name UpgradeDef
extends Resource

@export var id: StringName = &""
@export var display_name := ""
@export var description := ""
@export_range(0, 999999, 1) var money_cost := 0
@export var item_costs: Array[Dictionary] = []
@export_range(0, 999, 1) var starter_ammo_bonus := 0


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("UpgradeDef requires id.")
	if display_name == "":
		errors.append("UpgradeDef requires display_name.")
	if description == "":
		errors.append("UpgradeDef requires description.")
	if money_cost < 0:
		errors.append("UpgradeDef money_cost cannot be negative.")
	if starter_ammo_bonus < 0:
		errors.append("UpgradeDef starter_ammo_bonus cannot be negative.")
	for index in range(item_costs.size()):
		var cost := item_costs[index]
		var item_path := str(cost.get("item_path", ""))
		var quantity := int(cost.get("quantity", 0))
		if item_path == "" or not ResourceLoader.exists(item_path):
			errors.append("UpgradeDef item cost %d has invalid item_path." % index)
		if quantity <= 0:
			errors.append("UpgradeDef item cost %d requires positive quantity." % index)
	if money_cost <= 0 and item_costs.is_empty():
		errors.append("UpgradeDef should require at least one cost.")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()
