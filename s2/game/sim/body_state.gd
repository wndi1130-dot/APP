extends RefCounted
# One person's body in the field (body_injury 4, 4.2, 4.5, 4.6). Times are field seconds.
# The wound list is the source of truth; bleed, arm_fracture, leg_fracture, splinted and
# bite_part are read from it (the first four also accept writes, kept for old callers and tests).

const InjuryRules = preload("res://game/sim/injury_rules.gd")
const Stamina = preload("res://game/sim/stamina.gd")

const WINDOW := 480.0
const SCRATCH_INFECT := 0.10
const LIGHT_BLEED_STOP := 240.0
const HEAVY_DOWN := 120.0
const DOWN_DEATH := 60.0
const QUICK_TREAT := 120.0       # medic within 2 min eases one step (body_injury 4)
const GUNSHOT_LEG := 0.25

# Wound model (body_injury 4.6). Names match s1/schema/receipt.schema.json $defs.wound.
const PARTS := ["head_neck", "torso", "arm_left", "arm_right", "leg_left", "leg_right"]
# The parts in the words of the state notes (as treatment.gd PART_NAMES).
const PART_WORDS := {"head_neck": "머리·목", "torso": "몸통", "arm_left": "왼팔", "arm_right": "오른팔", "leg_left": "왼다리", "leg_right": "오른다리"}
const KINDS := ["scratch", "laceration", "deep", "embedded", "bite", "fracture"]
# Starting blood flow per kind (start values). Heavy bleeding is a total of 1.0 or more.
const BLOOD := {"scratch": 0.15, "laceration": 0.4, "deep": 1.0, "embedded": 1.0, "bite": 0.4, "fracture": 0.0}
const HEAVY_BLOOD := 1.0
## Festering (body_injury 4.6 stage 2; start values, to be set on the phone).
const FESTER_IN_FIELD := true    # false: nothing festers on the field, only the train decides
const FESTER_TIME := 360.0       # seconds a dirty wound is left before it turns
# A deep wound is not among them: its care has no cleaning (tourniquet,
# stitches, bandage) and left alone it bleeds on (body_injury 4.6 table).
# Its dressing still festers once dirty.
const FESTER_KINDS := ["scratch", "laceration", "embedded"]
const FESTER_MULT := 0.9
const BAREFOOT_MOVE := 0.9      # walking with no shoes on (clothing.md 5장, new value)
const SEEP_BLOOD := 0.4          # a heavy wound with a plain bandage seeps on as a light one

const RUN_FATIGUE := Stamina.RUN_FATIGUE
const OVERLOAD_FATIGUE := Stamina.OVERLOAD_FATIGUE
const COLD_FATIGUE := Stamina.COLD_FATIGUE
const REST_RECOVER := Stamina.REST_RECOVER
const BREATH_RUN := Stamina.BREATH_RUN
const BREATH_REST := Stamina.BREATH_REST
const RUN_BREATH_MIN := Stamina.RUN_BREATH_MIN

const FLOOR := 0.5
const MOVE_FLOOR := 0.25
const AIM_UP := 1.4
const AIM_MAX := 3.0
const MELEE_HIT_FLOOR: float = 0.15
const MELEE_HIT_NEED: Array[float] = [1.0, 0.85, 0.65]

