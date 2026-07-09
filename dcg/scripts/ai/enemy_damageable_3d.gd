class_name EnemyDamageable3D
extends CharacterBody3D

const ArmorMitigationServiceScript := preload("res://scripts/combat/armor_mitigation_service.gd")

signal health_changed(current: float, maximum: float)
signal damaged(event: DamageEvent)
signal died(event: DamageEvent)

@export var max_health := 45.0
@export_range(0.0, 10.0, 1.0) var armor_protection_level := 0.0

var current_health := 0.0


func _ready() -> void:
	current_health = max_health
	add_to_group("enemy")
	add_to_group("damageable")
	health_changed.emit(current_health, max_health)


func apply_damage(event: DamageEvent) -> bool:
	if event == null or event.amount <= 0.0 or current_health <= 0.0:
		return false
	var mitigated_amount := ArmorMitigationServiceScript.damage_after_armor(event, 0.0, armor_protection_level)
	current_health = maxf(current_health - mitigated_amount, 0.0)
	health_changed.emit(current_health, max_health)
	damaged.emit(event)
	if current_health <= 0.0:
		died.emit(event)
	return true


func is_alive() -> bool:
	return current_health > 0.0
