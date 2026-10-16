extends RefCounted
## What people inside the train do with their bodies when a value is bad:
## five on their feet for tension and resentment, then five more for fear,
## hunger and cold (see MORE below). Gestures only, no words. Each is read off
## one clock and gives where the trunk, the head and two arms sit on top of a
## pose of train_body.gd (base_of says which; the first five stand); it
## decides nothing and moves nobody along the car. Forward is +z.
##
## at(name, t, role) gives:
##   "turn"  radians about y added to the body's own facing
##   "lean"  radians forward (+) or back (-)
##   "sway"  radians to its right (+) or left (-)
##   "lift"  metres up
##   "head"  metres the head is moved from where the pose puts it
##   "arms"  [left, right], each {"pos", "rot"} of a box ARM_SIZE whose long side is z
## A pair (ARGUE, WHISPER) is two people standing PAIR_GAP apart along x: role 0
## is the one on the left (smaller x), role 1 the one on the right. Give both the
## same t. The scene faces nobody: "turn" does it.

const Body = preload("res://game/train/train_body.gd")
const Rest = preload("res://game/train/train_gesture_rest.gd")
const Riot = preload("res://game/train/train_gesture_riot.gd")

const ARGUE: String = "argue"            # two at a door, one at a time at the other's face
const WHISPER: String = "whisper"        # two with their heads together, a look over the shoulder now and then
const TURN_ABOUT: String = "turn_about"  # stands, turns to look the other way, turns back
const ARMS_CROSSED: String = "arms_crossed"
const BACK_TURNED: String = "back_turned"  # its back to the car, a look over the shoulder now and then
const NAMES: Array[String] = [ARGUE, WHISPER, TURN_ABOUT, ARMS_CROSSED, BACK_TURNED]

const ARM_SIZE: Vector3 = Vector3(0.1, 0.1, 0.5)
const ARM_SIDE: float = 0.33
const PAIR_GAP: Dictionary = {ARGUE: 0.95, WHISPER: 0.78}
const SAY: float = 2.6            # ARGUE: one has the word this long, then the other
const GLANCE_EVERY: float = 5.5   # WHISPER, BACK_TURNED: seconds between two looks round
const GLANCE: float = 0.9         # and how long one lasts
const ABOUT_ROUND: float = 6.0    # TURN_ABOUT: one look the other way and back, with the standing between
const ABOUT_TURN: float = 0.7     # of that, each turning
const ABOUT_HOLD: float = 1.8     # and the looking


## A name is ready only when its stand-in clip exists, not because the contract lists it.
static func knows(name: String) -> bool:
	return name in NAMES or name in MORE or Rest.knows(name) or Riot.knows(name)


static func spec(name: String) -> Dictionary:
	if Rest.knows(name):
		return Rest.spec(name)
	if Riot.knows(name):
		return Riot.spec(name)
	return {}


static func at(name: String, t: float, role: int = 0) -> Dictionary:
	var row: Dictionary = spec(name)
	if not row.is_empty():
		if row["kind"] == "three":
			var enter: float = row["length"]["enter"]
			return phase_at(name, "enter", maxf(t, 0.0), role) if t < enter else phase_at(name, "loop", t - enter, role)
		return phase_at(name, "once", t, role)
	match name:
		ARGUE:
			return _argue(t, role)
		WHISPER:
			return _whisper(t, role)
		TURN_ABOUT:
			return _turn_about(t, role)
		ARMS_CROSSED:
			return _arms_crossed(t, role)
		BACK_TURNED:
			return _back_turned(t, role)
	if name in MORE:
		return more(name, t, role)
	return _still()


static func hang(side: float) -> Dictionary:
	return {"pos": Vector3(ARM_SIDE * side, 1.0, 0.0), "rot": Vector3(PI * 0.5, 0, 0)}


static func _still() -> Dictionary:
	return {"turn": 0.0, "lean": 0.0, "sway": 0.0, "lift": 0.0, "head": Vector3.ZERO, "arms": [hang(-1.0), hang(1.0)]}


static func _mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	return {"pos": (a["pos"] as Vector3).lerp(b["pos"], k), "rot": (a["rot"] as Vector3).lerp(b["rot"], k)}


## The two forearms laid one over the other on the chest.
static func _folded() -> Array:
	return [
		{"pos": Vector3(0.06, 1.1, 0.27), "rot": Vector3(0.0, PI * 0.5 - 0.15, 0)},
		{"pos": Vector3(-0.06, 1.02, 0.3), "rot": Vector3(0.0, -PI * 0.5 + 0.15, 0)},
	]


## 1 while it is this one's turn to speak, easing in and out; the two never both speak.
static func speaking(t: float, role: int) -> float:
	var at_t := fposmod(t - SAY * float(role), SAY * 2.0)
	return smoothstep(0.0, 0.3, at_t) * (1.0 - smoothstep(SAY - 0.3, SAY, at_t))