# One entry per wound: {part, kind, blood, disinfected, bandaged, splinted, festering, at}
# and, from stage 2, {tourniquet, pulled, sutured, what, open_t}.
# blood is the flow now (0 once stopped). what: "bullet" for a round that stayed in.
# open_t: seconds the wound has been left dirty (it festers at FESTER_TIME).
# For the cut (body_injury 2.2): risk (the bite or scratch opened the window
# now running), infects (a bite always; a scratch when its roll came up),
# stump (what is left where a limb was cut off).
var wounds: Array[Dictionary] = []
var infection: String = ""       # "" | "scratch" | "bite"
var infected: bool = false       # hidden for scratches
var window_left: float = 0.0
var lost: Array[String] = []     # the arms and legs cut off (amputate)
var exhaustion: float = 0.0
var breath: float = 1.0
var downed: bool = false
var dead: bool = false
var heavy_bleed_time: float = 0.0
var light_bleed_time: float = 0.0
var last_bandages_used: int = 0  # what the last bandage() call really used (callers take only that)
var down_time: float = 0.0       # time spent downed while bleeding heavily
var injured_at: float = -INF
var cold_level: int = 0          # last cold_level seen by tick(), for icons
var _heavy_reported: bool = false
var _level_seen: int = 0         # bleed level at the last change, to reset timers on a drop
var breath_locked: bool = false

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
	# Nothing lands where a limb was cut off: the other side, else the torso.
	if lost.has(part):
		part = _whole(part)
		if part == "":
			if kind == "fracture":
				return -1
			part = "torso"
	# Repeated trauma keeps the fourth matching record's identity for callers.
	# At most 6 regions * 6 kinds * 4 rows take part in a body's tick.
	var same := 0
	for i in wounds.size():
		var old: Dictionary = wounds[i]
		if old["part"] != part or old["kind"] != kind:
			continue
		same += 1
		if same < InjuryRules.MAX_SAME_WOUNDS:
			continue
		old["hits"] = int(old.get("hits", 1)) + 1
		old["blood"] = float(old["blood"]) + (float(BLOOD[kind]) if blood < 0.0 else blood)
		for flag in ["disinfected", "bandaged", "splinted", "tourniquet", "pulled", "sutured", "bandage_dirty"]:
			old[flag] = false
		old["bandage_t"] = 0.0
		_refresh()
		if bleed_level() == 1:
			light_bleed_time = 0.0
		return i
	wounds.append({
		"part": part, "kind": kind,
		"blood": float(BLOOD[kind]) if blood < 0.0 else blood,
		"disinfected": false, "bandaged": false, "splinted": false, "festering": false,
		"tourniquet": false, "pulled": false, "sutured": false, "what": "", "open_t": 0.0,
		"at": now, "hits": 1, "bandage_t": 0.0, "bandage_dirty": false,
	})
	_refresh()
	if wounds[-1]["blood"] > 0.0 and bleed_level() == 1:
		light_bleed_time = 0.0
	return wounds.size() - 1


func apply_bite(_rng: RandomNumberGenerator, part: String, now: float) -> void:
	# Already infected: the window runs on (a closed one stays closed); a new bite never resets it.
	var was_infected: bool = infected
	var i: int = add_wound(_fine_part(part, "bite"), "bite", now)
	if i >= 0:
		wounds[i]["risk"] = true
		wounds[i]["infects"] = true
	injured_at = now
	infection = "bite"
	window_left = minf(window_left, WINDOW) if was_infected else WINDOW
	infected = true


func apply_scratch(rng: RandomNumberGenerator, now: float, part: String = "torso") -> void:
	var i: int = add_wound(_fine_part(part, "scratch"), "scratch", now)
	injured_at = now
	var roll: bool = rng.randf() < SCRATCH_INFECT
	if i >= 0:
		wounds[i]["risk"] = true
		wounds[i]["infects"] = bool(wounds[i].get("infects", false)) or roll
	var was_infected: bool = infected
	if infection != "bite":
		infection = "scratch"
	infected = infected or roll
	if was_infected:
		window_left = minf(window_left, WINDOW)
	else:
		window_left = minf(window_left, WINDOW) if window_left > 0.0 else WINDOW


# A light cut tears (laceration), a heavy one goes deep.
func apply_cut(heavy: bool, now: float, part: String = "torso") -> void:
	add_wound(_fine_part(part, "cut"), "deep" if heavy else "laceration", now)
	injured_at = now


# Heavy bleed (a bullet stays in); 25% hits a leg and breaks it. Already bleeding heavily: downed.
# Returns the coarse place ("head", "torso" or "leg"). The side comes from the same roll.
# zone "head" (the aim roll hit the head) puts the round there, not on a rolled part.
func apply_gunshot(rng: RandomNumberGenerator, now: float, zone: String = "") -> String:
	return gunshot_at(gunshot_part(rng, zone), now)


## Where a round lands, on the one roll it always drew: the fine part (a vest
## may stop it there first, field_combat.gd).
func gunshot_part(rng: RandomNumberGenerator, zone: String = "") -> String:
	var roll: float = rng.randf()
	if zone == "head":
		return "head_neck"
	if roll < GUNSHOT_LEG:
		return "leg_left" if roll < GUNSHOT_LEG * 0.5 else "leg_right"
	return "torso"


## The round in `fine` (gunshot_part); returns the coarse place.
func gunshot_at(fine: String, now: float) -> String:
	var was_heavy: bool = bleed_level() >= 2
	var part: String = "head" if fine == "head_neck" else ("torso" if fine == "torso" else "leg")
	wounds[add_wound(fine, "embedded", now)]["what"] = "bullet"
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
	last_bandages_used = 0
	var budget: int = count
	var start: int = bleed_level()
	var done := false
	while budget > 0:
		var i: int = _top_bleeder()
		if i < 0:
			break
		var heavy: bool = float(wounds[i]["blood"]) >= HEAVY_BLOOD
		var cost: int = 2 if heavy and not InjuryRules.dirty(wounds[i]) else 1
		if cost > budget:
			break
		bandage_wound(i)
		budget -= cost
		last_bandages_used += cost
		done = true
		_refresh()
		if start >= 2 and bleed_level() < 2:
			break
	return done


