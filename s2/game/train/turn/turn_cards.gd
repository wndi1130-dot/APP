extends RefCounted
## S1 cards.ts choices and function-valued travel effects.
## Internal effect tuples keep their S1 order; no fixture states are consulted.
const C = preload("res://game/train/turn/turn_common.gd")
const St = preload("res://game/train/train_state.gd")
const W = preload("res://game/train/turn/turn_wounds.gd")
const People = preload("res://game/train/turn/turn_people.gd")
const Death = preload("res://game/train/turn/turn_death.gd")
const Travel = preload("res://game/train/turn/turn_travel.gd")
const Field = preload("res://game/politics/field_return.gd")
const RationCut = preload("res://game/train/turn/turn_ration_cut.gd")
const Ladder = preload("res://game/train/turn/turn_ladder.gd")
const TrainResearch = preload("res://game/train/train_research.gd")
const TrainWorkshop = preload("res://game/train/train_workshop.gd")
const Late = preload("res://game/train/turn/turn_late.gd")
const Budget = preload("res://game/train/turn/turn_budget.gd")
const TrainClimate = preload("res://game/train/train_climate.gd")
const Content = preload("res://game/train/turn/turn_content.gd")
const Trip = preload("res://game/train/turn/turn_trip_cards.gd")

static func choice(id: String, label: String, effs: Array, special: String = "", witness: bool = false) -> Dictionary:
	return {"id": id, "label": label, "effs": effs, "special": special, "witness": witness}

static func travel_view(g: Dictionary, t: Dictionary, id: String) -> Dictionary:
	var past: Dictionary = g.get("eventLog", {}).get(id, {})
	var n: int = mini(int(past.get("n", 0)), 3)
	var pick: String = past.get("pick", "")
	var title: String = ""
	var choices: Array = []
	match id:
		"tail_cold":
			title = "꺼진 난로" if past.is_empty() else "또 꺼진 난로"
			choices = [choice("fuel_front", "앞칸 연료를 덜어 온다", [["base", "tail", 0, 5], ["base", "front", 0, -5], ["rel", "tail", 5], ["rel", "front", -(8 + 3 * n)]]), choice("blankets", "담요를 나눈다", [["lux", -(1 + n)], ["rel", "tail", 4]]), choice("endure", "참으라 한다", [["rel", "tail", -(5 + 3 * n)], ["tension", 2 + 2 * n]])]
			choices[0]["log"] = "꼬리칸 난로가 꺼져 앞칸 연료를 덜어 왔다." if past.is_empty() else "꼬리칸 난로가 또 꺼져 앞칸 연료를 덜어 왔다."
			choices[1]["log"] = "꼬리칸 난로가 꺼져 창고 담요를 나눴다." if past.is_empty() else "꼬리칸 난로가 또 꺼져 창고 담요를 다시 나눴다."
			choices[2]["log"] = "꼬리칸 난로가 꺼졌어도 참으라고 했다." if past.is_empty() else "꼬리칸 난로가 또 꺼졌어도 버티라고 했다."
		"crowd_fight":
			title = "자리 싸움" if past.is_empty() else "또 자리 싸움"
			choices = [choice("guard_break", "경비대가 말린다", [["rel", "tail", -(3 + 2 * n)], ["tension", -3], ["fear", 2]]), choice("widen", "칸을 넓혀 준다", [["base", "tail", 2, -5], ["base", "front", 2, 5], ["rel", "front", -5], ["rel", "tail", 3]]), choice("let_be", "내버려 둔다", [["injured", 1 if past.is_empty() else 2], ["tension", 4 + 2 * n]])]
			choices[0]["log"] = "꼬리칸 자리 싸움을 경비대가 말렸다." if past.is_empty() else "또 붙은 자리 싸움을 경비대가 말렸다."
			choices[1]["log"] = "앞칸 짐을 치워 꼬리칸에 누울 자리를 넓혔다." if past.is_empty() else "또 붙은 자리 싸움에 앞칸 짐을 치워 자리를 넓혔다."
			choices[2]["log"] = "꼬리칸 자리 싸움을 내버려 뒀다." if past.is_empty() else "또 붙은 자리 싸움을 내버려 뒀다."
		"front_curtain":
			title = "앞칸의 커튼" if past.is_empty() else "다시 걸린 커튼"
			choices = [choice("curtain_open", "커튼을 걷게 한다", [["rel", "front", -(6 + 2 * n)], ["rel", "tail", 4]]), choice("side_front", "앞칸 편을 든다", [["rel", "tail", -(4 + 3 * n)], ["rel", "front", 4]]), choice("call_reps", "대표 둘을 부른다", [["lux", -(1 + n)], ["tension", -2], ["trust", 1]])]
			choices[0]["log"] = "앞칸 창의 커튼을 걷게 했다." if past.is_empty() else "다시 걸린 커튼을 걷게 했다."
			choices[1]["log"] = "커튼 다툼에서 앞칸 편을 들었다." if past.is_empty() else "다시 걸린 커튼 다툼에서 앞칸 편을 들었다."
			choices[2]["log"] = "커튼 일로 두 칸 대표를 열차장 식탁에 앉혔다." if past.is_empty() else "다시 걸린 커튼 일로 두 대표를 식탁에 불렀다."
		"water_tower":
			title = "얼어붙은 급수탑"
			var sc: String = g.get("lastCrew", "tail")
			var chore: float = float(t["P"]["choreRel"]) if t["CHORE_COMMS"].has(sc) else 0.0
			var hold: Array = [["coal", -2], ["rel", "engine", -(4 + 2 * n)]]
			if pick == "hold_on": hold.append(["base", "engine", 3, 6])
			choices = [choice("burn_melt", "불을 피워 녹인다", [["coal", -3]]), choice("snow_melt", "눈을 녹인다", [["base", sc, 3, t["P"]["snowExposure"]], ["rel", sc, -(4 + 3 * n) + chore]]), choice("hold_on", "다음 역까지 버틴다", hold)]
			choices[0]["log"] = "얼어붙은 급수탑을 석탄불로 녹였다."
			choices[1]["log"] = "얼어붙은 급수탑 대신 눈을 퍼다 녹였다."
			choices[2]["log"] = "얼어붙은 급수탑을 두고 물을 아끼며 떠났다."
		"snow_drift":
			title = "눈더미"
			var tail: Array = [["rel", "tail", -(5 + 3 * n)]]
			if pick == "dig_tail": tail.append(["tension", 3])
			choices = [choice("dig_all", "모든 칸이 나눠 판다", [["food", -3], ["rel", "front", -1 if pick == "dig_all" else -3], ["tension", -1]]), choice("dig_tail", "꼬리칸이 판다", tail), choice("plow", "기관차로 밀어붙인다", [["coal", -(4 + n)], ["base", "engine", 3, 4 + 2 * n]])]
			choices[0]["log"] = "선로를 묻은 눈더미를 모든 칸이 나눠 팠다."
			choices[1]["log"] = "선로를 묻은 눈더미를 꼬리칸이 팠다."
			choices[2]["log"] = "선로를 묻은 눈더미를 기관차로 밀고 나갔다."
		"abandoned_tender":
			title = "측선의 탄수차"
			choices = [choice("tender_take", "석탄을 옮긴다", [["coal", 8]], "risk_injury"), choice("tender_pass", "지나친다", [])]
			choices[0]["log"] = "측선에 버려진 탄수차에서 석탄을 퍼 왔다."
			choices[1]["log"] = "측선에 버려진 탄수차를 손대지 않고 지나쳤다."
		"sick_child":
			title = "아이 열병" if past.is_empty() else "열병이 번진다"
			var save: Array = [["rel", "tail", -(4 + 3 * n)], ["rel", "medtech", -2]]
			if pick == "med_save": save.append(["trust", -2])
			choices = [choice("med_use", "의약품을 쓴다", [["med", -3 if pick == "med_use" else -2], ["rel", "tail", 4], ["rel", "medtech", 2]]), choice("med_save", "아껴 둔다", save)]
			choices[0]["log"] = "열이 난 아이들에게 의약품을 썼다." if past.is_empty() else "번지는 열병에 의약품을 썼다."
			choices[1]["log"] = "아이들이 열이 나도 의약품은 아껴 뒀다." if past.is_empty() else "열병이 번져도 의약품은 아껴 뒀다."
		"ration_line":
			title = "배급 줄"
			var guard: Array = [["fear", 3], ["rel", "tail", -3], ["rel", "guard", 2]]
			if not past.is_empty(): guard.append(["tension", 2 * n])
			choices = [choice("reshare", "다시 나눈다", [["food", -(4 + n)], ["rel", "tail", 3]]), choice("guard_line", "경비대를 세운다", guard)]
			choices[0]["log"] = "빵이 떨어진 배급 줄 끝까지 다시 나눴다."
			choices[1]["log"] = "배급 줄 옆에 경비대를 세웠다."
		"guard_frost":
			title = "동상"
			var frost: bool = TrainClimate.holds(g, t, "frost")
			choices = [choice("guard_heat", "경비대 난방을 올린다", [["lever", "guard", "heat", 1], ["rel", "guard", 3]]), choice("watch_less", "경계를 줄인다", [["rel", "guard", 2], ["tension", 2 + n]]), choice("hold_post", "그대로 선다", [["rel", "guard", -(5 + 4 * n)], ["injured", 1]])]
			choices[0]["log"] = "보초가 동상을 입어 경비칸 난방을 올렸다." if frost else "보초가 찬비에 젖어 경비칸 난방을 올렸다."
			choices[1]["log"] = "보초가 동상을 입어 지붕 경계를 줄였다." if frost else "보초가 찬비에 젖어 지붕 경계를 줄였다."
			choices[2]["log"] = "보초가 동상을 입었어도 경계는 줄이지 않았다." if frost else "보초가 찬비에 젖었어도 경계는 줄이지 않았다."
		_: return {}
	return {"title": title, "key": id, "choices": choices}

