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
# Bake-only opt-in. Empty this array to keep the original walk poses.
const PERSON_FOOT_LOCK: Array = ["p_walk", "p_walk_long", "p_walk_axe", "p_walk_pistol", "p_carry_big", "p_walk_hurt"]
const PERSON_FOOTLOCK_OVERLAP: float = 0.02
const PERSON_FOOTLOCK_STANCE_MIN: float = 0.53
const PERSON_FOOTLOCK_STANCE_MAX: float = 0.57
# Decision 534. Metres/radians, bake-only; no skeleton scale or rule changes.
const PERSON_WALK_PELVIS_YAW: float = 0.174533  # 10 degrees
const PERSON_WALK_CHEST_COUNTER: float = 0.20
const PERSON_WALK_HEEL_PITCH: float = 0.558505  # 32 degrees, toe up
const PERSON_WALK_TOE_PITCH: float = 0.872665   # 50 degrees, heel up
const PERSON_WALK_HEEL_END: float = 0.28
const PERSON_WALK_TOE_START: float = 0.55
const PERSON_WALK_SWING_LIFT: float = 0.07
const PERSON_WALK_FOOTPRINT_BACK: float = 0.08  # balance the ankle's heel/toe reach
const PERSON_WALK_KNEE_MIN: float = 0.069813   # 4 degrees, never straight/backward
const HIP_OVER_STAND_TOL_M: float = 0.0012  # solver tolerance only, not a gait-shape value (walk polish v2, decision 534)
const PERSON_WALK_MID_KNEE_MAX: float = 0.26179939  # 15 degrees
const PERSON_WALK_HEIGHT_SAMPLES: int = 256
const PERSON_WALK_HEIGHT_RADIUS: int = 2  # five cyclic neighbours, including self
const PERSON_WALK_HEIGHT_PASSES: int = 4
const PERSON_WALK_MEAN_MIN: float = 0.95  # minimum mean height relative to standing
const PERSON_WALK_MEAN_PASSES: int = PERSON_WALK_HEIGHT_SAMPLES + 1  # one saturation per sample
const PERSON_WALK_MEAN_EPSILON: float = 0.000000001  # numerical convergence in metres
const PERSON_WALK_REACH_MARGIN: float = 0.001  # one vertical millimetre below the ceiling
const PERSON_WALK_HEIGHT_INTERPOLATION_MARGIN: float = 0.00001  # 0.01 mm inside a ceiling knot
const PERSON_WALK_SOLVE_PASSES: int = 6  # legacy fixed-point pass count
# solver tolerance only, decision 534/442: 1 mm = 1/20 of 2 cm slip, 0.04 px.
# These are NOT the 1 um projection gate, outer joint convergence or 95% mean gate.
const PERSON_WALK_SKIN_TOL_M: float = 0.001
const PERSON_WALK_SKIN_HEIGHT_TOL_M: float = 0.0005
const PERSON_WALK_ANKLE_TOL_M: float = 0.001
const PERSON_WALK_JOINT_TARGET_TOL_M: float = 0.0001
const PERSON_WALK_JOINT_HEIGHT_TOL_M: float = 0.00005
# Paired IK evaluations, including rejected trials; shared work budgets stay fixed.
const PERSON_WALK_SKIN_EVALUATIONS: int = 2 * PERSON_WALK_SOLVE_PASSES
const PERSON_WALK_AITKEN_MIN: float = 0.25
const PERSON_WALK_AITKEN_MAX: float = 2.0
const PERSON_WALK_SKIN_STALL_TRIALS: int = 3
const PERSON_WALK_SKIN_PROGRESS: float = 0.000001  # dimensionless normalized residual
const PERSON_WALK_AITKEN_DENOM_M2: float = 0.00000000000001
const PERSON_WALK_SKIN_CYCLE_M: float = 0.0000001
const PERSON_WALK_CONTACT_EPSILON: float = 0.005
const PERSON_WALK_SAVED_SAMPLES: int = 32
const PERSON_WALK_PROJECT_SWEEPS: int = 512
const PERSON_WALK_PROJECT_EPSILON: float = 0.0000001
# One micrometre: 1/20000 of the 2 cm slip gate, below the 10 um inset.
# Dense skin and saved-frame gates still validate the accepted table.
const PERSON_WALK_PROJECT_FEASIBILITY_M: float = 0.000001
const PERSON_WALK_PROJECT_STALL_SWEEPS: int = 32
const PERSON_WALK_PROJECT_PROGRESS_M: float = 0.000000000001  # one picometre
const PERSON_WALK_JOINT_PASSES: int = 12
const PERSON_WALK_SEARCH_GEOMETRY: int = 4096
const PERSON_WALK_SEARCH_SKIN: int = 64
const PERSON_WALK_SEARCH_BEAM: int = 8
const PERSON_WALK_SEARCH_ROUNDS: int = 2
const PERSON_WALK_DENSE_SAMPLES: int = 1024
const PERSON_WALK_CENTER_LIMIT: float = 0.16
const PERSON_WALK_LIFT_MIN: float = 0.02
const PERSON_WALK_LIFT_MAX: float = 0.18
const PERSON_WALK_BUDGET_BOUNDS: int = 131072
const PERSON_WALK_BUDGET_CLIP_BOUNDS: int = 32768
const PERSON_WALK_BUDGET_IK: int = 16384
const PERSON_WALK_BUDGET_CLIP_IK: int = 4096
const PERSON_WALK_BUDGET_PROJECT: int = 1048576
const PERSON_WALK_BUDGET_PATHS: int = 128
const PERSON_WALK_BLOCK_PATHS: int = 24
const PERSON_PHASE_MAX_SECONDS: float = 0.05
const STAND_KNEE_TOLERANCE: float = 0.5  # degrees
const STAND_ANKLE_TOLERANCE: float = 0.001  # metres
const STAND_WIDTH_TOLERANCE: float = 0.005  # metres
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
		"steps": WALK_LEGS + [
			["turn", "spine", "x", [0.05, 0.015, 0.0, 2.0]],
			["turn", "chest", "y", [0.0, 0.12, 0.0]],
			["turn", "neck", "x", 0.04],
			["turn", "head", "y", [0.0, -0.05, 0.0]],
			["aim", "upper_arm.L", "forearm.L", [0.16, -1.0, [0.04, -0.3, 0.0]]],
			["aim", "forearm.L", "hand.L", [0.08, -1.0, [0.3, -0.28, 0.0]]],
			["aim", "upper_arm.R", "forearm.R", [-0.16, -1.0, [0.04, 0.3, 0.0]]],
			["aim", "forearm.R", "hand.R", [-0.08, -1.0, [0.3, 0.28, 0.0]]],
		],
		"sink": WALK_SINK,
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
	# UAL1 Idle_Loop crouches and staggers the feet. Keep its upper-body
	# pose, with relaxed, planted legs and a small upper-body breath.
	"p_stand": {
		"steps": [
			["stand_support", 4.0, 0.10],
			["turn", "spine", "x", [0.0, 0.012, 0.0]],
			["turn", "chest", "x", [0.0, -0.006, 0.0]],
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
		"steps": WALK_LEGS + [
			["turn", "spine", "x", [0.05, 0.015, 0.0, 2.0]],
			["turn", "chest", "y", [0.0, 0.04, 0.0]],
			["turn", "neck", "x", 0.04],
			["turn", "head", "y", [0.0, -0.05, 0.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.1, -1.0, [0.3, 0.015, 0.0]]],
			["aim", "forearm.R", "hand.R", [0.05, -0.35, 1.0]],
			["aim", "upper_arm.L", "forearm.L", [-0.3, -0.7, [0.6, 0.015, 0.0]]],
			["aim", "forearm.L", "hand.L", [-0.75, 0.45, 0.5]],
		],
		"sink": WALK_SINK,
	},
	# Walking with an axe hanging in the right hand (decision 422, second set): that arm
	# straight and hardly swinging under the weight, held a little out from the leg, the left swinging.
	"p_walk_axe": {
		"steps": WALK_LEGS + [
			["turn", "spine", "x", [0.05, 0.015, 0.0, 2.0]],
			["turn", "chest", "y", [0.0, 0.12, 0.0]],
			["turn", "neck", "x", 0.04],
			["turn", "head", "y", [0.0, -0.05, 0.0]],
			["aim", "upper_arm.L", "forearm.L", [0.16, -1.0, [0.04, -0.3, 0.0]]],
			["aim", "forearm.L", "hand.L", [0.08, -1.0, [0.3, -0.28, 0.0]]],
			["aim", "upper_arm.R", "forearm.R", [-0.22, -1.0, [0.02, 0.06, 0.0]]],
			["aim", "forearm.R", "hand.R", [-0.12, -1.0, [0.12, 0.05, 0.0]]],
		],
		"sink": WALK_SINK,
	},
	# Walking with a pistol hanging in the right hand, its muzzle down and forward
	# (decision 422, second set): the forearm a little back, that arm hardly swinging.
	"p_walk_pistol": {
		"steps": WALK_LEGS + [
			["turn", "spine", "x", [0.05, 0.015, 0.0, 2.0]],
			["turn", "chest", "y", [0.0, 0.12, 0.0]],
			["turn", "neck", "x", 0.04],
			["turn", "head", "y", [0.0, -0.05, 0.0]],
			["aim", "upper_arm.L", "forearm.L", [0.16, -1.0, [0.04, -0.3, 0.0]]],
			["aim", "forearm.L", "hand.L", [0.08, -1.0, [0.3, -0.28, 0.0]]],
			["aim", "upper_arm.R", "forearm.R", [-0.15, -1.0, [0.06, 0.08, 0.0]]],
			["aim", "forearm.R", "hand.R", [-0.06, -1.0, -0.45]],
		],
		"sink": WALK_SINK,
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


## Relax neutral standing legs without changing their lengths. Place each
## ankle half extra_width outward from its thigh, keep its rest height and foot orientation,
## and lower the pelvis to fit the requested knee bend. The two-link solve
## bends the knees forward (+Z); the spine and arms keep their rotations.
static func _relax_stand_support(body: Skeleton3D, knee_degrees: float, extra_width: float) -> Array[Dictionary]:
	var legs: Array[Dictionary] = []
	var drop := 0.0
	for side: String in ["L", "R"]:
		var thigh_name := "thigh." + side
		var shin_name := "shin." + side
		var foot_name := "foot." + side
		var thigh := body.get_bone_global_rest(_bone(body, thigh_name)).origin
		var knee := body.get_bone_global_rest(_bone(body, shin_name)).origin
		var foot := body.get_bone_global_rest(_bone(body, foot_name))
		var upper := thigh.distance_to(knee)
		var lower := knee.distance_to(foot.origin)
		var target := Vector3(thigh.x + extra_width * (0.5 if side == "L" else -0.5), foot.origin.y, foot.origin.z)
		var reach_squared := upper * upper + lower * lower + 2.0 * upper * lower * cos(deg_to_rad(knee_degrees))
		var across := target - thigh
		var height := sqrt(maxf(0.0, reach_squared - across.x * across.x - across.z * across.z))
		drop += thigh.y - target.y - height
		legs.append({"side": side, "thigh": thigh_name, "shin": shin_name, "foot": foot_name, "target": target, "upper": upper, "lower": lower, "foot_basis": foot.basis.orthonormalized()})
	# Both legs have matching lengths/heights in the fourteen living rigs.
	sink(body, drop * 0.5)
	for leg: Dictionary in legs:
		var start := body.get_bone_global_pose(_bone(body, leg["thigh"])).origin
		var target: Vector3 = leg["target"]
		var axis := (target - start).normalized()
		var distance := start.distance_to(target)
		if distance <= 0.000001 or not is_finite(distance):
			continue  # The post-solve checks below reject an unsolved leg.
		var upper: float = leg["upper"]
		var lower: float = leg["lower"]
		var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
		var bend := (Vector3.BACK - axis * axis.dot(Vector3.BACK)).normalized()
		var knee := start + axis * along + bend * sqrt(maxf(0.0, upper * upper - along * along))
		aim(body, leg["thigh"], leg["shin"], knee - start)
		var shin := body.get_bone_global_pose(_bone(body, leg["shin"])).origin
		aim(body, leg["shin"], leg["foot"], target - shin)
		var foot := _bone(body, leg["foot"])
		var parent_basis := body.get_bone_global_pose(body.get_bone_parent(foot)).basis.orthonormalized()
		body.set_bone_pose_rotation(foot, (parent_basis.inverse() * (leg["foot_basis"] as Basis)).get_rotation_quaternion())
	# Check the actual pose after BOTH solves. An averaged pelvis drop can
	# leave one asymmetric leg short of its target even when the other fits.
	var hip_width: float = absf(body.get_bone_global_pose(_bone(body, "thigh.L")).origin.x - body.get_bone_global_pose(_bone(body, "thigh.R")).origin.x)
	var ankle_width: float = absf(body.get_bone_global_pose(_bone(body, "foot.L")).origin.x - body.get_bone_global_pose(_bone(body, "foot.R")).origin.x)
	var width: float = ankle_width - hip_width
	var width_error: float = absf(width - extra_width) if is_finite(width) else INF
	var failures: Array[Dictionary] = []
	for leg: Dictionary in legs:
		var thigh: Vector3 = body.get_bone_global_pose(_bone(body, leg["thigh"])).origin
		var shin: Vector3 = body.get_bone_global_pose(_bone(body, leg["shin"])).origin
		var foot: Vector3 = body.get_bone_global_pose(_bone(body, leg["foot"])).origin
		var knee: float = rad_to_deg((shin - thigh).angle_to(foot - shin))
		var knee_error: float = absf(knee - knee_degrees) if is_finite(knee) else INF
		var ankle_error: float = foot.distance_to(leg["target"])
		if not is_finite(ankle_error):
			ankle_error = INF
		var axis: Vector3 = (foot - thigh).normalized()
		var knee_out: Vector3 = (shin - thigh) - axis * (shin - thigh).dot(axis)
		var forward: float = knee_out.dot(Vector3.BACK - axis * Vector3.BACK.dot(axis))
		if not is_finite(forward):
			forward = -INF
		if knee_error > STAND_KNEE_TOLERANCE or ankle_error > STAND_ANKLE_TOLERANCE or forward <= 0.0 or width_error > STAND_WIDTH_TOLERANCE:
			failures.append({"side": leg["side"], "knee": knee, "knee_target": knee_degrees, "knee_error": knee_error, "ankle_error": ankle_error, "forward": forward, "width": width, "width_target": extra_width, "width_error": width_error})
	return failures


## One failure slot per clip and leg, retaining each measurement's worst
## value across all samples (a later good frame cannot erase a failure).
static func _record_stand_failures(ctx: Dictionary, clip: String, samples: Array[Dictionary]) -> void:
	if samples.is_empty():
		return
	var records: Dictionary = ctx.get_or_add("stand_failures", {})
	var failures: Array = ctx.get_or_add("fit_failures", [])
	for sample: Dictionary in samples:
		var key: String = clip + ":" + String(sample["side"])
		if not records.has(key):
			var first: Dictionary = sample.duplicate()
			first["index"] = failures.size()
			records[key] = first
			failures.append("")
		var worst: Dictionary = records[key]
		if float(sample["knee_error"]) > float(worst["knee_error"]):
			worst["knee"] = sample["knee"]
			worst["knee_error"] = sample["knee_error"]
		if float(sample["width_error"]) > float(worst["width_error"]):
			worst["width"] = sample["width"]
			worst["width_error"] = sample["width_error"]
		worst["ankle_error"] = maxf(float(worst["ankle_error"]), float(sample["ankle_error"]))
		worst["forward"] = minf(float(worst["forward"]), float(sample["forward"]))
		failures[int(worst["index"])] = "STAND_UNFIT %s %s knee %.6f target %.6f error_deg %.6f ankle_error_m %.6f forward %.6f width_m %.6f target %.6f error_m %.6f" % [clip, sample["side"], worst["knee"], worst["knee_target"], worst["knee_error"], worst["ankle_error"], worst["forward"], worst["width"], worst["width_target"], worst["width_error"]]


## Hangs a layer on the body (after retarget), for progress u (0..1). The
## layers' sinks are metres for hips 1 m up; `sink_scale` is this body's hip
## height over that, so a shorter body is lowered as far in proportion.
static func apply_layer(body: Skeleton3D, layer: Dictionary, u: float, sink_scale: float = 1.0) -> Array[Dictionary]:
	var w := TAU * u
	var failures: Array[Dictionary] = []
	for step: Array in layer.get("steps", []):
		match step[0]:
			"stand_support":
				# Only p_stand uses this layer. The rig's neutral legs are straight
				# and its sole vertices already sit at y=0. Reset pelvis travel as
				# well as rotation, so breathing cannot slide the planted feet.
				# Spine/chest/head retain the source animation's local rotations.
				for bone_name: String in ["hips", "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R"]:
					var bone := _bone(body, bone_name)
					var rest := body.get_bone_rest(bone)
					body.set_bone_pose_position(bone, rest.origin)
					body.set_bone_pose_rotation(bone, rest.basis.get_rotation_quaternion())
				failures.append_array(_relax_stand_support(body, float(step[1]), float(step[2])))
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
	return failures


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
static func pose(ctx: Dictionary, clip: String, layer: String, u: float, report_clip: String = "") -> void:
	var spec: Dictionary = LAYERS.get(layer, {})
	var at := u
	if spec.has("warp"):
		var warp: Array = spec["warp"]
		at = fposmod(u + float(warp[0]) * sin(TAU * u - float(warp[1])), 1.0)
	if spec.has("span"):
		var span: Array = spec["span"]
		at = lerpf(float(span[0]), float(span[1]), at)
	_pose_at(ctx, clip, at, spec.get("damp", {}))
	var failures: Array[Dictionary] = apply_layer(ctx["body"], spec, u, float(ctx.get("sink_scale", 1.0)))
	_record_stand_failures(ctx, layer if report_clip.is_empty() else report_clip, failures)
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


## Where each foot is over a round, on the fine grid (PERSON_PHASE_SAMPLES). A round
## measured on the bake's own few frames moves with where they fall in the loop
## (up to 5 % on a run at 24 frames); on this grid it is the motion's own.
static func _person_stride_reach(ctx: Dictionary, entry: Array, shift: float = 0.0) -> Array:
	var reach := [[], []]
	for f in PERSON_PHASE_SAMPLES:
		pose(ctx, entry[1], entry[4], fposmod(float(f) / float(PERSON_PHASE_SAMPLES) + shift, 1.0), entry[0])
		_note_reach(ctx, entry[0], reach)
	return reach


static func _person_stride_round(ctx: Dictionary, entry: Array, shift: float = 0.0) -> float:
	return _round(_person_stride_reach(ctx, entry, shift))


## A new fit for this body and this clip, including motions retargeted from
## a source in future. The sampler and the saved round use the same fine grid.
static func _fit_person_stride(ctx: Dictionary, entry: Array, shift: float = 0.0) -> void:
	var name: String = entry[0]
	var layer: String = entry[4]
	var fits: Dictionary = ctx.get("stride_fits", {})
	ctx["stride_fits"] = fits
	# A clip outside the table that shares a fitted layer must not inherit its legs.
	fits.erase(layer)
	if not PERSON_STRIDE_ROUNDS.has(name):
		return
	var body: Skeleton3D = ctx["body"]
	var bones := []
	var samples := []
	for bone_name: String in PERSON_STRIDE_BONES:
		bones.append(_bone(body, bone_name))
		samples.append([])
	var reach := [[], []]
	for f in PERSON_PHASE_SAMPLES:
		pose(ctx, entry[1], layer, fposmod(float(f) / float(PERSON_PHASE_SAMPLES) + shift, 1.0), name)
		_note_reach(ctx, name, reach)
		for n in bones.size():
			samples[n].append(body.get_bone_pose_rotation(bones[n]))
	var before := _round(reach)
	var target: float = PERSON_STRIDE_ROUNDS[name]
	if before <= 0.0:
		print("STRIDE_STOP %s %.6f inf" % [name, before])
		ctx.get_or_add("fit_failures", []).append("STRIDE_STOP " + name)
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
			ctx.get_or_add("fit_failures", []).append("STRIDE_STOP " + name)
			return
		fit["scale"] = needed
		measured = _person_stride_round(ctx, entry, shift)
		if absf(measured - target) <= target * STRIDE_TOLERANCE:
			break
	var status := "STRIDE" if absf(measured - target) <= target * STRIDE_TOLERANCE else "STRIDE_UNFIT"
	print("%s %s round %.6f -> %.6f scale %.6f" % [status, name, before, measured, fit["scale"]])
	if status == "STRIDE_UNFIT":
		ctx.get_or_add("fit_failures", []).append("STRIDE_UNFIT " + name)


## Walk uses locked saved skin frames; other clips use fine-grid leg samples.
## Never substitute a rule target for the measurement.
static func _check_person_stride_final(ctx: Dictionary, name: String, reach: Array, fit: Dictionary = {}) -> float:
	var sides: Array = _person_walk_saved_rounds(fit, reach) if not fit.is_empty() else [round_of(reach[0]), round_of(reach[1])]
	var measured: float = (float(sides[0]) + float(sides[1])) * 0.5 if not fit.is_empty() else _round(reach)
	if PERSON_STRIDE_ROUNDS.has(name):
		var target: float = PERSON_STRIDE_ROUNDS[name]
		var failures: Array = ctx.get_or_add("fit_failures", [])
		if not is_finite(measured) or absf(measured - target) > target * STRIDE_TOLERANCE:
			var failure: String = "STRIDE_FINAL %s round %.6f target %.6f relative_error %.6f limit %.6f" % [name, measured, target, absf(measured - target) / target, STRIDE_TOLERANCE]
			failures.append(failure)
			print(failure)
		# The mean leaves out a foot that never goes back; both must.
		var left: float = sides[0]
		var right: float = sides[1]
		if left <= ROUND_LEAST or right <= ROUND_LEAST:
			var one_foot: String = "STRIDE_FINAL %s one_foot left %.6f right %.6f" % [name, left, right]
			failures.append(one_foot)
			print(one_foot)
	return measured


## Least-squares stance slope from saved skin frames, unwrapped at touchdown.
static func _person_walk_saved_rounds(fit: Dictionary, frames: Array) -> Array:
	var samples: Array = [[], []]
	for frame in frames.size():
		var u: float = float(frame) / float(frames.size())
		var probes: Array = _person_footlock_probes(fit, frames[frame])
		for side in 2:
			var age: float = fposmod(u - float(fit["starts"][side]), 1.0)
			if age <= float(fit["durations"][side]):
				var probe: Dictionary = probes[side]
				var point: Vector3 = probe["point"]
				var rest: Vector3 = probe["rest"]
				samples[side].append(Vector2(age, point.z - rest.z))
	var rounds: Array = []
	for side in 2:
		var rows: Array = samples[side]
		if rows.size() < 2:
			rounds.append(0.0)
			continue
		var mean: Vector2 = Vector2.ZERO
		for row: Vector2 in rows:
			mean += row
		mean /= float(rows.size())
		var cross: float = 0.0
		var variance: float = 0.0
		for row: Vector2 in rows:
			cross += (row.x - mean.x) * (row.y - mean.y)
			variance += (row.x - mean.x) * (row.x - mean.x)
		rounds.append(-cross / variance if variance > 0.0 else 0.0)
	return rounds


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
## A sample may hold one height per sole vertex (PackedFloat32Array): the shader
## moves each vertex on its own straight line between frames, so the entry is the
## first vertex's own crossing, not that of the two frames' lowest points joined.
static func person_contact_phase(heights: Array) -> float:
	if heights.size() < 2:
		return -1.0
	var lows: Array[float] = []
	for sample: Variant in heights:
		var low := _lowest_sole_height(sample)
		if not is_finite(low):
			return -1.0
		lows.append(low)
	var threshold := float(lows.min()) + PERSON_CONTACT_HEIGHT
	for f in lows.size():
		var p := (f + lows.size() - 1) % lows.size()
		var previous := lows[p]
		var current := lows[f]
		if previous > threshold and current <= threshold:
			var fraction := (previous - threshold) / (previous - current)
			if typeof(heights[f]) == TYPE_PACKED_FLOAT32_ARRAY:
				var before: PackedFloat32Array = heights[p]
				var after: PackedFloat32Array = heights[f]
				fraction = 1.0
				for v in after.size():
					if after[v] <= threshold and before[v] > threshold:
						fraction = minf(fraction, (before[v] - threshold) / (before[v] - after[v]))
			return fposmod((float(f - 1) + fraction) / float(lows.size()), 1.0)
	return -1.0


## First upward exit from the lowest centimetre, including the loop seam.
## Use final output-frame heights; -1 means the foot never leaves the band.
static func person_step_off_phase(heights: Array) -> float:
	if heights.size() < 2:
		return -1.0
	var threshold := float(heights.min()) + PERSON_CONTACT_HEIGHT
	for f in heights.size():
		var previous := float(heights[(f + heights.size() - 1) % heights.size()])
		var current := float(heights[f])
		if previous <= threshold and current > threshold:
			var fraction := (threshold - previous) / (current - previous)
			return fposmod((float(f - 1) + fraction) / float(heights.size()), 1.0)
	return -1.0


## Measure the same body soles as contact, after phase shift and foot locking.
## Shells retain the body source, so a hem cannot become a foot probe.
static func _person_step_off(ctx: Dictionary, frames: Array) -> Array:
	var mesh_node: MeshInstance3D = ctx["mesh_node"]
	var source: Array = mesh_node.get_meta(PERSON_PHASE_SOURCE) if mesh_node.has_meta(PERSON_PHASE_SOURCE) else mesh_node.mesh.surface_get_arrays(0)
	var rest: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = source[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = source[Mesh.ARRAY_WEIGHTS]
	if rest.is_empty() or bones.is_empty() or weights.size() != bones.size():
		return [-1.0, -1.0]
	var soles := person_sole_vertices(rest)
	var per: int = bones.size() / rest.size()
	var result := []
	for side in 2:
		var heights := []
		if not soles[side].is_empty():
			for skin: Array in frames:
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
				heights.append(lowest)
		result.append(person_step_off_phase(heights))
	return result


static func _lowest_sole_height(sample: Variant) -> float:
	if typeof(sample) != TYPE_PACKED_FLOAT32_ARRAY:
		return float(sample)
	var values: PackedFloat32Array = sample
	var low := INF
	for height: float in values:
		if not is_finite(height):
			return NAN
		low = minf(low, height)
	return low


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
	var frames: Array = []
	for f in PERSON_PHASE_SAMPLES:
		pose(ctx, entry[1], entry[4], float(f) / float(PERSON_PHASE_SAMPLES))
		frames.append(_skin_frame(ctx))
	return _person_sole_heights_from_frames(ctx, frames)


## Reuse the same fixed body soles and skinning for the fit and final check.
## With a shell, frames still transform the original body's saved source skin.
## per_vertex keeps every sole vertex's height (for the few saved frames).
static func _person_sole_heights_from_frames(ctx: Dictionary, frames: Array, per_vertex: bool = false) -> Array:
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
	for skin: Array in frames:
		for side in 2:
			var lowest := INF
			var each := PackedFloat32Array()
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
				each.append(point.y)
			if per_vertex:
				heights[side].append(each)
			else:
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
		ctx.get_or_add("fit_failures", []).append("PHASE_STOP " + name)
	else:
		print("PHASE %s %.6f %.6f shift %.6f" % [name, fposmod(float(fit["left"]) - shift, 1.0), fposmod(float(fit["right"]) - shift, 1.0), shift])
	return {"shift": shift}


## Match the baked-sole test: both feet must enter the ground band. Runs
## enforce the better foot order's maximum circular error; walks report it.
static func _check_person_phase_final(ctx: Dictionary, name: String, heights: Array) -> void:
	if not PERSON_PHASE_BASE.has(name):
		return
	var left: float = person_contact_phase(heights[0])
	var right: float = person_contact_phase(heights[1])
	var failures: Array = ctx.get_or_add("fit_failures", [])
	if left < 0.0 or right < 0.0:
		var failure: String = "PHASE_FINAL %s no_sole_contact left %.6f right %.6f" % [name, left, right]
		failures.append(failure)
		print(failure)
		return
	var least: float = INF
	for order in 2:
		var left_gap: float = absf(left - float(PERSON_STEP_AT[order]))
		var right_gap: float = absf(right - float(PERSON_STEP_AT[1 - order]))
		var worst: float = maxf(minf(left_gap, 1.0 - left_gap), minf(right_gap, 1.0 - right_gap))
		least = minf(least, worst)
	var base: String = PERSON_PHASE_BASE[name]
	var period: float = float(PERSON_STRIDE_ROUNDS[base]) / (3.9 if base == "p_run" else 2.1)
	var seconds: float = least * period
	var report: String = "%s final left %.6f right %.6f max_error_ms %.6f period_s %.6f" % [name, left, right, seconds * 1000.0, period]
	print("PHASE " + report + (" walk_report_only" if base == "p_walk" else " run_limit_ms 50.000"))
	if base == "p_run" and seconds > PERSON_PHASE_MAX_SECONDS:
		failures.append("PHASE_FINAL " + report + " limit_ms 50.000")


## Average one shared support set in current/rest x/z. During local solving
## that set is frozen; y always remains the minimum of the entire sole.
static func _person_footlock_probes(fit: Dictionary, skin: Array, support_sets: Array = []) -> Array:
	var rest: PackedVector3Array = fit["rest"]
	var bones: PackedInt32Array = fit["bones"]
	var weights: PackedFloat32Array = fit["weights"]
	var per: int = fit["per"]
	var points := []
	for side in 2:
		var moved := []
		var lowest := INF
		var lowest_vertex: int = -1
		for vertex: int in fit["soles"][side]:
			var point := Vector3.ZERO
			var total := 0.0
			for slot in per:
				var weight := weights[vertex * per + slot]
				if weight > 0.0:
					point += ((skin[bones[vertex * per + slot]] as Transform3D) * rest[vertex]) * weight
					total += weight
			point = point / total if total > 0.0 else rest[vertex]
			moved.append(point)
			if point.y < lowest:
				lowest_vertex = vertex
			lowest = minf(lowest, point.y)
		var centre := Vector3.ZERO
		var reference := Vector3.ZERO
		var count := 0
		var vertices: PackedInt32Array = PackedInt32Array()
		var sole_height_offsets: Dictionary = {}
		for index in moved.size():
			var point: Vector3 = moved[index]
			sole_height_offsets[int(fit["soles"][side][index])] = point.y - lowest
			var selected: bool = support_sets[side].has(int(fit["soles"][side][index])) if support_sets.size() == 2 else point.y <= lowest + PERSON_SOLE_EPSILON
			if selected:
				centre += point
				reference += rest[fit["soles"][side][index]]
				count += 1
				vertices.append(int(fit["soles"][side][index]))
		centre /= float(count)
		centre.y = lowest
		points.append({"point": centre, "rest": reference / float(count), "vertices": vertices, "lowest_vertex": lowest_vertex,
			"sole_height_offsets_m": sole_height_offsets})
	return points


## Read-only measurement: actual weighted sole vertices, never F(target)-target.
static func _person_walk_physical_error(fit: Dictionary, skin: Array, goals: Array, hips_y: float, wanted_h: float) -> Dictionary:
	var invalid: Dictionary = {"valid": false, "sides": [], "max_abs_m": INF, "height_abs_m": INF}
	var rest: PackedVector3Array = fit.get("rest", PackedVector3Array())
	var bones: PackedInt32Array = fit.get("bones", PackedInt32Array())
	var weights: PackedFloat32Array = fit.get("weights", PackedFloat32Array())
	var soles: Array = fit.get("soles", [])
	var per: int = int(fit.get("per", 0))
	var floor_y: float = float(fit.get("floor", INF))
	if rest.is_empty() or per <= 0 or soles.size() != 2 or goals.size() != 2 or bones.size() != rest.size() * per or weights.size() != bones.size():
		return invalid
	if not is_finite(hips_y) or not is_finite(wanted_h) or not is_finite(floor_y):
		return invalid
	var sides: Array = []
	var maximum: float = 0.0
	for side in 2:
		var lowest: float = INF
		for vertex: int in soles[side]:
			if vertex < 0 or vertex >= rest.size():
				return invalid
			var point: Vector3 = Vector3.ZERO
			var total: float = 0.0
			for slot in per:
				var index: int = vertex * per + slot
				var weight: float = weights[index]
				if not is_finite(weight) or weight < 0.0:
					return invalid
				if weight > 0.0:
					if bones[index] < 0 or bones[index] >= skin.size():
						return invalid
					point += ((skin[bones[index]] as Transform3D) * rest[vertex]) * weight
					total += weight
			point = point / total if total > 0.0 else rest[vertex]
			if not point.is_finite():
				return invalid
			lowest = minf(lowest, point.y)
		var target_y: float = floor_y + (goals[side].get("path", Vector3(INF, INF, INF)) as Vector3).y
		if not is_finite(lowest) or not is_finite(target_y):
			return invalid
		var error: float = lowest - target_y
		sides.append({"lowest_y": lowest, "target_y": target_y, "signed_m": error, "abs_m": absf(error)})
		maximum = maxf(maximum, absf(error))
	return {"valid": true, "sides": sides, "max_abs_m": maximum, "height_abs_m": absf(hips_y - wanted_h)}


## Observation belongs to ctx, outside fit/caches/budget and all solve decisions.
static func _person_walk_observe(ctx: Dictionary, fit: Dictionary, u: float, event: String, detail: Dictionary = {}) -> void:
	var note: Dictionary = ctx.get_or_add("walk_observation", {"actual_pairs": 0, "outside_pairs": 0})
	var budget: Dictionary = fit.get("work_budget", {})
	var stage: String = str(budget.get("active_stage", "search")) if not budget.is_empty() else "outside"
	var clip: String = str(ctx.get("walk_clip", "unknown"))
	if event == "attempt":
		note["last_attempt"] = {"rig": ctx.get("rig_label", "unknown"), "clip": clip, "phase": u, "stage": stage,
			"candidate": note.get("candidate", 0), "skin_count": note.get("skin_count", 0), "evaluated": false}
	elif event == "pair":
		note["actual_pairs"] = int(note.get("actual_pairs", 0)) + 1
		note["outside_pairs"] = int(note.get("outside_pairs", 0)) + (1 if budget.is_empty() else 0)
		note["last_attempt"]["evaluated"] = true
		note["last_evaluated"] = (note["last_attempt"] as Dictionary).duplicate(true)
		var by_clip: Dictionary = note.get_or_add("pair_stage_clips", {}).get_or_add(stage, {})
		by_clip[clip] = int(by_clip.get(clip, 0)) + 1
	elif event == "frame":
		var frame: Dictionary = {"rig": ctx.get("rig_label", "unknown"), "clip": clip, "phase": u, "stage": stage,
			"candidate": note.get("candidate", 0), "reason": detail.get("reason", ""), "evaluated": detail.get("evaluated", false), "suspended": detail.has("continuation")}
		note["last_frame"] = frame
		if not str(frame["reason"]).is_empty() and not bool(frame["suspended"]) and not note.has("first_failure"):
			note["first_failure"] = frame.duplicate(true)
		if bool(frame["evaluated"]):
			var goals: Array = [_person_walk_ankle_goal_uncached(fit, 0, u), _person_walk_ankle_goal_uncached(fit, 1, u)]
			var physical: Dictionary = _person_walk_physical_error(fit, _skin_frame(ctx), goals, float(detail["final_hips_y"]), float(detail.get("table_height", INF)))
			note["last_physical"] = physical
			if bool(physical["valid"]):
				note["max_physical_m"] = maxf(float(note.get("max_physical_m", 0.0)), float(physical["max_abs_m"]))
				note["max_height_m"] = maxf(float(note.get("max_height_m", 0.0)), float(physical["height_abs_m"]))


static func _person_footlock_points(fit: Dictionary, skin: Array) -> Array:
	var points := []
	for probe: Dictionary in _person_footlock_probes(fit, skin):
		points.append(probe["point"])
	return points


## Rotation in skeleton space; only this foot's local rotation is written.
static func _person_footlock_rotation(body: Skeleton3D, foot: int, rotation: Quaternion) -> void:
	var parent := body.get_bone_parent(foot)
	var parent_rot := body.get_bone_global_pose(parent).basis.orthonormalized().get_rotation_quaternion() if parent >= 0 else Quaternion()
	body.set_bone_pose_rotation(foot, (parent_rot.inverse() * rotation).normalized())


## z travel, sole lift, foot pitch. The flat footprint is stationary in world
## space during stance. Swing is Hermite with the same endpoint velocity;
## both position and velocity join at toe-off, touchdown and the loop seam.
static func _person_walk_path(age: float, duration: float, stride: float, params: Dictionary = {}) -> Vector3:
	if age <= duration:
		var t := age / duration
		var pitch: float = -PERSON_WALK_HEEL_PITCH * (1.0 - smoothstep(0.0, float(params.get("heel_end", PERSON_WALK_HEEL_END)), t))
		pitch += PERSON_WALK_TOE_PITCH * smoothstep(float(params.get("toe_start", PERSON_WALK_TOE_START)), 1.0, t)
		return Vector3(stride * (duration * 0.5 - age), 0.0, pitch)
	var t := (age - duration) / (1.0 - duration)
	var h := t * t * (3.0 - 2.0 * t)
	var z := stride * duration * (h - 0.5) - stride * (1.0 - duration) * (2.0 * t * t * t - 3.0 * t * t + t)
	return Vector3(z, float(params.get("swing_lift", PERSON_WALK_SWING_LIFT)) * pow(sin(PI * t), 2.0), lerpf(PERSON_WALK_TOE_PITCH, -PERSON_WALK_HEEL_PITCH, h))


## Rotation only, also used while fitting the canonical p_walk height table.
## The advancing hip turns forward; the chest counter-turn carries the arms.
static func _apply_person_walk_turn(ctx: Dictionary, fit: Dictionary, u: float, keyed_u: float, layer: String) -> void:
	var body: Skeleton3D = ctx["body"]
	var age := fposmod(u - float(fit["starts"][0]), 1.0)
	var gap := fposmod(float(fit["starts"][1]) - float(fit["starts"][0]), 1.0)
	var half := age / gap if age < gap else (age - gap) / (1.0 - gap)
	var yaw := -PERSON_WALK_PELVIS_YAW * cos(PI * half) * (1.0 if age < gap else -1.0)
	var old_yaw := _value(WALK_LEGS[1][3], TAU * keyed_u)
	turn(body, "hips", yaw - old_yaw, Vector3.UP)
	var old_chest := 0.0
	for step: Array in LAYERS[layer].get("steps", []):
		if step[0] == "turn" and step[1] == "chest" and step[2] == "y":
			old_chest += _value(step[3], TAU * keyed_u)
	turn(body, "chest", -yaw * (1.0 + PERSON_WALK_CHEST_COUNTER) - old_chest, Vector3.UP)


## The lowest rotated REST sole point rolls about its own flat footprint.
## Both the height solver and IK start from this same mesh-space ankle goal.
static func _person_walk_ankle_goal(fit: Dictionary, side: int, u: float) -> Dictionary:
	if fit.has("goal_cache"):
		var cache: Dictionary = fit["goal_cache"].get_or_add(side, {})
		if not cache.has(u):
			cache[u] = _person_walk_ankle_goal_uncached(fit, side, u)
		return cache[u]
	return _person_walk_ankle_goal_uncached(fit, side, u)


static func _person_walk_ankle_goal_uncached(fit: Dictionary, side: int, u: float) -> Dictionary:
	var age: float = fposmod(u - float(fit["starts"][side]), 1.0)
	var params: Dictionary = fit.get("path_params", {})
	var path_params: Dictionary = {"swing_lift": float(params.get("lifts", [PERSON_WALK_SWING_LIFT, PERSON_WALK_SWING_LIFT])[side]),
		"heel_end": float(params.get("heel_end", PERSON_WALK_HEEL_END)), "toe_start": float(params.get("toe_start", PERSON_WALK_TOE_START))}
	var path: Vector3 = _person_walk_path(age, float(fit["durations"][side]), float(fit["round"]), path_params)
	var rest: PackedVector3Array = fit["rest"]
	var ankle: Vector3 = fit["rest_ankles"][side]
	var flat: Basis = fit["rotations"][side]
	var roll: Basis = Basis(Vector3.RIGHT, path.z)
	var lowest: float = INF
	for vertex: int in fit["soles"][side]:
		var offset: Vector3 = roll * (rest[vertex] - ankle)
		lowest = minf(lowest, offset.y)
	var offset_sum: Vector3 = Vector3.ZERO
	var reference: Vector3 = Vector3.ZERO
	var count: int = 0
	for vertex: int in fit["soles"][side]:
		var offset: Vector3 = roll * (rest[vertex] - ankle)
		if offset.y <= lowest + PERSON_SOLE_EPSILON:
			offset_sum += offset
			reference += rest[vertex] - ankle
			count += 1
	var target: Vector3 = fit["anchors"][side]
	target += reference / float(count) - offset_sum / float(count)
	target.z += path.x
	target.y = float(fit["floor"]) + path.y - lowest
	var base: Vector3 = fit["anchors"][side]
	base.z += path.x
	return {"target": target, "rotation": roll * flat, "base": base, "path": path, "age": age}


## Bounds on absolute hips y in mesh space, AFTER the pelvis rotation.
## R(theta)^2 = thigh^2 + shin^2 + 2*thigh*shin*cos(theta).
## With thigh = hips + offset, y = ankle.y - offset.y + sqrt(R^2 - dxz^2).
## Swing legs constrain the ceiling too; scheduled mid-stance never tests contact.
static func _person_walk_height_bounds(ctx: Dictionary, fit: Dictionary, u: float, targets: Array = []) -> Dictionary:
	return _person_walk_bounds_from_geometry(fit, u, targets, _person_walk_geometry(ctx, fit))


static func _person_walk_geometry(ctx: Dictionary, fit: Dictionary) -> Dictionary:
	var body: Skeleton3D = ctx["body"]
	var to_mesh: Transform3D = ctx["to_mesh"]
	var hips: Vector3 = to_mesh * body.get_bone_global_pose(_bone(body, "hips")).origin
	var legs: Array = []
	for leg: Array in fit["legs"]:
		var thigh: Vector3 = to_mesh * body.get_bone_global_pose(int(leg[0])).origin
		var shin: Vector3 = to_mesh * body.get_bone_global_pose(int(leg[1])).origin
		var foot: Vector3 = to_mesh * body.get_bone_global_pose(int(leg[2])).origin
		legs.append({"thigh": thigh, "a": thigh.distance_to(shin), "b": shin.distance_to(foot)})
	return {"hips": hips, "legs": legs}


static func _person_walk_bounds_from_geometry(fit: Dictionary, u: float, targets: Array, geometry: Dictionary) -> Dictionary:
	var hips: Vector3 = geometry["hips"]
	var upper: float = _person_walk_stand_cap(fit)
	var lower: float = -INF
	var horizontal_miss: bool = false
	var upper_side: int = -1
	var lower_side: int = -1
	var per_side: Array = []
	for side in 2:
		var thigh: Vector3 = geometry["legs"][side]["thigh"]
		var a: float = geometry["legs"][side]["a"]
		var b: float = geometry["legs"][side]["b"]
		var target: Vector3 = targets[side] if targets.size() == 2 else _person_walk_ankle_goal(fit, side, u)["target"]
		var offset: Vector3 = thigh - hips
		var horizontal: float = Vector2(thigh.x - target.x, thigh.z - target.z).length_squared()
		var reach_squared: float = a * a + b * b + 2.0 * a * b * cos(PERSON_WALK_KNEE_MIN)
		var base_y: float = target.y - offset.y
		var invalid: bool = minf(a, b) < 0.000001 or horizontal > reach_squared
		var candidate_upper: float = -INF
		var candidate_lower: float = base_y
		var reason: String = ""
		if invalid:
			horizontal_miss = true
			reason = "DEGENERATE_LEG" if minf(a, b) < 0.000001 else "HORIZONTAL_REACH"
		else:
			candidate_upper = base_y + sqrt(reach_squared - horizontal) - PERSON_WALK_REACH_MARGIN
			# Positive vertical branch, including the internal reach sphere.
			var minimum: float = maxf(absf(a - b), 0.000001)
			if horizontal < minimum * minimum:
				candidate_lower += sqrt(minimum * minimum - horizontal) + 0.000001
		if candidate_upper < upper:
			upper = candidate_upper
			upper_side = side
		var age: float = fposmod(u - float(fit["starts"][side]), 1.0)
		var mid: float = age / float(fit["durations"][side])
		if not invalid and mid >= 0.40 and mid <= 0.60:
			var mid_squared: float = a * a + b * b + 2.0 * a * b * cos(PERSON_WALK_MID_KNEE_MAX)
			if mid_squared > horizontal:
				candidate_lower = maxf(candidate_lower, base_y + sqrt(mid_squared - horizontal))
		if candidate_lower > lower:
			lower = candidate_lower
			lower_side = side
		var forbidden: Vector2 = Vector2(INF, -INF)
		if not invalid and mid >= 0.40 and mid <= 0.60:
			var vertical: float = maxf(0.0, _person_walk_stand_cap(fit) - base_y)
			var radius_squared: float = a * a + b * b + 2.0 * a * b * cos(PERSON_WALK_MID_KNEE_MAX)
			var dz_squared: float = radius_squared - vertical * vertical - pow(thigh.x - target.x, 2.0)
			if dz_squared > 0.0:
				var center: float = float(_person_walk_default_params(fit)["centers"][side]) + thigh.z - target.z
				forbidden = Vector2(center - sqrt(dz_squared), center + sqrt(dz_squared))
		per_side.append({"lower": candidate_lower, "upper": candidate_upper, "target": target, "reason": reason, "forbidden_center": forbidden})
	return {"upper": upper, "lower": lower, "empty": horizontal_miss or lower > upper, "per_side": per_side,
		"horizontal_miss": horizontal_miss, "upper_side": upper_side, "lower_side": lower_side}


static func _person_walk_stand_cap(fit: Dictionary) -> float:
	return float(fit["rest_hips_y"]) + (HIP_OVER_STAND_TOL_M if bool(fit.get("hip_over_stand_allowed", true)) else 0.0)


## Subtract every mid-stance forbidden interval, preserving both branches.
static func _person_walk_center_intersection(intervals: Array, forbidden: Vector2) -> Array:
	var kept: Array = []
	for interval: Vector2 in intervals:
		if forbidden.x >= interval.y or forbidden.y <= interval.x:
			kept.append(interval)
		else:
			if forbidden.x > interval.x:
				kept.append(Vector2(interval.x, forbidden.x))
			if forbidden.y < interval.y:
				kept.append(Vector2(forbidden.y, interval.y))
	return kept


## Raise the mean without exceeding any ceiling. Every pass saturates a
## ceiling or reaches the target, so the sample count bounds the loop.
static func _person_walk_raise_mean(values: PackedFloat64Array, ceilings: PackedFloat64Array, target: float) -> Dictionary:
	var raised: PackedFloat64Array = values.duplicate()
	if raised.is_empty() or raised.size() != ceilings.size():
		return {"values": raised, "mean": 0.0, "feasible": false}
	var mean: float = 0.0
	for _pass_id in PERSON_WALK_MEAN_PASSES:
		var total: float = 0.0
		var available: int = 0
		for sample in raised.size():
			total += raised[sample]
			if ceilings[sample] - raised[sample] > PERSON_WALK_MEAN_EPSILON:
				available += 1
		mean = total / float(raised.size())
		var deficit: float = (target - mean) * float(raised.size())
		if deficit <= PERSON_WALK_MEAN_EPSILON * float(raised.size()) or available == 0:
			break
		var increment: float = deficit / float(available)
		for sample in raised.size():
			if ceilings[sample] - raised[sample] > PERSON_WALK_MEAN_EPSILON:
				raised[sample] = minf(ceilings[sample], raised[sample] + increment)
	return {"values": raised, "mean": mean, "feasible": mean + PERSON_WALK_MEAN_EPSILON >= target}


## Sparse periodic cubic B-spline weights, equivalent to the stored Hermite table.
static func _person_walk_height_weights(u: float, count: int) -> Dictionary:
	var position: float = fposmod(u, 1.0) * float(count)
	var index: int = int(floor(position))
	var t: float = position - float(index)
	var t2: float = t * t
	var t3: float = t2 * t
	return {"indices": PackedInt32Array([posmod(index - 1, count), index, (index + 1) % count, (index + 2) % count]),
		"weights": PackedFloat64Array([pow(1.0 - t, 3.0) / 6.0, (3.0 * t3 - 6.0 * t2 + 4.0) / 6.0,
			(-3.0 * t3 + 3.0 * t2 + 3.0 * t + 1.0) / 6.0, t3 / 6.0])}


static func _person_walk_height_row(indices: PackedInt32Array, weights: PackedFloat64Array, limit: float) -> Dictionary:
	var norm: float = 0.0
	for weight: float in weights:
		norm += weight * weight
	return {"indices": indices, "weights": weights, "limit": limit, "norm": norm}


## Dykstra corrections are scalars because every constraint is a half-space.
static func _project_person_walk_height(rows: Array, reference: PackedFloat64Array, max_sweeps: int = PERSON_WALK_PROJECT_SWEEPS, budget: Dictionary = {}) -> Dictionary:
	var coefficients: PackedFloat64Array = reference.duplicate()
	var corrections: PackedFloat64Array = PackedFloat64Array()
	corrections.resize(rows.size())
	var violation: float = INF
	var best_excess: float = INF
	var stale_sweeps: int = 0
	for sweep in mini(max_sweeps, PERSON_WALK_PROJECT_SWEEPS):
		if not _person_walk_spend(budget, "project", "shared", rows.size()):
			return {"coefficients": coefficients, "converged": false, "max_violation": violation, "sweeps": sweep, "reason": "FOOT_PATH_BUDGET"}
		for row_id in rows.size():
			var row: Dictionary = rows[row_id]
			var indices: PackedInt32Array = row["indices"]
			var weights: PackedFloat64Array = row["weights"]
			var dot: float = 0.0
			for slot in indices.size():
				dot += coefficients[indices[slot]] * weights[slot]
			var correction: float = maxf(0.0, (dot + corrections[row_id] * float(row["norm"]) - float(row["limit"])) / float(row["norm"]))
			var step: float = corrections[row_id] - correction
			for slot in indices.size():
				coefficients[indices[slot]] += step * weights[slot]
			corrections[row_id] = correction
		violation = 0.0
		var excess: float = 0.0
		for row: Dictionary in rows:
			var indices: PackedInt32Array = row["indices"]
			var weights: PackedFloat64Array = row["weights"]
			var dot: float = 0.0
			for slot in indices.size():
				dot += coefficients[indices[slot]] * weights[slot]
			violation = maxf(violation, dot - float(row["limit"]))
			excess = maxf(excess, dot - float(row["limit"]) - float(row.get("epsilon_m", PERSON_WALK_PROJECT_FEASIBILITY_M)))
		# Feasibility is sufficient; nearest-point optimality is not a bake gate.
		if excess <= 0.0:
			return {"coefficients": coefficients, "converged": true, "max_violation": violation, "sweeps": sweep + 1}
		if excess < best_excess - PERSON_WALK_PROJECT_PROGRESS_M:
			best_excess = excess
			stale_sweeps = 0
		else:
			stale_sweeps += 1
		if stale_sweeps >= PERSON_WALK_PROJECT_STALL_SWEEPS:
			return {"coefficients": coefficients, "converged": false, "max_violation": violation,
				"sweeps": sweep + 1, "stale_sweeps": stale_sweeps, "reason": "HEIGHT_PROJECT_STALLED"}
	return {"coefficients": coefficients, "converged": false, "max_violation": violation, "sweeps": mini(max_sweeps, PERSON_WALK_PROJECT_SWEEPS)}


static func _person_walk_project_table(phases: PackedFloat64Array, lowers: PackedFloat64Array, uppers: PackedFloat64Array, target: float, require_mean: bool = true, inset: float = 0.0, budget: Dictionary = {}, projection_phases: PackedFloat64Array = PackedFloat64Array(), ctx: Dictionary = {}) -> Dictionary:
	var count: int = PERSON_WALK_HEIGHT_SAMPLES
	var table: Dictionary = {"ok": false, "reason": "", "values": PackedFloat64Array(), "slopes": PackedFloat64Array(),
		"uppers": uppers, "lowers": lowers, "failed_samples": PackedInt32Array(), "mean": 0.0, "saved_mean": 0.0, "mean_feasible": false}
	if phases.size() < count or lowers.size() != phases.size() or uppers.size() != phases.size():
		table["reason"] = "HEIGHT_INPUT"
		return table
	var failed: PackedInt32Array = PackedInt32Array()
	for index in phases.size():
		if not is_finite(lowers[index]) or not is_finite(uppers[index]) or lowers[index] > uppers[index]:
			failed.append(index)
	if not failed.is_empty():
		table["failed_samples"] = failed
		table["reason"] = "POINT_EMPTY"
		return table
	var grid_cap: float = 0.0
	var saved_cap: float = 0.0
	for index in count:
		grid_cap += uppers[index] / float(count)
		if index % 8 == 0:
			saved_cap += uppers[index] / float(PERSON_WALK_SAVED_SAMPLES)
	table["grid_cap"] = grid_cap
	table["saved_cap"] = saved_cap
	if require_mean and minf(grid_cap, saved_cap) + PERSON_WALK_MEAN_EPSILON < target:
		table["reason"] = "MEAN_SAVED_CAP" if saved_cap + PERSON_WALK_MEAN_EPSILON < target else "MEAN_GRID_CAP"
		return table
	var rows: Array = []
	var deferred: Array = []
	for index in phases.size():
		var basis: Dictionary = _person_walk_height_weights(phases[index], count)
		var weights: PackedFloat64Array = basis["weights"]
		var negative: PackedFloat64Array = PackedFloat64Array()
		for weight: float in weights:
			negative.append(-weight)
		var margin: float = _person_walk_height_inset(lowers[index], uppers[index], inset)
		var destination: Array = rows if projection_phases.is_empty() or projection_phases.has(phases[index]) else deferred
		destination.append(_person_walk_height_row(basis["indices"], weights, uppers[index] - margin))
		destination.append(_person_walk_height_row(basis["indices"], negative, -lowers[index] - margin))
	if require_mean:
		for samples: int in [count, PERSON_WALK_SAVED_SAMPLES]:
			var weights: PackedFloat64Array = PackedFloat64Array()
			weights.resize(count)
			for frame in samples:
				var basis: Dictionary = _person_walk_height_weights(float(frame) / float(samples), count)
				for slot in 4:
					weights[int(basis["indices"][slot])] -= float(basis["weights"][slot]) / float(samples)
			var indices: PackedInt32Array = PackedInt32Array()
			for index in count:
				indices.append(index)
			var mean_row: Dictionary = _person_walk_height_row(indices, weights, -target)
			mean_row["epsilon_m"] = PERSON_WALK_MEAN_EPSILON
			rows.append(mean_row)
	var reference: PackedFloat64Array = uppers.slice(0, count)
	for _pass_id in PERSON_WALK_HEIGHT_PASSES:
		var smoothed: PackedFloat64Array = PackedFloat64Array()
		for index in count:
			var total: float = 0.0
			for neighbour in range(-PERSON_WALK_HEIGHT_RADIUS, PERSON_WALK_HEIGHT_RADIUS + 1):
				total += reference[posmod(index + neighbour, count)]
			smoothed.append(total / float(2 * PERSON_WALK_HEIGHT_RADIUS + 1))
		reference = smoothed
	var projected: Dictionary = {}
	# Add omitted constraints only when the solved table violates them.
	for _refinement: int in deferred.size() + 1:
		projected = _project_person_walk_height(rows, reference, PERSON_WALK_PROJECT_SWEEPS, budget)
		if not bool(projected["converged"]):
			if ctx.has("dump_projection"):
				_person_walk_dump_projection(ctx, rows, reference, projected, phases, lowers, uppers, target, require_mean, inset)
			break
		var added: bool = false
		var current: PackedFloat64Array = projected["coefficients"]
		for row_id: int in range(deferred.size() - 1, -1, -1):
			var row: Dictionary = deferred[row_id]
			var indices: PackedInt32Array = row["indices"]
			var weights: PackedFloat64Array = row["weights"]
			var dot: float = 0.0
			for slot: int in indices.size():
				dot += current[indices[slot]] * weights[slot]
			if dot - float(row["limit"]) > PERSON_WALK_PROJECT_EPSILON:
				rows.append(row)
				deferred.remove_at(row_id)
				added = true
		if not added:
			break
	table["projection"] = projected
	if not bool(projected["converged"]):
		table["reason"] = projected.get("reason", "HEIGHT_PROJECT_LIMIT")
		return table
	var coefficients: PackedFloat64Array = projected["coefficients"]
	var values: PackedFloat64Array = PackedFloat64Array()
	var slopes: PackedFloat64Array = PackedFloat64Array()
	var mean: float = 0.0
	var saved_mean: float = 0.0
	for index in count:
		var left: float = coefficients[posmod(index - 1, count)]
		var right: float = coefficients[(index + 1) % count]
		var value: float = (left + 4.0 * coefficients[index] + right) / 6.0
		values.append(value)
		slopes.append((right - left) * 0.5)
		mean += value / float(count)
		if index % 8 == 0:
			saved_mean += value / float(PERSON_WALK_SAVED_SAMPLES)
	var mean_ok: bool = minf(mean, saved_mean) + PERSON_WALK_MEAN_EPSILON >= target
	if require_mean and not mean_ok:
		table["reason"] = "HEIGHT_PROJECT_LIMIT"
		if ctx.has("dump_projection"):
			_person_walk_dump_projection(ctx, rows, reference, projected, phases, lowers, uppers, target, require_mean, inset)
		return table
	table.merge({"ok": true, "values": values, "slopes": slopes, "coefficients": coefficients,
		"mean": mean, "saved_mean": saved_mean, "mean_feasible": mean_ok}, true)
	return table


## Capture the first failed solve; coefficients have no independent box bounds.
static func _person_walk_dump_projection(ctx: Dictionary, rows: Array, reference: PackedFloat64Array, projected: Dictionary, phases: PackedFloat64Array, lowers: PackedFloat64Array, uppers: PackedFloat64Array, target: float, require_mean: bool, inset: float) -> void:
	var state: Dictionary = ctx.get_or_add("walk_projection_dump", {})
	if bool(state.get("attempted", false)):
		return
	state["attempted"] = true
	var matrix: Array = []
	var limits: Array[float] = []
	var row_epsilons: Array[float] = []
	var variables: Array = []
	for index: int in reference.size():
		variables.append({"name": "pelvis_bspline_%03d" % index, "lower": null, "upper": null})
	for row: Dictionary in rows:
		var coefficients: Array[float] = []
		coefficients.resize(reference.size())
		coefficients.fill(0.0)
		var indices: PackedInt32Array = row["indices"]
		var weights: PackedFloat64Array = row["weights"]
		for slot: int in indices.size():
			coefficients[indices[slot]] += weights[slot]
		matrix.append(coefficients)
		limits.append(float(row["limit"]))
		row_epsilons.append(float(row.get("epsilon_m", PERSON_WALK_PROJECT_FEASIBILITY_M)))
	var residual: float = projected["max_violation"]
	var payload: Dictionary = {"schema": "walk_projection_v1", "relation": "A*x <= b", "rows": rows.size(), "columns": reference.size(),
		"A": matrix, "b": limits, "A_eq": [], "b_eq": [], "variables": variables, "x0": Array(reference),
		"x_last": Array(projected["coefficients"]), "sweeps": projected["sweeps"], "max_sweeps": PERSON_WALK_PROJECT_SWEEPS,
		"solver_converged": projected["converged"], "zero_initial_corrections": true,
		"reason": projected.get("reason", "HEIGHT_PROJECT_LIMIT"), "max_violation": residual if is_finite(residual) else null,
		"projection_epsilon_m": PERSON_WALK_PROJECT_FEASIBILITY_M, "mean_epsilon_m": PERSON_WALK_MEAN_EPSILON,
		"row_epsilon_m": row_epsilons, "stale_sweeps": projected.get("stale_sweeps", 0),
		"units": {"x": "m", "A": "dimensionless", "b": "m", "phase": "cycle"},
		"rig": ctx.get("rig_label", "unknown"), "scope": "active rows of first failed projection call",
		"input": {"phases": Array(phases), "lowers": Array(lowers), "uppers": Array(uppers), "target": target, "require_mean": require_mean, "inset": inset}}
	var path: String = str(ctx["dump_projection"])
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not is_instance_valid(file):
		state["error"] = int(FileAccess.get_open_error())
		push_error("WALK_PROJECTION_DUMP_OPEN path=%s error=%d" % [path, state["error"]])
		return
	file.store_string(JSON.stringify(payload, "\t", true, true))
	file.flush()
	state["error"] = int(file.get_error())
	file.close()
	state["written"] = int(state["error"]) == int(OK)
	state["path"] = path
	state["rows"] = rows.size()
	state["columns"] = reference.size()
	if not bool(state["written"]):
		push_error("WALK_PROJECTION_DUMP_WRITE path=%s error=%d" % [path, state["error"]])


## Keep the grid first so stored frames remain every eighth grid sample.
static func _person_walk_validation_phases(fit: Dictionary, include_mid: bool = true) -> PackedFloat64Array:
	var phases: PackedFloat64Array = PackedFloat64Array()
	for sample in PERSON_WALK_HEIGHT_SAMPLES:
		phases.append(float(sample) / float(PERSON_WALK_HEIGHT_SAMPLES))
	var params: Dictionary = fit.get("path_params", {})
	var boundaries: Array[float] = [0.0]
	for side in 2:
		for fraction: float in [0.0, float(params.get("heel_end", PERSON_WALK_HEEL_END)), 0.40, 0.60, float(params.get("toe_start", PERSON_WALK_TOE_START)), 1.0]:
			boundaries.append(float(fit["starts"][side]) + float(fit["durations"][side]) * fraction)
		for sample in (17 if include_mid else 0):
			var mid_u: float = fposmod(float(fit["starts"][side]) + float(fit["durations"][side]) * (0.40 + 0.20 * float(sample) / 16.0), 1.0)
			if not phases.has(mid_u):
				phases.append(mid_u)
	for boundary: float in boundaries:
		for offset: float in [-0.000001, 0.0, 0.000001]:
			var u: float = fposmod(boundary + offset, 1.0)
			if not phases.has(u):
				phases.append(u)
	for u: float in fit.get("height_extra_phases", PackedFloat64Array()):
		if not phases.has(u):
			phases.append(u)
	return phases


static func _person_walk_collect_bounds(ctx: Dictionary, fit: Dictionary, specs: Array, field: Dictionary) -> Dictionary:
	var phases: PackedFloat64Array = _person_walk_validation_phases(fit)
	var uppers: PackedFloat64Array = PackedFloat64Array()
	var lowers: PackedFloat64Array = PackedFloat64Array()
	var details: Array = []
	var cache: Dictionary = fit.get_or_add("geometry_cache", {})
	var bound_cache: Dictionary = fit.get_or_add("bound_cache", {})
	var intervals: Array = [[Vector2(-PERSON_WALK_CENTER_LIMIT, PERSON_WALK_CENTER_LIMIT)], [Vector2(-PERSON_WALK_CENTER_LIMIT, PERSON_WALK_CENTER_LIMIT)]]
	for u: float in phases:
		var rigid_targets: Array = [_person_walk_ankle_goal(fit, 0, u)["target"], _person_walk_ankle_goal(fit, 1, u)["target"]]
		var shared: Dictionary = {"lower": -INF, "upper": _person_walk_stand_cap(fit), "lower_side": -1, "upper_side": -1,
			"lower_clip": "", "upper_clip": "stand", "phase": u, "horizontal_miss": false, "reason": "", "targets": rigid_targets}
		for spec: Dictionary in specs:
			var entry: Array = spec["entry"]
			var clip: String = entry[0]
			var cache_key: String = "%s:%.12f" % [clip, float(spec["shift"])]
			var geometry_by_phase: Dictionary = cache.get_or_add(cache_key, {})
			if not geometry_by_phase.has(u):
				var keyed_u: float = fposmod(u + float(spec["shift"]), 1.0)
				_person_walk_pose(ctx, fit, entry, keyed_u)
				_apply_person_walk_turn(ctx, fit, u, keyed_u, entry[4])
				geometry_by_phase[u] = _person_walk_geometry(ctx, fit)
			var phase_field: Dictionary = field.get(clip, {})
			var targets: Array = phase_field.get(u, rigid_targets)
			if not (fit.get("height_extra_phases", PackedFloat64Array()) as PackedFloat64Array).is_empty():
				targets = _person_walk_field_seed(fit, phase_field, u, rigid_targets)
			# Exact serialized inputs only; rounded keys can hide a narrow collision.
			var bound_key: String = var_to_bytes([u, geometry_by_phase[u], targets, fit["starts"], fit["durations"], fit.get("path_params", {}), _person_walk_stand_cap(fit)]).hex_encode()
			var bounds: Dictionary = bound_cache.get(bound_key, {})
			if bounds.is_empty():
				if not _person_walk_spend(fit.get("work_budget", {}), "bounds", clip):
					return {"phases": phases, "uppers": uppers, "lowers": lowers, "details": details, "reason": "FOOT_PATH_BUDGET", "center_intervals": intervals, "complete": false}
				bounds = _person_walk_bounds_from_geometry(fit, u, targets, geometry_by_phase[u])
				bound_cache[bound_key] = bounds
			else:
				var ledger: Dictionary = fit.get("work_budget", {})
				ledger["bounds_reused"] = int(ledger.get("bounds_reused", 0)) + 1
			for side in 2:
				intervals[side] = _person_walk_center_intersection(intervals[side], bounds["per_side"][side]["forbidden_center"])
			if float(bounds["lower"]) > float(shared["lower"]):
				shared["lower"] = bounds["lower"]
				shared["lower_side"] = bounds["lower_side"]
				shared["lower_clip"] = clip
				shared["lower_targets"] = targets
			if float(bounds["upper"]) < float(shared["upper"]):
				shared["upper"] = bounds["upper"]
				shared["upper_side"] = bounds["upper_side"]
				shared["upper_clip"] = clip
				shared["upper_targets"] = targets
			shared["horizontal_miss"] = bool(shared["horizontal_miss"]) or bool(bounds["horizontal_miss"])
			for side_bounds: Dictionary in bounds["per_side"]:
				if not str(side_bounds["reason"]).is_empty():
					shared["reason"] = side_bounds["reason"]
		lowers.append(shared["lower"])
		uppers.append(shared["upper"])
		details.append(shared)
	return {"phases": phases, "uppers": uppers, "lowers": lowers, "details": details, "center_intervals": intervals, "complete": true}


## Both means constrain the same coefficients and all clips share their bounds.
static func _fit_person_walk_height(ctx: Dictionary, fit: Dictionary, walk: Array, shift: float, target_field: Dictionary = {}, require_mean: bool = true, report: bool = true) -> Dictionary:
	if not fit.has("walk_specs"):
		fit.erase("geometry_cache")
	var specs: Array = fit.get("walk_specs", [{"entry": walk, "shift": shift}])
	var field: Dictionary = fit.get("target_field", {}) if target_field.is_empty() else target_field
	var bounds: Dictionary = _person_walk_collect_bounds(ctx, fit, specs, field)
	if bounds.has("reason"):
		return {"ok": false, "reason": bounds["reason"], "failed_samples": PackedInt32Array()}
	var target: float = float(fit["floor"]) + PERSON_WALK_MEAN_MIN * float(fit["stand_ref_m"])
	var table: Dictionary = _person_walk_project_table(bounds["phases"], bounds["lowers"], bounds["uppers"], target, require_mean, PERSON_WALK_HEIGHT_INTERPOLATION_MARGIN, fit.get("work_budget", {}), _person_walk_validation_phases(fit, false), ctx)
	table.merge({"phases": bounds["phases"], "details": bounds["details"], "center_intervals": bounds["center_intervals"], "rig_label": ctx.get("rig_label", "unknown"),
		"clip": walk[0], "fit_failures": ctx.get_or_add("fit_failures", [])}, true)
	if report and not bool(table["ok"]):
		var failed: PackedInt32Array = table["failed_samples"]
		for sample in failed:
			var detail: Dictionary = bounds["details"][sample]
			ctx.get_or_add("fit_failures", []).append("PELVIS_UNFIT rig=%s clip=%s sample=%d phase=%.9f reason=%s lower=%.9f upper=%.9f lower_side=%d upper_side=%d" % [
				ctx.get("rig_label", "unknown"), walk[0], sample, detail["phase"], table["reason"], detail["lower"], detail["upper"], detail["lower_side"], detail["upper_side"]])
		if failed.is_empty():
			ctx.get_or_add("fit_failures", []).append("PELVIS_MEAN_UNFIT rig=%s clip=%s reason=%s target=%.9f" % [ctx.get("rig_label", "unknown"), walk[0], table["reason"], target])
	return table


static func _person_walk_default_params(fit: Dictionary) -> Dictionary:
	return fit.get("path_params", {"centers": [-PERSON_WALK_FOOTPRINT_BACK, -PERSON_WALK_FOOTPRINT_BACK],
		"lifts": [PERSON_WALK_SWING_LIFT, PERSON_WALK_SWING_LIFT], "heel_end": PERSON_WALK_HEEL_END,
		"toe_start": PERSON_WALK_TOE_START, "durations": (fit["durations"] as Array).duplicate()}).duplicate(true)


static func _person_walk_params_valid(params: Dictionary, starts: Array) -> bool:
	var heel: float = params["heel_end"]
	var toe: float = params["toe_start"]
	if heel < 0.16 or heel > 0.40 or toe < 0.45 or toe > 0.80 or toe < heel + 0.05 - 0.000000001:
		return false
	for side in 2:
		var gap: float = fposmod(float(starts[1 - side]) - float(starts[side]), 1.0)
		var duration: float = params["durations"][side]
		if duration < (0.50 if gap < 0.5 else 0.55) or duration > (0.53 if gap < 0.5 else 0.57):
			return false
		if absf(float(params["centers"][side])) > PERSON_WALK_CENTER_LIMIT:
			return false
		if float(params["lifts"][side]) < PERSON_WALK_LIFT_MIN or float(params["lifts"][side]) > PERSON_WALK_LIFT_MAX:
			return false
	return true


static func _person_walk_with_params(fit: Dictionary, params: Dictionary) -> Dictionary:
	var candidate: Dictionary = fit.duplicate()
	var previous: Dictionary = _person_walk_default_params(fit)
	var anchors: Array = []
	for side in 2:
		var anchor: Vector3 = fit["anchors"][side]
		anchor.z += float(params["centers"][side]) - float(previous["centers"][side])
		anchors.append(anchor)
	candidate["anchors"] = anchors
	candidate["durations"] = (params["durations"] as Array).duplicate()
	candidate["path_params"] = params.duplicate(true)
	candidate["target_field"] = {}
	candidate["height_extra_phases"] = PackedFloat64Array()
	candidate["goal_cache"] = {}
	return candidate


static func _person_walk_rank_path(ctx: Dictionary, fit: Dictionary, specs: Array) -> Dictionary:
	var collected: Dictionary = _person_walk_collect_bounds(ctx, fit, specs, {})
	var target: float = float(fit["floor"]) + PERSON_WALK_MEAN_MIN * float(fit["stand_ref_m"])
	var grid_cap: float = 0.0
	var saved_cap: float = 0.0
	var gap: float = 0.0
	var worst: Dictionary = {"phase": -1.0, "lower": -INF, "upper": INF, "lower_side": -1, "upper_side": -1, "lower_clip": "", "upper_clip": "", "reason": "UNSAMPLED"}
	var reason: String = ""
	var lift_estimates: Array = (_person_walk_default_params(fit)["lifts"] as Array).duplicate()
	for index in (collected["details"] as Array).size():
		var detail: Dictionary = collected["details"][index]
		if index == 0:
			worst = detail
		var local_gap: float = maxf(0.0, float(detail["lower"]) - float(detail["upper"]))
		var upper_side: int = detail["upper_side"]
		if upper_side >= 0 and is_finite(local_gap):
			var age: float = fposmod(float(detail["phase"]) - float(fit["starts"][upper_side]), 1.0)
			var duration: float = fit["durations"][upper_side]
			if age > duration:
				var gain: float = pow(sin(PI * (age - duration) / (1.0 - duration)), 2.0)
				if gain > 0.000001:
					lift_estimates[upper_side] = maxf(float(lift_estimates[upper_side]), float(fit["path_params"]["lifts"][upper_side]) + local_gap / gain)
		if local_gap > gap:
			gap = local_gap
			worst = detail
		if not str(detail["reason"]).is_empty():
			reason = detail["reason"]
		if index < PERSON_WALK_HEIGHT_SAMPLES:
			grid_cap += float(detail["upper"]) / float(PERSON_WALK_HEIGHT_SAMPLES)
			if index % 8 == 0:
				saved_cap += float(detail["upper"]) / float(PERSON_WALK_SAVED_SAMPLES)
	var category: String = "FEASIBLE"
	if gap > 0.0:
		if reason.is_empty():
			reason = "POINT_EMPTY"
		category = "REST_CAP" if int(worst["upper_side"]) < 0 else "STANCE_CAP"
		var side: int = worst["upper_side"]
		if side >= 0 and fposmod(float(worst["phase"]) - float(fit["starts"][side]), 1.0) > float(fit["durations"][side]):
			category = "SWING_CAP"
	elif minf(grid_cap, saved_cap) < target:
		category = "MEAN_CAP"
		reason = "MEAN_SAVED_CAP" if saved_cap < target else "MEAN_GRID_CAP"
	var score: float = 4.0 * gap + maxf(0.0, target - minf(grid_cap, saved_cap))
	score += maxf(0.0, float(fit["rest_hips_y"]) - minf(grid_cap, saved_cap)) * 0.001
	var ranked: Dictionary = {"fit": fit, "params": fit["path_params"], "gap": gap, "detail": worst,
		"grid_cap": grid_cap, "saved_cap": saved_cap, "category": category, "reason": reason,
		"center_intervals": collected["center_intervals"], "lift_estimates": lift_estimates, "complete": bool(collected["complete"]), "phases_checked": (collected["details"] as Array).size(),
		"phases_total": (collected["phases"] as PackedFloat64Array).size(), "means_complete": (collected["details"] as Array).size() >= PERSON_WALK_HEIGHT_SAMPLES}
	if bool(collected["complete"]):
		ranked["score"] = score
	else:
		ranked["reason"] = reason if not reason.is_empty() else "UNSAMPLED"
	return ranked


static func _person_walk_keep_candidate(beam: Array, candidate: Dictionary) -> Array:
	var ordered: Array = beam.duplicate()
	ordered.append(candidate)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) < float(b["score"]))
	var selected: Array = []
	var categories: Array[String] = []
	var ids: Array[int] = []
	for item: Dictionary in ordered:
		var category: String = item["category"]
		if not categories.has(category) and selected.size() < PERSON_WALK_SEARCH_BEAM:
			selected.append(item)
			ids.append(int(item["id"]))
			categories.append(category)
	for item: Dictionary in ordered:
		if selected.size() >= PERSON_WALK_SEARCH_BEAM:
			break
		if not ids.has(int(item["id"])):
			selected.append(item)
	selected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) < float(b["score"]))
	return selected


