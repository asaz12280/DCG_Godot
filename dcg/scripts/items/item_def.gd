class_name ItemDef
extends Resource

@export var id: StringName
@export var catalog_number: int = 0
@export var display_name: String = ""
@export var name_key: StringName = &""
@export var description_key: StringName = &""
@export_enum("weapon", "ammo", "armor", "backpack", "attachment", "medical", "food", "consumable", "key", "crafting", "electronics", "explosive", "valuable", "intel", "quest", "totem", "recipe", "loot", "currency") var item_type: String = "loot"
@export var weight: float = 0.0
@export var value: int = 0
@export var max_stack: int = 1
@export_multiline var authoring_notes_zh_tw: String = ""
# // Gun damage used by the early codex and combat planning slice. Non-gun items keep this at 0. //
@export var damage: int = 0
@export_range(0.0, 30.0, 0.1) var fire_rate_per_second: float = 0.0
@export_range(0.0, 10.0, 0.5) var weapon_armor_penetration_level: float = 0.0
@export_range(0.0, 100.0, 1.0) var critical_chance: float = 0.0
@export_range(0.0, 100.0, 1.0) var projectile_pierce_chance: float = 0.0
@export_range(0.0, 100.0, 0.5) var defense_bonus: float = 0.0
@export_range(0.0, 9999.0, 0.5) var heal_amount: float = 0.0
@export_range(0.0, 30.0, 0.1) var use_duration_seconds: float = 0.0
@export_range(0.0, 9999.0, 0.5) var max_health_bonus: float = 0.0
@export_range(0.0, 9999.0, 0.5) var stamina_restore: float = 0.0
@export_range(0, 999, 1) var magazine_capacity: int = 0
@export_range(0.0, 10.0, 0.05) var reload_duration_seconds: float = 0.0
@export_range(0.0, 20000.0, 10.0) var projectile_range: float = 0.0
@export_range(0.0, 10.0, 0.1) var weapon_durability_wear_per_shot: float = 1.0
@export_range(0, 999, 1) var attachment_magazine_capacity_bonus: int = 0
@export_range(0.0, 5.0, 0.05) var attachment_vertical_recoil_multiplier: float = 1.0
@export_range(0.0, 5.0, 0.05) var attachment_horizontal_recoil_multiplier: float = 1.0
@export_range(0.0, 5.0, 0.05) var attachment_recoil_recovery_multiplier: float = 1.0
@export_range(0.0, 5.0, 0.05) var attachment_spread_multiplier: float = 1.0
@export_range(0.0, 60.0, 0.1) var weapon_vertical_recoil: float = 0.0
@export_range(0.0, 60.0, 0.1) var weapon_horizontal_recoil: float = 0.0
@export_range(0, 9999, 1) var max_durability: int = 0
@export_range(0, 999, 1) var repair_max_durability_loss: int = 0
@export_range(0.1, 1.0, 0.05) var durability_penalty_ratio: float = 0.5
@export var compatible_ammo_tags: Array[StringName] = []
@export var weapon_attachment_slots: Array[StringName] = []
@export var ammo_tag: StringName = &""
@export_range(0.0, 10.0, 1.0) var ammo_penetration_level: float = 0.0
@export_range(0.0, 5.0, 0.05) var weapon_wear_rate: float = 1.0
@export_range(0.0, 5.0, 0.05) var ammo_damage_multiplier: float = 1.0
@export_range(0.0, 5.0, 0.05) var ammo_spread_multiplier: float = 1.0
@export_range(0.0, 5.0, 0.05) var ammo_recoil_multiplier: float = 1.0
@export_range(0.0, 10.0, 1.0) var armor_protection_level: float = 0.0
@export var weapon_profile: WeaponProfile
@export var ammo_profile: AmmoProfile
@export var armor_profile: ArmorProfile
@export var attachment_profile: AttachmentProfile
@export var tags: Array[StringName] = []
@export var is_quest_item: bool = false


func get_max_stack() -> int:
	if item_type == "key":
		return 1
	return maxi(max_stack, 1)


func get_weapon_damage() -> int:
	return maxi(weapon_profile.damage if weapon_profile != null else damage, 0)


func get_weapon_fire_rate_per_second() -> float:
	return maxf(weapon_profile.fire_rate_per_second if weapon_profile != null else fire_rate_per_second, 0.0)


