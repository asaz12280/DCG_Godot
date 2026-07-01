class_name ItemCodexGridModel
extends RefCounted

# // Keeps codex grid math reusable so future node-based slots, dragging, tooltips, and filters share one model. //
var columns: int = 10
var visible_rows: int = 6
var minimum_slots: int = 100
var slot_count: int = 100


func configure(highest_catalog_number: int) -> void:
	var normalized_highest := maxi(minimum_slots, highest_catalog_number)
	slot_count = int(ceil(float(normalized_highest) / float(columns))) * columns


func get_max_scroll_row() -> int:
	return maxi(0, int(ceil(float(slot_count) / float(columns))) - visible_rows)


func get_slot_number(scroll_row: int, visible_row: int, column: int) -> int:
	return (scroll_row + visible_row) * columns + column + 1


func has_slot(number: int) -> bool:
	return number >= 1 and number <= slot_count
