extends "res://addons/gut/test.gd"
## Choosing the stop on paper (stop_pick_card.gd): it says what the train's own
## rules say for the state it is given, and a pick goes through set_stop.

const StopPickCard = preload("res://game/ui/stop_pick_card.gd")
const TrainStop = preload("res://game/train/train_stop.gd")


func test_the_card_says_what_the_train_rules_say_for_the_sample_stop() -> void:
	var s: Array = StopPickCard.sample()
	var g: Dictionary = s[0]
	var t: Dictionary = s[1]
	assert_false(g.is_empty(), "the train sample is there")
	var m: Dictionary = StopPickCard.model(g, t)
	assert_false(m.has("seg"), "no 「1 구간 정차」 kick (결정 417)")
	assert_eq(m["place"], "병원")
	assert_eq(m["hint"], "", "no line on what the place holds: the target chips' fill says it (결정 417)")
	assert_eq(m["risk"], "?", "not scouted: not known")
	assert_eq(m["stays"].map(func(r): return "%s %s" % [r["word"], r["cost"]]), ["짧게 석탄 −1", "보통 석탄 −2", "길게 석탄 −3"])
	assert_eq(m["targets"].filter(func(r): return r["on"]).map(func(r): return r["id"]), ["food"])
	assert_eq(m["crews"].map(func(r): return r["word"]), ["꼬리", "의무", "경비", "앞칸"])
	assert_eq(m["size"], 4)
	var pre: Dictionary = TrainStop.crew_preview(g, t, "tail")
	assert_true(String(m["crew_line"]).begins_with("노출 %d → %d · " % [int(pre["from"]), int(pre["to"])]), m["crew_line"])
	var named: Dictionary = StopPickCard.model(g, t, "술레후프")
	assert_eq(named["place"], "술레후프")
	assert_eq(named["hint"], "병원", "the kind of place under its own name")


func test_a_pick_goes_through_the_train_rule() -> void:
	var c = StopPickCard.new()
	add_child_autofree(c)
	c.pick("target", "medicine")
	assert_eq(c.g["stop"]["target"], "medicine")
	c.pick("crewSize", 12)
	assert_eq(int(c.g["stop"]["crewSize"]), 8, "set_stop keeps the crew to 2–8")
	assert_eq((c.find_child("CrewSize", true, false) as Label).text, "8", "the card is drawn again (명 is its own smaller word)")
	c.pick("crewComm", "engine")
	assert_eq(c.g["stop"]["crewComm"], "tail", "the engine car cannot be sent")


func test_its_keys_send_or_pass_the_stop_by() -> void:
	var c = StopPickCard.new()
	add_child_autofree(c)
	var got: Array = []
	c.sent.connect(func(g): got.append(g))
	c.passed_by.connect(func(): got.append("passed"))
	(c.find_child("Send", true, false) as Button).pressed.emit()
	(c.find_child("PassBy", true, false) as Button).pressed.emit()
	assert_eq(got.size(), 2)
	assert_eq(got[0]["stop"]["place"], "hospital", "sent with the state as picked")
	assert_eq(got[1], "passed")


func test_the_promises_the_stop_goes_with_are_one_line() -> void:
	var c = StopPickCard.new()
	c.promises = [{"kind": "prologue", "subjects": ["a", "b"]}, {"kind": "skip_dispatch", "madeTo": "tail"}]
	add_child_autofree(c)
	assert_eq(_said(c.find_child("Promises", true, false)), "서막 2명 데려오기 / 교대 꼬리칸 파견 제외", "one line, its numbers in their own face (no 「이번 정차」 nor 「약속」: 결정 417)")
	var plain = StopPickCard.new()
	add_child_autofree(plain)
	assert_null(plain.find_child("Promises", true, false), "no promise, no line")


## The words of a line made of several labels, read left to right.
func _said(line: Node) -> String:
	var out: String = ""
	for l in line.get_children():
		if l is Label:
			out += (l as Label).text
	return out
