extends Control
class_name BaseMenuScreen

const BaseUIStyle := preload("res://scripts/ui/ui_style.gd")

var title_label: Label
var subtitle_label: Label
var button_box: VBoxContainer


func setup_base_menu(title_key: StringName, subtitle_key: StringName) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	title_label = _make_label(title_key, BaseUIStyle.FONT_TITLE, BaseUIStyle.COLOR_TEXT_PRIMARY)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title_label)

	subtitle_label = _make_label(subtitle_key, BaseUIStyle.FONT_SUBTITLE, BaseUIStyle.COLOR_TEXT_SUBTITLE)
	add_child(subtitle_label)

	button_box = VBoxContainer.new()
	button_box.add_theme_constant_override("separation", BaseUIStyle.SPACING_MENU_BUTTONS)
	add_child(button_box)

	resized.connect(layout_base_menu)


func add_menu_button(label_key: StringName, callback: Callable) -> Button:
	var button := Button.new()
	button.name = str(label_key).replace(".", "_")
	button.set_meta("label_key", str(label_key))
	button.custom_minimum_size = BaseUIStyle.SIZE_MENU_BUTTON
	button.focus_mode = Control.FOCUS_ALL
	BaseUIStyle.apply_font_size(button, BaseUIStyle.FONT_MENU_BUTTON)
	button.pressed.connect(callback)
	button_box.add_child(button)
	return button


func make_overlay_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	BaseUIStyle.apply_overlay_panel_style(panel)
	return panel


func update_base_texts() -> void:
	if title_label == null:
		return
	title_label.text = tr(str(title_label.get_meta("label_key", "")))
	subtitle_label.text = tr(str(subtitle_label.get_meta("label_key", "")))
	for child in button_box.get_children():
		if child is Button:
			(child as Button).text = tr(str(child.get_meta("label_key", "")))


func layout_base_menu() -> void:
	if title_label == null:
		return
	var viewport_size := get_viewport_rect().size
	var left := maxf(48.0, viewport_size.x * 0.11)
	var top := maxf(56.0, viewport_size.y * 0.18)
	var title_width := minf(viewport_size.x - left * 2.0, viewport_size.x * 0.58)
	title_label.position = Vector2(left, top)
	title_label.size = Vector2(title_width, 86.0)
	subtitle_label.position = Vector2(left + 4.0, top + 86.0)
	subtitle_label.size = Vector2(title_width, 40.0)
	button_box.position = Vector2(left, top + 166.0)
	button_box.size = Vector2(340.0, 300.0)


func set_control_rect(control: Control, rect_position: Vector2, rect_size: Vector2) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = rect_position.x
	control.offset_top = rect_position.y
	control.offset_right = rect_position.x + rect_size.x
	control.offset_bottom = rect_position.y + rect_size.y


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), BaseUIStyle.COLOR_MENU_BACKGROUND)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), BaseUIStyle.COLOR_MENU_ATMOSPHERE)

	var ground_y := viewport_size.y * 0.72
	draw_rect(Rect2(Vector2(0.0, ground_y), Vector2(viewport_size.x, viewport_size.y - ground_y)), BaseUIStyle.COLOR_MENU_GROUND)
	for index in range(14):
		var x := float(index) * viewport_size.x / 13.0
		draw_line(Vector2(x, ground_y), Vector2(x - viewport_size.x * 0.12, viewport_size.y), BaseUIStyle.COLOR_MENU_GRID_STRONG, 4.0)
	for index in range(9):
		var y := ground_y + float(index) * (viewport_size.y - ground_y) / 8.0
		draw_line(Vector2(0.0, y), Vector2(viewport_size.x, y), BaseUIStyle.COLOR_MENU_GRID_SOFT, 3.0)


func _make_label(label_key: StringName, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.set_meta("label_key", str(label_key))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	BaseUIStyle.apply_font_size(label, font_size)
	BaseUIStyle.apply_font_color(label, color)
	return label
