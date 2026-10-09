shader_type spatial;
// Windows on cars and houses. Frost grows in from the frame, rain beads and
// runs (slanted when the train moves), and a lamp inside shows through.
// Ban line (project rules): a lived-in car's window always lets its light
// through, so frost and boards may dim the glow but never hide it.
render_mode blend_mix, cull_back, depth_draw_opaque;
#include "res://fx/shaders/fx_common.gdshaderinc"

uniform vec4 glass_tint : source_color = vec4(0.12, 0.12, 0.12, 0.55);
uniform vec4 glow : source_color = vec4(1.0, 0.64, 0.30, 1.0);
uniform float glow_energy = 0.0;
// Scales the fx_frost global for this pane (sheltered panes lower).
uniform float frost_local : hint_range(0.0, 2.0) = 1.0;
// Cold car (찬 객차): heating off, frost covers the pane.
uniform float cold_car : hint_range(0.0, 1.0) = 0.0;
// Train speed in m/s. Script sets it; rain runs sideways when it grows.
uniform float speed = 0.0;
uniform float pane_scale = 1.0;

const float MIN_GLOW_THROUGH = 0.55;

void fragment() {
	vec2 uv = UV;
	vec2 e = min(uv, 1.0 - uv);
	float edge = min(e.x, e.y) * 2.0; // 0 at the frame, 1 in the middle
	float n = fx_fbm2(uv * 9.0 * pane_scale);
	float fern = fx_crystal(uv * 16.0 * pane_scale);

	float fr = clamp(max(fx_frost * frost_local, cold_car), 0.0, 1.0);
	float reach = fr * 0.8;
	float frost = fr > 0.001 ? 1.0 - smoothstep(reach - 0.06, reach + 0.08, edge + (n - 0.5) * 0.3) : 0.0;
	frost *= 0.75 + 0.25 * fern;

	// Rain: beads on a grid cell, streaks drawn back by speed.
	float wet = clamp(fx_wet, 0.0, 1.0) * (1.0 - frost);
	float slant = clamp(speed / 20.0, 0.0, 1.5);
	vec2 ru = vec2(uv.x * 26.0 + uv.y * slant * 26.0, uv.y * 7.0 + TIME * (0.35 + slant * 2.0));
	vec2 cell = floor(ru);
	float pick = step(0.82, fx_hash(cell));
	float along = fract(ru.y);
	float across = abs(fract(ru.x) - 0.5);
	float streak = pick * smoothstep(0.12, 0.02, across) * smoothstep(0.0, 0.6, along) * (1.0 - along);
	float bead = step(0.9, fx_hash(floor(uv * 34.0 * pane_scale))) * 0.6;
	float rain = wet * clamp(streak + bead, 0.0, 1.0);

	vec3 col = mix(glass_tint.rgb, FX_RIME, frost);
	col = mix(col, vec3(0.62, 0.65, 0.68), rain * 0.5);
	ALBEDO = fx_photo(col, fx_fade);
	ALPHA = clamp(mix(glass_tint.a, 0.94, frost) + rain * 0.15, 0.0, 1.0);
	ROUGHNESS = mix(0.05, 0.8, frost);
	SPECULAR = 0.5;
	// Frost scatters the lamp instead of blocking it.
	EMISSION = glow.rgb * glow_energy * max(1.0 - frost * 0.45, MIN_GLOW_THROUGH);
}
