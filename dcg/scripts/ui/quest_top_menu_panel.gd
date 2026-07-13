class_name QuestTopMenuPanel
extends Control

signal quest_action_requested(quest_id: String, action_mode: String)

const UIStyleScript := preload("res://scripts/ui/ui_style.gd")
const UILayoutScript := preload("res://scripts/ui/ui_layout.gd")
const UITextScript := preload("res://scripts/ui/ui_text.gd")
const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")
const QuestTopMenuLayoutBuilderScript := preload("res://scripts/ui/quest_top_menu_layout_builder.gd")
const QuestTopMenuPresenterScript := preload("res://scripts/ui/quest_top_menu_presenter.gd")
const BaseScreenViewModelScript := preload("res://scripts/base/base_screen_view_model.gd")
const QuestStateScript := preload("res://scripts/quests/quest_state.gd")

const CATEGORY_AVAILABLE := "available"
const CATEGORY_ACTIVE := "active"
const CATEGORY_COMPLETED := "completed"
const ACTION_ACCEPT := "quest_accept"
const ACTION_SUBMIT := "quest_submit"
const ACTION_ACTIVE := "quest_active"
const ACTION_COMPLETED := "quest_completed"
const ACTION_CANCEL := "quest_cancel"
@export var design_panel_size := UISurfacePaletteScript.SIZE_QUEST_PANEL
@export var design_top_margin := UISurfacePaletteScript.TOP_MENU_PANEL_TOP_MARGIN

@onready var main_panel: PanelContainer = get_node_or_null("MainPanel") as PanelContainer

var title_label: Label = null
var hint_label: Label = null
var available_tab_button: Button = null
var active_tab_button: Button = null
var completed_tab_button: Button = null
var left_column: VBoxContainer = null
var detail_panel: PanelContainer = null
var sort_label: Label = null
var quest_list: VBoxContainer = null
var empty_list_label: Label = null
var detail_title_label: Label = null
var detail_status_label: Label = null
var detail_description_label: Label = null
var condition_title_label: Label = null
var condition_rows: VBoxContainer = null
var reward_title_label: Label = null
var reward_rows: VBoxContainer = null
var status_message_label: Label = null
var action_button: Button = null

var is_open := false
var _active_category := CATEGORY_AVAILABLE
var _selected_quest_id := ""
var _quest_entries: Array[Dictionary] = []
var _filtered_entries: Array[Dictionary] = []
var _save_manager_node: Node = null
var _has_save_data := false
var _prefer_default_category_on_next_refresh := false
var _quest_giver_profile: Resource = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_layout_nodes()
	_connect_controls()
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
	_prefer_default_category_on_next_refresh = true
	refresh()
	_apply_responsive_layout()


func set_quest_giver_profile(profile: Resource) -> void:
	_quest_giver_profile = profile
	if is_open:
		_prefer_default_category_on_next_refresh = true
		refresh()


func close_quests() -> void:
	is_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	title_label.text = _locale_text(&"ui.top.quest_board_title", "任務板", "Quest List")
	hint_label.text = _locale_text(&"ui.top.quest_board_hint", "選擇任務後查看條件、進度與獎勵。", "Select a quest to view conditions, progress, and rewards.")
	condition_title_label.text = _locale_text(&"ui.top.quest_conditions", "任務條件", "Conditions")
	reward_title_label.text = _locale_text(&"ui.top.quest_rewards", "獎勵", "Rewards")

	var save_data := _current_save_data()
	_has_save_data = not save_data.is_empty()
	_quest_entries = _build_quest_entries(save_data)
	if _prefer_default_category_on_next_refresh:
		_active_category = _default_open_category()
		_selected_quest_id = ""
		_prefer_default_category_on_next_refresh = false
	_update_selection()
	_render_tabs()
	_render_quest_list()
	_render_detail()


func select_category(category: String) -> void:
	if not [CATEGORY_AVAILABLE, CATEGORY_ACTIVE, CATEGORY_COMPLETED].has(category):
		return
	_active_category = category
	_selected_quest_id = ""
	refresh()


func select_quest(quest_id: String) -> void:
	if quest_id == "":
		return
	_selected_quest_id = quest_id
	refresh()


func request_selected_action() -> void:
	_on_action_pressed()


