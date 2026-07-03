extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const BaseScreenScene := preload("res://scenes/base/base_screen.tscn")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const RaidHudScene := preload("res://scenes/ui/raid_hud_panel.tscn")
const RaidResultScene := preload("res://scenes/ui/raid_result_panel.tscn")
const ContainerInventoryScene := preload("res://scenes/ui/container_inventory_ui.tscn")
const QuestTopMenuScene := preload("res://scenes/ui/quest_top_menu_panel.tscn")
const StatusTopMenuScene := preload("res://scenes/ui/status_top_menu_panel.tscn")
const MapTopMenuScene := preload("res://scenes/ui/map_top_menu_panel.tscn")

const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const ContainerInventoryModelScript := preload("res://scripts/inventory/container_inventory_model.gd")
const UITextScript := preload("res://scripts/ui/ui_text.gd")
const UILayoutScript := preload("res://scripts/ui/ui_layout.gd")

const WoodItem := preload("res://data/items/crafting/wood.tres")
const JunkItem := preload("res://data/items/loot/junk.tres")
const PistolItem := preload("res://data/items/weapons/pistol_9mm.tres")
const AmmoItem := preload("res://data/items/ammo/ammo_9mm.tres")

const VIEWPORTS: Array[Vector2] = [
	Vector2(1280.0, 720.0),
	Vector2(1920.0, 1080.0),
]

