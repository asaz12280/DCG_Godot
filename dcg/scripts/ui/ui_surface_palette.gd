class_name UISurfacePalette
extends RefCounted

# Central surface and text color index for drawn UI.
# Adjust these tokens instead of hand-picking panel colors in individual screens.

const TRANSPARENT := Color(0.0, 0.0, 0.0, 0.0)

const TEXT_PRIMARY := Color(0.94, 0.98, 0.97, 1.0)
const TEXT_SECONDARY := Color(0.78, 0.88, 0.86, 0.95)
const TEXT_MUTED := Color(0.62, 0.72, 0.70, 0.78)
const TEXT_DARK := Color(0.08, 0.14, 0.16, 1.0)
const TEXT_DANGER := Color(1.0, 0.48, 0.42, 1.0)

const SHADOW := Color(0.0, 0.0, 0.0, 0.26)
const OVERLAY_SCRIM := Color(0.0, 0.0, 0.0, 0.18)
const PANEL_FILL := Color(0.075, 0.115, 0.125, 0.94)
const PANEL_FILL_STRONG := Color(0.055, 0.085, 0.095, 0.98)
const PANEL_BORDER := Color(0.48, 0.68, 0.70, 0.36)
const PANEL_HIGHLIGHT := Color(0.78, 0.94, 0.91, 0.16)
const HEADER_FILL := Color(0.12, 0.18, 0.19, 0.88)
const SECTION_FILL := Color(0.10, 0.16, 0.165, 0.88)
const ROW_FILL := Color(0.105, 0.18, 0.18, 0.66)
const ROW_FILL_ALT := Color(0.085, 0.145, 0.15, 0.62)

const SLOT_FILL := Color(0.08, 0.145, 0.16, 0.88)
const SLOT_FILL_ALT := Color(0.10, 0.17, 0.165, 0.88)
const SLOT_FILL_DISABLED := Color(0.12, 0.13, 0.125, 0.72)
const SLOT_BORDER := Color(0.46, 0.64, 0.66, 0.50)
const SLOT_BORDER_SOFT := Color(0.42, 0.58, 0.60, 0.36)
const ITEM_LABEL_FILL := Color(0.13, 0.24, 0.235, 0.78)

const BUTTON_FILL := Color(0.18, 0.46, 0.57, 0.94)
const BUTTON_FILL_HOVER := Color(0.22, 0.54, 0.66, 0.96)
const BUTTON_FILL_DISABLED := Color(0.19, 0.22, 0.22, 0.76)
const BUTTON_BORDER := Color(0.54, 0.82, 0.88, 0.50)
const BUTTON_TEXT := TEXT_PRIMARY

const SUCCESS_FILL := Color(0.20, 0.50, 0.40, 0.94)
const WARNING_FILL := Color(0.78, 0.48, 0.22, 0.94)
const DANGER_FILL := Color(0.72, 0.22, 0.27, 0.94)
const NEUTRAL_FILL := Color(0.24, 0.30, 0.31, 0.94)

const TOOLTIP_FILL := Color(0.045, 0.075, 0.085, 0.98)
const TOOLTIP_BORDER := Color(0.52, 0.74, 0.76, 0.72)

const BAR_TRACK := Color(0.04, 0.07, 0.075, 0.70)
const BAR_FILL := Color(0.48, 0.76, 0.70, 0.92)
const SCROLL_TRACK := Color(0.0, 0.0, 0.0, 0.24)
const SCROLL_THUMB := Color(0.76, 0.92, 0.90, 0.58)

const ICON_MUTED := Color(0.78, 0.86, 0.82, 0.48)
const SELECTED_MODULATE := Color(0.84, 1.0, 0.96, 1.0)
const BADGE_LOCK_FILL := Color(0.84, 0.62, 0.26, 0.95)
const BADGE_LOCK_BORDER := Color(0.18, 0.10, 0.02, 0.75)
const BADGE_LOCK_TEXT := Color(0.06, 0.04, 0.02, 1.0)
const BADGE_NEEDED_FILL := Color(0.88, 0.30, 0.38, 0.95)
const BADGE_NEEDED_BORDER := Color(0.22, 0.04, 0.07, 0.78)
const BADGE_NEEDED_TEXT := Color(1.0, 0.96, 0.95, 1.0)

