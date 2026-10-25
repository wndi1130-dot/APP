extends Node3D
## How the train's people look (user request 2026-10-24): baked bodies in place of
## the capsule and ball, with the train's own motions (train_clips.gd, folders
## <body>_t). It only reads the bodies the train scene moves (where each is,
## which way it faces, its pose, its gesture, the life activity it is at) and
## the car's numbers, and decides nothing. One multimesh a body carries every
## person of the train who wears it. Without the folders, or with the field's
## switch off, nothing is drawn here and the capsules stay.
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
##
## The cold over it (user 2026-10-25: two or three under one blanket, breath,
## doing things while shivering): a tremble on top of whatever one does, as
## much as the cold gets to that person; on a cold bench neighbours hunched
## under one blanket; in a freezing car breath before a few faces. All three
## follow the warmth the room shows and each person's own delay, so the stove
## and the frost still go first.
##
## What happens reaches them (user 2026-10-25: every decision of the player
## shows in the cars): a thing that happened, {kind, car, comm, sign, size,
## day}, comes either from the rules (a law passed or repealed, rations moved,
## people taken in or gone, a search party out or back, the dead, a decree;
## events_between reads the values before and after) or from post_event (what
## the workshop made, a car changed or added). In the cars it reaches, a few
## people react for a while, each as they are (the quick-tempered argue, the
## talkers put their heads together, the shy close up, the ones it helps
## approve), and for a day or two after the car keeps a trace of it in what its
## people do. Nothing here changes a value.

