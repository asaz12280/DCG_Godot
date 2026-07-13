@tool
class_name MeleeVfxPreview3D
extends Node3D

const CrescentSlashScene := preload("res://scenes/combat/vfx/melee_crescent_slash_3d.tscn")

@export_range(0.6, 3.0, 0.1) var repeat_seconds := 1.0
@export_range(0.1, 3.0, 0.05) var attack_range := 1.45
@export_range(30.0, 180.0, 1.0) var arc_degrees := 110.0
@export_tool_button("Preview Slash", "Play") var preview_slash_action = _preview_slash

@onready var _camera := get_node_or_null("PreviewCamera3D") as Camera3D
@onready var _preview_focus := get_node_or_null("PreviewFocus") as Marker3D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if _camera != null and _preview_focus != null:
		_camera.look_at(_preview_focus.global_position, Vector3.UP)
	_spawn_slash()
	var timer := Timer.new()
	timer.wait_time = repeat_seconds
	timer.timeout.connect(_spawn_slash)
	add_child(timer)
	timer.start()


func _spawn_slash() -> void:
	var slash := CrescentSlashScene.instantiate() as Node3D
	if slash == null:
		return
	add_child(slash)
	if slash.has_method("setup"):
		slash.call("setup", global_position, Vector3.FORWARD, attack_range, arc_degrees)


func _preview_slash() -> void:
	if not Engine.is_editor_hint():
		return
	_spawn_slash()
