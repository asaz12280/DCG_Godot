# Project DCG Early Development Plan

Last updated: 2026-07-01

## Purpose

This document defines the early development target for Project DCG: a small, playable, repeatable extraction-survival vertical slice inspired by Escape From Duckov, but scoped for fast Godot/Codex-driven iteration.

The goal is not to build content volume first. The goal is to prove that the core loop feels right, the architecture can scale, and new content can later be added through data/resources instead of rewriting systems.

## Reference Summary

### Current Project State

Already implemented in the current Godot project:

- Main menu, difficulty selection, settings, pause menu, save-slot UI, and localization bootstrap.
- Player movement, mouse facing, sprint, stamina, dodge, carry-weight speed penalty, and basic HUD.
- Data-driven `ItemDef` resources and a 21-item catalog.
- Player-owned `InventoryModel` with stacking, sorting, splitting, drag merge/swap, drop behavior, and backpack UI.
- Item codex grid/detail UI driven by item resources.
- World pickup flow that adds items to the player inventory.
- Basic combat domain with `DamageEvent`, `Damageable3D`, and `WeaponController3D`.
- A test gameplay scene with props, loot pickup, player, HUD, and a damageable target.
- Validation scripts for item catalog, UI foundation, inventory drag rules, gameplay architecture, combat, difficulty, save slots, audio settings, and pause menu.

Key missing parts:

- No complete raid loop yet.
- No extraction success/failure result screen.
- No persistent stash that receives extracted loot.
- No death-loss rule.
- No enemy AI.
- No loot tables or loot containers.
- No quest/base/workbench loop.
- Save slots store only basic run metadata, not full progression.

### Escape From Duckov Takeaways

Escape From Duckov is publicly positioned as a single-player top-down PvE extraction/looter shooter with survival, base building, gear upgrades, scavenging, weapon customization, quests, skill growth, and Steam Workshop support. Its store page emphasizes:

- Safety of base versus danger outside.
- Five maps with changing loot, enemies, and weather.
- Extraction pressure: leave in time or risk losing everything.
- Loot economy: meds, gear, collectibles, scrap, selling, crafting, base upgrades.
- 50+ weapons and weapon modding.
- Blueprints, stronger gear, skill trees, NPC quests, and 50+ hours of content.

For DCG, the useful lesson is not "make many maps and weapons now." The useful lesson is that the game is held together by one repeatable tension loop:

Prepare -> enter danger -> loot/fight -> decide greed versus safety -> extract or lose -> convert loot into progress -> repeat.

## Design Direction

### Target Genre

Single-player top-down 3D PvE extraction survival RPG.

### Early Player Fantasy

The player is a small armed survivor entering a dangerous collapsed zone. Each run should feel like a small gamble: grab useful supplies, survive a fight, then decide whether to push for more or extract safely.

### Early Emotional Targets

Using the MDA lens:

- Mechanics: movement, shooting, inventory, loot, extraction, death loss, stash, upgrades.
- Dynamics: greed versus caution, weight pressure, route planning, deciding whether one more container is worth the risk.
- Aesthetics: tension, discovery, relief after extraction, satisfaction from turning junk into progress.

### Design Pillars

1. **Complete the loop before adding volume.**
   One map, one stash, one extraction rule, one enemy type, one upgrade is more valuable than ten disconnected systems.

2. **Data first, art later.**
   Items, loot tables, enemies, maps, quests, and upgrades should be resources/configuration where possible. Early visuals can use primitives, simple materials, and existing placeholder props.

3. **Readable top-down combat.**
   A player should understand why they were hit, why they died, and how to avoid it next time.

4. **Loss should hurt, not erase progress.**
   Death loses raid inventory, but stash/base/quest progress remains. Safe pockets can protect a small amount of loot.

5. **Codex automation must have guardrails.**
   Every system addition should include a validation script or runtime check so automated development can move quickly without quietly breaking older behavior.

## Early Version Definition

The first target version is **Dev Slice 0.1: First Raid Loop**.

This version is successful when a player can:

