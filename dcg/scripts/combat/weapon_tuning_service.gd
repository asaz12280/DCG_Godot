class_name WeaponTuningService
extends RefCounted

const ItemDurabilityServiceScript := preload("res://scripts/items/item_durability_service.gd")
const WeaponAttachmentServiceScript := preload("res://scripts/combat/weapon_attachment_service.gd")
const PROJECTILE_RANGE_UNITS_PER_METER := 100.0
const CRITICAL_DAMAGE_MULTIPLIER := 2.0


static func chance_percent(value: float) -> float:
	return clampf(value, 0.0, 100.0)


static func chance_ratio(value: float) -> float:
	return chance_percent(value) / 100.0


static func chance_succeeds(value: float) -> bool:
	var percent := chance_percent(value)
	if percent <= 0.0:
		return false
	if percent >= 100.0:
		return true
	return randf() < chance_ratio(percent)


static func authored_range_to_meters(value: float) -> float:
	return maxf(value, 0.0) / PROJECTILE_RANGE_UNITS_PER_METER


static func resolve_snapshot(weapon_def: ItemDef = null, ammo_def: ItemDef = null, attachments: Variant = {}, durability: Variant = {}) -> Dictionary:
	var attachment_state := _resolve_attachment_state(attachments, weapon_def)
	var durability_state := _resolve_durability_state(durability, weapon_def)
	var combat_penalty := ItemDurabilityServiceScript.combat_penalty_state(durability_state, weapon_def)
	if weapon_def == null or weapon_def.item_type != "weapon":
		return _empty_snapshot(weapon_def, ammo_def, attachment_state, durability_state, combat_penalty)

	var base_damage := float(weapon_def.get_weapon_damage())
	var ammo_damage_multiplier := _ammo_damage_multiplier(ammo_def)
	var damage := base_damage * ammo_damage_multiplier
	damage *= maxf(float(combat_penalty.get("damage_multiplier", 1.0)), 0.0)

	var base_capacity := weapon_def.get_weapon_magazine_capacity()
	var capacity_bonus := maxi(int(attachment_state.get("magazine_capacity_bonus", 0)), 0)
	var fire_rate := weapon_def.get_weapon_fire_rate_per_second()
	var projectile_range := weapon_def.get_weapon_projectile_range()
	var weapon_armor_penetration := weapon_def.get_weapon_armor_penetration_level()
	var ammo_penetration := _ammo_penetration_level(ammo_def)
	var ammo_recoil := _ammo_recoil_multiplier(ammo_def)
	var ammo_spread := _ammo_spread_multiplier(ammo_def)
	var attachment_vertical := maxf(float(attachment_state.get("vertical_recoil_multiplier", 1.0)), 0.0)
	var attachment_horizontal := maxf(float(attachment_state.get("horizontal_recoil_multiplier", 1.0)), 0.0)
	var attachment_spread := maxf(float(attachment_state.get("spread_multiplier", 1.0)), 0.0)
	var weapon_vertical := weapon_def.get_weapon_vertical_recoil() * attachment_vertical
	var weapon_horizontal := weapon_def.get_weapon_horizontal_recoil() * attachment_horizontal

	return {
		"valid": true,
		"weapon_id": weapon_def.id,
		"ammo_id": ammo_def.id if ammo_def != null else &"",
		"base_damage": base_damage,
		"damage": damage,
		"ammo_damage_multiplier": ammo_damage_multiplier,
		"fire_rate_per_second": fire_rate,
		"fire_cooldown_seconds": 1.0 / maxf(fire_rate, 0.01) if fire_rate > 0.0 else 0.0,
		"base_magazine_capacity": base_capacity,
		"magazine_capacity_bonus": capacity_bonus,
		"magazine_capacity": base_capacity + capacity_bonus,
		"reload_duration_seconds": weapon_def.get_weapon_reload_duration_seconds(),
		"projectile_range": projectile_range,
		"projectile_range_meters": authored_range_to_meters(projectile_range),
		"armor_penetration_level": maxf(weapon_armor_penetration, ammo_penetration),
		"weapon_armor_penetration_level": weapon_armor_penetration,
		"ammo_penetration_level": ammo_penetration,
		"critical_chance": chance_percent(weapon_def.get_weapon_critical_chance()),
		"projectile_pierce_chance": chance_percent(weapon_def.get_weapon_projectile_pierce_chance()),
		"weapon_vertical_recoil": weapon_vertical,
		"weapon_horizontal_recoil": weapon_horizontal,
		"vertical_recoil": weapon_vertical * ammo_recoil,
		"horizontal_recoil": weapon_horizontal * ammo_recoil,
		"ammo_recoil_multiplier": ammo_recoil,
		"attachment_vertical_recoil_multiplier": attachment_vertical,
		"attachment_horizontal_recoil_multiplier": attachment_horizontal,
		"attachment_recoil_recovery_multiplier": maxf(float(attachment_state.get("recoil_recovery_multiplier", 1.0)), 0.0),
		"ammo_spread_multiplier": ammo_spread,
		"attachment_spread_multiplier": attachment_spread,
		"spread_multiplier": ammo_spread * attachment_spread,
		"weapon_wear_rate": _ammo_weapon_wear_rate(ammo_def),
		"durability_wear_per_shot": weapon_def.get_weapon_durability_wear_per_shot(),
		"durability": durability_state.duplicate(true),
		"combat_penalty": combat_penalty.duplicate(true),
		"durability_ratio": float(durability_state.get("durability_ratio", 0.0)),
		"durability_is_low": bool(durability_state.get("durability_is_low", false)),
		"durability_is_broken": bool(durability_state.get("durability_is_broken", false)),
		"attachment_ids": (attachment_state.get("attachment_ids", []) as Array).duplicate(),
		"attachment_slots": (attachment_state.get("attachment_slots", []) as Array).duplicate(),
		"compatible_ammo_tags": weapon_def.get_weapon_compatible_ammo_tags(),
		"weapon_attachment_slots": weapon_def.get_weapon_attachment_slots(),
	}


