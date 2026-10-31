extends GutTest
## Written for the lead's Godot/GUT slot. No fixture answers are consulted by game code.
const Content = preload("res://game/train/turn/turn_content.gd")
const Travel = preload("res://game/train/turn/turn_travel.gd")
const Cards = preload("res://game/train/turn/turn_cards.gd")
const CardText = preload("res://game/train/turn/turn_card_text.gd")
const Advance = preload("res://game/train/train_advance.gd")
const SaveSlot = preload("res://game/politics/save_slot.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const V = preload("res://tests/train/train_vectors.gd")
const CARD_PATH: String = "res://tests/fixtures/train/content_vectors.json"
const TURN_PATH: String = "res://tests/fixtures/train/turn_vectors_eventpack.json"
var _cards: Dictionary = {}
var _turns: Dictionary = {}
var _catalog: Dictionary = {}


func before_all() -> void:
	_cards = JSON.parse_string(FileAccess.get_file_as_string(CARD_PATH))
	_turns = JSON.parse_string(FileAccess.get_file_as_string(TURN_PATH))
	_catalog = Content.data().duplicate(true)


func before_each() -> void:
	Content._data = _catalog.duplicate(true)


func after_each() -> void:
	Content._data = _catalog.duplicate(true)


func _definitions() -> void:
	for kind: String in ["events", "secrets", "deals"]: Content.register_definitions(kind, _cards["definitions"][kind])


func _same(want: Variant, got: Variant, at: String) -> void:
	assert_eq(V.full_diffs(want, got, at, 12), [] as Array[String], at)


static func _tuple(effect: Dictionary) -> Array:
	match str(effect["t"]):
		"rel": return ["rel", effect["c"], effect["v"]]
		"base": return ["base", effect["c"], effect["i"], effect["v"]]
	return [effect["t"], effect["v"]]


static func _step(g: Dictionary, t: Dictionary, action: Dictionary) -> Dictionary:
	match str(action["kind"]):
		"choose_card": return Advance.choose_card(g, t, int(action["uid"]), int(action["index"]))
		"resolve_stop": return Advance.resolve_stop(g, t, bool(action["go"]))
		"cast_vote": return Advance.cast_vote(g, t)
		"advance": return Advance.advance(g, t)
	return g


func _part(row: Dictionary) -> void:
	var g: Dictionary = row["before"].duplicate(true)
	var t: Dictionary = _cards["tables"]
	var action: Dictionary = row["action"]
	var result: Variant = null
	match str(action["kind"]):
		"add": result = Content.add_content_card(g, t, action["id"])
		"pool":
			var ids: Array = []
			for ev: Dictionary in Content.content_pool(g, t): ids.append(ev["id"])
			result = ids
		"choose":
			g = Cards.choose(g, t, int(action["uid"]), int(action["index"]))
			result = not (g["cards"] as Array).any(func(card: Dictionary) -> bool: return int(card["uid"]) == int(action["uid"]))
		"tick": Content.content_followup_tick(g, t)
		"away": Content.content_away_tick(g)
	if row.has("result"): _same(row["result"], result, str(row["name"]) + ".result")
	_same(row["after"], g, row["name"])


func test_fixture_contract_has_46_first_views_and_four_live_runs() -> void:
	assert_eq(_cards["format"], "content-vectors-v1")
	assert_eq(_turns["format"], "turn-content-v1")
	assert_eq(int(_cards["packCount"]), 46)
	assert_eq((_cards["views"] as Array).filter(func(row: Dictionary) -> bool: return str(row["name"]).begins_with("first/")).size(), 46)
	assert_eq((_turns["runs"] as Array).size(), 4)
	assert_eq(Content.data()["draw"], _cards["tables"]["DRAW"])
	for ev: Dictionary in Content.data()["events"]:
		assert_eq(ev["phase"], "travel")
		assert_false(str(ev["id"]).begins_with("ev_str_"))
	for run: Dictionary in _turns["runs"]:
		assert_gte((run["steps"] as Array).size(), 30)
		assert_gt(int(run["contentChoices"]), 0)
	assert_true(Content.in_event_pack("ev_b01_any"))
	assert_true(Content.in_event_pack("ev_h12_any"))
	assert_false(Content.in_event_pack("ev_h1_any"))
	assert_false(Content.in_event_pack("ev_future"))


func test_four_eventpack_runs_match_s1_full_state_and_rng() -> void:
	for run: Dictionary in _turns["runs"]:
		var g: Dictionary = run["steps"][0]["before"].duplicate(true)
		var chosen: int = 0
		for row: Dictionary in run["steps"]:
			var at: String = "%s/%d" % [run["seed"], int(row["step"])]
			_same(row["before"], g, at + ".before")
			var action: Dictionary = row["action"]
			if action["kind"] == "choose_card":
				for card: Dictionary in g["cards"]:
					if card["uid"] == action["uid"] and card["kind"] == "content": chosen += 1
			g = _step(g, _turns["tables"], action)
			assert_false(g.has("_turn_port_error"), at)
			_same(row["after"], g, at + ".after (including journal/eventLog)")
		assert_eq(chosen, int(run["contentChoices"]))


func test_every_content_view_and_requires_match_s1_without_using_rng() -> void:
	_definitions()
	for row: Dictionary in _cards["views"]:
		var g: Dictionary = row["state"].duplicate(true)
		var before: Dictionary = g.duplicate(true)
		var want: Dictionary = row["view"]
		var got: Dictionary = CardText.view(g, _cards["tables"], row["card"])
		var at: String = row["name"]
		for key: String in ["title", "body", "required", "focus", "key", "speaker"]:
			_same(want.get(key), got.get(key), at + "." + key)
		assert_eq((got["choices"] as Array).size(), (want["choices"] as Array).size(), at)
		for i: int in mini((want["choices"] as Array).size(), (got["choices"] as Array).size()):
			var expected: Dictionary = want["choices"][i]
			var actual: Dictionary = got["choices"][i]
			for field: Array in [["id", ""], ["label", ""], ["say", ""], ["why", ""], ["later", ""], ["disabled", ""], ["special", ""], ["witness", false]]:
				_same(expected.get(field[0], field[1]), actual.get(field[0], field[1]), "%s[%d].%s" % [at, i, field[0]])
			assert_eq(actual.has("log"), expected.has("log"), at + ".log presence")
			_same(expected.get("log"), actual.get("log"), at + ".filled log")
			_same((expected["effs"] as Array).map(_tuple), actual["effs"], at + ".effs")
			_same(row["costs"][i], CardText.cost_lines(_cards["tables"], actual), at + ".costs")
			_same(row["pols"][i], CardText.politics_lines(_cards["tables"], actual), at + ".politics")
		_same(before, g, at + ".view does not mutate")
		g["lateOn"] = true
		var late: Dictionary = Cards.view(g, _cards["tables"], row["card"])
		assert_false((late["choices"] as Array).any(func(ch: Dictionary) -> bool: return ch.get("special") == "late"), at + ": content is never postponed")


func test_all_content_answers_match_s1_effects_witnesses_event_log_and_journal() -> void:
	_definitions()
	var count: int = 0
	for row: Dictionary in _cards["views"]:
		for answer: Dictionary in row["choices"]:
			var got: Dictionary = Cards.choose(row["state"], _cards["tables"], int(row["card"]["uid"]), int(answer["index"]))
			_same(answer["after"], got, "%s/answer-%d" % [row["name"], int(answer["index"])])
			count += 1
	assert_gte(count, 130)


func test_conditions_cooldown_repeat_and_chain_limit_match_s1() -> void:
	_definitions()
	for row: Dictionary in _cards["parts"]:
		if str(row["name"]).begins_with("pool/"): _part(row)
	# The chain limit (3) and cooldown (5) each on their own, and which side lets the event in.
	var inside: Dictionary = {"pool/chain-2-gap-9": true, "pool/chain-3-gap-9": false, "pool/chain-0-gap-4": false, "pool/chain-0-gap-5": true}
	for row: Dictionary in _cards["parts"]:
		if inside.has(row["name"]):
			assert_eq((row["result"] as Array).has("port_front_a"), inside[row["name"]], str(row["name"]))
			inside.erase(row["name"])
	assert_eq(inside.keys(), [], "every chain and cooldown edge is compared")


func test_placeholders_and_binding_rng_order_match_s1() -> void:
	_definitions()
	for row: Dictionary in _cards["texts"]: assert_eq(Content.fill_text(row["text"], row["vals"]), row["result"])
	for row: Dictionary in _cards["parts"]:
		if str(row["name"]).begins_with("add/"): _part(row)


func test_followup_front_order_trigger_recheck_away_and_deal_ticks_match_s1() -> void:
	_definitions()
	for row: Dictionary in _cards["parts"]:
		if str(row["name"]).get_slice("/", 0) in ["followup", "away", "deal", "secret"]: _part(row)


func test_weighted_and_uniform_draws_match_s1_with_one_rng_draw() -> void:
	for row: Dictionary in _cards["draws"]:
		var g: Dictionary = row["before"].duplicate(true)
		var extra: Array = []
		for ev: Dictionary in Content.content_pool(g, _cards["tables"]): extra.append("content:" + str(ev["id"]))
		_same(row["extra"], extra, "ordered content pool")
		var rng_before: Dictionary = g["rng"].duplicate(true)
		for weight: Dictionary in row["weights"]:
			assert_almost_eq(Travel.travel_weight(g, _cards["tables"], weight["id"], row["recent"]), float(weight["weight"]), 0.000000001, weight["id"])
		_same(rng_before, g["rng"], "weights consume no RNG")
		assert_eq(Travel.draw_event(g, _cards["tables"], extra), row["id"])
		_same(row["after"], g, "weighted/uniform full draw result")
		if not row["before"].get("eventPack", false): assert_eq(extra, [], "pack is absent when off")


func test_existing_pack_off_departures_stay_identical() -> void:
	var checked: int = 0
	for path: String in ["res://tests/fixtures/train/turn_vectors.json", "res://tests/fixtures/train/turn_vectors_climate.json"]:
		var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for run: Dictionary in old["runs"]:
			for row: Dictionary in run["steps"]:
				if row["action"]["kind"] != "advance" or row["before"]["phase"] != "prep": continue
				assert_false(row["before"].get("eventPack", false))
				_same(row["after"], Advance.advance(row["before"], old["tables"]), "pack-off/%s/%d" % [run["seed"], int(row["step"])])
				checked += 1
	assert_gt(checked, 8)


func test_real_new_board_enables_pack_without_changing_start_asset() -> void:
	var raw: String = FileAccess.get_file_as_string("res://game/train/slice_start.json")
	var original: Dictionary = JSON.parse_string(raw)
	var board: Array = SliceFlow.start_board()
	assert_true(board[0]["eventPack"])
	assert_true(board[0]["lateOn"])
	assert_false(original["state"].get("eventPack", false))
	var expected: Dictionary = original["state"].duplicate(true)
	expected["lateOn"] = true
	expected["eventPack"] = true
	_same(expected, board[0], "only real-new-game flags")
	assert_eq(FileAccess.get_file_as_string("res://game/train/slice_start.json"), raw)


func test_content_state_survives_json_save_read_and_next_tick() -> void:
	_definitions()
	var original: Dictionary = _cards["save"]["before"].duplicate(true)
	var result: Dictionary = SaveSlot.read_save(JSON.parse_string(JSON.stringify(original)), _cards["tables"])
	assert_true(result["ok"])
	if not result["ok"]: return
	var got: Dictionary = result["g"]
	var want: Dictionary = _cards["save"]["after"]
	# Existing save-reader convention: S2 explicitly writes old off/empty late defaults.
	if not want.has("lateOn") and got.get("lateOn") == false: got.erase("lateOn")
	if not want.has("lateCards") and got.get("lateCards") == []: got.erase("lateCards")
	_same(want, got, "S1 readSave after JSON roundtrip")
	_same(_cards["save"]["before"], original, "read_save preserves caller")
	var uninterrupted: Dictionary = want.duplicate(true)
	Content.content_away_tick(uninterrupted)
	Content.content_followup_tick(uninterrupted, _cards["tables"])
	Content.content_away_tick(got)
	Content.content_followup_tick(got, _cards["tables"])
	_same(uninterrupted, got, "same next content tick after loading")
	# Loaded, then on to the segment where the queued follow-up, the deal and the
	# absence are all due: the same as S1 from the same loaded state.
	var due: Dictionary = SaveSlot.read_save(JSON.parse_string(JSON.stringify(original, "", false)), _cards["tables"])["g"]
	var next: Dictionary = _cards["save"]["next"]
	assert_false((original["contentQueue"] as Array).is_empty(), "the save holds a queued follow-up")
	due["seg"] = next["seg"]
	Content.content_away_tick(due)
	Content.content_followup_tick(due, _cards["tables"])
	if not next.has("lateOn") and due.get("lateOn") == false: due.erase("lateOn")
	if not next.has("lateCards") and due.get("lateCards") == []: due.erase("lateCards")
	_same(next, due, "S1 ticks at the due segment after loading")


## S1 reads content fields with `??`: null in a save reads as none, and the next
## tick and the card still work. A save keeps key order as S1's JSON does, so a
## tie picked by insertion order (two laws repealed in one segment) stays put.
func test_null_content_fields_read_as_none_and_saves_keep_key_order() -> void:
	var base: Dictionary = _turns["runs"][0]["steps"][0]["before"].duplicate(true)
	var g: Dictionary = base.duplicate(true)
	var keys: Array[String] = ["contentAway", "contentFlags", "contentInjured", "contentDeals", "contentQueue", "contentSecrets"]
	for key: String in keys: g[key] = null
	g["cards"] = [{"uid": 900, "kind": "content", "text": "ev_h09_dropped_food", "comm": "tail", "vals": null}]
	var read: Dictionary = SaveSlot.read_save(JSON.parse_string(JSON.stringify(g)), _turns["tables"])
	assert_true(read["ok"], str(read.get("why", "")))
	if not read["ok"]: return
	var back: Dictionary = read["g"]
	for key: String in keys: assert_false(back.has(key), key + ": null reads as none")
	assert_false((back["cards"][0] as Dictionary).has("vals"), "null vals reads as none")
	Content.content_away_tick(back)
	Content.content_followup_tick(back, _turns["tables"])
	assert_false(Cards.view(back, _turns["tables"], back["cards"][0]).is_empty(), "the card still shows")
	var tie: Dictionary = base.duplicate(true)
	tie["repealedAt"] = {"heat_quota": 2, "child_labor": 2}
	for law: String in tie["repealedAt"]: tie["passed"].erase(law)
	var path: String = "user://test_content_key_order.json"
	assert_true(SaveSlot.save_slot(tie, path))
	var loaded: Dictionary = SaveSlot.read_save(JSON.parse_string(FileAccess.get_file_as_string(path)), _turns["tables"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_true(loaded["ok"])
	if not loaded["ok"]: return
	assert_eq((loaded["g"]["repealedAt"] as Dictionary).keys(), ["heat_quota", "child_labor"], "keys keep their order")
	assert_eq(Content._last_law(loaded["g"], true), Content._last_law(tie, true), "same law after a load")
	assert_eq(Content._last_law(tie, true), "heat_quota", "the first repealed of a tie, as S1")


## Content fields of the wrong shape are refused at the door, with a reason;
## null is none (the test above).
func test_content_fields_of_a_wrong_shape_are_refused() -> void:
	var base: Dictionary = _turns["runs"][0]["steps"][0]["before"]
	for patch: Dictionary in [{"eventPack": 1}, {"contentFlags": []}, {"contentAway": "x"}, {"contentSecrets": 3},
		{"contentInjured": {}}, {"contentQueue": {}}, {"contentDeals": "x"},
		{"contentQueue": [{"id": 3, "at": 2}]}, {"contentQueue": [{"id": "port_front_a", "at": "2"}]}, {"contentQueue": ["port_front_a"]},
		{"contentDeals": [{"id": "port_deal_def", "comm": "tail"}]},
		{"cards": [{"uid": 1, "kind": "content", "text": "ev_h09_dropped_food", "comm": "tail", "vals": []}]}]:
		var g: Dictionary = base.duplicate(true)
		g.merge(patch, true)
		var read: Dictionary = SaveSlot.read_save(g, _turns["tables"])
		assert_false(read["ok"], str(patch))
		assert_ne(str(read.get("why", "")), "", str(patch) + " says why")


func test_out_of_scope_branches_still_reject_actions() -> void:
	var initial: Dictionary = _turns["runs"][0]["steps"][0]["before"].duplicate(true)
	initial["cards"] = []
	initial["phase"] = "prep"
	for key: String in ["dark", "disasters", "arrivals"]:
		var g: Dictionary = initial.duplicate(true)
		g[key] = true
		assert_true(str(Advance.advance(g, _turns["tables"]).get("_turn_port_error", "")).begins_with("F-NOT-PORTED"), key)
	var stranded: Dictionary = initial.duplicate(true)
	stranded["stranded"] = {}
	assert_true(str(Advance.advance(stranded, _turns["tables"]).get("_turn_port_error", "")).begins_with("F-NOT-PORTED"), "stranded")
	var death_weight: Dictionary = _cards["views"][0]["state"].duplicate(true)
	death_weight["deathWeight"] = true
	assert_true(str(Cards.choose(death_weight, _cards["tables"], int(death_weight["cards"][0]["uid"]), 0).get("_turn_port_error", "")).begins_with("F-NOT-PORTED"), "deathWeight")
