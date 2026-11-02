extends "res://addons/gut/test.gd"
## PR4's S1 oracle, compared in both directions like test_train_research.gd.

const Mods = preload("res://game/train/train_mods.gd")
const Dom = preload("res://game/train/train_dom.gd")
const Research = preload("res://game/train/train_research.gd")
const LawTech = preload("res://game/train/train_lawtech.gd")
const Workshop = preload("res://game/train/train_workshop.gd")
const State = preload("res://game/train/train_state.gd")
const Turn = preload("res://game/train/train_turn.gd")
const TV = preload("res://tests/train/train_vectors.gd")
const PATH := "res://tests/fixtures/train/mods_vectors.json"
static var _data: Dictionary = {}
var _bad: Array[String] = []


func before_all() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(_data.get("format"), "mods-vectors-v1")
	assert_eq(_data["cases"].size(), _data["seeds"].size() * _data["checkpoints"].size() * int(_data["profiles"]))
	assert_lt(FileAccess.get_file_as_bytes(PATH).size(), 5000000)


func before_each() -> void:
	_bad.clear()


func _same(want: Variant, got: Variant, label: String) -> void:
	var diff: String = TV.diff(want, got, label)
	if diff == "":
		diff = TV.diff(got, want, label + " unexpected")
	if diff != "" and _bad.size() < 12:
		_bad.append(diff)


func _furnish_owned(g: Dictionary) -> Dictionary:
	var out: Dictionary = _owned(g).duplicate(true)
	if out["job"] is Dictionary:
		out["job"]["paid"].erase("cloth")
	out["parts"] = g["dom"]["parts"]
	out["furnish"] = g["dom"].get("furnish", {}).duplicate(true)
	out["store"] = g["dom"].get("store", {}).duplicate(true)
	out["rel"] = {}
	for c: String in Mods.COMM_CARS:
		out["rel"][c] = g["comms"][c]["rel"]
	out["ledger"] = g.get("ledger", []).duplicate(true)
	return out


func test_furnish_tables_and_costs_match_s1_except_actual_cloth() -> void:
	var tables: Dictionary = _data["tables"]
	var work := {}
	for n: int in Mods.FURNISH_STEPS:
		work[str(n)] = Mods.FURNISH_WORK[n]
	_same(tables["FURNISH_WORK"], work, "furnish work")
	_same(tables["FURNISH_CARS"], Mods.FURNISH_CARS, "furnish cars")
	_same(tables["FURNISH_STEPS"], Mods.FURNISH_STEPS, "furnish steps")
	_same(tables["FURNITURE_SIZE"], Mods.FURNITURE_SIZE, "furniture sizes")
	_same(tables["FURNITURE"], Mods.FURNITURE, "furniture")
	for row: Dictionary in _data["furnish"]["costs"]:
		var cost: Dictionary = Mods.furnish_cost(int(row["step"]))
		assert_eq(cost["cloth"], Mods.FURNISH_WORK[int(row["step"])]["cloth"])
		cost.erase("cloth")
		_same(row["cost"], cost, "furnish cost")
	assert_eq(_bad, [] as Array[String])


