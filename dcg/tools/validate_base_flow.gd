extends SceneTree

const MainMenuScene := preload("res://scenes/ui/main_menu.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const DifficultyManagerScript := preload("res://scripts/difficulty/difficulty_manager.gd")
const BASE_SCENE := "res://scenes/base/base_3d.tscn"

var _errors: Array[String] = []
var _created_nodes: Array[Node] = []


func _initialize() -> void:
	await _validate_new_game_enters_base()
	await _validate_continue_enters_base()
	if _errors.is_empty():
		print("[base_flow] OK new_game=base continue=base current_slot=tracked")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_new_game_enters_base() -> void:
	var save_manager := _make_save_manager()
	var difficulty_manager := _make_difficulty_manager()
	var menu := MainMenuScene.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame

	menu._on_start_pressed()
	if menu.difficulty_panel == null or not menu.difficulty_panel.visible:
		_errors.append("Main menu Start should open the difficulty panel before creating a save.")
	else:
		menu.difficulty_panel.pending_difficulty_id = &"hard"
		menu.difficulty_panel._confirm_difficulty()
		await process_frame
		await process_frame

		var slot_index: int = save_manager.get_current_slot_index()
		var save_data: Dictionary = save_manager.get_slot_data(slot_index)
		if save_data.is_empty():
			_errors.append("Confirming difficulty should create a save slot.")
		if str(save_data.get("difficulty_id", "")) != "hard":
			_errors.append("Confirming hard difficulty should save the hard difficulty id.")
		if _current_scene_path() != BASE_SCENE:
			_errors.append("New game flow should enter the 3D base scene.")

	_cleanup_validation_root(save_manager.save_root_path)
	_free_if_created(difficulty_manager)
	_free_if_created(save_manager)
	_free_current_scene()


func _validate_continue_enters_base() -> void:
	var save_manager := _make_save_manager()
	var difficulty_manager := _make_difficulty_manager()
	if not save_manager.save_new_game(2, "easy"):
		_errors.append("Validation setup should create slot 2.")
	if not save_manager.continue_from_slot(2):
		_errors.append("Continue from slot 2 should succeed.")
	await process_frame
	await process_frame

	if save_manager.get_current_slot_index() != 2:
		_errors.append("Continue from slot 2 should track current slot 2.")
	if _current_scene_path() != BASE_SCENE:
		_errors.append("Continue flow should enter the 3D base scene.")

	_cleanup_validation_root(save_manager.save_root_path)
	_free_if_created(difficulty_manager)
	_free_if_created(save_manager)
	_free_current_scene()


func _make_save_manager() -> Node:
	var existing := root.get_node_or_null("SaveGameManager")
	if existing != null:
		existing.save_root_path = "user://validation_base_flow"
		_cleanup_validation_root(existing.save_root_path)
		return existing
	var save_manager := SaveGameManagerScript.new()
	save_manager.name = "SaveGameManager"
	save_manager.save_root_path = "user://validation_base_flow"
	root.add_child(save_manager)
	_created_nodes.append(save_manager)
	_cleanup_validation_root(save_manager.save_root_path)
	return save_manager


func _make_difficulty_manager() -> Node:
	var existing := root.get_node_or_null("DifficultyManager")
	if existing != null:
		return existing
	var difficulty_manager := Node.new()
	difficulty_manager.name = "DifficultyManager"
	difficulty_manager.set_script(DifficultyManagerScript)
	root.add_child(difficulty_manager)
	difficulty_manager._ready()
	_created_nodes.append(difficulty_manager)
	return difficulty_manager


func _current_scene_path() -> String:
	if current_scene == null:
		return ""
	return current_scene.scene_file_path


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


func _free_if_created(node: Node) -> void:
	if node in _created_nodes:
		_created_nodes.erase(node)
		_free_node(node)
