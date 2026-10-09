shader_type spatial;
// Grass tufts, bare branches, reeds and hedge cards. The top sways with the
// fx_wind global; the base stays put. Sway weight is the object-space height
// over `height`, so cards need their root at y = 0.
render_mode cull_disabled, world_vertex_coords;
#include "res://fx/shaders/fx_common.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 albedo : source_color = vec4(0.30, 0.32, 0.26, 1.0);
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform float height = 1.0;
// Metres the tip travels in full wind.
uniform float sway = 0.25;
uniform float freq = 1.3;
uniform float snow_catch : hint_range(0.0, 1.0) = 0.6;

varying float tip;

void vertex() {
	// world_vertex_coords: VERTEX is already in world space here.
	vec3 root = MODEL_MATRIX[3].xyz;
	float h = clamp((VERTEX.y - root.y) / max(height, 0.01), 0.0, 1.0);
	h *= h;
	tip = h;
	float phase = TIME * freq + dot(root.xz, vec2(0.37, 0.21));
	float gust = 0.6 + 0.4 * sin(phase * 0.37 + root.x * 0.05);
	float s = clamp(fx_wind.z, 0.0, 1.0);
	vec2 dir = length(fx_wind.xy) > 0.001 ? normalize(fx_wind.xy) : vec2(1.0, 0.0);
	float lean = (0.45 + 0.55 * (0.5 + 0.5 * sin(phase))) * gust;
	vec2 flutter = vec2(sin(phase * 2.3), cos(phase * 1.7)) * 0.04;
	vec2 off = (dir * lean * sway + flutter) * s * h;
	VERTEX.xz += off;
	VERTEX.y -= dot(off, off) * 0.5; // bending shortens the stalk a little
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV) * albedo;
	vec3 base = tex.rgb * COLOR.rgb;
	// Snow sits on the upper part only.
	float s = clamp(fx_snow, 0.0, 1.0) * snow_catch;
	base = mix(base, FX_SNOW, s * smoothstep(0.3, 0.9, tip) * 0.7);
	base *= mix(1.0, 0.7, clamp(fx_wet, 0.0, 1.0));
	ALBEDO = fx_photo(base, fx_fade);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.95;
}
