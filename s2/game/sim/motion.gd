extends RefCounted
## One timed motion of a body (a shove, a swing, a fall, getting up): how long
## it is and when things in it happen. The rules clock drives it (tick); the
## picture only reads where it is (k, phase). Nothing here draws, and nothing
## in the game waits on a picture to finish.
##
## A spec is plain data, like a weapon row:
##   len     seconds from start to end at speed 1
##   hit     seconds in when the blow lands (-1: this motion lands no blow)
##   feet    Vector2(from, to): the feet are held between these seconds
##   open    seconds in from which another motion or a step may cut it short
##           (-1: it runs to its end)
##   sound   seconds in when its sound belongs (-1: none)
##   upper   true: only the upper body is taken, the legs keep walking
##   loop    true: it starts over at its end until it is stopped

const W = preload("res://game/sim/weapons.gd")

const HIT: String = "hit"
const SOUND: String = "sound"
const FEET_HELD: String = "feet_held"
const FEET_FREE: String = "feet_free"
const OPEN: String = "open"
const END: String = "end"

## The times are today's rules (field_combat.gd), written down as rows: the
## shove winds up 0.15 s, lands, and the next one comes 0.35 s after that.
const TABLE: Dictionary = {
	"shove": {"len": 0.5, "hit": 0.15, "feet": Vector2(0.0, 0.15), "open": 0.3, "sound": 0.15, "upper": true, "loop": false},
	# A dead body goes over (0.25 s in it meets the ground) and, at the end of its
	# time down, comes up again. For the rules it is down or up at once; these
	# are what is seen (dead_pose.gd).
	"dead_fall": {"len": 0.75, "hit": -1.0, "feet": Vector2(0.0, 0.75), "open": -1.0, "sound": 0.63, "upper": false, "loop": false},
	"dead_rise": {"len": 1.2, "hit": -1.0, "feet": Vector2(0.0, 1.2), "open": 0.0, "sound": -1.0, "upper": false, "loop": false},
	# A dead body comes up out of a hole: through a street manhole it hauls
	# itself up by its arms, from a culvert's mouth it crawls out and stands.
	# Until "open" only its head and arms are out. The sound is the heave.
	"dead_climb_lid": {"len": 2.4, "hit": -1.0, "feet": Vector2(0.0, 2.4), "open": 0.96, "sound": 0.96, "upper": false, "loop": false},
	"dead_climb_culvert": {"len": 1.6, "hit": -1.0, "feet": Vector2(0.0, 1.6), "open": 0.64, "sound": 0.64, "upper": false, "loop": false},
	"fall": {"len": 1.5, "hit": -1.0, "feet": Vector2(0.0, 1.5), "open": -1.0, "sound": 0.2, "upper": false, "loop": false},
	# One stomp on a body on the ground: the knee comes up for STOMP_WINDUP,
	# the boot lands, and the next can start at STOMP_TIME (field_combat.gd).
	"stomp": {"len": 1.0, "hit": 0.45, "feet": Vector2(0.0, 1.0), "open": -1.0, "sound": -1.0, "upper": false, "loop": false},
	# A jammed gun is worked at for JAM_CLEAR (field_combat.gd); the feet are free.
	"jam_clear": {"len": 2.5, "hit": -1.0, "feet": Vector2(0.0, 0.0), "open": -1.0, "sound": -1.0, "upper": true, "loop": false},
	# A crowbar in a door for PRY_TIME, a door kicked for KICK_TIME
	# (field_actions.gd). A step cuts either short (Person.go_to).
	"pry": {"len": 4.0, "hit": -1.0, "feet": Vector2(0.0, 4.0), "open": 0.0, "sound": 0.0, "upper": false, "loop": false},
	"kick": {"len": 1.0, "hit": -1.0, "feet": Vector2(0.0, 1.0), "open": 0.0, "sound": -1.0, "upper": false, "loop": false},
}

var id: String = ""
var spec: Dictionary = {}
var speed: float = 1.0
var elapsed: float = 0.0
var _fired: Dictionary = {}


static func has(motion_id: String) -> bool:
	return TABLE.has(motion_id)


static func row(motion_id: String) -> Dictionary:
	return TABLE.get(motion_id, {})


## A melee swing as a row: the weapon comes back for its windup, the blow
## lands, and the rest of the weapon's swing time is the way back (a heavier
## weapon winds up longer). Nothing cuts it.
static func swing_row(weapon_id: String) -> Dictionary:
	var d: Dictionary = W.get_data(weapon_id)
	if d.get("kind", "") != "melee":
		return {}
	var seconds: float = float(d["swing"])
	var windup: float = W.melee_windup(weapon_id)
	return {"len": seconds, "hit": windup, "feet": Vector2(0.0, 0.0), "open": -1.0, "sound": 0.0, "upper": true, "loop": false}


