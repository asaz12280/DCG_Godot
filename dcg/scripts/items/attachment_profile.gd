class_name AttachmentProfile
extends Resource

@export_range(0, 999, 1) var magazine_capacity_bonus: int = 0
@export_range(0.0, 5.0, 0.05) var vertical_recoil_multiplier: float = 1.0
@export_range(0.0, 5.0, 0.05) var horizontal_recoil_multiplier: float = 1.0
@export_range(0.0, 5.0, 0.05) var recoil_recovery_multiplier: float = 1.0
@export_range(0.0, 5.0, 0.05) var spread_multiplier: float = 1.0
@export var slot_tags: Array[StringName] = []
@export var compatibility_tags: Array[StringName] = []


func has_authored_values() -> bool:
	return magazine_capacity_bonus > 0 or absf(vertical_recoil_multiplier - 1.0) > 0.001 or absf(horizontal_recoil_multiplier - 1.0) > 0.001 or absf(recoil_recovery_multiplier - 1.0) > 0.001 or absf(spread_multiplier - 1.0) > 0.001
