class_name DamageEvent
extends RefCounted

var amount: float = 0.0
var source: Node = null
var item_def: ItemDef = null
var ammo_def: ItemDef = null
var armor_penetration_level: float = 0.0
var critical_chance: float = 0.0
var is_critical: bool = false
var projectile_pierce_chance: float = 0.0
var tags: Array[StringName] = []


func _init(damage_amount: float = 0.0, damage_source: Node = null, source_item: ItemDef = null, source_tags: Array[StringName] = []) -> void:
	amount = maxf(damage_amount, 0.0)
	source = damage_source
	item_def = source_item
	tags = source_tags.duplicate()
