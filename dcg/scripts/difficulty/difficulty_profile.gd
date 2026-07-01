class_name DifficultyProfile
extends Resource

@export var id: StringName = &"normal"
@export var name_key: StringName = &"ui.difficulty.normal"
@export var description_key: StringName = &"ui.difficulty.normal_desc"
@export var player_health_multiplier: float = 1.0


func apply_to_player_stats(profile: PlayerStatsProfile) -> void:
	if profile == null:
		return
	profile.base_max_health *= maxf(player_health_multiplier, 0.01)