func get_weapon_armor_penetration_level() -> float:
	return maxf(weapon_profile.armor_penetration_level if weapon_profile != null else weapon_armor_penetration_level, 0.0)


func get_weapon_critical_chance() -> float:
	return clampf(weapon_profile.critical_chance if weapon_profile != null else critical_chance, 0.0, 100.0)


func get_weapon_projectile_pierce_chance() -> float:
	return clampf(weapon_profile.projectile_pierce_chance if weapon_profile != null else projectile_pierce_chance, 0.0, 100.0)


func get_weapon_magazine_capacity() -> int:
	return maxi(weapon_profile.magazine_capacity if weapon_profile != null else magazine_capacity, 0)


func get_weapon_reload_duration_seconds() -> float:
	return maxf(weapon_profile.reload_duration_seconds if weapon_profile != null else reload_duration_seconds, 0.0)


func get_weapon_projectile_range() -> float:
	return maxf(weapon_profile.projectile_range if weapon_profile != null else projectile_range, 0.0)


func get_weapon_durability_wear_per_shot() -> float:
	return maxf(weapon_profile.durability_wear_per_shot if weapon_profile != null else weapon_durability_wear_per_shot, 0.0)


func get_weapon_vertical_recoil() -> float:
	return maxf(weapon_profile.vertical_recoil if weapon_profile != null else weapon_vertical_recoil, 0.0)


func get_weapon_horizontal_recoil() -> float:
	return maxf(weapon_profile.horizontal_recoil if weapon_profile != null else weapon_horizontal_recoil, 0.0)


func get_weapon_compatible_ammo_tags() -> Array[StringName]:
	return weapon_profile.compatible_ammo_tags.duplicate() if weapon_profile != null and not weapon_profile.compatible_ammo_tags.is_empty() else compatible_ammo_tags.duplicate()


func get_weapon_attachment_slots() -> Array[StringName]:
	return weapon_profile.attachment_slots.duplicate() if weapon_profile != null and not weapon_profile.attachment_slots.is_empty() else weapon_attachment_slots.duplicate()


func get_ammo_tag() -> StringName:
	return ammo_profile.ammo_tag if ammo_profile != null and ammo_profile.ammo_tag != &"" else ammo_tag


func get_ammo_penetration_level() -> float:
	return maxf(ammo_profile.penetration_level if ammo_profile != null else ammo_penetration_level, 0.0)


func get_ammo_weapon_wear_rate() -> float:
	return maxf(ammo_profile.weapon_wear_rate if ammo_profile != null else weapon_wear_rate, 0.0)


func get_ammo_damage_multiplier() -> float:
	return maxf(ammo_profile.damage_multiplier if ammo_profile != null else ammo_damage_multiplier, 0.0)


func get_ammo_spread_multiplier() -> float:
	return maxf(ammo_profile.spread_multiplier if ammo_profile != null else ammo_spread_multiplier, 0.0)


func get_ammo_recoil_multiplier() -> float:
	return maxf(ammo_profile.recoil_multiplier if ammo_profile != null else ammo_recoil_multiplier, 0.0)


func get_armor_defense_bonus() -> float:
	return maxf(armor_profile.defense_bonus if armor_profile != null else defense_bonus, 0.0)


func get_armor_protection_level() -> float:
	return maxf(armor_profile.protection_level if armor_profile != null else armor_protection_level, 0.0)


func get_max_durability() -> int:
	if weapon_profile != null and weapon_profile.max_durability > 0:
		return maxi(weapon_profile.max_durability, 0)
	return maxi(armor_profile.max_durability if armor_profile != null and armor_profile.max_durability > 0 else max_durability, 0)


func get_repair_max_durability_loss() -> int:
	if weapon_profile != null and weapon_profile.repair_max_durability_loss > 0:
		return maxi(weapon_profile.repair_max_durability_loss, 0)
	return maxi(armor_profile.repair_max_durability_loss if armor_profile != null and armor_profile.repair_max_durability_loss > 0 else repair_max_durability_loss, 0)


func get_durability_penalty_ratio() -> float:
	if weapon_profile != null:
		return clampf(weapon_profile.durability_penalty_ratio, 0.1, 1.0)
	return clampf(armor_profile.durability_penalty_ratio if armor_profile != null else durability_penalty_ratio, 0.1, 1.0)


func get_attachment_magazine_capacity_bonus() -> int:
	return maxi(attachment_profile.magazine_capacity_bonus if attachment_profile != null else attachment_magazine_capacity_bonus, 0)


