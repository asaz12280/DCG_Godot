extends SceneTree

const BaseScreenScene := preload("res://scenes/base/base_screen.tscn")
const ScavengerScene := preload("res://scenes/enemies/scavenger_3d.tscn")
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")
const RaidResultApplierScript := preload("res://scripts/raid/raid_result_applier.gd")
const SaveGameManagerScript := preload("res://scripts/save/save_game_manager.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")
const RaidResultSchema := preload("res://scripts/raid/raid_result.gd")
const FirstSalvageQuest := preload("res://data/quests/first_salvage.tres")
const FirstScavengerHuntQuest := preload("res://data/quests/first_scavenger_hunt.tres")

const WOOD_PATH := "res://data/items/crafting/wood.tres"
const WIRE_PATH := "res://data/items/electronics/wire.tres"

var _errors: Array[String] = []
var _created_save_manager: Node = null


func _initialize() -> void:
	await _validate_extraction_updates_quest_and_base_submit()
	await _validate_scavenger_kill_updates_quest_and_base_submit()
	await _validate_quest_ui_layout()
	if _errors.is_empty():
		print("[quest_flow] OK extraction=updates_base kill=updates_base quest=claimable reward=saved layout=fits")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_extraction_updates_quest_and_base_submit() -> void:
	var save_manager := _make_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	save_manager.save_slot_data(1, {
		"difficulty_id": "normal",
		"money": 0,
		"stash": [],
		"base_upgrades": {},
		"quests": {},
	})

	var test_root := Node3D.new()
	root.add_child(test_root)
	var applier := RaidResultApplierScript.new()
	test_root.add_child(applier)
	var result := RaidResultSchema.create(RaidResultSchema.OUTCOME_EXTRACTED, {
		"extracted_items": [{"item_path": WIRE_PATH, "quantity": 1}],
	})
	if not applier.apply_raid_result(result):
		_errors.append("RaidResultApplier should apply extraction result with quest progress.")

	var after_extract: Dictionary = save_manager.get_slot_data(1)
	var quests: Dictionary = after_extract.get("quests", {}) as Dictionary
	if not quests.has("first_salvage"):
		_errors.append("Extraction should create first_salvage quest state in save data.")
	else:
		var quest_state: Dictionary = quests.get("first_salvage", {}) as Dictionary
		if str(quest_state.get("state", "")) != QuestStateScript.STATE_READY:
			_errors.append("Extracting wire should ready First Salvage quest.")

	var base_screen: BaseScreen = BaseScreenScene.instantiate()
	root.add_child(base_screen)
	await process_frame
	base_screen.refresh()
	var ready_state: Dictionary = base_screen.get_display_state()
	if bool(ready_state.get("submit_quest_disabled", true)):
		_errors.append("Base quest submit button should enable when quest is ready.")
	if not str(ready_state.get("quest_status", "")).contains("可回報"):
		_errors.append("Base quest status should show Traditional Chinese ready text for claimable quest.")

	var claim_result: Dictionary = base_screen.submit_first_salvage_quest()
	if not bool(claim_result.get("success", false)):
		_errors.append("BaseScreen should submit First Salvage when ready.")
	var after_claim: Dictionary = save_manager.get_slot_data(1)
	if int(after_claim.get("money", 0)) != int(FirstSalvageQuest.get("reward_money")):
		_errors.append("Submitting First Salvage should save reward money.")
	var claimed_quests: Dictionary = after_claim.get("quests", {}) as Dictionary
	var claimed_state: Dictionary = claimed_quests.get("first_salvage", {}) as Dictionary
	if str(claimed_state.get("state", "")) != QuestStateScript.STATE_COMPLETED:
		_errors.append("Submitting First Salvage should save completed quest state.")
	if not bool(claimed_state.get("claimed", false)):
		_errors.append("Submitting First Salvage should save claimed=true.")
	var completed_state: Dictionary = base_screen.get_display_state()
	if str(completed_state.get("quest_id", "")) != "first_scavenger_hunt":
		_errors.append("Base should advance to the next active quest after First Salvage is completed.")
	if not bool(completed_state.get("submit_quest_disabled", false)):
		_errors.append("Base quest submit button should disable for the next active quest.")

	_free_node(base_screen)
	_free_node(test_root)
	_cleanup_validation_root(save_manager.save_root_path)
	_free_created_save_manager()