# Dresses one chosen wound (the body picture, body_injury 4.6). Same rule as bandage():
# a heavy wound takes two and seeps on as a light one, any other takes one and stops.
# Returns the bandages used (0: nothing to dress there).
func bandage_wound(index: int) -> int:
	if index < 0 or index >= wounds.size():
		return 0
	var w: Dictionary = wounds[index]
	if w["kind"] == "fracture" or (bool(w["bandaged"]) and not InjuryRules.dirty(w)):
		return 0
	var replacement := InjuryRules.dirty(w)
	var heavy: bool = float(w["blood"]) >= HEAVY_BLOOD
	w["blood"] = SEEP_BLOOD if heavy or InjuryRules.needs_closure(w) else 0.0
	w["bandaged"] = true
	w["bandage_t"] = 0.0
	w["bandage_dirty"] = false
	_refresh()
	return 2 if heavy and not replacement else 1


# Splints one chosen fracture. False when that wound is not an unsplinted fracture.
func splint_wound(index: int) -> bool:
	if index < 0 or index >= wounds.size():
		return false
	var w: Dictionary = wounds[index]
	if w["kind"] != "fracture" or bool(w["splinted"]):
		return false
	w["splinted"] = true
	return true


# A tourniquet on a limb (stage 2): a heavy flow drops to a seep at once. It does
# not close the wound. False when there is nothing for it to do there.
func tourniquet_wound(index: int) -> bool:
	if index < 0 or index >= wounds.size():
		return false
	var w: Dictionary = wounds[index]
	if bool(w["tourniquet"]) or w["kind"] == "fracture" or coarse(String(w["part"])) not in ["arm", "leg"]:
		return false
	w["tourniquet"] = true
	w["blood"] = minf(float(w["blood"]), SEEP_BLOOD)
	_refresh()
	return true


# Takes out what is stuck in an embedded wound (stage 2). Until then it cannot be cleaned.
func pull_wound(index: int) -> bool:
	if index < 0 or index >= wounds.size():
		return false
	var w: Dictionary = wounds[index]
	if w["kind"] != "embedded" or bool(w["pulled"]):
		return false
	w["pulled"] = true
	return true


# Stitches a wound shut (stage 2): the blood stops for good, no seeping on.
func suture_wound(index: int) -> bool:
	if index < 0 or index >= wounds.size():
		return false
	var w: Dictionary = wounds[index]
	if bool(w["sutured"]) or w["kind"] not in ["deep", "embedded"]:
		return false
	if w["kind"] == "embedded" and not bool(w["pulled"]):
		return false
	w["sutured"] = true
	w["blood"] = 0.0
	_refresh()
	return true


# Will this wound fester if left as it is (stage 2)? A torn wound not cleaned, or
# anything still stuck in. Never the plague: this is 'festering' and nothing else.
func festers(w: Dictionary) -> bool:
	if bool(w["festering"]) or w["kind"] == "fracture":
		return false
	if InjuryRules.dirty(w):
		return true
	if String(w["kind"]) not in FESTER_KINDS:
		return false
	# A scratch is cared for by a bandage alone (body_injury 4.6 table: 붕대만도 됨);
	# left bare it can fester.
	if w["kind"] == "scratch" and bool(w["bandaged"]):
		return false
	if w["kind"] == "embedded" and not bool(w["pulled"]):
		return true
	return not bool(w["disinfected"])


func festering_on(group: String) -> bool:
	for w: Dictionary in wounds:
		if bool(w["festering"]) and _in_group(String(w["part"]), group):
			return true
	return false


func has_festering() -> bool:
	for w: Dictionary in wounds:
		if bool(w["festering"]):
			return true
	return false


# Where a wound sits in the list now (-1 when it is gone). By identity, not by value:
# two wounds can read the same.
func index_of(wound: Dictionary) -> int:
	for i in wounds.size():
		if is_same(wounds[i], wound):
			return i
	return -1


# A medkit stops the blood of every wound at once.
func use_kit() -> bool:
	if bleed_level() == 0:
		return false
	for w: Dictionary in wounds:
		if float(w["blood"]) > 0.0:
			w["blood"] = 0.0
			w["bandaged"] = true
			w["bandage_t"] = 0.0
			w["bandage_dirty"] = false
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
	if wounds[index]["disinfected"] or (wounds[index]["kind"] == "embedded" and not bool(wounds[index].get("pulled", false))):
		return false
	wounds[index]["disinfected"] = true
	wounds[index]["open_t"] = 0.0
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


