extends RefCounted
## S1 stranded.ts: mutate the caller's working copy; only roll_station consumes RNG.
const C = preload("res://game/train/turn/turn_common.gd")
const St = preload("res://game/train/train_state.gd")
const Content = preload("res://game/train/turn/turn_content.gd")
const Death = preload("res://game/train/turn/turn_death.gd")
const Research = preload("res://game/train/train_research.gd")
const EVENTS = ["ev_str_lamp", "ev_str_snow", "ev_str_promise", "ev_str_half_bowl"]
const CARD_KINDS = ["trip_depart", "trip_return", "trip_lost", "trip_extend"]

## S1 josa.ts finalOf/josa, kept in rules rather than the UI.
static func josa(word: String, pair: String) -> String:
	var clean: String = word.strip_edges()
	var ch: String = clean.right(1)
	var code: int = ch.unicode_at(0) if not ch.is_empty() else 0
	var ending: int = 0 # none / final / rieul
	if code >= 0xac00 and code <= 0xd7a3:
		var jong: int = (code - 0xac00) % 28
		ending = 0 if jong == 0 else (2 if jong == 8 else 1)
	elif ch in ["1", "7", "8"]: ending = 2
	elif ch in ["0", "3", "6"]: ending = 1
	var parts: PackedStringArray = pair.split("/")
	if parts[0] == "으로": return "으로" if ending == 1 else "로"
	return parts[1] if ending == 0 else parts[0]

static func _flags(g: Dictionary) -> Dictionary:
	if g.get("contentFlags") == null: g["contentFlags"] = {}
	return g["contentFlags"]

static func seg_km_of(g: Dictionary, t: Dictionary, seg: int = -1) -> float:
	if seg < 0: seg = int(g["seg"])
	for row: Dictionary in g["route"] if g.get("route") is Array else []:
		if int(row["seg"]) == seg: return float(row["km"]) if row.get("km") != null else float(t["P"]["segKmDefault"])
	return float(t["P"]["segKmDefault"])

static func stall_km(seg_km: float, coal_before: float, need: float) -> float:
	if need <= 0: return maxf(1, seg_km - 1)
	return minf(maxf(1, seg_km - 1), maxf(1, floori(seg_km * maxf(0, coal_before) / need)))

static func enter_stranded(g: Dictionary, t: Dictionary, coal_before: float, need: float) -> void:
	C.put(g, "coal", 0, "short")
	var km: float = seg_km_of(g, t)
	var at: float = stall_km(km, coal_before, need)
	g["stranded"] = {"since": g["seg"], "turns": 0, "segKm": km, "atKm": at, "toNextKm": km - at, "seen": [],
		"trip": null, "captainAway": false, "deputy": null, "lostTrips": 0, "snow": null, "lamp": false, "burned": maxf(0, coal_before)}
	_flags(g)["stranded"] = true
	C.journal(g, "불이 꺼졌다. 열차가 %dkm 지점에서 섰다. 다음 역까지 %dkm. 창마다 입김이 서린다." % [int(at), int(km - at)], "dark")

static func _go_turns(p: Dictionary, dist: float) -> int:
	return maxi(1, ceili(dist / float(p["tripGoKm"])))

static func _back_turns(p: Dictionary, dist: float, lamp: bool) -> int:
	return maxi(1, ceili(dist / float(p["tripBackKm"])) - (1 if lamp else 0))

static func _total(trip: Dictionary) -> int:
	return int(trip["goTurns"]) + int(trip["searchTurns"]) + int(trip["backTurns"])

static func sync_flags(g: Dictionary, t: Dictionary, st: Dictionary) -> void:
	var flags: Dictionary = _flags(g)
	if flags.get("stranded_lamp") == true:
		flags["stranded_lamp"] = false
		st["lamp"] = true
		var trip: Variant = st["trip"]
		if trip != null and trip["phase"] != "back":
			trip["backTurns"] = _back_turns(t["P"], float(trip["distKm"]), true)
			if int(trip["extends"]) == 0: trip["plannedTurns"] = _total(trip)
	if flags.get("stranded_snow") in ["all", "guard", "none"]:
		st["snow"] = flags["stranded_snow"]
		flags["stranded_snow"] = false

static func volunteer_pool(g: Dictionary, t: Dictionary, comm: String) -> Array:
	var s: Dictionary = g["comms"][comm]
	var sick: Variant = s["sick"]["rep"]["name"] if s.get("sick") is Dictionary else null
	var alive: Array = []
	for person: Dictionary in t["PROFILES"]:
		if person["community"] == comm and not St.is_gone(g, person["name"]) and float(person["age"]) >= 16 and float(person["age"]) <= 65 and person["name"] != sick and person["name"] != s["leader"]["name"]:
			alive.append(person["name"])
	if alive.is_empty(): return []
	var start: int = (int(g["seg"]) * 7) % alive.size()
	var out: Array = []
	for i: int in alive.size(): out.append(alive[(start + i) % alive.size()])
	return out

