extends RefCounted
## The train people's own motions (user request 2026-10-24): baked on the field's body
## (models/people/n5-crew_seamstress) into a folder of their own, so the field's
## numbers stay as they are. Names begin with t_. tools/bake_train_cli.gd bakes
## them; train_people_view.gd finds each by its name.
##
## A row: name, source motion ("" for none), frames, loops, layer ("" for none),
## seconds (only for a row with no source motion). The sources are the two free
## motion sets the field already uses (UAL 1 and 2, CC0), read together.
## A layer is written as body_bake.gd LAYERS are: "span" plays part of the
## source, "steps" turn or aim a bone, "sink" lowers the hips.

const FOLDER: String = "res://models/people/n5-crew_seamstress_t"

const CLIPS: Array = [
	["t_sit", "Sitting_Idle_Loop", 24, true, "", 0.0],
	["t_sit_talk", "Sitting_Talking_Loop", 24, true, "", 0.0],
	["t_stand", "Idle_Loop", 24, true, "", 0.0],
	["t_walk", "Walk_Loop", 24, true, "", 0.0],
	["t_fold", "Idle_FoldArms_Loop", 24, true, "", 0.0],
	["t_talk", "Idle_Talking_Loop", 24, true, "", 0.0],
	["t_no", "Idle_No_Loop", 24, true, "", 0.0],
	["t_lantern", "Idle_Lantern_Loop", 24, true, "", 0.0],
	["t_crouch", "Crouch_Idle_Loop", 24, true, "", 0.0],
	["t_kneel_work", "Fixing_Kneeling", 32, true, "t_kneel_span", 0.0],
	["t_eat", "Consume", 24, true, "", 0.0],
	["t_carry", "Walk_Carry_Loop", 24, true, "", 0.0],
	["t_shovel", "Farm_Harvest", 32, true, "", 0.0],
	["t_stir", "Farm_Watering", 32, true, "", 0.0],
	["t_lie", "LayToIdle", 12, true, "t_lie_still", 0.0],
	["t_floor_sit", "LayToIdle", 12, true, "t_floor_sit", 0.0],
	["t_shiver", "Idle_FoldArms_Loop", 24, true, "t_shiver", 0.0],
	["t_cough", "Idle_Loop", 32, true, "t_cough", 0.0],
	["t_sit_huddle", "Sitting_Idle_Loop", 24, true, "t_huddle", 0.0],
	["t_sit_doze", "Sitting_Idle_Loop", 24, true, "t_doze", 0.0],
	["t_warm_hands", "Crouch_Idle_Loop", 24, true, "t_hands_out", 0.0],
]

## Kept at every frame in the small bake (their beats are quicker than half the frames).
const KEEP: Array = ["t_shiver", "t_cough"]

const LAYERS: Dictionary = {
	# Kneeling at a job: the middle of the motion only, without going down or getting up.
	"t_kneel_span": {"span": [0.2, 0.8]},
	# Lying on a bunk or the floor: the start of getting up, held, the chest rising slowly.
	"t_lie_still": {"span": [0.0, 0.02], "steps": [["turn", "chest", "x", [0.0, 0.025, 0.0]]]},
	# Sitting on the floor: the moment of getting up where the body sits, held.
	"t_floor_sit": {"span": [0.30, 0.31], "steps": [["turn", "chest", "x", [0.1, 0.02, 0.0]]]},
	# Cold: arms folded tight, shoulders up, a quick small tremble through the body. A short
	# span of the folded-arms idle so the tremble is fast (four beats in 0.75 s), every frame kept.
	"t_shiver": {"span": [0.0, 0.3], "steps": [
		["turn", "spine", "x", 0.12],
		["turn", "chest", "x", [0.1, 0.025, 0.0, 4.0]],
		["turn", "chest", "z", [0.0, 0.03, 0.0, 5.0]],
		["turn", "neck", "x", 0.25],
		["turn", "head", "y", [0.0, 0.03, 1.0, 3.0]],
	], "sink": 0.04},
	# A cough once a round: the chest jerks forward twice, the head goes down, a hand comes up to the mouth.
	"t_cough": {"steps": [
		["turn", "spine", "x", ["keys", [[0.0, 0.05], [0.52, 0.05], [0.58, 0.22], [0.64, 0.1], [0.70, 0.22], [0.8, 0.05]]]],
		["turn", "chest", "x", ["keys", [[0.0, 0.08], [0.52, 0.08], [0.58, 0.3], [0.64, 0.12], [0.70, 0.3], [0.8, 0.08]]]],
		["turn", "neck", "x", ["keys", [[0.0, 0.3], [0.52, 0.3], [0.6, 0.55], [0.8, 0.3]]]],
		["aim", "upper_arm.R", "forearm.R", [-0.15, ["keys", [[0.0, -1.0], [0.45, -1.0], [0.55, -0.25], [0.8, -0.25], [0.9, -1.0]]], ["keys", [[0.0, 0.1], [0.45, 0.1], [0.55, 0.9], [0.8, 0.9], [0.9, 0.1]]]]],
		["aim", "forearm.R", "hand.R", [0.25, ["keys", [[0.0, -1.0], [0.45, -1.0], [0.55, 0.9], [0.8, 0.9], [0.9, -1.0]]], 0.4]],
	]},
	# Hunched up on the bench: bent over the knees, arms round the body, head low.
	"t_huddle": {"steps": [
		["turn", "spine", "x", 0.35],
		["turn", "chest", "x", [0.3, 0.015, 0.0, 9.0]],
		["turn", "neck", "x", 0.45],
		["aim", "upper_arm.L", "forearm.L", [0.15, -0.6, 0.8]],
		["aim", "forearm.L", "hand.L", [-0.9, 0.0, 0.4]],
		["aim", "upper_arm.R", "forearm.R", [-0.15, -0.6, 0.8]],
		["aim", "forearm.R", "hand.R", [0.9, 0.0, 0.4]],
	]},
	# Asleep sitting up: the head fallen to one side, the back slack.
	"t_doze": {"steps": [
		["turn", "spine", "x", 0.15],
		["turn", "neck", "x", [0.55, 0.03, 0.0]],
		["turn", "head", "z", 0.35],
	]},
	# Crouched by the stove: both hands held out to it, rubbed now and then.
	"t_hands_out": {"steps": [
		["turn", "spine", "x", 0.15],
		["aim", "upper_arm.L", "forearm.L", [0.12, -0.35, 1.0]],
		["aim", "forearm.L", "hand.L", [[-0.15, 0.06, 0.0, 3.0], 0.1, 1.0]],
		["aim", "upper_arm.R", "forearm.R", [-0.12, -0.35, 1.0]],
		["aim", "forearm.R", "hand.R", [[0.15, 0.06, 3.14, 3.0], 0.1, 1.0]],
	]},
}


static func names() -> Array:
	return CLIPS.map(func(row: Array) -> String: return String(row[0]))