const FONT_TITLE := 24
const FONT_PANEL_TITLE := 24
const FONT_MENU_BUTTON := 18
const FONT_SUBTITLE := 20
const FONT_BODY := 18
const FONT_PLACEHOLDER := 18
const FONT_HELP := 18
const FONT_SMALL := 14
const FONT_BADGE := 18
const FONT_HUD_PRIMARY := 18
const FONT_HUD_SECONDARY := 18
const FONT_HUD_TITLE := 20

const LINE_HEIGHT_TIGHT := 20.0
const LINE_HEIGHT_BODY := 24.0
const LINE_HEIGHT_LOOSE := 28.0

const SPACE_XXS := 4
const SPACE_XS := 6
const SPACE_SM := 8
const SPACE_MD := 12
const SPACE_LG := 16
const SPACE_XL := 22
const SPACE_XXL := 28

const PANEL_MARGIN_LEFT := 36
const PANEL_MARGIN_RIGHT := 36
const PANEL_MARGIN_TOP := 30
const PANEL_MARGIN_BOTTOM := 28
const PANEL_CONTENT_GAP := 12
const PANEL_CONTENT_GAP_LOOSE := 14
const TAB_GAP := 8
const ROW_GAP := 10
const ROW_GAP_LOOSE := 22

const BORDER_WIDTH := 1
const BORDER_WIDTH_STRONG := 2
const RADIUS_SM := 6
const RADIUS_MD := 8
const RADIUS_LG := 10
const RADIUS_XL := 12
const RADIUS_PANEL := 10
const RADIUS_TOP_MENU_PANEL := 20
const RADIUS_FLOATING_PANEL := 22

const SIZE_MENU_BUTTON := Vector2(320.0, 58.0)
const SIZE_MENU_OVERLAY_PANEL := Vector2(1180.0, 680.0)
const SIZE_PANEL_BACK_BUTTON := Vector2(220.0, 48.0)
const SIZE_SETTINGS_TAB := Vector2(150.0, 42.0)
const SIZE_SETTING_ROW := Vector2(0.0, 68.0)
const SIZE_SETTING_LABEL := Vector2(190.0, 0.0)
const SIZE_SETTING_CONTROL := Vector2(600.0, 52.0)
const SIZE_SETTINGS_SCROLL := Vector2(0.0, 390.0)
const TOP_MENU_PANEL_WIDTH := 1540.0
const SIZE_TOP_MENU_PANEL := Vector2(TOP_MENU_PANEL_WIDTH, 850.0)
const SIZE_QUEST_PANEL := SIZE_TOP_MENU_PANEL
const SIZE_QUEST_TAB_BUTTON := Vector2(190.0, 54.0)
const SIZE_QUEST_ACTION_BUTTON := Vector2(220.0, 52.0)
const SIZE_QUEST_LEFT_COLUMN := Vector2(430.0, 0.0)
const SIZE_STATUS_PANEL := SIZE_TOP_MENU_PANEL
const SIZE_MAP_PANEL := SIZE_TOP_MENU_PANEL
const SIZE_TOP_BAR_PANEL := Vector2(700.0, 84.0)
const SIZE_TOP_BAR_BUTTON := Vector2(55.0, 55.0)
const TOP_BAR_BUTTON_GAP := 24.0
const TOP_MENU_PANEL_TOP_MARGIN := 132.0
const TOP_MENU_PANEL_MIN_SCALE := 0.58
const TOP_MENU_PANEL_MAX_VIEWPORT_HEIGHT_RATIO := 0.715
const TOP_MENU_TITLE_ORIGIN := Vector2(PANEL_MARGIN_LEFT, PANEL_MARGIN_TOP)
const TOP_MENU_HEADER_OFFSET := Vector2(PANEL_MARGIN_LEFT - SPACE_LG, PANEL_MARGIN_TOP - SPACE_MD)
const TOP_MENU_HEADER_HEIGHT := 42.0
const QUICK_SLOT_SIZE := Vector2(74.0, 74.0)
const QUICK_SLOT_COMPACT_SIZE := Vector2(58.0, 58.0)
const QUICK_SLOT_GAP := 16.0
const QUICK_SLOT_BOTTOM_OFFSET := 88.0
const SIZE_CONTAINER_PANEL := Vector2(480.0, 250.0)
const CONTAINER_SLOT_SIZE := Vector2(96.0, 74.0)
const CONTAINER_GRID_COLUMNS := 4
const HUD_HEALTH_PANEL_SIZE := Vector2(250.0, 44.0)
const HUD_AMMO_PANEL_SIZE := Vector2(210.0, 46.0)

