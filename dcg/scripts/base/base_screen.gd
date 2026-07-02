extends Control
class_name BaseScreen

const BaseUIStyle := preload("res://scripts/ui/ui_style.gd")
const BaseScreenActionsScript := preload("res://scripts/base/base_screen_actions.gd")
const BaseScreenViewModelScript := preload("res://scripts/base/base_screen_view_model.gd")
const BaseScreenStashRowsScript := preload("res://scripts/base/base_screen_stash_rows.gd")
const BaseProgressionScript := preload("res://scripts/base/base_progression.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")
const WORKBENCH_LEVEL_1 := preload("res://data/base_upgrades/workbench_level_1.tres")
const GAMEPLAY_SCENE := "res://scenes/gameplay/player_test_world_3d.tscn"

@export var current_slot_index: int = 1

@onready var main_panel: PanelContainer = %MainPanel
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var phase_banner: PanelContainer = %PhaseBanner
@onready var phase_label: Label = %PhaseLabel
@onready var phase_hint_label: Label = %PhaseHintLabel
@onready var slot_label: Label = %SlotLabel
@onready var difficulty_label: Label = %DifficultyLabel
@onready var money_label: Label = %MoneyLabel
@onready var stash_title_label: Label = %StashTitleLabel
@onready var stash_rows: VBoxContainer = %StashRows
@onready var workbench_title_label: Label = %WorkbenchTitleLabel
@onready var workbench_name_label: Label = %WorkbenchNameLabel
@onready var workbench_description_label: Label = %WorkbenchDescriptionLabel
@onready var workbench_cost_label: Label = %WorkbenchCostLabel
@onready var workbench_status_label: Label = %WorkbenchStatusLabel
@onready var upgrade_workbench_button: Button = %UpgradeWorkbenchButton
@onready var quest_title_label: Label = %QuestTitleLabel
@onready var quest_name_label: Label = %QuestNameLabel
@onready var quest_objective_label: Label = %QuestObjectiveLabel
@onready var quest_progress_label: Label = %QuestProgressLabel
@onready var quest_status_label: Label = %QuestStatusLabel
@onready var submit_quest_button: Button = %SubmitQuestButton
@onready var status_label: Label = %StatusLabel
@onready var sell_all_junk_button: Button = %SellAllJunkButton
@onready var start_raid_button: Button = %StartRaidButton

var _current_save_data: Dictionary = {}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply_styles()
	upgrade_workbench_button.pressed.connect(_on_upgrade_workbench_pressed)
	submit_quest_button.pressed.connect(_on_submit_quest_pressed)
	sell_all_junk_button.pressed.connect(_on_sell_all_junk_pressed)
	start_raid_button.pressed.connect(_on_start_raid_pressed)
	resized.connect(_layout_panel)
	_layout_panel()
	refresh()


func refresh() -> void:
	_sync_current_slot_from_save_manager()
	var save_data := _get_current_save_data()
	var has_save := not save_data.is_empty()
	if not has_save:
		save_data = _empty_save_data()
	_current_save_data = save_data.duplicate(true)

	title_label.text = _text(&"ui.base.title", "基地")
	subtitle_label.text = _text(&"ui.base.subtitle", "整理倉庫、準備裝備，開始下一場行動。")
	phase_label.text = _text(&"ui.base.phase", "安全區 / 基地階段")
	phase_hint_label.text = _text(&"ui.base.phase_hint", "這裡不會戰鬥。確認倉庫、任務與工作台後再開始出擊。")
	slot_label.text = _text(&"ui.base.slot_format", "存檔 %d") % current_slot_index
	difficulty_label.text = "%s: %s" % [_text(&"ui.base.difficulty", "難度"), BaseScreenViewModelScript.difficulty_name(self, str(save_data.get("difficulty_id", "normal")))]
	money_label.text = "%s: $%d" % [_text(&"ui.base.money", "金錢"), int(save_data.get("money", 0))]
	stash_title_label.text = _text(&"ui.base.stash", "倉庫")
	workbench_title_label.text = _text(&"ui.base.workbench", "工作台")
	workbench_name_label.text = WORKBENCH_LEVEL_1.display_name
	workbench_description_label.text = WORKBENCH_LEVEL_1.description
	workbench_cost_label.text = "%s: %s" % [_text(&"ui.base.upgrade_cost", "需求"), BaseProgressionScript.describe_cost(WORKBENCH_LEVEL_1)]
	quest_title_label.text = _text(&"ui.base.quest", "任務")
	sell_all_junk_button.text = _text(&"ui.base.sell_all_junk", "出售雜物")
	upgrade_workbench_button.text = _text(&"ui.base.upgrade", "升級")
	start_raid_button.text = _text(&"ui.base.start_raid", "開始出擊")
	status_label.text = _text(&"ui.base.ready", "基地待命：整理物資後按「開始出擊」。") if has_save else _text(&"ui.base.no_save", "尚無存檔資料。先開始一場行動來建立進度。")
	_rebuild_stash_rows(save_data.get("stash", []))
	_update_sell_button(save_data.get("stash", []), has_save)
	_update_workbench_state(save_data, has_save)
	_update_quest_state(save_data, has_save)
	_layout_panel.call_deferred()


