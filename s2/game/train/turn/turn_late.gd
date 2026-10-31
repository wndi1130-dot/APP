extends RefCounted
## S1 late.ts (결정 514). Player deferrals are separate from the card budget.
const St = preload("res://game/train/train_state.gd")
const Budget = preload("res://game/train/turn/turn_budget.gd")
const LATE := {"max": 2, "margin": 2, "step": 2, "grow": 0.5}
const DEMAND_WORDS := {
	"tail": ["다음에 오라더니 또 왔다. 이번엔 답 듣고 간다.", "두 번 미뤘다. 세 번째는 우리가 알아서 한다."],
	"medtech": ["미룬 날부터 적어 뒀다. 환자 수가 늘었다.", "두 번 미룬 것까지 적어 뒀다. 더는 묻지 않는다."],
	"guard": ["기다렸다. 대원들은 더 못 기다린다.", "두 번이다. 대원들이 열차장 말을 안 믿기 시작했다."],
	"front": ["기다려 드렸습니다. 이번엔 답을 주셔야지요.", "두 번 기다려 드렸습니다. 세 번은 어렵겠습니다."],
	"engine": ["미룬 사이에 불이 한 번 꺼질 뻔했다. 답 달라.", "두 번 미뤘다. 불은 안 기다린다. 우리도 이제 안 기다린다."],
}
const LATER_SAY := {
	"demand": "지금은 재고할 문제가 아니다. 다음 회기에 다시 와라.",
	"favor": "더 중요한 문제가 있다. 그 부탁은 나중에 듣겠다.",
	"promise_ledger": "장부는 나중에 펼치겠다. 지금은 더 중요한 문제가 있다.",
	"ration_cut": "감축은 막 섰다. 예외는 지금 재고할 문제가 아니다.",
	"front_curtain": "커튼 하나로 열차를 세울 수는 없다. 더 중요한 문제가 있다.",
}


static func enable(g: Dictionary) -> void:
	g["lateOn"] = true


static func kind(card: Dictionary) -> String:
	var k: Variant = card.get("kind", "")
	if not k is String: return ""
	if k in ["demand", "favor", "promise_ledger", "ration_cut"]: return k
	return "front_curtain" if k == "travel" and card.get("text") == "front_curtain" else ""


static func comm(card: Dictionary) -> String:
	return "tail" if card.get("kind") in ["ration_cut", "travel"] else str(card.get("comm") if card.get("comm") != null else "tail")


static func grow_eff(e: Array, late: int) -> Array:
	var out: Array = e.duplicate(true)
	var key: String = e[0]
	var at: int = 2 if key in ["rel", "pop", "fervor"] else 1
	if key not in ["coal", "food", "med", "lux", "trust", "rel", "pop", "tension", "fear", "injured", "fervor"]: return out
	var v: float = float(e[at])
	var harm: bool = v > 0 if key in ["tension", "fear", "injured", "fervor"] else v < 0
	if harm: out[at] = signf(v) * floorf(absf(v) * (1.0 + float(LATE.grow) * late) + 0.5)
	return out


static func loss(ch: Dictionary, c: String) -> float:
	var total: float = 0.0
	for e: Array in ch["effs"]:
		if e[0] == "rel" and e[1] == c: total += float(e[2])
	return maxf(0.0, -total)


## Ties keep the first choice, including choices shut by costs.
static func worst_choice(choices: Array, c: String) -> Dictionary:
	var worst: Dictionary = {}
	for ch: Dictionary in choices:
		if ch.get("id") == "later": continue
		if worst.is_empty() or loss(ch, c) > loss(worst, c): worst = ch
	return worst


static func view(g: Dictionary, card: Dictionary, v: Dictionary) -> Dictionary:
	var k: String = kind(card) if g.get("lateOn", false) else ""
	if k == "" or v.is_empty(): return v
	var out: Dictionary = v.duplicate(true)
	var late: int = int(card.get("late", 0))
	var c: String = comm(card)
	var penalty: float = 0.0
	for ch: Dictionary in out["choices"]:
		if late > 0: ch["effs"] = (ch["effs"] as Array).map(func(e: Array) -> Array: return grow_eff(e, late))
		penalty = maxf(penalty, loss(ch, c))
	var say: String = "교대는 나중에 다시 짠다. 지금은 더 중요한 문제가 있다." if k == "demand" and v.get("key") == "demand:engine_shift" else LATER_SAY[k]
	out["late"] = late
	out["lateLeft"] = maxi(0, int(LATE.max) - late)
	out["choices"].append({"id": "later", "label": "나중에 정한다", "say": say, "effs": [["rel", c, -(penalty + LATE.margin + LATE.step * late)]], "special": "late", "witness": false})
	return out


