extends Node3D
## How the field's living people look: a baked body (models/people) in place of
## the capsule and ball, drawn with the dead's shader (person_vat.gdshader: the
## dead's dead_vat.gdshaderinc, with what is worn in its own look). It
## only reads the people (where they are, which way they face, what their body
## and hands are doing) and decides nothing.
## Two multimeshes wear the same body: one with the living's own motions
## (OWN_FOLDER: walking, running, standing, crouched, held, bitten, the shove,
## the blows, the hands' jobs, aiming, the falls, the crawl, getting up and
## reeling spent), one with the dead's folder for a build whose people folder
## has no such motion (and the struck pose). Each person is in one of them at a
## time; a change between the two is not eased.
## The weapon in the hand is put in the worn body's right hand (found in the
## baked motions); a gun aimed standing still is held out in that hand, kicking
## back as person_pose.gd has it. Being loaded or cleared, or aimed on the
## move, person_pose.gd still holds it.
## The capsule, the ball and the arm boxes are hidden while a body is worn; the
## weapon box stays, since the blows are still drawn with it (person_pose.gd).
## With the switch off, or no baked folder in the build, nothing is drawn here
## and the people keep their boxes.
## Each person wears a body of their own (body_cast.gd), each body with its own
## two multimeshes (and its garments', WEAR_TINTS), read in the first time
## someone wears it. FOLDER and
## OWN_FOLDER are the body worn when a person's own is not in the build.
## What they wear is drawn in its own look, person by person, from the
## multimeshes' own colour of each one (person_vat.gdshader): a garment's
## colour and pattern (wear.gd look), and the gloves painted on the hands the
## body's mesh has marked (body_bake.gd hand_marks).

