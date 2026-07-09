class_name LootTableEntry
extends Resource

@export_file("*.tres", "*.res") var item_path := ""
@export_range(1, 999, 1) var min_quantity := 1
@export_range(1, 999, 1) var max_quantity := 1
@export_range(0.0, 9999.0, 0.1) var weight := 1.0
@export var tags: Array[StringName] = []


func is_valid() -> bool:
	return get_validation_errors().is_empty()


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if item_path == "":
		errors.append("Loot entry is missing item_path.")
	elif not ResourceLoader.exists(item_path):
		errors.append("Loot entry item_path does not exist: %s" % item_path)
	else:
		var item := load(item_path) as ItemDef
		if item == null:
			errors.append("Loot entry item_path is not an ItemDef: %s" % item_path)
		else:
			if item.catalog_number < 1:
				errors.append("Loot entry item is not in the codex: %s" % item_path)
			if item.name_key == &"":
				errors.append("Loot entry item is missing name_key: %s" % item_path)
	if min_quantity <= 0:
		errors.append("Loot entry min_quantity must be positive.")
	if max_quantity < min_quantity:
		errors.append("Loot entry max_quantity must be >= min_quantity.")
	if weight <= 0.0:
		errors.append("Loot entry weight must be positive.")
	return errors


func roll_stack(rng: RandomNumberGenerator) -> Dictionary:
	if not is_valid():
		return {}
	var item := load(item_path) as ItemDef
	if item == null:
		return {}
	var quantity := rng.randi_range(min_quantity, max_quantity)
	return {
		"item_path": item_path,
		"quantity": quantity,
		"resource_path": item_path,
		"tags": tags.duplicate(),
	}
