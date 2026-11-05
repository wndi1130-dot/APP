extends "res://addons/gut/test.gd"
## The train's stores (train_dom.gd, decision 426 PR 1): an empty store a new
## game gets, what counts as stores only, and that the stores change none of
## the S1a answers — the train-vector rules and the field return read the
## game as before, and the stores only take what the field brings home.

const TrainDom = preload("res://game/train/train_dom.gd")
const St = preload("res://game/train/train_state.gd")
const Turn = preload("res://game/train/train_turn.gd")
const TV = preload("res://tests/train/train_vectors.gd")
const FV = preload("res://tests/politics/field_vectors.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")


func test_transport_stocks_and_empty_furnish_keep_the_store_contract() -> void:
	var d: Dictionary = TrainDom.start()
	assert_eq(d["furnish"], {})
	for key: String in ["sleds", "stretchers", "carts", "long_sleds", "runners"]:
		assert_eq(d[key], 0)
		assert_true(TrainDom.is_store({key: 1}))
		assert_false(TrainDom.is_store({key: -1}))
		assert_false(TrainDom.is_store({key: "1"}))
	for id: String in ["w5", "x4"]:
		d["techs"][id] = {"stage": "done", "defect": false, "progress": 3, "need": 3}
	assert_true(St.is_s1a({"dom": d}))
	assert_true(TrainDom.is_store({"furnish": {}}))


func test_the_empty_stores_hold_every_amount_at_zero() -> void:
	var d: Dictionary = TrainDom.empty()
	assert_true(TrainDom.is_store(d))
	for key: String in TrainDom.AMOUNTS:
		assert_eq(d[key], 0, key)
	assert_eq((d["frags"] as Dictionary).size(), TrainDom.FIELDS.size())
	for f: String in TrainDom.FIELDS:
		assert_eq(d["frags"][f], 0, f)
	assert_eq(d["armory"], [])
	var g := {}
	TrainDom.ensure(g)
	assert_eq(g["dom"], TrainDom.empty(), "a game with none gets the empty stores")
	var kept := {"dom": {"wood": 3}}
	TrainDom.ensure(kept)
	assert_eq(kept["dom"], {"wood": 3}, "one it has stays as it is")


func test_stores_only_means_these_keys_and_nothing_under_zero() -> void:
	assert_true(TrainDom.is_store({"wood": 2.5, "scrap": 0, "frags": {"med": 1}}))
	assert_true(TrainDom.is_store({"armory": [{"id": "axe", "quality": "factory", "condition": 0.9}]}))
	assert_false(TrainDom.is_store({"wood": -1}), "under zero")
	assert_false(TrainDom.is_store({"wood": "3"}), "not a number")
	assert_true(TrainDom.is_store({"techs": {}}), "PR 6 research is ported")
	assert_false(TrainDom.is_store({"frags": {"magic": 1}}), "a field the receipt does not know")
	assert_false(TrainDom.is_store({"armory": [{"id": "laser", "quality": "factory", "condition": 1.0}]}), "a weapon the field does not know")
	assert_false(TrainDom.is_store({"armory": [{"id": "axe", "quality": "shiny", "condition": 1.0}]}), "a quality the field does not know")
	assert_false(TrainDom.is_store({"armory": [{"id": "axe", "quality": "crude", "condition": 1.5}]}), "condition over 1")
	assert_false(TrainDom.is_store([]))


func test_the_stores_are_not_the_domestic_branch() -> void:
	assert_true(St.is_s1a({"dom": TrainDom.empty()}))
	assert_false(TrainDom.rules_on({"dom": TrainDom.empty()}))
	assert_false(TrainDom.rules_on({}))
	assert_false(TrainDom.rules_on({"dom": {"wood": 1, "techs": {}}}))
	assert_true(St.is_s1a({"dom": {"wood": 1, "techs": {}}}))
	assert_true(St.is_s1a({"dom": TrainDom.start(), "hands": {"short": {"repair": 0.5}}}))
	for key: String in ["people", "manuals", "classroom", "beds", "elder"]:
		var d: Dictionary = TrainDom.start()
		d[key] = {}
		assert_false(St.is_s1a({"dom": d}), key + " is not ported")
	assert_false(TrainDom.is_store({"techs": {"w1": {"stage": "done"}}}), "incomplete TechState")
	assert_false(TrainDom.is_store({"restoring": "unknown"}))
	assert_false(TrainDom.is_store({"experts": [{"name": "x", "comm": "tail", "field": "craft", "skill": 4}]}))
	assert_false(TrainDom.is_store({"experts": [{"name": "x", "comm": "tail", "field": "craft", "skill": 1, "pupil": "y"}]}))


