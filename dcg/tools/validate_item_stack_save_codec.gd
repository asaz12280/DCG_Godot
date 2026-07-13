extends SceneTree

const ItemStackSaveCodecScript := preload("res://scripts/inventory/item_stack_save_codec.gd")
const Wood := preload("res://data/items/crafting/wood.tres")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const ExtendedMagazine := preload("res://data/items/attachments/extended_magazine.tres")

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_non_durable_save_entry_stays_compact()
	_validate_durability_round_trip()
	_validate_weapon_mods_round_trip()
	_validate_item_path_fallback()
	_validate_legacy_s_item_path_alias()
	if _errors.is_empty():
		print("[item_stack_save_codec] OK compact=non_durable durability=round_trip weapon_mods=round_trip path=fallback")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_non_durable_save_entry_stays_compact() -> void:
	var entry: Dictionary = ItemStackSaveCodecScript.to_save_entry(Wood.to_stack(3))
	if str(entry.get("item_path", "")) != Wood.resource_path:
		_errors.append("Save codec should serialize non-durable item path.")
	if int(entry.get("quantity", 0)) != 3:
		_errors.append("Save codec should serialize non-durable quantity.")
	if entry.has("current_durability") or entry.has("max_durability"):
		_errors.append("Save codec should not persist zero durability keys for non-durable items.")


func _validate_durability_round_trip() -> void:
	var damaged := Pistol.to_stack(1)
	damaged["current_durability"] = 41
	damaged["max_durability"] = 88
	damaged["original_max_durability"] = 100
	damaged["repair_max_durability_loss"] = 5
	damaged["durability_wear_progress"] = 0.5
	var entry: Dictionary = ItemStackSaveCodecScript.to_save_entry(damaged)
	if int(entry.get("current_durability", 0)) != 41 or int(entry.get("max_durability", 0)) != 88:
		_errors.append("Save codec should persist damaged durability values.")
	if absf(float(entry.get("durability_wear_progress", 0.0)) - 0.5) > 0.001:
		_errors.append("Save codec should persist fractional durability wear progress.")
	var restored: Dictionary = ItemStackSaveCodecScript.stack_from_entry(entry, Pistol, 1)
	if int(restored.get("current_durability", 0)) != 41 or int(restored.get("max_durability", 0)) != 88:
		_errors.append("Save codec should restore damaged durability values.")
	if absf(float(restored.get("durability_wear_progress", 0.0)) - 0.5) > 0.001:
		_errors.append("Save codec should restore fractional durability wear progress.")
	if int(restored.get("catalog_number", 0)) != Pistol.catalog_number:
		_errors.append("Save codec should restore the item stack from the provided ItemDef.")


func _validate_weapon_mods_round_trip() -> void:
	var modded := Pistol.to_stack(1)
	modded["weapon_mods"] = {
		"magazine": ExtendedMagazine.to_stack(1),
	}
	var entry: Dictionary = ItemStackSaveCodecScript.to_save_entry(modded)
	if not ItemStackSaveCodecScript.has_persistent_state(entry):
		_errors.append("Save codec should identify weapon_mods as persistent state.")
	var saved_mods: Dictionary = entry.get("weapon_mods", {}) as Dictionary
	var saved_magazine: Dictionary = saved_mods.get("magazine", {}) as Dictionary
	if str(saved_magazine.get("item_path", saved_magazine.get("resource_path", ""))) != ExtendedMagazine.resource_path:
		_errors.append("Save codec should persist weapon_mods entries.")
	var restored: Dictionary = ItemStackSaveCodecScript.stack_from_entry(entry, Pistol, 1)
	var restored_mods: Dictionary = restored.get("weapon_mods", {}) as Dictionary
	var restored_magazine: Dictionary = restored_mods.get("magazine", {}) as Dictionary
	if str(restored_magazine.get("item_path", restored_magazine.get("resource_path", ""))) != ExtendedMagazine.resource_path:
		_errors.append("Save codec should restore weapon_mods entries.")


func _validate_item_path_fallback() -> void:
	var path := ItemStackSaveCodecScript.get_item_path({"item_path": Pistol.resource_path, "quantity": 1})
	if path != Pistol.resource_path:
		_errors.append("Save codec should read legacy item_path entries.")


func _validate_legacy_s_item_path_alias() -> void:
	var path := ItemStackSaveCodecScript.get_item_path({"item_path": "res://data/items/weapons/pistol_9mm.tres", "quantity": 1})
	if path != Pistol.resource_path:
		_errors.append("Save codec should map legacy pistol_9mm paths to pistol_S.")
