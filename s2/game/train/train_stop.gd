extends RefCounted
## Choosing the first stop, ported from s1/src/game/turn.ts (the reference) for the S1a game: the
## work crew, how many hands a place wants, and the risk line the stop card promises. States and
## tables as in train_state.gd. Nothing here draws from the game's random stream: each crew
## member's fate is a hash of the seed, stretch, place and name, as in S1.
## tests/train/test_train_stop.gd checks every function against the S1 answers.

const St = preload("res://game/train/train_state.gd")
const Rng = preload("res://game/politics/rng.gd")
const CouncilMath = preload("res://game/politics/council_math.gd")

const FNV_OFFSET := 2166136261
const FNV_PRIME := 16777619


## FNV-1a over UTF-16 code units, as hash() in omens.ts reads a JS string.
static func hash_text(text: String) -> int:
	var x := FNV_OFFSET
	for i: int in text.length():
		var cp := text.unicode_at(i)
		if cp > 0xFFFF:
			cp -= 0x10000
			x = Rng.imul(x ^ (0xD800 + (cp >> 10)), FNV_PRIME)
			x = Rng.imul(x ^ (0xDC00 + (cp & 0x3FF)), FNV_PRIME)
		else:
			x = Rng.imul(x ^ cp, FNV_PRIME)
	return x & Rng.MASK


static func threat_step(threat: float, t: Dictionary) -> int:
	var steps: Array = t["THREAT_STEPS"]
	if threat <= float(steps[0]):
		return 0
	return 1 if threat < float(steps[2]) else 2


## The outside threat after scouting gear noise; no noise leaves it as it was (effThreat).
static func eff_threat(stop: Variant, t: Dictionary) -> float:
	var threat := 1.0
	var noise := 0
	if stop is Dictionary:
		if stop.get("threat") != null:
			threat = float(stop["threat"])
		if stop.get("noise") != null:
			noise = int(stop["noise"])
	if noise == 0:
		return threat
	return float(t["THREAT_STEPS"][clampi(threat_step(threat, t) + noise, 0, 2)])


## How a crew's size against the hands the place wants scales each person's risk (crewMult).
static func crew_mult(r: float, curve: String, t: Dictionary) -> float:
	var p: Dictionary = t["P"]
	if curve == "off":
		return 1.0
	if curve == "A":
		return St.clampv(pow(maxf(r, 1e-6), -float(p["crewAPow"])), float(p["crewAFloor"]), float(p["crewACeil"]))
	if r <= 0.5:
		return float(p["crewBCeil"])
	if r <= 1.0:
		return float(p["crewBCeil"]) + (1.0 - float(p["crewBCeil"])) * (r - 0.5) / 0.5
	if r < 2.0:
		return 1.0 + (float(p["crewBFloor"]) - 1.0) * (r - 1.0)
	return float(p["crewBFloor"])


static func crew_band(r: float, t: Dictionary) -> String:
	var p: Dictionary = t["P"]
	if r < float(p["crewBandShort"]):
		return "short"
	return "tight" if r < float(p["crewBandEnough"]) else "enough"


## Exposure a crew of this size adds and the ceiling it may reach: {gain, cap} (crewGainOf).
static func crew_gain_of(size: float, cost: String, t: Dictionary) -> Dictionary:
	var p: Dictionary = t["P"]
	var k: Dictionary = t["CREW_COST"][cost]
	var pw := float(k["pow"])
	var gain := float(p["crewGain"]) * (pow(size / float(t["CREW_COST_REF"]), pw) if pw != 0.0 else 1.0)
	return {"gain": gain, "cap": float(p["crewCap"]) + maxf(0.0, gain - float(p["crewGain"]))}


static func crew_haul_mult(size: float, need: float, haul: String, t: Dictionary) -> float:
	if haul == "flat":
		return 0.7 + 0.075 * size
	return 0.7 + 0.075 * minf(size, need) + 0.075 * float(t["CREW_HAUL_OVER"][haul]) * maxf(0.0, size - need)


## Returned crew who sit out this session's vote (crewAwayOf).
static func crew_away_of(returned: float, cost: String, t: Dictionary) -> int:
	return CouncilMath.round_half_up(returned * float(t["CREW_COST"][cost]["away"]))


