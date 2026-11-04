extends GutTest
## The council's deals (결정 426 PR 7, persuasion 결정 433): for every car and
## tool whether it can be used and what it costs, the deal made, votes cast
## with deals in hand, and the settle that judges an open deal's promise kept
## or broken, against S1's own whole states (s1/tools/deal_port_fixtures.ts).

const Advance = preload("res://game/train/train_advance.gd")
const Vote = preload("res://game/politics/council_vote.gd")
const V = preload("res://tests/train/train_vectors.gd")
const State = preload("res://game/train/train_state.gd")
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
	for kind: String in ["status", "deal", "vote", "settle", "holder", "holderpick", "holderflow"]:
		assert_true(kinds.has(kind), kind)
	# The agenda a group took in a deal: every seed × car × regular/emergency session.
	var holders: Array[String] = []
	for row: Dictionary in _data["cases"]:
		if str(row["name"]).begins_with("holder/"):
			holders.append(str(row["name"]))
			assert_eq(str(row["action"]["kind"]), "open_council", str(row["name"]))
	var want: Array[String] = []
	for seed: String in _data["seeds"]:
		for comm: String in _data["tables"]["COMMS"]:
			for when: String in ["regular", "emergency"]:
				want.append("holder/%s/%s/%s" % [seed, comm, when])
	holders.sort()
	want.sort()
	assert_eq(holders, want)


## A group that holds the agenda picks what it likes best; a session that cannot vote on that
## pick in S2 yet (a law or motion outside council_vote.gd SUPPORTED_*, a ratification) is
## refused before the agenda is spent or the session opened, the board as it was. S1's boards
## never pick one (s1/tools/deal_port_fixtures.ts searched), so these are made here: a law the
## group hates waiting for a repeal ratification scores high on the group's own scale.
func test_a_holder_never_locks_a_session_on_an_agenda_s2_cannot_vote() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var refused: int = 0
	var opened: int = 0
	for row: Dictionary in _data["cases"]:
		if not str(row["name"]).begins_with("holder/"): continue
		for law: String in t["LAWS"]:
			var g: Dictionary = row["before"].duplicate(true)
			if State.law_active(g, law): continue
			g["ratifyRepeal"] = [law]
			var bytes: PackedByteArray = var_to_bytes(g)
			var got: Dictionary = Advance.open_council(g, t, bool(row["action"].get("emergency", false)))
			assert_eq(var_to_bytes(g), bytes, "the input is not touched")
			if got.has("_turn_port_error"):
				refused += 1
				assert_string_contains(str(got["_turn_port_error"]), "agendaHolder")
				var back: Dictionary = got.duplicate(true)
				back.erase("_turn_port_error")
				assert_eq(var_to_bytes(back), bytes, "refused with the board as it was: %s %s" % [row["name"], law])
				continue
			opened += 1
			var council: Dictionary = got["council"]
			if (council["options"] as Array).is_empty(): continue
			assert_true(Advance.votable(council["options"][int(council["idx"])]), "%s %s picks an agenda S2 votes on" % [row["name"], law])
	assert_gt(refused, 0, "a held agenda S2 cannot vote on is refused at least once")
	assert_gt(opened, 0)


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
			"open_council": got = Advance.open_council(input, t, bool(action.get("emergency", false)))
		if got.has("_turn_port_error"):
			bad.append("%s: %s" % [at, got["_turn_port_error"]])
		else:
			bad.append_array(V.full_diffs(_snap_ledger(row["after"]), _snap_ledger(got), at, 8))
		if bad.size() >= 40: break
	assert_eq(bad.size(), 0, "First differences:\n" + "\n".join(bad.slice(0, 40)))
