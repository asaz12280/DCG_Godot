class_name BaseInteractionPanel
extends Control

signal action_requested(interaction_id: String)
signal recipe_selected(interaction_id: String, recipe_id: String)
signal station_mode_selected(interaction_id: String, mode_id: String)
signal blueprint_selected(interaction_id: String, blueprint_item_path: String)
signal repair_selected(interaction_id: String, repair_id: String)
signal dismantle_selected(interaction_id: String, dismantle_id: String)

const UIStyleScript := preload("res://scripts/ui/ui_style.gd")
const UITextScript := preload("res://scripts/ui/ui_text.gd")
const PanelViewModelScript := preload("res://scripts/base/base_interaction_panel_view_model.gd")

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel
@onready var mode_tabs: HBoxContainer = %ModeTabs
@onready var recipe_scroll: ScrollContainer = %RecipeScroll
@onready var recipe_list: VBoxContainer = %RecipeList
@onready var action_button: Button = %ActionButton
@onready var close_button: Button = %CloseButton

var active_interaction_id := ""
var active_context: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	UIStyleScript.apply_overlay_panel_style(panel)
	UIStyleScript.apply_font_size(title_label, UIStyleScript.FONT_PANEL_TITLE)
	UIStyleScript.apply_font_color(title_label, UIStyleScript.COLOR_TEXT_PRIMARY)
	UIStyleScript.apply_font_size(body_label, UIStyleScript.FONT_BODY)
	UIStyleScript.apply_font_color(body_label, UIStyleScript.COLOR_TEXT_HELP)
	UIStyleScript.apply_font_size(action_button, UIStyleScript.FONT_BODY)
	UIStyleScript.apply_font_size(close_button, UIStyleScript.FONT_BODY)
	action_button.pressed.connect(_on_action_button_pressed)
	close_button.pressed.connect(close_panel)


func open_interaction(interaction_id: String, display_name: String, context: Dictionary = {}) -> void:
	active_interaction_id = interaction_id
	active_context = context.duplicate(true)
	title_label.text = display_name
	body_label.text = str(context.get("body", _body_text(interaction_id)))
	action_button.visible = bool(context.get("action_visible", false))
	action_button.disabled = not bool(context.get("action_enabled", false))
	action_button.text = str(context.get("action_text", _text(&"ui.common.execute", "Execute")))
	close_button.text = _text(&"ui.common.close", "Close")
	_refresh_station_mode_tabs()
	_refresh_recipe_list()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if action_button.visible and not action_button.disabled:
		action_button.grab_focus.call_deferred()
	else:
		close_button.grab_focus.call_deferred()


func update_interaction_state(context: Dictionary) -> void:
	for key in context.keys():
		active_context[key] = context[key]
	body_label.text = str(context.get("body", body_label.text))
	if context.has("action_visible"):
		action_button.visible = bool(context.get("action_visible", action_button.visible))
	if context.has("action_enabled"):
		action_button.disabled = not bool(context.get("action_enabled", not action_button.disabled))
	if context.has("action_text"):
		action_button.text = str(context.get("action_text", action_button.text))
	_refresh_station_mode_tabs()
	_refresh_recipe_list()


func _input(event: InputEvent) -> void:
	if not _can_navigate_recipe_list():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DOWN:
			if select_next_recipe():
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_UP:
			if select_previous_recipe():
				get_viewport().set_input_as_handled()


func close_panel() -> void:
	visible = false
	active_interaction_id = ""
	active_context.clear()
	_clear_station_mode_tabs()
	_clear_recipe_list()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func is_open() -> bool:
	return visible


func select_next_recipe() -> bool:
	return _select_recipe_by_offset(1)


func select_previous_recipe() -> bool:
	return _select_recipe_by_offset(-1)


