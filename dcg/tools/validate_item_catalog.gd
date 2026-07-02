extends SceneTree

# // Validates the early item catalog data from command line Godot runs. //
const ITEM_ROOT_PATH := "res://data/items"

var _items_by_number: Dictionary = {}
var _errors: Array[String] = []


func _initialize() -> void:
	_collect_items(ITEM_ROOT_PATH)
	_validate_numbers()
	_validate_item_fields()
	_validate_v2_proof_items()
	if _errors.is_empty():
		print("[item_catalog] OK items=%d max_no=%d" % [_items_by_number.size(), _highest_number()])
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _collect_items(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		_errors.append("Missing item directory: %s" % path)
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
			if item == null:
				_errors.append("Cannot load ItemDef: %s" % full_path)
			elif _items_by_number.has(item.catalog_number):
				_errors.append("Duplicate catalog number No.%d at %s" % [item.catalog_number, full_path])
			else:
				_items_by_number[item.catalog_number] = {"item": item, "path": full_path}
		entry = dir.get_next()
	dir.list_dir_end()


func _validate_numbers() -> void:
	if _items_by_number.is_empty():
		_errors.append("No item resources found.")
		return
	for number in range(1, _highest_number() + 1):
		if not _items_by_number.has(number):
			_errors.append("Missing catalog number No.%d" % number)


func _validate_item_fields() -> void:
	for number in _items_by_number.keys():
		var entry := _items_by_number[number] as Dictionary
		var item := entry.get("item") as ItemDef
		var path := str(entry.get("path", ""))
		if item.id == &"":
			_errors.append("Missing id at %s" % path)
		if item.name_key == &"":
			_errors.append("Missing name_key at %s" % path)
		if item.description_key == &"":
			_errors.append("Missing description_key at %s" % path)
		if item.weight < 0.0:
			_errors.append("Negative weight at %s" % path)
		if item.value < 0:
			_errors.append("Negative value at %s" % path)
		if item.max_stack < 1:
			_errors.append("Invalid max_stack at %s" % path)
		if item.tags.has(&"gun") and item.damage <= 0:
			_errors.append("Gun item is missing damage at %s" % path)


func _validate_v2_proof_items() -> void:
	_validate_catalog_item(5, &"pistol_9mm", "手槍-S")
	_validate_catalog_item(7, &"ammo_9mm", "彈藥-S")


func _validate_catalog_item(number: int, expected_id: StringName, expected_display_name: String) -> void:
	if not _items_by_number.has(number):
		return
	var entry := _items_by_number[number] as Dictionary
	var item := entry.get("item") as ItemDef
	var path := str(entry.get("path", ""))
	if item.id != expected_id:
		_errors.append("Catalog No.%d should be %s, got %s at %s." % [number, expected_id, item.id, path])
	if item.display_name != expected_display_name:
		_errors.append("Catalog No.%d display name should stay %s, got %s at %s." % [number, expected_display_name, item.display_name, path])


func _highest_number() -> int:
	var highest := 0
	for number in _items_by_number.keys():
		highest = maxi(highest, int(number))
	return highest