## A deep wound on a leg: no running (body_injury 4.6 '깊은 상처는 달리기 못 함').
func has_deep_leg_wound() -> bool:
	for w: Dictionary in wounds:
		if w["kind"] == "deep" and _in_group(String(w["part"]), "leg"):
			return true
	return false


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
		# What was done for it (receipt v5 treat): the train reads it instead of drawing anew (J02).
		var treat := {}
		for flag: String in ["bandaged", "disinfected", "sutured", "splinted", "tourniquet", "pulled", "quick"]:
			if bool(w.get(flag, false)):
				treat[flag] = true
		if not treat.is_empty():
			row["treat"] = treat
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


## Does a bite or a scratch on this part carry the window now running?
func at_risk_on(part: String) -> bool:
	for w: Dictionary in wounds:
		if w["part"] == part and bool(w.get("risk", false)):
			return true
	return false


## The arms and legs a bite of the window now running sits on.
func bitten_limbs() -> Array[String]:
	var out: Array[String] = []
	for w: Dictionary in wounds:
		var part: String = String(w["part"])
		if w["kind"] == "bite" and bool(w.get("risk", false)) and coarse(part) in ["arm", "leg"] and not out.has(part):
			out.append(part)
	return out


## The limbs to cut to stop the window now running, when every bite and
## scratch of it sits on one; none when one sits where no cut reaches.
func cut_parts() -> Array[String]:
	var out: Array[String] = []
	for w: Dictionary in wounds:
		if not bool(w.get("risk", false)):
			continue
		var part: String = String(w["part"])
		if coarse(part) not in ["arm", "leg"]:
			out.clear()
			return out
		if not out.has(part):
			out.append(part)
	return out


## Where a bite of the window now running sits that no cut takes off (the
## torso, the head or the neck, 결정 441); "" when there is none.
func uncut_bite() -> String:
	for w: Dictionary in wounds:
		if w["kind"] == "bite" and bool(w.get("risk", false)) and coarse(String(w["part"])) not in ["arm", "leg"]:
			return String(w["part"])
	return ""


## Cuts off an arm or a leg (body_injury 2.2): every wound on it goes with it,
## a stump is left (stump_kind, under the tourniquet it was cut with) and the
## body is spent, whoever it is. Inside the window whatever came in through
## that limb is gone; it is not a chance (decisions.md 「절단은 확률이 아니다」).
## A risk left elsewhere runs on in the window, not knowing. Once the window
## has closed it is too late: the limb is lost for nothing. Returns true when
## no infection is left after it.
func amputate(part: String, stump_kind: String, now: float) -> bool:
	if lost.has(part) or coarse(part) not in ["arm", "leg"]:
		return not infected
	var in_time: bool = window_left > 0.0
	for i in range(wounds.size() - 1, -1, -1):
		if wounds[i]["part"] == part:
			wounds.remove_at(i)
	var s: int = add_wound(part, stump_kind, now, minf(float(BLOOD.get(stump_kind, SEEP_BLOOD)), SEEP_BLOOD))
	if s >= 0:
		wounds[s]["stump"] = true
		wounds[s]["tourniquet"] = true
	lost.append(part)
	injured_at = now
	exhaustion = maxf(exhaustion, Stamina.FATIGUE_HEAVY)
	if in_time:
		_recount_infection()
	return not infected


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
	return Stamina.fatigue_mult(ctx)


func pain() -> float:
	var total := 0.0
	for w: Dictionary in wounds:
		total += InjuryRules.pain(w)
	return minf(1.0, total)


func torso_effort() -> float:
	var load := 0.0
	for w: Dictionary in wounds:
		if w["part"] == "torso":
			load = maxf(load, InjuryRules.pain(w))
	return 1.0 + load


func exert_climb(seconds: float, ctx: Dictionary = {}) -> void:
	var effort := ctx.duplicate()
	effort["torso_effort"] = torso_effort()
	var cost := Stamina.climb_cost(seconds, effort)
	add_fatigue(cost.x)
	breath = maxf(0.0, breath - cost.y)
	_update_breath_lock()


func _update_breath_lock() -> void:
	if breath <= RUN_BREATH_MIN:
		breath_locked = true
	elif breath >= Stamina.RUN_BREATH_RESUME:
		breath_locked = false


