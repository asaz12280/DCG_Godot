class_name BaseInteractionController3D
extends Node

const GAMEPLAY_SCENE := "res://scenes/gameplay/player_test_world_3d.tscn"
const RaidLoadoutTransferScript := preload("res://scripts/raid/raid_loadout_transfer.gd")
const BaseWorkbenchServiceScript := preload("res://scripts/base/base_workbench_service.gd")
const QuestBoardScript := preload("res://scripts/base/base_interaction_quest_board.gd")

const INTERACTION_NAME_KEYS := {
	"stash": &"ui.base.station.stash",
	"quests": &"ui.base.station.quests",
	"workbench": &"ui.base.station.workbench",
	"raid_gate": &"ui.base.station.raid_gate",
}
const INTERACTION_HINT_KEYS := {
	"stash": &"ui.base.station.stash_hint",
	"quests": &"ui.base.station.quests_hint",
	"workbench": &"ui.base.station.workbench_hint",
	"raid_gate": &"ui.base.station.raid_gate_hint",
}

@export_node_path("Node3D") var player_path: NodePath
@export_node_path("Label3D") var prompt_label_path: NodePath
@export_node_path("Control") var panel_path: NodePath
@export_node_path("Control") var stash_panel_path: NodePath
@export var interaction_range := 1.8

var _player: Node3D
var _prompt_label: Label3D
var _panel: Control
var _stash_panel: Control
var _points: Array[Node3D] = []
var _nearest_point: Node3D
var _last_prepared_raid_loadout: Dictionary = {}
var _workbench_station_mode := "craft"


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_prompt_label = get_node_or_null(prompt_label_path) as Label3D
	_panel = get_node_or_null(panel_path) as Control
	_stash_panel = get_node_or_null(stash_panel_path) as Control
	_connect_interaction_panel()
	_refresh_points()
	_apply_point_localization()
	_update_prompt()


func _process(_delta: float) -> void:
	_update_nearest_point()
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _is_any_panel_open():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			if _is_stash_panel_open():
				_stash_panel.call("close_stash")
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
		return _start_raid_from_gate()
	if interaction_id == "stash":
		return _open_stash_station()
	if interaction_id == "workbench":
		return _open_workbench_station(display_name)
	if interaction_id == "quests":
		return _open_quest_station(display_name)
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
	if _is_stash_panel_open() and _stash_panel.has_method("get_display_state"):
		return _stash_panel.call("get_display_state")
	var quest_panel := _quest_panel()
	if quest_panel != null and quest_panel.has_method("get_display_state"):
		var quest_state: Dictionary = quest_panel.call("get_display_state")
		if bool(quest_state.get("visible", false)):
			return quest_state
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


func _change_to_gameplay_scene() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.change_scene_to_file(GAMEPLAY_SCENE)


func _start_raid_from_gate() -> bool:
	_close_active_gameplay_ui()
	if not prepare_raid_loadout():
		return false
	_change_to_gameplay_scene.call_deferred()
	return true


func _open_workbench_station(display_name: String) -> bool:
	if _panel == null or not _panel.has_method("open_interaction"):
		return false
	_close_active_gameplay_ui()
	_workbench_station_mode = BaseWorkbenchServiceScript.STATION_MODE_CRAFT
	_panel.call("open_interaction", "workbench", display_name, _workbench_panel_context())
	return true


func _open_quest_station(display_name: String) -> bool:
	if _is_interaction_panel_open():
		_panel.call("close_panel")
	if _is_stash_panel_open():
		_stash_panel.call("close_stash")
	var ui_manager := get_node_or_null("/root/UIManager") if is_inside_tree() else null
	if ui_manager != null and ui_manager.has_method("open_ui"):
		ui_manager.call("open_ui", &"quests")
		return str(ui_manager.call("get_active_ui")) == "quests"
	var quest_panel := _quest_panel()
	if quest_panel == null or not quest_panel.has_method("open_quests"):
		return false
	quest_panel.call("open_quests")
	return true


