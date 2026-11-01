extends Node3D
## All the dead on one stop. Data lives in plain dictionaries; drawing is one
## VAT MultiMesh per look. States: wander, investigate, chase, attack, grab, climb,
## downed, dead, frozen, waking, rising (corpse about to stand up), horde.
## Kinds (zombies.md): "dead" 망자, "clothed" 껴입은 자, "fresh" 갓 일어난 자,
## "frozen" 얼어붙은 자 (becomes "dead" when it wakes).

const FieldGrid = preload("res://game/world/field_grid.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const GrabRules = preload("res://game/sim/grab_rules.gd")
const SenseRules = preload("res://game/sim/sense_rules.gd")
const SmellRules = preload("res://game/sim/smell_rules.gd")
const DeadPose = preload("res://game/actors/dead_pose.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const DeadCast = preload("res://game/actors/dead_cast.gd")
const Motion = preload("res://game/sim/motion.gd")
const LungerRules = preload("res://game/sim/lunger_rules.gd")
const HordeMix = preload("res://game/sim/horde_mix.gd")
const DeadSeparation = preload("res://game/sim/dead_separation.gd")
const EatRules = preload("res://game/sim/eat_rules.gd")
const BuildingRules = preload("res://game/sim/building_rules.gd")
const SEPARATION_EXCLUDED: Array[String] = ["downed", "rising", "waking", "frozen", "climb", "grab", "dead", "corpse", "dash", "eat"]

const MAX_DRAW: int = 160
const SIGHT_FADE_IN: float = 0.18
const SIGHT_FADE_OUT: float = 0.2
const FRUSTUM_PAD: float = 1.2
const SIGHT: float = 9.0
const SPEED_WANDER: float = 0.45
const SPEED_SHAMBLE: float = 1.05
const SPEED_HURRY: float = 1.35
const SPEED_FRESH: float = 2.7
const SPEED_CRAWL: float = 0.35
const ATTACK_RANGE: float = 0.85
const WINDUP: float = 0.8
# A crawler's bite lands later in its lunge than a standing one's (the reference
# game: at 0.5 of it, not 0.2; decision 425): its wind-up is that much longer.
const WINDUP_CRAWL: float = WINDUP * 0.5 / 0.2
# One just seen is not bitten at once (the reference game's grace): the dead
# come on at it but bite only once they have had it in sight this long.
const SEEN_GRACE: float = 0.5
const GET_UP: Vector2 = Vector2(5.0, 9.0)
const RISE_TIME: float = 30.0
## What a fallen one may have on it (user 2026-10-11: now and then, small
## things), by kind and, for the padded ones, by where they stood: the tables
## are in loot_tables.gd (loot spec v1), the dead's the values of before.
## Rolled once, the first time it goes down; knocking the same one down again
## rolls nothing.
const LootRules = preload("res://game/sim/loot_rules.gd")
const PropModels = preload("res://game/world/prop_models.gd")
## 몸에 박힌 무기(결정 423 카드 2, 대조 P09): 지도에 처음 서 있던 망자 가운데 드물게 등에 도끼가
## 박혀 있다. 눈에 띄는 그림 하나와 확정 물건(쓰러뜨려 뒤지면 그 도끼)이 같이 온다.
const EMBED_CHANCE: float = 0.03
const EMBED_MAX: int = 2
const EMBED_TOOL: String = "axe"
const EMBED_MODEL: String = "res://models/weapons/axe.glb"
## 몸 기준 자리(앞이 +Z): 도끼 머리(모델 +Z 끝)가 등에 들고, 자루가 뒤로 조금 위로 나온다.
const EMBED_AT := Transform3D(Basis(Vector3.RIGHT, 0.45), Vector3(0.06, 1.2, -0.42))
## 쓰러지면 도끼는 몸 곁 바닥에 떨어져 있다(구운 몸은 동작으로 누워 몸 기울기를 따라갈 수 없다).
const EMBED_DROP_AT := Vector3(0.5, 0.03, -0.35)
const EMBED_DROP_TURN: float = 0.6
const FRESH_STIFFEN: float = 240.0
const WAKE_TIME: float = 2.0
const NEAR: float = 32.0
const FEEL: float = 1.8          # all-round sense at arm's reach
const CONE_COS: float = 0.5      # 120 degree forward sight cone
const HERD: float = 8.0
const MEMORY: float = 8.0        # seconds a lost target stays worth chasing (field_unified 11, 'normal')
const SEARCH_TIME: float = 4.0   # look around the last seen spot, two corners, then wander
const SHOVED_TIME: float = 0.28  # a shoved body is seen stumbling back this long (it is already there for the rules)
const NO_WAY_WAIT: float = 2.5   # no way through to the target: look for one again this much later
const KINDS: Array[String] = ["dead", "clothed", "fresh", "frozen"]
const TINTS: Dictionary = {"dead": Color(0.5, 0.52, 0.47), "clothed": Color(0.36, 0.38, 0.45), "fresh": Color(0.62, 0.45, 0.42), "frozen": Color(0.86, 0.9, 0.95), "corpse": Color(0.3, 0.3, 0.29)}

var game  # field_game.gd
var list: Array[Dictionary] = []
var next_id: int = 1
var loot_rng := RandomNumberGenerator.new()   # its own, so a body's pockets do not shift the fight's dice
var lunge_rng := RandomNumberGenerator.new()  # its own, so who lunges does not shift them either
var embed_rng := RandomNumberGenerator.new()  # its own, so who has an axe in the back shifts nothing else
var embedded_draw: MultiMeshInstance3D        # the axes in backs; null without the model
var lunger_share: float = 0.0  # Act progress, or the forced share (decisions 383, 387, 134).
var draw: Dictionary = {}     # look -> MultiMeshInstance3D (the first body's)
var draws: Array = []         # body (dead_cast.gd) -> look -> MultiMeshInstance3D; {} for one not in the build
var body_rounds: Array = []   # body -> its walks' rounds (dead_body.gd rounds_of)
var _pose_rounds: Array[Dictionary] = []   # assigned body -> stride, fixed before appearance reads
var bodies_to_read: Array[String] = []   # bodies not read in yet: one a frame (render)
var bodies_planned: int = 1
var wear_draws: Array = []    # body -> garment (dead_cast.gd SHELLS) -> MultiMeshInstance3D, null for one it has none of; read when first worn
var _garment_reads: int = 0   # garments still to be read in this frame
var garments_drawn: Dictionary = {}   # garment multimesh -> the ids of the dead drawn in it this frame, in order (the instances' data is the renderer's)
var _drawn_worn: Dictionary = {}   # id -> [worn_at, kind, what it has on] for one drawn before worn_of is asked (drawn_worn)
var drawn_count: int = 0
var drawn_at: Dictionary = {}          # id -> world place actually drawn this frame
var _submitted_last: Dictionary = {}   # snapshot of drawn_at; membership owns next frame's cap priority
var _submitted_markers: Dictionary = {} # id -> visibility sent to the rising marker this frame
var _shown: Dictionary = {}            # id -> sight visibility; never part of a saved body
var _last_seen_draw: Dictionary = {}   # id -> last in-sight appearance, before packing visibility
var _held_frames: Dictionary = {}      # id -> consecutive in-sight frames waiting for its appearance
var _rendered_once: bool = false
var appearance_swaps: int = 0
var cap_drops: int = 0                # previous frame's submitted ids displaced by a full body/look
var held_frames_max: int = 0
var vat: Dictionary
var baked: bool = false       # the dead are a baked body (dead_body.gd), not the boxes
var markers: MultiMeshInstance3D
var _people: Array = []
var _food: Array = []                 # the bodies of the living that can be eaten, this update (EatRules)
var _sense_cells: Dictionary = {}
var _sense_cells_ready: bool = false
var _sense_padding: float = 0.0


func setup(field_game, vat_assets: Dictionary) -> void:
	game = field_game
	loot_rng.seed = hash(int(game.opts.get("seed", 0))) + 62
	lunge_rng.seed = hash(int(game.opts.get("seed", 0))) + 63
	embed_rng.seed = hash(int(game.opts.get("seed", 0))) + 64
	# Forced on never reads the act; otherwise the act's progress sets the share.
	if bool(game.opts.get(LungerRules.OPTION, false)):
		lunger_share = LungerRules.SHARE
	else:
		lunger_share = float(HordeMix.of(String(game.opts.get("act", "prologue")), act_progress_of(game.opts))["lunger_share"])
	var body := DeadBody.assets()
	baked = not body.is_empty()
	vat = body if baked else vat_assets
	draw = _draws_of(vat)
	draws = [draw]
	wear_draws = [{}]
	body_rounds = [DeadBody.rounds]
	bodies_to_read = DeadCast.others() if baked else ([] as Array[String])
	bodies_planned = 1 + bodies_to_read.size()
	# Pose clocks are saved: their strides cannot depend on mesh/VAT read timing.
	_pose_rounds = [body_rounds[0]]
	for dir: String in bodies_to_read:
		var path: String = dir.path_join("clips.json")
		var info: Variant = null
		if FileAccess.file_exists(path):
			info = JSON.parse_string(FileAccess.get_file_as_string(path))
		var stride: Dictionary = body_rounds[0]
		if info is Dictionary and DeadCast.lined_up(info, vat):
			stride = DeadBody.rounds_of(info)
		_pose_rounds.append(stride)
	# Rising markers above corpses that will stand up.
	markers = MultiMeshInstance3D.new()
	var mm2 := MultiMesh.new()
	mm2.transform_format = MultiMesh.TRANSFORM_3D
	mm2.use_colors = true
	var ring := TorusMesh.new()
	ring.inner_radius = 0.35
	ring.outer_radius = 0.45
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	rm.vertex_color_use_as_albedo = true
	rm.albedo_color = Color(0.78, 0.76, 0.72)   # off-white: no red in the field (fx colour rule)
	ring.material = rm
	mm2.mesh = ring
	mm2.instance_count = 32
	mm2.visible_instance_count = 0
	mm2.custom_aabb = AABB(Vector3(-5, -5, -5), Vector3(185, 16, 115))
	markers.multimesh = mm2
	add_child(markers)
	var axe: Dictionary = PropModels.batch_meshes(EMBED_MODEL) if ResourceLoader.exists(EMBED_MODEL) else {}
	if axe.has(0):
		embedded_draw = MultiMeshInstance3D.new()
		var mm3 := MultiMesh.new()
		mm3.transform_format = MultiMesh.TRANSFORM_3D
		mm3.mesh = axe[0]
		mm3.instance_count = EMBED_MAX
		mm3.visible_instance_count = 0
		mm3.custom_aabb = AABB(Vector3(-5, -5, -5), Vector3(185, 16, 115))
		embedded_draw.multimesh = mm3
		add_child(embedded_draw)


## The act's progress as a number: a missing, null or non-numeric value reads as
## the act's start (decisions 383, 387, 134).
static func act_progress_of(opts: Dictionary) -> float:
	var value: Variant = opts.get("act_progress", 0.0)
	if value is float or value is int:
		return float(value)
	if value is String and (value as String).is_valid_float():
		return (value as String).to_float()
	return 0.0


func spawn(kind: String, at: Vector3, opts: Dictionary = {}) -> Dictionary:
	var z := {
		"id": next_id, "kind": kind, "pos": _floor_y(at), "state": "frozen" if kind == "frozen" else "wander",
		"home": _floor_y(at), "target": _floor_y(at), "path": PackedVector3Array(), "path_t": 0.0,
		"angle": game.rng.randf() * TAU, "phase": game.rng.randf(), "t": 0.0, "linger": 0.0,
		"victim": null, "windup": 0.0, "cooldown": 0.0, "grab_t": 0.0, "crawl": false,
		"horde": int(opts.get("horde", -1)), "seen_t": 0.0, "seen_at": {}, "last_seen": Vector3.ZERO, "age": 0.0,
		"rise_t": 0.0, "name": String(opts.get("name", "")), "bang_t": 0.0, "depth": float(opts.get("depth", 1.0)),
		"stun": 0.0, "speed": 0.0, "stander": game.rng.randf() < 0.55, "search_left": 0, "sense_t": 0.0, "smell_lock": 0.0,
	}
	next_id += 1
	# Not the frozen, and not those sent in with a horde (a horde's runners are another rule).
	# Keep the roll even for a drifter; zero share rolls nothing (decisions 134, 250, 387).
	if lunger_share > 0.0 and kind != "frozen" and not opts.has("target"):
		z["lunger"] = LungerRules.picks(lunge_rng.randf(), z["stander"], lunger_share)
	if opts.has("target"):
		z["state"] = "horde"
		z["target"] = opts["target"]
	list.append(z)
	_sense_cells_ready = false
	return z


## Bodies stand on a floor: y snaps to the level it is on.
func _floor_y(at: Vector3) -> Vector3:
	return Vector3(at.x, game.level_y(game.level_of(at)), at.z)


## A dead person becomes a corpse that stands up as "fresh" after RISE_TIME.
func add_rising(at: Vector3, who_name: String) -> Dictionary:
	var z := spawn("fresh", at, {"name": who_name})
	z["state"] = "rising"
	z["rise_t"] = RISE_TIME
	# A risen person stands. Keep this second roll after spawn's (decisions 134, 250, 387).
	z["lunger"] = lunger_share > 0.0 and LungerRules.picks(lunge_rng.randf(), true, lunger_share)
	# A person's things fall to the ground; a raider's are put on it (set_loot).
	z["loot"] = []
	z["searched"] = true
	return z


## Lying there with pockets nobody has been through yet. Standing ones and
## those already searched are not.
## How long going through this one's pockets takes: its kind and where it stood
## (loot spec v1 2.3, user decision 407 B5). A plain body three seconds.
func search_time(z: Dictionary) -> float:
	var place := LootRules.place_at(game.data.get("buildings", []), FieldGrid.cell_of(z["home"]))
	return LootRules.body_search_time(String(z["kind"]), place)


func lootable(z: Dictionary) -> bool:
	return not z.is_empty() and z["state"] in ["dead", "downed", "rising"] and z.has("loot") and not z.get("searched", false)


func set_loot(z: Dictionary, loot: Array) -> void:
	z["loot"] = loot
	z["searched"] = false


## What one of the dead has on (decision 434, loot_tables.gd WEAR_*): rolled
## the first time it is asked for or drawn, by the place it keeps to then (its
## home, kept as worn_at, which a save keeps), on dice of its own from the run's
## seed and the body's number, so whenever that is (a round on a vest, a hand
## on a coat) it comes out the same and moves no other dice, and led off
## somewhere else it keeps what it was seen in. A risen one of ours has what it
## wore (field_game.gd).
func worn_of(z: Dictionary) -> Dictionary:
	if not z.has("worn"):
		var kept: Array = _drawn_worn.get(int(z["id"]), [])
		z["worn"] = kept[2] if _kept_for(kept, z) else _roll_worn(z)
		_drawn_worn.erase(int(z["id"]))
	return z["worn"]


func _roll_worn(z: Dictionary) -> Dictionary:
	if not z.has("worn_at"):
		z["worn_at"] = z["home"]
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:worn:%d" % [int(game.opts.get("seed", 0)), int(z["id"])]).hash()
	var place := LootRules.wear_place_at(game.data.get("buildings", []), FieldGrid.cell_of(z["worn_at"]))
	return LootRules.wear_roll(String(z["kind"]), place, rng)


## What one of the dead has on as it is drawn (render): worn_of's once that is
## asked for, till then the same roll kept here by its number (with the place
## and kind it was rolled by), so drawing it puts only where it kept to in its
## record, not its clothes (a save keeps what was asked for).
func drawn_worn(z: Dictionary) -> Dictionary:
	if z.has("worn"):
		return z["worn"]
	var kept: Array = _drawn_worn.get(int(z["id"]), [])
	if not _kept_for(kept, z):
		var worn := _roll_worn(z)
		kept = [z["worn_at"], z["kind"], worn]
		_drawn_worn[int(z["id"])] = kept
	return kept[2]


func _kept_for(kept: Array, z: Dictionary) -> bool:
	return not kept.is_empty() and z.has("worn_at") and kept[0] == z["worn_at"] and kept[1] == z["kind"]


## Lying there with something still on it to take off.
func strippable(z: Dictionary) -> bool:
	return not z.is_empty() and z["state"] in ["dead", "downed", "rising"] and not worn_of(z).is_empty()


func _roll_loot(z: Dictionary) -> void:
	if z.has("loot"):
		return
	var place := LootRules.place_at(game.data.get("buildings", []), FieldGrid.cell_of(z["home"]))
	var loot: Array = []
	for entry: Dictionary in LootRules.body_roll(String(z["kind"]), place, int(z.get("horde", -1)) >= 0, loot_rng):
		loot.append(LootRules.to_pocket(entry))
	if z.has("embedded"):
		loot.append(LootRules.to_pocket({"tool": z["embedded"]}))
	# What this one was given to carry when the stop was made (a building's key,
	# a note; decision 423 P12 and card 10): always there, drawing no dice.
	for id in z.get("carry", []):
		loot.append({"id": String(id), "n": 1})
	z["loot"] = loot


## The dead first put on the map (not a horde's, not the frozen): now and then
## one has an axe in its back, at most EMBED_MAX a stop. Returns how many.
func embed_weapons() -> int:
	var n := 0
	for z in list:
		if n >= EMBED_MAX:
			break
		if z["kind"] in ["dead", "clothed"] and int(z["horde"]) < 0 and z["state"] == "wander" and embed_rng.randf() < EMBED_CHANCE:
			z["embedded"] = EMBED_TOOL
			n += 1
	return n


## Drawn while it is still in the body (its pockets not yet gone through).
func shows_embedded(z: Dictionary) -> bool:
	return z.has("embedded") and not bool(z.get("searched", false))


func alive_count() -> int:
	var n := 0
	for z in list:
		if z["state"] != "dead":
			n += 1
	return n


func count_where(state: String) -> int:
	var n := 0
	for z in list:
		if z["state"] == state:
			n += 1
	return n


func active(z: Dictionary) -> bool:
	return z["state"] != "dead" and z["state"] != "rising" and z["state"] != "frozen"


func threat(z: Dictionary) -> bool:
	return z["state"] != "dead" and z["state"] != "rising"


## Nearest dead within radius matching an optional state filter.
func nearest(at: Vector3, radius: float, include_downed: bool = true, include_frozen: bool = true) -> Dictionary:
	var best: Dictionary = {}
	var best_d := radius
	for z in list:
		if z["state"] == "dead" or z["state"] == "rising":
			continue
		if not include_downed and z["state"] == "downed":
			continue
		if not include_frozen and z["state"] == "frozen":
			continue
		var d: float = at.distance_to(z["pos"])
		if d < best_d:
			best_d = d
			best = z
	return best


func in_radius(at: Vector3, radius: float) -> Array:
	var out: Array = []
	for z in list:
		if threat(z) and at.distance_to(z["pos"]) <= radius:
			out.append(z)
	return out


func find(id: int) -> Dictionary:
	for z in list:
		if z["id"] == id:
			return z
	return {}


## Sound reaches the dead (body_injury 8장). Frozen ones wake on NORMAL or louder.
## wind (weather.gd, optional) stretches the radius downwind (excessive blood, 8.1).
func hear(at: Vector3, level: int, radius: float, wind = null) -> int:
	var reacted := 0
	for z in list:
		if can_hear(z, at, radius, wind) and hear_one(z, at, level):
			reacted += 1
	return reacted


## Shared hearing gate; checking it never changes a body (decision 494).
func can_hear(z: Dictionary, at: Vector3, radius: float, wind = null) -> bool:
	if z["state"] in ["dead", "rising", "downed", "grab", "attack", "climb", "tell", "waking", "chase"]:
		return false
	var reach := radius
	if wind != null:
		reach *= float(wind.downwind(at, z["pos"]))
	# Every floor between halves what comes through it.
	var floors: int = absi(game.level_of(at) - game.level_of(z["pos"]))
	if floors > 0:
		reach *= pow(0.5, floors)
	return at.distance_to(z["pos"]) <= reach


## React only after a sound passes its hearing gate.
func hear_one(z: Dictionary, at: Vector3, level: int) -> bool:
	var state: String = z["state"]
	if state == "frozen":
		if level >= SimNoise.Level.NORMAL:
			wake(z)
			return true
		return false
	if level == SimNoise.Level.QUIET:
		z["angle"] = atan2(at.x - z["pos"].x, at.z - z["pos"].z)
		return false
	# A fainter sound does not pull one already walking to a louder one.
	if (state == "investigate" or state == "horde") and level < int(z.get("clue", 0)) and z["pos"].distance_to(z["target"]) > 1.2:
		return false
	# Idle dead first turn toward the noise, then set off (no instant lock-on).
	if state == "wander" or state == "search" or state == "eat":
		z["turn_t"] = game.rng.randf_range(0.4, 0.9)
	z["clue"] = level
	z["clue_kind"] = "sound"
	z["clue_left"] = SimNoise.LINGER[level]
	z["state"] = "investigate"
	z["target"] = at
	z["linger"] = SimNoise.LINGER[level]
	z["speed"] = SPEED_HURRY if level >= SimNoise.Level.LOUD else SPEED_SHAMBLE
	z["path_t"] = 0.0
	return true


## Excessive blood (body_injury 8.1): a smell event, separate from sound. The
## dead within reach walk to the spot it came from (not to where the bleeder
## is now). Frozen ones do not wake to it; silencers and quiet steps do not cut it.
func smell(at: Vector3, radius: float) -> int:
	var reacted := 0
	for z in list:
		var state: String = z["state"]
		if state in ["dead", "rising", "downed", "grab", "attack", "frozen", "waking", "chase", "climb", "tell", "eat"]:
			continue
		var reach := radius * float(game.weather.scent_mult(at, z["pos"]))
		if at.distance_to(z["pos"]) > reach:
			continue
		if state == "investigate" and int(z.get("clue", 0)) > SimNoise.Level.NORMAL and z["pos"].distance_to(z["target"]) > 1.2:
			continue
		if state == "wander" or state == "search":
			z["turn_t"] = game.rng.randf_range(0.4, 0.9)
		z["clue"] = SimNoise.Level.NORMAL
		z["clue_kind"] = "scent"
		z["state"] = "investigate"
		z["target"] = at
		z["linger"] = SmellRules.LINGER
		z["speed"] = SPEED_SHAMBLE
		z["path_t"] = 0.0
		reacted += 1
	return reacted


## It comes up out of a hole where it stands: "lid" a street manhole, "culvert"
## a culvert's mouth. Until the motion's time is over it does nothing else (it
## does not walk, hear or bite); then it is an ordinary wanderer.
func start_climb(z: Dictionary, way: String = "lid") -> void:
	z["state"] = "climb"
	z["climb_at"] = z["age"]
	z["climb_way"] = way


func wake(z: Dictionary) -> void:
	if z["state"] != "frozen":
		return
	z["state"] = "waking"
	z["t"] = WAKE_TIME
	game.on_frozen_wake(z)


func update(delta: float) -> void:
	# Remember exclusions before timers expire or a body gets up this tick.
	var separation_skip := _separation_exclusions()
	var people: Array = game.people_alive()
	_people = people
	_food = _edible_bodies()
	# Every eater's time goes on its body first (결정 441 (3)): a body eaten up this tick is
	# no food any more, and all who ate at it go off by the usual way up.
	for eater in list:
		if eater["state"] != "eat":
			continue
		var body = _food_of(eater)
		if body != null:
			var eaten: float = float(body.get_meta(EatRules.EATEN_META, 0.0))
			body.set_meta(EatRules.EATEN_META, minf(EatRules.EAT_TOTAL, eaten + delta))
	_food = _edible_bodies()
	_sense_cells_ready = false
	_sense_padding = LungerRules.DASH_SPEED * maxf(delta, 0.0)
	for z in list:
		z["age"] += delta
		z["cooldown"] = maxf(0.0, z["cooldown"] - delta)
		z["stun"] = maxf(0.0, z["stun"] - delta)
		if z.has("shoved_t"):
			z["shoved_t"] = maxf(0.0, float(z["shoved_t"]) - delta)
		if z.has("fall_in"):
			# Shoved over, it reels first (release): now it goes down, unless
			# it was killed or knocked down some other way meanwhile.
			z["fall_in"] = float(z["fall_in"]) - delta
			if z["fall_in"] <= 0.0:
				z.erase("fall_in")
				if z["state"] == "chase":
					knock_down(z)
		if z.has("dash_t"):
			_run_down(z, delta)
		match z["state"]:
			"dead", "frozen":
				continue
			"rising":
				z["rise_t"] -= delta
				if z["rise_t"] <= 0.0:
					z["state"] = "wander"
					z["home"] = z["pos"]
					game.on_risen(z)
				continue
			"waking":
				z["t"] -= delta
				if z["t"] <= 0.0:
					z["kind"] = "dead"
					z["state"] = "wander"
				continue
			"climb":
				if DeadPose.climb_k(z) >= 1.0:
					z["state"] = "wander"
					z["home"] = z["pos"]
				continue
			"downed":
				z["t"] -= delta
				if z["t"] <= 0.0:
					z["state"] = "wander"
					z["home"] = z["pos"]
				continue
			"grab":
				_update_grab(z, delta)
				continue
			"attack":
				_update_attack(z, delta)
				continue
			"tell":
				_update_tell(z, delta)
				continue
			"eat":
				_keep_eating(z)       # then it looks and listens as ever (half sight: _sense)
		if z["kind"] == "fresh" and z["age"] > FRESH_STIFFEN:
			z["kind"] = "dead"
		if z["stun"] > 0.0:
			continue
		_sense(z, people, delta)
		if z["state"] == "tell":
			continue   # it has just dropped into it: it stands
		_move(z, delta)
	_separate(delta, separation_skip)


func _can_separate(z: Dictionary) -> bool:
	return not z["state"] in SEPARATION_EXCLUDED and float(z.get("dash_t", 0.0)) <= 0.0 and float(z.get("shoved_t", 0.0)) <= 0.0


func _separation_exclusions() -> Dictionary:
	var skip: Dictionary = {}
	for z in list:
		if not _can_separate(z):
			skip[z["id"]] = true
	return skip


## One simultaneous correction after movement. Only pos may change here;
## targets, paths, states, facing and the game's random stream stay untouched.
func _separate(delta: float, skip: Dictionary = {}) -> void:
	var bodies: Array[Dictionary] = []
	var positions := PackedVector3Array()
	var floors := PackedInt32Array()
	var ids := PackedInt64Array()
	var speeds := PackedFloat32Array()
	for z in list:
		if skip.has(z["id"]) or not _can_separate(z):
			continue
		bodies.append(z)
		positions.append(z["pos"])
		floors.append(game.level_of(z["pos"]))
		ids.append(z["id"])
		speeds.append(_speed(z))
	if bodies.size() < 2:
		return
	var pushes := DeadSeparation.pushes(positions, floors, ids, speeds, delta)
	# Stairs and ladders belong to both ends of the link; never push onto one.
	var links: Dictionary = {}
	for stair in game.stairs:
		var cell: Vector2i = stair["cell"]
		links[Vector3i(cell.x, stair["low"], cell.y)] = true
		links[Vector3i(cell.x, stair["high"], cell.y)] = true
	for i in range(bodies.size()):
		if pushes[i] == Vector3.ZERO:
			continue
		var dest := positions[i] + pushes[i]
		var cell := FieldGrid.cell_of(dest)
		var lg = game.grid_at(positions[i])
		if game.level_of(dest) != floors[i] or not lg.dead_can_walk(cell):
			continue
		if links.has(Vector3i(cell.x, floors[i], cell.y)):
			continue
		if not lg.body_line_clear(FieldGrid.cell_of(positions[i]), cell):
			continue
		bodies[i]["pos"] = dest


func _sense(z: Dictionary, people: Array, delta: float) -> void:
	# Far dead keep their errand; near ones look (forward cone), feel (arm's
	# reach all round) and smell blood. Senses tick at ~6 Hz per zombie.
	# Far from every person (not just the player) and not chasing: skip.
	if z["state"] == "chase":
		z["seen_t"] += delta
	else:
		var anyone_near := false
		for q in people:
			if z["pos"].distance_squared_to(q.position) <= NEAR * NEAR:
				anyone_near = true
				break
		if not anyone_near:
			return
	z["sense_t"] = float(z.get("sense_t", 0.0)) - delta
	if z["sense_t"] > 0.0:
		return
	z["sense_t"] = SenseRules.TICK_MIN + game.rng.randf() * SenseRules.TICK_JITTER
	# Weather cuts sight for both sides (body_injury 8.3); dusk cuts it again.
	var sight: float = SIGHT * float(game.weather.sight_mult(game.clock.is_dark()))
	if z["state"] == "eat":
		sight *= EatRules.SIGHT_MULT
	var best = null
	var best_d := 999.0
	var seen_at: Dictionary = z.get("seen_at", {})
	z["seen_at"] = seen_at
	var forward := Vector3(sin(z["angle"]), 0, cos(z["angle"]))
	var zl: int = game.level_of(z["pos"])
	var lg = game.grid_at(z["pos"])
	for p in people:
		# The dead do not look up through floors or out of upstairs windows.
		if game.level_of(p.position) != zl:
			continue
		var d: float = z["pos"].distance_to(p.position)
		# The body's smell stretches the end of sight and the feel alike, one step more downwind (8.1).
		var body_scent: float = SmellRules.body_mult(int(p.smell), SmellRules.downwind(game.weather.wind, game.weather.wind_dir, p.position, z["pos"]))
		var reach: float = sight * body_scent
		reach *= SenseRules.posture_mult(p.crouched, p.moving, p.is_running_now())
		# One standing in an unlit room after dark is seen no farther than in a cellar (decision 439 card 1).
		reach = BuildingRules.dark_reach(reach, game.has_method("dark_at") and game.dark_at(p.position))
		var to_p: Vector3 = (p.position - z["pos"])
		to_p.y = 0
		var close_sense: bool = d < FEEL * body_scent and lg.body_line_clear(FieldGrid.cell_of(z["pos"]), FieldGrid.cell_of(p.position))
		var in_cone := close_sense or (to_p.length() > 0.01 and forward.dot(to_p.normalized()) >= CONE_COS)
		# Already chasing: keeps tracking a moving target a bit outside the cone.
		if z["state"] == "chase" and z["victim"] == p and d < reach:
			in_cone = true
		if not in_cone or d > reach:
			continue
		if not lg.line_clear(FieldGrid.cell_of(z["pos"]), FieldGrid.cell_of(p.position)):
			continue
		# When it first made out each one is kept for as long as it is up (결정 441 (2)):
		# turning to another, or back again, does not start the grace over.
		var person_id: int = p.get_instance_id()
		if not seen_at.has(person_id):
			seen_at[person_id] = z["age"]
		if d <= best_d:
			best = p
			best_d = d
	if best != null:
		if _lunges(z, best_d):
			_begin_tell(z, best)
			return
		if z["state"] != "chase":
			z["path_t"] = 0.0
			_call_neighbours(z, best.position)
		z["turn_t"] = 0.0
		z["state"] = "chase"
		z["victim"] = best
		z["seen_t"] = 0.0
		z["last_seen"] = best.position
		z["target"] = best.position
		if best_d <= ATTACK_RANGE and z["cooldown"] <= 0.0 and can_reach(z, best) and float(z["age"]) - float(seen_at[best.get_instance_id()]) >= SEEN_GRACE:
			z["state"] = "attack"
			z["windup"] = WINDUP_CRAWL if z["crawl"] else WINDUP
			z["angle"] = atan2(best.position.x - z["pos"].x, best.position.z - z["pos"].z)
		return
	if float(z.get("dash_t", 0.0)) > 0.0:
		return   # in its run it does not look for what it lost: it runs on
	if z["state"] == "chase":
		# Memory holds the last observed spot, never an unseen person's new floor.
		z["target"] = z["last_seen"]
		if z["pos"].distance_to(z["last_seen"]) < 1.0:
			_begin_search(z, z["last_seen"])
		elif z["seen_t"] > MEMORY:
			z["state"] = "wander"
			z["victim"] = null
			z["home"] = z["pos"]
			z["target"] = z["pos"]
			z["path"] = PackedVector3Array()
			z["t"] = 2.0
		return
	if z["state"] == "eat":
		return   # eating: no trail or other body pulls it off (a sound still does: hear)
	if (z["state"] == "wander" or z["state"] == "search") and _go_to_food(z):
		return
	# Blood: fresh trail points pull the dead (body_injury 8.1: heavy bleeding reaches far).
	if z["state"] != "investigate" or float(z.get("smell_lock", 0.0)) <= 0.0:
		var scent: Dictionary = game.strongest_scent(z["pos"])
		if not scent.is_empty():
			z["state"] = "investigate"
			z["clue_kind"] = "scent"
			z["target"] = scent["pos"]
			z["linger"] = SmellRules.LINGER
			z["speed"] = SPEED_SHAMBLE
			z["path_t"] = 0.0
			z["smell_lock"] = SmellRules.TRAIL_LOCK
	z["smell_lock"] = maxf(0.0, float(z.get("smell_lock", 0.0)) - SmellRules.TRAIL_LOCK_TICK)


## The bodies of the living lying there that can be eaten (EatRules.edible).
func _edible_bodies() -> Array:
	var out: Array = []
	for p in game.people:
		if not p.body.dead:
			continue
		var rising: Dictionary = find(int(p.brain.get("rising_id", -1))) if p.brain.has("rising_id") else {}
		if EatRules.edible(p, rising):
			out.append(p)
	return out


## The body this one eats or goes to eat, if it can still be eaten.
func _food_of(z: Dictionary):
	var id := int(z.get("eat_of", 0))
	if id == 0:
		return null
	for p in _food:
		if p.get_instance_id() == id:
			return p
	return null


func _eaters_at(p) -> int:
	var n := 0
	for o in list:
		if o["state"] == "eat" and int(o.get("eat_of", 0)) == p.get_instance_id():
			n += 1
	return n


## Wandering near a body that can be eaten: off to it (the nearest, same floor).
func _go_to_food(z: Dictionary) -> bool:
	var best = null
	var best_d := EatRules.GATHER_R
	for p in _food:
		if game.level_of(p.position) != game.level_of(z["pos"]):
			continue
		var d: float = z["pos"].distance_to(p.position)
		if d < best_d:
			best = p
			best_d = d
	if best == null:
		return false
	z["state"] = "investigate"
	z["clue_kind"] = "food"
	z["clue"] = SimNoise.Level.QUIET
	z["target"] = best.position
	z["linger"] = 3.0
	z["speed"] = SPEED_SHAMBLE
	z["path_t"] = 0.0
	z["eat_of"] = best.get_instance_id()
	return true


## At the body: it kneels to eat, unless enough are at it already (then it
## stands round it a while and wanders off, and may come back).
func _begin_eating(z: Dictionary) -> bool:
	var p = _food_of(z)
	if p == null or _eaters_at(p) >= EatRules.AT_MOST:
		return false
	z["state"] = "eat"
	z["eat_at"] = z["age"]                 # dead_body.gd: kneeling down, then eating
	z["angle"] = atan2(p.position.x - z["pos"].x, p.position.z - z["pos"].z)
	z["last_seen"] = z["pos"]
	z["path"] = PackedVector3Array()
	return true


## Eating: it stops when the body gets up (or is gone), and goes back to it if
## it was pushed off.
func _keep_eating(z: Dictionary) -> void:
	var p = _food_of(z)
	if p == null:
		z["state"] = "wander"
		z["home"] = z["pos"]
		z["target"] = z["pos"]
		z["t"] = 2.0
		z["ate_until"] = z["age"]          # dead_body.gd: getting up from it
		z.erase("eat_of")
		return
	if Vector2(p.position.x - z["pos"].x, p.position.z - z["pos"].z).length() > EatRules.LEAVE_R:
		z["state"] = "investigate"
		z["clue_kind"] = "food"
		z["target"] = p.position
		z["linger"] = 3.0
		z["path_t"] = 0.0


## Lost the target: walk to where it was last seen, then poke around nearby.
func _begin_search(z: Dictionary, around: Vector3) -> void:
	z["state"] = "search"
	z["victim"] = null
	z["home"] = around
	z["target"] = around
	z["search_left"] = 2
	z["search_t"] = SEARCH_TIME
	z["linger"] = 1.0
	z["path_t"] = 0.0


## Herd behaviour: dead that see a neighbour lurch after something follow it.
func _call_neighbours(z: Dictionary, toward: Vector3) -> void:
	if not _sense_cells_ready:
		_sense_cells = SenseRules.index(list, Callable(game, "level_of"), HERD)
		_sense_cells_ready = true
	var floor_id: int = game.level_of(z["pos"])
	var lg = game.grid_at(z["pos"])
	for o in SenseRules.neighbours(_sense_cells, z["pos"], floor_id, HERD, HERD + _sense_padding):
		if o["id"] == z["id"] or o["state"] in ["dead", "rising", "frozen", "waking", "downed", "chase", "attack", "grab", "climb", "tell"]:
			continue
		if game.level_of(o["pos"]) != floor_id or o["pos"].distance_to(z["pos"]) > HERD:
			continue
		if not lg.line_clear(FieldGrid.cell_of(z["pos"]), FieldGrid.cell_of(o["pos"])):
			continue
		o["state"] = "investigate"
		o["clue_kind"] = "herd"
		o["target"] = toward + Vector3(game.rng.randf_range(-1.5, 1.5), 0, game.rng.randf_range(-1.5, 1.5))
		o["linger"] = 6.0
		o["speed"] = SPEED_SHAMBLE
		o["path_t"] = game.rng.randf() * 0.6


## True when this one, seeing a person that far off, drops into its tell now.
func _lunges(z: Dictionary, far: float) -> bool:
	if not z.get("lunger", false) or z.get("lunged", false) or z["crawl"] or far > LungerRules.SEES:
		return false
	var busy := 0
	for o in list:
		if o["state"] == "tell" or (float(o.get("dash_t", 0.0)) > 0.0 and o["state"] != "dead"):
			busy += 1
	return busy < LungerRules.AT_ONCE


## The beat before it runs: it stands where it is, low, facing the one it saw.
## The field is told (on_lunge_tell), so that it can show and sound it.
func _begin_tell(z: Dictionary, victim) -> void:
	if z["state"] != "chase":
		_call_neighbours(z, victim.position)
	z["lunged"] = true
	z["state"] = "tell"
	z["t"] = LungerRules.TELL
	z["turn_t"] = 0.0
	z["victim"] = victim
	z["seen_t"] = 0.0
	z["last_seen"] = victim.position
	z["target"] = victim.position
	z["dash_t"] = 0.0
	z["spent_t"] = 0.0
	z["angle"] = atan2(victim.position.x - z["pos"].x, victim.position.z - z["pos"].z)
	if game.has_method("on_lunge_tell"):
		game.on_lunge_tell(z)


## It turns with the one it saw until the beat is over, then runs at where they
## are at that moment, in a straight line. Struck in the beat, it does not run.
func _update_tell(z: Dictionary, delta: float) -> void:
	var victim = z["victim"]
	# For this one beat it keeps its eyes on them, wherever they step (a chase only remembers a spot).
	if victim != null and victim.is_alive() and game.level_of(victim.position) == game.level_of(z["pos"]):
		z["last_seen"] = victim.position
		z["target"] = victim.position
	var to: Vector3 = z["last_seen"] - z["pos"]
	to.y = 0
	if to.length() > 0.01:
		z["angle"] = lerp_angle(float(z["angle"]), atan2(to.x, to.z), minf(1.0, delta * 6.0))
	if z["stun"] > 0.0:
		z["state"] = "chase"
		z["spent_t"] = LungerRules.SPENT
		return
	z["t"] -= delta
	if z["t"] > 0.0:
		return
	z["state"] = "chase"
	z["path_t"] = 0.0
	z["dash_dir"] = to.normalized() if to.length() > 0.01 else Vector3(sin(z["angle"]), 0, cos(z["angle"]))
	z["dash_t"] = LungerRules.DASH


## The clocks of the run and of the staggering after it. They go on while it
## bites, is held off or lies on the ground.
func _run_down(z: Dictionary, delta: float) -> void:
	if z["dash_t"] > 0.0:
		z["dash_t"] -= delta
		if z["dash_t"] <= 0.0:
			_end_dash(z)
	elif z["spent_t"] > 0.0:
		z["spent_t"] = maxf(0.0, z["spent_t"] - delta)


func end_dash(z: Dictionary) -> void:
	_end_dash(z)


func _end_dash(z: Dictionary) -> void:
	z["dash_t"] = 0.0
	z["spent_t"] = LungerRules.SPENT
	z["path_t"] = 0.0


## The run goes where it was aimed, not after the person: no path, no turning.
## A wall it cannot get along ends it; a door is banged on, as in a walk.
func _dash(z: Dictionary, delta: float) -> void:
	var at: Vector3 = z["pos"]
	var dir: Vector3 = z["dash_dir"]
	var step := dir * _speed(z) * delta
	var dest := at + step
	var dc := FieldGrid.cell_of(dest)
	var lg = game.grid_at(at)
	if lg.blocks_body(dc):
		if lg == game.grid and game.grid.doors.has(dc):
			_bang(z, dc, delta)
			dest = at
		else:
			dest = _slide(at, step)
			if dest.distance_to(at) < step.length() * 0.2:
				_end_dash(z)
	z["angle"] = atan2(dir.x, dir.z)
	z["pos"] = _avoid_people(z, dest)


func _speed(z: Dictionary) -> float:
	if z["crawl"]:
		return SPEED_CRAWL
	var s := SPEED_WANDER
	match z["state"]:
		"chase":
			if float(z.get("dash_t", 0.0)) > 0.0:
				s = LungerRules.DASH_SPEED
			elif float(z.get("spent_t", 0.0)) > 0.0:
				s = LungerRules.SPENT_SPEED
			else:
				s = SPEED_FRESH if z["kind"] == "fresh" else SPEED_HURRY
		"investigate":
			s = maxf(float(z["speed"]), SPEED_SHAMBLE)
		"search":
			s = SPEED_SHAMBLE
		"horde":
			s = SPEED_SHAMBLE
	return s * float(FieldGrid.FLOOR_SPEED[game.grid_at(z["pos"]).floor_at(FieldGrid.cell_of(z["pos"]))])


func _move(z: Dictionary, delta: float) -> void:
	if z["state"] == "eat":
		return
	if z["state"] == "chase" and float(z.get("dash_t", 0.0)) > 0.0 and not z["crawl"]:
		_dash(z, delta)
		return
	var state: String = z["state"]
	var target: Vector3 = z["target"]
	var at: Vector3 = z["pos"]
	if state == "wander":
		if at.distance_to(target) < 0.5:
			z["t"] -= delta
			if z["t"] <= 0.0:
				# Most of the dead stand and sway, turning now and then; some drift.
				if z.get("stander", false) and game.rng.randf() < 0.7:
					z["t"] = game.rng.randf_range(4.0, 10.0)
					z["angle"] += game.rng.randf_range(-1.2, 1.2)
					return
				z["t"] = game.rng.randf_range(3.0, 8.0)
				var off := Vector3(game.rng.randf_range(-5, 5), 0, game.rng.randf_range(-5, 5))
				var home: Vector3 = Vector3(z["home"].x, at.y, z["home"].z)
				var c: Vector2i = game.grid_at(at).nearest_walkable(FieldGrid.cell_of(home + off), true, 2)
				z["target"] = game.lift(c, game.level_of(at))
				z["path"] = PackedVector3Array()
			return
	elif state == "investigate":
		# Travel to a sound has a deadline too. Arrival keeps the existing linger.
		if at.distance_to(target) >= 1.2 and z.get("clue_kind", "") == "sound":
			z["clue_left"] = maxf(0.0, float(z.get("clue_left", 0.0)) - delta)
			if z["clue_left"] <= 0.0:
				_begin_search(z, at)
				return
		if at.distance_to(target) < EatRules.REACH:
			if z.get("clue_kind", "") == "food" and _begin_eating(z):
				return
			z["linger"] -= delta
			if z["linger"] <= 0.0:
				z["state"] = "wander"
				z["home"] = at
				z["t"] = 2.0
			elif game.rng.randf() < delta * 0.5:
				z["angle"] += game.rng.randf_range(-1.5, 1.5)
			return
	elif state == "search":
		z["search_t"] = float(z.get("search_t", SEARCH_TIME)) - delta
		if z["search_t"] <= 0.0:
			z["state"] = "wander"
			z["home"] = at
			z["t"] = 2.0
			return
		if at.distance_to(target) < 1.0:
			z["linger"] -= delta
			if game.rng.randf() < delta * 1.5:
				z["angle"] += game.rng.randf_range(-1.6, 1.6)
			if z["linger"] <= 0.0:
				z["search_left"] = int(z["search_left"]) - 1
				if z["search_left"] <= 0:
					z["state"] = "wander"
					z["t"] = 3.0
					return
				var off := Vector3(game.rng.randf_range(-3, 3), 0, game.rng.randf_range(-3, 3))
				z["target"] = game.walkable_near(z["home"] + off, true, 2)
				z["linger"] = 1.0
				z["path_t"] = 0.0
			return
	elif state == "horde":
		if at.distance_to(target) < 2.0:
			z["state"] = "investigate"
			z["linger"] = 40.0
			z["speed"] = SPEED_SHAMBLE
	if float(z.get("turn_t", 0.0)) > 0.0:
		z["turn_t"] = float(z["turn_t"]) - delta
		var want := atan2(target.x - at.x, target.z - at.z)
		z["angle"] = lerp_angle(float(z["angle"]), want, minf(1.0, delta * 6.0))
		return
	# Path refresh: straight when clear, otherwise A* on the people grid
	# (closed doors are planned through and then banged on).
	z["path_t"] -= delta
	z["no_way_t"] = maxf(0.0, float(z.get("no_way_t", 0.0)) - delta)
	var path: PackedVector3Array = z["path"]
	# The wait holds only for the cell that had no way: a new target is looked for at once.
	var waiting: bool = float(z["no_way_t"]) > 0.0 and z.get("no_way_cell") == FieldGrid.cell_of(target)
	if (z["path_t"] <= 0.0 or path.is_empty()) and not waiting:
		z["no_way_t"] = 0.0
		var near := at.distance_to(game.player.position) < NEAR
		z["path_t"] = (0.6 if near else 2.5) + game.rng.randf() * 0.4
		if game.level_of(at) == game.level_of(target) and game.grid_at(at).clear_walk(FieldGrid.cell_of(at), FieldGrid.cell_of(target), true):
			path = PackedVector3Array([target])
		else:
			path = game.find_path(at, target, false)
			# Walled off (a locked room, up a ladder): the search that finds no way
			# is the dearest one, and with nowhere left to walk every one of the
			# crowd ran it again each frame, which slowed the whole field (build 89).
			# They stand where they got to and ask again a little later.
			if path.is_empty() or FieldGrid.cell_of(path[path.size() - 1]) != FieldGrid.cell_of(target):
				z["no_way_t"] = NO_WAY_WAIT + game.rng.randf() * 0.5
				z["no_way_cell"] = FieldGrid.cell_of(target)
		z["path"] = path
	if path.is_empty():
		return
	var next := path[0]
	var dir := next - at
	dir.y = 0
	if dir.length() < 0.25:
		# Stairs: the next point is the same spot a floor up or down.
		z["pos"] = Vector3(at.x, game.level_y(game.level_of(next)), at.z)
		path.remove_at(0)
		z["path"] = path
		return
	var step := dir.normalized() * _speed(z) * delta
	var dest := at + step
	var dc := FieldGrid.cell_of(dest)
	var lg = game.grid_at(at)
	if lg.blocks_body(dc):
		if lg == game.grid and game.grid.doors.has(dc):
			_bang(z, dc, delta)
		dest = _slide(at, step)
	z["angle"] = atan2(dir.x, dir.z)
	z["pos"] = _avoid_people(z, dest)


func _bang(z: Dictionary, c: Vector2i, delta: float) -> void:
	var row: Dictionary = Motion.row("dead_thump")
	# Come up to the door, it draws its arms back first: the first blow lands
	# where the picture's does (decision 425), then one every round.
	if float(z["age"]) - float(z.get("bang_seen", -INF)) > DeadBody.AT_DOOR:
		z["bang_t"] = float(row["hit"])
	z["bang_seen"] = z["age"]      # at the door now (dead_body.gd draws it beating on it)
	z["bang_t"] -= delta
	if z["bang_t"] > 0.0:
		return
	z["bang_t"] = float(row["len"])
	game.on_door_banged(c, z)


func _slide(at: Vector3, step: Vector3) -> Vector3:
	var lg = game.grid_at(at)
	var r := at
	var cand := r + Vector3(step.x, 0, 0)
	if not lg.blocks_body(FieldGrid.cell_of(cand)):
		r.x = cand.x
	cand = r + Vector3(0, 0, step.z)
	if not lg.blocks_body(FieldGrid.cell_of(cand)):
		r.z = cand.z
	return r


func _avoid_people(z: Dictionary, dest: Vector3) -> Vector3:
	for p in _people:
		var d: float = dest.distance_to(p.position)
		if d < 0.55 and d > 0.001:
			dest = p.position + (dest - p.position).normalized() * 0.55
	return dest


## Same floor and nothing that stops a blow between (a wall corner, a shut door, whole glass).
func can_reach(z: Dictionary, victim) -> bool:
	if game.level_of(z["pos"]) != game.level_of(victim.position):
		return false
	return game.grid_at(z["pos"]).body_line_clear(FieldGrid.cell_of(z["pos"]), FieldGrid.cell_of(victim.position))


func _update_attack(z: Dictionary, delta: float) -> void:
	var victim = z["victim"]
	if victim == null or not victim.is_alive():
		z["state"] = "wander"
		return
	z["windup"] -= delta
	var d: float = z["pos"].distance_to(victim.position)
	if d > ATTACK_RANGE + GrabRules.CONTACT_MARGIN or not can_reach(z, victim):
		z["state"] = "chase"
		return
	if z["windup"] > 0.0:
		return
	z["cooldown"] = GrabRules.ATTACK_COOLDOWN
	var outcome: String = game.zombie_reaches(z, victim)
	if outcome == "miss":
		z["missed_at"] = z["age"]      # reached and got nothing (dead_body.gd: it snaps at the air)
	if outcome == "grab":
		z["state"] = "grab"
	else:
		z["state"] = "chase"


func _update_grab(z: Dictionary, delta: float) -> void:
	var victim = z["victim"]
	if victim == null or not victim.is_alive():
		if victim != null:
			victim.release_grab(z)
			GrabRules.mark_released(victim, game.clock.elapsed)
		z["state"] = "wander"
		z["victim"] = null
		return
	if not victim.grabbers.has(z) or z["pos"].distance_to(victim.position) > ATTACK_RANGE + GrabRules.CONTACT_MARGIN or not can_reach(z, victim):
		release(z, victim.position, false)
		return
	z["pos"] = victim.position + (z["pos"] - victim.position).normalized() * 0.5
	z["angle"] = atan2(victim.position.x - z["pos"].x, victim.position.z - z["pos"].z)


## Release a grab (shoved off or victim died). Shove pushes the body back.
func release(z: Dictionary, push_from: Vector3, knock: bool) -> void:
	if z.is_empty() or z["state"] == "dead":
		return
	# Whoever it held is let go, knocked down or not (release_grab is safe to repeat).
	if z["state"] == "grab" and z["victim"] != null:
		z["victim"].release_grab(z)
		GrabRules.mark_released(z["victim"], game.clock.elapsed)
	var away: Vector3 = z["pos"] - push_from
	away.y = 0
	if away.length() < 0.01:
		away = Vector3(0, 0, 1)
	z["shoved_from"] = z["pos"]
	z["shoved_t"] = SHOVED_TIME
	z["pos"] = _slide(z["pos"], away.normalized() * 1.3)
	z["cooldown"] = GrabRules.RELEASE_RECOVERY
	if knock and reels_first(z):
		# Decision 412: it reels back the shove's length on its feet, stunned
		# (it cannot bite or grab), then goes over (update). It lies as long.
		if float(z.get("dash_t", 0.0)) > 0.0:
			_end_dash(z)
		z["state"] = "chase"
		z["stun"] = maxf(float(z["stun"]), SHOVED_TIME)
		z["fall_in"] = SHOVED_TIME
	elif knock:
		knock_down(z)
	else:
		if z["state"] == "tell":
			z["spent_t"] = LungerRules.SPENT   # shoved out of its tell, it does not run
		z["state"] = "chase"
		z["stun"] = 1.0


## Lying knocked down and now getting up (the last of its time down, as long as
## the drawing's rise): a shove catches it then (decision 425). A crawler does not get up.
func getting_up(z: Dictionary) -> bool:
	return z["state"] == "downed" and not z["crawl"] and float(z["t"]) <= float(Motion.row("dead_rise")["len"])


## Shoved over, half of the dead go down at once and half reel first and go
## down after (decision 412). Which, by the body's own number, so a body always
## does the same; apart from how it falls (DeadBody.fall_motion).
static func reels_first(z: Dictionary) -> bool:
	return fposmod(float(z["phase"]) * 3.73 + 0.31, 1.0) < 0.5


## How far a shoved body has been seen to go: 0 still where it stood, 1 where
## the shove put it (build 89: it jumped there at once). The rules use "pos".
func shoved_k(z: Dictionary) -> float:
	var left: float = float(z.get("shoved_t", 0.0))
	if left <= 0.0:
		return 1.0
	var k := 1.0 - left / SHOVED_TIME
	return 1.0 - (1.0 - k) * (1.0 - k)


## Where a body is seen (decision 474 J2: a blow is judged there): stumbling
## back from a shove it is still on its way (draw_pos), holding someone it is
## drawn GRAB_BACK further off them (render), and one on the ground is struck
## on its upper body, LYING_HIT toward its head, which lies off to the side it
## went over (decision 487: not the head itself, 0.75 m off, which lies away
## from whoever felled it, out among the rest). Drawn into a wall or a crate
## (gone over against it, hanging back off someone by it), it is struck where
## it stands instead: no blow could reach it in there.
func seen_pos(z: Dictionary) -> Vector3:
	var pos := draw_pos(z)
	var off := Vector3.ZERO
	if z["state"] == "grab" and shoved_k(z) >= 1.0:
		off = Basis(Vector3.UP, z["angle"]) * Vector3(0, 0, -GRAB_BACK)
	elif (z["state"] == "downed" or z["state"] == "rising") and not z["crawl"]:
		var down := DeadPose.down_k(z)
		var turn: float = float(DeadPose.sprawl(float(z["phase"]))["turn"]) * down
		off = Basis(Vector3.UP, float(z["angle"]) + turn) * Vector3(0, 0, DeadPose.fall_side(z) * LYING_HIT * down)
	if off != Vector3.ZERO and game.grid_at(pos).body_line_clear(FieldGrid.cell_of(pos), FieldGrid.cell_of(pos + off)):
		pos += off
	return pos


func draw_pos(z: Dictionary) -> Vector3:
	var k := shoved_k(z)
	if k >= 1.0:
		return z["pos"]
	var from: Vector3 = z["shoved_from"]
	return from.lerp(z["pos"], k)


func knock_down(z: Dictionary) -> void:
	# Knocked off its victim: the victim is let go, or the grab still bites.
	if z["state"] == "grab" and z["victim"] != null:
		z["victim"].release_grab(z)
		GrabRules.mark_released(z["victim"], game.clock.elapsed)
	DeadPose.mark_fall(z, _people)
	if float(z.get("dash_t", 0.0)) > 0.0:
		_end_dash(z)
	z["state"] = "downed"
	_roll_loot(z)
	z["t"] = game.rng.randf_range(GET_UP.x, GET_UP.y)
	z["victim"] = null


func kill(z: Dictionary) -> void:
	if z["state"] == "grab" and z["victim"] != null:
		z["victim"].release_grab(z)
		GrabRules.mark_released(z["victim"], game.clock.elapsed)
	DeadPose.mark_fall(z, _people)
	z["state"] = "dead"
	z["victim"] = null
	_roll_loot(z)
	game.on_zombie_killed(z)


## How a body that is going for someone leans at them (drawing only). Coming
## in for the bite (attack) it bends further in as its windup runs out; holding
## on (grab) it hangs on them, tugging back and forth and side to side.
const REACH_LEAN: float = 0.25
const HOLD_LEAN: float = 0.12                # holding on it hangs less far in than it bent to bite
const GRAB_BACK: float = 0.15                # drawn this much further off the one it holds, metres
const LYING_HIT: float = 0.4                 # one lying flat is struck this far from its place toward its head: the chest, metres
const TUG: Vector2 = Vector2(0.08, 0.06)       # forward and sideways, radians
const TUG_HZ: float = 2.2


static func reach_basis(z: Dictionary) -> Basis:
	if z["state"] == "attack":
		var k := 1.0 - clampf(float(z["windup"]) / WINDUP, 0.0, 1.0)
		return Basis(Vector3.RIGHT, REACH_LEAN * k * k)
	var w := TAU * (TUG_HZ * float(z["age"]) + float(z["phase"]))
	return Basis(Vector3.RIGHT, HOLD_LEAN + TUG.x * sin(w)) * Basis(Vector3.BACK, TUG.y * sin(w * 0.5 + 1.0))


## One body's multimeshes, one per look, each in the look's tint, each of the
## dead in it worn as its own (dead_cast.gd tear_of, the multimesh colour).
func _draws_of(body: Dictionary) -> Dictionary:
	var out := {}
	var mesh: Mesh = body["mesh"]
	var marked: bool = mesh != null and mesh.get_surface_count() > 0 and (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0
	for look in ["dead", "clothed", "fresh", "frozen", "corpse"]:
		var node := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = true
		node.set_meta(&"hands_marked", marked)
		mm.mesh = body["mesh"]
		mm.instance_count = MAX_DRAW
		mm.visible_instance_count = 0
		mm.custom_aabb = AABB(Vector3(-5, -5, -5), Vector3(185, 16, 115))
		node.multimesh = mm
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://game/actors/dead_weathered.gdshader")
		mat.set_shader_parameter("vat", body["texture"])
		mat.set_shader_parameter("rows_per_frame", float(body["rows_per_frame"]))
		if baked:
			var tables := VatBaker.shader_tables(body)
			for key in tables:
				mat.set_shader_parameter(key, tables[key])
			mat.set_shader_parameter("mixes", true)
			mat.set_shader_parameter("cloth_state", DeadCast.CLOTH_STATE)
			mat.set_shader_parameter("skin_tint", float(DeadCast.SKIN_TINT.get(look, 1.0)))
			mat.set_shader_parameter("skin_gone_least", float(DeadCast.SKIN_GONE_LEAST.get(look, 0.82)))
		var t: Color = TINTS[look]
		mat.set_shader_parameter("tint", Vector3(t.r, t.g, t.b))
		node.material_override = mat
		add_child(node)
		out[look] = node
	return out


## The next body the dead wear read in (dead_cast.gd), one a frame so the field
## does not stall starting; until then the dead in it are drawn in the first.
func _read_a_body() -> void:
	if bodies_to_read.is_empty():
		return
	var got := DeadCast.read(bodies_to_read.pop_front(), vat)
	draws.append(_draws_of(got) if not got.is_empty() else {})
	wear_draws.append({})
	body_rounds.append(DeadBody.rounds_of(got) if not got.is_empty() else DeadBody.rounds)


## Garment `kind` over body `b` (dead_cast.gd), read in the first time one of
## the dead in that body is drawn in it, one a frame as the bodies are and not
## in a frame a body is read (a stop with no police station never reads the
## vest). A body not yet shown waits for this read, including a cached null
## when that body has none of it.
func _garment_of(b: int, kind: String) -> MultiMeshInstance3D:
	var wear: Dictionary = wear_draws[b]
	if wear.has(kind):
		return wear[kind]
	if _garment_reads <= 0:
		return null
	_garment_reads -= 1
	var got := DeadCast.read_garment(DeadCast.garment_dir(b, kind), vat)
	wear[kind] = _garment_draw(got) if not got.is_empty() else null
	return wear[kind]


## One garment's multimesh: dead_garment.gdshader's worn_look and sight fade
## on the dead's motions, each of the dead in the garment's own
## colour and pattern (dead_cast.gd garment_of, the multimesh colour).
func _garment_draw(shell: Dictionary) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = shell["mesh"]
	mm.instance_count = MAX_DRAW * 5   # as many as the body's five looks hold
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-5, -5, -5), Vector3(185, 16, 115))
	node.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://game/actors/dead_garment.gdshader")
	mat.set_shader_parameter("vat", shell["texture"])
	mat.set_shader_parameter("rows_per_frame", float(shell["rows_per_frame"]))
	var tables := VatBaker.shader_tables(shell)
	for key in tables:
		mat.set_shader_parameter(key, tables[key])
	mat.set_shader_parameter("mixes", true)
	mat.set_shader_parameter("worn_look", true)
	node.material_override = mat
	add_child(node)
	return node


## Sight changes only the drawing; elapsed time is supplied by render.
static func next_shown(prev: float, seen_now: bool, delta: float) -> float:
	return clampf(prev + delta / SIGHT_FADE_IN if seen_now else prev - delta / SIGHT_FADE_OUT, 0.0, 1.0)


## Keep shade below 2, leaving the even part for sixteen steps of hidden pixels.
static func pack_shade(shade: float, shown: float) -> float:
	assert(shade >= 0.0 and shade < 2.0, "shade must leave room for sight visibility")
	var k: int = int(round((1.0 - clampf(shown, 0.0, 1.0)) * 16.0))
	return shade + 2.0 * float(k)


static func unpack_shade(a: float) -> Vector2:
	var k: float = floorf(a * 0.5)
	return Vector2(a - 2.0 * k, 1.0 - k / 16.0)


## Camera3D's planes face out: positive distance is outside. Keep a sphere
## touching any plane, so a body is already submitted before its centre enters.
static func in_sight_frustum(planes: Array[Plane], at: Vector3) -> bool:
	var centre: Vector3 = at + Vector3(0, 0.9, 0)
	for plane: Plane in planes:
		if plane.distance_to(centre) > FRUSTUM_PAD:
			return false
	return true


## The last in-sight draw owns these values; shader TIME keeps its motion going.
func _sight_draw(z: Dictionary, b: int, look: String, over: Dictionary, garment: MultiMeshInstance3D, record: Dictionary) -> Dictionary:
	var at: Vector3 = z["pos"]
	var state: String = z["state"]
	var basis := Basis(Vector3.UP, DeadBody.yaw_of(z, baked))
	var pos := draw_pos(z)
	var reel := 1.0 - shoved_k(z)
	var frozen_anim := 0.0
	var shade := 1.0
	var down := DeadPose.down_k(z)
	if down > 0.0:
		# A baked body goes over by its own motion; the boxes are laid down whole.
		if not DeadBody.falls_by_motion(z, baked):
			var lie := DeadPose.lying(z, down)
			basis = basis * lie.basis
			pos.y = pos.y + lie.origin.y
		else:
			basis = basis * Basis(Vector3.UP, DeadBody.ground_turn(z, down))
		# Flat on the ground it is still (a crawler drags itself); going over or coming up, the limbs move.
		frozen_anim = 1.0 if down >= 1.0 and (state != "downed" or not z["crawl"]) else 0.0
	elif reel > 0.0:
		basis = basis * Basis(Vector3.RIGHT, -0.5 * reel)   # thrown back on its heels
	elif state == "grab" or state == "attack":
		basis = basis * reach_basis(z)
		if state == "grab":
			# The rules hold it 0.5 m off; drawn there its reach goes through them.
			pos -= Basis(Vector3.UP, z["angle"]) * Vector3(0, 0, GRAB_BACK)
	elif state == "climb":
		var out := DeadBody.climbing(z, baked)
		pos = pos + basis * out.origin
		basis = basis * out.basis
	elif state == "tell":
		# The boxes have no motion for it: they bend forward and sink. A baked body has its own.
		if not baked:
			var low := DeadBody.tell_k(z)
			basis = basis * Basis(Vector3.RIGHT, 0.45 * low)
			pos.y -= 0.18 * low
	elif state == "eat" and not baked:
		# The boxes have no motion for it: bent low over the body.
		basis = basis * Basis(Vector3.RIGHT, 0.6)
		pos.y -= 0.25
	elif state != "frozen" and state != "waking" and not baked:
		basis = basis * DeadPose.gait_basis(z)
	if state == "frozen":
		frozen_anim = 1.0
		basis = basis * Basis(Vector3.RIGHT, -0.5)
		pos.y = at.y - 0.55
	elif state == "waking":
		pos.y = at.y - 0.55 * clampf(float(z["t"]) / WAKE_TIME, 0, 1) + sin(z["t"] * 40.0) * 0.04
	# Reuse this id's record; only an in-sight frame may overwrite its values.
	record["b"] = b
	record["look"] = look
	record["at"] = at
	record["garment"] = garment
	record["shell"] = String(over.get("shell", ""))
	record["garment_color"] = over.get("colour", Color.WHITE)
	if state == "rising":
		record["marker"] = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.05, 0))
	else:
		record.erase("marker")
	# The axe goes by the body as it stands or lies, before the clothed are drawn broader.
	if embedded_draw != null and shows_embedded(z):
		var axe := Transform3D(basis, pos) * EMBED_AT
		if down > 0.5:
			var turn := Basis(Vector3.UP, z["angle"])
			axe = Transform3D(Basis(Vector3.UP, z["angle"] + EMBED_DROP_TURN), Vector3(pos.x, at.y, pos.z) + turn * EMBED_DROP_AT)
		record["axe"] = axe
	else:
		record.erase("axe")
	if z["kind"] == "clothed":
		basis = basis.scaled(Vector3(1.3, 1.0, 1.35))
	if z["stun"] > 0.0:
		shade = 0.8
	var node: MultiMeshInstance3D = draws[b][look]
	# The drawn slot may be a fallback or an old appearance; the pose keeps its assigned stride.
	var pose_body: int = DeadCast.body_of(int(z["id"]), bodies_planned)
	DeadBody.rounds = _pose_rounds[pose_body] if pose_body < _pose_rounds.size() else _pose_rounds[0]
	record["transform"] = Transform3D(basis, pos)
	record["custom"] = DeadBody.custom(z, down, frozen_anim, shade, baked)
	record["color"] = DeadCast.tear_of(z, bool(node.get_meta(&"hands_marked", false)))
	return record


