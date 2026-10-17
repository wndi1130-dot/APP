extends RefCounted
## The field's one save slot (S3 spec 4, user decision 296): what a stop has
## come to, as one JSON file, written over each time. No loading by hand, no
## going back: the last whole save is the only one, and a broken file falls
## back to the one before it (.bak).
##
## capture() only reads the field; to_json/from_json and write/read are plain
## functions over a Dictionary. Only S2 reads this file (its keys are its own);
## the train keeps its own save (user://s1a_game_v2.json). On start the field
## save wins while its phase is "field", unless the train already applied its
## receipt_id (S3 PR #428).

const VERSION := 1
const KIND := "s2_field"
const PATH := "user://field_save.json"

## Keys that hold a place in the field: [x, y, z] in the file, Vector3 here.
const VEC_KEYS := ["pos"]


## What the field is now, as plain data. `game` is a field_game.gd.
static func capture(game) -> Dictionary:
	var people: Array = []
	for p in game.people:
		people.append(_person(game, p))
	var zombies: Array = []
	if game.zombies != null:
		for z in game.zombies.list:
			zombies.append({"id": int(z["id"]), "kind": String(z["kind"]), "pos": z["pos"], "state": String(z["state"]), "loot": (z.get("loot", []) as Array).duplicate(true), "searched": bool(z.get("searched", false)), "horde": int(z.get("horde", -1)), "name": String(z.get("name", ""))})
	var containers := {}
	for id in game.data.get("containers", {}):
		var c: Dictionary = game.data["containers"][id]
		containers[String(id)] = {"searched": bool(c.get("searched", false)), "locked": bool(c.get("locked", false)), "items": (c.get("items", []) as Array).duplicate(true)}
	var spots := {}
	for id in game.data.get("spots", {}):
		spots[String(id)] = String(game.data["spots"][id].get("state", ""))
	var ground: Array = []
	for g in game.ground_items:
		ground.append(g.duplicate(true))  # {pos, id, n} and a dropped gun's own row
	var said: Dictionary = game.receipt.to_dict() if game.receipt != null else {}
	# The departure order is the train side's contract (S3 spec): kept whole, inside untouched.
	var departure: Dictionary = (game.opts.get("departure", {}) as Dictionary).duplicate(true)
	var stop_id := String(departure.get("stopId", said.get("stopId", game.opts.get("stop_id", ""))))
	return {
		"version": VERSION, "kind": KIND,
		"stop_id": stop_id, "place": game.place, "mission": game.mission,
		"seed": int(game.rng.seed), "phase": "ended" if game.ended else "field", "end_reason": String(said.get("endReason", "")),
		"saved_at": game.clock.label(), "clock": {"elapsed": game.clock.elapsed, "speed": game.clock.speed},
		"player_pid": game.player.pid if game.player != null else "",
		"people": people, "ammo": game.ammo.duplicate(), "containers": containers, "spots": spots,
		"ground_items": ground, "unloaded": game.unloaded.duplicate(),
		"coal": {"delivered": game.actions.coal_delivered if game.actions != null else 0, "spent": game.actions.coal_spent if game.actions != null else 0},
		"zombies": zombies, "decisions": game.decisions.duplicate(true),
		# The return's id, the same as the receipt's receiptId: the train side applies it once.
		"receipt_id": String(said.get("receiptId", game.opts.get("receipt_id", ""))),
		"departure": departure,
	}


static func _person(game, p) -> Dictionary:
	var b = p.body
	return {
		"pid": p.pid, "team": p.team, "pos": p.position, "level": game.level_of(p.position), "alive": p.is_alive(),
		"bag": p.bag, "items": p.items.duplicate(), "hands": p.hands.duplicate(true),
		"body": {"wounds": b.wounds.duplicate(true), "infection": b.infection, "infected": b.infected, "exhaustion": b.exhaustion, "downed": b.downed, "dead": b.dead},
	}


static func to_json(d: Dictionary) -> String:
	return JSON.stringify(_encode(d), "", false)


## The save in `text`, or {} when it is not a whole save of this kind and version.
static func from_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:  # a cut-off file is expected here, not an engine error
		return {}
	var parsed = json.data
	if not parsed is Dictionary:
		return {}
	if String(parsed.get("kind", "")) != KIND or int(parsed.get("version", 0)) != VERSION:
		return {}
	var d: Dictionary = _decode(parsed)
	d["version"] = int(d["version"])
	d["seed"] = int(d.get("seed", 0))
	for z in d.get("zombies", []):
		z["id"] = int(z["id"])
		z["horde"] = int(z["horde"])
	for g in d.get("ground_items", []):
		g["n"] = int(g["n"])
	for key in ["ammo", "unloaded"]:
		var counts: Dictionary = d.get(key, {})
		for id in counts:
			counts[id] = int(counts[id])
	for p in d.get("people", []):
		p["level"] = int(p["level"])
		for id in p["items"]:
			p["items"][id] = int(p["items"][id])
	return d


## Writes over the slot: the new file goes down whole first, the last one is kept as .bak.
static func write(d: Dictionary, path: String = PATH) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(to_json(d))
	f.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp, path) == OK


## The last whole save: the slot, or the one before it when the slot is broken; {} when none.
static func read(path: String = PATH) -> Dictionary:
	for at in [path, path + ".bak"]:
		if FileAccess.file_exists(at):
			var d := from_json(FileAccess.get_file_as_string(at))
			if not d.is_empty():
				return d
	return {}


static func clear(path: String = PATH) -> void:
	for at in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(at):
			DirAccess.remove_absolute(at)


static func _encode(v):
	if v is Vector3:
		return [v.x, v.y, v.z]
	if v is Dictionary:
		var out := {}
		for k in v:
			out[String(k)] = _encode(v[k])
		return out
	if v is Array:
		var out: Array = []
		for e in v:
			out.append(_encode(e))
		return out
	return v


static func _decode(v):
	if v is Dictionary:
		var out := {}
		for k in v:
			var e = v[k]
			if k in VEC_KEYS and e is Array and e.size() == 3:
				out[k] = Vector3(float(e[0]), float(e[1]), float(e[2]))
			else:
				out[k] = _decode(e)
		return out
	if v is Array:
		var out: Array = []
		for e in v:
			out.append(_decode(e))
		return out
	return v
