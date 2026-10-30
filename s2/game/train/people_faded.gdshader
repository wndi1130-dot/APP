shader_type spatial;
render_mode cull_back, depth_draw_always;
// The train's people while a car is decorated (decor_view.gd): the people's own shader, seen through
// by `fade` (dead_vat.gdshaderinc FADED), its depth still written so the train's walls behind stay behind.
// train_people_view.gd puts it on the bodies' materials and back.
#define FADED
#include "res://game/actors/dead_vat.gdshaderinc"