func get_display_state() -> Dictionary:
	return {
		"visible": visible,
		"interaction_id": active_interaction_id,
		"title": title_label.text if title_label != null else "",
		"body": body_label.text if body_label != null else "",
		"action_visible": action_button.visible if action_button != null else false,
		"action_enabled": not action_button.disabled if action_button != null else false,
		"action_text": action_button.text if action_button != null else "",
		"action_mode": str(active_context.get("action_mode", "")),
		"selected_station_mode": str(active_context.get("selected_station_mode", "")),
		"station_modes": (active_context.get("station_modes", []) as Array).duplicate(true),
		"mode_tabs_visible": mode_tabs.visible if mode_tabs != null else false,
		"mode_button_count": mode_tabs.get_child_count() if mode_tabs != null else 0,
		"mode_buttons": PanelViewModelScript.mode_button_states(mode_tabs),
		"blueprint_rows": (active_context.get("blueprint_rows", []) as Array).duplicate(true),
		"can_research_blueprint": bool(active_context.get("can_research_blueprint", false)),
		"blueprint_button_count": _button_states("blueprint").size(),
		"blueprint_buttons": _button_states("blueprint"),
		"recipe_rows": (active_context.get("recipe_rows", []) as Array).duplicate(true),
		"selected_recipe_id": str(active_context.get("selected_recipe_id", "")),
		"repair_rows": (active_context.get("repair_rows", []) as Array).duplicate(true),
		"selected_repair_id": str(active_context.get("selected_repair_id", "")),
		"repair_button_count": _button_states("repair").size(),
		"repair_buttons": _button_states("repair"),
		"dismantle_rows": (active_context.get("dismantle_rows", []) as Array).duplicate(true),
		"selected_dismantle_id": str(active_context.get("selected_dismantle_id", "")),
		"dismantle_button_count": _button_states("dismantle").size(),
		"dismantle_buttons": _button_states("dismantle"),
		"recipe_list_visible": recipe_scroll.visible if recipe_scroll != null else false,
		"recipe_button_count": _button_states("recipe").size(),
		"selected_recipe_button_index": _selected_recipe_button_index(),
		"recipe_buttons": _button_states("recipe"),
		"recipe_list_rect": Rect2(recipe_scroll.global_position, recipe_scroll.size) if recipe_scroll != null else Rect2(),
		"button": close_button.text if close_button != null else "",
	}


func _body_text(interaction_id: String) -> String:
	match interaction_id:
		"stash":
			return _text(&"ui.base.interaction.stash_body", "Open the warehouse to manage extracted supplies and raid loadout.")
		"quests":
			return _text(&"ui.base.interaction.quests_body", "Review quest progress and turn in completed objectives.")
		"workbench":
			return _text(&"ui.base.interaction.workbench_body", "Use the workbench to craft recipes and research blueprints; install the matching stations to repair or dismantle items.")
		_:
			return _text(&"ui.base.interaction.default_body", "Choose a base facility to prepare the next raid.")


