extends "res://addons/gut/test.gd"
## The departure contract v2 and the return receipt v5 (s3_departure_receipt_contract.md) against
## the S1 answers in field_vectors.json "contracts": the same state makes the same contract, the
## v5 receipt is applied the same way, and the contract made again after it reads that return.

const V = preload("res://tests/politics/field_vectors.gd")
const FieldDeparture = preload("res://game/politics/field_departure.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const Receipt = preload("res://game/sim/receipt.gd")
const TrainStop = preload("res://game/train/train_stop.gd")

var _tables: Dictionary


func before_all() -> void:
	_tables = V.tables()


func _check(bad: Array[String], label: String, want: Variant, got: Variant) -> void:
	var problem := V.diff(want, got, label)
	if problem != "" and bad.size() < 40:
		bad.append(problem)


func _contracts() -> Array:
	return V.data().get("contracts", [])


func _at(row: Dictionary) -> String:
	return "%s/domestic=%s/supplies=%s" % [row["seed"], row["domestic"], row.get("supplies", false)]


func _profile(id: String) -> Dictionary:
	for p: Dictionary in _tables["PROFILES"]:
		if p["id"] == id:
			return p
	return {}


func test_one_left_in_the_field_is_on_the_left_list_and_not_sent_again() -> void:
	var row: Dictionary = _contracts()[0]
	var receipt: Dictionary = (row["receipt"] as Dictionary).duplicate(true)
	var pid: String = ""
	for id: String in receipt["people"]["sent"]:
		if not _profile(id).is_empty():
			pid = id
			break
	var who: Dictionary = _profile(pid)
	assert_true(TrainStop.crew_names(row["state"], _tables, who["community"], 99).has(who["name"]), "could go out before")
	receipt["people"]["leftBehind"] = [pid]
	receipt["crew"] = (receipt["crew"] as Array).filter(func(c: Dictionary) -> bool: return c["person"] != pid)
	var g: Dictionary = FieldReturn.apply_field_return(row["state"], _tables, row["departure"], receipt)["g"]
	assert_eq(g["left"], [who["name"]])
	assert_false(TrainStop.crew_names(g, _tables, who["community"], 99).has(who["name"]))


func test_one_left_earlier_and_rescued_alive_comes_off_the_list_and_back_into_the_count() -> void:
	var row: Dictionary = _contracts()[0]
	var receipt: Dictionary = (row["receipt"] as Dictionary).duplicate(true)
	var who: Dictionary = {}
	for p: Dictionary in _tables["PROFILES"]:
		if p["community"] == "tail" and not (receipt["people"]["sent"] as Array).has(p["id"]):
			who = p
			break
	receipt["people"]["rescued"] = [who["id"]]
	var control: Dictionary = FieldReturn.apply_field_return(row["state"], _tables, row["departure"], receipt)["g"]
	var state: Dictionary = (row["state"] as Dictionary).duplicate(true)
	state["left"] = [who["name"]]
	var g: Dictionary = FieldReturn.apply_field_return(state, _tables, row["departure"], receipt)["g"]
	assert_eq(g["left"], [])
	assert_eq(int(g["comms"]["tail"]["pop"]), int(control["comms"]["tail"]["pop"]) + 1)


## One the floor of one kept on the count when left is not added again when rescued (s1 leftShort).
func test_one_the_floor_kept_on_the_count_is_not_counted_back_when_rescued() -> void:
	var row: Dictionary = _contracts()[0]
	var receipt: Dictionary = (row["receipt"] as Dictionary).duplicate(true)
	var who: Dictionary = {}
	for p: Dictionary in _tables["PROFILES"]:
		if p["community"] == "tail" and not (receipt["people"]["sent"] as Array).has(p["id"]):
			who = p
			break
	receipt["people"]["rescued"] = [who["id"]]
	var control: Dictionary = FieldReturn.apply_field_return(row["state"], _tables, row["departure"], receipt)["g"]
	var state: Dictionary = (row["state"] as Dictionary).duplicate(true)
	state["left"] = [who["name"]]
	state["leftShort"] = {"tail": 1}
	var g: Dictionary = FieldReturn.apply_field_return(state, _tables, row["departure"], receipt)["g"]
	assert_eq(g["left"], [])
	assert_eq(int(g["comms"]["tail"]["pop"]), int(control["comms"]["tail"]["pop"]), "not added again")
	assert_false(g.has("leftShort"))


## Left and missing at once is one person: taken off the count once; a car down to one notes the rest.
func test_one_in_both_lists_is_taken_off_once_and_the_floor_notes_the_rest() -> void:
	var row: Dictionary = _contracts()[0]
	var pick: Dictionary = {}
	for person: Dictionary in row["departure"]["roster"]:
		if person["id"] != FieldDeparture.CAPTAIN_ID:
			pick = person
			break
	var comm: String = pick["comm"]
	var receipt: Dictionary = (row["receipt"] as Dictionary).duplicate(true)
	receipt["people"]["dead"] = []
	receipt["people"]["leftBehind"] = [pick["id"]]
	receipt["people"]["missing"] = [pick["id"]]
	for pop: int in [5, 1]:
		var state: Dictionary = (row["state"] as Dictionary).duplicate(true)
		state["comms"][comm]["pop"] = pop
		var result: Dictionary = FieldReturn.apply_field_return(state, _tables, row["departure"], receipt)
		assert_eq(result["status"], "applied")
		var g: Dictionary = result["g"]
		assert_eq(int(g["comms"][comm]["pop"]), maxi(1, pop - 1), "pop %d" % pop)
		if pop == 1:
			assert_eq(int(g["leftShort"][comm]), 1, "held at one by the floor")
		else:
			assert_false(g.has("leftShort"))


func test_the_fixture_has_seven_contracts() -> void:
	assert_eq(_contracts().size(), 7, "three seeds, with and without the domestic rules, and one with supplies on")


func test_the_contract_matches_s1() -> void:
	var bad: Array[String] = []
	for row: Dictionary in _contracts():
		var before := JSON.stringify(row["state"])
		_check(bad, _at(row) + " departure", row["departure"], FieldDeparture.build(row["state"], _tables, row["opts"]))
		_check(bad, _at(row) + " state unchanged", before, JSON.stringify(row["state"]))
	assert_eq(bad, [] as Array[String])


func test_a_v5_return_is_applied_as_s1_does() -> void:
	var bad: Array[String] = []
	for row: Dictionary in _contracts():
		assert_eq(Receipt.check(row["receipt"]), [] as Array[String], _at(row) + " receipt v5 passes the check")
		var applied := FieldReturn.apply_field_return(row["state"], _tables, row["departure"], row["receipt"])
		_check(bad, _at(row) + " status", row["apply"]["status"], applied["status"])
		_check(bad, _at(row) + " record", row["apply"]["record"], applied["record"])
		_check(bad, _at(row) + " after", row["apply"]["after"], applied["g"])
		_check(bad, _at(row) + " again", row["again"], FieldDeparture.build(applied["g"], _tables, row["opts"]))
	assert_eq(bad, [] as Array[String])


func test_ids_go_out_and_come_back_the_same() -> void:
	for row: Dictionary in _contracts():
		var d: Dictionary = row["departure"]
		assert_eq(d["roster"][0]["id"], FieldDeparture.CAPTAIN_ID, "the chief leads")
		var ids := {}
		for p: Dictionary in FieldDeparture.people_of(d):
			ids[p["id"]] = true
			assert_true((_tables["PROFILES"] as Array).any(func(x: Dictionary) -> bool: return x["id"] == p["id"]) or p["id"] == FieldDeparture.CAPTAIN_ID,
					"%s is someone on the train's roll" % p["id"])
		for pid: String in row["receipt"]["people"]["sent"]:
			assert_true(ids.has(pid), "%s went out under the contract" % pid)
		assert_eq(row["apply"]["record"]["sent"], row["receipt"]["people"]["sent"], "the record keeps who went")


func test_those_who_went_come_back_sore() -> void:
	for row: Dictionary in _contracts():
		var went: Array = row["receipt"]["people"]["sent"]
		for p: Dictionary in row["again"]["roster"]:
			if p["id"] == FieldDeparture.CAPTAIN_ID:
				assert_eq(int(p["sore"]), 1, "the chief was out on the last return")
			elif not went.has(p["id"]):
				assert_eq(int(p["sore"]), 0, "%s stayed on the train" % p["id"])


func test_a_receipt_with_care_or_crew_rows_is_v5() -> void:
	var r := Receipt.new("sulechow_station")
	r.set_ids("ret_a", "stop_a", "dep_a")
	r.add_wound("p_001", "arm_left", "fracture", false, {"splinted": true, "quick": true, "sutured": false})
	var d := r.to_dict()
	assert_eq(int(d["version"]), 5)
	assert_eq(d["people"]["wounds"][0]["treat"], {"splinted": true, "quick": true}, "only what was done")
	assert_eq(d["crew"], [])
	assert_eq(d["defense"], null)
	var plain := Receipt.new("sulechow_station")
	plain.add_wound("p_001", "arm_left", "fracture", false, {"splinted": true})
	assert_false((plain.to_dict()["people"]["wounds"][0] as Dictionary).has("treat"), "no care rows on a v2 receipt")


func test_the_contract_carries_the_arrival_the_route_board_shows() -> void:
	# Decision 471 B0: the train rolls the stop's arrival from its run's seed and stretch (stop_time.ts);
	# the six contracts hold S1's own answers.
	for row: Dictionary in _contracts():
		var d: Dictionary = row["departure"]
		assert_eq(int(d["arriveMin"]), TrainStop.arrival_min(String(row["state"]["seed"]), int(d["segment"])), _at(row))
	var bands: Array = [0, 0, 0, 0]
	for i in 2000:
		var m := TrainStop.arrival_min("share-%d" % i, 3)
		assert_eq(m % 10, 0)
		var k := -1
		for b: int in TrainStop.ARRIVALS.size():
			if m >= int(TrainStop.ARRIVALS[b][1]) and m <= int(TrainStop.ARRIVALS[b][2]):
				k = b
		assert_gt(k, -1, "%d is in a band" % m)
		bands[maxi(k, 0)] += 1
	for b: int in bands.size():
		assert_almost_eq(float(bands[b]) / 20.0, float(TrainStop.ARRIVALS[b][0]), 3.5, "band %d share" % b)


func test_the_decks_place_rides_from_one_stop_to_the_next() -> void:
	# Decision 474 S1: the field's decks (loot_dress.gd) keep 「exactly k of n」 across stops only if
	# where they stand rides the receipt back into the train's state and out on the next contract.
	var deck := {"food_shop": {"n": 10, "k": 7, "seen": 4, "hit": 3}, "garage_fuel": {"n": 10, "k": 3, "seen": 2, "hit": 0}}
	for row: Dictionary in _contracts():
		assert_false((row["departure"] as Dictionary).has("lootDeck"), _at(row) + " no deck before a field stop")
		var receipt: Dictionary = (row["receipt"] as Dictionary).duplicate(true)
		receipt["lootDeck"] = deck.duplicate(true)
		assert_eq(Receipt.check(receipt), [] as Array[String], _at(row) + " a v5 receipt may carry the deck")
		var applied := FieldReturn.apply_field_return(row["state"], _tables, row["departure"], receipt)
		assert_eq(applied["g"].get("lootDeck"), deck, _at(row) + " the train keeps where the decks stand")
		var again := FieldDeparture.build(applied["g"], _tables, row["opts"])
		assert_eq(again.get("lootDeck"), deck, _at(row) + " the next contract carries it")
	var bad := (_contracts()[0]["receipt"] as Dictionary).duplicate(true)
	bad["lootDeck"] = {"pan": {"n": 10, "k": 5, "seen": -1, "hit": 0}}
	assert_ne(Receipt.check(bad), [] as Array[String], "a deck row with a negative count is refused")
	bad["lootDeck"] = {"pan": {"n": 10, "k": 5}}
	assert_ne(Receipt.check(bad), [] as Array[String], "a deck row without seen and hit is refused")
	var r := Receipt.new("sulechow_station")
	r.set_ids("ret_d", "stop_d", "dep_d")
	r.set_defense(true, [], [], [])
	r.set_loot_deck(deck)
	assert_eq(r.to_dict().get("lootDeck"), deck, "the receipt writes the deck on v5")


func test_the_contract_says_whether_the_run_turned_supplies_on() -> void:
	# Decision 490: the field reads it to dress supplies or not; a contract without it is dressed as always.
	var bad: Array[String] = []
	var on: int = 0
	for row: Dictionary in _contracts():
		assert_eq((row["departure"] as Dictionary).get("supplies"), bool(row.get("supplies", false)), _at(row))
		on += 1 if bool(row.get("supplies", false)) else 0
		var g: Dictionary = (row["state"] as Dictionary).duplicate(true)
		g["supOn"] = not bool(g.get("supOn", false))
		var d := FieldDeparture.build(g, _tables, row["opts"])
		assert_eq(d.get("supplies"), g["supOn"], _at(row) + " turned the other way")
		d["supplies"] = row["departure"]["supplies"]
		_check(bad, _at(row) + " the rest as before", row["departure"], d)
	assert_eq(on, 1, "one run with supplies on")
	assert_eq(bad, [] as Array[String])


func test_route_weather_fields_match_s1_and_are_absent_with_climate_off() -> void:
	# Decision 474 N2: current S2 id, the previous three in order, no disaster in the past.
	var path: String = "res://tests/fixtures/train/route_weather.json"
	assert_true(FileAccess.file_exists(path))
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary)
	if not parsed is Dictionary:
		return
	var fixture: Dictionary = parsed
	assert_eq(fixture.get("format", ""), "route-weather-v1")
	assert_eq((fixture.get("contracts", []) as Array).size(), 162)
	var tables: Dictionary = _tables.merged(fixture["tables"], true)
	var bad: Array[String] = []
	for row: Dictionary in fixture.get("contracts", []):
		var g: Dictionary = (fixture["baseState"] as Dictionary).duplicate(true)
		for key: String in ["seed", "seg", "climate", "disasters", "disaster"]:
			if row.has(key):
				g[key] = row[key]
		if row.has("storedWeather"):
			g["stop"]["weather"] = row["storedWeather"]
		var before: String = JSON.stringify(g)
		var d: Dictionary = FieldDeparture.build(g, tables, fixture["opts"])
		var got: Dictionary = {}
		for key: String in ["stopWeather", "pastWeather"]:
			if d.has(key):
				got[key] = d[key]
		_check(bad, String(row["name"]), row["expected"], got)
		_check(bad, String(row["name"]) + " state unchanged", before, JSON.stringify(g))
	assert_eq(bad, [] as Array[String])
