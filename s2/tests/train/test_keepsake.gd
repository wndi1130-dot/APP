extends GutTest
## The 「외투와 장화」 paper (S1 cards.ts keepsake, 사람의 무게 A1(나)): someone
## who is not a leader dies and their car asks who wears the coat — shared in
## the car (warmth +2 for two stretches), sent to the tail (not when it is the
## tail's), or left with the dead; one who died at a stop left only the spare.

const TurnCards = preload("res://game/train/turn/turn_cards.gd")
const CardText = preload("res://game/train/turn/turn_card_text.gd")
const C = preload("res://game/train/turn/turn_common.gd")
const PATH: String = "res://tests/fixtures/train/turn_vectors.json"

var _data: Dictionary = {}


func before_all() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_data = parsed


func _board() -> Dictionary:
	var g: Dictionary = (_data["runs"][0]["steps"][0]["before"] as Dictionary).duplicate(true)
	g["cards"] = []
	return g


## A guard who is no leader and has something they liked.
func _guard(g: Dictionary) -> Dictionary:
	for p: Dictionary in _data["tables"]["PROFILES"]:
		if p["community"] == "guard" and String(p.get("like", "")) != "" and not C.is_leader(g, _data["tables"], String(p["name"])):
			return p
	return {}


func test_the_coat_and_boots_read_s1_s_words() -> void:
	var g := _board()
	var p := _guard(g)
	assert_false(p.is_empty(), "a guard to mourn")
	C.card(g, {"kind": "keepsake", "comm": "guard", "who": p["name"]})
	var v: Dictionary = CardText.view(g, _data["tables"], g["cards"][0])
	assert_eq(v["title"], "외투와 장화")
	assert_eq(v["focus"], "guard")
	assert_string_starts_with(String(v["body"]), "%s의 외투와 장화가 남았다. 칸 사람들은 '%s'" % [p["name"], p["like"]])
	assert_string_ends_with(String(v["body"]), "좋아하던 사람으로 기억한다. 누가 입을지 칸이 묻는다.")
	var labels: Array = (v["choices"] as Array).map(func(c: Dictionary) -> String: return String(c["label"]))
	assert_eq(labels, ["그 칸에 나눈다", "꼬리칸에 보낸다", "함께 보낸다"])
	assert_eq(v["choices"][2]["say"], "그 옷은 그와 함께 간다. 손대지 마라.")
	g["cards"][0]["text"] = "field"
	var away: Dictionary = CardText.view(g, _data["tables"], g["cards"][0])
	assert_string_starts_with(String(away["body"]), "%s은(는) 정차에서 돌아오지 못했다." % p["name"])
	assert_eq(away["choices"][2]["label"], "그대로 둔다")
	g["cards"][0]["comm"] = "tail"
	assert_eq(TurnCards.view(g, _data["tables"], g["cards"][0])["choices"].size(), 2, "the tail's own coat is not sent to the tail")


func test_shared_coat_warms_the_car_for_two_stretches() -> void:
	var g := _board()
	var p := _guard(g)
	C.card(g, {"kind": "keepsake", "comm": "guard", "who": p["name"]})
	var before: float = float(g["comms"]["guard"]["base"][0])
	var out: Dictionary = TurnCards.choose(g, _data["tables"], int(g["cards"][0]["uid"]), 0)
	assert_false(out.has("_turn_port_error"), str(out.get("_turn_port_error", "")))
	assert_eq(float(out["comms"]["guard"]["base"][0]), before + 2.0)
	assert_eq(out["tempBase"].back(), {"c": "guard", "i": 0, "v": 2, "until": int(g["seg"]) + 2})
	var sent: Dictionary = TurnCards.choose(g, _data["tables"], int(g["cards"][0]["uid"]), 1)
	assert_eq(sent["tempBase"].back()["c"], "tail")
	var kept: Dictionary = TurnCards.choose(g, _data["tables"], int(g["cards"][0]["uid"]), 2)
	assert_eq((kept.get("tempBase", []) as Array).size(), (g.get("tempBase", []) as Array).size(), "left with the dead: nothing to take back")
