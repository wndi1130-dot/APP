extends "res://addons/gut/test.gd"
## Field receipt v4: shared S1 fixtures, builder parity and boundary checks.

const Receipt = preload("res://game/sim/receipt.gd")
const FIXTURES := "res://tests/game/fixtures/field_v4/"


func _read(name: String = "case1_symbol_kept.json") -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + name))
	assert_true(value is Dictionary, name)
	return value if value is Dictionary else {}


## JSON parses integral numbers as floats, including nested values.
func _norm(value: Variant) -> Variant:
	if value is int:
		return float(value)
	if value is Array:
		var list: Array = []
		for item: Variant in value:
			list.append(_norm(item))
		return list
	if value is Dictionary:
		var object: Dictionary = {}
		for key: Variant in value:
			object[key] = _norm(value[key])
		return object
	return value


func _has_problem(problems: Array[String], prefix: String) -> bool:
	for problem: String in problems:
		if problem.begins_with(prefix):
			return true
	return false


func _sample() -> Receipt:
	var receipt := Receipt.new("sulechow_station", "freight", "small_station_siding")
	receipt.set_ids("ret_sulechow_01", "stop_sulechow", "dep_sulechow_01")
	receipt.set_time("D1 10:30", "D1 13:10", 160)
	receipt.set_end("departed")
	receipt.add_stock("coal", 6)
	receipt.add_stock("food", 3)
	receipt.add_stock("symbol", 1)
	receipt.gain_item("symbol_tail_kettle")
	for id: String in ["p_151", "p_152", "p_153", "p_122"]:
		receipt.person("sent", id)
	receipt.person("injured", "p_153")
	for id: String in ["p_004", "p_005"]:
		receipt.person("rescued", id)
	receipt.set_place_state(0.4, 2)
	receipt.set_goal("coal", 4, 6)
	receipt.set_extras(0, [], 0)
	receipt.set_symbol("sym_tail_kettle", "tail", "p_152")
	receipt.see_promise("promise_prologue", "prologue", ["p_151", "p_122"], ["tail"])
	return receipt


func test_all_eight_receipt_fixtures_pass_check() -> void:
	var files: PackedStringArray = DirAccess.get_files_at(FIXTURES)
	var count: int = 0
	for name: String in files:
		if not name.ends_with(".json") or name.begins_with("departure_"):
			continue
		count += 1
		assert_eq(Receipt.check(_read(name)), [] as Array[String], name)
	assert_eq(count, 8, "출발 명세 3개를 제외한 영수증 8개")


func test_builder_matches_case1_values_and_key_order() -> void:
	var expected: Dictionary = _read()
	var receipt := _sample()
	var actual: Dictionary = receipt.to_dict()
	assert_eq(_norm(actual), _norm(expected))
	assert_eq(actual.keys(), expected.keys(), "최상위 키 순서")
	assert_eq(actual["goal"].keys(), expected["goal"].keys())
	assert_eq(actual["extras"].keys(), expected["extras"].keys())
	assert_eq(actual["symbol"].keys(), expected["symbol"].keys())
	assert_eq(actual["fieldPromises"][0].keys(), expected["fieldPromises"][0].keys())
	assert_eq(Receipt.check(actual), [] as Array[String])
	assert_eq(_norm(JSON.parse_string(receipt.to_json())), _norm(expected))


func test_v4_requires_each_new_contract_key() -> void:
	for key: String in Receipt.V3_REQUIRED + Receipt.V4_REQUIRED:
		var receipt: Dictionary = _read()
		receipt.erase(key)
		assert_true(_has_problem(Receipt.check(receipt), "%s: 없음" % key), key)


func test_v4_rejects_unknown_symbol_group() -> void:
	var receipt: Dictionary = _read()
	receipt["symbol"]["groupId"] = "unknown"
	assert_true(_has_problem(Receipt.check(receipt), "symbol.groupId"))


func test_v4_rejects_duplicate_promise_ids() -> void:
	var receipt: Dictionary = _read()
	receipt["fieldPromises"].append(receipt["fieldPromises"][0].duplicate(true))
	assert_true(_has_problem(Receipt.check(receipt), "fieldPromises.1.id"))


func test_symbol_requires_positive_stock_symbol() -> void:
	for amount: Variant in [null, 0, -1]:
		var receipt: Dictionary = _read()
		if amount == null:
			receipt["stock"].erase("symbol")
		else:
			receipt["stock"]["symbol"] = amount
		assert_true(_has_problem(Receipt.check(receipt), "stock.symbol"), str(amount))


func test_legacy_versions_reject_all_new_contract_fields() -> void:
	for version: int in [1, 2]:
		var receipt: Dictionary = _read()
		receipt["version"] = version
		var problems: Array[String] = Receipt.check(receipt)
		for key: String in Receipt.V3_REQUIRED + Receipt.V4_REQUIRED:
			assert_true(_has_problem(problems, "%s: 모르는 칸" % key), key)


func test_promise_observations_reject_bad_types_duplicates_and_verdicts() -> void:
	var changes: Array = [
		["kind", "kept"], ["witnesses", ["p_151", "p_151"]],
		["witnesses", ["BadId"]], ["witnesses", "p_151"],
		["heardBy", ["unknown"]], ["heardBy", ["tail", "tail"]],
		["heardBy", "tail"], ["kept", true], ["verdict", "broken"],
	]
	for change: Array in changes:
		var receipt: Dictionary = _read()
		receipt["fieldPromises"][0][change[0]] = change[1]
		assert_true(_has_problem(Receipt.check(receipt), "fieldPromises.0.%s" % change[0]), str(change))


