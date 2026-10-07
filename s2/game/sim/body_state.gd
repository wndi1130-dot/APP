extends RefCounted
# One person's body in the field (body_injury 4, 4.2, 4.5). Times are field seconds.

const WINDOW := 480.0
const SCRATCH_INFECT := 0.10
const LIGHT_BLEED_STOP := 240.0
const HEAVY_DOWN := 120.0
const DOWN_DEATH := 60.0
const QUICK_TREAT := 120.0       # medic within 2 min eases one step (body_injury 4)
const GUNSHOT_LEG := 0.25

const RUN_FATIGUE := 0.004       # exhaustion per second while running
const OVERLOAD_FATIGUE := 1.6    # carry_state >= 2
const COLD_FATIGUE := 1.25       # cold_level >= 1
const REST_RECOVER := 1.0 / 120.0  # indoor rest: about one level per minute (doc 4 table)
const BREATH_RUN := 0.12
const BREATH_REST := 0.25
const RUN_BREATH_MIN := 0.15

const FLOOR := 0.5
const MOVE_FLOOR := 0.25
const AIM_UP := 1.4
const AIM_MAX := 3.0

var bleed: int = 0               # 0 none, 1 light, 2 heavy
var arm_fracture: bool = false
var leg_fracture: bool = false
var splinted: bool = false
var infection: String = ""       # "" | "scratch" | "bite"
var infected: bool = false       # hidden for scratches
var window_left: float = 0.0
var exhaustion: float = 0.0
var breath: float = 1.0
var downed: bool = false
var dead: bool = false
var bite_part: String = ""
var heavy_bleed_time: float = 0.0
var light_bleed_time: float = 0.0
var down_time: float = 0.0       # time spent downed while bleeding heavily
var injured_at: float = -INF
var cold_level: int = 0          # last cold_level seen by tick(), for icons
var _heavy_reported: bool = false


func apply_bite(_rng: RandomNumberGenerator, part: String, now: float) -> void:
	var had_window: bool = infected and window_left > 0.0
	_wound(1, now)
	infection = "bite"
	bite_part = part
	window_left = minf(window_left, WINDOW) if had_window else WINDOW
	infected = true


func apply_scratch(rng: RandomNumberGenerator, now: float) -> void:
	_wound(1, now)
	var roll: bool = rng.randf() < SCRATCH_INFECT
	if infection != "bite":
		infection = "scratch"
	infected = infected or roll
	window_left = minf(window_left, WINDOW) if window_left > 0.0 else WINDOW


func apply_cut(heavy: bool, now: float) -> void:
	_wound(2 if heavy else 1, now)


# Heavy bleed; 25% hits the leg and breaks it. Already bleeding heavily: downed.
func apply_gunshot(rng: RandomNumberGenerator, now: float) -> String:
	var was_heavy: bool = bleed >= 2
	_wound(2, now)
	var part: String = "torso"
	if rng.randf() < GUNSHOT_LEG:
		part = "leg"
		leg_fracture = true
		splinted = false
	if was_heavy:
		downed = true
	return part


# Heavy needs two bandages (count >= 2) to become light; light stops with one. One step per call.
func bandage(count: int = 1) -> bool:
	if bleed >= 2:
		if count < 2:
			return false
		_set_bleed(1)
		return true
	if bleed == 1 and count >= 1:
		_set_bleed(0)
		return true
	return false


func use_kit() -> bool:
	if bleed == 0:
		return false
	_set_bleed(0)
	return true


func splint() -> void:
	if arm_fracture or leg_fracture:
		splinted = true


func fracture(arm: bool) -> void:
	if arm:
		arm_fracture = true
	else:
		leg_fracture = true
	splinted = false


func quick_treat_ok(now: float) -> bool:
	return now - injured_at <= QUICK_TREAT


func add_fatigue(x: float) -> void:
	exhaustion = clampf(exhaustion + x, 0.0, 1.0)


# Exhaustion rate multiplier from load and cold (also for add_fatigue callers).
static func fatigue_mult(ctx: Dictionary) -> float:
	var m: float = 1.0
	if int(ctx.get("carry_state", 0)) >= 2:
		m *= OVERLOAD_FATIGUE
	if int(ctx.get("cold_level", 0)) >= 1:
		m *= COLD_FATIGUE
	return m


