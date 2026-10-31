extends GutTest
## A train-turn card's words (turn_card_text.gd) against S1's own viewCard,
## costLines and politicsLines (s1/tools/card_view_fixtures.ts): cards from
## played S1a runs and cards with every past pick, count, shortfall and
## community the words turn on.

const CardText = preload("res://game/train/turn/turn_card_text.gd")
const TV = preload("res://tests/train/train_vectors.gd")
const PATH: String = "res://tests/fixtures/train/card_vectors.json"

var _data: Dictionary = {}
var _bad: Array[String] = []


func before_all() -> void:
	if not FileAccess.file_exists(PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary: _data = parsed


func before_each() -> void:
	_bad = []


func _same(want: Variant, got: Variant, label: String) -> void:
	var d: String = TV.diff(want, got, label)
	if d == "":
		d = TV.diff(got, want, label + " unexpected")
	if d != "" and _bad.size() < 30:
		_bad.append(d)


## S1's effect objects as turn_cards.gd's tuples.
static func _tuple(e: Dictionary) -> Array:
	match str(e["t"]):
		"rel", "fervor", "pop": return [e["t"], e["c"], e["v"]]
		"base": return ["base", e["c"], e["i"], e["v"]]
		"lever": return ["lever", e["c"], e["which"], e["v"]]
		"debt", "grudge": return [e["t"], e["c"]]
	return [e["t"], e["v"]]


func test_fixture_contract() -> void:
	assert_false(_data.is_empty(), "card fixture exists and parses")
	if _data.is_empty(): return
	assert_eq(_data.get("format"), "card-vectors-v1")
	var kinds := {}
	for row: Dictionary in _data["cases"]:
		kinds[str(row["card"]["kind"])] = true
	for kind: String in _data["kinds"]:
		assert_true(kinds.has(kind), kind)


func test_every_card_reads_as_s1() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var count := 0
	for row: Dictionary in _data["cases"]:
		var at: String = str(row["name"])
		var want: Dictionary = row["view"]
		var got: Dictionary = CardText.view(row["state"], t, row["card"])
		if got.is_empty():
			_bad.append(at + ": no view")
			continue
		for key: String in ["title", "body", "required"]:
			_same(want[key], got[key], "%s.%s" % [at, key])
		_same(want.get("focus"), got["focus"], at + ".focus")
		_same(want.get("key"), got.get("key"), at + ".key")
		_same(want.get("late"), got.get("late"), at + ".late")
		_same(want.get("lateLeft"), got.get("lateLeft"), at + ".lateLeft")
		_same(want.get("speaker"), got["speaker"], at + ".speaker")
		var wc: Array = want["choices"]
		var gc: Array = got["choices"]
		if wc.size() != gc.size():
			_bad.append("%s: %d choices, got %d" % [at, wc.size(), gc.size()])
			continue
		for i: int in wc.size():
			var w: Dictionary = wc[i]
			var g: Dictionary = gc[i]
			var label: String = "%s[%d]" % [at, i]
			for field: Array in [["id", ""], ["label", ""], ["say", ""], ["why", ""], ["disabled", ""], ["witness", false], ["special", ""], ["log", ""], ["extra", []]]:
				_same(w.get(field[0], field[1]), g.get(field[0], field[1]), "%s.%s" % [label, field[0]])
			_same((w["effs"] as Array).map(_tuple), g["effs"], label + ".effs")
			_same(row["costs"][i], CardText.cost_lines(t, g), label + " costLines")
			_same(row["pols"][i], CardText.politics_lines(t, g), label + " politicsLines")
		count += 1
	assert_eq(count, (_data["cases"] as Array).size())
	assert_eq(_bad, [] as Array[String], "First differences:\n" + "\n".join(_bad))


## A shortfall shuts a way and says why; a card whose every way is shut opens
## them all again (S1 guardCosts), so no card traps the captain.
func test_a_shortfall_shuts_a_way_but_never_all() -> void:
	if _data.is_empty(): return
	var t: Dictionary = _data["tables"]
	var g: Dictionary = {}
	for row: Dictionary in _data["cases"]:
		if str(row["name"]).begins_with("afford/") and str(row["name"]).ends_with("/ration_line/food"):
			g = (row["state"] as Dictionary).duplicate(true)
			break
	assert_false(g.is_empty())
	var v: Dictionary = CardText.view(g, t, {"uid": 1, "kind": "travel", "text": "ration_line"})
	assert_eq(v["choices"][0]["disabled"], "식량이 모자라다")
	assert_eq(v["choices"][1]["disabled"], "")
	assert_eq(CardText.shortfall({"coal": 5.0}, [["coal", -3]]), "")
	assert_eq(CardText.sign_of(-1.5), "−1.5")
	assert_eq(CardText.cost_lines(t, {"effs": [["coal", -2]], "extra": ["목재 −10 · 고철 −6", "달리기 석탄 +0.4/구간"]}),
		["석탄 −2", "목재 −10 · 고철 −6", "달리기 석탄 +0.4/구간"] as Array[String], "S1 costLines: extra lines after the effects")
	assert_eq(CardText.sign_of(2.0), "+2")


func test_a_kind_it_does_not_draw_has_no_view() -> void:
	if _data.is_empty(): return
	var g: Dictionary = (_data["cases"][0]["state"] as Dictionary).duplicate(true)
	assert_eq(CardText.view(g, _data["tables"], {"uid": 1, "kind": "trip_depart"}), {})
