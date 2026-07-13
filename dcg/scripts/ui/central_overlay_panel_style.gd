class_name CentralOverlayPanelStyle
extends RefCounted

const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")
const PANEL_SIZE := Vector2(540.0, 520.0)
const WEAPON_MOD_PANEL_SIZE := Vector2(720.0, 630.0)
const INSPECTION_HEADER_HEIGHT := 54.0
const INSPECTION_TITLE_FONT_SIZE := 24
const INSPECTION_TITLE_BASELINE := 33.0
const INSPECTION_CATALOG_FONT_SIZE := 18
const INSPECTION_CATALOG_BASELINE := 31.0
const INSPECTION_META_FONT_SIZE := 18
const INSPECTION_META_BASELINE := 94.0
const INSPECTION_BODY_TOP := 112.0
const INSPECTION_ROW_HEIGHT := 42.0
const INSPECTION_SECTION_FONT_SIZE := 20
const INSPECTION_BODY_FONT_SIZE := 18
const INSPECTION_ROW_TEXT_BASELINE := 28.0


static func panel_rect(ui_scale: float, viewport_size: Vector2) -> Rect2:
	var panel_size := PANEL_SIZE * ui_scale
	return _centered_panel_rect(panel_size, ui_scale, viewport_size)


static func weapon_mod_panel_rect(ui_scale: float, viewport_size: Vector2) -> Rect2:
	return _centered_panel_rect(WEAPON_MOD_PANEL_SIZE * ui_scale, ui_scale, viewport_size)


static func _centered_panel_rect(panel_size: Vector2, ui_scale: float, viewport_size: Vector2) -> Rect2:
	var panel_position := Vector2(
		(viewport_size.x - panel_size.x) * 0.5,
		maxf(300.0 * ui_scale, (viewport_size.y - panel_size.y) * 0.46)
	)
	return Rect2(panel_position, panel_size)


static func shell_fill() -> Color:
	return UISurfacePaletteScript.panel_fill()


static func weapon_mod_shell_fill() -> Color:
	return UISurfacePaletteScript.panel_fill(true)


static func shell_border() -> Color:
	return UISurfacePaletteScript.panel_border()


static func header_fill() -> Color:
	return UISurfacePaletteScript.header_fill()


static func body_fill() -> Color:
	return header_fill()


static func body_border() -> Color:
	return UISurfacePaletteScript.slot_border(true)


static func row_fill(index: int) -> Color:
	return UISurfacePaletteScript.row_fill(index)


static func section_fill() -> Color:
	return UISurfacePaletteScript.section_fill()


static func text_primary() -> Color:
	return UISurfacePaletteScript.TEXT_PRIMARY


static func text_secondary() -> Color:
	return UISurfacePaletteScript.TEXT_SECONDARY


static func text_muted() -> Color:
	return UISurfacePaletteScript.TEXT_MUTED
