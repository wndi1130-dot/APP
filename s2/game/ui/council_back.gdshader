shader_type canvas_item;
// What is behind the special session (UI 3단계 시안 2차 k3c_views.js councilBack,
// c3.css .cnback · .cnshade): the dining car as the train draws it under this
// rect, softened, at brightness(.4) saturate(.42), and over it the room's dark
// falling off from the lamp, radial-gradient(<radius> at <at>, c0, c1 <mid>, c2)
// (after the vote a deeper one, #stage[data-res] .cnshade). Colours are mixed
// as the browser mixes them, in sRGB, straight alpha.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// The softening: blur(1.8px), as a mip level of the screen.
uniform float lod = 1.6;
uniform float brightness = 0.4;
uniform float saturation = 0.42;
uniform vec2 at = vec2(0.47, 0.66);
uniform vec2 radius = vec2(0.64, 0.86);
uniform float mid = 0.62;
uniform vec4 c0 = vec4(0.0196, 0.0275, 0.0392, 0.6);
uniform vec4 c1 = vec4(0.0196, 0.0275, 0.0392, 0.5);
uniform vec4 c2 = vec4(0.0118, 0.0157, 0.0235, 0.9);

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb * brightness;
	float grey = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(grey), c, saturation);
	// An ellipse of `radius` (fractions of the rect) round `at`; 1 on its edge.
	float r = length((UV - at) / radius);
	vec4 s = r < mid ? mix(c0, c1, r / mid) : mix(c1, c2, clamp((r - mid) / (1.0 - mid), 0.0, 1.0));
	COLOR = vec4(mix(c, s.rgb, s.a), 1.0);
}