static func _by_rel(g: Dictionary, t: Dictionary) -> Array:
	var order: Array = t["COMMS"]
	var sorted: Array = order.duplicate()
	sorted.sort_custom(func(a: String, b: String) -> bool:
		var ar: float = float(g["comms"][a]["rel"])
		var br: float = float(g["comms"][b]["rel"])
		return ar > br if ar != br else order.find(a) < order.find(b))
	return sorted

static func deputy_of(g: Dictionary, t: Dictionary) -> String:
	return _by_rel(g, t)[0]

static func trip_plan(g: Dictionary, t: Dictionary, mode: String) -> Variant:
	if g.get("stranded") == null: return null
	var st: Dictionary = g["stranded"]
	var p: Dictionary = t["P"]
	sync_flags(g, t, st)
	var leader: bool = mode == "captain"
	var forced: bool = leader and St.support_share(g, t) < float(p["supportLine"])
	var need: int = int(p["tripSize"]) - (1 if leader else 0)
	var pools: Array = []
	for comm: String in _by_rel(g, t):
		if not leader and float(g["comms"][comm]["rel"]) < 15: continue
		var pool: Array = volunteer_pool(g, t, comm)
		if not pool.is_empty(): pools.append({"comm": comm, "pool": pool})
	if pools.is_empty(): return null
	var pick: Dictionary = pools[0]
	for entry: Dictionary in pools:
		if entry["pool"].size() >= need:
			pick = entry
			break
		if entry["pool"].size() > pick["pool"].size(): pick = entry
	if not leader and pick["pool"].size() < need: return null
	var names: Array = pick["pool"].slice(0, need)
	var size: int = names.size() + (1 if leader else 0)
	var dist: float = float(st["toNextKm"])
	var go: int = _go_turns(p, dist)
	var back: int = _back_turns(p, dist, bool(st["lamp"]))
	var total: int = go + int(p["tripSearchTurns"]) + back
	return {"comm": pick["comm"], "names": names, "size": size, "leaderGoes": leader, "forced": forced,
		"distKm": dist, "goTurns": go, "searchTurns": p["tripSearchTurns"], "backTurns": back, "total": total,
		"food": ceili(size * total * float(p["tripFoodPer"]))}

static func crew_allowed(g: Dictionary, t: Dictionary) -> bool:
	return St.support_share(g, t) >= float(t["P"]["supportLine"])

static func support_line_text(g: Dictionary, t: Dictionary) -> String:
	var pct: int = floori(St.support_share(g, t) * 100 + 0.5)
	var line: int = floori(float(t["P"]["supportLine"]) * 100 + 0.5)
	return ("따르는 사람 %d%%. %d%%를 넘어 수색대를 보낼 수 있다." if crew_allowed(g, t) else "따르는 사람 %d%%. %d%%가 안 돼 열차장이 직접 간다.") % [pct, line]

static func start_trip(g: Dictionary, t: Dictionary, mode: String) -> bool:
	if g.get("stranded") == null or g["stranded"]["trip"] != null: return false
	var st: Dictionary = g["stranded"]
	var plan: Variant = trip_plan(g, t, mode)
	if plan == null: return false
	var take: float = maxf(0, minf(float(plan["food"]), floori(float(g["food"]))))
	C.bump(g, "food", -take, "cart")
	st["trip"] = {"leaderGoes": plan["leaderGoes"], "forced": plan["forced"], "comm": plan["comm"], "names": plan["names"], "size": plan["size"],
		"distKm": plan["distKm"], "extends": 0, "goTurns": plan["goTurns"], "searchTurns": plan["searchTurns"], "backTurns": plan["backTurns"],
		"plannedTurns": plan["total"], "turn": 0, "phase": "go", "posKm": 0, "baseFood": take, "foodShort": float(plan["food"]) - take, "foodOwed": 0,
		"outcome": null, "known": false, "promise": null}
	_flags(g)["trip_out"] = true
	if bool(plan["leaderGoes"]):
		st["captainAway"] = true
		st["deputy"] = deputy_of(g, t)
		g["councilOwed"] = false
		var name: String = t["COMM_NAME"][st["deputy"]]
		C.journal(g, "열차장이 수동차에 올랐다. %s%s 열차를 맡는다." % [name, josa(name, "이/가")], "dark")
	else:
		C.journal(g, "%s에서 %d명이 수동차에 올랐다. 자루 둘과 나무 상자 하나를 싣는다." % [t["COMM_NAME"][plan["comm"]], plan["names"].size()], "dark")
	return true

