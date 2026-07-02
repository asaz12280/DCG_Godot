extends SceneTree

const ProjectileScene := preload("res://scenes/combat/projectile_3d.tscn")
const ProjectileScript := preload("res://scripts/combat/projectile_3d.gd")
const HitFeedbackScene := preload("res://scenes/combat/projectile_hit_feedback_3d.tscn")
const HitFeedbackScript := preload("res://scripts/combat/projectile_hit_feedback_3d.gd")
const WeaponControllerScript := preload("res://scripts/combat/weapon_controller_3d.gd")
const DamageableScript := preload("res://scripts/combat/damageable_3d.gd")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_hit_feedback_scene()
	await _validate_projectile_hit_feedback()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[projectile_hit] OK damage=applied projectile=removed feedback=visible boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_hit_feedback_scene() -> void:
	var feedback := HitFeedbackScene.instantiate()
	root.add_child(feedback)
	if not (feedback is Node3D):
		_errors.append("Projectile hit feedback should use Node3D root.")
	if feedback.get_script() != HitFeedbackScript:
		_errors.append("Projectile hit feedback scene should use ProjectileHitFeedback3D script.")
	if feedback.get_node_or_null("MeshInstance3D") == null:
		_errors.append("Projectile hit feedback should include a MeshInstance3D so hits are visible.")
	_free_node(feedback)


func _validate_projectile_hit_feedback() -> void:
	var world := Node3D.new()
	world.name = "ProjectileHitValidationWorld"
	root.add_child(world)
	await process_frame

	var target := DamageableScript.new()
	target.name = "ProjectileHitTarget"
	target.max_health = 50.0
	var target_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.4, 1.2)
	target_shape.shape = box
	target.add_child(target_shape)
	world.add_child(target)
	target.position = Vector3.FORWARD * 4.0
	target._ready()

	var shooter := Node3D.new()
	shooter.name = "ProjectileHitShooter"
	world.add_child(shooter)

	var weapon := WeaponControllerScript.new()
	weapon.weapon_def = Pistol
	weapon.current_ammo = 1
	weapon.reserve_ammo = 0
	weapon.fire_cooldown_seconds = 0.0
	shooter.add_child(weapon)
	await process_frame
	await physics_frame

	if not weapon.fire_forward(Vector3.ZERO, Vector3.FORWARD, null):
		_errors.append("WeaponController3D.fire_forward should start projectile hit validation.")
		_free_node(world)
		return
	var projectile := _find_node_with_script(world, ProjectileScript)
	if projectile == null:
		_errors.append("A projectile should exist immediately after firing.")
		_free_node(world)
		return

	for _frame in range(40):
		await physics_frame
		if target.current_health < target.max_health:
			break

	if target.current_health >= target.max_health:
		_errors.append("Projectile should apply damage to the damageable target.")
	if is_instance_valid(projectile):
		_errors.append("Projectile should disappear after a successful hit.")
	if not bool(weapon.last_fire_result.get("hit", false)):
		_errors.append("WeaponController3D should record projectile hit result.")

	var feedback := _find_node_with_script(world, HitFeedbackScript)
	if feedback == null:
		_errors.append("Projectile hit should spawn a visible hit feedback node.")
	else:
		if not (feedback is Node3D):
			_errors.append("Hit feedback should be a Node3D instance.")
		if (feedback as Node3D).global_position.distance_to(target.global_position) > 1.5:
			_errors.append("Hit feedback should appear near the target hit position.")
		await process_frame
		if not is_instance_valid(feedback):
			_errors.append("Hit feedback should remain visible for at least one frame.")

	await create_timer(0.35).timeout
	if feedback != null and is_instance_valid(feedback):
		_errors.append("Hit feedback should clean itself up after its short lifetime.")

	_free_node(world)


func _validate_source_boundaries() -> void:
	var projectile_source := FileAccess.get_file_as_string("res://scripts/combat/projectile_3d.gd")
	for required in ["hit_feedback_scene", "_spawn_hit_feedback", "projectile_hit.emit"]:
		if not projectile_source.contains(required):
			_errors.append("Projectile3D should keep hit feedback term: %s." % required)
	for forbidden in ["InventoryModel", "EquipmentModel", "UIManager", "PlayerController3D", "Control"]:
		if projectile_source.contains(forbidden):
			_errors.append("Projectile3D hit flow should stay combat-only and independent from %s." % forbidden)

	var feedback_source := FileAccess.get_file_as_string("res://scripts/combat/projectile_hit_feedback_3d.gd")
	for forbidden in ["InventoryModel", "EquipmentModel", "UIManager", "PlayerController3D", "Control"]:
		if feedback_source.contains(forbidden):
			_errors.append("ProjectileHitFeedback3D should stay visual/combat-only and independent from %s." % forbidden)


func _find_node_with_script(parent: Node, script: Script) -> Node:
	for child in parent.get_children():
		if child.get_script() == script:
			return child
		var nested := _find_node_with_script(child, script)
		if nested != null:
			return nested
	return null


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