func test_furnish_sequences_match_s1_in_both_directions() -> void:
	var actions: int = 0
	for row: Dictionary in _data["furnish"]["cases"]:
		var g: Dictionary = row["state"].duplicate(true)
		g["dom"]["cloth"] = 100.0
		var cloth: float = 100.0
		for sample: Dictionary in row["steps"]:
			var result: Variant = null
			var car: String = String(sample.get("car", ""))
			match sample["op"]:
				"check": result = Mods.job_check(g, "furnish", car, sample.get("step"))
				"start":
					result = Mods.start_job(g, "furnish", car, sample.get("step"))
					if result:
						cloth -= float(Mods.FURNISH_WORK[int(g["dom"]["job"]["furnishStep"])]["cloth"])
				"cancel":
					var refund: float = float(g["dom"]["job"]["paid"].get("cloth", 0)) if g["dom"].get("job") is Dictionary else 0.0
					result = Mods.cancel_job(g)
					if result:
						cloth += refund
				"run":
					var out: Dictionary = Workshop.run(g)
					result = {"used": out["used"], "did": out["did"]}
				"place": result = Mods.place_furniture(g, car, String(sample["kind"]))
				"remove": result = Mods.remove_furniture(g, car, sample["index"])
				"tick": LawTech.furnish_tick(g)
			var label: String = "%s/%d %s" % [row["name"], actions, sample["op"]]
			_same(sample["result"], result, label + " result")
			_same(sample["after"], _furnish_owned(g), label + " after")
			_same(sample["effects"], _effects(g), label + " effects")
			_same(sample["comparison"], LawTech.furnish_comparison(g), label + " comparison")
			var cars := {}
			for id: String in Mods.FURNISH_CARS:
				cars[id] = {"state": Mods.furnish_of(g, id), "score": Mods.furnish_score(g, id), "next": Mods.next_furnish_work(g, id)}
			_same(sample["cars"], cars, label + " car states")
			assert_almost_eq(float(g["dom"]["cloth"]), cloth, 1e-9, label + " actual S2 cloth")
			assert_true(Dom.is_store(g["dom"]), label + " dom contract")
			actions += 1
	assert_gt(actions, 300)
	assert_eq(_bad, [] as Array[String])


func _furnish_game() -> Dictionary:
	var g: Dictionary = _ready_game()
	var gained: Array = []
	for kind: String in Mods.FURNITURE:
		if Mods.FURNITURE[kind]["furniture"]:
			for _i: int in 20: gained.append(kind)
	Mods.TrainDecor.receive_decor(g, gained)
	g["dom"].merge({"wood": 100.0, "scrap": 100.0, "parts": 20.0, "cloth": 20.0, "target": 0}, true)
	g["comms"] = {}
	for c: String in Mods.COMM_CARS:
		g["comms"][c] = {"rel": 0.0, "pop": 10}
	return g


func _finish_furnish(g: Dictionary, car: String, step: int) -> void:
	assert_true(Mods.start_job(g, "furnish", car, step))
	Mods.advance_job(g, 20.0)
	assert_null(g["dom"]["job"])


func test_furnish_three_thresholds_research_gates_and_permanent_tiers() -> void:
	var g: Dictionary = _furnish_game()
	var before: Dictionary = g.duplicate(true)
	assert_eq(Mods.furnish_of(g, "tail1")["tier"], 0)
	assert_eq(g, before, "read alone never migrates an old state")
	for car: String in ["engine", "store", "tail4"]:
		assert_false(Mods.start_job(g, "furnish", car))
	for step: Variant in [0, 4, 1.5, "1", true, NAN, INF]:
		assert_false(Mods.start_job(g, "furnish", "tail1", step))
	assert_eq(Mods.job_check(g, "furnish", "tail1", 2)["why"], "살림 1단부터")
	_finish_furnish(g, "tail1", 1)
	assert_eq([Mods.furnish_score(g, "tail1"), Mods.furnish_of(g, "tail1")["tier"]], [3, 1])
	assert_eq(Mods.job_check(g, "furnish", "tail1")["why"], "이 칸 단열부터")
	g["dom"]["insulated"] = ["tail1"]
	assert_eq(Mods.job_check(g, "furnish", "tail1")["why"], "객차 목공을 사용해야 한다")
	g["dom"]["techs"]["w5"] = {"stage": "done", "defect": false, "need": 3, "progress": 3, "off": true}
	assert_false(Mods.start_job(g, "furnish", "tail1"))
	g["dom"]["techs"]["w5"]["off"] = false
	_finish_furnish(g, "tail1", 2)
	assert_eq([Mods.furnish_score(g, "tail1"), Mods.furnish_of(g, "tail1")["tier"]], [8, 2])
	assert_eq(Mods.job_check(g, "furnish", "tail1")["why"], "공구 수리부터")
	g["dom"]["techs"]["w1"] = {"stage": "done", "defect": false, "need": 3, "progress": 3, "off": true}
	assert_eq(Mods.job_check(g, "furnish", "tail1")["why"], "공구 수리부터", "the third tier needs 공구 수리 in use, not only restored")
	g["dom"]["techs"]["w1"]["off"] = false
	_finish_furnish(g, "tail1", 3)
	assert_eq([Mods.furnish_score(g, "tail1"), Mods.furnish_of(g, "tail1")["tier"]], [15, 3])
	assert_almost_eq(g["comms"]["tail"]["rel"], 4.0, 1e-9, "first tiers give (2 + 4 + 6) / 3")
	var rel: float = g["comms"]["tail"]["rel"]
	g["dom"]["techs"]["w5"]["off"] = true
	Mods.place_furniture(g, "tail1", "piano")
	Mods.remove_furniture(g, "tail1", 0)
	assert_eq(Mods.furnish_of(g, "tail1")["tier"], 3)
	assert_eq(g["comms"]["tail"]["rel"], rel, "no repeated tier reward")
	assert_false(Mods.start_job(g, "furnish", "tail1"))


