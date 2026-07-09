class_name PlayerHUDPainter
extends RefCounted

const PlayerQuickBarLayoutScript := preload("res://scripts/ui/player_quick_bar_layout.gd")

static func setup_styles(hud) -> void:
	hud.health_background_style.bg_color = Color(0.18, 0.18, 0.16, 0.82)
	hud.health_background_style.corner_radius_top_left = 8
	hud.health_background_style.corner_radius_top_right = 8
	hud.health_background_style.corner_radius_bottom_left = 8
	hud.health_background_style.corner_radius_bottom_right = 8
	hud.health_fill_style.bg_color = Color(1.0, 0.24, 0.2, 1.0)
	hud.health_fill_style.corner_radius_top_left = 6
	hud.health_fill_style.corner_radius_top_right = 6
	hud.health_fill_style.corner_radius_bottom_left = 6
	hud.health_fill_style.corner_radius_bottom_right = 6
	hud.lower_left_panel_style.bg_color = Color(0.16, 0.16, 0.16, 0.88)
	hud.lower_left_panel_style.corner_radius_top_left = 22
	hud.lower_left_panel_style.corner_radius_top_right = 22
	hud.lower_left_panel_style.corner_radius_bottom_left = 22
	hud.lower_left_panel_style.corner_radius_bottom_right = 22
	hud.lower_left_fill_style.bg_color = Color(1.0, 0.36, 0.4, 0.96)
	hud.lower_left_fill_style.corner_radius_top_left = 16
	hud.lower_left_fill_style.corner_radius_top_right = 16
	hud.lower_left_fill_style.corner_radius_bottom_left = 16
	hud.lower_left_fill_style.corner_radius_bottom_right = 16
	hud.lower_left_icon_style.bg_color = Color(0.26, 0.26, 0.26, 0.98)
	hud.lower_left_icon_style.corner_radius_top_left = 20
	hud.lower_left_icon_style.corner_radius_top_right = 20
	hud.lower_left_icon_style.corner_radius_bottom_left = 20
	hud.lower_left_icon_style.corner_radius_bottom_right = 20
	hud.reload_background_style.bg_color = Color(0.14, 0.14, 0.12, 0.78)
	hud.reload_background_style.corner_radius_top_left = 7
	hud.reload_background_style.corner_radius_top_right = 7
	hud.reload_background_style.corner_radius_bottom_left = 7
	hud.reload_background_style.corner_radius_bottom_right = 7
	hud.reload_fill_style.bg_color = Color(0.56, 0.82, 1.0, 0.96)
	hud.reload_fill_style.corner_radius_top_left = 5
	hud.reload_fill_style.corner_radius_top_right = 5
	hud.reload_fill_style.corner_radius_bottom_left = 5
	hud.reload_fill_style.corner_radius_bottom_right = 5
	hud.ammo_panel_style.bg_color = Color(0.12, 0.12, 0.11, 0.86)
	hud.ammo_panel_style.corner_radius_top_left = 18
	hud.ammo_panel_style.corner_radius_top_right = 18
	hud.ammo_panel_style.corner_radius_bottom_left = 18
	hud.ammo_panel_style.corner_radius_bottom_right = 18


static func paint(hud) -> void:
	_paint_player_health(hud)
	_paint_enemy_health_bars(hud)
	_paint_lower_left_health(hud)
	_paint_damage_feedback(hud)
	_paint_stamina_ring(hud)
	_paint_quick_bar(hud)
	_paint_ammo_panel(hud)
	_paint_reload_progress(hud)
	_paint_item_use_progress(hud)
	_paint_melee_slash(hud)
	_paint_crosshair(hud)


static func _paint_player_health(hud) -> void:
	if hud.player == null:
		return
	var current_health: float = hud.player.get("health")
	var maximum_health: float = hud.player.get_total_max_health() if hud.player.has_method("get_total_max_health") else hud.player.get("max_health")
	var ratio := 0.0
	if maximum_health > 0.0:
		ratio = clampf(current_health / maximum_health, 0.0, 1.0)
	_paint_health_bar(hud, hud._get_player_screen_position(hud.health_offset), hud.health_size, ratio)


static func _paint_enemy_health_bars(hud) -> void:
	for state in hud._enemy_health_bar_states():
		if not bool(state.get("visible", false)):
			continue
		_paint_health_bar(hud, state.get("center", Vector2.ZERO), state.get("size", hud.enemy_health_size), float(state.get("ratio", 0.0)))


static func _paint_health_bar(hud, center: Vector2, bar_size: Vector2, ratio: float) -> void:
	var background_rect := Rect2(center - bar_size * 0.5, bar_size)
	var fill_rect := background_rect.grow(-4.0)
	fill_rect.size.x *= clampf(ratio, 0.0, 1.0)
	hud.draw_style_box(hud.health_background_style, background_rect)
	if fill_rect.size.x > 0.0:
		hud.draw_style_box(hud.health_fill_style, fill_rect)


