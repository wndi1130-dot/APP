extends GutTest

const Advance = preload("res://game/train/train_advance.gd")
const V = preload("res://tests/train/train_vectors.gd")
const PATH: String = "res://tests/fixtures/train/turn_vectors.json"

var _data: Dictionary = {}
var _bad: Array[String] = []
var _ported_bad: Array[String] = []
var _input_bad: Array[String] = []
var _count: int = 0
var _matched: int = 0
var _unsupported: int = 0


func before_all() -> void:
	if not FileAccess.file_exists(PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary: return
	_data = parsed
	var details: Array = []
	var first: Dictionary = {}
	for run: Dictionary in _data["runs"]:
		for row: Dictionary in run["steps"]:
			var input: Dictionary = row["before"].duplicate(true)
			var action: Dictionary = row["action"]
			var tables: Dictionary = _data["tables"]
			var got: Dictionary
			match str(action["kind"]):
				"advance": got = Advance.advance(input, tables)
				"resolve_stop": got = Advance.resolve_stop(input, tables, bool(action["go"]))
				"choose_card": got = Advance.choose_card(input, tables, int(action["uid"]), int(action["index"]))
				"cast_vote": got = Advance.cast_vote(input, tables)
				_: got = {"_turn_port_error": "F-BAD-FIXTURE-ACTION"}
			var at: String = "%s/%d %s:%s" % [run["seed"], int(row["step"]), input["phase"], action["kind"]]
			var differences: Array[String] = V.full_diffs(row["after"], got, at, 40)
			var input_differences: Array[String] = V.full_diffs(row["before"], input, at + " input", 40)
			_input_bad.append_array(input_differences.slice(0, maxi(0, 40 - _input_bad.size())))
			_bad.append_array(differences.slice(0, maxi(0, 40 - _bad.size())))
			var reason: String = str(got.get("_turn_port_error", ""))
			if reason != "": _unsupported += 1
			else: _ported_bad.append_array(differences.slice(0, maxi(0, 40 - _ported_bad.size())))
			if differences.is_empty(): _matched += 1
			elif first.is_empty(): first = {"seed": run["seed"], "step": row["step"], "phase": input["phase"], "action": action, "difference": differences[0], "reason": reason}
			details.append({"seed": run["seed"], "step": row["step"], "phase": input["phase"], "action": action["kind"], "matched": differences.is_empty(), "reason": reason, "firstDifference": differences[0] if not differences.is_empty() else ""})
			_count += 1
	var report: Dictionary = {"checked": _count, "matched": _matched, "unsupported": _unsupported, "firstMismatch": first, "differences": _bad, "portedDifferences": _ported_bad, "inputDifferences": _input_bad, "steps": details}
	if OS.get_environment("GUT_NO_REPORT_FILES") != "1":
		var file: FileAccess = FileAccess.open("res://.godot/turn_port_audit.json", FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t") + "\n")
	print("TURN_ADVANCE checked=%d matched=%d unsupported=%d ported_differences=%d input_differences=%d" % [_count, _matched, _unsupported, _ported_bad.size(), _input_bad.size()])


func test_fixture_contract() -> void:
	assert_false(_data.is_empty(), "whole-state fixture exists and parses")
	if _data.is_empty(): return
	assert_eq(_data.get("format"), "turn-vectors-v1")
	assert_eq(_data["seeds"], ["slice-seed-a", "train-0", "train-1", "train-2"])
	assert_gt(_count, 0, "complete before/after steps")
	for run: Dictionary in _data["runs"]:
		assert_lte((run["steps"] as Array).size(), int(_data["maxSteps"]))
		if not bool(run["ended"]): assert_eq((run["steps"] as Array).size(), int(_data["maxSteps"]))
		for i: int in (run["steps"] as Array).size():
			var row: Dictionary = run["steps"][i]
			assert_false(row["before"].has("dom") or row["before"].has("dark"), "S1a")
			if i > 0: assert_eq(V.full_diffs(run["steps"][i - 1]["after"], row["before"]), [], "reference chain is continuous")


func test_every_whole_state_step_matches_s1() -> void:
	# Deliberately fails until every ported action and every missing branch matches.
	# Never bless the unported cases as expected answers or skip them silently.
	assert_gt(_count, 0)
	assert_eq(_bad.size(), 0, "First 40 whole-state differences:\n" + "\n".join(_bad))


func test_implemented_actions_match_s1() -> void:
	assert_gt(_count - _unsupported, 0)
	assert_eq(_ported_bad.size(), 0, "\n".join(_ported_bad))


func test_actions_do_not_change_the_input() -> void:
	assert_gt(_count, 0)
	assert_eq(_input_bad.size(), 0, "\n".join(_input_bad))


func test_full_comparator_contract() -> void:
	assert_eq(V.full_diffs({"x": 1, "y": 0.5}, {"y": 0.5000005, "x": 1.0}), [])
	assert_false(V.full_diffs(1, 1.0000001).is_empty(), "integers are exact")
	assert_false(V.full_diffs({}, {"extra": null}).is_empty(), "extra keys fail")
	assert_false(V.full_diffs({"key": null}, {}).is_empty(), "missing differs from null")
	assert_false(V.full_diffs(false, 0).is_empty(), "boolean is not a number")
	assert_eq(V.full_diffs([1, 2, 3], [4, 5, 6], "", 2).size(), 2, "bounded diagnostics")
