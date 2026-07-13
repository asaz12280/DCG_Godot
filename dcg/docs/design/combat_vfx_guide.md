# DCG Combat VFX Guide

Read this file only for firearm or melee VFX work. Combat VFX is optional presentation: it consumes confirmed combat events and may never own damage, targeting, cadence, projectile physics, inventory, persistence, weapon switching, or shot audio.

## Firearms

- Pistol-S and SMG-S share the approved DCG-owned `WeaponVfxProfile` scenes for muzzle, projectile travel, world impact, and confirmed target response. Shotgun-SG reuses the Pistol-S profile.
- `CombatVfxSpawner3D` owns presentation selection. `WeaponController3D` and `Projectile3D` only report confirmed source/travel/contact events.
- Keep four readable beats at gameplay camera distance: muzzle source, forward-only red tracer, restrained world contact, and distinct confirmed-enemy response.
- Source layers share the authored `MuzzleMarker3D` center. Contrast backing uses a radial alpha mask, never an opaque/black square.
- The tracer remains fully forward of the muzzle on its spawn frame. World contact must not trigger confirmed-target response.
- Approved vendor preview layers currently include `VFX_Hit_fire_2` at muzzle, `VFX_Fire_strike` on travel, and the centered ring/cross from `VFX_Anticipation_fire_3` for confirmed firearm hits.
- Do not restore point lights, fragment sparks, demo maps/managers, showcase gameplay, or unrelated vendor systems.
- Validate with `validate_weapon_vfx_profiles.gd`, `validate_projectile_3d.gd`, and `validate_projectile_hit_enemy.gd`.

## Melee

- `MeleeAttackService` owns targeting/damage and returns confirmed `hit_positions`; `MeleeVfxSpawner3D` owns presentation only.
- The crescent is a DCG-owned 128-segment analytic ribbon, plays counterclockwise near player mid-height, and stays inside the service-provided attack range including glow expansion.
- `BladeTrail`, `ArcGlow`, and `BladeCore` are the current white-only layers with one shared reveal/fade lifecycle. `BladeCore` is the narrow moving cutting edge; `ArcGlow` stays broad and low alpha.
- `SpeedLines` is one shorter inner segmented arc, not a separate frame-history trail. Any particles are short, range-bounded, one-shot, shadowless, collision-free, and have no point light.
- `knife_hit_fire_2.tscn` is the local alpha-0.5 fire ring for swing start only.
- Confirmed melee damage spawns one short-lived `MeleeEnemyHitFeedback3D` per service-resolved hit position. It uses the approved white ring from `VFX_Anticipation_fire_3` at 0.51 scale with the cross disabled; firearm VFX is unchanged.
- Do not restore blue tint, opaque all-white crescents, frame-history trails, fixed forward offsets, long-lived speed lines, `MeleeImpactFlash3D`, PolyBlocks stars, generic flashes, vendor slash gameplay, or firearm target-hit scenes for melee damage.
- All melee VFX `MeshInstance3D` nodes use `cast_shadow = 0`.
- Validate with `validate_melee_weapon_flow.gd`.

## Preview And Vendor Assets

- Use `res://scenes/combat/vfx/melee_vfx_preview_3d.tscn`; select its root and press Inspector `Preview Slash`. It instantiates the real slash scene and does not duplicate combat logic.
- Runtime-generated mesh VFX that need art tuning provide an editor-only `@tool` preview using the same geometry/material builders and no combat, hit detection, or runtime timers.
- Keep licensed source material under an isolated `res://assets/vendor/<package>/` folder with `LICENSE` and `SOURCE.md`. Copy only selected scenes/direct dependencies, rewrite paths, and let DCG rebuild imports.
- Never copy source-project `.import`, `.uid`, `.depren`, absolute tool paths, demo gameplay, characters, cameras, environments, or managers unless explicitly approved.
- League of Legends is a clarity/hierarchy/timing reference only; never copy Riot assets, silhouettes, palettes, names, exact timings, or layouts.
