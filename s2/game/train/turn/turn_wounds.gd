extends RefCounted
## S1 wounds.ts: S1a wound records, local injury RNG and daily treatment.
const C = preload("res://game/train/turn/turn_common.gd")
const St = preload("res://game/train/train_state.gd")
const People = preload("res://game/train/turn/turn_people.gd")
const Death = preload("res://game/train/turn/turn_death.gd")
const PART_NAME: Dictionary = {"head": "머리", "torso": "몸통", "armL": "왼팔", "armR": "오른팔", "legL": "왼다리", "legR": "오른다리"}

static func book(g: Dictionary) -> Array:
	if not g.has("wounds"): g["wounds"] = []
	return g["wounds"]

static func active(g: Dictionary, comm: String = "", live: bool = false) -> Array:
	var out: Array = []
	for w: Dictionary in book(g):
		if not w["state"] in ["bed", "home", "light"] or (comm != "" and w["comm"] != comm): continue
		if live and St.is_gone(g, w["who"]): continue
		out.append(w)
	return out

static func sync(g: Dictionary) -> void:
	g["injured"] = active(g, "", true).size()

static func weighted(random: Dictionary, keys: Array, weights: Array) -> String:
	var total: float = 0
	for w: float in weights: total += w
	var r: float = C.rnd(random) * total
	for i: int in keys.size():
		if r < float(weights[i]): return keys[i]
		r -= float(weights[i])
	return keys[-1]

static func push_wound(g: Dictionary, t: Dictionary, who: String, comm: String, from: String, where: String, random: Dictionary, opt: Dictionary = {}) -> Dictionary:
	var grade: String = str(opt["grade"]) if opt.has("grade") else weighted(random, ["light", "deep", "fracture", "amputation"], [0.3, 0.45, 0.2, 0.05])
	var part: String = str(opt["part"]) if opt.has("part") else weighted(random, ["armL", "armR", "legL", "legR", "torso", "head"], [0.2, 0.2, 0.2, 0.2, 0.15, 0.05])
	if grade == "fracture" and not part in ["armL", "armR", "legL", "legR"]: part = ["armL", "armR", "legL", "legR"][int(floor(C.rnd(random) * 4))]
	var coin: float = C.rnd(random) if grade == "deep" else 0.0
	var crowd: float = St.situation(g, t, comm)[2]
	var level: int = 3 if crowd >= float(t["P"]["crowdFrom"][2]) else (2 if crowd >= float(t["P"]["crowdFrom"][1]) else (1 if crowd >= float(t["P"]["crowdFrom"][0]) else 0))
	var septic: bool = bool(opt["septic"]) if opt.has("septic") else C.rnd(random) < float(opt.get("septicP", 0.2)) + float(t["P"]["crowdSeptic"]) * float(t["P"]["crowdMult"][level])
	var cuts: int = int(opt.get("cuts", -St.law_sum(g, t, "healDays")))
	var days: int = 1 if grade == "light" else ((3 if coin < 0.5 else 4) if grade == "deep" else ((6 if part in ["armL", "armR"] else 8) if grade == "fracture" else 4))
	var floor_days: int = 1 if grade == "light" else ((3 if part in ["armL", "armR"] else 4) if grade == "fracture" else 2)
	if cuts > 0: days = maxi(floor_days, days - cuts)
	if septic: days = int(ceil(days * 1.5))
	var state: String = "light" if grade == "light" else "bed"
	if state == "bed" and comm != "medtech" and not active(g, "medtech").is_empty(): days += 1
	var id: int = int(g.get("nextWoundId", 1))
	var w: Dictionary = {"id": id, "who": who, "comm": comm, "grade": grade, "part": part, "from": from, "where": where, "septic": septic, "daysLeft": days, "days0": days, "bedDays": 0 if grade == "light" else (4 if grade == "amputation" else 2), "state": state, "at": g["seg"]}
	if g["comms"][comm]["leader"]["name"] == who: w["personId"] = g["comms"][comm]["leader"]["personId"]
	if opt.get("why", "") != "": w["why"] = opt["why"]
	g["nextWoundId"] = id + 1
	book(g).append(w)
	return w

