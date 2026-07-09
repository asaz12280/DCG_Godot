extends RefCounted

const UIStyleScript := preload("res://scripts/ui/ui_style.gd")


static func build(owner: Control, main_panel: PanelContainer) -> Dictionary:
	if main_panel == null:
		main_panel = PanelContainer.new()
		main_panel.name = "MainPanel"
		main_panel.unique_name_in_owner = true
		main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		owner.add_child(main_panel)

	var panel_margin := main_panel.get_node_or_null("PanelMargin") as MarginContainer
	if panel_margin == null:
		panel_margin = MarginContainer.new()
		panel_margin.name = "PanelMargin"
		main_panel.add_child(panel_margin)
	_apply_margin(panel_margin, 22, 18, 22, 18)

	var content := panel_margin.get_node_or_null("Content") as VBoxContainer
	if content == null:
		content = VBoxContainer.new()
		content.name = "Content"
		panel_margin.add_child(content)
	content.add_theme_constant_override("separation", 12)
	_clear_children(content)

	var title_label := _make_label("TitleLabel", "Quests", UIStyleScript.FONT_PANEL_TITLE)
	content.add_child(title_label)
	var hint_label := _make_label("HintLabel", "Review available, active, and completed quests.", UIStyleScript.FONT_PLACEHOLDER)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint_label)

	var tab_row := HBoxContainer.new()
	tab_row.name = "TabRow"
	tab_row.add_theme_constant_override("separation", 8)
	content.add_child(tab_row)
	var available_tab_button := _make_button("AvailableTabButton", "Available", Vector2(190.0, 54.0))
	var active_tab_button := _make_button("ActiveTabButton", "Active", Vector2(190.0, 54.0))
	var completed_tab_button := _make_button("CompletedTabButton", "Completed", Vector2(190.0, 54.0))
	tab_row.add_child(available_tab_button)
	tab_row.add_child(active_tab_button)
	tab_row.add_child(completed_tab_button)

	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	content.add_child(body)

	var left_column := VBoxContainer.new()
	left_column.name = "LeftColumn"
	left_column.custom_minimum_size = Vector2(430.0, 0.0)
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 8)
	body.add_child(left_column)

	var quest_list_panel := PanelContainer.new()
	quest_list_panel.name = "QuestListPanel"
	quest_list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quest_list_panel.add_theme_stylebox_override("panel", _inner_panel_style(Color(0.05, 0.07, 0.10, 0.94)))
	left_column.add_child(quest_list_panel)
	var list_margin := MarginContainer.new()
	list_margin.name = "ListMargin"
	_apply_margin(list_margin, 10, 10, 10, 10)
	quest_list_panel.add_child(list_margin)
	var list_rows := VBoxContainer.new()
	list_rows.name = "ListRows"
	list_rows.add_theme_constant_override("separation", 8)
	list_margin.add_child(list_rows)
	var empty_list_label := _make_label("EmptyListLabel", "No quests in this category.", UIStyleScript.FONT_BODY)
	empty_list_label.visible = false
	empty_list_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_list_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_rows.add_child(empty_list_label)
	var quest_scroll := ScrollContainer.new()
	quest_scroll.name = "QuestScroll"
	quest_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	quest_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_rows.add_child(quest_scroll)
	var quest_list := VBoxContainer.new()
	quest_list.name = "QuestList"
	quest_list.unique_name_in_owner = true
	quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_list.add_theme_constant_override("separation", 8)
	quest_scroll.add_child(quest_list)

	var detail_panel := PanelContainer.new()
	detail_panel.name = "DetailPanel"
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _inner_panel_style(Color(0.10, 0.14, 0.15, 0.94)))
	body.add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	detail_margin.name = "DetailMargin"
	_apply_margin(detail_margin, 28, 24, 28, 24)
	detail_panel.add_child(detail_margin)
	var detail_rows := VBoxContainer.new()
	detail_rows.name = "DetailRows"
	detail_rows.add_theme_constant_override("separation", 12)
	detail_margin.add_child(detail_rows)

	var detail_title_label := _make_label("DetailTitleLabel", "Quest Details", UIStyleScript.FONT_PANEL_TITLE)
	detail_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_rows.add_child(detail_title_label)
	var detail_status_label := _make_label("DetailStatusLabel", "Available", UIStyleScript.FONT_BODY)
	detail_rows.add_child(detail_status_label)
	var detail_description_label := _make_label("DetailDescriptionLabel", "Quest description", UIStyleScript.FONT_PLACEHOLDER)
	detail_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_rows.add_child(detail_description_label)
	var condition_title_label := _make_label("ConditionTitleLabel", "Objectives", UIStyleScript.FONT_BODY)
	detail_rows.add_child(condition_title_label)
	var condition_rows := VBoxContainer.new()
	condition_rows.name = "ConditionRows"
	condition_rows.unique_name_in_owner = true
	condition_rows.add_theme_constant_override("separation", 6)
	detail_rows.add_child(condition_rows)
	var reward_title_label := _make_label("RewardTitleLabel", "Rewards", UIStyleScript.FONT_BODY)
	detail_rows.add_child(reward_title_label)
	var reward_rows := VBoxContainer.new()
	reward_rows.name = "RewardRows"
	reward_rows.unique_name_in_owner = true
	reward_rows.add_theme_constant_override("separation", 6)
	detail_rows.add_child(reward_rows)
	var spacer := Control.new()
	spacer.name = "DetailSpacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_rows.add_child(spacer)
	var status_message_label := _make_label("StatusMessageLabel", "", UIStyleScript.FONT_PLACEHOLDER)
	status_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_rows.add_child(status_message_label)
	var action_button := _make_button("ActionButton", "Accept Quest", Vector2(220.0, 52.0))
	detail_rows.add_child(action_button)

	return {
		"main_panel": main_panel,
		"title_label": title_label,
		"hint_label": hint_label,
		"available_tab_button": available_tab_button,
		"active_tab_button": active_tab_button,
		"completed_tab_button": completed_tab_button,
		"sort_label": null,
		"quest_list": quest_list,
		"empty_list_label": empty_list_label,
		"detail_title_label": detail_title_label,
		"detail_status_label": detail_status_label,
		"detail_description_label": detail_description_label,
		"condition_title_label": condition_title_label,
		"condition_rows": condition_rows,
		"reward_title_label": reward_title_label,
		"reward_rows": reward_rows,
		"status_message_label": status_message_label,
		"action_button": action_button,
	}


static func _make_label(node_name: String, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.unique_name_in_owner = true
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyleScript.apply_font_size(label, font_size)
	return label


static func _make_button(node_name: String, text: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.unique_name_in_owner = true
	button.text = text
	button.custom_minimum_size = minimum_size
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	return button


static func _inner_panel_style(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(1.0, 1.0, 1.0, 0.10)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


static func _apply_margin(margin: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)


static func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()
