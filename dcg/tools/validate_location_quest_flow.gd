extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")

const VALIDATION_SAVE_ROOT := "user://validation_location_quest_flow"
const LOCATION_QUEST_ID := "radio_tower_scout"
const LOCATION_ID := "radio_tower"

var _errors: Array[String] = []
var _original_save_root := ""
var _original_slot := 1


func _initialize() -> void:
	await _validate_location_interaction_updates_top_menu_quest_page()
	_validate_source_boundaries()
	_restore_save_manager()
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	if _errors.is_empty():
		print("[location_quest_flow] OK location=visible interact=saves_progress top_menu=live_update boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_location_interaction_updates_top_menu_quest_page() -> void:
	var save_manager := _save_manager()
	if save_manager == null:
		_errors.append("SaveGameManager autoload should exist for location quest flow.")
		return
	_prepare_save_manager(save_manager)

	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var ui_manager := root.get_node_or_null("UIManager")
	var quest_panel := scene.get_node_or_null("HUD/QuestTopMenuPanel")
	var player := scene.get_node_or_null("Player3D")
	var location_point := scene.get_node_or_null("SceneProps/RadioTowerQuestPoint")
	if ui_manager == null or quest_panel == null or player == null or location_point == null:
		_errors.append("Normal Raid scene should include UIManager, QuestTopMenuPanel, Player3D, and RadioTowerQuestPoint.")
		_free_node(scene)
		return
	if not location_point.is_in_group("location_quest_point"):
		_errors.append("RadioTowerQuestPoint should be in location_quest_point group for validation and future tools.")
	if not location_point.has_method("try_record_location") or not location_point.has_method("get_state"):
		_errors.append("RadioTowerQuestPoint should expose try_record_location and get_state.")

	var point_state: Dictionary = location_point.call("get_state")
	if str(point_state.get("location_id", "")) != LOCATION_ID:
		_errors.append("RadioTowerQuestPoint should expose radio_tower location id.")
	if str(point_state.get("prompt_text", "")).contains("Open") or str(point_state.get("prompt_text", "")).contains("Interact"):
		_errors.append("RadioTowerQuestPoint prompt should be player-readable Traditional Chinese, not English fallback.")
	if location_point.get_node_or_null("PromptLabel") == null or location_point.get_node_or_null("ZoneMarker") == null or location_point.get_node_or_null("TowerMarker") == null:
		_errors.append("RadioTowerQuestPoint should have visible prompt, zone marker, and tower marker nodes.")

	ui_manager.call("open_ui", &"quests")
	await process_frame
	var before_state: Dictionary = quest_panel.call("get_display_state")
	var before_quest := _quest_summary(before_state, LOCATION_QUEST_ID)
	if before_quest.is_empty():
		_errors.append("Top-menu quest page should show the radio tower location quest before interaction.")
	else:
		if str(before_quest.get("state", "")) != QuestStateScript.STATE_ACTIVE:
			_errors.append("Location quest should start active before the player records the location.")
		if not str(before_quest.get("progress", "")).contains("0/1"):
			_errors.append("Location quest should show 0/1 before interaction.")
		if not str(before_quest.get("objective", "")).contains("訊號塔"):
			_errors.append("Location quest objective should name the signal tower in Traditional Chinese.")
	if not bool(before_state.get("visible", false)) or not bool(before_state.get("is_open", false)):
		_errors.append("Top-menu quest page should be visibly open before validating live progress.")

	if location_point.has_method("try_record_location"):
		location_point.call("try_record_location", player)
	await process_frame
	await process_frame

	var save_data: Dictionary = save_manager.call("get_slot_data", 1)
	var quest_state := _saved_quest_state(save_data, LOCATION_QUEST_ID)
	var progress: Dictionary = quest_state.get("progress", {}) as Dictionary
	var progress_key := QuestStateScript.location_progress_key(LOCATION_ID)
	if int(progress.get(progress_key, 0)) != 1:
		_errors.append("Interacting with RadioTowerQuestPoint should persist location:radio_tower progress.")
	if str(quest_state.get("state", "")) != QuestStateScript.STATE_READY:
		_errors.append("Recording the radio tower should mark the location quest ready in save data.")

	var after_state: Dictionary = quest_panel.call("get_display_state")
	var after_quest := _quest_summary(after_state, LOCATION_QUEST_ID)
	if after_quest.is_empty():
		_errors.append("Top-menu quest page should still show the radio tower quest after interaction.")
	else:
		if str(after_quest.get("state", "")) != QuestStateScript.STATE_READY:
			_errors.append("Open top-menu quest page should refresh to ready after location interaction.")
		if not str(after_quest.get("progress", "")).contains("1/1"):
			_errors.append("Open top-menu quest page should show 1/1 location progress after interaction.")
		if str(after_quest.get("status", "")).strip_edges() == "":
			_errors.append("Open top-menu quest page should show a readable status after location interaction.")

	point_state = location_point.call("get_state")
	if not bool(point_state.get("has_recorded", false)):
		_errors.append("RadioTowerQuestPoint should expose recorded state after successful interaction.")
	if not str(point_state.get("prompt_text", "")).contains("已記錄"):
		_errors.append("RadioTowerQuestPoint should show a completed prompt after interaction.")

	_free_node(scene)


func _validate_source_boundaries() -> void:
	var trigger_source := FileAccess.get_file_as_string("res://scripts/quests/location_quest_trigger_3d.gd")
	for required in ["update_from_location_reached", "get_current_slot_index", "save_slot_data"]:
		if not trigger_source.contains(required):
			_errors.append("LocationQuestTrigger3D should update save-backed quest state through %s." % required)
	for forbidden in ["QuestTopMenuPanel", "BaseScreen", "change_scene", "PlayerHud3D", "WeaponController3D", "InventoryModel", "LootContainer3D"]:
		if trigger_source.contains(forbidden):
			_errors.append("LocationQuestTrigger3D should not hard-reference display, scene flow, or inventory combat state: %s." % forbidden)

	var panel_source := FileAccess.get_file_as_string("res://scripts/ui/quest_top_menu_panel.gd")
	for required in ["slot_saved", "refresh", "BaseScreenViewModelScript.quest_defs"]:
		if not panel_source.contains(required):
			_errors.append("QuestTopMenuPanel should refresh location quest from save/model state through %s." % required)
	for forbidden in ["save_slot_data", "LocationQuestTrigger3D", "RadioTowerQuestPoint", "WeaponController3D"]:
		if panel_source.contains(forbidden):
			_errors.append("QuestTopMenuPanel should not mutate or hard-reference gameplay location flow: %s." % forbidden)

	var view_model_source := FileAccess.get_file_as_string("res://scripts/base/base_screen_view_model.gd")
	for required in ["radio_tower_scout", "location_progress_key", "quest_location_objective", "location_name"]:
		if not view_model_source.contains(required):
			_errors.append("BaseScreenViewModel should expose location quest display through %s." % required)

	var scene_text := FileAccess.get_file_as_string("res://scenes/gameplay/player_test_world_3d.tscn")
	for required in ["RadioTowerQuestPoint", "location_quest_point", "按 E 調查訊號塔", "ZoneMarker", "TowerMarker"]:
		if not scene_text.contains(required):
			_errors.append("Normal Raid scene should make the location quest point player-visible through %s." % required)


func _prepare_save_manager(save_manager: Node) -> void:
	_original_save_root = str(save_manager.get("save_root_path"))
	if save_manager.has_method("get_current_slot_index"):
		_original_slot = int(save_manager.call("get_current_slot_index"))
	save_manager.set("save_root_path", VALIDATION_SAVE_ROOT)
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	save_manager.call("set_current_slot_index", 1)
	save_manager.call("save_slot_data", 1, {
		"difficulty_id": "normal",
		"money": 0,
		"stash": [],
		"base_upgrades": {},
		"quests": {},
	})


func _restore_save_manager() -> void:
	var save_manager := _save_manager()
	if save_manager == null:
		return
	if _original_save_root != "":
		save_manager.set("save_root_path", _original_save_root)
	if save_manager.has_method("set_current_slot_index"):
		save_manager.call("set_current_slot_index", _original_slot)


func _save_manager() -> Node:
	return root.get_node_or_null("SaveGameManager")


func _saved_quest_state(save_data: Dictionary, quest_id: String) -> Dictionary:
	var quests: Dictionary = save_data.get("quests", {}) as Dictionary
	return quests.get(quest_id, {}) as Dictionary


func _quest_summary(display_state: Dictionary, quest_id: String) -> Dictionary:
	var quests: Array = display_state.get("quests", []) as Array
	for entry in quests:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var summary := entry as Dictionary
		if str(summary.get("id", "")) == quest_id:
			return summary
	return {}


func _cleanup_validation_root(root_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(root_path)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute("%s/slot_1.json" % absolute)
		DirAccess.remove_absolute("%s/slot_2.json" % absolute)
		DirAccess.remove_absolute("%s/slot_3.json" % absolute)
		DirAccess.remove_absolute(absolute)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