const BodyBake = preload("res://scripts/body_bake.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const Pose = preload("res://game/actors/person_pose.gd")
const SearchHeight = preload("res://game/actors/search_height.gd")
const InjuryRules = preload("res://game/sim/injury_rules.gd")
const BodyCast = preload("res://game/actors/body_cast.gd")
const Wear = preload("res://game/sim/wear.gd")

const FOLDER: String = "res://models/people/n5-crew_seamstress"
const OWN_FOLDER: String = "res://models/people/n5-crew_seamstress_p"
const SETTING: String = "visuals/baked_people_enabled"
const MAX_PEOPLE: int = 32
const READS_PER_FRAME: int = 1           # bodies read in a frame (worn_of)
## How many bodies a scene's people wear at most (body_cast.gd pick `cap`; 0 is
## one each). For a phone that cannot hold every body's pictures: past it, a
## new person wears the body fewest wear.
const BODIES_SETTING: String = "visuals/people_bodies_max"
## What is worn over the body (decision 423 card 2, #564): each look is a
## shell baked with the own folder's motions (wear/<id>), drawn in the colour
## and pattern of the garment worn (it has no picture; wear.gd look, decision
## 434): dark and cold, as the snow wants. Here the colour a shell has when a
## garment brings none. Each body's own folder has its own, baked against that
## body; a body without them is drawn without (the values still count, wear.gd).
## The gloves are painted on the body's marked hands by the shader, in its own
## folder's motions and the dead's alike.
const WEAR_TINTS: Dictionary = {"jacket_short": Vector3(0.1, 0.11, 0.14), "coat_long": Vector3(0.12, 0.1, 0.085),
	"hat_knit": Vector3(0.17, 0.12, 0.1), "hood": Vector3(0.13, 0.135, 0.14)}
## The bags worn on the back (carry.gd BAGS, body_bake.gd BAG_SHELLS), drawn as a
## garment is: everyday colours, worn canvas brown and a faded blue.
const BAG_TINTS: Dictionary = {"pack": Vector3(0.15, 0.11, 0.075), "big_pack": Vector3(0.075, 0.095, 0.13)}
## A garment's pattern as the shader numbers it (person_vat.gdshader worn_look).
const PATTERNS: Dictionary = {"plain": 0, "check": 1, "knit": 2, "quilt": 3}
const SHADER: Shader = preload("res://game/actors/person_vat.gdshader")
# Motion numbers, in the order body_bake.gd bakes them (dead_body.gd names them).
const WALK: int = 0
const STAND: int = DeadBody.STAND
const LUNGE: int = DeadBody.LUNGE
const FALL: int = DeadBody.FALL
const RUN: int = DeadBody.RUN
const FALL_FRONT: int = DeadBody.FALL_FRONT
const CRAWL: int = DeadBody.CRAWL
const RISE: int = DeadBody.RISE
const STAGGER: int = DeadBody.STAGGER
const HIT: int = DeadBody.HIT
const RISE_FRONT: int = DeadBody.RISE_FRONT
const TELL: int = DeadBody.TELL
const SHADE: float = 1.0
const STRIDE_CAP: float = 0.5            # more than this between two drawings is not a step
const STILL_AFTER: float = 0.2           # stands once it has kept its place this long
# Held by the dead (after the reference game's struck state, 상태표 2.3): the arms
# out against them (the lunge's reach), leaning back from one in front and
# bent under one behind, twisting to get free.
const HELD_LEAN: Vector2 = Vector2(-0.2, 0.22)   # in front, behind
const HELD_TWIST: Vector2 = Vector2(0.12, 0.2)   # sideways roll, turn about the spine
const HELD_HZ: float = 2.6
# Hurt (bitten, scratched, cut, shot): the struck pose and the body thrown
# back, easing out. A bite throws it furthest.
const HURT_TIME: float = 0.45
const HURT_LEAN: Dictionary = {"bite": -0.35, "": -0.2}
# The blow throws the body away from where it came: back from one in front,
# forward from one behind, over to the far side from one at the side (the
# reference game picks its struck motion by the striker's side). What struck
# it is the nearest of the dead holding it; with none, it came from in front.
const HURT_SIDE_ROLL: float = 0.6        # of the lean, rolled away from one at the side
# Turning where it stands, the feet step round instead of the body spinning on
# them (the reference game steps its turns in place): a turn of one radian goes
# TURN_FOOT metres round the walk, so a half turn is about two steps.
const TURN_FOOT: float = 0.35
const TURN_HOLD: float = 0.15            # it keeps stepping this long after the turn stops
const TURN_MIN: float = 0.002            # less than this between two drawings is not a turn
const TURN_CAP: float = 1.2              # more than this at once is a snap round, not stepped
# The living's own motions in OWN_FOLDER, by name; where the build has no such
# folder, the dead's that read closest. Crouched (the reference game's sneak: its
# own stand and walk) it stands low as the dead do before they run, and walks
# the bent shuffle. A note keeps an own motion as OWN_BASE + its number, so it
# is never taken for one of the dead's.
const OWN_WALK: String = "p_walk"
const OWN_RUN: String = "p_run"
const OWN_STAND: String = "p_stand"
const OWN_CROUCH_WALK: String = "p_crouch_walk"
const OWN_CROUCH_STAND: String = "p_crouch_idle"
const OWN_HELD: String = "p_held"
const OWN_BITTEN: String = "p_bitten"
const OWN_SHOVE: String = "p_shove"
# Down, crawling, getting up and reeling spent in the living's own (people
# folder 16-21; VatBaker.pack_motion carries them to the shader).
const OWN_FALL: String = "p_fall"
const OWN_FALL_FRONT: String = "p_fall_front"
const OWN_FALL_SLUMP: String = "p_fall_slump"
const OWN_CRAWL: String = "p_crawl"
const OWN_RISE: String = "p_rise"
const OWN_RISE_FRONT: String = "p_rise_front"
const OWN_SPENT: String = "p_spent"
# Loading or clearing a handgun standing still (people folder 26, from UAL). A
# long gun turns over in the hand in it, so it is held as person_pose.gd has it.
const OWN_RELOAD: String = "p_reload"
const OWN_BASE: int = 100
# Easing into each own motion: the reference game's own blend-in times:
# walk, stand 0.2, run 0.35, sneak walk 0.5 and low 0.4, bitten 0.2, shove
# 0.2, a melee blow 0.15, rummaging low 0.5, a bandage 0.2, aiming 0.3, falling and
# getting up 0.2. Rummaging at chest height has none of its own: its commonest, 0.2.
const OWN_MIX: Dictionary = {"p_walk": 0.2, "p_stand": 0.2, "p_crouch_walk": 0.5, "p_crouch_idle": 0.4,
	"p_bitten": 0.2, "p_shove": 0.2, "p_swing_one": 0.15, "p_swing_axe": 0.15, "p_stab": 0.15,
	"p_swing_back": 0.15, "p_chop_side": 0.15,
	"p_search_mid": 0.2, "p_search_low": 0.5, "p_treat": 0.2, "p_aim_one": 0.3, "p_aim_two": 0.3,
	"p_fall": 0.2, "p_fall_front": 0.2, "p_fall_slump": 0.2, "p_crawl": 0.2, "p_rise": 0.2, "p_rise_front": 0.2,
	"p_floor_strike": 0.15, "p_stomp": 0.2, "p_kick": 0.2, "p_pry": 0.2,
	"p_reload": 0.2, "p_kneel_work": 0.5,
	"p_search_high": 0.2, "p_treat_head": 0.2, "p_treat_arm": 0.2, "p_treat_leg": 0.2,
	"p_limp_light": 0.2, "p_limp_heavy": 0.2, "p_limp_light_l": 0.2, "p_limp_light_r": 0.2,
	"p_limp_heavy_l": 0.2, "p_limp_heavy_r": 0.2, "p_bitten_front": 0.2, "p_bitten_back": 0.2,
	"p_shiver": 0.3, "p_pain_head": 0.3, "p_pain_torso": 0.3, "p_pain_arm": 0.3, "p_pain_leg": 0.3,
	"p_tired_stretch": 0.3}
# Decision 422 (the gaps in the motions), each only where the folder has it and
# otherwise as before: a leg that hurts limps (splinted broken or cut deep, the
# heavy limp; festering or lightly cut, the light one; a side's own if there is
# one, `_l`/`_r`), a wound is treated where it is (head and body, an arm, a leg;
# someone else's knelt by), a bite or blow from in front or behind has its own
# flinch, and standing still now and then the body shows how it is: hurting,
# cold, tired, in that order, each person at their own time (MOOD_EVERY).
const OWN_LIMP: Dictionary = {"heavy": "p_limp_heavy", "light": "p_limp_light"}
const OWN_TREAT: Dictionary = {"head_neck": "p_treat_head", "torso": "p_treat_head", "arm": "p_treat_arm", "leg": "p_treat_leg"}
const OWN_TREAT_OTHER: String = "p_kneel_work"
const OWN_BITTEN_FRONT: String = "p_bitten_front"
const OWN_BITTEN_BACK: String = "p_bitten_back"
const OWN_PAIN: Dictionary = {"head_neck": "p_pain_head", "torso": "p_pain_torso", "arm": "p_pain_arm", "leg": "p_pain_leg"}
const OWN_SHIVER: String = "p_shiver"
const OWN_TIRED: String = "p_tired_stretch"
const MOOD_EVERY: Vector2 = Vector2(9.0, 15.0)
const MOOD_LOOP: float = 3.0          # a shiver (a motion that goes round) is kept up this long
const PAIN_SHOWN: float = 0.25        # it hurts this much in all (body_state.gd pain) before it is shown
# Aiming a gun standing still (as the reference game aims a handgun and a rifle): one hand
# out for a handgun, the long gun up at the shoulder. A bow has none of its own yet.
const OWN_AIMS: Dictionary = {"one": "p_aim_one", "two": "p_aim_two"}
# A timed job of the hands (as in the reference game: the hands' own motions over the
# standing, by how high the work is): the own motion and how fast it goes
# round. 0 plays it once over the job: a window is broken with one blow. A bar
# is worked back and forth, the pickaxe comes down in front of the feet, work on
# the ground is done kneeling. Climbing has none that stays on the ground (UAL's
# p_climb lifts the feet off it in place).
const OWN_WORK: Dictionary = {
	"search": ["p_search_mid", 1.0], "inspect": ["p_search_mid", 1.0], "door": ["p_search_mid", 1.0],
	"pry": ["p_pry", 1.0], "pick": ["p_search_mid", 1.0], "glass": ["p_search_mid", 1.0],
	"salvage": ["p_search_mid", 1.0], "repair": ["p_search_mid", 1.0], "wall": ["p_search_mid", 1.0],
	"craft": ["p_search_mid", 1.0], "swap": ["p_search_mid", 0.8],
	"loot": ["p_kneel_work", 1.0], "fire": ["p_kneel_work", 1.0], "snow": ["p_search_low", 1.0],
	"lid": ["p_kneel_work", 1.0],
	"treat": ["p_treat", 1.0], "splint": ["p_kneel_work", 1.0], "rub": ["p_treat", 1.0],
	"dig": ["p_floor_strike", 0.8], "window": ["p_swing_one", 0.0],
	"wear": ["p_wear_outer", 0.0],
}
# A melee blow in the living's own motions: the ways each weapon is swung, and
# where in each the blow lands (body_bake.gd keys; for UAL's chop, where the
# right hand goes fastest) and, if not at its end, where the way back stops
# (the chop is a loop that lifts the axe again: it stops with the axe low, so
# the next way does not drop the arm and lift it once more). Blow after blow goes through them in turn, so the
# same one is not seen twice running (decision 411): the reference game swings a
# one-handed weapon across, overhead or up from below and mixes three swings
# across, and a hand-to-hand mod for it changes hands each blow. A knife stabs, then cuts
# across; an axe comes down from overhead, then chops in from the side; the
# rest swing across, back the other way, then come down from overhead.
# A blow at a body on the ground is struck down in front of the feet, and a
# stomp drives the heel into it.
const OWN_BLOWS: Dictionary = {
	"one": [["p_swing_one", 0.45], ["p_swing_back", 0.45], ["p_swing_axe", 0.45]],
	"axe": [["p_swing_axe", 0.45], ["p_chop_side", 0.16, 0.45]],
	"stab": [["p_stab", 0.35], ["p_swing_one", 0.45]],
	"floor": [["p_floor_strike", 0.5]], "stomp": [["p_stomp", 0.5]]}
# A blow drawn back within this long of the last one ending goes on to the next
# way; after a longer rest it starts again from the first.
const CHAIN_GAP: float = 1.0
# A door kick, and where in it the foot lands (body_bake.gd p_kick at 0.4): the
# leg comes up over the last WIND of the try so it lands as the door is struck.
const OWN_KICK: Array = ["p_kick", 0.4]
const KICK_WIND: float = 0.36
# The right hand: with both arms thrown straight out (p_shove at 0.4) the
# furthest forward vertex on the right (-x: the body faces +z, as the right
# arm's bones are turned in body_bake.gd) and those within HAND_R of it; the
# elbow those within ELBOW_R of a point FOREARM behind it.
const HAND_R: float = 0.1
const ELBOW_R: float = 0.05
const ELBOW_SPARE: float = 0.02
const FOREARM: float = 0.32
const GRIP_FOLLOW: float = 0.5           # how far the weapon turns toward the hand's way each frame
const OWN_MIX_TIME: float = 0.35
# The own shove's arms are back at 0.3 of it and out at 0.4 (body_bake.gd p_shove):
# drawn back over the rules' wind-up, out as it lands, half back by the lunge's end.
const SHOVE_OUT: Vector2 = Vector2(0.4, 0.7)
const CROUCH_WALK: int = 1                       # walk_b: bent over, both feet barely leaving the ground
const CROUCH_LOW: Vector2 = Vector2(0.87, 0.97)  # where in the tell it is held, breathing between the two
const STAND_PACE: Vector2 = Vector2(0.85, 1.15)  # each person stands at their own pace, from their own place in it

var game                                 # field_game.gd
var vat: Dictionary = {}
var draw: MultiMeshInstance3D
var notes: Dictionary = {}               # person -> what it was last drawn as
var table: Array = []                    # the worn body's motions, for easing between them (dead_body.gd mix_from)
var own_vat: Dictionary = {}             # the same body with the living's own motions
var own_draw: MultiMeshInstance3D
var own_table: Array = []
var own_mix: Dictionary = {}             # own motion number -> how long a change into it is eased
var own_frames: Array = []               # the own folder's table, for the hand (dead_body.gd table_of)
var frames: Array = []                   # the dead folder's
var wear_draws: Dictionary = {}          # look id -> its multimesh once worn (garment_of; null: none), FOLDER / OWN_FOLDER's
var worn: Dictionary = {}                # body -> its pictures and what is read off them (_dress); "" is FOLDER / OWN_FOLDER
var body_by: Dictionary = {}             # person -> the body they wear (body_cast.gd)
var taken: Dictionary = {}               # body -> how many in this scene wear it


func setup(field_game) -> void:
	game = field_game
	process_priority = 100               # after field_game has set every person's view
	if not enabled():
		return
	var d := _dress(FOLDER, OWN_FOLDER)
	if d.is_empty():
		return
	worn[""] = d
	vat = d["vat"]
	draw = d["draw"]
	table = d["table"]
	own_vat = d["own_vat"]
	own_draw = d["own_draw"]
	own_table = d["own_table"]
	own_mix = d["own_mix"]
	own_frames = d["own_frames"]
	frames = d["frames"]
	wear_draws = d["wear"]


## One body's two pictures: the dead's folder (the struck pose, and a build
## whose own folder lacks a motion) and the living's own, each in a multimesh,
## with the tables, eases and the right hand read off them. A folder with no
## colour picture of its own is drawn with the other's. What is worn over it is
## read in when first worn (garment_of).
func _dress(dead_dir: String, own_dir: String) -> Dictionary:
	var dead_look := dead_dir if ResourceLoader.exists(dead_dir.path_join(DeadBody.ALBEDO_FILE)) else own_dir
	var dead := DeadBody.with_albedo(BodyBake.load_baked(dead_dir), dead_look)
	if dead.is_empty():
		return {}
	var d := {"vat": dead, "draw": _wear(dead), "table": [], "own_vat": {}, "own_draw": null,
		"own_table": [], "own_mix": {}, "own_frames": [], "frames": [], "wear": {},
		"wear_dir": own_dir.path_join("wear"), "n": 0, "k": 0, "worn_n": {}}
	if DeadBody.can_mix():
		d["table"] = DeadBody.table_of(dead)
	var own := DeadBody.with_albedo(BodyBake.load_baked(own_dir), own_dir)
	if own.is_empty():
		return d
	d["own_vat"] = own
	d["own_draw"] = _wear(own)
	var clips: Array = own.get("clips", [])
	for n in clips.size():
		d["own_mix"][n] = float(OWN_MIX.get(String(clips[n].get("name", "")), OWN_MIX_TIME))
	if DeadBody.can_mix():
		d["own_table"] = DeadBody.table_of(own)
	d["own_frames"] = DeadBody.table_of(own)
	var arm := hand_of(own)
	if not arm.is_empty():
		own["arm"] = arm_table(own, arm["hand"], arm["elbow"])
		if int(dead.get("vertices", 0)) == int(own.get("vertices", -1)):
			dead["arm"] = arm_table(dead, arm["hand"], arm["elbow"])
			d["frames"] = DeadBody.table_of(dead)
	return d


## One garment over a body (WEAR_TINTS), read in the first time someone in that
## body wears it: the short coat everyone starts in comes with nearly every
## body, the rest only when worn, so a phone holds what is on show (a body's
## four are more than half the body again). null when this body has none of
## that kind.
func garment_of(d: Dictionary, kind: String) -> MultiMeshInstance3D:
	var wear: Dictionary = d["wear"]
	if not wear.has(kind):
		var shell := BodyBake.load_baked(String(d["wear_dir"]).path_join(kind)) if WEAR_TINTS.has(kind) or BAG_TINTS.has(kind) else {}
		wear[kind] = _wear(shell, true) if not shell.is_empty() else null
	return wear[kind]


## The body one person wears, picked the first time they are drawn and read in
## the first time anyone wears it; FOLDER / OWN_FOLDER's when theirs is not in
## the build. {} when it is not read in yet and `may_read` is false.
func worn_of(p, may_read: bool = true) -> Dictionary:
	if not body_by.has(p):
		body_by[p] = BodyCast.pick(String(p.pid), String(p.role), taken, int(ProjectSettings.get_setting(BODIES_SETTING, 0)))
	var body: String = body_by[p]
	if not worn.has(body):
		if not may_read:
			return {}
		var d := {}
		if ResourceLoader.exists(BodyCast.own_folder(body).path_join("clips.json")):
			d = _dress(BodyCast.dead_folder(body), BodyCast.own_folder(body))
		worn[body] = d if not d.is_empty() and d["own_draw"] != null else worn[""]
	return worn[body]


## One multimesh wearing a baked folder: a body, gloved by the shader where its
## mesh has the hands marked, or a garment (in the look of the one worn), each
## person in their own colour (use_colors: hands_colour, looks_on).
func _wear(baked: Dictionary, garment: bool = false) -> MultiMeshInstance3D:
	var one := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	var mesh: Mesh = baked["mesh"]
	var marked := not garment and hands_marked(mesh)
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = garment or marked
	mm.mesh = mesh
	mm.instance_count = MAX_PEOPLE
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-5, -5, -5), Vector3(185, 16, 115))
	one.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("vat", baked["texture"])
	var tables := VatBaker.shader_tables(baked)
	for key in tables:
		mat.set_shader_parameter(key, tables[key])
	mat.set_shader_parameter("worn_look", garment)
	mat.set_shader_parameter("gloves", marked)
	if marked and mesh.has_meta(BodyBake.HAND_LIGHT) and float(mesh.get_meta(BodyBake.HAND_LIGHT)) > 0.0:
		mat.set_shader_parameter("glove_light", float(mesh.get_meta(BodyBake.HAND_LIGHT)))
	if DeadBody.can_mix():
		mat.set_shader_parameter("mixes", true)
	one.material_override = mat
	add_child(one)
	return one


