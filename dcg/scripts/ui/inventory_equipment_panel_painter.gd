extends RefCounted

const InventoryGridMetricsScript := preload("res://scripts/ui/inventory_grid_metrics.gd")


static func paint_shell(owner: Control, painter: RefCounted, panel_rect: Rect2) -> void:
	painter.panel_shadow(panel_rect)
	painter.panel(panel_rect, Color(0.76, 0.77, 0.70, 0.56), Color(1.0, 1.0, 1.0, 0.14), 1, 22)
	painter.panel_highlight(panel_rect)


static func paint_currency(owner: Control, painter: RefCounted, rect: Rect2, icon_text: String, amount: int, ui_scale: float) -> void:
	painter.panel(Rect2(rect.position + Vector2(4.0, 4.0) * ui_scale, rect.size).grow(5.0 * ui_scale), Color(0.0, 0.0, 0.0, 0.10), Color.TRANSPARENT, 0, 10)
	painter.panel(rect, Color(0.74, 0.78, 0.73, 0.68), Color(1.0, 1.0, 1.0, 0.08), 1, 10)
	painter.text(icon_text, rect.position + Vector2(10.0, 30.0) * ui_scale, 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 28.0 * ui_scale)
	painter.text(str(amount), rect.position + Vector2(50.0, 30.0) * ui_scale, 25, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 50.0 * ui_scale)


static func paint_safe_pocket(owner: Control, painter: RefCounted, rect: Rect2, ui_scale: float) -> void:
	painter.panel(Rect2(rect.position + Vector2(8.0, 8.0) * ui_scale, rect.size), Color(0.0, 0.0, 0.0, 0.14), Color.TRANSPARENT, 0, 18)
	painter.panel(rect, Color(0.76, 0.77, 0.70, 0.56), Color(1.0, 1.0, 1.0, 0.14), 1, 18)
	painter.header(Rect2(rect.position + Vector2(12.0, 8.0) * ui_scale, Vector2(rect.size.x - 24.0 * ui_scale, 28.0 * ui_scale)), owner.call("_localized_text", &"ui.inventory.safe_pocket", "安全口袋"))
	var slot_origin := rect.position + Vector2(47.0, 48.0) * ui_scale
	var safe_pocket_items: Array = owner.get("safe_pocket_items") as Array
	for index in range(int(owner.call("_get_safe_pocket_slots"))):
		var slot_rect := Rect2(slot_origin + Vector2(0.0, float(index) * 86.0 * ui_scale), Vector2(74.0, 74.0) * ui_scale)
		painter.slot(slot_rect, Color(0.70, 0.72, 0.66, 0.25), Color(1.0, 1.0, 1.0, 0.28))
		if index < safe_pocket_items.size():
			owner.call("_paint_item_label", slot_rect, safe_pocket_items[index])


static func paint_equipment(owner: Control, painter: RefCounted, rect: Rect2, ui_scale: float) -> void:
	painter.header(Rect2(rect.position, Vector2(rect.size.x, 36.0 * ui_scale)), owner.call("_localized_text", &"ui.inventory.equipment", "裝備"))
	var equipment_slot_ids: Array = owner.get("equipment_slot_ids") as Array
	var equipment_slot_label_keys: Array = owner.get("equipment_slot_label_keys") as Array
	for index in range(equipment_slot_ids.size()):
		var slot_rect: Rect2 = owner.call("_equipment_slot_rect", rect, index)
		painter.slot(slot_rect, Color(0.56, 0.58, 0.53, 0.52), Color(1.0, 1.0, 1.0, 0.22))
		painter.equipment_icon(slot_rect, index)
		var stack: Dictionary = owner.call("_get_equipment_stack_at", index)
		if not stack.is_empty():
			owner.call("_paint_item_label", slot_rect, stack)
		painter.text(owner.call("_localized_text", equipment_slot_label_keys[index], ""), slot_rect.position + Vector2(0.0, slot_rect.size.y + 22.0 * ui_scale), 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, slot_rect.size.x)


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
		painter.slot(slot_rect, Color(0.74, 0.75, 0.68, 0.24), Color(1.0, 1.0, 1.0, 0.28))
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
	painter.panel(label_rect, Color(0.74, 0.78, 0.73, 0.66), Color.TRANSPARENT, 0, 10)
	painter.panel(bar_rect, Color(0.26, 0.30, 0.29, 0.58), Color.TRANSPARENT, 0, 7)
	owner.draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * ratio, bar_rect.size.y)), Color(0.84, 0.88, 0.82, 0.92))
	painter.text(owner.call("_weight_label_text"), label_rect.position + Vector2(16.0, 27.0) * ui_scale, 19, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 52.0 * ui_scale)
	painter.panel(value_rect, Color(0.0, 0.0, 0.0, 0.82), Color.TRANSPARENT, 0, 10)
	var text_color := Color(1.0, 0.48, 0.42, 1.0) if current_weight > weight_limit else Color.WHITE
	painter.text(owner.call("_weight_value_text"), value_rect.position + Vector2(0.0, 27.0) * ui_scale, 19, text_color, HORIZONTAL_ALIGNMENT_CENTER, value_rect.size.x)


static func _paint_button(painter: RefCounted, rect: Rect2, label: String, ui_scale: float) -> void:
	painter.panel(rect.grow(5.0 * ui_scale), Color(0.25, 0.56, 0.78, 0.24), Color.TRANSPARENT, 0, 10)
	painter.panel(rect, Color(0.76, 0.93, 1.0, 0.94), Color(0.48, 0.80, 1.0, 0.74), 2, 9)
	painter.text(label, rect.position + Vector2(0.0, 22.0) * ui_scale, 16, Color(0.23, 0.42, 0.52, 1.0), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
