extends RefCounted
const C = preload("res://game/train/turn/turn_common.gd")
const St = preload("res://game/train/train_state.gd")
const Turn = preload("res://game/train/train_turn.gd")
const People = preload("res://game/train/turn/turn_people.gd")
const WEATHER_WEIGHT: Array = [["snow", 30], ["fog", 20], ["sleet", 15], ["overcast", 20], ["clear", 15]]

static func event_state_key(g: Dictionary, t: Dictionary) -> String:
	var leaders: Array = []
	for comm: String in t["COMMS"]: leaders.append(g["comms"][comm]["leader"]["name"])
	var laws: Array = g["passed"].keys()
	laws.sort()
	var sit: Array = St.situation(g, t, "tail")
	return "%s|%d|%d|%d|%d|%s" % [",".join(leaders), int(floor(maxf(0, float(g["coal"])) / 40)), int(floor(maxf(0, float(g["food"])) / 40)), int(floor(maxf(0, float(sit[0])) / 10)), int(floor(maxf(0, float(sit[1])) / 10)), ",".join(laws)]

static func event_open(g: Dictionary, t: Dictionary, id: String) -> bool:
	match id:
		"tail_cold": return St.situation(g, t, "tail")[0] <= 38
		"crowd_fight": return St.situation(g, t, "tail")[2] >= 78
		"front_curtain": return int(g.get("eventLog", {}).get(id, {}).get("n", 0)) < 3
		"water_tower": return int(g["seg"]) >= 2
		"snow_drift": return int(g["seg"]) >= 3
		"abandoned_tender": return int(g["seg"]) >= 2 and float(g["coal"]) < 80
		"sick_child": return float(g["med"]) >= 2
		"ration_line": return St.situation(g, t, "tail")[1] < 45
		"guard_frost": return St.situation(g, t, "guard")[0] < 50
	return false

static func draw_event(g: Dictionary, t: Dictionary) -> String:
	var key: String = event_state_key(g, t)
	var pool: Array = []
	for id: String in ["tail_cold", "crowd_fight", "front_curtain", "water_tower", "snow_drift", "abandoned_tender", "sick_child", "ration_line", "guard_frost"]:
		if not event_open(g, t, id) or g["recentEvents"].has(id): continue
		var memo: Dictionary = g.get("eventLog", {}).get(id, {})
		if not memo.is_empty() and (int(g["seg"]) - int(memo["seg"]) < int(t["EVENT_COOLDOWN"]) or int(memo["n"]) >= int(t["EVENT_CHAIN_MAX"]) or memo.get("st") == key): continue
		pool.append(id)
	if float(g.get("hands", {}).get("short", {}).get("roof", 0)) > float(t["HANDS"]["roofOver"]):
		for id: String in ["water_tower", "snow_drift"]:
			if pool.has(id):
				for _i: int in range(1, int(t["HANDS"]["roofTrack"])): pool.append(id)
	if pool.is_empty(): return ""
	var id: String = pool[int(floor(C.rnd(g) * pool.size()))]
	g["recentEvents"].append(id)
	g["recentEvents"] = g["recentEvents"].slice(maxi(0, g["recentEvents"].size() - 4))
	return id

static func depart(g0: Dictionary, t: Dictionary) -> Dictionary:
	if g0.get("stranded") != null: return C.unsupported(g0, "depart: strandedDepart")
	if g0.get("eventPack", false) or g0.get("content") != null: return C.unsupported(g0, "depart: eventPack/content")
	var g: Dictionary = g0.duplicate(true)
	g.erase("platform")
	var p: Dictionary = t["P"]
	if int(g["seg"]) % int(p["winterEvery"]) == 0:
		for comm: String in t["COMMS"]: g["comms"][comm]["base"][0] -= float(p["winterDrop"])
		C.journal(g, "추위가 한 단계 깊어졌다. 모든 칸 온기 −5.", "bad")
	# 내정 훅 자리: domesticDepart / domesticStrikeLine / domesticStrikeRuns.
	var engine: Dictionary = g["comms"]["engine"]
	var striking: bool = int(engine["fervor"]) >= 1 and float(engine["rel"]) <= float(p["strikeRel"])
	if striking and St.law_active(g, "strike_ban"):
		engine["fervor"] = 0
		C.bump_rel(g, "engine", -10, "strike")
		g["fear"] = clampf(float(g["fear"]) + 10, 0, 100)
		C.journal(g, "파업 금지법에 따라 경비대가 기관실 문을 열었다. 화부들이 불 앞으로 끌려갔다.", "dark")
	elif striking:
		if not bool(g["inStrike"]): g["strikes"] += 1
		g["inStrike"] = true
		g["lostSegments"] += 1
		C.card(g, {"kind": "strike", "comm": "engine"})
		C.journal(g, "기관실이 파업했다. 열차가 섰다.", "bad")
		g["phase"] = "travel"
		return g
	g["inStrike"] = false
	if int(g["seg"]) == 1 and g.get("story", {}).get("flags", {}).get("depot_promise", false):
		C.card(g, {"kind": "pro_deal", "comm": "tail"})
		g["phase"] = "travel"
		return g
	if not People.recent(g, t):
		var event: String = draw_event(g, t)
		if event != "": C.card(g, {"kind": "travel", "text": event})
	g["phase"] = "travel"
	return g