func _validate_scavenger_kill_updates_quest_and_base_submit() -> void:
	var save_manager := _make_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	save_manager.save_slot_data(1, {
		"difficulty_id": "normal",
		"money": 0,
		"stash": [],
		"base_upgrades": {},
		"quests": {},
	})

	var enemy := ScavengerScene.instantiate()
	root.add_child(enemy)
	await process_frame
	var tracker := enemy.get_node_or_null("QuestKillTracker3D")
	if tracker == null:
		_errors.append("Scavenger should include QuestKillTracker3D.")
	else:
		enemy.apply_damage(DamageEventScript.new(999.0, null, null, [&"validation"]))

	var after_kill: Dictionary = save_manager.get_slot_data(1)
	var quests: Dictionary = after_kill.get("quests", {}) as Dictionary
	if not quests.has("first_scavenger_hunt"):
		_errors.append("Killing a Scavenger should create first_scavenger_hunt quest state in save data.")
	else:
		var quest_state: Dictionary = quests.get("first_scavenger_hunt", {}) as Dictionary
		var progress: Dictionary = quest_state.get("progress", {}) as Dictionary
		var progress_key := QuestStateScript.kill_progress_key("scavenger")
		if int(progress.get(progress_key, 0)) != 1:
			_errors.append("Scavenger kill should save kill:scavenger progress immediately.")
		if str(quest_state.get("state", "")) != QuestStateScript.STATE_READY:
			_errors.append("Killing one Scavenger should ready First Scavenger Hunt.")

	if tracker != null and tracker.has_method("record_kill"):
		tracker.record_kill("scavenger")
	var after_repeat: Dictionary = save_manager.get_slot_data(1)
	var repeat_quests: Dictionary = after_repeat.get("quests", {}) as Dictionary
	var repeat_state: Dictionary = repeat_quests.get("first_scavenger_hunt", {}) as Dictionary
	var repeat_progress: Dictionary = repeat_state.get("progress", {}) as Dictionary
	if int(repeat_progress.get(QuestStateScript.kill_progress_key("scavenger"), 0)) > 1:
		_errors.append("QuestKillTracker3D should not double count the same enemy death.")

	var base_screen: BaseScreen = BaseScreenScene.instantiate()
	root.add_child(base_screen)
	await process_frame
	base_screen.refresh()
	var ready_state: Dictionary = base_screen.get_display_state()
	if str(ready_state.get("quest_id", "")) != "first_scavenger_hunt":
		_errors.append("Base should show the ready Scavenger kill quest.")
	if bool(ready_state.get("submit_quest_disabled", true)):
		_errors.append("Base submit button should enable for ready Scavenger kill quest.")

	var claim_result: Dictionary = base_screen.submit_first_scavenger_hunt_quest()
	if not bool(claim_result.get("success", false)):
		_errors.append("BaseScreen should submit First Scavenger Hunt when ready.")
	var after_claim: Dictionary = save_manager.get_slot_data(1)
	if int(after_claim.get("money", 0)) != int(FirstScavengerHuntQuest.get("reward_money")):
		_errors.append("Submitting First Scavenger Hunt should save reward money.")
	var claimed_quests: Dictionary = after_claim.get("quests", {}) as Dictionary
	var claimed_state: Dictionary = claimed_quests.get("first_scavenger_hunt", {}) as Dictionary
	if str(claimed_state.get("state", "")) != QuestStateScript.STATE_COMPLETED:
		_errors.append("Submitting First Scavenger Hunt should save completed quest state.")

	_free_node(base_screen)
	_free_node(enemy)
	_cleanup_validation_root(save_manager.save_root_path)
	_free_created_save_manager()


func _validate_quest_ui_layout() -> void:
	var save_manager := _make_save_manager()
	_cleanup_validation_root(save_manager.save_root_path)
	save_manager.set_current_slot_index(1)
	save_manager.save_slot_data(1, {
		"difficulty_id": "normal",
		"money": 0,
		"stash": [],
		"base_upgrades": {},
		"quests": {
			"first_salvage": {
				"id": "first_salvage",
				"state": QuestStateScript.STATE_READY,
				"progress": {WIRE_PATH: 1},
				"claimed": false,
			},
		},
	})
	for viewport_size in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		root.content_scale_size = Vector2i(int(viewport_size.x), int(viewport_size.y))
		root.size = Vector2i(int(viewport_size.x), int(viewport_size.y))
		var screen: BaseScreen = BaseScreenScene.instantiate()
		root.add_child(screen)
		screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
		screen.size = viewport_size
		await process_frame
		screen.refresh()
		await process_frame
		var state: Dictionary = screen.get_display_state()
		var panel_rect := state.get("panel_global_rect", state.get("panel_rect")) as Rect2
		var submit_rect := state.get("submit_quest_button_rect") as Rect2
		if panel_rect.end.x > viewport_size.x or panel_rect.end.y > viewport_size.y:
			_errors.append("Base quest UI should fit inside %s." % viewport_size)
		if submit_rect.position.x < panel_rect.position.x or submit_rect.end.x > panel_rect.end.x:
			_errors.append("Quest submit button should stay horizontally inside Base panel at %s." % viewport_size)
		if submit_rect.size.y < 44.0:
			_errors.append("Quest submit button should keep early button height at %s." % viewport_size)
		if str(state.get("quest_name", "")) == "" or str(state.get("quest_objective", "")) == "" or str(state.get("quest_progress", "")) == "":
			_errors.append("Quest UI should expose title, objective, and progress text.")
		_free_node(screen)
	_cleanup_validation_root(save_manager.save_root_path)
	_free_created_save_manager()


func _make_save_manager() -> Node:
	var existing := root.get_node_or_null("SaveGameManager")
	if existing != null:
		existing.save_root_path = "user://validation_quest_flow"
		return existing
	var save_manager := SaveGameManagerScript.new()
	save_manager.name = "SaveGameManager"
	save_manager.save_root_path = "user://validation_quest_flow"
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