func test_furniture_tiers_drop_but_each_tier_reward_and_journal_happen_once() -> void:
	var g: Dictionary = _furnish_game()
	g["dom"]["insulated"] = ["front"]
	for tech: String in ["w5", "w1"]:
		g["dom"]["techs"][tech] = {"stage": "done", "defect": false, "need": 3, "progress": 3}
	assert_true(Mods.place_furniture(g, "front", "piano")["ok"])
	for n: int in [1, 2, 3]:
		if n > 1: _finish_furnish(g, "front", n)
		var journal: Array = g.get("journal", []).duplicate(true)
		var rel: float = g["comms"]["front"]["rel"]
		for _repeat: int in 2:
			assert_eq(Mods.remove_furniture(g, "front", 0), {"ok": true})
			assert_eq(Mods.furnish_of(g, "front")["tier"], n - 1)
			assert_eq(Mods.furnish_of(g, "front")["best"], n)
			assert_true(Dom.is_furnish(Mods.furnish_of(g, "front")))
			assert_eq(Mods.place_furniture(g, "front", "piano"), {"ok": true})
			assert_eq(Mods.furnish_of(g, "front")["tier"], n)
			assert_eq(g["comms"]["front"]["rel"], rel)
			assert_eq(g["journal"], journal)
	assert_eq(Mods.furnish_of(g, "front")["jobs"], [2, 3])
	assert_eq(g["comms"]["front"]["rel"], 12.0)
	assert_eq(g["journal"].filter(func(row: Dictionary) -> bool: return "그 소리를 들었다" in row["text"]).size(), 3)


func test_work_only_tiers_survive_removal_at_all_three_levels() -> void:
	for n: int in [1, 2, 3]:
		var g: Dictionary = _furnish_game()
		g["dom"]["insulated"] = ["front"]
		for tech: String in ["w5", "w1"]:
			g["dom"]["techs"][tech] = {"stage": "done", "defect": false, "need": 3, "progress": 3}
		for step: int in range(1, n + 1): _finish_furnish(g, "front", step)
		var journal: Array = g["journal"].duplicate(true)
		var rel: float = g["comms"]["front"]["rel"]
		assert_true(Mods.place_furniture(g, "front", "piano")["ok"])
		assert_true(Mods.remove_furniture(g, "front", 0)["ok"])
		assert_eq(Mods.furnish_of(g, "front")["tier"], n)
		assert_eq(Mods.furnish_of(g, "front")["jobs"], range(1, n + 1))
		assert_eq(g["comms"]["front"]["rel"], rel)
		assert_eq(g["journal"], journal)


func test_one_piece_rotated_through_all_six_cars_keeps_rewards_but_no_tiers() -> void:
	var g: Dictionary = _furnish_game()
	for _repeat: int in 2:
		for car: String in Mods.FURNISH_CARS:
			assert_true(Mods.place_furniture(g, car, "piano")["ok"])
			assert_eq(Mods.furnish_of(g, car)["tier"], 1)
			assert_true(Mods.remove_furniture(g, car, 0)["ok"])
			assert_eq(Mods.furnish_of(g, car)["tier"], 0)
			assert_eq(Mods.furnish_of(g, car)["best"], 1)
	assert_eq(g["journal"].filter(func(row: Dictionary) -> bool: return "그 소리를 들었다" in row["text"]).size(), 6)


