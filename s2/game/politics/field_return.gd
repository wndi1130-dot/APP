extends RefCounted
## First field-return application for the S1a train. State-changing functions copy the supplied
## Dictionary, following the train port. Tables come from field-vectors-v1; game keys stay S1 keys.

const Receipt = preload("res://game/sim/receipt.gd")
const Rng = preload("res://game/politics/rng.gd")
const CouncilMath = preload("res://game/politics/council_math.gd")

const TrainState = preload("res://game/train/train_state.gd")
const TrainStop = preload("res://game/train/train_stop.gd")
const FieldDeparture = preload("res://game/politics/field_departure.gd")
const TrainDom = preload("res://game/train/train_dom.gd")
const TurnDeath = preload("res://game/train/turn/turn_death.gd")
const PersonMemory = preload("res://game/politics/person_memory.gd")
const CouncilLog = preload("res://game/politics/council_log.gd")
const LEDGER_MAX := 64
const FIELD_PROMISE_KINDS := ["prologue", "skip_dispatch"]
const SYMBOL_USES := ["hang_before_session", "hang_in_car"]


static func _clamp(value: float, lo: float, hi: float) -> float:
	return maxf(lo, minf(hi, value))


static func _journal(g: Dictionary, text: String, tone: Variant = null) -> void:
	var row := {"seg": g["seg"], "text": text}
	if tone != null:
		row["tone"] = tone
	(g["journal"] as Array).append(row)


static func _note(g: Dictionary, key: String, delta: float, why: String) -> void:
	if delta == 0.0:
		return
	if not g.has("ledger") or not g["ledger"] is Array:
		g["ledger"] = []
	var rows: Array = g["ledger"]
	rows.append({"k": key, "d": delta, "why": why})
	while rows.size() > LEDGER_MAX:
		rows.pop_front()


static func _bump(g: Dictionary, key: String, delta: float, why: String, floor_zero: bool = false) -> void:
	var before := float(g[key])
	var raw := before + delta
	if key == "trust" or key == "tension":
		g[key] = _clamp(raw, 0.0, 100.0)
	elif floor_zero:
		g[key] = maxf(0.0, raw)
	else:
		g[key] = raw
	_note(g, key, float(g[key]) - before, why)


static func _bump_rel(g: Dictionary, comm: String, delta: float, why: String) -> void:
	var state: Dictionary = g["comms"][comm]
	var before := float(state["rel"])
	state["rel"] = _clamp(before + delta, -100.0, 100.0)
	_note(g, "rel:%s" % comm, float(state["rel"]) - before, why)


static func _profile(t: Dictionary, person_id: String) -> Dictionary:
	for profile: Dictionary in t["PROFILES"]:
		if profile["id"] == person_id:
			return profile
	return {}


## S1 state.pick: one main-RNG draw, including a one-person pool.
static func _pick(g: Dictionary, items: Array) -> Variant:
	var draw := Rng.next(int(g["rng"]["state"]))
	g["rng"]["state"] = int(draw[1])
	return items[int(floorf(float(draw[0]) * items.size()))]


## The dark board's own draw (s1 dark/state.ts dr, dpick).
static func _dpick(g: Dictionary, items: Array) -> Variant:
	var draw := Rng.next(int(g["dark"]["rng"]["state"]))
	g["dark"]["rng"]["state"] = int(draw[1])
	return items[int(floorf(float(draw[0]) * items.size()))]


## S1a succession (사용자 답 2026-10-29). Keep drawPerson's ordered pool and fallback.
## On a dark board the new rep's trait is the dark board's draw (s1 repGone, succeedRep).
static func _succeed_rep(g: Dictionary, t: Dictionary, comm: String) -> void:
	var state: Dictionary = g["comms"][comm]
	var ages: Array = t["REP_AGE"][comm]
	var used: Array = g["usedProfiles"]
	var pool: Array = []
	var fallback: Array = []
	for profile: Dictionary in t["PROFILES"]:
		if profile["community"] != comm or TrainState.is_gone(g, profile["name"]):
			continue
		fallback.append(profile)
		if not used.has(profile["id"]) and int(profile["age"]) >= int(ages[0]) and int(profile["age"]) <= int(ages[1]):
			pool.append(profile)
	var person: Dictionary = _pick(g, pool if not pool.is_empty() else fallback)
	if not used.has(person["id"]):
		used.append(person["id"])
	var traits: Array = []
	for trait_id: String in t["TRAITS"]:
		if trait_id != t["TRAIT_BAN"].get(comm) and trait_id != state["leader"]["trait"]:
			traits.append(trait_id)
	state["leader"] = {
		"personId": person["id"], "name": person["name"], "age": person["age"],
		"trait": _dpick(g, traits) if g.get("dark") is Dictionary else _pick(g, traits), "traitShown": 0,
	}
	state.erase("sick")
	state["debt"] = false
	state["promise"] = null
	_journal(g, "%s이(가) %s 대표 자리를 이었다." % [person["name"], t["COMM_NAME"][comm]], "dark")


static func _person_of(t: Dictionary, departure: Dictionary, person_id: String) -> Dictionary:
	if person_id == FieldDeparture.CAPTAIN_ID:
		return {"name": FieldDeparture.CAPTAIN_NAME, "comm": FieldDeparture.CAPTAIN_COMM}
	var profile := _profile(t, person_id)
	if not profile.is_empty():
		return {"name": profile["name"], "comm": profile["community"]}
	for row: Dictionary in FieldDeparture.people_of(departure):
		if row["id"] == person_id:
			return {"name": person_id, "comm": row["comm"]}
	return {"name": person_id, "comm": "tail"}


static func _by_comm(t: Dictionary, departure: Dictionary, people: Array) -> Dictionary:
	var out := {}
	for person_id: String in people:
		var person := _person_of(t, departure, person_id)
		var comm: String = person["comm"]
		if not out.has(comm):
			out[comm] = []
		(out[comm] as Array).append(person["name"])
	return out


