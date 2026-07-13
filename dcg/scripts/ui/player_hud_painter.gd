class_name PlayerHUDPainter
extends RefCounted

const PlayerQuickBarLayoutScript := preload("res://scripts/ui/player_quick_bar_layout.gd")
const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")

static func setup_styles(hud) -> void:
	hud.health_background_style.bg_color = UISurfacePaletteScript.panel_fill(true)
	hud.health_background_style.set_corner_radius_all(UISurfacePaletteScript.RADIUS_MD)
	hud.health_fill_style.bg_color = UISurfacePaletteScript.HUD_HEALTH_FILL
	hud.health_fill_style.set_corner_radius_all(UISurfacePaletteScript.RADIUS_SM)
	hud.lower_left_panel_style.bg_color = UISurfacePaletteScript.panel_fill()
	hud.lower_left_panel_style.set_corner_radius_all(UISurfacePaletteScript.RADIUS_FLOATING_PANEL)
	hud.lower_left_fill_style.bg_color = UISurfacePaletteScript.HUD_HEALTH_FILL
	hud.lower_left_fill_style.set_corner_radius_all(UISurfacePaletteScript.RADIUS_LG)
	hud.lower_left_icon_style.bg_color = UISurfacePaletteScript.HUD_ICON_FILL
	hud.lower_left_icon_style.set_corner_radius_all(UISurfacePaletteScript.RADIUS_LG)
	hud.reload_background_style.bg_color = UISurfacePaletteScript.BAR_TRACK
	hud.reload_background_style.set_corner_radius_all(UISurfacePaletteScript.RADIUS_SM)
	hud.reload_fill_style.bg_color = UISurfacePaletteScript.HUD_ACTION_FILL
	hud.reload_fill_style.set_corner_radius_all(UISurfacePaletteScript.RADIUS_SM)
	hud.ammo_panel_style.bg_color = UISurfacePaletteScript.panel_fill()
	hud.ammo_panel_style.set_corner_radius_all(UISurfacePaletteScript.RADIUS_LG)


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
	_paint_heart_icon(hud, icon_rect.get_center(), float(UISurfacePaletteScript.SPACE_MD), UISurfacePaletteScript.HUD_HEALTH_FILL)
	var health_text := "%d / %d" % [roundi(current_health), roundi(maximum_health)]
	var font := ThemeDB.fallback_font
	var font_size := UISurfacePaletteScript.FONT_HUD_PRIMARY
	var text_size := font.get_string_size(health_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_position := bar_rect.position + (bar_rect.size - text_size) * 0.5 + Vector2(0.0, text_size.y * 0.72)
	hud.draw_string(font, text_position, health_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UISurfacePaletteScript.TEXT_PRIMARY)


static func _paint_damage_feedback(hud) -> void:
	var alpha: float = hud._damage_feedback_alpha()
	if alpha <= 0.0:
		return
	hud.draw_rect(Rect2(Vector2.ZERO, hud.size), Color(UISurfacePaletteScript.HUD_WARNING_OVERLAY.r, UISurfacePaletteScript.HUD_WARNING_OVERLAY.g, UISurfacePaletteScript.HUD_WARNING_OVERLAY.b, UISurfacePaletteScript.HUD_WARNING_OVERLAY.a * alpha), true)
	hud.draw_rect(Rect2(Vector2.ZERO, hud.size), Color(UISurfacePaletteScript.HUD_WARNING_BORDER.r, UISurfacePaletteScript.HUD_WARNING_BORDER.g, UISurfacePaletteScript.HUD_WARNING_BORDER.b, UISurfacePaletteScript.HUD_WARNING_BORDER.a * alpha), false, float(UISurfacePaletteScript.RADIUS_MD))


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
	hud.draw_circle(Vector2.ZERO, (hud.ring_radius + 8.0) * draw_scale, UISurfacePaletteScript.panel_fill(true))
	hud.draw_arc(Vector2.ZERO, hud.ring_radius * draw_scale, 0.0, TAU, 160, UISurfacePaletteScript.slot_border(), (hud.ring_width + 4.0) * draw_scale, true)
	hud.draw_arc(Vector2.ZERO, hud.ring_radius * draw_scale, -PI * 0.5, -PI * 0.5 + TAU * ratio, 160, UISurfacePaletteScript.HUD_STAMINA_FILL, hud.ring_width * draw_scale, true)
	hud.draw_circle(Vector2.ZERO, 7.0 * draw_scale, UISurfacePaletteScript.TEXT_SECONDARY)
	hud.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _paint_reload_progress(hud) -> void:
	if not hud._is_reload_visible():
		return
	var center: Vector2 = hud._timed_action_screen_position()
	var progress: float = hud._timed_action_progress(hud.reload_state)
	var bar_rect := Rect2(center - Vector2(hud.reload_bar_size.x * 0.5, 0.0), hud.reload_bar_size)
	var fill_rect := bar_rect.grow(-3.0)
	fill_rect.size.x *= progress
	hud.draw_style_box(hud.reload_background_style, bar_rect)
	hud.draw_style_box(hud.reload_fill_style, fill_rect)
	var label := "%s %s" % [hud._hud_text(&"ui.raid_hud.reloading", "Reloading"), hud._timed_action_remaining_text(hud.reload_state)]
	var font := ThemeDB.fallback_font
	var font_size := UISurfacePaletteScript.FONT_HUD_PRIMARY
	var label_position: Vector2 = center + Vector2(0.0, 24.0) - Vector2(hud.reload_bar_size.x * 0.5, 0.0)
	hud.draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_CENTER, hud.reload_bar_size.x, font_size, UISurfacePaletteScript.TEXT_PRIMARY)


