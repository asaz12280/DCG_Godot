extends PanelContainer
class_name SettingsPanel

signal closed

const SettingsUIStyle := preload("res://scripts/ui/ui_style.gd")

const LANGUAGE_LOCALES := ["zh_TW", "en"]
const LANGUAGE_LABEL_KEYS := ["ui.language.zh_tw", "ui.language.en"]
const RESOLUTION_OPTIONS := [
	Vector2i(2560, 1440),
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1366, 768),
	Vector2i(1280, 720),
]
const DISPLAY_MODE_VALUES := ["fullscreen", "windowed"]
const DISPLAY_MODE_LABEL_KEYS := ["ui.settings.display.fullscreen", "ui.settings.display.windowed"]

var title_label: Label
var back_button: Button
var language_option: OptionButton
var resolution_option: OptionButton
var display_mode_option: OptionButton
var master_volume_slider: HSlider
var master_volume_value_label: Label
var bgm_volume_slider: HSlider
var bgm_volume_value_label: Label
var sfx_volume_slider: HSlider
var sfx_volume_value_label: Label
var settings_scroll: ScrollContainer
var localized_labels: Array[Label] = []
var updating_options := false


func _ready() -> void:
	_build_panel()
	refresh_texts()


func open() -> void:
	refresh_texts()
	visible = true


func refresh_texts() -> void:
	if title_label == null:
		return
	title_label.text = tr("ui.main.settings")
	back_button.text = tr("ui.main.back")
	for label in localized_labels:
		if label != null and label.has_meta("label_key"):
			label.text = tr(str(label.get_meta("label_key")))
	_populate_options()


func get_preferred_panel_size() -> Vector2:
	return SettingsUIStyle.SIZE_MENU_OVERLAY_PANEL


func _build_panel() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_apply_panel_style()

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", SettingsUIStyle.PANEL_MARGIN_LEFT)
	panel_margin.add_theme_constant_override("margin_right", SettingsUIStyle.PANEL_MARGIN_RIGHT)
	panel_margin.add_theme_constant_override("margin_top", SettingsUIStyle.PANEL_MARGIN_TOP)
	panel_margin.add_theme_constant_override("margin_bottom", SettingsUIStyle.PANEL_MARGIN_BOTTOM)
	add_child(panel_margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SettingsUIStyle.SPACING_PANEL_CONTENT)
	panel_margin.add_child(box)

	title_label = Label.new()
	SettingsUIStyle.apply_font_size(title_label, SettingsUIStyle.FONT_PANEL_TITLE)
	box.add_child(title_label)

	settings_scroll = ScrollContainer.new()
	settings_scroll.custom_minimum_size = SettingsUIStyle.SIZE_SETTINGS_SCROLL
	settings_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_child(settings_scroll)

	var form_margin := MarginContainer.new()
	form_margin.add_theme_constant_override("margin_left", 34)
	form_margin.add_theme_constant_override("margin_right", 34)
	form_margin.add_theme_constant_override("margin_top", 8)
	form_margin.add_theme_constant_override("margin_bottom", 8)
	settings_scroll.add_child(form_margin)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", SettingsUIStyle.SPACING_SETTING_ROWS)
	form_margin.add_child(rows)

	language_option = OptionButton.new()
	language_option.item_selected.connect(_on_language_selected)
	rows.add_child(_make_setting_row(&"ui.settings.language", language_option))

	resolution_option = OptionButton.new()
	resolution_option.item_selected.connect(_on_resolution_selected)
	rows.add_child(_make_setting_row(&"ui.settings.resolution", resolution_option))

	display_mode_option = OptionButton.new()
	display_mode_option.item_selected.connect(_on_display_mode_selected)
	rows.add_child(_make_setting_row(&"ui.settings.display_mode", display_mode_option))

	var master_volume_control := _make_volume_control("master")
	rows.add_child(_make_setting_row(&"ui.settings.master_volume", master_volume_control))

	var bgm_volume_control := _make_volume_control("bgm")
	rows.add_child(_make_setting_row(&"ui.settings.bgm_volume", bgm_volume_control))

	var sfx_volume_control := _make_volume_control("sfx")
	rows.add_child(_make_setting_row(&"ui.settings.sfx_volume", sfx_volume_control))

	back_button = Button.new()
	back_button.custom_minimum_size = SettingsUIStyle.SIZE_PANEL_BACK_BUTTON
	back_button.pressed.connect(_on_back_pressed)
	box.add_child(back_button)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_scroll_height()


func _update_scroll_height() -> void:
	if settings_scroll == null:
		return
	var target_height := clampf(size.y - 165.0, 320.0, 540.0)
	settings_scroll.custom_minimum_size = Vector2(0.0, target_height)


func _apply_panel_style() -> void:
	SettingsUIStyle.apply_overlay_panel_style(self)