# ctx: running, swinging, carry_state, cold_level, indoor_rest. Returns event names.
func tick(delta: float, ctx: Dictionary) -> Array:
	var events: Array = []
	if dead or delta <= 0.0:
		return events
	var running: bool = bool(ctx.get("running", false))
	cold_level = int(ctx.get("cold_level", 0))

	# Bleeding
	var level: int = bleed_level()
	if level == 1:
		if not running:
			light_bleed_time += delta
			if light_bleed_time >= LIGHT_BLEED_STOP:
				for w: Dictionary in wounds:
					if not InjuryRules.needs_closure(w):
						w["blood"] = 0.0
				_refresh()
				if bleed_level() == 0:
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

	# Count only the part of a tick spent dirty, including a large time step.
	if FESTER_IN_FIELD:
		for w: Dictionary in wounds:
			var was_at_risk := festers(w)
			var exposed := delta
			if bool(w["bandaged"]) and not InjuryRules.dirty(w) and not bool(w.get("sutured", false)):
				var old_t := float(w.get("bandage_t", 0.0))
				var life := InjuryRules.bandage_life(w)
				w["bandage_t"] = old_t + delta
				if float(w["bandage_t"]) >= life:
					w["bandage_dirty"] = true
					events.append("bandage_dirty")
					if not was_at_risk:
						exposed = maxf(0.0, old_t + delta - life)
			if festers(w):
				w["open_t"] = float(w.get("open_t", 0.0)) + exposed
				if float(w["open_t"]) >= FESTER_TIME:
					w["festering"] = true
					events.append("festering")

	# Infection window
	if infection != "" and window_left > 0.0:
		window_left = maxf(0.0, window_left - delta)
		if window_left <= 0.0:
			events.append("window_closed")
			if not infected:
				infection = ""
				# Clean after all: nothing left there to cut for.
				for w: Dictionary in wounds:
					w.erase("risk")

	# Exhaustion
	_update_breath_lock()
	var effort := ctx.duplicate()
	effort["torso_effort"] = torso_effort()
	var stamina := Stamina.advance(exhaustion, breath, delta, effort)
	exhaustion = stamina.x
	breath = stamina.y
	_update_breath_lock()
	if exhaustion_level() == 2:
		if not _heavy_reported:
			_heavy_reported = true
			events.append("exhausted_heavy")
	else:
		_heavy_reported = false

	return events


func exhaustion_level() -> int:
	if exhaustion >= Stamina.FATIGUE_HEAVY:
		return 2
	if exhaustion >= Stamina.FATIGUE_LIGHT:
		return 1
	return 0


func can_run() -> bool:
	return not leg_fracture and not lost_limb("leg") and not has_deep_leg_wound() and exhaustion_level() < 2 and breath > RUN_BREATH_MIN and not breath_locked and not downed and not dead


## An arm ("arm") or a leg ("leg") cut off.
func lost_limb(group: String) -> bool:
	for part: String in lost:
		if _in_group(part, group):
			return true
	return false


# body_injury 4.2. Speed factors (time = base / factor) except aim_min (circle floor size, bigger is worse).
# ctx: carry_state 0..3, cold_level 0..3, gloves, heavy_coat, barefoot, panic, strength.
## How well a blow lands (body_injury 4.2, decisions 2026-10-11 '근접 타수'):
## the one action that may fall below half. It scales the chance to hit the
## head and to knock down (weapons.melee_odds), so a spent, bleeding, frozen
## hand needs many blows where a fresh one needs two.
## Hunger and sore muscles come from the train (the departure contract, person.gd
## hunger_level and sore_level). ctx["hunger_level"], ctx["sore_level"]: 0 none, 1 some, 2 bad.