## True when a baked body's mesh has its hands marked for the shader's gloves.
static func hands_marked(mesh: Mesh) -> bool:
	return mesh != null and mesh.get_surface_count() > 0 and (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0


static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING, true))


func is_worn() -> bool:
	return draw != null


func _process(delta: float) -> void:
	if draw == null:
		return
	for d: Dictionary in worn.values():
		d["n"] = 0
		d["k"] = 0
		d["worn_n"] = {}
	var count := 0
	# One body read in a frame (about a tenth of a second each on a PC): someone
	# whose body is not in yet is left out for the frames it takes.
	var reads := READS_PER_FRAME
	for p in game.people:
		_hide_boxes(p)
		if not p.visible or count >= MAX_PEOPLE:
			continue
		var had := worn.size()
		var d := worn_of(p, reads > 0)
		if worn.size() > had:
			reads -= 1
		if d.is_empty():
			continue
		count += 1
		var b_vat: Dictionary = d["vat"]
		var b_own: Dictionary = d["own_vat"]
		var b_own_frames: Array = d["own_frames"]
		var b_frames: Array = d["frames"]
		var mm: MultiMesh = d["draw"].multimesh
		var own_mm: MultiMesh = d["own_draw"].multimesh if d["own_draw"] != null else null
		var n: int = d["n"]
		var k: int = d["k"]
		var note: Dictionary = notes.get(p, {})
		notes[p] = note
		var c := motion_of(p, note, delta, b_vat.get("clips", []), b_own.get("clips", []))
		var look := Color(c.x, c.y, 1.0, SHADE)
		var at := Transform3D(Basis(Vector3.UP, p.rotation.y) * lean_of(p, note), p.global_position)
		var own := is_own(note)
		# A change of folder cannot be eased: the frame it was in is in the other picture.
		if own != bool(note.get("drawn_own", own)):
			note.erase("mix_own" if own else "mix_dead")
		note["drawn_own"] = own
		var mix: Dictionary = note.get_or_add("mix_own" if own else "mix_dead", {})
		var drawn: Color
		if own:
			drawn = DeadBody.mix_from(mix, look, float(note["t"]), d["own_table"], d["own_mix"])
			own_mm.set_instance_transform(k, at)
			own_mm.set_instance_custom_data(k, drawn)
			if own_mm.use_colors:
				own_mm.set_instance_color(k, hands_colour(p))
			d["k"] = k + 1
			# What they wear moves with the body: the same place, the same frame.
			var worn_n: Dictionary = d["worn_n"]
			for worn_look: Dictionary in looks_on(p) + bag_on(p):
				var kind: String = worn_look["shell"]
				var garment := garment_of(d, kind)
				if garment != null:
					var w: int = int(worn_n.get(kind, 0))
					var wmm: MultiMesh = garment.multimesh
					wmm.set_instance_transform(w, at)
					wmm.set_instance_custom_data(w, drawn)
					wmm.set_instance_color(w, worn_look["colour"])
					worn_n[kind] = w + 1
		else:
			drawn = DeadBody.mix_from(mix, look, float(note["t"]), d["table"])
			mm.set_instance_transform(n, at)
			mm.set_instance_custom_data(n, drawn)
			if mm.use_colors:
				mm.set_instance_color(n, hands_colour(p))
			d["n"] = n + 1
		var baked: Dictionary = b_own if own else b_vat
		if baked.has("arm") and (not gun_busy(p) or (own and loading(note, b_own.get("clips", [])))):
			var hand := arm_at(baked["arm"], b_own_frames if own else b_frames, drawn)
			var grip := grip_of(hand[0], hand[1], note.get("grip", Basis()))
			note["grip"] = grip
			var lean := lean_of(p, note)
			p.weapon_mesh.transform = Transform3D(lean * grip, lean * hand[0])
		elif baked.has("arm") and own and aiming(note, b_own.get("clips", [])):
			# The gun in the hand held out, the muzzle ahead, kicking back as it fires
			# as person_pose.gd has it (its aim less where it would hold it still).
			var hand := arm_at(baked["arm"], b_own_frames, drawn)
			var hold := Pose.hold_of(p.weapon_id())
			var still: Vector3 = Pose.aim_at(hold)["weapon"]["pos"]
			var shot: Dictionary = Pose.aim_at(hold, Pose._kick(p, Time.get_ticks_msec()))["weapon"]
			var lean := lean_of(p, note)
			p.weapon_mesh.transform = Transform3D(lean * Basis.from_euler(shot["rot"]), lean * (hand[0] + shot["pos"] - still))
	for d: Dictionary in worn.values():
		d["draw"].multimesh.visible_instance_count = d["n"]
		if d["own_draw"] != null:
			d["own_draw"].multimesh.visible_instance_count = d["k"]
		for kind: String in d["wear"]:
			if d["wear"][kind] != null:
				(d["wear"][kind] as MultiMeshInstance3D).multimesh.visible_instance_count = int(d["worn_n"].get(kind, 0))


