extends RefCounted
# Grab, bite and scratch rules (body_injury 2).

const FRONT_WINDOW := 1.0
const BACK_WINDOW := 0.5
const GRAB_SHARE := 0.65
const BITE_ARM := 0.60
const BITE_TORSO := 0.25


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
	return "leg"


# A dead hand reaches: "grab" (65%) or "scratch"; the coat may turn a scratch into "blocked".
static func attack_outcome(rng: RandomNumberGenerator, coat_block: float) -> String:
	if rng.randf() < GRAB_SHARE:
		return "grab"
	if rng.randf() < coat_block:
		return "blocked"
	return "scratch"
