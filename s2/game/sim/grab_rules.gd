extends RefCounted
# Grab, bite and scratch rules (body_injury 2).

# 1 s felt too fast on the S22 (user, build 20); the back window keeps half of the front.
const FRONT_WINDOW := 1.5
const BACK_WINDOW := 0.75
const GRAB_SHARE := 0.65
const BITE_ARM := 0.60
const BITE_TORSO := 0.20
const BITE_HEAD := 0.05  # the head or the neck, by one standing (결정 441 (5))
const CONTACT_MARGIN: float = 0.4
const ATTACK_COOLDOWN: float = 1.6
const RELEASE_RECOVERY: float = 1.8
## Once the last hand lets go, leave the recovery plus one full front window.
## Only another grab is held off; nails can still reach the person.
const REGRAB_GRACE: float = RELEASE_RECOVERY + FRONT_WINDOW
const HEAVY_COAT_BLOCK: float = 0.5
const COAT_HIT_WEAR: float = 0.1
const COAT_BLOCK_WEAR: float = 0.05
const COAT_PARTS: Array[String] = ["arm_left", "arm_right", "torso"]
const RELEASE_META: StringName = &"dead_regrab_until"


# Seconds to shove free. Two or more grabbers: no window.
static func window(front: bool, grabbers: int, melee_skill: int, strength: int, mult: float = 1.0) -> float:
	if grabbers >= 2:
		return 0.0
	var base: float = FRONT_WINDOW if front else BACK_WINDOW
	var ability: float = 1.0 + 0.03 * float(melee_skill) + 0.02 * float(strength - 5)
	return maxf(0.0, base * ability * mult)


# Where a missed window turns into a bite. Crawlers bite legs.
static func bite_location(rng: RandomNumberGenerator, crawler: bool) -> String:
	if crawler:
		return "leg"
	var r: float = rng.randf()
	if r < BITE_ARM:
		return "arm"
	if r < BITE_ARM + BITE_TORSO:
		return "torso"
	if r < BITE_ARM + BITE_TORSO + BITE_HEAD:
		return "head_neck"
	return "leg"


# A dead hand reaches: "grab" (65%) or "scratch"; the coat may turn a scratch into "blocked".
static func attack_outcome(rng: RandomNumberGenerator, coat_block: float) -> String:
	if rng.randf() < GRAB_SHARE:
		return "grab"
	if rng.randf() < coat_block:
		return "blocked"
	return "scratch"


static func front_contact(facing: float, offset: Vector3, prone: bool = false) -> bool:
	if prone:
		return false
	offset.y = 0.0
	var forward := Vector3(sin(facing), 0, cos(facing))
	return offset.length() < 0.01 or forward.dot(offset.normalized()) > 0.0


static func mark_released(person, now: float) -> void:
	if person != null and person.grabbers.is_empty():
		person.set_meta(RELEASE_META, now + REGRAB_GRACE)


static func can_regrab(person, now: float) -> bool:
	return now >= float(person.get_meta(RELEASE_META, -INF))


## A coat covers arms and torso. A hole belongs to one of the six body parts,
## not both arms at once. Thin coats resist nails, but cannot stop teeth.
static func clothing_block(coat: Dictionary, part: String, bite: bool = false) -> float:
	if part not in COAT_PARTS or (coat.get("holes", {}) as Dictionary).has(part):
		return 0.0
	var heavy: bool = bool(coat.get("heavy", false))
	if bite and not heavy:
		return 0.0
	var block: float = HEAVY_COAT_BLOCK if heavy else float(coat.get("block", 0.0))
	return clampf(block * (1.0 - float(coat.get("wear", 0.0))), 0.0, 1.0)


static func damage_clothing(coat: Dictionary, part: String, blocked: bool) -> void:
	if part not in COAT_PARTS:
		return
	var holes: Dictionary = coat.get("holes", {})
	holes[part] = true
	coat["holes"] = holes
	var wear: float = COAT_BLOCK_WEAR if blocked else COAT_HIT_WEAR
	coat["wear"] = minf(1.0, float(coat.get("wear", 0.0)) + wear)
