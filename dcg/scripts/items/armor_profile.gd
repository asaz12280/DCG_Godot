class_name ArmorProfile
extends Resource

@export_range(0.0, 100.0, 0.5) var defense_bonus: float = 0.0
@export_range(0.0, 10.0, 1.0) var protection_level: float = 0.0
@export_range(0, 9999, 1) var max_durability: int = 0
@export_range(0, 999, 1) var repair_max_durability_loss: int = 0
@export_range(0.1, 1.0, 0.05) var durability_penalty_ratio: float = 0.5


func has_authored_values() -> bool:
	return defense_bonus > 0.0 or protection_level > 0.0 or max_durability > 0
