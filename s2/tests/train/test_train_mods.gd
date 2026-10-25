extends "res://addons/gut/test.gd"
## PR4's S1 oracle, compared in both directions like test_train_research.gd.

const Mods = preload("res://game/train/train_mods.gd")
const Dom = preload("res://game/train/train_dom.gd")
const Research = preload("res://game/train/train_research.gd")
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
		{"paid": {"wood": 8, "scrap": 0, "parts": 1}}, {"paid": {"wood": INF, "scrap": 0}}, {"extra": true}]:
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
