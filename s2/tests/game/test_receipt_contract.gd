extends "res://addons/gut/test.gd"
## Receipt contract table (J07): the same mutated receipts must get the same verdict from
## Receipt.check() here and from s1/schema/receipt.schema.json in s1/tests/receipt.test.ts.
## The table lives in tests/game/fixtures/receipt_contract_cases.json; both CI workflows run on it.

const Receipt = preload("res://game/sim/receipt.gd")
const FIXTURES := "res://tests/game/fixtures/"
const TABLE_PATH := FIXTURES + "receipt_contract_cases.json"


func _read(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Walks to the parent of the last step; steps are keys or array indices (JSON numbers).
func _parent(root: Variant, path: Array) -> Variant:
	var node: Variant = root
	for i: int in path.size() - 1:
		var step: Variant = path[i]
		node = node[int(step)] if node is Array else node[step]
	return node


func _apply(base: Dictionary, c: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for pair: Variant in c["set"]:
		var path: Array = pair[0]
		var node: Variant = _parent(out, path)
		var key: Variant = path[-1]
		var value: Variant = pair[1].duplicate(true) if (pair[1] is Array or pair[1] is Dictionary) else pair[1]
		if node is Array:
			node[int(key)] = value
		else:
			node[key] = value
	for path: Variant in c["remove"]:
		var node: Variant = _parent(out, path)
		if node is Array:
			(node as Array).remove_at(int(path[-1]))
		else:
			(node as Dictionary).erase(path[-1])
	return out


func test_table_loads() -> void:
	var table: Variant = _read(TABLE_PATH)
	assert_true(table is Dictionary, TABLE_PATH)
	assert_gt((table["cases"] as Array).size(), 0)


func test_check_matches_schema_verdicts() -> void:
	var table: Dictionary = _read(TABLE_PATH)
	var base: Dictionary = _read(FIXTURES + String(table["base"]))
	var wrong: Array[String] = []
	for c: Dictionary in table["cases"]:
		var problems := Receipt.check(_apply(base, c))
		var valid: bool = c["valid"]
		if problems.is_empty() != valid:
			wrong.append("%s: 표는 %s, check()는 %s %s" % [c["name"], "통과" if valid else "거부",
				"통과" if problems.is_empty() else "거부", problems])
	assert_eq(wrong, [] as Array[String], "\n".join(wrong))
