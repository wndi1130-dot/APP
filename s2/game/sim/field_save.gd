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
## The train's own save (politics/save_slot.gd DEFAULT_PATH): read here only for what it applied.
const TRAIN_PATH := "user://s1a_game_v2.json"
const DeadPose = preload("res://game/actors/dead_pose.gd")
const EatRules = preload("res://game/sim/eat_rules.gd")
const Wear = preload("res://game/sim/wear.gd")

## Keys that hold a place in the field: [x, y, z] in the file, Vector3 here.
const VEC_KEYS := ["pos", "home"]
## Start options that are not the world: the switch itself and what goes in its own keys.
const NOT_START := ["field_save", "field_save_path", "field_resume", "departure", "receipt_id"]
## What a body may be doing when it comes back: anything mid-act (a grab, a lunge,
## a horde on the march) wakes up wandering, since who it was after is not saved.
const RESUME_STATES := ["frozen", "wander", "downed", "dead", "rising"]


## What the field is now, as plain data. `game` is a field_game.gd.
static func capture(game) -> Dictionary:
	var people: Array = []
	for p in game.people:
		people.append(_person(game, p))
	var zombies: Array = []
	if game.zombies != null:
		for z in game.zombies.list:
			var row := {"id": int(z["id"]), "kind": String(z["kind"]), "pos": z["pos"], "state": String(z["state"]), "loot": (z.get("loot", []) as Array).duplicate(true), "searched": bool(z.get("searched", false)), "horde": int(z.get("horde", -1)), "name": String(z.get("name", "")), "home": z.get("home", z["pos"])}
			# What it has on, once rolled or taken from (decision 434); unrolled it rolls the same again.
			if z.has("worn"):
				row["worn"] = (z["worn"] as Dictionary).duplicate(true)
				row["stripped"] = bool(z.get("stripped", false))
			zombies.append(row)
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
		"ground_items": ground, "unloaded": game.unloaded.duplicate(), "loaded_wear": game.loaded_wear.duplicate(true),
		"coal": {"delivered": game.actions.coal_delivered if game.actions != null else 0, "spent": game.actions.coal_spent if game.actions != null else 0},
		"zombies": zombies, "decisions": game.decisions.duplicate(true),
		# The return's id, the same as the receipt's receiptId: the train side applies it once.
		"receipt_id": String(said.get("receiptId", game.opts.get("receipt_id", ""))),
		"departure": departure,
		# The same seed builds the same stop only with the same start options.
		"start_opts": _start_opts(game.opts),
		# What the receipt has gathered so far (deaths, who saw what, notes): its own fields as they are.
		"receipt_state": _receipt_state(game.receipt) if game.receipt != null else {},
	}


static func _start_opts(opts: Dictionary) -> Dictionary:
	var out := opts.duplicate(true)
	for key in NOT_START:
		out.erase(key)
	return out


