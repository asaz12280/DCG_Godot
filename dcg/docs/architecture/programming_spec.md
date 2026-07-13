# DCG Programming Specification

This is the extended reference, not the default AI entry file. New threads start with:

`D:\3DMesh\DCG_Godot\dcg\docs\architecture\programming_spec_short.md`

Read this file only for broad/high-risk architecture, persistence/schema, cross-domain ownership, new autoload/plugin integration, or when the short spec cannot decide the owner. For ordinary dialogue, CSV, UI, or VFX work, use the focused guide routed by the short spec instead.

## Work Gate

Before editing:

1. State one outcome and its acceptance criteria.
2. Name the active domain and current owner files.
3. Inspect only the relevant scripts, scenes, Resources, data, and validators.
4. Choose one self-contained behavior, data/content slice, or architecture cleanup.
5. Identify the smallest validation path.

After editing:

- Confirm the acceptance criteria and ownership boundary.
- Run focused validation; treat printed `SCRIPT ERROR` or `ERROR` as failure even when the process exits successfully.
- Check localization and save compatibility when touched.
- Run `git diff --check` when practical and report skipped checks or remaining debt.

Do not run broad repository scans or full validator sweeps by default. Prefer focused `rg`, targeted reads, and one validator at a time. Use `rtk` when available; read `C:\Users\User\.codex\RTK.md` only when needed.

## Architecture Rules

A script has one clear reason to change. Do not accumulate unrelated behavior in a controller, UI script, Resource, autoload, or plugin adapter.

- Controllers coordinate scene nodes and stable public APIs/signals.
- Components own local runtime behavior and its mutable state.
- Models own durable runtime state and data operations.
- Services own reusable calculations and domain transactions.
- Resources own authored data and relationships.
- UI reads state, presents it, and emits user intent; it does not own persistent gameplay truth.
- Scenes own node composition and local wiring, not reusable domain rules.

Split by ownership, not by line ranges. A real split moves the behavior together with its Timer, pending request, selection/drag state, validation, and cancel/complete lifecycle. A large coordinator may remain a compatibility facade, but forwarded implementation and mutable state must exist in only one focused owner.

Consider a split when a script approaches 300-350 lines and gains an unrelated responsibility, mixes UI/input/save/rules, directly reaches into an unrelated panel, or duplicates behavior already present elsewhere. Keep APIs stable during the first decomposition pass and update source-based validators to follow the new owner.

Current guarded boundaries:

- `PlayerController3D` delegates reload/item-use lifecycle to `PlayerTimedActionController3D`, quick-slot behavior to `PlayerQuickSlotController3D`, and equipment/weapon state to focused collaborators.
- `InventoryEquipmentUI` delegates GUI input routing, commands, and drag lifecycle to their existing support objects while reusing shared painters/presenters/layout.
- `validate_player_ui_architecture_health.gd` guards ownership and line-count regression caps.

Autoloads are only for narrow project-wide contracts. Prefer scene-local nodes, Resources, models, services, or static helpers. A new autoload requires a clear cross-scene need, an ownership contract, focused validation, and usually an ADR.

## Runtime Rules

- Use signals/events for inventory, equipment, HUD, UI, and gameplay coordination. Do not introduce frame polling without profiling evidence.
- Reload and item-use use focused Timer/start/end/cancel flows. Never poll them in `_physics_process`.
- Timed actions expose busy state, block incompatible actions, and emit progress only on meaningful/coarse changes.
- Cache repeated gameplay-time resource lookups instead of repeatedly calling `ResourceLoader.exists()` or `load()`.
- Keep continuous physics/movement in physics owners. State transitions may select behavior but must not duplicate movement, damage, or navigation calculations.

## Project Domains

