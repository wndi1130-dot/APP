extends RefCounted
## Unrest gestures: the first five, then twelve more. The seconds and contacts are first values (가안)
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
	# A takes B by the collar with both hands, pulls, lets go
	"grab_collar": {
		"kind": "once", "length": {"once": 1.6}, "people": 2,
		"pair": {"clock": "shared", "roles": ["A", "B"], "contact": 0.5, "anchors": "scene"},
		"prop": {"name": "", "left": "open", "right": "open"},
		"two_hand_weapon": false, "upper": false, "base": "stand",
		"stages": {
			"once": {"visual": ["stand", "reach", "collar_grip", "collar_pull", "release", "stand"],
				"times": {2: 0.5, 3: 0.9}, "bones": {
					"hips": ["neutral", "forward", "forward", "back", "neutral", "neutral"],
					"chest": ["upright", "forward", "forward", "back", "upright", "upright"],
					"upper_arm.L": ["down", "reach", "grip", "pull", "lower", "down"],
					"upper_arm.R": ["down", "reach", "grip", "pull", "lower", "down"],
					"forearm.L": ["down", "reach", "grip", "pull", "lower", "down"],
					"forearm.R": ["down", "reach", "grip", "pull", "lower", "down"],
					"hand.L": ["open", "open", "fist", "fist", "open", "open"],
					"hand.R": ["open", "open", "fist", "fist", "open", "open"],
					"neck": ["forward", "forward", "close", "close", "forward", "forward"],
					"head": ["forward", "forward", "close", "close", "forward", "forward"]},
				"bones_b": {
					"hips": ["neutral", "neutral", "lean_in_if_confirmed", "lean_in_if_confirmed", "recover", "neutral"],
					"chest": ["upright", "guard", "pulled_if_confirmed", "pulled_if_confirmed", "recover", "upright"],
					"upper_arm.L": ["down", "guard", "grab_wrist", "grab_wrist", "lower", "down"],
					"upper_arm.R": ["down", "guard", "grab_wrist", "grab_wrist", "lower", "down"],
					"forearm.L": ["down", "guard", "grab_wrist", "grab_wrist", "lower", "down"],
					"forearm.R": ["down", "guard", "grab_wrist", "grab_wrist", "lower", "down"],
					"neck": ["forward", "guard", "back", "back", "forward", "forward"],
					"head": ["forward", "guard", "back", "back", "forward", "forward"]}},
		},
	},
	# A swings once; B's head and chest turn only if the hit is confirmed
	"punch_swing": {
		"kind": "once", "length": {"once": 1.2}, "people": 2,
		"pair": {"clock": "shared", "roles": ["A", "B"], "contact": 0.46, "anchors": "scene"},
		"prop": {"name": "", "left": "fist", "right": "fist"},
		"two_hand_weapon": false, "upper": false, "base": "stand",
		"stages": {
			"once": {"visual": ["stand", "wind_up", "punch_contact", "punch_follow", "stand"],
				"times": {2: 0.46}, "bones": {
					"hips": ["neutral", "twist_back", "twist_forward", "settle", "neutral"],
					"thigh.L": ["straight", "brace", "support", "support", "straight"],
					"shin.L": ["straight", "brace", "support", "support", "straight"],
					"chest": ["upright", "twist_back", "twist_forward", "settle", "upright"],
					"upper_arm.R": ["down", "cocked", "extended", "return", "down"],
					"forearm.R": ["down", "cocked", "extended", "return", "down"],
					"hand.R": ["fist", "fist", "fist", "fist", "fist"],
					"upper_arm.L": ["down", "guard", "guard", "guard", "down"],
					"forearm.L": ["down", "guard", "guard", "guard", "down"],
					"head": ["forward", "target", "target", "target", "forward"]},
				"bones_b": {
					"hips": ["neutral", "neutral", "stagger_if_confirmed", "recover", "neutral"],
					"chest": ["upright", "guard", "turn_if_confirmed", "recover", "upright"],
					"upper_arm.L": ["down", "guard", "guard", "lower", "down"],
					"upper_arm.R": ["down", "guard", "guard", "lower", "down"],
					"forearm.L": ["down", "guard", "guard", "lower", "down"],
					"forearm.R": ["down", "guard", "guard", "lower", "down"],
					"neck": ["forward", "guard", "snap_if_confirmed", "recover", "forward"],
					"head": ["forward", "guard", "snap_if_confirmed", "recover", "forward"]}},
		},
	},
	# an adult goes down seat first and stays propped on the hands; never lying flat
	"fall_down": {
		"kind": "once", "length": {"once": 1.3}, "people": 1, "pair": {},
		"prop": {"name": "", "left": "free", "right": "free"},
		"two_hand_weapon": false, "upper": false, "base": "floor",
		"stages": {
			"once": {"visual": ["stand", "stagger", "drop", "floor_land", "floor_prop"],
				"times": {3: 0.78}, "bones": {
					"hips": ["neutral", "back", "falling", "floor", "floor"],
					"thigh.L": ["straight", "step_back", "bend", "folded", "folded"],
					"thigh.R": ["straight", "straight", "bend", "folded", "half"],
					"shin.L": ["straight", "step_back", "bend", "folded", "folded"],
					"shin.R": ["straight", "straight", "bend", "folded", "half"],
					"chest": ["upright", "back", "back", "lean_back", "lean_back"],
					"upper_arm.L": ["down", "flail", "reach_floor", "elbow_prop", "elbow_prop"],
					"upper_arm.R": ["down", "flail", "reach_floor", "palm_prop", "palm_prop"],
					"forearm.L": ["down", "flail", "reach_floor", "elbow_prop", "elbow_prop"],
					"forearm.R": ["down", "flail", "reach_floor", "palm_prop", "palm_prop"],
					"neck": ["forward", "back", "tuck", "tuck", "up"],
					"head": ["forward", "back", "tuck", "tuck", "up"]}},
		},
	},
	# A, standing, gives a hand; B gets up from the floor by it
	"help_up": {
		"kind": "once", "length": {"once": 2.0}, "people": 2,
		"pair": {"clock": "shared", "roles": ["A", "B"], "contact": 0.7, "anchors": "scene"},
		"prop": {"name": "", "left": "open", "right": "open"},
		"two_hand_weapon": false, "upper": false, "base": "stand",
		"stages": {
			"once": {"visual": ["stand", "bend_offer", "hand_grip", "pull_up", "stand"],
				"times": {2: 0.7}, "bones": {
					"hips": ["neutral", "bend", "bend", "back", "neutral"],
					"chest": ["upright", "forward", "forward", "back", "upright"],
					"upper_arm.R": ["down", "offer", "grip", "pull", "down"],
					"forearm.R": ["down", "offer", "grip", "pull", "down"],
					"hand.R": ["open", "open", "grip", "grip", "open"],
					"head": ["forward", "down", "down", "follow", "forward"]},
				"bones_b": {
					"hips": ["floor", "floor", "floor", "rising", "upright"],
					"thigh.L": ["folded", "folded", "support", "extend", "straight"],
					"thigh.R": ["half", "half", "support", "extend", "straight"],
					"shin.L": ["folded", "folded", "support", "extend", "straight"],
					"shin.R": ["half", "half", "support", "extend", "straight"],
					"foot.L": ["ground", "ground", "ground", "ground", "ground"],
					"foot.R": ["ground", "ground", "ground", "ground", "ground"],
					"chest": ["lean_back", "upright", "forward", "upright", "upright"],
					"upper_arm.R": ["palm_prop", "reach", "grip", "pulled", "down"],
					"forearm.R": ["palm_prop", "reach", "grip", "pulled", "down"],
					"head": ["up", "up", "up", "rising", "ahead"]}},
		},
	},
	# a small loose thing thrown overhand at a wall, door, crate or the floor (never a person)
	"throw_object": {
		"kind": "once", "length": {"once": 1.0}, "people": 1, "pair": {},
		"prop": {"name": "small_loose_item", "left": "free", "right": "grip"},
		"two_hand_weapon": false, "upper": false, "base": "stand",
		"stages": {
			"once": {"visual": ["stand", "throw_cock", "throw_release", "throw_follow", "stand"],
				"times": {2: 0.48}, "bones": {
					"hips": ["neutral", "twist_back", "twist_forward", "settle", "neutral"],
					"thigh.L": ["straight", "step", "support", "support", "straight"],
					"shin.L": ["straight", "step", "support", "support", "straight"],
					"chest": ["upright", "twist_back", "forward", "forward", "upright"],
					"upper_arm.R": ["down", "back_high", "forward_high", "across", "down"],
					"forearm.R": ["down", "folded", "extended", "across", "down"],
					"hand.R": ["grip", "grip", "open", "open", "open"],
					"upper_arm.L": ["down", "point", "balance", "balance", "down"],
					"head": ["target", "target", "target", "target", "forward"]}},
		},
	},
	# upper body over a walk: both palms out, leaning away
	"back_away": {
		"kind": "three", "length": {"enter": 0.4, "loop": 0.9, "exit": 0.5},
		"people": 1, "pair": {},
		"prop": {"name": "", "left": "palm_out", "right": "palm_out"},
		"two_hand_weapon": false, "upper": true, "base": "walk",
		"stages": {
			"enter": {"visual": ["stand", "hands_up", "hands_up"], "bones": {
				"upper_arm.L": ["down", "raising", "front"], "upper_arm.R": ["down", "raising", "front"],
				"forearm.L": ["down", "raising", "up"], "forearm.R": ["down", "raising", "up"]}},
			"loop": {"visual": ["hands_up", "lean_back", "lean_back", "hands_up"], "bones": {
				"chest": ["upright", "back", "back", "upright"],
				"neck": ["watch", "watch", "watch", "watch"], "head": ["watch", "watch", "watch", "watch"],
				"hand.L": ["palm_out", "palm_out", "palm_out", "palm_out"],
				"hand.R": ["palm_out", "palm_out", "palm_out", "palm_out"]}},
			"exit": {"visual": ["hands_up", "stand", "stand"], "bones": {
				"upper_arm.L": ["front", "lowering", "down"], "upper_arm.R": ["front", "lowering", "down"],
				"forearm.L": ["up", "lowering", "down"], "forearm.R": ["up", "lowering", "down"]}},
		},
	},
	# stands looking toward the trouble and shrinks once
	"watch_flinch": {
		"kind": "three", "length": {"enter": 0.5, "loop": 3.0, "exit": 0.5},
		"people": 1, "pair": {},
		"prop": {"name": "", "left": "free", "right": "free"},
		"two_hand_weapon": false, "upper": true, "base": "stand",
		"stages": {
			"enter": {"visual": ["stand", "turn_look", "watch"], "bones": {
				"neck": ["ahead", "turning", "toward"], "head": ["ahead", "turning", "toward"]}},
			"loop": {"visual": ["watch", "watch", "flinch", "watch"], "times": {2: 2.1}, "bones": {
				"chest": ["upright", "upright", "shrink", "upright"],
				"upper_arm.L": ["down", "down", "close", "down"], "upper_arm.R": ["down", "down", "close", "down"],
				"forearm.L": ["down", "down", "to_chest", "down"], "forearm.R": ["down", "down", "to_chest", "down"],
				"neck": ["toward", "toward", "duck", "toward"], "head": ["toward", "toward", "duck", "toward"]}},
			"exit": {"visual": ["watch", "turn_back", "stand"], "bones": {
				"neck": ["toward", "turning", "ahead"], "head": ["toward", "turning", "ahead"]}},
		},
	},
	# both hands under a crate's edge, heaved and tipped over
	"tip_crate": {
		"kind": "once", "length": {"once": 1.5}, "people": 1, "pair": {},
		"prop": {"name": "crate", "left": "grip_edge", "right": "grip_edge"},
		"two_hand_weapon": false, "upper": false, "base": "stand",
		"stages": {
			"once": {"visual": ["stand", "crouch_grip", "heave", "tip_over", "stand"],
				"times": {3: 1.05}, "bones": {
					"hips": ["neutral", "low", "rising", "forward", "neutral"],
					"thigh.L": ["straight", "bend", "extend", "support", "straight"],
					"thigh.R": ["straight", "bend", "extend", "support", "straight"],
					"shin.L": ["straight", "bend", "extend", "support", "straight"],
					"shin.R": ["straight", "bend", "extend", "support", "straight"],
					"chest": ["upright", "forward", "upright", "forward", "upright"],
					"upper_arm.L": ["down", "low_grip", "lift", "push", "down"],
					"upper_arm.R": ["down", "low_grip", "lift", "push", "down"],
					"forearm.L": ["down", "low_grip", "lift", "push", "down"],
					"forearm.R": ["down", "low_grip", "lift", "push", "down"],
					"head": ["forward", "down", "crate", "crate", "forward"]}},
		},
	},
	# a torch held at shoulder height
	"torch_hold": {
		"kind": "three", "length": {"enter": 0.6, "loop": 2.4, "exit": 0.6},
		"people": 1, "pair": {},
		"prop": {"name": "torch", "left": "free", "right": "grip"},
		"two_hand_weapon": false, "upper": true, "base": "stand",
		"stages": {
			"enter": {"visual": ["stand", "torch_lift", "torch_high"], "bones": {
				"upper_arm.R": ["down", "raising", "shoulder"], "forearm.R": ["down", "raising", "up"],
				"hand.R": ["grip", "grip", "grip"]}},
			"loop": {"visual": ["torch_high", "torch_sway", "torch_high"], "bones": {
				"upper_arm.R": ["shoulder", "shoulder_sway", "shoulder"],
				"chest": ["upright", "turn", "upright"], "head": ["crowd", "crowd", "crowd"]}},
			"exit": {"visual": ["torch_high", "torch_lower", "stand"], "bones": {
				"upper_arm.R": ["shoulder", "lowering", "down"], "forearm.R": ["up", "lowering", "down"],
				"hand.R": ["grip", "grip", "grip"]}},
		},
	},
	# upper body over a walk: the torch held out front, away from the body (no run)
	"torch_carry": {
		"kind": "three", "length": {"enter": 0.5, "loop": 1.0, "exit": 0.5},
		"people": 1, "pair": {},
		"prop": {"name": "torch", "left": "free", "right": "grip"},
		"two_hand_weapon": false, "upper": true, "base": "walk",
		"stages": {
			"enter": {"visual": ["walk", "torch_front", "torch_front"], "bones": {
				"upper_arm.R": ["down", "raising", "front"], "forearm.R": ["down", "raising", "front"]}},
			"loop": {"visual": ["torch_front", "torch_bob", "torch_front"], "bones": {
				"upper_arm.R": ["front", "front_low", "front"], "hand.R": ["grip", "grip", "grip"],
				"upper_arm.L": ["swing_back", "swing_front", "swing_back"]}},
			"exit": {"visual": ["torch_front", "lowering", "walk"], "bones": {
				"upper_arm.R": ["front", "lowering", "down"], "forearm.R": ["front", "lowering", "down"]}},
		},
	},
	# a cloth in the left hand put to the torch in the right, then held up
	"light_cloth": {
		"kind": "once", "length": {"once": 1.8}, "people": 1, "pair": {},
		"prop": {"name": "torch_and_cloth", "left": "cloth", "right": "torch"},
		"two_hand_weapon": false, "upper": true, "base": "stand",
		"stages": {
			"once": {"visual": ["hold_both", "bring_together", "catch", "cloth_up", "hold_both"],
				"times": {2: 0.9}, "bones": {
					"upper_arm.L": ["low", "front", "front", "raise", "low"],
					"forearm.L": ["low", "front", "front", "raise", "low"],
					"hand.L": ["pinch", "pinch", "pinch", "pinch", "pinch"],
					"upper_arm.R": ["low", "front", "front", "low", "low"],
					"forearm.R": ["low", "front", "front", "low", "low"],
					"chest": ["upright", "lean_away", "lean_away", "upright", "upright"],
					"head": ["hands", "hands", "away", "cloth", "ahead"]}},
		},
	},
	# upper body over a walk: the inside of the elbow over the mouth, head low, other hand feeling ahead
	"walk_out_smoke": {
		"kind": "three", "length": {"enter": 0.5, "loop": 1.1, "exit": 0.6},
		"people": 1, "pair": {},
		"prop": {"name": "", "left": "free", "right": "free"},
		"two_hand_weapon": false, "upper": true, "base": "walk",
		"stages": {
			"enter": {"visual": ["walk", "arm_to_mouth", "covered"], "bones": {
				"upper_arm.R": ["down", "raising", "across_face"], "forearm.R": ["down", "folding", "across_face"],
				"neck": ["ahead", "lower", "low"], "head": ["ahead", "lower", "low"]}},
			"loop": {"visual": ["covered", "cough", "covered"], "times": {1: 0.5}, "bones": {
				"chest": ["bent", "cough", "bent"], "neck": ["low", "lower", "low"],
				"upper_arm.L": ["front_low", "front_low", "front_low"],
				"forearm.L": ["feel_ahead", "feel_ahead", "feel_ahead"]}},
			"exit": {"visual": ["covered", "arm_down", "walk"], "bones": {
				"upper_arm.R": ["across_face", "lowering", "down"], "forearm.R": ["across_face", "lowering", "down"],
				"neck": ["low", "rising", "ahead"], "head": ["low", "rising", "ahead"]}},
		},
	},
}

