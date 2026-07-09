# Unity Reference Logic Migration Inventory

Date: 2026-07-07

## Purpose

Use the AssetRipper export as a reference source for gameplay-system ideas, not as source code to copy into Project DCG.

Reference project:

`D:\Escape from Duckov\AssetRipper_export_20260705_151633\ExportedProject`

Target project:

`D:\3DMesh\DCG_Godot\dcg`

The migration goal is to make Project DCG more complete while preserving the current Godot architecture, validation workflow, localization requirements, and script responsibility boundaries.

## Safety Rules

- Do not import Unity runtime dependencies, MonoBehaviour lifecycle assumptions, UnityEvent wiring, Easy Save, Addressables, URP, shaders, scene/prefab execution flow, or editor-only scripts.
- Do not port large Unity classes directly. Extract the gameplay rule and implement it as Godot resources, services, controllers, or validators that match existing project ownership.
- Do not expand content volume before the current loop is stable.
- Every implementation candidate must name its target domain, owner files, expected validator, and rollback risk before editing.
- If a candidate would touch an overloaded script, split or reuse an existing focused helper first.
- Player-facing text must use localization keys with `zh_TW` and `en` coverage.

## Current Project Priority

The current DCG plan says to stabilize first:

1. Repair extraction-to-stash and raid inventory/equipment clearing.
2. Repair validator failure semantics so automation can trust results.
3. Repair localization and base station readability.
4. Repair weapon mod panel readability.
5. Make the first enemy encounter visible.
6. Only then add small representative content.

Unity-derived logic should support those priorities, not distract from them.

## Unity Reference Findings

The readable `.cs` files in the export are mostly third-party packages or examples:

- ECM2 examples and walkthrough scripts.
- VLB volumetric light scripts.
- FOW demos.
- KINEMATION demo/helpers.
- Miscellaneous editor/demo helpers.

Useful gameplay domain names are mostly visible in `TeamSoda.Duckov.Core.dll`, not as clean source files. Reflection shows these reference systems:

- `ItemSetting_Gun`, with `ReloadModes` and `TriggerModes`.
- `ItemAgent_Gun`, with `GunStates`.
- `InventoryExtensions.Sort`.
- `ItemUtilities`, including `AddAndMerge`, `ConsumeItems`, `Count`, `Decompose`, `GetRepairLossRatio`, `SendToPlayerStorage`, `SendToPlayerCharacterInventory`, and player item-operation events.
- `PlayerStorage`, with storage capacity calculation and load behavior.
- `RaidUtilities`, with `NewRaid`, `NotifyDead`, `NotifyEnd`, and raid lifecycle events.
- `CraftingFormula`, with id, result, tags, cost, unlock, perk requirement, and index visibility fields.
- `Duckov.Quests.Quest`, `QuestManager`, `QuestCollection`, quest relations, quest giver IDs, quest save data, and quest sorting/status UI.
- `Duckov.Economy.StockShop`, with buy/sell/cache item flow, stock counts, override sell prices, merchant profiles, and shop save data.
- `Duckov.Buildings.BuildingManager`, building area data, building rotation, building tokens, building save data, and buy/place results.
- `Duckov.Buffs` and perk-tree systems.
- `Duckov.Utilities.GameplayDataSettings`, with item assets, looting, quests, buffs, and scene management data.
- `InteractableLootbox` and `LootBoxStates`.

These are architecture signals. They do not justify copying implementation.

## Existing DCG Coverage

Project DCG already has matching systems:

- Items, ammo, armor, attachments, weapon profiles, durability, and tuning snapshots.
- Inventory, containers, stash, item stack save codec, sorting, and transfer rules.
- Loot tables and loot containers.
- Raid result, extraction, loss rules, and loadout transfer.
- Quests: collect, kill, location, catalog, state, and reward claim.
- Base upgrades, workbench, recipes, repair, dismantle, blueprint, needed-item services, and stash storage upgrades.
- Enemy definitions, behavior profiles, controller, damage, death, and loot drop.
- UI presenters/helpers for inventory, codex, quests, weapon mods, HUD, and top menu panels.
- Focused validators for most of the above.

Because coverage already exists, the safest migration path is strengthening gaps and validators, not adding parallel systems.

## Candidate Queue

### P0: Stabilize Raid Reward Contract

Unity reference signal:

- `RaidUtilities` owns raid lifecycle events.
- `ItemUtilities.SendToPlayerStorage` and player item-operation events suggest reward transfer is a service-level operation, not a UI side effect.

DCG target:

- `scripts/raid/raid_result_applier.gd`
- `scripts/raid/raid_loadout_transfer.gd`
- `scripts/raid/raid_loss_rules.gd`
- `scripts/base/stash_model.gd`
- `tools/validate_extraction_flow.gd`
- `tools/validate_three_raid_loop_0_2.gd`

Safe migration action:

- Treat successful extraction as a domain transaction: extracted non-cash items enter persistent stash, cash enters money, and consumed raid inventory/equipment is cleared by the same result path.
- Do not add a new manager. Repair the existing raid/base services.

Acceptance:

- `validate_extraction_flow.gd` has no `ERROR` output.
- `validate_three_raid_loop_0_2.gd` has no stash, money, upgrade, or bonus-ammo regression.

### P0: Make Validators Automation-Safe

Unity reference signal:

- Not a Unity feature. This is required before automated migration can be trusted.

DCG target:

- `tools/validate_*.gd`
- Possible shared helper only if an existing validation pattern supports it.

Safe migration action:

- Standardize failure exit behavior or add a small validation result helper.
- Until then, automation must treat `ERROR` text as failed even if exit code is 0.

Acceptance:

- A deliberately failing validator exits non-zero or produces an explicit machine-readable failure result.

### P1: Weapon State Completeness

Unity reference signal:

- `ItemSetting_Gun.ReloadModes`
- `ItemSetting_Gun.TriggerModes`
- `ItemAgent_Gun.GunStates`

DCG target:

- `scripts/items/weapon_profile.gd`
- `scripts/combat/weapon_tuning_service.gd`
- `scripts/combat/weapon_ammo_model.gd`
- `scripts/combat/weapon_controller_3d.gd`
- `scripts/player/player_equipment_controller_3d.gd`
- weapon validators

Safe migration action:

- Add missing authored fields only when they map cleanly to the existing profile/snapshot path.
- Prefer data/profile additions over controller branches.
- Do not add animation, Unity input, or Unity gun-agent state code.

Acceptance:

- Focused weapon validator proves new field resolves through `WeaponTuningService.resolve_snapshot()`.

### P1: Item Operation Service Coverage

Unity reference signal:

- `ItemUtilities.AddAndMerge`
- `ConsumeItems`
- `Count`
- `Decompose`
- `GetRepairLossRatio`
- item sent-to-storage and sent-to-character events

DCG target:

- `scripts/inventory/inventory_model.gd`
- `scripts/inventory/container_inventory_model.gd`
- `scripts/base/stash_model.gd`
- `scripts/base/base_dismantle_service.gd`
- `scripts/base/base_repair_service.gd`
- `scripts/items/item_durability_service.gd`
- existing inventory/base validators

Safe migration action:

- Prefer improving existing stack helpers and services.
- Add missing validators before changing behavior.
- Do not introduce global item events unless a real DCG flow needs them.

Acceptance:

- Stack merge, consume, dismantle, repair, and stash round-trip validators pass one at a time.

### P1: Quest Data And Sorting

Unity reference signal:

- Quest save data, quest giver IDs, quest status, sorting mode, quest relations.

DCG target:

- `scripts/quests/quest_def.gd`
- `scripts/quests/quest_state.gd`
- `scripts/quests/quest_catalog.gd`
- `scripts/ui/quest_top_menu_presenter.gd`
- quest validators

Safe migration action:

- Add only missing small concepts: quest status grouping, ordering, prerequisite relation, or clearer reward claim state.
- Keep text localization-key driven.

Acceptance:

- Quest validators prove collect, kill, location, claim reward, and UI readable status.

### P2: Shop And Economy

Unity reference signal:

- `StockShop`, stock count save data, override selling prices, merchant profile.

DCG target:

- Existing vendor/sell validator and future base/economy service.

Safe migration action:

- Only after P0/P1 stability, add a small shop stock profile or sell-price service if it supports the current loop.

Acceptance:

- Vendor validator proves buying/selling does not corrupt inventory or money.

