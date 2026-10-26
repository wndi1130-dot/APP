extends GutTest
## The cost pane (cost_pane.gd, J12): pressing coal or food on the gauges shows
## what this stretch will cost and why, beside what the last settle put down
## and why, in the same causes and the same split.

const CostPane = preload("res://game/ui/cost_pane.gd")
const TrainGauges = preload("res://game/ui/train_gauges.gd")
const StopPickCard = preload("res://game/ui/stop_pick_card.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const Settle = preload("res://game/train/turn/turn_settle.gd")
const St = preload("res://game/train/train_state.gd")
const TrainDom = preload("res://game/train/train_dom.gd")
const TrainTurn = preload("res://game/train/train_turn.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")

const MIN_TOUCH: float = 79.0


func after_each() -> void:
	await wait_process_frames(1)


func _sample() -> Array:
	var s: Array = StopPickCard.sample()
	var g: Dictionary = (s[0] as Dictionary).duplicate(true)
	g.erase("lastSettle")
	return [g, s[1]]


func _row(m: Dictionary, why: String) -> Dictionary:
	for r: Dictionary in m["rows"]:
		if r["why"] == why:
			return r
	return {}


## This stretch's rows are the forecast split over its causes, in S1's words,
## and they add up to what the band burns.
func test_this_stretch_is_the_forecast_by_cause() -> void:
	var s: Array = _sample()
	for key: String in ["coal", "food"]:
		var m: Dictionary = CostPane.model(s[0], s[1], key)
		assert_almost_eq(float(m["now"]), -float(TrainTurn.forecast(s[0], s[1])[key]), 1e-9, key)
		var sum := 0.0
		for r: Dictionary in m["rows"]:
			sum += float(r["now"])
			assert_ne(String(r["word"]), String(r["why"]), "%s reads as words" % r["why"])
		assert_almost_eq(sum, float(m["now"]), 0.05 * CostPane.WHY_NAME.size(), key + " rows add up")
		assert_null(m["last"], "no settle yet")
	assert_eq(String(_row(CostPane.model(s[0], s[1], "coal"), "run")["word"]), "기관 운행")
	assert_eq(String(_row(CostPane.model(s[0], s[1], "food"), "ration")["word"]), "배급")


## After the stretch the ledger reads the same causes with the same numbers
## the forecast showed before it: every settle in S1's whole-state record
## (tests/fixtures/train/turn_vectors.json), run from the state it starts on.
func test_after_the_stretch_last_reads_what_this_said() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/train/turn_vectors.json"))
	var t: Dictionary = data["tables"]
	var settles: int = 0
	for run: Dictionary in data["runs"]:
		for step: Dictionary in run["steps"]:
			if step["after"].get("lastSettle") == step["before"].get("lastSettle"):
				continue
			var g: Dictionary = step["before"]
			var before: Dictionary = {"coal": CostPane.model(g, t, "coal"), "food": CostPane.model(g, t, "food")}
			var after: Dictionary = Settle.settle(g, t)
			if after.has("_turn_port_error"):
				continue
			settles += 1
			for key: String in ["coal", "food"]:
				var m: Dictionary = CostPane.model(after, t, key)
				for r: Dictionary in before[key]["rows"]:
					var now_row: Dictionary = _row(m, String(r["why"]))
					assert_false(now_row.is_empty(), "%s %s still listed" % [key, r["why"]])
					if now_row.is_empty():
						continue
					assert_almost_eq(float(now_row["last"]), float(r["now"]), 1e-9, "%s %s: last = what this stretch said" % [key, r["why"]])
				assert_almost_eq(float(m["last"]), float(after["lastSettle"][key]), 1e-9, key + " total is the settle's")
				assert_null(m["rest"], key + ": the settle's lines are all named")
	assert_gt(settles, 10, "settles run from the record")


## Insulated cars: under 칸 난방 what they keep off this stretch's heating, the
## heating with no car insulated less the heating as it is.
func test_insulated_cars_show_what_they_keep_off_the_heating() -> void:
	var s: Array = _sample()
	var g: Dictionary = s[0]
	var t: Dictionary = s[1]
	g["comms"]["tail"]["heat"] = 3
	g["dom"] = TrainDom.start()
	assert_false(_row(CostPane.model(g, t, "coal"), "heat").has("saved"), "nothing insulated, no line")
	g["dom"]["insulated"] = ["tail1"]
	var heat: Dictionary = _row(CostPane.model(g, t, "coal"), "heat")
	assert_true(heat.has("saved"))
	var bare: Dictionary = g.duplicate(true)
	bare["dom"]["insulated"] = []
	var kept: float = TrainTurn.heat_cost(bare, t) - TrainTurn.heat_cost(g, t)
	assert_almost_eq(float(heat["saved"]), kept * St.law_mult(g, t, "heatMult"), 1e-9)
	assert_gt(float(heat["saved"]), 0.0)


## The ledger's lines for one cause are read once, from the newest settle's
## block; lines of the same stock for other causes end it.
func test_the_last_settle_s_block_is_read_from_the_ledger() -> void:
	var parts: Array = [["run", 1.0], ["heat", 1.0]]
	var g := {"ledger": [
		{"k": "coal", "d": -9.0, "why": "run"}, {"k": "coal", "d": -9.0, "why": "heat"},
		{"k": "trust", "d": 1.0, "why": "drift"},
		{"k": "coal", "d": -4.0, "why": "run"}, {"k": "coal", "d": -6.0, "why": "heat"},
		{"k": "food", "d": -3.0, "why": "ration"}, {"k": "coal", "d": -2.0, "why": "stop.stay"},
	]}
	assert_eq(CostPane.settle_rows(g, "coal", parts), {"run": -4.0, "heat": -6.0})
	assert_eq(CostPane.settle_rows({}, "coal", parts), {})


## The pane draws the model: the stock's word, the total in both columns, a
## row per cause; 「–」 before the first settle; 접기 folds it.
func test_the_pane_draws_the_model_and_folds() -> void:
	var s: Array = _sample()
	var p = CostPane.new()
	p.which = "coal"
	add_child_autofree(p)
	p.pin(TrainGauges.BAND_H)
	p.show_state(s[0], s[1])
	var m: Dictionary = CostPane.model(s[0], s[1], "coal")
	assert_eq((p.find_child("Name", true, false) as Label).text, "석탄")
	assert_eq((p.find_child("Total_now", true, false) as Label).text, CostPane.signed(float(m["now"])))
	assert_eq((p.find_child("Total_last", true, false) as Label).text, "–")
	assert_not_null(p.find_child("Row_run", true, false))
	assert_almost_eq(p.size.y / UiFonts.K, CostPane.CSS_SIZE.y, 0.5)
	watch_signals(p)
	(p.find_child("Fold", true, false) as Button).pressed.emit()
	assert_signal_emitted(p, "folded")


## Coal and food on the gauges are keys a finger can press; the rest are not.
func test_coal_and_food_on_the_gauges_are_keys() -> void:
	var s: Array = _sample()
	var holder := Control.new()
	holder.size = Vector2(844.0, 390.0) * UiFonts.K
	add_child_autofree(holder)
	var gauges = TrainGauges.new()
	gauges.g = s[0]
	gauges.t = s[1]
	holder.add_child(gauges)
	await wait_process_frames(1)
	watch_signals(gauges)
	for id: String in ["coal", "food"]:
		var tap := gauges.find_child("Tap_" + id, true, false) as Button
		assert_not_null(tap, id)
		assert_gte(tap.size.y, MIN_TOUCH, id + " is a finger high")
		tap.pressed.emit()
		assert_signal_emitted_with_parameters(gauges, "stock_pressed", [id])
	assert_null(gauges.find_child("Tap_med", true, false))


## On the train's home the cost pane stands where the rooms do: the car's pane
## makes way, the other stock takes its place, the same stock folds it and the
## car picked before comes back.
func test_the_slice_opens_the_cost_pane_from_the_gauges() -> void:
	var f = SliceFlow.new()
	f.opts = {"skip_field": true, "seed": 3, "cinema": false}
	add_child_autofree(f)
	await wait_process_frames(1)
	assert_eq(f.current(), "train")
	var was: String = f.sel
	# A finger's way: the band's own key, whose press draws the band again under it.
	(f.gauges.find_child("Tap_coal", true, false) as Button).pressed.emit()
	await wait_process_frames(1)
	assert_true(is_instance_valid(f.cost), "the cost pane is up")
	assert_not_null(f.gauges.find_child("Tap_coal", true, false), "the band drew its keys again")
	assert_eq(String(f.cost.name), "CostPane")
	assert_eq(String(f.cost.which), "coal")
	assert_false(f.pane.visible, "the car's pane makes way")
	assert_eq(f.gauges.focus, ["coal"], "the band keeps the stock it is about lit")
	f.gauges.stock_pressed.emit("food")
	await wait_process_frames(1)
	assert_eq(String(f.cost.which), "food", "the other stock takes its place")
	f.gauges.stock_pressed.emit("food")
	await wait_process_frames(1)
	assert_false(is_instance_valid(f.cost), "the same stock folds it")
	assert_eq(f.gauges.focus, [], "folded, the band is all lit again")
	assert_eq(f.sel, was, "folding brings back the car picked before")
	f._open_room("papers")
	f.gauges.stock_pressed.emit("coal")
	await wait_process_frames(1)
	assert_false(is_instance_valid(f.research), "one room at a time")


## A technology that makes an ideal law cheaper (E3 가 under 공동 난방) takes
## coal off the stretch as 「열차 살림」, and the settle lays that saving down
## the same way the pane said it would.
func test_a_technology_s_saving_is_the_same_cause_before_and_after() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/train/turn_vectors.json"))
	var t: Dictionary = data["tables"]
	var g: Dictionary = {}
	for run: Dictionary in data["runs"]:
		for step: Dictionary in run["steps"]:
			if g.is_empty() and step["after"].get("lastSettle") != step["before"].get("lastSettle"):
				g = (step["before"] as Dictionary).duplicate(true)
	g["dom"] = TrainDom.start()
	g["dom"]["techs"]["e3"] = {"stage": "done", "defect": false, "progress": 2, "need": 2, "variant": "a"}
	g["passed"]["common_heating"] = 0
	var before: Dictionary = CostPane.model(g, t, "coal")
	var saving: Dictionary = _row(before, "upkeep")
	assert_false(saving.is_empty(), "the saving has a row")
	assert_gt(float(saving["now"]), 0.0, "it gives coal back")
	assert_eq(String(saving["word"]), "열차 살림")
	var after: Dictionary = Settle.settle(g, t)
	assert_false(after.has("_turn_port_error"), str(after.get("_turn_port_error", "")))
	var m: Dictionary = CostPane.model(after, t, "coal")
	for r: Dictionary in before["rows"]:
		assert_almost_eq(float(_row(m, String(r["why"]))["last"]), float(r["now"]), 1e-9, String(r["why"]))
	assert_null(m["rest"])
