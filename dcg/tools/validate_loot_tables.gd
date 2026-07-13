extends SceneTree

const LootTableScript := preload("res://scripts/loot/loot_table.gd")
const LootTableEntryScript := preload("res://scripts/loot/loot_table_entry.gd")
const CommonTable := preload("res://data/loot_tables/refuge_outskirts_common.tres")
const DarkGreenCrateTable := preload("res://data/loot_tables/crate_dark_green_weapons.tres")
const RedCrateTable := preload("res://data/loot_tables/crate_red_supplies.tres")
const WhiteCrateTable := preload("res://data/loot_tables/crate_white_misc_food.tres")
const YellowLockedCrateTable := preload("res://data/loot_tables/crate_yellow_locked_cache.tres")
const BlueLockedCrateTable := preload("res://data/loot_tables/crate_blue_locked_armor.tres")
const LOCALIZATION_SOURCE := "res://data/localization/game_text.csv"
const PISTOL_PATH := "res://data/items/weapons/pistol_S.tres"
const SMG_PATH := "res://data/items/weapons/smg_S.tres"
const AMMO_PATH := "res://data/items/ammo/ammo_S.tres"
const KNIFE_PATH := "res://data/items/weapons/combat_knife.tres"
const WAREHOUSE_KEY_PATH := "res://data/items/keys/warehouse_key.tres"
const TACTICAL_HEADSET_PATH := "res://data/items/attachments/tactical_headset.tres"
const TACTICAL_GLASSES_PATH := "res://data/items/attachments/tactical_glasses.tres"
const DEFENSE_TOTEM_PATH := "res://data/items/totems/defense_totem.tres"
const LIFE_TOTEM_PATH := "res://data/items/totems/life_totem.tres"
const BASIC_HELMET_PATH := "res://data/items/armor/basic_helmet.tres"
const LIGHT_ARMOR_PATH := "res://data/items/armor/light_armor.tres"
const SMALL_BACKPACK_PATH := "res://data/items/backpacks/small_backpack.tres"

var _errors: Array[String] = []
var _localization_source := ""


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_localization_source = FileAccess.get_file_as_string(LOCALIZATION_SOURCE)
	_validate_common_table()
	_validate_colored_crate_tables()
	_validate_invalid_entry_is_caught()
	_validate_uncataloged_entry_is_caught()
	_validate_empty_table_is_caught()
	if _errors.is_empty():
		print("[loot_tables] OK common=valid colored_crates=typed roll=codex_named invalid=caught uncataloged=caught empty=caught")
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
	_validate_high_grade_ammo_entry(table)
	_validate_attachment_entries(table)
	_validate_fix_station_tool_entries(table)
	_validate_disassemble_station_tool_entries(table)
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
		else:
			_validate_roll_item_has_codex_name(item_path)
		if quantity <= 0:
			_errors.append("Loot roll returned non-positive quantity.")
	if not _rolled_contains_path(rolled, PISTOL_PATH):
		_errors.append("Common loot table should always roll No.5 pistol for early container proof.")
	if not _rolled_contains_path(rolled, AMMO_PATH):
		_errors.append("Common loot table should always roll No.7 ammo for early container proof.")


func _validate_colored_crate_tables() -> void:
	_validate_typed_table(
		DarkGreenCrateTable,
		"Dark green weapon crate",
		["weapon", "ammo"],
		[PISTOL_PATH, AMMO_PATH, KNIFE_PATH]
	)
	_validate_typed_table(
		RedCrateTable,
		"Red supply crate",
		["medical", "consumable", "food"],
		["res://data/items/medical/bandage.tres", "res://data/items/food/bottled_water.tres", "res://data/items/food/bread.tres"]
	)
	_validate_typed_table(
		WhiteCrateTable,
		"White misc crate",
		["key"],
		[WAREHOUSE_KEY_PATH]
	)
	_validate_red_supply_guarantees()
	_validate_white_key_only_table()
	_validate_dark_green_weapon_guarantees()
	_validate_yellow_locked_crate_table()
	_validate_blue_locked_crate_table()


func _validate_typed_table(table: Resource, label: String, allowed_types: Array[String], required_paths: Array[String]) -> void:
	if table == null:
		_errors.append("%s should load as LootTable." % label)
		return
	for error in table.get_validation_errors():
		_errors.append("%s invalid: %s" % [label, error])
	var entries := _all_entries(table)
	for item_path in required_paths:
		if not _entry_list_contains_path(entries, item_path):
			_errors.append("%s should include %s." % [label, item_path])
	for entry: Variant in entries:
		var item_path := str(entry.get("item_path")) if entry != null else ""
		var item := load(item_path) as ItemDef
		if item == null:
			continue
		if not allowed_types.has(item.item_type):
			_errors.append("%s should not contain %s item %s." % [label, item.item_type, item_path])
		_validate_roll_item_has_codex_name(item_path, label)
	var rolled: Array[Dictionary] = table.roll(12, 24680)
	if rolled.is_empty():
		_errors.append("%s should roll visible loot." % label)
	for stack in rolled:
		var rolled_item := load(str(stack.get("item_path", ""))) as ItemDef
		if rolled_item != null and not allowed_types.has(rolled_item.item_type):
			_errors.append("%s rolled disallowed %s item %s." % [label, rolled_item.item_type, rolled_item.resource_path])


