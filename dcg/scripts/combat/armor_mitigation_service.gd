class_name ArmorMitigationService
extends RefCounted


static func damage_after_armor(event: DamageEvent, flat_defense: float = 0.0, armor_protection_level: float = 0.0) -> float:
	if event == null or event.amount <= 0.0:
		return 0.0
	var amount := maxf(event.amount, 0.0)
	var defense := maxf(flat_defense, 0.0)
	var protection := maxf(armor_protection_level, 0.0)
	var effective_defense := maxf(defense, protection)
	if not _uses_ballistic_penetration(event):
		return maxf(amount - effective_defense, 0.0)
	var penetration := maxf(event.armor_penetration_level, 0.0)
	var remaining_defense := maxf(effective_defense - penetration, 0.0)
	return maxf(amount - remaining_defense, 0.0)


static func penetration_damage_multiplier(armor_protection_level: float, armor_penetration_level: float) -> float:
	var protection := maxf(armor_protection_level, 0.0)
	var penetration := maxf(armor_penetration_level, 0.0)
	var remaining_defense := maxf(protection - penetration, 0.0)
	if remaining_defense <= 0.0:
		return 1.0
	return 0.0


static func _uses_ballistic_penetration(event: DamageEvent) -> bool:
	if event == null:
		return false
	if event.ammo_def != null:
		return true
	return event.tags.has(&"gun") or event.tags.has(&"bullet") or event.tags.has(&"projectile")