static func view(g: Dictionary, t: Dictionary, card: Dictionary) -> Dictionary:
	return Trip.filter_view(g, card, Late.view(g, card, _base_view(g, t, card)))


static func _base_view(g: Dictionary, t: Dictionary, card: Dictionary) -> Dictionary:
	if card["kind"] in ["trip_depart", "trip_return", "trip_lost", "trip_extend"]: return Trip.view(g, t, card)
	if card["kind"] in ["content", "content-deal"]: return Content.content_view(g, t, card)
	var comm: String = card.get("comm", "tail")
	var s: Dictionary = g["comms"][comm]
	match str(card["kind"]):
		"travel": return travel_view(g, t, card.get("text", ""))
		"info": return {"title": str(card.get("who", "알림")), "choices": [choice("", "알았다", [])]}
		"need_warn":
			if not t["NEEDS"].has(card.get("text")): return {}
			var def: Dictionary = t["NEEDS"][card["text"]]
			var promise: Dictionary = choice("", "약속한다", [], "need_promise")
			promise["log"] = "%s을 정하겠다고 약속했다." % def["title"]
			var options: Array = [promise, choice("", "두고 본다", [])]
			options[1]["log"] = "%s은(는) 두고 보기로 했다." % def["title"]
			return {"title": "%s이 필요하다" % def["title"], "choices": options}
		"demand":
			var sit: Array = St.situation(g, t, comm)
			if comm == "engine" and float(sit[3]) > 50:
				var past: Dictionary = g.get("eventLog", {}).get("demand:engine_shift", {})
				var n: int = mini(int(past.get("n", 0)), 3)
				var shifts: Array = [choice("shift_more", "교대를 늘린다", [["coal", -float(t["P"]["shiftCoal"])], ["base", "engine", 3, -float(t["P"]["shiftRelief"])], ["rel", "engine", 3]]), choice("shift_apprentice", "견습생을 붙인다", [["base", "engine", 3, -5], ["base", "tail", 3, 3], ["rel", "tail", -(2 + 2 * n)]]), choice("refuse", "거절한다", [["fervor", "engine", 1], ["rel", "engine", -(float(t["P"]["refuseRel"]) + 3 * n)]])]
				shifts[0]["log"] = "화부들의 요구대로 교대를 늘렸다." if past.is_empty() else "다시 온 화부들의 요구대로 교대를 늘렸다."
				shifts[1]["log"] = "화부들에게 꼬리칸 견습생을 붙였다." if past.is_empty() else "다시 온 화부들에게 꼬리칸 견습생을 붙였다."
				shifts[2]["log"] = "화부 교대 요구를 거절했다." if past.is_empty() else "다시 온 화부들의 교대 요구를 거절했다."
				return {"title": "화부 교대" if past.is_empty() else "화부 교대, 다시", "key": "demand:engine_shift", "choices": shifts}
			var which: String = "ration" if float(s["heat"]) >= 4 else ("heat" if float(s["ration"]) >= 4 or float(sit[0]) < float(sit[1]) else "ration")
			var past: Dictionary = g.get("eventLog", {}).get("demand:" + comm, {})
			var n: int = mini(int(past.get("n", 0)), 3) if past.get("pick") == "refuse" else 0
			var options: Array = [choice("heat_up" if which == "heat" else "ration_up", "난방을 올린다" if which == "heat" else "배급을 올린다", [["lever", comm, which, 1], ["rel", comm, 2]]), choice("refuse", "거절한다", [["fervor", comm, 1], ["rel", comm, -(float(t["P"]["refuseRel"]) + 3 * n)]])]
			options[0]["log"] = ("%s의 요구대로 난방을 올렸다." if which == "heat" else "%s의 요구대로 배급을 올렸다.") % t["COMM_NAME"][comm]
			options[1]["log"] = ("%s의 난방 요구를 거절했다." if which == "heat" else "%s의 배급 요구를 거절했다.") % t["COMM_NAME"][comm]
			return {"title": "난방 요구" if which == "heat" else "배급 요구", "key": "demand:" + comm, "choices": options}
		"favor":
			var again: bool = g.get("eventLog", {}).has("favor:" + comm)
			var costs: Dictionary = {"tail": [["med", -2], ["base", "medtech", 2, 3]], "medtech": [["rel", "front", -3]] if again else [["base", "front", 2, 3]], "guard": [["rel", "engine", -2], ["rel", "tail", -1]] if again else [["rel", "engine", -2]], "front": [["lux", -3 if again else -2]], "engine": [["rel", "tail", -3 if again else -2]]}
			var cost: Array = costs[comm]
			cost.append(["debt", comm])
			var options: Array = [choice("grant", "들어준다", cost, "favor_risk"), choice("refuse", "거절한다", [["rel", comm, -4 if again else -3]])]
			options[0]["log"] = "%s의 사적인 부탁을 들어줬다." % s["leader"]["name"]
			options[1]["log"] = "%s의 사적인 부탁을 거절했다." % s["leader"]["name"]
			return {"title": "사적인 부탁", "key": "favor:" + comm, "choices": options}
		"rescue":
			var options: Array = []
			if g["passed"].has("no_outsiders"):
				options = [choice("leave_law", "법대로 두고 온다", [["trust", -1]], "", true)]
				options[0]["log"] = "부상자를 법대로 두고 왔다."
			else:
				var past: Dictionary = g.get("eventLog", {}).get("rescue", {})
				var n: int = mini(int(past.get("n", 0)), 3) if past.get("pick") == "leave" else 0
				options = [choice("take_in", "데려온다", [["pop", "tail", 2], ["base", "tail", 2, 3], ["injured", 1], ["rel", "medtech", 3]], "", true), choice("supplies_only", "물자만 받는다", [["food", 3], ["trust", -1], ["rel", "medtech", -3]], "", true), choice("leave", "두고 온다", [["trust", -(1 + n)], ["rel", "medtech", -3]], "", true)]
				options[0]["log"] = "부상자를 열차에 태웠다."
				options[1]["log"] = "부상자는 태우지 않고 물자만 받았다."
				options[2]["log"] = "부상자를 두고 왔다."
			return {"title": "부상자", "key": "rescue", "choices": options}
		"bitten":
			var part: String = ["팔을", "다리를", "손을"][int(card["uid"]) % 3]
			var who: String = str(card.get("who", "대원"))
			var options: Array = [choice("cut", part + " 자른다", [["med", -3], ["injured", 1], ["rel", comm, 2]], "", true), choice("hide", "숨겨 준다", [], "hide_bite", true), choice("leave", "두고 온다", [["rel", comm, -8], ["tension", 2]], "leave_bitten", true)]
			options[0]["log"] = "물린 %s의 %s 잘랐다." % [who, part]
			options[1]["log"] = "물린 %s을(를) 숨겨 태웠다." % who
			options[2]["log"] = "물린 한 명을 남기고 왔다."
			return {"title": "물렸다", "key": "bitten", "choices": options}
		"ration_cut":
			# The tail's demand after 비상식량감축법 stands (결정 091·430, turn_ration_cut.gd).
			var k: Dictionary = t["RATION_CUT"]
			var options: Array = [
				choice("cut_spare_tail", "꼬리칸은 뺀다", [["rel", "tail", k["spareRel"]["tail"]], ["rel", "front", k["spareRel"]["front"]]], "cut_spare_tail"),
				choice("cut_front_first", "앞칸이 먼저 낸다", [["rel", "tail", k["frontRel"]["tail"]], ["rel", "front", k["frontRel"]["front"]]], "cut_front_first"),
				choice("refuse", "거절한다", [["rel", "tail", k["refuseRel"]], ["tension", k["refuseTension"]]], "cut_refuse")]
			options[0]["log"] = "배급 감축에서 꼬리칸은 뺐다."
			options[1]["log"] = "앞칸이 배급을 한 단 더 줄이게 했다."
			options[2]["log"] = "배급 감축에 예외를 두지 않았다."
			return {"title": "감축 배급 요구", "key": "ration_cut", "choices": options}
		"promise_ledger":
			# The result arc (council_log.gd): a second broken promise brings the car's ledger; a third closes open deals.
			var options: Array = [choice("", "사과하고 갚는다", [["lux", -3], ["rel", comm, 8]]), choice("", "물리친다", [["rel", comm, -5]], "ledger_refuse")]
			options[0]["log"] = "어긴 약속을 %s에 사과하고 갚았다." % t["COMM_NAME"][comm]
			options[1]["log"] = "%s이(가) 내민 약속 장부를 물리쳤다." % t["COMM_NAME"][comm]
			return {"title": "약속 장부", "choices": options}
		"tension_crisis":
			# The ladder's last rung (정치 흐름 4.2): guard, yield, or nothing (nothing ends the board in revolt).
			var refused: Variant = Ladder.guard_refuses(g)
			var hold: Dictionary = choice("", "경비대를 푼다", [["fear", 15], ["trust", -10], ["rel", "tail", -10]], "crisis_guard")
			if refused != null: hold["disabled"] = refused
			var options: Array = [hold, choice("", "창고를 연다", [["food", -15], ["coal", -10], ["rel", "tail", 8]], "crisis_yield"), choice("", "아무것도 안 한다", [], "revolt")]
			options[0]["log"] = "통로를 막은 사람들 앞에 경비대를 풀었다."
			options[1]["log"] = "창고를 열어 식량과 석탄을 풀었다."
			options[2]["log"] = "통로가 막혀도 아무것도 하지 않았다."
			return {"title": "마지막 기회", "choices": options}
		"protest":
			var refused: Variant = Ladder.guard_refuses(g)
			var opp: String = t["OPPOSITE"]["tail"]
			if card.get("text") != "riot":
				var hold: Dictionary = choice("", "경비대를 세운다", [["tension", -6]], "ladder_guard")
				if refused != null: hold["disabled"] = refused
				var options: Array = [choice("", "들어준다", [["food", -8], ["coal", -5], ["tension", -10], ["rel", "tail", 3], ["rel", opp, -3]], "ladder_yield"), hold, choice("", "물리친다", [["rel", "tail", -5]], "ladder_ignore")]
				options[0]["log"] = "항의를 듣고 식량과 석탄을 나눠 줬다."
				options[1]["log"] = "항의하는 사람들 앞 통로에 경비를 세웠다."
				options[2]["log"] = "통로에 모인 사람들의 항의를 물리쳤다."
				return {"title": "항의", "choices": options}
			var hold_riot: Dictionary = choice("", "경비대를 푼다", [["fear", 8], ["trust", -5], ["rel", "tail", -5]], "riot_guard")
			if refused != null: hold_riot["disabled"] = refused
			var riot_options: Array = [choice("", "들어준다", [["food", -10], ["coal", -6], ["tension", -10], ["rel", "tail", 4], ["rel", opp, -3]], "riot_yield"), hold_riot, choice("", "아무것도 안 한다", [], "ladder_ignore")]
			riot_options[0]["log"] = "난장판이 된 칸의 요구를 들어줬다."
			riot_options[1]["log"] = "싸움을 말리려 경비대를 풀었다."
			riot_options[2]["log"] = "싸움이 번지는 동안 아무것도 하지 않았다."
			return {"title": "난장판", "choices": riot_options}
		"keepsake":
			# S1 cards.ts keepsake (사람의 무게 A1(나)): the dead's coat and boots. One who died at a stop
			# (text "field") left only the spare under the bunk.
			var dead: String = str(card.get("who", ""))
			var field: bool = card.get("text") == "field"
			var keep: Array = [choice("", "그 칸에 나눈다", [["base", comm, 0, 2], ["rel", comm, 2]], "keep_share")]
			keep[0]["log"] = "%s의 외투와 장화를 그 칸에 나눴다." % dead
			if comm != "tail":
				keep.append(choice("", "꼬리칸에 보낸다", [["base", "tail", 0, 2], ["rel", comm, -3]], "keep_tail"))
				keep[1]["log"] = "%s의 외투와 장화를 꼬리칸에 보냈다." % dead
			keep.append(choice("", "그대로 둔다" if field else "함께 보낸다", [["rel", comm, 4]]))
			keep[-1]["log"] = ("%s의 침상 밑 여벌은 그대로 뒀다." if field else "%s을(를) 보낼 때 외투와 장화도 함께 보냈다.") % dead
			return {"title": "외투와 장화", "choices": keep}
		"dom:short":
			# S1 domestic/cards.ts dom:short (its upkeep half, train_research.gd pay_upkeep raises it).
			var options: Array = [choice("", "하나를 세운다", [], "dom_short_stand"),
				choice("", "그냥 달린다", [], "dom_short_go"), choice("", "목표치 +3", [], "dom_short_target")]
			options[0]["log"] = "부품을 돌리려 기술 하나를 세우기로 했다."
			options[1]["log"] = "부품이 모자라도 그대로 달리기로 했다."
			options[2]["log"] = "부품 목표치를 높이기로 했다."
			return {"title": "부품이 모자란다", "key": "dom:short", "choices": options}
		"strike_warn":
			# S1 cards.ts strike_warn: the engine warns before the fire goes out (turn_settle.gd raises it).
			var options: Array = [choice("", "교대를 늘린다", [["coal", -float(t["P"]["shiftCoal"])], ["base", "engine", 3, -float(t["P"]["shiftRelief"])], ["rel", "engine", 6]]),
				choice("", "기관실 배급 +1", [["lever", "engine", "ration", 1], ["rel", "engine", 5], ["rel", "medtech", -2]]), choice("", "듣기만 한다", [["rel", "engine", -3]])]
			options[0]["log"] = "불을 끄겠다는 화부들의 경고에 교대를 늘렸다."
			options[1]["log"] = "불을 끄겠다는 화부들의 경고에 기관실 배급을 올렸다."
			options[2]["log"] = "불을 끄겠다는 화부들의 경고를 듣기만 했다."
			return {"title": "파업 경고", "choices": options}
		"strike":
			# S1 cards.ts strike: the train stands at the engine's door (turn_travel.gd raises it).
			var options: Array = [choice("", "요구를 들어준다", [["lever", "engine", "ration", 1], ["fervor", "engine", -1], ["fervor", "medtech", 1], ["rel", "engine", 12]]),
				choice("", "교대를 늘린다", [["coal", -float(t["P"]["shiftCoal"])], ["base", "engine", 3, -float(t["P"]["shiftRelief"])], ["fervor", "engine", -1], ["rel", "engine", 8]]),
				choice("", "수석 기관사를 산다", [["lux", -3]], "strike_bribe"), choice("", "버틴다", [["tension", 3]])]
			options[0]["log"] = "기관실 문 앞에 앉은 화부들의 요구를 받아들였다."
			options[1]["log"] = "파업한 화부들의 교대를 늘렸다."
			options[2]["log"] = "파업 중에 수석 기관사를 따로 불러 사치품을 쥐여 줬다."
			options[3]["log"] = "화부들의 파업에 굽히지 않고 버텼다."
			return {"title": "파업", "choices": options}
		"pro_deal":
			# S1 prologue.ts pro_deal: the tail's first ask past the lakes; a kept depot promise asks only the stove.
			var kept: bool = g.get("story", {}).get("flags", {}).get("depot_promise") == "kept"
			var yes: Dictionary = choice("", "들어준다", [], "pro_deal_yes")
			yes["extra"] = ["꼬리칸 난방 레버 +1" if kept else "꼬리칸 난방 레버 +1 · 배급 레버 +1"]
			yes["log"] = "꼬리칸 난로에 석탄을 한 삽 더 넣어 줬다." if kept else "꼬리칸 난로에 석탄 한 삽과 배급 한 국자를 더 줬다."
			var options: Array = [yes, choice("", "거절한다", [["rel", "tail", t["PROLOGUE"]["dealRefuseRel"]]], "pro_deal_no")]
			options[1]["log"] = "꼬리칸 난로에 석탄 한 삽을 더 달라는 청을 거절했다." if kept else "꼬리칸이 값으로 청한 석탄과 배급을 거절했다."
			return {"title": "열차 안 첫 거래", "choices": options}
		"leash":
			return {"title": "목줄이 끊겼다", "choices": [choice("", "알았다", [])]}
		"bite_found":
			# S1 cards.ts bite_found: a hidden bite shows (turn_settle.gd) and is too late to cut; a bite
			# from a corpse kept in the car (text "corpse") can still be cut while its window is open.
			if card.get("text") == "corpse":
				var bite: Dictionary = {}
				for b: Dictionary in g.get("hiddenBites", []):
					if b.get("who") == card.get("who"):
						bite = b
						break
				var cut: Dictionary = choice("", "의무칸에서 자른다", [["med", -3], ["injured", 1]], "bite_cut")
				if bite.is_empty() or int(g["seg"]) > int(bite["at"]): cut["disabled"] = "감염 창이 닫혔다"
				var corpse_choices: Array = [cut, choice("", "따로 눕힌다", [["tension", 2]], "bite_isolate"), choice("", "쏜다", [["fear", 3], ["rel", comm, -3]], "bite_shoot", true)]
				corpse_choices[0]["log"] = "시신에 물린 %s의 물린 곳을 의무칸에서 잘랐다." % str(card.get("who", "그 사람"))
				corpse_choices[1]["log"] = "시신에 물린 %s을(를) 따로 눕혔다." % str(card.get("who", "그 사람"))
				corpse_choices[2]["log"] = "시신에 물린 %s을(를) 쐈다." % str(card.get("who", "그 사람"))
				return {"title": "시신에게 물렸다", "key": "bite_corpse", "choices": corpse_choices}
			var bite_choices: Array = [choice("", "따로 눕힌다", [["trust", -5], ["tension", 2]], "bite_isolate"),
				choice("", "쏜다", [["trust", -5], ["fear", 3], ["rel", comm, -3]], "bite_shoot", true)]
			bite_choices[0]["log"] = "물림이 드러난 %s을(를) 따로 눕혔다." % str(card.get("who", "대원"))
			bite_choices[1]["log"] = "물림이 드러난 %s을(를) 쐈다." % str(card.get("who", "대원"))
			return {"title": "숨긴 물림이 드러났다", "key": "bite_found", "choices": bite_choices}
		"orphan":
			# S1 cards.ts orphan (사람의 무게 A1(가)): a parent who left children died. A living other
			# parent raises them; the rest of the ways ease that parent's hands.
			var f: Dictionary = People.family(g, t, str(card.get("who", "")))
			var other: Dictionary = {}
			for o: Dictionary in f.get("others", []):
				if f["fam"]["parents"].has(o["id"]):
					other = o
					break
			var oc: String = String(other.get("community", comm))
			var ways: Array = [choice("", "곁의 부모가 키운다", [["base", oc, 1, -1], ["rel", oc, 2]], "orphan_parent")] if not other.is_empty() else [choice("", "같은 칸이 돌본다", [["base", comm, 1, -2]], "orphan_same")]
			ways[0]["log"] = "남은 아이를 %s이(가) 키우고 칸이 돕게 했다." % other["name"] if not other.is_empty() else "남은 아이를 같은 칸이 함께 키우게 했다."
			if comm != "front":
				ways.append(choice("", "앞칸 집에 맡긴다", [["base", "front", 2, 1], ["rel", comm, 4], ["rel", "front", -4]], "orphan_front"))
				ways[-1]["log"] = "남은 아이를 밤마다 앞칸 빈 침대에서 재우게 했다."
			if comm != "medtech":
				ways.append(choice("", "의무칸에 둔다", [["base", "medtech", 3, 2], ["rel", "medtech", -2], ["trust", 1]], "orphan_med"))
				ways[-1]["log"] = "남은 아이를 의무진에게 맡겼다."
			return {"title": "남은 아이", "choices": ways}
		"elder":
			# S1 cards.ts elder (사람의 무게 A3): the old one chose to get off; the captain picks no one.
			var options: Array = [choice("", "붙잡는다", [["rel", comm, 3]], "elder_hold"),
				choice("", "보내 준다", [["pop", comm, -1], ["rel", comm, -5], ["trust", -2]], "elder_leave", true),
				choice("", "작별을 치른다", [["pop", comm, -1], ["lux", -1], ["tension", -3], ["rel", comm, 2]], "elder_leave")]
			options[0]["log"] = "다음 역에서 내리겠다던 %s을(를) 붙잡았다." % str(card.get("who", "노인"))
			options[1]["log"] = "내리겠다던 %s을(를) 막지 않고 보내 줬다." % str(card.get("who", "노인"))
			options[2]["log"] = "모두 모여 %s의 작별을 치렀다." % str(card.get("who", "노인"))
			return {"title": "내리겠다는 노인", "choices": options}
		"birth":
			# S1 cards.ts birth (사람의 무게 A4): a child born where it stays under BIRTH.warm comes small.
			var cold: bool = float(St.situation(g, t, comm)[0]) < float(t["BIRTH"]["warm"])
			var options: Array = [choice("", "의무칸으로 데려간다", [["med", -2], ["base", "medtech", 3, 2]], "birth_ok"),
				choice("", "그 칸에서 낳는다", [], "birth_weak" if cold else "birth_ok")]
			options[0]["log"] = "해산을 앞둔 %s을(를) 의무칸으로 데려갔다." % str(card.get("who", ""))
			options[1]["log"] = "%s이(가) 그 칸에서 아이를 낳게 했다." % str(card.get("who", ""))
			return {"title": "아이가 나온다", "choices": options}
		"naming":
			var mine: Dictionary = choice("", "내 이름을 준다", [["trust", 3], ["rel", "medtech", -2], ["rel", "tail", -2]])
			mine["log"] = "아이에게 열차장의 이름을 주었다."
			var options: Array = [choice("", "엄마가 짓는다", [["rel", comm, 3]]), choice("", "열차 이름을 준다", [], "name_train"), mine]
			options[0]["log"] = "아이의 이름은 엄마가 짓게 뒀다."
			options[1]["log"] = "아이에게 열차의 이름을 줬다."
			return {"title": "아이의 이름", "choices": options}
		"rep_sick":
			var sick: bool = s.get("sick") is Dictionary
			var rep: String = String(s["sick"]["rep"]["name"]) if sick else String(s["leader"]["name"])
			var options: Array = [choice("", "약을 보낸다", [["med", -2], ["rel", comm, 3]], "rep_heal"), choice("", "측근을 만난다", [], "proxy_meet"), choice("", "그냥 둔다", [])] if sick else [choice("", "알았다", [])]
			if sick:
				options[0]["log"] = "앓는 %s에게 의무진의 약을 보냈다." % rep
				options[1]["log"] = "%s 대신 나온다는 측근을 만났다." % rep
				options[2]["log"] = "앓는 %s을(를) 그냥 뒀다." % rep
			else:
				options[0]["log"] = "%s이(가) 앓다가 일어났다." % rep
			return {"title": "대표가 앓는다", "choices": options}
	return {}

