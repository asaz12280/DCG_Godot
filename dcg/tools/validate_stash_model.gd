extends SceneTree

const StashModelScript := preload("res://scripts/base/stash_model.gd")
const Wood := preload("res://data/items/crafting/wood.tres")
const Pistol := preload("res://data/items/weapons/pistol_9mm.tres")
const ExtendedMagazine := preload("res://data/items/attachments/extended_magazine.tres")
const WarehouseKey := preload("res://data/items/keys/warehouse_key.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_add_merge_and_remove()
	_validate_save_round_trip()
	_validate_invalid_entries()
	if _errors.is_empty():
		print("[stash_model] OK add=merge remove=works save=round_trip weapon_mods=round_trip")
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
	if not stash.add_item(WarehouseKey, 2):
		_errors.append("StashModel should accept multiple keys as separate stacks.")
	if _stack_count_for_item(stash.get_stacks(), WarehouseKey.resource_path) != 2:
		_errors.append("Key items should stay non-stackable in stash storage.")


func _validate_save_round_trip() -> void:
	var source := StashModelScript.new()
	source.add_item(Wood, 23)
	source.add_item(Pistol, 1)
	source.add_stack(_damaged_pistol_stack(38, 82))
	source.add_stack(_modded_pistol_stack())
	var save_data := source.to_save_data()
	if save_data.is_empty():
		_errors.append("StashModel should serialize non-empty stash data.")
	if not _saved_stack_has_durability(save_data, Pistol.resource_path, 38, 82):
		_errors.append("StashModel save data should preserve damaged item durability.")
	if not _saved_stack_has_mod(save_data, Pistol.resource_path, ExtendedMagazine.resource_path):
		_errors.append("StashModel save data should preserve weapon attachment mods.")

	var loaded := StashModelScript.new()
	if not loaded.load_save_data(save_data):
		_errors.append("StashModel should load its own save data.")
	if loaded.get_item_quantity(Wood) != 23:
		_errors.append("Round trip should preserve wood quantity.")
	if loaded.get_item_quantity(Pistol) != 3:
		_errors.append("Round trip should preserve pistol quantity.")
	if not _loaded_stack_has_durability(loaded.get_stacks(), Pistol.resource_path, 38, 82):
		_errors.append("Round trip should preserve damaged pistol durability.")
	if not _loaded_stack_has_mod(loaded.get_stacks(), Pistol.resource_path, ExtendedMagazine.resource_path):
		_errors.append("Round trip should preserve weapon attachment mods.")


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


func _damaged_pistol_stack(current: int, maximum: int) -> Dictionary:
	var stack := Pistol.to_stack(1)
	stack["current_durability"] = current
	stack["max_durability"] = maximum
	stack["original_max_durability"] = Pistol.max_durability
	stack["repair_max_durability_loss"] = Pistol.repair_max_durability_loss
	return stack


func _modded_pistol_stack() -> Dictionary:
	var stack := Pistol.to_stack(1)
	stack["weapon_mods"] = {
		"magazine": ExtendedMagazine.to_stack(1),
	}
	return stack


func _saved_stack_has_durability(stacks: Array, item_path: String, current: int, maximum: int) -> bool:
	for value in stacks:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := value as Dictionary
		if str(stack.get("item_path", "")) == item_path and int(stack.get("current_durability", -1)) == current and int(stack.get("max_durability", -1)) == maximum:
			return true
	return false


func _saved_stack_has_mod(stacks: Array, item_path: String, mod_item_path: String) -> bool:
	for value in stacks:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := value as Dictionary
		if str(stack.get("item_path", "")) != item_path:
			continue
		var mods: Dictionary = stack.get("weapon_mods", {}) as Dictionary
		var magazine: Dictionary = mods.get("magazine", {}) as Dictionary
		if str(magazine.get("item_path", magazine.get("resource_path", ""))) == mod_item_path:
			return true
	return false


func _loaded_stack_has_durability(stacks: Array, item_path: String, current: int, maximum: int) -> bool:
	for value in stacks:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := value as Dictionary
		if str(stack.get("resource_path", "")) == item_path and int(stack.get("current_durability", -1)) == current and int(stack.get("max_durability", -1)) == maximum:
			return true
	return false


func _loaded_stack_has_mod(stacks: Array, item_path: String, mod_item_path: String) -> bool:
	for value in stacks:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := value as Dictionary
		if str(stack.get("resource_path", "")) != item_path:
			continue
		var mods: Dictionary = stack.get("weapon_mods", {}) as Dictionary
		var magazine: Dictionary = mods.get("magazine", {}) as Dictionary
		if str(magazine.get("item_path", magazine.get("resource_path", ""))) == mod_item_path:
			return true
	return false


func _stack_count_for_item(stacks: Array, item_path: String) -> int:
	var count := 0
	for value in stacks:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := value as Dictionary
		if str(stack.get("resource_path", "")) == item_path:
			count += 1
	return count
