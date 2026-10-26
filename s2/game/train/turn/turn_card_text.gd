extends RefCounted
## The words of a train-turn card (S1 cards.ts viewCard): its title, who brings
## it, what it says, what the captain says for each choice, why a choice cannot
## be taken, and the lines a choice's cost and politics read as (costLines,
## politicsLines). turn_cards.gd view keeps the choices and their effects; view
## here dresses that in S1's words for the kinds it draws, so the card's paper
## (ui/turn_card.gd) only reads. Checked against card-vectors-v1
## (s1/tools/card_view_fixtures.ts).

const St = preload("res://game/train/train_state.gd")
const TurnCards = preload("res://game/train/turn/turn_cards.gd")
const TrainClimate = preload("res://game/train/train_climate.gd")

const RES_NAME: Dictionary = {"coal": "석탄", "food": "식량", "med": "의약품", "lux": "사치품", "trust": "신임",
	"tension": "긴장", "fear": "공포", "injured": "부상자"}
const BASE_NAME: Array[String] = ["온기", "배급", "과밀", "노출"]
## The kinds whose S1 view runs withAfford itself (the rest only meet guardCosts).
const AFFORD_KINDS: Array[String] = ["travel", "demand", "ration_cut", "favor", "rescue", "bitten", "rep_sick", "promise_ledger"]


