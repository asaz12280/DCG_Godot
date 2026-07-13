shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 trail_blue : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 trail_white : source_color = vec4(0.84, 0.94, 1.0, 1.0);
uniform float reveal_progress : hint_range(0.0, 1.0) = 0.0;
uniform float trail_alpha : hint_range(0.0, 1.0) = 1.0;
uniform int layer_mode : hint_range(0, 2) = 0;

void fragment() {
	float width_feather = smoothstep(0.0, 0.06, UV.y) * (1.0 - smoothstep(0.94, 1.0, UV.y));
	float tail_feather = smoothstep(0.0, 0.08, UV.x);
	float reveal_mask = 1.0 - smoothstep(reveal_progress, reveal_progress + 0.035, UV.x);
	float leading_progress = max(reveal_progress, 0.001);
	float trailing_energy = smoothstep(max(leading_progress - 0.52, 0.0), leading_progress, UV.x);
	vec3 color = trail_blue.rgb;
	float layer_alpha = width_feather * (0.92 + trailing_energy * 0.06);
	if (layer_mode == 1) {
		color = trail_blue.rgb;
		layer_alpha = width_feather * (0.18 + trailing_energy * 0.22);
	} else if (layer_mode == 2) {
		float outer_edge = 1.0 - smoothstep(0.018, 0.075, UV.y);
		float sweep_head = 1.0 - smoothstep(0.025, 0.17, abs(UV.x - reveal_progress));
		float moving_glint = sweep_head * (1.0 - smoothstep(0.12, 0.72, UV.y));
		color = trail_white.rgb;
		layer_alpha = max(outer_edge * (0.16 + trailing_energy * 0.28), moving_glint * 0.78);
	} else {
		float outer_tint = 1.0 - smoothstep(0.08, 0.86, UV.y);
		color = mix(trail_blue.rgb, trail_white.rgb, outer_tint * 0.28);
	}
	ALBEDO = color;
	EMISSION = color * (0.16 + float(layer_mode) * 0.18);
	ALPHA = layer_alpha * tail_feather * reveal_mask * trail_alpha;
}
