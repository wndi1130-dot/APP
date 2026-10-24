extends Node3D
## How the train's people look (user request 2026-10-24): the field's baked body in place of
## the capsule and ball, with the train's own motions (train_clips.gd, folder
## n5-crew_seamstress_t). It only reads the bodies the train scene moves (where
## each is, which way it faces, its pose, its gesture, the life activity it is
## at) and the car's numbers, and decides nothing. Four multimeshes, one a
## coat, carry every drawn body of the train. Without the folder, or with the
## field's switch off, nothing is drawn here and the capsules stay.
##
## Every person is someone of their own (user 2026-10-24: each person's state
## and doing differ). Their number gives them traits that stay: how soon the
## cold gets to them, how sick the exposure makes them, how tired, how hungry,
## how quick to argue, how much they talk, how fast they react, and a
## timetable of their own (how long they keep at one thing, from when). The
## car's numbers only move the odds, so on one bench some sit, some talk, some
## doze, and the cold huddles some sooner than others.
##
## The transition layer is the one place a car's state turns into motion:
## want_for() is what a person would be doing now; shown_for() is what they are
## seen doing. A change is taken after the person's own delay (REACT_FROM ..
## REACT_TO), so a few react first and the rest follow, and BRIDGES can put a
## short joining motion between two. What the scene does to the body itself
## (sat it down, stood it up, set it walking, a gesture) is taken at once.
## The change of clip itself is eased (dead_body.gd mix_from).

const BodyBake = preload("res://scripts/body_bake.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const TrainClips = preload("res://game/train/train_clips.gd")
const Gesture = preload("res://game/train/train_gesture.gd")
const Look = preload("res://game/train/train_look.gd")
const Catalog = preload("res://game/train/train_catalog.gd")
const Rules = preload("res://game/train/train_rules.gd")

const SETTING: String = "visuals/baked_people_enabled"   # the field's switch (person_visual.gd)
const MAX_PEOPLE: int = 240
## Four worn coats over the one body's picture (tint / 0.5): faded neutral, brown,
## grey-blue and dark, so a bench of people is not one colour. No uniform among them.
const COATS: Array = [Vector3(0.44, 0.43, 0.41), Vector3(0.6, 0.46, 0.34), Vector3(0.34, 0.4, 0.5), Vector3(0.3, 0.3, 0.31)]
const SIT_FORWARD: float = 0.3           # metres: the baked seat is this far behind the feet
const BED_HEIGHT: float = 0.47           # one lying on a bench or a bed lies on its top
const STOVE_NEAR: float = 1.6            # metres: one cold this close to the stove holds its hands out to it
## The transition layer, first values. A person takes a change of state after
## a delay of their own; one in four reacts within the first second.
const REACT_FROM: float = 0.4
const REACT_TO: float = 7.0
const HOLD_FROM: float = 6.0             # seconds one keeps at one thing before their timetable may change it
const HOLD_TO: float = 16.0
const MIX_TIME: float = 0.45             # seconds a change of clip is eased over
## A joining motion between two, "from>to" or "*>to": [clip, seconds]. Taken
## only within one posture, after the delay. First entries; the joining motions
## the user picks (getting up from under a blanket, reaching to the stove) go here.
const BRIDGES: Dictionary = {
	"*>t_warm_hands": ["t_crouch", 1.2],
	"t_shiver>t_stand": ["t_fold", 1.5],
	"t_sit_doze>t_sit_talk": ["t_sit", 1.0],
}
## Which posture a motion is drawn in (a change between postures is not delayed).
const POSTURE: Dictionary = {
	"t_sit": "sit", "t_sit_talk": "sit", "t_sit_huddle": "sit", "t_sit_doze": "sit", "t_eat": "sit",
	"t_floor_sit": "floor", "t_crouch": "floor", "t_warm_hands": "floor", "t_lie": "lie", "t_kneel_work": "floor",
	"t_walk": "walk", "t_carry": "walk",
}

var scene                                 # train_scene.gd
var baked: Dictionary = {}
var draws: Array = []
var clip_index: Dictionary = {}
var table: Array = []                     # the folder's frames, for easing a change of clip
var mix_in: Dictionary = {}
var drawn: Dictionary = {}                # body -> clip name last drawn, for the tests and the shots
var people: Dictionary = {}               # body -> {shown, want, want_since, pose, bridge_until, after, mix}


static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING, true)) and ResourceLoader.exists(TrainClips.FOLDER.path_join("clips.json"))


