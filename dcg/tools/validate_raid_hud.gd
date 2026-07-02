extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const RaidHudScene := preload("res://scenes/ui/raid_hud_panel.tscn")
const RaidHudScript := preload("res://scripts/ui/raid_hud_panel.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_gameplay_hud_wiring()
	_validate_layout_quality()
	_validate_node_first_structure()
	_validate_ui_independence()
	if _errors.is_empty():
		print("[raid_hud] OK objective=visible route=clear vitals=visible ammo=weapon extraction=status ui_manager=compatible layout=fit")
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
	_require_exact(state, "goal_title", "目前目標", "Raid HUD should show a Traditional Chinese current-objective title.")
	_require_terms(state, "objective", ["搜索物資", "小心敵人", "前往撤離點"], "Raid HUD objective should list the visible raid route.")
	if bool(state.get("route_hint_visible", true)):
		_errors.append("Raid HUD should hide long route instructions; detailed tasks belong in the top-menu quest tab.")
	_require_terms(state, "status", ["行動中"], "Raid HUD should show active raid status in Traditional Chinese.")
	_require_terms(state, "vitals", ["生命", "體力"], "Raid HUD should show player health and stamina.")
	_require_terms(state, "ammo", ["武器", "手槍-S", "彈藥"], "Raid HUD should show current weapon and ammo.")
	_require_terms(state, "weapon_status", ["戰鬥狀態"], "Raid HUD should show readable weapon combat status.")
	_require_any_term(state, "weapon_status", ["未裝備", "空彈", "裝填中", "可射擊", "射擊間隔"], "Raid HUD weapon status should show a player-readable state.")
	_reject_english_fallbacks(state, ["objective", "route_hint", "status", "vitals", "extraction", "ammo", "weapon_status"])

	if int(state.get("mouse_filter", -1)) != Control.MOUSE_FILTER_IGNORE:
		_errors.append("Raid HUD should ignore mouse input so it does not block gameplay or panels.")
	var idle_rect: Rect2 = state.get("panel_rect", Rect2())
	if idle_rect.size.x > 390.0 or idle_rect.size.y > 160.0:
		_errors.append("Raid HUD should be a compact combat summary, not a large panel. Got %s." % idle_rect.size)
	if bool(state.get("extraction_progress_visible", true)):
		_errors.append("Raid HUD extraction progress should stay hidden until the player starts extracting.")

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
	_require_terms(state, "extraction", ["撤離"], "Raid HUD should show extraction countdown/status while player is in the zone.")
	if float(state.get("extraction_progress", 0.0)) <= 0.0:
		_errors.append("Raid HUD extraction progress should increase while extracting.")
	if not bool(state.get("extraction_progress_visible", false)):
		_errors.append("Raid HUD extraction progress should become visible while extracting.")

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
		if rect.size.x > viewport_size.x * 0.30:
			_errors.append("Compact Raid HUD should not cover too much horizontal gameplay view at %s." % viewport_size)
		if rect.size.y > viewport_size.y * 0.23:
			_errors.append("Compact Raid HUD should not cover too much vertical gameplay view at %s." % viewport_size)
	_free_node(hud)


func _validate_node_first_structure() -> void:
	var hud := RaidHudScene.instantiate()
	root.add_child(hud)
	await process_frame
	for path in [
		"MainPanel/PanelMargin/Content/GoalTitleLabel",
		"MainPanel/PanelMargin/Content/ObjectiveLabel",
		"MainPanel/PanelMargin/Content/RouteHintLabel",
		"MainPanel/PanelMargin/Content/StatusLabel",
		"MainPanel/PanelMargin/Content/VitalsLabel",
		"MainPanel/PanelMargin/Content/ExtractionLabel",
		"MainPanel/PanelMargin/Content/ExtractionProgress",
		"MainPanel/PanelMargin/Content/AmmoLabel",
		"MainPanel/PanelMargin/Content/WeaponStatusLabel",
		"MainPanel/PanelMargin/Content/ReloadLabel",
		"MainPanel/PanelMargin/Content/ReloadProgress",
	]:
		if hud.get_node_or_null(path) == null:
			_errors.append("Raid HUD scene should provide node-first UI path: %s" % path)
	var reload_progress := hud.get_node_or_null("MainPanel/PanelMargin/Content/ReloadProgress") as ProgressBar
	if reload_progress == null:
		_errors.append("Raid HUD reload progress should be a ProgressBar node.")
	var objective := hud.get_node_or_null("MainPanel/PanelMargin/Content/ObjectiveLabel") as Label
	if objective != null:
		if objective.get_theme_font_size("font_size") < 16:
			_errors.append("Raid HUD objective text should remain readable at early target resolutions.")
		_require_text_terms(objective.text, ["搜索物資", "小心敵人", "前往撤離點"], "Raid HUD scene default objective should be readable before runtime refresh.")
	var route_hint := hud.get_node_or_null("MainPanel/PanelMargin/Content/RouteHintLabel") as Label
	if route_hint != null and route_hint.visible:
		_errors.append("Raid HUD scene should keep RouteHintLabel hidden for compact mode.")
	var extraction_bar := hud.get_node_or_null("MainPanel/PanelMargin/Content/ExtractionProgress") as ProgressBar
	if extraction_bar != null and extraction_bar.visible:
		_errors.append("Raid HUD scene should hide extraction progress until extraction starts.")
	var ammo := hud.get_node_or_null("MainPanel/PanelMargin/Content/AmmoLabel") as Label
	if ammo != null:
		_require_text_terms(ammo.text, ["武器", "手槍-S", "彈藥"], "Raid HUD scene default ammo text should be Traditional Chinese.")
	var weapon_status := hud.get_node_or_null("MainPanel/PanelMargin/Content/WeaponStatusLabel") as Label
	if weapon_status != null:
		_require_text_terms(weapon_status.text, ["戰鬥狀態", "未裝備"], "Raid HUD scene default weapon status should be Traditional Chinese.")
	_free_node(hud)


func _validate_ui_independence() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/raid_hud_panel.gd")
	if source.contains("InventoryEquipmentUI") or source.contains("ItemCodexUI"):
		_errors.append("RaidHudPanel should not directly depend on inventory or codex panel scripts.")
	if source.contains("\"Find supplies") or source.contains("\"Raid active") or source.contains("\"Ammo"):
		_errors.append("RaidHudPanel fallbacks should be Traditional Chinese, not English.")
	for required in ["WeaponStatusLabel", "_update_weapon_status", "_weapon_status_text", "get_reload_state"]:
		if not source.contains(required):
			_errors.append("RaidHudPanel should expose weapon status HUD term: %s." % required)


func _require_exact(state: Dictionary, key: String, expected: String, message: String) -> void:
	var actual := str(state.get(key, ""))
	if actual != expected:
		_errors.append("%s Got `%s`." % [message, actual])


func _require_terms(state: Dictionary, key: String, terms: Array[String], message: String) -> void:
	_require_text_terms(str(state.get(key, "")), terms, message)


func _require_any_term(state: Dictionary, key: String, terms: Array[String], message: String) -> void:
	var actual := str(state.get(key, ""))
	for term in terms:
		if actual.contains(term):
			return
	_errors.append("%s Missing one of `%s` in `%s`." % [message, terms, actual])


func _require_text_terms(text: String, terms: Array[String], message: String) -> void:
	for term in terms:
		if not text.contains(term):
			if _allows_unarmed_ammo_state(text, term, message):
				continue
			_errors.append("%s Missing `%s` in `%s`." % [message, term, text])


func _allows_unarmed_ammo_state(text: String, term: String, message: String) -> bool:
	if not (message.contains("current weapon and ammo") or message.contains("default ammo text")):
		return false
	return text.contains("未裝備") and term.ends_with("-S")


func _reject_english_fallbacks(state: Dictionary, keys: Array[String]) -> void:
	for key in keys:
		var value := str(state.get(key, ""))
		for token in ["Find supplies", "Reach extraction", "Raid active", "Ready", "Health", "Stamina", "Weapon", "Ammo", "No weapon", "Ready to fire", "Reloading", "Empty", "Combat status"]:
			if value.contains(token):
				_errors.append("Raid HUD %s should not show English fallback text: %s" % [key, value])


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
