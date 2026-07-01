extends SceneTree

const DamageableScript := preload("res://scripts/combat/damageable_3d.gd")
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")
const WeaponControllerScript := preload("res://scripts/combat/weapon_controller_3d.gd")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_damageable()
	_validate_weapon_controller()
	_validate_scene_slice()
	if _errors.is_empty():
		print("[combat_domain] OK damageable=works weapon=applies_damage scene=has_target")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_damageable() -> void:
	var target := DamageableScript.new()
	target.max_health = 30.0
	root.add_child(target)
	target._ready()
	var event := DamageEventScript.new(12.0, null, Pistol, [&"test"])
	if not target.apply_damage(event):
		_errors.append("Damageable3D should accept positive damage events.")
	if not is_equal_approx(target.current_health, 18.0):
		_errors.append("Damageable3D should subtract event damage from current health.")
	target.queue_free()


func _validate_weapon_controller() -> void:
	var target := DamageableScript.new()
	target.max_health = 50.0
	root.add_child(target)
	target._ready()
	var weapon := WeaponControllerScript.new()
	weapon.weapon_def = Pistol
	root.add_child(weapon)
	if not weapon.fire_at(target):
		_errors.append("WeaponController3D should apply damage to a damageable target.")
	if target.current_health >= target.max_health:
		_errors.append("WeaponController3D should reduce target health.")
	weapon.queue_free()
	target.queue_free()


func _validate_scene_slice() -> void:
	var scene := load("res://scenes/gameplay/player_test_world_3d.tscn") as PackedScene
	if scene == null:
		_errors.append("Cannot load gameplay test world.")
		return
	var instance := scene.instantiate()
	root.add_child(instance)
	var target := instance.find_child("CombatTarget", true, false)
	if target == null or not target.has_method("apply_damage"):
		_errors.append("Gameplay test world should include a CombatTarget with Damageable3D.")
	var player := instance.find_child("Player3D", true, false)
	var weapon := player.find_child("WeaponController3D", true, false) if player != null else null
	if weapon == null or not weapon.has_method("fire_at"):
		_errors.append("Player3D should include WeaponController3D for the combat slice.")
	instance.queue_free()