static func _person_walk_add_path(state: Dictionary, params: Dictionary) -> void:
	var base: Dictionary = state["base"]
	if not _person_walk_params_valid(params, base["starts"]):
		return
	var key: String = var_to_str(params)
	if (state["seen"] as Dictionary).has(key):
		return
	if int(state["geometry_count"]) >= int(state["geometry_limit"]):
		state["limited"] = true
		return
	if not _person_walk_spend(base.get("work_budget", {}), "paths", "shared"):
		state["limited"] = true
		return
	state["seen"][key] = true
	state["geometry_count"] = int(state["geometry_count"]) + 1
	var candidate: Dictionary = _person_walk_rank_path(state["ctx"], _person_walk_with_params(base, params), state["specs"])
	if not candidate.has("score"):
		state["partial_candidate"] = candidate
		state["geometry_count"] = int(state["geometry_count"]) - 1
		state["limited"] = true
		return
	candidate["id"] = state["geometry_count"]
	state["beam"] = _person_walk_keep_candidate(state["beam"], candidate)
	state["trials"].append({"id": candidate["id"], "params": params.duplicate(true), "reason": candidate["reason"],
		"gap": candidate["gap"], "detail": candidate["detail"], "grid_cap": candidate["grid_cap"], "saved_cap": candidate["saved_cap"]})


