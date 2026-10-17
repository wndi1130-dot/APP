shader_type canvas_item;
// The paper of a sheet (UI 3단계 시안 2차 c2.css .sheet, B1): the paper's colour;
// over it, from the bottom, the soot and hand grime that soak into its edges,
// a darker band along both sides, the fold down the middle, then the fibres
// (tex/paper.png). The right edge is torn off the pad (tex/tear.png down it).
// In shadow mode it is the sheet's drop shadow instead: black, soft, the
// sheet's shape (CSS drop-shadow 8px 6px 14px rgba(0,0,0,.62)).
// Colours are mixed as the browser mixes them, in sRGB, straight alpha.

uniform sampler2D paper_tex : repeat_enable, filter_linear;
uniform sampler2D tear_tex : repeat_enable, filter_linear;
// The sheet's size in px (in shadow mode: the sheet's, not this rect's).
uniform vec2 sheet_size = vec2(823.0, 639.0);
// The fibre tile, the solid part's cut from the right, the torn strip's size.
uniform float tile = 443.0;
uniform float cut = 24.0;
uniform vec2 tear = vec2(25.8, 443.0);
uniform vec4 paper = vec4(0.804, 0.761, 0.659, 1.0);
uniform bool shadow = false;
// Shadow mode: how far this rect reaches past the sheet on each side, and the blur.
uniform float reach = 40.0;
uniform float sigma = 12.9;
uniform float shadow_alpha = 0.62;

vec3 lay(vec3 under, vec3 c, float a) {
	return mix(under, c, clamp(a, 0.0, 1.0));
}

// The normal curve's share below z (tanh fit).
float below(float z) {
	return 0.5 * (1.0 + tanh(0.7978845608 * (z + 0.044715 * z * z * z)));
}

float torn(vec2 p) {
	float solid = p.x < sheet_size.x - cut ? 1.0 : 0.0;
	float tx = (p.x - (sheet_size.x - tear.x)) / tear.x;
	float strip = 0.0;
	if (tx >= 0.0 && tx <= 1.0) {
		strip = texture(tear_tex, vec2(tx, fract(p.y / tear.y))).a;
	}
	return max(solid, strip);
}

void fragment() {
	if (shadow) {
		vec2 box = sheet_size + vec2(reach * 2.0);
		vec2 p = UV * box - vec2(reach);
		float fx = below(p.x / sigma) - below((p.x - sheet_size.x) / sigma);
		float fy = below(p.y / sigma) - below((p.y - sheet_size.y) / sigma);
		COLOR = vec4(0.0, 0.0, 0.0, shadow_alpha * fx * fy);
	} else {
		vec2 p = UV * sheet_size;
		vec2 f = p / sheet_size;
		vec3 c = paper.rgb;
		// radial-gradient(120% 110% at 46% 38%, rgba(40,28,14,0) 52%, rgba(40,28,14,.26))
		float r = length((f - vec2(0.46, 0.38)) / vec2(1.2, 1.1));
		c = lay(c, vec3(40.0, 28.0, 14.0) / 255.0, 0.26 * clamp((r - 0.52) / 0.48, 0.0, 1.0));
		// linear-gradient(96deg, rgba(104,82,50,.22), transparent 24%, transparent 72%, rgba(104,82,50,.15))
		vec2 dir = vec2(sin(radians(96.0)), -cos(radians(96.0)));
		float len = abs(sheet_size.x * dir.x) + abs(sheet_size.y * dir.y);
		float t = dot(p - sheet_size * 0.5, dir) / len + 0.5;
		float edge = t < 0.24 ? 0.22 * (1.0 - t / 0.24) : (t > 0.72 ? 0.15 * (t - 0.72) / 0.28 : 0.0);
		c = lay(c, vec3(104.0, 82.0, 50.0) / 255.0, edge);
		// The fold: linear-gradient(90deg, transparent 49.7%, rgba(60,44,24,.1) 50%, rgba(255,252,240,.22) 50.3%, transparent 50.8%)
		float x = f.x;
		if (x > 0.497 && x <= 0.5) {
			c = lay(c, vec3(60.0, 44.0, 24.0) / 255.0, 0.1 * (x - 0.497) / 0.003);
		} else if (x > 0.5 && x <= 0.503) {
			float k = (x - 0.5) / 0.003;
			float a = mix(0.1, 0.22, k);
			vec3 col = mix(vec3(60.0, 44.0, 24.0) * 0.1, vec3(255.0, 252.0, 240.0) * 0.22, k) / 255.0 / max(a, 1e-4);
			c = lay(c, col, a);
		} else if (x > 0.503 && x < 0.508) {
			c = lay(c, vec3(255.0, 252.0, 240.0) / 255.0, 0.22 * (1.0 - (x - 0.503) / 0.005));
		}
		vec4 fib = texture(paper_tex, p / tile);
		c = lay(c, fib.rgb, fib.a);
		COLOR = vec4(c, paper.a * torn(p));
	}
}
