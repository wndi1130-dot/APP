extends RefCounted
## S1 chronicle arithmetic, kept separate from the disabled dark-path rules.

const NIGHTMARE_CARDS := 3
const SAVED_DEATHS := 6
const MEANS := {
	"assn_ordered": 4, "executions": 3, "scapegoats": 3, "frames": 3, "exiles": 2,
	"lynch_allowed": 2, "summary": 2, "trial_bought": 2, "blackmail": 1, "harsh_chosen": 1,
	"martial": 5, "martial_sided": 5, "martial_brink": 4, "martial_council": 2,
	"martial_lifted": -2, "guard_exec": 1,
}
const CROSSINGS := ["assn_ordered", "scapegoats", "lynch_allowed", "exiles", "executions", "trial_bought", "frames", "martial", "martial_sided", "martial_brink"]
const GRAVE := ["assn_ordered", "executions", "scapegoats", "frames", "martial_sided"]
const STATS := ["signs", "imminent", "violent", "violentDeaths", "cases", "solved", "misjudged", "trials", "scapegoats", "lynches", "orders", "revealed", "risen", "cardsDeferred"]
const TONE_LINE := {
	"hope": "열차는 닿았다. 누구의 이름도 팔지 않고.",
	"hope_cost": "많이 잃었다. {lost}. 그래도 열차장은 끝까지 사람을 팔지 않았다.",
	"shade": "열차는 닿았다. 다만 {cross}의 일은 아무도 잊지 않는다.",
	"tragedy": "지키려던 것을 놓쳤다. {cross}부터였다.",
	"worth": "열차는 닿았다. 그럴 가치가 있었는지는 남은 사람들이 묻는다.",
	"despair": "열차는 많은 것을 치르고도 아무것도 지키지 못했다.",
}
const CROSS_WORD := {
	"assn_ordered": "암살 명령", "executions": "처형", "scapegoats": "희생양", "frames": "누명",
	"exiles": "하차 명령", "lynch_allowed": "막지 않은 린치", "summary": "즉결", "trial_bought": "산 재판",
	"blackmail": "협박", "harsh_chosen": "가혹한 법", "martial": "계엄", "martial_sided": "편든 계엄",
	"martial_brink": "내전을 막은 계엄", "martial_council": "의회가 맡긴 계엄", "martial_lifted": "거둔 계엄", "guard_exec": "경비대 재판의 처형",
}
const BOARDING := {"refugee": "피난길에 탔다", "bought": "자리를 사서 탔다", "rescue": "구조돼 탔다", "depot": "차고에서부터 있었다", "force": "밀고 올라탔다", "born": "열차에서 났다"}


static func enabled(g: Dictionary) -> bool:
	var dark: Variant = g.get("dark")
	# JS objects, including an empty object, are truthy.
	return dark != null and (dark is Dictionary or bool(dark))


static func state(g: Dictionary, create: bool = false) -> Dictionary:
	if g.get("endChronicle") is Dictionary:
		return g["endChronicle"]
	var d := {"means": {}, "crossed": [], "nightmareUntil": -1, "nightmareCards": 0,
		"numb": false, "h7": [], "stats": {}, "joined": [], "closed": false}
	if create: g["endChronicle"] = d
	return d


static func cross(g: Dictionary, key: String) -> void:
	assert(MEANS.has(key))
	var d: Dictionary = state(g, true)
	d["means"][key] = int(d["means"].get(key, 0)) + 1
	if key not in CROSSINGS: return
	if int(d["nightmareUntil"]) >= int(g["seg"]): d["numb"] = true
	d["crossed"].append({"key": key, "seg": g["seg"]})
	d["nightmareUntil"] = int(g["seg"]) + 1
	d["nightmareCards"] = NIGHTMARE_CARDS


static func means_total(g: Dictionary) -> int:
	var chosen := 0
	var means: Dictionary = state(g)["means"]
	for key: String in means: chosen += int(MEANS[key]) * int(means[key])
	return maxi(0, chosen + int(MEANS["blackmail"]) * int(g.get("stats", {}).get("blackmails", 0)))


static func means_layer(g: Dictionary) -> String:
	var d: Dictionary = state(g)
	if (d["crossed"] as Array).is_empty(): return "clean"
	var grave := 0
	for key: String in GRAVE: grave += int(d["means"].get(key, 0))
	return "dark" if means_total(g) >= 8 or grave >= 2 else "shaken"


static func saved(g: Dictionary) -> bool:
	return g.get("end") == "complete" and (g.get("deaths", []) as Array).size() <= SAVED_DEATHS


static func tone(g: Dictionary) -> String:
	var layer: String = means_layer(g)
	if layer == "clean": return "hope" if saved(g) else "hope_cost"
	if layer == "shaken": return "shade" if saved(g) else "tragedy"
	return "worth" if saved(g) else "despair"


static func tone_line(g: Dictionary) -> String:
	if not enabled(g): return ""
	var lost: String = ", ".join((g.get("deaths", []) as Array).slice(0, 2))
	var crossed: Array = state(g)["crossed"]
	var first: String = "그날" if crossed.is_empty() else "%d구간의 %s" % [int(crossed[0]["seg"]), CROSS_WORD[crossed[0]["key"]]]
	return String(TONE_LINE[tone(g)]).replace("{lost}", lost if lost != "" else "이름들").replace("{cross}", first)


static func log_pick(g: Dictionary, pick: Dictionary) -> void:
	var row: Dictionary = pick.duplicate(true)
	row["seg"] = g["seg"]
	state(g, true)["h7"].append(row)