const HUD_HEALTH_FILL := Color(0.86, 0.24, 0.25, 0.96)
const HUD_STAMINA_FILL := Color(0.48, 0.76, 0.70, 0.96)
const HUD_WARNING_OVERLAY := Color(1.0, 0.12, 0.08, 0.16)
const HUD_WARNING_BORDER := Color(1.0, 0.20, 0.16, 0.55)
const HUD_ACTION_FILL := Color(0.48, 0.76, 0.70, 0.96)
const HUD_ICON_FILL := Color(0.10, 0.17, 0.18, 0.98)
const HUD_EFFECT_PRIMARY := Color(0.62, 0.86, 1.0, 0.52)
const HUD_EFFECT_CORE := Color(1.0, 1.0, 0.92, 0.92)
const HUD_EFFECT_GLOW := Color(0.8, 0.96, 1.0, 0.24)
const TOP_BAR_SELECTED_FILL := Color(0.18, 0.46, 0.57, 0.95)
const TOP_BAR_SELECTED_GLOW := Color(0.48, 0.76, 0.70, 0.24)
const TOP_BAR_ICON_SHADOW := Color(0.48, 0.76, 0.70, 0.26)


static func panel_fill(strong: bool = false) -> Color:
	return PANEL_FILL_STRONG if strong else PANEL_FILL


static func panel_border() -> Color:
	return PANEL_BORDER


static func panel_highlight() -> Color:
	return PANEL_HIGHLIGHT


static func shadow() -> Color:
	return SHADOW


static func overlay_scrim() -> Color:
	return OVERLAY_SCRIM


static func header_fill() -> Color:
	return HEADER_FILL


static func section_fill() -> Color:
	return SECTION_FILL


static func row_fill(index: int = 0) -> Color:
	return ROW_FILL if index % 2 == 0 else ROW_FILL_ALT


static func slot_fill(variant: StringName = &"default") -> Color:
	match variant:
		&"equipment":
			return SLOT_FILL_ALT
		&"mod":
			return ITEM_LABEL_FILL
		&"backpack":
			return SLOT_FILL
		&"alt", &"safe":
			return SLOT_FILL_ALT
		&"disabled":
			return SLOT_FILL_DISABLED
		_:
			return SLOT_FILL


static func slot_border(soft: bool = false) -> Color:
	return SLOT_BORDER_SOFT if soft else SLOT_BORDER


static func item_label_fill() -> Color:
	return ITEM_LABEL_FILL


static func button_fill(kind: StringName = &"primary") -> Color:
	match kind:
		&"danger":
			return DANGER_FILL
		&"success", &"use":
			return SUCCESS_FILL
		&"warning", &"split":
			return WARNING_FILL
		&"disabled":
			return BUTTON_FILL_DISABLED
		&"neutral", &"cancel":
			return NEUTRAL_FILL
		&"hover":
			return BUTTON_FILL_HOVER
		_:
			return BUTTON_FILL


static func button_border() -> Color:
	return BUTTON_BORDER


static func button_text(enabled: bool = true) -> Color:
	return BUTTON_TEXT if enabled else TEXT_MUTED


static func font_size(kind: StringName = &"body") -> int:
	match kind:
		&"title":
			return FONT_TITLE
		&"panel_title":
			return FONT_PANEL_TITLE
		&"menu_button":
			return FONT_MENU_BUTTON
		&"subtitle":
			return FONT_SUBTITLE
		&"placeholder":
			return FONT_PLACEHOLDER
		&"help":
			return FONT_HELP
		&"small":
			return FONT_SMALL
		&"badge":
			return FONT_BADGE
		&"hud_title":
			return FONT_HUD_TITLE
		&"hud_secondary":
			return FONT_HUD_SECONDARY
		&"hud":
			return FONT_HUD_PRIMARY
		_:
			return FONT_BODY


