class_name EnemyController3D
extends Node

signal state_changed(state: StringName)
signal attack_windup_started(target: Node)
signal attacked(target: Node, damage: float)

const STATE_IDLE := &"idle"
const STATE_ALERT := &"alert"
const STATE_CHASE := &"chase"
const STATE_SEARCH := &"search"
const STATE_ATTACK := &"attack"
const STATE_DEAD := &"dead"
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")

@export var target_group := "player"
@export_range(0.1, 10.0, 0.1) var attack_range := 1.35
@export_range(0.05, 2.0, 0.05) var attack_windup_duration := 0.35
@export_range(0.1, 10.0, 0.1) var attack_cooldown := 1.0
@export var use_navigation := true
@export_range(0.05, 1.0, 0.05) var navigation_refresh_interval := 0.2
@export_range(0.1, 3.0, 0.1) var navigation_repath_distance := 0.75
@export_range(0.1, 2.0, 0.05) var stuck_check_interval := 0.35
@export_range(0.01, 1.0, 0.01) var stuck_min_progress := 0.08
@export_range(0.1, 2.0, 0.05) var stuck_recovery_duration := 0.45
@export_range(0.2, 2.0, 0.05) var stuck_probe_distance := 0.9
@export_range(4.0, 40.0, 0.5) var forget_distance := 18.0
@export_range(0.1, 10.0, 0.1) var damage_alert_min_duration := 2.0
@export_range(0.2, 10.0, 0.1) var search_duration := 4.0
@export_range(0.1, 3.0, 0.1) var search_arrival_distance := 0.75

var state: StringName = STATE_IDLE
var target: Node3D
var _enemy_body: CharacterBody3D
var _navigation_agent: NavigationAgent3D
var _enemy_def: Resource
var _behavior_profile: EnemyBehaviorProfile
var _attack_timer := 0.0
var _windup_timer := 0.0
var _windup_target: Node3D = null
var _navigation_refresh_timer := 0.0
var _last_navigation_target := Vector3.ZERO
var _has_navigation_target := false
var _stuck_check_timer := 0.0
var _last_progress_position := Vector3.ZERO
var _recovery_timer := 0.0
var _recovery_direction := Vector3.ZERO
var _alerted_target: Node3D = null
var _has_damage_alert := false
var _last_known_target_position := Vector3.ZERO
var _has_last_known_target_position := false
var _damage_alert_timer := 0.0
var _search_timer := 0.0


func _ready() -> void:
	_enemy_body = get_parent() as CharacterBody3D
	if _enemy_body != null:
		_enemy_def = _enemy_body.get_meta("enemy_def", null) as Resource
		_behavior_profile = _enemy_def.behavior_profile if _enemy_def != null and "behavior_profile" in _enemy_def else null
		_apply_behavior_profile()
		_last_progress_position = _enemy_body.global_position
		_stuck_check_timer = stuck_check_interval
		_navigation_agent = _enemy_body.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
		if _navigation_agent != null:
			_navigation_agent.max_speed = _move_speed()
		if _enemy_body.has_signal("died"):
			_enemy_body.died.connect(_on_enemy_died)
		if _enemy_body.has_signal("damaged"):
			_enemy_body.damaged.connect(_on_enemy_damaged)
	_set_state(STATE_IDLE)


func _physics_process(delta: float) -> void:
	if state == STATE_DEAD or _enemy_body == null:
		return
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_navigation_refresh_timer = maxf(_navigation_refresh_timer - delta, 0.0)
	_damage_alert_timer = maxf(_damage_alert_timer - delta, 0.0)
	target = _resolve_target()
	if target == null:
		_cancel_windup()
		_search_last_known_position(delta)
		return

	var distance := _enemy_body.global_position.distance_to(target.global_position)
	if not _can_track_target(distance):
		_cancel_windup()
		_search_last_known_position(delta)
	elif distance > attack_range or not _has_attack_clearance():
		_cancel_windup()
		_remember_target_position(target.global_position)
		_chase_target(delta)
	else:
		_remember_target_position(target.global_position)
		_prepare_or_attack(delta)


