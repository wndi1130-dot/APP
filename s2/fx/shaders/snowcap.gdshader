shader_type spatial;
// Snow cap lying on a model (weather_fx.md 13장): the NAME_snowcap mesh made
// by tools/blender/tripo_prep.py --snowcap. The mesh comes lifted to its full
// depth; vertex colour R is the share of that depth (rim 0, inside 1). Lying
// snow (fx_snow) lowers or raises it, and thin snow drops the rim first.
// Turn shadow casting off on the node: the cap takes shadows but throws none.
#include "res://fx/shaders/fx_common.gdshaderinc"

// Metres the mesh was lifted (tripo_prep --snow-depth) and the snow depth in
// centimetres that stands for.
uniform float full_depth = 0.25;
uniform float full_cm = 25.0;
// Never deeper than this many times the full depth.
uniform float max_scale = 2.0;
// SnowCover.cover_for constants (game/sim/snow_cover.gd), to read fx_snow
// back into centimetres.
uniform float cover_max = 0.95;
uniform float cover_scale_cm = 13.5;

varying float share;
varying float amount;

void vertex() {
	float cover = clamp(fx_snow, 0.0, cover_max - 0.01);
	float cm = -cover_scale_cm * log(1.0 - cover / cover_max);
	amount = clamp(cm / full_cm, 0.0, max_scale);
	share = COLOR.r;
	VERTEX.y += full_depth * share * (amount - 1.0);
}

void fragment() {
	// Under about a third of the full depth the rim melts back to nothing.
	float keep = smoothstep(0.0, 0.35, amount);
	if (share + keep < 1.0 || amount <= 0.01) {
		discard;
	}
	ALBEDO = fx_photo(FX_SNOW * 1.2, fx_fade);
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
