extends RefCounted
## First seven resting gestures. The seconds and pose keys are first values (가안)
## from GESTURE_TABLE.md. Bone names are those of the current 17-bone body.

const TABLE: Dictionary = {
	"sit_bench": {
		"kind": "three", "length": {"enter": 1.1, "loop": 4.2, "exit": 1.3},
		"people": 1, "pair": {}, "prop": {"name": "", "left": "thigh", "right": "thigh"},
		"two_hand_weapon": false, "upper": false, "base": "sit",
		"stages": {
			"enter": {"visual": ["stand", "lower", "lower", "seat"], "bones": {
				"hips": ["upright", "lowering", "lowering", "seated"],
				"thigh.L": ["straight", "fold", "fold", "seated"], "thigh.R": ["straight", "fold", "fold", "seated"],
				"shin.L": ["straight", "support", "support", "upright"], "shin.R": ["straight", "support", "support", "upright"],
				"forearm.L": ["down", "lower", "near_thigh", "rest"], "forearm.R": ["down", "lower", "near_thigh", "rest"]}},
			"loop": {"visual": ["seat", "seat_breathe", "seat"], "bones": {
				"chest": ["rest", "breath", "rest"], "neck": ["forward", "forward", "forward"], "head": ["forward", "forward", "forward"]}},
			"exit": {"visual": ["seat", "lower", "lower", "stand"], "bones": {
				"hips": ["seated", "forward", "rising", "upright"],
				"thigh.L": ["folded", "support", "extend", "straight"], "thigh.R": ["folded", "support", "extend", "straight"],
				"foot.L": ["grounded", "grounded", "grounded", "grounded"], "foot.R": ["grounded", "grounded", "grounded", "grounded"]}},
		},
	},
	"sit_floor": {
		"kind": "three", "length": {"enter": 1.5, "loop": 4.8, "exit": 1.7},
		"people": 1, "pair": {}, "prop": {"name": "", "left": "free", "right": "floor_support"},
		"two_hand_weapon": false, "upper": false, "base": "floor",
		"stages": {
			"enter": {"visual": ["stand", "lower", "floor_brace", "floor_brace", "floor"], "bones": {
				"hips": ["upright", "lowering", "lowering", "low", "seated"],
				"thigh.L": ["straight", "fold", "fold", "fold", "seated"], "thigh.R": ["straight", "fold", "fold", "fold", "seated"],
				"shin.L": ["straight", "fold", "fold", "beside", "beside"], "shin.R": ["straight", "fold", "fold", "beside", "beside"],
				"upper_arm.R": ["down", "reach", "brace", "brace", "rest"],
				"forearm.R": ["down", "reach", "brace", "brace", "rest"], "hand.R": ["free", "reach", "ground", "ground", "rest"]}},
			"loop": {"visual": ["floor", "floor_breathe", "floor"], "bones": {
				"spine": ["upright", "breath", "upright"], "chest": ["rest", "breath", "rest"], "head": ["ahead", "ahead", "ahead"]}},
			"exit": {"visual": ["floor", "floor_brace", "lower", "lower", "stand"], "bones": {
				"hand.R": ["rest", "ground", "support", "release", "free"], "hips": ["seated", "low", "rising", "rising", "upright"],
				"thigh.L": ["folded", "support", "extend", "extend", "straight"], "thigh.R": ["folded", "support", "extend", "extend", "straight"],
				"foot.L": ["beside", "ground", "ground", "ground", "ground"], "foot.R": ["beside", "ground", "ground", "ground", "ground"]}},
		},
	},
	"lie_bunk": {
		"kind": "three", "length": {"enter": 2.4, "loop": 5.6, "exit": 2.6},
		"people": 1, "pair": {}, "prop": {"name": "", "left": "bunk_support", "right": "bunk_support"},
		"two_hand_weapon": false, "upper": false, "base": "sit",
		"stages": {
			"enter": {"visual": ["stand", "lower", "seat", "bunk_turn", "bunk"], "bones": {
				"hips": ["upright", "lower", "seated", "roll_side", "lying"],
				"thigh.L": ["straight", "fold", "seated", "lift", "on_bunk"], "thigh.R": ["straight", "fold", "seated", "lift", "on_bunk"],
				"shin.L": ["straight", "fold", "fold", "gather", "on_bunk"], "shin.R": ["straight", "fold", "fold", "gather", "on_bunk"],
				"hand.L": ["free", "reach", "brace", "brace", "rest"], "hand.R": ["free", "reach", "brace", "brace", "rest"]}},
			"loop": {"visual": ["bunk", "bunk_breathe", "bunk"], "bones": {
				"chest": ["rest", "breath", "rest"], "neck": ["pillow", "pillow", "pillow"], "head": ["pillow", "pillow", "pillow"]}},
			"exit": {"visual": ["bunk", "bunk_turn", "seat", "lower", "stand"], "bones": {
				"spine": ["lying", "lift", "upright", "rising", "upright"], "hips": ["lying", "turn", "seated", "rising", "upright"],
				"thigh.L": ["on_bunk", "gather", "lower", "support", "straight"], "thigh.R": ["on_bunk", "gather", "lower", "support", "straight"],
				"foot.L": ["on_bunk", "lower", "ground", "ground", "ground"], "foot.R": ["on_bunk", "lower", "ground", "ground", "ground"]}},
		},
	},
	"sleep_lean_wall": {
		"kind": "three", "length": {"enter": 1.6, "loop": 5.1, "exit": 1.8},
		"people": 1, "pair": {}, "prop": {"name": "", "left": "knee", "right": "knee"},
		"two_hand_weapon": false, "upper": false, "base": "sit",
		"stages": {
			"enter": {"visual": ["stand", "lower", "wall", "wall"], "bones": {
				"hips": ["upright", "lower", "seated_against_wall", "seated_against_wall"],
				"thigh.L": ["straight", "fold", "fold", "fold"], "thigh.R": ["straight", "fold", "fold", "fold"],
				"shin.L": ["straight", "forward", "forward", "forward"], "shin.R": ["straight", "forward", "forward", "forward"],
				"forearm.L": ["down", "lower", "knee", "knee"], "forearm.R": ["down", "lower", "knee", "knee"]}},
			"loop": {"visual": ["wall", "wall_nod", "wall"], "bones": {
				"chest": ["breath", "breath", "breath"], "neck": ["raised", "drooping", "raised"], "head": ["raised", "drooping", "raised"]}},
			"exit": {"visual": ["wall", "lower", "lower", "stand"], "bones": {
				"head": ["drooped", "raised", "ahead", "ahead"], "hips": ["against_wall", "forward", "rising", "upright"],
				"thigh.L": ["fold", "support", "extend", "straight"], "thigh.R": ["fold", "support", "extend", "straight"],
				"foot.L": ["ground", "ground", "ground", "ground"], "foot.R": ["ground", "ground", "ground", "ground"]}},
		},
	},
	"warm_hands_crouch": {
		"kind": "three", "length": {"enter": 1.3, "loop": 3.4, "exit": 1.5},
		"people": 1, "pair": {}, "prop": {"name": "", "left": "open", "right": "open"},
		"two_hand_weapon": false, "upper": false, "base": "floor",
		"stages": {
			"enter": {"visual": ["stand", "lower", "crouch", "crouch_warm"], "bones": {
				"hips": ["upright", "lower", "low", "crouched"],
				"thigh.L": ["straight", "fold", "fold", "fold"], "thigh.R": ["straight", "fold", "fold", "fold"],
				"shin.L": ["straight", "fold", "fold", "fold"], "shin.R": ["straight", "fold", "fold", "fold"]}},
			"loop": {"visual": ["crouch_warm", "crouch_warm_roll", "crouch_warm_roll", "crouch_warm"], "bones": {
				"upper_arm.L": ["forward", "forward", "forward", "forward"], "upper_arm.R": ["forward", "forward", "forward", "forward"],
				"forearm.L": ["open", "turn", "turn_back", "open"], "forearm.R": ["open", "turn", "turn_back", "open"],
				"hand.L": ["palm", "back", "palm", "palm"], "hand.R": ["palm", "back", "palm", "palm"],
				"chest": ["forward", "forward", "forward", "forward"], "head": ["hands", "hands", "hands", "hands"]}},
			"exit": {"visual": ["crouch_warm", "crouch", "lower", "stand"], "bones": {
				"hand.L": ["open", "release", "down", "down"], "hand.R": ["open", "release", "down", "down"],
				"hips": ["low", "rising", "rising", "upright"],
				"thigh.L": ["fold", "support", "extend", "straight"], "thigh.R": ["fold", "support", "extend", "straight"]}},
		},
	},
	"warm_hands_stand": {
		"kind": "three", "length": {"enter": 0.7, "loop": 3.2, "exit": 0.7},
		"people": 1, "pair": {}, "prop": {"name": "", "left": "open", "right": "open"},
		"two_hand_weapon": false, "upper": true, "base": "stand",
		"stages": {
			"enter": {"visual": ["stand", "stand_warm", "stand_warm"], "bones": {
				"upper_arm.L": ["down", "lift", "forward"], "upper_arm.R": ["down", "lift", "forward"],
				"forearm.L": ["down", "lift", "forward"], "forearm.R": ["down", "lift", "forward"]}},
			"loop": {"visual": ["stand_warm", "stand_warm_roll", "stand_warm_roll", "stand_warm"], "bones": {
				"upper_arm.L": ["forward", "gather", "extend", "forward"], "upper_arm.R": ["forward", "gather", "extend", "forward"],
				"forearm.L": ["forward", "turn", "turn_back", "forward"], "forearm.R": ["forward", "turn", "turn_back", "forward"],
				"hand.L": ["palm", "back", "palm", "palm"], "hand.R": ["palm", "back", "palm", "palm"],
				"chest": ["slight_bow", "slight_bow", "slight_bow", "slight_bow"],
				"neck": ["hands", "hands", "hands", "hands"], "head": ["hands", "hands", "hands", "hands"]}},
			"exit": {"visual": ["stand_warm", "stand", "stand"], "bones": {
				"upper_arm.L": ["forward", "lower", "down"], "upper_arm.R": ["forward", "lower", "down"],
				"forearm.L": ["forward", "lower", "down"], "forearm.R": ["forward", "lower", "down"]}},
		},
	},
	"kneel": {
		"kind": "three", "length": {"enter": 1.2, "loop": 4.0, "exit": 1.4},
		"people": 1, "pair": {}, "prop": {"name": "", "left": "thigh", "right": "thigh"},
		"two_hand_weapon": false, "upper": false, "base": "floor",
		"stages": {
			"enter": {"visual": ["stand", "lower", "kneel", "kneel"], "bones": {
				"hips": ["upright", "lower", "one_knee", "kneeling"],
				"thigh.L": ["straight", "fold", "ground", "ground"], "thigh.R": ["straight", "fold", "fold", "ground"],
				"shin.L": ["straight", "fold", "support", "support"], "shin.R": ["straight", "fold", "support", "support"],
				"forearm.L": ["down", "lower", "thigh", "thigh"], "forearm.R": ["down", "lower", "thigh", "thigh"]}},
			"loop": {"visual": ["kneel", "kneel_breathe", "kneel"], "bones": {
				"spine": ["upright", "upright", "upright"], "chest": ["rest", "breath", "rest"], "head": ["ahead", "ahead", "ahead"]}},
			"exit": {"visual": ["kneel", "lower", "lower", "stand"], "bones": {
				"hips": ["kneeling", "rising", "rising", "upright"],
				"thigh.L": ["fold", "support", "extend", "straight"], "thigh.R": ["fold", "support", "extend", "straight"],
				"foot.L": ["ground", "ground", "ground", "ground"], "foot.R": ["ground", "ground", "ground", "ground"]}},
		},
	},
}


static func knows(name: String) -> bool:
	return TABLE.has(name)


static func spec(name: String) -> Dictionary:
	return TABLE.get(name, {})
