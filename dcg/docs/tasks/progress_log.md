# Progress Log

## 2026-07-01 Automation Baseline Task

### Completed

- Read the automation documents: `docs/design/early_development_plan.md`, `docs/tasks/automation_task_queue.md`, and `docs/design/ui_layout_quality_guide.md`.
- Confirmed the automation queue, project health check rules, and UI layout quality rules are present.
- Completed `任務一：建立自動化基準線` in `docs/tasks/automation_task_queue.md`.
- Cleaned a non-blocking baseline validation issue by guarding `/root` autoload lookups in `difficulty_manager.gd` and `difficulty_select_panel.gd` when nodes are initialized outside the active scene tree during headless validation.

### Verified

- Standard validation set reports `ALL_STANDARD_VALIDATIONS_PASSED`.
- `validate_item_catalog.gd` reports `[item_catalog] OK items=21 max_no=21`.
- `validate_ui_foundation.gd` reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- `validate_inventory_drag_rules.gd` reports `[inventory_drag_rules] OK`.
- `validate_gameplay_architecture.gd` reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- `validate_combat_domain.gd` reports `[combat_domain] OK damageable=works weapon=applies_damage scene=has_target`.
- `validate_difficulty_system.gd` reports `[difficulty_system] OK profiles=3 health=scaled menu=available` without the previous absolute-path errors.
- `validate_save_slots.gd` reports `[save_slots] OK slots=3 save=start load=continue`.
- `validate_save_slot_panel.gd` reports `[save_slot_panel] OK rows=3 refresh=ready`.
- `validate_audio_settings.gd` reports `[audio_settings] OK buses=Master/BGM/SFX`.
- `validate_pause_menu.gd` reports `[pause_menu] OK open_close=true`.
- Main scene and `res://scenes/gameplay/player_test_world_3d.tscn` both load in Godot 4.7 headless mode.

### Next

1. Start `任務二：建立 StashModel`.

## 2026-07-01 Stash Model Task

### Completed

- Completed `任務二：建立 StashModel` in `docs/tasks/automation_task_queue.md`.
- Added `scripts/base/stash_model.gd` as a UI-independent permanent stash model.
- Added support for adding valid `ItemDef` resources, merging stackable items, splitting overflow into multiple stacks, tracking total quantity, removing partial quantities, removing stacks, serializing to save-friendly dictionaries, and loading from save data.
- Added resource existence checks before loading save entries so invalid saved item paths are handled without noisy Godot resource load errors.
- Added `tools/validate_stash_model.gd` for focused stash model validation.

### Verified

- `validate_stash_model.gd` reports `[stash_model] OK add=merge remove=works save=round_trip`.
- `validate_item_catalog.gd` reports `[item_catalog] OK items=21 max_no=21`.
- Main scene loads in Godot 4.7 headless mode after the stash model addition.

### Next

1. Start `任務三：擴充存檔格式為 Save Schema v1`.

## 2026-07-01 Save Schema v1 Task

### Completed

- Completed `任務三：擴充存檔格式為 Save Schema v1` in `docs/tasks/automation_task_queue.md`.
- Expanded `SaveGameManager` slot data to schema version 1.
- Added `version`, `money`, `stash`, `base_upgrades`, and `quests` fields to new save files.
- Added `get_slot_data()` and `save_slot_data()` so future systems can round-trip persistent state without reaching into private file helpers.
- Preserved legacy slot compatibility by normalizing old scene/difficulty/time-only save data to schema v1 defaults.
- Updated `tools/validate_save_slots.gd` to validate schema defaults, money/stash/base-upgrade/quest round-trip, and legacy-slot normalization.

### Verified

- `validate_save_slots.gd` reports `[save_slots] OK slots=3 save=start load=continue schema=v1`.
- `validate_stash_model.gd` reports `[stash_model] OK add=merge remove=works save=round_trip`.
- `validate_save_slot_panel.gd` reports `[save_slot_panel] OK rows=3 refresh=ready`.
- Standard validation set reports `ALL_STANDARD_VALIDATIONS_PASSED`, including item catalog, UI foundation, inventory drag rules, gameplay architecture, combat, difficulty, save slots, save slot panel, stash model, audio settings, pause menu, main scene startup, and gameplay scene startup.

### Project Health Check

- Trigger: completed 任務三, before 任務四.
- Responsibility boundaries: new stash and save logic stay in `scripts/base` and `scripts/save`; no UI node owns persistent gameplay state.
- UI node-first/layout quality: no new player-facing UI was introduced in tasks one through three, so there is no new layout surface to review yet.
- Script size/focus: scan found no scripts over 300 lines in `scripts`; new `stash_model.gd` and expanded `save_game_manager.gd` remain focused.
- Data-driven content: stash serialization uses item resource paths and does not hard-code item behavior into UI.
- Coupling scan: no new dependency from gameplay/domain scripts to `InventoryEquipmentUI`; `UIManager` remains the expected owner of active gameplay UI binding.
- Save safety: schema v1 defaults and legacy normalization are covered by validation.
- Scene health: main scene and gameplay scene both load headless.
- Validation health: new `validate_stash_model.gd` exists, and updated `validate_save_slots.gd` covers schema v1.

### Next

1. Start `任務四：建立最小 Base Screen`.

## 2026-06-30

### Completed

- Added the first main menu scene at `scenes/ui/main_menu.tscn`.
- Added `MainMenu` UI logic for Start Game, Load Save, Settings, and Quit Game.
- Set the project main scene to the new main menu.
- Connected Start Game to the current 3D player test world.
- Added placeholder Load Save and Settings panels so the menu flow has room for future save and options systems.
- Added a fullscreen/windowed screen mode option to the Settings panel.
- Added localized main menu text keys to `data/localization/game_text.csv`.
- Stored dynamic menu panel node references directly so translated text updates do not depend on fragile generated node paths.
- Added `GameSettings` as a shared settings autoload with language, resolution, screen mode, and `user://game_settings.cfg` persistence.
- Expanded the Settings panel into a tabbed settings UI with language, resolution, screen mode, and placeholder audio/video/keybind rows.
- Added localized settings text keys for the new settings tabs, options, display modes, and language names.
- Updated display mode bootstrapping so gameplay scenes respect `GameSettings` instead of overwriting the selected display mode.

### Verified

- Godot launches the new project main scene without recent startup errors.
- Runtime UI check confirms the main menu title, subtitle, status text, and four main buttons display Traditional Chinese from localization.
- Runtime UI check confirms the Load Save panel opens and displays the localized placeholder message.
- Runtime UI check confirms the Settings panel opens at a fixed 960x620 layout without overflowing the screen.
- Runtime UI check confirms the Settings panel shows Traditional Chinese labels for language, resolution, screen mode, and placeholder rows.
- Runtime UI check confirms the default resolution option displays `2560 x 1440` and screen mode displays fullscreen.
- Fixed resolution and screen mode application so selecting the same saved value still reapplies it, resolution updates the root render viewport, fullscreen uses exclusive fullscreen, and windowed mode resizes the OS window.
- Runtime UI check confirms screen mode selection now changes between windowed and fullscreen instead of only updating the dropdown label.
- Refactored the main menu into reusable UI modules: `BaseMenuScreen` for shared menu layout/background/buttons and `SettingsPanel` for shared settings UI and behavior.
- Simplified `MainMenu` so it only owns Start Game, Load Save, Settings, and Quit Game flow decisions.
- Replaced dictionary-based settings option data with parser-safe parallel option arrays after Godot reported a retained parse error around the settings option loop.
- Runtime check confirms the refactored main menu launches, starts with only the four main buttons visible, and can open the reusable settings panel.
- Clarified display-setting behavior so selected resolution is the authoritative render/content-scale resolution, while the OS window size is only a suggested windowed size and may differ after editor/debug constraints or user resizing.
- Runtime checks confirm `resolution` and `render_size` stay synchronized for 2560x1440, 1920x1080, and 1280x720 in windowed mode, and for 2560x1440 in fullscreen mode.
- Added a minimum supported render resolution of 1280x720 so UI is not squeezed below the project support floor.
- Updated main menu responsive layout so overlay panels are right-aligned on large screens and centered on smaller screens.
- Updated the reusable settings panel so its scroll area adapts to panel height, preserving space for tabs, helper text, and the back button.
- Runtime responsive check at 1280x720 confirms `render_matches_resolution == true` and the settings panel fits within the viewport.
- Set 1920x1080 as the standard actual window size target while keeping selected resolution as the authoritative render size.
- Updated the settings resolution order so 1920x1080 is the default/first standard option.
- Runtime checks confirm the standard window target reports 1920x1080 while render size still follows the selected resolution.

### Next

1. Add the first save/load data model and make the Load Save button list actual save slots.
2. Convert the load-save placeholder into a reusable save-slot panel.
3. Connect the placeholder audio settings to actual audio buses.

## 2026-06-29

### Completed

- Added `ItemDef` as the first data-driven item resource model.
- Added `InventoryModel` for slot limits, stack merging, sorting, display data, and total weight.
- Rebuilt `InventoryEquipmentUI` so the backpack panel reads from `InventoryModel` instead of owning only ad hoc UI arrays.
- Added temporary debug starter items: canned corn, scrap metal, duck tape, and broken scope.
- Moved starter items into real `ItemDef` `.tres` resources under `data/items`.
- Connected backpack total weight to the player controller through `set_current_carry_weight()`.
- Cleaned visible inventory equipment labels: weapon, armor, backpack, accessory, safe pocket, sort button, and weight text.
- Fixed strict GDScript warnings in `inventory_equipment_ui.gd` and `display_mode_3d.gd`.
- Added `LootPickup3D`, the first world loot interaction component.
- Added the first world loot pickup scene and placed it in the player test world.
- Added `InventoryEquipmentUI.add_item_resource()` so world systems can add items without owning inventory internals.
- Replaced the static generated top menu strip with a functional `TopMenuBar`.
- Added five selectable top menu buttons: backpack, quests, character status, map, and item encyclopedia.
- Moved Tab inventory toggling ownership from `InventoryEquipmentUI` into `TopMenuBar`.
- Added `# // ... //` explanation comments to the new top menu, inventory model, item definition, pickup interaction, and inventory public API areas.
- Added the first localization planning document at `docs/design/localization_plan.md`.
- Added the first runtime localization slice with `data/localization/game_text.csv`.
- Added `LocalizationBootstrap` to register CSV translations and force the early development locale to `zh_TW`.
- Migrated the inventory panel, equipment labels, item display names, top menu metadata, and pickup prompt to localization keys.
- Cleaned the four starter item resources and added item name/description keys.
- Changed development localization to read `game_text.csv` directly instead of relying on stale imported `.translation` files.
- Added CSV hot reload and localization refresh callbacks for inventory UI, top menu UI, and pickup prompts.
- Cleared remaining player-facing fallback text from item resources, pickup scene labels, and inventory UI fallback strings so `game_text.csv` is the single source of visible text.
- Added the first `ItemCodexUI` implementation and connected it to the top menu codex button.
- The item codex now scans `res://data/items` for all current `ItemDef` resources and displays localized names/descriptions from `game_text.csv`.
- Reworked `ItemCodexUI` into a 10-column catalog grid with 100 fixed numbered slots and a draggable scrollbar.
- Added `ItemDef.catalog_number` so catalog positions are data-driven.
- Replaced the old test item set with a single No.1 `wood` item and removed the previous canned corn, scrap metal, duck tape, and broken scope resources.
- Enlarged the item codex layout into a wide left catalog grid and a separate right-side item detail panel.
- Reduced the top menu button size, icon stroke, spacing, and panel height by roughly 30% to make the HUD less crowded.
- Updated display handling so supported screens enter fullscreen, smaller screens use a fitted window, and stretch aspect uses `expand`.

### Verified

- Godot project launches the main scene and the Godot AI game helper becomes live.
- Pressing Tab shows `InventoryEquipmentUI`.
- Runtime check reports 4 backpack item stacks.
- Runtime check loads item names from current item resources.
- Runtime check reports `backpack_model.get_total_weight() == 4.95`.
- Runtime check reports `Player3D.current_carry_weight == 4.95`.
- No new editor log entries appeared after the clean verification cursor.
- Runtime pickup check starts with `LootPickupScrapMetal` in range of the player.
- Pressing E removes the pickup from the scene.
- Pickup merges scrap metal from quantity 3 to 5.
- Runtime check reports `backpack_model.get_total_weight() == 6.75` after pickup.
- Runtime check reports `Player3D.current_carry_weight == 6.75` after pickup.
- Runtime check confirms the initial top menu selection is backpack and inventory starts closed.
- Runtime check confirms pressing Tab opens the inventory and keeps the backpack icon selected.
- Runtime check confirms pressing Right moves selection from backpack to quests.
- Screenshot check confirms the top HUD is now a functional button row rather than a static image strip.
- Runtime check after comment pass confirms no new editor log entries and the main HUD/inventory nodes still initialize correctly.
- Runtime localization check confirms `ui.inventory.equipment`, `ui.inventory.sort`, `ui.inventory.load`, and `prompt.pickup` resolve to Traditional Chinese.
- Screenshot check confirms the inventory panel and pickup prompt display Traditional Chinese instead of the earlier English labels.
- Runtime localization hot reload check confirms changing `ui.inventory.equipment` in `game_text.csv` updates `tr("ui.inventory.equipment")` without restarting the game.
- Runtime localization source check confirms `internationalization/locale/translations` is empty and UI text still resolves from `game_text.csv` through `LocalizationBootstrap`.
- Runtime codex check confirms the codex opens from the fifth top-menu icon, closes the backpack panel, and lists the four current item resources.
- Screenshot check confirms the codex panel displays localized item names, descriptions, type labels, weight, value, and max stack.
- Runtime codex grid check confirms 10 columns, 100 slots, No.1 wood, and scrollbar dragging to No.100.
- Project-wide search confirms the removed old test item resource ids and names no longer appear.
- Screenshot check confirms the codex now uses the larger left-grid/right-detail layout.
- Runtime check confirms the smaller top menu still opens the codex from the fifth icon and closes the backpack panel.
- Runtime display check confirms the project uses `canvas_items` stretch mode with `expand` aspect and the display mode script runs without errors.

### Next

1. Add a simple language setting UI later, then let it override `LocalizationBootstrap.DEFAULT_LOCALE`.
2. Start the combat slice with a damageable target.
3. Add a pistol controller with raycast shot and ammo.
4. Add a tiny validation test that asserts starter item resources can load and compute weight.

## 2026-06-30

### Completed

- Expanded `ItemDef` with broader Escape-from-Duckov-style item categories and an early gun `damage` stat.
- Updated `ItemCodexUI` so the catalog starts at 100 slots but expands downward automatically when higher numbered items exist.
- Updated the codex detail panel so non-stackable items hide the max-stack row.
- Added gun damage display in the codex when an item has the `gun` tag and a positive damage value.
- Added the first current item catalog from No.1 to No.37 across materials, electronics, consumables, food, medical, weapons, ammo, armor, backpacks, attachments, keys, explosives, valuables, intel, quest items, totems, recipes, and loot.
- Kept the previously removed test objects out of the active catalog: scrap metal, duck tape, canned corn, and broken scope.
- Added localization keys for the new item categories, item names, item descriptions, and the codex damage row.
- Added `tools/validate_item_catalog.gd` for command-line validation of catalog numbering and item data fields.

### Verified

- PowerShell data check confirms 37 item resources, catalog numbers No.1 through No.37, no duplicates, and no missing numbers.
- CSV import check confirms `game_text.csv` parses successfully with 150 rows and no empty required fields.
- Project-wide search confirms the removed test item ids and visible names no longer appear.
- Godot 4.7 headless run succeeds with no startup errors.
- Godot command-line validation reports `[item_catalog] OK items=37 max_no=37`.

### Next

1. Connect the item catalog to future pickup/spawn tables so world loot comes from the same `ItemDef` source.
2. Start the combat slice with a damageable target and a basic pistol.
3. Add a small item filter or category tab to the codex once the catalog grows beyond the first page.

## 2026-06-30 Item Catalog Trim

### Completed

- Removed the red-marked catalog items from active item resources and localization keys.
- Added `bread` as a food item with localized name and description keys.
- Repacked the active catalog into continuous numbers from No.1 to No.14.

### Verified

- Data check confirms 14 item resources, catalog numbers No.1 through No.14, no duplicates, and no missing numbers.
- Search check confirms the removed red-marked item ids and visible names no longer appear in `data` or `scripts`.
- CSV import check confirms `game_text.csv` parses successfully with 104 rows and bread has both name and description keys.
- Godot command-line validation reports `[item_catalog] OK items=14 max_no=14`.

## 2026-06-30 Item Catalog Additions

### Completed

- Added No.15 through No.21: extended magazine, wire, stamina potion, life totem, blueprint, cash, and junk.
- Renamed pistol display text to `手槍-S`.
- Renamed 9mm ammo display text to `彈藥-S`.
- Renamed light armor display text to `一級防彈衣`.
- Added localization keys for all newly added item names and descriptions.

### Verified

- Data check confirms 21 item resources, catalog numbers No.1 through No.21, no duplicates, and no missing numbers.
- CSV import check confirms `game_text.csv` parses successfully with 118 rows and no empty required fields.
- Godot command-line validation reports `[item_catalog] OK items=21 max_no=21`.

## 2026-06-30 Responsive HUD Pass

### Completed

- Updated `TopMenuBar` to compute its runtime position from the current viewport instead of relying on the old 1920px fixed `x = 610` scene offset.
- Added a 1920x1080 design-canvas scale for the top menu with clamped scaling across common 16:9 resolutions.
- Updated the gameplay scene so `TopMenuBar` starts with top-center anchors in the editor as well.

### Verified

- Position math check confirms the top menu center matches the screen center at 1920x1080, 2560x1440, 1600x900, and 1280x720.
- Godot 4.7 headless startup succeeds after the HUD layout change.
- Godot item catalog validation still reports `[item_catalog] OK items=21 max_no=21`.

## 2026-06-30 UI Foundation Pass

### Completed

- Added the shared Godot theme resource at `data/ui/game_theme.tres`.
- Connected the project default custom theme through `project.godot`.
- Added `UILayout` as the shared 1920x1080 design-canvas layout helper for top bars and centered content panels.
- Updated `TopMenuBar` to use `UILayout` instead of local viewport math.
- Added `ItemCodexGridModel` so codex slot count, scroll rows, and slot numbering are no longer hard-coded inside drawing code.
- Updated `ItemCodexUI` to use the shared grid model and centered responsive content rect.
- Added `ItemCodexSlot` as the first reusable codex slot component for future node-based UI migration.
- Added `docs/design/ui_architecture.md` to document theme rules, responsive rules, codex rules, and migration priority.
- Added `tools/validate_ui_foundation.gd` to validate shared theme, layout centering, and codex grid behavior.

### Verified

- Godot 4.7 headless startup succeeds with the custom theme configured.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Item catalog validation still reports `[item_catalog] OK items=21 max_no=21`.

## 2026-06-30 Codex Grid Node Pass

### Completed

- Converted the active item codex grid path from hand-drawn slot hitboxes to real Godot `Control` nodes.
- `ItemCodexUI` now builds a `PanelContainer -> ScrollContainer -> GridContainer -> ItemCodexSlot` hierarchy for catalog slots.
- Mouse wheel scrolling now drives the `ScrollContainer` instead of the old manual scrollbar math.
- Slot clicks now come from `ItemCodexSlot.slot_selected` instead of manual `Rect2.has_point()` checks.
- Added validation coverage that instantiates `ItemCodexUI` and confirms the codex creates 100 `ItemCodexSlot` controls.

### Verified

- Gameplay scene loads successfully in Godot 4.7 headless mode.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Item catalog validation still reports `[item_catalog] OK items=21 max_no=21`.

## 2026-06-30 UIManager Centralization Pass

### Completed

- Promoted `UIManager` to a project autoload so gameplay UI state is controlled by one persistent runtime controller.
- Removed the old scene-local `UIManager` node from `player_test_world_3d.tscn`.
- Updated `UIManager` to bind `TopMenuBar`, `InventoryEquipmentUI`, and `ItemCodexUI` from the active gameplay scene.
- Centralized Tab, Escape, Enter, Space, and top-menu click handling in `UIManager`.
- Kept unfinished main tabs such as quests, status, and map selectable in the top menu without opening placeholder panels.
- Removed obsolete panel open/close and scene-search helpers from `TopMenuBar`; it now only handles visual selection and emits menu requests.
- Normalized `main_menu.gd` to use the shared `UIStyle` helper name consistently.

### Verified

- Godot 4.7 headless startup succeeds.
- Gameplay scene loads successfully in Godot 4.7 headless mode.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Item catalog validation still reports `[item_catalog] OK items=21 max_no=21`.
- Runtime eval confirms `/root/UIManager` exists, backpack and codex panels switch exclusively, unfinished tabs keep the top menu open, and `close_all()` hides all managed gameplay UI.

## 2026-07-01 Difficulty Select UI Pass

### Completed

- Rebuilt `DifficultySelectPanel` to use the same overlay panel, margin, font, row spacing, and back button sizing patterns as `SettingsPanel`.
- Changed difficulty choices from compact stacked buttons into settings-style rows with a left label and right selectable control.
- Added a selected difficulty highlight style so the current choice is visible without relying on extra instruction text.
- Enlarged and aligned the difficulty panel in `main_menu.gd` to match the settings panel placement rules.
- Added `ui.difficulty.*` keys to `game_text.csv` for Traditional Chinese, English, Japanese, and Simplified Chinese.
- Replaced garbled fallback difficulty text with clean fallback strings.

### Verified

- Godot 4.7 headless startup succeeds.
- Main menu scene loads successfully in Godot 4.7 headless mode.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Item catalog validation still reports `[item_catalog] OK items=21 max_no=21`.

## 2026-07-01 Top Menu Toggle Pass

### Completed

- Updated `UIManager` so Tab now toggles the whole top UI system menu instead of only toggling the backpack panel.
- When no top-menu UI is open, Tab opens the default backpack tab.
- When any top-menu UI is already open, including backpack, quests, status, map, or codex, Tab closes the whole top UI system menu.
- Escape still closes the active top UI system menu through the same centralized close path.

### Verified

- Godot 4.7 headless startup succeeds.
- Gameplay scene loads successfully in Godot 4.7 headless mode.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Item catalog validation still reports `[item_catalog] OK items=21 max_no=21`.
- Runtime eval confirms Tab opens backpack by default, Tab closes from backpack, Tab closes from codex, and Escape closes from backpack.

