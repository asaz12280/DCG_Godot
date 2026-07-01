extends SceneTree

const RaidResultPanelScene := preload("res://scenes/ui/raid_result_panel.tscn")
const RaidResultPanelScript := preload("res://scripts/ui/raid_result_panel.gd")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")

var _errors: Array[String] = []
var _continue_signal_seen := false


func _initialize() -> void:
	await _validate_fake_result_display()
	await _validate_layout_fit()
	await _validate_gameplay_scene_wiring()
	_validate_script_boundaries()
	if _errors.is_empty():
		print("[raid_result_panel] OK node_first=true fake_data=shown continue=base layout=fits")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_fake_result_display() -> void:
	var panel := _make_panel()
	await process_frame
	panel.show_result(_fake_result())
	await process_frame
	var state: Dictionary = panel.get_display_state()
	if not bool(state.get("visible", false)):
		_errors.append("RaidResultPanel should become visible after show_result().")
	if not str(state.get("outcome", "")).contains("Extracted"):
		_errors.append("RaidResultPanel should show extracted outcome from fake data.")
	if int(state.get("extracted_rows", 0)) < 1:
		_errors.append("RaidResultPanel should show extracted item rows.")
	if int(state.get("lost_rows", 0)) < 1:
		_errors.append("RaidResultPanel should show lost item rows or empty state.")
	if int(state.get("safe_pocket_rows", 0)) < 1:
		_errors.append("RaidResultPanel should show safe pocket rows or empty state.")
	if str(state.get("continue_text", "")) == "":
		_errors.append("RaidResultPanel continue button should have readable text.")
	_continue_signal_seen = false
	panel.continue_to_base_requested.connect(_on_continue_to_base_requested)
	panel.continue_button.pressed.emit()
	if not _continue_signal_seen:
		_errors.append("RaidResultPanel should emit user intent before returning to Base.")
	if not ResourceLoader.exists(panel.BASE_SCENE):
		_errors.append("RaidResultPanel Base destination scene should exist.")
	_free_node(panel)


func _validate_layout_fit() -> void:
	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		root.content_scale_size = Vector2i(int(viewport_size.x), int(viewport_size.y))
		root.size = Vector2i(int(viewport_size.x), int(viewport_size.y))
		var panel := _make_panel()
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.size = viewport_size
		await process_frame
		panel.show_result(_fake_result())
		panel.size = viewport_size
		await process_frame
		var state: Dictionary = panel.get_display_state()
		var panel_rect := state.get("panel_rect") as Rect2
		var button_rect := state.get("button_rect") as Rect2
		if panel_rect.position.x < 32.0 and viewport_size.x >= 1280.0:
			_errors.append("RaidResultPanel should keep a clear safe margin at %s." % viewport_size)
		if panel_rect.end.x > viewport_size.x or panel_rect.end.y > viewport_size.y:
			_errors.append("RaidResultPanel should fit inside %s." % viewport_size)
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


func _validate_script_boundaries() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/raid_result_panel.gd")
	if source.contains("SaveGameManager") or source.contains("StashModel"):
		_errors.append("RaidResultPanel should not directly mutate save or stash state.")
	if not source.contains("change_scene_to_file(BASE_SCENE)"):
		_errors.append("RaidResultPanel should route Continue to Base through the configured scene path.")


func _fake_result() -> Dictionary:
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


func _make_panel() -> Control:
	var panel := RaidResultPanelScene.instantiate() as Control
	root.add_child(panel)
	return panel


func _on_continue_to_base_requested(_result: Dictionary) -> void:
	_continue_signal_seen = true


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
