# Game Design Document: Project DCG

## Vision

Project DCG is a single-player top-down PvE extraction survival RPG starring armed ducks in a collapsing world. The player repeatedly leaves a safe base, scavenges dangerous maps, fights hostile forces, extracts with loot, upgrades their hideout and gear, and slowly uncovers a larger escape objective.

Design goal: capture the tension and satisfaction of extraction survival while keeping the controls readable, the tone playful, and the session length friendly.

## Pillars

1. Every raid should create a small story: preparation, risk, surprise, greed, escape, or loss.
2. Loot should matter because it feeds base upgrades, crafting, quests, equipment, and money.
3. Combat should be readable from top-down view, with clear sound, line of sight, cover, reload windows, and enemy tells.
4. Progression should make the next raid feel different, not just numerically easier.
5. Loss should sting but not stop progress; safe pockets, base upgrades, quest unlocks, and knowledge remain.

## Core Loop

Base phase:
- Repair, heal, craft, buy, sell, accept quests, equip loadout, choose map.

Raid phase:
- Spawn into map, loot containers, fight enemies, complete objectives, manage weight, decide whether to push deeper or extract.

Result phase:
- Extracted: stash gained loot, complete quests, unlock upgrades.
- Died: lose carried equipment and backpack items, keep safe pocket items and persistent progress.

## Player Experience

The first 30 minutes should teach:
- Move, aim, sprint, dodge.
- Shoot one basic weapon.
- Loot a container.
- See weight and inventory pressure.
- Extract successfully.
- Upgrade one base facility.
- Accept a quest that asks for a specific item or kill.

## MVP Feature Set

MVP should prove the game loop, not the full content volume.

Required MVP:
- One small raid map.
- One base screen or base room.
- Player movement, stamina, dodge, health, death.
- Two weapons: pistol and shotgun/rifle.
- Three enemy types.
- Ten loot items.
- Four equipment slots: weapon, armor, backpack, safe pocket.
- Inventory model, stash, weight, item value.
- Two extraction zones.
- Three quests.
- One base upgrade.
- Save/load.
- Raid result screen.

Not required for MVP:
- Full story.
- 50+ weapons.
- Multiple endings.
- Mod support.
- Complex attachment system.
- Advanced weather.

## Full Game Scope

Maps:
- Map 1: Refuge Outskirts, starter zone, low enemy density, basic loot.
- Map 2: Abandoned Market, dense loot, many interiors, ambush enemies.
- Map 3: Factory Drain, industrial hazards, crafting materials, armor enemies.
- Map 4: Military Wetlands, long sight lines, snipers, high-end weapons.
- Map 5: Launch Facility, late game quest hub and final escape chain.

Weapons:
- Melee: stick, wrench, blade.
- Pistols: cheap sidearms, low sound, weak armor penetration.
- Shotguns: strong close range, heavy ammo.
- SMGs: fast, expensive ammo.
- Rifles: general purpose, attachment friendly.
- Snipers: long range, slow handling.
- Special: homemade launcher, energy prototype, joke weapons.

Progression:
- Character levels unlock skills and trader tiers.
- Skills split into survival, ranged, melee, crafting, mobility, and economy.
- Base upgrades unlock stash space, crafting, healing, weapon modding, ammo crafting, map intel, and final escape construction.

Quests:
- Tutorial quests teach the loop.
- Trader quests unlock recipes, maps, and economy.
- Story quests reveal why Duckov is collapsing.
- Final quest chain assembles an escape vehicle or equivalent endgame objective.

## Economy

Currencies:
- Common money for vendors and repairs.
- Premium/special currency for rare services, late-game upgrades, or quest rewards.

Item roles:
- Vendor trash: sells for money.
- Upgrade materials: base and craft costs.
- Quest items: must be extracted.
- Gear: weapons, armor, backpacks, meds.
- Keys/intel: unlock rooms, extraction options, or map information.

Balancing principle:
- Early raids should make even "junk" feel useful.
- Mid game should force choice between money, upgrades, and combat power.
- Late game should make rare components and survival consistency the bottleneck.

## Combat Design

Combat must communicate danger quickly:
- Visible enemy cone/range can be optional debug, but sound and animation should clearly telegraph awareness.
- Shots should reveal position by sound radius.
- Cover should block line of sight and bullets where appropriate.
- Reloading should be a real risk.
- Enemies should miss sometimes, reposition, and retreat rather than always rushing.

Damage:
- Health plus armor durability.
- Armor reduces or absorbs damage based on class.
- Bleed and fracture can be added after the basic loop works.

## UX Requirements

HUD:
- Health, stamina, ammo, current weapon, quick item slots, extraction timer, raid objective hints.

Inventory:
- Grid or slot-based backpack.
- Equipment panel.
- Safe pocket.
- Weight indicator.
- Sort/organize.
- Item tooltip with value, weight, tags, and quest/upgrading usage.

Base:
- Stash.
- Vendor.
- Workbench.
- Facility upgrades.
- Quest board.
- Map selection.

## Success Criteria

MVP is successful when:
- A player can complete three raids in a row without developer help.
- Death and extraction both produce correct item persistence.
- At least one quest and one base upgrade require extracted loot.
- Combat is understandable enough that deaths feel fair.
- Save/load restores stash, base upgrade, quest state, and player money.

Full game is successful when:
- The content supports 15-25 hours for a compact indie version.
- The player has meaningful reasons to revisit maps.
- There is a clear endgame objective and completion state.
