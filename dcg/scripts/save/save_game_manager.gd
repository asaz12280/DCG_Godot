extends Node

const DEFAULT_SAVE_ROOT := "user://saves"
const SLOT_COUNT := 3
const SAVE_SCHEMA_VERSION := 1
const DEFAULT_BASE_SCENE := "res://scenes/base/base_3d.tscn"
const DEFAULT_GAMEPLAY_SCENE := "res://scenes/gameplay/player_test_world_3d.tscn"
const DEFAULT_MONEY := 0
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")

var save_root_path := DEFAULT_SAVE_ROOT
var current_slot_index := 1


func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for slot_index in range(1, SLOT_COUNT + 1):
		slots.append(get_slot_summary(slot_index))
	return slots


func get_slot_summary(slot_index: int) -> Dictionary:
	var summary := {
		"slot_index": slot_index,
		"exists": false,
		"version": SAVE_SCHEMA_VERSION,
		"scene_path": DEFAULT_BASE_SCENE,
		"difficulty_id": "normal",
		"saved_at_unix": 0,
		"saved_at_text": "",
		"money": DEFAULT_MONEY,
	}
	var raw_data := _read_slot_file(slot_index)
	if raw_data.is_empty():
		return summary
	var save_data := _normalize_save_data(raw_data)
	summary["exists"] = true
	summary["version"] = int(save_data.get("version", SAVE_SCHEMA_VERSION))
	summary["scene_path"] = str(save_data.get("scene_path", DEFAULT_BASE_SCENE))
	summary["difficulty_id"] = str(save_data.get("difficulty_id", "normal"))
	summary["saved_at_unix"] = int(save_data.get("saved_at_unix", 0))
	summary["saved_at_text"] = str(save_data.get("saved_at_text", ""))
	summary["money"] = int(save_data.get("money", DEFAULT_MONEY))
	return summary


func get_preferred_new_game_slot() -> int:
	for slot_index in range(1, SLOT_COUNT + 1):
		if not bool(get_slot_summary(slot_index).get("exists", false)):
			return slot_index
	return 1


func save_new_game(slot_index: int, difficulty_id: String, scene_path: String = DEFAULT_BASE_SCENE) -> bool:
	if not _is_valid_slot(slot_index):
		return false
	var timestamp := int(Time.get_unix_time_from_system())
	var save_data := _default_save_data(_normalize_difficulty_id(difficulty_id), scene_path, timestamp)
	return save_slot_data(slot_index, save_data)


func get_slot_data(slot_index: int) -> Dictionary:
	if not _is_valid_slot(slot_index):
		return {}
	var raw_data := _read_slot_file(slot_index)
	if raw_data.is_empty():
		return {}
	return _normalize_save_data(raw_data)


func save_slot_data(slot_index: int, save_data: Dictionary) -> bool:
	if not _is_valid_slot(slot_index):
		return false
	_ensure_save_root()
	var normalized := _normalize_save_data(save_data)
	if int(normalized.get("saved_at_unix", 0)) <= 0:
		var timestamp := int(Time.get_unix_time_from_system())
		normalized["saved_at_unix"] = timestamp
		normalized["saved_at_text"] = Time.get_datetime_string_from_unix_time(timestamp, true)
	var file := FileAccess.open(_slot_path(slot_index), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(normalized, "\t"))
	return true


func start_new_game(slot_index: int, difficulty_id: String, scene_path: String = DEFAULT_BASE_SCENE) -> bool:
	var normalized_difficulty := _normalize_difficulty_id(difficulty_id)
	if not save_new_game(slot_index, normalized_difficulty, scene_path):
		return false
	current_slot_index = slot_index
	_apply_difficulty(normalized_difficulty)
	if is_inside_tree():
		var tree := get_tree()
		tree.change_scene_to_file(scene_path)
	return true


