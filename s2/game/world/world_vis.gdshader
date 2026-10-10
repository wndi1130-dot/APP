shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
#include "res://fx/shaders/fx_common.gdshaderinc"

// Low-resolution sight mask: one texel per metre cell (R = seen now, G = seen before).
uniform sampler2D vis : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(120.0, 70.0);
uniform float mask_on = 1.0;
uniform float frost = 0.0;
// Warm lamp light from the mask's B channel (weather_fx 12.2): no light nodes.
uniform vec3 lamp_color : source_color = vec3(1.0, 0.64, 0.30);
uniform float lamp_gain = 0.0;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	// Weather (fx_common globals): wet darkens and shines, snow dusts up faces.
	// Snow is capped and spares saturated colours, so loot, stove and floor
	// kinds stay readable. Floors under a roof get neither.
	float up = clamp(world_nrm.y, 0.0, 1.0);
	// Vertex alpha: 1 open to the sky, 0 under a roof (map_view.sky_alpha).
	float sky = COLOR.a;
	float wet = clamp(fx_wet, 0.0, 1.0) * sky;
	float drift = fx_fbm2(world_pos.xz * 0.35);
	float chroma = max(base.r, max(base.g, base.b)) - min(base.r, min(base.g, base.b));
	float cover = smoothstep(0.6, 0.9, up) * clamp(fx_snow * (0.6 + 0.8 * drift), 0.0, 1.0);
	cover *= 0.55 * sky * (1.0 - smoothstep(0.08, 0.3, chroma));
	base *= 1.0 - 0.35 * wet;
	base = mix(base, FX_SNOW * mix(1.0, 0.75, wet), cover);
	// Rime on upright faces in hard cold: thin and patchy, never a white wall.
	float rime = (1.0 - smoothstep(0.2, 0.6, up)) * sky * clamp(fx_frost, 0.0, 1.0);
	rime *= 0.16 * smoothstep(0.3, 0.9, fx_fbm2(vec2((world_pos.x + world_pos.z) * 0.7, world_pos.y * 1.6)));
	base = mix(base, FX_RIME, rime * (1.0 - smoothstep(0.08, 0.3, chroma)));
	vec2 uv = world_pos.xz / map_size;
	vec4 cell = texture(vis, uv);
	vec2 seen = cell.rg;
	// Seen now: full. Seen before: dim memory. Never seen: dark but readable.
	float lit = mix(1.0, max(seen.r, seen.g * 0.3 + 0.24), mask_on);
	float grey = dot(base, vec3(0.3, 0.59, 0.11));
	vec3 dimmed = mix(vec3(grey), base, seen.r * 0.6 + 0.4);
	// Tactical pause (fx_fade) fades the world before the sight mask darkens it.
	ALBEDO = fx_photo(mix(dimmed, vec3(0.86, 0.88, 0.9), frost), fx_fade) * lit;
	ROUGHNESS = mix(1.0, 0.4, wet * (1.0 - cover));
	// A lamp out of sight still shows faintly, so mates can be found in the dark.
	float lamp = cell.b * lamp_gain * mix(0.4, 1.0, seen.r) * (1.0 - 0.5 * clamp(fx_fade, 0.0, 1.0));
	EMISSION = lamp_color * (0.25 + 0.75 * grey) * lamp;
}