static func _paint_lower_left_health(hud) -> void:
	if hud.player == null:
		return
	var current_health: float = hud.player.get("health")
	var maximum_health: float = hud.player.get_total_max_health() if hud.player.has_method("get_total_max_health") else hud.player.get("max_health")
	var ratio := clampf(current_health / maximum_health, 0.0, 1.0)
	var panel_position := Vector2(hud.lower_left_health_position.x, hud.size.y + hud.lower_left_health_position.y)
	var panel_rect := Rect2(panel_position, hud.lower_left_health_size)
	var icon_rect := Rect2(panel_rect.position + Vector2(7.0, 6.0), Vector2(36.0, 32.0))
	var bar_rect := Rect2(panel_rect.position + Vector2(48.0, 7.0), Vector2(panel_rect.size.x - 56.0, panel_rect.size.y - 14.0))
	var fill_rect := bar_rect.grow(-4.0)
	fill_rect.size.x *= ratio
	hud.draw_style_box(hud.lower_left_panel_style, panel_rect)
	hud.draw_style_box(hud.lower_left_icon_style, icon_rect)
	hud.draw_style_box(hud.lower_left_fill_style, fill_rect)
	_paint_heart_icon(hud, icon_rect.get_center(), 12.0, Color(1.0, 0.36, 0.4, 1.0))
	var health_text := "%d / %d" % [roundi(current_health), roundi(maximum_health)]
	var font := ThemeDB.fallback_font
	var font_size := 22
	var text_size := font.get_string_size(health_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_position := bar_rect.position + (bar_rect.size - text_size) * 0.5 + Vector2(0.0, text_size.y * 0.72)
	hud.draw_string(font, text_position, health_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 1.0, 1.0, 0.98))


static func _paint_damage_feedback(hud) -> void:
	var alpha: float = hud._damage_feedback_alpha()
	if alpha <= 0.0:
		return
	hud.draw_rect(Rect2(Vector2.ZERO, hud.size), Color(1.0, 0.12, 0.08, 0.16 * alpha), true)
	hud.draw_rect(Rect2(Vector2.ZERO, hud.size), Color(1.0, 0.2, 0.16, 0.55 * alpha), false, 8.0)


static func _paint_heart_icon(hud, center: Vector2, icon_scale: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, 0.78) * icon_scale,
		center + Vector2(-0.92, -0.1) * icon_scale,
		center + Vector2(-0.72, -0.78) * icon_scale,
		center + Vector2(-0.24, -0.86) * icon_scale,
		center + Vector2(0.0, -0.55) * icon_scale,
		center + Vector2(0.24, -0.86) * icon_scale,
		center + Vector2(0.72, -0.78) * icon_scale,
		center + Vector2(0.92, -0.1) * icon_scale,
	])
	hud.draw_colored_polygon(points, color)


static func _paint_stamina_ring(hud) -> void:
	if hud.stamina >= hud.max_stamina - 0.05 and hud.stamina_visible_time <= 0.0:
		return
	var center: Vector2 = hud._get_player_screen_position(hud.stamina_offset)
	var ratio := clampf(hud.stamina / hud.max_stamina, 0.0, 1.0)
	var draw_scale := 2.0
	hud.draw_set_transform(center, 0.0, Vector2(1.0 / draw_scale, 1.0 / draw_scale))
	hud.draw_circle(Vector2.ZERO, (hud.ring_radius + 8.0) * draw_scale, Color(0.16, 0.16, 0.16, 0.72))
	hud.draw_arc(Vector2.ZERO, hud.ring_radius * draw_scale, 0.0, TAU, 160, Color(0.78, 0.78, 0.72, 1.0), (hud.ring_width + 4.0) * draw_scale, true)
	hud.draw_arc(Vector2.ZERO, hud.ring_radius * draw_scale, -PI * 0.5, -PI * 0.5 + TAU * ratio, 160, Color(0.56, 1.0, 0.48, 1.0), hud.ring_width * draw_scale, true)
	hud.draw_circle(Vector2.ZERO, 7.0 * draw_scale, Color(0.86, 0.88, 0.82, 1.0))
	hud.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _paint_reload_progress(hud) -> void:
	if not hud._is_reload_visible():
		return
	var center: Vector2 = hud._crosshair_center()
	var progress := clampf(float(hud.reload_state.get("progress", 0.0)), 0.0, 1.0)
	var bar_rect := Rect2(center - Vector2(hud.reload_bar_size.x * 0.5, 0.0) + hud.reload_bar_offset, hud.reload_bar_size)
	var fill_rect := bar_rect.grow(-3.0)
	fill_rect.size.x *= progress
	hud.draw_style_box(hud.reload_background_style, bar_rect)
	hud.draw_style_box(hud.reload_fill_style, fill_rect)
	var label := "%s %.0f%%" % [hud._hud_text(&"ui.raid_hud.reloading", "裝填中"), progress * 100.0]
	var font := ThemeDB.fallback_font
	var font_size := 16
	var label_position: Vector2 = center + hud.reload_label_offset - Vector2(hud.reload_bar_size.x * 0.5, 0.0)
	hud.draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_CENTER, hud.reload_bar_size.x, font_size, Color(0.96, 0.98, 0.9, 0.98))