const MIN_BUTTON_HEIGHT := 44.0
const MIN_SAFE_MARGIN := 20.0

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_base_screen()
	await _validate_base_3d_station_ui()
	await _validate_gameplay_hud_cluster()
	await _validate_top_menu_panels()
	await _validate_inventory_equipment()
	await _validate_container_inventory()
	await _validate_raid_result()
	_validate_scene_ownership_boundaries()
	if _errors.is_empty():
		print("[ui_layout_quality_0_2] OK viewports=1280x720,1920x1080 base=fit raid=fit inventory=fit container=fit top_menu=fit text=zh boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_base_screen() -> void:
	var save_manager := _make_save_manager("user://validation_ui_layout_quality_0_2_base")
	save_manager.call("set_current_slot_index", 1)
	save_manager.call("save_slot_data", 1, {
		"difficulty_id": "normal",
		"money": 80,
		"stash": [
			{"item_path": WoodItem.resource_path, "quantity": 3},
			{"item_path": JunkItem.resource_path, "quantity": 2},
		],
		"base_upgrades": {},
		"quests": {},
	})
	for viewport_size in VIEWPORTS:
		_set_root_viewport(viewport_size)
		var screen := BaseScreenScene.instantiate() as Control
		root.add_child(screen)
		screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
		screen.size = viewport_size
		await process_frame
		screen.call("refresh")
		await process_frame
		var state: Dictionary = screen.call("get_display_state")
		_assert_rect_inside(state.get("panel_rect", Rect2()), viewport_size, "Base screen panel")
		_assert_rect_inside(state.get("phase_banner_rect", Rect2()), viewport_size, "Base screen phase banner")
		_assert_rect_inside(state.get("start_button_rect", Rect2()), viewport_size, "Base screen start button")
		_assert_button_rect(state.get("start_button_rect", Rect2()), "Base screen start button")
		_assert_button_rect(state.get("sell_button_rect", Rect2()), "Base screen sell button")
		_assert_panel_not_dominating(state.get("panel_rect", Rect2()), viewport_size, "Base screen panel", 0.86, 0.92)
		_assert_no_english_fallback_tree(screen, "Base screen")
		_free_node(screen)
	_free_node(save_manager)


func _validate_base_3d_station_ui() -> void:
	for viewport_size in VIEWPORTS:
		_set_root_viewport(viewport_size)
		var save_manager := _make_save_manager("user://validation_ui_layout_quality_0_2_base3d")
		save_manager.call("set_current_slot_index", 1)
		save_manager.call("save_slot_data", 1, {
			"difficulty_id": "normal",
			"money": 30,
			"stash": [{"item_path": WoodItem.resource_path, "quantity": 4}],
			"base_upgrades": {},
			"quests": {},
		})
		var scene := Base3DScene.instantiate()
		root.add_child(scene)
		await process_frame
		await process_frame
		var controller := scene.get_node_or_null("BaseInteractionController3D")
		var panel := scene.get_node_or_null("HUD/BaseInteractionPanel") as Control
		var stash_panel := scene.get_node_or_null("HUD/BaseStashInventoryUI") as Control
		if controller == null or panel == null or stash_panel == null:
			_errors.append("Base 3D scene should expose interaction controller, station panel, and stash storage panel.")
			_free_node(scene)
			_free_node(save_manager)
			continue
		if not bool(controller.call("open_interaction_by_id", "stash")):
			_errors.append("Base 3D should open stash storage UI.")
		else:
			await process_frame
			var stash_state: Dictionary = stash_panel.call("get_display_state_for_viewport", viewport_size)
			_assert_rect_inside(stash_state.get("left_panel_rect", Rect2()), viewport_size, "Base 3D stash loadout panel")
			_assert_rect_inside(stash_state.get("right_panel_rect", Rect2()), viewport_size, "Base 3D stash warehouse panel")
			_assert_rect_inside(stash_state.get("stash_grid_rect", Rect2()), viewport_size, "Base 3D stash grid")
			_assert_rect_inside(stash_state.get("backpack_grid_rect", Rect2()), viewport_size, "Base 3D stash backpack grid")
			_assert_visible_text_not_empty(stash_state, ["title", "status_text"], "Base 3D stash")
			if stash_panel.has_method("close_stash"):
				stash_panel.call("close_stash")
		for interaction_id in ["workbench", "medical"]:
			if not bool(controller.call("open_interaction_by_id", interaction_id)):
				_errors.append("Base 3D should open interaction panel for %s." % interaction_id)
				continue
			await process_frame
			var panel_rect := _global_rect_or_fallback(panel.get_node_or_null("%Panel") as Control, Rect2(Vector2(360.0, 180.0), Vector2(560.0, 240.0)))
			_assert_rect_inside(panel_rect, viewport_size, "Base 3D %s panel" % interaction_id)
			_assert_panel_not_dominating(panel_rect, viewport_size, "Base 3D %s panel" % interaction_id, 0.74, 0.62)
			_assert_no_english_fallback_tree(panel, "Base 3D %s panel" % interaction_id)
			if panel.has_method("close_panel"):
				panel.call("close_panel")
		_free_node(scene)
		_free_node(save_manager)


func _validate_gameplay_hud_cluster() -> void:
	for viewport_size in VIEWPORTS:
		_set_root_viewport(viewport_size)
		var scene := GameplayScene.instantiate()
		root.add_child(scene)
		await process_frame
		await process_frame
		var hud := scene.get_node_or_null("HUD/RaidHudPanel")
		var top_menu := scene.get_node_or_null("HUD/TopMenuBar") as Control
		var player_hud := scene.get_node_or_null("HUD/PlayerHud3D") as Control
		var pause_menu := scene.get_node_or_null("HUD/PauseMenu") as Control
		if hud == null or top_menu == null or player_hud == null or pause_menu == null:
			_errors.append("Gameplay HUD should include RaidHudPanel, TopMenuBar, PlayerHud3D, and PauseMenu.")
			_free_node(scene)
			continue
		var hud_rect: Rect2 = hud.call("preview_layout", viewport_size)
		_assert_rect_inside(hud_rect, viewport_size, "Raid HUD panel")
		_assert_panel_not_dominating(hud_rect, viewport_size, "Raid HUD panel", 0.34, 0.30)
		var top_menu_rect: Rect2 = UILayoutScript.centered_top_rect(viewport_size, Vector2(700.0, 84.0), 20.0, 0.75, 1.1)
		_assert_rect_inside(top_menu_rect, viewport_size, "Top menu bar")
		if top_menu_rect.position.y > 32.0:
			_errors.append("Top menu bar should remain near the top edge at %s." % viewport_size)
		var player_hud_state: Dictionary = player_hud.call("get_display_state") if player_hud.has_method("get_display_state") else {}
		_assert_visible_text_not_empty(player_hud_state, ["health_text"], "Player HUD")
		_free_node(scene)


func _validate_top_menu_panels() -> void:
	var configs := [
		{"scene": QuestTopMenuScene, "open": "open_quests", "name": "Quest top-menu panel", "max_y": 0.70},
		{"scene": StatusTopMenuScene, "open": "open_status", "name": "Status top-menu panel", "max_y": 0.56},
		{"scene": MapTopMenuScene, "open": "open_map", "name": "Map top-menu panel", "max_y": 0.56},
	]
	for config in configs:
		var packed_scene: PackedScene = config.get("scene")
		var panel := packed_scene.instantiate() as Control
		root.add_child(panel)
		await process_frame
		panel.call(str(config.get("open")))
		await process_frame
		for viewport_size in VIEWPORTS:
			var rect: Rect2 = panel.call("preview_layout", viewport_size)
			_assert_rect_inside(rect, viewport_size, str(config.get("name")))
			if rect.position.y < 70.0:
				_errors.append("%s should sit below the top icon bar at %s." % [config.get("name"), viewport_size])
			_assert_panel_not_dominating(rect, viewport_size, str(config.get("name")), 0.56, float(config.get("max_y")))
			var state: Dictionary = panel.call("get_display_state_for_viewport", viewport_size)
			_assert_visible_text_not_empty(state, ["title", "hint"], str(config.get("name")))
		_assert_no_english_fallback_tree(panel, str(config.get("name")))
		_free_node(panel)


func _validate_inventory_equipment() -> void:
	for viewport_size in VIEWPORTS:
		_set_root_viewport(viewport_size)
		var scene := GameplayScene.instantiate()
		root.add_child(scene)
		await process_frame
		await process_frame
		var player := scene.get_node_or_null("Player3D")
		var inventory := scene.get_node_or_null("HUD/InventoryEquipmentUI") as Control
		if player == null or inventory == null:
			_errors.append("Gameplay scene should expose Player3D and InventoryEquipmentUI.")
			_free_node(scene)
			continue
		if player.has_method("add_item_resource"):
			player.call("add_item_resource", PistolItem, 1)
			player.call("add_item_resource", AmmoItem, 24)
		inventory.call("open_inventory")
		await process_frame
		var state: Dictionary = inventory.call("get_display_state_for_viewport", viewport_size)
		var panel_rect: Rect2 = state.get("panel_rect", Rect2())
		_assert_rect_inside(panel_rect, viewport_size, "Inventory equipment panel")
		_assert_panel_not_dominating(panel_rect, viewport_size, "Inventory equipment panel", 0.54, 0.96)
		if int(state.get("backpack_slots", 0)) < 20:
			_errors.append("Inventory should expose enough visible backpack slots for the slice.")
		var slot_rects: Dictionary = state.get("equipment_slot_rects", {})
		for required_slot in ["primary_weapon", "sidearm"]:
			if not slot_rects.has(required_slot):
				_errors.append("Inventory should expose equipment slot rect for %s." % required_slot)
			else:
				_assert_rect_inside(slot_rects[required_slot], viewport_size, "Inventory equipment slot %s" % required_slot)
		_assert_no_english_fallback_tree(inventory, "Inventory equipment panel")
		_free_node(scene)


func _validate_container_inventory() -> void:
	for viewport_size in VIEWPORTS:
		_set_root_viewport(viewport_size)
		var model := ContainerInventoryModelScript.new(4)
		model.call("add_item", PistolItem, 1)
		model.call("add_item", AmmoItem, 24)
		var panel := ContainerInventoryScene.instantiate() as Control
		root.add_child(panel)
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.size = viewport_size
		await process_frame
		panel.call("open_container", model, "愛心箱")
		await process_frame
		var state: Dictionary = panel.call("get_display_state")
		_assert_rect_inside(state.get("panel_rect", Rect2()), viewport_size, "Container inventory panel")
		_assert_rect_inside(state.get("scroll_rect", Rect2()), viewport_size, "Container inventory slot grid")
		_assert_panel_not_dominating(state.get("panel_rect", Rect2()), viewport_size, "Container inventory panel", 0.44, 0.50)
		if int(state.get("slot_count", 0)) != 4:
			_errors.append("Container inventory should expose one visible slot per capacity.")
		if str(state.get("capacity", "")) != "2/4":
			_errors.append("Container inventory should show used/capacity text like 2/4.")
		_assert_button_rect(_global_rect_or_fallback(panel.get_node_or_null("%CloseButton") as Control, Rect2()), "Container close button")
		_assert_no_english_fallback_tree(panel, "Container inventory panel")
		_free_node(panel)


func _validate_raid_result() -> void:
	for viewport_size in VIEWPORTS:
		_set_root_viewport(viewport_size)
		var panel := RaidResultScene.instantiate() as Control
		root.add_child(panel)
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.size = viewport_size
		await process_frame
		panel.call("show_result", {
			"outcome": "extracted",
			"duration": 98.0,
			"money_delta": 18,
			"extracted_items": [{"item_path": PistolItem.resource_path, "quantity": 1}],
			"lost_items": [],
			"kept_safe_pocket_items": [],
		})
		panel.call("_layout_panel")
		await process_frame
		var state: Dictionary = panel.call("get_display_state")
		_assert_rect_inside(state.get("panel_rect", Rect2()), viewport_size, "Raid result panel")
		_assert_rect_inside(state.get("transfer_rect", Rect2()), viewport_size, "Raid result transfer banner")
		_assert_rect_inside(state.get("button_rect", Rect2()), viewport_size, "Raid result continue button")
		_assert_button_rect(state.get("button_rect", Rect2()), "Raid result continue button")
		_assert_panel_not_dominating(state.get("panel_rect", Rect2()), viewport_size, "Raid result panel", 0.86, 1.0)
		_assert_visible_text_not_empty(state, ["title", "transfer_title", "continue_text"], "Raid result")
		_assert_no_english_fallback_tree(panel, "Raid result panel")
		_free_node(panel)


func _validate_scene_ownership_boundaries() -> void:
	var gameplay_scene := FileAccess.get_file_as_string("res://scenes/gameplay/player_test_world_3d.tscn")
	for required in ["RaidHudPanel", "ContainerInventoryUI", "InventoryEquipmentUI", "QuestTopMenuPanel", "StatusTopMenuPanel", "MapTopMenuPanel", "PauseMenu"]:
		if not gameplay_scene.contains(required):
			_errors.append("Gameplay scene should keep player-visible UI node in scene: %s." % required)
	var base_scene := FileAccess.get_file_as_string("res://scenes/base/base_3d.tscn")
	for required in ["BaseInteractionPanel", "BaseStashInventoryUI", "TopMenuBar", "InventoryEquipmentUI", "PauseMenu"]:
		if not base_scene.contains(required):
			_errors.append("Base 3D scene should keep player-visible UI node in scene: %s." % required)
	var ui_manager_source := FileAccess.get_file_as_string("res://scripts/ui/ui_manager.gd")
	for required in ["UI_BACKPACK", "UI_PAUSE", "UI_CONTAINER", "UI_QUESTS", "UI_STATUS", "UI_MAP"]:
		if not ui_manager_source.contains(required):
			_errors.append("UIManager should own gameplay UI state id: %s." % required)


func _assert_rect_inside(rect: Rect2, viewport_size: Vector2, label: String) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_errors.append("%s should have a positive layout size." % label)
		return
	if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > viewport_size.x + 1.0 or rect.end.y > viewport_size.y + 1.0:
		_errors.append("%s should fit inside %s, got %s." % [label, viewport_size, rect])


func _assert_panel_not_dominating(rect: Rect2, viewport_size: Vector2, label: String, max_width_ratio: float, max_height_ratio: float) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	if rect.size.x > viewport_size.x * max_width_ratio:
		_errors.append("%s should not cover too much horizontal gameplay view at %s." % [label, viewport_size])
	if rect.size.y > viewport_size.y * max_height_ratio:
		_errors.append("%s should not cover too much vertical gameplay view at %s." % [label, viewport_size])


func _assert_button_rect(rect: Rect2, label: String) -> void:
	if rect.size.y < MIN_BUTTON_HEIGHT:
		_errors.append("%s should be at least %.0fpx tall, got %.1f." % [label, MIN_BUTTON_HEIGHT, rect.size.y])
	if rect.size.x < 80.0:
		_errors.append("%s should have enough width for Traditional Chinese text, got %.1f." % [label, rect.size.x])


func _assert_button_size(size: Vector2, label: String) -> void:
	if size.y < MIN_BUTTON_HEIGHT:
		_errors.append("%s should be at least %.0fpx tall, got %.1f." % [label, MIN_BUTTON_HEIGHT, size.y])
	if size.x < 120.0:
		_errors.append("%s should have enough width for Traditional Chinese text, got %.1f." % [label, size.x])


func _assert_visible_text_not_empty(state: Dictionary, keys: Array[String], label: String) -> void:
	for key in keys:
		var text := str(state.get(key, "")).strip_edges()
		if text == "":
			_errors.append("%s should expose visible text for `%s`." % [label, key])
		elif _looks_like_english_fallback(text):
			_errors.append("%s should not expose English fallback text for `%s`: %s" % [label, key, text])


func _assert_no_english_fallback_tree(node: Node, label: String) -> void:
	if node is Label:
		_assert_text_quality((node as Label).text, "%s/%s" % [label, node.name])
	elif node is Button:
		_assert_text_quality((node as Button).text, "%s/%s" % [label, node.name])
	for child in node.get_children():
		_assert_no_english_fallback_tree(child, label)


func _assert_text_quality(text: String, label: String) -> void:
	if text.strip_edges() == "":
		return
	if UITextScript.looks_corrupt(text):
		_errors.append("%s should not display mojibake text: %s" % [label, text])
	if _looks_like_english_fallback(text):
		_errors.append("%s should not display English fallback text: %s" % [label, text])


func _looks_like_english_fallback(text: String) -> bool:
	if text == "":
		return false
	var has_cjk := false
	for codepoint in text.to_utf32_buffer():
		if (codepoint >= 0x3400 and codepoint <= 0x9FFF) or (codepoint >= 0xF900 and codepoint <= 0xFAFF):
			has_cjk = true
			break
	if has_cjk:
		return false
	for token in [
		"Base",
		"Raid",
		"Container",
		"Inventory",
		"Quest",
		"Status",
		"Map",
		"Close",
		"Start",
		"Cancel",
		"Extraction Zone",
		"Weapon",
		"Ammo",
		"Health",
		"Stamina",
	]:
		if text.contains(token):
			return true
	return false


func _global_rect_or_fallback(control: Control, fallback: Rect2) -> Rect2:
	if control == null:
		return fallback
	return control.get_global_rect()


func _make_save_manager(save_root_path: String) -> Node:
	var existing := root.get_node_or_null("SaveGameManager")
	if existing != null:
		_free_node(existing)
	var save_manager := SaveGameManagerScript.new()
	save_manager.name = "SaveGameManager"
	save_manager.set("save_root_path", save_root_path)
	root.add_child(save_manager)
	_cleanup_validation_root(save_root_path)
	return save_manager


func _cleanup_validation_root(root_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(root_path)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute("%s/slot_1.json" % absolute)
		DirAccess.remove_absolute("%s/slot_2.json" % absolute)
		DirAccess.remove_absolute("%s/slot_3.json" % absolute)
		DirAccess.remove_absolute(absolute)


func _set_root_viewport(viewport_size: Vector2) -> void:
	root.size = Vector2i(int(viewport_size.x), int(viewport_size.y))


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
