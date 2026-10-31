extends RefCounted
const Budget = preload("res://game/train/turn/turn_budget.gd")
## S1 council_log.ts: the council record and the result arc (정치 흐름 P1, 결정 439). A record, not a new gauge.
## The record keeps only its last rows; the promise counts (comms[c].kept·broken) and the lasting
## limit (openClosed) stay for the whole run. tests/politics/test_field_port.gd and
## tests/train/test_train_advance.gd check it against S1 through the field and turn vectors;
## tests/politics/test_council_log.gd checks the arc branches.

const CouncilMath = preload("res://game/politics/council_math.gd")

## S1 ARC and LOG_MAX (values proposed, set by the bot). The vectors' tables carry the same.
const ARC := {"ledgerAt": 2, "closeAt": 3, "heldFails": 2, "heldRel": -5, "harshLaws": 3, "harshRel": -3}
const LOG_MAX := 24
const LEDGER_MAX := 64
const DIGIT_FINAL := {"0": "final", "1": "rieul", "2": "none", "3": "final", "4": "none", "5": "none", "6": "final", "7": "rieul", "8": "rieul", "9": "none"}


static func _journal(g: Dictionary, text: String, tone: Variant = null) -> void:
	var row := {"seg": g["seg"], "text": text}
	if tone != null:
		row["tone"] = tone
	(g["journal"] as Array).append(row)


static func _bump_rel(g: Dictionary, comm: String, delta: float, why: String) -> void:
	var state: Dictionary = g["comms"][comm]
	var before := float(state["rel"])
	state["rel"] = maxf(-100.0, minf(100.0, before + delta))
	var moved := float(state["rel"]) - before
	if moved == 0.0:
		return
	if not g.get("ledger") is Array:
		g["ledger"] = []
	var rows: Array = g["ledger"]
	rows.append({"k": "rel:%s" % comm, "d": moved, "why": why})
	while rows.size() > LEDGER_MAX:
		rows.pop_front()


static func _add_card(g: Dictionary, value: Dictionary, t: Dictionary = {}) -> void:
	var row: Dictionary = {"uid": g["nextCardUid"]}
	row.merge(value)
	g["nextCardUid"] = int(g["nextCardUid"]) + 1
	(g["cards"] as Array).append(row)
	Budget.on_add(g, t)


## S1 josa for the pairs this file uses (은/는, 이/가).
static func _josa(word: String, pair: String) -> String:
	var halves := pair.split("/")
	var last := word.strip_edges().right(1)
	var final := String(DIGIT_FINAL.get(last, "none"))
	if not last.is_empty():
		var code := last.unicode_at(0)
		if code >= 0xac00 and code <= 0xd7a3:
			var jong := (code - 0xac00) % 28
			final = "none" if jong == 0 else ("rieul" if jong == 8 else "final")
	return halves[1] if final == "none" else halves[0]


## S1 voteWhy: one line on the car whose undecided or leader-brought seats split furthest from
## what was expected. turned holds, per car, how many of each went yes. Null under one seat.
static func vote_why(t: Dictionary, map: Dictionary, turned: Dictionary) -> Variant:
	var best_gap := -1.0
	var best: Variant = null
	for comm: String in t["COMMS"]:
		var b: Dictionary = map[comm]
		if not turned.has(comm):
			continue
		var name: String = t["COMM_NAME"][comm]
		var und := int(b["und"])
		if und > 0:
			var p := CouncilMath.undecided_chance(int(b["score"]))
			var exp := und * p
			var gap := absf(int(turned[comm]["und"]) - exp)
			if gap >= 1.0 and (best == null or gap > best_gap):
				best_gap = gap
				best = "%s 미정 %d석 가운데 %d석이 찬성했다(기대 %d석, 한 석마다 찬성 %d%%)." % [name, und, int(turned[comm]["und"]), _round(exp), _round(p * 100.0)]
		var pool := int(b["pool"])
		if pool > 0:
			var chance := float(b["poolChance"])
			var exp := pool * chance
			var gap := absf(int(turned[comm]["pool"]) - exp)
			if gap >= 1.0 and (best == null or gap > best_gap):
				best_gap = gap
				best = "%s 대표가 끌고 오겠다던 %d석 가운데 %d석이 따랐다(기대 %d석, 결속 %d%%)." % [name, pool, int(turned[comm]["pool"]), _round(exp), _round(chance * 100.0)]
	return best


## JS Math.round: halves go up.
static func _round(x: float) -> int:
	return int(floor(x + 0.5))


static func log_vote(g: Dictionary, row: Dictionary) -> void:
	if not g.get("councilLog") is Array:
		g["councilLog"] = []
	var log: Array = g["councilLog"]
	log.append(row)
	while log.size() > LOG_MAX:
		log.pop_front()


static func _harsh_count(g: Dictionary, t: Dictionary) -> int:
	var n := 0
	for law: String in t["LAWS"]:
		if t["LAWS"][law].get("tag") == "가혹" and (g.get("passed", {}) as Dictionary).has(law):
			n += 1
	return n


## Called right after a promise to `comm` is broken (once its broken count went up).
static func note_broken(g: Dictionary, t: Dictionary, comm: String) -> void:
	var s: Dictionary = g["comms"][comm]
	var n := int(s.get("broken", 0))
	var name: String = t["COMM_NAME"][comm]
	if _harsh_count(g, t) >= int(ARC["harshLaws"]):
		_bump_rel(g, comm, float(ARC["harshRel"]), "arc")
		_journal(g, "%s에서 말이 돈다: \"법은 모질게 세우면서 약속은 가볍게 어긴다.\"" % name, "bad")
	if n == int(ARC["ledgerAt"]):
		_add_card(g, {"kind": "promise_ledger", "comm": comm}, t)
	if n >= int(ARC["closeAt"]) and not bool(s.get("openClosed", false)):
		s["openClosed"] = true
		_journal(g, "%s%s 더는 열차장의 약속을 받지 않는다." % [name, _josa(name, "은/는")], "bad")


## After a vote: counts the fails of an agenda picked by the car handed the choice. A pass clears it.
static func note_held(g: Dictionary, t: Dictionary, comm: String, passed: bool) -> void:
	var s: Dictionary = g["comms"][comm]
	if passed:
		s["heldFails"] = 0
		return
	s["heldFails"] = int(s.get("heldFails", 0)) + 1
	if int(s["heldFails"]) < int(ARC["heldFails"]):
		return
	s["heldFails"] = 0
	_bump_rel(g, comm, float(ARC["heldRel"]), "arc")
	var name: String = t["COMM_NAME"][comm]
	_journal(g, "%s%s 고른 안건이 또 떨어졌다. 들러리를 섰다고 여긴다." % [name, _josa(name, "이/가")], "bad")
