extends RefCounted
## S1 domestic/workshop.ts, state.ts and lawtech.ts: insulation and furnishing.
## Starts pay once; only untouched jobs refund the recorded payment.

const TrainResearch = preload("res://game/train/train_research.gd")
const TrainDecor = preload("res://game/train/train_decor.gd")
const D: Dictionary = {
	"insulateWork": 3, "insulateWood": 8, "insulateWarm": 6,
	"insulateHeat": 0.3, "insulateCrowd": 2, "insulateQuotaHalf": false,
	"furnishClothWood": 0, "furnishFurnitureCap": 4, "furnishThreshold": [0, 3, 8, 15],
	"furnishWarm": [0, 1, 1, 2], "furnishCrowd": -0.5, "furnishRel": 2,
	"furnishGapMin": 1, "furnishGapMax": 2, "furnishGapRel": 0.5,
	"furnishGapCap": 2, "furnishPianoRel": 0.3,
}
const FURNISH_CARS: Array[String] = ["tail1", "tail2", "tail3", "medtech", "guard", "front"]
const FURNISH_STEPS: Array[int] = [1, 2, 3]
const FURNISH_NAMES: Array[String] = ["누더기", "손봄", "갖춤", "북유럽식"]
const FURNISH_WORK: Dictionary = {
	1: {"wood": 1, "scrap": 3, "cloth": 0, "parts": 0, "work": 1, "points": 3},
	2: {"wood": 1, "scrap": 6, "cloth": 2, "parts": 0, "work": 3, "points": 5},
	3: {"wood": 2, "scrap": 8, "cloth": 2, "parts": 2, "work": 4, "points": 7},
}
const FURNITURE_SIZE: Dictionary = {
	"small": {"slots": 4, "points": 1, "crowd": 0},
	"medium": {"slots": 2, "points": 2, "crowd": 0.5},
	"large": {"slots": 1, "points": 3, "crowd": 1.5},
}
const FURNITURE: Dictionary = TrainDecor.DECOR
const CAR_COMM: Dictionary = {
	"tail1": "tail", "tail2": "tail", "tail3": "tail", "medtech": "medtech",
	"guard": "guard", "front": "front", "engine": "engine",
}
const COMM_CARS: Dictionary = {"tail": 3, "medtech": 1, "guard": 1, "front": 1, "engine": 1}
const CAR_NAME: Dictionary = {
	"tail1": "꼬리칸 1", "tail2": "꼬리칸 2", "tail3": "꼬리칸 3", "cold": "냉동칸", "store": "창고칸",
	"medtech": "의무칸", "dining": "식당칸", "guard": "경비대칸", "captain": "열차장실",
	"front": "앞칸", "workshop": "공방칸", "engine": "기관실",
}
## S1 data.ts LAWS.heat_quota.mats, checked against mods-vectors-v1.
const HEAT_QUOTA_MATS: Dictionary = {"tail": [-10, 0, 0, 0], "medtech": [-10, 0, 0, 0], "guard": [-5, 0, 0, 0]}


static func _dom(g: Dictionary) -> Dictionary:
	return g["dom"] if g.get("dom") is Dictionary else {}


## Typed Array[int].has coerces its argument; validate before that can turn
## a fractional step into an integer job (JSON numbers arrive as floats).
static func is_furnish_step(step: Variant) -> bool:
	return (step is int or step is float) and is_finite(float(step)) \
		and float(step) == floorf(float(step)) and float(step) >= 1.0 and float(step) <= 3.0


