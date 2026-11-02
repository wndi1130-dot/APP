extends RefCounted
## S1 supplies.ts. Optional stores; neither enabling nor using supplies creates domestic state.
const C = preload("res://game/train/turn/turn_common.gd")
const St = preload("res://game/train/train_state.gd")
const Hands = preload("res://game/train/train_hands.gd")

const YIELD: Dictionary = {"houses": 3.5, "church": 2.5, "office": 2.25, "hospital": 1.75, "freight": 1.0, "factory": 1.5}
const EPS: float = 1e-9


static func enable(g: Dictionary, t: Dictionary) -> void:
	g["supOn"] = true
	g["sup"] = float(t["P"]["sup0"])
	g["supCover"] = {}


static func asks(g: Dictionary) -> bool:
	return bool(g.get("supOn", false))


static func need(g: Dictionary, t: Dictionary) -> float:
	var total: float = 0.0
	for comm: String in t["COMMS"]:
		total += maxf(0.0, float(g["comms"][comm]["pop"])) / 100.0 * float(t["P"]["supPer100"])
	return total


static func _cover(got: float, own: float) -> float:
	return floorf(got / own * 1e6 + 0.5) / 1e6


## Empty when off. Plenty belongs to this consumption, not to any later delivery.
static func use(g: Dictionary, t: Dictionary) -> Dictionary:
	if not asks(g): return {}
	var living: Array[String] = []
	for comm: String in t["COMMS"]:
		if float(g["comms"][comm]["pop"]) > 0.0: living.append(comm)
	var wanted: float = need(g, t)
	var used: float = minf(maxf(0.0, float(g.get("sup", 0))), wanted)
	var cover: Dictionary = {}
	if not St.law_active(g, "contribution_ration") or used == wanted:
		for comm: String in living: cover[comm] = _cover(used, wanted) if wanted > 0.0 else 1.0
	else:
		var ranked: Array[Dictionary] = []
		for comm: String in living:
			# Those away worked this stretch too: do not use hands_offered here.
			ranked.append({"comm": comm, "hands": maxf(0.0, float(g["comms"][comm]["pop"])) * Hands.work_share(t, comm) * Hands.hands_will(g, t, comm)})
		ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["hands"]) > float(b["hands"]) if a["hands"] != b["hands"] else t["COMMS"].find(a["comm"]) < t["COMMS"].find(b["comm"]))
		var left: float = used
		for row: Dictionary in ranked:
			var comm: String = row["comm"]
			var own: float = float(g["comms"][comm]["pop"]) / 100.0 * float(t["P"]["supPer100"])
			var got: float = minf(left, own)
			cover[comm] = _cover(got, own)
			left = maxf(0.0, left - got)
	C.bump(g, "sup", -used, "sup.use")
	g["supCover"] = cover
	return {"need": wanted, "use": used, "cover": cover, "plenty": wanted > 0.0 and float(g.get("sup", 0)) >= float(t["P"]["supPlentyNeeds"]) * wanted - EPS}


## After drift, outside its relationship recovery ceiling of 15.
static func relations(g: Dictionary, t: Dictionary, turn: Dictionary) -> void:
	if not asks(g) or turn.is_empty(): return
	for comm: String in t["COMMS"]:
		if float(g["comms"][comm]["pop"]) <= 0.0 or not turn["cover"].has(comm): continue
		var f: float = float(turn["cover"][comm])
		if f < 1.0: C.bump_rel(g, comm, -float(t["P"]["supShortRel"]) * (1.0 - f), "sup")
		if bool(turn["plenty"]): C.bump_rel(g, comm, float(t["P"]["supPlentyRel"]), "sup")


## Ported for a later hygiene settlement; no S2 caller yet.
static func hygiene_short(g: Dictionary, t: Dictionary, comm: String) -> bool:
	return asks(g) and float(g["comms"][comm]["pop"]) > 0.0 and float(g.get("supCover", {}).get(comm, 1)) < float(t["P"]["supHygieneCover"])


static func add(g: Dictionary, amount: float, source: String) -> void:
	C.bump(g, "sup", amount, source)
