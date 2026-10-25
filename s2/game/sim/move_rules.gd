extends RefCounted
## How one walking a path (the companions, the work crew, raiders) turns into the
## way and gets going, so that it does not glide off sideways or backwards at
## full pace while its body is still coming round, nor start and stop dead
## (user field test 10-25: the companions "whip round and move like drones").
##
## The drawn body turns at its own rate (person.gd turn_rate, look); the feet go
## with it: full pace while it faces within FREE_DEG of the way, less the further
## it is off, and none past STILL_DEG, where it turns on the spot first (the
## people's drawing steps round by the turn). As the reference game's moves have
## it: a turn of up to a quarter is blended into the walk, a half turn is a turn
## of its own. The pace comes up and goes down over the seconds the thumb's walk
## takes (field_game.gd DRIVE_START, DRIVE_STOP, DRIVE_STOP_RUN).
##
## Swarmed, a companion backs off with its face to them (field_ai.gd _engage),
## slower than a walk, the walk drawn backwards (the step round runs back).

const FREE_DEG: float = 25.0
const STILL_DEG: float = 90.0
const START: float = 0.2        # seconds to come up to pace
const STOP: float = 0.25        # seconds to come down from a walk
const STOP_RUN: float = 0.4     # and from a run
const BACKPEDAL: float = 1.3    # m/s stepping back with the face to them (a walk is 2.1)
const FACE_HOLD: float = 0.5    # seconds a face to them holds after the AI last asked for it


## The share of its pace a body walks at with its drawn body `off` radians from the way.
static func heading_share(off: float) -> float:
	var free := deg_to_rad(FREE_DEG)
	if off <= free:
		return 1.0
	if off >= deg_to_rad(STILL_DEG):
		return 0.0
	return cos(off) / cos(free)


## The pace after `delta`: up toward `want` over START of the full pace `top`,
## down over STOP (STOP_RUN from above a walk `walk`).
static func paced(pace: float, want: float, top: float, walk: float, delta: float) -> float:
	if want >= pace:
		return minf(want, pace + top / START * delta)
	var stop_t := STOP_RUN if pace > walk * 1.1 else STOP
	return maxf(want, pace - maxf(pace, walk) / stop_t * delta)