func _validate_red_supply_guarantees() -> void:
	var guaranteed: Array = RedCrateTable.get("guaranteed_entries")
	for item_path in ["res://data/items/medical/bandage.tres", "res://data/items/food/bottled_water.tres", "res://data/items/food/bread.tres"]:
		if not _entry_list_contains_path(guaranteed, item_path):
			_errors.append("Red supply crate guaranteed entries should include %s." % item_path)


func _validate_white_key_only_table() -> void:
	var guaranteed: Array = WhiteCrateTable.get("guaranteed_entries")
	var entries: Array = WhiteCrateTable.get("entries")
	if guaranteed.size() != 1 or not _entry_list_contains_path(guaranteed, WAREHOUSE_KEY_PATH):
		_errors.append("White misc crate should only guarantee the warehouse key.")
	if not entries.is_empty():
		_errors.append("White misc crate should not roll random loot while it is key-only.")
	var rolled: Array[Dictionary] = WhiteCrateTable.roll(12, 24680)
	if rolled.size() != 1 or not _rolled_contains_path(rolled, WAREHOUSE_KEY_PATH):
		_errors.append("White misc crate roll should return only the warehouse key.")
	if _rolled_quantity(rolled, WAREHOUSE_KEY_PATH) != 2:
		_errors.append("White misc crate should guarantee exactly two warehouse keys.")


func _validate_dark_green_weapon_guarantees() -> void:
	var guaranteed: Array = DarkGreenCrateTable.get("guaranteed_entries")
	var entries: Array = DarkGreenCrateTable.get("entries")
	for item_path in [PISTOL_PATH, AMMO_PATH, SMG_PATH, KNIFE_PATH]:
		if not _entry_list_contains_path(guaranteed, item_path):
			_errors.append("Dark green weapon crate guaranteed entries should include %s." % item_path)
	if not entries.is_empty():
		_errors.append("Dark green weapon crate should not keep combat knife in random entries.")
	var rolled: Array[Dictionary] = DarkGreenCrateTable.roll(12, 24680)
	var knife_count := 0
	for stack in rolled:
		if str(stack.get("item_path", "")) == KNIFE_PATH:
			knife_count += int(stack.get("quantity", 0))
	if knife_count != 1:
		_errors.append("Dark green weapon crate should roll exactly one combat knife, got %d." % knife_count)
	if not _rolled_contains_path(rolled, SMG_PATH):
		_errors.append("Dark green weapon crate should roll one SMG-S as a guaranteed weapon.")


func _validate_yellow_locked_crate_table() -> void:
	var table := YellowLockedCrateTable
	var label := "Yellow locked crate"
	if table == null:
		_errors.append("%s should load as LootTable." % label)
		return
	for error in table.get_validation_errors():
		_errors.append("%s invalid: %s" % [label, error])
	var guaranteed: Array = table.get("guaranteed_entries")
	var entries: Array = table.get("entries")
	var required_paths := [TACTICAL_HEADSET_PATH, TACTICAL_GLASSES_PATH, DEFENSE_TOTEM_PATH, SMALL_BACKPACK_PATH]
	if guaranteed.size() != required_paths.size():
		_errors.append("%s should have exactly %d guaranteed entries." % [label, required_paths.size()])
	if not entries.is_empty():
		_errors.append("%s should not have random entries; it should only drop the guaranteed equipment/totem set." % label)
	for item_path in required_paths:
		if not _entry_list_contains_path(guaranteed, item_path):
			_errors.append("%s guaranteed entries should include %s." % [label, item_path])
	for entry in _all_entries(table):
		var item_path := str(entry.get("item_path")) if entry != null else ""
		if not required_paths.has(item_path):
			_errors.append("%s should not contain non-guaranteed item %s." % [label, item_path])
		_validate_roll_item_has_codex_name(item_path, label)
	var rolled: Array[Dictionary] = table.roll(1, 24680)
	if rolled.size() != required_paths.size():
		_errors.append("%s should roll exactly its guaranteed stacks, got %d." % [label, rolled.size()])
	for item_path in required_paths:
		if not _rolled_contains_path(rolled, item_path):
			_errors.append("%s roll should include guaranteed item %s." % [label, item_path])


