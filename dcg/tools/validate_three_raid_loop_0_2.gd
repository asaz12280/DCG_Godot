extends SceneTree

const Base3DScene := preload("res://scenes/base/base_3d.tscn")
const GameplayScene := preload("res://scenes/gameplay/player_test_world_3d.tscn")
const PlayerScene := preload("res://scenes/player/player_3d.tscn")
const ScavengerScene := preload("res://scenes/enemies/scavenger_3d.tscn")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const RaidResultApplierScript := preload("res://scripts/raid/raid_result_applier.gd")
const RaidResultSchema := preload("res://scripts/raid/raid_result.gd")
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")
const InventoryModelScript := preload("res://scripts/inventory/inventory_model.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")
const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const BaseWorkbenchServiceScript := preload("res://scripts/base/base_workbench_service.gd")
const FirstSalvageQuest := preload("res://data/quests/first_salvage.tres")
const FirstScavengerHuntQuest := preload("res://data/quests/first_scavenger_hunt.tres")
const WorkbenchUpgrade := preload("res://data/base_upgrades/workbench_level_1.tres")

const WOOD_PATH := "res://data/items/crafting/wood.tres"
const WIRE_PATH := "res://data/items/electronics/wire.tres"
const JUNK_PATH := "res://data/items/loot/junk.tres"
const VALIDATION_SAVE_ROOT := "user://validation_three_raid_loop_0_2"

var _errors: Array[String] = []
var _save_manager: Node = null
var _created_save_manager := false
var _raid_two_completed: Dictionary = {}


class FakePlayer:
	extends CharacterBody3D

	var inventory_model := InventoryModel.new()

	func _init() -> void:
		name = "Player3D"
		inventory_model.setup(12)

	func get_inventory_model() -> InventoryModel:
		return inventory_model


func _initialize() -> void:
	TranslationServer.set_locale("zh_TW")
	_setup_save_manager()
	await _validate_raid_one_extract_then_3d_base_upgrade()
	await _validate_raid_two_enemy_death_preserves_meta_progress()
	await _validate_raid_three_upgrade_effect_kill_extract_reload()
	_validate_source_boundaries()
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
	if _created_save_manager:
		_free_node(_save_manager)

	if _errors.is_empty():
		print("[three_raid_loop_0_2] OK raid1=extract_3d_base_upgrade raid2=enemy_death_preserves raid3=upgrade_kill_extract reload=persistent")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_raid_one_extract_then_3d_base_upgrade() -> void:
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
	if str(_quest_state(after_extract, "first_salvage").get("state", "")) != QuestStateScript.STATE_READY:
		_errors.append("Raid one should ready First Salvage from extracted materials.")

	var claim_result := _claim_quest(FirstSalvageQuest)
	if not bool(claim_result.get("success", false)):
		_errors.append("3D Base phase should claim First Salvage after raid one.")

	var base_scene := Base3DScene.instantiate()
	root.add_child(base_scene)
	await process_frame
	await process_frame
	var controller := base_scene.get_node_or_null("BaseInteractionController3D")
	var panel := base_scene.get_node_or_null("HUD/BaseInteractionPanel")
	if controller == null or panel == null:
		_errors.append("Raid one base phase should expose 3D Base interaction controller and panel.")
	else:
		if not bool(controller.call("open_interaction_by_id", "workbench")):
			_errors.append("3D Base should open the workbench station after raid one.")
		await process_frame
		var panel_state: Dictionary = panel.call("get_display_state") if panel.has_method("get_display_state") else {}
		if not bool(panel_state.get("visible", false)):
			_errors.append("3D Base workbench panel should be visible before purchasing the upgrade.")
		if not bool(panel_state.get("action_visible", false)):
			_errors.append("3D Base workbench panel should expose a player-visible upgrade action.")
	var upgrade_result: Dictionary = BaseWorkbenchServiceScript.purchase(_save_manager)
	if not bool(upgrade_result.get("success", false)):
		_errors.append("3D Base workbench service should purchase Workbench Level 1 after raid one.")
	_free_node(base_scene)

	var after_base: Dictionary = _save_manager.get_slot_data(1)
	if int(after_base.get("money", 0)) != 20:
		_errors.append("Raid one 3D Base phase should leave money at 20 after quest reward and upgrade cost.")
	if _stash_quantity(after_base, WOOD_PATH) != 1 or _stash_quantity(after_base, WIRE_PATH) != 0:
		_errors.append("3D Base workbench purchase should consume tuned material costs and keep excess wood.")
	if not BaseProgressionScript.is_upgrade_purchased(after_base, WorkbenchUpgrade.id):
		_errors.append("Workbench Level 1 should persist after raid one 3D Base phase.")
	if str(_quest_state(after_base, "first_salvage").get("state", "")) != QuestStateScript.STATE_COMPLETED:
		_errors.append("First Salvage should persist completed after 3D Base claim.")


