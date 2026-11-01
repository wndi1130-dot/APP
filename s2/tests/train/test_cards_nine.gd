extends GutTest
## The nine train-turn papers S2 raised but could not show (결정 480): the
## people's four (S1 cards.ts orphan, elder, birth, naming), the road's three
## (strike_warn, strike, S1 prologue.ts pro_deal), leash and bite_found. Each
## reads S1's title, choices and body, and a choice runs without a port error.

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


func _t() -> Dictionary:
	return _data["tables"]


func _labels(v: Dictionary) -> Array:
	return (v["choices"] as Array).map(func(c: Dictionary) -> String: return String(c["label"]))


func _pick(g: Dictionary, index: int) -> Dictionary:
	var out: Dictionary = TurnCards.choose(g, _t(), int(g["cards"][0]["uid"]), index)
	assert_false(out.has("_turn_port_error"), str(out.get("_turn_port_error", "")))
	return out


## A tail family with two parents in the profiles and a child under 16.
func _family() -> Dictionary:
	for fam: Dictionary in _t()["FAMILIES"]:
		if fam["community"] != "tail" or (fam["parents"] as Array).size() < 2:
			continue
		var a: Dictionary = C.profile(_t(), String(fam["parents"][0]), "id")
		var b: Dictionary = C.profile(_t(), String(fam["parents"][1]), "id")
		var kid: Dictionary = {}
		for id: String in fam["children"]:
			var p: Dictionary = C.profile(_t(), id, "id")
			if not p.is_empty() and int(p["age"]) < 16:
				kid = p
		if not a.is_empty() and not b.is_empty() and not kid.is_empty():
			return {"dead": a, "other": b, "kid": kid}
	return {}


## Someone of the car who is no leader.
func _one(g: Dictionary, comm: String) -> Dictionary:
	for p: Dictionary in _t()["PROFILES"]:
		if p["community"] == comm and not C.is_leader(g, _t(), String(p["name"])):
			return p
	return {}


func test_the_left_child_reads_s1_and_stays_with_the_other_parent() -> void:
	var g := _board()
	var f := _family()
	assert_false(f.is_empty(), "a tail family with a child")
	C.card(g, {"kind": "orphan", "comm": "tail", "who": f["dead"]["name"]})
	var v: Dictionary = CardText.view(g, _t(), g["cards"][0])
	assert_eq(v["title"], "남은 아이")
	assert_eq(_labels(v), ["곁의 부모가 키운다", "앞칸 집에 맡긴다", "의무칸에 둔다"])
	assert_string_starts_with(String(v["body"]), "%s이(가) 아이 " % f["dead"]["name"])
	assert_string_ends_with(String(v["body"]), "곁엔 %s뿐인데, 혼자서는 버거워 보인다. 칸이 열차장의 말을 기다린다." % f["other"]["name"])
	var out := _pick(g, 0)
	assert_eq(out["raised"][f["kid"]["name"]], f["other"]["community"])


func test_the_old_one_who_would_get_off_is_held_for_two_stretches() -> void:
	var g := _board()
	var p: Dictionary = {}
	for row: Dictionary in _t()["PROFILES"]:
		if row["community"] == "tail" and int(row["age"]) >= 65 and not C.is_leader(g, _t(), String(row["name"])):
			p = row
	assert_false(p.is_empty(), "an old one in the tail")
	C.card(g, {"kind": "elder", "comm": "tail", "who": p["name"]})
	var v: Dictionary = CardText.view(g, _t(), g["cards"][0])
	assert_eq(v["title"], "내리겠다는 노인")
	assert_eq(v["speaker"]["role"], "꼬리칸 · %d세" % int(p["age"]))
	assert_eq(v["body"], "%s이(가) 스스로 정했다며 찾아왔다. \"다음 역에서 내리겠다. 내 몫은 아이들에게.\"" % p["name"])
	assert_eq(_labels(v), ["붙잡는다", "보내 준다", "작별을 치른다"])
	var held := _pick(g, 0)
	assert_eq(held["elderHeld"], {"who": p["name"], "comm": "tail", "at": g["seg"], "until": int(g["seg"]) + 2})
	var gone := _pick(g, 1)
	assert_eq(gone["left"].back(), p["name"])


