extends RefCounted

const ItemStackTooltipPresenterScript := preload("res://scripts/ui/item_stack_tooltip_presenter.gd")
const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")
const TOOLTIP_LINE_HEIGHT := 28.0
const CASH_ITEM_PATH := "res://data/items/currency/cash.tres"


static func build_state(owner: Control, viewport_size: Vector2, models: Dictionary, state: Dictionary, rects: Dictionary, text: Dictionary) -> Dictionary:
	return {
		"visible": owner.visible,
		"is_open": bool(state.get("is_open", false)),
		"backpack_items": (state.get("backpack_items", []) as Array).duplicate(true),
		"safe_pocket_items": (state.get("safe_pocket_items", []) as Array).duplicate(true),
		"equipment_slots": state.get("equipment_slots", {}),
		"equipment_slot_rects": state.get("equipment_slot_rects", {}),
		"equipment_text": str(text.get("equipment_text", "")),
		"weapon_mod_panel": state.get("weapon_mod_panel", {}),
		"weapon_mod_panel_rect": rects.get("weapon_mod_panel_rect", Rect2()),
		"weapon_mod_panel_text": str(text.get("weapon_mod_panel_text", "")),
		"item_detail_panel": state.get("item_detail_panel", {}),
		"item_detail_panel_rect": rects.get("item_detail_panel_rect", Rect2()),
		"item_detail_panel_text": str(text.get("item_detail_panel_text", "")),
		"panel_rect": rects.get("panel_rect", Rect2()),
		"backpack_used": int(models.get("backpack_used", 0)),
		"backpack_slots": int(models.get("backpack_slots", 0)),
		"safe_pocket_used": int(models.get("safe_pocket_used", 0)),
		"safe_pocket_slots": int(models.get("safe_pocket_slots", 0)),
		"money": int(state.get("money", 0)),
		"weight_label": str(text.get("weight_label", "")),
		"weight_text": str(text.get("weight_text", "")),
		"current_weight": float(state.get("current_weight", 0.0)),
		"carry_weight_limit": float(state.get("carry_weight_limit", 0.0)),
		"sort_button_text": str(text.get("sort_button_text", "")),
		"store_all_button_visible": bool(state.get("store_all_button_visible", false)),
		"store_all_button_text": str(text.get("store_all_button_text", "")),
		"store_all_button_rect": rects.get("store_all_button_rect", Rect2()),
		"overlay_scrim_visible": bool(state.get("overlay_scrim_visible", true)),
		"viewport_size": viewport_size,
	}


static func build_owner_state(owner: Control, viewport_size: Vector2, layout: RefCounted, weapon_mod_panel: RefCounted, item_detail_panel: RefCounted, backpack_model: RefCounted, safe_pocket_model: RefCounted) -> Dictionary:
	owner.call("_update_layout_scale", viewport_size)
	var panel_rect: Rect2 = owner.call("_panel_rect")
	var backpack_rect: Rect2 = layout.backpack_rect(panel_rect)
	var store_all_visible := bool(owner.get("_store_all_button_visible"))
	var store_all_rect: Rect2 = owner.call("_store_all_button_rect_for_backpack", backpack_rect) if store_all_visible else Rect2()
	owner.set("_store_all_button_rect", store_all_rect)
	return build_state(
		owner,
		viewport_size,
		{
			"backpack_used": backpack_model.get_used_slots(),
			"backpack_slots": owner.call("_get_backpack_slots"),
			"safe_pocket_used": safe_pocket_model.get_used_slots(),
			"safe_pocket_slots": owner.call("_get_safe_pocket_slots"),
		},
		{
			"is_open": owner.get("is_open"),
			"backpack_items": owner.get("backpack_items"),
			"safe_pocket_items": owner.get("safe_pocket_items"),
			"equipment_slots": owner.call("_get_equipment_slots_state"),
			"equipment_slot_rects": owner.call("_get_equipment_slot_rects_state"),
			"weapon_mod_panel": weapon_mod_panel.state.duplicate(true),
			"item_detail_panel": item_detail_panel.state.duplicate(true),
			"money": owner.get("money"),
			"current_weight": owner.call("_get_current_weight"),
			"carry_weight_limit": owner.call("_get_carry_weight_limit"),
			"store_all_button_visible": store_all_visible,
			"overlay_scrim_visible": owner.get("_overlay_scrim_visible"),
		},
		{
			"panel_rect": panel_rect,
			"weapon_mod_panel_rect": weapon_mod_panel.panel_rect(owner.get("_ui_scale"), owner.get("_layout_viewport_size")) if weapon_mod_panel.is_open() else Rect2(),
			"item_detail_panel_rect": item_detail_panel.panel_rect(owner.get("_ui_scale"), owner.get("_layout_viewport_size")) if item_detail_panel.is_open() else Rect2(),
			"store_all_button_rect": store_all_rect,
		},
		{
			"equipment_text": owner.call("_get_equipment_visible_text"),
			"weapon_mod_panel_text": weapon_mod_panel.visible_text(owner),
			"item_detail_panel_text": item_detail_panel.visible_text(owner),
			"weight_label": owner.call("_weight_label_text"),
			"weight_text": owner.call("_weight_value_text"),
			"sort_button_text": owner.call("_sort_button_text"),
			"store_all_button_text": owner.call("_store_all_button_text"),
		}
	)