static func job_check(g: Dictionary, kind: String, car: String, step: Variant = null) -> Dictionary:
	if kind not in ["insulate", "furnish"]:
		return {"ok": false, "why": "아직 이 열차에서 못 쓴다"}
	var d: Dictionary = _dom(g)
	if d.get("job") != null:
		return {"ok": false, "why": "개조 하나가 이미 줄에 있다"}
	if kind == "furnish":
		if not FURNISH_CARS.has(car):
			return {"ok": false, "why": "살림은 사람이 사는 객차 여섯 칸만"}
		var f: Dictionary = furnish_of(g, car)
		if step != null and not is_furnish_step(step):
			return {"ok": false, "why": "이미 살림 작업을 마쳤다"}
		var n: int = next_furnish_work(g, car) if step == null else int(step)
		if not FURNISH_STEPS.has(n) or (f["jobs"] as Array).has(n):
			return {"ok": false, "why": "이미 살림 작업을 마쳤다"}
		if int(f["tier"]) < n - 1:
			return {"ok": false, "why": "살림 %d단부터" % (n - 1)}
		if n == 2 and not (d.get("insulated", []) as Array).has(car):
			return {"ok": false, "why": "이 칸 단열부터"}
		if n >= 2 and TrainResearch.mult(g, {}, "w5") <= 0.0:
			return {"ok": false, "why": "객차 목공을 사용해야 한다"}
		if n == 3 and TrainResearch.mult(g, {}, "w1") <= 0.0:
			return {"ok": false, "why": "공구 수리부터"}
		var cost: Dictionary = furnish_cost(n)
		for key: String in ["wood", "scrap", "parts", "cloth"]:
			if float(d.get(key, 0)) < float(cost[key]):
				var word: String = {"wood": "목재", "scrap": "고철", "parts": "부품", "cloth": "천"}[key]
				return {"ok": false, "why": "%s %d이 든다" % [word, int(cost[key])]}
		return {"ok": true}
	if not TrainResearch.usable(g, {}, "e5"):
		return {"ok": false, "why": "단열 개조를 아직 모른다"}
	if not CAR_COMM.has(car):
		return {"ok": false, "why": "사람이 사는 칸만"}
	if (d.get("insulated", []) as Array).has(car):
		return {"ok": false, "why": "이미 단열했다"}
	if float(d.get("wood", 0)) < float(D["insulateWood"]):
		return {"ok": false, "why": "목재 %d이 든다" % int(D["insulateWood"])}
	return {"ok": true}


static func start_job(g: Dictionary, kind: String, car: String, step: Variant = null) -> bool:
	if not g.get("dom") is Dictionary or not bool(job_check(g, kind, car, step)["ok"]):
		return false
	var d: Dictionary = _dom(g)
	var n: int = next_furnish_work(g, car) if step == null else int(step)
	var cost: Dictionary = furnish_cost(n) if kind == "furnish" else {"wood": D["insulateWood"], "scrap": 0, "parts": 0, "work": D["insulateWork"]}
	var paid := {}
	for key: String in ["wood", "scrap", "parts", "cloth"]:
		if not cost.has(key):
			continue
		var before: float = float(d.get(key, 0))
		d[key] = before - float(cost[key])
		paid[key] = before - float(d[key])
	d["job"] = {"kind": kind, "car": car, "progress": 0.0, "need": cost["work"], "paid": paid}
	if kind == "furnish":
		d["job"]["furnishStep"] = n
	_journal(g, "공방 개조 줄에 올렸다: %s." % job_title(kind, car))
	return true


static func cancel_open(g: Dictionary) -> bool:
	var job: Variant = _dom(g).get("job")
	return job is Dictionary and float(job.get("progress", 0)) <= 0.0 and job.get("paid") is Dictionary


static func cancel_job(g: Dictionary) -> bool:
	if not cancel_open(g):
		return false
	var d: Dictionary = _dom(g)
	var job: Dictionary = d["job"]
	d["wood"] = float(d.get("wood", 0)) + float(job["paid"]["wood"])
	d["scrap"] = float(d.get("scrap", 0)) + float(job["paid"]["scrap"])
	d["parts"] = float(d.get("parts", 0)) + float(job["paid"].get("parts", 0))
	if job["paid"].has("cloth"):
		d["cloth"] = float(d.get("cloth", 0)) + float(job["paid"]["cloth"])
	d["job"] = null
	_journal(g, "공방 개조 줄에서 내렸다: %s." % job_title(String(job["kind"]), String(job["car"])))
	return true