static func _paint_item_use_progress(hud) -> void:
	if not hud._is_item_use_visible():
		return
	var center: Vector2 = hud._timed_action_screen_position()
	var progress: float = hud._timed_action_progress(hud.item_use_state)
	var bar_rect := Rect2(center - Vector2(hud.reload_bar_size.x * 0.5, 0.0), hud.reload_bar_size)
	var fill_rect := bar_rect.grow(-3.0)
	fill_rect.size.x *= progress
	hud.draw_style_box(hud.reload_background_style, bar_rect)
	hud.draw_style_box(hud.reload_fill_style, fill_rect)
	var label := "%s %s" % [hud._item_use_display_text(), hud._timed_action_remaining_text(hud.item_use_state)]
	var font := ThemeDB.fallback_font
	var font_size := UISurfacePaletteScript.FONT_HUD_PRIMARY
	var label_position: Vector2 = center + Vector2(0.0, 24.0) - Vector2(hud.reload_bar_size.x * 0.5, 0.0)
	hud.draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_CENTER, hud.reload_bar_size.x, font_size, UISurfacePaletteScript.TEXT_PRIMARY)


static func _paint_ammo_panel(hud) -> void:
	var panel_rect := Rect2(Vector2(hud.size.x + hud.ammo_panel_position.x, hud.size.y + hud.ammo_panel_position.y), hud.ammo_panel_size)
	hud.draw_style_box(hud.ammo_panel_style, panel_rect)
	var font := ThemeDB.fallback_font
	hud.draw_string(font, panel_rect.position + Vector2(16.0, 18.0), hud._held_weapon_panel_label(), HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 32.0, UISurfacePaletteScript.FONT_HUD_TITLE, UISurfacePaletteScript.TEXT_SECONDARY)
	hud.draw_string(font, panel_rect.position + Vector2(16.0, 38.0), hud._ammo_display_text(), HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 32.0, UISurfacePaletteScript.FONT_HUD_SECONDARY, UISurfacePaletteScript.TEXT_PRIMARY)


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
	var fill := UISurfacePaletteScript.slot_fill() if assigned else UISurfacePaletteScript.slot_fill(&"disabled")
	var border := UISurfacePaletteScript.panel_border() if active else UISurfacePaletteScript.slot_border(true)
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	var border_width := UISurfacePaletteScript.BORDER_WIDTH_STRONG if active else UISurfacePaletteScript.BORDER_WIDTH
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(UISurfacePaletteScript.RADIUS_XL)
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
		hud.draw_string(font, rect.position + Vector2(7.0, 26.0), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 14.0, UISurfacePaletteScript.FONT_HUD_PRIMARY, UISurfacePaletteScript.TEXT_PRIMARY)
	if kind == "weapon":
		var center := rect.get_center()
		if str(state.get("weapon_slot_id", "")) == "melee":
			hud.draw_line(center + Vector2(-12.0, 16.0), center + Vector2(16.0, -16.0), UISurfacePaletteScript.TEXT_SECONDARY, 5.0, true)
			hud.draw_line(center + Vector2(-17.0, 20.0), center + Vector2(-7.0, 10.0), UISurfacePaletteScript.panel_fill(true), 7.0, true)
		else:
			hud.draw_line(center + Vector2(-20.0, 8.0), center + Vector2(20.0, 8.0), UISurfacePaletteScript.TEXT_SECONDARY, 5.0, true)
			hud.draw_line(center + Vector2(-7.0, 8.0), center + Vector2(-15.0, 22.0), UISurfacePaletteScript.TEXT_MUTED, 5.0, true)
	elif bool(state.get("assigned", false)):
		hud.draw_circle(rect.get_center() + Vector2(0.0, 10.0), 12.0, UISurfacePaletteScript.TOP_BAR_SELECTED_GLOW)


static func _paint_quick_key_badge(hud, rect: Rect2, key_label: String) -> void:
	var badge_size := Vector2(34.0, 25.0)
	var badge_rect := Rect2(Vector2(rect.get_center().x - badge_size.x * 0.5, rect.position.y - badge_size.y - 8.0), badge_size)
	var badge := StyleBoxFlat.new()
	badge.bg_color = UISurfacePaletteScript.header_fill()
	badge.border_color = UISurfacePaletteScript.slot_border(true)
	badge.set_border_width_all(UISurfacePaletteScript.BORDER_WIDTH)
	badge.set_corner_radius_all(UISurfacePaletteScript.RADIUS_SM)
	hud.draw_style_box(badge, badge_rect)
	var font := ThemeDB.fallback_font
	hud.draw_string(font, badge_rect.position + Vector2(0.0, 18.0), key_label, HORIZONTAL_ALIGNMENT_CENTER, badge_rect.size.x, UISurfacePaletteScript.FONT_BADGE, UISurfacePaletteScript.TEXT_PRIMARY)


static func _paint_crosshair(hud) -> void:
	var center: Vector2 = hud._crosshair_center()
	var shadow := UISurfacePaletteScript.shadow()
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
