extends RefCounted
## Bakes a rigged body and a set of motions into one vertex texture: the motion
## bones are matched to the body's bones, each clip is sampled frame by frame
## (with a hand-made layer on top), and VatBaker.build_skinned turns the skin
## matrices into offsets. Both models must already be in the scene tree. Also
## writes the result to a folder and reads it back.

const VatBaker = preload("res://scripts/vat_baker.gd")

# Body bone -> bone of the motion set.
const MAP: Dictionary = {
	"hips": "pelvis", "spine": "spine_01", "chest": "spine_03", "neck": "neck_01", "head": "Head",
	"upper_arm.L": "upperarm_l", "forearm.L": "lowerarm_l", "hand.L": "hand_l",
	"upper_arm.R": "upperarm_r", "forearm.R": "lowerarm_r", "hand.R": "hand_r",
	"thigh.L": "thigh_l", "shin.L": "calf_l", "foot.L": "foot_l",
	"thigh.R": "thigh_r", "shin.R": "calf_r", "foot.R": "foot_r",
}
# Motions, in baking order (this is the motion number): name, source motion,
# frames, loops, layer name (LAYERS, "" for none).
const CLIPS: Array = [
	["walk_a", "Walk_Loop", 32, true, "walk"],
	["walk_b", "Walk_Loop", 32, true, "walk_b"],
	["walk_c", "Walk_Loop", 32, true, "walk_c"],
	["stand", "Idle_Loop", 32, true, "stand"],
	["lunge", "Walk_Loop", 24, true, "lunge"],
	["hit", "Hit_Chest", 12, false, ""],
	["fall", "Death01", 48, false, ""],
	["run", "Jog_Fwd_Loop", 24, true, "run"],
	["tell", "Idle_Loop", 12, false, "tell"],
	# Written here whichever way it is baked (no source motion; the last number is its length).
	["fall_front", "", 32, false, "own_fall_front", 0.75],
	["crawl", "", 32, true, "own_crawl", 1.8],
	["rise", "", 32, false, "own_rise", 1.2],
	["climb", "", 32, false, "own_climb", 2.4],
	["rise_front", "", 32, false, "own_rise_front", 1.3],
	["stagger", "", 32, true, "own_stagger", 1.3],
	# More ways to go over (decision 412), each lying at the end as one above.
	["fall_thrown", "", 32, false, "own_fall_thrown", 0.75],
	["fall_slump", "", 32, false, "own_fall_slump", 0.75],
	# What the reference game's dead do that these could not yet (motion detail 2,
	# 2026-10-24): at a door, struck on the head four ways, turning round, two
	# slower walks. Written here, as the ones above.
	["thump", "", 24, true, "own_thump", 1.3],
	["claw", "", 24, true, "own_claw", 1.3],
	["hit_left", "", 12, false, "own_hit_left", 0.4],
	["hit_right", "", 12, false, "own_hit_right", 0.4],
	["hit_top", "", 12, false, "own_hit_top", 0.4],
	["hit_upper", "", 12, false, "own_hit_upper", 0.4],
	["turn_left", "", 24, false, "own_turn_left", 1.0],
	["turn_right", "", 24, false, "own_turn_right", 1.0],
	["walk_d", "", 32, true, "own_walk_d", 1.8],
	["walk_e", "", 32, true, "own_walk_e", 1.6],
	# Eating a body (decision 423): down on its knees, the loop (the teeth meet at 0.5), up again.
	["eat_start", "", 24, false, "own_eat_start", 1.0],
	["eat", "", 32, true, "own_eat", 1.6],
	["eat_rise", "", 24, false, "own_eat_rise", 1.2],
	# Biting the one it holds (decision 422, the teeth in at 0.5: dead_body.gd
	# BITE_LANDS) and snapping at the air when it reached and missed.
	["bite", "", 24, false, "own_bite", 1.0],
	["bite_miss", "", 20, false, "own_bite_miss", 0.75],
]
# The same motions with nothing from a motion set (the legs are written here
# too): name, "", frames, loops, layer name, length in seconds. Same names in
# the same order as CLIPS, so the motion numbers are the same either way.
const OWN_CLIPS: Array = [
	["walk_a", "", 32, true, "own_walk", 1.4],
	["walk_b", "", 32, true, "own_walk_b", 1.5],
	["walk_c", "", 32, true, "own_walk_c", 1.2],
	["stand", "", 32, true, "own_stand", 3.0],
	["lunge", "", 24, true, "own_lunge", 1.0],
	["hit", "", 12, false, "own_hit", 0.4],
	["fall", "", 32, false, "own_fall", 0.75],
	["run", "", 24, true, "own_run", 0.7],
	["tell", "", 12, false, "own_tell", 0.5],
	["fall_front", "", 32, false, "own_fall_front", 0.75],
	["crawl", "", 32, true, "own_crawl", 1.8],
	["rise", "", 32, false, "own_rise", 1.2],
	["climb", "", 32, false, "own_climb", 2.4],
	["rise_front", "", 32, false, "own_rise_front", 1.3],
	["stagger", "", 32, true, "own_stagger", 1.3],
	["fall_thrown", "", 32, false, "own_fall_thrown", 0.75],
	["fall_slump", "", 32, false, "own_fall_slump", 0.75],
	# What the reference game's dead do that these could not yet (motion detail 2,
	# 2026-10-24): at a door, struck on the head four ways, turning round, two
	# slower walks. Written here, as the ones above.
	["thump", "", 24, true, "own_thump", 1.3],
	["claw", "", 24, true, "own_claw", 1.3],
	["hit_left", "", 12, false, "own_hit_left", 0.4],
	["hit_right", "", 12, false, "own_hit_right", 0.4],
	["hit_top", "", 12, false, "own_hit_top", 0.4],
	["hit_upper", "", 12, false, "own_hit_upper", 0.4],
	["turn_left", "", 24, false, "own_turn_left", 1.0],
	["turn_right", "", 24, false, "own_turn_right", 1.0],
	["walk_d", "", 32, true, "own_walk_d", 1.8],
	["walk_e", "", 32, true, "own_walk_e", 1.6],
	# Eating a body (decision 423): down on its knees, the loop (the teeth meet at 0.5), up again.
	["eat_start", "", 24, false, "own_eat_start", 1.0],
	["eat", "", 32, true, "own_eat", 1.6],
	["eat_rise", "", 24, false, "own_eat_rise", 1.2],
	["bite", "", 24, false, "own_bite", 1.0],
	["bite_miss", "", 20, false, "own_bite_miss", 0.75],
]
# Quick, or striking on a beat: every frame kept in the small bake
# (bake_body_cli --keep), as PERSON_KEEP is for the living.
const DEAD_KEEP: Array = ["thump", "claw", "hit_left", "hit_right", "hit_top", "hit_upper", "bite", "bite_miss"]
# Still poses, one frame each in a clip named POSES_CLIP: source motion, where in
# it (0..1), name of the hand-made addition (OVERLAYS, "" for none).
const POSES: Array = [
	["Death01", 1.0, ""], ["Idle_Loop", 0.0, ""], ["Idle_Loop", 0.0, "press"], ["Sitting_Idle_Loop", 0.0, "slump"],
]
# The same four with nothing from a motion set: layer name, where in it, addition.
const OWN_POSES: Array = [
	["own_fall", 1.0, ""], ["own_stand", 0.0, ""], ["own_press", 0.0, ""], ["own_sit", 0.0, ""],
]
# The living people's motions (bake_body_cli --set=person, a folder of its own
# so the dead's numbers above stay): name, source motion ("" for one written
# here), frames, loops, layer ("" for none), seconds (a source motion's own
# length is what is baked). Existing slots stay fixed even when their source
# changes; new clips append after the last slot. The field finds names. 128 at
# most: the shader's clip tables have VatBaker.TABLE_SIZE places
# (dead_vat.gdshader); numbers 16 and up are written with VatBaker.pack_motion.
const PERSON_CLIPS: Array = [
	["p_walk", "", 32, true, "p_walk", 0.78],
	["p_run", "", 24, true, "p_run", 0.58],
	["p_stand", "Idle_Loop", 32, true, "p_stand", 2.5],
	["p_held", "", 24, true, "p_held", 1.0],
	["p_bitten", "", 24, false, "p_bitten", 0.6],
	["p_swing_one", "", 24, false, "p_swing_one", 0.6],
	["p_swing_axe", "", 32, false, "p_swing_axe", 0.9],
	["p_stab", "", 20, false, "p_stab", 0.45],
	["p_shove", "", 20, false, "p_shove", 0.5],
	["p_crouch_walk", "", 32, true, "p_crouch_walk", 1.08],
	["p_crouch_idle", "", 24, true, "p_crouch_idle", 3.0],
	["p_search_mid", "", 24, true, "p_search_mid", 2.0],
	["p_search_low", "", 24, true, "p_search_low", 2.0],
	["p_treat", "", 24, true, "p_treat", 2.0],
	["p_aim_one", "", 16, true, "p_aim_one", 1.0],
	["p_aim_two", "", 16, true, "p_aim_two", 1.0],
	# Down, along and up again with the same layers the dead use, so a living
	# body need not change folders (and lose its mix) to fall.
	["p_fall", "", 32, false, "own_fall", 1.0],
	["p_fall_front", "", 32, false, "own_fall_front", 1.0],
	["p_crawl", "", 32, true, "own_crawl", 1.8],
	["p_rise", "", 32, false, "own_rise", 1.2],
	["p_rise_front", "", 32, false, "own_rise_front", 1.2],
	["p_spent", "", 32, true, "own_stagger", 1.3],
	["p_floor_strike", "", 24, false, "p_floor_strike", 0.8],
	["p_stomp", "", 20, false, "p_stomp", 0.6],
	["p_pry", "", 24, true, "p_pry", 1.6],
	["p_kick", "", 20, false, "p_kick", 0.6],
	# A one-handed blow back the other way, a second to the swing across (decision 411).
	["p_swing_back", "", 24, false, "p_swing_back", 0.6],
	# Slumping on its face, a second way to go down to own_fall_front's (decision 412).
	["p_fall_slump", "", 32, false, "own_fall_slump", 1.0],
	# Decision 422, first set: a high shelf, limping (each leg), binding a wound
	# by where it is, bitten from in front and from behind, cold, a hand to
	# where it hurts, spent.
	["p_search_high", "", 24, true, "p_search_high", 2.0],
	["p_limp_light_l", "", 32, true, "p_limp_light_l", 1.0],
	["p_limp_light_r", "", 32, true, "p_limp_light_r", 1.0],
	["p_limp_heavy_l", "", 32, true, "p_limp_heavy_l", 1.4],
	["p_limp_heavy_r", "", 32, true, "p_limp_heavy_r", 1.4],
	["p_treat_arm", "", 24, true, "p_treat_arm", 2.0],
	["p_treat_leg", "", 24, true, "p_treat_leg", 2.0],
	["p_treat_head", "", 24, true, "p_treat_head", 2.0],
	["p_bitten_front", "", 24, false, "p_bitten_front", 0.6],
	["p_bitten_back", "", 24, false, "p_bitten_back", 0.6],
	["p_shiver", "", 24, true, "p_shiver", 1.0],
	["p_pain_head", "", 24, false, "p_pain_head", 2.0],
	["p_pain_torso", "", 24, false, "p_pain_torso", 2.0],
	["p_pain_arm", "", 24, false, "p_pain_arm", 2.0],
	["p_pain_leg", "", 24, false, "p_pain_leg", 2.0],
	["p_tired_stretch", "", 24, false, "p_tired_stretch", 2.5],
	# Putting on a coat, a hat or hood, and gloves (decision 423).
	["p_wear_outer", "", 24, false, "p_wear_outer", 2.4],
	["p_wear_head", "", 24, false, "p_wear_head", 1.4],
	["p_wear_hands", "", 24, false, "p_wear_hands", 1.8],
	# Decision 422, second set: carrying each kind of weapon walking and running,
	# the three melee guards, a two-handed weapon held low in the good hand.
	["p_walk_long", "", 32, true, "p_walk_long", 0.78],
	["p_walk_axe", "", 32, true, "p_walk_axe", 0.78],
	["p_walk_pistol", "", 32, true, "p_walk_pistol", 0.78],
	["p_run_long", "", 24, true, "p_run_long", 0.58],
	["p_run_pistol", "", 24, true, "p_run_pistol", 0.58],
	["p_ready_one", "", 24, true, "p_ready_one", 1.6],
	["p_ready_two", "", 24, true, "p_ready_two", 1.6],
	["p_ready_stab", "", 24, true, "p_ready_stab", 1.6],
	["p_hold_weak", "", 24, true, "p_hold_weak", 3.0],
	# Decision 448: creeping with a long weapon or a handgun (walking and still),
	# the weak-hand hold the other way round (the right arm hurt), a big thing
	# carried in both arms, and walking bent over a wound.
	["p_crouch_walk_long", "", 32, true, "p_crouch_walk_long", 1.08],
	["p_crouch_walk_pistol", "", 32, true, "p_crouch_walk_pistol", 1.08],
	["p_crouch_idle_long", "", 24, true, "p_crouch_idle_long", 3.0],
	["p_crouch_idle_pistol", "", 24, true, "p_crouch_idle_pistol", 3.0],
	["p_hold_weak_r", "", 24, true, "p_hold_weak_r", 3.0],
	["p_carry_big", "", 32, true, "p_carry_big", 0.78],
	["p_walk_hurt", "", 32, true, "p_walk_hurt", 0.78],
	# From the two free motion sets (UAL1_Standard.glb and UAL2_Standard.glb, read together).
	["p_reload", "Pistol_Reload", 32, false, "", 1.667],
	["p_climb", "ClimbUp_1m", 20, false, "", 0.667],
	["p_kneel_work", "Fixing_Kneeling", 32, true, "p_kneel_work", 3.12],
	# A low lid, a knockback and a pick-up nothing played made way for a second
	# blow and a fall: an axe chopped in from the side (UAL's sword blows turn
	# the hips round 69 to 160 degrees, the chop 34).
	["p_chop_side", "TreeChopping_Loop", 24, false, "", 0.967],
]
# Quick blows and all walk/run legs keep every frame in the small bake.
const PERSON_KEEP: Array = ["p_bitten", "p_swing_one", "p_swing_axe", "p_stab", "p_shove", "p_floor_strike", "p_stomp", "p_kick", "p_climb", "p_swing_back", "p_chop_side", "p_bitten_front", "p_bitten_back", "p_shiver", "p_walk", "p_walk_long", "p_walk_axe", "p_walk_pistol", "p_carry_big", "p_walk_hurt", "p_run", "p_run_long", "p_run_pistol"]
# Decision 425, game/sim/noise.gd STEP_ROUND. Fit the bake to these distances;
# neither body dimensions nor the rules' distances change.
const PERSON_STRIDE_ROUNDS: Dictionary = {
	"p_walk": 1.64, "p_walk_long": 1.64, "p_walk_axe": 1.64,
	"p_walk_pistol": 1.64, "p_carry_big": 1.64, "p_walk_hurt": 1.64,
	"p_run": 2.27, "p_run_long": 2.27, "p_run_pistol": 2.27,
	"p_crouch_walk": 1.19, "p_crouch_walk_long": 1.19, "p_crouch_walk_pistol": 1.19,
}
const PERSON_STRIDE_BONES: Array = ["thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R"]
const STRIDE_TOLERANCE: float = 0.005
const STRIDE_SCALE_MIN: float = 0.9
const STRIDE_SCALE_MAX: float = 1.1
const STRIDE_PASSES: int = 3
# Only these shared legs follow STEP_AT; crouching keeps its current phase.
const PERSON_PHASE_BASE: Dictionary = {
	"p_walk": "p_walk", "p_walk_long": "p_walk", "p_walk_axe": "p_walk",
	"p_walk_pistol": "p_walk", "p_carry_big": "p_walk", "p_walk_hurt": "p_walk",
	"p_run": "p_run", "p_run_long": "p_run", "p_run_pistol": "p_run",
}
const PERSON_STEP_AT: Array = [0.2, 0.65]  # game/sim/noise.gd, unchanged
const PERSON_PHASE_SAMPLES: int = 256
const PERSON_CONTACT_HEIGHT: float = 0.01
const PERSON_SOLE_EPSILON: float = 0.0001  # equal rest-height vertices, 0.1 mm
const PERSON_PHASE_SOURCE: String = "person_phase_source"
const POSES_CLIP: String = "poses"
const ROUND_LEAST: float = 0.05               # a loop whose feet go back less than this a round is standing
const CRAWL_CLIP: String = "crawl"            # pulled along by its hands, not its feet
const PERSON_CRAWL_CLIP: String = "p_crawl"   # the same for the living
const HIP_HEIGHT: float = 1.0                 # the hips the layers' sinks were written for, metres
# The walk's legs and hips (as p_walk), for walks that do something else with
# the hands and must cover the walk's ground a round.
const WALK_LEGS: Array = [
	["turn", "hips", "z", [0.0, 0.035, 0.0]],
	["turn", "hips", "y", [0.0, -0.09, 0.0]],
	["aim", "thigh.L", "shin.L", [0.07, -1.0, [[0.02, 0.4, 0.0], [0.0, -0.04, 0.0, 3.0], [0.0, 0.015, 0.0, 5.0]]]],
	["aim", "shin.L", "foot.L", [0.05, -1.0, [[-0.26, 0.38, 0.0], [0.0, -0.04, 0.0, 3.0], [0.0, 0.015, 0.0, 5.0], [0.0, -0.3, -1.5708], [0.0, -0.12, -1.5708, 2.0]]]],
	["aim", "thigh.R", "shin.R", [-0.07, -1.0, [[0.02, 0.4, 3.1416], [0.0, -0.04, 9.4248, 3.0], [0.0, 0.015, 15.708, 5.0]]]],
	["aim", "shin.R", "foot.R", [-0.05, -1.0, [[-0.26, 0.38, 3.1416], [0.0, -0.04, 9.4248, 3.0], [0.0, 0.015, 15.708, 5.0], [0.0, -0.3, 1.5708], [0.0, -0.12, 4.7124, 2.0]]]],
]
const WALK_SINK: Array = [0.025, 0.02, -1.5708, 2.0]
# The run's legs, hips and lean, the same whatever the hands hold so each run
# covers the run's ground a round (SimNoise.STEP_ROUND). The thigh swings from
# 27 degrees back to 40 ahead; the shin lands 18 ahead, gives under the body,
# pushes off and folds to 100 back (the heel up behind) on the way forward.
const RUN_LEGS: Array = [
	["turn", "hips", "x", 0.12],
	["turn", "hips", "z", [0.0, 0.05, 0.0]],
	["turn", "hips", "y", [0.0, -0.14, 0.0]],
	["swing", "thigh.L", "shin.L", 0.07, [0.12, 0.585, 0.0]],
	["swing", "shin.L", "foot.L", 0.05, [[-0.707, 0.611, 0.0], [0.0, -0.628, -1.5708], [0.0, -0.41, -1.5708, 2.0]]],
	["swing", "thigh.R", "shin.R", -0.07, [0.12, 0.585, 3.1416]],
	["swing", "shin.R", "foot.R", -0.05, [[-0.707, 0.611, 3.1416], [0.0, -0.628, 1.5708], [0.0, -0.41, -1.5708, 2.0]]],
	["turn", "spine", "x", 0.22],
	["turn", "chest", "x", 0.1],
	["turn", "neck", "x", -0.3],
]
const RUN_SINK: Array = [0.075, 0.025, -1.5708, 2.0]   # lowest as the legs pass, under the body
# Creeping (crouched), the same whatever the hands hold, covering the crouched
# walk's ground a round: knees half bent, the back well forward, the head up to
# see ahead. The thigh swings from 11 degrees to 46 ahead, the foot kept low.
const CROUCH_LEGS: Array = [
	["turn", "hips", "x", 0.25],
	["turn", "hips", "y", [0.0, -0.06, 0.0]],
	["swing", "thigh.L", "shin.L", 0.1, [0.5, 0.305, 0.0]],
	["swing", "shin.L", "foot.L", 0.07, [[-0.558, 0.36, 0.0], [0.0, -0.236, -1.5708], [0.0, -0.166, -1.5708, 2.0]]],
	["swing", "thigh.R", "shin.R", -0.1, [0.5, 0.305, 3.1416]],
	["swing", "shin.R", "foot.R", -0.07, [[-0.558, 0.36, 3.1416], [0.0, -0.236, 1.5708], [0.0, -0.166, -1.5708, 2.0]]],
	["turn", "spine", "x", 0.42],
	["turn", "chest", "x", 0.14],
	["turn", "chest", "y", [0.0, 0.06, 0.0]],
	["turn", "neck", "x", -0.65],
]
const CROUCH_SINK: Array = [0.12, 0.01, -1.5708, 2.0]
# The crouch kept still, a little less deep, the left foot ahead, breathing.
const CROUCH_STILL: Array = [
	["turn", "hips", "x", 0.18],
	["swing", "thigh.L", "shin.L", 0.12, 0.45],
	["swing", "shin.L", "foot.L", 0.09, -0.2],
	["swing", "thigh.R", "shin.R", -0.12, 0.21],
	["swing", "shin.R", "foot.R", -0.09, -0.45],
	["turn", "hips", "y", -0.08],
	["turn", "spine", "x", [0.38, 0.015, 0.0]],
	["turn", "chest", "x", [0.12, 0.01, 0.0]],
	["turn", "neck", "x", -0.58],
	["turn", "head", "y", [0.0, 0.2, 0.5]],
]
const CROUCH_STILL_SINK: Array = [0.06, 0.004, 0.0]
# What the hands do creeping with a long weapon: held as walking with it
# (p_walk_long) but tipped further ahead, lower with the body.
const CROUCH_LONG_ARMS: Array = [
	["aim", "upper_arm.R", "forearm.R", [-0.1, -1.0, 0.3]],
	["aim", "forearm.R", "hand.R", [0.05, -0.8, 1.0]],
	["aim", "upper_arm.L", "forearm.L", [-0.3, -0.7, 0.75]],
	["aim", "forearm.L", "hand.L", [-0.7, 0.3, 0.75]],
]
# And with a handgun: the right forearm hanging so the muzzle points ahead and
# a little down (PersonVisual.grip_of), the left hand closed over the right.
const CROUCH_PISTOL_ARMS: Array = [
	["swing", "upper_arm.R", "forearm.R", -0.1, 0.55],
	["swing", "forearm.R", "hand.R", 0.2, -0.2],
	["swing", "upper_arm.L", "forearm.L", -0.38, 0.45],
	["swing", "forearm.L", "hand.L", -0.45, 0.05],
]