static func _quote(body_text: String, say: String, last: bool) -> String:
	var re := RegEx.new()
	re.compile('"[^"]*"\\s*$' if last else '"[^"]*"')
	return re.sub(body_text, '"' + say + '"') if re.search(body_text) != null else body_text + ' "' + say + '"'


static func body(g: Dictionary, card: Dictionary, text: String) -> String:
	if not g.get("lateOn", false) or int(card.get("late", 0)) == 0: return text
	var c: String = comm(card)
	var twice: bool = int(card.get("late", 0)) >= 2
	var head: String = ""
	var say: String = ""
	match kind(card):
		"demand":
			head = "두 번 미룬 요구다." if twice else "지난번에 미룬 요구다."
			return head + " " + _quote(text, DEMAND_WORDS[c][1 if twice else 0], true)
		"favor":
			head = "두 번 미룬 부탁이다." if twice else "지난번에 미룬 부탁이다."
			say = ("두 번 미루셨습니다. 이번이 마지막으로 여쭙는 겁니다." if twice else "기다려 드렸습니다. 이번엔 들어 주시겠지요.") if c == "front" else ("두 번 미뤘다. 이번이 마지막으로 묻는 거다." if twice else "기다렸다. 이번엔 들어 줄 거냐.")
		"promise_ledger":
			var name: String = g["comms"][c]["leader"]["name"]
			head = name + ("이(가) 장부를 또 내밀었다." if twice else "이(가) 미뤘던 장부를 다시 내밀었다.")
			if not twice: return head + " " + text
			return head + " " + _quote(text, "이번엔 회기 앞에서 펼치겠습니다." if c == "front" else "이번엔 회기 앞에서 펼친다.", true)
		"ration_cut":
			if twice: return "두 번 미룬 감축 배급 요구다. " + _quote(text, "두 번 미뤘다. 우리 칸은 더 줄일 게 없다.", false)
			head = "미룬 감축 배급 요구다. 꼬리칸 대표가 빈 그릇을 다시 들고 왔다."
			say = "기다리라더니 그릇만 더 비었다."
		"front_curtain":
			head = "두 번 미룬 커튼 일이다." if twice else "미뤘던 커튼 일이다. 커튼 앞에 모인 사람이 늘었다."
			say = "두 번 미뤘다. 커튼이 걸린 채면 그게 답인 줄 알겠다." if twice else "커튼은 그대로다. 우리도 그대로 서 있다."
		_: return text
	return head + " " + text + ' "' + say + '"'


static func log_line(g: Dictionary, t: Dictionary, card: Dictionary) -> String:
	var c: String = comm(card)
	var title: String = t["COMM_NAME"][c]
	var name: String = g["comms"][c]["leader"]["name"]
	match kind(card):
		"demand": return "%s의 요구를 끝내 미뤘다. 답을 기다리던 %s이(가) 등을 돌렸다." % [title, title]
		"favor": return "%s의 부탁을 끝내 미뤘다. %s은(는) 다시 부탁하러 오지 않았다." % [name, name]
		"promise_ledger": return "%s이(가) 내민 장부를 끝내 펼치지 않았다. %s은(는) 그것을 물리친 것으로 기억한다." % [title, title]
		"ration_cut": return "감축 배급의 예외를 끝내 정하지 않았다. 꼬리칸 그릇부터 비었다."
		"front_curtain": return "커튼 일을 끝내 미뤘다. 꼬리칸은 걸린 커튼을 열차장의 답으로 들었다."
	return ""


static func pending(g: Dictionary, k: String) -> bool:
	return bool(g.get("lateOn", false)) and (g.get("lateCards", []) as Array).any(func(card: Dictionary) -> bool: return card.get("kind") == k)


## S1 budget.gone's demand branch. Other deferrable kinds have no gone branch.
static func demand_gone(g: Dictionary, t: Dictionary, card: Dictionary) -> bool:
	return Budget.gone(g, t, card)


static func next_segment(g: Dictionary, t: Dictionary) -> void:
	if not g.get("lateOn", false) or (g.get("lateCards", []) as Array).is_empty(): return
	var back: Array = []
	for card: Dictionary in g["lateCards"]:
		if kind(card) == "" or float(g["comms"][comm(card)]["pop"]) <= 0 or demand_gone(g, t, card): continue
		if card.get("kind") == "favor" and card.get("who") != null and card.get("who") != "" and card.get("who") != g["comms"][comm(card)]["leader"]["personId"]: continue
		if card.get("kind") == "ration_cut" and (not St.law_active(g, "emergency_ration") or g.get("rationCut") != null): continue
		if (g["cards"] as Array).any(func(c: Dictionary) -> bool: return c["uid"] == card["uid"]): continue
		back.append(card)
	g["lateCards"] = []
	g["cards"] = back + g["cards"]