static func _paint_item_use_progress(hud) -> void:
	if not hud._is_item_use_visible():
		return
	var center: Vector2 = hud._crosshair_center()
	var progress := clampf(float(hud.item_use_state.get("progress", 0.0)), 0.0, 1.0)
	var bar_rect := Rect2(center - Vector2(hud.reload_bar_size.x * 0.5, 0.0) + hud.reload_bar_offset + Vector2(0.0, 28.0), hud.reload_bar_size)
	var fill_rect := bar_rect.grow(-3.0)
	fill_rect.size.x *= progress
	hud.draw_style_box(hud.reload_background_style, bar_rect)
	hud.draw_style_box(hud.reload_fill_style, fill_rect)
	var label := "%s %.0f%%" % [hud._item_use_display_text(), progress * 100.0]
	var font := ThemeDB.fallback_font
	var font_size := 16
	var label_position: Vector2 = center + hud.reload_label_offset + Vector2(0.0, 28.0) - Vector2(hud.reload_bar_size.x * 0.5, 0.0)
	hud.draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_CENTER, hud.reload_bar_size.x, font_size, Color(0.96, 0.98, 0.9, 0.98))


static func _paint_melee_slash(hud) -> void:
	if not hud._is_melee_slash_visible():
		return
	var alpha: float = hud._melee_slash_alpha()
	var center: Vector2 = hud._get_player_screen_position(Vector2.ZERO)
	var crosshair: Vector2 = hud._crosshair_center()
	var aim := crosshair - center
	if aim.length() <= 4.0:
		aim = Vector2.RIGHT
	var angle := aim.angle()
	var side := float(hud.melee_slash_direction)
	var radius := 74.0
	var start_angle := angle - side * 1.05
	var end_angle := angle + side * 0.62
	var arc_from := minf(start_angle, end_angle)
	var arc_to := maxf(start_angle, end_angle)
	var outer := Color(0.62, 0.86, 1.0, 0.52 * alpha)
	var core := Color(1.0, 1.0, 0.92, 0.92 * alpha)
	var glow := Color(0.8, 0.96, 1.0, 0.24 * alpha)
	hud.draw_arc(center, radius + 8.0, arc_from, arc_to, 28, glow, 18.0, true)
	hud.draw_arc(center, radius, arc_from, arc_to, 32, outer, 10.0, true)
	hud.draw_arc(center, radius - 8.0, arc_from + 0.08, arc_to - 0.08, 28, core, 4.0, true)
	var tip_angle := end_angle
	var tip := center + Vector2(cos(tip_angle), sin(tip_angle)) * radius
	hud.draw_circle(tip, 5.0, Color(1.0, 1.0, 0.86, 0.62 * alpha))


static func _paint_ammo_panel(hud) -> void:
	var panel_rect := Rect2(Vector2(hud.size.x + hud.ammo_panel_position.x, hud.size.y + hud.ammo_panel_position.y), hud.ammo_panel_size)
	hud.draw_style_box(hud.ammo_panel_style, panel_rect)
	var font := ThemeDB.fallback_font
	hud.draw_string(font, panel_rect.position + Vector2(16.0, 18.0), hud._held_weapon_panel_label(), HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 32.0, 14, Color(0.76, 0.82, 0.78, 0.95))
	hud.draw_string(font, panel_rect.position + Vector2(16.0, 38.0), hud._ammo_display_text(), HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 32.0, 22, Color(1.0, 1.0, 1.0, 0.98))


static func _paint_quick_bar(hud) -> void:
	var slots: Array = hud._quick_bar_slots()
	if slots.is_empty():
		return
	var rects: Array[Rect2] = PlayerQuickBarLayoutScript.slot_rects(hud.size, slots)
	var slot_count: int = mini(slots.size(), rects.size())
	for index in range(slot_count):
		if typeof(slots[index]) != TYPE_DICTIONARY:
			continue
		var state: Dictionary = slots[index]
		_paint_quick_slot(hud, rects[index], state)


