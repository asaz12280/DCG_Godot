class_name ItemStackTooltipPresenter
extends RefCounted

const ItemCodexCatalogScript := preload("res://scripts/ui/item_codex_catalog.gd")
const ItemCodexPresenterScript := preload("res://scripts/ui/item_codex_presenter.gd")
const ItemInspectionSnapshotBuilderScript := preload("res://scripts/ui/item_inspection_snapshot_builder.gd")

static var _codex_catalog: RefCounted = null


static func build(owner: Control, stack: Dictionary, context: Dictionary = {}) -> Dictionary:
	var state := ItemInspectionSnapshotBuilderScript.build(owner, stack, context)
	if state.is_empty():
		return {}
	var item_def := _load_item_from_stack(stack)
	state["catalog_number"] = _display_catalog_number(stack, item_def)
	state["codex_category_id"] = ItemCodexPresenterScript.codex_category_id(item_def)
	state["codex_category_name"] = ItemCodexPresenterScript.codex_category_name(owner, item_def) if item_def != null else _localized_text(owner, &"codex_category.other", "Other")
	return state


static func tooltip_text(tooltip: Dictionary) -> String:
	if tooltip.is_empty():
		return ""
	var parts: Array[String] = [str(tooltip.get("title", ""))]
	for line in tooltip.get("lines", []) as Array:
		var line_text := str(line).strip_edges()
		if line_text != "":
			parts.append(line_text)
	return "\n".join(parts)


static func _load_item_from_stack(stack: Dictionary) -> ItemDef:
	var item_path := str(stack.get("resource_path", stack.get("item_path", ""))).strip_edges()
	if item_path == "" or not ResourceLoader.exists(item_path):
		return null
	return load(item_path) as ItemDef


static func _display_catalog_number(stack: Dictionary, item_def: ItemDef) -> int:
	var catalog := _get_codex_catalog()
	if catalog != null and item_def != null:
		var display_slot := int(catalog.call("display_slot_for_item_id", item_def.id))
		if display_slot > 0:
			return display_slot
	if catalog != null:
		var authored_number := int(stack.get("catalog_number", item_def.catalog_number if item_def != null else 0))
		var display_from_authored := int(catalog.call("display_slot_for_catalog_number", authored_number))
		if display_from_authored > 0:
			return display_from_authored
	return int(stack.get("catalog_number", item_def.catalog_number if item_def != null else 0))


static func _get_codex_catalog() -> RefCounted:
	if _codex_catalog == null:
		_codex_catalog = ItemCodexCatalogScript.new()
		_codex_catalog.call("reload")
	return _codex_catalog


static func _localized_text(owner: Control, key: StringName, fallback: String) -> String:
	var translated := owner.tr(str(key))
	return fallback if translated == "" or translated == str(key) else translated
