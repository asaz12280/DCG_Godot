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
	await _validate_damage_alert_chases_outside_detect_radius()
	await _validate_navigation_route_around_barrier()
	await _validate_scene_wiring()
	if _errors.is_empty():
		print("[enemy_ai] OK detect=chase damage_alert=chases search=give_up attack=damages dead=stops navigation=routes scene=wired")
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

	enemy.global_position = Vector3.ZERO
	enemy.velocity = Vector3.ZERO
	controller._attack_timer = 0.0
	controller._windup_timer = 0.0
	controller._windup_target = null
	player.global_position = Vector3(0.0, 0.0, 1.0)
	var blocker := _create_attack_blocker(Vector3(0.0, 0.65, 0.5), Vector3(0.25, 1.3, 0.25))
	root.add_child(blocker)
	await physics_frame
	player.damage_taken = 0.0
	controller._physics_process(0.05)
	controller._physics_process(0.5)
	if str(controller.state) == "attack":
		_errors.append("EnemyController3D should not attack through a blocking body between enemy and player.")
	if player.damage_taken > 0.0:
		_errors.append("EnemyController3D should require attack clearance before dealing melee damage.")
	_free_node(blocker)

	var lethal := DamageEventScript.new(999.0, null, null, [&"validation"])
	enemy.apply_damage(lethal)
	controller._physics_process(0.2)
	if str(controller.state) != "dead":
		_errors.append("EnemyController3D should stop in dead state after the enemy dies.")
	if enemy.velocity.length() > 0.0:
		_errors.append("EnemyController3D should stop movement after death.")

	_free_node(enemy)
	_free_node(player)


func _validate_damage_alert_chases_outside_detect_radius() -> void:
	var enemy := ScavengerScene.instantiate()
	root.add_child(enemy)
	var controller := enemy.get_node_or_null("EnemyController3D")
	var player := FakePlayer.new()
	player.add_to_group("damage_alert_test_player")
	enemy.global_position = Vector3.ZERO
	player.position = Vector3(14.0, 0.0, 0.0)
	if controller == null:
		_errors.append("Scavenger should include EnemyController3D for damage alert validation.")
		_free_node(enemy)
		_free_node(player)
		return
	controller.target_group = "damage_alert_test_player"
	controller.forget_distance = 12.0
	controller.damage_alert_min_duration = 0.4
	controller.search_duration = 0.6
	root.add_child(player)
	await process_frame
	await physics_frame

	controller._physics_process(0.2)
	if str(controller.state) != "idle":
		_errors.append("EnemyController3D should stay idle when an undamaged player is outside detect radius.")

	var hurt_event := DamageEventScript.new(5.0, player, null, [&"validation", &"ranged"])
	if not enemy.apply_damage(hurt_event):
		_errors.append("Scavenger should accept non-lethal damage from a ranged player.")
	controller._physics_process(0.2)

	if str(controller.state) != "chase":
		_errors.append("EnemyController3D should chase the player after being damaged outside detect radius.")
	if controller.target != player:
		_errors.append("EnemyController3D should remember the damage source as its alerted target.")
	if enemy.velocity.length() <= 0.0:
		_errors.append("EnemyController3D should move toward a damage source outside detect radius.")
	if not bool(controller.get_state().get("damage_alert", false)):
		_errors.append("EnemyController3D should expose active damage_alert state after being hit.")

	player.global_position = Vector3(32.0, 0.0, 0.0)
	controller._physics_process(0.3)
	if str(controller.state) != "search":
		_errors.append("EnemyController3D should search the last known player position after the player sprints past forget distance.")
	if bool(controller.get_state().get("damage_alert", true)):
		_errors.append("EnemyController3D should drop exact damage-alert target lock while searching.")

	for index in range(4):
		controller._physics_process(0.2)
		await physics_frame
	if str(controller.state) != "idle":
		_errors.append("EnemyController3D should give up and return to idle after searching without reacquiring the player.")
	if bool(controller.get_state().get("has_last_known_position", true)):
		_errors.append("EnemyController3D should clear last known target memory after giving up.")

	_free_node(enemy)
	_free_node(player)