const BodyBake = preload("res://scripts/body_bake.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const TrainClips = preload("res://game/train/train_clips.gd")
const Gesture = preload("res://game/train/train_gesture.gd")
const Look = preload("res://game/train/train_look.gd")
const Catalog = preload("res://game/train/train_catalog.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Smoke = preload("res://fx/smoke.gd")

const SETTING: String = "visuals/baked_people_enabled"   # the field's switch (person_visual.gd)
const MAX_PEOPLE: int = 240
const PEOPLE_DIR: String = "res://models/people/"
## Each person has a body of their own (user 2026-10-25: every person a different
## body), every one baked with the same train motions (tools/bake_train_cli.gd,
## folders <body>_t). The car and the person's work pick it first; the rest wear
## ordinary clothes, and two neighbours do not share one. No uniform among them:
## the guards wear plain coats.
## Eight bodies at most on the train screen at once (the body bake's PC
## estimate until the phone is measured: about 2.5MB of GPU each), and the
## light ones (1,200 to 1,420 points): the twice-as-heavy bodies stay out.
const ROLE_BODIES: Dictionary = {
	"cook": ["n5-crew_cook_t"],
	"stoker": ["n5-crew_stoker_t"],
	"carer": ["n5-crew_medic_t"],
	"guard": ["n5-crew_guard_t"],
}
const GENERAL_BODIES: Array = [
	"n10-body_sheepskin-m_t", "n3-body_parka_t", "n10-body_apron-f_t", "n5-crew_guard-f_t",
]
## How many in one car wear their work's body: the life plan makes every able
## person in the medical car a carer and every adult in the dining car a cook,
## so the first two do and the rest wear their own clothes (no car of twins).
const ROLE_A_CAR: int = 2
const NEUTRAL_TINT := Vector3(0.5, 0.5, 0.5)   # the body's own picture as it is (tint / 0.5)
## Two in one place doing the same at the same moment read as a loop: the one
## beside (NEIGHBOUR m along the car, same posture) is not copied, talk aside.
const NEIGHBOUR: float = 1.3
const TOGETHER: Array = ["t_sit_talk", "t_talk"]
## A guard on the guard car's bench sits with a gun across the knees, looking it over.
const LAP_GUN := "res://models/weapons/shotgun.glb"
const LAP_GUNS: int = 2
const LAP_AT := Vector3(0.0, 0.56, 0.12)   # metres from the feet: on the knees
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
	"t_sit_nod": "sit", "t_sit_no": "sit", "t_sit_fold": "sit", "t_sit_clap": "sit", "t_gun_clean": "sit", "t_handwork": "sit",
	"t_floor_sit": "floor", "t_crouch": "floor", "t_warm_hands": "floor", "t_lie": "lie", "t_kneel_work": "floor",
	"t_walk": "walk", "t_carry": "walk",
}
## The tremble of the cold (dead_vat.gdshader: b below 0), at most SHIVER_MAX,
## less in a motion that already warms or already shivers.
const SHIVER_MAX: float = 0.5
const SHIVER_DAMP: Dictionary = {
	"t_shiver": 0.0, "t_warm_hands": 0.4, "t_lie": 0.5, "t_walk": 0.3, "t_carry": 0.3,
	"t_shovel": 0.5, "t_stir": 0.5, "t_kneel_work": 0.5,
}
const UNDER_BLANKET: float = 0.5          # the tremble left under a shared blanket
## One blanket over two or three side by side on a cold bench, hunched up under
## it. The cloth is shaped here (blanket_mesh) over the hunched sitting body of
## the train bake, for the bench's seat step; it is pulled up over BLANKET_UP
## once all under it are seen hunched, and let down again the same way.
const BLANKETS_A_CAR: int = 2
const BLANKETS: int = 16                  # of each size, for the whole train
const BLANKET_UP: float = 0.9
const BLANKET_LOW: float = 0.55           # how far down it starts (in the lap)
const BLANKET_STEP: float = 0.95          # metres between two seats (train_scene.gd SLOT_STEP)
const BLANKET_EDGE: float = 0.34          # metres it reaches past the outer two
## Worn wool, dark and cold beside the snow light: one of these a blanket.
const BLANKET_TINTS: Array = [
	Color(0.60, 0.54, 0.46), Color(0.46, 0.50, 0.44), Color(0.47, 0.51, 0.58), Color(0.52, 0.42, 0.38),
]
## Breath in a freezing car: one small emitter a car (fx/smoke.gd "breath"),
## from the mouths of a few who feel the cold, not of everyone.
const BREATH_CARS: int = 6
const BREATH_HEADS: int = 4
const BREATH_FROM: float = 0.05           # the tremble from which one's breath shows
const BREATH_PER_HEAD: float = 0.5        # puffs alive a head: one about every 2.4 s
const BREATH_EVERY: float = 0.5           # seconds between looks at whose breath shows
## Where the mouth is in a motion (metres from the baked body's place).
const MOUTH: Dictionary = {
	"t_sit_huddle": Vector3(0.0, 1.0, 0.34), "t_sit": Vector3(0.0, 1.16, 0.04),
	"t_sit_talk": Vector3(0.0, 1.16, 0.04), "t_sit_doze": Vector3(0.0, 1.1, 0.18),
	"t_sit_nod": Vector3(0.0, 1.16, 0.04), "t_sit_no": Vector3(0.0, 1.16, 0.04), "t_sit_fold": Vector3(0.0, 1.16, 0.04),
	"t_sit_clap": Vector3(0.0, 1.16, 0.04), "t_gun_clean": Vector3(0.0, 1.06, 0.2), "t_handwork": Vector3(0.0, 1.06, 0.2),
}
const MOUTH_STANDING := Vector3(0.0, 1.45, 0.13)
## A reaction: how many react (2 .. 6 by the event's size), for how long
## (REACT_FOR seconds by size), in at most REACT_CARS cars of a train-wide one.
const REACT_FEW: int = 2
const REACT_MANY: int = 6
const REACT_FOR := Vector2(10.0, 60.0)
const REACT_CARS: int = 3
## What keeps someone from reacting: asleep, hurt, or at a job. The rest (a
## chat, warming hands, a bowl, the cold hunch) look up for it.
const REACT_BUSY: Array = ["sleep", "heal", "cook", "serve", "work", "clean", "care", "mend", "refuge", "mourn"]
## What each way of taking it looks like in each posture.
const REACTIONS: Dictionary = {
	"argue": {"sit": "t_sit_talk", "stand": "t_no", "floor": "t_floor_sit"},
	"whisper": {"sit": "t_sit_talk", "stand": "t_talk", "floor": "t_floor_sit"},
	"withdraw": {"sit": "t_sit_fold", "stand": "t_fold", "floor": "t_floor_sit"},
	"headshake": {"sit": "t_sit_no", "stand": "t_no", "floor": "t_floor_sit"},
	"approve": {"sit": "t_sit_nod", "stand": "t_nod", "floor": "t_floor_sit"},
	"cheer": {"sit": "t_sit_clap", "stand": "t_clap", "floor": "t_floor_sit"},
	"grief": {"sit": "t_sit_huddle", "stand": "t_fold", "floor": "t_floor_sit"},
}
## Events that are a loss: everyone it reaches is quiet.
const GRIEF: Array = ["memorial", "dead_stored", "let_go"]
## Events of the whole train (a law, a vote, a decree): every car with people.
const TRAIN_WIDE: Array = ["law_passed", "law_repealed", "vote_called", "vote_done", "decree", "memorial", "dead_stored"]
## The trace a car keeps for a few days: what its people do more (or less) of,
## by kind (and "-" or "+" for its sign), scaled by the event's size.
const MARKS: Dictionary = {
	"ration-": {"t_eat": 1.5, "t_sit_talk": 0.6, "t_talk": 0.6, "t_sit_huddle": 0.6},
	"ration+": {"t_eat": 1.0, "t_sit_talk": 0.8, "t_sit_doze": 0.4},
	"law_passed": {"t_sit_talk": 1.2, "t_talk": 1.0, "t_no": 0.4},
	"law_repealed": {"t_sit_talk": 1.2, "t_talk": 1.0, "t_no": 0.4},
	"vote_done": {"t_sit_talk": 1.0, "t_talk": 0.8},
	"memorial": {"t_sit_talk": -1.5, "t_talk": -1.5, "t_sit_huddle": 1.0, "t_fold": 1.0},
	"dead_stored": {"t_sit_talk": -1.0, "t_talk": -1.0, "t_sit_huddle": 0.8, "t_fold": 0.8},
	"taken_in": {"t_sit_talk": 0.8, "t_talk": 0.6},
	"let_go": {"t_fold": 1.0, "t_sit_huddle": 0.6, "t_sit_talk": -0.6},
	"party_out": {"t_fold": 0.8, "t_lantern": 0.5},
	"party_back": {"t_sit_talk": 1.0, "t_talk": 1.0},
	"decree": {"t_fold": 1.0, "t_no": 0.8, "t_sit_talk": 0.5},
	"made": {"t_sit_talk": 0.6, "t_talk": 0.6, "t_kneel_work": 0.4},
	"mod_done": {"t_sit_talk": 0.6, "t_talk": 0.6},
	"car_added": {"t_sit_talk": 0.6, "t_talk": 0.6},
}
const LINGER: Dictionary = {"memorial": 3, "dead_stored": 3, "made": 1}
const LINGER_DAYS: int = 2
const HEARD_KEPT: int = 64              # the last events kept for the tests and the shots
## A change of rations this big (of 100) is an event.
const RATION_STEP: float = 8.0

var scene                                 # train_scene.gd
var bodies: Dictionary = {}               # folder -> {draw, clip_index, table, mix_in, count}
var draws: Array = []
var drawn: Dictionary = {}                # body -> clip name last drawn, for the tests and the shots
var worn: Dictionary = {}                 # body -> the folder it wears
var people: Dictionary = {}               # body -> {shown, want, want_since, pose, bridge_until, after, mix, wears}
var guns: MultiMeshInstance3D
var blankets: Array = []                  # one multimesh for two under it, one for three
var covers: Dictionary = {}               # first under it -> {k (0 down .. 1 up), under}
var shivers: Dictionary = {}              # body -> the tremble drawn, for the tests and the shots
var breath: Dictionary = {}               # car id -> {p, t, key, heads}
var _last_now: float = 0.0
var heard: Array = []                     # every event taken, in order
var scenes: Dictionary = {}               # car id -> {kind, from, until, picks: {body: clip}}
var marks: Dictionary = {}                # car id -> [{kind, sign, size, until (day)}]
var _seen_rules: Dictionary = {}          # the rules as they were, for events_between


static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING, true)) and ResourceLoader.exists(TrainClips.FOLDER.path_join("clips.json"))


