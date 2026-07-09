class_name WeaponAttachmentService
extends RefCounted

const GENERIC_ATTACHMENT_TAGS := [
	&"attachment",
	&"magazine",
	&"grip",
	&"muzzle",
	&"stock",
	&"scope",
	&"sight",
	&"tactic",
	&"special",
	&"charm",
	&"glasses",
	&"headset",
]

const ATTACHMENT_SLOT_TAGS := [
	&"magazine",
	&"grip",
	&"muzzle",
	&"stock",
	&"scope",
	&"sight",
	&"tactic",
	&"special",
]


static func modifiers_for_equipment(equipment: RefCounted, weapon_def: ItemDef) -> Dictionary:
	var result := _empty_modifiers()
	if equipment == null or weapon_def == null:
		return result
	if not equipment.has_method("get_slot_ids") or not equipment.has_method("get_slot"):
		return result
	for slot_id in equipment.call("get_slot_ids"):
		var stack: Dictionary = equipment.call("get_slot", slot_id)
		if stack.is_empty():
			continue
		var attachment := _load_item_from_stack(stack)
		if not _is_compatible_attachment(attachment, weapon_def):
			continue
		_apply_attachment_modifiers(result, attachment, str(slot_id))
	return result


static func modifiers_for_weapon_stack(weapon_stack: Dictionary, weapon_def: ItemDef) -> Dictionary:
	var result := _empty_modifiers()
	if weapon_stack.is_empty() or weapon_def == null:
		return result
	for slot_id in weapon_mod_slot_ids(weapon_def):
		var mod_stack := weapon_mod_stack(weapon_stack, slot_id)
		if mod_stack.is_empty():
			continue
		var attachment := _load_item_from_stack(mod_stack)
		if not _is_compatible_attachment(attachment, weapon_def):
			continue
		_apply_attachment_modifiers(result, attachment, str(slot_id))
	return result


static func _empty_modifiers() -> Dictionary:
	return {
		"magazine_capacity_bonus": 0,
		"vertical_recoil_multiplier": 1.0,
		"horizontal_recoil_multiplier": 1.0,
		"recoil_recovery_multiplier": 1.0,
		"spread_multiplier": 1.0,
		"attachment_ids": [] as Array[String],
		"attachment_slots": [] as Array[String],
	}


static func weapon_mod_slot_ids(weapon_def: ItemDef) -> Array[StringName]:
	var result: Array[StringName] = []
	if weapon_def == null:
		return result
	for slot_id in weapon_def.get_weapon_attachment_slots():
		if ATTACHMENT_SLOT_TAGS.has(slot_id) and not result.has(slot_id):
			result.append(slot_id)
	return result


static func weapon_mod_stack(weapon_stack: Dictionary, slot_id: StringName) -> Dictionary:
	var mods: Dictionary = weapon_stack.get("weapon_mods", {}) as Dictionary
	var stack: Variant = mods.get(str(slot_id), mods.get(slot_id, {}))
	if typeof(stack) != TYPE_DICTIONARY:
		return {}
	return (stack as Dictionary).duplicate(true)


static func has_weapon_mod(weapon_stack: Dictionary, slot_id: StringName) -> bool:
	return not weapon_mod_stack(weapon_stack, slot_id).is_empty()


static func mod_slot_for_attachment(attachment: ItemDef, weapon_def: ItemDef) -> StringName:
	if attachment == null or weapon_def == null:
		return &""
	for slot_id in _attachment_slot_tags(attachment):
		if weapon_def.get_weapon_attachment_slots().has(slot_id):
			return slot_id
	return &""


static func _apply_attachment_modifiers(result: Dictionary, attachment: ItemDef, slot_label: String) -> void:
	result["magazine_capacity_bonus"] = int(result.get("magazine_capacity_bonus", 0)) + attachment.get_attachment_magazine_capacity_bonus()
	result["vertical_recoil_multiplier"] = maxf(float(result.get("vertical_recoil_multiplier", 1.0)), 0.0) * attachment.get_attachment_vertical_recoil_multiplier()
	result["horizontal_recoil_multiplier"] = maxf(float(result.get("horizontal_recoil_multiplier", 1.0)), 0.0) * attachment.get_attachment_horizontal_recoil_multiplier()
	result["recoil_recovery_multiplier"] = maxf(float(result.get("recoil_recovery_multiplier", 1.0)), 0.0) * attachment.get_attachment_recoil_recovery_multiplier()
	result["spread_multiplier"] = maxf(float(result.get("spread_multiplier", 1.0)), 0.0) * attachment.get_attachment_spread_multiplier()
	(result["attachment_ids"] as Array[String]).append(str(attachment.id))
	(result["attachment_slots"] as Array[String]).append(slot_label)


static func _is_compatible_attachment(attachment: ItemDef, weapon_def: ItemDef) -> bool:
	if attachment == null or weapon_def == null:
		return false
	if attachment.item_type != "attachment":
		return false
	if weapon_def.item_type != "weapon":
		return false
	if not _has_weapon_modifier(attachment):
		return false
	if not _weapon_supports_attachment_slot(weapon_def, attachment):
		return false
	var specific_tags := _specific_attachment_tags(attachment)
	if specific_tags.is_empty():
		return true
	for tag in specific_tags:
		if weapon_def.tags.has(tag) or weapon_def.get_weapon_compatible_ammo_tags().has(tag):
			return true
	return false


static func _weapon_supports_attachment_slot(weapon_def: ItemDef, attachment: ItemDef) -> bool:
	var attachment_slots := _attachment_slot_tags(attachment)
	if attachment_slots.is_empty():
		return false
	var weapon_slots := weapon_def.get_weapon_attachment_slots()
	if weapon_slots.is_empty():
		return false
	for slot_tag in attachment_slots:
		if weapon_slots.has(slot_tag):
			return true
	return false


static func _has_weapon_modifier(attachment: ItemDef) -> bool:
	if attachment.get_attachment_magazine_capacity_bonus() > 0:
		return true
	if absf(attachment.get_attachment_vertical_recoil_multiplier() - 1.0) > 0.001:
		return true
	if absf(attachment.get_attachment_horizontal_recoil_multiplier() - 1.0) > 0.001:
		return true
	if absf(attachment.get_attachment_recoil_recovery_multiplier() - 1.0) > 0.001:
		return true
	if absf(attachment.get_attachment_spread_multiplier() - 1.0) > 0.001:
		return true
	return false


static func _attachment_slot_tags(attachment: ItemDef) -> Array[StringName]:
	var result: Array[StringName] = []
	for tag in attachment.get_attachment_slot_tags():
		if ATTACHMENT_SLOT_TAGS.has(tag) and not result.has(tag):
			result.append(tag)
	return result


static func _specific_attachment_tags(attachment: ItemDef) -> Array[StringName]:
	var result: Array[StringName] = []
	for tag in attachment.get_attachment_compatibility_tags():
		if GENERIC_ATTACHMENT_TAGS.has(tag):
			continue
		if not result.has(tag):
			result.append(tag)
	return result


static func _load_item_from_stack(stack: Dictionary) -> ItemDef:
	var item_path := str(stack.get("resource_path", stack.get("item_path", "")))
	if item_path == "" or not ResourceLoader.exists(item_path):
		return null
	return load(item_path) as ItemDef
