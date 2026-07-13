extends Node

signal slot_saved(slot_index: int, save_data: Dictionary)

const DEFAULT_SAVE_ROOT := "user://saves"
const SLOT_COUNT := 3
const SAVE_SCHEMA_VERSION := 2
const DEFAULT_BASE_SCENE := "res://scenes/base/base_3d.tscn"
const DEFAULT_GAMEPLAY_SCENE := "res://scenes/gameplay/player_test_world_3d.tscn"
const DEFAULT_MONEY := 0
const DEFAULT_STASH_MONEY := 0
const ItemStackSaveCodecScript := preload("res://scripts/inventory/item_stack_save_codec.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")

const SAVE_ID_ALIASES := {
	"workbench_ammo_9mm": "workbench_ammo_S",
	"workbench_ammo_9mm_polished": "workbench_ammo_S",
	"workbench_pistol_9mm_parts": "workbench_pistol_S_parts",
	"stash:0:pistol_9mm": "stash:0:pistol_S",
	"stash:0:workbench_pistol_9mm_parts": "stash:0:workbench_pistol_S_parts",
}

var save_root_path := DEFAULT_SAVE_ROOT
var current_slot_index := 1
var _pending_raid_loadout: Dictionary = {}


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
		"stash_money": DEFAULT_STASH_MONEY,
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
	summary["stash_money"] = int(save_data.get("stash_money", DEFAULT_STASH_MONEY))
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
	file = null
	slot_saved.emit(slot_index, normalized.duplicate(true))
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


func set_pending_raid_loadout(loadout: Dictionary) -> bool:
	if loadout.is_empty():
		return false
	_pending_raid_loadout = loadout.duplicate(true)
	return true


func has_pending_raid_loadout() -> bool:
	return not _pending_raid_loadout.is_empty()


func peek_pending_raid_loadout() -> Dictionary:
	return _pending_raid_loadout.duplicate(true)


func consume_pending_raid_loadout() -> Dictionary:
	var loadout := _pending_raid_loadout.duplicate(true)
	_pending_raid_loadout.clear()
	return loadout


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
		"stash_money": DEFAULT_STASH_MONEY,
		"stash": [],
		"equipment": {"slots": {}},
		"base_upgrades": {},
		"quests": {},
		"needed_item_marks": {},
		"selected_recipe_ids": {},
		"selected_repair_ids": {},
		"selected_dismantle_ids": {},
		"researched_blueprints": {},
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
	normalized["stash_money"] = maxi(int(raw_data.get("stash_money", DEFAULT_STASH_MONEY)), 0)

	var stash_value: Variant = raw_data.get("stash", [])
	if typeof(stash_value) == TYPE_ARRAY:
		normalized["stash"] = _normalize_stack_array(stash_value as Array)

	var equipment_value: Variant = raw_data.get("equipment", {})
	if typeof(equipment_value) == TYPE_DICTIONARY:
		normalized["equipment"] = _normalize_equipment_data(equipment_value as Dictionary)

	var base_upgrades_value: Variant = raw_data.get("base_upgrades", {})
	if typeof(base_upgrades_value) == TYPE_DICTIONARY:
		normalized["base_upgrades"] = (base_upgrades_value as Dictionary).duplicate(true)

	var quests_value: Variant = raw_data.get("quests", {})
	if typeof(quests_value) == TYPE_DICTIONARY:
		normalized["quests"] = _normalize_quest_states(quests_value as Dictionary)

	var needed_marks_value: Variant = raw_data.get("needed_item_marks", {})
	if typeof(needed_marks_value) == TYPE_DICTIONARY:
		normalized["needed_item_marks"] = _normalize_needed_item_marks(needed_marks_value as Dictionary)

	var selected_recipes_value: Variant = raw_data.get("selected_recipe_ids", {})
	if typeof(selected_recipes_value) == TYPE_DICTIONARY:
		normalized["selected_recipe_ids"] = _normalize_selected_recipe_ids(selected_recipes_value as Dictionary)

	var selected_repairs_value: Variant = raw_data.get("selected_repair_ids", {})
	if typeof(selected_repairs_value) == TYPE_DICTIONARY:
		normalized["selected_repair_ids"] = _normalize_selected_repair_ids(selected_repairs_value as Dictionary)

	var selected_dismantles_value: Variant = raw_data.get("selected_dismantle_ids", {})
	if typeof(selected_dismantles_value) == TYPE_DICTIONARY:
		normalized["selected_dismantle_ids"] = _normalize_selected_dismantle_ids(selected_dismantles_value as Dictionary)

	var researched_blueprints_value: Variant = raw_data.get("researched_blueprints", {})
	if typeof(researched_blueprints_value) == TYPE_DICTIONARY:
		normalized["researched_blueprints"] = _normalize_researched_blueprints(researched_blueprints_value as Dictionary)

	return normalized


