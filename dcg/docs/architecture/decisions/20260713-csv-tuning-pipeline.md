# ADR 20260713: CSV Tuning Pipeline

## Status

Accepted

## Context

Item, weapon, and difficulty values need spreadsheet-style editing without spreading CSV dictionaries through inventory, combat, UI, or save code. Weapon resources also retain legacy compatibility fields that can drift from their typed profiles.

## Decision

Use CSV Data Importer for focused numeric tables under `res://data/tuning/`. `items.csv` covers all ItemDef resources and owns shared inventory/effect values; weapon combat and difficulty values remain in separate tables. `GameTuningBootstrap` loads imported dictionary records at startup, validates stable IDs and schema versions, applies values to typed resources plus legacy compatibility fields, and retains the tuned resources for the runtime session. Existing controllers continue consuming ItemDef, profiles, and snapshots.

## Options Considered

- Read CSV directly from every controller: rejected because it removes type safety and duplicates parsing and fallback logic.
- Generate and rewrite every `.tres` whenever CSV changes: deferred because it adds editor tooling and file churn before the table contract is proven.
- Apply CSV once to typed resources at startup: chosen because it keeps spreadsheet editing and the current runtime architecture.

## Consequences

- Positive: shared item, weapon combat, and difficulty values have one editable tuning source per domain.
- Positive: runtime code keeps typed Resource contracts and existing validators.
- Positive: profile and legacy ItemDef values cannot disagree during a running session.
- Tradeoff: `.tres` fallback values may be older than CSV on disk, so the tuning bootstrap and validator are required.
- Tradeoff: adding a table requires explicit schema and synchronization code; arbitrary CSVs are not accepted automatically.

## Validation

- `res://tools/validate_csv_tuning_pipeline.gd`
- `res://tools/validate_difficulty_system.gd`
- `res://tools/validate_shotgun_flow.gd`
- Main project headless startup

## Links

- `res://data/tuning/weapons.csv`
- `res://data/tuning/items.csv`
- `res://data/tuning/difficulty.csv`
- `res://scripts/data/csv_data_table_loader.gd`
- `res://scripts/data/game_tuning_bootstrap.gd`
