extends RefCounted
## What a car shows for the state it is in: how many people are in it, how
## many of them move, where each one sits, who may walk to another car and
## which cars are on calling terms. It reads the rules' numbers and changes
## none of them.
##
## Head counts are s1/src/ui/home.ts figures(); the warmth and crowding steps
## are S1's (warmthTone, P.crowdFrom). The shares below are first values: the
## briefs only say that cold makes people huddle and crowding seats them on
## the floor (presentation_motion 7).

const Gesture = preload("res://game/train/train_gesture.gd")

const FIGURES_MIN: int = 2
const FIGURES_MAX: int = 16
const TAIL_SHARE: int = 3               # the tail's people are spread over three cars
const DINING_SESSION: int = 32          # the council: the brief's 30 to 40 (the web's side view draws 12)
const DINING_IDLE: int = 4
const CAPTAIN_ROOM: int = 2
const OTHER_CAR: int = 3
const WARM_FREEZING: float = 30.0
const WARM_COLD: float = 45.0
const WARM_WARM: float = 70.0
const CROWD_FROM: Array = [60.0, 80.0, 95.0]
## Of the people in a car only a few move (presentation_motion 7: two to four).
const MOVERS_ONE_IN: float = 4.0
const HUDDLE_SHARE: Dictionary = {"freezing": 0.7, "cold": 0.35, "": 0.0, "warm": 0.0}
const FLOOR_SHARE: Array = [0.0, 0.15, 0.3, 0.45]
## The mood of a car: one of four, picked from its numbers and the train's
## (2026-10-12: one mood a car, with gestures for single values laid over it
## later). It is for show only; no rule reads it. Fear quiets a car before
## unrest stirs it, and unrest shows before cold or hunger weigh it down.
const FEAR_FROZEN: float = 60.0         # first value: the council draft's frightened quiet
const TENSION_STIR: float = 60.0        # first value: from the council draft
const REL_STIR: float = -40.0           # s1 STAGES: "opposed" and below
const GRUDGE_STIR: int = 2              # the brief: set against the captain from two grudges
const LOW_BELOW: float = 45.0           # s1 reads warmth and ration under 45 as low (ui/home.ts, turn.ts)
const MOOD_NAMES: Dictionary = {"calm": "평온", "low": "가라앉음", "stir": "술렁임", "frozen": "얼어붙음"}
## What a mood changes: how many walk and how fast, how long they stand between
## walks, the share of the others who stand about in knots, whether the seated
## gather round the stove, whether heads are bowed, and the lamp. First values.
const MOOD_LOOK: Dictionary = {
	"calm": {"movers": [2, 4], "speed": 1.0, "wait": 1.0, "stand": 0.0, "gather": false, "bowed": false,
		"lamp": Color(1.0, 0.72, 0.42), "energy": 1.3, "sway": 1.0},
	"low": {"movers": [1, 2], "speed": 0.6, "wait": 1.6, "stand": 0.0, "gather": true, "bowed": false,
		"lamp": Color(0.92, 0.68, 0.46), "energy": 0.8, "sway": 1.0},
	"stir": {"movers": [3, 4], "speed": 1.4, "wait": 0.4, "stand": 0.3, "gather": false, "bowed": false,
		"lamp": Color(1.0, 0.72, 0.42), "energy": 1.3, "sway": 2.0},
	"frozen": {"movers": [0, 1], "speed": 0.7, "wait": 3.0, "stand": 0.0, "gather": false, "bowed": true,
		"lamp": Color(0.72, 0.77, 0.88), "energy": 0.6, "sway": 0.5},
}
## The gestures laid over a mood, one bad value a car (2026-10-12: tension
## first, then resentment). The first knot of those standing about takes
## them. In a car the train's tension stirs: two at each other (a quarrel in
## one car, heads together in the next) and the third looking about. In a
## car stirred by its own standing with the captain: arms folded, and one
## with its back turned. In a frightened car nobody stands about: the
## first few of those on the floor hug their knees. For show only.
const GESTURES: Dictionary = {
	"tension": {"pairs": [Gesture.ARGUE, Gesture.WHISPER], "one": Gesture.TURN_ABOUT},
	"resent": {"each": [Gesture.ARMS_CROSSED, Gesture.BACK_TURNED, Gesture.ARMS_CROSSED]},
	"fear": {"floor": [Gesture.HUG_KNEES, Gesture.HUG_KNEES, Gesture.HUG_KNEES]},
}
const GESTURE_PAIR: int = 2             # a quarrel takes two: in a tense car one stander alone keeps still
const SLOT_STRIDE: int = 4
const STOVE_STEAM_FROM: float = 0.4
## The council in the dining car (presentation_motion 3 and 7). The unrest
## score and its five steps are the brief's: tension, 10 more a community
## "opposed" or worse, 15 more a community set against the captain; up at
## 20/40/60/80 and down only 5 under. Fear from 60 hushes the room whatever
## the score, and when the vote is called everyone stops. Who gets up and who
## leans over is picked by seat number alone: no community's own numbers move
## a seat, so the room cannot give a secret vote away.
const UNREST_FROM: Array = [20.0, 40.0, 60.0, 80.0]
const UNREST_DOWN: float = 5.0
const UNREST_NAMES: Array = ["속닥", "웅성", "언쟁", "고함·야유", "개판"]
const QUIET_NAMES: Dictionary = {"vote": "표결", "hush": "무서운 조용함"}
## The room: the chair and the clerk by the table's head, two who walk, two who
## stand talking by a doorway, the rest seated on both sides of the table.
## With the seated who act that is the brief's 8 to 12 moving. First values.
const COUNCIL_ROOM: Array = [["chair", 2], ["walk", 2], ["door", 2]]
const COUNCIL_BENCH: int = 14
const COUNCIL_TABLE: int = 12
const COUNCIL_STRIDE: int = 7           # spreads the seated who act over both rows
## By step: how many of the seated act, how many of those get to their feet
## rather than lean over to a neighbour, and how long a gesture or a rest lasts.
const UNREST_LOOK: Array = [
	{"act": 4, "rise": 0, "hold": [4.0, 8.0]},
	{"act": 5, "rise": 0, "hold": [3.0, 6.0]},
	{"act": 6, "rise": 1, "hold": [3.0, 5.0]},
	{"act": 7, "rise": 3, "hold": [2.0, 4.0]},
	{"act": 8, "rise": 5, "hold": [1.5, 3.0]},
]


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