static func _argue(t: float, role: int) -> Dictionary:
	var d := _still()
	# They face each other along the car.
	d["turn"] = PI * 0.5 if role == 0 else -PI * 0.5
	var mine := speaking(t, role)
	var theirs := speaking(t, 1 - role)
	# The one speaking comes forward and chops the air with one hand; the other
	# goes back on the heels with both hands half up, and shakes its head.
	var chop := 0.5 + 0.5 * sin(t * TAU / 0.55 + float(role))
	var hand := 1.0 if role == 0 else -1.0     # the arm on the side the car is looked at from
	var out := {"pos": Vector3(0.2 * hand, 1.22 - 0.16 * chop, 0.42), "rot": Vector3(-0.35 + 0.7 * chop, 0, 0)}
	var up := {"pos": Vector3(0.0, 1.12, 0.26), "rot": Vector3(-0.9, 0, 0)}
	var arms: Array = []
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var arm := hang(side)
		var held := {"pos": Vector3(0.24 * side, 1.12, 0.26), "rot": Vector3(-0.9, 0.3 * side, 0)}
		arm = _mix(arm, held, theirs * 0.9)
		if side == hand:
			arm = _mix(arm, out, mine)
		arms.append(arm)
	d["arms"] = arms
	d["lean"] = 0.22 * mine - 0.1 * theirs
	d["head"] = Vector3(0.05 * theirs * sin(t * TAU / 0.5), 0.0, 0.05 * mine)
	d["lift"] = 0.02 * mine * chop
	return d


## 1 during a look round, 0 otherwise. The two of a pair do not look at once.
static func glancing(t: float, role: int) -> float:
	var at_t := fposmod(t - GLANCE_EVERY * 0.5 * float(role) - 1.5, GLANCE_EVERY)
	return smoothstep(0.0, 0.25, at_t) * (1.0 - smoothstep(GLANCE - 0.25, GLANCE, at_t))


static func _whisper(t: float, role: int) -> Dictionary:
	var d := _still()
	var toward := 1.0 if role == 0 else -1.0    # where the other one is, along x
	var look := glancing(t, role)
	# Side by side facing out of the car, tipped toward each other until the heads nearly touch.
	d["sway"] = 0.13 * toward * (1.0 - look)
	d["lean"] = 0.12 * (1.0 - look)
	d["head"] = Vector3(0.09 * toward * (1.0 - look), -0.04 * (1.0 - look) + 0.01 * sin(t * 1.3 + float(role)), 0.03)
	# The look round is away from the other, over the outer shoulder.
	d["turn"] = -0.9 * toward * look
	# The hand next to the other goes up by the mouth.
	var arms: Array = [hang(-1.0), hang(1.0)]
	var i := 1 if role == 0 else 0
	var cover := {"pos": Vector3(0.2 * toward, 1.38, 0.2), "rot": Vector3(-1.1, -0.5 * toward, 0)}
	arms[i] = _mix(arms[i], cover, (1.0 - look) * (0.75 + 0.25 * sin(t * 0.9 + float(role) * 2.0)))
	d["arms"] = arms
	return d


## How far round it is, 0 as it stood and 1 looking the other way.
static func about(t: float, role: int = 0) -> float:
	var at_t := fposmod(t + 1.7 * float(role), ABOUT_ROUND)
	var there := smoothstep(0.0, ABOUT_TURN, at_t)
	var back := smoothstep(ABOUT_TURN + ABOUT_HOLD, ABOUT_TURN * 2.0 + ABOUT_HOLD, at_t)
	return there - back


static func _turn_about(t: float, role: int) -> Dictionary:
	var d := _still()
	var k := about(t, role)
	var way := 1.0 if role % 2 == 0 else -1.0
	d["turn"] = PI * 0.5 * way * k
	# The head goes first and comes back last: while the body is still turning it is ahead of it.
	var moving := 4.0 * k * (1.0 - k)
	d["head"] = Vector3(0.07 * way * moving, 0.0, 0.03 * k)
	d["lean"] = 0.08 * k
	d["sway"] = 0.05 * way * moving
	# The weight goes from one foot to the other as it stands.
	d["lift"] = 0.012 * sin(t * 2.1 + float(role))
	return d


static func _arms_crossed(t: float, role: int) -> Dictionary:
	var d := _still()
	d["arms"] = _folded()
	d["lean"] = -0.07
	# It shifts its weight slowly, and the chin comes up.
	d["sway"] = 0.04 * sin(t * 0.7 + float(role) * 1.9)
	d["head"] = Vector3(0.0, 0.015, -0.02)
	return d


static func _back_turned(t: float, role: int) -> Dictionary:
	var d := _still()
	var look := glancing(t, role)
	var way := 1.0 if role % 2 == 0 else -1.0
	d["turn"] = PI - 0.7 * way * look
	# Shoulders up, head down between them; the elbows show past the sides.
	d["lean"] = 0.12
	d["head"] = Vector3(0.0, -0.08 * (1.0 - look), 0.05)
	d["arms"] = [
		{"pos": Vector3(0.12, 1.1, 0.24), "rot": Vector3(0.0, PI * 0.5 - 0.3, 0)},
		{"pos": Vector3(-0.12, 1.02, 0.26), "rot": Vector3(0.0, -PI * 0.5 + 0.3, 0)},
	]
	d["sway"] = 0.03 * sin(t * 0.6 + float(role))
	return d


# ---------------------------------------------------------------- the next five
## Fear, hunger and cold. These are not all on their feet, so each also says
## which pose it sits on: "base" (train_body.gd's pose name) and "huddled".
## DRAG_WALK also gives "pace", what the walking speed is multiplied by, and
## BOWL_SIT gives "prop": where the bowl is held ({"name", "pos"}).

const HUG_KNEES: String = "hug_knees"    # on the floor, arms round the knees, rocking a little
const SLUMP: String = "slump"            # on the floor, fallen back against the wall, hands lying open
const DRAG_WALK: String = "drag_walk"    # a walk with nothing in it: bent, arms dead, feet not lifted
const BOWL_SIT: String = "bowl_sit"      # on the bench, an empty bowl held in the lap and looked into
const RUB_STAMP: String = "rub_stamp"    # standing, hands rubbed and blown into, feet stamped
const MORE: Array[String] = [HUG_KNEES, SLUMP, DRAG_WALK, BOWL_SIT, RUB_STAMP]
const DRAG_PACE: float = 0.55
const BLOW_EVERY: float = 4.6     # RUB_STAMP: seconds between two breaths into the hands
const BLOW: float = 1.1


