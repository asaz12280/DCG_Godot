extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const QuestTopMenuScene := preload("res://scenes/ui/quest_top_menu_panel.tscn")
const QuestTopMenuScript := preload("res://scripts/ui/quest_top_menu_panel.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_quest_tab_opens_panel()
	await _validate_quest_panel_layout()
	_validate_node_first_structure()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[top_menu_panels] OK quests_tab=opens list=salvage_hunt layout=fit ui_manager=owns_state boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_quest_tab_opens_panel() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var ui_manager := root.get_node_or_null("UIManager")
	var top_menu := scene.get_node_or_null("HUD/TopMenuBar")
	var quest_panel := scene.get_node_or_null("HUD/QuestTopMenuPanel")
	if ui_manager == null or top_menu == null or quest_panel == null:
		_errors.append("Gameplay scene should include UIManager, TopMenuBar, and QuestTopMenuPanel.")
		_free_node(scene)
		return
	if quest_panel.get_script() != QuestTopMenuScript:
		_errors.append("QuestTopMenuPanel should use QuestTopMenuPanel script.")

	ui_manager.call("open_ui", &"quests")
	await process_frame
	var state: Dictionary = quest_panel.call("get_display_state")
	if not bool(state.get("visible", false)):
		_errors.append("Opening top-menu quest tab should show QuestTopMenuPanel.")
	if str(ui_manager.call("get_active_ui")) != "quests":
		_errors.append("UIManager active UI should be `quests` after opening the quest tab.")
	if not bool(top_menu.get("visible")):
		_errors.append("TopMenuBar should remain visible while the quest panel is open.")
	if str(top_menu.call("get_selected_item_id")) != "quests":
		_errors.append("TopMenuBar should select the quest icon when the quest panel is open.")
	_require_terms(str(state.get("title", "")), ["任務"], "Quest panel title should be Traditional Chinese.")
	_validate_quest_summaries(state)

	ui_manager.call("open_ui", &"backpack")
	await process_frame
	state = quest_panel.call("get_display_state")
	if bool(state.get("visible", true)):
		_errors.append("Opening backpack tab should close the quest panel.")

	_free_node(scene)


func _validate_quest_panel_layout() -> void:
	var panel := QuestTopMenuScene.instantiate()
	root.add_child(panel)
	await process_frame
	panel.call("open_quests")
	await process_frame
	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		var rect: Rect2 = panel.call("preview_layout", viewport_size)
		if rect.position.y < 70.0:
			_errors.append("Quest top-menu panel should sit below the icon bar at %s." % viewport_size)
		if rect.end.x > viewport_size.x or rect.end.y > viewport_size.y:
			_errors.append("Quest top-menu panel should fit inside viewport at %s." % viewport_size)
		if rect.size.x > viewport_size.x * 0.55:
			_errors.append("Quest top-menu panel should not cover too much horizontal gameplay view at %s." % viewport_size)
		if rect.size.y > viewport_size.y * 0.50:
			_errors.append("Quest top-menu panel should not cover too much vertical gameplay view at %s." % viewport_size)
		var state: Dictionary = panel.call("get_display_state_for_viewport", viewport_size)
		_validate_quest_summaries(state)
	_free_node(panel)


func _validate_node_first_structure() -> void:
	var panel := QuestTopMenuScene.instantiate()
	root.add_child(panel)
	await process_frame
	for path in [
		"MainPanel/PanelMargin/Content/TitleLabel",
		"MainPanel/PanelMargin/Content/HintLabel",
		"MainPanel/PanelMargin/Content/QuestCards/FirstQuestCard/Margin/Rows/FirstQuestNameLabel",
		"MainPanel/PanelMargin/Content/QuestCards/FirstQuestCard/Margin/Rows/FirstQuestObjectiveLabel",
		"MainPanel/PanelMargin/Content/QuestCards/FirstQuestCard/Margin/Rows/FirstQuestProgressLabel",
		"MainPanel/PanelMargin/Content/QuestCards/FirstQuestCard/Margin/Rows/FirstQuestStatusLabel",
		"MainPanel/PanelMargin/Content/QuestCards/SecondQuestCard/Margin/Rows/SecondQuestNameLabel",
		"MainPanel/PanelMargin/Content/QuestCards/SecondQuestCard/Margin/Rows/SecondQuestObjectiveLabel",
		"MainPanel/PanelMargin/Content/QuestCards/SecondQuestCard/Margin/Rows/SecondQuestProgressLabel",
		"MainPanel/PanelMargin/Content/QuestCards/SecondQuestCard/Margin/Rows/SecondQuestStatusLabel",
	]:
		if panel.get_node_or_null(path) == null:
			_errors.append("Quest panel scene should provide node-first UI path: %s" % path)
	_free_node(panel)


func _validate_source_boundaries() -> void:
	var ui_manager_source := FileAccess.get_file_as_string("res://scripts/ui/ui_manager.gd")
	for required in ["QuestTopMenuPanel", "open_quests", "close_quests", "UI_QUESTS"]:
		if not ui_manager_source.contains(required):
			_errors.append("UIManager should own quest panel state through %s." % required)

	var panel_source := FileAccess.get_file_as_string("res://scripts/ui/quest_top_menu_panel.gd")
	for required in ["BaseScreenViewModelScript.quest_defs", "QuestStateScript", "get_slot_data"]:
		if not panel_source.contains(required):
			_errors.append("QuestTopMenuPanel should read quest model state through %s." % required)
	for forbidden in ["claim_reward", "save_slot_data", "RaidResultApplier", "WeaponController3D", "InventoryModel", "LootContainer3D"]:
		if panel_source.contains(forbidden):
			_errors.append("QuestTopMenuPanel should be display-only and not own gameplay state: %s." % forbidden)

	var scene_text := FileAccess.get_file_as_string("res://scenes/gameplay/player_test_world_3d.tscn")
	if not scene_text.contains("QuestTopMenuPanel"):
		_errors.append("Gameplay HUD should instance QuestTopMenuPanel.")


func _validate_quest_summaries(state: Dictionary) -> void:
	var quests: Array = state.get("quests", []) as Array
	if quests.size() < 2:
		_errors.append("Quest panel should show both early collect and kill quests.")
		return
	var text := "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s" % [
		quests[0].get("name", ""),
		quests[0].get("objective", ""),
		quests[0].get("progress", ""),
		quests[0].get("status", ""),
		quests[1].get("name", ""),
		quests[1].get("objective", ""),
		quests[1].get("progress", ""),
		quests[1].get("status", ""),
	]
	for term in ["首次回收", "帶回", "進度", "首次獵捕拾荒者", "擊倒", "拾荒者"]:
		_require_terms(text, [term], "Quest top-menu panel should show collect and kill quest details.")
	for token in ["Quest List", "Track current", "Active", "Ready", "Completed"]:
		if text.contains(token) or str(state.get("title", "")).contains(token) or str(state.get("hint", "")).contains(token):
			_errors.append("Quest top-menu panel should not show English fallback text.")


func _require_terms(text: String, terms: Array[String], message: String) -> void:
	for term in terms:
		if not text.contains(term):
			_errors.append("%s Missing `%s` in `%s`." % [message, term, text])


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
