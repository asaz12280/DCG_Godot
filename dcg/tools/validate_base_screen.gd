extends SceneTree

const BaseScreenScene := preload("res://scenes/base/base_screen.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_empty_stash()
	await _validate_filled_stash()
	await _validate_layout_fit()
	await _validate_start_raid_button()
	if _errors.is_empty():
		print("[base_screen] OK node_first=true empty=shown stash=shown layout=fits")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_empty_stash() -> void:
	var save_manager := _make_save_manager()
	var screen: BaseScreen = _make_screen()
	await process_frame
	screen.refresh()
	var state: Dictionary = screen.get_display_state()
	if int(state.get("stash_rows", 0)) != 1:
		_errors.append("BaseScreen should show one empty-state stash row when there is no save data.")
	if not (
		str(state.get("status", "")).contains("尚無存檔")
		or str(state.get("status", "")).contains("No save data")
	):
		_errors.append("BaseScreen should show a clear no-save status message.")
	_free_node(screen)
	_free_node(save_manager)


func _validate_filled_stash() -> void:
	var save_manager := _make_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)
	var data := {
		"difficulty_id": "hard",
		"money": 42,
		"stash": [
			{"item_path": "res://data/items/crafting/wood.tres", "quantity": 3},
			{"item_path": "res://data/items/currency/cash.tres", "quantity": 8},
		],
		"base_upgrades": {},
		"quests": {},
	}
	if not save_manager.save_slot_data(2, data):
		_errors.append("Validation setup should save filled base data.")
	save_manager.set_current_slot_index(2)
	var screen: BaseScreen = _make_screen()
	await process_frame
	screen.refresh()
	var state: Dictionary = screen.get_display_state()
	if not str(state.get("slot", "")).contains("2"):
		_errors.append("BaseScreen should show the SaveGameManager current slot.")
	if int(state.get("stash_rows", 0)) != 2:
		_errors.append("BaseScreen should show one row per stash entry.")
	var difficulty_text := str(state.get("difficulty", ""))
	if not (
		difficulty_text.contains("Hard")
		or difficulty_text.contains("困難")
		or difficulty_text.contains("困难")
	):
		_errors.append("BaseScreen should show the saved difficulty.")
	if not str(state.get("money", "")).contains("42"):
		_errors.append("BaseScreen should show saved money.")
	_free_node(screen)
	_cleanup_validation_root(save_manager.save_root_path)
	_free_node(save_manager)


func _validate_layout_fit() -> void:
	var save_manager := _make_save_manager()
	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		root.content_scale_size = Vector2i(int(viewport_size.x), int(viewport_size.y))
		root.size = Vector2i(int(viewport_size.x), int(viewport_size.y))
		var screen: BaseScreen = _make_screen()
		screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
		screen.size = viewport_size
		await process_frame
		screen.size = viewport_size
		await process_frame
		var state: Dictionary = screen.get_display_state()
		var panel_rect := state.get("panel_rect") as Rect2
		var button_rect := state.get("start_button_rect") as Rect2
		if panel_rect.position.x < 48.0 and viewport_size.x >= 1280.0:
			_errors.append("BaseScreen panel should keep a large-screen safe margin.")
		if panel_rect.end.x > viewport_size.x or panel_rect.end.y > viewport_size.y:
			_errors.append("BaseScreen panel should fit inside %s." % viewport_size)
		if button_rect.size.x < 220.0 or button_rect.size.y < 44.0:
			_errors.append("BaseScreen start button should meet early button size rules.")
		if button_rect.end.x > viewport_size.x or button_rect.end.y > viewport_size.y:
			_errors.append("BaseScreen start button should stay inside the viewport at %s." % viewport_size)
		if not panel_rect.encloses(button_rect):
			_errors.append("BaseScreen start button should stay inside the main panel at %s." % viewport_size)
		_free_node(screen)
	_free_node(save_manager)


func _validate_start_raid_button() -> void:
	var save_manager := _make_save_manager()
	var screen: BaseScreen = _make_screen()
	await process_frame
	if screen.start_raid_button == null:
		_errors.append("BaseScreen should expose a Start Raid button from the scene tree.")
	elif screen.start_raid_button.text == "":
		_errors.append("BaseScreen Start Raid button should have readable text.")
	_free_node(screen)
	_free_node(save_manager)


func _make_save_manager() -> Node:
	var existing := root.get_node_or_null("SaveGameManager")
	if existing != null:
		_free_node(existing)
	var save_manager := SaveGameManagerScript.new()
	save_manager.name = "SaveGameManager"
	save_manager.save_root_path = "user://validation_base_screen"
	root.add_child(save_manager)
	_cleanup_validation_root(save_manager.save_root_path)
	return save_manager


func _make_screen() -> BaseScreen:
	var screen := BaseScreenScene.instantiate()
	root.add_child(screen)
	return screen


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
