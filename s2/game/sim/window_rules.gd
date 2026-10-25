extends RefCounted
## Breaking a window and the glass in its frame; cuts stay in the body/combat
## rules. Opening, latches, boards and curtains are building_rules.gd.

const BuildingRules = preload("res://game/sim/building_rules.gd")

const BREAK_SECONDS := 1.0
const CLEAR_SECONDS := 3.0
const IMMOBILE_LOAD := 3
## Climbing through a frame with its broken glass still in: a cut leg, less likely in gloves.
const CROSS_CUT := 0.5
const CROSS_CUT_GLOVED := 0.2
## Pulling the glass out bare-handed, nothing held to knock it out with: now and then a cut hand.
const CLEAR_CUT_BARE := 0.1
## The player walking (not running) into a frame with glass in it is stopped and asked once;
## the frame stays shut to them this long while the choice is up, then lets them through.
const ASK_HOLD := 3.0


## Boards in front of the glass keep a blow off it.
static func can_break(window: Dictionary) -> bool:
	return not window.is_empty() and not bool(window.get("broken", false)) and BuildingRules.planks_total(window) == 0


static func can_clear(window: Dictionary) -> bool:
	return not window.is_empty() and bool(window.get("broken", false)) and bool(window.get("glass", false))


static func can_cross(window: Dictionary, carry_state: int) -> bool:
	return not window.is_empty() and BuildingRules.window_passable(window) and carry_state < IMMOBILE_LOAD


static func cross_cut_chance(window: Dictionary, gloves: bool) -> float:
	if not can_clear(window):
		return 0.0
	return CROSS_CUT_GLOVED if gloves else CROSS_CUT


## Gloves, or anything in the hand to knock the shards out with, keep the hand whole.
static func clear_cut_chance(gloves: bool, holding: bool) -> float:
	return 0.0 if gloves or holding else CLEAR_CUT_BARE


## Ask before climbing in: glass still in the frame, walking, and either not asked at
## this frame yet or asked so lately that the choice is still up.
static func holds_for_choice(window: Dictionary, running: bool, asked: bool, asked_at: float, now: float) -> bool:
	if not can_clear(window) or running:
		return false
	return not asked or now - asked_at < ASK_HOLD
