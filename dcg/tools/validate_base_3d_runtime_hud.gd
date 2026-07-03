extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")

const BASE_3D_SCENE := "res://scenes/base/base_3d.tscn"
const GAMEPLAY_SCENE := "res://scenes/gameplay/player_test_world_3d.tscn"

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_base_hud_shortcuts()
	await _validate_raid_gate_scene_change()
	if _errors.is_empty():
		print("[base_3d_runtime_hud] OK tab=backpack esc=pause crosshair=visible raid_gate=gameplay")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_base_hud_shortcuts() -> void:
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait_frames(3)

	if scene.scene_file_path != BASE_3D_SCENE:
		_errors.append("Validation should start from the 3D Base scene.")
	var ui_manager := root.get_node_or_null("UIManager")
	var top_menu := scene.get_node_or_null("HUD/TopMenuBar")
	var inventory_ui := scene.get_node_or_null("HUD/InventoryEquipmentUI")
	var codex_ui := scene.get_node_or_null("HUD/ItemCodexUI")
	var pause_menu := scene.get_node_or_null("HUD/PauseMenu")
	var player_hud := scene.get_node_or_null("HUD/PlayerHud3D")
	if ui_manager == null:
		_errors.append("UIManager autoload should be available in 3D Base.")
	if top_menu == null or inventory_ui == null or codex_ui == null or pause_menu == null or player_hud == null:
		_errors.append("3D Base HUD should include TopMenuBar, InventoryEquipmentUI, ItemCodexUI, PauseMenu, and PlayerHud3D.")
		_free_current_scene()
		return

	_press_key_on_ui_manager(ui_manager, KEY_TAB)
	await _wait_frames(3)
	if str(ui_manager.call("get_active_ui")) != "backpack":
		_errors.append("TAB should open the backpack through UIManager in 3D Base.")
	if not bool(top_menu.get("visible")):
		_errors.append("TAB should make TopMenuBar visible in 3D Base.")
	if not bool(inventory_ui.get("visible")):
		_errors.append("TAB should make InventoryEquipmentUI visible in 3D Base.")

	_press_key_on_ui_manager(ui_manager, KEY_ESCAPE)
	await _wait_frames(3)
	if str(ui_manager.call("get_active_ui")) != "":
		_errors.append("ESC should close the active backpack UI before opening pause.")
	_press_key_on_ui_manager(ui_manager, KEY_ESCAPE)
	await _wait_frames(3)
	if str(ui_manager.call("get_active_ui")) != "pause":
		_errors.append("ESC should open PauseMenu through UIManager in 3D Base.")
	if not bool(pause_menu.get("visible")):
		_errors.append("PauseMenu should be visible after pressing ESC in 3D Base.")
	if not paused:
		_errors.append("SceneTree should be paused while PauseMenu is open.")
	paused = false

	if not bool(player_hud.get("visible")):
		_errors.append("PlayerHud3D should be visible so the mouse crosshair is drawn in 3D Base.")
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		_errors.append("Pause should leave OS mouse visible while menu is open.")

	_free_current_scene()


func _validate_raid_gate_scene_change() -> void:
	paused = false
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait_frames(3)

	var controller := scene.get_node_or_null("BaseInteractionController3D")
	if controller == null:
		_errors.append("3D Base should include BaseInteractionController3D for raid gate testing.")
		_free_current_scene()
		return
	if not bool(controller.call("open_interaction_by_id", "raid_gate")):
		_errors.append("Raid gate interaction should accept the start-raid request.")
		_free_current_scene()
		return
	await _wait_frames(12)

	if current_scene == null:
		_errors.append("Raid gate should leave a loaded current scene.")
	elif current_scene.scene_file_path != GAMEPLAY_SCENE:
		_errors.append("Raid gate should load the gameplay scene, got `%s`." % current_scene.scene_file_path)
	else:
		var player := current_scene.get_node_or_null("Player3D")
		var hud := current_scene.get_node_or_null("HUD/PlayerHud3D")
		if player == null or hud == null:
			_errors.append("Gameplay scene after raid gate should include Player3D and PlayerHud3D.")

	_free_current_scene()


func _press_key_on_ui_manager(ui_manager: Node, keycode: Key) -> void:
	if ui_manager == null:
		return
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	ui_manager.call("_input", event)


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


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