func _refresh_station_mode_tabs() -> void:
	if mode_tabs == null:
		return
	_clear_station_mode_tabs()
	var rows: Array = active_context.get("station_modes", []) as Array
	mode_tabs.visible = active_interaction_id == "workbench" and not rows.is_empty()
	if not mode_tabs.visible:
		return
	for row_value in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row := row_value as Dictionary
		var button := Button.new()
		button.custom_minimum_size = Vector2(88.0, 28.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		button.text = PanelViewModelScript.mode_button_text(row)
		button.disabled = not bool(row.get("enabled", false)) or bool(row.get("is_selected", false))
		button.set_meta("mode_id", str(row.get("id", "")))
		button.set_meta("selected", bool(row.get("is_selected", false)))
		button.set_meta("enabled", bool(row.get("enabled", false)))
		button.set_meta("has_data", bool(row.get("has_data", false)))
		UIStyleScript.apply_font_size(button, UIStyleScript.FONT_HELP)
		if bool(row.get("enabled", false)) and not bool(row.get("is_selected", false)):
			button.pressed.connect(_on_station_mode_button_pressed.bind(str(row.get("id", ""))))
		mode_tabs.add_child(button)


func _clear_station_mode_tabs() -> void:
	if mode_tabs == null:
		return
	for child in mode_tabs.get_children():
		mode_tabs.remove_child(child)
		child.queue_free()
	mode_tabs.visible = false


func _refresh_recipe_list() -> void:
	if recipe_scroll == null or recipe_list == null:
		return
	_clear_recipe_list()
	var selected_mode := str(active_context.get("selected_station_mode", ""))
	var rows: Array = []
	if selected_mode == "blueprints":
		rows = active_context.get("blueprint_rows", []) as Array
	elif selected_mode == "repair":
		rows = active_context.get("repair_rows", []) as Array
	elif selected_mode == "dismantle":
		rows = active_context.get("dismantle_rows", []) as Array
	else:
		rows = active_context.get("recipe_rows", []) as Array
	recipe_scroll.visible = active_interaction_id == "workbench" and not rows.is_empty()
	if not recipe_scroll.visible:
		return
	for row_value in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row := row_value as Dictionary
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 40.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		if selected_mode == "blueprints":
			var blueprint_path := str(row.get("blueprint_item_path", ""))
			button.text = PanelViewModelScript.blueprint_button_text(row, _text)
			button.disabled = not bool(row.get("can_research", false))
			button.set_meta("row_type", "blueprint")
			button.set_meta("blueprint_item_path", blueprint_path)
			button.set_meta("can_research", bool(row.get("can_research", false)))
			button.set_meta("is_researched", bool(row.get("is_researched", false)))
			if bool(row.get("can_research", false)):
				button.pressed.connect(_on_blueprint_button_pressed.bind(blueprint_path))
		elif selected_mode == "repair":
			var repair_id := str(row.get("id", ""))
			button.text = PanelViewModelScript.repair_button_text(row, _text)
			button.disabled = bool(row.get("is_selected", false))
			button.set_meta("row_type", "repair")
			button.set_meta("repair_id", repair_id)
			button.set_meta("selected", bool(row.get("is_selected", false)))
			button.set_meta("can_repair", bool(row.get("can_repair", false)))
			button.set_meta("repair_cost", int(row.get("repair_cost", 0)))
			button.set_meta("source_label", str(row.get("source_label", "")))
			if not bool(row.get("is_selected", false)):
				button.pressed.connect(_on_repair_button_pressed.bind(repair_id))
		elif selected_mode == "dismantle":
			var dismantle_id := str(row.get("id", ""))
			button.text = PanelViewModelScript.dismantle_button_text(row, _text)
			button.disabled = bool(row.get("is_selected", false))
			button.set_meta("row_type", "dismantle")
			button.set_meta("dismantle_id", dismantle_id)
			button.set_meta("selected", bool(row.get("is_selected", false)))
			button.set_meta("can_dismantle", bool(row.get("can_dismantle", false)))
			button.set_meta("output_text", str(row.get("output_text", "")))
			if not bool(row.get("is_selected", false)):
				button.pressed.connect(_on_dismantle_button_pressed.bind(dismantle_id))
		else:
			button.text = PanelViewModelScript.recipe_button_text(row, _text)
			button.set_meta("row_type", "recipe")
			button.set_meta("recipe_id", str(row.get("id", "")))
			button.set_meta("selected", bool(row.get("is_selected", false)))
			button.set_meta("can_craft", bool(row.get("can_craft", false)))
			button.pressed.connect(_on_recipe_button_pressed.bind(str(row.get("id", ""))))
		UIStyleScript.apply_font_size(button, UIStyleScript.FONT_HELP)
		recipe_list.add_child(button)


func _clear_recipe_list() -> void:
	if recipe_list == null:
		return
	for child in recipe_list.get_children():
		recipe_list.remove_child(child)
		child.queue_free()
	if recipe_scroll != null:
		recipe_scroll.visible = false


func _button_states(row_type: String) -> Array[Dictionary]:
	return PanelViewModelScript.button_states(recipe_list, row_type)


func _can_navigate_recipe_list() -> bool:
	return visible and active_interaction_id == "workbench" and str(active_context.get("selected_station_mode", "")) == "craft" and recipe_scroll != null and recipe_scroll.visible and recipe_list != null and _button_states("recipe").size() > 1


func _select_recipe_by_offset(offset: int) -> bool:
	if not _can_navigate_recipe_list():
		return false
	var current_index := _selected_recipe_button_index()
	if current_index < 0:
		current_index = 0
	var button_count := recipe_list.get_child_count()
	var next_index := posmod(current_index + offset, button_count)
	var next_button := recipe_list.get_child(next_index) as Button
	if next_button == null:
		return false
	var recipe_id := str(next_button.get_meta("recipe_id", ""))
	if recipe_id == "":
		return false
	recipe_selected.emit(active_interaction_id, recipe_id)
	return true


func _selected_recipe_button_index() -> int:
	if recipe_list == null:
		return -1
	for index in range(recipe_list.get_child_count()):
		var button := recipe_list.get_child(index) as Button
		if button != null and bool(button.get_meta("selected", false)):
			return index
	return -1


func _text(key: StringName, fallback: String) -> String:
	return UITextScript.text(self, key, fallback)


func _on_recipe_button_pressed(recipe_id: String) -> void:
	if active_interaction_id == "" or recipe_id == "":
		return
	recipe_selected.emit(active_interaction_id, recipe_id)


func _on_station_mode_button_pressed(mode_id: String) -> void:
	if active_interaction_id == "" or mode_id == "":
		return
	station_mode_selected.emit(active_interaction_id, mode_id)


func _on_blueprint_button_pressed(blueprint_item_path: String) -> void:
	if active_interaction_id == "" or blueprint_item_path == "":
		return
	blueprint_selected.emit(active_interaction_id, blueprint_item_path)


func _on_repair_button_pressed(repair_id: String) -> void:
	if active_interaction_id == "" or repair_id == "":
		return
	repair_selected.emit(active_interaction_id, repair_id)


func _on_dismantle_button_pressed(dismantle_id: String) -> void:
	if active_interaction_id == "" or dismantle_id == "":
		return
	dismantle_selected.emit(active_interaction_id, dismantle_id)


func _on_action_button_pressed() -> void:
	if active_interaction_id == "":
		return
	action_requested.emit(active_interaction_id)