## Loading a gun or a bow as a row: the weapon's reload time (one shell of a
## pump gun, the whole magazine of a pistol). The feet are free.
static func reload_row(weapon_id: String) -> Dictionary:
	var d: Dictionary = W.get_data(weapon_id)
	if not W.is_ranged(weapon_id):
		return {}
	return {"len": float(d["reload"]), "hit": -1.0, "feet": Vector2(0.0, 0.0), "open": -1.0, "sound": -1.0, "upper": true, "loop": false}


## Starts a motion. speed is the body's own multiplier (a tired arm swings
## slower): 0.5 makes every time in the row take twice as long.
func start(motion_id: String, motion_spec: Dictionary, body_speed: float = 1.0) -> void:
	id = motion_id
	spec = motion_spec
	speed = maxf(0.01, body_speed)
	elapsed = 0.0
	_fired = {}


func start_known(motion_id: String, body_speed: float = 1.0) -> bool:
	if not TABLE.has(motion_id):
		return false
	start(motion_id, TABLE[motion_id], body_speed)
	return true


func active() -> bool:
	return id != ""


func length() -> float:
	return float(spec.get("len", 0.0))


## 0 at the start, 1 at the end.
func k() -> float:
	var total := length()
	if not active() or total <= 0.0:
		return 0.0
	return clampf(elapsed / total, 0.0, 1.0)


## Real seconds until it ends at the current speed.
func time_left() -> float:
	if not active():
		return 0.0
	return maxf(0.0, length() - elapsed) / speed


## "windup" until the blow lands, "recover" after it; a motion with no blow is
## "recover" all the way.
func phase() -> String:
	if not active():
		return ""
	var hit: float = float(spec.get("hit", -1.0))
	return "windup" if hit >= 0.0 and not _fired.has(HIT) else "recover"


## 0 as the windup starts, 1 as the blow lands (1 all along with no windup).
func windup_k() -> float:
	var hit: float = float(spec.get("hit", -1.0))
	if not active() or hit <= 0.0:
		return 1.0
	return clampf(elapsed / hit, 0.0, 1.0)


## 0 as the blow lands, 1 at the end.
func recover_k() -> float:
	var hit: float = maxf(0.0, float(spec.get("hit", -1.0)))
	var rest := length() - hit
	if not active() or rest <= 0.0:
		return 0.0
	return clampf((elapsed - hit) / rest, 0.0, 1.0)


func feet_held() -> bool:
	if not active():
		return false
	var feet: Vector2 = spec.get("feet", Vector2.ZERO)
	return feet.y > feet.x and elapsed >= feet.x and elapsed < feet.y


func upper_only() -> bool:
	return bool(spec.get("upper", false))


func can_cut() -> bool:
	if not active():
		return true
	var open: float = float(spec.get("open", -1.0))
	return open >= 0.0 and elapsed >= open


## Stops it now, whatever it was doing (a grab, a fall, death take the body).
func stop() -> void:
	id = ""
	spec = {}
	elapsed = 0.0
	_fired = {}


## Stops it only where the row lets it be cut short.
func cut() -> bool:
	if not active() or not can_cut():
		return false
	stop()
	return true


## Moves the motion on and returns what happened in this step, in order of
## time. Each mark fires once per run of the motion; a mark at 0 fires on the
## first tick. A step that jumps past several marks returns them all.
func tick(delta: float) -> Array[String]:
	var out: Array[String] = []
	if not active():
		return out
	elapsed += maxf(0.0, delta) * speed
	var total := length()
	var feet: Vector2 = spec.get("feet", Vector2.ZERO)
	# Marks at the same moment keep this order: held, sound, blow, freed, open.
	var marks: Array = []
	if feet.y > feet.x:
		marks.append([feet.x, FEET_HELD, 0])
	for key in [SOUND, HIT]:
		var at: float = float(spec.get(key, -1.0))
		if at >= 0.0:
			marks.append([at, key, marks.size()])
	if feet.y > feet.x:
		marks.append([feet.y, FEET_FREE, marks.size()])
	var open: float = float(spec.get(OPEN, -1.0))
	if open >= 0.0:
		marks.append([open, OPEN, marks.size()])
	marks.sort_custom(func(a, b) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[2] < b[2]))
	for m in marks:
		if elapsed >= float(m[0]) and not _fired.has(m[1]):
			_fired[m[1]] = true
			out.append(m[1])
	if elapsed >= total:
		out.append(END)
		if bool(spec.get("loop", false)) and total > 0.0:
			elapsed = fmod(elapsed, total)
			_fired = {}
		else:
			stop()
	return out
