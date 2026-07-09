extends SceneTree

const WeaponControllerScript := preload("res://scripts/combat/weapon_controller_3d.gd")
const DamageableScript := preload("res://scripts/combat/damageable_3d.gd")
const ProjectileScript := preload("res://scripts/combat/projectile_3d.gd")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const Ammo := preload("res://data/items/ammo/ammo_9mm.tres")
const PolishedAmmo := preload("res://data/items/ammo/ammo_9mm_polished.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_item_data()
	_validate_weapon_direct_damage_uses_ammo_multiplier()
	await _validate_projectile_damage_uses_ammo_multiplier()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[ammo_damage_multiplier] OK data=ammo damage=direct/projectile baseline=stable boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_item_data() -> void:
	if absf(Ammo.ammo_damage_multiplier - 1.0) > 0.001:
		_errors.append("Baseline Ammo-S should keep the existing 1.0 damage multiplier.")
	if PolishedAmmo.ammo_damage_multiplier <= Ammo.ammo_damage_multiplier:
		_errors.append("Polished Ammo-S should have a higher ammo damage multiplier than baseline Ammo-S.")
	var stack := PolishedAmmo.to_stack(2)
	if absf(float(stack.get("ammo_damage_multiplier", 0.0)) - PolishedAmmo.ammo_damage_multiplier) > 0.001:
		_errors.append("Ammo stacks should expose ammo_damage_multiplier for UI and planning.")


func _validate_weapon_direct_damage_uses_ammo_multiplier() -> void:
	var baseline_damage := _direct_damage_after_one_shot(Ammo)
	var polished_damage := _direct_damage_after_one_shot(PolishedAmmo)
	var expected_baseline := float(Pistol.damage) * Ammo.ammo_damage_multiplier
	var expected_polished := float(Pistol.damage) * PolishedAmmo.ammo_damage_multiplier
	if not is_equal_approx(baseline_damage, expected_baseline):
		_errors.append("Baseline ammo direct shot should deal %.2f damage, got %.2f." % [expected_baseline, baseline_damage])
	if not is_equal_approx(polished_damage, expected_polished):
		_errors.append("Polished ammo direct shot should deal %.2f damage, got %.2f." % [expected_polished, polished_damage])
	if polished_damage <= baseline_damage:
		_errors.append("Polished ammo direct shot should deal more damage than baseline ammo.")


func _validate_projectile_damage_uses_ammo_multiplier() -> void:
	var baseline_damage := await _projectile_damage_after_one_shot(Ammo)
	var polished_damage := await _projectile_damage_after_one_shot(PolishedAmmo)
	if polished_damage <= baseline_damage:
		_errors.append("Projectile hit should preserve the loaded ammo damage multiplier.")


func _validate_source_boundaries() -> void:
	var item_source := FileAccess.get_file_as_string("res://scripts/items/item_def.gd")
	if not item_source.contains("ammo_damage_multiplier"):
		_errors.append("ItemDef should own ammo damage multiplier data.")
	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	for required in ["_current_ammo_damage_multiplier", "ammo_damage_multiplier", "_make_damage_event"]:
		if not weapon_source.contains(required):
			_errors.append("WeaponController3D should apply ammo damage through %s." % required)
	for forbidden in ["InventoryModel", "EquipmentModel", "SaveGameManager", "BaseRecipeService"]:
		if weapon_source.contains(forbidden):
			_errors.append("WeaponController3D ammo damage should not depend on %s." % forbidden)
	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	if player_source.contains("ammo_damage_multiplier"):
		_errors.append("PlayerController3D should not own ammo damage math; WeaponController3D has the ammo model.")


func _direct_damage_after_one_shot(ammo_def: ItemDef) -> float:
	var target := DamageableScript.new()
	target.max_health = 100.0
	root.add_child(target)
	target._ready()
	var weapon := _weapon_with_loaded_ammo(ammo_def)
	root.add_child(weapon)
	weapon.force_cooldown_ready()
	if not weapon.fire_at(target):
		_errors.append("WeaponController3D should fire directly with %s." % ammo_def.resource_path)
	var damage := 100.0 - float(target.current_health)
	_free_node(weapon)
	_free_node(target)
	return damage


func _projectile_damage_after_one_shot(ammo_def: ItemDef) -> float:
	var world := Node3D.new()
	root.add_child(world)
	await process_frame
	var target := DamageableScript.new()
	target.max_health = 100.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.2, 1.2)
	shape.shape = box
	target.add_child(shape)
	world.add_child(target)
	target.global_position = Vector3.FORWARD * 3.0
	target._ready()
	var shooter := Node3D.new()
	world.add_child(shooter)
	var weapon := _weapon_with_loaded_ammo(ammo_def)
	shooter.add_child(weapon)
	await process_frame
	await physics_frame
	weapon.force_cooldown_ready()
	if not weapon.fire_forward(Vector3.ZERO, Vector3.FORWARD, null):
		_errors.append("WeaponController3D should fire a projectile with %s." % ammo_def.resource_path)
	for _frame in range(40):
		await physics_frame
		if target.current_health < target.max_health:
			break
	var damage := 100.0 - float(target.current_health)
	var projectile := _find_node_with_script(world, ProjectileScript)
	if projectile != null and is_instance_valid(projectile):
		_errors.append("Projectile should resolve and be removed after ammo damage validation.")
	_free_node(world)
	return damage


func _weapon_with_loaded_ammo(ammo_def: ItemDef) -> WeaponController3D:
	var weapon := WeaponControllerScript.new()
	var pistol := Pistol.duplicate() as ItemDef
	pistol.weapon_profile = Pistol.weapon_profile.duplicate(true)
	pistol.weapon_profile.critical_chance = 0.0
	pistol.weapon_profile.projectile_pierce_chance = 0.0
	weapon.weapon_def = pistol
	weapon.fire_cooldown_seconds = 0.0
	weapon.equip_weapon(pistol)
	var moved := weapon.reload_from_item(ammo_def, 1)
	if moved != 1:
		_errors.append("Weapon should load one compatible ammo round for damage validation.")
	return weapon


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
