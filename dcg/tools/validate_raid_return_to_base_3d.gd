extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")

const BASE_3D_SCENE := "res://scenes/base/base_3d.tscn"
const WOOD_PATH := "res://data/items/crafting/wood.tres"
const AMMO_PATH := "res://data/items/ammo/ammo_9mm.tres"
const PISTOL_PATH := "res://data/items/weapons/pistol_9mm.tres"

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
		print("[raid_return_to_base_3d] OK result=applied destination=base_3d extracted_stash=saved backpack=cleared")
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
	var extracted_equipment := {
		"slots": {
			"sidearm": {
				"item_path": PISTOL_PATH,
				"quantity": 1,
				"current_durability": 37,
				"max_durability": 81,
			},
		},
	}
	if not session.register_extraction({
		"extracted_items": extracted,
		"extracted_equipment": extracted_equipment,
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
	if _pending_quantity(WOOD_PATH) != 0:
		_errors.append("Extracted wood should not remain in the pending backpack loadout.")
	if _pending_quantity(AMMO_PATH) != 0:
		_errors.append("Extracted No.7 ammo should not remain in the pending backpack loadout.")
	if int(after_extract.get("money", 0)) != 12:
		_errors.append("Extracted money delta should be saved before scene return.")
	if not _equipment_slot_has(after_extract, &"sidearm", PISTOL_PATH, 37, 81):
		_errors.append("Extracted equipped Pistol-S should be saved to base equipment before scene return.")

	panel.continue_button.pressed.emit()
	await _wait_for_current_scene(BASE_3D_SCENE, 60)
	await _wait_for_returned_stash_page(WOOD_PATH, 2, AMMO_PATH, 30, 60)

	if current_scene == null:
		_errors.append("Continue from result should leave a loaded current scene.")
	elif current_scene.scene_file_path != BASE_3D_SCENE:
		_errors.append("Continue from result should load 3D Base, got `%s`." % current_scene.scene_file_path)
	elif current_scene.name != "Base3D":
		_errors.append("3D Base return should land on the Base3D scene root.")

	var returned_save: Dictionary = _save_manager.get_slot_data(1)
	if _stash_quantity(returned_save, WOOD_PATH) != 2 or _stash_quantity(returned_save, AMMO_PATH) != 30:
		_errors.append("Base return should keep extracted backpack items in the saved stash.")
	if int(returned_save.get("money", 0)) != 12:
		_errors.append("Base return should preserve extracted money state.")
	if not _equipment_slot_has(returned_save, &"sidearm", PISTOL_PATH, 37, 81):
		_errors.append("Base return should preserve extracted equipped Pistol-S state.")
	_validate_returned_player_equipment(&"sidearm", PISTOL_PATH, 37, 81)
	_validate_returned_stash_page(WOOD_PATH, 2, AMMO_PATH, 30)

	_free_current_scene()
	_close_ui_manager()


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
	await _wait_for_current_scene(BASE_3D_SCENE, 60)
	for _index in range(8):
		await process_frame

	if current_scene == null:
		_errors.append("Continue from death result should leave a loaded current scene.")
	elif current_scene.scene_file_path != BASE_3D_SCENE:
		_errors.append("Continue from death result should load 3D Base, got `%s`." % current_scene.scene_file_path)
	else:
		var stash_panel := current_scene.get_node_or_null("HUD/BaseStashInventoryUI")
		if stash_panel != null and stash_panel.has_method("is_open") and bool(stash_panel.call("is_open")):
			_errors.append("Death return should not auto-open the extraction stash page.")

	_free_current_scene()
	_close_ui_manager()


func _validate_returned_stash_page(first_item_path: String, first_quantity: int, second_item_path: String, second_quantity: int) -> void:
	if current_scene == null:
		return
	var ui_manager := root.get_node_or_null("UIManager")
	if ui_manager == null or str(ui_manager.call("get_active_ui")) != "stash":
		_errors.append("Successful extraction should return to Base with UIManager on the stash page.")
	var stash_panel := current_scene.get_node_or_null("HUD/BaseStashInventoryUI")
	if stash_panel == null:
		_errors.append("Base return should include BaseStashInventoryUI.")
		return
	if not stash_panel.has_method("is_open") or not bool(stash_panel.call("is_open")):
		_errors.append("Successful extraction should auto-open the Base stash page.")
	var state: Dictionary = stash_panel.call("get_display_state") if stash_panel.has_method("get_display_state") else {}
	var stash_items: Array = state.get("stash_items", []) as Array
	var backpack_items: Array = state.get("backpack_items", []) as Array
	if _stack_quantity(stash_items, first_item_path) != first_quantity:
		_errors.append("Auto-opened stash page should show extracted first item in warehouse storage.")
	if _stack_quantity(stash_items, second_item_path) != second_quantity:
		_errors.append("Auto-opened stash page should show extracted second item in warehouse storage.")
	if _stack_quantity(backpack_items, first_item_path) != 0 or _stack_quantity(backpack_items, second_item_path) != 0:
		_errors.append("Auto-opened stash page should not leave extracted items in the returned backpack.")


func _wait_for_current_scene(scene_path: String, max_frames: int) -> void:
	for _index in range(max_frames):
		if current_scene != null and current_scene.scene_file_path == scene_path:
			return
		await process_frame


func _wait_for_returned_stash_page(first_item_path: String, first_quantity: int, second_item_path: String, second_quantity: int, max_frames: int) -> void:
	for _index in range(max_frames):
		if _returned_stash_page_matches(first_item_path, first_quantity, second_item_path, second_quantity):
			return
		await process_frame


func _returned_stash_page_matches(first_item_path: String, first_quantity: int, second_item_path: String, second_quantity: int) -> bool:
	if current_scene == null:
		return false
	var ui_manager := root.get_node_or_null("UIManager")
	if ui_manager == null or str(ui_manager.call("get_active_ui")) != "stash":
		return false
	var stash_panel := current_scene.get_node_or_null("HUD/BaseStashInventoryUI")
	if stash_panel == null or not stash_panel.has_method("is_open") or not bool(stash_panel.call("is_open")):
		return false
	var state: Dictionary = stash_panel.call("get_display_state") if stash_panel.has_method("get_display_state") else {}
	var stash_items: Array = state.get("stash_items", []) as Array
	var backpack_items: Array = state.get("backpack_items", []) as Array
	return (
		_stack_quantity(stash_items, first_item_path) == first_quantity
		and _stack_quantity(stash_items, second_item_path) == second_quantity
		and _stack_quantity(backpack_items, first_item_path) == 0
		and _stack_quantity(backpack_items, second_item_path) == 0
	)


func _close_ui_manager() -> void:
	var ui_manager := root.get_node_or_null("UIManager")
	if ui_manager != null and ui_manager.has_method("close_active_ui"):
		ui_manager.call("close_active_ui")


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


func _pending_quantity(item_path: String) -> int:
	if _save_manager == null or not _save_manager.has_method("peek_pending_raid_loadout"):
		return 0
	var loadout: Dictionary = _save_manager.call("peek_pending_raid_loadout")
	return _stack_quantity(loadout.get("backpack", []) as Array, item_path)


func _equipment_slot_has(save_data: Dictionary, slot_id: StringName, item_path: String, current: int, maximum: int) -> bool:
	var equipment: Dictionary = save_data.get("equipment", {}) as Dictionary
	var slots: Dictionary = equipment.get("slots", {}) as Dictionary
	var value: Variant = slots.get(str(slot_id), {})
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var stack := value as Dictionary
	return str(stack.get("item_path", stack.get("resource_path", ""))) == item_path and int(stack.get("current_durability", -1)) == current and int(stack.get("max_durability", -1)) == maximum


func _validate_returned_player_equipment(slot_id: StringName, item_path: String, current: int, maximum: int) -> void:
	if current_scene == null:
		return
	var player := current_scene.get_node_or_null("Player3D")
	if player == null or not player.has_method("get_equipment_model"):
		_errors.append("Returned 3D Base should expose Player3D equipment.")
		return
	var equipment: RefCounted = player.call("get_equipment_model")
	var stack: Dictionary = equipment.call("get_slot", slot_id) if equipment != null else {}
	if str(stack.get("item_path", stack.get("resource_path", ""))) != item_path:
		_errors.append("Returned base Player3D should keep extracted equipment worn in the same slot.")
	if int(stack.get("current_durability", -1)) != current or int(stack.get("max_durability", -1)) != maximum:
		_errors.append("Returned base Player3D should preserve equipped durability %s/%s." % [str(current), str(maximum)])


func _stack_quantity(stacks: Array, item_path: String) -> int:
	var total := 0
	for value in stacks:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := value as Dictionary
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
