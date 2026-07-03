extends SceneTree

const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const EnemyControllerScript := preload("res://scripts/ai/enemy_controller_3d.gd")

var _errors: Array[String] = []
var _windup_count := 0


func _initialize() -> void:
	await _validate_enemy_warning_and_player_hit_feedback()
	_validate_feedback_boundaries()
	if _errors.is_empty():
		print("[combat_feedback_visibility] OK enemy_warning=visible windup=delays_damage player_hit=visible boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_enemy_warning_and_player_hit_feedback() -> void:
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
	var status_label := enemy.get_node_or_null("EnemyStatusDisplay3D/StatusLabel") as Label3D
	if controller == null or controller.get_script() != EnemyControllerScript:
		_errors.append("Scavenger should expose EnemyController3D for warning feedback.")
		_free_node(scene)
		return
	if status_label == null:
		_errors.append("Scavenger should expose a 3D status label for attack warning.")
		_free_node(scene)
		return
	if not controller.has_signal("attack_windup_started"):
		_errors.append("EnemyController3D should emit attack_windup_started before applying damage.")
		_free_node(scene)
		return

	controller.attack_windup_started.connect(_on_attack_windup_started)
	controller.attack_cooldown = 0.8
	player.global_position = Vector3.ZERO
	enemy.global_position = player.global_position + Vector3(0.0, 0.0, 0.85)
	enemy.velocity = Vector3.ZERO

	var health_before := float(player.get("health"))
	controller._physics_process(0.05)
	await process_frame
	if _windup_count != 1:
		_errors.append("Enemy should start exactly one windup when first entering melee range.")
	if str(controller.state) != "alert":
		_errors.append("Enemy should enter alert state before melee damage.")
	if status_label.text != "準備攻擊":
		_errors.append("Enemy 3D status label should show 準備攻擊 during windup.")
	if float(player.get("health")) < health_before:
		_errors.append("Player should not take damage before the visible windup finishes.")

	controller._physics_process(0.45)
	await process_frame

	var health_after := float(player.get("health"))
	var hud_state := hud.call("get_display_state") as Dictionary
	if health_after >= health_before:
		_errors.append("Player should take damage after the attack windup.")
	if not bool(hud_state.get("damage_feedback_visible", false)):
		_errors.append("PlayerHud3D should show visible hit feedback after enemy damage.")
	if float(hud_state.get("damage_feedback_alpha", 0.0)) <= 0.0:
		_errors.append("PlayerHud3D hit feedback should expose a positive alpha for validation.")

	_free_node(scene)


func _validate_feedback_boundaries() -> void:
	var enemy_source := FileAccess.get_file_as_string("res://scripts/ai/enemy_controller_3d.gd")
	for forbidden in ["Inventory", "Quest", "SaveGame", "RaidResult", "PlayerHud3D", "UIManager"]:
		if enemy_source.contains(forbidden):
			_errors.append("EnemyController3D should not depend on %s for combat feedback." % forbidden)
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/player_hud_3d.gd")
	for forbidden in ["EnemyController3D", "Scavenger", "Quest", "SaveGame"]:
		if hud_source.contains(forbidden):
			_errors.append("PlayerHud3D should not depend on %s for hit feedback." % forbidden)


func _on_attack_windup_started(_target: Node) -> void:
	_windup_count += 1


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
