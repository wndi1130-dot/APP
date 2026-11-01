extends RefCounted
## S1 budget.ts for the ported train rules. It stays off unless the state enables it.
const St = preload("res://game/train/train_state.gd")


static func grade(t: Dictionary, card: Dictionary) -> int:
	return int(t["CARD_GRADE"].get(card["kind"], {}).get("grade", 2))


static func _sync(g: Dictionary) -> void:
	if g["budget"]["seg"] != g["seg"]:
		g["budget"]["seg"] = g["seg"]
		g["budget"]["picked"] = 0


static func pick(g: Dictionary) -> void:
	if not g.get("budget") is Dictionary: return
	_sync(g)
	g["budget"]["picked"] += 1


static func _bump(g: Dictionary, key: String, gr: int) -> void:
	var stats: Dictionary = g["budget"]["stats"][key]
	stats[str(gr)] = int(stats.get(str(gr), 0)) + 1


static func _retire(g: Dictionary, t: Dictionary, card: Dictionary) -> void:
	var gr: int = grade(t, card)
	card["pushed"] = int(card.get("pushed", 0)) + 1
	if gr >= 5 and int(card["pushed"]) >= 2:
		_bump(g, "faded", gr)
		# Loaded only when retiring; the card module itself calls this budget.
		var view: Dictionary = load("res://game/train/turn/turn_cards.gd").view(g, t, card)
		g["journal"].append({"seg": g["seg"], "text": str(view.get("title", card["kind"])) + " 얘기는 흐지부지됐다."})
		return
	_bump(g, "deferred", gr)
	if not g.has("deferred"): g["deferred"] = []
	g["deferred"].append(card)


static func pass_cards(g: Dictionary, t: Dictionary) -> void:
	if not g.get("budget") is Dictionary: return
	_sync(g)
	while int(g["budget"]["picked"]) + g["cards"].size() > int(t["BUDGET"]["perSeg"]):
		var at: int = -1
		var worst: int = 2
		for i: int in g["cards"].size():
			var card: Dictionary = g["cards"][i]
			if g.get("lateOn", false) and int(card.get("late", 0)) > 0: continue
			if card.get("ask", false) and int(t["BUDGET"]["askExempt"]) != 0: continue
			var gr: int = grade(t, card)
			if gr >= 3 and gr >= worst:
				worst = gr
				at = i
		if at < 0: return
		var card: Dictionary = g["cards"][at]
		g["cards"].remove_at(at)
		_retire(g, t, card)


static func gone(g: Dictionary, t: Dictionary, card: Dictionary) -> bool:
	var c: String = str(card.get("comm") if card.get("comm") != null else "tail")
	var who: String = str(card.get("who") if card.get("who") != null else "")
	match str(card["kind"]):
		"orphan": return load("res://game/train/turn/turn_people.gd").family(g, t, who).get("kids", []).is_empty()
		"rep_sick": return g["comms"][c].get("sick") == null
		"elder": return who == "" or St.is_gone(g, who)
		"birth": return who == "" or St.is_gone(g, who) or g.get("born") == null
		"naming": return who == "" or St.is_gone(g, who) or (g.get("born") is Dictionary and bool(g["born"].get("lost", false)))
		"chain_push", "chain_fix": return not (g.get("deathChains", []) as Array).any(func(row: Dictionary) -> bool: return row["comm"] == c)
		"heat_after": return not St.law_active(g, "heat_quota")
		"demand":
			var s: Dictionary = g["comms"][c]
			var sit: Array = St.situation(g, t, c)
			return not (c == "engine" and float(sit[3]) > 50) and not ((float(s.heat) < 4 and float(sit[0]) < 45) or (float(s.ration) < 4 and float(sit[1]) < 45))
		"content":
			var vals: Dictionary = card["vals"] if card.get("vals") is Dictionary else {}
			for key: String in ["person", "person2", "@aide"]:
				if vals.get(key, "") != "" and St.is_gone(g, vals[key]): return true
		"dom:fit", "dom:fork": return g.get("dom") is Dictionary and g["dom"].get("techs", {}).has(card.get("text", ""))
	return false


static func _slot(card: Dictionary) -> String:
	var k: String = card["kind"]
	var text_key: String = ""
	if k == "dom:short": text_key = "break%s" % card.get("n", "undefined") if card.get("text") == "break" else "starved"
	elif k in ["travel", "content", "dom:fit", "dom:fork", "dom:pupil", "dom:manual", "disaster_prep"]: text_key = str(card.get("text") if card.get("text") != null else "")
	return "%s|%s|%s|%s" % [k, card.get("comm") if card.get("comm") != null else "", card.get("who") if card.get("who") != null else "", text_key]


static func on_add(g: Dictionary, t: Dictionary) -> void:
	if not g.get("budget") is Dictionary: return
	var card: Dictionary = g["cards"][-1] if not g["cards"].is_empty() else {}
	for old: Dictionary in g.get("deferred", []):
		if not card.is_empty() and _slot(old) == _slot(card):
			g["cards"].pop_back()
			if card.has("n"): old["n"] = card["n"]
			if card["kind"] == "dom:short" and card.has("text"): old["text"] = card["text"]
			return
	pass_cards(g, t)


static func next_segment(g: Dictionary, t: Dictionary) -> void:
	if not g.get("budget") is Dictionary: return
	if g["budget"]["seg"] == g["seg"]: return
	_sync(g)
	var back: Array = []
	for card: Dictionary in g.get("deferred", []):
		if gone(g, t, card): _bump(g, "dropped", grade(t, card))
		else: back.append({"card": card, "order": back.size()})
	g["deferred"] = []
	back.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ga: int = grade(t, a["card"])
		var gb: int = grade(t, b["card"])
		return ga < gb if ga != gb else int(a["order"]) < int(b["order"]))
	var cards: Array = back.map(func(row: Dictionary) -> Dictionary: return row["card"])
	var limit: int = int(t["BUDGET"]["returnMax"])
	g["cards"] = cards.slice(0, limit) + g["cards"]
	for card: Dictionary in cards.slice(limit): _retire(g, t, card)
	pass_cards(g, t)
