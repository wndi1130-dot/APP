extends "res://addons/gut/test.gd"
## The train's gauges along the top (train_gauges.gd): they say what the
## train's own numbers say (the state, train_turn.gd forecast and standings),
## mark the 조심 구간 as the tokens set them, and dim what a sheet is not about.

const TrainGauges = preload("res://game/ui/train_gauges.gd")
const TrainTurn = preload("res://game/train/train_turn.gd")
const StopPickCard = preload("res://game/ui/stop_pick_card.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")


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
			assert_eq(st["left"], int(floor(float(st["n"]) / float(cost[id]))), id + ": stretches it lasts")
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
