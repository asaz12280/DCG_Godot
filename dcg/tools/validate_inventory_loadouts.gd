extends SceneTree

const LOADOUT_PATHS: Array[String] = [
	"res://data/inventory/starter_inventory.tres",
]

var _errors: Array[String] = []


func _initialize() -> void:
	for path in LOADOUT_PATHS:
		_validate_loadout(path)
	if _errors.is_empty():
		print("[inventory_loadouts] OK loadouts=%d" % LOADOUT_PATHS.size())
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_loadout(path: String) -> void:
	var loadout := load(path)
	if loadout == null:
		_errors.append("Cannot load InventoryLoadout: %s" % path)
		return
	if not loadout.has_method("get_entry_count") or not loadout.has_method("get_item_path") or not loadout.has_method("get_quantity"):
		_errors.append("Resource is not an inventory loadout: %s" % path)
		return
	var item_paths: PackedStringArray = loadout.get("item_paths")
	var quantities: PackedInt32Array = loadout.get("quantities")
	if item_paths.size() != quantities.size():
		_errors.append("Mismatched item_paths and quantities at %s" % path)
	for index in range(loadout.get_entry_count()):
		var item_path := str(loadout.get_item_path(index))
		var item := load(item_path) as ItemDef
		if item == null:
			_errors.append("Invalid item path at %s[%d]: %s" % [path, index, item_path])
		if loadout.get_quantity(index) < 1:
			_errors.append("Invalid quantity at %s[%d]" % [path, index])
