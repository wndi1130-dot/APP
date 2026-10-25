extends RefCounted
## The departure contract v2 (docs/design/briefs/s3_departure_receipt_contract.md 2): the one sheet
## the train hands the field when the crew goes down at a stop, made from the train's state. A port of
## s1/src/game/field_departure.ts buildDeparture; the same state gives the same sheet
## (tests/politics/test_field_departure.gd against field_vectors.json "contracts"). Reads the state
## only and draws nothing from the run's random numbers: the body's small wobble is fixed by the
## person's id. Game keys stay S1 keys, as in the train port.

const Rng = preload("res://game/politics/rng.gd")
const TrainStop = preload("res://game/train/train_stop.gd")
const PersonMemory = preload("res://game/politics/person_memory.gd")

## The chief's one id outside the roll of names; the train's wound book keeps him by name.
const CAPTAIN_ID := "captain"
const CAPTAIN_NAME := "열차장"
const CAPTAIN_COMM := "front"
const BODY_SKILLS := ["strength", "melee", "shooting", "stealth", "search"]
## Card A (user 2026-10-25): a base by age and car, then each person's own −1·0·+1.
const CAPTAIN_BODY := {"strength": 5, "melee": 3, "shooting": 2, "stealth": 2, "search": 2}
const COMM_BODY := {"guard": {"melee": 1, "shooting": 1}, "engine": {"strength": 1}, "tail": {"search": 1}, "medtech": {"stealth": 1}, "front": {}}
## One companion a car by default, the cars of the field's own first squad.
const COMPANION_COMMS := ["guard", "medtech", "tail"]
## Nothing is held back from the stores at the start (one ledger, decision 407 C1); until the
## stores' own picking screen, each role goes out with the field's first squad's kit.
const CHIEF_GEAR := {"hands": [["axe", "factory", 0.9], ["pistol", "factory", 0.8]], "items": {"bandage": 2, "cloth": 1}, "wear": {}, "bag": "pack"}
const COMPANION_GEAR := {
	"guard": {"hands": [["pipe_shotgun", "crude", 0.9], ["knife", "factory", 0.8]], "items": {"bandage": 1}, "wear": {}, "bag": "pack"},
	"medtech": {"hands": [["bow", "factory", 0.9], ["crowbar", "factory", 0.9]], "items": {"bandage": 3, "medkit": 1, "tweezers": 1, "needle_thread": 3}, "wear": {}, "bag": "pack"},
	"tail": {"hands": [["crowbar", "factory", 0.8], ["knife", "factory", 0.7]], "items": {"bandage": 1}, "wear": {}, "bag": "big_pack"},
	"engine": {"hands": [["crowbar", "factory", 0.8], ["knife", "factory", 0.7]], "items": {"bandage": 1}, "wear": {}, "bag": "pack"},
	"front": {"hands": [["crowbar", "factory", 0.8], ["knife", "factory", 0.7]], "items": {"bandage": 1}, "wear": {}, "bag": "pack"},
}
const CARRIER_GEAR := {"hands": [], "items": {}, "wear": {}, "bag": "pack"}
const ESCORT_GEAR := [
	{"hands": [["shotgun", "factory", 0.8], ["crowbar", "factory", 0.9]], "items": {}, "wear": {}, "bag": "pack"},
	{"hands": [["axe", "factory", 0.9]], "items": {}, "wear": {}, "bag": "pack"},
]


static func _profile(t: Dictionary, id: String) -> Dictionary:
	for p: Dictionary in t["PROFILES"]:
		if p["id"] == id:
			return p
	return {}


static func _id_of_name(t: Dictionary, name: String) -> String:
	for p: Dictionary in t["PROFILES"]:
		if p["name"] == name:
			return String(p["id"])
	return ""


static func _jitter(id: String, skill: String) -> int:
	return int(floor(float(Rng.next(Rng.seed_state("%s:body:%s" % [id, skill]))[0]) * 3.0)) - 1


static func body_of(id: String, age: float, comm: String) -> Dictionary:
	if id == CAPTAIN_ID:
		return CAPTAIN_BODY.duplicate()
	var strength := 6 if age <= 25.0 else (5 if age <= 45.0 else 4)
	var out := {}
	for k: String in BODY_SKILLS:
		var base := strength if k == "strength" else 1
		out[k] = clampi(base + int((COMM_BODY[comm] as Dictionary).get(k, 0)) + _jitter(id, k), 0, 10)
	return out


## Card B: one lever below the usual ration (2) is 1, two is 2; a train gone hungry a stretch
## or more is at least 1, three or more is 2.
static func hunger_of(g: Dictionary, comm: String) -> int:
	var lever := int(g["comms"][comm]["ration"]) - 2
	var by_ration := 2 if lever <= -2 else (1 if lever <= -1 else 0)
	var segs := int(g.get("hunger", 0))
	var by_food := 2 if segs >= 3 else (1 if segs >= 1 else 0)
	return maxi(by_ration, by_food)


static func _records(g: Dictionary) -> Array:
	var r: Variant = g.get("fieldReturns")
	return (r as Dictionary).get("records", []) if r is Dictionary else []


static func _went(record: Variant, id: String) -> bool:
	return record is Dictionary and (record.get("sent", []) as Array).has(id)


## Sore: out on the last return 1, on the last two running 2.
static func sore_of(g: Dictionary, id: String) -> int:
	var recs := _records(g)
	if recs.is_empty() or not _went(recs[-1], id):
		return 0
	return 2 if recs.size() >= 2 and _went(recs[-2], id) else 1