## 2026-07-01 Codex Detail Text Wrap Pass

### Completed

- Updated `ItemCodexUI` detail-description wrapping so long text without spaces, such as Chinese and Japanese, is split safely by character when it exceeds the detail panel width.
- Kept the existing word-based wrapping for English and other space-separated languages.
- Prevented right-side codex descriptions from being clipped by `draw_string` when the translated sentence is wider than the panel.

### Verified

- Godot 4.7 headless startup succeeds.
- Gameplay scene loads successfully in Godot 4.7 headless mode.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Item catalog validation still reports `[item_catalog] OK items=21 max_no=21`.

## 2026-07-01 Codex Grid Centering Pass

### Completed

- Updated the item codex grid container to use centered horizontal sizing instead of relying on the scroll container's default left placement.
- Centralized codex grid padding and scrollbar reservation values so future layout tuning is easier.
- Kept the 10-column catalog layout intact while improving horizontal centering inside the grid panel.

### Verified

- Godot 4.7 headless startup succeeds.
- Gameplay scene loads successfully in Godot 4.7 headless mode.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Item catalog validation still reports `[item_catalog] OK items=21 max_no=21`.

## 2026-07-01 Codex Grid Shell Centering Pass

### Completed

- Reworked the item codex grid placement to use an explicit `GridShell` inside the scroll area.
- The grid now calculates its total width from 10 columns and centers that width against the grid backing panel instead of relying on `ScrollContainer` child alignment.
- Removed the previous right-side scrollbar width subtraction that visually biased the grid toward the left.
- Explicitly assigns shell and grid size/position during layout so the centered placement remains stable after container updates.

### Verified

- Godot 4.7 headless startup succeeds.
- Gameplay scene loads successfully in Godot 4.7 headless mode.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Item catalog validation still reports `[item_catalog] OK items=21 max_no=21`.

## 2026-07-01 Top Menu Movement Pass

### Completed

- Split gameplay input blocking into movement blocking and action blocking.
- Top-menu UI states such as backpack and codex no longer block player movement, sprint, or dodge.
- Pause UI remains movement-blocking.
- Player attack/action input still treats active UI as blocked so clicking UI or open panels does not accidentally fire gameplay actions.

### Verified

- Godot 4.7 headless startup succeeds.
- Gameplay scene loads successfully in Godot 4.7 headless mode.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Item catalog validation still reports `[item_catalog] OK items=21 max_no=21`.
- Runtime eval confirms backpack and codex keep `movement_blocked=false`, while pause sets `movement_blocked=true`.

## 2026-07-01 Inventory Context Menu Pass

### Completed

- Added right-click backpack item context menu with split and drop actions.
- Added stack splitting support to `InventoryModel`.
- Added a split dialog with current split amount display, slider control, confirm button, and cancel/back button.
- Reused the existing world-drop pickup flow for right-click drop so drag-drop and context-drop share the same item spawning behavior.
- Added localization keys for split, drop, split amount, and split confirmation.
- Kept mark/tag action out of scope for this pass.

### Verified

- Godot 4.7 headless startup succeeds.
- Gameplay scene loads successfully in Godot 4.7 headless mode.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Item catalog validation still reports `[item_catalog] OK items=21 max_no=21`.

## 2026-07-01 Nearby Context Drop Pass

### Completed

- Updated right-click inventory drop to place discarded items near the player instead of using the context menu screen position.
- Added a player-centered random drop radius for context-menu drops.
- Kept drag-drop behavior using the existing mouse-direction placement logic.

### Verified

- Godot 4.7 headless startup succeeds.
- Gameplay scene loads successfully in Godot 4.7 headless mode.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Item catalog validation still reports `[item_catalog] OK items=21 max_no=21`.

## 2026-07-01 Inventory Drag Merge Swap Pass

### Completed

- Added inventory model support for drag merge and drag swap behavior.
- Dragging one backpack stack onto the same catalog number merges quantities only when `max_stack > 1` and the target stack has room.
- Same catalog number items with `max_stack = 1` do not merge.
- Dragging onto a different catalog number swaps the two stack positions.
- Backpack UI now calls the merge/swap model behavior when a dragged item is released over an occupied backpack slot.
- Added `tools/validate_inventory_drag_rules.gd` for focused rule validation.

### Verified

- Godot 4.7 headless startup succeeds.
- Gameplay scene loads successfully in Godot 4.7 headless mode.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Item catalog validation still reports `[item_catalog] OK items=21 max_no=21`.
- Inventory drag rule validation reports `[inventory_drag_rules] OK`.

## 2026-07-01 Save Slot Panel Pass

### Completed

- Added reusable `SaveSlotPanel` so the main menu no longer builds load-slot rows inline.
- Connected the load panel to `SaveGameManager` slot summaries and continue flow.
- Added fallback UI copy for empty-slot, loading, and save-manager-missing states without depending on the messy localization CSV.
- Simplified `main_menu.gd` so it only opens and refreshes the reusable save-slot panel.
- Added `tools/validate_save_slot_panel.gd` for focused headless validation.

### Verified

- Save slot validation still reports `[save_slots] OK slots=3 save=start load=continue`.
- Save slot panel validation reports `[save_slot_panel] OK rows=3 refresh=ready`.
- Godot 4.7 headless startup succeeds after the main-menu load panel refactor.

## 2026-07-01 Gameplay Architecture Pass

### Completed

- Added `PlayerStatsProfile` so player base stats and bonuses live in a typed Resource instead of many controller-owned export fields.
- Updated `PlayerStats3D` to calculate from `PlayerStatsProfile` directly, removing string-based `owner.get()` stat lookups.
- Added `PlayerLocomotion3D` for sprint, stamina, carry-weight speed, and dodge-roll rules.
- Reduced `PlayerController3D` to player orchestration, inventory ownership, mouse facing, and compatibility accessors.
- Moved starter inventory loading and backpack state ownership onto the player instead of the inventory UI.
- Updated `InventoryEquipmentUI` to bind to the player's `InventoryModel`, keeping UI as a display/control layer.
- Updated `LootPickup3D` to add items through the player pickup contract instead of finding `InventoryEquipmentUI`.
- Updated `PlayerInputReader3D` to read the `/root/UIManager` autoload contract for gameplay input blocking.
- Added `tools/validate_gameplay_architecture.gd` to guard against the old UIManager lookup, pickup-to-UI coupling, and string-based stat lookup returning.

### Verified

- Godot MCP runtime launched `res://scenes/gameplay/player_test_world_3d.tscn` successfully and reported the game helper live.
- Runtime eval confirms the player exists, exposes `get_inventory_model()` and `add_item_resource()`, owns a 50-slot inventory model, loads the starter inventory, and can see `/root/UIManager`.
- Runtime eval confirms opening the backpack through `/root/UIManager` makes `PlayerInputReader3D.is_gameplay_blocked()` return true, then `close_all()` clears the UI state.
- Static scan confirms gameplay scripts no longer use `current_scene.find_child("UIManager")`, `LootPickup3D` no longer references `InventoryEquipmentUI`, and `PlayerStats3D` no longer uses `owner.get()`.

## 2026-07-01 Project Health Cleanup Pass

### Completed

- Added `InventoryEquipmentPainter` and moved inventory slot, icon, text, and panel drawing details out of `InventoryEquipmentUI`.
- Reduced `InventoryEquipmentUI` to 237 lines so it mostly owns UI state binding, input handling, layout orchestration, and inventory panel composition.
- Rewrote `docs/design/localization_plan.md` with a clean localization plan covering key naming, item resources, UI usage, validation backlog, and extension steps.
- Added the first combat domain slice with `DamageEvent`, `Damageable3D`, and `WeaponController3D`.
- Added a `WeaponController3D` child to `Player3D` using the 9mm pistol item resource.
- Added `CombatTarget` to `player_test_world_3d.tscn` so the test scene includes a real damageable target.
- Added `tools/validate_combat_domain.gd` to validate damage application, weapon-to-target flow, and scene wiring.

### Verified

- Static scan confirms the rewritten localization plan no longer contains the previous mojibake patterns.
- Static line count confirms `InventoryEquipmentUI` is 237 lines after moving drawing details into `InventoryEquipmentPainter`.
- Godot MCP launched the current gameplay scene and reported the game helper live.
- Runtime eval confirms `WeaponController3D.fire_at(CombatTarget)` succeeds and reduces target health from 50 to 26.
- Runtime eval confirms `InventoryEquipmentUI` exists in the gameplay HUD and still has a bound backpack model.

## 2026-07-01 Difficulty Selection Pass

### Completed

- Added `DifficultyProfile` resources under `data/difficulty` for easy, normal, and hard.
- Added `DifficultyManager` as a project autoload to own the selected difficulty and expose profile data.
- Added difficulty persistence to `GameSettings` through the `gameplay/difficulty_id` config entry.
- Added `DifficultySelectPanel` and changed the main menu Start flow so it opens difficulty selection before entering gameplay.
- Added local fallback text for the new difficulty UI keys so the feature works while the legacy localization CSV is still messy.
- Updated `PlayerController3D` to duplicate its runtime stats profile and let `DifficultyManager` apply the selected profile before health initialization.
- Added `tools/validate_difficulty_system.gd` to validate profile ordering, health scaling, and menu panel availability.

### Verified

- Godot MCP launched the main menu and reported the game helper live.
- Runtime eval confirms pressing Start opens the difficulty panel with exactly three difficulty buttons.
- Runtime eval confirms choosing hard sets `DifficultyManager.selected_difficulty_id` to `hard`, changes to gameplay, and initializes the player at 75 max health.

## 2026-07-01 Base Screen Task

### Completed

- Added node-first `scenes/base/base_screen.tscn` with a stable Control/container layout for the early base screen.
- Added `BaseScreen` binding logic for current slot, difficulty, money, stash rows, empty-stash state, and Start Raid.
- Added `tools/validate_base_screen.gd` to verify empty stash, filled stash, localized difficulty text, button sizing, and 1280x720/1920x1080 fit.
- Adjusted the base stash scroll region so the panel fits cleanly at 720p while staying ready for future art pass replacements.

### Verified

- Base screen validation reports `[base_screen] OK node_first=true empty=shown stash=shown layout=fits`.
- Save slot validation reports `[save_slots] OK slots=3 save=start load=continue schema=v1`.
- Stash model validation reports `[stash_model] OK add=merge remove=works save=round_trip`.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Base screen and main scene both pass Godot 4.7 headless startup.

### Next

- Continue with 任務五：調整新遊戲與讀取流程進入 Base.

## 2026-07-01 Base Entry Flow Task

### Completed

- Updated `SaveGameManager` so new saves default to `base_screen.tscn` and the manager tracks the current save slot.
- Changed difficulty confirmation so a new game creates/overwrites the preferred save slot, then enters Base instead of going straight to gameplay.
- Changed continue flow so loading an existing slot enters Base and preserves the selected current slot.
- Updated `BaseScreen` to read the current slot from `SaveGameManager`, while still falling back to the first existing slot if needed.
- Added `tools/validate_base_flow.gd` to guard the main menu start flow, continue flow, Base destination, and current-slot tracking.

### Verified

- Base flow validation reports `[base_flow] OK new_game=base continue=base current_slot=tracked`.
- Save slot validation reports `[save_slots] OK slots=3 save=start load=continue schema=v1`.
- Base screen validation reports `[base_screen] OK node_first=true empty=shown stash=shown layout=fits`.
- Difficulty validation reports `[difficulty_system] OK profiles=3 health=scaled menu=available`.
- UI foundation and StashModel validations still pass.
- Base screen and main scene both pass Godot 4.7 headless startup.

### Next

- Continue with 任務六：建立 `RaidSession`.

## 2026-07-02 Base Start Button Layout Repair

### Completed

- Fixed the Base screen layout issue where the stash scroll area expanded vertically and pushed the Start Raid button below the visible 1920x1080 game window.
- Reduced the Base stash scroll minimum height and removed its vertical expand flag so status text and the primary action stay visible.
- Added a deferred Base screen layout pass after data binding, preventing Godot container layout from stretching the main panel after `_ready()`.
- Strengthened `tools/validate_base_screen.gd` so it fails if the Start Raid button leaves the viewport or main panel.

### Verified

- Base screen validation reports `[base_screen] OK node_first=true empty=shown stash=shown layout=fits`.
- Base flow validation reports `[base_flow] OK new_game=base continue=base current_slot=tracked`.
- Godot AI runtime inspection confirms `MainPanel` is `980x620` at 1920x1080 and `StartRaidButton` is visible at `y=733`.
- Runtime mouse click on Start Raid successfully changes from Base to `PlayerTestWorld3D`.

## 2026-07-02 RaidSession Task

### Completed

- Added `scripts/raid/raid_session.gd` as the authoritative single-raid state owner.
- Added begin, extraction, death, state snapshot, and result dictionary APIs.
- Enforced terminal-state exclusivity so one raid cannot be both extracted and dead.
- Added a `RaidSession` node to `player_test_world_3d.tscn` at the scene root, separate from UI and player ownership.
- Added `tools/validate_raid_session.gd` to cover active state, extraction result, death result, restart behavior, and gameplay scene wiring.

### Verified

- Raid session validation reports `[raid_session] OK begin=active extraction=exclusive death=exclusive result=serializable scene=wired`.
- Gameplay architecture validation still reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- Combat domain validation still reports `[combat_domain] OK damageable=works weapon=applies_damage scene=has_target`.
- Base flow and save slot validations still pass.
- Gameplay scene passes Godot 4.7 headless startup.

### Next

- Run the required Project Health Check after 任務六, then continue with 任務七：建立 Extraction Zone.

## 2026-07-02 Project Health Check After Task Six

### Health Check

- Responsibility boundaries: `RaidSession` owns only raid lifecycle state/result data and does not reference UI, save files, inventory UI, or scene-flow panels.
- UI ownership: Base, save slot, and difficulty UI still read service/model state and emit user intent; persistent save data remains in `SaveGameManager`.
- Godot node-first UI: Base screen remains `.tscn`/Control/container based, with script limited to data binding, layout correction, and button behavior.
- UI layout quality: Base panel now keeps `StartRaidButton` visible in runtime and validation checks the button stays inside both panel and viewport.
- Script size and focus: largest scripts remain below the 300-350 line review threshold; `inventory_equipment_ui.gd` and `item_codex_ui.gd` are watch items but not blockers.
- Data-driven content: item catalog remains resource-driven; no new hard-coded content volume was added in Task Six.
- Save safety: Save Schema v1 validation still passes after Base and RaidSession changes.
- Localization: no new player-facing strings were added by RaidSession; existing Base validation accepts localized difficulty text.
- Scene health: main scene and gameplay scene both load headless.
- Validation health: Standard validation set plus `validate_stash_model.gd`, `validate_base_screen.gd`, `validate_base_flow.gd`, and `validate_raid_session.gd` pass.

### Verified

- Full health validation run reports `PROJECT_HEALTH_VALIDATION_PASSED`.
- `validate_raid_session.gd` reports `[raid_session] OK begin=active extraction=exclusive death=exclusive result=serializable scene=wired`.
- Main scene and gameplay scene pass Godot 4.7 headless startup.

### Next

- Continue with 任務七：建立 Extraction Zone.

## 2026-07-02 Extraction Zone Task

### Completed

- Added `scripts/raid/extraction_zone_3d.gd` as an independent Area3D-based extraction owner.
- Added countdown, cancellation on exit, completion, progress state, and RaidSession notification.
- Added a simple `ExtractionZone` node to `player_test_world_3d.tscn` with collision, visible marker, and Label3D prompt.
- Kept extraction independent from inventory and backpack UI state.
- Added `tools/validate_extraction_flow.gd` to guard countdown, cancellation, session notification, and gameplay scene wiring.

### Verified

- Extraction flow validation reports `[extraction_flow] OK countdown=works cancel=works session=notified scene=wired`.
- Raid session validation still reports `[raid_session] OK begin=active extraction=exclusive death=exclusive result=serializable scene=wired`.
- Gameplay architecture validation still reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- Combat domain validation still reports `[combat_domain] OK damageable=works weapon=applies_damage scene=has_target`.
- Gameplay scene passes Godot 4.7 headless startup.

### Next

- Continue with 任務八：建立 Raid Result Data.

## 2026-07-02 Raid Result Data Task

### Completed

- Added `scripts/raid/raid_result.gd` as the shared raid result schema helper.
- Defined required result fields: `outcome`, `extracted_items`, `lost_items`, `kept_safe_pocket_items`, `money_delta`, and `duration`.
- Updated `RaidSession` to build extracted and death results through the shared schema.
- Kept session metadata such as `map_id`, timestamps, and terminal flags as serializable result data.
- Updated `tools/validate_raid_session.gd` to verify schema defaults, required keys, and Object/Node reference sanitization.

### Verified

- Raid session validation reports `[raid_session] OK begin=active extraction=exclusive death=exclusive result=schema_serializable scene=wired`.
- Extraction flow validation still reports `[extraction_flow] OK countdown=works cancel=works session=notified scene=wired`.
- Gameplay scene passes Godot 4.7 headless startup.

### Next

- Continue with 任務九：建立 Raid Result Panel.

## 2026-07-02 Raid Result Panel Task

### Completed

- Added `scenes/ui/raid_result_panel.tscn` as a node-first Control scene for raid results.
- Added `scripts/ui/raid_result_panel.gd` for result data binding, RaidSession signal handling, and Continue to Base intent.
- Wired `HUD/RaidResultPanel` into `player_test_world_3d.tscn`, hidden by default and shown when `RaidSession.raid_completed` emits.
- Result panel shows outcome, duration, money delta, extracted items, lost items, safe pocket items, status text, and a Continue to Base button.
- Kept the panel from directly mutating stash/save data; inventory transfer remains reserved for the result application flow in 任務十.
- Fixed `top_menu_bar.gd` deferred move-to-front behavior so quick scene validation no longer resumes an awaited function on a freed instance.

### Verified

- Raid result panel validation reports `[raid_result_panel] OK node_first=true fake_data=shown continue=base layout=fits`.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Raid session and extraction flow validations still pass.
- Gameplay scene passes Godot 4.7 headless startup.
- UI layout quality check passed by automated rect checks at `1280x720` and `1920x1080`: main panel and Continue button stay inside viewport and panel, button meets early size rules, and list sections remain node/container based.

## 2026-07-02 Project Health Check After Task Nine

### Health Check

- Responsibility boundaries: `RaidSession` still owns raid lifecycle and result emission; `RaidResultPanel` only displays result data and emits Continue intent.
- UI ownership: Result UI does not mutate stash, save data, inventory, or raid domain state.
- Godot node-first UI: Result panel structure exists in `.tscn` using Control, PanelContainer, MarginContainer, VBox/HBoxContainer, ScrollContainer, Label, and Button nodes.
- UI layout quality: Result panel has clear title, summary row, item list columns, status text, and primary action. Automated layout checks cover `1280x720` and `1920x1080`.
- Script size and focus: new `raid_result_panel.gd` is below the review threshold; existing `inventory_equipment_ui.gd` and `item_codex_ui.gd` remain watch items for future refactor work.
- Data-driven content: Raid result item names resolve from item resource paths; no new loot/content volume was hard-coded.
- Save safety: no save schema changes were made in Task Nine.
- Localization: new player-facing strings use localization-key lookups with temporary fallbacks.
- Scene health: main menu and gameplay scenes both load headless.
- Validation health: standard gameplay/UI/save/combat/audio/stash validations pass; the previously noisy TopMenu deferred await was cleaned up.

### Verified

- `validate_item_catalog.gd`, `validate_ui_foundation.gd`, `validate_inventory_drag_rules.gd`, `validate_inventory_loadouts.gd`, `validate_gameplay_architecture.gd`, `validate_combat_domain.gd`, `validate_difficulty_system.gd`, `validate_save_slots.gd`, `validate_save_slot_panel.gd`, `validate_base_screen.gd`, `validate_base_flow.gd`, `validate_audio_settings.gd`, `validate_pause_menu.gd`, `validate_stash_model.gd`, `validate_raid_session.gd`, `validate_extraction_flow.gd`, and `validate_raid_result_panel.gd` pass.
- Main menu and gameplay scene startup pass Godot 4.7 headless checks.

### Next

- Continue with 任務十：完成撤離成功物資轉移.

## 2026-07-02 Extraction Success Transfer Task

### Completed

- Added `scripts/raid/raid_result_applier.gd` as the non-UI owner of applying completed raid results to persistent save data.
- Updated `ExtractionZone3D` to snapshot the player's backpack stacks into `extracted_items` before completing extraction.
- Updated the gameplay scene with a `RaidResultApplier` node wired to `RaidSession.raid_completed`.
- Added `InventoryModel.clear()` so raid inventory can be cleared after a successful transfer.
- Updated `tools/validate_extraction_flow.gd` to verify backpack pickup data becomes raid result data, then persistent stash save data, and the raid inventory is cleared.

### Verified

- Extraction flow validation reports `[extraction_flow] OK countdown=works cancel=works transfer=stash_saved inventory=cleared scene=wired`.
- Save slot validation reports `[save_slots] OK slots=3 save=start load=continue schema=v1`.
- Raid session validation reports `[raid_session] OK begin=active extraction=exclusive death=exclusive result=schema_serializable scene=wired`.
- Raid result panel validation still reports `[raid_result_panel] OK node_first=true fake_data=shown continue=base layout=fits`.
- Gameplay architecture validation still reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- Stash model, Base screen, Base flow, and gameplay scene headless startup all pass.

### Next

- Continue with 任務十一：完成死亡與遺失規則.

## 2026-07-02 Death Loss Rules Task

### Completed

- Added `scripts/raid/raid_loss_rules.gd` to define the early death loss interface.
- Death context now lists backpack stacks as `lost_items` and keeps a `kept_safe_pocket_items` array for the future safe pocket system.
- Updated `RaidResultApplier` so death results clear raid inventory without adding backpack items to persistent stash.
- Updated `tools/validate_extraction_flow.gd` to cover both successful extraction transfer and death loss behavior.
- Confirmed death still travels through the existing `RaidSession.raid_completed` result flow, so `RaidResultPanel` can show lost items from the result data.

### Verified

- Extraction flow validation reports `[extraction_flow] OK countdown=works cancel=works transfer=stash_saved death=lost_items inventory=cleared scene=wired`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- Raid session validation reports `[raid_session] OK begin=active extraction=exclusive death=exclusive result=schema_serializable scene=wired`.
- Raid result panel, save slots, stash model, and gameplay scene headless startup all pass.

### Next

- Continue with 任務十二：建立 LootTable Resource.