static func _person_walk_path_block(beam: Array, block: int) -> Array:
	var proposals: Array = _person_walk_directed_paths(beam[0])
	if block == 0:
		var initial: Dictionary = beam[0]["params"]
		for left in 17:
			for right in 17:
				var params: Dictionary = initial.duplicate(true)
				params["centers"] = [-0.16 + float(left) * 0.02, -0.16 + float(right) * 0.02]
				proposals.append(params)
		return proposals
	for item: Dictionary in beam:
		var initial: Dictionary = item["params"]
		if block == 1:
			var choices: Array = [[], []]
			for side in 2:
				var values: Array = [float(initial["lifts"][side]), 0.02, 0.07, 0.12, 0.18]
				var detail: Dictionary = item["detail"]
				var age: float = fposmod(float(detail["phase"]) - float(item["fit"]["starts"][side]), 1.0)
				var duration: float = initial["durations"][side]
				if int(detail["upper_side"]) == side and age > duration and is_finite(float(item["gap"])):
					var gain: float = pow(sin(PI * (age - duration) / (1.0 - duration)), 2.0)
					if gain > 0.000001:
						var estimate: float = float(initial["lifts"][side]) + float(item["gap"]) / gain
						for offset: float in [-0.01, 0.0, 0.01]:
							values.append(clampf(estimate + offset, PERSON_WALK_LIFT_MIN, PERSON_WALK_LIFT_MAX))
				choices[side] = values
			for left: float in choices[0]:
				for right: float in choices[1]:
					var params: Dictionary = initial.duplicate(true)
					params["lifts"] = [left, right]
					proposals.append(params)
		elif block == 2:
			for heel: float in [0.16, 0.22, 0.28, 0.34, 0.40]:
				for toe: float in [0.45, 0.55, 0.65, 0.75, 0.80]:
					var params: Dictionary = initial.duplicate(true)
					params["heel_end"] = heel
					params["toe_start"] = toe
					proposals.append(params)
		elif block == 3:
			var starts: Array = item["fit"]["starts"]
			var short_side: int = 0 if fposmod(float(starts[1]) - float(starts[0]), 1.0) < 0.5 else 1
			for short_duration: float in [0.50, 0.51, 0.52, 0.53]:
				for long_duration: float in [0.55, 0.56, 0.57]:
					var params: Dictionary = initial.duplicate(true)
					params["durations"][short_side] = short_duration
					params["durations"][1 - short_side] = long_duration
					proposals.append(params)
		else:
			for key: String in ["centers", "lifts", "roll"]:
				var step: float = 0.025 if key == "roll" else 0.005
				for left: float in [-step, 0.0, step]:
					for right: float in [-step, 0.0, step]:
						var params: Dictionary = initial.duplicate(true)
						if key == "roll":
							params["heel_end"] = float(params["heel_end"]) + left
							params["toe_start"] = float(params["toe_start"]) + right
						else:
							params[key][0] = float(params[key][0]) + left
							params[key][1] = float(params[key][1]) + right
						proposals.append(params)
	return proposals