func get_state() -> Dictionary:
	return {
		"state": state,
		"has_target": target != null,
		"attack_ready": _attack_timer <= 0.0,
		"attack_windup": _windup_timer,
		"using_navigation": _navigation_agent != null and use_navigation,
		"stuck_recovery": _recovery_timer > 0.0,
		"damage_alert": _has_damage_alert,
		"damage_alert_time": _damage_alert_timer,
		"has_last_known_position": _has_last_known_target_position,
		"last_known_position": _last_known_target_position,
		"search_time": _search_timer,
	}


func _resolve_target() -> Node3D:
	if _is_valid_target(_alerted_target):
		return _alerted_target
	_clear_damage_alert()

	var candidates := get_tree().get_nodes_in_group(target_group)
	var best_target: Node3D
	var best_distance := INF
	for candidate in candidates:
		var node := candidate as Node3D
		if not _is_valid_target(node):
			continue
		var distance := _enemy_body.global_position.distance_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = node
	return best_target


func _is_valid_target(node: Node3D) -> bool:
	if node == null or node == _enemy_body:
		return false
	if node.has_method("is_alive") and not bool(node.call("is_alive")):
		return false
	if _enemy_body != null and node.get_tree() != _enemy_body.get_tree():
		return false
	return true


func _can_track_target(distance: float) -> bool:
	if distance <= _detect_radius():
		return true
	if not _is_damage_alert_target(target):
		return false
	if _damage_alert_timer > 0.0:
		return true
	return distance <= forget_distance


func _remember_target_position(position: Vector3) -> void:
	_last_known_target_position = position
	_has_last_known_target_position = true
	_search_timer = search_duration


func _chase_target(delta: float) -> void:
	var chase_position := _next_chase_position()
	_move_toward_position(chase_position, delta, STATE_CHASE)


func _move_toward_position(destination: Vector3, delta: float, next_state: StringName) -> void:
	_set_state(next_state)
	var direction := destination - _enemy_body.global_position
	direction.y = 0.0
	if direction.length() <= 0.01:
		_stop_movement()
		return
	var desired_direction := direction.normalized()
	_update_stuck_recovery(delta, desired_direction)
	var move_direction := _movement_direction_with_recovery(delta, desired_direction)
	_enemy_body.velocity = move_direction * _move_speed()
	_enemy_body.move_and_slide()
	var look_position := _enemy_body.global_position + move_direction
	_enemy_body.look_at(Vector3(look_position.x, _enemy_body.global_position.y, look_position.z), Vector3.UP)


func _attack_target() -> void:
	_stop_movement()
	_set_state(STATE_ATTACK)
	if _attack_timer > 0.0 or target == null or not target.has_method("apply_damage"):
		return
	var event := DamageEventScript.new(_damage(), _enemy_body, null, [&"enemy", &"melee"])
	if bool(target.call("apply_damage", event)):
		attacked.emit(target, _damage())
	_attack_timer = attack_cooldown


func _prepare_or_attack(delta: float) -> void:
	_stop_movement()
	_reset_stuck_tracking()
	if _attack_timer > 0.0:
		_cancel_windup()
		_set_state(STATE_ATTACK)
		return
	if _windup_target != target or _windup_timer <= 0.0 or state != STATE_ALERT:
		_windup_target = target
		_windup_timer = attack_windup_duration
		_set_state(STATE_ALERT)
		attack_windup_started.emit(target)
		return
	_windup_timer = maxf(_windup_timer - delta, 0.0)
	if _windup_timer <= 0.0:
		_cancel_windup()
		_attack_target()


func _cancel_windup() -> void:
	_windup_timer = 0.0
	_windup_target = null


func _stop_movement() -> void:
	_enemy_body.velocity = Vector3.ZERO