# Layers: a hand-made addition on top of a motion. For a frame at progress u
# (0..1), w = TAU * u, and a layer holds:
#   "warp": [size, lag]       read the motion at u + size * sin(w - lag) (uneven cadence)
#   "span": [from, to]        play only that part of the motion (0..1 of its length)
#   "damp": {bone: share}     the share (0..1) of the motion's turn that bone keeps
#   "steps": [...]            applied in order after the bones are matched:
#       ["turn", bone, axis, value]       bend a bone about "x" (forward), "y" (twist) or "z" (sideways)
#       ["aim", bone, child, [x, y, z]]   point a bone at a direction in the body's space
#       ["swing", bone, child, x, angle]  the same at angle radians forward of straight
#                                         down (back below 0; past a right angle it points up), x as in "aim"
#   "sink": value             lower the hips by that many metres, applied last
# A value is a number, or [base, size, lag] for base + size * sin(w - lag),
# or [base, size, lag, beats] for base + size * sin(beats * w - lag),
# or a list of such lists, added up.
const LAYERS: Dictionary = {
	# Right leg dragged and turned out, head hangs to the left, one hand half raised.
	"walk": {
		"warp": [0.07, 0.0],
		"damp": {"thigh.R": 0.55, "shin.R": 0.3, "foot.R": 0.3},
		"steps": [
			["turn", "hips", "z", [0.06, 0.08, 0.0]],
			["turn", "foot.R", "y", -0.45],
			["turn", "spine", "x", 0.2],
			["turn", "spine", "z", -0.07],
			["turn", "chest", "x", 0.26],
			["turn", "chest", "y", [0.0, 0.1, 0.6]],
			["turn", "neck", "x", 0.32],
			["turn", "head", "z", 0.3],
			["turn", "head", "y", [0.0, 0.14, 1.3]],
			["aim", "upper_arm.L", "forearm.L", [0.2, -1.0, [0.02, 0.14, 1.0]]],
			["aim", "forearm.L", "hand.L", [0.08, -1.0, [0.2, 0.1, 1.6]]],
			["aim", "upper_arm.R", "forearm.R", [-0.12, -1.0, [0.28, 0.08, -2.0]]],
			["aim", "forearm.R", "hand.R", [-0.02, -0.55, 0.85]],
		],
		"sink": 0.03,
	},
	# Both arms hang, the back is bent the most, both legs take less of the step, head to the right.
	"walk_b": {
		"warp": [0.04, 0.0],
		"damp": {"thigh.L": 0.7, "shin.L": 0.7, "thigh.R": 0.7, "shin.R": 0.7},
		"steps": [
			["turn", "hips", "z", [0.0, 0.05, 0.0]],
			["turn", "spine", "x", 0.28],
			["turn", "chest", "x", 0.34],
			["turn", "neck", "x", 0.4],
			["turn", "head", "z", -0.25],
			["aim", "upper_arm.L", "forearm.L", [0.2, -1.0, [0.04, 0.1, 1.0]]],
			["aim", "forearm.L", "hand.L", [0.08, -1.0, [0.15, 0.08, 1.6]]],
			["aim", "upper_arm.R", "forearm.R", [-0.2, -1.0, [0.04, 0.1, -1.0]]],
			["aim", "forearm.R", "hand.R", [-0.08, -1.0, [0.15, 0.08, -1.6]]],
		],
		"sink": 0.03,
	},
	# Left leg dragged and turned out, left arm held out in front, right arm hangs, back less bent, head thrown back.
	"walk_c": {
		"warp": [0.09, 0.0],
		"damp": {"thigh.L": 0.55, "shin.L": 0.3},
		"steps": [
			["turn", "foot.L", "y", 0.45],
			["turn", "spine", "x", 0.1],
			["turn", "spine", "z", 0.12],
			["turn", "chest", "x", 0.12],
			["turn", "neck", "x", -0.1],
			["turn", "head", "x", -0.1],
			["aim", "upper_arm.L", "forearm.L", [0.12, [-0.25, 0.06, 1.0], 1.0]],
			["aim", "forearm.L", "hand.L", [-0.02, [0.0, 0.05, 1.6], 1.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.12, -1.0, [0.2, 0.08, -2.0]]],
			["aim", "forearm.R", "hand.R", [-0.04, -1.0, [0.15, 0.06, -2.4]]],
		],
		"sink": 0.03,
	},
	# Standing: a slow sway, the head rolls a little behind the body, arms hang.
	"stand": {
		"steps": [
			["turn", "hips", "z", [0.0, 0.05, 0.0]],
			["turn", "spine", "x", [0.2, 0.03, 0.0, 2.0]],
			["turn", "spine", "z", [-0.06, -0.05, 0.0]],
			["turn", "chest", "x", 0.27],
			["turn", "neck", "x", [0.35, 0.05, 0.8]],
			["turn", "head", "z", [0.22, 0.14, 1.2]],
			["aim", "upper_arm.L", "forearm.L", [0.16, -1.0, [0.06, 0.05, 1.0]]],
			["aim", "forearm.L", "hand.L", [0.06, -1.0, 0.16]],
			["aim", "upper_arm.R", "forearm.R", [-0.12, -1.0, [0.14, 0.05, 1.5]]],
			["aim", "forearm.R", "hand.R", [-0.02, -0.8, 0.5]],
		],
		"sink": 0.03,
	},
	# Lunge: bent forward, face up, both arms reaching out.
	"lunge": {
		"warp": [0.05, 0.0],
		"damp": {"thigh.R": 0.75, "shin.R": 0.6},
		"steps": [
			["turn", "hips", "z", [0.0, 0.07, 0.0]],
			["turn", "spine", "x", 0.3],
			["turn", "chest", "x", 0.22],
			["turn", "chest", "y", [0.0, 0.12, 0.5]],
			["turn", "neck", "x", -0.3],
			["turn", "head", "z", 0.18],
			["aim", "upper_arm.L", "forearm.L", [0.14, [0.08, 0.07, 0.0], 1.0]],
			["aim", "forearm.L", "hand.L", [-0.05, 0.18, 1.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.18, [-0.22, 0.07, -2.4], 1.0]],
			["aim", "forearm.R", "hand.R", [0.06, 0.05, 1.0]],
		],
		"sink": 0.04,
	},
	# A walk with nothing from the motion set: the legs are written here too.
	# The left leg steps, the right is dragged after it (it swings as far, but
	# stiff: its knee hardly folds). A thigh swings as a triangle, not a sine,
	# so a foot goes back at one pace while it is down and the ground can be
	# made to go by under it at that pace (dead_body.gd, STRIDE); a knee folds
	# only on the way forward.
	"own_walk": {
		"steps": [
			["turn", "hips", "z", [0.05, 0.09, 0.3]],
			["turn", "hips", "y", [0.0, 0.1, 0.0]],
			["aim", "thigh.L", "shin.L", [0.06, -1.0, [[0.02, 0.3, 0.0], [0.0, -0.033, 0.0, 3.0], [0.0, 0.012, 0.0, 5.0]]]],
			["aim", "shin.L", "foot.L", [0.03, -1.0, [[-0.243, 0.3, 0.0], [0.0, -0.033, 0.0, 3.0], [0.0, 0.012, 0.0, 5.0], [0.0, -0.225, -1.5708], [0.0, -0.095, -1.5708, 2.0]]]],
			["aim", "thigh.R", "shin.R", [-0.1, -1.0, [[-0.02, 0.3, 3.14], [0.0, -0.033, 9.42, 3.0], [0.0, 0.012, 15.7, 5.0]]]],
			["aim", "shin.R", "foot.R", [-0.12, -1.0, [[-0.158, 0.3, 3.14], [0.0, -0.033, 9.42, 3.0], [0.0, 0.012, 15.7, 5.0], [0.0, -0.06, 1.5692], [0.0, -0.025, 4.7092, 2.0]]]],
			["turn", "foot.R", "y", -0.4],
			["turn", "spine", "x", [0.22, 0.03, 0.0, 2.0]],
			["turn", "spine", "z", [-0.07, 0.05, 0.6]],
			["turn", "chest", "x", 0.26],
			["turn", "chest", "y", [0.0, 0.12, 0.6]],
			["turn", "neck", "x", 0.32],
			["turn", "head", "z", [0.3, 0.06, 1.2]],
			["turn", "head", "y", [0.0, 0.14, 1.3]],
			["aim", "upper_arm.L", "forearm.L", [0.2, -1.0, [0.02, 0.14, 1.0]]],
			["aim", "forearm.L", "hand.L", [0.08, -1.0, [0.2, 0.1, 1.6]]],
			["aim", "upper_arm.R", "forearm.R", [-0.12, -1.0, [0.28, 0.08, -2.0]]],
			["aim", "forearm.R", "hand.R", [-0.02, -0.55, 0.85]],
		],
		"sink": [0.05, 0.02, 0.4, 2.0],
	},
	"own_lunge": {
		"steps": [
			["turn", "hips", "z", [0.0, 0.07, 0.0]],
			["aim", "thigh.L", "shin.L", [0.06, -1.0, [0.04, 0.4, 0.0]]],
			["aim", "shin.L", "foot.L", [0.03, -1.0, [-0.26, 0.44, 0.7]]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, [0.0, 0.3, 3.14]]],
			["aim", "shin.R", "foot.R", [-0.08, -1.0, [-0.22, 0.3, 3.7]]],
			["turn", "spine", "x", 0.3],
			["turn", "chest", "x", 0.22],
			["turn", "chest", "y", [0.0, 0.12, 0.5]],
			["turn", "neck", "x", -0.3],
			["turn", "head", "z", 0.18],
			["aim", "upper_arm.L", "forearm.L", [0.14, [0.08, 0.07, 0.0], 1.0]],
			["aim", "forearm.L", "hand.L", [-0.05, 0.18, 1.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.18, [-0.22, 0.07, -2.4], 1.0]],
			["aim", "forearm.R", "hand.R", [0.06, 0.05, 1.0]],
		],
		"sink": [0.06, 0.02, 0.4, 2.0],
	},
	# Struck: thrown back from the chest and coming forward again (w runs half a turn).
	"own_hit": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, [0.03, 0.12, 0.0, 0.5]]],
			["aim", "shin.L", "foot.L", [0.04, -1.0, [-0.08, -0.2, 0.0, 0.5]]],
			["aim", "thigh.R", "shin.R", [-0.1, -1.0, [0.0, -0.1, 0.0, 0.5]]],
			["aim", "shin.R", "foot.R", [-0.08, -1.0, [-0.05, -0.15, 0.0, 0.5]]],
			["turn", "spine", "x", [0.2, -0.4, 0.0, 0.5]],
			["turn", "chest", "x", [0.27, -0.35, 0.0, 0.5]],
			["turn", "chest", "y", [0.0, 0.3, 0.0, 0.5]],
			["turn", "neck", "x", [0.35, -0.6, 0.3, 0.5]],
			["turn", "head", "z", 0.22],
			["aim", "upper_arm.L", "forearm.L", [[0.16, 0.4, 0.0, 0.5], -1.0, [0.06, 0.3, 0.0, 0.5]]],
			["aim", "forearm.L", "hand.L", [[0.06, 0.3, 0.0, 0.5], -1.0, [0.16, 0.4, 0.0, 0.5]]],
			["aim", "upper_arm.R", "forearm.R", [[-0.12, -0.4, 0.0, 0.5], -1.0, [0.14, 0.3, 0.0, 0.5]]],
			["aim", "forearm.R", "hand.R", [[-0.02, -0.3, 0.0, 0.5], -0.8, [0.5, 0.3, 0.0, 0.5]]],
		],
		"sink": [0.03, 0.05, 0.0, 0.5],
	},
	# Going over on its back (played once; these values start slow and end fast):
	# the hips drop and tip back, the legs come up level, the arms fall wide.
	"own_fall": {
		"steps": [
			["turn", "hips", "x", [-1.5, -1.62, 1.5708, 0.25]],
			["turn", "spine", "x", [0.0, -0.45, 1.5708, 0.25]],
			["turn", "hips", "y", [0.25, 0.25, 1.5708, 0.25]],
			["aim", "thigh.L", "shin.L", [0.14, [-1.0, 0.92, 0.0, 0.25], [0.0, 1.0, 0.0, 0.25]]],
			["aim", "shin.L", "foot.L", [0.1, [-0.02, 0.98, 1.5708, 0.25], [1.0, 1.2, 1.5708, 0.25]]],
			["aim", "thigh.R", "shin.R", [-0.3, [-1.0, 1.15, 0.0, 0.25], [0.0, 1.0, 0.0, 0.25]]],
			["aim", "shin.R", "foot.R", [-0.1, [-0.35, 0.65, 1.5708, 0.25], [0.6, 0.7, 1.5708, 0.25]]],
			["turn", "neck", "x", [-0.25, -0.6, 1.5708, 0.25]],
			["turn", "head", "z", 0.3],
			["aim", "upper_arm.L", "forearm.L", [[1.0, 0.8, 1.5708, 0.25], [0.02, 1.02, 1.5708, 0.25], [-0.5, -0.52, 1.5708, 0.25]]],
			["aim", "forearm.L", "hand.L", [[0.7, 0.62, 1.5708, 0.25], [0.0, 1.0, 1.5708, 0.25], [-0.8, -1.0, 1.5708, 0.25]]],
			["aim", "upper_arm.R", "forearm.R", [[-1.0, -0.88, 1.5708, 0.25], [0.02, 1.02, 1.5708, 0.25], [0.2, -0.08, 1.5708, 0.25]]],
			["aim", "forearm.R", "hand.R", [[-0.6, -0.58, 1.5708, 0.25], [0.0, 0.8, 1.5708, 0.25], [0.9, 0.4, 1.5708, 0.25]]],
		],
		"sink": [0.0, 0.84, 0.0, 0.25],
	},
	# Going over on its face (played once): the knees go and it kneels, then it
	# pitches forward with its arms out in front and lies with its face turned.
	"own_fall_front": {
		"steps": [
			["turn", "hips", "x", [1.5, 1.5, 1.5708, 0.25]],
			["turn", "hips", "y", [-0.2, -0.2, 1.5708, 0.25]],
			["aim", "thigh.L", "shin.L", [0.12, [0.0, 1.0, 1.5708, 0.25], [[0.0, 0.35, 0.0, 0.5], [-1.0, -1.0, 1.5708, 0.25]]]],
			["aim", "shin.L", "foot.L", [0.08, [-1.0, 1.04, 0.0, 0.25], [0.0, -1.0, 0.0, 0.25]]],
			["aim", "thigh.R", "shin.R", [-0.2, [0.0, 1.0, 1.5708, 0.25], [[0.0, 0.3, 0.0, 0.5], [-1.0, -1.0, 1.5708, 0.25]]]],
			["aim", "shin.R", "foot.R", [-0.3, [-1.0, 1.04, 0.0, 0.25], [0.0, -0.8, 0.0, 0.25]]],
			["turn", "spine", "x", [0.0, -0.2, 1.5708, 0.25]],
			["turn", "neck", "x", [-0.2, -0.5, 1.5708, 0.25]],
			["turn", "head", "y", [0.9, 0.9, 1.5708, 0.25]],
			["aim", "upper_arm.L", "forearm.L", [[0.6, 0.4, 1.5708, 0.25], [0.0, 1.0, 1.5708, 0.25], [0.0, 0.8, 0.0, 0.25]]],
			["aim", "forearm.L", "hand.L", [[-0.3, -0.4, 1.5708, 0.25], [0.0, 1.0, 1.5708, 0.25], [0.2, 0.8, 0.0, 0.25]]],
			["aim", "upper_arm.R", "forearm.R", [[-0.9, -0.75, 1.5708, 0.25], [0.0, 1.0, 1.5708, 0.25], [0.0, 0.3, 0.0, 0.25]]],
			["aim", "forearm.R", "hand.R", [[-0.2, -0.2, 1.5708, 0.25], [0.0, 0.7, 1.5708, 0.25], [-0.7, -1.1, 1.5708, 0.25]]],
		],
		"sink": [[0.0, 0.42, 0.0, 0.25], [0.5, 0.5, 1.5708, 0.25]],
	},
	# Thrown over on its back (played once, decision 412): the head snaps back and the
	# arms fly up as the right foot goes back a step, then it goes over stiffly and
	# lies as own_fall ends, so getting up is the same. UAL's Hit_Knockback flies
	# through the air, so it is not used.
	"own_fall_thrown": {
		"steps": [
			["turn", "hips", "x", ["keys", [[0, 0.12], [0.25, -0.3], [0.45, -0.55], [0.75, -1.2], [0.85, -1.5]]]],
			["turn", "spine", "x", ["keys", [[0, 0.45], [0.2, -0.35], [0.5, -0.3], [0.85, 0.0]]]],
			["turn", "hips", "y", ["keys", [[0, 0.0], [0.3, -0.15], [0.85, 0.25]]]],
			["aim", "thigh.L", "shin.L", [0.14, ["keys", [[0, -1.0], [0.35, -0.97], [0.85, -0.08]]], ["keys", [[0, 0.0], [0.35, 0.2], [0.85, 1.0]]]]],
			["aim", "shin.L", "foot.L", [0.1, ["keys", [[0, -1.0], [0.4, -0.95], [0.9, -0.02]]], ["keys", [[0, -0.2], [0.4, -0.1], [0.9, 1.0]]]]],
			["aim", "thigh.R", "shin.R", [-0.3, ["keys", [[0, -1.0], [0.25, -0.93], [0.45, -0.9], [0.85, 0.15]]], ["keys", [[0, 0.0], [0.25, -0.35], [0.45, -0.2], [0.85, 1.0]]]]],
			["aim", "shin.R", "foot.R", [-0.1, ["keys", [[0, -1.0], [0.25, -0.95], [0.9, -0.35]]], ["keys", [[0, -0.1], [0.25, -0.3], [0.9, 0.6]]]]],
			["turn", "neck", "x", ["keys", [[0, 0.35], [0.15, -0.45], [0.5, -0.4], [0.9, -0.25]]]],
			["turn", "head", "z", 0.3],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0, 0.2], [0.25, 0.75], [0.9, 1.0]]], ["keys", [[0, -1.0], [0.25, 0.25], [0.55, 0.35], [0.9, 0.02]]], ["keys", [[0, 0.02], [0.25, -0.15], [0.9, -0.5]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0, 0.08], [0.25, 0.5], [0.9, 0.7]]], ["keys", [[0, -1.0], [0.25, 0.5], [0.55, 0.45], [0.9, 0.0]]], ["keys", [[0, 0.2], [0.25, -0.1], [0.9, -0.8]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0, -0.12], [0.25, -0.75], [0.9, -1.0]]], ["keys", [[0, -1.0], [0.25, 0.25], [0.55, 0.35], [0.9, 0.02]]], ["keys", [[0, 0.28], [0.25, 0.0], [0.9, 0.2]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0, -0.02], [0.25, -0.45], [0.9, -0.6]]], ["keys", [[0, -0.8], [0.25, 0.5], [0.55, 0.45], [0.9, 0.0]]], ["keys", [[0, 0.5], [0.25, 0.1], [0.9, 0.9]]]]],
		],
		"sink": ["keys", [[0, 0.0], [0.3, 0.06], [0.75, 0.6], [0.85, 0.84]]],
	},
	# Slumping on its face (played once, decision 412): the knees give at once and
	# it drops onto them upright, head lolling and arms hanging, then topples
	# forward whole and lies as own_fall_front ends, so getting up is the same.
	"own_fall_slump": {
		"steps": [
			["turn", "hips", "x", ["keys", [[0, 0.0], [0.3, -0.05], [0.45, 0.0], [0.8, 1.3], [0.88, 1.5]]]],
			["turn", "hips", "y", ["keys", [[0, 0.0], [0.88, -0.2]]]],
			["aim", "thigh.L", "shin.L", [0.12, ["keys", [[0, -1.0], [0.3, -0.97], [0.45, -0.95], [0.88, 0.0]]], ["keys", [[0, 0.0], [0.3, 0.15], [0.45, 0.1], [0.88, -1.0]]]]],
			["aim", "shin.L", "foot.L", [0.08, ["keys", [[0, -1.0], [0.3, -0.25], [0.88, 0.04]]], ["keys", [[0, 0.0], [0.3, -0.95], [0.88, -1.0]]]]],
			["aim", "thigh.R", "shin.R", [-0.2, ["keys", [[0, -1.0], [0.3, -0.97], [0.45, -0.95], [0.88, 0.0]]], ["keys", [[0, 0.0], [0.3, 0.12], [0.45, 0.08], [0.88, -1.0]]]]],
			["aim", "shin.R", "foot.R", [-0.3, ["keys", [[0, -1.0], [0.3, -0.25], [0.88, 0.04]]], ["keys", [[0, 0.0], [0.3, -0.9], [0.88, -0.8]]]]],
			["turn", "spine", "x", ["keys", [[0, 0.2], [0.3, 0.25], [0.6, 0.3], [0.9, 0.0]]]],
			["turn", "neck", "x", ["keys", [[0, 0.3], [0.2, 0.8], [0.6, 0.8], [0.92, -0.2]]]],
			["turn", "head", "y", ["keys", [[0, 0.0], [0.6, 0.1], [0.92, 0.9]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0, 0.2], [0.65, 0.25], [0.92, 0.6]]], ["keys", [[0, -1.0], [0.65, -0.95], [0.92, 0.0]]], ["keys", [[0, 0.0], [0.65, 0.05], [0.92, 0.8]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0, 0.1], [0.65, 0.1], [0.92, -0.3]]], ["keys", [[0, -1.0], [0.65, -0.97], [0.92, 0.0]]], ["keys", [[0, 0.2], [0.65, 0.1], [0.92, 1.0]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0, -0.15], [0.65, -0.2], [0.92, -0.9]]], ["keys", [[0, -1.0], [0.65, -0.95], [0.92, 0.0]]], ["keys", [[0, 0.0], [0.65, 0.05], [0.92, 0.3]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0, 0.0], [0.65, 0.0], [0.92, -0.2]]], ["keys", [[0, -0.7], [0.3, -1.0], [0.65, -0.97], [0.92, 0.0]]], ["keys", [[0, 0.4], [0.3, 0.1], [0.65, 0.05], [0.92, -0.7]]]]],
		],
		"sink": ["keys", [[0, 0.0], [0.3, 0.5], [0.45, 0.5], [0.88, 0.92]]],
	},
	# Getting up off its back (played once): it sits up and draws its legs
	# under it, pushes off the ground with its hands, and stands as it stood.
	"own_rise": {
		"steps": [
			["turn", "hips", "x", [[-1.5, 2.0, 0.0, 0.25], [-0.5, -0.5, 1.5708, 0.25]]],
			["turn", "hips", "y", [0.25, -0.25, 0.0, 0.25]],
			["turn", "spine", "x", [0.2, 0.65, 1.5708, 0.25]],
			["aim", "thigh.L", "shin.L", [0.12, [-1.0, -1.0, 1.5708, 0.25], [0.03, -0.97, 1.5708, 0.25]]],
			["aim", "shin.L", "foot.L", [0.07, [-0.02, -0.98, 0.0, 0.25], [1.0, -1.08, 0.0, 0.25]]],
			["aim", "thigh.R", "shin.R", [-0.2, [-1.0, -1.0, 1.5708, 0.25], [0.0, -1.0, 1.5708, 0.25]]],
			["aim", "shin.R", "foot.R", [-0.09, [-0.35, -0.65, 0.0, 0.25], [0.6, -0.65, 0.0, 0.25]]],
			["turn", "chest", "x", [0.27, 0.27, 1.5708, 0.25]],
			["turn", "neck", "x", [0.35, 0.6, 1.5708, 0.25]],
			["turn", "head", "z", 0.25],
			["aim", "upper_arm.L", "forearm.L", [[1.0, -0.84, 0.0, 0.25], [0.02, -1.02, 0.0, 0.25], [-0.5, 0.56, 0.0, 0.25]]],
			["aim", "forearm.L", "hand.L", [[0.7, -0.64, 0.0, 0.25], [0.0, -1.0, 0.0, 0.25], [-0.8, 0.96, 0.0, 0.25]]],
			["aim", "upper_arm.R", "forearm.R", [[-1.0, 0.88, 0.0, 0.25], [0.02, -1.02, 0.0, 0.25], [0.2, -0.06, 0.0, 0.25]]],
			["aim", "forearm.R", "hand.R", [[-0.6, 0.58, 0.0, 0.25], [0.0, -0.8, 0.0, 0.25], [0.9, -0.4, 0.0, 0.25]]],
		],
		"sink": [0.03, -0.81, 1.5708, 0.25],
	},
	# Getting up off its face (played once): it pushes its chest up off the
	# ground, draws its knees under it (the right foot first), and stands.
	"own_rise_front": {
		"steps": [
			["turn", "hips", "x", [0.0, -1.5, 1.5708, 0.25]],
			["turn", "hips", "y", [0.0, 0.2, 1.5708, 0.25]],
			["aim", "thigh.L", "shin.L", [0.1, [0.0, -1.0, 0.0, 0.25], [[-1.0, 1.03, 0.0, 0.25], [0.0, 0.87, 0.0, 0.5]]]],
			["aim", "shin.L", "foot.L", [0.06, [-1.0, -1.04, 1.5708, 0.25], [-0.08, 0.92, 1.5708, 0.25]]],
			["aim", "thigh.R", "shin.R", [-0.15, [0.0, -1.0, 0.0, 0.25], [[-1.0, 1.0, 0.0, 0.25], [0.0, 1.0, 0.0, 0.5]]]],
			["aim", "shin.R", "foot.R", [[-0.08, 0.22, 1.5708, 0.25], [0.04, -1.04, 0.0, 0.25], [-0.8, 0.75, 0.0, 0.25]]],
			["turn", "spine", "x", [[0.2, 0.2, 1.5708, 0.25], [0.0, -0.3, 0.0, 0.5]]],
			["turn", "chest", "x", [0.27, 0.27, 1.5708, 0.25]],
			["turn", "neck", "x", [0.35, 0.55, 1.5708, 0.25]],
			["turn", "head", "y", [0.0, -0.9, 1.5708, 0.25]],
			["turn", "head", "z", [0.22, 0.22, 1.5708, 0.25]],
			["aim", "upper_arm.L", "forearm.L", [[0.6, -0.44, 0.0, 0.25], [0.0, -1.0, 0.0, 0.25], [0.8, -0.74, 0.0, 0.25]]],
			["aim", "forearm.L", "hand.L", [[-0.3, 0.36, 0.0, 0.25], [0.0, -1.0, 0.0, 0.25], [1.0, -0.84, 0.0, 0.25]]],
			["aim", "upper_arm.R", "forearm.R", [[-0.9, 0.78, 0.0, 0.25], [0.0, -1.0, 0.0, 0.25], [0.3, -0.16, 0.0, 0.25]]],
			["aim", "forearm.R", "hand.R", [[-0.2, 0.18, 0.0, 0.25], [0.0, -0.8, 0.0, 0.25], [-0.7, 1.2, 0.0, 0.25]]],
		],
		"sink": [[0.03, -0.89, 1.5708, 0.25], [0.0, -0.15, 0.0, 0.5]],
	},
	# Hauling itself up out of a hole in the ground (played once; the drawing
	# side lifts the whole body): the arms come up over the rim and hold, then
	# press down past its sides as the body comes up, and it ends as it stands.
	"own_climb": {
		"steps": [
			["turn", "hips", "y", [0.0, 0.12, 0.0, 1.5]],
			["aim", "thigh.L", "shin.L", [0.08, -1.0, [0.03, 0.25, 0.0, 0.5]]],
			["aim", "shin.L", "foot.L", [0.04, -1.0, [-0.08, -0.3, 0.0, 0.5]]],
			["aim", "thigh.R", "shin.R", [-0.1, -1.0, [0.0, 0.1, 0.0, 0.5]]],
			["aim", "shin.R", "foot.R", [-0.08, -1.0, [-0.05, -0.2, 0.0, 0.5]]],
			["turn", "spine", "x", [0.2, 0.25, 0.0, 0.5]],
			["turn", "chest", "x", 0.27],
			["turn", "neck", "x", [0.35, 0.95, 1.5708, 0.25]],
			["turn", "head", "z", [0.22, 0.2, 0.0, 1.0]],
			["aim", "upper_arm.L", "forearm.L", [[0.16, -0.2, 1.5708, 0.25], [-1.0, -1.95, 1.5708, 0.25], [0.06, -0.3, 1.5708, 0.25]]],
			["aim", "forearm.L", "hand.L", [0.06, [-1.0, -1.9, 1.5708, 0.25], [0.16, -0.5, 1.5708, 0.25]]],
			["aim", "upper_arm.R", "forearm.R", [[-0.12, 0.3, 1.5708, 0.25], [-1.0, -1.8, 1.5708, 0.25], [0.14, -0.35, 1.5708, 0.25]]],
			["aim", "forearm.R", "hand.R", [-0.02, [-0.8, -1.6, 1.5708, 0.25], [0.5, -0.2, 1.5708, 0.25]]],
		],
		"sink": 0.03,
	},
	# Dragging itself along on its face: one arm reaches and pulls, then the
	# other; the hips roll after them and the legs trail.
	"own_crawl": {
		"steps": [
			["turn", "hips", "x", 1.5],
			["turn", "hips", "z", [0.0, 0.16, 0.6]],
			["turn", "hips", "y", [0.0, 0.14, 0.0]],
			["aim", "thigh.L", "shin.L", [0.14, 0.0, -1.0]],
			["aim", "shin.L", "foot.L", [[0.1, 0.06, 0.4], 0.04, -1.0]],
			["aim", "thigh.R", "shin.R", [-0.24, 0.0, -1.0]],
			["aim", "shin.R", "foot.R", [-0.34, 0.03, -0.7]],
			["turn", "spine", "x", -0.25],
			["turn", "chest", "y", [0.0, 0.22, 0.3]],
			["turn", "neck", "x", -0.55],
			["turn", "head", "z", [0.2, 0.1, 1.0]],
			["aim", "upper_arm.L", "forearm.L", [0.5, [0.12, 0.1, 0.0], [0.55, 0.45, 0.0]]],
			["aim", "forearm.L", "hand.L", [-0.25, [-0.2, 0.1, 0.0], [0.8, 0.5, 0.5]]],
			["aim", "upper_arm.R", "forearm.R", [-0.5, [0.12, 0.1, 3.14], [0.55, 0.45, 3.14]]],
			["aim", "forearm.R", "hand.R", [0.25, [-0.2, 0.1, 3.14], [0.8, 0.5, 3.64]]],
		],
		"sink": 0.92,
	},
	"own_run": {
		"steps": [
			["turn", "hips", "z", [0.0, 0.1, 0.0]],
			["aim", "thigh.L", "shin.L", [0.06, -1.0, [[0.1, 0.5, 0.0], [0.0, -0.056, 0.0, 3.0], [0.0, 0.02, 0.0, 5.0]]]],
			["aim", "shin.L", "foot.L", [0.03, -1.0, [[-0.404, 0.5, 0.0], [0.0, -0.056, 0.0, 3.0], [0.0, 0.02, 0.0, 5.0], [0.0, -0.4, -1.5708], [0.0, -0.17, -1.5708, 2.0]]]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, [[0.1, 0.5, 3.14], [0.0, -0.056, 9.42, 3.0], [0.0, 0.02, 15.7, 5.0]]]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, [[-0.404, 0.5, 3.14], [0.0, -0.056, 9.42, 3.0], [0.0, 0.02, 15.7, 5.0], [0.0, -0.4, 1.5692], [0.0, -0.17, 4.7092, 2.0]]]],
			["turn", "spine", "x", 0.42],
			["turn", "spine", "z", [0.0, 0.08, 0.5]],
			["turn", "chest", "x", 0.3],
			["turn", "chest", "y", [0.0, 0.16, 0.6]],
			["turn", "neck", "x", -0.4],
			["turn", "head", "z", [0.18, 0.12, 1.4]],
			["aim", "upper_arm.L", "forearm.L", [0.3, -0.8, [-0.45, 0.35, 0.9]]],
			["aim", "forearm.L", "hand.L", [0.12, -1.0, [-0.25, 0.4, 1.7]]],
			["aim", "upper_arm.R", "forearm.R", [-0.3, -0.8, [-0.45, 0.35, -2.2]]],
			["aim", "forearm.R", "hand.R", [-0.12, -1.0, [-0.25, 0.4, -1.4]]],
		],
		"sink": [0.1, 0.04, 0.4, 2.0],
	},
	"own_stand": {
		"steps": [
			["turn", "hips", "z", [0.0, 0.05, 0.0]],
			["aim", "thigh.L", "shin.L", [0.08, -1.0, 0.03]],
			["aim", "shin.L", "foot.L", [0.04, -1.0, -0.08]],
			["aim", "thigh.R", "shin.R", [-0.1, -1.0, 0.0]],
			["aim", "shin.R", "foot.R", [-0.08, -1.0, -0.05]],
			["turn", "spine", "x", [0.2, 0.03, 0.0, 2.0]],
			["turn", "spine", "z", [-0.06, -0.05, 0.0]],
			["turn", "chest", "x", 0.27],
			["turn", "neck", "x", [0.35, 0.05, 0.8]],
			["turn", "head", "z", [0.22, 0.14, 1.2]],
			["aim", "upper_arm.L", "forearm.L", [0.16, -1.0, [0.06, 0.05, 1.0]]],
			["aim", "forearm.L", "hand.L", [0.06, -1.0, 0.16]],
			["aim", "upper_arm.R", "forearm.R", [-0.12, -1.0, [0.14, 0.05, 1.5]]],
			["aim", "forearm.R", "hand.R", [-0.02, -0.8, 0.5]],
		],
		"sink": 0.03,
	},
	# The other two walks: the left leg is the one dragged; and a short shuffle,
	# both feet barely leaving the ground, bent further over.
	"own_walk_b": {
		"steps": [
			["turn", "hips", "z", [-0.05, 0.09, 3.44]],
			["turn", "hips", "y", [0.0, 0.1, 3.14]],
			["aim", "thigh.R", "shin.R", [-0.06, -1.0, [[0.02, 0.3, 3.14], [0.0, -0.033, 9.42, 3.0], [0.0, 0.012, 15.7, 5.0]]]],
			["aim", "shin.R", "foot.R", [-0.03, -1.0, [[-0.243, 0.3, 3.14], [0.0, -0.033, 9.42, 3.0], [0.0, 0.012, 15.7, 5.0], [0.0, -0.225, 1.5692], [0.0, -0.095, 4.7092, 2.0]]]],
			["aim", "thigh.L", "shin.L", [0.1, -1.0, [[-0.02, 0.3, 0.0], [0.0, -0.033, 0.0, 3.0], [0.0, 0.012, 0.0, 5.0]]]],
			["aim", "shin.L", "foot.L", [0.12, -1.0, [[-0.158, 0.3, 0.0], [0.0, -0.033, 0.0, 3.0], [0.0, 0.012, 0.0, 5.0], [0.0, -0.06, -1.5708], [0.0, -0.025, -1.5708, 2.0]]]],
			["turn", "foot.L", "y", 0.4],
			["turn", "spine", "x", [0.16, 0.03, 0.0, 2.0]],
			["turn", "spine", "z", [0.08, 0.05, 3.7]],
			["turn", "chest", "x", 0.2],
			["turn", "chest", "y", [0.0, 0.12, 3.7]],
			["turn", "neck", "x", 0.4],
			["turn", "head", "z", [-0.28, 0.06, 4.3]],
			["aim", "upper_arm.R", "forearm.R", [-0.2, -1.0, [0.02, 0.14, 4.1]]],
			["aim", "forearm.R", "hand.R", [-0.08, -1.0, [0.2, 0.1, 4.7]]],
			["aim", "upper_arm.L", "forearm.L", [0.3, -1.0, [0.1, 0.1, 1.1]]],
			["aim", "forearm.L", "hand.L", [0.2, -1.0, [0.05, 0.12, 1.7]]],
		],
		"sink": [0.05, 0.02, 3.5, 2.0],
	},
	"own_walk_c": {
		"steps": [
			["turn", "hips", "z", [0.0, 0.06, 0.3]],
			["aim", "thigh.L", "shin.L", [0.1, -1.0, [[0.08, 0.2, 0.0], [0.0, -0.022, 0.0, 3.0], [0.0, 0.008, 0.0, 5.0]]]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, [[-0.224, 0.2, 0.0], [0.0, -0.022, 0.0, 3.0], [0.0, 0.008, 0.0, 5.0], [0.0, -0.1, -1.5708], [0.0, -0.042, -1.5708, 2.0]]]],
			["aim", "thigh.R", "shin.R", [-0.1, -1.0, [[0.08, 0.2, 3.14], [0.0, -0.022, 9.42, 3.0], [0.0, 0.008, 15.7, 5.0]]]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, [[-0.224, 0.2, 3.14], [0.0, -0.022, 9.42, 3.0], [0.0, 0.008, 15.7, 5.0], [0.0, -0.1, 1.5692], [0.0, -0.042, 4.7092, 2.0]]]],
			["turn", "spine", "x", [0.34, 0.04, 0.0, 2.0]],
			["turn", "chest", "x", 0.34],
			["turn", "chest", "y", [0.0, 0.08, 0.6]],
			["turn", "neck", "x", 0.2],
			["turn", "head", "z", [0.0, 0.2, 0.9]],
			["aim", "upper_arm.L", "forearm.L", [0.14, -1.0, [0.3, 0.06, 1.0]]],
			["aim", "forearm.L", "hand.L", [0.02, -0.7, [0.7, 0.08, 1.6]]],
			["aim", "upper_arm.R", "forearm.R", [-0.14, -1.0, [0.3, 0.06, 4.1]]],
			["aim", "forearm.R", "hand.R", [-0.02, -0.7, [0.7, 0.08, 4.7]]],
		],
		"sink": [0.09, 0.015, 0.4, 2.0],
	},
	# Spent after a dash: bent double and heaving, lurching from foot to foot
	# on a wide stance, head and arms hanging loose.
	"own_stagger": {
		"steps": [
			["turn", "hips", "z", [0.0, 0.17, 0.4]],
			["turn", "hips", "y", [0.0, 0.2, 0.0]],
			["aim", "thigh.L", "shin.L", [0.2, -1.0, [[0.06, 0.26, 0.0], [0.0, -0.029, 0.0, 3.0], [0.0, 0.01, 0.0, 5.0]]]],
			["aim", "shin.L", "foot.L", [0.14, -1.0, [[-0.235, 0.26, 0.0], [0.0, -0.029, 0.0, 3.0], [0.0, 0.01, 0.0, 5.0], [0.0, -0.15, -1.5708], [0.0, -0.064, -1.5708, 2.0]]]],
			["aim", "thigh.R", "shin.R", [-0.2, -1.0, [[0.06, 0.26, 3.14], [0.0, -0.029, 9.42, 3.0], [0.0, 0.01, 15.7, 5.0]]]],
			["aim", "shin.R", "foot.R", [-0.14, -1.0, [[-0.235, 0.26, 3.14], [0.0, -0.029, 9.42, 3.0], [0.0, 0.01, 15.7, 5.0], [0.0, -0.15, 1.5692], [0.0, -0.064, 4.7092, 2.0]]]],
			["turn", "spine", "x", [0.62, 0.1, 0.0, 2.0]],
			["turn", "spine", "z", [0.0, -0.14, 0.4]],
			["turn", "chest", "x", [0.42, 0.08, 0.5, 2.0]],
			["turn", "chest", "y", [0.0, 0.16, 0.6]],
			["turn", "neck", "x", [0.5, 0.12, 1.2, 2.0]],
			["turn", "head", "z", [0.0, 0.34, 1.0]],
			["aim", "upper_arm.L", "forearm.L", [[0.16, 0.12, 0.8], -1.0, [0.5, 0.2, 1.2]]],
			["aim", "forearm.L", "hand.L", [[0.04, 0.14, 1.4], -1.0, [0.55, 0.26, 1.9]]],
			["aim", "upper_arm.R", "forearm.R", [[-0.16, 0.12, 0.8], -1.0, [0.5, 0.2, 4.3]]],
			["aim", "forearm.R", "hand.R", [[-0.04, 0.14, 1.4], -1.0, [0.55, 0.26, 5.0]]],
		],
		"sink": [0.13, 0.03, 0.4, 2.0],
	},
	# Still: both hands and the face up against a pane.
	"own_press": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.1, -1.0, 0.06]],
			["aim", "shin.L", "foot.L", [0.05, -1.0, -0.1]],
			["aim", "thigh.R", "shin.R", [-0.1, -1.0, 0.02]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, -0.06]],
			["turn", "spine", "x", 0.14],
			["turn", "chest", "x", 0.1],
			["turn", "neck", "x", -0.12],
			["turn", "head", "z", 0.2],
			["aim", "upper_arm.L", "forearm.L", [0.3, 0.12, 1.0]],
			["aim", "forearm.L", "hand.L", [-0.12, 0.55, 1.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.34, -0.1, 1.0]],
			["aim", "forearm.R", "hand.R", [0.1, 0.7, 1.0]],
		],
		"sink": 0.02,
	},
	# Still: sat on the ground, legs out in front, the back and head gone slack.
	"own_sit": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.2, -0.02, 1.0]],
			["aim", "shin.L", "foot.L", [0.12, -0.12, 1.0]],
			["aim", "thigh.R", "shin.R", [-0.14, 0.3, 1.0]],
			["aim", "shin.R", "foot.R", [-0.05, -0.75, 0.6]],
			["turn", "spine", "x", 0.3],
			["turn", "spine", "z", 0.1],
			["turn", "chest", "x", 0.28],
			["turn", "neck", "x", 0.5],
			["turn", "head", "z", 0.28],
			["aim", "upper_arm.L", "forearm.L", [0.3, -1.0, 0.25]],
			["aim", "forearm.L", "hand.L", [0.25, -0.6, 0.7]],
			["aim", "upper_arm.R", "forearm.R", [-0.3, -1.0, 0.2]],
			["aim", "forearm.R", "hand.R", [-0.1, -0.5, 0.8]],
		],
		"sink": 0.8,
	},
	# The beat before it runs, standing on its own legs (see "tell"): it drops
	# low over bent knees, arms drawn back, face up at what it has seen.
	"own_tell": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.14, -1.0, [0.03, 0.5, 0.0, 0.25]]],
			["aim", "shin.L", "foot.L", [0.05, -1.0, [-0.08, -0.62, 0.0, 0.25]]],
			["aim", "thigh.R", "shin.R", [-0.16, -1.0, [0.0, 0.42, 0.0, 0.25]]],
			["aim", "shin.R", "foot.R", [-0.08, -1.0, [-0.05, -0.7, 0.0, 0.25]]],
			["turn", "hips", "y", [0.0, 0.22, 0.0, 0.25]],
			["turn", "spine", "x", [0.2, 0.62, 0.0, 0.25]],
			["turn", "chest", "x", [0.27, 0.16, 0.0, 0.25]],
			["turn", "chest", "y", [0.0, -0.3, 0.0, 0.25]],
			["turn", "neck", "x", [0.35, -0.95, 0.0, 0.25]],
			["turn", "head", "z", [0.22, -0.2, 0.0, 0.25]],
			["aim", "upper_arm.L", "forearm.L", [[0.22, 0.5, 0.0, 0.25], -1.0, [0.06, -0.75, 0.0, 0.25]]],
			["aim", "forearm.L", "hand.L", [[0.1, 0.45, 0.0, 0.25], -1.0, [0.16, -0.5, 0.0, 0.25]]],
			["aim", "upper_arm.R", "forearm.R", [[-0.22, -0.5, 0.0, 0.25], -1.0, [0.14, -0.8, 0.0, 0.25]]],
			["aim", "forearm.R", "hand.R", [[-0.1, -0.45, 0.0, 0.25], -1.0, [0.3, -0.6, 0.0, 0.25]]],
		],
		"sink": [0.03, 0.27, 0.0, 0.25],
	},
	# At a door (motion.gd dead_thump): close up to it, both arms go up and the
	# forearms come down on it at 0.85 of the round, the chest and head pitching
	# in after them; then they fall back a little and go up again. The feet stay
	# put (nothing in it covers ground).
	"own_thump": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.12, -1.0, 0.04]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.1]],
			["aim", "thigh.R", "shin.R", [-0.12, -1.0, -0.06]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, -0.14]],
			["turn", "spine", "x", ["keys", [[0.0, 0.2], [0.35, 0.18], [0.72, 0.06], [0.85, 0.32], [1.0, 0.2]]]],
			["turn", "spine", "z", -0.04],
			["turn", "chest", "x", ["keys", [[0.0, 0.2], [0.72, 0.06], [0.85, 0.3], [1.0, 0.2]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.18], [0.72, 0.0], [0.87, 0.32], [1.0, 0.18]]]],
			["turn", "head", "z", 0.14],
			["aim", "upper_arm.L", "forearm.L", [0.24, ["keys", [[0.0, 0.0], [0.3, -0.25], [0.72, 0.6], [0.85, 0.2], [1.0, 0.0]]], ["keys", [[0.0, 1.0], [0.3, 0.9], [0.72, 0.6], [0.85, 1.0], [1.0, 1.0]]]]],
			["aim", "forearm.L", "hand.L", [0.04, ["keys", [[0.0, 0.0], [0.3, 0.15], [0.72, 0.75], [0.85, -0.3], [1.0, 0.0]]], ["keys", [[0.0, 1.0], [0.3, 1.0], [0.72, -0.45], [0.85, 1.0], [1.0, 1.0]]]]],
			["aim", "upper_arm.R", "forearm.R", [-0.24, ["keys", [[0.0, 0.0], [0.3, -0.25], [0.72, 0.6], [0.85, 0.2], [1.0, 0.0]]], ["keys", [[0.0, 1.0], [0.3, 0.9], [0.72, 0.6], [0.85, 1.0], [1.0, 1.0]]]]],
			["aim", "forearm.R", "hand.R", [-0.04, ["keys", [[0.0, 0.0], [0.3, 0.15], [0.72, 0.75], [0.85, -0.3], [1.0, 0.0]]], ["keys", [[0.0, 1.0], [0.3, 1.0], [0.72, -0.45], [0.85, 1.0], [1.0, 1.0]]]]],
		],
		"sink": 0.04,
	},
	# Clawing at a door: one hand reaches high, catches on it (the left at 0.23
	# of the round, the right at 0.73) and drags down to the chest, the chest
	# twisting after the hand that claws.
	"own_claw": {
		"steps": [
			["turn", "hips", "z", [0.0, 0.05, -0.126]],
			["aim", "thigh.L", "shin.L", [0.12, -1.0, 0.04]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.1]],
			["aim", "thigh.R", "shin.R", [-0.12, -1.0, -0.04]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, -0.12]],
			["turn", "spine", "x", [0.2, 0.05, 1.571, 2.0]],
			["turn", "chest", "x", 0.2],
			["turn", "chest", "y", [0.0, -0.18, -0.126]],
			["turn", "neck", "x", [0.12, 0.08, 1.822, 2.0]],
			["turn", "head", "z", [0.1, 0.1, -0.126]],
			["aim", "upper_arm.L", "forearm.L", [0.2, ["keys", [[0.0, 0.35], [0.15, 0.6], [0.23, 0.5], [0.45, -0.3], [0.5, -0.35], [0.6, -0.3], [0.9, 0.2], [1.0, 0.35]]], ["keys", [[0.0, 0.7], [0.15, 0.8], [0.23, 1.0], [0.45, 1.0], [0.5, 0.95], [0.6, 0.6], [0.9, 0.5], [1.0, 0.7]]]]],
			["aim", "forearm.L", "hand.L", [0.06, ["keys", [[0.0, 0.8], [0.15, 0.6], [0.23, 0.25], [0.45, -0.15], [0.5, -0.2], [0.6, 0.3], [0.9, 0.9], [1.0, 0.8]]], ["keys", [[0.0, 0.5], [0.15, 0.9], [0.23, 1.0], [0.45, 1.0], [0.5, 1.0], [0.6, 0.7], [0.9, 0.35], [1.0, 0.5]]]]],
			["aim", "upper_arm.R", "forearm.R", [-0.2, ["keys", [[0.0, -0.35], [0.1, -0.3], [0.4, 0.2], [0.5, 0.35], [0.65, 0.6], [0.73, 0.5], [0.95, -0.3], [1.0, -0.35]]], ["keys", [[0.0, 0.95], [0.1, 0.6], [0.4, 0.5], [0.5, 0.7], [0.65, 0.8], [0.73, 1.0], [0.95, 1.0], [1.0, 0.95]]]]],
			["aim", "forearm.R", "hand.R", [-0.06, ["keys", [[0.0, -0.2], [0.1, 0.3], [0.4, 0.9], [0.5, 0.8], [0.65, 0.6], [0.73, 0.25], [0.95, -0.15], [1.0, -0.2]]], ["keys", [[0.0, 1.0], [0.1, 0.7], [0.4, 0.35], [0.5, 0.5], [0.65, 0.9], [0.73, 1.0], [0.95, 1.0], [1.0, 1.0]]]]],
		],
		"sink": [0.04, 0.01, 1.571, 2.0],
	},
	# Struck on the head (the reference game's four, each at 0.4 s, eased in
	# 0.1 s): from the left, the head and shoulders thrown over to its right and
	# turned away, the arms flung after them, then standing again.
	"own_hit_left": {
		"steps": [
			["turn", "hips", "z", ["keys", [[0.0, 0.0], [0.22, -0.06], [0.5, -0.027], [1.0, 0.0]]]],
			["aim", "thigh.L", "shin.L", [0.08, -1.0, 0.03]],
			["aim", "shin.L", "foot.L", [0.04, -1.0, -0.08]],
			["aim", "thigh.R", "shin.R", [["keys", [[0.0, -0.1], [0.22, -0.18], [0.5, -0.136], [1.0, -0.1]]], -1.0, 0.0]],
			["aim", "shin.R", "foot.R", [["keys", [[0.0, -0.08], [0.22, -0.14], [0.5, -0.107], [1.0, -0.08]]], -1.0, -0.05]],
			["turn", "spine", "x", ["keys", [[0.0, 0.2], [0.22, 0.14], [0.5, 0.173], [1.0, 0.2]]]],
			["turn", "spine", "z", ["keys", [[0.0, -0.06], [0.22, 0.08], [0.5, 0.003], [1.0, -0.06]]]],
			["turn", "chest", "x", 0.27],
			["turn", "chest", "z", ["keys", [[0.0, 0.0], [0.22, 0.25], [0.5, 0.113], [1.0, 0.0]]]],
			["turn", "chest", "y", ["keys", [[0.0, 0.0], [0.22, -0.35], [0.5, -0.158], [1.0, 0.0]]]],
			["turn", "neck", "x", 0.35],
			["turn", "neck", "z", ["keys", [[0.0, 0.0], [0.22, 0.2], [0.5, 0.09], [1.0, 0.0]]]],
			["turn", "head", "z", ["keys", [[0.0, 0.22], [0.22, 0.82], [0.5, 0.49], [1.0, 0.22]]]],
			["turn", "head", "y", ["keys", [[0.0, 0.0], [0.22, -0.55], [0.5, -0.248], [1.0, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.16], [0.3, 0.44], [0.6, 0.258], [1.0, 0.16]]], ["keys", [[0.0, -1.0], [0.3, -0.7], [0.6, -0.895], [1.0, -1.0]]], ["keys", [[0.0, 0.06], [0.3, 0.22], [0.6, 0.116], [1.0, 0.06]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0.0, 0.06], [0.3, 0.16], [0.6, 0.095], [1.0, 0.06]]], ["keys", [[0.0, -1.0], [0.3, -0.6], [0.6, -0.86], [1.0, -1.0]]], ["keys", [[0.0, 0.16], [0.3, 0.36], [0.6, 0.23], [1.0, 0.16]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.12], [0.3, -0.42], [0.6, -0.225], [1.0, -0.12]]], ["keys", [[0.0, -1.0], [0.3, -0.8], [0.6, -0.93], [1.0, -1.0]]], ["keys", [[0.0, 0.14], [0.3, -0.1], [0.6, 0.056], [1.0, 0.14]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0.0, -0.02], [0.3, -0.12], [0.6, -0.055], [1.0, -0.02]]], ["keys", [[0.0, -0.8], [0.3, -0.5], [0.6, -0.695], [1.0, -0.8]]], ["keys", [[0.0, 0.5], [0.3, 0.2], [0.6, 0.395], [1.0, 0.5]]]]],
		],
		"sink": ["keys", [[0.0, 0.03], [0.22, 0.06], [0.5, 0.043], [1.0, 0.03]]],
	},
	# From the right: the same the other way.
	"own_hit_right": {
		"steps": [
			["turn", "hips", "z", ["keys", [[0.0, 0.0], [0.22, 0.06], [0.5, 0.027], [1.0, 0.0]]]],
			["aim", "thigh.L", "shin.L", [["keys", [[0.0, 0.08], [0.22, 0.16], [0.5, 0.116], [1.0, 0.08]]], -1.0, 0.03]],
			["aim", "shin.L", "foot.L", [["keys", [[0.0, 0.04], [0.22, 0.1], [0.5, 0.067], [1.0, 0.04]]], -1.0, -0.08]],
			["aim", "thigh.R", "shin.R", [-0.1, -1.0, 0.0]],
			["aim", "shin.R", "foot.R", [-0.08, -1.0, -0.05]],
			["turn", "spine", "x", ["keys", [[0.0, 0.2], [0.22, 0.14], [0.5, 0.173], [1.0, 0.2]]]],
			["turn", "spine", "z", ["keys", [[0.0, -0.06], [0.22, -0.2], [0.5, -0.123], [1.0, -0.06]]]],
			["turn", "chest", "x", 0.27],
			["turn", "chest", "z", ["keys", [[0.0, 0.0], [0.22, -0.25], [0.5, -0.113], [1.0, 0.0]]]],
			["turn", "chest", "y", ["keys", [[0.0, 0.0], [0.22, 0.35], [0.5, 0.158], [1.0, 0.0]]]],
			["turn", "neck", "x", 0.35],
			["turn", "neck", "z", ["keys", [[0.0, 0.0], [0.22, -0.2], [0.5, -0.09], [1.0, 0.0]]]],
			["turn", "head", "z", ["keys", [[0.0, 0.22], [0.22, -0.38], [0.5, -0.05], [1.0, 0.22]]]],
			["turn", "head", "y", ["keys", [[0.0, 0.0], [0.22, 0.55], [0.5, 0.248], [1.0, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.16], [0.3, 0.46], [0.6, 0.265], [1.0, 0.16]]], ["keys", [[0.0, -1.0], [0.3, -0.8], [0.6, -0.93], [1.0, -1.0]]], ["keys", [[0.0, 0.06], [0.3, -0.18], [0.6, -0.024], [1.0, 0.06]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0.0, 0.06], [0.3, 0.16], [0.6, 0.095], [1.0, 0.06]]], ["keys", [[0.0, -1.0], [0.3, -0.7], [0.6, -0.895], [1.0, -1.0]]], ["keys", [[0.0, 0.16], [0.3, -0.14], [0.6, 0.055], [1.0, 0.16]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.12], [0.3, -0.4], [0.6, -0.218], [1.0, -0.12]]], ["keys", [[0.0, -1.0], [0.3, -0.7], [0.6, -0.895], [1.0, -1.0]]], ["keys", [[0.0, 0.14], [0.3, 0.3], [0.6, 0.196], [1.0, 0.14]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0.0, -0.02], [0.3, -0.12], [0.6, -0.055], [1.0, -0.02]]], ["keys", [[0.0, -0.8], [0.3, -0.4], [0.6, -0.66], [1.0, -0.8]]], ["keys", [[0.0, 0.5], [0.3, 0.7], [0.6, 0.57], [1.0, 0.5]]]]],
		],
		"sink": ["keys", [[0.0, 0.03], [0.22, 0.06], [0.5, 0.043], [1.0, 0.03]]],
	},
	# From above: the head driven down, the knees giving under it.
	"own_hit_top": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, ["keys", [[0.0, 0.03], [0.25, 0.28], [0.55, 0.155], [1.0, 0.03]]]]],
			["aim", "shin.L", "foot.L", [0.04, -1.0, ["keys", [[0.0, -0.08], [0.25, -0.23], [0.55, -0.155], [1.0, -0.08]]]]],
			["aim", "thigh.R", "shin.R", [-0.1, -1.0, ["keys", [[0.0, 0.0], [0.25, 0.25], [0.55, 0.125], [1.0, 0.0]]]]],
			["aim", "shin.R", "foot.R", [-0.08, -1.0, ["keys", [[0.0, -0.05], [0.25, -0.2], [0.55, -0.125], [1.0, -0.05]]]]],
			["turn", "spine", "x", ["keys", [[0.0, 0.2], [0.25, 0.35], [0.55, 0.275], [1.0, 0.2]]]],
			["turn", "spine", "z", -0.06],
			["turn", "chest", "x", ["keys", [[0.0, 0.27], [0.25, 0.47], [0.55, 0.37], [1.0, 0.27]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.35], [0.25, 0.75], [0.55, 0.55], [1.0, 0.35]]]],
			["turn", "head", "z", 0.22],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.16], [0.3, 0.31], [0.6, 0.212], [1.0, 0.16]]], ["keys", [[0.0, -1.0], [0.3, -0.8], [0.6, -0.93], [1.0, -1.0]]], ["keys", [[0.0, 0.06], [0.3, -0.04], [0.6, 0.025], [1.0, 0.06]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0.0, 0.06], [0.3, 0.11], [0.6, 0.077], [1.0, 0.06]]], ["keys", [[0.0, -1.0], [0.3, -0.8], [0.6, -0.93], [1.0, -1.0]]], ["keys", [[0.0, 0.16], [0.3, 0.06], [0.6, 0.125], [1.0, 0.16]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.12], [0.3, -0.27], [0.6, -0.172], [1.0, -0.12]]], ["keys", [[0.0, -1.0], [0.3, -0.8], [0.6, -0.93], [1.0, -1.0]]], ["keys", [[0.0, 0.14], [0.3, 0.04], [0.6, 0.105], [1.0, 0.14]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0.0, -0.02], [0.3, -0.07], [0.6, -0.037], [1.0, -0.02]]], ["keys", [[0.0, -0.8], [0.3, -0.7], [0.6, -0.765], [1.0, -0.8]]], ["keys", [[0.0, 0.5], [0.3, 0.3], [0.6, 0.43], [1.0, 0.5]]]]],
		],
		"sink": ["keys", [[0.0, 0.03], [0.25, 0.15], [0.55, 0.09], [1.0, 0.03]]],
	},
	# From under the chin: the head snapped back, the back arched, the arms flung up.
	"own_hit_upper": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, 0.03]],
			["aim", "shin.L", "foot.L", [0.04, -1.0, -0.08]],
			["aim", "thigh.R", "shin.R", [-0.1, -1.0, ["keys", [[0.0, 0.0], [0.22, -0.2], [0.5, -0.09], [1.0, 0.0]]]]],
			["aim", "shin.R", "foot.R", [-0.08, -1.0, ["keys", [[0.0, -0.05], [0.22, -0.3], [0.5, -0.163], [1.0, -0.05]]]]],
			["turn", "spine", "x", ["keys", [[0.0, 0.2], [0.22, -0.05], [0.5, 0.088], [1.0, 0.2]]]],
			["turn", "spine", "z", -0.06],
			["turn", "chest", "x", ["keys", [[0.0, 0.27], [0.22, -0.13], [0.5, 0.09], [1.0, 0.27]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.35], [0.22, -0.5], [0.5, -0.033], [1.0, 0.35]]]],
			["turn", "head", "x", ["keys", [[0.0, 0.0], [0.22, -0.35], [0.5, -0.158], [1.0, 0.0]]]],
			["turn", "head", "z", 0.22],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.16], [0.3, 0.61], [0.6, 0.318], [1.0, 0.16]]], ["keys", [[0.0, -1.0], [0.3, -0.1], [0.6, -0.685], [1.0, -1.0]]], ["keys", [[0.0, 0.06], [0.3, 0.16], [0.6, 0.095], [1.0, 0.06]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0.0, 0.06], [0.3, 0.21], [0.6, 0.112], [1.0, 0.06]]], ["keys", [[0.0, -1.0], [0.3, 0.0], [0.6, -0.65], [1.0, -1.0]]], 0.16]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.12], [0.3, -0.57], [0.6, -0.277], [1.0, -0.12]]], ["keys", [[0.0, -1.0], [0.3, -0.1], [0.6, -0.685], [1.0, -1.0]]], ["keys", [[0.0, 0.14], [0.3, 0.24], [0.6, 0.175], [1.0, 0.14]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0.0, -0.02], [0.3, -0.17], [0.6, -0.072], [1.0, -0.02]]], ["keys", [[0.0, -0.8], [0.3, 0.1], [0.6, -0.485], [1.0, -0.8]]], 0.5]],
		],
		"sink": ["keys", [[0.0, 0.03], [0.22, 0.05], [0.5, 0.039], [1.0, 0.03]]],
	},
	# Turning round to something it has noticed on its left (the field turns the
	# body; this is how it goes): the head comes up and round first, the chest
	# and hips after it, the near foot stepping out and the other after it.
	"own_turn_left": {
		"steps": [
			["turn", "hips", "y", ["keys", [[0.0, 0.0], [0.4, 0.3], [0.75, 0.15], [1.0, 0.0]]]],
			["aim", "thigh.L", "shin.L", [["keys", [[0.0, 0.08], [0.42, 0.2], [1.0, 0.08]]], -1.0, ["keys", [[0.0, 0.03], [0.3, 0.03], [0.42, 0.25], [0.55, 0.06], [1.0, 0.03]]]]],
			["aim", "shin.L", "foot.L", [0.04, -1.0, ["keys", [[0.0, -0.08], [0.3, -0.08], [0.42, -0.35], [0.55, -0.06], [1.0, -0.08]]]]],
			["aim", "thigh.R", "shin.R", [-0.1, -1.0, ["keys", [[0.0, 0.0], [0.55, 0.0], [0.66, 0.2], [0.78, 0.0], [1.0, 0.0]]]]],
			["aim", "shin.R", "foot.R", [-0.08, -1.0, ["keys", [[0.0, -0.05], [0.55, -0.05], [0.66, -0.3], [0.78, -0.05], [1.0, -0.05]]]]],
			["turn", "foot.L", "y", ["keys", [[0.0, 0.0], [0.45, 0.4], [1.0, 0.0]]]],
			["turn", "spine", "x", ["keys", [[0.0, 0.2], [0.15, 0.1], [0.7, 0.16], [1.0, 0.2]]]],
			["turn", "spine", "z", -0.06],
			["turn", "chest", "x", 0.27],
			["turn", "chest", "y", ["keys", [[0.0, 0.0], [0.3, 0.55], [0.7, 0.35], [1.0, 0.0]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.35], [0.12, -0.1], [0.6, 0.15], [1.0, 0.35]]]],
			["turn", "head", "z", 0.22],
			["turn", "head", "y", ["keys", [[0.0, 0.0], [0.18, 1.1], [0.55, 0.7], [1.0, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.16], [0.15, 0.28], [0.6, 0.2], [1.0, 0.16]]], -1.0, ["keys", [[0.0, 0.06], [0.2, 0.35], [0.7, 0.15], [1.0, 0.06]]]]],
			["aim", "forearm.L", "hand.L", [0.06, -1.0, ["keys", [[0.0, 0.16], [0.2, 0.4], [1.0, 0.16]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.12], [0.15, -0.24], [0.6, -0.16], [1.0, -0.12]]], -1.0, ["keys", [[0.0, 0.14], [0.2, 0.2], [0.7, 0.18], [1.0, 0.14]]]]],
			["aim", "forearm.R", "hand.R", [-0.02, -0.8, ["keys", [[0.0, 0.5], [0.2, 0.6], [1.0, 0.5]]]]],
		],
		"sink": ["keys", [[0.0, 0.03], [0.15, 0.05], [0.42, 0.04], [0.66, 0.04], [1.0, 0.03]]],
	},
	# The same to its right.
	"own_turn_right": {
		"steps": [
			["turn", "hips", "y", ["keys", [[0.0, 0.0], [0.4, -0.3], [0.75, -0.15], [1.0, 0.0]]]],
			["aim", "thigh.L", "shin.L", [0.08, -1.0, ["keys", [[0.0, 0.03], [0.55, 0.03], [0.66, 0.2], [0.78, 0.0], [1.0, 0.03]]]]],
			["aim", "shin.L", "foot.L", [0.04, -1.0, ["keys", [[0.0, -0.08], [0.55, -0.08], [0.66, -0.3], [0.78, -0.05], [1.0, -0.08]]]]],
			["aim", "thigh.R", "shin.R", [["keys", [[0.0, -0.1], [0.42, -0.22], [1.0, -0.1]]], -1.0, ["keys", [[0.0, 0.0], [0.3, 0.0], [0.42, 0.25], [0.55, 0.06], [1.0, 0.0]]]]],
			["aim", "shin.R", "foot.R", [-0.08, -1.0, ["keys", [[0.0, -0.05], [0.3, -0.05], [0.42, -0.35], [0.55, -0.06], [1.0, -0.05]]]]],
			["turn", "foot.R", "y", ["keys", [[0.0, 0.0], [0.45, -0.4], [1.0, 0.0]]]],
			["turn", "spine", "x", ["keys", [[0.0, 0.2], [0.15, 0.1], [0.7, 0.16], [1.0, 0.2]]]],
			["turn", "spine", "z", -0.06],
			["turn", "chest", "x", 0.27],
			["turn", "chest", "y", ["keys", [[0.0, 0.0], [0.3, -0.55], [0.7, -0.35], [1.0, 0.0]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.35], [0.12, -0.1], [0.6, 0.15], [1.0, 0.35]]]],
			["turn", "head", "z", 0.22],
			["turn", "head", "y", ["keys", [[0.0, 0.0], [0.18, -1.1], [0.55, -0.7], [1.0, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.16], [0.15, 0.28], [0.6, 0.2], [1.0, 0.16]]], -1.0, ["keys", [[0.0, 0.06], [0.2, 0.2], [0.7, 0.15], [1.0, 0.06]]]]],
			["aim", "forearm.L", "hand.L", [0.06, -1.0, ["keys", [[0.0, 0.16], [0.2, 0.4], [1.0, 0.16]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.12], [0.15, -0.24], [0.6, -0.16], [1.0, -0.12]]], -1.0, ["keys", [[0.0, 0.14], [0.2, 0.35], [0.7, 0.18], [1.0, 0.14]]]]],
			["aim", "forearm.R", "hand.R", [-0.02, -0.8, ["keys", [[0.0, 0.5], [0.2, 0.6], [1.0, 0.5]]]]],
		],
		"sink": ["keys", [[0.0, 0.03], [0.15, 0.05], [0.42, 0.04], [0.66, 0.04], [1.0, 0.03]]],
	},
	# Two slower walks (the reference game's dead walk five ways). A shuffle:
	# short steps on a wide stance, the feet hardly lifting, bent over and tipped
	# to one side, the head hanging on the chest, one arm swinging across.
	"own_walk_d": {
		"steps": [
			["turn", "hips", "z", [0.0, 0.06, 0.3]],
			["turn", "hips", "y", [0.0, 0.06, 0.0]],
			["aim", "thigh.L", "shin.L", [0.12, -1.0, [[0.04, 0.16, 0.0], [0.0, -0.018, 0.0, 3.0], [0.0, 0.006, 0.0, 5.0]]]],
			["aim", "shin.L", "foot.L", [0.084, -1.0, [[-0.2, 0.16, 0.0], [0.0, -0.018, 0.0, 3.0], [0.0, 0.006, 0.0, 5.0], [0.0, -0.08, -1.571], [0.0, -0.034, -1.571, 2.0]]]],
			["aim", "thigh.R", "shin.R", [-0.12, -1.0, [[0.04, 0.16, 3.14], [0.0, -0.018, 9.42, 3.0], [0.0, 0.006, 15.7, 5.0]]]],
			["aim", "shin.R", "foot.R", [-0.084, -1.0, [[-0.2, 0.16, 3.14], [0.0, -0.018, 9.42, 3.0], [0.0, 0.006, 15.7, 5.0], [0.0, -0.08, 1.569], [0.0, -0.034, 4.709, 2.0]]]],
			["turn", "spine", "x", [0.3, 0.02, 0.0, 2.0]],
			["turn", "spine", "z", -0.16],
			["turn", "chest", "x", 0.3],
			["turn", "chest", "y", [0.12, 0.06, 0.6]],
			["turn", "neck", "x", 0.62],
			["turn", "head", "z", [0.35, 0.05, 1.2]],
			["aim", "upper_arm.L", "forearm.L", [0.12, -1.0, [0.0, 0.06, 1.0]]],
			["aim", "forearm.L", "hand.L", [0.04, -1.0, [0.05, 0.05, 1.6]]],
			["aim", "upper_arm.R", "forearm.R", [0.02, -1.0, [0.25, 0.06, 4.1]]],
			["aim", "forearm.R", "hand.R", [0.12, -1.0, [0.3, 0.06, 4.7]]],
		],
		"sink": [0.07, 0.012, 0.4, 2.0],
	},
	# A lurch: the right leg stiff (its knee hardly folds) and swung round from
	# a hip hitched up, the body heaving over the left leg each time, both arms
	# half raised in front.
	"own_walk_e": {
		"steps": [
			["turn", "hips", "z", [0.0, -0.1, 1.571]],
			["aim", "thigh.L", "shin.L", [0.06, -1.0, [[0.04, 0.26, 0.0], [0.0, -0.029, 0.0, 3.0], [0.0, 0.01, 0.0, 5.0]]]],
			["aim", "shin.L", "foot.L", [0.042, -1.0, [[-0.2, 0.26, 0.0], [0.0, -0.029, 0.0, 3.0], [0.0, 0.01, 0.0, 5.0], [0.0, -0.2, -1.571], [0.0, -0.085, -1.571, 2.0]]]],
			["aim", "thigh.R", "shin.R", [-0.1, -1.0, [[0.0, 0.26, 3.14], [0.0, -0.029, 9.42, 3.0], [0.0, 0.01, 15.7, 5.0]]]],
			["aim", "shin.R", "foot.R", [-0.07, -1.0, [[-0.04, 0.26, 3.14], [0.0, -0.029, 9.42, 3.0], [0.0, 0.01, 15.7, 5.0], [0.0, -0.03, 1.569]]]],
			["turn", "foot.R", "y", -0.3],
			["turn", "spine", "x", 0.35],
			["turn", "spine", "z", [-0.04, -0.12, 1.571]],
			["turn", "chest", "x", 0.2],
			["turn", "chest", "y", [0.0, 0.14, 0.6]],
			["turn", "neck", "x", -0.05],
			["turn", "head", "z", [-0.1, 0.08, 1.0]],
			["aim", "upper_arm.L", "forearm.L", [0.18, [-0.45, 0.06, 0.5, 2.0], 1.0]],
			["aim", "forearm.L", "hand.L", [0.04, [-0.25, 0.05, 1.0, 2.0], 1.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.18, [-0.6, 0.06, 0.5, 2.0], 0.9]],
			["aim", "forearm.R", "hand.R", [-0.06, [-0.5, 0.05, 1.0, 2.0], 1.0]],
		],
		"sink": [[0.06, 0.03, 0.4, 2.0], [0.0, 0.02, 1.571]],
	},
	# Going down on its knees over a body to eat (decision 423): the knees bend, drop to the
	# ground, and it bends over with both hands on the body (played once, then own_eat).
	"own_eat_start": {
		"steps": [
			["aim", "thigh.L", "shin.L", [["keys", [[0.0, 0.08], [0.4, 0.12], [0.7, 0.14], [1.0, 0.14]]], ["keys", [[0.0, -1.0], [0.4, -0.8], [0.7, -1.0], [1.0, -1.0]]], ["keys", [[0.0, 0.03], [0.4, 0.8], [0.7, 0.3], [1.0, 0.3]]]]],
			["aim", "shin.L", "foot.L", [["keys", [[0.0, 0.04], [0.4, 0.06], [0.7, 0.06], [1.0, 0.06]]], ["keys", [[0.0, -1.0], [0.4, -1.0], [0.7, -0.15], [1.0, -0.15]]], ["keys", [[0.0, -0.08], [0.4, -0.6], [0.7, -1.0], [1.0, -1.0]]]]],
			["aim", "thigh.R", "shin.R", [["keys", [[0.0, -0.1], [0.4, -0.12], [0.7, -0.14], [1.0, -0.14]]], ["keys", [[0.0, -1.0], [0.4, -0.8], [0.7, -1.0], [1.0, -1.0]]], ["keys", [[0.0, 0.0], [0.4, 0.8], [0.7, 0.3], [1.0, 0.3]]]]],
			["aim", "shin.R", "foot.R", [["keys", [[0.0, -0.08], [0.4, -0.06], [0.7, -0.06], [1.0, -0.06]]], ["keys", [[0.0, -1.0], [0.4, -1.0], [0.7, -0.15], [1.0, -0.15]]], ["keys", [[0.0, -0.05], [0.4, -0.6], [0.7, -1.0], [1.0, -1.0]]]]],
			["turn", "foot.L", "x", ["keys", [[0.0, 0.0], [0.55, 0.0], [0.75, 0.9], [1.0, 0.9]]]],
			["turn", "foot.R", "x", ["keys", [[0.0, 0.0], [0.55, 0.0], [0.75, 0.9], [1.0, 0.9]]]],
			["turn", "spine", "x", ["keys", [[0.0, 0.2], [0.4, 0.45], [0.7, 0.6], [1.0, 0.85]]]],
			["turn", "chest", "x", ["keys", [[0.0, 0.27], [1.0, 0.35]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.35], [0.7, 0.2], [1.0, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.16], [0.4, 0.2], [0.8, 0.15], [1.0, 0.15]]], ["keys", [[0.0, -1.0], [0.4, -0.8], [0.8, -0.5], [1.0, -0.5]]], ["keys", [[0.0, 0.06], [0.4, 0.5], [0.8, 0.85], [1.0, 0.85]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0.0, 0.06], [0.4, 0.0], [0.8, -0.05], [1.0, -0.05]]], -1.0, ["keys", [[0.0, 0.16], [0.4, 0.4], [0.8, 0.25], [1.0, 0.25]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.12], [0.4, -0.2], [0.8, -0.15], [1.0, -0.15]]], ["keys", [[0.0, -1.0], [0.4, -0.8], [0.8, -0.5], [1.0, -0.5]]], ["keys", [[0.0, 0.14], [0.4, 0.5], [0.8, 0.85], [1.0, 0.85]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0.0, -0.02], [0.4, 0.0], [0.8, 0.05], [1.0, 0.05]]], ["keys", [[0.0, -0.8], [0.4, -1.0], [0.8, -1.0], [1.0, -1.0]]], ["keys", [[0.0, 0.5], [0.4, 0.4], [0.8, 0.25], [1.0, 0.25]]]]],
		],
		"sink": ["keys", [[0.0, 0.03], [0.4, 0.3], [0.7, 0.52], [1.0, 0.52]]],
	},
	# Eating a body on its knees (decision 423, a loop): the head goes down to it, the teeth meet
	# at the middle of the loop (0.5), then it jerks back tearing, the head twisting, the hands pulling.
	"own_eat": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.14, -1.0, 0.3]],
			["aim", "shin.L", "foot.L", [0.06, -0.15, -1.0]],
			["aim", "thigh.R", "shin.R", [-0.14, -1.0, 0.3]],
			["aim", "shin.R", "foot.R", [-0.06, -0.15, -1.0]],
			["turn", "foot.L", "x", 0.9],
			["turn", "foot.R", "x", 0.9],
			["turn", "spine", "x", ["keys", [[0.0, 0.85], [0.35, 0.95], [0.5, 1.0], [0.65, 0.8], [0.8, 0.75], [1.0, 0.85]]]],
			["turn", "chest", "x", ["keys", [[0.0, 0.35], [0.5, 0.45], [0.7, 0.25], [1.0, 0.35]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.0], [0.35, 0.25], [0.5, 0.35], [0.62, -0.1], [0.75, -0.2], [1.0, 0.0]]]],
			["turn", "head", "y", ["keys", [[0.0, 0.0], [0.55, 0.0], [0.68, 0.25], [0.8, -0.15], [1.0, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [0.15, ["keys", [[0.0, -0.5], [0.5, -0.5], [0.7, -0.65], [1.0, -0.5]]], ["keys", [[0.0, 0.85], [0.5, 0.85], [0.7, 0.65], [1.0, 0.85]]]]],
			["aim", "forearm.L", "hand.L", [-0.05, -1.0, ["keys", [[0.0, 0.25], [0.5, 0.25], [0.7, -0.05], [1.0, 0.25]]]]],
			["aim", "upper_arm.R", "forearm.R", [-0.15, ["keys", [[0.0, -0.5], [0.5, -0.5], [0.7, -0.65], [1.0, -0.5]]], ["keys", [[0.0, 0.85], [0.5, 0.85], [0.7, 0.65], [1.0, 0.85]]]]],
			["aim", "forearm.R", "hand.R", [0.05, -1.0, ["keys", [[0.0, 0.25], [0.5, 0.25], [0.7, -0.05], [1.0, 0.25]]]]],
		],
		"sink": 0.52,
	},
	# Getting up from eating (decision 423, played once): the body up first, the right foot
	# planted in front, then up onto both feet as it stands.
	"own_eat_rise": {
		"steps": [
			["aim", "thigh.L", "shin.L", [["keys", [[0.0, 0.14], [0.55, 0.14], [0.85, 0.12], [1.0, 0.08]]], ["keys", [[0.0, -1.0], [0.55, -1.0], [0.85, -0.8], [1.0, -1.0]]], ["keys", [[0.0, 0.3], [0.55, 0.3], [0.85, 0.8], [1.0, 0.03]]]]],
			["aim", "shin.L", "foot.L", [["keys", [[0.0, 0.06], [0.55, 0.06], [0.85, 0.06], [1.0, 0.04]]], ["keys", [[0.0, -0.15], [0.55, -0.15], [0.85, -1.0], [1.0, -1.0]]], ["keys", [[0.0, -1.0], [0.55, -1.0], [0.85, -0.6], [1.0, -0.08]]]]],
			["aim", "thigh.R", "shin.R", [["keys", [[0.0, -0.14], [0.3, -0.14], [0.55, -0.12], [0.85, -0.12], [1.0, -0.1]]], ["keys", [[0.0, -1.0], [0.3, -1.0], [0.55, -0.25], [0.85, -0.8], [1.0, -1.0]]], ["keys", [[0.0, 0.3], [0.3, 0.3], [0.55, 1.0], [0.85, 0.8], [1.0, 0.0]]]]],
			["aim", "shin.R", "foot.R", [["keys", [[0.0, -0.06], [0.3, -0.06], [0.55, -0.06], [0.85, -0.06], [1.0, -0.08]]], ["keys", [[0.0, -0.15], [0.3, -0.15], [0.55, -1.0], [0.85, -1.0], [1.0, -1.0]]], ["keys", [[0.0, -1.0], [0.3, -1.0], [0.55, -0.08], [0.85, -0.6], [1.0, -0.05]]]]],
			["turn", "foot.L", "x", ["keys", [[0.0, 0.9], [0.6, 0.9], [0.85, 0.0], [1.0, 0.0]]]],
			["turn", "foot.R", "x", ["keys", [[0.0, 0.9], [0.3, 0.9], [0.5, 0.0], [1.0, 0.0]]]],
			["turn", "spine", "x", ["keys", [[0.0, 0.85], [0.3, 0.45], [0.85, 0.5], [1.0, 0.2]]]],
			["turn", "chest", "x", ["keys", [[0.0, 0.35], [1.0, 0.27]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.0], [0.3, 0.3], [1.0, 0.35]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.15], [0.3, 0.2], [0.85, 0.2], [1.0, 0.16]]], ["keys", [[0.0, -0.5], [0.3, -0.8], [0.85, -0.8], [1.0, -1.0]]], ["keys", [[0.0, 0.85], [0.3, 0.5], [0.85, 0.5], [1.0, 0.06]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0.0, -0.05], [0.3, 0.0], [0.85, 0.0], [1.0, 0.06]]], -1.0, ["keys", [[0.0, 0.25], [0.3, 0.4], [0.85, 0.4], [1.0, 0.16]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.15], [0.3, -0.2], [0.85, -0.2], [1.0, -0.12]]], ["keys", [[0.0, -0.5], [0.3, -0.8], [0.85, -0.8], [1.0, -1.0]]], ["keys", [[0.0, 0.85], [0.3, 0.5], [0.85, 0.5], [1.0, 0.14]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0.0, 0.05], [0.3, 0.0], [0.85, 0.0], [1.0, -0.02]]], ["keys", [[0.0, -1.0], [0.3, -1.0], [0.85, -1.0], [1.0, -0.8]]], ["keys", [[0.0, 0.25], [0.3, 0.4], [0.85, 0.4], [1.0, 0.5]]]]],
		],
		"sink": ["keys", [[0.0, 0.52], [0.3, 0.52], [0.55, 0.38], [0.85, 0.2], [1.0, 0.03]]],
	},
	# Biting the one it holds (decision 422, played once from the lunge's reach,
	# own_lunge at 0, and back to it): the arms draw them in, the head goes back,
	# then down into them at the middle (the teeth in, dead_body.gd BITE_LANDS),
	# shakes side to side tearing, and jerks back up as the arms let go.
	"own_bite": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.06, -1.0, ["keys", [[0.0, 0.04], [0.3, 0.16], [0.5, 0.2], [0.8, 0.14], [1.0, 0.04]]]]],
			["aim", "shin.L", "foot.L", [0.03, -1.0, ["keys", [[0.0, -0.543], [0.3, -0.25], [0.5, -0.18], [0.8, -0.28], [1.0, -0.543]]]]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, ["keys", [[0.0, 0.0], [0.5, -0.12], [0.8, -0.08], [1.0, 0.0]]]]],
			["aim", "shin.R", "foot.R", [-0.08, -1.0, ["keys", [[0.0, -0.06], [0.5, -0.3], [0.8, -0.2], [1.0, -0.06]]]]],
			["turn", "spine", "x", ["keys", [[0.0, 0.3], [0.3, 0.38], [0.5, 0.62], [0.72, 0.55], [0.86, 0.38], [1.0, 0.3]]]],
			["turn", "chest", "x", ["keys", [[0.0, 0.22], [0.3, 0.26], [0.5, 0.34], [0.72, 0.3], [1.0, 0.22]]]],
			["turn", "chest", "y", ["keys", [[0.0, -0.0575], [0.5, 0.08], [0.62, -0.12], [0.74, 0.1], [0.86, 0.0], [1.0, -0.0575]]]],
			["turn", "neck", "x", ["keys", [[0.0, -0.3], [0.3, -0.4], [0.44, 0.1], [0.5, 0.3], [0.72, 0.28], [0.86, -0.1], [1.0, -0.3]]]],
			["turn", "head", "x", ["keys", [[0.0, 0.0], [0.3, -0.18], [0.5, -0.06], [0.72, 0.0], [1.0, 0.0]]]],
			["turn", "head", "z", ["keys", [[0.0, 0.18], [0.4, 0.32], [0.72, 0.3], [1.0, 0.18]]]],
			["turn", "head", "y", ["keys", [[0.0, 0.0], [0.55, 0.0], [0.62, 0.28], [0.7, -0.24], [0.78, 0.18], [0.86, 0.0], [1.0, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.14], [0.3, 0.2], [0.8, 0.2], [1.0, 0.14]]], ["keys", [[0.0, 0.08], [0.3, -0.25], [0.5, -0.3], [0.8, -0.18], [1.0, 0.08]]], 1.0]],
			["aim", "forearm.L", "hand.L", [["keys", [[0.0, -0.05], [0.3, -0.42], [0.8, -0.34], [1.0, -0.05]]], ["keys", [[0.0, 0.18], [0.3, 0.12], [0.8, 0.15], [1.0, 0.18]]], ["keys", [[0.0, 1.0], [0.3, 0.55], [0.65, 0.42], [0.8, 0.6], [1.0, 1.0]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.18], [0.3, -0.2], [0.8, -0.2], [1.0, -0.18]]], ["keys", [[0.0, -0.173], [0.3, -0.25], [0.5, -0.3], [0.8, -0.18], [1.0, -0.173]]], 1.0]],
			["aim", "forearm.R", "hand.R", [["keys", [[0.0, 0.06], [0.3, 0.42], [0.8, 0.34], [1.0, 0.06]]], ["keys", [[0.0, 0.05], [0.3, 0.12], [0.8, 0.15], [1.0, 0.05]]], ["keys", [[0.0, 1.0], [0.3, 0.55], [0.65, 0.42], [0.8, 0.6], [1.0, 1.0]]]]],
		],
		"sink": ["keys", [[0.0, 0.0522], [0.5, 0.1], [0.8, 0.07], [1.0, 0.0522]]],
	},
	# Snapping at the air after it reached and missed (decision 422, played once
	# from the lunge's reach and back to it): it throws itself on, the jaws snap
	# twice at the front of the lunge, the body carries round past it and it
	# stumbles back a step before it gathers itself.
	"own_bite_miss": {
		"steps": [
			["turn", "hips", "y", ["keys", [[0.0, 0.0], [0.35, 0.05], [0.6, 0.16], [0.85, 0.06], [1.0, 0.0]]]],
			["aim", "thigh.L", "shin.L", [0.06, -1.0, ["keys", [[0.0, 0.04], [0.3, 0.3], [0.55, 0.26], [0.8, 0.08], [1.0, 0.04]]]]],
			["aim", "shin.L", "foot.L", [0.03, -1.0, ["keys", [[0.0, -0.543], [0.3, -0.1], [0.55, -0.12], [0.8, -0.4], [1.0, -0.543]]]]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, ["keys", [[0.0, 0.0], [0.35, -0.18], [0.6, -0.1], [0.78, -0.26], [1.0, 0.0]]]]],
			["aim", "shin.R", "foot.R", [-0.08, -1.0, ["keys", [[0.0, -0.06], [0.35, -0.35], [0.6, -0.2], [0.78, -0.45], [1.0, -0.06]]]]],
			["turn", "spine", "x", ["keys", [[0.0, 0.3], [0.3, 0.5], [0.45, 0.52], [0.7, 0.36], [1.0, 0.3]]]],
			["turn", "chest", "x", ["keys", [[0.0, 0.22], [0.3, 0.3], [0.7, 0.24], [1.0, 0.22]]]],
			["turn", "chest", "y", ["keys", [[0.0, -0.0575], [0.35, 0.05], [0.6, 0.22], [0.85, 0.05], [1.0, -0.0575]]]],
			["turn", "neck", "x", ["keys", [[0.0, -0.3], [0.2, -0.4], [0.35, 0.3], [0.42, 0.05], [0.5, 0.28], [0.7, 0.0], [1.0, -0.3]]]],
			["turn", "head", "z", ["keys", [[0.0, 0.18], [0.35, 0.1], [0.6, 0.3], [1.0, 0.18]]]],
			["aim", "upper_arm.L", "forearm.L", [0.14, ["keys", [[0.0, 0.08], [0.3, 0.2], [0.6, 0.0], [1.0, 0.08]]], 1.0]],
			["aim", "forearm.L", "hand.L", [-0.05, ["keys", [[0.0, 0.18], [0.3, 0.28], [0.6, 0.05], [1.0, 0.18]]], 1.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.18, ["keys", [[0.0, -0.173], [0.3, 0.05], [0.6, -0.3], [1.0, -0.173]]], 1.0]],
			["aim", "forearm.R", "hand.R", [0.06, ["keys", [[0.0, 0.05], [0.3, 0.2], [0.6, -0.1], [1.0, 0.05]]], 1.0]],
		],
		"sink": ["keys", [[0.0, 0.0522], [0.35, 0.09], [0.6, 0.07], [0.8, 0.08], [1.0, 0.0522]]],
	},
	# Run: pitched far forward as if about to fall, face up, arms trailing behind and flapping.
	"run": {
		"warp": [0.06, 0.0],
		"steps": [
			["turn", "hips", "z", [0.0, 0.1, 0.0]],
			["turn", "spine", "x", 0.42],
			["turn", "spine", "z", [0.0, 0.08, 0.5]],
			["turn", "chest", "x", 0.3],
			["turn", "chest", "y", [0.0, 0.16, 0.6]],
			["turn", "neck", "x", -0.4],
			["turn", "head", "z", [0.18, 0.12, 1.4]],
			["aim", "upper_arm.L", "forearm.L", [0.3, -0.8, [-0.45, 0.35, 0.9]]],
			["aim", "forearm.L", "hand.L", [0.12, -1.0, [-0.25, 0.4, 1.7]]],
			["aim", "upper_arm.R", "forearm.R", [-0.3, -0.8, [-0.45, 0.35, -2.2]]],
			["aim", "forearm.R", "hand.R", [-0.12, -1.0, [-0.25, 0.4, -1.4]]],
		],
		"sink": 0.06,
	},
	# The half beat before it runs (played once, w runs a quarter turn so sin goes 0..1):
	# it stops, the head comes up, the body dips and the arms draw back.
	"tell": {
		"steps": [
			["turn", "hips", "y", [0.0, 0.22, 0.0, 0.25]],
			["turn", "spine", "x", [0.2, 0.4, 0.0, 0.25]],
			["turn", "chest", "x", [0.27, 0.16, 0.0, 0.25]],
			["turn", "chest", "y", [0.0, -0.3, 0.0, 0.25]],
			["turn", "neck", "x", [0.35, -0.95, 0.0, 0.25]],
			["turn", "head", "z", [0.22, -0.2, 0.0, 0.25]],
			["aim", "upper_arm.L", "forearm.L", [[0.22, 0.5, 0.0, 0.25], -1.0, [0.06, -0.75, 0.0, 0.25]]],
			["aim", "forearm.L", "hand.L", [[0.1, 0.45, 0.0, 0.25], -1.0, [0.16, -0.5, 0.0, 0.25]]],
			["aim", "upper_arm.R", "forearm.R", [[-0.22, -0.5, 0.0, 0.25], -1.0, [0.14, -0.8, 0.0, 0.25]]],
			["aim", "forearm.R", "hand.R", [[-0.1, -0.45, 0.0, 0.25], -1.0, [0.3, -0.6, 0.0, 0.25]]],
		],
		"sink": [0.03, 0.09, 0.0, 0.25],
	},
	# The living. Upright, both legs alike half a round apart, arms swinging
	# against the legs. Left leg forward while sin(w) > 0.
	"p_walk": {
		"steps": [
			["turn", "hips", "z", [0.0, 0.035, 0.0]],
			["turn", "hips", "y", [0.0, -0.09, 0.0]],
			["aim", "thigh.L", "shin.L", [0.07, -1.0, [[0.02, 0.4, 0.0], [0.0, -0.04, 0.0, 3.0], [0.0, 0.015, 0.0, 5.0]]]],
			["aim", "shin.L", "foot.L", [0.05, -1.0, [[-0.26, 0.38, 0.0], [0.0, -0.04, 0.0, 3.0], [0.0, 0.015, 0.0, 5.0], [0.0, -0.3, -1.5708], [0.0, -0.12, -1.5708, 2.0]]]],
			["aim", "thigh.R", "shin.R", [-0.07, -1.0, [[0.02, 0.4, 3.1416], [0.0, -0.04, 9.4248, 3.0], [0.0, 0.015, 15.708, 5.0]]]],
			["aim", "shin.R", "foot.R", [-0.05, -1.0, [[-0.26, 0.38, 3.1416], [0.0, -0.04, 9.4248, 3.0], [0.0, 0.015, 15.708, 5.0], [0.0, -0.3, 1.5708], [0.0, -0.12, 4.7124, 2.0]]]],
			["turn", "spine", "x", [0.05, 0.015, 0.0, 2.0]],
			["turn", "chest", "y", [0.0, 0.12, 0.0]],
			["turn", "neck", "x", 0.04],
			["turn", "head", "y", [0.0, -0.05, 0.0]],
			["aim", "upper_arm.L", "forearm.L", [0.16, -1.0, [0.04, -0.3, 0.0]]],
			["aim", "forearm.L", "hand.L", [0.08, -1.0, [0.3, -0.28, 0.0]]],
			["aim", "upper_arm.R", "forearm.R", [-0.16, -1.0, [0.04, 0.3, 0.0]]],
			["aim", "forearm.R", "hand.R", [-0.08, -1.0, [0.3, 0.28, 0.0]]],
		],
		"sink": [0.025, 0.02, -1.5708, 2.0],
	},
	# Leaning into it. Each leg lands a little bent ahead, gives under the body,
	# pushes off behind and folds up with the heel high on the way forward. The
	# arms swing against the legs from the shoulder, well behind the body and
	# up in front, the elbow bent so the hand goes from the hip to the chest.
	"p_run": {
		"steps": RUN_LEGS + [
			["turn", "chest", "y", [0.0, 0.32, 0.0]],
			["swing", "upper_arm.L", "forearm.L", 0.18, [-0.78, -0.75, 0.0]],
			["swing", "forearm.L", "hand.L", [0.0, 0.15, 0.0], [0.82, -0.9, 0.0]],
			["swing", "upper_arm.R", "forearm.R", -0.18, [-0.78, 0.75, 0.0]],
			["swing", "forearm.R", "hand.R", [0.0, 0.15, 0.0], [0.82, 0.9, 0.0]],
		],
		"sink": RUN_SINK,
	},
	# UAL1 Idle_Loop supplies the planted feet and breathing. Only the arms are
	# layered over it; the old hip drift and leg aims must not undo its feet.
	"p_stand": {
		"steps": [
			["aim", "upper_arm.L", "forearm.L", [0.14, -1.0, [0.02, 0.01, 0.0, 4.0]]],
			["aim", "forearm.L", "hand.L", [0.08, -1.0, 0.1]],
			["aim", "upper_arm.R", "forearm.R", [-0.14, -1.0, [0.02, 0.01, 0.0, 4.0]]],
			["aim", "forearm.R", "hand.R", [-0.08, -1.0, 0.1]],
		],
	},
	# Held by a dead one: both arms out at its shoulders, leaning back from it,
	# twisting side to side to get loose, feet braced apart.
	"p_held": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.18, -1.0, [0.1, 0.06, 0.0]]],
			["aim", "shin.L", "foot.L", [0.12, -1.0, -0.15]],
			["aim", "thigh.R", "shin.R", [-0.18, -1.0, [-0.2, 0.06, 3.1416]]],
			["aim", "shin.R", "foot.R", [-0.12, -1.0, -0.3]],
			["turn", "spine", "x", -0.2],
			["turn", "chest", "y", [0.0, 0.25, 0.0]],
			["turn", "spine", "z", [0.0, 0.06, 0.0]],
			["turn", "neck", "x", [-0.1, 0.08, 0.0, 2.0]],
			["turn", "head", "y", [0.0, -0.3, 0.0]],
			["aim", "upper_arm.L", "forearm.L", [0.2, -0.15, 1.0]],
			["aim", "forearm.L", "hand.L", [[0.0, 0.1, 0.0], 0.0, 1.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.2, -0.15, 1.0]],
			["aim", "forearm.R", "hand.R", [[0.0, 0.1, 0.0], 0.0, 1.0]],
		],
		"sink": [0.06, 0.02, 0.0, 2.0],
	},
	# Bitten on the right: shoulders up, body jerks over to the bitten side and
	# the head goes back, then it braces.
	"p_bitten": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, 0.0]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.02]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, 0.0]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, -0.02]],
			["turn", "spine", "z", ["keys", [[0, 0], [0.25, 0.35], [1, 0.08]]]],
			["turn", "spine", "x", ["keys", [[0, 0.05], [0.25, 0.25], [1, 0.12]]]],
			["turn", "chest", "y", ["keys", [[0, 0], [0.25, -0.2], [1, -0.05]]]],
			["turn", "neck", "x", ["keys", [[0, 0.0], [0.25, -0.5], [1, -0.05]]]],
			["turn", "head", "z", ["keys", [[0, 0.0], [0.25, -0.25], [1, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [0.3, ["keys", [[0, -1.0], [0.25, -0.55], [1, -0.8]]], 0.25]],
			["aim", "forearm.L", "hand.L", [-0.1, ["keys", [[0, -0.6], [0.25, 0.1], [1, -0.2]]], 1.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.35, ["keys", [[0, -1.0], [0.25, -0.55], [1, -0.8]]], 0.15]],
			["aim", "forearm.R", "hand.R", [0.4, ["keys", [[0, -0.6], [0.25, 0.6], [1, 0.2]]], 0.6]],
		],
		"sink": ["keys", [[0, 0.0], [0.25, 0.08], [1, 0.04]]],
	},
	# One-handed swing (crowbar, pipe): the right hand back past the shoulder
	# with the body twisted right, across in front to the left, back again.
	"p_swing_one": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, ["keys", [[0, 0.0], [0.45, -0.15], [1, 0.0]]]]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.05]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, ["keys", [[0, 0.0], [0.3, 0.0], [0.45, 0.3], [1, 0.0]]]]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, ["keys", [[0, -0.02], [0.45, 0.05], [1, -0.02]]]]],
			["turn", "spine", "x", ["keys", [[0, 0.05], [0.3, 0.0], [0.45, 0.25], [1, 0.05]]]],
			["turn", "chest", "y", ["keys", [[0, 0.0], [0.3, -0.6], [0.45, 0.5], [1, 0.0]]]],
			["turn", "head", "y", ["keys", [[0, 0.0], [0.3, 0.3], [0.45, -0.25], [1, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [0.25, -0.8, 0.4]],
			["aim", "forearm.L", "hand.L", [-0.1, -0.2, 1.0]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0, -0.16], [0.3, -0.7], [0.45, 0.35], [1, -0.16]]], ["keys", [[0, -1.0], [0.3, 0.35], [0.45, -0.1], [1, -1.0]]], ["keys", [[0, 0.04], [0.3, -0.5], [0.45, 0.9], [1, 0.04]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0, -0.08], [0.3, -0.3], [0.45, 0.7], [1, -0.08]]], ["keys", [[0, -1.0], [0.3, 0.9], [0.45, 0.0], [1, -1.0]]], ["keys", [[0, 0.1], [0.3, -0.3], [0.45, 0.7], [1, 0.1]]]]],
		],
		"sink": ["keys", [[0, 0.0], [0.45, 0.06], [1, 0.0]]],
	},
	# The one-handed swing back the other way (backhand): the right hand drawn
	# across to the left shoulder with the body twisted left, out across in
	# front to the right, back again.
	"p_swing_back": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, ["keys", [[0, 0.0], [0.45, -0.15], [1, 0.0]]]]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.05]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, ["keys", [[0, 0.0], [0.3, 0.0], [0.45, 0.3], [1, 0.0]]]]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, ["keys", [[0, -0.02], [0.45, 0.05], [1, -0.02]]]]],
			["turn", "spine", "x", ["keys", [[0, 0.05], [0.3, 0.0], [0.45, 0.25], [1, 0.05]]]],
			["turn", "chest", "y", ["keys", [[0, 0.0], [0.3, 0.55], [0.45, -0.5], [1, 0.0]]]],
			["turn", "head", "y", ["keys", [[0, 0.0], [0.3, -0.25], [0.45, 0.2], [1, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [0.35, -0.85, 0.25]],
			["aim", "forearm.L", "hand.L", [-0.1, -0.2, 1.0]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0, -0.16], [0.3, 0.8], [0.45, -0.6], [1, -0.16]]], ["keys", [[0, -1.0], [0.3, 0.1], [0.45, -0.05], [1, -1.0]]], ["keys", [[0, 0.04], [0.3, 0.3], [0.45, 0.8], [1, 0.04]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0, -0.08], [0.3, 0.45], [0.45, -0.75], [1, -0.08]]], ["keys", [[0, -1.0], [0.3, 0.6], [0.45, 0.0], [1, -1.0]]], ["keys", [[0, 0.1], [0.3, -0.45], [0.45, 0.65], [1, 0.1]]]]],
		],
		"sink": ["keys", [[0, 0.0], [0.45, 0.06], [1, 0.0]]],
	},
	# Two-handed axe: both hands up over and behind the head, chopped down in
	# front with the knees giving, lifted back.
	"p_swing_axe": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.1, -1.0, ["keys", [[0, 0.0], [0.33, 0.0], [0.45, 0.25], [1, 0.0]]]]],
			["aim", "shin.L", "foot.L", [0.08, -1.0, ["keys", [[0, -0.02], [0.33, -0.02], [0.45, -0.25], [1, -0.02]]]]],
			["aim", "thigh.R", "shin.R", [-0.1, -1.0, ["keys", [[0, 0.0], [0.33, 0.0], [0.45, 0.25], [1, 0.0]]]]],
			["aim", "shin.R", "foot.R", [-0.08, -1.0, ["keys", [[0, -0.02], [0.33, -0.02], [0.45, -0.25], [1, -0.02]]]]],
			["turn", "spine", "x", ["keys", [[0, 0.05], [0.33, -0.2], [0.45, 0.45], [1, 0.05]]]],
			["turn", "neck", "x", ["keys", [[0, 0.0], [0.33, -0.2], [0.45, 0.15], [1, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [0.05, ["keys", [[0, -1.0], [0.33, 1.0], [0.45, -0.25], [1, -1.0]]], ["keys", [[0, 0.05], [0.33, -0.3], [0.45, 1.0], [1, 0.05]]]]],
			["aim", "forearm.L", "hand.L", [-0.15, ["keys", [[0, -1.0], [0.33, 0.7], [0.45, -0.7], [1, -1.0]]], ["keys", [[0, 0.1], [0.33, -0.8], [0.45, 0.7], [1, 0.1]]]]],
			["aim", "upper_arm.R", "forearm.R", [-0.05, ["keys", [[0, -1.0], [0.33, 1.0], [0.45, -0.25], [1, -1.0]]], ["keys", [[0, 0.05], [0.33, -0.3], [0.45, 1.0], [1, 0.05]]]]],
			["aim", "forearm.R", "hand.R", [0.15, ["keys", [[0, -1.0], [0.33, 0.7], [0.45, -0.7], [1, -1.0]]], ["keys", [[0, 0.1], [0.33, -0.8], [0.45, 0.7], [1, 0.1]]]]],
		],
		"sink": ["keys", [[0, 0.0], [0.33, 0.0], [0.45, 0.12], [1, 0.0]]],
	},
	# Knife: the right hand drawn back to the hip, thrust straight out with the
	# body behind it, the left hand up in front.
	"p_stab": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, -0.05]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.1]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, ["keys", [[0, 0.0], [0.22, 0.0], [0.35, 0.25], [1, 0.0]]]]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, 0.0]],
			["turn", "spine", "x", ["keys", [[0, 0.05], [0.22, 0.0], [0.35, 0.25], [1, 0.05]]]],
			["turn", "chest", "y", ["keys", [[0, 0.0], [0.22, -0.3], [0.35, 0.2], [1, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [0.2, -0.7, 0.6]],
			["aim", "forearm.L", "hand.L", [-0.3, 0.3, 1.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.3, ["keys", [[0, -1.0], [0.22, -0.7], [0.35, -0.15], [1, -1.0]]], ["keys", [[0, 0.04], [0.22, -0.6], [0.35, 1.0], [1, 0.04]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0, -0.08], [0.22, 0.05], [0.35, 0.1], [1, -0.08]]], ["keys", [[0, -1.0], [0.22, -0.1], [0.35, 0.0], [1, -1.0]]], ["keys", [[0, 0.1], [0.22, 1.0], [0.35, 1.0], [1, 0.1]]]]],
		],
		"sink": ["keys", [[0, 0.0], [0.35, 0.05], [1, 0.0]]],
	},
	# Shove: hands drawn to the chest leaning back, then both arms straight out
	# with a step and the body thrown forward, back again.
	"p_shove": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, -0.05]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.08]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, ["keys", [[0, 0.0], [0.3, 0.0], [0.4, 0.35], [1, 0.0]]]]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, ["keys", [[0, -0.02], [0.4, 0.1], [1, -0.02]]]]],
			["turn", "spine", "x", ["keys", [[0, 0.05], [0.3, -0.2], [0.4, 0.35], [1, 0.05]]]],
			["aim", "upper_arm.L", "forearm.L", [0.25, ["keys", [[0, -1.0], [0.3, -0.35], [0.4, 0.05], [1, -1.0]]], ["keys", [[0, 0.04], [0.3, -0.25], [0.4, 1.0], [1, 0.04]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0, 0.08], [0.3, -0.8], [0.4, 0.0], [1, 0.08]]], ["keys", [[0, -1.0], [0.3, 0.45], [0.4, 0.05], [1, -1.0]]], ["keys", [[0, 0.1], [0.3, 0.3], [0.4, 1.0], [1, 0.1]]]]],
			["aim", "upper_arm.R", "forearm.R", [-0.25, ["keys", [[0, -1.0], [0.3, -0.35], [0.4, 0.05], [1, -1.0]]], ["keys", [[0, 0.04], [0.3, -0.25], [0.4, 1.0], [1, 0.04]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0, -0.08], [0.3, 0.8], [0.4, 0.0], [1, -0.08]]], ["keys", [[0, -1.0], [0.3, 0.45], [0.4, 0.05], [1, -1.0]]], ["keys", [[0, 0.1], [0.3, 0.3], [0.4, 1.0], [1, 0.1]]]]],
		],
		"sink": ["keys", [[0, 0.0], [0.4, 0.05], [1, 0.0]]],
	},
	# Creeping (decision 448, 4): half crouched rather than squatting, the arms
	# bent along the sides with the hands before the hips, swinging a little.
	"p_crouch_walk": {
		"steps": CROUCH_LEGS + [
			["swing", "upper_arm.L", "forearm.L", 0.22, [-0.42, -0.1, 0.0]],
			["swing", "forearm.L", "hand.L", -0.05, [0.5, -0.1, 0.0]],
			["swing", "upper_arm.R", "forearm.R", -0.22, [-0.42, 0.1, 0.0]],
			["swing", "forearm.R", "hand.R", 0.05, [0.5, 0.1, 0.0]],
		],
		"sink": CROUCH_SINK,
	},
	# The same crouch kept still.
	"p_crouch_idle": {
		"steps": CROUCH_STILL + [
			["swing", "upper_arm.L", "forearm.L", 0.22, -0.4],
			["swing", "forearm.L", "hand.L", -0.05, 0.5],
			["swing", "upper_arm.R", "forearm.R", -0.22, -0.4],
			["swing", "forearm.R", "hand.R", 0.05, 0.5],
		],
		"sink": CROUCH_STILL_SINK,
	},
	# Creeping with a long weapon held low before the body in both hands, tipped
	# well forward: the right fist by the hip, the left out along it.
	"p_crouch_walk_long": {
		"steps": CROUCH_LEGS + CROUCH_LONG_ARMS,
		"sink": CROUCH_SINK,
	},
	"p_crouch_idle_long": {
		"steps": CROUCH_STILL + CROUCH_LONG_ARMS,
		"sink": CROUCH_STILL_SINK,
	},
	# Creeping with a handgun held low before the body in both hands, the muzzle ahead.
	"p_crouch_walk_pistol": {
		"steps": CROUCH_LEGS + CROUCH_PISTOL_ARMS,
		"sink": CROUCH_SINK,
	},
	"p_crouch_idle_pistol": {
		"steps": CROUCH_STILL + CROUCH_PISTOL_ARMS,
		"sink": CROUCH_STILL_SINK,
	},
	# Searching a drawer or shelf: bent a little at the waist, the two hands
	# turning things over in front of the chest by turns, head down.
	"p_search_mid": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.09, -1.0, 0.02]],
			["aim", "shin.L", "foot.L", [0.07, -1.0, -0.03]],
			["aim", "thigh.R", "shin.R", [-0.09, -1.0, 0.02]],
			["aim", "shin.R", "foot.R", [-0.07, -1.0, -0.03]],
			["turn", "spine", "x", 0.3],
			["turn", "chest", "y", [0.0, 0.08, 0.0]],
			["turn", "neck", "x", 0.35],
			["turn", "head", "y", [0.0, 0.12, 1.0]],
			["aim", "upper_arm.L", "forearm.L", [0.15, -0.7, [0.55, 0.12, 0.0]]],
			["aim", "forearm.L", "hand.L", [-0.15, [0.1, 0.3, 0.0, 2.0], 1.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.15, -0.7, [0.55, 0.12, 3.1416]]],
			["aim", "forearm.R", "hand.R", [0.15, [0.1, 0.3, 3.1416, 2.0], 1.0]],
		],
		"sink": 0.02,
	},
	# Down on the right knee, reaching to the ground in front with both hands by turns.
	"p_search_low": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.12, -0.25, 1.0]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.08]],
			["aim", "thigh.R", "shin.R", [-0.12, -1.0, 0.1]],
			["aim", "shin.R", "foot.R", [-0.06, -0.12, -1.0]],
			["turn", "foot.R", "x", 0.9],
			["turn", "spine", "x", 0.55],
			["turn", "chest", "x", 0.15],
			["turn", "neck", "x", 0.25],
			["aim", "upper_arm.L", "forearm.L", [0.15, -1.0, [0.55, 0.15, 0.0]]],
			["aim", "forearm.L", "hand.L", [0.0, -1.0, [0.6, 0.25, 0.0]]],
			["aim", "upper_arm.R", "forearm.R", [-0.15, -1.0, [0.55, 0.15, 3.1416]]],
			["aim", "forearm.R", "hand.R", [0.0, -1.0, [0.6, 0.25, 3.1416]]],
		],
		"sink": 0.36,
	},
	# On one knee binding the left forearm: the right hand goes round and round it.
	"p_treat": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.12, -0.25, 1.0]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.08]],
			["aim", "thigh.R", "shin.R", [-0.12, -1.0, 0.1]],
			["aim", "shin.R", "foot.R", [-0.06, -0.12, -1.0]],
			["turn", "foot.R", "x", 0.9],
			["turn", "spine", "x", 0.35],
			["turn", "neck", "x", 0.4],
			["aim", "upper_arm.L", "forearm.L", [0.2, -0.8, 0.45]],
			["aim", "forearm.L", "hand.L", [-0.7, 0.05, 0.7]],
			["aim", "upper_arm.R", "forearm.R", [-0.2, -0.75, [0.5, 0.08, 0.0]]],
			["aim", "forearm.R", "hand.R", [[0.55, 0.25, 0.0], [0.1, 0.35, 1.5708], 0.7]],
		],
		"sink": 0.36,
	},
	# Pistol held out at eye height in the right hand, the left under it, half side on.
	"p_aim_one": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.14, -1.0, 0.12]],
			["aim", "shin.L", "foot.L", [0.1, -1.0, 0.0]],
			["aim", "thigh.R", "shin.R", [-0.14, -1.0, -0.12]],
			["aim", "shin.R", "foot.R", [-0.1, -1.0, -0.1]],
			["turn", "hips", "y", 0.25],
			["turn", "chest", "y", [-0.3, 0.015, 0.0]],
			["turn", "neck", "x", -0.05],
			["turn", "head", "y", -0.2],
			["aim", "upper_arm.R", "forearm.R", [0.02, [0.12, 0.01, 0.0], 1.0]],
			["aim", "forearm.R", "hand.R", [0.04, [0.08, 0.01, 0.0], 1.0]],
			["aim", "upper_arm.L", "forearm.L", [-0.3, -0.05, 0.9]],
			["aim", "forearm.L", "hand.L", [-0.6, 0.05, 0.75]],
		],
		"sink": [0.04, 0.003, 0.0],
	},
	# A long gun at the shoulder: the right hand at the cheek, the left out under
	# the barrel, head down along it.
	"p_aim_two": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.14, -1.0, 0.15]],
			["aim", "shin.L", "foot.L", [0.1, -1.0, 0.0]],
			["aim", "thigh.R", "shin.R", [-0.14, -1.0, -0.12]],
			["aim", "shin.R", "foot.R", [-0.1, -1.0, -0.1]],
			["turn", "hips", "y", 0.35],
			["turn", "spine", "x", 0.08],
			["turn", "chest", "y", [-0.4, 0.015, 0.0]],
			["turn", "neck", "x", 0.2],
			["turn", "head", "z", -0.15],
			["aim", "upper_arm.R", "forearm.R", [-0.65, -0.25, 0.25]],
			["aim", "forearm.R", "hand.R", [0.55, 0.35, 0.75]],
			["aim", "upper_arm.L", "forearm.L", [-0.05, [-0.15, 0.01, 0.0], 1.0]],
			["aim", "forearm.L", "hand.L", [-0.25, [0.05, 0.01, 0.0], 1.0]],
		],
		"sink": [0.05, 0.003, 0.0],
	},
	# Striking down at something on the ground: both hands raised over the head,
	# bent right over with the knees giving as the blow lands in front of the feet.
	"p_floor_strike": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.12, -1.0, ["keys", [[0, 0.05], [0.35, 0.05], [0.5, 0.55], [1, 0.05]]]]],
			["aim", "shin.L", "foot.L", [0.08, -1.0, ["keys", [[0, -0.05], [0.35, -0.05], [0.5, -0.45], [1, -0.05]]]]],
			["aim", "thigh.R", "shin.R", [-0.12, -1.0, ["keys", [[0, -0.1], [0.35, -0.1], [0.5, 0.35], [1, -0.1]]]]],
			["aim", "shin.R", "foot.R", [-0.08, -1.0, ["keys", [[0, -0.1], [0.35, -0.1], [0.5, -0.4], [1, -0.1]]]]],
			["turn", "spine", "x", ["keys", [[0, 0.1], [0.35, -0.15], [0.5, 0.8], [1, 0.1]]]],
			["turn", "chest", "x", ["keys", [[0, 0.0], [0.5, 0.25], [1, 0.0]]]],
			["turn", "neck", "x", ["keys", [[0, 0.2], [0.35, 0.0], [0.5, 0.35], [1, 0.2]]]],
			["aim", "upper_arm.L", "forearm.L", [0.05, ["keys", [[0, -0.7], [0.35, 1.0], [0.5, -0.6], [1, -0.7]]], ["keys", [[0, 0.4], [0.35, -0.25], [0.5, 0.8], [1, 0.4]]]]],
			["aim", "forearm.L", "hand.L", [-0.12, ["keys", [[0, -0.5], [0.35, 0.8], [0.5, -0.9], [1, -0.5]]], ["keys", [[0, 0.6], [0.35, -0.6], [0.5, 0.45], [1, 0.6]]]]],
			["aim", "upper_arm.R", "forearm.R", [-0.05, ["keys", [[0, -0.7], [0.35, 1.0], [0.5, -0.6], [1, -0.7]]], ["keys", [[0, 0.4], [0.35, -0.25], [0.5, 0.8], [1, 0.4]]]]],
			["aim", "forearm.R", "hand.R", [0.12, ["keys", [[0, -0.5], [0.35, 0.8], [0.5, -0.9], [1, -0.5]]], ["keys", [[0, 0.6], [0.35, -0.6], [0.5, 0.45], [1, 0.6]]]]],
		],
		"sink": ["keys", [[0, 0.03], [0.35, 0.0], [0.5, 0.2], [1, 0.03]]],
	},
	# Stamping down: the right knee drawn high, the foot driven into the ground
	# in front, looking down at it, the arms out a little for balance.
	"p_stomp": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.1, -1.0, -0.05]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.1]],
			["aim", "thigh.R", "shin.R", [-0.1, ["keys", [[0, -1.0], [0.35, -0.35], [0.5, -0.85], [1, -1.0]]], ["keys", [[0, 0.0], [0.35, 1.0], [0.5, 0.45], [1, 0.0]]]]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, ["keys", [[0, -0.02], [0.35, -0.3], [0.5, 0.1], [1, -0.02]]]]],
			["turn", "spine", "x", ["keys", [[0, 0.05], [0.35, 0.3], [0.5, 0.4], [1, 0.05]]]],
			["turn", "neck", "x", ["keys", [[0, 0.1], [0.35, 0.45], [0.5, 0.5], [1, 0.1]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0, 0.16], [0.35, 0.5], [1, 0.16]]], -1.0, 0.1]],
			["aim", "forearm.L", "hand.L", [0.1, -0.8, 0.3]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0, -0.16], [0.35, -0.5], [1, -0.16]]], -1.0, 0.1]],
			["aim", "forearm.R", "hand.R", [-0.1, -0.8, 0.3]],
		],
		"sink": ["keys", [[0, 0.0], [0.35, -0.03], [0.5, 0.06], [1, 0.0]]],
	},
	# Prying a door or lid: both hands on a bar in front at the chest, the body
	# thrown back against it and coming forward to set it again.
	"p_pry": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.12, -1.0, 0.25]],
			["aim", "shin.L", "foot.L", [0.08, -1.0, -0.1]],
			["aim", "thigh.R", "shin.R", [-0.12, -1.0, [-0.15, 0.08, 0.0]]],
			["aim", "shin.R", "foot.R", [-0.08, -1.0, -0.15]],
			["turn", "spine", "x", [0.05, 0.25, 0.0]],
			["turn", "chest", "y", [0.0, 0.08, 0.5]],
			["turn", "neck", "x", [0.15, -0.1, 0.0]],
			["aim", "upper_arm.L", "forearm.L", [0.15, [-0.45, 0.15, 0.0], 0.75]],
			["aim", "forearm.L", "hand.L", [-0.35, [0.05, 0.1, 0.0], 0.8]],
			["aim", "upper_arm.R", "forearm.R", [-0.15, [-0.45, 0.15, 0.0], 0.75]],
			["aim", "forearm.R", "hand.R", [0.35, [0.05, 0.1, 0.0], 0.8]],
		],
		"sink": [0.08, 0.04, 0.0],
	},
	# Front kick: the weight back on the left leg, the right swung out straight
	# to below the hip (higher goes through the skirt) and back down, the arms thrown out.
	"p_kick": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.1, -1.0, ["keys", [[0, -0.02], [0.4, -0.15], [1, -0.02]]]]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.08]],
			["aim", "thigh.R", "shin.R", [-0.1, ["keys", [[0, -1.0], [0.25, -0.75], [0.4, -0.55], [1, -1.0]]], ["keys", [[0, 0.0], [0.25, 0.45], [0.4, 0.8], [1, 0.0]]]]],
			["aim", "shin.R", "foot.R", [-0.08, ["keys", [[0, -1.0], [0.25, -1.0], [0.4, -0.45], [1, -1.0]]], ["keys", [[0, -0.02], [0.25, -0.2], [0.4, 0.9], [1, -0.02]]]]],
			["turn", "spine", "x", ["keys", [[0, 0.05], [0.4, -0.3], [1, 0.05]]]],
			["turn", "neck", "x", ["keys", [[0, 0.0], [0.4, 0.3], [1, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0, 0.16], [0.4, 0.7], [1, 0.16]]], ["keys", [[0, -1.0], [0.4, -0.3], [1, -1.0]]], 0.15]],
			["aim", "forearm.L", "hand.L", [0.2, -0.6, 0.4]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0, -0.16], [0.4, -0.7], [1, -0.16]]], ["keys", [[0, -1.0], [0.4, -0.3], [1, -1.0]]], -0.1]],
			["aim", "forearm.R", "hand.R", [-0.2, -0.6, 0.2]],
		],
		"sink": ["keys", [[0, 0.0], [0.4, 0.04], [1, 0.0]]],
	},
	# Searching a high shelf: up on the toes, both arms up in front, the hands
	# turning things over by turns, the head back to see.
	"p_search_high": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, 0.0]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, 0.0]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, 0.0]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, 0.0]],
			["turn", "foot.L", "x", 0.45],
			["turn", "foot.R", "x", 0.45],
			["turn", "spine", "x", -0.04],
			["turn", "chest", "y", [0.0, 0.06, 0.0]],
			["turn", "neck", "x", -0.45],
			["turn", "head", "y", [0.0, 0.12, 1.0]],
			["aim", "upper_arm.L", "forearm.L", [0.12, 0.9, 0.45]],
			["aim", "forearm.L", "hand.L", [-0.05, [0.55, 0.25, 0.0, 2.0], [0.8, 0.15, 0.6, 2.0]]],
			["aim", "upper_arm.R", "forearm.R", [-0.12, 0.9, 0.45]],
			["aim", "forearm.R", "hand.R", [0.05, [0.55, 0.25, 3.142, 2.0], [0.8, 0.15, 3.742, 2.0]]],
		],
		"sink": -0.06,
	},
	# Limping, the left leg hurt (decision 422 M1): its knee hardly folds, the
	# body dips and leans off it each time it takes the weight. Both feet go
	# back alike (the same swing), so neither slides; the bake measures the round.
	"p_limp_light_l": {
		"steps": [
			["turn", "hips", "z", [0.0, 0.035, 0.0]],
			["turn", "hips", "y", [0.0, -0.08, 0.0]],
			["aim", "thigh.L", "shin.L", [0.07, -1.0, [[0.02, 0.36, 0.0], [0.0, -0.036, 0.0, 3.0], [0.0, 0.013, 0.0, 5.0]]]],
			["aim", "shin.L", "foot.L", [0.049, -1.0, [[-0.16, 0.342, 0.0], [0.0, -0.036, 0.0, 3.0], [0.0, 0.013, 0.0, 5.0], [0.0, -0.12, -1.571], [0.0, -0.05, -1.571, 2.0]]]],
			["aim", "thigh.R", "shin.R", [-0.07, -1.0, [[0.02, 0.36, 3.142], [0.0, -0.036, 9.425, 3.0], [0.0, 0.013, 15.708, 5.0]]]],
			["aim", "shin.R", "foot.R", [-0.049, -1.0, [[-0.26, 0.342, 3.142], [0.0, -0.036, 9.425, 3.0], [0.0, 0.013, 15.708, 5.0], [0.0, -0.3, 1.571], [0.0, -0.12, 4.712, 2.0]]]],
			["turn", "spine", "x", [0.08, 0.02, 0.0, 2.0]],
			["turn", "spine", "z", [0.02, 0.07, 1.571]],
			["turn", "chest", "y", [0.0, 0.1, 0.0]],
			["turn", "neck", "x", [0.06, 0.06, 1.571]],
			["turn", "head", "y", [0.0, -0.05, 0.0]],
			["aim", "upper_arm.L", "forearm.L", [0.18, -1.0, [0.04, -0.2, 0.0]]],
			["aim", "forearm.L", "hand.L", [0.08, -1.0, [0.25, -0.2, 0.0]]],
			["aim", "upper_arm.R", "forearm.R", [-0.2, -1.0, [0.04, 0.3, 0.0]]],
			["aim", "forearm.R", "hand.R", [-0.08, -1.0, [0.3, 0.28, 0.0]]],
		],
		"sink": [[0.03, 0.02, -1.571, 2.0], [0.0, 0.03, 1.571]],
	},
	# The same, the right leg hurt.
	"p_limp_light_r": {
		"steps": [
			["turn", "hips", "z", [0.0, -0.035, 0.0]],
			["turn", "hips", "y", [0.0, 0.08, 0.0]],
			["aim", "thigh.R", "shin.R", [-0.07, -1.0, [[0.02, 0.36, 0.0], [0.0, -0.036, 0.0, 3.0], [0.0, 0.013, 0.0, 5.0]]]],
			["aim", "shin.R", "foot.R", [-0.049, -1.0, [[-0.16, 0.342, 0.0], [0.0, -0.036, 0.0, 3.0], [0.0, 0.013, 0.0, 5.0], [0.0, -0.12, -1.571], [0.0, -0.05, -1.571, 2.0]]]],
			["aim", "thigh.L", "shin.L", [0.07, -1.0, [[0.02, 0.36, 3.142], [0.0, -0.036, 9.425, 3.0], [0.0, 0.013, 15.708, 5.0]]]],
			["aim", "shin.L", "foot.L", [0.049, -1.0, [[-0.26, 0.342, 3.142], [0.0, -0.036, 9.425, 3.0], [0.0, 0.013, 15.708, 5.0], [0.0, -0.3, 1.571], [0.0, -0.12, 4.712, 2.0]]]],
			["turn", "spine", "x", [0.08, 0.02, 0.0, 2.0]],
			["turn", "spine", "z", [-0.02, -0.07, 1.571]],
			["turn", "chest", "y", [0.0, -0.1, 0.0]],
			["turn", "neck", "x", [0.06, 0.06, 1.571]],
			["turn", "head", "y", [0.0, 0.05, 0.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.18, -1.0, [0.04, -0.2, 0.0]]],
			["aim", "forearm.R", "hand.R", [-0.08, -1.0, [0.25, -0.2, 0.0]]],
			["aim", "upper_arm.L", "forearm.L", [0.2, -1.0, [0.04, 0.3, 0.0]]],
			["aim", "forearm.L", "hand.L", [0.08, -1.0, [0.3, 0.28, 0.0]]],
		],
		"sink": [[0.03, 0.02, -1.571, 2.0], [0.0, 0.03, 1.571]],
	},
	# Limping hard on a broken or deep-cut left leg: it stays straight, turned
	# out and dragged on its toe, swung round from a hitched hip; the body
	# lurches over the right leg, the left hand pressed on the thigh.
	"p_limp_heavy_l": {
		"steps": [
			["turn", "hips", "z", [0.0, 0.1, -1.571]],
			["turn", "hips", "y", [0.0, -0.06, 0.0]],
			["aim", "thigh.L", "shin.L", [0.08, -1.0, [[0.02, 0.28, 0.0], [0.0, -0.028, 0.0, 3.0], [0.0, 0.01, 0.0, 5.0]]]],
			["aim", "shin.L", "foot.L", [0.056, -1.0, [[-0.01, 0.266, 0.0], [0.0, -0.028, 0.0, 3.0], [0.0, 0.01, 0.0, 5.0], [0.0, -0.02, -1.571]]]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, [[0.02, 0.28, 3.142], [0.0, -0.028, 9.425, 3.0], [0.0, 0.01, 15.708, 5.0]]]],
			["aim", "shin.R", "foot.R", [-0.056, -1.0, [[-0.26, 0.266, 3.142], [0.0, -0.028, 9.425, 3.0], [0.0, 0.01, 15.708, 5.0], [0.0, -0.32, 1.571], [0.0, -0.13, 4.712, 2.0]]]],
			["turn", "foot.L", "y", 0.35],
			["turn", "foot.L", "x", 0.25],
			["turn", "spine", "x", [0.18, 0.04, 0.0, 2.0]],
			["turn", "spine", "z", [0.07, 0.1, 1.571]],
			["turn", "chest", "y", [0.0, 0.12, 0.0]],
			["turn", "neck", "x", [0.15, 0.08, 1.571]],
			["aim", "upper_arm.L", "forearm.L", [0.22, -1.0, 0.28]],
			["aim", "forearm.L", "hand.L", [-0.12, -1.0, 0.4]],
			["aim", "upper_arm.R", "forearm.R", [-0.35, -1.0, [0.05, 0.3, 0.0]]],
			["aim", "forearm.R", "hand.R", [-0.15, -1.0, [0.3, 0.3, 0.0]]],
		],
		"sink": [[0.05, 0.02, -1.571, 2.0], [0.0, 0.05, 1.571]],
	},
	# The same, the right leg hurt.
	"p_limp_heavy_r": {
		"steps": [
			["turn", "hips", "z", [0.0, -0.1, -1.571]],
			["turn", "hips", "y", [0.0, 0.06, 0.0]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, [[0.02, 0.28, 0.0], [0.0, -0.028, 0.0, 3.0], [0.0, 0.01, 0.0, 5.0]]]],
			["aim", "shin.R", "foot.R", [-0.056, -1.0, [[-0.01, 0.266, 0.0], [0.0, -0.028, 0.0, 3.0], [0.0, 0.01, 0.0, 5.0], [0.0, -0.02, -1.571]]]],
			["aim", "thigh.L", "shin.L", [0.08, -1.0, [[0.02, 0.28, 3.142], [0.0, -0.028, 9.425, 3.0], [0.0, 0.01, 15.708, 5.0]]]],
			["aim", "shin.L", "foot.L", [0.056, -1.0, [[-0.26, 0.266, 3.142], [0.0, -0.028, 9.425, 3.0], [0.0, 0.01, 15.708, 5.0], [0.0, -0.32, 1.571], [0.0, -0.13, 4.712, 2.0]]]],
			["turn", "foot.R", "y", -0.35],
			["turn", "foot.R", "x", 0.25],
			["turn", "spine", "x", [0.18, 0.04, 0.0, 2.0]],
			["turn", "spine", "z", [-0.07, -0.1, 1.571]],
			["turn", "chest", "y", [0.0, -0.12, 0.0]],
			["turn", "neck", "x", [0.15, 0.08, 1.571]],
			["aim", "upper_arm.R", "forearm.R", [-0.22, -1.0, 0.28]],
			["aim", "forearm.R", "hand.R", [0.12, -1.0, 0.4]],
			["aim", "upper_arm.L", "forearm.L", [0.35, -1.0, [0.05, 0.3, 0.0]]],
			["aim", "forearm.L", "hand.L", [0.15, -1.0, [0.3, 0.3, 0.0]]],
		],
		"sink": [[0.05, 0.02, -1.571, 2.0], [0.0, 0.05, 1.571]],
	},
	# Binding the left forearm standing: it held across in front, the right
	# hand going round and round it, head down over it.
	"p_treat_arm": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, 0.0]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.02]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, 0.0]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, -0.02]],
			["turn", "spine", "x", 0.15],
			["turn", "chest", "y", -0.1],
			["turn", "neck", "x", 0.45],
			["aim", "upper_arm.L", "forearm.L", [0.2, -0.75, 0.45]],
			["aim", "forearm.L", "hand.L", [-0.7, 0.1, 0.7]],
			["aim", "upper_arm.R", "forearm.R", [-0.2, -0.7, [0.5, 0.08, 0.0]]],
			["aim", "forearm.R", "hand.R", [[0.55, 0.25, 0.0], [0.15, 0.35, 1.571], 0.7]],
		],
		"sink": 0.0,
	},
	# Binding the left shin, down on the right knee: bent over the raised left
	# knee, both hands at the shin, the right one going round it.
	"p_treat_leg": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.12, -0.25, 1.0]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.08]],
			["aim", "thigh.R", "shin.R", [-0.12, -1.0, 0.1]],
			["aim", "shin.R", "foot.R", [-0.06, -0.12, -1.0]],
			["turn", "foot.R", "x", 0.9],
			["turn", "spine", "x", 0.7],
			["turn", "chest", "x", 0.15],
			["turn", "neck", "x", 0.25],
			["aim", "upper_arm.L", "forearm.L", [0.18, -1.0, 0.35]],
			["aim", "forearm.L", "hand.L", [-0.15, -0.8, 0.6]],
			["aim", "upper_arm.R", "forearm.R", [-0.05, -1.0, [0.4, 0.1, 0.0]]],
			["aim", "forearm.R", "hand.R", [[0.5, 0.3, 0.0], [-0.6, 0.3, 1.571], 0.6]],
		],
		"sink": 0.36,
	},
	# Binding the head or the body (both read from here): the left hand holds a
	# pad to the side of the head, the right takes the strip round over the top.
	"p_treat_head": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, 0.0]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.02]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, 0.0]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, -0.02]],
			["turn", "spine", "x", 0.05],
			["turn", "neck", "x", 0.15],
			["turn", "head", "z", -0.12],
			["aim", "upper_arm.L", "forearm.L", [0.5, 0.0, 0.35]],
			["aim", "forearm.L", "hand.L", [-0.4, 0.8, -0.2]],
			["aim", "upper_arm.R", "forearm.R", [-0.5, [0.05, 0.15, 0.0], [0.35, 0.2, 1.571]]],
			["aim", "forearm.R", "hand.R", [[0.45, 0.3, 1.571], 0.75, [-0.25, 0.35, 0.0]]],
		],
		"sink": 0.0,
	},
	# Bitten by one in front: thrown back from it, both forearms up to fend it
	# off, the head turned away, the right foot a step back; then braced.
	"p_bitten_front": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, ["keys", [[0.0, 0.0], [0.25, 0.08], [1.0, 0.036]]]]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.02]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, ["keys", [[0.0, 0.0], [0.25, -0.3], [1.0, -0.135]]]]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, ["keys", [[0.0, -0.02], [0.25, -0.4], [1.0, -0.191]]]]],
			["turn", "spine", "x", ["keys", [[0.0, 0.05], [0.25, -0.3], [1.0, -0.107]]]],
			["turn", "chest", "y", ["keys", [[0.0, 0.0], [0.25, -0.2], [1.0, -0.09]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.0], [0.25, -0.45], [1.0, -0.203]]]],
			["turn", "head", "y", ["keys", [[0.0, 0.0], [0.25, 0.4], [1.0, 0.18]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.14], [0.25, 0.3], [1.0, 0.212]]], ["keys", [[0.0, -1.0], [0.25, -0.2], [1.0, -0.64]]], ["keys", [[0.0, 0.1], [0.25, 0.9], [1.0, 0.46]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0.0, 0.08], [0.25, -0.2], [1.0, -0.046]]], ["keys", [[0.0, -1.0], [0.25, 0.55], [1.0, -0.302]]], ["keys", [[0.0, 0.2], [0.25, 0.8], [1.0, 0.47]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.14], [0.25, -0.3], [1.0, -0.212]]], ["keys", [[0.0, -1.0], [0.25, -0.25], [1.0, -0.662]]], ["keys", [[0.0, 0.1], [0.25, 0.9], [1.0, 0.46]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0.0, -0.08], [0.25, 0.2], [1.0, 0.046]]], ["keys", [[0.0, -1.0], [0.25, 0.5], [1.0, -0.325]]], ["keys", [[0.0, 0.2], [0.25, 0.8], [1.0, 0.47]]]]],
		],
		"sink": ["keys", [[0.0, 0.0], [0.25, 0.06], [1.0, 0.027]]],
	},
	# Bitten from behind, on the shoulder: jerked forward and hunched, the left
	# foot a step forward, the head twisting back to it, the right hand
	# clawing back over the shoulder; then braced.
	"p_bitten_back": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, ["keys", [[0.0, 0.0], [0.25, 0.35], [1.0, 0.158]]]]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, ["keys", [[0.0, -0.02], [0.25, 0.0], [1.0, -0.011]]]]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, ["keys", [[0.0, 0.0], [0.25, -0.08], [1.0, -0.036]]]]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, ["keys", [[0.0, -0.02], [0.25, -0.15], [1.0, -0.079]]]]],
			["turn", "spine", "x", ["keys", [[0.0, 0.05], [0.25, 0.4], [1.0, 0.208]]]],
			["turn", "chest", "y", ["keys", [[0.0, 0.0], [0.25, -0.3], [1.0, -0.135]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.0], [0.25, 0.1], [1.0, 0.045]]]],
			["turn", "head", "y", ["keys", [[0.0, 0.0], [0.25, -0.6], [1.0, -0.27]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.14], [0.25, 0.4], [1.0, 0.257]]], ["keys", [[0.0, -1.0], [0.25, -0.5], [1.0, -0.775]]], ["keys", [[0.0, 0.1], [0.25, 0.6], [1.0, 0.325]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0.0, 0.08], [0.25, 0.2], [1.0, 0.134]]], ["keys", [[0.0, -1.0], [0.25, -0.2], [1.0, -0.64]]], ["keys", [[0.0, 0.2], [0.25, 0.9], [1.0, 0.515]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.14], [0.25, -0.45], [1.0, -0.28]]], ["keys", [[0.0, -1.0], [0.25, 0.55], [1.0, -0.302]]], ["keys", [[0.0, 0.1], [0.25, -0.15], [1.0, -0.012]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0.0, -0.08], [0.25, 0.35], [1.0, 0.114]]], ["keys", [[0.0, -1.0], [0.25, 0.55], [1.0, -0.302]]], ["keys", [[0.0, 0.2], [0.25, -0.6], [1.0, -0.16]]]]],
		],
		"sink": ["keys", [[0.0, 0.0], [0.25, 0.07], [1.0, 0.032]]],
	},
	# Cold (decision 422 M13): hunched, knees in, the arms wrapped round the
	# chest, shaking six times a second, breathing.
	"p_shiver": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.04, -1.0, 0.06]],
			["aim", "shin.L", "foot.L", [0.07, -1.0, -0.04]],
			["aim", "thigh.R", "shin.R", [-0.04, -1.0, 0.06]],
			["aim", "shin.R", "foot.R", [-0.07, -1.0, -0.04]],
			["turn", "spine", "x", [0.2, 0.015, 0.0, 1.0]],
			["turn", "spine", "z", [0.0, 0.015, 1.0, 6.0]],
			["turn", "chest", "x", 0.15],
			["turn", "chest", "z", [0.0, 0.025, 0.0, 6.0]],
			["turn", "neck", "x", 0.35],
			["turn", "head", "z", [0.0, 0.03, 0.5, 6.0]],
			["aim", "upper_arm.L", "forearm.L", [0.15, -0.7, 0.6]],
			["aim", "forearm.L", "hand.L", [-0.9, 0.3, 0.2]],
			["aim", "upper_arm.R", "forearm.R", [-0.15, -0.7, 0.6]],
			["aim", "forearm.R", "hand.R", [0.9, 0.35, 0.15]],
		],
		"sink": 0.03,
	},
	# A hand to where it hurts (decision 422 M13), now and then while standing:
	# reached for, held, let go. The head: the right hand to the temple, the
	# head bowed and tipped to it.
	"p_pain_head": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, 0.0]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.02]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, 0.0]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, -0.02]],
			["turn", "spine", "x", ["keys", [[0.0, 0.03], [0.25, 0.12], [0.75, 0.12], [1.0, 0.03]]]],
			["turn", "chest", "y", ["keys", [[0.0, 0.0], [0.25, -0.1], [0.75, -0.1], [1.0, 0.0]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.0], [0.25, 0.25], [0.75, 0.25], [1.0, 0.0]]]],
			["turn", "head", "z", ["keys", [[0.0, 0.0], [0.25, 0.15], [0.75, 0.15], [1.0, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [0.14, -1.0, 0.02]],
			["aim", "forearm.L", "hand.L", [0.08, -1.0, 0.1]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.14], [0.12, -0.3], [0.25, -0.45], [0.75, -0.45], [0.88, -0.3], [1.0, -0.14]]], ["keys", [[0.0, -1.0], [0.12, -0.3], [0.25, 0.15], [0.75, 0.15], [0.88, -0.3], [1.0, -1.0]]], ["keys", [[0.0, 0.02], [0.12, 0.8], [0.25, 0.55], [0.75, 0.55], [0.88, 0.8], [1.0, 0.02]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0.0, -0.08], [0.12, 0.0], [0.25, 0.4], [0.75, 0.4], [0.88, 0.0], [1.0, -0.08]]], ["keys", [[0.0, -1.0], [0.12, 0.0], [0.25, 0.8], [0.75, 0.8], [0.88, 0.0], [1.0, -1.0]]], ["keys", [[0.0, 0.1], [0.12, 1.0], [0.25, -0.35], [0.75, -0.35], [0.88, 1.0], [1.0, 0.1]]]]],
		],
		"sink": ["keys", [[0.0, 0.0], [0.25, 0.0], [0.75, 0.0], [1.0, 0.0]]],
	},
	# The body: both hands pressed to the belly, bent over them, knees giving a little.
	"p_pain_torso": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, ["keys", [[0.0, 0.0], [0.25, 0.12], [0.75, 0.12], [1.0, 0.0]]]]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, ["keys", [[0.0, -0.02], [0.25, -0.08], [0.75, -0.08], [1.0, -0.02]]]]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, ["keys", [[0.0, 0.0], [0.25, 0.12], [0.75, 0.12], [1.0, 0.0]]]]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, ["keys", [[0.0, -0.02], [0.25, -0.08], [0.75, -0.08], [1.0, -0.02]]]]],
			["turn", "spine", "x", ["keys", [[0.0, 0.03], [0.25, 0.35], [0.75, 0.35], [1.0, 0.03]]]],
			["turn", "chest", "x", ["keys", [[0.0, 0.0], [0.25, 0.1], [0.75, 0.1], [1.0, 0.0]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.0], [0.25, 0.3], [0.75, 0.3], [1.0, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.14], [0.25, 0.12], [0.75, 0.12], [1.0, 0.14]]], ["keys", [[0.0, -1.0], [0.25, -0.85], [0.75, -0.85], [1.0, -1.0]]], ["keys", [[0.0, 0.02], [0.25, 0.45], [0.75, 0.45], [1.0, 0.02]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0.0, 0.08], [0.25, -0.8], [0.75, -0.8], [1.0, 0.08]]], ["keys", [[0.0, -1.0], [0.25, 0.1], [0.75, 0.1], [1.0, -1.0]]], ["keys", [[0.0, 0.1], [0.25, 0.5], [0.75, 0.5], [1.0, 0.1]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.14], [0.25, -0.12], [0.75, -0.12], [1.0, -0.14]]], ["keys", [[0.0, -1.0], [0.25, -0.85], [0.75, -0.85], [1.0, -1.0]]], ["keys", [[0.0, 0.02], [0.25, 0.45], [0.75, 0.45], [1.0, 0.02]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0.0, -0.08], [0.25, 0.8], [0.75, 0.8], [1.0, -0.08]]], ["keys", [[0.0, -1.0], [0.25, 0.15], [0.75, 0.15], [1.0, -1.0]]], ["keys", [[0.0, 0.1], [0.25, 0.5], [0.75, 0.5], [1.0, 0.1]]]]],
		],
		"sink": ["keys", [[0.0, 0.0], [0.25, 0.04], [0.75, 0.04], [1.0, 0.0]]],
	},
	# The left arm: the right hand gripping it above the elbow, the arm hanging stiff, the head turned to it.
	"p_pain_arm": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, 0.0]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.02]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, 0.0]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, -0.02]],
			["turn", "chest", "y", ["keys", [[0.0, 0.0], [0.25, 0.15], [0.75, 0.15], [1.0, 0.0]]]],
			["turn", "chest", "z", ["keys", [[0.0, 0.0], [0.25, -0.06], [0.75, -0.06], [1.0, 0.0]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.0], [0.25, 0.3], [0.75, 0.3], [1.0, 0.0]]]],
			["turn", "head", "y", ["keys", [[0.0, 0.0], [0.25, 0.4], [0.75, 0.4], [1.0, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.14], [0.25, 0.25], [0.75, 0.25], [1.0, 0.14]]], -1.0, ["keys", [[0.0, 0.02], [0.25, 0.12], [0.75, 0.12], [1.0, 0.02]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0.0, 0.08], [0.25, 0.12], [0.75, 0.12], [1.0, 0.08]]], -1.0, ["keys", [[0.0, 0.1], [0.25, 0.18], [0.75, 0.18], [1.0, 0.1]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.14], [0.12, -0.1], [0.25, 0.05], [0.75, 0.05], [0.88, -0.1], [1.0, -0.14]]], ["keys", [[0.0, -1.0], [0.12, -0.6], [0.25, -0.55], [0.75, -0.55], [0.88, -0.6], [1.0, -1.0]]], ["keys", [[0.0, 0.02], [0.12, 0.9], [0.25, 0.85], [0.75, 0.85], [0.88, 0.9], [1.0, 0.02]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0.0, -0.08], [0.12, 0.4], [0.25, 0.95], [0.75, 0.95], [0.88, 0.4], [1.0, -0.08]]], ["keys", [[0.0, -1.0], [0.12, -0.2], [0.25, 0.3], [0.75, 0.3], [0.88, -0.2], [1.0, -1.0]]], ["keys", [[0.0, 0.1], [0.12, 1.0], [0.25, 0.05], [0.75, 0.05], [0.88, 1.0], [1.0, 0.1]]]]],
		],
		"sink": ["keys", [[0.0, 0.0], [0.25, 0.0], [0.75, 0.0], [1.0, 0.0]]],
	},
	# The left leg: the weight off it, bent down with the left hand on the knee.
	"p_pain_leg": {
		"steps": [
			["aim", "thigh.L", "shin.L", [["keys", [[0.0, 0.08], [0.25, 0.1], [0.75, 0.1], [1.0, 0.08]]], -1.0, ["keys", [[0.0, 0.0], [0.25, 0.3], [0.75, 0.3], [1.0, 0.0]]]]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, ["keys", [[0.0, -0.02], [0.25, -0.12], [0.75, -0.12], [1.0, -0.02]]]]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, ["keys", [[0.0, 0.0], [0.25, 0.04], [0.75, 0.04], [1.0, 0.0]]]]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, ["keys", [[0.0, -0.02], [0.25, -0.04], [0.75, -0.04], [1.0, -0.02]]]]],
			["turn", "spine", "x", ["keys", [[0.0, 0.03], [0.25, 0.45], [0.75, 0.45], [1.0, 0.03]]]],
			["turn", "spine", "z", ["keys", [[0.0, 0.0], [0.25, 0.08], [0.75, 0.08], [1.0, 0.0]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.0], [0.25, 0.2], [0.75, 0.2], [1.0, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.14], [0.25, 0.12], [0.75, 0.12], [1.0, 0.14]]], -1.0, ["keys", [[0.0, 0.02], [0.25, 0.3], [0.75, 0.3], [1.0, 0.02]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0.0, 0.08], [0.25, 0.0], [0.75, 0.0], [1.0, 0.08]]], -1.0, ["keys", [[0.0, 0.1], [0.25, 0.3], [0.75, 0.3], [1.0, 0.1]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.14], [0.25, -0.25], [0.75, -0.25], [1.0, -0.14]]], -1.0, ["keys", [[0.0, 0.02], [0.25, 0.1], [0.75, 0.1], [1.0, 0.02]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0.0, -0.08], [0.25, -0.1], [0.75, -0.1], [1.0, -0.08]]], -1.0, ["keys", [[0.0, 0.1], [0.25, 0.2], [0.75, 0.2], [1.0, 0.1]]]]],
		],
		"sink": ["keys", [[0.0, 0.0], [0.25, 0.06], [0.75, 0.06], [1.0, 0.0]]],
	},
	# Spent (decision 422 M13): both hands to the small of the back, the back
	# arched and the head back, held a moment, and straight again.
	"p_tired_stretch": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, 0.0]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.02]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, 0.0]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, -0.02]],
			["turn", "spine", "x", ["keys", [[0.0, 0.03], [0.25, -0.094], [0.45, -0.28], [0.7, -0.28], [1.0, 0.03]]]],
			["turn", "chest", "x", ["keys", [[0.0, 0.0], [0.25, -0.06], [0.45, -0.15], [0.7, -0.15], [1.0, 0.0]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.0], [0.25, -0.14], [0.45, -0.35], [0.7, -0.35], [1.0, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.14], [0.2, 0.35], [0.8, 0.35], [1.0, 0.14]]], ["keys", [[0.0, -1.0], [0.2, -0.8], [0.8, -0.8], [1.0, -1.0]]], ["keys", [[0.0, 0.02], [0.2, -0.45], [0.8, -0.45], [1.0, 0.02]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0.0, 0.08], [0.1, 0.4], [0.2, -0.6], [0.8, -0.6], [0.9, 0.4], [1.0, 0.08]]], ["keys", [[0.0, -1.0], [0.1, -0.6], [0.2, 0.1], [0.8, 0.1], [0.9, -0.6], [1.0, -1.0]]], ["keys", [[0.0, 0.1], [0.1, -0.3], [0.2, -0.6], [0.8, -0.6], [0.9, -0.3], [1.0, 0.1]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.14], [0.2, -0.35], [0.8, -0.35], [1.0, -0.14]]], ["keys", [[0.0, -1.0], [0.2, -0.8], [0.8, -0.8], [1.0, -1.0]]], ["keys", [[0.0, 0.02], [0.2, -0.45], [0.8, -0.45], [1.0, 0.02]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0.0, -0.08], [0.1, -0.4], [0.2, 0.6], [0.8, 0.6], [0.9, -0.4], [1.0, -0.08]]], ["keys", [[0.0, -1.0], [0.1, -0.6], [0.2, 0.1], [0.8, 0.1], [0.9, -0.6], [1.0, -1.0]]], ["keys", [[0.0, 0.1], [0.1, -0.3], [0.2, -0.6], [0.8, -0.6], [0.9, -0.3], [1.0, 0.1]]]]],
		],
		"sink": 0.0,
	},
	# Putting a coat on (decision 423): the right arm back and down into its
	# sleeve, the body turned after it; the left the same; then both hands draw
	# the front together and the shoulders settle into it.
	"p_wear_outer": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, 0.0]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.02]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, 0.0]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, -0.02]],
			["turn", "spine", "x", ["keys", [[0.0, 0.03], [0.2, 0.1], [0.5, 0.1], [0.8, 0.12], [1.0, 0.03]]]],
			["turn", "chest", "y", ["keys", [[0.0, 0.0], [0.2, -0.35], [0.35, -0.1], [0.5, 0.35], [0.65, 0.1], [0.8, 0.0], [1.0, 0.0]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.0], [0.8, 0.25], [1.0, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.14], [0.35, 0.14], [0.5, 0.4], [0.62, 0.3], [0.8, 0.15], [1.0, 0.14]]], ["keys", [[0.0, -1.0], [0.35, -1.0], [0.5, -0.7], [0.62, -0.6], [0.8, -0.8], [1.0, -1.0]]], ["keys", [[0.0, 0.02], [0.35, 0.02], [0.5, -0.5], [0.62, 0.2], [0.8, 0.45], [1.0, 0.02]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0.0, 0.08], [0.35, 0.08], [0.5, 0.25], [0.62, 0.0], [0.8, -0.7], [1.0, 0.08]]], ["keys", [[0.0, -1.0], [0.35, -1.0], [0.5, -0.9], [0.62, -0.5], [0.8, 0.3], [1.0, -1.0]]], ["keys", [[0.0, 0.1], [0.35, 0.1], [0.5, -0.35], [0.62, 0.7], [0.8, 0.6], [1.0, 0.1]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.14], [0.2, -0.4], [0.33, -0.3], [0.5, -0.2], [0.8, -0.15], [1.0, -0.14]]], ["keys", [[0.0, -1.0], [0.2, -0.7], [0.33, -0.6], [0.5, -0.8], [0.8, -0.8], [1.0, -1.0]]], ["keys", [[0.0, 0.02], [0.2, -0.5], [0.33, 0.2], [0.5, 0.3], [0.8, 0.45], [1.0, 0.02]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0.0, -0.08], [0.2, -0.25], [0.33, 0.0], [0.5, -0.1], [0.8, 0.7], [1.0, -0.08]]], ["keys", [[0.0, -1.0], [0.2, -0.9], [0.33, -0.5], [0.5, -0.9], [0.8, 0.35], [1.0, -1.0]]], ["keys", [[0.0, 0.1], [0.2, -0.35], [0.33, 0.7], [0.5, 0.3], [0.8, 0.6], [1.0, 0.1]]]]],
		],
		"sink": 0.0,
	},
	# Putting a hat or a hood on (decision 423): both hands up to the top of the
	# head, drawing it down over the ears, the head bowed a little to them.
	"p_wear_head": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, 0.0]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.02]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, 0.0]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, -0.02]],
			["turn", "spine", "x", ["keys", [[0.0, 0.03], [0.3, 0.06], [1.0, 0.03]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.0], [0.3, 0.2], [0.65, 0.12], [1.0, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.14], [0.15, 0.35], [0.3, 0.5], [0.65, 0.55], [0.85, 0.3], [1.0, 0.14]]], ["keys", [[0.0, -1.0], [0.15, -0.3], [0.3, 0.35], [0.65, 0.05], [0.85, -0.6], [1.0, -1.0]]], ["keys", [[0.0, 0.02], [0.15, 0.7], [0.3, 0.4], [0.65, 0.25], [0.85, 0.3], [1.0, 0.02]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0.0, 0.08], [0.15, 0.0], [0.3, -0.4], [0.65, -0.45], [0.85, -0.1], [1.0, 0.08]]], ["keys", [[0.0, -1.0], [0.15, 0.2], [0.3, 0.85], [0.65, 0.7], [0.85, -0.5], [1.0, -1.0]]], ["keys", [[0.0, 0.1], [0.15, 1.0], [0.3, -0.2], [0.65, -0.15], [0.85, 0.6], [1.0, 0.1]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.14], [0.15, -0.35], [0.3, -0.5], [0.65, -0.55], [0.85, -0.3], [1.0, -0.14]]], ["keys", [[0.0, -1.0], [0.15, -0.3], [0.3, 0.35], [0.65, 0.05], [0.85, -0.6], [1.0, -1.0]]], ["keys", [[0.0, 0.02], [0.15, 0.7], [0.3, 0.4], [0.65, 0.25], [0.85, 0.3], [1.0, 0.02]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0.0, -0.08], [0.15, 0.0], [0.3, 0.4], [0.65, 0.45], [0.85, 0.1], [1.0, -0.08]]], ["keys", [[0.0, -1.0], [0.15, 0.2], [0.3, 0.85], [0.65, 0.7], [0.85, -0.5], [1.0, -1.0]]], ["keys", [[0.0, 0.1], [0.15, 1.0], [0.3, -0.2], [0.65, -0.15], [0.85, 0.6], [1.0, 0.1]]]]],
		],
		"sink": ["keys", [[0.0, 0.0], [0.3, 0.01], [1.0, 0.0]]],
	},
	# Putting gloves on (decision 423): the left hand held out in front, the
	# right pulling the glove up over it and tugging at the cuff; then the
	# other way round; both hands flexed once.
	"p_wear_hands": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.08, -1.0, 0.0]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, -0.02]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, 0.0]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, -0.02]],
			["turn", "spine", "x", ["keys", [[0.0, 0.03], [0.15, 0.12], [0.85, 0.12], [1.0, 0.03]]]],
			["turn", "neck", "x", ["keys", [[0.0, 0.0], [0.15, 0.35], [0.85, 0.35], [1.0, 0.0]]]],
			["turn", "chest", "y", ["keys", [[0.0, 0.0], [0.3, 0.12], [0.45, 0.12], [0.6, -0.12], [0.75, -0.12], [1.0, 0.0]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0.0, 0.14], [0.15, 0.15], [0.45, 0.15], [0.55, 0.1], [0.85, 0.1], [1.0, 0.14]]], ["keys", [[0.0, -1.0], [0.15, -0.8], [0.45, -0.8], [0.55, -0.75], [0.85, -0.75], [1.0, -1.0]]], ["keys", [[0.0, 0.02], [0.15, 0.45], [0.45, 0.45], [0.55, 0.5], [0.85, 0.5], [1.0, 0.02]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0.0, 0.08], [0.15, -0.3], [0.45, -0.3], [0.55, -0.75], [0.7, -0.55], [0.85, -0.75], [1.0, 0.08]]], ["keys", [[0.0, -1.0], [0.15, 0.05], [0.45, 0.05], [0.55, 0.2], [0.7, 0.2], [0.85, 0.2], [1.0, -1.0]]], ["keys", [[0.0, 0.1], [0.15, 1.0], [0.45, 1.0], [0.55, 0.6], [0.7, 0.8], [0.85, 0.6], [1.0, 0.1]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0.0, -0.14], [0.15, -0.1], [0.45, -0.1], [0.55, -0.15], [0.85, -0.15], [1.0, -0.14]]], ["keys", [[0.0, -1.0], [0.15, -0.75], [0.45, -0.75], [0.55, -0.8], [0.85, -0.8], [1.0, -1.0]]], ["keys", [[0.0, 0.02], [0.15, 0.5], [0.45, 0.5], [0.55, 0.45], [0.85, 0.45], [1.0, 0.02]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0.0, -0.08], [0.15, 0.75], [0.3, 0.55], [0.45, 0.75], [0.55, 0.3], [0.85, 0.3], [1.0, -0.08]]], ["keys", [[0.0, -1.0], [0.15, 0.2], [0.3, 0.2], [0.45, 0.2], [0.55, 0.05], [0.85, 0.05], [1.0, -1.0]]], ["keys", [[0.0, 0.1], [0.15, 0.6], [0.3, 0.8], [0.45, 0.6], [0.55, 1.0], [0.85, 1.0], [1.0, 0.1]]]]],
		],
		"sink": 0.0,
	},
	# Walking with a long weapon held upright before the right hip in both hands (decision
	# 422, second set): the right fist at the hip, the left higher up it, the chest hardly turning.
	"p_walk_long": {
		"steps": [
			["turn", "hips", "z", [0.0, 0.035, 0.0]],
			["turn", "hips", "y", [0.0, -0.09, 0.0]],
			["aim", "thigh.L", "shin.L", [0.07, -1.0, [[0.02, 0.4, 0.0], [0.0, -0.04, 0.0, 3.0], [0.0, 0.015, 0.0, 5.0]]]],
			["aim", "shin.L", "foot.L", [0.05, -1.0, [[-0.26, 0.38, 0.0], [0.0, -0.04, 0.0, 3.0], [0.0, 0.015, 0.0, 5.0], [0.0, -0.3, -1.5708], [0.0, -0.12, -1.5708, 2.0]]]],
			["aim", "thigh.R", "shin.R", [-0.07, -1.0, [[0.02, 0.4, 3.1416], [0.0, -0.04, 9.4248, 3.0], [0.0, 0.015, 15.708, 5.0]]]],
			["aim", "shin.R", "foot.R", [-0.05, -1.0, [[-0.26, 0.38, 3.1416], [0.0, -0.04, 9.4248, 3.0], [0.0, 0.015, 15.708, 5.0], [0.0, -0.3, 1.5708], [0.0, -0.12, 4.7124, 2.0]]]],
			["turn", "spine", "x", [0.05, 0.015, 0.0, 2.0]],
			["turn", "chest", "y", [0.0, 0.04, 0.0]],
			["turn", "neck", "x", 0.04],
			["turn", "head", "y", [0.0, -0.05, 0.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.1, -1.0, [0.3, 0.015, 0.0]]],
			["aim", "forearm.R", "hand.R", [0.05, -0.35, 1.0]],
			["aim", "upper_arm.L", "forearm.L", [-0.3, -0.7, [0.6, 0.015, 0.0]]],
			["aim", "forearm.L", "hand.L", [-0.75, 0.45, 0.5]],
		],
		"sink": [0.025, 0.02, -1.5708, 2.0],
	},
	# Walking with an axe hanging in the right hand (decision 422, second set): that arm
	# straight and hardly swinging under the weight, held a little out from the leg, the left swinging.
	"p_walk_axe": {
		"steps": [
			["turn", "hips", "z", [0.0, 0.035, 0.0]],
			["turn", "hips", "y", [0.0, -0.09, 0.0]],
			["aim", "thigh.L", "shin.L", [0.07, -1.0, [[0.02, 0.4, 0.0], [0.0, -0.04, 0.0, 3.0], [0.0, 0.015, 0.0, 5.0]]]],
			["aim", "shin.L", "foot.L", [0.05, -1.0, [[-0.26, 0.38, 0.0], [0.0, -0.04, 0.0, 3.0], [0.0, 0.015, 0.0, 5.0], [0.0, -0.3, -1.5708], [0.0, -0.12, -1.5708, 2.0]]]],
			["aim", "thigh.R", "shin.R", [-0.07, -1.0, [[0.02, 0.4, 3.1416], [0.0, -0.04, 9.4248, 3.0], [0.0, 0.015, 15.708, 5.0]]]],
			["aim", "shin.R", "foot.R", [-0.05, -1.0, [[-0.26, 0.38, 3.1416], [0.0, -0.04, 9.4248, 3.0], [0.0, 0.015, 15.708, 5.0], [0.0, -0.3, 1.5708], [0.0, -0.12, 4.7124, 2.0]]]],
			["turn", "spine", "x", [0.05, 0.015, 0.0, 2.0]],
			["turn", "chest", "y", [0.0, 0.12, 0.0]],
			["turn", "neck", "x", 0.04],
			["turn", "head", "y", [0.0, -0.05, 0.0]],
			["aim", "upper_arm.L", "forearm.L", [0.16, -1.0, [0.04, -0.3, 0.0]]],
			["aim", "forearm.L", "hand.L", [0.08, -1.0, [0.3, -0.28, 0.0]]],
			["aim", "upper_arm.R", "forearm.R", [-0.22, -1.0, [0.02, 0.06, 0.0]]],
			["aim", "forearm.R", "hand.R", [-0.12, -1.0, [0.12, 0.05, 0.0]]],
		],
		"sink": [0.025, 0.02, -1.5708, 2.0],
	},
	# Walking with a pistol hanging in the right hand, its muzzle down and forward
	# (decision 422, second set): the forearm a little back, that arm hardly swinging.
	"p_walk_pistol": {
		"steps": [
			["turn", "hips", "z", [0.0, 0.035, 0.0]],
			["turn", "hips", "y", [0.0, -0.09, 0.0]],
			["aim", "thigh.L", "shin.L", [0.07, -1.0, [[0.02, 0.4, 0.0], [0.0, -0.04, 0.0, 3.0], [0.0, 0.015, 0.0, 5.0]]]],
			["aim", "shin.L", "foot.L", [0.05, -1.0, [[-0.26, 0.38, 0.0], [0.0, -0.04, 0.0, 3.0], [0.0, 0.015, 0.0, 5.0], [0.0, -0.3, -1.5708], [0.0, -0.12, -1.5708, 2.0]]]],
			["aim", "thigh.R", "shin.R", [-0.07, -1.0, [[0.02, 0.4, 3.1416], [0.0, -0.04, 9.4248, 3.0], [0.0, 0.015, 15.708, 5.0]]]],
			["aim", "shin.R", "foot.R", [-0.05, -1.0, [[-0.26, 0.38, 3.1416], [0.0, -0.04, 9.4248, 3.0], [0.0, 0.015, 15.708, 5.0], [0.0, -0.3, 1.5708], [0.0, -0.12, 4.7124, 2.0]]]],
			["turn", "spine", "x", [0.05, 0.015, 0.0, 2.0]],
			["turn", "chest", "y", [0.0, 0.12, 0.0]],
			["turn", "neck", "x", 0.04],
			["turn", "head", "y", [0.0, -0.05, 0.0]],
			["aim", "upper_arm.L", "forearm.L", [0.16, -1.0, [0.04, -0.3, 0.0]]],
			["aim", "forearm.L", "hand.L", [0.08, -1.0, [0.3, -0.28, 0.0]]],
			["aim", "upper_arm.R", "forearm.R", [-0.15, -1.0, [0.06, 0.08, 0.0]]],
			["aim", "forearm.R", "hand.R", [-0.06, -1.0, -0.45]],
		],
		"sink": [0.025, 0.02, -1.5708, 2.0],
	},
	# Running with a long weapon in both hands across the front (decision 422, second set):
	# held as when walking with it, the legs and lean of the run.
	"p_run_long": {
		"steps": RUN_LEGS + [
			["turn", "chest", "y", [0.0, 0.05, 0.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.1, -1.0, [0.35, 0.02, 0.0]]],
			["aim", "forearm.R", "hand.R", [0.05, -0.25, 1.0]],
			["aim", "upper_arm.L", "forearm.L", [-0.3, -0.65, [0.65, 0.02, 0.0]]],
			["aim", "forearm.L", "hand.L", [-0.75, 0.5, 0.5]],
		],
		"sink": RUN_SINK,
	},
	# Running with a pistol (decision 422, second set): the right elbow bent and pumping less,
	# the muzzle up, the left arm swinging as in the run.
	"p_run_pistol": {
		"steps": RUN_LEGS + [
			["turn", "chest", "y", [0.0, 0.16, 0.0]],
			["swing", "upper_arm.L", "forearm.L", 0.18, [-0.78, -0.75, 0.0]],
			["swing", "forearm.L", "hand.L", [0.0, 0.15, 0.0], [0.82, -0.9, 0.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.2, -1.0, [0.05, 0.2, 0.0]]],
			["aim", "forearm.R", "hand.R", [-0.05, [0.15, -0.12, 0.0], 0.9]],
		],
		"sink": RUN_SINK,
	},
	# On guard with a one-handed weapon (decision 422, second set): knees bent, left side
	# forward, the right fist up by the shoulder with the head of the weapon back, the left hand out.
	"p_ready_one": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.12, -1.0, 0.22]],
			["aim", "shin.L", "foot.L", [0.1, -1.0, -0.12]],
			["aim", "thigh.R", "shin.R", [-0.14, -1.0, -0.12]],
			["aim", "shin.R", "foot.R", [-0.1, -1.0, -0.2]],
			["turn", "hips", "y", 0.2],
			["turn", "spine", "x", [0.14, 0.015, 0.0]],
			["turn", "neck", "x", -0.1],
			["turn", "chest", "y", [-0.2, 0.02, 0.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.55, -0.35, -0.25]],
			["aim", "forearm.R", "hand.R", [-0.05, 1.0, [0.3, 0.03, 0.0]]],
			["aim", "upper_arm.L", "forearm.L", [0.2, -0.45, 0.9]],
			["aim", "forearm.L", "hand.L", [-0.25, 0.45, 0.9]],
		],
		"sink": [0.07, 0.01, 0.0],
	},
	# On guard with a two-handed weapon (decision 422, second set): knees bent, both fists
	# together by the right shoulder, the weapon up and back over it, ready to swing.
	"p_ready_two": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.12, -1.0, 0.22]],
			["aim", "shin.L", "foot.L", [0.1, -1.0, -0.12]],
			["aim", "thigh.R", "shin.R", [-0.14, -1.0, -0.12]],
			["aim", "shin.R", "foot.R", [-0.1, -1.0, -0.2]],
			["turn", "hips", "y", 0.2],
			["turn", "spine", "x", [0.14, 0.015, 0.0]],
			["turn", "neck", "x", -0.1],
			["turn", "chest", "y", [-0.3, 0.02, 0.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.75, -0.55, 0.35]],
			["aim", "forearm.R", "hand.R", [-0.25, 0.5, [0.85, 0.03, 0.0]]],
			["aim", "upper_arm.L", "forearm.L", [-0.35, -0.7, 0.55]],
			["aim", "forearm.L", "hand.L", [-0.8, 0.3, 0.55]],
		],
		"sink": [0.07, 0.01, 0.0],
	},
	# On guard with a knife (decision 422, second set): crouched lower, the right fist low
	# in front with the blade forward, the left hand up before the face.
	"p_ready_stab": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.12, -1.0, 0.22]],
			["aim", "shin.L", "foot.L", [0.1, -1.0, -0.12]],
			["aim", "thigh.R", "shin.R", [-0.14, -1.0, -0.12]],
			["aim", "shin.R", "foot.R", [-0.1, -1.0, -0.2]],
			["turn", "hips", "y", 0.2],
			["turn", "spine", "x", [0.14, 0.015, 0.0]],
			["turn", "neck", "x", -0.1],
			["turn", "chest", "y", [-0.15, 0.02, 0.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.2, -0.75, 0.6]],
			["aim", "forearm.R", "hand.R", [-0.05, -1.0, [-0.1, 0.03, 0.0]]],
			["aim", "upper_arm.L", "forearm.L", [0.2, -0.4, 0.85]],
			["aim", "forearm.L", "hand.L", [-0.3, 0.6, 0.75]],
		],
		"sink": [0.11, 0.01, 0.0],
	},
	# A two-handed weapon held low in the good right hand, the hurt left arm held across the
	# belly (decision 422, second set): standing, shoulders down.
	"p_hold_weak": {
		"steps": [
			["turn", "hips", "z", [0.0, 0.04, 0.0]],
			["aim", "thigh.L", "shin.L", [[0.08, 0.02, 0.0], -1.0, 0.0]],
			["aim", "shin.L", "foot.L", [[0.06, 0.02, 0.0], -1.0, -0.02]],
			["aim", "thigh.R", "shin.R", [[-0.08, 0.02, 0.0], -1.0, 0.0]],
			["aim", "shin.R", "foot.R", [[-0.06, 0.02, 0.0], -1.0, -0.02]],
			["turn", "spine", "z", [0.0, -0.03, 0.0]],
			["turn", "spine", "x", [0.03, 0.012, 0.0, 4.0]],
			["turn", "chest", "x", [0.02, -0.015, 0.0, 4.0]],
			["turn", "head", "y", [0.0, 0.1, 0.8]],
			["turn", "chest", "x", 0.08],
			["turn", "neck", "x", 0.12],
			["aim", "upper_arm.R", "forearm.R", [-0.16, -1.0, [0.08, 0.01, 0.0, 4.0]]],
			["aim", "forearm.R", "hand.R", [-0.06, -1.0, 0.25]],
			["aim", "upper_arm.L", "forearm.L", [0.12, -1.0, 0.2]],
			["aim", "forearm.L", "hand.L", [-0.85, 0.1, 0.5]],
		],
		"sink": [0.0, 0.004, 0.0, 4.0],
	},
	# The same the other way round (decision 448): the hurt right arm across the
	# belly, the weapon held low in the left hand.
	"p_hold_weak_r": {
		"steps": [
			["turn", "hips", "z", [0.0, -0.04, 0.0]],
			["aim", "thigh.L", "shin.L", [[0.08, -0.02, 0.0], -1.0, 0.0]],
			["aim", "shin.L", "foot.L", [[0.06, -0.02, 0.0], -1.0, -0.02]],
			["aim", "thigh.R", "shin.R", [[-0.08, -0.02, 0.0], -1.0, 0.0]],
			["aim", "shin.R", "foot.R", [[-0.06, -0.02, 0.0], -1.0, -0.02]],
			["turn", "spine", "z", [0.0, 0.03, 0.0]],
			["turn", "spine", "x", [0.03, 0.012, 0.0, 4.0]],
			["turn", "chest", "x", [0.02, -0.015, 0.0, 4.0]],
			["turn", "head", "y", [0.0, -0.1, 0.8]],
			["turn", "chest", "x", 0.08],
			["turn", "neck", "x", 0.12],
			["aim", "upper_arm.L", "forearm.L", [0.16, -1.0, [0.08, 0.01, 0.0, 4.0]]],
			["aim", "forearm.L", "hand.L", [0.06, -1.0, 0.25]],
			["aim", "upper_arm.R", "forearm.R", [-0.12, -1.0, 0.2]],
			["aim", "forearm.R", "hand.R", [0.85, 0.1, 0.5]],
		],
		"sink": [0.0, 0.004, 0.0, 4.0],
	},
	# Carrying a big thing (decision 448, 19): the walk's legs, both arms brought
	# round in front to hold it against the belly, leaning back a little under it.
	"p_carry_big": {
		"steps": WALK_LEGS + [
			["turn", "spine", "x", -0.06],
			["turn", "chest", "x", 0.02],
			["turn", "chest", "y", [0.0, 0.04, 0.0]],
			["turn", "neck", "x", 0.1],
			["swing", "upper_arm.L", "forearm.L", 0.25, 0.45],
			["swing", "forearm.L", "hand.L", -0.55, 1.45],
			["swing", "upper_arm.R", "forearm.R", -0.25, 0.45],
			["swing", "forearm.R", "hand.R", 0.55, 1.45],
		],
		"sink": WALK_SINK,
	},
	# Walking hurt (decision 448, 6): the walk's legs, bent at the waist and over
	# to the right, the right hand held to that side, the left arm hardly swinging.
	"p_walk_hurt": {
		"steps": WALK_LEGS + [
			["turn", "spine", "x", [0.32, 0.02, 0.0, 2.0]],
			["turn", "chest", "x", 0.1],
			["turn", "spine", "z", 0.08],
			["turn", "chest", "y", [0.0, 0.06, 0.0]],
			["turn", "neck", "x", -0.15],
			["swing", "upper_arm.R", "forearm.R", -0.25, -0.15],
			["swing", "forearm.R", "hand.R", 0.9, 1.3],
			["aim", "upper_arm.L", "forearm.L", [0.16, -1.0, [0.04, -0.2, 0.0]]],
			["aim", "forearm.L", "hand.L", [0.08, -1.0, [0.25, -0.18, 0.0]]],
		],
		"sink": WALK_SINK,
	},
	# Fixing_Kneeling gets down at its start and up at its end: the kneeling middle alone, looped.
	"p_kneel_work": {"span": [0.2, 0.8], "steps": []},
}
const AXES: Dictionary = {"x": Vector3.RIGHT, "y": Vector3.UP, "z": Vector3.BACK}

