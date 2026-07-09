extends SceneTree

const LocalizationBootstrapScript := preload("res://scripts/localization/localization_bootstrap.gd")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const QuestTopMenuScene := preload("res://scenes/ui/quest_top_menu_panel.tscn")
const QuestTopMenuScript := preload("res://scripts/ui/quest_top_menu_panel.gd")
const StatusTopMenuScene := preload("res://scenes/ui/status_top_menu_panel.tscn")
const StatusTopMenuScript := preload("res://scripts/ui/status_top_menu_panel.gd")
const MapTopMenuScene := preload("res://scenes/ui/map_top_menu_panel.tscn")
const MapTopMenuScript := preload("res://scripts/ui/map_top_menu_panel.gd")
const PistolItem := preload("res://data/items/weapons/pistol_9mm.tres")
const AmmoItem := preload("res://data/items/ammo/ammo_9mm.tres")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")

const VALIDATION_SAVE_ROOT := "user://validation_top_menu_panels"
var _errors: Array[String] = []
var _original_save_root := ""
var _original_slot := 1


func _initialize() -> void:
	var localization := root.get_node_or_null("LocalizationBootstrap")
	if localization == null:
		localization = LocalizationBootstrapScript.new()
		localization.name = "ValidationLocalizationBootstrap"
		root.add_child(localization)
		await process_frame
	_force_validation_locale()
	var save_manager := root.get_node_or_null("SaveGameManager")
	_prepare_save_manager(save_manager)
	await _validate_quest_tab_opens_panel()
	await _validate_status_tab_opens_panel()
	await _validate_map_tab_opens_panel()
	await _validate_quest_panel_layout()
	await _validate_quest_panel_english_locale(localization)
	await _validate_status_panel_layout()
	await _validate_map_panel_layout()
	_validate_node_first_structure()
	_validate_source_boundaries()
	_restore_save_manager(save_manager)
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	_free_node(localization)
	if _errors.is_empty():
		print("[top_menu_panels] OK quests_tab=board_accept status_tab=player_model map_tab=title_only list=available_active_completed layout=fit ui_manager=owns_state boundaries=clean")
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
	_force_validation_locale()

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
	_validate_quest_board_state(state)
	_validate_fresh_quest_action(state)
	_validate_empty_quest_tabs_are_selectable(quest_panel)
	if quest_panel.has_method("request_selected_action"):
		quest_panel.call("request_selected_action")
		await process_frame
		_validate_accepted_first_quest(root.get_node_or_null("SaveGameManager"), quest_panel)
		quest_panel.call("select_category", "active")
		quest_panel.call("select_quest", "first_salvage")
		await process_frame
		quest_panel.call("request_selected_action")
		await process_frame
		_validate_cancelled_first_quest(root.get_node_or_null("SaveGameManager"), quest_panel)

	ui_manager.call("open_ui", &"backpack")
	await process_frame
	state = quest_panel.call("get_display_state")
	if bool(state.get("visible", true)):
		_errors.append("Opening backpack tab should close the quest panel.")

	_free_node(scene)


func _validate_status_tab_opens_panel() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	_force_validation_locale()

	var ui_manager := root.get_node_or_null("UIManager")
	var top_menu := scene.get_node_or_null("HUD/TopMenuBar")
	var status_panel := scene.get_node_or_null("HUD/StatusTopMenuPanel")
	var quest_panel := scene.get_node_or_null("HUD/QuestTopMenuPanel")
	var player := scene.get_node_or_null("Player3D")
	if ui_manager == null or top_menu == null or status_panel == null or player == null:
		_errors.append("Gameplay scene should include UIManager, TopMenuBar, StatusTopMenuPanel, and Player3D.")
		_free_node(scene)
		return
	if status_panel.get_script() != StatusTopMenuScript:
		_errors.append("StatusTopMenuPanel should use StatusTopMenuPanel script.")

	_prepare_player_status_sample(player)
	ui_manager.call("open_ui", &"status")
	await process_frame
	var state: Dictionary = status_panel.call("get_display_state")
	if not bool(state.get("visible", false)):
		_errors.append("Opening top-menu status tab should show StatusTopMenuPanel.")
	if str(ui_manager.call("get_active_ui")) != "status":
		_errors.append("UIManager active UI should be `status` after opening the status tab.")
	if not bool(top_menu.get("visible")):
		_errors.append("TopMenuBar should remain visible while the status panel is open.")
	if str(top_menu.call("get_selected_item_id")) != "status":
		_errors.append("TopMenuBar should select the status icon when the status panel is open.")
	_validate_status_summary(state)

	ui_manager.call("open_ui", &"quests")
	await process_frame
	state = status_panel.call("get_display_state")
	if bool(state.get("visible", true)):
		_errors.append("Opening quest tab should close the status panel.")
	if quest_panel != null and not bool(quest_panel.call("get_display_state").get("visible", false)):
		_errors.append("Switching from status to quests should still open the quest panel.")

	_free_node(scene)