## The looks one person wears over the body: the shell of the outermost layer
## over the body and of what is on the head (wear.gd shells, decision 434).
static func looks_of(p) -> Array[String]:
	var out: Array[String] = []
	for worn_look: Dictionary in looks_on(p):
		out.append(String(worn_look["shell"]))
	return out


## The same looks, each with the colour the shader draws it in (person_vat.gdshader
## worn_look): the garment's own (wear.gd look), rgb as tint is, its pattern in
## alpha (PATTERNS, thirds). The garment drawn over the body is the outermost
## of coat and jacket that has a shell, then what is on the head (as wear.gd
## shells picks them); a shell with no garment colour takes WEAR_TINTS'.
static func looks_on(p) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: String in ["coat", "jacket"]:
		if p.worn.has(s):
			var outer := _look_of(String(p.worn[s].get("id", "")))
			if not outer.is_empty():
				out.append(outer)
				break
	if p.worn.has("head"):
		var hat := _look_of(String(p.worn["head"].get("id", "")))
		if not hat.is_empty():
			out.append(hat)
	return out


## The bag on the back as looks_on gives a garment ({shell, colour}, plain), none
## with pockets only (person.gd bag).
static func bag_on(p) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var kind := String(p.bag)
	if BAG_TINTS.has(kind):
		var c: Vector3 = BAG_TINTS[kind]
		out.append({"shell": kind, "colour": Color(c.x, c.y, c.z, 0.0)})
	return out


## {shell, colour} of one garment kind drawn over the body, {} for one that is not.
static func _look_of(id: String) -> Dictionary:
	var look := Wear.look(id)
	var shell := String(look["look_shell"])
	if not WEAR_TINTS.has(shell):
		return {}
	var tint: Array = look["look_tint"]
	var c: Vector3 = WEAR_TINTS[shell]
	if tint.size() == 3:
		c = Vector3(float(tint[0]), float(tint[1]), float(tint[2]))
	var pattern := int(PATTERNS.get(String(look["look_pattern"]), 0))
	return {"shell": shell, "colour": Color(c.x, c.y, c.z, float(pattern) / 3.0)}


## The gloves one person has on, as the shader paints them on the marked hands
## (person_vat.gdshader gloves): rgb as the colour picture would hold them once
## read (linear), the kind's own colour where it has one, else the dark worn
## wool the gloved picture had (BodyBake.GLOVE_COLOUR); alpha 1 gloved, 0 bare.
static func hands_colour(p) -> Color:
	if not p.worn.has("hands"):
		return Color(0.0, 0.0, 0.0, 0.0)
	var tint: Array = Wear.look(String(p.worn["hands"].get("id", "")))["look_tint"]
	var c := BodyBake.GLOVE_COLOUR.srgb_to_linear()
	if tint.size() == 3:
		c = Color(float(tint[0]), float(tint[1]), float(tint[2]))
	c.a = 1.0
	return c


func _hide_boxes(p) -> void:
	p.body_mesh.visible = false
	p.head_mesh.visible = false
	# The arm boxes, and the foot box a door kick shows (the worn body kicks with
	# its own leg).
	for box in p.get_meta(Pose.META, []):
		box.visible = false


