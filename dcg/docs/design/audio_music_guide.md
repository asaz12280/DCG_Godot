# DCG Audio And Music Guide

Read this file only for music, ambience, UI sound, gameplay sound, audio settings, Sound Manager, gdfxr, or audio-asset tasks.

## Ownership

- `GameSettings` is the only owner of saved Master/BGM/SFX percentages and applies them to Godot audio buses.
- Sound Manager owns playback lifecycle for non-positional music and global sounds. Project code reaches it through DCG-owned audio adapters, not scattered `/root/SoundManager` calls.
- Scene-local `AudioStreamPlayer3D` nodes own positional weapon, enemy, impact, and world sounds. Sound Manager must not replace them.
- Audio profiles/Resources own authored stream choices, pitch ranges, local gain, and source-license notes. UI does not own audio state.
- gdfxr is an editor-only authoring/import tool for original retro or placeholder SFX; it does not own playback or volume.

## Bus Contract

The setting sliders control buses once; Sound Manager category gain stays at 0 dB to avoid double attenuation.

| Setting | Godot bus | Sound Manager categories | Typical content |
|---|---|---|---|
| Master | `Master` | all output | complete game mix |
| Music | `BGM` | `BGM`, `BGS` | music and non-positional ambience |
| Sound effects | `SFX` | `SFX`, `MFX` | UI sounds, stingers, gameplay and positional 3D sounds |

`GameSettings` creates missing `BGM` and `SFX` buses, applies mute/volume, and synchronizes the Sound Manager contract through `SoundManagerBridge`. Do not add independent Sound Manager volume sliders or save a second set of percentages.

## Playback Rules

- Use Sound Manager for menu/base/raid music, music transitions, non-positional ambience, UI confirmation/cancel sounds, and global musical stingers.
- Keep weapon shots, enemy sounds, impacts, footsteps, and location-dependent ambience on local `AudioStreamPlayer3D` nodes routed to `SFX`.
- When the first production music feature lands, extend the DCG-owned audio bridge/service with the smallest required `play/fade/stop` API. Gameplay/UI scripts must not call raw Sound Manager methods directly.
- Use stable non-localized audio IDs such as `music.menu.main` or `ui.confirm`; visible translated text never doubles as an audio key.
- One gameplay event requests one sound. Do not poll playback in `_process`/`_physics_process` or trigger the same cue from both gameplay and UI.
- Keep Sound Manager resource preloading and node preinstantiation disabled until profiling proves a concrete need.

## Asset Rules

- Add production assets under focused paths such as `res://assets/audio/music/`, `res://assets/audio/ambience/`, and `res://assets/audio/sfx/<domain>/` when content exists.
- Do not keep fake/example paths in the active Sound Manager dictionary. Add an ID only with a real referenced asset and a real caller in the same change.
- Prefer WAV for short source effects and OGG for longer music/ambience when appropriate. Check import loop points and compression in Godot.
- Every external audio asset needs a source/license note and proof that commercial redistribution/modification is allowed. Keep attribution beside the asset or in its owning profile/source note.
- gdfxr output is acceptable for original UI/gameplay placeholders and intentionally synthetic sounds. It is not a substitute for final realistic firearm audio or composed music unless that is the approved art direction.
- The current procedural weapon sound remains a temporary fallback. Final weapon streams stay in `WeaponShotAudioProfile` and play through `WeaponShotAudioPlayer3D` on `SFX`.

## Completion Gate

1. The correct owner and bus are used; positional sounds remain spatial.
2. Master/BGM/SFX settings affect the new sound without a second volume multiplier.
3. Audio IDs, files, callers, and licenses are complete; no addon examples remain active.
4. Playback is event-driven and survives scene changes as intended.
5. Run `validate_audio_settings.gd`, `validate_sound_manager_integration.gd`, and the feature-specific audio validator such as `validate_weapon_shot_audio.gd`.
6. Check Godot output for import, missing stream, invalid bus, and script errors.
