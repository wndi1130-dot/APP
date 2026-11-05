extends RefCounted
## S1 domestic/hooks.ts domesticDepart (8.5 engine stall, 6.5 breakdown roll, 8.7 pressure warning)
## and domesticStrikeRuns (8.7) for the S2 domestic subset, called from turn_travel.gd depart.
## The S2 game has no engine choice (S1's default c3, breakdown multiplier 0) and no manuals,
## apprentices, pressure cards or stokers. A state that would take one of those S1 steps is refused
## before the departure changes anything (refusal(), strike_refusal(); the caller returns
## C.unsupported of the state that came in); every other state departs as S1 departs.
## Design: coord/review/내정출발훅_설계_20261105.md (sections 3, 10).

const C = preload("res://game/train/turn/turn_common.gd")
const Research = preload("res://game/train/train_research.gd")


## Whether the hook runs: S1 projects a domestic run's people as `experts` (an empty roster when
## no one is left). A store without them is the S2 stores of an S1 run with no dom (TrainDom.ensure),
## and S1 skips the hook there (`if (!d) return null`).
static func on(g: Dictionary) -> bool:
	var dom: Variant = g.get("dom")
	return dom is Dictionary and (dom as Dictionary).has("experts")


## The engine the run drives (S1 loco.ts locoOf): none chosen reads as the default; an id the
## table does not know is null.
static func loco_spec(g: Dictionary, t: Dictionary) -> Variant:
	var id: Variant = g.get("loco")
	if id == null:
		id = t["LOCO_DEFAULT"]
	return (t["LOCO"] as Dictionary).get(id)


## S1 workshop.ts breakChance: (base + per defective tech) x the engine's multiplier.
static func break_chance(g: Dictionary, t: Dictionary, spec: Dictionary) -> float:
	var defects: int = 0
	for st: Variant in (g["dom"].get("techs", {}) as Dictionary).values():
		if st is Dictionary and st.get("stage") == "defective":
			defects += 1
	var d: Dictionary = t["D"]
	return (float(d["breakChance"]) + float(d["breakPerDefect"]) * defects) * float(spec["breakMult"])


## S1 loco.ts locoPressureChance: an engine that always builds pressure, or a crew whose best
## engine hand is exactly 1; null when no warning can come (no draw).
static func pressure_chance(t: Dictionary, spec: Dictionary, engine_skill: int) -> Variant:
	if bool(spec.get("pressureAlways", false)):
		return spec["pressureChance"] if spec.get("pressureChance") != null else t["D"]["pressureChance"]
	return t["D"]["pressureChance"] if engine_skill == 1 else null


## The S1 step this port does not carry that domesticDepart would take on g, or "" when it can
## depart here. Read before anything changes: the engine first, since an engine anyone drives
## passes the stall check in S1 (knowledge.ts engineStall).
static func refusal(g: Dictionary, t: Dictionary) -> String:
	if not on(g):
		return ""
	var spec: Variant = loco_spec(g, t)
	if not spec is Dictionary:
		return "domesticDepart: locomotive %s" % str(g.get("loco"))
	if bool(spec.get("anyoneDrives", false)):
		return "domesticDepart: anyoneDrives (%s)" % str(g.get("loco"))
	var top: int = Research.top_skill(g, "engine")
	if top == 0:
		return ""
	if break_chance(g, t, spec) > 0.0:
		return "domesticDepart: breakdown (%s)" % str(g.get("loco", t["LOCO_DEFAULT"]))
	if pressure_chance(t, spec, top) != null:
		return "domesticDepart: dom:pressure"
	return ""


## S1 domesticDepart on a state refusal() let through: false when no one can drive the engine
## (S1 engineStall 'end'; the S2 subset has no manual to read, so the run ends stranded), true to
## go on after the breakdown roll's one draw (S1 rolls before testing a chance that is 0 here).
## S1's `d.stalled = false` has no S2 key (the projection drops it).
static func depart(g: Dictionary, t: Dictionary) -> bool:
	if not on(g):
		return true
	if Research.top_skill(g, "engine") == 0:
		return false
	var spec: Dictionary = loco_spec(g, t)
	var draw: float = C.rnd(g)
	if draw < break_chance(g, t, spec):
		push_error("turn_dom_depart: a breakdown refusal() lets through")
	return true


## S1 domesticStrikeRuns where S1 calls it (a strike with no strike ban): a substitute driver,
## someone outside the engine car with engine skill 2 or more, takes S1 to the stoker card, which
## this port does not carry. Without one the engine car's strike stops the train, as it does now.
## (S1 domesticStrikeLine moves the strike line only with an engine manual, which S2 has not.)
static func strike_refusal(g: Dictionary) -> String:
	if not on(g):
		return ""
	for expert: Variant in g["dom"]["experts"]:
		if expert is Dictionary and expert.get("field") == "engine" and expert.get("comm") != "engine" and int(expert.get("skill", 0)) >= 2:
			return "domesticStrikeRuns: stoker"
	return ""
