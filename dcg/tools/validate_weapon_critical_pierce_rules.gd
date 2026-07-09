extends SceneTree

const DamageableScript := preload("res://scripts/combat/damageable_3d.gd")
const WeaponControllerScript := preload("res://scripts/combat/weapon_controller_3d.gd")
const ProjectileScript := preload("res://scripts/combat/projectile_3d.gd")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_critical_damage_before_armor()
	await _validate_projectile_pierce_hits_second_target()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[weapon_critical_pierce_rules] OK critical=2x armor=after_critical pierce=second_target boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_critical_damage_before_armor() -> void:
	var target := DamageableScript.new()
	target.max_health = 9.0
	target.armor_protection_level = 5.0
	root.add_child(target)
	target._ready()

	var weapon := WeaponControllerScript.new()
	weapon.equip_weapon(_validation_pistol(5, 4.0, 100.0, 0.0))
	weapon.current_ammo = 1
	weapon.reserve_ammo = 0
	weapon.force_cooldown_ready()
	root.add_child(weapon)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")

	var state := {"hit_event": null}
	weapon.hit.connect(func(_target: Node, event: DamageEvent) -> void: state["hit_event"] = event)
	if not weapon.fire_at(target):
		_errors.append("Critical validation weapon should fire at armored target.")
	if not is_equal_approx(float(target.current_health), 0.0):
		_errors.append("100% critical should deal (5*2)-max(5-4,0)=9 damage and kill 9 HP target, got health %.2f." % float(target.current_health))
	var result_event := state.get("hit_event") as DamageEvent
	if result_event == null:
		_errors.append("Critical validation should emit a hit DamageEvent.")
	elif not bool(result_event.is_critical):
		_errors.append("DamageEvent should mark 100% critical hits as critical.")

	_free_node(weapon)
	_free_node(target)


func _validate_projectile_pierce_hits_second_target() -> void:
	var world := Node3D.new()
	root.add_child(world)
	await process_frame

	var first := _target_at(world, Vector3.FORWARD * 3.0)
	var second := _target_at(world, Vector3.FORWARD * 6.0)
	var shooter := Node3D.new()
	world.add_child(shooter)
	var weapon := WeaponControllerScript.new()
	weapon.equip_weapon(_validation_pistol(10, 0.0, 0.0, 100.0))
	weapon.current_ammo = 1
	weapon.reserve_ammo = 0
	weapon.fire_cooldown_seconds = 0.0
	shooter.add_child(weapon)
	if weapon.has_method("_sync_ammo_result"):
		weapon.call("_sync_ammo_result")
	await process_frame
	await physics_frame
	weapon.force_cooldown_ready()

	if not weapon.fire_forward(Vector3.ZERO, Vector3.FORWARD, null):
		_errors.append("Pierce validation weapon should fire a projectile.")
	for _frame in range(160):
		await physics_frame
		if first.current_health < first.max_health and second.current_health < second.max_health:
			break
	if first.current_health >= first.max_health:
		_errors.append("Piercing projectile should damage the first target.")
	if second.current_health >= second.max_health:
		_errors.append("100% piercing projectile should continue and damage the second target behind the first.")
	var projectile := _find_node_with_script(world, ProjectileScript)
	if projectile != null and is_instance_valid(projectile):
		for _frame in range(160):
			await physics_frame
			if not is_instance_valid(projectile):
				break
	if projectile != null and is_instance_valid(projectile):
		_errors.append("Piercing projectile should eventually resolve after passing targets.")

	_free_node(world)


func _validate_source_boundaries() -> void:
	var item_source := FileAccess.get_file_as_string("res://scripts/items/item_def.gd")
	for required in ["critical_chance", "projectile_pierce_chance"]:
		if not item_source.contains(required):
			_errors.append("ItemDef should own weapon chance data: %s." % required)
	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	for required in ["CRITICAL_DAMAGE_MULTIPLIER", "is_critical", "projectile_pierce_chance"]:
		if not weapon_source.contains(required):
			_errors.append("WeaponController3D should apply critical/pierce event data through %s." % required)
	var projectile_source := FileAccess.get_file_as_string("res://scripts/combat/projectile_3d.gd")
	for required in ["_should_pierce_after_hit", "_pierced_damage_targets", "_pierced_colliders"]:
		if not projectile_source.contains(required):
			_errors.append("Projectile3D should own projectile piercing through %s." % required)


func _validation_pistol(damage: int, penetration: float, critical_percent: float, pierce_percent: float) -> ItemDef:
	var pistol := Pistol.duplicate() as ItemDef
	pistol.weapon_profile = Pistol.weapon_profile.duplicate(true)
	pistol.damage = damage
	pistol.weapon_armor_penetration_level = penetration
	pistol.critical_chance = critical_percent
	pistol.projectile_pierce_chance = pierce_percent
	pistol.projectile_range = 1000.0
	pistol.weapon_profile.damage = damage
	pistol.weapon_profile.armor_penetration_level = penetration
	pistol.weapon_profile.critical_chance = critical_percent
	pistol.weapon_profile.projectile_pierce_chance = pierce_percent
	pistol.weapon_profile.projectile_range = 1000.0
	pistol.weapon_profile.compatible_ammo_tags = [&"S"]
	pistol.tags = [&"gun", &"pistol", &"S"]
	pistol.compatible_ammo_tags = [&"S"]
	return pistol


func _target_at(parent: Node, position: Vector3) -> Damageable3D:
	var target := DamageableScript.new()
	target.max_health = 30.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.2, 1.2)
	shape.shape = box
	target.add_child(shape)
	parent.add_child(target)
	target.global_position = position
	target._ready()
	return target


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
