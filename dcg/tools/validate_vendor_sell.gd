extends SceneTree

const BaseScreenScene := preload("res://scenes/base/base_screen.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const StashVendorScript := preload("res://scripts/base/stash_vendor.gd")

const JUNK_PATH := "res://data/items/loot/junk.tres"
const WATCH_PATH := "res://data/items/valuables/old_watch.tres"
const WOOD_PATH := "res://data/items/crafting/wood.tres"

var _errors: Array[String] = []
var _created_save_manager: Node = null


func _initialize() -> void:
	await _validate_vendor_rules()
	await _validate_base_sell_and_save_round_trip()
	if _errors.is_empty():
		print("[vendor_sell] OK value=item_def stash=removes_sold money=saved materials=kept")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_vendor_rules() -> void:
	var stash_data: Array = [
		{"item_path": JUNK_PATH, "quantity": 5},
		{"item_path": WATCH_PATH, "quantity": 1},
		{"item_path": WOOD_PATH, "quantity": 3},
	]
	var result: Dictionary = StashVendorScript.sell_all_junk(stash_data, 7)
	if int(result.get("money_delta", 0)) != 120:
		_errors.append("StashVendor should use ItemDef.value * quantity for sellable junk.")
	if int(result.get("money", 0)) != 127:
		_errors.append("StashVendor should add sale value to starting money.")
	var remaining: Array = result.get("remaining_stash", []) as Array
	if remaining.size() != 1 or str((remaining[0] as Dictionary).get("item_path", "")) != WOOD_PATH:
		_errors.append("StashVendor should keep crafting materials for early upgrades.")


func _validate_base_sell_and_save_round_trip() -> void:
	var save_manager := _make_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	var save_data := {
		"version": 1,
		"scene_path": SaveGameManagerScript.DEFAULT_BASE_SCENE,
		"difficulty_id": "normal",
		"money": 10,
		"stash": [
			{"item_path": JUNK_PATH, "quantity": 5},
			{"item_path": WATCH_PATH, "quantity": 1},
			{"item_path": WOOD_PATH, "quantity": 3},
		],
		"base_upgrades": {},
		"quests": {},
	}
	if not save_manager.save_slot_data(1, save_data):
		_errors.append("Validation setup should save base stash data.")
		return

	var base_screen := BaseScreenScene.instantiate()
	root.add_child(base_screen)
	await process_frame
	base_screen.refresh()
	var before_state: Dictionary = base_screen.get_display_state()
	if bool(before_state.get("sell_all_junk_disabled", true)):
		_errors.append("Base sell button should be enabled when stash has sellable junk.")

	var sale_result: Dictionary = base_screen.sell_all_junk()
	if int(sale_result.get("money_delta", 0)) != 120:
		_errors.append("BaseScreen sell_all_junk should report the sold value.")
	var after_state: Dictionary = base_screen.get_display_state()
	if not str(after_state.get("money", "")).contains("$130"):
		_errors.append("Base money label should update after selling junk.")
	if int(after_state.get("stash_rows", 0)) != 1:
		_errors.append("Base stash rows should remove sold items and keep unsold materials.")

	var loaded: Dictionary = save_manager.get_slot_data(1)
	if int(loaded.get("money", 0)) != 130:
		_errors.append("Saved slot should restore money after selling junk.")
	var loaded_stash: Array = loaded.get("stash", []) as Array
	if loaded_stash.size() != 1:
		_errors.append("Saved slot should keep only unsold stash entries.")
	elif str((loaded_stash[0] as Dictionary).get("item_path", "")) != WOOD_PATH:
		_errors.append("Saved stash should keep crafting material after selling junk.")

	_free_node(base_screen)
	_cleanup_validation_root(save_manager.save_root_path)
	_free_created_save_manager()


func _make_save_manager() -> Node:
	var existing := root.get_node_or_null("SaveGameManager")
	if existing != null:
		existing.save_root_path = "user://validation_vendor_sell"
		return existing
	var save_manager := SaveGameManagerScript.new()
	save_manager.name = "SaveGameManager"
	save_manager.save_root_path = "user://validation_vendor_sell"
	root.add_child(save_manager)
	_created_save_manager = save_manager
	return save_manager


func _cleanup_validation_root(root_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(root_path)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute("%s/slot_1.json" % absolute)
		DirAccess.remove_absolute("%s/slot_2.json" % absolute)
		DirAccess.remove_absolute("%s/slot_3.json" % absolute)
		DirAccess.remove_absolute(absolute)


func _free_created_save_manager() -> void:
	if _created_save_manager != null:
		_free_node(_created_save_manager)
		_created_save_manager = null


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
