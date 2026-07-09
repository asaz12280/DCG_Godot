class_name ItemStackSorter
extends RefCounted

const MODE_TYPE := &"type"
const MODE_VALUE := &"value"
const MODE_WEIGHT := &"weight"
const MODE_VALUE_WEIGHT := &"value_weight"
const MODE_SEQUENCE: Array[StringName] = [MODE_TYPE, MODE_VALUE, MODE_WEIGHT, MODE_VALUE_WEIGHT]


static func next_mode(mode: StringName) -> StringName:
	var index := MODE_SEQUENCE.find(mode)
	if index < 0:
		return MODE_VALUE
	return MODE_SEQUENCE[(index + 1) % MODE_SEQUENCE.size()]


static func normalized_mode(mode: StringName) -> StringName:
	if MODE_SEQUENCE.has(mode):
		return mode
	return MODE_TYPE


static func sort_stacks(stacks: Array[Dictionary], mode: StringName = MODE_TYPE, keep_empty_slots: bool = false) -> Array[Dictionary]:
	var sorted: Array[Dictionary] = []
	var empty_count := 0
	for stack in stacks:
		if stack.is_empty():
			empty_count += 1
			continue
		sorted.append(stack.duplicate(true))
	var selected_mode := normalized_mode(mode)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _is_before(a, b, selected_mode)
	)
	if keep_empty_slots:
		for _index in range(empty_count):
			sorted.append({})
	return sorted


static func sort_stacks_in_place(stacks: Array[Dictionary], mode: StringName = MODE_TYPE, keep_empty_slots: bool = false) -> Array[Dictionary]:
	var sorted := sort_stacks(stacks, mode, keep_empty_slots)
	stacks.clear()
	for stack in sorted:
		stacks.append(stack)
	return stacks


static func stack_sort_value(stack: Dictionary, mode: StringName) -> float:
	var quantity := maxi(int(stack.get("quantity", 1)), 1)
	var value := float(maxi(int(stack.get("value", 0)), 0))
	var weight := maxf(float(stack.get("weight", 0.0)), 0.0)
	match normalized_mode(mode):
		MODE_VALUE:
			return value * float(quantity)
		MODE_WEIGHT:
			return weight * float(quantity)
		MODE_VALUE_WEIGHT:
			if weight <= 0.0:
				return value * 1000.0
			return value / weight
		_:
			return 0.0


static func _is_before(a: Dictionary, b: Dictionary, mode: StringName) -> bool:
	if mode == MODE_TYPE:
		return _type_key(a) < _type_key(b)
	var value_a := stack_sort_value(a, mode)
	var value_b := stack_sort_value(b, mode)
	if not is_equal_approx(value_a, value_b):
		return value_a > value_b
	return _type_key(a) < _type_key(b)


static func _type_key(stack: Dictionary) -> String:
	return "%s|%s|%04d" % [
		str(stack.get("type", "")),
		str(stack.get("name_key", stack.get("name", ""))),
		int(stack.get("catalog_number", 0)),
	]
