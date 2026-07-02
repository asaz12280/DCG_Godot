# Project DCG Dev Slice 0.1 Acceptance

Date: 2026-07-02

## Status

System validation: PASSED.

Player-visible acceptance: PENDING.

The automated systems, data paths, and validation scripts have passed. The player-facing version is not approved yet because the user's hands-on review only clearly confirmed a small part of the loop.

Development gate: content expansion remains locked until the user approves Dev Slice 0.1 after hands-on player-visible review.

This report no longer closes the early framework slice for content expansion. It records that system validation passed, but player-visible acceptance is still pending.

## Player Hands-On Review

Confirmed player-visible:

- Difficulty selection / new game entry.
- Extraction zone countdown and result transition.
- Loot containers can produce items.

Not clearly player-visible yet:

- Base phase as a recognizable base screen.
- Traditional Chinese UI text across Base, Raid HUD, and Raid Result.
- Pistol ownership, weapon state, and shooting feedback.
- Scavenger enemy in the normal raid route.
- Player damage, death, and death-loss flow.
- Enemy death and dropped loot.
- Quest progress and claim flow.
- Workbench upgrade requirements and result.
- Vendor/junk selling and money change.
- Save/load state changes visible through normal play.

## Acceptance Checklist

System validation checklist:

- Main menu starts a new save: verified by `validate_base_flow.gd`, `validate_save_slots.gd`, and main project startup.
- Base screen displays persistent stash: verified by `validate_base_screen.gd`, `validate_stash_model.gd`, and `validate_three_raid_loop.gd`.
- Raid map starts from base: verified by `validate_base_flow.gd` and gameplay scene startup at `res://scenes/gameplay/player_test_world_3d.tscn`.
- Player can loot, fight, and extract: verified by `validate_loot_container.gd`, `validate_combat_domain.gd`, `validate_enemy_ai.gd`, and `validate_extraction_flow.gd`.
- Extracted items enter stash: verified by `validate_extraction_flow.gd` and `validate_three_raid_loop.gd`.
- Death loses raid backpack items: verified by `validate_extraction_flow.gd` and `validate_three_raid_loop.gd`.
- Save/load restores stash and money: verified by `validate_save_slots.gd` and `validate_three_raid_loop.gd`.
- At least one upgrade consumes extracted loot: verified by `validate_base_progression.gd` and `validate_three_raid_loop.gd`.
- At least one quest gives direction: verified by `validate_quest_model.gd`, `validate_quest_flow.gd`, and `validate_three_raid_loop.gd`.
- Existing validation suite passes: verified by the Standard Validation Set and the slice-specific validations listed below.
- The loop is repeatable for at least three raids: verified by `validate_three_raid_loop.gd`; final feel approval still requires the user to play and approve the direction.

## Player-Visible Acceptance Checklist

- [ ] Difficulty selection leads to a clearly recognizable Base phase.
- [ ] Base UI is readable in Traditional Chinese.
- [ ] Base clearly shows stash, money, quest, workbench, selling, and start raid.
- [ ] Raid HUD tells the player what to do in Traditional Chinese.
- [ ] Pistol, ammo, and shooting feedback are visible during normal play.
- [ ] Scavenger is visible on the normal raid route.
- [ ] Enemy attack, player damage, and player death are visible.
- [ ] Enemy death and dropped loot are visible and collectible.
- [ ] Extraction result clearly shows brought-back and lost items.
- [ ] Returning to Base clearly shows stash, money, quest, and upgrade changes.
- [ ] At least one collection quest and one kill quest can be understood and completed by normal play.
- [ ] Workbench upgrade requirements and success result are visible.
- [ ] Selling junk and money change are visible.
- [ ] A new `validate_player_visible_slice.gd` or equivalent runtime check catches missing player-visible wiring.
- [ ] The user approves that Dev Slice 0.1 now matches the intended early direction.

## Required Validation Set

Standard Validation Set:

- `validate_item_catalog.gd`
- `validate_ui_foundation.gd`
- `validate_inventory_drag_rules.gd`
- `validate_gameplay_architecture.gd`
- `validate_combat_domain.gd`
- `validate_difficulty_system.gd`
- `validate_save_slots.gd`
- `validate_save_slot_panel.gd`
- `validate_audio_settings.gd`
- `validate_pause_menu.gd`

Dev Slice 0.1 validation set:

- `validate_stash_model.gd`
- `validate_base_screen.gd`
- `validate_base_flow.gd`
- `validate_raid_session.gd`
- `validate_extraction_flow.gd`
- `validate_raid_result_panel.gd`
- `validate_loot_tables.gd`
- `validate_loot_container.gd`
- `validate_enemy_def.gd`
- `validate_enemy_ai.gd`
- `validate_enemy_loot_drop.gd`
- `validate_player_damage.gd`
- `validate_vendor_sell.gd`
- `validate_base_progression.gd`
- `validate_quest_model.gd`
- `validate_quest_flow.gd`
- `validate_raid_hud.gd`
- `validate_ui_text_quality.gd`
- `validate_early_balance.gd`
- `validate_content_authoring_guide.gd`
- `validate_three_raid_loop.gd`
- `validate_dev_slice_acceptance.gd`

Startup checks:

- Main project headless startup.
- Gameplay scene headless startup at `res://scenes/gameplay/player_test_world_3d.tscn`.

## Project Health Check

- Responsibility boundaries: raid result application, save persistence, quests, base progression, enemy behavior, loot tables, and UI display remain in separate scripts/resources.
- UI ownership: Base, Raid HUD, Raid Result, save slot, settings, and pause screens read model/service state and emit user intent instead of owning persistent gameplay truth.
- Godot node-first UI: stable UI surfaces remain `.tscn` Control scenes using Godot nodes, containers, and theme/style helpers.
- UI layout quality: Base, Raid HUD, Raid Result, quest/base UI, save slot panel, pause menu, and settings validations cover readable spacing, button fit, hierarchy, and 1280x720/1920x1080 fit.
- Data-driven content: items, loot tables, enemies, quests, upgrades, localization, and authoring rules are resource or data driven.
- Save safety: extraction, death, stash, money, quest, upgrade, and reload behavior are covered by save and three-raid validations.
- Localization: UI text quality validation checks required keys and clean fallback behavior.
- Scene loadability: main project and gameplay scene load in Godot headless checks.
- Validation health: every major early slice system has a matching `tools/validate_*.gd` guardrail.

## Technical Debt

- `scripts/base/base_screen.gd` is still above the preferred long-term size. Split quest display, workbench display, stash rows, and base actions into focused helpers before adding much more Base behavior.
- Automated validation proves the loop rules and runtime wiring, but the user still needs a hands-on playtest before content volume begins.
- Visual polish, audio feedback, final art, and richer combat feel are intentionally outside Dev Slice 0.1.

## Decision Gate

Do not start repeated content expansion until the user explicitly approves Dev Slice 0.1 after hands-on player-visible review.

Allowed next work before approval:

- Bug fixes.
- Project health fixes.
- Validation maintenance.
- Small UI layout fixes.
- Documentation corrections.

Blocked until approval:

- Second full map.
- Large item batches.
- Large weapon batches.
- Large enemy batches.
- Long quest chains.
- Final art production.