## The pose a gesture sits on: {"base", "huddled"}. The first five stand.
static func base_of(name: String) -> Dictionary:
	var row: Dictionary = spec(name)
	if not row.is_empty():
		return {"base": row["base"], "huddled": false}
	match name:
		HUG_KNEES:
			return {"base": "floor", "huddled": true}
		SLUMP:
			return {"base": "floor", "huddled": false}
		DRAG_WALK:
			return {"base": "walk", "huddled": false}
		BOWL_SIT:
			return {"base": "sit", "huddled": false}
	return {"base": "stand", "huddled": false}


static func more(name: String, t: float, role: int = 0) -> Dictionary:
	var d := _still()
	var off := float(role) * 1.7
	match name:
		HUG_KNEES:
			# The knees are not drawn: the forearms lie across where they would be.
			var rock := sin(t * 1.5 + off)
			d["arms"] = [
				{"pos": Vector3(0.05, 0.46, 0.36), "rot": Vector3(0.0, PI * 0.5 - 0.2, 0)},
				{"pos": Vector3(-0.05, 0.38, 0.38), "rot": Vector3(0.0, -PI * 0.5 + 0.2, 0)},
			]
			d["lean"] = 0.05 * rock
			d["head"] = Vector3(0.0, -0.03 + 0.01 * rock, 0.04)
		SLUMP:
			var breath := sin(t * 0.9 + off)
			d["lean"] = -0.32
			d["sway"] = 0.1 if role % 2 == 0 else -0.1
			d["head"] = Vector3(0.05 if role % 2 == 0 else -0.05, -0.06 + 0.008 * breath, -0.06)
			d["arms"] = [
				{"pos": Vector3(-0.34, 0.1, 0.22), "rot": Vector3(0.1, 0.25, 0)},
				{"pos": Vector3(0.34, 0.1, 0.22), "rot": Vector3(0.1, -0.25, 0)},
			]
		DRAG_WALK:
			# One foot is put down, the other dragged up to it: the dip comes once a step, not twice.
			var step := fposmod(t * 1.1 + off, 1.0)
			d["lean"] = 0.2
			d["sway"] = 0.05 * sin(step * TAU)
			d["lift"] = -0.02 - 0.025 * smoothstep(0.0, 0.3, step) * (1.0 - smoothstep(0.3, 0.8, step))
			d["head"] = Vector3(0.0, -0.07, 0.06)
			d["arms"] = [
				{"pos": Vector3(-ARM_SIDE, 0.96, 0.05), "rot": Vector3(PI * 0.5 - 0.1, 0, 0)},
				{"pos": Vector3(ARM_SIDE, 0.96, 0.05), "rot": Vector3(PI * 0.5 - 0.1, 0, 0)},
			]
			d["pace"] = DRAG_PACE
		BOWL_SIT:
			# Looking into it; now and then the head comes up and goes down again.
			var up := glancing(t, role)
			var bowl := Vector3(0.0, 0.78, 0.4)
			d["arms"] = [
				{"pos": Vector3(-0.16, 0.86, 0.24), "rot": Vector3(0.35, 0.35, 0)},
				{"pos": Vector3(0.16, 0.86, 0.24), "rot": Vector3(0.35, -0.35, 0)},
			]
			d["lean"] = 0.18 * (1.0 - up)
			d["head"] = Vector3(0.0, -0.05 * (1.0 - up), 0.05 * (1.0 - up))
			d["prop"] = {"name": "bowl", "pos": bowl}
		RUB_STAMP:
			var at_t := fposmod(t + off, BLOW_EVERY)
			var blow := smoothstep(0.0, 0.3, at_t) * (1.0 - smoothstep(BLOW - 0.3, BLOW, at_t))
			var rub := sin(t * TAU / 0.35) * (1.0 - blow)
			var hands := Vector3(0.0, lerpf(1.12, 1.42, blow), lerpf(0.3, 0.24, blow))
			d["arms"] = [
				{"pos": hands + Vector3(-0.1, 0.03 * rub, 0.03 * rub), "rot": Vector3(-0.5 - 0.5 * blow, 0.6, 0)},
				{"pos": hands + Vector3(0.1, -0.03 * rub, -0.03 * rub), "rot": Vector3(-0.5 - 0.5 * blow, -0.6, 0)},
			]
			# Feet: one, then the other, twice a second.
			var foot := sin(t * TAU / 0.5 + off)
			d["lift"] = 0.03 * absf(foot)
			d["sway"] = 0.05 * foot
			d["lean"] = 0.1 + 0.06 * blow
			d["head"] = Vector3(0.0, -0.03 - 0.03 * blow, 0.03 + 0.03 * blow)
	return d


## First-value (가안) pose keys, with the current rig's bone names and local
## seconds. No bone angles are assumed before the real body's rest is checked.
static func keyframes(name: String, part: String, role: int = 0) -> Array:
	var row: Dictionary = spec(name)
	if row.is_empty() or not row["stages"].has(part):
		return []
	var stage: Dictionary = row["stages"][part]
	var visuals: Array = stage["visual"]
	var times: Dictionary = stage.get("times", {})
	var tracks: Dictionary = stage.get("bones_b", stage["bones"]) if role == 1 else stage["bones"]
	var length: float = float(row["length"][part])
	var out: Array = []
	for i in visuals.size():
		var seconds: float = float(times.get(i, length * float(i) / float(visuals.size() - 1)))
		var bones: Dictionary = {}
		for bone in tracks:
			bones[bone] = tracks[bone][i]
		out.append({"time": seconds, "visual": visuals[i], "bones": bones})
	return out


