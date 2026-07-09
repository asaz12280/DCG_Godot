extends SceneTree

const ExtractionZoneScript := preload("res://scripts/raid/extraction_zone_3d.gd")
const RaidSessionScript := preload("res://scripts/raid/raid_session.gd")
const RaidResultApplierScript := preload("res://scripts/raid/raid_result_applier.gd")
const RaidLossRulesScript := preload("res://scripts/raid/raid_loss_rules.gd")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const InventoryModelScript := preload("res://scripts/inventory/inventory_model.gd")
const EquipmentModelScript := preload("res://scripts/equipment/equipment_model.gd")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const WoodItem := preload("res://data/items/crafting/wood.tres")
const PistolItem := preload("res://data/items/weapons/pistol_9mm.tres")
const ExtendedMagazine := preload("res://data/items/attachments/extended_magazine.tres")

var _errors: Array[String] = []
var _last_raid_result: Dictionary = {}


class FakePlayer:
	extends CharacterBody3D

	var inventory_model := InventoryModel.new()
	var safe_pocket_model := InventoryModel.new()
	var equipment_model := EquipmentModelScript.new()

	func get_inventory_model() -> InventoryModel:
		return inventory_model

	func get_safe_pocket_model() -> InventoryModel:
		return safe_pocket_model

	func get_equipment_model() -> RefCounted:
		return equipment_model


func _initialize() -> void:
	_validate_zone_countdown_and_transfer()
	_validate_death_loss_rules()
	_validate_gameplay_scene_wiring()
	if _errors.is_empty():
		print("[extraction_flow] OK countdown=works cancel=works transfer=stash_saved equipment_saved death=lost_items inventory=cleared scene=wired")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_zone_countdown_and_transfer() -> void:
	var test_root := Node3D.new()
	root.add_child(test_root)
	var save_manager := _make_save_manager()
	var save_data := {
		"difficulty_id": "normal",
		"money": 0,
		"stash": [],
		"base_upgrades": {},
		"quests": {},
	}
	if not save_manager.save_slot_data(1, save_data):
		_errors.append("Validation setup should create a save slot for extraction transfer.")
	save_manager.set_current_slot_index(1)

	var session := RaidSessionScript.new()
	session.name = "RaidSession"
	session.auto_begin = false
	test_root.add_child(session)
	session.begin_raid("validation_map")
	session.raid_completed.connect(_on_raid_completed)

	var applier := RaidResultApplierScript.new()
	applier.name = "RaidResultApplier"
	applier.raid_session_path = NodePath("../RaidSession")
	applier.player_path = NodePath("../Player3D")
	test_root.add_child(applier)
	applier._ready()

	var zone := ExtractionZoneScript.new()
	zone.name = "ExtractionZone"
	zone.required_time = 1.0
	zone.raid_session_path = NodePath("../RaidSession")
	test_root.add_child(zone)

	var player := FakePlayer.new()
	player.name = "Player3D"
	player.inventory_model.setup(12)
	player.safe_pocket_model.setup(2)
	player.inventory_model.add_item(WoodItem, 3)
	if not player.equipment_model.equip_stack(&"sidearm", _damaged_modded_pistol_stack()):
		_errors.append("Validation should equip a damaged modded pistol before extraction.")
	test_root.add_child(player)

	_last_raid_result.clear()
	zone._on_body_entered(player)
	zone._process(0.4)
	if not bool(zone.get_state().get("active", false)):
		_errors.append("ExtractionZone should start countdown when the player enters.")
	if float(zone.get_state().get("progress", 0.0)) <= 0.0:
		_errors.append("ExtractionZone should advance progress while the player remains inside.")

	zone._on_body_exited(player)
	if bool(zone.get_state().get("active", true)):
		_errors.append("ExtractionZone should cancel countdown when the player exits.")
	if float(zone.get_state().get("progress", 1.0)) != 0.0:
		_errors.append("ExtractionZone should reset progress after cancellation.")
	if session.extracted:
		_errors.append("RaidSession should not extract when the countdown is cancelled.")

	zone._on_body_entered(player)
	zone._process(1.0)
	if not session.extracted:
		_errors.append("ExtractionZone should notify RaidSession when countdown completes.")
	var result := session.build_result()
	if str(result.get("source", "")) != "extraction_zone":
		_errors.append("ExtractionZone result context should stay serializable and identify the source.")
	var extracted_items := result.get("extracted_items", []) as Array
	if extracted_items.is_empty() or int(extracted_items[0].get("quantity", 0)) != 3:
		_errors.append("Extraction result should include the player's backpack item stacks.")
	var extracted_pistol := _entry_for_path(extracted_items, PistolItem.resource_path)
	if not extracted_pistol.is_empty():
		_errors.append("Extraction result should keep equipped weapon stacks out of extracted_items.")
	var extracted_equipment := result.get("extracted_equipment", {}) as Dictionary
	var extracted_equipped_pistol := _equipment_entry_for_slot(extracted_equipment, &"sidearm")
	if extracted_equipped_pistol.is_empty():
		_errors.append("Extraction result should include equipped weapon stacks in extracted_equipment.")
	else:
		_expect_pistol_state(extracted_equipped_pistol, "Extraction result equipment")
	if not bool(applier.last_apply_result.get("applied", false)):
		_errors.append("RaidResultApplier should apply extracted items to the current save slot. Reason: %s" % str(applier.last_apply_result.get("reason", "")))
	var saved_after: Dictionary = save_manager.get_slot_data(1)
	var saved_stash := saved_after.get("stash", []) as Array
	if saved_stash.is_empty() or int(saved_stash[0].get("quantity", 0)) != 3:
		_errors.append("Extracted items should be saved into persistent stash.")
	var saved_pistol := _entry_for_path(saved_stash, PistolItem.resource_path)
	if not saved_pistol.is_empty():
		_errors.append("Extracted equipped Pistol-S should stay equipped instead of moving into persistent stash.")
	var saved_equipped_pistol := _equipment_entry_for_slot(saved_after.get("equipment", {}) as Dictionary, &"sidearm")
	if saved_equipped_pistol.is_empty():
		_errors.append("Extracted equipped Pistol-S should be saved into persistent equipment.")
	else:
		_expect_pistol_state(saved_equipped_pistol, "Persistent equipment")
	if player.inventory_model.get_used_slots() != 0:
		_errors.append("Raid inventory should be cleared after successful transfer.")
	if not player.equipment_model.is_empty(&"sidearm"):
		_errors.append("Raid equipment should be cleared after successful transfer.")

	test_root.free()
	_cleanup_validation_root(save_manager.save_root_path)
	_free_node(save_manager)


