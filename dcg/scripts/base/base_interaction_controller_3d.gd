class_name BaseInteractionController3D
extends Node

const GAMEPLAY_SCENE := "res://scenes/gameplay/player_test_world_3d.tscn"
const RaidLoadoutTransferScript := preload("res://scripts/raid/raid_loadout_transfer.gd")

@export_node_path("Node3D") var player_path: NodePath
@export_node_path("Label3D") var prompt_label_path: NodePath
@export_node_path("Control") var panel_path: NodePath
@export var interaction_range := 1.8

var _player: Node3D
var _prompt_label: Label3D
var _panel: Control
var _points: Array[Node3D] = []
var _nearest_point: Node3D
var _last_prepared_raid_loadout: Dictionary = {}


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_prompt_label = get_node_or_null(prompt_label_path) as Label3D
	_panel = get_node_or_null(panel_path) as Control
	_refresh_points()
	_update_prompt()


func _process(_delta: float) -> void:
	_update_nearest_point()
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _is_panel_open():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
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
		prepare_raid_loadout()
		get_tree().change_scene_to_file(GAMEPLAY_SCENE)
		return true
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
	_prompt_label.visible = _nearest_point != null and not _is_panel_open()
	if _nearest_point == null:
		_prompt_label.text = ""
		return
	_prompt_label.global_position = _nearest_point.global_position + Vector3(0.0, 1.35, 0.0)
	var display_name := _display_name(_nearest_point)
	if str(_nearest_point.get_meta("interaction_id", "")) == "raid_gate":
		_prompt_label.text = "按 E 開始出擊：%s" % display_name
	else:
		_prompt_label.text = "按 E 開啟：%s" % display_name


func _find_point_by_id(interaction_id: String) -> Node3D:
	for point in _points:
		if str(point.get_meta("interaction_id", "")) == interaction_id:
			return point
	return null


func _display_name(point: Node) -> String:
	return str(point.get_meta("display_name_zh", "基地互動"))


func _is_panel_open() -> bool:
	if _panel == null or not _panel.has_method("is_open"):
		return false
	return bool(_panel.call("is_open"))


func _get_save_manager() -> Node:
	if is_inside_tree():
		var manager := get_node_or_null("/root/SaveGameManager")
		if manager != null:
			return manager
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("SaveGameManager")
