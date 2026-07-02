extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const RaidHudScene := preload("res://scenes/ui/raid_hud_panel.tscn")
const RaidHudScript := preload("res://scripts/ui/raid_hud_panel.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_gameplay_hud_wiring()
	_validate_layout_quality()
	_validate_node_first_structure()
	_validate_ui_independence()
	if _errors.is_empty():
		print("[raid_hud] OK objective=visible extraction=status ammo=visible ui_manager=compatible layout=fit")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_gameplay_hud_wiring() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var hud := scene.get_node_or_null("HUD/RaidHudPanel")
	if hud == null:
		_errors.append("Gameplay scene should include HUD/RaidHudPanel.")
		_free_node(scene)
		return
	if hud.get_script() != RaidHudScript:
		_errors.append("RaidHudPanel should use RaidHudPanel script.")

	var state: Dictionary = hud.call("get_display_state")
	if not (
		str(state.get("objective", "")).contains("搜索物資")
		or str(state.get("objective", "")).contains("Find supplies")
	):
		_errors.append("Raid HUD should show the early raid objective.")
	if not (
		str(state.get("status", "")).contains("行動中")
		or str(state.get("status", "")).contains("Raid active")
	):
		_errors.append("Raid HUD should show active raid status.")
	if not (
		str(state.get("ammo", "")).contains("彈藥")
		or str(state.get("ammo", "")).contains("Ammo")
	):
		_errors.append("Raid HUD should show current weapon ammo.")
	if int(state.get("mouse_filter", -1)) != Control.MOUSE_FILTER_IGNORE:
		_errors.append("Raid HUD should ignore mouse input so it does not block gameplay or panels.")

	var player := scene.get_node_or_null("Player3D") as Node3D
	var extraction_zone := scene.get_node_or_null("SceneProps/ExtractionZone")
	if player == null or extraction_zone == null:
		_errors.append("Gameplay scene should include player and extraction zone for Raid HUD validation.")
		_free_node(scene)
		return
	extraction_zone.call("_on_body_entered", player)
	extraction_zone.call("_process", 1.0)
	await process_frame
	state = hud.call("get_display_state")
	if not (
		str(state.get("extraction", "")).contains("撤離")
		or str(state.get("extraction", "")).contains("Extraction")
	):
		_errors.append("Raid HUD should show extraction countdown/status while player is in the zone.")
	if float(state.get("extraction_progress", 0.0)) <= 0.0:
		_errors.append("Raid HUD extraction progress should increase while extracting.")

	var ui_manager := root.get_node_or_null("UIManager")
	if ui_manager != null and ui_manager.has_method("open_ui"):
		ui_manager.call("open_ui", &"backpack")
		await process_frame
		state = hud.call("get_display_state")
		if not bool(state.get("visible", false)):
			_errors.append("Raid HUD should remain valid when backpack UI is opened.")
		ui_manager.call("close_active_ui")

	_free_node(scene)


func _validate_layout_quality() -> void:
	var hud := RaidHudScene.instantiate()
	root.add_child(hud)
	await process_frame
	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		var rect: Rect2 = hud.call("preview_layout", viewport_size)
		if rect.position.x < 24.0 or rect.position.y < 24.0:
			_errors.append("Raid HUD should keep a safe top-left margin at %s." % viewport_size)
		if rect.end.x > viewport_size.x or rect.end.y > viewport_size.y:
			_errors.append("Raid HUD should fit within viewport at %s." % viewport_size)
		if rect.size.x > viewport_size.x * 0.34:
			_errors.append("Raid HUD should not cover too much horizontal gameplay view at %s." % viewport_size)
		if rect.size.y > viewport_size.y * 0.26:
			_errors.append("Raid HUD should not cover too much vertical gameplay view at %s." % viewport_size)
	_free_node(hud)


func _validate_node_first_structure() -> void:
	var hud := RaidHudScene.instantiate()
	root.add_child(hud)
	await process_frame
	for path in [
		"MainPanel/PanelMargin/Content/ObjectiveLabel",
		"MainPanel/PanelMargin/Content/StatusLabel",
		"MainPanel/PanelMargin/Content/ExtractionLabel",
		"MainPanel/PanelMargin/Content/ExtractionProgress",
		"MainPanel/PanelMargin/Content/AmmoLabel",
	]:
		if hud.get_node_or_null(path) == null:
			_errors.append("Raid HUD scene should provide node-first UI path: %s" % path)
	var objective := hud.get_node_or_null("MainPanel/PanelMargin/Content/ObjectiveLabel") as Label
	if objective != null and objective.get_theme_font_size("font_size") < 16:
		_errors.append("Raid HUD objective text should remain readable at early target resolutions.")
	_free_node(hud)


func _validate_ui_independence() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/raid_hud_panel.gd")
	if source.contains("InventoryEquipmentUI") or source.contains("ItemCodexUI"):
		_errors.append("RaidHudPanel should not directly depend on inventory or codex panel scripts.")


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
