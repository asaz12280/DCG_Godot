extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const WoodItem := preload("res://data/items/crafting/wood.tres")
const AmmoItem := preload("res://data/items/ammo/ammo_9mm.tres")
const PistolItem := preload("res://data/items/weapons/pistol_9mm.tres")

const VALIDATION_SAVE_ROOT := "user://validation_base_stash_storage_ui"
const WOOD_PATH := "res://data/items/crafting/wood.tres"
const AMMO_PATH := "res://data/items/ammo/ammo_9mm.tres"
const PISTOL_PATH := "res://data/items/weapons/pistol_9mm.tres"

var _errors: Array[String] = []
var _save_manager: Node = null
var _created_save_manager := false


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_setup_save_manager()
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait_frames(3)
	await _validate_stash_open_state(scene)
	await _validate_storage_transfers(scene)
	_free_node(scene)
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	if _created_save_manager:
		_free_node(_save_manager)
	if _errors.is_empty():
		print("[base_stash_storage_ui] OK open=warehouse_grid store=backpack/equipment/safe_pocket withdraw=backpack save=persist")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_stash_open_state(scene: Node) -> void:
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	var stash_panel := scene.get_node_or_null("HUD/BaseStashInventoryUI")
	var generic_panel := scene.get_node_or_null("HUD/BaseInteractionPanel")
	if controller == null or stash_panel == null:
		_errors.append("Base scene should expose controller and BaseStashInventoryUI.")
		return
	if not bool(controller.call("open_interaction_by_id", "stash")):
		_errors.append("Stash station should open through BaseInteractionController3D.")
		return
	await _wait_frames(2)
	var state: Dictionary = stash_panel.call("get_display_state")
	if not bool(state.get("visible", false)) or not bool(state.get("is_open", false)):
		_errors.append("Stash station should show an open storage UI.")
	if int(state.get("stash_capacity", 0)) != 250:
		_errors.append("Stash UI should expose the 250-slot warehouse capacity.")
	if not str(state.get("title", "")).contains(TranslationServer.translate("ui.base.station.stash")):
		_errors.append("Stash UI title should be localized.")
	if generic_panel != null and generic_panel.has_method("is_open") and bool(generic_panel.call("is_open")):
		_errors.append("Stash station should not show the generic station info panel.")
	stash_panel.call("close_stash")


func _validate_storage_transfers(scene: Node) -> void:
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	var player := scene.get_node_or_null("Player3D")
	var stash_panel := scene.get_node_or_null("HUD/BaseStashInventoryUI")
	if controller == null or player == null or stash_panel == null:
		return
	player.call("add_item_resource", WoodItem, 5)
	player.call("add_item_resource", PistolItem, 1)
	var inventory: InventoryModel = player.call("get_inventory_model")
	var safe_pocket: InventoryModel = player.call("get_safe_pocket_model")
	var equipment: RefCounted = player.call("get_equipment_model")
	var pistol_index := _stack_index_with_resource(inventory.get_display_items(), PISTOL_PATH)
	if pistol_index < 0 or not bool(player.call("equip_inventory_stack", pistol_index, &"sidearm")):
		_errors.append("Validation setup should equip a sidearm from the backpack.")
		return
	safe_pocket.add_item(AmmoItem, 6)

	if not bool(controller.call("open_interaction_by_id", "stash")):
		_errors.append("Stash station should open for storage transfer validation.")
		return
	await _wait_frames(2)

	var wood_index := _stack_index_with_resource(inventory.get_display_items(), WOOD_PATH)
	var stored_wood_quantity := _stack_quantity(inventory.get_display_items(), WOOD_PATH)
	if wood_index < 0 or not bool(stash_panel.call("store_backpack_stack", wood_index)):
		_errors.append("Stash UI should store a backpack stack into the warehouse.")
	var saved_after_backpack: Dictionary = _save_manager.call("get_slot_data", 1)
	if _stack_quantity(saved_after_backpack.get("stash", []) as Array, WOOD_PATH) != stored_wood_quantity:
		_errors.append("Stored backpack items should persist to save stash.")
	if _stack_quantity(inventory.get_display_items(), WOOD_PATH) != 0:
		_errors.append("Stored backpack items should leave the backpack.")

	if not bool(stash_panel.call("store_equipment_slot", &"sidearm")):
		_errors.append("Stash UI should store equipped sidearm items.")
	if not equipment.call("is_empty", &"sidearm"):
		_errors.append("Stored equipment item should clear the equipment slot.")
	var saved_after_equipment: Dictionary = _save_manager.call("get_slot_data", 1)
	if _stack_quantity(saved_after_equipment.get("stash", []) as Array, PISTOL_PATH) != 1:
		_errors.append("Stored equipment item should persist to save stash.")

	if not bool(stash_panel.call("store_safe_pocket_stack", 0)):
		_errors.append("Stash UI should store safe pocket stacks.")
	if safe_pocket.get_used_slots() != 0:
		_errors.append("Stored safe pocket item should leave the safe pocket.")
	var saved_after_safe: Dictionary = _save_manager.call("get_slot_data", 1)
	if _stack_quantity(saved_after_safe.get("stash", []) as Array, AMMO_PATH) != 10:
		_errors.append("Stored safe pocket ammo should merge with existing save stash ammo.")

	var state: Dictionary = stash_panel.call("get_display_state")
	var stash_items: Array = state.get("stash_items", []) as Array
	var stash_wood_index := _stack_index_with_resource(stash_items, WOOD_PATH)
	if stash_wood_index < 0 or not bool(stash_panel.call("withdraw_stash_stack", stash_wood_index)):
		_errors.append("Stash UI should withdraw warehouse stacks to backpack.")
	if _stack_quantity(inventory.get_display_items(), WOOD_PATH) != stored_wood_quantity:
		_errors.append("Withdrawn stash item should enter the backpack.")
	var saved_after_withdraw: Dictionary = _save_manager.call("get_slot_data", 1)
	if _stack_quantity(saved_after_withdraw.get("stash", []) as Array, WOOD_PATH) != 0:
		_errors.append("Withdrawn item should be removed from save stash.")
	stash_panel.call("close_stash")


func _setup_save_manager() -> void:
	_save_manager = root.get_node_or_null("SaveGameManager")
	if _save_manager == null:
		_save_manager = SaveGameManagerScript.new()
		_save_manager.name = "SaveGameManager"
		root.add_child(_save_manager)
		_created_save_manager = true
	_save_manager.set("save_root_path", VALIDATION_SAVE_ROOT)
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	_save_manager.call("set_current_slot_index", 1)
	_save_manager.call("save_slot_data", 1, {
		"difficulty_id": "normal",
		"money": 15,
		"stash": [{"item_path": AMMO_PATH, "quantity": 4}],
		"base_upgrades": {},
		"quests": {},
	})


func _stack_index_with_resource(stacks: Array, item_path: String) -> int:
	for index in range(stacks.size()):
		var value: Variant = stacks[index]
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("resource_path", (value as Dictionary).get("item_path", ""))) == item_path:
			return index
	return -1


func _stack_quantity(stacks: Array, item_path: String) -> int:
	var total := 0
	for value in stacks:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := value as Dictionary
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path:
			total += int(stack.get("quantity", 0))
	return total


func _cleanup_validation_root(root_path: String) -> void:
	var absolute := ProjectSettings.globalize_path(root_path)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute("%s/slot_1.json" % absolute)
		DirAccess.remove_absolute("%s/slot_2.json" % absolute)
		DirAccess.remove_absolute("%s/slot_3.json" % absolute)
		DirAccess.remove_absolute(absolute)


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