static func _take_promise(g: Dictionary, t: Dictionary, trip: Dictionary) -> void:
	var flags: Dictionary = _flags(g)
	var pr: Variant = flags.get("stranded_promise")
	if pr not in ["yes", "no"]: return
	flags["stranded_promise"] = false
	trip["promise"] = pr
	C.bump_rel(g, trip["comm"], float(t["P"]["promiseRel"] if pr == "yes" else t["P"]["promiseSkipRel"]), "cart")

static func _roll_station(g: Dictionary, t: Dictionary, trip: Dictionary) -> void:
	var p: Dictionary = t["P"]
	var shortage: float = minf(float(p["tripShortMax"]), floori(float(trip["foodShort"]) / 2) * float(p["tripShortLost"]))
	var lost: float = minf(0.9, float(p["tripLostFirst"]) + float(p["tripLostStep"]) * int(trip["extends"]) + shortage)
	var ext: float = float(p["tripExtendFirst"]) if int(trip["extends"]) == 0 else (float(p["tripExtendNext"]) if int(trip["extends"]) == 1 else 0.0)
	var roll: float = C.rnd(g)
	if roll < lost:
		trip["outcome"] = "lost"
		return
	if roll < lost + ext:
		trip["extends"] += 1
		trip["distKm"] += float(p["extendKm"])
		trip["goTurns"] = _go_turns(p, float(trip["distKm"]))
		trip["backTurns"] = _back_turns(p, float(trip["distKm"]), bool(g["stranded"]["lamp"]))
		trip["foodOwed"] += ceili(float(trip["baseFood"]) * (pow(float(p["tripFoodMult"]), int(trip["extends"])) - pow(float(p["tripFoodMult"]), int(trip["extends"]) - 1)))
		return
	trip["outcome"] = "coal"

static func _learn_extend(g: Dictionary, trip: Dictionary) -> float:
	var owed: float = float(trip["foodOwed"])
	if owed > 0:
		C.bump(g, "food", -minf(owed, maxf(0, float(g["food"]))), "cart")
		trip["foodOwed"] = 0
	trip["known"] = true
	return owed

static func _pos_of(t: Dictionary, trip: Dictionary) -> float:
	if int(trip["turn"]) <= int(trip["goTurns"]): return minf(float(trip["distKm"]), int(trip["turn"]) * float(t["P"]["tripGoKm"]))
	if int(trip["turn"]) <= int(trip["goTurns"]) + int(trip["searchTurns"]): return float(trip["distKm"])
	return maxf(0, float(trip["distKm"]) - (int(trip["turn"]) - int(trip["goTurns"]) - int(trip["searchTurns"])) * float(t["P"]["tripBackKm"]))

static func _resolve_lost(g: Dictionary, t: Dictionary, st: Dictionary, trip: Dictionary) -> void:
	Death.on_death(g, t, trip["comm"], trip["names"], "other")
	C.bump_rel(g, trip["comm"], float(t["P"]["tripLostRel"]), "cart")
	C.bump(g, "tension", float(t["P"]["tripLostTension"]), "cart")
	g["fear"] = clampf(float(g["fear"]) + float(t["P"]["tripLostFear"]), 0, 100)
	st["lostTrips"] += 1
	st["trip"] = null
	_flags(g)["trip_out"] = false
	g["councilOwed"] = false
	C.journal(g, ("수동차는 돌아오지 않았다. " + (", ".join(trip["names"]) + "의 이름을 일지에 적었다." if not trip["names"].is_empty() else "")).strip_edges(), "bad")
	if bool(trip["leaderGoes"]):
		st["captainAway"] = false
		load("res://game/train/train_turn.gd").finish(g, t, "lost_captain")
		return
	C.card(g, {"kind": "trip_lost", "comm": trip["comm"], "who": ",".join(trip["names"]), "n": trip["turn"]}, t)

