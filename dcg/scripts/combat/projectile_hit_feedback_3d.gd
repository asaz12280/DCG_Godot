class_name ProjectileHitFeedback3D
extends Node3D

@export var lifetime_seconds := 0.22
@export var start_scale := Vector3.ONE * 0.35
@export var end_scale := Vector3.ONE * 0.8

var _elapsed := 0.0
var _mesh: MeshInstance3D = null


func _ready() -> void:
	_mesh = get_node_or_null("MeshInstance3D") as MeshInstance3D
	scale = start_scale


func _process(delta: float) -> void:
	_elapsed += delta
	var progress := clampf(_elapsed / maxf(lifetime_seconds, 0.01), 0.0, 1.0)
	scale = start_scale.lerp(end_scale, progress)
	if _mesh != null:
		var material := _mesh.get_active_material(0) as StandardMaterial3D
		if material != null:
			material.albedo_color.a = 1.0 - progress
			material.emission_energy_multiplier = lerpf(1.7, 0.0, progress)
	if progress >= 1.0:
		queue_free()