static func line_height(kind: StringName = &"body") -> float:
	match kind:
		&"tight":
			return LINE_HEIGHT_TIGHT
		&"loose", &"tooltip":
			return LINE_HEIGHT_LOOSE
		_:
			return LINE_HEIGHT_BODY


static func spacing(kind: StringName = &"md") -> int:
	match kind:
		&"xxs":
			return SPACE_XXS
		&"xs":
			return SPACE_XS
		&"sm", &"tab":
			return SPACE_SM
		&"lg":
			return SPACE_LG
		&"xl":
			return SPACE_XL
		&"xxl":
			return SPACE_XXL
		&"panel":
			return PANEL_CONTENT_GAP
		&"panel_loose":
			return PANEL_CONTENT_GAP_LOOSE
		&"row":
			return ROW_GAP
		&"row_loose":
			return ROW_GAP_LOOSE
		_:
			return SPACE_MD


static func radius(kind: StringName = &"md") -> int:
	match kind:
		&"sm":
			return RADIUS_SM
		&"lg":
			return RADIUS_LG
		&"xl":
			return RADIUS_XL
		&"panel":
			return RADIUS_PANEL
		&"floating":
			return RADIUS_FLOATING_PANEL
		_:
			return RADIUS_MD


static func panel_margin(side: StringName) -> int:
	match side:
		&"left":
			return PANEL_MARGIN_LEFT
		&"right":
			return PANEL_MARGIN_RIGHT
		&"top":
			return PANEL_MARGIN_TOP
		&"bottom":
			return PANEL_MARGIN_BOTTOM
		_:
			return PANEL_CONTENT_GAP


static func tooltip_fill() -> Color:
	return TOOLTIP_FILL


static func tooltip_border() -> Color:
	return TOOLTIP_BORDER


static func codex_slot_fill(selected: bool, hovered: bool) -> Color:
	if selected:
		return Color(0.13, 0.26, 0.28, 0.96)
	if hovered:
		return Color(0.12, 0.23, 0.24, 0.94)
	return Color(0.09, 0.16, 0.18, 0.92)


static func codex_slot_border(selected: bool) -> Color:
	return Color(0.58, 0.88, 0.88, 0.88) if selected else SLOT_BORDER


static func codex_category_color(category_id: String) -> Color:
	match category_id:
		"weapon":
			return Color(0.72, 0.24, 0.20, 0.95)
		"ammo":
			return Color(0.76, 0.62, 0.22, 0.95)
		"armor", "equipment", "intel":
			return Color(0.34, 0.43, 0.56, 0.95)
		"backpack", "food":
			return Color(0.66, 0.46, 0.24, 0.95)
		"attachment":
			return Color(0.38, 0.43, 0.46, 0.95)
		"medical":
			return Color(0.80, 0.20, 0.26, 0.95)
		"consumable", "totem":
			return Color(0.42, 0.74, 0.58, 0.95)
		"key":
			return Color(0.84, 0.72, 0.34, 0.95)
		"crafting":
			return Color(0.52, 0.54, 0.47, 0.95)
		"electronics":
			return Color(0.18, 0.58, 0.66, 0.95)
		"explosive":
			return Color(0.78, 0.32, 0.12, 0.95)
		"currency", "valuable":
			return Color(0.82, 0.62, 0.18, 0.95)
		"quest":
			return Color(0.58, 0.34, 0.76, 0.95)
		"recipe":
			return Color(0.58, 0.48, 0.78, 0.95)
		"loot":
			return Color(0.30, 0.52, 0.64, 0.95)
		_:
			return Color(0.48, 0.48, 0.52, 0.95)


static func drag_slot_fill(kind: StringName = &"default") -> Color:
	match kind:
		&"equipment":
			return Color(0.14, 0.22, 0.34, 0.82)
		&"mod":
			return Color(0.28, 0.24, 0.17, 0.82)
		_:
			return Color(0.13, 0.26, 0.24, 0.82)


static func drag_slot_border(kind: StringName = &"default") -> Color:
	match kind:
		&"equipment":
			return Color(0.62, 0.72, 0.92, 0.74)
		&"mod":
			return Color(0.86, 0.76, 0.54, 0.78)
		_:
			return Color(0.64, 0.84, 0.78, 0.72)