func test_v3_builder_and_required_fields() -> void:
	var builder := Receipt.new("sulechow_station")
	assert_true(builder.set_time("D1 10:30", "D1 13:10", 160))
	assert_true(builder.set_ids("ret_sulechow_01", "stop_sulechow"))
	assert_true(builder.set_goal("materials", 4, 2))
	assert_true(builder.set_extras(1, ["engine", "craft", "craft"], 2))
	var receipt: Dictionary = builder.to_dict()
	assert_eq(receipt["version"], 3)
	assert_eq(receipt["goal"]["status"], "part")
	for key: String in Receipt.V4_REQUIRED:
		assert_false(receipt.has(key), key)
	assert_eq(Receipt.check(receipt), [] as Array[String])
	for key: String in Receipt.V3_REQUIRED:
		var missing: Dictionary = receipt.duplicate(true)
		missing.erase(key)
		assert_true(_has_problem(Receipt.check(missing), "%s: 없음" % key), key)
	receipt["symbol"] = null
	assert_true(_has_problem(Receipt.check(receipt), "symbol: 모르는 칸"))


func test_goal_status_matches_s1_and_updates_after_set_end() -> void:
	var builder := _sample()
	var cases: Array = [
		["coal", 4, 6, "departed", "done"], ["food", 4, 1, "limit", "part"],
		["medicine", 4, 0, "departed", "retreat"], ["materials", 4, 4, "limit", "done"],
		["coal", 0, 0, "departed", "done"], [null, 0, 0, "limit", "retreat"],
		["coal", 4, 6, "wiped", "failed"], [null, 0, 0, "wiped", "failed"],
	]
	for row: Array in cases:
		assert_true(builder.set_goal(row[0], row[1], row[2]))
		assert_true(builder.set_end(row[3]))
		var receipt: Dictionary = builder.to_dict()
		assert_eq(receipt["goal"]["status"], row[4], str(row))
		assert_eq(Receipt.check(receipt), [] as Array[String], str(row))
		receipt["goal"]["status"] = "invalid"
		assert_true(_has_problem(Receipt.check(receipt), "goal.status"), str(row))
	var no_goal: Dictionary = _read()
	no_goal["goal"] = {"kind": null, "required": 1, "earned": 0, "status": "retreat"}
	assert_true(_has_problem(Receipt.check(no_goal), "goal:"))


func test_v4_defaults_allow_no_symbol_or_seen_promises() -> void:
	var builder := Receipt.new("sulechow_station")
	builder.set_time("D1 10:30", "D1 13:10", 160)
	builder.set_ids("ret_sulechow_01", "stop_sulechow", "dep_sulechow_01")
	var receipt: Dictionary = builder.to_dict()
	assert_eq(receipt["version"], 4)
	assert_null(receipt["symbol"])
	assert_eq(receipt["fieldPromises"], [])
	assert_eq(Receipt.check(receipt), [] as Array[String])
	for bad: Variant in [[], "symbol", 1]:
		receipt["symbol"] = bad
		assert_true(_has_problem(Receipt.check(receipt), "symbol:"), str(bad))


func test_new_setters_refuse_invalid_values_without_mutating() -> void:
	var builder := _sample()
	var before: Dictionary = builder.to_dict()
	assert_false(builder.set_ids("BadId", "stop_sulechow"))
	assert_false(builder.set_ids("ret_sulechow_01", "stop_sulechow", "BadId"))
	assert_false(builder.set_goal("luxury", 1, 1))
	assert_false(builder.set_goal("coal", -1, 1))
	assert_false(builder.set_goal(null, 1, 0))
	assert_false(builder.set_extras(-1, [], 0))
	assert_false(builder.set_extras(0, ["unknown"], 0))
	assert_false(builder.set_symbol("sym_tail_kettle", "unknown", "p_152"))
	assert_false(builder.see_promise("promise_prologue", "prologue", [], []))
	assert_false(builder.see_promise("promise_new", "unknown", [], []))
	assert_false(builder.see_promise("promise_new", "prologue", ["p_151", "p_151"], []))
	assert_false(builder.see_promise("promise_new", "skip_dispatch", [], ["tail", "tail"]))
	assert_eq(builder.to_dict(), before)


func test_output_and_input_arrays_do_not_alias_builder_state() -> void:
	var builder := _sample()
	var fragments: Array = ["radio"]
	var witnesses: Array = ["p_151"]
	var heard_by: Array = ["engine"]
	assert_true(builder.set_extras(0, fragments, 0))
	assert_true(builder.see_promise("promise_skip", "skip_dispatch", witnesses, heard_by))
	fragments.clear()
	witnesses.clear()
	heard_by.clear()
	var before: Dictionary = builder.to_dict()
	assert_eq(before["extras"]["fragments"], ["radio"])
	assert_eq(before["fieldPromises"][1]["witnesses"], ["p_151"])
	assert_eq(before["fieldPromises"][1]["heardBy"], ["engine"])
	var output: Dictionary = builder.to_dict()
	output["goal"]["earned"] = 0
	output["extras"]["fragments"].clear()
	output["symbol"]["id"] = "changed"
	output["fieldPromises"][0]["witnesses"].clear()
	assert_eq(builder.to_dict(), before)
