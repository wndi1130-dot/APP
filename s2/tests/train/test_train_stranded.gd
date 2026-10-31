extends GutTest
## S1-produced steps, including RNG, full journals, ledgers, cards and settlement receipts.
## Written for the lead's GUT slot; this worktree must not launch Godot.
const S = preload("res://game/train/turn/turn_stranded.gd")
const C = preload("res://game/train/turn/turn_common.gd")
const Cards = preload("res://game/train/turn/turn_cards.gd")
const Text = preload("res://game/train/turn/turn_card_text.gd")
const Content = preload("res://game/train/turn/turn_content.gd")
const Budget = preload("res://game/train/turn/turn_budget.gd")
const Turn = preload("res://game/train/train_turn.gd")
const Advance = preload("res://game/train/train_advance.gd")
const Save = preload("res://game/politics/save_slot.gd")
const Paper = preload("res://game/ui/turn_card.gd")
const V = preload("res://tests/train/train_vectors.gd")
var _data: Dictionary
var _content: Dictionary
var _tables: Dictionary

func before_all() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/train/stranded_vectors.json"))
	_content = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/train/stranded_content_vectors.json"))
	_tables = JSON.parse_string(FileAccess.get_file_as_string("res://game/train/slice_start.json"))["tables"]
	Content._data = {}

func _same(want: Variant, got: Variant, at: String) -> void:
	assert_eq(V.full_diffs(want, got, at, 14), [] as Array[String], at)

func _view(g: Dictionary, t: Dictionary, card: Dictionary) -> Dictionary:
	var v: Dictionary = Text.view(g, t, card)
	var choices: Array = []
	var costs: Array = []
	var pols: Array = []
	for ch: Dictionary in v.get("choices", []):
		var out: Dictionary = {}
		for key: String in ["label", "log", "say", "why", "later", "disabled", "special"]: out[key] = ch.get(key, "")
		out["witness"] = ch.get("witness", false)
		out["extra"] = ch.get("extra", [])
		out["effs"] = ch["effs"]
		choices.append(out)
		costs.append(Text.cost_lines(t, ch))
		pols.append(Text.politics_lines(t, ch))
	return {"title": v.get("title", ""), "body": v.get("body", ""), "required": v.get("required", false), "speaker": v.get("speaker"),
		"focus": v.get("focus"), "key": v.get("key"), "choices": choices, "costs": costs, "pols": pols}

func _step(input: Dictionary, t: Dictionary, action: Dictionary, at: String) -> Dictionary:
	var g: Dictionary = input.duplicate(true)
	var result: Variant = null
	match str(action["kind"]):
		"setup": g.merge(action["values"].duplicate(true), true)
		"advance":
			g = Advance.advance(input, t)
		"add_card": C.card(g, action["card"], t)
		"view": result = _view(g, t, action["card"])
		"choose_card": g = Advance.choose_card(input, t, int(action["uid"]), int(action["index"]))
		"start_trip": result = S.start_trip(g, t, action["mode"])
		"enter": S.enter_stranded(g, t, float(action["coal"]), float(action["need"]))
		"stall_math": result = [S.stall_km(30, 4, 10), S.stall_km(30, 0, 10), S.stall_km(30, 10, 10), S.stall_km(30, 4, 0), S.stall_km(1, -2, 10)]
		"trip_tick": S.trip_tick(g, t)
		"stranded_settle": S.stranded_settle(g, t)
		"stranded_depart": S.stranded_depart(g, t)
		"budget_next": Budget.next_segment(g, t)
		"finish": Turn.finish(g, t, action["end"])
		"plans": result = {"crew": S.trip_plan(g, t, "crew"), "captain": S.trip_plan(g, t, "captain"), "allowed": S.crew_allowed(g, t), "deputy": S.deputy_of(g, t), "supportLine": S.support_line_text(g, t)}
		"save":
			var read: Dictionary = Save.read_save(JSON.parse_string(JSON.stringify(g)), t)
			assert_true(read["ok"], at + " save")
			if read["ok"]: result = read["g"].get("stranded")
		"save_next":
			var read: Dictionary = Save.read_save(JSON.parse_string(JSON.stringify(g)), t)
			assert_true(read["ok"], at + " first load")
			if read["ok"]:
				var reloaded: Dictionary = Save.read_save(JSON.parse_string(JSON.stringify(read["g"])), t)
				assert_true(reloaded["ok"], at + " second load")
				if reloaded["ok"]:
					var direct: Dictionary = Advance.advance(read["g"], t)
					var after: Dictionary = Advance.advance(reloaded["g"], t)
					_same(direct, after, at + " next settlement and RNG survive save")
					result = {"before": read["g"], "after": after}
		_: fail_test("unknown fixture action: " + str(action["kind"]))
	assert_false(g.has("_turn_port_error"), at + ": " + str(g.get("_turn_port_error", "")))
	return {"g": g, "result": result}