## The crew sent from car c: the living 16 to 65 of that car, minus scouts already out and a sick
## representative, starting at a place fixed by the stretch (crewNames).
static func crew_names(g: Dictionary, t: Dictionary, c: String, size: int) -> Array[String]:
	var stop: Variant = g.get("stop")
	var scouts: Array = []
	if stop is Dictionary and stop.get("scoutReport") is Dictionary:
		scouts = stop["scoutReport"]["names"]
	var sick_rep: Variant = null
	var sick: Variant = g["comms"][c].get("sick")
	if sick is Dictionary:
		sick_rep = sick["rep"]["name"]
	var busy := crew_busy(g)
	var alive: Array[String] = []
	for person: Dictionary in t["PROFILES"]:
		var person_name: String = person["name"]
		var age := float(person["age"])
		if person["community"] == c and not St.is_gone(g, person_name) and age >= 16.0 and age <= 65.0 \
				and not scouts.has(person_name) and person_name != sick_rep and not busy.has(person_name):
			alive.append(person_name)
	var out: Array[String] = []
	if alive.is_empty():
		return out
	var start := (int(g["seg"]) * 7) % alive.size()
	for i: int in mini(size, alive.size()):
		out.append(alive[(start + i) % alive.size()])
	return out


## Who cannot go out on a crew (S1 CREW_BUSY): one healing from more than a light
## wound (wounds.ts) and newcomers still waiting to be taken in (arrivals.ts).
static func crew_busy(g: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for w: Dictionary in g.get("wounds", []):
		if ["bed", "home", "light"].has(String(w.get("state", ""))) and String(w.get("grade", "")) != "light":
			out.append(String(w["who"]))
	var arrivals: Variant = g.get("arrivals")
	if arrivals is Dictionary and arrivals.get("pending") is Dictionary:
		for n: Variant in (arrivals["pending"] as Dictionary).get("names", []):
			out.append(String(n))
	return out


## How the sent car's exposure raises its chances of harm: 1 up to 50, +0.5% a point above.
static func expose_mult(g: Dictionary, t: Dictionary, c: String) -> float:
	var p: Dictionary = t["P"]
	return 1.0 + maxf(0.0, St.situation(g, t, c)[3] - float(p["exposeFrom"])) * float(p["exposeHurt"])


static func _fate_roll(g: Dictionary, person: String, kind: String) -> float:
	var stop: Dictionary = g["stop"]
	var place: Variant = stop.get("place")
	var key := "%s|%d|%s|%s|%s%s" % [g["seed"], int(g["seg"]), place if place != null else "", person, kind,
		"|again" if bool(stop.get("again", false)) else ""]
	return float(hash_text(key)) / 4294967296.0


static func _place(t: Dictionary, id: Variant) -> Dictionary:
	for place: Dictionary in t["PLACES"]:
		if place["id"] == id:
			return place
	return t["PLACES"][0]


## The stop's risk line (stopRisk): expected harm, the crew's fixed fates, the hands the place wants.
static func stop_risk(g: Dictionary, t: Dictionary) -> Dictionary:
	var p: Dictionary = t["P"]
	var stop: Variant = g.get("stop")
	var has_stop := stop is Dictionary
	var place := _place(t, stop.get("place") if has_stop else null)
	var stay: Dictionary = t["STAY"][stop.get("stay", "normal") if has_stop and stop.get("stay") != null else "normal"]
	# Those who can actually go, not the size picked (S1 stopRisk, 검수 PR 395): fewer when the car runs short.
	var names: Array[String] = []
	if has_stop:
		names = crew_names(g, t, stop["crewComm"], int(stop["crewSize"]) if stop.get("crewSize") != null else 4)
	var crew := float(names.size()) if has_stop else 4.0
	var guard: Dictionary = g["comms"]["guard"]
	var guard_refused := float(guard["fervor"]) >= 1.0 and float(guard["rel"]) <= -40.0
	var guard_mult := 1.5 if guard_refused else 1.0
	var horde := minf(1.5, 1.0 + float(p["thrownHorde"]) * float(g["thrown"]))
	var escort := 0.5 if bool(g["guardEscort"]) else 1.0
	var now := eff_threat(stop, t)
	var threat := now * (float(p["pyreLight"]) if St.pyre_count(g) > 0.0 else 1.0)
	if g.get("hands") is Dictionary and t.has("HANDS"):
		threat *= 1 + float(t["HANDS"]["watchRisk"]) * float(g["hands"]["short"].get("watch", 0))
	var tired := expose_mult(g, t, stop["crewComm"]) if has_stop else 1.0
	var risk := float(place["risk"])
	var need := maxf(float(p["crewNeedMin"]), float(p["crewNeed"]) * risk * float(stay["risk"]) * now * guard_mult * horde * escort)
	var ratio := crew / need
	var m := crew_mult(ratio, t["CREW"]["curve"], t)
	var lam := risk * float(p["injuryRate"]) * guard_mult * horde * float(stay["risk"]) * (crew / 4.0) * escort * threat * 1.0 * tired * m
	var p_death := risk * float(p["deathRate"]) * guard_mult * horde * St.law_mult(g, t, "deathMult") * float(stay["risk"]) * escort * threat * 1.0 * tired * m
	var dead: Array[String] = []
	var hurt: Array[String] = []
	if has_stop:
		var qd := p_death / 4.0
		var qh := minf(0.9, lam / maxf(1.0, names.size()))
		for n: String in names:
			if _fate_roll(g, n, "d") < qd and dead.size() < maxi(0, names.size() - 1):
				dead.append(n)
		for n: String in names:
			if not dead.has(n) and _fate_roll(g, n, "h") < qh:
				hurt.append(n)
	var raw_threat := float(stop["threat"]) if has_stop and stop.get("threat") != null else 1.0
	return {
		"lam": lam, "pDeath": p_death, "maxHurt": hurt.size(), "maxDead": dead.size(), "dead": dead, "hurt": hurt,
		"guardRefused": guard_refused, "horde": horde > 1.2, "fresh": raw_threat > 1.0,
		# A blizzard hides what the scouts saw (S1 blizzardActive).
		"known": has_stop and bool(stop.get("scout", false)) and not _blizzard_active(g), "pyre": St.pyre_count(g) > 0.0,
		"noisy": threat_step(now, t) > threat_step(raw_threat, t),
		"need": need, "ratio": ratio, "band": crew_band(ratio, t),
	}


static func _blizzard_active(g: Dictionary) -> bool:
	var d: Variant = g.get("disaster")
	return d is Dictionary and d.get("kind") == "blizzard" and d.get("stage") == "active"


## The promise step of a risk line: dead, hurt, light or calm (riskLevel).
static func risk_level(r: Dictionary) -> String:
	if int(r["maxDead"]) > 0:
		return "dead"
	if int(r["maxHurt"]) > 0:
		return "hurt"
	return "light" if float(r["lam"]) >= 0.2 else "calm"


## What the stop card shows for sending car c (crewPreview): exposure before and after, relation
## cost of unfamiliar work, haul share, the cars that rest, and the risk factor.
static func crew_preview(g: Dictionary, t: Dictionary, c: String) -> Dictionary:
	var p: Dictionary = t["P"]
	var stop: Variant = g.get("stop")
	var size := float(stop["crewSize"]) if stop is Dictionary and stop.get("crewSize") != null else float(t["CREW_COST_REF"])
	var ex := St.situation(g, t, c)[3]
	var base3 := float(g["comms"][c]["base"][3])
	var gc := crew_gain_of(size, t["CREW"]["cost"], t)
	var to := CouncilMath.round_half_up(ex + maxf(0.0, minf(float(gc["cap"]), base3 + float(gc["gain"])) - base3))
	var rest: Array[String] = []
	var floors: Dictionary = t["REST_FLOOR"]
	for o: String in St.comms(t):
		if o != c and floors.has(o) and float(g["comms"][o]["base"][3]) > float(floors[o]):
			rest.append(o)
	var hauls: Dictionary = t["CREW_HAUL"]
	return {
		"from": CouncilMath.round_half_up(ex), "to": to,
		"rel": float(p["choreRel"]) if (t["CHORE_COMMS"] as Array).has(c) else 0.0,
		"haul": float(hauls[c]) if hauls.has(c) else 1.0, "rest": rest, "risk": expose_mult(g, t, c),
	}


## Set what the stop goes for, how long, which car and how many (setStop). The engine car cannot be
## sent; the crew stays between 2 and 8. A done stop is left as it is. Scouting is a separate act.
static func set_stop(g0: Dictionary, t: Dictionary, patch: Dictionary) -> Dictionary:
	var g := g0.duplicate(true)
	var stop: Variant = g.get("stop")
	if not stop is Dictionary or bool(stop.get("done", false)):
		return g
	for key: String in ["target", "stay", "crewComm", "crewSize"]:
		if not patch.has(key):
			continue
		if key == "crewComm" and not (t["CREW_COMMS"] as Array).has(patch[key]):
			continue
		stop[key] = patch[key]
	stop["crewSize"] = int(St.clampv(float(stop["crewSize"]), 2.0, 8.0))
	return g
