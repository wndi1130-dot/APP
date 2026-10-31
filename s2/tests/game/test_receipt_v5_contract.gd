extends "res://addons/gut/test.gd"
## Shared v5 verdicts: S1 field_receipt_v5_contract.test.ts reads the same table.

const Receipt = preload("res://game/sim/receipt.gd")
const FIXTURES: String = "res://tests/game/fixtures/"
const TABLE_PATH: String = FIXTURES + "receipt_v5_contract_cases.json"


func _read(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Walk to the parent of the last key or array index, as in test_receipt_contract.gd.
func _parent(root_value: Variant, steps: Array) -> Variant:
	var node: Variant = root_value
	for i: int in steps.size() - 1:
		var step: Variant = steps[i]
		node = node[int(step)] if node is Array else node[step]
	return node


func _apply(base: Dictionary, case_row: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for pair: Variant in case_row["set"]:
		var set_path: Array = pair[0]
		var set_parent: Variant = _parent(out, set_path)
		var set_key: Variant = set_path[-1]
		var set_value: Variant = pair[1].duplicate(true) if (pair[1] is Array or pair[1] is Dictionary) else pair[1]
		if set_parent is Array:
			set_parent[int(set_key)] = set_value
		else:
			set_parent[set_key] = set_value
	for remove_path: Variant in case_row["remove"]:
		var remove_parent: Variant = _parent(out, remove_path)
		if remove_parent is Array:
			(remove_parent as Array).remove_at(int(remove_path[-1]))
		else:
			(remove_parent as Dictionary).erase(remove_path[-1])
	return out


func test_table_loads() -> void:
	var table: Variant = _read(TABLE_PATH)
	assert_true(table is Dictionary, TABLE_PATH)
	if not table is Dictionary:
		return
	var cases: Array = table["cases"]
	var names: Dictionary = {}
	var valid_count: int = 0
	for case_row: Dictionary in cases:
		assert_false(names.has(case_row["name"]), String(case_row["name"]))
		names[case_row["name"]] = true
		if case_row["valid"]:
			valid_count += 1
	assert_gt(valid_count, 0)
	assert_gt(cases.size() - valid_count, 0)


func test_numbers_that_are_not_finite_are_turned_down_anywhere() -> void:
	# JSON cannot carry them, so they go in by hand (S1 field_receipt_v5_contract.test.ts does the same).
	var table: Dictionary = _read(TABLE_PATH)
	var base: Dictionary = _read(FIXTURES + String(table["base"]))
	var free: Dictionary = base.duplicate(true)
	free["placeState"]["drift"] = 0.5
	assert_eq(Receipt.check(free), [] as Array[String], "a free placeState key takes a finite number")
	for value: float in [NAN, INF, -INF]:
		var bad: Dictionary = base.duplicate(true)
		bad["placeState"]["drift"] = value
		assert_eq(Receipt.check(bad), ["placeState.drift: 유한하지 않은 수"] as Array[String], str(value))
		bad = base.duplicate(true)
		bad["crew"][0]["bodyUse"]["walk"] = value
		assert_true(Receipt.check(bad).has("crew.0.bodyUse.walk: 유한하지 않은 수"), str(value))


func test_check_matches_schema_verdicts() -> void:
	var table: Dictionary = _read(TABLE_PATH)
	var base: Dictionary = _read(FIXTURES + String(table["base"]))
	var wrong: Array[String] = []
	for case_row: Dictionary in table["cases"]:
		var changed: Dictionary = _apply(base, case_row)
		if not (case_row["set"] as Array).is_empty() or not (case_row["remove"] as Array).is_empty():
			assert_ne(changed, base, String(case_row["name"]))
		var problems: Array[String] = Receipt.check(changed)
		var valid: bool = case_row["valid"]
		if problems.is_empty() != valid:
			wrong.append("%s: 표는 %s, check()는 %s %s" % [case_row["name"], "통과" if valid else "거부",
				"통과" if problems.is_empty() else "거부", problems])
	assert_eq(wrong, [] as Array[String], "\n".join(wrong))
