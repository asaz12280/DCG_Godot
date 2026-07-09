extends RefCounted

const InventoryGridMetricsScript := preload("res://scripts/ui/inventory_grid_metrics.gd")


static func right_panel_rect(viewport_size: Vector2, reference_panel: Rect2, grid_columns: int, scaled_slot_size: Vector2, scaled_slot_gap: float, ui_scale: float, panel_height: float) -> Rect2:
	var minimum_width := float(grid_columns) * scaled_slot_size.x + float(grid_columns - 1) * scaled_slot_gap + 48.0 * ui_scale
	var panel_width := maxf(560.0 * ui_scale, minimum_width)
	var resolved_height := maxf(panel_height, reference_panel.size.y)
	var x := viewport_size.x - panel_width - 52.0 * ui_scale
	return Rect2(Vector2(x, reference_panel.position.y), Vector2(panel_width, resolved_height))


static func panel_height(visible_stash_rows: int, visible_backpack_rows: int, scaled_slot_size: Vector2, scaled_slot_gap: float, ui_scale: float) -> float:
	var stash_grid_height := float(visible_stash_rows) * scaled_slot_size.y + float(visible_stash_rows - 1) * scaled_slot_gap
	var backpack_grid_height := float(visible_backpack_rows) * scaled_slot_size.y + float(visible_backpack_rows - 1) * scaled_slot_gap
	var safe_height := 86.0 * ui_scale + scaled_slot_size.y
	return maxf(170.0 * ui_scale + stash_grid_height, 194.0 * ui_scale + backpack_grid_height + safe_height)


static func stash_grid_rect(panel_rect: Rect2, grid_columns: int, visible_rows: int, scaled_slot_size: Vector2, scaled_slot_gap: float, ui_scale: float) -> Rect2:
	return Rect2(panel_rect.position + Vector2(24.0, 96.0) * ui_scale, InventoryGridMetricsScript.grid_size(grid_columns, visible_rows, scaled_slot_size, scaled_slot_gap))


static func backpack_grid_rect(layout: RefCounted, panel_rect: Rect2, grid_columns: int, visible_rows: int, scaled_slot_size: Vector2, scaled_slot_gap: float, ui_scale: float) -> Rect2:
	var backpack_rect: Rect2 = layout.backpack_rect(panel_rect)
	return Rect2(backpack_rect.position + Vector2(28.0, 64.0) * ui_scale, InventoryGridMetricsScript.grid_size(grid_columns, visible_rows, scaled_slot_size, scaled_slot_gap))


static func equipment_slot_rect(layout: RefCounted, panel_rect: Rect2, index: int, ui_scale: float) -> Rect2:
	var equipment_rect: Rect2 = layout.equipment_rect(panel_rect)
	var slot_size := Vector2(80.0, 80.0) * ui_scale
	var start: Vector2 = equipment_rect.position + Vector2(20.0, 54.0) * ui_scale
	var step_x := 90.0 * ui_scale
	var step_y := 132.0 * ui_scale
	var row := int(floor(float(index) / 5.0))
	var column := index % 5
	return Rect2(start + Vector2(float(column) * step_x, float(row) * step_y), slot_size)


static func sort_button_rect(panel_rect: Rect2, ui_scale: float) -> Rect2:
	return Rect2(panel_rect.position + Vector2(panel_rect.size.x - 176.0 * ui_scale, 24.0 * ui_scale), Vector2(76.0, 32.0) * ui_scale)


static func store_all_button_rect(layout: RefCounted, panel_rect: Rect2, ui_scale: float) -> Rect2:
	var backpack_rect: Rect2 = layout.backpack_rect(panel_rect)
	return Rect2(Vector2(backpack_rect.end.x - 112.0 * ui_scale, backpack_rect.position.y + 7.0 * ui_scale), Vector2(96.0, 32.0) * ui_scale)


static func storage_upgrade_button_rect(panel_rect: Rect2, ui_scale: float) -> Rect2:
	return Rect2(panel_rect.position + Vector2(panel_rect.size.x - 98.0 * ui_scale, 114.0 * ui_scale), Vector2(74.0, 32.0) * ui_scale)


static func close_button_rect(panel_rect: Rect2, ui_scale: float) -> Rect2:
	return Rect2(panel_rect.position + Vector2(panel_rect.size.x - 90.0 * ui_scale, 24.0 * ui_scale), Vector2(66.0, 32.0) * ui_scale)


static func equipment_index_at(position: Vector2, panel_rect: Rect2, equipment_slot_ids: Array[StringName], layout: RefCounted, ui_scale: float) -> int:
	for index in range(equipment_slot_ids.size()):
		if equipment_slot_rect(layout, panel_rect, index, ui_scale).has_point(position):
			return index
	return -1


static func safe_pocket_index_at(position: Vector2, safe_rect: Rect2, slots: int, ui_scale: float) -> int:
	for index in range(slots):
		var slot_rect := Rect2(safe_rect.position + Vector2(47.0, 48.0 + float(index) * 86.0) * ui_scale, Vector2(74.0, 74.0) * ui_scale)
		if slot_rect.has_point(position):
			return index
	return -1