## S1 runWorkshop's modify branch + completeJob.
## The event is S2's train-scene envelope; it is emitted only on completion.
static func advance_job(g: Dictionary, work: float) -> Dictionary:
	var out := {"used": 0.0, "did": [], "events": []}
	var d: Dictionary = _dom(g)
	var job: Variant = d.get("job")
	if work <= 0.0 or not job is Dictionary or job.get("kind") not in ["insulate", "furnish"] or not CAR_COMM.has(job.get("car")):
		return out
	if job["kind"] == "furnish" and (not FURNISH_CARS.has(job["car"]) or not is_furnish_step(job.get("furnishStep"))):
		return out
	var spend: float = minf(work, float(job["need"]) - float(job["progress"]))
	job["progress"] = float(job["progress"]) + spend
	out["used"] = spend
	if float(job["progress"]) >= float(job["need"]) - 1e-9:
		var car: String = String(job["car"])
		out["did"].append(job_title(String(job["kind"]), car))
		d["job"] = null
		if job["kind"] == "furnish":
			var f: Dictionary = _mutable_furnish(g, car)
			var n: int = int(job["furnishStep"])
			if not (f["jobs"] as Array).has(n):
				(f["jobs"] as Array).append(n)
			_update_furnish(g, car)
		else:
			if not d.has("insulated"):
				d["insulated"] = []
			(d["insulated"] as Array).append(car)
			_journal(g, "%s 벽의 틈을 메웠다. 밤바람이 덜 들고, 아침 창에 김이 서렸다." % CAR_NAME[car], "good")
		out["events"].append({"kind": "mod_done", "car": car, "comm": CAR_COMM[car],
			"sign": 1, "size": 0.4, "day": int(g.get("seg", 0))})
	return out


static func insulated_count(g: Dictionary, c: String) -> int:
	var n: int = 0
	for car: String in _dom(g).get("insulated", []):
		if CAR_COMM.get(car) == c:
			n += 1
	return n


static func insulated_share(g: Dictionary, c: String) -> float:
	return minf(1.0, float(insulated_count(g, c)) / float(COMM_CARS[c]))


## S1 insulateGain: positive numbers use JS Math.round's half-up rounding.
static func _insulate_gain(car: String) -> Dictionary:
	var c: String = String(CAR_COMM.get(car, ""))
	var share: float = 1.0 / float(COMM_CARS[c]) if c != "" else 1.0
	return {"warm": int(floorf(float(D["insulateWarm"]) * share + 0.5)),
		"heat": int(floorf(float(D["insulateHeat"]) * share * 10.0 + 0.5)),
		"crowd": int(floorf(float(D["insulateCrowd"]) + 0.5))}


static func insulate_numbers(car: String) -> String:
	var v: Dictionary = _insulate_gain(car)
	var parts: Array[String] = []
	if int(v["warm"]) > 0:
		parts.append("온기 +%d" % int(v["warm"]))
	if int(v["heat"]) > 0:
		parts.append("난방 −%d할" % int(v["heat"]))
	if int(v["crowd"]) > 0:
		parts.append("과밀 +%d" % int(v["crowd"]))
	return ", ".join(parts)


static func insulate_pick_line() -> String:
	var tail: String = insulate_numbers("tail1")
	var alone: String = insulate_numbers("medtech")
	if tail == "":
		return "벽 틈을 메운다. 「난방 배당」이 서 있으면 이 칸은 온기 벌을 받지 않는다."
	return "벽 틈을 메운다. 이 칸은 덜 춥고 석탄이 덜 든다. 대신 공기가 무거워진다. (칸이 여럿인 곳은 칸마다 %s, 혼자 사는 칸은 %s)" % [tail, alone]


