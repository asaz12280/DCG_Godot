extends Camera3D

@export_node_path("Node3D") var target_path: NodePath
@export var follow_offset: Vector3 = Vector3(0.0, 8.5, 6.8)
@export var follow_speed: float = 8.0

var _target: Node3D


func _ready() -> void:
	current = true
	if not target_path.is_empty():
		_target = get_node_or_null(target_path)
	if _target != null:
		global_position = _target.global_position + follow_offset
		look_at(_target.global_position, Vector3.UP)


func _process(delta: float) -> void:
	if _target == null:
		return

	var desired_position := _target.global_position + follow_offset
	global_position = global_position.lerp(desired_position, 1.0 - exp(-follow_speed * delta))
	look_at(_target.global_position, Vector3.UP)
