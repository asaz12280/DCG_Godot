extends SceneTree

const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_slot_listing()
	_validate_save_and_load_flow()
	_validate_schema_round_trip()
	_validate_legacy_slot_defaults()
	if _errors.is_empty():
		print("[save_slots] OK slots=3 save=start load=continue schema=v1")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_slot_listing() -> void:
	var manager := SaveGameManagerScript.new()
	manager.save_root_path = "user://validation_saves"
	root.add_child(manager)
	var slots := manager.list_slots()
	if slots.size() != 3:
		_errors.append("SaveGameManager should expose exactly three slots.")
	manager.queue_free()


func _validate_save_and_load_flow() -> void:
	var manager := SaveGameManagerScript.new()
	manager.save_root_path = "user://validation_saves"
	root.add_child(manager)
	_cleanup_validation_root(manager.save_root_path)
	if not manager.save_new_game(2, "hard"):
		_errors.append("Saving a new game to slot 2 should succeed.")
	var summary := manager.get_slot_summary(2)
	if not bool(summary.get("exists", false)):
		_errors.append("Saved slot 2 should exist.")
	if str(summary.get("difficulty_id", "")) != "hard":
		_errors.append("Saved slot 2 should preserve the difficulty id.")
	if str(summary.get("scene_path", "")) != SaveGameManagerScript.DEFAULT_BASE_SCENE:
		_errors.append("New save slots should continue to the base scene by default.")
	if not manager.continue_from_slot(2):
		_errors.append("Continuing from slot 2 should succeed.")
	if manager.get_current_slot_index() != 2:
		_errors.append("Continuing from slot 2 should set the current slot index.")
	_cleanup_validation_root(manager.save_root_path)
	manager.queue_free()


func _validate_schema_round_trip() -> void:
	var manager := SaveGameManagerScript.new()
	manager.save_root_path = "user://validation_saves"
	root.add_child(manager)
	_cleanup_validation_root(manager.save_root_path)
	if not manager.save_new_game(1, "easy"):
		_errors.append("Saving a new schema v1 game should succeed.")
	var save_data: Dictionary = manager.get_slot_data(1)
	if int(save_data.get("version", 0)) != 1:
		_errors.append("New save data should include schema version 1.")
	if int(save_data.get("money", -1)) != 0:
		_errors.append("New save data should default money to 0.")
	if typeof(save_data.get("stash", null)) != TYPE_ARRAY:
		_errors.append("New save data should include a stash array.")
	if typeof(save_data.get("base_upgrades", null)) != TYPE_DICTIONARY:
		_errors.append("New save data should include base_upgrades dictionary.")
	if typeof(save_data.get("quests", null)) != TYPE_DICTIONARY:
		_errors.append("New save data should include quests dictionary.")
	if typeof(save_data.get("needed_item_marks", null)) != TYPE_DICTIONARY:
		_errors.append("New save data should include needed_item_marks dictionary.")
	if typeof(save_data.get("selected_recipe_ids", null)) != TYPE_DICTIONARY:
		_errors.append("New save data should include selected_recipe_ids dictionary.")
	if typeof(save_data.get("selected_repair_ids", null)) != TYPE_DICTIONARY:
		_errors.append("New save data should include selected_repair_ids dictionary.")
	if typeof(save_data.get("selected_dismantle_ids", null)) != TYPE_DICTIONARY:
		_errors.append("New save data should include selected_dismantle_ids dictionary.")
	if typeof(save_data.get("researched_blueprints", null)) != TYPE_DICTIONARY:
		_errors.append("New save data should include researched_blueprints dictionary.")
	if str(save_data.get("scene_path", "")) != SaveGameManagerScript.DEFAULT_BASE_SCENE:
		_errors.append("New schema v1 save data should target the base scene.")

	save_data["money"] = 42
	save_data["stash"] = [{"item_path": "res://data/items/crafting/wood.tres", "quantity": 3}]
	save_data["base_upgrades"] = {"workbench_level": 1}
	save_data["quests"] = {"first_wood": {"state": "complete"}}
	save_data["needed_item_marks"] = {"res://data/items/crafting/wood.tres": true}
	save_data["selected_recipe_ids"] = {"workbench": "workbench_extended_magazine"}
	save_data["selected_repair_ids"] = {"workbench": "stash:0:pistol_9mm"}
	save_data["selected_dismantle_ids"] = {"workbench": "stash:0:workbench_pistol_9mm_parts"}
	save_data["researched_blueprints"] = {"res://data/items/recipes/blueprint.tres": true}
	if not manager.save_slot_data(1, save_data):
		_errors.append("Saving updated schema v1 slot data should succeed.")
	var loaded: Dictionary = manager.get_slot_data(1)
	if int(loaded.get("money", 0)) != 42:
		_errors.append("Round trip should preserve money.")
	if (loaded.get("stash", []) as Array).size() != 1:
		_errors.append("Round trip should preserve stash entries.")
	if int((loaded.get("base_upgrades", {}) as Dictionary).get("workbench_level", 0)) != 1:
		_errors.append("Round trip should preserve base upgrades.")
	if not (loaded.get("quests", {}) as Dictionary).has("first_wood"):
		_errors.append("Round trip should preserve quest data.")
	if not bool((loaded.get("needed_item_marks", {}) as Dictionary).get("res://data/items/crafting/wood.tres", false)):
		_errors.append("Round trip should preserve needed item marks.")
	if str((loaded.get("selected_recipe_ids", {}) as Dictionary).get("workbench", "")) != "workbench_extended_magazine":
		_errors.append("Round trip should preserve selected crafting recipe ids.")
	if str((loaded.get("selected_repair_ids", {}) as Dictionary).get("workbench", "")) != "stash:0:pistol_9mm":
		_errors.append("Round trip should preserve selected repair item ids.")
	if str((loaded.get("selected_dismantle_ids", {}) as Dictionary).get("workbench", "")) != "stash:0:workbench_pistol_9mm_parts":
		_errors.append("Round trip should preserve selected dismantle item ids.")
	if not bool((loaded.get("researched_blueprints", {}) as Dictionary).get("res://data/items/recipes/blueprint.tres", false)):
		_errors.append("Round trip should preserve researched blueprint ids.")
	_cleanup_validation_root(manager.save_root_path)
	manager.queue_free()


