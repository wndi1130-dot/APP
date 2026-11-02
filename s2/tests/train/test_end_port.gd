extends GutTest
## S1 answers; the caller owns the Godot/GUT execution slot.
const V = preload("res://tests/train/train_vectors.gd")
const Turn = preload("res://game/train/train_turn.gd")
const Content = preload("res://game/train/turn/turn_content.gd")
const Cards = preload("res://game/train/turn/turn_cards.gd")
const Trip = preload("res://game/train/turn/turn_stranded.gd")
const Chronicle = preload("res://game/train/train_chronicle.gd")
const End = preload("res://game/train/turn/turn_end.gd")
const Save = preload("res://game/politics/save_slot.gd")
const State = preload("res://game/train/train_state.gd")
var _data: Dictionary
var _tables: Dictionary
var _content_before: Dictionary


func before_all() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/train/end_vectors.json"))
	_tables = JSON.parse_string(FileAccess.get_file_as_string("res://game/train/slice_start.json"))["tables"]


func before_each() -> void:
	_content_before = Content.data().duplicate(true)
	Content.register_definitions("deals", _data["deals"])


func after_each() -> void:
	Content._data = _content_before


func _same(want: Variant, got: Variant, where: String) -> void:
	assert_eq(V.diff(want, got, where), "", where)


func _unit_game(input: Dictionary) -> Dictionary:
	var g: Dictionary = input.duplicate(true)
	if not g.get("dark") is Dictionary:
		g["dark"] = {"means": {}, "crossed": [], "nightmareUntil": -1, "nightmareCards": 0,
			"numb": false, "h7": [], "stats": {}, "joined": [], "scenes": [], "closed": false}
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
	var was_closed: bool = bool(g["dark"]["closed"])
	Chronicle.close_chronicle(g, _tables)
	var wall: Array = Chronicle.wall_names(g, _tables)
	_same(expected["wall"], wall, where + " wall data")
	var lines: Array = []
	for row: Dictionary in wall: lines.append(Chronicle.wall_line(row))
	_same(expected["wallLines"], lines, where + " wall words")
	assert_eq(g["journal"][-1]["text"], expected["closeLine"], where + " closing journal")
	assert_eq(g["journal"].size(), size_before + (0 if was_closed else 1))
	var first_close: Dictionary = g.duplicate(true)
	Chronicle.close_chronicle(g, _tables)
	assert_eq(V.full_diffs(first_close, g), [], where + " close once")
	assert_eq(g["rng"], before_rng, where + " no RNG consumption")
	assert_true(Chronicle.enabled(g), where + " isolated active chronicle input")
	var loaded: Dictionary = Save.read_save(JSON.parse_string(JSON.stringify(g)), _tables)
	assert_true(loaded["ok"], where + " record save/load")
	if loaded["ok"]:
		_same(g["dark"], loaded["g"]["dark"], where + " saved record")
		assert_eq(Chronicle.tone_line(loaded["g"]), expected["toneLine"])
	_same(g["dark"], State.to_rules(g, _tables)["train"]["dark"], where + " registered key")


func test_seeded_end_transitions_and_full_run_end_states() -> void:
	assert_eq(_data["format"], "end-vectors-v3")
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
		assert_ne(row["reason"], "")
		assert_eq(reason, row["reason"])
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
		assert_eq(V.full_diffs(row["expectedState"], Chronicle.state(g)), [], row["id"] + " S1 dark state")
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
	for row: Dictionary in _data["cards"]:
		var g: Dictionary = _unit_game(row["input"])
		var before: Dictionary = g.duplicate(true)
		for ms: float in [0.0, -1.0, INF, NAN]:
			Chronicle.log_card_pick(g, _tables, int(row["uid"]), int(row["index"]), ms)
		Chronicle.log_card_pick(g, _tables, -1, 0, 1200)
		Chronicle.log_card_pick(g, _tables, int(row["uid"]), -1, 1200)
		assert_eq(V.full_diffs(before, g), [], "invalid picks leave the entire state alone")
		Chronicle.log_card_pick(g, _tables, int(row["uid"]), int(row["index"]), float(row["ms"]))
		_same(row["expected"], g["dark"]["h7"], row["id"] + " S1 logCardPick")
		assert_false(g.has("endChronicle"))
		before = g.duplicate(true)
		Chronicle._log_card_view_pick(g, "closed", {"body": "", "choices": [{"label": "닫힘", "disabled": "닫힘"}]}, 0, 1000)
		assert_eq(V.full_diffs(before, g), [], "disabled choices are not logged")
	assert_eq(Chronicle._utf16_length("한😀"), 3)


