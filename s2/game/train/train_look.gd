extends RefCounted
## What a car shows for the state it is in: how many people are in it, how
## many of them move, where each one sits and who may walk to another car. It
## reads the rules' numbers and changes none of them.
##
## Head counts are s1/src/ui/home.ts figures(); the warmth and crowding steps
## are S1's (warmthTone, P.crowdFrom). The shares below are first values: the
## briefs only say that cold makes people huddle and crowding seats them on
## the floor (presentation_motion 7).

const FIGURES_MIN: int = 2
const FIGURES_MAX: int = 16
const TAIL_SHARE: int = 3               # the tail's people are spread over three cars
const DINING_SESSION: int = 12
const DINING_IDLE: int = 4
const CAPTAIN_ROOM: int = 2
const OTHER_CAR: int = 3
const WARM_FREEZING: float = 30.0
const WARM_COLD: float = 45.0
const WARM_WARM: float = 70.0
const CROWD_FROM: Array = [60.0, 80.0, 95.0]
## Of the people in a car only a few move (presentation_motion 7: two to four).
const MOVERS_MIN: int = 2
const MOVERS_MAX: int = 4
const MOVERS_ONE_IN: float = 4.0
const HUDDLE_SHARE: Dictionary = {"freezing": 0.7, "cold": 0.35, "": 0.0, "warm": 0.0}
const FLOOR_SHARE: Array = [0.0, 0.15, 0.3, 0.45]


## People standing in this car. `comm` is the car's community ({} for a car
## without one), `phase` the train's.
static func figures(car: Dictionary, comm: Dictionary, phase: String) -> int:
	if car.has("comm") and not comm.is_empty():
		var tail := String(car["comm"]) == "tail"
		var per_car: float = float(comm.get("pop", 0)) / (TAIL_SHARE if tail else 1)
		var n := clampi(roundi(per_car * (0.25 + crowding(comm) / 250.0)), FIGURES_MIN, FIGURES_MAX)
		var away := int(comm.get("away", 0))
		# People out on a job leave their own car; the tail's leave from its first car.
		if away > 0 and (not tail or String(car.get("id", "")) == "tail1"):
			n = maxi(1, n - away)
		return n
	match String(car.get("kind", "")):
		"dining":
			return DINING_SESSION if phase == "council" else DINING_IDLE
		"captain":
			return CAPTAIN_ROOM
		"loco", "freight", "cold":
			return 0
	return OTHER_CAR


static func warmth(comm: Dictionary) -> float:
	return _sit(comm, 0, 60.0)


static func crowding(comm: Dictionary) -> float:
	return _sit(comm, 2, 0.0)


## "freezing", "cold", "" or "warm".
static func warmth_tone(w: float) -> String:
	if w < WARM_FREEZING:
		return "freezing"
	if w < WARM_COLD:
		return "cold"
	if w > WARM_WARM:
		return "warm"
	return ""


## 0 roomy, 1 full, 2 cramped, 3 sleeping in layers (s1 crowd.ts).
static func crowd_level(crowd: float) -> int:
	if crowd >= float(CROWD_FROM[2]):
		return 3
	if crowd >= float(CROWD_FROM[1]):
		return 2
	return 1 if crowd >= float(CROWD_FROM[0]) else 0


static func movers(count: int) -> int:
	if count <= 0:
		return 0
	return mini(count, clampi(roundi(count / MOVERS_ONE_IN), MOVERS_MIN, MOVERS_MAX))


## How the people of a car split: {"walk", "bench", "floor", "huddled"}.
## walk + bench + floor = count; huddled counts those of bench and floor who
## sit hunched. Crowding picks the place, cold the posture, so a colder car
## moves nobody and a fuller one hunches nobody.
static func split(count: int, w: float, crowd: float) -> Dictionary:
	var walk := movers(count)
	var seated := maxi(count - walk, 0)
	var on_floor := roundi(seated * float(FLOOR_SHARE[crowd_level(crowd)]))
	var huddled := roundi(seated * float(HUDDLE_SHARE[warmth_tone(w)]))
	return {"walk": walk, "bench": seated - on_floor, "floor": on_floor, "huddled": huddled}


## One row a person, movers first: [{"pose": "walk" | "sit" | "floor",
## "huddled": bool}]. The floor hunches first, then the bench from its far end.
static func seating(count: int, w: float, crowd: float) -> Array:
	var s := split(count, w, crowd)
	var rows: Array = []
	for i in count:
		var pose := "walk" if i < int(s["walk"]) else ("sit" if i < int(s["walk"]) + int(s["bench"]) else "floor")
		rows.append({"pose": pose, "huddled": i >= count - int(s["huddled"])})
	return rows


## The trips this car's people may take now: only ones with a use (a meal, the
## infirmary, the session), never to their own car. A car without a community
## sends nobody.
static func errands_for(car: Dictionary, phase: String, errands: Array) -> Array:
	var rows: Array = []
	if not car.has("comm"):
		return rows
	for e in errands:
		if String(e.get("to", "")) == String(car.get("id", "")):
			continue
		var only := String(e.get("phase", ""))
		if only == "" or only == phase:
			rows.append(e)
	return rows


static func _sit(comm: Dictionary, i: int, fallback: float) -> float:
	var sit = comm.get("sit")
	return float(sit[i]) if sit is Array and sit.size() > i else fallback