1. Start from the main menu.
2. Choose a difficulty.
3. Enter one small raid map.
4. Move, aim, sprint, dodge, and shoot.
5. Pick up or loot several items.
6. Fight at least one enemy.
7. Reach an extraction zone.
8. See a raid result screen.
9. Move extracted loot into a persistent stash.
10. Start another raid with saved stash state.

### What This Version Must Prove

- The extraction loop is fun enough to repeat.
- Inventory pressure matters.
- The player can understand combat and extraction goals.
- Stash persistence works.
- Adding a new item, loot table entry, enemy profile, or map pickup does not require rewriting UI code.
- Codex can safely continue development by running validation commands after each slice.

### What This Version Must Not Chase Yet

- Multiple finished maps.
- 50+ weapons.
- Weapon attachment UI.
- Complex weather.
- Full base-building UI.
- Full quest chain.
- Multiple vendors.
- Final character art.
- Final map art.
- Steam Workshop/mod support.
- Complex procedural generation.

## Core Loop Spec

### Base Phase

Early base can be a UI screen, not a full 3D room.

Required:

- Stash view with extracted items.
- Start raid button.
- Current difficulty display.
- Basic money display.
- One upgrade or workbench action using extracted loot.

Optional after the loop works:

- Vendor sell button.
- Simple map select.
- Quest board.

### Raid Phase

Required:

- Spawn player into `Refuge Outskirts` test map.
- Spawn loot from a small loot table.
- Spawn one or two enemies.
- Show extraction objective.
- Let player extract by staying inside extraction zone for a short timer.
- Track raid result: extracted, died, abandoned.

### Result Phase

Required:

- Display extracted item list.
- Move extracted backpack/safe-pocket items to stash on success.
- On death, keep only safe-pocket items if safe pockets are implemented in the save result.
- Save persistent state.
- Offer Continue to Base and Start Another Raid.

## Early Content Plan

### Map 1: Refuge Outskirts

Purpose: teach movement, loot, combat, and extraction.

Suggested layout:

- Player spawn near south edge.
- Small camp area with 2-3 loot containers.
- One open combat area with clear cover.
- One locked or blocked future area as visual promise only.
- Extraction zone on the opposite side.

Art rules:

- Use existing floor, trees, rocks, fence, props, simple boxes/barrels.
- Use color-coded debug materials for loot containers, extraction, and enemy zones.
- Do not create final environment art until the loop is approved.

### Early Items

Use a small subset of the existing item catalog:

- Wood: upgrade/crafting material.
- Wire: upgrade/crafting material.
- Bread: food/vendor item.
- Bottled water: food/vendor item.
- Bandage: medical item, usable later if item-use is added.
- Cash: currency.
- Junk: vendor trash.
- Ammo 9mm: combat economy.
- Pistol 9mm: starting weapon.
- Basic helmet or light armor: future equipment test.
- Small backpack: future equipment test.
- Warehouse key: future locked-area test.

Early item roles:

- `vendor_trash`: sell for money.
- `upgrade_material`: base/workbench costs.
- `combat_supply`: ammo, med, grenade.
- `equipment`: weapon, armor, backpack.
- `key_item`: opens map route or quest gate later.

### Early Enemies

Enemy 1: Scavenger

- Low health.
- Patrols or idles near loot.
- Detects player within simple radius/line-of-sight.
- Moves toward player.
- Uses melee hit or short-range pistol shot.
- Drops one loot item or small cash.

Enemy 2, later in slice: Pistol Guard

- Uses existing weapon damage flow.
- Fires slowly.
- Retreats/repositions only if simple to implement.

Enemy rules:

- Use simple capsule/box bodies and material colors.
- Combat readability matters more than animation quality.
- Enemy AI should be component-style: sensor, movement, attack, loot drop should not become one massive script if it starts growing.

### Early Weapons

Weapon 1: Pistol 9mm

- Uses existing `WeaponController3D` flow.
- Add ammo count, fire cooldown, range, and hit feedback.
- Later add reload.

Weapon 2, after loop works: Combat Knife

- Short range.
- No ammo cost.
- Useful when ammo is empty.

## Architecture Plan

### Current Architecture Direction To Preserve

Keep these current decisions:

- Player owns inventory state.
- UI displays and commands state; UI should not own game state.
- `UIManager` controls top-level gameplay UI state.
- `GameSettings`, `DifficultyManager`, `SaveGameManager`, and localization remain autoload-level services.
- Item data stays in `ItemDef` resources.
- Validation scripts live under `tools/validate_*.gd`.

### Runtime Domains

#### 1. App Flow

Responsibility:

- Main menu.
- Difficulty selection.
- Save-slot selection.
- Scene changes.
- Pause/menu transitions.

Existing:

- `MainMenu`
- `DifficultySelectPanel`
- `SaveSlotPanel`
- `SaveGameManager`
- `PauseMenu`

Needed:

- Base screen or base overlay after raid.
- Result screen after extraction/death.
- Transition path: Main Menu -> Base -> Raid -> Result -> Base.

#### 2. Persistent Game State

Responsibility:

- Save slot metadata.
- Stash inventory.
- Money.
- Selected difficulty.
- Base upgrades.
- Quest flags.
- Future discovered maps/unlocks.

Recommended files:

- `scripts/save/save_game_manager.gd` expands current slot metadata.
- `scripts/save/save_data.gd` or dictionary schema helper.
- `scripts/base/stash_model.gd`
- `scripts/base/base_state.gd`

Early save schema:

```gdscript
{
	"version": 1,
	"scene_path": "res://scenes/base/base_screen.tscn",
	"difficulty_id": "normal",
	"saved_at_unix": 0,
	"money": 0,
	"stash": [
		{"item_path": "res://data/items/crafting/wood.tres", "quantity": 3}
	],
	"base_upgrades": {
		"workbench_level": 0
	},
	"quests": {}
}
```

Use JSON/dictionaries for player save files. Use Godot `Resource` files for authored design data.

#### 3. Raid Session

Responsibility:

- Own one active raid.
- Track success/failure.
- Track raid timer.
- Spawn loot/enemies.
- Collect result data.
- Decide what returns to stash.

Recommended files:

- `scripts/raid/raid_session.gd`
- `scripts/raid/raid_result.gd`
- `scripts/raid/extraction_zone.gd`
- `scripts/raid/map_def.gd`
- `data/maps/refuge_outskirts.tres`

Key API:

```gdscript
func begin_raid(map_def: MapDef, player_loadout: InventoryModel) -> void
func register_extraction() -> void
func register_player_death() -> void
func build_result() -> Dictionary
```

#### 4. Loot And Containers

Responsibility:

- Define what can spawn.
- Spawn deterministic or weighted loot.
- Let containers transfer loot to player.

Recommended files:

- `scripts/loot/loot_table.gd`
- `scripts/loot/loot_table_entry.gd`
- `scripts/loot/loot_container_3d.gd`
- `data/loot_tables/refuge_outskirts_common.tres`

Early rule:

- One common table with 8-12 possible entries.
- Container rolls 1-3 items.
- World loose loot can reuse same table.

#### 5. Player And Inventory

Responsibility:

- Player movement/combat orchestration.
- Player-owned inventory.
- Safe pocket and loadout.
- Carry weight.

Existing:

- `PlayerController3D`
- `PlayerLocomotion3D`
- `PlayerStats3D`
- `InventoryModel`
- `InventoryEquipmentUI`

Needed:

- Equipment model.
- Safe pocket persistence rule.
- Item-use actions.
- Ammo consumption.

#### 6. Combat

Responsibility:

- Damage events.
- Weapon fire.
- Hit detection.
- Enemy/player health and death.

Existing:

- `DamageEvent`
- `Damageable3D`
- `WeaponController3D`

Needed:

- Fire cooldown.
- Ammo source.
- Reload or simple reserve ammo.
- Player death event.
- Enemy death event.
- Hit/miss feedback.

#### 7. Enemy AI

Responsibility:

- Detect player.
- Move/chase/patrol.
- Attack.
- Die/drop loot.

Recommended files:

- `scripts/ai/enemy_controller_3d.gd`
- `scripts/ai/enemy_sensor_3d.gd`
- `scripts/ai/enemy_attack_3d.gd`
- `scripts/ai/enemy_def.gd`
- `data/enemies/scavenger.tres`

