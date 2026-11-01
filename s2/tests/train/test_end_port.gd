extends GutTest
## S1 answers; the caller owns the Godot/GUT execution slot.
const V = preload("res://tests/train/train_vectors.gd")
const Turn = preload("res://game/train/train_turn.gd")
const Trip = preload("res://game/train/turn/turn_stranded.gd")
const Chronicle = preload("res://game/train/train_chronicle.gd")
const End = preload("res://game/train/turn/turn_end.gd")
const Save = preload("res://game/politics/save_slot.gd")
const State = preload("res://game/train/train_state.gd")
var _data: Dictionary
var _tables: Dictionary


func before_all() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/train/end_vectors.json"))
	_tables = JSON.parse_string(FileAccess.get_file_as_string("res://game/train/slice_start.json"))["tables"]


func _same(want: Variant, got: Variant, where: String) -> void:
	assert_eq(V.diff(want, got, where), "", where)


func _unit_game(input: Dictionary) -> Dictionary:
	var g: Dictionary = input.duplicate(true)
	g["dark"] = {"unit": true}
	return g


func _answer(g: Dictionary, expected: Dictionary, where: String) -> void:
	_same(expected["means"], Chronicle.means_total(g), where + " means")
	_same(expected["layer"], Chronicle.means_layer(g), where + " layer")
	_same(expected["tone"], Chronicle.tone(g), where + " tone")
	_same(expected["toneLine"], Chronicle.tone_line(g), where + " tone words")
	_same(expected["h7"], Chronicle.h7_record(g), where + " H7")
	var keys: Array = Chronicle.h7_record(g).keys()
	var wanted: Array = expected["h7"].keys()
	keys.sort()
	wanted.sort()
	assert_eq(keys, wanted, where + " exact H7 keys")
	var before_rng: Dictionary = g["rng"].duplicate(true)
	var size_before: int = (g["journal"] as Array).size()
	var closed: Dictionary = Chronicle.close_chronicle(g, _tables)
	_same(expected["wall"], closed["wall"], where + " wall data")
	var lines: Array = []
	for row: Dictionary in closed["wall"]: lines.append(Chronicle.wall_line(row))
	_same(expected["wallLines"], lines, where + " wall words")
	assert_eq(g["journal"][-1]["text"], expected["closeLine"], where + " closing journal")
	assert_eq(g["journal"].size(), size_before + 1)
	var first_close: Dictionary = g.duplicate(true)
	Chronicle.close_chronicle(g, _tables)
	assert_eq(V.full_diffs(first_close, g), [], where + " close once")
	assert_eq(g["rng"], before_rng, where + " no RNG consumption")
	assert_true(Chronicle.enabled(g), where + " isolated active chronicle input")
	var loaded: Dictionary = Save.read_save(JSON.parse_string(JSON.stringify(g)), _tables)
	assert_true(loaded["ok"], where + " record save/load")
	if loaded["ok"]:
		_same(g["endChronicle"], loaded["g"]["endChronicle"], where + " saved record")
		assert_eq(Chronicle.tone_line(loaded["g"]), expected["toneLine"])
	_same(g["endChronicle"], State.to_rules(g, _tables)["train"]["endChronicle"], where + " registered key")


