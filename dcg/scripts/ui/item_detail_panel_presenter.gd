class_name ItemDetailPanelPresenter
extends RefCounted

const CentralOverlayPanelStyleScript := preload("res://scripts/ui/central_overlay_panel_style.gd")
const ItemInspectionFieldPolicyScript := preload("res://scripts/ui/item_inspection_field_policy.gd")

var state: Dictionary = {}


func is_open() -> bool:
	return not state.is_empty()


func open(next_state: Dictionary) -> bool:
	if next_state.is_empty():
		return false
	state = next_state.duplicate(true)
	return true


func close() -> void:
	state.clear()


func visible_text(owner: Object = null) -> String:
	if not is_open():
		return ""
	var parts: PackedStringArray = []
	parts.append(str(state.get("title", "")))
	var meta := _meta_text()
	if meta != "":
		parts.append(meta)
	var info_lines := _detail_info_lines(int(state.get("catalog_number", 0)))
	parts.append(_section_text(owner, _section_title_key(ItemInspectionFieldPolicyScript.SECTION_INFO), "Item Info"))
	for line in info_lines:
		parts.append(str(line))
	var stat_lines := _detail_stat_lines()
	if not stat_lines.is_empty():
		parts.append(_section_text(owner, _section_title_key(ItemInspectionFieldPolicyScript.SECTION_STATS), "Item Stats"))
		for line in stat_lines:
			parts.append(str(line))
	return "\n".join(parts)


func panel_rect(ui_scale: float, viewport_size: Vector2) -> Rect2:
	return CentralOverlayPanelStyleScript.weapon_mod_panel_rect(ui_scale, viewport_size)


func meta_text_origin(ui_scale: float, viewport_size: Vector2) -> Vector2:
	var rect := panel_rect(ui_scale, viewport_size)
	return rect.position + _v(24.0, CentralOverlayPanelStyleScript.INSPECTION_META_BASELINE, ui_scale)


func draw(owner: Object, painter: RefCounted, ui_scale: float, viewport_size: Vector2) -> void:
	if not is_open():
		return
	var rect := panel_rect(ui_scale, viewport_size)
	painter.panel_shadow(rect)
	painter.panel(rect, CentralOverlayPanelStyleScript.shell_fill(), CentralOverlayPanelStyleScript.shell_border(), 1, 22)
	painter.panel_highlight(rect)
	var header_rect := Rect2(rect.position + _v(12.0, 12.0, ui_scale), Vector2(rect.size.x - 24.0 * ui_scale, CentralOverlayPanelStyleScript.INSPECTION_HEADER_HEIGHT * ui_scale))
	painter.panel(header_rect, CentralOverlayPanelStyleScript.header_fill(), Color.TRANSPARENT, 0, 8)
	var catalog_number := int(state.get("catalog_number", 0))
	if catalog_number > 0:
		painter.text("#%d" % catalog_number, header_rect.position + _v(12.0, CentralOverlayPanelStyleScript.INSPECTION_CATALOG_BASELINE, ui_scale), CentralOverlayPanelStyleScript.INSPECTION_CATALOG_FONT_SIZE, CentralOverlayPanelStyleScript.text_muted(), HORIZONTAL_ALIGNMENT_RIGHT, header_rect.size.x - 24.0 * ui_scale)
	painter.text(str(state.get("title", "")), header_rect.position + _v(12.0, CentralOverlayPanelStyleScript.INSPECTION_TITLE_BASELINE, ui_scale), CentralOverlayPanelStyleScript.INSPECTION_TITLE_FONT_SIZE, CentralOverlayPanelStyleScript.text_primary(), HORIZONTAL_ALIGNMENT_LEFT, header_rect.size.x - 108.0 * ui_scale)
	var meta := _meta_text()
	if meta != "":
		painter.text(meta, meta_text_origin(ui_scale, viewport_size), CentralOverlayPanelStyleScript.INSPECTION_META_FONT_SIZE, CentralOverlayPanelStyleScript.text_secondary(), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48.0 * ui_scale)
	var body_rect := Rect2(rect.position + _v(12.0, CentralOverlayPanelStyleScript.INSPECTION_BODY_TOP, ui_scale), Vector2(rect.size.x - 24.0 * ui_scale, rect.size.y - (CentralOverlayPanelStyleScript.INSPECTION_BODY_TOP + 16.0) * ui_scale))
	painter.panel(body_rect, CentralOverlayPanelStyleScript.body_fill(), CentralOverlayPanelStyleScript.body_border(), 1, 8)
	var rows := _detail_rows(owner, catalog_number)
	var visible_rows := maxi(floori((body_rect.size.y - CentralOverlayPanelStyleScript.INSPECTION_ROW_HEIGHT * ui_scale) / (CentralOverlayPanelStyleScript.INSPECTION_ROW_HEIGHT * ui_scale)), 1)
	var max_rows := mini(rows.size(), visible_rows)
	for index in range(max_rows):
		var row: Dictionary = rows[index] as Dictionary
		var row_rect := Rect2(body_rect.position + _v(10.0, 16.0 + float(index) * CentralOverlayPanelStyleScript.INSPECTION_ROW_HEIGHT, ui_scale), Vector2(body_rect.size.x - 20.0 * ui_scale, (CentralOverlayPanelStyleScript.INSPECTION_ROW_HEIGHT - 4.0) * ui_scale))
		if bool(row.get("is_section", false)):
			painter.panel(row_rect, CentralOverlayPanelStyleScript.section_fill(), Color.TRANSPARENT, 0, 4)
			painter.text(str(row.get("text", "")), row_rect.position + _v(8.0, CentralOverlayPanelStyleScript.INSPECTION_ROW_TEXT_BASELINE, ui_scale), CentralOverlayPanelStyleScript.INSPECTION_SECTION_FONT_SIZE, CentralOverlayPanelStyleScript.text_primary(), HORIZONTAL_ALIGNMENT_LEFT, row_rect.size.x - 16.0 * ui_scale)
		else:
			painter.panel(row_rect, CentralOverlayPanelStyleScript.row_fill(index), Color.TRANSPARENT, 0, 4)
			painter.text(str(row.get("text", "")), row_rect.position + _v(8.0, CentralOverlayPanelStyleScript.INSPECTION_ROW_TEXT_BASELINE, ui_scale), CentralOverlayPanelStyleScript.INSPECTION_BODY_FONT_SIZE, CentralOverlayPanelStyleScript.text_secondary(), HORIZONTAL_ALIGNMENT_LEFT, row_rect.size.x - 16.0 * ui_scale)