Early AI state machine:

```text
Idle -> Alert -> Chase -> Attack -> Dead
```

Keep it simple. Do not build cover, squad tactics, or advanced perception before the first raid loop works.

#### 8. Base, Economy, And Progression

Responsibility:

- Stash.
- Money.
- Selling loot.
- Workbench/base upgrades.
- Quest progression.

Early implementation:

- Base screen with stash list.
- Sell all vendor trash button.
- One upgrade: Workbench Level 1 costs wood + wire + cash.
- Upgrade unlocks a simple recipe or improves starter item quantity.

Recommended files:

- `scripts/base/base_screen.gd`
- `scripts/base/stash_model.gd`
- `scripts/base/base_state.gd`
- `scripts/economy/vendor_service.gd`
- `scripts/crafting/recipe_def.gd`
- `data/base/upgrades/workbench_level_1.tres`

#### 9. UI

Responsibility:

- HUD.
- Inventory.
- Codex.
- Stash.
- Raid objective.
- Result screen.

Rules:

- UI should bind to models/services.
- UI should not be the source of save data.
- Use reusable panels where possible.
- Stable screens and reusable panels should be Godot node-first: prefer `.tscn` scenes, `Control` nodes, containers, labels, buttons, panel containers, scroll containers, grid containers, and theme resources.
- Scripts should mostly bind data, handle signals, and update state. Avoid building entire stable interfaces only through code when node composition can express the layout.
- Script-created UI is acceptable for dynamic repeated children, temporary debug views, or custom drawing that is genuinely hard to express with nodes; record the reason when choosing this path.
- UI work is not complete just because it runs. Any player-facing UI must pass the layout quality bar in `docs/design/ui_layout_quality_guide.md`, including base panels, button sizing, spacing, alignment, visual hierarchy, readability, and 1280x720/1920x1080 fit.
- Every new major UI panel should have a validation script if it has non-trivial logic.

#### 10. Validation And Automation

Responsibility:

- Let Codex safely change code without losing existing behavior.
- Keep every milestone measurable.

Required validation pattern:

- Add or update `tools/validate_[domain].gd` with every new core system.
- Run domain validation plus smoke startup.
- For UI state, use runtime inspection when possible.
- Update `docs/tasks/progress_log.md` after meaningful slices.

## Codex Automation Workflow

Each automated development task should follow this structure:

1. Read the relevant design section and current scripts.
2. Make one narrow feature slice.
3. Add or update a validation script.
4. Run Godot headless validation.
5. Run gameplay scene startup.
6. If UI behavior changed, run runtime UI checks.
7. After every three completed numbered tasks in `docs/tasks/automation_task_queue.md`, run the Project Health Check before continuing.
8. Report exactly what changed, what passed, what health issues were found, and what remains.

### Standard Validation Commands

Use the local Godot executable path currently used in this workspace:

```powershell
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_item_catalog.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_ui_foundation.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_inventory_drag_rules.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_gameplay_architecture.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_combat_domain.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_difficulty_system.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_save_slots.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_save_slot_panel.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_audio_settings.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_pause_menu.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --quit-after 1
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg res://scenes/gameplay/player_test_world_3d.tscn --quit-after 1
```

Add new commands as new domains appear:

- `validate_stash_model.gd`
- `validate_raid_session.gd`
- `validate_loot_tables.gd`
- `validate_extraction_flow.gd`
- `validate_enemy_ai.gd`
- `validate_raid_result.gd`
- `validate_base_progression.gd`

### Codex Task Template

Use this shape for future automation prompts:

```text
Implement [one feature] for Project DCG.

Scope:
- Files/domains allowed:
- Must preserve:
- New behavior:
- Out of scope:

Validation:
- Add/update tools/validate_[domain].gd.
- Run existing relevant validations.
- Run gameplay scene headless startup.
- Report changed files and pass/fail.
```

## Milestone Roadmap

### Milestone 0: Baseline Stabilization

Goal: make the current prototype a stable base for automation.

Tasks:

- Keep all current validation scripts passing.
- Fix any blocking mojibake in player-facing fallback strings touched by new work.
- Document save schema version.
- Confirm `progress_log.md` remains the running history.

Exit criteria:

- Existing validation commands pass.
- Main menu and gameplay scene load headless.

### Milestone 1: Persistent Stash And Save Expansion

Goal: create the permanent state that makes extraction meaningful.

Tasks:

- Add `StashModel`.
- Expand `SaveGameManager` to store money, stash stacks, base upgrades, and quests.
- Add validation for save/load round trip.
- Add a minimal base screen or base panel that displays stash and money.

Exit criteria:

- Save slot can store and reload stash.
- Stash survives scene changes.
- No inventory UI owns persistent stash data.

### Milestone 2: Raid Session And Extraction

Goal: make one raid succeed or fail.

Tasks:

- Add `RaidSession`.
- Add `ExtractionZone`.
- Add extraction timer and prompt.
- Add `RaidResultPanel`.
- Route Main Menu -> Difficulty -> Base -> Raid -> Result -> Base.

Exit criteria:

- Player can extract from the test map.
- Extracted backpack items move to stash.
- Result screen shows success and loot.

### Milestone 3: Loot Tables And Containers

Goal: replace fixed pickup-only loot with repeatable content generation.

Tasks:

- Add `LootTable` resource.
- Add `LootContainer3D`.
- Add one map loot table.
- Spawn loose loot or container loot from the table.

Exit criteria:

- Containers roll items from data.
- Adding/removing an item in the loot table requires no UI code change.
- Validation catches invalid item paths and empty tables.

### Milestone 4: Enemy AI And Death Loss

Goal: make raids dangerous.

Tasks:

- Add `EnemyDef`.
- Add Scavenger enemy scene.
- Add simple AI state machine.
- Connect enemy damage/death/drop.
- Add player damage/death.
- On death, send player to result screen and apply loss rules.

Exit criteria:

- Player can kill one enemy.
- Enemy can damage/kill player.
- Death loses raid backpack items.
- Safe-pocket rule is tested if active.

### Milestone 5: Economy And First Upgrade

Goal: make loot matter after extraction.

Tasks:

- Add money accounting.
- Add sell vendor-trash button.
- Add one workbench upgrade requiring wood/wire/cash.
- Add one simple reward for upgrade.

Exit criteria:

- Extracted loot can become money or upgrade progress.
- Upgrade persists in save.
- The next raid feels slightly different because of the upgrade.

### Milestone 6: Tutorial Quest

Goal: give the first 10 minutes direction.

Tasks:

- Add quest data resource.
- Add one collect quest: extract wood/wire.
- Add one combat quest: defeat one scavenger.
- Add base/quest UI feedback.

Exit criteria:

- Quest can start, update, complete, reward, and persist.
- Quest does not require bespoke hard-coded UI per quest.

### Milestone 7: Vertical Slice Polish

Goal: make Dev Slice 0.1 feel like a small game.

Tasks:

- Tune movement/combat/loot quantities.
- Add simple audio placeholders.
- Add hit/extraction/result feedback.
- Add basic map readability.
- Run repeated raid tests.
- Clean UI text and layout at 1280x720 and 1920x1080.

Exit criteria:

- A fresh player can complete three raids without developer help.
- Extraction and death both produce correct persistence.
- The player understands why they should loot, fight, and extract.

## Development Priorities

### Highest Priority

1. Persistent stash.
2. Raid session.
3. Extraction zone.
4. Result screen.
5. Loot table/container.
6. One enemy.
7. Death/loss rules.

### Medium Priority

1. Ammo/reload.
2. Equipment model.
3. Usable medical/food items.
4. Vendor sell flow.
5. One base upgrade.
6. Quest system.

### Low Priority Until Dev Slice 0.1 Is Approved

1. More maps.
2. More weapons.
3. Full attachment system.
4. Weather.
5. Advanced enemy tactics.
6. Final art.
7. Workshop/mod support.

## Technical Rules

### Data Ownership

- Authored static content: Godot `Resource` files under `data/`.
- Runtime state: RefCounted models and scene nodes.
- Player save data: JSON/dictionaries with explicit schema version.
- UI: reads models/services, emits user intent, does not own authoritative gameplay state.