func get_stash_row_count() -> int:
	return stash_rows.get_child_count()


func get_display_state() -> Dictionary:
	return {
		"slot": slot_label.text,
		"title": title_label.text,
		"subtitle": subtitle_label.text,
		"phase": phase_label.text,
		"phase_hint": phase_hint_label.text,
		"difficulty": difficulty_label.text,
		"money": money_label.text,
		"stash_title": stash_title_label.text,
		"stash_rows": get_stash_row_count(),
		"workbench_title": workbench_title_label.text,
		"status": status_label.text,
		"quest_title": quest_title_label.text,
		"quest_id": _current_quest_id(),
		"sell_all_junk_disabled": sell_all_junk_button.disabled,
		"sell_all_junk_text": sell_all_junk_button.text,
		"workbench_name": workbench_name_label.text,
		"workbench_cost": workbench_cost_label.text,
		"workbench_status": workbench_status_label.text,
		"upgrade_workbench_disabled": upgrade_workbench_button.disabled,
		"upgrade_workbench_text": upgrade_workbench_button.text,
		"quest_name": quest_name_label.text,
		"quest_objective": quest_objective_label.text,
		"quest_progress": quest_progress_label.text,
		"quest_status": quest_status_label.text,
		"submit_quest_disabled": submit_quest_button.disabled,
		"submit_quest_text": submit_quest_button.text,
		"panel_rect": Rect2(main_panel.position, main_panel.size),
		"panel_global_rect": Rect2(main_panel.global_position, main_panel.size),
		"phase_banner_rect": Rect2(phase_banner.global_position, phase_banner.size),
		"upgrade_button_rect": Rect2(upgrade_workbench_button.global_position, upgrade_workbench_button.size),
		"submit_quest_button_rect": Rect2(submit_quest_button.global_position, submit_quest_button.size),
		"sell_button_rect": Rect2(sell_all_junk_button.global_position, sell_all_junk_button.size),
		"start_button_rect": Rect2(start_raid_button.global_position, start_raid_button.size),
	}


