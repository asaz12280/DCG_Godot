# Duckov-Like Game Architecture Analysis

Source context checked on 2026-06-29:
- Steam describes Escape From Duckov as a single-player/PvE survival RPG with scavenging, hideout building, gear upgrades, hostile enemies, extraction risk, five maps, changing loot, weather, 50+ weapons, weapon mods, skill trees, quests, NPCs, Steam Workshop, and 50+ hours of content.
- The project currently has a Godot 4.7 3D top-down prototype with player movement, sprinting, dodge roll, stamina, health HUD, inventory/equipment UI shell, a test world, simple props, and a folder layout for data-driven content.

## Target Architecture

The game should be built around one repeatable loop:

1. Prepare at base.
2. Enter a raid map.
3. Explore, fight, loot, and complete objectives.
4. Extract before death or timeout.
5. Keep extracted loot, lose risky carried gear on death, and convert resources into upgrades.
6. Unlock harder zones, better equipment, quests, and story progress.

This loop needs five major runtime domains.

## Runtime Domains

### 1. Player And Combat

Current state:
- `scripts/player/player_controller_3d.gd` handles top-down movement, sprint, dodge roll, stamina, health, carry weight, defense, backpack slots, and safe pocket slots.
- `scenes/player/player_3d.tscn` provides a simple 3D duck body and collision.
- `scripts/ui/player_hud_3d.gd` renders health, stamina, and crosshair.

Needed:
- Weapon controller with fire mode, spread, recoil, reload, ammo, durability, and attachments.
- Hit detection through raycast or projectile simulation.
- Damage model for body, armor, defense, status effects, and death.
- Item use actions for meds, food, drinks, grenades, tools, keys, and quest objects.

Recommended Godot modules:
- `scripts/combat/weapon_controller.gd`
- `scripts/combat/hit_scan_weapon.gd`
- `scripts/combat/projectile_weapon.gd`
- `scripts/combat/damageable.gd`
- `scripts/combat/status_effects.gd`

### 2. Inventory, Items, And Economy

Current state:
- `scripts/ui/inventory_equipment_ui.gd` draws equipment slots, backpack grid, safe pocket slots, money display, weight bar, scroll, and organize button.
- `data/items/*` folders already exist but are empty.

Needed:
- Data-driven item definitions.
- Inventory model separated from UI.
- Grid/slot rules, stacking, weight, rarity, value, tags, quest flags, and safe pocket protection.
- Equipment slots that change player stats.
- Vendors, buy/sell prices, barter recipes, and insurance-like recovery rules if desired.

Recommended Godot modules:
- `scripts/items/item_def.gd` as `Resource`
- `scripts/items/item_stack.gd`
- `scripts/inventory/inventory_model.gd`
- `scripts/inventory/equipment_model.gd`
- `scripts/economy/vendor_service.gd`
- `data/items/weapons/*.tres`
- `data/items/loot/*.tres`
- `data/tables/loot_tables/*.tres`

### 3. Raid Maps, Loot, And Extraction

Current state:
- `scenes/gameplay/player_test_world_3d.tscn` is a small test arena with floor, player, camera, HUD, and props.
- `data/maps` exists but is empty.

Needed:
- Map definitions for spawn points, extraction points, enemy zones, loot zones, weather, time of day, locked areas, and mission hooks.
- Raid session manager that owns state for timer, extraction, death, generated loot, spawned enemies, and result summary.
- Loot containers with deterministic table references.

Recommended Godot modules:
- `scripts/raid/raid_session.gd`
- `scripts/raid/extraction_zone.gd`
- `scripts/raid/loot_container.gd`
- `scripts/raid/map_def.gd`
- `scenes/maps/map_01_refuge_outskirts.tscn`

### 4. Enemy AI And Encounter Design

Needed:
- PvE enemies with patrol, hearing/vision, suspicion, chase, cover/retreat, attack, reload, and loot drop behavior.
- Tiered enemy archetypes: melee scavenger, pistol guard, shotgun rusher, rifle patrol, sniper, boss/miniboss, wildlife/monster variants if desired.
- AI director for density, alertness, and map escalation.

Recommended Godot modules:
- `scripts/ai/enemy_controller.gd`
- `scripts/ai/sensor_component.gd`
- `scripts/ai/combat_brain.gd`
- `scripts/ai/loot_dropper.gd`
- `data/enemies/*.tres`

### 5. Base, Progression, Quests, And Save

Needed:
- Base facilities: stash, workbench, medical station, shooting range, generator, trader radio, map table.
- Upgrade graph using materials, money, quests, and player level.
- Quest system for NPC dialogue, kill/collect/extract/discover/craft objectives, rewards, and story flags.
- Skill tree for character, ranged, melee, survival, crafting, and trading.
- Save system that persists stash, base, quests, skills, currencies, discovered maps, and player settings.

Recommended Godot modules:
- `scripts/base/base_state.gd`
- `scripts/base/facility_def.gd`
- `scripts/progression/skill_tree.gd`
- `scripts/missions/mission_def.gd`
- `scripts/save/save_service.gd`

## Data Ownership

Use Godot `Resource` files for strongly typed content and JSON/CSV only for bulk import tables. The project already has `data` and `resources` folders; keep design data in `data` and reusable engine resources in `resources`.

Suggested content definitions:
- ItemDef: id, display_name, icon, weight, size, max_stack, tags, rarity, value.
- WeaponDef: item fields plus caliber, magazine, fire_rate, accuracy, recoil, sound_range, attachment_slots.
- ArmorDef: item fields plus armor_class, durability, protected_slots, movement_penalty.
- EnemyDef: health, armor, senses, weapon_pool, loot_table, behavior_profile.
- MapDef: scene_path, raid_time, spawn_sets, extraction_sets, loot_tables, weather_pool.
- MissionDef: giver, objective list, unlock conditions, reward list, next missions.
- FacilityDef: upgrade levels, costs, effects, prerequisites.

## Current Gap Summary

Already present:
- Basic movement and camera.
- Basic player stats.
- Stamina and health HUD.
- Inventory/equipment UI shell.
- Basic world scene and props.
- Project folders for data, assets, resources, tests, docs, and tools.

Highest priority gaps:
- Combat feel.
- Data-driven inventory model.
- Loot/extract raid loop.
- Enemy AI.
- Save/load.
- Base progression.

## Technical Risks

- Several existing comments and UI labels appear mojibake/encoding-corrupted. Before content production, normalize source files to UTF-8 and replace garbled labels with stable Traditional Chinese or internal English ids.
- Inventory UI currently owns demo data arrays directly. Move item state into an inventory model so UI does not become the game state.
- The current controller combines base stats, equipment stats, skill stats, carry weight, movement, and stamina. Keep it for prototype velocity, but extract stat calculation before equipment and skills grow.
- Build the game as data-driven early. A Duckov-like game lives or dies by item tables, loot tables, mission chains, and tuning speed.
