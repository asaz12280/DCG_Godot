# Project DCG Content Authoring Guide

Last updated: 2026-07-02

## Purpose

This guide defines how Codex or a human designer may add early Project DCG content after Dev Slice 0.1 proves the loop. Its main job is to prevent content expansion from turning into scattered hard-coded logic.

Until Dev Slice 0.1 is approved, new content should be limited to tiny validation-driven samples. Do not add volume for its own sake.

## Core Rules

1. Add authored content as Godot resources under `dcg/data/` whenever a resource type already exists.
2. Do not add item, loot, enemy, quest, or upgrade behavior directly inside UI scripts.
3. Do not duplicate a system just to support one new content entry.
4. Every new content entry must be covered by the relevant validation script before the task is complete.
5. If a new content type needs a new field, update the typed resource class, update validation, and document the field here.
6. Placeholder visuals are allowed, but stable player-facing UI must remain Godot node-first and follow `docs/design/ui_layout_quality_guide.md`.
7. Localization keys are required for player-facing item text. Temporary English fallback text is acceptable only when the task records why.

## Folder Map

- Items: `dcg/data/items/**`
- Loot tables: `dcg/data/loot_tables/*.tres`
- Enemy data: `dcg/data/enemies/*.tres`
- Enemy scenes: `dcg/scenes/enemies/*.tscn`
- Quests: `dcg/data/quests/*.tres`
- Base upgrades: `dcg/data/base_upgrades/*.tres`
- Localization CSV: `dcg/data/localization/game_text.csv`
- Validation scripts: `dcg/tools/validate_*.gd`

## Content Workflow

Use this sequence for every content task:

1. Identify the smallest content slice needed for the current gameplay goal.
2. Check whether an existing resource type supports the slice.
3. Add or edit the `.tres` resource.
4. Add localization keys if the content name or description is player-facing.
5. Wire scenes only when a runtime node is required, such as an enemy scene or pickup scene.
6. Run the domain validation.
7. Run the nearest loop validation if the content affects progression or raid results.
8. Record the content change and validation result in `docs/tasks/progress_log.md`.

## Item Authoring

Resource class: `ItemDef`

Script: `dcg/scripts/items/item_def.gd`

Typical path:

- `dcg/data/items/weapons/*.tres`
- `dcg/data/items/ammo/*.tres`
- `dcg/data/items/crafting/*.tres`
- `dcg/data/items/loot/*.tres`
- `dcg/data/items/valuables/*.tres`

Required fields:

- `id`: stable snake_case `StringName`, unique across the catalog.
- `catalog_number`: positive unique integer with no gaps in the current catalog.
- `name_key`: localization key, usually `item.<id>.name`.
- `description_key`: localization key, usually `item.<id>.desc`.
- `item_type`: one of the exported enum values in `ItemDef`.
- `weight`: non-negative.
- `value`: non-negative.
- `max_stack`: at least 1.
- `tags`: gameplay tags such as `gun`, `pistol`, `9mm`, `vendor_trash`, `crafting`, or `food`.

Rules:

- Gun items must set `damage` above 0.
- Non-gun items should keep `damage` at 0.
- Quest-only items should set `is_quest_item = true`.
- Items should not know about UI panels, save slots, or quest completion logic.
- When adding a sellable junk item, include a useful `value` and the `vendor_trash` tag.

Validation:

```powershell
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_item_catalog.gd
```

Also run `validate_ui_text_quality.gd` if localization rows are touched.

## Loot Table Authoring

Resource classes:

- `LootTable`
- `LootTableEntry`

Scripts:

- `dcg/scripts/loot/loot_table.gd`
- `dcg/scripts/loot/loot_table_entry.gd`

Typical path:

- `dcg/data/loot_tables/*.tres`

Required `LootTable` fields:

- `id`: stable snake_case `StringName`.
- `entries`: one or more `LootTableEntry` resources.

Required `LootTableEntry` fields:

- `item_path`: existing `ItemDef` resource path.
- `min_quantity`: positive integer.
- `max_quantity`: greater than or equal to `min_quantity`.
- `weight`: positive float.
- `tags`: optional tags for content review, such as `common`, `currency`, `food`, `electronics`, `vendor_trash`.

Rules:

- Keep early loot tables small and readable.
- Use weights to tune frequency instead of hard-coding special cases in containers.
- Avoid adding rare chase loot until the basic loop has been approved.
- If a loot entry is needed for a quest or upgrade, make sure the quantity and weight allow the loop to complete without perfect luck.
- Containers should point to a loot table; they should not embed one-off item logic.

Validation:

```powershell
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_loot_tables.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_loot_container.gd
```

Run `validate_early_balance.gd` and `validate_three_raid_loop.gd` if loot quantity, economy pacing, or upgrade pacing changes.

## Enemy Authoring

Resource class: `EnemyDef`

Script: `dcg/scripts/ai/enemy_def.gd`

Data path:

- `dcg/data/enemies/*.tres`

Scene path:

- `dcg/scenes/enemies/*.tscn`

Required fields:

- `id`: stable snake_case `StringName`.
- `display_name`: designer-readable name.
- `max_health`: positive.
- `move_speed`: positive.
- `damage`: positive.
- `detect_radius`: positive.
- `loot_table_path`: existing `LootTable` resource path.

Scene requirements:

