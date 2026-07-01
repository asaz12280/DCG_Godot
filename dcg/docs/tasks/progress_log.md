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

### Next

- Continue with 任務二十：加入 Raid HUD 目標資訊.

### Next

- Continue with 任務十九：加入敵人掉落.
