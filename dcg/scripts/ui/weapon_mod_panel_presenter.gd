extends RefCounted

const CentralOverlayPanelStyleScript := preload("res://scripts/ui/central_overlay_panel_style.gd")
const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")
const DETAIL_ROW_HEIGHT := CentralOverlayPanelStyleScript.INSPECTION_ROW_HEIGHT
const DETAIL_TEXT_BASELINE := CentralOverlayPanelStyleScript.INSPECTION_ROW_TEXT_BASELINE

var weapon_slot: StringName = &""
var state: Dictionary = {}
var detail_scroll_row: int = 0


func is_open() -> bool:
	return weapon_slot != &"" and not state.is_empty()


func open(slot_id: StringName, next_state: Dictionary) -> bool:
	if not bool(next_state.get("has_weapon", false)):
		return false
	weapon_slot = slot_id
	state = next_state.duplicate(true)
	detail_scroll_row = 0
	return true


func close() -> void:
	weapon_slot = &""
	state = {}


func refresh(next_state: Dictionary) -> void:
	if not bool(next_state.get("has_weapon", false)):
		close()
		return
	state = next_state.duplicate(true)


func panel_rect(ui_scale: float, viewport_size: Vector2) -> Rect2:
	return CentralOverlayPanelStyleScript.weapon_mod_panel_rect(ui_scale, viewport_size)


func slot_rect(panel_rect_value: Rect2, index: int, ui_scale: float) -> Rect2:
	var rows: Array = state.get("slots", []) as Array
	var slot_width := minf(94.0 * ui_scale, (panel_rect_value.size.x - 28.0 * ui_scale - float(maxi(rows.size() - 1, 0)) * 8.0 * ui_scale) / maxf(float(maxi(rows.size(), 1)), 1.0))
	var slot_size := Vector2(slot_width, 94.0 * ui_scale)
	return Rect2(panel_rect_value.position + _v(14.0, 78.0, ui_scale) + Vector2(float(index) * (slot_width + 8.0 * ui_scale), 0.0), slot_size)


func visible_text(owner: Object) -> String:
	if not is_open():
		return ""
	var parts: Array[String] = []
	var weapon_stack: Dictionary = state.get("weapon_stack", {}) as Dictionary
	parts.append(_stack_name(owner, weapon_stack))
	var catalog_number := int(state.get("catalog_number", 0))
	if catalog_number > 0:
		parts.append("#%d" % catalog_number)
	var details_title := _text(owner, &"ui.weapon_mod.details_title", "")
	parts.append(_text(owner, &"ui.weapon_mod.summary_title", "Weapon Info"))
	var description := _description(owner)
	if description != "":
		parts.append(description)
	parts.append_array(_summary_lines(owner))
	if details_title != "":
		parts.append(details_title)
	for row in state.get("slots", []) as Array:
		var row_dict := row as Dictionary
		var label := _text(owner, StringName(str(row_dict.get("label_key", ""))), str(row_dict.get("slot_id", "")))
		if label != "":
			parts.append(label)
		var stack: Dictionary = row_dict.get("stack", {}) as Dictionary
		if stack.is_empty():
			continue
		else:
			parts.append("%s %s" % [installed_text(owner, stack), effect_summary(owner, stack)])
	for row in _stat_rows() as Array:
		var row_dict := row as Dictionary
		var label := _text(owner, StringName(str(row_dict.get("label_key", ""))), "")
		if label != "":
			parts.append("%s %s" % [label, str(row_dict.get("value", ""))])
	return " ".join(parts)