static func trip_tick(g: Dictionary, t: Dictionary) -> void:
	if g.get("stranded") == null or g["stranded"]["trip"] == null: return
	var st: Dictionary = g["stranded"]
	var trip: Dictionary = st["trip"]
	_take_promise(g, t, trip)
	trip["turn"] += 1
	if trip["turn"] == trip["goTurns"] and trip["outcome"] == null:
		_roll_station(g, t, trip)
		if Research.usable(g, t, "r3"):
			if trip["outcome"] == "lost":
				_resolve_lost(g, t, st, trip)
				return
			if int(trip["extends"]) > 0 and not bool(trip["known"]):
				var owed: float = _learn_extend(g, trip)
				C.journal(g, "무전이 짧게 왔다. 역에 석탄이 없다. 15km를 더 간다.", "dark")
				C.card(g, {"kind": "trip_extend", "comm": trip["comm"], "n": owed}, t)
	trip["phase"] = "go" if int(trip["turn"]) <= int(trip["goTurns"]) else ("search" if int(trip["turn"]) <= int(trip["goTurns"]) + int(trip["searchTurns"]) else "back")
	trip["posKm"] = _pos_of(t, trip)
	var total: int = _total(trip)
	if trip["outcome"] == "coal" and int(trip["turn"]) >= total:
		if int(trip["extends"]) > 0 and not bool(trip["known"]): _learn_extend(g, trip)
		C.card(g, {"kind": "trip_return", "comm": trip["comm"], "n": trip["turn"]}, t)
		return
	if trip["outcome"] == "lost" and int(trip["turn"]) > total:
		_resolve_lost(g, t, st, trip)
		return
	if int(trip["turn"]) == 1: C.journal(g, "수동차가 선로 끝으로 사라졌다. 열차는 조용하다.", "dark")
	elif int(trip["turn"]) < int(trip["plannedTurns"]): C.journal(g, "수동차가 보이지 않는다. %d턴째. 식량 %d." % [int(trip["turn"]), floori(float(g["food"]) + 0.5)])
	elif trip["turn"] == trip["plannedTurns"]: C.journal(g, "오늘쯤 돌아올 때가 됐다. 꼬리칸이 창에 붙어 있다.", "dark")
	else: C.journal(g, "돌아올 때가 지났다. 아무도 먼저 말을 꺼내지 않는다.", "bad")

static func reapply_away(g: Dictionary) -> void:
	if g.get("stranded") != null and g["stranded"]["trip"] != null:
		var trip: Dictionary = g["stranded"]["trip"]
		g["comms"][trip["comm"]]["away"] += trip["names"].size()

static func return_trip(g: Dictionary, t: Dictionary) -> void:
	if g.get("stranded") == null or g["stranded"]["trip"] == null: return
	var trip: Dictionary = g["stranded"]["trip"]
	if bool(trip["leaderGoes"]) and not bool(trip["forced"]): C.journal(g, "열차장이 석탄을 가져왔다. 아무도 박수를 치지 않았다.", "dark")
	else: C.journal(g, "수동차가 돌아왔다. 석탄 %d을 부었다." % int(t["P"]["tripCoal"]), "good")
	resume_run(g, t)

static func resume_run(g: Dictionary, t: Dictionary) -> void:
	if g.get("stranded") == null: return
	var st: Dictionary = g["stranded"]
	g["stranded"] = null
	_flags(g)["stranded"] = false
	_flags(g)["trip_out"] = false
	if st["snow"] == "none":
		C.bump(g, "coal", -2, "stranded")
		C.journal(g, "선로에 쌓인 눈을 그대로 두었다. 쟁기가 눈을 밀며 석탄 2를 더 먹는다.", "bad")
	if int(g["seg"]) > int(t["P"]["segments"]): g["seg"] = t["P"]["segments"]

static func stranded_depart(g: Dictionary, t: Dictionary) -> void:
	if g.get("stranded") == null: return
	var st: Dictionary = g["stranded"]
	g["lostSegments"] += 1
	var order: Array = ["ev_str_half_bowl", "ev_str_lamp", "ev_str_snow", "ev_str_promise"] if float(g["food"]) <= 30 else EVENTS
	for id: String in order:
		if st["seen"].has(id): continue
		if Content.add_content_card(g, t, id, false, true):
			st["seen"].append(id)
			break
	if st["trip"] == null: C.card(g, {"kind": "trip_depart", "comm": "tail"}, t)
	g["phase"] = "travel"

static func stranded_settle(g: Dictionary, t: Dictionary) -> void:
	if g.get("stranded") == null: return
	var st: Dictionary = g["stranded"]
	st["turns"] += 1
	var flags: Dictionary = _flags(g)
	sync_flags(g, t, st)
	if flags.get("ration_down_asked", false):
		flags["ration_down_asked"] = false
		for comm: String in t["COMMS"]: g["comms"][comm]["ration"] = minf(float(g["comms"][comm]["ration"]), 1)
		C.journal(g, "솥 앞 줄이 짧아졌다. 배급 레버를 1로 내렸다.", "bad")
	if float(g["coal"]) >= 1: C.put(g, "coal", float(g["coal"]) - 1, "stranded")
	else:
		for comm: String in t["COMMS"]:
			var base: Array = g["comms"][comm]["base"]
			base[0] = minf(float(base[0]), maxf(float(t["P"]["strandedWarmFloor"]), float(base[0]) - float(t["P"]["strandedWarmDrop"])))