### P2: Building/Base Upgrade Completeness

Unity reference signal:

- `BuildingManager`, building areas, rotation, building tokens, building save data.

DCG target:

- `scripts/base/base_progression.gd`
- `scripts/base/base_workbench_service.gd`
- `scripts/base/base_storage_upgrade_service.gd`
- base upgrade resources and validators

Safe migration action:

- Treat this as base upgrade/resource logic, not placement-building gameplay, unless the DCG design explicitly needs placement.

Acceptance:

- Base progression and station readability validators pass.

## Explicitly Rejected For Now

- Unity shader, URP, render feature, post-processing, particle, light-proxy, and camera code.
- Easy Save backup/persistence internals.
- Addressables or scene-reference systems.
- Unity UI code and prefab-bound UnityEvent interactions.
- Third-party demo scripts and packages from the export.
- Mini-games, Steam Workshop, achievements, aquariums, crops, bitcoin miner, black market, and perk-tree breadth until the core loop is reliable.

## Automation Progress

### 2026-07-07: P1 Localization And UI Health Pass

Unity reference signal:

- Quest, storage, item-operation, and weapon attachment systems depend on readable UI state rather than hidden fallback strings.

DCG action:

- Filled missing English localization coverage for stash storage, quest board, quest names, base storage upgrades, weapon attachment slot names, and newly surfaced attachment items.
- Localized the quest objective/progress "or" separator instead of hard-coding Chinese in `BaseScreenViewModel`.
- Fixed the raid map loot summary English format to match the existing direction/count argument order.
- Added missing needed-item source and stash sort status localization keys.

Validation:

- `validate_user_reported_correctness.gd`
- `validate_top_menu_panels.gd`
- `validate_base_stash_storage_ui.gd`
- `validate_weapon_attachment_slots.gd`

Next safe candidate:

- Continue P0/P1 health work by making validator failure semantics automation-safe, then return to small Unity-inspired gameplay service gaps.

### 2026-07-07: P0 Validator Runner Failure Semantics

Unity reference signal:

- Not a Unity feature. This protects the migration loop from reporting success when a Godot validator emits `ERROR` but the process exits 0.

DCG action:

- Added `tools/run_godot_validator.ps1` as the automation-safe entry point for focused Godot validators.
- Added `tools/validation_runner_failure_probe.gd`, a non-`validate_` probe that deliberately emits `ERROR` and exits 0 so the runner can prove it catches false passes.
- The runner preserves Godot output, exits with Godot's non-zero code when present, and otherwise treats `ERROR:`, `SCRIPT ERROR:`, or parse-error output as failure.

Validation:

- `tools/run_godot_validator.ps1 validate_user_reported_correctness.gd` returned 0.
- `tools/run_godot_validator.ps1 validation_runner_failure_probe.gd` returned 1 despite Godot itself exiting 0.

Next safe candidate:

- Use the runner for future automation cycles, then return to small Unity-inspired gameplay service gaps such as item operation coverage or quest ordering only when a focused validator exists.

### 2026-07-07: P1 Item Operation Coverage Audit

Unity reference signal:

- `InventoryExtensions.Sort`
- `ItemUtilities.AddAndMerge`
- item stack storage and round-trip behavior

DCG finding:

- No new Unity logic should be ported for these basics right now. Project DCG already has Godot-native inventory sorting, stash merge/remove/save round-trip, and container merge/remove/save round-trip coverage.
- Adding a parallel Unity-style item utility layer would increase coupling without improving the current loop.

Validation through `tools/run_godot_validator.ps1`:

- `validate_item_stack_sorter.gd` returned 0 with sorting modes value, weight, value-weight, and type covered.
- `validate_stash_model.gd` returned 0 with add/merge/remove/save round-trip and weapon mod round-trip covered.
- `validate_container_inventory_model.gd` returned 0 with capacity, stack merge, remove, save round-trip, and clean coupling covered.

Next safe candidate:

- Continue with a focused quest-ordering/status audit or a small shop/economy audit only if the matching validator is already present and passing baseline checks.

### 2026-07-07: P1 Quest Status And Objective Coverage Audit

Unity reference signal:

- Quest save data, quest giver IDs, quest status, sorting mode, quest relations, and status UI.

DCG finding:

- No Unity quest manager layer should be ported right now. Project DCG already has focused `QuestCatalog`, `QuestState`, kill/location trackers, top-menu quest presentation, reward claiming, and status grouping guarded by validators.
- Importing Unity-style quest collections or scene-bound quest giver assumptions would duplicate existing Godot services and risk UI/save coupling.

Validation through `tools/run_godot_validator.ps1`:

- `validate_quest_flow.gd` returned 0 with extraction objective progress, kill objective progress, claimable reward, save persistence, and layout coverage.
- `validate_top_menu_panels.gd` returned 0 with available/active/completed quest list coverage and UI ownership boundaries.
- `validate_quest_kill_enemy_flow.gd` returned 0 with enemy kill progress, save persistence, and live top-menu update coverage.
- `validate_location_quest_flow.gd` returned 0 with visible location interaction, saved progress, and live top-menu update coverage.

Next safe candidate:

- Audit shop/economy coverage against the Unity `StockShop` reference. Only implement a small shop stock or sell-price service if `validate_vendor_sell.gd` exposes a real gap.

### 2026-07-07: P2 Shop And Economy Coverage Audit

Unity reference signal:

- `StockShop`, stock counts, buy/sell/cache item flow, override sell prices, merchant profiles, and shop save data.

DCG finding:

- Do not port Unity `StockShop` yet. Project DCG currently supports a narrower base economy slice: selling sellable stash items through `StashVendor`, preserving crafting materials, updating money, and saving the result.
- A full stock shop would require new vendor stock data, buy UI, pricing rules, save schema, and balance decisions. That is a larger feature, not a safe migration patch while the current vertical slice is still stabilizing.
- The current sell-only slice is useful and validator-covered, so keep it as the production path until the design calls for buying or merchant stock.

Validation through `tools/run_godot_validator.ps1`:

- `validate_vendor_sell.gd` returned 0 with item value pricing, sold-item stash removal, money persistence, and unsold material preservation covered.

Next safe candidate:

- Audit base upgrade/building coverage against Unity `BuildingManager`. Treat placement-building logic as rejected unless a current validator shows a base-upgrade gap.

### 2026-07-07: P2 Base Upgrade And Building Coverage Pass

Unity reference signal:

- `BuildingManager`, building areas, rotation, building tokens, building save data, and buy/place results.

DCG action:

- Kept Unity placement-building logic rejected for now. The current DCG base slice is upgrade/station driven, not free placement.
- Filled missing localization for `workbench_fix_station` and `workbench_disassemble_station` upgrade names so station installation panels show localized upgrade names.
- Replaced prototype "connected" base station copy with player-facing station purpose text for stash, quests, workbench, medical, and default station bodies.

Validation through `tools/run_godot_validator.ps1`:

- `validate_base_progression.gd` returned 0 with upgrade data, purchase cost, save persistence, workbench tabs, crafting, blueprint research, repair station, disassemble station, starter ammo, and storage capacity covered.
- `validate_base_station_readability.gd` returned 0 with readable labels/prompts, station panel copy, stash grid, removed medical prototype flow, and clean boundaries covered.
- `validate_base_interactions.gd` returned 0 with station prompts, station panels, stash grid, and raid start path covered.

Next safe candidate:

- Return to current-loop health: run the first 10-minute or player-visible slice validator through the runner and only patch the smallest exposed gap.

### 2026-07-07: Current Player-Visible Loop Health Check

Unity reference signal:

- Use Duckov-like reference systems only to keep the first playable loop coherent: base, raid start, loot, equipment, reload, projectile hit, enemy kill, quest update, extraction, and return to base.

DCG finding:

- No migration was needed this cycle. The current player-visible loop is validator-covered and passing through the automation-safe runner.
- The immediate goal should remain stabilization and small gap-filling rather than importing broader Unity runtime assumptions.

Validation through `tools/run_godot_validator.ps1`:

- `validate_player_visible_0_2_slice.gd` returned 0 with 3D base, direct raid gate start, enemy chase/attack, loot, equip, reload, projectile hit, enemy death, quest progress, raid result, and base return covered.
- `validate_player_visible_v2_slice.gd` returned 0 with 3D base, container grid, transfer/equip, visible reload, 3D projectile, extraction, and 3D base return covered.
- `validate_ui_layout_quality_0_2.gd` returned 0 with 1280x720 and 1920x1080 fit checks for base, raid, inventory, container, top menu, Traditional Chinese text, and UI boundaries.

