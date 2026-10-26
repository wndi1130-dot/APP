extends RefCounted
## The dead eat the dead (decision 423, card 4): by the body of one of the
## living that lies there, not yet up again, one of the dead kneels and eats.
## While it eats it sees half as far and hears as ever, and the wandering dead
## near a body are drawn to it. A body still gets up as before (RISE_TIME):
## then those eating it stop. There are no beasts in the field yet; when there
## are, their bodies go in the same way.
##
## New values (not in the reference game as plain numbers), for the phone:
const SIGHT_MULT: float = 0.5   # decided (card 4): eating, it sees half as far
const GATHER_R: float = 10.0    # the wandering dead within this of a body come to it
const REACH: float = 1.2        # where a body walking to a clue stops (zombies.gd investigate): it kneels there
const AT_MOST: int = 3          # so many eat at one body; the rest stand round it
const EAT_TOTAL: float = 120.0  # 결정 441 (3): a body is eaten up when its eaters' seconds add up to this
const EATEN_META: StringName = &"dead_eaten_seconds"   # those seconds, kept on the body (and in the field save)
const LEAVE_R: float = 1.6      # pushed further off it than this, it walks back to it


## True while a body can be eaten: one of the living, dead, and not up again
## (its own risen self, `rising`, still lying there, or put down for good).
static func edible(p, rising: Dictionary) -> bool:
	if p == null or not is_instance_valid(p) or not p.body.dead:
		return false
	if float(p.get_meta(EATEN_META, 0.0)) >= EAT_TOTAL:
		return false
	if rising.is_empty():
		return true
	return String(rising.get("state", "")) in ["rising", "dead"]