static func _empty_snapshot(weapon_def: ItemDef, ammo_def: ItemDef, attachment_state: Dictionary, durability_state: Dictionary, combat_penalty: Dictionary) -> Dictionary:
	return {
		"valid": false,
		"weapon_id": weapon_def.id if weapon_def != null else &"",
		"ammo_id": ammo_def.id if ammo_def != null else &"",
		"base_damage": 0.0,
		"damage": 0.0,
		"ammo_damage_multiplier": _ammo_damage_multiplier(ammo_def),
		"fire_rate_per_second": 0.0,
		"fire_cooldown_seconds": 0.0,
		"base_magazine_capacity": 0,
		"magazine_capacity_bonus": maxi(int(attachment_state.get("magazine_capacity_bonus", 0)), 0),
		"magazine_capacity": 0,
		"reload_duration_seconds": 0.0,
		"projectile_range": 0.0,
		"projectile_range_meters": 0.0,
		"armor_penetration_level": _ammo_penetration_level(ammo_def),
		"weapon_armor_penetration_level": 0.0,
		"ammo_penetration_level": _ammo_penetration_level(ammo_def),
		"critical_chance": 0.0,
		"projectile_pierce_chance": 0.0,
		"weapon_vertical_recoil": 0.0,
		"weapon_horizontal_recoil": 0.0,
		"vertical_recoil": 0.0,
		"horizontal_recoil": 0.0,
		"ammo_recoil_multiplier": _ammo_recoil_multiplier(ammo_def),
		"attachment_vertical_recoil_multiplier": maxf(float(attachment_state.get("vertical_recoil_multiplier", 1.0)), 0.0),
		"attachment_horizontal_recoil_multiplier": maxf(float(attachment_state.get("horizontal_recoil_multiplier", 1.0)), 0.0),
		"attachment_recoil_recovery_multiplier": maxf(float(attachment_state.get("recoil_recovery_multiplier", 1.0)), 0.0),
		"ammo_spread_multiplier": _ammo_spread_multiplier(ammo_def),
		"attachment_spread_multiplier": maxf(float(attachment_state.get("spread_multiplier", 1.0)), 0.0),
		"spread_multiplier": _ammo_spread_multiplier(ammo_def) * maxf(float(attachment_state.get("spread_multiplier", 1.0)), 0.0),
		"weapon_wear_rate": _ammo_weapon_wear_rate(ammo_def),
		"durability_wear_per_shot": 0.0,
		"durability": durability_state.duplicate(true),
		"combat_penalty": combat_penalty.duplicate(true),
		"durability_ratio": float(durability_state.get("durability_ratio", 0.0)),
		"durability_is_low": bool(durability_state.get("durability_is_low", false)),
		"durability_is_broken": bool(durability_state.get("durability_is_broken", false)),
		"attachment_ids": (attachment_state.get("attachment_ids", []) as Array).duplicate(),
		"attachment_slots": (attachment_state.get("attachment_slots", []) as Array).duplicate(),
		"compatible_ammo_tags": [],
		"weapon_attachment_slots": [],
	}


static func _resolve_attachment_state(attachments: Variant, weapon_def: ItemDef) -> Dictionary:
	match typeof(attachments):
		TYPE_DICTIONARY:
			return _merge_attachment_state(attachments as Dictionary)
		TYPE_ARRAY:
			return _attachment_state_from_array(attachments as Array, weapon_def)
		_:
			if attachments is RefCounted:
				var object := attachments as RefCounted
				if object.has_method("get_slot_ids") and object.has_method("get_slot"):
					return WeaponAttachmentServiceScript.modifiers_for_equipment(object, weapon_def)
	return _empty_attachment_state()


