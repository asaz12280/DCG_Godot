class_name RaidResultPanel
extends Control

signal continue_to_base_requested(result: Dictionary)

const ResultUIStyle := preload("res://scripts/ui/ui_style.gd")
const UITextScript := preload("res://scripts/ui/ui_text.gd")
const RaidResultSchema := preload("res://scripts/raid/raid_result.gd")
const BASE_SCENE := "res://scenes/base/base_3d.tscn"

@export var raid_session_path: NodePath = NodePath("../../RaidSession")

@onready var background: ColorRect = %Background
@onready var main_panel: PanelContainer = %MainPanel
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var outcome_label: Label = %OutcomeLabel
@onready var duration_label: Label = %DurationLabel
@onready var money_label: Label = %MoneyLabel
@onready var transfer_banner: PanelContainer = %TransferBanner
@onready var transfer_title_label: Label = %TransferTitleLabel
@onready var transfer_detail_label: Label = %TransferDetailLabel
@onready var extracted_title_label: Label = %ExtractedTitleLabel
@onready var lost_title_label: Label = %LostTitleLabel
@onready var safe_pocket_title_label: Label = %SafePocketTitleLabel
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
		"transfer_title": transfer_title_label.text,
		"transfer_detail": transfer_detail_label.text,
		"extracted_title": extracted_title_label.text,
		"lost_title": lost_title_label.text,
		"safe_pocket_title": safe_pocket_title_label.text,
		"extracted_rows": extracted_rows.get_child_count(),
		"lost_rows": lost_rows.get_child_count(),
		"safe_pocket_rows": safe_pocket_rows.get_child_count(),
		"status": status_label.text,
		"continue_text": continue_button.text,
		"panel_rect": Rect2(main_panel.position, main_panel.size),
		"transfer_rect": Rect2(transfer_banner.global_position, transfer_banner.size),
		"button_rect": Rect2(continue_button.global_position, continue_button.size),
	}


func _apply_styles() -> void:
	ResultUIStyle.apply_overlay_panel_style(main_panel)
	transfer_banner.add_theme_stylebox_override("panel", ResultUIStyle.make_transfer_panel_style())
	ResultUIStyle.apply_font_size(title_label, ResultUIStyle.FONT_PANEL_TITLE)
	ResultUIStyle.apply_font_color(title_label, ResultUIStyle.COLOR_TEXT_PRIMARY)
	ResultUIStyle.apply_font_size(subtitle_label, ResultUIStyle.FONT_BODY)
	ResultUIStyle.apply_font_color(subtitle_label, ResultUIStyle.COLOR_TEXT_HELP)
	for label in [outcome_label, duration_label, money_label]:
		ResultUIStyle.apply_font_size(label, ResultUIStyle.FONT_BODY)
	ResultUIStyle.apply_font_size(transfer_title_label, ResultUIStyle.FONT_BODY)
	ResultUIStyle.apply_font_color(transfer_title_label, ResultUIStyle.COLOR_TEXT_PRIMARY)
	ResultUIStyle.apply_font_size(transfer_detail_label, ResultUIStyle.FONT_PLACEHOLDER)
	ResultUIStyle.apply_font_color(transfer_detail_label, ResultUIStyle.COLOR_TEXT_HELP)
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
	title_label.text = _text(&"ui.raid_result.title", "行動結算")
	subtitle_label.text = _text(&"ui.raid_result.subtitle", "檢視本次行動結果，確認帶回與遺失物資。")
	outcome_label.text = "%s: %s" % [_text(&"ui.raid_result.outcome", "結果"), _outcome_text(str(current_result.get("outcome", "")))]
	duration_label.text = "%s: %.1fs" % [_text(&"ui.raid_result.duration", "時間"), float(current_result.get("duration", 0.0))]
	money_label.text = "%s: %+d" % [_text(&"ui.raid_result.money_delta", "金錢"), int(current_result.get("money_delta", 0))]
	transfer_title_label.text = _text(&"ui.raid_result.transfer_title", "物資轉移")
	transfer_detail_label.text = _transfer_detail_text()
	extracted_title_label.text = _text(&"ui.raid_result.extracted_items", "帶回物品")
	lost_title_label.text = _text(&"ui.raid_result.lost_items", "遺失物品")
	safe_pocket_title_label.text = _text(&"ui.raid_result.safe_pocket_items", "安全口袋")
	continue_button.text = _text(&"ui.raid_result.continue_to_base", "回到基地")
	status_label.text = _status_text()
	_rebuild_rows(extracted_rows, current_result.get("extracted_items", []), _text(&"ui.raid_result.empty_extracted", "沒有帶回物品。"))
	_rebuild_rows(lost_rows, current_result.get("lost_items", []), _text(&"ui.raid_result.empty_lost", "沒有遺失物品。"))
	_rebuild_rows(safe_pocket_rows, current_result.get("kept_safe_pocket_items", []), _text(&"ui.raid_result.empty_safe_pocket", "安全口袋沒有物品。"))

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
	return UITextScript.item_name(self, item_path, "未知物品")

