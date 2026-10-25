extends RefCounted
## S1 hands.ts: the cars offer hands; settle stores the next stretch's share.
## Read functions use that stored share, never a fresh estimate. No share at
## the start (or in an old save) means no missing work. Tables come from S1.

const JOB_NAME := {"stoker": "화실 교대", "stove": "난로와 물", "watch": "지붕 보초", "roof": "지붕 얼음과 선로", "repair": "고칠 손"}
const TRACK := ["water_tower", "snow_drift"]
## Older field fixtures and the workshop have callers without HANDS tables.
## This fallback is checked in full against S1's exported HANDS by the tests.
const HANDS := {
	"order": ["stoker", "stove", "watch", "roof", "repair"],
	"need": {"stoker": 12, "stove": 24, "watch": 12, "roof": 18, "repair": 8},
	"willCold": 0.85, "willHostile": 0.7, "willRefuse": 0.4,
	"leverLow": 0.85, "leverCut": 0.7,
	"stokerCoal": 3, "stoveWarm": 10, "watchRisk": 0.5, "repairWork": 0.5,
	"roofOver": 0.5, "roofTrack": 2, "loadFree": 0.55, "loadExpose": 40,
}
const JOB_SHORT := {"stoker": "화실", "stove": "난로", "watch": "보초", "roof": "선로", "repair": "수리"}


static func work_share(t: Dictionary, c: String) -> float:
	var total := 0
	var working := 0
	for person: Dictionary in t["PROFILES"]:
		if person["community"] == c:
			total += 1
			if float(person["age"]) >= 16.0 and float(person["age"]) <= 65.0:
				working += 1
	return float(working) / float(total) if total > 0 else 0.75


static func hands_will(g: Dictionary, t: Dictionary, c: String) -> float:
	var s: Dictionary = g["comms"][c]
	var h: Dictionary = t.get("HANDS", HANDS)
	var will := 1.0
	if float(s["rel"]) <= -40.0:
		will = float(h["willRefuse"] if float(s["fervor"]) >= 1.0 else h["willHostile"])
	elif float(s["rel"]) < -15.0:
		will = float(h["willCold"])
	var lever := minf(float(s["heat"]), float(s["ration"]))
	if lever <= 0.0:
		will *= float(h["leverCut"])
	elif lever <= 1.0:
		will *= float(h["leverLow"])
	return will


static func hands_offered(g: Dictionary, t: Dictionary, c: String) -> float:
	var s: Dictionary = g["comms"][c]
	return maxf(0.0, float(s["pop"]) - float(s["away"])) * work_share(t, c) * hands_will(g, t, c)


static func hands_now(g: Dictionary, t: Dictionary) -> Dictionary:
	var h: Dictionary = t.get("HANDS", HANDS)
	var have := 0.0
	for c: String in t["COMMS"]:
		have += hands_offered(g, t, c)
	have = maxf(0.0, have - float(g.get("injured", 0)))
	var left := have
	var need := 0.0
	var short := {}
	for job: String in h["order"]:
		var n := float(h["need"][job])
		need += n
		var got := minf(n, left)
		left -= got
		short[job] = 1.0 - got / n
	var over := maxf(0.0, minf(1.0, need / maxf(1.0, have)) - float(h["loadFree"]))
	var expose := {}
	for c: String in t["COMMS"]:
		expose[c] = float(h["loadExpose"]) * over * hands_will(g, t, c) if over > 0.0 and hands_offered(g, t, c) > 0.0 else 0.0
	return {"have": have, "short": short, "expose": expose}


## Same copy/return convention as train_turn. The caller owns the note list.
static func settle(g0: Dictionary, t: Dictionary, notes: Array) -> Dictionary:
	var g := g0.duplicate(true)
	g["hands"] = hands_now(g, t)
	var line := shortage_line(g, t)
	if not line.is_empty():
		notes.append(line)
	return g


static func hand_short(g: Dictionary, job: String) -> float:
	var h: Variant = g.get("hands")
	if not h is Dictionary:
		return 0.0
	return float((h.get("short", {}) as Dictionary).get(job, 0.0))


static func hands_coal(g: Dictionary, t: Dictionary) -> float:
	var h: Dictionary = t.get("HANDS", HANDS)
	return float(h["stokerCoal"]) * hand_short(g, "stoker")


static func hands_watch_mult(g: Dictionary, t: Dictionary) -> float:
	var h: Dictionary = t.get("HANDS", HANDS)
	return 1.0 + float(h["watchRisk"]) * hand_short(g, "watch")


static func hands_work_mult(g: Dictionary, t: Dictionary = {}) -> float:
	var h: Dictionary = t.get("HANDS", HANDS)
	return 1.0 - float(h["repairWork"]) * hand_short(g, "repair")


static func hands_track_boost(g: Dictionary, t: Dictionary, pool: Array) -> Array:
	var h: Dictionary = t.get("HANDS", HANDS)
	if hand_short(g, "roof") <= float(h["roofOver"]):
		return pool
	var out := pool.duplicate()
	for id: String in TRACK:
		if pool.has(id):
			for i in range(1, int(h["roofTrack"])):
				out.append(id)
	return out


## Shared by settle and the read-only carriage pane; the threshold is S1's.
static func shortage_line(g: Dictionary, t: Dictionary, compact: bool = false) -> String:
	var empty: Array[String] = []
	var h: Dictionary = t.get("HANDS", HANDS)
	for job: String in h["order"]:
		if hand_short(g, job) > 0.01:
			empty.append(JOB_SHORT[job] if compact else JOB_NAME[job])
	if empty.is_empty():
		return ""
	return ("일손 부족 · %s 빈다." if compact else "일손이 모자라 %s이(가) 빈다.") % "·".join(empty)
