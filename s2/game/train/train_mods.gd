extends RefCounted
## PR 4: S1 domestic/workshop.ts and lawtech.ts, insulation only.
## Starts pay once; only untouched jobs refund the recorded payment.

const TrainResearch = preload("res://game/train/train_research.gd")
const D: Dictionary = {
	"insulateWork": 3, "insulateWood": 8, "insulateWarm": 6,
	"insulateHeat": 0.3, "insulateCrowd": 2, "insulateQuotaHalf": false,
}
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


static func job_check(g: Dictionary, kind: String, car: String) -> Dictionary:
	if kind != "insulate":
		return {"ok": false, "why": "아직 이 열차에서 못 쓴다"}
	var d: Dictionary = _dom(g)
	if d.get("job") != null:
		return {"ok": false, "why": "개조 하나가 이미 줄에 있다"}
	if not TrainResearch.usable(g, {}, "e5"):
		return {"ok": false, "why": "단열 개조를 아직 모른다"}
	if not CAR_COMM.has(car):
		return {"ok": false, "why": "사람이 사는 칸만"}
	if (d.get("insulated", []) as Array).has(car):
		return {"ok": false, "why": "이미 단열했다"}
	if float(d.get("wood", 0)) < float(D["insulateWood"]):
		return {"ok": false, "why": "목재 %d이 든다" % int(D["insulateWood"])}
	return {"ok": true}


static func start_job(g: Dictionary, kind: String, car: String) -> bool:
	if not bool(job_check(g, kind, car)["ok"]):
		return false
	var d: Dictionary = _dom(g)
	var wood0: float = float(d.get("wood", 0))
	d["wood"] = wood0 - float(D["insulateWood"])
	d["job"] = {"kind": kind, "car": car, "progress": 0.0, "need": D["insulateWork"],
		"paid": {"wood": wood0 - float(d["wood"]), "scrap": 0.0}}
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
	d["job"] = null
	_journal(g, "공방 개조 줄에서 내렸다: %s." % job_title(String(job["kind"]), String(job["car"])))
	return true


## S1 runWorkshop's modify branch + completeJob's insulation branch.
## The event is S2's train-scene envelope; it is emitted only on completion.
static func advance_job(g: Dictionary, work: float) -> Dictionary:
	var out := {"used": 0.0, "did": [], "events": []}
	var d: Dictionary = _dom(g)
	var job: Variant = d.get("job")
	if work <= 0.0 or not job is Dictionary or job.get("kind") != "insulate" or not CAR_COMM.has(job.get("car")):
		return out
	var spend: float = minf(work, float(job["need"]) - float(job["progress"]))
	job["progress"] = float(job["progress"]) + spend
	out["used"] = spend
	if float(job["progress"]) >= float(job["need"]) - 1e-9:
		var car: String = String(job["car"])
		out["did"].append(job_title("insulate", car))
		d["job"] = null
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
	if kind != "insulate":
		return "아직 이 열차에서 못 쓴다"
	return "%s 단열" % String(CAR_NAME.get(car, car))


static func _journal(g: Dictionary, text: String, tone: String = "") -> void:
	if not g.get("journal") is Array:
		g["journal"] = []
	var entry := {"seg": int(g.get("seg", 0)), "text": text}
	if tone != "":
		entry["tone"] = tone
	g["journal"].append(entry)
