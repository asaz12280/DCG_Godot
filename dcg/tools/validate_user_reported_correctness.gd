extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const PlayerScene := preload("res://scenes/player/player_3d.tscn")
const ScavengerScene := preload("res://scenes/enemies/scavenger_3d.tscn")
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")
const LootContainerScript := preload("res://scripts/loot/loot_container_3d.gd")
const RaidLossRulesScript := preload("res://scripts/raid/raid_loss_rules.gd")
const RaidResultApplierScript := preload("res://scripts/raid/raid_result_applier.gd")
const RaidResultScript := preload("res://scripts/raid/raid_result.gd")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")

const GAMEPLAY_SCENE := "res://scenes/gameplay/player_test_world_3d.tscn"
const VALIDATION_SAVE_ROOT := "user://validation_user_reported_correctness"
const WoodItem := preload("res://data/items/crafting/wood.tres")
const AmmoItem := preload("res://data/items/ammo/ammo_9mm.tres")
const PistolItem := preload("res://data/items/weapons/pistol_9mm.tres")

var _errors: Array[String] = []
var _save_manager: Node = null
var _created_save_manager := false


class FakeRaidPlayer:
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


class FakeLootPlayer:
	extends CharacterBody3D

	var inventory_model := InventoryModel.new()

	func _init() -> void:
		add_to_group("player")
		inventory_model.setup(24)

	func get_inventory_model() -> InventoryModel:
		return inventory_model


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_setup_save_manager()
	await _validate_raid_gate_has_no_briefing()
	_validate_english_translations_do_not_fall_back_to_chinese()
	await _validate_enemy_death_creates_f_loot_grid()
	await _validate_equipped_pistol_can_return_to_backpack()
	await _validate_safe_pocket_returns_to_base_on_death()
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	if _created_save_manager:
		_free_node(_save_manager)
	if _errors.is_empty():
		print("[user_reported_correctness] OK raid_gate=no_briefing locale=en corpse_loot=F_grid unequip=pistol safe_pocket=returns_to_base")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_raid_gate_has_no_briefing() -> void:
	var scene := Base3DScene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait_frames(3)
	if scene.get_node_or_null("HUD/RaidBriefingPanel") != null:
		_errors.append("Raid gate should not mount the removed briefing panel.")
	var controller := scene.get_node_or_null("BaseInteractionController3D")
	if controller == null:
		_errors.append("Base scene should include BaseInteractionController3D.")
		_free_current_scene()
		return
	if not bool(controller.call("open_interaction_by_id", "raid_gate")):
		_errors.append("Raid gate should directly start the raid.")
		_free_current_scene()
		return
	await _wait_frames(14)
	if current_scene == null:
		_errors.append("Raid gate should leave a loaded gameplay scene.")
	elif current_scene.scene_file_path != GAMEPLAY_SCENE:
		_errors.append("Raid gate should load gameplay, got `%s`." % current_scene.scene_file_path)
	_free_current_scene()


func _validate_english_translations_do_not_fall_back_to_chinese() -> void:
	TranslationServer.set_locale("en")
	var keys := PackedStringArray([
		"ui.base.station.raid_gate",
		"prompt.start_raid_format",
		"prompt.loot_corpse",
		"prompt.view_corpse",
		"ui.container.enemy_corpse",
		"ui.inventory.safe_pocket",
		"ui.stash.title_format",
		"ui.stash.store_hint",
		"ui.stash.ready",
		"ui.stash.saved",
		"ui.raid_result.safe_pocket_items",
		"ui.raid_result.transfer_dead",
		"ui.raid_result.status_dead",
		"ui.common.close",
		"ui.common.execute",
		"prompt.record_location",
		"prompt.location_recorded",
		"ui.top.status_armor_no_bonus",
		"ui.top.status_armor_bonus_format",
		"ui.top.status_armor_missing",
		"ui.top.status_armor_item_no_bonus_format",
		"ui.top.status_armor_item_bonus_format",
		"enemy.scavenger.name",
		"enemy.status.idle",
		"enemy.status.dead",
		"enemy.status.injured",
		"enemy.status.chase",
		"enemy.status.attack",
		"enemy.status.alert",
	])
	for key in keys:
		var translated := TranslationServer.translate(key)
		if translated == key or translated.strip_edges() == "":
			_errors.append("English localization key should be translated: %s." % key)
		elif _contains_cjk(translated):
			_errors.append("English localization key should not show Chinese text: %s -> %s." % [key, translated])
	TranslationServer.set_locale("zh_TW")


func _validate_enemy_death_creates_f_loot_grid() -> void:
	var map_root := Node3D.new()
	root.add_child(map_root)
	var enemy := ScavengerScene.instantiate()
	map_root.add_child(enemy)
	await process_frame
	var lethal := DamageEventScript.new(999.0, null, null, [&"validation"])
	enemy.call("apply_damage", lethal)
	await _wait_frames(2)
	var corpse := _first_loot_container(map_root)
	if corpse == null:
		_errors.append("Enemy death should create a lootable corpse container.")
		_free_node(map_root)
		return
	if int(corpse.get("interact_keycode")) != KEY_F:
		_errors.append("Enemy corpse should use F for looting.")
	var model: RefCounted = corpse.call("get_container_inventory_model")
	if model == null or not model.has_method("get_capacity") or int(model.call("get_capacity")) <= 0:
		_errors.append("Enemy corpse should expose a grid-like container inventory.")
	elif int(model.call("get_used_slots")) <= 0:
		_errors.append("Enemy corpse container should contain dropped item stacks.")
	var player := FakeLootPlayer.new()
	map_root.add_child(player)
	if not bool(corpse.call("try_open", player)):
		_errors.append("Enemy corpse should open through the container loot path.")
	_free_node(map_root)


