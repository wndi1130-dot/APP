extends "res://addons/gut/test.gd"
## The train's workshop (train_workshop.gd, decision 426 PR 3): a new run's
## stores, what the stores take now, parts up to the target, one thing on the
## line at a time paid up front, taken back whole before the workshop touches
## it, and what it makes landing in the armory or the wardrobe.

const TrainDom = preload("res://game/train/train_dom.gd")
const TrainWorkshop = preload("res://game/train/train_workshop.gd")
const TrainResearch = preload("res://game/train/train_research.gd")
const St = preload("res://game/train/train_state.gd")


func _transport_game() -> Dictionary:
	var g: Dictionary = _game({"wood": 100.0, "scrap": 100.0, "parts": 20.0, "cloth": 10.0, "target": 0})
	for id: String in ["x1", "x4"]:
		g["dom"]["techs"][id] = {"stage": "done", "defect": false, "progress": 6, "need": 6}
	return g


func test_five_transport_tools_pay_the_design_cost_and_enter_their_stores() -> void:
	var rows: Array = [
		["sled", "sleds", {"wood": 2.0, "scrap": 1.0}, 1.0],
		["stretcher", "stretchers", {"wood": 2.0, "cloth": 1.0}, 1.0],
		["cart", "carts", {"wood": 3.0, "scrap": 2.0, "parts": 1.0}, 2.0],
		["long_sled", "long_sleds", {"wood": 4.0, "scrap": 1.0}, 2.0],
		["runner", "runners", {"scrap": 2.0}, 1.0],
	]
	for row: Array in rows:
		var g: Dictionary = _transport_game()
		if row[0] == "runner":
			g["dom"]["sleds"] = 1
		var before: Dictionary = g["dom"].duplicate(true)
		assert_true(TrainWorkshop.start(g, row[0]), row[0])
		assert_eq(g["dom"]["make"]["paid"], row[2])
		assert_eq(g["dom"]["make"]["need"], row[3])
		for key: String in row[2]:
			assert_eq(float(g["dom"][key]), float(before[key]) - float(row[2][key]), row[0] + " " + key)
		assert_true(TrainDom.is_store(g["dom"]))
		var out: Dictionary = TrainWorkshop.run(g)
		assert_eq(out["made"], [row[0]])
		assert_eq(float(out["used"]), row[3])
		assert_eq(float(g["dom"][row[1]]), 1.0)
		assert_null(g["dom"]["make"])
		assert_true(TrainDom.is_store(g["dom"]))


func test_transport_caps_share_sled_places_and_count_runners_per_sled() -> void:
	for order: Array in [["sled", "sled"], ["sled", "long_sled"], ["long_sled", "sled"], ["long_sled", "long_sled"]]:
		var g: Dictionary = _transport_game()
		for id: String in order:
			assert_true(TrainWorkshop.start(g, id))
			TrainWorkshop.run(g)
		var before: Dictionary = g.duplicate(true)
		for id: String in ["sled", "long_sled"]:
			assert_eq(TrainWorkshop.why_not(g, id), "썰매 자리는 둘까지")
			assert_false(TrainWorkshop.start(g, id))
		assert_eq(g, before, "full sled places never spend stores")
	for id: String in ["stretcher", "cart"]:
		var g: Dictionary = _transport_game()
		assert_true(TrainWorkshop.start(g, id))
		TrainWorkshop.run(g)
		assert_false(TrainWorkshop.start(g, id))
	var g: Dictionary = _transport_game()
	assert_false(TrainWorkshop.start(g, "runner"), "no sled to fit")
	for sled: String in ["sled", "long_sled"]:
		assert_true(TrainWorkshop.start(g, sled))
		TrainWorkshop.run(g)
		assert_true(TrainWorkshop.start(g, "runner"))
		TrainWorkshop.run(g)
		assert_false(TrainWorkshop.start(g, "runner"), "one per sled")
	assert_eq(float(g["dom"]["runners"]), 2.0)


