extends Control
class_name BaseScreen

const BaseUIStyle := preload("res://scripts/ui/ui_style.gd")
const GAMEPLAY_SCENE := "res://scenes/gameplay/player_test_world_3d.tscn"

@export var current_slot_index: int = 1

@onready var main_panel: PanelContainer = %MainPanel
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var slot_label: Label = %SlotLabel
@onready var difficulty_label: Label = %DifficultyLabel
@onready var money_label: Label = %MoneyLabel
@onready var stash_title_label: Label = %StashTitleLabel
@onready var stash_rows: VBoxContainer = %StashRows
@onready var status_label: Label = %StatusLabel
@onready var start_raid_button: Button = %StartRaidButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply_styles()
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

	title_label.text = _text(&"ui.base.title", "Base")
	subtitle_label.text = _text(&"ui.base.subtitle", "Stash, prepare, and start the next raid.")
	slot_label.text = _text(&"ui.base.slot_format", "Slot %d") % current_slot_index
	difficulty_label.text = "%s: %s" % [_text(&"ui.base.difficulty", "Difficulty"), _difficulty_name(str(save_data.get("difficulty_id", "normal")))]
	money_label.text = "%s: $%d" % [_text(&"ui.base.money", "Money"), int(save_data.get("money", 0))]
	stash_title_label.text = _text(&"ui.base.stash", "Stash")
	start_raid_button.text = _text(&"ui.base.start_raid", "Start Raid")
	status_label.text = _text(&"ui.base.ready", "Ready for the next run.") if has_save else _text(&"ui.base.no_save", "No save data yet. Start a raid to create progress.")
	_rebuild_stash_rows(save_data.get("stash", []))
	_layout_panel.call_deferred()


func get_stash_row_count() -> int:
	return stash_rows.get_child_count()


func get_display_state() -> Dictionary:
	return {
		"slot": slot_label.text,
		"difficulty": difficulty_label.text,
		"money": money_label.text,
		"stash_rows": get_stash_row_count(),
		"status": status_label.text,
		"panel_rect": Rect2(main_panel.position, main_panel.size),
		"start_button_rect": Rect2(start_raid_button.global_position, start_raid_button.size),
	}


func _apply_styles() -> void:
	BaseUIStyle.apply_overlay_panel_style(main_panel)
	BaseUIStyle.apply_font_size(title_label, BaseUIStyle.FONT_PANEL_TITLE)
	BaseUIStyle.apply_font_color(title_label, BaseUIStyle.COLOR_TEXT_PRIMARY)
	BaseUIStyle.apply_font_size(subtitle_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_color(subtitle_label, BaseUIStyle.COLOR_TEXT_HELP)
	BaseUIStyle.apply_font_size(slot_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_size(difficulty_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_size(money_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_size(stash_title_label, BaseUIStyle.FONT_BODY)
	BaseUIStyle.apply_font_color(stash_title_label, BaseUIStyle.COLOR_TEXT_SUBTITLE)
	BaseUIStyle.apply_font_size(status_label, BaseUIStyle.FONT_PLACEHOLDER)
	BaseUIStyle.apply_font_color(status_label, BaseUIStyle.COLOR_TEXT_MUTED)
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
		minf(620.0, maxf(320.0, viewport_size.y - outer_margin * 2.0))
	)
	main_panel.position = Vector2(
		floor((viewport_size.x - panel_size.x) * 0.5),
		floor((viewport_size.y - panel_size.y) * 0.5)
	)
	main_panel.size = panel_size


func _rebuild_stash_rows(stash_data: Variant) -> void:
	for child in stash_rows.get_children():
		stash_rows.remove_child(child)
		child.queue_free()

	if typeof(stash_data) != TYPE_ARRAY or (stash_data as Array).is_empty():
		stash_rows.add_child(_make_stash_row(_text(&"ui.base.stash_empty", "Stash is empty."), ""))
		return

	for entry in stash_data as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item_path := str(entry.get("item_path", ""))
		var quantity := int(entry.get("quantity", 0))
		var item_name := _item_name_from_path(item_path)
		stash_rows.add_child(_make_stash_row(item_name, "x%d" % quantity))


func _make_stash_row(item_name: String, quantity_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 38.0)
	row.add_theme_constant_override("separation", 16)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	BaseUIStyle.apply_font_size(name_label, BaseUIStyle.FONT_PLACEHOLDER)
	row.add_child(name_label)

	var quantity_label := Label.new()
	quantity_label.text = quantity_text
	quantity_label.custom_minimum_size = Vector2(80.0, 0.0)
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	BaseUIStyle.apply_font_size(quantity_label, BaseUIStyle.FONT_PLACEHOLDER)
	row.add_child(quantity_label)
	return row


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


func _difficulty_name(difficulty_id: String) -> String:
	match difficulty_id:
		"easy":
			return _text(&"ui.difficulty.easy", "Easy")
		"hard":
			return _text(&"ui.difficulty.hard", "Hard")
		_:
			return _text(&"ui.difficulty.normal", "Normal")


func _text(key: StringName, fallback: String) -> String:
	var key_text := str(key)
	var translated := tr(key_text)
	return fallback if translated == key_text else translated


func _on_start_raid_pressed() -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file(GAMEPLAY_SCENE)
