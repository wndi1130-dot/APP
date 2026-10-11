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
const POSES_CLIP: String = "poses"

# Layers: a hand-made addition on top of a motion. For a frame at progress u
# (0..1), w = TAU * u, and a layer holds:
#   "warp": [size, lag]       read the motion at u + size * sin(w - lag) (uneven cadence)
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
	# The left leg steps, the right is dragged after it (a shorter, stiffer swing).
	"own_walk": {
		"steps": [
			["turn", "hips", "z", [0.05, 0.09, 0.3]],
			["turn", "hips", "y", [0.0, 0.1, 0.0]],
			["aim", "thigh.L", "shin.L", [0.06, -1.0, [0.02, 0.36, 0.0]]],
			["aim", "shin.L", "foot.L", [0.03, -1.0, [-0.24, 0.4, 0.7]]],
			["aim", "thigh.R", "shin.R", [-0.1, -1.0, [-0.04, 0.2, 3.14]]],
			["aim", "shin.R", "foot.R", [-0.12, -1.0, [-0.16, 0.16, 3.6]]],
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
			["aim", "thigh.L", "shin.L", [0.06, -1.0, [0.1, 0.75, 0.0]]],
			["aim", "shin.L", "foot.L", [0.03, -1.0, [-0.6, 0.8, 0.8]]],
			["aim", "thigh.R", "shin.R", [-0.08, -1.0, [0.1, 0.65, 3.14]]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, [-0.55, 0.7, 3.94]]],
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
			["aim", "thigh.R", "shin.R", [-0.06, -1.0, [0.02, 0.36, 3.14]]],
			["aim", "shin.R", "foot.R", [-0.03, -1.0, [-0.24, 0.4, 3.84]]],
			["aim", "thigh.L", "shin.L", [0.1, -1.0, [-0.04, 0.2, 0.0]]],
			["aim", "shin.L", "foot.L", [0.12, -1.0, [-0.16, 0.16, 0.46]]],
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
			["aim", "thigh.L", "shin.L", [0.1, -1.0, [0.08, 0.18, 0.0]]],
			["aim", "shin.L", "foot.L", [0.06, -1.0, [-0.22, 0.2, 0.6]]],
			["aim", "thigh.R", "shin.R", [-0.1, -1.0, [0.08, 0.18, 3.14]]],
			["aim", "shin.R", "foot.R", [-0.06, -1.0, [-0.22, 0.2, 3.74]]],
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
	# The half beat before it runs, standing on its own legs (see "tell").
	"own_tell": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.1, -1.0, [0.03, 0.2, 0.0, 0.25]]],
			["aim", "shin.L", "foot.L", [0.05, -1.0, [-0.08, -0.25, 0.0, 0.25]]],
			["aim", "thigh.R", "shin.R", [-0.12, -1.0, [0.0, 0.2, 0.0, 0.25]]],
			["aim", "shin.R", "foot.R", [-0.08, -1.0, [-0.05, -0.25, 0.0, 0.25]]],
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
		"sink": [0.03, 0.12, 0.0, 0.25],
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
	if typeof(parts[0]) == TYPE_ARRAY:
		var total := 0.0
		for part in parts:
			total += _value(part, w)
		return total
	var beats: float = parts[3] if parts.size() > 3 else 1.0
	return float(parts[0]) + float(parts[1]) * sin(beats * w - float(parts[2]))


## Hangs a layer on the body (after retarget), for progress u (0..1).
static func apply_layer(body: Skeleton3D, layer: Dictionary, u: float) -> void:
	var w := TAU * u
	for step: Array in layer.get("steps", []):
		match step[0]:
			"turn":
				turn(body, step[1], _value(step[3], w), AXES[step[2]])
			"aim":
				var dir: Array = step[3]
				aim(body, step[1], step[2], Vector3(_value(dir[0], w), _value(dir[1], w), _value(dir[2], w)))
	if layer.has("sink"):
		sink(body, _value(layer["sink"], w))


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
	_pose_at(ctx, clip, at, spec.get("damp", {}))
	apply_layer(ctx["body"], spec, u)


## One skin matrix per bone the mesh binds: pose * inverse bind, in mesh space.
static func _skin_frame(ctx: Dictionary) -> Array:
	var body: Skeleton3D = ctx["body"]
	var skin: Skin = ctx["skin"]
	var bind_bone: Array = ctx["bind_bone"]
	var mats := []
	for j in bind_bone.size():
		mats.append((ctx["to_mesh"] as Transform3D) * body.get_bone_global_pose(bind_bone[j]) * skin.get_bind_pose(j))
	return mats


