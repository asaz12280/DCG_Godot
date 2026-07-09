# DCG Programming Specification

This document is the required entry gate before Codex or any AI-driven pass changes scripts, scenes, or gameplay data in this project.

Low-token entry point for new AI threads:

`D:\3DMesh\DCG_Godot\dcg\docs\architecture\programming_spec_short.md`

Use the short entry spec by default. Read this full specification only for broad architecture, persistence, UI-system, localization-system, decision-record, or unclear high-risk work.

## Required Pre-Task Gate

Before implementation starts:

1. Read this file.
2. Identify the active feature domain: player, combat, inventory, items, loot, raid, AI, base, quests, save, settings, UI, localization, data, or validation.
3. Identify the owner script, helper scripts, scenes, resources, and validation files that should change.
4. Confirm the task is ready: desired player or developer outcome, acceptance criteria, affected domains, and validation path are clear enough to act.
5. Refuse the "single giant script" path. If the work mixes responsibilities, split it into focused scripts first.
6. After implementation, run the smallest relevant validator set and add or update `tools/validate_*.gd` when the behavior can regress.

## Core Rule

Scripts must be split by responsibility. Do not concentrate unrelated behavior in one large script just because it is convenient during a long conversation.

A script should have one clear reason to change. When a file starts owning two or more domains, create a focused helper, service, presenter, model, resource, or component.

Preferred split signals:

- A script grows beyond roughly 300-350 lines and new behavior is not tightly related to the existing owner.
- UI drawing, user input, gameplay rules, save persistence, data lookup, and scene flow appear in the same file.
- A domain script references a specific UI node path or concrete UI panel class.
- A UI script becomes the authority for persistent gameplay state.
- A scene script starts containing reusable domain rules instead of local node wiring.
- A feature requires repeated copy-pasted code across screens, panels, enemies, items, or services.

## Project Management Gates

Use lightweight ready and done gates so work does not drift during long AI sessions.

Definition of Ready:

- The task has one primary outcome.
- The user-visible or developer-visible result is known.
- The affected domains and likely owner files are named before editing.
- Acceptance criteria are specific enough to validate.
- The implementation can be delivered as one self-contained change, or it is split into ordered smaller steps.

Definition of Done:

- Acceptance criteria are satisfied.
- Relevant validation scripts pass, or any skipped validation is reported with the reason.
- The implementation preserves script responsibility boundaries.
- UI changes remain readable at required target resolutions and do not make UI the owner of persistent game state.
- All new or changed player-facing text is localization-key driven and translated for every supported locale.
- Save/data/schema changes are backward-safe or have an explicit migration/default path.
- New architecture-significant decisions are recorded when required by the Decision Records section.
- Larger technical debt is recorded in `docs/tasks/progress_log.md` instead of being hidden in code.

## Change Size Rule

Prefer one self-contained change at a time. A good change addresses one behavior, one architecture cleanup, or one content/data slice and includes the validation needed to understand it.

Avoid broad churn:

- Do not mix unrelated feature work, refactors, formatting, data rewrites, and scene redesigns in the same pass.
- Do not add unused APIs without at least one real use in the same change.
- Do not spread a small behavior change across many files unless the split follows existing ownership boundaries.
- If a feature is naturally large, land it as staged vertical slices with working validation after each slice.

## Quality Attribute Gate

Before choosing an architecture approach, identify which quality attributes the task touches:

- Modifiability: Can the next related feature be added without editing an unrelated domain script?
- Testability: Can the rule be validated through `tools/validate_*.gd` or a focused runtime scene check?
- Reliability: Does failure stay local, or can one global service break unrelated scenes?
- Usability: Is the player-facing flow readable, visible, and not only technically wired?
- Performance: Does the change avoid unnecessary global allocation, per-frame work, or scene-wide searching?
- Save safety: Does persisted state survive missing fields, renamed content, or old slots?

For large or risky work, write the relevant quality attribute in the task notes before editing.

## Project Ownership Boundaries

