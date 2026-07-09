class_name MeleeAttackService
extends RefCounted

const DamageEventScript := preload("res://scripts/combat/damage_event.gd")


static func perform_arc_attack(
	attacker: Node3D,
	melee_weapon: ItemDef,
	range_meters: float,
	arc_degrees: float,
	fallback_damage: float
) -> Dictionary:
	if attacker == null or melee_weapon == null or attacker.get_tree() == null:
		return _empty_result()
	var damage := maxf(float(melee_weapon.get_weapon_damage()), fallback_damage)
	if damage <= 0.0:
		return _empty_result()
	var forward := -attacker.global_transform.basis.z
	forward.y = 0.0
	if forward.length() <= 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var half_arc := deg_to_rad(maxf(arc_degrees, 1.0) * 0.5)
	var hit_paths: Array[String] = []
	var hit_count := 0
	for candidate in attacker.get_tree().get_nodes_in_group("damageable"):
		var target := candidate as Node3D
		if target == null or target == attacker or not target.is_inside_tree():
			continue
		if target.has_method("is_alive") and not bool(target.call("is_alive")):
			continue
		var offset := target.global_position - attacker.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= 0.001 or distance > range_meters:
			continue
		var direction := offset.normalized()
		if acos(clampf(forward.dot(direction), -1.0, 1.0)) > half_arc:
			continue
		var damage_target := _resolve_damage_target(target)
		if damage_target == null:
			continue
		var tags: Array[StringName] = [&"melee"]
		var event: DamageEvent = DamageEventScript.new(damage, attacker, melee_weapon, tags)
		if bool(damage_target.call("apply_damage", event)):
			hit_count += 1
			hit_paths.append(str(damage_target.get_path()))
	return {
		"attacked": true,
		"hit_count": hit_count,
		"hit_paths": hit_paths,
		"damage": damage,
		"range": range_meters,
		"arc_degrees": arc_degrees,
		"weapon_id": str(melee_weapon.id),
	}


static func _resolve_damage_target(target: Node) -> Node:
	if target == null:
		return null
	if target.has_method("apply_damage"):
		return target
	for child in target.get_children():
		if child is Node and child.has_method("apply_damage"):
			return child
	var parent := target.get_parent()
	if parent != null and parent.has_method("apply_damage"):
		return parent
	return null


static func _empty_result() -> Dictionary:
	return {
		"attacked": false,
		"hit_count": 0,
		"hit_paths": [],
		"damage": 0.0,
		"range": 0.0,
		"arc_degrees": 0.0,
		"weapon_id": "",
	}