## 2026-07-02 LootTable Resource Task

### Completed

- Added `scripts/loot/loot_table_entry.gd` for item path, min/max quantity, weight, and optional tags.
- Added `scripts/loot/loot_table.gd` for validation and weighted stack rolling.
- Added `data/loot_tables/refuge_outskirts_common.tres` with early common loot entries.
- Added `tools/validate_loot_tables.gd` to verify valid rolls, invalid item path detection, and empty table detection.

### Verified

- Loot table validation reports `[loot_tables] OK common=valid roll=stacks invalid=caught empty=caught`.
- Item catalog validation reports `[item_catalog] OK items=21 max_no=21`.
- Gameplay architecture validation still reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- Gameplay scene passes Godot 4.7 headless startup.

### Next

- Run Project Health Check after 任務十二, then continue with 任務十三：建立 LootContainer3D.

## 2026-07-02 Project Health Check After Task Twelve

### Health Check

- Responsibility boundaries: Loot tables are Resource/data objects only; they do not reference UI, save managers, scene nodes, or raid flow.
- UI ownership: no UI was changed in Task Twelve.
- Godot node-first UI: unchanged; existing Result/Base UI validations still pass.
- UI layout quality: unchanged UI remains covered by Base and Raid Result panel layout validations at `1280x720` and `1920x1080`.
- Script size and focus: new loot scripts are small and focused; existing `inventory_equipment_ui.gd` and `item_codex_ui.gd` remain watch items.
- Data-driven content: `refuge_outskirts_common.tres` now defines early loot via resource data instead of scene-hard-coded loot.
- Save safety: no save schema changes were made in Task Twelve.
- Localization: no new player-facing strings were added.
- Scene health: main menu and gameplay scenes both load headless.
- Validation health: loot table, item catalog, UI, inventory, save, gameplay, combat, raid, base, and audio validations pass.

### Verified

- `validate_loot_tables.gd`, `validate_item_catalog.gd`, `validate_ui_foundation.gd`, `validate_inventory_drag_rules.gd`, `validate_save_slots.gd`, `validate_gameplay_architecture.gd`, `validate_combat_domain.gd`, `validate_raid_session.gd`, `validate_extraction_flow.gd`, `validate_base_screen.gd`, `validate_base_flow.gd`, and `validate_audio_settings.gd` pass.
- Main menu and gameplay scene startup pass Godot 4.7 headless checks.

### Next

- Continue with 任務十三：建立 LootContainer3D.

## 2026-07-02 LootContainer3D Task

### Completed

- Added `scripts/loot/loot_container_3d.gd` as an Area3D interaction owner for loot containers.
- Added `scenes/loot/loot_container_basic.tscn` with collision, placeholder crate mesh, prompt label, and a bound LootTable.
- Added one-shot open behavior so an opened container cannot grant repeat loot.
- Container rolls from LootTable and directly calls the player's inventory API, without depending on `InventoryEquipmentUI`.
- Added `tools/validate_loot_container.gd` to verify roll-to-inventory behavior, repeat-open blocking, scene wiring, and UI independence.

### Verified

- Loot container validation reports `[loot_container] OK roll=grants_inventory one_shot=blocks_repeat ui_coupling=clean scene=wired`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- Loot table, inventory loadout, and item catalog validations still pass.
- Loot container scene and gameplay scene both pass Godot 4.7 headless startup.

### Next

- Continue with 任務十四：把 Refuge Outskirts 測試場景改成第一張可玩 raid map.

## 2026-07-02 Refuge Outskirts Playable Map Task

### Completed

- Kept the existing gameplay test scene path so current Base and validation flows remain stable.
- Added `SceneProps/PlayerSpawnMarker` as a clear player spawn marker.
- Added three `LootContainer3D` instances to the map using the shared basic loot container scene and common Refuge Outskirts loot table.
- Kept the existing `ExtractionZone`, player, HUD, TopMenu, Inventory, Codex, Pause, CombatTarget, RaidSession, RaidResultPanel, and RaidResultApplier wiring.
- Updated `tools/validate_loot_container.gd` so gameplay map validation now checks for spawn, loot containers, and extraction.

### Verified

- Extraction flow validation reports `[extraction_flow] OK countdown=works cancel=works transfer=stash_saved death=lost_items inventory=cleared scene=wired`.
- Loot container validation reports `[loot_container] OK roll=grants_inventory one_shot=blocks_repeat map=spawn_loot_extract ui_coupling=clean scene=wired`.
- Gameplay architecture, loot table, item catalog, and raid result panel validations still pass.
- Gameplay scene passes Godot 4.7 headless startup.

### Next

- Continue with 任務十五：補齊手槍基礎射擊規則.

## 2026-07-02 Pistol Basic Firing Rules Task

### Completed

- Updated `WeaponController3D` with fire cooldown, magazine ammo, reserve ammo, reload-from-reserve, and block reasons.
- Added `missed` and `fire_blocked` signals plus `last_fire_result` as early hit/miss/ammo feedback interfaces.
- Kept damage application through the existing `DamageEvent` and `Damageable3D` domain path.
- Updated `tools/validate_combat_domain.gd` to verify damage, ammo consumption, cooldown blocking, no-ammo blocking, reload behavior, and gameplay scene weapon wiring.

### Verified

- Combat domain validation reports `[combat_domain] OK damageable=works weapon=ammo_cooldown_damage scene=has_target`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- Item catalog validation still passes.
- Player scene and gameplay scene both pass Godot 4.7 headless startup.

### Next

- Continue with 任務十六：建立玩家受傷與死亡事件.

## 2026-07-02 Player Damage And Death Task

### Completed

- Added `health_changed` and `died` signals to `Player3D`.
- Added `Player3D.apply_damage()` so DamageEvent can reduce player health and trigger death once.
- Player death now builds death loss context through `RaidLossRules` and notifies `RaidSession.register_player_death()`.
- Updated `PlayerHud3D` to listen for player health changes and redraw immediately.
- Added `tools/validate_player_damage.gd` to verify damage, single death emission, RaidSession death result, lost items, and HUD health signal.

### Verified

- Player damage validation reports `[player_damage] OK health=decreases death=once raid_result=dead hud_signal=emits`.
- Combat domain validation reports `[combat_domain] OK damageable=works weapon=ammo_cooldown_damage scene=has_target`.
- Extraction flow, raid result panel, gameplay architecture, and gameplay scene headless startup all pass.

### Next

- Continue with 任務十七：建立 EnemyDef 與 Scavenger 場景.

## 2026-07-02 EnemyDef And Scavenger Scene Task

### Completed

- Added `scripts/ai/enemy_def.gd` as the first data-driven enemy definition resource.
- Added `data/enemies/scavenger.tres` with health, move speed, damage, detect radius, and loot table path.
- Added `scripts/ai/enemy_damageable_3d.gd` so enemy roots can be CharacterBody3D and still receive DamageEvent.
- Added `scenes/enemies/scavenger_3d.tscn` with placeholder body/head meshes, collision, EnemyDef metadata, and damageable behavior.
- Added `tools/validate_enemy_def.gd` to verify enemy data, invalid data detection, scene loadability, and damageable presence.

### Verified

- Enemy definition validation reports `[enemy_def] OK scavenger=data_valid scene=loadable damageable=present`.
- Combat domain validation reports `[combat_domain] OK damageable=works weapon=ammo_cooldown_damage scene=has_target`.
- Loot table and gameplay architecture validations still pass.
- Scavenger scene and gameplay scene both pass Godot 4.7 headless startup.

### Next

- Continue with 任務十八：建立 Scavenger AI v1.

## 2026-07-02 Scavenger AI v1 Task

### Completed

- Added `scripts/ai/enemy_controller_3d.gd` with Idle, Chase, Attack, and Dead behavior.
- Wired `EnemyController3D` into `scavenger_3d.tscn`.
- Scavenger now detects live players in range, chases when outside attack range, attacks when close, and stops after enemy death.
- Added `tools/validate_enemy_ai.gd` to cover detect/chase, attack damage, death stop behavior, and scene wiring.

### Verified

- Enemy AI validation reports `[enemy_ai] OK detect=chase attack=damages dead=stops scene=wired`.
- Player damage validation reports `[player_damage] OK health=decreases death=once raid_result=dead hud_signal=emits`.
- Enemy definition, combat domain, and gameplay scene startup validations pass.

## 2026-07-02 Project Health Check After Task Eighteen

### Health Check

- Responsibility boundaries: enemy data, damageable health, and AI behavior remain split across EnemyDef, EnemyDamageable3D, and EnemyController3D.
- UI ownership: no UI state is changed by enemy AI; player HUD remains signal/read based.
- Godot node-first UI: unchanged UI validations still pass.
- UI layout quality: no UI layout changes were made in Tasks Sixteen to Eighteen.
- Script size and focus: new AI scripts are focused and under review thresholds; existing large UI scripts remain watch items.
- Data-driven content: Scavenger reads EnemyDef metadata and loot table path rather than hard-coding enemy stats into AI logic.
- Save safety: no save schema changes were made.
- Localization: no new player-facing UI text was added.
- Scene health: main menu, gameplay scene, and scavenger scene all load headless.
- Validation health: player damage, combat, enemy data, enemy AI, gameplay architecture, extraction, loot, UI, save, raid, base, and audio validations pass.

### Verified

- `validate_player_damage.gd`, `validate_combat_domain.gd`, `validate_enemy_def.gd`, `validate_enemy_ai.gd`, `validate_gameplay_architecture.gd`, `validate_extraction_flow.gd`, `validate_loot_container.gd`, `validate_ui_foundation.gd`, `validate_save_slots.gd`, `validate_raid_session.gd`, `validate_base_flow.gd`, `validate_audio_settings.gd`, and `validate_loot_tables.gd` pass.
- Main menu, gameplay scene, and scavenger scene startup pass Godot 4.7 headless checks.

## 2026-07-02 Enemy Loot Drop Task

### Completed

- Added `scripts/ai/enemy_loot_drop_3d.gd` as a focused enemy death loot component.
- Wired `EnemyLootDrop3D` into `scenes/enemies/scavenger_3d.tscn`.
- Scavenger now reads its `EnemyDef.loot_table_path`, rolls the linked LootTable on death, and spawns existing LootPickup3D pickups near the death position.
- Enemy drops are one-shot per enemy instance through `has_dropped`, preventing repeated loot from the same Scavenger.
- Added `tools/validate_enemy_loot_drop.gd` to verify death drop spawn, pickup inventory transfer, repeat-drop blocking, and UI independence.

### Verified

- Enemy loot drop validation reports `[enemy_loot_drop] OK death=spawns_pickup pickup=adds_inventory repeat=blocked ui_coupling=clean`.
- Enemy AI validation reports `[enemy_ai] OK detect=chase attack=damages dead=stops scene=wired`.
- Loot table validation reports `[loot_tables] OK common=valid roll=stacks invalid=caught empty=caught`.
- Enemy definition, combat domain, gameplay architecture, and Scavenger scene headless startup all pass.

## 2026-07-02 Raid HUD Objective Task

### Completed

- Added `scripts/ui/raid_hud_panel.gd` and `scenes/ui/raid_hud_panel.tscn` as a node-first stable HUD panel.
- Wired `RaidHudPanel` into `scenes/gameplay/player_test_world_3d.tscn`.
- Raid HUD now shows the early objective, raid active status, extraction hint/countdown/progress, and current weapon ammo.
- HUD uses Control nodes, PanelContainer, MarginContainer, VBoxContainer, Label, and ProgressBar; script only binds state and text.
- HUD ignores mouse input and remains compatible with UIManager-managed backpack/codex/pause panels.
- Added `tools/validate_raid_hud.gd` to cover HUD wiring, extraction state, ammo display, UIManager compatibility, node-first structure, UI independence, and 1280x720/1920x1080 layout fit.

### Verified

- Raid HUD validation reports `[raid_hud] OK objective=visible extraction=status ammo=visible ui_manager=compatible layout=fit`.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- Extraction flow and player damage validations still pass.
- Gameplay scene passes Godot 4.7 headless startup.

### UI Layout Quality Check

- Panel base: compact top-left overlay with a styled PanelContainer backing.
- Spacing and alignment: node-first margin and VBox spacing keep objective, status, extraction, progress, and ammo grouped clearly.
- Readability: important labels use existing UIStyle font sizes and do not scale below readable sizes.
- Fit: validation checks 1280x720 and 1920x1080 safe margins, viewport bounds, and gameplay-view coverage limits.
- Interaction: mouse_filter is ignore, so the HUD does not block gameplay, backpack, codex, or pause UI.

## 2026-07-02 Vendor Sell Task

### Completed

- Added `scripts/base/stash_vendor.gd` as the focused sell-rule helper for stash items.
- Added `Sell All Junk` to `scenes/base/base_screen.tscn` using an existing Button node inside the Base action row.
- Updated `BaseScreen` to show sell value, sell stash junk, update money, rebuild stash rows, and save the current slot.
- Sell rules use `ItemDef.value * quantity`, sell `loot`, `valuable`, `currency`, and `intel`, and keep crafting/electronics materials for early upgrades.
- Added `tools/validate_vendor_sell.gd` to verify sale value, stash removal, money persistence, and material retention.

### Verified

- Vendor sell validation reports `[vendor_sell] OK value=item_def stash=removes_sold money=saved materials=kept`.
- Save slot validation reports `[save_slots] OK slots=3 save=start load=continue schema=v1`.
- Base flow validation reports `[base_flow] OK new_game=base continue=base current_slot=tracked`.
- Base screen validation reports `[base_screen] OK node_first=true empty=shown stash=shown layout=fits`.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Base scene passes Godot 4.7 headless startup.

### UI Layout Quality Check

- Panel base: unchanged Base panel backing and margins remain node-first.
- Buttons: `Sell All Junk` uses a real Button node with the same 48px height as `Start Raid`.
- Spacing and alignment: ActionRow now has consistent 12px separation and right alignment.
- Readability: sell button displays the sale value when available and disables when no sellable stash exists.
- Fit: existing Base screen validation still reports layout fit after adding the second action button.

## 2026-07-02 Project Health Check After Task Twenty-One

### Health Check

- Responsibility boundaries: enemy drops, Raid HUD, and vendor sell rules are split across focused components instead of being mixed into AI, gameplay, or monolithic UI scripts.
- Script boundaries: `EnemyLootDrop3D`, `RaidHudPanel`, and `StashVendor` remain focused; BaseScreen only coordinates UI, save, and refresh behavior.
- UI ownership: Raid HUD does not depend on inventory/codex panels, and Base sell UI uses scene nodes plus small state-binding code.
- Godot node-first UI: Raid HUD and Base sell button are implemented with `.tscn` Control nodes, containers, labels, progress bar, and buttons.
- UI layout quality: Raid HUD and Base screen validations cover fit, safe margins, visible hierarchy, button size, and non-blocking HUD input.
- Data-driven content: enemy drops read EnemyDef LootTable paths; vendor sell value reads `ItemDef.value`.
- Save safety: vendor sell updates current slot data through SaveGameManager and save slot validation still passes.
- Localization: new player-facing strings use `_text()` fallback keys and do not introduce hardcoded-only flow blockers.
- Scene loadability: main project, gameplay scene, and Base scene all load in Godot 4.7 headless.
- Validation health: vendor, save, base, UI, Raid HUD, enemy drop, extraction, gameplay architecture, combat, item catalog, and loot table validations pass.

### Verified

- `validate_vendor_sell.gd`, `validate_save_slots.gd`, `validate_base_screen.gd`, `validate_base_flow.gd`, `validate_ui_foundation.gd`, `validate_raid_hud.gd`, `validate_enemy_loot_drop.gd`, `validate_extraction_flow.gd`, `validate_gameplay_architecture.gd`, `validate_combat_domain.gd`, `validate_item_catalog.gd`, and `validate_loot_tables.gd` pass.
- Main project, gameplay scene, and Base scene startup pass Godot 4.7 headless checks.

## 2026-07-02 Workbench Upgrade Task

### Completed

- Added `scripts/base/upgrade_def.gd` as the data format for base upgrades.
- Added `data/base_upgrades/workbench_level_1.tres` with wood, wire, and money costs.
- Added `scripts/base/base_progression.gd` as the focused helper for upgrade affordability, cost deduction, purchased state, and starter ammo bonus lookup.
- Updated `BaseScreen` with a node-first Workbench section showing upgrade name, description, cost, status, and an Upgrade button.
- Workbench Level 1 now deducts required stash materials and money, persists in `base_upgrades`, and disables the button after purchase.
- Player startup now reads the current save slot upgrade state and applies the Workbench starter reserve ammo +1 effect for the next raid.
- Added `tools/validate_base_progression.gd` to verify upgrade data, insufficient-cost UI state, successful purchase, save persistence, and starter ammo effect.

### Verified

- Base progression validation reports `[base_progression] OK upgrade=data_valid cost=deducted save=persists effect=starter_ammo`.
- Vendor sell validation reports `[vendor_sell] OK value=item_def stash=removes_sold money=saved materials=kept`.
- Save slot validation reports `[save_slots] OK slots=3 save=start load=continue schema=v1`.
- Base flow validation reports `[base_flow] OK new_game=base continue=base current_slot=tracked`.
- Gameplay architecture, combat domain, player damage, UI foundation, and item catalog validations pass.
- Base scene and gameplay scene pass Godot 4.7 headless startup.

### UI Layout Quality Check

- Panel base: Workbench was added inside the existing Base panel using scene nodes and containers, not script-built UI.
- Spacing and grouping: Workbench has its own title, description, cost/status row, and Upgrade button, separated from stash and global actions.
- Buttons: Upgrade, Sell All Junk, and Start Raid keep readable 48px button heights and consistent grouping.
- 1280x720 fit: Base vertical spacing and stash height were tightened after validation caught overflow at 720p.
- Visual hierarchy: upgrade status and cost are visible before the action button, and purchased/blocked states are clearly disabled.

## 2026-07-02 Quest Data Model Task

### Completed

- Added `scripts/quests/quest_def.gd` as the data-driven quest definition resource.
- Added `scripts/quests/quest_state.gd` as a save-friendly quest state helper.
- Added `data/quests/first_salvage.tres` as the first collection/extraction quest: extract wood or wire.
- Quest objectives now support `collect`, `extract`, and `extract_any` data modes.
- Quest state can update from extracted item stacks, become ready, claim rewards, and serialize back to save data.
- SaveGameManager now normalizes quest state dictionaries when loading slots.
- Added `tools/validate_quest_model.gd` to verify QuestDef loading, extract_any progress, reward claiming, and save round trip.

### Verified

- Quest model validation reports `[quest_model] OK def=loads progress=extract_any reward=claim save=round_trip`.
- Save slot validation reports `[save_slots] OK slots=3 save=start load=continue schema=v1`.
- Base progression validation reports `[base_progression] OK upgrade=data_valid cost=deducted save=persists effect=starter_ammo`.
- Base screen and item catalog validations pass.
- Main project startup passes Godot 4.7 headless.

## 2026-07-02 Quest Base Flow Task

### Completed

- Updated `RaidResultApplier` so extracted wood or wire updates First Salvage quest progress in the current save slot.
- Added a node-first Quest section to `scenes/base/base_screen.tscn` with quest title, objective, progress, status, and Submit button.
- Updated `BaseScreen` to display First Salvage as Active, Ready, or Completed.
- BaseScreen can now submit a ready quest, grant reward money, mark it completed, and save the completed/claimed state.
- Converted the Base middle content area into a ScrollContainer so Stash, Workbench, and Quest sections can grow without breaking 1280x720 layout.
- Added `tools/validate_quest_flow.gd` to verify extraction progress, Base submit, reward persistence, completed state, and Quest UI layout.

### Verified

- Quest flow validation reports `[quest_flow] OK extraction=updates_base quest=claimable reward=saved layout=fits`.
- Quest model validation reports `[quest_model] OK def=loads progress=extract_any reward=claim save=round_trip`.
- Save slot validation reports `[save_slots] OK slots=3 save=start load=continue schema=v1`.
- Extraction flow validation reports `[extraction_flow] OK countdown=works cancel=works transfer=stash_saved death=lost_items inventory=cleared scene=wired`.
- Base progression, Base screen, UI foundation, and Base scene startup validations pass.

### UI Layout Quality Check

- Panel base: Quest UI extends the existing Base scene with Control/Container nodes, not script-built panels.
- Visual hierarchy: Quest title, objective, progress, state, and submit action are separated and readable.
- States: Active disables Submit, Ready enables Submit, Completed disables Submit and shows completed status.
- Responsive fit: Base middle content now scrolls, keeping bottom status/actions stable and passing 1280x720/1920x1080 layout checks.
- Future-proofing: Stash, Workbench, and Quest content can expand without overflowing the Base panel.

### Next

- Continue with 任務二十五：建立第一個擊殺任務.

### Next

- Continue with 任務二十四：把第一個收集任務接到 Base.

### Next

- Continue with 任務二十三：建立 Quest 資料模型.

### Next

- Continue with 任務二十二：建立第一個 Workbench Upgrade.

### Next

- Continue with 任務二十一：建立簡單金錢與出售流程.

### Next

- Continue with 任務二十：加入 Raid HUD 目標資訊.

### Next

- Continue with 任務十九：加入敵人掉落.

## 2026-07-02 Project Health Check After Task Twenty-Four

### Health Check

- Responsibility boundaries: quest data/state, Base UI display, save application, enemy AI, and enemy drop logic remain split across focused scripts.
- Script boundaries: QuestState, BaseScreen, enemy AI, and enemy loot drop remain focused enough to continue.
- UI ownership: Base Quest UI remains node-first and only displays save-backed quest state.
- Godot node-first UI: Base screen uses `.tscn` Control nodes, containers, labels, buttons, and a ScrollContainer for expanding middle content.
- UI layout quality: Base Quest, Workbench, stash, and action areas pass 1280x720/1920x1080 fit checks with readable buttons and stable spacing.
- Data-driven content: quests, upgrades, enemies, items, and loot tables remain resource-driven.
- Save safety: quest state dictionaries round-trip through SaveGameManager and missing quest data still normalizes to active defaults.
- Scene loadability: main project, Base scene, gameplay scene, and Scavenger scene dependencies load in Godot 4.7 headless.
- Validation health: quest, Base, save, enemy, extraction, UI, combat, and gameplay architecture validations pass.

### Verified