func _validate_map_tab_opens_panel() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	_force_validation_locale()

	var ui_manager := root.get_node_or_null("UIManager")
	var top_menu := scene.get_node_or_null("HUD/TopMenuBar")
	var map_panel := scene.get_node_or_null("HUD/MapTopMenuPanel")
	var status_panel := scene.get_node_or_null("HUD/StatusTopMenuPanel")
	if ui_manager == null or top_menu == null or map_panel == null:
		_errors.append("Gameplay scene should include UIManager, TopMenuBar, and MapTopMenuPanel.")
		_free_node(scene)
		return
	if map_panel.get_script() != MapTopMenuScript:
		_errors.append("MapTopMenuPanel should use MapTopMenuPanel script.")

	ui_manager.call("open_ui", &"map")
	await process_frame
	var state: Dictionary = map_panel.call("get_display_state")
	if not bool(state.get("visible", false)):
		_errors.append("Opening top-menu map tab should show MapTopMenuPanel.")
	if str(ui_manager.call("get_active_ui")) != "map":
		_errors.append("UIManager active UI should be `map` after opening the map tab.")
	if not bool(top_menu.get("visible")):
		_errors.append("TopMenuBar should remain visible while the map panel is open.")
	if str(top_menu.call("get_selected_item_id")) != "map":
		_errors.append("TopMenuBar should select the map icon when the map panel is open.")
	_validate_map_summary(state)

	ui_manager.call("open_ui", &"status")
	await process_frame
	state = map_panel.call("get_display_state")
	if bool(state.get("visible", true)):
		_errors.append("Opening status tab should close the map panel.")
	if status_panel != null and not bool(status_panel.call("get_display_state").get("visible", false)):
		_errors.append("Switching from map to status should still open the status panel.")

	_free_node(scene)


func _validate_quest_panel_layout() -> void:
	var panel := QuestTopMenuScene.instantiate()
	root.add_child(panel)
	await process_frame
	_force_validation_locale()
	panel.call("open_quests")
	await process_frame
	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		var rect: Rect2 = panel.call("preview_layout", viewport_size)
		if rect.position.y < 70.0:
			_errors.append("Quest top-menu panel should sit below the icon bar at %s." % viewport_size)
		if rect.end.x > viewport_size.x or rect.end.y > viewport_size.y:
			_errors.append("Quest top-menu panel should fit inside viewport at %s." % viewport_size)
		if rect.size.x > viewport_size.x * 0.84:
			_errors.append("Quest top-menu panel should not cover too much horizontal gameplay view at %s." % viewport_size)
		if rect.size.y > viewport_size.y * 0.72:
			_errors.append("Quest top-menu panel should not cover too much vertical gameplay view at %s." % viewport_size)
		var state: Dictionary = panel.call("get_display_state_for_viewport", viewport_size)
		_validate_quest_board_state(state)
	_free_node(panel)


