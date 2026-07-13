class_name ItemInspectionSnapshotBuilder
extends RefCounted

const ItemDurabilityServiceScript := preload("res://scripts/items/item_durability_service.gd")
const WeaponAttachmentServiceScript := preload("res://scripts/combat/weapon_attachment_service.gd")
const WeaponTuningServiceScript := preload("res://scripts/combat/weapon_tuning_service.gd")
const FieldPolicyScript := preload("res://scripts/ui/item_inspection_field_policy.gd")
const WeaponRowsScript := preload("res://scripts/items/item_inspection_weapon_rows.gd")
const WeaponHardpointLabelsScript := preload("res://scripts/ui/weapon_hardpoint_labels.gd")


static func build(owner: Object, stack: Dictionary, context: Dictionary = {}) -> Dictionary:
	if stack.is_empty():
		return {}
	var item_def := _load_item_from_stack(stack)
	var durability_stack: Dictionary = ItemDurabilityServiceScript.normalize_stack(stack, item_def)
	var item_type := str(stack.get("type", item_def.item_type if item_def != null else "loot"))
	var quantity := maxi(int(stack.get("quantity", 1)), 1)
	var max_stack := maxi(int(stack.get("max_stack", item_def.get_max_stack() if item_def != null else 1)), 1)
	var unit_value := maxi(int(stack.get("value", item_def.value if item_def != null else 0)), 0)
	var unit_weight := maxf(float(stack.get("weight", item_def.weight if item_def != null else 0.0)), 0.0)
	var type_name := _localized_text(owner, StringName("item_type.%s" % item_type), item_type.capitalize())
	var fields: Dictionary = {}

	var description := _localized_text(owner, StringName(str(stack.get("description_key", item_def.description_key if item_def != null else &""))), "")
	if description != "":
		_add_text_field(fields, &"description", description)
	_add_text_field(fields, &"category", _localized_text(owner, &"ui.item.type_format", "Type: %s") % type_name)
	_add_text_field(fields, &"total_weight", _localized_text(owner, &"ui.item.stack_weight_format", "Total weight %.2f kg") % (unit_weight * float(quantity)))
	_add_value_field(owner, fields, &"unit_weight", &"ui.codex.weight", "%.2f kg" % unit_weight)
	_add_value_field(owner, fields, &"value", &"ui.codex.value", str(unit_value))
	if quantity > 1:
		_add_value_field(owner, fields, &"total_value", &"ui.item.total_value", str(unit_value * quantity), "Total Value")
	if max_stack > 1:
		_add_value_field(owner, fields, &"max_stack", &"ui.codex.max_stack", str(max_stack))

	var needed_sources := _needed_source_labels(owner, context.get("needed_sources", []) as Array)
	if not needed_sources.is_empty():
		_add_text_field(fields, &"needed_sources", _localized_text(owner, &"ui.item.needed_format", "Needed: %s") % _join_strings(needed_sources, ", "))

	if item_type == "weapon" and item_def != null:
		_add_weapon_fields(owner, fields, item_def, durability_stack)
		_add_repair_wear_field(owner, fields, durability_stack)
	else:
		_add_non_weapon_combat_fields(owner, fields, stack)
		_add_durability_fields(owner, fields, durability_stack)
	_add_durability_threshold_field(owner, fields, durability_stack)
	if item_type == "ammo":
		var ammo_tag := str(stack.get("ammo_tag", item_def.get_ammo_tag() if item_def != null else &""))
		if ammo_tag != "":
			_add_value_field(owner, fields, &"ammo_tag", &"ui.item_stat.ammo_type", ammo_tag)
	_add_consumable_fields(owner, fields, stack)
	_add_attachment_fields(owner, fields, stack)

	var tooltip_rows := FieldPolicyScript.rows_for_surface(fields, FieldPolicyScript.SURFACE_TOOLTIP, item_type)
	var detail_rows := FieldPolicyScript.rows_for_surface(fields, FieldPolicyScript.SURFACE_DETAIL, item_type)
	var codex_rows := FieldPolicyScript.rows_for_surface(fields, FieldPolicyScript.SURFACE_CODEX, item_type)
	var detail_info_lines := FieldPolicyScript.text_lines(detail_rows, FieldPolicyScript.SECTION_INFO)
	var detail_stat_lines := FieldPolicyScript.text_lines(detail_rows, FieldPolicyScript.SECTION_STATS)
	var detail_lines: Array[String] = detail_info_lines.duplicate()
	detail_lines.append_array(detail_stat_lines)
	return {
		"title": _stack_display_name(owner, stack),
		"item_path": str(stack.get("resource_path", stack.get("item_path", ""))),
		"catalog_number": int(stack.get("catalog_number", item_def.catalog_number if item_def != null else 0)),
		"item_type": item_type,
		"item_type_name": type_name,
		"quantity": quantity,
		"max_stack": max_stack,
		"value": unit_value,
		"total_value": unit_value * quantity,
		"weight": unit_weight,
		"total_weight": unit_weight * float(quantity),
		"lines": FieldPolicyScript.text_lines(tooltip_rows),
		"detail_lines": detail_lines,
		"detail_info_lines": detail_info_lines,
		"detail_stat_lines": detail_stat_lines,
		"codex_info_lines": FieldPolicyScript.text_lines(codex_rows, FieldPolicyScript.SECTION_INFO),
		"codex_stat_rows": FieldPolicyScript.value_rows(codex_rows),
		"inspection_fields": fields.duplicate(true),
		"needed_sources": needed_sources,
		"durability": durability_stack,
	}


