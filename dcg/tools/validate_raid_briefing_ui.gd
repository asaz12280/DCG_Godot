extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")

const BASE_3D_SCENE := "res://scenes/base/base_3d.tscn"
const GAMEPLAY_SCENE := "res://scenes/gameplay/player_test_world_3d.tscn"
const CONTROLLER_SOURCE := "res://scripts/base/base_interaction_controller_3d.gd"
const BASE_SCENE_SOURCE := "res://scenes/base/base_3d.tscn"

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_raid_gate_direct_start()
	_validate_ownership_boundaries()
	if _errors.is_empty():
		print("[raid_gate_direct_start] OK briefing=removed gate=direct_start gameplay=loaded boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_raid_gate_direct_start() -> void:
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait_frames(3)

	if scene.scene_file_path != BASE_3D_SCENE:
		_errors.append("Validation should start from Base3D.")
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	if controller == null:
		_errors.append("Base3D should include BaseInteractionController3D.")
		_free_current_scene()
		return
	if scene.get_node_or_null("HUD/RaidBriefingPanel") != null:
		_errors.append("Base3D raid gate should not include the removed briefing panel.")
		_free_current_scene()
		return

	if not bool(controller.call("open_interaction_by_id", "raid_gate")):
		_errors.append("Raid gate should directly start the raid.")
		_free_current_scene()
		return
	var prepared_loadout: Dictionary = controller.call("get_last_prepared_raid_loadout")
	if prepared_loadout.is_empty():
		_errors.append("Raid gate should prepare loadout before changing to gameplay.")
	await _wait_frames(14)

	if current_scene == null:
		_errors.append("Starting the raid gate should leave a loaded current scene.")
	elif current_scene.scene_file_path != GAMEPLAY_SCENE:
		_errors.append("Starting the raid gate should load gameplay, got `%s`." % current_scene.scene_file_path)
	else:
		var player := current_scene.get_node_or_null("Player3D")
		var enemy := _find_visible_enemy(current_scene)
		if player == null:
			_errors.append("Gameplay scene after raid gate should include Player3D.")
		if enemy == null:
			_errors.append("Gameplay scene after raid gate should still include the visible 3D enemy.")

	_free_current_scene()


func _validate_ownership_boundaries() -> void:
	var controller_source := FileAccess.get_file_as_string(CONTROLLER_SOURCE)
	var base_scene := FileAccess.get_file_as_string(BASE_SCENE_SOURCE)
	for required in ["_start_raid_from_gate", "prepare_raid_loadout", "set_pending_raid_loadout", "change_scene_to_file"]:
		if not controller_source.contains(required):
			_errors.append("BaseInteractionController3D should own raid gate transition term: %s." % required)
	for forbidden in ["open_briefing", "RaidBriefingPanel", "raid_briefing_panel_path"]:
		if controller_source.contains(forbidden) or base_scene.contains(forbidden):
			_errors.append("Raid gate should not keep briefing coupling: %s." % forbidden)


func _find_visible_enemy(root_node: Node) -> Node:
	if root_node == null:
		return null
	if root_node.name.to_lower().contains("scavenger") or root_node.name.to_lower().contains("enemy"):
		return root_node
	for child in root_node.get_children():
		var found := _find_visible_enemy(child)
		if found != null:
			return found
	return null


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _free_current_scene() -> void:
	var scene := current_scene
	current_scene = null
	if scene == null or not is_instance_valid(scene):
		return
	if scene.get_parent() != null:
		scene.get_parent().remove_child(scene)
	scene.queue_free()