func _validate_status_panel_layout() -> void:
	var panel := StatusTopMenuScene.instantiate()
	root.add_child(panel)
	await process_frame
	_force_validation_locale()
	panel.call("open_status")
	await process_frame
	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		var rect: Rect2 = panel.call("preview_layout", viewport_size)
		if rect.position.y < 70.0:
			_errors.append("Status top-menu panel should sit below the icon bar at %s." % viewport_size)
		if rect.end.x > viewport_size.x or rect.end.y > viewport_size.y:
			_errors.append("Status top-menu panel should fit inside viewport at %s." % viewport_size)
		if rect.size.x > viewport_size.x * 0.55:
			_errors.append("Status top-menu panel should not cover too much horizontal gameplay view at %s." % viewport_size)
		if rect.size.y > viewport_size.y * 0.50:
			_errors.append("Status top-menu panel should not cover too much vertical gameplay view at %s." % viewport_size)
		var state: Dictionary = panel.call("get_display_state_for_viewport", viewport_size)
		if str(state.get("title", "")).strip_edges() == "":
			_errors.append("Status panel title should not be empty.")
	_free_node(panel)


func _validate_map_panel_layout() -> void:
	var panel := MapTopMenuScene.instantiate()
	root.add_child(panel)
	await process_frame
	_force_validation_locale()
	panel.call("open_map")
	await process_frame
	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		var rect: Rect2 = panel.call("preview_layout", viewport_size)
		if rect.position.y < 70.0:
			_errors.append("Map top-menu panel should sit below the icon bar at %s." % viewport_size)
		if rect.end.x > viewport_size.x or rect.end.y > viewport_size.y:
			_errors.append("Map top-menu panel should fit inside viewport at %s." % viewport_size)
		if rect.size.x > viewport_size.x * 0.55:
			_errors.append("Map top-menu panel should not cover too much horizontal gameplay view at %s." % viewport_size)
		if rect.size.y > viewport_size.y * 0.50:
			_errors.append("Map top-menu panel should not cover too much vertical gameplay view at %s." % viewport_size)
		var state: Dictionary = panel.call("get_display_state_for_viewport", viewport_size)
		if str(state.get("title", "")).strip_edges() == "":
			_errors.append("Map panel title should not be empty.")
	_free_node(panel)


