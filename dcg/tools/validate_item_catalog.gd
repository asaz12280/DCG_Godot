extends SceneTree

# // Validates the early item catalog data from command line Godot runs. //
const ITEM_ROOT_PATH := "res://data/items"

var _items_by_number: Dictionary = {}
var _all_item_entries: Array[Dictionary] = []
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
			else:
				_all_item_entries.append({"item": item, "path": full_path})
			if item == null or item.catalog_number < 1:
				entry = dir.get_next()
				continue
			if _items_by_number.has(item.catalog_number):
				_errors.append("Duplicate catalog number No.%d at %s" % [item.catalog_number, full_path])
			else:
				_items_by_number[item.catalog_number] = {"item": item, "path": full_path}
		entry = dir.get_next()
	dir.list_dir_end()


func _validate_numbers() -> void:
	if _items_by_number.is_empty():
		_errors.append("No visible item resources found.")


func _validate_item_fields() -> void:
	for entry in _all_item_entries:
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
		if item.item_type == "key" and item.max_stack != 1:
			_errors.append("Key item should be non-stackable at %s" % path)
		if item.item_type == "key" and item.get_max_stack() != 1:
			_errors.append("Key item effective max stack should be 1 at %s" % path)
		if item.tags.has(&"gun") and item.damage <= 0:
			_errors.append("Gun item is missing damage at %s" % path)
		if item.tags.has(&"gun") and item.max_durability <= 0:
			_errors.append("Gun item is missing durability at %s" % path)
		if item.tags.has(&"gun") and item.weapon_vertical_recoil < 0.0:
			_errors.append("Gun item has invalid negative vertical recoil at %s" % path)
		if item.tags.has(&"gun") and item.weapon_horizontal_recoil < 0.0:
			_errors.append("Gun item has invalid negative horizontal recoil at %s" % path)
		if item.item_type == "armor" and item.max_durability <= 0:
			_errors.append("Armor item is missing durability at %s" % path)
		if item.max_durability > 0 and item.repair_max_durability_loss <= 0:
			_errors.append("Repairable item is missing max durability repair wear at %s" % path)
		if item.item_type == "ammo" and item.weapon_wear_rate <= 0.0:
			_errors.append("Ammo item is missing positive weapon wear rate at %s" % path)
		if item.item_type == "ammo" and item.ammo_spread_multiplier <= 0.0:
			_errors.append("Ammo item is missing positive spread multiplier at %s" % path)
		if item.item_type == "ammo" and item.ammo_recoil_multiplier <= 0.0:
			_errors.append("Ammo item is missing positive recoil multiplier at %s" % path)


func _validate_v2_proof_items() -> void:
	_validate_catalog_item(11, &"warehouse_key", "")
	_validate_catalog_item(8, &"basic_helmet", "")
	_validate_catalog_item(9, &"light_armor", "")
	_validate_catalog_item(5, &"pistol_9mm", "手槍-S")
	_validate_catalog_item(7, &"ammo_9mm", "彈藥-S")


	_validate_required_catalog_item(12, &"junk")
	_validate_required_catalog_item(13, &"cash")
	_validate_required_catalog_item(14, &"stamina_potion")
	_validate_required_catalog_item(16, &"life_totem")
	_validate_required_catalog_item(17, &"tactical_headset")
	_validate_required_catalog_item(18, &"tactical_glasses")
	_validate_required_catalog_item(19, &"defense_totem")
	_validate_required_catalog_item(20, &"smg_9mm")


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


func _validate_required_catalog_item(number: int, expected_id: StringName) -> void:
	if not _items_by_number.has(number):
		_errors.append("Catalog No.%d should be occupied by %s." % [number, expected_id])
		return
	var entry := _items_by_number[number] as Dictionary
	var item := entry.get("item") as ItemDef
	var path := str(entry.get("path", ""))
	if item.id != expected_id:
		_errors.append("Catalog No.%d should be %s, got %s at %s." % [number, expected_id, item.id, path])


func _highest_number() -> int:
	var highest := 0
	for number in _items_by_number.keys():
		highest = maxi(highest, int(number))
	return highest
