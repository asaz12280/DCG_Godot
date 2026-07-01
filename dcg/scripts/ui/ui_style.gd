class_name UIStyle
extends RefCounted

# Shared UI style tokens for values that are not yet cleanly expressed by the
# global Theme resource, especially generated Control trees and early overlays.

const COLOR_TEXT_PRIMARY := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_TEXT_SUBTITLE := Color(0.78, 0.92, 0.92, 1.0)
const COLOR_TEXT_STATUS := Color(0.90, 0.95, 0.90, 0.74)
const COLOR_TEXT_MUTED := Color(0.90, 0.94, 0.90, 0.60)
const COLOR_TEXT_HELP := Color(0.80, 0.92, 0.92, 0.72)

const COLOR_OVERLAY_PANEL := Color(0.12, 0.16, 0.16, 0.92)
const COLOR_OVERLAY_BORDER := Color(0.70, 0.88, 0.88, 0.20)

const COLOR_MENU_BACKGROUND := Color(0.08, 0.10, 0.10, 1.0)
const COLOR_MENU_ATMOSPHERE := Color(0.50, 0.55, 0.47, 0.32)
const COLOR_MENU_GROUND := Color(0.18, 0.22, 0.20, 0.55)
const COLOR_MENU_GRID_STRONG := Color(0.85, 0.75, 0.54, 0.18)
const COLOR_MENU_GRID_SOFT := Color(0.85, 0.75, 0.54, 0.13)

const FONT_TITLE := 64
const FONT_PANEL_TITLE := 26
const FONT_MENU_BUTTON := 24
const FONT_SUBTITLE := 20
const FONT_BODY := 18
const FONT_PLACEHOLDER := 16
const FONT_HELP := 14

const SPACING_MENU_BUTTONS := 12
const SPACING_PANEL_CONTENT := 12
const SPACING_LOAD_PANEL_CONTENT := 14
const SPACING_TAB_ROW := 8
const SPACING_SETTING_ROWS := 22
const SPACING_SETTING_ROW := 38

const PANEL_MARGIN_LEFT := 36
const PANEL_MARGIN_RIGHT := 36
const PANEL_MARGIN_TOP := 30
const PANEL_MARGIN_BOTTOM := 28

const SIZE_MENU_BUTTON := Vector2(320.0, 58.0)
const SIZE_PANEL_BACK_BUTTON := Vector2(220.0, 48.0)
const SIZE_SETTINGS_TAB := Vector2(150.0, 42.0)
const SIZE_SETTING_ROW := Vector2(0.0, 68.0)
const SIZE_SETTING_LABEL := Vector2(190.0, 0.0)
const SIZE_SETTING_CONTROL := Vector2(600.0, 52.0)
const SIZE_SETTINGS_SCROLL := Vector2(0.0, 390.0)

const OVERLAY_BORDER_WIDTH := 1
const OVERLAY_CORNER_RADIUS := 10


static func apply_panel_margins(container: Container, separation: int = SPACING_PANEL_CONTENT) -> void:
	container.add_theme_constant_override("separation", separation)
	container.add_theme_constant_override("margin_left", PANEL_MARGIN_LEFT)
	container.add_theme_constant_override("margin_right", PANEL_MARGIN_RIGHT)
	container.add_theme_constant_override("margin_top", PANEL_MARGIN_TOP)
	container.add_theme_constant_override("margin_bottom", PANEL_MARGIN_BOTTOM)


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


static func apply_overlay_panel_style(panel: Control) -> void:
	panel.add_theme_stylebox_override("panel", make_overlay_panel_style())
