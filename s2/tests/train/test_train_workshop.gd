extends "res://addons/gut/test.gd"
## The train's workshop (train_workshop.gd, decision 426 PR 3): a new run's
## stores, what the stores take now, parts up to the target, one thing on the
## line at a time paid up front, taken back whole before the workshop touches
## it, and what it makes landing in the armory or the wardrobe.

const TrainDom = preload("res://game/train/train_dom.gd")
const TrainWorkshop = preload("res://game/train/train_workshop.gd")
const St = preload("res://game/train/train_state.gd")


func _game(stores: Dictionary = {}) -> Dictionary:
	var dom: Dictionary = TrainDom.start()
	for key: String in stores:
		dom[key] = stores[key]
	return {"seg": 2, "dom": dom}


func test_a_new_run_starts_with_s1s_scrap_wood_and_parts() -> void:
	var d: Dictionary = TrainDom.start()
	assert_eq([d["scrap"], d["wood"], d["parts"]], [10, 10, 4])
	assert_eq(d["wardrobe"], [])
	assert_true(TrainDom.is_store(d))
	assert_eq(TrainDom.empty()["wardrobe"], [], "the empty stores have an empty wardrobe")


func test_the_workshops_keys_are_still_stores_only() -> void:
	var g := _game()
	assert_true(TrainWorkshop.start(g, "bow"))
	TrainWorkshop.set_target(g, 7)
	g["dom"]["partWork"] = 0.5
	g["dom"]["wardrobe"] = [{"id": "coat_long", "condition": 0.8}]
	assert_true(TrainDom.is_store(g["dom"]), "a line, a target, part work and a coat")
	assert_true(St.is_s1a(g), "the stores are still not the domestic branch")
	assert_false(TrainDom.is_store({"wardrobe": [{"id": "cape", "condition": 1.0}]}), "a thing the wardrobe does not know")
	assert_false(TrainDom.is_store({"target": 11}), "a target over 10")
	assert_false(TrainDom.is_store({"make": {"id": "bow"}}), "a line without its numbers")
	assert_true(TrainDom.is_store({"make": null}), "nothing on the line")


func test_why_not_names_the_store_that_is_short() -> void:
	var g := _game({"scrap": 3})
	assert_eq(TrainWorkshop.why_not(g, "crowbar"), "고철 1 모자람")
	assert_eq(TrainWorkshop.why_not(g, "coat_long"), "천 4 모자람", "no cloth reaches the train yet")
	assert_eq(TrainWorkshop.why_not(g, "bow"), "")
	assert_false(TrainWorkshop.start(g, "crowbar"))
	assert_eq(g["dom"]["scrap"], 3, "nothing paid")


func test_one_thing_on_the_line_paid_up_front() -> void:
	var g := _game()
	assert_true(TrainWorkshop.start(g, "crowbar"))
	assert_eq(float(g["dom"]["scrap"]), 6.0, "four scrap paid now")
	assert_eq(TrainWorkshop.why_not(g, "bow"), "다른 것을 만드는 중")
	assert_false(TrainWorkshop.start(g, "bow"))


func test_taken_back_whole_before_the_workshop_touches_it() -> void:
	var g := _game()
	TrainWorkshop.start(g, "bow")
	assert_true(TrainWorkshop.cancel(g))
	assert_eq([float(g["dom"]["wood"]), float(g["dom"]["scrap"])], [10.0, 10.0])
	assert_null(TrainWorkshop.line(g))
	TrainWorkshop.start(g, "bow")
	# A thing longer than a stretch: the stretch's work goes into it and it stays on the line.
	g["dom"]["make"]["need"] = 9.0
	TrainWorkshop.run(g)
	assert_false(TrainWorkshop.cancel(g), "work has gone into it")


func test_parts_first_up_to_the_target_then_the_line() -> void:
	var g := _game()
	TrainWorkshop.start(g, "bow")
	var r: Dictionary = TrainWorkshop.run(g)
	# PR 6's starting craft master gives 5 work: one part, then the bow's 3.
	assert_eq(r["parts"], 1)
	assert_eq(float(g["dom"]["parts"]), 5.0)
	assert_eq(r["made"], ["bow"])
	assert_null(TrainWorkshop.line(g))
	assert_eq(g["dom"]["armory"], [{"id": "bow", "quality": "usable", "condition": 1.0}])
	assert_true(TrainDom.is_store(g["dom"]), "the bow is a weapon the field knows")
	assert_eq(r["events"], [{"kind": "made", "car": "", "comm": "", "sign": 1, "size": 0.4, "day": 2}])


func test_a_coat_goes_to_the_wardrobe() -> void:
	var g := _game({"cloth": 4, "parts": 5})
	assert_true(TrainWorkshop.start(g, "coat_long"))
	var r: Dictionary = TrainWorkshop.run(g)
	assert_eq(r["made"], ["coat_long"])
	assert_eq(g["dom"]["wardrobe"], [{"id": "coat_long", "condition": 1.0}])
	assert_true(TrainDom.is_store(g["dom"]))


func test_a_long_thing_carries_over_and_parts_stop_at_the_target() -> void:
	var g := _game({"parts": 0})
	TrainWorkshop.set_target(g, 3)
	TrainWorkshop.start(g, "crowbar")
	g["dom"]["make"]["need"] = 4.0
	var r1: Dictionary = TrainWorkshop.run(g)
	# Starting master gives 5 work: 3 parts, then 2 of this longer job's 4.
	assert_eq(r1["parts"], 3)
	assert_eq(r1["made"], [])
	assert_almost_eq(float(TrainWorkshop.now(g)["share"]), 0.5, 1e-6)
	var r2: Dictionary = TrainWorkshop.run(g)
	assert_eq(r2["parts"], 0, "at the target")
	assert_eq(r2["made"], ["crowbar"])


func test_no_parts_without_the_stores() -> void:
	var g := _game({"scrap": 1, "wood": 0, "parts": 0})
	var r: Dictionary = TrainWorkshop.run(g)
	assert_eq(r["parts"], 0)
	assert_eq(float(g["dom"]["scrap"]), 1.0)


func test_the_target_stays_between_0_and_10() -> void:
	var g := _game()
	TrainWorkshop.set_target(g, 12)
	assert_eq(TrainWorkshop.target(g), 10)
	TrainWorkshop.set_target(g, -3)
	assert_eq(TrainWorkshop.target(g), 0)
