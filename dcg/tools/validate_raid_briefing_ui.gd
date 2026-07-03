extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")

const BASE_3D_SCENE := "res://scenes/base/base_3d.tscn"
const GAMEPLAY_SCENE := "res://scenes/gameplay/player_test_world_3d.tscn"
const CONTROLLER_SOURCE := "res://scripts/base/base_interaction_controller_3d.gd"
const PANEL_SOURCE := "res://scripts/ui/raid_briefing_panel.gd"
const PANEL_SCENE := "res://scenes/ui/raid_briefing_panel.tscn"

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_briefing_open_cancel_and_confirm()
	_validate_ownership_boundaries()
	if _errors.is_empty():
		print("[raid_briefing_ui] OK open=briefing cancel=base confirm=raid layout=fit text=zh boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_briefing_open_cancel_and_confirm() -> void:
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait_frames(3)

	if scene.scene_file_path != BASE_3D_SCENE:
		_errors.append("Validation should start from Base3D.")
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	var panel := scene.get_node_or_null("HUD/RaidBriefingPanel")
	if controller == null:
		_errors.append("Base3D should include BaseInteractionController3D.")
		_free_current_scene()
		return
	if panel == null:
		_errors.append("Base3D should include the node-first RaidBriefingPanel under HUD.")
		_free_current_scene()
		return
	if not panel.has_method("open_briefing") or not panel.has_method("confirm_start") or not panel.has_method("get_display_state_for_viewport"):
		_errors.append("RaidBriefingPanel should expose briefing, confirm, and layout validation methods.")
		_free_current_scene()
		return

	if not bool(controller.call("open_interaction_by_id", "raid_gate")):
		_errors.append("Raid gate should open the briefing panel.")
		_free_current_scene()
		return
	await _wait_frames(3)

	if current_scene == null or current_scene.scene_file_path != BASE_3D_SCENE:
		_errors.append("Opening the raid gate should keep the player in Base3D until the briefing is confirmed.")
	if not bool(panel.call("is_open")):
		_errors.append("Raid briefing should be visible after opening the raid gate.")
	if not controller.call("get_last_prepared_raid_loadout").is_empty():
		_errors.append("Raid loadout should not be prepared before the briefing is confirmed.")
	_validate_text_state(panel.call("get_display_state"))
	_validate_layout_state(panel, Vector2(1280.0, 720.0))
	_validate_layout_state(panel, Vector2(1920.0, 1080.0))

	panel.call("cancel")
	await _wait_frames(3)
	if bool(panel.call("is_open")):
		_errors.append("Cancel should close the raid briefing.")
	if current_scene == null or current_scene.scene_file_path != BASE_3D_SCENE:
		_errors.append("Cancel should leave the player in Base3D.")

	if not bool(controller.call("open_interaction_by_id", "raid_gate")):
		_errors.append("Raid gate should reopen the briefing after cancel.")
		_free_current_scene()
		return
	await _wait_frames(3)
	panel.call("confirm_start")
	await _wait_frames(14)

	if current_scene == null:
		_errors.append("Confirming the briefing should leave a loaded current scene.")
	elif current_scene.scene_file_path != GAMEPLAY_SCENE:
		_errors.append("Confirming the briefing should load gameplay, got `%s`." % current_scene.scene_file_path)
	else:
		var player := current_scene.get_node_or_null("Player3D")
		var enemy := _find_visible_enemy(current_scene)
		if player == null:
			_errors.append("Gameplay scene after briefing should include Player3D.")
		if enemy == null:
			_errors.append("Gameplay scene after briefing should still include the visible 3D enemy.")

	_free_current_scene()


func _validate_text_state(state: Dictionary) -> void:
	var combined := "%s\n%s\n%s\n%s\n%s\n%s\n%s" % [
		state.get("title", ""),
		state.get("location", ""),
		state.get("risk", ""),
		state.get("objective", ""),
		state.get("loadout", ""),
		state.get("start_button", ""),
		state.get("cancel_button", ""),
	]
	var required_terms := ["出擊簡報", "地點", "風險", "拾荒者", "搜索物資", "撤離點", "開始出擊", "取消"]
	for term in required_terms:
		if not combined.contains(term):
			_errors.append("Raid briefing text should include `%s`." % term)
	if _contains_ascii_word(combined):
		_errors.append("Raid briefing should not expose English fallback text.")


func _validate_layout_state(panel: Control, viewport_size: Vector2) -> void:
	var state: Dictionary = panel.call("get_display_state_for_viewport", viewport_size)
	var rect: Rect2 = state.get("panel_rect", Rect2())
	if rect.position.x < 0.0 or rect.position.y < 0.0:
		_errors.append("Raid briefing panel escapes viewport at %s." % viewport_size)
	if rect.end.x > viewport_size.x or rect.end.y > viewport_size.y:
		_errors.append("Raid briefing panel exceeds viewport at %s." % viewport_size)
	var start_min: Vector2 = state.get("start_button_min_size", Vector2.ZERO)
	var cancel_min: Vector2 = state.get("cancel_button_min_size", Vector2.ZERO)
	if start_min.x < 150.0 or start_min.y < 42.0:
		_errors.append("Raid briefing start button is too small at %s." % viewport_size)
	if cancel_min.x < 150.0 or cancel_min.y < 42.0:
		_errors.append("Raid briefing cancel button is too small at %s." % viewport_size)


func _validate_ownership_boundaries() -> void:
	var controller_source := FileAccess.get_file_as_string(CONTROLLER_SOURCE)
	var panel_source := FileAccess.get_file_as_string(PANEL_SOURCE)
	var panel_scene := FileAccess.get_file_as_string(PANEL_SCENE)
	if not controller_source.contains("open_briefing") or not controller_source.contains("set_pending_raid_loadout"):
		_errors.append("BaseInteractionController3D should own the raid transition and loadout preparation.")
	var forbidden_panel_terms := ["change_scene", "set_pending_raid_loadout", "InventoryModel", "WeaponController3D", "SaveGameManager"]
	for term in forbidden_panel_terms:
		if panel_source.contains(term):
			_errors.append("RaidBriefingPanel should not own gameplay/loadout responsibility: %s." % term)
	var required_nodes := ["PanelContainer", "MarginContainer", "VBoxContainer", "HBoxContainer", "Label", "Button"]
	for node_type in required_nodes:
		if not panel_scene.contains(node_type):
			_errors.append("Raid briefing scene should remain node-first and include %s." % node_type)


func _find_visible_enemy(root_node: Node) -> Node:
	if root_node == null:
		return null
	if root_node.name.to_lower().contains("scavenger") or root_node.name.to_lower().contains("enemy"):
		return root_node
	for child in root_node.get_children():
		var found := _find_visible_enemy(child)
		if found != null:
			return found
	return null


func _contains_ascii_word(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("[A-Za-z]{3,}")
	return regex.search(value) != null


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _free_current_scene() -> void:
	var scene := current_scene
	current_scene = null
	if scene == null or not is_instance_valid(scene):
		current_scene = null
		return
	if scene.get_parent() != null:
		scene.get_parent().remove_child(scene)
	scene.queue_free()