func _validate_raid_two_enemy_death_preserves_meta_progress() -> void:
	var before_death: Dictionary = _save_manager.get_slot_data(1)
	var gameplay := GameplayScene.instantiate()
	root.add_child(gameplay)
	await process_frame
	await process_frame
	var player := gameplay.get_node_or_null("Player3D")
	var enemy := gameplay.get_node_or_null("SceneProps/ScavengerPatrol01")
	var result_applier := gameplay.get_node_or_null("RaidResultApplier")
	if player == null or enemy == null or result_applier == null:
		_errors.append("Raid two should load normal gameplay with player, visible enemy, and RaidResultApplier.")
		_free_node(gameplay)
		return
	var junk_item := load(JUNK_PATH) as ItemDef
	player.call("get_inventory_model").add_item(junk_item, 2)
	if gameplay.has_node("RaidSession"):
		var raid_session := gameplay.get_node("RaidSession")
		if raid_session.has_signal("raid_completed"):
			raid_session.raid_completed.connect(_on_raid_two_completed)
	player.call("apply_damage", DamageEventScript.new(999.0, enemy, null, [&"enemy", &"validation"]))
	await _wait_frames(8)
	if not bool(player.get("is_dead")):
		_errors.append("Raid two should kill the player through the real player damage/death path.")
	var last_apply: Dictionary = result_applier.get("last_apply_result")
	if not bool(last_apply.get("death_loss", false)):
		_errors.append("Raid two death should be applied by RaidResultApplier.")
	if _raid_two_completed.is_empty() or str(_raid_two_completed.get("outcome", "")) != RaidResultSchema.OUTCOME_DEAD:
		_errors.append("Raid two should emit a dead RaidResult from RaidSession.")
	_free_node(gameplay)

	var after_death: Dictionary = _save_manager.get_slot_data(1)
	if _stash_quantity(after_death, JUNK_PATH) != 0:
		_errors.append("Raid two death should not add lost backpack items to stash.")
	if int(after_death.get("money", 0)) != int(before_death.get("money", 0)):
		_errors.append("Raid two death should preserve base money.")
	if not BaseProgressionScript.is_upgrade_purchased(after_death, WorkbenchUpgrade.id):
		_errors.append("Raid two death should preserve purchased base upgrades.")
	if str(_quest_state(after_death, "first_salvage").get("state", "")) != QuestStateScript.STATE_COMPLETED:
		_errors.append("Raid two death should not roll back completed quests.")