static func _median(values: Array) -> float:
	if values.is_empty(): return 0.0
	var ordered: Array = values.duplicate()
	ordered.sort()
	return float(ordered[ordered.size() >> 1])


## Number.toFixed(2), rounded from the binary value, including exact half ties.
static func _fixed2(value: float) -> float:
	if value <= 0.0: return 0.0
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	var bits: int = bytes.decode_u64(0)
	var exponent: int = (bits >> 52) & 2047
	if exponent == 0: return 0.0
	var shift: int = 1073 - exponent
	if shift <= 0: return value
	if shift >= 63: return 0.0
	var numerator: int = ((bits & 4503599627370495) | 4503599627370496) * 25
	var whole: int = numerator >> shift
	if numerator - (whole << shift) >= (1 << (shift - 1)): whole += 1
	return float(whole) / 100.0


static func h7_record(g: Dictionary) -> Dictionary:
	var d: Dictionary = state(g)
	var ratios: Array = []
	var shown := 0
	var with_alt := 0
	for pick: Dictionary in d["h7"]:
		if not bool(pick["crossing"]): continue
		shown += 1
		if bool(pick["alt"]): with_alt += 1
		var peers: Array = []
		for other: Dictionary in d["h7"]:
			if not bool(other["crossing"]) and other["choices"] == pick["choices"] and absf(float(other["chars"]) - float(pick["chars"])) <= float(pick["chars"]) * 0.3:
				peers.append(float(other["ms"]) / maxf(1.0, float(other["chars"])))
		var middle: float = _median(peers)
		if middle > 0.0: ratios.append((float(pick["ms"]) / maxf(1.0, float(pick["chars"]))) / middle)
	var out := {"hesitation": _fixed2(_median(ratios)), "hesitationN": ratios.size(),
		"crossingShown": shown, "crossingShownWithAlt": with_alt,
		"crossings": (d["crossed"] as Array).size(), "means": means_total(g)}
	for key: String in STATS: out[key] = int(d["stats"].get(key, 0))
	return out


static func _utf16_length(text: String) -> int:
	var count := text.length()
	for i: int in text.length():
		if text.unicode_at(i) > 65535: count += 1
	return count


static func _disabled(choice: Dictionary) -> bool:
	var value: Variant = choice.get("disabled")
	if value is String: return not String(value).is_empty()
	if value is bool: return bool(value)
	return false


static func log_card_pick(g: Dictionary, t: Dictionary, uid: int, index: int, ms: float) -> void:
	if not is_finite(ms) or ms <= 0.0: return
	for card: Dictionary in g.get("cards", []):
		if int(card["uid"]) != uid: continue
		var view: Dictionary = load("res://game/train/turn/turn_card_text.gd").view(g, t, card)
		_log_card_view_pick(g, String(card["kind"]), view, index, ms)
		return


static func _log_card_view_pick(g: Dictionary, kind: String, view: Dictionary, index: int, ms: float) -> void:
	if not is_finite(ms) or ms <= 0.0: return
	var choices: Array = view.get("choices", [])
	if index < 0 or index >= choices.size(): return
	var selected: Dictionary = choices[index]
	if _disabled(selected): return
	var chars: int = _utf16_length(String(view.get("body", "")))
	var count := 0
	var crossing := false
	var alternative := false
	for choice: Dictionary in choices:
		if _disabled(choice): continue
		count += 1
		var say: Variant = choice.get("say")
		chars += _utf16_length(String(choice.get("label", "") if say == null else say))
		if choice.has("cross"): crossing = true
		else: alternative = true
	log_pick(g, {"kind": kind, "chars": chars, "ms": int(floor(ms + 0.5)), "choices": count,
		"crossing": crossing, "picked": selected.has("cross"), "alt": alternative})


static func wall_names(g: Dictionary, t: Dictionary) -> Array:
	var wall: Array = []
	for death: Dictionary in g.get("deathLog", []):
		var row := {"name": death["name"], "seg": death["seg"]}
		for person: Dictionary in t.get("PROFILES", []):
			if person["name"] != death["name"]: continue
			row["comm"] = person["community"]
			if person.has("like"): row["like"] = person["like"]
			row["boarding"] = "판 중에 탔다" if person["id"] in state(g)["joined"] else BOARDING.get(person.get("boarding", ""), "처음부터 탔다")
			break
		wall.append(row)
	return wall


static func wall_line(wall_name: Dictionary) -> String:
	return "%s · %d구간" % [wall_name["name"], int(wall_name["seg"])]


## The rules close the record once, after lookback and any raised-child lines.
static func close_chronicle(g: Dictionary, t: Dictionary) -> Dictionary:
	if not enabled(g): return {}
	var d: Dictionary = state(g, true)
	if bool(d["closed"]): return d
	d["closed"] = true
	var record: Dictionary = h7_record(g)
	d["record"] = record
	d["tone"] = tone(g)
	d["toneLine"] = tone_line(g)
	d["wall"] = wall_names(g, t)
	var line: String = "기록: 징후 %d, 폭력 %d(사망 %d), 선을 넘음 %d, 수단 %d, 망설임 %s배." % [record["signs"], record["violent"], record["violentDeaths"], record["crossings"], record["means"], str(record["hesitation"])]
	# JS prints integer-valued numbers without a decimal suffix.
	line = line.replace(".0배.", "배.")
	g["journal"].append({"seg": g["seg"], "text": line})
	return d
