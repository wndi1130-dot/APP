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
const TrainResearch = preload("res://game/train/train_research.gd")
const C = preload("res://game/train/turn/turn_common.gd")
const People = preload("res://game/train/turn/turn_people.gd")
const Late = preload("res://game/train/turn/turn_late.gd")

const RES_NAME: Dictionary = {"coal": "석탄", "food": "식량", "med": "의약품", "lux": "사치품", "trust": "신임",
	"tension": "긴장", "fear": "공포", "injured": "부상자"}
const BASE_NAME: Array[String] = ["온기", "배급", "과밀", "노출"]
## The kinds whose S1 view runs withAfford itself (the rest only meet guardCosts).
const AFFORD_KINDS: Array[String] = ["travel", "demand", "ration_cut", "favor", "rescue", "bitten", "rep_sick", "promise_ledger", "keepsake",
	"strike_warn", "strike", "bite_found", "orphan", "elder", "birth", "naming", "tension_crisis", "protest"]


## The card as S1 shows it: turn_cards.gd view's choices with S1's words, and
## {title, speaker ({name, role, comm?} or null), body, required, focus (or null),
## key?}. {} for a kind turn_cards.gd does not draw.
static func view(g: Dictionary, t: Dictionary, card: Dictionary) -> Dictionary:
	var v: Dictionary = TurnCards.view(g, t, card)
	if v.is_empty():
		return {}
	# Content carries S1's filled body/speaker/why/later/log and guarded choices already.
	if card["kind"] in ["content", "content-deal"]:
		var content: Dictionary = v.duplicate(true)
		if not content.has("speaker"): content["speaker"] = null
		if not content.has("focus"): content["focus"] = null
		for choice: Dictionary in content["choices"]:
			for key: String in ["say", "why", "later", "disabled"]:
				if not choice.has(key): choice[key] = ""
		return content
	var out: Dictionary = v.duplicate(true)
	out["speaker"] = null
	out["body"] = ""
	out["required"] = true
	out["focus"] = null
	var says: Array = []
	var why: Array = []
	# A choice S1 shuts itself (bite_found's cut once the window closes), kept past the words below.
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
			out["body"] = ("감축법이 다시 섰다. 꼬리칸 대표가 왔다. \"지난번 답, 우리는 기억한다.\" 꼬리칸 배급 %d." % r) if past != null \
				else ("비상식량감축법이 섰다. 꼬리칸 대표가 빈 그릇을 들고 왔다. \"제일 적게 받는 우리한테서 또 깎으면, 그게 고르게 줄이는 거냐.\" 꼬리칸 배급 %d." % r)
			says = ["꼬리칸 그릇은 그대로 둔다. 나머지 칸이 줄인다.", "앞칸이 한 단 더 줄인다. 꼬리칸 몫은 거기서 나온다.", "예외는 없다. 모두 같이 줄인다."]
			why = ["아끼는 식량이 구간마다 %s로 준다." % _num(-float(k["spareFood"])),
				"앞칸 배급 처지는 모두 −%s까지 내려간다. 아끼는 식량은 그대로다." % _num(2.0 * float(k["sit"])), ""]
		"favor":
			var past: Variant = _memo(g, "favor:" + c)
			out["speaker"] = _leader(g, t, c)
			out["focus"] = c
			out["body"] = String((FAVORS_AGAIN if past != null else FAVORS)[c])
			says = ["이번까지다. 다음은 없다." if past != null else "들어주마. 대신 이 일은 기억해 둬라.",
				"한 번 들어줬다고 버릇이 되면 안 된다." if past != null else "사사로운 부탁은 받지 않는다."]
		"rescue": _rescue(g, t, card, out, says)
		"bitten":
			var past: Variant = _memo(g, "bitten")
			var parts: Array = [["팔", "팔을"], ["다리", "다리를"], ["손", "손을"]][int(card["uid"]) % 3]
			var echo: String = " 지난번 일 때문에 다들 상처부터 본다." if _was(past, "hide") else (" 지난번 역에 두고 온 사람을 다들 기억한다." if _was(past, "leave") else "")
			out["speaker"] = {"name": str(card.get("who", "수색대원")), "role": String(t["COMM_NAME"][c])}
			out["focus"] = c
			out["body"] = "%s이(가) %s 물렸다. \"열차장…\" 수색대가 열차장의 말을 기다린다. \"감염 창이 닫히기 전에 잘라야 합니다.\"%s" % [str(card.get("who", "대원")), parts[1], echo]
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
			out["body"] = "%s이(가) 열차장이 어긴 약속 둘을 적은 종이를 내밀었다. \"%s\"" % [who["name"], LEDGER_SAY[c]]
			says = ["내 잘못이다. 지금 갚겠다.", "지난 일이다. 앞을 보자."]
		"need_warn":
			var def: Dictionary = t["NEEDS"][card["text"]]
			var warn: Array = def["warn"]
			out["body"] = "%s %d구간 안에 정하지 않으면 손해가 난다. 약속하면 한 구간을 더 벌지만, 어기면 신임을 크게 잃는다." % [warn[int(card.get("n", 0)) % warn.size()], int(t["NEED_GRACE"])]
			says = ["다음 회기 안에 정하겠다. 내 이름을 걸고 약속한다.", "서두른다고 좋은 법이 나오지 않는다. 지켜봐라."]
		"keepsake":
			# S1 cards.ts keepsake: no one brings it; the car asks who wears the coat.
			var dead: String = str(card.get("who", ""))
			var field: bool = card.get("text") == "field"
			var like: String = String(C.profile(t, dead).get("like", ""))
			out["focus"] = c
			out["body"] = ("%s은(는) 정차에서 돌아오지 못했다. 침상 밑에 여벌 외투와 장화가 남았다." % dead if field else "%s의 외투와 장화가 남았다." % dead) \
				+ (" 칸 사람들은 그를 '%s'%s 좋아하던 사람으로 기억한다." % [like, _eul(like)] if like != "" else "") + " 누가 입을지 칸이 묻는다."
			says = ["그 칸 사람들이 나눠 입어라. 그게 맞다."]
			if c != "tail": says.append("꼬리칸엔 장화 없는 사람이 있다. 그리로 보내라.")
			says.append("그 침상은 아무도 건드리지 마라." if field else ("그 옷은 그와 함께 불에 들어간다." if St.law_active(g, "corpse_burn") else "그 옷은 그와 함께 간다. 손대지 마라."))
		"dom:short":
			# S1 domestic/cards.ts: the craft master brings it; the machines that could not pay run at half.
			out["speaker"] = _craft_master(g, t)
			var names: Array = []
			for id: String in str(card.get("text", "")).split(",", false):
				names.append(TrainResearch.TECHS[id]["name"] if TrainResearch.TECHS.has(id) else id)
			out["body"] = "유지비를 못 낸 기계가 반쯤만 돈다(%s)." % ", ".join(names)
			says = ["그건 세워라. 그 부품으로 보일러부터 막는다!", "삐걱대도 달린다!", "기계를 굶길 순 없다. 목표치를 올려라!"]
			why = ["기술 하나가 멈춘다", "반쯤만 돈다", "부품 목표치 +3"]
		"strike_warn":
			# S1 cards.ts strike_warn: the engine's exposure and ration as the warning comes.
			var sit: Array = St.situation(g, t, "engine")
			out["speaker"] = _leader(g, t, "engine")
			out["focus"] = "engine"
			out["body"] = "\"다음 역까지 답이 없으면 불을 끄겠다.\" 기관실 위험 노출 %d, 배급 %d." % [_round(float(sit[3])), _round(float(sit[1]))]
			says = ["교대를 늘리겠다. 그러니 불은 끄지 마라.", "기관실 그릇을 채워라. 불 지키는 사람이 굶으면 안 된다.", "불을 끄겠다고? 그럼 다 같이 얼어 죽는 거다."]
		"strike":
			out["speaker"] = _leader(g, t, "engine")
			out["focus"] = "engine"
			out["body"] = "보일러 불이 낮게 깔렸다. 열차가 선다. 기관실 문 앞에 화부들이 앉아 있다."
			says = ["요구를 받아들인다. 당장 불을 올려라!", "교대를 늘린다. 그러니 문 앞에서 일어나라.", "수석 기관사를 따로 불러라. 줄 게 있다.", "협박에는 굽히지 않는다. 앉아 있고 싶으면 계속 앉아 있어라."]
		"pro_deal":
			# S1 prologue.ts pro_deal: the tail's leader asks by how the depot promise went.
			var kept: bool = g.get("story", {}).get("flags", {}).get("depot_promise") == "kept"
			var rep: String = String(g["comms"]["tail"]["leader"]["name"])
			out["speaker"] = _leader(g, t, "tail")
			out["focus"] = "tail"
			out["body"] = "열차가 호숫가를 벗어났다. %s%s 말한다. %s" % [rep, _josa(rep, "이/가"), "\"약속을 지켰다. 그러니 하나만 청한다. 꼬리칸 난로에 석탄을 한 삽 더.\"" if kept else "\"이제 값을 치러라. 꼬리칸 난로에 한 삽 더, 배급도 한 국자 더.\""]
			says = ["한 삽 더 넣어라." if kept else "난로도 배급도 한 칸씩 올린다.", "지금은 못 한다. 석탄이 모자란다."]
		"leash":
			out["speaker"] = _leader(g, t, c)
			out["focus"] = c
			out["body"] = "%s이(가) 제 비밀을 털어놓고 열차장이 그걸로 협박했다고 말했다." % g["comms"][c]["leader"]["name"]
			says = ["제 입으로 털어놨으면 됐다. 더 할 말 없다."]
		"bite_found":
			# S1 cards.ts bite_found: the medic brings it; a corpse's bite is no hidden one, so no word of the captain hiding it.
			out["speaker"] = _leader(g, t, "medtech")
			out["focus"] = c
			if card.get("text") == "corpse":
				out["body"] = "남겨 두었던 시신에게 %s이(가) 물렸다." % str(card.get("who", "그 사람"))
				says = ["아직 늦지 않았다. 의무칸으로 옮겨 잘라라!", "빈 칸 끝에 눕혀라. 문은 열고 가족을 곁에 둬라.", "일어나기 전에 끝내라. 가족은 뒤로 물려라."]
			else:
				out["body"] = ("%s %s의 붕대 아래가 검게 부었다. 자르기엔 늦었다. 열차장이 숨겨 줬다는 말이 벌써 돈다." % [str(card.get("text", "")), str(card.get("who", "대원"))]).strip_edges()
				says = ["빈 칸 끝에 눕혀라. 문은 열고 가족을 곁에 둬라.", "일어나기 전에 끝내라. 내가 숨긴 일이다, 내가 책임진다."]
		"orphan":
			# S1 cards.ts orphan: the children by name and age, and the other parent when one lives.
			var dead: String = str(card.get("who", ""))
			var f: Dictionary = People.family(g, t, dead)
			var other: Dictionary = {}
			for o: Dictionary in f.get("others", []):
				if f["fam"]["parents"].has(o["id"]):
					other = o
					break
			var named: Array = []
			for k: Dictionary in f.get("kids", []): named.append("%s(%s)" % [k["name"], _num(float(k["age"]))])
			var kid_text: String = ", ".join(named)
			var parent: String = String(other.get("name", ""))
			out["speaker"] = _leader(g, t, c)
			out["focus"] = c
			out["body"] = ("%s이(가) 아이 %s을(를) 남겼다. 곁엔 %s뿐인데, 혼자서는 버거워 보인다. 칸이 열차장의 말을 기다린다." % [dead, kid_text, parent]) if not other.is_empty() \
				else ("%s이(가) 아이 %s을(를) 남겼다. 이제 아무도 없다. 칸이 열차장의 말을 기다린다." % [dead, kid_text])
			says = [("%s이(가) 키운다. 칸이 손을 보태라!" % parent) if not other.is_empty() else "이 칸의 아이다. 이 칸이 함께 키운다."]
			if c != "front": says.append(("밤엔 앞칸 빈 침대에서 재워라. %s도 자야 한다." % parent) if not other.is_empty() else "앞칸에 빈 침대가 있다. 거기서 자게 해라.")
			if c != "medtech": says.append(("낮엔 의무진이 맡아라. %s의 손을 덜어 줘라." % parent) if not other.is_empty() else "의무진이 맡아라. 아플 때 제일 가깝다.")
		"elder":
			# S1 cards.ts elder: the old one comes in person; the age reads beside the car.
			var who: String = str(card.get("who", "노인"))
			var age: Variant = C.profile(t, who).get("age")
			out["speaker"] = {"name": who, "role": String(t["COMM_NAME"][c]) + ((" · %s세" % _num(float(age))) if age != null else ""), "comm": c}
			out["focus"] = c
			out["body"] = "%s이(가) 스스로 정했다며 찾아왔다. \"다음 역에서 내리겠다. 내 몫은 아이들에게.\"" % who
			says = ["아무도 혼자 내리지 않는다. 자리로 돌아가라.", "원한다면 막지 않겠다. 몫은 아이들에게 간다.", "모두 모여라. 그를 그냥 보내지는 않는다."]
		"birth":
			var mother: String = str(card.get("who", ""))
			var cold: bool = float(St.situation(g, t, c)[0]) < float(t["BIRTH"]["warm"])
			out["speaker"] = _leader(g, t, "medtech")
			out["focus"] = c
			out["body"] = "%s에서 %s의 아이가 나온다. %s" % [t["COMM_NAME"][c], mother, "거긴 너무 춥다." if cold else "칸은 그럭저럭 따뜻하다."]
			says = ["의무칸을 비워라. 아이는 따뜻한 데서 받는다.", "옮길 틈이 없다. 거기서 받아라."]
		"naming":
			var mother: String = str(card.get("who", ""))
			out["speaker"] = {"name": mother, "role": String(t["COMM_NAME"][c]), "comm": c}
			out["focus"] = c
			out["body"] = "%s의 아이에게 이름이 필요하다. 칸 사람들이 열차장을 쳐다본다." % mother
			says = ["이름은 엄마가 짓는 거다. 내가 끼어들 일 아니다.", "이 아이는 열차 모두의 아이다. 열차 이름을 줘라.", "내 이름을 줘라. 이 아이는 내가 지킨다."]
		"tension_crisis":
			# S1 cards.ts tension_crisis: the ladder's last rung, the tail's leader brings it.
			out["speaker"] = _leader(g, t, "tail")
			out["focus"] = "tail"
			out["body"] = "칸마다 사람들이 모였다. 통로를 막아서고 거래도 끊었다. 오늘 밤을 넘기지 못할 수도 있다."
			says = ["경비대, 통로를 비워라. 손은 쓰지 마라.", "창고를 열어라! 오늘 밤은 모두 배불리 먹는다.", "(열차장은 아무 말도 하지 않는다.)"]
		"protest":
			# S1 cards.ts protest: a protest, or a riot (text "riot") with fire when it has caught.
			out["speaker"] = _leader(g, t, "tail")
			out["focus"] = "tail"
			if card.get("text") != "riot":
				out["body"] = "복도마다 사람들이 모여 열차장을 찾는다. 배급과 석탄을 두고 목소리가 높아지고 있다."
				says = ["들어보자. 줄 수 있는 것은 나눠 주겠다.", "통로에 경비를 세워라. 손은 쓰지 마라.", "지금은 줄 것이 없다. 돌아가 제 일을 해라."]
			else:
				var fire: bool = g.get("riot") is Dictionary and not (g["riot"].get("fire", []) as Array).is_empty()
				out["body"] = "싸움이 번졌다. 물건이 날고 어른들이 쓰러진다." + (" 불이 붙었다. 사람들은 걸어서 옆 칸으로 옮겨 간다." if fire else "")
				says = ["요구를 듣겠다. 모두 손을 내려라.", "경비대를 풀어라! 싸움부터 말려라.", "(열차장은 아무 말도 하지 않는다.)"]
		"info":
			out["title"] = str(card.get("who", "알림"))
			out["body"] = str(card.get("text", ""))
	var choices: Array = out["choices"]
	for i: int in choices.size():
		var ch: Dictionary = choices[i]
		ch["say"] = String(says[i]) if i < says.size() else String(ch.get("say", ""))
		ch["why"] = String(why[i]) if i < why.size() else ""
		# A way the rule shuts keeps why (S1 card.ts shows it on the way): the guard who
		# will not go, the infection window that has closed.
		ch["disabled"] = String(ch.get("disabled", ""))
	out["body"] = Late.body(g, card, out["body"])
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


