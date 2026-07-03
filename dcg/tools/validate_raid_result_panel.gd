extends SceneTree

const RaidResultPanelScene := preload("res://scenes/ui/raid_result_panel.tscn")
const RaidResultPanelScript := preload("res://scripts/ui/raid_result_panel.gd")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")

var _errors: Array[String] = []
var _continue_signal_seen := false


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	await _validate_extracted_result_display()
	await _validate_dead_result_display()
	await _validate_layout_fit()
	await _validate_gameplay_scene_wiring()
	_validate_script_boundaries()
	if _errors.is_empty():
		print("[raid_result_panel] OK node_first=true extracted_vs_dead=clear transfer=visible loot=shown continue=base layout=fits boundaries=clean")
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
	await process_frame
	_free_current_scene()
	_free_node(panel)


func _validate_dead_result_display() -> void:
	var panel := _make_panel()
	await process_frame
	panel.show_result(_dead_result())
	await process_frame
	var state: Dictionary = panel.get_display_state()
	if not str(state.get("outcome", "")).contains("死亡"):
		_errors.append("RaidResultPanel should show death outcome in Traditional Chinese.")
	if not str(state.get("outcome", "")).contains("行動失敗"):
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
	for expected in ["基地", "回到基地"]:
		if not detail.contains(expected):
			_errors.append("RaidResultPanel transfer detail should mention `%s`." % expected)
	if extracted:
		for expected in ["帶回成功", "基地倉庫"]:
			if not detail.contains(expected):
				_errors.append("RaidResultPanel extracted transfer detail should mention `%s`." % expected)
		if not str(state.get("status", "")).contains("基地倉庫"):
			_errors.append("RaidResultPanel status should explain extracted supplies enter base stash.")
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
	if source.contains("SaveGameManager") or source.contains("StashModel"):
		_errors.append("RaidResultPanel should not directly mutate save or stash state.")
	if source.contains("base_screen.tscn"):
		_errors.append("RaidResultPanel should not route normal player flow back to the old 2D BaseScreen.")
	if not source.contains("change_scene_to_file(BASE_SCENE)"):
		_errors.append("RaidResultPanel should route Continue to Base through the configured scene path.")


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
			{"item_path": "res://data/items/electronics/wire.tres", "quantity": 1},
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
