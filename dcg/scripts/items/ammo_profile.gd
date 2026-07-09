class_name AmmoProfile
extends Resource

@export var ammo_tag: StringName = &""
@export_range(0.0, 10.0, 1.0) var penetration_level: float = 0.0
@export_range(0.0, 5.0, 0.05) var weapon_wear_rate: float = 1.0
@export_range(0.0, 5.0, 0.05) var damage_multiplier: float = 1.0
@export_range(0.0, 5.0, 0.05) var spread_multiplier: float = 1.0
@export_range(0.0, 5.0, 0.05) var recoil_multiplier: float = 1.0


func has_authored_values() -> bool:
	return ammo_tag != &"" or penetration_level > 0.0 or absf(damage_multiplier - 1.0) > 0.001 or absf(spread_multiplier - 1.0) > 0.001 or absf(recoil_multiplier - 1.0) > 0.001