static func _law_active(g: Dictionary, law: String) -> bool:
	return (g.get("passed", {}) as Dictionary).has(law)


static func _situation(g: Dictionary, t: Dictionary, comm: String) -> Array:
	return TrainState.situation(g, t, comm)


static func snapshot(g: Dictionary, t: Dictionary) -> Dictionary:
	var rel := {}
	var pop := {}
	var warm := {}
	for comm: String in t["COMMS"]:
		rel[comm] = g["comms"][comm]["rel"]
		pop[comm] = g["comms"][comm]["pop"]
		warm[comm] = CouncilMath.round_half_up(float(_situation(g, t, comm)[0]))
	return {
		"trust": g["trust"], "tension": g["tension"], "coal": g["coal"], "food": g["food"],
		"med": g["med"], "lux": g["lux"], "symbols": g["symbols"], "injured": g["injured"],
		"rel": rel, "pop": pop, "warm": warm,
	}


static func returned_of(receipt: Dictionary) -> Array:
	var gone := {}
	for key: String in ["dead", "missing", "leftBehind"]:
		for person_id: String in receipt["people"][key]:
			gone[person_id] = true
	var seen := {}
	var out: Array = []
	for key: String in ["sent", "rescued"]:
		for person_id: String in receipt["people"][key]:
			if not seen.has(person_id) and not gone.has(person_id):
				seen[person_id] = true
				out.append(person_id)
	return out


static func judge_promises(departure: Dictionary, receipt: Dictionary) -> Array:
	var back := {}
	for person_id: String in returned_of(receipt):
		back[person_id] = true
	# Who actually went: the roster on v1, and on v2 the work crew too once called down.
	var went: Array = departure["roster"]
	if int(departure["version"]) == 2:
		went = []
		for row: Dictionary in FieldDeparture.people_of(departure):
			if (receipt["people"]["sent"] as Array).has(row["id"]):
				went.append(row)
	var out: Array = []
	for promise: Dictionary in departure["promises"]:
		var seen: Variant = null
		for row: Dictionary in receipt["fieldPromises"]:
			if row["id"] == promise["id"]:
				seen = row
				break
		var witnesses_back: Array = []
		if seen is Dictionary:
			for witness: String in seen["witnesses"]:
				if back.has(witness):
					witnesses_back.append(witness)
		var verdict := "unknown"
		if not witnesses_back.is_empty():
			if promise["kind"] == "prologue":
				verdict = "kept"
				for subject: String in promise["subjects"]:
					if not back.has(subject):
						verdict = "broken"
						break
			else:
				verdict = "kept"
				for roster: Dictionary in went:
					if roster["comm"] == promise["madeTo"]:
						verdict = "broken"
						break
		out.append({
			"id": promise["id"], "kind": promise["kind"], "madeTo": promise["madeTo"],
			"verdict": verdict, "witnessesBack": witnesses_back,
		})
	return out


static func _valid_id(value: Variant) -> bool:
	if not value is String or value.is_empty():
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z][a-z0-9_]*$")
	return regex.search(value) != null


