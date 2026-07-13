# LeLu VFX2 Firearm Texture Adaptation

Licensed source root: `D:\3DMesh\Godot_Tool\GODOT_VFX2`.

Full runtime-preview import:

- `VFX Magic Projectiles (PREMIUM)\VFX` copied to `res://VFX/` so the licensed `VFX_Anticipation_fire_3`, `VFX_Hit_fire_2`, and `VFX_Fire_strike` scenes can retain their authored shaders, materials, particle layers, and local `Trail3D` dependency.

Copied direct dependencies:

- `VFX Magic Projectiles (PREMIUM)\VFX\Textures\T_basic1_vfx.PNG` as `soft_circle.png`.
- `VFX_Hit_Impacts_(PREMIUM)\VFX\Textures\T_fl8_vfx.png` as `impact_flare.png`.
- `VFX_Hit_Impacts_(PREMIUM)\VFX\Textures\T_Fl3.PNG` as `muzzle_burst.png`.
- `VFX_Hit_Impacts_(PREMIUM)\VFX\Textures\T_Fl4.png` as `impact_shock_ring.png`.
- `VFX Magic Projectiles (PREMIUM)\VFX\Textures\T_flare8_vfx.png` as `hit_fire2_flare.png` for the `VFX_Hit_fire_2`-derived muzzle core.
- `VFX Magic Projectiles (PREMIUM)\VFX\Textures\T_FireTrail_Desat.PNG` as `fire_strike_trail.png` for the `VFX_Fire_strike`-derived tracer material.

Use: DCG-owned firearm source and contact wrapper scenes only. The copied burst and shock-ring textures are single centered billboard layers, not fragment particle effects. The full Magic Projectiles VFX folder is present only because the user explicitly approved a visual-preview integration of `VFX_Anticipation_fire_3`, `VFX_Hit_fire_2`, and `VFX_Fire_strike`; `VFX_Hit_fire_2` and `VFX_Fire_strike` have their `OmniLight3D` nodes removed. Demo maps, `GameManager`, projectiles showcase flow, and demo gameplay scripts remain excluded.

The copied `LICENSE.txt` permits personal/commercial project use and modification but forbids redistributing or selling the asset product. No vendor scenes, demo scripts, characters, weapons, or environment models are copied.