- `scripts/player`: player input, locomotion, stats, equipment/inventory bridges, quick slots, player action coordination.
- `scripts/combat`: damage, weapons, projectiles, armor mitigation, ballistics, recoil, attachment effects, combat presentation bridges.
- `scripts/inventory`: inventory/container models, stack movement, sorting, persistence codecs.
- `scripts/items`: item definitions, typed profiles, item-level services such as durability and consumables.
- `scripts/loot`: loot tables and container generation/interaction.
- `scripts/raid`: raid session, extraction, result, loss rules, loadout transfer.
- `scripts/ai`: enemy data, sensing, state coordination, navigation/combat components, damage and loot bridges.
- `scripts/quests`: quest definitions, progress state, trackers, catalog, provider and location integration.
- `scripts/base`: stash, progression, crafting/workbench, repair, blueprints, dismantling, interaction/view models.
- `scripts/save`: persistence, normalization, migrations, round-trip safety.
- `scripts/ui`: scenes, presentation, layout, painters, presenters, components, and input intent.
- `scripts/localization`: locale startup and translation wiring only.
- `scripts/data`: approved data loaders, synchronizers, resolvers, and reference readers.
- `data`: authored Resources, tuning tables, translations, story files, and project-owned reference data.
- `scenes`: composition and local wiring.
- `tools`: focused headless behavior, architecture, data, localization, and scene validators.

Cross-domain communication uses typed methods, signals, models, Resources, snapshots, or narrow project services. A domain must not search for unrelated UI nodes or depend on a concrete panel class.

## UI And Localization

Use Godot `.tscn` scenes, `Control` nodes, containers, themes, focus/input behavior, Resources, and signals before recreating equivalent behavior in script. Script-created UI is limited to dynamic repeated content, small glue code, debug views, or genuinely custom drawing.

Before changing UI, inspect and reuse the nearest existing screen, layout helper, theme/style token, component, presenter, and painter. Maintain one product family for palette, panel opacity, borders, spacing, typography, button hierarchy, and interaction. Prefer changing shared tokens over introducing one-off styling. See `docs/design/ui_architecture.md` and `docs/design/ui_layout_quality_guide.md`.

All player-facing text uses stable localization keys and is translated at the display edge. The required locales are currently exactly `zh_TW` and `en`; both must be non-empty and preserve matching format placeholders. English mode must not display Chinese fallback text. Fallback strings are developer safety nets, not completed content.

## Shared Plugin Policy

Code under `res://addons/` is vendor-owned. DCG scenes, adapters, data, UI, and validators stay outside addon folders so upgrades do not overwrite project logic. Do not let controllers call raw plugin APIs throughout the project; use one narrow integration boundary per plugin. Plugin upgrades require focused startup/import validation and a check that project-owned adapters still match the installed version.

Current baseline: Dialogue Manager `3.10.2`, CSV Data Importer `2.0`, and Sound Manager `4.0` are enabled and integrated. gdfxr `2.1` is available as an editor authoring tool. Godot State Charts `0.22.5` is vendored but is not yet enabled or used by a production scene; verify this baseline after any plugin update.

### Sound Manager And gdfxr

- `GameSettings` is the only saved Master/BGM/SFX volume owner. Sound Manager category gains stay at 0 dB and route through those buses.
- Sound Manager owns non-positional music/global playback only. Positional weapon, enemy, impact, and world sounds remain scene-local `AudioStreamPlayer3D` nodes.
- DCG code integrates through `SoundManagerBridge` or a later focused audio service; do not scatter raw plugin calls.
- Sound Manager maps `BGM/BGS -> BGM` and `SFX/MFX -> SFX`. Keep preload/preinstantiation disabled until profiling justifies them.
- gdfxr creates/imports original synthetic or placeholder streams; it never owns playback, settings, or final realistic audio direction.

Read `docs/design/audio_music_guide.md` and ADR `20260714-sound-manager-audio-routing.md`; validate with `validate_audio_settings.gd` and `validate_sound_manager_integration.gd`.

### Dialogue Manager

Dialogue Manager owns dialogue syntax, branching, conditions, mutations, and runtime line delivery. It does not own locale selection, quest truth, gameplay calculations, or production UI.

- Story files: `res://data/dialogue/`.
- Every visible line and choice uses a permanent `[ID:dialogue.<arc>.<scene>.<line>]`.
- Dialogue translations: `res://data/localization/dialogue_text.csv`, complete for `zh_TW` and `en`.
- `LocalizationBootstrap` remains the only locale owner; `DialogueLocalizationBridge` keeps Dialogue Manager in CSV-key mode.
- Dialogue may request quest accept/turn-in or story-flag actions through stable domain APIs; quest objectives, rewards, progress, and persistence remain in quest/save owners.
- Static UI, items, weapons, combat feedback, codex facts, and ordinary notifications stay in their existing localization/data owners.
- The addon example Balloon is demo/reference UI only. Production dialogue UI reuses DCG UI patterns.