## Joint proposals cover both ends before local refinements spend the budget.
static func _person_walk_directed_paths(item: Dictionary) -> Array:
	var initial: Dictionary = item["params"]
	var centers: Array = (initial["centers"] as Array).duplicate()
	for side in 2:
		var nearest: float = INF
		var origin: float = centers[side]
		for interval: Vector2 in item.get("center_intervals", [[], []])[side]:
			var choice: float = (interval.x + interval.y) * 0.5
			if absf(choice - origin) < nearest:
				nearest = absf(choice - origin)
				centers[side] = choice
	var proposals: Array = []
	for index in 8:
		var params: Dictionary = initial.duplicate(true)
		params["centers"] = centers.duplicate()
		if index >= 4:
			params["centers"] = [(-0.16 if index % 2 == 0 else 0.16), (-0.16 if index < 6 else 0.16)]
		for side in 2:
			params["lifts"][side] = PERSON_WALK_LIFT_MAX if index >= 2 else clampf(float(item.get("lift_estimates", initial["lifts"])[side]) + 0.005, PERSON_WALK_LIFT_MIN, PERSON_WALK_LIFT_MAX)
		if index % 2 == 1:
			for side in 2:
				var starts: Array = item["fit"]["starts"]
				params["durations"][side] = 0.50 if fposmod(float(starts[1 - side]) - float(starts[side]), 1.0) < 0.5 else 0.55
		if index == 3:
			params["heel_end"] = 0.16
			params["toe_start"] = 0.80
		proposals.append(params)
	return proposals


static func _person_walk_path_distance(a: Dictionary, b: Dictionary) -> float:
	var distance: float = 0.0
	for key: String in ["centers", "lifts", "durations"]:
		var scale: float = 0.32 if key == "centers" else (0.16 if key == "lifts" else 0.07)
		for side in 2:
			distance += pow((float(a[key][side]) - float(b[key][side])) / scale, 2.0)
	distance += pow((float(a["heel_end"]) - float(b["heel_end"])) / 0.24, 2.0)
	distance += pow((float(a["toe_start"]) - float(b["toe_start"])) / 0.35, 2.0)
	return distance


## Deduplicate before quota; farthest-first covers the remaining design box.
static func _person_walk_allocate_paths(proposals: Array, seen: Dictionary, starts: Array, limit: int, nearby: Dictionary = {}) -> Dictionary:
	var unique: Dictionary = {}
	var remaining: Array = []
	for params: Dictionary in proposals:
		var key: String = var_to_str(params)
		if not seen.has(key) and not unique.has(key) and _person_walk_params_valid(params, starts):
			unique[key] = true
			remaining.append(params)
	var selected: Array = []
	if not nearby.is_empty():
		var local_order: Array = remaining.duplicate()
		local_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _person_walk_path_distance(a, nearby) < _person_walk_path_distance(b, nearby))
		for index: int in mini(16, mini(limit, local_order.size())):
			selected.append(local_order[index])
			remaining.erase(local_order[index])
	var priority: int = mini(8, mini(limit - selected.size(), remaining.size()))
	for _index in priority:
		selected.append(remaining.pop_front())
	while selected.size() < limit and not remaining.is_empty():
		var best_index: int = 0
		var best_distance: float = -1.0
		for index in remaining.size():
			var nearest: float = INF
			for chosen: Dictionary in selected:
				nearest = minf(nearest, _person_walk_path_distance(remaining[index], chosen))
			if nearest > best_distance:
				best_distance = nearest
				best_index = index
		selected.append(remaining[best_index])
		remaining.remove_at(best_index)
	return {"selected": selected, "unique": unique.size(), "omitted": remaining.size()}


## Explicit diagnostics opt in through a temporary project setting.
static func _person_walk_budget_scale_for_tests() -> float:
	var value: Variant = ProjectSettings.get_setting("body_bake/walk_budget_scale_for_tests", 1.0)
	if not (value is float or value is int):
		return 1.0
	var scale: float = float(value)
	return maxf(1.0, scale) if is_finite(scale) else 1.0


## One ledger covers all candidates and clips in this rig context.
static func _person_walk_budget(limits: Dictionary = {}) -> Dictionary:
	var caps: Dictionary = {"bounds": PERSON_WALK_BUDGET_BOUNDS, "clip_bounds": PERSON_WALK_BUDGET_CLIP_BOUNDS,
		"ik": PERSON_WALK_BUDGET_IK, "clip_ik": PERSON_WALK_BUDGET_CLIP_IK,
		"project": PERSON_WALK_BUDGET_PROJECT, "paths": PERSON_WALK_BUDGET_PATHS}
	var scale: float = _person_walk_budget_scale_for_tests()
	for key: String in caps:
		if scale > 1.0:
			caps[key] = ceili(float(caps[key]) * scale)
		# Explicit small limits remain absolute for exhaustion fixtures.
		caps[key] = clampi(int(limits.get(key, caps[key])), 0, int(caps[key]))
	return {"limits": caps, "used": {}, "clips": {}, "exhausted": false, "kind": "", "clip": "", "scale": scale}


static func _person_walk_spend(budget: Dictionary, kind: String, clip: String, amount: int = 1) -> bool:
	if budget.is_empty():
		return true
	if bool(budget["exhausted"]):
		return false
	var used: Dictionary = budget["used"]
	var by_clip: Dictionary = budget["clips"].get_or_add(clip, {})
	var limits: Dictionary = budget["limits"]
	if int(used.get(kind, 0)) + amount > int(limits[kind]) or (limits.has("clip_" + kind) and int(by_clip.get(kind, 0)) + amount > int(limits["clip_" + kind])):
		budget.merge({"exhausted": true, "kind": kind, "clip": clip}, true)
		return false
	used[kind] = int(used.get(kind, 0)) + amount
	by_clip[kind] = int(by_clip.get(kind, 0)) + amount
	var stage: String = str(budget.get("active_stage", "search"))
	var stage_used: Dictionary = budget.get_or_add("stages", {}).get_or_add(stage, {})
	stage_used[kind] = int(stage_used.get(kind, 0)) + amount
	var stage_clip: Dictionary = budget.get_or_add("stage_clips", {}).get_or_add(stage, {}).get_or_add(clip, {})
	stage_clip[kind] = int(stage_clip.get(kind, 0)) + amount
	return true


## Cache only frozen keyed poses, before path-dependent pelvis and IK edits.
static func _person_walk_pose(ctx: Dictionary, fit: Dictionary, entry: Array, keyed_u: float) -> void:
	if not fit.has("pose_cache"):
		pose(ctx, entry[1], entry[4], keyed_u)
		return
	var body: Skeleton3D = ctx["body"]
	var cache: Dictionary = fit["pose_cache"].get_or_add(str(entry[0]), {})
	if cache.has(keyed_u):
		var cached_poses: Array = cache[keyed_u]
		for bone in body.get_bone_count():
			body.set_bone_pose_position(bone, cached_poses[bone][0])
			body.set_bone_pose_rotation(bone, cached_poses[bone][1])
			body.set_bone_pose_scale(bone, cached_poses[bone][2])
		return
	pose(ctx, entry[1], entry[4], keyed_u)
	var bone_poses: Array = []
	for bone in body.get_bone_count():
		bone_poses.append([body.get_bone_pose_position(bone), body.get_bone_pose_rotation(bone), body.get_bone_pose_scale(bone)])
	cache[keyed_u] = bone_poses


## Only evaluated, uncut frames may return their correction to the shared table.
static func _person_walk_joint_feedback(solved: Dictionary) -> Dictionary:
	var conditions: Dictionary = solved.get("conditions", {})
	var targets: Array = solved.get("proposed_targets", [])
	var valid: bool = bool(solved.get("evaluated", false)) and not bool(solved.get("bounds", {}).get("empty", true)) and targets.size() == 2
	for target: Vector3 in targets:
		valid = valid and target.is_finite()
	for cut: bool in solved.get("reach_clamped", [true, true]):
		valid = valid and not cut
	for ankle_ok: bool in conditions.get("ankle_ok", [false, false]):
		valid = valid and ankle_ok
	var knee: bool = false
	for gate: String in ["mid_knee_ok", "stance_knee_ok"]:
		for passed: bool in conditions.get(gate, []):
			knee = knee or not passed
	var recoverable: bool = str(solved.get("reason", "")) in ["SKIN_ITER_LIMIT", "SKIN_STALLED", "SKIN_CYCLE", "SKIN_SUPPORT_CYCLE"]
	return {"retry": valid and recoverable, "knee": valid and knee,
		"targets": targets.duplicate(), "needs_projection": valid and (recoverable or absf(float(solved.get("height_table_delta_m", 0.0))) > PERSON_WALK_JOINT_HEIGHT_TOL_M)}


## Periodic interpolation predicts only a seed; every new phase is still evaluated.
static func _person_walk_field_seed(fit: Dictionary, field: Dictionary, u: float, rigid: Array) -> Array:
	if field.has(u):
		return (field[u] as Array).duplicate()
	if field.is_empty():
		return rigid.duplicate()
	var phases: Array = field.keys()
	phases.sort()
	var left: float = float(phases.back())
	var right: float = float(phases.front())
	var before: float = left - 1.0
	var after: float = right + 1.0
	for phase: float in phases:
		if phase < u:
			before = phase
			left = phase
		elif phase > u:
			after = phase
			right = phase
			break
	var weight: float = (u - before) / (after - before)
	var seed: Array = []
	for side in 2:
		var a: Vector3 = (field[left][side] as Vector3) - (_person_walk_ankle_goal(fit, side, left)["target"] as Vector3)
		var b: Vector3 = (field[right][side] as Vector3) - (_person_walk_ankle_goal(fit, side, right)["target"] as Vector3)
		seed.append((rigid[side] as Vector3) + a.lerp(b, weight))
	return seed


## Constant center intervals at the actual height: R15 <= distance <= R4.
static func _person_walk_center_window(fit: Dictionary, u: float, targets: Array, geometry: Dictionary, height: float) -> Dictionary:
	var intervals: Array = []
	var evidence: Array = []
	var centers: Array = _person_walk_default_params(fit)["centers"]
	for side in 2:
		var leg: Dictionary = geometry["legs"][side]
		var thigh: Vector3 = leg["thigh"]
		var target: Vector3 = targets[side]
		var a: float = leg["a"]
		var b: float = leg["b"]
		var vertical: float = height + thigh.y - (geometry["hips"] as Vector3).y - target.y
		var fixed_squared: float = vertical * vertical + pow(thigh.x - target.x, 2.0)
		var r4: float = sqrt(a * a + b * b + 2.0 * a * b * cos(PERSON_WALK_KNEE_MIN))
		var r15: float = sqrt(a * a + b * b + 2.0 * a * b * cos(PERSON_WALK_MID_KNEE_MAX))
		var distance: float = sqrt(fixed_squared + pow(thigh.z - target.z, 2.0))
		var center: float = float(centers[side]) + thigh.z - target.z
		var mid: float = fposmod(u - float(fit["starts"][side]), 1.0) / float(fit["durations"][side])
		var allowed: Array = []
		var outer_squared: float = r4 * r4 - fixed_squared
		if minf(a, b) > 0.000001 and vertical >= 0.0 and outer_squared >= 0.0:
			var outer: float = sqrt(outer_squared)
			var lo: float = maxf(-PERSON_WALK_CENTER_LIMIT, center - outer)
			var hi: float = minf(PERSON_WALK_CENTER_LIMIT, center + outer)
			if lo <= hi:
				allowed.append(Vector2(lo, hi))
			if mid >= 0.40 and mid <= 0.60 and r15 * r15 > fixed_squared:
				var inner: float = sqrt(r15 * r15 - fixed_squared)
				allowed = _person_walk_center_intersection(allowed, Vector2(center - inner, center + inner))
		intervals.append(allowed)
		evidence.append({"mid": mid, "distance_minus_r15_m": distance - r15, "r4_minus_distance_m": r4 - distance,
			"predicted_knee_deg": rad_to_deg(acos(clampf((distance * distance - a * a - b * b) / maxf(2.0 * a * b, 0.000000001), -1.0, 1.0))), "intervals": allowed})
	return {"intervals": intervals, "sides": evidence}


static func _person_walk_overlap_centers(a: Array, b: Array) -> Array:
	var result: Array = []
	for left: Vector2 in a:
		for right: Vector2 in b:
			var lo: float = maxf(left.x, right.x)
			var hi: float = minf(left.y, right.y)
			if lo <= hi:
				result.append(Vector2(lo, hi))
	return result


static func _person_walk_nearest_center(intervals: Array, origin: float) -> float:
	var nearest: float = INF
	for interval: Vector2 in intervals:
		var inset: float = _person_walk_height_inset(interval.x, interval.y)
		var choice: float = clampf(origin, interval.x + inset, interval.y - inset)
		if absf(choice - origin) < absf(nearest - origin):
			nearest = choice
	return nearest


## Intersect every clip and phase, not just the first offending middle frame.
static func _person_walk_feedback_centers(ctx: Dictionary, fit: Dictionary, specs: Array, field: Dictionary, heights: Dictionary) -> Dictionary:
	var intervals: Array = [[Vector2(-PERSON_WALK_CENTER_LIMIT, PERSON_WALK_CENTER_LIMIT)], [Vector2(-PERSON_WALK_CENTER_LIMIT, PERSON_WALK_CENTER_LIMIT)]]
	var witness: Dictionary = {}
	var active: Array = [{}, {}]
	var violations: Array = [-INF, -INF]
	for spec: Dictionary in specs:
		var entry: Array = spec["entry"]
		var clip: String = entry[0]
		for u: float in field[clip]:
			if not _person_walk_spend(fit.get("work_budget", {}), "bounds", clip):
				return {"ok": false, "reason": "FOOT_PATH_BUDGET", "center_intervals": intervals}
			var keyed_u: float = fposmod(u + float(spec["shift"]), 1.0)
			_person_walk_pose(ctx, fit, entry, keyed_u)
			_apply_person_walk_turn(ctx, fit, u, keyed_u, entry[4])
			var window: Dictionary = _person_walk_center_window(fit, u, field[clip][u], _person_walk_geometry(ctx, fit), float(heights[clip][u]))
			for side in 2:
				intervals[side] = _person_walk_overlap_centers(intervals[side], window["intervals"][side])
				var evidence: Dictionary = window["sides"][side]
				var violation: float = -float(evidence["r4_minus_distance_m"])
				if float(evidence["mid"]) >= 0.40 and float(evidence["mid"]) <= 0.60:
					violation = maxf(violation, -float(evidence["distance_minus_r15_m"]))
				if violation > float(violations[side]):
					violations[side] = violation
					active[side] = {"clip": clip, "phase": u, "side": side, "window": evidence}
				if (intervals[side] as Array).is_empty() and witness.is_empty():
					witness = {"clip": clip, "phase": u, "side": side, "window": window}
	var params: Dictionary = _person_walk_default_params(fit)
	for side in 2:
		var center: float = _person_walk_nearest_center(intervals[side], float(params["centers"][side]))
		if not is_finite(center):
			return {"ok": false, "reason": "CENTER_EMPTY", "center_intervals": intervals, "detail": witness, "constraints": active}
		params["centers"][side] = center
	return {"ok": true, "params": params, "center_intervals": intervals, "constraints": active}


static func _person_walk_joint_transition(stage: String, passes: int, converged: bool, limit: int) -> String:
	if converged:
		return "dense" if stage == "coarse" else "saved"
	if passes >= limit:
		return "COARSE_ITER_LIMIT" if stage == "coarse" else "DENSE_ITER_LIMIT"
	return stage


static func _person_walk_joint_progress(history: Array, signature: String, score: float) -> String:
	if not history.is_empty() and str(history.back()["signature"]) == signature:
		return "JOINT_STALLED"
	if history.size() > 1 and str(history[history.size() - 2]["signature"]) == signature:
		return "JOINT_CYCLE"
	var stalled: int = 0
	if not history.is_empty() and not score < float(history.back()["score"]) - PERSON_WALK_SKIN_PROGRESS:
		stalled = int(history.back()["stalled"]) + 1
	history.append({"signature": signature, "score": score, "stalled": stalled})
	return "JOINT_STALLED" if stalled >= PERSON_WALK_SKIN_STALL_TRIALS else ""


