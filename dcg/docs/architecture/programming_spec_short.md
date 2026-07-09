# DCG AI Task Entry Spec

Copy this path into new AI threads first:

`D:\3DMesh\DCG_Godot\dcg\docs\architecture\programming_spec_short.md`

This is the low-token entry rule. Read this file first. Do not read the full `programming_spec.md` unless the task changes broad architecture, persistence, UI systems, localization systems, or the user explicitly asks.

## Cost Control

- Keep context small: inspect only the files needed for the active task.
- Use `rg` to find owners before opening files.
- Do not scan the whole repo or run the full validator set by default.
- Run the smallest relevant `tools/validate_*.gd` checks one at a time.
- Give concise progress and final reports. Avoid long architecture essays unless requested.
- If the work is ambiguous but not dangerous, make a reasonable small assumption and proceed.

## Pre-Task Gate

Before editing:

1. Identify the active domain: player, combat, inventory, items, loot, raid, AI, base, quests, save, settings, UI, localization, data, validation, or docs.
2. Name the likely owner files and the smallest validation path.
3. Keep the change scoped to one behavior, one architecture cleanup, or one content/data slice.
4. If the task mixes responsibilities, split into focused scripts/resources/services instead of growing one large file.

## Core Architecture Rules

- Scripts must be split by responsibility. Avoid god scripts and duplicated logic.
- A file should have one clear reason to change.
- Controllers coordinate nodes and consume services/resources; they should not own reusable gameplay math.
- Authored values belong in Godot `Resource` data, scenes, theme resources, or focused profile resources, not hidden in controller branches.
- UI reads models/services and emits intent. UI must not own persistent gameplay state.
- Prefer Godot nodes, scenes, controls, containers, resources, and themes over recreating equivalent behavior with code.
- Reuse existing UI layout, theme, presenters, painters, components, and rhythm before creating a new UI style.
- All player-facing text must use localization keys/resources. English mode must not show Chinese fallback text.
- Save/data/schema changes must be backward-safe or include a migration/default path.

## Current Data Pattern

- `ItemDef` owns catalog identity, shared metadata, localization keys, tags, stack export, and compatibility fallback getters.
- Weapon-only values belong in `WeaponProfile`.
- Ammo-only values belong in `AmmoProfile`.
- Armor-only values belong in `ArmorProfile`.
- Attachment-only values belong in `AttachmentProfile`.
- Final weapon runtime stats must come from `WeaponTuningService.resolve_snapshot()` for weapon + ammo + attachments + durability.
- Enemy detect/chase/search/attack/windup/forget/navigation/stuck tuning belongs in `EnemyBehaviorProfile`; `EnemyController3D` only runs the simple state machine.

## External Reference Rule

- Duckov is a functional reference, not a copy target. Keep DCG's UI, assets, data, code, names, and balance implementation original.
- `D:\Escape from Duckov\AssetRipper_export_20260705_151633\MeshIndex_20260706.csv` is an external mesh index for analysis only.
- Use that CSV to search mesh names, estimate scene/object complexity, understand prop categories, and plan original Godot replacements.
- Do not import, commit, ship, or directly recreate extracted meshes, textures, materials, names, layouts, or copyrighted assets from the AssetRipper export.
- When borrowing an idea, translate it into a DCG-owned contract such as gameplay behavior, item category, encounter role, scene density target, or original placeholder asset requirement.

## Done Gate

Before final response:

- Relevant behavior works or the blocker is reported clearly.
- Responsibility boundaries are preserved.
- New or changed player-facing text is localization-ready.
- Relevant focused validators pass, or skipped/failed checks are named with reasons.
- Run `git diff --check` for touched files when practical.
- Mention only files and tests relevant to this task. Do not summarize unrelated dirty worktree changes.

## Full Spec Fallback

Read `D:\3DMesh\DCG_Godot\dcg\docs\architecture\programming_spec.md` only when:

- Creating a new architecture pattern.
- Adding a broad service/autoload.
- Changing save/persistence schema.
- Changing reusable UI/localization architecture.
- Writing or updating a decision record.
- The short spec is insufficient for the task.