static func _paint_quick_slot(hud, rect: Rect2, state: Dictionary) -> void:
	var active := bool(state.get("active", false))
	var assigned := bool(state.get("assigned", false))
	var key_label := str(state.get("key_label", ""))
	var fill := Color(0.12, 0.13, 0.13, 0.62) if assigned else Color(0.18, 0.18, 0.17, 0.42)
	var border := Color(0.92, 0.98, 1.0, 0.88) if active else Color(1.0, 1.0, 1.0, 0.18)
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 3 if active else 1
	style.border_width_top = 3 if active else 1
	style.border_width_right = 3 if active else 1
	style.border_width_bottom = 3 if active else 1
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	hud.draw_style_box(style, rect)
	_paint_quick_slot_glyph(hud, rect, state)
	_paint_quick_key_badge(hud, rect, key_label)


static func _paint_quick_slot_glyph(hud, rect: Rect2, state: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var display_text := str(state.get("display_text", ""))
	var kind := str(state.get("kind", ""))
	if display_text != "":
		var label := display_text
		if label.length() > 8:
			label = label.left(8)
		hud.draw_string(font, rect.position + Vector2(7.0, 26.0), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 14.0, 14, Color(0.95, 0.98, 0.94, 0.96))
	if kind == "weapon":
		var center := rect.get_center()
		if str(state.get("weapon_slot_id", "")) == "melee":
			hud.draw_line(center + Vector2(-12.0, 16.0), center + Vector2(16.0, -16.0), Color(0.86, 0.94, 0.92, 0.72), 5.0, true)
			hud.draw_line(center + Vector2(-17.0, 20.0), center + Vector2(-7.0, 10.0), Color(0.2, 0.24, 0.22, 0.78), 7.0, true)
		else:
			hud.draw_line(center + Vector2(-20.0, 8.0), center + Vector2(20.0, 8.0), Color(0.82, 0.86, 0.8, 0.72), 5.0, true)
			hud.draw_line(center + Vector2(-7.0, 8.0), center + Vector2(-15.0, 22.0), Color(0.82, 0.86, 0.8, 0.68), 5.0, true)
	elif bool(state.get("assigned", false)):
		hud.draw_circle(rect.get_center() + Vector2(0.0, 10.0), 12.0, Color(0.62, 0.86, 0.98, 0.55))


static func _paint_quick_key_badge(hud, rect: Rect2, key_label: String) -> void:
	var badge_size := Vector2(34.0, 25.0)
	var badge_rect := Rect2(Vector2(rect.get_center().x - badge_size.x * 0.5, rect.end.y + 8.0), badge_size)
	var badge := StyleBoxFlat.new()
	badge.bg_color = Color(0.96, 0.96, 0.93, 0.92)
	badge.border_color = Color(0.2, 0.2, 0.2, 0.18)
	badge.border_width_left = 1
	badge.border_width_top = 1
	badge.border_width_right = 1
	badge.border_width_bottom = 1
	badge.corner_radius_top_left = 5
	badge.corner_radius_top_right = 5
	badge.corner_radius_bottom_left = 5
	badge.corner_radius_bottom_right = 5
	hud.draw_style_box(badge, badge_rect)
	var font := ThemeDB.fallback_font
	hud.draw_string(font, badge_rect.position + Vector2(0.0, 18.0), key_label, HORIZONTAL_ALIGNMENT_CENTER, badge_rect.size.x, 18, Color(0.12, 0.12, 0.12, 0.95))


static func _paint_crosshair(hud) -> void:
	var center: Vector2 = hud._crosshair_center()
	var shadow := Color(0.12, 0.12, 0.12, 0.7)
	var gap := 13.0
	var length := 12.0
	var width := 4.0
	_paint_crosshair_line(hud, center + Vector2(-gap - length, 0.0), center + Vector2(-gap, 0.0), shadow, width + 2.0)
	_paint_crosshair_line(hud, center + Vector2(gap, 0.0), center + Vector2(gap + length, 0.0), shadow, width + 2.0)
	_paint_crosshair_line(hud, center + Vector2(0.0, -gap - length), center + Vector2(0.0, -gap), shadow, width + 2.0)
	_paint_crosshair_line(hud, center + Vector2(0.0, gap), center + Vector2(0.0, gap + length), shadow, width + 2.0)
	_paint_crosshair_line(hud, center + Vector2(-gap - length, 0.0), center + Vector2(-gap, 0.0), hud.crosshair_color, width)
	_paint_crosshair_line(hud, center + Vector2(gap, 0.0), center + Vector2(gap + length, 0.0), hud.crosshair_color, width)
	_paint_crosshair_line(hud, center + Vector2(0.0, -gap - length), center + Vector2(0.0, -gap), hud.crosshair_color, width)
	_paint_crosshair_line(hud, center + Vector2(0.0, gap), center + Vector2(0.0, gap + length), hud.crosshair_color, width)


static func _paint_crosshair_line(hud, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	hud.draw_line(from, to, color, width, true)
