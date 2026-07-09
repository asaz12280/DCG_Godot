class_name ItemStackTooltipPresenter
extends RefCounted

const ItemDurabilityServiceScript := preload("res://scripts/items/item_durability_service.gd")
const ItemCodexPresenterScript := preload("res://scripts/ui/item_codex_presenter.gd")


static func build(owner: Control, stack: Dictionary, context: Dictionary = {}) -> Dictionary:
	if stack.is_empty():
		return {}
	var item_def := _load_item_from_stack(stack)
	var durability_stack: Dictionary = ItemDurabilityServiceScript.normalize_stack(stack, item_def)
	var quantity := maxi(int(stack.get("quantity", 1)), 1)
	var max_stack := maxi(int(stack.get("max_stack", 1)), 1)
	var value := maxi(int(stack.get("value", 0)), 0)
	var weight := maxf(float(stack.get("weight", 0.0)), 0.0)
	var catalog_number := int(stack.get("catalog_number", item_def.catalog_number if item_def != null else 0))
	var lines: Array[String] = []
	var description := _localized_text(owner, StringName(str(stack.get("description_key", ""))), "")
	if description != "":
		lines.append(description)
	var item_type := str(stack.get("type", "loot"))
	var type_name := _localized_text(owner, StringName("item_type.%s" % item_type), item_type.capitalize())
	var codex_category_id := _codex_category_id(item_def)
	var codex_category_name := _codex_category_name(owner, item_def)
	if catalog_number > 0:
		lines.append(ItemCodexPresenterScript.catalog_label(catalog_number))
	lines.append(_localized_text(owner, &"ui.item.type_format", "Type: %s") % codex_category_name)
	lines.append(_localized_text(owner, &"ui.item.stack_weight_format", "Total weight %.2f kg") % (weight * float(quantity)))
	_add_combat_rows(owner, stack, lines)
	_add_consumable_rows(owner, stack, lines)
	_add_durability_rows(owner, durability_stack, lines)
	var source_values: Array = context.get("needed_sources", []) as Array
	var needed_sources: Array[String] = _needed_source_labels(owner, source_values)
	if not needed_sources.is_empty():
		lines.append(_localized_text(owner, &"ui.item.needed_format", "Needed: %s") % _join_strings(needed_sources, ", "))
	return {
		"title": _stack_display_name(owner, stack),
		"item_path": str(stack.get("resource_path", stack.get("item_path", ""))),
		"catalog_number": catalog_number,
		"codex_category_id": codex_category_id,
		"codex_category_name": codex_category_name,
		"item_type": item_type,
		"item_type_name": type_name,
		"quantity": quantity,
		"max_stack": max_stack,
		"value": value,
		"total_value": value * quantity,
		"weight": weight,
		"total_weight": weight * float(quantity),
		"lines": lines,
		"needed_sources": needed_sources,
		"durability": durability_stack,
	}


static func tooltip_text(tooltip: Dictionary) -> String:
	if tooltip.is_empty():
		return ""
	var parts: Array[String] = []
	parts.append(str(tooltip.get("title", "")))
	for line in tooltip.get("lines", []) as Array:
		var line_text := str(line).strip_edges()
		if line_text != "":
			parts.append(line_text)
	return _join_strings(parts, "\n")


