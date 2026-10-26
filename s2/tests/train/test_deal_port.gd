extends GutTest
## The council's deals (결정 426 PR 7, persuasion 결정 433): for every car and
## tool whether it can be used and what it costs, the deal made, votes cast
## with deals in hand, and the settle that judges an open deal's promise kept
## or broken, against S1's own whole states (s1/tools/deal_port_fixtures.ts).

const Advance = preload("res://game/train/train_advance.gd")
const Vote = preload("res://game/politics/council_vote.gd")
const V = preload("res://tests/train/train_vectors.gd")
const PATH: String = "res://tests/fixtures/train/deal_vectors.json"

var _data: Dictionary = {}


func before_all() -> void:
	if not FileAccess.file_exists(PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary: _data = parsed


## As test_law_port.gd: Godot reads some 17-digit decimals one bit off S1's, so
## the ledger's deltas are compared to 1e-9 and the rest exactly.
func _snap_ledger(state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	for row: Dictionary in out.get("ledger", []):
		row["d"] = snappedf(float(row["d"]), 1e-9)
	return out


func test_fixture_contract() -> void:
	assert_false(_data.is_empty(), "deal fixture exists and parses")
	if _data.is_empty(): return
	assert_eq(_data.get("format"), "deal-vectors-v1")
	var kinds := {}
	for row: Dictionary in _data["cases"]:
		kinds[str(row["name"]).get_slice("/", 0)] = true
	for kind: String in ["status", "deal", "vote", "settle"]:
		assert_true(kinds.has(kind), kind)


func test_every_deal_case_matches_s1() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var bad: Array[String] = []
	for row: Dictionary in _data["cases"]:
		var input: Dictionary = row["before"].duplicate(true)
		var action: Dictionary = row["action"]
		var at: String = str(row["name"])
		var got: Dictionary = {}
		match str(action["kind"]):
			"status":
				bad.append_array(V.full_diffs(row["out"], Vote.tool_status(input, t, str(action["comm"]), str(action["tool"])), at + " out", 4))
				bad.append_array(V.full_diffs(row["before"], input, at + " input", 4))
				continue
			"deal":
				var r: Dictionary = Vote.make_deal(input, t, str(action["comm"]), str(action["tool"]), int(action.get("cond", 0)), str(action.get("cut", "")))
				bad.append_array(V.full_diffs(row["out"], {"ok": r["ok"], "text": r["text"]}, at + " out", 4))
				got = r["g"]
			"cast_vote": got = Advance.cast_vote(input, t)
			"advance": got = Advance.advance(input, t)
		if got.has("_turn_port_error"):
			bad.append("%s: %s" % [at, got["_turn_port_error"]])
		else:
			bad.append_array(V.full_diffs(_snap_ledger(row["after"]), _snap_ledger(got), at, 8))
		if bad.size() >= 40: break
	assert_eq(bad.size(), 0, "First differences:\n" + "\n".join(bad.slice(0, 40)))