func _open_stash_station() -> bool:
	if _stash_panel == null or not _stash_panel.has_method("open_stash"):
		return false
	_close_active_gameplay_ui()
	if _is_interaction_panel_open():
		_panel.call("close_panel")
	var ui_manager := get_node_or_null("/root/UIManager") if is_inside_tree() else null
	if ui_manager != null and ui_manager.has_method("open_stash_inventory"):
		return bool(ui_manager.call("open_stash_inventory", _player, _get_save_manager()))
	return bool(_stash_panel.call("open_stash", _player, _get_save_manager()))


func _workbench_panel_context() -> Dictionary:
	return BaseWorkbenchServiceScript.get_panel_context(_get_save_manager(), StringName(_workbench_station_mode), _player)


func _quest_panel_context() -> Dictionary:
	return QuestBoardScript.panel_context(self, _get_save_manager())


func _connect_interaction_panel() -> void:
	if _panel == null or not _panel.has_signal("action_requested"):
		return
	var action_callable := Callable(self, "_on_interaction_panel_action_requested")
	if not _panel.is_connected("action_requested", action_callable):
		_panel.connect("action_requested", action_callable)
	if _panel.has_signal("recipe_selected"):
		var recipe_callable := Callable(self, "_on_interaction_panel_recipe_selected")
		if not _panel.is_connected("recipe_selected", recipe_callable):
			_panel.connect("recipe_selected", recipe_callable)
	if _panel.has_signal("station_mode_selected"):
		var station_mode_callable := Callable(self, "_on_interaction_panel_station_mode_selected")
		if not _panel.is_connected("station_mode_selected", station_mode_callable):
			_panel.connect("station_mode_selected", station_mode_callable)
	if _panel.has_signal("blueprint_selected"):
		var blueprint_callable := Callable(self, "_on_interaction_panel_blueprint_selected")
		if not _panel.is_connected("blueprint_selected", blueprint_callable):
			_panel.connect("blueprint_selected", blueprint_callable)
	if _panel.has_signal("repair_selected"):
		var repair_callable := Callable(self, "_on_interaction_panel_repair_selected")
		if not _panel.is_connected("repair_selected", repair_callable):
			_panel.connect("repair_selected", repair_callable)
	if _panel.has_signal("dismantle_selected"):
		var dismantle_callable := Callable(self, "_on_interaction_panel_dismantle_selected")
		if not _panel.is_connected("dismantle_selected", dismantle_callable):
			_panel.connect("dismantle_selected", dismantle_callable)


func _on_interaction_panel_action_requested(interaction_id: String) -> void:
	match interaction_id:
		"quests":
			var result := _execute_quest_board_action()
			if _panel != null and _panel.has_method("update_interaction_state"):
				var context := _quest_panel_context()
				if not bool(result.get("success", false)):
					context["body"] = "%s\n%s" % [
						_localized_text(&"ui.base.quest_action_failed", "Quest action failed."),
						str(context.get("body", "")),
					]
				_panel.call("update_interaction_state", context)
		"workbench":
			var result: Dictionary = BaseWorkbenchServiceScript.execute_action(_get_save_manager(), StringName(_workbench_station_mode), _player)
			if _panel != null and _panel.has_method("update_interaction_state"):
				var context := _workbench_panel_context()
				var prefix := _localized_text(&"ui.base.workbench_upgrade_done", "Upgrade complete.") if bool(result.get("success", false)) else _localized_text(&"ui.base.workbench_upgrade_failed_short", "Upgrade failed.")
				if str(result.get("action_type", "upgrade")) == "craft":
					prefix = _localized_text(&"ui.base.workbench_craft_done", "Craft complete.") if bool(result.get("success", false)) else _localized_text(&"ui.base.workbench_craft_failed_short", "Craft failed.")
				elif str(result.get("action_type", "upgrade")) == "blueprint_research":
					prefix = _localized_text(&"ui.base.workbench_blueprint_research_done", "Blueprint research complete.") if bool(result.get("success", false)) else _localized_text(&"ui.base.workbench_blueprint_research_failed_short", "Blueprint research failed.")
				elif str(result.get("action_type", "upgrade")) == "repair":
					prefix = _localized_text(&"ui.base.workbench_repair_done", "Repair complete.") if bool(result.get("success", false)) else _localized_text(&"ui.base.workbench_repair_failed_short", "Repair failed.")
				elif str(result.get("action_type", "upgrade")) == "dismantle":
					prefix = _localized_text(&"ui.base.workbench_dismantle_done", "Dismantle complete.") if bool(result.get("success", false)) else _localized_text(&"ui.base.workbench_dismantle_failed_short", "Dismantle failed.")
				context["body"] = "%s\n%s" % [prefix, str(context.get("body", ""))]
				_panel.call("update_interaction_state", context)


