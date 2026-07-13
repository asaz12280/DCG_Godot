extends SceneTree

const ProjectileScript := preload("res://scripts/combat/projectile_3d.gd")
const WeaponControllerScript := preload("res://scripts/combat/weapon_controller_3d.gd")
const DamageableScript := preload("res://scripts/combat/damageable_3d.gd")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	await _validate_projectile_hit()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[projectile_hit] OK damage=applied projectile=removed feedback=optional boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_projectile_hit() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var target := DamageableScript.new()
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
	world.add_child(shooter)
	var weapon := WeaponControllerScript.new()
	weapon.weapon_def = Pistol.duplicate(true) as ItemDef
	weapon.weapon_def.weapon_profile.projectile_pierce_chance = 0.0
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
		_errors.append("A logic-only projectile should exist immediately after firing.")
		_free_node(world)
		return
	for _frame in range(40):
		await physics_frame
		if target.current_health < target.max_health:
			break
	if target.current_health >= target.max_health:
		_errors.append("Projectile should apply damage to the target.")
	if is_instance_valid(projectile):
		_errors.append("Projectile should disappear after a successful hit.")
	if not bool(weapon.last_fire_result.get("hit", false)):
		_errors.append("WeaponController3D should record projectile hit result.")
	_free_node(world)


func _validate_source_boundaries() -> void:
	var projectile_source := FileAccess.get_file_as_string("res://scripts/combat/projectile_3d.gd")
	for required in ["projectile_hit.emit", "apply_damage", "play_projectile_impact"]:
		if not projectile_source.contains(required):
			_errors.append("Projectile3D should retain hit-resolution boundary term: %s." % required)
	for forbidden in ["hit_feedback_scene", "_spawn_hit_feedback"]:
		if projectile_source.contains(forbidden):
			_errors.append("Projectile3D should not bind detached hit VFX fallback: %s." % forbidden)


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
