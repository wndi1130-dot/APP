extends RefCounted
## The single special session after the first field return. Regular agenda options are supplied by
## the caller because the wider agenda generator is outside this port.

const FieldReturn = preload("res://game/politics/field_return.gd")
const CouncilVote = preload("res://game/politics/council_vote.gd")


static func _journal(g: Dictionary, text: String, tone: Variant = null) -> void:
	var row := {"seg": g["seg"], "text": text}
	if tone != null:
		row["tone"] = tone
	(g["journal"] as Array).append(row)


static func _same_agenda(a: Dictionary, b: Dictionary) -> bool:
	var law_a: bool = a.get("kind") != "motion"
	var law_b: bool = b.get("kind") != "motion"
	if law_a and law_b:
		return a.get("law") == b.get("law") and bool(a.get("repeal", false)) == bool(b.get("repeal", false))
	if not law_a and not law_b:
		return a.get("motion") == b.get("motion") and a.get("subject") == b.get("subject") and a.get("person") == b.get("person")
	return false


static func special_candidates(g: Dictionary, t: Dictionary, record: Dictionary, regular: Array) -> Array:
	var out: Array = []
	if not (record["dead"] as Array).is_empty():
		for agenda: Dictionary in regular:
			if agenda.get("kind") != "motion" and not bool(agenda.get("repeal", false)) and not bool(agenda.get("ratify", false)) and (t["CORPSE_LAWS"] as Array).has(agenda.get("law")):
				out.append({"agenda": agenda.duplicate(true), "from": "corpse"})
				break
	if record["symbol"] is Dictionary and record["symbol"].get("use") == "hang_before_session":
		out.append({
			"agenda": {
				"kind": "motion", "motion": "field_symbol", "subject": record["symbol"]["groupId"],
				"person": record["symbol"]["id"],
			},
			"from": "symbol",
		})
	var verdict: Variant = null
	for row: Dictionary in record["verdicts"]:
		if row["verdict"] == "broken":
			verdict = row
			break
	if verdict == null:
		for row: Dictionary in record["verdicts"]:
			if row["verdict"] != "unknown":
				verdict = row
				break
	if verdict is Dictionary:
		out.append({
			"agenda": {
				"kind": "motion", "motion": "field_promise", "subject": verdict["madeTo"],
				"person": verdict["id"], "verdict": verdict["verdict"],
			},
			"from": "promise",
		})
	for agenda: Dictionary in regular:
		if out.size() >= 3:
			break
		var duplicate := false
		for candidate: Dictionary in out:
			if _same_agenda(candidate["agenda"], agenda):
				duplicate = true
				break
		if not duplicate:
			out.append({"agenda": agenda.duplicate(true), "from": "regular"})
	if out.size() > 3:
		out.resize(3)
	return out


static func open_special_council(g0: Dictionary, t: Dictionary, regular: Array) -> Dictionary:
	var g := g0.duplicate(true)
	var field_returns: Variant = g.get("fieldReturns")
	if not field_returns is Dictionary or (field_returns.get("records", []) as Array).is_empty() or field_returns.has("special"):
		return {"record": null, "g": g}
	var record: Dictionary = field_returns["records"][0]
	if record["symbol"] is Dictionary and record["symbol"].get("use") == null:
		return {"record": null, "g": g}
	if g["phase"] == "council" or g["phase"] == "end":
		return {"record": null, "g": g}
	var base := {
		"receiptId": record["receiptId"], "seg": g["seg"], "back": g["phase"], "candidates": [],
	}
	if g.get("dark") is Dictionary and g["dark"].get("martial") != null:
		var skipped := base.duplicate(true)
		skipped["status"] = "skipped"
		skipped["why"] = "의회가 닫혀 있다"
		field_returns["special"] = skipped
		_journal(g, "첫 귀환을 두고 의회를 열 수 없다. 의회가 닫혀 있다.", "dark")
		return {"record": skipped, "g": g}
	g["session"] = int(g["session"]) + 1
	for comm: String in t["COMMS"]:
		g["comms"][comm]["lastOffense"] = int(g["comms"][comm]["lastOffense"]) + 1
	var candidates := special_candidates(g, t, record, regular)
	if candidates.is_empty():
		var skipped := base.duplicate(true)
		skipped["status"] = "skipped"
		skipped["why"] = "올릴 안건이 없다"
		field_returns["special"] = skipped
		_journal(g, "첫 귀환을 두고 의회를 불렀지만 올릴 안건이 없었다.")
		return {"record": skipped, "g": g}
	var options: Array = []
	var labels: Array = []
	for candidate: Dictionary in candidates:
		options.append(candidate["agenda"].duplicate(true))
		labels.append({"title": CouncilVote.agenda_title(t, candidate["agenda"]), "from": candidate["from"]})
	g["council"] = {
		"options": options, "idx": 0, "locked": false, "deals": [], "result": null,
		"emergency": true, "special": true,
	}
	var opened := base.duplicate(true)
	opened["status"] = "opened"
	opened["candidates"] = labels
	opened["before"] = FieldReturn.snapshot(g, t)
	field_returns["special"] = opened
	g["phase"] = "council"
	_journal(g, "첫 귀환을 두고 특별 회기를 연다. 안건 후보 %d개." % candidates.size())
	return {"record": opened, "g": g}


static func leave_special_council(g0: Dictionary, t: Dictionary) -> Dictionary:
	var g := g0.duplicate(true)
	var council: Variant = g.get("council")
	var special: Variant = g.get("fieldReturns", {}).get("special")
	if not council is Dictionary or not bool(council.get("special", false)) or g["phase"] != "council" or not special is Dictionary or special.get("status") != "opened" or council.get("result") == null:
		return {"left": false, "g": g}
	var result: Dictionary = council["result"]
	var agenda: Dictionary = council["options"][int(council["idx"])]
	special["picked"] = CouncilVote.agenda_title(t, agenda)
	special["result"] = {
		"yes": result["yes"], "no": result["no"], "need": result["need"], "passed": result["passed"],
	}
	special["after"] = FieldReturn.snapshot(g, t)
	g["phase"] = special["back"]
	return {"left": true, "g": g}


static func next_field_step(g0: Dictionary, t: Dictionary, regular: Array) -> Dictionary:
	var g := g0.duplicate(true)
	var field_returns: Variant = g.get("fieldReturns")
	if not field_returns is Dictionary or (field_returns.get("records", []) as Array).is_empty():
		return {"step": "done", "g": g}
	var record: Dictionary = field_returns["records"][0]
	if record["symbol"] is Dictionary and record["symbol"].get("use") == null:
		return {"step": "choose_symbol", "g": g}
	if not field_returns.has("special"):
		var opened := open_special_council(g, t, regular)
		return {"step": "council" if opened["record"] is Dictionary and opened["record"].get("status") == "opened" else "done", "g": opened["g"]}
	return {
		"step": "council" if g["phase"] == "council" and g.get("council") is Dictionary and bool(g["council"].get("special", false)) else "done",
		"g": g,
	}


static func special_reasons(g: Dictionary) -> Array:
	var field_returns: Variant = g.get("fieldReturns")
	if not field_returns is Dictionary or (field_returns.get("records", []) as Array).is_empty():
		return []
	var out: Array = []
	for line: Dictionary in field_returns["records"][0]["lines"]:
		if line["k"] == "promise" or line["k"] == "symbol":
			out.append(line.duplicate(true))
	return out