func test_removal_restores_current_warmth_crowding_comparison_and_next_work() -> void:
	var g: Dictionary = _furnish_game()
	var sit: Array[float] = LawTech.sit(g, "front")
	var comparison: Dictionary = LawTech.furnish_comparison(g)
	assert_true(Mods.place_furniture(g, "front", "piano")["ok"])
	assert_eq(LawTech.sit(g, "front")[0] - sit[0], 1.0)
	assert_eq(LawTech.sit(g, "front")[2] - sit[2], 1.0)
	assert_ne(LawTech.furnish_comparison(g), comparison)
	assert_true(Mods.remove_furniture(g, "front", 0)["ok"])
	assert_eq(LawTech.sit(g, "front"), sit)
	assert_eq(LawTech.furnish_comparison(g), comparison)
	g["dom"]["insulated"] = ["front"]
	g["dom"]["techs"]["w5"] = {"stage": "done", "defect": false, "need": 3, "progress": 3}
	assert_true(Mods.place_furniture(g, "front", "piano")["ok"])
	_finish_furnish(g, "front", 2)
	assert_true(Mods.remove_furniture(g, "front", 0)["ok"])
	assert_eq(Mods.furnish_of(g, "front")["tier"], 1)
	assert_eq(Mods.next_furnish_work(g, "front"), 1)
	_finish_furnish(g, "front", 1)
	assert_eq(Mods.furnish_score(g, "front"), 8)
	assert_eq(Mods.furnish_of(g, "front")["tier"], 2)


func test_furnish_cloth_and_recorded_four_store_refund() -> void:
	var g: Dictionary = _furnish_game()
	assert_eq(int(Mods.furnish_cost(1)["cloth"]), 0, "the first tier needs no cloth, so it does not compete with stretchers")
	_finish_furnish(g, "front", 1)
	g["dom"]["insulated"] = ["front"]
	g["dom"]["techs"]["w5"] = {"stage": "done", "defect": false, "need": 3, "progress": 3}
	g["dom"]["cloth"] = 1.0
	var before: Dictionary = g.duplicate(true)
	assert_eq(Mods.job_check(g, "furnish", "front")["why"], "천이 2 든다")
	assert_false(Mods.start_job(g, "furnish", "front"))
	assert_eq(g, before)
	g["dom"]["cloth"] = 4.0
	assert_true(Mods.start_job(g, "furnish", "front"))
	assert_eq(g["dom"]["job"]["paid"], {"wood": 1.0, "scrap": 6.0, "parts": 0.0, "cloth": 2.0})
	g["dom"]["job"]["paid"] = {"wood": 0.25, "scrap": 1.5, "parts": 0.75, "cloth": 0.5}
	assert_true(Mods.cancel_job(g))
	assert_eq([g["dom"]["wood"], g["dom"]["scrap"], g["dom"]["parts"], g["dom"]["cloth"]], [98.25, 92.5, 20.75, 2.5])
	assert_true(Mods.start_job(g, "furnish", "front"))
	Mods.advance_job(g, 0.25)
	before = g.duplicate(true)
	assert_false(Mods.cancel_job(g))
	assert_eq(g, before)


