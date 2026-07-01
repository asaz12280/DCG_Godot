class_name RaidResultPanel
extends Control

signal continue_to_base_requested(result: Dictionary)

const ResultUIStyle := preload("res://scripts/ui/ui_style.gd")
const RaidResultSchema := preload("res://scripts/raid/raid_result.gd")
const BASE_SCENE := "res://scenes/base/base_screen.tscn"

@export var raid_session_path: NodePath = NodePath("../../RaidSession")

@onready var background: ColorRect = %Background
@onready var main_panel: PanelContainer = %MainPanel
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var outcome_label: Label = %OutcomeLabel
@onready var duration_label: Label = %DurationLabel
@onready var money_label: Label = %MoneyLabel
@onready var extracted_rows: VBoxContainer = %ExtractedRows
@onready var lost_rows: VBoxContainer = %LostRows
@onready var safe_pocket_rows: VBoxContainer = %SafePocketRows
@onready var status_label: Label = %StatusLabel
@onready var continue_button: Button = %ContinueButton

var current_result: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_styles()
	continue_button.pressed.connect(_on_continue_pressed)
	resized.connect(_layout_panel)
	_connect_raid_session()
	_layout_panel()


func show_result(result: Dictionary) -> void:
	current_result = RaidResultSchema.create(str(result.get("outcome", "")), result)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_bind_result()
	_layout_panel.call_deferred()


func get_display_state() -> Dictionary:
	return {
		"visible": visible,
		"title": title_label.text,
		"outcome": outcome_label.text,
		"duration": duration_label.text,
		"money": money_label.text,
		"extracted_rows": extracted_rows.get_child_count(),
		"lost_rows": lost_rows.get_child_count(),
		"safe_pocket_rows": safe_pocket_rows.get_child_count(),
		"continue_text": continue_button.text,
		"panel_rect": Rect2(main_panel.position, main_panel.size),
		"button_rect": Rect2(continue_button.global_position, continue_button.size),
	}


func _apply_styles() -> void:
	ResultUIStyle.apply_overlay_panel_style(main_panel)
	ResultUIStyle.apply_font_size(title_label, ResultUIStyle.FONT_PANEL_TITLE)
	ResultUIStyle.apply_font_color(title_label, ResultUIStyle.COLOR_TEXT_PRIMARY)
	ResultUIStyle.apply_font_size(subtitle_label, ResultUIStyle.FONT_BODY)
	ResultUIStyle.apply_font_color(subtitle_label, ResultUIStyle.COLOR_TEXT_HELP)
	for label in [outcome_label, duration_label, money_label]:
		ResultUIStyle.apply_font_size(label, ResultUIStyle.FONT_BODY)
	for label in [%ExtractedTitleLabel, %LostTitleLabel, %SafePocketTitleLabel]:
		ResultUIStyle.apply_font_size(label, ResultUIStyle.FONT_BODY)
		ResultUIStyle.apply_font_color(label, ResultUIStyle.COLOR_TEXT_SUBTITLE)
	ResultUIStyle.apply_font_size(status_label, ResultUIStyle.FONT_PLACEHOLDER)
	ResultUIStyle.apply_font_color(status_label, ResultUIStyle.COLOR_TEXT_MUTED)
	ResultUIStyle.apply_font_size(continue_button, ResultUIStyle.FONT_BODY)


func _layout_panel() -> void:
	if main_panel == null:
		return
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	var outer_margin := 40.0 if viewport_size.x >= 1280.0 else 28.0
	var panel_size := Vector2(
		minf(1040.0, maxf(360.0, viewport_size.x - outer_margin * 2.0)),
		minf(640.0, maxf(360.0, viewport_size.y - outer_margin * 2.0))
	)
	main_panel.position = Vector2(
		floor((viewport_size.x - panel_size.x) * 0.5),
		floor((viewport_size.y - panel_size.y) * 0.5)
	)
	main_panel.size = panel_size


