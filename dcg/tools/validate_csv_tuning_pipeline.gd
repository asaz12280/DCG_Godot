extends SceneTree

const CsvDataTableLoaderScript := preload("res://scripts/data/csv_data_table_loader.gd")
const WeaponTuningServiceScript := preload("res://scripts/combat/weapon_tuning_service.gd")
const ITEM_TABLE_PATH := "res://data/tuning/items.csv"
const WEAPON_TABLE_PATH := "res://data/tuning/weapons.csv"
const DIFFICULTY_TABLE_PATH := "res://data/tuning/difficulty.csv"
const EXPECTED_WEAPON_IDS := [&"pistol_S", &"smg_S", &"shotgun_SG", &"combat_knife"]
const EXPECTED_DIFFICULTY_IDS := [&"easy", &"normal", &"hard"]
const ITEM_VALUE_FIELDS := [
	"weight",
	"value",
	"max_stack",
	"defense_bonus",
	"heal_amount",
	"use_duration_seconds",
	"max_health_bonus",
	"stamina_restore",
	"thirst_restore",
	"satiety_restore",
]
const WEAPON_VALUE_FIELDS := [
	"damage",
	"fire_rate_per_second",
	"projectiles_per_shot",
	"projectile_spread_degrees",
	"armor_penetration_level",
	"critical_chance",
	"projectile_pierce_chance",
	"magazine_capacity",
	"reload_duration_seconds",
	"projectile_range",
	"durability_wear_per_shot",
	"max_durability",
	"repair_max_durability_loss",
	"durability_penalty_ratio",
	"vertical_recoil",
	"horizontal_recoil",
]
const LEGACY_FIELDS := {
	"damage": "damage",
	"fire_rate_per_second": "fire_rate_per_second",
	"projectiles_per_shot": "projectiles_per_shot",
	"projectile_spread_degrees": "projectile_spread_degrees",
	"armor_penetration_level": "weapon_armor_penetration_level",
	"critical_chance": "critical_chance",
	"projectile_pierce_chance": "projectile_pierce_chance",
	"magazine_capacity": "magazine_capacity",
	"reload_duration_seconds": "reload_duration_seconds",
	"projectile_range": "projectile_range",
	"durability_wear_per_shot": "weapon_durability_wear_per_shot",
	"max_durability": "max_durability",
	"repair_max_durability_loss": "repair_max_durability_loss",
	"durability_penalty_ratio": "durability_penalty_ratio",
	"vertical_recoil": "weapon_vertical_recoil",
	"horizontal_recoil": "weapon_horizontal_recoil",
}

var _errors: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_validate_import_ownership()
	var item_rows := CsvDataTableLoaderScript.load_records(ITEM_TABLE_PATH)
	var weapon_rows := CsvDataTableLoaderScript.load_records(WEAPON_TABLE_PATH)
	var difficulty_rows := CsvDataTableLoaderScript.load_records(DIFFICULTY_TABLE_PATH)
	_validate_imported_records(ITEM_TABLE_PATH, item_rows)
	_validate_imported_records(WEAPON_TABLE_PATH, weapon_rows)
	_validate_imported_records(DIFFICULTY_TABLE_PATH, difficulty_rows)
	_validate_item_rows(item_rows)
	_validate_weapon_rows(weapon_rows)
	_validate_difficulty_rows(difficulty_rows)
	_validate_runtime_boundaries()
	if _errors.is_empty():
		print("[csv_tuning_pipeline] OK importer=csv_data headers=dictionaries items=22 weapons=4 difficulty=3 resources=synced localization=protected boundaries=clean")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _validate_import_ownership() -> void:
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	_expect(project_source.contains("res://addons/csv-data-importer/plugin.cfg"), "CSV Data Importer should be enabled.")
	for table_path in [ITEM_TABLE_PATH, WEAPON_TABLE_PATH, DIFFICULTY_TABLE_PATH]:
		var import_source := FileAccess.get_file_as_string(table_path + ".import")
		_expect(import_source.contains('importer="com.timothyqiu.godot-csv-importer"'), "%s should use CSV Data Importer." % table_path)
		_expect(import_source.contains("headers=true"), "%s should import records with headers." % table_path)
		_expect(import_source.contains("detect_numbers=true"), "%s should detect numeric tuning values." % table_path)
		_expect(import_source.contains("force_float=false"), "%s should preserve integer tuning values." % table_path)
	for translation_path in ["res://data/localization/game_text.csv", "res://data/localization/dialogue_text.csv"]:
		var import_source := FileAccess.get_file_as_string(translation_path + ".import")
		_expect(import_source.contains('importer="csv_translation"'), "%s must remain owned by Godot CSV Translation." % translation_path)
	var reference_import := FileAccess.get_file_as_string("res://data/reference/resource_reference_index.csv.import")
	_expect(reference_import.contains('importer="com.timothyqiu.godot-csv-importer"') and reference_import.contains("headers=true"), "Resource reference index should import as CSV Data dictionary records.")
	for filename in DirAccess.get_files_at("res://data/reference"):
		_expect(not (filename.begins_with("resource_reference_index.") and filename.ends_with(".translation")), "Resource reference index should not generate translation resources: %s" % filename)


