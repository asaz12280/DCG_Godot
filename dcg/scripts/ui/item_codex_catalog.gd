class_name ItemCodexCatalog
extends RefCounted

var root_path := "res://data/items"
var item_by_number: Dictionary = {}


func reload() -> void:
	item_by_number.clear()
	_collect_items(root_path)


func highest_catalog_number() -> int:
	var highest_number := 0
	for number in item_by_number.keys():
		highest_number = maxi(highest_number, int(number))
	return highest_number


func has_item(catalog_number: int) -> bool:
	return item_by_number.has(catalog_number)


func get_item(catalog_number: int) -> ItemDef:
	return item_by_number.get(catalog_number, null) as ItemDef


func _collect_items(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full_path := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			_collect_items(full_path)
		elif entry.ends_with(".tres") or entry.ends_with(".res"):
			var item := load(full_path) as ItemDef
			if item != null and item.catalog_number >= 1:
				item_by_number[item.catalog_number] = item
		entry = dir.get_next()
	dir.list_dir_end()
