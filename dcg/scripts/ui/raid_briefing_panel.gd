class_name RaidBriefingPanel
extends Control

signal start_raid_requested
signal cancel_requested

const UIStyle := preload("res://scripts/ui/ui_style.gd")
const UILayout := preload("res://scripts/ui/ui_layout.gd")

const PANEL_DESIGN_SIZE := Vector2(820.0, 430.0)
const ACTION_BUTTON_SIZE := Vector2(160.0, 46.0)

@onready var main_panel: PanelContainer = %MainPanel
@onready var title_label: Label = %TitleLabel
@onready var location_label: Label = %LocationLabel
@onready var risk_label: Label = %RiskLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var loadout_label: Label = %LoadoutLabel
@onready var hint_label: Label = %HintLabel
@onready var start_button: Button = %StartButton
@onready var cancel_button: Button = %CancelButton

var active_context: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	UIStyle.apply_overlay_panel_style(main_panel)
	_style_label(title_label, UIStyle.FONT_PANEL_TITLE, UIStyle.COLOR_TEXT_PRIMARY)
	_style_label(location_label, UIStyle.FONT_BODY, UIStyle.COLOR_TEXT_SUBTITLE)
	_style_label(risk_label, UIStyle.FONT_BODY, UIStyle.COLOR_TEXT_HELP)
	_style_label(objective_label, UIStyle.FONT_BODY, UIStyle.COLOR_TEXT_HELP)
	_style_label(loadout_label, UIStyle.FONT_BODY, UIStyle.COLOR_TEXT_STATUS)
	_style_label(hint_label, UIStyle.FONT_HELP, UIStyle.COLOR_TEXT_MUTED)
	UIStyle.apply_font_size(start_button, UIStyle.FONT_BODY)
	UIStyle.apply_font_size(cancel_button, UIStyle.FONT_BODY)
	start_button.custom_minimum_size = ACTION_BUTTON_SIZE
	cancel_button.custom_minimum_size = ACTION_BUTTON_SIZE
	start_button.text = "開始出擊"
	cancel_button.text = "取消"
	start_button.pressed.connect(confirm_start)
	cancel_button.pressed.connect(cancel)
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout.call_deferred()


func open_briefing(context: Dictionary = {}) -> void:
	active_context = context.duplicate(true)
	title_label.text = "出擊簡報"
	location_label.text = "地點：%s" % str(active_context.get("location", "郊外回收區"))
	risk_label.text = "風險：%s" % str(active_context.get("risk", "偵測到拾荒者，會追蹤並近身攻擊。"))
	objective_label.text = "目標：%s" % str(active_context.get("objective", "搜索物資，保持距離，必要時裝填手槍反擊，前往撤離點。"))
	loadout_label.text = "攜帶：%s" % str(active_context.get("loadout_summary", "依目前裝備與背包出擊。"))
	hint_label.text = "確認後會離開基地並進入出擊關卡。"
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply_responsive_layout()
	start_button.grab_focus.call_deferred()


func confirm_start() -> void:
	if not visible:
		return
	close_panel(false)
	start_raid_requested.emit()


func cancel() -> void:
	if not visible:
		return
	close_panel(true)
	cancel_requested.emit()


func close_panel(restore_hidden_mouse := true) -> void:
	visible = false
	active_context.clear()
	if restore_hidden_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func is_open() -> bool:
	return visible


func get_display_state() -> Dictionary:
	return _state_from_rect(main_panel.get_global_rect())


func get_display_state_for_viewport(viewport_size: Vector2) -> Dictionary:
	return _state_from_rect(preview_layout(viewport_size))


func preview_layout(viewport_size: Vector2) -> Rect2:
	return UILayout.centered_content_rect(viewport_size, PANEL_DESIGN_SIZE, 0.72, 1.0)


func _apply_responsive_layout() -> void:
	if main_panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var rect := preview_layout(viewport_size)
	main_panel.position = rect.position
	main_panel.size = rect.size


func _state_from_rect(rect: Rect2) -> Dictionary:
	return {
		"visible": visible,
		"title": title_label.text if title_label != null else "",
		"location": location_label.text if location_label != null else "",
		"risk": risk_label.text if risk_label != null else "",
		"objective": objective_label.text if objective_label != null else "",
		"loadout": loadout_label.text if loadout_label != null else "",
		"hint": hint_label.text if hint_label != null else "",
		"start_button": start_button.text if start_button != null else "",
		"cancel_button": cancel_button.text if cancel_button != null else "",
		"panel_rect": rect,
		"start_button_min_size": start_button.custom_minimum_size if start_button != null else Vector2.ZERO,
		"cancel_button_min_size": cancel_button.custom_minimum_size if cancel_button != null else Vector2.ZERO,
	}


func _style_label(label: Label, font_size: int, color: Color) -> void:
	UIStyle.apply_font_size(label, font_size)
	UIStyle.apply_font_color(label, color)
