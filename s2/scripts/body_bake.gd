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
]
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
# length is what is baked). Those written here come first, so a bake with no
# motion set keeps their numbers; the field finds each by its name. Thirty-two at most:
# the shader's clip tables have thirty-two places (dead_vat.gdshader); numbers
# 16 and up are written with VatBaker.pack_motion.
const PERSON_CLIPS: Array = [
	["p_walk", "", 32, true, "p_walk", 0.78],
	["p_run", "", 24, true, "p_run", 0.58],
	["p_stand", "", 32, true, "p_stand", 4.0],
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
	# From the two free motion sets (UAL1_Standard.glb and UAL2_Standard.glb, read together).
	["p_reload", "Pistol_Reload", 32, false, "", 1.667],
	["p_climb", "ClimbUp_1m", 20, false, "", 0.667],
	["p_kneel_work", "Fixing_Kneeling", 32, true, "p_kneel_work", 3.12],
	# A low lid and a knockback nothing played made way for these two blows: an
	# axe chopped in from the side (UAL's sword blows turn the hips round 69 to
	# 160 degrees, the chop 34).
	["p_chop_side", "TreeChopping_Loop", 24, false, "", 0.967],
	["p_pickup", "PickUp_Table", 24, false, "", 0.833],
]
# Played once and quick: every frame kept in the small bake (bake_body_cli --keep).
const PERSON_KEEP: Array = ["p_bitten", "p_swing_one", "p_swing_axe", "p_stab", "p_shove", "p_floor_strike", "p_stomp", "p_kick", "p_climb", "p_swing_back", "p_chop_side", "p_pickup"]
const POSES_CLIP: String = "poses"
const ROUND_LEAST: float = 0.05               # a loop whose feet go back less than this a round is standing
const CRAWL_CLIP: String = "crawl"            # pulled along by its hands, not its feet
const PERSON_CRAWL_CLIP: String = "p_crawl"   # the same for the living
const HIP_HEIGHT: float = 1.0                 # the hips the layers' sinks were written for, metres