## Local time in one segment: three-part names use enter, loop or exit;
## one-off names use once. Their visual contacts do not execute game events.
static func phase_at(name: String, part: String, t: float, role: int = 0, confirmed: bool = false, from_pose: String = "sit") -> Dictionary:
	var row: Dictionary = spec(name)
	var frames: Array = keyframes(name, part, role)
	if row.is_empty() or frames.is_empty():
		return _still()
	var duration: float = float(row["length"][part])
	var seconds: float = fposmod(maxf(t, 0.0), duration) if part == "loop" and duration > 0.0 else clampf(t, 0.0, duration)
	for i in range(frames.size() - 1):
		var first: float = float(frames[i]["time"])
		var last: float = float(frames[i + 1]["time"])
		if seconds <= last:
			var k: float = smoothstep(first, last, seconds)
			return _blend_new(
				_visual(name, String(frames[i]["visual"]), role, confirmed, from_pose),
				_visual(name, String(frames[i + 1]["visual"]), role, confirmed, from_pose), k)
	return _visual(name, String(frames.back()["visual"]), role, confirmed, from_pose)


## The keyed visual words have a single stand-in reading. Real arm and leg
## joints use keyframes() later; these capsules and arm boxes have none.
static func _visual(name: String, visual: String, role: int, confirmed: bool, from_pose: String) -> Dictionary:
	var d: Dictionary = _still()
	var row: Dictionary = spec(name)
	var low: String = "sit" if name in ["sit_bench", "lie_bunk", "sleep_lean_wall", "spring_up"] else "floor"
	if name == "spring_up" and from_pose == "floor":
		low = "floor"
	var ground: Dictionary = Body.pose_at("stand", false)
	var down: Dictionary = Body.pose_at(low, false)
	var pose: Dictionary = ground
	var base: String = "stand"
	match visual:
		"lower", "drop", "heave":
			pose = {"body_pos": (ground["body_pos"] as Vector3).lerp(down["body_pos"], 0.5),
				"body_scale": (ground["body_scale"] as Vector3).lerp(down["body_scale"], 0.5),
				"head_pos": (ground["head_pos"] as Vector3).lerp(down["head_pos"], 0.5)}
			base = low
		"bend_offer", "hand_grip", "pull_up":
			# Helping up: only B, who starts on the floor, is low; pull_up is B halfway.
			if role == 1:
				var k: float = 0.5 if visual == "pull_up" else 1.0
				pose = {"body_pos": (ground["body_pos"] as Vector3).lerp(down["body_pos"], k),
					"body_scale": (ground["body_scale"] as Vector3).lerp(down["body_scale"], k),
					"head_pos": (ground["head_pos"] as Vector3).lerp(down["head_pos"], k)}
				base = low
		"seat", "seat_breathe", "spring_brace", "bunk", "bunk_turn", "bunk_breathe":
			pose = down
			base = low
		"floor", "floor_breathe", "floor_brace", "kneel", "kneel_breathe", "crouch", "crouch_warm", "crouch_warm_roll", "floor_land", "floor_prop", "crouch_grip":
			pose = Body.pose_at("floor", false)
			base = "floor"
		"wall", "wall_nod":
			pose = down
			base = low
	d["pose"] = base
	d["body_pos"] = pose["body_pos"]
	d["body_scale"] = pose["body_scale"]
	d["head_pos"] = pose["head_pos"]
	d["upper"] = bool(row.get("upper", false))
	d["held"] = row.get("prop", {})

	var arms: Array = [hang(-1.0), hang(1.0)]
	match visual:
		"seat", "seat_breathe", "spring_brace", "lower":
			arms = _hands_at(Body.SEAT_HEIGHT + Body.RADIUS, ARM_SIDE)
		"floor", "floor_breathe", "kneel", "kneel_breathe", "wall", "wall_nod", "crouch":
			arms = _hands_at(Body.SEAT_HEIGHT, ARM_SIDE)
		"floor_brace":
			arms = _hands_at(Body.SEAT_HEIGHT, ARM_SIDE)
			arms[1] = {"pos": Vector3(ARM_SIDE, Body.RADIUS, ARM_SIDE), "rot": Vector3(PI * 0.5, 0, 0)}
		"bunk", "bunk_breathe", "bunk_turn":
			arms = _hands_at(Body.SEAT_HEIGHT, ARM_SIDE)
		"crouch_warm", "crouch_warm_roll":
			arms = _hands_at(Body.SEAT_HEIGHT + Body.RADIUS, ARM_SIZE.z)
		"stand_warm", "stand_warm_roll":
			arms = _hands_at(1.12, ARM_SIZE.z)
		"fist", "fist_pump":
			arms[1] = {"pos": Vector3(ARM_SIDE, 1.5, ARM_SIZE.z), "rot": Vector3(-PI * 0.5, 0, 0)}
		"shove_ready", "shove_recover", "shove_contact":
			arms = _hands_at(1.12, ARM_SIZE.z if visual == "shove_contact" and role == 0 else ARM_SIDE)
		"bang_ready", "bang_up", "bang_contact":
			var height: float = 1.42 if visual == "bang_up" else (1.0 if visual == "bang_contact" else 1.12)
			arms[1] = {"pos": Vector3(ARM_SIDE, height, ARM_SIZE.z), "rot": Vector3(-PI * 0.5, 0, 0)}
		"stomp_lift", "stomp_contact":
			arms = _hands_at(1.12, ARM_SIDE)
	d["arms"] = arms

	match visual:
		"seat_breathe", "floor_breathe", "kneel_breathe", "bunk_breathe":
			d["head"] = Vector3(0, Body.BOB, 0)
		"bunk", "bunk_breathe", "bunk_turn":
			var turn: float = 0.5 if visual == "bunk_turn" else 1.0
			d["lean"] = -PI * 0.5 * turn
			d["turn"] = PI * 0.5 * turn
			d["head_pos"] = (pose["head_pos"] as Vector3).lerp(
				Vector3(0, Body.SEAT_HEIGHT + Body.HEAD_RADIUS, Body.HEIGHT * Body.SEATED_SCALE), turn)
		"wall", "wall_nod":
			d["lean"] = -Body.SIDE_LEAN
			d["head"] = Vector3(0, -Body.BOW_DROP if visual == "wall_nod" else 0.0, 0)
		"crouch", "crouch_warm", "crouch_warm_roll":
			d["lean"] = Body.HUDDLE_LEAN
		"stand_warm", "stand_warm_roll":
			d["lean"] = Body.SIDE_LEAN
			d["head"] = Vector3(0, -Body.BOB, Body.RADIUS)
		"fist_pump":
			d["lift"] = Body.BOB
		"shove_ready":
			d["lean"] = -Body.SIDE_LEAN if role == 0 else Body.SIDE_LEAN
		"shove_contact":
			d["lean"] = Body.SIDE_LEAN if role == 0 else (-Body.SIDE_LEAN if confirmed else Body.SIDE_LEAN)
		"shove_recover":
			d["lean"] = -Body.SIDE_LEAN if role == 1 and confirmed else 0.0
		"bang_contact":
			d["lean"] = Body.SIDE_LEAN
		"spring_brace":
			d["lean"] = Body.HUDDLE_LEAN
		"spring_rise":
			d["lift"] = Body.BOB
		"stomp_lift":
			d["lift"] = Body.BOB
			d["sway"] = Body.SIDE_LEAN
		"stomp_contact":
			d["sway"] = -Body.SIDE_LEAN
	if visual == "crouch_warm_roll" or visual == "stand_warm_roll":
		for i in 2:
			arms[i]["rot"] = Vector3(PI * 0.5, PI * 0.5 if i == 0 else -PI * 0.5, 0)
	_unrest_more(d, visual, role, confirmed)
	return d


