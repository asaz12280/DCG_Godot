extends RefCounted

const BaseStashInventoryMarkerSupportScript := preload("res://scripts/ui/base_stash_inventory_marker_support.gd")
const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")
const TOOLTIP_LINE_HEIGHT := 28.0


static func draw_stash_panel(ui: Control, rect: Rect2) -> void:
	var painter = ui.get("_painter")
	var ui_scale := float(ui.get("_ui_scale"))
	painter.panel_shadow(rect)
	painter.panel(rect, UISurfacePaletteScript.panel_fill(), UISurfacePaletteScript.panel_border(), 1, 18)
	painter.panel_highlight(rect)
	painter.text(ui.call("_stash_title_text"), rect.position + _scaled_v(ui_scale, 22.0, 42.0), 24, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 164.0 * ui_scale)
	draw_button(ui, ui.call("_sort_button_rect", rect), ui.call("_localized_text", &"ui.stash.sort", "Sort"), UISurfacePaletteScript.button_fill())

	var grid_rect: Rect2 = ui.call("_stash_grid_rect", rect)
	var category_tabs: Array = ui.call("_stash_category_tabs", rect)
	for tab_state in category_tabs:
		var tab: Dictionary = tab_state as Dictionary
		var tab_rect: Rect2 = tab.get("rect", Rect2())
		var selected := bool(tab.get("selected", false))
		painter.panel(tab_rect, UISurfacePaletteScript.button_fill() if selected else UISurfacePaletteScript.slot_fill(&"equipment"), UISurfacePaletteScript.button_border() if selected else UISurfacePaletteScript.slot_border(), 1, 7)
		painter.text(str(tab.get("short_label", "")), tab_rect.position + _scaled_v(ui_scale, 3.0, 25.0), 16, UISurfacePaletteScript.button_text(), HORIZONTAL_ALIGNMENT_CENTER, tab_rect.size.x - 6.0 * ui_scale)

	var grid_columns := int(ui.get("grid_columns"))
	var stash_scroll_row := int(ui.get("stash_scroll_row"))
	var stash_display_slot_count := int(ui.call("_stash_display_slot_count"))
	var stash_items: Array = ui.get("filtered_stash_items")
	var source_indices: Array = ui.get("filtered_stash_source_indices")
	var visible_stash_rows := int(ui.get("visible_stash_rows"))
	for slot_index in range(grid_columns * visible_stash_rows):
		var display_index := stash_scroll_row * grid_columns + slot_index
		if display_index >= stash_display_slot_count:
			continue
		var slot_rect: Rect2 = ui.call("_grid_slot_rect", grid_rect, slot_index, grid_columns)
		painter.slot(slot_rect, UISurfacePaletteScript.slot_fill(), UISurfacePaletteScript.slot_border())
		if display_index < stash_items.size():
			var source_index := int(source_indices[display_index])
			paint_item_label(ui, slot_rect, stash_items[display_index])
			if BaseStashInventoryMarkerSupportScript.is_needed_stack(stash_items[display_index], ui.get("_needed_item_paths")):
				paint_needed_indicator(ui, slot_rect)
			if BaseStashInventoryMarkerSupportScript.is_locked(ui.get("locked_stash_slots"), source_index):
				paint_lock_indicator(ui, slot_rect)
	var max_scroll_row := int(ui.call("_max_stash_scroll_row"))
	var scroll_track_rect: Rect2 = ui.call("_stash_scroll_track_rect", rect)
	if max_scroll_row > 0:
		painter.scroll_bar_in_track(scroll_track_rect, stash_scroll_row, max_scroll_row)
	else:
		painter.panel(scroll_track_rect, UISurfacePaletteScript.SCROLL_TRACK, UISurfacePaletteScript.TRANSPARENT, 0, 3)
		painter.panel(scroll_track_rect, UISurfacePaletteScript.SCROLL_THUMB, UISurfacePaletteScript.TRANSPARENT, 0, 3)
	draw_stash_currency_panel(ui, rect)


static func draw_stash_currency_panel(ui: Control, panel_rect: Rect2) -> void:
	var painter = ui.get("_painter")
	var ui_scale := float(ui.get("_ui_scale"))
	var currency_rect: Rect2 = ui.call("_stash_currency_panel_rect", panel_rect)
	painter.panel(currency_rect, UISurfacePaletteScript.section_fill(), UISurfacePaletteScript.button_border(), 1, 8)
	var balance_rect: Rect2 = ui.call("_stash_currency_balance_rect", panel_rect)
	painter.panel(balance_rect, UISurfacePaletteScript.slot_fill(), UISurfacePaletteScript.slot_border(), 1, 8)
	painter.text("$ %d" % int(ui.get("_stash_money")), balance_rect.position + _scaled_v(ui_scale, 6.0, 33.0), 20, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER, balance_rect.size.x - 12.0 * ui_scale)
	draw_button(ui, ui.call("_stash_currency_deposit_rect", panel_rect), ui.call("_localized_text", &"ui.stash.deposit", "Deposit"), UISurfacePaletteScript.button_fill(&"success"))
	draw_button(ui, ui.call("_stash_currency_withdraw_rect", panel_rect), ui.call("_localized_text", &"ui.stash.withdraw", "Withdraw"), UISurfacePaletteScript.button_fill())


