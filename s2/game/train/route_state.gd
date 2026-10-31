extends RefCounted
## The train owns progress; the screen slot is only a copy of it.

const Catalog = preload("res://game/train/campaign_route.gd")
const Rng = preload("res://game/politics/rng.gd")


static func is_campaign(g: Dictionary) -> bool:
	return g.get("campaign") is Dictionary and g["campaign"].get("mode") == "campaign"


static func start(g: Dictionary, run: String) -> Dictionary:
	var out: Dictionary = g.duplicate(true)
	out["campaign"] = {"version": 1, "mode": "campaign", "catalog": Catalog.CATALOG, "run": run,
		"cursor": 0, "visit": {}, "workshop_done": [], "branches": [], "chosen": {}, "recommended": {}, "dead": {}}
	return out


static func current_stop(g: Dictionary) -> Dictionary:
	return Catalog.stop_at(int(g["campaign"]["cursor"])) if is_campaign(g) else {}


static func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) == floorf(float(value))


static func visit_id(run: String, stop_id: String, seg: int) -> String:
	return "visit_%s_%s_%d" % [run.sha256_text().left(16), stop_id, seg]


static func record_for_visit(g: Dictionary) -> Dictionary:
	if not is_campaign(g) or not g["campaign"].get("visit") is Dictionary:
		return {}
	var visit: Dictionary = g["campaign"]["visit"]
	var returns: Dictionary = g.get("fieldReturns", {}) if g.get("fieldReturns") is Dictionary else {}
	for row: Variant in returns.get("records", []):
		if row is Dictionary and row.get("departureId") == visit.get("departure_id") and row.get("stopId") == visit.get("stop_id") and row.get("seg") == visit.get("seg"):
			return row
	return {}


static func problem(g: Dictionary) -> String:
	if not is_campaign(g):
		return "F-CAMPAIGN-ROUTE: mode"
	var route: Dictionary = g["campaign"]
	if route.get("version") != 1 or route.get("catalog") != Catalog.CATALOG or not route.get("run") is String or route["run"].is_empty():
		return "F-CAMPAIGN-ROUTE: identity"
	if not _whole(route.get("cursor")) or int(route["cursor"]) > Catalog.size() or not route.get("visit") is Dictionary:
		return "F-CAMPAIGN-ROUTE: cursor or visit"
	for key: String in ["chosen", "recommended", "dead"]:
		if not route.get(key) is Dictionary or not route[key].is_empty():
			return "F-CAMPAIGN-ROUTE: " + key
	if not route.get("branches") is Array or not route["branches"].is_empty() or not route.get("workshop_done") is Array:
		return "F-CAMPAIGN-ROUTE: lists"
	var seen: Dictionary = {}
	for workshop_id: Variant in route["workshop_done"]:
		if not workshop_id is String or not workshop_id.begins_with("dep_visit_") or seen.has(workshop_id):
			return "F-CAMPAIGN-ROUTE: workshop identity"
		seen[workshop_id] = true
	var issue: String = Catalog.validate()
	if issue != "":
		return issue
	var visit: Dictionary = route["visit"]
	if visit.is_empty():
		return "" if int(route["cursor"]) == 0 and g.get("phase") == "travel" else "F-CAMPAIGN-ROUTE: missing visit"
	var stop: Dictionary = Catalog.stop_at(mini(int(route["cursor"]), Catalog.size() - 1))
	if not _whole(visit.get("seg")) or not _whole(visit.get("field_seed")) or visit.get("seg", 0) > g.get("seg", -1):
		return "F-CAMPAIGN-ROUTE: visit numbers"
	var id: String = visit_id(route["run"], stop["id"], int(visit["seg"]))
	if visit.get("id") != id or visit.get("stop_id") != stop["id"] or visit.get("map") != stop["map"] or visit.get("departure_id") != "dep_" + id:
		return "F-CAMPAIGN-ROUTE: visit identity"
	if int(visit["field_seed"]) != Rng.seed_state("%s:field:%s" % [g["seed"], id]):
		return "F-CAMPAIGN-ROUTE: field seed"
	if not visit.get("result") in ["open", "returned", "passed"]:
		return "F-CAMPAIGN-ROUTE: result"
	if visit.has("contract"):
		if not visit["contract"] is Dictionary or not owns_contract(g, visit["contract"]):
			return "F-CAMPAIGN-ROUTE: contract"
		var order: Dictionary = visit["contract"]
		if not order.get("version") in [1, 2] or not order.get("roster") is Array or not order.get("workCrew") is Array or not order.get("promises") is Array or not order.get("domestic") is bool:
			return "F-CAMPAIGN-ROUTE: contract shape"
		for key: String in ["roster", "workCrew", "promises"]:
			for row: Variant in order[key]:
				if not row is Dictionary or not row.get("id") is String:
					return "F-CAMPAIGN-ROUTE: contract row"
	var record: Dictionary = record_for_visit(g)
	var matches: int = 0
	var ledger: Dictionary = g.get("fieldReturns", {}) if g.get("fieldReturns") is Dictionary else {}
	for row: Variant in ledger.get("records", []):
		if row is Dictionary and (row.get("departureId") == visit["departure_id"] or row.get("stopId") == visit["stop_id"]):
			matches += 1
	if matches > 1 or (matches == 1 and record.is_empty()):
		return "F-CAMPAIGN-ROUTE: duplicate or misplaced return"
	if visit["result"] == "returned":
		if record.is_empty() or record.get("receiptId") != visit.get("receipt_id"):
			return "F-CAMPAIGN-ROUTE: missing return"
		var returns: Dictionary = g.get("fieldReturns", {})
		var applied: Dictionary = returns.get("applied", {}) if returns.get("applied") is Dictionary else {}
		var raw: Variant = applied.get(visit["receipt_id"])
		if not raw is String:
			return "F-CAMPAIGN-ROUTE: missing applied id"
		var receipt: Variant = JSON.parse_string(raw)
		if not receipt is Dictionary or receipt.get("receiptId") != visit["receipt_id"] or not owns_receipt(g, receipt):
			return "F-CAMPAIGN-ROUTE: return identity"
	elif not record.is_empty():
		return "F-CAMPAIGN-ROUTE: unexpected return"
	if visit["result"] == "open" and (visit["seg"] != g["seg"] or g.get("phase") != "stop" or not g.get("stop") is Dictionary or bool(g["stop"].get("done", false))):
		return "F-CAMPAIGN-ROUTE: open stop"
	if visit["result"] == "passed" and visit["seg"] == g["seg"] and (not g.get("stop") is Dictionary or not bool(g["stop"].get("done", false)) or not bool(g["stop"].get("result", {}).get("passed", false))):
		return "F-CAMPAIGN-ROUTE: passed stop"
	if int(route["cursor"]) == Catalog.size() and visit["result"] == "open":
		return "F-CAMPAIGN-ROUTE: unfinished trial"
	return ""