## Stand-in reading of the twelve later unrest rows: arm boxes and trunk tilt
## only. B's reactions to a grab or a swing show only when confirmed. (가안)
static func _unrest_more(d: Dictionary, visual: String, role: int, confirmed: bool) -> void:
	var arms: Array = d["arms"]
	var reach: float = ARM_SIZE.z
	var up := Vector3(-PI * 0.5, 0, 0)
	var ahead := Vector3.ZERO
	match visual:
		"reach":
			d["arms"] = _hands_at(1.2, reach if role == 0 else ARM_SIDE)
			d["lean"] = Body.SIDE_LEAN * 0.5 if role == 0 else 0.0
		"collar_grip", "collar_pull":
			d["arms"] = _hands_at(1.3, reach)
			var pull: float = 1.0 if visual == "collar_grip" else -1.0
			if role == 0:
				d["lean"] = Body.SIDE_LEAN * pull
			elif confirmed:
				d["lean"] = -Body.SIDE_LEAN * 0.5 * pull
		"wind_up", "punch_contact", "punch_follow":
			if role == 0:
				var depth: float = -0.1 if visual == "wind_up" else (reach + 0.2 if visual == "punch_contact" else ARM_SIDE)
				arms[1] = {"pos": Vector3(ARM_SIDE, 1.35 if visual != "punch_follow" else 1.2, depth),
					"rot": ahead if visual == "punch_contact" else up}
				arms[0] = {"pos": Vector3(-ARM_SIDE, 1.3, ARM_SIDE), "rot": up}
				d["turn"] = -0.3 if visual == "wind_up" else (0.2 if visual == "punch_contact" else 0.0)
				d["lean"] = Body.SIDE_LEAN if visual == "punch_contact" else 0.0
			else:
				d["arms"] = _hands_at(1.3, ARM_SIDE)
				if confirmed and visual == "punch_contact":
					d["turn"] = 0.4
					d["head"] = Vector3(Body.SIDE_HEAD, 0, 0)
				elif confirmed and visual == "punch_follow":
					d["lean"] = -Body.SIDE_LEAN
		"stagger":
			for i in 2:
				var side: float = -1.0 if i == 0 else 1.0
				arms[i] = {"pos": Vector3(side * (ARM_SIDE + 0.12), 1.15, -0.05), "rot": Vector3(PI * 0.5, 0, side * 0.6)}
			d["lean"] = -Body.SIDE_LEAN
			d["sway"] = Body.SIDE_LEAN * 0.5
		"drop":
			d["arms"] = _hands_at(Body.RADIUS + 0.2, -0.1)
			d["lean"] = -Body.SIDE_LEAN
		"floor_land", "floor_prop":
			# Sitting on the floor, hands planted behind: never lying flat.
			d["arms"] = _hands_at(Body.RADIUS, -ARM_SIDE)
			d["lean"] = -Body.SIDE_LEAN if visual == "floor_land" else -Body.SIDE_LEAN * 0.5
			if visual == "floor_land":
				d["head"] = Vector3(0, -Body.BOB, 0)
		"bend_offer", "hand_grip":
			if role == 0:
				arms[1] = {"pos": Vector3(ARM_SIDE, 0.9, reach), "rot": ahead}
				d["lean"] = Body.HUDDLE_LEAN * 0.5
			else:
				arms[1] = {"pos": Vector3(ARM_SIDE, 0.8, ARM_SIDE), "rot": ahead}
		"pull_up":
			arms[1] = {"pos": Vector3(ARM_SIDE, 1.0, ARM_SIDE), "rot": ahead}
			if role == 0:
				d["lean"] = -Body.SIDE_LEAN * 0.5
		"throw_cock":
			arms[1] = {"pos": Vector3(ARM_SIDE, 1.55, -0.15), "rot": up}
			arms[0] = {"pos": Vector3(-ARM_SIDE, 1.2, reach), "rot": ahead}
			d["turn"] = -0.35
		"throw_release":
			arms[1] = {"pos": Vector3(ARM_SIDE, 1.5, reach), "rot": Vector3(-PI * 0.25, 0, 0)}
			d["turn"] = 0.2
			d["lean"] = Body.SIDE_LEAN
		"throw_follow":
			arms[1] = {"pos": Vector3(0.0, 1.0, ARM_SIDE), "rot": ahead}
			d["lean"] = Body.SIDE_LEAN * 0.5
		"hands_up", "lean_back":
			d["arms"] = _hands_at(1.3, reach)
			if visual == "lean_back":
				d["lean"] = -Body.SIDE_LEAN
		"flinch":
			d["arms"] = _hands_at(1.2, 0.15)
			d["lift"] = -Body.BOB
			d["head"] = Vector3(0, -Body.BOW_DROP, 0)
		"crouch_grip":
			d["arms"] = _hands_at(Body.SEAT_HEIGHT, reach)
			d["lean"] = Body.HUDDLE_LEAN
		"heave":
			d["arms"] = _hands_at(0.9, reach)
			d["lean"] = Body.HUDDLE_LEAN * 0.5
		"tip_over":
			d["arms"] = _hands_at(1.1, reach + 0.15)
			d["lean"] = Body.SIDE_LEAN
		"torch_lift", "torch_high", "torch_sway":
			arms[1] = {"pos": Vector3(ARM_SIDE, 1.25 if visual == "torch_lift" else 1.5, ARM_SIDE), "rot": up}
			if visual == "torch_sway":
				d["turn"] = 0.25
		"torch_front", "torch_bob":
			arms[1] = {"pos": Vector3(ARM_SIDE, 1.3, reach + 0.1), "rot": Vector3(-PI / 3.0, 0, 0)}
			if visual == "torch_bob":
				d["lift"] = Body.BOB
		"hold_both":
			d["arms"] = _hands_at(1.0, ARM_SIDE)
		"bring_together", "catch":
			arms[0] = {"pos": Vector3(-0.12, 1.1, reach), "rot": ahead}
			arms[1] = {"pos": Vector3(0.12, 1.1, reach), "rot": ahead}
			d["lean"] = -Body.SIDE_LEAN * 0.5
			if visual == "catch":
				d["turn"] = -0.3
		"cloth_up":
			arms[0] = {"pos": Vector3(-ARM_SIDE, 1.5, ARM_SIDE), "rot": up}
		"arm_to_mouth":
			arms[1] = {"pos": Vector3(0.1, 1.2, 0.2), "rot": Vector3(0, PI * 0.5, 0)}
		"covered", "cough":
			arms[1] = {"pos": Vector3(0.0, 1.3, 0.22), "rot": Vector3(0, PI * 0.5, 0)}
			arms[0] = {"pos": Vector3(-ARM_SIDE, 1.0, reach), "rot": ahead}
			d["lean"] = Body.HUDDLE_LEAN * (0.6 if visual == "cough" else 0.4)
			d["head"] = Vector3(0, -Body.BOW_DROP, 0)


