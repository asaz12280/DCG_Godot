class_name ItemInspectionFieldPolicy
extends RefCounted

const SURFACE_TOOLTIP := &"tooltip"
const SURFACE_DETAIL := &"detail"
const SURFACE_CODEX := &"codex"

const SECTION_INFO := &"info"
const SECTION_STATS := &"stats"
const TOOLTIP_ROW_LIMIT := 3
const WEAPON_TOOLTIP_ROW_LIMIT := 4

# This is the single presentation policy for item facts. Value calculation stays
# in focused builders; this table only owns ordering and surface visibility.
const FIELD_ORDER: Array[StringName] = [
	&"description",
	&"needed_sources",
	&"category",
	&"total_weight",
	&"weapon_ammo",
	&"durability",
	&"durability_penalty_threshold",
	&"unit_weight",
	&"value",
	&"total_value",
	&"max_stack",
	&"heal_amount",
	&"stamina_restore",
	&"thirst_restore",
	&"satiety_restore",
	&"use_duration",
	&"max_health_bonus",
	&"defense",
	&"weapon_damage",
	&"weapon_fire_rate",
	&"weapon_projectiles_per_shot",
	&"weapon_projectile_spread",
	&"weapon_attack_rate",
	&"weapon_armor_penetration",
	&"weapon_critical_chance",
	&"weapon_pierce_chance",
	&"weapon_magazine_capacity",
	&"weapon_ammo_compatibility",
	&"weapon_attachment_slots",
	&"weapon_reload_duration",
	&"weapon_vertical_recoil",
	&"weapon_horizontal_recoil",
	&"weapon_range",
	&"weapon_attack_range",
	&"weapon_durability_wear",
	&"attachment_magazine_bonus",
	&"attachment_recoil",
	&"attachment_recoil_recovery",
	&"attachment_spread",
	&"ammo_tag",
	&"repair_wear",
]

const FIELD_RULES := {
	&"description": {"section": SECTION_INFO, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX]},
	&"needed_sources": {"section": SECTION_INFO, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX]},
	&"category": {"section": SECTION_STATS, "surfaces": [SURFACE_TOOLTIP]},
	&"total_weight": {"section": SECTION_STATS, "surfaces": [SURFACE_TOOLTIP]},
	&"weapon_ammo": {"section": SECTION_STATS, "surfaces": [SURFACE_TOOLTIP], "item_types": ["weapon"]},
	&"durability_penalty_threshold": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX]},
	&"unit_weight": {"section": SECTION_STATS, "surfaces": [SURFACE_CODEX]},
	&"value": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX]},
	&"total_value": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL]},
	&"max_stack": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX]},
	&"heal_amount": {"section": SECTION_STATS, "surfaces": [SURFACE_TOOLTIP, SURFACE_DETAIL, SURFACE_CODEX]},
	&"stamina_restore": {"section": SECTION_STATS, "surfaces": [SURFACE_TOOLTIP, SURFACE_DETAIL, SURFACE_CODEX]},
	&"thirst_restore": {"section": SECTION_STATS, "surfaces": [SURFACE_TOOLTIP, SURFACE_DETAIL, SURFACE_CODEX]},
	&"satiety_restore": {"section": SECTION_STATS, "surfaces": [SURFACE_TOOLTIP, SURFACE_DETAIL, SURFACE_CODEX]},
	&"use_duration": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX]},
	&"max_health_bonus": {"section": SECTION_STATS, "surfaces": [SURFACE_TOOLTIP, SURFACE_DETAIL, SURFACE_CODEX]},
	&"defense": {"section": SECTION_STATS, "surfaces": [SURFACE_TOOLTIP, SURFACE_DETAIL, SURFACE_CODEX]},
	&"weapon_damage": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["weapon"]},
	&"weapon_fire_rate": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["weapon"]},
	&"weapon_projectiles_per_shot": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["weapon"]},
	&"weapon_projectile_spread": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["weapon"]},
	&"weapon_attack_rate": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["weapon"]},
	&"weapon_armor_penetration": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["weapon"]},
	&"weapon_critical_chance": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["weapon"]},
	&"weapon_pierce_chance": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["weapon"]},
	&"weapon_magazine_capacity": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["weapon"]},
	&"weapon_ammo_compatibility": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["weapon"]},
	&"weapon_attachment_slots": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["weapon"]},
	&"weapon_reload_duration": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["weapon"]},
	&"weapon_vertical_recoil": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["weapon"]},
	&"weapon_horizontal_recoil": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["weapon"]},
	&"weapon_range": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["weapon"]},
	&"weapon_attack_range": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["weapon"]},
	&"weapon_durability_wear": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["weapon"]},
	&"attachment_magazine_bonus": {"section": SECTION_STATS, "surfaces": [SURFACE_TOOLTIP, SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["attachment"]},
	&"attachment_recoil": {"section": SECTION_STATS, "surfaces": [SURFACE_TOOLTIP, SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["attachment"]},
	&"attachment_recoil_recovery": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["attachment"]},
	&"attachment_spread": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["attachment"]},
	&"ammo_tag": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX], "item_types": ["ammo"]},
	&"durability": {"section": SECTION_STATS, "surfaces": [SURFACE_TOOLTIP, SURFACE_DETAIL, SURFACE_CODEX]},
	&"repair_wear": {"section": SECTION_STATS, "surfaces": [SURFACE_DETAIL, SURFACE_CODEX]},
}


static func rows_for_surface(fields: Dictionary, surface: StringName, item_type: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for field_id in FIELD_ORDER:
		if not fields.has(field_id):
			continue
		var rule: Dictionary = FIELD_RULES.get(field_id, {}) as Dictionary
		if not (rule.get("surfaces", []) as Array).has(surface):
			continue
		var item_types: Array = rule.get("item_types", []) as Array
		if not item_types.is_empty() and not item_types.has(item_type):
			continue
		var stored_field: Dictionary = fields[field_id] as Dictionary
		var source_rows: Array = stored_field.get("repeat_rows", [stored_field]) as Array
		for source_row in source_rows:
			var row: Dictionary = (source_row as Dictionary).duplicate(true)
			row["field_id"] = field_id
			row["section"] = rule.get("section", SECTION_STATS)
			rows.append(row)
			var tooltip_limit := WEAPON_TOOLTIP_ROW_LIMIT if item_type == "weapon" else TOOLTIP_ROW_LIMIT
			if surface == SURFACE_TOOLTIP and rows.size() >= tooltip_limit:
				return rows
	return rows


static func section_title_key(item_type: String, section: StringName) -> StringName:
	if item_type == "weapon":
		return &"ui.weapon_detail.info_title" if section == SECTION_INFO else &"ui.weapon_detail.stats_title"
	return &"ui.item_detail.info_title" if section == SECTION_INFO else &"ui.item_detail.stats_title"


static func text_lines(rows: Array[Dictionary], section: StringName = &"") -> Array[String]:
	var lines: Array[String] = []
	for row in rows:
		if section != &"" and StringName(str(row.get("section", ""))) != section:
			continue
		var text := str(row.get("text", "")).strip_edges()
		if text != "":
			lines.append(text)
	return lines


static func value_rows(rows: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in rows:
		if StringName(str(row.get("section", ""))) != SECTION_STATS:
			continue
		var label := str(row.get("label", "")).strip_edges()
		var value := str(row.get("codex_value", row.get("value", ""))).strip_edges()
		if label == "" or value == "":
			continue
		result.append({
			"field_id": row.get("field_id", &""),
			"label_key": row.get("label_key", &""),
			"label": label,
			"value": value,
		})
	return result
