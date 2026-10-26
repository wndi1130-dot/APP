extends RefCounted
## The train's workshop (decision 426 PR 3): it makes parts up to a target and
## one thing on its line at a time from the stores (train_dom.gd), a stretch's
## work each time the train leaves a stop. S1's workshop (s1/src/game/domestic/
## workshop.ts runWorkshop) with its numbers (domestic/data.ts D); what S2 does
## not have yet (the craftsman's skill, the workshop car's place, the W1
## technique) stands as a constant until it comes over.
##
## The three things to make are decision 070's (decisions.md 「공방 '만들기'는
## 셋부터다」): the hunting bow and the crowbar go to the armory as the field
## carries weapons, the long coat to the wardrobe. What they cost and how long
## they take are new values (the PR's table). What they do is the field's: the
## train only holds them.
##
## The work is shared: parts, the making line, restoration, then insulation.
## Making a thing slows a refit (decision 070); the order is fixed in S2.
##
## A stretch (`stretch`) is S1 domesticSettle's order: the running technologies
## take their upkeep from the stores first (payUpkeep), then the workshop works
## (`run`, S1 runWorkshop). One the stores cannot keep runs at half that
## stretch (train_research.gd pay_upkeep, mult). S1's 「부품이 모자란다」 card is
## not here yet: S2 runs on, as that card's 「그냥 달린다」.

const TrainDom = preload("res://game/train/train_dom.gd")
const TrainHands = preload("res://game/train/train_hands.gd")
const TrainResearch = preload("res://game/train/train_research.gd")
const TrainLawTech = preload("res://game/train/train_lawtech.gd")
const TrainMods = preload("res://game/train/train_mods.gd")

## S1 D.work, D.workSkill[2] (숙련), ZONE_WORK.front, W1 off: a stretch's work.
const WORK: float = 4.0
const SKILL: float = 1.0
const ZONE: float = 1.0
## S1 D.partWork, D.partScrap, D.partWood: one part.
const PART_WORK: float = 1.0
const PART_SCRAP: float = 2.0
const PART_WOOD: float = 1.0
## S1 D.target0, D.targetMax: how many parts the workshop keeps.
const TARGET0: int = 5
const TARGET_MAX: int = 10
## How well the train's workshop makes a weapon (weapons.gd QUALITY).
const QUALITY: String = "usable"
## The stores' names on the screen.
const STORE_NAME: Dictionary = {"scrap": "고철", "wood": "목재", "parts": "부품", "cloth": "천"}
## Decision 070's three: name, what they cost, the work they take, where they go.
const RECIPES: Dictionary = {
	"bow": {"name": "사냥 활", "cost": {"wood": 4, "scrap": 1}, "work": 3.0, "to": "armory"},
	"crowbar": {"name": "쇠지렛대", "cost": {"scrap": 4}, "work": 2.0, "to": "armory"},
	"coat_long": {"name": "두꺼운 겉옷", "cost": {"cloth": 4}, "work": 3.0, "to": "wardrobe"},
}
const ORDER: Array[String] = ["bow", "crowbar", "coat_long"]


## A stretch's work.
static func work_power(g: Dictionary = {}, t: Dictionary = {}) -> float:
	return TrainResearch.work_power(g, t)


## How many parts the workshop keeps.
static func target(g: Dictionary) -> int:
	return int((g["dom"] as Dictionary).get("target", TARGET0))


static func set_target(g: Dictionary, n: int) -> void:
	TrainDom.ensure(g)
	g["dom"]["target"] = clampi(n, 0, TARGET_MAX)


## What is on the line: {id, progress, need, paid}, or null.
static func line(g: Dictionary) -> Variant:
	return (g["dom"] as Dictionary).get("make")


## Why `id` cannot go on the line now ("" when it can): another thing on it,
## or the store it lacks most and by how much (「고철 2 모자람」).
static func why_not(g: Dictionary, id: String) -> String:
	if not RECIPES.has(id):
		return "만들 수 없다"
	var dom: Dictionary = g.get("dom", {})
	if dom.get("make") != null:
		return "다른 것을 만드는 중"
	var cost: Dictionary = RECIPES[id]["cost"]
	for key: String in cost:
		var short: float = float(cost[key]) - float(dom.get(key, 0))
		if short > 0.0:
			return "%s %s 모자람" % [STORE_NAME.get(key, key), _num(short)]
	return ""


## Put `id` on the line: its stores are paid now. False when it cannot.
static func start(g: Dictionary, id: String) -> bool:
	TrainDom.ensure(g)
	if why_not(g, id) != "":
		return false
	var dom: Dictionary = g["dom"]
	var cost: Dictionary = RECIPES[id]["cost"]
	var paid := {}
	for key: String in cost:
		dom[key] = float(dom.get(key, 0)) - float(cost[key])
		paid[key] = float(cost[key])
	dom["make"] = {"id": id, "progress": 0.0, "need": float(RECIPES[id]["work"]), "paid": paid}
	return true


