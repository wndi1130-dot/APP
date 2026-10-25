extends RefCounted
## S1a politics.ts agendaOptions. Input and tables are read-only.
## The returned options can be passed as field_council.gd's regular argument.

const State = preload("res://game/train/train_state.gd")
const Stop = preload("res://game/train/train_stop.gd")


static func same_agenda(a: Dictionary, b: Dictionary) -> bool:
	if a.get("kind") != "motion" and b.get("kind") != "motion":
		return a["law"] == b["law"] and a["repeal"] == b["repeal"]
	if a.get("kind") == "motion" and b.get("kind") == "motion":
		return a["motion"] == b["motion"] and a.get("subject") == b.get("subject") and a.get("person") == b.get("person")
	return false


static func _active(g: Dictionary, law: String) -> bool:
	return State.law_active(g, law)


static func law_open(g: Dictionary, t: Dictionary, law: String) -> bool:
	# 내정 훅 자리: domesticLawOpen. S1a에서는 내정 법을 열지 않는다.
	if (t["S1C_LAWS"] as Array).has(law) or (t["FAREWELL_LAWS"] as Array).has(law):
		return false
	match law:
		"seed_grain": return float(g["food"]) <= 50.0
		"emergency_ration": return float(g["food"]) <= 40.0 and not _active(g, "common_kitchen") and not _active(g, "contribution_ration")
		"common_kitchen", "contribution_ration": return not _active(g, "emergency_ration")
		"common_heating": return State.situation(g, t, "tail")[0] <= 40.0
		"heat_quota": return float(g["coal"]) <= 50.0
		"child_labor": return float(g["coal"]) <= 40.0 or float(g["food"]) <= 40.0
		"corpse_throw", "corpse_store", "corpse_burn": return bool(g["corpseIssue"])
		"triage": return float(g["med"]) <= 5.0 or int(g["injured"]) >= 6
		"no_outsiders": return State.situation(g, t, "tail")[2] >= 75.0
		"patrol": return float(g["tension"]) >= 40.0
		"emergency_powers": return float(g["tension"]) >= 50.0 or float(g["trust"]) <= 10.0 or g.get("trustCrisis") != null
		"strike_ban": return int(g["strikes"]) > 0
		"night_of_names": return not (g["deaths"] as Array).is_empty()
		"guided_voting": return int(g["session"]) >= 3
	return true


