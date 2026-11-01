extends RefCounted
## Second-station summary and the terminal card for the field slice.

const FieldReturn = preload("res://game/politics/field_return.gd")


## A ledger amount as the sheet writes it: to one decimal (field_arrival.ts num, Math.round
## half up), whole numbers without a point.
static func _number(value: Variant) -> String:
	var n := floorf(float(value) * 10.0 + 0.5) / 10.0
	if n == floorf(n):
		return str(int(n))
	return "%.1f" % n


static func _diff(before: Variant, after: Variant) -> String:
	var a := float(before)
	var b := float(after)
	if a == b:
		return "그대로"
	return "%s → %s (%s%s)" % [_number(before), _number(after), "+" if b > a else "−", _number(absf(b - a))]


static func second_station_reached(g: Dictionary) -> bool:
	if g.get("campaign") is Dictionary and g["campaign"].get("mode") == "campaign":
		var visit: Dictionary = g["campaign"].get("visit", {})
		var campaign_stop: Variant = g.get("stop")
		return visit.get("result") in ["returned", "passed"] and g.get("phase") == "stop" and int(g.get("seg", 0)) > int(visit.get("seg", 0)) and campaign_stop is Dictionary and not bool(campaign_stop.get("done", false))
	var field_returns: Variant = g.get("fieldReturns")
	if not field_returns is Dictionary or (field_returns.get("records", []) as Array).is_empty():
		return false
	var record: Dictionary = field_returns["records"][0]
	var stop: Variant = g.get("stop")
	return g["phase"] == "stop" and int(g["seg"]) > int(record["seg"]) and (not stop is Dictionary or not bool(stop.get("done", false)))


static func arrival_summary(g: Dictionary, t: Dictionary) -> Variant:
	if g.get("campaign") is Dictionary and g["campaign"].get("mode") == "campaign" and g["campaign"].get("visit", {}).get("result") == "passed":
		return [{"k": "arrive", "title": "둘째 역", "lines": ["구벤에 닿았다."]},
			{"k": "people", "title": "지나친 정차", "lines": ["이전 정차는 지나쳤다. 귀환 영수증과 특별 회기는 없다."]}]
	var field_returns: Variant = g.get("fieldReturns")
	if not field_returns is Dictionary or (field_returns.get("records", []) as Array).is_empty():
		return null
	var record: Dictionary = field_returns["records"][0]
	var before: Dictionary = record["before"]
	var now := FieldReturn.snapshot(g, t)
	var out: Array = []
	out.append({
		"k": "arrive", "title": "둘째 역",
		"lines": ["%d구간, 둘째 역에 닿았다. 첫 정차에서 %d구간을 달려왔다." % [int(g["seg"]), int(g["seg"]) - int(record["seg"])]]
	})
	var people: Array[String] = []
	if not (record["dead"] as Array).is_empty():
		people.append("돌아오지 못한 사람: %s" % ", ".join(record["dead"]))
	for comm: String in t["COMMS"]:
		if float(now["pop"][comm]) != float(before["pop"][comm]):
			people.append("%s %s명" % [t["COMM_NAME"][comm], _diff(before["pop"][comm], now["pop"][comm])])
	if float(now["injured"]) != float(before["injured"]):
		people.append("다친 사람 %s" % _diff(before["injured"], now["injured"]))
	out.append({"k": "people", "title": "사람", "lines": people if not people.is_empty() else ["사람 수는 그대로다."]})
	out.append({
		"k": "stock", "title": "물자", "lines": [
			"석탄 %s" % _diff(before["coal"], now["coal"]),
			"식량 %s" % _diff(before["food"], now["food"]),
			"의약품 %s" % _diff(before["med"], now["med"]),
			"사치품 %s" % _diff(before["lux"], now["lux"]),
		],
	})
	var warm: Array[String] = []
	for comm: String in t["COMMS"]:
		if float(now["warm"][comm]) != float(before["warm"][comm]):
			warm.append("%s 온기 %s" % [t["COMM_NAME"][comm], _diff(before["warm"][comm], now["warm"][comm])])
	out.append({"k": "warm", "title": "온기", "lines": warm if not warm.is_empty() else ["칸마다 온기는 그대로다."]})
	var symbol: Array = []
	var promise: Array = []
	for line: Dictionary in record["lines"]:
		if line["k"] == "symbol":
			symbol.append(line["text"])
		elif line["k"] == "promise":
			promise.append(line["text"])
	out.append({"k": "symbol", "title": "상징물", "lines": symbol if not symbol.is_empty() else ["가져온 상징물이 없다."]})
	out.append({"k": "promise", "title": "약속", "lines": promise if not promise.is_empty() else ["필드에서 한 약속이 없었다."]})
	var council: Array[String] = []
	var special: Variant = field_returns.get("special")
	if not special is Dictionary:
		council.append("특별 회기는 열리지 않았다.")
	elif special["status"] == "skipped":
		council.append("특별 회기를 열지 못했다: %s" % special.get("why", ""))
	else:
		if special.has("picked") and special.has("result"):
			var result: Dictionary = special["result"]
			council.append("「%s」 %s (찬성 %d, 반대 %d, 필요 %d)" % [special["picked"], "가결" if bool(result["passed"]) else "부결", int(result["yes"]), int(result["no"]), int(result["need"])])
		if special.get("before") is Dictionary and special.get("after") is Dictionary:
			var council_before: Dictionary = special["before"]
			var council_after: Dictionary = special["after"]
			council.append("신임 %s" % _diff(council_before["trust"], council_after["trust"]))
			council.append("긴장 %s" % _diff(council_before["tension"], council_after["tension"]))
			for comm: String in t["COMMS"]:
				if float(council_after["rel"][comm]) != float(council_before["rel"][comm]):
					council.append("%s 관계 %s" % [t["COMM_NAME"][comm], _diff(council_before["rel"][comm], council_after["rel"][comm])])
	out.append({"k": "council", "title": "특별 회기", "lines": council})
	return out


