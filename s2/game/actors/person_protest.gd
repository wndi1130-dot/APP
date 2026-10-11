extends RefCounted
## Someone left on the platform as the train goes (user 2026-10-12): they shout
## after it. Three ways of doing it, so that people side by side do not move
## as one. It reads one clock and moves the same boxes person_pose.gd moves;
## it decides nothing, and it does not move the person (running a few steps
## after the train is the rules').
##
## The field marks who protests: p.set_meta(META, {"kind": 0..2, "t": seconds
## since they began}) and adds to "t" as time passes; remove_meta ends it.
## The words over the head and the shout are not here.

const META: String = "protest"
const KINDS: int = 3
const FISTS: int = 0     # both fists up over the head in a V, pumping, up on the toes
const POINTS: int = 1    # one arm jabbed at the train again and again, the other fist held back
const SINKS: int = 2     # arms flung wide, then down on the knees, beating the ground

const ARM_SIDE: float = 0.33
const ROUND: float = 3.2          # a burst of shouting and the breath after it, seconds
const BREATH: float = 0.8         # of that, the arms come down this long
const FLING: float = 1.4          # SINKS: arms wide this long
const DROP: float = 0.7           # then this long going down
const KNEEL: float = 0.42         # how far down the body ends


## What to draw at time t: "arms" [left, right] each {"pos", "rot"}, "lean"
## (added to the body's bend, radians), "lift" (added to the body's and the
## head's height, metres).
static func at(kind: int, t: float) -> Dictionary:
	match posmod(kind, KINDS):
		POINTS:
			return _points(t)
		SINKS:
			return _sinks(t)
	return _fists(t)


## 1 while shouting, 0 in the breath between two bursts.
static func loud(t: float) -> float:
	var at_t := fposmod(t, ROUND)
	var up := smoothstep(0.0, 0.25, at_t)
	var down := 1.0 - smoothstep(ROUND - BREATH, ROUND - BREATH * 0.4, at_t)
	return minf(up, down)


static func _hang(side: float) -> Dictionary:
	return {"pos": Vector3(ARM_SIDE * side, 1.0, 0.0), "rot": Vector3(PI * 0.5, 0, 0)}


static func _mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	return {"pos": (a["pos"] as Vector3).lerp(b["pos"], k), "rot": (a["rot"] as Vector3).lerp(b["rot"], k)}


static func _fists(t: float) -> Dictionary:
	var k := loud(t)
	var arms: Array = []
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		# The two fists go up and down out of step.
		var pump := sin(t * TAU / 0.42 + (0.0 if i == 0 else PI))
		# Up and a little out and forward, so that from above they are seen as a V that shakes.
		var up := {"pos": Vector3((ARM_SIDE + 0.06) * side, 1.5 + 0.06 * pump, 0.18), "rot": Vector3(-0.95 + 0.3 * pump, 0.45 * side, 0)}
		arms.append(_mix(_hang(side), up, k))
	return {"arms": arms, "lean": 0.18 * k, "lift": 0.07 * k * absf(sin(t * TAU / 0.84))}


static func _points(t: float) -> Dictionary:
	var k := loud(t)
	# A jab: out fast, back slower.
	var beat := fposmod(t, 0.62) / 0.62
	var jab := (1.0 - smoothstep(0.18, 0.9, beat)) if beat > 0.18 else smoothstep(0.0, 0.18, beat)
	var back := {"pos": Vector3(0.3, 1.2, 0.05), "rot": Vector3(0.2, 0, 0)}
	var out := {"pos": Vector3(0.22, 1.3, 0.55), "rot": Vector3(-0.1, 0, 0)}
	var right := _mix(_hang(1.0), _mix(back, out, jab), k)
	var fist := {"pos": Vector3(-ARM_SIDE, 1.12, -0.06), "rot": Vector3(0.35, 0, 0)}
	var left := _mix(_hang(-1.0), fist, k)
	return {"arms": [left, right], "lean": k * (0.1 + 0.22 * jab), "lift": 0.0}


static func _sinks(t: float) -> Dictionary:
	# Once: it does not get up again while it protests.
	var wide := smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(FLING, FLING + DROP * 0.6, t))
	var down := smoothstep(FLING, FLING + DROP, t)
	var arms: Array = []
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var flung := {"pos": Vector3(0.55 * side, 1.32, 0.0), "rot": Vector3(-0.15, PI * 0.5 * side, 0)}
		# On the knees the fists come down on the ground in front, one after the other.
		var beat := maxf(0.0, sin((t - FLING - DROP) * TAU / 0.9 + (0.0 if i == 0 else PI)))
		var struck := {"pos": Vector3(0.22 * side, 0.95 + 0.22 * beat, 0.42), "rot": Vector3(PI * 0.5 - 0.5 - 0.5 * beat, 0, 0)}
		arms.append(_mix(_mix(_hang(side), flung, wide), struck, down))
	return {"arms": arms, "lean": -0.12 * wide + 0.5 * down, "lift": -KNEEL * down}