func setup(train_scene) -> void:
	scene = train_scene
	name = "PeopleView"
	process_priority = 100               # after the scene has moved and posed everyone
	var mixes: bool = DeadBody.can_mix()
	var folders: Array = GENERAL_BODIES.duplicate()
	for role in ROLE_BODIES:
		folders.append_array(ROLE_BODIES[role])
	for folder in folders:
		var dir: String = PEOPLE_DIR + String(folder)
		if not ResourceLoader.exists(dir.path_join("clips.json")):
			continue
		var baked: Dictionary = DeadBody.with_albedo(BodyBake.load_baked(dir), dir)
		if baked.is_empty():
			continue
		var one := {"clip_index": {}, "table": [], "mix_in": {}, "count": 0}
		var clips: Array = baked["clips"]
		for n in clips.size():
			one["clip_index"][String(clips[n]["name"])] = n
			one["mix_in"][n] = MIX_TIME
		if mixes:
			one["table"] = DeadBody.table_of(baked)
		var tables := VatBaker.shader_tables(baked)
		var draw := MultiMeshInstance3D.new()
		draw.name = String(folder)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = baked["mesh"]
		mm.instance_count = MAX_PEOPLE
		mm.visible_instance_count = 0
		mm.custom_aabb = AABB(Vector3(-20, -3, -5), Vector3(400, 10, 10))
		draw.multimesh = mm
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://game/actors/dead_vat.gdshader")
		mat.set_shader_parameter("vat", baked["texture"])
		for key in tables:
			mat.set_shader_parameter(key, tables[key])
		mat.set_shader_parameter("tint", NEUTRAL_TINT)
		mat.set_shader_parameter("mixes", mixes)
		draw.material_override = mat
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(draw)
		draws.append(draw)
		one["draw"] = draw
		bodies[String(folder)] = one
	guns = _lap_guns()
	for n in [2, 3]:
		blankets.append(_blanket_draw(n))
	# A screen built afresh from a state that moved on (the slice shows a new train
	# scene at each stop) can bring the values it last showed, so what changed in
	# between is taken in here as it would be on one screen.
	var before = scene.opts.get("rules_before", null)
	_seen_rules = (before if before is Dictionary else scene.rules).duplicate(true)
	scene.rules_applied.connect(_on_rules)
	if before is Dictionary:
		_on_rules()


func is_worn() -> bool:
	return not draws.is_empty()


func _process(_delta: float) -> void:
	if draws.is_empty() or scene == null:
		return
	var now: float = float(scene.clock)
	var dt: float = clampf(now - _last_now, 0.0, 0.5)
	_last_now = now
	for folder in bodies:
		bodies[folder]["count"] = 0
	drawn.clear()
	worn.clear()
	shivers.clear()
	var seen: Dictionary = {}
	var gun_count := 0
	var wanted: Array = []                # the blankets wanted this frame: the bodies under each
	var cars_seen: Dictionary = {}
	for c in scene.cars:
		var state := car_state(c)
		var prev := ""
		var at_work := 0
		var last_want := ""
		var last_x := -1000.0
		var last_pose := ""
		var ordered := in_seat_order(c["bodies"])
		var under: Dictionary = {}
		for group in blanket_groups(_bench_rows(ordered, state, now), state):
			var members: Array = group.map(func(i): return ordered[i])
			for m in members:
				under[m] = true
			wanted.append(members)
		var heads: Array = []
		var reacting: Dictionary = _reacting(String(c["id"]), now)
		for b in ordered:
			_hide_boxes(b)
			if not b.visible:
				continue
			seen[b] = true
			var key: int = absi(b.get_instance_id())
			var life: Dictionary = scene.life.actors.get(b.get_instance_id(), {})
			var traits: Dictionary = life.get("traits", {})
			if under.has(b):
				traits = traits.merged({"blanket": true})
			if reacting.has(b):
				traits = traits.merged({"react": reacting[b]})
			var x: float = b.global_position.x
			var beside: bool = String(b.pose) == last_pose and x - last_x < NEIGHBOUR
			var want := want_for(b, state, String(life.get("activity", "")), key, now, traits, last_want if beside else "")
			last_want = want
			last_x = x
			last_pose = String(b.pose)
			var clip := shown_for(b, want, now)
			var rec: Dictionary = people[b]
			if not rec.has("wears") or not bodies.has(String(rec["wears"])):
				rec["wears"] = _available(body_for(String(state["layout"]), String(traits.get("role", "")), at_work, key, prev), key)
			var folder: String = rec["wears"]
			if not GENERAL_BODIES.has(folder):
				at_work += 1
			prev = folder
			var one: Dictionary = bodies[folder]
			if int(one["count"]) >= MAX_PEOPLE:
				continue
			drawn[b] = clip
			worn[b] = folder
			var i: int = one["count"]
			var mm: MultiMesh = (one["draw"] as MultiMeshInstance3D).multimesh
			mm.set_instance_transform(i, place_of(b, clip, state))
			var shade: float = lerpf(0.78, 1.0, _h(key, 11)) * (0.9 if state["freezing"] else 1.0)
			var shiver := _shiver_of(rec, state, key, clip, under.has(b), dt)
			shivers[b] = shiver
			var plain := Color(_h(key, 12), float(one["clip_index"].get(clip, 0)), -shiver, shade)
			mm.set_instance_custom_data(i, DeadBody.mix_from(rec["mix"], plain, now, one["table"], one["mix_in"]))
			one["count"] = i + 1
			if state["freezing"] and shiver >= BREATH_FROM and heads.size() < BREATH_HEADS:
				var mouth = MOUTH.get(clip, MOUTH_STANDING if String(b.pose) == "stand" else null)
				if mouth != null:
					heads.append(place_of(b, clip, state) * Vector3(mouth))
			if guns != null and gun_count < LAP_GUNS and String(state["layout"]) == "guard" and clip in ["t_sit", "t_gun_clean"] and String(b.pose) == "sit":
				var at: Transform3D = place_of(b, clip, state)
				guns.multimesh.set_instance_transform(gun_count, at * Transform3D(Basis(Vector3.UP, PI * 0.5), LAP_AT))
				gun_count += 1
		cars_seen[String(c["id"])] = true
		_breathe(c, heads, now)
	for id in breath:
		if not cars_seen.has(id):
			(breath[id]["p"] as GPUParticles3D).emitting = false
	_cover(wanted, dt)
	if guns != null:
		guns.multimesh.visible_instance_count = gun_count
	for folder in bodies:
		(bodies[folder]["draw"] as MultiMeshInstance3D).multimesh.visible_instance_count = int(bodies[folder]["count"])
	# Forget the people who are gone (a car reseated, a layout rebuilt).
	for b in people.keys():
		if not seen.has(b):
			people.erase(b)


