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


static func at(name: String, t: float, role: int = 0) -> Dictionary:
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
