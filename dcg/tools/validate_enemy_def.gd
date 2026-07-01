extends SceneTree

const EnemyDefScript := preload("res://scripts/ai/enemy_def.gd")
const ScavengerDef := preload("res://data/enemies/scavenger.tres")
const ScavengerScene := preload("res://scenes/enemies/scavenger_3d.tscn")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_scavenger_def()
	_validate_invalid_def_is_caught()
	_validate_scavenger_scene()
	if _errors.is_empty():
		print("[enemy_def] OK scavenger=data_valid scene=loadable damageable=present")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_scavenger_def() -> void:
	var enemy_def := ScavengerDef as Resource
	if enemy_def == null or enemy_def.get_script() != EnemyDefScript:
		_errors.append("Scavenger enemy data should use EnemyDef script.")
		return
	for error in enemy_def.get_validation_errors():
		_errors.append("Scavenger EnemyDef invalid: %s" % error)


func _validate_invalid_def_is_caught() -> void:
	var enemy_def := EnemyDefScript.new()
	enemy_def.id = &"broken"
	enemy_def.display_name = "Broken"
	enemy_def.max_health = 0.0
	enemy_def.loot_table_path = "res://missing/nope.tres"
	if enemy_def.get_validation_errors().is_empty():
		_errors.append("EnemyDef validation should catch invalid fields.")


func _validate_scavenger_scene() -> void:
	var scene := ScavengerScene.instantiate()
	root.add_child(scene)
	if not scene.is_in_group("enemy"):
		_errors.append("Scavenger scene root should be in enemy group.")
	if not scene.has_method("apply_damage"):
		_errors.append("Scavenger scene root should have Damageable3D or equivalent apply_damage.")
	if scene.get_node_or_null("CollisionShape3D") == null:
		_errors.append("Scavenger scene should include CollisionShape3D.")
	if scene.get_node_or_null("Body") == null or scene.get_node_or_null("Head") == null:
		_errors.append("Scavenger scene should include placeholder body/head meshes.")
	var enemy_def := scene.get_meta("enemy_def", null) as Resource
	if enemy_def == null or enemy_def.get_script() != EnemyDefScript:
		_errors.append("Scavenger scene should reference EnemyDef metadata.")
	elif float(enemy_def.max_health) != float(scene.get("max_health")):
		_errors.append("Scavenger scene max_health should match EnemyDef.")
	scene.free()