func _movement_direction_with_recovery(delta: float, desired_direction: Vector3) -> Vector3:
	if _recovery_timer <= 0.0 or _recovery_direction.length() <= 0.01:
		return desired_direction
	_recovery_timer = maxf(_recovery_timer - delta, 0.0)
	var mixed := desired_direction * 0.25 + _recovery_direction * 0.75
	if mixed.length() <= 0.01:
		return desired_direction
	return mixed.normalized()


func _update_stuck_recovery(delta: float, desired_direction: Vector3) -> void:
	if desired_direction.length() <= 0.01:
		return
	_stuck_check_timer = maxf(_stuck_check_timer - delta, 0.0)
	if _stuck_check_timer > 0.0:
		return
	var moved := _enemy_body.global_position.distance_to(_last_progress_position)
	if moved < stuck_min_progress:
		_start_stuck_recovery(desired_direction)
	_last_progress_position = _enemy_body.global_position
	_stuck_check_timer = stuck_check_interval


func _start_stuck_recovery(desired_direction: Vector3) -> void:
	_recovery_direction = _best_recovery_direction(desired_direction)
	_recovery_timer = stuck_recovery_duration
	_clear_navigation_target()


func _best_recovery_direction(desired_direction: Vector3) -> Vector3:
	var side := Vector3(-desired_direction.z, 0.0, desired_direction.x)
	if side.length() <= 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var candidates: Array[Vector3] = [
		side,
		-side,
		-desired_direction,
	]
	var best_direction: Vector3 = candidates[0]
	var best_score := -INF
	for direction in candidates:
		var score := _clearance_score(direction)
		if score > best_score:
			best_score = score
			best_direction = direction
	return best_direction.normalized()


func _clearance_score(direction: Vector3) -> float:
	if direction.length() <= 0.01 or _enemy_body == null:
		return 0.0
	var world := _enemy_body.get_world_3d()
	if world == null:
		return stuck_probe_distance
	var from := _enemy_body.global_position + Vector3.UP * 0.65
	var to := from + direction.normalized() * stuck_probe_distance
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_enemy_body.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return stuck_probe_distance
	return from.distance_to(hit.get("position", from))


func _reset_stuck_tracking() -> void:
	if _enemy_body == null:
		return
	_stuck_check_timer = stuck_check_interval
	_last_progress_position = _enemy_body.global_position
	_recovery_timer = 0.0
	_recovery_direction = Vector3.ZERO


func _next_chase_position() -> Vector3:
	if target == null:
		return _enemy_body.global_position
	return _next_navigation_position(target.global_position)


func _next_navigation_position(destination: Vector3) -> Vector3:
	if not use_navigation or _navigation_agent == null:
		return destination

	if not _has_navigation_target or _navigation_refresh_timer <= 0.0 or _last_navigation_target.distance_to(destination) >= navigation_repath_distance:
		_navigation_agent.target_position = destination
		_last_navigation_target = destination
		_has_navigation_target = true
		_navigation_refresh_timer = navigation_refresh_interval

	if _navigation_agent.is_navigation_finished():
		return destination

	var next_path_position := _navigation_agent.get_next_path_position()
	if next_path_position.distance_to(_enemy_body.global_position) <= 0.05:
		return destination
	return next_path_position


func _search_last_known_position(delta: float) -> void:
	target = null
	_clear_damage_alert()
	if not _has_last_known_target_position:
		_stop_movement()
		_clear_navigation_target()
		_reset_stuck_tracking()
		_set_state(STATE_IDLE)
		return
	_search_timer = maxf(_search_timer - delta, 0.0)
	if _search_timer <= 0.0:
		_clear_target_memory()
		_stop_movement()
		_clear_navigation_target()
		_reset_stuck_tracking()
		_set_state(STATE_IDLE)
		return
	var distance := _enemy_body.global_position.distance_to(_last_known_target_position)
	if distance > search_arrival_distance:
		_move_toward_position(_next_navigation_position(_last_known_target_position), delta, STATE_SEARCH)
	else:
		_stop_movement()
		_reset_stuck_tracking()
		_set_state(STATE_SEARCH)


