class_name LootTable
extends Resource

@export var id: StringName = &""
@export var entries: Array[Resource] = []


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("LootTable is missing id.")
	if entries.is_empty():
		errors.append("LootTable has no entries.")
	for index in range(entries.size()):
		var entry := entries[index]
		if entry == null:
			errors.append("LootTable entry %d is null." % index)
			continue
		if not entry.has_method("get_validation_errors"):
			errors.append("LootTable entry %d is not a LootTableEntry." % index)
			continue
		for error in entry.get_validation_errors():
			errors.append("Entry %d: %s" % [index, error])
	if _total_weight() <= 0.0:
		errors.append("LootTable total weight must be positive.")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()


func roll(count: int = 1, seed: int = 0) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if count <= 0 or not is_valid():
		return results
	var rng := RandomNumberGenerator.new()
	if seed != 0:
		rng.seed = seed
	else:
		rng.randomize()
	for _index in range(count):
		var entry: Resource = _weighted_pick(rng)
		if entry == null:
			continue
		var stack: Dictionary = entry.roll_stack(rng)
		if not stack.is_empty():
			results.append(stack)
	return results


func _weighted_pick(rng: RandomNumberGenerator) -> Resource:
	var total := _total_weight()
	if total <= 0.0:
		return null
	var roll_value := rng.randf_range(0.0, total)
	var cursor := 0.0
	for entry in entries:
		if entry == null or not entry.has_method("is_valid") or not entry.is_valid():
			continue
		cursor += entry.weight
		if roll_value <= cursor:
			return entry
	return null


func _total_weight() -> float:
	var total := 0.0
	for entry in entries:
		if entry == null or not entry.has_method("is_valid") or not entry.is_valid():
			continue
		total += entry.weight
	return total
