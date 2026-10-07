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
		r *= 0.5
	return r * maxf(range_mult, 0.0)


## Walk 3m, run 12m (glass: walking counts as 12m too). Crouch (walk only) x0.5 and
## stealth -4%/level (max -40%, crouched only). Then floor and trait multipliers.
static func footstep_radius(running: bool, floor_mult: float, trait_mult: float, crouched: bool, stealth_skill: int, on_glass: bool = false) -> float:
	var r: float = RUN_RADIUS if (running or on_glass) else WALK_RADIUS
	if crouched and not running:
		r *= CROUCH_MULT
		var cut: float = minf(STEALTH_STEP * float(maxi(stealth_skill, 0)), STEALTH_MAX)
		r *= 1.0 - cut
	return r * maxf(floor_mult, 0.0) * maxf(trait_mult, 0.0)


static func footstep_level(running: bool, on_glass: bool) -> int:
	if running or on_glass:
		return Level.NORMAL
	return Level.QUIET
