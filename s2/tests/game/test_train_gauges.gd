extends "res://addons/gut/test.gd"
## The train's gauges along the top (train_gauges.gd): they say what the
## train's own numbers say (the state, train_turn.gd forecast and standings),
## mark the 조심 구간 as the tokens set them, and dim what a sheet is not about.

const TrainGauges = preload("res://game/ui/train_gauges.gd")
const TrainTurn = preload("res://game/train/train_turn.gd")
const StopPickCard = preload("res://game/ui/stop_pick_card.gd")


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
