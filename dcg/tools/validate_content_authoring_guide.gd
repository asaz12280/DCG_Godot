extends SceneTree

const GUIDE_PATH := "res://docs/design/content_authoring_guide.md"

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_guide_exists()
	if _errors.is_empty():
		_validate_required_sections()
		_validate_required_resource_terms()
		_validate_required_validation_commands()
		_validate_current_resource_paths()
	if _errors.is_empty():
		print("[content_authoring_guide] OK sections=present resources=covered validation=listed")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_guide_exists() -> void:
	if not FileAccess.file_exists(GUIDE_PATH):
		_errors.append("Missing content authoring guide: %s" % GUIDE_PATH)


func _validate_required_sections() -> void:
	var text := _guide_text()
	for heading in [
		"# Project DCG Content Authoring Guide",
		"## Core Rules",
		"## Content Workflow",
		"## Item Authoring",
		"## Loot Table Authoring",
		"## Enemy Authoring",
		"## Quest Authoring",
		"## Upgrade Authoring",
		"## Localization Requirements",
		"## Validation Matrix",
		"## Definition Of Done For Content Expansion",
		"## Do Not Do Yet",
	]:
		if not text.contains(heading):
			_errors.append("Content authoring guide is missing heading: %s" % heading)


func _validate_required_resource_terms() -> void:
	var text := _guide_text()
	for term in [
		"ItemDef",
		"LootTable",
		"LootTableEntry",
		"EnemyDef",
		"QuestDef",
		"UpgradeDef",
		"game_text.csv",
		"res://scenes/gameplay/player_test_world_3d.tscn",
	]:
		if not text.contains(term):
			_errors.append("Content authoring guide should mention required term: %s" % term)


func _validate_required_validation_commands() -> void:
	var text := _guide_text()
	for script_name in [
		"validate_item_catalog.gd",
		"validate_loot_tables.gd",
		"validate_enemy_def.gd",
		"validate_quest_model.gd",
		"validate_base_progression.gd",
		"validate_three_raid_loop.gd",
		"validate_ui_text_quality.gd",
	]:
		if not text.contains(script_name):
			_errors.append("Content authoring guide should list validation script: %s" % script_name)


func _validate_current_resource_paths() -> void:
	for path in [
		"res://scripts/items/item_def.gd",
		"res://scripts/loot/loot_table.gd",
		"res://scripts/loot/loot_table_entry.gd",
		"res://scripts/ai/enemy_def.gd",
		"res://scripts/quests/quest_def.gd",
		"res://scripts/base/upgrade_def.gd",
		"res://data/loot_tables/refuge_outskirts_common.tres",
		"res://data/enemies/scavenger.tres",
		"res://data/quests/first_salvage.tres",
		"res://data/base_upgrades/workbench_level_1.tres",
	]:
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			_errors.append("Content authoring guide references an expected project path that is missing: %s" % path)


func _guide_text() -> String:
	return FileAccess.get_file_as_string(GUIDE_PATH)
