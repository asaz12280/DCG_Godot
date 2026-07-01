# Completion And Monitoring Plan

## Codex Automation Primer

Codex scheduled work has two useful shapes:

- Cron automation: runs as a standalone recurring job against one or more workspace folders. This is best for project monitoring, weekly reports, test runs, backlog audits, and "check this repo every morning" tasks.
- Heartbeat automation: follows up inside an existing thread. This is best for short follow-ups or continuing a conversation later.

For this project, use a cron automation. It should open `D:\3DMesh\DCG_Godot\dcg`, inspect the repo, optionally run validation, compare progress against this plan, and report blockers plus the next highest-leverage task.

Recommended monitor cadence:
- Daily light monitor: check changed files, current milestone, broken scenes/scripts, and next task.
- Weekly planning monitor: summarize completed work, update risk list, and propose next sprint.

Recommended first automation prompt:

```text
Monitor the Godot project at D:\3DMesh\DCG_Godot\dcg for progress toward a Duckov-like single-player PvE extraction RPG. Read docs/architecture/duckov_like_architecture.md, docs/design/game_design_duckov_like.md, and docs/tasks/completion_and_monitoring_plan.md. Inspect current files, identify completed/missing milestone items, run lightweight checks if available, and report: completed since last check, current risks, next 3 concrete tasks, and any files that need attention. Do not make code changes unless explicitly requested.
```

## Milestone 0: Stabilize Prototype

Goal: make the current project clean enough to build on.

Tasks:
- Fix mojibake comments and UI labels in player, HUD, and inventory scripts.
- Confirm Godot opens `res://scenes/gameplay/player_test_world_3d.tscn`.
- Add basic developer README with controls.
- Create a lightweight validation command or Godot test scene checklist.

Done when:
- Player can move, sprint, dodge, aim, open inventory, and see health/stamina without script errors.

## Milestone 1: Combat Slice

Goal: one weapon, one enemy, one death loop.

Tasks:
- Add weapon controller and pistol definition.
- Add ammo/magazine/reload.
- Add raycast hit detection.
- Add `Damageable` component.
- Add one enemy that patrols and attacks.
- Add player death state and respawn/result placeholder.

Done when:
- Player can kill an enemy and can be killed.

## Milestone 2: Data-Driven Items And Inventory

Goal: real item state replaces UI-only demo arrays.

Tasks:
- Create typed item resources.
- Create inventory and equipment models.
- Connect inventory UI to model.
- Implement pickup, drop, stack, sort, weight, and safe pocket behavior.
- Add 10 starter items and 2 starter weapons.

Done when:
- Loot picked in world appears in backpack, affects weight, can be extracted or lost.

## Milestone 3: Raid Loop

Goal: a complete playable extraction session.

Tasks:
- Add `RaidSession`.
- Add map spawn points.
- Add loot containers.
- Add extraction zones.
- Add extraction timer.
- Add result screen.
- Add death/extract item persistence.

Done when:
- Player can start a raid, loot, extract, and keep items.
- If player dies, unsafe carried items are lost.

## Milestone 4: Save, Stash, And Base

Goal: persistent progression.

Tasks:
- Add save/load service.
- Add stash data model.
- Add base screen or base scene.
- Add vendor sell flow.
- Add workbench craft flow.
- Add one base upgrade that increases stash or crafting options.

Done when:
- Closing and reopening the project preserves stash, money, base upgrade, and quest state.

## Milestone 5: Quests And Progression

Goal: give raids purpose.

Tasks:
- Add mission definitions.
- Add objective types: collect, kill, extract, visit, craft.
- Add quest board/NPC UI.
- Add rewards.
- Add character XP and simple skill unlocks.

Done when:
- Three starter quests guide the player through looting, fighting, and upgrading.

## Milestone 6: Content Vertical Slice

Goal: one polished small game segment.

Tasks:
- Expand starter map.
- Add 3 enemy types.
- Add 20 loot items.
- Add 5 weapons.
- Add 5 base upgrades.
- Add 10 quests.
- Add audio and VFX feedback for shooting, hit, death, loot, extraction.

Done when:
- A new player can play 60-90 minutes with clear progression.

## Milestone 7: Full Indie Scope

Goal: finish the compact full game.

Tasks:
- Build 5 maps.
- Add 50+ weapons and core attachment families.
- Add 80-150 loot/crafting items.
- Add 30-50 quests.
- Add skill trees.
- Add late-game base upgrades and final escape objective.
- Add balance pass, UX pass, performance pass, and bug fixing.

Done when:
- The game has a start, middle, end, persistent progression, and repeatable extraction gameplay.

## Suggested Weekly Sprint Rhythm

Monday:
- Choose one milestone target.
- Lock 3-5 concrete tasks.

Tuesday to Thursday:
- Implement one vertical feature at a time.
- Keep content data small until the loop works.

Friday:
- Playtest the loop.
- Record bugs and friction.
- Update docs and milestone status.

Weekend:
- Content expansion only if core systems are stable.

## First Three Implementation Tasks

1. Clean encoding and labels in current scripts. Status: partially complete for the inventory UI; player and HUD comments can be cleaned opportunistically.
2. Add `ItemDef`, `InventoryModel`, and connect the existing inventory UI to real state. Status: complete for the first prototype pass.
3. Add pistol shooting plus one damageable target/enemy in the test world. Status: world pickup is complete; damageable target and pistol controller are next.
