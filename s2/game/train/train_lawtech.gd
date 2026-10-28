extends RefCounted
## Decision 426 PR 7, S2's fourth part (decision 446): S1 domestic/lawtech.ts,
## technology that bends a law instead of saving stores, and the three variant
## laws of domestic/laws.ts. Three ways (s1c_domestic 7.3):
## - it lifts part of a harsh law's situation penalty (E1, E2, E3 나, E4, E5);
##   the lift is gone with the law, a defective plate lifts half (TrainResearch.mult);
## - it opens a less cruel variant beside the harsh law (M2, M3 가, X1), one of
##   the two stands at a time, and the variant over a standing law is an amendment;
## - it cuts an ideal law's price (E3 가 coal, M3 나 food, M5 medicine).
## Insulation's own terms (decision 217·225, PR 4) are part of the same
## situation share. Checked against lawtech-vectors-v1
## (s1/tools/lawtech_port_fixtures.ts).

const TrainResearch = preload("res://game/train/train_research.gd")
const TrainMods = preload("res://game/train/train_mods.gd")

## S1 domestic/data.ts D: what a technology leaves of an ideal law's price.
const D: Dictionary = {"m5TreatMed": 1.3, "e3aHeatCoal": 0.65, "iceBoxFood": 1.5}
## S1 data.ts LAWS[law].mats of the two harsh laws technology softens.
const LAW_MATS: Dictionary = {
	"snow_duty": {"tail": [-10, 0, 0, 5], "front": [-10, 0, 0, 15], "medtech": [-10, 0, 0, 5]},
	"heat_quota": TrainMods.HEAT_QUOTA_MATS,
}
## S1 data.ts LAWS[law].title of every law named below (the lines read them
## without the game's tables).
const LAW_TITLE: Dictionary = {
	"snow_duty": "눈 녹이기 당번", "heat_quota": "난방 배당", "common_heating": "공동 난방",
	"common_kitchen": "공동 식당", "treat_all": "모두를 치료", "seed_grain": "종자곡 풀기",
	"seed_half": "종자곡 반만 풀기", "child_labor": "아동 노동", "child_pack": "아동 노동(짐 꾸리기만)",
	"triage": "중환자 분류", "triage_std": "중환자 분류(기준)",
}
## How much of a law's penalty a complete plate lifts, car by car; i is the
## situation slot (0 warmth, 3 exposure). One car's lift never passes the penalty.
const RELIEF: Array = [
	# E1 누설 막기: 눈 녹이기 당번's warmth −10 goes, its exposure penalty halves.
	{"tech": "e1", "law": "snow_duty", "i": 0, "by": {"tail": 10, "front": 10, "medtech": 10}},
	{"tech": "e1", "law": "snow_duty", "i": 3, "by": {"front": 7, "tail": 3, "medtech": 3}},
	# E4 과열 증기: 눈 녹이기 당번's exposure penalty goes.
	{"tech": "e4", "law": "snow_duty", "i": 3, "by": {"front": 15, "tail": 5, "medtech": 5}},
	# E2 압력 조절: 난방 배당's tail·medtech warmth −10 → −5, the guard's −5 → 0.
	{"tech": "e2", "law": "heat_quota", "i": 0, "by": {"tail": 5, "medtech": 5, "guard": 5}},
	# E3 나 앞칸 직결: the guard's penalty under 난방 배당 goes (the front's +5 is BONUS).
	{"tech": "e3", "variant": "b", "law": "heat_quota", "i": 0, "by": {"guard": 5}},
]
## Only while the law stands. E3 나: the front's warmth +5 under 난방 배당.
const BONUS: Array = [{"tech": "e3", "variant": "b", "law": "heat_quota", "i": 0, "by": {"front": 5}}]
## Which technology bends which law (the council's law preview and the journal).
const TOUCHES: Array = [
	{"tech": "e1", "law": "snow_duty", "text": "온기 벌 없음, 노출 벌 절반"},
	{"tech": "e4", "law": "snow_duty", "text": "노출 벌 없음"},
	{"tech": "e2", "law": "heat_quota", "text": "꼬리칸·의무진 온기 −10 → −5, 경비대 벌 없음"},
	{"tech": "e3", "variant": "b", "law": "heat_quota", "text": "경비대 벌 없음, 앞칸 온기 +5"},
	{"tech": "e5", "law": "heat_quota", "text": "단열한 객차는 온기 벌 없음"},
	{"tech": "e3", "variant": "a", "law": "common_heating", "text": "석탄 +1.25 → +0.6/구간"},
	{"tech": "m3", "variant": "b", "law": "common_kitchen", "text": "식량 +5 → +3.5/구간"},
	{"tech": "m5", "law": "treat_all", "text": "의약품 소모 ×1.6 → ×1.3"},
]
## The variant a technology opens in place of the harsh law (laws.ts).
const OPENS: Array = [
	{"tech": "m3", "variant": "a", "law": "seed_half", "base": "seed_grain"},
	{"tech": "x1", "law": "child_pack", "base": "child_labor"},
	{"tech": "m2", "law": "triage_std", "base": "triage"},
]
## Every effect of these is on a law (7.3): without the law there is no use for
## them. E4 and M5 have effects outside a law and are not here.
const LAW_ONLY_TECHS: Array[String] = ["e1", "e2", "e3", "e5", "m2", "m3"]