func _execute_quest_board_action() -> Dictionary:
	return QuestBoardScript.execute_action(self, _panel, _get_save_manager())


func _on_interaction_panel_recipe_selected(interaction_id: String, recipe_id: String) -> void:
	if interaction_id != "workbench" or recipe_id == "":
		return
	_workbench_station_mode = BaseWorkbenchServiceScript.STATION_MODE_CRAFT
	var result: Dictionary = BaseWorkbenchServiceScript.select_recipe(_get_save_manager(), StringName(recipe_id))
	if _panel != null and _panel.has_method("update_interaction_state"):
		var context := _workbench_panel_context()
		if not bool(result.get("success", false)):
			context["body"] = "%s\n%s" % [
				_localized_text(&"ui.base.workbench_recipe_select_failed", "Recipe unavailable."),
				str(context.get("body", "")),
			]
		_panel.call("update_interaction_state", context)


func _on_interaction_panel_station_mode_selected(interaction_id: String, mode_id: String) -> void:
	if interaction_id != "workbench" or mode_id == "":
		return
	if mode_id != BaseWorkbenchServiceScript.STATION_MODE_CRAFT and mode_id != BaseWorkbenchServiceScript.STATION_MODE_BLUEPRINTS and mode_id != BaseWorkbenchServiceScript.STATION_MODE_REPAIR and mode_id != BaseWorkbenchServiceScript.STATION_MODE_DISMANTLE:
		return
	_workbench_station_mode = mode_id
	if _panel != null and _panel.has_method("update_interaction_state"):
		_panel.call("update_interaction_state", _workbench_panel_context())


func _on_interaction_panel_blueprint_selected(interaction_id: String, blueprint_item_path: String) -> void:
	if interaction_id != "workbench" or blueprint_item_path == "":
		return
	_workbench_station_mode = BaseWorkbenchServiceScript.STATION_MODE_BLUEPRINTS
	var result: Dictionary = BaseWorkbenchServiceScript.research_blueprint(_get_save_manager(), blueprint_item_path)
	if _panel != null and _panel.has_method("update_interaction_state"):
		var context := _workbench_panel_context()
		var prefix := _localized_text(&"ui.base.workbench_blueprint_research_done", "Blueprint research complete.") if bool(result.get("success", false)) else _localized_text(&"ui.base.workbench_blueprint_research_failed_short", "Blueprint research failed.")
		context["body"] = "%s\n%s" % [prefix, str(context.get("body", ""))]
		_panel.call("update_interaction_state", context)


func _on_interaction_panel_repair_selected(interaction_id: String, repair_id: String) -> void:
	if interaction_id != "workbench" or repair_id == "":
		return
	_workbench_station_mode = BaseWorkbenchServiceScript.STATION_MODE_REPAIR
	var result: Dictionary = BaseWorkbenchServiceScript.select_repair_item(_get_save_manager(), StringName(repair_id), _player)
	if _panel != null and _panel.has_method("update_interaction_state"):
		var context := _workbench_panel_context()
		if not bool(result.get("success", false)):
			context["body"] = "%s\n%s" % [
				_localized_text(&"ui.base.workbench_repair_select_failed", "Repair item unavailable."),
				str(context.get("body", "")),
			]
		_panel.call("update_interaction_state", context)