func multipliers(ctx: Dictionary) -> Dictionary:
	var carry: int = int(ctx.get("carry_state", 0))
	var cold: int = int(ctx.get("cold_level", 0))
	var strong: bool = int(ctx.get("strength", 5)) >= 7
	var m: Dictionary = {
		"move": 1.0, "swing": 1.0, "aim_min": 1.0, "reload": 1.0,
		"swap": 1.0, "hands": 1.0, "shove_window": 1.0, "aim_shrink": 1.0,
		"melee_hit": 1.0,
	}
	var arm_hurt := 0.0
	var leg_hurt := 0.0
	var head_bleeding := false
	# A limb cut off is a broken one for good: its row below, not its stump's hurt.
	var lost_arm: bool = lost_limb("arm")
	var lost_leg: bool = lost_limb("leg")
	for w: Dictionary in wounds:
		if w["kind"] == "fracture" or lost.has(String(w["part"])):
			continue
		if _in_group(String(w["part"]), "arm"):
			arm_hurt = maxf(arm_hurt, InjuryRules.severity(w))
		elif _in_group(String(w["part"]), "leg"):
			leg_hurt = maxf(leg_hurt, InjuryRules.severity(w))
		elif w["part"] == "head_neck" and float(w["blood"]) > 0.0 and not bool(w["bandaged"]):
			head_bleeding = true
	if not arm_fracture and not lost_arm and arm_hurt > 0.0:
		_mul(m, "aim_min", lerpf(1.0, InjuryRules.HEAD_AIM_MULT, arm_hurt))
		_mul(m, "reload", lerpf(1.0, InjuryRules.ARM_RELOAD_MULT, arm_hurt))
		_mul(m, "swap", lerpf(1.0, InjuryRules.ARM_SWAP_MULT, arm_hurt))
		_mul(m, "hands", lerpf(1.0, InjuryRules.ARM_HANDS_MULT, arm_hurt))
		_mul(m, "shove_window", lerpf(1.0, InjuryRules.ARM_SHOVE_MULT, arm_hurt))
	if not leg_fracture and not lost_leg and leg_hurt > 0.0:
		_mul(m, "move", lerpf(1.0, InjuryRules.LEG_MOVE_MULT, leg_hurt))
	if head_bleeding:
		_mul(m, "aim_min", InjuryRules.HEAD_AIM_MULT)
	var pain_mult := lerpf(1.0, InjuryRules.PAIN_ACTION_FLOOR, pain())
	_mul(m, "hands", pain_mult)
	_mul(m, "aim_shrink", pain_mult)
	# Bag (strength 7+ halves these)
	if carry == 1:
		_mul(m, "move", _soft(0.9, strong))
	elif carry >= 2:
		_mul(m, "move", _soft(0.7, strong))
		_mul(m, "swing", _soft(0.85, strong))
		_mul(m, "shove_window", _soft(0.8, strong))
		_mul(m, "melee_hit", _soft(0.8, strong))
	# Exhaustion (strength 7+ halves these)
	var ex: int = exhaustion_level()
	if ex == 1:
		_mul(m, "swing", _soft(0.9, strong))
		_mul(m, "hands", _soft(0.9, strong))
		_mul(m, "aim_shrink", _soft(0.7, strong))
		_mul(m, "melee_hit", _soft(0.7, strong))
	elif ex == 2:
		_mul(m, "swing", _soft(0.75, strong))
		_mul(m, "hands", _soft(0.75, strong))
		_mul(m, "melee_hit", _soft(0.4, strong))
		_mul(m, "shove_window", _soft(0.8, strong))
		_mul(m, "aim_shrink", _soft(0.5, strong))
		m["aim_min"] = float(m["aim_min"]) * (1.0 + (AIM_UP - 1.0) * (0.5 if strong else 1.0))
	# Heavy bleed
	if bleed >= 2:
		_mul(m, "move", 0.8)
		_mul(m, "swing", 0.85)
		_mul(m, "melee_hit", 0.6)
		_mul(m, "aim_min", AIM_UP)
	# Arm fracture, or an arm cut off (one hand, body_injury 2.2)
	if arm_fracture or lost_arm:
		_mul(m, "aim_min", AIM_UP)
		_mul(m, "reload", 0.6)
		_mul(m, "swap", 0.7)
		_mul(m, "hands", 0.5)
		_mul(m, "shove_window", 0.7)
	# Leg fracture: splinted limps, unsplinted crawls; a leg cut off crawls
	# (body_injury 2.2: it cannot walk; two carrying it is for later)
	if leg_fracture or lost_leg:
		_mul(m, "move", 0.6 if leg_fracture and not lost_leg and fractures_splinted("leg") else MOVE_FLOOR)
		_mul(m, "swing", 0.9)
		_mul(m, "melee_hit", 0.8)
		_mul(m, "shove_window", 0.7)
	# A festering wound hurts where it is: arm slows the hands, leg the walk, the rest the swing.
	if festering_on("arm"):
		_mul(m, "reload", FESTER_MULT)
		_mul(m, "swap", FESTER_MULT)
		_mul(m, "hands", FESTER_MULT)
	if festering_on("leg"):
		_mul(m, "move", FESTER_MULT)
	if festering_on("torso") or festering_on("head_neck"):
		_mul(m, "swing", FESTER_MULT)
		_mul(m, "melee_hit", 0.85)
	# Cold: 추움 row from level 1, hypothermia rows stack on top
	if cold >= 1:
		_mul(m, "move", 0.95)
		_mul(m, "swing", 0.95)
		_mul(m, "reload", 0.9)
		_mul(m, "hands", 0.9)
		_mul(m, "melee_hit", 0.8 if cold == 1 else 0.64)
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
		_mul(m, "melee_hit", 0.9)
	# No shoes on the snow (clothing.md 5장, new value).
	if bool(ctx.get("barefoot", false)):
		_mul(m, "move", BAREFOOT_MOVE)
	if bool(ctx.get("panic", false)):
		_mul(m, "aim_min", AIM_UP)
		_mul(m, "reload", 0.8)
		_mul(m, "swap", 0.8)
		_mul(m, "hands", 0.6)
	_mul(m, "melee_hit", MELEE_HIT_NEED[clampi(int(ctx.get("hunger_level", 0)), 0, 2)])
	_mul(m, "melee_hit", MELEE_HIT_NEED[clampi(int(ctx.get("sore_level", 0)), 0, 2)])
	m["melee_hit"] = maxf(MELEE_HIT_FLOOR, float(m["melee_hit"]))
	# Floors and caps
	for k: String in ["swing", "reload", "swap", "hands", "shove_window", "aim_shrink"]:
		m[k] = maxf(FLOOR, float(m[k]))
	m["move"] = maxf(MOVE_FLOOR, float(m["move"]))
	m["aim_min"] = minf(AIM_MAX, float(m["aim_min"]))
	if carry >= 3:
		m["move"] = 0.0
	m["one_hand"] = arm_fracture or lost_arm or arm_hurt >= 1.0
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
	if not lost.is_empty():
		rest.append({"id": "lost", "severe": lost_limb("leg")})
	if has_festering():
		rest.append({"id": "fester", "severe": false})
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


