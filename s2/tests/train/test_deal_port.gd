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
	for kind: String in ["status", "deal", "vote", "settle", "holder", "holderpick", "holderflow", "holderedge"]:
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


## The contract held to sets written here, not read back from the fixture (재점검 L6): the
## seeds and cars, each holder row's regular/emergency against its action, every flow step,
## and that the holderpick rows have the two properties they were found for, by S1's own
## scores (the row's `out`), so no S2 code judges them.
func test_fixture_contract_holds_its_fixed_sets_and_properties() -> void:
	if _data.is_empty(): return
	const SEEDS := ["deal-0", "deal-1"]
	const COMMS := ["tail", "medtech", "guard", "front", "engine"]
	const FLOW := {"1-deal": "deal", "2-vote": "cast_vote", "3-open": "open_council", "4-vote": "cast_vote", "5-open": "open_council"}
	var by_name := {}
	for row: Dictionary in _data["cases"]:
		by_name[str(row["name"])] = row
	for seed: String in SEEDS:
		for comm: String in COMMS:
			for when: String in ["regular", "emergency"]:
				var label: String = "holder/%s/%s/%s" % [seed, comm, when]
				assert_true(by_name.has(label), label)
				if by_name.has(label):
					assert_eq(bool(by_name[label]["action"].get("emergency", false)), when == "emergency", label)
		var holder: String = ""
		for step: String in FLOW:
			var label: String = "holderflow/%s/%s" % [seed, step]
			assert_true(by_name.has(label), label)
			if not by_name.has(label): continue
			var row: Dictionary = by_name[label]
			assert_eq(str(row["action"]["kind"]), FLOW[step], label)
			var after: Dictionary = row["after"]
			match step:
				"1-deal":
					holder = str(row["action"]["comm"])
					assert_eq(after.get("agendaHolder"), holder, label + ": the deal gave the agenda")
				"3-open":
					assert_eq(after["council"].get("holder"), holder, label + ": the holder picked")
					assert_true(bool(after["council"]["locked"]), label + ": locked")
					assert_eq(after.get("agendaHolder"), null, label + ": spent")
				"5-open":
					assert_false(bool(after["council"]["locked"]), label + ": the session after is free")
					assert_false(after["council"].has("holder"), label)
	var split: int = 0
	var tie: int = 0
	for row: Dictionary in _data["cases"]:
		var label: String = str(row["name"])
		if not label.begins_with("holderpick/"): continue
		var out: Dictionary = row.get("out", {})
		var without: Array = out.get("without", [])
		var with_grudge: Array = out.get("withGrudge", [])
		var idx: int = int(row["after"]["council"]["idx"])
		assert_false(without.is_empty(), label + ": S1 scores ride along")
		if without.is_empty(): continue
		assert_eq(idx, _first_best(without), label + ": S1 picked the first best without grudge")
		if label.contains("-grudge"):
			assert_ne(_first_best(with_grudge), idx, label + ": grudge would have picked another")
			split += 1
		if label.contains("-tie"):
			assert_gt(without.count(without[idx]), 1, label + ": the best score is shared")
			tie += 1
	assert_gt(split, 0, "a row where grudge splits the pick")
	assert_gt(tie, 0, "a row where the best score ties")


## The papers taken as the slice takes them (slice_flow.gd pick_first, kept here so this test
## does not load the field game): from the front, each on its first way that can be taken, a
## card no way takes put aside.
static func _take_papers(g0: Dictionary, t: Dictionary) -> Dictionary:
	var g: Dictionary = g0
	for _n: int in 50:
		if not (g.get("cards") is Array) or (g["cards"] as Array).is_empty() or g.has("_turn_port_error"): break
		var uid: int = int((g["cards"] as Array)[0]["uid"])
		var taken := false
		for i: int in 12:
			var out: Dictionary = Advance.choose_card(g, t, uid, i)
			if out.has("_turn_port_error"): break
			if not (out["cards"] as Array).any(func(c: Dictionary) -> bool: return int(c["uid"]) == uid):
				g = out
				taken = true
				break
		if not taken:
			g = g.duplicate(true)
			g["cards"] = (g["cards"] as Array).filter(func(c: Dictionary) -> bool: return int(c["uid"]) != uid)
	return g