## "calm", "low", "stir" or "frozen". `comm` is {} for a car without a
## community; such a car follows the train's fear and tension only.
static func mood(comm: Dictionary, train: Dictionary) -> String:
	if float(train.get("fear", 0)) >= FEAR_FROZEN:
		return "frozen"
	if float(train.get("tension", 0)) >= TENSION_STIR:
		return "stir"
	if comm.is_empty():
		return "calm"
	if resents(comm):
		return "stir"
	if warmth(comm) < LOW_BELOW or _sit(comm, 1, 60.0) < LOW_BELOW:
		return "low"
	return "calm"


## Set against the captain, by its standing or by its grudges.
static func resents(comm: Dictionary) -> bool:
	return float(comm.get("rel", 0)) <= REL_STIR or int(comm.get("grudge", 0)) >= GRUDGE_STIR


static func mood_look(m: String) -> Dictionary:
	return MOOD_LOOK.get(m, MOOD_LOOK["calm"])


## The bad value whose gestures a car of mood `m` shows first: "fear",
## "tension", "resent" or "". Fear comes first, as it does in mood(). A car
## is stirred by the train's tension or by its own standing with the
## captain: on a tense train the tension comes first, and gesture_also()
## says whether the car's own resentment shows beside it.
static func gesture_for(m: String, train: Dictionary) -> String:
	if m == "frozen":
		return "fear"
	if m != "stir":
		return ""
	return "tension" if float(train.get("tension", 0)) >= TENSION_STIR else "resent"


## A second bad value a car shows beside the first (decision 137: one or
## two): on a tense train, a car that is also set against the captain.
static func gesture_also(value: String, comm: Dictionary) -> String:
	return "resent" if value == "tension" and not comm.is_empty() and resents(comm) else ""