func _validate_equipped_pistol_can_return_to_backpack() -> void:
	var player := PlayerScene.instantiate()
	root.add_child(player)
	await _wait_frames(3)
	if not player.has_method("add_item_resource") or not player.has_method("equip_inventory_stack") or not player.has_method("unequip_equipment_slot"):
		_errors.append("Player should expose backpack, equipment, and unequip flow.")
		_free_node(player)
		return
	player.call("add_item_resource", PistolItem, 1)
	var inventory: InventoryModel = player.call("get_inventory_model")
	var equipment: RefCounted = player.call("get_equipment_model")
	var pistol_index := _stack_index_with_item(inventory.get_display_items(), PistolItem.resource_path)
	if pistol_index < 0 or not bool(player.call("equip_inventory_stack", pistol_index, &"primary_weapon")):
		_errors.append("Player should equip backpack pistol into equipment.")
		_free_node(player)
		return
	if not bool(player.call("unequip_equipment_slot", &"primary_weapon")):
		_errors.append("Equipped pistol should return to backpack.")
	if not equipment.call("is_empty", &"primary_weapon"):
		_errors.append("Unequipping pistol should clear the equipment slot.")
	if _stack_index_with_item(inventory.get_display_items(), PistolItem.resource_path) < 0:
		_errors.append("Unequipping pistol should restore it to the backpack inventory.")
	_free_node(player)


func _validate_safe_pocket_returns_to_base_on_death() -> void:
	var test_root := Node3D.new()
	root.add_child(test_root)
	var player := FakeRaidPlayer.new()
	player.name = "Player3D"
	player.inventory_model.add_item(WoodItem, 2)
	player.safe_pocket_model.add_item(AmmoItem, 6)
	player.equipment_model.equip_item(&"sidearm", PistolItem)
	test_root.add_child(player)

	_save_manager.call("set_current_slot_index", 1)
	_save_manager.call("save_slot_data", 1, {
		"difficulty_id": "normal",
		"money": 5,
		"stash": [{"item_path": AmmoItem.resource_path, "quantity": 2}],
		"base_upgrades": {},
		"quests": {},
	})

	var applier := RaidResultApplierScript.new()
	applier.name = "RaidResultApplier"
	applier.player_path = NodePath("../Player3D")
	test_root.add_child(applier)
	await process_frame

	var context := RaidLossRulesScript.build_death_context_from_player(player)
	var lost_items: Array = context.get("lost_items", []) as Array
	var kept_items: Array = context.get("kept_safe_pocket_items", []) as Array
	if _stack_quantity(lost_items, WoodItem.resource_path) != 2:
		_errors.append("Death should mark backpack items as lost.")
	if _stack_quantity(lost_items, PistolItem.resource_path) != 1:
		_errors.append("Death should mark equipped pistol as lost.")
	if _stack_quantity(kept_items, AmmoItem.resource_path) != 6:
		_errors.append("Death should keep safe pocket items.")
	var result := RaidResultScript.create(RaidResultScript.OUTCOME_DEAD, context)
	if not bool(applier.call("apply_raid_result", result)):
		_errors.append("Death result should apply through RaidResultApplier.")
	var saved_after: Dictionary = _save_manager.call("get_slot_data", 1)
	var stash: Array = saved_after.get("stash", []) as Array
	if _stack_quantity(stash, AmmoItem.resource_path) != 8:
		_errors.append("Safe pocket items should return to base stash on death.")
	if _stack_quantity(stash, WoodItem.resource_path) != 0 or _stack_quantity(stash, PistolItem.resource_path) != 0:
		_errors.append("Lost backpack and equipment items should not return to base stash on death.")
	if player.inventory_model.get_used_slots() != 0 or player.safe_pocket_model.get_used_slots() != 0 or not player.equipment_model.is_empty(&"sidearm"):
		_errors.append("Death apply should clear temporary raid backpack, safe pocket, and equipment.")
	_free_node(test_root)


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
		"money": 0,
		"stash": [],
		"base_upgrades": {},
		"quests": {},
	})


func _first_loot_container(parent: Node) -> LootContainer3D:
	for child in parent.find_children("*", "Area3D", true, false):
		if child.get_script() == LootContainerScript:
			return child as LootContainer3D
	return null


func _stack_index_with_item(stacks: Array, item_path: String) -> int:
	for index in range(stacks.size()):
		var value: Variant = stacks[index]
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("resource_path", "")) == item_path:
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


func _contains_cjk(value: String) -> bool:
	for codepoint in value.to_utf32_buffer():
		if (codepoint >= 0x3400 and codepoint <= 0x9FFF) or (codepoint >= 0xF900 and codepoint <= 0xFAFF):
			return true
	return false


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


func _free_current_scene() -> void:
	var scene := current_scene
	current_scene = null
	if scene == null or not is_instance_valid(scene):
		return
	_free_node(scene)


func _free_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