## Both the ordinary pass and a changed cap selection submit the same attachments.
func _submit_sight_draw(id: int, record: Dictionary, shown: float, counts: Array, attachments: Vector2i) -> Vector2i:
	var b: int = int(record["b"])
	var look: String = record["look"]
	var n: int = counts[b][look]
	var mm: MultiMesh = draws[b][look].multimesh
	var draw_transform: Transform3D = record["transform"]
	var custom: Color = record["custom"]   # Color is a value: the cached shade stays unpacked.
	custom.a = pack_shade(custom.a, shown)
	mm.set_instance_transform(n, draw_transform)
	mm.set_instance_custom_data(n, custom)
	mm.set_instance_color(n, record["color"])
	counts[b][look] = n + 1
	drawn_at[id] = draw_transform.origin
	var garment: MultiMeshInstance3D = record["garment"]
	var worn_ids: Array = garments_drawn.get_or_add(garment, []) if garment != null else []
	if garment != null and worn_ids.size() < garment.multimesh.instance_count:
		var w: int = worn_ids.size()
		garment.multimesh.set_instance_transform(w, draw_transform)
		garment.multimesh.set_instance_custom_data(w, custom)
		garment.multimesh.set_instance_color(w, record["garment_color"])
		worn_ids.append(id)
	if record.has("marker") and attachments.x < 32:
		markers.multimesh.set_instance_transform(attachments.x, record["marker"])
		markers.multimesh.set_instance_color(attachments.x, Color(1, 1, 1, shown))
		_submitted_markers[id] = shown
		attachments.x += 1
	# The axe uses PropModels' shared weathered shader, which has no sight fade.
	# Keep its existing threshold until that material gains an opt-in fade path.
	if shown >= 0.5 and embedded_draw != null and record.has("axe") and attachments.y < EMBED_MAX:
		embedded_draw.multimesh.set_instance_transform(attachments.y, record["axe"])
		attachments.y += 1
	return attachments