static func pick_place(g: Dictionary, t: Dictionary, exclude: String = "") -> Dictionary:
	var r: float = C.rnd(g)
	var band: Dictionary = t["ROUTE"][-1]
	for row: Dictionary in t["ROUTE"]:
		if int(g["seg"]) <= int(row["to"]):
			band = row
			break
	if g["seg"] == band["relief"]["seg"]:
		var ids: Array = band["relief"]["places"].filter(func(id: String) -> bool: return id != exclude)
		if not ids.is_empty():
			var id: String = ids[int(floor(r * ids.size()))]
			for p: Dictionary in t["PLACES"]:
				if p["id"] == id: return p
			return t["PLACES"][0]
	var candidates: Array = []
	var total: float = 0
	for p: Dictionary in t["PLACES"]:
		if p["id"] != exclude and float(band["w"].get(p["id"], 0)) > 0:
			candidates.append(p)
			total += float(band["w"][p["id"]])
	var acc: float = 0
	for p: Dictionary in candidates:
		acc += float(band["w"][p["id"]])
		if r * total < acc: return p
	return candidates[-1] if not candidates.is_empty() else t["PLACES"][0]

static func suggest_target(g: Dictionary, loot: Dictionary) -> String:
	var need: Dictionary = {"coal": float(g["coal"]) / 252, "food": float(g["food"]) / 240}
	if float(g["med"]) < 8: need["medicine"] = float(g["med"]) / 20
	var keys: Array = need.keys()
	var order: Array = keys.duplicate()
	keys.sort_custom(func(a: String, b: String) -> bool: return float(need[a]) < float(need[b]) if need[a] != need[b] else order.find(a) < order.find(b))
	for key: String in keys:
		if float(loot[key]) >= 25: return key
	return "coal" if float(loot["coal"]) / (float(g["coal"]) + 1) > float(loot["food"]) / (float(g["food"]) + 1) else "food"

static func pick_fresh(pool: Array, seen: Array, salt: String) -> String:
	var start: int = C.hash_text(salt) % pool.size()
	var ordered: Array = []
	for i: int in pool.size(): ordered.append(pool[(start + i) % pool.size()])
	for line: String in ordered:
		if not seen.has(line): return line
	var oldest: String = ordered[0]
	for line: String in ordered:
		if seen.rfind(line) < seen.rfind(oldest): oldest = line
	return oldest

static func mark_seen(g: Dictionary, line: String) -> void:
	var seen: Array = []
	for old: String in g.get("linesSeen", []):
		if old != line: seen.append(old)
	seen.append(line)
	g["linesSeen"] = seen.slice(maxi(0, seen.size() - 150))

static func roll_stop_view(g: Dictionary, t: Dictionary, stop: Dictionary) -> void:
	var total: int = 0
	for row: Array in WEATHER_WEIGHT: total += int(row[1])
	var x: int = C.hash_text("%s:w:%d" % [g["seed"], int(g["seg"])]) % total
	var weather: String = "snow"
	for row: Array in WEATHER_WEIGHT:
		if x < int(row[1]):
			weather = row[0]
			break
		x -= int(row[1])
	var horde: bool = 1 + float(t["P"]["thrownHorde"]) * float(g["thrown"]) > 1.2
	var sign_tier: String = "many" if float(stop["threat"]) > 1 or horde else ("few" if float(stop["threat"]) < 1 else "some")
	var salt: String = "%s:%d:%s" % [g["seed"], int(g["seg"]), stop["place"]]
	var seen: Array = g.get("linesSeen", [])
	var sky: String = pick_fresh(t["WEATHER_LOOK"][weather], seen, salt + ":wl")
	var ground: String = pick_fresh(t["PLACE_LOOK"].get(stop["place"], t["PLACE_LOOK"]["freight"]), seen, salt + ":pl")
	var omens: Array = t["PLACE_OMENS"].get(stop["place"], t["PLACE_OMENS"]["freight"])[sign_tier] + t["WEATHER_OMENS"][weather][sign_tier]
	stop.merge({"weather": weather, "sign": sign_tier, "look": sky + " " + ground, "omen": pick_fresh(omens, seen, salt + ":om")}, true)
	mark_seen(g, sky)
	mark_seen(g, ground)

static func arrive_stop(g: Dictionary, t: Dictionary) -> void:
	var place: Dictionary = pick_place(g, t)
	var promise: Variant = g["comms"]["tail"].get("promise")
	var tail: bool = promise is Dictionary and promise["cond"]["kind"] == "skip_dispatch"
	var roll: float = C.rnd(g)
	var threat: float = 0.8 if roll < 0.25 else (1.0 if roll < 0.8 else 1.4)
	g["stop"] = {"place": place["id"], "target": suggest_target(g, place["loot"]), "stay": "normal", "crewComm": "guard" if tail else "tail", "crewSize": 4, "threat": threat, "done": false, "result": null}
	if place["id"] in ["freight", "factory"]:
		if not g.has("look"): g["look"] = {"low": {}, "skip": {}, "coalStops": 0}
		if not g["look"]["low"].has("coal"): g["look"]["coalStops"] += 1
	roll_stop_view(g, t, g["stop"])
	# 내정 훅 자리: alternative scouting place.
	g["phase"] = "stop"

static func run_travel(g0: Dictionary, t: Dictionary, after_stop: Callable) -> Dictionary:
	if bool(g0["inStrike"]): return after_stop.call(g0, t)
	if g0.get("stranded") != null or Turn.stalls_en_route(g0, t): return C.unsupported(g0, "runTravel: enterStranded/afterStop")
	var g: Dictionary = g0.duplicate(true)
	arrive_stop(g, t)
	return g
