class_name WeaponProfile
extends Resource

@export var shot_audio_profile: Resource
@export var vfx_profile: WeaponVfxProfile
@export_enum("firearm", "melee") var weapon_kind: String = "firearm"
@export var damage: int = 0
@export_range(0.0, 30.0, 0.1) var fire_rate_per_second: float = 0.0
@export_range(1, 32, 1) var projectiles_per_shot: int = 1
@export_range(0.0, 90.0, 0.1) var projectile_spread_degrees: float = 0.0
@export_range(0.0, 10.0, 0.5) var armor_penetration_level: float = 0.0
@export_range(0.0, 100.0, 1.0) var critical_chance: float = 0.0
@export_range(0.0, 100.0, 1.0) var projectile_pierce_chance: float = 0.0
@export_range(0, 999, 1) var magazine_capacity: int = 0
@export_range(0.0, 10.0, 0.05) var reload_duration_seconds: float = 0.0
@export_range(0.0, 20000.0, 10.0) var projectile_range: float = 0.0
@export_range(0.0, 10.0, 0.1) var durability_wear_per_shot: float = 1.0
@export_range(0, 9999, 1) var max_durability: int = 0
@export_range(0, 999, 1) var repair_max_durability_loss: int = 0
@export_range(0.1, 1.0, 0.05) var durability_penalty_ratio: float = 0.5
@export_range(0.0, 60.0, 0.1) var vertical_recoil: float = 0.0
@export_range(0.0, 60.0, 0.1) var horizontal_recoil: float = 0.0
@export var compatible_ammo_tags: Array[StringName] = []
@export var attachment_slots: Array[StringName] = []


func has_authored_values() -> bool:
	return weapon_kind == "melee" or damage > 0 or projectiles_per_shot > 1 or projectile_spread_degrees > 0.0 or magazine_capacity > 0 or max_durability > 0 or not compatible_ammo_tags.is_empty() or not attachment_slots.is_empty()
