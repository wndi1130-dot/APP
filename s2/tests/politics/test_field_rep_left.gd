extends GutTest
## 사용자 답 2026-10-29: S1a representatives left in the field are succeeded by someone from their car.

const V = preload("res://tests/politics/field_vectors.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const FieldDeparture = preload("res://game/politics/field_departure.gd")
const SliceFlow = preload("res://game/slice_flow.gd")

var _tables: Dictionary


func before_all() -> void:
	_tables = V.tables()


func _case() -> Dictionary:
	return (V.data()["repLeft"] as Dictionary).duplicate(true)


func _apply(row: Dictionary) -> Dictionary:
	return FieldReturn.apply_field_return(row["state"], _tables, row["departure"], row["receipt"])


func _succession_lines(g: Dictionary) -> Array:
	return (g["journal"] as Array).filter(func(line: Dictionary) -> bool: return String(line["text"]).ends_with("대표 자리를 이었다."))


func test_left_representative_and_companion_match_s1_including_rng_and_journal() -> void:
	var row := _case()
	var before := JSON.stringify(row["state"])
	assert_false(row["state"].has("dark"))
	assert_false(row["state"].has("dom"))
	var result := _apply(row)
	assert_eq(result["status"], row["apply"]["status"])
	assert_eq(V.diff(row["apply"]["record"], result["record"]), "")
	assert_eq(V.diff(row["apply"]["after"], result["g"]), "", "full S1 state, including main RNG and usedProfiles")
	assert_eq(JSON.stringify(row["state"]), before, "the input state is preserved")
	var g: Dictionary = result["g"]
	var comm: String = row["comm"]
	var state: Dictionary = g["comms"][comm]
	var leader: Dictionary = state["leader"]
	var old: Dictionary = row["state"]["comms"][comm]["leader"]
	assert_false((row["receipt"]["people"]["sent"] as Array).has(leader["personId"]), "neither person left in the field can succeed")
	assert_eq((g["left"] as Array).size(), 2)
	assert_eq(_succession_lines(g).size(), 1, "list both people before drawing, without a second succession")
	assert_has(g["journal"], {"seg": g["seg"], "text": "%s이(가) %s 대표 자리를 이었다." % [leader["name"], _tables["COMM_NAME"][comm]], "tone": "dark"})
	assert_ne(leader["trait"], old["trait"])
	assert_ne(leader["trait"], _tables["TRAIT_BAN"].get(comm))
	assert_eq(int(leader["traitShown"]), 0)
	assert_true(int(leader["age"]) >= int(_tables["REP_AGE"][comm][0]) and int(leader["age"]) <= int(_tables["REP_AGE"][comm][1]))
	var used: Array = (row["state"]["usedProfiles"] as Array).duplicate()
	assert_false(used.has(leader["personId"]))
	used.append(leader["personId"])
	assert_eq(g["usedProfiles"], used)
	assert_false(state.has("sick"))
	assert_false(state["debt"])
	assert_null(state["promise"])
	var again := FieldReturn.apply_field_return(g, _tables, row["departure"], row["receipt"])
	assert_eq(again["status"], row["duplicate"]["status"])
	assert_eq(V.diff(row["duplicate"]["record"], again["record"]), "")
	assert_eq(V.diff(row["duplicate"]["after"], again["g"]), "", "duplicate return consumes no RNG")


func test_missing_representative_also_succeeds() -> void:
	var row := _case()
	var people: Dictionary = row["receipt"]["people"]
	people["missing"] = (people["sent"] as Array).duplicate()
	people["leftBehind"] = []
	var g: Dictionary = _apply(row)["g"]
	assert_eq(V.diff(row["apply"]["after"]["comms"][row["comm"]]["leader"], g["comms"][row["comm"]]["leader"]), "")
	assert_eq(V.diff(row["apply"]["after"]["rng"], g["rng"]), "")
	assert_eq(_succession_lines(g).size(), 1)


func test_non_representative_keeps_representatives_and_rng() -> void:
	var row := _case()
	row["receipt"]["people"]["leftBehind"] = []
	var g: Dictionary = _apply(row)["g"]
	for comm: String in _tables["COMMS"]:
		assert_eq(V.diff(row["state"]["comms"][comm]["leader"], g["comms"][comm]["leader"]), "")
	assert_eq(V.diff(row["state"]["rng"], g["rng"]), "")
	assert_eq(g["usedProfiles"], row["state"]["usedProfiles"])
	assert_eq((g["left"] as Array).size(), 1)
	assert_eq(_succession_lines(g).size(), 0)


func test_captain_left_or_missing_is_not_on_the_left_list() -> void:
	for kind: String in ["leftBehind", "missing"]:
		var row := _case()
		row["departure"]["roster"] = [{"id": FieldDeparture.CAPTAIN_ID, "comm": FieldDeparture.CAPTAIN_COMM}]
		var people: Dictionary = row["receipt"]["people"]
		people["sent"] = [FieldDeparture.CAPTAIN_ID]
		people["leftBehind"] = []
		people["missing"] = []
		people[kind] = [FieldDeparture.CAPTAIN_ID]
		var g: Dictionary = _apply(row)["g"]
		assert_eq(g.get("left", []), [])
		for comm: String in _tables["COMMS"]:
			assert_eq(V.diff(row["state"]["comms"][comm]["leader"], g["comms"][comm]["leader"]), "")
		assert_eq(V.diff(row["state"]["rng"], g["rng"]), "")
		assert_eq(_succession_lines(g).size(), 0)


func test_fallback_ignores_age_and_used_profiles_but_excludes_left_and_dead() -> void:
	var row := _case()
	var comm: String = row["comm"]
	var g0: Dictionary = row["state"]
	var sent: Array = row["receipt"]["people"]["sent"]
	var survivor: Dictionary = {}
	for profile: Dictionary in _tables["PROFILES"]:
		if profile["community"] == comm and not sent.has(profile["id"]) and int(profile["age"]) < int(_tables["REP_AGE"][comm][0]):
			survivor = profile
			break
	assert_false(survivor.is_empty())
	if survivor.is_empty():
		return
	g0["usedProfiles"] = []
	g0["left"] = []
	g0["deaths"] = []
	for profile: Dictionary in _tables["PROFILES"]:
		(g0["usedProfiles"] as Array).append(profile["id"])
		if profile["community"] != comm or sent.has(profile["id"]) or profile["id"] == survivor["id"]:
			continue
		if (g0["deaths"] as Array).is_empty():
			(g0["deaths"] as Array).append(profile["name"])
		else:
			(g0["left"] as Array).append(profile["name"])
	var g: Dictionary = _apply(row)["g"]
	assert_eq(g["comms"][comm]["leader"]["personId"], survivor["id"])
	assert_eq(g["usedProfiles"], g0["usedProfiles"], "fallback does not append an already used profile")
	assert_eq(V.diff(row["apply"]["after"]["rng"], g["rng"]), "", "one person still consumes one draw, then one trait draw")
	assert_eq(_succession_lines(g).size(), 1)


## PR #981 점검: a promise to that car due at this stop is judged against the rep who was left, then the rep is
## succeeded with no promise (S1 field_receipt.test.ts, the same order).
func test_a_promise_due_at_this_stop_is_judged_before_the_rep_is_succeeded() -> void:
	var start: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/train/slice_start.json"))
	var slice: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/train/slice_vectors.json"))
	var t: Dictionary = start["tables"]
	var g: Dictionary = SliceFlow.first_stop(start["state"], t)
	var comm: String = g["stop"]["crewComm"]
	var rep: String = g["comms"][comm]["leader"]["personId"]
	for c: String in g["comms"]:
		(g["comms"][c] as Dictionary).erase("promise")
	var other: String = ""
	for kind: String in ["coal", "food", "medicine", "luxury"]:
		if kind != g["stop"]["target"]:
			other = kind
			break
	g["comms"][comm]["promise"] = {"kind": "open", "cond": {"kind": "target", "label": "그 갈래를 노린다", "now": false, "target": other},
		"label": "그 갈래를 노린다", "due": g["seg"], "madeSession": 0}
	var departure: Dictionary = FieldDeparture.build(g, t, {"placeId": slice["placeId"]})
	if not (departure["roster"] as Array).any(func(row: Dictionary) -> bool: return row["id"] == rep):
		(departure["roster"] as Array).append({"id": rep, "comm": comm})
	var receipt: Dictionary = (slice["cases"][0]["receipt"] as Dictionary).duplicate(true)
	receipt["receiptId"] = "ret_rep_promise"
	receipt["departureId"] = departure["departureId"]
	receipt["stopId"] = departure["stopId"]
	receipt["symbol"] = null
	var sent: Array = []
	for row: Dictionary in departure["roster"]:
		sent.append(row["id"])
	receipt["people"]["sent"] = sent
	receipt["people"]["leftBehind"] = [rep]
	var broken := int(g["stats"]["promisesBroken"])
	var result: Dictionary = FieldReturn.apply_field_return(g, t, departure, receipt)
	assert_eq(result["status"], "applied")
	var after: Dictionary = result["g"]
	assert_true(bool(after["stop"]["done"]))
	assert_eq(int(after["stats"]["promisesBroken"]), broken + 1, "judged against the rep who was left")
	assert_ne(after["comms"][comm]["leader"]["personId"], rep)
	assert_null(after["comms"][comm]["promise"])
