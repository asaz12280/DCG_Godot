class_name SaveSlotPanel
extends PanelContainer

signal closed

const PanelUIStyle := preload("res://scripts/ui/ui_style.gd")

var title_label: Label
var description_label: Label
var status_label: Label
var rows_box: VBoxContainer
var back_button: Button
var slot_rows: Array[Dictionary] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	PanelUIStyle.apply_overlay_panel_style(self)
	_build()
	refresh_texts()


func open() -> void:
	refresh_texts()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func refresh_texts() -> void:
	if title_label == null:
		return
	title_label.text = tr("ui.main.load")
	description_label.text = _localized_text(&"ui.save_slots.prompt")
	back_button.text = tr("ui.main.back")
	status_label.text = _localized_text(&"ui.save_slots.status_default")
	_refresh_slots()


func get_slot_count() -> int:
	return slot_rows.size()


func _build() -> void:
	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", PanelUIStyle.PANEL_MARGIN_LEFT)
	panel_margin.add_theme_constant_override("margin_right", PanelUIStyle.PANEL_MARGIN_RIGHT)
	panel_margin.add_theme_constant_override("margin_top", PanelUIStyle.PANEL_MARGIN_TOP)
	panel_margin.add_theme_constant_override("margin_bottom", PanelUIStyle.PANEL_MARGIN_BOTTOM)
	add_child(panel_margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", PanelUIStyle.SPACING_PANEL_CONTENT)
	panel_margin.add_child(box)

	title_label = Label.new()
	PanelUIStyle.apply_font_size(title_label, PanelUIStyle.FONT_PANEL_TITLE)
	box.add_child(title_label)

	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size = Vector2(0.0, 44.0)
	PanelUIStyle.apply_font_size(description_label, PanelUIStyle.FONT_BODY)
	PanelUIStyle.apply_font_color(description_label, PanelUIStyle.COLOR_TEXT_HELP)
	box.add_child(description_label)

	var rows_margin := MarginContainer.new()
	rows_margin.add_theme_constant_override("margin_left", 34)
	rows_margin.add_theme_constant_override("margin_right", 34)
	rows_margin.add_theme_constant_override("margin_top", 8)
	rows_margin.add_theme_constant_override("margin_bottom", 8)
	box.add_child(rows_margin)

	rows_box = VBoxContainer.new()
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", PanelUIStyle.SPACING_SETTING_ROWS)
	rows_margin.add_child(rows_box)

	for slot_index in range(1, 4):
		rows_box.add_child(_make_slot_row(slot_index))

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0.0, 54.0)
	PanelUIStyle.apply_font_size(status_label, PanelUIStyle.FONT_PLACEHOLDER)
	PanelUIStyle.apply_font_color(status_label, PanelUIStyle.COLOR_TEXT_MUTED)
	box.add_child(status_label)

	back_button = Button.new()
	back_button.custom_minimum_size = PanelUIStyle.SIZE_PANEL_BACK_BUTTON
	back_button.pressed.connect(close)
	box.add_child(back_button)


func _make_slot_row(slot_index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = PanelUIStyle.SIZE_SETTING_ROW
	row.add_theme_constant_override("separation", PanelUIStyle.SPACING_SETTING_ROW)

	var label := Label.new()
	label.custom_minimum_size = PanelUIStyle.SIZE_SETTING_LABEL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PanelUIStyle.apply_font_size(label, PanelUIStyle.FONT_BODY)
	row.add_child(label)

	var button := Button.new()
	button.custom_minimum_size = PanelUIStyle.SIZE_SETTING_CONTROL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_on_slot_pressed.bind(slot_index))
	PanelUIStyle.apply_font_size(button, PanelUIStyle.FONT_BODY)
	row.add_child(button)

	slot_rows.append({
		"slot_index": slot_index,
		"label": label,
		"button": button,
	})
	return row


func _refresh_slots() -> void:
	var save_manager := get_node_or_null("/root/SaveGameManager")
	var has_any_slot := false
	for row_data in slot_rows:
		var slot_index := int(row_data.get("slot_index", 0))
		var label := row_data.get("label") as Label
		var button := row_data.get("button") as Button
		if label == null or button == null:
			continue

		var summary := {}
		if save_manager != null and save_manager.has_method("get_slot_summary"):
			summary = save_manager.get_slot_summary(slot_index)
		var exists := bool(summary.get("exists", false))
		has_any_slot = has_any_slot or exists

		label.text = _localized_text(&"ui.save_slots.slot_format") % slot_index
		button.disabled = not exists
		if exists:
			button.text = _make_filled_slot_text(summary)
		else:
			button.text = _localized_text(&"ui.save_slots.empty")

	if not has_any_slot:
		status_label.text = _localized_text(&"ui.save_slots.status_empty")


func _make_filled_slot_text(summary: Dictionary) -> String:
	var difficulty_name := _difficulty_name(str(summary.get("difficulty_id", "normal")))
	var saved_at := str(summary.get("saved_at_text", ""))
	if saved_at == "":
		saved_at = _localized_text(&"ui.save_slots.time_unknown")
	return _localized_text(&"ui.save_slots.filled_format") % [difficulty_name, saved_at]


func _on_slot_pressed(slot_index: int) -> void:
	var save_manager := get_node_or_null("/root/SaveGameManager")
	if save_manager == null or not save_manager.has_method("get_slot_summary"):
		status_label.text = _localized_text(&"ui.save_slots.status_missing_manager")
		return

	var summary: Dictionary = save_manager.get_slot_summary(slot_index)
	if not bool(summary.get("exists", false)):
		status_label.text = _localized_text(&"ui.save_slots.status_empty")
		return

	status_label.text = _localized_text(&"ui.save_slots.status_loading") % slot_index
	if save_manager.has_method("continue_from_slot") and save_manager.continue_from_slot(slot_index):
		return
	status_label.text = _localized_text(&"ui.save_slots.status_load_failed") % slot_index


func _difficulty_name(difficulty_id: String) -> String:
	match difficulty_id:
		"easy":
			return _localized_text(&"ui.difficulty.easy")
		"hard":
			return _localized_text(&"ui.difficulty.hard")
		"normal":
			return _localized_text(&"ui.difficulty.normal")
		_:
			return _localized_text(&"ui.save_slots.difficulty_unknown")


func _localized_text(key: StringName) -> String:
	var key_text := str(key)
	if key_text == "":
		return ""
	var translated := tr(key_text)
	if translated != key_text:
		return translated
	return _fallback_text(key)


func _fallback_text(key: StringName) -> String:
	match key:
		&"ui.save_slots.prompt":
			return "Choose a slot to continue an existing run."
		&"ui.save_slots.slot_format":
			return "Slot %d"
		&"ui.save_slots.empty":
			return "Empty slot"
		&"ui.save_slots.filled_format":
			return "%s  %s"
		&"ui.save_slots.status_default":
			return "Only slots with save data can continue."
		&"ui.save_slots.status_empty":
			return "No save data yet. Start a new game to create the first slot."
		&"ui.save_slots.status_loading":
			return "Loading slot %d..."
		&"ui.save_slots.status_load_failed":
			return "Slot %d could not be loaded."
		&"ui.save_slots.status_missing_manager":
			return "Save manager is not available."
		&"ui.save_slots.time_unknown":
			return "Unknown time"
		&"ui.save_slots.difficulty_unknown":
			return "Unknown"
		_:
			return str(key)
