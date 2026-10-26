extends RefCounted
## Container work uses seconds; body/temperature multipliers belong to the tick.

const Carry = preload("res://game/sim/carry.gd")

const SKILL_STEP := 0.15
const NOISE_EVERY := 4.0
const COMPANION_LIMIT := 1
## How long a look a box takes by its size (card H 가): the map's seconds times
## this, by the furniture it stands in (Carry's three box sizes) — a small cabinet
## half, a drawer or a desk three quarters, a wardrobe, a counter or a crate (and
## a box of its own) as the map says.
const SIZE_FACTOR: Dictionary = {Carry.BOX_SMALL: 0.5, Carry.BOX_MID: 0.75, Carry.BOX_BIG: 1.0}


static func seconds(base: float, skill: int) -> float:
	return maxf(base, 0.0) / (1.0 + SKILL_STEP * maxi(skill, 0))


## A box's own seconds before the searcher's skill: the map's, by its size.
static func box_seconds(c: Dictionary) -> float:
	return float(c.get("search", 0.0)) * float(SIZE_FACTOR.get(Carry.box_limit(c), 1.0))


static func can_search(container: Dictionary) -> bool:
	return not container.is_empty() and not bool(container.get("locked", false)) and not bool(container.get("searched", false)) and not bool(container.get("busy", false))


static func can_take(container: Dictionary) -> bool:
	return not container.is_empty() and bool(container.get("searched", false)) and not bool(container.get("locked", false)) and not bool(container.get("busy", false))