Next safe candidate:

- Audit combat/weapon feel coverage against Unity gun-state signals (`ReloadModes`, `TriggerModes`, `GunStates`) and only add focused profile/snapshot data if a weapon validator exposes a small missing concept.

### 2026-07-07: P1 Combat And Weapon Feel Coverage Audit

Unity reference signal:

- Searched the AssetRipper export for gun-state signals such as `ReloadModes`, `TriggerModes`, `GunStates`, reload, ammo, and recoil.
- The export did not expose portable gameplay source for those gun-state concepts under `Assets/Scripts/Assembly-CSharp`; the clear signal found this cycle was data-like recoil tuning in rule assets such as `recoilMultiplier`.

DCG finding:

- No Unity gun-state layer should be ported right now. Project DCG already has Godot-native weapon profiles, ammo profiles, attachment profiles, `WeaponTuningService.resolve_snapshot()`, `WeaponAmmoModel`, reload flow, equipment binding, HUD feedback, and recoil handling.
- Importing a parallel Unity-style weapon state machine would risk duplicating current controller/model/service boundaries without improving the validated playable loop.

Validation through `tools/run_godot_validator.ps1`:

- `validate_ammo_reload_model.gd` returned 0 with pistol data, reload consumption, controller/model binding, and clean boundaries covered.
- `validate_reload_flow.gd` returned 0 with reload input, empty-fire auto reload, backpack ammo consumption, magazine update, and clean boundaries covered.
- `validate_reload_ui.gd` returned 0 with minimal HUD reload progress visibility, completion clearing, hidden legacy panel behavior, and clean boundaries covered.
- `validate_weapon_equipment_binding.gd` returned 0 with unarmed start, pistol equip sync, HUD visibility, and clean boundaries covered.
- `validate_weapon_recoil_handling.gd` returned 0 with weapon/ammo data, recoil service output, random horizontal recoil, sustained offset, and clean boundaries covered.
- `validate_profile_tuning_architecture.gd` returned 0 with profile snapshot flow, weapon controller bridge, and data-driven enemy behavior covered.

Next safe candidate:

- Audit armor, damage mitigation, and item durability coverage against Unity defense/difficulty data. Only add or adjust focused profile/service data if the matching Godot validators expose a small, current-loop gap.

### 2026-07-07: P1 Armor, Damage, And Durability Coverage Audit

Unity reference signal:

- Searched the AssetRipper export for defense, protection, durability, damage, and difficulty signals.
- The portable reference this cycle was data-like balance: rule assets expose values such as `damageFactor_ToPlayer` and `recoilMultiplier`, and spawn presets contain durability ranges. The export did not expose a clean, engine-independent armor or durability runtime layer to port.

DCG finding:

- No Unity armor or durability runtime should be ported right now. Project DCG already has Godot-native `ArmorProfile`, durability stack state, `ItemDurabilityService`, armor mitigation, penetration, broken-armor behavior, low-durability weapon spread, ammo damage/wear modifiers, and player damage flow coverage.
- A Unity-style difficulty damage-factor system would be a design/balance feature, not a safe migration patch. Keep current damage rules stable until a difficulty profile is explicitly scoped.

Validation through `tools/run_godot_validator.ps1`:

- `validate_armor_penetration.gd` returned 0 with ammo/armor data, defense-minus-penetration formula, loaded-ammo damage, and clean boundaries covered.
- `validate_armor_durability_wear.gd` returned 0 with hit wear, final-hit breakage, no-protection after break, death preserving worn armor, and clean boundaries covered.
- `validate_broken_armor_effect.gd` returned 0 with broken armor providing no protection, full armor protection, durability state, and clean boundaries covered.
- `validate_equipment_armor_effect.gd` returned 0 with armor equip, reduced damage, visible UI, and clean boundaries covered.
- `validate_weapon_durability_wear.gd` returned 0 with service-owned wear, equipment-stack fire wear, no-ammo no-wear, worn durability loadout preservation, and clean boundaries covered.
- `validate_ammo_wear_rate.gd` returned 0 with ammo wear-rate data, fractional durability progress, loaded-ammo fire path, save-ready progress, and clean boundaries covered.
- `validate_low_durability_spread.gd` returned 0 with service-owned penalty, fresh weapon stability, low-durability spread, wear preservation, and clean boundaries covered.
- `validate_broken_weapon_fire_block.gd` returned 0 with broken weapon fire block, ammo preservation, durability preservation, depleted HUD state, and clean boundaries covered.
- `validate_ammo_damage_multiplier.gd` returned 0 with ammo damage data, direct/projectile damage, stable baseline, and clean boundaries covered.
- `validate_player_damage_flow.gd` returned 0 with accepted damage, health signal emission, HUD update, and death guard covered.

Next safe candidate:

- Audit enemy awareness and AI patrol/chase coverage against Unity NodeCanvas behavior-tree assets. Do not port behavior trees; only record or adjust focused Godot `EnemyBehaviorProfile` data if current AI validators expose a small, player-visible gap.

### 2026-07-07: P0 Enemy Awareness And First Encounter Visibility Pass

Unity reference signal:

- Searched the AssetRipper export NodeCanvas behavior-tree assets for awareness and patrol concepts.
- Portable signals included `SearchEnemyAround`, sight distance multipliers, hurt/noticed checks, aim setting, random movement around last-known positions, `forgetTime`, `traceTargetChance`, patrol ranges, and reload-if-empty actions.
- These are behavior concepts only. NodeCanvas graphs, blackboard variable IDs, Unity action classes, and serialized scene references are not portable into the Godot project.

DCG action:

- Did not port Unity behavior trees.
- Kept the existing Godot-native `EnemyBehaviorProfile` and `EnemyController3D` simple-state-machine path.
- Moved the Normal Raid `ScavengerPatrol01` from a far off-route position to a first-encounter position near the player route: `(-2.8, 0.0, 1.2)`.
- This was a small player-visible stabilization fix: it restores first enemy route visibility and keeps the player-style enemy health bar inside the HUD projection.

Validation through `tools/run_godot_validator.ps1`:

- `validate_enemy_architecture_health.gd` returned 0 after the position fix, with reachable raid enemy, clean enemy boundaries, clean UI coupling, and slice coverage.
- `validate_enemy_def.gd` returned 0 with valid scavenger data, loadable scene, and damageable wiring.
- `validate_enemy_ai.gd` returned 0 with detect/chase, damage-alert chase, search give-up, attack damage, dead stop, navigation routing, and scene wiring.
- `validate_enemy_chase_player.gd` returned 0 with normal raid detection, chase, navigation routing, visible status, and search-then-idle behavior.
- `validate_enemy_attack_player.gd` returned 0 with normal raid attack damage, HUD update, cooldown guard, and visible status.
- `validate_enemy_visible_in_raid.gd` returned 0 with visible/reachable scavenger route, label, and controller wiring.
- `validate_enemy_damageable_3d.gd` returned 0 with player-style overlay health bar, injured/dead readability, and decoupled display.
- `validate_enemy_loot_drop.gd` returned 0 with death corpse container, F interaction, container grid, repeat block, and clean UI coupling.
- `validate_enemy_player_death_result.gd` returned 0 with enemy attack, death result panel, visible lost items, and return to 3D base.
- `validate_quest_kill_enemy_flow.gd` returned 0 with normal raid enemy kill progress, saved progress, live top-menu update, and clean boundaries.
- `validate_combat_feedback_visibility.gd` returned 0 with visible attack warning, delayed windup damage, player hit feedback, and clean boundaries.
- `validate_player_visibility_v2_health.gd` returned 0 with documented known debts, guarded boundaries, and health G coverage.
- `validate_player_visible_0_2_slice.gd` returned 0 with 3D base, direct raid start, enemy chase/attack, loot, equip, reload, projectile hit, enemy death, quest progress, raid result, and base return.

Next safe candidate:

- Audit raid loot/container and locked-container coverage against Unity pickup/search-pickup signals. Do not port Unity pickup actions or scene assumptions; only patch existing Godot loot/container data or validators if a player-visible gap is exposed.