# The icons with their words: press one for its effects. Same order as icons().
# Each row: id, short (the two
# letters on the icon), title (a noun phrase), good (a help or a harm), severe, text.
func status_notes() -> Array:
	var out: Array = []
	for icon: Dictionary in icons():
		var severe: bool = bool(icon["severe"])
		var row := {"id": icon["id"], "short": "", "title": "", "good": false, "severe": severe, "faint": bool(icon.get("faint", false)), "text": ""}
		match String(icon["id"]):
			"infection":
				row["short"] = "감염"
				# What to cut to stop it (body_injury 2.2). A bite no cut reaches
				# says why and how long until the fever, with nothing to decide
				# (결정 441 (4)): 「정해야 한다」 is for an arm or a leg.
				var time: String = window_words()
				var core: String = uncut_bite()
				var off: String = _off_limb_risk()
				if infection == "bite":
					row["title"] = "물린 상처"
					var limbs: Array[String] = bitten_limbs()
					if window_left <= 0.0:
						row["text"] = "감염 창이 닫혔다"
					elif core != "":
						row["text"] = "%s 자를 수 없다. 열이 오르기까지 %s" % [_ira(PART_WORDS[core]), time]
					elif limbs.is_empty():
						row["text"] = "감염 창이 %s 남았다. 닫히기 전에 정해야 한다" % time
					else:
						row["text"] = "감염 창이 %s 남았다. 닫히기 전에 정해야 한다: %s 자르면 막는다" % [time, _eul(_words(limbs))]
						if off != "":
							row["text"] += ". %s 긁힘은 자를 수 없다" % PART_WORDS[off]
				else:
					row["title"] = "긁힌 상처"
					if window_left > 0.0 and off != "":
						row["text"] = "감염됐는지 아직 모른다. %s 자를 수 없다. %s 뒤 창이 끝나면 안다" % [_ira(PART_WORDS[off]), time]
					else:
						row["text"] = "감염됐는지 아직 모른다. 창이 끝나야 안다"
						var cut: Array[String] = cut_parts()
						if not cut.is_empty() and window_left > 0.0:
							row["text"] += ". %s 자르면 감염이어도 막는다" % _eul(_words(cut))
			"bleed":
				row["short"] = "출혈"
				if severe:
					row["title"] = "심한 출혈"
					row["text"] = "걸음과 휘두르기가 느리고 조준이 흔들린다. 2분쯤 뒤 쓰러진다. 피 냄새가 퍼진다"
				else:
					row["title"] = "가벼운 출혈"
					row["text"] = "뛰지 않으면 4분쯤 뒤 저절로 멎는다. 피 냄새가 퍼진다"
			"fracture":
				row["short"] = "골절"
				if leg_fracture:
					var splint_on: bool = fractures_splinted("leg")
					row["title"] = "부목 댄 다리 골절" if splint_on else "다리 골절"
					row["text"] = "절뚝이며 걷는다. 뛰지 못한다" if splint_on else "기어간다. 뛰지 못한다. 부목을 대면 절뚝이며 걷는다"
				else:
					row["title"] = "팔 골절"
					row["text"] = "양손 무기를 못 쓴다. 재장전과 손일이 느리고 조준이 흔들린다"
			"lost":
				row["short"] = "잘림"
				var words: Array = []
				for part: String in lost:
					words.append(PART_WORDS[part])
				row["title"] = "잘린 " + "·".join(words)
				var says: Array = []
				if lost_limb("arm"):
					says.append("한 손 무기만 쓴다(양손 총과 활은 못 쓴다). 재장전과 손일이 느리다")
				if lost_limb("leg"):
					says.append("기어간다. 뛰지 못한다")
				row["text"] = ". ".join(says)
			"fester":
				row["short"] = "곪음"
				row["title"] = "곪은 상처"
				row["text"] = "그 자리가 아프다. 팔이면 손일과 재장전이, 다리면 걸음이, 몸통이면 휘두르기가 느리다. 열차에서 약이 더 든다"
			"cold":
				row["short"] = "추움"
				row["title"] = "추위"
				row["text"] = "걷기와 휘두르기가 조금 느리고 재장전과 손일이 느리다. 불 곁이나 실내에서 풀린다"
			"exhaustion":
				row["short"] = "지침"
				row["title"] = "심한 탈진" if severe else "탈진"
				row["text"] = "뛰지 못한다. 휘두르기가 느리고 조준이 흔들린다. 실내에서 쉬면 풀린다" if severe else "휘두르기와 손일이 느리고 조준이 천천히 줄어든다. 실내에서 쉬면 풀린다"
		out.append(row)
	return out


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
	if leg_fracture or lost_limb("leg"):
		return "느림" if leg_fracture and not lost_limb("leg") and fractures_splinted("leg") else "못 걸음"
	if arm_fracture or lost_limb("arm"):
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
		light_bleed_time = 0.0   # a dressed heavy wound seeps on for the full time
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
	return group == "" or part == group or part.begins_with(group + "_")


