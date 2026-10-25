extends RefCounted
## Cutting off a bitten or scratched arm or leg in the field (body_injury 2.2,
## decisions.md 「물리면 절단」, 「절단은 확률이 아니다」): inside the infection
## window it always stops the infection that limb carries; the risk is the
## blood, the shock and the limb lost. Only an arm or a leg can be cut (a bite
## on the torso, the head or the neck cannot, 결정 441). The numbers are the
## brief's start values, to be set on the phone.
##
## What it takes: a blade (a knife or the hatchet, in either one's hands) and a
## tourniquet (one carried, or made on the spot of cloth and a plank, as the
## care steps make it). A medkit, when there is one, is used up and halves the
## death by shock. How long it takes and how it goes after hangs on the medical
## knowledge of the one who cuts.

const W = preload("res://game/sim/weapons.gd")
const Treatment = preload("res://game/sim/treatment.gd")
const Carry = preload("res://game/sim/carry.gd")
const SimNoise = preload("res://game/sim/noise.gd")

## Seconds to cut, by the medical knowledge of the one who cuts (the hands'
## state stretches it as it does any work, field_game.gd _update_person).
const SECONDS: Dictionary = {"none": 20.0, "apprentice": 16.0, "skilled": 12.0, "master": 8.0}
## Death by shock, by the same.
const SHOCK: Dictionary = {"none": 0.15, "apprentice": 0.10, "skilled": 0.05, "master": 0.02}
## The wound left: rough hands leave a deep one, a trained hand a torn one.
const STUMP: Dictionary = {"none": "deep", "apprentice": "deep", "skilled": "laceration", "master": "laceration"}
## Strong enough to bear the shock half as often (body_injury 2.2: 체력 7 이상).
const STRONG: int = 7
## The scream (body_injury 2.2 「매우 시끄러움(비명)」): the whole map hears it
## (SimNoise.WHOLE_MAP_MIN).
const SCREAM: int = SimNoise.Level.VERY_LOUD
const LIMBS: Array[String] = ["arm_left", "arm_right", "leg_left", "leg_right"]


## What cutting off `part` of `o`'s body by `medic` would take, with what the
## two carry (`have`, field_actions.gd care_tools): {"ok", "why" (what stops
## it, in a few words), "seconds", "blade", "uses" (item -> how many), "kit",
## "also" (the other limbs bitten too, that must go as well)}.
static func plan(medic, o, part: String, have: Dictionary) -> Dictionary:
	var out := {"ok": false, "why": "", "seconds": seconds(String(medic.medical)), "blade": "", "uses": {}, "kit": false, "also": []}
	if not LIMBS.has(part):
		out["why"] = "팔이나 다리만 자를 수 있다"
		return out
	if o.body.lost.has(part):
		out["why"] = "이미 잘렸다"
		return out
	if not o.body.at_risk_on(part):
		out["why"] = "자를 까닭이 없다"
		return out
	if o.body.window_left <= 0.0:
		out["why"] = "감염 창이 닫혀 소용없다"
		return out
	var core: String = o.body.uncut_bite()
	if core != "":
		out["why"] = "%s도 물려 잘라도 막지 못한다" % Treatment.PART_NAMES[core]
		return out
	var takes: float = float(out["seconds"]) / maxf(float(medic.mults()["hands"]), 0.01)
	if takes > o.body.window_left:
		out["why"] = "창이 %d초 남아 다 자르기 전에 닫힌다" % ceili(o.body.window_left)
		return out
	out.merge(tools(medic, o, have), true)
	if out["why"] != "":
		return out
	for other: String in o.body.bitten_limbs():
		if other != part:
			out["also"].append(other)
	out["ok"] = true
	return out


## The blade, the tourniquet and the medkit the cut takes: {"why" ("" when all
## is there), "blade", "uses", "kit"}. Asked again when the cut is done.
static func tools(medic, o, have: Dictionary) -> Dictionary:
	var out := {"why": "", "blade": blade_of(medic, o), "uses": {}, "kit": false}
	if medic.body.lost.has("arm_left") and medic.body.lost.has("arm_right"):
		out["why"] = "자를 손이 없다"
		return out
	if out["blade"] == "":
		out["why"] = "칼이나 손도끼 없음"
		return out
	if int(have.get("tourniquet", 0)) > 0:
		out["uses"] = {"tourniquet": 1}
	else:
		var made: Dictionary = Treatment._made(Treatment.STEPS["tourniquet"], have)
		if made.is_empty():
			out["why"] = "지혈대 없음(천과 판자)"
			return out
		out["uses"] = made
	if int(have.get("medkit", 0)) > 0:
		out["uses"]["medkit"] = 1
		out["kit"] = true
	return out


static func seconds(medical: String) -> float:
	return float(SECONDS.get(medical, SECONDS["none"]))


## How likely the shock kills: by who cuts, halved for a strong body, halved again with a medkit.
static func shock_chance(medical: String, strength: int, kit: bool) -> float:
	var c := float(SHOCK.get(medical, SHOCK["none"]))
	if strength >= STRONG:
		c *= 0.5
	if kit:
		c *= 0.5
	return c


static func stump_kind(medical: String) -> String:
	return String(STUMP.get(medical, STUMP["none"]))


## A blade in the hands of either of them, the cutter's first ("" with none).
static func blade_of(medic, o) -> String:
	for who in [medic, o]:
		for h: Dictionary in who.hands:
			var id: String = String(h.get("id", ""))
			if bool(W.get_data(id).get("blade", false)):
				return id
	return ""


## The plan as one line for the body picture: "손도끼 · 지혈대(천+판자) ·
## 구급함 · 20초 · 비명이 온 지도에 들린다", or what stops it.
static func plan_text(p: Dictionary) -> String:
	if not bool(p["ok"]):
		return String(p["why"])
	var words: Array = [String(W.get_data(String(p["blade"])).get("name", p["blade"]))]
	var uses: Dictionary = p["uses"]
	if uses.has("tourniquet"):
		words.append(Carry.ITEM_NAMES["tourniquet"])
	else:
		var made: Array = []
		for id: String in uses:
			if id != "medkit":
				made.append(String(Carry.ITEM_NAMES.get(id, id)))
		words.append("지혈대(%s)" % "+".join(made))
	if bool(p["kit"]):
		words.append(Carry.ITEM_NAMES["medkit"])
	words.append("%d초" % roundi(float(p["seconds"])))
	words.append("비명이 온 지도에 들린다")
	return " · ".join(words)
