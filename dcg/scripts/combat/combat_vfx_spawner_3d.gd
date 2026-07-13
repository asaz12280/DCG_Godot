class_name CombatVfxSpawner3D
extends Node3D


func play_firearm_shot(origin: Vector3, direction: Vector3, weapon_def: ItemDef) -> void:
	_spawn_feedback(_profile_scene(weapon_def, &"firearm_muzzle_scene"), origin, direction, [weapon_def])


func attach_projectile_travel(projectile: Node3D, weapon_def: ItemDef) -> void:
	if projectile == null or projectile.get_node_or_null("ProjectileTravelVfx") != null:
		return
	var scene := _profile_scene(weapon_def, &"firearm_projectile_scene")
	if scene == null:
		return
	var feedback := scene.instantiate() as Node3D
	if feedback == null:
		return
	feedback.name = "ProjectileTravelVfx"
	projectile.add_child(feedback)


func play_projectile_impact(hit_position: Vector3, incoming_direction: Vector3, weapon_def: ItemDef, did_damage: bool, damaged_target: Node3D = null) -> void:
	_spawn_feedback(_profile_scene(weapon_def, &"firearm_impact_scene"), hit_position, incoming_direction, [weapon_def])
	if did_damage and damaged_target != null:
		_spawn_feedback(_profile_scene(weapon_def, &"firearm_target_hit_scene"), hit_position, incoming_direction, [damaged_target])


func _profile_scene(weapon_def: ItemDef, property_name: StringName) -> PackedScene:
	if weapon_def == null or not weapon_def.has_method("get_weapon_vfx_profile"):
		return null
	var profile := weapon_def.call("get_weapon_vfx_profile") as WeaponVfxProfile
	if profile == null:
		return null
	return profile.get(property_name) as PackedScene


func _spawn_feedback(scene: PackedScene, spawn_position: Vector3, direction: Vector3, extra_args: Array = []) -> Node3D:
	if scene == null:
		return null
	var feedback := scene.instantiate() as Node3D
	if feedback == null:
		return null
	var parent := get_tree().current_scene if is_inside_tree() and get_tree().current_scene != null else get_parent()
	if parent == null:
		feedback.queue_free()
		return null
	parent.add_child(feedback)
	if feedback.has_method("setup"):
		var args: Array = [spawn_position, direction]
		args.append_array(extra_args)
		feedback.callv("setup", args)
	else:
		feedback.global_position = spawn_position
	return feedback
