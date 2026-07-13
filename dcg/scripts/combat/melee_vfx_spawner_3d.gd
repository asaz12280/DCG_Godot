class_name MeleeVfxSpawner3D
extends Node3D

const CrescentSlashScene := preload("res://scenes/combat/vfx/melee_crescent_slash_3d.tscn")
const EnemyHitScene := preload("res://scenes/combat/vfx/melee_enemy_hit_feedback_3d.tscn")


func play_crescent_slash(attacker: Node3D, range_meters: float, arc_degrees: float, hit_positions: Array = []) -> void:
	if attacker == null or not attacker.is_inside_tree():
		return
	var parent := attacker.get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	var slash := CrescentSlashScene.instantiate() as Node3D
	if slash == null:
		return
	parent.add_child(slash)
	var forward := -attacker.global_transform.basis.z
	if slash.has_method("setup"):
		slash.call("setup", attacker.global_position, forward, range_meters, arc_degrees)
	for hit_position in hit_positions:
		if hit_position is Vector3:
			_spawn_enemy_hit(parent, hit_position as Vector3, forward)


func _spawn_enemy_hit(parent: Node, hit_position: Vector3, incoming_direction: Vector3) -> void:
	if parent == null:
		return
	var enemy_hit := EnemyHitScene.instantiate() as Node3D
	if enemy_hit == null:
		return
	parent.add_child(enemy_hit)
	if enemy_hit.has_method("setup"):
		enemy_hit.call("setup", hit_position, incoming_direction)
	else:
		enemy_hit.global_position = hit_position
