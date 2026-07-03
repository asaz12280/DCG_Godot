extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const EnemyControllerScript := preload("res://scripts/ai/enemy_controller_3d.gd")

var _errors: Array[String] = []
var _attack_count := 0


func _initialize() -> void:
	await _validate_raid_enemy_attacks_real_player()
	_validate_enemy_controller_boundaries()
	if _errors.is_empty():
		print("[enemy_attack_player] OK raid=normal attack=damages_player hud=updates cooldown=guarded status=visible")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_raid_enemy_attacks_real_player() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	await process_frame

	var player := scene.get_node_or_null("Player3D")
	var enemy := scene.get_node_or_null("SceneProps/ScavengerPatrol01")
	var hud := scene.get_node_or_null("HUD/PlayerHud3D")
	if player == null or enemy == null or hud == null:
		_errors.append("Normal Raid scene should include Player3D, ScavengerPatrol01, and PlayerHud3D.")
		_free_node(scene)
		return

	var controller := enemy.get_node_or_null("EnemyController3D")
	if controller == null or controller.get_script() != EnemyControllerScript:
		_errors.append("Normal Raid enemy should include EnemyController3D.")
		_free_node(scene)
		return
	if not controller.has_signal("attacked"):
		_errors.append("EnemyController3D should expose attacked signal for attack validation and feedback.")
		_free_node(scene)
		return

	controller.attacked.connect(_on_enemy_attacked)
	controller.attack_cooldown = 0.8
	player.global_position = Vector3.ZERO
	enemy.global_position = player.global_position + Vector3(0.0, 0.0, 0.85)
	enemy.velocity = Vector3.ZERO

	var health_before := float(player.get("health"))
	var hud_before := hud.call("get_display_state") as Dictionary
	for _index in range(36):
		await physics_frame

	var health_after := float(player.get("health"))
	var hud_after := hud.call("get_display_state") as Dictionary
	var status_label := enemy.get_node_or_null("EnemyStatusDisplay3D/StatusLabel") as Label3D

	if _attack_count != 1:
		_errors.append("Enemy should attack once inside cooldown window, got %d attacks." % _attack_count)
	if str(controller.state) != "attack":
		_errors.append("Enemy should enter attack state when close to the player.")
	if health_after >= health_before:
		_errors.append("Enemy attack should reduce the real Raid player health.")
	if float(hud_after.get("health_current", health_before)) >= float(hud_before.get("health_current", health_before)):
		_errors.append("PlayerHud3D display state should update after enemy damage.")
	if not str(hud_after.get("health_text", "")).contains(str(roundi(health_after))):
		_errors.append("PlayerHud3D health text should reflect damaged health.")
	if status_label == null or not status_label.visible or status_label.text.strip_edges() == "":
		_errors.append("Enemy attack state should be visible through a 3D status label.")
	if bool(controller.get_state().get("attack_ready", true)):
		_errors.append("Enemy attack cooldown should prevent immediate repeated attacks.")

	_free_node(scene)


func _validate_enemy_controller_boundaries() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ai/enemy_controller_3d.gd")
	for forbidden in ["Inventory", "Quest", "SaveGame", "RaidResult", "PlayerHud3D", "UIManager"]:
		if source.contains(forbidden):
			_errors.append("EnemyController3D should not depend on %s for melee attack behavior." % forbidden)


func _on_enemy_attacked(_target: Node, _damage: float) -> void:
	_attack_count += 1


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