## Take the line back while the workshop has not touched it: what was paid
## comes back whole (S1 cancelOpen). False once work has gone into it.
static func cancel(g: Dictionary) -> bool:
	var dom: Dictionary = g.get("dom", {})
	var m: Variant = dom.get("make")
	if not m is Dictionary or float(m["progress"]) > 0.0:
		return false
	var paid: Dictionary = m["paid"]
	for key: String in paid:
		dom[key] = float(dom.get(key, 0)) + float(paid[key])
	dom["make"] = null
	return true


## A stretch leaving a stop: the upkeep, then the work. `run`'s answer with
## "starved", the running technologies whose upkeep the stores could not pay.
static func stretch(g: Dictionary) -> Dictionary:
	TrainDom.ensure(g)
	var starved: Array[String] = TrainResearch.pay_upkeep(g)
	var out: Dictionary = run(g)
	out["starved"] = starved
	return out


## A stretch of work (the train leaving a stop): parts up to the target while
## the stores last, then the line. {"parts": made, "made": [ids], "events": [...]}
## — the events in the train scene's form (train_scene post_event).
static func run(g: Dictionary) -> Dictionary:
	TrainDom.ensure(g)
	var dom: Dictionary = g["dom"]
	var w: float = work_power(g)
	var initial_work: float = w
	var did: Array[String] = []
	var parts_made: int = 0
	var made: Array[String] = []
	var events: Array = []
	var want: int = target(g)
	while w > 0.0 and float(dom.get("parts", 0)) < float(want) \
			and float(dom.get("scrap", 0)) >= PART_SCRAP and float(dom.get("wood", 0)) >= PART_WOOD:
		var done_part: float = float(dom.get("partWork", 0.0))
		var spend: float = minf(w, PART_WORK - done_part)
		done_part += spend
		w -= spend
		if done_part >= PART_WORK - 1e-9:
			done_part = 0.0
			dom["scrap"] = float(dom["scrap"]) - PART_SCRAP
			dom["wood"] = float(dom["wood"]) - PART_WOOD
			dom["parts"] = float(dom.get("parts", 0)) + 1.0
			parts_made += 1
		dom["partWork"] = done_part
	if parts_made > 0:
		did.append("부품 %d" % parts_made)
	var m: Variant = dom.get("make")
	if w > 0.0 and m is Dictionary:
		var spend_line: float = minf(w, float(m["need"]) - float(m["progress"]))
		m["progress"] = float(m["progress"]) + spend_line
		w -= spend_line
		if float(m["progress"]) >= float(m["need"]) - 1e-9:
			var id: String = String(m["id"])
			_deliver(dom, id)
			dom["make"] = null
			made.append(id)
			# No workshop car on S2's train yet: the train as a whole made it.
			events.append({"kind": "made", "car": "", "comm": "", "sign": 1, "size": 0.4, "day": int(g.get("seg", 0))})
	# Preserve the existing making line immediately after parts. Restoration
	# receives the remaining work (S1 parts -> restore when no making is queued).
	var restored: Dictionary = TrainResearch.advance_restore(g, w)
	w -= float(restored["used"])
	did.append_array(restored["did"])
	# A standing law the restored technology bends says so (S1 completeTech's lawTechNews).
	if restored.get("done") != null:
		for news: String in TrainLawTech.news(g, String(restored["done"])):
			if not g.get("journal") is Array:
				g["journal"] = []
			g["journal"].append({"seg": int(g.get("seg", 0)), "text": news, "tone": "good"})
	var modified: Dictionary = TrainMods.advance_job(g, w)
	w -= float(modified["used"])
	did.append_array(modified["did"])
	events.append_array(modified["events"])
	return {"parts": parts_made, "made": made, "events": events, "used": initial_work - w, "did": did}


## What the workshop is doing for the screen: the line's thing and how far
## along (0..1), or parts, or nothing; and the share of a stretch it waits.
static func now(g: Dictionary) -> Dictionary:
	var dom: Dictionary = g.get("dom", {})
	var m: Variant = dom.get("make")
	if m is Dictionary:
		return {"id": String(m["id"]), "share": clampf(float(m["progress"]) / maxf(float(m["need"]), 1e-9), 0.0, 1.0),
			"can_cancel": float(m["progress"]) <= 0.0}
	return {"id": "", "share": 0.0, "can_cancel": false}


static func _deliver(dom: Dictionary, id: String) -> void:
	if String(RECIPES[id]["to"]) == "wardrobe":
		if not dom.get("wardrobe") is Array:
			dom["wardrobe"] = []
		(dom["wardrobe"] as Array).append({"id": id, "condition": 1.0})
	else:
		if not dom.get("armory") is Array:
			dom["armory"] = []
		(dom["armory"] as Array).append({"id": id, "quality": QUALITY, "condition": 1.0})


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