static func insulate_car_note(g: Dictionary, car: String) -> String:
	if not (_dom(g).get("insulated", []) as Array).has(car):
		return ""
	var v: Dictionary = _insulate_gain(car)
	var gain: Array[String] = []
	if int(v["warm"]) > 0:
		gain.append("온기 +%d" % int(v["warm"]))
	if int(v["heat"]) > 0:
		gain.append("난방 −%d할" % int(v["heat"]))
	var parts: Array[String] = []
	if not gain.is_empty():
		parts.append("바람이 덜 든다(%s)" % ", ".join(gain))
	if int(v["crowd"]) > 0:
		parts.append("공기가 무겁다(과밀 +%d)" % int(v["crowd"]))
	return "단열: %s." % ". ".join(parts) if not parts.is_empty() else ""


static func job_title(kind: String, car: String) -> String:
	if kind == "furnish":
		return "%s 살림" % String(CAR_NAME.get(car, car))
	if kind != "insulate":
		return "아직 이 열차에서 못 쓴다"
	return "%s 단열" % String(CAR_NAME.get(car, car))


## S1 furnishOf: reading an older save never adds a key to it.
## The captain's and dining cars keep only {items}; they read like an untouched car around those items.
static func furnish_of(g: Dictionary, car: String) -> Dictionary:
	var f: Variant = _dom(g).get("furnish", {}).get(car)
	if f is Dictionary and f.has("tier"):
		return f
	return {"work": 0, "jobs": [], "furnPts": 0, "tier": 0, "best": 0, "items": f.get("items", []) if f is Dictionary else []}


static func furnish_score(g: Dictionary, car: String, items: Variant = null) -> int:
	var f: Dictionary = furnish_of(g, car)
	var furniture: int = int(f["furnPts"]) if items == null else TrainDecor.furniture_points(items)
	var points: int = mini(furniture, int(D["furnishFurnitureCap"]))
	for n: Variant in f["jobs"]:
		points += int(FURNISH_WORK[int(n)]["points"])
	return points


## Completed jobs are never removed, so their points preserve the work-only tier (517).
static func furnish_tier(g: Dictionary, car: String, items: Array) -> int:
	var score: int = furnish_score(g, car, items)
	var reached: int = 0
	for n: int in FURNISH_STEPS:
		if score >= int(D["furnishThreshold"][n]):
			reached = n
	return reached


## S1 furnishAfter: the score and tier once that job is done. A car whose furniture
## left can finish a job without reaching the next tier.
static func furnish_after(g: Dictionary, car: String, step: int) -> Dictionary:
	var score: int = furnish_score(g, car) + int(FURNISH_WORK[step]["points"])
	var reached: int = 0
	for n: int in FURNISH_STEPS:
		if score >= int(D["furnishThreshold"][n]):
			reached = n
	return {"score": score, "tier": maxi(int(furnish_of(g, car)["tier"]), reached)}


## 0 means no next work (S1 undefined). Retained tiers can need an earlier job
## after furniture has been removed, so do not simply count completed jobs.
static func next_furnish_work(g: Dictionary, car: String) -> int:
	var f: Dictionary = furnish_of(g, car)
	if int(f["tier"]) >= 3:
		return 0
	var next: int = int(f["tier"]) + 1
	if not (f["jobs"] as Array).has(next):
		return next
	for n: int in FURNISH_STEPS:
		if n <= next and not (f["jobs"] as Array).has(n):
			return n
	return 0


## S2 pays actual cloth, not S1's cloth-to-wood conversion (currently zero).
static func furnish_cost(step: int) -> Dictionary:
	if not FURNISH_WORK.has(step):
		return {}
	var cost: Dictionary = FURNISH_WORK[step]
	return {"wood": cost["wood"], "scrap": cost["scrap"], "parts": cost["parts"], "work": cost["work"], "cloth": cost["cloth"]}


static func _mutable_furnish(g: Dictionary, car: String) -> Dictionary:
	var d: Dictionary = _dom(g)
	if not d.has("furnish"):
		d["furnish"] = {}
	if not d["furnish"].has(car):
		d["furnish"][car] = furnish_of(g, car)
	var f: Dictionary = d["furnish"][car]
	f["best"] = maxi(int(f.get("best", f["tier"])), int(f["tier"]))
	return d["furnish"][car]