func _validate_legacy_slot_defaults() -> void:
	var manager := SaveGameManagerScript.new()
	manager.save_root_path = "user://validation_saves"
	root.add_child(manager)
	_cleanup_validation_root(manager.save_root_path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(manager.save_root_path))
	var legacy_file := FileAccess.open("%s/slot_3.json" % manager.save_root_path, FileAccess.WRITE)
	if legacy_file == null:
		_errors.append("Validation should be able to create a legacy slot file.")
		manager.queue_free()
		return
	legacy_file.store_string(JSON.stringify({
		"scene_path": "res://scenes/gameplay/player_test_world_3d.tscn",
		"difficulty_id": "hard",
		"saved_at_unix": 123,
		"saved_at_text": "legacy",
	}, "\t"))
	legacy_file = null
	var loaded := manager.get_slot_data(3)
	if int(loaded.get("version", 0)) != 1:
		_errors.append("Legacy slot should normalize to schema version 1.")
	if int(loaded.get("money", -1)) != 0:
		_errors.append("Legacy slot should default money to 0.")
	if typeof(loaded.get("stash", null)) != TYPE_ARRAY:
		_errors.append("Legacy slot should default stash to an array.")
	if typeof(loaded.get("needed_item_marks", null)) != TYPE_DICTIONARY:
		_errors.append("Legacy slot should default needed item marks to a dictionary.")
	if typeof(loaded.get("selected_recipe_ids", null)) != TYPE_DICTIONARY:
		_errors.append("Legacy slot should default selected recipe ids to a dictionary.")
	if typeof(loaded.get("selected_repair_ids", null)) != TYPE_DICTIONARY:
		_errors.append("Legacy slot should default selected repair ids to a dictionary.")
	if typeof(loaded.get("selected_dismantle_ids", null)) != TYPE_DICTIONARY:
		_errors.append("Legacy slot should default selected dismantle ids to a dictionary.")
	if typeof(loaded.get("researched_blueprints", null)) != TYPE_DICTIONARY:
		_errors.append("Legacy slot should default researched blueprints to a dictionary.")
	if str(loaded.get("difficulty_id", "")) != "hard":
		_errors.append("Legacy slot should preserve difficulty id.")
	_cleanup_validation_root(manager.save_root_path)
	manager.queue_free()


func _cleanup_validation_root(root_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(root_path)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute("%s/slot_1.json" % absolute)
		DirAccess.remove_absolute("%s/slot_2.json" % absolute)
		DirAccess.remove_absolute("%s/slot_3.json" % absolute)
		DirAccess.remove_absolute(absolute)