func _case(id: String) -> Dictionary:
	for row: Dictionary in _data["cases"]:
		if row["id"] == id: return row
	return {}

func test_all_ten_scenes_replay_every_s1_step() -> void:
	assert_eq(_data["format"], "stranded-vectors-v1")
	var scenes: Array = []
	var count: int = 0
	for row: Dictionary in _data["cases"]:
		if not scenes.has(int(row["scene"])): scenes.append(int(row["scene"]))
		var t: Dictionary = _tables.duplicate(true)
		for person: Dictionary in t["PROFILES"]:
			if row.get("profileAges", {}).has(person["name"]): person["age"] = row["profileAges"][person["name"]]
		var g: Dictionary = row["steps"][0]["before"].duplicate(true)
		for i: int in row["steps"].size():
			var step: Dictionary = row["steps"][i]
			var at: String = "%s/%d %s" % [row["id"], i, step["action"]["kind"]]
			_same(step["before"], g, at + " before")
			var original: Dictionary = g.duplicate(true)
			var out: Dictionary = _step(g, t, step["action"], at)
			_same(original, g, at + " caller unchanged")
			g = out["g"]
			_same(step["after"], g, at + " after, RNG and words")
			if step.has("result"): _same(step["result"], out["result"], at + " result")
			count += 1
	scenes.sort()
	assert_eq(scenes, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
	assert_gt(count, 150)

func test_four_content_events_views_choices_and_required_filter() -> void:
	assert_eq(_content["format"], "stranded-content-v1")
	assert_eq(_content["events"], S.EVENTS)
	for row: Dictionary in _content["cases"]:
		var g: Dictionary = row["before"].duplicate(true)
		var at: String = row["id"] + "/" + row["variant"]
		assert_true(Content.add_content_card(g, _tables, row["id"], false, true), at)
		_same(row["state"], g, at + " add")
		_same(row["view"], _view(g, _tables, row["card"]), at + " view")
		for answer: Dictionary in row["choices"]:
			var got: Dictionary = Advance.choose_card(g, _tables, int(row["card"]["uid"]), int(answer["index"]))
			_same(answer["after"], got, at + "/choice/%d" % int(answer["index"]))

func test_all_four_trip_cards_fit_the_existing_paper_and_keep_extra_lines() -> void:
	var seen: Array = []
	for row: Dictionary in _data["cases"]:
		for step: Dictionary in row["steps"]:
			if step["action"]["kind"] != "view": continue
			var card: Dictionary = step["action"]["card"]
			var kind: String = card["kind"]
			if kind not in S.CARD_KINDS or seen.has(kind): continue
			if kind == "trip_return" and step["before"].get("stranded", {}).get("trip") == null: continue
			if kind == "trip_lost" and card.get("who") == null: continue
			if kind == "trip_extend" and card.get("n") == null: continue
			var g: Dictionary = step["before"].duplicate(true)
			g["cards"] = [card.duplicate(true)]
			var model: Dictionary = Paper.model(g, _tables, int(card["uid"]))
			assert_false(model.is_empty(), kind)
			assert_eq(model["title"], step["result"]["title"])
			assert_true(step["result"]["required"])
			assert_eq(model["choices"].size(), step["result"]["choices"].size())
			for i: int in model["choices"].size():
				var lines: Array = model["choices"][i]["effects"].map(func(e: Dictionary) -> String: return e["text"])
				for extra: String in step["result"]["choices"][i]["extra"]: assert_has(lines, extra, kind + " extra")
			seen.append(kind)
	assert_eq(seen.size(), 4)

func test_ending_states_keep_all_three_s1_endings_and_receipts() -> void:
	for end: String in ["revolt", "ousted", "lost_captain"]:
		var row: Dictionary = _case("finish-%s-in-settle" % end)
		var step: Dictionary = row["steps"][-1]
		var got: Dictionary = Advance.advance(step["before"], _tables)
		_same(step["after"], got, end)
		assert_eq(got["phase"], "end")
		assert_eq(got["end"], end)
		assert_true(got["lastSettle"] is Dictionary)
		assert_true((got["journal"] as Array).any(func(line: Dictionary) -> bool: return line["text"] == Turn.end_text(got, end)))
		assert_true((got["journal"] as Array).any(func(line: Dictionary) -> bool: return str(line["text"]).begins_with("돌이켜 보면")))

func test_budget_second_call_changes_nothing_and_six_turns_are_counted_once() -> void:
	var row: Dictionary = _case("budget-second-call-keeps-deferred-stats")
	var g: Dictionary = row["steps"][0]["before"].duplicate(true)
	Budget.next_segment(g, _tables)
	_same(row["steps"][0]["after"], g, "first budget call")
	assert_eq((g["deferred"] as Array).size(), 2, "pending cards make this a real duplicate-call regression")
	var once: Dictionary = g.duplicate(true)
	Budget.next_segment(g, _tables)
	_same(once, g, "second budget call")
	var six: Dictionary = _case("six-stranded-turns-budget-once-per-segment")
	assert_eq(int(six["steps"][-1]["after"]["stranded"]["turns"]), 6)
	assert_eq((six["steps"] as Array).filter(func(step: Dictionary) -> bool: return step["action"]["kind"] == "budget_next").size(), 6)

func test_hub_boundary_stays_blocked_for_a_stranded_train() -> void:
	for row: Dictionary in _data["blocked"]:
		var input: Dictionary = row["before"].duplicate(true)
		assert_false(Turn.next_segment_covers(input, _tables))
		var got: Dictionary = Advance.advance(input, _tables)
		assert_eq(got.get("_turn_port_error"), row["s2"])
		got.erase("_turn_port_error")
		_same(row["before"], got, "blocked %d" % int(row["seg"]))
		_same(row["before"], input, "boundary caller unchanged")
		assert_eq(int(row["s1After"]["seg"]), int(row["seg"]) + 1, "S1 progresses here; this S2 boundary is explicitly outside the port")

func test_first_depart_has_the_s1_empty_flags_without_ignoring_nonempty_flags() -> void:
	var row: Dictionary = _case("ordinary-depart-materializes-empty-flags")["steps"][0]
	assert_false(row["before"].has("contentFlags"))
	var got: Dictionary = Advance.advance(row["before"], _tables)
	assert_true(got.has("contentFlags"))
	assert_eq(got["contentFlags"], {})
	_same(row["after"], got, "S1 creates empty flags")
	assert_false(V.full_diffs({"comms": {}}, {"comms": {}, "contentFlags": {"stranded": true}}).is_empty())

func _valid_away() -> Dictionary:
	return _case("save-away")["steps"][0]["before"].duplicate(true)

func _invalid(g: Dictionary, at: String) -> void:
	assert_not_null(Save.shape_problem(g, _tables), at)

func test_save_roundtrip_stranded_away_absent_null_and_old_burned() -> void:
	for id: String in ["save-absent", "save-stranded", "save-away", "save-resumed", "save-old-burned"]:
		var g: Dictionary = _case(id)["steps"][0]["before"]
		# The slot's JSON serialization and reader; existing test_save_slot covers disk I/O.
		var loaded: Dictionary = Save.read_save(JSON.parse_string(JSON.stringify(g)), _tables)
		assert_true(loaded["ok"], id)
		if loaded["ok"]: _same(g.get("stranded"), loaded["g"].get("stranded"), id)

func test_save_rejects_every_bad_stranded_and_trip_field() -> void:
	var base: Dictionary = _valid_away()
	assert_null(Save.shape_problem(base, _tables))
	for key: String in ["since", "turns", "segKm", "atKm", "toNextKm", "lostTrips"]:
		for bad: Variant in [null, -1, 0.5, "1", INF, NAN]:
			var g: Dictionary = base.duplicate(true)
			g["stranded"][key] = bad
			_invalid(g, "stranded." + key)
	for key: String in ["captainAway", "lamp", "seen", "deputy", "snow", "trip"]:
		var g: Dictionary = base.duplicate(true)
		g["stranded"].erase(key)
		_invalid(g, "missing stranded." + key)
		g["stranded"][key] = 42
		_invalid(g, "wrong stranded." + key)
	for bad: Variant in [null, "1", INF, NAN]:
		var g: Dictionary = base.duplicate(true)
		g["stranded"]["burned"] = bad
		_invalid(g, "stranded.burned")
	for key: String in ["size", "distKm", "extends", "goTurns", "searchTurns", "backTurns", "plannedTurns", "turn"]:
		for bad: Variant in [null, -1, 0.5, "1", INF, NAN]:
			var g: Dictionary = base.duplicate(true)
			g["stranded"]["trip"][key] = bad
			_invalid(g, "trip." + key)
	for key: String in ["posKm", "baseFood", "foodShort", "foodOwed"]:
		for bad: Variant in [null, "1", INF, NAN]:
			var g: Dictionary = base.duplicate(true)
			g["stranded"]["trip"][key] = bad
			_invalid(g, "trip." + key)
	for key: String in ["leaderGoes", "forced", "known", "comm", "names", "phase", "outcome", "promise"]:
		var g: Dictionary = base.duplicate(true)
		g["stranded"]["trip"].erase(key)
		_invalid(g, "missing trip." + key)
		g["stranded"]["trip"][key] = 42
		_invalid(g, "wrong trip." + key)
	for key: String in ["seen", "names"]:
		var g: Dictionary = base.duplicate(true)
		if key == "seen": g["stranded"][key] = ["ok", 42]
		else: g["stranded"]["trip"][key] = ["ok", 42]
		_invalid(g, "mixed string array " + key)
	for bad: Variant in [[], true, "stopped", 42]:
		var g: Dictionary = base.duplicate(true)
		g["stranded"] = bad
		_invalid(g, "wrong stranded container")

func test_save_rejects_missing_or_nonfinite_budget_numbers() -> void:
	for key: String in ["seg", "picked"]:
		var g: Dictionary = _valid_away()
		g["budget"] = {"seg": 1, "picked": 0}
		assert_null(Save.shape_problem(g, _tables))
		g["budget"].erase(key)
		_invalid(g, "missing budget." + key)
		for bad: Variant in [null, "1", true, INF, NAN]:
			g["budget"][key] = bad
			_invalid(g, "wrong budget." + key)

func test_rule_josa_uses_s1_hangul_and_number_finals() -> void:
	assert_eq(S.josa("꼬리칸", "이/가"), "이")
	assert_eq(S.josa("경비대", "이/가"), "가")
	assert_eq(S.josa("1", "으로/로"), "로")
	assert_eq(S.josa("6", "으로/로"), "으로")
	assert_eq(S.josa(" 8 ", "이/가"), "이")
	assert_eq(S.josa("", "이/가"), "가")
