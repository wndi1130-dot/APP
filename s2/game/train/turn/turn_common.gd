extends RefCounted
## S1 state.ts / ledger.ts primitives. Mutate only the caller's working copy.

const State = preload("res://game/train/train_state.gd")
const Rng = preload("res://game/politics/rng.gd")

static func rnd(g: Dictionary) -> float:
	var draw: Array = Rng.next(int(g["rng"]["state"]))
	g["rng"]["state"] = draw[1]
	return float(draw[0])

static func hash_text(value: String) -> int:
	var h: int = 2166136261
	for i: int in value.length(): h = Rng.imul(h ^ value.unicode_at(i), 16777619)
	return h & 0xffffffff

static func local_rng(key: String) -> Dictionary:
	return {"rng": {"state": hash_text(key)}}

static func journal(g: Dictionary, line: String, tone: String = "") -> void:
	if not g.has("journal"): g["journal"] = []
	var row: Dictionary = {"seg": g["seg"], "text": line}
	if tone != "": row["tone"] = tone
	g["journal"].append(row)

static func card(g: Dictionary, value: Dictionary) -> void:
	var row: Dictionary = {"uid": g["nextCardUid"]}
	row.merge(value)
	g["nextCardUid"] = int(g["nextCardUid"]) + 1
	g["cards"].append(row)

static func has_card(g: Dictionary, kind: String) -> bool:
	for row: Dictionary in g["cards"]:
		if row["kind"] == kind: return true
	return false

static func note(g: Dictionary, key: String, delta: float, why: String) -> void:
	if delta == 0.0: return
	if not g.has("ledger"): g["ledger"] = []
	g["ledger"].append({"k": key, "d": delta, "why": why})
	if g["ledger"].size() > 64: g["ledger"] = g["ledger"].slice(g["ledger"].size() - 64)

static func bump(g: Dictionary, key: String, delta: float, why: String, floor_zero: bool = false) -> void:
	var before: float = float(g[key])
	var value: float = before + delta
	g[key] = clampf(value, 0, 100) if key in ["trust", "tension"] else (maxf(0, value) if floor_zero else value)
	note(g, key, float(g[key]) - before, why)

static func put(g: Dictionary, key: String, value: float, why: String) -> void:
	var before: float = float(g[key])
	g[key] = value
	note(g, key, value - before, why)

static func bump_rel(g: Dictionary, comm: String, delta: float, why: String) -> void:
	var s: Dictionary = g["comms"][comm]
	var before: float = float(s["rel"])
	s["rel"] = clampf(before + delta, -100, 100)
	note(g, "rel:" + comm, float(s["rel"]) - before, why)

static func bump_parts(g: Dictionary, key: String, delta: float, parts: Array, floor_zero: bool = false) -> void:
	var before: float = float(g[key])
	var value: float = before + delta
	g[key] = clampf(value, 0, 100) if key in ["trust", "tension"] else (maxf(0, value) if floor_zero else value)
	var real: float = float(g[key]) - before
	if real == 0 or parts.is_empty(): return
	for row: Array in split_parts(real, parts): note(g, key, float(row[1]), str(row[0]))

## How bump_parts lays `real` over its parts' weights, [[why, share], ...]; the
## last takes what is left. The train's cost pane splits the forecast so too, so
## the forecast's rows are the ledger's (J12).
static func split_parts(real: float, parts: Array) -> Array:
	var total: float = 0
	for part: Array in parts: total += float(part[1])
	var out: Array = []
	var left: float = real
	for i: int in parts.size():
		var share: float = left if i == parts.size() - 1 or total == 0 else real * (float(parts[i][1]) / total)
		left -= share
		out.append([str(parts[i][0]), share])
	return out

static func profile(t: Dictionary, value: String, key: String = "name") -> Dictionary:
	for p: Dictionary in t["PROFILES"]:
		if p[key] == value: return p
	return {}

static func is_leader(g: Dictionary, t: Dictionary, who: String) -> bool:
	for c: String in t["COMMS"]:
		if g["comms"][c]["leader"]["name"] == who: return true
	return false

static func hub(g: Dictionary) -> Dictionary:
	if not g.has("hub") or g["hub"] == null: g["hub"] = {"warned": [], "stash": {}, "agreed": []}
	return g["hub"]

static func unsupported(g: Dictionary, reason: String) -> Dictionary:
	var out: Dictionary = g.duplicate(true)
	out["_turn_port_error"] = "F-NOT-PORTED: " + reason
	return out
