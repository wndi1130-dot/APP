#include "res://fx/shaders/fx_common.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_tex = false;
uniform bool use_vertex_color = false;
uniform float roughness = 1.0;
uniform float metallic = 0.0;

void fragment() {
	ALBEDO = albedo_color.rgb * (has_tex ? texture(albedo_tex, UV).rgb : vec3(1.0))
			* (use_vertex_color ? COLOR.rgb : vec3(1.0));
	ROUGHNESS = roughness;
	METALLIC = metallic;
	if (fx_fill.w > 0.5) {
		EMISSION = fx_fill_term(ALBEDO, metallic, normalize(mat3(INV_VIEW_MATRIX) * NORMAL));
	}
}