static func _add_weapon_fields(owner: Object, fields: Dictionary, item_def: ItemDef, weapon_stack: Dictionary) -> void:
	var attachment_state := WeaponAttachmentServiceScript.modifiers_for_weapon_stack(weapon_stack, item_def)
	var ammo_state: Dictionary = weapon_stack.get("weapon_ammo_state", {}) as Dictionary
	var ammo_item := _load_ammo_item(ammo_state)
	var snapshot := WeaponTuningServiceScript.resolve_snapshot(item_def, ammo_item, attachment_state, weapon_stack)
	var capabilities := {
		"weapon_kind": item_def.get_weapon_kind(),
		"uses_ammo": item_def.weapon_uses_ammo(),
		"supports_attachments": item_def.weapon_supports_attachments(),
		"has_durability": item_def.weapon_has_durability(),
	}
	if bool(capabilities.get("uses_ammo", false)):
		var loaded_ammo := maxi(int(ammo_state.get("loaded_ammo", 0)), 0)
		var magazine_capacity := maxi(int(snapshot.get("magazine_capacity", 0)), 0)
		_add_text_field(fields, &"weapon_ammo", _localized_text(owner, &"ui.weapon_mod.summary_ammo", "Ammo %d/%d") % [loaded_ammo, magazine_capacity])
		var compatible_ammo := _string_names(item_def.get_weapon_compatible_ammo_tags())
		if not compatible_ammo.is_empty():
			_add_value_field(owner, fields, &"weapon_ammo_compatibility", &"ui.item_stat.compatible_ammo", _join_strings(compatible_ammo, ", "))
	var attachment_slot_rows: Array[Dictionary] = []
	for hardpoint in item_def.get_weapon_attachment_slots():
		var hardpoint_key := WeaponHardpointLabelsScript.label_key(hardpoint)
		var hardpoint_name := _localized_text(owner, hardpoint_key, "")
		if hardpoint_key == &"" or hardpoint_name == "":
			continue
		attachment_slot_rows.append(_value_field(owner, &"ui.item_stat.attachment_slots", hardpoint_name))
	if not attachment_slot_rows.is_empty():
		fields[&"weapon_attachment_slots"] = {"repeat_rows": attachment_slot_rows}
	for value in WeaponRowsScript.build(snapshot, capabilities, true):
		var row := value as Dictionary
		var field_id := StringName(str(row.get("field_id", "")))
		var label_key := StringName(str(row.get("label_key", "")))
		_add_value_field(owner, fields, field_id, label_key, str(row.get("value", "")))
		if field_id == &"durability":
			var durability: Dictionary = snapshot.get("durability", {}) as Dictionary
			var durability_field: Dictionary = fields[field_id] as Dictionary
			durability_field["codex_value"] = str(maxi(int(durability.get("max_durability", 0)), 0))
			fields[field_id] = durability_field


static func _add_non_weapon_combat_fields(owner: Object, fields: Dictionary, stack: Dictionary) -> void:
	var defense_bonus := maxf(float(stack.get("defense_bonus", 0.0)), 0.0)
	var protection_level := maxf(float(stack.get("armor_protection_level", 0.0)), 0.0)
	var defense := maxf(defense_bonus, protection_level)
	if defense > 0.0:
		_add_value_field(owner, fields, &"defense", &"ui.codex.defense", "%.0f" % defense, "Defense")