func test_furnish_contract_rejects_malformed_state_and_jobs() -> void:
	var g: Dictionary = _furnish_game()
	Mods.place_furniture(g, "tail1", "piano")
	var valid: Dictionary = Mods.furnish_of(g, "tail1").duplicate(true)
	assert_true(Dom.is_store({"furnish": {"tail1": valid}}))
	assert_true(Dom.is_store({"job": {"kind": "insulate", "car": "tail1", "need": 3, "progress": 0, "paid": {"wood": 8, "scrap": 0, "parts": 0}}}))
	for patch: Dictionary in [{"work": 1}, {"jobs": [1, 1], "work": 2}, {"jobs": [4], "work": 1},
		{"jobs": [1.5], "work": 1}, {"jobs": [true], "work": 1}, {"jobs": ["1"], "work": 1},
		{"furnPts": 4}, {"furnPts": NAN}, {"tier": -1}, {"tier": 4, "best": 4}, {"best": 0}, {"best": 2}, {"tier": 0.5},
		{"items": [{"kind": "piano", "size": "small"}]}, {"items": [{"kind": "unknown", "size": "large"}]},
		{"extra": true},
		{"tier": 3, "best": 3}, {"tier": 0, "best": 0}, {"jobs": [1, 2, 3], "work": 3}]:
		var bad: Dictionary = valid.duplicate(true)
		bad.merge(patch, true)
		assert_false(Dom.is_store({"furnish": {"tail1": bad}}), str(patch))
	var two_large: Dictionary = valid.duplicate(true)
	two_large.merge({"items": [{"kind": "piano", "size": "large"}, {"kind": "piano", "size": "large"}], "furnPts": 4}, true)
	assert_true(Dom.is_store({"furnish": {"tail1": two_large}}), "floor capacity replaces the old one-large cap")
	var kept: Dictionary = valid.duplicate(true)
	kept.merge({"items": [], "furnPts": 0}, true)
	assert_true(Dom.is_furnish(kept), "a tier kept after the furniture left is a real save")
	var dropped: Dictionary = kept.duplicate(true)
	dropped.merge({"tier": 0, "best": 1}, true)
	assert_true(Dom.is_furnish(dropped), "the tier drops with the furniture while best stays")
	kept.merge({"jobs": [1, 2, 3], "work": 3, "tier": 3, "best": 3}, true)
	assert_true(Dom.is_furnish(kept))
	for key: String in valid:
		var missing: Dictionary = valid.duplicate(true)
		missing.erase(key)
		assert_false(Dom.is_furnish(missing), "missing " + key)
	for car: String in ["engine", "store", "tail4"]:
		assert_false(Dom.is_store({"furnish": {car: valid}}))
	assert_false(Dom.is_store({"furnish": []}))
	assert_true(Mods.start_job(g, "furnish", "front"))
	var job: Dictionary = g["dom"]["job"].duplicate(true)
	assert_true(Dom.is_job(job))
	for patch: Dictionary in [{"car": "engine"}, {"furnishStep": 0}, {"furnishStep": 1.5}, {"furnishStep": 4}, {"furnishStep": true}, {"furnishStep": "1"}, {"furnishStep": NAN}, {"furnishStep": INF}, {"paid": {"wood": 1, "scrap": 3, "cloth": -1}}]:
		var bad: Dictionary = job.duplicate(true)
		bad.merge(patch, true)
		assert_false(Dom.is_job(bad), str(patch))
	job.erase("furnishStep")
	assert_false(Dom.is_job(job))


func test_furnish_raw_situation_counts_one_stove_per_car_and_crowd_without_dividing() -> void:
	var g: Dictionary = _furnish_game()
	for kind: String in ["small_stove", "iron_stove", "bed_frame"]:
		assert_true(Mods.place_furniture(g, "tail1", kind)["ok"])
	var sit: Array[float] = LawTech.sit(g, "tail")
	assert_almost_eq(sit[0], 4.0 / 3.0, 1e-9, "one largest stove, divided by three cars")
	assert_almost_eq(sit[2], 1.0, 1e-9, "0.5 + 1.5 + (0.5 - 1) - tier * 0.5, not divided")
	for i: int in 3:
		assert_true(Mods.place_furniture(g, "tail2", "chair")["ok"])
	sit = LawTech.sit(g, "tail")
	assert_almost_eq(sit[0], 5.0 / 3.0, 1e-9, "second car adds its own tier stove")
	assert_almost_eq(sit[2], 0.5, 1e-9, "second car adds its own tier crowd relief")
	assert_eq(LawTech.sit(g, "engine"), [0.0, 0.0, 0.0, 0.0] as Array[float])


func test_settlement_compares_after_workshop_finishes_a_tier() -> void:
	var g: Dictionary = _furnish_game()
	assert_true(Mods.start_job(g, "furnish", "front"))
	Workshop.stretch(g)
	assert_eq(Mods.furnish_of(g, "front")["tier"], 1)
	assert_eq(g["comms"]["front"]["rel"], 2.0)
	for c: String in ["tail", "medtech", "guard"]:
		assert_eq(g["comms"][c]["rel"], -0.5, "new tier compares in this settlement")
	assert_eq(g["comms"]["engine"]["rel"], 0.0)
	assert_eq(g["ledger"][0], {"k": "rel:front", "d": 2.0, "why": "furnish"})


func _label(row: Dictionary) -> String:
	return "%s/%d/%d" % [row["seed"], int(row["step"]), int(row["profile"])]


