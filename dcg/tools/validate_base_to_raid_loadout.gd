extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const Pistol := preload("res://data/items/weapons/pistol_S.tres")
const Ammo := preload("res://data/items/ammo/ammo_S.tres")

var _errors: Array[String] = []
var _save_manager: Node = null


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_save_manager = _ensure_save_manager()
	if _save_manager != null and _save_manager.has_method("consume_pending_raid_loadout"):
		_save_manager.call("consume_pending_raid_loadout")
	await _validate_base_prepares_pending_loadout()
	_validate_source_boundaries()
	if _errors.is_empty():
		print("[base_to_raid_loadout] OK base=prepares_pending raid=consumes backpack=ammo equipment=pistol weapon=synced")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_base_prepares_pending_loadout() -> void:
	var base_scene := Base3DScene.instantiate()
	root.add_child(base_scene)
	current_scene = base_scene
	await process_frame
	await process_frame

	var base_player := base_scene.get_node_or_null("Player3D")
	var controller := base_scene.get_node_or_null("BaseInteractionController3D")
	if base_player == null or controller == null:
		_errors.append("Base scene should expose Player3D and BaseInteractionController3D.")
		_free_node(base_scene)
		return

	var base_inventory: InventoryModel = base_player.call("get_inventory_model")
	base_inventory.clear()
	base_inventory.setup(int(base_player.call("get_total_backpack_slots")))
	base_inventory.add_stack(_damaged_pistol_stack(43, 86))
	base_inventory.add_item(Ammo, 24)
	if not bool(base_player.call("equip_inventory_stack", 0)):
		_errors.append("Base player should equip No.5 pistol before raid loadout capture.")
	await process_frame

	if not bool(controller.call("prepare_raid_loadout")):
		_errors.append("Base interaction controller should prepare a pending raid loadout before scene change.")
	var pending: Dictionary = _save_manager.call("peek_pending_raid_loadout") if _save_manager != null and _save_manager.has_method("peek_pending_raid_loadout") else {}
	_validate_pending_loadout(pending)
	_free_node(base_scene)
	await process_frame

	var gameplay_scene := GameplayScene.instantiate()
	root.add_child(gameplay_scene)
	current_scene = gameplay_scene
	await process_frame
	await process_frame

	var raid_player := gameplay_scene.get_node_or_null("Player3D")
	if raid_player == null:
		_errors.append("Raid scene should expose Player3D.")
		_free_node(gameplay_scene)
		return
	_validate_raid_player_loadout(raid_player)
	if _save_manager != null and bool(_save_manager.call("has_pending_raid_loadout")):
		_errors.append("Pending raid loadout should be consumed after raid player spawns.")
	_free_node(gameplay_scene)


func _validate_pending_loadout(loadout: Dictionary) -> void:
	if loadout.is_empty():
		_errors.append("Prepared loadout should be stored on SaveGameManager.")
		return
	if str(loadout.get("source", "")) != "base_3d":
		_errors.append("Prepared loadout should record base_3d as source.")
	if not _stack_array_has(loadout.get("backpack", []), 7):
		_errors.append("Prepared loadout backpack should include No.7 ammo.")
	if _stack_array_has(loadout.get("backpack", []), 5):
		_errors.append("Prepared loadout backpack should not duplicate equipped No.5 pistol.")
	if not _equipment_data_has(loadout.get("equipment", {}), &"primary_weapon", 5):
		_errors.append("Prepared loadout equipment should include No.5 pistol in primary weapon.")
	if not _equipment_data_has_durability(loadout.get("equipment", {}), &"primary_weapon", 43, 86):
		_errors.append("Prepared loadout equipment should preserve No.5 pistol durability.")


func _validate_raid_player_loadout(player: Node) -> void:
	var inventory: InventoryModel = player.call("get_inventory_model")
	var equipment: RefCounted = player.call("get_equipment_model")
	var weapon := player.get_node_or_null("WeaponController3D")
	if not _stack_array_has(inventory.get_display_items(), 7):
		_errors.append("Raid player backpack should receive No.7 ammo from the 3D Base loadout.")
	if _stack_array_has(inventory.get_display_items(), 5):
		_errors.append("Raid player backpack should not duplicate the equipped No.5 pistol.")
	var primary_weapon: Dictionary = equipment.call("get_slot", &"primary_weapon")
	if int(primary_weapon.get("catalog_number", 0)) != 5:
		_errors.append("Raid player primary weapon should receive equipped No.5 pistol from the 3D Base loadout.")
	if int(primary_weapon.get("current_durability", 0)) != 43 or int(primary_weapon.get("max_durability", 0)) != 86:
		_errors.append("Raid player primary weapon should preserve carried-in durability.")
	if weapon == null or weapon.get("weapon_def") == null or int(weapon.get("weapon_def").get("catalog_number")) != 5:
		_errors.append("Raid weapon controller should sync to the carried-in No.5 pistol.")