- `validate_quest_flow.gd`, `validate_quest_model.gd`, `validate_base_progression.gd`, `validate_base_screen.gd`, `validate_ui_foundation.gd`, `validate_save_slots.gd`, `validate_enemy_ai.gd`, `validate_enemy_loot_drop.gd`, `validate_extraction_flow.gd`, `validate_gameplay_architecture.gd`, and `validate_combat_domain.gd` pass.
- Base scene and gameplay scene startup pass Godot 4.7 headless checks.

## 2026-07-02 First Kill Quest Task

### Completed

- Extended `QuestDef` with `kill` objectives using `enemy_id` and positive quantity validation.
- Extended `QuestState` with `update_from_enemy_killed()` and stable `kill:<enemy_id>` progress keys.
- Added `data/quests/first_scavenger_hunt.tres` as the first kill quest: eliminate one Scavenger for money.
- Added `QuestKillTracker3D` as a focused enemy death listener that updates quest save progress through SaveGameManager.
- Wired `QuestKillTracker3D` into `scenes/enemies/scavenger_3d.tscn`.
- Updated BaseScreen quest display and submission to handle multiple early quest definitions, prioritizing ready quests before active quests.
- Updated `validate_quest_model.gd`, `validate_quest_flow.gd`, and `validate_enemy_ai.gd` to cover kill quest data, Scavenger scene wiring, Base submission, and duplicate kill protection.

### Rule

- Kill quest progress is saved immediately when the enemy death signal is recorded. Death or extraction after that point does not roll back kill progress.

### Verified

- Quest model validation reports `[quest_model] OK def=loads progress=extract_any kill=ready reward=claim save=round_trip`.
- Quest flow validation reports `[quest_flow] OK extraction=updates_base kill=updates_base quest=claimable reward=saved layout=fits`.
- Enemy AI validation reports `[enemy_ai] OK detect=chase attack=damages dead=stops scene=wired`.
- Base screen, save slots, enemy loot drop, extraction flow, UI foundation, gameplay architecture, combat domain, base progression, Base scene startup, gameplay scene startup, and main project startup validations pass.

### Next

- Continue with 任務二十六：完成三場 Raid Smoke Test.

## 2026-07-02 Three Raid Smoke Test Task

### Completed

- Added `tools/validate_three_raid_loop.gd` as a cross-system smoke test for three consecutive raid outcomes.
- Raid 1 simulates extraction of wood and wire, confirms stash persistence, claims First Salvage, purchases Workbench Level 1, and verifies money/material/upgrades/quest state.
- Raid 2 simulates player death with backpack loot, confirms lost items do not enter stash, and confirms money, base upgrades, and completed quests are preserved.
- Raid 3 simulates killing a Scavenger, extracting a valuable item, claiming First Scavenger Hunt, and reloading the save slot to verify persistence.
- The smoke test uses the existing SaveGameManager autoload, RaidResultApplier, BaseScreen, Scavenger scene, QuestState, and BaseProgression boundaries instead of adding a parallel test-only flow.

### Verified

- Three raid loop validation reports `[three_raid_loop] OK raid1=extract_upgrade raid2=death_preserves raid3=kill_extract reload=persistent`.
- Standard validation set passes: item catalog, UI foundation, inventory drag rules, gameplay architecture, combat domain, difficulty system, save slots, save slot panel, audio settings, pause menu, main project startup, and gameplay scene startup.
- Additional loop-adjacent validations pass: quest flow, extraction flow, base progression, enemy AI, enemy loot drop, loot tables, and base screen.

### Next

- Continue with 任務二十七：UI polish/final layout quality pass.
## 2026-07-02 UI Text Quality Task

### Completed

- Added `scripts/ui/ui_text.gd` as the shared safe text helper for player-facing UI fallback text.
- Updated BaseScreen, RaidHudPanel, and RaidResultPanel to use `UIText.text()` so missing or corrupt localization entries fall back to clean readable text.
- Updated BaseScreen and RaidResultPanel item-name display to use `UIText.item_name()`, protecting stash/result rows from corrupt item localization text.
- Added clean ASCII fallback localization rows for Base, Raid HUD, Raid Result, and Scavenger/unknown enemy UI keys.
- Bound Raid Result list section titles through localization keys instead of leaving them as static scene text.
- Added `tools/validate_ui_text_quality.gd` to verify required keys, mojibake-free rendered UI text, and 1280x720/1920x1080 fit for Base, Raid HUD, and Raid Result.

### Verified

- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- Base screen, Raid HUD, Raid Result Panel, Quest flow, and UI foundation validations pass.
- Standard validation set passes: item catalog, inventory drag rules, gameplay architecture, combat domain, difficulty system, save slots, save slot panel, audio settings, pause menu, main project startup, and gameplay scene startup.

## 2026-07-02 Project Health Check After Task Twenty-Seven

### Health Check

- Responsibility boundaries: UI text fallback is centralized in `UIText`; Base/HUD/Result scripts consume the helper and do not own localization parsing.
- UI ownership: Base, Raid HUD, Result, and Quest UI still display model/service state and emit user intent; persistent state remains in SaveGameManager and domain helpers.
- Godot node-first UI: Base, Raid HUD, and Raid Result remain `.tscn` Control/container based; this task did not move stable panels into script-created UI.
- UI layout quality: Base, Raid HUD, Raid Result, and Quest layout checks pass at 1280x720 and 1920x1080 with action buttons inside their panels.
- Data-driven content: items, quests, enemies, upgrades, and loot tables remain resource/data driven.
- Save safety: save slots, quest flow, extraction flow, base progression, and three-raid persistence validations pass.
- Scene loadability: main project and gameplay scene pass Godot 4.7 headless startup.
- Validation health: added `validate_ui_text_quality.gd`; existing standard, quest, extraction, enemy, loot, base, and three-raid validations pass.

### Technical Debt

- `scripts/base/base_screen.gd` is now about 529 lines and should be split in a future maintenance slice into focused helpers for quest display, workbench display, stash rows, and Base actions. This was not split inside the UI text task to avoid a broad refactor while all current validations pass.

### Verified

- `validate_ui_text_quality.gd`, `validate_base_screen.gd`, `validate_raid_hud.gd`, `validate_raid_result_panel.gd`, `validate_quest_flow.gd`, `validate_ui_foundation.gd`, `validate_three_raid_loop.gd`, `validate_extraction_flow.gd`, `validate_base_progression.gd`, `validate_enemy_ai.gd`, `validate_enemy_loot_drop.gd`, `validate_loot_tables.gd`, `validate_quest_model.gd`, and the Standard Validation Set pass.

### Next

- Continue with 任務二十八：早期數值調整.

## 2026-07-02 Early Balance Tuning Task

### Completed

- Tuned the early player baseline toward a more forgiving first loop: max health 110, max stamina 110, sprint stamina cost 22, and stamina recovery 24.
- Tuned Scavenger combat pressure: max health 40 so the pistol kills in two clean hits, damage 10 so the enemy threatens over repeated mistakes, detect radius 9, and move speed 3.0.
- Tuned `refuge_outskirts_common` loot pacing: wood now rolls 2-4, cash rolls 8-22, wire has higher weight, and common junk was added as vendor-trash economy filler.
- Tuned Workbench Level 1 to cost $15, 3 wood, and 2 wire so the first successful salvage route can reasonably reach the first upgrade without perfect loot.
- Tuned the gameplay extraction zone to 4.5 seconds, adding a small stay-in-zone pressure window while keeping the first map readable.
- Added `tools/validate_early_balance.gd` as the early balance guardrail for player stats, enemy pressure, loot pacing, extraction timer, and upgrade cost.
- Updated `validate_base_progression.gd` and `validate_three_raid_loop.gd` for the tuned Workbench cost and resulting money/material totals.

### Verified

- Early balance validation reports `[early_balance] OK player=forgiving enemy=readable loot=progression extraction=pressure upgrade=reachable`.
- Related validations pass: loot tables, enemy def, enemy AI, base progression, extraction flow, raid HUD, three-raid loop, combat domain, and player damage.
- Raid HUD validation still passes after the longer extraction timer.

### Notes

- This is an early automated balance pass, not final tuning. The goal is to keep a fresh three-raid loop reachable and readable before adding repeated content volume.

### Next

- Continue with 任務二十九：內容製作指南與資料擴充流程.

## 2026-07-02 Content Authoring Guide Task

### Completed

- Added `docs/design/content_authoring_guide.md` as the early content expansion rulebook before adding repeated item/enemy/quest/upgrades.
- Documented folder ownership, content workflow, required fields, authoring rules, and validation commands for `ItemDef`, `LootTableEntry`, `EnemyDef`, `QuestDef`, and `UpgradeDef`.
- Added localization requirements for item, UI, and enemy keys, including the rule that `UIText` fallback is only a safety net.
- Added a validation matrix mapping each content type to the required `tools/validate_*.gd` scripts.
- Added startup check guidance with the correct gameplay scene path: `res://scenes/gameplay/player_test_world_3d.tscn`.
- Added `tools/validate_content_authoring_guide.gd` so automation can catch missing guide sections, missing resource type coverage, missing validation commands, and missing expected project paths.

### Verified

- Content authoring guide validation reports `[content_authoring_guide] OK sections=present resources=covered validation=listed`.
- Required task validations pass: item catalog, loot tables, enemy def, and quest model.
- Additional related validations pass: base progression, UI text quality, and three-raid loop.
- Main project and gameplay scene startup checks pass.

### Notes

- This task intentionally adds no repeated content volume. It creates the rules for safe content expansion after Dev Slice 0.1 approval.

### Next

- Continue with 任務三十：Dev Slice 0.1 驗收與是否開始內容擴充判斷.

## 2026-07-02 Dev Slice 0.1 Acceptance Task

### Completed

- Added `docs/tasks/dev_slice_0_1_acceptance.md` as the final Dev Slice 0.1 acceptance report.
- Recorded the Dev Slice 0.1 approval checklist evidence for main menu, base, raid start, loot, combat, extraction, death loss, stash, money, save/load, upgrade, quest, validation, and three-raid repeatability.
- Added `tools/validate_dev_slice_acceptance.gd` so automation can verify the acceptance report, task queue state, approval gate, listed validation scripts, content authoring guide, and gameplay scene path.
- Updated `early_development_plan.md` to record that automated Dev Slice 0.1 acceptance passed while repeated content expansion remains locked until user approval.
- Marked 任務三十 complete in `automation_task_queue.md`.

### Project Health Check After Task Thirty

- Responsibility boundaries: raid result application, save persistence, quests, base progression, enemy behavior, loot tables, and UI display remain split across focused scripts/resources.
- UI ownership: Base, Raid HUD, Raid Result, save slot, settings, and pause screens read model/service state and emit user intent instead of owning persistent gameplay truth.
- Godot node-first UI: stable UI surfaces remain `.tscn` Control scenes using Godot nodes, containers, and theme/style helpers.
- UI layout quality: Base, Raid HUD, Raid Result, quest/base UI, save slot panel, pause menu, and settings validations cover readable spacing, button fit, hierarchy, and 1280x720/1920x1080 fit.
- Data-driven content: items, loot tables, enemies, quests, upgrades, localization, and authoring rules are resource or data driven.
- Save safety: extraction, death, stash, money, quest, upgrade, and reload behavior are covered by save and three-raid validations.
- Localization: UI text quality validation checks required keys and clean fallback behavior.
- Scene loadability: main project and gameplay scene load in Godot headless checks.
- Validation health: Dev Slice 0.1 now has `validate_dev_slice_acceptance.gd` as the final guardrail.

### Verified

- Dev Slice 0.1 acceptance validation reports `[dev_slice_acceptance] OK checklist=documented gate=locked validations=listed`.
- Three raid loop validation reports `[three_raid_loop] OK raid1=extract_upgrade raid2=death_preserves raid3=kill_extract reload=persistent`.
- Standard Validation Set passes: item catalog, UI foundation, inventory drag rules, gameplay architecture, combat domain, difficulty system, save slots, save slot panel, audio settings, and pause menu.
- Dev Slice 0.1 validation set passes: stash model, base screen, base flow, raid session, extraction flow, raid result panel, loot tables, loot container, enemy def, enemy AI, enemy loot drop, player damage, vendor sell, base progression, quest model, quest flow, raid HUD, UI text quality, early balance, content authoring guide, and three-raid loop.
- Main project and gameplay scene startup checks pass in Godot 4.7 headless mode.

### Gate

- Automated Dev Slice 0.1 acceptance passed.
- Repeated content expansion is locked until the user explicitly approves that this early version matches the desired direction.

### Next

- Pause numbered automation tasks after Dev Slice 0.1 completion.
- Wait for user hands-on approval before adding repeated content volume.

## 2026-07-02 Player Visibility Gate Task

### Completed

- Updated `docs/tasks/dev_slice_0_1_acceptance.md` to distinguish system validation from player-visible acceptance.
- Recorded the user's hands-on finding that only difficulty selection, extraction countdown/result transition, and loot containers are clearly visible so far.
- Added a player-visible acceptance checklist for Base, Traditional Chinese UI, Raid HUD, pistol feedback, Scavenger, damage/death, enemy drops, quests, workbench, selling, stash/money changes, and future visible-slice validation.
- Updated `early_development_plan.md` so content expansion remains locked because player-visible acceptance is still pending.
- Marked 可視化任務一 complete in `player_visibility_task_queue.md`.

### Verified

- Dev Slice acceptance validation reports `[dev_slice_acceptance] OK system=passed player_visible=pending gate=locked`.
- Base flow validation reports `[base_flow] OK new_game=base continue=base current_slot=tracked`.
- Three raid loop validation reports `[three_raid_loop] OK raid1=extract_upgrade raid2=death_preserves raid3=kill_extract reload=persistent`.
- Main project and gameplay scene startup checks pass in Godot 4.7 headless mode.

### Next

- Continue with 可視化任務二：修復繁中 UI 文字基礎.

## 2026-07-02 Traditional Chinese UI Text Visibility Task

### Completed

- Rebuilt `data/localization/game_text.csv` into a clean one-key-per-line CSV so `LocalizationBootstrap` can reliably load player-facing text.
- Replaced English `zh_TW` text for Base, Raid HUD, Raid Result, difficulty, save slots, pause, codex, inventory labels, item types, visible items, and enemy names.
- Added Traditional Chinese fallback display names/descriptions to the currently visible workbench upgrade, two starter quests, Scavenger enemy, and key visible item resources.
- Expanded `tools/validate_ui_text_quality.gd` so it now checks exact zh_TW strings for key Base/Raid/Result UI labels and catches English fallback text.
- Marked 可視化任務二 complete in `player_visibility_task_queue.md`.

### Verified

- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- CSV key uniqueness check reports `CSV keys unique: 210 rows`.
- Difficulty validation reports `[difficulty_system] OK profiles=3 health=scaled menu=available`.
- Base screen validation reports `[base_screen] OK node_first=true empty=shown stash=shown layout=fits`.
- Raid HUD validation reports `[raid_hud] OK objective=visible extraction=status ammo=visible ui_manager=compatible layout=fit`.
- Raid result panel validation reports `[raid_result_panel] OK node_first=true fake_data=shown continue=base layout=fits`.
- Save slot panel validation reports `[save_slot_panel] OK rows=3 refresh=ready`.
- Item catalog validation reports `[item_catalog] OK items=21 max_no=21`.
- Quest model validation reports `[quest_model] OK def=loads progress=extract_any kill=ready reward=claim save=round_trip`.
- Base flow validation reports `[base_flow] OK new_game=base continue=base current_slot=tracked`.
- Base progression validation reports `[base_progression] OK upgrade=data_valid cost=deducted save=persists effect=starter_ammo`.
- Three raid loop validation reports `[three_raid_loop] OK raid1=extract_upgrade raid2=death_preserves raid3=kill_extract reload=persistent`.
- Main project, Base scene, and current Raid gameplay scene load in Godot 4.7 headless checks.

### Next

- Continue with 可視化任務三：讓 Base 成為明確可辨識的基地畫面.

## 2026-07-02 Base Visibility Task

### Completed

- Updated `scenes/base/base_screen.tscn` with a node-first Base phase banner that identifies the screen as `安全區 / 基地階段`.
- Added a clear player-facing hint: `這裡不會戰鬥。確認倉庫、任務與工作台後再開始出擊。`
- Changed Base scene default text to readable Traditional Chinese so editor preview and pre-refresh text do not show English placeholders.
- Added `ui.base.phase` and `ui.base.phase_hint` localization keys and strengthened `ui.base.ready` as a next-step status.
- Updated `scripts/base/base_screen.gd` so Base fallbacks are Traditional Chinese instead of English.
- Added `scripts/base/base_screen_view_model.gd` for Base display text, quest selection, quest progress formatting, upgrade status text, enemy names, item names, and difficulty labels.
- Added `scripts/base/base_screen_stash_rows.gd` so dynamic stash row construction no longer lives in the main Base screen controller.
- Expanded `tools/validate_base_screen.gd` to check that Base is recognizable, section labels are Traditional Chinese, the phase banner is visible, and the primary action remains inside the panel at 1280x720 and 1920x1080.
- Expanded `tools/validate_ui_text_quality.gd` to require the new Base phase localization keys and check the Base phase banner in layout validation.
- Marked 可視化任務三 complete in `player_visibility_task_queue.md`.

### Project Health Check After Visibility Task Three

- Player flow reachability: `validate_base_flow.gd` confirms New Game and Continue both enter `res://scenes/base/base_screen.tscn`.
- Traditional Chinese text quality: Base title, phase banner, hint, section labels, status, and primary action are validated as Traditional Chinese; CSV keys remain unique.
- UI layout spacing and hierarchy: Base now has title, subtitle, phase banner, account row, section scroll area, status, and action row with validated 1280x720 / 1920x1080 fit.
- Godot node-first UI ownership: stable Base structure remains in `.tscn` Control/Container nodes; script-created UI is limited to dynamic stash rows and moved into a focused helper.
- Gameplay responsibility boundaries: Base display text and stash row construction were split out of `base_screen.gd`; Base UI still emits actions and does not own authoritative save/gameplay truth.
- Save safety: `validate_save_slots.gd`, `validate_base_progression.gd`, and `validate_three_raid_loop.gd` still pass.
- Scene loadability: main project, Base scene, and current Raid gameplay scene load in Godot 4.7 headless checks.
- Validation health: Base screen, Base flow, UI text quality, UI foundation, gameplay architecture, save slots, base progression, and three-raid validations pass.
- Remaining architecture note: `base_screen.gd` was reduced from 547 to 405 lines by extracting helpers; it is healthier but should continue shrinking if future Base tasks add more behavior.

### Verified

- Base screen validation reports `[base_screen] OK node_first=true base=recognizable empty=shown stash=shown layout=fits`.
- Base flow validation reports `[base_flow] OK new_game=base continue=base current_slot=tracked`.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- Save slots validation reports `[save_slots] OK slots=3 save=start load=continue schema=v1`.
- Base progression validation reports `[base_progression] OK upgrade=data_valid cost=deducted save=persists effect=starter_ammo`.
- Three raid loop validation reports `[three_raid_loop] OK raid1=extract_upgrade raid2=death_preserves raid3=kill_extract reload=persistent`.
- CSV key uniqueness check reports `CSV keys unique: 212 rows`.
- Main project, Base scene, and current Raid gameplay scene load in Godot 4.7 headless checks.

### Next

- Continue with 可視化任務四：讓 Raid Result 明確顯示戰利品與回基地流程.

## 2026-07-02 Raid Result Visibility Task

### Completed

- Updated `scenes/ui/raid_result_panel.tscn` so the stable Result layout defaults to readable Traditional Chinese text.
- Added a node-first `TransferBanner` to the Raid Result panel so players can see how loot is transferred before pressing the next action.
- Updated `scripts/ui/raid_result_panel.gd` to show a visible `物資轉移` summary for extraction, empty extraction, and death results.
- Changed Raid Result fallback text to Traditional Chinese for title, subtitle, outcome, money, list titles, empty states, unknown items, outcome names, and `回到基地`.
- Added Result localization keys for transfer summary text and death transfer status.
- Added shared `UIStyle.make_transfer_panel_style()` so the Result transfer banner does not own scattered color values.
- Rebuilt `tools/validate_raid_result_panel.gd` so it now fails if the Result panel does not visibly show extracted loot, lost loot, safe pocket state, transfer-to-base-stash text, death loss text, or the `回到基地` action.
- Expanded `tools/validate_ui_text_quality.gd` to require the new Result transfer localization keys and check the transfer banner within 1280x720 / 1920x1080 layout validation.
- Marked 可視化任務四 complete in `player_visibility_task_queue.md`.

### Verified

- Raid result panel validation reports `[raid_result_panel] OK node_first=true transfer=visible loot=shown continue=base layout=fits`.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- Extraction flow validation reports `[extraction_flow] OK countdown=works cancel=works transfer=stash_saved death=lost_items inventory=cleared scene=wired`.
- Three raid loop validation reports `[three_raid_loop] OK raid1=extract_upgrade raid2=death_preserves raid3=kill_extract reload=persistent`.
- Base screen validation reports `[base_screen] OK node_first=true base=recognizable empty=shown stash=shown layout=fits`.
- Base flow validation reports `[base_flow] OK new_game=base continue=base current_slot=tracked`.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- CSV key uniqueness check reports `CSV keys unique: 217 rows`.
- Main project, Base scene, and current Raid gameplay scene load in Godot 4.7 headless checks.

### Next

- Continue with 可視化任務五：Raid HUD 顯示玩家當下目標.

## 2026-07-02 Raid HUD Player Objective Visibility Task

### Completed

- Marked 可視化任務五 complete in `docs/tasks/player_visibility_task_queue.md`.
- Updated `scenes/ui/raid_hud_panel.tscn` so the stable HUD panel defaults to readable Traditional Chinese instead of English placeholders.
- Added node-first HUD rows for `目前目標`, route guidance, health/stamina, extraction status, and weapon/ammo.
- Updated `scripts/ui/raid_hud_panel.gd` to bind the HUD to the existing RaidSession, player vitals, WeaponController3D, and extraction zone without adding new map/content.
- Added Raid HUD localization keys for goal title, route hint, health, stamina, weapon, and missing weapon/vitals states.
- Strengthened `tools/validate_raid_hud.gd` so the task fails if the HUD only exists technically but does not show the visible player objective in Traditional Chinese.
- Expanded `tools/validate_ui_text_quality.gd` to verify the new HUD keys and visible HUD text at 1280x720 and 1920x1080.

### Verified