func _owned(g: Dictionary) -> Dictionary:
	var d: Dictionary = g["dom"]
	return {"wood": d["wood"], "scrap": d["scrap"], "insulated": d["insulated"],
		"job": d["job"], "journal": g.get("journal", [])}


func _effects(g: Dictionary) -> Dictionary:
	var sit := {}
	for c: String in _data["tables"]["COMMS"]:
		sit[c] = State.situation(g, _data["tables"], c)
	return {"heat": Turn.heat_cost(g, _data["tables"]), "situation": sit}


func _cancel(sample: Dictionary, input: Dictionary, label: String) -> void:
	var g: Dictionary = input.duplicate(true)
	_same(sample["result"], Mods.cancel_job(g), label + " cancel result")
	_same(sample["after"], _owned(g), label + " cancel after")
	_same(sample["effects"], _effects(g), label + " cancel effects")


func _run(sample: Dictionary, input: Dictionary, label: String, direct: bool = false) -> void:
	var g: Dictionary = input.duplicate(true)
	var got: Dictionary = Mods.advance_job(g, Workshop.work_power(g)) if direct else Workshop.run(g)
	_same(sample["result"], {"used": got["used"], "did": got["did"]}, label + " run result")
	_same(sample["after"], _owned(g), label + " run after")
	_same(sample["effects"], _effects(g), label + " run effects")
	var events: Array = []
	if sample["completed"] != null:
		var car: String = String(sample["completed"])
		events.append({"kind": "mod_done", "car": car, "comm": Mods.CAR_COMM[car],
			"sign": 1, "size": 0.4, "day": int(g["seg"])})
	_same(events, got["events"], label + " completion events")


func test_s1_constants_and_text() -> void:
	for key: String in ["D", "CAR_COMM", "COMM_CARS", "CAR_NAME", "HEAT_QUOTA_MATS"]:
		var port: Dictionary = {"D": Mods.D, "CAR_COMM": Mods.CAR_COMM, "COMM_CARS": Mods.COMM_CARS,
			"CAR_NAME": Mods.CAR_NAME, "HEAT_QUOTA_MATS": Mods.HEAT_QUOTA_MATS}
		_same(_data["tables"][key], port[key], key)
	_same(_data["pickLine"], Mods.insulate_pick_line(), "pick line")
	assert_eq(_bad, [] as Array[String])


func test_heat_and_situation_with_and_without_insulation_against_s1() -> void:
	for row: Dictionary in _data["cases"]:
		var g: Dictionary = row["state"]
		var bare: Dictionary = g.duplicate(true)
		bare["dom"]["insulated"] = []
		var got: Dictionary = _effects(g)
		var without: Dictionary = _effects(bare)
		_same(row["effects"], got, _label(row) + " insulated")
		_same(row["without"], without, _label(row) + " without")
		for c: String in Mods.COMM_CARS:
			var want_delta: Array = []
			var got_delta: Array = []
			for i: int in 4:
				want_delta.append(float(row["effects"]["situation"][c][i]) - float(row["without"]["situation"][c][i]))
				got_delta.append(float(got["situation"][c][i]) - float(without["situation"][c][i]))
			_same(want_delta, got_delta, _label(row) + " delta " + c)
			_same(row["share"][c], Mods.insulated_share(g, c), _label(row) + " share " + c)
			var count: int = 0
			for car: String in g["dom"]["insulated"]:
				count += int(Mods.CAR_COMM[car] == c)
			_same(count, Mods.insulated_count(g, c), _label(row) + " count " + c)
		assert_true(Dom.is_store(g["dom"]), _label(row) + " dom")
		assert_true(State.is_s1a(g), _label(row) + " supported subset")
	assert_eq(_bad, [] as Array[String])


func test_legacy_no_dom_and_empty_insulation_keep_s1a_values() -> void:
	for row: Dictionary in _data["legacy"]:
		var g: Dictionary = row["state"].duplicate(true)
		_same(row["effects"], _effects(g), "legacy no dom")
		g["dom"] = {"insulated": [], "job": null}
		_same(row["effects"], _effects(g), "legacy empty")
		g["dom"] = null
		_same(row["effects"], _effects(g), "legacy null")
	assert_eq(_bad, [] as Array[String])


