shader_type spatial;
render_mode cull_back;
// The field's living (game/actors/person_visual.gd): the dead's shader with what is
// worn over the body in its own look, and the hands gloved by the shader.
#define WORN
#include "res://game/actors/dead_vat.gdshaderinc"
