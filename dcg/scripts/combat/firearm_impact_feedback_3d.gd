class_name FirearmImpactFeedback3D
extends Node3D

@export_range(0.02, 0.2, 0.01) var core_duration_seconds := 0.09
@export_range(0.1, 1.0, 0.01) var cleanup_seconds := 0.42

@onready var _core := get_node_or_null("ImpactCore") as MeshInstance3D
@onready var _halo := get_node_or_null("ImpactHalo") as MeshInstance3D
@onready var _contrast := get_node_or_null("ImpactContrast") as MeshInstance3D
@onready var _shock_ring := get_node_or_null("ImpactShockRing") as MeshInstance3D

var _shock_ring_scale := Vector3.ONE


func _ready() -> void:
	for node in [_core, _halo, _contrast]:
		if node != null:
			node.visible = false
	if _shock_ring != null:
		_shock_ring_scale = _shock_ring.scale
		_shock_ring.visible = false


func setup(hit_position: Vector3, incoming_direction: Vector3, _weapon_def: ItemDef = null) -> void:
	global_position = hit_position
	var forward := incoming_direction.normalized() if incoming_direction != Vector3.ZERO else Vector3.FORWARD
	look_at(hit_position + forward, Vector3.UP)
	_play()


func _play() -> void:
	_align_overlapping_layers()
	for node in [_core, _halo, _contrast]:
		if node != null:
			node.visible = true
	if _shock_ring != null:
		_shock_ring.visible = true
		_shock_ring.scale = _shock_ring_scale * 0.38
		create_tween().tween_property(_shock_ring, "scale", _shock_ring_scale * 1.62, cleanup_seconds * 0.72)
	for emitter in _emitters():
		emitter.restart()
		emitter.emitting = true
	get_tree().create_timer(core_duration_seconds).timeout.connect(_hide_core)
	get_tree().create_timer(cleanup_seconds).timeout.connect(queue_free)


func _align_overlapping_layers() -> void:
	if _core == null:
		return
	if _halo != null:
		_halo.global_position = _core.global_position
	if _contrast != null:
		_contrast.global_position = _core.global_position
	if _shock_ring != null:
		_shock_ring.global_position = _core.global_position


func _hide_core() -> void:
	if _core != null:
		_core.visible = false
	if _contrast != null:
		_contrast.visible = false


func _emitters() -> Array[GPUParticles3D]:
	var result: Array[GPUParticles3D] = []
	for node_name in ["ImpactRing"]:
		var emitter := get_node_or_null(node_name) as GPUParticles3D
		if emitter != null:
			result.append(emitter)
	return result