func _validate_source_boundaries() -> void:
	var base_controller := FileAccess.get_file_as_string("res://scripts/base/base_interaction_controller_3d.gd")
	for required in ["RaidLoadoutTransferScript", "prepare_raid_loadout", "set_pending_raid_loadout"]:
		if not base_controller.contains(required):
			_errors.append("BaseInteractionController3D should prepare raid loadout through %s." % required)
	for forbidden in ["add_item_resource", "equip_inventory_stack(", "reload_equipped_weapon"]:
		if base_controller.contains(forbidden):
			_errors.append("BaseInteractionController3D should not mutate backpack/equipment/combat directly through %s." % forbidden)

	var player_source := FileAccess.get_file_as_string("res://scripts/player/player_controller_3d.gd")
	for required in ["consume_pending_raid_loadout", "RaidLoadoutTransferScript.apply_to_player", "_load_starter_inventory"]:
		if not player_source.contains(required):
			_errors.append("PlayerController3D should load pending raid loadout before starter fallback through %s." % required)

	var transfer_source := FileAccess.get_file_as_string("res://scripts/raid/raid_loadout_transfer.gd")
	for forbidden in ["Control", "Button", "change_scene", "BaseInteractionController3D", "LootContainer3D"]:
		if transfer_source.contains(forbidden):
			_errors.append("RaidLoadoutTransfer should stay data-only and independent from %s." % forbidden)

	var gameplay_scene := FileAccess.get_file_as_string("res://scenes/gameplay/player_test_world_3d.tscn")
	for forbidden in ["pistol_S.tres", "ammo_S.tres", "starter_inventory.tres"]:
		if gameplay_scene.contains(forbidden):
			_errors.append("Raid scene should not hardwire loadout item resource %s." % forbidden)


func _stack_array_has(value: Variant, catalog_number: int) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	for stack_value in value as Array:
		if typeof(stack_value) == TYPE_DICTIONARY and int((stack_value as Dictionary).get("catalog_number", 0)) == catalog_number:
			return true
		if typeof(stack_value) == TYPE_DICTIONARY:
			var item_path := str((stack_value as Dictionary).get("item_path", ""))
			var item := load(item_path) as ItemDef if item_path != "" and ResourceLoader.exists(item_path) else null
			if item != null and item.catalog_number == catalog_number:
				return true
	return false


func _equipment_data_has(value: Variant, slot_id: StringName, catalog_number: int) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var slots: Dictionary = (value as Dictionary).get("slots", {})
	var slot_value: Variant = slots.get(str(slot_id), {})
	if typeof(slot_value) != TYPE_DICTIONARY:
		return false
	var item_path := str((slot_value as Dictionary).get("item_path", ""))
	var item := load(item_path) as ItemDef if item_path != "" and ResourceLoader.exists(item_path) else null
	return item != null and item.catalog_number == catalog_number


func _equipment_data_has_durability(value: Variant, slot_id: StringName, current: int, maximum: int) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var slots: Dictionary = (value as Dictionary).get("slots", {})
	var slot_value: Variant = slots.get(str(slot_id), {})
	if typeof(slot_value) != TYPE_DICTIONARY:
		return false
	var stack := slot_value as Dictionary
	return int(stack.get("current_durability", -1)) == current and int(stack.get("max_durability", -1)) == maximum


func _damaged_pistol_stack(current: int, maximum: int) -> Dictionary:
	var stack := Pistol.to_stack(1)
	stack["current_durability"] = current
	stack["max_durability"] = maximum
	stack["original_max_durability"] = Pistol.max_durability
	stack["repair_max_durability_loss"] = Pistol.repair_max_durability_loss
	return stack


func _ensure_save_manager() -> Node:
	var existing := root.get_node_or_null("SaveGameManager")
	if existing != null:
		return existing
	var manager := SaveGameManagerScript.new()
	manager.name = "SaveGameManager"
	root.add_child(manager)
	return manager


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