static func _hands_at(height: float, depth: float) -> Array:
	return [
		{"pos": Vector3(-ARM_SIDE, height, depth), "rot": Vector3(PI * 0.5, 0, 0)},
		{"pos": Vector3(ARM_SIDE, height, depth), "rot": Vector3(PI * 0.5, 0, 0)},
	]


static func _blend_new(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var d: Dictionary = _still()
	for key in ["turn", "lean", "sway", "lift"]:
		d[key] = lerpf(float(a[key]), float(b[key]), k)
	for key in ["head", "body_pos", "body_scale", "head_pos"]:
		d[key] = (a[key] as Vector3).lerp(b[key], k)
	d["arms"] = [_mix(a["arms"][0], b["arms"][0], k), _mix(a["arms"][1], b["arms"][1], k)]
	d["pose"] = a["pose"] if k < 0.5 else b["pose"]
	d["upper"] = b["upper"]
	d["held"] = b["held"]
	return d


## The stand-in reads the same keyed sample used by the future rig. An upper
## clip leaves the caller's walking/seated legs and body scale in place.
static func show_phase(body: Node3D, name: String, part: String, t: float, role: int = 0, facing: float = 0.0, confirmed: bool = false, from_pose: String = "sit") -> void:
	show_sample(body, phase_at(name, part, t, role, confirmed, from_pose), facing)


static func show_sample(body: Node3D, d: Dictionary, facing: float = 0.0) -> void:
	if not d.has("body_pos"):
		return
	if not bool(d["upper"]):
		body.pose = d["pose"]
		body.huddled = false
	body.show_pose()
	if not bool(d["upper"]):
		body.body_mesh.position = d["body_pos"]
		body.body_mesh.scale = d["body_scale"]
		body.head_mesh.position = d["head_pos"]
	body.rotation.y = facing + float(d["turn"])
	var lift := Vector3(0, float(d["lift"]), 0)
	body.body_mesh.position += lift
	body.body_mesh.rotation.x += float(d["lean"])
	body.body_mesh.rotation.z -= float(d["sway"])
	body.head_mesh.position += lift + (d["head"] as Vector3)
	var arms: Array = _arm_boxes(body)
	for i in 2:
		arms[i].visible = true
		arms[i].position = (d["arms"][i]["pos"] as Vector3) + lift
		arms[i].rotation = d["arms"][i]["rot"]


## The caller supplies both real positions and one local clock; no pair gap,
## displacement, contact outcome or damage is chosen by the gesture. (가안)
static func shove_pair(anchor_a: Vector3, anchor_b: Vector3, t: float, confirmed: bool = false, run_id: int = 0) -> Dictionary:
	return pair_at("shove_body", anchor_a, anchor_b, t, confirmed, run_id)


## Any two-person one-off row (shove_body, grab_collar, punch_swing, help_up)
## sampled for both roles at one common time.
static func pair_at(name: String, anchor_a: Vector3, anchor_b: Vector3, t: float, confirmed: bool = false, run_id: int = 0) -> Dictionary:
	var row: Dictionary = Riot.spec(name)
	if row.is_empty() or int(row["people"]) != 2 or row["kind"] != "once":
		return {}
	if anchor_a.is_equal_approx(anchor_b):
		return {}
	var contact: float = row["pair"]["contact"]
	var a: Dictionary = phase_at(name, "once", t, 0, confirmed)
	var b: Dictionary = phase_at(name, "once", t, 1, confirmed, "floor" if name == "help_up" else "sit")
	var across: Vector3 = anchor_b - anchor_a
	return {"run_id": run_id, "time": t, "contact": contact,
		"anchors": [anchor_a, anchor_b], "roles": [a, b],
		"facings": [atan2(across.x, across.z), atan2(-across.x, -across.z)]}


# ---------------------------------------------------------------- putting it on a body
const ARMS_META: String = "gesture_arms"


## Draws one gesture on a stand-in body (train_body.gd) at time t: its pose
## first, then what the gesture adds. The body's own facing is `facing`
## (radians about y); the two arm boxes are made the first time and kept.
## name "" takes the gesture off: the arms are hidden and the pose is as it was.
static func show(body: Node3D, name: String, t: float, role: int = 0, facing: float = 0.0) -> void:
	var arms: Array = _arm_boxes(body)
	if name == "":
		for arm in arms:
			arm.visible = false
		body.rotation.y = facing
		body.body_mesh.rotation.z = 0.0
		body.show_pose()
		return
	if not spec(name).is_empty():
		show_sample(body, at(name, t, role), facing)
		return
	var base: Dictionary = base_of(name)
	body.pose = base["base"]
	body.huddled = base["huddled"]
	body.clock = t
	body.show_pose()
	var d: Dictionary = at(name, t, role)
	var lift := Vector3(0, float(d["lift"]), 0)
	var lean: float = d["lean"]
	var sway: float = d["sway"]
	body.rotation.y = facing + float(d["turn"])
	body.body_mesh.position += lift
	body.body_mesh.rotation.x += lean
	body.body_mesh.rotation.z = -sway
	# The head rides the top of the trunk as it tips.
	var top: float = body.head_mesh.position.y - body.body_mesh.position.y
	body.head_mesh.position += lift + (d["head"] as Vector3) + Vector3(sway * top, 0, lean * top)
	for i in 2:
		arms[i].visible = true
		arms[i].position = (d["arms"][i]["pos"] as Vector3) + lift
		arms[i].rotation = d["arms"][i]["rot"]


static func _arm_boxes(body: Node3D) -> Array:
	if body.has_meta(ARMS_META):
		return body.get_meta(ARMS_META)
	var arms: Array = []
	for i in 2:
		var arm := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = ARM_SIZE
		arm.mesh = box
		arm.material_override = body.body_mesh.material_override
		arm.visible = false
		body.add_child(arm)
		arms.append(arm)
	body.set_meta(ARMS_META, arms)
	return arms


# ---------------------------------------------------------------- one display run
## The display clock is separate from sim/motion.gd: it owns no hit, step,
## inventory or interruption permission. Every end belongs to one run id.
var clip: String = ""
var segment: String = ""
var seconds: float = 0.0
var role: int = 0
var run_id: int = 0
var from_pose: String = "stand"
var pair_anchors: Array = []
var _exit_from: Dictionary = {}
var _exit_base: String = "stand"
var _shown: Dictionary = {}


func active() -> bool:
	return segment != "" and segment != "done"


## Two-person clips require both places in the same caller-owned scene.
## The scene uses shove_pair() with its common time for both bodies.
func begin(name: String, p_role: int = 0, p_run_id: int = 0, p_from_pose: String = "stand", context: Dictionary = {}) -> bool:
	var row: Dictionary = spec(name)
	if row.is_empty() or active():
		return false
	if p_role < 0 or p_role >= int(row["people"]):
		return false
	if not p_from_pose in ["stand", "sit", "floor", "walk"]:
		return false
	# Prepared hands, support and clearance are facts from the caller, not
	# new weapon, stove, crowding or collision rules.
	if not bool(context.get("hands_ready", false)):
		return false
	if name in ["sit_bench", "lie_bunk", "sleep_lean_wall", "warm_hands_stand", "warm_hands_crouch"]:
		var support = context.get("support")
		if not (support is Vector3 or support is Node3D):
			return false
	if name in ["sit_floor", "kneel", "stomp"] and not bool(context.get("floor_clear", false)):
		return false
	if name == "bang_object":
		var prop = context.get("prop")
		var target = context.get("target")
		if not (prop is Node3D) or not (target is Vector3 or target is Node3D):
			return false
	if name in ["warm_hands_stand", "fist_raise", "shove_body", "bang_object", "stomp"] and p_from_pose != "stand":
		return false
	if name == "spring_up" and not p_from_pose in ["sit", "floor"]:
		return false
	if name == "shove_body" and not bool(context.get("adult", false)):
		return false
	var rule: Dictionary = Riot.BEGIN_RULES.get(name, {})
	if not rule.is_empty():
		var from_ok: Array = rule.get("role_b_from", rule["from"]) if p_role == 1 else rule["from"]
		if not p_from_pose in from_ok:
			return false
		for key in rule["context"]:
			match key:
				"adult", "floor_clear":
					if not bool(context.get(key, false)):
						return false
				"prop":
					if not (context.get("prop") is Node3D):
						return false
				"target":
					var aim = context.get("target")
					if not (aim is Vector3 or aim is Node3D):
						return false
	var anchors: Array = context.get("anchors", [])
	if int(row["people"]) == 2:
		if anchors.size() != 2 or not (anchors[0] is Vector3) or not (anchors[1] is Vector3):
			return false
		if (anchors[0] as Vector3).is_equal_approx(anchors[1]):
			return false
	clip = name
	segment = "enter" if row["kind"] == "three" else "once"
	seconds = 0.0
	role = p_role
	run_id = p_run_id
	from_pose = p_from_pose
	pair_anchors = anchors.duplicate()
	_exit_from = {}
	# A fall ends on the floor so the next clip (spring_up, help_up B) starts there.
	_exit_base = "floor" if name == "fall_down" else "stand"
	_shown = {}
	# A body already in the required sitting support need not stand up to sit again.
	if name in ["sit_bench", "sit_floor"] and p_from_pose == row["base"]:
		segment = "loop"
	return true


func advance(delta: float) -> void:
	var left: float = maxf(delta, 0.0)
	while active() and left > 0.0:
		var total: float = duration()
		if total <= 0.0:
			segment = "done"
			return
		if segment == "loop":
			seconds = fposmod(seconds + left, total)
			return
		var until_end: float = maxf(total - seconds, 0.0)
		if left < until_end:
			seconds += left
			return
		left -= until_end
		if segment == "enter":
			segment = "loop"
			seconds = 0.0
		else:
			segment = "done"
			seconds = 0.0


func duration() -> float:
	var row: Dictionary = spec(clip)
	if row.is_empty() or not active():
		return 0.0
	if segment == "exit" and row["kind"] == "once":
		# First values (가안): upper recover 0.34, full-body recovery 0.7.
		return 0.34 if bool(row["upper"]) else 0.7
	return float(row["length"][segment])


## Keep the actual rendered pose. In a paired motion the caller's common
## scene clock can move without two independent advance() calls.
func observed(sample: Dictionary, scene_time: float = -1.0) -> void:
	if not active():
		return
	if scene_time >= 0.0 and segment == "once":
		seconds = clampf(scene_time, 0.0, duration())
	_shown = sample.duplicate(true)


## A run is cancelled exactly once. The old run cannot end a new run.
func cancel(p_run_id: int, next_pose: String = "stand", confirmed: bool = false) -> bool:
	if not active() or p_run_id != run_id or segment == "exit":
		return false
	if not next_pose in ["stand", "sit", "floor", "walk"]:
		return false
	_exit_from = _shown.duplicate(true) if not _shown.is_empty() else frame(confirmed)
	_exit_base = next_pose
	segment = "exit"
	seconds = 0.0
	return true


func frame(confirmed: bool = false) -> Dictionary:
	if clip == "":
		return {}
	if segment == "done":
		return _neutral_new(clip, _exit_base, from_pose)
	if segment == "exit":
		var target: Dictionary
		var row: Dictionary = spec(clip)
		if row["kind"] == "once":
			target = _neutral_new(clip, _exit_base, from_pose)
		else:
			target = phase_at(clip, "exit", seconds, role, confirmed, from_pose)
			if _exit_base != "stand":
				target = _blend_new(target, _neutral_new(clip, _exit_base, from_pose), clampf(seconds / duration(), 0.0, 1.0))
		return _blend_new(_exit_from, target, clampf(seconds / duration(), 0.0, 1.0))
	return phase_at(clip, segment, seconds, role, confirmed, from_pose)


static func _neutral_new(name: String, base: String, original: String) -> Dictionary:
	var visual: String = "stand"
	if base == "sit":
		visual = "seat"
	elif base == "floor":
		visual = "floor"
	return _visual(name, visual, 0, false, original)


## An invisible or removed body finishes its display bookkeeping once,
## without replaying an old object contact or keeping a seat reserved.
func finish_offscreen(p_run_id: int) -> bool:
	if not active() or p_run_id != run_id:
		return false
	segment = "done"
	seconds = 0.0
	_exit_from = {}
	_shown = {}
	return true


## One signal cancels both actors. If one was removed, the survivor still exits.
static func cancel_pair(first, second, p_run_id: int, next_pose: String = "stand") -> bool:
	var ended := false
	for actor in [first, second]:
		if actor != null and actor.has_method("cancel"):
			ended = bool(actor.call("cancel", p_run_id, next_pose)) or ended
	return ended