## Which body a person wears: the car and their work first (the cook, the
## stoker, the carers, the guard car's guards), ROLE_A_CAR of them a car
## (`at_work` already wear one), otherwise ordinary clothes by their number,
## never the same as the one beside them.
static func body_for(layout: String, role: String, at_work: int, key: int, prev: String) -> String:
	var kind := ""
	match role:
		"cook":
			kind = "cook"
		"carer":
			kind = "carer"
		"worker":
			kind = "stoker" if layout in ["technical", "loco", "tender"] else ""
	if kind == "" and layout == "guard":
		kind = "guard"
	if kind == "" and layout == "loco":
		kind = "stoker"
	if at_work >= ROLE_A_CAR:
		kind = ""
	if kind == "guard":
		return String(ROLE_BODIES["guard"][at_work % ROLE_BODIES["guard"].size()])
	if kind != "":
		var list: Array = ROLE_BODIES[kind]
		return String(list[key % list.size()])
	var n: int = GENERAL_BODIES.size()
	var pick: int = key % n
	if String(GENERAL_BODIES[pick]) == prev:
		pick = (pick + 1) % n
	return String(GENERAL_BODIES[pick])


## A car's people from one end to the other, so the one beside is the one before.
static func in_seat_order(list: Array) -> Array:
	var out: Array = list.filter(func(b): return is_instance_valid(b))
	out.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	return out


## One multimesh of the gun that lies across a guard's knees (one draw for all).
func _lap_guns() -> MultiMeshInstance3D:
	if not ResourceLoader.exists(LAP_GUN):
		return null
	var packed = load(LAP_GUN)
	if not packed is PackedScene:
		return null
	var root: Node = (packed as PackedScene).instantiate()
	var found: Array = root.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
	root.free()
	if mesh == null:
		return null
	var draw := MultiMeshInstance3D.new()
	draw.name = "LapGuns"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = LAP_GUNS
	mm.visible_instance_count = 0
	draw.multimesh = mm
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(draw)
	return draw


## The body if it was baked here, else an ordinary one that was.
func _available(folder: String, key: int) -> String:
	if bodies.has(folder):
		return folder
	var n: int = GENERAL_BODIES.size()
	for k in n:
		var other: String = GENERAL_BODIES[(key + k) % n]
		if bodies.has(other):
			return other
	return String(bodies.keys()[0])


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
		"meal": bool(scene.life.contexts.get(c["id"], {}).get("meal", false)),
		"marks": _marks_of(String(c["id"])),
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
static func want_for(b, s: Dictionary, activity: String, key: int, t: float = 0.0, life: Dictionary = {}, avoid: String = "") -> String:
	var pose: String = String(b.pose)
	if pose == "walk":
		return "t_carry" if activity == "carry" or String(b.errand.get("id", "")) in ["carry", "coal", "food"] else "t_walk"
	# Something has just happened in the car: their way of taking it, while it
	# lasts, over the everyday gestures, unless busy or the scene has them up.
	var reaction: String = String(life.get("react", ""))
	if reaction != "" and String(POSTURE.get(reaction, "stand")) == pose and not REACT_BUSY.has(activity) and String(b.act) == "":
		return reaction
	var forced := _forced(b, s, activity, t)
	if forced != "":
		return forced
	# Under a shared blanket one sits hunched up with the others.
	if pose == "sit" and bool(life.get("blanket", false)):
		return "t_sit_huddle"
	var me := traits_of(key)
	# What the life plan already knows of them: the sick and hurt, the children.
	me["ill"] = bool(life.get("sick", false)) or bool(life.get("injured", false))
	me["child"] = bool(life.get("child", false))
	me["role"] = String(life.get("role", ""))
	var round_no: int = int(floor((t + float(me["offset"])) / float(me["hold"])))
	var weights := weights_for(pose, b, s, me)
	# Not the same as the one beside at the same moment (talk is done together):
	# that motion is left out of this person's odds, unless it is all there is.
	if avoid != "" and not TOGETHER.has(avoid) and float(weights.get(avoid, 0.0)) > 0.0:
		var others := weights.duplicate()
		others[avoid] = 0.0
		var rest := 0.0
		for k in others:
			rest += maxf(float(others[k]), 0.0)
		if rest > 0.0:
			weights = others
	return _pick(weights, key, round_no)


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
	var weights := _base_weights(pose, b, s, me)
	# What happened in the car these last days leaves its trace (MARKS).
	for m: Dictionary in s.get("marks", []):
		var kind: String = String(m["kind"])
		var add: Dictionary = MARKS.get("%s%s" % [kind, "-" if int(m["sign"]) < 0 else "+"], MARKS.get(kind, {}))
		var scale: float = 0.5 + float(m["size"])
		for clip in add:
			if weights.has(clip):
				weights[clip] = maxf(float(weights[clip]) + float(add[clip]) * scale, 0.0)
	return weights


