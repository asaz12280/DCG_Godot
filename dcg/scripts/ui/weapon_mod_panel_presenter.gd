extends RefCounted

var weapon_slot: StringName = &""
var state: Dictionary = {}
var detail_scroll_row: int = 0


func is_open() -> bool:
	return weapon_slot != &"" and not state.is_empty()


func open(slot_id: StringName, next_state: Dictionary) -> bool:
	var rows: Array = next_state.get("slots", []) as Array
	if not bool(next_state.get("has_weapon", false)) or rows.is_empty():
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
	var panel_size := Vector2(540.0, 520.0) * ui_scale
	var panel_position := Vector2(
		(viewport_size.x - panel_size.x) * 0.5,
		maxf(24.0 * ui_scale, minf(92.0 * ui_scale, (viewport_size.y - panel_size.y) * 0.18))
	)
	return Rect2(panel_position, panel_size)


func slot_rect(panel_rect_value: Rect2, index: int, ui_scale: float) -> Rect2:
	var rows: Array = state.get("slots", []) as Array
	var slot_width := minf(70.0 * ui_scale, (panel_rect_value.size.x - 28.0 * ui_scale - float(maxi(rows.size() - 1, 0)) * 8.0 * ui_scale) / maxf(float(maxi(rows.size(), 1)), 1.0))
	var slot_size := Vector2(slot_width, 98.0 * ui_scale)
	return Rect2(panel_rect_value.position + _v(14.0, 34.0, ui_scale) + Vector2(float(index) * (slot_width + 8.0 * ui_scale), 24.0 * ui_scale), slot_size)


func visible_text(owner: Object) -> String:
	if not is_open():
		return ""
	var parts: Array[String] = []
	var weapon_stack: Dictionary = state.get("weapon_stack", {}) as Dictionary
	parts.append("%s %s" % [_stack_name(owner, weapon_stack), _text(owner, &"ui.weapon_mod.title", "Mods")])
	var details_title := _text(owner, &"ui.weapon_mod.details_title", "")
	if details_title != "":
		parts.append(details_title)
	var description := _description(owner)
	if description != "":
		parts.append(description)
	for row in state.get("slots", []) as Array:
		var row_dict := row as Dictionary
		var stack: Dictionary = row_dict.get("stack", {}) as Dictionary
		if stack.is_empty():
			parts.append("%s %s" % [slot_label(owner, row_dict), _text(owner, &"ui.weapon_mod.empty_slot", "Empty")])
		else:
			parts.append("%s %s %s" % [slot_label(owner, row_dict), installed_text(owner, stack), effect_summary(owner, stack)])
	for row in state.get("stat_rows", []) as Array:
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
	painter.panel(rect, Color(0.05, 0.10, 0.13, 0.94), Color(0.63, 0.76, 0.72, 0.82), 2, 14)
	var weapon_stack: Dictionary = state.get("weapon_stack", {}) as Dictionary
	var title := "%s %s" % [_stack_name(owner, weapon_stack), _text(owner, &"ui.weapon_mod.title", "Mods")]
	painter.text(title, rect.position + _v(14.0, 28.0, ui_scale), 17, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 70.0 * ui_scale)
	painter.text(_text(owner, &"ui.weapon_mod.hint", "Drag a backpack attachment into a matching slot to install it."), rect.position + _v(14.0, 50.0, ui_scale), 11, Color(0.76, 0.88, 0.84, 0.92), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 28.0 * ui_scale)
	var rows: Array = state.get("slots", []) as Array
	for index in range(rows.size()):
		var row: Dictionary = rows[index] as Dictionary
		var slot_rect_value := slot_rect(rect, index, ui_scale)
		painter.slot(slot_rect_value, Color(0.10, 0.17, 0.20, 0.90), Color(0.70, 0.78, 0.76, 0.72))
		painter.text(slot_label(owner, row), slot_rect_value.position + _v(4.0, 14.0, ui_scale), 10, Color(0.72, 0.86, 0.83, 0.92), HORIZONTAL_ALIGNMENT_CENTER, slot_rect_value.size.x - 8.0 * ui_scale)
		var stack: Dictionary = row.get("stack", {}) as Dictionary
		if stack.is_empty():
			painter.text(_text(owner, &"ui.weapon_mod.empty_slot", "Empty"), slot_rect_value.position + _v(4.0, 47.0, ui_scale), 11, Color(0.78, 0.86, 0.83, 0.78), HORIZONTAL_ALIGNMENT_CENTER, slot_rect_value.size.x - 8.0 * ui_scale)
		else:
			owner.call("_paint_item_label", slot_rect_value.grow(-2.0 * ui_scale), stack)
			painter.text(installed_text(owner, stack), slot_rect_value.position + _v(4.0, 74.0, ui_scale), 9, Color(0.86, 0.94, 0.86, 0.88), HORIZONTAL_ALIGNMENT_CENTER, slot_rect_value.size.x - 8.0 * ui_scale)
			painter.text(effect_summary(owner, stack), slot_rect_value.position + _v(4.0, 90.0, ui_scale), 8, Color(0.72, 0.88, 1.0, 0.90), HORIZONTAL_ALIGNMENT_CENTER, slot_rect_value.size.x - 8.0 * ui_scale)
	_draw_detail_panel(owner, painter, rect, ui_scale)
	_draw_close_button(owner, painter, rect, ui_scale)


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


