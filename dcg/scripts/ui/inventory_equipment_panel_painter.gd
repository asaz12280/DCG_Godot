extends RefCounted

const InventoryGridMetricsScript := preload("res://scripts/ui/inventory_grid_metrics.gd")
const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")


static func paint_shell(owner: Control, painter: RefCounted, panel_rect: Rect2) -> void:
	painter.panel_shadow(panel_rect)
	painter.panel(panel_rect, UISurfacePaletteScript.panel_fill(), UISurfacePaletteScript.panel_border(), 1, 22)
	painter.panel_highlight(panel_rect)


static func paint_currency(owner: Control, painter: RefCounted, rect: Rect2, icon_text: String, amount: int, ui_scale: float) -> void:
	painter.panel(Rect2(rect.position + Vector2(4.0, 4.0) * ui_scale, rect.size).grow(5.0 * ui_scale), UISurfacePaletteScript.shadow(), UISurfacePaletteScript.TRANSPARENT, 0, 10)
	painter.panel(rect, UISurfacePaletteScript.section_fill(), UISurfacePaletteScript.slot_border(true), 1, 10)
	painter.text(icon_text, rect.position + Vector2(10.0, 30.0) * ui_scale, 18, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER, 28.0 * ui_scale)
	painter.text(str(amount), rect.position + Vector2(50.0, 30.0) * ui_scale, 18, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 50.0 * ui_scale)


static func paint_safe_pocket(owner: Control, painter: RefCounted, rect: Rect2, ui_scale: float) -> void:
	painter.panel(Rect2(rect.position + Vector2(8.0, 8.0) * ui_scale, rect.size), UISurfacePaletteScript.shadow(), UISurfacePaletteScript.TRANSPARENT, 0, 18)
	painter.panel(rect, UISurfacePaletteScript.panel_fill(), UISurfacePaletteScript.panel_border(), 1, 18)
	painter.header(Rect2(rect.position + Vector2(12.0, 8.0) * ui_scale, Vector2(rect.size.x - 24.0 * ui_scale, 28.0 * ui_scale)), owner.call("_localized_text", &"ui.inventory.safe_pocket", "安全口袋"))
	var slot_origin := rect.position + Vector2(47.0, 48.0) * ui_scale
	var safe_pocket_items: Array = owner.get("safe_pocket_items") as Array
	for index in range(int(owner.call("_get_safe_pocket_slots"))):
		var slot_rect := Rect2(slot_origin + Vector2(0.0, float(index) * 86.0 * ui_scale), Vector2(74.0, 74.0) * ui_scale)
		painter.slot(slot_rect, UISurfacePaletteScript.slot_fill(&"safe"), UISurfacePaletteScript.slot_border())
		if index < safe_pocket_items.size():
			owner.call("_paint_item_label", slot_rect, safe_pocket_items[index])


static func paint_equipment(owner: Control, painter: RefCounted, rect: Rect2, ui_scale: float) -> void:
	painter.header(Rect2(rect.position, Vector2(rect.size.x, 36.0 * ui_scale)), owner.call("_localized_text", &"ui.inventory.equipment", "裝備"))
	var equipment_slot_ids: Array = owner.get("equipment_slot_ids") as Array
	var equipment_slot_label_keys: Array = owner.get("equipment_slot_label_keys") as Array
	for index in range(equipment_slot_ids.size()):
		var slot_rect: Rect2 = owner.call("_equipment_slot_rect", rect, index)
		painter.slot(slot_rect, UISurfacePaletteScript.slot_fill(&"equipment"), UISurfacePaletteScript.slot_border())
		painter.equipment_icon(slot_rect, index)
		var stack: Dictionary = owner.call("_get_equipment_stack_at", index)
		if not stack.is_empty():
			owner.call("_paint_item_label", slot_rect, stack)
		painter.text(owner.call("_localized_text", equipment_slot_label_keys[index], ""), slot_rect.position + Vector2(0.0, slot_rect.size.y + 22.0 * ui_scale), 18, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER, slot_rect.size.x)


