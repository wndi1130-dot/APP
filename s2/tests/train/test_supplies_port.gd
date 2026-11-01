extends "res://addons/gut/test.gd"
## S1 functions generate every expected state, including stores, ledger, cards and RNG.
const V = preload("res://tests/politics/field_vectors.gd")
const Supplies = preload("res://game/train/train_supplies.gd")
const C = preload("res://game/train/turn/turn_common.gd")
const Advance = preload("res://game/train/train_advance.gd")
const Cards = preload("res://game/train/turn/turn_cards.gd")
const Text = preload("res://game/train/turn/turn_card_text.gd")
const Vote = preload("res://game/politics/council_vote.gd")
const Field = preload("res://game/politics/field_return.gd")
const Departure = preload("res://game/politics/field_departure.gd")
const Save = preload("res://game/politics/save_slot.gd")
const State = preload("res://game/train/train_state.gd")
const PATH: String = "res://tests/fixtures/train/supplies_vectors.json"
const SAVE_PATH: String = "user://supplies_pr1_gut_round_trip.json"
const BROKEN_PATH: String = "user://supplies_pr1_gut_broken.json"

var _data: Dictionary = {}
var _t: Dictionary = {}


func before_all() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_true(parsed is Dictionary)
	if parsed is Dictionary:
		_data = parsed
		_t = _data["tables"]
	assert_eq(_data.get("format"), "supplies-vectors-v1")


func after_all() -> void:
	for path: String in [SAVE_PATH, BROKEN_PATH]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _state_for_compare(want: Variant, got: Variant) -> Variant:
	if not want is Dictionary or not got is Dictionary or not want.has("comms"): return got
	var state: Dictionary = got.duplicate(true)
	# Match train_vectors.full_diffs: only absent, empty S2 bookkeeping is optional.
	if not want.has("contentFlags") and state.get("contentFlags") is Dictionary and state["contentFlags"].is_empty():
		state.erase("contentFlags")
	# FieldReturn already materialized this empty book before the supplies PR.
	if not want.has("wounds") and state.get("wounds") is Array and state["wounds"].is_empty():
		state.erase("wounds")
	return state


func _same(want: Variant, got: Variant, at: String) -> void:
	assert_eq(V.diff(want, _state_for_compare(want, got), at), "", at)


func test_state_comparison_only_allows_absent_empty_books() -> void:
	var want: Dictionary = {"comms": {}}
	var got: Dictionary = {"comms": {}, "contentFlags": {}, "wounds": []}
	_same(want, got, "empty S2 books")
	assert_true(got.has("contentFlags") and got.has("wounds"), "comparison preserves caller state")
	for extra: Dictionary in [{"contentFlags": {"stranded": true}}, {"wounds": [{"id": 1}]}, {"unexpected": {}}, {"contentFlags": []}, {"wounds": {}}]:
		var state: Dictionary = want.duplicate(true)
		state.merge(extra)
		assert_ne(V.diff(want, _state_for_compare(want, state)), "", "nonempty, mistyped and unknown keys stay visible")
	assert_ne(V.diff({"wounds": []}, _state_for_compare({"wounds": []}, {})), "", "expected keys stay required")
	assert_ne(V.diff({}, _state_for_compare({}, {"wounds": []})), "", "only whole game states are normalized")


func _rows(group: String) -> Array:
	return _data["groups"][group]