func hit_close(screen_position: Vector2, ui_scale: float, viewport_size: Vector2) -> bool:
	return is_open() and _close_button_rect(panel_rect(ui_scale, viewport_size), ui_scale).has_point(screen_position)


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


func slot_label(owner: Object, row: Dictionary) -> String:
	var base_label := _text(owner, StringName(str(row.get("label_key", ""))), str(row.get("slot_id", "")).capitalize())
	return _text(owner, &"ui.weapon_mod.slot_format", "%s slot") % base_label


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


func _draw_detail_panel(owner: Object, painter: RefCounted, rect: Rect2, ui_scale: float) -> void:
	var detail_rect := _detail_rect(rect, ui_scale)
	painter.panel(detail_rect, Color(0.04, 0.08, 0.10, 0.88), Color(0.44, 0.58, 0.58, 0.72), 1, 8)
	painter.text(_text(owner, &"ui.weapon_mod.details_title", ""), detail_rect.position + _v(12.0, 24.0, ui_scale), 14, Color(0.92, 1.0, 0.96, 0.96), HORIZONTAL_ALIGNMENT_LEFT, detail_rect.size.x - 30.0 * ui_scale)
	var description := _description(owner)
	if description != "":
		painter.text(description.left(90), detail_rect.position + _v(12.0, 46.0, ui_scale), 10, Color(0.72, 0.86, 0.84, 0.90), HORIZONTAL_ALIGNMENT_LEFT, detail_rect.size.x - 34.0 * ui_scale)
	var rows: Array = state.get("stat_rows", []) as Array
	var visible_rows := _visible_detail_rows(detail_rect, ui_scale)
	var max_scroll := maxi(rows.size() - visible_rows, 0)
	detail_scroll_row = clampi(detail_scroll_row, 0, max_scroll)
	var row_height := 23.0 * ui_scale
	var start_y := detail_rect.position.y + 70.0 * ui_scale
	var value_width := 132.0 * ui_scale
	for local_index in range(mini(visible_rows, rows.size() - detail_scroll_row)):
		var row: Dictionary = rows[detail_scroll_row + local_index] as Dictionary
		var row_rect := Rect2(Vector2(detail_rect.position.x + 10.0 * ui_scale, start_y + float(local_index) * row_height), Vector2(detail_rect.size.x - 34.0 * ui_scale, row_height - 3.0 * ui_scale))
		var fill := Color(0.09, 0.15, 0.17, 0.68) if local_index % 2 == 0 else Color(0.07, 0.12, 0.14, 0.58)
		painter.panel(row_rect, fill, Color.TRANSPARENT, 0, 4)
		var label := _text(owner, StringName(str(row.get("label_key", ""))), "")
		var value := str(row.get("value", ""))
		painter.text(label, row_rect.position + _v(8.0, 15.0, ui_scale), 11, Color(0.78, 0.90, 0.88, 0.95), HORIZONTAL_ALIGNMENT_LEFT, row_rect.size.x - value_width - 18.0 * ui_scale)
		painter.text(value, row_rect.position + Vector2(row_rect.size.x - value_width - 8.0 * ui_scale, 15.0 * ui_scale), 11, Color(0.95, 0.98, 0.92, 0.98), HORIZONTAL_ALIGNMENT_RIGHT, value_width)
	_draw_detail_scrollbar(painter, detail_rect, rows.size(), visible_rows, max_scroll, ui_scale)


