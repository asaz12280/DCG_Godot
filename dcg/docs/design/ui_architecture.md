# UI Architecture

This project is moving from prototype UI toward maintainable production UI.

## Goals

- Keep player-facing text in `data/localization/game_text.csv`.
- Keep item data in `data/items`.
- Keep shared UI style in `data/ui/game_theme.tres`.
- Keep transitional shared style tokens in `scripts/ui/ui_style.gd` until they can move into the theme or layout helpers cleanly.
- Keep gameplay screen UI state in `scripts/ui/ui_manager.gd`.
- Keep screen-size math in `scripts/ui/ui_layout.gd`.
- Keep reusable UI behavior in component scripts under `scripts/ui/components`.

## Theme Rules

- Global Godot theme: `data/ui/game_theme.tres`.
- Use the theme for normal Godot `Control` nodes such as `Button`, `Label`, `Panel`, `OptionButton`, and scroll bars.
- Per-screen colors are allowed during prototyping, but shared button, panel, scrollbar, and text states should migrate back into the theme.
- Common states to preserve: normal, hover, pressed, selected, disabled, focus.
- Generated Control trees should use `UIStyle` for repeated font sizes, spacing, margins, panel shapes, and overlay colors instead of embedding one-off values in each screen script.
- When a `UIStyle` token maps cleanly to a Godot `Theme` color, constant, font size, or stylebox slot, prefer moving it into `game_theme.tres` and removing the script token.

## Responsive Rules

- Base design resolution: `1920x1080`.
- Shared helper: `UILayout`.
- Use `UILayout.design_scale()` for UI scale.
- Use `UILayout.centered_top_rect()` for top bars.
- Use `UILayout.centered_content_rect()` for large modal panels so ultrawide screens do not over-stretch UI.
- Important target shapes: 16:9, 16:10, 21:9, low resolution windows, Steam Deck-like screens.

## UI State Rules

- `UIManager` owns the currently active gameplay UI panel.
- Top-level menu controls should request an active UI change; they should not directly open or close inventory, codex, or future panels.
- Gameplay panels may own their internal drawing and interaction, but global concerns such as mutual exclusion, Escape/Tab handling, focus, mouse mode, and gameplay input blocking belong to `UIManager`.
- Only one major gameplay UI should be active at a time until a screen explicitly needs layered modal behavior.

## Codex Rules

- Item definitions live in `data/items`.
- Catalog numbering lives on `ItemDef.catalog_number`.
- Grid math lives in `ItemCodexGridModel`.
- Future node-based slots should use `ItemCodexSlot`.
- Current drawn codex UI may remain while gameplay is early, but new behavior such as tooltip, drag, multi-select, filters, and category tabs should be implemented through reusable slot/grid structures.

## Migration Priority

1. Keep current screens working.
2. Move shared numbers and colors into theme/layout helpers.
3. Replace hand-drawn repeated elements with reusable `Control` components.
4. Convert large screens only when the data model and interaction rules are stable.