static func paint_backpack(owner: Control, painter: RefCounted, rect: Rect2, ui_scale: float) -> void:
	var backpack_model = owner.get("backpack_model")
	painter.header(Rect2(rect.position, Vector2(rect.size.x, 50.0 * ui_scale)), owner.call("_localized_text", &"ui.inventory.backpack_format", "") % [backpack_model.get_used_slots(), owner.call("_get_backpack_slots")])
	var organize_rect: Rect2 = owner.call("_organize_button_rect_for_backpack", rect)
	owner.set("_organize_button_rect", organize_rect)
	if bool(owner.get("_store_all_button_visible")):
		var store_all_rect: Rect2 = owner.call("_store_all_button_rect_for_backpack", rect)
		owner.set("_store_all_button_rect", store_all_rect)
		_paint_button(painter, store_all_rect, owner.call("_store_all_button_text"), ui_scale)
	else:
		owner.set("_store_all_button_rect", Rect2())
	_paint_button(painter, organize_rect, owner.call("_sort_button_text"), ui_scale)

	var total_slots := int(owner.call("_get_backpack_slots"))
	var columns := int(owner.get("backpack_columns"))
	var visible_rows := 4
	var max_scroll_row: int = InventoryGridMetricsScript.max_scroll_row(total_slots, columns, visible_rows)
	owner.set("backpack_scroll_row", clampi(int(owner.get("backpack_scroll_row")), 0, max_scroll_row))
	var backpack_items: Array = owner.get("backpack_items") as Array
	var scroll_row := int(owner.get("backpack_scroll_row"))
	for slot_index in range(scroll_row * columns, mini((scroll_row + visible_rows) * columns, total_slots)):
		var slot_rect: Rect2 = owner.call("_backpack_slot_rect", rect, slot_index)
		painter.slot(slot_rect, UISurfacePaletteScript.slot_fill(), UISurfacePaletteScript.slot_border())
		if slot_index < backpack_items.size():
			owner.call("_paint_item_label", slot_rect, backpack_items[slot_index])
	if max_scroll_row > 0:
		painter.scroll_bar(rect, scroll_row, max_scroll_row, owner.get("_scaled_slot_size"), float(owner.get("_scaled_slot_gap")))


static func paint_weight(owner: Control, painter: RefCounted, rect: Rect2, ui_scale: float) -> void:
	var current_weight := float(owner.call("_get_current_weight"))
	var weight_limit := float(owner.call("_get_carry_weight_limit"))
	var ratio := 0.0 if weight_limit <= 0.0 else clampf(current_weight / weight_limit, 0.0, 1.0)
	var label_rect := Rect2(rect.position, Vector2(220.0, 40.0) * ui_scale)
	var value_rect := Rect2(Vector2(label_rect.end.x + 22.0 * ui_scale, rect.position.y), Vector2(150.0, 40.0) * ui_scale)
	var bar_rect := Rect2(label_rect.position + Vector2(68.0, 14.0) * ui_scale, Vector2(130.0, 12.0) * ui_scale)
	painter.panel(label_rect, UISurfacePaletteScript.section_fill(), UISurfacePaletteScript.TRANSPARENT, 0, 10)
	painter.panel(bar_rect, UISurfacePaletteScript.BAR_TRACK, UISurfacePaletteScript.TRANSPARENT, 0, 7)
	owner.draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * ratio, bar_rect.size.y)), UISurfacePaletteScript.BAR_FILL)
	painter.text(owner.call("_weight_label_text"), label_rect.position + Vector2(16.0, 27.0) * ui_scale, 18, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, 52.0 * ui_scale)
	painter.panel(value_rect, UISurfacePaletteScript.panel_fill(true), UISurfacePaletteScript.TRANSPARENT, 0, 10)
	var text_color := UISurfacePaletteScript.TEXT_DANGER if current_weight > weight_limit else UISurfacePaletteScript.TEXT_PRIMARY
	painter.text(owner.call("_weight_value_text"), value_rect.position + Vector2(0.0, 27.0) * ui_scale, 18, text_color, HORIZONTAL_ALIGNMENT_CENTER, value_rect.size.x)


static func _paint_button(painter: RefCounted, rect: Rect2, label: String, ui_scale: float) -> void:
	painter.panel(rect.grow(5.0 * ui_scale), UISurfacePaletteScript.shadow(), UISurfacePaletteScript.TRANSPARENT, 0, 10)
	painter.panel(rect, UISurfacePaletteScript.button_fill(), UISurfacePaletteScript.button_border(), 2, 9)
	painter.text(label, rect.position + Vector2(0.0, 22.0) * ui_scale, 18, UISurfacePaletteScript.button_text(), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