static func _first_best(scores: Array) -> int:
	var at: int = 0
	for i: int in scores.size():
		if float(scores[i]) > float(scores[at]): at = i
	return at


## The whole way a bought agenda goes (재점검 M4), not row by row: the deal's S2 board carried
## on through the public turn — its vote, the settle, the next segments with their papers and
## stops (passed by), after_stop — to the next session, where the group picks and the agenda
## is locked to it and spent; that vote; then the session after, free.
func test_a_bought_agenda_is_spent_at_the_next_session_through_the_turn() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var flows: int = 0
	for row: Dictionary in _data["cases"]:
		var label: String = str(row["name"])
		if not (label.begins_with("holderflow/") and label.ends_with("/1-deal")): continue
		flows += 1
		var comm: String = str(row["action"]["comm"])
		var made: Dictionary = Vote.make_deal(row["before"].duplicate(true), t, comm, "open", int(row["action"]["cond"]))
		assert_true(bool(made["ok"]), label + ": the deal is made")
		var g: Dictionary = made["g"]
		assert_eq(g.get("agendaHolder"), comm, label + ": the group holds the agenda")
		var first_session: int = int(g["session"])
		var seen: Array[Dictionary] = []
		for _step: int in 600:
			if g.has("_turn_port_error") or str(g["phase"]) == "end" or seen.size() >= 2: break
			if g.get("cards") is Array and not (g["cards"] as Array).is_empty():
				g = _take_papers(g, t)
				continue
			var phase: String = str(g["phase"])
			if phase == "stop" and g.get("stop") is Dictionary and not bool(g["stop"].get("done", false)):
				g = Advance.resolve_stop(g, t, false)
				continue
			if phase == "council" and g.get("council") is Dictionary:
				var council: Dictionary = g["council"]
				if int(g["session"]) > first_session and (seen.is_empty() or int(seen[-1]["session"]) != int(g["session"])):
					seen.append({"session": int(g["session"]), "council": council.duplicate(true), "agendaHolder": g.get("agendaHolder")})
				if council.get("result") == null and not (council.get("options", []) as Array).is_empty():
					g = Advance.cast_vote(g, t)
					assert_true(g.get("council", {}).get("result") != null, "%s: session %d voted" % [label, int(g["session"])])
					continue
			g = Advance.advance(g, t)
		assert_false(g.has("_turn_port_error"), "%s: the way is ported: %s" % [label, g.get("_turn_port_error", "")])
		assert_eq(seen.size(), 2, label + ": two sessions after the deal's")
		if seen.size() < 2: continue
		var held: Dictionary = seen[0]["council"]
		assert_eq(held.get("holder"), comm, label + ": the group picked the next session's agenda")
		assert_true(bool(held["locked"]), label + ": and it is locked")
		assert_eq(seen[0]["agendaHolder"], null, label + ": the agenda is spent")
		assert_true(Advance.votable(held["options"][int(held["idx"])]), label + ": on an agenda S2 votes on")
		assert_false(bool(seen[1]["council"]["locked"]), label + ": the session after is free")
		assert_false(seen[1]["council"].has("holder"), label)
	assert_eq(flows, 2, "both seeds' flows")


## The laws and motions S2 votes on, written here (not read from council_vote.gd), so the pick
## below is judged apart from the code that makes it. A law in a fixture's options that is in
## neither list fails the test: classify it here when S2 ports or meets it.
const VOTABLE_LAWS := [
	"common_kitchen", "contribution_ration", "seed_grain", "common_heating", "heat_quota", "snow_duty",
	"child_labor", "corpse_throw", "corpse_store", "corpse_burn", "treat_all", "triage", "no_outsiders",
	"patrol", "secret_ballot", "strike_ban", "guided_voting", "evening_pot", "wall_ledger",
	"night_of_names", "emergency_ration", "seed_half", "child_pack", "triage_std",
]
const UNVOTABLE_LAWS := ["emergency_powers"]
const VOTABLE_MOTIONS := ["field_symbol", "field_promise"]