## What each of a car's standers does, in knot order: [{"name", "role",
## "of"}], name "" for standing still and "of" the value the gesture is
## of. Only the first knot acts. For tension its first two are a pair (role
## 0 and 1) and its third is alone; for resentment each has a gesture of
## its own, so one stander is enough. With a second value `also`, the pair
## stays the first value's and the third takes the second's.
static func knot_gestures(value: String, standing: int, car_index: int, also: String = "") -> Array:
	var out: Array = []
	var set: Dictionary = GESTURES.get(value, {})
	var each: Array = set.get("each", [])
	var pairs: Array = set.get("pairs", [])
	var paired: bool = not pairs.is_empty() and standing >= GESTURE_PAIR
	var other: Array = (GESTURES.get(also, {}) as Dictionary).get("each", [])
	for k in standing:
		var name := ""
		var whose := value
		if k < each.size():
			name = each[k]
		elif paired and k < GESTURE_PAIR:
			name = pairs[posmod(car_index, pairs.size())]
		elif paired and k == GESTURE_PAIR and not other.is_empty():
			name = other[0]
			whose = also
		elif paired and k == GESTURE_PAIR:
			name = set["one"]
		out.append({"name": name, "role": k if k < maxi(GESTURE_PAIR, each.size()) else 0,
			"of": whose if name != "" else ""})
	return out


## What each of those a car has on its floor does, in floor order:
## [{"name", "role"}], name "" for sitting as they were. Only the first few
## act, each on a beat of its own (role).
static func floor_gestures(value: String, on_floor: int) -> Array:
	var out: Array = []
	var each: Array = (GESTURES.get(value, {}) as Dictionary).get("floor", [])
	for k in on_floor:
		var acts: bool = k < each.size()
		out.append({"name": each[k] if acts else "", "role": k if acts else 0})
	return out


static func movers(count: int, m: String = "calm") -> int:
	if count <= 0:
		return 0
	var few: Array = mood_look(m)["movers"]
	return mini(count, clampi(roundi(count / MOVERS_ONE_IN), int(few[0]), int(few[1])))


## How the people of a car split: {"walk", "stand", "bench", "floor",
## "huddled"}. walk + stand + bench + floor = count; huddled counts those of
## bench and floor who sit hunched. The mood picks who moves and who stands
## about, crowding picks the place, cold the posture.
static func split(count: int, w: float, crowd: float, m: String = "calm") -> Dictionary:
	var walk := movers(count, m)
	var still := maxi(count - walk, 0)
	var stand := roundi(still * float(mood_look(m)["stand"]))
	var seated := still - stand
	var on_floor := roundi(seated * float(FLOOR_SHARE[crowd_level(crowd)]))
	var huddled := roundi(seated * float(HUDDLE_SHARE[warmth_tone(w)]))
	return {"walk": walk, "stand": stand, "bench": seated - on_floor, "floor": on_floor, "huddled": huddled}


## One row a person, movers first: [{"pose": "walk" | "stand" | "sit" |
## "floor", "huddled": bool, "bowed": bool}]. The floor hunches first, then the
## bench from its far end. In a frightened car everyone seated bows the head.
static func seating(count: int, w: float, crowd: float, m: String = "calm") -> Array:
	var s := split(count, w, crowd, m)
	var bowed: bool = mood_look(m)["bowed"]
	var rows: Array = []
	var walk := int(s["walk"])
	var stand := int(s["stand"])
	for i in count:
		var pose := "floor"
		if i < walk:
			pose = "walk"
		elif i < walk + stand:
			pose = "stand"
		elif i < walk + stand + int(s["bench"]):
			pose = "sit"
		var seated := pose == "sit" or pose == "floor"
		rows.append({"pose": pose, "huddled": i >= count - int(s["huddled"]), "bowed": bowed and seated})
	return rows


## Which of `slots` places along the car the k-th seated person takes. Spread:
## in steps of four, so a few sit apart and nobody moves when one more comes.
## Gathered: from the middle outward, round the stove and the lamp.
static func seat_slot(k: int, slots: int, gather: bool) -> int:
	if not gather:
		return (k * SLOT_STRIDE) % slots
	var off := (k % slots + 1) / 2
	return clampi(slots / 2 + (off if k % 2 == 1 else -off), 0, slots - 1)


## How much frost the windows carry, 0 to 1: none from "cold" up, thick well
## below "freezing".
static func frost(w: float) -> float:
	return clampf((WARM_COLD - w) / WARM_FREEZING, 0.0, 1.0)


## How bright the stove burns, 0 to 1: out in a freezing car, full in a warm one.
static func stove(w: float) -> float:
	return clampf((w - WARM_FREEZING) / (WARM_WARM - WARM_FREEZING), 0.0, 1.0)


