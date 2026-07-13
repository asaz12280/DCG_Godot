extends RefCounted

const InventoryGridMetricsScript := preload("res://scripts/ui/inventory_grid_metrics.gd")

const WAREHOUSE_PANEL_WIDTH := 500.0
const WAREHOUSE_RIGHT_MARGIN := 52.0
const STASH_GRID_TOP := 128.0
const STASH_GRID_BOTTOM_INSET := 20.0
const STASH_CATEGORY_TOP := 76.0
const STASH_CATEGORY_HEIGHT := 38.0
const STASH_CATEGORY_GAP := 6.0
const STASH_SCROLL_TRACK_GAP := 10.0
const STASH_SCROLL_TRACK_WIDTH := 12.0
const STASH_SCROLL_TRACK_RIGHT_INSET := 18.0
const STASH_CURRENCY_PANEL_HEIGHT := 84.0
const STASH_CURRENCY_PANEL_GRID_GAP := 18.0
const STASH_CURRENCY_PANEL_BOTTOM_INSET := 24.0
const STASH_CURRENCY_CONTROL_TOP := 16.0
const STASH_CURRENCY_CONTROL_HEIGHT := 52.0
const STASH_CURRENCY_CONTROL_INSET := 14.0
const STASH_CURRENCY_CONTROL_GAP := 12.0
const STASH_CURRENCY_BUTTON_WIDTH := 112.0


static func right_panel_rect(viewport_size: Vector2, reference_panel: Rect2, grid_columns: int, scaled_slot_size: Vector2, scaled_slot_gap: float, ui_scale: float, panel_height: float) -> Rect2:
	var minimum_width := float(grid_columns) * scaled_slot_size.x + float(grid_columns - 1) * scaled_slot_gap + 48.0 * ui_scale
	var panel_width := maxf(WAREHOUSE_PANEL_WIDTH * ui_scale, minimum_width)
	var resolved_height := maxf(panel_height, reference_panel.size.y)
	var x := viewport_size.x - reference_panel.size.x - WAREHOUSE_RIGHT_MARGIN * ui_scale
	return Rect2(Vector2(x, reference_panel.position.y), Vector2(panel_width, resolved_height))


static func panel_height(visible_stash_rows: int, visible_backpack_rows: int, scaled_slot_size: Vector2, scaled_slot_gap: float, ui_scale: float) -> float:
	var stash_grid_height := float(visible_stash_rows) * scaled_slot_size.y + float(visible_stash_rows - 1) * scaled_slot_gap
	var backpack_grid_height := float(visible_backpack_rows) * scaled_slot_size.y + float(visible_backpack_rows - 1) * scaled_slot_gap
	var safe_height := 86.0 * ui_scale + scaled_slot_size.y
	var currency_height := (STASH_GRID_TOP + STASH_CURRENCY_PANEL_HEIGHT + STASH_CURRENCY_PANEL_BOTTOM_INSET + STASH_CURRENCY_PANEL_GRID_GAP) * ui_scale + stash_grid_height
	return maxf(currency_height, 194.0 * ui_scale + backpack_grid_height + safe_height)


static func stash_grid_rect(panel_rect: Rect2, grid_columns: int, visible_rows: int, scaled_slot_size: Vector2, scaled_slot_gap: float, ui_scale: float) -> Rect2:
	return Rect2(panel_rect.position + Vector2(24.0, STASH_GRID_TOP) * ui_scale, InventoryGridMetricsScript.grid_size(grid_columns, visible_rows, scaled_slot_size, scaled_slot_gap))


static func stash_grid_region_rect(panel_rect: Rect2, grid_rect: Rect2, ui_scale: float) -> Rect2:
	var bottom := panel_rect.end.y - STASH_GRID_BOTTOM_INSET * ui_scale
	return Rect2(grid_rect.position, Vector2(grid_rect.size.x, maxf(bottom - grid_rect.position.y, grid_rect.size.y)))


static func category_tab_rects(panel_rect: Rect2, grid_rect: Rect2, category_count: int, ui_scale: float) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if category_count <= 0:
		return result
	var gap := STASH_CATEGORY_GAP * ui_scale
	var width := (grid_rect.size.x - gap * float(category_count - 1)) / float(category_count)
	var top := panel_rect.position.y + STASH_CATEGORY_TOP * ui_scale
	for index in range(category_count):
		result.append(Rect2(Vector2(grid_rect.position.x + float(index) * (width + gap), top), Vector2(width, STASH_CATEGORY_HEIGHT * ui_scale)))
	return result


