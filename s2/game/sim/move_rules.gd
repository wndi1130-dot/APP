extends RefCounted
## How one walking a path (the companions, the work crew, raiders) turns into the
## way before it goes, so that it does not glide off sideways or backwards at full
## pace while its body is still coming round (user field test 10-25: the
## companions "whip round and move like drones").
##
## The drawn body turns at its own rate (person.gd turn_rate, look); the feet go
## with it: full pace while it faces within FREE_DEG of the way, less the further
## it is off, and none past STILL_DEG, where it turns on the spot first (the
## people's drawing steps round by the turn). As the reference game's moves have
## it: a turn of up to a quarter is blended into the walk, a half turn is a turn
## of its own. It has no easing in and out of its pace: one at 0.2 s left the
## companions behind the chief and bitten more (40 runs 10-26, on the walk 5 → 13).
##
## Swarmed, a companion backs off with its face to them (field_ai.gd _engage), at a
## walk at most, the walk drawn backwards (the step round runs back).

const FREE_DEG: float = 25.0
const STILL_DEG: float = 90.0
const BACKPEDAL: float = 2.1    # m/s stepping back with the face to them: a walk, never a run (1.3 fell behind the hurrying dead)
const FACE_HOLD: float = 0.5    # seconds a face to them holds after the AI last asked for it
const FOLLOW_TURN_FLOOR: float = 0.3   # Decision 486: opt-in pace while a follower turns.
const FOLLOW_TURN_STOP_DEG: float = 135.0


## The share of its pace a body walks at with its drawn body `off` radians from the way.
static func heading_share(off: float) -> float:
	var free := deg_to_rad(FREE_DEG)
	if off <= free:
		return 1.0
	if off >= deg_to_rad(STILL_DEG):
		return 0.0
	return cos(off) / cos(free)