static func _add_combat_rows(owner: Control, stack: Dictionary, lines: Array[String]) -> void:
	var damage := maxi(int(stack.get("damage", 0)), 0)
	if damage > 0:
		lines.append(_localized_text(owner, &"ui.item.damage_format", "Damage %d") % damage)
	var defense_bonus := maxf(float(stack.get("defense_bonus", 0.0)), 0.0)
	var armor_protection_level := maxf(float(stack.get("armor_protection_level", 0.0)), 0.0)
	var effective_defense := maxf(defense_bonus, armor_protection_level)
	if effective_defense > 0.0:
		lines.append(_localized_text(owner, &"ui.item.defense_format", "Defense %.0f") % effective_defense)
	var magazine_capacity := maxi(int(stack.get("magazine_capacity", 0)), 0)
	if magazine_capacity > 0:
		lines.append(_localized_text(owner, &"ui.item.magazine_format", "Magazine %d") % magazine_capacity)
	var attachment_magazine_capacity_bonus := maxi(int(stack.get("attachment_magazine_capacity_bonus", 0)), 0)
	if attachment_magazine_capacity_bonus > 0:
		lines.append(_localized_text(owner, &"ui.item.attachment_magazine_bonus_format", "Magazine +%d") % attachment_magazine_capacity_bonus)
	var attachment_vertical_recoil_multiplier := maxf(float(stack.get("attachment_vertical_recoil_multiplier", 1.0)), 0.0)
	var attachment_horizontal_recoil_multiplier := maxf(float(stack.get("attachment_horizontal_recoil_multiplier", 1.0)), 0.0)
	if absf(attachment_vertical_recoil_multiplier - 1.0) > 0.001 or absf(attachment_horizontal_recoil_multiplier - 1.0) > 0.001:
		lines.append(_localized_text(owner, &"ui.item.attachment_recoil_multiplier_format", "Recoil V%.2fx / H%.2fx") % [attachment_vertical_recoil_multiplier, attachment_horizontal_recoil_multiplier])
	var attachment_recoil_recovery_multiplier := maxf(float(stack.get("attachment_recoil_recovery_multiplier", 1.0)), 0.0)
	if absf(attachment_recoil_recovery_multiplier - 1.0) > 0.001:
		lines.append(_localized_text(owner, &"ui.item.attachment_recoil_recovery_format", "Recoil recovery %.2fx") % attachment_recoil_recovery_multiplier)
	var attachment_spread_multiplier := maxf(float(stack.get("attachment_spread_multiplier", 1.0)), 0.0)
	if absf(attachment_spread_multiplier - 1.0) > 0.001:
		lines.append(_localized_text(owner, &"ui.item.attachment_spread_multiplier_format", "Spread %.2fx") % attachment_spread_multiplier)
	var horizontal_recoil := maxf(float(stack.get("weapon_horizontal_recoil", 0.0)), 0.0)
	var vertical_recoil := maxf(float(stack.get("weapon_vertical_recoil", 0.0)), 0.0)
	if horizontal_recoil > 0.0 or vertical_recoil > 0.0:
		lines.append(_localized_text(owner, &"ui.item.weapon_recoil_format", "Recoil V%.1f / H%.1f") % [vertical_recoil, horizontal_recoil])
	var projectile_pierce_chance := clampf(float(stack.get("projectile_pierce_chance", 0.0)), 0.0, 100.0)
	if projectile_pierce_chance > 0.0:
		lines.append(_localized_text(owner, &"ui.item.projectile_pierce_chance_format", "Pierce chance %.0f%%") % projectile_pierce_chance)
	if str(stack.get("type", "")) == "ammo":
		var ammo_penetration_level := maxf(float(stack.get("ammo_penetration_level", 0.0)), 0.0)
		lines.append(_localized_text(owner, &"ui.item.ammo_penetration_level_format", "Penetration Lv. %.0f") % ammo_penetration_level)
		var ammo_damage_multiplier := maxf(float(stack.get("ammo_damage_multiplier", 1.0)), 0.0)
		lines.append(_localized_text(owner, &"ui.item.ammo_damage_multiplier_format", "Ammo damage %.2fx") % ammo_damage_multiplier)
		var ammo_spread_multiplier := maxf(float(stack.get("ammo_spread_multiplier", 1.0)), 0.0)
		lines.append(_localized_text(owner, &"ui.item.ammo_spread_multiplier_format", "Spread %.2fx") % ammo_spread_multiplier)
		var weapon_wear_rate := maxf(float(stack.get("weapon_wear_rate", 1.0)), 0.0)
		lines.append(_localized_text(owner, &"ui.item.weapon_wear_rate_format", "Weapon wear %.2fx") % weapon_wear_rate)
		var ammo_recoil_multiplier := maxf(float(stack.get("ammo_recoil_multiplier", 1.0)), 0.0)
		lines.append(_localized_text(owner, &"ui.item.ammo_recoil_multiplier_format", "Recoil %.2fx") % ammo_recoil_multiplier)