func setup(train_scene) -> void:
	scene = train_scene
	name = "PeopleView"
	process_priority = 100               # after the scene has moved and posed everyone
	baked = DeadBody.with_albedo(BodyBake.load_baked(TrainClips.FOLDER), TrainClips.FOLDER)
	if baked.is_empty():
		return
	var clips: Array = baked["clips"]
	for n in clips.size():
		clip_index[String(clips[n]["name"])] = n
		mix_in[n] = MIX_TIME
	var mixes: bool = DeadBody.can_mix()
	if mixes:
		table = DeadBody.table_of(baked)
	var tables := VatBaker.shader_tables(baked)
	for coat in COATS:
		var one := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = baked["mesh"]
		mm.instance_count = MAX_PEOPLE
		mm.visible_instance_count = 0
		mm.custom_aabb = AABB(Vector3(-20, -3, -5), Vector3(400, 10, 10))
		one.multimesh = mm
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://game/actors/dead_vat.gdshader")
		mat.set_shader_parameter("vat", baked["texture"])
		for key in tables:
			mat.set_shader_parameter(key, tables[key])
		mat.set_shader_parameter("tint", coat)
		mat.set_shader_parameter("mixes", mixes)
		one.material_override = mat
		one.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(one)
		draws.append(one)


func is_worn() -> bool:
	return not draws.is_empty()


func _process(_delta: float) -> void:
	if draws.is_empty() or scene == null:
		return
	var now: float = float(scene.clock)
	var counts: Array = []
	counts.resize(COATS.size())
	counts.fill(0)
	drawn.clear()
	var seen: Dictionary = {}
	for c in scene.cars:
		var state := car_state(c)
		for b in c["bodies"]:
			if not is_instance_valid(b):
				continue
			_hide_boxes(b)
			if not b.visible:
				continue
			seen[b] = true
			var key: int = absi(b.get_instance_id())
			var coat: int = key % COATS.size()
			if counts[coat] >= MAX_PEOPLE:
				continue
			var life: Dictionary = scene.life.actors.get(b.get_instance_id(), {})
			var want := want_for(b, state, String(life.get("activity", "")), key, now, life.get("traits", {}))
			var clip := shown_for(b, want, now)
			drawn[b] = clip
			var mm: MultiMesh = (draws[coat] as MultiMeshInstance3D).multimesh
			mm.set_instance_transform(counts[coat], place_of(b, clip, state))
			var shade: float = lerpf(0.72, 1.0, _h(key, 11)) * (0.9 if state["freezing"] else 1.0)
			var plain := Color(_h(key, 12), float(clip_index.get(clip, 0)), 0.0, shade)
			var rec: Dictionary = people[b]
			mm.set_instance_custom_data(counts[coat], DeadBody.mix_from(rec["mix"], plain, now, table, mix_in))
			counts[coat] += 1
	for i in draws.size():
		(draws[i] as MultiMeshInstance3D).multimesh.visible_instance_count = counts[i]
	# Forget the people who are gone (a car reseated, a layout rebuilt).
	for b in people.keys():
		if not seen.has(b):
			people.erase(b)


