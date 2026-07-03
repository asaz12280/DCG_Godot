extends SceneTree

const WeaponControllerScript := preload("res://scripts/combat/weapon_controller_3d.gd")
const ProjectileScript := preload("res://scripts/combat/projectile_3d.gd")
const ShotFeedbackScript := preload("res://scripts/combat/shot_feedback_3d.gd")
const HitFeedbackScript := preload("res://scripts/combat/projectile_hit_feedback_3d.gd")
const ShotFeedbackScene := preload("res://scenes/combat/shot_feedback_3d.tscn")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_shot_feedback_scene()
	await _validate_weapon_fire_spawns_vfx_chain()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[pistol_fire_vfx] OK muzzle=spark tracer=visible projectile=red impact=visible boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_shot_feedback_scene() -> void:
	var feedback := ShotFeedbackScene.instantiate()
	root.add_child(feedback)
	if feedback.get_script() != ShotFeedbackScript:
		_errors.append("Shot feedback scene should use ShotFeedback3D script.")
	var spark := feedback.get_node_or_null("MuzzleSpark") as MeshInstance3D
	var tracer := feedback.get_node_or_null("TracerBeam") as MeshInstance3D
	var light := feedback.get_node_or_null("MuzzleLight") as OmniLight3D
	if spark == null:
		_errors.append("Shot feedback should include a visible MuzzleSpark mesh.")
	if tracer == null:
		_errors.append("Shot feedback should include a visible TracerBeam mesh.")
	if light == null:
		_errors.append("Shot feedback should include a short muzzle light.")
	_require_red_emissive(spark, "MuzzleSpark")
	_require_red_emissive(tracer, "TracerBeam")
	_free_node(feedback)


func _validate_weapon_fire_spawns_vfx_chain() -> void:
	var world := Node3D.new()
	world.name = "PistolFireVfxWorld"
	root.add_child(world)
	await process_frame

	var wall := StaticBody3D.new()
	wall.name = "ImpactWall"
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.2, 0.35)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	world.add_child(wall)
	wall.position = Vector3.FORWARD * 4.0

	var shooter := Node3D.new()
	shooter.name = "PistolVfxShooter"
	world.add_child(shooter)
	var weapon := WeaponControllerScript.new()
	weapon.weapon_def = Pistol
	weapon.current_ammo = 1
	weapon.reserve_ammo = 0
	weapon.fire_cooldown_seconds = 0.0
	shooter.add_child(weapon)
	await process_frame
	await physics_frame

	if not bool(weapon.call("fire_forward", Vector3.ZERO, Vector3.FORWARD, null)):
		_errors.append("Pistol should fire before validating VFX.")
		_free_node(world)
		return
	await process_frame
	var projectile := _find_by_script(world, ProjectileScript)
	var shot_feedback := _find_by_script(world, ShotFeedbackScript)
	if projectile == null:
		_errors.append("Pistol fire should spawn a visible red Projectile3D.")
	else:
		var projectile_mesh := projectile.get_node_or_null("MeshInstance3D") as MeshInstance3D
		_require_red_emissive(projectile_mesh, "Projectile3D")
	if shot_feedback == null:
		_errors.append("Pistol fire should spawn ShotFeedback3D for muzzle spark and tracer.")
	else:
		if shot_feedback.get_node_or_null("MuzzleSpark") == null or shot_feedback.get_node_or_null("TracerBeam") == null:
			_errors.append("ShotFeedback3D should carry both muzzle spark and tracer nodes.")

	for _frame in range(40):
		await physics_frame
		await process_frame
		if _find_by_script(world, HitFeedbackScript) != null:
			break
	var impact_feedback := _find_by_script(world, HitFeedbackScript)
	if impact_feedback == null:
		_errors.append("Projectile impact should spawn ProjectileHitFeedback3D on world collision.")
	else:
		var impact_mesh := impact_feedback.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if impact_mesh == null:
			_errors.append("Projectile hit feedback should include visible impact mesh.")

	_free_node(world)


func _validate_source_boundaries() -> void:
	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	for required in ["DEFAULT_SHOT_FEEDBACK_SCENE", "shot_feedback_scene", "_spawn_shot_feedback"]:
		if not weapon_source.contains(required):
			_errors.append("WeaponController3D should own fire VFX spawn term: %s." % required)
	for forbidden in ["InventoryEquipmentUI", "ContainerInventoryUI", "Quest", "SaveGame"]:
		if weapon_source.contains(forbidden):
			_errors.append("WeaponController3D fire VFX should not depend on %s." % forbidden)
	var feedback_source := FileAccess.get_file_as_string("res://scripts/combat/shot_feedback_3d.gd")
	for forbidden in ["PlayerController3D", "EnemyController3D", "Inventory", "UIManager"]:
		if feedback_source.contains(forbidden):
			_errors.append("ShotFeedback3D should stay visual-only and not depend on %s." % forbidden)


func _require_red_emissive(mesh_instance: MeshInstance3D, label: String) -> void:
	if mesh_instance == null:
		return
	var material := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	if material == null:
		_errors.append("%s should use a StandardMaterial3D override." % label)
		return
	if material.albedo_color.r < 0.85 or material.albedo_color.g > 0.35 or material.albedo_color.b > 0.25:
		_errors.append("%s should be clearly red/orange for visibility." % label)
	if not material.emission_enabled:
		_errors.append("%s should use emission for readability." % label)


func _find_by_script(parent: Node, script: Script) -> Node:
	for child in parent.get_children():
		if child.get_script() == script:
			return child
		var nested := _find_by_script(child, script)
		if nested != null:
			return nested
	return null


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
