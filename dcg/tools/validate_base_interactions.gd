extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")
var _required_ids := PackedStringArray(["stash", "quests", "workbench", "raid_gate", "medical"])

var _errors: Array[String] = []


func _initialize() -> void:
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	_validate_controller(scene)
	_validate_panel(scene)
	_validate_interactions(scene)
	await _validate_layout_fit(scene)
	scene.queue_free()
	if _errors.is_empty():
		print("[base_interactions] OK prompt=visible panels=connected raid=startable text=zh")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_controller(scene: Node) -> void:
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	if controller == null:
		_errors.append("Base 3D should include BaseInteractionController3D.")
		return
	if not controller.has_method("get_available_interaction_ids"):
		_errors.append("BaseInteractionController3D should expose available interaction ids for validation.")
		return
	var ids: PackedStringArray = controller.get_available_interaction_ids()
	for id in _required_ids:
		if not ids.has(id):
			_errors.append("Base interaction controller missing id: %s." % id)


func _validate_panel(scene: Node) -> void:
	var panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
	if panel == null:
		_errors.append("Base 3D should include node-first BaseInteractionPanel under HUD.")
		return
	if not panel.has_method("open_interaction") or not panel.has_method("get_display_state"):
		_errors.append("BaseInteractionPanel should expose open_interaction and display state.")


func _validate_interactions(scene: Node) -> void:
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	var player := scene.get_node_or_null("Player3D") as Node3D
	if controller == null or player == null:
		return
	var expected_titles := {
		"stash": "倉庫",
		"quests": "任務板",
		"workbench": "工作台",
		"medical": "醫療站",
	}
	for id in expected_titles.keys():
		var point := _find_point(scene, id)
		if point == null:
			_errors.append("Base 3D missing interaction point %s." % id)
			continue
		player.global_position = point.global_position
		await process_frame
		var prompt := str(controller.call("get_current_prompt_text"))
		if not prompt.contains("按 E 互動") or not prompt.contains(str(expected_titles[id])):
			_errors.append("Prompt should show Traditional Chinese open text for %s, got: %s." % [id, prompt])
		if not bool(controller.call("open_interaction_by_id", id)):
			_errors.append("Controller should open panel for %s." % id)
			continue
		var state: Dictionary = controller.call("get_panel_state")
		if not bool(state.get("visible", false)):
			_errors.append("Panel should be visible after opening %s." % id)
		if str(state.get("title", "")) != str(expected_titles[id]):
			_errors.append("Panel title for %s should be Traditional Chinese." % id)
		if _contains_ascii_word(str(state.get("body", ""))):
			_errors.append("Panel body for %s should not contain English fallback text." % id)
		if id == "medical":
			if not bool(state.get("action_visible", false)):
				_errors.append("Medical station should show a treatment action button.")
			if not str(state.get("action_text", "")).contains("治療"):
				_errors.append("Medical station action should use readable Traditional Chinese text.")
		var panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
		if panel != null and panel.has_method("close_panel"):
			panel.call("close_panel")

	var raid_point := _find_point(scene, "raid_gate")
	if raid_point != null:
		player.global_position = raid_point.global_position
		await process_frame
		var raid_prompt := str(controller.call("get_current_prompt_text"))
		if not raid_prompt.contains("按 E 查看出擊簡報") or not raid_prompt.contains("出擊門"):
			_errors.append("Raid gate prompt should show Traditional Chinese briefing text.")
	var source := FileAccess.get_file_as_string("res://scripts/base/base_interaction_controller_3d.gd")
	if not source.contains("res://scenes/gameplay/player_test_world_3d.tscn"):
		_errors.append("Base interaction raid target scene should exist.")


func _validate_layout_fit(scene: Node) -> void:
	var panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
	var framed_panel := scene.get_node_or_null("HUD/BaseInteractionPanel/Panel") as PanelContainer
	if panel == null or framed_panel == null:
		return
	var viewport_sizes := [Vector2i(1280, 720), Vector2i(1920, 1080)]
	for viewport_size in viewport_sizes:
		root.size = viewport_size
		panel.call("open_interaction", "stash", "倉庫")
		await process_frame
		await process_frame
		var rect := Rect2(framed_panel.global_position, framed_panel.size)
		if rect.position.x < 0.0 or rect.position.y < 0.0:
			_errors.append("Base interaction panel escapes viewport at %s." % viewport_size)
		if rect.end.x > float(viewport_size.x) or rect.end.y > float(viewport_size.y):
			_errors.append("Base interaction panel exceeds viewport at %s." % viewport_size)
		var close_button := scene.get_node_or_null("HUD/BaseInteractionPanel/Panel/Margin/Content/CloseButton") as Button
		if close_button == null or close_button.size.x < 160.0 or close_button.size.y < 40.0:
			_errors.append("Base interaction close button should remain comfortably clickable at %s." % viewport_size)
		panel.call("close_panel")


func _find_point(scene: Node, interaction_id: String) -> Node3D:
	for point in _collect_points(scene):
		if str(point.get_meta("interaction_id", "")) == interaction_id:
			return point
	return null


func _collect_points(root_node: Node) -> Array[Node3D]:
	var points: Array[Node3D] = []
	_collect_points_recursive(root_node, points)
	return points


func _collect_points_recursive(node: Node, points: Array[Node3D]) -> void:
	if node.is_in_group("base_interaction_point"):
		var point := node as Node3D
		if point != null:
			points.append(point)
	for child in node.get_children():
		_collect_points_recursive(child, points)


func _contains_ascii_word(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("[A-Za-z]{3,}")
	return regex.search(value) != null
