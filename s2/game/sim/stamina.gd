extends RefCounted
## The short breath and the stop's accumulated fatigue use separate clocks.

const RUN_FATIGUE := 0.004
const OVERLOAD_FATIGUE := 1.6
const COLD_FATIGUE := 1.25
const REST_RECOVER := 1.0 / 120.0
const BREATH_RUN := 0.12
const MELEE_BREATH_PER_SECOND := BREATH_RUN # reserved for the combat owner
const BREATH_REST := 0.25
const RUN_BREATH_MIN := 0.15
const RUN_BREATH_RESUME := 0.25
const FATIGUE_LIGHT := 0.5
const FATIGUE_HEAVY := 0.8
const REST_FATIGUE_PENALTY := 0.85
const WALK_RECOVERY_MULT := 0.25
const CROUCH_EFFORT_MULT := 1.5
const LOAD_BREATH_MULT := [1.0, 1.0, 1.5, 2.8]


static func fatigue_mult(ctx: Dictionary) -> float:
	var value := OVERLOAD_FATIGUE if int(ctx.get("carry_state", 0)) >= 2 else 1.0
	if int(ctx.get("cold_level", 0)) >= 1:
		value *= COLD_FATIGUE
	return value


static func breath_mult(ctx: Dictionary) -> float:
	var value: float = LOAD_BREATH_MULT[clampi(int(ctx.get("carry_state", 0)), 0, 3)]
	if int(ctx.get("cold_level", 0)) >= 1:
		value *= COLD_FATIGUE
	if bool(ctx.get("crouched", false)):
		value *= CROUCH_EFFORT_MULT
	return value * maxf(1.0, float(ctx.get("torso_effort", 1.0)))


static func advance(exhaustion: float, breath: float, delta: float, ctx: Dictionary) -> Vector2:
	if delta <= 0.0:
		return Vector2(exhaustion, breath)
	var running := bool(ctx.get("running", false))
	var moving := bool(ctx.get("moving", running))
	var working := bool(ctx.get("swinging", false)) or bool(ctx.get("working", false))
	var fatigue := clampf(exhaustion, 0.0, 1.0)
	var air := clampf(breath, 0.0, 1.0)
	if running:
		fatigue += RUN_FATIGUE * delta * fatigue_mult(ctx) * maxf(1.0, float(ctx.get("torso_effort", 1.0)))
		air -= BREATH_RUN * delta * breath_mult(ctx)
	elif not working:
		var recovery := maxf(0.0, 1.0 - fatigue * (1.0 if moving else REST_FATIGUE_PENALTY))
		if moving:
			recovery *= WALK_RECOVERY_MULT
		if not moving or int(ctx.get("carry_state", 0)) < 2:
			air += BREATH_REST * delta * recovery
		if bool(ctx.get("indoor_rest", false)) and not moving:
			fatigue -= REST_RECOVER * delta
	return Vector2(clampf(fatigue, 0.0, 1.0), clampf(air, 0.0, 1.0))


## A climb pays its equivalent active seconds on entry, even when cut short.
static func climb_cost(seconds: float, ctx: Dictionary) -> Vector2:
	var duration := maxf(0.0, seconds)
	return Vector2(RUN_FATIGUE * duration * fatigue_mult(ctx), BREATH_RUN * duration * breath_mult(ctx))
