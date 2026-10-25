extends RefCounted
## Read-only rules over one train state, ported from s1/src/game (the reference). A state is a
## Dictionary with S1's own key names (Game in state.ts); t is the tables block of a train-vectors
## file (tests/fixtures/train/train_vectors.json, written by s1/tools/train_port_fixtures.ts).
## Only the S1a game: the domestic, dark-path, climate, disaster and arrivals branches are off, so
## their hooks give 0 or 1 here exactly as they do in S1 when switched off. A dom holding the
## S2's explicitly ported stores/workshop/research subset (train_dom.gd) keeps
## unported S1c hooks off. Its research effects are wired by TrainResearch only.
## tests/train/test_train_state.gd checks every function against the S1 answers.

const CouncilMath = preload("res://game/politics/council_math.gd")
const TrainDom = preload("res://game/train/train_dom.gd")
const TrainHands = preload("res://game/train/train_hands.gd")


## S1a plus the allowed S2 domestic subset; unknown domestic keys still reject it.
static func is_s1a(g: Dictionary) -> bool:
	for key: String in ["dom", "dark", "climate", "disasters", "arrivals", "budget"]:
		var v: Variant = g.get(key)
		if v == null or (v is bool and not v):
			continue
		if key == "dom" and TrainDom.is_store(v):
			continue
		return false
	return true


## JS clamp in state.ts: max(lo, min(hi, value)).
static func clampv(value: float, lo: float, hi: float) -> float:
	return maxf(lo, minf(hi, value))


static func comms(t: Dictionary) -> Array:
	return t["COMMS"]


## situation(g, c) in state.ts: [warmth, ration, crowding, exposure], each 0..100. The space lever
## moves crowding from the tail to the giving car; domestic and arrival shares are 0 in S1a.
static func situation(g: Dictionary, t: Dictionary, c: String) -> Array[float]:
	var s: Dictionary = g["comms"][c]
	var p: Dictionary = t["P"]
	var base: Array = s["base"]
	var hands: Dictionary = g["hands"] if g.get("hands") is Dictionary else {}
	var short: Dictionary = hands.get("short", {})
	var expose: Dictionary = hands.get("expose", {})
	var h: Dictionary = t.get("HANDS", TrainHands.HANDS)
	var room := 0.0
	var sp: Variant = g.get("space")
	if sp is Dictionary and sp.get("giver") != null and float(sp.get("step", 0)) > 0:
		var side := -1.0 if c == "tail" else (1.0 if c == sp["giver"] else 0.0)
		room = side * float(p["spaceStep"]) * float(sp["step"])
	return [
		clampv(float(base[0]) + float(p["leverStep"]) * (float(s["heat"]) - 2.0) - float(h["stoveWarm"]) * float(short.get("stove", 0.0)), 0.0, 100.0),
		clampv(float(base[1]) + float(p["leverStep"]) * (float(s["ration"]) - 2.0), 0.0, 100.0),
		clampv(float(base[2]) + room, 0.0, 100.0),
		clampv(float(base[3]) + float(expose.get(c, 0.0)), 0.0, 100.0),
	]