func _validate_node_first_structure() -> void:
	var panel := QuestTopMenuScene.instantiate()
	root.add_child(panel)
	await process_frame
	for path in [
		"MainPanel/PanelMargin/Content/TitleLabel",
		"MainPanel/PanelMargin/Content/HintLabel",
		"MainPanel/PanelMargin/Content/TabRow/AvailableTabButton",
		"MainPanel/PanelMargin/Content/TabRow/ActiveTabButton",
		"MainPanel/PanelMargin/Content/TabRow/CompletedTabButton",
		"MainPanel/PanelMargin/Content/Body/LeftColumn/QuestListPanel/ListMargin/ListRows/QuestScroll/QuestList",
		"MainPanel/PanelMargin/Content/Body/DetailPanel/DetailMargin/DetailRows/DetailTitleLabel",
		"MainPanel/PanelMargin/Content/Body/DetailPanel/DetailMargin/DetailRows/DetailStatusLabel",
		"MainPanel/PanelMargin/Content/Body/DetailPanel/DetailMargin/DetailRows/DetailDescriptionLabel",
		"MainPanel/PanelMargin/Content/Body/DetailPanel/DetailMargin/DetailRows/ConditionTitleLabel",
		"MainPanel/PanelMargin/Content/Body/DetailPanel/DetailMargin/DetailRows/ConditionRows",
		"MainPanel/PanelMargin/Content/Body/DetailPanel/DetailMargin/DetailRows/RewardTitleLabel",
		"MainPanel/PanelMargin/Content/Body/DetailPanel/DetailMargin/DetailRows/RewardRows",
		"MainPanel/PanelMargin/Content/Body/DetailPanel/DetailMargin/DetailRows/ActionButton",
	]:
		if panel.get_node_or_null(path) == null:
			_errors.append("Quest panel scene should provide node-first UI path: %s" % path)
	if panel.get_node_or_null("MainPanel/PanelMargin/Content/Body/LeftColumn/SortBar") != null:
		_errors.append("Quest panel should not show an unclear sort bar.")
	_free_node(panel)

	panel = StatusTopMenuScene.instantiate()
	root.add_child(panel)
	await process_frame
	for path in [
		"MainPanel/PanelMargin/Content/TitleLabel",
		"MainPanel/PanelMargin/Content/HintLabel",
		"MainPanel/PanelMargin/Content/VitalsPanel/Margin/Rows/HealthLabel",
		"MainPanel/PanelMargin/Content/VitalsPanel/Margin/Rows/StaminaLabel",
		"MainPanel/PanelMargin/Content/VitalsPanel/Margin/Rows/WeightLabel",
		"MainPanel/PanelMargin/Content/VitalsPanel/Margin/Rows/WeaponAmmoLabel",
		"MainPanel/PanelMargin/Content/EquipmentPanel/Margin/Rows/EquipmentTitleLabel",
		"MainPanel/PanelMargin/Content/EquipmentPanel/Margin/Rows/EquipmentListLabel",
	]:
		if panel.get_node_or_null(path) == null:
			_errors.append("Status panel scene should provide node-first UI path: %s" % path)
	_free_node(panel)

	panel = MapTopMenuScene.instantiate()
	root.add_child(panel)
	await process_frame
	for path in [
		"MainPanel/PanelMargin/Content/TitleLabel",
		"MainPanel/PanelMargin/Content/HintLabel",
		"MainPanel/PanelMargin/Content/InfoPanel/Margin/Rows/AreaLabel",
		"MainPanel/PanelMargin/Content/InfoPanel/Margin/Rows/ExtractionLabel",
		"MainPanel/PanelMargin/Content/InfoPanel/Margin/Rows/FlowStateLabel",
		"MainPanel/PanelMargin/Content/InfoPanel/Margin/Rows/NoteLabel",
	]:
		if panel.get_node_or_null(path) == null:
			_errors.append("Map panel scene should provide node-first UI path: %s" % path)
	_free_node(panel)


func _validate_source_boundaries() -> void:
	var ui_manager_source := FileAccess.get_file_as_string("res://scripts/ui/ui_manager.gd")
	for required in ["open_quests", "close_quests", "UI_QUESTS"]:
		if not ui_manager_source.contains(required):
			_errors.append("UIManager should own quest panel state through %s." % required)
	for required in ["open_status", "close_status", "UI_STATUS"]:
		if not ui_manager_source.contains(required):
			_errors.append("UIManager should own status panel state through %s." % required)
	for required in ["open_map", "close_map", "UI_MAP"]:
		if not ui_manager_source.contains(required):
			_errors.append("UIManager should own map panel state through %s." % required)

	var panel_source := FileAccess.get_file_as_string("res://scripts/ui/quest_top_menu_panel.gd")
	for required in ["BaseScreenViewModelScript.quest_defs", "QuestStateScript", "get_slot_data", "quest_action_requested"]:
		if not panel_source.contains(required):
			_errors.append("QuestTopMenuPanel should read quest model state through %s." % required)
	for forbidden in ["claim_reward", "save_slot_data", "RaidResultApplier", "WeaponController3D", "InventoryModel", "LootContainer3D", "LocationQuestTrigger3D", "RadioTowerQuestPoint"]:
		if panel_source.contains(forbidden):
			_errors.append("QuestTopMenuPanel should be display-only and not own gameplay state: %s." % forbidden)

	var quest_actions_source := FileAccess.get_file_as_string("res://scripts/ui/ui_manager_quest_actions.gd")
	for required in ["quest_action_requested", "QuestStateScript.accept", "QuestStateScript.claim_reward", "save_slot_data", "quest_cancel"]:
		if not ui_manager_source.contains(required) and not quest_actions_source.contains(required):
			_errors.append("UIManager should own quest action persistence through %s." % required)

	var scene_text := FileAccess.get_file_as_string("res://scenes/gameplay/player_test_world_3d.tscn")
	if not scene_text.contains("QuestTopMenuPanel"):
		_errors.append("Gameplay HUD should instance QuestTopMenuPanel.")
	if not scene_text.contains("StatusTopMenuPanel"):
		_errors.append("Gameplay HUD should instance StatusTopMenuPanel.")
	if not scene_text.contains("MapTopMenuPanel"):
		_errors.append("Gameplay HUD should instance MapTopMenuPanel.")

	panel_source = FileAccess.get_file_as_string("res://scripts/ui/status_top_menu_panel.gd")
	for required in ["get_total_max_health", "get_total_carry_weight_limit", "get_inventory_model", "get_equipment_model", "WeaponController3D"]:
		if not panel_source.contains(required):
			_errors.append("StatusTopMenuPanel should read player/equipment/weapon model state through %s." % required)
	for forbidden in ["save_slot_data", "claim_reward", "ContainerInventoryModel", "LootContainer3D", "equip_inventory_stack", "reload_equipped_weapon", "add_item_resource"]:
		if panel_source.contains(forbidden):
			_errors.append("StatusTopMenuPanel should stay display-only and not mutate gameplay state: %s." % forbidden)

	panel_source = FileAccess.get_file_as_string("res://scripts/ui/map_top_menu_panel.gd")
	for required in ["RaidSession", "ExtractionZone", "Player3D", "get_state"]:
		if not panel_source.contains(required):
			_errors.append("MapTopMenuPanel should read map/raid state through %s." % required)
	for forbidden in ["register_extraction", "register_player_death", "change_scene", "save_slot_data", "equip_inventory_stack", "reload_equipped_weapon"]:
		if panel_source.contains(forbidden):
			_errors.append("MapTopMenuPanel should be display-only and not mutate flow/gameplay state: %s." % forbidden)


