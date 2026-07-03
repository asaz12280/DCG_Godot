extends SceneTree

const RaidLossRulesScript := preload("res://scripts/raid/raid_loss_rules.gd")
const RaidResultApplierScript := preload("res://scripts/raid/raid_result_applier.gd")
const RaidResultScript := preload("res://scripts/raid/raid_result.gd")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const WoodItem := preload("res://data/items/crafting/wood.tres")
const AmmoItem := preload("res://data/items/ammo/ammo_9mm.tres")
const PistolItem := preload("res://data/items/weapons/pistol_9mm.tres")

const VALIDATION_SAVE_ROOT := "user://validation_raid_loss_rules"

var _errors: Array[String] = []


class FakePlayer:
	extends Node3D

	var inventory_model := InventoryModel.new()
	var safe_pocket_model := InventoryModel.new()
	var equipment_model := EquipmentModel.new()

	func _init() -> void:
		inventory_model.setup(12)
		safe_pocket_model.setup(2)

	func get_inventory_model() -> InventoryModel:
		return inventory_model

	func get_safe_pocket_model() -> InventoryModel:
		return safe_pocket_model

	func get_equipment_model() -> RefCounted:
		return equipment_model


func _initialize() -> void:
	_validate_loss_context_from_player()
	await _validate_death_applier_clears_raid_inventory_only()
	_validate_source_boundaries()
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	if _errors.is_empty():
		print("[raid_loss_rules] OK lost=backpack_equipment kept=safe_pocket stash=unchanged boundaries=clean")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_loss_context_from_player() -> void:
	var player := FakePlayer.new()
	player.inventory_model.add_item(WoodItem, 3)
	player.safe_pocket_model.add_item(AmmoItem, 8)
	player.equipment_model.equip_item(&"sidearm", PistolItem)
	var context: Dictionary = RaidLossRulesScript.build_death_context_from_player(player)
	var lost_items: Array = context.get("lost_items", []) as Array
	var kept_items: Array = context.get("kept_safe_pocket_items", []) as Array
	if _stack_quantity(lost_items, WoodItem.resource_path) != 3:
		_errors.append("Death loss rules should list backpack items as lost.")
	if _stack_quantity(lost_items, PistolItem.resource_path) != 1:
		_errors.append("Death loss rules should list equipped items as lost.")
	if _stack_quantity(kept_items, AmmoItem.resource_path) != 8:
		_errors.append("Death loss rules should return safe pocket items.")
	if str(context.get("loss_rule", "")) != "backpack_equipment_lost_safe_pocket_returned":
		_errors.append("Death loss context should identify the applied loss rule.")
	var result := RaidResultScript.create(RaidResultScript.OUTCOME_DEAD, context)
	if not RaidResultScript.is_serializable(result):
		_errors.append("Death loss result should be serializable and not contain player or item objects.")
	player.free()


func _validate_death_applier_clears_raid_inventory_only() -> void:
	var save_manager := root.get_node_or_null("SaveGameManager")
	var created_save_manager := false
	if save_manager == null:
		save_manager = SaveGameManagerScript.new()
		save_manager.name = "SaveGameManager"
		root.add_child(save_manager)
		created_save_manager = true
	save_manager.save_root_path = VALIDATION_SAVE_ROOT
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	save_manager.save_slot_data(1, {
		"difficulty_id": "normal",
		"money": 5,
		"stash": [{"item_path": AmmoItem.resource_path, "quantity": 2}],
		"base_upgrades": {},
		"quests": {},
	})

	var test_root := Node3D.new()
	root.add_child(test_root)
	var player := FakePlayer.new()
	player.name = "Player3D"
	player.inventory_model.add_item(WoodItem, 2)
	player.safe_pocket_model.add_item(AmmoItem, 6)
	player.equipment_model.equip_item(&"sidearm", PistolItem)
	test_root.add_child(player)

	var applier := RaidResultApplierScript.new()
	applier.name = "RaidResultApplier"
	applier.player_path = NodePath("../Player3D")
	test_root.add_child(applier)
	await process_frame

	var context := RaidLossRulesScript.build_death_context_from_player(player)
	var result := RaidResultScript.create(RaidResultScript.OUTCOME_DEAD, context)
	if not bool(applier.apply_raid_result(result)):
		_errors.append("RaidResultApplier should accept death results.")
	if not bool(applier.last_apply_result.get("death_loss", false)):
		_errors.append("RaidResultApplier should mark death loss application.")
	if player.inventory_model.get_used_slots() != 0:
		_errors.append("Death result should clear temporary raid backpack inventory.")
	if player.safe_pocket_model.get_used_slots() != 0:
		_errors.append("Death result should clear temporary safe pocket after returning it to base.")
	if not player.equipment_model.is_empty(&"sidearm"):
		_errors.append("Death result should clear temporary raid equipment.")
	var saved_after: Dictionary = save_manager.get_slot_data(1)
	var stash: Array = saved_after.get("stash", []) as Array
	if _stack_quantity(stash, WoodItem.resource_path) != 0:
		_errors.append("Death should not move lost backpack items to base stash.")
	if _stack_quantity(stash, PistolItem.resource_path) != 0:
		_errors.append("Death should not move equipped lost items to base stash.")
	if _stack_quantity(stash, AmmoItem.resource_path) != 8:
		_errors.append("Death should preserve existing base stash and return safe pocket items.")
	if int(saved_after.get("money", 0)) != 5:
		_errors.append("Death applier should not alter saved money.")

	_free_node(test_root)
	if created_save_manager:
		_free_node(save_manager)


func _validate_source_boundaries() -> void:
	var loss_source := FileAccess.get_file_as_string("res://scripts/raid/raid_loss_rules.gd")
	for required in ["collect_backpack_items", "collect_equipment_items", "collect_safe_pocket_items", "lost_items", "kept_safe_pocket_items"]:
		if not loss_source.contains(required):
			_errors.append("RaidLossRules should keep loss term: %s." % required)
	for forbidden in ["RaidResultPanel", "SaveGameManager", "change_scene", "EnemyController3D"]:
		if loss_source.contains(forbidden):
			_errors.append("RaidLossRules should not depend on UI, save, scene flow, or enemy logic: %s." % forbidden)

	var applier_source := FileAccess.get_file_as_string("res://scripts/raid/raid_result_applier.gd")
	if not applier_source.contains("OUTCOME_DEAD") or not applier_source.contains("_clear_player_inventory"):
		_errors.append("RaidResultApplier should handle dead outcome through inventory cleanup.")
	for forbidden in ["RaidResultPanel", "change_scene_to_file", "QuestTopMenuPanel"]:
		if applier_source.contains(forbidden):
			_errors.append("RaidResultApplier should not own UI or scene transition flow: %s." % forbidden)


func _stack_quantity(stacks: Array, item_path: String) -> int:
	var total := 0
	for entry in stacks:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stack := entry as Dictionary
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


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