static func _merge_attachment_state(source: Dictionary) -> Dictionary:
	var result := _empty_attachment_state()
	result["magazine_capacity_bonus"] = maxi(int(source.get("magazine_capacity_bonus", result["magazine_capacity_bonus"])), 0)
	result["vertical_recoil_multiplier"] = maxf(float(source.get("vertical_recoil_multiplier", result["vertical_recoil_multiplier"])), 0.0)
	result["horizontal_recoil_multiplier"] = maxf(float(source.get("horizontal_recoil_multiplier", result["horizontal_recoil_multiplier"])), 0.0)
	result["recoil_recovery_multiplier"] = maxf(float(source.get("recoil_recovery_multiplier", result["recoil_recovery_multiplier"])), 0.0)
	result["spread_multiplier"] = maxf(float(source.get("spread_multiplier", result["spread_multiplier"])), 0.0)
	result["attachment_ids"] = (source.get("attachment_ids", []) as Array).duplicate()
	result["attachment_slots"] = (source.get("attachment_slots", []) as Array).duplicate()
	return result


static func _attachment_state_from_array(attachments: Array, weapon_def: ItemDef) -> Dictionary:
	var result := _empty_attachment_state()
	for value in attachments:
		var attachment := value as ItemDef
		if attachment == null:
			continue
		var slot_id := WeaponAttachmentServiceScript.mod_slot_for_attachment(attachment, weapon_def)
		if slot_id == &"":
			continue
		_apply_attachment_profile(result, attachment, str(slot_id))
	return result


static func _apply_attachment_profile(result: Dictionary, attachment: ItemDef, slot_label: String) -> void:
	result["magazine_capacity_bonus"] = int(result.get("magazine_capacity_bonus", 0)) + attachment.get_attachment_magazine_capacity_bonus()
	result["vertical_recoil_multiplier"] = maxf(float(result.get("vertical_recoil_multiplier", 1.0)), 0.0) * attachment.get_attachment_vertical_recoil_multiplier()
	result["horizontal_recoil_multiplier"] = maxf(float(result.get("horizontal_recoil_multiplier", 1.0)), 0.0) * attachment.get_attachment_horizontal_recoil_multiplier()
	result["recoil_recovery_multiplier"] = maxf(float(result.get("recoil_recovery_multiplier", 1.0)), 0.0) * attachment.get_attachment_recoil_recovery_multiplier()
	result["spread_multiplier"] = maxf(float(result.get("spread_multiplier", 1.0)), 0.0) * attachment.get_attachment_spread_multiplier()
	(result["attachment_ids"] as Array).append(str(attachment.id))
	(result["attachment_slots"] as Array).append(slot_label)


static func _empty_attachment_state() -> Dictionary:
	return {
		"magazine_capacity_bonus": 0,
		"vertical_recoil_multiplier": 1.0,
		"horizontal_recoil_multiplier": 1.0,
		"recoil_recovery_multiplier": 1.0,
		"spread_multiplier": 1.0,
		"attachment_ids": [],
		"attachment_slots": [],
	}


static func _resolve_durability_state(durability: Variant, weapon_def: ItemDef) -> Dictionary:
	if typeof(durability) == TYPE_DICTIONARY and not (durability as Dictionary).is_empty():
		return ItemDurabilityServiceScript.normalize_stack(durability as Dictionary, weapon_def)
	if weapon_def != null:
		return ItemDurabilityServiceScript.normalize_stack(weapon_def.to_stack(1), weapon_def)
	return ItemDurabilityServiceScript.normalize_stack({}, weapon_def)


static func _ammo_penetration_level(ammo_def: ItemDef = null) -> float:
	if ammo_def == null or ammo_def.item_type != "ammo":
		return 0.0
	return ammo_def.get_ammo_penetration_level()


static func _ammo_damage_multiplier(ammo_def: ItemDef = null) -> float:
	if ammo_def == null or ammo_def.item_type != "ammo":
		return 1.0
	return ammo_def.get_ammo_damage_multiplier()


static func _ammo_spread_multiplier(ammo_def: ItemDef = null) -> float:
	if ammo_def == null or ammo_def.item_type != "ammo":
		return 1.0
	return ammo_def.get_ammo_spread_multiplier()


static func _ammo_recoil_multiplier(ammo_def: ItemDef = null) -> float:
	if ammo_def == null or ammo_def.item_type != "ammo":
		return 1.0
	return ammo_def.get_ammo_recoil_multiplier()


static func _ammo_weapon_wear_rate(ammo_def: ItemDef = null) -> float:
	if ammo_def == null or ammo_def.item_type != "ammo":
		return 1.0
	return ammo_def.get_ammo_weapon_wear_rate()
