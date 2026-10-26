extends GutTest
## The council record and result arc (council_log.gd, S1 council_log.ts). Votes are matched whole
## against S1 by the turn, field, law and deal vectors; this checks the arc branches those runs
## rarely reach: the promise ledger, the closed deals, a handed agenda failing twice.

const CouncilLog = preload("res://game/politics/council_log.gd")
const CouncilVote = preload("res://game/politics/council_vote.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const Cards = preload("res://game/train/turn/turn_cards.gd")
const PATH := "res://tests/fixtures/train/turn_vectors.json"

var _t: Dictionary = {}
var _g0: Dictionary = {}


func before_all() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_t = data["tables"]
	_g0 = data["runs"][0]["steps"][0]["before"]


func _g() -> Dictionary:
	return _g0.duplicate(true)


func test_the_arc_values_are_s1s() -> void:
	assert_eq((_t["ARC"] as Dictionary).keys(), CouncilLog.ARC.keys())
	for key: String in CouncilLog.ARC:
		assert_eq(int(_t["ARC"][key]), int(CouncilLog.ARC[key]), key)
	assert_eq(int(_t["LOG_MAX"]), CouncilLog.LOG_MAX)


func test_the_record_keeps_its_last_rows() -> void:
	var g := _g()
	for i: int in CouncilLog.LOG_MAX + 3:
		CouncilLog.log_vote(g, {"session": i})
	assert_eq((g["councilLog"] as Array).size(), CouncilLog.LOG_MAX)
	assert_eq(int(g["councilLog"][0]["session"]), 3)


func test_two_broken_bring_the_ledger_and_three_close_open_deals() -> void:
	var g := _g()
	var cards := (g["cards"] as Array).size()
	for n: int in 3:
		g["comms"]["tail"]["promise"] = {"label": "시험 약속"}
		FieldReturn._break_promise(g, _t, "tail", "시험 약속")
		if n == 1:
			assert_eq((g["cards"] as Array).size(), cards + 1, "the ledger comes at the second")
			assert_eq(g["cards"][-1]["kind"], "promise_ledger")
	assert_eq((g["cards"] as Array).size(), cards + 1, "once only")
	assert_true(bool(g["comms"]["tail"]["openClosed"]), "the third closes")
	g["council"] = {"options": [{"kind": "law", "law": "heat_quota"}], "idx": 0, "locked": false, "deals": [], "result": null}
	for tool: String in ["open", "fetch"]:
		var status := CouncilVote.tool_status(g, _t, "tail", tool)
		if status.get("why") != "남은 반대는 꿈쩍 않는다" and status.get("why") != "살 표가 없다":
			assert_eq(status.get("why"), "약속을 세 번 어겼다", tool)


func test_the_ledger_card_pays_back_or_offends() -> void:
	var g := _g()
	g["lux"] = 10
	CouncilLog._add_card(g, {"kind": "promise_ledger", "comm": "medtech"})
	var card: Dictionary = g["cards"][-1]
	var view := Cards.view(g, _t, card)
	assert_eq(view["title"], "약속 장부")
	var rel := float(g["comms"]["medtech"]["rel"])
	var paid := Cards.choose(g, _t, int(card["uid"]), 0)
	assert_eq(float(paid["lux"]), 7.0)
	assert_eq(float(paid["comms"]["medtech"]["rel"]), minf(100.0, rel + 8.0))
	var grudge := int(g["comms"]["medtech"]["grudge"])
	var refused := Cards.choose(g, _t, int(card["uid"]), 1)
	assert_eq(int(refused["comms"]["medtech"]["grudge"]), mini(3, grudge + 1), "refusing offends")


func test_harsh_laws_make_a_broken_promise_cost_more() -> void:
	var g := _g()
	var harsh: Array = []
	for law: String in _t["LAWS"]:
		if _t["LAWS"][law].get("tag") == "가혹" and harsh.size() < CouncilLog.ARC["harshLaws"]:
			harsh.append(law)
	for law: String in harsh:
		g["passed"][law] = 0
	var calm := _g()
	g["comms"]["front"]["promise"] = {"label": "시험"}
	calm["comms"]["front"]["promise"] = {"label": "시험"}
	FieldReturn._break_promise(g, _t, "front", "시험")
	FieldReturn._break_promise(calm, _t, "front", "시험")
	assert_eq(float(g["comms"]["front"]["rel"]), maxf(-100.0, float(calm["comms"]["front"]["rel"]) + float(CouncilLog.ARC["harshRel"])))


func test_a_handed_agenda_failing_twice_stings_once() -> void:
	var g := _g()
	var rel := float(g["comms"]["guard"]["rel"])
	CouncilLog.note_held(g, _t, "guard", false)
	assert_eq(float(g["comms"]["guard"]["rel"]), rel, "one fail is borne")
	CouncilLog.note_held(g, _t, "guard", false)
	assert_eq(float(g["comms"]["guard"]["rel"]), maxf(-100.0, rel + float(CouncilLog.ARC["heldRel"])))
	assert_eq(int(g["comms"]["guard"]["heldFails"]), 0)
	CouncilLog.note_held(g, _t, "guard", false)
	CouncilLog.note_held(g, _t, "guard", true)
	assert_eq(int(g["comms"]["guard"]["heldFails"]), 0, "a pass clears the count")