func notify_quest_action_result(result: Dictionary) -> void:
	var message := str(result.get("message", ""))
	if message != "":
		status_message_label.text = message
	if bool(result.get("success", false)):
		refresh()
		if message != "":
			status_message_label.text = message
	else:
		refresh()
		if message != "":
			status_message_label.text = message


func get_display_state() -> Dictionary:
	var viewport_size := get_viewport_rect().size if is_inside_tree() else Vector2(1920.0, 1080.0)
	return get_display_state_for_viewport(viewport_size)


func get_display_state_for_viewport(viewport_size: Vector2) -> Dictionary:
	var rect := _layout_for_viewport(viewport_size)
	var selected := _selected_entry()
	return {
		"visible": visible,
		"is_open": is_open,
		"title": title_label.text,
		"hint": hint_label.text,
		"active_category": _active_category,
		"available_count": _count_for_category(CATEGORY_AVAILABLE),
		"active_count": _count_for_category(CATEGORY_ACTIVE),
		"completed_count": _count_for_category(CATEGORY_COMPLETED),
		"quest_count": _quest_entries.size(),
		"quest_giver_id": _quest_giver_id(),
		"list_count": _filtered_entries.size(),
		"quests": _filtered_entries.duplicate(true),
		"all_quests": _quest_entries.duplicate(true),
		"selected_quest": selected.duplicate(true),
		"selected_quest_id": _selected_quest_id,
		"detail_title": detail_title_label.text,
		"description": detail_description_label.text,
		"conditions": _row_texts(condition_rows),
		"rewards": _row_texts(reward_rows),
		"status": detail_status_label.text,
		"status_message": status_message_label.text,
		"action_text": action_button.text,
		"action_mode": str(selected.get("action_mode", "")),
		"action_enabled": action_button.visible and not action_button.disabled,
		"panel_rect": rect,
		"title_origin": _title_origin_for_viewport(viewport_size),
		"mouse_filter": mouse_filter,
	}


func preview_layout(viewport_size: Vector2) -> Rect2:
	return _layout_for_viewport(viewport_size)


func _ensure_layout_nodes() -> void:
	var nodes := QuestTopMenuLayoutBuilderScript.build(self, main_panel)
	main_panel = nodes.get("main_panel") as PanelContainer
	title_label = nodes.get("title_label") as Label
	hint_label = nodes.get("hint_label") as Label
	available_tab_button = nodes.get("available_tab_button") as Button
	active_tab_button = nodes.get("active_tab_button") as Button
	completed_tab_button = nodes.get("completed_tab_button") as Button
	left_column = nodes.get("left_column") as VBoxContainer
	detail_panel = nodes.get("detail_panel") as PanelContainer
	sort_label = nodes.get("sort_label") as Label
	quest_list = nodes.get("quest_list") as VBoxContainer
	empty_list_label = nodes.get("empty_list_label") as Label
	detail_title_label = nodes.get("detail_title_label") as Label
	detail_status_label = nodes.get("detail_status_label") as Label
	detail_description_label = nodes.get("detail_description_label") as Label
	condition_title_label = nodes.get("condition_title_label") as Label
	condition_rows = nodes.get("condition_rows") as VBoxContainer
	reward_title_label = nodes.get("reward_title_label") as Label
	reward_rows = nodes.get("reward_rows") as VBoxContainer
	status_message_label = nodes.get("status_message_label") as Label
	action_button = nodes.get("action_button") as Button
	if available_tab_button != null and not available_tab_button.resized.is_connected(_sync_tab_body_grid):
		available_tab_button.resized.connect(_sync_tab_body_grid)

func _connect_controls() -> void:
	available_tab_button.pressed.connect(_on_category_pressed.bind(CATEGORY_AVAILABLE))
	active_tab_button.pressed.connect(_on_category_pressed.bind(CATEGORY_ACTIVE))
	completed_tab_button.pressed.connect(_on_category_pressed.bind(CATEGORY_COMPLETED))
	action_button.pressed.connect(_on_action_pressed)


