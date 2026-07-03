extends SceneTree

const ScavengerScene := preload("res://scenes/enemies/scavenger_3d.tscn")
const EnemyControllerScript := preload("res://scripts/ai/enemy_controller_3d.gd")
const QuestKillTrackerScript := preload("res://scripts/quests/quest_kill_tracker_3d.gd")
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")

var _errors: Array[String] = []
var _attack_count := 0


class FakePlayer:
	extends CharacterBody3D

	var health := 100.0
	var damage_taken := 0.0

	func _init() -> void:
		add_to_group("player")

	func apply_damage(event: DamageEvent) -> bool:
		if event == null or event.amount <= 0.0 or health <= 0.0:
			return false
		damage_taken += event.amount
		health = maxf(health - event.amount, 0.0)
		return true

	func is_alive() -> bool:
		return health > 0.0


func _initialize() -> void:
	await _validate_chase_attack_and_death()
	await _validate_scene_wiring()
	if _errors.is_empty():
		print("[enemy_ai] OK detect=chase attack=damages dead=stops scene=wired")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_chase_attack_and_death() -> void:
	var enemy := ScavengerScene.instantiate()
	root.add_child(enemy)
	var controller := enemy.get_node_or_null("EnemyController3D")
	var player := FakePlayer.new()
	root.add_child(player)
	await process_frame
	enemy.global_position = Vector3.ZERO
	player.global_position = Vector3(4.0, 0.0, 0.0)
	if controller == null:
		_errors.append("Scavenger should include EnemyController3D.")
		_free_node(enemy)
		_free_node(player)
		return
	controller.attacked.connect(_on_enemy_attacked)
	controller._physics_process(0.2)
	if str(controller.state) != "chase":
		_errors.append("EnemyController3D should chase a player inside detect radius and outside attack range.")
	if enemy.velocity.length() <= 0.0:
		_errors.append("EnemyController3D should set velocity while chasing.")

	player.global_position = Vector3(0.6, 0.0, 0.0)
	controller._physics_process(0.05)
	if str(controller.state) != "alert":
		_errors.append("EnemyController3D should show alert windup before melee damage.")
	if player.damage_taken > 0.0:
		_errors.append("EnemyController3D should not damage the player before the attack windup completes.")
	controller._physics_process(0.5)
	if str(controller.state) != "attack":
		_errors.append("EnemyController3D should enter attack state inside attack range.")
	if player.damage_taken <= 0.0 or _attack_count != 1:
		_errors.append("EnemyController3D should damage the player when attacking.")

	var lethal := DamageEventScript.new(999.0, null, null, [&"validation"])
	enemy.apply_damage(lethal)
	controller._physics_process(0.2)
	if str(controller.state) != "dead":
		_errors.append("EnemyController3D should stop in dead state after the enemy dies.")
	if enemy.velocity.length() > 0.0:
		_errors.append("EnemyController3D should stop movement after death.")

	_free_node(enemy)
	_free_node(player)


func _validate_scene_wiring() -> void:
	var enemy := ScavengerScene.instantiate()
	root.add_child(enemy)
	await process_frame
	var controller := enemy.get_node_or_null("EnemyController3D")
	if controller == null or controller.get_script() != EnemyControllerScript:
		_errors.append("Scavenger scene should wire EnemyController3D script.")
	var kill_tracker := enemy.get_node_or_null("QuestKillTracker3D")
	if kill_tracker == null or kill_tracker.get_script() != QuestKillTrackerScript:
		_errors.append("Scavenger scene should wire QuestKillTracker3D script.")
	if not enemy.has_signal("died"):
		_errors.append("Scavenger root should expose died signal for AI stop behavior.")
	_free_node(enemy)


func _on_enemy_attacked(_target: Node, _damage: float) -> void:
	_attack_count += 1


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
