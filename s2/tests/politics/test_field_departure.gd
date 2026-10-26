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
	return "%s/domestic=%s" % [row["seed"], row["domestic"]]


func test_the_fixture_has_six_contracts() -> void:
	assert_eq(_contracts().size(), 6, "three seeds, with and without the domestic rules")


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