func _validate_quest_board_state(state: Dictionary) -> void:
	var all_quests: Array = state.get("all_quests", []) as Array
	if all_quests.size() < 3:
		_errors.append("Quest board should list multiple quests, got %d." % all_quests.size())
	if int(state.get("available_count", 0)) <= 0:
		_errors.append("Quest board should expose available quests.")
	if str(state.get("active_category", "")) == "":
		_errors.append("Quest board should track the selected category.")
	var selected: Dictionary = state.get("selected_quest", {}) as Dictionary
	if selected.is_empty():
		_errors.append("Quest board should select a quest and show its detail.")
	if str(state.get("detail_title", "")).strip_edges() == "":
		_errors.append("Quest detail should show the selected quest name.")
	if (state.get("conditions", []) as Array).is_empty():
		_errors.append("Quest detail should show quest conditions.")
	if (state.get("rewards", []) as Array).is_empty():
		_errors.append("Quest detail should show rewards.")
	var text := "%s\n%s\n%s\n%s\n%s\n%s" % [
		state.get("title", ""),
		state.get("hint", ""),
		state.get("detail_title", ""),
		state.get("description", ""),
		"\n".join(state.get("conditions", []) as Array),
		"\n".join(state.get("rewards", []) as Array),
	]
	for token in ["Quest List", "Track current", "Active", "Ready", "Completed", "Accept Quest"]:
		if text.contains(token) or str(state.get("action_text", "")).contains(token):
			_errors.append("Quest top-menu panel should not show English fallback text.")