static func _base_weights(pose: String, b, s: Dictionary, me: Dictionary) -> Dictionary:
	var cold_n: float = cold_of(s)
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
	# At ease: warm, fed, no quarrel in the air. Then the car rests, talks and eats
	# as a car of its kind does (user 2026-10-25: a peaceful train shown at random).
	var calm: bool = cold_n < 0.4 and hunger_n < 0.4 and tense_n < 0.3 and not afraid
	var layout: String = String(s["layout"])
	var role: String = String(me.get("role", ""))
	var guard: bool = layout == "guard" and not me.get("child", false)
	match pose:
		"sit":
			return {
				"t_sit": 2.0 + (0.8 if guard else 0.0),
				# A guard looks the gun on the knees over; a calm car mends and reads.
				"t_gun_clean": 1.5 if guard and not s["night"] else 0.0,
				"t_handwork": (1.0 if calm else 0.2) if not guard and not me.get("child", false) else 0.0,
				"t_sit_talk": (1.6 if talker else 0.25) + (2.0 if hothead else 0.0) + (1.0 if calm else 0.0) + (1.2 if layout == "dining" else 0.0),
				"t_sit_huddle": (4.0 if chilled else 0.0) + (1.5 if sick else 0.0) + (2.0 if afraid else 0.0),
				"t_sit_doze": (3.0 if sleepy else 0.2) * (0.3 if guard else 1.0) + (0.8 if calm and not guard else 0.0),
				"t_eat": (3.5 if hungry else 0.0) + ((3.0 if s.get("meal", false) else 0.8) if layout == "dining" else 0.0),
			}
		"floor":
			var near: bool = absf(b.global_position.x - float(s["stove_x"])) < STOVE_NEAR
			var at_work: bool = (role == "carer" and layout == "medical") or (role == "worker" and layout == "technical")
			return {
				"t_floor_sit": 2.0,
				"t_crouch": 2.5 if chilled else 0.3,
				"t_warm_hands": 5.0 if chilled and near else 0.0,
				"t_lie": (2.0 if sleepy else 0.0) + (2.0 if sick else 0.0) + 1.5 * crowd_n + (0.8 if calm else 0.0),
				"t_kneel_work": 3.0 if at_work else 0.0,
			}
	return {
		"t_stand": 2.0,
		"t_fold": 1.0 + (1.5 if chilled else 0.0) + (2.0 if guard and not s["night"] else 0.0),
		"t_shiver": 4.0 if chilled else 0.0,
		"t_cough": 5.0 if sick else 0.0,
		"t_talk": (2.5 if hothead else (0.8 if talker else 0.0)) + (0.8 if calm and talker else 0.0),
		"t_no": 1.5 if hothead else 0.0,
		"t_lantern": (5.0 if s["night"] else 1.5) if guard else 0.0,
		"t_stir": 3.0 if role == "cook" and layout == "dining" else 0.0,
		# The cook hands the bowls round at a meal; one cold by the stove reaches to it.
		"t_pass": 2.0 if role == "cook" and layout == "dining" and s.get("meal", false) else 0.0,
		"t_reach": 3.0 if chilled and b.is_inside_tree() and absf(b.global_position.x - float(s["stove_x"])) < STOVE_NEAR else 0.0,
		"t_shovel": 1.5 if role == "worker" and layout in ["technical", "tender", "loco"] else 0.0,
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


## Take one event: the cars it reaches keep a trace of it for a few days, and
## in up to REACT_CARS of them a few people react now (one scene a car, a
## newer one takes the place of an older).
func react(ev: Dictionary) -> void:
	var now: float = float(scene.clock)
	var day: int = int(ev.get("day", _day()))
	var kind: String = String(ev.get("kind", ""))
	var size: float = clampf(float(ev.get("size", 0.5)), 0.0, 1.0)
	heard.append(ev)
	if heard.size() > HEARD_KEPT:
		heard = heard.slice(heard.size() - HEARD_KEPT)
	var shown := 0
	for c in cars_for(ev, scene.cars):
		var id: String = String(c["id"])
		var sign: int = _sign_in(ev, c)
		var list: Array = marks.get(id, [])
		list.append({"kind": kind, "sign": sign, "size": size, "until": day + int(LINGER.get(kind, LINGER_DAYS))})
		marks[id] = list
		if shown >= REACT_CARS:
			continue
		var rows: Array = []
		var who: Array = []
		for b in in_seat_order(c["bodies"]):
			var busy: bool = REACT_BUSY.has(String(scene.life.actors.get(b.get_instance_id(), {}).get("activity", "")))
			if b.visible and String(b.pose) in ["sit", "stand", "floor"] and not busy:
				rows.append({"key": absi(b.get_instance_id()), "pose": String(b.pose)})
				who.append(b)
		var picked := reaction_picks(kind, sign, size, rows, day)
		if picked.is_empty():
			continue
		var picks: Dictionary = {}
		for i in picked:
			picks[who[i]] = picked[i]
		scenes[id] = {"kind": kind, "from": now, "until": now + lerpf(REACT_FOR.x, REACT_FOR.y, size), "picks": picks}
		shown += 1


## The cars an event reaches: the one it names, or its community's, or every
## car with people for one of the whole train (the council's car first), or
## for what the workshop made the workshop. Not the engine, the stores, the cold car.
static func cars_for(ev: Dictionary, cars: Array) -> Array:
	var kind := String(ev.get("kind", ""))
	var car_id := String(ev.get("car", ""))
	var comm := String(ev.get("comm", ""))
	var first: Array = []
	var rest: Array = []
	for c in cars:
		var def: Dictionary = c["def"]
		var layout := Catalog.layout_id(def)
		if car_id != "":
			if String(c["id"]) == car_id:
				rest.append(c)
			continue
		if layout in ["loco", "tender", "freight", "cold"]:
			continue
		if comm != "":
			if String(def.get("comm", "")) == comm:
				rest.append(c)
		elif TRAIN_WIDE.has(kind):
			(first if layout == "dining" else rest).append(c)
		elif kind == "made" and layout == "technical":
			rest.append(c)
	return first + rest


## Which way an event goes for a car: its own sign, or for a law or a vote,
## how that car's people stand with the captain.
func _sign_in(ev: Dictionary, c: Dictionary) -> int:
	var sign: int = int(ev.get("sign", 0))
	if sign != 0 or not String(ev.get("kind", "")) in ["law_passed", "law_repealed", "vote_done"]:
		return sign
	var comm: Dictionary = (scene.rules.get("comms", {}) as Dictionary).get(String((c["def"] as Dictionary).get("comm", "")), {})
	var rel: float = float(comm.get("rel", 0))
	return -1 if rel < -10.0 else (1 if rel > 10.0 else 0)


## Who reacts and how (indices into rows of {key, pose}): a different few
## each time, more for a bigger event, each by their own traits.
static func reaction_picks(kind: String, sign: int, size: float, rows: Array, day: int) -> Dictionary:
	var n: int = mini(clampi(REACT_FEW + int(round(size * float(REACT_MANY - REACT_FEW))), REACT_FEW, REACT_MANY), rows.size())
	var out: Dictionary = {}
	if n < 1:
		return out
	var salt: int = absi(kind.hash()) % 997 + day * 13
	var order: Array = range(rows.size())
	order.sort_custom(func(a, b): return _h(int(rows[a]["key"]), salt) < _h(int(rows[b]["key"]), salt))
	for i in order.slice(0, n):
		var way: String = role_for(kind, sign, traits_of(int(rows[i]["key"])))
		var clip: String = String((REACTIONS[way] as Dictionary).get(String(rows[i]["pose"]), ""))
		if clip != "":
			out[i] = clip
	return out


## How one person takes it: a loss quietly; good news nodded at, clapped by
## the talkers, murmured over by the shy; bad news argued by the quick-tempered, murmured over by the
## talkers, closed up against by the shy, the rest shake their heads.
static func role_for(kind: String, sign: int, me: Dictionary) -> String:
	if GRIEF.has(kind):
		return "grief"
	var hot: bool = float(me["temper"]) < 0.3
	var talker: bool = float(me["social"]) > 0.55
	var shy: bool = float(me["social"]) < 0.3
	if sign > 0:
		if shy:
			return "whisper"
		return "cheer" if talker else "approve"
	if sign < 0:
		if hot:
			return "argue"
		if talker:
			return "whisper"
		return "withdraw" if shy else "headshake"
	if hot:
		return "argue"
	return "withdraw" if shy else "whisper"


## The motions of a car's reaction going on now, by body; an ended one is let go.
func _reacting(car_id: String, now: float) -> Dictionary:
	if not scenes.has(car_id):
		return {}
	var s: Dictionary = scenes[car_id]
	if now >= float(s["until"]):
		scenes.erase(car_id)
		return {}
	var out: Dictionary = {}
	for b in s["picks"]:
		if is_instance_valid(b):
			out[b] = s["picks"][b]
	return out


## A car's traces still in their days.
func _marks_of(car_id: String) -> Array:
	var day := _day()
	var kept: Array = (marks.get(car_id, []) as Array).filter(func(m): return int(m["until"]) > day)
	if kept.is_empty():
		marks.erase(car_id)
	else:
		marks[car_id] = kept
	return kept


func _day() -> int:
	return int((scene.rules.get("train", {}) as Dictionary).get("seg", 0))


## The rules changed: what happened between then and now, the biggest few.
func _on_rules() -> void:
	var found := events_between(_seen_rules, scene.rules, _day())
	found.sort_custom(func(a, b): return float(a["size"]) > float(b["size"]))
	for ev in found.slice(0, EVENTS_AT_ONCE):
		react(ev)
	_seen_rules = scene.rules.duplicate(true)


## More than this many at once is a whole new state (a load), not a moment.
const EVENTS_AT_ONCE: int = 4


## What happened between two sets of rule values, in the event form: laws
## passed or repealed (train.passed), a vote called or done, a decree, the dead
## laid in the cold car, a memorial, and for each community rations moved
## (sit[1] by RATION_STEP or more), a search party out or back, people taken in
## or gone. Read only.
static func events_between(before: Dictionary, after: Dictionary, day: int) -> Array:
	var out: Array = []
	var tb: Dictionary = before.get("train", {})
	var ta: Dictionary = after.get("train", {})
	var pb: Dictionary = tb.get("passed", {}) if tb.get("passed") is Dictionary else {}
	var pa: Dictionary = ta.get("passed", {}) if ta.get("passed") is Dictionary else {}
	for law in pa:
		if not pb.has(law):
			out.append(_event("law_passed", "", 0, 0.6, day).merged({"law": law}))
	for law in pb:
		if not pa.has(law):
			out.append(_event("law_repealed", "", 0, 0.6, day).merged({"law": law}))
	var vb: bool = bool(tb.get("voting", false))
	var va: bool = bool(ta.get("voting", false))
	if va and not vb:
		out.append(_event("vote_called", "", 0, 0.4, day))
	if vb and not va:
		out.append(_event("vote_done", "", 0, 0.5, day))
	if int(tb.get("decreeLeft", 0)) <= 0 and int(ta.get("decreeLeft", 0)) > 0:
		out.append(_event("decree", "", -1, 0.6, day))
	var dead: int = int(ta.get("stored", 0)) - int(tb.get("stored", 0))
	if dead > 0:
		out.append(_event("dead_stored", "", -1, clampf(0.3 + 0.2 * dead, 0.0, 1.0), day))
	if bool((after.get("view", {}) as Dictionary).get("memorial", false)) and not bool((before.get("view", {}) as Dictionary).get("memorial", false)):
		out.append(_event("memorial", "", -1, 0.8, day))
	var cb: Dictionary = before.get("comms", {})
	var ca: Dictionary = after.get("comms", {})
	for id in ca:
		if not (cb.get(id) is Dictionary) or not (ca[id] is Dictionary):
			continue
		var b: Dictionary = cb[id]
		var a: Dictionary = ca[id]
		var sb: Array = b.get("sit", [])
		var sa: Array = a.get("sit", [])
		if sb.size() > 1 and sa.size() > 1:
			var moved: float = float(sa[1]) - float(sb[1])
			if absf(moved) >= RATION_STEP:
				out.append(_event("ration", id, int(signf(moved)), clampf(absf(moved) / 40.0, 0.2, 1.0), day))
		var away_b: int = int(b.get("away", 0))
		var away_a: int = int(a.get("away", 0))
		if away_b <= 0 and away_a > 0:
			out.append(_event("party_out", id, 0, 0.4, day))
		elif away_b > 0 and away_a <= 0:
			out.append(_event("party_back", id, 1, 0.5, day))
		var grew: int = int(a.get("pop", 0)) - int(b.get("pop", 0))
		if grew > 0:
			out.append(_event("taken_in", id, 0, clampf(float(grew) / 20.0, 0.2, 1.0), day))
		elif grew < 0 and away_a - away_b < -grew and dead <= 0:
			out.append(_event("let_go", id, -1, clampf(float(-grew) / 20.0, 0.2, 1.0), day))
	return out


static func _event(kind: String, comm: String, sign: int, size: float, day: int) -> Dictionary:
	return {"kind": kind, "car": "", "comm": comm, "sign": sign, "size": size, "day": day}


## How cold a car is for the people in it, 0 (60 and warmer) .. 1 (20 and colder).
static func cold_of(s: Dictionary) -> float:
	return clampf((60.0 - float(s["warmth"])) / 40.0, 0.0, 1.0)


## How much one person trembles in a car (0 .. SHIVER_MAX): only the ones the
## cold gets to (their own `cold` under the car's), more the further under.
static func shiver_for(s: Dictionary, me: Dictionary) -> float:
	var felt: float = cold_of(s) - float(me.get("cold", 1.0))
	if felt <= 0.0:
		return 0.0
	return clampf(0.12 + felt * 0.6, 0.0, SHIVER_MAX)


## The tremble drawn on one person: what the car and their motion call for,
## reached at their own pace (their `react`), so they do not all start at once.
func _shiver_of(rec: Dictionary, s: Dictionary, key: int, clip: String, covered: bool, dt: float) -> float:
	var me := traits_of(key)
	var target: float = shiver_for(s, me) * float(SHIVER_DAMP.get(clip, 1.0)) * (UNDER_BLANKET if covered else 1.0)
	if not rec.has("shiver"):
		rec["shiver"] = target
	else:
		rec["shiver"] = lerpf(float(rec["shiver"]), target, 1.0 - exp(-dt / float(me["react"])))
	return float(rec["shiver"])


## A car's people in seat order as blanket_groups reads them: where each sits,
## whether they sit on the bench with nothing else to do, how soon the cold gets to them.
func _bench_rows(ordered: Array, s: Dictionary, now: float) -> Array:
	var rows: Array = []
	for b in ordered:
		var life: Dictionary = scene.life.actors.get(b.get_instance_id(), {})
		var free: bool = b.visible and String(b.pose) == "sit" and int(b.seat) < 0 \
			and _forced(b, s, String(life.get("activity", "")), now) in ["", "t_sit_huddle"]
		rows.append({"x": b.global_position.x, "free": free, "cold": float(traits_of(absi(b.get_instance_id()))["cold"])})
	return rows


## Who shares a blanket on a cold bench: neighbours side by side (NEIGHBOUR
## apart in seat order), each one the cold gets to, two or three a blanket and
## BLANKETS_A_CAR of them a car. Indices into the rows.
static func blanket_groups(rows: Array, s: Dictionary) -> Array:
	var groups: Array = []
	if not bool(s.get("cold", false)):
		return groups
	var cold_n := cold_of(s)
	var run: Array = []
	var last_x := -1000.0
	for i in rows.size() + 1:
		var ok: bool = i < rows.size() and bool(rows[i]["free"]) and float(rows[i]["cold"]) < cold_n
		if ok and not run.is_empty() and float(rows[i]["x"]) - last_x >= NEIGHBOUR:
			_split_run(run, groups)
			run = []
		if ok:
			run.append(i)
			last_x = float(rows[i]["x"])
		elif not run.is_empty():
			_split_run(run, groups)
			run = []
	return groups.slice(0, BLANKETS_A_CAR)


## Two or three a blanket: a run of four is two pairs, of five a three and a pair.
static func _split_run(run: Array, groups: Array) -> void:
	var at := 0
	var left := run.size()
	while left >= 2:
		var take := 3 if left == 3 or left >= 5 else 2
		groups.append(run.slice(at, at + take))
		at += take
		left -= take


## Draw the blankets: each wanted one is pulled up once all under it are seen
## hunched, and one no longer wanted (warmer, or someone got up) let down and gone.
func _cover(wanted: Array, dt: float) -> void:
	var seen: Dictionary = {}
	for members in wanted:
		var key: int = absi((members[0] as Node3D).get_instance_id())
		var rec: Dictionary = covers.get(key, {"k": 0.0})
		rec["under"] = members
		rec["up"] = members.all(func(m): return String(drawn.get(m, "")) == "t_sit_huddle")
		covers[key] = rec
		seen[key] = true
	var counts := [0, 0]
	for key in covers.keys():
		var rec: Dictionary = covers[key]
		var members: Array = rec["under"]
		if not members.all(func(m): return is_instance_valid(m)):
			covers.erase(key)
			continue
		var up: bool = seen.has(key) and bool(rec["up"])
		rec["k"] = move_toward(float(rec["k"]), 1.0 if up else 0.0, dt / BLANKET_UP)
		if float(rec["k"]) <= 0.0:
			if not seen.has(key):
				covers.erase(key)
			continue
		var size: int = members.size() - 2
		if counts[size] >= BLANKETS:
			continue
		var mm: MultiMesh = (blankets[size] as MultiMeshInstance3D).multimesh
		mm.set_instance_transform(counts[size], cover_place(members, float(rec["k"])))
		mm.set_instance_color(counts[size], BLANKET_TINTS[key % BLANKET_TINTS.size()])
		counts[size] += 1
	for n in blankets.size():
		var draw: MultiMeshInstance3D = blankets[n]
		draw.multimesh.visible_instance_count = counts[n]
		draw.visible = counts[n] > 0          # no draw call while no one is under one


## Where one blanket lies: over the middle of those under it, stretched to how
## far apart they sit, low in the lap at k 0 and over the shoulders at k 1.
func cover_place(members: Array, k: float) -> Transform3D:
	var first: Transform3D = place_of(members[0], "t_sit_huddle", {})
	var last: Transform3D = place_of(members[members.size() - 1], "t_sit_huddle", {})
	var span: float = first.origin.distance_to(last.origin) / float(members.size() - 1)
	var e: float = k * k * (3.0 - 2.0 * k)
	var basis := first.basis * Basis.from_scale(Vector3(span / BLANKET_STEP, lerpf(BLANKET_LOW, 1.0, e), lerpf(0.85, 1.0, e)))
	return Transform3D(basis, (first.origin + last.origin) * 0.5)


func _blanket_draw(n: int) -> MultiMeshInstance3D:
	var draw := MultiMeshInstance3D.new()
	draw.name = "Blankets%d" % n
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blanket_mesh(n)
	mm.instance_count = BLANKETS
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-20, -3, -5), Vector3(400, 10, 10))
	draw.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = false
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	draw.material_override = mat
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(draw)
	return draw


