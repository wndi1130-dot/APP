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