- Root should be in the `enemy` group.
- Root or child damage component must expose `apply_damage`.
- Scene should include a collision shape.
- Placeholder body/head meshes are acceptable for early enemies.
- Scene metadata `enemy_def` should point to the matching enemy data resource.
- Scene health and visible detection marker metadata should match the `EnemyDef` when present.

Rules:

- Keep Scavenger-like enemies simple: detect, chase, attack, die, drop.
- Do not add cover tactics, squads, patrol graphs, or complex behavior before the loop approval task.
- Split sensor, attack, death, and drop logic if the enemy controller starts growing beyond a focused state machine.

Validation:

```powershell
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_enemy_def.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_enemy_ai.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_enemy_loot_drop.gd
```

Run `validate_player_damage.gd` if enemy damage or death flow changes.

## Quest Authoring

Resource class: `QuestDef`

Script: `dcg/scripts/quests/quest_def.gd`

Typical path:

- `dcg/data/quests/*.tres`

Required fields:

- `id`: stable snake_case `StringName`.
- `display_name`: player-facing or temporary readable title.
- `description`: player-facing or temporary readable description.
- `objective_type`: `collect`, `extract`, `extract_any`, or `kill`.
- `objectives`: one or more dictionaries.
- `reward_money` or `reward_items`: at least one reward is required.

Objective dictionaries:

- Item objectives use `{"item_path": "res://...", "quantity": N}`.
- Kill objectives use `{"enemy_id": "scavenger", "quantity": N}`.

Rules:

- Prefer data objectives over hard-coded UI branches.
- Quest progress must be save-friendly dictionaries.
- Kill quest progress should use stable keys such as `kill:<enemy_id>`.
- Do not make one-off Base UI code for one quest. The existing Base quest display should be extended generically if needed.
- Early quests should teach the loop: extract materials, survive a fight, claim reward, and return to base.

Validation:

```powershell
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_quest_model.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_quest_flow.gd
```

Run `validate_base_screen.gd` if quest display changes.

## Upgrade Authoring

Resource class: `UpgradeDef`

Script: `dcg/scripts/base/upgrade_def.gd`

Typical path:

- `dcg/data/base_upgrades/*.tres`

Required fields:

- `id`: stable snake_case `StringName`.
- `display_name`: designer-readable name.
- `description`: short description of the effect.
- `money_cost`: non-negative.
- `item_costs`: dictionaries with `item_path` and positive `quantity`.
- `starter_ammo_bonus`: non-negative, if used.

Rules:

- Every upgrade must have at least one cost.
- Costs should point to items already available in the current loop.
- Effects must be applied by progression or gameplay systems, not by UI buttons directly.
- Base UI may display and request the upgrade, but it must not become the owner of upgrade rules.
- If an upgrade changes raid startup, add a validation that instantiates the player or relevant scene after the save state is set.

Validation:

```powershell
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_base_progression.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_three_raid_loop.gd
```

Run `validate_early_balance.gd` when costs or rewards change.

## Localization Requirements

Player-facing item names and descriptions should use localization keys. Add rows to:

- `dcg/data/localization/game_text.csv`

Minimum item key pattern:

- `item.<id>.name`
- `item.<id>.desc`

UI-facing labels should use `ui.<screen>.<name>` keys. Enemy names may use `enemy.<id>.name`.

After adding localization:

```powershell
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_ui_text_quality.gd
```

If a key is missing or corrupt, use `UIText` fallback only as a safety net. Do not treat fallback text as a complete localization pass.

## Validation Matrix

Use this matrix before marking a content task complete:

| Content changed | Required validation |
| --- | --- |
| ItemDef | `validate_item_catalog.gd` |
| LootTable or LootTableEntry | `validate_loot_tables.gd`, `validate_loot_container.gd` if containers use it |
| EnemyDef or enemy scene | `validate_enemy_def.gd`, `validate_enemy_ai.gd`, `validate_enemy_loot_drop.gd` |
| QuestDef | `validate_quest_model.gd`, `validate_quest_flow.gd` |
| UpgradeDef | `validate_base_progression.gd`, `validate_three_raid_loop.gd` |
| Economy pacing | `validate_vendor_sell.gd`, `validate_early_balance.gd`, `validate_three_raid_loop.gd` |
| UI text or layout | `validate_ui_text_quality.gd`, `validate_ui_foundation.gd`, relevant panel validation |
| Scene wiring | relevant scene validation plus Godot headless startup |

## Required Startup Checks

For shared content changes, run both startup checks:

```powershell
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --quit-after 1
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --quit-after 1 res://scenes/gameplay/player_test_world_3d.tscn
```

The gameplay scene path must include `scenes/gameplay/`.

## Definition Of Done For Content Expansion

A content expansion task is complete only when:

- The content is represented by resources or scene instances in the expected folders.
- The relevant validation scripts pass.
- No UI script owns persistent state or content-specific rules.
- Player-facing text has localization keys or the progress log records why it is temporary.
- The content supports the current loop instead of bypassing it.
- The progress log records what was added, what validation passed, and any remaining risk.

## Do Not Do Yet

Until Dev Slice 0.1 is accepted:

- Do not add many maps.
- Do not add a large weapon catalog.
- Do not build a full attachment UI.
- Do not add final art requirements.
- Do not add advanced enemy tactics.
- Do not add complex crafting chains.
- Do not add vendors beyond the existing sell/junk loop unless a task explicitly asks for it.