- Raid HUD validation reports `[raid_hud] OK objective=visible route=clear vitals=visible ammo=weapon extraction=status ui_manager=compatible layout=fit`.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- Related validations pass: extraction flow, three-raid loop, UI foundation, gameplay architecture, Base screen, and Raid result panel.
- Localization key check reports no duplicate non-empty keys in `game_text.csv`.

### Next

- Continue with 可視化任務六：讓手槍與射擊回饋可見.

## 2026-07-02 Player Visibility V2 Automation Setup

### Completed

- Added `docs/design/player_visibility_v2_direction.md` to record the corrected player-visible target: 3D Base, visible container capacity, pistol/ammo pickup, equipment, reload bar, and 3D projectiles.
- Added `docs/tasks/player_visibility_v2_task_queue.md` as the new automation queue, superseding the earlier player visibility queue for future work.
- Marked V2 任務一 complete because the corrected direction and task queue are now in the repository.
- Documented parallel work policy so automation can work non-linearly only when dependencies and file ownership do not conflict.

### Next

- Continue with V2 任務二：建立專案健康檢查基準.

## 2026-07-02 Player Visibility V2 Health Baseline

### Completed

- Added `docs/tasks/player_visibility_v2_health_audit.md` to name the current coupling debts before refactoring them.
- Documented ownership guardrails for Base, LootContainer3D, InventoryModel, EquipmentModel, WeaponController3D, ContainerInventoryUI, UIManager, and PlayerController3D.
- Added `tools/validate_player_visibility_v2_health.gd` to verify the V2 audit exists, known player-visible debts are documented, UI surface IDs are present, and InventoryModel remains independent from UI/equipment/combat/player/controller coupling.
- Marked V2 任務二 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Main project and current 3D gameplay test scene load in Godot 4.7 headless checks.

### Next

- Continue with V2 任務三：建立 3D Base 場景雛形.

## 2026-07-02 Player Visibility V2 3D Base Scene

### Completed

- Added `scenes/base/base_3d.tscn` as the first playable 3D Base shell with floor, boundary collision, player, camera, lighting, and visible placeholder Base stations.
- Added visible Traditional Chinese station labels for `倉庫`, `任務板`, `工作台`, and `出擊門` without adding final art or extra gameplay content.
- Updated difficulty selection and save defaults so new game and continue flows enter the 3D Base scene instead of the old full-screen Base panel.
- Updated V2 health audit from `missing 3D Base` to `3D Base interaction wiring pending`, because the scene now exists but interaction behavior belongs to later tasks.
- Added `tools/validate_base_3d_scene.gd` to verify Base 3D loadability, player/camera presence, boundary collision, visible interaction point markers, and Traditional Chinese labels.
- Marked V2 任務三 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Base 3D scene validation reports `[base_3d_scene] OK scene=loadable player=present camera=targeted boundaries=present points=4`.
- Base flow validation reports `[base_flow] OK new_game=base continue=base current_slot=tracked`.
- Save slots validation reports `[save_slots] OK slots=3 save=start load=continue schema=v1`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Base screen validation reports `[base_screen] OK node_first=true base=recognizable empty=shown stash=shown layout=fits`.
- Main project and new `res://scenes/base/base_3d.tscn` load in Godot 4.7 headless checks.

### Next

- Continue with V2 任務四：建立 Base 互動點.

## 2026-07-02 Project Health Check After V2 Task Three

### Health Check

- Player flow reachability: V2 flow enters `res://scenes/base/base_3d.tscn` through new game and continue validation.
- 3D Base vs 2D panel responsibility: 3D Base owns the world shell and station placement; old `BaseScreen` remains available for later panel reuse and is not embedded as the whole Base scene.
- Inventory/equipment/weapon boundaries: no inventory, equipment, ammo, or weapon ownership changed in V2 task three.
- Container inventory boundary: unchanged; direct container-to-backpack grant remains documented as V2 debt.
- UIManager and UI ownership: unchanged; top menu panel debt remains documented until the relevant V2 tasks.
- Traditional Chinese text quality: Base station labels are Traditional Chinese and validated in `validate_base_3d_scene.gd`.
- Scene loadability and validation health: Base 3D, base flow, save slots, V2 health, gameplay architecture, UI foundation, and main startup validations pass.

## 2026-07-02 Player Visibility V2 Base Interaction Points

### Completed

- Added `scripts/base/base_interaction_controller_3d.gd` so 3D Base proximity prompts and E-key interaction are owned by a Base controller instead of PlayerController3D.
- Added node-first `scenes/base/base_interaction_panel.tscn` with `scripts/base/base_interaction_panel.gd` for visible Traditional Chinese station panels.
- Wired `base_3d.tscn` so `倉庫`, `任務板`, `工作台`, and `出擊門` show a nearby prompt; station panels open for the first three and the raid gate starts the existing raid scene.
- Added `tools/validate_base_interactions.gd` to verify prompts, panel visibility, Traditional Chinese station text, and raid start target.
- Marked V2 任務四 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Base interaction validation reports `[base_interactions] OK prompt=visible panels=connected raid=startable text=zh`.
- Base 3D scene validation reports `[base_3d_scene] OK scene=loadable player=present camera=targeted boundaries=present points=4`.
- Base flow validation reports `[base_flow] OK new_game=base continue=base current_slot=tracked`.
- Save slots validation reports `[save_slots] OK slots=3 save=start load=continue schema=v1`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- New `res://scenes/base/base_3d.tscn` loads in Godot 4.7 headless checks.

### Next

- Continue with V2 任務五：拆分舊 BaseScreen 職責.

## 2026-07-02 Player Visibility V2 BaseScreen Responsibility Split

### Completed

- Added `scripts/base/base_screen_actions.gd` as the BaseScreen action boundary for vendor/sell action rules.
- Updated `scripts/base/base_screen.gd` so it no longer directly preloads `StashVendor`; BaseScreen now delegates display text, stash row construction, and sell action rules to focused helpers.
- Added `tools/validate_base_screen_responsibilities.gd` to guard BaseScreen boundaries, confirm Base3D does not embed the old full BaseScreen, and confirm base flow validation targets the 3D Base scene.
- Marked V2 任務五 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- BaseScreen responsibility validation reports `[base_screen_responsibilities] OK display=view_model stash=helper actions=helper base3d=separate`.
- Base screen validation reports `[base_screen] OK node_first=true base=recognizable empty=shown stash=shown layout=fits`.
- Base flow validation reports `[base_flow] OK new_game=base continue=base current_slot=tracked`.
- Vendor sell validation reports `[vendor_sell] OK value=item_def stash=removes_sold money=saved materials=kept`.
- Quest flow validation reports `[quest_flow] OK extraction=updates_base kill=updates_base quest=claimable reward=saved layout=fits`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- Main project loads in Godot 4.7 headless checks.
- Main project and `res://scenes/base/base_3d.tscn` load in Godot 4.7 headless checks.

### Next

- Continue with V2 任務六：建立 ContainerInventoryModel.

## 2026-07-02 Player Visibility V2 ContainerInventoryModel

### Completed

- Added `scripts/inventory/container_inventory_model.gd` as an independent fixed-slot container inventory model.
- Supports container capacity, visible slot dictionaries, stack merging, partial/full removal, clearing, and save/load round trips.
- Keeps container inventory separate from player backpack, LootContainer3D, WeaponController, UIManager, and Control/scene code.
- Added `tools/validate_container_inventory_model.gd` to guard capacity, stacking, transactional rejection when full, removal, serialization, invalid save entries, and responsibility boundaries.
- Marked V2 任務六 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Container inventory model validation reports `[container_inventory_model] OK capacity=slots stack=merge remove=works save=round_trip coupling=clean`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- Main project loads in Godot 4.7 headless checks.

### Next

- Continue with V2 任務七：建立箱子內容 UI.

## 2026-07-02 Project Health Check Before V2 Task Seven

### Health Check

- Player flow reachability: current V2 Base and raid flow checks remain covered by existing Base and startup validations.
- 3D Base vs 2D panel responsibility: unchanged; 3D Base remains the playable space and old BaseScreen remains a panel/helper surface.
- Inventory/equipment/weapon boundaries: ContainerInventoryModel remains separate from player backpack and weapon/equipment state.
- Container inventory boundary: `validate_container_inventory_model.gd` confirms fixed-slot container state is UI-independent.
- UIManager ownership: unchanged this slice; ContainerInventoryUI is only a reusable panel and does not own global UI focus routing yet.
- Traditional Chinese text quality: `validate_ui_text_quality.gd` passes before adding the new panel.
- Scene loadability and validation health: V2 health, container model, UI text quality, and main startup validations pass.

## 2026-07-02 Player Visibility V2 Container Inventory UI

### Completed

- Added node-first `scenes/ui/container_inventory_ui.tscn` with a dimmer, panel, header, capacity label, help text, scroll/grid area, empty state, and close button.
- Added `scripts/ui/container_inventory_ui.gd` to bind a `ContainerInventoryModel`, display container name, show used/capacity like `2/4`, generate one visible slot per capacity, and emit slot intent without owning loot rolling or player backpack transfer.
- Added `tools/validate_container_inventory_ui.gd` to verify node-first structure, visible capacity, visible slots, Traditional Chinese text, responsibility boundaries, and 1280x720 / 1920x1080 fit.
- Marked V2 任務七 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Container inventory UI validation reports `[container_inventory_ui] OK panel=node_first capacity=visible slots=visible layout=fits text=zh`.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- Container inventory model validation reports `[container_inventory_model] OK capacity=slots stack=merge remove=works save=round_trip coupling=clean`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Main project loads in Godot 4.7 headless checks.

### Next

- Continue with V2 任務八：改造箱子開啟流程.

## 2026-07-02 Player Visibility V2 Container Open Flow

### Completed

- Updated `LootContainer3D` so opening a container now generates and holds a `ContainerInventoryModel` instead of directly granting all rolled loot to the player backpack.
- Added `UIManager.open_container_inventory()` and `UI_CONTAINER` state so active container UI, mouse focus, and action blocking are owned by UIManager.
- Wired `ContainerInventoryUI` into the gameplay HUD so normal raid play can open the visible container panel.
- Updated `validate_loot_container.gd` from the old direct-grant expectation to the new container-owned inventory expectation.
- Added `tools/validate_container_open_flow.gd` to verify a gameplay scene container opens the visible UI through UIManager.
- Updated V2 health audit and validation so the direct container-to-backpack grant is now treated as removed debt.
- Marked V2 任務八 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Container open flow validation reports `[container_open_flow] OK interaction=opens_ui contents=container_owned ui_manager=owner`.
- Loot container validation reports `[loot_container] OK roll=container_inventory one_shot=no_reroll map=spawn_loot_extract ui_coupling=clean scene=wired`.
- Container inventory UI validation reports `[container_inventory_ui] OK panel=node_first capacity=visible slots=visible layout=fits text=zh`.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- Main project loads in Godot 4.7 headless checks.

### Next

- Continue with V2 任務九：箱子物品轉移到背包.

## 2026-07-02 Player Visibility V2 Container Transfer

### Completed

- Wired `ContainerInventoryUI.slot_pressed` into `UIManager` so clicking a visible container slot transfers that stack to the player backpack.
- Kept `ContainerInventoryUI` as a node-first display/intent panel; transfer coordination now lives in `UIManager`.
- Added visible Traditional Chinese transfer feedback for success, empty slots, unavailable transfer state, and full backpack state.
- Preserved the corrected container flow: `LootContainer3D` opens/owns container contents and no longer silently grants all loot to the backpack.
- Added `tools/validate_container_transfer.gd` to prove normal gameplay can open a container, click a slot, update container/backpack capacity, and show full-backpack feedback.
- Marked V2 任務九 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Container transfer validation reports `[container_transfer] OK click=moves_to_backpack full=feedback boundaries=clean`.
- Container open flow validation reports `[container_open_flow] OK interaction=opens_ui contents=container_owned ui_manager=owner`.
- Container inventory UI validation reports `[container_inventory_ui] OK panel=node_first capacity=visible slots=visible layout=fits text=zh`.
- Loot container validation reports `[loot_container] OK roll=container_inventory one_shot=no_reroll map=spawn_loot_extract ui_coupling=clean scene=wired`.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.

### Project Health Check After V2 Task Nine

- Player flow reachability: normal raid gameplay can open a visible loot container and click a slot to move loot into the player backpack.
- Inventory/container boundary: `ContainerInventoryModel` still owns container slots, `InventoryModel` still owns player backpack stacks, and `UIManager` is the bridge for player intent.
- UI boundary: `ContainerInventoryUI` displays capacity, slots, and status text but does not search for Player, roll loot, or mutate backpack state directly.
- Loot boundary: `LootContainer3D` still opens/holds container contents and does not write directly to `InventoryEquipmentUI` or `InventoryModel`.
- UI layout quality: container panel remains node-first, stable at 1280x720 and 1920x1080, and all visible transfer feedback is Traditional Chinese.
- Validation health: transfer, open flow, UI, loot container, text quality, and V2 health validations pass.

### Next

- Continue with V2 任務十：把 No.5 手槍與 No.7 子彈放入早期箱子.

## 2026-07-02 Player Visibility V2 Early Pistol And Ammo Container

### Completed

- Added `guaranteed_entries` support to `LootTable` so early proof items can be data-authored without hard-coding them into player, UI, or container scripts.
- Updated `data/loot_tables/refuge_outskirts_common.tres` so early loot containers always include No.5 `手槍-S` and No.7 `彈藥-S`, then roll the existing small common loot set.
- Kept the scope narrow: no new weapon list, no new map, no new enemy, and no final art.
- Strengthened `tools/validate_loot_tables.gd` to require the guaranteed No.5 pistol and No.7 ammo entries and prove rolled loot contains both.
- Strengthened `tools/validate_container_transfer.gd` to open the gameplay container UI and verify the visible slot text matches the item catalog names for No.5 and No.7.
- Strengthened `tools/validate_item_catalog.gd` to guard No.5 as `pistol_9mm` / `手槍-S` and No.7 as `ammo_9mm` / `彈藥-S`.
- Marked V2 任務十 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Loot table validation reports `[loot_tables] OK common=valid roll=stacks invalid=caught empty=caught`.
- Container transfer validation reports `[container_transfer] OK click=moves_to_backpack full=feedback boundaries=clean`.
- Item catalog validation reports `[item_catalog] OK items=21 max_no=21`.
- Loot container validation reports `[loot_container] OK roll=container_inventory one_shot=no_reroll map=spawn_loot_extract ui_coupling=clean scene=wired`.
- Container open flow validation reports `[container_open_flow] OK interaction=opens_ui contents=container_owned ui_manager=owner`.
- Container inventory UI validation reports `[container_inventory_ui] OK panel=node_first capacity=visible slots=visible layout=fits text=zh`.
- Early balance validation reports `[early_balance] OK player=forgiving enemy=readable loot=progression extraction=pressure upgrade=reachable`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.

### Next

- Continue with V2 任務十一：建立 EquipmentModel.

## 2026-07-02 Player Visibility V2 EquipmentModel

### Completed

- Added `scripts/equipment/equipment_model.gd` as the standalone equipment domain model.
- Added equipment slots for primary weapon, sidearm, melee, helmet, armor, glasses, headset, backpack, and two charm slots.
- Added slot legality checks so pistol/gun, melee weapon, helmet, armor, and backpack items only enter valid equipment slots.
- Added equip, equip-from-stack, unequip, slot inspection, equipped item lookup, and save/load round-trip support.
- Kept `EquipmentModel` independent from UI, player controller, loot containers, weapon controller, and save services.
- Updated the V2 health audit so the previous missing EquipmentModel debt is now recorded as resolved in V2 task eleven.
- Added `tools/validate_equipment_model.gd` and strengthened `tools/validate_player_visibility_v2_health.gd` to guard the new model boundary.
- Marked V2 任務十一 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Equipment model validation reports `[equipment_model] OK slots=ready equip=legal reject=invalid save=round_trip coupling=clean`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- Item catalog validation reports `[item_catalog] OK items=21 max_no=21`.

### Next

- Continue with V2 任務十二：背包物品可裝備.

## 2026-07-02 Player Visibility V2 Backpack Equip Flow

### Completed

- Connected `PlayerController3D` to the existing `EquipmentModel` so the player now owns a separate equipment state beside the backpack inventory.
- Added `can_equip_inventory_stack`, `equip_inventory_stack`, and default slot selection so No.5 `手槍-S` moves from backpack into the sidearm slot without coupling `InventoryModel` to UI or combat.
- Added a visible right-click `裝備` action to `InventoryContextMenu`; it is enabled for valid gear and disabled for non-equipment stacks.
- Updated `InventoryEquipmentUI` to display equipped item labels in the equipment panel, expose a stable UI equip API, and report display state for player-visible validation.
- Added localization key `ui.inventory.equip`.
- Added `tools/validate_inventory_equipment_flow.gd` to prove visible backpack-to-equipment flow, ammo rejection, layout fit, and ownership boundaries.
- Marked V2 任務十二 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Inventory equipment flow validation reports `[inventory_equipment_flow] OK backpack=visible equip=sidearm ammo=rejected layout=fit boundaries=clean`.
- Equipment model validation reports `[equipment_model] OK slots=ready equip=legal reject=invalid save=round_trip coupling=clean`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Gameplay scene launch check completed with Godot headless `--quit-after 1 res://scenes/gameplay/player_test_world_3d.tscn`.

### Project Health Check After V2 Task Twelve

- Player/equipment boundary: `PlayerController3D` coordinates moving a stack from `InventoryModel` into `EquipmentModel`; the data models do not reference UI or combat.
- Inventory boundary: `InventoryModel` remains a generic backpack stack model and does not know about equipment, weapons, players, or UI.
- Equipment boundary: `EquipmentModel` remains data-only and validation still rejects UI/player/combat/save-service coupling.
- UI boundary: `InventoryEquipmentUI` shows and requests equipment actions, but equipment legality and mutation stay on the player/equipment side.
- UI layout quality: inventory panel preview fits 1280x720 and 1920x1080 through the new validation path; visible equip action uses Traditional Chinese text.
- Validation health: new flow validation, equipment model validation, gameplay architecture validation, V2 health validation, and scene launch check pass.

### Next

- Continue with V2 任務十三：解除玩家預設手槍耦合.

## 2026-07-03 Player Visibility V2 Weapon Equipment Binding

### Completed

- Removed the hardwired No.5 pistol reference from `scenes/player/player_3d.tscn`, so the player no longer starts with an always-ready weapon.
- Added an explicit unarmed state to `WeaponController3D`; firing is blocked with `no_weapon` when no weapon is equipped.
- Added small weapon binding APIs on `WeaponController3D`: `equip_weapon`, `clear_weapon`, and `has_weapon`.
- Updated `PlayerController3D` to sync the current primary/sidearm item from `EquipmentModel` into `WeaponController3D` whenever equipment changes.
- Preserved responsibility boundaries: `WeaponController3D` does not read backpack UI or `InventoryModel`; `PlayerController3D` bridges player-owned equipment to the combat controller.
- Updated the V2 health audit and health validator so the removed hardwired pistol cannot return silently.
- Added `tools/validate_weapon_equipment_binding.gd`.
- Marked V2 任務十三 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Weapon/equipment binding validation reports `[weapon_equipment_binding] OK start=unarmed equip=pistol_sync hud=visible boundaries=clean`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Combat domain validation reports `[combat_domain] OK damageable=works weapon=ammo_cooldown_damage scene=has_target`.
- Inventory equipment flow validation reports `[inventory_equipment_flow] OK backpack=visible equip=sidearm ammo=rejected layout=fit boundaries=clean`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- Base progression validation reports `[base_progression] OK upgrade=data_valid cost=deducted save=persists effect=starter_ammo`.

### Next

- Continue with V2 任務十四：建立 Ammo/Magazine 裝彈資料.

## 2026-07-03 Player Visibility V2 Ammo Magazine Model

### Completed

- Added ammo/magazine metadata to `ItemDef` and item stacks: magazine capacity, compatible ammo tags, and ammo tag.
- Updated No.5 `手槍-S` with 8-round magazine capacity and 9mm compatibility.
- Updated No.7 `彈藥-S` as 9mm ammo data.
- Added `scripts/combat/weapon_ammo_model.gd` as the focused combat data model for weapon capacity, loaded ammo, reserve ammo, compatible ammo, reload movement, and round consumption.
- Updated `WeaponController3D` so reload and firing consume ammo through `WeaponAmmoModel` while keeping `current_ammo` and `reserve_ammo` as temporary HUD/legacy bridge fields.
- Updated Workbench starter ammo validation so the old hidden 24-round starter reserve pile does not return; Workbench Level 1 now validates only its +1 reserve ammo effect.
- Updated V2 health audit/validation to guard the Ammo/Magazine model boundary.
- Updated Raid HUD validation so the V2-correct initial state is `未裝備` instead of the old hardwired pistol.
- Added `tools/validate_ammo_reload_model.gd`.
- Marked V2 任務十四 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Ammo reload model validation reports `[ammo_reload_model] OK data=pistol_9mm model=reload_consume controller=model_bound boundaries=clean`.
- Combat domain validation reports `[combat_domain] OK damageable=works weapon=ammo_cooldown_damage scene=has_target`.
- Base progression validation reports `[base_progression] OK upgrade=data_valid cost=deducted save=persists effect=starter_ammo`.
- Weapon/equipment binding validation reports `[weapon_equipment_binding] OK start=unarmed equip=pistol_sync hud=visible boundaries=clean`.
- Raid HUD validation reports `[raid_hud] OK objective=visible route=clear vitals=visible ammo=weapon extraction=status ui_manager=compatible layout=fit`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Gameplay scene launch check completed with Godot headless `--quit-after 1 res://scenes/gameplay/player_test_world_3d.tscn`.

### Next

- Continue with V2 任務十五：R 鍵裝填.

## 2026-07-03 Player Visibility V2 R Key Reload

### Completed