static func _person_walk_dense_reserve(budget: Dictionary, specs: Array, phases: int) -> bool:
	if budget.is_empty():
		return true
	var total: int = 0
	for spec: Dictionary in specs:
		var clip: String = str(spec["entry"][0])
		var required: int = phases + int(spec["entry"][2])
		total += required
		if int(budget["clips"].get(clip, {}).get("ik", 0)) + required > int(budget["limits"]["clip_ik"]):
			return false
	return int(budget["used"].get("ik", 0)) + total <= int(budget["limits"]["ik"])


static func _fit_person_walk_candidate(ctx: Dictionary, source: Dictionary, specs: Array) -> Dictionary:
	ctx.get_or_add("walk_observation", {"actual_pairs": 0, "outside_pairs": 0})
	if ctx.has("dump_projection"):
		ctx["walk_projection_dump"] = ctx.get("walk_projection_dump", {})
	var local_ctx: Dictionary = ctx.duplicate()
	local_ctx["fit_failures"] = []
	var fit: Dictionary = source.duplicate()
	fit["walk_specs"] = specs
	fit["target_field"] = (source.get("target_field", {}) as Dictionary).duplicate(true)
	fit["dense_refined_phases"] = {}
	if not fit.has("work_budget") or (fit["work_budget"] as Dictionary).is_empty():
		fit["work_budget"] = _person_walk_budget()
	var budget: Dictionary = fit.get("work_budget", {})
	var old_stage: String = str(budget.get("active_stage", "search"))
	var before: Dictionary = (budget.get("stages", {}) as Dictionary).duplicate(true)
	# Reserve half of the unchanged twelve passes for dense continuation.
	var coarse_limit: int = PERSON_WALK_JOINT_PASSES >> 1
	var joint: Dictionary = {"stage": "coarse", "stage_limits": {"coarse": coarse_limit, "dense": PERSON_WALK_JOINT_PASSES - coarse_limit},
		"stage_passes": {"coarse": 0, "dense": 0}, "reprojections": 0, "feedback_frames": 0,
		"knee_feedbacks": 0, "center_updates": 0, "cache_hits": 0, "passes": [], "stage_ik": {}}
	var result: Dictionary = _person_walk_joint_candidate(local_ctx, fit, specs, joint)
	for stage: String in budget.get("stages", {}):
		joint["stage_ik"][stage] = int(budget["stages"][stage].get("ik", 0)) - int(before.get(stage, {}).get("ik", 0))
	joint["exit_reason"] = result.get("reason", "")
	result["joint"] = joint
	result["target_field"] = fit["target_field"]
	budget["active_stage"] = old_stage
	if bool(result["ok"]):
		fit["joint_passes"] = int(joint["stage_passes"]["coarse"]) + int(joint["stage_passes"]["dense"])
		for key: String in ["work_budget", "pose_cache", "geometry_cache", "bound_cache"]:
			fit.erase(key)
	return result


static func _person_walk_joint_candidate(ctx: Dictionary, fit: Dictionary, specs: Array, joint: Dictionary) -> Dictionary:
	var first: Dictionary = specs[0]
	var walk: Array = first["entry"]
	var field: Dictionary = fit["target_field"]
	var solved_cache: Dictionary = {}
	var budget: Dictionary = fit.get("work_budget", {})
	for stage: String in ["coarse", "dense"]:
		var dense: bool = stage == "dense"
		joint["stage"] = stage
		var history: Array = []
		var limit: int = joint["stage_limits"][stage]
		for stage_pass in limit:
			budget["active_stage"] = stage
			var ik_before: int = int(budget.get("used", {}).get("ik", 0))
			if int(joint["stage_passes"]["coarse"]) + int(joint["stage_passes"]["dense"]) > 0:
				joint["reprojections"] = int(joint["reprojections"]) + 1
			joint["stage_passes"][stage] = stage_pass + 1
			fit["stance_knee_min_deg"] = INF
			var full: Dictionary = _fit_person_walk_height(ctx, fit, walk, float(first["shift"]), field, true, false)
			if bool(budget.get("exhausted", false)):
				return {"ok": false, "reason": "FOOT_PATH_BUDGET", "table": full}
			var table: Dictionary = full
			if not bool(full["ok"]):
				if str(full["reason"]) in ["POINT_EMPTY", "CENTER_EMPTY", "MEAN_GRID_CAP", "MEAN_SAVED_CAP"]:
					return {"ok": false, "reason": full["reason"], "table": full}
				table = _fit_person_walk_height(ctx, fit, walk, float(first["shift"]), field, false, false)
			if not bool(table["ok"]):
				return {"ok": false, "reason": table["reason"], "table": table}
			fit["pelvis"] = table
			var next_field: Dictionary = {}
			var heights: Dictionary = {}
			var target_delta: float = 0.0
			var fixed_point_delta: float = 0.0
			var field_step_delta: float = 0.0
			var input_field_verified: bool = true
			var height_delta: float = 0.0
			var unresolved: int = 0
			var knee_feedback: bool = false
			var worst: Dictionary = {}
			var worst_score: float = -1.0
			for spec: Dictionary in specs:
				var entry: Array = spec["entry"]
				var clip: String = entry[0]
				ctx["walk_clip"] = clip
				var previous: Dictionary = field.get(clip, {})
				var next: Dictionary = {}
				var clip_heights: Dictionary = {}
				var cached_phases: Dictionary = solved_cache.get_or_add(clip, {})
				var correction: Array = [Vector3.ZERO, Vector3.ZERO]
				var ordered: PackedFloat64Array = (table["phases"] as PackedFloat64Array).duplicate()
				ordered.sort()
				for u: float in ordered:
					var keyed_u: float = fposmod(u + float(spec["shift"]), 1.0)
					var rigid: Array = [_person_walk_ankle_goal(fit, 0, u)["target"], _person_walk_ankle_goal(fit, 1, u)["target"]]
					var initial: Array = _person_walk_field_seed(fit, previous, u, rigid) if dense else (previous.get(u, []) as Array).duplicate()
					if initial.is_empty():
						initial = [(rigid[0] as Vector3) + (correction[0] as Vector3), (rigid[1] as Vector3) + (correction[1] as Vector3)]
					var height: float = _person_walk_height_at(table, u)
					# Fresh solves select S from this seed; no support state crosses phases.
					var cache_key: PackedByteArray = var_to_bytes([height, initial, [], true])
					var cached: Dictionary = cached_phases.get(u, {})
					var solved: Dictionary = {}
					if not cached.is_empty() and (cached["key"] as PackedByteArray) == cache_key:
						solved = cached["solved"]
						joint["cache_hits"] = int(joint["cache_hits"]) + 1
					else:
						_person_walk_pose(ctx, fit, entry, keyed_u)
						_apply_person_walk_body(ctx, fit, u, keyed_u, entry[4])
						budget["active_stage"] = "dense_verify" if dense else "coarse"
						solved = _solve_person_walk_frame(ctx, fit, u, initial, 1 if dense else PERSON_WALK_SKIN_EVALUATIONS, true, {}, dense, true)
						if dense and solved.has("continuation") and not bool(budget.get("exhausted", false)):
							fit["dense_refined_phases"].get_or_add(clip, {})[u] = true
							budget["active_stage"] = "dense_refine"
							solved = _solve_person_walk_frame(ctx, fit, u, [], PERSON_WALK_SKIN_EVALUATIONS - 1, true, solved["continuation"], false, true)
					var feedback: Dictionary = _person_walk_joint_feedback(solved)
					if not bool(solved["ok"]):
						if not bool(feedback["retry"]):
							next_field[clip] = next
							return {"ok": false, "reason": solved["reason"], "clip": clip, "phase": u, "solve": solved, "partial_target_field": next_field}
						unresolved += 1
						joint["feedback_frames"] = int(joint["feedback_frames"]) + 1
					else:
						cached_phases[u] = {"key": cache_key, "solved": solved}
						fit["stance_knee_min_deg"] = minf(float(fit["stance_knee_min_deg"]), float(solved["stance_knee_min_deg"]))
					knee_feedback = knee_feedback or bool(feedback["knee"]) or bool(solved.get("next_bounds", {}).get("empty", false))
					# The inner solve evaluates damped updates through the stricter joint gate.
					# Commit that measured state, and independently retain the full F(t)-t error.
					next[u] = (solved["targets_used"] as Array).duplicate()
					clip_heights[u] = solved["final_hips_y"]
					for side in 2:
						correction[side] = (next[u][side] as Vector3) - (rigid[side] as Vector3)
					var errors: Dictionary = _person_walk_joint_errors(solved, initial, height)
					input_field_verified = input_field_verified and bool(solved["ok"]) and var_to_bytes(initial) == var_to_bytes(solved["targets_used"])
					target_delta = maxf(target_delta, float(errors["target_m"]))
					fixed_point_delta = maxf(fixed_point_delta, float(errors["fixed_point_m"]))
					field_step_delta = maxf(field_step_delta, float(errors["displacement_m"]))
					height_delta = maxf(height_delta, float(errors["height_m"]))
					var score: float = float(solved["normalized_residual"])
					if score > worst_score:
						worst_score = score
						worst = {"reason": solved["reason"], "clip": clip, "phase": u, "solve": solved}
				next_field[clip] = next
				heights[clip] = clip_heights
			budget["active_stage"] = stage
			var note: Dictionary = {"stage": stage, "pass": stage_pass + 1, "unresolved": unresolved,
				"target_delta_m": target_delta, "fixed_point_delta_m": fixed_point_delta,
				"field_step_delta_m": field_step_delta, "height_delta_m": height_delta,
				"input_field_verified": input_field_verified,
				"mean": full.get("mean", 0.0), "saved_mean": full.get("saved_mean", 0.0), "table_ok": full["ok"],
				"ik_pairs": int(budget.get("used", {}).get("ik", 0)) - ik_before,
				"worst": _person_walk_skin_witness(worst)}
			joint["passes"].append(note)
			var converged: bool = unresolved == 0 and target_delta <= PERSON_WALK_JOINT_TARGET_TOL_M and height_delta <= PERSON_WALK_JOINT_HEIGHT_TOL_M and (not dense or input_field_verified)
			if knee_feedback:
				joint["knee_feedbacks"] = int(joint["knee_feedbacks"]) + 1
				var center_result: Dictionary = _person_walk_feedback_centers(ctx, fit, specs, next_field, heights)
				note["center_feedback"] = center_result
				if not bool(center_result["ok"]):
					fit["target_field"] = next_field
					return center_result
				var old_params: Dictionary = _person_walk_default_params(fit)
				var params: Dictionary = center_result["params"]
				var change: Array = [float(params["centers"][0]) - float(old_params["centers"][0]), float(params["centers"][1]) - float(old_params["centers"][1])]
				if maxf(absf(float(change[0])), absf(float(change[1]))) > 0.0:
					if not _person_walk_spend(budget, "paths", "shared"):
						return {"ok": false, "reason": "FOOT_PATH_BUDGET"}
					for clip: String in next_field:
						for u: float in next_field[clip]:
							for side in 2:
								next_field[clip][u][side] += Vector3(0.0, 0.0, float(change[side]))
					var extra: PackedFloat64Array = fit.get("height_extra_phases", PackedFloat64Array())
					fit.merge(_person_walk_with_params(fit, params), true)
					fit["height_extra_phases"] = extra
					solved_cache.clear()
					joint["center_updates"] = int(joint["center_updates"]) + 1
				converged = false
			if converged and not bool(full["ok"]):
				return {"ok": false, "reason": full["reason"], "table": full}
			var transition: String = _person_walk_joint_transition(stage, stage_pass + 1, converged, limit)
			if transition == "saved":
				# This exact input field produced the table and passed the dense IK gate.
				# A corrected field must return through projection before publication.
				fit["target_field"] = field
				budget["active_stage"] = "saved"
				joint["stage"] = "saved"
				var saved: Dictionary = _person_walk_validate_saved(ctx, fit, specs)
				if not bool(saved["ok"]):
					return saved
				return {"ok": true, "reason": "", "fit": fit, "saved": saved, "target_delta": target_delta, "height_delta": height_delta}
			field = next_field
			fit["target_field"] = field
			if transition == "dense" and not dense:
				break
			if transition.ends_with("_ITER_LIMIT"):
				return {"ok": false, "reason": transition, "clip": worst.get("clip", ""), "phase": worst.get("phase", -1.0), "solve": worst.get("solve", {})}
			var signature: String = var_to_bytes([field, table["values"], _person_walk_default_params(fit)]).hex_encode().sha256_text()
			var score: float = maxf(worst_score, maxf(target_delta / PERSON_WALK_JOINT_TARGET_TOL_M, height_delta / PERSON_WALK_JOINT_HEIGHT_TOL_M))
			var stopped: String = _person_walk_joint_progress(history, signature, score)
			if not stopped.is_empty():
				return {"ok": false, "reason": stopped, "clip": worst.get("clip", ""), "phase": worst.get("phase", -1.0), "solve": worst.get("solve", {})}
		if not dense:
			var extra: PackedFloat64Array = PackedFloat64Array()
			for sample in PERSON_WALK_DENSE_SAMPLES:
				extra.append(float(sample) / float(PERSON_WALK_DENSE_SAMPLES))
			fit["height_extra_phases"] = extra
			if not _person_walk_dense_reserve(budget, specs, _person_walk_validation_phases(fit).size()):
				joint["stage"] = "dense_reserve"
				return {"ok": false, "reason": "DENSE_BUDGET_RESERVE"}
	return {"ok": false, "reason": "DENSE_ITER_LIMIT"}


## Check fresh saved skin, including each foot's measured material stride.
static func _person_walk_validate_saved(ctx: Dictionary, fit: Dictionary, specs: Array) -> Dictionary:
	var measurements: Dictionary = {}
	for spec: Dictionary in specs:
		var entry: Array = spec["entry"]
		var clip: String = entry[0]
		ctx["walk_clip"] = clip
		var frames: Array = []
		var stats: Array = _person_footlock_stats()
		for frame in int(entry[2]):
			var u: float = float(frame) / float(entry[2])
			var keyed_u: float = fposmod(u + float(spec["shift"]), 1.0)
			pose(ctx, entry[1], entry[4], keyed_u)
			var before: Array = _person_footlock_points(fit, _skin_frame(ctx))
			var drop: float = _apply_person_walk_body(ctx, fit, u, keyed_u, entry[4])
			var solved: Dictionary = _solve_person_walk_frame(ctx, fit, u)
			if not bool(solved["ok"]):
				return {"ok": false, "reason": solved["reason"], "clip": clip, "phase": u, "solve": solved}
			var skin: Array = _skin_frame(ctx)
			frames.append(skin)
			_note_person_footlock(ctx, fit, u, before, _person_footlock_probes(fit, skin), solved["misses"], stats, drop)
		var rounds: Array = _person_walk_saved_rounds(fit, frames)
		for side in 2:
			var note: Dictionary = stats[side]
			var mean: float = float(note["hips_sum_m"]) / float(note["frames"])
			var contact: float = float(note["contacts"]) / float(note["frames"])
			var reason: String = ""
			if absf(float(rounds[side]) - float(fit["round"])) > float(fit["round"]) * STRIDE_TOLERANCE:
				reason = "SAVED_STRIDE"
			elif mean < PERSON_WALK_MEAN_MIN * float(fit["stand_ref_m"]):
				reason = "SAVED_MEAN"
			elif contact < 0.5:
				reason = "SAVED_CONTACT"
			elif _person_footlock_slide(note["after"]) > 2.0 or _person_footlock_slide(note["contact_after"]) > 2.0:
				reason = "SAVED_SLIDE"
			elif int(note["mid_samples"]) < 1 or float(note["mid_knee_max_deg"]) > 15.0:
				reason = "SAVED_MID_KNEE"
			elif int(note["reach_clamp_frames"]) > 0 or int(note["reach_final_fail_frames"]) > 0 or int(note["height_fail_frames"]) > 0 or int(note["knee_backward_frames"]) > 0:
				reason = "SAVED_REACH"
			if not reason.is_empty():
				return {"ok": false, "reason": reason, "clip": clip, "side": side, "stats": note, "rounds": rounds}
		measurements[clip] = {"stats": stats, "rounds": rounds}
	return {"ok": true, "reason": "", "measurements": measurements}


static func _person_walk_candidate_possible(candidate: Dictionary) -> bool:
	if not bool(candidate.get("complete", false)) or float(candidate["gap"]) > 0.0:
		return false
	if bool(candidate["detail"].get("horizontal_miss", false)):
		return false
	for intervals: Array in candidate["center_intervals"]:
		if intervals.is_empty():
			return false
	var fit: Dictionary = candidate["fit"]
	var target: float = float(fit["floor"]) + PERSON_WALK_MEAN_MIN * float(fit["stand_ref_m"])
	return minf(float(candidate["grid_cap"]), float(candidate["saved_cap"])) + PERSON_WALK_MEAN_EPSILON >= target


static func _person_walk_try_beam(state: Dictionary, limit: int = 6) -> Dictionary:
	var attempted: int = 0
	for candidate: Dictionary in state["beam"]:
		var id: int = candidate["id"]
		if not _person_walk_candidate_possible(candidate) or (state["skin_seen"] as Dictionary).has(id):
			continue
		if attempted >= limit:
			break
		if int(state["skin_count"]) >= int(state["skin_limit"]):
			state["limited"] = true
			break
		state["skin_seen"][id] = true
		state["skin_count"] = int(state["skin_count"]) + 1
		attempted += 1
		var source: Dictionary = (candidate["fit"] as Dictionary).duplicate()
		source["hip_over_stand_allowed"] = bool(state["base"].get("hip_over_stand_allowed", true))
		state["ctx"].get_or_add("walk_observation", {"actual_pairs": 0, "outside_pairs": 0}).merge({"candidate": id, "skin_count": state["skin_count"]}, true)
		var result: Dictionary = _fit_person_walk_candidate(state["ctx"], source, state["specs"])
		state["last_joint_attempt"] = result.get("joint", {})
		if str(result.get("reason", "")) == "HIP_TOL_STRAIGHT_KNEE":
			state["base"]["hip_over_stand_allowed"] = false
			source["hip_over_stand_allowed"] = false
			state["last_skin_failure"] = result
			if int(state["skin_count"]) < int(state["skin_limit"]):
				state["skin_count"] = int(state["skin_count"]) + 1
				state["ctx"]["walk_observation"]["skin_count"] = state["skin_count"]
				result = _fit_person_walk_candidate(state["ctx"], source, state["specs"])
				state["last_joint_attempt"] = result.get("joint", {})
			else:
				state["limited"] = true
		state["ctx"]["walk_observation"]["last_candidate"] = {"reason": result.get("reason", ""), "candidate": id, "skin_count": state["skin_count"]}
		if bool(result["ok"]):
			result["candidate"] = id
			return result
		state["trials"][id - 1]["skin"] = result
		var corrected_table: Dictionary = result.get("table", {})
		if corrected_table.has("center_intervals"):
			candidate["center_intervals"] = corrected_table["center_intervals"]
		if result.has("center_intervals"):
			candidate["center_intervals"] = result["center_intervals"]
		if str(result.get("reason", "")) != "FOOT_PATH_BUDGET":
			state["last_skin_failure"] = result
		if bool(state["base"]["work_budget"]["exhausted"]):
			state["limited"] = true
			break
	return {}


## Candidate failures are private; only the caller publishes final refusal.
static func _search_person_walk_path(ctx: Dictionary, fit: Dictionary, specs: Array, geometry_limit: int = PERSON_WALK_SEARCH_GEOMETRY, skin_limit: int = PERSON_WALK_SEARCH_SKIN, budget_limits: Dictionary = {}) -> Dictionary:
	ctx.get_or_add("walk_observation", {"actual_pairs": 0, "outside_pairs": 0})
	if ctx.has("dump_projection"):
		ctx["walk_projection_dump"] = ctx.get("walk_projection_dump", {})
	var local_ctx: Dictionary = ctx.duplicate()
	local_ctx["fit_failures"] = []
	var base: Dictionary = fit.duplicate()
	base["walk_specs"] = specs
	base["geometry_cache"] = {}
	base["bound_cache"] = {}
	base["pose_cache"] = {}
	base["work_budget"] = ctx.get_or_add("walk_work_budget", _person_walk_budget(budget_limits))
	var state: Dictionary = {"ctx": local_ctx, "base": base, "specs": specs, "beam": [], "seen": {}, "skin_seen": {},
		"geometry_count": 0, "skin_count": 0, "trials": [], "limited": false, "block_limited": false, "coverage": [], "last_skin_failure": {},
		"geometry_limit": clampi(geometry_limit, 1, PERSON_WALK_SEARCH_GEOMETRY), "skin_limit": clampi(skin_limit, 1, PERSON_WALK_SEARCH_SKIN)}
	_person_walk_add_path(state, _person_walk_default_params(base))
	var result: Dictionary = _person_walk_try_beam(state, 1)
	for _round_id in PERSON_WALK_SEARCH_ROUNDS:
		if not result.is_empty() or bool(state["limited"]):
			break
		for block in 5:
			var proposals: Array = _person_walk_path_block(state["beam"], block)
			var near_first: bool = _round_id == 0 and block == 0
			var allocation: Dictionary = _person_walk_allocate_paths(proposals, state["seen"], base["starts"], PERSON_WALK_BLOCK_PATHS, _person_walk_default_params(base) if near_first else {})
			state["block_limited"] = bool(state["block_limited"]) or int(allocation["omitted"]) > 0
			var before_count: int = state["geometry_count"]
			for params: Dictionary in allocation["selected"]:
				_person_walk_add_path(state, params)
				if near_first and not bool(state["limited"]):
					result = _person_walk_try_beam(state, 1)
				if not result.is_empty() or bool(state["limited"]):
					break
			var checked: int = int(state["geometry_count"]) - before_count
			state["coverage"].append({"round": _round_id, "block": block, "generated": proposals.size(), "unique_unseen": allocation["unique"], "checked": checked, "omitted": int(allocation["unique"]) - checked})
			if result.is_empty():
				result = _person_walk_try_beam(state)
			if not result.is_empty() or bool(state["limited"]):
				break
	if result.is_empty() and not bool(state["limited"]):
		result = _person_walk_try_beam(state, PERSON_WALK_SEARCH_SKIN)
	if result.is_empty():
		state["limited"] = bool(state["limited"]) or int(state["geometry_count"]) >= int(state["geometry_limit"]) or int(state["skin_count"]) >= int(state["skin_limit"])
		if bool(state["block_limited"]) and not bool(state["limited"]):
			base["work_budget"].merge({"exhausted": true, "kind": "block_paths", "clip": str(specs[0]["entry"][0])}, true)
		var best: Dictionary = state["beam"][0] if not (state["beam"] as Array).is_empty() else state.get("partial_candidate", {})
		result = {"ok": false, "reason": "SEARCH_LIMIT" if bool(state["limited"]) else "PATH_NOT_FOUND", "best": best}
		if bool(base["work_budget"]["exhausted"]):
			result["reason"] = "FOOT_PATH_BUDGET"
			var budget_clip: String = str(base["work_budget"]["clip"])
			if budget_clip == "shared":
				budget_clip = str(specs[0]["entry"][0])
			result["failure"] = "FOOT_PATH_BUDGET rig=%s clip=%s kind=%s used=%s" % [ctx.get("rig_label", "unknown"), budget_clip, base["work_budget"]["kind"], base["work_budget"]["used"]]
	result["budget"] = (base["work_budget"] as Dictionary).duplicate(true)
	result["geometry_count"] = state["geometry_count"]
	result["skin_count"] = state["skin_count"]
	result["trials"] = state["trials"]
	result["coverage"] = state["coverage"]
	result["last_skin_failure"] = state["last_skin_failure"]
	result["partial_candidate"] = state.get("partial_candidate", {})
	result["global_infeasible"] = false
	if not bool(result["ok"]):
		var best: Dictionary = result["best"]
		result["witness"] = {"params": best.get("params", _person_walk_default_params(base)), "detail": best.get("detail", {}),
			"geometry_reason": best.get("reason", "UNSAMPLED"), "budget_reason": result["reason"], "budget_kind": base["work_budget"]["kind"],
			"grid_cap": best.get("grid_cap", 0.0), "saved_cap": best.get("saved_cap", 0.0), "means_complete": best.get("means_complete", false),
			"candidate_complete": best.get("complete", false), "phases_checked": best.get("phases_checked", 0), "phases_total": best.get("phases_total", 0),
			"last_skin_failure": _person_walk_skin_witness(state["last_skin_failure"], ctx["walk_observation"]), "coverage": state["coverage"],
			"last_joint_attempt": state.get("last_joint_attempt", {}),
			"hip_over_stand_allowed": base.get("hip_over_stand_allowed", true), "global_infeasible": false}
	print("WALK_RIG_DIAGNOSTIC " + JSON.stringify({"rig": ctx.get("rig_label", "unknown"), "ok": result["ok"],
		"budget": result["budget"], "witness": result.get("witness", {}), "joint": result.get("joint", {})}))
	print("WALK_RIG_BUDGET_USE " + JSON.stringify({"source": "body_bake", "scope": "fit", "rig": ctx.get("rig_label", "unknown"), "ok": result["ok"],
		"used": result["budget"]["used"], "clips": result["budget"]["clips"], "stages": result["budget"].get("stages", {}),
		"stage_clips": result["budget"].get("stage_clips", {}), "skin_count": state["skin_count"], "observed": ctx["walk_observation"]}))
	return result