static func crisis_now(g: Dictionary, t: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if float(g["coal"]) < float(t["P"]["crisisLine"]): out.append("coal")
	if float(g["food"]) < float(t["P"]["crisisLine"]): out.append("food")
	if bool(g["corpseIssue"]): out.append("corpse")
	if float(g["med"]) <= 3.0 and int(g["injured"]) >= 4: out.append("med")
	return out


static func drains(t: Dictionary, law: String) -> Array[String]:
	var res: Dictionary = t["LAWS"][law]["res"]
	var out: Array[String] = []
	if float(res.get("rationFloor", 0)) != 0.0: out.append("food")
	if float(res.get("heatFloor", 0)) != 0.0: out.append("coal")
	if float(res.get("medMult", 1)) > 1.0: out.append("med")
	return out


static func _needed(g: Dictionary, t: Dictionary, option: Dictionary) -> bool:
	if bool(option["repeal"]): return false
	var needs: Dictionary = g.get("needs", {})
	for id: String in t["NEED_IDS"]:
		if needs.get(id) != null and t["LAWS"][option["law"]]["group"] == t["NEEDS"][id]["group"]:
			return true
	return false


static func _contains(options: Array, option: Dictionary) -> bool:
	for existing: Dictionary in options:
		if same_agenda(existing, option): return true
	return false


static func _depart_share(g: Dictionary, t: Dictionary, comm: String) -> float:
	var s: Dictionary = g["comms"][comm]
	var h: Dictionary = t["HUB"]
	var rel: float = float(s["rel"])
	var share: float = float(h["share"][2] if rel <= -70.0 else h["share"][1] if rel <= -40.0 else h["share"][0] if rel <= -15.0 else 0.0)
	if int(s["grudge"]) >= 2: share += float(h["grudgeAdd"])
	share = minf(float(h["cap"]), share)
	if share > 0.0 and float(s["coh"]) < float(h["cohLump"]):
		var fixed: float = float(Stop.hash_text("%s|hub|w|%s" % [g["seed"], comm])) / 4294967296.0
		share = clampf(share + (fixed * 2.0 - 1.0) * float(h["wobble"]), 0.0, float(h["cap"]))
	return floorf(share * 100.0 + 0.5) / 100.0


static func agenda_options(g: Dictionary, t: Dictionary) -> Dictionary:
	# S1a only; the slice's domestic stores (train_dom.gd, stocks only) are still S1a (train_state.gd is_s1a).
	assert(State.is_s1a(g), "agenda_options: S1a only")
	var options: Array = []
	var corpse_set: bool = false
	for corpse: String in t["CORPSE_LAWS"]:
		corpse_set = corpse_set or _active(g, corpse)
	for law: String in t["LAW_IDS"]:
		if _active(g, law) or not law_open(g, t, law): continue
		if (t["CORPSE_LAWS"] as Array).has(law) and corpse_set: continue
		if int(g["session"]) - int(g["repealedAt"].get(law, -99)) <= int(t["P"]["repealCool"]): continue
		var option: Dictionary = {"law": law, "repeal": false}
		var base: Variant = t["LAW_VARIANT_OF"].get(law)
		if base != null and _active(g, str(base)): option["amend"] = base
		options.append(option)
	for law: String in t["LAW_IDS"]:
		if _active(g, law) and int(g["session"]) - int(g["passed"][law]) > int(t["P"]["repealCool"]) and not (t["FAREWELL_LAWS"] as Array).has(law):
			options.append({"law": law, "repeal": true})
	var merged: Array = []
	for law: String in g.get("ratify", []):
		if _active(g, law): merged.append({"law": law, "repeal": false, "ratify": true})
	for law: String in g.get("ratifyRepeal", []):
		if not _active(g, law): merged.append({"law": law, "repeal": true, "ratify": true})
	# S1a motionsNow has only the final-station share motions (crisis rank).
	# 내정 훅 자리: pipe motion source.
	for proposal: Dictionary in g["proposals"]:
		if proposal.get("kind") == "motion" or _contains(options, proposal) or (bool(proposal.get("repeal", false)) and bool(proposal.get("promise", false)) and _active(g, str(proposal["law"]))):
			merged.append(proposal.duplicate(true))
	for needed: bool in [true, false]:
		for option: Dictionary in options:
			if _needed(g, t, option) == needed and not _contains(merged, option): merged.append(option)
	var forced: Array = []
	var council: Dictionary = g["council"] if g.get("council") is Dictionary else {}
	if int(g["seg"]) == int(t["P"]["segments"]) and not bool(council.get("emergency", false)):
		var hub: Dictionary = g["hub"] if g.get("hub") is Dictionary else {}
		for comm: String in t["COMMS"]:
			if _depart_share(g, t, comm) > 0.0 and not (hub.get("agreed", []) as Array).has(comm):
				forced.append({"kind": "motion", "motion": "share", "subject": comm, "by": comm})
	var crises: Array[String] = crisis_now(g, t)
	for option: Dictionary in merged:
		if option.get("kind") == "motion": continue
		var affects: Array = drains(t, str(option["law"])) if bool(option["repeal"]) else t["LAWS"][option["law"]]["crisis"]
		for crisis: String in affects:
			if crises.has(crisis):
				forced.append(option.duplicate(true))
				break
	if not forced.is_empty():
		for option: Dictionary in forced: option["forced"] = true
		return {"options": forced, "forced": true}
	return {"options": merged, "forced": false}