func _votable_by_hand(agenda: Dictionary, at: String) -> bool:
	if agenda.get("kind") == "motion": return VOTABLE_MOTIONS.has(agenda.get("motion"))
	if bool(agenda.get("ratify", false)): return false
	var law: String = str(agenda.get("law"))
	assert_true(VOTABLE_LAWS.has(law) or UNVOTABLE_LAWS.has(law), "%s: classify law %s here" % [at, law])
	return VOTABLE_LAWS.has(law) and not bool(agenda.get("ratify", false))


## A group that holds the agenda picks among the agendas S2 can vote on (코디 11-04 9-1, the
## boundary rule until 9-2 ports the emergency powers vote): no session is refused for its
## pick, none is locked on an agenda S2 cannot vote on, and one whose agendas S2 can vote on none
## of opens free with the agenda spent. Boards made here: every inactive law in turn waiting for
## a repeal ratification, which S2 cannot vote on.
func test_a_holder_never_locks_a_session_on_an_agenda_s2_cannot_vote() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var opened: int = 0
	var bypassed: int = 0
	for row: Dictionary in _data["cases"]:
		if not str(row["name"]).begins_with("holder/"): continue
		for law: String in t["LAWS"]:
			var g: Dictionary = row["before"].duplicate(true)
			if State.law_active(g, law): continue
			g["ratifyRepeal"] = [law]
			var bytes: PackedByteArray = var_to_bytes(g)
			var at: String = "%s %s" % [row["name"], law]
			var got: Dictionary = Advance.open_council(g, t, bool(row["action"].get("emergency", false)))
			assert_eq(var_to_bytes(g), bytes, "the input is not touched")
			assert_false(got.has("_turn_port_error"), at + ": never refused for the pick")
			if got.has("_turn_port_error"): continue
			opened += 1
			assert_eq(got.get("agendaHolder"), null, at + ": the agenda is spent")
			var council: Dictionary = got["council"]
			var options: Array = council["options"]
			var any_votable: bool = options.any(func(a: Dictionary) -> bool: return _votable_by_hand(a, at))
			if options.is_empty():
				assert_true(bool(council["locked"]), at + ": S1 locks a held session with no agenda")
			elif any_votable:
				assert_true(bool(council["locked"]), at)
				assert_true(_votable_by_hand(options[int(council["idx"])], at), at + ": picks an agenda S2 votes on")
				if not _votable_by_hand(options[0], at) and int(council["idx"]) != 0: bypassed += 1
			else:
				assert_false(bool(council["locked"]), at + ": none S2 votes on, so it opens free")
				assert_false(council.has("holder"), at)
	assert_gt(opened, 0)
	assert_gt(bypassed, 0, "a ratification first in line is passed over at least once")


## The rule against S1 itself (holderedge rows: S1's holder picks the emergency powers law, a
## repeal ratification, a share motion — none of which S2 votes on yet). S2 picks the first best
## of the agendas S2 votes on by S1's own scores (the row's `out`); the rest of the board is
## S1's, with the pick and its journal line set to that agenda.
func test_a_holder_picks_the_best_agenda_s2_can_vote_on_by_s1_scores() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var kinds := {}
	for row: Dictionary in _data["cases"]:
		var at: String = str(row["name"])
		if not at.begins_with("holderedge/"): continue
		kinds[at.get_slice("/", 1)] = true
		var out: Dictionary = row["out"]
		var scores: Array = out["without"]
		var want: Dictionary = row["after"].duplicate(true)
		var options: Array = want["council"]["options"]
		assert_false(_votable_by_hand(options[int(want["council"]["idx"])], at), at + ": S1 picked one S2 cannot vote on")
		var e: int = -1
		for i: int in options.size():
			if _votable_by_hand(options[i], at) and (e < 0 or float(scores[i]) > float(scores[e])): e = i
		assert_gt(e, -1, at + ": some agenda S2 votes on")
		if e < 0: continue
		want["council"]["idx"] = e
		var line: String = "%s이(가) 안건을 골랐다: %s." % [t["COMM_NAME"][out["holder"]], out["titles"][e]]
		var patched: bool = false
		for i: int in range((want["journal"] as Array).size() - 1, -1, -1):
			if str(want["journal"][i].get("text", "")).contains("안건을 골랐다"):
				want["journal"][i]["text"] = line
				patched = true
				break
		assert_true(patched, at + ": S1 wrote the pick's line")
		var got: Dictionary = Advance.open_council(row["before"].duplicate(true), t, false)
		assert_false(got.has("_turn_port_error"), at)
		if got.has("_turn_port_error"): continue
		var bad: Array = V.full_diffs(_snap_ledger(want), _snap_ledger(got), at, 8)
		assert_eq(bad.size(), 0, "\n".join(bad))
	for kind: String in ["powers", "ratify", "motion"]:
		assert_true(kinds.has(kind), "holderedge " + kind)


