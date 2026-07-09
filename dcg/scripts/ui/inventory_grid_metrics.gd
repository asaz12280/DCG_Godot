class_name InventoryGridMetrics
extends RefCounted


static func grid_size(columns: int, rows: int, slot_size: Vector2, slot_gap: float) -> Vector2:
	var safe_columns := maxi(columns, 0)
	var safe_rows := maxi(rows, 0)
	if safe_columns == 0 or safe_rows == 0:
		return Vector2.ZERO
	return Vector2(
		float(safe_columns) * slot_size.x + float(safe_columns - 1) * slot_gap,
		float(safe_rows) * slot_size.y + float(safe_rows - 1) * slot_gap
	)


static func slot_rect(grid_rect: Rect2, local_slot_index: int, columns: int, slot_size: Vector2, slot_gap: float) -> Rect2:
	if columns <= 0 or local_slot_index < 0:
		return Rect2()
	var column := local_slot_index % columns
	var row := int(floor(float(local_slot_index) / float(columns)))
	return Rect2(
		grid_rect.position + Vector2(float(column) * (slot_size.x + slot_gap), float(row) * (slot_size.y + slot_gap)),
		slot_size
	)


static func absolute_index_at(position: Vector2, grid_rect: Rect2, columns: int, visible_rows: int, scroll_row: int, total_slots: int, slot_size: Vector2, slot_gap: float) -> int:
	if columns <= 0 or visible_rows <= 0 or total_slots <= 0:
		return -1
	if not grid_rect.has_point(position):
		return -1
	var first_slot := maxi(scroll_row, 0) * columns
	var visible_slots := columns * visible_rows
	var local_limit := mini(visible_slots, maxi(total_slots - first_slot, 0))
	for local_index in range(local_limit):
		if slot_rect(grid_rect, local_index, columns, slot_size, slot_gap).has_point(position):
			return first_slot + local_index
	return -1


static func max_scroll_row(total_slots: int, columns: int, visible_rows: int) -> int:
	if columns <= 0 or visible_rows <= 0 or total_slots <= 0:
		return 0
	return maxi(0, int(ceil(float(total_slots) / float(columns))) - visible_rows)
