extends RefCounted
## First five unrest gestures. The seconds and contacts are first values (가안)
## from GESTURE_TABLE.md, not event, damage or movement timings.

const TABLE: Dictionary = {
	"fist_raise": {
		"kind": "three", "length": {"enter": 0.55, "loop": 1.7, "exit": 0.65},
		"people": 1, "sync": "scene_signal", "pair": {},
		"prop": {"name": "", "left": "free", "right": "fist_silhouette"},
		"two_hand_weapon": false, "upper": true, "base": "stand",
		"stages": {
			"enter": {"visual": ["stand", "fist", "fist"], "bones": {
				"upper_arm.R": ["down", "raising", "raised"], "forearm.R": ["down", "folding", "folded"]}},
			"loop": {"visual": ["fist", "fist_pump", "fist_pump", "fist"], "bones": {
				"hand.R": ["fist_up", "accent", "accent", "fist_up"], "chest": ["rest", "response", "response", "rest"],
				"neck": ["looking", "looking", "looking", "looking"], "head": ["looking", "looking", "looking", "looking"]}},
			"exit": {"visual": ["fist", "stand", "stand"], "bones": {
				"upper_arm.R": ["raised", "lowering", "down"], "forearm.R": ["folded", "lowering", "down"]}},
		},
	},
	"shove_body": {
		"kind": "once", "length": {"once": 1.4}, "people": 2,
		"pair": {"clock": "shared", "roles": ["A", "B"], "contact": 0.58, "anchors": "scene"},
		"prop": {"name": "", "left": "open", "right": "open"},
		"two_hand_weapon": false, "upper": false, "base": "stand",
		"stages": {
			"once": {"visual": ["stand", "shove_ready", "shove_contact", "shove_recover", "stand"],
				"times": {2: 0.58}, "bones": {
					"hips": ["neutral", "brace", "forward", "recover", "neutral"],
					"thigh.L": ["straight", "brace", "support", "release", "straight"],
					"shin.L": ["straight", "brace", "support", "release", "straight"],
					"chest": ["upright", "back", "forward", "return", "upright"],
					"upper_arm.L": ["down", "shield", "shield", "lower", "down"],
					"upper_arm.R": ["down", "shield", "shield", "lower", "down"],
					"forearm.L": ["down", "shield", "shield", "lower", "down"],
					"forearm.R": ["down", "shield", "shield", "lower", "down"],
					"neck": ["forward", "follow", "follow", "forward", "forward"],
					"head": ["forward", "follow", "follow", "forward", "forward"]},
				"bones_b": {
					"hips": ["neutral", "brace", "balance_if_confirmed", "recover", "neutral"],
					"thigh.L": ["straight", "support", "support", "release", "straight"],
					"shin.L": ["straight", "support", "support", "release", "straight"],
					"chest": ["upright", "guard", "react_if_confirmed", "recover_if_confirmed", "upright"],
					"upper_arm.L": ["down", "shield", "shield", "lower", "down"],
					"upper_arm.R": ["down", "shield", "shield", "lower", "down"],
					"forearm.L": ["down", "shield", "shield", "lower", "down"],
					"forearm.R": ["down", "shield", "shield", "lower", "down"],
					"neck": ["forward", "guard", "follow_if_confirmed", "forward", "forward"],
					"head": ["forward", "guard", "follow_if_confirmed", "forward", "forward"]}},
		},
	},
	"bang_object": {
		"kind": "three", "length": {"enter": 0.6, "loop": 1.6, "exit": 0.7},
		"people": 1, "pair": {},
		"prop": {"name": "bowl_or_small_lid", "left": "free", "right": "grip"},
		"two_hand_weapon": false, "upper": true, "base": "stand",
		"stages": {
			"enter": {"visual": ["stand", "bang_ready", "bang_ready"], "bones": {
				"upper_arm.R": ["down", "lift", "ready"], "forearm.R": ["down", "lift", "ready"], "hand.R": ["held", "held", "held"]}},
			"loop": {"visual": ["bang_ready", "bang_up", "bang_contact", "bang_ready"],
				"times": {2: 0.85}, "bones": {
					"upper_arm.R": ["ready", "raised", "contact", "ready"],
					"forearm.R": ["ready", "raised", "contact", "ready"],
					"hand.R": ["grip", "grip", "contact", "grip"],
					"chest": ["upright", "upright", "forward", "upright"],
					"head": ["object", "object", "object", "object"]}},
			"exit": {"visual": ["bang_ready", "stand", "stand"], "bones": {
				"upper_arm.R": ["ready", "lower", "down"], "forearm.R": ["ready", "lower", "down"],
				"hand.R": ["grip", "grip", "grip"]}},
		},
	},
	"spring_up": {
		"kind": "once", "length": {"once": 1.1}, "people": 1, "pair": {},
		"prop": {"name": "", "left": "seat_support", "right": "seat_support"},
		"two_hand_weapon": false, "upper": false, "base": "stand",
		"stages": {
			"once": {"visual": ["seat", "spring_brace", "lower", "spring_rise", "stand"], "bones": {
				"hips": ["seated", "forward", "rising", "higher", "upright"],
				"thigh.L": ["folded", "support", "extend", "extend", "straight"],
				"thigh.R": ["folded", "support", "extend", "extend", "straight"],
				"shin.L": ["folded", "support", "extend", "extend", "straight"],
				"shin.R": ["folded", "support", "extend", "extend", "straight"],
				"foot.L": ["ground", "ground", "ground", "ground", "ground"],
				"foot.R": ["ground", "ground", "ground", "ground", "ground"],
				"forearm.L": ["seat", "support", "release", "lower", "down"],
				"forearm.R": ["seat", "support", "release", "lower", "down"],
				"chest": ["upright", "forward", "upright", "upright", "upright"],
				"neck": ["ahead", "ahead", "rising", "ahead", "ahead"],
				"head": ["ahead", "ahead", "rising", "ahead", "ahead"]}},
		},
	},
	"stomp": {
		"kind": "once", "length": {"once": 1.0}, "people": 1, "pair": {},
		"prop": {"name": "", "left": "free", "right": "free"},
		"two_hand_weapon": false, "upper": false, "base": "stand",
		"stages": {
			"once": {"visual": ["stand", "stomp_lift", "stomp_contact", "stand"], "times": {2: 0.55}, "bones": {
				"hips": ["neutral", "left_support", "contact", "neutral"],
				"thigh.R": ["straight", "bend", "extend", "straight"],
				"shin.R": ["straight", "bend", "extend", "straight"],
				"foot.R": ["ground", "raised", "ground", "ground"],
				"foot.L": ["support", "support", "support", "support"],
				"upper_arm.L": ["down", "balance", "balance", "down"],
				"upper_arm.R": ["down", "balance", "balance", "down"],
				"chest": ["rest", "support", "rebound", "rest"],
				"neck": ["ahead", "ahead", "ahead", "ahead"],
				"head": ["ahead", "ahead", "ahead", "ahead"]}},
		},
	},
}


static func knows(name: String) -> bool:
	return TABLE.has(name)


static func spec(name: String) -> Dictionary:
	return TABLE.get(name, {})