static func _person(game, p) -> Dictionary:
	var b = p.body
	return {
		"pid": p.pid, "team": p.team, "pos": p.position, "level": game.level_of(p.position), "alive": p.is_alive(),
		"bag": p.bag, "items": p.items.duplicate(), "hands": p.hands.duplicate(true), "wear": Wear.save_of(p),
		"body": {"wounds": b.wounds.duplicate(true), "infection": b.infection, "infected": b.infected, "window": b.window_left, "lost": b.lost.duplicate(), "exhaustion": b.exhaustion, "downed": b.downed, "dead": b.dead},
		"eaten": float(p.get_meta(EatRules.EATEN_META, 0.0)),
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
		# An arrow saved before it took the stock's name (decision 426).
		if g.get("id") == "arrow":
			g["id"] = "ammo_craft"
	for key in ["ammo", "unloaded"]:
		var counts: Dictionary = d.get(key, {})
		for id in counts:
			counts[id] = int(counts[id])
	for p in d.get("people", []):
		p["level"] = int(p["level"])
		for id in p["items"]:
			p["items"][id] = int(p["items"][id])
		for h in p["hands"]:
			if h.has("loaded"):
				h["loaded"] = int(h["loaded"])
	return d


## Whether the field is where play goes on when the app starts again: a stop still
## being played whose return the train has not taken in yet. `applied` is the train
## save's fieldReturns.applied (receipt ids; a Dictionary there, a list is read too).
static func should_resume(save: Dictionary, applied = {}) -> bool:
	if save.is_empty() or String(save.get("phase", "")) != "field":
		return false
	var id := String(save.get("receipt_id", ""))
	if id == "":
		return true
	if applied is Dictionary:
		return not (applied as Dictionary).has(id)
	return not (applied as Array).has(id)


## Where the app starts (S3 spec 4, user decision 296): the field save and the
## train save are read, and a stop still being played whose return the train has
## not taken in comes back. Returns the start options for it, or {} to start fresh.
static func pick_start(field_path: String = PATH, train_path: String = TRAIN_PATH) -> Dictionary:
	var save := read(field_path)
	if not should_resume(save, train_applied(train_path)):
		return {}
	var opts := resume_opts(save)
	opts["field_save_path"] = field_path
	return opts


## The receipt ids the train save has taken in (its fieldReturns.applied), {} when none.
static func train_applied(train_path: String = TRAIN_PATH) -> Dictionary:
	if not FileAccess.file_exists(train_path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(train_path)) != OK or not json.data is Dictionary:
		return {}
	var returns = (json.data as Dictionary).get("fieldReturns")
	if not returns is Dictionary or not returns.get("applied") is Dictionary:
		return {}
	return returns["applied"]


## The options that build the same stop again and then put the save on it.
static func resume_opts(save: Dictionary) -> Dictionary:
	var opts: Dictionary = (save.get("start_opts", {}) as Dictionary).duplicate(true)
	opts["seed"] = int(save.get("seed", 0))
	opts["place"] = String(save.get("place", ""))
	opts["mission"] = String(save.get("mission", ""))
	if not (save.get("departure", {}) as Dictionary).is_empty():
		opts["departure"] = (save["departure"] as Dictionary).duplicate(true)
	if String(save.get("receipt_id", "")) != "":
		opts["receipt_id"] = String(save["receipt_id"])
	opts["field_resume"] = save
	return opts


## Puts a save on a field just built from resume_opts(save). Not brought back:
## hordes on their way and the director's budget, the goals' and the held train's
## progress, what each companion was told to do. They start again from the stop's start.
static func apply(game, save: Dictionary) -> void:
	game.skip_arrival()
	game.clock.elapsed = float(save["clock"]["elapsed"])
	game.clock.speed = float(save["clock"]["speed"])
	for row: Dictionary in save.get("people", []):
		for p in game.people:
			if p.pid == String(row["pid"]):
				_put_person(p, row)
	_put_counts(game.ammo, save.get("ammo", {}))
	game.unloaded.clear()
	_put_counts(game.unloaded, save.get("unloaded", {}))
	game.loaded_wear = (save.get("loaded_wear", []) as Array).duplicate(true)
	game.actions.coal_delivered = float(save["coal"]["delivered"])
	game.actions.coal_spent = float(save["coal"]["spent"])
	var boxes: Dictionary = game.data.get("containers", {})
	for id in save.get("containers", {}):
		if boxes.has(id):  # a heap pulled together during the stop is not on the map yet
			var row: Dictionary = save["containers"][id]
			boxes[id]["searched"] = bool(row["searched"])
			boxes[id]["locked"] = bool(row["locked"])
			boxes[id]["items"] = (row["items"] as Array).duplicate(true)
	for id in save.get("spots", {}):
		if game.data["spots"].has(id):
			game.data["spots"][id]["state"] = String(save["spots"][id])
	game.ground_items = (save.get("ground_items", []) as Array).duplicate(true)
	game.decisions = (save.get("decisions", []) as Array).duplicate(true)
	_put_zombies(game, save.get("zombies", []))
	if game.receipt != null:
		_put_receipt(game.receipt, save.get("receipt_state", {}))
	game.cam_focus = game.player.position
	game._update_camera(1.0)
	game._refresh_vision()


static func _put_person(p, row: Dictionary) -> void:
	p.cancel_action()
	p.stop()
	p.position = row["pos"]
	p.bag = String(row["bag"])
	p.items = (row["items"] as Dictionary).duplicate(true)
	# A save from before the three places has none: they keep what they put on.
	Wear.restore(p, row.get("wear", {}))
	p.set_weapon_slots((row["hands"] as Array).duplicate(true))
	var b = p.body
	var body: Dictionary = row["body"]
	b.wounds.assign(body["wounds"])
	b.infection = String(body["infection"])
	b.infected = bool(body["infected"])
	# A save from before the cut (J05) has neither: the window reads as closed.
	b.window_left = float(body.get("window", 0.0))
	b.lost.assign(body.get("lost", []))
	b.exhaustion = float(body["exhaustion"])
	b.downed = bool(body["downed"])
	b.dead = bool(body["dead"])
	# How long the dead have eaten at this body (결정 441 (3)): one eaten up stays so. None before it.
	p.set_meta(EatRules.EATEN_META, float(row.get("eaten", 0.0)))


static func _put_counts(into: Dictionary, counts: Dictionary) -> void:
	for id in counts:
		into[id] = int(counts[id])


static func _put_zombies(game, rows: Array) -> void:
	var all = game.zombies
	all.list.clear()
	var top := 0
	for row: Dictionary in rows:
		var z: Dictionary = all.spawn(String(row["kind"]), row["pos"], {"horde": int(row["horde"]), "name": String(row["name"])})
		var state := String(row["state"])
		if state in ["downed", "dead"]:
			DeadPose.mark_fall(z, game.people)  # lies as it fell, not standing
		z["id"] = int(row["id"])
		z["state"] = state if state in RESUME_STATES else "wander"
		z["loot"] = (row["loot"] as Array).duplicate(true)
		z["searched"] = bool(row["searched"])
		# Where it keeps to: its pockets and clothes are rolled by that place when first asked.
		if row.get("home") is Vector3:
			z["home"] = row["home"]
		if row.get("worn") is Dictionary:
			z["worn"] = (row["worn"] as Dictionary).duplicate(true)
			z["stripped"] = bool(row.get("stripped", false))
		top = maxi(top, int(row["id"]))
	all.next_id = top + 1


## The receipt's own fields, read and written back as they are (it has no loader of
## its own). Typed lists keep their type: they are filled, not replaced.
static func _receipt_state(r) -> Dictionary:
	var out := {}
	for prop in r.get_property_list():
		var name := String(prop["name"])
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and name.begins_with("_"):
			var v = r.get(name)
			out[name] = v.duplicate(true) if (v is Array or v is Dictionary) else v
	return out


static func _put_receipt(r, state: Dictionary) -> void:
	for name in state:
		var now = r.get(name)
		var v = state[name]
		if now is Array:
			(now as Array).assign(v)
		elif now is Dictionary:
			var into: Dictionary = now
			for key in into.keys():
				if not (v as Dictionary).has(key):
					into.erase(key)
			for key in v:
				if into.get(key) is Array:
					(into[key] as Array).assign(v[key])  # the people lists are typed
				else:
					into[key] = v[key]
		elif now is int:
			r.set(name, int(v))
		elif now is float:
			r.set(name, float(v))
		elif now is bool:
			r.set(name, bool(v))
		elif now is String:
			r.set(name, String(v))


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