func _hygiene(g: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for comm: String in _t["COMMS"]: out[comm] = Supplies.hygiene_short(g, _t, comm)
	return out


func test_supplies_vectors_match_s1() -> void:
	_same(_data["yield"], Supplies.YIELD, "stop yields")
	for row: Dictionary in _rows("enable"):
		var g: Dictionary = row["before"].duplicate(true)
		Supplies.enable(g, _t)
		_same(row["after"], g, row["name"])
		assert_false(g.has("dom"))
	for row: Dictionary in _rows("use"):
		var g: Dictionary = row["before"].duplicate(true)
		var want: Dictionary = row["value"]
		_same(want["need"], Supplies.need(g, _t), row["name"] + "/need")
		_same(want["hygieneBefore"], _hygiene(g), row["name"] + "/before hygiene")
		var turn: Dictionary = Supplies.use(g, _t)
		_same(want["turn"], turn, row["name"] + "/use")
		Supplies.relations(g, _t, turn)
		_same(want["asks"], Supplies.asks(g), row["name"] + "/asks")
		_same(want["hygiene"], _hygiene(g), row["name"] + "/hygiene")
		_same(row["after"], g, row["name"] + "/state")
		if row["name"] == "zero-population":
			assert_false(turn["plenty"])
			assert_eq(turn["cover"], {})


func test_contribution_preserves_half_cover_with_away() -> void:
	for row: Dictionary in _rows("use"):
		if not String(row["name"]).begins_with("contribution/"): continue
		var g: Dictionary = row["before"].duplicate(true)
		var turn: Dictionary = Supplies.use(g, _t)
		_same(row["value"]["turn"], turn, row["name"])
		if row["name"] == "contribution/exact-half":
			assert_eq(float(turn["cover"]["medtech"]), 0.5)
			assert_false(Supplies.hygiene_short(g, _t, "medtech"))
		if row["name"] == "contribution/away-79":
			assert_gt(float(turn["cover"]["tail"]), 0.0, "away does not demote the largest contribution")
		if row["name"] == "contribution/tie-comms-order":
			_same({"tail": 1.0, "medtech": 0.5, "guard": 0.0, "front": 0.0, "engine": 0.0}, turn["cover"], "exact ties follow COMMS")


func test_supplies_ledger_off_missing_and_floor_zero() -> void:
	for row: Dictionary in _rows("ledger"):
		var g: Dictionary = row["before"].duplicate(true)
		match String(row.get("method", "off")):
			"bump":
				C.bump(g, "sup", 1.5, "sup.search")
				C.bump(g, "sup", -9, "sup.use")
			"parts":
				C.bump_parts(g, "sup", 1.5, [["stop.loot", 1], ["sup.search", 2]])
				C.bump_parts(g, "sup", -9, [["sup.use", 1]])
			"put":
				C.put(g, "sup", 1.5, "sup.search")
				C.put(g, "sup", -9, "sup.use")
			"add":
				Supplies.add(g, 1.5, "field.loot")
				Supplies.add(g, -9, "field.loot")
			_:
				Supplies.add(g, 9, "field.loot")
				C.bump(g, "sup", 3, "sup.search")
				C.bump_parts(g, "sup", 4, [["sup.search", 1]])
				C.put(g, "sup", 7, "sup.use")
		_same(row["after"], g, row["name"])


func test_supplies_stop_yields_stays_cut_pass_and_empty_match_s1() -> void:
	for row: Dictionary in _rows("stops"):
		var g: Dictionary = Advance.resolve_stop(row["before"], _t, bool(row.get("go", true)))
		_same(row["after"], g, row["name"])
		assert_false(g.has("dom"), "a stop does not enable domestic mode")
		assert_false(g["stop"]["result"]["gains"].has("sup"))
		assert_false(g["stop"]["result"]["gains"].has("supplies"))
	for row: Dictionary in _rows("departures"):
		var got: Dictionary = Departure.build(row["before"], _t, row["opts"])
		_same(row["value"], got, row["name"])
		assert_eq(got["supplies"], bool(row["before"].get("supOn", false)))


func test_field_supplies_signed_and_idempotent() -> void:
	for row: Dictionary in _rows("fields"):
		var before: String = JSON.stringify(row["before"])
		var out: Dictionary = Field.apply_field_return(row["before"], _t, row["departure"], row["input"])
		assert_eq(out["status"], row["status"], row["name"])
		_same(row["after"], out["g"], row["name"])
		assert_eq(JSON.stringify(row["before"]), before, "caller state is never mutated")
		if row["status"] == "rejected":
			assert_false((out["problems"] as Array).is_empty())
			if row["name"] == "other-id-same-stop-plus3":
				assert_eq(out["problems"], ["이미 반영한 정차에 다른 영수증이 왔다"])
				assert_eq(float(out["g"]["sup"]), 11.0, "+3 was applied once")
		else:
			_same(row["record"], out["record"], row["name"] + "/receipt")
			if row["name"] == "signed/true/-10":
				assert_eq(float(out["g"]["sup"]), 0.0)
				assert_true(JSON.stringify(out["record"]["lines"]).contains("부족 2"))


func _card_view(g: Dictionary, card: Dictionary) -> Dictionary:
	var view: Dictionary = Text.view(g, _t, card)
	var out: Dictionary = {}
	for key: String in ["title", "body", "required", "speaker", "focus", "key"]: out[key] = view.get(key)
	var choices: Array = []
	for ch: Dictionary in view["choices"]:
		var row: Dictionary = {}
		for key: String in ["id", "label", "say", "log", "disabled", "special"]: row[key] = ch.get(key, "")
		row["effs"] = ch["effs"]
		row["costs"] = Text.cost_lines(_t, ch)
		row["politics"] = Text.politics_lines(_t, ch)
		choices.append(row)
	out["choices"] = choices
	return out


func test_supplies_asks_and_fine_choices_match_s1() -> void:
	for row: Dictionary in _rows("cards"):
		_same(row["view"], _card_view(row["before"], row["card"]), row["name"])
		for choice: Dictionary in row["choices"]:
			var g: Dictionary = Cards.choose(row["before"], _t, int(row["card"]["uid"]), int(choice["index"]))
			_same(choice["after"], g, "%s/%d" % [row["name"], int(choice["index"])])
	for row: Dictionary in _rows("conditions"):
		var g: Dictionary = row["before"].duplicate(true)
		for round_row: Dictionary in row["rounds"]:
			g["session"] = round_row["session"]
			_same(round_row["value"], Vote.open_conditions(g, _t, row["comm"]), "%s/%d" % [row["name"], int(round_row["session"])])


func test_supplies_use_before_due_promise_and_plenty_only_for_issuer() -> void:
	for row: Dictionary in _rows("settles"):
		var g: Dictionary = Advance.advance(row["before"], _t)
		_same(row["after"], g, row["name"])
		assert_false(g.has("dom"))
		if row["name"] == "demand/12":
			assert_eq(int(g["comms"]["tail"]["demandCool"]), 5)
			for comm: String in ["medtech", "guard", "front", "engine"]:
				assert_eq(int(g["comms"][comm]["demandCool"]), 0, "only the issuer receives +2")


func _step(g: Dictionary, action: Dictionary) -> Dictionary:
	match String(action["kind"]):
		"resolve_stop": return Advance.resolve_stop(g, _t, bool(action["go"]))
		"choose_card": return Advance.choose_card(g, _t, int(action["uid"]), int(action["index"]))
		"cast_vote": return Advance.cast_vote(g, _t)
		_: return Advance.advance(g, _t)


func _play(row: Dictionary) -> void:
	var g: Dictionary = row["initial"].duplicate(true)
	for i: int in row["steps"].size():
		var step: Dictionary = row["steps"][i]
		g = _step(g, step["action"])
		_same(step["after"], g, "%s/%d" % [row["name"], i])
		assert_false(g.has("dom"))
		if row["flag"] != true:
			assert_false(g.has("sup"))
			assert_false(g.has("supFine"))
			assert_false(g.has("supCover"))
	assert_eq(int(row["settles"]), 4)


func test_supplies_off_keeps_state_rng_cards() -> void:
	for row: Dictionary in _data["runs"]:
		if row["flag"] != true: _play(row)


func test_supplies_enabled_s1a_full_turns_match_s1() -> void:
	for row: Dictionary in _data["runs"]:
		if row["flag"] == true: _play(row)


func test_supplies_save_legacy_and_round_trip() -> void:
	assert_eq(Save.SAVE_VERSION, 1)
	var old: Dictionary = _data["runs"][0]["initial"].duplicate(true)
	var on: Dictionary = _data["runs"][2]["initial"].duplicate(true)
	on["sup"] = 1.5
	on["supFine"] = 0.25
	on["supCover"] = {"tail": 0.5, "medtech": 1.0}
	on["comms"]["tail"]["promise"] = {"kind": "open", "cond": {"kind": "give_sup", "label": "아이들 겨울옷", "now": false, "amount": 2, "sup": true}, "label": "아이들 겨울옷", "due": 3, "madeSession": 0}
	var flag_only: Dictionary = old.duplicate(true)
	flag_only["supOn"] = true
	var off: Dictionary = old.duplicate(true)
	off["supOn"] = false
	for g: Dictionary in [old, on, flag_only, off]:
		assert_true(Save.save_slot(g, SAVE_PATH))
		var loaded: Dictionary = Save.load_slot(_t, SAVE_PATH, BROKEN_PATH)
		assert_null(loaded["why"])
		if not loaded["g"] is Dictionary: continue
		var expected: Dictionary = g.duplicate(true)
		Save.fill_defaults(expected)
		_same(expected, loaded["g"], "save round trip")
		var rules: Dictionary = State.to_rules(loaded["g"], _t)["train"]
		for key: String in ["supOn", "sup", "supFine", "supCover"]:
			assert_eq(loaded["g"].has(key), g.has(key), key + " presence")
			assert_eq(rules.has(key), g.has(key), key + " projection presence")
			if g.has(key): _same(g[key], rules[key], key)
	assert_false(old.has("supOn"))


func test_supplies_save_rejects_wrong_types_nonfinite_and_unknown_cover() -> void:
	var old: Dictionary = _data["runs"][0]["initial"]
	for pair: Array in [["supOn", 1], ["supOn", null], ["sup", -1], ["sup", INF], ["sup", NAN], ["sup", "8"], ["sup", null],
		["supFine", -1], ["supFine", INF], ["supFine", NAN], ["supCover", null], ["supCover", []], ["supCover", {"alien": 0.5}],
		["supCover", {"tail": -0.1}], ["supCover", {"tail": 1.01}], ["supCover", {"tail": NAN}], ["supCover", {"tail": "1"}]]:
		var g: Dictionary = old.duplicate(true)
		g[pair[0]] = pair[1]
		assert_not_null(Save.shape_problem(g, _t), "reject " + str(pair))