# Layers: a hand-made addition on top of a motion. For a frame at progress u
# (0..1), w = TAU * u, and a layer holds:
#   "warp": [size, lag]       read the motion at u + size * sin(w - lag) (uneven cadence)
#   "span": [from, to]        play only that part of the motion (0..1 of its length)
#   "damp": {bone: share}     the share (0..1) of the motion's turn that bone keeps
#   "steps": [...]            applied in order after the bones are matched:
#       ["turn", bone, axis, value]       bend a bone about "x" (forward), "y" (twist) or "z" (sideways)
#       ["aim", bone, child, [x, y, z]]   point a bone at a direction in the body's space
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
	# Leaning a little into it, knees high, elbows bent and pumping.
	"p_run": {
		"steps": [
			["turn", "hips", "z", [0.0, 0.05, 0.0]],
			["turn", "hips", "y", [0.0, -0.12, 0.0]],
			["aim", "thigh.L", "shin.L", [0.07, -1.0, [[0.12, 0.6, 0.0], [0.0, -0.06, 0.0, 3.0], [0.0, 0.02, 0.0, 5.0]]]],
			["aim", "shin.L", "foot.L", [0.05, -1.0, [[-0.5, 0.55, 0.0], [0.0, -0.06, 0.0, 3.0], [0.0, 0.02, 0.0, 5.0], [0.0, -0.55, -1.5708], [0.0, -0.2, -1.5708, 2.0]]]],
			["aim", "thigh.R", "shin.R", [-0.07, -1.0, [[0.12, 0.6, 3.1416], [0.0, -0.06, 9.4248, 3.0], [0.0, 0.02, 15.708, 5.0]]]],
			["aim", "shin.R", "foot.R", [-0.05, -1.0, [[-0.5, 0.55, 3.1416], [0.0, -0.06, 9.4248, 3.0], [0.0, 0.02, 15.708, 5.0], [0.0, -0.55, 1.5708], [0.0, -0.2, 4.7124, 2.0]]]],
			["turn", "spine", "x", 0.15],
			["turn", "chest", "x", 0.05],
			["turn", "chest", "y", [0.0, 0.16, 0.0]],
			["turn", "neck", "x", -0.12],
			["aim", "upper_arm.L", "forearm.L", [0.2, -1.0, [0.0, -0.55, 0.0]]],
			["aim", "forearm.L", "hand.L", [0.05, [0.2, 0.25, 0.0], [0.9, -0.2, 0.0]]],
			["aim", "upper_arm.R", "forearm.R", [-0.2, -1.0, [0.0, 0.55, 0.0]]],
			["aim", "forearm.R", "hand.R", [-0.05, [0.2, -0.25, 0.0], [0.9, 0.2, 0.0]]],
		],
		"sink": [0.07, 0.04, -1.5708, 2.0],
	},
	# Standing easy: breathing, the weight drifting from one foot to the other.
	"p_stand": {
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
			["aim", "upper_arm.L", "forearm.L", [0.14, -1.0, [0.02, 0.01, 0.0, 4.0]]],
			["aim", "forearm.L", "hand.L", [0.08, -1.0, 0.1]],
			["aim", "upper_arm.R", "forearm.R", [-0.14, -1.0, [0.02, 0.01, 0.0, 4.0]]],
			["aim", "forearm.R", "hand.R", [-0.08, -1.0, 0.1]],
		],
		"sink": [0.0, 0.004, 0.0, 4.0],
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
	# Crouched walk: hips low, knees well bent, back forward, feet kept low,
	# head up to see ahead, arms low in front.
	"p_crouch_walk": {
		"steps": [
			["turn", "hips", "y", [0.0, -0.06, 0.0]],
			["aim", "thigh.L", "shin.L", [0.12, -1.0, [[1.3, 0.65, 0.0], [0.0, -0.05, 0.0, 3.0]]]],
			["aim", "shin.L", "foot.L", [0.08, -1.0, [[-0.75, 0.5, 0.0], [0.0, -0.22, -1.5708]]]],
			["aim", "thigh.R", "shin.R", [-0.12, -1.0, [[1.3, 0.65, 3.1416], [0.0, -0.05, 9.4248, 3.0]]]],
			["aim", "shin.R", "foot.R", [-0.08, -1.0, [[-0.75, 0.5, 3.1416], [0.0, -0.22, 1.5708]]]],
			["turn", "spine", "x", 0.5],
			["turn", "chest", "x", 0.1],
			["turn", "chest", "y", [0.0, 0.08, 0.0]],
			["turn", "neck", "x", -0.4],
			["aim", "upper_arm.L", "forearm.L", [0.2, -1.0, [0.5, -0.15, 0.0]]],
			["aim", "forearm.L", "hand.L", [0.0, -0.6, 1.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.2, -1.0, [0.5, 0.15, 0.0]]],
			["aim", "forearm.R", "hand.R", [0.0, -0.6, 1.0]],
		],
		"sink": [0.22, 0.015, -1.5708, 2.0],
	},
	# The same low crouch kept still, breathing.
	"p_crouch_idle": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.15, -1.0, 1.45]],
			["aim", "shin.L", "foot.L", [0.1, -1.0, -0.75]],
			["aim", "thigh.R", "shin.R", [-0.15, -1.0, 1.35]],
			["aim", "shin.R", "foot.R", [-0.1, -1.0, -0.8]],
			["turn", "spine", "x", [0.5, 0.02, 0.0]],
			["turn", "chest", "x", [0.1, 0.02, 0.0]],
			["turn", "neck", "x", -0.4],
			["turn", "head", "y", [0.0, 0.2, 0.5]],
			["aim", "upper_arm.L", "forearm.L", [0.2, -1.0, 0.45]],
			["aim", "forearm.L", "hand.L", [0.0, -0.7, 1.0]],
			["aim", "upper_arm.R", "forearm.R", [-0.2, -1.0, 0.45]],
			["aim", "forearm.R", "hand.R", [0.0, -0.7, 1.0]],
		],
		"sink": [0.23, 0.006, 0.0],
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
	for entry: Array in list:
		var count: int = entry[2]
		var looped: bool = entry[3]
		var frames := []
		var reach := [[], []]
		for f in count:
			# A loop's last frame stops one step short of the first; a one-shot ends on its end.
			var u: float = float(f) / float(count) if looped else float(f) / float(count - 1)
			pose(ctx, entry[1], entry[4], u)
			frames.append(_skin_frame(ctx))
			_note_reach(ctx, entry[0], reach)
		var length := float(entry[5]) if entry[1] == "" else player.get_animation(entry[1]).length * _span_share(entry[4])
		clips.append({"name": entry[0], "loop": looped, "length": length, "frames": frames, "round": _round(reach) if looped else 0.0})
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