func _clear_navigation_target() -> void:
	_has_navigation_target = false
	_navigation_refresh_timer = 0.0


func _clear_damage_alert() -> void:
	_alerted_target = null
	_has_damage_alert = false
	_damage_alert_timer = 0.0


func _clear_target_memory() -> void:
	_clear_damage_alert()
	_has_last_known_target_position = false
	_last_known_target_position = Vector3.ZERO
	_search_timer = 0.0


func _is_damage_alert_target(node: Node3D) -> bool:
	return _has_damage_alert and node != null and node == _alerted_target


func _has_attack_clearance() -> bool:
	if target == null or _enemy_body == null:
		return false
	var world := _enemy_body.get_world_3d()
	if world == null:
		return true
	var from := _enemy_body.global_position + Vector3.UP * 0.65
	var to := target.global_position + Vector3.UP * 0.65
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_enemy_body.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit.get("collider", null) as Node
	return collider == target or (collider != null and target.is_ancestor_of(collider))


func _set_state(next_state: StringName) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(state)


func _on_enemy_died(_event: DamageEvent) -> void:
	_stop_movement()
	_clear_target_memory()
	_set_state(STATE_DEAD)


func _on_enemy_damaged(event: DamageEvent) -> void:
	if state == STATE_DEAD:
		return
	var attacker := _target_from_damage_event(event)
	if attacker == null:
		return
	_alerted_target = attacker
	_has_damage_alert = true
	_damage_alert_timer = damage_alert_min_duration
	target = attacker
	_remember_target_position(attacker.global_position)
	_cancel_windup()
	_clear_navigation_target()
	_reset_stuck_tracking()
	_set_state(STATE_ALERT)


func _target_from_damage_event(event: DamageEvent) -> Node3D:
	if event == null:
		return null
	var source := event.source
	while source != null:
		var source_node := source as Node3D
		if source_node != null and source_node != _enemy_body:
			if source_node.is_in_group(target_group) or source_node.has_method("apply_damage"):
				return source_node
		source = source.get_parent()
	return null


func _move_speed() -> float:
	return float(_enemy_def.move_speed) if _enemy_def != null and "move_speed" in _enemy_def else 3.0


func _damage() -> float:
	return float(_enemy_def.damage) if _enemy_def != null and "damage" in _enemy_def else 5.0


func _detect_radius() -> float:
	if _behavior_profile != null:
		return _behavior_profile.detect_radius
	if _enemy_def != null and _enemy_def.has_method("get_detect_radius"):
		return float(_enemy_def.call("get_detect_radius"))
	return float(_enemy_def.detect_radius) if _enemy_def != null and "detect_radius" in _enemy_def else 8.0


func _apply_behavior_profile() -> void:
	if _behavior_profile == null:
		return
	attack_range = maxf(_behavior_profile.attack_range, 0.01)
	attack_windup_duration = maxf(_behavior_profile.attack_windup_duration, 0.01)
	attack_cooldown = maxf(_behavior_profile.attack_cooldown, 0.01)
	forget_distance = maxf(_behavior_profile.forget_distance, 0.01)
	damage_alert_min_duration = maxf(_behavior_profile.damage_alert_min_duration, 0.01)
	search_duration = maxf(_behavior_profile.search_duration, 0.01)
	search_arrival_distance = maxf(_behavior_profile.search_arrival_distance, 0.01)
	use_navigation = _behavior_profile.use_navigation
	navigation_refresh_interval = maxf(_behavior_profile.navigation_refresh_interval, 0.01)
	navigation_repath_distance = maxf(_behavior_profile.navigation_repath_distance, 0.01)
	stuck_check_interval = maxf(_behavior_profile.stuck_check_interval, 0.01)
	stuck_min_progress = maxf(_behavior_profile.stuck_min_progress, 0.0)
	stuck_recovery_duration = maxf(_behavior_profile.stuck_recovery_duration, 0.01)
	stuck_probe_distance = maxf(_behavior_profile.stuck_probe_distance, 0.01)
