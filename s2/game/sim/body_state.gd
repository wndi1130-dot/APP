extends RefCounted
# One person's body in the field (body_injury 4, 4.2, 4.5, 4.6). Times are field seconds.
# The wound list is the source of truth; bleed, arm_fracture, leg_fracture, splinted and
# bite_part are read from it (the first four also accept writes, kept for old callers and tests).

const WINDOW := 480.0
const SCRATCH_INFECT := 0.10
const LIGHT_BLEED_STOP := 240.0
const HEAVY_DOWN := 120.0
const DOWN_DEATH := 60.0
const QUICK_TREAT := 120.0       # medic within 2 min eases one step (body_injury 4)
const GUNSHOT_LEG := 0.25

# Wound model (body_injury 4.6). Names match s1/schema/receipt.schema.json $defs.wound.
const PARTS := ["head_neck", "torso", "arm_left", "arm_right", "leg_left", "leg_right"]
const KINDS := ["scratch", "laceration", "deep", "embedded", "bite", "fracture"]
# Starting blood flow per kind (start values). Heavy bleeding is a total of 1.0 or more.
const BLOOD := {"scratch": 0.15, "laceration": 0.4, "deep": 1.0, "embedded": 1.0, "bite": 0.4, "fracture": 0.0}
const HEAVY_BLOOD := 1.0
const SEEP_BLOOD := 0.4          # a heavy wound with a plain bandage seeps on as a light one

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

# One entry per wound: {part, kind, blood, disinfected, bandaged, splinted, festering, at}.
# blood is the flow now (0 once stopped); festering is only a slot until stage 2 sets it.
var wounds: Array[Dictionary] = []
var infection: String = ""       # "" | "scratch" | "bite"
var infected: bool = false       # hidden for scratches
var window_left: float = 0.0
var exhaustion: float = 0.0
var breath: float = 1.0
var downed: bool = false
var dead: bool = false
var heavy_bleed_time: float = 0.0
var light_bleed_time: float = 0.0
var down_time: float = 0.0       # time spent downed while bleeding heavily
var injured_at: float = -INF
var cold_level: int = 0          # last cold_level seen by tick(), for icons
var _heavy_reported: bool = false
var _level_seen: int = 0         # bleed level at the last change, to reset timers on a drop

# 0 none, 1 light, 2 heavy: from the total blood of all wounds (body_injury 4.6).
var bleed: int:
	get:
		return bleed_level()
	set(value):
		_force_bleed(value)

# Any broken arm / leg. Writing true adds a fracture on a free side, false clears them.
var arm_fracture: bool:
	get:
		return has_fracture("arm")
	set(value):
		_set_fracture("arm", value)

var leg_fracture: bool:
	get:
		return has_fracture("leg")
	set(value):
		_set_fracture("leg", value)

# True when there is a fracture and every fracture has a splint. Writing sets all of them.
var splinted: bool:
	get:
		return fractures_splinted("")
	set(value):
		for w: Dictionary in wounds:
			if w["kind"] == "fracture":
				w["splinted"] = value

# Coarse place of the latest bite ("arm", "torso", "leg", "head_neck"); "" without a bite.
var bite_part: String:
	get:
		for i in range(wounds.size() - 1, -1, -1):
			if wounds[i]["kind"] == "bite":
				return coarse(String(wounds[i]["part"]))
		return ""


## Adds a wound and returns its index (-1 for an unknown part or kind).
## blood < 0 takes the start value of the kind.
func add_wound(part: String, kind: String, now: float, blood: float = -1.0) -> int:
	if not PARTS.has(part) or not KINDS.has(kind):
		push_warning("body: bad wound %s / %s" % [part, kind])
		return -1
	wounds.append({
		"part": part, "kind": kind,
		"blood": float(BLOOD[kind]) if blood < 0.0 else blood,
		"disinfected": false, "bandaged": false, "splinted": false, "festering": false,
		"at": now,
	})
	_refresh()
	if wounds[-1]["blood"] > 0.0 and bleed_level() == 1:
		light_bleed_time = 0.0
	return wounds.size() - 1


func apply_bite(_rng: RandomNumberGenerator, part: String, now: float) -> void:
	var had_window: bool = infected and window_left > 0.0
	add_wound(_fine_part(part, "bite"), "bite", now)
	injured_at = now
	infection = "bite"
	window_left = minf(window_left, WINDOW) if had_window else WINDOW
	infected = true


func apply_scratch(rng: RandomNumberGenerator, now: float, part: String = "torso") -> void:
	add_wound(_fine_part(part, "scratch"), "scratch", now)
	injured_at = now
	var roll: bool = rng.randf() < SCRATCH_INFECT
	if infection != "bite":
		infection = "scratch"
	infected = infected or roll
	window_left = minf(window_left, WINDOW) if window_left > 0.0 else WINDOW


# A light cut tears (laceration), a heavy one goes deep.
func apply_cut(heavy: bool, now: float, part: String = "torso") -> void:
	add_wound(_fine_part(part, "cut"), "deep" if heavy else "laceration", now)
	injured_at = now