## The motion one person is in (y) and how far through it (x), from what the
## rules say about them. `note` keeps what it was last drawn as, so a walk goes
## by the ground covered and a fall plays once from where it started. `own` is
## the living's own folder's motions: when y is one of those, is_own(note).
static func motion_of(p, note: Dictionary, delta: float, clips: Array, own: Array = []) -> Vector2:
	var t: float = float(note.get("t", 0.0)) + delta
	note["t"] = t
	var at: Vector3 = p.global_position
	var gone: float = at.distance_to(note.get("at", at))
	note["at"] = at
	_note_hurt(p, note, t)
	# Noted every drawing, so a turn made in another motion (aiming, a blow) is not stepped later.
	var turned := _turned(p, note, t)
	var lying: bool = p.body.downed or p.body.dead or p.fallen_t > 0.0
	if lying:
		# Dead or knocked down it goes over on its back; down and still alive
		# (or slipped) it lies on its face, where it can still drag itself;
		# half of them slump on their face either way (fall_name).
		var own_crawl := clip_named(own, OWN_CRAWL, -1)
		if p.body.downed and not p.body.dead and gone > 0.01:
			if own_crawl >= 0:
				note["motion"] = OWN_BASE + own_crawl
				return Vector2(_round(note, "crawl", gone, _round_of(own, own_crawl, 0.41)), own_crawl)
			return Vector2(_round(note, "crawl", gone, _round_of(clips, CRAWL, 0.61)), CRAWL)
		var own_down := clip_named(own, fall_name(p, own), -1)
		if own_down >= 0:
			if int(note.get("motion", -1)) == OWN_BASE + own_crawl:
				# Stopped dragging itself: still down, not falling again.
				note["motion"] = OWN_BASE + own_down
				note["since"] = t - _length(own, own_down, 1.0)
			return Vector2(_own_once(note, OWN_BASE + own_down, t, _length(own, own_down, 1.0)), own_down)
		var fall := FALL if p.body.dead else FALL_FRONT
		return Vector2(_once(note, fall, t, clips), fall)
	# Up again off the face it fell on (or crawled on), or off its back.
	var was: int = int(note.get("motion", -1))
	if was == FALL or was == FALL_FRONT:
		note["motion"] = RISE_FRONT if was == FALL_FRONT else RISE
		note["since"] = t
	elif was >= OWN_BASE and was - OWN_BASE < own.size():
		var down := String(own[was - OWN_BASE].get("name", ""))
		if down == OWN_FALL or down == OWN_FALL_FRONT or down == OWN_FALL_SLUMP or down == OWN_CRAWL:
			note["motion"] = OWN_BASE + clip_named(own, OWN_RISE if down == OWN_FALL else OWN_RISE_FRONT, -1)
			note["since"] = t
	var rise: int = int(note.get("motion", -1))
	if (rise == RISE or rise == RISE_FRONT) and t - float(note["since"]) < _length(clips, rise, 1.0):
		return Vector2((t - float(note["since"])) / _length(clips, rise, 1.0), rise)
	var own_rise := rise - OWN_BASE
	if own_rise >= 0 and own_rise < own.size() and (String(own[own_rise].get("name", "")) == OWN_RISE or String(own[own_rise].get("name", "")) == OWN_RISE_FRONT):
		if t - float(note["since"]) < _length(own, own_rise, 1.0):
			return Vector2((t - float(note["since"])) / _length(own, own_rise, 1.0), own_rise)
	var bitten := clip_named(own, bitten_name(note), -1)
	if bitten < 0:
		bitten = clip_named(own, OWN_BITTEN, -1)
	if bitten >= 0 and note.has("hurt_at") and t - float(note["hurt_at"]) < _length(own, bitten, 0.6):
		# Flinching, shoulders up and the head thrown back, then bracing.
		note["motion"] = OWN_BASE + bitten
		note["hurt_own"] = String(own[bitten].get("name", ""))
		return Vector2((t - float(note["hurt_at"])) / _length(own, bitten, 0.6), bitten)
	if not p.grabbers.is_empty():
		var held := clip_named(own, OWN_HELD, -1)
		if held >= 0:
			# Both arms pushing them off, twisting to get free.
			return Vector2(_own_cycle(note, OWN_BASE + held, t, _length(own, held, 1.0), p.name_unit("held")), held)
		# Held: the arms out against them, the legs shifting under it.
		note["motion"] = LUNGE
		return Vector2(fposmod(DeadBody.REACH_AT + DeadBody.REACH_SHIFT * sin(TAU * HELD_HZ * 0.5 * t), 1.0), LUNGE)
	if bitten < 0 and hurt_k(note, t) > 0.0:
		note["motion"] = HIT
		return Vector2(0.0, HIT)
	var blow := blow_of(p, own, note, t)
	if blow.y >= 0.0:
		note["motion"] = OWN_BASE + int(blow.y)
		return blow
	if p.shove_t > 0.0 or p.lunge_t > 0.0:
		var shove := clip_named(own, OWN_SHOVE, -1)
		if shove >= 0:
			note["motion"] = OWN_BASE + shove
			var r := lerpf(SHOVE_OUT.x, SHOVE_OUT.y, 1.0 - clampf(p.lunge_t / Pose.LUNGE, 0.0, 1.0))
			if p.shove_t > 0.0:
				var wind: float = Pose.SHOVE_WINDUP / float(p.mults()["swing"])
				r = SHOVE_OUT.x * (1.0 - clampf(p.shove_t / maxf(wind, 0.01), 0.0, 1.0))
			return Vector2(r, shove)
		return Vector2(_cycle(note, LUNGE, t, clips), LUNGE)
	var work := work_of(p, note, t, own)
	if work.y >= 0.0:
		return work
	if gone > 0.001:
		note["moved"] = t
	var load := reload_of(p, note, t, own)
	if load.y >= 0.0 and t - float(note.get("moved", -10.0)) >= STILL_AFTER:
		return load
	var aim := aim_of(p, own)
	if aim >= 0 and t - float(note.get("moved", -10.0)) >= STILL_AFTER:
		return Vector2(_own_cycle(note, OWN_BASE + aim, t, _length(own, aim, 1.0), p.name_unit("aim")), aim)
	var unit: float = p.name_unit("stand")
	# Spent, it reels as the dead do (the living have no such motion of their own
	# yet), still reeling where it stops for breath.
	var spent: bool = not p.running and not p.crouched and p.body.exhaustion_level() >= 2
	var own_spent := clip_named(own, OWN_SPENT, -1) if spent else -1
	if spent and t - float(note.get("moved", -10.0)) >= STILL_AFTER:
		if own_spent >= 0:
			return Vector2(_own_cycle(note, OWN_BASE + own_spent, t, _length(own, own_spent, 1.0) * 2.0, unit), own_spent)
		return Vector2(_own_cycle(note, STAGGER, t, _length(clips, STAGGER, 1.0) * 2.0, unit), STAGGER)
	if t - float(note.get("moved", -10.0)) >= STILL_AFTER and t - float(note.get("turned", -10.0)) < TURN_HOLD:
		# Turning on the spot: the walk goes round by the turn, not by ground covered.
		var own_turn := clip_named(own, OWN_CROUCH_WALK if p.crouched else OWN_WALK, -1)
		var foot := turned * TURN_FOOT
		if own_turn >= 0:
			note["motion"] = OWN_BASE + own_turn
			return Vector2(_round(note, "step", foot, _round_of(own, own_turn, 1.2)), own_turn)
		var turn_gait := CROUCH_WALK if p.crouched else WALK
		note["motion"] = turn_gait
		return Vector2(_round(note, "step", foot, _round_of(clips, turn_gait, float(DeadBody.STRIDE.get(turn_gait, 1.2)))), turn_gait)
	if t - float(note.get("moved", -10.0)) >= STILL_AFTER:
		var mood := mood_of(p, note, t, own)
		if mood.y >= 0.0:
			return mood
		var own_stand := clip_named(own, OWN_CROUCH_STAND if p.crouched else OWN_STAND, -1)
		if own_stand >= 0:
			return Vector2(_own_cycle(note, OWN_BASE + own_stand, t, _length(own, own_stand, 1.0), unit), own_stand)
		if p.crouched:
			note["motion"] = TELL
			var breath := 0.5 + 0.5 * sin(TAU * (t / 3.5 + unit))
			return Vector2(lerpf(CROUCH_LOW.x, CROUCH_LOW.y, breath), TELL)
		return Vector2(_own_cycle(note, STAND, t, _length(clips, STAND, 1.0), unit), STAND)
	var own_gait := own_spent if spent else -1
	if not spent:
		own_gait = limp_of(p, own) if not p.running and not p.crouched else -1
	if not spent and own_gait < 0:
		own_gait = clip_named(own, OWN_RUN if p.running else (OWN_CROUCH_WALK if p.crouched else OWN_WALK), -1)
	if own_gait >= 0:
		note["motion"] = OWN_BASE + own_gait
		var stepped := _round(note, "step", gone, _round_of(own, own_gait, 1.2))
		var gait_name := String(own[own_gait].get("name", ""))
		if p.brain.has("step_r") and (gait_name == OWN_WALK or gait_name == OWN_RUN or gait_name == OWN_CROUCH_WALK):
			stepped = float(p.brain["step_r"])   # the feet land with the footsteps (field_game.gd steps_in)
		return Vector2(stepped, own_gait)
	var gait := WALK
	if p.running:
		gait = RUN
	elif p.crouched:
		gait = CROUCH_WALK
	elif spent:
		gait = STAGGER
	note["motion"] = gait
	return Vector2(_round(note, "step", gone, _round_of(clips, gait, float(DeadBody.STRIDE.get(gait, 1.2)))), gait)


## Which of the living's own falls a body goes down in: dead on its back,
## knocked down on its face, and half of the people (by their name, so always
## the same) slump on their face either way when the folder has it (decision 412).
static func fall_name(p, own: Array) -> String:
	if posmod(hash(String(p.pid)), 2) == 1 and clip_named(own, OWN_FALL_SLUMP, -1) >= 0:
		return OWN_FALL_SLUMP
	return OWN_FALL if p.body.dead else OWN_FALL_FRONT


