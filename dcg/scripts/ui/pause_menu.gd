extends Control
class_name PauseMenu

const PauseUIStyle := preload("res://scripts/ui/ui_style.gd")

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var is_open := false
var title_label: Label
var button_box: VBoxContainer
var resume_button: Button
var settings_button: Button
var main_menu_button: Button
var quit_button: Button
var settings_panel: SettingsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_menu()
	refresh_texts()


func open_pause() -> void:
	is_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_main_buttons()
	refresh_texts()
	resume_button.grab_focus()


func close_pause() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if settings_panel != null:
		settings_panel.visible = false
	get_tree().paused = false


func refresh_texts() -> void:
	if title_label == null:
		return
	title_label.text = _text("ui.pause.title", "暫停")
	resume_button.text = _text("ui.pause.resume", "回到遊戲")
	settings_button.text = _text("ui.pause.settings", "設定")
	main_menu_button.text = _text("ui.pause.main_menu", "回到主菜單")
	quit_button.text = _text("ui.pause.quit", "退出遊戲")
	if settings_panel != null:
		settings_panel.refresh_texts()


func _build_menu() -> void:
	title_label = Label.new()
	title_label.position = Vector2(84.0, 300.0)
	title_label.size = Vector2(280.0, 64.0)
	PauseUIStyle.apply_font_size(title_label, PauseUIStyle.FONT_PANEL_TITLE)
	PauseUIStyle.apply_font_color(title_label, PauseUIStyle.COLOR_TEXT_PRIMARY)
	add_child(title_label)

	button_box = VBoxContainer.new()
	button_box.position = Vector2(84.0, 380.0)
	button_box.size = Vector2(230.0, 240.0)
	button_box.add_theme_constant_override("separation", 10)
	add_child(button_box)

	resume_button = _make_pause_button(_on_resume_pressed)
	settings_button = _make_pause_button(_on_settings_pressed)
	main_menu_button = _make_pause_button(_on_main_menu_pressed)
	quit_button = _make_pause_button(_on_quit_pressed)
	button_box.add_child(resume_button)
	button_box.add_child(settings_button)
	button_box.add_child(main_menu_button)
	button_box.add_child(quit_button)

	settings_panel = SettingsPanel.new()
	settings_panel.visible = false
	settings_panel.closed.connect(_on_settings_closed)
	add_child(settings_panel)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_settings_panel()


func _draw() -> void:
	if not is_open:
		return
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.0, 0.08, 0.13, 0.76))
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.0, 0.0, 0.0, 0.16))


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if settings_panel != null and settings_panel.visible:
			_on_settings_closed()
		else:
			_on_resume_pressed()
		get_viewport().set_input_as_handled()


func _make_pause_button(callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(160.0, 44.0)
	button.focus_mode = Control.FOCUS_ALL
	PauseUIStyle.apply_font_size(button, PauseUIStyle.FONT_BODY)
	button.pressed.connect(callback)
	return button


func _show_main_buttons() -> void:
	button_box.visible = true
	title_label.visible = true
	if settings_panel != null:
		settings_panel.visible = false
	queue_redraw()


func _on_resume_pressed() -> void:
	var ui_manager := get_node_or_null("/root/UIManager")
	if ui_manager != null and ui_manager.has_method("close_active_ui"):
		ui_manager.call("close_active_ui")
	else:
		close_pause()


func _on_settings_pressed() -> void:
	button_box.visible = false
	title_label.visible = false
	_layout_settings_panel()
	settings_panel.open()
	settings_panel.grab_focus()


func _on_settings_closed() -> void:
	_show_main_buttons()
	settings_button.grab_focus()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()


func _layout_settings_panel() -> void:
	if settings_panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var preferred_size := PauseUIStyle.SIZE_MENU_OVERLAY_PANEL
	if settings_panel.has_method("get_preferred_panel_size"):
		var preferred_value: Variant = settings_panel.call("get_preferred_panel_size")
		if preferred_value is Vector2:
			preferred_size = preferred_value
	var panel_size := Vector2(
		minf(preferred_size.x, viewport_size.x - 160.0),
		minf(preferred_size.y, viewport_size.y - 140.0)
	)
	settings_panel.position = Vector2(
		floor((viewport_size.x - panel_size.x) * 0.5),
		floor((viewport_size.y - panel_size.y) * 0.5)
	)
	settings_panel.size = panel_size


func _text(key: String, fallback: String) -> String:
	var translated := tr(key)
	return fallback if translated == key else translated