func _validate_quest_panel_english_locale(localization: Node) -> void:
	localization.call("set_game_locale", "en")
	var settings := root.get_node_or_null("GameSettings")
	if settings != null:
		settings.set("language_locale", "en")
	TranslationServer.set_locale("en")
	await process_frame
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	TranslationServer.set_locale("en")
	var ui_manager := root.get_node_or_null("UIManager")
	var quest_panel := scene.get_node_or_null("HUD/QuestTopMenuPanel")
	if ui_manager == null or quest_panel == null:
		_errors.append("English quest locale validation requires UIManager and QuestTopMenuPanel.")
		_free_node(scene)
		_restore_zh_tw_locale(localization)
		return
	ui_manager.call("open_ui", &"quests")
	await process_frame
	var state: Dictionary = quest_panel.call("get_display_state")
	var text := "%s\n%s\n%s\n%s\n%s\n%s\n%s" % [
		state.get("title", ""),
		state.get("hint", ""),
		state.get("detail_title", ""),
		state.get("description", ""),
		"\n".join(state.get("conditions", []) as Array),
		"\n".join(state.get("rewards", []) as Array),
		state.get("action_text", ""),
	]
	for entry in state.get("all_quests", []) as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			var quest_entry := entry as Dictionary
			text += "\n%s\n%s\n%s" % [
				quest_entry.get("name", ""),
				quest_entry.get("description", ""),
				quest_entry.get("status", ""),
			]
	if _contains_cjk(text):
		_errors.append("English quest panel should not show Chinese quest text: %s" % text)
	for required in ["Quest List", "First Salvage", "First Scavenger Hunt", "Radio Tower Scout", "Not accepted", "Accept Quest"]:
		if not text.contains(required):
			_errors.append("English quest panel should include `%s` in `%s`." % [required, text])
	quest_panel.call("select_category", "completed")
	await process_frame
	var empty_state: Dictionary = quest_panel.call("get_display_state")
	var empty_text := "%s\n%s\n%s\n%s\n%s" % [
		empty_state.get("title", ""),
		empty_state.get("hint", ""),
		empty_state.get("detail_title", ""),
		empty_state.get("description", ""),
		empty_state.get("action_text", ""),
	]
	if _contains_cjk(empty_text):
		_errors.append("English empty quest category should not show Chinese text: %s" % empty_text)
	for required in ["No quests in this category", "Switch categories or return to base"]:
		if not empty_text.contains(required):
			_errors.append("English empty quest category should include `%s` in `%s`." % [required, empty_text])
	_free_node(scene)
	_restore_zh_tw_locale(localization)
	await process_frame


func _restore_zh_tw_locale(localization: Node) -> void:
	if localization != null:
		localization.call("set_game_locale", "zh_TW")
	var settings := root.get_node_or_null("GameSettings")
	if settings != null:
		settings.set("language_locale", "zh_TW")
	TranslationServer.set_locale("zh_TW")


func _validate_fresh_quest_action(state: Dictionary) -> void:
	if str(state.get("active_category", "")) != "available":
		_errors.append("Fresh quest board should open on the available quest tab.")
	if str(state.get("action_mode", "")) != "quest_accept":
		_errors.append("Fresh quest board should expose accept action on selected available quest.")
	if not bool(state.get("action_enabled", false)):
		_errors.append("Fresh quest board accept action should be enabled when a validation save exists.")
	var action_text := str(state.get("action_text", ""))
	if not action_text.contains("接受") and not action_text.contains("接取"):
		_errors.append("Fresh quest board action button should say it accepts quests.")


func _validate_empty_quest_tabs_are_selectable(quest_panel: Node) -> void:
	if quest_panel == null or not quest_panel.has_method("select_category") or not quest_panel.has_method("get_display_state"):
		return
	quest_panel.call("select_category", "active")
	var active_state: Dictionary = quest_panel.call("get_display_state")
	if str(active_state.get("active_category", "")) != "active":
		_errors.append("Quest board should allow selecting active tab even when it has no quests.")
	if int(active_state.get("list_count", -1)) != 0:
		_errors.append("Fresh active quest tab should be empty before accepting a quest.")
	quest_panel.call("select_category", "completed")
	var completed_state: Dictionary = quest_panel.call("get_display_state")
	if str(completed_state.get("active_category", "")) != "completed":
		_errors.append("Quest board should allow selecting completed tab even when it has no quests.")
	if int(completed_state.get("list_count", -1)) != 0:
		_errors.append("Fresh completed quest tab should be empty before claiming rewards.")
	quest_panel.call("select_category", "available")


