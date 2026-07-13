class_name MeleeEnemyHitVfx3D
extends Node3D

const LIFETIME_SECONDS := 0.65

@onready var _vendor_vfx := get_node_or_null("VFXAnticipationFire3") as Node3D


func _ready() -> void:
	_make_vendor_white()
	_disable_cross()


func setup(hit_position: Vector3, incoming_direction: Vector3) -> void:
	global_position = hit_position
	var flat_direction := incoming_direction
	flat_direction.y = 0.0
	if flat_direction.length() > 0.001:
		look_at(global_position + flat_direction.normalized(), Vector3.UP)
	get_tree().create_timer(LIFETIME_SECONDS).timeout.connect(queue_free)


func _make_vendor_white() -> void:
	if _vendor_vfx == null:
		return
	for child in _vendor_vfx.get_children():
		var particles := child as GPUParticles3D
		if particles == null:
			continue
		var source_process := particles.process_material as ParticleProcessMaterial
		if source_process != null:
			var white_process := source_process.duplicate() as ParticleProcessMaterial
			white_process.color = Color.WHITE
			_make_color_ramp_white(white_process)
			particles.process_material = white_process


func _disable_cross() -> void:
	var cross := get_node_or_null("VFXAnticipationFire3/cross") as GPUParticles3D
	if cross != null:
		cross.visible = false
		cross.emitting = false


func _make_color_ramp_white(process_material: ParticleProcessMaterial) -> void:
	var source_ramp := process_material.color_ramp as GradientTexture1D
	if source_ramp == null or source_ramp.gradient == null:
		return
	var white_ramp := source_ramp.duplicate() as GradientTexture1D
	var white_gradient := source_ramp.gradient.duplicate() as Gradient
	for index in range(white_gradient.get_point_count()):
		var source_color := white_gradient.get_color(index)
		white_gradient.set_color(index, Color(1.0, 1.0, 1.0, source_color.a))
	white_ramp.gradient = white_gradient
	process_material.color_ramp = white_ramp
