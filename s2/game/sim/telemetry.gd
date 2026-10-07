extends RefCounted
## One-line run log per field run (s2_station 3 '기록'). Times are field seconds.

const Receipt = preload("res://game/sim/receipt.gd")
const VERSION := 1

var run_id: String
var current_zone: String = ""
var zones: Dictionary = {}  # zone -> {"enter": Array[float], "seconds": float}, first-entered order
var noise_curve: Array[Array] = []  # [t, total]; only when the total changes
var hordes: Array[Dictionary] = []
var injuries: Array[Dictionary] = []
var ammo_used: Dictionary = {}
var carry_seconds: float = 0.0
var end_reason: String = ""
var end_t: float = -1.0


func _init(p_run_id: String = "") -> void:
	run_id = p_run_id


func zone_enter(zone: String, t: float) -> void:
	(_zone(zone)["enter"] as Array).append(t)
	current_zone = zone


func zone_tick(zone: String, delta: float) -> void:
	if delta <= 0.0:
		return
	var z: Dictionary = _zone(zone)
	z["seconds"] = float(z["seconds"]) + delta


func noise(t: float, total: int) -> void:
	if not noise_curve.is_empty() and int(noise_curve.back()[1]) == total:
		return
	noise_curve.append([t, total])


func horde(t: float, index: int, size: int, entry: String) -> void:
	hordes.append({"t": t, "index": index, "size": size, "entry": entry})


func injury(t: float, who: String, kind: String) -> void:
	injuries.append({"t": t, "who": who, "kind": kind})


## Rounds/shells spent; non-positive counts are ignored.
func ammo(kind: String, n: int) -> void:
	if n <= 0:
		return
	ammo_used[kind] = int(ammo_used.get(kind, 0)) + n


## Time spent hauling (carrying cargo toward the train).
func carry_time(delta: float) -> void:
	if delta > 0.0:
		carry_seconds += delta


## reason: "departed" | "limit" | "wiped" (same as receipt endReason).
func end(reason: String, t: float) -> bool:
	if not Receipt.END_REASONS.has(reason):
		return false
	end_reason = reason
	end_t = t
	return true


func to_dict() -> Dictionary:
	var zone_out := {}
	for zone: String in zones:
		var z: Dictionary = zones[zone]
		var enters: Array = []
		for t: float in z["enter"]:
			enters.append(_r(t))
		zone_out[zone] = {"enter": enters, "seconds": _r(z["seconds"])}
	var noise_out: Array = []
	for p: Array in noise_curve:
		noise_out.append([_r(p[0]), p[1]])
	var horde_out: Array = []
	for h: Dictionary in hordes:
		horde_out.append({"t": _r(h["t"]), "index": h["index"], "size": h["size"], "entry": h["entry"]})
	var injury_out: Array = []
	for i: Dictionary in injuries:
		injury_out.append({"t": _r(i["t"]), "who": i["who"], "kind": i["kind"]})
	return {
		"v": VERSION,
		"run": run_id,
		"end": end_reason,
		"staySec": _r(end_t) if end_t >= 0.0 else -1.0,
		"carrySec": _r(carry_seconds),
		"zones": zone_out,
		"noise": noise_out,
		"hordes": horde_out,
		"injuries": injury_out,
		"ammo": ammo_used.duplicate(),
	}


## Compact single-line JSON (append to a .jsonl log).
func to_json_line() -> String:
	return JSON.stringify(to_dict(), "", false)


func _zone(zone: String) -> Dictionary:
	if not zones.has(zone):
		zones[zone] = {"enter": [] as Array[float], "seconds": 0.0}
	return zones[zone]


static func _r(x: float) -> float:
	return snappedf(x, 0.1)