func _validate_imported_records(path: String, rows: Array[Dictionary]) -> void:
	_expect(not rows.is_empty(), "%s should load non-empty dictionary records." % path)
	var imported := load(path)
	_expect(imported != null and imported.get("records") is Array, "%s should load as a CSV Data Resource." % path)
	if imported != null and imported.get("records") is Array:
		var imported_rows := imported.get("records") as Array
		_expect(not imported_rows.is_empty() and imported_rows[0] is Dictionary, "%s imported records should be dictionaries." % path)


func _validate_item_rows(rows: Array[Dictionary]) -> void:
	var rows_by_id: Dictionary = {}
	var tuned_paths: Dictionary = {}
	for row in rows:
		var item_id := StringName(str(row.get("item_id", "")))
		var resource_path := str(row.get("resource_path", ""))
		_expect(not rows_by_id.has(item_id), "Item tuning ids should be unique: %s" % item_id)
		_expect(not tuned_paths.has(resource_path), "Item tuning resource paths should be unique: %s" % resource_path)
		rows_by_id[item_id] = row
		tuned_paths[resource_path] = true
		_expect(int(row.get("schema_version", 0)) == 1, "Item tuning %s should use schema version 1." % item_id)
		_expect(float(row.get("weight", -1.0)) >= 0.0, "Item tuning %s requires non-negative weight." % item_id)
		_expect(int(row.get("value", -1)) >= 0, "Item tuning %s requires non-negative value." % item_id)
		_expect(int(row.get("max_stack", 0)) >= 1, "Item tuning %s requires max_stack of at least one." % item_id)
		var item := load(resource_path) as ItemDef
		_expect(item != null and item.id == item_id, "Item tuning %s should resolve to its matching ItemDef." % item_id)
		if item == null:
			continue
		for field in ITEM_VALUE_FIELDS:
			_expect(_numeric_equal(item.get(field), row.get(field)), "ItemDef %s.%s should match items.csv." % [item_id, field])
		if item.armor_profile != null:
			_expect(_numeric_equal(item.armor_profile.defense_bonus, row.get("defense_bonus")), "ArmorProfile %s defense should match items.csv." % item_id)
	var item_paths: Array[String] = []
	_collect_item_paths("res://data/items", item_paths)
	for path in item_paths:
		_expect(tuned_paths.has(path), "items.csv is missing ItemDef resource: %s" % path)
	_expect(rows.size() == item_paths.size(), "items.csv should contain exactly one row for every ItemDef resource.")