Read `docs/design/dialogue_authoring_guide.md` and ADR `20260712-dialogue-manager-localization.md`; validate with `validate_dialogue_localization.gd`.

### CSV Data Importer

CSV Data Importer provides spreadsheet-style authored data without exposing CSV dictionaries to gameplay code.

- Approved tuning tables live under `res://data/tuning/` and use stable IDs plus explicit schema/range validation.
- `items.csv` owns shared ItemDef numeric inventory/effect fields; `weapons.csv` owns weapon combat tuning; `difficulty.csv` owns difficulty multipliers.
- `GameTuningBootstrap` is the only runtime owner that applies tuning rows to typed Resources/profiles and compatibility fields. It retains tuned Resources for the session.
- Controllers, UI, inventory, equipment, and combat services consume typed Resources or snapshots, never raw CSV records or tuning file paths.
- Identity, localization keys, assets, scenes, relationships, save state, dialogue, and UI layout do not belong in tuning tables.
- `game_text.csv` and `dialogue_text.csv` remain Godot CSV Translation sources and must not be imported as generic CSV Data.
- `CsvDataTableLoader` may provide a first-import/headless fallback; imported dictionary Resources remain the normal editor path.
- Every new table needs one domain synchronizer, schema/version rules, stable-ID/range checks, importer-ownership checks, and a focused validator.

The DCG-owned `resource_reference_index.csv` may also be imported as records, but `ResourceReferenceIndex` remains the domain reader and enforces allowed statuses and extracted-source boundaries.

Read `data/tuning/README.md` and ADR `20260713-csv-tuning-pipeline.md`; validate tuning with `validate_csv_tuning_pipeline.gd`.

### Godot State Charts

Godot State Charts manages legal transitions in meaningful exclusive, hierarchical, or parallel runtime flows. It is not a replacement for Resources, services, Dialogue Manager, quest persistence, or Timer-based player actions.

Good fits:

- Enemy AI such as `idle -> chase -> search -> windup -> attack -> dead`.
- Boss phases and interruptible combat modes.
- Multi-stage encounters, tutorials, or world devices with several valid/invalid transitions.
- Complex extraction flow only after it gains countdown/cancel/contested/failure states.

Poor fits:

- Quest objectives, rewards, progress dictionaries, and save data.
- Dialogue lines/choices already owned by Dialogue Manager.
- Weapon/item/attachment/durability math and CSV synchronization.
- UI layout, inventory models, codex data, static toggles, or simple booleans.
- Existing reload/item-use timing owned by `PlayerTimedActionController3D`.
- Continuous input, sensing, movement, navigation, or physics calculations.

State Chart rules:

- A chart answers "which state is active and which transitions are legal." Components perform sensing, movement, navigation, combat, animation, and effects.
- `EnemyBehaviorProfile` continues to own detect/chase/search/attack/windup/forget/navigation/stuck tuning.
- Use scene-local StateChart nodes, preferably as reusable component scenes; do not add a StateChart autoload.
- Use stable non-localized `StringName` event IDs. Send events only when a condition changes; never spam the same event every frame.
- State enter/exit handlers delegate to focused components. They do not contain damage formulas, inventory mutations, persistence, or UI construction.
- State-native delayed transitions are acceptable for AI windup/search/cooldown flows. Player reload/item-use remain in their existing Timer owner.
- Keep one root state and use compound/parallel states only when hierarchy/concurrency removes real duplication.
- Preserve existing public signals and `get_state()` compatibility during migration. Add debugger tracking during development and a focused architecture/behavior validator before calling a chart production-ready.

The first production pilot is enemy AI. A safe split is `EnemyPerception3D` (target edges), `EnemyNavigationMotor3D` (movement), `EnemyCombat3D` (windup/attack), and a small chart adapter, with `EnemyController3D` remaining the scene facade. Do not migrate quests merely because they contain a `state` field.

The addon may be vendored before it is enabled or used. Inspect `project.godot` and actual scenes; do not assume installation means production coupling.

## Data Contracts