static func check_departure(departure: Dictionary, t: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: String in ["version", "departureId", "stopId", "placeId", "segment", "roster", "promises", "domestic"]:
		if not departure.has(key):
			out.append("출발 명세에 %s 칸이 없다" % key)
	if not out.is_empty():
		return out
	var version := int(departure["version"])
	if (version != 1 and version != 2) or (version == 2 and not departure.get("workCrew") is Array) or not _valid_id(departure["departureId"]) or not _valid_id(departure["stopId"]) or not _valid_id(departure["placeId"]):
		out.append("출발 명세가 올바르지 않다")
	if not departure["segment"] is int and not departure["segment"] is float:
		out.append("출발 구간이 수가 아니다")
	elif float(departure["segment"]) != floorf(float(departure["segment"])) or int(departure["segment"]) < 0:
		out.append("출발 구간이 올바르지 않다")
	var roster_ids := {}
	for row: Dictionary in FieldDeparture.people_of(departure):
		if not _valid_id(row.get("id")) or not (t["COMMS"] as Array).has(row.get("comm")) or roster_ids.has(row.get("id")):
			out.append("출발 명단이 올바르지 않다")
			break
		roster_ids[row["id"]] = true
	var promise_ids := {}
	for promise: Dictionary in departure["promises"]:
		if not _valid_id(promise.get("id")) or not FIELD_PROMISE_KINDS.has(promise.get("kind")) or not (t["COMMS"] as Array).has(promise.get("madeTo")) or promise_ids.has(promise.get("id")):
			out.append("출발 약속이 올바르지 않다")
			break
		for subject: Variant in promise.get("subjects", []):
			if not _valid_id(subject):
				out.append("출발 약속이 올바르지 않다")
				break
		promise_ids[promise["id"]] = true
	return out


static func match_departure(departure: Dictionary, receipt: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if receipt["departureId"] != departure["departureId"] or receipt["stopId"] != departure["stopId"] or receipt["place"]["id"] != departure["placeId"]:
		out.append("출발 명세와 영수증의 정차가 다르다")
	# v1: those sent are the roster exactly; v2: the whole roster and any of the work crew called down.
	var sent := {}
	for person_id: String in receipt["people"]["sent"]:
		sent[person_id] = true
	var may := {}
	for row: Dictionary in FieldDeparture.people_of(departure):
		may[row["id"]] = true
	var same := not (int(departure["version"]) == 1 and sent.size() != (departure["roster"] as Array).size())
	for row: Dictionary in departure["roster"]:
		if not sent.has(row["id"]):
			same = false
	for person_id: String in sent:
		if not may.has(person_id):
			same = false
	if not same:
		out.append("출발 명단과 영수증의 명단이 다르다")
	var promises := {}
	for promise: Dictionary in departure["promises"]:
		promises[promise["id"]] = promise["kind"]
	if (receipt["fieldPromises"] as Array).size() != promises.size():
		out.append("출발 약속과 영수증의 약속이 다르다")
	else:
		for promise: Dictionary in receipt["fieldPromises"]:
			if not promises.has(promise["id"]) or promises[promise["id"]] != promise["kind"]:
				out.append("출발 약속과 영수증의 약속이 다르다")
				break
	if receipt["symbol"] is Dictionary and not returned_of(receipt).has(receipt["symbol"]["carriedBy"]):
		out.append("상징물을 든 사람이 열차에 오르지 않았다")
	return out


static func canonical(value: Variant) -> String:
	if value is Array:
		var parts: Array[String] = []
		for item: Variant in value:
			parts.append(canonical(item))
		return "[" + ",".join(parts) + "]"
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var parts: Array[String] = []
		for key: Variant in keys:
			parts.append(JSON.stringify(String(key)) + ":" + canonical(value[key]))
		return "{" + ",".join(parts) + "}"
	if value is float:
		assert(is_finite(value), "유한하지 않은 수량이다")
		if value == floorf(value):
			return str(int(value))
	return JSON.stringify(value)


static func _seats(g: Dictionary, t: Dictionary) -> Dictionary:
	var pops: Array = []
	for comm: String in t["COMMS"]:
		pops.append(int(g["comms"][comm]["pop"]))
	var values := CouncilMath.seats(pops)
	var out := {}
	for i: int in (t["COMMS"] as Array).size():
		out[t["COMMS"][i]] = values[i]
	return out


static func _offend(g: Dictionary, comm: String) -> void:
	var state: Dictionary = g["comms"][comm]
	state["grudge"] = mini(3, int(state["grudge"]) + 1)
	state["lastOffense"] = g["session"]


static func _voice_kept(g: Dictionary, t: Dictionary, comm: String) -> void:
	var voices := {
		"engine": ["말한 대로 왔군. 화부들한테 전하겠다.", "약속은 석탄 같은 거다. 넣은 만큼 간다."],
		"tail": ["한다고 한 걸 했네. 여기서는 그게 드문 일이야.", "뒤쪽에서도 다 봤어. 잊지 않을게."],
		"guard": ["명령이 아니라 약속이었지. 지킨 것으로 적어 둔다.", "말과 한 일이 같았다. 그거면 됐다."],
		"medtech": ["말한 날에 말한 대로였어요. 그렇게 적어 둘게요.", "지켜질 줄 몰랐어요. 다음에도 물어볼게요."],
		"front": ["계산이 맞았군요. 다음 이야기도 들어 보죠.", "약속을 값으로 치는 분이라면 우리도 그렇게 대하겠습니다."],
	}
	var any := ["한 말을 지켰다.", "이번에는 믿을 만했다.", "칸 사람들이 다 들었다. 열차장이 약속을 지켰다고."]
	if not g.has("keptVoice"):
		g["keptVoice"] = {}
	var kept: Dictionary = g["keptVoice"]
	kept[comm] = int(kept.get(comm, 0)) + 1
	var n := int(kept[comm])
	var line: String = voices[comm][n - 1] if n <= 2 else any[(n - 3) % any.size()]
	_journal(g, "%s: 「%s」" % [t["COMM_NAME"][comm], line], "deal")


static func _keep_promise(g: Dictionary, t: Dictionary, comm: String, label: String) -> void:
	var state: Dictionary = g["comms"][comm]
	state["promise"] = null
	_bump(g, "trust", 2.0, "promise")
	_bump_rel(g, comm, 5.0, "promise")
	if int(state["grudge"]) == 1:
		state["grudge"] = 0
	g["stats"]["promisesKept"] = int(g["stats"]["promisesKept"]) + 1
	# Each car's own count of promises kept to it (turn.ts keepPromise, decision 433 persuasion reads it).
	state["kept"] = int(state.get("kept", 0)) + 1
	_journal(g, "%s과(와)의 약속을 지켰다: %s." % [t["COMM_NAME"][comm], label], "good")
	_voice_kept(g, t, comm)


static func _break_promise(g: Dictionary, t: Dictionary, comm: String, label: String) -> void:
	var state: Dictionary = g["comms"][comm]
	state["promise"] = null
	var loss := -12.0 if int(_seats(g, t)[comm]) >= 30 else -8.0
	_bump(g, "trust", loss, "promise")
	_bump_rel(g, comm, -20.0, "promise")
	state["fervor"] = mini(3, int(state["fervor"]) + 1)
	_bump(g, "tension", 3.0, "promise")
	g["stats"]["promisesBroken"] = int(g["stats"]["promisesBroken"]) + 1
	state["broken"] = int(state.get("broken", 0)) + 1  # the car's own count (turn.ts breakPromise)
	_offend(g, comm)
	_journal(g, "%s과(와)의 약속을 어겼다: %s." % [t["COMM_NAME"][comm], label], "bad")
	CouncilLog.note_broken(g, t, comm)


static func _break_prologue(g: Dictionary, t: Dictionary, comm: String, label: String) -> void:
	_bump(g, "trust", float(t["PROLOGUE"]["brokenTrust"]), "promise")
	_bump_rel(g, comm, float(t["PROLOGUE"]["brokenRel"]), "promise")
	g["stats"]["promisesBroken"] = int(g["stats"]["promisesBroken"]) + 1
	g["comms"][comm]["broken"] = int(g["comms"][comm].get("broken", 0)) + 1  # field_receipt.ts breakPrologueVow
	_journal(g, "%s과(와)의 약속을 어겼다: %s." % [t["COMM_NAME"][comm], label], "bad")
	CouncilLog.note_broken(g, t, comm)


static func _active_wounds(g: Dictionary, comm: String = "") -> Array:
	var out: Array = []
	for wound: Dictionary in g.get("wounds", []):
		if ["bed", "home", "light"].has(wound["state"]) and (comm == "" or wound["comm"] == comm):
			out.append(wound)
	return out


static func _weighted_pick(rand: float, keys: Array, weights: Array) -> String:
	var total := 0.0
	for weight: float in weights:
		total += weight
	var value := rand * total
	for i: int in keys.size():
		if value < float(weights[i]):
			return keys[i]
		value -= float(weights[i])
	return keys[-1]


static func _hash_draw(state: int) -> Array:
	return Rng.next(state)


static func _hash_state(text: String) -> int:
	var state := 2166136261
	for i: int in text.length():
		state = Rng.imul(state ^ text.unicode_at(i), 16777619)
	return state


static func _crowd_septic(g: Dictionary, t: Dictionary, comm: String) -> float:
	var crowd := float(_situation(g, t, comm)[2])
	var level := 3 if crowd >= float(t["P"]["crowdFrom"][2]) else (2 if crowd >= float(t["P"]["crowdFrom"][1]) else (1 if crowd >= float(t["P"]["crowdFrom"][0]) else 0))
	return float(t["P"]["crowdSeptic"]) * float(t["P"]["crowdMult"][level])


static func _heal_cuts(g: Dictionary, t: Dictionary) -> int:
	var cuts := 0
	for law: String in (g.get("passed", {}) as Dictionary):
		var res: Dictionary = t["LAWS"][law].get("res", {})
		cuts -= int(res.get("healDays", 0))
	return cuts


## The field wound's part to the train's wound book (s3 contract 4); hands go with arms, feet with legs.
const FIELD_PART := {"head_neck": "head", "torso": "torso", "arm_left": "armL", "arm_right": "armR", "leg_left": "legL", "leg_right": "legR"}
const LIMB_PARTS := ["armL", "armR", "legL", "legR"]


static func _field_rank(w: Dictionary) -> float:
	var kind: String = w["kind"]
	if kind == "amputation":
		return 3.0
	if kind == "fracture":
		var treat: Dictionary = w.get("treat", {})
		return 0.5 if bool(treat.get("splinted", false)) and bool(treat.get("quick", false)) else 2.0
	return 1.0 if kind == "deep" or kind == "embedded" else 0.0


## One badly hurt person's record on the train (J02, body_injury 4.1·4.6; s1 field_receipt.ts
## fieldWoundOf): the heaviest of the wounds the field wrote is the grade and the part, all of
## them ride along in "field". An arm or a leg cut off in the field is an amputation, above all
## else. A fracture is a fracture, or a light wound when a medic splinted it
## at once; a fracture off the limbs counts as deep (the train's fractures are limbs). Deep and
## embedded are deep. Only scratches and cuts on one listed as badly hurt is deep (decision card C,
## user 2026-10-25); with no rows at all, the torso. Festering if any of them festers. No draws.
static func field_wound_of(rows: Array, pid: String) -> Dictionary:
	var mine: Array = []
	for w: Dictionary in rows:
		if w["person"] == pid:
			mine.append(w)
	var top: Variant = null
	for w: Dictionary in mine:
		if top == null or _field_rank(w) > _field_rank(top):
			top = w
	var part: String = String(FIELD_PART.get(top["part"], "torso")) if top is Dictionary else "torso"
	var grade := "deep"
	if top is Dictionary:
		var rank := _field_rank(top)
		grade = "amputation" if rank == 3.0 else ("fracture" if rank == 2.0 else ("light" if rank == 0.5 else "deep"))
	if (grade == "fracture" or grade == "amputation") and not LIMB_PARTS.has(part):
		grade = "deep"
	var septic := false
	var field: Array = []
	for w: Dictionary in mine:
		septic = septic or bool(w.get("festering", false))
		var row := (w as Dictionary).duplicate(true)
		row.erase("person")
		field.append(row)
	return {"grade": grade, "part": part, "septic": septic, "field": field}


## A wound the field settled, put in the book as it is (s1 wounds.ts recordFieldWound): only a deep
## wound's 3 or 4 days takes the local coin noteInjury uses (seed, stretch, record id, name).
static func _record_field_wound(g: Dictionary, t: Dictionary, who: String, comm: String, place: String, fw: Dictionary) -> void:
	if not g.has("wounds"):
		g["wounds"] = []
	var wound_id := int(g.get("nextWoundId", 1))
	var state := _hash_state("%s:wound:%d:%d:%s" % [g["seed"], int(g["seg"]), wound_id, who])
	var grade: String = fw["grade"]
	var part: String = fw["part"]
	var coin := 0.0
	if grade == "deep":
		coin = float(_hash_draw(state)[0])
	var septic: bool = fw["septic"]
	var days := 1
	if grade == "deep":
		days = 3 if coin < 0.5 else 4
	elif grade == "fracture":
		days = 6 if ["armL", "armR"].has(part) else 8
	elif grade == "amputation":
		days = 4
	var floor_days := 1 if grade == "light" else (2 if grade == "deep" or grade == "amputation" else (3 if ["armL", "armR"].has(part) else 4))
	var cuts := _heal_cuts(g, t)
	if cuts > 0:
		days = maxi(floor_days, days - cuts)
	if septic:
		days = int(ceil(days * 1.5))
	var wound_state := "light" if grade == "light" else "bed"
	if wound_state == "bed" and comm != "medtech" and not _active_wounds(g, "medtech").is_empty():
		days += 1
	var wound := {
		"id": wound_id, "who": who, "comm": comm, "grade": grade, "part": part,
		"from": "stop", "where": place, "septic": septic, "daysLeft": days, "days0": days,
		"bedDays": 0 if grade == "light" else (4 if grade == "amputation" else 2),
		"state": wound_state, "at": g["seg"],
	}
	var leader: Dictionary = g["comms"][comm]["leader"]
	if leader["name"] == who:
		wound["personId"] = leader["personId"]
	if not (fw["field"] as Array).is_empty():
		wound["field"] = (fw["field"] as Array).duplicate(true)
	g["nextWoundId"] = wound_id + 1
	(g["wounds"] as Array).append(wound)


static func _on_death(g: Dictionary, t: Dictionary, comm: String, names: Array) -> void:
	TurnDeath.on_death(g, t, comm, names)


static func _receipt_value(input: Variant) -> Dictionary:
	var value: Variant = JSON.parse_string(input) if input is String else input
	assert(value is Dictionary, "영수증은 객체여야 한다")
	var problems := Receipt.check(value)
	assert(problems.is_empty(), "필드 영수증 계약이 올바르지 않다: %s" % [problems])
	assert(int(value["version"]) == 4 or int(value["version"]) == 5, "필드 영수증은 판 4나 5여야 한다")
	return (value as Dictionary).duplicate(true)


static func apply_field_return(g0: Dictionary, t: Dictionary, departure: Dictionary, input: Variant) -> Dictionary:
	var g := g0.duplicate(true)
	var receipt := _receipt_value(input)
	var fingerprint := canonical(receipt)
	var known: Variant = null
	if g.get("fieldReturns") is Dictionary:
		known = g["fieldReturns"]["applied"].get(receipt["receiptId"])
	if known != null:
		assert(known == fingerprint, "같은 귀환 id에 다른 영수증이 왔다")
		for record: Dictionary in g["fieldReturns"]["records"]:
			if record["receiptId"] == receipt["receiptId"]:
				return {"status": "duplicate", "record": record, "g": g}
	assert(check_departure(departure, t).is_empty(), "출발 명세가 올바르지 않다")
	assert(match_departure(departure, receipt).is_empty(), "출발 명세와 영수증이 맞지 않는다")
	if g.get("fieldReturns") is Dictionary:
		for old: Dictionary in g["fieldReturns"]["records"]:
			assert(old["stopId"] != receipt["stopId"] and old["departureId"] != receipt["departureId"], "이미 반영한 정차에 다른 영수증이 왔다")
	var verdicts := judge_promises(departure, receipt)
	# S1's snapshot reads situation, which reads the wound book and so makes the empty book (wounds.ts book).
	if not g.has("wounds"):
		g["wounds"] = []
	var before := snapshot(g, t)
	var lines: Array = []
	var stock: Dictionary = receipt["stock"]
	for row: Array in [["coal", "coal"], ["food", "food"], ["medicine", "med"], ["luxury", "lux"]]:
		var delta := float(stock.get(row[0], 0))
		if delta != 0.0:
			_bump(g, row[1], delta, "field.loot", true)
	if float(stock.get("symbol", 0)) != 0.0:
		g["symbols"] = maxf(0.0, float(g["symbols"]) + float(stock["symbol"]))
	if g.get("dom") is Dictionary:
		for key: String in ["wood", "scrap", "cloth", "parts"]:
			if float(stock.get(key, 0)) != 0.0:
				g["dom"][key] = maxf(0.0, float(g["dom"].get(key, 0)) + float(stock[key]))
	# The decks' places (decision 474 S1): what the field left them at rides to the next contract.
	if int(receipt["version"]) == 5 and receipt.get("lootDeck") is Dictionary:
		g["lootDeck"] = (receipt["lootDeck"] as Dictionary).duplicate(true)
	var got: Array[String] = []
	for row: Array in [["coal", "석탄"], ["food", "식량"], ["medicine", "의약품"], ["luxury", "사치품"], ["wood", "목재"], ["scrap", "고철"], ["cloth", "천"], ["parts", "부품"]]:
		var amount := float(stock.get(row[0], 0))
		if amount != 0.0:
			got.append("%s %s%s" % [row[1], "+" if amount > 0 else "", int(amount) if amount == floorf(amount) else amount])
	if not got.is_empty():
		lines.append({"k": "stock", "text": ", ".join(got)})
	var place: String = receipt["place"]["id"]
	var dead_by_comm := _by_comm(t, departure, receipt["people"]["dead"])
	for comm: String in dead_by_comm:
		var names: Array = dead_by_comm[comm]
		_on_death(g, t, comm, names)
		lines.append({"k": "people", "comm": comm, "text": "%s %s이(가) 돌아오지 못했다(죽음)." % [t["COMM_NAME"][comm], ", ".join(names)]})
	var gone := {}
	for key: String in ["dead", "missing", "leftBehind"]:
		for person_id: String in receipt["people"][key]:
			gone[person_id] = true
	# Badly hurt: the field's own part, kind, care and festering go in as they are (J02: no new draw).
	var hurt_by := {}
	for person_id: String in receipt["people"]["injured"]:
		if not gone.has(person_id):
			var c: String = _person_of(t, departure, person_id)["comm"]
			if not hurt_by.has(c):
				hurt_by[c] = []
			(hurt_by[c] as Array).append(person_id)
	var rows: Array = receipt["people"].get("wounds", [])
	for comm: String in hurt_by:
		var names: Array = []
		for person_id: String in hurt_by[comm]:
			names.append(_person_of(t, departure, person_id)["name"])
		g["injured"] = int(g["injured"]) + names.size()
		for person_id: String in hurt_by[comm]:
			_record_field_wound(g, t, _person_of(t, departure, person_id)["name"], comm, place, field_wound_of(rows, person_id))
		lines.append({"k": "people", "comm": comm, "text": "%s %s이(가) 크게 다쳐 돌아왔다." % [t["COMM_NAME"][comm], ", ".join(names)]})
	# Bitten and back: the train's hidden-bite clock (two stretches to show or rise, decision card C).
	for person_id: String in receipt["people"]["bitten"]:
		if gone.has(person_id):
			continue
		var who: Dictionary = _person_of(t, departure, person_id)
		var hidden := false
		for b: Dictionary in g.get("hiddenBites", []):
			hidden = hidden or b["who"] == who["name"]
		if hidden:
			continue
		if not g.get("hiddenBites") is Array:
			g["hiddenBites"] = []
		(g["hiddenBites"] as Array).append({"who": who["name"], "comm": who["comm"], "at": g["seg"], "due": int(g["seg"]) + 2})
		_journal(g, "%s이(가) 물린 채 돌아왔다. 아는 사람은 수색대뿐이다." % who["name"], "dark")
		lines.append({"k": "people", "comm": who["comm"], "text": "%s %s이(가) 물린 채 돌아왔다. 2구간 안에 드러나거나 일어난다." % [t["COMM_NAME"][who["comm"]], who["name"]]})
	# One in both lists is counted once (s1 the same).
	var lost_ids: Array = []
	for person_id: String in receipt["people"]["leftBehind"]:
		if not (receipt["people"]["dead"] as Array).has(person_id) and not lost_ids.has(person_id):
			lost_ids.append(person_id)
	for person_id: String in receipt["people"]["missing"]:
		if not (receipt["people"]["dead"] as Array).has(person_id) and not lost_ids.has(person_id):
			lost_ids.append(person_id)
	var lost_by_comm := _by_comm(t, departure, lost_ids)
	for comm: String in lost_by_comm:
		var names: Array = lost_by_comm[comm]
		var had := int(g["comms"][comm]["pop"])
		g["comms"][comm]["pop"] = maxi(1, had - names.size())
		# Those the floor of one kept on the count are noted, and not added again if they are
		# rescued (the left list and the count agree; s1 leftShort).
		var short := names.size() - maxi(0, had - int(g["comms"][comm]["pop"]))
		if short > 0:
			if not g.get("leftShort") is Dictionary:
				g["leftShort"] = {}
			g["leftShort"][comm] = int(g["leftShort"].get(comm, 0)) + short
		lines.append({"k": "people", "comm": comm, "text": "%s %s이(가) 필드에 남았다." % [t["COMM_NAME"][comm], ", ".join(names)]})
		_journal(g, "%s이(가) 필드에 남았다. 열차는 그들 없이 떠났다." % ", ".join(names), "dark")
	# Left at an earlier stop and rescued alive this time: off the left list and back into the car's
	# count (as the prologue's waiting for them does; s1 field_receipt.ts rejoined).
	var rejoined: Array = []
	for person_id: String in returned_of(receipt):
		if person_id != FieldDeparture.CAPTAIN_ID and (receipt["people"]["rescued"] as Array).has(person_id) and (g.get("left", []) as Array).has(_person_of(t, departure, person_id)["name"]):
			rejoined.append(person_id)
	var rejoined_by_comm := _by_comm(t, departure, rejoined)
	for comm: String in rejoined_by_comm:
		var names: Array = rejoined_by_comm[comm]
		var still_left: Array = []
		for name: Variant in g.get("left", []):
			if not names.has(name):
				still_left.append(name)
		g["left"] = still_left
		var owed := mini(names.size(), int((g.get("leftShort", {}) as Dictionary).get(comm, 0)))
		g["comms"][comm]["pop"] = int(g["comms"][comm]["pop"]) + names.size() - owed
		if owed > 0:
			g["leftShort"][comm] = int(g["leftShort"][comm]) - owed
			if int(g["leftShort"][comm]) == 0:
				(g["leftShort"] as Dictionary).erase(comm)
			if (g["leftShort"] as Dictionary).is_empty():
				g.erase("leftShort")
		lines.append({"k": "people", "comm": comm, "text": "%s %s이(가) 살아서 다시 열차에 올랐다." % [t["COMM_NAME"][comm], ", ".join(names)]})
		_journal(g, "%s이(가) 살아서 다시 열차에 올랐다." % ", ".join(names), "good")
	for verdict: Dictionary in verdicts:
		var spec: Dictionary = {}
		for promise: Dictionary in departure["promises"]:
			if promise["id"] == verdict["id"]:
				spec = promise
				break
		if verdict["kind"] == "prologue":
			g["story"]["flags"]["depot_promise"] = verdict["verdict"]
		var comm: String = verdict["madeTo"]
		var live: Variant = g["comms"][comm].get("promise")
		var live_here := false
		if verdict["kind"] == "skip_dispatch" and live is Dictionary and live.get("kind") != "fetch" and live.get("cond") is Dictionary:
			live_here = live["cond"].get("kind") == "skip_dispatch"
		if verdict["verdict"] == "kept":
			_keep_promise(g, t, comm, spec["label"])
			if not live_here:
				g["comms"][comm]["promise"] = live
			lines.append({"k": "promise", "comm": comm, "text": "%s과(와)의 약속을 지켰다: %s. 본 사람 %d명이 돌아와 말했다." % [t["COMM_NAME"][comm], spec["label"], (verdict["witnessesBack"] as Array).size()]})
		elif verdict["verdict"] == "broken":
			if verdict["kind"] == "prologue":
				_break_prologue(g, t, comm, spec["label"])
			else:
				_break_promise(g, t, comm, spec["label"])
			if not live_here:
				g["comms"][comm]["promise"] = live
			lines.append({"k": "promise", "comm": comm, "text": "%s과(와)의 약속을 어겼다: %s. 본 사람 %d명이 돌아와 말했다." % [t["COMM_NAME"][comm], spec["label"], (verdict["witnessesBack"] as Array).size()]})
		else:
			if live_here:
				g["comms"][comm]["promise"] = null
			_journal(g, "%s: 그 약속을 본 사람이 아무도 돌아오지 못했다. 지켰는지 어겼는지 열차는 모른다." % spec["label"])
			lines.append({"k": "promise", "comm": comm, "text": "%s과(와)의 약속: 본 사람이 돌아오지 못해 알 수 없다." % t["COMM_NAME"][comm]})
	_body_searches(g, departure, receipt)
	_resident_scenes(g, departure, receipt)
	# Each person's own memory of the stop (person_memory.gd, s1 memory.ts on RETURN_HOOK).
	PersonMemory.from_return(g, t, departure, receipt, returned_of(receipt))
	# Left behind or missing: on the left list as well, so the next crew and the train's
	# is_gone see the same people as the count. After the memories have found this return's
	# kin. Exclude the captain; list everyone before drawing a successor from those still aboard.
	for person_id: String in lost_ids:
		var name: String = _person_of(t, departure, person_id)["name"]
		if person_id != FieldDeparture.CAPTAIN_ID and not TrainState.is_gone(g, name):
			if not g.get("left") is Array:
				g["left"] = []
			(g["left"] as Array).append(name)
	_close_field_stop(g, t, departure, receipt)
	# 사용자 답 2026-10-29: another person from the car succeeds a rep left behind or missing,
	# after the stop is closed: a promise to that car due at this stop is judged first (S1 same order).
	for person_id: String in lost_ids:
		if person_id == FieldDeparture.CAPTAIN_ID:
			continue
		for comm: String in t["COMMS"]:
			if g["comms"][comm]["leader"].get("personId") == person_id:
				_succeed_rep(g, t, comm)
				break
	if receipt["symbol"] is Dictionary:
		var comm: String = receipt["symbol"]["groupId"]
		lines.append({"k": "symbol", "comm": comm, "text": "%s의 상징물을 가져왔다. 쓰임을 고른다." % t["COMM_NAME"][comm]})
	var dead_names: Array = []
	for person_id: String in receipt["people"]["dead"]:
		dead_names.append(_person_of(t, departure, person_id)["name"])
	var symbol: Variant = null
	if receipt["symbol"] is Dictionary:
		symbol = receipt["symbol"].duplicate(true)
		symbol["use"] = null
	var record := {
		"receiptId": receipt["receiptId"], "departureId": receipt["departureId"], "stopId": receipt["stopId"],
		"seg": g["seg"], "verdicts": verdicts, "dead": dead_names, "symbol": symbol,
		"before": before, "after": snapshot(g, t), "lines": lines,
	}
	# Who went (the next departure's soreness reads it) and, on v5, how each came back.
	if int(departure["version"]) == 2:
		record["sent"] = (receipt["people"]["sent"] as Array).duplicate()
	if int(receipt["version"]) == 5:
		record["crew"] = (receipt["crew"] as Array).duplicate(true)
	if not g.get("fieldReturns") is Dictionary:
		g["fieldReturns"] = {"applied": {}, "records": []}
	g["fieldReturns"]["applied"][receipt["receiptId"]] = fingerprint
	(g["fieldReturns"]["records"] as Array).append(record)
	return {"status": "applied", "record": record, "g": g}


## The stop the field went out on, closed by the field's result (s1 field_receipt.ts
## closeFieldStop; s3-link card 10-26 F, taken as recommended under decision 442): only
## while the train still stands at an open stop. Nothing is rolled: the receipt's coal is
## net of the stay, and the field wrote its own finds, wounds, deaths, rescues and bites.
## What every stop does is done as a dispatch does it: the pyre, the away of who came
## back, the cars that rest, the stop's promises.
static func _close_field_stop(g: Dictionary, t: Dictionary, departure: Dictionary, receipt: Dictionary) -> void:
	var stop: Variant = g.get("stop")
	# A late receipt from a departure of an earlier stretch brings its goods and people only:
	# it neither closes the stop the train stands at now nor counts toward the aimed-at run.
	if g["phase"] != "stop" or not stop is Dictionary or bool(stop["done"]) or int(departure["segment"]) != int(g["seg"]):
		return
	# Loaded when called: train_advance.gd preloads this file.
	var adv: GDScript = load("res://game/train/train_advance.gd")
	stop["done"] = true
	adv._burn_pyre(g, t)
	var back: Array = returned_of(receipt)
	var went: Dictionary = {}
	var home: Dictionary = {}
	for person_id: String in receipt["people"]["sent"]:
		var comm: String = _person_of(t, departure, person_id)["comm"]
		went[comm] = int(went.get(comm, 0)) + 1
		if back.has(person_id):
			home[comm] = int(home.get(comm, 0)) + 1
	for comm: String in home:
		g["comms"][comm]["away"] = int(g["comms"][comm]["away"]) + TrainStop.crew_away_of(float(home[comm]), t["CREW"]["cost"], t)
	# The car that cannot rest is the one that sent the most (the first to go on a tie).
	var busy: String = ""
	for comm: String in went:
		if busy == "" or int(went[comm]) > int(went[busy]):
			busy = comm
	adv._crew_rest(g, t, busy)
	if busy != "":
		g["lastCrew"] = busy
	# 내정 훅 자리: domesticStop (escort, leaving at the stop) is the domestic side's, not called here (as in S1).
	var notes: Array = ["필드에서 돌아왔다."]
	var stock: Dictionary = receipt["stock"]
	var gains: Dictionary = {}
	for key: String in ["coal", "food", "medicine", "luxury"]:
		if float(stock.get(key, 0)) > 0:
			gains[key] = stock[key]
	var gone: Array = (receipt["people"]["dead"] as Array) + (receipt["people"]["missing"] as Array) + (receipt["people"]["leftBehind"] as Array)
	var hurt: Array = []
	for person_id: String in receipt["people"]["injured"]:
		if not gone.has(person_id):
			hurt.append(_person_of(t, departure, person_id)["name"])
	var dead: Array = []
	for person_id: String in receipt["people"]["dead"]:
		dead.append(_person_of(t, departure, person_id)["name"])
	stop["result"] = {"passed": false, "gains": gains, "notes": notes, "injured": hurt, "dead": dead}
	var place: Dictionary = t["PLACES"][0]
	for p: Dictionary in t["PLACES"]:
		if p["id"] == stop["place"]:
			place = p
			break
	var got: Array = []
	for key: String in gains:
		got.append("%s %d" % [t["LOOT_NAME"][key], int(gains[key])])  # the ledger's amounts are whole (stop_receipt.ts)
	_journal(g, "%s에 %s 머물렀다(필드 %d명). %s." % [place["name"], t["STAY"][stop["stay"]]["name"], (receipt["people"]["sent"] as Array).size(), ", ".join(got) if not got.is_empty() else "빈손"])
	adv._check_stop_promises(g, t, stop["target"], gains)
	adv._note_target(g, stop["target"])


## Bodies gone through in the field (decision 423 card 12, the same values as
## s1 field_receipt.ts BODY_SEARCH_REL): the car of one who saw it and came back
## minds it or not, once a return.
const BODY_SEARCH_REL: Dictionary = {"tail": 0.0, "medtech": -1.0, "guard": 0.0, "front": -1.0, "engine": 0.0}


## The people living at a stop (J21): one who saw their winter stores taken and came back alive makes
## their car mind it, once a return (s1 field_receipt.ts RESIDENT_ROBBED_REL, decision 439 card 3).
const RESIDENT_ROBBED_REL: Dictionary = {"tail": 0.0, "medtech": -1.0, "guard": 0.0, "front": -1.0, "engine": 0.0}


static func _resident_scenes(g: Dictionary, departure: Dictionary, receipt: Dictionary) -> void:
	var back: Array = returned_of(receipt)
	var minded: Dictionary = {}
	for row: Dictionary in receipt.get("witnessed", []):
		if String(row.get("template", "")) != "resident_robbed":
			continue
		for w: Variant in row.get("witnesses", []):
			var pid: String = String(w) if w is String else String((w as Dictionary).get("person", ""))
			if not back.has(pid):
				continue
			for r: Dictionary in FieldDeparture.people_of(departure):
				var comm: String = String(r.get("comm", ""))
				if String(r.get("id", "")) != pid or minded.has(comm):
					continue
				minded[comm] = true
				var d: float = float(RESIDENT_ROBBED_REL.get(comm, 0.0))
				if d != 0.0:
					_bump_rel(g, comm, d, "field.resident")


static func _body_searches(g: Dictionary, departure: Dictionary, receipt: Dictionary) -> void:
	var back: Array = returned_of(receipt)
	var minded: Dictionary = {}
	for row: Dictionary in receipt.get("witnessed", []):
		if String(row.get("template", "")) != "body_search":
			continue
		for w: Variant in row.get("witnesses", []):
			var pid: String = String(w) if w is String else String((w as Dictionary).get("person", ""))
			if not back.has(pid):
				continue
			for r: Dictionary in FieldDeparture.people_of(departure):
				var comm: String = String(r.get("comm", ""))
				if String(r.get("id", "")) != pid or minded.has(comm):
					continue
				minded[comm] = true
				var d: float = float(BODY_SEARCH_REL.get(comm, 0.0))
				if d != 0.0:
					_bump_rel(g, comm, d, "field.body")


static func _hang_why(g: Dictionary, comm: String) -> Variant:
	# The stores alone (train_dom.gd) do not carry the bond a hung symbol builds.
	if not TrainDom.rules_on(g):
		return "내정을 켠 판에서만 쓴다."
	if (g["dom"].get("hung", []) as Array).has(comm):
		return "이 칸에는 이미 걸려 있다."
	if int(g["symbols"]) - (g["dom"].get("hung", []) as Array).size() < 1:
		return "걸 수 있는 상징물이 없다. 이미 건 것뿐이거나 하나도 없다."
	return null


static func symbol_options(g: Dictionary, t: Dictionary, receipt_id: String) -> Array:
	var record: Variant = null
	if g.get("fieldReturns") is Dictionary:
		for row: Dictionary in g["fieldReturns"]["records"]:
			if row["receiptId"] == receipt_id:
				record = row
				break
	if not record is Dictionary or not record["symbol"] is Dictionary or record["symbol"].get("use") != null:
		return []
	var comm: String = record["symbol"]["groupId"]
	var name: String = t["COMM_NAME"][comm]
	var caught: Variant = _hang_why(g, comm)
	return [
		{
			"use": "hang_before_session", "ok": true, "why": null,
			"now": "회기 앞에 %s의 상징물을 내건다. %s과(와)의 관계가 한 번 바뀌고 안건 전망에 보인다." % [name, name],
			"later": "한 번 쓰고 끝난다. 칸에 걸어 두는 결속은 없다.",
		},
		{
			"use": "hang_in_car", "ok": caught == null, "why": caught,
			"now": "%s 칸에 걸어 둔다. 걸어 두는 동안 구간마다 그 칸 결속이 조금씩 오른다." % name,
			"later": "나중에 내리거나 잃으면 결속과 관계가 한 번 크게 깎인다. 회기 앞에 내걸 수는 없다.",
		},
	]


static func choose_symbol_use(g0: Dictionary, t: Dictionary, receipt_id: String, use: String) -> Dictionary:
	var g := g0.duplicate(true)
	if not SYMBOL_USES.has(use):
		return {"accepted": false, "g": g}
	var record: Variant = null
	for row: Dictionary in g.get("fieldReturns", {}).get("records", []):
		if row["receiptId"] == receipt_id:
			record = row
			break
	var option: Variant = null
	for row: Dictionary in symbol_options(g, t, receipt_id):
		if row["use"] == use:
			option = row
			break
	if not record is Dictionary or not record["symbol"] is Dictionary or not option is Dictionary or not bool(option["ok"]):
		return {"accepted": false, "g": g}
	var comm: String = record["symbol"]["groupId"]
	if use == "hang_in_car":
		(g["dom"]["hung"] as Array).append(comm)
		_journal(g, "%s 칸에 상징물을 걸었다. 걸어 두는 동안 결속이 조금씩 오른다." % t["COMM_NAME"][comm])
		(record["lines"] as Array).append({"k": "symbol", "comm": comm, "text": "%s 칸에 상징물을 걸었다. 구간마다 결속이 오른다." % t["COMM_NAME"][comm]})
	else:
		var delta := float(t["FIELD"]["hangRel"])
		if delta != 0.0:
			_bump_rel(g, comm, delta, "symbol")
		_journal(g, "회기 앞에 %s의 상징물을 내걸었다." % t["COMM_NAME"][comm], "deal")
		(record["lines"] as Array).append({"k": "symbol", "comm": comm, "text": "회기 앞에 %s의 상징물을 내걸었다. 관계 %s%s." % [t["COMM_NAME"][comm], "+" if delta >= 0.0 else "", int(delta) if delta == floorf(delta) else delta]})
	record["symbol"]["use"] = use
	record["after"] = snapshot(g, t)
	return {"accepted": true, "g": g}