func _on_interaction_panel_dismantle_selected(interaction_id: String, dismantle_id: String) -> void:
	if interaction_id != "workbench" or dismantle_id == "":
		return
	_workbench_station_mode = BaseWorkbenchServiceScript.STATION_MODE_DISMANTLE
	var result: Dictionary = BaseWorkbenchServiceScript.select_dismantle_item(_get_save_manager(), StringName(dismantle_id))
	if _panel != null and _panel.has_method("update_interaction_state"):
		var context := _workbench_panel_context()
		if not bool(result.get("success", false)):
			context["body"] = "%s\n%s" % [
				_localized_text(&"ui.base.workbench_dismantle_select_failed", "Dismantle item unavailable."),
				str(context.get("body", "")),
			]
		_panel.call("update_interaction_state", context)


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
		_prompt_label.text = _localized_text(&"prompt.start_raid_format", "Press E to raid: %s") % display_name
	else:
		_prompt_label.text = _localized_text(&"prompt.base_interact_format", "Press E: %s") % display_name


func _find_point_by_id(interaction_id: String) -> Node3D:
	for point in _points:
		if str(point.get_meta("interaction_id", "")) == interaction_id:
			return point
	return null


func _display_name(point: Node) -> String:
	var interaction_id := str(point.get_meta("interaction_id", ""))
	var key: StringName = INTERACTION_NAME_KEYS.get(interaction_id, &"")
	return _localized_text(key, str(point.get_meta("display_name_zh", _localized_text(&"ui.base.station.default", "Base station"))))


func _is_any_panel_open() -> bool:
	return _is_interaction_panel_open() or _is_stash_panel_open()


func _is_interaction_panel_open() -> bool:
	if _panel == null or not _panel.has_method("is_open"):
		return false
	return bool(_panel.call("is_open"))


func _is_stash_panel_open() -> bool:
	if _stash_panel == null or not _stash_panel.has_method("is_open"):
		return false
	return bool(_stash_panel.call("is_open"))


func _quest_panel() -> Control:
	var scene := get_tree().current_scene if is_inside_tree() and get_tree() != null else null
	if scene != null:
		return scene.find_child("QuestTopMenuPanel", true, false) as Control
	if is_inside_tree():
		return get_node_or_null("../HUD/QuestTopMenuPanel") as Control
	return null


func _close_active_gameplay_ui() -> void:
	var ui_manager := get_node_or_null("/root/UIManager") if is_inside_tree() else null
	if ui_manager != null and ui_manager.has_method("close_active_ui") and str(ui_manager.call("get_active_ui")) != "":
		ui_manager.call("close_active_ui")


func _get_save_manager() -> Node:
	if is_inside_tree():
		var manager := get_node_or_null("/root/SaveGameManager")
		if manager != null:
			return manager
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("SaveGameManager")


func _on_localization_changed() -> void:
	_apply_point_localization()
	_update_prompt()
	if _stash_panel != null and _stash_panel.has_method("refresh_localization"):
		_stash_panel.call("refresh_localization")


func _apply_point_localization() -> void:
	for point in _points:
		var interaction_id := str(point.get_meta("interaction_id", ""))
		var name_label := point.get_node_or_null("Label3D") as Label3D
		if name_label != null:
			name_label.text = _display_name(point)
		var hint_label := point.get_node_or_null("HintLabel3D") as Label3D
		if hint_label != null:
			var key: StringName = INTERACTION_HINT_KEYS.get(interaction_id, &"")
			hint_label.text = _localized_text(key, hint_label.text)


func _localized_text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	if key_text == "":
		return fallback
	var translated := tr(key_text)
	return fallback if translated == key_text or translated == "" else translated
