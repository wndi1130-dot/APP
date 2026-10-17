extends Node3D
## How the field's living people look: a baked body (models/people) in place of
## the capsule and ball, one multimesh for all of them, drawn with the dead's
## shader (dead_vat.gdshader). It only reads the people (where they are, which
## way they face, what their body and hands are doing) and decides nothing.
## The capsule, the ball and the arm boxes are hidden while a body is worn; the
## weapon box stays, since the blows are still drawn with it (person_pose.gd).
## With the switch off, or no baked folder in the build, nothing is drawn here
## and the people keep their boxes.

const BodyBake = preload("res://scripts/body_bake.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const Pose = preload("res://game/actors/person_pose.gd")

const FOLDER: String = "res://models/people/n5-crew_seamstress"
const SETTING: String = "visuals/baked_people_enabled"
const MAX_PEOPLE: int = 32
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
# Held by the dead (after Project Zomboid's struck state, 상태표 2.3): the arms
# out against them (the lunge's reach), leaning back from one in front and
# bent under one behind, twisting to get free.
const HELD_LEAN: Vector2 = Vector2(-0.2, 0.22)   # in front, behind
const HELD_TWIST: Vector2 = Vector2(0.12, 0.2)   # sideways roll, turn about the spine
const HELD_HZ: float = 2.6
# Hurt (bitten, scratched, cut, shot): the struck pose and the body thrown
# back, easing out. A bite throws it furthest.
const HURT_TIME: float = 0.45
const HURT_LEAN: Dictionary = {"bite": -0.35, "": -0.2}
# The living's own motions, by name, once the people's folder has them
# (asked of the bake, coord fun 모션_새동작_청함); until then the dead's that
# read closest. Crouched (Project Zomboid's sneak: its own stand and walk) it
# stands low as the dead do before they run, and walks the bent shuffle.
const OWN_WALK: String = "p_walk"
const OWN_RUN: String = "p_run"
const OWN_STAND: String = "p_stand"
const OWN_CROUCH_WALK: String = "p_crouch_walk"
const OWN_CROUCH_STAND: String = "p_crouch_idle"
const CROUCH_WALK: int = 1                       # walk_b: bent over, both feet barely leaving the ground
const CROUCH_LOW: Vector2 = Vector2(0.87, 0.97)  # where in the tell it is held, breathing between the two
const STAND_PACE: Vector2 = Vector2(0.85, 1.15)  # each person stands at their own pace, from their own place in it

var game                                 # field_game.gd
var vat: Dictionary = {}
var draw: MultiMeshInstance3D
var notes: Dictionary = {}               # person -> what it was last drawn as
var table: Array = []                    # the worn body's motions, for easing between them (dead_body.gd mix_from)


func setup(field_game) -> void:
	game = field_game
	process_priority = 100               # after field_game has set every person's view
	if not enabled():
		return
	vat = DeadBody.with_albedo(BodyBake.load_baked(FOLDER), FOLDER)
	if vat.is_empty():
		return
	draw = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = vat["mesh"]
	mm.instance_count = MAX_PEOPLE
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-5, -5, -5), Vector3(185, 16, 115))
	draw.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://game/actors/dead_vat.gdshader")
	mat.set_shader_parameter("vat", vat["texture"])
	var tables := VatBaker.shader_tables(vat)
	for key in tables:
		mat.set_shader_parameter(key, tables[key])
	mat.set_shader_parameter("tint", Vector3(0.5, 0.5, 0.5))
	if DeadBody.can_mix():
		table = DeadBody.table_of(vat)
		mat.set_shader_parameter("mixes", true)
	draw.material_override = mat
	add_child(draw)


static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING, true))


func is_worn() -> bool:
	return draw != null


func _process(delta: float) -> void:
	if draw == null:
		return
	var mm := draw.multimesh
	var n := 0
	for p in game.people:
		_hide_boxes(p)
		if not p.visible or n >= MAX_PEOPLE:
			continue
		var note: Dictionary = notes.get(p, {})
		notes[p] = note
		var c := motion_of(p, note, delta, vat.get("clips", []))
		var look := Color(c.x, c.y, 1.0, SHADE)
		mm.set_instance_transform(n, Transform3D(Basis(Vector3.UP, p.rotation.y) * lean_of(p, note), p.global_position))
		mm.set_instance_custom_data(n, DeadBody.mix_from(note, look, float(note["t"]), table))
		n += 1
	mm.visible_instance_count = n


func _hide_boxes(p) -> void:
	p.body_mesh.visible = false
	p.head_mesh.visible = false
	var arms: Array = p.get_meta(Pose.META, [])
	for i in mini(arms.size(), 2):
		arms[i].visible = false


