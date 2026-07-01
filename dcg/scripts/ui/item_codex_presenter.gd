class_name ItemCodexPresenter
extends RefCounted


static func localized_text(owner: Control, key: StringName) -> String:
	var key_text := str(key)
	if key_text == "":
		return ""
	var translated := owner.tr(key_text)
	return "" if translated == key_text else translated


static func item_name(owner: Control, item: ItemDef) -> String:
	return localized_text(owner, item.name_key)


static func item_type_name(owner: Control, item_type: String) -> String:
	return localized_text(owner, StringName("item_type.%s" % item_type))


static func stat_rows(owner: Control, item: ItemDef) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [
		{"label": localized_text(owner, &"ui.codex.weight"), "value": "%.2f kg" % item.weight},
		{"label": localized_text(owner, &"ui.codex.value"), "value": str(item.value)},
	]
	if item.max_stack > 1:
		rows.append({"label": localized_text(owner, &"ui.codex.max_stack"), "value": str(item.max_stack)})
	if item.tags.has(&"gun") and item.damage > 0:
		rows.append({"label": localized_text(owner, &"ui.codex.damage"), "value": str(item.damage)})
	return rows


static func item_type_color(item_type: String) -> Color:
	match item_type:
		"weapon":
			return Color(0.72, 0.24, 0.20, 0.95)
		"ammo":
			return Color(0.76, 0.62, 0.22, 0.95)
		"armor":
			return Color(0.34, 0.43, 0.56, 0.95)
		"backpack":
			return Color(0.46, 0.34, 0.22, 0.95)
		"attachment":
			return Color(0.38, 0.43, 0.46, 0.95)
		"medical":
			return Color(0.80, 0.20, 0.26, 0.95)
		"food":
			return Color(0.66, 0.46, 0.24, 0.95)
		"consumable":
			return Color(0.42, 0.64, 0.28, 0.95)
		"key":
			return Color(0.84, 0.72, 0.34, 0.95)
		"crafting":
			return Color(0.52, 0.54, 0.47, 0.95)
		"electronics":
			return Color(0.18, 0.58, 0.66, 0.95)
		"explosive":
			return Color(0.78, 0.32, 0.12, 0.95)
		"valuable":
			return Color(0.82, 0.62, 0.18, 0.95)
		"intel":
			return Color(0.34, 0.50, 0.76, 0.95)
		"quest":
			return Color(0.58, 0.34, 0.76, 0.95)
		"totem":
			return Color(0.42, 0.74, 0.58, 0.95)
		"recipe":
			return Color(0.58, 0.48, 0.78, 0.95)
		"loot":
			return Color(0.30, 0.52, 0.64, 0.95)
		_:
			return Color(0.48, 0.48, 0.52, 0.95)
