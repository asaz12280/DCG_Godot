class_name ItemCodexPresenter
extends RefCounted

const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")
const ItemInspectionSnapshotBuilderScript := preload("res://scripts/ui/item_inspection_snapshot_builder.gd")

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

const STORAGE_CATEGORY_ORDER: Array[String] = [
	"all",
	"weapon",
	"ammo",
	"equipment",
	"attachment",
	"totem",
	"medical",
	"food",
	"other",
]

const STORAGE_DIRECT_CATEGORY_IDS: Array[String] = [
	"weapon",
	"ammo",
	"equipment",
	"attachment",
	"totem",
	"medical",
	"food",
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


static func storage_category_order() -> Array[String]:
	return STORAGE_CATEGORY_ORDER.duplicate()


static func storage_category_id(item: ItemDef) -> String:
	var category_id := codex_category_id(item)
	return category_id if STORAGE_DIRECT_CATEGORY_IDS.has(category_id) else "other"


static func storage_category_label_key(category_id: String) -> StringName:
	return StringName("ui.stash.category.%s" % category_id if STORAGE_CATEGORY_ORDER.has(category_id) else "ui.stash.category.other")


static func storage_category_short_label_key(category_id: String) -> StringName:
	return StringName("ui.stash.category_short.%s" % category_id if STORAGE_CATEGORY_ORDER.has(category_id) else "ui.stash.category_short.other")


static func stat_rows(owner: Control, item: ItemDef) -> Array[Dictionary]:
	return (inspection_state(owner, item).get("codex_stat_rows", []) as Array).duplicate(true)


static func inspection_state(owner: Control, item: ItemDef) -> Dictionary:
	if item == null:
		return {}
	return ItemInspectionSnapshotBuilderScript.build(owner, item.to_stack(1))


static func info_lines(owner: Control, item: ItemDef) -> Array[String]:
	var values: Array = inspection_state(owner, item).get("codex_info_lines", []) as Array
	var lines: Array[String] = []
	for value in values:
		lines.append(str(value))
	return lines


static func item_type_color(item_type: String) -> Color:
	return UISurfacePaletteScript.codex_category_color(item_type)


static func codex_category_color(item: ItemDef) -> Color:
	return UISurfacePaletteScript.codex_category_color(codex_category_id(item))
