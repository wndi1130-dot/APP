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

const VERSION := 2
const KIND := "s2_field"
const PATH := "user://field_save.json"
## The train's own save (politics/save_slot.gd DEFAULT_PATH): read here only for what it applied.
const TRAIN_PATH := "user://s1a_game_v2.json"
const DeadPose = preload("res://game/actors/dead_pose.gd")
const EatRules = preload("res://game/sim/eat_rules.gd")
const Wear = preload("res://game/sim/wear.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const StopForm = preload("res://game/sim/stop_form.gd")

## Keys that hold a place in the field: [x, y, z] in the file, Vector3 here.
const VEC_KEYS := ["pos", "home"]
## Start options that are not the world: the switch itself and what goes in its own keys.
const NOT_START := ["field_save", "field_save_path", "field_resume", "departure", "receipt_id", "map_data", "vat", "staged"]
## Version 1 did not store targets or timers; keep its original fallback.
const RESUME_STATES := ["frozen", "wander", "downed", "dead", "rising"]

## Only simulation state, never meshes, services or input widgets.
const PERSON_FIELDS: Array[String] = [
	"team", "role", "display_name", "skills", "medical", "hunger_level", "sore_level", "smell", "traits", "lamp", "lamp_on",
	"path", "running", "crouched", "facing", "turn_rate", "look", "moving", "stick", "drive_speed", "drive_dir",
	"command", "command_target", "action", "action_label", "action_t", "action_total", "action_done", "action_busy",
	"action_noise_t", "swing_t", "shove_t", "lunge_t", "strike_t", "strike_total", "strike_at", "strike_kind",
	"reload_t", "jam_t", "target_zombie", "target_person", "hold_attack", "grabbers", "grab_left", "grab_front",
	"climbing", "carrying_wounded", "downed_marked", "dead_marked", "brain", "panic", "ice_t", "fallen_t",
	"last_hurt_by", "blood_soaked", "close_kills",
]
const GAME_FIELDS: Array[String] = [
	"squad", "crew", "raiders",
	"rng", "eat_rng", "hordes", "pending_spawn", "last_loud", "rattle", "lid_open", "waiting", "cap",
	"ammo_start", "loaded_start", "cloth_start", "shot_times", "blood", "sounds", "alarms", "named_seen",
	"glints", "key_ways", "note_spot", "lures", "lure_marks", "body_searches", "loot_report", "rode_off",
	"forecast_t", "forecast_precision", "deaf_t", "casings", "last_gun_t", "radio", "radio_wait", "radio_wait_t",
	"radio_last", "radio_rings", "radio_t", "zone_now", "auto_paused_once", "dark_noise_t", "safe_warned",
	"glass_warned", "player_downed_t", "spotted_events", "unseen_rattle", "lid_tip_told", "roof_seen",
	"seen_now", "seen_memory", "vis_t", "cam_focus", "cam_push", "cam_size",
]
const COMPONENTS: Array[String] = ["director", "ledger", "mission_play", "holdout", "actions", "ai", "combat", "lines", "weather", "telemetry", "train_guard", "work"]
## "dead_eaten_seconds" is EatRules.EATEN_META (결정 441 (3)).
const PERSON_META: Array[String] = ["dead_regrab_until", "pose_mode", "pose_blow_way", "pose_care", "pose_swing", "dead_eaten_seconds"]


## What the field is now, as plain data. `game` is a field_game.gd.
static func capture(game) -> Dictionary:
	var people: Array = []
	for p in game.people:
		people.append(_person(game, p))
	var zombies: Array = []
	if game.zombies != null:
		for z in game.zombies.list:
			zombies.append(_record(game, z))
	var containers := {}
	for id in game.data.get("containers", {}):
		var c: Dictionary = game.data["containers"][id]
		containers[String(id)] = _record(game, c)
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
	var out: Dictionary = {
		"version": VERSION, "kind": KIND,
		"stop_id": stop_id, "place": game.place, "mission": game.mission,
		"stop_form": game.stop_form,
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
	out["runtime"] = _runtime(game)
	return out


static func _start_opts(opts: Dictionary) -> Dictionary:
	var out := opts.duplicate(true)
	for key in NOT_START:
		out.erase(key)
	return out


static func _person(game, p) -> Dictionary:
	return {
		"pid": p.pid, "team": p.team, "pos": p.position, "level": game.level_of(p.position), "alive": p.is_alive(),
		"bag": p.bag, "items": p.items.duplicate(), "hands": p.hands.duplicate(true), "wear": Wear.save_of(p),
		"body": p.body.save_of(), "heat": p.heat.save_of(),
		"state": _properties(game, p, PERSON_FIELDS), "aim": _script_state(game, p.aim),
		"meta": _person_meta(game, p),
	}


static func _person_meta(game, p) -> Dictionary:
	var out: Dictionary = {}
	for key: String in PERSON_META:
		if p.has_meta(key):
			out[key] = _freeze(game, p.get_meta(key))
	return out


static func to_json(d: Dictionary) -> String:
	var encoded: Dictionary = _encode(d)
	# Keep the envelope readable by old slot tools; the payload preserves Variant types.
	encoded["version"] = int(d.get("version", VERSION))
	return JSON.stringify(encoded, "", false, true)


## The save in `text`, or {} when it is not a whole save of this kind and version.
static func from_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:  # a cut-off file is expected here, not an engine error
		return {}
	var parsed = json.data
	if not parsed is Dictionary:
		return {}
	if String(parsed.get("kind", "")) != KIND or int(parsed.get("version", 0)) not in [1, VERSION]:
		return {}
	var d: Dictionary = _decode(parsed)
	d["version"] = int(d["version"])
	d["seed"] = int(d.get("seed", 0))
	for z in d.get("zombies", []):
		z["id"] = int(z["id"])
		z["horde"] = int(z["horde"])
	for g in d.get("ground_items", []):
		# A crew carrier's dropped load keeps its part (field_work.gd drop_load); other items count whole.
		g["n"] = float(g["n"]) if g.get("crew_drop", false) else int(g["n"])
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
	if save.has("stop_form"):
		opts["stop_form"] = save["stop_form"]
	if not (save.get("departure", {}) as Dictionary).is_empty():
		opts["departure"] = (save["departure"] as Dictionary).duplicate(true)
	if String(save.get("receipt_id", "")) != "":
		opts["receipt_id"] = String(save["receipt_id"])
	opts["field_resume"] = save
	return opts


## A save that holds the whole running state (version 2 with "runtime"), not only the old fallbacks.
static func exact(save: Dictionary) -> bool:
	return int(save.get("version", 1)) >= 2 and save.has("runtime")


## Exact solids must fit every saved floor before any grid is replaced.
static func _grid_sizes_match(game, save: Dictionary) -> bool:
	var levels: Dictionary = save["runtime"].get("levels", {})
	for level in levels:
		if not game.levels.has(level):
			return false
		var grid: FieldGrid = game.levels[level]
		var row: Dictionary = levels[level]
		if row.get("solid", PackedByteArray()).size() != grid.width * grid.height:
			return false
	return true


## Version 2 reconnects existing identities before restoring their clocks or callbacks.
static func apply(game, save: Dictionary) -> void:
	var form := StopForm.resolve(save if save.has("stop_form") else game.opts, String(game.data["place_kind"]))
	game.skip_arrival()
	game.begin_resume()
	game.clock.elapsed = float(save["clock"]["elapsed"])
	game.clock.speed = float(save["clock"]["speed"])
	var fits := exact(save) and _grid_sizes_match(game, save)
	# One that does not fit a grown remote map was made while its ground stood unbuilt.
	var moved: bool = not fits and game.data.has("stop_left")
	var shift := _legacy_shift(game) if moved else Vector3.ZERO
	# The work crew is made during play (field_work.gd): each member a save carries is made again first.
	if game.get("work") != null:
		game.work.remake(save.get("people", []))
	for row: Dictionary in save.get("people", []):
		for p in game.people:
			if p.pid == String(row["pid"]):
				_put_person(p, row, shift)
				if moved:
					p.position = _onto_open(game, p.position, false)
	if exact(save):
		game.ammo.clear()
	_put_counts(game.ammo, save.get("ammo", {}))
	game.unloaded.clear()
	_put_counts(game.unloaded, save.get("unloaded", {}))
	game.loaded_wear = (save.get("loaded_wear", []) as Array).duplicate(true)
	game.actions.coal_delivered = float(save["coal"]["delivered"])
	game.actions.coal_spent = float(save["coal"]["spent"])
	if exact(save):
		if fits:
			_apply_exact(game, save)
			game.set_stop_form(form)
			return
		push_warning("field save grid size changed; restoring legacy state")
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
	if moved:
		for item: Dictionary in game.ground_items:
			if item.get("pos") is Vector3:
				item["pos"] = _onto_open(game, item["pos"] + shift, false)
	game.decisions = (save.get("decisions", []) as Array).duplicate(true)
	_put_zombies(game, save.get("zombies", []), shift, moved)
	if game.receipt != null:
		_put_receipt(game.receipt, save.get("receipt_state", {}))
	game.cam_focus = game.player.position
	game._update_camera(1.0)
	_refresh_restored_view(game)
	game.set_stop_form(form)


## How far an old remote save's cells moved when the ground grew west (stop_ground.gd
## `stop_left`); a side path the grown map took on and the old one did not, or the other
## way round, is not in it, so _onto_open still steps off what is not open.
static func _legacy_shift(game) -> Vector3:
	return Vector3(float(int(game.data.get("stop_left", 0))), 0.0, 0.0)


## How far, in cells, a moved spot looks for open ground (a side path's strip is 14).
const OPEN_REACH: int = 32


## The open cell nearest `at` on its floor, or `at` when it is open: an old save's spot
## can lie under the grown remote ground's deep forest.
static func _onto_open(game, at: Vector3, for_dead: bool) -> Vector3:
	var g: FieldGrid = game.levels.get(game.level_of(at), game.grid)
	var c := FieldGrid.cell_of(at)
	var open: bool = g.dead_can_walk(c) if for_dead else g.people_can_walk(c)
	if open:
		return at
	var n := g.nearest_walkable(c, for_dead, OPEN_REACH)
	return Vector3(float(n.x) + 0.5, at.y, float(n.y) + 0.5)


static func _put_person(p, row: Dictionary, shift: Vector3 = Vector3.ZERO) -> void:
	p.cancel_action()
	p.stop()
	p.position = row["pos"] + shift
	p.bag = String(row["bag"])
	p.items = (row["items"] as Dictionary).duplicate(true)
	# A save from before the three places has none: they keep what they put on.
	Wear.restore(p, row.get("wear", {}))
	p.set_weapon_slots((row["hands"] as Array).duplicate(true))
	var b = p.body
	var body: Dictionary = row["body"]
	b.restore(body)
	p.heat.restore(row.get("heat", {}))
	# How long the dead have eaten at this body (결정 441 (3)): one eaten up stays so. Version 2
	# keeps it in "meta" (PERSON_META), a version-1 row as its own "eaten"; none before it.
	var metadata: Dictionary = row.get("meta", {})
	var key := String(EatRules.EATEN_META)
	if metadata.has(key) or row.has("eaten"):
		p.set_meta(EatRules.EATEN_META, float(metadata.get(key, row.get("eaten", 0.0))))
	elif p.has_meta(EatRules.EATEN_META):
		p.remove_meta(EatRules.EATEN_META)


static func _runtime(game) -> Dictionary:
	var out: Dictionary = {"game": _properties(game, game, GAME_FIELDS), "components": {}, "levels": {}, "spots": {}, "mission": _script_state(game, game.mission_play.mission)}
	for name: String in COMPONENTS:
		out["components"][name] = _script_state(game, game.get(name))
	var doors: Array = []
	for door: Dictionary in game.holdout.doors:
		doors.append(_record(game, door))
	out["holdout_doors"] = doors
	out["hud"] = {"grab_total": game.hud.grab_total}
	out["zombie_system"] = _properties(game, game.zombies, ["next_id", "loot_rng", "lunge_rng", "embed_rng", "lungers_on"])
	for level in game.levels:
		var grid = game.levels[level]
		var level_state: Dictionary = {"solid": grid.solid.duplicate(), "revision": grid.revision, "doors": {}, "windows": {}, "floor_glass": grid.floor_glass.duplicate()}
		for kind: String in ["doors", "windows"]:
			for cell in grid.get(kind):
				level_state[kind][cell] = _record(game, grid.get(kind)[cell])
		out["levels"][level] = level_state
	for id in game.data.get("spots", {}):
		out["spots"][id] = _record(game, game.data["spots"][id])
	# Coal dug from a wagon (field_ai.gd _dug, field_work.gd) is in the map's own rows, which a
	# restart builds afresh: each wagon's coal, in the map's order.
	var wagon_coal: Array = []
	for wagon: Dictionary in game.data.get("wagons", []):
		wagon_coal.append(float(wagon.get("coal", 0.0)))
	out["wagon_coal"] = wagon_coal
	return out


## These small state holders contain script data; their owners and drawing objects
## are reconstructed by the field. Explicit exclusions keep those out of the slot.
static func _script_state(game, object) -> Dictionary:
	var fields: Array[String] = []
	for prop: Dictionary in object.get_property_list():
		var name: String = String(prop["name"])
		if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) or name in ["game", "tracers"]:
			continue
		if (object == game.mission_play and name == "mission") or (object == game.holdout and name == "doors"):
			continue
		# by_id holds the very rows of bodies (field_train_guard.gd): put back from them on restore.
		if object == game.train_guard and name == "by_id":
			continue
		fields.append(name)
	return _properties(game, object, fields)


static func _properties(game, object, fields: Array) -> Dictionary:
	var out: Dictionary = {}
	for field: String in fields:
		var value: Variant = object.get(field)
		if field == "action_done":
			if object.action == "":
				value = Callable()
			elif object.action == "swap":
				# The combat callback is a closure with no serializable capture list.
				value = Callable(object, "swap_weapons")
		out[field] = _freeze(game, value)
	return out


static func _record(game, row: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in row:
		if key != "node":
			out[key] = _freeze(game, row[key])
	return out


## References use stable field identities. Instance ids are process-local, including
## keys in combat/work reservations, so they also travel by the person's pid.
static func _freeze(game, value: Variant) -> Variant:
	if value is RandomNumberGenerator:
		return {"$rng": [str(value.seed), str(value.state)]}
	if value is Callable:
		if not value.is_valid():
			return {"$call": []}
		return {"$call": [_freeze(game, value.get_object()), String(value.get_method()), _freeze(game, value.get_bound_arguments())]}
	if value is Object:
		for p in game.people:
			if value == p:
				return {"$person": p.pid}
			if value == p.body:
				return {"$body": p.pid}
		if value == game:
			return {"$owner": "field"}
		for name: String in COMPONENTS + ["zombies"]:
			if value == game.get(name):
				return {"$owner": name}
		push_error("Unsupported object in field save")
		return null
	if value is Dictionary:
		if value.has("id") and value.has("kind") and value.has("pos"):
			var zombie: Dictionary = game.zombies.find(int(value["id"]))
			if is_same(value, zombie):
				return {"$zombie": int(value["id"])}
		for kind: String in ["containers", "spots"]:
			for id in game.data.get(kind, {}):
				if is_same(value, game.data[kind][id]):
					return {"$map": [kind, id]}
		for level in game.levels:
			for kind: String in ["doors", "windows"]:
				for cell in game.levels[level].get(kind):
					if is_same(value, game.levels[level].get(kind)[cell]):
						return {"$grid": [level, kind, cell]}
		for p in game.people:
			for i in p.body.wounds.size():
				if is_same(value, p.body.wounds[i]):
					return {"$wound": [p.pid, i]}
		for i in game.ground_items.size():
			if is_same(value, game.ground_items[i]):
				return {"$ground": i}
		var dictionary: Dictionary = {}
		for key in value:
			var saved_key: Variant = _freeze(game, key)
			if key is int:
				for p in game.people:
					if key == p.get_instance_id():
						saved_key = {"$instance": p.pid}
			dictionary[saved_key] = _freeze(game, value[key])
		return dictionary
	if value is Array:
		var array: Array = []
		for entry in value:
			array.append(_freeze(game, entry))
		return array
	if value is PackedVector3Array or value is PackedByteArray or value is PackedInt32Array or value is PackedStringArray:
		return value.duplicate()
	return value


static func _person_with_id(game, pid: String):
	for p in game.people:
		if p.pid == pid:
			return p
	return null


static func _thaw(game, value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("$person"):
			return _person_with_id(game, String(value["$person"]))
		if value.has("$body"):
			return _person_with_id(game, String(value["$body"])).body
		if value.has("$instance"):
			return _person_with_id(game, String(value["$instance"])).get_instance_id()
		if value.has("$zombie"):
			return game.zombies.find(int(value["$zombie"]))
		if value.has("$map"):
			var at: Array = value["$map"]
			return game.data[at[0]][at[1]]
		if value.has("$grid"):
			var at: Array = value["$grid"]
			return game.levels[at[0]].get(at[1])[at[2]]
		if value.has("$wound"):
			var at: Array = value["$wound"]
			return _person_with_id(game, String(at[0])).body.wounds[int(at[1])]
		if value.has("$ground"):
			return game.ground_items[int(value["$ground"])]
		if value.has("$owner"):
			return game if value["$owner"] == "field" else game.get(value["$owner"])
		if value.has("$call"):
			var call: Array = value["$call"]
			if call.is_empty():
				return Callable()
			return Callable(_thaw(game, call[0]), StringName(call[1])).bindv(_thaw(game, call[2]))
		var dictionary: Dictionary = {}
		for key in value:
			dictionary[_thaw(game, key)] = _thaw(game, value[key])
		return dictionary
	if value is Array:
		var array: Array = []
		for entry in value:
			array.append(_thaw(game, entry))
		return array
	if value is PackedVector3Array or value is PackedByteArray or value is PackedInt32Array or value is PackedStringArray:
		return value.duplicate()
	return value


static func _restore_properties(game, object, saved: Dictionary) -> void:
	for key in saved:
		var current: Variant = object.get(key)
		var value: Variant = saved[key]
		if current is RandomNumberGenerator:
			var pair: Array = value["$rng"]
			current.seed = int(pair[0])
			current.state = int(pair[1])
		else:
			var restored: Variant = _thaw(game, value)
			if current is Array:
				current.assign(restored)
			else:
				object.set(key, restored)


static func _apply_exact(game, save: Dictionary) -> void:
	var runtime: Dictionary = save["runtime"]
	for kind: String in ["containers", "spots"]:
		var rows: Dictionary = save["containers"] if kind == "containers" else runtime["spots"]
		var into: Dictionary = game.data[kind]
		for id in into.keys():
			if not rows.has(id):
				into.erase(id)
		for id in rows:
			into[id] = (rows[id] as Dictionary).duplicate(true)
	var wagons: Array = game.data.get("wagons", [])
	var wagon_coal: Array = runtime.get("wagon_coal", [])
	for i in mini(wagons.size(), wagon_coal.size()):
		wagons[i]["coal"] = float(wagon_coal[i])
	for level in runtime["levels"]:
		var grid = game.levels[level]
		var row: Dictionary = runtime["levels"][level]
		grid.solid = row["solid"].duplicate()
		grid.doors = (row["doors"] as Dictionary).duplicate(true)
		grid.windows = (row["windows"] as Dictionary).duplicate(true)
		# The glass fallen from a window onto the floor (field_actions.gd), there to sweep up.
		grid.floor_glass = (row.get("floor_glass", {}) as Dictionary).duplicate(true)
		grid.refresh_paths()
		grid.revision = int(row["revision"])
	game.ground_items = (save.get("ground_items", []) as Array).duplicate(true)
	game.decisions = (save.get("decisions", []) as Array).duplicate(true)
	# Allocate every identity first, then reconnect references without calling spawn().
	game.zombies.list.clear()
	for row: Dictionary in save["zombies"]:
		game.zombies.list.append({"id": int(row["id"])})
	for i in game.zombies.list.size():
		game.zombies.list[i].merge(_thaw(game, save["zombies"][i]), true)
	game.zombies._sense_cells_ready = false
	for row: Dictionary in save["people"]:
		var p = _person_with_id(game, String(row["pid"]))
		if p != null:
			_restore_properties(game, p, row.get("state", {}))
			_restore_properties(game, p.aim, row.get("aim", {}))
			var metadata: Dictionary = row.get("meta", {})
			for key: String in PERSON_META:
				if metadata.has(key):
					p.set_meta(key, _thaw(game, metadata[key]))
				elif p.has_meta(key):
					p.remove_meta(key)
	var player = _person_with_id(game, String(save.get("player_pid", "")))
	if player != null:
		game.player = player
	_restore_properties(game, game.mission_play.mission, runtime["mission"])
	for name: String in COMPONENTS:
		if runtime["components"].has(name):
			_restore_properties(game, game.get(name), runtime["components"][name])
	game.train_guard.by_id.clear()
	for row: Dictionary in game.train_guard.bodies:
		game.train_guard.by_id[int(row["id"])] = row
	for door: Dictionary in game.holdout.doors:
		if is_instance_valid(door.get("node")):
			door["node"].queue_free()
	game.holdout.doors = _thaw(game, runtime["holdout_doors"])
	for door: Dictionary in game.holdout.doors:
		door["node"] = null
		if int(door["wall"]) > 0:
			game.holdout._show_wall(door)
	_restore_properties(game, game.zombies, runtime["zombie_system"])
	game.hud.grab_total = float(runtime.get("hud", {}).get("grab_total", game.hud.grab_total))
	if game.receipt != null:
		_put_receipt(game.receipt, save.get("receipt_state", {}))
	_restore_properties(game, game, runtime["game"])
	_refresh_restored_view(game)
	# Sight/view rebuilding must not advance the saved simulation or random streams.
	_restore_properties(game, game, runtime["game"])
	# Rendering establishes pose caches. Keep their saved clocks too: showing the
	# paused frame is not an extra simulation/render step on the body's timeline.
	for i in game.zombies.list.size():
		var restored: Dictionary = _thaw(game, save["zombies"][i])
		game.zombies.list[i].clear()
		game.zombies.list[i].merge(restored)
	for row: Dictionary in save["people"]:
		var p = _person_with_id(game, String(row["pid"]))
		if p != null:
			var metadata: Dictionary = row.get("meta", {})
			for key: String in PERSON_META:
				if metadata.has(key):
					p.set_meta(key, _thaw(game, metadata[key]))
				elif p.has_meta(key):
					p.remove_meta(key)


static func _refresh_restored_view(game) -> void:
	# Boxes are drawn in shared chunk meshes (map_view.gd): ask the view, not its nodes.
	for id in game.view.container_ids():
		if not game.data["containers"].has(id):
			game.view.remove_object_container(id)
	for id in game.data["containers"]:
		if game.view.has_container(id):
			game.view.update_container(id)
		else:
			game.view.add_container(id)
	for id in game.data["spots"]:
		if game.view.spot_nodes.has(id):
			game.view.update_spot(id)
	for cell in game.grid.doors:
		if game.view.door_nodes.has(cell) or (game.view.buildings and game.view.buildings.draws_cell(cell)):
			game.view.update_door(cell)
	for cell in game.grid.windows:
		if game.view.window_nodes.has(cell) or (game.view.buildings and game.view.buildings.draws_cell(cell)):
			game.view.update_window(cell)
	for key in game.view.manhole_nodes:
		game.view.update_manhole(key, not game.director.is_open(key), float(game.lid_open.get(key, 0.0)) > 0.0)
	game._update_camera(0.0)
	game._refresh_vision()
	var level: int = game.level_of(game.player.position)
	game.view.show_levels(level)
	game.view.cut_away(game.grid_at(game.player.position).building_at(FieldGrid.cell_of(game.player.position)), level)
	for p in game.people:
		p.visible = game.level_shown(game.level_of(p.position)) and game._person_visible(p) and not game.rode_off.has(p)
		var saved_look: float = p.look
		p.refresh_view(p.visible)
		# refresh_view normally turns by the frame delta; a restored still must not.
		p.look = saved_look
		p.rotation.y = p.facing if p.turn_rate <= 0.0 else saved_look
	game.zombies.render(game.camera, game.seen_now, game.mask_on)


static func _put_counts(into: Dictionary, counts: Dictionary) -> void:
	for id in counts:
		into[id] = int(counts[id])


static func _put_zombies(game, rows: Array, shift: Vector3 = Vector3.ZERO, moved: bool = false) -> void:
	var all = game.zombies
	all.list.clear()
	var top := 0
	for row: Dictionary in rows:
		var at: Vector3 = _onto_open(game, row["pos"] + shift, true) if moved else row["pos"]
		var z: Dictionary = all.spawn(String(row["kind"]), at, {"horde": int(row.get("horde", -1)), "name": String(row.get("name", ""))})
		var state := String(row["state"])
		if state in ["downed", "dead"]:
			DeadPose.mark_fall(z, game.people)  # lies as it fell, not standing
		z["id"] = int(row["id"])
		z["state"] = state if state in RESUME_STATES else "wander"
		# A version-2 row is the whole record: pockets not rolled yet stay unrolled (zombies.gd rolls them when asked).
		if row.has("loot"):
			z["loot"] = (row["loot"] as Array).duplicate(true)
		else:
			z.erase("loot")
		z["searched"] = bool(row.get("searched", false))
		# Where it keeps to: its pockets and clothes are rolled by that place when first asked.
		if row.get("home") is Vector3:
			z["home"] = _onto_open(game, row["home"] + shift, true) if moved else row["home"]
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


static func _encode(v: Variant) -> Variant:
	if v is int:
		return {"$type": "int", "value": str(v)}
	if v is float and not is_finite(v):
		return {"$type": "float", "value": "inf" if v > 0.0 else "-inf"}
	if v is Vector3:
		return {"$type": "Vector3", "value": [v.x, v.y, v.z]}
	if v is Vector2:
		return {"$type": "Vector2", "value": [v.x, v.y]}
	if v is Vector2i:
		return {"$type": "Vector2i", "value": [v.x, v.y]}
	if v is Rect2i:
		return {"$type": "Rect2i", "value": [v.position.x, v.position.y, v.size.x, v.size.y]}
	if v is Color:
		return {"$type": "Color", "value": [v.r, v.g, v.b, v.a]}
	if v is PackedVector3Array or v is PackedByteArray or v is PackedInt32Array or v is PackedStringArray:
		return {"$type": type_string(typeof(v)), "value": _encode(Array(v))}
	if v is Dictionary:
		var strings_only: bool = true
		for key in v:
			if not (key is String or key is StringName):
				strings_only = false
		if not strings_only:
			var pairs: Array = []
			for key in v:
				pairs.append([_encode(key), _encode(v[key])])
			return {"$type": "Dictionary", "value": pairs}
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


static func _decode(v: Variant) -> Variant:
	if v is Dictionary:
		if v.has("$type") and v.has("value"):
			var value: Variant = v["value"]
			match String(v["$type"]):
				"int": return int(value)
				"float": return INF if value == "inf" else -INF
				"Vector3": return Vector3(float(value[0]), float(value[1]), float(value[2]))
				"Vector2": return Vector2(float(value[0]), float(value[1]))
				"Vector2i": return Vector2i(int(value[0]), int(value[1]))
				"Rect2i": return Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3]))
				"Color": return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
				"PackedVector3Array": return PackedVector3Array(_decode(value))
				"PackedByteArray": return PackedByteArray(_decode(value))
				"PackedInt32Array": return PackedInt32Array(_decode(value))
				"PackedStringArray": return PackedStringArray(_decode(value))
				"Dictionary":
					var dictionary: Dictionary = {}
					for pair: Array in value:
						dictionary[_decode(pair[0])] = _decode(pair[1])
					return dictionary
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
