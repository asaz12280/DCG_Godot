extends SceneTree

const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")
const FirstSalvageQuest := preload("res://data/quests/first_salvage.tres")
const FirstScavengerHuntQuest := preload("res://data/quests/first_scavenger_hunt.tres")

const WOOD_PATH := "res://data/items/crafting/wood.tres"

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_quest_def_loads()
	_validate_extract_any_progress()
	_validate_kill_progress()
	_validate_claim_reward()
	_validate_save_round_trip()
	if _errors.is_empty():
		print("[quest_model] OK def=loads progress=extract_any kill=ready reward=claim save=round_trip")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_quest_def_loads() -> void:
	if FirstSalvageQuest == null or not FirstSalvageQuest.has_method("is_valid") or not FirstSalvageQuest.is_valid():
		_errors.append("First Salvage QuestDef should load and validate.")
		return
	if str(FirstSalvageQuest.get("objective_type")) != "extract_any":
		_errors.append("First Salvage should support extract_any objective.")
	if int(FirstSalvageQuest.call("get_required_quantity", WOOD_PATH)) != 3:
		_errors.append("First Salvage should require three wood for its active objective.")
	if FirstScavengerHuntQuest == null or not FirstScavengerHuntQuest.has_method("is_valid") or not FirstScavengerHuntQuest.is_valid():
		_errors.append("First Scavenger Hunt QuestDef should load and validate.")
		return
	if str(FirstScavengerHuntQuest.get("objective_type")) != "kill":
		_errors.append("First Scavenger Hunt should use kill objective.")
	if int(FirstScavengerHuntQuest.call("get_required_kill_quantity", "scavenger")) != 1:
		_errors.append("First Scavenger Hunt should require one scavenger kill.")


func _validate_extract_any_progress() -> void:
	var state: Dictionary = QuestStateScript.create(FirstSalvageQuest)
	state = QuestStateScript.update_from_extracted_items(state, FirstSalvageQuest, [
		{"item_path": WOOD_PATH, "quantity": 3},
	])
	if str(state.get("state", "")) != QuestStateScript.STATE_READY:
		_errors.append("Extracting three wood should ready First Salvage.")
	var progress: Dictionary = state.get("progress", {}) as Dictionary
	if int(progress.get(WOOD_PATH, 0)) != 3:
		_errors.append("Quest progress should record extracted wood quantity.")

	var partial_state: Dictionary = QuestStateScript.create(FirstSalvageQuest)
	partial_state = QuestStateScript.update_from_extracted_items(partial_state, FirstSalvageQuest, [
		{"item_path": WOOD_PATH, "quantity": 1},
	])
	if str(partial_state.get("state", "")) == QuestStateScript.STATE_READY:
		_errors.append("Extracting only one wood should not ready a three wood objective.")


func _validate_kill_progress() -> void:
	var state: Dictionary = QuestStateScript.create(FirstScavengerHuntQuest)
	state = QuestStateScript.update_from_enemy_killed(state, FirstScavengerHuntQuest, "scavenger", 1)
	if str(state.get("state", "")) != QuestStateScript.STATE_READY:
		_errors.append("Killing one scavenger should ready First Scavenger Hunt.")
	var progress: Dictionary = state.get("progress", {}) as Dictionary
	if int(progress.get(QuestStateScript.kill_progress_key("scavenger"), 0)) != 1:
		_errors.append("Kill quest progress should use a stable kill:scavenger save key.")


func _validate_claim_reward() -> void:
	var save_data := {
		"money": 5,
		"stash": [],
		"quests": {},
	}
	var state: Dictionary = QuestStateScript.create(FirstSalvageQuest)
	state = QuestStateScript.update_from_extracted_items(state, FirstSalvageQuest, [
		{"item_path": WOOD_PATH, "quantity": 3},
	])
	var result: Dictionary = QuestStateScript.claim_reward(save_data, state, FirstSalvageQuest)
	if not bool(result.get("success", false)):
		_errors.append("Ready quest should claim reward successfully.")
	var rewarded_save: Dictionary = result.get("save_data", {}) as Dictionary
	if int(rewarded_save.get("money", 0)) != 40:
		_errors.append("Claiming First Salvage should add reward money.")
	var rewarded_state: Dictionary = result.get("quest_state", {}) as Dictionary
	if str(rewarded_state.get("state", "")) != QuestStateScript.STATE_COMPLETED or not bool(rewarded_state.get("claimed", false)):
		_errors.append("Claiming First Salvage should mark quest completed and claimed.")


func _validate_save_round_trip() -> void:
	var manager := SaveGameManagerScript.new()
	manager.save_root_path = "user://validation_quest_model"
	root.add_child(manager)
	_cleanup_validation_root(manager.save_root_path)

	var state: Dictionary = QuestStateScript.create(FirstSalvageQuest)
	state = QuestStateScript.update_from_extracted_items(state, FirstSalvageQuest, [
		{"item_path": WOOD_PATH, "quantity": 3},
	])
	var save_data := {
		"difficulty_id": "normal",
		"money": 0,
		"stash": [],
		"base_upgrades": {},
		"quests": {
			str(FirstSalvageQuest.get("id")): QuestStateScript.to_save_data(state, FirstSalvageQuest),
		},
	}
	if not manager.save_slot_data(1, save_data):
		_errors.append("SaveGameManager should save quest state.")
	var loaded: Dictionary = manager.get_slot_data(1)
	var quests: Dictionary = loaded.get("quests", {}) as Dictionary
	if not quests.has("first_salvage"):
		_errors.append("SaveGameManager should restore first_salvage quest state.")
	else:
		var loaded_state: Dictionary = quests.get("first_salvage", {}) as Dictionary
		if str(loaded_state.get("state", "")) != QuestStateScript.STATE_READY:
			_errors.append("SaveGameManager should preserve ready quest state.")
		var progress: Dictionary = loaded_state.get("progress", {}) as Dictionary
		if int(progress.get(WOOD_PATH, 0)) != 3:
			_errors.append("SaveGameManager should preserve quest progress dictionary.")

	_cleanup_validation_root(manager.save_root_path)
	_free_node(manager)


func _cleanup_validation_root(root_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(root_path)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute("%s/slot_1.json" % absolute)
		DirAccess.remove_absolute("%s/slot_2.json" % absolute)
		DirAccess.remove_absolute("%s/slot_3.json" % absolute)
		DirAccess.remove_absolute(absolute)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