static func affordable(g: Dictionary, effs: Array) -> bool:
	for e: Array in effs:
		if e[0] in ["coal", "food", "med", "lux"] and float(e[1]) < 0 and float(g[e[0]]) < -float(e[1]): return false
		if e[0] == "lever" and float(e[3]) > 0 and float(g["comms"][e[1]][e[2]]) >= 4: return false
	return true

static func apply_effects(g: Dictionary, t: Dictionary, effs: Array, from: String, comm: String) -> void:
	for e: Array in effs:
		var kind: String = e[0]
		match kind:
			"coal", "food", "med", "lux", "trust", "tension": C.bump(g, kind, float(e[1]), "card", kind in ["med", "lux"])
			"fear": g["fear"] = clampf(float(g["fear"]) + float(e[1]), 0, 100)
			"injured":
				var before: int = int(g["injured"])
				g["injured"] = maxi(0, before + int(e[1]))
				if int(g["injured"]) > before: W.note_injury(g, t, int(g["injured"]) - before, from, "카드", {"comm": comm})
				else: W.note_relief(g, before - int(g["injured"]))
			"rel": C.bump_rel(g, e[1], float(e[2]), "card")
			"fervor": g["comms"][e[1]]["fervor"] = clampf(float(g["comms"][e[1]]["fervor"]) + float(e[2]), 0, 3)
			"pop": g["comms"][e[1]]["pop"] = maxi(1, int(g["comms"][e[1]]["pop"]) + int(e[2]))
			"base": g["comms"][e[1]]["base"][int(e[2])] += float(e[3])
			"lever": g["comms"][e[1]][e[2]] = clampf(float(g["comms"][e[1]][e[2]]) + float(e[3]), 0, 4)
			"debt": g["comms"][e[1]]["debt"] = true
			"grudge": Field._offend(g, e[1])

