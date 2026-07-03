extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")

const VALIDATION_SAVE_ROOT := "user://validation_quest_kill_enemy_flow"
const KILL_QUEST_ID := "first_scavenger_hunt"
const ENEMY_ID := "scavenger"

var _errors: Array[String] = []
var _original_save_root := ""
var _original_slot := 1


func _initialize() -> void:
	await _validate_kill_updates_open_top_menu_quest_page()
	_validate_source_boundaries()
	_restore_save_manager()
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	if _errors.is_empty():
		print("[quest_kill_enemy_flow] OK enemy=normal_raid kill=saves_progress top_menu=live_update boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_kill_updates_open_top_menu_quest_page() -> void:
	var save_manager := _save_manager()
	if save_manager == null:
		_errors.append("SaveGameManager autoload should exist for kill quest flow.")
		return
	_prepare_save_manager(save_manager)

	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var ui_manager := root.get_node_or_null("UIManager")
	var quest_panel := scene.get_node_or_null("HUD/QuestTopMenuPanel")
	var raid_hud := scene.get_node_or_null("HUD/RaidHudPanel")
	var enemy := scene.get_node_or_null("SceneProps/ScavengerPatrol01")
	if ui_manager == null or quest_panel == null or enemy == null:
		_errors.append("Normal Raid scene should include UIManager, QuestTopMenuPanel, and ScavengerPatrol01.")
		_free_node(scene)
		return

	ui_manager.call("open_ui", &"quests")
	await process_frame
	var before_state: Dictionary = quest_panel.call("get_display_state")
	var before_quest := _quest_summary(before_state, KILL_QUEST_ID)
	if before_quest.is_empty():
		_errors.append("Top-menu quest page should show First Scavenger Hunt before the kill.")
	elif str(before_quest.get("state", "")) != QuestStateScript.STATE_ACTIVE:
		_errors.append("Kill quest should start active before the enemy is killed.")
	if not bool(before_state.get("visible", false)) or not bool(before_state.get("is_open", false)):
		_errors.append("Top-menu quest page should be visibly open before validating live progress.")

	if raid_hud != null and raid_hud.has_method("get_display_state"):
		var hud_state: Dictionary = raid_hud.call("get_display_state")
		var hud_text := "%s\n%s\n%s" % [
			hud_state.get("goal_title", ""),
			hud_state.get("objective", ""),
			hud_state.get("status", ""),
		]
		if hud_text.contains(KILL_QUEST_ID) or hud_text.contains("first_scavenger_hunt"):
			_errors.append("Raid HUD should not expose kill quest internals; detailed quest progress belongs in Top Menu.")

	var tracker := enemy.get_node_or_null("QuestKillTracker3D")
	if tracker == null:
		_errors.append("Normal Raid Scavenger should include QuestKillTracker3D.")
	else:
		enemy.apply_damage(DamageEventScript.new(999.0, null, null, [&"validation"]))
	await process_frame
	await process_frame

	var save_data: Dictionary = save_manager.call("get_slot_data", 1)
	var quest_state := _saved_quest_state(save_data, KILL_QUEST_ID)
	var progress: Dictionary = quest_state.get("progress", {}) as Dictionary
	var progress_key := QuestStateScript.kill_progress_key(ENEMY_ID)
	if int(progress.get(progress_key, 0)) != 1:
		_errors.append("Killing the normal Raid Scavenger should persist kill:scavenger progress.")
	if str(quest_state.get("state", "")) != QuestStateScript.STATE_READY:
		_errors.append("Killing one Scavenger should mark First Scavenger Hunt ready in save data.")

	var after_state: Dictionary = quest_panel.call("get_display_state")
	var after_quest := _quest_summary(after_state, KILL_QUEST_ID)
	if after_quest.is_empty():
		_errors.append("Top-menu quest page should still show First Scavenger Hunt after the kill.")
	else:
		if str(after_quest.get("state", "")) != QuestStateScript.STATE_READY:
			_errors.append("Open top-menu quest page should refresh to ready after the enemy kill.")
		if not str(after_quest.get("progress", "")).contains("1/1"):
			_errors.append("Open top-menu quest page should show 1/1 kill progress after the enemy kill.")
		if str(after_quest.get("status", "")).strip_edges() == "":
			_errors.append("Open top-menu quest page should show a readable status after the enemy kill.")

	_free_node(scene)


func _validate_source_boundaries() -> void:
	var tracker_source := FileAccess.get_file_as_string("res://scripts/quests/quest_kill_tracker_3d.gd")
	for required in ["update_from_enemy_killed", "get_current_slot_index", "save_slot_data"]:
		if not tracker_source.contains(required):
			_errors.append("QuestKillTracker3D should update save-backed quest state through %s." % required)
	for forbidden in ["QuestTopMenuPanel", "BaseScreen", "change_scene", "PlayerHud3D"]:
		if tracker_source.contains(forbidden):
			_errors.append("QuestKillTracker3D should not hard-reference display or scene flow: %s." % forbidden)

	var panel_source := FileAccess.get_file_as_string("res://scripts/ui/quest_top_menu_panel.gd")
	for required in ["slot_saved", "refresh", "BaseScreenViewModelScript.quest_defs"]:
		if not panel_source.contains(required):
			_errors.append("QuestTopMenuPanel should refresh from save/model state through %s." % required)
	for forbidden in ["save_slot_data", "QuestKillTracker3D", "ScavengerPatrol01", "WeaponController3D"]:
		if panel_source.contains(forbidden):
			_errors.append("QuestTopMenuPanel should not mutate or hard-reference gameplay kill flow: %s." % forbidden)


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