## Rest: as sore, but up to how worn out they came back from the last return.
static func rest_of(g: Dictionary, id: String) -> int:
	var tired := 0
	var recs := _records(g)
	if not recs.is_empty():
		for row: Dictionary in (recs[-1] as Dictionary).get("crew", []):
			if row["person"] == id:
				tired = int(row["exhaustion"])
	return maxi(sore_of(g, id), tired)


static func _wounds_of(g: Dictionary, name: String) -> Array:
	var out: Array = []
	for w: Dictionary in g.get("wounds", []):
		if w["who"] == name and ["bed", "home", "light"].has(w["state"]):
			out.append({"woundId": w["id"], "part": w["part"], "grade": w["grade"], "state": w["state"], "daysLeft": w["daysLeft"], "septic": w["septic"]})
	return out


static func _know_of(g: Dictionary, name: String) -> Variant:
	var dom: Variant = g.get("dom")
	if not dom is Dictionary:
		return null
	for p: Dictionary in (dom as Dictionary).get("people", []):
		if p["name"] == name and bool(p["alive"]) and not bool(p.get("gone", false)):
			return {"field": p["field"], "skill": p["skill"]}
	return null


static func person(g: Dictionary, t: Dictionary, id: String, role: String, gear: Dictionary) -> Dictionary:
	var prof := _profile(t, id)
	var name: String = CAPTAIN_NAME if id == CAPTAIN_ID else String(prof.get("name", id))
	var comm: String = CAPTAIN_COMM if id == CAPTAIN_ID else String(prof.get("community", "tail"))
	var out := {
		"id": id, "comm": comm, "name": name, "role": role, "body": body_of(id, float(prof.get("age", 40)), comm),
		"know": _know_of(g, name), "wounds": _wounds_of(g, name), "hunger": hunger_of(g, comm), "sore": sore_of(g, id),
		"rest": rest_of(g, id), "gear": gear.duplicate(true), "rel": 0 if id == CAPTAIN_ID else g["comms"][comm]["rel"],
	}
	# The person's own memory of the chief, when they have one (person_memory.gd).
	out.merge(PersonMemory.departure_memory(g, id))
	return out


## Who may go out as a companion from car `comm` this stretch (profile ids): S1 crewNames' sieve.
static func companion_candidates(g: Dictionary, t: Dictionary, comm: String) -> Array[String]:
	var out: Array[String] = []
	for n: String in TrainStop.crew_names(g, t, comm, (t["PROFILES"] as Array).size()):
		var id := _id_of_name(t, n)
		if id != "":
			out.append(id)
	return out


## The swap promise hung on a car (kept off the next dispatch). The prologue promise needs the
## people to bring back standing in the field, so it does not go out yet.
static func promises_of(g: Dictionary, t: Dictionary) -> Array:
	var out: Array = []
	for c: String in t["COMMS"]:
		var p: Variant = g["comms"][c].get("promise")
		if p is Dictionary and p.get("kind") != "fetch" and p.get("cond") is Dictionary and p["cond"].get("kind") == "skip_dispatch":
			out.append({"id": "promise_skip_%s" % c, "kind": "skip_dispatch", "madeTo": c, "label": "다음 파견에서 제외", "subjects": []})
	return out


## The contract for the stop the train stands at. opts: placeId (the field map's), companions
## (profile ids picked; one a car in COMPANION_COMMS order when not given).
static func build(g: Dictionary, t: Dictionary, opts: Dictionary) -> Dictionary:
	var place: String = String(opts["placeId"])
	var seg := int(g["seg"])
	var taken := {}
	var carriers: Array[String] = []
	var stop: Variant = g.get("stop")
	if stop is Dictionary:
		for n: String in TrainStop.crew_names(g, t, String(stop["crewComm"]), int(stop["crewSize"])):
			var id := _id_of_name(t, n)
			if id != "":
				carriers.append(id)
				taken[id] = true
	var companions: Array[String] = []
	if opts.has("companions"):
		for id: String in opts["companions"]:
			if not taken.has(id):
				companions.append(id)
				taken[id] = true
	else:
		for c: String in COMPANION_COMMS:
			for id: String in companion_candidates(g, t, c):
				if not taken.has(id):
					companions.append(id)
					taken[id] = true
					break
	var escorts: Array[String] = []
	for id: String in companion_candidates(g, t, "guard"):
		if not taken.has(id) and escorts.size() < ESCORT_GEAR.size():
			escorts.append(id)
	var roster: Array = [person(g, t, CAPTAIN_ID, "chief", CHIEF_GEAR)]
	for id: String in companions:
		roster.append(person(g, t, id, "companion", COMPANION_GEAR[String(_profile(t, id).get("community", "tail"))]))
	var work: Array = []
	for id: String in carriers:
		work.append(person(g, t, id, "carrier", CARRIER_GEAR))
	for i: int in escorts.size():
		work.append(person(g, t, escorts[i], "escort", ESCORT_GEAR[i]))
	return {
		"version": 2, "departureId": "dep_%s_%d" % [place, seg], "stopId": "stop_%s_%d" % [place, seg], "placeId": place, "segment": seg,
		"roster": roster, "workCrew": work, "promises": promises_of(g, t), "domestic": g.get("dom") != null,
		"train": {"food": g["food"], "hungerSegs": int(g.get("hunger", 0))},
	}


## Everyone who may go out: the roster on v1, the roster and the work crew on v2.
static func people_of(departure: Dictionary) -> Array:
	var out: Array = (departure["roster"] as Array).duplicate()
	if int(departure["version"]) == 2:
		out.append_array(departure["workCrew"])
	return out
