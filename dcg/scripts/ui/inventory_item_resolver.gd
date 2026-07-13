class_name InventoryItemResolver
extends RefCounted

const ITEM_ROOT_PATH := "res://data/items"

var _item_by_path: Dictionary = {}
var _item_by_catalog: Dictionary = {}
var _item_by_id: Dictionary = {}


func item_def_from_stack(stack: Dictionary) -> ItemDef:
	var path := str(stack.get("resource_path", stack.get("item_path", ""))).strip_edges()
	if path != "":
		return _load_item_from_path(path)

	var catalog_number := int(stack.get("catalog_number", 0))
	var item_id := StringName(str(stack.get("id", stack.get("item_id", ""))))
	if item_id != &"" and _item_by_id.has(str(item_id)):
		return _item_by_id.get(str(item_id), null) as ItemDef
	if catalog_number > 0 and _item_by_catalog.has(catalog_number):
		return _item_by_catalog.get(catalog_number, null) as ItemDef
	return _find_item_def(ITEM_ROOT_PATH, catalog_number, item_id)


func _load_item_from_path(path: String) -> ItemDef:
	var normalized_path := path.strip_edges()
	if normalized_path == "":
		return null
	if _item_by_path.has(normalized_path):
		return _item_by_path.get(normalized_path, null) as ItemDef
	if not ResourceLoader.exists(normalized_path):
		return null
	var item_from_path := load(normalized_path) as ItemDef
	return _cache_item_def(item_from_path, normalized_path)


func _cache_item_def(item_def: ItemDef, path: String = "") -> ItemDef:
	if item_def == null:
		return null
	var normalized_path := path.strip_edges()
	if normalized_path != "":
		_item_by_path[normalized_path] = item_def
	if item_def.catalog_number > 0:
		_item_by_catalog[item_def.catalog_number] = item_def
	if item_def.id != &"":
		_item_by_id[str(item_def.id)] = item_def
	return item_def


func _find_item_def(path: String, catalog_number: int, item_id: StringName) -> ItemDef:
	var dir := DirAccess.open(path)
	if dir == null:
		return null

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue

		var full_path := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			var nested_item := _find_item_def(full_path, catalog_number, item_id)
			if nested_item != null:
				dir.list_dir_end()
				return nested_item
		elif entry.ends_with(".tres") or entry.ends_with(".res"):
			var item := load(full_path) as ItemDef
			if item != null:
				_cache_item_def(item, full_path)
			if item != null and (item.catalog_number == catalog_number or item.id == item_id):
				dir.list_dir_end()
				return item

		entry = dir.get_next()
	dir.list_dir_end()
	return null