func _validate_weapon_rows(rows: Array[Dictionary]) -> void:
	var rows_by_id: Dictionary = {}
	for row in rows:
		var weapon_id := StringName(str(row.get("weapon_id", "")))
		_expect(not rows_by_id.has(weapon_id), "Weapon tuning ids should be unique: %s" % weapon_id)
		rows_by_id[weapon_id] = row
		_expect(int(row.get("schema_version", 0)) == 1, "Weapon tuning %s should use schema version 1." % weapon_id)
		_expect(int(row.get("damage", -1)) >= 0, "Weapon tuning %s requires non-negative damage." % weapon_id)
		_expect(float(row.get("fire_rate_per_second", 0.0)) > 0.0, "Weapon tuning %s requires positive fire rate." % weapon_id)
		_expect(int(row.get("projectiles_per_shot", 0)) in range(1, 33), "Weapon tuning %s projectiles_per_shot should be 1..32." % weapon_id)
		_expect(float(row.get("projectile_spread_degrees", -1.0)) >= 0.0 and float(row.get("projectile_spread_degrees", 91.0)) <= 90.0, "Weapon tuning %s spread should be 0..90 degrees." % weapon_id)
	for weapon_id in EXPECTED_WEAPON_IDS:
		_expect(rows_by_id.has(weapon_id), "Weapon tuning table is missing %s." % weapon_id)
		if not rows_by_id.has(weapon_id):
			continue
		var row := rows_by_id[weapon_id] as Dictionary
		var item := load(str(row.get("resource_path", ""))) as ItemDef
		_expect(item != null and item.id == weapon_id and item.weapon_profile != null, "Weapon tuning %s should resolve to its typed resource." % weapon_id)
		if item == null or item.weapon_profile == null:
			continue
		for field in WEAPON_VALUE_FIELDS:
			_expect(_numeric_equal(item.weapon_profile.get(field), row.get(field)), "WeaponProfile %s.%s should match weapons.csv." % [weapon_id, field])
			_expect(_numeric_equal(item.get(LEGACY_FIELDS[field]), row.get(field)), "ItemDef compatibility field %s.%s should match weapons.csv." % [weapon_id, LEGACY_FIELDS[field]])
		var snapshot := WeaponTuningServiceScript.resolve_snapshot(item)
		_expect(_numeric_equal(snapshot.get("damage"), row.get("damage")), "Weapon snapshot %s damage should come from synchronized tuning." % weapon_id)
	_expect(rows_by_id.size() == EXPECTED_WEAPON_IDS.size(), "Weapon tuning table should contain only the four current weapon ids.")


func _validate_difficulty_rows(rows: Array[Dictionary]) -> void:
	var rows_by_id: Dictionary = {}
	for row in rows:
		var difficulty_id := StringName(str(row.get("difficulty_id", "")))
		_expect(not rows_by_id.has(difficulty_id), "Difficulty tuning ids should be unique: %s" % difficulty_id)
		rows_by_id[difficulty_id] = row
		_expect(int(row.get("schema_version", 0)) == 1, "Difficulty tuning %s should use schema version 1." % difficulty_id)
		_expect(float(row.get("player_health_multiplier", 0.0)) > 0.0, "Difficulty tuning %s requires a positive health multiplier." % difficulty_id)
	for difficulty_id in EXPECTED_DIFFICULTY_IDS:
		_expect(rows_by_id.has(difficulty_id), "Difficulty tuning table is missing %s." % difficulty_id)
		if not rows_by_id.has(difficulty_id):
			continue
		var row := rows_by_id[difficulty_id] as Dictionary
		var profile := load(str(row.get("resource_path", ""))) as DifficultyProfile
		_expect(profile != null and profile.id == difficulty_id, "Difficulty tuning %s should resolve to its typed resource." % difficulty_id)
		if profile != null:
			_expect(_numeric_equal(profile.player_health_multiplier, row.get("player_health_multiplier")), "DifficultyProfile %s should match difficulty.csv." % difficulty_id)
	_expect(rows_by_id.size() == EXPECTED_DIFFICULTY_IDS.size(), "Difficulty tuning table should contain only easy, normal, and hard.")
	var bootstrap := root.get_node_or_null("GameTuningBootstrap")
	_expect(bootstrap != null and (bootstrap.get("last_errors") as Array).is_empty(), "GameTuningBootstrap should apply both tables without errors.")


func _validate_runtime_boundaries() -> void:
	for path in [
		"res://scripts/combat/weapon_controller_3d.gd",
		"res://scripts/player/player_controller_3d.gd",
		"res://scripts/ui/item_inspection_snapshot_builder.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.contains("data/tuning/") and not source.contains("CsvDataTableLoader"), "%s should consume typed resources or snapshots, not CSV tables." % path)


func _collect_item_paths(directory_path: String, result: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		if directory.current_is_dir():
			_collect_item_paths(directory_path.path_join(entry), result)
		elif entry.ends_with(".tres"):
			result.append(directory_path.path_join(entry))
		entry = directory.get_next()
	directory.list_dir_end()


func _numeric_equal(first: Variant, second: Variant) -> bool:
	return is_equal_approx(float(first), float(second))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
