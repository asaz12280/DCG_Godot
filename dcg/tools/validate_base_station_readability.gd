extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")

const REQUIRED_STATIONS := {
	"stash": {
		"title_key": "ui.base.station.stash",
		"hint_key": "ui.base.station.stash_hint",
	},
	"quests": {
		"title_key": "ui.base.station.quests",
		"hint_key": "ui.base.station.quests_hint",
	},
	"workbench": {
		"title_key": "ui.base.station.workbench",
		"hint_key": "ui.base.station.workbench_hint",
		"action_required": true,
	},
	"raid_gate": {
		"title_key": "ui.base.station.raid_gate",
		"hint_key": "ui.base.station.raid_gate_hint",
	},
	"medical": {
		"title_key": "ui.base.station.medical",
		"hint_key": "ui.base.station.medical_hint",
		"action_required": true,
	},
}

var _errors: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	_validate_station_nodes(scene)
	await _validate_station_prompts_and_panels(scene)
	_validate_responsibility_boundaries()
	scene.queue_free()
	if _errors.is_empty():
		print("[base_station_readability] OK stations=5 labels=readable prompts=clear stash=grid panels=zh boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_station_nodes(scene: Node) -> void:
	for station_id in REQUIRED_STATIONS.keys():
		var station: Dictionary = REQUIRED_STATIONS[station_id]
		var point := _find_point(scene, station_id)
		if point == null:
			_errors.append("Base station missing interaction point: %s." % station_id)
			continue
		if point.get_node_or_null("Marker") == null:
			_errors.append("Base station %s should have a visible 3D marker." % station_id)
		var title_label := point.get_node_or_null("Label3D") as Label3D
		var hint_label := point.get_node_or_null("HintLabel3D") as Label3D
		_validate_label(title_label, _localized(str(station.get("title_key", ""))), station_id, "title")
		_validate_label(hint_label, _localized(str(station.get("hint_key", ""))), station_id, "hint")


func _validate_label(label: Label3D, expected_text: String, station_id: String, role: String) -> void:
	if label == null:
		_errors.append("Base station %s should include a %s Label3D." % [station_id, role])
		return
	if not label.visible:
		_errors.append("Base station %s %s Label3D should be visible." % [station_id, role])
	if label.billboard == BaseMaterial3D.BILLBOARD_DISABLED:
		_errors.append("Base station %s %s Label3D should billboard toward the camera." % [station_id, role])
	if role == "title" and label.font_size < 38:
		_errors.append("Base station %s title should be large enough to read." % station_id)
	if role == "hint" and label.font_size < 22:
		_errors.append("Base station %s hint should be large enough to read." % station_id)
	if label.outline_size < 4:
		_errors.append("Base station %s %s Label3D should keep outline contrast." % [station_id, role])
	if expected_text != "" and label.text != expected_text:
		_errors.append("Base station %s %s should read `%s`, got `%s`." % [station_id, role, expected_text, label.text])
	_assert_clean_text(label.text, "Base station %s %s label" % [station_id, role])


func _validate_station_prompts_and_panels(scene: Node) -> void:
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	var player := scene.get_node_or_null("Player3D") as Node3D
	if controller == null or player == null:
		_errors.append("Base station readability requires Player3D and BaseInteractionController3D.")
		return
	for station_id in REQUIRED_STATIONS.keys():
		var station: Dictionary = REQUIRED_STATIONS[station_id]
		var title := _localized(str(station.get("title_key", "")))
		var point := _find_point(scene, station_id)
		if point == null:
			continue
		player.global_position = point.global_position
		await process_frame
		var prompt := str(controller.call("get_current_prompt_text"))
		_assert_clean_text(prompt, "Base station %s prompt" % station_id)
		if prompt.strip_edges() == "" or not prompt.contains(title):
			_errors.append("Base station %s prompt should include its station label, got `%s`." % [station_id, prompt])
		if station_id == "raid_gate":
			continue
		if not bool(controller.call("open_interaction_by_id", station_id)):
			_errors.append("Base station %s should open through the controller." % station_id)
			continue
		await process_frame
		var panel_state: Dictionary = controller.call("get_panel_state")
		if station_id == "stash":
			_validate_stash_state(panel_state)
		else:
			_validate_panel_state(panel_state, station_id, station, title)
		_close_station_ui(scene, station_id)


func _validate_stash_state(panel_state: Dictionary) -> void:
	if not bool(panel_state.get("visible", false)) or not bool(panel_state.get("is_open", false)):
		_errors.append("Stash station should open the warehouse storage grid.")
	if int(panel_state.get("stash_capacity", 0)) < 100:
		_errors.append("Stash station should expose warehouse storage capacity.")
	if not str(panel_state.get("title", "")).contains(_localized("ui.base.station.stash")):
		_errors.append("Stash station title should match its station label.")
	_assert_clean_text(str(panel_state.get("title", "")) + str(panel_state.get("status_text", "")), "Base station stash text")


func _validate_panel_state(panel_state: Dictionary, station_id: String, station: Dictionary, expected_title: String) -> void:
	if not bool(panel_state.get("visible", false)):
		_errors.append("Base station %s panel should be visible after interaction." % station_id)
	var title := str(panel_state.get("title", ""))
	var body := str(panel_state.get("body", ""))
	var button := str(panel_state.get("button", ""))
	if title != expected_title:
		_errors.append("Base station %s panel title should match its station label." % station_id)
	if body.strip_edges() == "":
		_errors.append("Base station %s panel body should explain its purpose." % station_id)
	if button != _localized("ui.common.close"):
		_errors.append("Base station %s panel close button should be localized." % station_id)
	if bool(station.get("action_required", false)) and not bool(panel_state.get("action_visible", false)):
		_errors.append("Base station %s should expose its action button." % station_id)
	_assert_clean_text(title + body + button + str(panel_state.get("action_text", "")), "Base station %s panel text" % station_id)


func _close_station_ui(scene: Node, station_id: String) -> void:
	if station_id == "stash":
		var stash_panel := scene.get_node_or_null("HUD/BaseStashInventoryUI")
		if stash_panel != null and stash_panel.has_method("close_stash"):
			stash_panel.call("close_stash")
		return
	var panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
	if panel != null and panel.has_method("close_panel"):
		panel.call("close_panel")


func _validate_responsibility_boundaries() -> void:
	var controller_source := FileAccess.get_file_as_string("res://scripts/base/base_interaction_controller_3d.gd")
	for forbidden in ["QuestState", "WeaponController", "InventoryEquipmentUI", "ItemCodexUI", "EnemyController"]:
		if controller_source.contains(forbidden):
			_errors.append("BaseInteractionController3D should not own %s behavior." % forbidden)
	var panel_source := FileAccess.get_file_as_string("res://scripts/base/base_interaction_panel.gd")
	for forbidden in ["change_scene", "SaveGameManager", "RaidSession", "WeaponController", "QuestState"]:
		if panel_source.contains(forbidden):
			_errors.append("BaseInteractionPanel should stay display-only and not own %s." % forbidden)


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


func _localized(key: String) -> String:
	if key == "":
		return ""
	var value := TranslationServer.translate(key)
	return "" if value == key else value


func _assert_clean_text(value: String, label: String) -> void:
	if value.strip_edges() == "":
		_errors.append("%s should not be empty." % label)
	if value.contains("�") or value.contains("???"):
		_errors.append("%s should not contain broken encoding text: `%s`." % [label, value])
