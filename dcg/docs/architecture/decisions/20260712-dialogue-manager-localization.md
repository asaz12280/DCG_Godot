# ADR 20260712: Dialogue Manager Localization

## Status

Accepted

## Context

DCG needs nonlinear story authoring without creating a second locale controller, translation store, or unrelated dialogue UI. Existing player-facing text already uses `LocalizationBootstrap`, CSV tables, and Godot `TranslationServer`.

## Decision

Use the vendored Dialogue Manager addon for dialogue parsing, branching, conditions, mutations, and line delivery. Keep `LocalizationBootstrap` as the only locale owner, load dialogue copy from the separate `dialogue_text.csv`, and force Dialogue Manager CSV-key mode through `DialogueLocalizationBridge`. Production dialogue presentation must reuse DCG UI patterns rather than the addon's example Balloon.

## Options Considered

- Let Dialogue Manager own separate translation files and locale switching: rejected because it duplicates state and increases mixed-language risk.
- Put dialogue rows into `game_text.csv`: supported but rejected as the default because long story content would make the general UI table harder to maintain.
- Share `TranslationServer` while separating dialogue CSV content: chosen because it preserves one runtime language setting and clear content ownership.

## Consequences

- Positive: existing language switching applies to UI, items, quests, and dialogue together.
- Positive: addon updates remain isolated from DCG-owned translation and UI rules.
- Tradeoff: every visible dialogue line and response requires a stable manual ID and four locale values.
- Tradeoff: after first installation or addon updates, the Godot editor must rescan `.dialogue` files through the addon importer.

## Validation

- `res://tools/validate_dialogue_localization.gd`
- Main project headless startup
- Godot editor restart and `.dialogue` import after plugin installation

## Links

- `res://scripts/localization/localization_bootstrap.gd`
- `res://scripts/localization/dialogue_localization_bridge.gd`
- `res://data/localization/dialogue_text.csv`
- `res://docs/design/dialogue_authoring_guide.md`
