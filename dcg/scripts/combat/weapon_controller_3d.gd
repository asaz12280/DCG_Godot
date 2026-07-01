class_name WeaponController3D
extends Node3D

const DamageEventScript := preload("res://scripts/combat/damage_event.gd")

signal fired(item_def: ItemDef)
signal hit(target: Node, event: DamageEvent)

@export var weapon_def: ItemDef
@export var fallback_damage: float = 10.0
@export var range: float = 28.0


func fire_at(target: Node) -> bool:
	var event := _make_damage_event()
	var damage_target := _resolve_damage_target(target)
	if damage_target == null:
		fired.emit(weapon_def)
		return false
	var did_hit: bool = damage_target.apply_damage(event)
	fired.emit(weapon_def)
	if did_hit:
		hit.emit(damage_target, event)
	return did_hit


func fire_forward(origin: Vector3, direction: Vector3, space_state: PhysicsDirectSpaceState3D) -> bool:
	if space_state == null or direction == Vector3.ZERO:
		fired.emit(weapon_def)
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * range)
	query.exclude = [get_parent()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		fired.emit(weapon_def)
		return false
	return fire_at(result.get("collider") as Node)


func _make_damage_event() -> DamageEvent:
	var damage := fallback_damage
	var tags: Array[StringName] = []
	if weapon_def != null:
		damage = float(maxi(weapon_def.damage, roundi(fallback_damage)))
		tags = weapon_def.tags.duplicate()
	return DamageEventScript.new(damage, get_parent(), weapon_def, tags)


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