func draw(owner: Object, painter: RefCounted, ui_scale: float, viewport_size: Vector2) -> void:
	if not is_open():
		return
	var rect := panel_rect(ui_scale, viewport_size)
	painter.panel_shadow(rect)
	painter.panel(rect, CentralOverlayPanelStyleScript.weapon_mod_shell_fill(), CentralOverlayPanelStyleScript.shell_border(), 1, 22)
	painter.panel_highlight(rect)
	var header_rect := Rect2(rect.position + _v(12.0, 12.0, ui_scale), Vector2(rect.size.x - 24.0 * ui_scale, CentralOverlayPanelStyleScript.INSPECTION_HEADER_HEIGHT * ui_scale))
	painter.panel(header_rect, CentralOverlayPanelStyleScript.header_fill(), Color.TRANSPARENT, 0, 8)
	var weapon_stack: Dictionary = state.get("weapon_stack", {}) as Dictionary
	var title := _stack_name(owner, weapon_stack)
	var catalog_number := int(state.get("catalog_number", 0))
	painter.text(title, header_rect.position + _v(12.0, CentralOverlayPanelStyleScript.INSPECTION_TITLE_BASELINE, ui_scale), CentralOverlayPanelStyleScript.INSPECTION_TITLE_FONT_SIZE, CentralOverlayPanelStyleScript.text_primary(), HORIZONTAL_ALIGNMENT_LEFT, header_rect.size.x - 108.0 * ui_scale)
	if catalog_number > 0:
		painter.text("#%d" % catalog_number, header_rect.position + _v(12.0, CentralOverlayPanelStyleScript.INSPECTION_CATALOG_BASELINE, ui_scale), CentralOverlayPanelStyleScript.INSPECTION_CATALOG_FONT_SIZE, CentralOverlayPanelStyleScript.text_muted(), HORIZONTAL_ALIGNMENT_RIGHT, header_rect.size.x - 24.0 * ui_scale)
	var rows: Array = state.get("slots", []) as Array
	for index in range(rows.size()):
		var row: Dictionary = rows[index] as Dictionary
		var slot_rect_value := slot_rect(rect, index, ui_scale)
		painter.slot(slot_rect_value, UISurfacePaletteScript.slot_fill(&"mod"), UISurfacePaletteScript.slot_border())
		var slot_label := _text(owner, StringName(str(row.get("label_key", ""))), str(row.get("slot_id", "")))
		painter.text(slot_label, slot_rect_value.position + _v(2.0, 112.0, ui_scale), 16, UISurfacePaletteScript.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER, slot_rect_value.size.x - 4.0 * ui_scale)
		var stack: Dictionary = row.get("stack", {}) as Dictionary
		if not stack.is_empty():
			owner.call("_paint_item_label", slot_rect_value.grow(-2.0 * ui_scale), stack)
			painter.text(installed_text(owner, stack), slot_rect_value.position + _v(4.0, 68.0, ui_scale), 18, UISurfacePaletteScript.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER, slot_rect_value.size.x - 8.0 * ui_scale)
			painter.text(effect_summary(owner, stack), slot_rect_value.position + _v(4.0, 84.0, ui_scale), 18, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER, slot_rect_value.size.x - 8.0 * ui_scale)
	_draw_detail_panel(owner, painter, rect, ui_scale)


func hit_slot(screen_position: Vector2, ui_scale: float, viewport_size: Vector2) -> Dictionary:
	if not is_open():
		return {"handled": false, "slot_id": &""}
	var rect := panel_rect(ui_scale, viewport_size)
	if not rect.has_point(screen_position):
		return {"handled": false, "slot_id": &""}
	var rows: Array = state.get("slots", []) as Array
	for index in range(rows.size()):
		if not slot_rect(rect, index, ui_scale).has_point(screen_position):
			continue
		var row: Dictionary = rows[index] as Dictionary
		return {"handled": true, "slot_id": StringName(str(row.get("slot_id", "")))}
	return {"handled": true, "slot_id": &""}


func scroll_details(amount: int, ui_scale: float, viewport_size: Vector2) -> bool:
	if not is_open():
		return false
	var rect := panel_rect(ui_scale, viewport_size)
	var max_scroll := _detail_max_scroll(rect, ui_scale)
	var previous := detail_scroll_row
	detail_scroll_row = clampi(detail_scroll_row + amount, 0, max_scroll)
	return detail_scroll_row != previous


func has_point(screen_position: Vector2, ui_scale: float, viewport_size: Vector2) -> bool:
	return is_open() and panel_rect(ui_scale, viewport_size).has_point(screen_position)


func installed_text(owner: Object, stack: Dictionary) -> String:
	return _text(owner, &"ui.weapon_mod.installed_format", "Installed: %s") % _stack_name(owner, stack)


func effect_summary(owner: Object, stack: Dictionary) -> String:
	var parts: Array[String] = []
	var magazine_bonus := int(stack.get("attachment_magazine_capacity_bonus", 0))
	if magazine_bonus > 0:
		parts.append(_text(owner, &"ui.item.attachment_magazine_bonus_format", "Magazine +%d") % magazine_bonus)
	var vertical_recoil := float(stack.get("attachment_vertical_recoil_multiplier", 1.0))
	var horizontal_recoil := float(stack.get("attachment_horizontal_recoil_multiplier", 1.0))
	if not is_equal_approx(vertical_recoil, 1.0) or not is_equal_approx(horizontal_recoil, 1.0):
		parts.append(_text(owner, &"ui.item.attachment_recoil_multiplier_format", "Recoil V%.2fx / H%.2fx") % [vertical_recoil, horizontal_recoil])
	var recovery := float(stack.get("attachment_recoil_recovery_multiplier", 1.0))
	if not is_equal_approx(recovery, 1.0):
		parts.append(_text(owner, &"ui.item.attachment_recoil_recovery_format", "Recoil recovery %.2fx") % recovery)
	var spread := float(stack.get("attachment_spread_multiplier", 1.0))
	if not is_equal_approx(spread, 1.0):
		parts.append(_text(owner, &"ui.item.attachment_spread_multiplier_format", "Spread %.2fx") % spread)
	return " / ".join(parts)