static func _active(g: Dictionary, law: String) -> bool:
	return (g.get("passed", {}) as Dictionary).has(law)


static func _dom(g: Dictionary) -> Dictionary:
	return g["dom"] if g.get("dom") is Dictionary else {}


## variantMult: the technology's multiplier when this way was picked, else 0.
static func variant_mult(g: Dictionary, tech: String, variant: String) -> float:
	var st: Variant = (_dom(g).get("techs", {}) as Dictionary).get(tech)
	if not st is Dictionary or st.get("variant") != variant:
		return 0.0
	return TrainResearch.mult(g, {}, tech)


static func _mult(g: Dictionary, p: Dictionary) -> float:
	return variant_mult(g, String(p["tech"]), String(p["variant"])) if p.has("variant") else TrainResearch.mult(g, {}, String(p["tech"]))


## lawTechSit for one community: what the dom adds to situation's four slots
## (S1 refreshSit with bedding, armour, pot, beds and fire at 0, as in S2).
static func sit(g: Dictionary, c: String) -> Array[float]:
	var out: Array[float] = [0.0, 0.0, 0.0, 0.0]
	if g.get("dom") == null:
		return out
	for law: String in ["snow_duty", "heat_quota"]:
		if not _active(g, law):
			continue
		var m: Variant = (LAW_MATS[law] as Dictionary).get(c)
		if m == null:
			continue
		for i: int in [0, 3]:
			# The penalty: warmth taken away, exposure added.
			var pen: float = maxf(0.0, -float(m[0])) if i == 0 else maxf(0.0, float(m[3]))
			if pen == 0.0:
				continue
			var relief: float = 0.0
			for r: Dictionary in RELIEF:
				if r["law"] == law and int(r["i"]) == i:
					relief += float((r["by"] as Dictionary).get(c, 0)) * _mult(g, r)
			if law == "heat_quota" and i == 0:
				relief += pen * TrainMods.insulated_share(g, c)
			relief = minf(pen, relief)
			out[i] += relief if i == 0 else -relief
	for b: Dictionary in BONUS:
		if not _active(g, String(b["law"])):
			continue
		var by: float = float((b["by"] as Dictionary).get(c, 0))
		if by != 0.0:
			out[int(b["i"])] += by * _mult(g, b) * (1.0 if int(b["i"]) == 0 else -1.0)
	# Insulation's gain and price (decision 217·225), with or without the law, on top of the lift above.
	var n: int = TrainMods.insulated_count(g, c)
	if n > 0:
		var half: float = 0.5 if bool(TrainMods.D["insulateQuotaHalf"]) and _active(g, "heat_quota") else 1.0
		out[0] += float(TrainMods.D["insulateWarm"]) * TrainMods.insulated_share(g, c) * half
		out[2] += float(TrainMods.D["insulateCrowd"]) * n
	# One stove per car: the larger of the tier's and its furniture's warmth.
	for car: String in TrainMods.FURNISH_CARS:
		if TrainMods.CAR_COMM[car] != c:
			continue
		var f: Dictionary = TrainMods.furnish_of(g, car)
		var warm: float = float(TrainMods.D["furnishWarm"][int(f["tier"])])
		var crowd: float = float(TrainMods.D["furnishCrowd"]) * float(f["tier"])
		for item: Dictionary in f["items"]:
			var furniture: Dictionary = TrainMods.FURNITURE[item["kind"]]
			warm = maxf(warm, float(furniture["warm"]))
			crowd += float(TrainMods.FURNITURE_SIZE[item["size"]]["crowd"]) + float(furniture["crowd"])
		out[0] += warm / float(TrainMods.COMM_CARS[c])
		out[2] += crowd
	return out