func _normalize_needed_item_marks(raw_marks: Dictionary) -> Dictionary:
	var marks: Dictionary = {}
	for item_path in raw_marks.keys():
		var path := ItemStackSaveCodecScript.normalize_item_path(str(item_path).strip_edges())
		if path != "" and bool(raw_marks.get(item_path, false)):
			marks[path] = true
	return marks


func _normalize_selected_recipe_ids(raw_selection: Dictionary) -> Dictionary:
	var selection: Dictionary = {}
	for station_id in raw_selection.keys():
		var station := str(station_id).strip_edges()
		var recipe_id := _normalize_save_id(str(raw_selection.get(station_id, "")).strip_edges())
		if station != "" and recipe_id != "":
			selection[station] = recipe_id
	return selection


func _normalize_selected_repair_ids(raw_selection: Dictionary) -> Dictionary:
	var selection: Dictionary = {}
	for station_id in raw_selection.keys():
		var station := str(station_id).strip_edges()
		var repair_id := _normalize_save_id(str(raw_selection.get(station_id, "")).strip_edges())
		if station != "" and repair_id != "":
			selection[station] = repair_id
	return selection


func _normalize_selected_dismantle_ids(raw_selection: Dictionary) -> Dictionary:
	var selection: Dictionary = {}
	for station_id in raw_selection.keys():
		var station := str(station_id).strip_edges()
		var dismantle_id := _normalize_save_id(str(raw_selection.get(station_id, "")).strip_edges())
		if station != "" and dismantle_id != "":
			selection[station] = dismantle_id
	return selection


func _normalize_researched_blueprints(raw_blueprints: Dictionary) -> Dictionary:
	var blueprints: Dictionary = {}
	for item_path in raw_blueprints.keys():
		var path := ItemStackSaveCodecScript.normalize_item_path(str(item_path).strip_edges())
		if path != "" and bool(raw_blueprints.get(item_path, false)):
			blueprints[path] = true
	return blueprints


func _normalize_equipment_data(raw_equipment: Dictionary) -> Dictionary:
	var slots_value: Variant = raw_equipment.get("slots", {})
	if typeof(slots_value) != TYPE_DICTIONARY:
		return {"slots": {}}
	var slots: Dictionary = {}
	for slot_id in (slots_value as Dictionary).keys():
		var value: Variant = (slots_value as Dictionary).get(slot_id, {})
		if typeof(value) == TYPE_DICTIONARY:
			slots[slot_id] = _normalize_stack_dictionary(value as Dictionary)
	return {"slots": slots}


func _normalize_stack_array(raw_stacks: Array) -> Array:
	var stacks: Array = []
	for value in raw_stacks:
		if typeof(value) == TYPE_DICTIONARY:
			var stack := _normalize_stack_dictionary(value as Dictionary)
			if not stack.is_empty():
				stacks.append(stack)
	return stacks


func _normalize_stack_dictionary(raw_stack: Dictionary) -> Dictionary:
	var stack := raw_stack.duplicate(true)
	for key in ["item_path", "resource_path"]:
		if stack.has(key):
			stack[key] = ItemStackSaveCodecScript.normalize_item_path(str(stack.get(key, "")))
	if typeof(stack.get("weapon_mods", null)) == TYPE_DICTIONARY:
		var normalized_mods: Dictionary = {}
		var raw_mods := stack.get("weapon_mods", {}) as Dictionary
		for slot_id in raw_mods.keys():
			var mod_value: Variant = raw_mods.get(slot_id, {})
			if typeof(mod_value) == TYPE_DICTIONARY:
				normalized_mods[slot_id] = _normalize_stack_dictionary(mod_value as Dictionary)
		stack["weapon_mods"] = normalized_mods
	return stack


func _normalize_save_id(value: String) -> String:
	return str(SAVE_ID_ALIASES.get(value, value))


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