## The council's unrest score. Only what everyone can see goes in: the train's
## tension and each community's standing with the captain.
static func unrest_score(train: Dictionary, comms: Dictionary) -> float:
	var score := float(train.get("tension", 0))
	for id in comms:
		var comm: Dictionary = comms[id]
		if float(comm.get("rel", 0)) <= REL_STIR:
			score += 10.0
		if int(comm.get("grudge", 0)) >= GRUDGE_STIR:
			score += 15.0
	return score


## The step of unrest, 0 to 4. `was` is the step the room was in (-1 at first):
## it climbs at a threshold and settles only once the score is 5 under it.
static func unrest_level(score: float, was: int = -1) -> int:
	var level := 0
	for from in UNREST_FROM:
		level += 1 if score >= float(from) else 0
	while level < mini(was, UNREST_FROM.size()) and score >= float(UNREST_FROM[level]) - UNREST_DOWN:
		level += 1
	return level


## "vote" while the vote is called, "hush" in a frightened room, "" otherwise.
static func council_quiet(train: Dictionary) -> String:
	if bool(train.get("voting", false)):
		return "vote"
	return "hush" if float(train.get("fear", 0)) >= FEAR_FROZEN else ""


## One place a person: "chair", "walk", "door", "bench" or "table". The same
## for every step of unrest, so nobody changes seats when the room heats up.
## Seats fill the two sides of the table in turn; beyond them people stand.
static func council_places(count: int) -> Array:
	var rows: Array = []
	for group in COUNCIL_ROOM:
		for i in int(group[1]):
			if rows.size() < count:
				rows.append(String(group[0]))
	var bench := 0
	var table := 0
	while rows.size() < count:
		if bench < COUNCIL_BENCH and (bench <= table or table >= COUNCIL_TABLE):
			rows.append("bench")
			bench += 1
		elif table < COUNCIL_TABLE:
			rows.append("table")
			table += 1
		else:
			rows.append("door")
	return rows


## What the seated person number `seat` (of `seats`) does at a step of unrest:
## "rise", "lean" or "" for sitting still. Someone who acts at one step acts at
## every higher one.
static func council_role(seat: int, seats: int, level: int) -> String:
	if seat < 0 or seats <= 0:
		return ""
	var look: Dictionary = UNREST_LOOK[clampi(level, 0, UNREST_LOOK.size() - 1)]
	# A stride that shares no factor with the seats gives every seat its own rank.
	var stride := COUNCIL_STRIDE
	while seats > 1 and _gcd(stride, seats) != 1:
		stride += 1
	var rank := (seat * stride) % seats
	if rank < int(look["rise"]):
		return "rise"
	return "lean" if rank < int(look["act"]) else ""


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


## How far apart two communities stand on S1's three axes (IDEO), summed.
static func ideo_gap(a: Array, b: Array) -> float:
	var gap := 0.0
	for i in mini(a.size(), b.size()):
		gap += absf(float(a[i]) - float(b[i]))
	return gap


## The communities this one is on calling terms with. S1 keeps no number for
## how two communities get on, so for now it is those that stand within
## `within` of it on the three axes (2026-10-12: a first reading, for show only).
static func friends(comm_id: String, ideo: Dictionary, within: float) -> Array:
	var rows: Array = []
	if not ideo.has(comm_id):
		return rows
	for other in ideo:
		if String(other) != comm_id and ideo_gap(ideo[comm_id], ideo[other]) <= within:
			rows.append(String(other))
	rows.sort()
	return rows


## The cars this car's people may call at, by id: the cars of the communities
## it is on calling terms with. A car without a community calls nowhere.
static func calls_for(car: Dictionary, cars: Array, ideo: Dictionary, within: float) -> Array:
	var rows: Array = []
	if not car.has("comm"):
		return rows
	var near := friends(String(car["comm"]), ideo, within)
	for other in cars:
		if other.has("comm") and near.has(String(other["comm"])):
			rows.append(String(other["id"]))
	return rows


## Nobody goes calling in a frightened car or during the session.
static func calls_open(m: String, phase: String) -> bool:
	return m != "frozen" and phase != "council"


static func _gcd(a: int, b: int) -> int:
	return a if b == 0 else _gcd(b, a % b)


static func _sit(comm: Dictionary, i: int, fallback: float) -> float:
	var sit = comm.get("sit")
	return float(sit[i]) if sit is Array and sit.size() > i else fallback
