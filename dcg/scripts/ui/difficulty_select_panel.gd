class_name DifficultySelectPanel
extends PanelContainer

const PanelUIStyle := preload("res://scripts/ui/ui_style.gd")
const BASE_SCENE := "res://scenes/base/base_3d.tscn"

var title_label: Label
var description_label: Label
var rows_box: VBoxContainer
var back_button: Button
var difficulty_buttons: Dictionary = {}
var pending_difficulty_id: StringName = &"normal"


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	PanelUIStyle.apply_overlay_panel_style(self)
	_build()
	refresh_texts()


func open() -> void:
	var manager := get_node_or_null("/root/DifficultyManager")
	if manager != null:
		pending_difficulty_id = _get_selected_difficulty_id(manager)
	refresh_texts()
	visible = true
	_focus_selected_button.call_deferred()


func close() -> void:
	visible = false


func refresh_texts() -> void:
	if title_label == null:
		return
	title_label.text = _localized_text(&"ui.difficulty.title")
	description_label.text = _localized_text(&"ui.difficulty.prompt")
	back_button.text = tr("ui.main.back")
	_rebuild_difficulty_rows()


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

	back_button = Button.new()
	back_button.custom_minimum_size = PanelUIStyle.SIZE_PANEL_BACK_BUTTON
	back_button.pressed.connect(close)
	box.add_child(back_button)


func _rebuild_difficulty_rows() -> void:
	if rows_box == null:
		return
	for child in rows_box.get_children():
		rows_box.remove_child(child)
		child.queue_free()
	difficulty_buttons.clear()

	var manager: Node = null
	if is_inside_tree():
		manager = get_node_or_null("/root/DifficultyManager")
	if manager == null or not manager.has_method("get_profiles"):
		return

	for profile in manager.get_profiles():
		var row := _make_difficulty_row(profile, profile.id == pending_difficulty_id)
		rows_box.add_child(row)


func _make_difficulty_row(profile: DifficultyProfile, selected: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = PanelUIStyle.SIZE_SETTING_ROW
	row.add_theme_constant_override("separation", PanelUIStyle.SPACING_SETTING_ROW)

	var label := Label.new()
	label.custom_minimum_size = PanelUIStyle.SIZE_SETTING_LABEL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = _localized_text(profile.name_key)
	PanelUIStyle.apply_font_size(label, PanelUIStyle.FONT_BODY)
	row.add_child(label)

	var button := Button.new()
	button.custom_minimum_size = PanelUIStyle.SIZE_SETTING_CONTROL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.text = _make_difficulty_button_text(profile)
	button.pressed.connect(_on_difficulty_selected.bind(profile.id))
	button.gui_input.connect(_on_difficulty_button_input.bind(profile.id))
	PanelUIStyle.apply_font_size(button, PanelUIStyle.FONT_BODY)
	if selected:
		_apply_selected_button_style(button)
		button.add_theme_color_override("font_color", PanelUIStyle.COLOR_TEXT_PRIMARY)
	difficulty_buttons[profile.id] = button
	row.add_child(button)

	return row


func _make_difficulty_button_text(profile: DifficultyProfile) -> String:
	return _localized_text(profile.description_key)


func _apply_selected_button_style(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.27, 0.52, 0.64, 1.0)
	normal.border_color = Color(0.48, 0.78, 0.90, 0.42)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.31, 0.60, 0.74, 1.0)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.22, 0.44, 0.55, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)


func _focus_selected_button() -> void:
	var button := difficulty_buttons.get(pending_difficulty_id, null) as Button
	if button != null and button.is_inside_tree():
		button.grab_focus()


func _get_selected_difficulty_id(manager: Node) -> StringName:
	if manager != null and manager.has_method("get_selected_profile"):
		var selected_profile_value: Variant = manager.call("get_selected_profile")
		var selected_profile: DifficultyProfile = selected_profile_value as DifficultyProfile
		if selected_profile != null:
			return selected_profile.id
	return &"normal"


func _on_difficulty_selected(id: StringName) -> void:
	pending_difficulty_id = id
	_rebuild_difficulty_rows()
	_focus_selected_button.call_deferred()


func _on_difficulty_button_input(event: InputEvent, id: StringName) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		pending_difficulty_id = id
		_confirm_difficulty()
		accept_event()


func _confirm_difficulty() -> void:
	var save_manager := get_node_or_null("/root/SaveGameManager")
	if save_manager != null and save_manager.has_method("start_new_game") and save_manager.has_method("get_preferred_new_game_slot"):
		var slot_index := int(save_manager.get_preferred_new_game_slot())
		if save_manager.start_new_game(slot_index, str(pending_difficulty_id), BASE_SCENE):
			return
	var manager := get_node_or_null("/root/DifficultyManager")
	if manager != null and manager.has_method("set_difficulty"):
		manager.set_difficulty(pending_difficulty_id)
	get_tree().change_scene_to_file(BASE_SCENE)


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
		&"ui.difficulty.title":
			return "Select Difficulty"
		&"ui.difficulty.prompt":
			return "Single click to choose. Double click to confirm."
		&"ui.difficulty.easy":
			return "Easy"
		&"ui.difficulty.easy_desc":
			return "Player health is increased."
		&"ui.difficulty.normal":
			return "Normal"
		&"ui.difficulty.normal_desc":
			return "Standard player health."
		&"ui.difficulty.hard":
			return "Hard"
		&"ui.difficulty.hard_desc":
			return "Player health is reduced."
		_:
			return str(key)