func test_research_start_keeps_its_own_roster_and_fragments() -> void:
	var first: Dictionary = TrainDom.start()
	var second: Dictionary = TrainDom.start()
	assert_eq(first["frags"], {"engine": 1, "med": 1, "craft": 0, "radio": 0, "expedition": 0})
	assert_eq(first["experts"].size(), 8)
	assert_eq(first["techs"], {})
	assert_null(first["restoring"])
	first["experts"][0]["skill"] = 0
	first["frags"]["engine"] = 9
	assert_eq(second["experts"][0]["skill"], 3)
	assert_eq(second["frags"]["engine"], 1)


func test_with_the_stores_the_train_rules_give_the_s1_answers() -> void:
	var t: Dictionary = TV.tables()
	var bad: Array[String] = []
	var stepped := 0
	for point: Dictionary in TV.points():
		var g: Dictionary = (point["state"] as Dictionary).duplicate(true)
		TrainDom.ensure(g)
		for c: String in St.comms(t):
			var d := TV.diff(St.situation(point["state"], t, c), St.situation(g, t, c), "%s %s" % [TV.where(point), c])
			if d != "" and bad.size() < 8:
				bad.append(d)
		var f := TV.diff(Turn.forecast(point["state"], t), Turn.forecast(g, t), TV.where(point) + " forecast")
		if f != "" and bad.size() < 8:
			bad.append(f)
		if Turn.next_segment_covers(point["state"], t):
			assert_true(Turn.next_segment_covers(g, t), TV.where(point) + " still covered")
			var want: Dictionary = Turn.next_segment(point["state"], t)
			var got: Dictionary = Turn.next_segment(g, t)
			assert_eq(got["dom"], TrainDom.empty(), "the stores ride along untouched")
			got.erase("dom")
			var n := TV.diff(want, got, TV.where(point) + " next segment")
			if n != "" and bad.size() < 8:
				bad.append(n)
			stepped += 1
	assert_eq(bad, [] as Array[String])
	assert_gt(stepped, 0, "some points step to the next stretch")


func test_a_field_return_fills_the_stores_and_changes_nothing_else() -> void:
	var t: Dictionary = FV.tables()
	var bad: Array[String] = []
	var seen := 0
	for row: Dictionary in FV.cases():
		if row["start"].get("dom") != null or row["apply"]["status"] != "applied":
			continue
		var g: Dictionary = (row["start"] as Dictionary).duplicate(true)
		TrainDom.ensure(g)
		var receipt := FV.receipt(row["receipt"])
		var applied := FieldReturn.apply_field_return(g, t, FV.departure(row["departure"]), receipt)
		var after: Dictionary = applied["g"]
		var stock: Dictionary = receipt["stock"]
		for key: String in ["wood", "scrap"]:
			assert_eq(float(after["dom"][key]), maxf(0.0, float(stock.get(key, 0))), FV.where(row) + " " + key)
		after.erase("dom")
		var d := FV.diff(row["apply"]["after"], after, FV.where(row) + " after")
		if d != "" and bad.size() < 8:
			bad.append(d)
		var r := FV.diff(row["apply"]["record"], applied["record"], FV.where(row) + " record")
		if r != "" and bad.size() < 8:
			bad.append(r)
		seen += 1
	assert_eq(bad, [] as Array[String])
	assert_gt(seen, 0, "cases with no dom to start from")


func test_the_stores_alone_do_not_open_hanging_a_symbol_in_a_car() -> void:
	# The bond a hung symbol builds is a domestic rule not ported yet.
	assert_eq(FieldReturn._hang_why({"dom": TrainDom.empty(), "symbols": 1}, "tail"), "내정을 켠 판에서만 쓴다.")
	assert_null(FieldReturn._hang_why({"dom": {"hung": []}, "symbols": 1}, "tail"))


func test_a_stop_brings_its_fragments_and_cores_to_the_stores() -> void:
	var g := {"dom": TrainDom.start()}
	assert_true(TrainDom.take_extras(g, {"documents": [], "symbolCount": 0, "fragments": ["craft", "craft", "radio"], "coreCount": 1}))
	assert_eq(float(g["dom"]["frags"]["craft"]), 2.0)
	assert_eq(float(g["dom"]["frags"]["radio"]), 1.0)
	assert_eq(float(g["dom"]["frags"]["engine"]), 1.0, "the start's one stays")
	assert_eq(float(g["dom"]["cores"]), 1.0)
	assert_true(TrainDom.is_store(g["dom"]))
	var none := {}
	assert_true(TrainDom.take_extras(none, {"fragments": [], "coreCount": 0}), "a stop with nothing in it")
	assert_eq(none["dom"], TrainDom.empty())
	for bad: Variant in [null, {"fragments": ["magic"]}, {"fragments": "craft"}, {"coreCount": -1}, {"coreCount": 0.5}]:
		var before: Dictionary = TrainDom.start()
		var h := {"dom": before.duplicate(true)}
		assert_false(TrainDom.take_extras(h, bad), str(bad))
		assert_eq(h["dom"], before, "nothing changed for " + str(bad))