static func _person_walk_skin_witness(failure: Dictionary, observed: Dictionary = {}) -> Dictionary:
	var solve: Dictionary = failure.get("solve", {})
	var projection: Dictionary = failure.get("table", {}).get("projection", {})
	return {"reason": observed.get("last_candidate", {}).get("reason", failure.get("reason", "UNTRIED")), "clip": failure.get("clip", ""), "phase": failure.get("phase", -1.0),
		"last_attempt": observed.get("last_attempt", {}), "last_evaluated": observed.get("last_evaluated", {}), "skin_count": observed.get("skin_count", 0),
		"frame_ok": solve.get("ok", false), "frame_evaluated": solve.get("evaluated", false),
		"dynamic_verified": solve.get("dynamic_verified", false), "support_history": solve.get("support_history", []),
		"support_cycle_brackets": solve.get("support_cycle_brackets", 0),
		"projection_sweeps": projection.get("sweeps", 0), "projection_max_violation": projection.get("max_violation", 0.0),
		"bounds": solve.get("bounds", {}), "targets_used": solve.get("targets_used", []), "ik_passes": solve.get("ik_passes", 0),
		"conditions": solve.get("conditions", {}), "passes": solve.get("passes", []),
		"joint": failure.get("joint", {}), "next_bounds": solve.get("next_bounds", {}),
		"proposed_targets": solve.get("proposed_targets", []), "residual_vector": solve.get("residual_vector", []),
		"probes": solve.get("probes", []), "height_table_delta_m": solve.get("height_table_delta_m", 0.0),
		"rejections": solve.get("rejections", 0), "last_trial": solve.get("last_trial", {}),
		"skin_residual": solve.get("skin_residual", INF), "height_residual": solve.get("height_residual", INF)}


static func _note_person_walk_empty_height(ctx: Dictionary, table: Dictionary, u: float) -> void:
	var failures: Array = ctx.get_or_add("fit_failures", []) if not ctx.is_empty() else table.get_or_add("fit_failures", [])
	var failed: PackedInt32Array = table.get("failed_samples", PackedInt32Array())
	var cause: String = "POINT_EMPTY" if not failed.is_empty() else str(table.get("reason", "NOT_BUILT"))
	var failure: String = "PELVIS_TABLE_EMPTY rig=%s clip=%s phase=%.9f cause=%s" % [
		ctx.get("rig_label", table.get("rig_label", "unknown")), ctx.get("walk_clip", table.get("clip", "unknown")), u, cause]
	if not failures.has(failure):
		failures.append(failure)


static func _person_walk_height_at(table: Dictionary, u: float, ctx: Dictionary = {}) -> float:
	var values: PackedFloat64Array = table.get("values", PackedFloat64Array())
	if values.is_empty():
		_note_person_walk_empty_height(ctx, table, u)
		return NAN
	var slopes: PackedFloat64Array = table["slopes"]
	var position: float = fposmod(u, 1.0) * float(values.size())
	var index: int = int(floor(position))
	var next: int = (index + 1) % values.size()
	var t: float = position - float(index)
	var t2: float = t * t
	var t3: float = t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * values[index] + (t3 - 2.0 * t2 + t) * slopes[index] + (-2.0 * t3 + 3.0 * t2) * values[next] + (t3 - t2) * slopes[next]


## Set an absolute height: this cancels ALL main WALK_SINK (mean and bob).
## The return value remains signed EXTRA lowering relative to the keyed pose.
static func _apply_person_walk_body(ctx: Dictionary, fit: Dictionary, u: float, keyed_u: float, layer: String) -> float:
	var body: Skeleton3D = ctx["body"]
	var to_mesh: Transform3D = ctx["to_mesh"]
	var hips_id: int = _bone(body, "hips")
	_apply_person_walk_turn(ctx, fit, u, keyed_u, layer)
	var before_y: float = (to_mesh * body.get_bone_global_pose(hips_id)).origin.y
	fit["keyed_hips_y"] = before_y
	# The paired solver alone projects height against its current skin targets.
	var height: float = _person_walk_height_at(fit["pelvis"], u, ctx)
	if not is_finite(height):
		fit["height_frame_failed"] = true
		return 0.0
	_set_person_walk_hips_y(ctx, height)
	return before_y - height


static func _set_person_walk_hips_y(ctx: Dictionary, height: float) -> void:
	var body: Skeleton3D = ctx["body"]
	var to_mesh: Transform3D = ctx["to_mesh"]
	var hips_id: int = _bone(body, "hips")
	var hips: Vector3 = to_mesh * body.get_bone_global_pose(hips_id).origin
	hips.y = height
	var position: Vector3 = to_mesh.affine_inverse() * hips
	var parent: int = body.get_bone_parent(hips_id)
	if parent >= 0:
		position = body.get_bone_global_pose(parent).affine_inverse() * position
	body.set_bone_pose_position(hips_id, position)


## Freeze every walk's stride and phase before searching any path.
static func _prepare_person_walk_specs(ctx: Dictionary, requested: Array, phase: Dictionary) -> Array:
	var walk: Array = PERSON_CLIPS[0]
	var requested_name: String = requested[0]
	var walk_name: String = walk[0]
	if requested_name != walk_name:
		ctx.get_or_add("phase_fits", {}).erase("p_walk")
		_fit_person_stride(ctx, walk)
		var canonical: Dictionary = _fit_person_phase(ctx, walk)
		phase["shift"] = float(canonical.get("shift", 0.0))
	var specs: Array = []
	for entry: Array in PERSON_CLIPS:
		var clip: String = entry[0]
		if not PERSON_FOOT_LOCK.has(clip):
			continue
		if clip != requested_name:
			_fit_person_stride(ctx, entry)
		_fit_person_stride(ctx, entry, float(phase["shift"]))
		specs.append({"entry": entry, "shift": float(phase["shift"])})
	return specs


## Only a successful joint bundle enters the shared walk cache.
static func _fit_person_footlock(ctx: Dictionary, entry: Array, phase: Dictionary) -> Dictionary:
	if not entry[0] in PERSON_FOOT_LOCK:
		return {}
	ctx["walk_clip"] = entry[0]
	var refused: Dictionary = ctx.get("footlock_walk_refused", {})
	if not refused.is_empty() and absf(float(refused["shift"]) - float(phase.get("shift", 0.0))) <= 0.000000001:
		return refused["fit"]
	if ctx.has("footlock_walk"):
		var cached: Dictionary = ctx["footlock_walk"]
		var matches: bool = true
		for spec: Dictionary in cached.get("walk_specs", []):
			if absf(float(spec["shift"]) - float(phase.get("shift", 0.0))) > 0.000000001:
				matches = false
		if matches:
			return cached
		ctx.erase("footlock_walk")
	if phase.is_empty():
		return {}
	var specs: Array = _prepare_person_walk_specs(ctx, entry, phase)
	var contacts: Dictionary = ctx.get("phase_fits", {}).get("p_walk", {})
	if phase.is_empty() or contacts.is_empty() or float(contacts["left"]) < 0.0 or float(contacts["right"]) < 0.0:
		push_error("FOOTLOCK_STOP %s F-INPUT-MISSING no_sole_contact" % entry[0])
		return {}
	var body: Skeleton3D = ctx["body"]
	var mesh_node: MeshInstance3D = ctx["mesh_node"]
	var source: Array = mesh_node.get_meta(PERSON_PHASE_SOURCE) if mesh_node.has_meta(PERSON_PHASE_SOURCE) else mesh_node.mesh.surface_get_arrays(0)
	var rest: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = source[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = source[Mesh.ARRAY_WEIGHTS]
	if rest.is_empty() or bones.is_empty() or weights.size() != bones.size():
		push_error("FOOTLOCK_STOP %s F-INPUT-MISSING no_sole_skin" % entry[0])
		return {}
	var soles := person_sole_vertices(rest)
	var per: int = bones.size() / rest.size()
	var legs := []
	for side in 2:
		var suffix := ".L" if side == 0 else ".R"
		var leg := [_bone(body, "thigh" + suffix), _bone(body, "shin" + suffix), _bone(body, "foot" + suffix)]
		if leg.has(-1) or body.get_bone_parent(leg[1]) != leg[0] or body.get_bone_parent(leg[2]) != leg[1]:
			push_error("FOOTLOCK_STOP %s F-INPUT-MISSING leg_chain %s" % [entry[0], suffix])
			return {}
		legs.append(leg)
		# Include toe/heel corners that were not at the rest minimum, too.
		for vertex in rest.size():
			if _main_bone(body, ctx["skin"], bones, weights, per, vertex) == int(leg[2]) and not soles[side].has(vertex):
				soles[side].append(vertex)
		if soles[side].is_empty():
			push_error("FOOTLOCK_STOP %s F-INPUT-MISSING empty_sole %s" % [entry[0], suffix])
			return {}
	var stand: Array = []
	for candidate: Array in PERSON_CLIPS:
		var candidate_name: String = candidate[0]
		if candidate_name == "p_stand":
			stand = candidate
	var fit := {"rest": rest, "bones": bones, "weights": weights, "per": per, "soles": soles, "legs": legs,
		"starts": [], "durations": [], "anchors": [], "rest_ankles": [], "rotations": [], "round": float(PERSON_STRIDE_ROUNDS["p_walk"])}
	pose(ctx, stand[1], stand[4], 0.0)
	var standing := _person_footlock_points(fit, _skin_frame(ctx))
	fit["floor"] = minf((standing[0] as Vector3).y, (standing[1] as Vector3).y)
	var shift: float = phase["shift"]
	var left := fposmod(float(contacts["left"]) - shift, 1.0)
	var left_order := 0 if absf(wrapf(left - float(PERSON_STEP_AT[0]), -0.5, 0.5)) <= absf(wrapf(left - float(PERSON_STEP_AT[1]), -0.5, 0.5)) else 1
	# Preserve foot order, but place physical touchdown on STEP_AT exactly.
	fit["starts"] = [float(PERSON_STEP_AT[left_order]), float(PERSON_STEP_AT[1 - left_order])]
	var to_mesh: Transform3D = ctx["to_mesh"]
	for side in 2:
		var start: float = fit["starts"][side]
		var gap := fposmod(float(fit["starts"][1 - side]) - start, 1.0)
		fit["durations"].append(clampf(gap + PERSON_FOOTLOCK_OVERLAP, PERSON_FOOTLOCK_STANCE_MIN, PERSON_FOOTLOCK_STANCE_MAX))
		var foot: int = legs[side][2]
		var rest_foot := to_mesh * body.get_bone_global_rest(foot)
		var anchor := (to_mesh * body.get_bone_global_rest(legs[side][0])).origin
		anchor.z -= PERSON_WALK_FOOTPRINT_BACK
		# Centre the footprint under the hip, not at the old keyed touchdown.
		# Moving the support from heel to toe must not translate a planted shoe.
		fit["anchors"].append(anchor)
		fit["rest_ankles"].append(rest_foot.origin)
		fit["rotations"].append(rest_foot.basis.orthonormalized())
	fit["rest_hips_y"] = (to_mesh * body.get_bone_global_rest(_bone(body, "hips"))).origin.y
	fit["stand_ref_m"] = float(fit["rest_hips_y"]) - float(fit["floor"])
	var searched: Dictionary = _search_person_walk_path(ctx, fit, specs)
	if bool(searched["ok"]):
		fit = searched["fit"]
		fit["search"] = {"candidate": searched["candidate"], "geometry_count": searched["geometry_count"],
			"skin_count": searched["skin_count"], "trials": searched["trials"], "coverage": searched["coverage"], "budget": searched["budget"],
			"joint": searched.get("joint", {})}
		fit["pelvis"]["fit_failures"] = ctx.get_or_add("fit_failures", [])
		ctx["footlock_walk"] = fit
	else:
		var best: Dictionary = searched["best"]
		fit = best.get("fit", fit)
		fit["search"] = {"reason": searched["reason"], "geometry_count": searched["geometry_count"], "skin_count": searched["skin_count"],
			"trials": searched["trials"], "witness": searched["witness"], "budget": searched["budget"], "coverage": searched["coverage"]}
		fit["pelvis"] = {"ok": false, "values": PackedFloat64Array(), "slopes": PackedFloat64Array(), "uppers": PackedFloat64Array(),
			"lowers": PackedFloat64Array(), "failed_samples": PackedInt32Array(), "reason": searched["reason"],
			"mean": 0.0, "saved_mean": 0.0, "mean_feasible": false, "rig_label": ctx.get("rig_label", "unknown"),
			"clip": entry[0], "fit_failures": ctx.get_or_add("fit_failures", [])}
		var summary: String = "WALK_SEARCH_REFUSED rig=%s reason=%s geometry=%s budget=%s" % [ctx.get("rig_label", "unknown"), searched["reason"], searched["witness"]["geometry_reason"], searched["witness"]["budget_kind"]]
		ctx.get_or_add("fit_failures", []).append(summary)
		ctx["footlock_walk_refused"] = {"shift": float(phase["shift"]), "fit": fit}
	if not bool(ctx.get("walk_diagnostic_printed", false)):
		ctx["walk_diagnostic_printed"] = true
		print("WALK_RIG_DIAGNOSTIC " + JSON.stringify({"rig": ctx.get("rig_label", "unknown"), "ok": searched["ok"], "witness": searched.get("witness", {}), "budget": searched["budget"], "coverage": searched["coverage"]}))
		var knee_min: float = fit.get("stance_knee_min_deg", INF)
		print("WALK_STANCE_KNEE_MIN rig=%s deg=%s accepted=%s" % [ctx.get("rig_label", "unknown"), ("%.6f" % knee_min) if is_finite(knee_min) else "UNMEASURED", searched["ok"]])
	return fit


## Cosine-rule two-bone solve with a fixed forward pole and deterministic
## fallback; rotate only, never lengthen either bone. True means distance cut.
static func _solve_person_footlock_leg(body: Skeleton3D, leg: Array, target: Vector3, pole_hint: Vector3) -> bool:
	var hip := body.get_bone_global_pose(leg[0]).origin
	var knee := body.get_bone_global_pose(leg[1]).origin
	var ankle := body.get_bone_global_pose(leg[2]).origin
	var upper := hip.distance_to(knee)
	var lower := knee.distance_to(ankle)
	if minf(upper, lower) < 0.000001:
		return true
	var delta := target - hip
	var wanted := delta.length()
	var axis := delta / wanted if wanted > 0.000001 else (ankle - hip).normalized()
	var limit := sqrt(upper * upper + lower * lower + 2.0 * upper * lower * cos(PERSON_WALK_KNEE_MIN))
	var minimum: float = maxf(absf(upper - lower), 0.000001)
	var distance := clampf(wanted, minimum, limit)
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, upper * upper - along * along))
	var bend := pole_hint - axis * pole_hint.dot(axis)
	if bend.length_squared() < 0.0000001:
		var fallback := Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.UP
		bend = fallback - axis * fallback.dot(axis)
	var knee_target := hip + axis * along + bend.normalized() * height
	var ankle_target := hip + axis * distance
	var suffix := ".L" if int(leg[0]) == _bone(body, "thigh.L") else ".R"
	aim(body, "thigh" + suffix, "shin" + suffix, knee_target - hip)
	aim(body, "shin" + suffix, "foot" + suffix, ankle_target - body.get_bone_global_pose(leg[1]).origin)
	return wanted < minimum or wanted > limit


static func _person_walk_reach_info(body: Skeleton3D, leg: Array, target: Vector3) -> Dictionary:
	var hip: Vector3 = body.get_bone_global_pose(int(leg[0])).origin
	var knee: Vector3 = body.get_bone_global_pose(int(leg[1])).origin
	var ankle: Vector3 = body.get_bone_global_pose(int(leg[2])).origin
	var upper: float = hip.distance_to(knee)
	var lower: float = knee.distance_to(ankle)
	var wanted: float = hip.distance_to(target)
	var minimum: float = maxf(absf(upper - lower), 0.000001)
	var limit: float = sqrt(upper * upper + lower * lower + 2.0 * upper * lower * cos(PERSON_WALK_KNEE_MIN))
	return {"wanted": wanted, "minimum": minimum, "limit": limit, "excess": maxf(0.0, maxf(minimum - wanted, wanted - limit)), "invalid": minf(upper, lower) < 0.000001}


static func _apply_person_footlock(ctx: Dictionary, fit: Dictionary, u: float) -> Array:
	return _solve_person_walk_frame(ctx, fit, u)["misses"]


## Shared by the height-table projection and each actual frame evaluation.
static func _person_walk_height_inset(lower: float, upper: float, inset: float = PERSON_WALK_HEIGHT_INTERPOLATION_MARGIN) -> float:
	return minf(inset, maxf(0.0, upper - lower) * 0.25)


static func _person_walk_inner_height(wanted: float, bounds: Dictionary) -> float:
	var margin: float = _person_walk_height_inset(float(bounds["lower"]), float(bounds["upper"]))
	return clampf(wanted, float(bounds["lower"]) + margin, float(bounds["upper"]) - margin)


static func _person_walk_skin_conditions(residual: float, height_residual: float, height: float, next_bounds: Dictionary, misses: Array, knees: Array, middles: Array, stances: Array) -> Dictionary:
	var empty: bool = bool(next_bounds["empty"])
	var lower_gap: float = height - float(next_bounds["lower"])
	var upper_gap: float = float(next_bounds["upper"]) - height
	var ankle_ok: Array = []
	var mid_ok: Array = []
	var stance_ok: Array = []
	var actual_ok: bool = true
	for side in 2:
		ankle_ok.append(float(misses[side]) <= PERSON_WALK_ANKLE_TOL_M)
		mid_ok.append(not bool(middles[side]) or float(knees[side]) <= PERSON_WALK_MID_KNEE_MAX)
		stance_ok.append(not bool(stances[side]) or float(knees[side]) >= PERSON_WALK_KNEE_MIN)
		actual_ok = actual_ok and bool(ankle_ok[side]) and bool(mid_ok[side]) and bool(stance_ok[side])
	var target_ok: bool = residual <= PERSON_WALK_SKIN_TOL_M
	var height_ok: bool = height_residual <= PERSON_WALK_SKIN_HEIGHT_TOL_M
	var inside: bool = not empty and lower_gap >= 0.0 and upper_gap >= 0.0
	return {"target_residual_m": residual, "target_ok": target_ok, "height_residual_m": height_residual,
		"height_ok": height_ok, "next_bounds_empty": empty, "next_bounds_ok": not empty,
		"height_minus_next_lower_m": lower_gap, "next_upper_minus_height_m": upper_gap,
		"lower_ok": lower_gap >= 0.0, "upper_ok": upper_gap >= 0.0, "height_inside": inside,
		"ankle_miss_m": misses.duplicate(), "ankle_ok": ankle_ok, "knee_rad": knees.duplicate(),
		"knee_deg": [rad_to_deg(float(knees[0])), rad_to_deg(float(knees[1]))],
		"middle": middles.duplicate(), "mid_knee_ok": mid_ok, "stance": stances.duplicate(),
		"stance_knee_ok": stance_ok, "actual_ok": actual_ok,
		"ok": target_ok and height_ok and inside and actual_ok}


## Snapshot only state mutated by a trial; the budget ledger is never rolled back.
static func _person_walk_skin_snapshot(body: Skeleton3D, fit: Dictionary, support_sets: Array = []) -> Dictionary:
	var pose: Array = []
	for bone in body.get_bone_count():
		pose.append([body.get_bone_pose_position(bone), body.get_bone_pose_rotation(bone), body.get_bone_pose_scale(bone)])
	return {"pose": pose, "reach_clamped": (fit["reach_clamped"] as Array).duplicate(),
		"reach_final_failed": (fit["reach_final_failed"] as Array).duplicate(), "height_frame_failed": fit["height_frame_failed"],
		"support_sets": support_sets.duplicate(true)}


static func _person_walk_skin_restore(body: Skeleton3D, fit: Dictionary, state: Dictionary) -> void:
	for bone in body.get_bone_count():
		body.set_bone_pose_position(bone, state["pose"][bone][0])
		body.set_bone_pose_rotation(bone, state["pose"][bone][1])
		body.set_bone_pose_scale(bone, state["pose"][bone][2])
	fit["reach_clamped"] = (state["reach_clamped"] as Array).duplicate()
	fit["reach_final_failed"] = (state["reach_final_failed"] as Array).duplicate()
	fit["height_frame_failed"] = bool(state["height_frame_failed"])


## Evaluate F(t) from the same keyed pose, including both IK solves and new skin.
static func _person_walk_skin_evaluate(ctx: Dictionary, fit: Dictionary, u: float, goals: Array, targets: Array, wanted_h: float, baseline: Dictionary, support_sets: Array = []) -> Dictionary:
	_person_walk_observe(ctx, fit, u, "attempt")
	var body: Skeleton3D = ctx["body"]
	var to_mesh: Transform3D = ctx["to_mesh"]
	var to_body: Transform3D = to_mesh.affine_inverse()
	_person_walk_skin_restore(body, fit, baseline)
	var bounds: Dictionary = _person_walk_height_bounds(ctx, fit, u, targets)
	var result: Dictionary = {"reason": "", "evaluated": false, "bounds": bounds, "targets_used": targets.duplicate(),
		"proposed_targets": [], "misses": [INF, INF], "skin_residual": INF, "height_residual": INF,
		"normalized_residual": INF, "conditions": {"ok": false}}
	if bool(bounds["empty"]):
		result["reason"] = "POINT_EMPTY"
		return result
	var height: float = _person_walk_inner_height(wanted_h, bounds)
	_set_person_walk_hips_y(ctx, height)
	var pre_reach: Array = []
	for side in 2:
		var info: Dictionary = _person_walk_reach_info(body, fit["legs"][side], to_body * (targets[side] as Vector3))
		pre_reach.append(info)
		fit["reach_final_failed"][side] = bool(info["invalid"]) or float(info["excess"]) > 0.0
	if bool(fit["reach_final_failed"][0]) or bool(fit["reach_final_failed"][1]):
		result["reason"] = "PRE_IK_REACH"
		return result
	if not _person_walk_spend(fit.get("work_budget", {}), "ik", str(ctx.get("walk_clip", "unknown"))):
		result["reason"] = "FOOT_PATH_BUDGET"
		return result
	result["evaluated"] = true
	_person_walk_observe(ctx, fit, u, "pair")
	for side in 2:
		fit["reach_clamped"][side] = _solve_person_footlock_leg(body, fit["legs"][side], to_body * (targets[side] as Vector3), to_body.basis * Vector3.BACK)
	var cut: bool = bool(fit["reach_clamped"][0]) or bool(fit["reach_clamped"][1])
	for side in 2:
		var rotation: Quaternion = (to_body.basis * (goals[side]["rotation"] as Basis)).orthonormalized().get_rotation_quaternion()
		_person_footlock_rotation(body, int(fit["legs"][side][2]), rotation)
	var skin: Array = _skin_frame(ctx)
	var dynamic_probes: Array = _person_footlock_probes(fit, skin)
	var dynamic: Dictionary = _person_walk_skin_measure(ctx, fit, u, goals, targets, wanted_h, bounds, cut, dynamic_probes)
	if support_sets.is_empty():
		result = dynamic.duplicate(true)
	else:
		result = _person_walk_skin_measure(ctx, fit, u, goals, targets, wanted_h, bounds, cut, _person_footlock_probes(fit, skin, support_sets))
	result["pre_reach"] = pre_reach
	dynamic["pre_reach"] = pre_reach
	# Both measurements share this actual paired IK and full-sole minimum y.
	result["dynamic"] = dynamic
	return result


