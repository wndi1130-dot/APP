extends "res://addons/gut/test.gd"
## Strict bidirectional comparisons of PR6-owned state with S1 function answers.

const Research = preload("res://game/train/train_research.gd")
const Workshop = preload("res://game/train/train_workshop.gd")
const Dom = preload("res://game/train/train_dom.gd")
const TV = preload("res://tests/train/train_vectors.gd")
const PATH := "res://tests/fixtures/train/tech_vectors.json"
static var _data: Dictionary = {}
var _bad: Array[String] = []


func before_all() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(_data.get("format"), "tech-vectors-v1")
	assert_eq((_data["cases"] as Array).size(), (_data["seeds"] as Array).size() * 8 * 23)


func test_furnish_and_transport_research_do_not_bypass_the_main_branch() -> void:
	assert_eq(Research.prereqs("x4"), ["x1"] as Array[String])
	assert_eq(Research.prereqs("x3"), ["x2"] as Array[String])
	assert_eq(Research.prereqs("w3"), ["w2"] as Array[String])
	assert_eq(Research.prereqs("w5"), [] as Array[String])
	assert_eq(Research.TECHS["w5"]["tier"], 0)
	assert_eq(Research.TECHS["w5"]["adapt"], {"parts": 1, "wood": 4})
	assert_true(Research.visible({}).has("w5"))
	assert_true(Research.visible({}).has("x4"))


func before_each() -> void:
	_bad.clear()


func _same(want: Variant, got: Variant, label: String) -> void:
	var diff: String = TV.diff(want, got, label)
	if diff == "":
		diff = TV.diff(got, want, label + " unexpected")
	if diff != "" and _bad.size() < 12:
		_bad.append(diff)


func _label(row: Dictionary) -> String:
	return "%s/%d/%s" % [row["seed"], int(row["profile"]), row["id"]]


func test_s1_tables_and_start_roster() -> void:
	var tables: Dictionary = _data["tables"]
	_same(tables["TECHS"], Research.TECHS, "TECHS")
	_same(tables["D"], Research.D, "D")
	_same(tables["FIELDS"], Research.FIELDS, "FIELDS")
	_same(tables["BRANCH_NAME"], Research.BRANCH_NAME, "BRANCH_NAME")
	_same(tables["ZONE_WORK"], Research.ZONE_WORK, "ZONE_WORK")
	_same(tables["ZONE0"], Research.ZONE0, "ZONE0")
	_same(tables["NOT_YET"], Research.NOT_YET, "NOT_YET")
	_same(tables["GEAR_TECHS"], Research.GEAR_TECHS, "GEAR_TECHS")
	_same(tables["TECH_IDS"], Research.TECHS.keys(), "TECH_IDS")
	_same(tables["TECH_IDS"], Dom.TECH_IDS, "dom ids")
	_same(_data["start"]["experts"], Dom.start()["experts"], "start experts")
	_same(_data["start"]["frags"], Dom.start()["frags"], "start frags")
	for i in Dom.START_EXPERTS.size():
		for key: String in ["comm", "field", "skill"]:
			_same(tables["SPECIALISTS"][i][key], Dom.START_EXPERTS[i][key], "specialist %d %s" % [i, key])
	for id: String in tables["TECH_IDS"]:
		_same(tables["prereqs"][id], Research.prereqs(id), id + " prereqs")
		_same(tables["skillNeed"][id], Research.TECHS[id]["tier"], id + " skill")
	assert_eq(_bad, [] as Array[String])


func test_all_read_functions_against_s1() -> void:
	for row: Dictionary in _data["cases"]:
		var g: Dictionary = row["state"]
		var id: String = String(row["id"])
		var want: Dictionary = row["read"].duplicate(true)
		var skills: Dictionary = {}
		for field: String in Research.FIELDS:
			skills[field] = Research.top_skill(g, field)
		var got: Dictionary = {"cost": Research.restore_cost(id), "block": Research.restore_block(g, id),
			"check": Research.restore_check(g, id), "finish": Research.finish_check(g, id), "upkeep": Research.upkeep_of(g, id),
			"work": Workshop.work_power(g), "usable": Research.usable(g, {}, id), "mult": Research.mult(g, {}, id),
			"prereqs": Research.prereqs(id), "visible": Research.visible_techs(g), "skills": skills}
		# Decision 449's W4 gear exception has its own S2 comparisons below.
		if not bool(g.get("gearOn", false)):
			(got["visible"] as Array).erase("w4")
			if id == "w4":
				for key: String in ["block", "check"]:
					want.erase(key)
					got.erase(key)
		_same(want, got, _label(row))
		_same(Research.VISIBLE, Research.visible(g), _label(row) + " S2 visible")
		assert_true(Dom.is_store(g["dom"]), _label(row) + " projected state")
	assert_eq(_bad, [] as Array[String])


func test_start_and_finish_against_s1() -> void:
	var accepted: int = 0
	for row: Dictionary in _data["cases"]:
		var id: String = String(row["id"])
		for sample: Dictionary in row["starts"]:
			# S1 blocks W4 without gear; S2 compares these modes with gear-on answers below.
			if id == "w4" and not bool(sample["before"].get("gearOn", false)):
				continue
			var g: Dictionary = sample["before"].duplicate(true)
			var result: bool = Research.start_restore(g, id, String(sample["mode"]), sample["variant"])
			accepted += int(result)
			_same(sample["result"], result, _label(row) + " start result")
			_same(sample["after"], g, _label(row) + " start after")
		var finish: Dictionary = row["finish"]
		var g: Dictionary = finish["before"].duplicate(true)
		_same(finish["result"], Research.start_finish(g, id), _label(row) + " finish result")
		_same(finish["after"], g, _label(row) + " finish after")
	assert_gt(accepted, 100)
	assert_eq(_bad, [] as Array[String])


