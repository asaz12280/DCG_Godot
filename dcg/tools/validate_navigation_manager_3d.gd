extends SceneTree

const ScavengerScene := preload("res://scenes/enemies/scavenger_3d.tscn")
const RaidScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const NavigationManagerScript := preload("res://scripts/gameplay/navigation_manager_3d.gd")

var _errors: Array[String] = []


class FakePlayer:
	extends CharacterBody3D

	var health := 100.0

	func _init() -> void:
		add_to_group("player")

	func apply_damage(_event: DamageEvent) -> bool:
		return true

	func is_alive() -> bool:
		return health > 0.0


func _initialize() -> void:
	await _validate_dynamic_blocker_navigation()
	await _validate_raid_scene_navigation_manager()
	if _errors.is_empty():
		print("[navigation_manager_3d] OK blockers=rebake enemy=routes raid=wired")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_dynamic_blocker_navigation() -> void:
	var scene_root := Node3D.new()
	root.add_child(scene_root)
	var region := NavigationRegion3D.new()
	region.name = "ValidationNavigationRegion3D"
	scene_root.add_child(region)
	var blockers_root := Node3D.new()
	blockers_root.name = "Blockers"
	scene_root.add_child(blockers_root)

	for data in [
		{"name": "FenceA", "position": Vector3(-1.2, 0.6, 3.3), "size": Vector3(1.25, 1.2, 1.2)},
		{"name": "FenceB", "position": Vector3(0.0, 0.6, 3.3), "size": Vector3(1.25, 1.2, 1.2)},
		{"name": "FenceC", "position": Vector3(1.2, 0.6, 3.3), "size": Vector3(1.25, 1.2, 1.2)},
		{"name": "RockLeft", "position": Vector3(-3.0, 0.5, 2.2), "size": Vector3(1.0, 1.0, 1.0)},
		{"name": "CrateRight", "position": Vector3(3.0, 0.5, 4.8), "size": Vector3(1.0, 1.0, 1.0)},
	]:
		blockers_root.add_child(_create_box_blocker(str(data["name"]), data["position"], data["size"]))

	var manager := NavigationManagerScript.new()
	manager.name = "NavigationManager3D"
	scene_root.add_child(manager)
	manager.navigation_region_path = manager.get_path_to(region)
	manager.scope_root_path = manager.get_path_to(blockers_root)
	manager.bounds_min = Vector2(-5.0, -1.0)
	manager.bounds_max = Vector2(5.0, 7.0)
	manager.cell_size = 0.5
	manager.agent_radius = 0.45
	manager.rebuild_on_ready = false
	await process_frame
	if not bool(manager.call("rebuild_navigation")):
		_errors.append("NavigationManager3D should build a walkable navmesh from blocker geometry.")

	var debug_state: Dictionary = manager.call("get_navigation_debug_state")
	if int(debug_state.get("blockers", 0)) < 5:
		_errors.append("NavigationManager3D should read navigation_blocker nodes inside its scope.")
	if int(debug_state.get("walkable_polygons", 0)) <= 0:
		_errors.append("NavigationManager3D should leave walkable polygons after blocking clutter.")

	var enemy := ScavengerScene.instantiate()
	scene_root.add_child(enemy)
	var player := FakePlayer.new()
	scene_root.add_child(player)
	await process_frame
	await physics_frame
	await physics_frame

	enemy.global_position = Vector3(0.0, 0.0, 1.0)
	player.global_position = Vector3(0.0, 0.0, 6.0)
	var controller := enemy.get_node_or_null("EnemyController3D")
	if controller == null:
		_errors.append("Scavenger should include EnemyController3D for dynamic blocker routing.")
		_free_node(scene_root)
		return

	var start_position: Vector3 = enemy.global_position
	var saw_sideways_route := false
	for index in range(24):
		controller._physics_process(0.1)
		if absf(enemy.velocity.x) > 0.1:
			saw_sideways_route = true
		await physics_frame

	if not saw_sideways_route:
		_errors.append("Enemy should route sideways around dynamically registered blockers.")
	if enemy.global_position.distance_to(start_position) <= 0.4:
		_errors.append("Enemy should make progress instead of staying stuck after dynamic navmesh rebuild.")

	var moved_blocker := blockers_root.get_node_or_null("FenceB") as Node3D
	if moved_blocker != null:
		moved_blocker.global_position.x = 2.8
		manager._physics_process(1.0)
		var after_move_state: Dictionary = manager.call("get_navigation_debug_state")
		if int(after_move_state.get("blockers", 0)) < 5:
			_errors.append("NavigationManager3D should preserve blocker tracking after blocker movement.")

	_free_node(scene_root)


func _validate_raid_scene_navigation_manager() -> void:
	var raid := RaidScene.instantiate()
	root.add_child(raid)
	await process_frame
	await process_frame
	await physics_frame
	var manager := raid.get_node_or_null("NavigationManager3D")
	if manager == null or manager.get_script() != NavigationManagerScript:
		_errors.append("Normal Raid should include NavigationManager3D.")
		_free_node(raid)
		return
	var debug_state: Dictionary = manager.call("get_navigation_debug_state")
	if int(debug_state.get("blockers", 0)) < 8:
		_errors.append("Normal Raid NavigationManager3D should gather blocking props, ropes, and containers.")
	if int(debug_state.get("walkable_polygons", 0)) <= 0:
		_errors.append("Normal Raid NavigationManager3D should build walkable polygons.")
	_free_node(raid)


func _create_box_blocker(blocker_name: String, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = blocker_name
	body.add_to_group("navigation_blocker")
	body.position = position
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	return body


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