- Added `WeaponController3D` reload result signals/state: `reloaded`, `reload_blocked`, and `last_reload_result`.
- Added `WeaponController3D.reload_from_item()` so combat can load compatible ammo without reading backpack or UI state directly.
- Added `InventoryModel.consume_stack_quantity()` for partial stack consumption owned by the inventory data model.
- Updated `PlayerController3D` so pressing `R` requests reload on the equipped weapon, finds compatible No.7 ammo in the backpack, consumes only loaded rounds, and emits reload feedback.
- Added `tools/validate_reload_flow.gd` to verify no-weapon blocking, no-compatible-ammo blocking, R-key reload, backpack ammo consumption, HUD ammo update, and ownership boundaries.
- Added the reload flow validator to the V2 health required-file set.
- Marked V2 任務十五 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Reload flow validation reports `[reload_flow] OK r_key=bound backpack_ammo=consumed magazine=updated boundaries=clean`.
- Ammo reload model validation reports `[ammo_reload_model] OK data=pistol_9mm model=reload_consume controller=model_bound boundaries=clean`.
- Weapon/equipment binding validation reports `[weapon_equipment_binding] OK start=unarmed equip=pistol_sync hud=visible boundaries=clean`.
- Inventory equipment flow validation reports `[inventory_equipment_flow] OK backpack=visible equip=sidearm ammo=rejected layout=fit boundaries=clean`.
- Combat domain validation reports `[combat_domain] OK damageable=works weapon=ammo_cooldown_damage scene=has_target`.
- Raid HUD validation reports `[raid_hud] OK objective=visible route=clear vitals=visible ammo=weapon extraction=status ui_manager=compatible layout=fit`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Gameplay scene launch check completed with Godot headless `--quit-after 1 res://scenes/gameplay/player_test_world_3d.tscn`.

### Project Health Check After V2 Task Fifteen

- Base boundary: unchanged in this slice; no Base scene or flow code was touched.
- Inventory boundary: `InventoryModel` owns generic partial stack consumption and still has no combat, UI, equipment, loot-container, or player references.
- Equipment boundary: equipped weapon selection remains in `EquipmentModel`/`PlayerController3D`; weapon legality was not moved into UI.
- Weapon boundary: `WeaponController3D` owns reload results and ammo movement inside the combat model, but still does not read backpack/UI directly.
- Player boundary: `PlayerController3D` coordinates player input and bridges player-owned backpack/equipment to weapon reload through narrow APIs.
- UI boundary and layout: no stable UI was hardcoded; player-visible success is the existing HUD ammo count updating after R reload.
- Validation health: new reload flow, ammo model, equipment binding, inventory equipment, combat domain, HUD, gameplay architecture, V2 health, and scene launch checks pass.

### Next

- Continue with V2 任務十六：空彈左鍵自動裝填.

## 2026-07-03 Player Visibility V2 Empty Fire Auto Reload

### Completed

- Updated `PlayerController3D` so a left-click fire request checks for an empty equipped weapon before firing.
- When the equipped weapon is empty and the backpack has compatible No.7 ammo, the left click now triggers `reload_equipped_weapon(&"empty_fire")`.
- The empty left click returns after reload, so that same click does not also fire a shot or consume one of the newly loaded rounds.
- Added a reload feedback `source` field so validators and later UI can distinguish manual `R` reload from empty-fire auto reload.
- Expanded `tools/validate_reload_flow.gd` to verify empty-left-click auto reload, no same-click shot, backpack ammo consumption, HUD ammo update, and ownership boundaries.
- Marked V2 任務十六 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Reload flow validation reports `[reload_flow] OK r_key=bound empty_fire=auto_reload backpack_ammo=consumed magazine=updated boundaries=clean`.
- Ammo reload model validation reports `[ammo_reload_model] OK data=pistol_9mm model=reload_consume controller=model_bound boundaries=clean`.
- Weapon/equipment binding validation reports `[weapon_equipment_binding] OK start=unarmed equip=pistol_sync hud=visible boundaries=clean`.
- Combat domain validation reports `[combat_domain] OK damageable=works weapon=ammo_cooldown_damage scene=has_target`.
- Raid HUD validation reports `[raid_hud] OK objective=visible route=clear vitals=visible ammo=weapon extraction=status ui_manager=compatible layout=fit`.
- Inventory equipment flow validation reports `[inventory_equipment_flow] OK backpack=visible equip=sidearm ammo=rejected layout=fit boundaries=clean`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Gameplay scene launch check completed with Godot headless `--quit-after 1 res://scenes/gameplay/player_test_world_3d.tscn`.

### Next

- Continue with V2 任務十七：建立裝填時間條 UI.

## 2026-07-03 Player Visibility V2 Reload Progress UI

### Completed

- Converted player reload from instant completion into a short timed reload state owned by `PlayerController3D`.
- Added `reload_progress_changed`, `get_reload_state()`, `reload_duration_seconds`, and active reload state tracking so UI can display progress without owning ammo mutation.
- Reload now consumes backpack ammo and updates the weapon magazine only after progress completes.
- Firing is blocked while reload is active, preserving the empty-fire auto reload behavior from 任務十六.
- Added node-first HUD reload UI to `scenes/ui/raid_hud_panel.tscn`: `ReloadLabel` and `ReloadProgress`.
- Updated `RaidHudPanel` to bind player reload progress, show `裝填中` progress, briefly show completion/cancel status, and then clear the UI.
- Added `tools/validate_reload_ui.gd` and added it to V2 health validation.
- Updated `tools/validate_reload_flow.gd` so R reload and empty-fire auto reload wait for timed completion.
- Marked V2 任務十七 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Reload UI validation reports `[reload_ui] OK node_first=progress_bar visible=reload_progress completion=clears layout=fit boundaries=clean`.
- Reload flow validation reports `[reload_flow] OK r_key=bound empty_fire=auto_reload backpack_ammo=consumed magazine=updated boundaries=clean`.
- Raid HUD validation reports `[raid_hud] OK objective=visible route=clear vitals=visible ammo=weapon extraction=status ui_manager=compatible layout=fit`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Weapon/equipment binding validation reports `[weapon_equipment_binding] OK start=unarmed equip=pistol_sync hud=visible boundaries=clean`.
- Combat domain validation reports `[combat_domain] OK damageable=works weapon=ammo_cooldown_damage scene=has_target`.
- Inventory equipment flow validation reports `[inventory_equipment_flow] OK backpack=visible equip=sidearm ammo=rejected layout=fit boundaries=clean`.
- Ammo reload model validation reports `[ammo_reload_model] OK data=pistol_9mm model=reload_consume controller=model_bound boundaries=clean`.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- Gameplay scene launch check completed with Godot headless `--quit-after 1 res://scenes/gameplay/player_test_world_3d.tscn`.

### Next

- Continue with V2 任務十八：射擊生成可見 3D 子彈.

## 2026-07-03 Player Visibility V2 Visible Projectile

### Completed

- Added `scripts/combat/projectile_3d.gd` as a combat-only visible projectile with movement, lifetime, hit detection, and damage application.
- Added `scenes/combat/projectile_3d.tscn` with a simple 3D mesh and collision shape so fired bullets are visible in the world.
- Updated `WeaponController3D.fire_forward()` to spawn the projectile scene instead of doing direct player-fire hitscan.
- Updated `PlayerController3D` so left-click firing uses a camera-to-world aim direction and launches the projectile from the weapon/player position.
- Added `tools/validate_projectile_3d.gd` to catch invisible bullets, missing projectile scene pieces, returned hitscan behavior, and projectile coupling with inventory/UI/player systems.
- Updated V2 health audit and validation so the old hitscan debt is now recorded as resolved and guarded.
- Marked V2 任務十八 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Projectile validation reports `[projectile_3d] OK scene=visible spawn=moving hit=damages hitscan=removed boundaries=clean`.
- Combat domain validation reports `[combat_domain] OK damageable=works weapon=ammo_cooldown_damage scene=has_target`.
- Ammo reload model validation reports `[ammo_reload_model] OK data=pistol_9mm model=reload_consume controller=model_bound boundaries=clean`.
- Weapon/equipment binding validation reports `[weapon_equipment_binding] OK start=unarmed equip=pistol_sync hud=visible boundaries=clean`.
- Reload flow validation reports `[reload_flow] OK r_key=bound empty_fire=auto_reload backpack_ammo=consumed magazine=updated boundaries=clean`.
- Reload UI validation reports `[reload_ui] OK node_first=progress_bar visible=reload_progress completion=clears layout=fit boundaries=clean`.
- Raid HUD validation reports `[raid_hud] OK objective=visible route=clear vitals=visible ammo=weapon extraction=status ui_manager=compatible layout=fit`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- Gameplay scene launch check completed with Godot headless `--quit-after 1 res://scenes/gameplay/player_test_world_3d.tscn`.

### Project Health Check After V2 Task Eighteen

- Base boundary: unchanged in this slice; no Base scene or flow code was touched.
- Inventory and equipment boundaries: unchanged; projectile and weapon code do not read backpack UI, container UI, or equipment internals.
- Weapon boundary: `WeaponController3D` owns firing and projectile spawning; it no longer uses direct `intersect_ray()` hitscan for player forward fire.
- Projectile boundary: `Projectile3D` owns travel, lifetime, hit resolution, and damage application while staying independent from `InventoryModel`, `EquipmentModel`, `UIManager`, and `PlayerController3D`.
- Player boundary: `PlayerController3D` only chooses player-facing aim direction and asks the weapon controller to fire.
- UI and layout: no new stable UI was introduced; existing reload HUD and raid HUD layout validators still pass.
- Validation health: projectile, combat, reload, HUD, UI text, gameplay architecture, V2 health, and scene launch checks pass.

### Next

- Continue with V2 任務十九：Projectile 命中處理.

## 2026-07-03 Player Visibility V2 Projectile Hit Feedback

### Completed

- Added `scripts/combat/projectile_hit_feedback_3d.gd` as a short-lived combat visual feedback node.
- Added `scenes/combat/projectile_hit_feedback_3d.tscn` with a simple visible 3D mesh placeholder for hit confirmation.
- Updated `Projectile3D` so successful damage hits spawn feedback near the hit position before the projectile disappears.
- Added `tools/validate_projectile_hit.gd` to verify damage application, projectile cleanup, visible hit feedback, feedback cleanup, and clean combat-only boundaries.
- Added projectile hit feedback files and validation to V2 health required paths.
- Marked V2 任務十九 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Projectile hit validation reports `[projectile_hit] OK damage=applied projectile=removed feedback=visible boundaries=clean`.
- Projectile validation reports `[projectile_3d] OK scene=visible spawn=moving hit=damages hitscan=removed boundaries=clean`.
- Combat domain validation reports `[combat_domain] OK damageable=works weapon=ammo_cooldown_damage scene=has_target`.
- Ammo reload model validation reports `[ammo_reload_model] OK data=pistol_9mm model=reload_consume controller=model_bound boundaries=clean`.
- Weapon/equipment binding validation reports `[weapon_equipment_binding] OK start=unarmed equip=pistol_sync hud=visible boundaries=clean`.
- Reload flow validation reports `[reload_flow] OK r_key=bound empty_fire=auto_reload backpack_ammo=consumed magazine=updated boundaries=clean`.
- Reload UI validation reports `[reload_ui] OK node_first=progress_bar visible=reload_progress completion=clears layout=fit boundaries=clean`.
- Raid HUD validation reports `[raid_hud] OK objective=visible route=clear vitals=visible ammo=weapon extraction=status ui_manager=compatible layout=fit`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Gameplay scene launch check completed with Godot headless `--quit-after 1 res://scenes/gameplay/player_test_world_3d.tscn`.

### Next

- Continue with V2 任務二十：Projectile 未命中處理.

## 2026-07-03 Player Visibility V2 Projectile Miss Cleanup

### Completed

- Updated `Projectile3D` so colliding with non-damageable world geometry finishes as a miss instead of passing through.
- Kept projectile max-distance and lifetime cleanup as the fallback for shots that do not collide with anything.
- Expanded `tools/validate_projectile_3d.gd` to verify wall collision cleanup, range cleanup, `projectile_missed` signaling, miss result recording, and combat-only boundaries.
- Stabilized `tools/validate_projectile_hit.gd` cleanup timing by waiting on a real timer for short-lived hit feedback.
- Marked V2 任務二十 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Projectile validation reports `[projectile_3d] OK scene=visible spawn=moving hit=damages miss=cleans_up hitscan=removed boundaries=clean`.
- Projectile hit validation reports `[projectile_hit] OK damage=applied projectile=removed feedback=visible boundaries=clean`.
- Combat domain validation reports `[combat_domain] OK damageable=works weapon=ammo_cooldown_damage scene=has_target`.
- Ammo reload model validation reports `[ammo_reload_model] OK data=pistol_9mm model=reload_consume controller=model_bound boundaries=clean`.
- Weapon/equipment binding validation reports `[weapon_equipment_binding] OK start=unarmed equip=pistol_sync hud=visible boundaries=clean`.
- Reload flow validation reports `[reload_flow] OK r_key=bound empty_fire=auto_reload backpack_ammo=consumed magazine=updated boundaries=clean`.
- Reload UI validation reports `[reload_ui] OK node_first=progress_bar visible=reload_progress completion=clears layout=fit boundaries=clean`.
- Raid HUD validation reports `[raid_hud] OK objective=visible route=clear vitals=visible ammo=weapon extraction=status ui_manager=compatible layout=fit`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Gameplay scene launch check completed with Godot headless `--quit-after 1 res://scenes/gameplay/player_test_world_3d.tscn`.

### Next

- Continue with V2 任務二十一：射擊回饋 HUD.

## 2026-07-03 Player Visibility V2 Shooting Feedback HUD

### Completed

- Added a node-first `WeaponStatusLabel` to the Raid HUD so weapon state is visible beside ammo and reload feedback.
- Updated `RaidHudPanel` to show `戰鬥狀態` from existing player reload and weapon controller state without mutating inventory, equipment, or ammo data.
- Added Traditional Chinese localization for `未裝備`, `空彈`, `裝填中`, `可射擊`, and `射擊間隔`.
- Added `tools/validate_shooting_feedback_hud.gd` to verify the four player-readable shooting states in the real gameplay scene.
- Expanded Raid HUD, reload UI, and V2 health validators to include the new shooting feedback HUD path.
- Marked V2 任務二十一 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Shooting feedback HUD validation reports `[shooting_feedback_hud] OK status=unarmed_empty_ready_reloading node_first=true zh_tw=true boundaries=clean`.
- Raid HUD validation reports `[raid_hud] OK objective=visible route=clear vitals=visible ammo=weapon extraction=status ui_manager=compatible layout=fit`.
- Reload UI validation reports `[reload_ui] OK node_first=progress_bar visible=reload_progress completion=clears layout=fit boundaries=clean`.
- Weapon/equipment binding validation reports `[weapon_equipment_binding] OK start=unarmed equip=pistol_sync hud=visible boundaries=clean`.
- Ammo reload model validation reports `[ammo_reload_model] OK data=pistol_9mm model=reload_consume controller=model_bound boundaries=clean`.
- Reload flow validation reports `[reload_flow] OK r_key=bound empty_fire=auto_reload backpack_ammo=consumed magazine=updated boundaries=clean`.
- Projectile validation reports `[projectile_3d] OK scene=visible spawn=moving hit=damages miss=cleans_up hitscan=removed boundaries=clean`.
- Projectile hit validation reports `[projectile_hit] OK damage=applied projectile=removed feedback=visible boundaries=clean`.
- Combat domain validation reports `[combat_domain] OK damageable=works weapon=ammo_cooldown_damage scene=has_target`.
- Gameplay scene launch check completed with Godot headless `--quit-after 1 res://scenes/gameplay/player_test_world_3d.tscn`.

### Project Health Check After V2 Task Twenty One

- Base boundary: unchanged in this slice; Base 3D and Base flow code were not touched.
- Inventory and equipment boundaries: unchanged; HUD does not consume backpack stacks, equip items, or read container models.
- Weapon boundary: `WeaponController3D` remains the source of weapon presence, ammo counts, fire block reason, reload data, and projectile firing.
- Player boundary: `PlayerController3D` remains the source of timed reload state exposed through `get_reload_state()` and `reload_progress_changed`.
- UI boundary: `RaidHudPanel` only reads state and formats Traditional Chinese player feedback through node-first Control children.
- UI layout: Raid HUD still passes 1280x720 and 1920x1080 fit checks with the added status row.
- Validation health: shooting HUD, raid HUD, reload UI, combat, projectile, architecture, V2 health, UI text, and scene launch checks pass.

### Next

- Continue with V2 任務二十二：修正 Raid HUD 大面板問題.

## 2026-07-03 Player Visibility V2 Compact Raid HUD

### Completed

- Reduced `RaidHudPanel` from a large panel-like block to a compact 380x152 top-left combat summary.
- Kept the core visible HUD information: current objective, raid status, health/stamina, weapon ammo, weapon combat state, reload feedback, and extraction status.
- Hid the long route hint from the main HUD so detailed task text can move into the Top Menu quest tab in the next task.
- Changed extraction progress to stay hidden until extraction begins, reducing idle HUD footprint.
- Tightened `validate_raid_hud.gd` so it now catches oversized HUD layouts, visible long route hints, and always-visible extraction progress.
- Marked V2 任務二十二 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Raid HUD validation reports `[raid_hud] OK objective=visible route=clear vitals=visible ammo=weapon extraction=status ui_manager=compatible layout=fit`.
- Reload UI validation reports `[reload_ui] OK node_first=progress_bar visible=reload_progress completion=clears layout=fit boundaries=clean`.
- Shooting feedback HUD validation reports `[shooting_feedback_hud] OK status=unarmed_empty_ready_reloading node_first=true zh_tw=true boundaries=clean`.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Gameplay scene launch check completed with Godot headless `--quit-after 1 res://scenes/gameplay/player_test_world_3d.tscn`.

### Next

- Continue with V2 任務二十三：任務清單移入 Top Menu 第二頁籤.

## 2026-07-03 Player Visibility V2 Quest Top Menu Tab

### Completed

- Added node-first `scenes/ui/quest_top_menu_panel.tscn` for the Top Menu quest tab.
- Added `scripts/ui/quest_top_menu_panel.gd` to display existing quest definitions and save-backed quest state without mutating quest progress or rewards.
- Wired `UIManager` so `UI_QUESTS` opens/closes the quest panel and keeps Top Menu selection/focus ownership centralized.
- Instanced `QuestTopMenuPanel` under the gameplay HUD so the second Top Menu icon opens a visible quest list.
- Added Traditional Chinese localization keys for the quest panel title, hint, empty state, and inactive status.
- Added `tools/validate_top_menu_panels.gd` to verify second-tab reachability, collect/kill quest visibility, layout fit, and display-only boundaries.
- Added the Top Menu panels validator to V2 health required paths.
- Marked V2 任務二十三 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Top Menu panels validation reports `[top_menu_panels] OK quests_tab=opens list=salvage_hunt layout=fit ui_manager=owns_state boundaries=clean`.
- Quest flow validation reports `[quest_flow] OK extraction=updates_base kill=updates_base quest=claimable reward=saved layout=fits`.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Gameplay scene launch check completed with Godot headless `--quit-after 1 res://scenes/gameplay/player_test_world_3d.tscn`.

### Next

- Continue with V2 任務二十四：角色狀態頁籤.

## 2026-07-03 Player Visibility V2 Character Status Top Menu Tab

### Completed

- Added node-first `scenes/ui/status_top_menu_panel.tscn` for the Top Menu character status tab.
- Added `scripts/ui/status_top_menu_panel.gd` to display player health, stamina, carry weight, equipped gear, and weapon ammo without owning or copying gameplay state.
- Wired `UIManager` so `UI_STATUS` opens/closes the status panel and keeps Top Menu selection/focus ownership centralized.
- Instanced `StatusTopMenuPanel` under the gameplay HUD so the third Top Menu icon opens a visible character status page.
- Added Traditional Chinese localization keys for the status panel title, hint, vitals, weapon ammo, equipment, empty state, and slot labels.
- Expanded `tools/validate_top_menu_panels.gd` to verify quest and status tab reachability, player/equipment/weapon model reads, layout fit, node-first structure, and display-only boundaries.
- Added status panel scene/script paths to V2 health validation.
- Marked V2 任務二十四 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Top Menu panels validation reports `[top_menu_panels] OK quests_tab=opens status_tab=player_model list=salvage_hunt layout=fit ui_manager=owns_state boundaries=clean`.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- Inventory equipment flow validation reports `[inventory_equipment_flow] OK backpack=visible equip=sidearm ammo=rejected layout=fit boundaries=clean`.
- Weapon equipment binding validation reports `[weapon_equipment_binding] OK start=unarmed equip=pistol_sync hud=visible boundaries=clean`.
- Gameplay scene launch check completed with Godot headless `--quit-after 1 res://scenes/gameplay/player_test_world_3d.tscn`.

### Project Health Check After V2 Task Twenty Four

- Trigger: completed V2 tasks twenty two, twenty three, and twenty four after the previous health check.
- Player flow reachability: the compact Raid HUD, quest tab, and status tab are all reachable from the existing gameplay HUD through `UIManager`.
- Base boundary: unchanged in this slice; 3D Base and Base panel responsibilities were not expanded or mixed into status UI.
- Inventory/equipment/weapon boundaries: `StatusTopMenuPanel` only reads `get_inventory_model()`, `get_equipment_model()`, and `WeaponController3D` display fields; it does not move stacks, equip items, reload, or mutate saves.
- Container boundary: container inventory and transfer code were not touched; status UI does not depend on container models.
- UIManager boundary: Top Menu active panel state remains centralized in `UIManager`; panels expose open/close methods and do not manage global input state.
- Traditional Chinese text quality: new player-facing status labels use localization keys with Traditional Chinese values.
- Node-first UI layout: the status page is a `.tscn` Control/Container layout and passes 1280x720 and 1920x1080 fit checks through `validate_top_menu_panels.gd`.
- Save/load safety: no save schema or persistence writes were added.
- Scene loadability: gameplay scene loads headless after the status panel instance was added.
- Validation health: `validate_top_menu_panels.gd` now covers both task and status tab visibility plus ownership boundaries.

### Next

- Continue with V2 任務二十五：地圖頁籤早期版.

## 2026-07-03 Player Visibility V2 Early Map Top Menu Tab

### Completed

- Added node-first `scenes/ui/map_top_menu_panel.tscn` for the Top Menu map tab.
- Added `scripts/ui/map_top_menu_panel.gd` to display a compact early map guide: current area, extraction direction, base/raid state, and a note that this is not yet the full map.
- Wired `UIManager` so `UI_MAP` opens/closes the map panel and keeps Top Menu selection/focus ownership centralized.
- Instanced `MapTopMenuPanel` under the gameplay HUD so the fourth Top Menu icon opens a visible early map page.
- Added Traditional Chinese localization keys for the map panel title, hint, current area, extraction direction, base/raid state, map note, known area names, flow states, and direction names.
- Expanded `tools/validate_top_menu_panels.gd` to verify quest, status, and map tab reachability, map player-visible text, layout fit, node-first structure, and display-only boundaries.
- Added map panel scene/script paths to V2 health validation.
- Marked V2 任務二十五 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Top Menu panels validation reports `[top_menu_panels] OK quests_tab=opens status_tab=player_model map_tab=area_extract list=salvage_hunt layout=fit ui_manager=owns_state boundaries=clean`.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- UI foundation validation reports `[ui_foundation] OK theme=loaded layout=centered grid=stable`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Gameplay architecture validation reports `[gameplay_architecture] OK player_stats=resource inventory=player_owned ui_coupling=clean`.
- Raid HUD validation reports `[raid_hud] OK objective=visible route=clear vitals=visible ammo=weapon extraction=status ui_manager=compatible layout=fit`.
- Quest flow validation reports `[quest_flow] OK extraction=updates_base kill=updates_base quest=claimable reward=saved layout=fits`.
- Gameplay scene launch check completed with Godot headless `--quit-after 1 res://scenes/gameplay/player_test_world_3d.tscn`.

