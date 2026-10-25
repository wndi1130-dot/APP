extends RefCounted
## Sound levels, scores and radii (field_unified 6, body_injury 8).

enum Level { QUIET, NORMAL, LOUD, VERY_LOUD }

const SCORE := [0, 1, 3, 6]
const RADIUS := [3.0, 12.0, 35.0, 1000.0]
## Seconds zombies inside the radius stay at the spot.
const LINGER := [0.0, 30.0, 60.0, 90.0]
const NAMES := ["조용함", "보통", "시끄러움", "매우 시끄러움"]

const WALK_RADIUS := 3.0
const RUN_RADIUS := 12.0
const CROUCH_MULT := 0.5
const STEALTH_STEP := 0.04
const STEALTH_MAX := 0.40
const WHOLE_MAP_MIN := 500.0
const INDOOR_MULT := 0.5
const STEP_EVERY := 0.5
## Footsteps go by the walk (decision 425, as the reference game times them):
## two to a round of the gait, at these points of it, the round being the
## metres the living's own walk, run and crouched walk cover (their baked
## "round"; tests check they match), each person's own stride on it (gait.gd).
## Loudness and reach are as they were.
const STEP_AT := [0.2, 0.65]
const STEP_ROUND := {"walk": 1.64, "run": 2.27, "crouch": 1.19}
const EVENT_DISPLAY_SECONDS := 1.6


static func clamp_level(level: int) -> int:
	return clampi(level, Level.QUIET, Level.VERY_LOUD)


static func score(level: int) -> int:
	return SCORE[clamp_level(level)]


## Indoor halves the radius, then range_mult applies. VERY_LOUD always reaches the whole map.
static func radius(level: int, indoor: bool, range_mult: float = 1.0) -> float:
	var lv := clamp_level(level)
	var r: float = RADIUS[lv]
	if lv == Level.VERY_LOUD:
		return maxf(r * maxf(range_mult, 0.0), WHOLE_MAP_MIN)
	if indoor:
		r *= INDOOR_MULT
	return r * maxf(range_mult, 0.0)


## Walk 3m, run 12m (glass: walking counts as 12m too). Crouch (walk only) x0.5 and
## stealth -4%/level (max -40%, crouched only). Then floor and trait multipliers.
static func footstep_radius(running: bool, floor_mult: float, trait_mult: float, crouched: bool, stealth_skill: int, on_glass: bool = false, indoor: bool = false) -> float:
	var r: float = RUN_RADIUS if (running or on_glass) else WALK_RADIUS
	if crouched and not running:
		r *= CROUCH_MULT
		var cut: float = minf(STEALTH_STEP * float(maxi(stealth_skill, 0)), STEALTH_MAX)
		r *= 1.0 - cut
	return r * maxf(floor_mult, 0.0) * maxf(trait_mult, 0.0) * (INDOOR_MULT if indoor else 1.0)


static func footstep_level(running: bool, on_glass: bool) -> int:
	if running or on_glass:
		return Level.NORMAL
	return Level.QUIET
