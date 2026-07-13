class_name InventoryEquipmentPainter
extends RefCounted

const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")

var owner: Control
var ui_scale: float = 1.0


func _init(source_owner: Control) -> void:
	owner = source_owner


func set_scale(value: float) -> void:
	ui_scale = value


func panel(rect: Rect2, fill_color: Color, border_color: Color, border_width: int, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(roundi(float(border_width) * ui_scale))
	style.set_corner_radius_all(roundi(float(radius) * ui_scale))
	owner.draw_style_box(style, rect)


func panel_shadow(rect: Rect2) -> void:
	panel(Rect2(rect.position + v(10.0, 10.0), rect.size), UISurfacePaletteScript.shadow(), UISurfacePaletteScript.TRANSPARENT, 0, 22)


func panel_highlight(rect: Rect2) -> void:
	var highlight_rect := Rect2(rect.position + v(10.0, 10.0), Vector2(rect.size.x - 20.0 * ui_scale, 2.0 * ui_scale))
	owner.draw_rect(highlight_rect, UISurfacePaletteScript.panel_highlight())


func slot(rect: Rect2, fill_color: Color, border_color: Color) -> void:
	panel(rect, fill_color, border_color, 2, 8)
	var inner_rect := rect.grow(-3.0 * ui_scale)
	owner.draw_rect(Rect2(inner_rect.position, Vector2(inner_rect.size.x, 1.0 * ui_scale)), UISurfacePaletteScript.panel_highlight())


func header(rect: Rect2, text_value: String) -> void:
	panel(rect, UISurfacePaletteScript.header_fill(), UISurfacePaletteScript.TRANSPARENT, 0, 8)
	text(text_value, rect.position + v(14.0, 25.0), 18, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20.0 * ui_scale)


func equipment_icon(rect: Rect2, index: int) -> void:
	var color := UISurfacePaletteScript.ICON_MUTED
	var center := rect.position + rect.size * 0.5
	var width := maxf(3.0 * ui_scale, 1.5)
	match index:
		0, 1:
			weapon_icon(center, rect.size, color, width)
		2:
			crossed_blades_icon(center, rect.size, color, width)
		3:
			head_icon(center, rect.size, color, width)
		4:
			armor_icon(center, rect.size, color)
		5:
			glasses_icon(center, rect.size, color, width)
		6:
			headset_icon(center, rect.size, color, width)
		7:
			bag_icon(center, rect.size, color)
		_:
			diamond_icon(center, rect.size, color)


func item_label(rect: Rect2, label: String, quantity: int) -> void:
	panel(rect.grow(-8.0 * ui_scale), UISurfacePaletteScript.item_label_fill(), UISurfacePaletteScript.TRANSPARENT, 0, 8)
	text(label.left(4), rect.position + v(8.0, 43.0), 15, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16.0 * ui_scale)
	if quantity > 1:
		text("x%d" % quantity, rect.position + v(8.0, 64.0), 13, UISurfacePaletteScript.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 16.0 * ui_scale)


func lock_badge(rect: Rect2) -> void:
	var badge_rect := Rect2(rect.position + v(6.0, 6.0), v(22.0, 18.0))
	badge(badge_rect, "L", UISurfacePaletteScript.BADGE_LOCK_FILL, UISurfacePaletteScript.BADGE_LOCK_BORDER, UISurfacePaletteScript.BADGE_LOCK_TEXT)


func needed_badge(rect: Rect2) -> void:
	var badge_size := v(22.0, 18.0)
	var badge_rect := Rect2(rect.position + Vector2(rect.size.x - badge_size.x - 6.0 * ui_scale, 6.0 * ui_scale), badge_size)
	badge(badge_rect, "N", UISurfacePaletteScript.BADGE_NEEDED_FILL, UISurfacePaletteScript.BADGE_NEEDED_BORDER, UISurfacePaletteScript.BADGE_NEEDED_TEXT)


func badge(rect: Rect2, label: String, fill_color: Color, border_color: Color, text_color: Color) -> void:
	panel(rect, fill_color, border_color, 1, 4)
	text(label, rect.position + v(2.0, 14.0), 11, text_color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 4.0 * ui_scale)


func scroll_bar(rect: Rect2, scroll_row: int, max_scroll_row: int, scaled_slot_size: Vector2, scaled_slot_gap: float) -> void:
	var visible_scroll_rows := 4
	var track_height := float(visible_scroll_rows) * scaled_slot_size.y + float(maxi(visible_scroll_rows - 1, 0)) * scaled_slot_gap
	var track_width := 10.0 * ui_scale
	var track_rect := Rect2(Vector2(rect.end.x - 10.0 * ui_scale, rect.position.y + 64.0 * ui_scale), Vector2(track_width, track_height))
	scroll_bar_in_track(track_rect, scroll_row, max_scroll_row)


func scroll_bar_in_track(track_rect: Rect2, scroll_row: int, max_scroll_row: int) -> void:
	if max_scroll_row <= 0 or track_rect.size.x <= 0.0 or track_rect.size.y <= 0.0:
		return
	panel(track_rect, UISurfacePaletteScript.SCROLL_TRACK, UISurfacePaletteScript.TRANSPARENT, 0, 3)
	var thumb_height := maxf(track_rect.size.y / float(max_scroll_row + 1), 34.0 * ui_scale)
	var thumb_y := track_rect.position.y + (track_rect.size.y - thumb_height) * float(scroll_row) / float(max_scroll_row)
	panel(Rect2(Vector2(track_rect.position.x, thumb_y), Vector2(track_rect.size.x, thumb_height)), UISurfacePaletteScript.SCROLL_THUMB, UISurfacePaletteScript.TRANSPARENT, 0, 3)


func numeric_slider(slider_rect: Rect2, ratio: float) -> void:
	if slider_rect.size.x <= 0.0 or slider_rect.size.y <= 0.0:
		return
	var track_height := maxf(4.0 * ui_scale, 1.0)
	var track_rect := Rect2(
		Vector2(slider_rect.position.x, slider_rect.get_center().y - track_height * 0.5),
		Vector2(slider_rect.size.x, track_height)
	)
	panel(track_rect, UISurfacePaletteScript.SCROLL_TRACK, UISurfacePaletteScript.TRANSPARENT, 0, 3)
	var clamped_ratio := clampf(ratio, 0.0, 1.0)
	var knob_center := Vector2(slider_rect.position.x + slider_rect.size.x * clamped_ratio, slider_rect.get_center().y)
	owner.draw_circle(knob_center, minf(slider_rect.size.y * 0.5, 10.0 * ui_scale), UISurfacePaletteScript.SCROLL_THUMB)


func text(text_value: String, text_position: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	owner.draw_string(owner.get_theme_default_font(), text_position, text_value, alignment, width, maxi(11, roundi(float(font_size) * ui_scale)), color)


func weapon_icon(center: Vector2, size_value: Vector2, color: Color, width: float) -> void:
	var s := minf(size_value.x, size_value.y)
	owner.draw_line(center + Vector2(-0.30, -0.10) * s, center + Vector2(0.32, -0.10) * s, color, width)
	owner.draw_line(center + Vector2(-0.12, -0.08) * s, center + Vector2(-0.28, 0.28) * s, color, width)
	owner.draw_line(center + Vector2(0.20, -0.08) * s, center + Vector2(0.28, 0.08) * s, color, width)


func crossed_blades_icon(center: Vector2, size_value: Vector2, color: Color, width: float) -> void:
	var s := minf(size_value.x, size_value.y)
	owner.draw_line(center + Vector2(-0.32, -0.32) * s, center + Vector2(0.32, 0.32) * s, color, width)
	owner.draw_line(center + Vector2(0.32, -0.32) * s, center + Vector2(-0.32, 0.32) * s, color, width)


func head_icon(center: Vector2, size_value: Vector2, color: Color, width: float) -> void:
	var s := minf(size_value.x, size_value.y)
	owner.draw_arc(center + Vector2(0.0, 0.06) * s, 0.30 * s, PI, TAU, 18, color, width)
	owner.draw_line(center + Vector2(-0.30, 0.06) * s, center + Vector2(-0.30, 0.30) * s, color, width)
	owner.draw_line(center + Vector2(0.30, 0.06) * s, center + Vector2(0.30, 0.30) * s, color, width)


func armor_icon(center: Vector2, size_value: Vector2, color: Color) -> void:
	var s := minf(size_value.x, size_value.y)
	var points := PackedVector2Array([
		center + Vector2(-0.34, -0.34) * s,
		center + Vector2(-0.10, -0.42) * s,
		center + Vector2(0.0, -0.24) * s,
		center + Vector2(0.10, -0.42) * s,
		center + Vector2(0.34, -0.34) * s,
		center + Vector2(0.25, 0.34) * s,
		center + Vector2(-0.25, 0.34) * s,
	])
	owner.draw_colored_polygon(points, color)


func glasses_icon(center: Vector2, size_value: Vector2, color: Color, width: float) -> void:
	var s := minf(size_value.x, size_value.y)
	owner.draw_arc(center + Vector2(-0.18, 0.0) * s, 0.14 * s, 0.0, TAU, 18, color, width)
	owner.draw_arc(center + Vector2(0.18, 0.0) * s, 0.14 * s, 0.0, TAU, 18, color, width)
	owner.draw_line(center + Vector2(-0.04, 0.0) * s, center + Vector2(0.04, 0.0) * s, color, width)


func headset_icon(center: Vector2, size_value: Vector2, color: Color, width: float) -> void:
	var s := minf(size_value.x, size_value.y)
	owner.draw_arc(center, 0.32 * s, PI, TAU, 20, color, width)
	owner.draw_line(center + Vector2(-0.32, 0.0) * s, center + Vector2(-0.32, 0.28) * s, color, width)
	owner.draw_line(center + Vector2(0.32, 0.0) * s, center + Vector2(0.32, 0.28) * s, color, width)


func bag_icon(center: Vector2, size_value: Vector2, color: Color) -> void:
	var s := minf(size_value.x, size_value.y)
	panel(Rect2(center + Vector2(-0.22, -0.10) * s, Vector2(0.44, 0.42) * s), color, Color.TRANSPARENT, 0, 8)


func diamond_icon(center: Vector2, size_value: Vector2, color: Color) -> void:
	var s := minf(size_value.x, size_value.y)
	var points := PackedVector2Array([
		center + Vector2(0.0, -0.32) * s,
		center + Vector2(0.32, 0.0) * s,
		center + Vector2(0.0, 0.32) * s,
		center + Vector2(-0.32, 0.0) * s,
	])
	owner.draw_colored_polygon(points, color)


func v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * ui_scale
