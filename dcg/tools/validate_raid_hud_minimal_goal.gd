extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const RaidHudScene := preload("res://scenes/ui/raid_hud_panel.tscn")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_normal_gameplay_hud()
	await _validate_legacy_goal_panel_is_compact()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[raid_hud_minimal_goal] OK legacy_panel=hidden combat_hud=visible route_detail=top_menu layout=fit boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_normal_gameplay_hud() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player_hud := scene.get_node_or_null("HUD/PlayerHud3D")
	var raid_hud := scene.get_node_or_null("HUD/RaidHudPanel")
	var top_menu := scene.get_node_or_null("HUD/TopMenuBar")
	var quest_panel := scene.get_node_or_null("HUD/QuestTopMenuPanel")
	var map_panel := scene.get_node_or_null("HUD/MapTopMenuPanel")
	if player_hud == null or raid_hud == null or top_menu == null or quest_panel == null or map_panel == null:
		_errors.append("Gameplay scene should include PlayerHud3D, hidden RaidHudPanel, TopMenuBar, QuestTopMenuPanel, and MapTopMenuPanel.")
		_free_node(scene)
		return

	var player_state: Dictionary = player_hud.call("get_display_state")
	if not bool(player_state.get("visible", false)):
		_errors.append("PlayerHud3D should remain the normal visible combat HUD.")
	if not bool(player_state.get("crosshair_visible", false)):
		_errors.append("PlayerHud3D should keep the mouse crosshair visible during normal gameplay.")
	if not bool(player_state.get("ammo_visible", false)):
		_errors.append("PlayerHud3D should keep weapon ammo summary visible during normal gameplay.")
	if str(player_state.get("health_text", "")) == "":
		_errors.append("PlayerHud3D should keep the lower-left health summary readable.")

	var legacy_state: Dictionary = raid_hud.call("get_display_state")
	if bool(legacy_state.get("visible", true)):
		_errors.append("Legacy top-left RaidHudPanel should not be visible during normal gameplay.")
	if int(legacy_state.get("mouse_filter", -1)) != Control.MOUSE_FILTER_IGNORE:
		_errors.append("Legacy RaidHudPanel should ignore mouse input when hidden or previewed.")
	if bool(legacy_state.get("route_hint_visible", true)):
		_errors.append("Long route hints should stay hidden from the normal combat HUD.")

	var ui_manager := root.get_node_or_null("UIManager")
	if ui_manager != null and ui_manager.has_method("open_ui"):
		ui_manager.call("open_ui", &"backpack")
		await process_frame
		player_state = player_hud.call("get_display_state")
		legacy_state = raid_hud.call("get_display_state")
		if not bool(player_state.get("visible", false)):
			_errors.append("Opening the backpack should not disable PlayerHud3D.")
		if bool(legacy_state.get("visible", true)):
			_errors.append("Opening the backpack should not bring back the hidden top-left RaidHudPanel.")
		if not bool(top_menu.get("visible")):
			_errors.append("Opening the backpack should show the top menu row for detailed tabs.")
		ui_manager.call("open_ui", &"quests")
		await process_frame
		if not bool(quest_panel.get("is_open")):
			_errors.append("Detailed quest objectives should be reachable from the Top Menu quest tab.")
		ui_manager.call("open_ui", &"map")
		await process_frame
		if not bool(map_panel.get("is_open")):
			_errors.append("Detailed route/map information should be reachable from the Top Menu map tab.")
		ui_manager.call("close_active_ui")

	_free_node(scene)


func _validate_legacy_goal_panel_is_compact() -> void:
	var hud := RaidHudScene.instantiate()
	root.add_child(hud)
	await process_frame
	hud.call("_update_objective")
	var state: Dictionary = hud.call("get_display_state")
	var objective := str(state.get("objective", ""))
	for term in ["搜索物資", "小心敵人", "前往撤離點"]:
		if not objective.contains(term):
			_errors.append("Legacy RaidHudPanel preview objective should keep concise route term: %s." % term)
	if bool(state.get("route_hint_visible", true)):
		_errors.append("Legacy RaidHudPanel preview should keep detailed route hint hidden.")
	var route_hint := str(state.get("route_hint", ""))
	if not route_hint.contains("箱子") or not route_hint.contains("撤離區"):
		_errors.append("Hidden route hint should still contain the detailed path for preview/debug use.")

	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		var rect: Rect2 = hud.call("preview_layout", viewport_size)
		if rect.position.x < 24.0 or rect.position.y < 24.0:
			_errors.append("Legacy RaidHudPanel preview should keep a safe margin at %s." % viewport_size)
		if rect.end.x > viewport_size.x or rect.end.y > viewport_size.y:
			_errors.append("Legacy RaidHudPanel preview should fit inside %s." % viewport_size)
		if rect.size.x > 390.0 or rect.size.y > 160.0:
			_errors.append("Legacy RaidHudPanel preview should stay compact, got %s." % rect.size)
	_free_node(hud)


func _validate_source_boundaries() -> void:
	var player_hud_source := FileAccess.get_file_as_string("res://scripts/ui/player_hud_3d.gd")
	if not player_hud_source.contains("PlayerHUDPainterScript"):
		_errors.append("PlayerHud3D should delegate combat HUD painting to PlayerHUDPainterScript.")
	var player_hud_painter_source := FileAccess.get_file_as_string("res://scripts/ui/player_hud_painter.gd")
	for required in ["_paint_lower_left_health", "_paint_ammo_panel", "_paint_reload_progress", "_paint_crosshair"]:
		if not player_hud_painter_source.contains(required):
			_errors.append("PlayerHUDPainter should own minimal combat HUD term: %s." % required)
	for forbidden in ["QuestTopMenuPanel", "MapTopMenuPanel", "QuestState", "change_scene_to_file"]:
		if player_hud_source.contains(forbidden):
			_errors.append("PlayerHud3D should not own detailed objective, map, quest, or scene flow logic: %s." % forbidden)

	var raid_hud_source := FileAccess.get_file_as_string("res://scripts/ui/raid_hud_panel.gd")
	for forbidden in ["InventoryEquipmentUI", "QuestTopMenuPanel", "MapTopMenuPanel", "LootContainer3D", "change_scene_to_file"]:
		if raid_hud_source.contains(forbidden):
			_errors.append("RaidHudPanel should remain display-only and not couple to gameplay panels or scene flow: %s." % forbidden)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