func _validate_raid_three_upgrade_effect_kill_extract_reload() -> void:
	_accept_quest(FirstScavengerHuntQuest)
	await _validate_next_raid_visible_upgrade_effect("raid three")
	var enemy := ScavengerScene.instantiate()
	root.add_child(enemy)
	await process_frame
	enemy.call("apply_damage", DamageEventScript.new(999.0, null, null, [&"validation"]))
	await process_frame
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
	var claim_result := _claim_quest(FirstScavengerHuntQuest)
	if not bool(claim_result.get("success", false)):
		_errors.append("3D Base phase should claim First Scavenger Hunt after raid three.")

	var reloaded: Dictionary = _reload_slot_data()
	if _stash_quantity(reloaded, JUNK_PATH) != 1:
		_errors.append("Save reload should preserve raid three extracted stash.")
	if int(reloaded.get("money", 0)) != 68:
		_errors.append("Save reload should preserve money after three 0.2 raids, expected 68.")
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


func _validate_source_boundaries() -> void:
	var source := _read_text("res://tools/validate_three_raid_loop_0_2.gd")
	for required in PackedStringArray(["Base3DScene", "BaseWorkbenchServiceScript", "GameplayScene", "ScavengerScene", "RaidResultApplierScript", "VALIDATION_SAVE_ROOT"]):
		if not source.contains(required):
			_errors.append("0.2 three raid loop validator should keep coverage term %s." % required)
	for forbidden in PackedStringArray(["Base" + "ScreenScene", "base_" + "screen.tscn"]):
		if source.contains(forbidden):
			_errors.append("0.2 three raid loop validator should not use old 2D base flow token: %s." % forbidden)


func _setup_save_manager() -> void:
	_save_manager = root.get_node_or_null("SaveGameManager")
	if _save_manager == null:
		_save_manager = SaveGameManagerScript.new()
		_save_manager.name = "SaveGameManager"
		root.add_child(_save_manager)
		_created_save_manager = true
	_save_manager.save_root_path = VALIDATION_SAVE_ROOT
	_cleanup_validation_root(VALIDATION_SAVE_ROOT)
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
	var applied := bool(applier.call("apply_raid_result", result))
	if player != null and player.get_parent() == test_root:
		test_root.remove_child(player)
		root.add_child(player)
	_free_node(test_root)
	return applied


func _claim_quest(quest_def: Resource) -> Dictionary:
	var save_data: Dictionary = _save_manager.get_slot_data(1)
	var quests: Dictionary = _quest_dict(save_data.get("quests", {}))
	var quest_id := str(quest_def.get("id"))
	if not quests.has(quest_id):
		return {"success": false, "reason": "not_accepted"}
	var quest_state: Dictionary = quests.get(quest_id, {}) as Dictionary
	var result: Dictionary = QuestStateScript.claim_reward(save_data, quest_state, quest_def)
	if not bool(result.get("success", false)):
		return result
	var updated: Dictionary = result.get("save_data", {}) as Dictionary
	var updated_quests: Dictionary = _quest_dict(updated.get("quests", {}))
	updated_quests[quest_id] = result.get("quest_state", {}) as Dictionary
	updated["quests"] = updated_quests
	if not bool(_save_manager.save_slot_data(1, updated)):
		return {"success": false, "reason": "save_failed"}
	return result


func _accept_quest(quest_def: Resource) -> void:
	var save_data: Dictionary = _save_manager.get_slot_data(1)
	var quests: Dictionary = _quest_dict(save_data.get("quests", {}))
	quests[str(quest_def.get("id"))] = QuestStateScript.accept(quest_def)
	save_data["quests"] = quests
	_save_manager.save_slot_data(1, save_data)


func _reload_slot_data() -> Dictionary:
	var reload_manager := SaveGameManagerScript.new()
	reload_manager.save_root_path = _save_manager.save_root_path
	var data: Dictionary = reload_manager.get_slot_data(1)
	reload_manager.free()
	return data


func _quest_state(save_data: Dictionary, quest_id: String) -> Dictionary:
	var quests: Dictionary = _quest_dict(save_data.get("quests", {}))
	return quests.get(quest_id, {}) as Dictionary


func _quest_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


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


func _on_raid_two_completed(result: Dictionary) -> void:
	_raid_two_completed = result.duplicate(true)


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


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


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("Cannot read %s" % path)
		return ""
	return file.get_as_text()
