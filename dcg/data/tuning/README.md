# DCG Tuning Tables

These CSV files own player-adjustable numeric tuning. CSV Data Importer should import them as `CSV Data` with headers, number detection enabled, integer preservation enabled, and boolean detection enabled.

- `weapons.csv`: weapon and melee combat values applied to `WeaponProfile` plus legacy `ItemDef` fallback fields.
- `difficulty.csv`: values applied to `DifficultyProfile`.
- `items.csv`: shared ItemDef tuning for weight, value, stack limit, and general consumable/totem effects. Weapon combat, armor protection, and attachment multipliers stay in their domain tables.

Runtime controllers must continue reading typed resources and snapshots. Only `GameTuningBootstrap` may apply these table values. Localization, dialogue, scenes, assets, save state, and resource references do not belong in tuning tables.