## S1 furnishComparison: max of other populated communities, capped per gap
## and then proportionally at two relationship points over the whole train.
static func furnish_comparison(g: Dictionary) -> Dictionary:
	var out := {"tail": 0.0, "medtech": 0.0, "guard": 0.0, "front": 0.0, "engine": 0.0}
	if not g.get("dom") is Dictionary:
		return out
	var means := {}
	for c: String in out:
		if c == "engine" or float(g.get("comms", {}).get(c, {}).get("pop", 0)) <= 0.0:
			continue
		var total: float = 0.0
		for car: String in TrainMods.FURNISH_CARS:
			if TrainMods.CAR_COMM[car] == c:
				total += float(TrainMods.furnish_of(g, car)["tier"])
		means[c] = total / float(TrainMods.COMM_CARS[c])
	var loss: float = 0.0
	for c: String in means:
		var best: float = 0.0
		for other: String in means:
			if other != c:
				best = maxf(best, float(means[other]))
		var gap: float = best - float(means[c])
		if gap >= float(TrainMods.D["furnishGapMin"]):
			out[c] = -float(TrainMods.D["furnishGapRel"]) * minf(gap, float(TrainMods.D["furnishGapMax"]))
		loss -= float(out[c])
	if loss > float(TrainMods.D["furnishGapCap"]):
		for c: String in means:
			out[c] *= float(TrainMods.D["furnishGapCap"]) / loss
	return out


## Called after runWorkshop, once per settlement; a piano pays only once per
## populated community, after comparison (same clamp and ledger order as S1).
static func furnish_tick(g: Dictionary) -> void:
	if not g.get("dom") is Dictionary:
		return
	var comparison: Dictionary = furnish_comparison(g)
	for c: String in comparison:
		TrainMods._bump_furnish_rel(g, c, float(comparison[c]))
		if c == "engine" or float(g.get("comms", {}).get(c, {}).get("pop", 0)) <= 0.0:
			continue
		var piano: bool = false
		for car: String in TrainMods.FURNISH_CARS:
			if TrainMods.CAR_COMM[car] == c:
				for item: Dictionary in TrainMods.furnish_of(g, car)["items"]:
					piano = piano or bool(TrainMods.FURNITURE[item["kind"]]["piano"])
		if piano:
			TrainMods._bump_furnish_rel(g, c, float(TrainMods.D["furnishPianoRel"]))


## lawTechRes: a law's fixed effects as technology has bent them (M5: 모두를
## 치료's medicine ×1.6 → ×1.3). `res` is the law's own row; it is not changed.
static func res(g: Dictionary, law: String, res_row: Dictionary) -> Dictionary:
	if law == "treat_all" and res_row.has("medMult"):
		var m: float = TrainResearch.mult(g, {}, "m5")
		if m > 0.0:
			var out: Dictionary = res_row.duplicate()
			out["medMult"] = float(res_row["medMult"]) - (float(res_row["medMult"]) - float(D["m5TreatMed"])) * m
			return out
	return res_row


## lawTechCoal: the coal a stretch an ideal law no longer burns (E3 가: 공동 난방).
static func coal(g: Dictionary) -> float:
	return float(D["e3aHeatCoal"]) * variant_mult(g, "e3", "a") if _active(g, "common_heating") else 0.0


## lawTechFood: the food a stretch an ideal law no longer eats (M3 나 얼음 상자: 공동 식당).
static func food(g: Dictionary) -> float:
	return float(D["iceBoxFood"]) * variant_mult(g, "m3", "b") if _active(g, "common_kitchen") else 0.0


