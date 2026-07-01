class_name PlayerStats3D
extends RefCounted

var profile: PlayerStatsProfile


func _init(source_profile: PlayerStatsProfile) -> void:
	profile = source_profile


func max_health() -> float:
	return profile.base_max_health + _bonus("max_health")


func walk_speed() -> float:
	return profile.base_walk_speed + _bonus("walk_speed")


func sprint_speed() -> float:
	return profile.base_sprint_speed + _bonus("sprint_speed")


func max_stamina() -> float:
	return profile.base_max_stamina + _bonus("max_stamina")


func roll_distance() -> float:
	return maxf(profile.base_roll_distance + _bonus("roll_distance"), 0.0)


func roll_speed() -> float:
	return roll_distance() / maxf(roll_duration(), 0.01)


func backpack_slots() -> int:
	return maxi(profile.base_backpack_slots + _int_bonus("backpack_slots"), 0)


func carry_weight_limit() -> float:
	return maxf(profile.base_carry_weight_limit + _bonus("carry_weight"), 0.0)


func safe_pocket_slots() -> int:
	return maxi(profile.base_safe_pocket_slots + _int_bonus("safe_pocket_slots"), 0)


func defense() -> float:
	return maxf(profile.base_defense + _bonus("defense"), 0.0)


func weight_speed_multiplier(current_carry_weight: float) -> float:
	var limit := carry_weight_limit()
	if limit <= 0.0:
		return 0.0

	var weight_ratio := current_carry_weight / limit
	if weight_ratio <= 1.0:
		return 1.0
	var immobilized_ratio := profile.immobilized_weight_ratio
	if weight_ratio >= immobilized_ratio:
		return 0.0

	var overweight_progress := (weight_ratio - 1.0) / maxf(immobilized_ratio - 1.0, 0.01)
	return lerpf(1.0, 0.25, overweight_progress)


func _bonus(stat_name: String) -> float:
	match stat_name:
		"max_health":
			return profile.skill_max_health_bonus + profile.equipment_max_health_bonus + profile.other_max_health_bonus
		"walk_speed":
			return profile.skill_walk_speed_bonus + profile.equipment_walk_speed_bonus + profile.other_walk_speed_bonus
		"sprint_speed":
			return profile.skill_sprint_speed_bonus + profile.equipment_sprint_speed_bonus + profile.other_sprint_speed_bonus
		"max_stamina":
			return profile.skill_max_stamina_bonus + profile.equipment_max_stamina_bonus + profile.other_max_stamina_bonus
		"roll_distance":
			return profile.skill_roll_distance_bonus + profile.equipment_roll_distance_bonus + profile.other_roll_distance_bonus
		"carry_weight":
			return profile.skill_carry_weight_bonus + profile.equipment_carry_weight_bonus + profile.other_carry_weight_bonus
		"defense":
			return profile.skill_defense_bonus + profile.equipment_defense_bonus + profile.other_defense_bonus
		_:
			return 0.0


func _int_bonus(stat_name: String) -> int:
	match stat_name:
		"backpack_slots":
			return profile.skill_backpack_slots_bonus + profile.equipment_backpack_slots_bonus + profile.other_backpack_slots_bonus
		"safe_pocket_slots":
			return profile.skill_safe_pocket_slots_bonus + profile.equipment_safe_pocket_slots_bonus + profile.other_safe_pocket_slots_bonus
		_:
			return 0


func roll_duration() -> float:
	return profile.roll_duration


func exhausted_speed() -> float:
	return profile.exhausted_speed


func sprint_stamina_cost() -> float:
	return profile.sprint_stamina_cost


func roll_stamina_cost() -> float:
	return profile.roll_stamina_cost


func stamina_recovery_rate() -> float:
	return profile.stamina_recovery_rate


func exhausted_recovery_threshold() -> float:
	return profile.exhausted_recovery_threshold
