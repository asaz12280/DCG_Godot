@tool
class_name MeleeCrescentSlash3D
extends Node3D

const ARC_GLOW_OUTER_SCALE := 1.035
const EDITOR_PREVIEW_RANGE := 1.45
const EDITOR_PREVIEW_ARC_DEGREES := 110.0
const COUNTERCLOCKWISE_SWEEP := -1.0

@export_range(32, 256, 1) var segment_count := 128
@export_range(0.08, 0.4, 0.01) var swing_seconds := 0.16
@export_range(0.05, 0.4, 0.01) var linger_seconds := 0.18

@onready var _arc_glow := get_node_or_null("ArcGlow") as MeshInstance3D
@onready var _blade_trail := get_node_or_null("BladeTrail") as MeshInstance3D
@onready var _blade_core := get_node_or_null("BladeCore") as MeshInstance3D

var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	for mesh_instance in [_arc_glow, _blade_trail, _blade_core]:
		if mesh_instance == null:
			continue
		var source_material := mesh_instance.material_override as ShaderMaterial
		if source_material != null:
			var material := source_material.duplicate() as ShaderMaterial
			mesh_instance.material_override = material
			_materials.append(material)
	if Engine.is_editor_hint():
		_build_editor_preview()


func setup(attacker_position: Vector3, forward: Vector3, range_meters: float, arc_degrees: float) -> void:
	if _arc_glow == null or _blade_trail == null or _blade_core == null or _materials.size() != 3:
		queue_free()
		return
	var direction := forward.normalized() if forward.length() > 0.001 else Vector3.FORWARD
	direction.y = 0.0
	if direction.length() <= 0.001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	global_position = attacker_position + Vector3.UP * 0.72
	look_at(global_position + direction, Vector3.UP)

	# ArcGlow is scaled up for readability, so shrink its source mesh to keep the visible edge inside attack range.
	var resolved_range := maxf(range_meters, 0.1)
	var geometry_outer_radius := resolved_range / ARC_GLOW_OUTER_SCALE
	var resolved_arc := clampf(arc_degrees, 30.0, 180.0)
	var trail_width := minf(clampf(geometry_outer_radius * 0.28, 0.24, 0.48), geometry_outer_radius * 0.85)
	var arc_mesh := _build_smooth_arc_mesh(geometry_outer_radius, resolved_arc, trail_width)
	_arc_glow.mesh = arc_mesh
	_blade_trail.mesh = arc_mesh
	_blade_core.mesh = arc_mesh
	_set_reveal(0.0)
	_set_alpha(1.0)
	var tween := create_tween()
	tween.tween_method(_set_reveal, 0.0, 1.0, swing_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_alpha, 1.0, 0.0, linger_seconds)
	get_tree().create_timer(swing_seconds + linger_seconds).timeout.connect(queue_free)


func _build_smooth_arc_mesh(outer_radius: float, arc_degrees: float, maximum_width: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var resolved_segments := maxi(segment_count, 32)
	var half_arc := deg_to_rad(arc_degrees * 0.5)
	for index in range(resolved_segments + 1):
		var progress := float(index) / float(resolved_segments)
		var angle := lerpf(-half_arc * COUNTERCLOCKWISE_SWEEP, half_arc * COUNTERCLOCKWISE_SWEEP, progress)
		var width_envelope := pow(maxf(sin(progress * PI), 0.0), 0.72)
		var inner_radius := outer_radius - maximum_width * width_envelope
		var radial_direction := Vector3(sin(angle), 0.0, -cos(angle))
		vertices.append(radial_direction * outer_radius)
		vertices.append(radial_direction * inner_radius)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(progress, 0.0))
		uvs.append(Vector2(progress, 1.0))
		if index < resolved_segments:
			var vertex_index := index * 2
			indices.append_array(PackedInt32Array([
				vertex_index,
				vertex_index + 2,
				vertex_index + 1,
				vertex_index + 1,
				vertex_index + 2,
				vertex_index + 3,
			]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _set_reveal(value: float) -> void:
	for material in _materials:
		material.set_shader_parameter("reveal_progress", clampf(value, 0.0, 1.0))


func _set_alpha(value: float) -> void:
	for material in _materials:
		material.set_shader_parameter("trail_alpha", clampf(value, 0.0, 1.0))


func _build_editor_preview() -> void:
	if _arc_glow == null or _blade_trail == null or _blade_core == null or _materials.size() != 3:
		return
	var geometry_outer_radius := EDITOR_PREVIEW_RANGE / ARC_GLOW_OUTER_SCALE
	var trail_width := minf(clampf(geometry_outer_radius * 0.28, 0.24, 0.48), geometry_outer_radius * 0.85)
	var arc_mesh := _build_smooth_arc_mesh(geometry_outer_radius, EDITOR_PREVIEW_ARC_DEGREES, trail_width)
	_arc_glow.mesh = arc_mesh
	_blade_trail.mesh = arc_mesh
	_blade_core.mesh = arc_mesh
	_set_reveal(1.0)
	_set_alpha(0.82)