# Hand-made additions for the still poses, applied in order after the motion is matched:
#   ["turn", bone, angle]            bend a bone about the body's left-right axis
#   ["turn_lr", bone, angle]         the same on both sides ("bone.L" and "bone.R")
#   ["aim_lr", bone, child, dir]     point a bone at a direction (x is for the left side, mirrored on the right)
#   ["hips_y", height]               set the height of the hips
const OVERLAYS: Dictionary = {
	"press": [
		["turn", "spine", 0.12], ["turn", "chest", 0.12], ["turn", "neck", 0.3], ["turn", "head", 0.2],
		["aim_lr", "upper_arm", "forearm", Vector3(-0.04, -0.1, 1.0)],
		["aim_lr", "forearm", "hand", Vector3(-0.12, 0.75, 0.75)],
	],
	"slump": [
		["hips_y", 0.17],
		["turn_lr", "shin", -1.35], ["turn_lr", "foot", 0.5],
		["turn", "spine", 0.3], ["turn", "chest", 0.3], ["turn", "neck", 0.45], ["turn", "head", 0.3],
	],
}


static func load_glb(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	return doc.generate_scene(state)


static func first_of(node: Node, cls: String) -> Node:
	if node.is_class(cls):
		return node
	for child in node.get_children():
		var found := first_of(child, cls)
		if found:
			return found
	return null


static func _world(skeleton: Skeleton3D, bone: int) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone)


