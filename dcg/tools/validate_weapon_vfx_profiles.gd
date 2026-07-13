extends SceneTree

const PlayerScene := preload("res://scenes/player/player_3d.tscn")
const WeaponVfxProfileScript := preload("res://scripts/combat/weapon_vfx_profile.gd")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const Smg := preload("res://data/items/weapons/smg_S.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_weapon_profiles()
	await _validate_player_boundary()
	_validate_source_contract()
	if _errors.is_empty():
		print("[weapon_vfx_profiles] OK pistol=bound smg=bound source=aligned vendor=contained")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_weapon_profiles() -> void:
	for raw_weapon in [Pistol, Smg]:
		var weapon := raw_weapon as ItemDef
		var profile: WeaponVfxProfile = weapon.get_weapon_vfx_profile()
		if profile == null or profile.get_script() != WeaponVfxProfileScript:
			_errors.append("%s should bind a WeaponVfxProfile." % weapon.id)
			continue
		for property_name in ["firearm_muzzle_scene", "firearm_projectile_scene", "firearm_impact_scene", "firearm_target_hit_scene"]:
			var scene := profile.get(property_name) as PackedScene
			if scene == null:
				_errors.append("%s VFX profile is missing %s." % [weapon.id, property_name])
				continue
			var instance := scene.instantiate()
			if not (instance is Node3D):
				_errors.append("%s VFX scene should instantiate as Node3D: %s." % [weapon.id, property_name])
			if instance != null:
				instance.free()
	var pistol_profile: WeaponVfxProfile = (Pistol as ItemDef).get_weapon_vfx_profile()
	var smg_profile: WeaponVfxProfile = (Smg as ItemDef).get_weapon_vfx_profile()
	if pistol_profile == null or smg_profile == null:
		return
	for property_name in ["firearm_muzzle_scene", "firearm_projectile_scene", "firearm_impact_scene", "firearm_target_hit_scene"]:
		if pistol_profile.get(property_name) != smg_profile.get(property_name):
			_errors.append("Pistol-S and SMG-S must share the approved firearm VFX scene for %s." % property_name)


func _validate_player_boundary() -> void:
	var player := PlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	if player.get_node_or_null("CombatVfxSpawner3D") == null:
		_errors.append("Player should expose CombatVfxSpawner3D for firearm presentation only.")
	player.queue_free()
	await process_frame


func _validate_source_contract() -> void:
	for scene_path in [
		"res://scenes/combat/vfx/lelu_firearm_muzzle_feedback_3d.tscn",
		"res://scenes/combat/vfx/lelu_firearm_impact_feedback_3d.tscn",
	]:
		var scene_source := FileAccess.get_file_as_string(scene_path)
		if not scene_source.contains("GradientTexture2D") or not scene_source.contains("albedo_texture = SubResource(\"Texture_contrast\")"):
			_errors.append("Firearm contrast backing must use a radial transparent mask, not a black square texture: %s." % scene_path)
	var muzzle_scene_source := FileAccess.get_file_as_string("res://scenes/combat/vfx/lelu_firearm_muzzle_feedback_3d.tscn")
	var impact_scene_source := FileAccess.get_file_as_string("res://scenes/combat/vfx/lelu_firearm_impact_feedback_3d.tscn")
	var target_scene_source := FileAccess.get_file_as_string("res://scenes/combat/vfx/lelu_firearm_target_hit_feedback_3d.tscn")
	if not muzzle_scene_source.contains("MuzzleBurst") or not impact_scene_source.contains("ImpactShockRing"):
		_errors.append("Firearm feedback should keep centered burst and shock-ring response layers.")
	if muzzle_scene_source.contains("[node name=\"Sparks\"") or impact_scene_source.contains("[node name=\"ImpactSparks\""):
		_errors.append("Firearm feedback must not restore fragment particle nodes.")
	var tracer_scene_source := FileAccess.get_file_as_string("res://scenes/combat/vfx/lelu_firearm_projectile_tracer_3d.tscn")
	if not tracer_scene_source.contains("position = Vector3(0, 0, -1.2)"):
		_errors.append("Projectile tracer must offset its centered tail fully forward so it never extends behind the muzzle.")
	if not muzzle_scene_source.contains("hit_fire2_flare.png") or not tracer_scene_source.contains("fire_strike_trail.png"):
		_errors.append("Firearm VFX must use the approved restrained Hit_Fire2 muzzle and FireStrike tracer texture adaptation.")
	if not muzzle_scene_source.contains("res://VFX/Scenes/VFX_Hit_fire_2.tscn") or not tracer_scene_source.contains("res://VFX/Scenes/VFX_Fire_strike.tscn"):
		_errors.append("Firearm preview must bind the explicitly approved full Hit_Fire2 and FireStrike vendor scenes.")
	if not target_scene_source.contains("res://VFX/Scenes/VFX_Anticipation_fire_3.tscn"):
		_errors.append("Confirmed target hit must bind the approved Anticipation_Fire3 vendor scene.")
	for scene_path in [
		"res://scenes/combat/vfx/lelu_firearm_muzzle_feedback_3d.tscn",
		"res://scenes/combat/vfx/lelu_firearm_impact_feedback_3d.tscn",
		"res://scenes/combat/vfx/lelu_firearm_target_hit_feedback_3d.tscn",
		"res://VFX/Scenes/VFX_Anticipation_fire_3.tscn",
		"res://VFX/Scenes/VFX_Hit_fire_2.tscn",
		"res://VFX/Scenes/VFX_Fire_strike.tscn",
	]:
		if FileAccess.get_file_as_string(scene_path).contains("type=\"OmniLight3D\""):
			_errors.append("Firearm VFX must not contain point-light nodes: %s." % scene_path)
	var target_vendor_source := FileAccess.get_file_as_string("res://VFX/Scenes/VFX_Anticipation_fire_3.tscn")
	if target_vendor_source.contains("[node name=\"sparks\""):
		_errors.append("Confirmed target hit must not restore fragment sparks.")
	for path in [
		"res://VFX/Scenes/VFX_Anticipation_fire_3.tscn",
		"res://VFX/Scenes/VFX_Hit_fire_2.tscn",
		"res://VFX/Scenes/VFX_Fire_strike.tscn",
		"res://VFX/Misc/Trail3D.gd",
	]:
		if not FileAccess.file_exists(path):
			_errors.append("Magic Projectiles preview dependency is missing: %s." % path)
	var muzzle_source := FileAccess.get_file_as_string("res://scripts/combat/firearm_muzzle_feedback_3d.gd")
	for required in ["_align_overlapping_layers", "_halo.global_position = _core.global_position", "_contrast.global_position = _core.global_position"]:
		if not muzzle_source.contains(required):
			_errors.append("Muzzle feedback should keep one shared flash center through %s." % required)
	for path in [
		"res://assets/vendor/lelu_vfx2/firearm/soft_circle.png",
		"res://assets/vendor/lelu_vfx2/firearm/impact_flare.png",
		"res://assets/vendor/lelu_vfx2/firearm/muzzle_burst.png",
		"res://assets/vendor/lelu_vfx2/firearm/impact_shock_ring.png",
		"res://assets/vendor/lelu_vfx2/firearm/hit_fire2_flare.png",
		"res://assets/vendor/lelu_vfx2/firearm/fire_strike_trail.png",
		"res://assets/vendor/lelu_vfx2/LICENSE.txt",
		"res://assets/vendor/lelu_vfx2/SOURCE.md",
	]:
		if not FileAccess.file_exists(path):
			_errors.append("LeLu VFX dependency record is missing: %s." % path)
	var weapon_source := FileAccess.get_file_as_string("res://scripts/combat/weapon_controller_3d.gd")
	if weapon_source.contains("Godot_Tool") or weapon_source.contains("GODOT_VFX2"):
		_errors.append("Runtime weapon code must not retain an absolute third-party library path.")