## A melee blow in the living's own motions (y) and how far through it (x):
## drawn back up to where the blow lands while the rules wind it up, the rest
## on the way back. y is -1 with no blow, or none of its own. `note` keeps which
## way the last blow went and when it ended (at the visual's own time t).
static func blow_of(p, own: Array, note: Dictionary = {}, t: float = 0.0) -> Vector2:
	if own.is_empty():
		return Vector2(0.0, -1.0)
	var sw: Array = Pose.swing_state(p)
	if sw.is_empty():
		if note.get("blow_on", false):
			note["blow_on"] = false
			note["blow_drawing"] = false
			note["blow_end"] = t
			p.remove_meta(Pose.BLOW_WAY)
		return Vector2(0.0, -1.0)
	# A new blow is drawn back: on to the next way if it follows on from the last.
	var drawing: bool = not sw[2]
	if drawing and not note.get("blow_drawing", false):
		var follows: bool = note.get("blow_on", false) or (note.has("blow_end") and t - float(note["blow_end"]) <= CHAIN_GAP)
		note["blow_n"] = int(note.get("blow_n", -1)) + 1 if follows else 0
	note["blow_drawing"] = drawing
	note["blow_on"] = true
	var mode: String = p.get_meta(Pose.MODE, "swing")
	var kind := "one"
	if mode == "stomp" or mode == "floor":
		kind = mode
	elif p.weapon_id() == "axe":
		kind = "axe"
	elif p.weapon_id() == "knife":
		kind = "stab"
	var ways: Array = OWN_BLOWS[kind]
	var way: Array = ways[int(note.get("blow_n", 0)) % ways.size()]
	var clip := clip_named(own, String(way[0]), -1)
	if clip < 0:
		# A body baked before the later ways were added swings its first each time.
		way = ways[0]
		clip = clip_named(own, String(way[0]), -1)
	if clip < 0:
		return Vector2(0.0, -1.0)
	p.set_meta(Pose.BLOW_WAY, String(way[0]))   # what it strikes is seen thrown that way (dead_body.gd)
	var lands: float = way[1]
	var ends: float = way[2] if way.size() > 2 else 1.0
	var r: float = lands + (ends - lands) * float(sw[1]) if sw[2] else lands * float(sw[0])
	return Vector2(r, clip)


## A timed job of the hands in the living's own motions (y) and how far through
## it (x); y is -1 with no job, or none of its own.
static func work_of(p, note: Dictionary, t: float, own: Array) -> Vector2:
	if p.action == "" or p.action_t <= 0.0 or p.action_total <= 0.0:
		return Vector2(0.0, -1.0)
	if p.action == "kick":
		var kick := clip_named(own, String(OWN_KICK[0]), -1)
		if kick < 0:
			return Vector2(0.0, -1.0)
		var wind := minf(KICK_WIND, p.action_total)
		note["motion"] = OWN_BASE + kick
		return Vector2(float(OWN_KICK[1]) * clampf(1.0 - p.action_t / wind, 0.0, 1.0), kick)
	if not OWN_WORK.has(p.action):
		return Vector2(0.0, -1.0)
	if p.action == "wear":
		return wear_of(p, note, own)
	var work_name := String(OWN_WORK[p.action][0])
	if p.action == "search" and p.action_busy is Dictionary and p.action_busy.has("name"):
		work_name = SearchHeight.clip_of(p.action_busy)
	elif p.action == "treat":
		work_name = treat_name(p)
	# Crouched it keeps low (the reference game's sneaking jobs): chest-high work done low.
	if p.crouched and (work_name == "p_search_mid" or work_name == "p_search_high" or work_name == "p_pry"):
		work_name = "p_search_low"
	var clip := clip_named(own, work_name, -1)
	if clip < 0:
		# A folder without the new ways of it: the job's old motion.
		clip = clip_named(own, String(OWN_WORK[p.action][0]), -1)
	if clip < 0:
		return Vector2(0.0, -1.0)
	var pace: float = OWN_WORK[p.action][1]
	if pace <= 0.0:
		note["motion"] = OWN_BASE + clip
		return Vector2(clampf(1.0 - p.action_t / p.action_total, 0.0, 1.0), clip)
	return Vector2(_own_cycle(note, OWN_BASE + clip, t * pace, _length(own, clip, 1.0), p.name_unit("work")), clip)


## Putting a garment on plays its place's motion once over the job (wear.gd
## CLIP); taking it off plays it backwards.
static func wear_of(p, note: Dictionary, own: Array) -> Vector2:
	var slot: String = String(p.action_busy.get("slot", "jacket"))
	var clip := clip_named(own, String(Wear.CLIP.get(slot, Wear.CLIP["jacket"])), -1)
	if clip < 0:
		return Vector2(0.0, -1.0)
	note["motion"] = OWN_BASE + clip
	var done := clampf(1.0 - p.action_t / p.action_total, 0.0, 1.0)
	return Vector2(1.0 - done if bool(p.action_busy.get("off", false)) else done, clip)


## Which of the living's own a treatment is drawn in: kneeling by someone else
## (field_actions.gd notes who, Pose.CARE), otherwise where the wound is that is
## being seen to (or, with none noted, the one that bleeds and hurts most).
static func treat_name(p) -> String:
	var care: Dictionary = p.get_meta(Pose.CARE, {})
	var noted: bool = not care.is_empty() and is_equal_approx(float(care.get("total", -1.0)), p.action_total) and String(care.get("label", "")) == p.action_label
	var other = care.get("of") if noted else null
	if other != null and is_instance_valid(other) and other != p:
		return OWN_TREAT_OTHER
	var part := String(care.get("part", "")) if noted else ""
	if part == "":
		part = sorest_part(p.body)
	return String(OWN_TREAT.get(coarse(part), OWN_WORK["treat"][0]))


## Where a body's worst wound is: the one bleeding most, then hurting most ("" with none).
static func sorest_part(body) -> String:
	var best := 0.0
	var part := ""
	for w: Dictionary in body.wounds:
		var k := float(w.get("blood", 0.0)) * 10.0 + InjuryRules.pain(w)
		if k > best:
			best = k
			part = String(w.get("part", ""))
	return part


## head_neck, torso, arm or leg.
static func coarse(part: String) -> String:
	if part.begins_with("arm_"):
		return "arm"
	if part.begins_with("leg_"):
		return "leg"
	return part


## The flinch for the last wound by where it came from: in front or behind,
## its own; from the side "" (the old one, thrown over to the far side).
static func bitten_name(note: Dictionary) -> String:
	var from: Vector2 = note.get("hurt_from", Vector2(0.0, 1.0))
	if absf(from.y) < absf(from.x):
		return ""
	return OWN_BITTEN_FRONT if from.y > 0.0 else OWN_BITTEN_BACK


## The limp a walking body has, in the living's own (-1: none, or none of its
## own). A broken leg not yet splinted is as before (the rules' crawl pace).
static func limp_of(p, own: Array) -> int:
	var how := ""
	var side := ""
	for w: Dictionary in p.body.wounds:
		var part := String(w.get("part", ""))
		if coarse(part) != "leg":
			continue
		var kind := String(w.get("kind", ""))
		var heavy: bool = (kind == "fracture" and bool(w.get("splinted", false))) or kind == "deep" or kind == "embedded"
		var light: bool = bool(w.get("festering", false)) or kind in ["scratch", "laceration", "bite"]
		if heavy and how != "heavy":
			how = "heavy"
			side = part
		elif light and how == "":
			how = "light"
			side = part
	if how == "":
		return -1
	var name := String(OWN_LIMP[how])
	var sided := clip_named(own, name + ("_l" if side.ends_with("left") else "_r"), -1)
	return sided if sided >= 0 else clip_named(own, name, -1)


## Standing still, now and then the body shows how it is (y; -1 the rest of
## the time, with nothing to show, or none of its own): its worst hurt held, a
## shiver in the cold, a stretch when tired. Once in MOOD_EVERY, each person at
## their own time and pace of it.
static func mood_of(p, note: Dictionary, t: float, own: Array) -> Vector2:
	if p.crouched or p.body.downed:
		return Vector2(0.0, -1.0)
	var name := ""
	if p.body.pain() >= PAIN_SHOWN:
		name = String(OWN_PAIN.get(coarse(sorest_part(p.body)), ""))
	if name == "" and p.heat.level() >= 1:
		name = OWN_SHIVER
	if name == "" and p.body.exhaustion_level() >= 1:
		name = OWN_TIRED
	var clip := clip_named(own, name, -1) if name != "" else -1
	if clip < 0:
		return Vector2(0.0, -1.0)
	var unit: float = p.name_unit("mood")
	var every := lerpf(MOOD_EVERY.x, MOOD_EVERY.y, unit)
	var at := fposmod(t + unit * every, every)
	var length := _length(own, clip, 1.0)
	var loops := bool(own[clip].get("loop", false))
	if at >= (maxf(length, MOOD_LOOP) if loops else length):
		return Vector2(0.0, -1.0)
	note["motion"] = OWN_BASE + clip
	return Vector2(fposmod(at / length, 1.0) if loops else at / length, clip)


