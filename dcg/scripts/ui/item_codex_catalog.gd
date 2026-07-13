class_name ItemCodexCatalog
extends RefCounted

const ItemCodexPresenterScript := preload("res://scripts/ui/item_codex_presenter.gd")

var root_path := "res://data/items"
var item_by_number: Dictionary = {}
var item_by_catalog_number: Dictionary = {}
var item_by_id: Dictionary = {}
var item_by_path: Dictionary = {}
var _items: Array[ItemDef] = []


func reload() -> void:
	item_by_number.clear()
	item_by_catalog_number.clear()
	item_by_id.clear()
	item_by_path.clear()
	_items.clear()
	_collect_items(root_path)
	_items.sort_custom(_sort_items_by_codex_category)
	for index in range(_items.size()):
		var item := _items[index]
		item_by_number[index + 1] = item
		item_by_catalog_number[item.catalog_number] = item
		item_by_id[item.id] = item
		item_by_path[item.resource_path] = item


func highest_catalog_number() -> int:
	return item_by_number.size()


func item_count() -> int:
	return _items.size()


func has_item(catalog_number: int) -> bool:
	return item_by_number.has(catalog_number)


func get_item(catalog_number: int) -> ItemDef:
	return item_by_number.get(catalog_number, null) as ItemDef


func get_item_by_catalog_number(catalog_number: int) -> ItemDef:
	return item_by_catalog_number.get(catalog_number, null) as ItemDef


func get_item_by_id(item_id: StringName) -> ItemDef:
	return item_by_id.get(item_id, null) as ItemDef


func get_item_by_path(item_path: String) -> ItemDef:
	return item_by_path.get(item_path, null) as ItemDef


func all_items() -> Array[ItemDef]:
	return _items.duplicate()


func storage_category_id_for_path(item_path: String) -> String:
	return ItemCodexPresenterScript.storage_category_id(get_item_by_path(item_path))


func display_slot_for_item_id(item_id: StringName) -> int:
	for number in item_by_number.keys():
		var item := item_by_number.get(number) as ItemDef
		if item != null and item.id == item_id:
			return int(number)
	return 0


func display_slot_for_catalog_number(catalog_number: int) -> int:
	for number in item_by_number.keys():
		var item := item_by_number.get(number) as ItemDef
		if item != null and item.catalog_number == catalog_number:
			return int(number)
	return 0


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
			if item != null and item.catalog_number > 0:
				_items.append(item)
		entry = dir.get_next()
	dir.list_dir_end()


func _sort_items_by_codex_category(a: ItemDef, b: ItemDef) -> bool:
	var category_a := ItemCodexPresenterScript.codex_category_sort_order(a)
	var category_b := ItemCodexPresenterScript.codex_category_sort_order(b)
	if category_a != category_b:
		return category_a < category_b
	var number_a := a.catalog_number if a.catalog_number > 0 else 999999
	var number_b := b.catalog_number if b.catalog_number > 0 else 999999
	if number_a != number_b:
		return number_a < number_b
	var id_a := str(a.id)
	var id_b := str(b.id)
	if id_a != id_b:
		return id_a < id_b
	return a.resource_path < b.resource_path
