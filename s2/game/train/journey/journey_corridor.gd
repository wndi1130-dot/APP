extends RefCounted
## The land on the way into a stop (결정 495 4절): the stop scene (stop_cinema.gd
## _lay_corridor) lays the same kit the train's screen did, the order of its sections
## going on from where the train's screen left it (journey.gd handoff), so the land does
## not change at the cut. With no train screen to go on from, the stretch's own band
## and window. Only what stands on the land and the roads and water (the stop scene has
## its own ground); no outside event (the stop card is a decision card, and at a stop
## crows and blood are omens only, presentation_motion.md 5장). Looks only.

const Kit = preload("res://game/train/journey/journey_kit.gd")
const Route = preload("res://game/train/journey/journey_route.gd")
const Sequencer = preload("res://game/train/journey/journey_sequencer.gd")

## The setting that lays it (on; off, the stop scene keeps its own corridor everywhere).
const SETTING := "visuals/journey_corridor_enabled"
## The run the sections' lengths are counted at (journey.gd RUN_SPEED): the same land
## goes on for as long in metres as it would have on the train's screen.
const RUN_SPEED: float = 8.0
## The stop scene's frame: the line along x through z 1.5, its rails' top 0.22 over its ground at 0.
const TRACK_Z: float = 1.5
const RAIL_Y: float = 0.22
const VIEW_M: float = 360.0
## The stop scene's camera beside the train stands 26 m out on the camera's side
## (stop_cinema.gd SIDE_AT): nothing tall nearer than this there.
const NEAR_CLEAR: float = 34.0
## Pieces laid a frame (the kit's are heavier than the stop scene's firs), and the
## first metre laid (the camera never looks further back than this).
const PER_FRAME: int = 2
const FIRST_X: float = -40.0

var window: Dictionary = {}
var look: Dictionary = {}
var seq = Sequencer.new()
var _section: Dictionary = {}
var _section_end: float = -INF
var _chunk_i: int = 0
## Running seconds at the corridor's first metre (the train screen's, going on), and that metre.
var _t0: float = 0.0
var _x_origin: float = NAN
## Metres of the train screen's section under way still to lay (handoff section_left_m).
var _carry_m: float = 0.0


## A corridor going on from `handoff` (journey.gd handoff()), or, when that is empty,
## for stretch `seg`'s last window on `seed_value`. Null where the band has no kit yet
## (the stop scene keeps its own corridor there).
static func make(handoff: Dictionary, seg: int, seed_value: int) -> RefCounted:
	if not bool(ProjectSettings.get_setting(SETTING, true)):
		return null
	var c = load("res://game/train/journey/journey_corridor.gd").new()
	if not handoff.is_empty():
		c.window = handoff.get("window", {})
		c.look = handoff.get("look", {})
		c.seq.setup(int(handoff.get("seed", seed_value)))
		c.seq.history = (handoff.get("history", []) as Array).duplicate(true)
		c._t0 = float(handoff.get("at", 0.0))
		# The section the train's screen was laying goes on first, for what it had left.
		var sec: Dictionary = handoff.get("section", {})
		if not sec.is_empty() and float(handoff.get("section_left_m", 0.0)) > 0.5:
			c._section = sec.duplicate()
			c._carry_m = float(handoff["section_left_m"])
			c._chunk_i = int(handoff.get("chunk", 0))
	else:
		var ws: Array = Route.windows(seg)
		c.window = ws[-1] if not ws.is_empty() else {"band": Route.DEFAULT_BAND, "neutral": false}
		c.seq.setup(hash([seed_value, seg, "corridor"]))
	if Route.kinds(c.window).is_empty():
		return null
	return c


## Lay the land from x0 to x1 of the stop scene's line under `world`, as white and
## wet as the stop's ground lies (stop_cinema.gd white, wet).
func lay(world: Node3D, x0: float, x1: float, white: float, wet: float) -> void:
	var x: float = x0
	if is_nan(_x_origin):
		_x_origin = x0
		if _carry_m > 0.0:
			_section_end = x0 + _carry_m
	while x < x1 - 0.5:
		if x >= _section_end:
			_section = seq.next(_t0 + (x - _x_origin) / RUN_SPEED, Route.kinds(window))
			if not bool(_section.get("extend", false)):
				_chunk_i = 0
			_section_end = x + float(_section["len_s"]) * RUN_SPEED
		var end: float = minf(x1, _section_end)
		var node: Node3D = Kit.build(String(_section["kind"]), x, end, _section, look,
			{"ground": false, "field_y": -RAIL_Y, "neutral": bool(window.get("neutral", false)), "chunk": _chunk_i,
				"white": white, "wet": wet, "cast_shadow": true, "far": true, "near_clear": NEAR_CLEAR})
		node.position = Vector3(x, RAIL_Y, TRACK_Z)
		# As far as the stop scene draws its own corridor (stop_cinema.gd CORRIDOR_AHEAD + 120).
		for g in node.find_children("*", "GeometryInstance3D", true, false):
			var gi := g as GeometryInstance3D
			if gi.visibility_range_end <= 0.0:
				gi.visibility_range_end = VIEW_M
		world.add_child(node)
		_chunk_i += 1
		x = end
