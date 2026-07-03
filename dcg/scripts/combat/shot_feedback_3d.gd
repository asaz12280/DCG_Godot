class_name ShotFeedback3D
extends Node3D

@export var lifetime_seconds := 0.16

var _elapsed := 0.0
var _spark: MeshInstance3D = null
var _tracer: MeshInstance3D = null
var _light: OmniLight3D = null


func _ready() -> void:
	_spark = get_node_or_null("MuzzleSpark") as MeshInstance3D
	_tracer = get_node_or_null("TracerBeam") as MeshInstance3D
	_light = get_node_or_null("MuzzleLight") as OmniLight3D


func setup(origin: Vector3, direction: Vector3) -> void:
	var shot_direction := direction.normalized() if direction != Vector3.ZERO else Vector3.FORWARD
	if is_inside_tree():
		look_at_from_position(origin, origin + shot_direction, Vector3.UP)
	else:
		position = origin


func _process(delta: float) -> void:
	_elapsed += delta
	var progress := clampf(_elapsed / maxf(lifetime_seconds, 0.01), 0.0, 1.0)
	var alpha := 1.0 - progress
	_fade_mesh(_spark, alpha, lerpf(3.2, 0.0, progress))
	_fade_mesh(_tracer, alpha, lerpf(2.4, 0.0, progress))
	if _light != null:
		_light.light_energy = lerpf(1.8, 0.0, progress)
	if progress >= 1.0:
		queue_free()


func _fade_mesh(mesh_instance: MeshInstance3D, alpha: float, emission_energy: float) -> void:
	if mesh_instance == null:
		return
	var material := mesh_instance.get_active_material(0) as StandardMaterial3D
	if material == null:
		return
	material.albedo_color.a = alpha
	material.emission_energy_multiplier = emission_energy
