extends SceneTree

const StashModelScript := preload("res://scripts/base/stash_model.gd")
const Wood := preload("res://data/items/crafting/wood.tres")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_add_merge_and_remove()
	_validate_save_round_trip()
	_validate_invalid_entries()
	if _errors.is_empty():
		print("[stash_model] OK add=merge remove=works save=round_trip")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_add_merge_and_remove() -> void:
	var stash := StashModelScript.new()
	if not stash.add_item(Wood, 23):
		_errors.append("StashModel should accept valid stackable items.")
	if stash.get_stack_count() != 2:
		_errors.append("Wood quantity 23 should split into two stacks with max_stack 20.")
	if stash.get_item_quantity(Wood) != 23:
		_errors.append("Wood quantity should report the total across stacks.")
	if not stash.remove_item(Wood, 5):
		_errors.append("StashModel should remove a partial quantity.")
	if stash.get_item_quantity(Wood) != 18:
		_errors.append("Wood quantity should decrease after removal.")
	if stash.remove_item(Wood, 99):
		_errors.append("StashModel should reject removing more than available.")
	if not stash.add_item(Pistol, 2):
		_errors.append("StashModel should accept valid unstackable items.")
	if stash.get_item_quantity(Pistol) != 2:
		_errors.append("Unstackable item quantity should be tracked across stacks.")


func _validate_save_round_trip() -> void:
	var source := StashModelScript.new()
	source.add_item(Wood, 23)
	source.add_item(Pistol, 2)
	var save_data := source.to_save_data()
	if save_data.is_empty():
		_errors.append("StashModel should serialize non-empty stash data.")

	var loaded := StashModelScript.new()
	if not loaded.load_save_data(save_data):
		_errors.append("StashModel should load its own save data.")
	if loaded.get_item_quantity(Wood) != 23:
		_errors.append("Round trip should preserve wood quantity.")
	if loaded.get_item_quantity(Pistol) != 2:
		_errors.append("Round trip should preserve pistol quantity.")


func _validate_invalid_entries() -> void:
	var stash := StashModelScript.new()
	if stash.add_item(null, 1):
		_errors.append("StashModel should reject null ItemDef.")
	if stash.add_item(Wood, 0):
		_errors.append("StashModel should reject zero quantity.")
	var loaded_all := stash.load_save_data([
		{"item_path": "res://data/items/crafting/wood.tres", "quantity": 2},
		{"item_path": "res://data/items/missing_item.tres", "quantity": 1},
	])
	if loaded_all:
		_errors.append("StashModel should report invalid save entries.")
	if stash.get_item_quantity(Wood) != 2:
		_errors.append("Valid save entries should still load when later entries are invalid.")