func _apply_styles() -> void:
	UIStyleScript.apply_top_menu_panel_style(main_panel)
	for label in [title_label, detail_title_label]:
		UIStyleScript.apply_font_size(label, UIStyleScript.FONT_PANEL_TITLE)
		UIStyleScript.apply_font_color(label, UIStyleScript.COLOR_TEXT_PRIMARY)
	for label in [hint_label, detail_description_label, status_message_label]:
		UIStyleScript.apply_font_size(label, UIStyleScript.FONT_PLACEHOLDER)
		UIStyleScript.apply_font_color(label, UIStyleScript.COLOR_TEXT_HELP)
	if sort_label != null:
		UIStyleScript.apply_font_size(sort_label, UIStyleScript.FONT_PLACEHOLDER)
		UIStyleScript.apply_font_color(sort_label, UIStyleScript.COLOR_TEXT_HELP)
	for label in [detail_status_label, condition_title_label, reward_title_label]:
		UIStyleScript.apply_font_size(label, UIStyleScript.FONT_BODY)
		UIStyleScript.apply_font_color(label, UIStyleScript.COLOR_TEXT_SUBTITLE)
	UIStyleScript.apply_font_size(empty_list_label, UIStyleScript.FONT_BODY)
	UIStyleScript.apply_font_color(empty_list_label, UIStyleScript.COLOR_TEXT_MUTED)
	for button in [available_tab_button, active_tab_button, completed_tab_button, action_button]:
		UIStyleScript.apply_font_size(button, UIStyleScript.FONT_BODY)


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1920.0, 1080.0)
	var rect := _layout_for_viewport(viewport_size)
	UIStyleScript.apply_top_menu_panel_margins(_panel_margin(), _top_menu_scale(viewport_size))
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = rect.position
	size = rect.size
	call_deferred("_sync_tab_body_grid")


func _sync_tab_body_grid() -> void:
	if left_column == null or available_tab_button == null or available_tab_button.size.x <= 0.0:
		return
	if is_equal_approx(left_column.custom_minimum_size.x, available_tab_button.size.x):
		return
	left_column.custom_minimum_size = Vector2(available_tab_button.size.x, 0.0)


func _layout_for_viewport(viewport_size: Vector2) -> Rect2:
	var rect := UILayoutScript.centered_top_rect(viewport_size, design_panel_size, design_top_margin, UISurfacePaletteScript.TOP_MENU_PANEL_MIN_SCALE, 1.0)
	rect.size.y = minf(rect.size.y, viewport_size.y * UISurfacePaletteScript.TOP_MENU_PANEL_MAX_VIEWPORT_HEIGHT_RATIO)
	return rect


func _title_origin_for_viewport(viewport_size: Vector2) -> Vector2:
	var rect := _layout_for_viewport(viewport_size)
	return rect.position + UISurfacePaletteScript.TOP_MENU_TITLE_ORIGIN * _top_menu_scale(viewport_size)


func _top_menu_scale(viewport_size: Vector2) -> float:
	return UILayoutScript.design_scale(viewport_size, UISurfacePaletteScript.TOP_MENU_PANEL_MIN_SCALE, 1.0)


func _panel_margin() -> MarginContainer:
	if main_panel == null:
		return null
	return main_panel.get_node_or_null("PanelMargin") as MarginContainer


func _build_quest_entries(save_data: Dictionary) -> Array[Dictionary]:
	var tracked_defs := BaseScreenViewModelScript.tracked_quest_defs(save_data, _quest_giver_profile)
	var tracked_ids := {}
	for quest_def in tracked_defs:
		tracked_ids[str(quest_def.get("id"))] = true

	var available_defs: Array[Resource] = []
	if _quest_giver_profile != null:
		for quest_def in BaseScreenViewModelScript.quest_defs(_quest_giver_profile):
			if tracked_ids.has(str(quest_def.get("id"))):
				continue
			available_defs.append(quest_def)

	var entries := QuestTopMenuPresenterScript.build_entries(self, save_data, tracked_defs)
	entries.append_array(QuestTopMenuPresenterScript.build_entries(self, save_data, available_defs))
	if _quest_giver_profile == null:
		for entry in entries:
			if str(entry.get("action_mode", "")) == ACTION_SUBMIT or str(entry.get("action_mode", "")) == ACTION_CANCEL:
				entry["action_mode"] = ACTION_ACTIVE
	return entries


