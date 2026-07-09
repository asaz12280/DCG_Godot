extends SceneTree

const RaidScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const EnemyControllerScript := preload("res://scripts/ai/enemy_controller_3d.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_normal_raid_enemy_chases_player()
	if _errors.is_empty():
		print("[enemy_chase_player] OK raid=normal detects=player chases=true nav=routes status=visible search_then_idle=true")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_normal_raid_enemy_chases_player() -> void:
	var raid := RaidScene.instantiate()
	root.add_child(raid)
	await process_frame
	await process_frame
	await physics_frame

	var player := raid.get_node_or_null("Player3D") as Node3D
	if player == null:
		_errors.append("Normal Raid scene should include Player3D for enemy chase validation.")
		_free_node(raid)
		return

	var enemy := _first_raid_enemy(raid)
	if enemy == null:
		_errors.append("Normal Raid scene should include a visible enemy that can chase the player.")
		_free_node(raid)
		return

	var controller := enemy.get_node_or_null("EnemyController3D")
	if controller == null or controller.get_script() != EnemyControllerScript:
		_errors.append("Normal Raid enemy should include EnemyController3D.")
		_free_node(raid)
		return

	var status_label := enemy.get_node_or_null("EnemyStatusDisplay3D/StatusLabel") as Label3D
	if status_label == null:
		_errors.append("Normal Raid enemy should expose a 3D StatusLabel for chase readability.")

	enemy.global_position = Vector3.ZERO
	player.global_position = Vector3(4.0, 0.0, 0.0)
	await physics_frame
	controller._physics_process(0.2)
	await process_frame

	if str(controller.state) != "chase":
		_errors.append("Enemy in the normal Raid scene should enter chase state when player is inside detect radius.")
	if controller.target != player:
		_errors.append("Enemy in the normal Raid scene should resolve Player3D as its chase target.")
	if enemy.velocity.length() <= 0.0:
		_errors.append("Enemy in chase state should have movement velocity toward the player.")
	if status_label != null and status_label.text.strip_edges() == "":
		_errors.append("Enemy status label should remain visible and non-empty while chasing the player.")

	var distance_after_chase := enemy.global_position.distance_to(player.global_position)
	if distance_after_chase >= 4.0:
		_errors.append("Enemy should move closer to the player while chasing.")

	enemy.global_position = Vector3(0.0, 0.0, 2.38)
	enemy.velocity = Vector3.ZERO
	player.global_position = Vector3(0.0, 0.0, 6.0)
	if controller.has_method("_clear_navigation_target"):
		controller.call("_clear_navigation_target")
	await physics_frame
	await physics_frame
	var saw_fence_route := false
	for index in range(10):
		controller._physics_process(0.1)
		if absf(enemy.velocity.x) > 0.1 and enemy.velocity.z > 0.0:
			saw_fence_route = true
			break
		await physics_frame
	if not saw_fence_route:
		_errors.append("Enemy should route sideways around the normal Raid fence instead of charging straight through it.")

	player.global_position = Vector3(40.0, 0.0, 0.0)
	controller.search_duration = 0.4
	controller._search_timer = controller.search_duration
	controller._physics_process(0.2)
	await process_frame
	if str(controller.state) != "search":
		_errors.append("Enemy should search the last known player position when the target leaves detect radius.")
	for index in range(4):
		controller._physics_process(0.2)
		await physics_frame
	if str(controller.state) != "idle":
		_errors.append("Enemy should return to idle after searching without reacquiring the player.")
	if status_label != null and status_label.text.strip_edges() == "":
		_errors.append("Enemy status label should remain visible and non-empty after target search ends.")

	_validate_decoupling()
	_free_node(raid)


func _first_raid_enemy(raid: Node) -> Node3D:
	for enemy in get_nodes_in_group("enemy"):
		var enemy_node := enemy as Node3D
		if enemy_node == null or not _is_descendant_of(enemy_node, raid):
			continue
		return enemy_node
	return null


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false


func _validate_decoupling() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ai/enemy_controller_3d.gd")
	for forbidden in ["InventoryEquipmentUI", "ContainerInventoryUI", "QuestState", "SaveGameManager", "RaidResultPanel"]:
		if source.contains(forbidden):
			_errors.append("EnemyController3D should not depend on %s for chase behavior." % forbidden)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
