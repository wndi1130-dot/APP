extends RefCounted
## Breaking a window and the glass in its frame; cuts stay in the body/combat
## rules. Opening, latches, boards and curtains are building_rules.gd.

const BuildingRules = preload("res://game/sim/building_rules.gd")

const BREAK_SECONDS := 1.0
const CLEAR_SECONDS := 3.0
const IMMOBILE_LOAD := 3


## Boards in front of the glass keep a blow off it.
static func can_break(window: Dictionary) -> bool:
	return not window.is_empty() and not bool(window.get("broken", false)) and BuildingRules.planks_total(window) == 0


static func can_clear(window: Dictionary) -> bool:
	return not window.is_empty() and bool(window.get("broken", false)) and bool(window.get("glass", false))


static func can_cross(window: Dictionary, carry_state: int) -> bool:
	return not window.is_empty() and BuildingRules.window_passable(window) and carry_state < IMMOBILE_LOAD