## S1 chief(g, 'craft'): the workshop's most skilled hand (the dom's experts), or no one.
static func _craft_master(g: Dictionary, t: Dictionary) -> Variant:
	var best: Dictionary = {}
	var dom: Variant = g.get("dom")
	for e: Variant in (dom.get("experts", []) if dom is Dictionary else []):
		if e is Dictionary and e.get("field") == "craft" and (best.is_empty() or int(e["skill"]) > int(best["skill"])):
			best = e
	if best.is_empty():
		return null
	return {"name": String(best["name"]), "role": String(t["COMM_NAME"].get(String(best.get("comm", "")), "공방"))}


static func _leader(g: Dictionary, t: Dictionary, c: String) -> Dictionary:
	return {"name": String(g["comms"][c]["leader"]["name"]), "role": String(t["REP_ROLE"][c]), "comm": c}


## S1 cards.ts eul: 을 after a final consonant, 를 after a vowel, 을(를) for anything not Hangul.
static func _eul(word: String) -> String:
	var code: int = word.unicode_at(word.length() - 1)
	if code < 0xac00 or code > 0xd7a3:
		return "을(를)"
	return "을" if (code - 0xac00) % 28 != 0 else "를"


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
			out["body"] = _again(past, "꼬리칸 난로가 이틀째 꺼져 있다. 아이 %d명의 손끝이 하얗다. \"앞칸엔 난로가 두 개다.\"" % kids, {
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
			out["body"] = _again(past, "꼬리칸에서 누울 자리를 두고 주먹이 오갔다. 한 사람이 머리를 다쳤다. \"누울 자리가 사람 수보다 적다.\"", {
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
				"burn_melt": "급수탑이 또 얼었다. 화부들은 아직 그 얘기다. \"지난번 녹이느라 태운 석탄이면 한참 달렸다.\" 석탄은 %d 남았다." % coal,
				"snow_melt": "급수탑이 또 얼었다. 지난번 양동이 일로 손이 다 튼 사람들이 묻는다. \"이번에도 우리냐?\"",
				"hold_on": "보일러 물이 거의 바닥났다. 수석 기관사가 말한다. \"지난번처럼 버티면 보일러 관이 탑니다.\"",
			}, "급수탑이 또 얼었다.")
			says.append_array(["물 없는 보일러는 고철이다. 석탄을 태워서라도 녹여라!",
				("%s%s 한 번 더 한다. 장갑은 앞칸에서 걷어 줘라." % [name, _iga(name)]) if _was(past, "snow_melt") else ("%s%s 양동이를 들어라. 눈을 퍼다 녹인다." % [name, _josa(name, "은/는")]),
				"관은 안 탄다. 내가 보증한다. 간다!" if _was(past, "hold_on") else "물을 아껴라. 다음 급수탑까지 간다."])
		"snow_drift":
			out["speaker"] = _leader(g, t, "engine")
			out["focus"] = "engine"
			out["body"] = _again(past, "선로가 눈더미에 묻혔다. 삽이 열두 자루 있다.", {
				"dig_all": "또 눈더미다. 사람들이 지난번 일을 아직 말한다. \"다 같이 파면 금방 끝난다.\" 앞칸 몇은 벌써 삽을 들었다.",
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
			out["body"] = _again(past, "꼬리칸 아이 셋이 열이 난다. \"해열제는 상자에 있습니다. 꺼낼지 정해 주십시오.\"", {
				"med_use": "이번엔 아이 다섯이 열이 난다. 지난번 약을 받은 집 얘기가 칸에 다 퍼졌다. \"그 집 애만 애냐.\" 의약품은 %d 남았다." % _round(float(g["med"])),
				"med_save": "지난번 약을 못 받은 아이가 아직 열이 안 내렸다. 엄마가 의무칸 문 앞을 떠나지 않는다. \"우리 애 차례는 언제냐.\"",
			}, "아이들이 또 열이 난다.")
			says.append_array(["의약품은 약자의 것이다. 아이들에게 먼저 써라!",
				"약은 살 사람에게 쓴다. 그 엄마를 문 앞에서 데려가라." if _was(past, "med_save") else "애들 열은 금방 내린다. 엄살 부리지 말라고 전해라!"])
		"ration_line":
			out["speaker"] = _leader(g, t, "tail")
			out["focus"] = "tail"
			out["body"] = _again(past, "배급 줄 끝에서 빵이 떨어졌다. 뒤에 선 사람들이 소리친다. \"우리 몫은 어디 갔어!\"", {
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
				out["body"] = _again(past, "지붕 경계를 서던 대원 둘이 동상을 입었다. \"교대를 줄여 달라.\"", {
					"hold_post": "지난번 지붕에 섰던 대원 하나가 발가락 둘을 잃었다. 경비대장이 말한다. \"지붕 교대는 이제 못 선다.\"",
					"watch_less": "경계를 줄인 그 밤을 두고 말이 많다. \"지붕 위로 뭔가 지나갔다.\" 대원들이 다시 동상을 입었다.",
					"guard_heat": "경비칸이 따뜻해지자 다른 칸이 수군댄다. \"그 칸 난로는 밤새 벌겋더라.\" 그런데 지붕 위 바람은 여전히 살을 엔다.",
				}, "지붕 경계 대원들이 또 동상을 입었다.")
			else:
				out["body"] = _again(past, "지붕 경계를 서던 대원 둘이 찬비에 흠뻑 젖어 이가 맞부딪힌다. \"교대를 줄여 달라.\"", {
					"hold_post": "지난번 지붕에 섰던 대원 하나가 열이 올라 일어나지 못한다. 경비대장이 말한다. \"지붕 교대는 이제 못 선다.\"",
					"watch_less": "경계를 줄인 그 밤을 두고 말이 많다. \"지붕 위로 뭔가 지나갔다.\" 대원들이 다시 젖은 채 떨었다.",
					"guard_heat": "경비칸이 따뜻해지자 다른 칸이 수군댄다. \"그 칸 난로는 밤새 벌겋더라.\" 그런데 지붕 위 찬비는 그대로다.",
				}, "지붕 경계 대원들이 또 젖은 채 떨었다.")
			says.append_array(["경비칸 난로에 석탄을 더 넣어라. 지키는 사람이 얼면 끝이다.", "얼어 죽은 보초는 아무것도 못 본다. 지붕에서 내려와라.",
				"거부는 없다. 지붕이 비면 다 같이 죽는다." if _was(past, "hold_post") else ("경계는 줄이지 않는다. 장갑을 두 겹 껴라." if frost else "경계는 줄이지 않는다. 젖은 옷은 교대 때마다 갈아입어라.")])


## 요구 카드에서 칸 대표가 직접 하는 말: [보통, 좋음(관계 15 이상), 나쁨(관계 -15 이하)]. S1 cards.ts DEMAND_SAY와 같다.
const DEMAND_SAY: Dictionary = {
	"tail": {"heat": ["우리 칸 난로부터 올려 줘. 손이 굳어서 삽을 못 쥔다.", "한 눈금만 올려 줘. 우린 받은 건 갚는다.", "다음 회기 전까지 올려 줘. 우리도 오래는 못 참는다."], "ration": ["우리도 빈속으론 못 버틴다. 그릇 좀 제대로 채워 줘.", "한 국자만 더 부탁하자. 우린 빚진 건 안 잊는다.", "다음 회기 전까지 채워 줘. 우린 빈 그릇 들고 또 오기 싫다."]},
	"medtech": {"heat": ["이 온기면 의무칸 침상부터 찬다.", "조금만 올려 달라. 동상 환자를 받기 전에.", "다음 회기 전까지다. 그 뒤엔 동상 환자 수를 센다."], "ration": ["반 그릇이면 상처가 안 아문다. 다음은 열병이다.", "조금 더 채워 달라. 아픈 사람 몫부터 부탁한다.", "다음 회기 전까지 채워 달라. 그 뒤엔 의무칸이 감당 못 한다."]},
	"guard": {"heat": ["초소가 언다. 손가락이 방아쇠에 안 붙는다. 올려 달라.", "대원들 입김이 하얗다. 한 단만 부탁한다.", "야간 보초가 한계다. 다음 회기 전까지 답 달라."], "ration": ["대원들 그릇이 반이다. 보초 서다 쓰러진다. 올려 달라.", "대원 몫만 채워 달라. 보초는 빈속으로 못 선다.", "다음 회기 전까지 답 달라. 대원들이 기다린다."]},
	"front": {"heat": ["온기가 이래서는 손님을 못 받습니다. 조금만 올려 주시지요.", "한 눈금이면 충분합니다. 앞칸은 받은 것을 잊지 않지요.", "다음 회기 전까지 답을 주시지요. 표는 그 뒤에 셈하겠습니다."], "ration": ["반 그릇이라. 몫을 다시 셈해 보셨으면 합니다.", "조금만 더 얹어 주시면, 그 몫은 기억해 두겠습니다.", "회기 전까지 채워 주시지요. 아니면 그 몫은 회기에서 따지겠습니다."]},
	"engine": {"heat": ["손이 곱으면 불이 늦게 든다. 기관차는 기다려 주지 않는다.", "불 앞 한 단만. 손을 녹여야 삽이 든다.", "다음 회기 전에 답 달라. 식은 손으로는 보일러 못 지킨다."], "ration": ["삽질은 배로 먹는다. 반 그릇으로는 불이 안 산다.", "화부들 몫만 더 달라. 불은 우리가 지킨다.", "다음 회기 전에 채워 달라. 빈속으로 삽 든 놈은 오래 못 간다."]},
}
## 거절당한 뒤 다시 온 요구 때 대표의 말(차례는 DEMAND_SAY와 같다).
const DEMAND_AGAIN: Dictionary = {
	"tail": {"heat": ["지난번엔 그냥 갔지. 이번엔 같이 왔다.", "한 번은 참았다. 이번엔 우리 난로 좀 올려 줘.", "회기 전까지다. 이번엔 안 물러난다."], "ration": ["이 그릇, 지난번 그대로다. 채워서 돌려줘.", "우리 그릇 씻을 일 좀 만들어 줘.", "또 빈 그릇이다. 회기 전까지 우리 몫 채워 줘."]},
	"medtech": {"heat": ["지난번 답은 기록해 뒀다. 다시 묻는다.", "다시 왔다. 손끝이 하얘지기 전에 한 단만.", "또 거절하면 다음은 동상이다. 회기 전까지 답 달라."], "ration": ["지난번 그릇 그대로다. 환자 몫부터 비었다.", "이번엔 채워 달라. 의무칸이 버틸 만큼만.", "또 비우면 열병을 못 막는다. 회기 전까지 채워 달라."]},
	"guard": {"heat": ["지난번 거절, 대원들도 들었다. 다시 묻는다.", "한 번은 물러났다. 이번엔 올려 달라.", "회기 전까지다. 대원들이 뒤에 서 있다."], "ration": ["그릇 그대로 가져왔다. 다시 묻는다.", "그때는 그냥 복귀했다. 이번엔 대원 몫을 채워 달라.", "회기 전까지다. 그릇은 여기 두고 간다."]},
	"front": {"heat": ["지난번 답은 들었습니다. 오늘 답은 다르길 바랍니다.", "한 번은 사정이 있으셨겠지요. 이번엔 믿겠습니다.", "회기 전까지입니다. 지난번처럼은 곤란합니다."], "ration": ["이 그릇, 지난번 그대로입니다. 셈이 안 맞지요.", "그릇이 말라붙었습니다. 한 번은 채워 주셔야지요.", "회기 전까지입니다. 빈 그릇은 회기에서 보여 드리지요."]},
	"engine": {"heat": ["지난번 그 답으로는 불이 안 든다.", "불 앞은 아직 차다. 삽 쥘 만큼만 올려 달라.", "보일러는 거절을 모른다. 회기 전에 답 달라."], "ration": ["지난번 그릇 그대로다. 화부들이 지켜본다.", "빈손으로 한 번 갔다. 삽질할 만큼만 채워 달라.", "회기 전에 답 달라. 빈 그릇으로 불 못 땐다."]},
}
## 약속 장부 카드에서 칸 대표가 직접 하는 경고(S1 cards.ts LEDGER_SAY와 같다).
const LEDGER_SAY: Dictionary = {
	"tail": "한 번만 더 어겨 봐라. 꼬리칸은 다시는 약속 안 받는다.",
	"medtech": "어긴 게 둘이다. 셋째면 기술·의무진은 약속을 받지 않는다.",
	"guard": "두 번이다. 한 번 더면 경비대는 약속을 안 받는다.",
	"front": "두 번은 넘어갔습니다. 한 번 더 어기시면 앞칸은 약속을 받지 않겠습니다.",
	"engine": "두 번 샜다. 한 번 더 새면 기관실은 약속을 안 받는다.",
}


static func _demand(g: Dictionary, t: Dictionary, c: String, out: Dictionary, says: Array) -> void:
	var sit: Array = St.situation(g, t, c)
	var name: String = String(t["COMM_NAME"][c])
	if c == "engine" and float(sit[3]) > 50:
		var past: Variant = _memo(g, "demand:engine_shift")
		var ex: int = _round(float(sit[3]))
		out["speaker"] = _leader(g, t, "engine")
		out["focus"] = "engine"
		out["body"] = _again(past, "화부들이 교대 없이 삽질을 한 지 오래다. 위험 노출 %d. \"화부들 손이 떨린다. 교대를 늘려 달라.\"" % ex, {
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
	var rel: float = float(s["rel"])
	# 같은 요구라도 관계에 따라 대표의 말이 다르다: 보통·좋음·나쁨(S1 cards.ts와 같다).
	var mood: int = 1 if rel >= 15 else (2 if rel <= -15 else 0)
	var need: String = "heat" if heat else "ration"
	var say: String = String(DEMAND_SAY[c][need][mood])
	var again: String = String(DEMAND_AGAIN[c][need][mood])
	var first: String = ("%s 온기 %d. 밤마다 사람들이 서로 붙어 잔다. \"%s\"" % [name, _round(float(sit[0])), say]) if heat \
		else ("%s 배급 %d. 그릇이 반만 찬다. \"%s\"" % [name, _round(float(sit[1])), say])
	var refused: String = ("%s 대표가 또 왔다. 이번엔 뒤에 칸 사람 몇이 서 있다. 온기 %d. \"%s\"" % [name, _round(float(sit[0])), again]) if heat \
		else ("%s 대표가 빈 그릇을 들고 왔다. 지난번 거절한 날부터 그릇을 씻지 않았다고 한다. 배급 %d. \"%s\"" % [name, _round(float(sit[1])), again])
	out["speaker"] = _leader(g, t, c)
	out["focus"] = c
	out["body"] = refused if _was(past, "refuse") else first
	says.append_array([
		("%s 난로를 올려라. 밤에 얼어 죽는 사람은 없어야 한다." % name) if heat else ("%s 그릇을 채워라. 빈 그릇으로는 일 못 한다." % name),
		"사람을 몰고 와도 석탄은 늘지 않는다." if _was(past, "refuse") else ("다들 붙어 자기는 마찬가지다. 지금은 안 된다." if heat else "모두 반 그릇이다. 더 나올 데가 없다.")])


static func _rescue(g: Dictionary, t: Dictionary, card: Dictionary, out: Dictionary, says: Array) -> void:
	var ban: bool = (g.get("passed", {}) as Dictionary).has("no_outsiders")
	var past: Variant = _memo(g, "rescue")
	var n: int = int(past.get("n", 0)) if past is Dictionary else 0
	var who: String = [
		"역사 안에 다친 사람 둘이 있다. \"데려가 주세요. 걸을 수는 있어요.\"",
		"역사 구석에 노인과 소년이 있다. \"할아버지를 업고 여기까지 왔어요. 같이 가게 해 주세요.\"",
		"플랫폼 끝에 여자 하나가 앉아 있다. 다리를 다쳤고, 아이를 안고 있다. \"아이만이라도 태워 주세요.\"",
		"대합실 의자 밑에서 남자 하나가 기어 나왔다. 손이 떨린다. \"기관사였어요. 불은 아직 땔 줄 알아요.\"",
	][n % 4]
	var echo: String = " 꼬리칸은 이미 꽉 찼다."
	if _was(past, "leave") or _was(past, "leave_law"):
		echo = " 수색대가 이번엔 먼저 묻는다. \"또 두고 갑니까?\""
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
	"front": "\"술 두 병만. 손님을 맞아야 합니다.\" 앞칸 대표가 웃는다.",
	"engine": "\"견습생 하나를 꼬리칸에서 데려가고 싶다. 내가 고른 아이로.\"",
}
## S1 FAVORS_AGAIN: the second time another favour comes.
const FAVORS_AGAIN: Dictionary = {
	"tail": "\"아들이 나았다. 이번엔 조카다.\" 대표가 눈을 피하며 말한다. 의무칸 침상이 또 필요하다.",
	"medtech": "\"동생이 앞칸에서 쫓겨날 것 같다. 한마디만 해 달라.\" 의사가 처음으로 목소리를 낮춘다.",
	"guard": "\"부관 얘기, 잊지 않았겠지.\" 경비대장이 총을 닦으며 묻는다.",
	"front": "\"손님이 또 옵니다. 이번엔 세 병.\" 앞칸 대표가 지난번처럼 웃지는 않는다.",
	"engine": "\"그 견습생, 쓸 만하다. 하나 더.\" 수석 기관사가 이번엔 이름까지 적어 왔다.",
}