static func _add_consumable_fields(owner: Object, fields: Dictionary, stack: Dictionary) -> void:
	_add_positive_format_field(owner, fields, stack, &"heal_amount", &"heal_amount", &"ui.item.heal_amount_format")
	_add_positive_format_field(owner, fields, stack, &"stamina_restore", &"stamina_restore", &"ui.item.stamina_restore_format")
	_add_positive_format_field(owner, fields, stack, &"thirst_restore", &"thirst_restore", &"ui.item.thirst_restore_format")
	_add_positive_format_field(owner, fields, stack, &"satiety_restore", &"satiety_restore", &"ui.item.satiety_restore_format")
	_add_positive_format_field(owner, fields, stack, &"use_duration", &"use_duration_seconds", &"ui.item.use_duration_format")
	_add_positive_format_field(owner, fields, stack, &"max_health_bonus", &"max_health_bonus", &"ui.item.max_health_bonus_format")


static func _add_attachment_fields(owner: Object, fields: Dictionary, stack: Dictionary) -> void:
	var magazine_bonus := maxi(int(stack.get("attachment_magazine_capacity_bonus", 0)), 0)
	if magazine_bonus > 0:
		_add_text_value_field(owner, fields, &"attachment_magazine_bonus", &"ui.weapon_stat.magazine_capacity", "+%d" % magazine_bonus, &"ui.item.attachment_magazine_bonus_format", [magazine_bonus])
	var vertical := maxf(float(stack.get("attachment_vertical_recoil_multiplier", 1.0)), 0.0)
	var horizontal := maxf(float(stack.get("attachment_horizontal_recoil_multiplier", 1.0)), 0.0)
	if not is_equal_approx(vertical, 1.0) or not is_equal_approx(horizontal, 1.0):
		_add_text_value_field(owner, fields, &"attachment_recoil", &"ui.weapon_stat.recoil_angle", "V%.2fx / H%.2fx" % [vertical, horizontal], &"ui.item.attachment_recoil_multiplier_format", [vertical, horizontal])
	var recovery := maxf(float(stack.get("attachment_recoil_recovery_multiplier", 1.0)), 0.0)
	if not is_equal_approx(recovery, 1.0):
		_add_text_value_field(owner, fields, &"attachment_recoil_recovery", &"ui.weapon_stat.recoil_recovery", "%.2fx" % recovery, &"ui.item.attachment_recoil_recovery_format", [recovery])
	var spread := maxf(float(stack.get("attachment_spread_multiplier", 1.0)), 0.0)
	if not is_equal_approx(spread, 1.0):
		_add_text_value_field(owner, fields, &"attachment_spread", &"ui.weapon_stat.spread", "%.2fx" % spread, &"ui.item.attachment_spread_multiplier_format", [spread])


static func _add_durability_fields(owner: Object, fields: Dictionary, stack: Dictionary) -> void:
	if not bool(stack.get("has_durability", false)):
		return
	var current := maxi(int(stack.get("current_durability", 0)), 0)
	var maximum := maxi(int(stack.get("max_durability", 0)), 0)
	if maximum > 0:
		_add_text_value_field(owner, fields, &"durability", &"ui.codex.durability", "%d/%d" % [current, maximum], &"ui.item.durability_format", [current, maximum])
		var durability_field: Dictionary = fields[&"durability"] as Dictionary
		durability_field["codex_value"] = str(maximum)
		fields[&"durability"] = durability_field
	_add_repair_wear_field(owner, fields, stack)


static func _add_repair_wear_field(owner: Object, fields: Dictionary, stack: Dictionary) -> void:
	var repair_loss := maxi(int(stack.get("repair_max_durability_loss", 0)), 0)
	if repair_loss > 0:
		_add_text_value_field(owner, fields, &"repair_wear", &"ui.item.repair_wear", "-%d" % repair_loss, &"ui.item.repair_wear_format", [repair_loss], "Repair Wear")


static func _add_durability_threshold_field(owner: Object, fields: Dictionary, stack: Dictionary) -> void:
	if not bool(stack.get("has_durability", false)):
		return
	var penalty_ratio := clampf(float(stack.get("durability_penalty_ratio", 0.0)), 0.0, 1.0)
	if penalty_ratio > 0.0:
		_add_value_field(owner, fields, &"durability_penalty_threshold", &"ui.item_stat.durability_penalty_threshold", "%.0f%%" % (penalty_ratio * 100.0))