static func _world_rot(skeleton: Skeleton3D, bone: int) -> Quaternion:
	return _world(skeleton, bone).basis.orthonormalized().get_rotation_quaternion()


## Bone index by name; a dotted name also matches its underscore form.
static func _bone(skeleton: Skeleton3D, bone_name: String) -> int:
	var id := skeleton.find_bone(bone_name)
	if id < 0:
		id = skeleton.find_bone(bone_name.replace(".", "_"))
	return id


## Poses the body like the motion set's skeleton right now. `ctx` is what
## prepare returns. `damp` maps a body bone name to the share (0..1) of the
## motion's turn that bone keeps.
static func retarget(ctx: Dictionary, damp: Dictionary) -> void:
	var body: Skeleton3D = ctx["body"]
	var source: Skeleton3D = ctx["source"]
	var ref: Dictionary = ctx["ref"]
	var pairs: Dictionary = ctx["map"]
	var rest_rot: Dictionary = ctx["rest_rot"]
	var keep := {}
	for bone_name: String in damp:
		keep[_bone(body, bone_name)] = float(damp[bone_name])
	var world := {}
	var body_rot := body.global_transform.basis.orthonormalized().get_rotation_quaternion()
	for i in body.get_bone_count():
		var parent := body.get_bone_parent(i)
		var parent_rot: Quaternion = world[parent] if parent >= 0 else body_rot
		var rot: Quaternion
		if pairs.has(i):
			var other: int = pairs[i]
			var delta: Quaternion = _world_rot(source, other) * (ref[other] as Quaternion).inverse()
			if keep.has(i):
				delta = Quaternion().slerp(delta, keep[i])
			rot = delta * (rest_rot[i] as Quaternion)
			body.set_bone_pose_rotation(i, (parent_rot.inverse() * rot).normalized())
		else:
			rot = parent_rot * body.get_bone_rest(i).basis.get_rotation_quaternion()
		world[i] = rot
	var hips := _bone(body, "hips")
	var travel := (_world(source, source.find_bone(MAP["hips"])).origin - (ctx["hip0"] as Vector3)) * (ctx["hip_ratio"] as float)
	var local := body.global_transform.affine_inverse() * ((ctx["hip_start"] as Vector3) + travel)
	var parent_id := body.get_bone_parent(hips)
	if parent_id >= 0:
		local = body.get_bone_global_pose(parent_id).affine_inverse() * local
	body.set_bone_pose_position(hips, local)


