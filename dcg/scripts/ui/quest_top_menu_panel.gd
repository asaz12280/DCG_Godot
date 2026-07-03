class_name QuestTopMenuPanel
extends Control

const UIStyleScript := preload("res://scripts/ui/ui_style.gd")
const UILayoutScript := preload("res://scripts/ui/ui_layout.gd")
const UITextScript := preload("res://scripts/ui/ui_text.gd")
const BaseScreenViewModelScript := preload("res://scripts/base/base_screen_view_model.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")

@export var design_panel_size := Vector2(760.0, 500.0)
@export var design_top_margin := 126.0

@onready var main_panel: PanelContainer = %MainPanel
@onready var title_label: Label = %TitleLabel
@onready var hint_label: Label = %HintLabel
@onready var first_name_label: Label = %FirstQuestNameLabel
@onready var first_objective_label: Label = %FirstQuestObjectiveLabel
@onready var first_progress_label: Label = %FirstQuestProgressLabel
@onready var first_status_label: Label = %FirstQuestStatusLabel
@onready var second_name_label: Label = %SecondQuestNameLabel
@onready var second_objective_label: Label = %SecondQuestObjectiveLabel
@onready var second_progress_label: Label = %SecondQuestProgressLabel
@onready var second_status_label: Label = %SecondQuestStatusLabel
@onready var third_name_label: Label = %ThirdQuestNameLabel
@onready var third_objective_label: Label = %ThirdQuestObjectiveLabel
@onready var third_progress_label: Label = %ThirdQuestProgressLabel
@onready var third_status_label: Label = %ThirdQuestStatusLabel

var is_open := false
var _quest_summaries: Array[Dictionary] = []
var _save_manager_node: Node = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_styles()
	_apply_responsive_layout()
	_connect_save_manager()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.connect(_apply_responsive_layout)
	refresh()


func open_quests() -> void:
	is_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh()
	_apply_responsive_layout()


func close_quests() -> void:
	is_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	title_label.text = _text(&"ui.top.quest_panel_title", "任務清單")
	hint_label.text = _text(&"ui.top.quest_panel_hint", "追蹤目前可完成的回收與擊殺目標。")
	var save_data := _current_save_data()
	_quest_summaries = _build_quest_summaries(save_data)
	_apply_quest_summary(0, first_name_label, first_objective_label, first_progress_label, first_status_label)
	_apply_quest_summary(1, second_name_label, second_objective_label, second_progress_label, second_status_label)
	_apply_quest_summary(2, third_name_label, third_objective_label, third_progress_label, third_status_label)


func get_display_state() -> Dictionary:
	var viewport_size := get_viewport_rect().size if is_inside_tree() else Vector2(1920.0, 1080.0)
	return get_display_state_for_viewport(viewport_size)


func get_display_state_for_viewport(viewport_size: Vector2) -> Dictionary:
	var rect := _layout_for_viewport(viewport_size)
	return {
		"visible": visible,
		"is_open": is_open,
		"title": title_label.text,
		"hint": hint_label.text,
		"quest_count": _quest_summaries.size(),
		"quests": _quest_summaries.duplicate(true),
		"panel_rect": rect,
		"mouse_filter": mouse_filter,
	}


func preview_layout(viewport_size: Vector2) -> Rect2:
	return _layout_for_viewport(viewport_size)


func _apply_styles() -> void:
	UIStyleScript.apply_overlay_panel_style(main_panel)
	for label in [title_label, first_name_label, second_name_label, third_name_label]:
		UIStyleScript.apply_font_size(label, UIStyleScript.FONT_BODY)
		UIStyleScript.apply_font_color(label, UIStyleScript.COLOR_TEXT_PRIMARY)
	for label in [hint_label, first_objective_label, second_objective_label, third_objective_label]:
		UIStyleScript.apply_font_size(label, UIStyleScript.FONT_PLACEHOLDER)
		UIStyleScript.apply_font_color(label, UIStyleScript.COLOR_TEXT_HELP)
	for label in [first_progress_label, second_progress_label, third_progress_label, first_status_label, second_status_label, third_status_label]:
		UIStyleScript.apply_font_size(label, UIStyleScript.FONT_PLACEHOLDER)
		UIStyleScript.apply_font_color(label, UIStyleScript.COLOR_TEXT_STATUS)


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1920.0, 1080.0)
	var rect := _layout_for_viewport(viewport_size)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = rect.position
	size = rect.size


func _layout_for_viewport(viewport_size: Vector2) -> Rect2:
	return UILayoutScript.centered_top_rect(viewport_size, design_panel_size, design_top_margin, 0.68, 1.0)


func _build_quest_summaries(save_data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for quest_def in BaseScreenViewModelScript.quest_defs():
		var quest_state := BaseScreenViewModelScript.quest_state(save_data, quest_def)
		result.append({
			"id": str(quest_def.get("id")),
			"name": str(quest_def.get("display_name")),
			"objective": BaseScreenViewModelScript.quest_objective_text(self, quest_def),
			"progress": BaseScreenViewModelScript.quest_progress_text(self, quest_state, quest_def),
			"status": _status_text(quest_state),
			"state": str(quest_state.get("state", QuestStateScript.STATE_ACTIVE)),
		})
	return result


func _apply_quest_summary(index: int, name_label: Label, objective_label: Label, progress_label: Label, status_label: Label) -> void:
	if index >= _quest_summaries.size():
		name_label.text = _text(&"ui.top.quest_empty", "沒有任務")
		objective_label.text = ""
		progress_label.text = ""
		status_label.text = ""
		return
	var summary := _quest_summaries[index]
	name_label.text = str(summary.get("name", ""))
	objective_label.text = str(summary.get("objective", ""))
	progress_label.text = str(summary.get("progress", ""))
	status_label.text = str(summary.get("status", ""))


func _status_text(quest_state: Dictionary) -> String:
	match str(quest_state.get("state", QuestStateScript.STATE_ACTIVE)):
		QuestStateScript.STATE_COMPLETED:
			return _text(&"ui.base.quest_completed", "已完成")
		QuestStateScript.STATE_READY:
			return _text(&"ui.base.quest_ready", "可回報")
		QuestStateScript.STATE_INACTIVE:
			return _text(&"ui.top.quest_inactive", "未啟用")
		_:
			return _text(&"ui.base.quest_active", "進行中")


func _current_save_data() -> Dictionary:
	var save_manager := _save_manager()
	if save_manager == null:
		return {}
	var slot_index := 1
	if save_manager.has_method("get_current_slot_index"):
		slot_index = int(save_manager.call("get_current_slot_index"))
	if save_manager.has_method("get_slot_data"):
		return save_manager.call("get_slot_data", slot_index) as Dictionary
	return {}


func _connect_save_manager() -> void:
	var save_manager := _save_manager()
	if save_manager == null or save_manager == _save_manager_node:
		return
	_save_manager_node = save_manager
	if save_manager.has_signal("slot_saved"):
		var callback := Callable(self, "_on_slot_saved")
		if not save_manager.is_connected("slot_saved", callback):
			save_manager.connect("slot_saved", callback)


func _on_slot_saved(_slot_index: int, _save_data: Dictionary) -> void:
	if is_open:
		call_deferred("refresh")


func _save_manager() -> Node:
	if is_inside_tree():
		var node := get_node_or_null("/root/SaveGameManager")
		if node != null:
			return node
	return null


func _text(key: StringName, fallback: String) -> String:
	return UITextScript.text(self, key, fallback)