- `scripts/player`: player movement, input reading, player-owned inventory bridges, equipment bridges, and player stat orchestration.
- `scripts/combat`: weapon operation, projectile or hit behavior, damage events, armor mitigation, ballistics, recoil, and attachment effects.
- `scripts/inventory`: inventory models, containers, stack movement rules, sorting, save codecs, and storage rules.
- `scripts/items`: item definitions and item-level services such as durability.
- `scripts/loot`: loot tables, loot entries, and container generation.
- `scripts/raid`: raid session state, extraction, raid result, loss rules, and loadout transfer.
- `scripts/ai`: enemy definitions, enemy controllers, enemy damage, senses, and loot-drop bridges.
- `scripts/base`: base progression, stash, workbench, repair, blueprint, dismantle, interaction, and base view-model services.
- `scripts/quests`: quest definitions, state, trackers, catalog, and location triggers.
- `scripts/save`: save slot persistence, migrations, and round-trip safety.
- `scripts/ui`: presentation, input intent, layout helpers, panel presenters, painters, and reusable UI components.
- `scripts/localization`: localization startup and language wiring only.
- `data`: authored content as Godot `Resource` files, translations, loot tables, item data, enemy data, upgrades, quests, and recipes.
- `scenes`: node composition, local scene wiring, and visual hierarchy.
- `tools`: headless validation scripts that guard behavior, architecture, content quality, and scene health.

## UI Rules

UI reads models and services, then emits user intent. UI must not become the source of truth for persistent gameplay state.

Stable UI must be Godot node-first when possible: `.tscn` scenes, `Control` nodes, containers, labels, buttons, panels, scroll containers, grid containers, theme resources, and built-in engine behavior should be used before custom script recreation.

Do not recreate Godot node, container, theme, input, focus, or layout behavior in script when the engine already provides the same effect. Script-created UI is acceptable only for dynamic repeated children, temporary debug views, small glue code, or custom drawing that is genuinely hard to express with nodes.

Keep shared layout math in UI helpers such as `UILayout`, shared style in `game_theme.tres` or `UIStyle`, and repeated presentation in presenters or components.

Before creating or changing UI:

- Inspect the closest existing screen, panel, `.tscn`, component, presenter, `UILayout` helper, `UIStyle` token, and `game_theme.tres` style.
- Reuse the existing layout rhythm, typography, margins, button hierarchy, panel structure, and interaction patterns unless the task explicitly requires a new pattern.
- If a new UI pattern is necessary, document why it cannot reuse the existing pattern and move any reusable parts into shared helpers, components, scenes, or theme resources.
- Do not create a visually unrelated one-off UI just because it is faster to script.
- Route labels, buttons, hints, status text, error text, empty states, and tooltips through localization keys; do not hard-code Chinese or English display copy in UI scripts.

## Localization Rules

All player-facing text must be ready for multi-language translation.

Player-facing text includes UI labels, buttons, hints, status messages, errors, item names/descriptions, item type names, prompts, combat feedback, quest text, dialogue, station text, tutorial text, map text, and result text.

Rules:

- Store stable localization keys in resources, scene exports, models, or settings-driven data; translate only at the display edge.
- Do not hard-code Traditional Chinese, English, or any final display copy in gameplay/UI scripts when the text can be localized.
- Every required key must have a non-empty translation for every supported locale before the task is done.
- `zh_TW` is the authoring locale, but English mode must never show Traditional Chinese because of missing keys, fallback strings, or copied display text.
- Fallback strings are temporary developer safety nets only. A player-facing screen is not complete if normal play can show fallback text.
- Format strings must keep the same runtime placeholders across locales.
- When adding a new text domain, add or update validation so missing keys and mixed-language output can be caught.

## Domain Rules

Domain systems should communicate through typed methods, signals, models, resources, or autoload services. They should not search for unrelated UI nodes or depend on concrete panel classes.

Use resources and data for authored content. Items, weapons, armor, ammo, loot tables, enemies, quests, base upgrades, recipes, and tuning values should not be hidden inside gameplay branches unless the value is temporary and documented.