## Agendas, but none S2 votes on: the agenda is spent and the session opens free, no pick
## written (9-1). Made here: every law S2 could enact or repeal kept off this session (the
## repeal cool-off), a repeal ratification the one agenda left.
func test_a_holder_with_no_agenda_s2_votes_on_spends_it_and_opens_free() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var row: Dictionary = {}
	for r: Dictionary in _data["cases"]:
		if str(r["name"]) == "holder/deal-0/guard/regular": row = r
	assert_false(row.is_empty(), "holder/deal-0/guard/regular")
	if row.is_empty(): return
	var g: Dictionary = row["before"].duplicate(true)
	var next: int = int(g["session"]) + 1
	var ratified: String = ""
	for law: String in t["LAW_IDS"]:
		if State.law_active(g, law):
			g["passed"][law] = next
		else:
			g["repealedAt"][law] = next
			if ratified == "" and VOTABLE_LAWS.has(law): ratified = law
	g["proposals"] = []
	g["ratifyRepeal"] = [ratified]
	var lines: int = (g["journal"] as Array).size()
	var got: Dictionary = Advance.open_council(g, t, false)
	assert_false(got.has("_turn_port_error"), str(got.get("_turn_port_error", "")))
	if got.has("_turn_port_error"): return
	var council: Dictionary = got["council"]
	assert_false((council["options"] as Array).is_empty(), "the ratification is on the list")
	for a: Dictionary in council["options"]:
		assert_false(_votable_by_hand(a, "no-votable"), "only agendas S2 cannot vote on: %s" % a)
	assert_false(bool(council["locked"]), "opens free")
	assert_false(council.has("holder"))
	assert_eq(got.get("agendaHolder"), null, "the agenda is spent")
	assert_eq(int(got["session"]), next)
	for i: int in range(lines, (got["journal"] as Array).size()):
		assert_false(str(got["journal"][i].get("text", "")).contains("안건을 골랐다"), "no pick written")


## The one refusal left: a held agenda in a regular martial session (S1 drops the pick and
## filters the agendas there; S2 has neither) — the board as it was.
func test_a_holder_in_a_martial_session_is_refused_with_the_board_as_it_was() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	for r: Dictionary in _data["cases"]:
		if str(r["name"]) != "holder/deal-0/guard/regular": continue
		var g: Dictionary = r["before"].duplicate(true)
		g["dark"] = {"martial": true}
		var bytes: PackedByteArray = var_to_bytes(g)
		var got: Dictionary = Advance.open_council(g, t, false)
		assert_string_contains(str(got.get("_turn_port_error", "")), "martial")
		assert_false(str(got.get("_turn_port_error", "")).contains("F-NOT-PORTED: F-NOT-PORTED"))
		var back: Dictionary = got.duplicate(true)
		back.erase("_turn_port_error")
		assert_eq(var_to_bytes(back), bytes, "the board as it was")
		return
	fail_test("holder/deal-0/guard/regular")


func test_every_deal_case_matches_s1() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var bad: Array[String] = []
	for row: Dictionary in _data["cases"]:
		var input: Dictionary = row["before"].duplicate(true)
		var action: Dictionary = row["action"]
		var at: String = str(row["name"])
		# holderedge rows: S1 picks what S2 cannot vote on yet; held to the rule in their own test.
		if at.begins_with("holderedge/"): continue
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
