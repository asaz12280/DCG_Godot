# Project DCG New Game Plan: Dev Slice 0.3

Date: 2026-07-06

## Purpose

This document replaces broad early-development direction with a concrete production plan for the current Project DCG build.

The target remains a simplified Escape From Duckov-like single-player PvE extraction game. The goal is functional parity, not UI copying, source-code copying, or content-volume imitation.

The immediate direction is:

```text
Stabilize the current loop -> repair player-visible regressions -> formalize weapon/stat architecture -> add only small representative content.
```

Do not start by adding many guns, maps, enemies, quests, or final art.

## Current Production Assessment

Overall current health score: 52 / 100.

Reasoning:

- System coverage is already meaningful: base, raid, loot, extraction, inventory, stash, weapon, armor, attachment, enemy, quest, workbench, save, and validation systems all exist in some form.
- The main extraction loop is currently not reliable enough: validation shows extracted loot is not consistently transferred into persistent stash, and three-raid progression persistence is failing.
- UI/localization health is unstable: several validators output `ERROR`, especially around English translations, removed language resources, base station wording, raid result text, and weapon mod panel text.
- Architecture direction is mostly correct: gameplay architecture validation still reports clean player-owned inventory and UI coupling boundaries.
- Script-size risk is now real: several scripts exceed the project guideline of roughly 300-350 lines and should be split before more systems are added.

## Duckov Reference Takeaways

The AssetRipper analysis suggests Escape From Duckov is structured around compiled core systems plus data-authored content. The useful lesson is not the exact code. The useful lesson is the architecture pattern:

- Shared gameplay systems interpret data.
- Items, weapons, bullets, armor, enemies, quests, shops, buildings, buffs, and scenes are content data or prefabs.
- Guns are not isolated one-off scripts. They are runtime item agents using weapon settings, ammo, reload modes, trigger modes, bullet info, damage types, recoil/spread style values, and state machines.
- AI is behavior/data driven, using behavior-tree-like assets rather than hard-coded one-enemy scripts.
- Save is subsystem-oriented: each major domain owns its serializable state, and a save system aggregates it.
- Scene flow is modular: base, menu, prepare/result, main raid scenes, and sub-scenes are separated.

For Project DCG, this means the next plan should protect and improve:

- Data-driven item definitions.
- Weapon/ammo/armor stat resolution.
- Loot tables and container data.
- Enemy definitions and simple behavior profiles.
- Quest definitions and save-friendly quest state.
- Base upgrade definitions and services.
- Focused validators that fail clearly when the player loop regresses.

## Current Implemented Base

The current project already has enough systems to build from:

- Godot 4.7 project with main menu, difficulty, save slots, settings, pause, localization bootstrap, and UI manager.
- 3D base, station interaction, stash, quest board, workbench/service-style flows, and raid gate.
- One main raid map flow, loot containers, locked container behavior, extraction zone, raid result panel, and return-to-base path.
- Item catalog currently validating at 19 active items.
- Data resources for items, ammo, armor, attachments, loot tables, one enemy, quests, base upgrades, crafting recipes, and dismantle recipes.
- Combat domain with damage events, damageable nodes, weapon controller, ammo model, projectile, hit feedback, armor mitigation, recoil/spread/durability/attachment-related services.
- One Scavenger enemy data/scene/controller path with AI, damage, death, and loot-drop coverage.
- Quest system with collect, kill, and location-style support.
- Save schema v1 with slot metadata, money, stash, base upgrades, and quests.
- Many `tools/validate_*.gd` validators.

## Validation Snapshot

Commands were run on 2026-07-06 using:

```powershell
C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe
```

Passed or structurally healthy:

- `validate_item_catalog.gd`: OK, 19 active items.
- `validate_save_slots.gd`: OK, schema v1 works at the save-slot level.
- `validate_combat_domain.gd`: OK, damageable/weapon/ammo/cooldown/damage target path works.
- `validate_gameplay_architecture.gd`: OK, player-owned inventory and UI coupling boundary remain clean.
- `validate_loot_tables.gd`: OK, loot tables are valid.
- Project headless startup: OK.