### Next

- Continue with V2 任務二十六：圖鑑一致性檢查.

## 2026-07-03 Player Visibility V2 Codex Item Consistency

### Completed

- Added `tools/validate_codex_item_consistency.gd` to guard No.5 手槍-S and No.7 彈藥-S across item data, stack data, container UI, backpack UI, equipment UI, and codex UI.
- Added the new consistency validator to the V2 health baseline so future automation catches mismatched or invisible item naming.
- Confirmed container capacity display still shows used/total slots such as `2/4`.
- Marked V2 任務二十六 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Codex item consistency validation reports `[codex_item_consistency] OK no5=手槍-S no7=彈藥-S surfaces=container/backpack/equipment/codex`.
- Item catalog validation reports `[item_catalog] OK items=21 max_no=21`.
- Container transfer validation reports `[container_transfer] OK click=moves_to_backpack full=feedback boundaries=clean`.
- Inventory equipment flow validation reports `[inventory_equipment_flow] OK backpack=visible equip=sidearm ammo=rejected layout=fit boundaries=clean`.
- Top Menu panels validation reports `[top_menu_panels] OK quests_tab=opens status_tab=player_model map_tab=area_extract list=salvage_hunt layout=fit ui_manager=owns_state boundaries=clean`.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Gameplay scene launch check completed with Godot headless `--quit-after 1 res://scenes/gameplay/player_test_world_3d.tscn`.

### Next

- Continue with V2 任務二十七：3D Base 到 Raid 裝備帶入.

## 2026-07-03 Player Visibility V2 Base To Raid Loadout

### Completed

- Added `scripts/raid/raid_loadout_transfer.gd` as a data-only bridge for backpack and equipment loadout transfer.
- Added one-shot pending raid loadout methods to `SaveGameManager` so 3D Base can hand off the current player loadout across a scene change without persisting it as stash or UI state.
- Updated `BaseInteractionController3D` so the raid gate prepares the current 3D Base player backpack/equipment before changing to the Raid scene.
- Updated `PlayerController3D` so a Raid player consumes pending loadout before falling back to starter inventory.
- Added `tools/validate_base_to_raid_loadout.gd` to prove No.5 equipped pistol and No.7 backpack ammo transfer from 3D Base into Raid and sync to `WeaponController3D`.
- Added the loadout transfer script and validator to V2 health validation.
- Marked V2 任務二十七 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Base to Raid loadout validation reports `[base_to_raid_loadout] OK base=prepares_pending raid=consumes backpack=ammo equipment=pistol weapon=synced`.
- Base interactions validation reports `[base_interactions] OK prompt=visible panels=connected raid=startable text=zh`.
- Inventory equipment flow validation reports `[inventory_equipment_flow] OK backpack=visible equip=sidearm ammo=rejected layout=fit boundaries=clean`.
- Weapon equipment binding validation reports `[weapon_equipment_binding] OK start=unarmed equip=pistol_sync hud=visible boundaries=clean`.
- Shooting feedback HUD validation reports `[shooting_feedback_hud] OK status=unarmed_empty_ready_reloading node_first=true zh_tw=true boundaries=clean`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Base 3D and gameplay scene launch checks completed with Godot headless `--quit-after 1`.

### Project Health Check After V2 Task Twenty Seven

- Trigger: completed V2 tasks twenty five, twenty six, and twenty seven after the previous health check.
- Player flow reachability: 3D Base raid gate now prepares current player loadout before entering Raid; Raid player consumes that pending loadout on spawn.
- Base boundary: `BaseInteractionController3D` only captures and stores a loadout through `RaidLoadoutTransfer`; it does not directly add items, equip gear, reload, or manipulate combat.
- Inventory/equipment/weapon boundaries: backpack stacks and equipment slots are converted by a data-only transfer helper; `PlayerController3D` applies the pending loadout and then syncs equipment to `WeaponController3D`.
- Container boundary: container ownership and transfer flow were not changed, and `validate_container_transfer.gd` still passes.
- UIManager boundary: no UI state ownership changed; Top Menu and UI panels still pass reachability and ownership checks.
- Quest boundary: quest extraction and kill progression still pass after the loadout handoff change.
- Traditional Chinese text quality and UI layout: no new player-facing UI was added; existing UI text/layout validations still pass at required resolutions.
- Save/load safety: pending raid loadout is temporary one-shot state on `SaveGameManager`, not persistent stash/save schema data; save slot validation still passes.
- Scene loadability: both 3D Base and gameplay scenes load headless after the loadout transfer changes.
- Validation health: new `validate_base_to_raid_loadout.gd` guards the exact player-visible handoff that was previously invisible/broken.

### Next

- Continue with V2 任務二十八：Raid 結算回 3D Base.

## 2026-07-03 Player Visibility V2 Raid Return To 3D Base

### Completed

- Updated `RaidResultPanel` so the player-facing `回到基地` action returns to `res://scenes/base/base_3d.tscn` instead of the old 2D BaseScreen scene.
- Added `tools/validate_raid_return_to_base_3d.gd` to run an extraction result, verify extracted items and money are saved, press the result continue button, and confirm the loaded current scene is `Base3D`.
- Strengthened `tools/validate_raid_result_panel.gd` so future changes fail if normal result flow points back to `base_screen.tscn`.
- Added the new return-flow validator to the V2 health baseline.
- Marked V2 任務二十八 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Raid return to 3D Base validation reports `[raid_return_to_base_3d] OK result=applied destination=base_3d stash=visible`.
- Raid result panel validation reports `[raid_result_panel] OK node_first=true transfer=visible loot=shown continue=base layout=fits`.
- Three Raid loop validation reports `[three_raid_loop] OK raid1=extract_upgrade raid2=death_preserves raid3=kill_extract reload=persistent`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Base flow validation reports `[base_flow] OK new_game=base continue=base current_slot=tracked`.
- Base 3D and gameplay scene launch checks completed with Godot headless `--quit-after 1`.

### Next

- Continue with V2 任務二十九：刪除錯誤捷徑.

## 2026-07-03 Player Visibility V2 Shortcut Removal Guard

### Completed

- Added `tools/validate_player_visible_v2_slice.gd` as the V2 player-visible guard for wrong shortcuts.
- The new validator confirms normal player flow uses 3D Base, not the old 2D BaseScreen route.
- The new validator confirms the Raid scene and Player scene do not hardwire No.5 pistol, No.7 ammo, starter inventory, or weapon definitions.
- The new validator confirms starter loadout does not grant No.5 pistol or No.7 ammo.
- The new validator opens a normal loot container and confirms No.5 pistol and No.7 ammo stay in the container grid until the player clicks a slot.
- The new validator confirms opening a container does not directly alter the player backpack or grant No.5/No.7.
- Added the V2 slice validator to the V2 health baseline.
- Marked V2 任務二十九 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Player-visible V2 slice validation reports `[player_visible_v2_slice] OK shortcuts=removed base=3d raid_loadout=earned container=grid_owned`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Base to Raid loadout validation reports `[base_to_raid_loadout] OK base=prepares_pending raid=consumes backpack=ammo equipment=pistol weapon=synced`.
- Container open flow validation reports `[container_open_flow] OK interaction=opens_ui contents=container_owned ui_manager=owner`.
- Container transfer validation reports `[container_transfer] OK click=moves_to_backpack full=feedback boundaries=clean`.
- Raid return to 3D Base validation reports `[raid_return_to_base_3d] OK result=applied destination=base_3d stash=visible`.
- Base 3D and gameplay scene launch checks completed with Godot headless `--quit-after 1`.

### Next

- Continue with V2 任務三十：玩家可見 V2 Smoke Test.

## 2026-07-03 Player Visibility V2 Smoke Test

### Completed

- Upgraded `tools/validate_player_visible_v2_slice.gd` from a shortcut guard into a full player-visible V2 smoke test.
- The smoke test now starts in 3D Base, prepares a sortie loadout, enters Raid, opens a loot container grid, clicks No.5 pistol and No.7 ammo into the backpack, equips No.5, reloads with a visible HUD progress bar, fires a visible 3D projectile, extracts remaining loot, and confirms the result continue button returns to `Base3D`.
- Kept the existing shortcut guards that prevent normal player flow from routing through the old 2D BaseScreen, prevent pistol/ammo hardwiring, and prevent containers from directly granting loot without player slot clicks.
- Marked V2 任務三十 complete in `docs/tasks/player_visibility_v2_task_queue.md`.

### Verified

- Player-visible V2 slice validation reports `[player_visible_v2_slice] OK base=3d container=grid transfer=equip reload=visible projectile=3d extract=base_3d`.
- Standard Validation Set passes: item catalog, UI foundation, inventory drag rules, gameplay architecture, combat domain, difficulty system, save slots, save slot panel, audio settings, pause menu, main scene launch, and gameplay scene launch.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.

### Project Health Check After V2 Task Thirty

- Trigger: completed V2 tasks twenty eight, twenty nine, and thirty after the previous health check.
- Player flow reachability: the validated flow is now 3D Base -> Raid -> container grid -> backpack/equipment/reload/projectile -> extraction result -> 3D Base.
- Base boundary: Base only prepares sortie loadout and routes the player to Raid; it does not directly grant loot, equip weapons, reload, fire, or write combat state.
- Inventory/equipment/weapon boundaries: container slots transfer into backpack through UIManager, `EquipmentModel` owns equipped No.5, and `WeaponController3D` syncs from equipment before reload/fire.
- Container boundary: `LootContainer3D` owns container inventory and only opens the UI; the player must click slots to move No.5 and No.7.
- UIManager boundary: UIManager remains the owner of active container/top-menu state and slot transfer requests.
- Quest boundary: no quest logic was changed in the smoke test update.
- Traditional Chinese text quality and UI layout: `validate_ui_text_quality.gd` and scene launch checks still pass.
- Save/load safety: validation uses a temporary `user://validation_player_visible_v2_slice` save root and cleans it up after the smoke test; extraction persists remaining No.7 ammo to stash before returning to Base.
- Scene loadability: main scene and gameplay scene both load headless after the final smoke test change.
- Validation health: `validate_player_visible_v2_slice.gd` now guards the exact player-visible V2 acceptance path instead of only checking that shortcuts were removed.

### Next

- V2 player visibility task queue is complete. Stop `dcg-v2` automation after commit/push and final status report.

## 2026-07-03 Base 3D Runtime HUD Hotfix

### Completed

- Added the shared gameplay HUD surfaces to `scenes/base/base_3d.tscn`: `TopMenuBar`, quest/status/map panels, `PlayerHud3D`, `InventoryEquipmentUI`, `ItemCodexUI`, and `PauseMenu`.
- Updated `BaseInteractionController3D` so raid-gate scene changes are deferred after the input event instead of changing scenes immediately during `_unhandled_input`.
- Added `tools/validate_base_3d_runtime_hud.gd` to guard the player-facing failures reported after V2: TAB opens backpack, ESC opens pause, crosshair HUD exists, and the raid gate reaches the gameplay scene.
- Added the new runtime HUD validator to the V2 health baseline.

### Verified

- Base 3D runtime HUD validation reports `[base_3d_runtime_hud] OK tab=backpack esc=pause crosshair=visible raid_gate=gameplay`.
- Base interactions validation reports `[base_interactions] OK prompt=visible panels=connected raid=startable text=zh`.
- Base 3D scene validation reports `[base_3d_scene] OK scene=loadable player=present camera=targeted boundaries=present points=4`.
- Top Menu panels validation reports `[top_menu_panels] OK quests_tab=opens status_tab=player_model map_tab=area_extract list=salvage_hunt layout=fit ui_manager=owns_state boundaries=clean`.
- Pause menu validation reports `[pause_menu] OK open_close=true`.
- Player-visible V2 slice validation reports `[player_visible_v2_slice] OK base=3d container=grid transfer=equip reload=visible projectile=3d extract=base_3d`.
- V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.

### Notes

- Root cause: the new 3D Base scene did not include the gameplay HUD nodes that `UIManager` needs for TAB, ESC, and crosshair behavior.

## 2026-07-03 Raid Minimal HUD And Primary Pistol Equip

### Completed

- Hid the large top-left `RaidHudPanel` in normal Raid gameplay so the red-box objective/status block no longer covers the play view.
- Kept reload feedback player-visible by moving the active reload progress display into `PlayerHud3D` near the crosshair instead of relying on the hidden legacy panel.
- Changed pistol default equipment routing so No.5 pistol equips into `primary_weapon` first, matching the visible `主武器` slot, with `sidearm` left as fallback.
- Updated player-visible validation scripts so they guard the new intended behavior: large raid panel hidden, minimal HUD reload progress visible, and pistol equipped in the primary weapon slot.

### Verified

- Inventory equipment flow reports `[inventory_equipment_flow] OK backpack=visible equip=primary_weapon ammo=rejected layout=fit boundaries=clean`.
- Base-to-Raid loadout reports `[base_to_raid_loadout] OK base=prepares_pending raid=consumes backpack=ammo equipment=pistol weapon=synced`.
- Reload UI reports `[reload_ui] OK minimal_hud=reload_progress visible=true completion=clears legacy_panel=hidden boundaries=clean`.
- Player-visible V2 smoke reports `[player_visible_v2_slice] OK base=3d container=grid transfer=equip reload=visible projectile=3d extract=base_3d`.
- Reload flow reports `[reload_flow] OK r_key=bound empty_fire=auto_reload backpack_ammo=consumed magazine=updated boundaries=clean`.
- Weapon equipment binding reports `[weapon_equipment_binding] OK start=unarmed equip=pistol_sync hud=visible boundaries=clean`.
- Top menu panels, pause menu, Base 3D runtime HUD, shooting feedback HUD, main scene launch, and gameplay scene launch all pass headless validation.

### Notes

- Existing generated localization `.translation` changes and `.uid` files were left untouched.

## 2026-07-03 Dev Slice 0.2 Enemy-First Task Seven

### Completed

- Added a visible pistol fire feedback scene with muzzle spark, short red tracer beam, and muzzle light.
- Connected `WeaponController3D.fire_forward` to spawn both the existing 3D projectile and the new muzzle/tracer feedback.
- Updated `Projectile3D` so both enemy hits and world-object impacts spawn visible hit feedback.
- Added a player-facing validation path where the player equips the No.5 pistol, reloads No.7 ammo, fires visible 3D projectiles, hits the normal Raid Scavenger, and kills it.
- Kept the weapon/projectile/enemy path decoupled from inventory UI, quest state, and save systems.
- Marked Dev Slice 0.2 enemy-first task seven complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Projectile enemy-hit validation reports `[projectile_hit_enemy] OK equip_reload_fire=works projectile=kills_enemy death=visible controller=stops`.
- Pistol fire VFX validation reports `[pistol_fire_vfx] OK muzzle=spark tracer=visible projectile=red impact=visible boundaries=clean`.
- Projectile validation reports `[projectile_3d] OK scene=visible spawn=moving hit=damages miss=cleans_up hitscan=removed boundaries=clean`.
- Weapon equipment binding reports `[weapon_equipment_binding] OK start=unarmed equip=pistol_sync hud=visible boundaries=clean`.
- Reload flow reports `[reload_flow] OK r_key=bound empty_fire=auto_reload backpack_ammo=consumed magazine=updated boundaries=clean`.
- Enemy attack, combat feedback, player-visible V2 slice, Base 3D runtime HUD, and Godot headless scene startup checks passed.

### Notes

- The enemy-hit validation originally failed because the automated shot origin crossed through the player collision body. The validation now fires from a forward muzzle position so it tests the intended pistol-to-enemy projectile path.
- Next task is Project Health Check B before continuing with later enemy loot, quest, result, or UI tasks.

## 2026-07-03 Dev Slice 0.2 Enemy-First Health Check B

### Completed

- Ran the required health check after enemy attack, warning feedback, and player counterattack tasks.
- Confirmed `WeaponController3D` owns projectile and fire VFX spawning without depending on inventory UI, quest, or save systems.
- Confirmed `Projectile3D` stays combat-only and still uses visible projectile movement rather than reverting to hitscan.
- Confirmed `EnemyDamageable3D` remains independent from weapon, inventory, and HUD-specific code.
- Confirmed the previous TAB backpack, ESC pause, crosshair, and Raid gate runtime behavior still passes after combat changes.
- Marked Dev Slice 0.2 enemy-first Project Health Check B complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Player visibility health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Projectile validation reports `[projectile_3d] OK scene=visible spawn=moving hit=damages miss=cleans_up hitscan=removed boundaries=clean`.
- Pistol fire VFX validation reports `[pistol_fire_vfx] OK muzzle=spark tracer=visible projectile=red impact=visible boundaries=clean`.
- Enemy architecture health validation reports `[enemy_architecture_health] OK raid=reachable enemy_boundaries=clean ui_coupling=clean validation=covered`.
- Base 3D runtime HUD validation reports `[base_3d_runtime_hud] OK tab=backpack esc=pause crosshair=visible raid_gate=gameplay`.

### Next

- Continue with task nine: enemy death loot/drop feedback.

## 2026-07-03 Dev Slice 0.2 Enemy-First Task Nine

### Completed

- Promoted the existing Scavenger `EnemyLootDrop3D` path into the Dev Slice 0.2 enemy-first queue.
- Strengthened `tools/validate_enemy_loot_drop.gd` so enemy drops must be player-visible: spawned pickup has a 3D mesh, a prompt label, readable pickup text when the player is in range, and can be collected into the backpack.
- Confirmed enemy loot uses the existing `LootPickup3D` and backpack flow instead of writing directly to stash, result, quest, or UI state.
- Marked Dev Slice 0.2 enemy-first task nine complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Enemy loot drop validation reports `[enemy_loot_drop] OK death=spawns_pickup pickup=adds_inventory repeat=blocked ui_coupling=clean`.
- Inventory drag rules validation reports `[inventory_drag_rules] OK`.
- Projectile enemy-hit validation reports `[projectile_hit_enemy] OK equip_reload_fire=works projectile=kills_enemy death=visible controller=stops`.
- Base 3D runtime HUD validation reports `[base_3d_runtime_hud] OK tab=backpack esc=pause crosshair=visible raid_gate=gameplay`.

### Next

- Continue with task ten: enemy kill quest visibility.

## 2026-07-03 Dev Slice 0.2 Enemy-First Task Five

### Completed

- Confirmed the visible Raid Scavenger can attack the real `Player3D` at close range in the normal Raid scene.
- Added health fields to `PlayerHud3D.get_display_state()` so player damage can be verified as player-visible HUD feedback, not only internal health data.
- Added `tools/validate_enemy_attack_player.gd` to verify enemy melee attack, player health reduction, HUD health sync, attack cooldown, and visible attack status.
- Added `tools/validate_player_damage_flow.gd` to guard the player damage signal and HUD health text update path.
- Marked Dev Slice 0.2 enemy-first task five complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Enemy attack validation reports `[enemy_attack_player] OK raid=normal attack=damages_player hud=updates cooldown=guarded status=visible`.
- Player damage flow validation reports `[player_damage_flow] OK damage=accepted health_signal=emits hud=updates death=guarded`.

### Next

- Continue with task six: enemy attack warning and hit feedback visibility.

## 2026-07-03 Dev Slice 0.2 Enemy-First Task Six

### Completed

- Added a short melee windup to `EnemyController3D` so close-range enemy damage is preceded by a visible warning instead of landing instantly.
- Added `attack_windup_started` signal and exposed `attack_windup` in `get_state()` for focused validation and later feedback hooks.
- Updated `EnemyStatusDisplay3D` so the enemy shows `準備攻擊` and an orange placeholder color during windup, then `攻擊` with a red tint when the hit lands.
- Added player hit feedback to `PlayerHud3D`: a brief red screen flash and border pulse when health decreases.
- Added HUD display-state fields for damage feedback visibility and alpha so automated checks can prove the feedback is player-visible.
- Added `tools/validate_combat_feedback_visibility.gd` to guard enemy warning, delayed damage, player hit feedback, and clean ownership boundaries.
- Updated enemy AI and attack validators to account for the new warning windup.
- Marked Dev Slice 0.2 enemy-first task six complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Combat feedback validation reports `[combat_feedback_visibility] OK enemy_warning=visible windup=delays_damage player_hit=visible boundaries=clean`.
- Enemy AI validation reports `[enemy_ai] OK detect=chase attack=damages dead=stops scene=wired`.
- Enemy attack validation reports `[enemy_attack_player] OK raid=normal attack=damages_player hud=updates cooldown=guarded status=visible`.
- Player damage flow validation reports `[player_damage_flow] OK damage=accepted health_signal=emits hud=updates death=guarded`.

### Next

- Continue with task seven: player projectile can hit and kill the enemy, including pistol fire VFX chain.

## 2026-07-03 Dev Slice 0.2 Enemy-First Task One

### Completed

- Created a 5-minute heartbeat automation for the Dev Slice 0.2 enemy-first task queue.
- Added `ScavengerPatrol01` to the normal Raid scene so the player can encounter a visible 3D enemy during regular sortie flow.
- Added a `NameLabel` to `scenes/enemies/scavenger_3d.tscn` so the enemy is clearly identifiable in 3D space.
- Added `tools/validate_enemy_visible_in_raid.gd` to guard against the system-existing-but-player-invisible enemy failure.
- Marked Dev Slice 0.2 enemy-first task one complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Enemy visibility validation reports `[enemy_visible_in_raid] OK raid=scavenger_visible route=reachable label=visible controller=wired`.
- Enemy AI validation reports `[enemy_ai] OK detect=chase attack=damages dead=stops scene=wired`.
- Raid scene launch check completed with Godot headless `--quit-after 1`.

### Next

- Continue with task two: 3D enemy health, injured, and death state readability.

## 2026-07-03 Dev Slice 0.2 Enemy-First Task Two

