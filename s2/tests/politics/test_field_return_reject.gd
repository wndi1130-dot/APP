extends "res://addons/gut/test.gd"

const V = preload("res://tests/politics/field_vectors.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const Receipt = preload("res://game/sim/receipt.gd")
const SliceFlow = preload("res://game/slice_flow.gd")

var _tables: Dictionary


class ReturnProbe extends SliceFlow:
	var take_calls: int = 0
	var after_return_calls: int = 0

	func _take(_g: Dictionary) -> void:
		take_calls += 1

	func _after_return(_g: Dictionary) -> void:
		after_return_calls += 1


func before_all() -> void:
	_tables = V.tables()


func _case() -> Dictionary:
	var row: Dictionary = V.cases()[0]
	return {
		"g": (row["start"] as Dictionary).duplicate(true),
		"departure": V.departure(row["departure"]).duplicate(true),
		"receipt": V.receipt(row["receipt"]).duplicate(true),
	}


func _assert_rejected(g: Dictionary, departure: Dictionary, input: Variant, expected: Array[String]) -> Dictionary:
	var before: String = JSON.stringify(g)
	var out: Dictionary = FieldReturn.apply_field_return(g, _tables, departure, input)
	assert_eq(out["status"], "rejected")
	assert_false((out["problems"] as Array).is_empty())
	assert_eq(out["problems"], expected, "existing validation messages are preserved")
	assert_eq(JSON.stringify(out["g"]), before, "returned board is unchanged")
	assert_eq(JSON.stringify(g), before, "input board is unchanged")
	return out


func test_other_receipt_id_for_same_stop_is_rejected_without_adding_stock() -> void:
	var row: Dictionary = _case()
	var receipt: Dictionary = row["receipt"]
	receipt["stock"]["coal"] = 7
	var once: Dictionary = FieldReturn.apply_field_return(row["g"], _tables, row["departure"], receipt)
	assert_eq(once["status"], "applied")
	var after: Dictionary = once["g"]
	assert_eq(float(after["coal"]), float(row["g"]["coal"]) + 7.0)
	receipt["receiptId"] = "ret_other"
	var out: Dictionary = _assert_rejected(after, row["departure"], receipt, ["이미 반영한 정차에 다른 영수증이 왔다"])
	assert_eq(out["g"]["coal"], after["coal"])
	assert_eq(JSON.stringify(out["g"]["fieldReturns"]), JSON.stringify(after["fieldReturns"]))


func test_same_receipt_id_with_changed_content_is_rejected() -> void:
	var row: Dictionary = _case()
	var receipt: Dictionary = row["receipt"]
	var once: Dictionary = FieldReturn.apply_field_return(row["g"], _tables, row["departure"], receipt)
	assert_eq(once["status"], "applied")
	receipt["stock"]["coal"] = float(receipt["stock"].get("coal", 0)) + 1.0
	_assert_rejected(once["g"], {}, receipt, ["같은 귀환 id에 다른 영수증이 왔다"])


func test_same_receipt_is_duplicate_before_departure_validation() -> void:
	var row: Dictionary = _case()
	var once: Dictionary = FieldReturn.apply_field_return(row["g"], _tables, row["departure"], row["receipt"])
	assert_eq(once["status"], "applied")
	var before: String = JSON.stringify(once["g"])
	var out: Dictionary = FieldReturn.apply_field_return(once["g"], _tables, {}, JSON.stringify(row["receipt"]))
	assert_eq(out["status"], "duplicate")
	assert_eq(JSON.stringify(out["record"]), JSON.stringify(once["record"]))
	assert_eq(JSON.stringify(out["g"]), before)
	assert_eq(JSON.stringify(once["g"]), before)


func test_non_dictionary_receipts_are_rejected() -> void:
	var row: Dictionary = _case()
	for input: Variant in [null, [], 7, "[]", "{"]:
		_assert_rejected(row["g"], row["departure"], input, ["영수증은 객체여야 한다"])


func test_version_three_receipt_is_rejected() -> void:
	var row: Dictionary = _case()
	var receipt: Dictionary = row["receipt"]
	receipt["version"] = 3
	for key: String in ["departureId", "symbol", "fieldPromises"]:
		receipt.erase(key)
	assert_eq(Receipt.check(receipt), [] as Array[String], "valid v3 still cannot return to the train")
	_assert_rejected(row["g"], row["departure"], receipt, ["필드 영수증은 판 4나 5여야 한다"])


func test_receipt_contract_problems_are_preserved() -> void:
	var row: Dictionary = _case()
	var receipt: Dictionary = row["receipt"]
	receipt.erase("stock")
	var expected: Array[String] = Receipt.check(receipt)
	assert_false(expected.is_empty())
	_assert_rejected(row["g"], {}, receipt, expected)


func test_invalid_departure_problems_are_preserved() -> void:
	var row: Dictionary = _case()
	var departure: Dictionary = row["departure"]
	departure.erase("roster")
	var expected: Array[String] = FieldReturn.check_departure(departure, _tables)
	assert_false(expected.is_empty())
	_assert_rejected(row["g"], departure, row["receipt"], expected)


func test_departure_mismatch_problems_are_preserved() -> void:
	var row: Dictionary = _case()
	var receipt: Dictionary = row["receipt"]
	receipt["departureId"] = "dep_other"
	assert_eq(Receipt.check(receipt), [] as Array[String])
	var expected: Array[String] = FieldReturn.match_departure(row["departure"], receipt)
	assert_false(expected.is_empty())
	_assert_rejected(row["g"], row["departure"], receipt, expected)


func test_departure_validation_precedes_already_applied_stop() -> void:
	var row: Dictionary = _case()
	var receipt: Dictionary = row["receipt"]
	var once: Dictionary = FieldReturn.apply_field_return(row["g"], _tables, row["departure"], receipt)
	assert_eq(once["status"], "applied")
	receipt["receiptId"] = "ret_other"
	_assert_rejected(once["g"], {}, receipt, FieldReturn.check_departure({}, _tables))
	receipt["departureId"] = "dep_other"
	_assert_rejected(once["g"], row["departure"], receipt, FieldReturn.match_departure(row["departure"], receipt))


func test_slice_rejection_preserves_board_receipt_and_result() -> void:
	var row: Dictionary = _case()
	var flow: ReturnProbe = ReturnProbe.new()
	flow.train_g = row["g"]
	flow.train_t = _tables
	flow.contract = row["departure"]
	flow.contract["segment"] = int(flow.train_g["seg"])
	flow.receipt = {"kept": true}
	flow.result = {"kept": true}
	var before: String = JSON.stringify(flow.train_g)
	var receipt_before: String = JSON.stringify(flow.receipt)
	var result_before: String = JSON.stringify(flow.result)
	var receipt: Dictionary = row["receipt"]
	receipt["departureId"] = "dep_other"
	assert_false(flow._returned(), "exercise rejection, not the already-returned guard")
	assert_false(flow._apply_return(receipt))
	assert_eq(JSON.stringify(flow.train_g), before)
	assert_eq(JSON.stringify(flow.receipt), receipt_before)
	assert_eq(JSON.stringify(flow.result), result_before)
	assert_eq(flow.take_calls, 0)
	assert_eq(flow.after_return_calls, 0)
	flow.free()
