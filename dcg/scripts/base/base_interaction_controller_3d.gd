class_name BaseInteractionController3D
extends Node

const GAMEPLAY_SCENE := "res://scenes/gameplay/player_test_world_3d.tscn"
const RaidLoadoutTransferScript := preload("res://scripts/raid/raid_loadout_transfer.gd")
const BaseMedicalServiceScript := preload("res://scripts/base/base_medical_service.gd")
const BaseWorkbenchServiceScript := preload("res://scripts/base/base_workbench_service.gd")

@export_node_path("Node3D") var player_path: NodePath
@export_node_path("Label3D") var prompt_label_path: NodePath
@export_node_path("Control") var panel_path: NodePath
@export_node_path("Control") var raid_briefing_panel_path: NodePath
@export var interaction_range := 1.8

var _player: Node3D
var _prompt_label: Label3D
var _panel: Control
var _raid_briefing_panel: Control
var _points: Array[Node3D] = []
var _nearest_point: Node3D
var _last_prepared_raid_loadout: Dictionary = {}


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_prompt_label = get_node_or_null(prompt_label_path) as Label3D
	_panel = get_node_or_null(panel_path) as Control
	_raid_briefing_panel = get_node_or_null(raid_briefing_panel_path) as Control
	_connect_interaction_panel()
	_connect_raid_briefing_panel()
	_refresh_points()
	_update_prompt()


func _process(_delta: float) -> void:
	_update_nearest_point()
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _is_any_panel_open():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			if _is_raid_briefing_open():
				_raid_briefing_panel.call("cancel")
			elif _is_interaction_panel_open():
				_panel.call("close_panel")
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if interact_with_nearest():
			get_viewport().set_input_as_handled()


func interact_with_nearest() -> bool:
	if _nearest_point == null:
		return false
	return open_interaction_by_id(str(_nearest_point.get_meta("interaction_id", "")))


func open_interaction_by_id(interaction_id: String) -> bool:
	var point := _find_point_by_id(interaction_id)
	if point == null:
		return false
	var display_name := _display_name(point)
	if interaction_id == "raid_gate":
		return _open_raid_briefing(display_name)
	if interaction_id == "medical":
		return _open_medical_station(display_name)
	if interaction_id == "workbench":
		return _open_workbench_station(display_name)
	if _panel == null or not _panel.has_method("open_interaction"):
		return false
	_panel.call("open_interaction", interaction_id, display_name)
	return true


func get_available_interaction_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for point in _points:
		var interaction_id := str(point.get_meta("interaction_id", ""))
		if interaction_id != "":
			ids.append(interaction_id)
	return ids


func get_current_prompt_text() -> String:
	return _prompt_label.text if _prompt_label != null else ""


func get_panel_state() -> Dictionary:
	return _panel.call("get_display_state") if _panel != null and _panel.has_method("get_display_state") else {}


func get_raid_briefing_state() -> Dictionary:
	return _raid_briefing_panel.call("get_display_state") if _raid_briefing_panel != null and _raid_briefing_panel.has_method("get_display_state") else {}


func get_medical_station_state() -> Dictionary:
	return BaseMedicalServiceScript.get_state(_player, _get_save_manager())


func prepare_raid_loadout() -> bool:
	_last_prepared_raid_loadout.clear()
	if _player == null:
		return false
	var save_manager := _get_save_manager()
	if save_manager == null or not save_manager.has_method("set_pending_raid_loadout"):
		return false
	var loadout: Dictionary = RaidLoadoutTransferScript.build_from_player(_player)
	if not bool(save_manager.call("set_pending_raid_loadout", loadout)):
		return false
	_last_prepared_raid_loadout = loadout.duplicate(true)
	return true


func get_last_prepared_raid_loadout() -> Dictionary:
	return _last_prepared_raid_loadout.duplicate(true)


func _change_to_gameplay_scene() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.change_scene_to_file(GAMEPLAY_SCENE)


func _open_raid_briefing(display_name: String) -> bool:
	if _raid_briefing_panel == null or not _raid_briefing_panel.has_method("open_briefing"):
		return false
	_raid_briefing_panel.call("open_briefing", _raid_briefing_context(display_name))
	return true


func _open_medical_station(display_name: String) -> bool:
	if _panel == null or not _panel.has_method("open_interaction"):
		return false
	_panel.call("open_interaction", "medical", display_name, _medical_panel_context())
	return true


func _open_workbench_station(display_name: String) -> bool:
	if _panel == null or not _panel.has_method("open_interaction"):
		return false
	_panel.call("open_interaction", "workbench", display_name, _workbench_panel_context())
	return true


func _workbench_panel_context() -> Dictionary:
	return BaseWorkbenchServiceScript.get_panel_context(_get_save_manager())


func _medical_panel_context() -> Dictionary:
	var state := BaseMedicalServiceScript.get_state(_player, _get_save_manager())
	return {
		"body": BaseMedicalServiceScript.describe(_player, _get_save_manager()),
		"action_visible": true,
		"action_enabled": bool(state.get("can_heal", false)),
		"action_text": str(state.get("action_text", "治療")),
	}