static func owns_contract(g: Dictionary, contract: Dictionary) -> bool:
	var visit: Dictionary = g["campaign"]["visit"]
	return not visit.is_empty() and contract.get("departureId") == visit.get("departure_id") and contract.get("stopId") == visit.get("stop_id") and contract.get("segment") == visit.get("seg") and contract.get("placeId") == visit.get("map")


static func owns_receipt(g: Dictionary, receipt: Dictionary) -> bool:
	var place: Dictionary = receipt.get("place", {}) if receipt.get("place") is Dictionary else {}
	var visit: Dictionary = g["campaign"]["visit"]
	return receipt.get("departureId") == visit.get("departure_id") and receipt.get("stopId") == visit.get("stop_id") and place.get("id") == visit.get("map")


static func enter_stop(g: Dictionary, seg: int) -> Dictionary:
	var out: Dictionary = g.duplicate(true)
	var stop: Dictionary = current_stop(out)
	if stop.is_empty() or not out["campaign"]["visit"].is_empty() or out.get("phase") != "stop" or seg != int(out["seg"]):
		return out
	var id: String = visit_id(out["campaign"]["run"], stop["id"], seg)
	out["campaign"]["visit"] = {"id": id, "seg": seg, "stop_id": stop["id"], "departure_id": "dep_" + id,
		"map": stop["map"], "field_seed": Rng.seed_state("%s:field:%s" % [out["seed"], id]), "result": "open"}
	return out


static func returned_for_current_stop(g: Dictionary) -> bool:
	return is_campaign(g) and g["campaign"]["visit"].get("result") == "returned" and not record_for_visit(g).is_empty()


static func mark_returned(g: Dictionary, receipt_id: String) -> Dictionary:
	var out: Dictionary = g.duplicate(true)
	var row: Dictionary = record_for_visit(out)
	if out["campaign"]["visit"].get("result") == "open" and row.get("receiptId") == receipt_id and (out.get("fieldReturns", {}).get("applied", {}) as Dictionary).has(receipt_id):
		out["campaign"]["visit"]["result"] = "returned"
		out["campaign"]["visit"]["receipt_id"] = receipt_id
	return out


static func mark_passed(g: Dictionary) -> Dictionary:
	var out: Dictionary = g.duplicate(true)
	if out["campaign"]["visit"].get("result") == "open":
		out["campaign"]["visit"]["result"] = "passed"
	return out


static func activate_next_stop(g: Dictionary) -> Dictionary:
	var out: Dictionary = g.duplicate(true)
	var route: Dictionary = out["campaign"]
	var visit: Dictionary = route["visit"]
	if int(route["cursor"]) >= Catalog.size() or not visit.get("result") in ["returned", "passed"]:
		return out
	if int(route["cursor"]) + 1 == Catalog.size():
		route["cursor"] = Catalog.size()
		return out
	if out.get("phase") != "stop" or int(out["seg"]) <= int(visit["seg"]) or bool(out.get("stop", {}).get("done", true)):
		return out
	route["cursor"] = int(route["cursor"]) + 1
	route["visit"] = {}
	return enter_stop(out, int(out["seg"]))


static func workshop_due(g: Dictionary, departure_id: String) -> bool:
	return not departure_id.is_empty() and not (g["campaign"]["workshop_done"] as Array).has(departure_id)


static func mark_workshop(g: Dictionary, departure_id: String) -> Dictionary:
	var out: Dictionary = g.duplicate(true)
	if workshop_due(out, departure_id):
		(out["campaign"]["workshop_done"] as Array).append(departure_id)
	return out
