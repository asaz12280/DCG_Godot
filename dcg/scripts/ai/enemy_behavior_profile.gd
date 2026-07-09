class_name EnemyBehaviorProfile
extends Resource

@export_range(0.0, 80.0, 0.5) var detect_radius: float = 8.0
@export_range(0.1, 10.0, 0.1) var attack_range: float = 1.35
@export_range(0.05, 2.0, 0.05) var attack_windup_duration: float = 0.35
@export_range(0.1, 10.0, 0.1) var attack_cooldown: float = 1.0
@export_range(4.0, 40.0, 0.5) var forget_distance: float = 18.0
@export_range(0.1, 10.0, 0.1) var damage_alert_min_duration: float = 2.0
@export_range(0.2, 10.0, 0.1) var search_duration: float = 4.0
@export_range(0.1, 3.0, 0.1) var search_arrival_distance: float = 0.75
@export var use_navigation: bool = true
@export_range(0.05, 1.0, 0.05) var navigation_refresh_interval: float = 0.2
@export_range(0.1, 3.0, 0.1) var navigation_repath_distance: float = 0.75
@export_range(0.1, 2.0, 0.05) var stuck_check_interval: float = 0.35
@export_range(0.01, 1.0, 0.01) var stuck_min_progress: float = 0.08
@export_range(0.1, 2.0, 0.05) var stuck_recovery_duration: float = 0.45
@export_range(0.2, 2.0, 0.05) var stuck_probe_distance: float = 0.9


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if detect_radius <= 0.0:
		errors.append("EnemyBehaviorProfile detect_radius must be positive.")
	if attack_range <= 0.0:
		errors.append("EnemyBehaviorProfile attack_range must be positive.")
	if attack_windup_duration <= 0.0:
		errors.append("EnemyBehaviorProfile attack_windup_duration must be positive.")
	if attack_cooldown <= 0.0:
		errors.append("EnemyBehaviorProfile attack_cooldown must be positive.")
	if forget_distance <= 0.0:
		errors.append("EnemyBehaviorProfile forget_distance must be positive.")
	if search_duration <= 0.0:
		errors.append("EnemyBehaviorProfile search_duration must be positive.")
	return errors
