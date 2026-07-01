extends BaseMenuScreen

const MenuUIStyle := preload("res://scripts/ui/ui_style.gd")
const DifficultySelectPanelScript := preload("res://scripts/ui/difficulty_select_panel.gd")

const GAMEPLAY_SCENE := "res://scenes/gameplay/player_test_world_3d.tscn"

var load_panel: PanelContainer
var load_title_label: Label
var load_message_label: Label
var load_back_button: Button
var settings_panel: SettingsPanel
var difficulty_panel: Control


func _ready() -> void:
	setup_base_menu(&"ui.main.title", &"ui.main.subtitle")
	add_menu_button(&"ui.main.start", _on_start_pressed)
	add_menu_button(&"ui.main.load", _on_load_pressed)
	add_menu_button(&"ui.main.settings", _on_settings_pressed)
	add_menu_button(&"ui.main.quit", _on_quit_pressed)

	load_panel = make_overlay_panel()
	add_child(load_panel)
	_build_load_panel()

	settings_panel = SettingsPanel.new()
	add_child(settings_panel)

	difficulty_panel = DifficultySelectPanelScript.new()
	add_child(difficulty_panel)

	update_texts()
	layout_menu()
	resized.connect(layout_menu)
	call_deferred("_hide_overlay_panels")


func _on_localization_changed() -> void:
	update_texts()


func _hide_overlay_panels() -> void:
	if load_panel != null:
		load_panel.visible = false
	if settings_panel != null:
		settings_panel.visible = false
	if difficulty_panel != null:
		difficulty_panel.visible = false


func layout_menu() -> void:
	layout_base_menu()
	if load_panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var top := viewport_size.y * 0.18
	var outer_margin := _get_responsive_margin(viewport_size)
	var load_size := Vector2(minf(520.0, viewport_size.x - outer_margin * 2.0), 260.0)
	var load_position := _get_overlay_position(viewport_size, load_size, top + 170.0, outer_margin)
	set_control_rect(load_panel, load_position, load_size)

	var settings_size := Vector2(
		minf(1180.0, viewport_size.x - outer_margin * 2.0),
		minf(680.0, viewport_size.y - outer_margin * 2.0)
	)
	var settings_position := _get_overlay_position(viewport_size, settings_size, top, outer_margin)
	set_control_rect(settings_panel, settings_position, settings_size)

	var difficulty_size := Vector2(
		minf(1180.0, viewport_size.x - outer_margin * 2.0),
		minf(520.0, viewport_size.y - outer_margin * 2.0)
	)
	var difficulty_position := _get_overlay_position(viewport_size, difficulty_size, top, outer_margin)
	set_control_rect(difficulty_panel, difficulty_position, difficulty_size)


func _get_responsive_margin(viewport_size: Vector2) -> float:
	if viewport_size.x < 1600.0:
		return 48.0
	return viewport_size.x * 0.08


func _get_overlay_position(viewport_size: Vector2, panel_size: Vector2, preferred_top: float, margin: float) -> Vector2:
	if viewport_size.x < 1600.0:
		return Vector2(
			floor((viewport_size.x - panel_size.x) * 0.5),
			floor((viewport_size.y - panel_size.y) * 0.5)
		)
	return Vector2(viewport_size.x - panel_size.x - margin, minf(preferred_top, viewport_size.y - panel_size.y - margin))


func update_texts() -> void:
	update_base_texts()
	if load_title_label != null:
		load_title_label.text = tr("ui.main.load")
	if load_message_label != null:
		load_message_label.text = tr("ui.main.load_empty")
	if load_back_button != null:
		load_back_button.text = tr("ui.main.back")
	if settings_panel != null:
		settings_panel.refresh_texts()
	if difficulty_panel != null and difficulty_panel.has_method("refresh_texts"):
		difficulty_panel.call("refresh_texts")


func _build_load_panel() -> void:
	var box := VBoxContainer.new()
	MenuUIStyle.apply_panel_margins(box, MenuUIStyle.SPACING_LOAD_PANEL_CONTENT)
	load_panel.add_child(box)

	load_title_label = Label.new()
	MenuUIStyle.apply_font_size(load_title_label, MenuUIStyle.FONT_PANEL_TITLE)
	box.add_child(load_title_label)

	load_message_label = Label.new()
	load_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MenuUIStyle.apply_font_size(load_message_label, MenuUIStyle.FONT_BODY)
	box.add_child(load_message_label)

	load_back_button = Button.new()
	load_back_button.custom_minimum_size = MenuUIStyle.SIZE_PANEL_BACK_BUTTON
	load_back_button.pressed.connect(func() -> void: load_panel.visible = false)
	box.add_child(load_back_button)


func _on_start_pressed() -> void:
	update_texts()
	load_panel.visible = false
	settings_panel.visible = false
	if difficulty_panel != null and difficulty_panel.has_method("open"):
		difficulty_panel.call("open")


func _on_load_pressed() -> void:
	update_texts()
	settings_panel.visible = false
	difficulty_panel.visible = false
	load_panel.visible = true


func _on_settings_pressed() -> void:
	update_texts()
	load_panel.visible = false
	difficulty_panel.visible = false
	settings_panel.open()


# // ??粹???//
func _on_quit_pressed() -> void:
	get_tree().quit()
