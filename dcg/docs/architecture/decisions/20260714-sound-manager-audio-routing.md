# ADR 20260714: Sound Manager Audio Routing

## Status

Accepted

## Context

DCG has persistent Master/BGM/SFX settings and spatial firearm playback, but no shared owner yet for future music, fades, global ambience, or UI sounds. Sound Manager provides non-positional playback but also introduces its own category gain and autoload.

## Decision

Enable Sound Manager as the non-positional playback backend while keeping `GameSettings` as the only saved volume owner. Route Sound Manager `BGM/BGS` to the Godot `BGM` bus and `SFX/MFX` to `SFX`; keep all plugin category gains at 0 dB. Use a DCG-owned bridge for integration. Positional sounds remain scene-local `AudioStreamPlayer3D` nodes.

## Consequences

- Existing settings control Sound Manager and spatial audio through the same buses.
- Music/global sound gains one persistent playback backend without replacing weapon/world audio.
- Raw plugin calls are contained behind a project-owned boundary.
- The plugin autoload and its JSON bus configuration become required project wiring.
- The vendored scene script UIDs are normalized to this project so Godot does not fall back to path-only loading; recheck them after plugin upgrades.
- Sound Manager preloading/preinstantiation stays disabled until measured.

## Validation

- `res://tools/validate_audio_settings.gd`
- `res://tools/validate_sound_manager_integration.gd`
- `res://tools/validate_weapon_shot_audio.gd`
