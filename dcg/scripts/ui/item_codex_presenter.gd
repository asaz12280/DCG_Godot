class_name ItemCodexPresenter
extends RefCounted

const CODEX_CATEGORY_ORDER: Array[String] = [
	"weapon",
	"ammo",
	"equipment",
	"attachment",
	"totem",
	"medical",
	"food",
	"crafting",
	"electronics",
	"key",
	"loot",
	"currency",
	"valuable",
	"intel",
	"quest",
	"recipe",
	"explosive",
	"other",
]


static func localized_text(owner: Control, key: StringName) -> String:
	var key_text := str(key)
	if key_text == "":
		return ""
	var translated := owner.tr(key_text)
	return "" if translated == key_text else translated


static func item_name(owner: Control, item: ItemDef) -> String:
	return localized_text(owner, item.name_key)


static func catalog_label(catalog_number: int) -> String:
	return "#%d" % catalog_number


static func item_type_name(owner: Control, item_type: String) -> String:
	return localized_text(owner, StringName("item_type.%s" % item_type))


static func codex_category_id(item: ItemDef) -> String:
	if item == null:
		return "other"
	match item.item_type:
		"weapon":
			return "weapon"
		"ammo":
			return "ammo"
		"armor", "backpack":
			return "equipment"
		"attachment":
			if item.tags.has(&"headset") or item.tags.has(&"glasses"):
				return "equipment"
			return "attachment"
		"totem":
			return "totem"
		"medical", "consumable":
			return "medical"
		"food":
			return "food"
		"crafting":
			return "crafting"
		"electronics":
			return "electronics"
		"key":
			return "key"
		"loot":
			return "loot"
		"currency":
			return "currency"
		"valuable":
			return "valuable"
		"intel":
			return "intel"
		"quest":
			return "quest"
		"recipe":
			return "recipe"
		"explosive":
			return "explosive"
		_:
			return "other"


static func codex_category_order() -> Array[String]:
	return CODEX_CATEGORY_ORDER.duplicate()


static func codex_category_sort_order(item: ItemDef) -> int:
	return codex_category_sort_order_for_id(codex_category_id(item))


static func codex_category_sort_order_for_id(category_id: String) -> int:
	var index := CODEX_CATEGORY_ORDER.find(category_id)
	return index if index >= 0 else CODEX_CATEGORY_ORDER.find("other")


static func codex_category_name(owner: Control, item: ItemDef) -> String:
	return localized_text(owner, StringName("codex_category.%s" % codex_category_id(item)))


static func stat_rows(owner: Control, item: ItemDef) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [
		{"label": localized_text(owner, &"ui.codex.weight"), "value": "%.2f kg" % item.weight},
		{"label": localized_text(owner, &"ui.codex.value"), "value": str(item.value)},
	]
	if item.get_max_stack() > 1:
		rows.append({"label": localized_text(owner, &"ui.codex.max_stack"), "value": str(item.get_max_stack())})
	if item.tags.has(&"gun") and item.get_weapon_damage() > 0:
		rows.append({"label": localized_text(owner, &"ui.codex.damage"), "value": str(item.get_weapon_damage())})
	if item.get_max_durability() > 0:
		rows.append({"label": localized_text(owner, &"ui.codex.durability"), "value": str(item.get_max_durability())})
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
		"currency":
			return Color(0.82, 0.62, 0.18, 0.95)
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


static func codex_category_color(item: ItemDef) -> Color:
	match codex_category_id(item):
		"weapon":
			return Color(0.72, 0.24, 0.20, 0.95)
		"ammo":
			return Color(0.76, 0.62, 0.22, 0.95)
		"equipment":
			return Color(0.34, 0.43, 0.56, 0.95)
		"attachment":
			return Color(0.38, 0.43, 0.46, 0.95)
		"totem":
			return Color(0.42, 0.74, 0.58, 0.95)
		"medical":
			return Color(0.80, 0.20, 0.26, 0.95)
		"food":
			return Color(0.66, 0.46, 0.24, 0.95)
		"crafting":
			return Color(0.52, 0.54, 0.47, 0.95)
		"electronics":
			return Color(0.18, 0.58, 0.66, 0.95)
		"key":
			return Color(0.84, 0.72, 0.34, 0.95)
		"loot":
			return Color(0.30, 0.52, 0.64, 0.95)
		"currency", "valuable":
			return Color(0.82, 0.62, 0.18, 0.95)
		"intel":
			return Color(0.34, 0.50, 0.76, 0.95)
		"quest":
			return Color(0.58, 0.34, 0.76, 0.95)
		"recipe":
			return Color(0.58, 0.48, 0.78, 0.95)
		"explosive":
			return Color(0.78, 0.32, 0.12, 0.95)
		_:
			return Color(0.30, 0.52, 0.64, 0.95)