func _draw_close_button(_owner: Object, painter: RefCounted, rect: Rect2, ui_scale: float) -> void:
	var button_rect := _close_button_rect(rect, ui_scale)
	painter.panel(Rect2(button_rect.position + _v(3.0, 3.0, ui_scale), button_rect.size), Color(0.0, 0.0, 0.0, 0.34), Color.TRANSPARENT, 0, 8)
	painter.panel(button_rect, Color(0.62, 0.17, 0.18, 0.98), Color(1.0, 0.78, 0.76, 0.82), 1, 8)
	painter.text("X", button_rect.position + _v(0.0, 25.0, ui_scale), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, button_rect.size.x)


func _close_button_rect(rect: Rect2, ui_scale: float) -> Rect2:
	return Rect2(Vector2(rect.end.x - 48.0 * ui_scale, rect.position.y + 12.0 * ui_scale), Vector2(34.0, 34.0) * ui_scale)


func _draw_detail_scrollbar(painter: RefCounted, detail_rect: Rect2, row_count: int, visible_rows: int, max_scroll: int, ui_scale: float) -> void:
	var track_rect := Rect2(Vector2(detail_rect.end.x - 13.0 * ui_scale, detail_rect.position.y + 12.0 * ui_scale), Vector2(6.0 * ui_scale, detail_rect.size.y - 24.0 * ui_scale))
	painter.panel(track_rect, Color(1.0, 1.0, 1.0, 0.12), Color.TRANSPARENT, 0, 3)
	var denominator := maxf(float(row_count), 1.0)
	var thumb_height := clampf(track_rect.size.y * (float(visible_rows) / denominator), 34.0 * ui_scale, track_rect.size.y)
	var scroll_ratio := float(detail_scroll_row) / float(max_scroll) if max_scroll > 0 else 0.0
	var thumb_y := track_rect.position.y + (track_rect.size.y - thumb_height) * scroll_ratio
	painter.panel(Rect2(Vector2(track_rect.position.x, thumb_y), Vector2(track_rect.size.x, thumb_height)), Color(0.76, 0.92, 0.90, 0.78), Color.TRANSPARENT, 0, 3)


func _detail_rect(rect: Rect2, ui_scale: float) -> Rect2:
	return Rect2(rect.position + _v(14.0, 172.0, ui_scale), Vector2(rect.size.x - 28.0 * ui_scale, rect.size.y - 188.0 * ui_scale))


func _visible_detail_rows(detail_rect: Rect2, ui_scale: float) -> int:
	return maxi(floori((detail_rect.size.y - 84.0 * ui_scale) / (23.0 * ui_scale)), 1)


func _detail_max_scroll(rect: Rect2, ui_scale: float) -> int:
	var rows: Array = state.get("stat_rows", []) as Array
	return maxi(rows.size() - _visible_detail_rows(_detail_rect(rect, ui_scale), ui_scale), 0)


func _description(owner: Object) -> String:
	var key := StringName(str(state.get("description_key", "")))
	if str(key) == "":
		var weapon_stack: Dictionary = state.get("weapon_stack", {}) as Dictionary
		key = StringName(str(weapon_stack.get("description_key", "")))
	if str(key) == "":
		return ""
	return _text(owner, key, "")


func _text(owner: Object, key: StringName, fallback: String) -> String:
	return str(owner.call("_localized_text", key, fallback))


func _stack_name(owner: Object, stack: Dictionary) -> String:
	return str(owner.call("_get_stack_display_name", stack))


func _v(x: float, y: float, ui_scale: float) -> Vector2:
	return Vector2(x, y) * ui_scale