static func draw_equipment_grid(ui: Control, rect: Rect2) -> void:
	var painter = ui.get("_painter")
	var ui_scale := float(ui.get("_ui_scale"))
	var origin := rect.position + _scaled_v(ui_scale, 24.0, 74.0)
	painter.text(ui.call("_localized_text", &"ui.inventory.equipment", "Equipment"), origin + _scaled_v(ui_scale, 0.0, -12.0), 20, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48.0 * ui_scale)
	var equipment_slot_ids: Array = ui.get("equipment_slot_ids")
	var equipment_slot_label_keys: Array = ui.get("equipment_slot_label_keys")
	for index in range(equipment_slot_ids.size()):
		var slot_rect: Rect2 = ui.call("_equipment_slot_rect", rect, index)
		painter.slot(slot_rect, UISurfacePaletteScript.slot_fill(&"equipment"), UISurfacePaletteScript.slot_border())
		painter.equipment_icon(slot_rect.grow(-13.0 * ui_scale), index)
		var stack: Dictionary = ui.call("_get_equipment_stack_at", index)
		if stack.is_empty():
			painter.text(ui.call("_localized_text", equipment_slot_label_keys[index], ""), slot_rect.position + _scaled_v(ui_scale, 7.0, 62.0), 18, UISurfacePaletteScript.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER, slot_rect.size.x - 14.0 * ui_scale)
		else:
			paint_item_label(ui, slot_rect, stack)
			if BaseStashInventoryMarkerSupportScript.is_needed_stack(stack, ui.get("_needed_item_paths")):
				paint_needed_indicator(ui, slot_rect)
			if BaseStashInventoryMarkerSupportScript.is_locked(ui.get("locked_equipment_slots"), str(equipment_slot_ids[index])):
				paint_lock_indicator(ui, slot_rect)


static func draw_backpack_grid(ui: Control, rect: Rect2) -> void:
	var painter = ui.get("_painter")
	var ui_scale := float(ui.get("_ui_scale"))
	var backpack_grid_rect: Rect2 = ui.call("_backpack_grid_rect", rect)
	var header_rect := Rect2(backpack_grid_rect.position - _scaled_v(ui_scale, 0.0, 42.0), Vector2(backpack_grid_rect.size.x, 32.0 * ui_scale))
	var backpack_format: String = ui.call("_localized_text", &"ui.inventory.backpack_format", "Backpack (%d/%d)")
	painter.header(header_rect, backpack_format % [ui.get("backpack_model").get_used_slots(), int(ui.call("_get_backpack_slots"))])
	var grid_columns := int(ui.get("grid_columns"))
	var backpack_scroll_row := int(ui.get("backpack_scroll_row"))
	var backpack_items: Array = ui.get("backpack_items")
	var visible_backpack_rows := int(ui.get("visible_backpack_rows"))
	var backpack_slots := int(ui.call("_get_backpack_slots"))
	for slot_index in range(grid_columns * visible_backpack_rows):
		var absolute_index := backpack_scroll_row * grid_columns + slot_index
		if absolute_index >= backpack_slots:
			continue
		var slot_rect: Rect2 = ui.call("_grid_slot_rect", backpack_grid_rect, slot_index, grid_columns)
		painter.slot(slot_rect, UISurfacePaletteScript.slot_fill(), UISurfacePaletteScript.slot_border())
		if absolute_index < backpack_items.size():
			paint_item_label(ui, slot_rect, backpack_items[absolute_index])
			if BaseStashInventoryMarkerSupportScript.is_needed_stack(backpack_items[absolute_index], ui.get("_needed_item_paths")):
				paint_needed_indicator(ui, slot_rect)
			if BaseStashInventoryMarkerSupportScript.is_locked(ui.get("locked_backpack_slots"), absolute_index):
				paint_lock_indicator(ui, slot_rect)
	var max_scroll_row := int(ui.call("_max_backpack_scroll_row"))
	if max_scroll_row > 0:
		painter.scroll_bar(rect, backpack_scroll_row, max_scroll_row, ui.get("_scaled_slot_size"), float(ui.get("_scaled_slot_gap")))