func test_seeded_end_transitions_and_full_run_end_states() -> void:
	assert_eq(_data["format"], "end-vectors-v2")
	assert_eq(_data["loco"], "c3")
	assert_false(_data["darkGameplay"])
	var seen: Dictionary = {}
	var stopped_revolt := false
	for row: Dictionary in _data["cases"]:
		var g: Dictionary = row["before"].duplicate(true)
		match String(row["action"]["kind"]):
			"check_end": g = Turn.check_end(g, _tables)
			"trip_tick": Trip.trip_tick(g, _tables)
			"ended": pass
			_: fail_test("unknown action")
		assert_eq(V.full_diffs(row["after"], g, row["id"], 10), [], row["id"] + " original end rules")
		assert_eq(g["phase"], "end")
		assert_eq(g["end"], row["after"]["end"])
		seen[g["end"]] = true
		if g.get("stranded") != null and g["end"] == "revolt": stopped_revolt = true
		_same(row["lookback"], Turn.lookback_lines(g, _tables), row["id"] + " lookback")
		var reason: String = Turn.end_text(g, g["end"])
		if row["reason"] != "": assert_eq(reason, row["reason"])
		assert_false(Chronicle.enabled(g), row["id"] + " dark gameplay stays off")
		assert_eq(Chronicle.tone_line(g), "")
		assert_false(g.has("endChronicle"))
		assert_false((g["journal"] as Array).any(func(line: Dictionary) -> bool: return String(line["text"]).begins_with("기록: 징후")))
		var before_draw: Dictionary = g.duplicate(true)
		for draw: int in 2:
			_same(row["panelLines"], End.panel_lines(g, _tables, reason), row["id"] + " panel %d" % draw)
			assert_eq(V.full_diffs(before_draw, g), [], row["id"] + " rendering is read-only")
		assert_eq(Chronicle.close_chronicle(g, _tables), {})
		assert_eq(V.full_diffs(before_draw, g), [], row["id"] + " disabled close is a no-op")
		var loaded: Dictionary = Save.read_save(JSON.parse_string(JSON.stringify(g)), _tables)
		assert_true(loaded["ok"], row["id"] + " save/load")
		if loaded["ok"]:
			var loaded_before: Dictionary = loaded["g"].duplicate(true)
			_same(row["panelLines"], End.panel_lines(loaded["g"], _tables, reason), row["id"] + " restored panel")
			_same(row["lookback"], Turn.lookback_lines(loaded["g"], _tables), row["id"] + " restored lookback")
			assert_eq(V.full_diffs(loaded_before, loaded["g"]), [], "restored rendering is read-only")
	for end: String in ["ousted", "revolt", "lost_captain"]: assert_true(seen.has(end), end)
	assert_true(stopped_revolt, "the stopped train's revolt is mandatory")


func test_means_thresholds_saved_boundary_and_all_tones() -> void:
	var seen: Dictionary = {}
	for row: Dictionary in _data["math"]:
		var g: Dictionary = _unit_game(row["input"])
		for key: String in row["operations"]: Chronicle.cross(g, key)
		_same(row["expectedState"], Chronicle.state(g), row["id"] + " ordered crossings")
		_answer(g, row["expected"], row["id"])
		seen[Chronicle.tone(g)] = true
	assert_eq(seen.size(), 6)
	var boundary: Dictionary = _data["math"][0]["input"].duplicate(true)
	boundary["deaths"] = ["1", "2", "3", "4", "5", "6"]
	assert_true(Chronicle.saved(boundary))
	boundary["deaths"].append("7")
	assert_false(Chronicle.saved(boundary))


func test_h7_peers_upper_median_and_decimal_rounding() -> void:
	var row: Dictionary = _data["h7"]
	var g: Dictionary = _unit_game(row["input"])
	for pick: Dictionary in row["picks"]: Chronicle.log_pick(g, pick)
	_answer(g, row["expected"], "H7 peers")
	for sample: Dictionary in _data["rounding"]:
		_same(sample["expected"], Chronicle._fixed2(sample["value"]), str(sample["value"]))


