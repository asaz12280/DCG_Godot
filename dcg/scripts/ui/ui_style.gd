class_name UIStyle
extends RefCounted

# Shared UI style tokens for values that are not yet cleanly expressed by the
# global Theme resource, especially generated Control trees and early overlays.

const UISurfacePaletteScript := preload("res://scripts/ui/ui_surface_palette.gd")

const COLOR_TEXT_PRIMARY := UISurfacePaletteScript.TEXT_PRIMARY
const COLOR_TEXT_SUBTITLE := UISurfacePaletteScript.TEXT_SECONDARY
const COLOR_TEXT_STATUS := UISurfacePaletteScript.TEXT_SECONDARY
const COLOR_TEXT_MUTED := UISurfacePaletteScript.TEXT_MUTED
const COLOR_TEXT_HELP := UISurfacePaletteScript.TEXT_MUTED

const COLOR_OVERLAY_PANEL := UISurfacePaletteScript.PANEL_FILL
const COLOR_OVERLAY_BORDER := UISurfacePaletteScript.PANEL_BORDER
const COLOR_BASE_PHASE_PANEL := UISurfacePaletteScript.PANEL_FILL
const COLOR_BASE_PHASE_BORDER := UISurfacePaletteScript.PANEL_BORDER
const COLOR_TRANSFER_PANEL := UISurfacePaletteScript.PANEL_FILL
const COLOR_TRANSFER_BORDER := UISurfacePaletteScript.PANEL_BORDER

const COLOR_MENU_BACKGROUND := Color(0.08, 0.10, 0.10, 1.0)
const COLOR_MENU_ATMOSPHERE := Color(0.50, 0.55, 0.47, 0.32)
const COLOR_MENU_GROUND := Color(0.18, 0.22, 0.20, 0.55)
const COLOR_MENU_GRID_STRONG := Color(0.85, 0.75, 0.54, 0.18)
const COLOR_MENU_GRID_SOFT := Color(0.85, 0.75, 0.54, 0.13)

const FONT_TITLE := UISurfacePaletteScript.FONT_TITLE
const FONT_PANEL_TITLE := UISurfacePaletteScript.FONT_PANEL_TITLE
const FONT_MENU_BUTTON := UISurfacePaletteScript.FONT_MENU_BUTTON
const FONT_SUBTITLE := UISurfacePaletteScript.FONT_SUBTITLE
const FONT_BODY := UISurfacePaletteScript.FONT_BODY
const FONT_PLACEHOLDER := UISurfacePaletteScript.FONT_PLACEHOLDER
const FONT_HELP := UISurfacePaletteScript.FONT_HELP

const SPACING_MENU_BUTTONS := UISurfacePaletteScript.PANEL_CONTENT_GAP
const SPACING_PANEL_CONTENT := UISurfacePaletteScript.PANEL_CONTENT_GAP
const SPACING_LOAD_PANEL_CONTENT := UISurfacePaletteScript.PANEL_CONTENT_GAP_LOOSE
const SPACING_TAB_ROW := UISurfacePaletteScript.TAB_GAP
const SPACING_ROW := UISurfacePaletteScript.ROW_GAP
const SPACING_SETTING_ROWS := UISurfacePaletteScript.ROW_GAP_LOOSE
const SPACING_SETTING_ROW := 38

const PANEL_MARGIN_LEFT := UISurfacePaletteScript.PANEL_MARGIN_LEFT
const PANEL_MARGIN_RIGHT := UISurfacePaletteScript.PANEL_MARGIN_RIGHT
const PANEL_MARGIN_TOP := UISurfacePaletteScript.PANEL_MARGIN_TOP
const PANEL_MARGIN_BOTTOM := UISurfacePaletteScript.PANEL_MARGIN_BOTTOM

