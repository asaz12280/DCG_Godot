extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")

const BASE_3D_SCENE := "res://scenes/base/base_3d.tscn"
const WOOD_PATH := "res://data/items/crafting/wood.tres"
const AMMO_PATH := "res://data/items/ammo/ammo_9mm.tres"

var _errors: Array[String] = []
var _save_manager: Node = null
var _created_save_manager := false


func _initialize() -> void:
	_setup_save_manager()
	await _validate_extraction_result_returns_to_3d_base()
	await _validate_death_result_returns_to_3d_base()
	_cleanup_validation_root(_save_manager.save_root_path)
	if _created_save_manager:
		_free_node(_save_manager)
	if _errors.is_empty():
		print("[raid_return_to_base_3d] OK result=applied destination=base_3d stash=visible")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_extraction_result_returns_to_3d_base() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/raid_result_panel.gd")
	if source.contains("const BASE_SCENE := \"res://scenes/base/base_screen.tscn\""):
		_errors.append("RaidResultPanel should not return to the old 2D BaseScreen scene.")
	if not source.contains("const BASE_SCENE := \"%s\"" % BASE_3D_SCENE):
		_errors.append("RaidResultPanel should route Continue to the 3D Base scene.")
	if not ResourceLoader.exists(BASE_3D_SCENE):
		_errors.append("3D Base destination scene should exist.")

	var gameplay := GameplayScene.instantiate()
	root.add_child(gameplay)
	current_scene = gameplay
	await process_frame
	await process_frame

	var session := gameplay.get_node_or_null("RaidSession")
	var panel := gameplay.get_node_or_null("HUD/RaidResultPanel")
	var applier := gameplay.get_node_or_null("RaidResultApplier")
	if session == null:
		_errors.append("Gameplay scene should include RaidSession.")
	if panel == null:
		_errors.append("Gameplay scene should include HUD/RaidResultPanel.")
	if applier == null:
		_errors.append("Gameplay scene should include RaidResultApplier.")
	if session == null or panel == null or applier == null:
		_free_current_scene()
		return

	if str(panel.BASE_SCENE) != BASE_3D_SCENE:
		_errors.append("RaidResultPanel BASE_SCENE should be the 3D Base scene.")

	var extracted := [
		{"item_path": WOOD_PATH, "quantity": 2},
		{"item_path": AMMO_PATH, "quantity": 30},
	]
	if not session.register_extraction({
		"extracted_items": extracted,
		"money_delta": 12,
	}):
		_errors.append("Validation raid should be able to extract.")
	await process_frame
	await process_frame

	if not bool(panel.visible):
		_errors.append("RaidResultPanel should be visible after extraction.")
	var apply_result: Dictionary = applier.last_apply_result
	if not bool(apply_result.get("applied", false)):
		_errors.append("RaidResultApplier should persist extracted result before returning to base.")
	var after_extract: Dictionary = _save_manager.get_slot_data(1)
	if _stash_quantity(after_extract, WOOD_PATH) != 2:
		_errors.append("Extracted wood should be saved to the base stash before scene return.")
	if _stash_quantity(after_extract, AMMO_PATH) != 30:
		_errors.append("Extracted No.7 ammo should be saved to the base stash before scene return.")
	if int(after_extract.get("money", 0)) != 12:
		_errors.append("Extracted money delta should be saved before scene return.")

	panel.continue_button.pressed.emit()
	for _index in range(6):
		await process_frame

	if current_scene == null:
		_errors.append("Continue from result should leave a loaded current scene.")
	elif current_scene.scene_file_path != BASE_3D_SCENE:
		_errors.append("Continue from result should load 3D Base, got `%s`." % current_scene.scene_file_path)
	elif current_scene.name != "Base3D":
		_errors.append("3D Base return should land on the Base3D scene root.")

	var returned_save: Dictionary = _save_manager.get_slot_data(1)
	if _stash_quantity(returned_save, WOOD_PATH) != 2 or _stash_quantity(returned_save, AMMO_PATH) != 30:
		_errors.append("Base return should preserve extracted stash state.")
	if int(returned_save.get("money", 0)) != 12:
		_errors.append("Base return should preserve extracted money state.")

	_free_current_scene()


func _validate_death_result_returns_to_3d_base() -> void:
	_setup_save_manager()
	var gameplay := GameplayScene.instantiate()
	root.add_child(gameplay)
	current_scene = gameplay
	await process_frame
	await process_frame

	var session := gameplay.get_node_or_null("RaidSession")
	var panel := gameplay.get_node_or_null("HUD/RaidResultPanel")
	var applier := gameplay.get_node_or_null("RaidResultApplier")
	if session == null or panel == null or applier == null:
		_errors.append("Gameplay scene should include session, result panel, and applier for death return.")
		_free_current_scene()
		return

	if not session.register_player_death({
		"lost_items": [{"item_path": WOOD_PATH, "quantity": 2}],
		"kept_safe_pocket_items": [{"item_path": AMMO_PATH, "quantity": 6}],
		"loss_rule": "backpack_lost_safe_pocket_kept",
	}):
		_errors.append("Validation raid should be able to register death.")
	await process_frame
	await process_frame

	if not bool(panel.visible):
		_errors.append("RaidResultPanel should be visible after death.")
	var state: Dictionary = panel.get_display_state()
	if not str(state.get("outcome", "")).contains("死亡"):
		_errors.append("Death return validation should show death result text.")
	if not bool(applier.last_apply_result.get("death_loss", false)):
		_errors.append("RaidResultApplier should apply death loss before returning to base.")
	var after_death: Dictionary = _save_manager.get_slot_data(1)
	if _stash_quantity(after_death, WOOD_PATH) != 0:
		_errors.append("Death return should not save lost wood to base stash.")

	panel.continue_button.pressed.emit()
	for _index in range(6):
		await process_frame

	if current_scene == null:
		_errors.append("Continue from death result should leave a loaded current scene.")
	elif current_scene.scene_file_path != BASE_3D_SCENE:
		_errors.append("Continue from death result should load 3D Base, got `%s`." % current_scene.scene_file_path)

	_free_current_scene()


func _setup_save_manager() -> void:
	_save_manager = root.get_node_or_null("SaveGameManager")
	if _save_manager == null:
		_save_manager = SaveGameManagerScript.new()
		_save_manager.name = "SaveGameManager"
		root.add_child(_save_manager)
		_created_save_manager = true
	_save_manager.save_root_path = "user://validation_raid_return_to_base_3d"
	_cleanup_validation_root(_save_manager.save_root_path)
	_save_manager.set_current_slot_index(1)
	_save_manager.save_slot_data(1, {
		"difficulty_id": "normal",
		"scene_path": BASE_3D_SCENE,
		"money": 0,
		"stash": [],
		"base_upgrades": {},
		"quests": {},
	})


func _stash_quantity(save_data: Dictionary, item_path: String) -> int:
	var total := 0
	var stash: Array = save_data.get("stash", []) as Array
	for entry in stash:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stack := entry as Dictionary
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path:
			total += int(stack.get("quantity", 0))
	return total


func _cleanup_validation_root(root_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(root_path)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute("%s/slot_1.json" % absolute)
		DirAccess.remove_absolute("%s/slot_2.json" % absolute)
		DirAccess.remove_absolute("%s/slot_3.json" % absolute)
		DirAccess.remove_absolute(absolute)


func _free_current_scene() -> void:
	if current_scene != null:
		_free_node(current_scene)
		current_scene = null


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
