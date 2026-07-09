extends SceneTree

const ItemStackSorterScript := preload("res://scripts/inventory/item_stack_sorter.gd")
const Wood := preload("res://data/items/crafting/wood.tres")
const Wire := preload("res://data/items/electronics/wire.tres")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_value_sort()
	_validate_weight_sort()
	_validate_value_weight_sort()
	_validate_type_sort()
	_validate_empty_slots_are_preserved_when_requested()
	_validate_mode_cycle()
	if _errors.is_empty():
		print("[item_stack_sorter] OK modes=value/weight/value_weight/type empty_slots=preserved")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_value_sort() -> void:
	var sorted := _sorted([Wood.to_stack(1), Wire.to_stack(1), Pistol.to_stack(1)], &"value")
	_expect_catalog_order(sorted, [Pistol.catalog_number, Wire.catalog_number, Wood.catalog_number], "Value sort should prioritize total stack value.")


func _validate_weight_sort() -> void:
	var sorted := _sorted([Wood.to_stack(1), Wire.to_stack(1), Pistol.to_stack(1)], &"weight")
	_expect_catalog_order(sorted, [Pistol.catalog_number, Wood.catalog_number, Wire.catalog_number], "Weight sort should prioritize total stack weight.")


func _validate_value_weight_sort() -> void:
	var sorted := _sorted([Wood.to_stack(1), Wire.to_stack(1), Pistol.to_stack(1)], &"value_weight")
	_expect_catalog_order(sorted, [Pistol.catalog_number, Wire.catalog_number, Wood.catalog_number], "Value/kg sort should prioritize value density.")


func _validate_type_sort() -> void:
	var sorted := _sorted([Pistol.to_stack(1), Wood.to_stack(1), Wire.to_stack(1)], &"type")
	_expect_catalog_order(sorted, [Wood.catalog_number, Wire.catalog_number, Pistol.catalog_number], "Type sort should keep category/name order stable.")


func _validate_empty_slots_are_preserved_when_requested() -> void:
	var source: Array[Dictionary] = [Wood.to_stack(1), {}, Pistol.to_stack(1), {}]
	var sorted: Array[Dictionary] = ItemStackSorterScript.sort_stacks(source, &"weight", true)
	if sorted.size() != source.size():
		_errors.append("Sort should preserve fixed-slot container size when requested.")
	if sorted.size() >= 4:
		if int(sorted[0].get("catalog_number", 0)) != Pistol.catalog_number:
			_errors.append("Fixed-slot weight sort should move occupied stacks before empty slots.")
		if not sorted[2].is_empty() or not sorted[3].is_empty():
			_errors.append("Fixed-slot sort should keep empty slots at the tail.")


func _validate_mode_cycle() -> void:
	if ItemStackSorterScript.next_mode(&"value") != &"weight":
		_errors.append("Sort mode cycle should advance value to weight.")
	if ItemStackSorterScript.next_mode(&"weight") != &"value_weight":
		_errors.append("Sort mode cycle should advance weight to value_weight.")
	if ItemStackSorterScript.next_mode(&"value_weight") != &"type":
		_errors.append("Sort mode cycle should advance value_weight to type.")
	if ItemStackSorterScript.normalized_mode(&"missing") != &"type":
		_errors.append("Unknown sort mode should fall back to type.")


func _sorted(stacks: Array[Dictionary], mode: StringName) -> Array[Dictionary]:
	return ItemStackSorterScript.sort_stacks(stacks, mode)


func _expect_catalog_order(stacks: Array[Dictionary], expected_catalogs: Array[int], message: String) -> void:
	if stacks.size() < expected_catalogs.size():
		_errors.append("%s Missing sorted stacks." % message)
		return
	for index in range(expected_catalogs.size()):
		var actual := int(stacks[index].get("catalog_number", 0))
		if actual != expected_catalogs[index]:
			_errors.append("%s Expected catalog %d at %d, got %d." % [message, expected_catalogs[index], index, actual])