## Same clamped relationship + 64-entry ledger as turn_common.bump_rel.
## Kept here to avoid the State -> Dom -> Mods -> State preload cycle.
static func _bump_furnish_rel(g: Dictionary, c: String, delta: float) -> void:
	if delta == 0.0 or not g.get("comms", {}).has(c):
		return
	var s: Dictionary = g["comms"][c]
	var before: float = float(s["rel"])
	s["rel"] = clampf(before + delta, -100.0, 100.0)
	var real: float = float(s["rel"]) - before
	if real == 0.0:
		return
	if not g.has("ledger"):
		g["ledger"] = []
	g["ledger"].append({"k": "rel:" + c, "d": real, "why": "furnish"})
	if g["ledger"].size() > 64:
		g["ledger"] = g["ledger"].slice(g["ledger"].size() - 64)


static func _update_furnish(g: Dictionary, car: String) -> void:
	var f: Dictionary = _mutable_furnish(g, car)
	f["work"] = f["jobs"].size()
	var points: int = TrainDecor.furniture_points(f["items"])
	f["furnPts"] = mini(int(D["furnishFurnitureCap"]), points)
	f["tier"] = furnish_tier(g, car, f["items"])
	var c: String = CAR_COMM[car]
	var changes: Dictionary = {1: "벽을 맞추고 잠자리를 손봤다", 2: "선반과 식탁이 들어섰다", 3: "붙박이 침대가 들어섰다"}
	for n: int in FURNISH_STEPS:
		if n > int(f["best"]) and n <= int(f["tier"]):
			_bump_furnish_rel(g, c, float(D["furnishRel"]) * n / float(COMM_CARS[c]))
			_journal(g, "%s에 살림 %d단: %s. %s에서 그 소리를 들었다." % [CAR_NAME[car], n, changes[n], "앞칸" if c == "tail" else "꼬리칸"], "good")
	f["best"] = maxi(int(f["best"]), int(f["tier"]))


static func place_furniture(g: Dictionary, car: String, kind: String) -> Dictionary:
	if not FURNITURE.has(kind) or not FURNITURE[kind]["furniture"]:
		return {"ok": false, "why": "알 수 없는 가구"}
	return place(g, car, kind, FURNITURE[kind]["spot"])


static func remove_furniture(g: Dictionary, car: String, index: Variant) -> Dictionary:
	return take_back(g, car, index)


static func can_place(g: Dictionary, car: String, kind: String, spot: String, at: Variant = null, rot: Variant = null, on: Variant = null) -> Dictionary:
	return TrainDecor.can_place(g, car, kind, spot, at, rot, on)


static func slots_open(g: Dictionary, car: String) -> Dictionary:
	return TrainDecor.slots_open(g, car)


static func place(g: Dictionary, car: String, kind: String, spot: String, at: Variant = null, rot: Variant = null, on: Variant = null) -> Dictionary:
	var check: Dictionary = can_place(g, car, kind, spot, at, rot, on)
	if not check["ok"]:
		return check
	var def: Dictionary = TrainDecor.DECOR[kind]
	var store: Dictionary = g["dom"]["store"]
	var entry: Dictionary = store[kind]
	var item: Dictionary = {"kind": kind, "size": def["size"], "spot": spot}
	if at != null: item["at"] = at.duplicate()
	if rot != null: item["rot"] = rot
	if on != null: item["on"] = on
	if def.has("res"):
		var tag: Dictionary = TrainDecor.oldest(entry)
		g[def["res"]] = float(g.get(def["res"], 0)) - float(tag["v"])
		item["v"] = tag["v"]
		entry["tags"].erase(tag)
	entry["n"] -= 1
	if entry["n"] == 0:
		store.erase(kind)
	if FURNISH_CARS.has(car):
		_mutable_furnish(g, car)["items"].append(item)
		_update_furnish(g, car)
	else:
		var d: Dictionary = g["dom"]
		if not d.has("furnish"): d["furnish"] = {}
		if not d["furnish"].has(car): d["furnish"][car] = {"items": []}
		d["furnish"][car]["items"].append(item)
	return {"ok": true}