func _validate_navigation_route_around_barrier() -> void:
	var navigation_region := _create_barrier_navigation_region()
	root.add_child(navigation_region)
	var enemy := ScavengerScene.instantiate()
	root.add_child(enemy)
	var controller := enemy.get_node_or_null("EnemyController3D")
	var navigation_agent := enemy.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	var player := FakePlayer.new()
	root.add_child(player)
	await process_frame
	await physics_frame
	await physics_frame

	if controller == null:
		_errors.append("Scavenger should include EnemyController3D for navigation chase validation.")
		_free_node(enemy)
		_free_node(player)
		_free_node(navigation_region)
		return
	if navigation_agent == null:
		_errors.append("Scavenger should include NavigationAgent3D for obstacle-aware chase.")
		_free_node(enemy)
		_free_node(player)
		_free_node(navigation_region)
		return

	enemy.global_position = Vector3(0.0, 0.0, 2.0)
	player.global_position = Vector3(0.0, 0.0, 6.0)
	var saw_sideways_route := false
	for index in range(12):
		controller._physics_process(0.1)
		if absf(enemy.velocity.x) > 0.1 and enemy.velocity.z > 0.0:
			saw_sideways_route = true
			break
		await physics_frame

	if str(controller.state) != "chase":
		_errors.append("EnemyController3D should chase a player across a navmesh obstacle gap.")
	if not saw_sideways_route:
		_errors.append("EnemyController3D should route sideways around a blocked navmesh band instead of charging straight ahead.")

	_free_node(enemy)
	_free_node(player)
	_free_node(navigation_region)


func _validate_scene_wiring() -> void:
	var enemy := ScavengerScene.instantiate()
	root.add_child(enemy)
	await process_frame
	var controller := enemy.get_node_or_null("EnemyController3D")
	if controller == null or controller.get_script() != EnemyControllerScript:
		_errors.append("Scavenger scene should wire EnemyController3D script.")
	if enemy.get_node_or_null("NavigationAgent3D") == null:
		_errors.append("Scavenger scene should wire NavigationAgent3D for obstacle-aware chase.")
	var kill_tracker := enemy.get_node_or_null("QuestKillTracker3D")
	if kill_tracker == null or kill_tracker.get_script() != QuestKillTrackerScript:
		_errors.append("Scavenger scene should wire QuestKillTracker3D script.")
	if not enemy.has_signal("died"):
		_errors.append("Scavenger root should expose died signal for AI stop behavior.")
	_free_node(enemy)


func _on_enemy_attacked(_target: Node, _damage: float) -> void:
	_attack_count += 1


func _create_barrier_navigation_region() -> NavigationRegion3D:
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.set_vertices(PackedVector3Array([
		Vector3(-6.0, 0.0, -2.0),
		Vector3(-2.0, 0.0, -2.0),
		Vector3(2.0, 0.0, -2.0),
		Vector3(6.0, 0.0, -2.0),
		Vector3(-6.0, 0.0, 3.0),
		Vector3(-2.0, 0.0, 3.0),
		Vector3(2.0, 0.0, 3.0),
		Vector3(6.0, 0.0, 3.0),
		Vector3(-6.0, 0.0, 4.5),
		Vector3(-2.0, 0.0, 4.5),
		Vector3(2.0, 0.0, 4.5),
		Vector3(6.0, 0.0, 4.5),
		Vector3(-6.0, 0.0, 8.0),
		Vector3(-2.0, 0.0, 8.0),
		Vector3(2.0, 0.0, 8.0),
		Vector3(6.0, 0.0, 8.0),
	]))
	for polygon in [
		PackedInt32Array([0, 1, 5, 4]),
		PackedInt32Array([1, 2, 6, 5]),
		PackedInt32Array([2, 3, 7, 6]),
		PackedInt32Array([4, 5, 9, 8]),
		PackedInt32Array([6, 7, 11, 10]),
		PackedInt32Array([8, 9, 13, 12]),
		PackedInt32Array([9, 10, 14, 13]),
		PackedInt32Array([10, 11, 15, 14]),
	]:
		navigation_mesh.add_polygon(polygon)
	var region := NavigationRegion3D.new()
	region.name = "ValidationNavigationRegion3D"
	region.navigation_mesh = navigation_mesh
	return region


func _create_attack_blocker(position: Vector3, size: Vector3) -> StaticBody3D:
	var blocker := StaticBody3D.new()
	blocker.name = "ValidationAttackBlocker"
	blocker.position = position
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	blocker.add_child(collision)
	return blocker


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
