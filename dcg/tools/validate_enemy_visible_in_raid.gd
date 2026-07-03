extends SceneTree

const RaidScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const ScavengerScenePath := "res://scenes/enemies/scavenger_3d.tscn"
const EnemyControllerScript := preload("res://scripts/ai/enemy_controller_3d.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_enemy_visible_in_normal_raid()
	if _errors.is_empty():
		print("[enemy_visible_in_raid] OK raid=scavenger_visible route=reachable label=visible controller=wired")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_enemy_visible_in_normal_raid() -> void:
	var raid := RaidScene.instantiate()
	root.add_child(raid)
	await process_frame

	var player := raid.get_node_or_null("Player3D") as Node3D
	if player == null:
		_errors.append("Raid scene should include Player3D so enemy visibility can be checked against the normal player route.")
		_free_node(raid)
		return

	var enemies := get_nodes_in_group("enemy")
	var raid_enemy: Node3D = null
	for enemy in enemies:
		var enemy_node := enemy as Node3D
		if enemy_node == null or not _is_descendant_of(enemy_node, raid):
			continue
		raid_enemy = enemy_node
		break

	if raid_enemy == null:
		_errors.append("Normal Raid scene should instance a 3D enemy in the playable scene, not only define enemy scripts/resources.")
		_free_node(raid)
		return

	if raid_enemy.scene_file_path != ScavengerScenePath:
		_errors.append("First visible Raid enemy should be the Scavenger scene for the enemy-first slice.")

	var distance_to_player := raid_enemy.global_position.distance_to(player.global_position)
	if distance_to_player > 12.0:
		_errors.append("Visible Raid enemy should be close enough to the normal player route. Distance was %.2f." % distance_to_player)

	var controller := raid_enemy.get_node_or_null("EnemyController3D")
	if controller == null or controller.get_script() != EnemyControllerScript:
		_errors.append("Visible Raid enemy should include EnemyController3D so later tasks can validate chase and attack.")

	if raid_enemy.find_child("CollisionShape3D", true, false) == null:
		_errors.append("Visible Raid enemy should include a CollisionShape3D.")

	var has_mesh := false
	for child in _all_children(raid_enemy):
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			has_mesh = true
			break
	if not has_mesh:
		_errors.append("Visible Raid enemy should include at least one visible MeshInstance3D body part.")

	var label := raid_enemy.get_node_or_null("NameLabel") as Label3D
	if label == null:
		_errors.append("Visible Raid enemy should have a NameLabel so the player can identify it as an enemy.")
	elif label.text.strip_edges() == "":
		_errors.append("Visible Raid enemy NameLabel should not be empty.")

	_free_node(raid)


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false


func _all_children(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_all_children(child))
	return result


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