func _outcome_text(outcome: String) -> String:
	match outcome:
		RaidResultSchema.OUTCOME_EXTRACTED:
			return _text(&"ui.raid_result.extracted", "撤離成功：帶回物資")
		RaidResultSchema.OUTCOME_DEAD:
			return _text(&"ui.raid_result.dead", "行動失敗：死亡")
		_:
			return _text(&"ui.raid_result.unknown", "未知")

func _transfer_detail_text() -> String:
	var outcome := str(current_result.get("outcome", ""))
	var extracted_count := _entry_count(current_result.get("extracted_items", []))
	var lost_count := _entry_count(current_result.get("lost_items", []))
	var safe_count := _entry_count(current_result.get("kept_safe_pocket_items", []))
	if outcome == RaidResultSchema.OUTCOME_DEAD:
		return _text(&"ui.raid_result.transfer_dead", "行動失敗：%d 種背包/裝備物資列為遺失，%d 種安全口袋物品已送回基地。按「回到基地」查看狀態。") % [lost_count, safe_count]
	if extracted_count <= 0:
		return _text(&"ui.raid_result.transfer_empty", "本次沒有帶回物品。按「回到基地」整理下一場行動。")
	return _text(&"ui.raid_result.transfer_extracted", "帶回成功：%d 種物資已轉入基地倉庫。按「回到基地」整理下一場行動。") % extracted_count

func _status_text() -> String:
	var outcome := str(current_result.get("outcome", ""))
	if outcome == RaidResultSchema.OUTCOME_DEAD:
		return _text(&"ui.raid_result.status_dead", "遺失物品不會進入基地倉庫；安全口袋物品會送回基地。")
	return _text(&"ui.raid_result.status", "帶回物資已轉入基地倉庫；回基地後可直接整理下一場行動。")

func _entry_count(entries: Variant) -> int:
	if typeof(entries) != TYPE_ARRAY:
		return 0
	var count := 0
	for entry in entries as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			count += 1
	return count


func _text(key: StringName, fallback: String) -> String:
	return UITextScript.text(self, key, fallback)


func _on_continue_pressed() -> void:
	continue_to_base_requested.emit(current_result.duplicate(true))
	_request_base_stash_after_extract()
	if is_inside_tree():
		get_tree().change_scene_to_file(BASE_SCENE)


func _request_base_stash_after_extract() -> void:
	if str(current_result.get("outcome", "")) != RaidResultSchema.OUTCOME_EXTRACTED:
		return
	var ui_manager := get_node_or_null("/root/UIManager") if is_inside_tree() else null
	if ui_manager != null and ui_manager.has_method("open_ui_on_next_scene"):
		ui_manager.call("open_ui_on_next_scene", &"stash")