Autoloads are for narrow project-level services. Do not add a new autoload when a scene-local node, model, service object, static helper, or resource reference is enough.

Autoload rules:

- An autoload should own its own state and contract.
- An autoload should not become a dumping ground for unrelated manager logic.
- Any new autoload must name why scene-local ownership, resources, or static helper functions are not enough.
- Any new autoload or broad-scoped service should have a validator or decision record.

## External Reference Rules

Duckov and other shipped games may be used as production references for feature structure, pacing, object categories, encounter roles, scene density, readability, and UX problems to solve. They must not become copy targets.

Reference rules:

- Keep DCG's UI, assets, data, code, names, tuning, and final presentation original.
- Use external references to extract functional contracts, not proprietary content.
- A reference can justify "what problem this feature solves" or "what category of prop/system is needed"; it cannot justify copying meshes, textures, materials, level layouts, item names, or copyrighted implementation.
- If the task uses external analysis, record the resulting DCG-owned requirement in project docs, data, validators, or task notes.

Known reference artifact:

- `D:\Escape from Duckov\AssetRipper_export_20260705_151633\MeshIndex_20260706.csv`
- Purpose: a CSV mesh index from an AssetRipper export, with mesh name, size, submesh count, vertex count, and original exported `.asset` path.
- Allowed use: search mesh names, estimate object/scene complexity, identify prop categories, compare density budgets, and plan original Godot replacement assets.
- Forbidden use: import, commit, ship, or directly recreate extracted meshes, textures, materials, names, layouts, or copyrighted assets.

## Profile And Snapshot Rule

When one catalog resource starts collecting unrelated tuning fields, split the authored values into focused profile resources before adding more controller logic.

Current item data pattern:

- `ItemDef` owns catalog identity, common metadata, localization keys, tags, save-safe stack export, and compatibility fallback getters.
- Weapon-only values belong in `WeaponProfile`, including firing, magazine, recoil, compatible ammo, attachment slots, and weapon durability tuning.
- Ammo-only values belong in `AmmoProfile`.
- Armor-only values belong in `ArmorProfile`.
- Attachment-only values belong in `AttachmentProfile`.
- Legacy `ItemDef` fields may remain as migration fallback, but new code should read through profile-backed getters such as `get_weapon_damage()` or through a domain service snapshot.

Runtime calculation pattern:

- Controllers must not each recalculate final weapon stats from raw item fields.
- `WeaponTuningService.resolve_snapshot()` is the single combat-facing resolver for weapon + ammo + attachments + durability final numbers.
- A snapshot should include both authored components and final runtime values when the distinction matters, for example base magazine capacity, attachment bonus, final magazine capacity, ammo multiplier, attachment multiplier, and final recoil/spread.
- UI and player/equipment bridges may display snapshot values, but UI must not become the owner of tuning math.
- When adding a new stat that changes firing, recoil, spread, durability, armor penetration, magazine capacity, reload, or range, add it to the relevant profile and update `WeaponTuningService.resolve_snapshot()` plus a focused validator.

AI behavior tuning pattern:

- Enemy catalog data stays in `EnemyDef`.
- Detect, chase, search, attack, windup, forget, navigation refresh, and stuck-recovery parameters belong in `EnemyBehaviorProfile`.
- `EnemyController3D` may keep a simple state machine, but should read behavior numbers from `EnemyBehaviorProfile` during setup instead of hard-coding or owning authored tuning values.

Migration experience from the 2026-07-06 profile split:

- Prefer a compatibility bridge first: add profile resources and `ItemDef` getters while leaving existing serialized fields intact.
- Move runtime readers to getters or snapshots before deleting any legacy field.
- Update representative `.tres` data with profile subresources so validators exercise the new path with real content.
- Add one architecture validator that proves data loads, snapshot math resolves, controllers consume the service/profile, and source boundaries stay clean.
- Record the pattern here immediately after the change so later AI sessions do not drift back into god resources or duplicated controller math.