static func _add_consumable_rows(owner: Control, stack: Dictionary, lines: Array[String]) -> void:
	var heal_amount := maxf(float(stack.get("heal_amount", 0.0)), 0.0)
	if heal_amount > 0.0:
		var heal_text := _localized_text(owner, &"ui.item.heal_amount_format", "")
		if heal_text != "":
			lines.append(heal_text % heal_amount)
	var use_duration := maxf(float(stack.get("use_duration_seconds", 0.0)), 0.0)
	if use_duration > 0.0:
		var use_text := _localized_text(owner, &"ui.item.use_duration_format", "")
		if use_text != "":
			lines.append(use_text % use_duration)
	var max_health_bonus := maxf(float(stack.get("max_health_bonus", 0.0)), 0.0)
	if max_health_bonus > 0.0:
		var health_text := _localized_text(owner, &"ui.item.max_health_bonus_format", "")
		if health_text != "":
			lines.append(health_text % max_health_bonus)


static func _add_durability_rows(owner: Control, stack: Dictionary, lines: Array[String]) -> void:
	if not bool(stack.get("has_durability", false)):
		return
	var current := int(stack.get("current_durability", 0))
	var maximum := int(stack.get("max_durability", 0))
	lines.append(_localized_text(owner, &"ui.item.durability_format", "Durability %d/%d") % [current, maximum])
	var repair_loss := int(stack.get("repair_max_durability_loss", 0))
	if repair_loss > 0:
		lines.append(_localized_text(owner, &"ui.item.repair_wear_format", "Repair wear -%d max durability") % repair_loss)


static func _needed_source_labels(owner: Control, sources: Array) -> Array[String]:
	var labels: Array[String] = []
	for source in sources:
		var source_name := str(source)
		var key := StringName("ui.item.needed_source.%s" % source_name)
		var fallback := source_name.capitalize().replace("_", " ")
		var label := _localized_text(owner, key, fallback)
		if label != "" and not labels.has(label):
			labels.append(label)
	return labels


static func _codex_category_id(item_def: ItemDef) -> String:
	if item_def == null:
		return "item"
	return ItemCodexPresenterScript.codex_category_id(item_def)


static func _codex_category_name(owner: Control, item_def: ItemDef) -> String:
	if item_def == null:
		return _localized_text(owner, &"codex_category.other", "Other")
	var name := ItemCodexPresenterScript.codex_category_name(owner, item_def)
	return name if name != "" else _localized_text(owner, &"codex_category.other", "Other")


static func _stack_display_name(owner: Control, stack: Dictionary) -> String:
	var key := StringName(str(stack.get("name_key", "")))
	var localized := _localized_text(owner, key, "")
	if localized != "":
		return localized
	var fallback := str(stack.get("name", "")).strip_edges()
	if fallback != "":
		return fallback
	return _localized_text(owner, &"item.unknown.name", "Unknown Item")


static func _load_item_from_stack(stack: Dictionary) -> ItemDef:
	var item_path := str(stack.get("resource_path", stack.get("item_path", ""))).strip_edges()
	if item_path == "" or not ResourceLoader.exists(item_path):
		return null
	return load(item_path) as ItemDef


static func _localized_text(owner: Control, key: StringName, fallback: String) -> String:
	var key_text := str(key)
	if key_text == "":
		return fallback
	var translated: String = ""
	if owner != null:
		translated = owner.tr(key_text)
	else:
		translated = TranslationServer.translate(key_text)
	if translated == key_text or translated == "":
		return fallback
	return translated


static func _join_strings(values: Array[String], separator: String) -> String:
	var result := ""
	for index in range(values.size()):
		if index > 0:
			result += separator
		result += values[index]
	return result