static func _person_walk_skin_measure(ctx: Dictionary, fit: Dictionary, u: float, goals: Array, targets: Array, wanted_h: float, bounds: Dictionary, cut: bool, probes: Array) -> Dictionary:
	var body: Skeleton3D = ctx["body"]
	var to_mesh: Transform3D = ctx["to_mesh"]
	var to_body: Transform3D = to_mesh.affine_inverse()
	var result: Dictionary = {"evaluated": true, "bounds": bounds, "targets_used": targets.duplicate(), "misses": [INF, INF]}
	var proposed: Array = []
	var ankles: Array = []
	var proposal_reach: Array = []
	var residual_vector: Array = []
	var knees: Array = []
	var middles: Array = []
	var stances: Array = []
	var residual: float = 0.0
	var norm_squared: float = 0.0
	for side in 2:
		var leg: Array = fit["legs"][side]
		var ankle: Vector3 = to_mesh * body.get_bone_global_pose(int(leg[2])).origin
		ankles.append(ankle)
		var offset: Vector3 = (probes[side]["point"] as Vector3) - ankle
		var flat_offset: Vector3 = (probes[side]["rest"] as Vector3) - (fit["rest_ankles"][side] as Vector3)
		var target: Vector3 = (goals[side]["base"] as Vector3) + flat_offset - offset
		target.y = float(fit["floor"]) + (goals[side]["path"] as Vector3).y - offset.y
		proposed.append(target)
		proposal_reach.append(_person_walk_reach_info(body, leg, to_body * target))
		var delta: Vector3 = target - (targets[side] as Vector3)
		residual_vector.append(delta)
		residual = maxf(residual, delta.length())
		var miss: float = ankle.distance_to(targets[side])
		result["misses"][side] = miss
		fit["reach_final_failed"][side] = miss > PERSON_WALK_ANKLE_TOL_M
		norm_squared += delta.length_squared() / (PERSON_WALK_SKIN_TOL_M * PERSON_WALK_SKIN_TOL_M) + pow(miss / PERSON_WALK_ANKLE_TOL_M, 2.0)
		var mid: float = float(goals[side]["age"]) / float(fit["durations"][side])
		middles.append(mid >= 0.40 and mid <= 0.60)
		stances.append(float(goals[side]["age"]) <= float(fit["durations"][side]))
		var thigh: Vector3 = to_mesh * body.get_bone_global_pose(int(leg[0])).origin
		var knee: Vector3 = to_mesh * body.get_bone_global_pose(int(leg[1])).origin
		knees.append((knee - thigh).angle_to(ankle - knee))
	# Measure the actual hips after IK; a small height residual never waives inclusion.
	var actual_h: float = (to_mesh * body.get_bone_global_pose(_bone(body, "hips"))).origin.y
	var next_bounds: Dictionary = _person_walk_height_bounds(ctx, fit, u, proposed)
	var height_residual: float = INF
	if not bool(next_bounds["empty"]):
		height_residual = absf(_person_walk_inner_height(wanted_h, next_bounds) - actual_h)
	var conditions: Dictionary = _person_walk_skin_conditions(residual, height_residual, actual_h, next_bounds, result["misses"], knees, middles, stances)
	norm_squared += pow(height_residual / PERSON_WALK_SKIN_HEIGHT_TOL_M, 2.0)
	norm_squared += pow(maxf(0.0, -float(conditions["height_minus_next_lower_m"])) / PERSON_WALK_SKIN_HEIGHT_TOL_M, 2.0)
	norm_squared += pow(maxf(0.0, -float(conditions["next_upper_minus_height_m"])) / PERSON_WALK_SKIN_HEIGHT_TOL_M, 2.0)
	for side in 2:
		if bool(middles[side]):
			norm_squared += pow(maxf(0.0, float(knees[side]) - PERSON_WALK_MID_KNEE_MAX) / PERSON_WALK_MID_KNEE_MAX, 2.0)
		if bool(stances[side]):
			norm_squared += pow(maxf(0.0, PERSON_WALK_KNEE_MIN - float(knees[side])) / PERSON_WALK_KNEE_MIN, 2.0)
	var branch: int = _person_walk_skin_height_branch(wanted_h, bounds)
	# Owners and lower/free/upper branch, plus the exact selected sole vertices.
	var selected: Array = [probes[0]["vertices"], probes[1]["vertices"]]
	var signature: String = str([selected, int(bounds["lower_side"]), int(bounds["upper_side"]),
		int(next_bounds["lower_side"]), int(next_bounds["upper_side"]), branch, _person_walk_skin_height_branch(wanted_h, next_bounds)])
	var command_height: float = _person_walk_inner_height(wanted_h, bounds)
	result.merge({"proposed_targets": proposed, "actual_ankles": ankles, "probes": probes,
		"support_sets": selected, "support_signature": str(selected),
		"proposal_reach": proposal_reach, "height": actual_h, "command_height": command_height, "table_height": wanted_h,
		"height_command_error_m": actual_h - command_height, "height_table_delta_m": actual_h - wanted_h,
		"skin_residual": residual, "height_residual": height_residual, "next_bounds": next_bounds,
		"residual_vector": residual_vector, "normalized_residual": sqrt(norm_squared), "conditions": conditions,
		"signature": signature, "reason": "IK_CUT" if cut else ""}, true)
	return result


static func _person_walk_skin_height_branch(wanted: float, bounds: Dictionary) -> int:
	if bool(bounds["empty"]):
		return 2
	var margin: float = _person_walk_height_inset(float(bounds["lower"]), float(bounds["upper"]))
	if wanted < float(bounds["lower"]) + margin:
		return -1
	if wanted > float(bounds["upper"]) - margin:
		return 1
	return 0


## Vector Aitken uses the dot product over BOTH three-dimensional foot residuals.
static func _person_walk_aitken(previous: Dictionary, current: Dictionary, previous_omega: float) -> float:
	if previous.is_empty() or str(previous["signature"]) != str(current["signature"]):
		return previous_omega
	var numerator: float = 0.0
	var denominator: float = 0.0
	for side in 2:
		var old: Vector3 = previous["residual_vector"][side]
		var delta: Vector3 = (current["residual_vector"][side] as Vector3) - old
		numerator += old.dot(delta)
		denominator += delta.length_squared()
	if denominator <= PERSON_WALK_AITKEN_DENOM_M2:
		return previous_omega
	return clampf(-previous_omega * numerator / denominator, PERSON_WALK_AITKEN_MIN, PERSON_WALK_AITKEN_MAX)


static func _person_walk_skin_improves(previous: Dictionary, trial: Dictionary) -> bool:
	return str(trial["reason"]).is_empty() and float(trial["normalized_residual"]) < float(previous["normalized_residual"]) - PERSON_WALK_SKIN_PROGRESS


static func _person_walk_skin_cycle(older: Dictionary, trial: Dictionary) -> bool:
	if older.is_empty() or not trial.has("height"):
		return false
	if str(older.get("support_signature", "")) != str(trial.get("support_signature", "")):
		return false
	if absf(float(older["height"]) - float(trial["height"])) > PERSON_WALK_SKIN_CYCLE_M:
		return false
	for side in 2:
		if (older["targets_used"][side] as Vector3).distance_to(trial["targets_used"][side]) > PERSON_WALK_SKIN_CYCLE_M:
			return false
	return true


static func _person_walk_skin_ready(state: Dictionary, joint_precision: bool = false) -> bool:
	if not str(state.get("reason", "")).is_empty() or not bool(state.get("conditions", {}).get("ok", false)):
		return false
	return not joint_precision or (float(state["skin_residual"]) <= PERSON_WALK_JOINT_TARGET_TOL_M and float(state["height_residual"]) <= PERSON_WALK_JOINT_HEIGHT_TOL_M)


## A zero field displacement cannot replace the actual undamped fixed-point error.
static func _person_walk_joint_errors(solved: Dictionary, initial: Array, table_height: float) -> Dictionary:
	var residual: float = 0.0
	var displacement: float = 0.0
	for side in 2:
		var used: Vector3 = solved["targets_used"][side]
		residual = maxf(residual, (solved["proposed_targets"][side] as Vector3).distance_to(used))
		displacement = maxf(displacement, (initial[side] as Vector3).distance_to(used))
	return {"fixed_point_m": residual, "displacement_m": displacement,
		"target_m": residual,
		"height_m": maxf(absf(float(solved["final_hips_y"]) - table_height), float(solved["height_residual"]))}


## Opposite dynamic residuals bracket a candidate on the chord between supports.
## This is only a search direction; full dynamic gates still decide success.
static func _person_walk_support_bracket(first: Dictionary, second: Dictionary) -> Dictionary:
	var direction: Array = []
	var length_squared: float = 0.0
	for side in 2:
		var delta: Vector3 = (second["targets_used"][side] as Vector3) - (first["targets_used"][side] as Vector3)
		direction.append(delta)
		length_squared += delta.length_squared()
	if length_squared <= PERSON_WALK_SKIN_CYCLE_M * PERSON_WALK_SKIN_CYCLE_M:
		return {}
	var left_value: float = 0.0
	var right_value: float = 0.0
	for side in 2:
		direction[side] /= sqrt(length_squared)
		left_value += (first["residual_vector"][side] as Vector3).dot(direction[side])
		right_value += (second["residual_vector"][side] as Vector3).dot(direction[side])
	if not is_finite(left_value) or not is_finite(right_value) or left_value * right_value >= 0.0:
		return {}
	return {"left": (first["targets_used"] as Array).duplicate(), "right": (second["targets_used"] as Array).duplicate(),
		"direction": direction, "left_value": left_value, "right_value": right_value}


static func _person_walk_support_midpoint(bracket: Dictionary) -> Array:
	if bracket.is_empty():
		return []
	var targets: Array = []
	var at_left: bool = true
	var at_right: bool = true
	for side in 2:
		var target: Vector3 = (bracket["left"][side] as Vector3).lerp(bracket["right"][side], 0.5)
		targets.append(target)
		at_left = at_left and target == (bracket["left"][side] as Vector3)
		at_right = at_right and target == (bracket["right"][side] as Vector3)
	return [] if at_left or at_right else targets


static func _person_walk_support_narrow(bracket: Dictionary, trial: Dictionary) -> Dictionary:
	if not bool(trial.get("evaluated", false)) or not str(trial.get("reason", "")).is_empty():
		return {}
	var value: float = 0.0
	for side in 2:
		value += (trial["residual_vector"][side] as Vector3).dot(bracket["direction"][side])
	# A zero projected residual cannot certify the other five components.
	if not is_finite(value) or value == 0.0:
		return {}
	var narrowed: Dictionary = bracket.duplicate(true)
	var endpoint: String = "left" if (value > 0.0) == (float(bracket["left_value"]) > 0.0) else "right"
	narrowed[endpoint] = (trial["targets_used"] as Array).duplicate()
	narrowed[endpoint + "_value"] = value
	return narrowed


## Every trial restarts from the keyed pose. Only measured improvements commit.
static func _solve_person_walk_frame(ctx: Dictionary, fit: Dictionary, u: float, target_seed: Array = [], iteration_limit: int = PERSON_WALK_SKIN_EVALUATIONS, accelerate: bool = true, continuation: Dictionary = {}, suspend: bool = false, joint_precision: bool = false) -> Dictionary:
	var body: Skeleton3D = ctx["body"]
	var goals: Array = []
	var targets: Array = target_seed.duplicate()
	if targets.is_empty():
		targets = (fit.get("target_field", {}).get(str(ctx.get("walk_clip", "p_walk")), {}).get(fposmod(u, 1.0), []) as Array).duplicate()
	var seeded: bool = not targets.is_empty()
	for side in 2:
		goals.append(_person_walk_ankle_goal(fit, side, u))
		if not seeded:
			targets.append(goals[side]["target"])
	fit["reach_clamped"] = [false, false]
	fit["reach_final_failed"] = [false, false]
	fit["height_frame_failed"] = false
	fit.erase("skin_support_sets")
	var baseline: Dictionary = _person_walk_skin_snapshot(body, fit)
	var wanted_h: float = _person_walk_height_at(fit["pelvis"], u, ctx)
	var current: Dictionary = {"targets_used": [], "proposed_targets": [], "misses": [INF, INF],
		"skin_residual": INF, "height_residual": INF, "bounds": _person_walk_height_bounds(ctx, fit, u, targets)}
	if not is_finite(wanted_h):
		current.merge({"ik_passes": 0, "passes": []})
		return _finish_person_walk_frame(ctx, fit, u, current, "PELVIS_TABLE_EMPTY")
	var limit: int = clampi(iteration_limit, 1, PERSON_WALK_SKIN_EVALUATIONS)
	var evaluations: int = 0
	var rejections: int = 0
	var stalled: int = 0
	var passes: Array = []
	var previous: Dictionary = {}
	var accepted_pose: Dictionary = baseline
	var omega: float = 1.0
	var accepted_omega: float = omega
	var support_sets: Array = []
	var support_history: Array = []
	var support_states: Dictionary = {}
	var support_bracket: Dictionary = {}
	var support_cycle_brackets: int = 0
	var reason: String = "SKIN_ITER_LIMIT"
	var last_trial: Dictionary = {}
	if not continuation.is_empty():
		baseline = continuation["baseline"]
		goals = continuation["goals"]
		targets = (continuation["targets"] as Array).duplicate()
		wanted_h = float(continuation["wanted_h"])
		current = continuation["current"]
		previous = continuation["previous"]
		accepted_pose = continuation["accepted_pose"]
		omega = float(continuation["omega"])
		accepted_omega = float(continuation["accepted_omega"])
		support_sets = (continuation["support_sets"] as Array).duplicate(true)
		support_history = (continuation["support_history"] as Array).duplicate()
		support_states = (continuation.get("support_states", {}) as Dictionary).duplicate(true)
		support_bracket = (continuation.get("support_bracket", {}) as Dictionary).duplicate(true)
		support_cycle_brackets = int(continuation.get("support_cycle_brackets", 0))
		joint_precision = bool(continuation["joint_precision"])
		evaluations = int(continuation["evaluations"])
		rejections = int(continuation["rejections"])
		stalled = int(continuation["stalled"])
		passes = (continuation["passes"] as Array).duplicate()
		limit = mini(PERSON_WALK_SKIN_EVALUATIONS, evaluations + limit)
		_person_walk_skin_restore(body, fit, accepted_pose)
	while evaluations < limit:
		var bracketing: bool = not support_bracket.is_empty()
		var trial: Dictionary = _person_walk_skin_evaluate(ctx, fit, u, goals, targets, wanted_h, baseline, [] if bracketing else support_sets)
		if bool(trial["evaluated"]):
			evaluations += 1
		var initial: bool = passes.is_empty()
		var accepted: bool = initial or _person_walk_skin_improves(current, trial) or (bracketing and _person_walk_skin_ready(trial, joint_precision))
		var cycle: bool = not bracketing and not initial and _person_walk_skin_cycle(previous, trial)
		if cycle:
			accepted = false
		if not accepted:
			rejections += 1
			stalled += 1
		trial["omega"] = omega
		trial["search_mode"] = "support_bracket" if bracketing else "local"
		trial["accepted"] = accepted
		trial["rejections"] = rejections
		trial["ik_passes"] = evaluations
		passes.append(trial.duplicate(true))
		last_trial = trial
		if accepted:
			previous = current if not initial else {}
			current = trial
			accepted_omega = omega
			if not previous.is_empty() and str(previous.get("signature", "")) != str(current.get("signature", "")):
				previous = {}
			if not bracketing and current.has("support_sets") and support_sets.is_empty():
				support_sets = (current["support_sets"] as Array).duplicate(true)
				support_history.append(current["support_signature"])
			accepted_pose = _person_walk_skin_snapshot(body, fit, current.get("support_sets", []))
			stalled = 0
		else:
			_person_walk_skin_restore(body, fit, accepted_pose)
		if str(trial["reason"]) == "FOOT_PATH_BUDGET":
			reason = "FOOT_PATH_BUDGET"
			break
		if initial and not str(trial["reason"]).is_empty():
			reason = str(trial["reason"])
			break
		# Success precedes the limit: the final evaluated state can still converge.
		if accepted and _person_walk_skin_ready(current, joint_precision):
			var dynamic: Dictionary = current["dynamic"]
			if _person_walk_skin_ready(dynamic, joint_precision):
				current["dynamic_verified"] = true
				accepted_pose["support_sets"] = (dynamic["support_sets"] as Array).duplicate(true)
				reason = ""
				break
			var selected: String = str(dynamic["support_signature"])
			support_states[str(current["support_signature"])] = {"state": dynamic.duplicate(true), "pose": accepted_pose.duplicate(true), "omega": accepted_omega}
			if support_history.has(selected):
				var other: Dictionary = support_states.get(selected, {})
				support_bracket = _person_walk_support_bracket(other["state"], dynamic) if not other.is_empty() else {}
				support_history.append(selected)
				if support_bracket.is_empty():
					reason = "SKIN_SUPPORT_CYCLE"
					break
				# Retain the better measured endpoint while spending the remaining cap
				# on dynamic probes between them. No frozen-set solution is published.
				support_cycle_brackets += 1
				current = dynamic.duplicate(true)
				if float(other["state"]["normalized_residual"]) < float(current["normalized_residual"]):
					current = (other["state"] as Dictionary).duplicate(true)
					accepted_pose = (other["pose"] as Dictionary).duplicate(true)
					accepted_omega = float(other["omega"])
				current["dynamic"] = current.duplicate(true)
				_person_walk_skin_restore(body, fit, accepted_pose)
				support_sets = []
				previous = {}
				stalled = 0
				targets = _person_walk_support_midpoint(support_bracket)
				omega = 0.5
				if targets.is_empty():
					reason = "SKIN_SUPPORT_CYCLE"
					break
				continue
			# Rebase both residuals on the same new set; the paired pose is unchanged.
			support_history.append(selected)
			support_sets = (dynamic["support_sets"] as Array).duplicate(true)
			current = dynamic.duplicate(true)
			current["dynamic"] = dynamic.duplicate(true)
			previous = {}
			accepted_pose["support_sets"] = support_sets.duplicate(true)
		if bracketing:
			support_bracket = _person_walk_support_narrow(support_bracket, trial)
			targets = _person_walk_support_midpoint(support_bracket)
			if targets.is_empty():
				reason = "SKIN_SUPPORT_CYCLE"
				break
			omega = 0.5
			continue
		if cycle or stalled >= PERSON_WALK_SKIN_STALL_TRIALS:
			reason = "SKIN_CYCLE" if cycle else "SKIN_STALLED"
			break
		if evaluations >= limit and not suspend:
			break
		if accepted:
			omega = _person_walk_aitken(previous, current, accepted_omega) if accelerate else 1.0
		else:
			omega = maxf(PERSON_WALK_AITKEN_MIN, omega * 0.5)
		for side in 2:
			targets[side] = (current["targets_used"][side] as Vector3) + omega * (current["residual_vector"][side] as Vector3)
	if reason == "SKIN_ITER_LIMIT" and not support_bracket.is_empty() and (not suspend or evaluations >= PERSON_WALK_SKIN_EVALUATIONS):
		reason = "SKIN_SUPPORT_CYCLE"
	# Keep failed trial diagnostics, but return only the last accepted pose/state.
	_person_walk_skin_restore(body, fit, accepted_pose)
	current = current.duplicate(true)
	var local_state: Dictionary = current.duplicate(true)
	# Public residuals always describe the original dynamic contact selection.
	if current.has("dynamic"):
		current.merge(current["dynamic"], true)
	current.merge({"ik_passes": evaluations, "passes": passes, "rejections": rejections, "last_trial": last_trial.duplicate(true)}, true)
	current["support_history"] = support_history.duplicate()
	current["accepted_omega"] = accepted_omega
	current["support_cycle_brackets"] = support_cycle_brackets
	if suspend and reason == "SKIN_ITER_LIMIT" and evaluations < PERSON_WALK_SKIN_EVALUATIONS:
		# This is the next bounded trial, not the untested full F(t) proposal.
		current["continuation"] = {"baseline": baseline, "goals": goals, "targets": targets.duplicate(),
			"wanted_h": wanted_h, "current": local_state, "previous": previous,
			"accepted_pose": accepted_pose, "omega": omega, "evaluations": evaluations,
			"accepted_omega": accepted_omega, "support_sets": support_sets.duplicate(true),
			"support_history": support_history.duplicate(), "joint_precision": joint_precision,
			"support_states": support_states.duplicate(true), "support_bracket": support_bracket.duplicate(true),
			"support_cycle_brackets": support_cycle_brackets,
			"rejections": rejections, "stalled": stalled, "passes": passes.duplicate()}
	return _finish_person_walk_frame(ctx, fit, u, current, reason)


static func _finish_person_walk_frame(ctx: Dictionary, fit: Dictionary, u: float, result: Dictionary, reason: String) -> Dictionary:
	var body: Skeleton3D = ctx["body"]
	var to_mesh: Transform3D = ctx["to_mesh"]
	var final_y: float = (to_mesh * body.get_bone_global_pose(_bone(body, "hips"))).origin.y
	var knee_min: float = _person_walk_stance_knee_min(ctx, fit, u)
	result["stance_knee_min_deg"] = knee_min
	if reason.is_empty():
		fit["stance_knee_min_deg"] = minf(float(fit.get("stance_knee_min_deg", INF)), knee_min)
		if not _person_walk_tolerance_knee_ok(fit, final_y, knee_min):
			reason = "HIP_TOL_STRAIGHT_KNEE"
	result["ok"] = reason.is_empty()
	result["reason"] = reason
	result["final_hips_y"] = (to_mesh * body.get_bone_global_pose(_bone(body, "hips"))).origin.y
	result["reach_clamped"] = (fit["reach_clamped"] as Array).duplicate()
	result["reach_final_failed"] = (fit["reach_final_failed"] as Array).duplicate()
	result["actual_ankles"] = []
	for side in 2:
		var ankle: Vector3 = to_mesh * body.get_bone_global_pose(int(fit["legs"][side][2])).origin
		result["actual_ankles"].append(ankle)
		if (result["targets_used"] as Array).size() == 2:
			result["misses"][side] = ankle.distance_to(result["targets_used"][side])
	fit["height_frame_failed"] = not reason.is_empty()
	# A live continuation belongs to the caller, not to the next frame's fit.
	fit.erase("skin_support_sets")
	fit["walk_solve"] = result.duplicate()
	fit["walk_solve"].erase("continuation")
	if not reason.is_empty():
		var bounds: Dictionary = result["bounds"]
		var failure: String = "WALK_SOLVE_FAIL rig=%s clip=%s stage=skin reason=%s ik_pass=%d phase=%.9f lower_m=%.9f upper_m=%.9f gap_mm=%.6f lower_side=%d upper_side=%d target_delta_mm=%.6f height_delta_mm=%.6f" % [
			ctx.get("rig_label", "unknown"), ctx.get("walk_clip", "unknown"), reason, result["ik_passes"], u,
			bounds["lower"], bounds["upper"], (float(bounds["lower"]) - float(bounds["upper"])) * 1000.0,
			bounds["lower_side"], bounds["upper_side"], float(result["skin_residual"]) * 1000.0, float(result["height_residual"]) * 1000.0]
		var failures: Array = ctx.get_or_add("fit_failures", [])
		if not failures.has(failure):
			failures.append(failure)
	_person_walk_observe(ctx, fit, u, "frame", result)
	return result


