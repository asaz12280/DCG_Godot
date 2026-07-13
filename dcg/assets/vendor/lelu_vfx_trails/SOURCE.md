# LeLu VFX Trails Runtime Selection

Source package:

`D:\3DMesh\Godot_Tool\GODOT_VFX2\VFX_Trails_Demo(PREMIUM)`

Selected runtime material:

- `GPUTrail-main/GPUTrail3D.gd`
- `GPUTrail-main/shaders/trail.gdshader`
- `GPUTrail-main/shaders/trail_draw_pass.gdshader`
- `GPUTrail-main/defaults/curve.tres`
- `GPUTrail-main/defaults/texture.tres`
- `GPUTrail-main/bounce.svg`
- `Textures/T_VFX_BlueTRails1.png`

The GPU trail implementation is attributed to celyk and is distributed under the included MIT `LICENSE`.

DCG adaptation:

- `res://scenes/combat/vfx/melee_crescent_slash_3d.tscn` retains the single-sword demo's blue trail texture and blue-white color relationship.
- The source `GPUTrail3D` frame-history renderer remains preserved for reference but is not attached to the short DCG melee swing. Raising its particle count did not remove visible corners because the moving transform still changed only once per rendered frame.
- DCG uses a 128-segment analytic arc mesh with continuous UVs. After gameplay review, the authored texture remains preserved for source reference but is no longer sampled by the runtime slash. The primary blade body now uses an unshaded, pure-white, fully opaque `StandardMaterial3D`; only the separate glow and blade-detail layers use transparent shader animation.
- DCG owns swing timing, attack-range scaling, attack-arc motion, and lifecycle. Confirmed knife-hit feedback is intentionally absent.
- Demo characters, sword models, cameras, environments, labels, and unrelated particles are excluded.
- Runtime resources must not reference the absolute source-package path.
