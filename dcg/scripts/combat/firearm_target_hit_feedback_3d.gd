class_name FirearmTargetHitFeedback3D
extends Node3D

@export_range(0.05, 1.2, 0.01) var cleanup_seconds := 0.65


func setup(hit_position: Vector3, incoming_direction: Vector3, _target: Node3D = null) -> void:
	global_position = hit_position
	var forward := incoming_direction.normalized() if incoming_direction != Vector3.ZERO else Vector3.FORWARD
	look_at(hit_position + forward, Vector3.UP)
	get_tree().create_timer(cleanup_seconds).timeout.connect(queue_free)