static func choose(g0: Dictionary, t: Dictionary, uid: int, index: int) -> Dictionary:
	# Trip views may consume pending lamp/snow flags, just as S1 tripPlan does.
	g0 = g0.duplicate(true)
	var card: Dictionary = {}
	for row: Dictionary in g0["cards"]:
		if int(row["uid"]) == uid:
			card = row
			break
	if card.is_empty(): return g0.duplicate(true)
	var v: Dictionary = view(g0, t, card)
	if v.is_empty(): return C.unsupported(g0, "chooseCard: " + str(card["kind"]))
	if index < 0 or index >= v["choices"].size(): return g0.duplicate(true)
	var selected: Dictionary = v["choices"][index]
	# Content.view already applies S1 guardCosts, including its all-unaffordable escape.
	if selected.has("disabled") or (card["kind"] not in ["content", "content-deal"] and not affordable(g0, selected["effs"])): return g0.duplicate(true)
	if not St.is_s1a(g0) or g0.get("deathWeight", false): return C.unsupported(g0, "chooseCard: optional hooks")
	if selected["special"] == "late":
		if int(card.get("late", 0)) < int(Late.LATE.max):
			var next: Dictionary = g0.duplicate(true)
			next["cards"] = next["cards"].filter(func(row: Dictionary) -> bool: return int(row["uid"]) != uid)
			Budget.pick(next)
			apply_effects(next, t, selected["effs"], "stop", "")
			var held: Dictionary = card.duplicate(true)
			held["late"] = int(card.get("late", 0)) + 1
			if card["kind"] == "favor" and card.get("who") == null: held["who"] = next["comms"][Late.comm(card)]["leader"]["personId"]
			if not next.has("lateCards"): next["lateCards"] = []
			next["lateCards"].append(held)
			Budget.pass_cards(next, t)
			return next
		var line: String = Late.log_line(g0, t, card)
		var expired: Dictionary = _resolve_choice(g0, t, card, v, Late.worst_choice(v["choices"], Late.comm(card)))
		apply_effects(expired, t, selected["effs"], "stop", "")
		C.journal(expired, line, "bad")
		return expired
	return _resolve_choice(g0, t, card, v, selected)


