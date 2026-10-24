extends RefCounted
## Container work uses seconds; body/temperature multipliers belong to the tick.

const SKILL_STEP := 0.15
const NOISE_EVERY := 4.0
const COMPANION_LIMIT := 1


static func seconds(base: float, skill: int) -> float:
	return maxf(base, 0.0) / (1.0 + SKILL_STEP * maxi(skill, 0))


static func can_search(container: Dictionary) -> bool:
	return not container.is_empty() and not bool(container.get("locked", false)) and not bool(container.get("searched", false)) and not bool(container.get("busy", false))


static func can_take(container: Dictionary) -> bool:
	return not container.is_empty() and bool(container.get("searched", false)) and not bool(container.get("locked", false)) and not bool(container.get("busy", false))
