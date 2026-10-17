shader_type canvas_item;
// The main key's face (UI 3단계 시안 2차 c1.css · c10.css .main, B1, lamp light
// darkened for the white snow, user 2026-10-17): a pill of lamp enamel lit
// from below, in a dark brass rim; a faint warm glow and a drop shadow on what
// is under it; a hairline of light along its top inside and a warm shade
// rising from its bottom. This rect reaches `reach` px past the key all round.
// Colours are mixed as the browser mixes them, in sRGB, straight alpha.

uniform vec2 key_size = vec2(273.0, 89.0);
uniform float reach = 30.0;
uniform float rim = 3.7;
uniform float k = 1.846;
uniform vec4 lamp1 = vec4(0.914, 0.784, 0.525, 1.0);
uniform vec4 lamp2 = vec4(0.820, 0.549, 0.196, 1.0);
uniform vec4 lamp3 = vec4(0.580, 0.318, 0.102, 1.0);
uniform vec4 rim1 = vec4(0.733, 0.635, 0.435, 1.0);
uniform vec4 rim2 = vec4(0.337, 0.251, 0.118, 1.0);
uniform vec4 rim3 = vec4(0.541, 0.439, 0.251, 1.0);
// Pressed: down 2 px and brighter (translateY(2px) brightness(1.14)).
uniform float sink = 0.0;
uniform float bright = 1.0;
// Off: grey and dim (saturate(.2) brightness(.6)), no glow.
uniform bool off = false;

float below(float z) {
	return 0.5 * (1.0 + tanh(0.7978845608 * (z + 0.044715 * z * z * z)));
}

// Signed distance to a pill of half size h centred at the origin.
float pill(vec2 p, vec2 h) {
	float r = min(h.x, h.y);
	vec2 q = abs(p) - h + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec4 over(vec4 under, vec4 c) {
	float a = c.a + under.a * (1.0 - c.a);
	vec3 rgb = (c.rgb * c.a + under.rgb * under.a * (1.0 - c.a)) / max(a, 1e-5);
	return vec4(rgb, a);
}

void fragment() {
	vec2 box = key_size + vec2(reach * 2.0);
	vec2 p = UV * box - vec2(reach) - vec2(0.0, sink);
	vec2 h = key_size * 0.5;
	vec2 q = p - h;
	float d = pill(q, h);
	vec4 col = vec4(0.0);
	// Outside: the glow, then the drop shadow over it.
	if (!off) {
		float glow = below(-d / (6.0 * k));
		col = over(col, vec4(214.0, 134.0, 40.0, 0.0) / 255.0 + vec4(0.0, 0.0, 0.0, 0.2 * glow));
	}
	float drop = below(-pill(q - vec2(0.0, 2.0 * k), h) / (3.0 * k));
	col = over(col, vec4(0.0, 0.0, 0.0, 0.6 * drop));
	// The rim: linear-gradient(140deg, rim1, rim2 50%, rim3) over the whole key.
	vec2 dir = vec2(sin(radians(140.0)), -cos(radians(140.0)));
	float len = abs(key_size.x * dir.x) + abs(key_size.y * dir.y);
	float t = clamp(dot(q, dir) / len + 0.5, 0.0, 1.0);
	vec3 rimc = t < 0.5 ? mix(rim1.rgb, rim2.rgb, t / 0.5) : mix(rim2.rgb, rim3.rgb, (t - 0.5) / 0.5);
	// The enamel inside the rim: radial-gradient(110% 150% at 50% 118%, lamp1, lamp2 48%, lamp3).
	vec2 inner_h = h - vec2(rim);
	float di = pill(q, inner_h);
	vec2 c = vec2(0.0, inner_h.y * 2.0 * 1.18 - inner_h.y);
	float r = length((q - c) / (inner_h * 2.0 * vec2(1.1, 1.5)));
	vec3 en = r < 0.48 ? mix(lamp1.rgb, lamp2.rgb, r / 0.48) : mix(lamp2.rgb, lamp3.rgb, clamp((r - 0.48) / 0.52, 0.0, 1.0));
	// inset 0 1px 0 rgba(255,240,214,.3): the top hairline inside the rim.
	float lit = (di < 0.0 && pill(q - vec2(0.0, 1.0 * k), inner_h) > 0.0) ? 0.3 : 0.0;
	en = mix(en, vec3(255.0, 240.0, 214.0) / 255.0, lit);
	// inset 0 -7px 12px rgba(90,38,0,.32): a warm shade rising from the bottom.
	float shade = 1.0 - below(-pill(q + vec2(0.0, 7.0 * k), inner_h) / (6.0 * k));
	en = mix(en, vec3(90.0, 38.0, 0.0) / 255.0, 0.32 * shade);
	float aa = 0.75;
	float in_key = clamp(0.5 - d / aa, 0.0, 1.0);
	float in_en = clamp(0.5 - di / aa, 0.0, 1.0);
	vec3 face = mix(rimc, en, in_en) * bright;
	if (off) {
		float grey = dot(face, vec3(0.2126, 0.7152, 0.0722));
		face = mix(vec3(grey), face, 0.2) * 0.6;
	}
	col = over(col, vec4(face, in_key));
	COLOR = col;
}
