extends RefCounted
# One person's body heat (body_injury 4.5, survival_detail 1). 0..100, field seconds.

const WARM := 65.0
const COLD := 35.0
const HYPO := 12.0
const BASE_LOSS := 0.11          # per second outside, calibrated: warmth 0.6 calm -> cold ~6 min, hypo ~11 min
const MOVING_MULT := 0.8
const INDOOR_MULT := 0.25
const STOVE_GAIN := 1.2
const REF_AMBIENT := -14.0       # BASE_LOSS is tuned for this outside temperature
const NO_LOSS_AT := 10.0         # at or above this ambient (C) no heat is lost
const DRY_STOVE := 0.02
const DRY_SLOW := 0.001          # away from a stove: very slow
const WET_COLD_THRESHOLD := 0.0
const DEFAULT_WARMTH := 0.6
const MAX_WARMTH := 1.2
const LOSS_WITHOUT_INSULATION := 1.25
const WARMTH_LOSS_CUT := 0.6

var heat: float = 100.0
var wet: float = 0.0


func save_of() -> Dictionary:
	return {"heat": heat, "wet": wet}


func restore(saved: Dictionary) -> void:
	heat = float(saved.get("heat", heat))
	wet = float(saved.get("wet", wet))


# 0 warm (>=65), 1 cold (>=35), 2 light hypothermia (>=12), 3 severe.
func level() -> int:
	return level_of(heat)


static func level_of(h: float) -> int:
	if h >= WARM:
		return 0
	if h >= COLD:
		return 1
	if h >= HYPO:
		return 2
	return 3


func soak(x: float) -> void:
	wet = clampf(wet + x, 0.0, 1.0)


# Heat lost per second outside for this ctx (before indoor/stove rules).
static func loss_rate(ctx: Dictionary, wet_now: float) -> float:
	var ambient: float = float(ctx.get("ambient_c", REF_AMBIENT))
	var amb: float = maxf(0.0, (NO_LOSS_AT - ambient) / (NO_LOSS_AT - REF_AMBIENT))
	var wind: float = clampf(float(ctx.get("wind", 0.0)), 0.0, 1.0)
	var windproof: float = clampf(float(ctx.get("windproof", 0.0)), 0.0, 1.0)
	var wet_ratio := clampf(wet_now, 0.0, 1.0)
	var warmth: float = clampf(float(ctx.get("warmth", DEFAULT_WARMTH)), 0.0, MAX_WARMTH)
	# Soaked through cools twice as fast (the 1 + wet term) and the warmth is not
	# cut again: no decision or brief gives a number for it.
	var r: float = BASE_LOSS * amb * (1.0 + wind * (1.0 - windproof)) * (1.0 + wet_ratio) * (LOSS_WITHOUT_INSULATION - warmth * WARMTH_LOSS_CUT)
	if bool(ctx.get("moving", false)):
		r *= MOVING_MULT
	return maxf(0.0, r)


# ctx: ambient_c, indoor, stove, wet, warmth, windproof, moving, wind.
func tick(delta: float, ctx: Dictionary) -> void:
	if delta <= 0.0:
		return
	wet = maxf(clampf(wet, 0.0, 1.0), clampf(float(ctx.get("wet", 0.0)), 0.0, 1.0))
	if bool(ctx.get("stove", false)):
		heat += STOVE_GAIN * delta
		wet = maxf(0.0, wet - DRY_STOVE * delta)
	else:
		var r: float = loss_rate(ctx, wet)
		if bool(ctx.get("indoor", false)):
			r *= INDOOR_MULT
		heat -= r * delta
		wet = maxf(0.0, wet - DRY_SLOW * delta)
	heat = clampf(heat, 0.0, 100.0)