static func note_injury(g: Dictionary, t: Dictionary, n: int, from: String, where: String, opt: Dictionary = {}) -> void:
	if n <= 0: return
	var names: Array = opt.get("names", []).slice(0, n)
	if names.size() < n:
		var random: Dictionary = C.local_rng("%s:note:%d:%d:%s:%d" % [g["seed"], int(g["seg"]), int(g.get("nextWoundId", 1)), from, n])
		var all: Array = []
		for p: Dictionary in People.pick_victims(g, t, t["PROFILES"].size(), "wound", random):
			var wounded: bool = false
			for w: Dictionary in active(g):
				if w["who"] == p["name"]: wounded = true
			if not names.has(p["name"]) and not wounded: all.append(p)
		var mine: Array = []
		for p: Dictionary in all:
			if p["community"] == opt.get("comm"): mine.append(p)
		var pool: Array = mine if mine.size() >= n - names.size() else all
		for p: Dictionary in pool:
			if names.size() >= n: break
			names.append(p["name"])
	for who: String in names:
		var comm: String = str(opt.get("comm", "tail"))
		var p: Dictionary = C.profile(t, who)
		if who == "열차장": comm = "front"
		elif not p.is_empty(): comm = p["community"]
		else:
			for k: String in t["COMMS"]:
				if g["comms"][k]["leader"]["name"] == who: comm = k
		push_wound(g, t, who, comm, from, where, C.local_rng("%s:wound:%d:%d:%s" % [g["seed"], int(g["seg"]), int(g.get("nextWoundId", 1)), who]), {"why": opt.get("why", "")})

static func note_relief(g: Dictionary, n: int) -> void:
	for w: Dictionary in active(g, "", true).slice(0, maxi(0, n)): w["state"] = "healed"

static func reconcile(g: Dictionary, t: Dictionary) -> void:
	var live: int = active(g, "", true).size()
	var n: int = int(floor(float(g["injured"])))
	if n > live: note_injury(g, t, n - live, "stop", "")
	elif n < live: note_relief(g, live - n)

static func rebalance(g: Dictionary, t: Dictionary) -> void:
	var candidates: Array = []
	for w: Dictionary in book(g):
		if w["state"] in ["bed", "home"]: candidates.append(w)
	var ordered: Array = candidates.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) < int(b["at"]) if a["at"] != b["at"] else int(a["id"]) < int(b["id"]))
	var ids: Array = []
	for w: Dictionary in ordered.slice(0, int(t["D"]["beds"])): ids.append(w["id"])
	for w: Dictionary in candidates:
		if ids.has(w["id"]) and w["state"] == "home": w["state"] = "bed"
		elif not ids.has(w["id"]) and w["state"] == "bed":
			w["state"] = "home"
			w["daysLeft"] += 1
	sync(g)

static func med_per_day(w: Dictionary) -> float:
	var amount: float = 0.5 if w["grade"] in ["deep", "amputation"] or (w["grade"] == "fracture" and int(w["bedDays"]) > 0) else 0.0
	return amount + (0.5 if bool(w["septic"]) else 0.0)

static func tick(g: Dictionary, t: Dictionary, notes: Array, med_mult: float) -> void:
	for w: Dictionary in active(g):
		if St.is_gone(g, w["who"]): w["state"] = "healed"
	var act: Array = active(g, "", true)
	if act.is_empty():
		sync(g)
		return
	var need: float = 0
	for w: Dictionary in act: need += med_per_day(w)
	need *= med_mult
	var med: Dictionary = g["comms"]["medtech"]
	if int(med["fervor"]) >= 1 and float(med["rel"]) <= -40:
		C.bump(g, "med", -minf(need, float(g["med"])), "sick")
		notes.append("의무진이 진료를 거부했다.")
		sync(g)
		return
	if float(g["med"]) < need:
		C.put(g, "med", 0, "sick")
		notes.append("의약품이 떨어졌다.")
		for w: Dictionary in act:
			var chance: float = (0.2 if bool(w["septic"]) else 0.1) if w["grade"] == "deep" else (0.03 if w["grade"] == "fracture" else (0.15 if w["grade"] == "amputation" else 0.0))
			if w["who"] != "열차장" and chance > 0 and C.rnd(g) < chance:
				book(g).erase(w)
				Death.on_death(g, t, w["comm"], [w["who"]])
		sync(g)
		return
	C.bump(g, "med", -need, "sick")
	for w: Dictionary in act:
		if w["at"] == g["seg"]: continue
		w["daysLeft"] -= 1
		if w["state"] in ["bed", "home"]: w["bedDays"] -= 1
	for w: Dictionary in act:
		if w["grade"] == "amputation" and int(w["bedDays"]) <= 0:
			w["state"] = "permanent"
			C.journal(g, "%s의 %s은(는) 돌아오지 않는다." % [w["who"], PART_NAME[w["part"]]])
		elif int(w["daysLeft"]) <= 0:
			w["state"] = "healed"
			C.journal(g, "%s의 %s이(가) 다 나았다." % [w["who"], PART_NAME[w["part"]]], "good")
		elif int(w["bedDays"]) <= 0 and w["state"] in ["bed", "home"]:
			w["state"] = "light"
			C.journal(g, "%s이(가) 침상에서 내려왔다. %s은(는) 아직 낫지 않았다." % [w["who"], PART_NAME[w["part"]]])
	for w: Dictionary in act:
		if w["state"] in ["bed", "home", "light"] and bool(w["septic"]) and float(w["daysLeft"]) < float(w["days0"]) * 2 and C.rnd(g) < 0.1: w["daysLeft"] += 1
	sync(g)