static func pops(g: Dictionary, t: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for c: String in comms(t):
		out.append(int(g["comms"][c]["pop"]))
	return out


static func total_pop(g: Dictionary, t: Dictionary) -> int:
	var sum := 0
	for p: int in pops(g, t):
		sum += p
	return sum


## Share of people in cars at relation 15 or better (supportShare).
static func support_share(g: Dictionary, t: Dictionary) -> float:
	var total := total_pop(g, t)
	var sum := 0.0
	for c: String in comms(t):
		var s: Dictionary = g["comms"][c]
		if float(s["rel"]) >= 15.0:
			sum += float(s["pop"])
	return sum / float(total if total != 0 else 1)


## Seats per community as a Dictionary (seats in state.ts, via council_math).
static func seats(g: Dictionary, t: Dictionary) -> Dictionary:
	var list := CouncilMath.seats(pops(g, t))
	var out := {}
	for i: int in comms(t).size():
		out[comms(t)[i]] = list[i]
	return out


static func stage_of(rel: float, t: Dictionary) -> Dictionary:
	return CouncilMath.stage_of(rel, t["STAGES"])


static func is_session_seg(seg: int, t: Dictionary) -> bool:
	return seg > 0 and seg % int(t["P"]["sessionEvery"]) == 0


static func law_active(g: Dictionary, law: String) -> bool:
	return (g.get("passed", {}) as Dictionary).has(law)


## The fixed effects of a law (lawTechRes; the domestic tech that bends one law is off in S1a).
static func law_res(t: Dictionary, law: String) -> Dictionary:
	return t["LAWS_RES"][law]


## Sum of one additive law effect over the laws in force (lawSum in turn.ts).
static func law_sum(g: Dictionary, t: Dictionary, key: String) -> float:
	var sum := 0.0
	for law: String in (g.get("passed", {}) as Dictionary):
		sum += float(law_res(t, law).get(key, 0))
	return sum


## Product of one multiplying law effect (lawMult in turn.ts). haulMult needs the classroom rule,
## which is not ported, so it is refused.
static func law_mult(g: Dictionary, t: Dictionary, key: String) -> float:
	assert(key != "haulMult", "law_mult: haulMult is not ported")
	var m := 1.0
	for law: String in (g.get("passed", {}) as Dictionary):
		m *= float(law_res(t, law).get(key, 1))
	return m


## The lowest a lever may sit under the laws in force (lawFloor in turn.ts).
static func law_floor(g: Dictionary, t: Dictionary, key: String) -> float:
	var floor_v := 0.0
	for law: String in (g.get("passed", {}) as Dictionary):
		floor_v = maxf(floor_v, float(law_res(t, law).get(key, 0)))
	return floor_v


# ---- calm.ts: the evening pot and the wall ledger ----

static func pot_running(g: Dictionary, t: Dictionary) -> bool:
	if not law_active(g, "evening_pot"):
		return false
	var calm: Variant = g.get("calm")
	if calm is Dictionary and calm.get("potOn") != null:
		return bool(calm["potOn"])
	return float(g["coal"]) > float(t["CALM"]["potOffCoal"])


static func ledger_level(g: Dictionary, t: Dictionary) -> String:
	var calm: Dictionary = t["CALM"]
	if float(g["coal"]) <= float(calm["ledgerPoor"]) or float(g["food"]) <= float(calm["ledgerPoor"]):
		return "poor"
	if float(g["coal"]) >= float(calm["ledgerRich"]) and float(g["food"]) >= float(calm["ledgerRich"]):
		return "rich"
	return "mid"


static func calm_coal(g: Dictionary, t: Dictionary) -> float:
	return float(t["CALM"]["potCoal"]) if pot_running(g, t) else 0.0


static func calm_tension(g: Dictionary, t: Dictionary) -> float:
	var calm: Dictionary = t["CALM"]
	var v := 0.0
	if pot_running(g, t):
		v += float(calm["potTension"])
	if law_active(g, "wall_ledger"):
		var level := ledger_level(g, t)
		if level == "rich":
			v += float(calm["richTension"])
		elif level == "poor":
			v += float(calm["poorTension"])
	return v


## The engine's own coal per stretch (locoCoal in loco.ts); no engine chosen reads as the default.
static func loco_coal(g: Dictionary, t: Dictionary) -> float:
	var id: Variant = g.get("loco")
	if id == null:
		id = t["LOCO_DEFAULT"]
	return float(t["LOCO_COAL"][id])


## Bodies waiting for the pyre: the cold car plus the cars they lived in (pyreCount in turn.ts).
static func pyre_count(g: Dictionary) -> float:
	var n := float(g.get("pyre", 0))
	var kin: Variant = g.get("pyreKin")
	if kin is Dictionary:
		for v: Variant in (kin as Dictionary).values():
			n += float(v if v != null else 0)
	return n


static func is_gone(g: Dictionary, person: String) -> bool:
	return (g.get("deaths", []) as Array).has(person) or (g.get("left", []) as Array).has(person)


## The same state in the shape the train interior reads (train_rules.json, train_context.gd): the
## game's own fields under "train", each car under "comms" with its situation as "sit". Key names
## are S1's. Only fields this state carries are filled; the caller merges the rest (view, dom,
## injured, council and so on) as before.
static func to_rules(g: Dictionary, t: Dictionary) -> Dictionary:
	var train := {}
	for key: String in ["phase", "tension", "fear", "trust", "seg", "coal", "food", "med", "lux", "hunger", "stored", "decreeLeft", "passed", "stranded"]:
		if g.has(key):
			train[key] = g[key]
	var out_comms := {}
	for c: String in comms(t):
		var s: Dictionary = g["comms"][c]
		out_comms[c] = {"name": t["COMM_NAME"][c], "pop": s["pop"], "away": s["away"], "rel": s["rel"], "grudge": s["grudge"], "sit": situation(g, t, c)}
	return {"train": train, "comms": out_comms}