func _validate_death_loss_rules() -> void:
	var test_root := Node3D.new()
	root.add_child(test_root)
	var save_manager := _make_save_manager()
	save_manager.save_slot_data(1, {
		"difficulty_id": "normal",
		"money": 0,
		"stash": [],
		"base_upgrades": {},
		"quests": {},
	})
	save_manager.set_current_slot_index(1)

	var session := RaidSessionScript.new()
	session.name = "RaidSession"
	session.auto_begin = false
	test_root.add_child(session)
	session.begin_raid("death_validation_map")

	var applier := RaidResultApplierScript.new()
	applier.name = "RaidResultApplier"
	applier.raid_session_path = NodePath("../RaidSession")
	applier.player_path = NodePath("../Player3D")
	test_root.add_child(applier)
	applier._ready()

	var player := FakePlayer.new()
	player.name = "Player3D"
	player.inventory_model.setup(12)
	player.inventory_model.add_item(WoodItem, 2)
	test_root.add_child(player)

	var death_context := RaidLossRulesScript.build_death_context_from_player(player)
	if not session.register_player_death(death_context):
		_errors.append("RaidSession should accept death context built from RaidLossRules.")
	var result := session.build_result()
	if str(result.get("outcome", "")) != "dead":
		_errors.append("Death result should use dead outcome.")
	var lost_items := result.get("lost_items", []) as Array
	if lost_items.is_empty() or int(lost_items[0].get("quantity", 0)) != 2:
		_errors.append("Death result should list backpack items as lost_items.")
	if typeof(result.get("kept_safe_pocket_items", null)) != TYPE_ARRAY:
		_errors.append("Death result should include safe pocket retention array.")
	if not bool(applier.last_apply_result.get("death_loss", false)):
		_errors.append("RaidResultApplier should handle death loss without saving backpack to stash.")
	var saved_after: Dictionary = save_manager.get_slot_data(1)
	var saved_stash := saved_after.get("stash", []) as Array
	if not saved_stash.is_empty():
		_errors.append("Death should not add backpack items to persistent stash.")
	if player.inventory_model.get_used_slots() != 0:
		_errors.append("Raid inventory should be cleared after death result is applied.")

	test_root.free()
	_cleanup_validation_root(save_manager.save_root_path)
	_free_node(save_manager)