## Loading or clearing the handgun in the hand in the living's own (y), how far
## through it (x): a load once over the gun's loading time, a jam round and
## round. y is -1 with neither, any other gun or a bow (held as person_pose.gd
## has it), or crouched (the motion is a standing one).
static func reload_of(p, note: Dictionary, t: float, own: Array) -> Vector2:
	var hold := Pose.hold_of(p.weapon_id())
	if hold != "one" or p.crouched or (p.reload_t <= 0.0 and p.jam_t <= 0.0):
		return Vector2(0.0, -1.0)
	var clip := clip_named(own, OWN_RELOAD, -1)
	if clip < 0:
		return Vector2(0.0, -1.0)
	if p.jam_t > 0.0:
		return Vector2(_own_cycle(note, OWN_BASE + clip, t, _length(own, clip, 1.0), p.name_unit("jam")), clip)
	note["motion"] = OWN_BASE + clip
	var total := float(Pose.W.get_data(p.weapon_id()).get("reload", 1.0))
	return Vector2(1.0 - clampf(p.reload_t / maxf(0.01, total), 0.0, 1.0), clip)


## Drawn loading or clearing in the own motion (note as motion_of left it).
static func loading(note: Dictionary, own: Array) -> bool:
	var m := int(note.get("motion", -1)) - OWN_BASE
	return m >= 0 and m < own.size() and String(own[m].get("name", "")) == OWN_RELOAD


## The own aiming motion for the gun in the hand while it is aimed, or -1.
## Crouched it stays low (the aiming motions are standing ones).
static func aim_of(p, own: Array) -> int:
	if not p.aim.active or p.crouched:
		return -1
	return clip_named(own, String(OWN_AIMS.get(Pose.hold_of(p.weapon_id()), "")), -1)


## Drawn in an own aiming motion (note as motion_of left it).
static func aiming(note: Dictionary, own: Array) -> bool:
	var m := int(note.get("motion", -1)) - OWN_BASE
	return m >= 0 and m < own.size() and OWN_AIMS.values().has(String(own[m].get("name", "")))


## A gun being aimed, loaded or cleared: person_pose.gd holds it there.
static func gun_busy(p) -> bool:
	if Pose.hold_of(p.weapon_id()) == "":
		return false
	return p.aim.active or p.reload_t > 0.0 or p.jam_t > 0.0


## The worn body's right hand and elbow vertices, found with both arms thrown
## straight out in p_shove; {} when the folder has no such motion.
static func hand_of(baked: Dictionary) -> Dictionary:
	var clips: Array = baked.get("clips", [])
	var shove := clip_named(clips, OWN_SHOVE, -1)
	if shove < 0:
		return {}
	var frame: int = int(clips[shove]["start"]) + int(roundf(0.4 * float(int(clips[shove]["frames"]) - 1)))
	var arrays: Array = (baked["mesh"] as Mesh).surface_get_arrays(0)
	var rest: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var look: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var at := PackedVector3Array()
	at.resize(rest.size())
	var tip := Vector3(0, 0, -99)
	for i in rest.size():
		at[i] = vertex_at(baked, rest, look, i, frame)
		if at[i].x < -0.05 and at[i].z > tip.z:
			tip = at[i]
	var hand := PackedInt32Array()
	var elbow := PackedInt32Array()
	var bend := tip - Vector3(0, 0, FOREARM)
	# A body of fewer vertices may have none that near the elbow: then those
	# within ELBOW_SPARE of the nearest one.
	var nearest := INF
	for i in rest.size():
		if at[i].distance_to(tip) >= HAND_R:
			nearest = minf(nearest, at[i].distance_to(bend))
	var reach := ELBOW_R if nearest < ELBOW_R else nearest + ELBOW_SPARE
	for i in rest.size():
		if at[i].distance_to(tip) < HAND_R:
			hand.append(i)
		elif at[i].distance_to(bend) < reach:
			elbow.append(i)
	if hand.is_empty() or elbow.is_empty():
		return {}
	return {"hand": hand, "elbow": elbow}


## Where one vertex of a baked body is in a frame of its picture: what the
## shader does (rest place plus the frame's offset), on the CPU.
static func vertex_at(baked: Dictionary, rest: PackedVector3Array, look: PackedVector2Array, i: int, frame: int) -> Vector3:
	var img: Image = baked["image"]
	var c := img.get_pixel(int(look[i].x * float(baked["width"])), frame * int(baked["rows_per_frame"]) + int(look[i].y))
	var v := Vector3(c.r, c.g, c.b)
	if baked.get("format", "") != "":
		var clip: Dictionary = _clip_at(baked["clips"], frame)
		var lo := Vector3(clip["lo"][0], clip["lo"][1], clip["lo"][2])
		var hi := Vector3(clip["hi"][0], clip["hi"][1], clip["hi"][2])
		v = lo + v * (hi - lo)
	return rest[i] + v


static func _clip_at(clips: Array, frame: int) -> Dictionary:
	for clip: Dictionary in clips:
		if frame >= int(clip["start"]) and frame < int(clip["start"]) + int(clip["frames"]):
			return clip
	return clips[0]


## The hand and elbow (each the middle of its vertices) for every frame of a
## baked folder, worked out once: [hand of frame 0, elbow of frame 0, hand of 1, ...].
static func arm_table(baked: Dictionary, hand: PackedInt32Array, elbow: PackedInt32Array) -> PackedVector3Array:
	var arrays: Array = (baked["mesh"] as Mesh).surface_get_arrays(0)
	var rest: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var look: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var rows: int = maxi(1, int(baked["rows_per_frame"]))
	var count: int = int(baked["height"]) / rows
	var img: Image = baked["image"]
	var width: float = float(baked["width"])
	var packed: bool = baked.get("format", "") != ""
	var clips: Array = baked["clips"]
	var out := PackedVector3Array()
	out.resize(count * 2)
	# What vertex_at does for each vertex and frame, with each vertex's place in
	# the picture read once and each frame's clip box once (a body's folder of
	# sixty motions took seconds the other way).
	var parts: Array[PackedInt32Array] = [hand, elbow]
	var cols: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
	var lines: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
	for part in 2:
		for i in parts[part]:
			cols[part].append(int(look[i].x * width))
			lines[part].append(int(look[i].y))
	var clip: Dictionary = clips[0] if not clips.is_empty() else {}
	var lo := Vector3.ZERO
	var span := Vector3.ONE
	var first := -1
	var last := -1
	for f in count:
		if packed and (f < first or f >= last):
			clip = _clip_at(clips, f)
			lo = Vector3(clip["lo"][0], clip["lo"][1], clip["lo"][2])
			span = Vector3(clip["hi"][0], clip["hi"][1], clip["hi"][2]) - lo
			first = int(clip["start"])
			last = first + int(clip["frames"])
		for part in 2:
			var ids: PackedInt32Array = parts[part]
			var sum := Vector3.ZERO
			for j in ids.size():
				var c := img.get_pixel(cols[part][j], f * rows + lines[part][j])
				var v := Vector3(c.r, c.g, c.b)
				if packed:
					v = lo + v * span
				sum += rest[ids[j]] + v
			out[f * 2 + part] = sum / float(ids.size())
	return out


