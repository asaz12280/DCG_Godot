extends SceneTree

const ACCEPTANCE_PATH := "res://docs/tasks/dev_slice_0_1_acceptance.md"
const TASK_QUEUE_PATH := "res://docs/tasks/automation_task_queue.md"
const PLAN_PATH := "res://docs/design/early_development_plan.md"
const CONTENT_GUIDE_PATH := "res://docs/design/content_authoring_guide.md"
const GAMEPLAY_SCENE_PATH := "res://scenes/gameplay/player_test_world_3d.tscn"

var _errors: Array[String] = []


func _initialize() -> void:
	_validate_required_files()
	if _errors.is_empty():
		_validate_acceptance_report()
		_validate_task_queue()
		_validate_plan_gate()
		_validate_project_paths()
	if _errors.is_empty():
		print("[dev_slice_acceptance] OK checklist=documented gate=locked validations=listed")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		quit(1)


func _validate_required_files() -> void:
	for path in [
		ACCEPTANCE_PATH,
		TASK_QUEUE_PATH,
		PLAN_PATH,
		CONTENT_GUIDE_PATH,
	]:
		if not FileAccess.file_exists(path):
			_errors.append("Missing required Dev Slice 0.1 acceptance file: %s" % path)


func _validate_acceptance_report() -> void:
	var text := FileAccess.get_file_as_string(ACCEPTANCE_PATH)
	for heading in [
		"# Project DCG Dev Slice 0.1 Acceptance",
		"## Status",
		"## Acceptance Checklist",
		"## Required Validation Set",
		"## Project Health Check",
		"## Technical Debt",
		"## Decision Gate",
	]:
		if not text.contains(heading):
			_errors.append("Acceptance report is missing heading: %s" % heading)

	for phrase in [
		"Automated acceptance: PASSED.",
		"content expansion remains locked until the user approves",
		"Do not start repeated content expansion until the user explicitly approves Dev Slice 0.1.",
		"validate_three_raid_loop.gd",
		"validate_dev_slice_acceptance.gd",
		"res://scenes/gameplay/player_test_world_3d.tscn",
	]:
		if not text.contains(phrase):
			_errors.append("Acceptance report is missing required phrase: %s" % phrase)

	for checklist_item in [
		"Main menu starts a new save",
		"Base screen displays persistent stash",
		"Raid map starts from base",
		"Player can loot, fight, and extract",
		"Extracted items enter stash",
		"Death loses raid backpack items",
		"Save/load restores stash and money",
		"At least one upgrade consumes extracted loot",
		"At least one quest gives direction",
		"Existing validation suite passes",
		"The loop is repeatable for at least three raids",
	]:
		if not text.contains(checklist_item):
			_errors.append("Acceptance report is missing checklist item: %s" % checklist_item)

	for validation_script in _required_validation_scripts():
		if not text.contains(validation_script):
			_errors.append("Acceptance report should list validation script: %s" % validation_script)


func _validate_task_queue() -> void:
	var text := FileAccess.get_file_as_string(TASK_QUEUE_PATH)
	var task_index := text.find("## 任務三十：Dev Slice 0.1 驗收與鎖定擴充門檻")
	if task_index < 0:
		_errors.append("Task queue is missing task thirty.")
		return
	var task_text := text.substr(task_index, 220)
	if not task_text.contains("狀態：完成"):
		_errors.append("Task thirty should be marked complete after Dev Slice 0.1 acceptance.")


func _validate_plan_gate() -> void:
	var text := FileAccess.get_file_as_string(PLAN_PATH)
	for phrase in [
		"Approval Target For Dev Slice 0.1",
		"Do not expand content volume until this checklist is true",
		"Dev Slice 0.1 automated acceptance passed on 2026-07-02",
		"Repeated content expansion remains locked until user approval",
	]:
		if not text.contains(phrase):
			_errors.append("Early development plan is missing approval gate phrase: %s" % phrase)


func _validate_project_paths() -> void:
	var tool_root := "res://tools/"
	for validation_script in _required_validation_scripts():
		var script_path := tool_root + validation_script
		if not FileAccess.file_exists(script_path):
			_errors.append("Missing validation script listed by acceptance report: %s" % script_path)
	if not ResourceLoader.exists(GAMEPLAY_SCENE_PATH):
		_errors.append("Gameplay scene should exist for final startup validation: %s" % GAMEPLAY_SCENE_PATH)


func _required_validation_scripts() -> Array[String]:
	return [
		"validate_item_catalog.gd",
		"validate_ui_foundation.gd",
		"validate_inventory_drag_rules.gd",
		"validate_gameplay_architecture.gd",
		"validate_combat_domain.gd",
		"validate_difficulty_system.gd",
		"validate_save_slots.gd",
		"validate_save_slot_panel.gd",
		"validate_audio_settings.gd",
		"validate_pause_menu.gd",
		"validate_stash_model.gd",
		"validate_base_screen.gd",
		"validate_base_flow.gd",
		"validate_raid_session.gd",
		"validate_extraction_flow.gd",
		"validate_raid_result_panel.gd",
		"validate_loot_tables.gd",
		"validate_loot_container.gd",
		"validate_enemy_def.gd",
		"validate_enemy_ai.gd",
		"validate_enemy_loot_drop.gd",
		"validate_player_damage.gd",
		"validate_vendor_sell.gd",
		"validate_base_progression.gd",
		"validate_quest_model.gd",
		"validate_quest_flow.gd",
		"validate_raid_hud.gd",
		"validate_ui_text_quality.gd",
		"validate_early_balance.gd",
		"validate_content_authoring_guide.gd",
		"validate_three_raid_loop.gd",
		"validate_dev_slice_acceptance.gd",
	]