### Coupling Rules

- Child scenes should expose methods/signals and avoid assuming exact parent paths.
- Autoloads are for persistent cross-scene services only.
- Avoid hard references from domain logic to UI nodes.
- Avoid letting any single script absorb unrelated responsibilities.
- If a script grows beyond roughly 300-350 lines or starts mixing unrelated responsibilities, pause feature work and split it into focused helpers before adding more behavior.
- New stable UI should use Godot scenes/nodes first; code-only panel construction should be treated as a temporary or justified exception.
- Prefer typed resources/classes over unstructured dictionaries for authored content.

### Validation Rules

- Every new domain needs a small validation script.
- Every validation should fail loudly with actionable messages.
- Use headless Godot for fast checks.
- Use runtime inspection for UI or scene wiring behavior when static checks are not enough.
- Run a project health review after every three automation tasks, checking responsibility boundaries, node-first UI usage, script size, data-driven content, save safety, localization, and scene loadability.
- Include UI layout quality in each project health review. Check whether the interface looks usable and organized, not only whether it technically opens.

## Risk Register

### Risk: Art Scope Explosion

Mitigation:

- Use placeholder primitives until Dev Slice 0.1 is approved.
- Build content through data tables.
- Add only one polished visual sample per category when needed.

### Risk: UI Grows Faster Than Game Loop

Mitigation:

- UI work must support a current loop requirement.
- Do not build full vendor/quest/stash UI before the underlying model works.
- Prefer reusable Godot node scenes for UI panels so layout stays visible and maintainable in the editor instead of becoming large script-only interfaces.
- Keep placeholder visuals clean: panel bases, buttons, spacing, and alignment should be solid before final art is introduced.

### Risk: Save System Becomes Hard To Change

Mitigation:

- Add schema version now.
- Keep conversion helpers isolated.
- Validate save/load round trips.

### Risk: Enemy AI Becomes Too Large

Mitigation:

- Start with small state machine.
- Split sensor, attack, and drop behavior if the controller grows.
- Do not add cover tactics before the first enemy is fun.

### Risk: Content Added Before Rules Are Stable

Mitigation:

- Add only enough items/enemies/upgrades to test the loop.
- After loop approval, duplicate content through resources and tables.

## Next Recommended Codex Tasks

1. Add `StashModel` and expanded save schema validation.
2. Add a minimal base screen that lists stash and starts raid.
3. Add `RaidSession`, `ExtractionZone`, and raid result data.
4. Add `RaidResultPanel` and success flow from gameplay to base.
5. Add `LootTable` and `LootContainer3D`.
6. Add Scavenger enemy v1.
7. Add player death and loss rules.
8. Add sell/vendor-trash and one workbench upgrade.
9. Add one tutorial quest.
10. Run a three-raid smoke test and tune.

## Approval Target For Dev Slice 0.1

Do not expand content volume until this checklist is true:

Dev Slice 0.1 system validation passed on 2026-07-02. Player-visible acceptance is pending after hands-on review, and repeated content expansion remains locked until user approval.

- Main menu starts a new save.
- Base screen displays persistent stash.
- Raid map starts from base.
- Player can loot, fight, and extract.
- Extracted items enter stash.
- Death loses raid backpack items.
- Save/load restores stash and money.
- At least one upgrade consumes extracted loot.
- At least one quest gives direction.
- Existing validation suite passes.
- The loop feels worth repeating at least three times.

## Sources

- Steam store page for Escape From Duckov: https://store.steampowered.com/app/3167020/Escape_From_Duckov/
- Godot scene organization best practices: https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html
- Godot autoload documentation: https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html
- Godot resources documentation: https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html
- Game Programming Patterns, Component pattern: https://gameprogrammingpatterns.com/component.html
- MDA framework paper: https://www.cs.northwestern.edu/~hunicke/pubs/MDA.pdf
- Rami Ismail, Prototypes & Vertical Slice: https://ltpf.ramiismail.com/prototypes-and-vertical-slice/
- UI layout quality guide: `docs/design/ui_layout_quality_guide.md`