func _validate_accepted_first_quest(save_manager: Node, quest_panel: Node) -> void:
	if save_manager == null or not save_manager.has_method("get_slot_data"):
		_errors.append("Quest action validation requires SaveGameManager.")
		return
	var save_data: Dictionary = save_manager.call("get_slot_data", 1)
	var quests: Dictionary = save_data.get("quests", {}) as Dictionary
	var quest_state: Dictionary = quests.get("first_salvage", {}) as Dictionary
	if str(quest_state.get("state", "")) != QuestStateScript.STATE_ACTIVE:
		_errors.append("Accepting from top-menu quest board should persist First Salvage as active.")
	if quest_panel.has_method("get_display_state"):
		var state: Dictionary = quest_panel.call("get_display_state")
		if str(state.get("active_category", "")) != "available":
			_errors.append("Accepted quest should leave the quest board on the available tab.")
		if str(state.get("selected_quest_id", "")) == "first_salvage":
			_errors.append("Accepted quest should leave the current tab and no longer be selected as available.")
	quest_panel.call("select_category", "active")
	quest_panel.call("select_quest", "first_salvage")
	if quest_panel.has_method("get_display_state"):
		var active_state: Dictionary = quest_panel.call("get_display_state")
		if str(active_state.get("active_category", "")) != "active":
			_errors.append("Manual active tab selection should show the active tab.")
		if str(active_state.get("selected_quest_id", "")) != "first_salvage":
			_errors.append("Accepted quest should be selectable from the active tab.")
		if str(active_state.get("action_mode", "")) != "quest_cancel":
			_errors.append("Active quest should expose a cancel action.")
		if not bool(active_state.get("action_enabled", false)):
			_errors.append("Active quest cancel action should be enabled.")


func _validate_cancelled_first_quest(save_manager: Node, quest_panel: Node) -> void:
	if save_manager == null or not save_manager.has_method("get_slot_data"):
		_errors.append("Quest cancel validation requires SaveGameManager.")
		return
	var save_data: Dictionary = save_manager.call("get_slot_data", 1)
	var quests: Dictionary = save_data.get("quests", {}) as Dictionary
	if quests.has("first_salvage"):
		_errors.append("Cancelling from top-menu quest board should remove First Salvage from active save data.")
	if quest_panel.has_method("get_display_state"):
		var state: Dictionary = quest_panel.call("get_display_state")
		if str(state.get("active_category", "")) != "active":
			_errors.append("Cancelled quest should leave the quest board on the active tab.")
		if int(state.get("list_count", -1)) != 0:
			_errors.append("Cancelled quest should leave the active tab empty when no other active quests exist.")
	quest_panel.call("select_category", "available")
	if quest_panel.has_method("get_display_state"):
		var available_state: Dictionary = quest_panel.call("get_display_state")
		if str(available_state.get("selected_quest_id", "")) != "first_salvage":
			_errors.append("Cancelled quest should be selectable again from available quests.")
		if str(available_state.get("action_mode", "")) != "quest_accept":
			_errors.append("Cancelled quest should become acceptable again.")


func _validate_status_summary(state: Dictionary) -> void:
	if str(state.get("title", "")).strip_edges() == "":
		_errors.append("Status panel title should not be empty.")
	_require_terms(str(state.get("health", "")), ["生命"], "Status panel should show health.")
	_require_terms(str(state.get("stamina", "")), ["體力"], "Status panel should show stamina.")
	_require_terms(str(state.get("weight", "")), ["負重"], "Status panel should show carry weight.")
	_require_terms(str(state.get("weapon_ammo", "")), ["武器", "彈藥", "手槍-S"], "Status panel should show weapon ammo from WeaponController.")
	_require_terms(str(state.get("equipment", "")), ["手槍-S"], "Status panel should show equipment from EquipmentModel.")
	var text := "%s\n%s\n%s\n%s\n%s\n%s" % [
		state.get("title", ""),
		state.get("hint", ""),
		state.get("health", ""),
		state.get("stamina", ""),
		state.get("weight", ""),
		state.get("equipment", ""),
	]
	for token in ["Character Status", "Health", "Stamina", "Equipment", "Weapon ammo"]:
		if text.contains(token) or str(state.get("weapon_ammo", "")).contains(token):
			_errors.append("Status top-menu panel should not show English fallback text.")