### Completed

- Added `scripts/ai/enemy_status_display_3d.gd` as a dedicated 3D enemy status display helper.
- Added a visible 3D health bar and status label to `scenes/enemies/scavenger_3d.tscn`.
- The Scavenger now shows readable states: `待機`, `受傷`, `追蹤中`, `攻擊`, and `死亡`.
- Non-lethal damage shrinks the health bar and changes the enemy's visible state to injured.
- Lethal damage empties the health bar, changes the enemy's visible state to dead, and darkens the placeholder enemy body.
- Added `tools/validate_enemy_damageable_3d.gd` to prove health, injured, and death state readability without coupling display logic to inventory, quest, or save systems.
- Marked Dev Slice 0.2 enemy-first task two complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Enemy damageable validation reports `[enemy_damageable_3d] OK healthbar=visible injured=readable death=readable display=decoupled`.
- Combat domain validation reports `[combat_domain] OK damageable=works weapon=ammo_cooldown_damage scene=has_target`.
- Enemy visibility validation reports `[enemy_visible_in_raid] OK raid=scavenger_visible route=reachable label=visible controller=wired`.
- Enemy AI validation reports `[enemy_ai] OK detect=chase attack=damages dead=stops scene=wired`.
- Raid scene launch check completed with Godot headless `--quit-after 1`.

### Next

- Continue with task three: enemy detection and player chase in the normal Raid scene.

## 2026-07-03 Dev Slice 0.2 Enemy-First Task Three And Health Check A

### Completed

- Added `tools/validate_enemy_chase_player.gd` to validate player detection and chase behavior inside the normal Raid scene, not only in an isolated AI test.
- The validation confirms the visible Raid Scavenger resolves `Player3D` as its target, enters chase state, moves toward the player, and shows `追蹤中` on the 3D status label.
- The validation also confirms the enemy returns to `待機` when the player leaves detect radius.
- Added `tools/validate_enemy_architecture_health.gd` for Project Health Check A.
- Health Check A confirms Enemy, Damageable, Combat, Raid, and UI ownership boundaries remain clean after the first three enemy-first tasks.
- Marked Dev Slice 0.2 enemy-first task three and Project Health Check A complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Enemy chase validation reports `[enemy_chase_player] OK raid=normal detects=player chases=true status=visible idle_return=true`.
- Enemy visibility validation reports `[enemy_visible_in_raid] OK raid=scavenger_visible route=reachable label=visible controller=wired`.
- Enemy AI validation reports `[enemy_ai] OK detect=chase attack=damages dead=stops scene=wired`.
- Enemy damageable validation reports `[enemy_damageable_3d] OK healthbar=visible injured=readable death=readable display=decoupled`.
- Enemy architecture health validation reports `[enemy_architecture_health] OK raid=reachable enemy_boundaries=clean ui_coupling=clean validation=covered`.
- Player visibility V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Raid scene launch check completed with Godot headless `--quit-after 1`.

### Next

- Continue with task five: enemy close-range attack against the player.

## 2026-07-03 Loaded Bullet And Backpack Ammo HUD

### Completed

- Changed the combat ammo HUD from `loaded / magazine capacity` to `loaded bullets / compatible backpack ammo total`.
- Added `PlayerController3D.get_compatible_backpack_ammo_count()` as a read-only query so `PlayerHud3D` does not directly inspect inventory internals.
- Updated the compatible ammo count to sum all matching backpack ammo stacks, not just the first stack.
- Updated reload UI validation to guard the intended display: `0 發子彈 / 24` before reload and `8 發子彈 / 16` after an 8-round reload.

### Verified

- Reload UI validation reports `[reload_ui] OK minimal_hud=reload_progress visible=true completion=clears legacy_panel=hidden boundaries=clean`.
- Reload flow reports `[reload_flow] OK r_key=bound empty_fire=auto_reload backpack_ammo=consumed magazine=updated boundaries=clean`.
- Player-visible V2 smoke reports `[player_visible_v2_slice] OK base=3d container=grid transfer=equip reload=visible projectile=3d extract=base_3d`.
- Weapon equipment binding, Base 3D runtime HUD, main scene launch, and gameplay scene launch pass headless validation.

### Notes

- Existing generated localization `.translation` changes and `.uid` files were left untouched.

## 2026-07-03 Inventory Drag-To-Equipment Hotfix

### Completed

- Fixed backpack drag-to-equipment routing: dragging a backpack stack onto an equipment slot now passes the target slot id to `PlayerController3D.equip_inventory_stack`.
- Kept equipment legality in the player/equipment model path instead of duplicating item rules in UI code.
- Added shared equipment slot rect helpers so painting, hit detection, and validation all refer to the same slot geometry.
- Added a runtime validation path that simulates dragging No.5 pistol from the backpack onto the `primary_weapon` slot and confirms it equips there.

### Verified

- Inventory equipment flow reports `[inventory_equipment_flow] OK backpack=visible equip=primary_weapon ammo=rejected layout=fit boundaries=clean`.
- Inventory drag rules report `[inventory_drag_rules] OK`.
- Weapon equipment binding reports `[weapon_equipment_binding] OK start=unarmed equip=pistol_sync hud=visible boundaries=clean`.
- Reload flow reports `[reload_flow] OK r_key=bound empty_fire=auto_reload backpack_ammo=consumed magazine=updated boundaries=clean`.
- Reload UI reports `[reload_ui] OK minimal_hud=reload_progress visible=true completion=clears legacy_panel=hidden boundaries=clean`.
- Player-visible V2 smoke reports `[player_visible_v2_slice] OK base=3d container=grid transfer=equip reload=visible projectile=3d extract=base_3d`.

### Notes

- Root cause: the previous pistol primary-slot fix only covered click/context equip. Drag release still only handled backpack merge/swap or dropping to the world, so dragging onto equipment slots had no equipment path.

## 2026-07-03 Red Projectile And Magazine HUD

### Completed

- Changed the visible 3D projectile material from yellow to bright red with stronger red emission so fired bullets are easier to see.
- Added a compact ammo panel to `PlayerHud3D` showing the equipped weapon magazine count and capacity, for example `彈匣 0 / 8` before reload and `彈匣 8 / 8` after reload.
- Kept the ammo UI tied to `WeaponController3D.current_ammo` and `magazine_size` so it reflects the same weapon state used by reload and fire logic.
- Updated projectile and reload UI validators to guard red projectile color and visible loaded-ammo / magazine-capacity text.

### Verified

- Projectile validation reports `[projectile_3d] OK scene=visible spawn=moving hit=damages miss=cleans_up hitscan=removed boundaries=clean`.
- Reload UI validation reports `[reload_ui] OK minimal_hud=reload_progress visible=true completion=clears legacy_panel=hidden boundaries=clean`.
- Reload flow reports `[reload_flow] OK r_key=bound empty_fire=auto_reload backpack_ammo=consumed magazine=updated boundaries=clean`.
- Player-visible V2 smoke reports `[player_visible_v2_slice] OK base=3d container=grid transfer=equip reload=visible projectile=3d extract=base_3d`.
- Base 3D runtime HUD, main scene launch, and gameplay scene launch pass headless validation.

### Notes

- Existing generated localization `.translation` changes and `.uid` files were left untouched.

## 2026-07-03 Dev Slice 0.2 Enemy-First Task Ten

### Completed

- Added `SaveGameManager.slot_saved` so save-backed UI can react to successful save updates without owning persistence logic.
- Updated `QuestTopMenuPanel` to refresh itself on the next frame when the open quest page receives a save update.
- Added `tools/validate_quest_kill_enemy_flow.gd` to prove the normal Raid Scavenger kill updates `first_scavenger_hunt` and the already-open Top Menu quest page.
- Kept kill tracking in `QuestKillTracker3D`, quest display in `QuestTopMenuPanel`, and save persistence in `SaveGameManager`.
- Marked Dev Slice 0.2 enemy-first task ten complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Quest kill enemy flow validation reports `[quest_kill_enemy_flow] OK enemy=normal_raid kill=saves_progress top_menu=live_update boundaries=clean`.
- Top menu panel validation reports `[top_menu_panels] OK quests_tab=opens status_tab=player_model map_tab=area_extract list=salvage_hunt layout=fit ui_manager=owns_state boundaries=clean`.
- Projectile hit enemy, Base 3D runtime HUD, player-visible V2 slice, quest flow, save slots, gameplay scene launch, and main scene launch validations pass.

### Next

- Continue with task eleven: enemy-caused player death and result flow.

## 2026-07-03 Dev Slice 0.2 Enemy-First Task Eleven

### Completed

- Added `tools/validate_enemy_player_death_result.gd` to validate the normal Raid Scavenger can attack, kill the player, show the death result panel, list lost backpack items, and return to 3D Base.
- Added `tools/validate_raid_loss_rules.gd` to validate backpack loss, safe-pocket retention, unchanged base stash, and clean RaidLossRules/RaidResultApplier boundaries.
- Updated `tools/validate_raid_return_to_base_3d.gd` so result-to-base validation covers both extraction and death outcomes.
- Confirmed existing gameplay systems already route player death through `Player3D -> RaidSession -> RaidResultApplier -> RaidResultPanel` without adding enemy/UI shortcuts.
- Marked Dev Slice 0.2 enemy-first task eleven complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Enemy player death result validation reports `[enemy_player_death_result] OK enemy=attacks death=result_panel lost_items=visible return=base_3d`.
- Raid loss rules validation reports `[raid_loss_rules] OK lost=backpack kept=safe_pocket stash=unchanged boundaries=clean`.
- Raid return to Base validation reports `[raid_return_to_base_3d] OK result=applied destination=base_3d stash=visible`.

### Next

- Continue with task twelve: Project Health Check C.

## 2026-07-03 Dev Slice 0.2 Enemy-First Health Check C

### Completed

- Strengthened `tools/validate_enemy_architecture_health.gd` so Health Check C now protects the enemy death loot path, enemy kill quest path, player death/loss result path, and display-only UI boundaries.
- Extended `tools/validate_player_visibility_v2_health.gd` to require the enemy loot, quest kill, death result, raid loss, and enemy architecture health validators.
- Confirmed enemy loot remains `EnemyLootDrop3D -> LootPickup3D -> Inventory` and does not write directly to stash, result, quest, or UI state.
- Confirmed enemy kill quest progress remains event-driven through `QuestKillTracker3D` and save-backed quest state, while `QuestTopMenuPanel` only refreshes/display reads.
- Confirmed player death still routes through `Player3D -> RaidLossRules -> RaidSession -> RaidResultApplier -> RaidResultPanel`, with no enemy or UI shortcut owning loss rules.
- Marked Dev Slice 0.2 enemy-first Project Health Check C complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Enemy architecture health validation reports `[enemy_architecture_health] OK raid=reachable enemy_boundaries=clean ui_coupling=clean validation=covered`.
- Player visibility V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Enemy loot drop validation reports `[enemy_loot_drop] OK death=spawns_pickup pickup=adds_inventory repeat=blocked ui_coupling=clean`.
- Quest kill enemy flow validation reports `[quest_kill_enemy_flow] OK enemy=normal_raid kill=saves_progress top_menu=live_update boundaries=clean`.
- Enemy player death result validation reports `[enemy_player_death_result] OK enemy=attacks death=result_panel lost_items=visible return=base_3d`.
- Raid loss rules validation reports `[raid_loss_rules] OK lost=backpack kept=safe_pocket stash=unchanged boundaries=clean`.
- Raid return to Base validation reports `[raid_return_to_base_3d] OK result=applied destination=base_3d stash=visible`.
- Top menu panel validation reports `[top_menu_panels] OK quests_tab=opens status_tab=player_model map_tab=area_extract list=salvage_hunt layout=fit ui_manager=owns_state boundaries=clean`.
- Base 3D runtime HUD validation reports `[base_3d_runtime_hud] OK tab=backpack esc=pause crosshair=visible raid_gate=gameplay`.
- Player-visible V2 smoke validation reports `[player_visible_v2_slice] OK base=3d container=grid transfer=equip reload=visible projectile=3d extract=base_3d`.
- Projectile enemy-hit validation reports `[projectile_hit_enemy] OK equip_reload_fire=works projectile=kills_enemy death=visible controller=stops`.
- Player damage validation reports `[player_damage] OK health=decreases death=once raid_result=dead hud_signal=emits`.
- Gameplay scene and main scene both launch in Godot 4.7 headless mode with `--quit-after 1`.

### Next

- Continue with task thirteen: Raid pre-sortie briefing UI.

## 2026-07-03 Dev Slice 0.2 Enemy-First Task Thirteen

### Completed

- Added the node-first `RaidBriefingPanel` scene under the 3D Base HUD so the raid gate now opens a Traditional Chinese sortie briefing before loading gameplay.
- Updated `BaseInteractionController3D` so the raid gate only prepares the loadout and changes scene after the briefing confirms `開始出擊`.
- Kept the briefing UI display-only: it does not own save, inventory, weapon, or gameplay scene responsibilities.
- Updated the Base runtime HUD validation to preserve TAB backpack, ESC pause, visible crosshair, and confirm-through-briefing raid entry behavior.
- Marked Dev Slice 0.2 enemy-first task thirteen complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Raid briefing validation reports `[raid_briefing_ui] OK open=briefing cancel=base confirm=raid layout=fit text=zh boundaries=clean`.
- Base 3D runtime HUD validation reports `[base_3d_runtime_hud] OK tab=backpack esc=pause crosshair=visible raid_gate=gameplay`.
- Base 3D scene and gameplay scene both launch in Godot 4.7 headless mode with `--quit-after 1`.

### Next

- Continue with task fourteen: Raid map information panel improvements.

## 2026-07-03 Dev Slice 0.2 Enemy-First Task Fourteen

### Completed

- Expanded the Top Menu map page into a readable early 2D information panel without adding a second raid map.
- Added visible Traditional Chinese map rows for current area, suggested route, extraction direction, danger zone, loot container zone, and base/raid state.
- Kept `MapTopMenuPanel` display-only: it reads `RaidSession`, `Player3D`, `ExtractionZone`, `Scavenger`, and `LootContainer` scene state, but does not change scene flow, quest, inventory, weapon, or save state.
- Added `tools/validate_top_menu_map_panel.gd` to verify player-visible map information, layout fit, node-first structure, and display-only ownership.
- Marked Dev Slice 0.2 enemy-first task fourteen complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Top Menu map panel validation reports `[top_menu_map_panel] OK area=visible route=visible extraction=visible danger=visible loot=visible layout=fit boundaries=clean`.
- Top Menu panel validation reports `[top_menu_panels] OK quests_tab=opens status_tab=player_model map_tab=area_extract list=salvage_hunt layout=fit ui_manager=owns_state boundaries=clean`.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- Base 3D scene and gameplay scene both launch in Godot 4.7 headless mode with `--quit-after 1`.

### Next

- Continue with task fifteen: Raid objective hint cleanup.

## 2026-07-03 Dev Slice 0.2 Enemy-First Task Fifteen

### Completed

- Added `tools/validate_raid_hud_minimal_goal.gd` to lock the intended player-facing HUD direction: the large top-left Raid objective panel stays hidden during normal gameplay, while `PlayerHud3D` remains the visible combat HUD.
- Confirmed detailed quest and route information remains reachable from the Top Menu quest/map tabs instead of returning to the large overlay.
- Updated `tools/validate_raid_hud.gd` so the legacy Raid HUD preview can still validate text/layout without forcing the hidden top-left panel to appear when backpack UI opens.
- Preserved TAB backpack, ESC pause, crosshair visibility, reload UI, and the hidden legacy panel behavior.
- Marked Dev Slice 0.2 enemy-first task fifteen complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Raid HUD minimal goal validation reports `[raid_hud_minimal_goal] OK legacy_panel=hidden combat_hud=visible route_detail=top_menu layout=fit boundaries=clean`.
- Raid HUD validation reports `[raid_hud] OK objective=visible route=clear vitals=visible ammo=weapon extraction=status ui_manager=compatible layout=fit`.
- Reload UI validation reports `[reload_ui] OK minimal_hud=reload_progress visible=true completion=clears legacy_panel=hidden boundaries=clean`.
- Base 3D runtime HUD validation reports `[base_3d_runtime_hud] OK tab=backpack esc=pause crosshair=visible raid_gate=gameplay`.

### Next

- Continue with task sixteen: Project Health Check D.

## 2026-07-03 Dev Slice 0.2 Enemy-First Health Check D

### Completed

- Strengthened `tools/validate_player_visibility_v2_health.gd` so Health Check D now protects the UIManager input/mouse/focus contract, raid briefing ownership, map panel display-only ownership, PlayerHud3D minimal combat HUD, and hidden legacy Raid HUD boundaries.
- Confirmed UIManager still owns TAB, ESC, active UI state, gameplay input blocking, focus, and mouse mode.
- Confirmed `RaidBriefingPanel` remains signal-driven and does not own scene loading, save, inventory, weapon, or raid-session logic.
- Confirmed `MapTopMenuPanel` reads visible route/area/danger/loot state without changing scene, quest, inventory, weapon, save, or extraction state.
- Confirmed normal gameplay keeps `PlayerHud3D` visible for crosshair, health, ammo, and reload feedback while the legacy top-left Raid HUD stays hidden.
- Marked Dev Slice 0.2 enemy-first Project Health Check D complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Player visibility V2 health validation reports `[player_visibility_v2_health] OK audit=present known_debts=documented boundaries=guarded`.
- Raid briefing validation reports `[raid_briefing_ui] OK open=briefing cancel=base confirm=raid layout=fit text=zh boundaries=clean`.
- Top Menu map panel validation reports `[top_menu_map_panel] OK area=visible route=visible extraction=visible danger=visible loot=visible layout=fit boundaries=clean`.
- Raid HUD minimal goal validation reports `[raid_hud_minimal_goal] OK legacy_panel=hidden combat_hud=visible route_detail=top_menu layout=fit boundaries=clean`.
- Base 3D runtime HUD validation reports `[base_3d_runtime_hud] OK tab=backpack esc=pause crosshair=visible raid_gate=gameplay`.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- Base 3D scene and gameplay scene both launch in Godot 4.7 headless mode with `--quit-after 1`.

### Next

- Continue with task seventeen: base station interaction readability.

## 2026-07-03 Dev Slice 0.2 Enemy-First Task Seventeen

### Completed

- Added readable 3D purpose hints to the four current Base stations: stash, quest board, workbench, and raid gate.
- Added `tools/validate_base_station_readability.gd` to verify station title labels, purpose hints, near-player prompts, panel text, raid briefing text, and responsibility boundaries.
- Updated `tools/validate_base_interactions.gd` so it matches the current player-facing prompts: `按 E 互動` and `按 E 查看出擊簡報`.
- Preserved the 3D Base flow and avoided adding the next service-station content before task eighteen.
- Marked Dev Slice 0.2 enemy-first task seventeen complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Base station readability validation reports `[base_station_readability] OK stations=4 labels=readable prompts=clear panels=zh boundaries=clean`.
- Base interaction validation reports `[base_interactions] OK prompt=visible panels=connected raid=startable text=zh`.
- Base 3D runtime HUD validation reports `[base_3d_runtime_hud] OK tab=backpack esc=pause crosshair=visible raid_gate=gameplay`.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- Base 3D scene and gameplay scene both launch in Godot 4.7 headless mode with `--quit-after 1`.

### Next

- Continue with task eighteen: add one clear Base service station.

## 2026-07-03 Dev Slice 0.2 Enemy-First Task Eighteen

### Completed

- Added a visible 3D Medical station to the Base with readable title, purpose hint, and interaction prompt.
- Added `BaseMedicalService` so healing cost, save money deduction, and player health restoration stay outside UI scripts.
- Added an action button path to `BaseInteractionPanel` while keeping the panel display-only and node-first.
- Added `restore_health_to_full()` to the 3D player controller for service-driven recovery.
- Updated Base interaction, station readability, and Base 3D scene validators for the fifth station.
- Marked Dev Slice 0.2 enemy-first task eighteen complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Base medical station validation reports `[base_medical_station] OK station=visible heal=works cost=deducted ui=zh boundaries=clean`.
- Save slot validation reports `[save_slots] OK slots=3 save=start load=continue schema=v1`.
- Base interaction validation reports `[base_interactions] OK prompt=visible panels=connected raid=startable text=zh`.
- Base station readability validation reports `[base_station_readability] OK stations=5 labels=readable prompts=clear panels=zh boundaries=clean`.
- Base 3D scene validation reports `[base_3d_scene] OK scene=loadable player=present camera=targeted boundaries=present points=5`.
- Base 3D runtime HUD validation reports `[base_3d_runtime_hud] OK tab=backpack esc=pause crosshair=visible raid_gate=gameplay`.
- UI text quality validation reports `[ui_text_quality] OK keys=present text=clean layout=fits`.
- Base 3D scene and gameplay scene both launch in Godot 4.7 headless mode with `--quit-after 1`.

### Next

- Continue with task nineteen: armor effect visibility.

## 2026-07-03 Dev Slice 0.2 Enemy-First Task Nineteen

### Completed

- Added a data-driven `defense_bonus` field to `ItemDef` and assigned the No.8 light armor a `+4` defense effect.
- Updated `PlayerController3D` so equipped body armor contributes to total defense and reduces incoming damage.
- Added player armor effect state for UI display without moving combat authority into UI scripts.
- Updated the Status Top Menu equipment summary to show the visible armor effect: each hit reduces damage by the armor value.
- Added `tools/validate_equipment_armor_effect.gd` to verify armor equipment, damage reduction, UI visibility, and clean ownership boundaries.
- Marked Dev Slice 0.2 enemy-first task nineteen complete in `docs/tasks/dev_slice_0_2_enemy_first_task_queue.md`.

### Verified

- Armor effect validation reports `[equipment_armor_effect] OK equip=armor damage=reduced ui=visible boundaries=clean`.
- Enemy attack validation reports `[enemy_attack_player] OK raid=normal attack=damages_player hud=updates cooldown=guarded status=visible`.
- Equipment model validation reports `[equipment_model] OK slots=ready equip=legal reject=invalid save=round_trip coupling=clean`.
- Top Menu panel validation reports `[top_menu_panels] OK quests_tab=opens status_tab=player_model map_tab=area_extract list=salvage_hunt layout=fit ui_manager=owns_state boundaries=clean`.
- Player damage flow validation reports `[player_damage_flow] OK damage=accepted health_signal=emits hud=updates death=guarded`.

### Next

- Continue with task twenty: Project Health Check E.
