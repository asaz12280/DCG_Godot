class_name EnemyDef
extends Resource

@export var id: StringName = &""
@export var display_name := ""
@export_range(1.0, 10000.0, 1.0) var max_health := 40.0
@export_range(0.0, 30.0, 0.1) var move_speed := 3.2
@export_range(0.0, 500.0, 0.5) var damage := 8.0
@export_range(0.0, 80.0, 0.5) var detect_radius := 8.0
@export var behavior_profile: EnemyBehaviorProfile
@export_file("*.tres", "*.res") var loot_table_path := ""


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("EnemyDef requires id.")
	if display_name == "":
		errors.append("EnemyDef requires display_name.")
	if max_health <= 0.0:
		errors.append("EnemyDef max_health must be positive.")
	if move_speed <= 0.0:
		errors.append("EnemyDef move_speed must be positive.")
	if damage <= 0.0:
		errors.append("EnemyDef damage must be positive.")
	if detect_radius <= 0.0:
		errors.append("EnemyDef detect_radius must be positive.")
	if behavior_profile != null:
		errors.append_array(behavior_profile.get_validation_errors())
	if loot_table_path == "":
		errors.append("EnemyDef requires loot_table_path.")
	elif not ResourceLoader.exists(loot_table_path):
		errors.append("EnemyDef loot_table_path does not exist: %s" % loot_table_path)
	else:
		var table := load(loot_table_path)
		if table == null or not table.has_method("roll"):
			errors.append("EnemyDef loot_table_path must point to a LootTable.")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()


func get_detect_radius() -> float:
	if behavior_profile != null:
		return behavior_profile.detect_radius
	return detect_radius
