extends RefCounted
## The land's next section (결정 495 1절, 7b 「구간마다 고유하게, 다 보기 어렵게」): a
## kind of land (wood, lake shore, field, village edge …) that goes on for a while,
## then another. Never the same kind twice running, and never a run of three kinds
## that began within REPEAT_S of running time before: when every kind would make
## one, the section under way goes on a little longer instead, till an old run has
## gone out of the window. Each section draws its own mirror and dressing seed, so
## the same kind never comes dressed the same way. Times are seconds of running
## (distance over the run speed): the land is laid ahead by distance.

## How long a run of three kinds keeps from coming again (gauge: 10 minutes, 0 repeats).
const REPEAT_S: float = 600.0
## A section that cannot be followed yet goes on by this much (seconds).
const EXTEND_S := Vector2(15.0, 30.0)
## A short bare stretch between, of a kind no window lays (journey_kit.gd lays ground
## and poles only for it): where a new window leaves no kind open and the last kind is
## not one of its own to go on with, it breaks the run instead of repeating one.
const BRIDGE := "plain"

var rng := RandomNumberGenerator.new()
## Sections begun, oldest first: {kind, at, len_s, mirror, seed}.
var history: Array = []
## How many times a section was lengthened instead of a run coming again.
var extended: int = 0
## How many bare stretches went between (a window change that left no kind open).
var bridged: int = 0


func setup(seed_value: int) -> void:
	rng.seed = seed_value
	history.clear()
	extended = 0
	bridged = 0


## The section that begins at `at` (seconds of running) from `kinds`, rows of
## {kind, weight, len_s: Vector2}: {kind, at, len_s, mirror, seed, extend}. With
## extend true it is more of the section under way (the same kind and dressing).
func next(at: float, kinds: Array) -> Dictionary:
	var rows: Array = kinds.filter(func(r: Dictionary) -> bool: return float(r.get("weight", 1.0)) > 0.0)
	if rows.is_empty():
		return {}
	var last: String = String(history[-1]["kind"]) if not history.is_empty() else ""
	var open: Array = _open(rows, at, history)
	if open.is_empty() and last != "":
		var cur: Dictionary = history[-1]
		var more: float = rng.randf_range(EXTEND_S.x, EXTEND_S.y)
		if _row(rows, last).size() > 0 or last == BRIDGE:
			# Every kind would repeat a run (or there is no other): this one goes on.
			extended += 1
			cur["len_s"] = float(cur["len_s"]) + more
			return {"kind": last, "at": at, "len_s": more, "mirror": bool(cur["mirror"]), "seed": int(cur["seed"]), "extend": true}
		# A new window without the last kind, and every kind of it would repeat a run.
		bridged += 1
		var bridge := {"kind": BRIDGE, "at": at, "len_s": more, "mirror": false, "seed": rng.randi(), "extend": false}
		history.append(bridge.duplicate())
		return bridge
	# Open is never empty here (the first section has no last kind). One step ahead: a
	# kind after which some kind can still follow is better.
	var pool: Array = open
	var mid: float = at + _mean_len(rows)
	var ahead: Array = pool.filter(func(r: Dictionary) -> bool:
		var h: Array = history.duplicate()
		h.append({"kind": String(r["kind"]), "at": at})
		return not _open(rows, mid, h).is_empty())
	if not ahead.is_empty():
		pool = ahead
	var row: Dictionary = _pick(pool)
	var span: Vector2 = row.get("len_s", Vector2(40.0, 90.0))
	var section := {"kind": String(row["kind"]), "at": at, "len_s": rng.randf_range(span.x, span.y),
		"mirror": rng.randf() < 0.5, "seed": rng.randi(), "extend": false}
	history.append(section.duplicate())
	return section


## The kinds that may come next after `h` at `at`: not the last kind, and not one
## that makes a run of three already begun within REPEAT_S.
static func _open(rows: Array, at: float, h: Array) -> Array:
	var last: String = String(h[-1]["kind"]) if h.size() >= 1 else ""
	var prev: String = String(h[-2]["kind"]) if h.size() >= 2 else ""
	var start: float = float(h[-2]["at"]) if h.size() >= 2 else at
	var out: Array = []
	for r: Dictionary in rows:
		var k: String = String(r["kind"])
		if k == last:
			continue
		if prev != "" and _run_seen(h, prev, last, k, start):
			continue
		out.append(r)
	return out


## Whether the run a, b, c began within REPEAT_S before `start` (the run's own start).
static func _run_seen(h: Array, a: String, b: String, c: String, start: float) -> bool:
	for i in range(h.size() - 2):
		if start - float(h[i]["at"]) >= REPEAT_S:
			continue
		if String(h[i]["kind"]) == a and String(h[i + 1]["kind"]) == b and String(h[i + 2]["kind"]) == c:
			return true
	return false


static func _row(rows: Array, kind: String) -> Dictionary:
	for r: Dictionary in rows:
		if String(r["kind"]) == kind:
			return r
	return {}


static func _mean_len(rows: Array) -> float:
	var total: float = 0.0
	for r: Dictionary in rows:
		var span: Vector2 = r.get("len_s", Vector2(40.0, 90.0))
		total += (span.x + span.y) * 0.5
	return total / maxf(float(rows.size()), 1.0)


func _pick(pool: Array) -> Dictionary:
	var total: float = 0.0
	for r: Dictionary in pool:
		total += float(r.get("weight", 1.0))
	var x: float = rng.randf() * total
	for r: Dictionary in pool:
		x -= float(r.get("weight", 1.0))
		if x <= 0.0:
			return r
	return pool[-1]


## The gauge (결정 495 6절): how many runs of three kinds came again within REPEAT_S
## of the same run's last start, plus how many times a kind followed itself, in
## `h` (sections, extensions not counted).
static func repeats(h: Array) -> int:
	var n: int = 0
	for i in range(1, h.size()):
		if String(h[i]["kind"]) == String(h[i - 1]["kind"]):
			n += 1
	for i in range(h.size() - 2):
		for j in range(i):
			if float(h[i]["at"]) - float(h[j]["at"]) >= REPEAT_S:
				continue
			if String(h[i]["kind"]) == String(h[j]["kind"]) and String(h[i + 1]["kind"]) == String(h[j + 1]["kind"]) \
					and String(h[i + 2]["kind"]) == String(h[j + 2]["kind"]):
				n += 1
				break
	return n