func _apply_styles() -> void:
	BaseUIStyle.apply_overlay_panel_style(main_panel)
	phase_banner.add_theme_stylebox_override("panel", BaseUIStyle.make_base_phase_panel_style())
	BaseUIStyle.apply_font_size(title_label, BaseUIStyle.FONT_PANEL_TITLE)
	BaseUIStyle.apply_font_color(title_label, BaseUIStyle.COLOR_TEXT_PRIMARY)
	BaseUIStyle.apply_font_size(subtitle_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_color(subtitle_label, BaseUIStyle.COLOR_TEXT_HELP)
	BaseUIStyle.apply_font_size(phase_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_color(phase_label, BaseUIStyle.COLOR_TEXT_PRIMARY)
	BaseUIStyle.apply_font_size(phase_hint_label, BaseUIStyle.FONT_PLACEHOLDER)
	BaseUIStyle.apply_font_color(phase_hint_label, BaseUIStyle.COLOR_TEXT_HELP)
	BaseUIStyle.apply_font_size(slot_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_size(difficulty_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_size(money_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_size(stash_title_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_color(stash_title_label, BaseUIStyle.COLOR_TEXT_SUBTITLE)
	BaseUIStyle.apply_font_size(workbench_title_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_color(workbench_title_label, BaseUIStyle.COLOR_TEXT_SUBTITLE)
	BaseUIStyle.apply_font_size(workbench_name_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_color(workbench_name_label, BaseUIStyle.COLOR_TEXT_PRIMARY)
	BaseUIStyle.apply_font_size(workbench_description_label, BaseUIStyle.FONT_PLACEHOLDER)
	BaseUIStyle.apply_font_color(workbench_description_label, BaseUIStyle.COLOR_TEXT_HELP)
	BaseUIStyle.apply_font_size(workbench_cost_label, BaseUIStyle.FONT_PLACEHOLDER)
	BaseUIStyle.apply_font_size(workbench_status_label, BaseUIStyle.FONT_PLACEHOLDER)
	BaseUIStyle.apply_font_color(workbench_status_label, BaseUIStyle.COLOR_TEXT_STATUS)
	BaseUIStyle.apply_font_size(upgrade_workbench_button, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_size(quest_title_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_color(quest_title_label, BaseUIStyle.COLOR_TEXT_SUBTITLE)
	BaseUIStyle.apply_font_size(quest_name_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_color(quest_name_label, BaseUIStyle.COLOR_TEXT_PRIMARY)
	BaseUIStyle.apply_font_size(quest_objective_label, BaseUIStyle.FONT_PLACEHOLDER)
	BaseUIStyle.apply_font_color(quest_objective_label, BaseUIStyle.COLOR_TEXT_HELP)
	BaseUIStyle.apply_font_size(quest_progress_label, BaseUIStyle.FONT_PLACEHOLDER)
	BaseUIStyle.apply_font_size(quest_status_label, BaseUIStyle.FONT_PLACEHOLDER)
	BaseUIStyle.apply_font_color(quest_status_label, BaseUIStyle.COLOR_TEXT_STATUS)
	BaseUIStyle.apply_font_size(submit_quest_button, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_size(status_label, BaseUIStyle.FONT_PLACEHOLDER)
	BaseUIStyle.apply_font_color(status_label, BaseUIStyle.COLOR_TEXT_MUTED)
	BaseUIStyle.apply_font_size(sell_all_junk_button, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_size(start_raid_button, BaseUIStyle.FONT_BODY)


func _layout_panel() -> void:
	if main_panel == null:
		return
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	var outer_margin := 48.0 if viewport_size.x >= 1280.0 else 32.0
	var panel_size := Vector2(
		minf(980.0, maxf(320.0, viewport_size.x - outer_margin * 2.0)),
		minf(640.0, maxf(320.0, viewport_size.y - outer_margin * 2.0))
	)
	main_panel.position = Vector2(
		floor((viewport_size.x - panel_size.x) * 0.5),
		floor((viewport_size.y - panel_size.y) * 0.5)
	)
	main_panel.size = panel_size


func _rebuild_stash_rows(stash_data: Variant) -> void:
	BaseScreenStashRowsScript.rebuild(self, stash_rows, stash_data)


func sell_all_junk() -> Dictionary:
	var save_manager := _get_save_manager()
	if save_manager == null or not save_manager.has_method("save_slot_data"):
		return {}
	var save_data := _get_current_save_data()
	if save_data.is_empty():
		return {}
	var stash_data: Array = _stash_array_from_variant(save_data.get("stash", []))
	var result: Dictionary = BaseScreenActionsScript.sell_all_junk(stash_data, int(save_data.get("money", 0)))
	if int(result.get("money_delta", 0)) <= 0:
		status_label.text = _text(&"ui.base.sell_none", "沒有可出售的雜物。")
		_update_sell_button(stash_data, true)
		return result

	save_data["money"] = int(result.get("money", 0))
	save_data["stash"] = (result.get("remaining_stash", []) as Array).duplicate(true)
	if not save_manager.save_slot_data(current_slot_index, save_data):
		status_label.text = _text(&"ui.base.sell_failed", "無法保存出售結果。")
		return {}

	_current_save_data = save_data.duplicate(true)
	money_label.text = "%s: $%d" % [_text(&"ui.base.money", "金錢"), int(save_data.get("money", 0))]
	_rebuild_stash_rows(save_data.get("stash", []))
	_update_sell_button(save_data.get("stash", []), true)
	_update_workbench_state(save_data, true)
	_update_quest_state(save_data, true)
	status_label.text = "%s +$%d" % [_text(&"ui.base.sell_success", "已出售雜物"), int(result.get("money_delta", 0))]
	return result


func upgrade_workbench() -> Dictionary:
	var save_manager := _get_save_manager()
	if save_manager == null or not save_manager.has_method("save_slot_data"):
		return {}
	var save_data := _get_current_save_data()
	if save_data.is_empty():
		return {}
	var result: Dictionary = BaseProgressionScript.purchase_upgrade(save_data, WORKBENCH_LEVEL_1)
	if not bool(result.get("success", false)):
		status_label.text = BaseScreenViewModelScript.upgrade_failure_text(self, str(result.get("reason", "unknown")))
		_update_workbench_state(save_data, true)
		return result

	var updated: Dictionary = result.get("save_data", {}) as Dictionary
	if not save_manager.save_slot_data(current_slot_index, updated):
		status_label.text = _text(&"ui.base.upgrade_save_failed", "無法保存升級結果。")
		return {}

	_current_save_data = updated.duplicate(true)
	money_label.text = "%s: $%d" % [_text(&"ui.base.money", "金錢"), int(updated.get("money", 0))]
	_rebuild_stash_rows(updated.get("stash", []))
	_update_sell_button(updated.get("stash", []), true)
	_update_workbench_state(updated, true)
	_update_quest_state(updated, true)
	status_label.text = _text(&"ui.base.upgrade_success", "工作台已升級。下一場行動備用彈藥 +1。")
	return result


func submit_first_salvage_quest() -> Dictionary:
	return _submit_quest(BaseScreenViewModelScript.first_salvage_quest())


func submit_first_scavenger_hunt_quest() -> Dictionary:
	return _submit_quest(BaseScreenViewModelScript.first_scavenger_hunt_quest())


func submit_current_quest() -> Dictionary:
	return _submit_quest(BaseScreenViewModelScript.selected_quest_def(_get_current_save_data()))


func _submit_quest(quest_def: Resource) -> Dictionary:
	var save_manager := _get_save_manager()
	if quest_def == null or save_manager == null or not save_manager.has_method("save_slot_data"):
		return {}
	var save_data := _get_current_save_data()
	if save_data.is_empty():
		return {}
	var quests: Dictionary = BaseScreenViewModelScript.quests_dict(save_data.get("quests", {}))
	var quest_id := str(quest_def.get("id"))
	var quest_state: Dictionary = quests.get(quest_id, QuestStateScript.create(quest_def)) as Dictionary
	var result: Dictionary = QuestStateScript.claim_reward(save_data, quest_state, quest_def)
	if not bool(result.get("success", false)):
		status_label.text = _text(&"ui.base.quest_not_ready", "任務尚未達成，無法回報。")
		_update_quest_state(save_data, true)
		return result

	var updated: Dictionary = result.get("save_data", {}) as Dictionary
	var updated_state: Dictionary = result.get("quest_state", {}) as Dictionary
	var updated_quests: Dictionary = BaseScreenViewModelScript.quests_dict(updated.get("quests", {}))
	updated_quests[quest_id] = updated_state
	updated["quests"] = updated_quests
	if not save_manager.save_slot_data(current_slot_index, updated):
		status_label.text = _text(&"ui.base.quest_save_failed", "無法保存任務獎勵。")
		return {}

	_current_save_data = updated.duplicate(true)
	money_label.text = "%s: $%d" % [_text(&"ui.base.money", "金錢"), int(updated.get("money", 0))]
	_update_quest_state(updated, true)
	status_label.text = "%s +$%d" % [_text(&"ui.base.quest_claimed", "任務完成"), int(quest_def.get("reward_money"))]
	return result


func _get_current_save_data() -> Dictionary:
	var save_manager := _get_save_manager()
	if save_manager == null or not save_manager.has_method("get_slot_data"):
		return {}

	var data: Dictionary = save_manager.get_slot_data(current_slot_index)
	if not data.is_empty():
		return data

	if save_manager.has_method("list_slots"):
		for summary in save_manager.list_slots():
			if bool(summary.get("exists", false)):
				current_slot_index = int(summary.get("slot_index", current_slot_index))
				if save_manager.has_method("set_current_slot_index"):
					save_manager.set_current_slot_index(current_slot_index)
				return save_manager.get_slot_data(current_slot_index)
	return {}


func _update_sell_button(stash_data: Variant, has_save: bool) -> void:
	var stash_array: Array = _stash_array_from_variant(stash_data)
	var sell_value := BaseScreenActionsScript.get_sellable_value(stash_array)
	sell_all_junk_button.disabled = not has_save or sell_value <= 0
	if sell_value > 0:
		sell_all_junk_button.text = "%s ($%d)" % [_text(&"ui.base.sell_all_junk", "出售雜物"), sell_value]


func _update_workbench_state(save_data: Dictionary, has_save: bool) -> void:
	var is_purchased := BaseProgressionScript.is_upgrade_purchased(save_data, WORKBENCH_LEVEL_1.id)
	var check: Dictionary = BaseProgressionScript.can_purchase_upgrade(save_data, WORKBENCH_LEVEL_1)
	if is_purchased:
		workbench_status_label.text = _text(&"ui.base.workbench_upgraded", "已升級：初始備用彈藥 +1")
		upgrade_workbench_button.text = _text(&"ui.base.upgraded", "已升級")
		upgrade_workbench_button.disabled = true
	elif not has_save:
		workbench_status_label.text = _text(&"ui.base.workbench_no_save", "先建立存檔才能升級。")
		upgrade_workbench_button.disabled = true
	else:
		workbench_status_label.text = BaseScreenViewModelScript.upgrade_ready_text(self, str(check.get("reason", "unknown")))
		upgrade_workbench_button.text = _text(&"ui.base.upgrade", "升級")
		upgrade_workbench_button.disabled = not bool(check.get("can_purchase", false))


func _update_quest_state(save_data: Dictionary, has_save: bool) -> void:
	var quest_def := BaseScreenViewModelScript.selected_quest_def(save_data)
	var quest_state := BaseScreenViewModelScript.quest_state(save_data, quest_def)
	quest_name_label.text = str(quest_def.get("display_name"))
	quest_objective_label.text = BaseScreenViewModelScript.quest_objective_text(self, quest_def)
	quest_progress_label.text = BaseScreenViewModelScript.quest_progress_text(self, quest_state, quest_def)
	var state := str(quest_state.get("state", QuestStateScript.STATE_ACTIVE))
	submit_quest_button.text = _text(&"ui.base.submit_quest", "回報任務")
	if not has_save:
		quest_status_label.text = _text(&"ui.base.quest_no_save", "請先建立存檔")
		submit_quest_button.disabled = true
	elif state == QuestStateScript.STATE_COMPLETED:
		quest_status_label.text = _text(&"ui.base.quest_completed", "已完成")
		submit_quest_button.text = _text(&"ui.base.completed", "已完成")
		submit_quest_button.disabled = true
	elif state == QuestStateScript.STATE_READY:
		quest_status_label.text = _text(&"ui.base.quest_ready", "可回報")
		submit_quest_button.disabled = false
	else:
		quest_status_label.text = _text(&"ui.base.quest_active", "進行中")
		submit_quest_button.disabled = true


func _stash_array_from_variant(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _get_save_manager() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/SaveGameManager")


func _sync_current_slot_from_save_manager() -> void:
	var save_manager := _get_save_manager()
	if save_manager != null and save_manager.has_method("get_current_slot_index"):
		current_slot_index = int(save_manager.get_current_slot_index())


func _empty_save_data() -> Dictionary:
	return {
		"difficulty_id": "normal",
		"money": 0,
		"stash": [],
	}


func _text(key: StringName, fallback: String) -> String:
	return BaseScreenViewModelScript.text(self, key, fallback)


func _current_quest_id() -> String:
	var save_data := _current_save_data
	if save_data.is_empty():
		save_data = _get_current_save_data()
	var quest_def := BaseScreenViewModelScript.selected_quest_def(save_data)
	if quest_def == null:
		return ""
	return str(quest_def.get("id"))


func _on_start_raid_pressed() -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file(GAMEPLAY_SCENE)


func _on_sell_all_junk_pressed() -> void:
	sell_all_junk()


func _on_upgrade_workbench_pressed() -> void:
	upgrade_workbench()


func _on_submit_quest_pressed() -> void:
	submit_current_quest()
