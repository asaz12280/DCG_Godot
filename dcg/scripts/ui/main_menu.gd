extends BaseMenuScreen

const DifficultySelectPanelScript := preload("res://scripts/ui/difficulty_select_panel.gd")
const SaveSlotPanelScript := preload("res://scripts/ui/save_slot_panel.gd")

const OVERLAY_PANEL_FALLBACK_SIZE := Vector2(1180.0, 680.0)

var load_panel: PanelContainer
var settings_panel: SettingsPanel
var difficulty_panel: Control


func _ready() -> void:
	setup_base_menu(&"ui.main.title", &"ui.main.subtitle")
	add_menu_button(&"ui.main.start", _on_start_pressed)
	add_menu_button(&"ui.main.load", _on_load_pressed)
	add_menu_button(&"ui.main.settings", _on_settings_pressed)
	add_menu_button(&"ui.main.quit", _on_quit_pressed)

	load_panel = SaveSlotPanelScript.new()
	add_child(load_panel)

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
	var viewport_size := _get_layout_viewport_size()
	var top := viewport_size.y * 0.18
	var outer_margin := _get_responsive_margin(viewport_size)
	var load_size := _get_menu_overlay_panel_size(viewport_size, outer_margin, load_panel)
	var load_position := _get_overlay_position(viewport_size, load_size, top + 170.0, outer_margin)
	set_control_rect(load_panel, load_position, load_size)

	var settings_size := _get_menu_overlay_panel_size(viewport_size, outer_margin, settings_panel)
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


func _get_layout_viewport_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	return get_viewport_rect().size


func _get_menu_overlay_panel_size(viewport_size: Vector2, outer_margin: float, panel: Control) -> Vector2:
	var preferred_size := OVERLAY_PANEL_FALLBACK_SIZE
	if panel != null and panel.has_method("get_preferred_panel_size"):
		var preferred_value: Variant = panel.call("get_preferred_panel_size")
		if preferred_value is Vector2:
			preferred_size = preferred_value
	var available_width := maxf(320.0, viewport_size.x - outer_margin * 2.0)
	var available_height := maxf(280.0, viewport_size.y - outer_margin * 2.0)
	return Vector2(
		minf(preferred_size.x, available_width),
		minf(preferred_size.y, available_height)
	)


func _get_overlay_position(viewport_size: Vector2, panel_size: Vector2, preferred_top: float, margin: float) -> Vector2:
	if viewport_size.x < 1600.0:
		return Vector2(
			floor((viewport_size.x - panel_size.x) * 0.5),
			floor((viewport_size.y - panel_size.y) * 0.5)
		)
	return Vector2(viewport_size.x - panel_size.x - margin, minf(preferred_top, viewport_size.y - panel_size.y - margin))


func update_texts() -> void:
	update_base_texts()
	if load_panel != null:
		load_panel.refresh_texts()
	if settings_panel != null:
		settings_panel.refresh_texts()
	if difficulty_panel != null and difficulty_panel.has_method("refresh_texts"):
		difficulty_panel.call("refresh_texts")


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
	load_panel.open()


func _on_settings_pressed() -> void:
	update_texts()
	load_panel.visible = false
	difficulty_panel.visible = false
	settings_panel.open()


# // ??粹???//
func _on_quit_pressed() -> void:
	get_tree().quit()