## The card as S1 shows it: turn_cards.gd view's choices with S1's words, and
## {title, speaker ({name, role, comm?} or null), body, required, focus (or null),
## key?}. {} for a kind turn_cards.gd does not draw.
static func view(g: Dictionary, t: Dictionary, card: Dictionary) -> Dictionary:
	var v: Dictionary = TurnCards.view(g, t, card)
	if v.is_empty():
		return {}
	var out: Dictionary = v.duplicate(true)
	out["speaker"] = null
	out["body"] = ""
	out["required"] = true
	out["focus"] = null
	var says: Array = []
	var why: Array = []
	var kind: String = str(card["kind"])
	var c: String = str(card.get("comm", "tail"))
	match kind:
		"travel": _travel(g, t, str(card.get("text", "")), out, says)
		"demand": _demand(g, t, c, out, says)
		"ration_cut":
			var past: Variant = _memo(g, "ration_cut")
			var r: int = _round(St.situation(g, t, "tail")[1])
			var k: Dictionary = t["RATION_CUT"]
			out["speaker"] = _leader(g, t, "tail")
			out["focus"] = "tail"
			out["body"] = ("감축법이 다시 섰다. 꼬리칸 대표가 지난번 답을 기억하고 왔다. 꼬리칸 배급 %d." % r) if past != null \
				else ("비상식량감축법이 섰다. 꼬리칸 대표가 빈 그릇을 들고 왔다. 제일 적게 받는 칸에서 또 깎으면 그건 고르게가 아니라고 한다. 꼬리칸 배급 %d." % r)
			says = ["꼬리칸 그릇은 그대로 둔다. 나머지 칸이 줄인다.", "앞칸이 한 단 더 줄인다. 꼬리칸 몫은 거기서 나온다.", "예외는 없다. 모두 같이 줄인다."]
			why = ["아끼는 식량이 구간마다 %s로 준다." % _num(-float(k["spareFood"])),
				"앞칸 배급 처지는 모두 −%s까지 내려간다. 아끼는 식량은 그대로다." % _num(2.0 * float(k["sit"])), ""]
		"favor":
			var past: Variant = _memo(g, "favor:" + c)
			out["speaker"] = _leader(g, t, c)
			out["focus"] = c
			out["body"] = String((FAVORS_AGAIN if past != null else FAVORS)[c])
			says = ["이번까지다. 다음은 없다." if past != null else "들어주지. 대신 이 일은 기억해 둬라.",
				"한 번 들어줬다고 버릇이 되면 안 된다." if past != null else "사사로운 부탁은 받지 않는다."]
		"rescue": _rescue(g, t, card, out, says)
		"bitten":
			var past: Variant = _memo(g, "bitten")
			var parts: Array = [["팔", "팔을"], ["다리", "다리를"], ["손", "손을"]][int(card["uid"]) % 3]
			var echo: String = " 지난번 일 때문에 다들 상처부터 본다." if _was(past, "hide") else (" 지난번 역에 두고 온 사람을 다들 기억한다." if _was(past, "leave") else "")
			out["speaker"] = {"name": str(card.get("who", "수색대원")), "role": String(t["COMM_NAME"][c])}
			out["focus"] = c
			out["body"] = "%s이(가) %s 물렸다. 수색대가 열차장의 말을 기다린다. 감염 창이 닫히기 전에 잘라야 한다.%s" % [str(card.get("who", "대원")), parts[1], echo]
			says = ["지금 %s 잘라라! 망설이면 늦는다." % parts[1],
				"지난번엔 운이 좋았다. 이번에도 감아서 태워라." if _was(past, "hide") else "아무도 못 본 거다. %s에 붕대를 감고 태워라." % parts[0],
				"물린 사람은 못 태운다. 미안하다고 전해라."]
		"rep_sick":
			var s: Dictionary = g["comms"][c]
			var sick: bool = s.get("sick") is Dictionary
			var rep: String = String(s["sick"]["rep"]["name"]) if sick else String(s["leader"]["name"])
			out["speaker"] = _leader(g, t, c)
			out["focus"] = c
			out["body"] = ("\"%s이(가) 사흘째 일어나지 못한다. 회기엔 내가 나간다.\" 측근 %s이(가) 말한다." % [rep, s["leader"]["name"]]) if sick \
				else "%s이(가) 앓다가 일어났다. 칸이 한숨 돌렸다." % rep
			says = ["의무진을 보내라. 대표는 회기에 나와야 한다.", "대신 나온다는 자를 데려와라. 얼굴을 봐야겠다.", "대표가 누구든 표는 표다."] if sick else [""]
		"promise_ledger":
			# The result arc (council_log.gd): the car's leader brings the two broken
			# promises; one more and the car takes no promise of the captain's.
			var who: Dictionary = _leader(g, t, c)
			out["speaker"] = who
			out["focus"] = c
			out["body"] = "%s이(가) 어긴 약속 둘을 적은 종이를 내밀었다. 한 번 더 어기면 %s은(는) 열차장의 약속을 받지 않는다." % [who["name"], t["COMM_NAME"][c]]
			says = ["내 잘못이다. 지금 갚겠다.", "지난 일이다. 앞을 보자."]
		"need_warn":
			var def: Dictionary = t["NEEDS"][card["text"]]
			var warn: Array = def["warn"]
			out["body"] = "%s %d구간 안에 정하지 않으면 손해가 난다. 약속하면 한 구간을 더 벌지만, 어기면 신임을 크게 잃는다." % [warn[int(card.get("n", 0)) % warn.size()], int(t["NEED_GRACE"])]
			says = ["다음 회기 안에 정하겠다. 내 이름을 걸고 약속한다.", "서두른다고 좋은 법이 나오지 않는다. 지켜봐라."]
		"info":
			out["title"] = str(card.get("who", "알림"))
			out["body"] = str(card.get("text", ""))
	var choices: Array = out["choices"]
	for i: int in choices.size():
		var ch: Dictionary = choices[i]
		ch["say"] = String(says[i]) if i < says.size() else ""
		ch["why"] = String(why[i]) if i < why.size() else ""
		ch["disabled"] = ""
	# withAfford in the kinds' own views, then guardCosts over every view: when
	# every way is shut the card would trap the captain, so then none is.
	if AFFORD_KINDS.has(kind):
		_afford(g, choices)
	var after: Array = choices.duplicate(true)
	_afford(g, after)
	if after.any(func(ch: Dictionary) -> bool: return ch["disabled"] == ""):
		out["choices"] = after
	return out