func _connect_raid_session() -> void:
	var session := get_node_or_null(raid_session_path)
	if session == null or not session.has_signal("raid_completed"):
		return
	if not session.raid_completed.is_connected(show_result):
		session.raid_completed.connect(show_result)


func _bind_result() -> void:
	title_label.text = _text(&"ui.raid_result.title", "Raid Result")
	subtitle_label.text = _text(&"ui.raid_result.subtitle", "Review what happened before returning to base.")
	outcome_label.text = "%s: %s" % [_text(&"ui.raid_result.outcome", "Outcome"), _outcome_text(str(current_result.get("outcome", "")))]
	duration_label.text = "%s: %.1fs" % [_text(&"ui.raid_result.duration", "Duration"), float(current_result.get("duration", 0.0))]
	money_label.text = "%s: %+d" % [_text(&"ui.raid_result.money_delta", "Money"), int(current_result.get("money_delta", 0))]
	continue_button.text = _text(&"ui.raid_result.continue_to_base", "Continue to Base")
	status_label.text = _text(&"ui.raid_result.status", "Inventory transfer is handled by the raid result flow.")
	_rebuild_rows(extracted_rows, current_result.get("extracted_items", []), _text(&"ui.raid_result.empty_extracted", "No extracted items."))
	_rebuild_rows(lost_rows, current_result.get("lost_items", []), _text(&"ui.raid_result.empty_lost", "No lost items."))
	_rebuild_rows(safe_pocket_rows, current_result.get("kept_safe_pocket_items", []), _text(&"ui.raid_result.empty_safe_pocket", "No safe pocket items."))


func _rebuild_rows(container: VBoxContainer, entries: Variant, empty_text: String) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	if typeof(entries) != TYPE_ARRAY or (entries as Array).is_empty():
		container.add_child(_make_item_row(empty_text, ""))
		return
	for entry in entries as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item_path := str(entry.get("item_path", ""))
		var quantity := int(entry.get("quantity", 1))
		container.add_child(_make_item_row(_item_name_from_path(item_path), "x%d" % quantity))
	if container.get_child_count() == 0:
		container.add_child(_make_item_row(empty_text, ""))


func _make_item_row(item_name: String, quantity_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 32.0)
	row.add_theme_constant_override("separation", 10)
	var name_label := Label.new()
	name_label.text = item_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ResultUIStyle.apply_font_size(name_label, ResultUIStyle.FONT_PLACEHOLDER)
	row.add_child(name_label)
	var quantity_label := Label.new()
	quantity_label.text = quantity_text
	quantity_label.custom_minimum_size = Vector2(52.0, 0.0)
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ResultUIStyle.apply_font_size(quantity_label, ResultUIStyle.FONT_PLACEHOLDER)
	row.add_child(quantity_label)
	return row


func _item_name_from_path(item_path: String) -> String:
	if item_path == "" or not ResourceLoader.exists(item_path):
		return _text(&"item.unknown.name", "Unknown item")
	var item_def := load(item_path) as ItemDef
	if item_def == null:
		return _text(&"item.unknown.name", "Unknown item")
	var name_key := str(item_def.name_key)
	if name_key != "":
		var translated := tr(name_key)
		if translated != name_key:
			return translated
	return item_def.display_name if item_def.display_name != "" else str(item_def.id)


func _outcome_text(outcome: String) -> String:
	match outcome:
		RaidResultSchema.OUTCOME_EXTRACTED:
			return _text(&"ui.raid_result.extracted", "Extracted")
		RaidResultSchema.OUTCOME_DEAD:
			return _text(&"ui.raid_result.dead", "Dead")
		_:
			return _text(&"ui.raid_result.unknown", "Unknown")


func _text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	var translated := tr(key_text)
	return fallback if translated == key_text else translated


func _on_continue_pressed() -> void:
	continue_to_base_requested.emit(current_result.duplicate(true))
	if is_inside_tree():
		get_tree().change_scene_to_file(BASE_SCENE)