func _default_open_category() -> String:
	if _count_for_category(CATEGORY_ACTIVE) > 0:
		return CATEGORY_ACTIVE
	if _count_for_category(CATEGORY_AVAILABLE) > 0:
		return CATEGORY_AVAILABLE
	if _count_for_category(CATEGORY_COMPLETED) > 0:
		return CATEGORY_COMPLETED
	return CATEGORY_AVAILABLE


func _update_selection() -> void:
	_filtered_entries = []
	for entry in _quest_entries:
		if str(entry.get("category", "")) == _active_category:
			_filtered_entries.append(entry)
	if _filtered_entries.is_empty():
		_selected_quest_id = ""
		return
	if _entry_for_id(_selected_quest_id).is_empty() or str(_entry_for_id(_selected_quest_id).get("category", "")) != _active_category:
		_selected_quest_id = str(_filtered_entries[0].get("id", ""))


func _render_tabs() -> void:
	available_tab_button.text = _locale_text(&"ui.top.quest_tab_available", "可承接", "Available")
	active_tab_button.text = _locale_text(&"ui.top.quest_tab_active", "進行中", "Active")
	completed_tab_button.text = _locale_text(&"ui.top.quest_tab_completed", "已完成", "Completed")
	_style_tab_button(available_tab_button, _active_category == CATEGORY_AVAILABLE)
	_style_tab_button(active_tab_button, _active_category == CATEGORY_ACTIVE)
	_style_tab_button(completed_tab_button, _active_category == CATEGORY_COMPLETED)


func _render_quest_list() -> void:
	_clear_children(quest_list)
	empty_list_label.visible = _filtered_entries.is_empty()
	if empty_list_label.visible:
		empty_list_label.text = _locale_text(&"ui.top.quest_empty_category", "此分類目前沒有任務。", "No quests in this category")
		return
	for entry in _filtered_entries:
		var button := Button.new()
		button.text = "%s\n%s" % [str(entry.get("name", "")), str(entry.get("status", ""))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0.0, UIStyleScript.SIZE_MENU_BUTTON.y + UIStyleScript.SPACING_LOAD_PANEL_CONTENT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_quest_pressed.bind(str(entry.get("id", ""))))
		_style_list_button(button, str(entry.get("id", "")) == _selected_quest_id)
		quest_list.add_child(button)


func _render_detail() -> void:
	_clear_children(condition_rows)
	_clear_children(reward_rows)
	var selected := _selected_entry()
	if selected.is_empty():
		detail_title_label.text = _locale_text(&"ui.top.quest_empty_category", "此分類目前沒有任務。", "No quests in this category")
		detail_status_label.text = ""
		detail_description_label.text = _locale_text(&"ui.top.quest_empty_category_hint", "切換分類或返回基地查看新的任務。", "Switch categories or return to base to find new quests.")
		status_message_label.text = ""
		action_button.visible = false
		return

	detail_title_label.text = str(selected.get("name", ""))
	detail_status_label.text = str(selected.get("status", ""))
	detail_description_label.text = str(selected.get("description", ""))
	_add_detail_row(condition_rows, str(selected.get("objective", "")))
	var progress := str(selected.get("progress", ""))
	if progress != "":
		_add_detail_row(condition_rows, progress)
	_add_detail_row(reward_rows, str(selected.get("reward", "")))
	_configure_action_button(selected)


func _configure_action_button(entry: Dictionary) -> void:
	var action_mode := str(entry.get("action_mode", ""))
	action_button.visible = true
	action_button.disabled = true
	action_button.text = _locale_text(&"ui.top.quest_action_unavailable", "不可執行", "Unavailable")
	match action_mode:
		ACTION_ACCEPT:
			action_button.disabled = not _has_save_data
		ACTION_SUBMIT:
			action_button.disabled = not _has_save_data
		ACTION_CANCEL:
			action_button.disabled = not _has_save_data
	_override_action_button_text(action_mode)
	_style_action_button(action_button.disabled)


