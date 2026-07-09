class_name PlayerQuickBarLayout
extends RefCounted

const SLOT_SIZE := Vector2(74.0, 74.0)
const COMPACT_SLOT_SIZE := Vector2(58.0, 58.0)
const GAP := 16.0
const BOTTOM_OFFSET := 88.0


static func slot_rects(viewport_size: Vector2, slots: Array) -> Array[Rect2]:
	var widths: Array[float] = []
	var total_width := 0.0
	for index in range(slots.size()):
		var state: Dictionary = slots[index]
		var key_label := str(state.get("key_label", ""))
		var width := COMPACT_SLOT_SIZE.x if key_label == "V" else SLOT_SIZE.x
		widths.append(width)
		total_width += width
		if index < slots.size() - 1:
			total_width += GAP
	var start := Vector2((viewport_size.x - total_width) * 0.5, viewport_size.y - BOTTOM_OFFSET)
	var cursor_x := start.x
	var result: Array[Rect2] = []
	for index in range(slots.size()):
		var state: Dictionary = slots[index]
		var key_label := str(state.get("key_label", ""))
		var size := COMPACT_SLOT_SIZE if key_label == "V" else SLOT_SIZE
		result.append(Rect2(Vector2(cursor_x, start.y + (SLOT_SIZE.y - size.y)), size))
		cursor_x += size.x + GAP
	return result


static func item_key_at_position(viewport_size: Vector2, slots: Array, position: Vector2) -> int:
	var rects := slot_rects(viewport_size, slots)
	for index in range(rects.size()):
		if not rects[index].has_point(position):
			continue
		var state: Dictionary = slots[index]
		if str(state.get("kind", "")) != "item":
			return -1
		return int(state.get("key", -1))
	return -1