## The hand and elbow for what one body is drawn as (the shader's frame for a
## held body: r through the motion, the next frame eased in, and the frame it
## is easing out of), [hand, elbow] in the body's own space.
static func arm_at(arm: PackedVector3Array, tab: Array, drawn: Color) -> Array:
	var packed := floorf(drawn.g + 0.5)
	var motion := DeadBody.motion_in(drawn.g)
	packed -= floorf(packed / VatBaker.UPPER) * VatBaker.UPPER
	var share := floorf(packed / 65536.0)
	var kept := floorf((packed - share * 65536.0) / 16.0)
	if motion >= tab.size():
		return [arm[0], arm[1]]
	var first: int = tab[motion][0]
	var count: int = tab[motion][1]
	var loops: bool = tab[motion][2]
	var at := fposmod(drawn.r * float(count), float(count)) if loops else clampf(drawn.r, 0.0, 1.0) * float(count - 1)
	var a := int(at)
	var b := (a + 1) % count if loops else mini(a + 1, count - 1)
	var k := at - float(a)
	var hand := arm[(first + a) * 2].lerp(arm[(first + b) * 2], k)
	var elbow := arm[(first + a) * 2 + 1].lerp(arm[(first + b) * 2 + 1], k)
	if share > 0.5 and int(kept) * 2 + 1 < arm.size():
		hand = hand.lerp(arm[int(kept) * 2], share / DeadBody.MIX_STEPS)
		elbow = elbow.lerp(arm[int(kept) * 2 + 1], share / DeadBody.MIX_STEPS)
	return [hand, elbow]


## How a weapon sits in a fist on the end of this forearm, held as a hammer is:
## hanging, the head forward; thrust out, the head up; raised over the
## shoulder, the head back. Where the forearm runs out sideways that reading
## fails, so it turns toward the way the forearm points about the up axis
## instead; and it only goes part way toward the new way each frame (from
## `was`), so it never flips in one frame.
static func grip_of(hand: Vector3, elbow: Vector3, was: Basis) -> Basis:
	var f := (hand - elbow).normalized()
	if f == Vector3.ZERO:
		return was
	var a := f.cross(Vector3.RIGHT)
	var b := f.cross(Vector3.UP)
	if a.dot(b) < 0.0:
		b = -b
	var z := a.lerp(b, clampf((absf(f.x) - 0.6) / 0.35, 0.0, 1.0)).normalized()
	var x := (Vector3.RIGHT - z * Vector3.RIGHT.dot(z)).normalized()
	if x == Vector3.ZERO:
		x = f
	var want := Basis(x, z.cross(x), z).orthonormalized()
	if was == Basis() or not was.is_finite():
		return want
	return was.orthonormalized().slerp(want, GRIP_FOLLOW)


## True when the motion last picked for this person is one of the living's own.
static func is_own(note: Dictionary) -> bool:
	return int(note.get("motion", -1)) >= OWN_BASE


## Notes the moment a new wound comes, and what kind it was.
static func _note_hurt(p, note: Dictionary, t: float) -> void:
	var n: int = p.body.wounds.size()
	if n > int(note.get("wounds", n)):
		note["hurt_at"] = t
		note["hurt_kind"] = String(p.body.wounds[-1].get("kind", ""))
		note["hurt_from"] = hurt_from(p)
		note["hurt_own"] = ""
	note["wounds"] = n


## Where the blow came from, seen from the body: x to its right (+) or left
## (-), y in front (+) or behind (-). The nearest of the dead holding it; with
## none of them (or none with a place), straight in front.
static func hurt_from(p) -> Vector2:
	var best := INF
	var from := Vector2(0.0, 1.0)
	# The way the body is drawn turned (it may still be coming round to its facing).
	var fwd := Vector3(sin(p.rotation.y), 0.0, cos(p.rotation.y))
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	for z in p.grabbers:
		if not (z is Dictionary) or not z.has("pos"):
			continue
		var to: Vector3 = z["pos"] - p.position
		to.y = 0.0
		var d := to.length()
		if d < 0.01 or d >= best:
			continue
		best = d
		from = Vector2(right.dot(to / d), fwd.dot(to / d))
	return from


## How far the body has turned since it was last drawn (radians); notes when it
## last turned. A snap round (TURN_CAP) or a tremble (TURN_MIN) is not a turn.
static func _turned(p, note: Dictionary, t: float) -> float:
	var yaw: float = p.rotation.y
	var was: float = float(note.get("yaw", yaw))
	note["yaw"] = yaw
	var d := absf(angle_difference(was, yaw))
	if d < TURN_MIN or d > TURN_CAP:
		return 0.0
	note["turned"] = t
	return d


## 1 as a wound comes, down to 0 HURT_TIME after.
static func hurt_k(note: Dictionary, t: float) -> float:
	if not note.has("hurt_at"):
		return 0.0
	return clampf(1.0 - (t - float(note["hurt_at"])) / HURT_TIME, 0.0, 1.0)


## How the whole body leans on top of the motion it is in (drawing only):
## held, hurt. Nothing for a body on the ground.
static func lean_of(p, note: Dictionary) -> Basis:
	if p.body.downed or p.body.dead or p.fallen_t > 0.0:
		return Basis()
	var t: float = float(note.get("t", 0.0))
	var pitch := 0.0
	var roll := 0.0
	var turn := 0.0
	if not p.grabbers.is_empty():
		pitch = HELD_LEAN.x if p.grab_front else HELD_LEAN.y
		if not is_own(note):             # the living's own held motion twists by itself
			var w := TAU * HELD_HZ * t
			roll = HELD_TWIST.x * sin(w)
			turn = HELD_TWIST.y * sin(w * 0.5 + 0.7)
	var k := hurt_k(note, t)
	if k > 0.0:
		# Away from the blow: back from in front, forward from behind, over from the side.
		var lean := float(HURT_LEAN.get(note.get("hurt_kind", ""), HURT_LEAN[""])) * k * k
		var from: Vector2 = note.get("hurt_from", Vector2(0.0, 1.0))
		var thrown := String(note.get("hurt_own", ""))
		if thrown != OWN_BITTEN_FRONT and thrown != OWN_BITTEN_BACK:   # those throw it themselves
			pitch += lean * from.y
		roll += absf(lean) * HURT_SIDE_ROLL * -from.x
	if pitch == 0.0 and roll == 0.0 and turn == 0.0:
		return Basis()
	return Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)


## An own motion that plays once, from the frame it was started in; `key` is
## what the note keeps it as.
static func _own_once(note: Dictionary, key: int, t: float, length: float) -> float:
	if int(note.get("motion", -1)) != key:
		note["motion"] = key
		note["since"] = t
	return clampf((t - float(note["since"])) / maxf(length, 0.01), 0.0, 1.0)


## A motion that plays once, from the frame it was started in.
static func _once(note: Dictionary, motion: int, t: float, clips: Array) -> float:
	if int(note.get("motion", -1)) != motion:
		note["motion"] = motion
		note["since"] = t
	return clampf((t - float(note["since"])) / _length(clips, motion, 1.0), 0.0, 1.0)


## The number of a motion by its name in the folder's list, or `fallback`
## when the folder has none of that name.
static func clip_named(clips: Array, clip_name: String, fallback: int) -> int:
	for n in clips.size():
		if String(clips[n].get("name", "")) == clip_name:
			return n
	return fallback


## A motion that goes round by the clock, each person from their own place
## in it and at their own pace (the reference game scatters its standing: 상태표 3.1).
## `key` is what the note keeps it as, `length` one round of it.
static func _own_cycle(note: Dictionary, key: int, t: float, length: float, unit: float) -> float:
	note["motion"] = key
	var pace := lerpf(STAND_PACE.x, STAND_PACE.y, fposmod(unit * 7.31, 1.0))
	return fposmod(unit + t * pace / maxf(length, 0.01), 1.0)


## A motion that goes round by the clock (standing, the shove).
static func _cycle(note: Dictionary, motion: int, t: float, clips: Array) -> float:
	note["motion"] = motion
	return fposmod(t / _length(clips, motion, 1.0), 1.0)


## A motion that goes round by the ground covered (walk, run, crawl).
static func _round(note: Dictionary, key: String, gone: float, size: float) -> float:
	var at: float = float(note.get(key, 0.0))
	if gone <= STRIDE_CAP:
		at = fposmod(at + gone / maxf(size, 0.01), 1.0)
	note[key] = at
	return at


static func _length(clips: Array, motion: int, fallback: float) -> float:
	if motion < clips.size():
		return maxf(float(clips[motion].get("length", fallback)), 0.01)
	return fallback


static func _round_of(clips: Array, motion: int, fallback: float) -> float:
	if motion < clips.size() and float(clips[motion].get("round", 0.0)) > 0.0:
		return float(clips[motion]["round"])
	return fallback
