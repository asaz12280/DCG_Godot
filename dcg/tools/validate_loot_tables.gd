extends SceneTree

const LootTableScript := preload("res://scripts/loot/loot_table.gd")
const LootTableEntryScript := preload("res://scripts/loot/loot_table_entry.gd")
const CommonTable := preload("res://data/loot_tables/refuge_outskirts_common.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_common_table()
	_validate_invalid_entry_is_caught()
	_validate_empty_table_is_caught()
	if _errors.is_empty():
		print("[loot_tables] OK common=valid roll=stacks invalid=caught empty=caught")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_common_table() -> void:
	var table := CommonTable as Resource
	if table == null:
		_errors.append("Common loot table should load as LootTable.")
		return
	if table.get_script() != LootTableScript:
		_errors.append("Common loot table should use LootTable script.")
	var validation_errors: Array[String] = table.get_validation_errors()
	for error in validation_errors:
		_errors.append("Common loot table invalid: %s" % error)
	var rolled: Array[Dictionary] = table.roll(8, 12345)
	if rolled.is_empty():
		_errors.append("Common loot table should roll at least one stack.")
	for stack in rolled:
		if typeof(stack) != TYPE_DICTIONARY:
			_errors.append("Loot roll result should be a Dictionary stack.")
			continue
		var item_path := str(stack.get("item_path", ""))
		var quantity := int(stack.get("quantity", 0))
		if item_path == "" or not ResourceLoader.exists(item_path):
			_errors.append("Loot roll returned invalid item path: %s" % item_path)
		if quantity <= 0:
			_errors.append("Loot roll returned non-positive quantity.")


func _validate_invalid_entry_is_caught() -> void:
	var entry := LootTableEntryScript.new()
	entry.item_path = "res://data/items/missing/nope.tres"
	entry.min_quantity = 1
	entry.max_quantity = 1
	entry.weight = 1.0
	var table := LootTableScript.new()
	table.id = &"invalid_entry_check"
	table.entries = [entry]
	if table.get_validation_errors().is_empty():
		_errors.append("LootTable validation should catch invalid item paths.")


func _validate_empty_table_is_caught() -> void:
	var table := LootTableScript.new()
	table.id = &"empty_check"
	if table.get_validation_errors().is_empty():
		_errors.append("LootTable validation should catch empty tables.")
