class_name FirearmMuzzleFeedback3D
extends Node3D

@export_range(0.02, 0.2, 0.01) var core_duration_seconds := 0.07
@export_range(0.1, 1.0, 0.01) var cleanup_seconds := 0.65

@onready var _core := get_node_or_null("CoreFlare") as MeshInstance3D
@onready var _halo := get_node_or_null("MuzzleHalo") as MeshInstance3D
@onready var _contrast := get_node_or_null("ContrastBacking") as MeshInstance3D
@onready var _burst := get_node_or_null("MuzzleBurst") as MeshInstance3D

var _core_scale := Vector3.ONE
var _halo_scale := Vector3.ONE
var _contrast_scale := Vector3.ONE
var _burst_scale := Vector3.ONE


func _ready() -> void:
	if _core != null:
		_core_scale = _core.scale
		_core.visible = false
	if _halo != null:
		_halo_scale = _halo.scale
		_halo.visible = false
	if _contrast != null:
		_contrast_scale = _contrast.scale
		_contrast.visible = false
	if _burst != null:
		_burst_scale = _burst.scale
		_burst.visible = false


func setup(origin: Vector3, direction: Vector3, _weapon_def: ItemDef = null) -> void:
	global_position = origin
	var forward := direction.normalized() if direction != Vector3.ZERO else Vector3.FORWARD
	look_at(origin + forward, Vector3.UP)
	_play()


func _play() -> void:
	_align_overlapping_layers()
	_set_core_visible(true)
	for emitter in _emitters():
		emitter.restart()
		emitter.emitting = true
	var tween := create_tween().set_parallel(true)
	if _core != null:
		_core.scale = _core_scale * 0.72
		tween.tween_property(_core, "scale", _core_scale * 1.08, core_duration_seconds)
	if _halo != null:
		_halo.scale = _halo_scale * 0.66
		tween.tween_property(_halo, "scale", _halo_scale * 1.22, cleanup_seconds * 0.62)
	if _burst != null:
		_burst.scale = _burst_scale * 0.42
		tween.tween_property(_burst, "scale", _burst_scale * 1.18, core_duration_seconds)
	get_tree().create_timer(core_duration_seconds).timeout.connect(func() -> void: _set_core_visible(false))
	get_tree().create_timer(cleanup_seconds).timeout.connect(queue_free)


func _align_overlapping_layers() -> void:
	if _core == null:
		return
	if _halo != null:
		_halo.global_position = _core.global_position
	if _contrast != null:
		_contrast.global_position = _core.global_position
	if _burst != null:
		_burst.global_position = _core.global_position


func _set_core_visible(is_visible: bool) -> void:
	if _core != null:
		_core.visible = is_visible
	if _contrast != null:
		_contrast.visible = is_visible
	if _burst != null:
		_burst.visible = is_visible
	if _halo != null:
		_halo.visible = is_visible


func _emitters() -> Array[GPUParticles3D]:
	var result: Array[GPUParticles3D] = []
	for node_name in ["WarmRing"]:
		var emitter := get_node_or_null(node_name) as GPUParticles3D
		if emitter != null:
			result.append(emitter)
	return result
