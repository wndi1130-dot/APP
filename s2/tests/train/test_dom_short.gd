extends GutTest
## The 「부품이 모자란다」 paper (S1 domestic/cards.ts dom:short, its upkeep half):
## upkeep the stores cannot pay raises it once in three stretches
## (train_research.gd pay_upkeep), its three ways — stand one down, run on,
## parts target +3 — and the stood-down technology running again for the part
## it gave back (S1 standDown, restartTech).

const TrainDom = preload("res://game/train/train_dom.gd")
const Research = preload("res://game/train/train_research.gd")
const TrainWorkshop = preload("res://game/train/train_workshop.gd")
const TurnCards = preload("res://game/train/turn/turn_cards.gd")
const CardText = preload("res://game/train/turn/turn_card_text.gd")
const St = preload("res://game/train/train_state.gd")
const PATH: String = "res://tests/fixtures/train/turn_vectors.json"

var _data: Dictionary = {}


func before_all() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_data = parsed


## A train board from S1's record with the stores, e2 (parts 0.25) and e4
## (parts 0.5) working, and the parts the stores have.
func _board(parts: float) -> Dictionary:
	var g: Dictionary = (_data["runs"][0]["steps"][0]["before"] as Dictionary).duplicate(true)
	g["dom"] = TrainDom.start()
	g["dom"]["parts"] = parts
	for id: String in ["e2", "e4"]:
		g["dom"]["techs"][id] = {"stage": "done", "defect": false, "progress": 2, "need": 2}
	g["cards"] = []
	return g


func _papers(g: Dictionary) -> Array:
	return (g["cards"] as Array).filter(func(c: Dictionary) -> bool: return c["kind"] == "dom:short")


func test_upkeep_unpaid_raises_the_paper_once_in_three_stretches() -> void:
	var g := _board(0.0)
	assert_eq(Research.pay_upkeep(g), ["e2", "e4"] as Array[String])
	assert_eq(_papers(g).size(), 1)
	assert_eq(String(_papers(g)[0]["text"]), "e2,e4")
	Research.pay_upkeep(g)
	assert_eq(_papers(g).size(), 1, "not twice while it waits")
	g["cards"] = []
	g["eventLog"] = {"dom:short": {"n": 1, "seg": int(g["seg"]) - 2}}
	Research.pay_upkeep(g)
	assert_eq(_papers(g).size(), 0, "two stretches since the last: not yet")
	g["eventLog"]["dom:short"]["seg"] = int(g["seg"]) - 3
	Research.pay_upkeep(g)
	assert_eq(_papers(g).size(), 1, "three stretches since: again")
	var paid := _board(5.0)
	Research.pay_upkeep(paid)
	assert_eq(_papers(paid).size(), 0, "paid: no paper")
	var bare := {"seg": 2, "dom": _board(0.0)["dom"]}
	Research.pay_upkeep(bare)
	assert_false(bare.has("cards"), "a board with no papers gets none")


func test_the_paper_reads_s1_s_words() -> void:
	var g := _board(0.0)
	Research.pay_upkeep(g)
	var v: Dictionary = CardText.view(g, _data["tables"], _papers(g)[0])
	assert_eq(v["title"], "부품이 모자란다")
	assert_eq(v["body"], "유지비를 못 낸 기계가 반쯤만 돈다(%s, %s)." % [Research.TECHS["e2"]["name"], Research.TECHS["e4"]["name"]])
	var labels: Array = (v["choices"] as Array).map(func(c: Dictionary) -> String: return String(c["label"]))
	assert_eq(labels, ["하나를 세운다", "그냥 달린다", "목표치 +3"])
	assert_eq(v["choices"][0]["why"], "기술 하나가 멈춘다")


func test_stand_one_down_stops_the_largest_and_gives_back_a_part() -> void:
	var g := _board(0.0)
	Research.pay_upkeep(g)
	var uid: int = int(_papers(g)[0]["uid"])
	var out: Dictionary = TurnCards.choose(g, _data["tables"], uid, 0)
	assert_false(out.has("_turn_port_error"), str(out.get("_turn_port_error", "")))
	assert_true(bool(out["dom"]["techs"]["e4"]["off"]), "e4 takes the most parts")
	assert_false(bool(out["dom"]["techs"]["e2"].get("off", false)))
	assert_eq(float(out["dom"]["parts"]), 1.0, "its part comes back")
	assert_eq(Research.mult(out, {}, "e4"), 0.0, "it does nothing while stood down")
	assert_true(St.is_s1a(out), "a stood-down technology is still the stores S2 carries")
	assert_eq(int(out["eventLog"]["dom:short"]["seg"]), int(g["seg"]), "the paper's cooldown starts")
	assert_eq(_papers(out).size(), 0)


func test_run_on_and_raise_the_target() -> void:
	var g := _board(0.0)
	Research.pay_upkeep(g)
	var uid: int = int(_papers(g)[0]["uid"])
	var on: Dictionary = TurnCards.choose(g, _data["tables"], uid, 1)
	assert_eq(on["dom"]["techs"], g["dom"]["techs"], "running on changes no technology")
	var up: Dictionary = TurnCards.choose(g, _data["tables"], uid, 2)
	assert_eq(TrainWorkshop.target(up), TrainWorkshop.TARGET0 + 3)


func test_a_stood_down_technology_runs_again_for_the_part() -> void:
	var g := _board(1.0)
	assert_eq(Research.restart_why(g, "e4"), "세워 둔 기술이 아니다")
	assert_eq(Research.stand_down(g), "e4")
	assert_eq(float(g["dom"]["parts"]), 2.0)
	g["dom"]["parts"] = 0.5
	assert_eq(Research.restart_why(g, "e4"), "세울 때 돌려받은 부품 1이 든다")
	assert_false(Research.restart(g, "e4"))
	g["dom"]["parts"] = 1.0
	assert_true(Research.restart(g, "e4"))
	assert_eq(float(g["dom"]["parts"]), 0.0, "the part is paid back")
	assert_false(bool(g["dom"]["techs"]["e4"]["off"]))
	assert_false(g["dom"]["techs"]["e4"].has("refund"))
	assert_gt(Research.mult(g, {}, "e4"), 0.0)
	var none := _board(0.0)
	none["dom"]["techs"] = {}
	assert_null(Research.stand_down(none), "nothing takes parts: nothing to stand down")
