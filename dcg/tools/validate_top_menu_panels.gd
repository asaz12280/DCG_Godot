extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const QuestTopMenuScene := preload("res://scenes/ui/quest_top_menu_panel.tscn")
const QuestTopMenuScript := preload("res://scripts/ui/quest_top_menu_panel.gd")
const StatusTopMenuScene := preload("res://scenes/ui/status_top_menu_panel.tscn")
const StatusTopMenuScript := preload("res://scripts/ui/status_top_menu_panel.gd")
const MapTopMenuScene := preload("res://scenes/ui/map_top_menu_panel.tscn")
const MapTopMenuScript := preload("res://scripts/ui/map_top_menu_panel.gd")
const PistolItem := preload("res://data/items/weapons/pistol_9mm.tres")
const AmmoItem := preload("res://data/items/ammo/ammo_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_quest_tab_opens_panel()
	await _validate_status_tab_opens_panel()
	await _validate_map_tab_opens_panel()
	await _validate_quest_panel_layout()
	await _validate_status_panel_layout()
	await _validate_map_panel_layout()
	_validate_node_first_structure()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[top_menu_panels] OK quests_tab=opens status_tab=player_model map_tab=area_extract list=salvage_hunt layout=fit ui_manager=owns_state boundaries=clean")
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


func _validate_status_tab_opens_panel() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

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


func _validate_status_panel_layout() -> void:
	var panel := StatusTopMenuScene.instantiate()
	root.add_child(panel)
	await process_frame
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
		_require_terms(str(state.get("title", "")), ["角色", "狀態"], "Status panel title should be Traditional Chinese.")
	_free_node(panel)


func _validate_map_panel_layout() -> void:
	var panel := MapTopMenuScene.instantiate()
	root.add_child(panel)
	await process_frame
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
		_require_terms(str(state.get("title", "")), ["區域", "地圖"], "Map panel title should be Traditional Chinese.")
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
	for required in ["QuestTopMenuPanel", "open_quests", "close_quests", "UI_QUESTS"]:
		if not ui_manager_source.contains(required):
			_errors.append("UIManager should own quest panel state through %s." % required)
	for required in ["StatusTopMenuPanel", "open_status", "close_status", "UI_STATUS"]:
		if not ui_manager_source.contains(required):
			_errors.append("UIManager should own status panel state through %s." % required)
	for required in ["MapTopMenuPanel", "open_map", "close_map", "UI_MAP"]:
		if not ui_manager_source.contains(required):
			_errors.append("UIManager should own map panel state through %s." % required)

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


func _validate_status_summary(state: Dictionary) -> void:
	_require_terms(str(state.get("title", "")), ["角色", "狀態"], "Status panel title should be Traditional Chinese.")
	_require_terms(str(state.get("health", "")), ["生命"], "Status panel should show health.")
	_require_terms(str(state.get("stamina", "")), ["體力"], "Status panel should show stamina.")
	_require_terms(str(state.get("weight", "")), ["負重"], "Status panel should show carry weight.")
	_require_terms(str(state.get("weapon_ammo", "")), ["武器", "彈藥", "手槍-S"], "Status panel should show weapon ammo from WeaponController.")
	_require_terms(str(state.get("equipment", "")), ["副武器", "手槍-S"], "Status panel should show equipment from EquipmentModel.")
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
	_require_terms(str(state.get("title", "")), ["區域", "地圖"], "Map panel title should be Traditional Chinese.")
	_require_terms(str(state.get("area", "")), ["目前區域", "避難郊區"], "Map panel should show current area.")
	_require_terms(str(state.get("extraction", "")), ["撤離方向", "撤離點"], "Map panel should show extraction direction.")
	_require_terms(str(state.get("flow_state", "")), ["基地", "出擊", "出擊中"], "Map panel should show base/raid state.")
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
