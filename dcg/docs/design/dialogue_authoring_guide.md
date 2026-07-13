# DCG Dialogue Authoring Guide

The current vendored addon is Dialogue Manager `3.10.2`. Its runtime compiler and CSV translation path are validated in the DCG Godot 4.7 project. Keep DCG integration files outside `res://addons/dialogue_manager/` so an addon update cannot overwrite project-owned rules.

## Ownership

- Dialogue Manager handles dialogue syntax, branching, conditions, mutations, and runtime line delivery.
- `LocalizationBootstrap` owns the active locale and loads all DCG translation tables.
- `DialogueLocalizationBridge` keeps Dialogue Manager in CSV-key mode.
- Production dialogue presentation must reuse the DCG UI system. The addon's example Balloon is not production UI.

## Paths

- Story scripts: `res://data/dialogue/`
- Dialogue translations: `res://data/localization/dialogue_text.csv`
- Starter template: `res://data/dialogue/story_template.dialogue`
- Validation: `res://tools/validate_dialogue_localization.gd`

## Authoring Pattern

Write the fallback copy in Traditional Chinese and assign every visible line and response a permanent ID:

```text
~ start
這是一句故事台詞。 [ID:dialogue.prologue.arrival.001]
- 繼續 [ID:dialogue.prologue.arrival.continue]
	下一句台詞。 [ID:dialogue.prologue.arrival.002]
=> END
```

Add the same IDs to `dialogue_text.csv` with non-empty `zh_TW` and `en` values. Wording may change without changing the ID.

Use Dialogue Manager for NPC conversations, quest acceptance and turn-in scenes, branching choices, story conditions, mutations, and ordered narrative events. Keep quest objectives/rewards, item and weapon data, static UI labels, codex facts, combat feedback, and ordinary system notifications in their existing domain owners.

## Completion Gate

1. Every visible dialogue line and response has a stable `dialogue.*` ID.
2. Every ID has both required locale values: `zh_TW` and `en`.
3. Dialogue IDs do not duplicate keys in `game_text.csv`.
4. `validate_dialogue_localization.gd` passes.
5. The active DCG dialogue UI shows no Chinese fallback while running in English.
