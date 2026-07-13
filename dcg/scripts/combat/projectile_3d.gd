class_name Projectile3D
extends Area3D

signal projectile_hit(target: Node, event: DamageEvent)
signal projectile_missed

const WeaponTuningServiceScript := preload("res://scripts/combat/weapon_tuning_service.gd")

@export var speed := 34.0
@export var max_distance := 28.0
@export var lifetime_seconds := 1.25

var damage_event: DamageEvent = null
var shooter: Node = null
var weapon_def: ItemDef = null
var combat_vfx_spawner: Node = null

var _direction := Vector3.FORWARD
var _start_position := Vector3.ZERO
var _elapsed := 0.0
var _has_finished := false
var _pierced_damage_targets: Array[Node] = []
var _pierced_colliders: Array[Node] = []


func _ready() -> void:
	_start_position = global_position
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(origin: Vector3, direction: Vector3, event: DamageEvent, source_weapon: ItemDef, source_shooter: Node, source_vfx_spawner: Node = null) -> void:
	if is_inside_tree():
		global_position = origin
	else:
		position = origin
	_start_position = origin
	_direction = direction.normalized() if direction != Vector3.ZERO else Vector3.FORWARD
	damage_event = event
	weapon_def = source_weapon
	shooter = source_shooter
	combat_vfx_spawner = source_vfx_spawner
	_pierced_damage_targets.clear()
	_pierced_colliders.clear()
	if is_inside_tree():
		look_at_from_position(origin, origin + _direction, Vector3.UP)
	if combat_vfx_spawner != null and combat_vfx_spawner.has_method("attach_projectile_travel"):
		combat_vfx_spawner.call("attach_projectile_travel", self, weapon_def)


func _physics_process(delta: float) -> void:
	if _has_finished:
		return
	var movement := _direction * speed * delta
	var next_position := global_position + movement
	if _try_segment_hit(global_position, next_position):
		return
	global_position = next_position
	_elapsed += delta
	if global_position.distance_to(_start_position) >= max_distance or _elapsed >= lifetime_seconds:
		_finish_miss()


func _on_body_entered(body: Node) -> void:
	_try_hit(body, global_position)


func _on_area_entered(area: Area3D) -> void:
	_try_hit(area, global_position)


func _try_hit(target: Node, hit_position: Vector3) -> void:
	if _has_finished or target == null or target == shooter:
		return
	var damage_target := _resolve_damage_target(target)
	if damage_target == null:
		_play_impact_vfx(hit_position, false)
		_finish_miss()
		return
	if _pierced_damage_targets.has(damage_target):
		return
	var did_hit: bool = damage_target.apply_damage(damage_event)
	if did_hit:
		_play_impact_vfx(hit_position, true, damage_target as Node3D)
		projectile_hit.emit(damage_target, damage_event)
		if _should_pierce_after_hit(damage_target, target):
			return
	else:
		_play_impact_vfx(hit_position, false)
		projectile_missed.emit()
	_has_finished = true
	queue_free()


func _try_segment_hit(from_position: Vector3, to_position: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var query := PhysicsRayQueryParameters3D.create(from_position, to_position)
	query.exclude = [self] + _pierced_colliders
	if shooter != null:
		query.exclude.append(shooter)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var collider := result.get("collider") as Node
	var hit_position := result.get("position", to_position) as Vector3
	_try_hit(collider, hit_position)
	return _has_finished


func _should_pierce_after_hit(damage_target: Node, collider: Node) -> bool:
	if damage_event == null or not WeaponTuningServiceScript.chance_succeeds(float(damage_event.projectile_pierce_chance)):
		return false
	_pierced_damage_targets.append(damage_target)
	if collider != null and not _pierced_colliders.has(collider):
		_pierced_colliders.append(collider)
	if damage_target != collider and damage_target != null and not _pierced_colliders.has(damage_target):
		_pierced_colliders.append(damage_target)
	return true


func _play_impact_vfx(hit_position: Vector3, did_damage: bool, damaged_target: Node3D = null) -> void:
	if combat_vfx_spawner != null and combat_vfx_spawner.has_method("play_projectile_impact"):
		combat_vfx_spawner.call("play_projectile_impact", hit_position, _direction, weapon_def, did_damage, damaged_target)


func _finish_miss() -> void:
	_has_finished = true
	projectile_missed.emit()
	queue_free()


func _resolve_damage_target(target: Node) -> Node:
	if target == null:
		return null
	if target.has_method("apply_damage"):
		return target
	for child in target.get_children():
		if child is Node and child.has_method("apply_damage"):
			return child
	var parent := target.get_parent()
	if parent != null and parent.has_method("apply_damage"):
		return parent
	return null