func test_lures_are_a_store_amount() -> void:
	assert_true(TrainDom.AMOUNTS.has("lures"))
	assert_eq(TrainDom.empty()["lures"], 0)
	assert_eq(TrainDom.start()["lures"], 0)
	var g: Dictionary = {}
	TrainDom.ensure(g)
	assert_eq(g["dom"]["lures"], 0)
	assert_true(TrainDom.is_store({"lures": 3}))
	assert_true(TrainDom.is_store({"lures": 0.5}), "the usual amount contract")
	assert_false(TrainDom.is_store({"lures": -1}))
	assert_false(TrainDom.is_store({"lures": "1"}))
	g["dom"]["lures"] = 3
	TrainDom.ensure(g)
	assert_eq(g["dom"]["lures"], 3, "existing stores stay intact")


func test_restore_store_shape_accepts_only_exact_log_stats_and_pipe_variants() -> void:
	var valid: Dictionary = {"log": {"restores": [{"seg": 1, "id": "e3", "v": "a"}, {"seg": 0, "id": "w1"}]},
		"stats": {"restored": 2, "tier3": 0, "defective": 1}, "pipeFlip": "b", "pipeMoved": "a"}
	assert_true(TrainDom.is_store(valid))
	assert_true(TrainDom.is_store(JSON.parse_string(JSON.stringify(valid))), "JSON integer-valued floats")
	for pair: Array in [["log", {}], ["log", {"restores": [], "apprentices": []}], ["log", {"restores": {}}],
		["log", {"restores": [{"seg": 0, "id": "w1", "other": 0}]}], ["log", {"restores": [{"seg": 0, "id": "e3", "v": "c"}]}],
		["log", {"restores": [{"seg": 0, "id": "unknown"}]}], ["log", {"restores": [{"id": "w1"}]}],
		["stats", {}], ["stats", {"restored": 0, "tier3": 0, "other": 0}],
		["stats", {"restored": 0, "tier3": 0, "defective": 0, "partsMade": 0}],
		["pipeFlip", null], ["pipeFlip", "c"], ["pipeMoved", true], ["pipeMoved", 0]]:
		var bad: Dictionary = valid.duplicate(true)
		bad[pair[0]] = pair[1]
		assert_false(TrainDom.is_store(bad), str(pair))
	for number: Variant in [-1, 0.5, true, "1", null, INF, NAN]:
		var bad_seg: Dictionary = valid.duplicate(true)
		bad_seg["log"]["restores"][0]["seg"] = number
		assert_false(TrainDom.is_store(bad_seg), "seg " + str(number))
		for key: String in ["restored", "tier3", "defective"]:
			var bad_stat: Dictionary = valid.duplicate(true)
			bad_stat["stats"][key] = number
			assert_false(TrainDom.is_store(bad_stat), key + " " + str(number))


func test_restore_log_initialization_is_idempotent_and_keeps_literal_key_order() -> void:
	var expected_empty: Array = ["frags", "armory", "wardrobe", "furnish", "store", "decor80", "scrap", "wood", "parts", "cores", "cloth", "ammo_pistol", "ammo_shell", "ammo_craft", "lures", "sleds", "stretchers", "carts", "long_sleds", "runners", "log", "stats"]
	var expected_start: Array = ["frags", "armory", "wardrobe", "furnish", "store", "decor80", "scrap", "wood", "parts", "cores", "cloth", "ammo_pistol", "ammo_shell", "ammo_craft", "lures", "sleds", "stretchers", "carts", "long_sleds", "runners", "techs", "restoring", "experts", "insulated", "job", "log", "stats"]
	assert_eq(TrainDom.empty().keys(), expected_empty)
	var first: Dictionary = TrainDom.start()
	assert_eq(first.keys(), expected_start)
	assert_eq(first["log"], {"restores": []})
	assert_eq(first["stats"], {"restored": 0, "tier3": 0, "defective": 0})
	(first["log"]["restores"] as Array).append({"seg": 1, "id": "w1"})
	first["stats"]["restored"] = 7
	var before: String = JSON.stringify(first, "", false)
	TrainDom.init_log(first)
	TrainDom.init_log(first)
	assert_eq(JSON.stringify(first, "", false), before)
	var legacy: Dictionary = {"wood": 3, "job": null}
	TrainDom.init_log(legacy)
	assert_eq(legacy.keys(), ["wood", "job", "log", "stats"])
	var returned: Dictionary = {}
	assert_true(TrainDom.take_extras(returned, {"fragments": ["med"], "coreCount": 1}))
	assert_eq(returned["dom"].keys(), expected_empty, "first return with no old dom")