# ctx: running, swinging, carry_state, cold_level, indoor_rest. Returns event names.
func tick(delta: float, ctx: Dictionary) -> Array:
	var events: Array = []
	if dead or delta <= 0.0:
		return events
	var running: bool = bool(ctx.get("running", false))
	var swinging: bool = bool(ctx.get("swinging", false))
	cold_level = int(ctx.get("cold_level", 0))

	# Bleeding
	if bleed == 1:
		if not running:
			light_bleed_time += delta
			if light_bleed_time >= LIGHT_BLEED_STOP:
				_set_bleed(0)
				events.append("bleed_stopped")
	elif bleed >= 2:
		heavy_bleed_time += delta
		if downed:
			down_time += delta
		elif heavy_bleed_time >= HEAVY_DOWN:
			downed = true
			down_time = heavy_bleed_time - HEAVY_DOWN
			events.append("downed")
		if downed and down_time >= DOWN_DEATH:
			dead = true
			events.append("died")
			return events

	# Infection window
	if infection != "" and window_left > 0.0:
		window_left = maxf(0.0, window_left - delta)
		if window_left <= 0.0:
			events.append("window_closed")
			if not infected:
				infection = ""

	# Exhaustion
	var gain: float = RUN_FATIGUE * delta if running else 0.0
	exhaustion += gain * fatigue_mult(ctx)
	if bool(ctx.get("indoor_rest", false)) and not running and not swinging:
		exhaustion -= REST_RECOVER * delta
	exhaustion = clampf(exhaustion, 0.0, 1.0)
	if exhaustion_level() == 2:
		if not _heavy_reported:
			_heavy_reported = true
			events.append("exhausted_heavy")
	else:
		_heavy_reported = false

	# Breath
	if running:
		breath -= BREATH_RUN * delta
	elif not swinging:
		breath += BREATH_REST * delta
	breath = clampf(breath, 0.0, 1.0)
	return events


func exhaustion_level() -> int:
	if exhaustion >= 0.8:
		return 2
	if exhaustion >= 0.5:
		return 1
	return 0


func can_run() -> bool:
	return not leg_fracture and exhaustion_level() < 2 and breath > RUN_BREATH_MIN and not downed and not dead


# body_injury 4.2. Speed factors (time = base / factor) except aim_min (circle floor size, bigger is worse).
# ctx: carry_state 0..3, cold_level 0..3, gloves, heavy_coat, panic, strength.
func multipliers(ctx: Dictionary) -> Dictionary:
	var carry: int = int(ctx.get("carry_state", 0))
	var cold: int = int(ctx.get("cold_level", 0))
	var strong: bool = int(ctx.get("strength", 5)) >= 7
	var m: Dictionary = {
		"move": 1.0, "swing": 1.0, "aim_min": 1.0, "reload": 1.0,
		"swap": 1.0, "hands": 1.0, "shove_window": 1.0, "aim_shrink": 1.0,
	}
	# Bag (strength 7+ halves these)
	if carry == 1:
		_mul(m, "move", _soft(0.9, strong))
	elif carry >= 2:
		_mul(m, "move", _soft(0.7, strong))
		_mul(m, "swing", _soft(0.85, strong))
		_mul(m, "shove_window", _soft(0.8, strong))
	# Exhaustion (strength 7+ halves these)
	var ex: int = exhaustion_level()
	if ex == 1:
		_mul(m, "swing", _soft(0.9, strong))
		_mul(m, "hands", _soft(0.9, strong))
		_mul(m, "aim_shrink", _soft(0.7, strong))
	elif ex == 2:
		_mul(m, "swing", _soft(0.75, strong))
		_mul(m, "hands", _soft(0.75, strong))
		_mul(m, "shove_window", _soft(0.8, strong))
		_mul(m, "aim_shrink", _soft(0.5, strong))
		m["aim_min"] = float(m["aim_min"]) * (1.0 + (AIM_UP - 1.0) * (0.5 if strong else 1.0))
	# Heavy bleed
	if bleed >= 2:
		_mul(m, "move", 0.8)
		_mul(m, "swing", 0.85)
		_mul(m, "aim_min", AIM_UP)
	# Arm fracture
	if arm_fracture:
		_mul(m, "aim_min", AIM_UP)
		_mul(m, "reload", 0.6)
		_mul(m, "swap", 0.7)
		_mul(m, "hands", 0.5)
		_mul(m, "shove_window", 0.7)
	# Leg fracture: splinted limps, unsplinted crawls
	if leg_fracture:
		_mul(m, "move", 0.6 if splinted else MOVE_FLOOR)
		_mul(m, "swing", 0.9)
		_mul(m, "shove_window", 0.7)
	# Cold: 추움 row from level 1, hypothermia rows stack on top
	if cold >= 1:
		_mul(m, "move", 0.95)
		_mul(m, "swing", 0.95)
		_mul(m, "reload", 0.9)
		_mul(m, "hands", 0.9)
	if cold == 2:
		_mul(m, "aim_min", AIM_UP)
		_mul(m, "reload", 0.8)
		_mul(m, "swap", 0.9)
		_mul(m, "hands", 0.8)
	elif cold >= 3:
		_mul(m, "move", 0.85)
		_mul(m, "aim_min", AIM_UP)
		_mul(m, "reload", 0.6)
		_mul(m, "swap", 0.7)
		_mul(m, "hands", 0.6)
	if bool(ctx.get("gloves", false)):
		_mul(m, "reload", 0.9)
		_mul(m, "swap", 0.9)
		_mul(m, "hands", 0.9)
	if bool(ctx.get("heavy_coat", false)):
		_mul(m, "move", 0.85)
		_mul(m, "swing", 0.9)
	if bool(ctx.get("panic", false)):
		_mul(m, "aim_min", AIM_UP)
		_mul(m, "reload", 0.8)
		_mul(m, "swap", 0.8)
		_mul(m, "hands", 0.6)
	# Floors and caps
	for k: String in ["swing", "reload", "swap", "hands", "shove_window", "aim_shrink"]:
		m[k] = maxf(FLOOR, float(m[k]))
	m["move"] = maxf(MOVE_FLOOR, float(m["move"]))
	m["aim_min"] = minf(AIM_MAX, float(m["aim_min"]))
	if carry >= 3:
		m["move"] = 0.0
	m["one_hand"] = arm_fracture
	return m


