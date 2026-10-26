extends GutTest
## Every S1a law but 비상대권 (결정 426 PR 7): enacted, repealed, voted in and
## out, a settle under it, and the tail's demand after 비상식량감축법 with its
## three answers, against S1's own whole states (s1/tools/law_port_fixtures.ts).

const Advance = preload("res://game/train/train_advance.gd")
const Vote = preload("res://game/politics/council_vote.gd")
const V = preload("res://tests/train/train_vectors.gd")
const PATH: String = "res://tests/fixtures/train/law_vectors.json"

var _data: Dictionary = {}


func before_all() -> void:
	if not FileAccess.file_exists(PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary: _data = parsed


func _run(row: Dictionary) -> Dictionary:
	var input: Dictionary = row["before"].duplicate(true)
	var t: Dictionary = _data["tables"]
	var action: Dictionary = row["action"]
	match str(action["kind"]):
		"enact": return Vote.enact_law(input, t, str(action["law"]))
		"repeal": return Vote.repeal_law(input, t, str(action["law"]))
		"cast_vote": return Advance.cast_vote(input, t)
		"advance": return Advance.advance(input, t)
		"choose_card": return Advance.choose_card(input, t, int(action["uid"]), int(action["index"]))
	return {"_turn_port_error": "F-BAD-FIXTURE-ACTION"}


## Godot reads some 17-digit decimals one bit off S1's (101.69999999999999 comes
## out ...CCD where S1 has ...CCC), so a ledger delta S1 gets exact can come
## out 1e-14 off; the ledger's deltas are compared to 1e-9, the rest exactly.
func _snap_ledger(state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	for row: Dictionary in out.get("ledger", []):
		row["d"] = snappedf(float(row["d"]), 1e-9)
	return out


func test_fixture_contract() -> void:
	assert_false(_data.is_empty(), "law fixture exists and parses")
	if _data.is_empty(): return
	assert_eq(_data.get("format"), "law-vectors-v1")
	assert_eq(_data["laws"], Vote.SUPPORTED_LAWS, "the S2 council takes the S1a laws but 비상대권")
	var kinds := {}
	for row: Dictionary in _data["cases"]:
		kinds[str(row["name"]).get_slice("/", 0)] = true
		assert_false(row["before"].has("dom") or row["before"].has("dark"), "S1a")
	for kind: String in ["enact", "repeal", "vote", "vote-repeal", "settle", "card"]:
		assert_true(kinds.has(kind), kind)


func test_every_law_case_matches_s1() -> void:
	if _data.is_empty(): return
	var bad: Array[String] = []
	var count := 0
	for row: Dictionary in _data["cases"]:
		var got: Dictionary = _run(row)
		var at: String = str(row["name"])
		if got.has("_turn_port_error"):
			bad.append("%s: %s" % [at, got["_turn_port_error"]])
		else:
			bad.append_array(V.full_diffs(_snap_ledger(row["after"]), _snap_ledger(got), at, 8))
		count += 1
		if bad.size() >= 40: break
	assert_gt(count, 0)
	assert_eq(bad.size(), 0, "First differences:\n" + "\n".join(bad.slice(0, 40)))


func test_the_input_is_not_changed() -> void:
	if _data.is_empty(): return
	for row: Dictionary in _data["cases"]:
		var input: Dictionary = row["before"].duplicate(true)
		var t: Dictionary = _data["tables"]
		var action: Dictionary = row["action"]
		if action["kind"] == "enact": Vote.enact_law(input, t, str(action["law"]))
		elif action["kind"] == "repeal": Vote.repeal_law(input, t, str(action["law"]))
		else: continue
		assert_eq(V.full_diffs(row["before"], input, str(row["name"]), 4), [], str(row["name"]))