## What a car is in, for picking motions: its numbers and kind, read only.
func car_state(c: Dictionary) -> Dictionary:
	var comm := Rules.comm_of(scene.rules, c["def"])
	var train: Dictionary = scene.rules.get("train", {})
	# The warmth the room shows (train_scene.gd room_w), so the people follow the stove and the frost.
	var w: float = float(c.get("room_w", Look.warmth(comm)))
	var view: Dictionary = scene.rules.get("view", {})
	return {
		"layout": Catalog.layout_id(c["def"]), "warmth": w, "cold": w < Look.WARM_COLD, "freezing": w < Look.WARM_FREEZING,
		"ration": Look.ration(comm), "crowding": Look.crowding(comm),
		"exposure": float((comm.get("sit", [0, 0, 0, 0]) as Array)[3]) if not comm.is_empty() else 0.0,
		"tension": float(train.get("tension", 0)), "fear": float(train.get("fear", 0)),
		"resent": Look.resents(comm) if not comm.is_empty() else false,
		"night": String(view.get("daytime", "day")) == "night", "stove_x": _stove_x(c),
	}


func _stove_x(c: Dictionary) -> float:
	var at: float = 7.85
	for row in Catalog.layout(c["def"])["props"]:
		if String(row.get("system", "")) == "stove":
			at = float(row["at"][0])
	return float(c["x0"]) + at


## A number in 0..1 that is always the same for one person and one salt.
static func _h(key: int, salt: int) -> float:
	return fposmod(sin(float(key % 100003) * 12.9898 + float(salt) * 78.233) * 43758.5453, 1.0)


## The traits one person keeps for good, from their number.
static func traits_of(key: int) -> Dictionary:
	return {
		"cold": _h(key, 1), "sick": _h(key, 2), "tired": _h(key, 3), "appetite": _h(key, 4),
		"temper": _h(key, 5), "social": _h(key, 6),
		# One in four is quick (under a second), the rest spread up to REACT_TO.
		"react": REACT_FROM + (REACT_TO - REACT_FROM) * pow(_h(key, 7), 1.6),
		"hold": lerpf(HOLD_FROM, HOLD_TO, _h(key, 8)), "offset": _h(key, 9) * HOLD_TO,
	}


## What one person would be doing now: what the scene and the life activity
## decide first (walking, a job, a gesture of a bad value, the council), and
## otherwise a pick of their own, weighted by the car's state and their traits,
## changed when their timetable comes round. `t` is the scene's clock.
static func want_for(b, s: Dictionary, activity: String, key: int, t: float = 0.0, life: Dictionary = {}) -> String:
	var pose: String = String(b.pose)
	if pose == "walk":
		return "t_carry" if activity == "carry" or String(b.errand.get("id", "")) in ["carry", "coal", "food"] else "t_walk"
	var forced := _forced(b, s, activity, t)
	if forced != "":
		return forced
	var me := traits_of(key)
	# What the life plan already knows of them: the sick and hurt, the children.
	me["ill"] = bool(life.get("sick", false)) or bool(life.get("injured", false))
	me["child"] = bool(life.get("child", false))
	var round_no: int = int(floor((t + float(me["offset"])) / float(me["hold"])))
	return _pick(weights_for(pose, b, s, me), key, round_no)


