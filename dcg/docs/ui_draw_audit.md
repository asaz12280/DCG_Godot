# UI Draw Audit

Last updated: 2026-06-30

Goal: keep `func _draw()` limited to places where immediate CanvasItem drawing is
still the simplest and most appropriate implementation. Ordinary UI structure
should move toward Controls, Containers, Theme resources, and small components.

## Current Status

| Script | Status | Notes |
| --- | --- | --- |
| `scripts/ui/item_codex_ui.gd` | Managed | Catalog grid is node-based through `ItemCodexSlot`; only backdrop, shell panels, and detail painting remain in `_draw()`. Removed obsolete hand-painted grid and scrollbar code. |
| `scripts/ui/inventory_equipment_ui.gd` | Needs component split | Still paints a full overlay. Best next step is to split panels, slots, sort button, and scrollbar into Controls before removing the callback. |
| `scripts/ui/top_menu_bar.gd` | Acceptable short-term | Draws a small icon strip. Convert to Button/TextureButton components when art assets or reusable icon nodes are available. |
| `scripts/ui/player_hud_3d.gd` | Acceptable short-term | Crosshair, stamina ring, and world-space health indicators are good CanvasItem candidates. Removed duplicate lower-left health panel implementation. |
| `scripts/ui/base_menu_screen.gd` | Acceptable short-term | Paints a decorative menu background. Can become a dedicated Backdrop Control or TextureRect later. |

## Rules

- Reserve the exact name `_draw()` for the Godot callback only.
- Use `_paint_*` for helper methods that issue CanvasItem draw calls.
- Do not add new full-screen UI overlays as one large `_draw()` method.
- Prefer Godot Control nodes for buttons, scrollable grids, labels, tooltips,
  slots, and repeated panels.
- If a `_draw()` remains, keep input hitboxes, layout state, and data loading
  outside the paint helpers where possible.

## Next Recommended Work

1. Convert `InventoryEquipmentUI` into a Control tree:
   `PanelContainer` root, `GridContainer` equipment slots, `GridContainer`
   backpack slots, a real `Button` for sorting, and a `ScrollContainer`.
2. Move `TopMenuBar` buttons to actual `Button` or `TextureButton` nodes while
   keeping custom icon drawing isolated in a small icon component if needed.
3. Move `BaseMenuScreen` background into a dedicated backdrop node or generated
   texture so menu screens only own layout and interactions.
