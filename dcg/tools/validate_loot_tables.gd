extends SceneTree

const LootTableScript := preload("res://scripts/loot/loot_table.gd")
const LootTableEntryScript := preload("res://scripts/loot/loot_table_entry.gd")
const CommonTable := preload("res://data/loot_tables/refuge_outskirts_common.tres")
const PISTOL_PATH := "res://data/items/weapons/pistol_9mm.tres"
const AMMO_PATH := "res://data/items/ammo/ammo_9mm.tres"

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
	_validate_guaranteed_early_proof_items(table)
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
	if not _rolled_contains_path(rolled, PISTOL_PATH):
		_errors.append("Common loot table should always roll No.5 pistol for early container proof.")
	if not _rolled_contains_path(rolled, AMMO_PATH):
		_errors.append("Common loot table should always roll No.7 ammo for early container proof.")


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


func _validate_guaranteed_early_proof_items(table: Resource) -> void:
	var guaranteed: Array = table.get("guaranteed_entries")
	if guaranteed.size() < 2:
		_errors.append("Common loot table should have guaranteed entries for early pistol/ammo proof.")
	if not _entry_list_contains_path(guaranteed, PISTOL_PATH):
		_errors.append("Common loot table guaranteed entries should include No.5 pistol.")
	if not _entry_list_contains_path(guaranteed, AMMO_PATH):
		_errors.append("Common loot table guaranteed entries should include No.7 ammo.")


func _entry_list_contains_path(entries: Array, item_path: String) -> bool:
	for entry in entries:
		if entry != null and str(entry.get("item_path")) == item_path:
			return true
	return false


func _rolled_contains_path(rolled: Array[Dictionary], item_path: String) -> bool:
	for stack in rolled:
		if str(stack.get("item_path", "")) == item_path:
			return true
	return false
