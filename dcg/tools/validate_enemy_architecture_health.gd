extends SceneTree

const RaidScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const EnemyControllerScript := preload("res://scripts/ai/enemy_controller_3d.gd")
const EnemyDamageableScript := preload("res://scripts/ai/enemy_damageable_3d.gd")
const EnemyStatusDisplayScript := preload("res://scripts/ai/enemy_status_display_3d.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_raid_enemy_boundaries()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[enemy_architecture_health] OK raid=reachable enemy_boundaries=clean ui_coupling=clean validation=covered")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_raid_enemy_boundaries() -> void:
	var raid := RaidScene.instantiate()
	root.add_child(raid)
	await process_frame

	var player := raid.get_node_or_null("Player3D")
	if player == null or not player.is_in_group("player"):
		_errors.append("Normal Raid should expose Player3D in the player group for enemy targeting.")

	var enemy := _first_raid_enemy(raid)
	if enemy == null:
		_errors.append("Normal Raid should include a reachable enemy instance.")
		_free_node(raid)
		return

	if enemy.get_script() != EnemyDamageableScript:
		_errors.append("Enemy root should own damage/death through EnemyDamageable3D.")

	var controller := enemy.get_node_or_null("EnemyController3D")
	if controller == null or controller.get_script() != EnemyControllerScript:
		_errors.append("Enemy chase/attack should be owned by EnemyController3D.")

	var status_display := enemy.get_node_or_null("EnemyStatusDisplay3D")
	if status_display == null or status_display.get_script() != EnemyStatusDisplayScript:
		_errors.append("Enemy visible health/state should be owned by EnemyStatusDisplay3D.")

	if enemy.get_node_or_null("NameLabel") == null:
		_errors.append("Enemy should keep a 3D name label for player readability.")
	if enemy.get_node_or_null("EnemyStatusDisplay3D/HealthBarFill") == null:
		_errors.append("Enemy should keep a 3D health bar fill for player readability.")

	var distance := (enemy as Node3D).global_position.distance_to((player as Node3D).global_position) if player is Node3D else INF
	if distance > 12.0:
		_errors.append("Normal Raid enemy should remain close enough to the player route for the first encounter.")

	_free_node(raid)


func _validate_source_boundaries() -> void:
	_assert_source_excludes(
		"res://scripts/ai/enemy_controller_3d.gd",
		["InventoryEquipmentUI", "ContainerInventoryUI", "RaidResultPanel", "QuestState", "SaveGameManager", "BaseInteractionController3D"]
	)
	_assert_source_excludes(
		"res://scripts/ai/enemy_damageable_3d.gd",
		["InventoryEquipmentUI", "ContainerInventoryUI", "RaidResultPanel", "QuestState", "SaveGameManager", "UIManager"]
	)
	_assert_source_excludes(
		"res://scripts/ai/enemy_status_display_3d.gd",
		["InventoryEquipmentUI", "ContainerInventoryUI", "RaidResultPanel", "QuestState", "SaveGameManager", "UIManager"]
	)

	for validator in [
		"res://tools/validate_enemy_visible_in_raid.gd",
		"res://tools/validate_enemy_damageable_3d.gd",
		"res://tools/validate_enemy_chase_player.gd",
	]:
		if not FileAccess.file_exists(validator):
			_errors.append("Enemy-first health requires validator: %s" % validator)


func _assert_source_excludes(path: String, forbidden_tokens: Array[String]) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source == "":
		_errors.append("Could not read source for boundary check: %s" % path)
		return
	for token in forbidden_tokens:
		if source.contains(token):
			_errors.append("%s should not depend on %s." % [path, token])


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


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
