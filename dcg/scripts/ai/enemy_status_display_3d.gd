class_name EnemyStatusDisplay3D
extends Node3D

@export var damageable_path: NodePath = NodePath("..")
@export var controller_path: NodePath = NodePath("../EnemyController3D")
@export var status_label_path: NodePath = NodePath("StatusLabel")
@export var health_fill_path: NodePath = NodePath("HealthBarFill")
@export var body_path: NodePath = NodePath("../Body")
@export var head_path: NodePath = NodePath("../Head")

var _damageable: Node = null
var _controller: Node = null
var _status_label: Label3D = null
var _health_fill: MeshInstance3D = null
var _body: MeshInstance3D = null
var _head: MeshInstance3D = null
var _base_body_color := Color(0.42, 0.48, 0.38, 1.0)
var _base_head_color := Color(0.64, 0.58, 0.45, 1.0)


func _ready() -> void:
	_damageable = get_node_or_null(damageable_path)
	_controller = get_node_or_null(controller_path)
	_status_label = get_node_or_null(status_label_path) as Label3D
	_health_fill = get_node_or_null(health_fill_path) as MeshInstance3D
	_body = get_node_or_null(body_path) as MeshInstance3D
	_head = get_node_or_null(head_path) as MeshInstance3D

	if _damageable != null:
		if _damageable.has_signal("health_changed"):
			_damageable.health_changed.connect(_on_health_changed)
		if _damageable.has_signal("died"):
			_damageable.died.connect(_on_died)
	if _controller != null and _controller.has_signal("state_changed"):
		_controller.state_changed.connect(_on_state_changed)

	_refresh_from_damageable()
	_set_status_text("待機")


func _refresh_from_damageable() -> void:
	if _damageable == null:
		return
	var current := float(_damageable.get("current_health"))
	var maximum := float(_damageable.get("max_health"))
	_on_health_changed(current, maximum)


func _on_health_changed(current: float, maximum: float) -> void:
	var ratio := 0.0
	if maximum > 0.0:
		ratio = clampf(current / maximum, 0.0, 1.0)
	if _health_fill != null:
		_health_fill.scale.x = maxf(ratio, 0.001)
		_health_fill.position.x = -0.45 + (0.45 * ratio)
	if current <= 0.0:
		_set_status_text("死亡")
		_set_body_color(Color(0.22, 0.22, 0.22, 1.0), Color(0.28, 0.25, 0.23, 1.0))
	elif ratio < 1.0:
		_set_status_text("受傷")
		_set_body_color(Color(0.72, 0.35, 0.28, 1.0), Color(0.78, 0.48, 0.36, 1.0))
	else:
		_set_body_color(_base_body_color, _base_head_color)


func _on_state_changed(state: StringName) -> void:
	if _damageable != null and float(_damageable.get("current_health")) <= 0.0:
		_set_status_text("死亡")
		return
	match state:
		&"chase":
			_set_status_text("追蹤中")
			_set_body_color(_base_body_color, _base_head_color)
		&"attack":
			_set_status_text("攻擊")
			_set_body_color(Color(0.82, 0.22, 0.16, 1.0), Color(0.9, 0.38, 0.28, 1.0))
		&"alert":
			_set_status_text("準備攻擊")
			_set_body_color(Color(0.88, 0.58, 0.18, 1.0), Color(1.0, 0.72, 0.28, 1.0))
		_:
			_set_status_text("待機")
			_set_body_color(_base_body_color, _base_head_color)


func _on_died(_event: DamageEvent) -> void:
	_set_status_text("死亡")
	_set_body_color(Color(0.22, 0.22, 0.22, 1.0), Color(0.28, 0.25, 0.23, 1.0))
	if _health_fill != null:
		_health_fill.scale.x = 0.001


func _set_status_text(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _set_body_color(body_color: Color, head_color: Color) -> void:
	_set_mesh_color(_body, body_color)
	_set_mesh_color(_head, head_color)


func _set_mesh_color(mesh_instance: MeshInstance3D, color: Color) -> void:
	if mesh_instance == null:
		return
	var material := mesh_instance.get_active_material(0) as StandardMaterial3D
	if material == null:
		return
	var unique_material := material.duplicate() as StandardMaterial3D
	unique_material.albedo_color = color
	mesh_instance.set_surface_override_material(0, unique_material)
