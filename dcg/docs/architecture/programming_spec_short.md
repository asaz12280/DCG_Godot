# DCG AI Quick Spec

New AI threads read only this file first:

`D:\3DMesh\DCG_Godot\dcg\docs\architecture\programming_spec_short.md`

Do not read the full spec or scan the repository by default. Open only the task's owner files and the routed guide below. Read `programming_spec.md` only for broad/high-risk architecture, persistence/schema, new autoload/plugin boundaries, or when this file is insufficient.

## Low-Token Workflow

1. Name one active domain and one expected outcome.
2. Use `rg` to find the current owner; inspect only relevant files.
3. Make one focused behavior, data/content slice, or architecture cleanup.
4. Run the smallest matching validator; avoid full sweeps unless required.
5. Keep progress and final reports concise; ignore unrelated dirty changes.

Use `rtk` when available. Read `C:\Users\User\.codex\RTK.md` only when its command behavior is needed.

## Hard Rules

- One script has one reason to change. Controllers coordinate; Resources hold authored data; models/services own reusable rules; UI presents state and emits intent.
- Split real ownership, including mutable state, Timer, pending request, selection, and cancel/complete flow. Moving helper functions alone is not a split.
- Preserve existing public APIs/signals during safe decomposition. Keep `validate_player_ui_architecture_health.gd` green.
- Prefer Godot nodes, scenes, containers, themes, Resources, signals, and Timer nodes over recreating equivalent engine behavior in code.
- Reuse the existing UI scene/layout/theme/presenter/painter/component family. Do not create a parallel UI style or let UI own persistent gameplay state.
- Runtime UI and gameplay coordination are event-driven. Never poll inventory, HUD, equipment, reload, or item-use state in `_physics_process`.
- Reload and item-use keep their Timer plus start/end/cancel state in `PlayerTimedActionController3D`; they expose busy state and block incompatible actions.
- All player-visible text uses stable localization keys with complete `zh_TW` and `en` values. English mode must never show Chinese fallback text.
- Save/data/schema changes require backward-compatible defaults or explicit migration.
- Addon code under `res://addons/` is vendor-owned. Keep DCG adapters, data, UI, and validators outside addon folders unless an explicit vendor patch is required.

## Plugin Boundaries

- **Dialogue Manager:** owns nonlinear dialogue syntax, branching, conditions, mutations, and line delivery. Story files live in `res://data/dialogue/`; every visible line/choice has a stable `[ID:dialogue.*]` and complete rows in `res://data/localization/dialogue_text.csv`. `LocalizationBootstrap` remains the only locale owner; production dialogue UI reuses DCG UI. Read `docs/design/dialogue_authoring_guide.md` for dialogue tasks and run `validate_dialogue_localization.gd`.
- **CSV Data Importer:** imports approved tuning/reference CSVs only. `GameTuningBootstrap` is the sole runtime tuning applier; controllers/UI consume typed `ItemDef`/Profile/snapshot contracts, never CSV rows. `items.csv`, `weapons.csv`, and `difficulty.csv` own their focused numeric fields. Translation CSVs are not generic CSV Data. Read `data/tuning/README.md` or ADR `20260713-csv-tuning-pipeline.md` for table/schema tasks and run `validate_csv_tuning_pipeline.gd`.
- **Godot State Charts:** use only for meaningful exclusive/hierarchical runtime flows, initially enemy AI (`idle/chase/search/windup/attack/dead`), later bosses or multi-stage encounters. Profiles keep tuning, components perform sensing/movement/combat, and State Charts choose legal state transitions. Do not use it for quest persistence/rewards, dialogue branching, CSV/data math, UI layout, weapon snapshots, or existing reload/item-use timers. Send stable events on condition changes, not every frame. No production chart is assumed until its scene and focused validator are added.
- **Sound Manager / gdfxr:** `GameSettings` remains the only Master/BGM/SFX volume owner. Sound Manager handles non-positional music/global sounds through a DCG bridge; positional weapon/world audio stays on scene-local `AudioStreamPlayer3D`. gdfxr is authoring/import only. Read `docs/design/audio_music_guide.md` for audio tasks and run `validate_sound_manager_integration.gd`.

## Current Contracts

- `ItemDef` owns identity/shared metadata; `WeaponProfile`, `ArmorProfile`, and `AttachmentProfile` own type-specific authored values. Ammo stays simple; do not add `AmmoProfile` combat stats.
- `WeaponTuningService.resolve_snapshot()` is the only final weapon + attachments + durability calculation. Ammo contributes compatibility/loaded identity only.
- `WeaponProfile.projectiles_per_shot` defaults to 1; one trigger consumes one round and plays one shot audio/muzzle event. Shotgun-SG currently fires 5 projectiles.
- `EnemyBehaviorProfile` owns enemy detection, chase, search, attack, windup, forget, navigation, and stuck-recovery tuning.
- `QuestGiverProfile` scopes quest providers. Quest objectives, rewards, progress, and persistence remain in quest/save owners.
- Active ItemDefs require a unique positive catalog number, one `items.csv` row, complete locale keys, and valid dependencies. Placeholder content stays outside active data.
- `ItemInspectionFieldPolicy` + snapshot/row builders own inspection fields; all item views consume them. `ItemCodexCatalog` is the single item index.

## Read Only When Relevant

- Broad architecture/plugin/state-chart/save/schema: `docs/architecture/programming_spec.md`
- Dialogue authoring: `docs/design/dialogue_authoring_guide.md`
- CSV tuning: `data/tuning/README.md` and `docs/architecture/decisions/20260713-csv-tuning-pipeline.md`
- UI structure/visual consistency: `docs/design/ui_architecture.md` and `docs/design/ui_layout_quality_guide.md`
- Combat VFX: `docs/design/combat_vfx_guide.md`
- Music/audio/Sound Manager/gdfxr: `docs/design/audio_music_guide.md`
- External reference index: `data/reference/resource_reference_index.csv`, reader `scripts/data/resource_reference_index.gd`, validator `tools/validate_resource_reference_index.gd`

Duckov and other games are functional references only. Never import, ship, or directly recreate extracted proprietary assets, names, tuning, or layouts. External MeshIndex data is analysis-only; the DCG-owned reference index is the project planning source.

## Done Gate

- Requested behavior/data/docs are complete, or the blocker is explicit.
- Ownership, localization, save safety, and the smallest relevant validation are handled.
- Check Godot output for printed `SCRIPT ERROR`/`ERROR`; exit code alone is insufficient.
- Run `git diff --check` for touched files when practical.