func get_attachment_vertical_recoil_multiplier() -> float:
	return maxf(attachment_profile.vertical_recoil_multiplier if attachment_profile != null else attachment_vertical_recoil_multiplier, 0.0)


func get_attachment_horizontal_recoil_multiplier() -> float:
	return maxf(attachment_profile.horizontal_recoil_multiplier if attachment_profile != null else attachment_horizontal_recoil_multiplier, 0.0)


func get_attachment_recoil_recovery_multiplier() -> float:
	return maxf(attachment_profile.recoil_recovery_multiplier if attachment_profile != null else attachment_recoil_recovery_multiplier, 0.0)


func get_attachment_spread_multiplier() -> float:
	return maxf(attachment_profile.spread_multiplier if attachment_profile != null else attachment_spread_multiplier, 0.0)


func get_attachment_slot_tags() -> Array[StringName]:
	return attachment_profile.slot_tags.duplicate() if attachment_profile != null and not attachment_profile.slot_tags.is_empty() else tags.duplicate()


func get_attachment_compatibility_tags() -> Array[StringName]:
	return attachment_profile.compatibility_tags.duplicate() if attachment_profile != null and not attachment_profile.compatibility_tags.is_empty() else tags.duplicate()


func to_stack(quantity: int = 1) -> Dictionary:
	return {
		"id": id,
		"catalog_number": catalog_number,
		"name": display_name,
		"name_key": name_key,
		"description_key": description_key,
		"type": item_type,
		"weight": weight,
		"value": value,
		"quantity": maxi(quantity, 1),
		"max_stack": get_max_stack(),
		"resource_path": resource_path,
		"damage": get_weapon_damage(),
		"fire_rate_per_second": get_weapon_fire_rate_per_second(),
		"weapon_armor_penetration_level": get_weapon_armor_penetration_level(),
		"critical_chance": get_weapon_critical_chance(),
		"projectile_pierce_chance": get_weapon_projectile_pierce_chance(),
		"defense_bonus": get_armor_defense_bonus(),
		"heal_amount": maxf(heal_amount, 0.0),
		"stamina_restore": maxf(stamina_restore, 0.0),
		"use_duration_seconds": maxf(use_duration_seconds, 0.0),
		"max_health_bonus": maxf(max_health_bonus, 0.0),
		"magazine_capacity": get_weapon_magazine_capacity(),
		"reload_duration_seconds": get_weapon_reload_duration_seconds(),
		"projectile_range": get_weapon_projectile_range(),
		"weapon_durability_wear_per_shot": get_weapon_durability_wear_per_shot(),
		"attachment_magazine_capacity_bonus": get_attachment_magazine_capacity_bonus(),
		"attachment_vertical_recoil_multiplier": get_attachment_vertical_recoil_multiplier(),
		"attachment_horizontal_recoil_multiplier": get_attachment_horizontal_recoil_multiplier(),
		"attachment_recoil_recovery_multiplier": get_attachment_recoil_recovery_multiplier(),
		"attachment_spread_multiplier": get_attachment_spread_multiplier(),
		"weapon_vertical_recoil": get_weapon_vertical_recoil(),
		"weapon_horizontal_recoil": get_weapon_horizontal_recoil(),
		"has_durability": get_max_durability() > 0,
		"repairable": get_max_durability() > 0,
		"current_durability": get_max_durability(),
		"max_durability": get_max_durability(),
		"original_max_durability": get_max_durability(),
		"repair_max_durability_loss": get_repair_max_durability_loss(),
		"durability_penalty_ratio": get_durability_penalty_ratio(),
		"compatible_ammo_tags": get_weapon_compatible_ammo_tags(),
		"weapon_attachment_slots": get_weapon_attachment_slots(),
		"ammo_tag": get_ammo_tag(),
		"ammo_penetration_level": get_ammo_penetration_level(),
		"weapon_wear_rate": get_ammo_weapon_wear_rate(),
		"ammo_damage_multiplier": get_ammo_damage_multiplier(),
		"ammo_spread_multiplier": get_ammo_spread_multiplier(),
		"ammo_recoil_multiplier": get_ammo_recoil_multiplier(),
		"armor_protection_level": get_armor_protection_level(),
		"tags": tags.duplicate(),
		"is_quest_item": is_quest_item,
	}
