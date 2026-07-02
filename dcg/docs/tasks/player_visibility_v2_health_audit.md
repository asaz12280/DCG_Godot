# Project DCG Player Visibility V2 Health Audit

Last updated: 2026-07-02

## Purpose

This audit is the baseline for the Player Visibility V2 phase. It records the current coupling debts before we fix them, so automation can refactor toward the corrected player-visible loop without mixing unrelated systems together.

The health check does not mean these debts are acceptable forever. It means the debts are visible, named, and protected by validation until later V2 tasks remove them.

## Current Coupling Debts

1. 3D Base interaction wiring pending
   - The current player flow now has a small 3D Base scene target, but its interaction points are still position markers.
   - Target: difficulty selection enters 3D Base, then stash, quests, workbench, and raid start are opened through player interaction.

2. 2D Base screen
   - `BaseScreen` currently carries too much of the Base experience.
   - Target: keep it as reusable stash/workbench/summary UI opened from 3D Base interactions.

3. hardwired starter pistol
   - `scenes/player/player_3d.tscn` assigns `pistol_9mm.tres` directly to `WeaponController3D`.
   - Target: the pistol must come from loot, appear in backpack, then be equipped through `EquipmentModel`.

4. starter loadout coupling
   - `PlayerController3D` still loads starter inventory and applies Base starter ammo bonus directly.
   - Target: player movement/input should not decide starting weapons, ammo, or Base progression effects.

5. direct container-to-backpack grant
   - `LootContainer3D.try_open()` rolls loot and calls the player `add_item_resource` API directly.
   - Target: containers hold their own inventory grid; the player moves items from container slots into backpack slots.

6. missing container capacity UI
   - Current container interaction does not show box name, `2/4` capacity, or visible item slots.
   - Target: a stable `.tscn`/Control panel displays container contents and capacity.

7. fake ammo counters
   - `WeaponController3D` owns `current_ammo` and `reserve_ammo` as local counters.
   - Target: ammo and magazine state should come from inventory/equipment/ammo models, not hidden controller numbers.

8. hitscan firing
   - `WeaponController3D` uses `intersect_ray()` and has no visible projectile bullet.
   - Target: firing spawns a visible 3D projectile that travels, hits, or expires.

9. missing EquipmentModel
   - Equipment slots are currently visible UI concepts, but there is no standalone equipment domain model.
   - Target: equipment data is independent from UI and validates legal slots.

10. Top Menu placeholder panels
   - Top Menu has backpack, quests, status, map, and codex IDs, but not every tab has a real player-facing panel.
   - Target: UIManager owns tab state; quests/status/map become real panels with Traditional Chinese text.

11. oversized Raid HUD
   - The HUD can still carry too much objective detail.
   - Target: HUD stays compact; full quest detail belongs in the top menu Quest tab.

## Ownership Guardrails

- `PlayerController3D`
  - Owns movement, interaction routing, and player-facing input requests.
  - Must not hard-code starter weapons, ammo, loot tables, quest state, or Base flow.

- `InventoryModel`
  - Owns item stacks and capacity rules.
  - Must not know about `WeaponController3D`, `EquipmentModel`, `UIManager`, `LootContainer3D`, or `PlayerController3D`.

- `EquipmentModel`
  - Owns equipped slots and legality checks.
  - Must not draw UI, roll loot, spawn projectiles, or save directly.

- `WeaponController3D`
  - Owns firing, reload state, projectile spawning, combat signals, and weapon feedback.
  - Reads equipped weapon and compatible ammo through a small API instead of reading backpack UI.

- `LootContainer3D`
  - Owns container interaction, generated contents, open/closed state, and persistence hooks.
  - Must not directly transfer all loot into the player backpack.

- `ContainerInventoryUI`
  - Owns visible container layout, capacity text, slot controls, and transfer intent.
  - Must not roll loot or own combat/equipment rules.

- `UIManager`
  - Owns active UI state, focus, mouse mode, and input blocking.
  - Stable UI should be `.tscn`/Control/Container based; scripts may build dynamic rows only.

## Parallel-Safe Work Lanes

- Base lane:
  - Files: `scenes/base_3d/`, `scripts/base/`, Base interaction scenes.
  - Must not rewrite combat or inventory internals.

- Container lane:
  - Files: `scripts/loot/`, `scripts/inventory/container_inventory_model.gd`, `scenes/ui/container_inventory_panel.tscn`, `scripts/ui/container_inventory_ui.gd`.
  - Must not change weapon reload behavior.

- Equipment and weapon lane:
  - Files: `scripts/equipment/`, `scripts/combat/`, player equipment binding.
  - Must not directly alter Base scene flow.

- Top menu lane:
  - Files: `scripts/ui/`, `scenes/ui/`, localization CSV.
  - Must route panel open/close through `UIManager`.

## Validation Rules

- `validate_player_visibility_v2_health.gd` must pass before later V2 task completion.
- `validate_gameplay_architecture.gd` remains the broad architecture smoke test.
- A task is not complete unless the feature is visible through normal play, uses readable Traditional Chinese, and has a focused validation script.
- Known debts in this document must be removed only when the corresponding V2 task actually fixes the behavior and updates the health validation.