## S1 affordable: why a choice's cost cannot be paid now ("" when it can).
static func shortfall(g: Dictionary, effs: Array) -> String:
	for e: Array in effs:
		if e[0] in ["coal", "food", "med", "lux"] and float(e[1]) < 0 and float(g[e[0]]) < -float(e[1]):
			return {"coal": "석탄이 모자라다", "food": "식량이 모자라다", "med": "의약품이 모자라다", "lux": "사치품이 모자라다"}[e[0]]
		if e[0] == "lever" and float(e[3]) > 0 and float(g["comms"][e[1]][e[2]]) >= 4:
			return "이미 최대다"
	return ""


static func _afford(g: Dictionary, choices: Array) -> void:
	for ch: Dictionary in choices:
		if ch["disabled"] == "":
			ch["disabled"] = shortfall(g, ch["effs"])


## costLines: a choice's stores, standing and levers as 「석탄 −3」 lines, then
## its extra lines as they are (what a domestic card costs that is no effect:
## the wood and scrap, the coal a stretch). No S1a card has any yet.
static func cost_lines(t: Dictionary, choice: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var names: Dictionary = t["COMM_NAME"]
	for e: Array in choice["effs"]:
		match str(e[0]):
			"coal", "food", "med", "lux", "injured": out.append("%s %s" % [RES_NAME[e[0]], sign_of(float(e[1]))])
			"base": out.append("%s %s %s" % [names[e[1]], BASE_NAME[int(e[2])], sign_of(float(e[3]))])
			"lever": out.append("%s %s %s" % [names[e[1]], "난방" if e[2] == "heat" else "배급", sign_of(float(e[3]))])
			"pop": out.append("%s %s명" % [names[e[1]], sign_of(float(e[2]))])
	for line: Variant in choice.get("extra", []):
		out.append(String(line))
	return out


## politicsLines: {text, tone} for relations (size in a word), trust, tension,
## fear, fervour and a debt.
static func politics_lines(t: Dictionary, choice: Dictionary) -> Array:
	var out: Array = []
	var names: Dictionary = t["COMM_NAME"]
	for e: Array in choice["effs"]:
		match str(e[0]):
			"rel":
				var v: float = float(e[2])
				var size: String = "크게" if absf(v) >= 8.0 else "약간"
				out.append({"text": "%s 지지 %s ↑" % [names[e[1]], size], "tone": "blue"} if v > 0 else {"text": "%s 불만 %s ↑" % [names[e[1]], size], "tone": "red"})
			"trust": out.append({"text": "신임 %s" % sign_of(float(e[1])), "tone": "blue" if float(e[1]) > 0 else "red"})
			"tension": out.append({"text": "긴장 %s" % sign_of(float(e[1])), "tone": "red" if float(e[1]) > 0 else "blue"})
			"fear": out.append({"text": "공포가 돈다", "tone": "gray"})
			"fervor":
				if float(e[2]) > 0: out.append({"text": "%s 열기 ↑" % names[e[1]], "tone": "red"})
			"debt": out.append({"text": "%s 대표에게 빚 받음" % names[e[1]], "tone": "blue"})
	return out


## S1 sign: +v, or a true minus for anything else (0 reads −0, as in S1).
static func sign_of(v: float) -> String:
	return "+" + _num(v) if v > 0 else "−" + _num(absf(v))


## A number as JavaScript writes it: no ".0" on a whole one.
static func _num(v: float) -> String:
	return str(int(v)) if v == floorf(v) and absf(v) < 1e15 else str(v)


## JavaScript Math.round.
static func _round(v: float) -> int:
	return int(floorf(v + 0.5))


static func _memo(g: Dictionary, key: String) -> Variant:
	var log: Variant = g.get("eventLog")
	return (log as Dictionary).get(key) if log is Dictionary else null


static func _was(past: Variant, id: String) -> bool:
	return past is Dictionary and past.get("pick") == id


## S1 again: the first line, or the line for what was picked last time.
static func _again(past: Variant, first: String, by_pick: Dictionary, fallback: String) -> String:
	if past == null:
		return first
	return String(by_pick.get(past.get("pick"), fallback))


static func _leader(g: Dictionary, t: Dictionary, c: String) -> Dictionary:
	return {"name": String(g["comms"][c]["leader"]["name"]), "role": String(t["REP_ROLE"][c]), "comm": c}


## S1 josa: 은/는-like pairs by the word's last sound (here only Hangul names).
static func _josa(word: String, pair: String) -> String:
	var two: PackedStringArray = pair.split("/")
	var code: int = word.unicode_at(word.length() - 1)
	var none: bool = code < 0xac00 or code > 0xd7a3 or (code - 0xac00) % 28 == 0
	return two[1] if none else two[0]


## S1 iga: 이 after a final consonant, 가 after a vowel, 이(가) for anything not Hangul.
static func _iga(word: String) -> String:
	var code: int = word.unicode_at(word.length() - 1)
	if code < 0xac00 or code > 0xd7a3:
		return "이(가)"
	return "이" if (code - 0xac00) % 28 != 0 else "가"


static func _travel(g: Dictionary, t: Dictionary, id: String, out: Dictionary, says: Array) -> void:
	var past: Variant = _memo(g, id)
	var again: bool = past != null
	match id:
		"tail_cold":
			out["speaker"] = _leader(g, t, "tail")
			out["focus"] = "tail"
			var kids: int = maxi(2, _round(float(g["comms"]["tail"]["pop"]) * 0.18))
			out["body"] = _again(past, "꼬리칸 난로가 이틀째 꺼져 있다. 아이 %d명의 손끝이 하얗다. 앞칸엔 난로가 두 개다." % kids, {
				"fuel_front": "꼬리칸 난로가 또 꺼졌다. 지난번 덜어 온 연료는 사흘을 못 갔다. 앞칸은 이제 연료 상자에 자물쇠를 걸었다.",
				"blankets": "꼬리칸 난로가 또 꺼졌다. 나눠 준 담요는 젖은 채 얼었다. 밤마다 기침 소리가 칸을 넘어온다.",
				"endure": "꼬리칸 난로가 또 꺼졌다. 아이들이 \"참아라\" 하는 열차장 말투를 흉내 내며 논다. 어른들은 웃지 않는다.",
			}, "꼬리칸 난로가 또 꺼졌다. 이번엔 노인 하나가 아침에 일어나지 않았다.")
			says.append_array([
				"자물쇠를 따라. 연료는 열차 전체의 것이다!" if _was(past, "fuel_front") else "난로 두 개는 사치다. 하나를 꼬리칸으로 옮겨라!",
				"창고 담요를 전부 풀어라. 젖은 건 보일러 옆에서 말려라." if again else "창고 담요를 풀어라. 아이들부터 덮어 줘라.",
				"아직 아무도 얼어 죽지 않았다. 버텨라." if again else "모두가 춥다. 꼬리칸만 추운 게 아니다."])
		"crowd_fight":
			out["speaker"] = _leader(g, t, "guard")
			out["focus"] = "tail"
			out["body"] = _again(past, "꼬리칸에서 누울 자리를 두고 주먹이 오갔다. 한 사람이 머리를 다쳤다.", {
				"guard_break": "또 주먹이 오갔다. 지난번 끌려갔던 사내가 이번엔 먼저 휘둘렀다. 경비대를 보는 눈이 곱지 않다.",
				"widen": "넓혀 준 자리에도 사람이 다시 찼다. 이번엔 깨진 병이 나왔다.",
				"let_be": "또 싸움이 났다. 지난번 다친 사람은 아직 못 일어난다. 이번엔 편이 갈렸다.",
			}, "자리 싸움이 또 났다. 누가 먼저였는지 아무도 말하지 않는다.")
			says.append_array(["경비대, 떼어 놓아라! 또 주먹을 쓰면 묶어 둬라.", "앞칸 짐을 치워라. 꼬리칸에도 누울 자리는 있어야 한다.",
				"저들끼리 끝내게 둬라. 열차장은 심판이 아니다." if again else "자리는 저들끼리 정하게 둬라."])
		"front_curtain":
			out["speaker"] = _leader(g, t, "tail")
			out["focus"] = "front"
			out["body"] = _again(past, "앞칸 창에 커튼이 걸렸다. 식사 시간마다 닫힌다. 꼬리칸이 그 앞에 줄을 섰다.", {
				"curtain_open": "커튼은 걷혔다. 대신 앞칸이 식사를 밤으로 옮겼다. 꼬리칸이 자는 사이에 먹는다.",
				"side_front": "커튼 앞 줄이 길어졌다. 누군가 커튼에 숯으로 \"배부른 칸\"이라고 썼다.",
				"call_reps": "두 대표가 한 식탁에 앉았던 일은 사흘을 못 갔다. 커튼이 다시 걸렸다.",
			}, "커튼이 또 걸렸다.")
			says.append_array([
				"밤에 먹든 낮에 먹든 같은 열차다. 문을 열어 둬라." if _was(past, "curtain_open") else "커튼을 걷어라. 이 열차에 숨어서 먹는 칸은 없다.",
				"낙서한 자를 찾아라. 앞칸 식탁은 앞칸 일이다." if _was(past, "side_front") else "앞칸 식탁은 앞칸 일이다. 줄을 풀어라.",
				"또 커튼이냐. 두 대표를 내 식탁으로 다시 끌고 와라!" if again else "두 대표를 내 식탁에 앉혀라. 커튼 얘기는 밥 먹으며 끝낸다."])
		"water_tower":
			var sc: String = str(g["lastCrew"]) if g.get("lastCrew") != null else "tail"
			var name: String = String(t["COMM_NAME"][sc])
			var coal: int = _round(float(g["coal"]))
			out["speaker"] = _leader(g, t, "engine")
			out["focus"] = "engine"
			out["body"] = _again(past, "급수탑 관이 얼었다. 보일러 물이 반밖에 없다. 석탄은 %d 남았다." % coal, {
				"burn_melt": "급수탑이 또 얼었다. 지난번 녹이느라 태운 석탄 얘기를 화부들이 아직 한다. 석탄은 %d 남았다." % coal,
				"snow_melt": "급수탑이 또 얼었다. 지난번 양동이 일로 손이 다 튼 사람들이 이번에도 자기들이냐고 묻는다.",
				"hold_on": "보일러 물이 바닥 근처다. 지난번처럼 버티면 관이 탈 수 있다고 기관사가 말한다.",
			}, "급수탑이 또 얼었다.")
			says.append_array(["물 없는 보일러는 고철이다. 석탄을 태워서라도 녹여라!",
				("%s%s 한 번 더 한다. 장갑은 앞칸에서 걷어 줘라." % [name, _iga(name)]) if _was(past, "snow_melt") else ("%s%s 양동이를 들어라. 눈을 퍼다 녹인다." % [name, _josa(name, "은/는")]),
				"관은 안 탄다. 내가 보증한다. 간다!" if _was(past, "hold_on") else "물을 아껴라. 다음 급수탑까지 간다."])
		"snow_drift":
			out["speaker"] = _leader(g, t, "engine")
			out["focus"] = "engine"
			out["body"] = _again(past, "선로가 눈더미에 묻혔다. 삽이 열두 자루 있다.", {
				"dig_all": "또 눈더미다. 지난번 함께 판 일을 사람들이 아직 말한다. 앞칸 몇은 벌써 삽을 들었다.",
				"dig_tail": "또 눈더미다. 꼬리칸 사람들이 삽을 내려놓고 앉아 있다. \"이번엔 앞칸 차례다.\"",
				"plow": "또 눈더미다. 지난번 밀어붙인 뒤로 앞바퀴에서 쇳소리가 난다.",
			}, "선로가 또 눈에 묻혔다.")
			says.append_array(["모든 칸이 삽을 든다. 앞칸도 예외는 없다!",
				"앉아 있으면 열차도 선다. 꼬리칸, 일어나라." if _was(past, "dig_tail") else "꼬리칸, 삽을 들어라. 손이 제일 많은 칸이다.",
				"화부들, 불을 올려라. 밀고 나간다!"])
		"abandoned_tender":
			out["focus"] = "engine"
			out["body"] = "측선에 또 버려진 탄수차가 있다. 이번엔 문짝마다 손톱자국이 나 있다." if again else "측선에 버려진 탄수차가 서 있다. 안에 석탄이 보인다. 주위가 너무 조용하다."
			says.append_array(["자국은 오래된 거다. 빨리 옮기고 빠진다!" if again else "조용하면 좋은 거다. 다 옮겨라, 서둘러!", "너무 조용하다. 손대지 말고 지나간다."])
		"sick_child":
			out["speaker"] = _leader(g, t, "medtech")
			out["focus"] = "medtech"
			out["body"] = _again(past, "꼬리칸 아이 셋이 열이 난다. 해열제는 의무칸 상자에 있다.", {
				"med_use": "이번엔 아이 다섯이 열이 난다. 지난번 약을 받은 집 얘기가 칸에 다 퍼졌다. 의약품은 %d 남았다." % _round(float(g["med"])),
				"med_save": "지난번 약을 못 받은 아이가 아직 열이 안 내렸다. 엄마가 의무칸 문 앞을 떠나지 않는다.",
			}, "아이들이 또 열이 난다.")
			says.append_array(["의약품은 약자의 것이다. 아이들에게 먼저 써라!",
				"약은 살 사람에게 쓴다. 그 엄마를 문 앞에서 데려가라." if _was(past, "med_save") else "애들 열은 금방 내린다. 엄살 부리지 말라고 전해라!"])
		"ration_line":
			out["speaker"] = _leader(g, t, "tail")
			out["focus"] = "tail"
			out["body"] = _again(past, "배급 줄 끝에서 빵이 떨어졌다. 뒤에 선 사람들이 소리친다.", {
				"reshare": "배급 줄 끝에서 또 빵이 떨어졌다. 사람들이 \"지난번처럼!\"을 외친다. 식량은 %d 남았다." % _round(float(g["food"])),
				"guard_line": "경비대가 섰던 날 이후로 배급 줄이 조용하다. 너무 조용하다. 오늘도 빵이 모자란다.",
			}, "배급 줄 끝에서 또 빵이 떨어졌다.")
			says.append_array(["솥을 다시 열어라. 줄 끝까지 한 그릇씩 간다.",
				"조용하면 됐다. 경비대는 그대로 선다." if _was(past, "guard_line") else "경비대를 줄 옆에 세워라. 질서가 먼저다."])
		"guard_frost":
			# Where ice does not stand on a climate board (late autumn) the post is
			# soaked by cold rain, not frostbitten; the values are the same (S1
			# seasonHolds; climate off: the frost always holds).
			var frost: bool = TrainClimate.holds(g, t, "frost")
			out["title"] = "동상" if frost else "젖은 보초"
			out["speaker"] = _leader(g, t, "guard")
			out["focus"] = "guard"
			if frost:
				out["body"] = _again(past, "지붕 경계를 서던 대원 둘이 동상을 입었다. 교대를 줄여 달라고 한다.", {
					"hold_post": "지난번 지붕에 섰던 대원 하나가 발가락 둘을 잃었다. 경비대가 지붕 교대를 거부하겠다고 한다.",
					"watch_less": "경계를 줄인 밤, 지붕 위로 무언가 지나갔다는 말이 돈다. 대원들이 다시 동상을 입었다.",
					"guard_heat": "경비칸이 따뜻해지자 다른 칸이 수군댄다. 그런데 지붕 위 바람은 여전히 살을 엔다.",
				}, "지붕 경계 대원들이 또 동상을 입었다.")
			else:
				out["body"] = _again(past, "지붕 경계를 서던 대원 둘이 찬비에 흠뻑 젖어 이가 맞부딪힌다. 교대를 줄여 달라고 한다.", {
					"hold_post": "지난번 지붕에 섰던 대원 하나가 열이 올라 일어나지 못한다. 경비대가 지붕 교대를 거부하겠다고 한다.",
					"watch_less": "경계를 줄인 밤, 지붕 위로 무언가 지나갔다는 말이 돈다. 대원들이 다시 젖은 채 떨었다.",
					"guard_heat": "경비칸이 따뜻해지자 다른 칸이 수군댄다. 그런데 지붕 위 찬비는 그대로다.",
				}, "지붕 경계 대원들이 또 젖은 채 떨었다.")
			says.append_array(["경비칸 난로에 석탄을 더 넣어라. 지키는 사람이 얼면 끝이다.", "얼어 죽은 보초는 아무것도 못 본다. 지붕에서 내려와라.",
				"거부는 없다. 지붕이 비면 다 같이 죽는다." if _was(past, "hold_post") else ("경계는 줄이지 않는다. 장갑을 두 겹 껴라." if frost else "경계는 줄이지 않는다. 젖은 옷은 교대 때마다 갈아입어라.")])


static func _demand(g: Dictionary, t: Dictionary, c: String, out: Dictionary, says: Array) -> void:
	var sit: Array = St.situation(g, t, c)
	var name: String = String(t["COMM_NAME"][c])
	if c == "engine" and float(sit[3]) > 50:
		var past: Variant = _memo(g, "demand:engine_shift")
		var ex: int = _round(float(sit[3]))
		out["speaker"] = _leader(g, t, "engine")
		out["focus"] = "engine"
		out["body"] = _again(past, "화부들이 교대 없이 삽질을 한 지 오래다. 위험 노출 %d. 교대를 늘려 달라고 한다." % ex, {
			"refuse": "화부들이 다시 왔다. 이번엔 수석 기관사도 함께다. 위험 노출 %d." % ex,
			"shift_apprentice": "붙여 준 견습생 하나가 화상을 입었다. 화부들이 교대를 다시 요구한다. 위험 노출 %d." % ex,
			"shift_more": "늘린 교대로도 모자란다. 석탄이 줄수록 삽질은 늘었다. 위험 노출 %d." % ex,
		}, "화부들이 또 교대를 요구한다. 위험 노출 %d." % ex)
		says.append_array(["교대를 늘려라. 석탄보다 화부가 먼저 쓰러지면 끝이다.",
			"견습생을 더 붙여라. 화상은 배우는 값이다." if _was(past, "shift_apprentice") else "꼬리칸에서 젊은 손을 데려가라. 삽질은 배우면 된다.",
			"수석 기관사가 와도 답은 같다. 불 앞으로 돌아가라." if _was(past, "refuse") else "보일러는 쉬지 않는다. 화부도 마찬가지다."])
		return
	var s: Dictionary = g["comms"][c]
	var heat: bool = String(out["title"]) == "난방 요구"
	var past: Variant = _memo(g, "demand:" + c)
	var first: String = ("%s 온기 %d. 밤마다 사람들이 서로 붙어 잔다. 난방을 올려 달라고 한다." % [name, _round(float(sit[0]))]) if heat \
		else ("%s 배급 %d. 그릇이 반만 찬다. 배급을 올려 달라고 한다." % [name, _round(float(sit[1]))])
	var refused: String = ("%s 대표가 또 왔다. 이번엔 뒤에 칸 사람 몇이 서 있다. 온기 %d." % [name, _round(float(sit[0]))]) if heat \
		else ("%s 대표가 빈 그릇을 들고 왔다. 지난번 거절한 날부터 그릇을 씻지 않았다고 한다. 배급 %d." % [name, _round(float(sit[1]))])
	var rel: float = float(s["rel"])
	var tone: String = "말투는 부탁에 가깝다." if rel >= 15 else ("답은 다음 회기 전까지 달라고 못 박는다." if rel <= -15 else "")
	out["speaker"] = _leader(g, t, c)
	out["focus"] = c
	out["body"] = ("%s %s" % [refused if _was(past, "refuse") else first, tone]).strip_edges()
	says.append_array([
		("%s 난로를 올려라. 밤에 얼어 죽는 사람은 없어야 한다." % name) if heat else ("%s 그릇을 채워라. 빈 그릇으로는 일 못 한다." % name),
		"사람을 몰고 와도 석탄은 늘지 않는다." if _was(past, "refuse") else ("다들 붙어 자기는 마찬가지다. 지금은 안 된다." if heat else "모두 반 그릇이다. 더 나올 데가 없다.")])


static func _rescue(g: Dictionary, t: Dictionary, card: Dictionary, out: Dictionary, says: Array) -> void:
	var ban: bool = (g.get("passed", {}) as Dictionary).has("no_outsiders")
	var past: Variant = _memo(g, "rescue")
	var n: int = int(past.get("n", 0)) if past is Dictionary else 0
	var who: String = [
		"역사 안에 다친 사람 둘이 있다. 데려가 달라고 한다.",
		"역사 구석에 노인과 소년이 있다. 소년은 노인을 업고 여기까지 왔다고 한다.",
		"플랫폼 끝에 여자 하나가 앉아 있다. 다리를 다쳤고, 아이를 안고 있다.",
		"대합실 의자 밑에서 남자 하나가 기어 나왔다. 기관사였다고 한다. 손이 떨린다.",
	][n % 4]
	var echo: String = " 꼬리칸은 이미 꽉 찼다."
	if _was(past, "leave") or _was(past, "leave_law"):
		echo = " 수색대가 이번엔 먼저 묻는다. 또 두고 가느냐고."
	elif _was(past, "take_in"):
		echo = " 지난번 데려온 사람들로 꼬리칸 과밀이 %d이다." % _round(float(St.situation(g, t, "tail")[2]))
	out["speaker"] = {"name": str(card.get("who", "수색대")), "role": "수색대"}
	out["body"] = ("%s 외부인 받지 않기 법이 있다." % who) if ban else who + echo
	if ban:
		says.append("법은 법이다. 두고 와라.")
	else:
		says.append_array(["자리는 만들면 된다. 데려와라!", "가진 식량만 받아라. 사람은 태울 수 없다.",
			"그래, 또 두고 간다. 우리 먼저 살아야 한다." if _was(past, "leave") else "꼬리칸은 꽉 찼다. 문을 닫아라."])


## S1 FAVORS: the first private favour each community's representative asks.
const FAVORS: Dictionary = {
	"tail": "\"아들이 기침을 한다. 의무칸 침상 하나만.\" 대표가 처음으로 사적인 부탁을 한다.",
	"medtech": "\"동생이 앞칸 빈자리에 갈 수 있게 해 달라.\" 아무도 모르게.",
	"guard": "\"부관 자리 얘기, 다음에 내 이름도 올려 달라.\" 경비대장이 낮게 말한다.",
	"front": "\"술 두 병만. 손님을 맞아야 한다.\" 앞칸 대표가 웃는다.",
	"engine": "\"견습생 하나를 꼬리칸에서 데려가고 싶다. 내가 고른 아이로.\"",
}
## S1 FAVORS_AGAIN: the second time another favour comes.
const FAVORS_AGAIN: Dictionary = {
	"tail": "\"아들이 나았다. 이번엔 조카다.\" 대표가 눈을 피하며 말한다. 의무칸 침상이 또 필요하다.",
	"medtech": "\"동생이 앞칸에서 쫓겨날 것 같다. 한마디만 해 달라.\" 의사가 처음으로 목소리를 낮춘다.",
	"guard": "\"부관 얘기, 잊지 않았겠지.\" 경비대장이 총을 닦으며 묻는다.",
	"front": "\"손님이 또 온다. 이번엔 세 병.\" 앞칸 대표가 지난번처럼 웃지는 않는다.",
	"engine": "\"그 견습생, 쓸 만하다. 하나 더.\" 수석 기관사가 이번엔 이름까지 적어 왔다.",
}