func continue_from_slot(slot_index: int, destination_scene: String = DEFAULT_BASE_SCENE) -> bool:
	var save_data := get_slot_data(slot_index)
	if save_data.is_empty():
		return false
	var difficulty_id := _normalize_difficulty_id(str(save_data.get("difficulty_id", "normal")))
	current_slot_index = slot_index
	_apply_difficulty(difficulty_id)
	if is_inside_tree():
		var tree := get_tree()
		tree.change_scene_to_file(destination_scene)
	return true


func get_current_slot_index() -> int:
	return current_slot_index


func set_current_slot_index(slot_index: int) -> bool:
	if not _is_valid_slot(slot_index):
		return false
	current_slot_index = slot_index
	return true


func _apply_difficulty(difficulty_id: String) -> void:
	if not is_inside_tree():
		return
	var difficulty_manager := get_node_or_null("/root/DifficultyManager")
	if difficulty_manager != null and difficulty_manager.has_method("set_difficulty"):
		difficulty_manager.set_difficulty(StringName(difficulty_id))
		return
	var settings := get_node_or_null("/root/GameSettings")
	if settings != null and settings.has_method("set_difficulty_id"):
		settings.set_difficulty_id(difficulty_id)


func _read_slot_file(slot_index: int) -> Dictionary:
	if not _is_valid_slot(slot_index):
		return {}
	var path := _slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary


func _ensure_save_root() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_root_path))


func _slot_path(slot_index: int) -> String:
	return "%s/slot_%d.json" % [save_root_path, slot_index]


func _is_valid_slot(slot_index: int) -> bool:
	return slot_index >= 1 and slot_index <= SLOT_COUNT


func _normalize_difficulty_id(value: String) -> String:
	return value if value in ["easy", "normal", "hard"] else "normal"


func _default_save_data(difficulty_id: String = "normal", scene_path: String = DEFAULT_BASE_SCENE, timestamp: int = 0) -> Dictionary:
	var saved_at_unix := timestamp
	if saved_at_unix <= 0:
		saved_at_unix = int(Time.get_unix_time_from_system())
	return {
		"version": SAVE_SCHEMA_VERSION,
		"scene_path": scene_path,
		"difficulty_id": _normalize_difficulty_id(difficulty_id),
		"saved_at_unix": saved_at_unix,
		"saved_at_text": Time.get_datetime_string_from_unix_time(saved_at_unix, true),
		"money": DEFAULT_MONEY,
		"stash": [],
		"base_upgrades": {},
		"quests": {},
	}


func _normalize_save_data(raw_data: Dictionary) -> Dictionary:
	var normalized := _default_save_data(
		str(raw_data.get("difficulty_id", "normal")),
		str(raw_data.get("scene_path", DEFAULT_BASE_SCENE)),
		int(raw_data.get("saved_at_unix", 0))
	)
	normalized["version"] = SAVE_SCHEMA_VERSION
	normalized["saved_at_text"] = str(raw_data.get("saved_at_text", normalized.get("saved_at_text", "")))
	normalized["money"] = maxi(int(raw_data.get("money", DEFAULT_MONEY)), 0)

	var stash_value: Variant = raw_data.get("stash", [])
	if typeof(stash_value) == TYPE_ARRAY:
		normalized["stash"] = (stash_value as Array).duplicate(true)

	var base_upgrades_value: Variant = raw_data.get("base_upgrades", {})
	if typeof(base_upgrades_value) == TYPE_DICTIONARY:
		normalized["base_upgrades"] = (base_upgrades_value as Dictionary).duplicate(true)

	var quests_value: Variant = raw_data.get("quests", {})
	if typeof(quests_value) == TYPE_DICTIONARY:
		normalized["quests"] = _normalize_quest_states(quests_value as Dictionary)

	return normalized


func _normalize_quest_states(raw_quests: Dictionary) -> Dictionary:
	var quests: Dictionary = {}
	for quest_id in raw_quests.keys():
		var value: Variant = raw_quests.get(quest_id, {})
		if typeof(value) == TYPE_DICTIONARY:
			var normalized: Dictionary = QuestStateScript.normalize(value as Dictionary)
			if str(normalized.get("id", "")) == "":
				normalized["id"] = str(quest_id)
			quests[str(quest_id)] = normalized
	return quests
