extends GutTest
## A train-turn card on paper (turn_card.gd): it shows S1's words for the card
## (turn_card_text.gd, checked against card-vectors-v1), a press answers the
## card through the train's own rule, a heavy way takes two presses, a shut way
## shakes, a kind not drawn yet hands back the rule's error, and every kind's
## longest card stays on the sheet.

const TurnCard = preload("res://game/ui/turn_card.gd")
const UiDeny = preload("res://game/ui/ui_deny.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const PATH: String = "res://tests/fixtures/train/card_vectors.json"
## A whole train state to lay a case's part over: a press runs the whole rule.
const TRAIN: String = "res://tests/fixtures/train/train_vectors.json"
const TRAIN_POINT: int = 3

var _data: Dictionary = {}
var _whole: Dictionary = {}


func before_all() -> void:
	if not FileAccess.file_exists(PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary: _data = parsed
	if not FileAccess.file_exists(TRAIN): return
	var train: Variant = JSON.parse_string(FileAccess.get_file_as_string(TRAIN))
	if train is Dictionary: _whole = train["points"][TRAIN_POINT]["state"]


## The state of case `name` with its card on top of the pile: [g, uid]. The
## case keeps only what the card's words read, so it is laid over a whole state.
func _case(name: String) -> Array:
	for row: Dictionary in _data.get("cases", []):
		if str(row["name"]) == name:
			var g: Dictionary = _whole.duplicate(true)
			g.merge((row["state"] as Dictionary).duplicate(true), true)
			var card: Dictionary = (row["card"] as Dictionary).duplicate(true)
			g["cards"] = [card]
			return [g, int(card["uid"])]
	return [{}, -1]


func _card(g: Dictionary) -> Control:
	var c = TurnCard.new()
	add_child_autofree(c)
	c.show_card(g, _data["tables"])
	return c


func _key(c: Control, n: int) -> Button:
	return c.find_child("Key_%d" % n, true, false) as Button


func test_the_bitten_card_says_what_s1_says() -> void:
	assert_false(_data.is_empty(), "card fixture exists and parses")
	if _data.is_empty(): return
	var s: Array = _case("bitten/card-0/6/0/first")
	assert_false((s[0] as Dictionary).is_empty())
	var m: Dictionary = TurnCard.model(s[0], _data["tables"])
	assert_eq(m["title"], "물렸다")
	assert_ne(m["name"], "", "who was bitten is named")
	assert_gte(int(m["bust"]), 0, "a person brings it: an ink bust")
	assert_eq(m["count"], 1)
	var ch: Array = m["choices"]
	assert_eq(ch.size(), 3)
	assert_eq(ch.map(func(x: Dictionary) -> bool: return x["heavy"]), [false, false, true], "only leaving them is the black stone")
	assert_eq(ch[0]["effects"][0], {"icon": "med", "text": "−3", "tone": ""}, "a store is its mark and number")
	assert_eq(ch[1]["effects"], [{"icon": "", "text": "지금 드는 값 없음", "tone": "none"}], "hiding it costs nothing now")
	var tones: Array = ch[2]["effects"].map(func(e: Dictionary) -> String: return e["tone"])
	assert_true(tones.has("red"), "leaving them: a grudge in red")
	assert_eq(ch[2]["effects"][-1], {"icon": "tension", "text": "+2", "tone": ""}, "the top band's tension as its mark, in S1's order")
	assert_true(String(ch[0]["say"]).begins_with("지금 "), "what the captain says, not the label")


## A choice's extra lines (what it costs that is no effect) close its line in
## words, so a way that costs wood and coal never reads 「지금 드는 값 없음」.
func test_extra_lines_close_the_cost_line() -> void:
	var fx: Array = TurnCard.effects({"COMM_NAME": {}}, {"effs": [], "extra": ["목재 −10 · 고철 −6", "달리기 석탄 +0.4/구간"]})
	assert_eq(fx, [{"icon": "", "text": "목재 −10 · 고철 −6", "tone": ""}, {"icon": "", "text": "달리기 석탄 +0.4/구간", "tone": ""}])


func test_a_press_answers_the_card_through_the_train_rule() -> void:
	if _data.is_empty(): return
	var s: Array = _case("bitten/card-0/6/0/first")
	var g: Dictionary = s[0]
	var before: String = JSON.stringify(g)
	var c := _card(g)
	var got: Array = []
	c.chose.connect(func(next: Dictionary) -> void: got.append(next))
	_key(c, 1).pressed.emit()
	assert_eq(got.size(), 1)
	assert_eq((got[0]["cards"] as Array).size(), 0, "the card is answered")
	assert_false(got[0].has("_turn_port_error"), "cut is a drawn way")
	assert_eq(JSON.stringify(g), before, "the state it was given is not changed")


func test_a_heavy_way_takes_two_presses() -> void:
	if _data.is_empty(): return
	var c := _card(_case("bitten/card-0/6/0/first")[0])
	var got: Array = []
	c.chose.connect(func(next: Dictionary) -> void: got.append(next))
	assert_null(c.find_child("Confirm", true, false))
	_key(c, 3).pressed.emit()
	assert_eq(got.size(), 0, "the first press only arms it")
	assert_not_null(c.find_child("Confirm", true, false), "「한 번 더 눌러 확정」")
	_key(c, 3).pressed.emit()
	assert_eq(got.size(), 1, "the second press says it")
	assert_eq((got[0]["cards"] as Array).size(), 0)


func test_another_way_after_arming_answers_at_once() -> void:
	if _data.is_empty(): return
	var c := _card(_case("bitten/card-0/6/0/first")[0])
	var got: Array = []
	c.chose.connect(func(next: Dictionary) -> void: got.append(next))
	_key(c, 3).pressed.emit()
	_key(c, 2).pressed.emit()
	assert_eq(got.size(), 1, "a light way is said with one press")


func test_a_shut_way_shakes_and_says_why() -> void:
	if _data.is_empty(): return
	var name: String = ""
	for row: Dictionary in _data["cases"]:
		if str(row["name"]).begins_with("afford/") and str(row["name"]).ends_with("/ration_line/food"):
			name = str(row["name"])
			break
	assert_ne(name, "")
	var c := _card(_case(name)[0])
	var got: Array = []
	c.chose.connect(func(next: Dictionary) -> void: got.append(next))
	var off := c.find_child("Off", true, false) as Label
	assert_not_null(off)
	assert_eq(off.text.strip_edges(), "식량이 모자라다")
	_key(c, 1).pressed.emit()
	assert_eq(got.size(), 0, "a way that cannot be paid is not said")
	assert_true(UiDeny.is_shaking(c.find_child("Say_1", true, false).get_node("Pad")))


func test_a_report_has_the_papers_mark() -> void:
	if _data.is_empty(): return
	var name: String = ""
	for row: Dictionary in _data["cases"]:
		if str(row["card"]["kind"]) == "need_warn":
			name = str(row["name"])
			break
	var m: Dictionary = TurnCard.model(_case(name)[0], _data["tables"])
	assert_eq(m["name"], "")
	assert_eq(m["bust"], -1, "no one brings it: the papers mark")


func test_the_ration_cut_demand_is_drawn() -> void:
	if _data.is_empty(): return
	var c := _card(_case("ration_cut/card-0/6/first")[0])
	var m: Dictionary = TurnCard.model(c.g, c.t)
	assert_eq(m["choices"].size(), 3)
	assert_eq(String(m["choices"][0]["say"]), "꼬리칸 그릇은 그대로 둔다. 나머지 칸이 줄인다.")
	assert_ne(String(m["choices"][0]["why"]), "", "what keeping the tail's bowl costs in food")
	assert_not_null(c.find_child("Why", true, false))


func test_a_kind_not_drawn_hands_back_the_rule_error() -> void:
	if _data.is_empty(): return
	var g: Dictionary = _case(str(_data["cases"][0]["name"]))[0]
	g["cards"] = [{"uid": 77, "kind": "trip_depart", "comm": "tail"}]
	var c = TurnCard.new()
	var got: Array = []
	c.chose.connect(func(next: Dictionary) -> void: got.append(next))
	add_child_autofree(c)
	c.show_card(g, _data["tables"])
	assert_eq(TurnCard.model(g, _data["tables"]), {})
	await get_tree().process_frame
	assert_eq(got.size(), 1)
	assert_true(String(got[0].get("_turn_port_error", "")).begins_with("F-NOT-PORTED"), "the rule's own error, as it is")


## Each kind's case with the most words: the ways stay on the sheet and the
## scene is all there to read (in print when pen would not fit).
func test_every_kind_longest_card_stays_on_the_sheet() -> void:
	if _data.is_empty(): return
	var longest: Dictionary = {}
	for row: Dictionary in _data["cases"]:
		var v: Dictionary = row["view"]
		var words: int = String(v["body"]).length() + String(v["title"]).length()
		for ch: Dictionary in v["choices"]:
			words += String(ch.get("say", ch["label"])).length() + String(ch.get("why", "")).length() + 12
		var kind: String = str(row["card"]["kind"])
		if not longest.has(kind) or words > int(longest[kind][1]):
			longest[kind] = [str(row["name"]), words]
	for kind: String in longest:
		var c := _card(_case(String(longest[kind][0]))[0])
		await _settled(c)
		var inner: Control = c.sheet.inner
		var need: float = c.body.get_combined_minimum_size().y
		var parts: Array = []
		for p: Control in c.body.get_children():
			parts.append("%s %.0f" % [p.name, p.get_combined_minimum_size().y / UiFonts.K])
		var at: String = "%s (%s)" % [kind, longest[kind][0]]
		assert_lte(need, inner.size.y + 0.5, "%s: %.0f of %.0f | %s" % [at, need, inner.size.y, ", ".join(parts)])
		var said := c.find_child("Said", true, false) as Control
		var scene := c.find_child("Scene", true, false) as Control
		assert_lte(scene.get_combined_minimum_size().y, said.size.y + 0.5, "%s: the scene is all there (%.0f in %.0f)" % [at, scene.get_combined_minimum_size().y, said.size.y])
		assert_lte(c.sheet.size.x / UiFonts.K, TurnCard.WIDE + 0.5, at + ": no wider than WIDE")


## A short card keeps the mockup's sheet and its pen; a long one is cut wider,
## and shows once it has settled.
func test_a_long_card_is_cut_wider_a_short_one_is_not() -> void:
	if _data.is_empty(): return
	var short := _card(_case("bitten/card-0/6/0/first")[0])
	await _settled(short)
	assert_almost_eq(short.sheet.size.x / UiFonts.K, 446.0, 0.5)
	assert_false((short.find_child("Scene", true, false) as Node).has_meta("print"), "the bitten card's scene is in pen")
	var long := _card(_case("ration_cut/card-0/6/first")[0])
	assert_eq(long.sheet.modulate.a, 0.0, "not shown before it settles")
	await _settled(long)
	assert_gt(long.sheet.size.x / UiFonts.K, 446.0)
	assert_eq(long.sheet.modulate.a, 1.0)


## Wait for the card's fit to settle (a few frames).
func _settled(c: Control) -> void:
	for i: int in 40:
		await get_tree().process_frame
		if not c.is_processing():
			return