## What the scene or the life activity has already decided for this body.
static func _forced(b, s: Dictionary, activity: String, t: float) -> String:
	var pose: String = String(b.pose)
	var gesture: String = String(b.gesture)
	match activity:
		"warm":
			return "t_warm_hands"
		"sleep", "heal":
			return "t_lie"
		"cook":
			return "t_stir"
		"serve", "eat":
			return "t_eat"
		"work":
			# Coal and the firebox are shovelled; the rest is knelt at.
			return "t_shovel" if pose == "stand" and String(s["layout"]) in ["technical", "tender", "loco"] else "t_kneel_work"
		"clean":
			return "t_shovel" if pose == "stand" else "t_kneel_work"
		"care", "mend":
			return "t_kneel_work"
		"chat", "teach":
			return "t_talk" if pose == "stand" else "t_sit_talk"
		"refuge":
			return "t_crouch"
		"mourn":
			return "t_fold"
		"watch":
			return "t_lantern" if String(s["layout"]) == "guard" else ""
	match gesture:
		Gesture.BOWL_SIT:
			return "t_eat"
		Gesture.SLUMP:
			return "t_lie"
		Gesture.HUG_KNEES:
			return "t_floor_sit"
		Gesture.ARGUE:
			return "t_talk" if Gesture.speaking(t, int(b.gesture_role)) > 0.5 else "t_no"
		Gesture.WHISPER:
			return "t_talk"
		Gesture.ARMS_CROSSED, Gesture.BACK_TURNED:
			return "t_fold"
		Gesture.RUB_STAMP:
			return "t_shiver"
		Gesture.TURN_ABOUT:
			return "t_stand"
	if gesture != "" and Gesture.knows(gesture):
		return "t_talk" if gesture.contains("riot") or gesture.contains("protest") or gesture.contains("shout") else "t_stand"
	match String(b.act):
		"rise":
			return "t_talk"
		"lean":
			return "t_sit_talk"
	if pose == "sit" and (b.huddled or b.bowed):
		return "t_sit_huddle"
	if pose == "floor" and b.huddled:
		return "t_warm_hands" if absf(b.global_position.x - float(s["stove_x"])) < STOVE_NEAR else "t_crouch"
	return ""


## The odds of each motion for one person in one posture: the car's numbers
## (0..1 how cold, hungry, exposed, tense, crowded) against their own traits.
static func weights_for(pose: String, b, s: Dictionary, me: Dictionary) -> Dictionary:
	var cold_n: float = clampf((60.0 - float(s["warmth"])) / 40.0, 0.0, 1.0)
	var hunger_n: float = clampf((60.0 - float(s.get("ration", 60.0))) / 40.0, 0.0, 1.0)
	var expo_n: float = clampf((float(s["exposure"]) - 30.0) / 60.0, 0.0, 1.0)
	var tense_n: float = maxf(clampf((float(s.get("tension", 0.0)) - 30.0) / 50.0, 0.0, 1.0), 0.6 if s.get("resent", false) else 0.0)
	var crowd_n: float = clampf((float(s.get("crowding", 0.0)) - 60.0) / 35.0, 0.0, 1.0)
	var afraid: bool = float(s.get("fear", 0.0)) >= Look.FEAR_FROZEN
	var chilled: bool = float(me["cold"]) < cold_n
	var sick: bool = me.get("ill", false) or float(me["sick"]) < expo_n * (0.35 + 0.65 * cold_n)
	var hungry: bool = float(me["appetite"]) < hunger_n * 0.8
	var sleepy: bool = float(me["tired"]) < 0.12 + (0.5 if s["night"] else 0.0)
	var hothead: bool = float(me["temper"]) < tense_n * 0.7
	var talker: bool = float(me["social"]) > 0.55 and not afraid
	match pose:
		"sit":
			return {
				"t_sit": 2.0,
				"t_sit_talk": (1.6 if talker else 0.25) + (2.0 if hothead else 0.0),
				"t_sit_huddle": (4.0 if chilled else 0.0) + (1.5 if sick else 0.0) + (2.0 if afraid else 0.0),
				"t_sit_doze": 3.0 if sleepy else 0.2,
				"t_eat": 3.5 if hungry else 0.0,
			}
		"floor":
			var near: bool = absf(b.global_position.x - float(s["stove_x"])) < STOVE_NEAR
			return {
				"t_floor_sit": 2.0,
				"t_crouch": 2.5 if chilled else 0.3,
				"t_warm_hands": 5.0 if chilled and near else 0.0,
				"t_lie": (2.0 if sleepy else 0.0) + (2.0 if sick else 0.0) + 1.5 * crowd_n,
			}
	var guard: bool = String(s["layout"]) == "guard" and not me.get("child", false)
	return {
		"t_stand": 2.0,
		"t_fold": 1.0 + (1.5 if chilled else 0.0) + (2.0 if guard and not s["night"] else 0.0),
		"t_shiver": 4.0 if chilled else 0.0,
		"t_cough": 5.0 if sick else 0.0,
		"t_talk": 2.5 if hothead else (0.8 if talker else 0.0),
		"t_no": 1.5 if hothead else 0.0,
		"t_lantern": (5.0 if s["night"] else 1.5) if guard else 0.0,
	}


