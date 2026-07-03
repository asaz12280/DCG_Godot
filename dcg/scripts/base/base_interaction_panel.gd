class_name BaseInteractionPanel
extends Control

signal action_requested(interaction_id: String)

const UIStyle := preload("res://scripts/ui/ui_style.gd")

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel
@onready var action_button: Button = %ActionButton
@onready var close_button: Button = %CloseButton

var active_interaction_id := ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	UIStyle.apply_overlay_panel_style(panel)
	UIStyle.apply_font_size(title_label, UIStyle.FONT_PANEL_TITLE)
	UIStyle.apply_font_color(title_label, UIStyle.COLOR_TEXT_PRIMARY)
	UIStyle.apply_font_size(body_label, UIStyle.FONT_BODY)
	UIStyle.apply_font_color(body_label, UIStyle.COLOR_TEXT_HELP)
	UIStyle.apply_font_size(action_button, UIStyle.FONT_BODY)
	UIStyle.apply_font_size(close_button, UIStyle.FONT_BODY)
	action_button.pressed.connect(_on_action_button_pressed)
	close_button.pressed.connect(close_panel)


func open_interaction(interaction_id: String, display_name: String, context: Dictionary = {}) -> void:
	active_interaction_id = interaction_id
	title_label.text = display_name
	body_label.text = str(context.get("body", _body_text(interaction_id)))
	action_button.visible = bool(context.get("action_visible", false))
	action_button.disabled = not bool(context.get("action_enabled", false))
	action_button.text = str(context.get("action_text", "執行"))
	close_button.text = "關閉"
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if action_button.visible and not action_button.disabled:
		action_button.grab_focus.call_deferred()
	else:
		close_button.grab_focus.call_deferred()


func update_interaction_state(context: Dictionary) -> void:
	body_label.text = str(context.get("body", body_label.text))
	if context.has("action_visible"):
		action_button.visible = bool(context.get("action_visible", action_button.visible))
	if context.has("action_enabled"):
		action_button.disabled = not bool(context.get("action_enabled", not action_button.disabled))
	if context.has("action_text"):
		action_button.text = str(context.get("action_text", action_button.text))


func close_panel() -> void:
	visible = false
	active_interaction_id = ""
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func is_open() -> bool:
	return visible


func get_display_state() -> Dictionary:
	return {
		"visible": visible,
		"interaction_id": active_interaction_id,
		"title": title_label.text if title_label != null else "",
		"body": body_label.text if body_label != null else "",
		"action_visible": action_button.visible if action_button != null else false,
		"action_enabled": not action_button.disabled if action_button != null else false,
		"action_text": action_button.text if action_button != null else "",
		"button": close_button.text if close_button != null else "",
	}


func _body_text(interaction_id: String) -> String:
	match interaction_id:
		"stash":
			return "倉庫面板已連接。後續會在這裡整理戰利品與裝備。"
		"quests":
			return "任務板已連接。後續會在這裡查看與回報任務。"
		"workbench":
			return "工作台已連接。後續會在這裡升級基地功能。"
		"medical":
			return "醫療站已連接。支付少量金錢即可回復生命。"
		_:
			return "基地互動點已連接。"


func _on_action_button_pressed() -> void:
	if active_interaction_id == "":
		return
	action_requested.emit(active_interaction_id)