### 2026-07-07: P1 Loot, Container, And Locked-Cache Coverage Pass

Unity reference signal:

- Searched the AssetRipper export for pickup/search and loot-box signals.
- Portable concepts found this cycle were `SearchedPickup`, `AI_Talk_FoundItem`, and enemy preset `lootBoxPrefab` references.
- These are concept/data references only. NodeCanvas blackboard variables, Unity pickup actions, prefab runtime wiring, and scene assumptions are not safe to port into the Godot project.

DCG action:

- Kept the existing Godot-native loot and container path: loot tables, `LootContainer3D`, `ContainerInventoryModel`, `ContainerInventoryUI`, transfer routing, and locked-container key consumption.
- Added the existing `loot_pickup_warehouse_key.tscn` to the Normal Raid scene as `SceneProps/LootPickupWarehouseKey` so the No.11 warehouse key is player-visible before opening the locked cache.
- Moved the key pickup off the first enemy firing lane after the player-visible smoke validator caught projectile collision interference.

Validation through `tools/run_godot_validator.ps1`:

- `validate_loot_tables.gd` returned 0 with common loot, typed colored crates, codex-named rolls, invalid-entry rejection, uncataloged-item rejection, and empty-table rejection covered.
- `validate_loot_container.gd` returned 0 with container inventory creation, one-shot roll behavior, map spawn/extract coverage, clean UI coupling, and scene wiring covered.
- `validate_container_inventory_model.gd` returned 0 with capacity slots, stack merge, removal, save round trip, and clean boundaries covered.
- `validate_container_open_flow.gd` returned 0 with interaction opening UI, container-owned contents, and UIManager ownership covered.
- `validate_container_inventory_ui.gd` returned 0 with node-first panel, visible capacity, visible slots, fitting layout, and Traditional Chinese text covered.
- `validate_container_transfer.gd` returned 0 with click-to-backpack transfer, full-inventory feedback, and clean boundaries covered.
- `validate_locked_container_flow.gd` initially exposed the missing world key pickup, then returned 0 after the scene placement fix with locked visibility, key pickup, single-stack key, key consumption, container grid, and clean boundaries covered.
- `validate_user_inventory_loot_consumables_totems.gd` returned 0 with empty starter inventory, guaranteed drops, drag-only inventory direction, usable bandage, stat totems, and slot rules covered.
- `validate_player_visible_0_2_slice.gd` initially caught key-pickup collision interference on projectile feedback/hits, then returned 0 after moving the key off the firing lane with 3D base, direct raid start, enemy chase/attack, loot, equip, reload, projectile hit, enemy death, quest progress, raid result, and base return covered.

Next safe candidate:

- Audit consumables, totems, and equipment utility coverage against Unity item-use signals. Do not import Unity item-use classes or effects; only add focused Godot item/profile/service data if a current player-visible validator exposes a gap.

### 2026-07-07: P1 Consumables, Totems, And Equipment Utility Audit

Unity reference signal:

- Searched the AssetRipper export for item-use, consumable, healing, food, water, stamina, buff, and totem signals.
- The useful portable signals were category/data concepts only: `Food`, `Healing`, `Totem`, and `StatInfo` entries such as `MaxHealth`, `Stamina`, `StaminaDrainRate`, `StaminaRecoverRate`, `MaxWater`, `WaterCost`, `FoodGain`, and `HealGain`.
- The export did not expose a clean, engine-independent item-use service to port. Unity category assets, MonoBehaviour item effects, and runtime item-use assumptions should not be imported into DCG.

DCG finding:

- No runtime migration was needed this cycle. Project DCG already has a focused Godot path for this slice: `ItemDef` metadata, `ItemConsumableService` for healing/use duration rules, `PlayerInventoryActions3D` for equipment intent, `EquipmentModel` for slot legality/save round trips, inventory/codex tooltip surfaces, and loadout transfer.
- The Unity food/water/energy stat vocabulary is useful future balance inspiration, but adding survival meters now would be feature expansion rather than a safe migration patch because no current player-visible validator exposes that gap.

Validation through `tools/run_godot_validator.ps1`:

- `validate_user_inventory_loot_consumables_totems.gd` returned 0 with empty starter inventory, guaranteed drops, drag-only inventory direction, usable bandage, stat totems, and weapon slot rules covered.
- `validate_item_catalog.gd` returned 0 with 19 cataloged items and contiguous catalog numbering covered.
- `validate_equipment_model.gd` returned 0 with ready slots, legal equip, invalid equip rejection, save round trip, and clean coupling covered.
- `validate_inventory_equipment_flow.gd` returned 0 with visible backpack, primary weapon equip, ammo rejection, fitting layout, and clean boundaries covered.
- `validate_inventory_loadouts.gd` returned 0 with authored loadout coverage.
- `validate_base_to_raid_loadout.gd` returned 0 with base pending loadout preparation, raid loadout consumption, backpack ammo, equipped pistol, and synced weapon covered.
- `validate_item_tooltips.gd` returned 0 with shared container/stash/codex tooltip presenter, item hash catalog, compact weight, durability/repair readiness, needed sources, and hidden weapon mod slots covered.
- `validate_codex_item_consistency.gd` returned 0 with item data shown consistently across container, backpack, equipment, and codex surfaces.
- `validate_inventory_drag_rules.gd` returned 0 with current drag/equipment rules covered.

Next safe candidate:

- Audit difficulty/economy balance concepts against Unity rule assets and vendor/currency data. Do not add a difficulty system or vendor economy rewrite unless a focused Godot validator exposes a current-loop gap.

### 2026-07-07: P1 Difficulty, Economy, And Currency Balance Audit

Unity reference signal:

- Searched the AssetRipper export for difficulty rule, vendor, shop, sell/buy, currency, cash, reward, price, and value signals.
- Portable concepts found this cycle were data-like only: Unity rule assets expose `damageFactor_ToPlayer`, `enemyHealthFactor`, `recoilMultiplier`, `enemyReactionTimeFactor`, `spawnDeadBody`, `fogOfWar`, and dead-body persistence settings.
- Enemy presets also expose cash-drop concepts such as `hasCashChance` and `cashRange`; for example the Scav preset uses a 0.3 cash chance with a 0..100 range.
- These are balance references, not a safe runtime layer to port. A direct six-rule difficulty table, Unity shop logic, or enemy cash-drop rewrite would be a design expansion unless a current DCG validator exposes a gap.

DCG finding:

- No runtime migration was needed this cycle. Project DCG already has a focused Godot difficulty and economy path for the current vertical slice: `DifficultyProfile` resources, menu selection/save integration, cash as an `ItemDef`, item value based selling, quest money rewards, base upgrade costs, repair/dismantle/crafting costs, raid loss boundaries, and three-raid persistence.
- Keep the Unity rule values as future balancing inspiration only. The current safe path is to stabilize the existing 3-profile difficulty model before adding enemy-health scaling, recoil multipliers, fog-of-war rules, or random enemy cash drops.

Validation through `tools/run_godot_validator.ps1`:

- `validate_difficulty_system.gd` returned 0 with 3 profiles, health scaling, and menu availability covered.
- `validate_vendor_sell.gd` returned 0 with ItemDef value based selling, sold-junk removal, saved money, and retained crafting materials covered.
- `validate_early_balance.gd` returned 0 with forgiving player values, readable enemy values, progression loot, extraction pressure, and reachable upgrade targets covered.
- `validate_quest_flow.gd` returned 0 with extraction progress, kill progress, claimable quest reward, saved reward, and fitting layout covered.
- `validate_base_progression.gd` returned 0 with valid upgrade data, cost deduction, persistence, 3D base action, tab modes, recipe keys, selection save, crafting, blueprint research, repair station, dismantle station, starter ammo effect, and storage capacity covered.
- `validate_raid_loss_rules.gd` returned 0 with backpack/equipment loss, safe-pocket retention, unchanged stash, and clean boundaries covered.
- `validate_three_raid_loop_0_2.gd` returned 0 with raid 1 extraction/base upgrade, raid 2 enemy death preservation, raid 3 upgrade/kill/extract, and persistent reload coverage.

Next safe candidate:

- Audit quest, location, and base-task progression concepts against Unity quest/building/crafting references. Do not import Unity quest graphs, building prefabs, or crafting runtime assumptions; only patch focused Godot quest/base data if a validator exposes a current-loop gap.