## domesticLawOpen for the variant laws and the laws they stand in for: true or
## false decides, null leaves it to the S1a rule. Without a dom nothing changes
## (S1a's council already keeps S1c laws closed).
static func law_open(g: Dictionary, law: String) -> Variant:
	if not g.get("dom") is Dictionary:
		return null
	match law:
		# Over a standing original the variant comes up as an amendment (council_agenda.gd).
		"triage_std": return TrainResearch.usable(g, {}, "m2") and (_active(g, "triage") or float(g["med"]) <= 5.0 or int(g["injured"]) >= 6)
		"triage": return false if TrainResearch.usable(g, {}, "m2") or _active(g, "triage_std") else null
		"seed_half": return variant_mult(g, "m3", "a") > 0.0 and (_active(g, "seed_grain") or float(g["food"]) <= 50.0)
		"seed_grain": return false if _active(g, "seed_half") else null
		"child_pack": return TrainResearch.mult(g, {}, "x1") > 0.0 and (_active(g, "child_labor") or float(g["coal"]) <= 40.0 or float(g["food"]) <= 40.0)
		"child_labor": return false if _active(g, "child_pack") else null
	return null


static func _same_way(p: Dictionary, variant: Variant) -> bool:
	return not p.has("variant") or variant == null or p["variant"] == variant


## techLaws: the laws that must stand for this technology (way) to be of use.
## Without a way picked, both ways' laws.
static func tech_laws(tech: String, variant: Variant = null) -> Array[String]:
	var out: Array[String] = []
	for t: Dictionary in TOUCHES:
		if t["tech"] == tech and _same_way(t, variant) and not out.has(String(t["law"])):
			out.append(String(t["law"]))
	for o: Dictionary in OPENS:
		if o["tech"] == tech and _same_way(o, variant) and not out.has(String(o["base"])):
			out.append(String(o["base"]))
	return out


## Whether one of the laws this technology (way) needs stands now (S1 useKey on/off).
static func law_standing(g: Dictionary, tech: String, variant: Variant = null) -> bool:
	for law: String in tech_laws(tech, variant):
		if _active(g, law):
			return true
	return false


## techUseLine: what the technology is for (7.3, so no one buys it unawares), or
## "" for a technology no law touches.
static func use_line(g: Dictionary, tech: String, variant: Variant = null) -> String:
	var parts: Array[String] = []
	for t: Dictionary in TOUCHES:
		if t["tech"] == tech and _same_way(t, variant):
			var part: String = "%s이(가) 서 있을 때" % LAW_TITLE[t["law"]]
			if not parts.has(part): parts.append(part)
	for o: Dictionary in OPENS:
		if o["tech"] == tech and _same_way(o, variant):
			var part: String = "%s 대신 %s을(를) 올릴 때" % [LAW_TITLE[o["base"]], LAW_TITLE[o["law"]]]
			if not parts.has(part): parts.append(part)
	if parts.is_empty():
		return ""
	return "%s: %s%s" % ["쓸모" if LAW_ONLY_TECHS.has(tech) else "법 쓸모", ", ".join(parts), "(지금 서 있다)" if law_standing(g, tech, variant) else "(지금은 없다)"]


static func _tech_name(t: Dictionary) -> String:
	var def: Dictionary = TrainResearch.TECHS[t["tech"]]
	if def.has("variants") and t.has("variant"):
		return String(def["variants"][t["variant"]]["name"])
	return String(def["name"])


## lawTechLines: how the technologies in use bend this law (the end of the law's preview).
static func law_lines(g: Dictionary, law: String) -> Array[String]:
	var out: Array[String] = []
	for t: Dictionary in TOUCHES:
		var m: float = _mult(g, t)
		if t["law"] == law and m > 0.0:
			out.append("%s: %s%s" % [_tech_name(t), t["text"], "(결함판이라 절반)" if m < 1.0 else ""])
	return out


## lawTechNews: a journal line for each standing law a just-restored technology bends.
static func news(g: Dictionary, tech: String) -> Array[String]:
	var out: Array[String] = []
	for t: Dictionary in TOUCHES:
		if t["tech"] == tech and _active(g, String(t["law"])) and _mult(g, t) > 0.0:
			out.append("%s이(가) 바뀐다: %s." % [LAW_TITLE[t["law"]], t["text"]])
	return out