static func _placed(g: Dictionary, car: String, index: Variant) -> Dictionary:
	if not g.get("dom") is Dictionary or not TrainDecor.DECOR_CARS.has(car) or not TrainDecor.integer(index):
		return {}
	var items: Array = TrainDecor.items_of(g, car)
	return items[int(index)] if float(index) < items.size() else {}


static func move(g: Dictionary, car: String, index: Variant, at: Variant, rot: Variant = null) -> Dictionary:
	var item: Dictionary = _placed(g, car, index)
	if item.is_empty():
		return {"ok": false, "why": "그 자리에 물건이 없다"}
	if at == null or not TrainDecor.valid_at(at) or not TrainDecor.valid_rot(rot):
		return {"ok": false, "why": "자리나 회전 값이 올바르지 않다"}
	item["at"] = at.duplicate()
	if rot != null: item["rot"] = rot
	return {"ok": true}


static func rotate(g: Dictionary, car: String, index: Variant, rot: Variant) -> Dictionary:
	var item: Dictionary = _placed(g, car, index)
	if item.is_empty():
		return {"ok": false, "why": "그 자리에 물건이 없다"}
	if rot == null or not TrainDecor.valid_rot(rot):
		return {"ok": false, "why": "자리나 회전 값이 올바르지 않다"}
	item["rot"] = rot
	return {"ok": true}


static func take_back(g: Dictionary, car: String, index: Variant) -> Dictionary:
	var item: Dictionary = _placed(g, car, index)
	if item.is_empty():
		return {"ok": false, "why": "그 자리에 물건이 없다"}
	var items: Array = TrainDecor.items_of(g, car)
	var removed: Array = []
	for j: int in items.size():
		if TrainDecor.spot_of(items[j]) == "surface" and items[j].get("on") == index:
			removed.append(j)
	removed.append(int(index))
	var remap: Dictionary = {}
	var kept: Array = []
	for j: int in items.size():
		if not removed.has(j):
			remap[j] = kept.size()
			kept.append(items[j])
	if FURNISH_CARS.has(car):
		var tier: int = furnish_tier(g, car, kept)
		if tier < int(furnish_of(g, car)["tier"]):
			var common: int = 0
			for other: String in FURNISH_CARS:
				common = maxi(common, tier if other == car else int(furnish_of(g, other)["tier"]))
			var fits: bool = TrainDecor.slots_fit(car, kept, tier)
			if common < TrainDecor.common_tier(g):
				for other: String in ["captain", "dining"]:
					fits = fits and TrainDecor.slots_fit(other, TrainDecor.items_of(g, other), common)
			if not fits:
				return {"ok": false, "why": "살림이 내려가면 자리가 모자란다. 다른 것부터 거둬라"}
	# A rejected removal must not even reconcile stored resource tags.
	var store: Dictionary = TrainDecor.read_store(g)
	for j: int in removed:
		var row: Dictionary = items[j]
		var def: Dictionary = TrainDecor.DECOR[row["kind"]]
		if def.has("res") and row.has("v"):
			g[def["res"]] = float(g.get(def["res"], 0)) + float(row["v"])
		TrainDecor.add_stored(store, row["kind"], row.get("v") if def.has("res") else null)
	for row: Dictionary in kept:
		if row.has("on"): row["on"] = remap[int(row["on"])]
	g["dom"]["furnish"][car]["items"] = kept
	if FURNISH_CARS.has(car): _update_furnish(g, car)
	return {"ok": true}


static func _journal(g: Dictionary, text: String, tone: String = "") -> void:
	if not g.get("journal") is Array:
		g["journal"] = []
	var entry := {"seg": int(g.get("seg", 0)), "text": text}
	if tone != "":
		entry["tone"] = tone
	g["journal"].append(entry)