- `ItemDef`: stable identity, shared metadata, localization keys, tags, stack export, compatibility getters.
- `WeaponProfile`, `ArmorProfile`, `AttachmentProfile`: type-specific authored values. Ammo stays compatibility/catalog data; do not add ammo-side damage/spread/recoil/wear/penetration or `AmmoProfile` without a new approved decision.
- `WeaponTuningService.resolve_snapshot()`: sole final weapon + attachment + durability calculation; ammo contributes loaded identity/compatibility only.
- `WeaponProfile.projectiles_per_shot`: defaults to 1. One trigger consumes one round and emits shot audio/muzzle presentation once; the weapon controller spawns the snapshot projectile count. Shotgun-SG currently uses 5.
- `EnemyBehaviorProfile`: enemy behavior tuning, never UI or state-chart topology.
- `QuestGiverProfile`: provider scope; quest state/rewards remain in quest/save services.

Active ItemDefs under `res://data/items/` require a unique positive catalog number, one matching `items.csv` row, complete locale keys, and valid referenced content. Future concepts stay in planning docs until complete. Removing active content requires cleaning its tuning/localization/dependencies/save aliases/validators together while preserving reusable generic systems.

`ItemInspectionFieldPolicy`, `ItemInspectionSnapshotBuilder`, and `ItemInspectionWeaponRows` are the shared item-information pipeline. Tooltip, detail, equipment/stash, and codex views consume it at different detail levels. `ItemCodexCatalog` is the only item index; do not add a parallel registry. Internal IDs must resolve through localized labels and never leak into player-facing copy.

Save readers normalize missing/old fields. Renamed IDs, paths, dialogue IDs, catalog entries, or schemas require compatibility aliases/defaults or an explicit migration and round-trip validation.

## Scenes, VFX, And External References

Scene scripts own local references, signals, and presentation state. Domain services own rules/calculation; Resources own authored reusable values. Reusable scenes receive context through exports, typed references, signals, callables, or narrow setup methods rather than reaching into sibling internals.

Combat VFX remains optional presentation: it may consume confirmed events/positions but never own damage, targeting, cadence, projectile physics, inventory, persistence, or audio. Read `docs/design/combat_vfx_guide.md` only for VFX work.

Duckov and other released games are functional references, not copy targets. Learn feature roles, pacing, readability, encounter structure, and UX problems while keeping DCG code, data, tuning, names, UI, assets, and final presentation original.

- External extracted MeshIndex data is analysis-only and never a shippable source.
- DCG planning source: `res://data/reference/resource_reference_index.csv`.
- Reader: `res://scripts/data/resource_reference_index.gd`.
- Validator: `res://tools/validate_resource_reference_index.gd`.
- Never import, commit, ship, or directly recreate extracted proprietary meshes, textures, materials, names, layouts, or copyrighted assets.
- Licensed third-party assets require an isolated vendor folder, license/source note, selected direct dependencies only, rewritten project-local paths, and no demo gameplay/managers unless explicitly approved.

## Decisions And Validation

Create a short ADR under `docs/architecture/decisions/` for hard-to-reverse choices: new autoloads, persistence schemas, cross-domain/plugin ownership, replacement of an established architecture, or a choice between credible structural options. Routine feature work does not need an ADR.

New gameplay domains, schemas, and cross-system contracts need focused `tools/validate_*.gd` coverage. Useful validators prove that data loads, the owner produces the expected result, UI only reads it, save/startup works when relevant, and forbidden coupling has not returned.

Definition of Done:

- Acceptance criteria are met.
- The behavior and mutable state live in the correct owner.
- Focused validation passes or skipped checks are reported.
- UI remains consistent and does not own gameplay state.
- Changed player-facing text is complete for all supported locales.
- Save/schema changes are backward-safe or migrated.
- Architecture-significant decisions are recorded; larger remaining debt is logged rather than hidden.

## Industry Basis

These rules follow common small-change, clear-ownership, quality-attribute, ADR, C4, and Godot scene-organization practices. Source references are retained here for occasional architecture review, not routine AI startup:

- https://scrumguides.org/scrum-guide.html
- https://google.github.io/eng-practices/review/developer/small-cls.html
- https://www.sei.cmu.edu/library/reasoning-about-software-quality-attributes/
- https://c4model.com/
- https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html
- https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_internal_nodes.html