func _override_action_button_text(action_mode: String) -> void:
	match action_mode:
		ACTION_ACCEPT:
			action_button.text = _locale_text(&"ui.top.quest_accept_action", "接受任務", "Accept Quest")
		ACTION_SUBMIT:
			action_button.text = _locale_text(&"ui.top.quest_submit_action", "回報任務", "Submit")
		ACTION_CANCEL:
			action_button.text = _locale_text(&"ui.top.quest_cancel_action", "取消任務", "Cancel Quest")
		ACTION_COMPLETED:
			action_button.text = _locale_text(&"ui.top.quest_completed_action", "已完成", "Completed")
		ACTION_ACTIVE:
			action_button.text = _locale_text(&"ui.top.quest_active_action", "進行中", "Active")
		_:
			action_button.text = _locale_text(&"ui.top.quest_action_unavailable", "不可執行", "Unavailable")


func _add_detail_row(parent: VBoxContainer, text: String) -> void:
	var row := Label.new()
	row.text = text
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyleScript.apply_font_size(row, UIStyleScript.FONT_PLACEHOLDER)
	UIStyleScript.apply_font_color(row, UIStyleScript.COLOR_TEXT_STATUS)
	parent.add_child(row)


func _on_category_pressed(category: String) -> void:
	select_category(category)


func _on_quest_pressed(quest_id: String) -> void:
	select_quest(quest_id)


func _on_action_pressed() -> void:
	var selected := _selected_entry()
	if selected.is_empty() or action_button.disabled:
		return
	quest_action_requested.emit(str(selected.get("id", "")), str(selected.get("action_mode", "")))


func _selected_entry() -> Dictionary:
	return _entry_for_id(_selected_quest_id)


func _entry_for_id(quest_id: String) -> Dictionary:
	if quest_id == "":
		return {}
	for entry in _quest_entries:
		if str(entry.get("id", "")) == quest_id:
			return entry
	return {}


func _count_for_category(category: String) -> int:
	var count := 0
	for entry in _quest_entries:
		if str(entry.get("category", "")) == category:
			count += 1
	return count


func _row_texts(parent: VBoxContainer) -> Array[String]:
	var result: Array[String] = []
	for child in parent.get_children():
		var label := child as Label
		if label != null:
			result.append(label.text)
	return result


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _style_tab_button(button: Button, is_selected: bool) -> void:
	var normal := _button_style(&"neutral")
	var selected := _button_style(&"primary")
	var style := selected if is_selected else normal
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", selected if is_selected else _button_style(&"hover"))
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_color_override("font_color", UIStyleScript.COLOR_TEXT_PRIMARY)


func _style_list_button(button: Button, is_selected: bool) -> void:
	var style := _button_style(&"neutral")
	var selected := _button_style(&"primary")
	button.add_theme_stylebox_override("normal", selected if is_selected else style)
	button.add_theme_stylebox_override("hover", selected)
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_color_override("font_color", UIStyleScript.COLOR_TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", UIStyleScript.COLOR_TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", UIStyleScript.COLOR_TEXT_PRIMARY)


func _style_action_button(is_disabled: bool) -> void:
	var style := _button_style(&"primary")
	var disabled := _button_style(&"disabled")
	action_button.add_theme_stylebox_override("normal", disabled if is_disabled else style)
	action_button.add_theme_stylebox_override("hover", style)
	action_button.add_theme_stylebox_override("pressed", style)
	action_button.add_theme_stylebox_override("disabled", disabled)
	action_button.add_theme_color_override("font_color", UIStyleScript.COLOR_TEXT_PRIMARY)
	action_button.add_theme_color_override("font_disabled_color", UIStyleScript.COLOR_TEXT_MUTED)


func _button_style(kind: StringName) -> StyleBoxFlat:
	return UIStyleScript.make_button_style(kind)


func _inner_panel_style(bg_color: Color) -> StyleBoxFlat:
	var style := UIStyleScript.make_inner_panel_style()
	style.bg_color = bg_color
	return style


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


func _quest_giver_id() -> String:
	if _quest_giver_profile == null:
		return ""
	return str(_quest_giver_profile.get("id"))


func _text(key: StringName, fallback: String) -> String:
	return UITextScript.text(self, key, fallback)


func _locale_text(key: StringName, zh_fallback: String, en_fallback: String) -> String:
	return _text(key, en_fallback if _is_english_locale() else zh_fallback)


func _is_english_locale() -> bool:
	return TranslationServer.get_locale().begins_with("en")


func _reward_delimiter() -> String:
	return ", " if _is_english_locale() else "、"