## A weighted pick that is the same for one person in one round of their timetable.
static func _pick(weights: Dictionary, key: int, round_no: int) -> String:
	var total := 0.0
	for k in weights:
		total += maxf(float(weights[k]), 0.0)
	if total <= 0.0:
		return "t_stand"
	var r: float = _h(key + round_no * 7919, 10) * total
	var last := ""
	for k in weights:
		var w: float = maxf(float(weights[k]), 0.0)
		if w <= 0.0:
			continue
		last = k
		r -= w
		if r < 0.0:
			return k
	return last


## What the scene itself has the body doing: its pose and, while in one, its
## gesture or council move. A change here is the scene moving the body, so the
## look follows at once; a gesture keeps its own beat (an argument's turns).
static func scene_beat(b) -> String:
	return "%s|%s|%s" % [b.pose, b.gesture, b.act]


## What one person is seen doing, given what they would be doing: when the
## scene moved the body (scene_beat), or a gesture is on, it is taken at once;
## otherwise after the person's own delay, through a joining motion when BRIDGES
## has one. This is the one place a change of the car's state reaches the look.
func shown_for(b, want: String, now: float) -> String:
	var key: int = absi(b.get_instance_id())
	var beat := scene_beat(b)
	if not people.has(b):
		people[b] = {"shown": want, "want": want, "want_since": now, "beat": beat, "bridge_until": -1.0, "after": "", "mix": {}}
		return want
	var rec: Dictionary = people[b]
	if beat != String(rec["beat"]) or String(b.gesture) != "" or String(b.act) != "":
		rec["shown"] = want
		rec["want"] = want
		rec["want_since"] = now
		rec["beat"] = beat
		rec["bridge_until"] = -1.0
		return want
	var pose: String = String(POSTURE.get(want, "stand"))
	if float(rec["bridge_until"]) > now:
		return String(rec["shown"])
	if float(rec["bridge_until"]) >= 0.0:
		rec["bridge_until"] = -1.0
		rec["shown"] = rec["after"]
	if want == String(rec["shown"]):
		rec["want"] = want
		return want
	if want != String(rec["want"]):
		rec["want"] = want
		rec["want_since"] = now
	if now - float(rec["want_since"]) < float(traits_of(key)["react"]):
		return String(rec["shown"])
	var bridge: Array = BRIDGES.get("%s>%s" % [rec["shown"], want], BRIDGES.get("*>%s" % want, []))
	if not bridge.is_empty() and String(POSTURE.get(String(bridge[0]), "stand")) == pose:
		rec["shown"] = bridge[0]
		rec["after"] = want
		rec["bridge_until"] = now + float(bridge[1])
		return String(rec["shown"])
	rec["shown"] = want
	return want


## Where the baked body stands for a body of the scene: its place and facing,
## the seat brought over the bench, the lying turned along the bunk.
func place_of(b, clip: String, _state: Dictionary) -> Transform3D:
	var yaw: float = b.global_rotation.y
	var at: Vector3 = b.global_position
	var basis := Basis(Vector3.UP, yaw)
	match clip:
		"t_sit", "t_sit_talk", "t_sit_huddle", "t_sit_doze", "t_eat":
			if String(b.pose) == "sit":
				at += basis * Vector3(0, 0, SIT_FORWARD)
		"t_lie":
			# Along the car, on the bench or bed it was sat on, or on the floor.
			basis = Basis(Vector3.UP, PI * 0.5)
			if String(b.pose) == "sit":
				at.y += BED_HEIGHT
	return Transform3D(basis, at)


## The capsule, the ball, the gesture's arm boxes and the held bowl go while a body is worn.
func _hide_boxes(b) -> void:
	for child in b.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
