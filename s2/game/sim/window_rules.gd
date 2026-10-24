extends RefCounted
## Whole windows remain shut in this slice; cuts stay in the body/combat rules.

const BREAK_SECONDS := 1.0
const CLEAR_SECONDS := 3.0
const IMMOBILE_LOAD := 3


static func can_break(window: Dictionary) -> bool:
	return not window.is_empty() and not bool(window.get("broken", false))


static func can_clear(window: Dictionary) -> bool:
	return not window.is_empty() and bool(window.get("broken", false)) and bool(window.get("glass", false))


static func can_cross(window: Dictionary, carry_state: int) -> bool:
	return not window.is_empty() and bool(window.get("broken", false)) and carry_state < IMMOBILE_LOAD