### 2026-07-07: P1 Quest, Location, And Base-Task Progression Pass

Unity reference signal:

- Searched the AssetRipper export for quest, task, building, formula, workbench, upgrade, and base references.
- Portable concepts this cycle were data-like only: `BuildingDataCollection.asset` exposes `prefabName`, `cost`, `requireBuildings`, and `requireQuests`; `CraftingFormulas.asset` exposes formula cost/default-unlock/perk fields; `DecompositeDatabase.asset` and `QuestRelation.asset` point at dismantle and quest-relation data concepts.
- Localization references also show broad base/task vocabulary such as `Building_Workbench`, `Building_WorkbenchAdvance`, `Building_MedicStation`, `Building_TeleportMachine`, `Quest_*`, `Quest_*_Task_*`, `UI_Interact_Quest`, and `UI_Interact_UnlockFormula`.
- These are useful production references, but the Unity quest graphs, building prefabs, formula runtime wiring, and quest GUID relations are not safe to import directly into the Godot project.

DCG action:

- Kept the existing Godot-native quest/base architecture: `QuestDef`, `QuestState`, `QuestCatalog`, `LocationQuestTrigger3D`, `QuestKillTracker3D`, quest top-menu presenters, `BaseProgression`, workbench recipe/blueprint/repair/dismantle services, and save-backed base upgrade data.
- Fixed one current-loop UI/data gap exposed by validation: added the missing repair source localization keys for stash, backpack, safe pocket, and equipment rows in `data/localization/game_text.csv`.
- Did not port Unity quest graphs, building prefabs, EasySave/Addressables assumptions, or formula runtime classes.

Validation through `tools/run_godot_validator.ps1`:

- `validate_quest_model.gd` returned 0 with quest def load, extraction progress, kill readiness, reward claim, and save round trip covered.
- `validate_quest_flow.gd` returned 0 with extraction progress, kill progress, claimable reward, saved reward, and fitting layout covered.
- `validate_location_quest_flow.gd` returned 0 with visible location interaction, saved progress, live top-menu update, and clean boundaries covered.
- `validate_quest_kill_enemy_flow.gd` returned 0 with normal raid enemy kill progress, saved progress, live top-menu update, and clean boundaries covered.
- `validate_base_interactions.gd` returned 0 with visible prompt, station UI, storage grid, raid start, and Traditional Chinese text covered.
- `validate_base_progression.gd` returned 0 with upgrade data, cost deduction, persistence, 3D base action, tab modes, recipe keys, selection save, crafting, blueprint research, repair station, dismantle station, starter ammo effect, and storage capacity covered.
- `validate_base_recipe_service.gd` returned 0 with recipe data, workbench unlock, blueprint gate, row list, selection save, needed material paths, and stash crafting covered.
- `validate_base_blueprint_service.gd` returned 0 with blueprint data, stash research, recipe unlock, and save round trip covered.
- `validate_base_repair_service.gd` initially exposed missing localized source labels, then returned 0 after the localization fix with fix-station gate, stash/carried rows, durability, money cost, save round trip, and 3D base repair covered.
- `validate_base_dismantle_service.gd` returned 0 with disassemble-station gate, stash rows, material outputs, capacity check, and 3D base dismantle covered.
- `validate_base_station_readability.gd` returned 0 with readable station labels, clear prompts, stash grid, Traditional Chinese panels, removed medical station debt, and clean boundaries covered.
- `validate_base_to_raid_loadout.gd` returned 0 with base pending loadout preparation, raid loadout consumption, backpack ammo, equipped pistol, and synced weapon covered.
- `validate_ui_text_quality.gd` returned 0 with multi-locale readiness, required Traditional Chinese/English keys, clean text, and fitting layout covered.

Next safe candidate:

- Audit save/settings/menu shell concepts against Unity boot/menu/settings references. Do not port Unity Addressables, EasySave, UI prefabs, URP, or scene manager assumptions; only patch focused Godot save/settings/menu data if a current validator exposes a small gap.

### 2026-07-07: P1 Save, Settings, And Menu Shell Audit

Unity reference signal:

- Searched the AssetRipper export for save, settings, option, audio, volume, language, main menu, startup, and slot references.
- Portable concepts this cycle were shell/UI concepts only: the export contains `Scenes/MainMenu`, `Scenes/Startup`, language-specific `Options.txt` files with screen mode, resolution, language, ambient-occlusion, grass, and run-input option labels.
- The export also contains `EasySave3.dll`, `Resources/es3/ES3Defaults.asset` with `SaveFile.es3`, Addressables `StreamingAssets/aa/settings.json`, and `FMODStudioSettings.asset`.
- These are not safe runtime migration sources for DCG. EasySave, Addressables catalogs, FMOD bank settings, Unity scene managers, and UI prefabs should stay reference-only.

DCG finding:

- No runtime migration was needed this cycle. Project DCG already has a focused Godot path for the current shell: `SaveGameManager` JSON slot data/schema normalization, `SaveSlotPanel`, `MainMenu`, `DifficultySelectPanel`, `SettingsPanel`, `PauseMenu`, localized settings text, language selection, display mode/resolution controls, and Master/BGM/SFX audio buses.
- Unity's option labels confirm useful future settings categories such as ambient occlusion, grass display, and run-input style, but adding them now would be feature expansion rather than a safe migration patch because the current validators do not expose a player-loop gap.

Validation through `tools/run_godot_validator.ps1`:

- `validate_save_slots.gd` returned 0 with 3 slots, new-game save, continue/load, and schema v1 covered.
- `validate_save_slot_panel.gd` returned 0 with 3 rows and refresh-ready UI covered.
- `validate_audio_settings.gd` returned 0 with Master/BGM/SFX audio buses covered.
- `validate_pause_menu.gd` returned 0 with pause open/close flow covered.
- `validate_user_reported_correctness.gd` returned 0 with no-briefing raid gate, English locale, corpse-loot F grid, pistol unequip, safe-pocket return to base, and money wallet sync covered.
- `validate_ui_text_quality.gd` returned 0 with multi-locale readiness, required Traditional Chinese/English keys, clean text, and fitting layout covered.

Next safe candidate:

- Audit map, level routing, and raid-location selection concepts against Unity level/startup/map references. Do not port Unity scenes, nav caches, Addressables catalogs, terrain data, or scene-loading assumptions; only patch existing Godot map/top-menu/raid selection data if a focused validator exposes a small gap.

### 2026-07-07: P1 Map, Level Routing, And Raid-Location Audit

Unity reference signal:

- Searched the AssetRipper export for map, level, path cache, graph cache, terrain, location, raid, startup, main-menu, and loading references.
- Portable concepts this cycle were high-level only: many `Scenes/Level_*` folders, `TerrainData` assets, `MapSprite.shader`, `AstarPathfindingProject.dll`, and path/cache byte assets such as `GroundZeroPathChche.bytes`, `StormZonePathChche.bytes`, `PathChche_warehouse.bytes`, `GraphCache3_Base.bytes`, and similar map navigation caches.
- These references confirm that a Duckov-like game needs explicit map identity, navigation/pathing, top-menu route information, raid session state, and base return routing.
- Unity scenes, terrain data, Astar caches, Addressables scene catalogs, shaders, and scene-loading assumptions are not safe to port directly into DCG.

DCG finding:

- No runtime migration was needed this cycle. Project DCG already has the current vertical-slice routing path covered by Godot-native `RaidSession`, `SaveGameManager` scene routing, pending raid loadout transfer, `NavigationManager3D`, `MapTopMenuPanel`, location quest triggers, raid HUD, raid result application, and return-to-3D-base flow.
- Unity's large map list is useful future production inspiration, but adding multiple raid locations now would be feature expansion. The current safe path is to keep the single validated `refuge_outskirts` style loop stable until map selection is deliberately scoped with data resources and validators.

Validation through `tools/run_godot_validator.ps1`:

- `validate_top_menu_map_panel.gd` returned 0 with visible title, removed body debt, fitting layout, and clean boundaries covered.
- `validate_navigation_manager_3d.gd` returned 0 with blocker rebake, enemy routing, and raid scene wiring covered.
- `validate_raid_session.gd` returned 0 with active begin state, mutually exclusive extraction/death, serializable result schema, and scene wiring covered.
- `validate_base_to_raid_loadout.gd` returned 0 with base pending loadout preparation, raid loadout consumption, backpack ammo, equipped pistol, and synced weapon covered.
- `validate_location_quest_flow.gd` returned 0 with visible location interaction, saved progress, live top-menu update, and clean boundaries covered.
- `validate_raid_hud_minimal_goal.gd` returned 0 with hidden legacy panel, visible combat HUD, route details in top menu, fitting layout, and clean boundaries covered.
- `validate_raid_return_to_base_3d.gd` returned 0 with result application, 3D base destination, extracted stash persistence, and cleared backpack covered.
- `validate_player_visible_0_2_slice.gd` returned 0 with 3D base, direct raid start, enemy chase/attack, loot, equip/reload, projectile hit, enemy death, quest progress, result, and base return covered.
- `validate_three_raid_loop_0_2.gd` returned 0 with raid 1 extraction/base upgrade, raid 2 enemy death preservation, raid 3 upgrade/kill/extract, and persistent reload covered.
- `validate_raid_briefing_ui.gd` returned 0 with briefing removed, direct-start raid gate, gameplay load, and clean boundaries covered.

Next safe candidate:

- Audit player input, interaction prompts, and action binding concepts against Unity input/options references. Do not port Unity Input System actions, UI prefabs, or MonoBehaviour interaction components; only patch existing Godot input/interaction data if a focused validator exposes a current-loop gap.

### 2026-07-07: P1 Input, Interaction Prompt, And Action Binding Audit

Unity reference signal:

- Searched the AssetRipper export for input, action, option, controller, and interaction references.
- Portable concepts this cycle were high-level only: `Unity.InputSystem.dll`, `Unity.InputSystem.ForUI.dll`, `ProjectSettings/InputManager.asset`, `Assets/MonoBehaviour/InputSystem.inputsettings.asset`, `Assets/MonoBehaviour/Duckov Controls.asset`, `Assets/MonoBehaviour/DefaultInputActions.asset`, `Assets/MonoBehaviour/FcController.asset`, `Assets/MonoBehaviour/InteractVolume Profile.asset`, and `Options_RunInputModeSettings`.
- These references confirm that a Duckov-like loop needs explicit movement, sprint/dodge, reload/fire, pause/top-menu, pickup/container, corpse-loot, base-station, and locked-cache interaction affordances.
- Unity Input System assets, MonoBehaviour interaction components, UI prefabs, generated action wrappers, and input option runtime assumptions are not safe to import directly into DCG.

DCG finding:

- No runtime migration was needed this cycle. Project DCG already owns this layer through Godot-native `project.godot` input actions, `PlayerInputReader3D`, `PlayerController3D` reload/fire handling, `UIManager` input blocking, `LootContainer3D` prompts, corpse container F interaction, base interaction prompts, inventory drag/drop controllers, equipment UI, top-menu tabs, pause menu, and localized prompt keys.
- The current Godot path deliberately uses direct Godot input and focused UI/services instead of copying Unity action maps. Adding remapping UI or alternate run-input modes would be a future scoped settings feature, not a safe migration patch for this cycle.

Validation through `tools/run_godot_validator.ps1`:

- `validate_user_corrected_inventory_direction.gd` returned 0 with weapon-mod, equipment UI, stash-left, and container-sort direction checks covered.
- `validate_inventory_drag_rules.gd` returned 0 with drag rules covered.
- `validate_inventory_equipment_flow.gd` returned 0 with visible backpack, primary weapon equip, ammo rejection, fitting layout, and clean boundaries covered.
- `validate_container_open_flow.gd` returned 0 with interaction opening UI, container-owned contents, and UIManager ownership covered.
- `validate_container_transfer.gd` returned 0 with click-to-backpack transfer, full-backpack feedback, and clean boundaries covered.
- `validate_locked_container_flow.gd` returned 0 with visible locked cache, key pickup, single key stack, key consumption, container grid, and clean boundaries covered.
- `validate_enemy_loot_drop.gd` returned 0 with corpse container, F key interaction, container grid, repeat blocking, and clean UI coupling covered.
- `validate_base_interactions.gd` returned 0 with visible prompt, station UI, stash storage grid, raid start, and Traditional Chinese text covered.
- `validate_reload_flow.gd` returned 0 with R key binding, empty-fire auto reload, backpack ammo consumption, magazine update, and clean boundaries covered.
- `validate_pause_menu.gd` returned 0 with pause open/close flow covered.
- `validate_top_menu_panels.gd` returned 0 with quest/status/map tabs, available/active/completed lists, fitting layout, UIManager state ownership, and clean boundaries covered.
- `validate_user_reported_correctness.gd` returned 0 with no-briefing raid gate, English locale, corpse-loot F grid, pistol unequip, safe-pocket return to base, and money wallet sync covered.
- `validate_ui_text_quality.gd` returned 0 with multi-locale readiness, required Traditional Chinese/English keys, clean text, and fitting layout covered.

Next safe candidate:

- Audit NPC, dialogue, vendor, and quest-board interaction concepts against Unity NPC/dialogue/merchant references. Do not port Unity dialogue prefabs, UnityEvents, NodeCanvas graphs, scene object references, or MonoBehaviour interaction components; only patch existing Godot vendor/quest-board/dialogue data if focused validators expose a current-loop gap.

### 2026-07-07: P1 NPC, Vendor, Dialogue, And Quest-Board Interaction Audit

Unity reference signal:

- Searched the AssetRipper export for NPC, dialogue, merchant, vendor, shop, sell/buy, quest-board, quest-giver, talk, and conversation references.
- Portable concepts this cycle were mostly localization/design signals: `Building_Merchant_Equipment`, `Building_Merchant_Normal`, `Building_Merchant_Weapon`, `Building_QuestGiver`, `MerchantName_*`, `Dialogue_Quest_*`, `UI_Interact_Quest`, `UI_Sell`, `UI_StockShop_PurchasedNotification`, `UI_Quest_NotifyClaimAtNPC`, `Merchant_Myst_Peddle*`, and related shop/quest-board labels.
- These references confirm that a Duckov-like loop benefits from clear base quest-board entry, sell/buy affordances, NPC/merchant identity, short dialogue flavor, and quest reward handoff text.
- Unity dialogue prefabs, UnityEvents, scene object references, generated dialogue graphs, NodeCanvas-style runtime assumptions, and shop/merchant MonoBehaviours are not safe to import directly into DCG.

DCG action:

- Kept DCG's current Godot-native interaction split: `BaseInteractionController3D` opens stations, `BaseInteractionQuestBoard` owns base quest-board context/action data, `UIManagerQuestActions` handles top-menu quest actions, `StashVendor` owns sell-all-junk rules, and quest/vendor UI keeps persistent state in save data rather than scene object references.
- Applied one small localization-safety fix in `scripts/ui/ui_manager_quest_actions.gd`: the `ui.top.quest_cancelled` fallback is now `Quest cancelled.` instead of Chinese text, so a missing translation cannot leak Chinese into English mode.
- Did not add NPC dialogue runtime or vendor buy menus this cycle. Unity's merchant/dialogue data suggests future content direction, but adding those systems now would be feature expansion unless scoped with Godot data resources and focused validators.

Validation through `tools/run_godot_validator.ps1`:

- `validate_top_menu_panels.gd` returned 0 with quest board accept/cancel style flows, status/map tabs, available/active/completed lists, fitting layout, UIManager state ownership, and clean boundaries covered.
- `validate_base_interactions.gd` returned 0 with visible prompts, station UI, stash storage grid, raid start, quest board, and Traditional Chinese text covered.
- `validate_quest_model.gd` returned 0 with quest definition loading, extraction progress, kill readiness, reward claim, and save round trip covered.
- `validate_quest_flow.gd` returned 0 with extraction progress, kill progress, claimable reward, saved reward, and fitting layout covered.
- `validate_vendor_sell.gd` returned 0 with ItemDef value-based selling, sold-junk removal, saved money, and retained crafting materials covered.
- `validate_user_reported_correctness.gd` returned 0 with no-briefing raid gate, English locale, corpse-loot F grid, pistol unequip, safe-pocket return to base, and money wallet sync covered.
- `validate_ui_text_quality.gd` returned 0 with multi-locale readiness, required Traditional Chinese/English keys, clean text, and fitting layout covered.

Next safe candidate:

- Audit status effects, hunger/thirst/stamina, and tutorial/road-sign hint concepts against Unity dialogue/options/status references. Do not port Unity status MonoBehaviours, particle/shader effects, or scene hints directly; only patch existing Godot consumable/status/HUD data if focused validators expose a current-loop gap.

### 2026-07-07: P2 Status Effects, Hunger-Thirst, Stamina, And Tutorial-Hint Audit

Unity reference signal:

- Searched the AssetRipper export for buff, status, stamina, hunger, thirst, hydration, energy, tutorial, guide, and road-sign references.
- Portable concepts this cycle were design-level only: `Buff_Starve`, `Buff_Thirsty`, `Buff_Weight_*`, `Buff_Pain`, `Buff_Heal`, `Buff_Freeze`, `Buff_Cold`, `Usage_Energy`, `Usage_Water`, `Stat_Stamina`, `Stat_MaxEnergy`, `Stat_MaxWater`, `UI_PlayerStatsView`, `UI_PlayerStats_Energy`, `UI_PlayerStats_Hunger`, `UI_PlayerStats_Thurst`, `UI_BuffView`, `Guide_Run`, `Dialogue_Roadsign_Dash`, `Dialogue_Roadsign_HeadShot`, and `Dialogue_Roadsign_StormWarning`.
- These references confirm future direction for survival pressure: energy/hydration, weight-based movement penalties, status-effect display, short tutorial hints, and environmental hazards.
- Unity status MonoBehaviours, buff runtime components, particle/shader effects, scene road signs, option flags, and status persistence assumptions are not safe to import directly into DCG.

DCG finding:

- No runtime migration was needed this cycle. DCG already covers the current vertical slice through Godot-native health/stamina on `PlayerController3D`, localized raid HUD vitals, status top-menu summaries, timed bandage use through `ItemConsumableService`, passive totem stat effects, armor/durability visibility, and first-route hints.
- A full hunger/thirst/buff runtime would need a scoped Godot data model, save migration/defaults, UI display rules, item effect authoring, and balancing validators. Adding it now would be feature expansion and risks breaking the stabilized base -> raid -> loot -> extract loop.
- Unity's road-sign and guide text is useful later as tutorial content inspiration, but current DCG route hints already cover the validated first-path needs.

Validation through `tools/run_godot_validator.ps1`:

- `validate_user_inventory_loot_consumables_totems.gd` returned 0 with empty starter backpack, guaranteed drops, drag-only pickup, usable bandage, totem stat effects, and weapon slot rules covered.
- `validate_raid_hud_minimal_goal.gd` returned 0 with hidden legacy panel, visible combat HUD, top-menu route detail, fitting layout, and clean boundaries covered.
- `validate_top_menu_panels.gd` returned 0 with quest/status/map tabs, status tab player model data, fitting layout, UIManager state ownership, and clean boundaries covered.
- `validate_base_3d_runtime_hud.gd` returned 0 with base stash tab, raid backpack tab, pause escape, visible crosshair, and raid gate gameplay transition covered.
- `validate_ui_layout_quality_0_2.gd` returned 0 across 1280x720 and 1920x1080 with base, raid, inventory, container, top-menu, text, and clean boundaries covered.
- `validate_early_balance.gd` returned 0 with forgiving player values, readable enemies, progression loot, extraction pressure, and reachable upgrades covered.
- `validate_ui_text_quality.gd` returned 0 with multi-locale readiness, required Traditional Chinese/English keys, clean text, and fitting layout covered.

Next safe candidate:

- Audit codex, notes, intel, and item knowledge concepts against Unity item/note/localization references. Do not port Unity note prefabs, Addressables, scene objects, or UI prefabs; only patch existing Godot item codex/category/localization data if focused validators expose a current-loop gap.

### 2026-07-07: P1 Codex, Notes, Intel, And Item-Knowledge Audit

Unity reference signal:

- Searched Unity localization/data references for item, note, intel, guide, inspect, quest item, recipe, and codex-adjacent terms.
- Portable concepts this cycle were item knowledge categories and readable inspection labels: `Item_InformationFiles`, `Item_Letter`, `Item_Quest_*`, `Item_Note_*`, `Note_*_Title`, `Note_*_Content`, `Tag_Information`, `UI_Item_Inspect`, `UI_Item_Use`, `UI_ItemRepair_*`, and guide/tutorial item text.
- Unity note prefabs, Addressables entries, scene note objects, UI prefabs, and bulk note/localization content are not safe to import into DCG. They are content/runtime assumptions rather than portable gameplay logic.

DCG action:

- Extended `scripts/ui/item_codex_presenter.gd` so Codex categories no longer collapse item-knowledge types into `other`.
- Added Godot-native categories for `crafting`, `electronics`, `key`, `loot`, `currency`, `valuable`, `intel`, `quest`, `recipe`, and `explosive`, keeping the existing weapon/ammo/equipment/attachment/totem/medical/food order stable.
- Kept category and type colors centralized in the Codex presenter, including a gold currency color instead of the generic fallback.
- Added localized category rows in `data/localization/game_text.csv` for `zh_TW`, `en`, `ja`, and `zh_CN`.
- Updated focused validators so category grouping and shared tooltips now expect material/key/loot/currency/intel-style categories instead of the old generic `Other` bucket.

Validation through `tools/run_godot_validator.ps1`:

- `validate_codex_category_grouping.gd` returned 0 with the expanded item-knowledge category order and localized category names covered.
- `validate_codex_item_consistency.gd` returned 0 with container, backpack, equipment, and Codex item display ownership covered.
- `validate_item_codex_layout.gd` returned 0 across 1280x720, 1920x1080, 2048x960, and 2560x1200.
- `validate_item_tooltips.gd` returned 0 with material tooltip type now showing `Crafting Material`, compact total weight, needed sources, durability, and shared tooltip behavior covered.
- `validate_item_catalog.gd` returned 0 with 19 cataloged items and max number 19.
- `validate_user_reported_correctness.gd` returned 0 with no-briefing raid gate, English locale, corpse-loot F grid, pistol unequip, safe-pocket return to base, and money wallet sync covered.
- `validate_ui_text_quality.gd` returned 0 with multi-locale readiness, required Traditional Chinese/English keys, clean text, and fitting layout covered.

Next safe candidate:

- Audit save/settings/menu/audio/input-adjacent polish against Unity option and startup references that have not yet become Godot data. Do not port Unity options files, EasySave defaults, generated input assets, FMOD, or scene menu prefabs; only patch existing Godot settings/localization/menu data if focused validators expose a current-loop gap.

### 2026-07-07: P1 Save, Settings, Menu, Audio, And Input-Adjacent Shell Audit

Unity reference signal:

- Re-checked shell/settings references in the AssetRipper export: `Scenes/MainMenu`, `Scenes/Startup`, language-specific `Resources/*/Options.txt`, `DefaultInputActions.asset`, `Duckov Controls.asset`, `InputSystem.inputsettings.asset`, `FMODStudioSettings.asset`, and `Resources/es3/ES3Defaults.asset`.
- Portable concepts were limited to settings-contract shape: screen mode, resolution, language, audio/input-adjacent option labels, startup/main-menu separation, and a dedicated save/settings backend.
- Unity `EasySave3`, FMOD settings, generated Input System assets, scene menu prefabs, URP volumes, and `Options.txt` files are not safe runtime sources for DCG and should remain reference-only.

DCG action:

- Kept DCG's existing Godot-native shell: `GameSettings`, `SaveGameManager`, `MainMenu`, `SaveSlotPanel`, `SettingsPanel`, `PauseMenu`, localization CSV, and Godot audio buses.
- Added a small safety patch in `scripts/settings/game_settings.gd`: language values now normalize to the currently supported locales (`zh_TW` and `en`), and display mode values normalize to the supported Godot modes (`fullscreen` and `windowed`).
- Extended `tools/validate_audio_settings.gd` so the settings contract guards unsupported Unity-style or stale config values such as `ja` language selection and `borderless` display mode without adding those feature paths prematurely.
- Did not add ambient-occlusion, grass, run-input mode, FMOD, EasySave, or Unity input-map migration. Those would require separate Godot data/UI/input design and are feature expansion unless a focused validator exposes a current-loop gap.

Validation through `tools/run_godot_validator.ps1`:

- `validate_audio_settings.gd` returned 0 with Master/BGM/SFX buses and locale/display normalization covered.
- `validate_save_slot_panel.gd` returned 0 with three load rows, refresh-ready UI, and main-menu load panel layout covered.
- `validate_save_slots.gd` returned 0 with three slots, new-game save, continue/load, schema v1, legacy defaults, and save round trip covered.
- `validate_pause_menu.gd` returned 0 with pause open/close, tree pause state, and mouse visibility covered.
- `validate_ui_text_quality.gd` returned 0 with multi-locale readiness, required Traditional Chinese/English keys, clean text, fitting layout, and settings language selector policy covered.

Next safe candidate:

- Audit tutorial/action-hint readability against Unity guide/input references. Do not port Unity guide scenes, animated prefabs, InputSystem assets, or road-sign scene objects; only patch existing Godot prompt/localization/HUD hint data if focused validators expose a current-loop readability gap.

### 2026-07-07: P1 Tutorial, Action-Hint, And Pickup Prompt Readability Audit

Unity reference signal:

- Re-checked action-hint references in the AssetRipper export: localized `Indicator_Map`, `Indicator_Dodge`, `Indicator_Reload`, `Indicator_Run`, `Tips_4`, `RunInputMode_*`, and road-sign dialogue keys.
- Portable concept this cycle was narrow: player-facing action prompts should name the action, not only the key.
- Unity road-sign scene objects, generated InputSystem assets, run-input settings, animated guide prefabs, and tutorial scene assumptions are not safe to import into DCG.

DCG action:

- Kept DCG's existing Godot interaction model and prompt ownership in `LootPickup3D`.
- Updated `prompt.pickup` in `data/localization/game_text.csv` from a bare key prompt to an action-readable prompt: `按 E 拾取物品` / `Press E to pick up`.
- Extended `tools/validate_user_reported_correctness.gd` so English localization now guards `prompt.pickup` and requires the pickup action wording instead of accepting a vague `Press E` prompt.
- Did not add Unity input maps, tutorial road signs, sprint mode settings, or new HUD indicator systems. Those remain separate Godot design tasks if the current loop exposes a real readability gap.

Validation through `tools/run_godot_validator.ps1`:

- `validate_user_reported_correctness.gd` returned 0 with raid gate, English locale, corpse-loot F grid, unequip, safe-pocket return, money wallet sync, and pickup prompt wording covered.
- `validate_ui_text_quality.gd` returned 0 with multi-locale readiness, required Traditional Chinese/English keys, clean text, and fitting layout covered.
- `validate_player_visible_0_2_slice.gd` returned 0 with base, direct raid gate, enemy chase/attack, loot/equip/reload, projectile hit, enemy death, quest, result, and return-to-base route covered.

Next safe candidate:

- Audit reload/ammo/action feedback readability against Unity `Indicator_Reload`, `Tips_4`, and current DCG weapon HUD behavior. Do not port Unity InputSystem actions, ammo-switch code, road-sign objects, or tutorial prefabs; only patch existing Godot weapon/HUD localization or focused validators if they expose a current-loop readability gap.

### 2026-07-07: P1 Reload, Ammo, And Action Feedback Localization Audit

Unity reference signal:

- Re-checked reload and action-feedback references in the AssetRipper export: `Indicator_Reload`, `Input_Reload`, `PopText_Reloading`, `Tips_4`, and reload-related stat/perk/totem labels.
- Portable concept this cycle was narrow: reload/action state and loaded-ammo wording should be explicit localized HUD text instead of relying on fallback strings.
- Unity InputSystem assets, ammo-switch code, perk/totem systems, road-sign tutorial objects, and scene/prefab assumptions are not safe to import into DCG.

DCG action:

- Kept DCG's existing Godot-native weapon HUD flow and `PlayerHud3D` ownership.
- Added localized HUD keys in `data/localization/game_text.csv` for `zh_TW`, `en`, `ja`, and `zh_CN`: `ui.raid_hud.reloading`, `ui.raid_hud.reload_ready`, `ui.raid_hud.reload_complete`, `ui.raid_hud.reload_cancelled`, `ui.raid_hud.weapon_status_using_item`, and `ui.player_hud.loaded_bullets`.
- Updated `tools/validate_reload_ui.gd` so ammo text assertions use `ui.player_hud.loaded_bullets` instead of stale hardcoded text, and added key presence guards for reload HUD wording.
- Updated `tools/validate_shooting_feedback_hud.gd` so zh-state assertions force `zh_TW` and verify translated weapon-status keys, avoiding saved user settings or English locale pollution.
- Extended `tools/validate_user_reported_correctness.gd` so English localization now guards the new reload/action HUD keys against CJK leakage.

Validation through `tools/run_godot_validator.ps1`:

- `validate_reload_ui.gd` returned 0 with reload progress visibility, completion clearing, hidden legacy panel, translated loaded-ammo wording, and localization keys covered.
- `validate_shooting_feedback_hud.gd` returned 0 with unarmed, empty, ready, and reloading weapon status text covered under forced `zh_TW`.
- `validate_user_reported_correctness.gd` returned 0 with English no-CJK checks including reload/action HUD keys.
- `validate_ui_text_quality.gd` returned 0 with multi-locale readiness, required Traditional Chinese/English keys, clean text, and fitting layout covered.

Next safe candidate:

- Audit item-use/consumable action feedback readability against Unity use/consume/heal references. Do not port Unity item effects, buffs, InputSystem actions, or prefabs; only patch existing Godot item-use HUD/localization/validators if a focused readability gap is exposed.

### 2026-07-07: P1 Consumable Use And Healing Feedback Localization Audit

Unity reference signal:

- Re-checked use/healing references in the AssetRipper export: `UI_Item_Use`, `UI_Drink`, `Usage_HealValue`, `Tips_0`, `Item_Bandage`, first-aid item descriptions, and food/medic tags.
- Portable concept this cycle was narrow: consumable use should show explicit localized action feedback while the existing Godot bandage flow is running.
- Unity item-effect components, buff/status-effect systems, InputSystem actions, food/drink mechanics, medical station prefabs, and scene/prefab assumptions are not safe to import into DCG.

DCG action:

- Kept DCG's existing Godot-native consumable rules in `ItemConsumableService`, `PlayerController3D.use_inventory_stack()`, and the current `item_use_progress_changed` signal.
- Added localized item-use HUD keys in `data/localization/game_text.csv` for `zh_TW`, `en`, `ja`, and `zh_CN`: `ui.item_use.using_format`, `ui.item_use.complete`, and `ui.item_use.cancelled`.
- Updated `scripts/ui/raid_hud_panel.gd` so consumable-use progress, completion, and cancellation no longer depend on empty player-facing fallbacks.
- Extended `tools/validate_user_inventory_loot_consumables_totems.gd` so it loads the CSV through `LocalizationBootstrap`, verifies item-use HUD keys, confirms the English progress label resolves to `Using Bandage`, and keeps the existing bandage heal/consume runtime check.
- Extended `tools/validate_user_reported_correctness.gd` so English localization now guards the new item-use HUD keys against CJK leakage.

Validation through `tools/run_godot_validator.ps1`:

- `validate_user_inventory_loot_consumables_totems.gd` returned 0 with starter inventory, guaranteed crate drops, bandage data/use, totems/equipment, and item-use HUD localization covered.
- `validate_user_reported_correctness.gd` returned 0 with English no-CJK checks including the new item-use HUD keys.
- `validate_ui_text_quality.gd` returned 0 with multi-locale readiness, required Traditional Chinese/English keys, clean text, and fitting layout covered.

Next safe candidate:

- Audit damage/bleeding/pain-adjacent feedback against Unity health-effect references. Do not port Unity buff systems, bleeding status effects, painkillers, medical prefabs, or stat managers; only patch existing Godot damage/HUD/localization/validators if a current player-visible feedback gap is exposed.

## Automation Loop

Every automation cycle should:

1. Re-read this inventory and the programming spec short entry.
2. Check the current dirty tree and avoid overwriting unrelated user changes.
3. Pick the highest-priority candidate that can be safely progressed.
4. Inspect current DCG owner scripts and validators before editing.
5. Prefer a validator or inventory refinement if runtime implementation risk is high.
6. Run the smallest relevant validator one at a time through `tools/run_godot_validator.ps1` when possible.
7. Treat `ERROR` text as failure even when raw Godot exit code is 0.
8. Report what changed, what was validated, and which candidate is next.