static func _person_walk_tolerance_knee_ok(fit: Dictionary, hips_y: float, knee_min_deg: float) -> bool:
	return hips_y <= float(fit["rest_hips_y"]) or knee_min_deg >= rad_to_deg(PERSON_WALK_KNEE_MIN)


static func _person_walk_stance_knee_min(ctx: Dictionary, fit: Dictionary, u: float) -> float:
	var body: Skeleton3D = ctx["body"]
	var to_mesh: Transform3D = ctx["to_mesh"]
	var minimum: float = INF
	for side in 2:
		if fposmod(u - float(fit["starts"][side]), 1.0) > float(fit["durations"][side]):
			continue
		var leg: Array = fit["legs"][side]
		var thigh: Vector3 = to_mesh * body.get_bone_global_pose(int(leg[0])).origin
		var knee: Vector3 = to_mesh * body.get_bone_global_pose(int(leg[1])).origin
		var ankle: Vector3 = to_mesh * body.get_bone_global_pose(int(leg[2])).origin
		minimum = minf(minimum, rad_to_deg((knee - thigh).angle_to(ankle - knee)))
	return minimum


## Sample the same frames that enter the VAT, with stance-relative travel
## unwrapped across u=0. No height threshold hides a slipping stance frame.
static func _person_footlock_stats() -> Array:
	var stats: Array = []
	for _side in 2:
		stats.append({"before": [], "after": [], "contact_after": [], "miss": 0.0, "minimum": INF, "frames": 0, "contacts": 0, "hip_drop": 0.0,
			"hips_sum_m": 0.0, "hips_drop_max_cm": 0.0, "mid_knee_max_deg": 0.0, "mid_samples": 0,
			"reach_clamp_frames": 0, "reach_final_fail_frames": 0, "height_fail_frames": 0, "knee_forward_min_m": INF, "knee_backward_frames": 0})
	return stats


## Joint measurements must be taken after the final IK, alongside the skin.
static func _note_person_footlock(ctx: Dictionary, fit: Dictionary, u: float, before: Array, after: Array, misses: Array, stats: Array, hip_drop: float) -> void:
	var body: Skeleton3D = ctx["body"]
	var to_mesh: Transform3D = ctx["to_mesh"]
	var hips: Vector3 = to_mesh * body.get_bone_global_pose(_bone(body, "hips")).origin
	if fit.has("keyed_hips_y"):
		hip_drop = float(fit["keyed_hips_y"]) - hips.y
	for side in 2:
		var note: Dictionary = stats[side]
		var age := fposmod(u - float(fit["starts"][side]), 1.0)
		var probe: Dictionary = after[side]
		var point: Vector3 = probe["point"]
		var flat_offset: Vector3 = (probe["rest"] as Vector3) - (fit["rest_ankles"][side] as Vector3)
		var residual := Vector2(point.x - flat_offset.x, point.z + age * float(fit["round"]) - flat_offset.z)
		note["frames"] += 1
		note["hip_drop"] += hip_drop
		note["hips_sum_m"] += hips.y - float(fit["floor"])
		note["hips_drop_max_cm"] = maxf(float(note["hips_drop_max_cm"]), (float(fit["rest_hips_y"]) - hips.y) * 100.0)
		if bool(fit["reach_clamped"][side]):
			note["reach_clamp_frames"] += 1
		if bool(fit["reach_final_failed"][side]):
			note["reach_final_fail_frames"] += 1
		if bool(fit["height_frame_failed"]):
			note["height_fail_frames"] += 1
		var leg: Array = fit["legs"][side]
		var thigh: Vector3 = to_mesh * body.get_bone_global_pose(int(leg[0])).origin
		var knee: Vector3 = to_mesh * body.get_bone_global_pose(int(leg[1])).origin
		var foot: Vector3 = to_mesh * body.get_bone_global_pose(int(leg[2])).origin
		var mid: float = age / float(fit["durations"][side])
		if mid >= 0.40 and mid <= 0.60:
			note["mid_samples"] += 1
			note["mid_knee_max_deg"] = maxf(float(note["mid_knee_max_deg"]), rad_to_deg((knee - thigh).angle_to(foot - knee)))
		var axis: Vector3 = (foot - thigh).normalized()
		var pole: Vector3 = Vector3.BACK - axis * Vector3.BACK.dot(axis)
		var forward: float = (knee - thigh).dot(pole.normalized())
		note["knee_forward_min_m"] = minf(float(note["knee_forward_min_m"]), forward)
		if forward < -0.00001:
			note["knee_backward_frames"] += 1
		var touching := absf(point.y - float(fit["floor"])) <= PERSON_WALK_CONTACT_EPSILON
		if touching:
			note["contacts"] += 1
		if age <= float(fit["durations"][side]):
			note["before"].append((before[side] as Vector3).z + age * float(fit["round"]))
			note["after"].append(residual)
			if touching:
				note["contact_after"].append(residual)
		note["minimum"] = minf(float(note["minimum"]), point.y)
		note["miss"] = maxf(float(note["miss"]), float(misses[side]))


## Bounding-box diagonal includes lateral drift as well as forward slip.
static func _person_footlock_slide(points: Array) -> float:
	if points.is_empty():
		return INF
	var low: Vector2 = points[0]
	var high := low
	for point: Vector2 in points:
		low = low.min(point)
		high = high.max(point)
	return low.distance_to(high) * 100.0


static func _print_person_footlock(clip: String, fit: Dictionary, stats: Array) -> void:
	for side in 2:
		var note: Dictionary = stats[side]
		var before: Array = note["before"]
		var after: Array = note["after"]
		var foot := "L" if side == 0 else "R"
		if before.is_empty() or after.is_empty() or not is_finite(float(note["minimum"])):
			push_error("FOOTLOCK_STOP %s F-INPUT-MISSING no_frame_samples %s" % [clip, foot])
			continue
		var start: float = fit["starts"][side]
		var slide_before := (float(before.max()) - float(before.min())) * 100.0
		var slide_after := _person_footlock_slide(after)
		var underground := maxf(0.0, float(fit["floor"]) - float(note["minimum"])) * 100.0
		var contact_share := float(note["contacts"]) / float(note["frames"])
		var hip_drop_cm := float(note["hip_drop"]) / float(note["frames"]) * 100.0
		var hips_mean_m: float = float(note["hips_sum_m"]) / float(note["frames"])
		var stand_ref_m: float = fit["stand_ref_m"]
		var height_fail_samples: int = (fit["pelvis"]["failed_samples"] as PackedInt32Array).size()
		print("FOOTLOCK %s %s stance %.6f %.6f slide_before_cm %.4f slide_after_cm %.4f reach_miss_cm %.4f under_ground_cm %.4f contact_share %.6f hip_drop_cm %.4f contact_slide_cm %.4f mid_knee_max_deg %.4f mid_samples %d hips_mean_m %.6f stand_ref_m %.6f hips_ratio %.6f hips_drop_max_cm %.4f height_fail_samples %d height_fail_frames %d reach_clamp_frames %d reach_final_fail_frames %d knee_forward_min_m %.6f knee_backward_frames %d" % [
			clip, foot, start, start + float(fit["durations"][side]), slide_before, slide_after, float(note["miss"]) * 100.0, underground, contact_share, hip_drop_cm, _person_footlock_slide(note["contact_after"]),
			note["mid_knee_max_deg"], note["mid_samples"], hips_mean_m, stand_ref_m, hips_mean_m / stand_ref_m, note["hips_drop_max_cm"], height_fail_samples, note["height_fail_frames"], note["reach_clamp_frames"], note["reach_final_fail_frames"], note["knee_forward_min_m"], note["knee_backward_frames"]])


## One skin matrix per bone the mesh binds: pose * inverse bind, in mesh space.
static func _skin_frame(ctx: Dictionary) -> Array:
	var body: Skeleton3D = ctx["body"]
	var skin: Skin = ctx["skin"]
	var bind_bone: Array = ctx["bind_bone"]
	var mats := []
	for j in bind_bone.size():
		mats.append((ctx["to_mesh"] as Transform3D) * body.get_bone_global_pose(bind_bone[j]) * skin.get_bind_pose(j))
	# A mesh-space neck bind, also when a garment has no weighted neck vertex.
	var to_mesh: Transform3D = ctx["to_mesh"]
	var neck: int = _bone(body, "neck")
	mats.append(to_mesh * body.get_bone_global_pose(neck) * body.get_bone_global_rest(neck).affine_inverse() * to_mesh.affine_inverse())
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
	var rig_label: String = body_root.scene_file_path.get_file().get_basename() if not body_root.scene_file_path.is_empty() else str(body_root.name)
	var ctx := {"source": source, "player": player, "body": body, "mesh_node": mesh_node, "rig_label": rig_label, "ref": {}, "map": {}, "rest_rot": {}, "hip0": _world(source, source.find_bone(MAP["hips"])).origin}
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


## Decision 535: leave mesh topology alone; only two VAT columns have no triangles.
## Shells retain source skin weights. Generated bags must never turn with the head.
static func _bake_head(ctx: Dictionary, clips: Array) -> Dictionary:
	var body: Skeleton3D = ctx["body"]
	var mesh_node: MeshInstance3D = ctx["mesh_node"]
	var source: Array = mesh_node.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = source[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = source[Mesh.ARRAY_WEIGHTS]
	if positions.is_empty() or bones.is_empty() or weights.size() != bones.size():
		return _person_bake_failure(ctx, "BAKE_EMPTY_SKIN", "vat")
	if clips.is_empty():
		return _person_bake_failure(ctx, "BAKE_EMPTY_FRAMES", "vat")
	for clip: Dictionary in clips:
		if (clip.get("frames", []) as Array).is_empty():
			return _person_bake_failure(ctx, "BAKE_EMPTY_FRAMES", str(clip.get("name", "unknown")))
	var per: int = bones.size() / positions.size()
	var head := _bone(body, "head")
	var neck := _bone(body, "neck")
	var shares := PackedFloat32Array()
	shares.resize(positions.size())
	if not mesh_node.has_meta("head_layer_bag"):
		for v in positions.size():
			var share := 0.0
			for k in per:
				var bone: int = ctx["bind_bone"][bones[v * per + k]]
				share += weights[v * per + k] * (1.0 if bone == head else (0.5 if bone == neck else 0.0))
			shares[v] = clampf(share, 0.0, 1.0)
	source[Mesh.ARRAY_CUSTOM0] = shares
	var neck_rest: Transform3D = (ctx["to_mesh"] as Transform3D) * body.get_bone_global_rest(neck)
	var pivot := neck_rest.origin
	var up := pivot + neck_rest.basis.y.normalized() * 0.1
	var bind: int = (ctx["bind_bone"] as Array).size()
	var probes := [{"rest": pivot, "bone": bind}, {"rest": up, "bone": bind}]
	var out: Dictionary = _with_rounds(VatBaker.build_skinned(source, clips, VatBaker.MAX_WIDTH, probes), clips)
	var reason: String = _person_bake_output_error(out)
	if not reason.is_empty():
		return _person_bake_failure(ctx, reason, "vat")
	return out


static func _person_bake_failure(ctx: Dictionary, reason: String, clip: String) -> Dictionary:
	var failure: String = "%s rig=%s clip=%s" % [reason, ctx.get("rig_label", "unknown"), clip]
	var failures: Array = ctx.get_or_add("fit_failures", [])
	if not failures.has(failure):
		failures.append(failure)
	return {"ok": false, "bake_error": reason, "fit_failures": failures.duplicate()}


static func _person_bake_output_error(assets: Dictionary) -> String:
	if not (assets.get("fit_failures", []) as Array).is_empty():
		return str(assets.get("bake_error", "BAKE_FIT_REFUSED"))
	if not assets.get("image") is Image:
		return "BAKE_EMPTY_IMAGE"
	var image: Image = assets["image"]
	if image.is_empty() or image.get_data().is_empty():
		return "BAKE_EMPTY_IMAGE"
	if not assets.get("mesh") is Mesh:
		return "BAKE_EMPTY_MESH"
	var mesh: Mesh = assets["mesh"]
	if mesh.get_surface_count() < 1:
		return "BAKE_EMPTY_MESH"
	if assets.has("head"):
		var arrays: Array = mesh.surface_get_arrays(0)
		var custom: Variant = arrays[Mesh.ARRAY_CUSTOM0]
		var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		if custom is PackedByteArray:
			if (custom as PackedByteArray).size() != count * 4:
				return "BAKE_EMPTY_CUSTOM0"
		elif custom is PackedFloat32Array:
			if (custom as PackedFloat32Array).size() != count:
				return "BAKE_EMPTY_CUSTOM0"
		else:
			return "BAKE_EMPTY_CUSTOM0"
	return ""


## Remove each bone's rest orientation before comparing anatomical +Z forwards.
## Chest +Y is the body's posed up axis; project forwards onto its normal plane.
## Positive radians follow right-handed rotation about that axis (shader alike).
static func _head_yaw(ctx: Dictionary) -> float:
	var body: Skeleton3D = ctx["body"]
	var to_mesh: Basis = (ctx["to_mesh"] as Transform3D).basis
	var chest := _bone(body, "chest")
	var head := _bone(body, "head")
	var chest_turn := (to_mesh * body.get_bone_global_pose(chest).basis * body.get_bone_global_rest(chest).basis.inverse() * to_mesh.inverse()).orthonormalized()
	var head_turn := (to_mesh * body.get_bone_global_pose(head).basis * body.get_bone_global_rest(head).basis.inverse() * to_mesh.inverse()).orthonormalized()
	var axis := chest_turn.y.normalized()
	var forward := chest_turn.z.slide(axis)
	var facing := head_turn.z.slide(axis)
	if forward.length_squared() < 0.000001 or facing.length_squared() < 0.000001:
		return 0.0
	return forward.normalized().signed_angle_to(facing.normalized(), axis)


static func _head_yaw_stats(samples: Array) -> Array:
	if samples.is_empty():
		return [0.0, 0.0, 0.0]
	var total := 0.0
	var low := INF
	var high := -INF
	for sample: float in samples:
		total += sample
		low = minf(low, sample)
		high = maxf(high, sample)
	return [clampf(total / float(samples.size()), low, high), low, high]


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
	if phase_mesh != null and phase_mesh.has_meta("head_layer_bag"):
		phase_mesh.remove_meta("head_layer_bag")
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
	mesh_node.set_meta("head_layer_bag", true)
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
	var flags: int = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if eight else 0
	if src[Mesh.ARRAY_CUSTOM0] != null:
		flags |= Mesh.ARRAY_CUSTOM_R_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src, [], {}, flags)
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
	var clips := []
	ctx["phase_fits"] = {}
	ctx["fit_failures"] = []
	ctx.erase("footlock_walk")
	ctx.erase("footlock_walk_refused")
	ctx.erase("walk_work_budget")
	ctx["stand_failures"] = {}
	for entry: Array in list:
		ctx["walk_clip"] = entry[0]
		var phase: Dictionary = {}
		var prepared: Dictionary = ctx.get("footlock_walk", {})
		if entry[0] in PERSON_FOOT_LOCK and prepared.has("walk_specs"):
			phase = {"shift": float(prepared["walk_specs"][0]["shift"])}
		else:
			_fit_person_stride(ctx, entry)
			phase = _fit_person_phase(ctx, entry)
			if entry[0] in PERSON_FOOT_LOCK and not phase.is_empty():
				_fit_person_stride(ctx, entry, float(phase["shift"]))
		# The foot lock and pelvis table follow the phase on the fitted stride;
		# the final phase check below reads the locked, saved frames.
		var footlock := _fit_person_footlock(ctx, entry, phase)
		if entry[0] in PERSON_FOOT_LOCK and (footlock.is_empty() or (footlock.get("pelvis", {}).get("values", PackedFloat64Array()) as PackedFloat64Array).is_empty()):
			return _person_bake_failure(ctx, "BAKE_WALK_REFUSED", str(entry[0]))
		var footlock_stats: Array = _person_footlock_stats() if not footlock.is_empty() else []
		var head_yaws := []
		var count: int = entry[2]
		var looped: bool = entry[3]
		var frames := []
		var reach := [[], []]
		for f in count:
			# A loop's last frame stops one step short of the first; a one-shot ends on its end.
			var output_u: float = float(f) / float(count) if looped else float(f) / float(count - 1)
			var u := fposmod(output_u + float(phase["shift"]), 1.0) if not phase.is_empty() else output_u
			pose(ctx, entry[1], entry[4], u, entry[0])
			var skin := _skin_frame(ctx)
			if not footlock.is_empty():
				var before := _person_footlock_points(footlock, skin)
				var hip_drop := _apply_person_walk_body(ctx, footlock, output_u, u, entry[4])
				var misses := _apply_person_footlock(ctx, footlock, output_u)
				# Failed solves must not publish the untouched keyed pose as a walk.
				if not bool(footlock["walk_solve"]["ok"]):
					return _person_bake_failure(ctx, "BAKE_WALK_REFUSED", str(entry[0]))
				skin = _skin_frame(ctx)
				_note_person_footlock(ctx, footlock, output_u, before, _person_footlock_probes(footlock, skin), misses, footlock_stats, hip_drop)
			frames.append(skin)
			head_yaws.append(_head_yaw(ctx))
			_note_reach(ctx, entry[0], reach)
		if not footlock.is_empty():
			_print_person_footlock(entry[0], footlock, footlock_stats)
		var length := float(entry[5]) if entry[1] == "" else player.get_animation(entry[1]).length * _span_share(entry[4])
		if not phase.is_empty():
			_check_person_phase_final(ctx, entry[0], _person_sole_heights_from_frames(ctx, frames, true))
		var stride_round: float = _round(reach)
		if PERSON_STRIDE_ROUNDS.has(entry[0]):
			var grid_round := stride_round
			var fine := _person_stride_reach(ctx, entry)
			if entry[0] in PERSON_FOOT_LOCK:
				if footlock.is_empty():
					stride_round = 0.0
					ctx.get_or_add("fit_failures", []).append("STRIDE_FINAL %s no_footlock" % entry[0])
				else:
					stride_round = _check_person_stride_final(ctx, entry[0], frames, footlock)
			else:
				stride_round = _check_person_stride_final(ctx, entry[0], fine)
			# For the record: the same legs measured from where the saved loop starts, and each foot.
			var at_shift := _person_stride_round(ctx, entry, float(phase["shift"])) if not phase.is_empty() else stride_round
			var saved_sides: Array = _person_walk_saved_rounds(footlock, frames) if not footlock.is_empty() else [round_of(fine[0]), round_of(fine[1])]
			print("STRIDE_SAVED %s round %.6f at_shift %.6f frames_round %.6f left %.6f right %.6f" % [entry[0], stride_round, at_shift, grid_round, saved_sides[0], saved_sides[1]])
		var clip := {"name": entry[0], "loop": looped, "length": length, "frames": frames, "round": stride_round if looped else 0.0, "head_yaw": _head_yaw_stats(head_yaws)}
		if PERSON_STRIDE_ROUNDS.has(entry[0]):
			var step_off := _person_step_off(ctx, frames)
			for side in 2:
				if float(step_off[side]) < 0.0:
					print("STEP_OFF_MISS %s %s" % [entry[0], "L" if side == 0 else "R"])
			if float(step_off[0]) >= 0.0 and float(step_off[1]) >= 0.0:
				clip["step_off"] = step_off
		clips.append(clip)
	var still := []
	var still_yaws := []
	for entry: Array in poses:
		_pose_at(ctx, entry[0], entry[1], {})
		apply_overlay(ctx["body"], entry[2])
		still.append(_skin_frame(ctx))
		still_yaws.append(_head_yaw(ctx))
	if not still.is_empty():
		clips.append({"name": POSES_CLIP, "loop": false, "length": 1.0, "frames": still, "head_yaw": _head_yaw_stats(still_yaws)})
	var out := _bake_head(ctx, clips)
	# Support, pelvis, stride and phase failures reach the save refusal.
	if not (ctx["fit_failures"] as Array).is_empty() and not out.is_empty():
		out["fit_failures"] = ctx["fit_failures"]
	return out


## Bakes the body in `body_root` (in the scene tree) with the motions written
## here alone: `list` in order (OWN_CLIPS, or the living's that take nothing from a motion set),
## then one POSES_CLIP of `poses` when there are any. Nothing in the result
## comes from a motion set. {} if something is missing.
static func bake_own(body_root: Node3D, list: Array = OWN_CLIPS, poses: Array = OWN_POSES) -> Dictionary:
	var ctx := prepare_own(body_root, list + poses)
	if ctx.is_empty():
		return {}
	var clips := []
	for entry: Array in list:
		var count: int = entry[2]
		var looped: bool = entry[3]
		var frames := []
		var reach := [[], []]
		var head_yaws := []
		for f in count:
			var u: float = float(f) / float(count) if looped else float(f) / float(count - 1)
			pose(ctx, "", entry[4], u, entry[0])
			frames.append(_skin_frame(ctx))
			head_yaws.append(_head_yaw(ctx))
			_note_reach(ctx, entry[0], reach)
		clips.append({"name": entry[0], "loop": looped, "length": float(entry[5]), "frames": frames, "round": _round(reach) if looped else 0.0, "head_yaw": _head_yaw_stats(head_yaws)})
	var still := []
	var still_yaws := []
	for entry: Array in poses:
		pose(ctx, "", entry[0], entry[1])
		apply_overlay(ctx["body"], entry[2])
		still.append(_skin_frame(ctx))
		still_yaws.append(_head_yaw(ctx))
	if not still.is_empty():
		clips.append({"name": POSES_CLIP, "loop": false, "length": 1.0, "frames": still, "head_yaw": _head_yaw_stats(still_yaws)})
	var out: Dictionary = _bake_head(ctx, clips)
	if not (ctx.get("fit_failures", []) as Array).is_empty() and not out.is_empty():
		out["fit_failures"] = ctx["fit_failures"]
	return out


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
		out["clips"][n]["head_yaw"] = clips[n].get("head_yaw", [0.0, 0.0, 0.0])
		if clips[n].has("step_off"):
			out["clips"][n]["step_off"] = clips[n]["step_off"]
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
	var reason: String = _person_bake_output_error(assets)
	if not reason.is_empty():
		return _person_bake_failure(assets, reason, "compact")
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
	if bytes.is_empty():
		return _person_bake_failure(assets, "BAKE_EMPTY_COMPACT", "compact")
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
	if assets.has("head"):
		out["head"] = (assets["head"] as Dictionary).duplicate(true)
		var error := 0.0
		for got: Array in picked:
			error = maxf(error, ((got[2] as Vector3) - (got[1] as Vector3)).length() / 255.0)
		# Each of vertex and pivot rounds by at most half a texel quantum.
		out["head"]["radius"] = float(assets["head"]["radius"]) + error
	return out


## Writes vat.bin (the picture's half floats as they are: an exported game
## cannot read EXR; a compacted bake's bytes), mesh.res and clips.json into `dir`.
static func save(assets: Dictionary, dir: String) -> void:
	var reason: String = _person_bake_output_error(assets)
	if not reason.is_empty():
		var refused: Dictionary = _person_bake_failure(assets, reason, "save")
		push_error(str(refused["fit_failures"][-1]))
		return
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
	for key in ["columns", "head"]:
		if assets.has(key):
			info[key] = assets[key]
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
		row["head_yaw"] = clip.get("head_yaw", [0.0, 0.0, 0.0])
		if clip.has("step_off"):
			row["step_off"] = clip["step_off"]
		if small:
			row["lo"] = clip.get("lo", [0.0, 0.0, 0.0])
			row["hi"] = clip.get("hi", [0.0, 0.0, 0.0])
		clips.append(row)
	var out := {"mesh": mesh, "texture": ImageTexture.create_from_image(image), "vertices": int(info["vertices"]), "width": image.get_width(), "rows_per_frame": int(info["rows_per_frame"]), "height": image.get_height(), "image": image, "clips": clips}
	for key in ["columns", "head"]:
		if info.has(key):
			out[key] = info[key]
	if small:
		out["format"] = SMALL_FORMAT
	return out
