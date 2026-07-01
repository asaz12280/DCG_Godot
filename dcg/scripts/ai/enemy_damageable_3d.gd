class_name EnemyDamageable3D
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal died(event: DamageEvent)

@export var max_health := 45.0

var current_health := 0.0


func _ready() -> void:
	current_health = max_health
	add_to_group("enemy")
	add_to_group("damageable")
	health_changed.emit(current_health, max_health)


func apply_damage(event: DamageEvent) -> bool:
	if event == null or event.amount <= 0.0 or current_health <= 0.0:
		return false
	current_health = maxf(current_health - event.amount, 0.0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		died.emit(event)
	return true


func is_alive() -> bool:
	return current_health > 0.0
