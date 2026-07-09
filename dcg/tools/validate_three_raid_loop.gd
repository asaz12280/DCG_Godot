extends SceneTree

const BaseScreenScene := preload("res://scenes/base/base_screen.tscn")
const PlayerScene := preload("res://scenes/player/player_3d.tscn")
const ScavengerScene := preload("res://scenes/enemies/scavenger_3d.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const RaidResultApplierScript := preload("res://scripts/raid/raid_result_applier.gd")
const RaidResultSchema := preload("res://scripts/raid/raid_result.gd")
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")
const InventoryModelScript := preload("res://scripts/inventory/inventory_model.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")
const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const WorkbenchUpgrade := preload("res://data/base_upgrades/workbench_level_1.tres")
const FirstSalvageQuest := preload("res://data/quests/first_salvage.tres")
const FirstScavengerHuntQuest := preload("res://data/quests/first_scavenger_hunt.tres")

const WOOD_PATH := "res://data/items/crafting/wood.tres"
const WIRE_PATH := "res://data/items/electronics/wire.tres"
const JUNK_PATH := "res://data/items/loot/junk.tres"

var _errors: Array[String] = []
var _save_manager: Node = null
var _created_save_manager := false


class FakePlayer:
	extends CharacterBody3D

	var inventory_model := InventoryModel.new()

	func _init() -> void:
		name = "Player3D"
		inventory_model.setup(12)

	func get_inventory_model() -> InventoryModel:
		return inventory_model


func _initialize() -> void:
	_setup_save_manager()
	await _validate_raid_one_extract_and_base_progress()
	await _validate_raid_two_death_preserves_meta_progress()
	await _validate_raid_three_kill_extract_and_save_reload()
	_cleanup_validation_root(_save_manager.save_root_path)
	if _created_save_manager:
		_free_node(_save_manager)
	if _errors.is_empty():
		print("[three_raid_loop] OK raid1=extract_upgrade raid2=death_preserves raid3=kill_extract reload=persistent")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_raid_one_extract_and_base_progress() -> void:
	_accept_quest(FirstSalvageQuest)
	var result := RaidResultSchema.create(RaidResultSchema.OUTCOME_EXTRACTED, {
		"extracted_items": [
			{"item_path": WOOD_PATH, "quantity": 4},
			{"item_path": WIRE_PATH, "quantity": 2},
		],
		"duration": 42.0,
	})
	_assert_serializable(result, "raid one extraction result")
	if not _apply_result(result):
		_errors.append("Raid one extraction should apply to the active save slot.")
		return

	var after_extract: Dictionary = _save_manager.get_slot_data(1)
	if _stash_quantity(after_extract, WOOD_PATH) != 4 or _stash_quantity(after_extract, WIRE_PATH) != 2:
		_errors.append("Raid one should store extracted wood and wire in persistent stash.")
	var salvage_state := _quest_state(after_extract, "first_salvage")
	if str(salvage_state.get("state", "")) != QuestStateScript.STATE_READY:
		_errors.append("Raid one should make First Salvage ready from extracted materials.")

	var base_screen: BaseScreen = await _make_base_screen()
	var claim_result: Dictionary = base_screen.submit_first_salvage_quest()
	if not bool(claim_result.get("success", false)):
		_errors.append("Base should claim First Salvage after raid one.")
	var upgrade_result: Dictionary = base_screen.upgrade_workbench()
	if not bool(upgrade_result.get("success", false)):
		_errors.append("Base should purchase Workbench Level 1 after raid one.")
	_free_node(base_screen)

	var after_base: Dictionary = _save_manager.get_slot_data(1)
	if int(after_base.get("money", 0)) != 20:
		_errors.append("Raid one base phase should leave money at 20 after quest reward and tuned upgrade cost.")
	if _stash_quantity(after_base, WOOD_PATH) != 1 or _stash_quantity(after_base, WIRE_PATH) != 0:
		_errors.append("Workbench purchase should consume tuned material costs and keep excess wood.")
	if not BaseProgressionScript.is_upgrade_purchased(after_base, WorkbenchUpgrade.id):
		_errors.append("Workbench Level 1 should persist after raid one.")
	await _validate_next_raid_visible_upgrade_effect("raid two")
	var completed_salvage := _quest_state(after_base, "first_salvage")
	if str(completed_salvage.get("state", "")) != QuestStateScript.STATE_COMPLETED:
		_errors.append("First Salvage should persist completed after base claim.")


func _validate_raid_two_death_preserves_meta_progress() -> void:
	var before_death: Dictionary = _save_manager.get_slot_data(1)
	var player := FakePlayer.new()
	root.add_child(player)
	var junk_item := load(JUNK_PATH) as ItemDef
	player.inventory_model.add_item(junk_item, 2)

	var result := RaidResultSchema.create(RaidResultSchema.OUTCOME_DEAD, {
		"lost_items": [{"item_path": JUNK_PATH, "quantity": 2}],
		"duration": 18.0,
	})
	_assert_serializable(result, "raid two death result")
	var applied := _apply_result(result, player)
	if not applied:
		_errors.append("Raid two death should be accepted by RaidResultApplier.")
	if player.inventory_model.get_used_slots() != 0:
		_errors.append("Raid two death should clear the raid inventory.")
	_free_node(player)

	var after_death: Dictionary = _save_manager.get_slot_data(1)
	if _stash_quantity(after_death, JUNK_PATH) != 0:
		_errors.append("Raid two death should not add lost backpack items to stash.")
	if int(after_death.get("money", 0)) != int(before_death.get("money", 0)):
		_errors.append("Raid two death should preserve base money.")
	if not BaseProgressionScript.is_upgrade_purchased(after_death, WorkbenchUpgrade.id):
		_errors.append("Raid two death should preserve purchased base upgrades.")
	if str(_quest_state(after_death, "first_salvage").get("state", "")) != QuestStateScript.STATE_COMPLETED:
		_errors.append("Raid two death should not roll back completed quests.")


func _validate_raid_three_kill_extract_and_save_reload() -> void:
	_accept_quest(FirstScavengerHuntQuest)
	var enemy := ScavengerScene.instantiate()
	root.add_child(enemy)
	await process_frame
	enemy.apply_damage(DamageEventScript.new(999.0, null, null, [&"validation"]))
	_free_node(enemy)

	var after_kill: Dictionary = _save_manager.get_slot_data(1)
	var hunt_state := _quest_state(after_kill, "first_scavenger_hunt")
	if str(hunt_state.get("state", "")) != QuestStateScript.STATE_READY:
		_errors.append("Raid three Scavenger kill should ready First Scavenger Hunt.")
	var kill_progress: Dictionary = hunt_state.get("progress", {}) as Dictionary
	if int(kill_progress.get(QuestStateScript.kill_progress_key("scavenger"), 0)) != 1:
		_errors.append("Raid three should persist kill:scavenger progress.")

	var result := RaidResultSchema.create(RaidResultSchema.OUTCOME_EXTRACTED, {
		"extracted_items": [{"item_path": JUNK_PATH, "quantity": 1}],
		"money_delta": 3,
		"duration": 64.0,
	})
	_assert_serializable(result, "raid three extraction result")
	if not _apply_result(result):
		_errors.append("Raid three extraction should apply to the active save slot.")

	var base_screen: BaseScreen = await _make_base_screen()
	var claim_result: Dictionary = base_screen.submit_first_scavenger_hunt_quest()
	if not bool(claim_result.get("success", false)):
		_errors.append("Base should claim First Scavenger Hunt after raid three.")
	_free_node(base_screen)

	var reloaded: Dictionary = _reload_slot_data()
	if _stash_quantity(reloaded, JUNK_PATH) != 1:
		_errors.append("Save reload should preserve raid three extracted stash.")
	if int(reloaded.get("money", 0)) != 68:
		_errors.append("Save reload should preserve money after three raids, expected 68.")
	if not BaseProgressionScript.is_upgrade_purchased(reloaded, WorkbenchUpgrade.id):
		_errors.append("Save reload should preserve Workbench Level 1.")
	if str(_quest_state(reloaded, "first_salvage").get("state", "")) != QuestStateScript.STATE_COMPLETED:
		_errors.append("Save reload should preserve First Salvage completion.")
	if str(_quest_state(reloaded, "first_scavenger_hunt").get("state", "")) != QuestStateScript.STATE_COMPLETED:
		_errors.append("Save reload should preserve First Scavenger Hunt completion.")


func _validate_next_raid_visible_upgrade_effect(label: String) -> void:
	var player := PlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	var weapon := player.get_node_or_null("WeaponController3D")
	if weapon == null:
		_errors.append("Player scene should include WeaponController3D for %s upgrade visibility." % label)
	else:
		if int(weapon.get("reserve_ammo")) < int(WorkbenchUpgrade.starter_ammo_bonus):
			_errors.append("Workbench Level 1 should make %s visibly start with bonus reserve ammo." % label)
	_free_node(player)


func _setup_save_manager() -> void:
	_save_manager = root.get_node_or_null("SaveGameManager")
	if _save_manager == null:
		_save_manager = SaveGameManagerScript.new()
		_save_manager.name = "SaveGameManager"
		root.add_child(_save_manager)
		_created_save_manager = true
	_save_manager.save_root_path = "user://validation_three_raid_loop"
	_cleanup_validation_root(_save_manager.save_root_path)
	_save_manager.set_current_slot_index(1)
	_save_manager.save_slot_data(1, {
		"difficulty_id": "normal",
		"money": 0,
		"stash": [],
		"base_upgrades": {},
		"quests": {},
	})


func _apply_result(result: Dictionary, player: Node = null) -> bool:
	var test_root := Node3D.new()
	root.add_child(test_root)
	if player != null and player.get_parent() != test_root:
		if player.get_parent() != null:
			player.get_parent().remove_child(player)
		test_root.add_child(player)
	var applier := RaidResultApplierScript.new()
	applier.name = "RaidResultApplier"
	applier.player_path = NodePath("../Player3D")
	test_root.add_child(applier)
	var applied := applier.apply_raid_result(result)
	if player != null and player.get_parent() == test_root:
		test_root.remove_child(player)
		root.add_child(player)
	_free_node(test_root)
	return applied


func _make_base_screen() -> BaseScreen:
	var base_screen: BaseScreen = BaseScreenScene.instantiate()
	root.add_child(base_screen)
	await process_frame
	base_screen.refresh()
	return base_screen


func _reload_slot_data() -> Dictionary:
	var reload_manager := SaveGameManagerScript.new()
	reload_manager.save_root_path = _save_manager.save_root_path
	var data: Dictionary = reload_manager.get_slot_data(1)
	reload_manager.free()
	return data


func _quest_state(save_data: Dictionary, quest_id: String) -> Dictionary:
	var quests: Dictionary = save_data.get("quests", {}) as Dictionary
	return quests.get(quest_id, {}) as Dictionary


func _accept_quest(quest_def: Resource) -> void:
	var save_data: Dictionary = _save_manager.get_slot_data(1)
	var quests: Dictionary = save_data.get("quests", {}) as Dictionary
	quests[str(quest_def.get("id"))] = QuestStateScript.accept(quest_def)
	save_data["quests"] = quests
	_save_manager.save_slot_data(1, save_data)


func _stash_quantity(save_data: Dictionary, item_path: String) -> int:
	var total := 0
	var stash: Array = save_data.get("stash", []) as Array
	for entry in stash:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str((entry as Dictionary).get("item_path", "")) == item_path:
			total += int((entry as Dictionary).get("quantity", 0))
	return total


func _assert_serializable(result: Dictionary, label: String) -> void:
	var errors: Array[String] = RaidResultSchema.validate(result)
	for error in errors:
		_errors.append("%s is not serializable: %s" % [label, error])


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