# Heavy bleed (a bullet stays in); 25% hits a leg and breaks it. Already bleeding heavily: downed.
# Returns the coarse place ("torso" or "leg"). The side comes from the same roll.
func apply_gunshot(rng: RandomNumberGenerator, now: float) -> String:
	var was_heavy: bool = bleed_level() >= 2
	var roll: float = rng.randf()
	var part: String = "torso"
	if roll < GUNSHOT_LEG:
		part = "leg"
	var fine: String = "torso" if part == "torso" else ("leg_left" if roll < GUNSHOT_LEG * 0.5 else "leg_right")
	add_wound(fine, "embedded", now)
	injured_at = now
	if part == "leg" and not _has_fracture_on(fine):
		add_wound(fine, "fracture", now)
	if was_heavy:
		downed = true
	return part


# Dresses the most urgent bleeding wounds with `count` bandages. A heavy wound (blood 1.0+)
# takes two and then seeps on as a light one; any other takes one and stops. When the
# person bled heavily this is one step: it ends once the level drops below heavy.
func bandage(count: int = 1) -> bool:
	var budget: int = count
	var start: int = bleed_level()
	var done := false
	while budget > 0:
		var i: int = _top_bleeder()
		if i < 0:
			break
		var heavy: bool = float(wounds[i]["blood"]) >= HEAVY_BLOOD
		var cost: int = 2 if heavy else 1
		if cost > budget:
			break
		wounds[i]["blood"] = SEEP_BLOOD if heavy else 0.0
		wounds[i]["bandaged"] = true
		budget -= cost
		done = true
		_refresh()
		if start >= 2 and bleed_level() < 2:
			break
	return done


# A medkit stops the blood of every wound at once.
func use_kit() -> bool:
	if bleed_level() == 0:
		return false
	for w: Dictionary in wounds:
		if float(w["blood"]) > 0.0:
			w["blood"] = 0.0
			w["bandaged"] = true
	_refresh()
	return true


# Splints one broken limb, the most urgent first (a leg before an arm).
func splint() -> void:
	var i: int = _top_fracture()
	if i >= 0:
		wounds[i]["splinted"] = true


# Cleans one wound: the given index, or the most urgent one not cleaned yet. Fractures stay as they are.
func disinfect(index: int = -1) -> bool:
	if index < 0:
		var best_key := -1.0
		for i in wounds.size():
			if wounds[i]["kind"] != "fracture" and not wounds[i]["disinfected"] and _order_key(i) > best_key:
				index = i
				best_key = _order_key(i)
	if index < 0 or index >= wounds.size() or wounds[index]["kind"] == "fracture":
		return false
	wounds[index]["disinfected"] = true
	return true


# The festering slot (stage 2 decides when it turns on).
func set_festering(index: int, on: bool) -> void:
	if index >= 0 and index < wounds.size():
		wounds[index]["festering"] = on


# Index of the wound to treat first: most blood, then festering, then an unsplinted fracture
# (body_injury 4.6 'most urgent preselected'). -1 when nothing needs care.
func most_urgent() -> int:
	var best: int = -1
	var best_key: float = 0.0
	for i in wounds.size():
		var k: float = _order_key(i)
		if k > best_key:
			best = i
			best_key = k
	return best


func has_fracture(group: String) -> bool:
	for w: Dictionary in wounds:
		if w["kind"] == "fracture" and _in_group(String(w["part"]), group):
			return true
	return false


# Fractures exist in the group ("arm", "leg", "" for any) and all carry a splint.
func fractures_splinted(group: String) -> bool:
	var found := false
	for w: Dictionary in wounds:
		if w["kind"] == "fracture" and _in_group(String(w["part"]), group):
			found = true
			if not w["splinted"]:
				return false
	return found


# Total blood flow of all wounds.
func blood_total() -> float:
	var sum := 0.0
	for w: Dictionary in wounds:
		sum += float(w["blood"])
	return sum


func bleed_level() -> int:
	var sum: float = blood_total()
	if sum >= HEAVY_BLOOD:
		return 2
	return 1 if sum > 0.0 else 0


# The wounds as receipt rows (no person): {part, kind} plus festering when true.
func receipt_wounds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Dictionary in wounds:
		var row := {"part": w["part"], "kind": w["kind"]}
		if w["festering"]:
			row["festering"] = true
		out.append(row)
	return out


# True when the wound list alone makes this person an injured one on the train
# (deep, embedded, fracture; body_injury 4.6 'when back on the train').
func has_serious_wound() -> bool:
	for w: Dictionary in wounds:
		if w["kind"] in ["deep", "embedded", "fracture"]:
			return true
	return false


func has_bite_wound() -> bool:
	for w: Dictionary in wounds:
		if w["kind"] == "bite":
			return true
	return false


## "arm_left" -> "arm", "leg_right" -> "leg", others as they are.
static func coarse(part: String) -> String:
	if part.begins_with("arm_"):
		return "arm"
	if part.begins_with("leg_"):
		return "leg"
	return part


