extends "res://addons/gut/test.gd"
## Deals and moved votes must shift a bloc as s1/src/game/politics.ts does. The cases come from TS
## games (s1/tools/s3_dump.ts, vectors --only=data): blocs before and after the deals of a real
## council, and single blocs before and after a moved-vote entry.

const BlocMoves = preload("res://game/politics/bloc_moves.gd")
const TABLE_PATH := "res://tests/game/fixtures/s3/calc_data.json"

var _table: Dictionary


func before_all() -> void:
	_table = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))


## JSON numbers are floats; a bloc counts seats in ints and keeps poolChance as a float.
func _bloc(raw: Dictionary) -> Dictionary:
	var out := {}
	for k: String in raw:
		out[k] = float(raw[k]) if k == "poolChance" else int(raw[k])
	return out


func test_deals_match_reference() -> void:
	var seen := {}
	var i := 0
	for case: Dictionary in _table["deals"]:
		for c: int in (case["before"] as Array).size():
			var b := _bloc(case["before"][c])
			for tool: String in case["tools"][c]:
				b = BlocMoves.apply_deal(b, tool, float(case["coh"][c]))
				seen[tool] = true
			assert_eq(b, _bloc(case["after"][c]), "deal case %d community %d %s" % [i, c, case["tools"][c]])
		i += 1
	for tool: String in ["open", "blackmail", "bribe", "favor"]:
		assert_true(seen.has(tool), "the table holds a %s deal" % tool)


func test_shifts_match_reference() -> void:
	var toward_yes := 0
	var toward_no := 0
	var i := 0
	for case: Dictionary in _table["shifts"]:
		var n := int(case["n"])
		assert_eq(BlocMoves.shift(_bloc(case["before"]), n), _bloc(case["after"]), "shift case %d n=%d" % [i, n])
		if n > 0:
			toward_yes += 1
		else:
			toward_no += 1
		i += 1
	assert_gt(toward_yes, 0)
	assert_gt(toward_no, 0)


func test_hard_no_never_moves() -> void:
	var b := {"seats": 20, "absent": 0, "yes": 2, "und": 4, "no": 14, "hard": 6, "pool": 0, "poolChance": 0.0, "score": -3, "ideo": -2}
	assert_eq(BlocMoves.apply_deal(b, "blackmail", 0.7)["no"], 6)
	assert_eq(BlocMoves.apply_deal(b, "bribe", 0.7)["no"], 6)
	assert_eq(BlocMoves.apply_deal(b, "bribe", 0.7)["pool"], 12)
	assert_eq(BlocMoves.shift(b, 99)["no"], 6)
	assert_eq(BlocMoves.shift(b, 99)["yes"], 14)
	assert_eq(BlocMoves.shift(b, -99)["no"], 20)
	assert_eq(b["no"], 14, "the bloc passed in is left alone")