## Admission facts for the later unrest rows: allowed start poses and the
## context keys the caller must supply. role_b_from is B's start in a pair.
const BEGIN_RULES: Dictionary = {
	"grab_collar": {"from": ["stand"], "context": ["hands_ready", "adult", "anchors"]},
	"punch_swing": {"from": ["stand"], "context": ["hands_ready", "adult", "anchors"]},
	"fall_down": {"from": ["stand", "walk"], "context": ["hands_ready", "adult", "floor_clear"]},
	"help_up": {"from": ["stand"], "context": ["hands_ready", "adult", "anchors"], "role_b_from": ["floor"]},
	"throw_object": {"from": ["stand"], "context": ["hands_ready", "adult", "prop", "target"]},
	"back_away": {"from": ["stand", "walk"], "context": ["hands_ready", "adult"]},
	"watch_flinch": {"from": ["stand"], "context": ["hands_ready", "adult", "target"]},
	"tip_crate": {"from": ["stand"], "context": ["hands_ready", "adult", "prop", "floor_clear"]},
	"torch_hold": {"from": ["stand"], "context": ["hands_ready", "adult", "prop"]},
	"torch_carry": {"from": ["walk"], "context": ["hands_ready", "adult", "prop"]},
	"light_cloth": {"from": ["stand"], "context": ["hands_ready", "adult", "prop"]},
	"walk_out_smoke": {"from": ["walk", "stand"], "context": ["hands_ready"]},
}


static func knows(name: String) -> bool:
	return TABLE.has(name)


static func spec(name: String) -> Dictionary:
	return TABLE.get(name, {})
