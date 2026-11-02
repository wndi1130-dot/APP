shader_type spatial;
render_mode cull_back;
// The field's dead (game/actors/zombies.gd): the dead's shader with each one's
// wear and tear laid over its colour picture (blood, dirt, the skin gone off).
#define WEATHERED
#define SIGHT_FADE
#include "res://game/actors/dead_vat.gdshaderinc"