Failed or emitted blocking `ERROR` output:

- `validate_extraction_flow.gd`: extracted items are not saved into persistent stash; raid inventory and equipment are not cleared after successful transfer.
- `validate_three_raid_loop_0_2.gd`: three-raid persistence is failing across stash, money, workbench upgrade, upgrade preservation, and bonus ammo.
- `validate_user_reported_correctness.gd`: many English localization keys are not translated; non-cash extracted loot still does not move to stash.
- `validate_ui_text_quality.gd`: localization CSV/resource policy is inconsistent; removed language/import artifacts remain; raid result text says loot remains in backpack instead of entering base stash.
- `validate_base_station_readability.gd`: quest station title is wrong; base station localization still contains prototype wording such as "connected" and "後續會".
- `validate_weapon_attachment_slots.gd`: string formatting errors; weapon mod panel labels and localization keys are missing or unreadable.
- `validate_enemy_architecture_health.gd`: normal raid enemy is too far from the player route for the first encounter.
- `validate_base_progression.gd`: workbench/recipe/fix-station/blueprint panel text does not clearly explain ready, completed, empty, or installed states.

Important validation process issue:

- Several validators emit `ERROR` but still return process exit code 0. This can make automation falsely report success. Validator failure semantics must be repaired before relying on automated completion reports.

## Discovered Errors And Risks

### P0: Core Loop Regression

The current build cannot be treated as a stable Duckov-like loop until extraction transfer is fixed.

Observed failures:

- Successful extraction does not reliably move non-cash loot into persistent stash.
- Raid inventory/equipment are not cleared after successful transfer.
- Three-raid validation fails to preserve stash, money, workbench upgrade, and upgrade effects.

Production impact:

- The game loop loses its main reward contract.
- Base progression cannot be trusted.
- Content expansion would hide or multiply the bug.

Required fix before new content:

- Repair `RaidResultApplier`, `RaidLossRules`, `RaidLoadoutTransfer`, `StashModel`, and result panel assumptions until extraction/death/stash behavior agrees across validators.

### P0: Validator Exit-Code Reliability

Validators currently print `ERROR` while returning exit code 0.

Production impact:

- Automation may mark broken slices as passed.
- Completion reports can drift from the actual build.

Required fix:

- Standardize validator failure behavior so any `_errors` or `push_error` condition exits non-zero or produces an explicit failure result consumed by automation.
- Update the task workflow to treat `ERROR:` text in validator output as failed even before exit-code repair is complete.

### P1: Localization Policy Drift

Current files and validators disagree.

Observed failures:

- Validator expects `key`, `zh_TW`, and `en` only, but CSV/imported resources still include removed or stale language support.
- Many English entries are still untranslated or equal to keys.
- Some player-facing text still uses prototype language.
- Deleted item localization keys remain for removed content.
- Some descriptions say "future" or "not enabled yet" even when the feature now exists.

Decision:

- Early development should support `zh_TW` and `en` as mandatory complete locales.
- `zh_CN` and `ja` should either be removed from the active pipeline or formally re-added with validators updated. Do not leave half-supported languages active.

### P1: Base Readability Regression

Current base text still contains prototype wording:

- "已連接"
- "後續會"
- "connected"

Production impact:

- The base feels like a development debug panel, not a playable hideout.
- Station purpose is unclear.

Required fix:

- Rewrite station copy as player actions: stash management, quest review, workbench crafting/research, repair/dismantle gates, raid gate.
- Keep all text localization-key driven.

### P1: Weapon Mod Panel Regression

Observed failures:

- String formatting errors in weapon attachment validation.
- Missing or unreadable slot labels.
- Installed attachments and empty hardpoints are not reliably shown.
- Missing localization keys for weapon mod panel text.

Production impact:

- Weapon customization exists structurally but is not player-readable.
- This blocks weapon-system expansion.

Required fix:

- Repair weapon mod panel localization and formatting before adding more attachments or weapons.

### P1: First Encounter Visibility