func test_job_checks_starts_and_per_car_words_against_s1() -> void:
	var accepted: int = 0
	for row: Dictionary in _data["cases"]:
		for car_row: Dictionary in row["perCar"]:
			var car: String = String(car_row["car"])
			var g: Dictionary = row["state"].duplicate(true)
			var label: String = _label(row) + " " + car
			_same(car_row["check"], Mods.job_check(g, "insulate", car), label + " check")
			_same(car_row["title"], Mods.job_title("insulate", car), label + " title")
			_same(car_row["numbers"], Mods.insulate_numbers(car), label + " numbers")
			_same(car_row["note"], Mods.insulate_car_note(g, car), label + " note")
			var result: bool = Mods.start_job(g, "insulate", car)
			accepted += int(result)
			_same(car_row["start"]["result"], result, label + " start result")
			_same(car_row["start"]["after"], _owned(g), label + " start after")
			if car_row.has("chain"):
				_cancel(car_row["chain"]["cancel"], g, label + " chain")
				_run(car_row["chain"]["run"], g, label + " chain")
	assert_gt(accepted, 20)
	assert_eq(_bad, [] as Array[String])


func test_cancel_and_modify_only_workshop_against_s1() -> void:
	var completed: int = 0
	for row: Dictionary in _data["cases"]:
		_same(row["cancelOpen"], Mods.cancel_open(row["state"]), _label(row) + " cancel open")
		_same(row["work"], Workshop.work_power(row["state"]), _label(row) + " work")
		_cancel(row["cancel"], row["state"], _label(row))
		_run(row["run"], row["state"], _label(row))
		_run(row["run"], row["state"], _label(row) + " direct", true)
		completed += int(row["run"]["completed"] != null)
	assert_gt(completed, 8)
	assert_eq(_bad, [] as Array[String])


func _ready_game() -> Dictionary:
	var g := {"seg": 7, "dom": Dom.start(), "journal": []}
	g["dom"]["wood"] = 40.0
	g["dom"]["techs"]["e5"] = {"stage": "done", "defect": false, "progress": 3, "need": 3}
	return g


func test_dom_contract_accepts_only_the_insulation_subset() -> void:
	var d: Dictionary = Dom.start()
	assert_eq(d["insulated"], [])
	assert_null(d["job"])
	assert_true(Dom.is_store(d))
	assert_true(Dom.is_store({"insulated": Mods.CAR_COMM.keys(), "job": null}))
	var valid := {"kind": "insulate", "car": "tail1", "progress": 0.0, "need": 3.0,
		"paid": {"wood": 5.5, "scrap": 1.25}}
	assert_true(Dom.is_store({"job": valid}))
	for insulated: Variant in [null, "tail1", [1], ["store"], ["tail1", "tail1"]]:
		assert_false(Dom.is_store({"insulated": insulated}), str(insulated))
	for replacement: Dictionary in [{"kind": "armor"}, {"kind": "convert"}, {"car": "cold"}, {"car": 1},
		{"progress": -1}, {"progress": 4}, {"progress": NAN}, {"need": 0}, {"need": INF},
		{"paid": null}, {"paid": {"wood": 8}}, {"paid": {"wood": -1, "scrap": 0}},
		{"paid": {"wood": 8, "scrap": 0, "coal": 1}}, {"paid": {"wood": INF, "scrap": 0}}, {"extra": true}]:
		var bad: Dictionary = valid.duplicate(true)
		bad.merge(replacement, true)
		assert_false(Dom.is_store({"job": bad}), str(replacement))
	for key: String in valid:
		var missing: Dictionary = valid.duplicate(true)
		missing.erase(key)
		assert_false(Dom.is_store({"job": missing}), "missing " + key)
	for key: String in ["armored", "greenhouse", "order", "bedding", "sit", "workDebt"]:
		assert_false(Dom.is_store({key: []}), "unported " + key)