## The cloth across the car (z, y), from the hem behind the backs over the
## shoulders to the hem over the shins, measured round the train bake's hunched
## sitting body (t_sit_huddle: shoulders about 0.95 m up, head bowed forward
## over the knees, arms round them as far as 0.6 m in front).
const BLANKET_PROFILE: Array = [
	Vector2(-0.55, 0.48), Vector2(-0.52, 0.70), Vector2(-0.46, 0.88), Vector2(-0.34, 0.98),
	Vector2(-0.16, 1.02), Vector2(0.04, 1.02), Vector2(0.24, 0.96), Vector2(0.45, 0.86),
	Vector2(0.65, 0.76), Vector2(0.70, 0.60), Vector2(0.66, 0.44), Vector2(0.58, 0.30),
]
## How much each point is the top of the cloth (which sinks round a head and between two).
const BLANKET_TOP: Array = [0.0, 0.0, 0.3, 0.7, 1.0, 1.0, 0.8, 0.4, 0.0, 0.0, 0.0, 0.0]
const BLANKET_WOOL := Color(0.40, 0.38, 0.35)
const BLANKET_STRIPE := Color(0.16, 0.15, 0.14)


## One blanket for `n` side by side, `BLANKET_STEP` apart: the cloth sinks
## round each head (it lies on the shoulders, the head above it) and a little
## between two, hangs at the ends, falls in folds to a wavy hem, and has a dark
## band near each hem. Linear vertex colours, tinted per blanket.
static func blanket_mesh(n: int) -> ArrayMesh:
	var centres: Array = []
	for k in n:
		centres.append(BLANKET_STEP * (float(k) - float(n - 1) * 0.5))
	var half: float = BLANKET_STEP * float(n - 1) * 0.5 + BLANKET_EDGE
	var cols: int = int(ceil(half * 2.0 / 0.08))
	# The profile, three rows a stretch, with its top weight and its length from each hem.
	var prof: Array = []
	for i in BLANKET_PROFILE.size() - 1:
		for j in 3:
			var f: float = float(j) / 3.0
			prof.append([(BLANKET_PROFILE[i] as Vector2).lerp(BLANKET_PROFILE[i + 1], f), lerpf(BLANKET_TOP[i], BLANKET_TOP[i + 1], f)])
	prof.append([BLANKET_PROFILE[BLANKET_PROFILE.size() - 1], 0.0])
	var along: Array = [0.0]
	for r in range(1, prof.size()):
		along.append(float(along[r - 1]) + (prof[r][0] as Vector2).distance_to(prof[r - 1][0]))
	var total: float = along[along.size() - 1]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for ci in cols + 1:
		var x: float = -half + 2.0 * half * float(ci) / float(cols)
		var near: float = 99.0
		for cx in centres:
			near = minf(near, absf(x - float(cx)))
		var head: float = 1.0 - smoothstep(0.10, 0.20, near)
		var gap: float = smoothstep(0.28, BLANKET_STEP * 0.5, near) if absf(x) < float(centres[n - 1]) else 0.0
		var end: float = smoothstep(half - 0.3, half, absf(x))
		# Folds that fall from the shoulders, deeper toward the hem, darker in their hollows.
		var wave: float = 0.7 * sin(x * 21.0 + 1.3) + 0.3 * sin(x * 9.0 + 0.4)
		var fold: float = 0.03 * wave
		for r in prof.size():
			var p: Vector2 = prof[r][0]
			var top: float = prof[r][1]
			var hem: float = 1.0 - top
			var z: float = p.x * (1.0 - 0.25 * end) + fold * hem * signf(p.x)
			var y: float = p.y - top * (0.13 * head + 0.08 * gap + 0.14 * end) - 0.08 * end
			if r == 0 or r == prof.size() - 1:
				y += 0.035 * sin(x * 13.0 + float(r)) - 0.03 * wave
			var from_hem: float = minf(float(along[r]), total - float(along[r]))
			var band: float = 1.0 - smoothstep(0.03, 0.06, absf(from_hem - 0.12))
			var hollow: float = 1.0 - 0.22 * hem * (0.5 - 0.5 * wave)
			st.set_color(BLANKET_WOOL.lerp(BLANKET_STRIPE, band) * hollow * (0.95 + 0.05 * sin(x * 7.0 + float(r))))
			st.add_vertex(Vector3(x, y, z))
	var rows: int = prof.size()
	for ci in cols:
		for r in rows - 1:
			var a: int = ci * rows + r
			var b: int = a + rows
			st.add_index(a)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(b + 1)
	st.generate_normals()
	return st.commit()


