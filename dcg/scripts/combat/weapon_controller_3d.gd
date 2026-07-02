class_name WeaponController3D
extends Node3D

const DamageEventScript := preload("res://scripts/combat/damage_event.gd")
const WeaponAmmoModelScript := preload("res://scripts/combat/weapon_ammo_model.gd")

signal fired(item_def: ItemDef)
signal hit(target: Node, event: DamageEvent)
signal missed(item_def: ItemDef)
signal fire_blocked(reason: StringName)

@export var weapon_def: ItemDef
@export var fallback_damage: float = 10.0
@export var weapon_range: float = 28.0
@export_range(0.0, 5.0, 0.01) var fire_cooldown_seconds := 0.28
@export_range(0, 999, 1) var magazine_size := 8
@export_range(0, 999, 1) var current_ammo := 0
@export_range(0, 999, 1) var reserve_ammo := 0

var last_fire_result := {
	"fired": false,
	"hit": false,
	"blocked_reason": "",
	"current_ammo": 0,
	"reserve_ammo": 0,
}

var _last_fire_time := -9999.0
var _ammo_model := WeaponAmmoModelScript.new()


func _init() -> void:
	_connect_ammo_model()


func _ready() -> void:
	_connect_ammo_model()
	_sync_ammo_model_from_public_counts()


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
	_sync_ammo_model_from_public_counts()
	if weapon_def == null:
		return &"no_weapon"
	if not _ammo_model.can_fire():
		return &"no_ammo"
	if _cooldown_remaining() > 0.0:
		return &"cooldown"
	return &""


func equip_weapon(item_def: ItemDef) -> bool:
	if item_def == null or item_def.item_type != "weapon":
		clear_weapon()
		return false
	var loaded_count := current_ammo
	var reserve_count := reserve_ammo
	weapon_def = item_def
	_ammo_model.configure_weapon(item_def, true)
	_ammo_model.set_counts(loaded_count, reserve_count)
	_sync_public_ammo_counts()
	return true


func clear_weapon() -> void:
	weapon_def = null
	_ammo_model.clear_weapon(true)
	_sync_public_ammo_counts()


func has_weapon() -> bool:
	return weapon_def != null


func get_ammo_model() -> RefCounted:
	return _ammo_model


func set_reserve_ammo_from_item(ammo_item: ItemDef, quantity: int) -> bool:
	_sync_ammo_model_from_public_counts()
	var result := _ammo_model.set_reserve_ammo(ammo_item, quantity)
	_sync_public_ammo_counts()
	return result


func add_reserve_ammo_from_item(ammo_item: ItemDef, quantity: int) -> bool:
	_sync_ammo_model_from_public_counts()
	var result := _ammo_model.add_reserve_ammo(ammo_item, quantity)
	_sync_public_ammo_counts()
	return result


func reload_from_reserve() -> bool:
	_sync_ammo_model_from_public_counts()
	var moved := _ammo_model.reload_from_reserve()
	if moved <= 0:
		return false
	_sync_public_ammo_counts()
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
	_ammo_model.consume_round()
	_sync_public_ammo_counts()
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
	_sync_ammo_model_from_public_counts()
	_sync_public_ammo_counts()


func _connect_ammo_model() -> void:
	if not _ammo_model.changed.is_connected(_sync_public_ammo_counts):
		_ammo_model.changed.connect(_sync_public_ammo_counts)


func _sync_public_ammo_counts() -> void:
	magazine_size = int(_ammo_model.get_state().get("magazine_capacity", magazine_size))
	current_ammo = int(_ammo_model.get_state().get("loaded_ammo", current_ammo))
	reserve_ammo = int(_ammo_model.get_state().get("reserve_ammo", reserve_ammo))
	last_fire_result["current_ammo"] = current_ammo
	last_fire_result["reserve_ammo"] = reserve_ammo


func _sync_ammo_model_from_public_counts() -> void:
	var loaded_count := current_ammo
	var reserve_count := reserve_ammo
	if weapon_def == null:
		_ammo_model.clear_weapon(true)
		_ammo_model.set_counts(loaded_count, reserve_count)
		return
	if _ammo_model.get_state().get("weapon_id", &"") != weapon_def.id:
		_ammo_model.configure_weapon(weapon_def, true)
	_ammo_model.set_counts(loaded_count, reserve_count)


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