func test_transport_research_gates_and_defective_x4_only_allow_cart() -> void:
	var g: Dictionary = _game({"wood": 100, "scrap": 100, "parts": 20, "cloth": 10})
	for id: String in ["sled", "stretcher", "cart", "long_sled", "runner"]:
		assert_false(TrainWorkshop.shown(g).has(id))
		assert_false(TrainWorkshop.start(g, id))
	g = _transport_game()
	for id: String in ["x1", "x4"]:
		g["dom"]["techs"][id]["stage"] = "defective"
		g["dom"]["techs"][id]["defect"] = true
	for id: String in ["sled", "stretcher", "cart"]:
		assert_true(TrainWorkshop.shown(g).has(id))
	for id: String in ["long_sled", "runner"]:
		assert_false(TrainWorkshop.shown(g).has(id))
		assert_false(TrainWorkshop.start(g, id))
	g["dom"]["techs"]["x4"]["stage"] = "done"
	g["dom"]["techs"]["x4"]["defect"] = false
	g["dom"]["techs"]["x4"]["starved"] = true
	assert_true(TrainWorkshop.shown(g).has("long_sled"), "starved finished research is still usable")
	g["dom"]["techs"]["x1"]["off"] = true
	g["dom"]["techs"]["x4"]["off"] = true
	for id: String in ["sled", "stretcher", "cart", "long_sled", "runner"]:
		assert_false(TrainWorkshop.start(g, id))
	g = _transport_game()
	g["dom"]["experts"] = []
	assert_false(TrainWorkshop.shown(g).has("cart"), "knowledge is required")
	g = _transport_game()
	g["dom"]["techs"]["x1"]["stage"] = "restoring"
	assert_false(TrainWorkshop.start(g, "sled"))


func test_transport_before_work_refunds_real_cloth_and_shares_one_line() -> void:
	var g: Dictionary = _transport_game()
	assert_true(TrainWorkshop.start(g, "stretcher"))
	assert_eq(float(g["dom"]["cloth"]), 9.0)
	assert_false(TrainWorkshop.start(g, "sled"))
	assert_true(TrainWorkshop.cancel(g))
	assert_eq(float(g["dom"]["cloth"]), 10.0)
	assert_eq(float(g["dom"]["wood"]), 100.0)
	assert_true(TrainWorkshop.start(g, "cart"))
	g["dom"]["make"]["progress"] = 0.25
	assert_false(TrainWorkshop.cancel(g))


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


func test_locked_research_recipes_are_hidden_and_refused() -> void:
	var g: Dictionary = _game()
	var before: Dictionary = g.duplicate(true)
	assert_eq(TrainWorkshop.shown(g), ["bow", "crowbar", "coat_long", "core_remake"] as Array[String])
	for id: String in ["rounds", "arrows", "lure"]:
		assert_eq(TrainWorkshop.why_not(g, id), "아직 만들 줄 모른다", id)
		assert_false(TrainWorkshop.start(g, id), id)
	assert_eq(g, before, "locked recipes take nothing")
	g["dom"]["techs"]["w2"] = {"stage": "restoring", "defect": false, "progress": 1.0, "need": 6.0, "variant": "a"}
	g["dom"]["restoring"] = "w2"
	assert_false(TrainWorkshop.shown(g).has("rounds"))
	assert_false(TrainWorkshop.start(g, "rounds"), "restoration has not finished")


func test_w2_a_makes_six_pistol_rounds_for_two_scrap_and_one_work() -> void:
	var g: Dictionary = _game({"scrap": 2, "ammo_pistol": 7, "target": 0})
	g["dom"]["techs"]["w2"] = {"stage": "done", "defect": false, "progress": 6.0, "need": 6.0, "variant": "a"}
	assert_eq(TrainWorkshop.shown(g), ["bow", "crowbar", "coat_long", "core_remake", "rounds"] as Array[String])
	assert_eq(TrainWorkshop.why_not(g, "arrows"), "아직 만들 줄 모른다")
	assert_true(TrainWorkshop.start(g, "rounds"))
	assert_eq(float(g["dom"]["scrap"]), 0.0)
	assert_eq(float(g["dom"]["make"]["need"]), 1.0)
	assert_eq(g["dom"]["make"]["paid"], {"scrap": 2.0})
	assert_true(TrainDom.is_store(g["dom"]), "the new line fits the store contract")
	var result: Dictionary = TrainWorkshop.run(g)
	assert_eq(result["made"], ["rounds"])
	assert_eq(float(result["used"]), 1.0)
	assert_eq(float(g["dom"]["ammo_pistol"]), 13.0)
	assert_null(TrainWorkshop.line(g))
	assert_true(TrainDom.is_store(g["dom"]))