## Collects what posing needs from the two models (both in the scene tree); {} if something is missing.
static func prepare(body_root: Node3D, motion_root: Node3D) -> Dictionary:
	var source := first_of(motion_root, "Skeleton3D") as Skeleton3D
	var player := first_of(motion_root, "AnimationPlayer") as AnimationPlayer
	var body := first_of(body_root, "Skeleton3D") as Skeleton3D
	var mesh_node := first_of(body_root, "MeshInstance3D") as MeshInstance3D
	if source == null or player == null or body == null or mesh_node == null or mesh_node.skin == null:
		push_error("body_bake: need a skeleton and animation player in the motions, and a skeleton and skinned mesh in the body")
		return {}
	for entry: Array in CLIPS:
		if entry[1] != "" and not player.has_animation(entry[1]):
			push_error("body_bake: motion not found: " + str(entry[1]))
			return {}
		if entry[4] != "" and not LAYERS.has(entry[4]):
			push_error("body_bake: layer not found: " + str(entry[4]))
			return {}
	for entry: Array in POSES:
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
static func prepare_own(body_root: Node3D) -> Dictionary:
	var body := first_of(body_root, "Skeleton3D") as Skeleton3D
	var mesh_node := first_of(body_root, "MeshInstance3D") as MeshInstance3D
	if body == null or mesh_node == null or mesh_node.skin == null:
		push_error("body_bake: need a skeleton and skinned mesh in the body")
		return {}
	for body_bone: String in MAP:
		if _bone(body, body_bone) < 0:
			push_error("body_bake: bone not found: " + body_bone)
			return {}
	for entry: Array in OWN_CLIPS + OWN_POSES:
		var layer: String = entry[4] if entry.size() > 4 else entry[0]
		if not LAYERS.has(layer):
			push_error("body_bake: layer not found: " + layer)
			return {}
	body.reset_bone_poses()
	var ctx := {"body": body, "mesh_node": mesh_node}
	_bind_skin(ctx)
	return ctx


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
	var player: AnimationPlayer = ctx["player"]
	var mesh_node: MeshInstance3D = ctx["mesh_node"]
	var clips := []
	for entry: Array in CLIPS:
		var count: int = entry[2]
		var looped: bool = entry[3]
		var frames := []
		for f in count:
			# A loop's last frame stops one step short of the first; a one-shot ends on its end.
			var u: float = float(f) / float(count) if looped else float(f) / float(count - 1)
			pose(ctx, entry[1], entry[4], u)
			frames.append(_skin_frame(ctx))
		clips.append({"name": entry[0], "loop": looped, "length": float(entry[5]) if entry[1] == "" else player.get_animation(entry[1]).length, "frames": frames})
	var still := []
	for entry: Array in POSES:
		_pose_at(ctx, entry[0], entry[1], {})
		apply_overlay(ctx["body"], entry[2])
		still.append(_skin_frame(ctx))
	clips.append({"name": POSES_CLIP, "loop": false, "length": 1.0, "frames": still})
	return VatBaker.build_skinned(mesh_node.mesh.surface_get_arrays(0), clips)


## Bakes the body in `body_root` (in the scene tree) with the motions written
## here alone: OWN_CLIPS in order, then one POSES_CLIP of OWN_POSES. Nothing
## in the result comes from a motion set. {} if something is missing.
static func bake_own(body_root: Node3D) -> Dictionary:
	var ctx := prepare_own(body_root)
	if ctx.is_empty():
		return {}
	var mesh_node: MeshInstance3D = ctx["mesh_node"]
	var clips := []
	for entry: Array in OWN_CLIPS:
		var count: int = entry[2]
		var looped: bool = entry[3]
		var frames := []
		for f in count:
			var u: float = float(f) / float(count) if looped else float(f) / float(count - 1)
			pose(ctx, "", entry[4], u)
			frames.append(_skin_frame(ctx))
		clips.append({"name": entry[0], "loop": looped, "length": float(entry[5]), "frames": frames})
	var still := []
	for entry: Array in OWN_POSES:
		pose(ctx, "", entry[0], entry[1])
		apply_overlay(ctx["body"], entry[2])
		still.append(_skin_frame(ctx))
	clips.append({"name": POSES_CLIP, "loop": false, "length": 1.0, "frames": still})
	return VatBaker.build_skinned(mesh_node.mesh.surface_get_arrays(0), clips)


## Writes vat.bin (the picture's half floats as they are: an exported game
## cannot read EXR), mesh.res and clips.json into `dir`.
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
	# Three half floats a texel.
	if width <= 0 or height <= 0 or data.size() != width * height * 6:
		return {}
	var image := Image.create_from_data(width, height, false, Image.FORMAT_RGBH, data)
	var clips := []
	for clip: Dictionary in info["clips"]:
		clips.append({"name": str(clip["name"]), "start": int(clip["start"]), "frames": int(clip["frames"]), "loop": bool(clip["loop"]), "length": float(clip["length"])})
	return {"mesh": mesh, "texture": ImageTexture.create_from_image(image), "vertices": int(info["vertices"]), "width": image.get_width(), "rows_per_frame": int(info["rows_per_frame"]), "height": image.get_height(), "image": image, "clips": clips}
