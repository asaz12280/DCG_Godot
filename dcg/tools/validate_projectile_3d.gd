extends SceneTree

const ProjectileScene := preload("res://scenes/combat/projectile_3d.tscn")
const ProjectileScript := preload("res://scripts/combat/projectile_3d.gd")
const WeaponControllerScript := preload("res://scripts/combat/weapon_controller_3d.gd")
const DamageableScript := preload("res://scripts/combat/damageable_3d.gd")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_projectile_scene()
	await _validate_weapon_spawns_visible_projectile()
	await _validate_projectile_wall_miss_cleanup()
	await _validate_projectile_range_miss_cleanup()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[projectile_3d] OK scene=visible spawn=moving hit=damages miss=cleans_up hitscan=removed boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_projectile_scene() -> void:
	var projectile := ProjectileScene.instantiate()
	root.add_child(projectile)
	if not (projectile is Area3D):
		_errors.append("Projectile scene should use Area3D root for visible moving hit detection.")
	if projectile.get_script() != ProjectileScript:
		_errors.append("Projectile scene should use Projectile3D script.")
	if projectile.get_node_or_null("MeshInstance3D") == null:
		_errors.append("Projectile scene should include a MeshInstance3D so the bullet is visible.")
	if projectile.get_node_or_null("CollisionShape3D") == null:
		_errors.append("Projectile scene should include a CollisionShape3D for hit detection.")
	_free_node(projectile)


func _validate_weapon_spawns_visible_projectile() -> void:
	var world := Node3D.new()
	world.name = "ProjectileValidationWorld"
	root.add_child(world)
	await process_frame

	var target := DamageableScript.new()
	target.name = "ProjectileTarget"
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
	shooter.name = "ProjectileShooter"
	world.add_child(shooter)

	var weapon := WeaponControllerScript.new()
	weapon.weapon_def = Pistol
	weapon.current_ammo = 1
	weapon.reserve_ammo = 0
	weapon.fire_cooldown_seconds = 0.0
	shooter.add_child(weapon)
	await process_frame
	await physics_frame

	var fired := weapon.fire_forward(Vector3(0.0, 0.0, 0.0), Vector3.FORWARD, null)
	if not fired:
		_errors.append("WeaponController3D.fire_forward should spawn a projectile and return true.")
	if int(weapon.get("current_ammo")) != 0:
		_errors.append("Projectile firing should still consume one loaded round.")
	await process_frame
	var projectile := _find_projectile(world)
	if projectile == null:
		_errors.append("fire_forward should add a Projectile3D instance to the scene.")
		_free_node(world)
		return
	var start_position := projectile.position
	await physics_frame
	await physics_frame
	if projectile != null and is_instance_valid(projectile) and projectile.position.distance_to(start_position) <= 0.05:
		_errors.append("Projectile should visibly move after being spawned.")

	for _frame in range(40):
		await physics_frame
		if target.current_health < target.max_health:
			break
	if target.current_health >= target.max_health:
		_errors.append("Projectile should hit the damageable target and apply damage.")
	if not bool(weapon.last_fire_result.get("hit", false)):
		_errors.append("WeaponController3D should update last_fire_result after projectile hit.")

	_free_node(world)


func _validate_projectile_wall_miss_cleanup() -> void:
	var world := Node3D.new()
	world.name = "ProjectileWallMissWorld"
	root.add_child(world)
	await process_frame

	var wall := StaticBody3D.new()
	wall.name = "ProjectileMissWall"
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.4, 0.35)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	world.add_child(wall)
	wall.position = Vector3.FORWARD * 4.0

	var shooter := Node3D.new()
	shooter.name = "ProjectileMissShooter"
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
		_errors.append("WeaponController3D.fire_forward should start wall-miss validation.")
		_free_node(world)
		return
	var projectile := _find_projectile(world)
	if projectile == null:
		_errors.append("A projectile should exist before wall-miss cleanup.")
		_free_node(world)
		return
	for _frame in range(40):
		await physics_frame
		if not is_instance_valid(projectile):
			break
	if is_instance_valid(projectile):
		_errors.append("Projectile should disappear when it collides with non-damageable world geometry.")
	if bool(weapon.last_fire_result.get("hit", true)):
		_errors.append("WeaponController3D should record wall collision as a miss, not a hit.")
	if str(weapon.last_fire_result.get("blocked_reason", "not-empty")) != "":
		_errors.append("Wall miss should not report a blocked firing reason.")

	_free_node(world)


func _validate_projectile_range_miss_cleanup() -> void:
	var world := Node3D.new()
	world.name = "ProjectileRangeMissWorld"
	root.add_child(world)
	await process_frame

	var projectile := ProjectileScene.instantiate()
	world.add_child(projectile)
	projectile.max_distance = 0.8
	projectile.lifetime_seconds = 1.0
	projectile.speed = 20.0
	var state := {"missed": false}
	projectile.projectile_missed.connect(func() -> void: state["missed"] = true)
	projectile.setup(Vector3.ZERO, Vector3.FORWARD, null, null, null)
	await process_frame
	for _frame in range(20):
		await physics_frame
		if not is_instance_valid(projectile):
			break
	if is_instance_valid(projectile):
		_errors.append("Projectile should clean itself up after reaching max_distance.")
	if not bool(state.get("missed", false)):
		_errors.append("Projectile should emit projectile_missed when range cleanup happens.")

	_free_node(world)


func _validate_source_boundaries() -> void:
	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	for required in ["DEFAULT_PROJECTILE_SCENE", "projectile_scene", "_spawn_projectile", "_on_projectile_hit"]:
		if not weapon_source.contains(required):
			_errors.append("WeaponController3D should expose projectile term: %s." % required)
	if weapon_source.contains("intersect_ray"):
		_errors.append("WeaponController3D.fire_forward should not keep hitscan intersect_ray after projectile task.")
	for forbidden in ["InventoryModel", "InventoryEquipmentUI", "ContainerInventoryUI"]:
		if weapon_source.contains(forbidden):
			_errors.append("WeaponController3D projectile flow should not depend on inventory or UI: %s." % forbidden)

	var projectile_source := FileAccess.get_file_as_string("res://scripts/combat/projectile_3d.gd")
	for required in ["max_distance", "lifetime_seconds", "_finish_miss", "projectile_missed.emit"]:
		if not projectile_source.contains(required):
			_errors.append("Projectile3D should keep miss cleanup term: %s." % required)
	for forbidden in ["InventoryModel", "EquipmentModel", "UIManager", "PlayerController3D"]:
		if projectile_source.contains(forbidden):
			_errors.append("Projectile3D should stay combat-only and independent from %s." % forbidden)


func _find_projectile(parent: Node) -> Node3D:
	for child in parent.get_children():
		if child is Node3D and child.get_script() == ProjectileScript:
			return child as Node3D
		var nested := _find_projectile(child)
		if nested != null:
			return nested
	return null


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
