extends "res://addons/gut/test.gd"
## The train's gauges along the top (train_gauges.gd): they say what the
## train's own numbers say (the state, train_turn.gd forecast and standings),
## mark the 조심 구간 as the tokens set them, and dim what a sheet is not about.

const TrainGauges = preload("res://game/ui/train_gauges.gd")
const TrainTurn = preload("res://game/train/train_turn.gd")
const StopPickCard = preload("res://game/ui/stop_pick_card.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const TrainClimate = preload("res://game/train/train_climate.gd")


func test_the_strip_says_the_trains_numbers() -> void:
	var s: Array = StopPickCard.sample()
	var g: Dictionary = s[0]
	var t: Dictionary = s[1]
	var m: Dictionary = TrainGauges.model(g, t)
	assert_eq(m["trust"], int(round(float(g["trust"]))))
	assert_eq(m["tension"], int(round(float(g["tension"]))))
	var stand: Dictionary = TrainTurn.standings(g, t)
	assert_eq([m["unrest"], m["neutral"], m["support"]], [int(stand["unrest"]), int(stand["neutral"]), int(stand["support"])])
	var cost: Dictionary = TrainTurn.forecast(g, t)
	for st: Dictionary in m["stocks"]:
		var id: String = st["id"]
		assert_eq(st["n"], int(round(float(g.get(id, 0)))), id)
		if cost.has(id) and float(cost[id]) > 0.0:
			assert_eq(st["left"], int(floor(float(g.get(id, 0)) / float(cost[id]))), id + ": stretches it lasts, off the store as it is")
			assert_true(String(st["line"]).ends_with("%d구간" % int(st["left"])), st["line"])
		else:
			assert_eq(st["line"], "", id + ": no cost, no line")


func test_the_zones_are_the_tokens() -> void:
	assert_eq([TrainGauges.level("trust", 45), TrainGauges.level("trust", 44), TrainGauges.level("trust", 29)], [0, 1, 2], "trust: 주의 under 45, 위험 under 30")
	assert_eq([TrainGauges.level("tension", 50), TrainGauges.level("tension", 51), TrainGauges.level("tension", 71)], [0, 1, 2], "tension: 주의 over 50, 위험 over 70")


func test_a_stock_three_stretches_from_empty_is_short() -> void:
	var s: Array = StopPickCard.sample()
	var g: Dictionary = (s[0] as Dictionary).duplicate(true)
	var t: Dictionary = s[1]
	var per: float = float(TrainTurn.forecast(g, t).get("coal", 0.0))
	assert_gt(per, 0.0, "coal is burnt each stretch")
	g["coal"] = int(floor(per * 3.0))
	var coal: Dictionary = (TrainGauges.model(g, t)["stocks"] as Array)[0]
	assert_true(bool(coal["short"]), "three stretches left: short")
	g["coal"] = int(ceil(per * 5.0))
	coal = (TrainGauges.model(g, t)["stocks"] as Array)[0]
	assert_false(bool(coal["short"]))


func test_numbers_are_whole_or_to_one_place() -> void:
	assert_eq(TrainGauges._num(10.0), "10")
	assert_eq(TrainGauges._num(8.5), "8.5")


## The slice's first board (climate on, 첫 추위, stretch 1, no weather yet).
func _start() -> Array:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/train/slice_start.json"))
	return [(d["state"] as Dictionary).duplicate(true), d["tables"]]


func test_the_thermometer_reads_the_trains_climate() -> void:
	var s: Array = _start()
	var g: Dictionary = s[0]
	var t: Dictionary = s[1]
	var o: Dictionary = TrainGauges.model(g, t)["outside"]
	assert_eq([o["name"], o["text"], o["freezing"]], ["첫 추위", "−3°", false], "stretch 1's midday, no weather")
	g["stop"] = {"weather": "snow"}
	assert_eq(TrainGauges.model(g, t)["outside"]["text"], "−5°", "snow takes two more")
	g["stop"] = null
	g["lastStop"] = {"weather": "sleet"}
	assert_eq(TrainGauges.model(g, t)["outside"]["text"], "2°", "between stops the last stop's weather")
	g["freeze"] = 1
	assert_true(bool(TrainGauges.model(g, t)["outside"]["freezing"]), "a frozen track")
	g["climate"] = false
	assert_null(TrainGauges.model(g, t)["outside"], "climate off: no thermometer")


func test_the_column_stands_by_the_stages() -> void:
	var temps: Array = _start()[1]["CL"]["temp"]
	assert_almost_eq(TrainGauges.ot_fill(temps, float(temps[0])), 0.9, 0.001, "the warmest stage at the top tick")
	assert_almost_eq(TrainGauges.ot_fill(temps, float(temps[temps.size() - 1])), 0.29, 0.001, "the coldest at the bottom tick")
	assert_gt(TrainGauges.ot_fill(temps, -3.0), TrainGauges.ot_fill(temps, -15.0), "colder stands lower")
	assert_almost_eq(TrainGauges.ot_fill(temps, -80.0), 0.18, 0.001, "never under the bulb")
	assert_eq([TrainGauges.deg(-3.0), TrainGauges.deg(5.0), TrainGauges.deg(0.0)], ["−3°", "5°", "0°"])


func test_the_thermometer_sits_after_tension() -> void:
	var s: Array = _start()
	s[0]["freeze"] = 1
	var strip = TrainGauges.new()
	strip.g = s[0]
	strip.t = s[1]
	add_child_autofree(strip)
	var o: Control = strip.find_child("Outside", true, false)
	assert_not_null(o)
	assert_not_null(o.find_child("Frozen", true, false), "the snow mark while frozen")
	var tension: Control = strip.find_child("MeterTension", true, false)
	assert_almost_eq(o.position.x - (tension.position.x + tension.size.x), 10.0 * UiFonts.K, 0.01, "10 after tension")
	var frozen_w: float = o.size.x
	s[0]["freeze"] = 0
	strip.refresh(s[0], s[1])
	o = strip.find_child("Outside", true, false)
	assert_null(o.find_child("Frozen", true, false))
	assert_almost_eq(o.size.x, frozen_w, 0.01, "the snow mark sits on the bulb and takes no width")


func test_while_a_sheet_is_up_only_what_it_is_about_stays_lit() -> void:
	var s: Array = StopPickCard.sample()
	var strip = TrainGauges.new()
	strip.g = s[0]
	strip.t = s[1]
	add_child_autofree(strip)
	assert_not_null(strip.find_child("MeterTrust", true, false))
	assert_not_null(strip.find_child("Stock_coal", true, false))
	strip.set_focus(["coal", "food"])
	assert_true(strip._dim("trust"))
	assert_false(strip._dim("coal"))
	var c: Color = TrainGauges.tone(TrainGauges.RED, true)
	assert_almost_eq(c.a, 0.3, 0.001, "a third of its alpha")
	assert_eq(TrainGauges.tone(TrainGauges.RED, false), TrainGauges.RED)


## otempTo: 80 ms a degree, a degree at a time, the stage's name when the tick is passed.
func test_the_number_rolls_a_degree_at_a_time() -> void:
	var temps: Array = _start()[1]["CL"]["temp"]
	var p: Dictionary = TrainGauges.roll_plan(4.0, -3.0, 0, 1, temps)
	assert_almost_eq(float(p["ms"]), 560.0, 0.001, "seven degrees, 80 ms each")
	var cross: Array = p["cross"]
	assert_eq(cross.size(), 1)
	assert_almost_eq(float(cross[0][0]), 560.0, 0.001, "첫 추위's tick at the end")
	assert_eq(int(cross[0][1]), 1)
	assert_almost_eq(TrainGauges.shown_temp(p, 280.0), 1.0, 0.001, "halfway: 1°")
	assert_almost_eq(TrainGauges.shown_temp(p, 560.0), -3.0, 0.001, "the new reading at the end")
	assert_eq([TrainGauges.shown_stage(p, 559.0), TrainGauges.shown_stage(p, 560.0)], [0, 1], "the name changes as the tick is passed")
	var q: Dictionary = TrainGauges.roll_plan(-3.0, -5.0, 1, 1, temps)
	assert_almost_eq(float(q["ms"]), 160.0, 0.001)
	assert_eq((q["cross"] as Array).size(), 0, "the same stage: no tick to pass")


func test_a_new_reading_rolls_the_thermometer() -> void:
	var s: Array = _start()
	var strip = TrainGauges.new()
	strip.g = s[0]
	strip.t = s[1]
	add_child_autofree(strip)
	assert_true((strip._ot_plan as Dictionary).is_empty(), "the first board does not roll")
	var g2: Dictionary = (s[0] as Dictionary).duplicate(true)
	g2["stop"] = {"weather": "snow"}
	strip.refresh(g2, s[1])
	assert_false((strip._ot_plan as Dictionary).is_empty(), "snow: a roll from −3° to −5°")
	var t0: int = strip._ot_t0
	assert_eq(strip._ot_state(t0)["text"], "−3°")
	assert_eq(strip._ot_state(t0 + 80)["text"], "−4°")
	assert_eq(strip._ot_state(t0 + 160)["text"], "−5°")
	assert_eq(strip._ot_state(t0 + 160)["delta_text"], "▼2°")
	assert_not_null(strip.find_child("OtDelta", true, false), "the change is there before it floats up")
	var end: Dictionary = strip._ot_state(t0 + 3000)
	var o: Dictionary = TrainGauges.model(g2, s[1])["outside"]
	assert_eq([end["text"], end["name"]], [o["text"], o["name"]], "over: the reading itself")
	assert_almost_eq(float(end["fill"]), float(o["fill"]), 0.0001)
	assert_eq([float(end["delta_p"]), float(end["puff"]), float(end["stamp"])], [-1.0, -1.0, -1.0], "nothing left moving")


## A 16:9 screen (1280 wide, 693 of the mockup's px) narrows the bars so the
## thermometer ends before the mood (235.7); a wider one keeps them as they were.
func test_a_narrow_band_packs_the_left_gauges() -> void:
	var s: Array = _start()
	var strip = TrainGauges.new()
	strip.g = s[0]
	strip.t = s[1]
	add_child_autofree(strip)
	var k: float = UiFonts.K
	# Off the screen's width (the band spans it), so the test sets it.
	strip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	strip.size = Vector2(1280, TrainGauges.BAND_H)
	strip._lay_out()
	var trust: Control = strip.find_child("MeterTrust", true, false)
	assert_almost_eq(trust.size.x, 66.0 * k, 0.01, "narrow bars")
	var o: Control = strip.find_child("Outside", true, false)
	assert_null(o.find_child("Stage", true, false), "no stage name on a narrow band")
	assert_lte(o.position.x + o.size.x, 230.0 * k, "the thermometer ends before the mood")
	strip.size = Vector2(1558, TrainGauges.BAND_H)
	strip._lay_out()
	trust = strip.find_child("MeterTrust", true, false)
	assert_almost_eq(trust.size.x, 104.0 * k, 0.01, "wide bars")
	o = strip.find_child("Outside", true, false)
	assert_not_null(o.find_child("Stage", true, false), "the stage's name on a wide band")


## 결정 483: the slip says how the reading is made and the heating coal's
## multiple, in the board's own numbers.
func test_the_slip_says_how_the_reading_is_made() -> void:
	var s: Array = _start()
	var g: Dictionary = s[0]
	var t: Dictionary = s[1]
	var o: Dictionary = TrainGauges.model(g, t)["outside"]
	assert_eq(TrainGauges.why_text(o, t), "바깥 −3° = 첫 추위 −3° | 난방 석탄 ×0.9", "no weather yet: no weather part")
	g["stop"] = {"weather": "snow"}
	o = TrainGauges.model(g, t)["outside"]
	assert_eq(TrainGauges.why_text(o, t), "바깥 −5° = 첫 추위 −3° · 눈 −2° | 난방 석탄 ×0.9")
	assert_eq(float(o["base"]), TrainClimate.seg_temp(t, int(g["seg"])), "the stretch's midday")
	assert_eq(float(o["base"]) + float(o["weather_temp"]), float(o["temp"]), "the parts make the reading")
	assert_eq(float(o["mult"]), TrainClimate.temp_mult(g, t), "the multiple heat_cost takes")
	assert_eq(TrainGauges.why_text(o, t), "바깥 %s = 첫 추위 %s · 눈 %s | 난방 석탄 ×%s" % [TrainGauges.deg(float(o["temp"])),
		TrainGauges.deg(float(o["base"])), TrainGauges.sdeg(float(o["weather_temp"])), TrainClimate._js(TrainClimate.temp_mult(g, t))])


## 결정 351 under 483: the slip tells nothing ahead — on stretch 16 (늦가을,
## 17 turns 첫 추위) neither the next stage nor the next stretch's temperature.
func test_the_slip_tells_nothing_ahead() -> void:
	var s: Array = _start()
	var g: Dictionary = s[0]
	var t: Dictionary = s[1]
	g["seg"] = 16
	g["outside"] = 0
	g["stop"] = {"weather": "clear"}
	assert_eq(TrainClimate.stage_at(t, 17), 1, "the stage turns on the next stretch")
	var o: Dictionary = TrainGauges.model(g, t)["outside"]
	var text: String = TrainGauges.why_text(o, t)
	assert_eq(String(o["name"]), "늦가을")
	assert_false(text.contains("첫 추위"), "not the next stage: " + text)
	var ahead: float = TrainClimate.seg_temp(t, 17)
	if not is_equal_approx(ahead, float(o["base"])) and not is_equal_approx(ahead, float(o["temp"])):
		assert_false(text.contains(" " + TrainGauges.deg(ahead)), "not the next stretch's temperature: " + text)


func test_a_press_on_the_thermometer_puts_up_its_slip() -> void:
	var s: Array = _start()
	var strip = TrainGauges.new()
	strip.g = s[0]
	strip.t = s[1]
	add_child_autofree(strip)
	(strip.find_child("Tap_outside", true, false) as Button).pressed.emit()
	assert_not_null(strip.find_child("Why", true, false), "a press puts it up")
	strip.set_focus(["coal"])
	assert_not_null(strip.find_child("Why", true, false), "a sheet's focus keeps it up")
	(strip.find_child("Tap_outside", true, false) as Button).pressed.emit()
	assert_null(strip.find_child("Why", true, false), "a press again folds it")
	(strip.find_child("Tap_outside", true, false) as Button).pressed.emit()
	assert_not_null(strip.find_child("Why", true, false))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(20, 700)
	strip._input(press)
	assert_null(strip.find_child("Why", true, false), "a press off it folds it")


func test_the_slip_stays_on_a_narrow_screen() -> void:
	var s: Array = _start()
	s[0]["stop"] = {"weather": "cold_front"}
	var strip = TrainGauges.new()
	strip.g = s[0]
	strip.t = s[1]
	add_child_autofree(strip)
	strip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	strip.size = Vector2(1280, TrainGauges.BAND_H)
	strip._lay_out()
	(strip.find_child("Tap_outside", true, false) as Button).pressed.emit()
	var why: Control = strip.find_child("Why", true, false)
	assert_not_null(why)
	assert_gte(why.position.x, 0.0, "in from the left")
	assert_lte(why.position.x + why.size.x, 1280.0, "in from the right")


## A store's fraction counts: 3.87 stretches of coal is 3 left and short, though
## its number shows rounded up (11.6 coal at 3 a stretch shows 12, lasts 3).
func test_the_stretches_left_come_off_the_store_as_it_is() -> void:
	var s: Array = StopPickCard.sample()
	var g: Dictionary = (s[0] as Dictionary).duplicate(true)
	var t: Dictionary = s[1]
	var per: float = float(TrainTurn.forecast(g, t).get("coal", 0.0))
	assert_gt(per, 0.0)
	g["coal"] = per * 3.87
	var coal: Dictionary = (TrainGauges.model(g, t)["stocks"] as Array)[0]
	assert_eq(coal["left"], 3, "floor of the store itself, not of its rounded number")
	assert_true(bool(coal["short"]), "three left: short")


## The band narrows under 840: at 839 the bars are narrow, just over 840 and at 844 the
## widest reading (첫 추위 at a cold stop, −15°) still ends before the mood.
func test_the_narrow_line_keeps_the_thermometer_off_the_mood() -> void:
	var s: Array = _start()
	s[0]["stop"] = {"weather": "cold"}
	var strip = TrainGauges.new()
	strip.g = s[0]
	strip.t = s[1]
	add_child_autofree(strip)
	strip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var k: float = UiFonts.K
	for css: float in [839.0, 840.5, 844.0]:
		strip.size = Vector2(css * k, TrainGauges.BAND_H)
		strip._lay_out()
		var trust: Control = strip.find_child("MeterTrust", true, false)
		assert_almost_eq(trust.size.x, (66.0 if css < 840.0 else 104.0) * k, 0.01, "bars at %d" % css)
		var o: Control = strip.find_child("Outside", true, false)
		var mood: Control = strip.find_child("Standing", true, false)
		var right: float = 0.0
		for id: String in ["Temp", "Stage"]:
			var l: Control = o.find_child(id, true, false)
			if l != null:
				right = maxf(right, o.position.x + l.position.x + l.size.x)
		assert_lte(right, mood.position.x, "its words end before the mood at %d" % css)
		assert_lte(o.position.x + o.size.x, mood.position.x, "and so does its key at %d" % css)


## A roll to a longer number widens the thermometer and its key with it.
func test_a_roll_to_a_longer_number_widens_the_thermometer() -> void:
	var s: Array = _start()
	var strip = TrainGauges.new()
	strip.g = s[0]
	strip.t = s[1]
	add_child_autofree(strip)
	var g2: Dictionary = (s[0] as Dictionary).duplicate(true)
	g2["stop"] = {"weather": "cold"}
	strip.refresh(g2, s[1])
	var o: Control = strip.find_child("Outside", true, false)
	var before: float = o.size.x
	strip._ot_apply(o, strip._ot_state(strip._ot_t0 + 5000))
	var temp: Control = o.find_child("Temp", true, false)
	assert_eq((temp as Label).text, "−15°")
	assert_gte(o.size.x, temp.position.x + temp.size.x, "the number stays inside it")
	assert_gt(o.size.x, before, "−3° grew to −15°")


## 결정 502: old settles, the newest meter blocks, then choices and small causes.
func _meter_fixture() -> Dictionary:
	var state: Dictionary = _start()[0]
	state["trust"] = 46.0
	state["tension"] = 39.11
	state["ledger"] = [
		{"k": "trust", "d": -9.0, "why": "mood"},
		{"k": "tension", "d": 9.0, "why": "mood"},
		{"k": "tension", "d": 7.0, "why": "law"},
		{"k": "coal", "d": -3.0, "why": "run"},
		{"k": "trust", "d": -1.25, "why": "mood"},
		{"k": "tension", "d": 3.2, "why": "mood"},
		{"k": "tension", "d": 0.2, "why": "short"},
		{"k": "tension", "d": -1.1, "why": "law"},
		{"k": "tension", "d": -0.2, "why": "calm.pot"},
		{"k": "tension", "d": 0.01, "why": "calm.ledger"},
		{"k": "tension", "d": -4.0, "why": "card"},
		{"k": "food", "d": -20.0, "why": "card"},
		{"k": "tension", "d": 0.3, "why": "corpse"},
		{"k": "tension", "d": 0.7, "why": "card"},
		{"k": "trust", "d": -2.75, "why": "card"},
		{"k": "trust", "d": 0.3, "why": "need"},
		{"k": "trust", "d": -0.3, "why": "promise"},
	]
	return state


func _meter_row(m: Dictionary, why: String) -> Dictionary:
	for row: Dictionary in m["rows"]:
		if row["why"] == why:
			return row
	return {}


func _assert_meter_total(m: Dictionary, before: float, now: float) -> void:
	var sum: float = 0.0
	var shown: float = 0.0
	for row: Dictionary in m["rows"]:
		sum += float(row["d"])
		var text: String = row["text"]
		shown += text.get_slice(" ", text.get_slice_count(" ") - 1).replace("−", "-").to_float()
	assert_almost_eq(float(m["before"]), before, 1e-6)
	assert_almost_eq(float(m["now"]), now, 1e-6)
	assert_almost_eq(float(m["total"]), now - before, 1e-6)
	assert_almost_eq(sum, now - before, 1e-6, "all rows, including 기타, equal the actual change")
	assert_almost_eq(shown, snappedf(now, 0.1) - snappedf(before, 0.1), 1e-6, "the displayed shares (one decimal) add up to the shown change")


func test_meter_slips_read_the_latest_settle_and_later_choices() -> void:
	var state: Dictionary = _meter_fixture()
	var untouched: Dictionary = state.duplicate(true)
	var trust: Dictionary = TrainGauges.meter_why_model(state, "trust")
	var tension: Dictionary = TrainGauges.meter_why_model(state, "tension")
	_assert_meter_total(trust, 50.0, 46.0)
	_assert_meter_total(tension, 40.0, 39.11)
	assert_eq(trust["head"], "지난 정산 뒤 신임 50 → 46 (−4)")
	assert_eq(tension["head"], "지난 정산 뒤 긴장 40 → 39 (−0.9)", "values as the bar shows them, the change to one decimal")
	assert_almost_eq(float(_meter_row(tension, "card")["d"]), -3.3, 1e-6, "two choices share one cause")
	assert_almost_eq(float(_meter_row(tension, "other")["d"]), 0.31, 1e-6)
	assert_eq(_meter_row(tension, "mood")["word"], "집단들의 마음", "S1's exact word")
	assert_eq(state, untouched, "the paper never changes game state or ledger rows")


func test_meter_slips_use_the_clamped_ledger_shares_without_rounding_them() -> void:
	var common = load("res://game/train/turn/turn_common.gd")
	var state := {"trust": 1.0, "tension": 98.0}
	common.bump(state, "trust", -2.5, "mood")
	common.bump_parts(state, "tension", 10.0, [["mood", 5.0], ["short", 5.0], ["law", -1.0], ["calm.pot", -1.0], ["cast", 0.0]])
	common.bump(state, "tension", -1.234567891, "card")
	_assert_meter_total(TrainGauges.meter_why_model(state, "trust"), 1.0, 0.0)
	_assert_meter_total(TrainGauges.meter_why_model(state, "tension"), 98.0, float(state["tension"]))
	assert_eq(TrainGauges.meter_signed(-1.234567891), "−1.2")
	assert_eq(TrainGauges.meter_signed(0.0), "+0")
	assert_eq(TrainGauges.meter_signed(0.084166667), "+0.1", "a slip never prints a long tail")


func test_meter_slips_match_the_real_meter_settle_and_a_later_card() -> void:
	var common = load("res://game/train/turn/turn_common.gd")
	for hungry: bool in [false, true]:
		var sample: Array = _start()
		var before: Dictionary = sample[0]
		before["ledger"] = []
		if hungry:
			before["food"] = 0.0
			before["tension"] = 98.0
			for comm: String in sample[1]["COMMS"]:
				before["comms"][comm]["rel"] = -25.0
		var after: Dictionary = TrainTurn.meters(before, sample[1])
		for key: String in ["trust", "tension"]:
			common.bump(after, key, -0.123456789, "card")
			_assert_meter_total(TrainGauges.meter_why_model(after, key), float(before[key]), float(after[key]))


func test_meter_causes_are_summed_before_the_half_point_threshold_and_sorted() -> void:
	var state := {"trust": 49.9, "ledger": [
		{"k": "trust", "d": -2.0, "why": "mood"},
		{"k": "trust", "d": 0.3, "why": "need"}, {"k": "trust", "d": 0.3, "why": "need"},
		{"k": "trust", "d": 0.5, "why": "card"}, {"k": "trust", "d": -0.5, "why": "promise"},
		{"k": "trust", "d": 0.49, "why": "vote"}, {"k": "trust", "d": 0.49, "why": "deal"},
		{"k": "trust", "d": 0.32, "why": "leak"},
	]}
	var m: Dictionary = TrainGauges.meter_why_model(state, "trust")
	var rows: Array = m["rows"]
	assert_eq(rows.map(func(r: Dictionary) -> String: return r["why"]), ["mood", "other", "need", "card", "promise"])
	assert_almost_eq(float(_meter_row(m, "need")["d"]), 0.6, 1e-6, "two small changes become one named cause")
	assert_almost_eq(float(_meter_row(m, "other")["d"]), 1.3, 1e-6, "기타 participates in the sort")
	_assert_meter_total(m, 50.0, 49.9)


func test_drift_is_a_whole_settle_and_adjacent_settles_do_not_join() -> void:
	var state := {"tension": 20.0, "ledger": [
		{"k": "tension", "d": 8.0, "why": "mood"}, {"k": "tension", "d": 2.0, "why": "law"},
		{"k": "tension", "d": -2.0, "why": "drift"}, {"k": "tension", "d": 1.0, "why": "card"},
	]}
	_assert_meter_total(TrainGauges.meter_why_model(state, "tension"), 21.0, 20.0)
	state["ledger"] = [
		{"k": "tension", "d": 8.0, "why": "mood"}, {"k": "tension", "d": 2.0, "why": "law"},
		{"k": "tension", "d": 0.8, "why": "mood"}, {"k": "tension", "d": 0.2, "why": "law"},
		{"k": "tension", "d": -0.5, "why": "card"},
	]
	_assert_meter_total(TrainGauges.meter_why_model(state, "tension"), 19.5, 20.0)


func test_no_meter_rows_say_nothing_changed_and_missing_markers_keep_retained_changes() -> void:
	for ledger: Variant in [null, [], [{"k": "food", "d": -3.0, "why": "ration"}]]:
		for key: String in ["trust", "tension"]:
			var m: Dictionary = TrainGauges.meter_why_model({"ledger": ledger}, key)
			assert_eq(m["head"], "지난 정산 뒤 바뀐 것 없음")
			assert_eq(m["rows"], [])
	var retained := {"trust": 46.0, "ledger": [{"k": "trust", "d": -4.0, "why": "card"}]}
	_assert_meter_total(TrainGauges.meter_why_model(retained, "trust"), 50.0, 46.0)
	var trust: Dictionary = TrainGauges.meter_why_model(_meter_fixture(), "trust")
	assert_eq(_meter_row(trust, "other")["text"], "기타 +0", "opposite small shares are not silently dropped")


func _meter_strip() -> Control:
	var strip = TrainGauges.new()
	strip.g = _meter_fixture()
	strip.t = _start()[1]
	add_child_autofree(strip)
	return strip


func _tap_meter(strip: Control, key: String) -> void:
	(strip.find_child("Tap_" + key, true, false) as Button).pressed.emit()


func test_meter_buttons_draw_the_model_have_finger_targets_and_toggle() -> void:
	var strip: Control = _meter_strip()
	for key: String in ["trust", "tension"]:
		var tap: Button = strip.find_child("Tap_" + key, true, false)
		assert_gte(tap.size.x, 48.0 * UiFonts.K)
		assert_gte(tap.size.y, 48.0 * UiFonts.K)
		_tap_meter(strip, key)
		var why: Control = strip.find_child("Why", true, false)
		assert_not_null(why)
		assert_eq(why.z_index, TrainGauges.OVER_PAPERS)
		var m: Dictionary = TrainGauges.meter_why_model(strip.g, key)
		assert_eq((why.find_child("Head", true, false) as Label).text.replace(UiFonts.WORD_JOINER, ""), m["head"])
		for row: Dictionary in m["rows"]:
			assert_eq((why.find_child("Cause_" + row["why"], true, false) as Label).text.replace(UiFonts.WORD_JOINER, ""), row["text"])
		await wait_process_frames(2)
		var scroll: ScrollContainer = why.find_child("SlipScroll", true, false)
		var lines: Control = why.find_child("SlipRows", true, false)
		assert_lte(lines.size.y, scroll.size.y + 0.5, "a short ledger is fully visible without scrolling")
		_tap_meter(strip, key)
		assert_null(strip.find_child("Why", true, false), "the same key folds it")
	strip.g.erase("ledger")
	_tap_meter(strip, "trust")
	assert_eq((strip.find_child("Head", true, false) as Label).text.replace(UiFonts.WORD_JOINER, ""), "지난 정산 뒤 바뀐 것 없음")


func test_meter_slips_share_one_place_with_the_thermometer_and_keep_focus() -> void:
	var strip: Control = _meter_strip()
	for key: String in ["outside", "tension", "trust", "outside", "trust", "tension"]:
		_tap_meter(strip, key)
		assert_eq(strip._why_key, key)
		assert_eq(strip._parts.find_children("Why", "Control", false, false).size(), 1, "only one slip")
	strip.set_focus(["coal"])
	assert_eq(strip._why_key, "tension")
	assert_not_null(strip.find_child("Why", true, false), "focus redraw keeps the selected slip")
	assert_true(strip._dim("trust"))
	assert_false(strip._dim("coal"))
	strip.refresh(_start()[0], _start()[1])
	assert_eq((strip.find_child("Head", true, false) as Label).text.replace(UiFonts.WORD_JOINER, ""), TrainGauges.meter_why_model(strip.g, "tension")["head"])
	strip.g["climate"] = false
	strip.refresh(strip.g, strip.t)
	assert_not_null(strip.find_child("Why", true, false), "meter slips also work without a thermometer")


func test_mouse_and_touch_off_the_meter_slip_fold_it_but_inside_does_not() -> void:
	var strip: Control = _meter_strip()
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	for key: String in ["trust", "tension"]:
		_tap_meter(strip, key)
		var why: Control = strip.find_child("Why", true, false)
		mouse.position = why.get_global_transform_with_canvas() * Vector2(2, 2)
		strip._input(mouse)
		assert_not_null(strip.find_child("Why", true, false), "inside tilted paper stays open")
		var tap: Control = strip.find_child("Tap_" + key, true, false)
		mouse.position = tap.get_global_rect().get_center()
		strip._input(mouse)
		assert_not_null(strip.find_child("Why", true, false), "the key handles its own toggle")
		mouse.position = Vector2(10, 600)
		strip._input(mouse)
		assert_null(strip.find_child("Why", true, false), "outside mouse folds")
		_tap_meter(strip, key)
		var touch := InputEventScreenTouch.new()
		touch.pressed = true
		touch.position = Vector2(10, 600)
		strip._input(touch)
		assert_null(strip.find_child("Why", true, false), "outside touch folds")


func test_meter_paper_corners_stay_inside_wide_and_narrow_screens() -> void:
	# The 839 mockup-px threshold, both requested sizes, and still smaller bands.
	for resolution: Vector2i in [Vector2i(1688, 780), Vector2i(1280, 720), Vector2i(int(839.0 * UiFonts.K), 720), Vector2i(800, 600), Vector2i(640, 390)]:
		var viewport := SubViewport.new()
		viewport.size = resolution
		add_child_autofree(viewport)
		var strip = TrainGauges.new()
		strip.g = _meter_fixture()
		strip.t = _start()[1]
		viewport.add_child(strip)
		await wait_process_frames(1)
		for key: String in ["trust", "tension"]:
			_tap_meter(strip, key)
			# Complete the entrance before measuring the tilted paper's four corners.
			await wait_seconds(0.35)
			var why: Control = strip.find_child("Why", true, false)
			for point: Vector2 in [Vector2.ZERO, Vector2(why.size.x, 0), why.size, Vector2(0, why.size.y)]:
				var screen: Vector2 = why.get_global_transform_with_canvas() * point
				assert_gte(screen.x, 0.0)
				assert_lte(screen.x, float(resolution.x))
				assert_gte(screen.y, TrainGauges.BAND_H, "paper is below the bar")
				assert_lte(screen.y, float(resolution.y))
			_tap_meter(strip, key)


func test_a_long_meter_ledger_scrolls_inside_the_paper_and_reflows_on_resize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child_autofree(viewport)
	var strip = TrainGauges.new()
	strip.g = _meter_fixture()
	strip.t = _start()[1]
	viewport.add_child(strip)
	strip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	strip.size = Vector2(1280, TrainGauges.BAND_H)
	strip.g["ledger"] = [{"k": "trust", "d": -1.0, "why": "mood"}]
	for why: String in TrainGauges.METER_WHY_NAME:
		if why != "mood":
			strip.g["ledger"].append({"k": "trust", "d": 0.7, "why": why})
	_tap_meter(strip, "trust")
	await wait_process_frames(2)
	var paper: Control = strip.find_child("Why", true, false)
	var scroll: ScrollContainer = paper.find_child("SlipScroll", true, false)
	var lines: Control = paper.find_child("SlipRows", true, false)
	assert_gt(lines.size.y, scroll.size.y, "many causes scroll vertically")
	assert_lte(lines.size.x, scroll.size.x, "words wrap inside the paper")
	strip.size = Vector2(700, TrainGauges.BAND_H)
	strip._lay_out()
	await wait_process_frames(2)
	paper = strip.find_child("Why", true, false)
	assert_eq(paper.get_meta("band_width"), 700.0, "an open slip reflows after resize")
	assert_lte(paper.size.x, 700.0)
	assert_lte(paper.position.y + paper.size.y, strip.get_viewport_rect().size.y)
