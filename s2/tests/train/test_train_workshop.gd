extends "res://addons/gut/test.gd"
## The train's workshop (train_workshop.gd, decision 426 PR 3): a new run's
## stores, what the stores take now, parts up to the target, one thing on the
## line at a time paid up front, taken back whole before the workshop touches
## it, and what it makes landing in the armory or the wardrobe.

const TrainDom = preload("res://game/train/train_dom.gd")
const TrainWorkshop = preload("res://game/train/train_workshop.gd")
const TrainResearch = preload("res://game/train/train_research.gd")
const St = preload("res://game/train/train_state.gd")


func _game(stores: Dictionary = {}) -> Dictionary:
	var dom: Dictionary = TrainDom.start()
	for key: String in stores:
		dom[key] = stores[key]
	return {"seg": 2, "dom": dom}


func test_a_new_run_starts_with_s1s_scrap_wood_and_parts() -> void:
	var d: Dictionary = TrainDom.start()
	assert_eq([d["scrap"], d["wood"], d["parts"]], [10, 10, 4])
	assert_eq(d["wardrobe"], TrainDom.START_WARDROBE, "the railway coats and gloves (decision 443)")
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
	# Onto the start armory (the first kits, PR 5).
	assert_eq((g["dom"]["armory"] as Array).size(), TrainDom.START_ARMORY.size() + 1)
	assert_eq(g["dom"]["armory"].back(), {"id": "bow", "quality": "usable", "condition": 1.0})
	assert_true(TrainDom.is_store(g["dom"]), "the bow is a weapon the field knows")
	assert_eq(r["events"], [{"kind": "made", "car": "", "comm": "", "sign": 1, "size": 0.4, "day": 2}])


func test_a_coat_goes_to_the_wardrobe() -> void:
	var g := _game({"cloth": 4, "parts": 5})
	assert_true(TrainWorkshop.start(g, "coat_long"))
	var r: Dictionary = TrainWorkshop.run(g)
	assert_eq(r["made"], ["coat_long"])
	# Onto the start wardrobe (decision 443).
	assert_eq((g["dom"]["wardrobe"] as Array).size(), TrainDom.START_WARDROBE.size() + 1)
	assert_eq(g["dom"]["wardrobe"].back(), {"id": "coat_long", "condition": 1.0})
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


## The remade core (decision 474 S3): parts and scrap paid up front, two
## stretches of work, then one more core in the stores, where a tier-3
## restoration looks for it; taken back whole before the work starts.
func test_a_remade_core_goes_to_the_stores_cores() -> void:
	var short := _game({"parts": 6, "scrap": 3})
	assert_eq(TrainWorkshop.why_not(short, "core_remake"), "고철 5 모자람")
	assert_eq(TrainWorkshop.why_not(_game(), "core_remake"), "부품 2 모자람", "four parts at the start")
	var g := _game({"parts": 6, "scrap": 8})
	TrainWorkshop.set_target(g, 0)
	assert_true(TrainWorkshop.start(g, "core_remake"))
	assert_eq([float(g["dom"]["parts"]), float(g["dom"]["scrap"])], [0.0, 0.0], "paid now")
	assert_true(TrainWorkshop.cancel(g))
	assert_eq([float(g["dom"]["parts"]), float(g["dom"]["scrap"])], [6.0, 8.0], "taken back whole")
	TrainWorkshop.start(g, "core_remake")
	var r1: Dictionary = TrainWorkshop.run(g)
	assert_eq(r1["made"], [], "longer than a stretch")
	assert_false(TrainWorkshop.cancel(g), "work has gone into it")
	var r2: Dictionary = TrainWorkshop.run(g)
	assert_eq(r2["made"], ["core_remake"])
	assert_eq(float(g["dom"]["cores"]), 1.0)
	assert_null(TrainWorkshop.line(g))
	assert_true(TrainDom.is_store(g["dom"]), "the cores are a store S1 has")


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


## Leaving a stop the running technologies take their upkeep before the work
## (S1 domesticSettle: payUpkeep, then runWorkshop), so the workshop makes back
## the parts they used; with nothing to pay it with they run at half and the
## stretch names them. `run` alone stays S1's runWorkshop.
func test_a_stretch_takes_the_upkeep_before_the_work() -> void:
	var g := _game()
	for id: String in ["e2", "e3"]:
		g["dom"]["techs"][id] = {"stage": "done", "defect": false, "progress": 2, "need": 2}
	var parts: float = float(g["dom"]["parts"])
	var r: Dictionary = TrainWorkshop.stretch(g)
	assert_eq(r["starved"], [] as Array[String])
	# 0.25 each came off before the workshop made parts back up to its target.
	assert_eq(r["parts"], int(ceilf(float(TrainWorkshop.target(g)) - (parts - 0.5))))
	var poor := _game({"parts": 0.0, "scrap": 0.0})
	poor["dom"]["techs"]["e2"] = {"stage": "done", "defect": false, "progress": 2, "need": 2}
	var r2: Dictionary = TrainWorkshop.stretch(poor)
	assert_eq(r2["starved"], ["e2"] as Array[String])
	assert_eq(TrainResearch.mult(poor, {}, "e2"), float(TrainResearch.D["defectMult"]), "a starved technology runs at half")
	var plain := _game()
	plain["dom"]["techs"]["e2"] = {"stage": "done", "defect": false, "progress": 2, "need": 2}
	var before: float = float(plain["dom"]["parts"])
	TrainWorkshop.run(plain)
	assert_false(plain["dom"]["techs"]["e2"].has("starved"), "run alone pays no upkeep")
	assert_gte(float(plain["dom"]["parts"]), before)