func _validate_gameplay_scene_wiring() -> void:
	var scene := GameplayScene.instantiate()
	root.add_child(scene)
	var zone := scene.get_node_or_null("SceneProps/ExtractionZone")
	if zone == null:
		_errors.append("Gameplay scene should include SceneProps/ExtractionZone.")
	elif zone.get_script() != ExtractionZoneScript:
		_errors.append("Gameplay ExtractionZone should use ExtractionZone3D script.")
	else:
		if zone.get_node_or_null("CollisionShape3D") == null:
			_errors.append("Gameplay ExtractionZone should include a CollisionShape3D.")
		var prompt_label := zone.get_node_or_null("PromptLabel")
		if prompt_label == null or not prompt_label is Label3D:
			_errors.append("Gameplay ExtractionZone should include a Label3D prompt.")
		if str(zone.raid_session_path) == "":
			_errors.append("Gameplay ExtractionZone should have a RaidSession path or fallback.")
	var session := scene.get_node_or_null("RaidSession")
	if session == null:
		_errors.append("Gameplay scene should keep the RaidSession node required by extraction.")
	var applier := scene.get_node_or_null("RaidResultApplier")
	if applier == null:
		_errors.append("Gameplay scene should include RaidResultApplier for extraction transfer.")
	elif applier.get_script() != RaidResultApplierScript:
		_errors.append("Gameplay RaidResultApplier should use the RaidResultApplier script.")
	scene.free()


func _on_raid_completed(result: Dictionary) -> void:
	_last_raid_result = result.duplicate(true)


func _make_save_manager() -> Node:
	var existing := root.get_node_or_null("SaveGameManager")
	if existing != null:
		_free_node(existing)
	var save_manager := SaveGameManagerScript.new()
	save_manager.name = "SaveGameManager"
	save_manager.save_root_path = "user://validation_extraction_flow"
	root.add_child(save_manager)
	_cleanup_validation_root(save_manager.save_root_path)
	return save_manager


func _damaged_modded_pistol_stack() -> Dictionary:
	var stack := PistolItem.to_stack(1)
	stack["current_durability"] = 37
	stack["max_durability"] = 81
	stack["original_max_durability"] = PistolItem.max_durability
	stack["repair_max_durability_loss"] = PistolItem.repair_max_durability_loss
	stack["durability_penalty_ratio"] = PistolItem.durability_penalty_ratio
	stack["weapon_mods"] = {
		"magazine": ExtendedMagazine.to_stack(1),
	}
	return stack


func _entry_for_path(stacks: Array, item_path: String) -> Dictionary:
	for value in stacks:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := value as Dictionary
		if str(stack.get("item_path", stack.get("resource_path", ""))) == item_path:
			return stack
	return {}


func _equipment_entry_for_slot(equipment_data: Dictionary, slot_id: StringName) -> Dictionary:
	var slots: Dictionary = equipment_data.get("slots", {}) as Dictionary
	var value: Variant = slots.get(str(slot_id), {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _expect_pistol_state(stack: Dictionary, label: String) -> void:
	if int(stack.get("current_durability", -1)) != 37 or int(stack.get("max_durability", -1)) != 81:
		_errors.append("%s should preserve damaged Pistol-S durability 37/81, got %s/%s." % [label, str(stack.get("current_durability", "")), str(stack.get("max_durability", ""))])
	var mods: Dictionary = stack.get("weapon_mods", {}) as Dictionary
	var magazine: Dictionary = mods.get("magazine", {}) as Dictionary
	if magazine.is_empty():
		_errors.append("%s should preserve Pistol-S magazine attachment." % label)
	elif str(magazine.get("item_path", magazine.get("resource_path", ""))) != ExtendedMagazine.resource_path:
		_errors.append("%s should preserve Extended Magazine-S, got %s." % [label, str(magazine.get("item_path", magazine.get("resource_path", "")))])


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