# The same limb on the other side, for one cut off; "" when that is gone too.
func _whole(part: String) -> String:
	var other: String = part.replace("_left", "_right") if part.ends_with("_left") else part.replace("_right", "_left")
	return "" if lost.has(other) else other


# After a cut inside the window: what still carries it. A bite always does
# (one from an old save has no flag); a scratch only as its roll came up.
func _recount_infection() -> void:
	var risk := false
	var bite := false
	infected = false
	for w: Dictionary in wounds:
		if not bool(w.get("risk", false)):
			continue
		risk = true
		bite = bite or w["kind"] == "bite"
		infected = infected or bool(w.get("infects", w["kind"] == "bite"))
	if not risk:
		infection = ""
		window_left = 0.0
	else:
		infection = "bite" if bite else "scratch"


# Parts in words, joined: ["arm_left", "leg_right"] → "왼팔·오른다리".
static func _words(parts: Array[String]) -> String:
	var words: Array = []
	for part: String in parts:
		words.append(PART_WORDS[part])
	return "·".join(words)


# The first part off the arms and legs a bite or scratch of the window sits on ("" none).
func _off_limb_risk() -> String:
	for w: Dictionary in wounds:
		if bool(w.get("risk", false)) and coarse(String(w["part"])) not in ["arm", "leg"]:
			return String(w["part"])
	return ""


# The window left in words: "7분 32초".
func window_words() -> String:
	return "%d분 %02d초" % [int(window_left) / 60, int(window_left) % 60]


static func _has_final(word: String) -> bool:
	var c: int = word.unicode_at(word.length() - 1)
	return c >= 0xAC00 and c <= 0xD7A3 and (c - 0xAC00) % 28 != 0


# A word with its object ending: 왼팔 → 왼팔을, 왼다리 → 왼다리를.
static func _eul(word: String) -> String:
	return word + ("을" if _has_final(word) else "를")


# A word with 이라/라: 몸통 → 몸통이라, 머리·목 → 머리·목이라.
static func _ira(word: String) -> String:
	return word + ("이라" if _has_final(word) else "라")


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
			left += int(w.get("hits", 1))
		elif w["part"] == group + "_right":
			right += int(w.get("hits", 1))
	return group + ("_left" if left <= right else "_right")


func _free_side(group: String) -> String:
	return _light_side(group, "fracture")


func _top_bleeder() -> int:
	var best := -1
	var best_blood := 0.0
	for i in wounds.size():
		if bool(wounds[i]["bandaged"]) and not InjuryRules.dirty(wounds[i]):
			continue
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
	if InjuryRules.dirty(w):
		return 2.0
	if w["kind"] == "fracture" and not w["splinted"]:
		return 1.5 if String(w["part"]).begins_with("leg_") else 1.0
	return 0.0


static func _soft(f: float, halve: bool) -> float:
	return 1.0 - (1.0 - f) * 0.5 if halve else f


static func _mul(m: Dictionary, key: String, f: float) -> void:
	m[key] = float(m[key]) * f
