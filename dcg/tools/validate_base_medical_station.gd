extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const MedicalServiceScript := preload("res://scripts/base/base_medical_service.gd")

const VALIDATION_SAVE_ROOT := "user://validation_base_medical_station"

var _errors: Array[String] = []
var _save_manager: Node = null
var _created_save_manager := false
var _original_save_root := ""
var _original_slot := 1


func _initialize() -> void:
	_setup_save_manager()
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	await _validate_medical_station(scene)
	_validate_source_boundaries()
	scene.queue_free()
	_restore_save_manager()
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	if _errors.is_empty():
		print("[base_medical_station] OK station=visible heal=works cost=deducted ui=zh boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_medical_station(scene: Node) -> void:
	var player := scene.get_node_or_null("Player3D") as Node
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	var point := _find_point(scene, "medical")
	if player == null or controller == null or point == null:
		_errors.append("Base medical validation requires Player3D, controller, and medical point.")
		return
	if str(point.get_meta("display_name_zh", "")) != "醫療站":
		_errors.append("Medical station should use readable Traditional Chinese display name.")
	var title_label := point.get_node_or_null("Label3D") as Label3D
	var hint_label := point.get_node_or_null("HintLabel3D") as Label3D
	if title_label == null or title_label.text != "醫療站":
		_errors.append("Medical station should show a 3D 醫療站 label.")
	if hint_label == null or not hint_label.text.contains("回復生命"):
		_errors.append("Medical station should show a 3D 回復生命 hint.")

	var maximum := float(player.call("get_total_max_health")) if player.has_method("get_total_max_health") else float(player.get("max_health"))
	player.set("health", maximum - 35.0)
	_save_manager.call("save_slot_data", 1, {
		"scene_path": "res://scenes/base/base_3d.tscn",
		"difficulty_id": "normal",
		"money": 25,
		"stash": [],
		"base_upgrades": {},
		"quests": {},
	})

	player.set("global_position", point.global_position)
	await process_frame
	var prompt := str(controller.call("get_current_prompt_text"))
	if not prompt.contains("按 E") or not prompt.contains("醫療站"):
		_errors.append("Medical station prompt should be readable, got `%s`." % prompt)
	if not bool(controller.call("open_interaction_by_id", "medical")):
		_errors.append("Medical station should open from BaseInteractionController3D.")
		return
	await process_frame
	var panel_state: Dictionary = controller.call("get_panel_state")
	if not bool(panel_state.get("visible", false)):
		_errors.append("Medical station panel should be visible.")
	if str(panel_state.get("title", "")) != "醫療站":
		_errors.append("Medical station panel title should be 醫療站.")
	if not str(panel_state.get("body", "")).contains("生命") or not str(panel_state.get("body", "")).contains("金錢"):
		_errors.append("Medical station panel should explain health and money state.")
	if not bool(panel_state.get("action_visible", false)) or not bool(panel_state.get("action_enabled", false)):
		_errors.append("Medical station action should be visible and enabled when damaged with enough money.")
	if not str(panel_state.get("action_text", "")).contains("治療"):
		_errors.append("Medical station action should read 治療.")

	var action_button := scene.get_node_or_null("HUD/BaseInteractionPanel/Panel/Margin/Content/ActionButton") as Button
	if action_button == null:
		_errors.append("Medical station should use a node-first ActionButton.")
		return
	action_button.pressed.emit()
	await process_frame
	var health_after := float(player.get("health"))
	if health_after < maximum - 0.01:
		_errors.append("Medical station should restore player health to full.")
	var save_after: Dictionary = _save_manager.call("get_slot_data", 1)
	if int(save_after.get("money", 0)) != 15:
		_errors.append("Medical station should deduct $10 from base money.")
	var healed_state: Dictionary = controller.call("get_panel_state")
	if not str(healed_state.get("body", "")).contains("治療完成"):
		_errors.append("Medical station should confirm treatment completion in the panel.")
	if bool(healed_state.get("action_enabled", true)):
		_errors.append("Medical station action should disable after health is full.")


func _validate_source_boundaries() -> void:
	var service_source := FileAccess.get_file_as_string("res://scripts/base/base_medical_service.gd")
	for required in ["HEAL_COST", "restore_health_to_full", "save_slot_data", "get_state"]:
		if not service_source.contains(required):
			_errors.append("BaseMedicalService should contain %s." % required)
	for forbidden in ["Control", "Button", "change_scene", "RaidSession", "WeaponController", "InventoryEquipmentUI"]:
		if service_source.contains(forbidden):
			_errors.append("BaseMedicalService should stay service-only and not depend on %s." % forbidden)
	var panel_source := FileAccess.get_file_as_string("res://scripts/base/base_interaction_panel.gd")
	for forbidden in ["SaveGameManager", "restore_health_to_full", "save_slot_data"]:
		if panel_source.contains(forbidden):
			_errors.append("BaseInteractionPanel should not own medical service behavior through %s." % forbidden)
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	if not player_source.contains("restore_health_to_full"):
		_errors.append("PlayerController3D should expose restore_health_to_full for base services.")


func _find_point(scene: Node, interaction_id: String) -> Node3D:
	for node in get_nodes_in_group("base_interaction_point"):
		var point := node as Node3D
		if point != null and str(point.get_meta("interaction_id", "")) == interaction_id:
			return point
	return null


func _setup_save_manager() -> void:
	_save_manager = root.get_node_or_null("SaveGameManager")
	if _save_manager == null:
		_save_manager = SaveGameManagerScript.new()
		_save_manager.name = "SaveGameManager"
		root.add_child(_save_manager)
		_created_save_manager = true
	_original_save_root = str(_save_manager.get("save_root_path"))
	if _save_manager.has_method("get_current_slot_index"):
		_original_slot = int(_save_manager.call("get_current_slot_index"))
	_save_manager.set("save_root_path", VALIDATION_SAVE_ROOT)
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	_save_manager.call("set_current_slot_index", 1)


func _restore_save_manager() -> void:
	if _save_manager == null:
		return
	_save_manager.set("save_root_path", _original_save_root)
	if _save_manager.has_method("set_current_slot_index"):
		_save_manager.call("set_current_slot_index", _original_slot)
	if _created_save_manager:
		_save_manager.queue_free()


func _cleanup_validation_root(save_root: String) -> void:
	var absolute := ProjectSettings.globalize_path(save_root)
	if DirAccess.dir_exists_absolute(absolute):
		OS.move_to_trash(absolute)