# Up to five icons, most urgent first: infection, then severe before light.
func icons() -> Array:
	var severe: Array = []
	var light: Array = []
	var out: Array = []
	if infection != "":
		out.append({"id": "infection", "severe": infection == "bite"})
	var rest: Array = []
	if bleed > 0:
		rest.append({"id": "bleed", "severe": bleed >= 2})
	if arm_fracture or leg_fracture:
		rest.append({"id": "fracture", "severe": leg_fracture and not splinted})
	if cold_level >= 1:
		rest.append({"id": "cold", "severe": cold_level >= 3, "faint": cold_level == 1})
	if exhaustion_level() >= 1:
		rest.append({"id": "exhaustion", "severe": exhaustion_level() >= 2})
	for icon: Dictionary in rest:
		if bool(icon["severe"]):
			severe.append(icon)
		else:
			light.append(icon)
	out.append_array(severe)
	out.append_array(light)
	return out.slice(0, 5)


# One short word for the roster screen (body_injury 4.2: '느림', '손이 떨림').
func status_words() -> String:
	if dead:
		return "죽음"
	if downed:
		return "쓰러짐"
	if infection == "bite":
		return "물림"
	if bleed >= 2:
		return "피를 흘림"
	if leg_fracture:
		return "느림" if splinted else "못 걸음"
	if arm_fracture:
		return "한 손"
	if cold_level >= 2:
		return "손이 떨림"
	if exhaustion_level() >= 2:
		return "지침"
	if infection == "scratch":
		return "긁힘"
	if bleed == 1:
		return "피가 남"
	if cold_level == 1:
		return "추움"
	if exhaustion_level() == 1:
		return "피곤함"
	return "멀쩡함"


func _wound(level: int, now: float) -> void:
	if level > bleed:
		bleed = level
	if bleed == 1:
		light_bleed_time = 0.0
	injured_at = now


func _set_bleed(level: int) -> void:
	bleed = level
	if level < 2:
		heavy_bleed_time = 0.0
		down_time = 0.0
		downed = false
	if level == 0:
		light_bleed_time = 0.0


static func _soft(f: float, halve: bool) -> float:
	return 1.0 - (1.0 - f) * 0.5 if halve else f


static func _mul(m: Dictionary, key: String, f: float) -> void:
	m[key] = float(m[key]) * f