func test_a_birth_brings_the_naming_paper_first() -> void:
	var g := _board()
	var mother: Dictionary = {}
	for row: Dictionary in _t()["PROFILES"]:
		if mother.is_empty() and row["community"] == "tail" and row["gender"] == "female" and int(row["age"]) >= 18 and int(row["age"]) <= 40:
			mother = row
	assert_false(mother.is_empty(), "a mother in the tail")
	C.card(g, {"kind": "birth", "comm": "tail", "who": mother["name"]})
	var v: Dictionary = CardText.view(g, _t(), g["cards"][0])
	assert_eq(v["title"], "아이가 나온다")
	assert_string_starts_with(String(v["body"]), "꼬리칸에서 %s의 아이가 나온다. " % mother["name"])
	assert_eq(_labels(v), ["의무칸으로 데려간다", "그 칸에서 낳는다"])
	var out := _pick(g, 0)
	assert_eq(int(out["comms"]["tail"]["pop"]), int(g["comms"]["tail"]["pop"]) + 1)
	assert_eq(out["cards"][0]["kind"], "naming")
	assert_eq(out["cards"][0]["who"], mother["name"])


func test_the_child_s_name_reads_s1() -> void:
	var g := _board()
	var mother := _one(g, "front")
	C.card(g, {"kind": "naming", "comm": "front", "who": mother["name"]})
	var v: Dictionary = CardText.view(g, _t(), g["cards"][0])
	assert_eq(v["title"], "아이의 이름")
	assert_eq(v["speaker"], {"name": mother["name"], "role": "앞칸", "comm": "front"})
	assert_eq(v["body"], "%s의 아이 이름을 지어야 한다. 칸 사람들이 열차장을 쳐다본다." % mother["name"])
	assert_eq(_labels(v), ["엄마가 짓는다", "열차 이름을 준다", "내 이름을 준다"])
	var train := _pick(g, 1)
	assert_almost_eq(float(train["comms"]["front"]["coh"]), minf(1.0, float(g["comms"]["front"]["coh"]) + 0.02), 0.0001)
	var mine := _pick(g, 2)
	assert_eq(mine["journal"].back()["text"], "아이에게 열차장의 이름을 주었다.")


func test_the_strike_warning_and_the_strike_read_s1() -> void:
	var g := _board()
	C.card(g, {"kind": "strike_warn", "comm": "engine"})
	var v: Dictionary = CardText.view(g, _t(), g["cards"][0])
	assert_eq(v["title"], "파업 경고")
	assert_string_starts_with(String(v["body"]), "\"다음 역까지 답이 없으면 불을 끄겠다.\" 기관실 위험 노출 ")
	assert_eq(_labels(v), ["교대를 늘린다", "기관실 배급 +1", "듣기만 한다"])
	var fed := _pick(g, 1)
	assert_eq(int(fed["comms"]["engine"]["ration"]), int(g["comms"]["engine"]["ration"]) + 1)
	var s := _board()
	C.card(s, {"kind": "strike", "comm": "engine"})
	var w: Dictionary = CardText.view(s, _t(), s["cards"][0])
	assert_eq(w["title"], "파업")
	assert_eq(w["body"], "보일러 불이 낮게 깔렸다. 열차가 선다. 기관실 문 앞에 화부들이 앉아 있다.")
	assert_eq(_labels(w), ["요구를 들어준다", "교대를 늘린다", "수석 기관사를 산다", "버틴다"])
	var met := _pick(s, 0)
	assert_eq(float(met["comms"]["engine"]["rel"]), float(s["comms"]["engine"]["rel"]) + 12.0)
	var bribed := _pick(s, 2)
	assert_eq(float(bribed["lux"]), float(s["lux"]) - 3.0)


func test_the_first_deal_asks_less_after_a_kept_promise() -> void:
	var g := _board()
	g["comms"]["tail"]["heat"] = 1
	g["comms"]["tail"]["ration"] = 1
	g["story"]["flags"]["depot_promise"] = "kept"
	C.card(g, {"kind": "pro_deal", "comm": "tail"})
	var v: Dictionary = CardText.view(g, _t(), g["cards"][0])
	assert_eq(v["title"], "열차 안 첫 거래")
	assert_string_ends_with(String(v["body"]), "말한다. \"약속을 지켰다. 그러니 하나만 청한다. 꼬리칸 난로에 석탄을 한 삽 더.\"")
	assert_eq(_labels(v), ["들어준다", "거절한다"])
	assert_eq(v["choices"][0]["say"], "한 삽 더 넣어라.")
	var kept := _pick(g, 0)
	assert_eq(int(kept["comms"]["tail"]["heat"]), 2)
	assert_eq(int(kept["comms"]["tail"]["ration"]), 1)
	g["story"]["flags"]["depot_promise"] = "broken"
	var owed := _pick(g, 0)
	assert_eq(int(owed["comms"]["tail"]["ration"]), 2)