func _make_setting_row(label_key: StringName, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = SettingsUIStyle.SIZE_SETTING_ROW
	row.add_theme_constant_override("separation", SettingsUIStyle.SPACING_SETTING_ROW)
	var label := Label.new()
	label.custom_minimum_size = SettingsUIStyle.SIZE_SETTING_LABEL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SettingsUIStyle.apply_font_size(label, SettingsUIStyle.FONT_BODY)
	label.set_meta("label_key", str(label_key))
	row.add_child(label)
	localized_labels.append(label)
	control.custom_minimum_size = SettingsUIStyle.SIZE_SETTING_CONTROL
	control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(control)
	return row


func _make_volume_control(volume_id: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.custom_minimum_size = SettingsUIStyle.SIZE_SETTING_CONTROL
	box.add_theme_constant_override("separation", 14)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float) -> void: _on_volume_slider_changed(volume_id, value))
	box.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(62.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SettingsUIStyle.apply_font_size(value_label, SettingsUIStyle.FONT_PLACEHOLDER)
	SettingsUIStyle.apply_font_color(value_label, SettingsUIStyle.COLOR_TEXT_MUTED)
	box.add_child(value_label)

	match volume_id:
		"master":
			master_volume_slider = slider
			master_volume_value_label = value_label
		"bgm":
			bgm_volume_slider = slider
			bgm_volume_value_label = value_label
		"sfx":
			sfx_volume_slider = slider
			sfx_volume_value_label = value_label

	return box


func _populate_options() -> void:
	if language_option == null:
		return
	updating_options = true
	var settings := _get_game_settings()
	var current_locale := TranslationServer.get_locale()
	var current_resolution := Vector2i(1920, 1080)
	var current_display_mode := "fullscreen"
	var current_master_volume := 100
	var current_bgm_volume := 80
	var current_sfx_volume := 80
	if settings != null:
		current_locale = str(settings.get("language_locale"))
		current_resolution = settings.get("resolution")
		current_display_mode = str(settings.get("display_mode"))
		current_master_volume = int(settings.get("master_volume"))
		current_bgm_volume = int(settings.get("bgm_volume"))
		current_sfx_volume = int(settings.get("sfx_volume"))

	language_option.clear()
	for index in range(LANGUAGE_LOCALES.size()):
		var locale := str(LANGUAGE_LOCALES[index])
		var label_key := str(LANGUAGE_LABEL_KEYS[index])
		language_option.add_item(tr(label_key), index)
		language_option.set_item_metadata(index, locale)
		if locale == current_locale:
			language_option.select(index)

	resolution_option.clear()
	for index in range(RESOLUTION_OPTIONS.size()):
		var resolution: Vector2i = RESOLUTION_OPTIONS[index]
		resolution_option.add_item("%d x %d" % [resolution.x, resolution.y], index)
		resolution_option.set_item_metadata(index, resolution)
		if resolution == current_resolution:
			resolution_option.select(index)

	display_mode_option.clear()
	for index in range(DISPLAY_MODE_VALUES.size()):
		var mode := str(DISPLAY_MODE_VALUES[index])
		var label_key := str(DISPLAY_MODE_LABEL_KEYS[index])
		display_mode_option.add_item(tr(label_key), index)
		display_mode_option.set_item_metadata(index, mode)
		if mode == current_display_mode:
			display_mode_option.select(index)

	_set_volume_slider_value(master_volume_slider, master_volume_value_label, current_master_volume)
	_set_volume_slider_value(bgm_volume_slider, bgm_volume_value_label, current_bgm_volume)
	_set_volume_slider_value(sfx_volume_slider, sfx_volume_value_label, current_sfx_volume)
	updating_options = false


func _set_volume_slider_value(slider: HSlider, value_label: Label, value: int) -> void:
	if slider != null:
		slider.value = clampi(value, 0, 100)
	if value_label != null:
		value_label.text = "%d%%" % clampi(value, 0, 100)


func _on_language_selected(index: int) -> void:
	if updating_options:
		return
	var locale := str(language_option.get_item_metadata(index))
	var settings := _get_game_settings()
	if settings != null and settings.has_method("set_language_locale"):
		settings.call("set_language_locale", locale)
	else:
		TranslationServer.set_locale(locale)
	refresh_texts()


func _on_resolution_selected(index: int) -> void:
	if updating_options:
		return
	var resolution: Vector2i = resolution_option.get_item_metadata(index)
	var settings := _get_game_settings()
	if settings != null and settings.has_method("set_resolution"):
		settings.call("set_resolution", resolution)
	refresh_texts()


func _on_display_mode_selected(index: int) -> void:
	if updating_options:
		return
	var display_mode := str(display_mode_option.get_item_metadata(index))
	var settings := _get_game_settings()
	if settings != null and settings.has_method("set_display_mode"):
		settings.call("set_display_mode", display_mode)
	refresh_texts()


func _on_volume_slider_changed(volume_id: String, value: float) -> void:
	var volume := clampi(roundi(value), 0, 100)
	match volume_id:
		"master":
			if master_volume_value_label != null:
				master_volume_value_label.text = "%d%%" % volume
		"bgm":
			if bgm_volume_value_label != null:
				bgm_volume_value_label.text = "%d%%" % volume
		"sfx":
			if sfx_volume_value_label != null:
				sfx_volume_value_label.text = "%d%%" % volume
	if updating_options:
		return
	var settings := _get_game_settings()
	if settings == null:
		return
	match volume_id:
		"master":
			if settings.has_method("set_master_volume"):
				settings.call("set_master_volume", volume)
		"bgm":
			if settings.has_method("set_bgm_volume"):
				settings.call("set_bgm_volume", volume)
		"sfx":
			if settings.has_method("set_sfx_volume"):
				settings.call("set_sfx_volume", volume)


func _on_back_pressed() -> void:
	visible = false
	closed.emit()


func _get_game_settings() -> Node:
	return get_node_or_null("/root/GameSettings")