func _summary_lines(owner: Object) -> Array[String]:
	var summary: Dictionary = state.get("summary", {}) as Dictionary
	var type_name := _text(owner, StringName(str(summary.get("type_key", ""))), "")
	var lines: Array[String] = [
		_text(owner, &"ui.weapon_mod.summary_type", "Type: %s") % type_name,
		_text(owner, &"ui.weapon_mod.summary_weight", "Weight %.2f kg") % float(summary.get("weight", 0.0)),
	]
	if bool(summary.get("uses_ammo", false)):
		lines.append(_text(owner, &"ui.weapon_mod.summary_ammo", "Ammo %d/%d") % [int(summary.get("loaded_ammo", 0)), int(summary.get("magazine_capacity", 0))])
	if bool(summary.get("has_durability", false)):
		lines.append(_text(owner, &"ui.weapon_mod.summary_durability", "Durability %d/%d") % [int(summary.get("current_durability", 0)), int(summary.get("max_durability", 0))])
	return lines


func _draw_detail_panel(owner: Object, painter: RefCounted, rect: Rect2, ui_scale: float) -> void:
	var detail_rect := _detail_rect(rect, ui_scale)
	painter.panel(detail_rect, CentralOverlayPanelStyleScript.body_fill(), CentralOverlayPanelStyleScript.body_border(), 1, 8)
	var items := _detail_items(owner)
	var visible_rows := _visible_detail_rows(detail_rect, ui_scale)
	var max_scroll := maxi(items.size() - visible_rows, 0)
	detail_scroll_row = clampi(detail_scroll_row, 0, max_scroll)
	var row_height := DETAIL_ROW_HEIGHT * ui_scale
	var start_y := detail_rect.position.y + 20.0 * ui_scale
	var value_width := 160.0 * ui_scale
	for local_index in range(mini(visible_rows, items.size() - detail_scroll_row)):
		var row: Dictionary = items[detail_scroll_row + local_index] as Dictionary
		var row_rect := Rect2(Vector2(detail_rect.position.x + 10.0 * ui_scale, start_y + float(local_index) * row_height), Vector2(detail_rect.size.x - 34.0 * ui_scale, row_height - 4.0 * ui_scale))
		var kind := StringName(str(row.get("kind", &"stat")))
		if kind == &"section":
			painter.panel(row_rect, CentralOverlayPanelStyleScript.section_fill(), Color.TRANSPARENT, 0, 4)
			painter.text(str(row.get("text", "")), row_rect.position + _v(10.0, DETAIL_TEXT_BASELINE, ui_scale), CentralOverlayPanelStyleScript.INSPECTION_SECTION_FONT_SIZE, CentralOverlayPanelStyleScript.text_primary(), HORIZONTAL_ALIGNMENT_LEFT, row_rect.size.x - 20.0 * ui_scale)
		elif kind == &"description":
			painter.panel(row_rect, CentralOverlayPanelStyleScript.row_fill(local_index), Color.TRANSPARENT, 0, 4)
			painter.text(str(row.get("text", "")).left(90), row_rect.position + _v(10.0, DETAIL_TEXT_BASELINE, ui_scale), CentralOverlayPanelStyleScript.INSPECTION_BODY_FONT_SIZE, CentralOverlayPanelStyleScript.text_primary(), HORIZONTAL_ALIGNMENT_LEFT, row_rect.size.x - 20.0 * ui_scale)
		elif kind == &"summary":
			painter.panel(row_rect, CentralOverlayPanelStyleScript.row_fill(local_index), Color.TRANSPARENT, 0, 4)
			painter.text(str(row.get("text", "")), row_rect.position + _v(10.0, DETAIL_TEXT_BASELINE, ui_scale), CentralOverlayPanelStyleScript.INSPECTION_BODY_FONT_SIZE, CentralOverlayPanelStyleScript.text_secondary(), HORIZONTAL_ALIGNMENT_LEFT, row_rect.size.x - 20.0 * ui_scale)
		else:
			painter.panel(row_rect, CentralOverlayPanelStyleScript.row_fill(local_index), Color.TRANSPARENT, 0, 4)
			var label := _text(owner, StringName(str(row.get("label_key", ""))), "")
			var value := str(row.get("value", ""))
			painter.text(label, row_rect.position + _v(10.0, DETAIL_TEXT_BASELINE, ui_scale), CentralOverlayPanelStyleScript.INSPECTION_BODY_FONT_SIZE, CentralOverlayPanelStyleScript.text_secondary(), HORIZONTAL_ALIGNMENT_LEFT, row_rect.size.x - value_width - 22.0 * ui_scale)
			painter.text(value, row_rect.position + Vector2(row_rect.size.x - value_width - 10.0 * ui_scale, DETAIL_TEXT_BASELINE * ui_scale), CentralOverlayPanelStyleScript.INSPECTION_BODY_FONT_SIZE, CentralOverlayPanelStyleScript.text_primary(), HORIZONTAL_ALIGNMENT_RIGHT, value_width)
	_draw_detail_scrollbar(painter, detail_rect, items.size(), visible_rows, max_scroll, ui_scale)


