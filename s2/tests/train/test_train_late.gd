extends GutTest
const Late = preload("res://game/train/turn/turn_late.gd")
const Cards = preload("res://game/train/turn/turn_cards.gd")
const Text = preload("res://game/train/turn/turn_card_text.gd")
const SaveSlot = preload("res://game/politics/save_slot.gd")
const V = preload("res://tests/train/train_vectors.gd")
const Budget = preload("res://game/train/turn/turn_budget.gd")
var _t: Dictionary
var _base: Dictionary


func before_all() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/train/turn_vectors.json"))
	_t = data["tables"]
	_base = data["runs"][0]["steps"][0]["before"]


func test_same_values_and_harm_only_growth() -> void:
	assert_eq(Late.LATE, {"max": 2, "margin": 2, "step": 2, "grow": 0.5})
	for key: String in ["coal", "food", "med", "lux", "trust"]:
		assert_eq(Late.grow_eff([key, -3], 1), [key, -5.0])
		assert_eq(Late.grow_eff([key, 3], 2), [key, 3])
	for key: String in ["tension", "fear", "injured"]:
		assert_eq(Late.grow_eff([key, 3], 1), [key, 5.0])
	for e: Array in [["base", "tail", 3, 3], ["lever", "tail", "heat", -1], ["debt", "tail"], ["grudge", "tail"]]:
		assert_eq(Late.grow_eff(e, 2), e)
	assert_eq(Late.grow_eff(["rel", "tail", -3], 1), ["rel", "tail", -5.0])
	assert_eq(Late.grow_eff(["pop", "tail", -3], 1), ["pop", "tail", -5.0])
	assert_eq(Late.grow_eff(["fervor", "tail", 3], 1), ["fervor", "tail", 5.0])


func test_worst_uses_target_community_and_keeps_first_tie_even_when_shut() -> void:
	var choices: Array = [
		{"id": "other", "effs": [["rel", "front", -50]]},
		{"id": "first", "effs": [["rel", "tail", -4]], "disabled": "cost"},
		{"id": "second", "effs": [["rel", "tail", -4]]},
		{"id": "later", "effs": [["rel", "tail", -99]]},
	]
	assert_eq(Late.worst_choice(choices, "tail")["id"], "first")


func test_later_is_last_and_stronger_without_mutating_view_or_game() -> void:
	var g: Dictionary = _base.duplicate(true)
	Late.enable(g)
	for kind: String in ["demand", "favor", "promise_ledger", "ration_cut", "travel"]:
		var previous: float = 0.0
		for n: int in range(3):
			var card := {"uid": 1, "kind": kind, "comm": "front", "text": "front_curtain", "late": n}
			var saved: String = JSON.stringify(g)
			var view: Dictionary = Text.view(g, _t, card)
			var choices: Array = view["choices"]
			var last: Dictionary = choices[-1]
			var worst: Dictionary = Late.worst_choice(choices, Late.comm(card))
			assert_eq(last["id"], "later")
			assert_eq(last["label"], "나중에 정한다")
			var loss: float = Late.loss(last, Late.comm(card))
			assert_eq(loss, Late.loss(worst, Late.comm(card)) + 2.0 + 2.0 * n)
			assert_gt(loss, previous)
			previous = loss
			assert_eq(view, Text.view(g, _t, card))
			assert_eq(JSON.stringify(g), saved)


func test_grown_cost_stops_a_regular_choice() -> void:
	var g: Dictionary = _base.duplicate(true)
	Late.enable(g)
	g["comms"]["engine"]["base"][3] = 100
	g["coal"] = _t["P"]["shiftCoal"]
	g["cards"] = [{"uid": 1, "kind": "demand", "comm": "engine", "late": 1}]
	assert_eq(Text.view(g, _t, g["cards"][0])["choices"][0]["disabled"], "석탄이 모자라다")
	assert_eq(V.full_diffs(g, Cards.choose(g, _t, 1, 0), "blocked grown cost", 10), [])


func test_ordinary_choice_after_two_deferrals_still_works() -> void:
	var g: Dictionary = _base.duplicate(true)
	Late.enable(g)
	g["cards"] = [{"uid": 1, "kind": "favor", "comm": "front", "late": 2}]
	var next: Dictionary = Cards.choose(g, _t, 1, 1)
	assert_eq(next["cards"], [])
	assert_eq(float(next["comms"]["front"]["rel"]), float(g["comms"]["front"]["rel"]) - 6.0)
	assert_eq(next.get("lateCards", []), [])


func test_old_save_is_off_and_empty_without_version_change() -> void:
	var old: Dictionary = _base.duplicate(true)
	old.erase("lateOn"); old.erase("lateCards")
	old["born"] = null
	old["dom"] = null
	assert_false(Budget.gone(old, _t, {"kind": "naming", "who": old["comms"]["tail"]["leader"]["name"]}))
	assert_false(Budget.gone(old, _t, {"kind": "dom:fit", "text": "w8"}))
	var read: Dictionary = SaveSlot.read_save(JSON.parse_string(JSON.stringify(old)), _t)
	assert_true(read["ok"])
	assert_eq(read["g"]["version"], old["version"])
	assert_eq(read["g"]["lateOn"], false)
	assert_eq(read["g"]["lateCards"], [])
	assert_false(old.has("lateOn"), "the input save is preserved")


func test_save_keeps_the_queue_and_live_card_count() -> void:
	var g: Dictionary = _base.duplicate(true)
	Late.enable(g)
	g["cards"] = [{"uid": 1, "kind": "promise_ledger", "comm": "tail", "late": 2}]
	g["lateCards"] = [{"uid": 2, "kind": "favor", "comm": "front", "late": 1, "who": g["comms"]["front"]["leader"]["personId"]}]
	Late.enable(g)
	var read: Dictionary = SaveSlot.read_save(JSON.parse_string(JSON.stringify(g)), _t)
	assert_true(read["ok"])
	assert_eq(V.full_diffs(g["lateCards"], read["g"]["lateCards"], "saved queue", 10), [])
	assert_eq(V.full_diffs(g["cards"], read["g"]["cards"], "saved live card", 10), [])
	Late.next_segment(g, _t); Late.next_segment(read["g"], _t)
	assert_eq(V.full_diffs(g["cards"], read["g"]["cards"], "return after save", 10), [])


func test_save_rejects_bad_late_fields() -> void:
	for patch: Dictionary in [{"lateOn": 1}, {"lateCards": {}}, {"lateCards": [{"uid": 1, "kind": "rescue", "late": 1}]},
		{"cards": [{"uid": 1, "kind": "favor", "late": 3}]}, {"cards": [{"uid": 1, "kind": "favor", "late": -1}]},
		{"cards": [{"uid": 1, "kind": "favor", "late": 0.5}]}, {"cards": [{"uid": 1, "kind": "favor", "late": "1"}]},
		# A broken kind is refused, not read as a string; a null place is not a car.
		{"lateCards": [{"uid": 1, "kind": 7, "late": 1}]}, {"lateCards": [{"uid": 1, "kind": null, "late": 1}]},
		{"lateCards": [{"uid": 1, "kind": ["favor"], "late": 1}]}, {"lateCards": [{"uid": 1, "kind": "favor", "comm": null, "late": 1}]}]:
		var g: Dictionary = _base.duplicate(true)
		g.merge(patch, true)
		assert_false(SaveSlot.read_save(g, _t)["ok"], str(patch))
