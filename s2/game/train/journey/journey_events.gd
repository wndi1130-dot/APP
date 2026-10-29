extends RefCounted
## The outside events' actors by name (journey_director.gd EVENTS). Each is a Node3D
## laid in the flowing land where the event comes into sight, with
##   begin(journey, event, seed)    what it is ({id, variant, kind}) and its own dice
##   advance(delta, travelled)      one tick; travelled is the journey's metres run
##   is_done() -> bool              gone by and out of sight: the journey frees it
## The land's frame: x along the line, z across it (+z the camera's side), y up from
## the rails' top. Looks only.

const ACTORS: Dictionary = {
	"dead_rush": "res://game/train/journey/journey_dead.gd",
	"crows_rise": "res://game/train/journey/journey_crows.gd",
	"dead_wagons": "res://game/train/journey/journey_wagons.gd",
}


static func make(id: String) -> Node3D:
	if not ACTORS.has(id):
		return null
	var script: Script = load(String(ACTORS[id]))
	return script.new() as Node3D