func test_e5_gate_unsupported_mods_and_residential_cars() -> void:
	var g := {"seg": 0, "dom": Dom.start()}
	assert_eq(Mods.job_check(g, "insulate", "tail1"), {"ok": false, "why": "단열 개조를 아직 모른다"})
	assert_false(Mods.start_job(g, "insulate", "tail1"))
	g = _ready_game()
	for stage: String in ["restoring", "done", "defective"]:
		g["dom"]["techs"]["e5"]["stage"] = stage
		g["dom"]["techs"]["e5"]["off"] = true
		assert_eq(Mods.job_check(g, "insulate", "tail1")["ok"], stage != "restoring", "S1 usable, not mult")
	var before: Dictionary = g.duplicate(true)
	for kind: String in ["armor", "convert", "greenhouse", "unknown"]:
		assert_eq(Mods.job_check(g, kind, "guard"), {"ok": false, "why": "아직 이 열차에서 못 쓴다"})
		assert_false(Mods.start_job(g, kind, "guard"))
	assert_eq(g, before)
	for car: String in ["cold", "store", "dining", "captain", "workshop", "unknown"]:
		assert_eq(Mods.job_check(g, "insulate", car), {"ok": false, "why": "사람이 사는 칸만"})
	assert_true(Research.visible(g).has("e5"))
	assert_eq(Research.restore_cost("e5")["frags"], 0)


func test_cancel_refunds_saved_payment_and_refuses_after_first_work() -> void:
	var g: Dictionary = _ready_game()
	assert_true(Mods.start_job(g, "insulate", "tail1"))
	assert_false(Mods.start_job(g, "insulate", "tail2"))
	g["dom"]["job"]["paid"] = {"wood": 2.25, "scrap": 1.75}
	assert_true(Mods.cancel_open(g))
	assert_true(Mods.cancel_job(g))
	assert_eq(g["dom"]["wood"], 34.25)
	assert_eq(g["dom"]["scrap"], 11.75)
	assert_false(Mods.cancel_job(g))
	assert_true(Mods.start_job(g, "insulate", "tail1"))
	var before: Dictionary = g.duplicate(true)
	assert_eq(Mods.advance_job(g, 0), {"used": 0.0, "did": [], "events": []})
	assert_eq(Mods.advance_job(g, -1), {"used": 0.0, "did": [], "events": []})
	assert_eq(g, before)
	Mods.advance_job(g, 0.25)
	assert_false(Mods.cancel_open(g))
	before = g.duplicate(true)
	assert_false(Mods.cancel_job(g))
	assert_eq(g, before)
	var done: Dictionary = Mods.advance_job(g, 10)
	assert_eq(done["used"], 2.75)
	assert_eq(g["dom"]["insulated"], ["tail1"])
	assert_null(g["dom"]["job"])
	assert_eq(Mods.job_check(g, "insulate", "tail1"), {"ok": false, "why": "이미 단열했다"})
	assert_eq(Mods.advance_job(g, 10), {"used": 0.0, "did": [], "events": []}, "no duplicate completion")


func test_parts_making_restore_then_modification_share_one_work_budget() -> void:
	var g: Dictionary = _ready_game()
	g["dom"]["target"] = 1
	g["dom"]["parts"] = 0
	g["dom"]["frags"]["craft"] = 1
	assert_true(Research.start_restore(g, "w1", "full"))
	assert_true(Workshop.start(g, "bow"))
	assert_true(Mods.start_job(g, "insulate", "tail1"))
	var first: Dictionary = Workshop.run(g)
	assert_eq(first["parts"], 1)
	assert_eq(first["made"], ["bow"])
	assert_eq(first["used"], 5.0)
	assert_eq(g["dom"]["techs"]["w1"]["progress"], 1.0)
	assert_eq(g["dom"]["job"]["progress"], 0.0)
	assert_true(Mods.cancel_open(g), "parts/making/research did not touch modification")
	assert_eq(first["events"].size(), 1)
	assert_eq(first["events"][0]["kind"], "made")
	var second: Dictionary = Workshop.run(g)
	assert_eq(second["used"], 5.0)
	assert_eq(second["did"], [String(Research.TECHS["w1"]["name"]) + " 복원", "꼬리칸 1 단열"])
	assert_eq(second["events"], [{"kind": "mod_done", "car": "tail1", "comm": "tail", "sign": 1, "size": 0.4, "day": 7}])
	assert_eq(g["dom"]["insulated"], ["tail1"])
	assert_true(Dom.is_store(g["dom"]))