func test_card_pick_and_invalid_input() -> void:
	var row: Dictionary = _data["card"]
	var g: Dictionary = _unit_game(row["input"])
	for ms: float in [0.0, -1.0, INF, NAN]:
		Chronicle.log_card_pick(g, _tables, int(row["uid"]), int(row["index"]), ms)
	assert_false(g.has("endChronicle"))
	Chronicle.log_card_pick(g, _tables, -1, 0, 1200)
	Chronicle.log_card_pick(g, _tables, int(row["uid"]), -1, 1200)
	assert_false(g.has("endChronicle"))
	Chronicle.log_card_pick(g, _tables, int(row["uid"]), int(row["index"]), float(row["ms"]))
	_same(row["expected"], g["endChronicle"]["h7"], "S1 logCardPick")
	assert_eq(Chronicle._utf16_length("한😀"), 3)
	var before: Dictionary = g.duplicate(true)
	Chronicle._log_card_view_pick(g, "closed", {"body": "", "choices": [{"label": "닫힘", "disabled": "닫힘"}]}, 0, 1000)
	assert_eq(V.full_diffs(before, g), [], "disabled choices are not logged")


func test_stopped_train_does_not_close_a_chronicle() -> void:
	var g: Dictionary = _data["cases"][2]["before"].duplicate(true)
	var before: Dictionary = g.duplicate(true)
	assert_eq(End.panel_lines(g, _tables, Turn.END_TEXT["stranded"]), [Turn.END_TEXT["stranded"]])
	assert_eq(V.full_diffs(before, g), [])


func test_disabled_dark_preserves_absent_and_existing_records() -> void:
	for dark: Variant in [null, false]:
		for existing: bool in [false, true]:
			var g: Dictionary = _data["cases"][0]["after"].duplicate(true)
			g["dark"] = dark
			if existing: g["endChronicle"] = {"closed": true, "toneLine": "old record"}
			var before: Dictionary = g.duplicate(true)
			Chronicle.close_chronicle(g, _tables)
			for draw: int in 2: _same(_data["cases"][0]["panelLines"], End.panel_lines(g, _tables, Turn.end_text(g, "ousted")), "disabled draw %d" % draw)
			assert_eq(V.full_diffs(before, g), [], "disabled paths leave even an old record untouched")
	assert_true(Chronicle.enabled({"dark": {}}), "an object has S1 truthiness")


func test_disabled_direct_lookback_has_no_closing_record() -> void:
	for row: Dictionary in _data["ruleHooks"]:
		if row["kind"] != "write_lookback": continue
		var g: Dictionary = row["input"].duplicate(true)
		g.erase("dark")
		Turn.write_lookback(g, _tables)
		var expected: Array = row["journal"].filter(func(line: Dictionary) -> bool: return not String(line["text"]).begins_with("기록: 징후"))
		_same(expected, g["journal"], "direct revolt-card lookback stays dark-off")
		assert_false(g.has("endChronicle"))


func test_wall_data_remains_a_function_level_oracle() -> void:
	var row: Dictionary = _data["wall"]
	assert_gt(row["expected"]["wall"].size(), 0)
	_answer(_unit_game(row["input"]), row["expected"], "wall names")


func test_rules_close_in_s1_journal_order_and_panels_only_read() -> void:
	for row: Dictionary in _data["ruleHooks"]:
		var g: Dictionary = row["input"].duplicate(true)
		if row["kind"] == "finish": Turn.finish(g, _tables, row["end"])
		else: Turn.write_lookback(g, _tables)
		_same(row["journal"], g["journal"], row["kind"] + " S1 journal order")
		_same(row["h7"], g["endChronicle"]["record"], row["kind"] + " rule-side record")
		assert_eq(g["journal"][-1]["text"].begins_with("기록: 징후"), true)
		var before_draw: Dictionary = g.duplicate(true)
		for draw: int in 2:
			var lines: Array = End.panel_lines(g, _tables, Turn.end_text(g, row["end"]))
			assert_eq(lines[-1], row["toneLine"])
			assert_eq(V.full_diffs(before_draw, g), [], "active rendering is read-only")
		# Rendering an active old save also must not create a missing record.
		g.erase("endChronicle")
		var no_record: Dictionary = g.duplicate(true)
		End.panel_lines(g, _tables, Turn.end_text(g, row["end"]))
		assert_eq(V.full_diffs(no_record, g), [], "panel never creates a record")