func test_disabled_h7_valid_picks_leave_the_entire_state_alone() -> void:
	for row: Dictionary in _data["cards"]:
		for dark: Variant in [null, false]:
			var g: Dictionary = row["input"].duplicate(true)
			g.erase("dark")
			if dark != null: g["dark"] = dark
			var before: Dictionary = g.duplicate(true)
			Chronicle.log_card_pick(g, _tables, int(row["uid"]), int(row["index"]), float(row["ms"]))
			Chronicle.log_pick(g, _data["h7"]["picks"][0])
			assert_eq(V.full_diffs(before, g), [], "dark absent/false valid H7 picks are no-ops")


func test_s1_dark_state_and_already_closed_save() -> void:
	for row: Dictionary in _data["restored"]:
		var g: Dictionary = row["input"].duplicate(true)
		assert_eq(Chronicle.tone(g), "shade", "S1 exiles survive the port")
		var before: Dictionary = g.duplicate(true)
		_answer(g, row["expected"], row["id"])
		if bool(row["input"]["dark"]["closed"]):
			assert_eq(V.full_diffs(before, g), [], "already closed S1 input stays identical")
		assert_false(g.has("endChronicle"))


func test_stopped_train_does_not_close_a_chronicle() -> void:
	var g: Dictionary = _data["cases"][2]["before"].duplicate(true)
	var before: Dictionary = g.duplicate(true)
	assert_eq(End.panel_lines(g, _tables, Turn.END_TEXT["stranded"]), [Turn.END_TEXT["stranded"]])
	assert_eq(V.full_diffs(before, g), [])


func test_disabled_dark_leaves_state_and_panels_unchanged() -> void:
	for dark: Variant in [null, false]:
		var g: Dictionary = _data["cases"][0]["after"].duplicate(true)
		g.erase("dark")
		if dark != null: g["dark"] = dark
		var before: Dictionary = g.duplicate(true)
		Chronicle.close_chronicle(g, _tables)
		for draw: int in 2: _same(_data["cases"][0]["panelLines"], End.panel_lines(g, _tables, Turn.end_text(g, "ousted")), "disabled draw %d" % draw)
		assert_eq(V.full_diffs(before, g), [], "disabled paths leave the entire state alone")
	assert_true(Chronicle.enabled({"dark": {}}), "an object has S1 truthiness")


func test_disabled_direct_lookback_has_no_closing_record() -> void:
	for row: Dictionary in _data["ruleHooks"]:
		if row["kind"] != "write_lookback": continue
		var g: Dictionary = row["input"].duplicate(true)
		g.erase("dark")
		Turn.write_lookback(g, _tables)
		var expected: Array = row["journal"]
		_same(expected, g["journal"], "direct revolt-card lookback stays dark-off")
		assert_false(g.has("endChronicle"))


func test_wall_data_remains_a_function_level_oracle() -> void:
	var row: Dictionary = _data["wall"]
	assert_gt(row["expected"]["wall"].size(), 0)
	_answer(_unit_game(row["input"]), row["expected"], "wall names")


func test_rules_close_in_s1_journal_order_and_panels_only_read() -> void:
	for row: Dictionary in _data["ruleHooks"]:
		var g: Dictionary = row["input"].duplicate(true)
		match String(row["kind"]):
			"finish": Turn.finish(g, _tables, row["end"])
			"write_lookback": Turn.write_lookback(g, _tables)
			"choose_card":
				# The dark gameplay gate stays closed; compare only the ported resolver.
				var card: Dictionary = g["cards"][0]
				var view: Dictionary = Cards.view(g, _tables, card)
				g = Cards._resolve_choice(g, _tables, card, view, view["choices"][int(row["index"])])
			"choose_card_off": g = Cards.choose(g, _tables, int(row["uid"]), int(row["index"]))
		_same(row["journal"], g["journal"], row["kind"] + " S1 journal order")
		assert_eq(V.full_diffs(row["dark"], g.get("dark")), [], row["kind"] + " S1 dark state")
		if row["kind"] == "write_lookback": assert_false(g["dark"]["closed"])
		elif Chronicle.enabled(g): assert_true(g["dark"]["closed"])
		assert_false(g.has("endChronicle"))
		var before_draw: Dictionary = g.duplicate(true)
		for draw: int in 2:
			var lines: Array = End.panel_lines(g, _tables, Turn.end_text(g, row["end"]))
			if Chronicle.enabled(g): assert_eq(lines[-1], row["toneLine"])
			assert_eq(V.full_diffs(before_draw, g), [], "rendering is read-only")
		if Chronicle.enabled(g): g["dark"]["closed"] = false
		var no_record: Dictionary = g.duplicate(true)
		End.panel_lines(g, _tables, Turn.end_text(g, row["end"]))
		assert_eq(V.full_diffs(no_record, g), [], "panel never closes a record")