static func _add_positive_format_field(owner: Object, fields: Dictionary, stack: Dictionary, field_id: StringName, stack_key: StringName, format_key: StringName) -> void:
	var amount := maxf(float(stack.get(str(stack_key), 0.0)), 0.0)
	if amount <= 0.0:
		return
	var text_format := _localized_text(owner, format_key, "")
	if text_format == "":
		return
	var text := text_format % amount
	var label_key := StringName("ui.item_stat.%s" % str(field_id))
	var label := _localized_text(owner, label_key, "")
	var value := "%.1f s" % amount if field_id == &"use_duration" else "+%.0f" % amount
	_add_field(fields, field_id, label_key, label, value, text)


static func _add_text_value_field(owner: Object, fields: Dictionary, field_id: StringName, label_key: StringName, value: String, format_key: StringName, format_values: Array, fallback_label: String = "") -> void:
	var label := _localized_text(owner, label_key, fallback_label)
	var text_format := _localized_text(owner, format_key, "")
	var text := text_format % format_values if text_format != "" else _label_value_text(label, value)
	_add_field(fields, field_id, label_key, label, value, text)


static func _add_value_field(owner: Object, fields: Dictionary, field_id: StringName, label_key: StringName, value: String, fallback_label: String = "") -> void:
	var row := _value_field(owner, label_key, value, fallback_label)
	_add_field(fields, field_id, row.get("label_key", &""), str(row.get("label", "")), str(row.get("value", "")), str(row.get("text", "")))


static func _value_field(owner: Object, label_key: StringName, value: String, fallback_label: String = "") -> Dictionary:
	var label := _localized_text(owner, label_key, fallback_label)
	return {"label_key": label_key, "label": label, "value": value, "text": _label_value_text(label, value)}


static func _add_text_field(fields: Dictionary, field_id: StringName, text: String) -> void:
	_add_field(fields, field_id, &"", "", "", text)


static func _add_field(fields: Dictionary, field_id: StringName, label_key: StringName, label: String, value: String, text: String) -> void:
	if field_id == &"" or text.strip_edges() == "":
		return
	fields[field_id] = {"label_key": label_key, "label": label, "value": value, "text": text}


static func _label_value_text(label: String, value: String) -> String:
	return value if label == "" else "%s  %s" % [label, value]


static func _needed_source_labels(owner: Object, sources: Array) -> Array[String]:
	var labels: Array[String] = []
	for source in sources:
		var source_name := str(source)
		var label := _localized_text(owner, StringName("ui.item.needed_source.%s" % source_name), source_name.capitalize().replace("_", " "))
		if label != "" and not labels.has(label):
			labels.append(label)
	return labels


static func _string_names(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		var text := str(value).strip_edges()
		if text != "":
			result.append(text)
	return result


static func _stack_display_name(owner: Object, stack: Dictionary) -> String:
	var localized := _localized_text(owner, StringName(str(stack.get("name_key", ""))), "")
	if localized != "":
		return localized
	var fallback := str(stack.get("name", "")).strip_edges()
	return fallback if fallback != "" else _localized_text(owner, &"item.unknown.name", "Unknown Item")


static func _load_item_from_stack(stack: Dictionary) -> ItemDef:
	var item_path := str(stack.get("resource_path", stack.get("item_path", ""))).strip_edges()
	if item_path == "" or not ResourceLoader.exists(item_path):
		return null
	return load(item_path) as ItemDef


static func _load_ammo_item(ammo_state: Dictionary) -> ItemDef:
	var ammo_path := str(ammo_state.get("ammo_item_path", "")).strip_edges()
	if ammo_path == "" or not ResourceLoader.exists(ammo_path):
		return null
	var item_def := load(ammo_path) as ItemDef
	return item_def if item_def != null and item_def.item_type == "ammo" else null


static func _localized_text(owner: Object, key: StringName, fallback: String) -> String:
	var key_text := str(key)
	if key_text == "":
		return fallback
	var translated := str(owner.tr(key_text)) if owner != null and owner.has_method("tr") else str(TranslationServer.translate(key_text))
	return fallback if translated == "" or translated == key_text else translated


static func _join_strings(values: Array[String], separator: String) -> String:
	var result := ""
	for index in range(values.size()):
		if index > 0:
			result += separator
		result += values[index]
	return result
