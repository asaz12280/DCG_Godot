extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")

const REQUIRED_IDS: Array[String] = ["stash", "quests", "workbench", "raid_gate", "medical"]
const STATION_TITLE_KEYS := {
	"stash": "ui.base.station.stash",
	"quests": "ui.base.station.quests",
	"workbench": "ui.base.station.workbench",
	"medical": "ui.base.station.medical",
}

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	_validate_controller(scene)
	_validate_panels(scene)
	await _validate_interactions(scene)
	await _validate_layout_fit(scene)
	scene.queue_free()
	if _errors.is_empty():
		print("[base_interactions] OK prompt=visible panels=connected stash=storage_grid raid=startable text=zh")
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
	for id in REQUIRED_IDS:
		if not ids.has(id):
			_errors.append("Base interaction controller missing id: %s." % id)


func _validate_panels(scene: Node) -> void:
	var panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
	if panel == null:
		_errors.append("Base 3D should include node-first BaseInteractionPanel under HUD.")
	elif not panel.has_method("open_interaction") or not panel.has_method("get_display_state"):
		_errors.append("BaseInteractionPanel should expose open_interaction and display state.")
	var stash_panel := scene.get_node_or_null("HUD/BaseStashInventoryUI")
	if stash_panel == null:
		_errors.append("Base 3D should include node-first BaseStashInventoryUI under HUD.")
	elif not stash_panel.has_method("open_stash") or not stash_panel.has_method("get_display_state"):
		_errors.append("BaseStashInventoryUI should expose open_stash and display state.")


func _validate_interactions(scene: Node) -> void:
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	var player := scene.get_node_or_null("Player3D") as Node3D
	if controller == null or player == null:
		return
	for id in STATION_TITLE_KEYS.keys():
		var expected_title := TranslationServer.translate(str(STATION_TITLE_KEYS[id]))
		var point := _find_point(scene, id)
		if point == null:
			_errors.append("Base 3D missing interaction point %s." % id)
			continue
		player.global_position = point.global_position
		await process_frame
		var prompt := str(controller.call("get_current_prompt_text"))
		if prompt.strip_edges() == "" or not prompt.contains(expected_title):
			_errors.append("Prompt should show localized open text for %s, got: %s." % [id, prompt])
		if not bool(controller.call("open_interaction_by_id", id)):
			_errors.append("Controller should open UI for %s." % id)
			continue
		await process_frame
		if id == "stash":
			_validate_stash_panel(scene)
			continue
		var state: Dictionary = controller.call("get_panel_state")
		if not bool(state.get("visible", false)):
			_errors.append("Panel should be visible after opening %s." % id)
		if str(state.get("title", "")) != expected_title:
			_errors.append("Panel title for %s should be localized." % id)
		if _contains_ascii_word(str(state.get("body", ""))):
			_errors.append("Panel body for %s should not contain English fallback text." % id)
		if id == "medical" and not bool(state.get("action_visible", false)):
			_errors.append("Medical station should show a treatment action button.")
		if id == "workbench" and not bool(state.get("action_visible", false)):
			_errors.append("Workbench station should expose its upgrade action button.")
		var panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
		if panel != null and panel.has_method("close_panel"):
			panel.call("close_panel")

	var raid_point := _find_point(scene, "raid_gate")
	if raid_point != null:
		player.global_position = raid_point.global_position
		await process_frame
		var raid_prompt := str(controller.call("get_current_prompt_text"))
		if raid_prompt.strip_edges() == "" or _contains_ascii_word(raid_prompt):
			_errors.append("Raid gate prompt should show localized start-raid text.")
	var source := FileAccess.get_file_as_string("res://scripts/base/base_interaction_controller_3d.gd")
	if not source.contains("res://scenes/gameplay/player_test_world_3d.tscn"):
		_errors.append("Base interaction raid target scene should exist.")


func _validate_stash_panel(scene: Node) -> void:
	var stash_panel := scene.get_node_or_null("HUD/BaseStashInventoryUI")
	var interaction_panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
	if stash_panel == null or not stash_panel.has_method("get_display_state"):
		_errors.append("Stash interaction should open BaseStashInventoryUI.")
		return
	var state: Dictionary = stash_panel.call("get_display_state")
	if not bool(state.get("visible", false)) or not bool(state.get("is_open", false)):
		_errors.append("Stash interaction should show the storage grid UI.")
	if int(state.get("stash_capacity", 0)) < 100:
		_errors.append("Stash storage UI should expose warehouse capacity.")
	if not str(state.get("title", "")).contains(TranslationServer.translate("ui.base.station.stash")):
		_errors.append("Stash storage title should be localized.")
	if interaction_panel != null and interaction_panel.has_method("is_open") and bool(interaction_panel.call("is_open")):
		_errors.append("Stash should not open the generic BaseInteractionPanel.")
	if stash_panel.has_method("close_stash"):
		stash_panel.call("close_stash")


func _validate_layout_fit(scene: Node) -> void:
	var panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
	var framed_panel := scene.get_node_or_null("HUD/BaseInteractionPanel/Panel") as PanelContainer
	var stash_panel := scene.get_node_or_null("HUD/BaseStashInventoryUI")
	if panel == null or framed_panel == null or stash_panel == null:
		return
	var viewport_sizes := [Vector2i(1280, 720), Vector2i(1920, 1080)]
	for viewport_size in viewport_sizes:
		root.size = viewport_size
		if stash_panel.has_method("open_stash"):
			stash_panel.call("open_stash", scene.get_node_or_null("Player3D"), root.get_node_or_null("SaveGameManager"))
			await process_frame
			var stash_state: Dictionary = stash_panel.call("get_display_state_for_viewport", Vector2(viewport_size))
			_assert_rect_inside(stash_state.get("left_panel_rect", Rect2()), viewport_size, "Base stash loadout panel")
			_assert_rect_inside(stash_state.get("right_panel_rect", Rect2()), viewport_size, "Base stash warehouse panel")
			_assert_rect_inside(stash_state.get("stash_grid_rect", Rect2()), viewport_size, "Base stash grid")
			stash_panel.call("close_stash")

		panel.call("open_interaction", "quests", TranslationServer.translate("ui.base.station.quests"))
		await process_frame
		await process_frame
		var rect := Rect2(framed_panel.global_position, framed_panel.size)
		_assert_rect_inside(rect, viewport_size, "Base interaction panel")
		var close_button := scene.get_node_or_null("HUD/BaseInteractionPanel/Panel/Margin/Content/CloseButton") as Button
		if close_button == null or close_button.size.x < 160.0 or close_button.size.y < 40.0:
			_errors.append("Base interaction close button should remain comfortably clickable at %s." % viewport_size)
		panel.call("close_panel")


func _assert_rect_inside(rect: Rect2, viewport_size: Vector2, label: String) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_errors.append("%s should have a positive layout size." % label)
		return
	if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > float(viewport_size.x) or rect.end.y > float(viewport_size.y):
		_errors.append("%s should fit inside %s, got %s." % [label, viewport_size, rect])


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
