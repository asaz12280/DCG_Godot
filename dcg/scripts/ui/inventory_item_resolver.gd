class_name InventoryItemResolver
extends RefCounted

const ITEM_ROOT_PATH := "res://data/items"


func item_def_from_stack(stack: Dictionary) -> ItemDef:
	var path := str(stack.get("resource_path", ""))
	if path != "":
		var item_from_path := load(path) as ItemDef
		if item_from_path != null:
			return item_from_path

	var catalog_number := int(stack.get("catalog_number", 0))
	var item_id := StringName(str(stack.get("id", "")))
	return _find_item_def(ITEM_ROOT_PATH, catalog_number, item_id)


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
			if item != null and (item.catalog_number == catalog_number or item.id == item_id):
				dir.list_dir_end()
				return item

		entry = dir.get_next()
	dir.list_dir_end()
	return null