static func stash_scroll_track_rect(panel_rect: Rect2, grid_rect: Rect2, ui_scale: float) -> Rect2:
	var preferred_x := grid_rect.end.x + STASH_SCROLL_TRACK_GAP * ui_scale
	var maximum_x := panel_rect.end.x - (STASH_SCROLL_TRACK_RIGHT_INSET + STASH_SCROLL_TRACK_WIDTH) * ui_scale
	return Rect2(
		Vector2(minf(preferred_x, maximum_x), grid_rect.position.y),
		Vector2(STASH_SCROLL_TRACK_WIDTH * ui_scale, grid_rect.size.y)
	)


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
	return Rect2(Vector2(panel_rect.end.x - 126.0 * ui_scale, panel_rect.position.y + 22.0 * ui_scale), Vector2(102.0, 36.0) * ui_scale)


static func stash_currency_panel_rect(panel_rect: Rect2, grid_rect: Rect2, ui_scale: float) -> Rect2:
	var size := Vector2(grid_rect.size.x, STASH_CURRENCY_PANEL_HEIGHT * ui_scale)
	var preferred_y := grid_rect.end.y + STASH_CURRENCY_PANEL_GRID_GAP * ui_scale
	var maximum_y := panel_rect.end.y - size.y - STASH_CURRENCY_PANEL_BOTTOM_INSET * ui_scale
	return Rect2(Vector2(grid_rect.position.x, minf(preferred_y, maximum_y)), size)


static func stash_currency_deposit_rect(currency_rect: Rect2, ui_scale: float) -> Rect2:
	var balance_rect := stash_currency_balance_rect(currency_rect, ui_scale)
	var gap := STASH_CURRENCY_CONTROL_GAP * ui_scale
	var content_rect := _stash_currency_content_rect(currency_rect, ui_scale)
	return Rect2(Vector2(balance_rect.end.x + gap, content_rect.position.y), Vector2(STASH_CURRENCY_BUTTON_WIDTH * ui_scale, content_rect.size.y))


static func stash_currency_withdraw_rect(currency_rect: Rect2, ui_scale: float) -> Rect2:
	var deposit_rect := stash_currency_deposit_rect(currency_rect, ui_scale)
	var gap := STASH_CURRENCY_CONTROL_GAP * ui_scale
	return Rect2(Vector2(deposit_rect.end.x + gap, deposit_rect.position.y), deposit_rect.size)


static func stash_currency_balance_rect(currency_rect: Rect2, ui_scale: float) -> Rect2:
	var content_rect := _stash_currency_content_rect(currency_rect, ui_scale)
	var gap := STASH_CURRENCY_CONTROL_GAP * ui_scale
	var button_width := STASH_CURRENCY_BUTTON_WIDTH * ui_scale
	var balance_width := maxf(content_rect.size.x - button_width * 2.0 - gap * 2.0, 72.0 * ui_scale)
	return Rect2(content_rect.position, Vector2(balance_width, content_rect.size.y))


static func _stash_currency_content_rect(currency_rect: Rect2, ui_scale: float) -> Rect2:
	var inset := STASH_CURRENCY_CONTROL_INSET * ui_scale
	return Rect2(
		currency_rect.position + Vector2(inset, STASH_CURRENCY_CONTROL_TOP * ui_scale),
		Vector2(maxf(currency_rect.size.x - inset * 2.0, 0.0), STASH_CURRENCY_CONTROL_HEIGHT * ui_scale)
	)


static func store_all_button_rect(layout: RefCounted, panel_rect: Rect2, ui_scale: float) -> Rect2:
	var backpack_rect: Rect2 = layout.backpack_rect(panel_rect)
	return Rect2(Vector2(backpack_rect.end.x - 112.0 * ui_scale, backpack_rect.position.y + 7.0 * ui_scale), Vector2(96.0, 32.0) * ui_scale)


static func storage_upgrade_button_rect(panel_rect: Rect2, ui_scale: float) -> Rect2:
	return Rect2(panel_rect.position + Vector2(panel_rect.size.x - 98.0 * ui_scale, 114.0 * ui_scale), Vector2(74.0, 32.0) * ui_scale)


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
