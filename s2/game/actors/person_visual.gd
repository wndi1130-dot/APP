extends Node3D
## How the field's living people look: a baked body (models/people) in place of
## the capsule and ball, drawn with the dead's shader (dead_vat.gdshader). It
## only reads the people (where they are, which way they face, what their body
## and hands are doing) and decides nothing.
## Two multimeshes wear the same body: one with the living's own motions
## (OWN_FOLDER: walking, running, standing, crouched, held, bitten, the shove),
## one with the dead's folder for what the living have no motion of their own
## for yet (the falls, the crawl, getting up, reeling spent). Each person is in
## one of them at a time; a change between the two is not eased.
## The weapon in the hand is put in the worn body's right hand (found in the
## baked motions), save while a gun is aimed, loaded or cleared, where
## person_pose.gd still holds it.
## The capsule, the ball and the arm boxes are hidden while a body is worn; the
## weapon box stays, since the blows are still drawn with it (person_pose.gd).
## With the switch off, or no baked folder in the build, nothing is drawn here
## and the people keep their boxes.

const BodyBake = preload("res://scripts/body_bake.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const Pose = preload("res://game/actors/person_pose.gd")

const FOLDER: String = "res://models/people/n5-crew_seamstress"
const OWN_FOLDER: String = "res://models/people/n5-crew_seamstress_p"
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
# The living's own motions in OWN_FOLDER, by name; where the build has no such
# folder, the dead's that read closest. Crouched (Project Zomboid's sneak: its
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
const OWN_BASE: int = 100
# Easing into each own motion (Project Zomboid: walking, running 0.35; struck 0.10).
const OWN_MIX: Dictionary = {"p_bitten": 0.1, "p_shove": 0.1, "p_swing_one": 0.1, "p_swing_axe": 0.1, "p_stab": 0.1}
# A melee blow in the living's own motions: which, and where in it the blow
# lands (body_bake.gd keys). A knife stabs, an axe and any blow at a body on the
# ground come down from overhead, the rest swing across. A stomp has none yet.
const OWN_BLOWS: Dictionary = {"one": ["p_swing_one", 0.45], "axe": ["p_swing_axe", 0.45], "stab": ["p_stab", 0.35]}
# The right hand: with both arms thrown straight out (p_shove at 0.4) the
# furthest forward vertex on the right and those within HAND_R of it; the
# elbow those within ELBOW_R of a point FOREARM behind it.
const HAND_R: float = 0.1
const ELBOW_R: float = 0.05
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


func setup(field_game) -> void:
	game = field_game
	process_priority = 100               # after field_game has set every person's view
	if not enabled():
		return
	vat = DeadBody.with_albedo(BodyBake.load_baked(FOLDER), FOLDER)
	if vat.is_empty():
		return
	draw = _wear(vat)
	if DeadBody.can_mix():
		table = DeadBody.table_of(vat)
	own_vat = DeadBody.with_albedo(BodyBake.load_baked(OWN_FOLDER), OWN_FOLDER)
	if own_vat.is_empty():
		return
	own_draw = _wear(own_vat)
	var clips: Array = own_vat.get("clips", [])
	for n in clips.size():
		own_mix[n] = float(OWN_MIX.get(String(clips[n].get("name", "")), OWN_MIX_TIME))
	if DeadBody.can_mix():
		own_table = DeadBody.table_of(own_vat)
	own_frames = DeadBody.table_of(own_vat)
	var arm := hand_of(own_vat)
	if not arm.is_empty():
		own_vat["arm"] = arm_table(own_vat, arm["hand"], arm["elbow"])
		if int(vat.get("vertices", 0)) == int(own_vat.get("vertices", -1)):
			vat["arm"] = arm_table(vat, arm["hand"], arm["elbow"])
			frames = DeadBody.table_of(vat)


## One multimesh wearing a baked folder.
func _wear(baked: Dictionary) -> MultiMeshInstance3D:
	var one := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = baked["mesh"]
	mm.instance_count = MAX_PEOPLE
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-5, -5, -5), Vector3(185, 16, 115))
	one.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://game/actors/dead_vat.gdshader")
	mat.set_shader_parameter("vat", baked["texture"])
	var tables := VatBaker.shader_tables(baked)
	for key in tables:
		mat.set_shader_parameter(key, tables[key])
	mat.set_shader_parameter("tint", Vector3(0.5, 0.5, 0.5))
	if DeadBody.can_mix():
		mat.set_shader_parameter("mixes", true)
	one.material_override = mat
	add_child(one)
	return one


static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING, true))


func is_worn() -> bool:
	return draw != null


func _process(delta: float) -> void:
	if draw == null:
		return
	var mm := draw.multimesh
	var own_mm: MultiMesh = own_draw.multimesh if own_draw != null else null
	var n := 0
	var k := 0
	for p in game.people:
		_hide_boxes(p)
		if not p.visible or n + k >= MAX_PEOPLE:
			continue
		var note: Dictionary = notes.get(p, {})
		notes[p] = note
		var c := motion_of(p, note, delta, vat.get("clips", []), own_vat.get("clips", []))
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
			drawn = DeadBody.mix_from(mix, look, float(note["t"]), own_table, own_mix)
			own_mm.set_instance_transform(k, at)
			own_mm.set_instance_custom_data(k, drawn)
			k += 1
		else:
			drawn = DeadBody.mix_from(mix, look, float(note["t"]), table)
			mm.set_instance_transform(n, at)
			mm.set_instance_custom_data(n, drawn)
			n += 1
		var baked: Dictionary = own_vat if own else vat
		if baked.has("arm") and not gun_busy(p):
			var hand := arm_at(baked["arm"], own_frames if own else frames, drawn)
			var grip := grip_of(hand[0], hand[1], note.get("grip", Basis()))
			note["grip"] = grip
			var lean := lean_of(p, note)
			p.weapon_mesh.transform = Transform3D(lean * grip, lean * hand[0])
	mm.visible_instance_count = n
	if own_mm != null:
		own_mm.visible_instance_count = k