## Bends one bone about an axis in the body's space (default: forward); its children follow.
static func turn(body: Skeleton3D, bone_name: String, angle: float, axis: Vector3 = Vector3.RIGHT) -> void:
	var id := _bone(body, bone_name)
	var global_basis := body.get_bone_global_pose(id).basis.orthonormalized()
	var parent := body.get_bone_parent(id)
	var parent_basis := body.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	body.set_bone_pose_rotation(id, (parent_basis.inverse() * (Basis(axis, angle) * global_basis)).get_rotation_quaternion())


## Points one bone (toward its child) along a direction in the body's space; children follow.
static func aim(body: Skeleton3D, bone_name: String, child: String, dir: Vector3) -> void:
	var id := _bone(body, bone_name)
	var current := body.get_bone_global_pose(id)
	var now := (body.get_bone_global_pose(_bone(body, child)).origin - current.origin).normalized()
	var parent := body.get_bone_parent(id)
	var parent_basis := body.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var swing := Quaternion(now, dir.normalized())
	body.set_bone_pose_rotation(id, (parent_basis.inverse() * (Basis(swing) * current.basis.orthonormalized())).get_rotation_quaternion())


## Lowers the hips by `by` metres.
static func sink(body: Skeleton3D, by: float) -> void:
	var hips := _bone(body, "hips")
	body.set_bone_pose_position(hips, body.get_bone_pose_position(hips) - Vector3(0.0, by, 0.0))


