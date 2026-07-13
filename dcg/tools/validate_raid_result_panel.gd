extends SceneTree

const RaidResultPanelScene := preload("res://scenes/ui/raid_result_panel.tscn")
const RaidResultPanelScript := preload("res://scripts/ui/raid_result_panel.gd")
const UITextScript := preload("res://scripts/ui/ui_text.gd")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")

const VALIDATION_SAVE_ROOT := "user://validation_raid_result_panel"
const WOOD_PATH := "res://data/items/crafting/wood.tres"

var _errors: Array[String] = []
var _continue_signal_seen := false
var _save_manager: Node = null
var _created_save_manager := false


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_setup_save_manager()
	await _validate_extracted_result_display()
	await _validate_dead_result_display()
	await _validate_layout_fit()
	await _validate_gameplay_scene_wiring()
	_validate_script_boundaries()
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	if _created_save_manager:
		_free_node(_save_manager)
	if _errors.is_empty():
		print("[raid_result_panel] OK node_first=true extracted_vs_dead=clear transfer=visible loot=shown continue=base_stash layout=fits boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_extracted_result_display() -> void:
	var panel := _make_panel()
	await process_frame
	panel.show_result(_extracted_result())
	await process_frame
	var state: Dictionary = panel.get_display_state()
	if not bool(state.get("visible", false)):
		_errors.append("RaidResultPanel should become visible after show_result().")
	if str(state.get("title", "")) != "行動結算":
		_errors.append("RaidResultPanel title should be readable Traditional Chinese.")
	if not str(state.get("outcome", "")).contains("撤離成功"):
		_errors.append("RaidResultPanel should show extracted outcome in Traditional Chinese.")
	if not str(state.get("outcome", "")).contains("帶回物資"):
		_errors.append("RaidResultPanel extracted outcome should tell the player supplies were secured.")
	if int(state.get("extracted_rows", 0)) < 2:
		_errors.append("RaidResultPanel should show extracted item rows.")
	_validate_visible_transfer_summary(state, true)
	_validate_list_titles(state)
	if str(state.get("continue_text", "")) != "回到基地":
		_errors.append("RaidResultPanel continue button should clearly say 回到基地.")
	_continue_signal_seen = false
	panel.continue_to_base_requested.connect(_on_continue_to_base_requested)
	panel.continue_button.pressed.emit()
	if not _continue_signal_seen:
		_errors.append("RaidResultPanel should emit user intent before returning to Base.")
	if str(panel.BASE_SCENE) != "res://scenes/base/base_3d.tscn":
		_errors.append("RaidResultPanel should continue to the 3D Base scene.")
	if not ResourceLoader.exists(panel.BASE_SCENE):
		_errors.append("RaidResultPanel Base destination scene should exist.")
	await _wait_process_frames(8)
	_validate_continue_opens_stash_page()
	_free_current_scene()
	_close_ui_manager()
	_free_node(panel)


func _validate_dead_result_display() -> void:
	var panel := _make_panel()
	await process_frame
	panel.show_result(_dead_result())
	await process_frame
	var state: Dictionary = panel.get_display_state()
	if not str(state.get("outcome", "")).contains("行動失敗"):
		_errors.append("RaidResultPanel should show death outcome in Traditional Chinese.")
	if not str(state.get("outcome", "")).contains("死亡"):
		_errors.append("RaidResultPanel death outcome should clearly say the action failed.")
	if int(state.get("lost_rows", 0)) < 1:
		_errors.append("RaidResultPanel should show lost item rows on death.")
	if int(state.get("safe_pocket_rows", 0)) < 1:
		_errors.append("RaidResultPanel should show kept safe pocket rows on death.")
	_validate_visible_transfer_summary(state, false)
	_free_node(panel)


func _validate_layout_fit() -> void:
	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		root.content_scale_size = Vector2i(int(viewport_size.x), int(viewport_size.y))
		root.size = Vector2i(int(viewport_size.x), int(viewport_size.y))
		var panel := _make_panel()
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.size = viewport_size
		await process_frame
		panel.show_result(_extracted_result())
		panel.size = viewport_size
		await process_frame
		var state: Dictionary = panel.get_display_state()
		var panel_rect := state.get("panel_rect") as Rect2
		var transfer_rect := state.get("transfer_rect") as Rect2
		var button_rect := state.get("button_rect") as Rect2
		if panel_rect.position.x < 32.0 and viewport_size.x >= 1280.0:
			_errors.append("RaidResultPanel should keep a clear safe margin at %s." % viewport_size)
		if panel_rect.end.x > viewport_size.x or panel_rect.end.y > viewport_size.y:
			_errors.append("RaidResultPanel should fit inside %s." % viewport_size)
		if transfer_rect.size.y < 56.0:
			_errors.append("RaidResultPanel transfer banner should be readable at %s." % viewport_size)
		if not panel_rect.encloses(transfer_rect):
			_errors.append("RaidResultPanel transfer banner should stay inside the panel at %s." % viewport_size)
		if button_rect.size.x < 220.0 or button_rect.size.y < 44.0:
			_errors.append("RaidResultPanel continue button should meet early button size rules.")
		if button_rect.end.x > viewport_size.x or button_rect.end.y > viewport_size.y:
			_errors.append("RaidResultPanel continue button should stay inside the viewport at %s." % viewport_size)
		if not panel_rect.encloses(button_rect):
			_errors.append("RaidResultPanel continue button should stay inside the main panel at %s." % viewport_size)
		_free_node(panel)


func _validate_gameplay_scene_wiring() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	var panel := scene.get_node_or_null("HUD/RaidResultPanel")
	if panel == null:
		_errors.append("Gameplay scene should include HUD/RaidResultPanel.")
	elif panel.get_script() != RaidResultPanelScript:
		_errors.append("Gameplay RaidResultPanel should use the RaidResultPanel script.")
	else:
		var session := scene.get_node_or_null("RaidSession")
		if session == null:
			_errors.append("Gameplay scene should include RaidSession for result panel binding.")
		elif not session.raid_completed.is_connected(panel.show_result):
			_errors.append("Gameplay RaidResultPanel should connect to RaidSession.raid_completed.")
	_free_node(scene)


func _validate_visible_transfer_summary(state: Dictionary, extracted: bool) -> void:
	if str(state.get("transfer_title", "")) != "物資轉移":
		_errors.append("RaidResultPanel should show a visible transfer summary title.")
	var detail := str(state.get("transfer_detail", ""))
	if not detail.contains("回到基地"):
		_errors.append("RaidResultPanel transfer detail should mention returning to base.")
	if extracted:
		for expected in ["背包", "手動整理"]:
			if not detail.contains(expected):
				_errors.append("RaidResultPanel extracted transfer detail should mention `%s`." % expected)
		var status := str(state.get("status", ""))
		if not status.contains("背包") or not status.contains("手動整理"):
			_errors.append("RaidResultPanel status should explain extracted supplies stay in the backpack for manual stash organization.")
	else:
		for expected in ["行動失敗", "遺失", "安全口袋"]:
			if not detail.contains(expected):
				_errors.append("RaidResultPanel death transfer detail should mention `%s`." % expected)
		if not str(state.get("status", "")).contains("遺失物品"):
			_errors.append("RaidResultPanel death status should explain lost items.")


func _validate_list_titles(state: Dictionary) -> void:
	if str(state.get("extracted_title", "")) != "帶回物品":
		_errors.append("RaidResultPanel should label extracted items in Traditional Chinese.")
	if str(state.get("lost_title", "")) != "遺失物品":
		_errors.append("RaidResultPanel should label lost items in Traditional Chinese.")
	if str(state.get("safe_pocket_title", "")) != "安全口袋":
		_errors.append("RaidResultPanel should label safe pocket items in Traditional Chinese.")


func _validate_script_boundaries() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/raid_result_panel.gd")
	if UITextScript.looks_corrupt(source):
		_errors.append("RaidResultPanel source should not contain mojibake fallback text.")
	if source.contains("SaveGameManager") or source.contains("StashModel"):
		_errors.append("RaidResultPanel should not directly mutate save or stash state.")
	if source.contains("open_stash") or source.contains("BaseStashInventoryUI"):
		_errors.append("RaidResultPanel should not open or reference the stash UI directly.")
	if not source.contains("open_ui_on_next_scene"):
		_errors.append("RaidResultPanel should request the post-extraction Base stash page through UIManager.")
	if source.contains("base_screen.tscn"):
		_errors.append("RaidResultPanel should not route normal player flow back to the old 2D BaseScreen.")
	if not source.contains("change_scene_to_file(BASE_SCENE)"):
		_errors.append("RaidResultPanel should route Continue to Base through the configured scene path.")
	var localization_source := FileAccess.get_file_as_string("res://data/localization/game_text.csv")
	if not localization_source.contains("保留在背包") or not localization_source.contains("手動整理進倉庫"):
		_errors.append("RaidResultPanel localization should mention backpack return and manual stash organization.")


func _validate_continue_opens_stash_page() -> void:
	if current_scene == null:
		_errors.append("RaidResultPanel Continue should load the Base scene.")
		return
	if current_scene.scene_file_path != "res://scenes/base/base_3d.tscn":
		_errors.append("RaidResultPanel Continue should leave the player in base_3d.tscn.")
	var stash_panel := current_scene.get_node_or_null("HUD/BaseStashInventoryUI")
	if stash_panel == null:
		_errors.append("Base scene should contain HUD/BaseStashInventoryUI for post-extraction transfer review.")
		return
	var ui_manager := root.get_node_or_null("UIManager")
	if ui_manager == null or str(ui_manager.call("get_active_ui")) != "stash":
		_errors.append("RaidResultPanel Continue should leave UIManager in the stash page after extraction.")
	if not stash_panel.has_method("is_open") or not bool(stash_panel.call("is_open")):
		_errors.append("RaidResultPanel Continue should auto-open the warehouse UI after extraction.")
	if stash_panel is CanvasItem and not (stash_panel as CanvasItem).visible:
		_errors.append("RaidResultPanel Continue should make the warehouse UI visible after extraction.")
	var state: Dictionary = stash_panel.call("get_display_state") if stash_panel.has_method("get_display_state") else {}
	if _stack_quantity(state.get("stash_items", []) as Array, WOOD_PATH) <= 0:
		_errors.append("Auto-opened warehouse page should show saved stash items.")


func _setup_save_manager() -> void:
	_save_manager = root.get_node_or_null("SaveGameManager")
	if _save_manager == null:
		_save_manager = SaveGameManagerScript.new()
		_save_manager.name = "SaveGameManager"
		root.add_child(_save_manager)
		_created_save_manager = true
	_save_manager.set("save_root_path", VALIDATION_SAVE_ROOT)
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	_save_manager.call("set_current_slot_index", 1)
	_save_manager.call("save_slot_data", 1, {
		"difficulty_id": "normal",
		"scene_path": "res://scenes/base/base_3d.tscn",
		"money": 0,
		"stash": [{"item_path": WOOD_PATH, "quantity": 3}],
		"base_upgrades": {},
		"quests": {},
	})


func _stack_quantity(stacks: Array, item_path: String) -> int:
	var total := 0
	for value in stacks:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := value as Dictionary
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path:
			total += int(stack.get("quantity", 0))
	return total


func _cleanup_validation_root(root_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(root_path)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute("%s/slot_1.json" % absolute)
		DirAccess.remove_absolute("%s/slot_2.json" % absolute)
		DirAccess.remove_absolute("%s/slot_3.json" % absolute)
		DirAccess.remove_absolute(absolute)


func _close_ui_manager() -> void:
	var ui_manager := root.get_node_or_null("UIManager")
	if ui_manager != null and ui_manager.has_method("close_active_ui"):
		ui_manager.call("close_active_ui")


func _wait_process_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _extracted_result() -> Dictionary:
	return {
		"outcome": "extracted",
		"duration": 94.25,
		"money_delta": 35,
		"extracted_items": [
			{"item_path": "res://data/items/crafting/wood.tres", "quantity": 3},
			{"item_path": "res://data/items/currency/cash.tres", "quantity": 5},
		],
		"lost_items": [],
		"kept_safe_pocket_items": [
			{"item_path": "res://data/items/crafting/wood.tres", "quantity": 1},
		],
	}


func _dead_result() -> Dictionary:
	return {
		"outcome": "dead",
		"duration": 41.0,
		"money_delta": 0,
		"extracted_items": [],
		"lost_items": [
			{"item_path": "res://data/items/crafting/wood.tres", "quantity": 2},
		],
		"kept_safe_pocket_items": [
			{"item_path": "res://data/items/loot/junk.tres", "quantity": 1},
		],
	}


func _make_panel() -> Control:
	var panel := RaidResultPanelScene.instantiate() as Control
	root.add_child(panel)
	return panel


func _on_continue_to_base_requested(_result: Dictionary) -> void:
	_continue_signal_seen = true


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