func _hide_boxes(p) -> void:
	p.body_mesh.visible = false
	p.head_mesh.visible = false
	var arms: Array = p.get_meta(Pose.META, [])
	for i in mini(arms.size(), 2):
		arms[i].visible = false


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
	var bitten := clip_named(own, OWN_BITTEN, -1)
	if bitten >= 0 and note.has("hurt_at") and t - float(note["hurt_at"]) < _length(own, bitten, 0.6):
		# Flinching, shoulders up and the head thrown back, then bracing.
		note["motion"] = OWN_BASE + bitten
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
	var blow := blow_of(p, own)
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
	if gone > 0.001:
		note["moved"] = t
	var unit: float = p.name_unit("stand")
	# Spent, it reels as the dead do (the living have no such motion of their own
	# yet), still reeling where it stops for breath.
	var spent: bool = not p.running and not p.crouched and p.body.exhaustion_level() >= 2
	if spent and t - float(note.get("moved", -10.0)) >= STILL_AFTER:
		return Vector2(_own_cycle(note, STAGGER, t, _length(clips, STAGGER, 1.0) * 2.0, unit), STAGGER)
	if t - float(note.get("moved", -10.0)) >= STILL_AFTER:
		var own_stand := clip_named(own, OWN_CROUCH_STAND if p.crouched else OWN_STAND, -1)
		if own_stand >= 0:
			return Vector2(_own_cycle(note, OWN_BASE + own_stand, t, _length(own, own_stand, 1.0), unit), own_stand)
		if p.crouched:
			note["motion"] = TELL
			var breath := 0.5 + 0.5 * sin(TAU * (t / 3.5 + unit))
			return Vector2(lerpf(CROUCH_LOW.x, CROUCH_LOW.y, breath), TELL)
		return Vector2(_own_cycle(note, STAND, t, _length(clips, STAND, 1.0), unit), STAND)
	var own_gait := -1
	if not spent:
		own_gait = clip_named(own, OWN_RUN if p.running else (OWN_CROUCH_WALK if p.crouched else OWN_WALK), -1)
	if own_gait >= 0:
		note["motion"] = OWN_BASE + own_gait
		return Vector2(_round(note, "step", gone, _round_of(own, own_gait, 1.2)), own_gait)
	var gait := WALK
	if p.running:
		gait = RUN
	elif p.crouched:
		gait = CROUCH_WALK
	elif spent:
		gait = STAGGER
	note["motion"] = gait
	return Vector2(_round(note, "step", gone, _round_of(clips, gait, float(DeadBody.STRIDE.get(gait, 1.2)))), gait)


## A melee blow in the living's own motions (y) and how far through it (x):
## drawn back up to where the blow lands while the rules wind it up, the rest
## on the way back. y is -1 with no blow, or none of its own (a stomp).
static func blow_of(p, own: Array) -> Vector2:
	if own.is_empty():
		return Vector2(0.0, -1.0)
	var sw: Array = Pose.swing_state(p)
	if sw.is_empty():
		return Vector2(0.0, -1.0)
	var mode: String = p.get_meta(Pose.MODE, "swing")
	if mode == "stomp":
		return Vector2(0.0, -1.0)
	var kind := "one"
	if mode == "floor" or p.weapon_id() == "axe":
		kind = "axe"
	elif p.weapon_id() == "knife":
		kind = "stab"
	var clip := clip_named(own, String(OWN_BLOWS[kind][0]), -1)
	if clip < 0:
		return Vector2(0.0, -1.0)
	var lands: float = OWN_BLOWS[kind][1]
	var r: float = lands + (1.0 - lands) * float(sw[1]) if sw[2] else lands * float(sw[0])
	return Vector2(r, clip)


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
		if at[i].x > 0.05 and at[i].z > tip.z:
			tip = at[i]
	var hand := PackedInt32Array()
	var elbow := PackedInt32Array()
	var bend := tip - Vector3(0, 0, FOREARM)
	for i in rest.size():
		if at[i].distance_to(tip) < HAND_R:
			hand.append(i)
		elif at[i].distance_to(bend) < ELBOW_R:
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
	var count: int = int(baked["height"]) / maxi(1, int(baked["rows_per_frame"]))
	var out := PackedVector3Array()
	out.resize(count * 2)
	for f in count:
		for part in 2:
			var ids: PackedInt32Array = hand if part == 0 else elbow
			var sum := Vector3.ZERO
			for i in ids:
				sum += vertex_at(baked, rest, look, i, f)
			out[f * 2 + part] = sum / float(ids.size())
	return out


## The hand and elbow for what one body is drawn as (the shader's frame for a
## held body: r through the motion, the next frame eased in, and the frame it
## is easing out of), [hand, elbow] in the body's own space.
static func arm_at(arm: PackedVector3Array, tab: Array, drawn: Color) -> Array:
	var packed := floorf(drawn.g + 0.5)
	var share := floorf(packed / 65536.0)
	var kept := floorf((packed - share * 65536.0) / 16.0)
	var motion := int(packed - share * 65536.0 - kept * 16.0 + 0.5)
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
		pitch = HELD_LEAN.x if p.grab_front else HELD_LEAN.y
		if not is_own(note):             # the living's own held motion twists by itself
			var w := TAU * HELD_HZ * t
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