## Who did not come back from the first stop: the dead and those left in the field
## (left behind or missing), each once — counted, never named (결정 147·183). A
## record from before leftCount counts its left again from the receipt kept in
## applied, as the return did (left behind or missing, not dead); failing that,
## only the dead. s1 field_arrival.ts notBack the same.
static func not_back(g: Dictionary, rec: Dictionary) -> int:
	var dead: int = (rec["dead"] as Array).size()
	if rec.has("leftCount"):
		return dead + int(rec["leftCount"])
	var applied: Variant = g["fieldReturns"].get("applied")
	var kept: Variant = (applied as Dictionary).get(rec.get("receiptId", ""), "") if applied is Dictionary else ""
	var json := JSON.new()
	if not kept is String or String(kept).is_empty() or json.parse(kept) != OK or not json.data is Dictionary or not json.data.get("people") is Dictionary:
		return dead
	var people: Dictionary = json.data["people"]
	var gone: Array = people.get("dead", []) if people.get("dead") is Array else []
	var left := {}
	for key: String in ["leftBehind", "missing"]:
		if people.get(key) is Array:
			for id: Variant in people[key]:
				if id is String and not gone.has(id):
					left[id] = true
	return dead + left.size()


static func end_card(g: Dictionary) -> Dictionary:
	var lost := 0
	if g.get("fieldReturns") is Dictionary and not (g["fieldReturns"].get("records", []) as Array).is_empty():
		lost = not_back(g, g["fieldReturns"]["records"][0])
	return {
		"title": "여기까지",
		"lines": [
			"첫 정차 한 번이 열차를 이만큼 바꿨다.",
			"%d명이 돌아오지 못했다." % lost if lost > 0 else "나간 사람은 모두 열차로 돌아왔다.",
			"이 시험판은 둘째 역에서 멈춘다.",
		],
	}


static func finish_slice(g0: Dictionary, _t: Dictionary) -> Dictionary:
	var g := g0.duplicate(true)
	if not second_station_reached(g):
		return {"finished": false, "g": g}
	g["fieldReturns"]["arrived"] = {"seg": g["seg"]}
	if g["phase"] != "end":
		g["end"] = "slice"
		g["phase"] = "end"
		(g["journal"] as Array).append({"seg": g["seg"], "text": "둘째 역에 닿았다. 시험판은 여기서 멈춘다.", "tone": "bad"})
	return {"finished": true, "g": g}