static func draw_safe_pocket_grid(ui: Control, rect: Rect2) -> void:
	var painter = ui.get("_painter")
	var ui_scale := float(ui.get("_ui_scale"))
	var safe_rect: Rect2 = ui.call("_safe_pocket_panel_rect", rect)
	painter.header(Rect2(safe_rect.position, Vector2(safe_rect.size.x, 32.0 * ui_scale)), ui.call("_localized_text", &"ui.inventory.safe_pocket", "Safe pocket"))
	var slot_origin := safe_rect.position + _scaled_v(ui_scale, 0.0, 44.0)
	var safe_pocket_items: Array = ui.get("safe_pocket_items")
	var safe_pocket_slots := int(ui.call("_get_safe_pocket_slots"))
	var scaled_slot_size: Vector2 = ui.get("_scaled_slot_size")
	var scaled_slot_gap := float(ui.get("_scaled_slot_gap"))
	for index in range(safe_pocket_slots):
		var slot_rect := Rect2(slot_origin + Vector2(float(index) * (scaled_slot_size.x + scaled_slot_gap), 0.0), scaled_slot_size)
		painter.slot(slot_rect, UISurfacePaletteScript.slot_fill(&"safe"), UISurfacePaletteScript.slot_border())
		if index < safe_pocket_items.size():
			paint_item_label(ui, slot_rect, safe_pocket_items[index])
			if BaseStashInventoryMarkerSupportScript.is_needed_stack(safe_pocket_items[index], ui.get("_needed_item_paths")):
				paint_needed_indicator(ui, slot_rect)
			if BaseStashInventoryMarkerSupportScript.is_locked(ui.get("locked_safe_pocket_slots"), index):
				paint_lock_indicator(ui, slot_rect)


static func draw_button(ui: Control, rect: Rect2, label: String, fill: Color) -> void:
	var painter = ui.get("_painter")
	var ui_scale := float(ui.get("_ui_scale"))
	painter.panel(rect, fill, UISurfacePaletteScript.button_border(), 1, 8)
	painter.text(label, rect.position + _scaled_v(ui_scale, 8.0, 24.0), 18, UISurfacePaletteScript.button_text(), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16.0 * ui_scale)


static func paint_item_label(ui: Control, rect: Rect2, stack: Dictionary) -> void:
	ui.get("_painter").item_label(rect, ui.call("_get_stack_display_name", stack), int(stack.get("quantity", 1)))


static func draw_hover_tooltip(ui: Control, position: Vector2) -> void:
	var stack: Dictionary = ui.call("_tooltip_stack_at_position", position) if ui.has_method("_tooltip_stack_at_position") else ui.call("_stack_at_position", position)
	if stack.is_empty():
		return
	var tooltip: Dictionary = ui.call("_tooltip_state_for_stack", stack)
	if tooltip.is_empty():
		return
	var lines: Array = tooltip.get("lines", []) as Array
	var max_lines := mini(lines.size(), 8)
	var ui_scale := float(ui.get("_ui_scale"))
	var width := 340.0 * ui_scale
	var height := (50.0 + float(max_lines) * TOOLTIP_LINE_HEIGHT) * ui_scale
	var viewport_size := ui.get_viewport_rect().size
	var tooltip_position := position + _scaled_v(ui_scale, 18.0, 18.0)
	tooltip_position.x = clampf(tooltip_position.x, 10.0 * ui_scale, viewport_size.x - width - 10.0 * ui_scale)
	tooltip_position.y = clampf(tooltip_position.y, 10.0 * ui_scale, viewport_size.y - height - 10.0 * ui_scale)
	var rect := Rect2(tooltip_position, Vector2(width, height))
	var painter = ui.get("_painter")
	painter.panel(rect, UISurfacePaletteScript.tooltip_fill(), UISurfacePaletteScript.tooltip_border(), 2, 8)
	painter.text(str(tooltip.get("title", "")), rect.position + _scaled_v(ui_scale, 12.0, 24.0), 20, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0 * ui_scale)
	for index in range(max_lines):
		painter.text(str(lines[index]), rect.position + _scaled_v(ui_scale, 12.0, 52.0 + float(index) * TOOLTIP_LINE_HEIGHT), 18, UISurfacePaletteScript.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0 * ui_scale)


static func paint_lock_indicator(ui: Control, rect: Rect2) -> void:
	ui.get("_painter").lock_badge(rect)


static func paint_needed_indicator(ui: Control, rect: Rect2) -> void:
	ui.get("_painter").needed_badge(rect)


static func _scaled_v(ui_scale: float, x: float, y: float) -> Vector2:
	return Vector2(x, y) * ui_scale
