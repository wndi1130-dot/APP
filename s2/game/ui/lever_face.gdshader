shader_type canvas_item;
// The lever key (UI 3단계 시안 2차 c10.css .main--lever.lv-na, B1): the iron base
// it is all one piece of, and the lamp nameplate on it. Two parts, one shader:
//   base: a rounded slab, radius 12 · 8 · 8 · 12, linear-gradient(#2e343b,
//     #1d2126 62%, #15181c) inside a 2 px rim of linear-gradient(140deg,
//     #8f7a50, #3c2f1a 50%, #6d5935); a hairline of light along its top inside,
//     a shade rising from its bottom inside, a drop shadow on what is under it.
//   plate: lamp enamel lit from below, radial-gradient(110% 150% at 50% 118%,
//     lamp1, lamp2 48%, lamp3), radius 8; a hairline of light along its top
//     inside, a warm shade rising from its bottom, a dark ring round it and a
//     faint warm glow.
// The rect reaches `reach` px past the part all round. Colours are mixed as
// the browser mixes them, in sRGB, straight alpha.

uniform bool plate = false;
uniform vec2 part_size = vec2(273.0, 89.0);
uniform float reach = 20.0;
uniform float k = 1.846;
// Corner radii, game px: top left, top right, bottom right, bottom left.
uniform vec4 radii = vec4(22.0, 15.0, 15.0, 22.0);
uniform vec4 lamp1 = vec4(0.914, 0.784, 0.525, 1.0);
uniform vec4 lamp2 = vec4(0.820, 0.549, 0.196, 1.0);
uniform vec4 lamp3 = vec4(0.580, 0.318, 0.102, 1.0);
// Pressed: brighter (brightness(1.14)); off: grey and dim (saturate(.2) brightness(.6)).
uniform float bright = 1.0;
uniform bool off = false;

float below(float z) {
	return 0.5 * (1.0 + tanh(0.7978845608 * (z + 0.044715 * z * z * z)));
}

// Signed distance to a box of half size h at the origin with corner radii r
// (top left, top right, bottom right, bottom left; y grows down).
float rbox(vec2 p, vec2 h, vec4 r) {
	float rr = p.x < 0.0 ? (p.y < 0.0 ? r.x : r.w) : (p.y < 0.0 ? r.y : r.z);
	rr = min(rr, min(h.x, h.y));
	vec2 q = abs(p) - h + vec2(rr);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rr;
}

vec4 over(vec4 under, vec4 c) {
	float a = c.a + under.a * (1.0 - c.a);
	vec3 rgb = (c.rgb * c.a + under.rgb * under.a * (1.0 - c.a)) / max(a, 1e-5);
	return vec4(rgb, a);
}

vec3 tone(vec3 c) {
	c *= bright;
	if (off) {
		float grey = dot(c, vec3(0.2126, 0.7152, 0.0722));
		c = mix(vec3(grey), c, 0.2) * 0.6;
	}
	return c;
}

void fragment() {
	vec2 box = part_size + vec2(reach * 2.0);
	vec2 p = UV * box - vec2(reach);
	vec2 h = part_size * 0.5;
	vec2 q = p - h;
	float d = rbox(q, h, radii);
	float aa = 0.75;
	vec4 col = vec4(0.0);
	if (!plate) {
		// 0 2px 6px rgba(0,0,0,.6)
		float drop = below(-rbox(q - vec2(0.0, 2.0 * k), h, radii) / (3.0 * k));
		col = over(col, vec4(0.0, 0.0, 0.0, 0.6 * drop));
		vec2 dir = vec2(sin(radians(140.0)), -cos(radians(140.0)));
		float len = abs(part_size.x * dir.x) + abs(part_size.y * dir.y);
		float t = clamp(dot(q, dir) / len + 0.5, 0.0, 1.0);
		vec3 rim = t < 0.5 ? mix(vec3(143.0, 122.0, 80.0), vec3(60.0, 47.0, 26.0), t / 0.5) : mix(vec3(60.0, 47.0, 26.0), vec3(109.0, 89.0, 53.0), (t - 0.5) / 0.5);
		rim /= 255.0;
		float bw = 2.0 * k;
		vec2 ih = h - vec2(bw);
		vec4 ir = max(radii - vec4(bw), vec4(0.0));
		float di = rbox(q, ih, ir);
		float f = (p.y - bw) / max(part_size.y - bw * 2.0, 1.0);
		vec3 iron = f < 0.62 ? mix(vec3(46.0, 52.0, 59.0), vec3(29.0, 33.0, 38.0), f / 0.62) : mix(vec3(29.0, 33.0, 38.0), vec3(21.0, 24.0, 28.0), clamp((f - 0.62) / 0.38, 0.0, 1.0));
		iron /= 255.0;
		// inset 0 1px 0 rgba(255,255,255,.07)
		float lit = (di < 0.0 && rbox(q - vec2(0.0, 1.0 * k), ih, ir) > 0.0) ? 0.07 : 0.0;
		iron = mix(iron, vec3(1.0), lit);
		// inset 0 -5px 9px rgba(0,0,0,.4)
		float shade = 1.0 - below(-rbox(q + vec2(0.0, 5.0 * k), ih, ir) / (4.5 * k));
		iron = mix(iron, vec3(0.0), 0.4 * shade);
		float in_part = clamp(0.5 - d / aa, 0.0, 1.0);
		float in_iron = clamp(0.5 - di / aa, 0.0, 1.0);
		col = over(col, vec4(tone(mix(rim, iron, in_iron)), in_part));
	} else {
		// 0 0 10px rgba(214,134,40,.16), then the ring 0 0 0 1.5px rgba(10,8,6,.6)
		if (!off) {
			float glow = below(-d / (5.0 * k));
			col = over(col, vec4(214.0 / 255.0, 134.0 / 255.0, 40.0 / 255.0, 0.16 * glow));
		}
		float ring = clamp(0.5 - rbox(q, h + vec2(1.5 * k), radii + vec4(1.5 * k)) / aa, 0.0, 1.0);
		col = over(col, vec4(10.0 / 255.0, 8.0 / 255.0, 6.0 / 255.0, 0.6 * ring));
		vec2 c = vec2(0.0, part_size.y * 1.18 - h.y);
		float r = length((q - c) / (part_size * vec2(1.1, 1.5)));
		vec3 en = r < 0.48 ? mix(lamp1.rgb, lamp2.rgb, r / 0.48) : mix(lamp2.rgb, lamp3.rgb, clamp((r - 0.48) / 0.52, 0.0, 1.0));
		// inset 0 1px 0 rgba(255,240,214,.3)
		float lit = (d < 0.0 && rbox(q - vec2(0.0, 1.0 * k), h, radii) > 0.0) ? 0.3 : 0.0;
		en = mix(en, vec3(255.0, 240.0, 214.0) / 255.0, lit);
		// inset 0 -5px 9px rgba(90,38,0,.32)
		float shade = 1.0 - below(-rbox(q + vec2(0.0, 5.0 * k), h, radii) / (4.5 * k));
		en = mix(en, vec3(90.0, 38.0, 0.0) / 255.0, 0.32 * shade);
		float in_part = clamp(0.5 - d / aa, 0.0, 1.0);
		col = over(col, vec4(tone(en), in_part));
	}
	COLOR = col;
}