## The motion one person is in (y) and how far through it (x), from what the
## rules say about them. `note` keeps what it was last drawn as, so a walk goes
## by the ground covered and a fall plays once from where it started.
static func motion_of(p, note: Dictionary, delta: float, clips: Array) -> Vector2:
	var t: float = float(note.get("t", 0.0)) + delta
	note["t"] = t
	var at: Vector3 = p.global_position
	var gone: float = at.distance_to(note.get("at", at))
	note["at"] = at
	_note_hurt(p, note, t)
	var lying: bool = p.body.downed or p.body.dead or p.fallen_t > 0.0
	if lying:
		# Dead or knocked down it goes over on its back; down and still alive
		# (or slipped) it lies on its face, where it can still drag itself.
		var fall := FALL if p.body.dead else FALL_FRONT
		if p.body.downed and not p.body.dead and gone > 0.01:
			return Vector2(_round(note, "crawl", gone, _round_of(clips, CRAWL, 0.61)), CRAWL)
		return Vector2(_once(note, fall, t, clips), fall)
	# Up again off the face it fell on, or off its back.
	if note.get("motion", -1) == FALL or note.get("motion", -1) == FALL_FRONT:
		note["motion"] = RISE_FRONT if note["motion"] == FALL_FRONT else RISE
		note["since"] = t
	var rise: int = int(note.get("motion", -1))
	if (rise == RISE or rise == RISE_FRONT) and t - float(note["since"]) < _length(clips, rise, 1.0):
		return Vector2((t - float(note["since"])) / _length(clips, rise, 1.0), rise)
	if not p.grabbers.is_empty():
		# Held: the arms out against them, the legs shifting under it.
		note["motion"] = LUNGE
		return Vector2(fposmod(DeadBody.REACH_AT + DeadBody.REACH_SHIFT * sin(TAU * HELD_HZ * 0.5 * t), 1.0), LUNGE)
	if hurt_k(note, t) > 0.0:
		note["motion"] = HIT
		return Vector2(0.0, HIT)
	if p.shove_t > 0.0 or p.lunge_t > 0.0:
		return Vector2(_cycle(note, LUNGE, t, clips), LUNGE)
	if gone > 0.001:
		note["moved"] = t
	var unit: float = p.name_unit("stand")
	if t - float(note.get("moved", -10.0)) >= STILL_AFTER:
		if p.crouched:
			var low := clip_named(clips, OWN_CROUCH_STAND, -1)
			if low >= 0:
				return Vector2(_own_cycle(note, low, t, clips, unit), low)
			note["motion"] = TELL
			var breath := 0.5 + 0.5 * sin(TAU * (t / 3.5 + unit))
			return Vector2(lerpf(CROUCH_LOW.x, CROUCH_LOW.y, breath), TELL)
		var stand := clip_named(clips, OWN_STAND, STAND)
		return Vector2(_own_cycle(note, stand, t, clips, unit), stand)
	var gait := clip_named(clips, OWN_WALK, WALK)
	if p.running:
		gait = clip_named(clips, OWN_RUN, RUN)
	elif p.crouched:
		gait = clip_named(clips, OWN_CROUCH_WALK, CROUCH_WALK)
	elif p.body.exhaustion_level() >= 2:
		gait = STAGGER
	note["motion"] = gait
	return Vector2(_round(note, "step", gone, _round_of(clips, gait, float(DeadBody.STRIDE.get(gait, 1.2)))), gait)


## Notes the moment a new wound comes, and what kind it was.
static func _note_hurt(p, note: Dictionary, t: float) -> void:
	var n: int = p.body.wounds.size()
	if n > int(note.get("wounds", n)):
		note["hurt_at"] = t
		note["hurt_kind"] = String(p.body.wounds[-1].get("kind", ""))
	note["wounds"] = n


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
		var w := TAU * HELD_HZ * t
		pitch = HELD_LEAN.x if p.grab_front else HELD_LEAN.y
		roll = HELD_TWIST.x * sin(w)
		turn = HELD_TWIST.y * sin(w * 0.5 + 0.7)
	var k := hurt_k(note, t)
	if k > 0.0:
		pitch += float(HURT_LEAN.get(note.get("hurt_kind", ""), HURT_LEAN[""])) * k * k
	if pitch == 0.0 and roll == 0.0 and turn == 0.0:
		return Basis()
	return Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)


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
## in it and at their own pace (Project Zomboid scatters its standing: 상태표 3.1).
static func _own_cycle(note: Dictionary, motion: int, t: float, clips: Array, unit: float) -> float:
	note["motion"] = motion
	var pace := lerpf(STAND_PACE.x, STAND_PACE.y, fposmod(unit * 7.31, 1.0))
	return fposmod(unit + t * pace / _length(clips, motion, 1.0), 1.0)


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