## Ordinary answers and expiry share effects, special handling, memory and journal order.
static func _resolve_choice(g0: Dictionary, t: Dictionary, card: Dictionary, v: Dictionary, selected: Dictionary) -> Dictionary:
	var uid: int = int(card["uid"])
	var g: Dictionary = g0.duplicate(true)
	g["cards"] = g["cards"].filter(func(row: Dictionary) -> bool: return int(row["uid"]) != uid)
	Budget.pick(g)
	var sources: Dictionary = {"let_be": "brawl", "hold_post": "guard_post", "take_in": "rescue", "cut": "bite_cut"}
	var from: String = sources.get(selected["id"], "bite_cut" if selected["special"] == "bite_cut" else "stop")
	apply_effects(g, t, selected["effs"], from, str(card["comm"]) if card.get("comm") != null else "")
	var comm: String = str(card["comm"]) if card.get("comm") != null else "tail"
	match str(selected["special"]):
		"revolt":
			# S1 cards.ts 'revolt': the end and its lookback only (the end words are the settle's finish).
			g["end"] = "revolt"
			g["phase"] = "end"
			load("res://game/train/train_turn.gd").write_lookback(g, t)
		"trip_go_crew", "trip_go_captain", "trip_fire", "trip_stay": Trip.choose(g, t, selected)
		"risk_injury":
			if C.rnd(g) < 0.3 + 0.15 * mini(int(g.get("eventLog", {}).get("abandoned_tender", {}).get("n", 0)), 3):
				g["injured"] += 1
				W.note_injury(g, t, 1, "tender", "탄수차", {"comm": comm})
				C.journal(g, "탄수차 그늘에서 무언가가 튀어나왔다. 한 사람이 다쳤다.", "bad")
		"favor_risk":
			g["comms"][comm]["favorCool"] = 4
			if C.rnd(g) < 0.15:
				for other: String in t["COMMS"]:
					if other != comm: C.bump_rel(g, other, -5, "leak")
				C.journal(g, "%s의 부탁을 들어준 게 알려졌다. 공정성 시비가 붙었다." % g["comms"][comm]["leader"]["name"], "bad")
		"hide_bite":
			if not g.has("hiddenBites"): g["hiddenBites"] = []
			g["hiddenBites"].append({"who": card.get("who", "이름 모를 대원"), "comm": comm, "at": g["seg"], "due": int(g["seg"]) + 2})
			C.journal(g, "%s의 상처를 붕대로 감아 태웠다. 아는 사람은 수색대뿐이다." % card.get("who", "대원"), "dark")
		"leave_bitten":
			Field._offend(g, comm)
			g["comms"][comm]["pop"] = maxi(1, int(g["comms"][comm]["pop"]) - 1)
			g["deaths"].append(card.get("who", "이름 모를 대원"))
			Death.log_death(g, [card.get("who", "이름 모를 대원")], "chosen", true, comm)
			# The journal keeps only the chosen line, counted, never named (결정 183; s1 the same).
		"need_promise":
			var need: Variant = g.get("needs", {}).get(card.get("text", ""))
			if need is Dictionary and not bool(need.get("promised", false)):
				need["promised"] = true
				need["due"] += 1
		"rep_heal": People.recover(g, t, comm, "의무진의 약을 먹고")
		"cut_spare_tail": RationCut.apply(g, t, "spare_tail")
		"cut_front_first": RationCut.apply(g, t, "front_first")
		"cut_refuse": RationCut.apply(g, t, "refuse")
		"proxy_meet": g["comms"][comm]["leader"]["traitShown"] = 2
		# S1 revertLater: the coat warms that car for two stretches (turn_people.gd tick takes it back).
		"keep_share", "keep_tail":
			if not g.has("tempBase"): g["tempBase"] = []
			g["tempBase"].append({"c": comm if selected["special"] == "keep_share" else "tail", "i": 0, "v": 2, "until": int(g["seg"]) + 2})
		"dom_short_stand": TrainResearch.stand_down(g)
		"dom_short_target": TrainWorkshop.set_target(g, TrainWorkshop.target(g) + 3)
		"strike_bribe":
			if C.rnd(g) < 0.25:
				C.bump_rel(g, "engine", -30, "leak")
				C.journal(g, "수석 기관사를 사려던 게 드러났다. 기관실이 등을 돌렸다.", "bad")
			elif C.rnd(g) < float(g["comms"]["engine"]["coh"]):
				g["comms"]["engine"]["fervor"] = 0
				C.bump_rel(g, "engine", 5, "card")
				C.journal(g, "수석 기관사가 화부들을 불 앞으로 돌려보냈다.", "dark")
			else: C.journal(g, "수석 기관사는 받았지만 화부들이 따르지 않았다.", "bad")
		"bite_cut":
			g["hiddenBites"] = g.get("hiddenBites", []).filter(func(b: Dictionary) -> bool: return b.get("who") != card.get("who"))
			C.journal(g, "%s%s의 물린 곳을 의무칸에서 잘랐다." % ["" if card.get("text") == "corpse" else "숨겼던 ", card.get("who", "대원")], "dark")
		"bite_isolate":
			for b: Dictionary in g.get("hiddenBites", []):
				if b.get("who") == card.get("who"): b["isolated"] = true
			C.journal(g, "%s을(를) 빈 칸 끝에 따로 두었다." % card.get("who", "대원"), "dark")
		"bite_shoot":
			g["hiddenBites"] = g.get("hiddenBites", []).filter(func(b: Dictionary) -> bool: return b.get("who") != card.get("who"))
			Death.on_death(g, t, comm, [card.get("who", "이름 모를 대원")], "chosen", true)
			C.journal(g, "%s을(를) 쏘았다. 칸 사람들이 다 들었다." % card.get("who", "대원"), "dark")
		"orphan_parent", "orphan_same", "orphan_front", "orphan_med":
			var f: Dictionary = People.family(g, t, str(card.get("who", "")))
			var parent_comm: String = comm
			for o: Dictionary in f.get("others", []):
				if f["fam"]["parents"].has(o["id"]):
					parent_comm = o["community"]
					break
			var sp: String = selected["special"]
			var to: String = "front" if sp == "orphan_front" else ("medtech" if sp == "orphan_med" else (parent_comm if sp == "orphan_parent" else comm))
			# Kept by the other parent's car or its own car, that car holds together a little more.
			if sp in ["orphan_parent", "orphan_same"]: g["comms"][to]["coh"] = clampf(float(g["comms"][to]["coh"]) + 0.05, 0, 1)
			for k: Dictionary in f.get("kids", []):
				if not g.has("raised"): g["raised"] = {}
				g["raised"][k["name"]] = to
		# S1 elder_leave: the pop effect already took the one who left; the name goes to the left.
		"elder_leave":
			if not g.has("left"): g["left"] = []
			g["left"].append(card.get("who", "노인"))
		# S1 elder_hold: held back, the old one may still get off alone at night (turn_people.gd elder_tick).
		"elder_hold":
			var held: Variant = card.get("who")
			if held is String and held != "": g["elderHeld"] = {"who": held, "comm": comm, "at": g["seg"], "until": int(g["seg"]) + int(t["ELDER_NIGHT"]["segs"])}
		"birth_ok":
			g["comms"][comm]["pop"] = int(g["comms"][comm]["pop"]) + 1
			for o: String in t["COMMS"]: C.bump_rel(g, o, 2, "birth")
			C.bump(g, "tension", -3, "birth")
			if g.get("born") is Dictionary: g["born"]["weak"] = false
			# S1 puts the naming paper first, past addCard.
			var named: Dictionary = {"uid": g["nextCardUid"], "kind": "naming", "comm": comm}
			if card.has("who"): named["who"] = card["who"]
			g["cards"].push_front(named)
			g["nextCardUid"] = int(g["nextCardUid"]) + 1
			C.journal(g, "%s의 아이가 태어났다. 열차가 잠깐 조용해졌다." % card.get("who", ""), "good")
		"birth_weak":
			g["comms"][comm]["pop"] = int(g["comms"][comm]["pop"]) + 1
			if g.get("born") is Dictionary:
				g["born"]["weak"] = true
				g["born"]["left"] = int(t["BIRTH"]["weakSegs"])
			C.journal(g, "%s의 아이가 작게 태어났다. 의무진이 의약품을 아껴 둔다." % card.get("who", ""), "bad")
		"name_train":
			for o: String in t["COMMS"]: g["comms"][o]["coh"] = clampf(float(g["comms"][o]["coh"]) + 0.02, 0, 1)
		# S1 prologue.ts prologueChoose: the levers go up as the tail asked (S1 setLever: the law floor to 4).
		"pro_deal_yes", "pro_deal_no":
			if selected["special"] == "pro_deal_yes":
				var kept: bool = g.get("story", {}).get("flags", {}).get("depot_promise") == "kept"
				var tail: Dictionary = g["comms"]["tail"]
				tail["heat"] = int(clampf(float(tail["heat"]) + 1, float(St.law_floor(g, t, "heatFloor")), 4))
				if not kept: tail["ration"] = int(clampf(float(tail["ration"]) + 1, float(St.law_floor(g, t, "rationFloor")), 4))
				C.journal(g, "꼬리칸 난방을 한 칸 올렸다." if kept else "꼬리칸 난방과 배급을 한 칸씩 올렸다.", "deal")
			else: C.journal(g, "꼬리칸의 첫 청을 거절했다.", "bad")
			C.journal(g, "길잡이가 다시 말한다. 라이프치히 중앙역에 열차들이 모이고, 그 남쪽 땅엔 석탄이 묻혀 있다고.")
		"ledger_refuse": Field._offend(g, comm)
		"riot_guard":
			Ladder.riot_end(g, t)
			Ladder.riot_fell(g, t, int(t["P"]["riotFall"]))
			Ladder.guard(g, "tail")
		"riot_yield":
			Ladder.riot_end(g, t)
			Ladder.concede(g)
		"ladder_yield": Ladder.concede(g)
		"ladder_guard": Ladder.guard(g, "tail")
		"ladder_ignore": Ladder.ignore(g)
		"crisis_guard", "crisis_yield":
			C.put(g, "tension", float(t["P"]["crisisBase"]) + float(t["P"]["crisisStep"]) * int(g.get("tensionCrisisUsed", 0)), "card")
			g["tensionCrisisUsed"] = int(g.get("tensionCrisisUsed", 0)) + 1
			if selected["special"] == "crisis_guard": Ladder.guard(g, "tail")
			else: Ladder.concede(g)
	Content.content_choose(g, t, card, selected)
	# hub.ts registers hubChoose for every accepted card, including non-hub cards.
	var hub: Dictionary = C.hub(g)
	if not hub.has("lines"): hub["lines"] = []
	if not g.has("story"): g["story"] = {"stage": 1, "flags": {}}
	if not g["story"]["flags"].has("hub_split"): g["story"]["flags"]["hub_split"] = {}
	if v.has("key"):
		if not g.has("eventLog"): g["eventLog"] = {}
		var key: String = v["key"]
		g["eventLog"][key] = {"n": int(g["eventLog"].get(key, {}).get("n", 0)) + 1, "seg": g["seg"], "pick": selected["id"] if selected["id"] != "" else selected["label"], "st": Travel.event_state_key(g, t)}
	if not card["kind"] in ["info", "trust_crisis", "leash"]: C.journal(g, selected.get("log", "%s: %s." % [v["title"], selected["label"]]), "dark" if bool(selected["witness"]) else "")
	# S1 `g.stop?.crewComm`: a stop without its crew car has no witness to tell.
	var crew: Variant = g["stop"].get("crewComm") if g.get("stop") is Dictionary else null
	if bool(selected["witness"]) and crew is String and crew != "":
		var harsh: bool = selected["special"] in ["leave_bitten", "hide_bite"] or selected["id"] == "stay_put"
		for e: Array in selected["effs"]:
			if e[0] == "trust" and float(e[1]) < 0: harsh = true
		C.bump_rel(g, crew, -5 if harsh else 3, "card")
	Budget.pass_cards(g, t)
	return g
