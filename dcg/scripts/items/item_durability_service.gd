class_name ItemDurabilityService
extends RefCounted

const DEFAULT_PENALTY_RATIO := 0.5
const DEFAULT_WEAPON_WEAR_RATE := 1.0
const LOW_DURABILITY_SPREAD_DEGREES := 5.0
const BROKEN_DURABILITY_SPREAD_DEGREES := 12.0


static func normalize_stack(stack: Dictionary, item_def: ItemDef = null) -> Dictionary:
	var result := stack.duplicate(true)
	var max_durability := _int_value(result.get("max_durability", 0))
	if max_durability <= 0 and item_def != null:
		max_durability = item_def.get_max_durability()
	if max_durability <= 0:
		result["has_durability"] = false
		result["repairable"] = false
		result["current_durability"] = 0
		result["max_durability"] = 0
		result["original_max_durability"] = 0
		result["repair_max_durability_loss"] = 0
		result["durability_penalty_ratio"] = DEFAULT_PENALTY_RATIO
		result["durability_penalty_threshold"] = 0
		result["durability_ratio"] = 0.0
		result["durability_is_low"] = false
		result["durability_is_broken"] = false
		result["durability_wear_progress"] = 0.0
		return result

	var original_max := _int_value(result.get("original_max_durability", max_durability))
	if item_def != null:
		original_max = maxi(original_max, item_def.get_max_durability())
	original_max = maxi(original_max, max_durability)
	var current := clampi(_int_value(result.get("current_durability", max_durability)), 0, max_durability)
	var repair_loss := _int_value(result.get("repair_max_durability_loss", 0))
	if repair_loss <= 0 and item_def != null:
		repair_loss = item_def.get_repair_max_durability_loss()
	var penalty_ratio := DEFAULT_PENALTY_RATIO
	if result.has("durability_penalty_ratio"):
		penalty_ratio = float(result.get("durability_penalty_ratio", DEFAULT_PENALTY_RATIO))
	elif item_def != null:
		penalty_ratio = item_def.get_durability_penalty_ratio()
	penalty_ratio = clampf(penalty_ratio, 0.1, 1.0)
	var threshold := floori(float(max_durability) * penalty_ratio)
	result["has_durability"] = true
	result["repairable"] = true
	result["current_durability"] = current
	result["max_durability"] = max_durability
	result["original_max_durability"] = original_max
	result["repair_max_durability_loss"] = repair_loss
	result["durability_penalty_ratio"] = penalty_ratio
	result["durability_penalty_threshold"] = threshold
	result["durability_ratio"] = float(current) / float(max_durability)
	result["durability_is_low"] = current > 0 and current <= threshold
	result["durability_is_broken"] = current <= 0
	result["durability_wear_progress"] = maxf(float(result.get("durability_wear_progress", 0.0)), 0.0)
	return result


static func has_durability(stack: Dictionary, item_def: ItemDef = null) -> bool:
	return bool(normalize_stack(stack, item_def).get("has_durability", false))


static func is_repair_needed(stack: Dictionary, item_def: ItemDef = null) -> bool:
	var normalized := normalize_stack(stack, item_def)
	return bool(normalized.get("has_durability", false)) and int(normalized.get("current_durability", 0)) < int(normalized.get("max_durability", 0))


static func apply_use_wear(stack: Dictionary, item_def: ItemDef = null, wear_amount: int = 1) -> Dictionary:
	var normalized := normalize_stack(stack, item_def)
	if not bool(normalized.get("has_durability", false)):
		return normalized
	var amount := maxi(wear_amount, 0)
	if amount <= 0:
		return normalized
	normalized["current_durability"] = maxi(int(normalized.get("current_durability", 0)) - amount, 0)
	return normalize_stack(normalized, item_def)


static func apply_ammo_use_wear(stack: Dictionary, item_def: ItemDef = null, ammo_def: ItemDef = null, base_wear_amount: float = 1.0) -> Dictionary:
	var normalized := normalize_stack(stack, item_def)
	if not bool(normalized.get("has_durability", false)):
		return normalized
	var base_amount := maxf(base_wear_amount, 0.0)
	if base_amount <= 0:
		return normalized
	var wear_rate := ammo_weapon_wear_rate(ammo_def)
	var accumulated := maxf(float(normalized.get("durability_wear_progress", 0.0)), 0.0)
	accumulated += base_amount * wear_rate
	var whole_wear := floori(accumulated)
	normalized["durability_wear_progress"] = accumulated - float(whole_wear)
	if whole_wear > 0:
		normalized["current_durability"] = maxi(int(normalized.get("current_durability", 0)) - whole_wear, 0)
		if int(normalized.get("current_durability", 0)) <= 0:
			normalized["durability_wear_progress"] = 0.0
	return normalize_stack(normalized, item_def)


static func ammo_weapon_wear_rate(ammo_def: ItemDef = null) -> float:
	if ammo_def == null or ammo_def.item_type != "ammo":
		return DEFAULT_WEAPON_WEAR_RATE
	return ammo_def.get_ammo_weapon_wear_rate()


static func combat_penalty_state(stack: Dictionary, item_def: ItemDef = null) -> Dictionary:
	var normalized := normalize_stack(stack, item_def)
	var result := {
		"active": false,
		"source": "",
		"spread_degrees": 0.0,
		"damage_multiplier": 1.0,
		"severity": 0.0,
		"current_durability": int(normalized.get("current_durability", 0)),
		"max_durability": int(normalized.get("max_durability", 0)),
		"threshold": int(normalized.get("durability_penalty_threshold", 0)),
	}
	if not bool(normalized.get("has_durability", false)):
		return result
	if bool(normalized.get("durability_is_broken", false)):
		result["active"] = true
		result["source"] = "depleted_durability"
		result["spread_degrees"] = BROKEN_DURABILITY_SPREAD_DEGREES
		result["severity"] = 1.0
		return result
	if not bool(normalized.get("durability_is_low", false)):
		return result
	var threshold := maxi(int(normalized.get("durability_penalty_threshold", 0)), 1)
	var current := clampi(int(normalized.get("current_durability", 0)), 0, threshold)
	var severity := clampf(1.0 - (float(current) / float(threshold)), 0.0, 1.0)
	result["active"] = true
	result["source"] = "low_durability"
	result["severity"] = severity
	result["spread_degrees"] = lerpf(LOW_DURABILITY_SPREAD_DEGREES, BROKEN_DURABILITY_SPREAD_DEGREES, severity)
	return result


static func _int_value(value: Variant) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return maxi(int(value), 0)
	return 0