## The breath of a freezing car: one small emitter (fx/smoke.gd "breath") at
## the mouths of up to BREATH_HEADS who feel the cold, looked at every
## BREATH_EVERY seconds; a puff about every 3.5 s a head.
func _breathe(c: Dictionary, heads: Array, now: float) -> void:
	var id: String = c["id"]
	if not breath.has(id):
		if heads.is_empty() or breath.size() >= BREATH_CARS:
			return
		var made := Smoke.build("breath")
		if made == null:
			return
		made.top_level = true
		add_child(made)
		made.global_transform = Transform3D.IDENTITY
		breath[id] = {"p": made, "t": -BREATH_EVERY, "key": "", "heads": 0}
	var rec: Dictionary = breath[id]
	var p: GPUParticles3D = rec["p"]
	if now - float(rec["t"]) < BREATH_EVERY:
		return
	rec["t"] = now
	p.emitting = not heads.is_empty()
	rec["heads"] = heads.size()
	if heads.is_empty():
		return
	var key := var_to_str(heads.map(func(h: Vector3) -> Vector3i: return Vector3i((h * 20.0).round())))
	if key == String(rec["key"]):
		return
	rec["key"] = key
	var image := Image.create(heads.size(), 1, false, Image.FORMAT_RGBF)
	var box := AABB(heads[0], Vector3.ZERO)
	for i in heads.size():
		var h: Vector3 = heads[i]
		image.set_pixel(i, 0, Color(h.x, h.y, h.z))
		box = box.expand(h)
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	pm.emission_point_texture = ImageTexture.create_from_image(image)
	pm.emission_point_count = heads.size()
	p.amount_ratio = clampf(float(heads.size()) * BREATH_PER_HEAD / float(p.amount), 1.0 / float(p.amount), 1.0)
	p.visibility_aabb = box.grow(1.0)


## Where the baked body stands for a body of the scene: its place and facing,
## the seat brought over the bench, the lying turned along the bunk.
func place_of(b, clip: String, _state: Dictionary) -> Transform3D:
	var yaw: float = b.global_rotation.y
	var at: Vector3 = b.global_position
	var basis := Basis(Vector3.UP, yaw)
	match clip:
		"t_sit", "t_sit_talk", "t_sit_huddle", "t_sit_doze", "t_eat", "t_sit_nod", "t_sit_no", "t_sit_fold", "t_sit_clap", "t_gun_clean", "t_handwork":
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