## One MultiMesh per body and look; sight fades before floor and screen culling.
func render(camera: Camera3D, seen: Dictionary, mask_on: bool, delta: float = -1.0) -> void:
	# delta is engine-scaled frame time, including the explicit test input. Match
	# field_game's clamp before slow; hitstop holds the picture. Pause alone may
	# finish a pending fade, as the field keeps calling render while paused.
	var step: float = clampf(get_process_delta_time() if delta < 0.0 else delta, 0.0, 0.1)
	step = 0.0 if bool(game.hitstop) else step * maxf(float(game.slow), 0.0)
	var first: bool = not _rendered_once
	# Only the restored still reads every seen appearance at once; a new field keeps
	# one read a frame (test_dead_cast) and fades its unread dead in when ready.
	var immediate: bool = bool(game.resume_pending)
	_garment_reads = 0 if not bodies_to_read.is_empty() else 1   # one read a frame, body or garment
	_read_a_body()
	if immediate:
		# The restored still gets only one render before the resume overlay waits.
		# Resolve every seen body's slot before sizing the submission counters.
		for z: Dictionary in list:
			var at: Vector3 = z["pos"]
			if (mask_on and not seen.has(game.seen_key(at))) or not game.level_shown(game.level_of(at)):
				continue
			var wanted_b: int = DeadCast.body_of(int(z["id"]), bodies_planned)
			while wanted_b >= draws.size() and not bodies_to_read.is_empty():
				_read_a_body()
		_garment_reads = list.size()   # at most one garment request per seen body
	var planes: Array[Plane] = camera.get_frustum()
	var counts := []
	for _b in draws.size():
		counts.append({"dead": 0, "clothed": 0, "fresh": 0, "frozen": 0, "corpse": 0})
	var shown_next: Dictionary = {}
	var seen_draw_next: Dictionary = {}
	var held_next: Dictionary = {}
	var overflow: Dictionary = {}   # body -> look -> ids; created only at the 161st candidate
	garments_drawn = {}
	drawn_at = {}
	_submitted_markers.clear()
	var attachments: Vector2i = Vector2i.ZERO
	for z in list:
		var id: int = int(z["id"])
		var at: Vector3 = z["pos"]
		# The restored still is not a step on the body's timeline (field_save keeps
		# the saved pose clocks): it draws from a copy, so z's clocks stay as saved.
		var pose_z: Dictionary = z.duplicate() if immediate else z
		if immediate and z["state"] == "grab" and DeadBody.bite_k(z) >= 0.0:
			# yaw_of changes the copy before bite_k compares it with victim.grabbers[0].
			# Keep that comparison on the original; field_save restores its saved clocks afterwards.
			pose_z = z
		var seen_now: bool = not mask_on or seen.has(game.seen_key(at))
		var prev: float = float(_shown.get(id, 0.0))
		var shown: float = 1.0 if (first or immediate) and seen_now else next_shown(prev, seen_now, step)
		shown_next[id] = shown
		var last: Dictionary = _last_seen_draw[id] if _last_seen_draw.has(id) else {}
		var floor_at: Vector3 = at if seen_now or last.is_empty() else last["at"]
		if not game.level_shown(game.level_of(floor_at)):
			shown_next[id] = 0.0
			continue
		var record: Dictionary = last
		var appearance_ready: bool = false
		if seen_now:
			var wanted_b: int = DeadCast.body_of(id, bodies_planned)
			appearance_ready = wanted_b < draws.size()
			# An attempted but absent body is a permanent fallback, not a pending read.
			if appearance_ready and (draws[wanted_b] as Dictionary).is_empty():
				wanted_b = 0
			var wanted_look: String = "corpse" if z["state"] == "dead" else String(z["kind"])
			if z["state"] == "frozen" or z["state"] == "waking":
				wanted_look = "frozen"
			var over: Dictionary = DeadCast.garment_of(drawn_worn(z), TINTS[wanted_look], id if String(z.get("name", "")) == "" else -1) if baked else {}
			var wanted_garment: MultiMeshInstance3D = null
			if appearance_ready and not over.is_empty():
				var request_garment: bool = immediate or (wear_draws[wanted_b] as Dictionary).has(over["shell"])
				if not request_garment and _garment_reads > 0:
					# Use the actual pose (including shove/grab offsets), without
					# overwriting the last appearance before the garment is ready.
					# A copy: whether this check runs depends on the read budget, never on rules.
					var probe: Dictionary = _sight_draw(z.duplicate(), wanted_b, wanted_look, over, null, {})
					var probe_transform: Transform3D = probe["transform"]
					request_garment = in_sight_frustum(planes, probe_transform.origin)
				if request_garment:
					wanted_garment = _garment_of(wanted_b, String(over["shell"]))
				appearance_ready = (wear_draws[wanted_b] as Dictionary).has(over["shell"])
			if not appearance_ready and (prev <= 0.0 or last.is_empty()):
				# Even on arrival, an unread appearance never gets a visible placeholder.
				shown_next[id] = 0.0
				# Still advance the pose clocks kept in z (DeadBody.custom), as a drawn body
				# would: when an appearance is read must never change the saved state.
				_sight_draw(pose_z, 0, wanted_look, {}, null, {})
				var held: int = int(_held_frames.get(id, 0)) + 1
				held_next[id] = held
				held_frames_max = maxi(held_frames_max, held)
				continue
			# The record is reused, so take appearance snapshots before overwriting it.
			var had_last: bool = not last.is_empty()
			var last_b: int = int(last.get("b", -1))
			var last_shell: String = String(last.get("shell", ""))
			var last_garment: MultiMeshInstance3D = last.get("garment", null)
			var last_garment_color: Color = last.get("garment_color", Color.WHITE)
			if appearance_ready:
				record = _sight_draw(pose_z, wanted_b, wanted_look, over, wanted_garment, last)
				if not first and prev > 0.0 and had_last and (last_b != wanted_b or last_shell != record["shell"] or last_garment != record["garment"] or last_garment_color != record["garment_color"]):
					appearance_swaps += 1
			else:
				# Keep only the old appearance while the next one loads. The visible
				# body's place, pose, custom data and attachments still follow this frame.
				var kept_over: Dictionary = {"shell": last_shell, "colour": last_garment_color}
				record = _sight_draw(pose_z, last_b, wanted_look, kept_over, last_garment, last)
			# Sight owns the latest pose even offscreen or while waiting for a draw slot.
			seen_draw_next[id] = record
		if shown <= 0.0 or record.is_empty():
			continue
		# Unseen frames retain the last in-sight values without refreshing them.
		if not last.is_empty():
			seen_draw_next[id] = last
		var draw_transform: Transform3D = record["transform"]
		if not in_sight_frustum(planes, draw_transform.origin):
			continue
		var b: int = int(record["b"])
		var look: String = record["look"]
		var n: int = counts[b][look]
		if n >= MAX_DRAW:
			if not overflow.has(b):
				overflow[b] = {}
			var body_overflow: Dictionary = overflow[b]
			if not body_overflow.has(look):
				var candidates: Array[int] = []
				# The ordinary path already drew these ids; collect only once the slot overflows.
				for drawn_id: int in drawn_at:
					var drawn_record: Dictionary = seen_draw_next[drawn_id]
					if int(drawn_record["b"]) == b and String(drawn_record["look"]) == look:
						candidates.append(drawn_id)
				body_overflow[look] = candidates
			(body_overflow[look] as Array).append(id)
			continue
		attachments = _submit_sight_draw(id, record, shown, counts, attachments)
	var redraw: bool = false
	for b: int in overflow:
		for look: String in overflow[b]:
			var candidates: Array = overflow[b][look]
			var player_at: Vector3 = game.player.position
			candidates.sort_custom(func(left: int, right: int) -> bool:
				var left_was_submitted: bool = _submitted_last.has(left)
				var right_was_submitted: bool = _submitted_last.has(right)
				if left_was_submitted != right_was_submitted:
					return left_was_submitted
				# Use the cached position so an unseen move cannot change draw priority.
				var left_at: Vector3 = seen_draw_next[left]["at"]
				var right_at: Vector3 = seen_draw_next[right]["at"]
				var left_distance: float = player_at.distance_squared_to(left_at)
				var right_distance: float = player_at.distance_squared_to(right_at)
				return left_distance < right_distance if left_distance != right_distance else left < right
			)
			for rank: int in candidates.size():
				var id: int = int(candidates[rank])
				if rank < MAX_DRAW:
					if not drawn_at.has(id):
						var selected_transform: Transform3D = seen_draw_next[id]["transform"]
						drawn_at[id] = selected_transform.origin
						redraw = true
				else:
					if _submitted_last.has(id):
						cap_drops += 1
					shown_next[id] = 0.0   # a newcomer waits here, then fades in from zero
					if drawn_at.erase(id):
						redraw = true
	if redraw:
		# Selection changed: repack bodies, shared garments and attachments together.
		var selected_ids: Array = drawn_at.keys()
		drawn_at.clear()
		garments_drawn.clear()
		_submitted_markers.clear()
		attachments = Vector2i.ZERO
		for b: int in counts.size():
			for look: String in counts[b]:
				counts[b][look] = 0
		for id: int in selected_ids:
			attachments = _submit_sight_draw(id, seen_draw_next[id], float(shown_next[id]), counts, attachments)
	# Snapshot only the final submission, never the provisional overflow pass.
	_submitted_last = drawn_at.duplicate()
	_shown = shown_next
	_last_seen_draw = seen_draw_next
	_held_frames = held_next
	_rendered_once = true
	DeadBody.rounds = body_rounds[0]
	if embedded_draw != null:
		embedded_draw.multimesh.visible_instance_count = attachments.y
	drawn_count = 0
	for b in draws.size():
		for look in counts[b]:
			if not (draws[b] as Dictionary).is_empty():
				draws[b][look].multimesh.visible_instance_count = counts[b][look]
			if look != "corpse":
				drawn_count += counts[b][look]
		for kind: String in wear_draws[b]:
			if wear_draws[b][kind] != null:
				(wear_draws[b][kind] as MultiMeshInstance3D).multimesh.visible_instance_count = (garments_drawn.get(wear_draws[b][kind], []) as Array).size()
	markers.multimesh.visible_instance_count = attachments.x
