extends RefCounted
## S1 riot.ts (정치 흐름 P2, #699): the unrest ladder — protest, riot, last chance —
## and the traces its three answers leave (ignore, yield, guard). The ember multiplier
## is S1b only and has no port here. Values are S1 LADDER verbatim.
const C = preload("res://game/train/turn/turn_common.gd")
const St = preload("res://game/train/train_state.gd")
const W = preload("res://game/train/turn/turn_wounds.gd")
const Death = preload("res://game/train/turn/turn_death.gd")
const Field = preload("res://game/politics/field_return.gd")

const LADDER := {
	"ignoreAgain": 3, "yieldDrop": 5, "yieldSegs": 2,
	"guardTension": -6, "guardFear": 5, "guardRel": -2, "guardEmberMult": 2, "guardEmberSegs": 6,
}


## The tension a protest card rises at (lower just after a concession).
static func protest_line(g: Dictionary, t: Dictionary) -> float:
	var r: Dictionary = g.get("riot", {})
	var drop: bool = r.has("yieldUntil") and int(g["seg"]) <= int(r["yieldUntil"])
	return float(t["P"]["protestFrom"]) - (float(LADDER["yieldDrop"]) if drop else 0.0)


## Whether the guard follows an order to hold the corridor; null when it does.
static func guard_refuses(g: Dictionary) -> Variant:
	return "경비대가 따르지 않는다" if float(g["comms"]["guard"]["rel"]) <= -40.0 else null


static func ignore(g: Dictionary) -> void:
	g["riot"]["ignoredAt"] = g["seg"]


static func concede(g: Dictionary) -> void:
	var r: Dictionary = g["riot"]
	r["yieldUntil"] = int(g["seg"]) + int(LADDER["yieldSegs"]) - 1
	r.erase("ignoredAt")


## Guards stand bare-handed in the corridor between people; no one is locked in or dragged off.
static func guard(g: Dictionary, comm: String) -> void:
	var r: Dictionary = g["riot"]
	Field._offend(g, comm)
	if g["comms"][comm].get("promise") is Dictionary:
		Field._offend(g, comm)
		C.journal(g, "약속을 걸어 둔 채 경비대를 세웠다. 그 칸이 따로 기억한다.", "bad")
	C.bump_rel(g, "guard", float(LADDER["guardRel"]), "ladder")
	g["fear"] = clampf(float(g["fear"]) + float(LADDER["guardFear"]), 0, 100)
	r["guardUntil"] = int(g["seg"]) + int(LADDER["guardEmberSegs"]) - 1
	r["guardComm"] = comm
	r.erase("ignoredAt")


## S1 riotEnd: the riot settles after the demand card is answered.
static func riot_end(g: Dictionary, t: Dictionary) -> void:
	var r: Dictionary = g["riot"]
	if int(r["stage"]) != 2: return
	r["stage"] = 1 if float(g["tension"]) >= float(t["P"]["protestFrom"]) else 0
	C.journal(g, "난장판이 가라앉았다.", "good")


## S1 riotFell: n adults fall; each dies with P.riotDeath, the rest are hurt. The person
## memory module reads riot_fell; car relations are not touched.
static func riot_fell(g: Dictionary, t: Dictionary, n: int) -> void:
	var p: Dictionary = t["P"]
	var r: Dictionary = g["riot"]
	var pool: Array = []
	for person: Dictionary in t["PROFILES"]:
		if int(person["age"]) < 16 or int(person["age"]) > 64 or C.is_leader(g, t, person["name"]) or St.is_gone(g, person["name"]): continue
		var wounded: bool = false
		for w: Dictionary in W.active(g):
			if w["who"] == person["name"]: wounded = true
		if not wounded: pool.append(person)
	var dead: int = 0
	var hurt: int = 0
	for _i: int in n:
		if pool.is_empty(): break
		var idx: int = int(floor(C.rnd(g) * pool.size()))
		var person: Dictionary = pool[idx]
		pool.remove_at(idx)
		if C.rnd(g) < float(p["riotDeath"]):
			Death.on_death(g, t, person["community"], [person["name"]], "other", false, true)
			dead += 1
		else:
			g["injured"] += 1
			W.note_injury(g, t, 1, "brawl", "난장판", {"names": [person["name"]], "comm": person["community"]})
			hurt += 1
		if not g.get("personEvents") is Array: g["personEvents"] = []
		g["personEvents"].append({"key": "riot_fell", "who": person["id"], "seg": g["seg"], "comm": person["community"]})
	r["fell"] += dead + hurt
	r["died"] += dead
	if dead + hurt > 0: C.journal(g, "싸움이 번져 어른 %d명이 쓰러졌다.%s" % [dead + hurt, " 그중 %d명은 일어나지 못했다." % dead if dead > 0 else " 모두 숨은 붙어 있다."], "bad")
