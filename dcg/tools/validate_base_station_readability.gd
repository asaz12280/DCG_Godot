extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const UITextScript := preload("res://scripts/ui/ui_text.gd")

const REQUIRED_STATIONS := {
	"stash": {
		"title": "倉庫",
		"hint_terms": ["整理", "戰利品"],
		"prompt_terms": ["按 E", "互動", "倉庫"],
		"panel_terms": ["整理戰利品", "裝備"],
	},
	"quests": {
		"title": "任務板",
		"hint_terms": ["查看", "回報"],
		"prompt_terms": ["按 E", "互動", "任務板"],
		"panel_terms": ["查看", "回報任務"],
	},
	"workbench": {
		"title": "工作台",
		"hint_terms": ["升級", "基地"],
		"prompt_terms": ["按 E", "互動", "工作台"],
		"panel_terms": ["升級基地功能"],
	},
	"raid_gate": {
		"title": "出擊門",
		"hint_terms": ["開始", "行動"],
		"prompt_terms": ["按 E", "查看出擊簡報", "出擊門"],
		"briefing_terms": ["出擊簡報", "地點", "風險", "目標", "開始出擊", "取消"],
	},
	"medical": {
		"title": "醫療站",
		"hint_terms": ["回復", "生命"],
		"prompt_terms": ["按 E", "互動", "醫療站"],
		"panel_terms": ["生命", "金錢"],
		"action_terms": ["治療"],
	},
}

var _errors: Array[String] = []


func _initialize() -> void:
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
		print("[base_station_readability] OK stations=5 labels=readable prompts=clear panels=zh boundaries=clean")
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
		_validate_label(title_label, str(station.get("title", "")), station_id, "title")
		_validate_hint_label(hint_label, station.get("hint_terms", []), station_id)


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
	_assert_clean_zh(label.text, "Base station %s %s label" % [station_id, role])


func _validate_hint_label(label: Label3D, terms: Array, station_id: String) -> void:
	if label == null:
		_errors.append("Base station %s should include a HintLabel3D explaining its purpose." % station_id)
		return
	_validate_label(label, "", station_id, "hint")
	if not _has_all_terms(label.text, terms):
		_errors.append("Base station %s hint should explain purpose with %s, got `%s`." % [station_id, terms, label.text])


func _validate_station_prompts_and_panels(scene: Node) -> void:
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	var player := scene.get_node_or_null("Player3D") as Node3D
	if controller == null or player == null:
		_errors.append("Base station readability requires Player3D and BaseInteractionController3D.")
		return
	for station_id in REQUIRED_STATIONS.keys():
		var station: Dictionary = REQUIRED_STATIONS[station_id]
		var point := _find_point(scene, station_id)
		if point == null:
			continue
		player.global_position = point.global_position
		await process_frame
		var prompt := str(controller.call("get_current_prompt_text"))
		_assert_clean_zh(prompt, "Base station %s prompt" % station_id)
		if not _has_all_terms(prompt, station.get("prompt_terms", [])):
			_errors.append("Base station %s prompt should be clear, got `%s`." % [station_id, prompt])
		if not bool(controller.call("open_interaction_by_id", station_id)):
			_errors.append("Base station %s should open through the controller." % station_id)
			continue
		await process_frame
		if station_id == "raid_gate":
			var briefing_state: Dictionary = controller.call("get_raid_briefing_state")
			_validate_briefing_state(briefing_state)
			var briefing := scene.get_node_or_null("HUD/RaidBriefingPanel")
			if briefing != null and briefing.has_method("cancel"):
				briefing.call("cancel")
		else:
			var panel_state: Dictionary = controller.call("get_panel_state")
			_validate_panel_state(panel_state, station_id, station)
			var panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
			if panel != null and panel.has_method("close_panel"):
				panel.call("close_panel")


func _validate_panel_state(panel_state: Dictionary, station_id: String, station: Dictionary) -> void:
	if not bool(panel_state.get("visible", false)):
		_errors.append("Base station %s panel should be visible after interaction." % station_id)
	var title := str(panel_state.get("title", ""))
	var body := str(panel_state.get("body", ""))
	var button := str(panel_state.get("button", ""))
	if title != str(station.get("title", "")):
		_errors.append("Base station %s panel title should match its station label." % station_id)
	if not _has_all_terms(body, station.get("panel_terms", [])):
		_errors.append("Base station %s panel body should explain its purpose, got `%s`." % [station_id, body])
	if button != "關閉":
		_errors.append("Base station %s panel close button should read 關閉." % station_id)
	if station.has("action_terms"):
		if not bool(panel_state.get("action_visible", false)):
			_errors.append("Base station %s should expose its action button." % station_id)
		if not _has_all_terms(str(panel_state.get("action_text", "")), station.get("action_terms", [])):
			_errors.append("Base station %s action button text should explain the action." % station_id)
	_assert_clean_zh(title + body + button, "Base station %s panel text" % station_id)


func _validate_briefing_state(state: Dictionary) -> void:
	if not bool(state.get("visible", false)):
		_errors.append("Raid gate should open the visible sortie briefing.")
	var combined := "%s %s %s %s %s %s %s" % [
		str(state.get("title", "")),
		str(state.get("location", "")),
		str(state.get("risk", "")),
		str(state.get("objective", "")),
		str(state.get("hint", "")),
		str(state.get("start_button", "")),
		str(state.get("cancel_button", "")),
	]
	_assert_clean_zh(combined, "Raid gate briefing text")
	if not _has_all_terms(combined, REQUIRED_STATIONS["raid_gate"].get("briefing_terms", [])):
		_errors.append("Raid gate briefing should summarize destination, risk, objective, and actions.")


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


func _has_all_terms(value: String, terms: Array) -> bool:
	for term in terms:
		if not value.contains(str(term)):
			return false
	return true


func _assert_clean_zh(value: String, context: String) -> void:
	if value == "":
		_errors.append("%s should not be empty." % context)
		return
	if UITextScript.looks_corrupt(value):
		_errors.append("%s looks corrupt: `%s`." % [context, value])
	if _contains_ascii_word(value):
		_errors.append("%s should not contain English fallback text: `%s`." % [context, value])


func _contains_ascii_word(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("[A-Za-z]{3,}")
	return regex.search(value) != null