Observed failure:

- Normal raid enemy is not close enough to the player route for the first encounter.

Production impact:

- The first raid may feel empty.
- Players may not learn combat, looting pressure, or extraction risk.

Required fix:

- Reposition or route the first enemy encounter so it is visible/reachable without requiring exploration knowledge.

### P2: Script Responsibility Debt

Current large scripts:

- `inventory_equipment_ui.gd`: 815 lines.
- `base_stash_inventory_ui.gd`: 719 lines.
- `player_controller_3d.gd`: 660 lines.
- `player_equipment_controller_3d.gd`: 552 lines.
- `quest_top_menu_panel.gd`: 446 lines.
- `raid_hud_panel.gd`: 413 lines.
- `item_codex_ui.gd`: 392 lines.
- `weapon_controller_3d.gd`: 369 lines.
- `enemy_controller_3d.gd`: 360 lines.

Production impact:

- New features are likely to be added to already overloaded owners.
- Bugs become harder to isolate.

Required direction:

- Split by responsibility before adding new large gameplay systems.
- Prioritize UI presenters/layout helpers, player combat/equipment bridges, and weapon stat services.

## New Game Direction

Working title:

```text
Project DCG: Duckov-like Extraction Core
```

Early slice name:

```text
Dev Slice 0.3: Stabilized Duckov-like Core
```

Core fantasy:

The player prepares in a small 3D base, enters one dangerous zone, scavenges useful loot, fights readable enemies, chooses whether to extract or risk more, then turns extracted loot into visible long-term growth.

Design pillars:

1. Complete and reliable loop before more content.
2. Readable top-down combat before deeper systems.
3. Loot must turn into stash, money, crafting, repair, quests, or upgrades.
4. Weapon values must be data-driven and inspectable.
5. UI style can remain original, but player-facing function should be Duckov-like.
6. Every player-visible system must have `zh_TW` and `en` localization.
7. Automation cannot mark success while validators print errors.

## Early Development Roadmap

### Phase 0: Stabilization Gate

Goal:

Make the current build truthful again. No new gameplay content.

Tasks:

1. Fix validator failure semantics.
2. Fix extraction transfer into persistent stash.
3. Fix raid inventory/equipment clearing after extraction.
4. Fix three-raid persistence: stash, money, workbench upgrade, death preservation, next-raid bonus.
5. Fix localization policy to mandatory `zh_TW` and `en`.
6. Remove or properly support stale `zh_CN` and `ja` assets.
7. Fix base station prototype wording.
8. Fix weapon mod panel formatting and localization.
9. Move first enemy encounter into the normal player route.
10. Update the completion report only after current validators are clean.

Exit criteria:

- Any validator `ERROR` is treated as failure.
- `validate_extraction_flow.gd` has no errors.
- `validate_three_raid_loop_0_2.gd` has no errors.
- `validate_user_reported_correctness.gd` has no errors.
- `validate_ui_text_quality.gd` has no errors.
- `validate_base_station_readability.gd` has no errors.
- `validate_weapon_attachment_slots.gd` has no errors.
- `validate_enemy_architecture_health.gd` has no errors.

### Phase 1: Weapon And Stat Foundation

Goal:

Turn the current pistol/attachment implementation into a scalable weapon-stat model without adding a large weapon catalog.

Duckov-inspired target:

Weapons, ammo, attachments, armor, difficulty, buffs, and durability should resolve into final combat values through a service, not scattered branches.

Required data:

- Base weapon damage.
- Fire rate.
- Magazine capacity.
- Reload time.
- Projectile range/speed.
- Hip spread.
- Aim spread.
- Vertical recoil.
- Horizontal recoil.
- Recoil recovery.
- Durability max/current.
- Durability wear per shot.
- Caliber/ammo tag.
- Compatible ammo tags.
- Attachment slots.
- Armor penetration.
- Critical chance.
- Projectile pierce chance.

Tasks:

1. Define a `WeaponStatSnapshot` or equivalent read model.
2. Make `WeaponTuningService` the single place that resolves weapon + ammo + attachments + durability.
3. Add validation that the UI and combat use the same resolved values.
4. Keep active content to:
   - Pistol-S.
   - Combat Knife or one slow weapon archetype.
   - Basic Ammo-S.
   - Polished Ammo-S.
   - One magazine attachment.
   - One recoil/spread attachment.
5. Create a small weapon balance table in docs, not a large catalog.

Exit criteria:

- Weapon panel shows resolved values.
- Shooting uses resolved values.
- Ammo modifiers affect damage/spread/recoil or clearly document which values are not active yet.
- Attachments do not appear as character equipment slots; they belong to the weapon.

### Phase 2: First 10-Minute Player Route

Goal:

Make the first session understandable without developer explanation.

Required route:

```text
Main menu -> save slot -> 3D base -> station prompts -> raid gate -> briefing -> raid -> loot -> equip pistol -> reload -> encounter enemy -> extract -> result -> stash -> workbench/quest -> next raid
```

Tasks:

1. Add or repair raid briefing.
2. Repair map/top-menu information so extraction direction and objective are readable.
3. Ensure first enemy is on the route.
4. Ensure Pistol-S and Ammo-S are discoverable in normal loot flow.
5. Ensure extraction result clearly says what was gained, lost, and saved.
6. Ensure result returns to 3D base without forcing warehouse UI.
7. Ensure one quest can be understood, progressed, completed, and rewarded.

Exit criteria:

- A new player can finish one successful raid without knowing the editor.
- One death path clearly shows loss.
- The second raid starts with saved progression.

### Phase 3: Base Progression Clarity

Goal:

Make the base feel like a small hideout, not a debug menu.

Tasks:

1. Rewrite station copy.
2. Make workbench states readable:
   - Not installed.
   - Materials missing.
   - Ready.
   - Crafted.
   - Research completed.
   - Repair station locked/unlocked.
   - Dismantle station locked/unlocked.
3. Keep one short upgrade chain:
   - Workbench Level 1.
   - Fix Station.
   - Dismantle Station.
   - Storage Expansion Level 1.
4. Do not add a full skill tree yet.

Exit criteria:

- Player knows what each base station does.
- Upgrade costs and rewards are visible.
- Upgrade effects are visible in the next raid or stash.

### Phase 4: Controlled Content Expansion

Goal:

After the loop is stable, add representative variety, not volume.

Allowed additions:

- 1 new enemy archetype: ranged patrol or guard.
- 1 new weapon rhythm: slow heavy firearm or melee if not active.
- 1 new special loot source: locked cache or mission object.
- 1 new location quest.
- 1 new ammo variant.
- 1 new armor/backpack effect.

Blocked until later:

- Second full raid map.
- Large weapon batches.
- Large enemy batches.
- Long quest chains.
- Full skill tree.
- Weather system.
- NPC dialogue system.
- Steam Workshop/mod support.
- Final character or environment art production.

## Feature Priority List

### Must Fix Before Any Expansion

1. Validator failures must fail automation.
2. Extraction loot must enter persistent stash.
3. Raid inventory/equipment must clear after successful transfer.
4. Three-raid persistence must pass.
5. `zh_TW` and `en` localization must be complete for active player-facing text.
6. Base station text must stop using prototype wording.
7. Weapon mod panel must stop throwing formatting errors.
8. First enemy encounter must be visible in the normal player route.

### Must Build For Dev Slice 0.3

1. Weapon stat snapshot/resolver.
2. Small weapon balance table.
3. Stable weapon/ammo/attachment UI.
4. Raid briefing or equivalent pre-raid objective panel.
5. Map/objective readable panel.
6. Workbench/base progression readable states.
7. First 10-minute route validation.

### Nice After Stabilization

1. One ranged patrol enemy.
2. One special locked loot source.
3. One location quest.
4. One armor or backpack effect with visible stats.
5. One short repair/dismantle loop.

## Early Weapon Balance Direction

Only balance a few archetypes first.

### Pistol-S

Role:

- Starter firearm.
- Cheap, low capacity, readable reload rhythm.

Design target:

- Reliable against Scavenger.
- Weak against armor.
- Low recoil.
- Low durability wear.

### Combat Knife

Role:

- Backup option when ammo is empty.

Design target:

- No ammo.
- Risky range.
- Useful only when player commits to close combat.

### Slow Heavy Weapon

Role:

- Second combat rhythm after pistol.

Design target:

- Slower fire rate.
- Higher burst damage.
- Higher reload risk.
- More recoil/spread.

Do not add more than these three until the stat resolver and UI are stable.

## Data Architecture Direction

Current `ItemDef` already contains many weapon, ammo, armor, durability, and attachment fields. This is useful for early speed, but it is at risk of becoming a "god resource."

Near-term acceptable rule:

- Keep `ItemDef` as the authored item entry.
- Use focused services to interpret groups of fields.
- Do not add unrelated fields unless a validator and UI path use them immediately.

Future split candidates:

- `WeaponProfile`: weapon-only base values.
- `AmmoProfile`: ammo-only multipliers and penetration.
- `ArmorProfile`: armor and durability rules.
- `AttachmentProfile`: slot, compatibility, and modifier values.
- `ConsumableProfile`: healing, stamina, buff duration.

Do not split immediately unless the next feature would otherwise add many more fields to `ItemDef`.

## Script Split Plan

Prioritize splitting only where new work will touch the file.

High priority split targets:

- `inventory_equipment_ui.gd`: move weapon mod panel, backpack drawing, equipment panel, context menu bridge, and input handling into focused presenters/helpers.
- `base_stash_inventory_ui.gd`: keep scene owner small; move storage upgrade rendering, stash/backpack transfer rules, and markers into existing support scripts.
- `player_controller_3d.gd`: keep orchestration; move reload, fire intent, damage/death, and raid interaction bridges into focused components where practical.
- `player_equipment_controller_3d.gd`: isolate weapon equipment binding, attachment install/remove, durability instance state, and loadout serialization.
- `weapon_controller_3d.gd`: keep runtime fire/reload operation; move stat resolution fully into `WeaponTuningService`.
- `enemy_controller_3d.gd`: keep simple state machine; split sensors, attack, and route/visibility if adding a second archetype.

Rule:

Do not do a broad refactor. Split only as part of a specific stabilization or feature task with validator coverage.

## Definition Of Done For Dev Slice 0.3

Dev Slice 0.3 is done only when:

- A fresh save can complete base -> raid -> loot -> fight -> extract -> result -> stash -> upgrade -> next raid.
- Death and extraction produce clearly different results.
- Extracted non-cash loot enters persistent stash.
- Cash/economy behavior is explicit and validated.
- Raid inventory/equipment cleanup rules are correct.
- Save reload preserves stash, money, quests, base upgrades, and equipment state.
- Pistol/ammo/attachment values are visible and match runtime behavior.
- Base station text is player-facing, not prototype wording.
- `zh_TW` and `en` are complete for active player-facing text.
- Validators fail loudly when errors exist.
- No new content batch was added to hide instability.

## Recommended Next Implementation Order

1. Repair validator failure handling or automation failure parsing.
2. Repair extraction transfer into stash.
3. Repair three-raid progression persistence.
4. Repair localization policy and active `zh_TW`/`en` coverage.
5. Repair base station readability.
6. Repair weapon mod panel formatting/localization.
7. Repair first enemy route visibility.
8. Add weapon stat snapshot/resolver validation.
9. Add small weapon balance table.
10. Repair workbench/base progression UI states.
11. Re-run first 10-minute route validation.
12. Only then add one representative new enemy/weapon/quest/loot-source sample.

## Current Non-Goals

- Do not clone Escape From Duckov UI.
- Do not copy proprietary code or formulas.
- Do not chase 50+ weapons.
- Do not add a second map.
- Do not add full skill trees.
- Do not add Steam Workshop support.
- Do not polish final art before the loop is stable.
- Do not rely on completion reports without rerunning current validators.