func test_the_cut_leash_is_only_noted() -> void:
	var g := _board()
	C.card(g, {"kind": "leash", "comm": "guard"})
	var v: Dictionary = CardText.view(g, _t(), g["cards"][0])
	assert_eq(v["title"], "목줄이 끊겼다")
	assert_eq(v["body"], "%s이(가) 제 비밀을 털어놓고 열차장이 그걸로 협박했다고 말했다." % g["comms"]["guard"]["leader"]["name"])
	assert_eq(_labels(v), ["알았다"])
	var out := _pick(g, 0)
	assert_eq((out["journal"] as Array).size(), (g["journal"] as Array).size(), "S1 writes no line for leash")


func test_a_hidden_bite_that_shows_is_laid_apart_or_shot() -> void:
	var g := _board()
	var p := _one(g, "guard")
	g["hiddenBites"] = [{"who": p["name"], "comm": "guard", "at": g["seg"], "due": int(g["seg"]) + 2, "found": true}]
	C.card(g, {"kind": "bite_found", "comm": "guard", "who": p["name"], "text": "열이 오르는 걸 의무장이 알아챘다."})
	var v: Dictionary = CardText.view(g, _t(), g["cards"][0])
	assert_eq(v["title"], "숨긴 물림이 드러났다")
	assert_eq(v["body"], "열이 오르는 걸 의무장이 알아챘다. %s의 붕대 아래가 검게 부었다. 자르기엔 늦었다. 열차장이 숨겨 줬다는 말이 벌써 돈다." % p["name"])
	assert_eq(_labels(v), ["따로 눕힌다", "쏜다"])
	var apart := _pick(g, 0)
	assert_true(bool(apart["hiddenBites"][0].get("isolated", false)))
	var shot := _pick(g, 1)
	assert_eq((shot["hiddenBites"] as Array).size(), 0)
	assert_true((shot["deaths"] as Array).has(p["name"]))


func test_a_corpse_bite_is_cut_only_while_the_window_is_open() -> void:
	var g := _board()
	var p := _one(g, "guard")
	g["hiddenBites"] = [{"who": p["name"], "comm": "guard", "at": int(g["seg"]) - 1, "due": int(g["seg"]) + 1}]
	C.card(g, {"kind": "bite_found", "comm": "guard", "who": p["name"], "text": "corpse"})
	var v: Dictionary = CardText.view(g, _t(), g["cards"][0])
	assert_eq(v["title"], "시신에게 물렸다")
	assert_eq(v["body"], "남겨 두었던 시신에게 %s이(가) 물렸다." % p["name"])
	assert_eq(v["choices"][0]["disabled"], "감염 창이 닫혔다")
	var shut: Dictionary = TurnCards.choose(g, _t(), int(g["cards"][0]["uid"]), 0)
	assert_eq((shut["cards"] as Array).size(), 1, "the shut cut is not taken")
	g["hiddenBites"][0]["at"] = g["seg"]
	var cut := _pick(g, 0)
	assert_eq((cut["hiddenBites"] as Array).size(), 0)


## A way the rule shuts says why on the paper, as S1's card does (card.ts):
## the guard who will not go keeps 「경비대가 따르지 않는다」 on the last
## chance and on a protest, not an empty reason over a dead key.
func test_a_way_the_rule_shuts_keeps_why() -> void:
	var g := _board()
	g["comms"]["guard"]["rel"] = -50
	for kind: String in ["tension_crisis", "protest"]:
		g["cards"] = []
		C.card(g, {"kind": kind, "comm": "tail"})
		var v: Dictionary = CardText.view(g, _data["tables"], g["cards"][0])
		var shut: Array = (v["choices"] as Array).filter(func(c: Dictionary) -> bool: return c["disabled"] != "")
		assert_eq(shut.size(), 1, kind)
		assert_eq(shut[0]["disabled"], "경비대가 따르지 않는다", kind)


## The last chance, a protest and a riot read S1's words: the tail's leader
## brings them, and a riot that has caught fire says so.
func test_the_ladder_papers_read_s1_s_words() -> void:
	var g := _board()
	C.card(g, {"kind": "tension_crisis", "comm": "tail"})
	var v: Dictionary = CardText.view(g, _data["tables"], g["cards"][0])
	assert_string_starts_with(String(v["body"]), "칸마다 사람들이 모였다.")
	assert_not_null(v["speaker"], "the tail's leader brings it")
	assert_eq(v["choices"][2]["say"], "(열차장은 아무 말도 하지 않는다.)")
	g["cards"] = []
	C.card(g, {"kind": "protest", "comm": "tail", "text": "riot"})
	g["riot"] = {"fire": ["tail1"]}
	var riot: Dictionary = CardText.view(g, _data["tables"], g["cards"][0])
	assert_eq(riot["title"], "난장판")
	assert_eq(riot["body"], "싸움이 번졌다. 물건이 날고 어른들이 쓰러진다. 불이 붙었다. 사람들은 걸어서 옆 칸으로 옮겨 간다.")