func _validate_blue_locked_crate_table() -> void:
	var table := BlueLockedCrateTable
	var label := "Blue locked crate"
	if table == null:
		_errors.append("%s should load as LootTable." % label)
		return
	for error in table.get_validation_errors():
		_errors.append("%s invalid: %s" % [label, error])
	var guaranteed: Array = table.get("guaranteed_entries")
	var entries: Array = table.get("entries")
	var required_paths := [BASIC_HELMET_PATH, LIGHT_ARMOR_PATH, LIFE_TOTEM_PATH]
	if guaranteed.size() != required_paths.size():
		_errors.append("%s should have exactly %d guaranteed entries." % [label, required_paths.size()])
	if not entries.is_empty():
		_errors.append("%s should not have random entries." % label)
	for item_path in required_paths:
		if not _entry_list_contains_path(guaranteed, item_path):
			_errors.append("%s guaranteed entries should include %s." % [label, item_path])
	var rolled: Array[Dictionary] = table.roll(1, 24680)
	if rolled.size() != required_paths.size():
		_errors.append("%s should roll exactly its guaranteed stacks, got %d." % [label, rolled.size()])
	for item_path in required_paths:
		if not _rolled_contains_path(rolled, item_path):
			_errors.append("%s roll should include guaranteed item %s." % [label, item_path])


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


func _validate_uncataloged_entry_is_caught() -> void:
	var entry := LootTableEntryScript.new()
	entry.item_path = "res://data/items/missing_validation_item.tres"
	entry.min_quantity = 1
	entry.max_quantity = 1
	entry.weight = 1.0
	var table := LootTableScript.new()
	table.id = &"uncataloged_entry_check"
	table.entries = [entry]
	var validation_errors := table.get_validation_errors()
	if validation_errors.is_empty():
		_errors.append("LootTable validation should catch items missing a codex number.")
	elif not "\n".join(validation_errors).contains("not in the codex"):
		_errors.append("LootTable validation should explain uncataloged loot items.")


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


func _validate_high_grade_ammo_entry(table: Resource) -> void:
	var entries: Array = table.get("entries")
	_validate_entries_have_codex_names(entries, "Common loot table entry")


func _validate_attachment_entries(table: Resource) -> void:
	var entries: Array = table.get("entries")
	for entry: Variant in entries:
		var item_path := str(entry.get("item_path")) if entry != null else ""
		if item_path.contains("/attachments/"):
			_errors.append("Common loot table should not include uncataloged attachment loot yet: %s" % item_path)


func _validate_fix_station_tool_entries(table: Resource) -> void:
	var entries: Array = table.get("entries")
	for entry: Variant in entries:
		var item_path := str(entry.get("item_path")) if entry != null else ""
		if item_path.contains("/tools/"):
			_errors.append("Common loot table should not include uncataloged tool loot yet: %s" % item_path)


func _validate_disassemble_station_tool_entries(table: Resource) -> void:
	var entries: Array = table.get("entries")
	for entry: Variant in entries:
		var item_path := str(entry.get("item_path")) if entry != null else ""
		if item_path.contains("/tools/"):
			_errors.append("Common loot table should not include uncataloged station tool loot yet: %s" % item_path)


func _validate_entries_have_codex_names(entries: Array, label: String) -> void:
	for index in range(entries.size()):
		var entry: Variant = entries[index]
		if entry == null:
			continue
		_validate_roll_item_has_codex_name(str(entry.get("item_path")), "%s %d" % [label, index])


func _validate_roll_item_has_codex_name(item_path: String, label: String = "Loot roll") -> void:
	var item := load(item_path) as ItemDef
	if item == null:
		return
	if item.catalog_number < 1:
		_errors.append("%s item should have a codex number: %s" % [label, item_path])
	var key_text := str(item.name_key)
	if key_text == "" or not _localization_has_key(key_text):
		_errors.append("%s item should have a localized codex name: %s" % [label, item_path])


func _localization_has_key(key_text: String) -> bool:
	if key_text == "":
		return false
	return _localization_source.contains("\n%s," % key_text) or _localization_source.begins_with("%s," % key_text)


func _entry_list_contains_path(entries: Array, item_path: String) -> bool:
	for entry in entries:
		if entry != null and str(entry.get("item_path")) == item_path:
			return true
	return false


func _all_entries(table: Resource) -> Array:
	var combined: Array = []
	if table == null:
		return combined
	combined.append_array(table.get("guaranteed_entries"))
	combined.append_array(table.get("entries"))
	return combined


func _rolled_contains_path(rolled: Array[Dictionary], item_path: String) -> bool:
	for stack in rolled:
		if str(stack.get("item_path", "")) == item_path:
			return true
	return false


func _rolled_quantity(rolled: Array[Dictionary], item_path: String) -> int:
	var total := 0
	for stack in rolled:
		if str(stack.get("item_path", "")) == item_path:
			total += int(stack.get("quantity", 0))
	return total
