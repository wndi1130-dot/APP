extends "res://addons/gut/test.gd"
## The departure contract v2 and the return receipt v5 (s3_departure_receipt_contract.md) against
## the S1 answers in field_vectors.json "contracts": the same state makes the same contract, the
## v5 receipt is applied the same way, and the contract made again after it reads that return.

const V = preload("res://tests/politics/field_vectors.gd")
const FieldDeparture = preload("res://game/politics/field_departure.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const Receipt = preload("res://game/sim/receipt.gd")

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