func _cancel(sample: Dictionary, label: String) -> void:
	var g: Dictionary = sample["before"].duplicate(true)
	Research.cancel_restore(g)
	_same(sample["after"], g, label + " cancel")


func _run(sample: Dictionary, label: String) -> void:
	var g: Dictionary = sample["before"].duplicate(true)
	var got: Dictionary = Workshop.run(g)
	_same(sample["result"], {"used": got["used"], "did": got["did"]}, label + " run result")
	_same(sample["after"], g, label + " run after")


func test_cancel_and_work_allocation_against_s1() -> void:
	var chains: int = 0
	for row: Dictionary in _data["cases"]:
		_cancel(row["cancel"], _label(row))
		_run(row["run"], _label(row))
		for chain: Dictionary in row["chains"]:
			chains += 1
			_cancel(chain["cancel"], _label(row) + " " + String(chain["kind"]))
			_run(chain["run"], _label(row) + " " + String(chain["kind"]))
	assert_gt(chains, 100)
	assert_eq(_bad, [] as Array[String])


func test_upkeep_against_s1() -> void:
	for row: Dictionary in _data["cases"]:
		var sample: Dictionary = row["upkeep"]
		var g: Dictionary = sample["before"].duplicate(true)
		_same(sample["result"], Research.pay_upkeep(g), _label(row) + " upkeep result")
		_same(sample["after"], g, _label(row) + " upkeep after")
	assert_eq(_bad, [] as Array[String])


func test_making_stays_between_parts_and_research() -> void:
	var g: Dictionary = {"dom": Dom.start()}
	g["dom"]["frags"]["craft"] = 1
	assert_true(Research.start_restore(g, "w1", "full"))
	assert_true(Workshop.start(g, "bow"))
	var result: Dictionary = Workshop.run(g)
	assert_eq(result["parts"], 1)
	assert_eq(result["made"], ["bow"])
	assert_eq(float(g["dom"]["techs"]["w1"]["progress"]), 1.0, "5 work: parts 1, bow 3, research 1")
	assert_eq(g["dom"]["restoring"], "w1")
	Workshop.run(g)
	assert_true(Research.usable(g, {}, "w1"))
	assert_almost_eq(Workshop.work_power(g), 6.25, 1e-6)


func test_empty_roster_and_legacy_save_are_distinct() -> void:
	assert_eq(Workshop.work_power({"dom": {"experts": []}}), 2.0)
	assert_eq(Workshop.work_power({}), 4.0, "legacy S1a fixed work is preserved")
	var g: Dictionary = {"dom": Dom.start()}
	g["dom"]["techs"]["w1"] = {"stage": "done", "defect": false, "need": 3, "progress": 3}
	g["hands"] = {"short": {"repair": 0.5}}
	assert_eq(Workshop.work_power(g), 6.25 * 0.75)
	g["dom"]["techs"]["w1"]["off"] = true
	assert_eq(Workshop.work_power(g), 5.0 * 0.75)


func test_workshop_technologies_are_visible_without_scouting() -> void:
	var g: Dictionary = {"gearOn": false, "dom": Dom.start()}
	for id: String in ["w2", "w4"]:
		assert_true(Research.VISIBLE.has(id), id)
		assert_true(Research.visible(g).has(id), id)
	assert_true(Research.visible_techs(g).has("w4"))
	assert_false(Research.visible_techs(g).has("r4"))
	assert_false(Research.visible(g).has("r4"))


func test_w4_restores_without_gear_but_r4_stays_blocked() -> void:
	var g: Dictionary = {"dom": Dom.start()}
	assert_null(Research.restore_block(g, "w4"), "no gear flag")
	g["gearOn"] = false
	assert_null(Research.restore_block(g, "w4"), "gear is off")
	assert_eq(Research.restore_block(g, "r4"), "아직 이 열차에서 못 쓴다")
	assert_false(Research.start_restore(g, "r4", "full", "a"))
	assert_true(Research.start_restore(g, "w4", "full"))
	assert_eq([float(g["dom"]["parts"]), float(g["dom"]["wood"])], [3.0, 8.0])
	var result: Dictionary = Research.advance_restore(g, 3.0)
	assert_eq(result.get("done"), "w4")
	assert_true(Research.usable(g, {}, "w4"))
	assert_true(Dom.is_store(g["dom"]))


func test_w4_without_gear_keeps_s1_restoration_answers() -> void:
	var compared: int = 0
	for row: Dictionary in _data["cases"]:
		if row["id"] != "w4" or not bool(row["state"].get("gearOn", false)):
			continue
		compared += 1
		var g: Dictionary = row["state"].duplicate(true)
		g["gearOn"] = false
		_same(row["read"]["block"], Research.restore_block(g, "w4"), _label(row) + " S2 block")
		_same(row["read"]["check"], Research.restore_check(g, "w4"), _label(row) + " S2 check")
		for sample: Dictionary in row["starts"]:
			var before: Dictionary = sample["before"].duplicate(true)
			var after: Dictionary = sample["after"].duplicate(true)
			before["gearOn"] = false
			after["gearOn"] = false
			_same(sample["result"], Research.start_restore(before, "w4", String(sample["mode"]), sample["variant"]), _label(row) + " S2 start")
			_same(after, before, _label(row) + " S2 after")
	assert_gt(compared, 0)
	assert_eq(_bad, [] as Array[String])
