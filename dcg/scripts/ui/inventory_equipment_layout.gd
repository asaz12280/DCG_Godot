class_name InventoryEquipmentLayout
extends RefCounted

const PANEL_SIZE := Vector2(520.0, 920.0)
const PANEL_POSITION := Vector2(50.0, 50.0)

var ui_scale: float = 1.0


func update_scale(viewport_size: Vector2, inventory_ui_scale: float) -> void:
	var base_scale := minf(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	ui_scale = clampf(base_scale * inventory_ui_scale, 0.55, 1.15)


func panel_rect() -> Rect2:
	return Rect2(v(PANEL_POSITION.x, PANEL_POSITION.y), PANEL_SIZE * ui_scale)


func equipment_rect(panel: Rect2) -> Rect2:
	return Rect2(panel.position + v(24.0, 104.0), v(472.0, 320.0))


func backpack_rect(panel: Rect2) -> Rect2:
	return Rect2(panel.position + v(24.0, 415.0), v(472.0, 340.0))


func weight_rect(panel: Rect2) -> Rect2:
	return Rect2(panel.position + v(24.0, 855.0), v(472.0, 50.0))


func safe_pocket_rect(panel: Rect2, safe_slot_count: int) -> Rect2:
	var safe_height := (68.0 + float(safe_slot_count) * 74.0 + float(maxi(safe_slot_count - 1, 0)) * 12.0) * ui_scale
	return Rect2(Vector2(panel.end.x + 18.0 * ui_scale, panel.position.y + 90.0 * ui_scale), Vector2(168.0 * ui_scale, safe_height))


func money_currency_rect(panel: Rect2) -> Rect2:
	var center_x := panel.position.x + panel.size.x * 0.5
	return Rect2(Vector2(center_x - 44.0 * ui_scale, panel.position.y + 34.0 * ui_scale), Vector2(88.0 * ui_scale, 44.0 * ui_scale))


func can_show_safe_pocket(rect: Rect2, viewport_size: Vector2) -> bool:
	return rect.end.x <= viewport_size.x - 18.0 * ui_scale


func v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * ui_scale
