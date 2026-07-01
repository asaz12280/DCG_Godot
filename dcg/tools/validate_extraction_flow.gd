extends SceneTree

const ExtractionZoneScript := preload("res://scripts/raid/extraction_zone_3d.gd")
const RaidSessionScript := preload("res://scripts/raid/raid_session.gd")
const RaidResultApplierScript := preload("res://scripts/raid/raid_result_applier.gd")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const InventoryModelScript := preload("res://scripts/inventory/inventory_model.gd")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const WoodItem := preload("res://data/items/crafting/wood.tres")

var _errors: Array[String] = []
var _last_raid_result: Dictionary = {}


class FakePlayer:
	extends CharacterBody3D

	var inventory_model := InventoryModel.new()

	func get_inventory_model() -> InventoryModel:
		return inventory_model


func _initialize() -> void:
	_validate_zone_countdown_and_transfer()
	_validate_gameplay_scene_wiring()
	if _errors.is_empty():
		print("[extraction_flow] OK countdown=works cancel=works transfer=stash_saved inventory=cleared scene=wired")
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
	player.inventory_model.add_item(WoodItem, 3)
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
	if not bool(applier.last_apply_result.get("applied", false)):
		_errors.append("RaidResultApplier should apply extracted items to the current save slot. Reason: %s" % str(applier.last_apply_result.get("reason", "")))
	var saved_after: Dictionary = save_manager.get_slot_data(1)
	var saved_stash := saved_after.get("stash", []) as Array
	if saved_stash.is_empty() or int(saved_stash[0].get("quantity", 0)) != 3:
		_errors.append("Extracted items should be saved into persistent stash.")
	if player.inventory_model.get_used_slots() != 0:
		_errors.append("Raid inventory should be cleared after successful transfer.")

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