## A part of the group ("arm" or "leg") with a random side; other names come back as they are.
static func pick_side(rng: RandomNumberGenerator, group: String) -> String:
	if group != "arm" and group != "leg":
		return group
	return group + ("_left" if rng.randf() < 0.5 else "_right")


## Starting spread for where a hit lands: any of the six parts, equal share (start value).
static func pick_part(rng: RandomNumberGenerator) -> String:
	return PARTS[rng.randi() % PARTS.size()]


## Zombie hands reach the arms and the torso (body_injury 4.6 'coat covers arms and torso').
static func pick_scratch_part(rng: RandomNumberGenerator) -> String:
	return ["torso", "arm_left", "arm_right"][rng.randi() % 3]


# A broken limb on the given part, or on the side without a fracture yet.
func fracture(arm: bool, part: String = "", now: float = 0.0) -> void:
	add_wound(part if part != "" else _free_side("arm" if arm else "leg"), "fracture", now)


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
	var level: int = bleed_level()
	if level == 1:
		if not running:
			light_bleed_time += delta
			if light_bleed_time >= LIGHT_BLEED_STOP:
				for w: Dictionary in wounds:
					w["blood"] = 0.0
				_refresh()
				events.append("bleed_stopped")
	elif level >= 2:
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
		_mul(m, "move", 0.6 if fractures_splinted("leg") else MOVE_FLOOR)
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
		rest.append({"id": "fracture", "severe": leg_fracture and not fractures_splinted("leg")})
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
		return "느림" if fractures_splinted("leg") else "못 걸음"
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


# Keeps the bleed timers right after the wound list changed.
func _refresh() -> void:
	var level: int = bleed_level()
	if _level_seen >= 2 and level < 2:
		heavy_bleed_time = 0.0
		down_time = 0.0
		downed = false
	if level == 0:
		light_bleed_time = 0.0
	_level_seen = level


# Old direct writes to bleed: a missing level adds a wound, a lower one thins the flow.
func _force_bleed(level: int) -> void:
	var cur: int = bleed_level()
	if level == cur:
		return
	if level <= 0:
		for w: Dictionary in wounds:
			w["blood"] = 0.0
	elif level > cur:
		add_wound("torso", "deep" if level >= 2 else "laceration", 0.0)
	else:
		var f: float = 0.9 * HEAVY_BLOOD / blood_total()
		for w: Dictionary in wounds:
			w["blood"] = float(w["blood"]) * f
	_refresh()


func _set_fracture(group: String, on: bool) -> void:
	if on:
		if not has_fracture(group):
			fracture(group == "arm")
		return
	for i in range(wounds.size() - 1, -1, -1):
		if wounds[i]["kind"] == "fracture" and _in_group(String(wounds[i]["part"]), group):
			wounds.remove_at(i)


static func _in_group(part: String, group: String) -> bool:
	return group == "" or part.begins_with(group + "_")


func _has_fracture_on(part: String) -> bool:
	for w: Dictionary in wounds:
		if w["kind"] == "fracture" and w["part"] == part:
			return true
	return false


# Coarse names ("arm", "leg", "head") become a part; the side with fewer wounds of that kind
# wins, left on a tie. Part names pass through, unknown ones fall back to the torso.
func _fine_part(part: String, kind: String) -> String:
	if PARTS.has(part):
		return part
	match part:
		"arm", "leg":
			return _light_side(part, kind)
		"head", "neck":
			return "head_neck"
	return "torso"


func _light_side(group: String, kind: String) -> String:
	var left := 0
	var right := 0
	for w: Dictionary in wounds:
		if String(w["kind"]) != kind and not (kind == "cut" and w["kind"] in ["laceration", "deep"]):
			continue
		if w["part"] == group + "_left":
			left += 1
		elif w["part"] == group + "_right":
			right += 1
	return group + ("_left" if left <= right else "_right")


func _free_side(group: String) -> String:
	return _light_side(group, "fracture")


func _top_bleeder() -> int:
	var best := -1
	var best_blood := 0.0
	for i in wounds.size():
		var blood: float = wounds[i]["blood"]
		if blood > best_blood:
			best = i
			best_blood = blood
	return best


func _top_fracture() -> int:
	var best := -1
	var best_key := 0.0
	for i in wounds.size():
		var w: Dictionary = wounds[i]
		if w["kind"] == "fracture" and not w["splinted"]:
			var k: float = 1.5 if String(w["part"]).begins_with("leg_") else 1.0
			if k > best_key:
				best = i
				best_key = k
	return best


# Urgency of a wound: blood first, then festering, then an unsplinted fracture (legs first).
func _order_key(i: int) -> float:
	var w: Dictionary = wounds[i]
	if float(w["blood"]) > 0.0:
		return 3.0 + float(w["blood"])
	if w["festering"]:
		return 2.0
	if w["kind"] == "fracture" and not w["splinted"]:
		return 1.5 if String(w["part"]).begins_with("leg_") else 1.0
	return 0.0


static func _soft(f: float, halve: bool) -> float:
	return 1.0 - (1.0 - f) * 0.5 if halve else f


static func _mul(m: Dictionary, key: String, f: float) -> void:
	m[key] = float(m[key]) * f
