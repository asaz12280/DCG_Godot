class_name WeaponController3D
extends Node3D

const DamageEventScript := preload("res://scripts/combat/damage_event.gd")

signal fired(item_def: ItemDef)
signal hit(target: Node, event: DamageEvent)
signal missed(item_def: ItemDef)
signal fire_blocked(reason: StringName)

@export var weapon_def: ItemDef
@export var fallback_damage: float = 10.0
@export var weapon_range: float = 28.0
@export_range(0.0, 5.0, 0.01) var fire_cooldown_seconds := 0.28
@export_range(0, 999, 1) var magazine_size := 8
@export_range(0, 999, 1) var current_ammo := 8
@export_range(0, 999, 1) var reserve_ammo := 24

var last_fire_result := {
	"fired": false,
	"hit": false,
	"blocked_reason": "",
	"current_ammo": 8,
	"reserve_ammo": 24,
}

var _last_fire_time := -9999.0


func fire_at(target: Node) -> bool:
	if not _begin_fire_attempt():
		return false
	var event := _make_damage_event()
	var damage_target := _resolve_damage_target(target)
	if damage_target == null:
		fired.emit(weapon_def)
		missed.emit(weapon_def)
		_record_fire_result(false, "")
		return false
	var did_hit: bool = damage_target.apply_damage(event)
	fired.emit(weapon_def)
	if did_hit:
		hit.emit(damage_target, event)
	else:
		missed.emit(weapon_def)
	_record_fire_result(did_hit, "")
	return did_hit


func fire_forward(origin: Vector3, direction: Vector3, space_state: PhysicsDirectSpaceState3D) -> bool:
	if not _begin_fire_attempt():
		return false
	if space_state == null or direction == Vector3.ZERO:
		fired.emit(weapon_def)
		missed.emit(weapon_def)
		_record_fire_result(false, "")
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * weapon_range)
	query.exclude = [get_parent()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		fired.emit(weapon_def)
		missed.emit(weapon_def)
		_record_fire_result(false, "")
		return false
	return _apply_shot_to_target(result.get("collider") as Node)


func can_fire() -> bool:
	return get_fire_block_reason() == &""


func get_fire_block_reason() -> StringName:
	if weapon_def == null:
		return &"no_weapon"
	if current_ammo <= 0:
		return &"no_ammo"
	if _cooldown_remaining() > 0.0:
		return &"cooldown"
	return &""


func equip_weapon(item_def: ItemDef) -> bool:
	if item_def == null or item_def.item_type != "weapon":
		clear_weapon()
		return false
	weapon_def = item_def
	return true


func clear_weapon() -> void:
	weapon_def = null


func has_weapon() -> bool:
	return weapon_def != null


func reload_from_reserve() -> bool:
	if current_ammo >= magazine_size or reserve_ammo <= 0:
		return false
	var needed := magazine_size - current_ammo
	var moved := mini(needed, reserve_ammo)
	current_ammo += moved
	reserve_ammo -= moved
	_sync_ammo_result()
	return true


func force_cooldown_ready() -> void:
	_last_fire_time = -9999.0


func _make_damage_event() -> DamageEvent:
	var damage := fallback_damage
	var tags: Array[StringName] = []
	if weapon_def != null:
		damage = float(maxi(weapon_def.damage, roundi(fallback_damage)))
		tags = weapon_def.tags.duplicate()
	return DamageEventScript.new(damage, get_parent(), weapon_def, tags)


func _begin_fire_attempt() -> bool:
	var block_reason := get_fire_block_reason()
	if block_reason != &"":
		last_fire_result = {
			"fired": false,
			"hit": false,
			"blocked_reason": str(block_reason),
			"current_ammo": current_ammo,
			"reserve_ammo": reserve_ammo,
		}
		fire_blocked.emit(block_reason)
		return false
	current_ammo = maxi(current_ammo - 1, 0)
	_last_fire_time = _now_seconds()
	return true


func _apply_shot_to_target(target: Node) -> bool:
	var event := _make_damage_event()
	var damage_target := _resolve_damage_target(target)
	if damage_target == null:
		fired.emit(weapon_def)
		missed.emit(weapon_def)
		_record_fire_result(false, "")
		return false
	var did_hit: bool = damage_target.apply_damage(event)
	fired.emit(weapon_def)
	if did_hit:
		hit.emit(damage_target, event)
	else:
		missed.emit(weapon_def)
	_record_fire_result(did_hit, "")
	return did_hit


func _record_fire_result(did_hit: bool, blocked_reason: String) -> void:
	last_fire_result = {
		"fired": true,
		"hit": did_hit,
		"blocked_reason": blocked_reason,
		"current_ammo": current_ammo,
		"reserve_ammo": reserve_ammo,
	}


func _sync_ammo_result() -> void:
	last_fire_result["current_ammo"] = current_ammo
	last_fire_result["reserve_ammo"] = reserve_ammo


func _cooldown_remaining() -> float:
	return maxf((_last_fire_time + fire_cooldown_seconds) - _now_seconds(), 0.0)


func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


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