func _raid_briefing_context(display_name: String) -> Dictionary:
	return {
		"location": display_name if display_name != "" else "郊外回收區",
		"risk": "偵測到拾荒者，會追蹤並近身攻擊。",
		"objective": "搜索物資，保持距離，必要時裝填手槍反擊，前往撤離點。",
		"loadout_summary": _loadout_summary(),
	}


func _loadout_summary() -> String:
	if _player == null:
		return "依目前裝備與背包出擊。"
	var loadout: Dictionary = RaidLoadoutTransferScript.build_from_player(_player)
	var backpack_items: Array = loadout.get("backpack_items", [])
	var equipped_items: Dictionary = loadout.get("equipment_slots", {})
	var equipped_count := 0
	for slot_id in equipped_items.keys():
		var item_data: Dictionary = equipped_items[slot_id]
		if not item_data.is_empty():
			equipped_count += 1
	return "背包 %d 組，裝備 %d 件。" % [backpack_items.size(), equipped_count]


func _connect_raid_briefing_panel() -> void:
	if _raid_briefing_panel == null:
		return
	var start_callable := Callable(self, "_on_raid_briefing_start_requested")
	var cancel_callable := Callable(self, "_on_raid_briefing_cancel_requested")
	if _raid_briefing_panel.has_signal("start_raid_requested") and not _raid_briefing_panel.is_connected("start_raid_requested", start_callable):
		_raid_briefing_panel.connect("start_raid_requested", start_callable)
	if _raid_briefing_panel.has_signal("cancel_requested") and not _raid_briefing_panel.is_connected("cancel_requested", cancel_callable):
		_raid_briefing_panel.connect("cancel_requested", cancel_callable)


func _connect_interaction_panel() -> void:
	if _panel == null or not _panel.has_signal("action_requested"):
		return
	var action_callable := Callable(self, "_on_interaction_panel_action_requested")
	if not _panel.is_connected("action_requested", action_callable):
		_panel.connect("action_requested", action_callable)


func _on_interaction_panel_action_requested(interaction_id: String) -> void:
	match interaction_id:
		"medical":
			var result := BaseMedicalServiceScript.apply_heal(_player, _get_save_manager())
			if _panel != null and _panel.has_method("update_interaction_state"):
				var context := _medical_panel_context()
				context["body"] = "%s\n%s" % [str(result.get("reason", "")), BaseMedicalServiceScript.describe(_player, _get_save_manager())]
				_panel.call("update_interaction_state", context)
		"workbench":
			var result: Dictionary = BaseWorkbenchServiceScript.purchase(_get_save_manager())
			if _panel != null and _panel.has_method("update_interaction_state"):
				var context := _workbench_panel_context()
				var prefix := "升級完成。" if bool(result.get("success", false)) else "升級失敗。"
				context["body"] = "%s\n%s" % [prefix, str(context.get("body", ""))]
				_panel.call("update_interaction_state", context)


func _on_raid_briefing_start_requested() -> void:
	if prepare_raid_loadout():
		_change_to_gameplay_scene.call_deferred()


func _on_raid_briefing_cancel_requested() -> void:
	_update_prompt()


func _refresh_points() -> void:
	_points.clear()
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("base_interaction_point"):
		var point := node as Node3D
		if point != null:
			_points.append(point)


func _update_nearest_point() -> void:
	_nearest_point = null
	if _player == null:
		return
	var best_distance := interaction_range
	for point in _points:
		var distance := _player.global_position.distance_to(point.global_position)
		if distance <= best_distance:
			best_distance = distance
			_nearest_point = point


func _update_prompt() -> void:
	if _prompt_label == null:
		return
	_prompt_label.visible = _nearest_point != null and not _is_any_panel_open()
	if _nearest_point == null:
		_prompt_label.text = ""
		return
	_prompt_label.global_position = _nearest_point.global_position + Vector3(0.0, 1.35, 0.0)
	var display_name := _display_name(_nearest_point)
	if str(_nearest_point.get_meta("interaction_id", "")) == "raid_gate":
		_prompt_label.text = "按 E 查看出擊簡報：%s" % display_name
	else:
		_prompt_label.text = "按 E 互動：%s" % display_name


func _find_point_by_id(interaction_id: String) -> Node3D:
	for point in _points:
		if str(point.get_meta("interaction_id", "")) == interaction_id:
			return point
	return null


func _display_name(point: Node) -> String:
	return str(point.get_meta("display_name_zh", "基地設施"))


func _is_any_panel_open() -> bool:
	return _is_interaction_panel_open() or _is_raid_briefing_open()


func _is_interaction_panel_open() -> bool:
	if _panel == null or not _panel.has_method("is_open"):
		return false
	return bool(_panel.call("is_open"))


func _is_raid_briefing_open() -> bool:
	if _raid_briefing_panel == null or not _raid_briefing_panel.has_method("is_open"):
		return false
	return bool(_raid_briefing_panel.call("is_open"))


func _get_save_manager() -> Node:
	if is_inside_tree():
		var manager := get_node_or_null("/root/SaveGameManager")
		if manager != null:
			return manager
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("SaveGameManager")
