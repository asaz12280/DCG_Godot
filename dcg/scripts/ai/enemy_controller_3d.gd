class_name EnemyController3D
extends Node

signal state_changed(state: StringName)
signal attacked(target: Node, damage: float)

const STATE_IDLE := &"idle"
const STATE_ALERT := &"alert"
const STATE_CHASE := &"chase"
const STATE_ATTACK := &"attack"
const STATE_DEAD := &"dead"
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")

@export var target_group := "player"
@export_range(0.1, 10.0, 0.1) var attack_range := 1.35
@export_range(0.1, 10.0, 0.1) var attack_cooldown := 1.0

var state: StringName = STATE_IDLE
var target: Node3D
var _enemy_body: CharacterBody3D
var _enemy_def: Resource
var _attack_timer := 0.0


func _ready() -> void:
	_enemy_body = get_parent() as CharacterBody3D
	if _enemy_body != null:
		_enemy_def = _enemy_body.get_meta("enemy_def", null) as Resource
		if _enemy_body.has_signal("died"):
			_enemy_body.died.connect(_on_enemy_died)
	_set_state(STATE_IDLE)


func _physics_process(delta: float) -> void:
	if state == STATE_DEAD or _enemy_body == null:
		return
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	target = _resolve_target()
	if target == null:
		_stop_movement()
		_set_state(STATE_IDLE)
		return

	var distance := _enemy_body.global_position.distance_to(target.global_position)
	if distance > _detect_radius():
		_stop_movement()
		_set_state(STATE_IDLE)
	elif distance > attack_range:
		_chase_target(delta)
	else:
		_attack_target()


func get_state() -> Dictionary:
	return {
		"state": state,
		"has_target": target != null,
		"attack_ready": _attack_timer <= 0.0,
	}


func _resolve_target() -> Node3D:
	var candidates := get_tree().get_nodes_in_group(target_group)
	var best_target: Node3D
	var best_distance := INF
	for candidate in candidates:
		var node := candidate as Node3D
		if node == null:
			continue
		if node.has_method("is_alive") and not bool(node.call("is_alive")):
			continue
		var distance := _enemy_body.global_position.distance_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = node
	return best_target


func _chase_target(_delta: float) -> void:
	_set_state(STATE_CHASE)
	var direction := target.global_position - _enemy_body.global_position
	direction.y = 0.0
	if direction.length() <= 0.01:
		_stop_movement()
		return
	_enemy_body.velocity = direction.normalized() * _move_speed()
	_enemy_body.move_and_slide()
	_enemy_body.look_at(Vector3(target.global_position.x, _enemy_body.global_position.y, target.global_position.z), Vector3.UP)


func _attack_target() -> void:
	_stop_movement()
	_set_state(STATE_ATTACK)
	if _attack_timer > 0.0 or target == null or not target.has_method("apply_damage"):
		return
	var event := DamageEventScript.new(_damage(), _enemy_body, null, [&"enemy", &"melee"])
	if bool(target.call("apply_damage", event)):
		attacked.emit(target, _damage())
	_attack_timer = attack_cooldown


func _stop_movement() -> void:
	_enemy_body.velocity = Vector3.ZERO


func _set_state(next_state: StringName) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(state)


func _on_enemy_died(_event: DamageEvent) -> void:
	_stop_movement()
	_set_state(STATE_DEAD)


func _move_speed() -> float:
	return float(_enemy_def.move_speed) if _enemy_def != null and "move_speed" in _enemy_def else 3.0


func _damage() -> float:
	return float(_enemy_def.damage) if _enemy_def != null and "damage" in _enemy_def else 5.0


func _detect_radius() -> float:
	return float(_enemy_def.detect_radius) if _enemy_def != null and "detect_radius" in _enemy_def else 8.0