func _detail_items(owner: Object) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	items.append({"kind": &"section", "text": _text(owner, &"ui.weapon_mod.summary_title", "Weapon Info")})
	var description := _description(owner)
	if description != "":
		items.append({"kind": &"description", "text": description})
	for line in _summary_lines(owner):
		items.append({"kind": &"summary", "text": line})
	var details_title := _text(owner, &"ui.weapon_mod.details_title", "")
	if details_title != "":
		items.append({"kind": &"section", "text": details_title})
	for row in _stat_rows() as Array:
		items.append(row as Dictionary)
	return items


func _draw_detail_scrollbar(painter: RefCounted, detail_rect: Rect2, row_count: int, visible_rows: int, max_scroll: int, ui_scale: float) -> void:
	var track_rect := Rect2(Vector2(detail_rect.end.x - 13.0 * ui_scale, detail_rect.position.y + 12.0 * ui_scale), Vector2(6.0 * ui_scale, detail_rect.size.y - 24.0 * ui_scale))
	painter.panel(track_rect, UISurfacePaletteScript.SCROLL_TRACK, UISurfacePaletteScript.TRANSPARENT, 0, 3)
	var denominator := maxf(float(row_count), 1.0)
	var thumb_height := clampf(track_rect.size.y * (float(visible_rows) / denominator), 34.0 * ui_scale, track_rect.size.y)
	var scroll_ratio := float(detail_scroll_row) / float(max_scroll) if max_scroll > 0 else 0.0
	var thumb_y := track_rect.position.y + (track_rect.size.y - thumb_height) * scroll_ratio
	painter.panel(Rect2(Vector2(track_rect.position.x, thumb_y), Vector2(track_rect.size.x, thumb_height)), UISurfacePaletteScript.SCROLL_THUMB, UISurfacePaletteScript.TRANSPARENT, 0, 3)


func _detail_rect(rect: Rect2, ui_scale: float) -> Rect2:
	var has_attachment_slots := not (state.get("slots", []) as Array).is_empty()
	var top := 202.0 if has_attachment_slots else 78.0
	return Rect2(rect.position + _v(12.0, top, ui_scale), Vector2(rect.size.x - 24.0 * ui_scale, rect.size.y - (top + 16.0) * ui_scale))


func _visible_detail_rows(detail_rect: Rect2, ui_scale: float) -> int:
	return maxi(floori((detail_rect.size.y - DETAIL_ROW_HEIGHT * ui_scale) / (DETAIL_ROW_HEIGHT * ui_scale)), 1)


func _detail_max_scroll(rect: Rect2, ui_scale: float) -> int:
	return maxi(_detail_item_count() - _visible_detail_rows(_detail_rect(rect, ui_scale), ui_scale), 0)


func _detail_item_count() -> int:
	var rows: Array = _stat_rows()
	var count := rows.size() + 2 + _summary_line_count()
	if _description_key() != &"":
		count += 1
	return count


func _summary_line_count() -> int:
	var summary: Dictionary = state.get("summary", {}) as Dictionary
	var count := 2
	if bool(summary.get("uses_ammo", false)):
		count += 1
	if bool(summary.get("has_durability", false)):
		count += 1
	return count


func _stat_rows() -> Array:
	var rows: Array = []
	for row in state.get("stat_rows", []) as Array:
		var row_dict := row as Dictionary
		if StringName(str(row_dict.get("label_key", ""))) == &"ui.weapon_stat.durability":
			continue
		rows.append(row_dict)
	return rows


func _description(owner: Object) -> String:
	var key := _description_key()
	if str(key) == "":
		return ""
	return _text(owner, key, "")


func _description_key() -> StringName:
	var key := StringName(str(state.get("description_key", "")))
	if str(key) == "":
		var weapon_stack: Dictionary = state.get("weapon_stack", {}) as Dictionary
		key = StringName(str(weapon_stack.get("description_key", "")))
	return key


func _text(owner: Object, key: StringName, fallback: String) -> String:
	return str(owner.call("_localized_text", key, fallback))


func _stack_name(owner: Object, stack: Dictionary) -> String:
	return str(owner.call("_get_stack_display_name", stack))


func _v(x: float, y: float, ui_scale: float) -> Vector2:
	return Vector2(x, y) * ui_scale