static func tooltip_by_path(owner: Control, item_path: String) -> Dictionary:
	var normalized_path := item_path.strip_edges()
	if normalized_path == "" or not ResourceLoader.exists(normalized_path):
		return {}
	var item_def := load(normalized_path) as ItemDef
	if item_def == null:
		return {}
	return ItemStackTooltipPresenterScript.build(owner, item_def.to_stack(1))


static func tooltip_for_stack(owner: Control, stack: Dictionary) -> Dictionary:
	if stack.is_empty():
		return {}
	return ItemStackTooltipPresenterScript.build(owner, stack)


static func draw_tooltip(owner: Control, painter: RefCounted, screen_position: Vector2, stack: Dictionary, ui_scale: float) -> void:
	var tooltip := tooltip_for_stack(owner, stack)
	if tooltip.is_empty():
		return
	var lines: Array = tooltip.get("lines", []) as Array
	var max_lines := mini(lines.size(), 8)
	var width := 340.0 * ui_scale
	var height := (50.0 + float(max_lines) * TOOLTIP_LINE_HEIGHT) * ui_scale
	var viewport_size := owner.get_viewport_rect().size
	var tooltip_position := screen_position + Vector2(18.0, 18.0) * ui_scale
	tooltip_position.x = clampf(tooltip_position.x, 10.0 * ui_scale, viewport_size.x - width - 10.0 * ui_scale)
	tooltip_position.y = clampf(tooltip_position.y, 10.0 * ui_scale, viewport_size.y - height - 10.0 * ui_scale)
	var rect := Rect2(tooltip_position, Vector2(width, height))
	painter.panel(rect, UISurfacePaletteScript.tooltip_fill(), UISurfacePaletteScript.tooltip_border(), 2, 8)
	var title_width := rect.size.x - 24.0 * ui_scale
	painter.text(str(tooltip.get("title", "")), rect.position + Vector2(12.0, 24.0) * ui_scale, 20, UISurfacePaletteScript.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, title_width)
	for index in range(max_lines):
		painter.text(str(lines[index]), rect.position + Vector2(12.0, 52.0 + float(index) * TOOLTIP_LINE_HEIGHT) * ui_scale, 18, UISurfacePaletteScript.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0 * ui_scale)


static func stack_at_position(owner: Control, screen_position: Vector2) -> Dictionary:
	var backpack_items: Array = owner.get("backpack_items") as Array
	var backpack_index := int(owner.call("_get_backpack_stack_index_at", screen_position))
	if backpack_index >= 0 and backpack_index < backpack_items.size():
		return backpack_items[backpack_index] as Dictionary
	var safe_pocket_items: Array = owner.get("safe_pocket_items") as Array
	var safe_pocket_index := int(owner.call("_get_safe_pocket_slot_index_at", screen_position))
	if safe_pocket_index >= 0 and safe_pocket_index < safe_pocket_items.size():
		return safe_pocket_items[safe_pocket_index] as Dictionary
	var equipment_index := int(owner.call("_get_equipment_slot_index_at", screen_position))
	if equipment_index >= 0:
		return owner.call("_get_equipment_stack_at", equipment_index) as Dictionary
	return {}


static func stack_display_name(owner: Control, stack: Dictionary) -> String:
	var key := StringName(str(stack.get("name_key", "")))
	if str(key) != "":
		return localized_text(owner, key, str(stack.get("name", "")))
	var fallback := str(stack.get("name", ""))
	if fallback != "":
		return fallback
	return localized_text(owner, &"item.unknown.name", "")


static func localized_text(owner: Control, key: StringName, fallback: String) -> String:
	var key_text := str(key)
	if key_text == "":
		return fallback
	var translated := owner.tr(key_text)
	return fallback if translated == key_text else translated


static func cash_value(items: Array) -> int:
	var total := 0
	for value in items:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var stack := value as Dictionary
		if stack_item_path(stack) == CASH_ITEM_PATH:
			total += int(stack.get("quantity", 0)) * maxi(int(stack.get("value", 1)), 1)
	return total


static func stack_item_path(stack: Dictionary) -> String:
	var path := str(stack.get("resource_path", ""))
	if path == "":
		path = str(stack.get("item_path", ""))
	return path