## A layer value (see LAYERS) at w = TAU * progress.
static func _value(spec: Variant, w: float) -> float:
	if typeof(spec) != TYPE_ARRAY:
		return float(spec)
	var parts: Array = spec
	if parts.size() == 2 and typeof(parts[0]) == TYPE_STRING and parts[0] == "keys":
		return _keyed(parts[1], w / TAU)
	if typeof(parts[0]) == TYPE_ARRAY:
		var total := 0.0
		for part in parts:
			total += _value(part, w)
		return total
	var beats: float = parts[3] if parts.size() > 3 else 1.0
	return float(parts[0]) + float(parts[1]) * sin(beats * w - float(parts[2]))


## A keyed value at progress u: eased from key to key, held past the ends.
static func _keyed(keys: Array, u: float) -> float:
	if u <= float(keys[0][0]):
		return float(keys[0][1])
	for n in range(1, keys.size()):
		if u <= float(keys[n][0]):
			var a: Array = keys[n - 1]
			var b: Array = keys[n]
			var t := (u - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			return lerpf(float(a[1]), float(b[1]), smoothstep(0.0, 1.0, t))
	return float(keys[keys.size() - 1][1])


## Hangs a layer on the body (after retarget), for progress u (0..1). The
## layers' sinks are metres for hips 1 m up; `sink_scale` is this body's hip
## height over that, so a shorter body is lowered as far in proportion.
static func apply_layer(body: Skeleton3D, layer: Dictionary, u: float, sink_scale: float = 1.0) -> void:
	var w := TAU * u
	for step: Array in layer.get("steps", []):
		match step[0]:
			"turn":
				turn(body, step[1], _value(step[3], w), AXES[step[2]])
			"aim":
				var dir: Array = step[3]
				aim(body, step[1], step[2], Vector3(_value(dir[0], w), _value(dir[1], w), _value(dir[2], w)))
			"swing":
				var angle := _value(step[4], w)
				aim(body, step[1], step[2], Vector3(_value(step[3], w), -cos(angle), sin(angle)))
	if layer.has("sink"):
		sink(body, _value(layer["sink"], w) * sink_scale)


static func apply_overlay(body: Skeleton3D, kind: String) -> void:
	if not OVERLAYS.has(kind):
		return
	for step: Array in OVERLAYS[kind]:
		match step[0]:
			"turn":
				turn(body, step[1], step[2])
			"turn_lr":
				for side in ["L", "R"]:
					turn(body, step[1] + "." + side, step[2])
			"aim_lr":
				for side in ["L", "R"]:
					var dir: Vector3 = step[3]
					dir.x *= 1.0 if side == "L" else -1.0
					aim(body, step[1] + "." + side, step[2] + "." + side, dir)
			"hips_y":
				var hips := _bone(body, "hips")
				var at := body.get_bone_pose_position(hips)
				at.y = step[1]
				body.set_bone_pose_position(hips, at)


## Plays `clip` of the motion set at `at` (0..1 of its length) and poses the body like it.
static func _pose_at(ctx: Dictionary, clip: String, at: float, damp: Dictionary) -> void:
	if clip == "":
		# Nothing from a motion set: the body's own rest pose, and the layer does the rest.
		(ctx["body"] as Skeleton3D).reset_bone_poses()
		return
	var player: AnimationPlayer = ctx["player"]
	player.play(clip)
	player.seek(player.get_animation(clip).length * at, true)
	player.advance(0.0)
	retarget(ctx, damp)


## Poses the body for `clip` of the motion set under `layer` ("" for none) at progress u (0..1).
static func pose(ctx: Dictionary, clip: String, layer: String, u: float) -> void:
	var spec: Dictionary = LAYERS.get(layer, {})
	var at := u
	if spec.has("warp"):
		var warp: Array = spec["warp"]
		at = fposmod(u + float(warp[0]) * sin(TAU * u - float(warp[1])), 1.0)
	if spec.has("span"):
		var span: Array = spec["span"]
		at = lerpf(float(span[0]), float(span[1]), at)
	_pose_at(ctx, clip, at, spec.get("damp", {}))
	apply_layer(ctx["body"], spec, u, float(ctx.get("sink_scale", 1.0)))
	_apply_person_stride(ctx, layer)


## Rotation vectors on the shortest arc, so a loop's mean pose survives a
## change of amplitude. Only the six leg rotations are ever written back.
static func _rotation_vector(q: Quaternion) -> Vector3:
	if q.w < 0.0:
		q = -q
	var v := Vector3(q.x, q.y, q.z)
	var size := v.length()
	return v * (2.0 * atan2(size, q.w) / size) if size > 0.0000001 else Vector3.ZERO


static func _mean_rotation(samples: Array) -> Quaternion:
	var mean: Quaternion = samples[0]
	for _pass_id in 12:
		var shift := Vector3.ZERO
		for q: Quaternion in samples:
			shift += _rotation_vector(mean.inverse() * q)
		shift /= float(samples.size())
		if shift.length() < 0.0000001:
			break
		mean = (mean * Quaternion(shift.normalized(), shift.length())).normalized()
	return mean


static func _apply_person_stride(ctx: Dictionary, layer: String) -> void:
	var fit: Dictionary = ctx.get("stride_fits", {}).get(layer, {})
	if fit.is_empty():
		return
	var body: Skeleton3D = ctx["body"]
	for n in fit["bones"].size():
		var bone: int = fit["bones"][n]
		var mean: Quaternion = fit["means"][n]
		var delta := _rotation_vector(mean.inverse() * body.get_bone_pose_rotation(bone))
		if delta.length() > 0.0000001:
			body.set_bone_pose_rotation(bone, (mean * Quaternion(delta.normalized(), delta.length() * float(fit["scale"]))).normalized())
		else:
			body.set_bone_pose_rotation(bone, mean)


static func _person_stride_round(ctx: Dictionary, entry: Array) -> float:
	var reach := [[], []]
	for f in int(entry[2]):
		pose(ctx, entry[1], entry[4], float(f) / float(entry[2]))
		_note_reach(ctx, entry[0], reach)
	return _round(reach)


## A new fit for this body and this clip, including motions retargeted from
## a source in future. The sampler and the saved round use the same poses.
static func _fit_person_stride(ctx: Dictionary, entry: Array) -> void:
	if not PERSON_STRIDE_ROUNDS.has(entry[0]):
		return
	var name: String = entry[0]
	var layer: String = entry[4]
	var body: Skeleton3D = ctx["body"]
	var fits: Dictionary = ctx.get("stride_fits", {})
	ctx["stride_fits"] = fits
	fits.erase(layer)
	var bones := []
	var samples := []
	for bone_name: String in PERSON_STRIDE_BONES:
		bones.append(_bone(body, bone_name))
		samples.append([])
	var reach := [[], []]
	for f in int(entry[2]):
		pose(ctx, entry[1], layer, float(f) / float(entry[2]))
		_note_reach(ctx, name, reach)
		for n in bones.size():
			samples[n].append(body.get_bone_pose_rotation(bones[n]))
	var before := _round(reach)
	var target: float = PERSON_STRIDE_ROUNDS[name]
	if before <= 0.0:
		print("STRIDE_STOP %s %.6f inf" % [name, before])
		return
	var means := []
	for rotations: Array in samples:
		means.append(_mean_rotation(rotations))
	var fit := {"bones": bones, "means": means, "scale": 1.0}
	fits[layer] = fit
	var measured := before
	for _pass_id in STRIDE_PASSES:
		var correction := target / measured if measured > 0.0 else INF
		var needed := float(fit["scale"]) * correction
		# Bound the total change from the original, as well as each correction.
		# On a stop, discard every trial and bake the original amplitude.
		if not is_finite(needed) or correction < STRIDE_SCALE_MIN or correction > STRIDE_SCALE_MAX or needed < STRIDE_SCALE_MIN or needed > STRIDE_SCALE_MAX:
			fits.erase(layer)
			print("STRIDE_STOP %s %.6f %.6f" % [name, before, needed])
			return
		fit["scale"] = needed
		measured = _person_stride_round(ctx, entry)
		if absf(measured - target) <= target * STRIDE_TOLERANCE:
			break
	var status := "STRIDE" if absf(measured - target) <= target * STRIDE_TOLERANCE else "STRIDE_UNFIT"
	print("%s %s round %.6f -> %.6f scale %.6f" % [status, name, before, measured, fit["scale"]])


## Fixed rest-bottom vertices of each foot, reused for contact and standing checks.
static func person_sole_vertices(rest: PackedVector3Array) -> Array:
	var soles := [PackedInt32Array(), PackedInt32Array()]  # left (+x), right (-x)
	var lows := [INF, INF]
	for i in rest.size():
		var side := 0 if rest[i].x >= 0.0 else 1
		lows[side] = minf(float(lows[side]), rest[i].y)
	for i in rest.size():
		var side := 0 if rest[i].x >= 0.0 else 1
		if rest[i].y <= float(lows[side]) + PERSON_SOLE_EPSILON:
			soles[side].append(i)
	return soles


## First downward entry into the lowest centimetre, including the loop seam.
## Interpolate the crossing between samples; -1 means no airborne-to-ground entry.
static func person_contact_phase(heights: Array) -> float:
	if heights.size() < 2:
		return -1.0
	var threshold := float(heights.min()) + PERSON_CONTACT_HEIGHT
	for f in heights.size():
		var previous := float(heights[(f + heights.size() - 1) % heights.size()])
		var current := float(heights[f])
		if previous > threshold and current <= threshold:
			var fraction := (previous - threshold) / (previous - current)
			return fposmod((float(f - 1) + fraction) / float(heights.size()), 1.0)
	return -1.0


## The output samples source(u + shift). Minimise the larger circular error,
## considering either foot order, and split any spacing mismatch equally.
static func person_phase_shift(left: float, right: float) -> float:
	var best := 0.0
	var least_error := INF
	for order in 2:
		var a := fposmod(left - float(PERSON_STEP_AT[order]), 1.0)
		var b := fposmod(right - float(PERSON_STEP_AT[1 - order]), 1.0)
		var gap := fposmod(b - a + 0.5, 1.0) - 0.5
		var shift := fposmod(a + gap * 0.5, 1.0)
		var error := absf(gap) * 0.5
		if error < least_error - 0.0000001 or (absf(error - least_error) <= 0.0000001 and minf(shift, 1.0 - shift) < minf(best, 1.0 - best)):
			least_error = error
			best = shift
	return best


## Use the body's sole skin, including when this bake outputs a coat or bag.
## A garment's own lowest point is its hem, not the person's foot.
static func _person_sole_heights(ctx: Dictionary, entry: Array) -> Array:
	var mesh_node: MeshInstance3D = ctx["mesh_node"]
	var source: Array = mesh_node.get_meta(PERSON_PHASE_SOURCE) if mesh_node.has_meta(PERSON_PHASE_SOURCE) else mesh_node.mesh.surface_get_arrays(0)
	var rest: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = source[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = source[Mesh.ARRAY_WEIGHTS]
	var soles := person_sole_vertices(rest)
	var heights := [[], []]
	if rest.is_empty() or soles[0].is_empty() or soles[1].is_empty():
		return heights
	var per: int = bones.size() / rest.size()
	for f in PERSON_PHASE_SAMPLES:
		pose(ctx, entry[1], entry[4], float(f) / float(PERSON_PHASE_SAMPLES))
		var skin := _skin_frame(ctx)
		for side in 2:
			var lowest := INF
			for vertex: int in soles[side]:
				var moved := Vector3.ZERO
				var weight_sum := 0.0
				for slot in per:
					var weight := weights[vertex * per + slot]
					if weight > 0.0:
						moved += ((skin[bones[vertex * per + slot]] as Transform3D) * rest[vertex]) * weight
						weight_sum += weight
				var point := moved / weight_sum if weight_sum > 0.0 else rest[vertex]
				lowest = minf(lowest, point.y)
			heights[side].append(lowest)
	return heights


static func _fit_person_phase(ctx: Dictionary, entry: Array) -> Dictionary:
	var name: String = entry[0]
	if not PERSON_PHASE_BASE.has(name):
		return {}
	var base: String = PERSON_PHASE_BASE[name]
	var fits: Dictionary = ctx.get("phase_fits", {})
	ctx["phase_fits"] = fits
	if not fits.has(base):
		var heights := _person_sole_heights(ctx, entry)
		var left := person_contact_phase(heights[0])
		var right := person_contact_phase(heights[1])
		fits[base] = {"left": left, "right": right, "shift": person_phase_shift(left, right) if left >= 0.0 and right >= 0.0 else 0.0}
	var fit: Dictionary = fits[base]
	var shift: float = fit["shift"]
	if float(fit["left"]) < 0.0 or float(fit["right"]) < 0.0:
		push_error("PHASE_STOP %s no_sole_contact left %.6f right %.6f" % [name, fit["left"], fit["right"]])
	else:
		print("PHASE %s %.6f %.6f shift %.6f" % [name, fposmod(float(fit["left"]) - shift, 1.0), fposmod(float(fit["right"]) - shift, 1.0), shift])
	# Preserve the pre-shift round: a fractional resample can alter the discrete
	# round estimator even though it is the same continuous loop.
	return {"shift": shift, "round": _person_stride_round(ctx, entry)}


## One skin matrix per bone the mesh binds: pose * inverse bind, in mesh space.
static func _skin_frame(ctx: Dictionary) -> Array:
	var body: Skeleton3D = ctx["body"]
	var skin: Skin = ctx["skin"]
	var bind_bone: Array = ctx["bind_bone"]
	var mats := []
	for j in bind_bone.size():
		mats.append((ctx["to_mesh"] as Transform3D) * body.get_bone_global_pose(bind_bone[j]) * skin.get_bind_pose(j))
	return mats


## Collects what posing needs from the two models (both in the scene tree) to
## bake `list` and `poses`; {} if something is missing.
static func prepare(body_root: Node3D, motion_root: Node3D, list: Array = CLIPS, poses: Array = POSES) -> Dictionary:
	var source := first_of(motion_root, "Skeleton3D") as Skeleton3D
	var player := first_of(motion_root, "AnimationPlayer") as AnimationPlayer
	var body := first_of(body_root, "Skeleton3D") as Skeleton3D
	var mesh_node := first_of(body_root, "MeshInstance3D") as MeshInstance3D
	if source == null or player == null or body == null or mesh_node == null or mesh_node.skin == null:
		push_error("body_bake: need a skeleton and animation player in the motions, and a skeleton and skinned mesh in the body")
		return {}
	for entry: Array in list:
		if entry[1] != "" and not player.has_animation(entry[1]):
			push_error("body_bake: motion not found: " + str(entry[1]))
			return {}
		if entry[4] != "" and not LAYERS.has(entry[4]):
			push_error("body_bake: layer not found: " + str(entry[4]))
			return {}
	for entry: Array in poses:
		if not player.has_animation(entry[0]):
			push_error("body_bake: motion not found: " + str(entry[0]))
			return {}
	source.reset_bone_poses()
	body.reset_bone_poses()
	var ctx := {"source": source, "player": player, "body": body, "mesh_node": mesh_node, "ref": {}, "map": {}, "rest_rot": {}, "hip0": _world(source, source.find_bone(MAP["hips"])).origin}
	for i in source.get_bone_count():
		ctx["ref"][i] = _world_rot(source, i)
	for body_bone: String in MAP:
		var mine := _bone(body, body_bone)
		var theirs := source.find_bone(MAP[body_bone])
		if mine < 0 or theirs < 0:
			push_error("body_bake: bone not found: " + body_bone + " / " + str(MAP[body_bone]))
			return {}
		ctx["map"][mine] = theirs
	for i in body.get_bone_count():
		ctx["rest_rot"][i] = _world_rot(body, i)
	ctx["hip_start"] = _world(body, _bone(body, "hips")).origin
	# The body's hips sit this much higher or lower than the motion set's.
	ctx["hip_ratio"] = ((ctx["hip_start"] as Vector3).y - body_root.global_position.y) / ((ctx["hip0"] as Vector3).y - motion_root.global_position.y)
	_bind_skin(ctx)
	return ctx


## Collects what posing needs from the body alone, for the motions written
## here with nothing from a motion set (OWN_CLIPS); {} if something is missing.
static func prepare_own(body_root: Node3D, entries: Array = OWN_CLIPS + OWN_POSES) -> Dictionary:
	var body := first_of(body_root, "Skeleton3D") as Skeleton3D
	var mesh_node := first_of(body_root, "MeshInstance3D") as MeshInstance3D
	if body == null or mesh_node == null or mesh_node.skin == null:
		push_error("body_bake: need a skeleton and skinned mesh in the body")
		return {}
	for body_bone: String in MAP:
		if _bone(body, body_bone) < 0:
			push_error("body_bake: bone not found: " + body_bone)
			return {}
	for entry: Array in entries:
		var layer: String = entry[4] if entry.size() > 4 else entry[0]
		if not LAYERS.has(layer):
			push_error("body_bake: layer not found: " + layer)
			return {}
	body.reset_bone_poses()
	var ctx := {"body": body, "mesh_node": mesh_node, "sink_scale": _sink_scale(body_root, body)}
	_bind_skin(ctx)
	return ctx


## The layers' sinks were written for hips 1 m up (see apply_layer): this body's share of that.
static func _sink_scale(body_root: Node3D, body: Skeleton3D) -> float:
	var hips := body.global_transform * body.get_bone_global_rest(_bone(body, "hips"))
	return (hips.origin.y - body_root.global_position.y) / HIP_HEIGHT


static func _bind_skin(ctx: Dictionary) -> void:
	var body: Skeleton3D = ctx["body"]
	var mesh_node: MeshInstance3D = ctx["mesh_node"]
	var skin := mesh_node.skin
	var bind_bone := []
	for j in skin.get_bind_count():
		var id := skin.get_bind_bone(j)
		if id < 0:
			id = body.find_bone(skin.get_bind_name(j))
		bind_bone.append(id)
	ctx["skin"] = skin
	ctx["bind_bone"] = bind_bone
	# Mesh space is the mesh node's own space; the skeleton may sit elsewhere.
	ctx["to_mesh"] = mesh_node.global_transform.affine_inverse() * body.global_transform


## Bakes the body in `body_root` with the motions in `motion_root`; both must be
## in the scene tree. Returns what VatBaker.build_skinned returns (the clips are
## CLIPS in order, then one POSES_CLIP of still poses), or {} if something is missing.
static func bake(body_root: Node3D, motion_root: Node3D) -> Dictionary:
	var ctx := prepare(body_root, motion_root)
	if ctx.is_empty():
		return {}
	return _bake_list(ctx, CLIPS, POSES)


# Garments as a layer over a body (decision 423): a coat or a head piece is the
# body's own surface where it would be, welded, pushed out along its own
# normals and weighted as the body is, so it moves exactly with it. Baked with
# the same motions as the body it is drawn over (bake_body_cli --shell=, the
# same --set and --keep), its clips line up frame for frame. Each: the bones
# whose skin it covers, how far out (metres), and for a head piece how much of
# the head from the top it covers ("top", 0..1) and whether it leaves the face.
const SHELLS: Dictionary = {
	"coat_long": {"bones": ["hips", "spine", "chest", "upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R", "thigh.L", "thigh.R"], "push": 0.03},
	"jacket_short": {"bones": ["hips", "spine", "chest", "upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R"], "push": 0.025},
	"hat_knit": {"bones": ["head"], "push": 0.02, "top": 0.55},
	"hood": {"bones": ["head", "neck"], "push": 0.025, "top": 1.0, "face": true},
	# The armour vest (wear.gd vest_armor, covers the torso): chest and back down to the waist, the arms bare,
	# thicker than a coat. Its edges (neck, armholes round the shoulder straps, hem) a little lighter than the
	# rest ("trim": how much), so it reads apart from the clothes under it; no marks or lettering.
	"vest": {"bones": ["spine", "chest"], "push": 0.04, "trim": 1.35},
}
# Bags on the back (carry.gd BAGS, decision 448): not cut from the body but
# made here against its back, each vertex weighted as the back beside it is,
# so a bag moves and bends with the body as a garment does (bake_body_cli
# --shell=, drawn as one). Everyday packs, not an army one (no frame, no
# webbing). Width, height, depth in metres; a pocket on the outside, or a
# rolled blanket strapped on top.
const BAG_SHELLS: Dictionary = {
	"pack": {"size": Vector3(0.3, 0.4, 0.14), "pocket": true},
	"big_pack": {"size": Vector3(0.36, 0.54, 0.2), "roll": true},
}
const BAG_GAP: float = 0.04                # off the back: past a coat (SHELLS push) and a little air
const BAG_BELOW_TOP: float = 0.05          # its top this far under the top of the back
const SHELL_FACE_FORWARD: float = 0.3      # a head vertex facing forward more than this is face, for a piece that leaves it
const SHELL_FACE_BROW: float = 0.15        # but not the top this share of the head (the brow is covered)
const GLOVE_COLOUR: Color = Color(0.17, 0.16, 0.15)  # dark worn wool, as the colour picture holds it
const GLOVE_GRAIN: float = 0.5             # how much of the picture's own light and dark a glove keeps
const GLOVE_SPREAD: int = 2                # pixels painted past each hand piece, so no skin shows at a seam
const HAND_LIGHT: StringName = &"hand_light"   # a marked mesh's meta: the colour picture's light at its hands (hand_light)


## Puts the shell of garment `kind` (SHELLS) in place of the body's skinned
## mesh: the same skin, the same bones, only the covered part, welded where
## the body's vertices were split, pushed out. False if `kind` is unknown or
## the body has no skinned mesh.
static func shell(body_root: Node3D, kind: String) -> bool:
	var phase_mesh := first_of(body_root, "MeshInstance3D") as MeshInstance3D
	if phase_mesh != null and phase_mesh.mesh != null and not phase_mesh.has_meta(PERSON_PHASE_SOURCE):
		phase_mesh.set_meta(PERSON_PHASE_SOURCE, phase_mesh.mesh.surface_get_arrays(0))
	if BAG_SHELLS.has(kind):
		return _bag(body_root, kind)
	var spec: Dictionary = SHELLS.get(kind, {})
	var mesh_node := first_of(body_root, "MeshInstance3D") as MeshInstance3D
	var body := first_of(body_root, "Skeleton3D") as Skeleton3D
	if spec.is_empty() or mesh_node == null or body == null or mesh_node.skin == null:
		return false
	var src: Array = mesh_node.mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = src[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = src[Mesh.ARRAY_WEIGHTS]
	var index: PackedInt32Array = src[Mesh.ARRAY_INDEX]
	var per: int = bones.size() / pos.size()
	var skin := mesh_node.skin
	var wanted := {}
	for bone_name: String in spec["bones"]:
		wanted[_bone(body, bone_name)] = true
	var covered := PackedByteArray()
	covered.resize(pos.size())
	var low := INF
	var high := -INF
	for v in pos.size():
		if wanted.has(_main_bone(body, skin, bones, weights, per, v)):
			covered[v] = 1
			low = minf(low, pos[v].y)
			high = maxf(high, pos[v].y)
	var top := float(spec.get("top", 1.0))
	var span := high - low
	for v in pos.size():
		if covered[v] == 0:
			continue
		if pos[v].y < high - top * span:
			covered[v] = 0
		elif bool(spec.get("face", false)) and normals[v].z > SHELL_FACE_FORWARD and pos[v].y < high - SHELL_FACE_BROW * span:
			covered[v] = 0
	# Weld: one shell vertex for each place, taking the skin of the first there.
	var key_of := {}
	var out_pos := PackedVector3Array()
	var out_bones := PackedInt32Array()
	var out_weights := PackedFloat32Array()
	var along := PackedVector3Array()
	var out_index := PackedInt32Array()
	for t in range(0, index.size(), 3):
		var corners := [index[t], index[t + 1], index[t + 2]]
		var inside := 0
		for c: int in corners:
			inside += covered[c]
		if inside < 2:
			continue
		var ids := []
		for c: int in corners:
			var key := (pos[c] * 10000.0).round()
			if not key_of.has(key):
				key_of[key] = out_pos.size()
				out_pos.append(pos[c])
				along.append(Vector3.ZERO)
				for k in per:
					out_bones.append(bones[c * per + k])
					out_weights.append(weights[c * per + k])
			var id: int = key_of[key]
			along[id] += normals[c]
			ids.append(id)
		if ids[0] == ids[1] or ids[1] == ids[2] or ids[0] == ids[2]:
			continue
		for id: int in ids:
			out_index.append(id)
	if out_index.is_empty():
		return false
	# The shell's own normals, from its triangles, turned the way the body's face.
	var out_normals := PackedVector3Array()
	out_normals.resize(out_pos.size())
	for t in range(0, out_index.size(), 3):
		var a := out_pos[out_index[t]]
		var face := (out_pos[out_index[t + 1]] - a).cross(out_pos[out_index[t + 2]] - a)
		for k in 3:
			out_normals[out_index[t + k]] += face
	var push := float(spec["push"])
	for i in out_pos.size():
		var n := out_normals[i]
		if n.dot(along[i]) < 0.0:
			n = -n
		n = n.normalized() if n.length_squared() > 0.0 else along[i].normalized()
		out_normals[i] = n
		out_pos[i] += n * push
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_pos
	arrays[Mesh.ARRAY_NORMAL] = out_normals
	arrays[Mesh.ARRAY_BONES] = out_bones
	arrays[Mesh.ARRAY_WEIGHTS] = out_weights
	arrays[Mesh.ARRAY_INDEX] = out_index
	if spec.has("trim"):
		arrays[Mesh.ARRAY_COLOR] = shell_trim(out_index, out_pos.size(), float(spec["trim"]))
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0)
	mesh_node.mesh = mesh
	return true


## A shell's vertex colours for a lighter trim: 1 on its open edges (an edge of
## one triangle only: the neck, the armholes, the hem), 1 / `trim` elsewhere, so
## a garment drawn `trim` times its colour (dead_cast.gd garment_of) keeps that
## colour in the body of it and is lighter at the edges. Alpha 1 (the pattern).
static func shell_trim(index: PackedInt32Array, count: int, trim: float) -> PackedColorArray:
	var uses := {}
	for t in range(0, index.size(), 3):
		for k in 3:
			var a := index[t + k]
			var b := index[t + (k + 1) % 3]
			var edge := Vector2i(mini(a, b), maxi(a, b))
			uses[edge] = int(uses.get(edge, 0)) + 1
	var inner := 1.0 / maxf(trim, 1.0)
	var colours := PackedColorArray()
	colours.resize(count)
	colours.fill(Color(inner, inner, inner, 1.0))
	for edge: Vector2i in uses:
		if int(uses[edge]) == 1:
			colours[edge.x] = Color.WHITE
			colours[edge.y] = Color.WHITE
	return colours


## Puts bag `kind` (BAG_SHELLS) in place of the body's skinned mesh: a block
## with its edges cut, against the back under the shoulders, with a pocket or
## a roll; each face its own vertices (flat light), each vertex weighted as
## the nearest piece of the back. False without a skinned mesh or a back.
static func _bag(body_root: Node3D, kind: String) -> bool:
	var spec: Dictionary = BAG_SHELLS[kind]
	var mesh_node := first_of(body_root, "MeshInstance3D") as MeshInstance3D
	var body := first_of(body_root, "Skeleton3D") as Skeleton3D
	if mesh_node == null or body == null or mesh_node.skin == null:
		return false
	var src: Array = mesh_node.mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = src[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = src[Mesh.ARRAY_WEIGHTS]
	var per: int = bones.size() / pos.size()
	var trunk := {_bone(body, "spine"): true, _bone(body, "chest"): true, _bone(body, "hips"): true}
	var back := PackedInt32Array()
	var top := -INF
	for v in pos.size():
		if normals[v].z < -0.2 and absf(pos[v].x) < 0.2 and trunk.has(_main_bone(body, mesh_node.skin, bones, weights, per, v)):
			back.append(v)
			top = maxf(top, pos[v].y)
	if back.is_empty():
		return false
	var size: Vector3 = spec["size"]
	var high := top - BAG_BELOW_TOP
	var low := high - size.y
	# Its face against the back, leaning as the back does: behind the furthest-out
	# part of the back in its upper third and in its lower third.
	var upper := INF
	var lower := INF
	for v in back:
		if absf(pos[v].x) >= size.x * 0.5:
			continue
		if pos[v].y <= high and pos[v].y >= high - size.y / 3.0:
			upper = minf(upper, pos[v].z)
		elif pos[v].y >= low and pos[v].y <= low + size.y / 3.0:
			lower = minf(lower, pos[v].z)
	if upper == INF:
		return false
	if lower == INF:
		lower = upper
	var face := (upper + lower) * 0.5 - BAG_GAP
	var out := {"pos": [], "normal": [], "index": []}
	_block(out, Vector3(0.0, (low + high) * 0.5, face - size.z * 0.5), size, minf(0.035, size.z * 0.25), 0.78, upper - lower)
	# (The pocket and the roll follow the same lean.)
	var lean := upper - lower
	if bool(spec.get("pocket", false)):
		var pocket := Vector3(size.x * 0.66, size.y * 0.36, size.z * 0.4)
		var y := low + pocket.y * 0.5 + 0.03
		var along := lean * ((y - low) / size.y - 0.5)
		_block(out, Vector3(0.0, y, face + along - size.z - pocket.z * 0.5 + 0.01), pocket, 0.02, 0.85, lean * pocket.y / size.y)
	if bool(spec.get("roll", false)):
		# On the narrowed top, toward the back.
		_roll(out, Vector3(0.0, high + 0.05, face + lean * 0.5 - size.z * 0.4), size.x * 0.95, 0.06)
	# Each vertex rides as the piece of the back nearest it does.
	var out_bones := PackedInt32Array()
	var out_weights := PackedFloat32Array()
	for p: Vector3 in out["pos"]:
		var best := back[0]
		var best_d := INF
		for v in back:
			var d := Vector2(pos[v].x - p.x, pos[v].y - clampf(p.y, low, high)).length_squared()
			if d < best_d:
				best_d = d
				best = v
		for k in per:
			out_bones.append(bones[best * per + k])
			out_weights.append(weights[best * per + k])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(out["pos"])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(out["normal"])
	arrays[Mesh.ARRAY_BONES] = out_bones
	arrays[Mesh.ARRAY_WEIGHTS] = out_weights
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(out["index"])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0)
	mesh_node.mesh = mesh
	return true


## A flat face (its corners in order around `normal`) added to `out`.
static func _face(out: Dictionary, corners: Array, normal: Vector3) -> void:
	var first: int = (out["pos"] as Array).size()
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	var flip := (b - a).cross(c - a).dot(normal) > 0.0
	for p: Vector3 in corners:
		(out["pos"] as Array).append(p)
		(out["normal"] as Array).append(normal)
	for i in range(1, corners.size() - 1):
		var tri := [first, first + i, first + i + 1]
		# Godot's front faces wind clockwise as seen from outside.
		if flip:
			tri = [first, first + i + 1, first + i]
		(out["index"] as Array).append_array(tri)


## A block of `size` centred at `at`, its four upright edges cut by `cut`; its
## top `taper` as wide and deep as its bottom, drawn to its +z side (toward the
## back it hangs on), as a filled pack sags; its top `lean` further along z
## than its bottom (the whole leaning as the back under it).
static func _block(out: Dictionary, at: Vector3, size: Vector3, cut: float, taper: float = 1.0, lean: float = 0.0) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	# Around the block, seen from above: eight corners of the cut rectangle.
	var ring := [Vector2(-hx + cut, -hz), Vector2(hx - cut, -hz), Vector2(hx, -hz + cut), Vector2(hx, hz - cut),
		Vector2(hx - cut, hz), Vector2(-hx + cut, hz), Vector2(-hx, hz - cut), Vector2(-hx, -hz + cut)]
	var lo := at.y - size.y * 0.5
	var hi := at.y + size.y * 0.5
	var bottom_ring := []
	var top_ring := []
	for p: Vector2 in ring:
		bottom_ring.append(Vector3(at.x + p.x, lo, at.z + p.y - lean * 0.5))
		top_ring.append(Vector3(at.x + p.x * taper, hi, at.z + hz - (hz - p.y) * taper + lean * 0.5))
	for i in ring.size():
		var j := (i + 1) % ring.size()
		var a: Vector3 = bottom_ring[i]
		var b: Vector3 = bottom_ring[j]
		var c: Vector3 = top_ring[j]
		var side := (b - a).cross(c - a).normalized()
		var mid := (a + b + c) / 3.0 - Vector3(at.x, (lo + hi) * 0.5, at.z)
		if side.dot(Vector3(mid.x, 0.0, mid.z)) < 0.0:
			side = -side
		_face(out, [a, b, c, top_ring[i]], side)
	_face(out, top_ring, Vector3.UP)
	_face(out, bottom_ring, Vector3.DOWN)


## A rolled blanket lying across, `length` long, of `radius`, centred at `at`.
static func _roll(out: Dictionary, at: Vector3, length: float, radius: float) -> void:
	var sides := 8
	var l := at.x - length * 0.5
	var r := at.x + length * 0.5
	var left_cap := []
	var right_cap := []
	for i in sides:
		var a := TAU * float(i) / sides
		var b := TAU * float(i + 1) / sides
		var pa := Vector2(cos(a), sin(a)) * radius
		var pb := Vector2(cos(b), sin(b)) * radius
		var mid := (a + b) * 0.5
		_face(out, [Vector3(l, at.y + pa.y, at.z + pa.x), Vector3(r, at.y + pa.y, at.z + pa.x),
			Vector3(r, at.y + pb.y, at.z + pb.x), Vector3(l, at.y + pb.y, at.z + pb.x)], Vector3(0.0, sin(mid), cos(mid)))
		left_cap.append(Vector3(l, at.y + pa.y, at.z + pa.x))
		right_cap.append(Vector3(r, at.y + pa.y, at.z + pa.x))
	_face(out, left_cap, Vector3.LEFT)
	_face(out, right_cap, Vector3.RIGHT)


## The body bone vertex `v` of a skin follows most.
static func _main_bone(body: Skeleton3D, skin: Skin, bones: PackedInt32Array, weights: PackedFloat32Array, per: int, v: int) -> int:
	var best := 0
	for k in per:
		if weights[v * per + k] > weights[v * per + best]:
			best = k
	var bind: int = bones[v * per + best]
	var id := skin.get_bind_bone(bind)
	return id if id >= 0 else body.find_bone(skin.get_bind_name(bind))


## The body's colour picture with its hands painted as gloves (decision 423):
## each triangle of the skin with two corners or more on a hand, a little past
## its edges so no skin shows at a seam, in `colour` with some of the picture's
## own light and dark kept. Null without a skinned mesh with UVs.
static func gloved(body_root: Node3D, albedo: Image, colour: Color = GLOVE_COLOUR) -> Image:
	var mesh_node := first_of(body_root, "MeshInstance3D") as MeshInstance3D
	var body := first_of(body_root, "Skeleton3D") as Skeleton3D
	if mesh_node == null or body == null or mesh_node.skin == null or albedo == null:
		return null
	var src: Array = mesh_node.mesh.surface_get_arrays(0)
	if src[Mesh.ARRAY_TEX_UV] == null:
		return null
	var uv: PackedVector2Array = src[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = src[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = src[Mesh.ARRAY_WEIGHTS]
	var index: PackedInt32Array = src[Mesh.ARRAY_INDEX]
	var per: int = bones.size() / uv.size()
	var hands := {_bone(body, "hand.L"): true, _bone(body, "hand.R"): true}
	var on_hand := PackedByteArray()
	on_hand.resize(uv.size())
	for v in uv.size():
		on_hand[v] = 1 if hands.has(_main_bone(body, mesh_node.skin, bones, weights, per, v)) else 0
	var out := albedo.duplicate() as Image
	if out.is_compressed():
		out.decompress()
	var size := Vector2(out.get_width(), out.get_height())
	var w := out.get_width()
	var mask := PackedByteArray()
	mask.resize(w * out.get_height())
	for t in range(0, index.size(), 3):
		if on_hand[index[t]] + on_hand[index[t + 1]] + on_hand[index[t + 2]] < 2:
			continue
		var a := uv[index[t]] * size
		var b := uv[index[t + 1]] * size
		var c := uv[index[t + 2]] * size
		var lo := a.min(b).min(c).floor().clamp(Vector2.ZERO, size - Vector2.ONE)
		var hi := a.max(b).max(c).floor().clamp(Vector2.ZERO, size - Vector2.ONE)
		for y in range(int(lo.y), int(hi.y) + 1):
			for x in range(int(lo.x), int(hi.x) + 1):
				if Geometry2D.point_is_inside_triangle(Vector2(x + 0.5, y + 0.5), a, b, c):
					mask[y * w + x] = 1
		for corner in [a, b, c]:
			var at: Vector2 = corner.floor().clamp(Vector2.ZERO, size - Vector2.ONE)
			mask[int(at.y) * w + int(at.x)] = 1
	for i in GLOVE_SPREAD:
		var grown := mask.duplicate()
		for y in out.get_height():
			for x in w:
				if mask[y * w + x] == 1:
					continue
				var left := x > 0 and mask[y * w + x - 1] == 1
				var right := x + 1 < w and mask[y * w + x + 1] == 1
				var up := y > 0 and mask[(y - 1) * w + x] == 1
				var down := y + 1 < out.get_height() and mask[(y + 1) * w + x] == 1
				if left or right or up or down:
					grown[y * w + x] = 1
		mask = grown
	var mean := 0.0
	var count := 0
	for i in mask.size():
		if mask[i] == 1:
			mean += out.get_pixel(i % w, i / w).get_luminance()
			count += 1
	mean = maxf(mean / maxi(count, 1), 0.05)
	for i in mask.size():
		if mask[i] == 1:
			var grain := lerpf(1.0, clampf(out.get_pixel(i % w, i / w).get_luminance() / mean, 0.5, 1.5), GLOVE_GRAIN)
			out.set_pixel(i % w, i / w, Color(colour.r * grain, colour.g * grain, colour.b * grain))
	return out


## The body's hands marked for the shader to glove (dead_vat.gdshader `gloves`,
## decision 434) instead of a second, gloved colour picture: a colour for each
## vertex of the skinned mesh, white, its alpha 1 where the hand bones carry it
## most (as gloved() picks the hands) and 0 elsewhere. Empty without a skinned mesh.
static func hand_marks(body_root: Node3D) -> PackedColorArray:
	var out := PackedColorArray()
	var mesh_node := first_of(body_root, "MeshInstance3D") as MeshInstance3D
	var body := first_of(body_root, "Skeleton3D") as Skeleton3D
	if mesh_node == null or body == null or mesh_node.skin == null:
		return out
	var src: Array = mesh_node.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = src[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = src[Mesh.ARRAY_WEIGHTS]
	var count: int = (src[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var per: int = bones.size() / maxi(count, 1)
	var hands := {_bone(body, "hand.L"): true, _bone(body, "hand.R"): true}
	out.resize(count)
	for v in count:
		out[v] = Color(1, 1, 1, 1.0 if hands.has(_main_bone(body, mesh_node.skin, bones, weights, per, v)) else 0.0)
	return out


## How light the colour picture is at the hands (marks as hand_marks gives
## them): the mean of its light over each triangle with two corners or more on a
## hand, as the picture holds it. A glove keeps GLOVE_GRAIN of the picture's own
## light and dark against it. 0 when there is no hand.
static func hand_light(mesh: Mesh, marks: PackedColorArray, albedo: Image) -> float:
	var src: Array = mesh.surface_get_arrays(0)
	if src[Mesh.ARRAY_TEX_UV] == null or albedo == null:
		return 0.0
	var picture := albedo.duplicate() as Image
	if picture.is_compressed():
		picture.decompress()
	var uv: PackedVector2Array = src[Mesh.ARRAY_TEX_UV]
	var index: PackedInt32Array = src[Mesh.ARRAY_INDEX]
	var size := Vector2(picture.get_width(), picture.get_height())
	var sum := 0.0
	var count := 0
	for t in range(0, index.size(), 3):
		if marks[index[t]].a + marks[index[t + 1]].a + marks[index[t + 2]].a < 1.5:
			continue
		var a := uv[index[t]] * size
		var b := uv[index[t + 1]] * size
		var c := uv[index[t + 2]] * size
		var lo := a.min(b).min(c).floor().clamp(Vector2.ZERO, size - Vector2.ONE)
		var hi := a.max(b).max(c).floor().clamp(Vector2.ZERO, size - Vector2.ONE)
		for y in range(int(lo.y), int(hi.y) + 1):
			for x in range(int(lo.x), int(hi.x) + 1):
				if Geometry2D.point_is_inside_triangle(Vector2(x + 0.5, y + 0.5), a, b, c):
					sum += picture.get_pixel(x, y).get_luminance()
					count += 1
	return sum / count if count > 0 else 0.0


## `mesh` (one surface, as build_skinned makes it) with `marks` as its vertex
## colours, the rest as it was: the same vertices in the same order, so the
## motion picture reads it as before. Its hand light (hand_light) goes with it
## as the mesh's HAND_LIGHT. Null when the counts differ.
static func with_hand_marks(mesh: Mesh, marks: PackedColorArray, light: float) -> ArrayMesh:
	var src: Array = mesh.surface_get_arrays(0)
	if (src[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() != marks.size():
		return null
	src[Mesh.ARRAY_COLOR] = marks
	var bones = src[Mesh.ARRAY_BONES]
	var eight: bool = bones != null and (bones as PackedInt32Array).size() == 8 * marks.size()
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if eight else 0)
	out.set_meta(HAND_LIGHT, light)
	return out


## Puts the hands' marks (hand_marks) in the skinned mesh of `body_root`, so a
## bake of it carries them (build_skinned keeps the vertex colours), and gives
## them back; empty without a skinned mesh.
static func mark_hands(body_root: Node3D) -> PackedColorArray:
	var marks := hand_marks(body_root)
	var mesh_node := first_of(body_root, "MeshInstance3D") as MeshInstance3D
	if marks.is_empty() or mesh_node == null:
		return PackedColorArray()
	var marked := with_hand_marks(mesh_node.mesh, marks, 0.0)
	if marked == null:
		return PackedColorArray()
	if mesh_node.mesh.surface_get_material(0) != null:
		marked.surface_set_material(0, mesh_node.mesh.surface_get_material(0))
	mesh_node.mesh = marked
	return marks


## The body's own colour picture, out of its material (null without one).
static func picture_of(body_root: Node3D) -> Image:
	for node in body_root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null:
				return (mat as BaseMaterial3D).albedo_texture.get_image()
	return null


## Bakes the living people's motions (PERSON_CLIPS, no still poses) with the
## motion set in `motion_root` for those that take one. The ones written here
## come out as bake_own makes them, so the numbers baked before stay the same.
static func bake_person(body_root: Node3D, motion_root: Node3D) -> Dictionary:
	var ctx := prepare(body_root, motion_root, PERSON_CLIPS, [])
	if ctx.is_empty():
		return {}
	ctx["sink_scale"] = _sink_scale(body_root, ctx["body"])
	return _bake_list(ctx, PERSON_CLIPS, [])


## Puts the motions of every other motion set in `roots` (same skeleton, all
## in the scene tree) on the first one's player, so one bake can read them all.
## Returns the first root; a motion the first already has is kept as it is.
static func merge_motions(roots: Array) -> Node3D:
	var first := roots[0] as Node3D
	var player := first_of(first, "AnimationPlayer") as AnimationPlayer
	var library := player.get_animation_library("")
	for n in range(1, roots.size()):
		var other := first_of(roots[n], "AnimationPlayer") as AnimationPlayer
		for motion: StringName in other.get_animation_list():
			if not player.has_animation(motion):
				library.add_animation(motion, other.get_animation(motion).duplicate())
	return first


## The share of its source motion a layer plays (1 without a span).
static func _span_share(layer: String) -> float:
	var span: Array = LAYERS.get(layer, {}).get("span", [0.0, 1.0])
	return float(span[1]) - float(span[0])


static func _bake_list(ctx: Dictionary, list: Array, poses: Array) -> Dictionary:
	var player: AnimationPlayer = ctx["player"]
	var mesh_node: MeshInstance3D = ctx["mesh_node"]
	var clips := []
	ctx["phase_fits"] = {}
	for entry: Array in list:
		_fit_person_stride(ctx, entry)
		var phase := _fit_person_phase(ctx, entry)
		var count: int = entry[2]
		var looped: bool = entry[3]
		var frames := []
		var reach := [[], []]
		for f in count:
			# A loop's last frame stops one step short of the first; a one-shot ends on its end.
			var u: float = float(f) / float(count) if looped else float(f) / float(count - 1)
			if not phase.is_empty():
				u = fposmod(u + float(phase["shift"]), 1.0)
			pose(ctx, entry[1], entry[4], u)
			frames.append(_skin_frame(ctx))
			_note_reach(ctx, entry[0], reach)
		var length := float(entry[5]) if entry[1] == "" else player.get_animation(entry[1]).length * _span_share(entry[4])
		var stride_round := float(phase["round"]) if not phase.is_empty() else _round(reach)
		clips.append({"name": entry[0], "loop": looped, "length": length, "frames": frames, "round": stride_round if looped else 0.0})
	var still := []
	for entry: Array in poses:
		_pose_at(ctx, entry[0], entry[1], {})
		apply_overlay(ctx["body"], entry[2])
		still.append(_skin_frame(ctx))
	if not still.is_empty():
		clips.append({"name": POSES_CLIP, "loop": false, "length": 1.0, "frames": still})
	return _with_rounds(VatBaker.build_skinned(mesh_node.mesh.surface_get_arrays(0), clips), clips)


## Bakes the body in `body_root` (in the scene tree) with the motions written
## here alone: `list` in order (OWN_CLIPS, or the living's that take nothing from a motion set),
## then one POSES_CLIP of `poses` when there are any. Nothing in the result
## comes from a motion set. {} if something is missing.
static func bake_own(body_root: Node3D, list: Array = OWN_CLIPS, poses: Array = OWN_POSES) -> Dictionary:
	var ctx := prepare_own(body_root, list + poses)
	if ctx.is_empty():
		return {}
	var mesh_node: MeshInstance3D = ctx["mesh_node"]
	var clips := []
	for entry: Array in list:
		var count: int = entry[2]
		var looped: bool = entry[3]
		var frames := []
		var reach := [[], []]
		for f in count:
			var u: float = float(f) / float(count) if looped else float(f) / float(count - 1)
			pose(ctx, "", entry[4], u)
			frames.append(_skin_frame(ctx))
			_note_reach(ctx, entry[0], reach)
		clips.append({"name": entry[0], "loop": looped, "length": float(entry[5]), "frames": frames, "round": _round(reach) if looped else 0.0})
	var still := []
	for entry: Array in poses:
		pose(ctx, "", entry[0], entry[1])
		apply_overlay(ctx["body"], entry[2])
		still.append(_skin_frame(ctx))
	if not still.is_empty():
		clips.append({"name": POSES_CLIP, "loop": false, "length": 1.0, "frames": still})
	return _with_rounds(VatBaker.build_skinned(mesh_node.mesh.surface_get_arrays(0), clips), clips)


## Notes where the two feet are (front to back) in the pose the body is in
## now: the spot of each sole that is under its ankle when the body stands at
## rest (the body's ground is y 0), carried by the foot bone. For the crawl it
## is the two hands, which are what pull it along.
static func _note_reach(ctx: Dictionary, clip: String, reach: Array) -> void:
	var body: Skeleton3D = ctx["body"]
	var to_mesh: Transform3D = ctx["to_mesh"]
	var crawls := clip == CRAWL_CLIP or clip == PERSON_CRAWL_CLIP
	var ends: Array = ["hand.L", "hand.R"] if crawls else ["foot.L", "foot.R"]
	for n in 2:
		var bone := _bone(body, ends[n])
		if bone < 0:
			continue
		var spot := Vector3.ZERO
		if not crawls:
			var rest := to_mesh * body.get_bone_global_rest(bone)
			spot = rest.affine_inverse() * Vector3(rest.origin.x, 0.0, rest.origin.z)
		reach[n].append((to_mesh * body.get_bone_global_pose(bone) * spot).z)


## How far one round of a looping motion should carry the body so that a foot
## going backwards stays on its spot: the middle of the two feet's rounds.
static func _round(reach: Array) -> float:
	var total := 0.0
	var sides := 0
	for side: Array in reach:
		var got := round_of(side)
		if got > ROUND_LEAST:
			total += got
			sides += 1
	return total / float(sides) if sides > 0 else 0.0


## The same for one foot, from where it is in each frame of the loop: its
## longest run going backwards, without the first and last sixth where it
## turns round; what it goes back in a frame there, times the frames. 0 if it
## never goes back.
static func round_of(zs: Array) -> float:
	var frames := zs.size()
	var best_from := 0
	var best_len := 0
	for from in frames:
		var n := 0
		while n < frames and float(zs[(from + n + 1) % frames]) < float(zs[(from + n) % frames]):
			n += 1
		if n > best_len:
			best_len = n
			best_from = from
	var skip := int(best_len / 6.0)
	var steps := best_len - skip * 2
	if steps <= 0:
		return 0.0
	var back := float(zs[(best_from + skip) % frames]) - float(zs[(best_from + best_len - skip) % frames])
	return back / float(steps) * float(frames)


## Puts each clip's round on what build_skinned returns (same order).
static func _with_rounds(out: Dictionary, clips: Array) -> Dictionary:
	if out.is_empty():
		return out
	for n in clips.size():
		out["clips"][n]["round"] = float(clips[n].get("round", 0.0))
	return out


const SMALL_FORMAT: String = "rgb8q"           # clips.json "format" of a compacted bake
const SMALL_DROPS: Array = ["hit"]             # the field never picks it: kept one frame so the numbers after it stay


## A smaller bake of the same motions for the phone (about a quarter): the
## still poses left out, a motion the field never picks cut to one frame, every
## other motion at half its frames (taken evenly, a one-shot keeping its last
## frame; the shader blends between frames anyway; a clip named in `keep_full`
## keeps every frame, for motions whose feet shake when halved), and each clip's offsets in
## 8 bits a channel inside that clip's own box, which clips.json carries as
## "lo" and "hi". The shader takes the box back (dead_vat.gdshader, quantized).
static func compact(assets: Dictionary, keep_full: Array = []) -> Dictionary:
	var image: Image = assets["image"]
	var width := image.get_width()
	var rows: int = int(assets["rows_per_frame"])
	var per_frame := width * rows
	var picked: Array = []
	var table: Array = []
	var start := 0
	for clip: Dictionary in assets["clips"]:
		if str(clip["name"]) == POSES_CLIP:
			continue
		var n: int = int(clip["frames"])
		var looped: bool = bool(clip["loop"])
		var spots := []
		if SMALL_DROPS.has(str(clip["name"])) or n < 2:
			spots = [0.0]
		elif keep_full.has(str(clip["name"])):
			for k in n:
				spots.append(float(k))
		elif looped:
			var m := maxi(1, n / 2)
			for k in m:
				spots.append(float(k) * float(n) / float(m))
		else:
			var m := ceili(float(n - 1) / 2.0) + 1
			for k in m:
				spots.append(float(k) * float(n - 1) / float(m - 1))
		var values := PackedVector3Array()
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for at: float in spots:
			var a := int(floor(at))
			var t := at - float(a)
			var b := (a + 1) % n if looped else mini(a + 1, n - 1)
			for i in per_frame:
				var x := i % width
				var y := i / width
				var ca := image.get_pixel(x, (int(clip["start"]) + a) * rows + y)
				var cb := image.get_pixel(x, (int(clip["start"]) + b) * rows + y)
				var v := Vector3(ca.r, ca.g, ca.b).lerp(Vector3(cb.r, cb.g, cb.b), t)
				values.append(v)
				lo = lo.min(v)
				hi = hi.max(v)
		picked.append([values, lo, hi])
		var row := clip.duplicate()
		row["start"] = start
		row["frames"] = spots.size()
		row["lo"] = [lo.x, lo.y, lo.z]
		row["hi"] = [hi.x, hi.y, hi.z]
		table.append(row)
		start += spots.size()
	var bytes := PackedByteArray()
	bytes.resize(start * per_frame * 3)
	var at_byte := 0
	for got: Array in picked:
		var lo: Vector3 = got[1]
		var span: Vector3 = (got[2] as Vector3) - lo
		for v: Vector3 in got[0]:
			for axis in 3:
				var s: float = span[axis]
				bytes[at_byte] = 0 if s <= 0.0 else clampi(roundi((v[axis] - lo[axis]) / s * 255.0), 0, 255)
				at_byte += 1
	var small := Image.create_from_data(width, start * rows, false, Image.FORMAT_RGB8, bytes)
	var out := assets.duplicate()
	out["image"] = small
	out["texture"] = ImageTexture.create_from_image(small)
	out["height"] = small.get_height()
	out["clips"] = table
	out["format"] = SMALL_FORMAT
	return out


## Writes vat.bin (the picture's half floats as they are: an exported game
## cannot read EXR; a compacted bake's bytes), mesh.res and clips.json into `dir`.
static func save(assets: Dictionary, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var image: Image = assets["image"]
	var raw := FileAccess.open(dir.path_join("vat.bin"), FileAccess.WRITE)
	if raw == null:
		push_error("body_bake: could not save vat.bin")
		return
	raw.store_buffer(image.get_data())
	raw.close()
	var err := ResourceSaver.save(assets["mesh"], dir.path_join("mesh.res"))
	if err != OK:
		push_error("body_bake: could not save mesh.res (" + error_string(err) + ")")
	var info := {"vertices": assets["vertices"], "width": image.get_width(), "height": image.get_height(), "rows_per_frame": assets["rows_per_frame"], "clips": assets["clips"]}
	if assets.has("format"):
		info["format"] = assets["format"]
	var file := FileAccess.open(dir.path_join("clips.json"), FileAccess.WRITE)
	if file == null:
		push_error("body_bake: could not save clips.json")
		return
	file.store_string(JSON.stringify(info, "\t"))


## Reads what save wrote, in the shape build_skinned returns; {} if any of the
## three is missing or the picture is not the size clips.json says.
static func load_baked(dir: String) -> Dictionary:
	var image_path := dir.path_join("vat.bin")
	var mesh_path := dir.path_join("mesh.res")
	var info_path := dir.path_join("clips.json")
	for path in [image_path, mesh_path, info_path]:
		if not FileAccess.file_exists(path):
			return {}
	var mesh := ResourceLoader.load(mesh_path, "", ResourceLoader.CACHE_MODE_IGNORE) as Mesh
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(info_path))
	if mesh == null or not info is Dictionary:
		return {}
	var width := int(info.get("width", 0))
	var height := int(info.get("height", 0))
	var data := FileAccess.get_file_as_bytes(image_path)
	# Three half floats a texel, or three bytes in a compacted bake.
	var small: bool = str(info.get("format", "")) == SMALL_FORMAT
	if width <= 0 or height <= 0 or data.size() != width * height * (3 if small else 6):
		return {}
	var image := Image.create_from_data(width, height, false, Image.FORMAT_RGB8 if small else Image.FORMAT_RGBH, data)
	var clips := []
	for clip: Dictionary in info["clips"]:
		var row := {"name": str(clip["name"]), "start": int(clip["start"]), "frames": int(clip["frames"]), "loop": bool(clip["loop"]), "length": float(clip["length"]), "round": float(clip.get("round", 0.0))}
		if small:
			row["lo"] = clip.get("lo", [0.0, 0.0, 0.0])
			row["hi"] = clip.get("hi", [0.0, 0.0, 0.0])
		clips.append(row)
	var out := {"mesh": mesh, "texture": ImageTexture.create_from_image(image), "vertices": int(info["vertices"]), "width": image.get_width(), "rows_per_frame": int(info["rows_per_frame"]), "height": image.get_height(), "image": image, "clips": clips}
	if small:
		out["format"] = SMALL_FORMAT
	return out