func test_w2_b_makes_three_arrows_for_two_wood_and_one_work() -> void:
	var g: Dictionary = _game({"wood": 2, "ammo_craft": 4, "target": 0})
	g["dom"]["techs"]["w2"] = {"stage": "done", "defect": false, "progress": 6.0, "need": 6.0, "variant": "b"}
	assert_eq(TrainWorkshop.shown(g), ["bow", "crowbar", "coat_long", "core_remake", "arrows"] as Array[String])
	assert_false(TrainWorkshop.start(g, "rounds"))
	assert_true(TrainWorkshop.start(g, "arrows"))
	assert_eq(float(g["dom"]["wood"]), 0.0)
	assert_eq(g["dom"]["make"]["paid"], {"wood": 2.0})
	var result: Dictionary = TrainWorkshop.run(g)
	assert_eq(result["made"], ["arrows"])
	assert_eq(float(result["used"]), 1.0)
	assert_eq(float(g["dom"]["ammo_craft"]), 7.0)
	assert_null(TrainWorkshop.line(g))
	assert_true(TrainDom.is_store(g["dom"]))


func test_w4_makes_one_lure_for_one_part_and_one_work_without_gear() -> void:
	var g: Dictionary = _game({"parts": 1, "lures": 2, "target": 0})
	g["gearOn"] = false
	g["dom"]["techs"]["w4"] = {"stage": "done", "defect": false, "progress": 3.0, "need": 3.0}
	assert_eq(TrainWorkshop.shown(g), ["bow", "crowbar", "coat_long", "core_remake", "lure"] as Array[String])
	assert_true(TrainWorkshop.start(g, "lure"))
	assert_eq(float(g["dom"]["parts"]), 0.0)
	assert_eq(g["dom"]["make"]["paid"], {"parts": 1.0})
	var result: Dictionary = TrainWorkshop.run(g)
	assert_eq(result["made"], ["lure"])
	assert_eq(float(result["used"]), 1.0)
	assert_eq(float(g["dom"]["lures"]), 3.0)
	assert_null(TrainWorkshop.line(g))
	assert_true(TrainDom.is_store(g["dom"]))


func test_defective_research_opens_recipes_and_off_closes_them() -> void:
	for row: Dictionary in [{"tech": "w2", "variant": "a", "recipe": "rounds"}, {"tech": "w2", "variant": "b", "recipe": "arrows"}, {"tech": "w4", "recipe": "lure"}]:
		var g: Dictionary = _game({"target": 0})
		var tech: String = String(row["tech"])
		var id: String = String(row["recipe"])
		var state: Dictionary = {"stage": "defective", "defect": true, "progress": 3.0, "need": 3.0}
		if row.has("variant"):
			state["variant"] = row["variant"]
		g["dom"]["techs"][tech] = state
		assert_gt(TrainResearch.mult(g, {}, tech), 0.0, id)
		assert_true(TrainWorkshop.shown(g).has(id), id)
		assert_true(TrainWorkshop.start(g, id), id)
		assert_eq(TrainWorkshop.run(g)["made"], [id])
		state["off"] = true
		var before: Dictionary = g.duplicate(true)
		assert_eq(TrainResearch.mult(g, {}, tech), 0.0, id)
		assert_false(TrainWorkshop.shown(g).has(id), id)
		assert_eq(TrainWorkshop.why_not(g, id), "아직 만들 줄 모른다", id)
		assert_false(TrainWorkshop.start(g, id), id)
		assert_eq(g, before, id + " stays unpaid while off")


func test_w2_recipes_close_without_working_knowledge() -> void:
	var g: Dictionary = _game({"experts": []})
	g["dom"]["techs"]["w2"] = {"stage": "done", "defect": false, "progress": 6.0, "need": 6.0, "variant": "a"}
	assert_eq(TrainResearch.mult(g, {}, "w2"), 0.0)
	assert_false(TrainWorkshop.shown(g).has("rounds"))
	assert_eq(TrainWorkshop.why_not(g, "rounds"), "아직 만들 줄 모른다")
	assert_false(TrainWorkshop.start(g, "rounds"))