## Scene Rules

Scene files own composition and local wiring. Attached scene scripts may coordinate child nodes, but reusable gameplay rules should live in the relevant domain script.

Reusable scenes should be self-contained. When a scene needs outside context, prefer explicit setup by the parent through exported data, typed references, signals, callables, or narrow methods. Sibling scenes should not directly reach into each other's internals; let a parent, model, or service mediate.

When adding a new scene, keep ownership clear:

- Scene script: local node references, local signals, local presentation state.
- Domain service or model: gameplay rules, persistence-ready state, calculation, validation-friendly behavior.
- Resource: authored values and reusable definitions.

## Architecture Views

Maintain enough architecture documentation that future tasks can find the right owner quickly.

- Update `docs/architecture/duckov_like_architecture.md` when a major runtime domain changes.
- Update focused design docs under `docs/design` when UI, localization, content authoring, or player-visible direction changes.
- For cross-domain flows, document the direction of ownership: who owns state, who reads state, who emits intent, and who persists data.
- Diagrams are optional, but when a flow becomes hard to explain in prose, use a small C4-style context/container/component view or a Mermaid diagram.

## Decision Records

Create an architecture decision record under `docs/architecture/decisions/` when a choice is hard to reverse or changes the project's structure.

Use a decision record for:

- New autoloads or project-wide services.
- New persistence schemas or migrations.
- New cross-domain ownership contracts.
- Replacing an established folder, scene, or UI architecture pattern.
- Choosing between two credible architecture approaches.

Do not create a decision record for routine feature work. The record should be short: context, decision, options considered, consequences, validation, and links.

## Validation Rules

Every new gameplay domain, persistence rule, content schema, or cross-system contract should have a matching validator under `tools/validate_*.gd`.

Prefer focused validators that prove ownership boundaries, not only happy-path behavior. A useful validator often checks that:

- The new data/resource can load.
- The model or service produces the expected result.
- UI can read the state without owning it.
- Save/load or scene startup still works when relevant.
- The new code does not introduce known coupling patterns.

## Implementation Checklist

Before editing:

- Read this specification.
- Read the existing architecture or design doc for the touched domain.
- Check current scripts before assuming ownership.
- Choose the smallest set of files that match the responsibility boundary.
- Confirm Definition of Ready.

During editing:

- Keep new behavior in the correct domain.
- Split helpers before adding unrelated logic to an already large script.
- Keep UI, domain state, save persistence, authored data, and validation separate.
- Follow existing folder and naming patterns.
- Keep the change self-contained.

Before finishing:

- Confirm Definition of Done.
- Run relevant `tools/validate_*.gd` checks.
- Run `git diff --check` for touched files when practical.
- Report any boundary debt that remains, instead of hiding it inside a large script.

## Industry Basis

This specification is intentionally lightweight, but it follows common industry guidance:

- Scrum Guide: transparent artifacts, refinement into smaller precise items, Sprint Goal, Product Goal, and Definition of Done.
- Google Engineering Practices: prefer small self-contained changes and protect long-term code health.
- SEI software architecture guidance: architecture choices should be reasoned about through quality attributes such as modifiability, performance, reliability, security, and usability.
- Architecture Decision Records: document key structural decisions, alternatives, and consequences.
- C4 model: use simple architecture views when communication needs more than prose.
- Godot best practices: prefer focused, loosely coupled scenes, avoid unnecessary global state, and use autoloads only for broad-scoped systems that own their contract.

Reference links:

- https://scrumguides.org/scrum-guide.html
- https://google.github.io/eng-practices/review/developer/small-cls.html
- https://google.github.io/eng-practices/review/reviewer/standard.html
- https://www.sei.cmu.edu/library/reasoning-about-software-quality-attributes/
- https://learn.microsoft.com/en-us/azure/well-architected/architect-role/architecture-decision-record
- https://c4model.com/
- https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html
- https://docs.godotengine.org/en/4.4/tutorials/best_practices/autoloads_versus_internal_nodes.html
