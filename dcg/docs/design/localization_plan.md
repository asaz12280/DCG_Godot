# Localization Plan

This document defines how DCG stores and consumes localized text. The goal is to keep UI, item data, prompts, and future dialogue readable in the editor while avoiding hard-coded display strings in gameplay code.

## Goals

1. All player-facing text uses a stable localization key.
2. Resources store keys, not translated copy.
3. UI scripts call `tr()` at display time.
4. `zh_TW` is the authoring locale; `en`, `ja`, and `zh_CN` should stay present for every required key.
5. Validation should catch missing item keys before the catalog grows.

## Files

- `data/localization/game_text.csv`: Source translation table.
- `data/localization/game_text.*.translation`: Godot-generated translation resources.
- `scripts/localization/localization_bootstrap.gd`: Runtime locale bootstrap.
- `scripts/items/item_def.gd`: Item resources store `name_key` and `description_key`.
- `scripts/inventory/loot_pickup_3d.gd`: Pickup prompts use `prompt_key` plus the item name key.
- `scripts/ui/*`: UI labels, buttons, headers, and status text translate keys at render/update time.

## Key Naming

Use lowercase dotted keys:

- `ui.main.start`
- `ui.inventory.backpack_format`
- `ui.codex.damage`
- `item.pistol_9mm.name`
- `item.pistol_9mm.desc`
- `item_type.weapon`
- `prompt.pickup`

Rules:

- Prefix by domain: `ui`, `item`, `item_type`, `prompt`, later `quest`, `dialogue`, or `combat`.
- Item names and descriptions must be paired as `.name` and `.desc`.
- Keep keys stable even if translated text changes.
- Do not encode quantity, rarity, or runtime values in the key.

## Item Resources

Every active `ItemDef` resource should set:

```gdscript
name_key = &"item.example.name"
description_key = &"item.example.desc"
```

`display_name` is legacy fallback only. New resources should rely on keys.

The catalog validation should continue checking:

- no missing `id`
- no missing `name_key`
- no missing `description_key`
- no invalid weight/value/stack values
- no duplicate or skipped catalog numbers

## UI Usage

UI code should translate at the edge:

```gdscript
label.text = tr("ui.main.start")
```

For optional fallback:

```gdscript
func localized_text(key: StringName, fallback: String = "") -> String:
	var key_text := str(key)
	if key_text == "":
		return fallback
	var translated := tr(key_text)
	return fallback if translated == key_text else translated
```

Avoid storing translated strings in gameplay state. Store keys or resource ids instead.

## Current Coverage

Currently localized areas:

- Main menu and settings panel
- Top gameplay menu
- Inventory/equipment UI
- Item codex
- Item names, item descriptions, and item type names
- Pickup prompt

Next likely areas:

- Combat messages
- Damage feedback
- Quest titles and objectives
- NPC dialogue
- Extraction/result screens

## Adding A New Item

1. Create the `ItemDef` resource under `data/items/<category>/`.
2. Assign a continuous `catalog_number`.
3. Add `name_key` and `description_key`.
4. Add both keys to `game_text.csv` for all supported locales.
5. Reimport translations in Godot if needed.
6. Run item catalog validation.

## Adding A New UI Screen

1. Define keys before wiring visible labels.
2. Use existing `ui.<screen>.<name>` naming.
3. Add keys to `game_text.csv`.
4. Keep runtime values in format strings such as `ui.inventory.backpack_format`.
5. Prefer a small helper method when a screen needs fallback behavior.

## Validation Backlog

Useful future checks:

- Verify every key used in `.gd` files exists in `game_text.csv`.
- Verify every active `ItemDef` key exists in every required locale.
- Verify translated format strings have the same placeholder count across locales.
- Verify no replacement characters or mojibake text appear in docs, data, or scripts.