func _validate_map_summary(state: Dictionary) -> void:
	if str(state.get("title", "")).strip_edges() == "":
		_errors.append("Map panel should keep its title while body copy is removed.")
	_validate_map_body_removed(state)
	var text := "%s\n%s\n%s\n%s\n%s" % [
		state.get("title", ""),
		state.get("hint", ""),
		state.get("area", ""),
		state.get("extraction", ""),
		state.get("flow_state", ""),
	]
	for token in ["Area Map", "Current area", "Extraction direction", "In raid", "Base / raid state"]:
		if text.contains(token) or str(state.get("note", "")).contains(token):
			_errors.append("Map top-menu panel should not show English fallback text.")


func _validate_map_body_removed(state: Dictionary) -> void:
	for key in ["area", "route", "extraction", "danger", "loot", "flow_state", "note"]:
		if str(state.get(key, "")).strip_edges() != "":
			_errors.append("Map panel body field `%s` should be empty." % key)
	if bool(state.get("body_visible", true)):
		_errors.append("Map panel body container should be hidden.")


func _prepare_player_status_sample(player: Node) -> void:
	if player == null:
		return
	if player.has_method("add_item_resource"):
		player.call("add_item_resource", PistolItem, 1)
	if player.has_method("get_inventory_model"):
		var backpack: RefCounted = player.call("get_inventory_model")
		if backpack != null and backpack.has_method("get_display_items"):
			var stacks: Array = backpack.call("get_display_items")
			for index in range(stacks.size()):
				var stack: Dictionary = stacks[index]
				if str(stack.get("resource_path", "")) == PistolItem.resource_path and player.has_method("equip_inventory_stack"):
					player.call("equip_inventory_stack", index, &"sidearm")
					break
	var weapon := player.get_node_or_null("WeaponController3D")
	if weapon != null and weapon.has_method("set_reserve_ammo_from_item"):
		weapon.call("set_reserve_ammo_from_item", AmmoItem, 24)


func _force_validation_locale() -> void:
	var settings := root.get_node_or_null("GameSettings")
	if settings != null:
		settings.set("language_locale", "zh_TW")
	TranslationServer.set_locale("zh_TW")


func _prepare_save_manager(save_manager: Node) -> void:
	if save_manager == null:
		return
	if _original_save_root == "":
		_original_save_root = str(save_manager.get("save_root_path"))
	if save_manager.has_method("get_current_slot_index"):
		_original_slot = int(save_manager.call("get_current_slot_index"))
	save_manager.set("save_root_path", VALIDATION_SAVE_ROOT)
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	if save_manager.has_method("set_current_slot_index"):
		save_manager.call("set_current_slot_index", 1)
	if save_manager.has_method("save_slot_data"):
		save_manager.call("save_slot_data", 1, {
			"difficulty_id": "normal",
			"money": 0,
			"stash": [],
			"base_upgrades": {},
			"quests": {},
		})


func _restore_save_manager(save_manager: Node) -> void:
	if save_manager == null:
		return
	if _original_save_root != "":
		save_manager.set("save_root_path", _original_save_root)
	if save_manager.has_method("set_current_slot_index"):
		save_manager.call("set_current_slot_index", _original_slot)


func _cleanup_validation_root(root_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(root_path)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute("%s/slot_1.json" % absolute)
		DirAccess.remove_absolute("%s/slot_2.json" % absolute)
		DirAccess.remove_absolute("%s/slot_3.json" % absolute)
		DirAccess.remove_absolute(absolute)


func _require_terms(text: String, terms: Array[String], message: String) -> void:
	for term in terms:
		if not text.contains(term):
			_errors.append("%s Missing `%s` in `%s`." % [message, term, text])


func _contains_cjk(text: String) -> bool:
	for codepoint in text.to_utf32_buffer():
		if (codepoint >= 0x3400 and codepoint <= 0x9FFF) or (codepoint >= 0xF900 and codepoint <= 0xFAFF):
			return true
	return false


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