func _meta_text() -> String:
	var parts: Array[String] = []
	var type_name := str(state.get("item_type_name", "")).strip_edges()
	if type_name != "":
		parts.append(type_name)
	var weight := float(state.get("total_weight", state.get("weight", 0.0)))
	if weight > 0.0:
		parts.append("%.2f kg" % weight)
	var quantity := int(state.get("quantity", 1))
	var max_stack := int(state.get("max_stack", 1))
	if quantity > 1 or max_stack > 1:
		parts.append("%d / %d" % [quantity, max_stack])
	return "  ".join(parts)


func _display_lines(catalog_number: int) -> Array:
	var lines: Array = (state.get("detail_lines", state.get("lines", [])) as Array).duplicate()
	if catalog_number <= 0:
		return lines
	var result: Array = []
	var duplicate_label := "#%d" % catalog_number
	for line in lines:
		if str(line).strip_edges() == duplicate_label:
			continue
		result.append(line)
	return result


func _detail_info_lines(catalog_number: int) -> Array:
	var lines: Array = (state.get("detail_info_lines", _display_lines(catalog_number)) as Array).duplicate()
	if lines.is_empty():
		return lines
	return lines


func _detail_stat_lines() -> Array:
	return (state.get("detail_stat_lines", []) as Array).duplicate()


func _detail_rows(owner: Object, catalog_number: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [{"is_section": true, "text": _section_text(owner, _section_title_key(ItemInspectionFieldPolicyScript.SECTION_INFO), "Item Info")}]
	for line in _detail_info_lines(catalog_number):
		rows.append({"is_section": false, "text": str(line)})
	var stat_lines := _detail_stat_lines()
	if not stat_lines.is_empty():
		rows.append({"is_section": true, "text": _section_text(owner, _section_title_key(ItemInspectionFieldPolicyScript.SECTION_STATS), "Item Stats")})
		for line in stat_lines:
			rows.append({"is_section": false, "text": str(line)})
	return rows


func _section_title_key(section: StringName) -> StringName:
	return ItemInspectionFieldPolicyScript.section_title_key(str(state.get("item_type", "loot")), section)


func _section_text(owner: Object, key: StringName, fallback: String) -> String:
	if owner != null and owner.has_method("_localized_text"):
		return str(owner.call("_localized_text", key, fallback))
	var translated := TranslationServer.translate(key)
	return fallback if translated == str(key) or translated == "" else translated


func _v(x: float, y: float, ui_scale: float) -> Vector2:
	return Vector2(x, y) * ui_scale