const SIZE_MENU_BUTTON := UISurfacePaletteScript.SIZE_MENU_BUTTON
const SIZE_MENU_OVERLAY_PANEL := UISurfacePaletteScript.SIZE_MENU_OVERLAY_PANEL
const SIZE_PANEL_BACK_BUTTON := UISurfacePaletteScript.SIZE_PANEL_BACK_BUTTON
const SIZE_SETTINGS_TAB := UISurfacePaletteScript.SIZE_SETTINGS_TAB
const SIZE_SETTING_ROW := UISurfacePaletteScript.SIZE_SETTING_ROW
const SIZE_SETTING_LABEL := UISurfacePaletteScript.SIZE_SETTING_LABEL
const SIZE_SETTING_CONTROL := UISurfacePaletteScript.SIZE_SETTING_CONTROL
const SIZE_SETTINGS_SCROLL := UISurfacePaletteScript.SIZE_SETTINGS_SCROLL

const OVERLAY_BORDER_WIDTH := UISurfacePaletteScript.BORDER_WIDTH
const OVERLAY_CORNER_RADIUS := UISurfacePaletteScript.RADIUS_PANEL


static func apply_panel_margins(container: Container, separation: int = SPACING_PANEL_CONTENT) -> void:
	container.add_theme_constant_override("separation", separation)
	container.add_theme_constant_override("margin_left", PANEL_MARGIN_LEFT)
	container.add_theme_constant_override("margin_right", PANEL_MARGIN_RIGHT)
	container.add_theme_constant_override("margin_top", PANEL_MARGIN_TOP)
	container.add_theme_constant_override("margin_bottom", PANEL_MARGIN_BOTTOM)


static func apply_top_menu_panel_margins(container: MarginContainer, scale: float = 1.0) -> void:
	if container == null:
		return
	var safe_scale := maxf(scale, 0.01)
	container.add_theme_constant_override("margin_left", roundi(float(PANEL_MARGIN_LEFT) * safe_scale))
	container.add_theme_constant_override("margin_right", roundi(float(PANEL_MARGIN_RIGHT) * safe_scale))
	container.add_theme_constant_override("margin_top", roundi(float(PANEL_MARGIN_TOP) * safe_scale))
	container.add_theme_constant_override("margin_bottom", roundi(float(PANEL_MARGIN_BOTTOM) * safe_scale))


static func apply_font_size(control: Control, font_size: int) -> void:
	control.add_theme_font_size_override("font_size", font_size)


static func apply_font_color(control: Control, color: Color) -> void:
	control.add_theme_color_override("font_color", color)


static func make_overlay_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_OVERLAY_PANEL
	style.border_color = COLOR_OVERLAY_BORDER
	style.set_border_width_all(OVERLAY_BORDER_WIDTH)
	style.set_corner_radius_all(OVERLAY_CORNER_RADIUS)
	return style


static func make_top_menu_panel_style() -> StyleBoxFlat:
	var style := make_overlay_panel_style()
	style.set_corner_radius_all(UISurfacePaletteScript.RADIUS_TOP_MENU_PANEL)
	return style


static func make_inner_panel_style(strong: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UISurfacePaletteScript.panel_fill(strong)
	style.border_color = UISurfacePaletteScript.slot_border(true)
	style.set_border_width_all(UISurfacePaletteScript.BORDER_WIDTH)
	style.set_corner_radius_all(UISurfacePaletteScript.RADIUS_MD)
	return style


static func make_button_style(kind: StringName = &"primary") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UISurfacePaletteScript.button_fill(kind)
	style.border_color = UISurfacePaletteScript.button_border()
	style.set_border_width_all(UISurfacePaletteScript.BORDER_WIDTH)
	style.set_corner_radius_all(UISurfacePaletteScript.RADIUS_MD)
	return style


static func make_base_phase_panel_style() -> StyleBoxFlat:
	var style := make_overlay_panel_style()
	style.bg_color = COLOR_BASE_PHASE_PANEL
	style.border_color = COLOR_BASE_PHASE_BORDER
	return style


static func make_transfer_panel_style() -> StyleBoxFlat:
	var style := make_overlay_panel_style()
	style.bg_color = COLOR_TRANSFER_PANEL
	style.border_color = COLOR_TRANSFER_BORDER
	return style


static func apply_overlay_panel_style(panel: Control) -> void:
	panel.add_theme_stylebox_override("panel", make_overlay_panel_style())


static func apply_top_menu_panel_style(panel: Control) -> void:
	panel.add_theme_stylebox_override("panel", make_top_menu_panel_style())
