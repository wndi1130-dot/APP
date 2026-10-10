extends Node3D
## All the dead on one stop. Data lives in plain dictionaries; drawing is one
## VAT MultiMesh per look. States: wander, investigate, chase, attack, grab,
## downed, dead, frozen, waking, rising (corpse about to stand up), horde.
## Kinds (zombies.md): "dead" 망자, "clothed" 껴입은 자, "fresh" 갓 일어난 자,
## "frozen" 얼어붙은 자 (becomes "dead" when it wakes).

const FieldGrid = preload("res://game/world/field_grid.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const GrabRules = preload("res://game/sim/grab_rules.gd")

const MAX_DRAW: int = 160
const SIGHT: float = 9.0
const SPEED_WANDER: float = 0.45
const SPEED_SHAMBLE: float = 1.05
const SPEED_HURRY: float = 1.35
const SPEED_FRESH: float = 2.7
const SPEED_CRAWL: float = 0.35
const ATTACK_RANGE: float = 0.85
const WINDUP: float = 0.8
const GET_UP: Vector2 = Vector2(5.0, 9.0)
const RISE_TIME: float = 30.0
const FRESH_STIFFEN: float = 240.0
const WAKE_TIME: float = 2.0
const NEAR: float = 32.0
const FEEL: float = 1.8          # all-round sense at arm's reach
const CONE_COS: float = 0.5      # 120 degree forward sight cone
const HERD: float = 8.0
const MEMORY: float = 8.0        # seconds a lost target stays worth chasing (field_unified 11, 'normal')
const SEARCH_TIME: float = 4.0   # look around the last seen spot, two corners, then wander
const NO_WAY_WAIT: float = 2.5   # no way through to the target: look for one again this much later
const KINDS: Array[String] = ["dead", "clothed", "fresh", "frozen"]
const TINTS: Dictionary = {"dead": Color(0.5, 0.52, 0.47), "clothed": Color(0.36, 0.38, 0.45), "fresh": Color(0.62, 0.45, 0.42), "frozen": Color(0.86, 0.9, 0.95), "corpse": Color(0.3, 0.3, 0.29)}

var game  # field_game.gd
var list: Array[Dictionary] = []
var next_id: int = 1
var draw: Dictionary = {}     # look -> MultiMeshInstance3D
var drawn_count: int = 0
var vat: Dictionary
var markers: MultiMeshInstance3D
var _people: Array = []


func setup(field_game, vat_assets: Dictionary) -> void:
	game = field_game
	vat = vat_assets
	for look in ["dead", "clothed", "fresh", "frozen", "corpse"]:
		var node := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = vat["mesh"]
		mm.instance_count = MAX_DRAW
		mm.visible_instance_count = 0
		mm.custom_aabb = AABB(Vector3(-5, -5, -5), Vector3(185, 16, 115))
		node.multimesh = mm
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://game/actors/dead_vat.gdshader")
		mat.set_shader_parameter("vat", vat["texture"])
		mat.set_shader_parameter("rows_per_frame", float(vat["rows_per_frame"]))
		var t: Color = TINTS[look]
		mat.set_shader_parameter("tint", Vector3(t.r, t.g, t.b))
		node.material_override = mat
		add_child(node)
		draw[look] = node
	# Rising markers above corpses that will stand up.
	markers = MultiMeshInstance3D.new()
	var mm2 := MultiMesh.new()
	mm2.transform_format = MultiMesh.TRANSFORM_3D
	var ring := TorusMesh.new()
	ring.inner_radius = 0.35
	ring.outer_radius = 0.45
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.78, 0.76, 0.72)   # off-white: no red in the field (fx colour rule)
	ring.material = rm
	mm2.mesh = ring
	mm2.instance_count = 32
	mm2.visible_instance_count = 0
	mm2.custom_aabb = AABB(Vector3(-5, -5, -5), Vector3(185, 16, 115))
	markers.multimesh = mm2
	add_child(markers)


func spawn(kind: String, at: Vector3, opts: Dictionary = {}) -> Dictionary:
	var z := {
		"id": next_id, "kind": kind, "pos": _floor_y(at), "state": "frozen" if kind == "frozen" else "wander",
		"home": _floor_y(at), "target": _floor_y(at), "path": PackedVector3Array(), "path_t": 0.0,
		"angle": game.rng.randf() * TAU, "phase": game.rng.randf(), "t": 0.0, "linger": 0.0,
		"victim": null, "windup": 0.0, "cooldown": 0.0, "grab_t": 0.0, "crawl": false,
		"horde": int(opts.get("horde", -1)), "seen_t": 0.0, "last_seen": Vector3.ZERO, "age": 0.0,
		"rise_t": 0.0, "name": String(opts.get("name", "")), "bang_t": 0.0, "depth": float(opts.get("depth", 1.0)),
		"stun": 0.0, "speed": 0.0, "stander": game.rng.randf() < 0.55, "search_left": 0, "sense_t": 0.0, "smell_lock": 0.0,
	}
	next_id += 1
	if opts.has("target"):
		z["state"] = "horde"
		z["target"] = opts["target"]
	list.append(z)
	return z


## Bodies stand on a floor: y snaps to the level it is on.
func _floor_y(at: Vector3) -> Vector3:
	return Vector3(at.x, game.level_y(game.level_of(at)), at.z)


## A dead person becomes a corpse that stands up as "fresh" after RISE_TIME.
func add_rising(at: Vector3, who_name: String) -> Dictionary:
	var z := spawn("fresh", at, {"name": who_name})
	z["state"] = "rising"
	z["rise_t"] = RISE_TIME
	return z


func alive_count() -> int:
	var n := 0
	for z in list:
		if z["state"] != "dead":
			n += 1
	return n


func count_where(state: String) -> int:
	var n := 0
	for z in list:
		if z["state"] == state:
			n += 1
	return n


func active(z: Dictionary) -> bool:
	return z["state"] != "dead" and z["state"] != "rising" and z["state"] != "frozen"


func threat(z: Dictionary) -> bool:
	return z["state"] != "dead" and z["state"] != "rising"


## Nearest dead within radius matching an optional state filter.
func nearest(at: Vector3, radius: float, include_downed: bool = true, include_frozen: bool = true) -> Dictionary:
	var best: Dictionary = {}
	var best_d := radius
	for z in list:
		if z["state"] == "dead" or z["state"] == "rising":
			continue
		if not include_downed and z["state"] == "downed":
			continue
		if not include_frozen and z["state"] == "frozen":
			continue
		var d: float = at.distance_to(z["pos"])
		if d < best_d:
			best_d = d
			best = z
	return best


func in_radius(at: Vector3, radius: float) -> Array:
	var out: Array = []
	for z in list:
		if threat(z) and at.distance_to(z["pos"]) <= radius:
			out.append(z)
	return out


func find(id: int) -> Dictionary:
	for z in list:
		if z["id"] == id:
			return z
	return {}


## Sound reaches the dead (body_injury 8장). Frozen ones wake on NORMAL or louder.
## wind (weather.gd, optional) stretches the radius downwind (excessive blood, 8.1).
func hear(at: Vector3, level: int, radius: float, wind = null) -> int:
	var reacted := 0
	for z in list:
		var state: String = z["state"]
		if state == "dead" or state == "rising" or state == "downed" or state == "grab" or state == "attack":
			continue
		var d: float = at.distance_to(z["pos"])
		var reach := radius
		if wind != null:
			reach *= float(wind.downwind(at, z["pos"]))
		# Every floor between halves what comes through it.
		var floors: int = absi(game.level_of(at) - game.level_of(z["pos"]))
		if floors > 0:
			reach *= pow(0.5, floors)
		if d > reach:
			continue
		if state == "frozen":
			if level >= SimNoise.Level.NORMAL:
				wake(z)
				reacted += 1
			continue
		if state == "waking" or state == "chase":
			continue
		if level == SimNoise.Level.QUIET:
			z["angle"] = atan2(at.x - z["pos"].x, at.z - z["pos"].z)
			continue
		# A fainter sound does not pull one already walking to a louder one.
		if (state == "investigate" or state == "horde") and level < int(z.get("clue", 0)) and z["pos"].distance_to(z["target"]) > 1.2:
			continue
		# Idle dead first turn toward the noise, then set off (no instant lock-on).
		if state == "wander" or state == "search":
			z["turn_t"] = game.rng.randf_range(0.4, 0.9)
		z["clue"] = level
		z["state"] = "investigate"
		z["target"] = at
		z["linger"] = SimNoise.LINGER[level]
		z["speed"] = SPEED_HURRY if level >= SimNoise.Level.LOUD else SPEED_SHAMBLE
		z["path_t"] = 0.0
		reacted += 1
	return reacted


## Excessive blood (body_injury 8.1): a smell event, separate from sound. The
## dead within reach walk to the spot it came from (not to where the bleeder
## is now). Frozen ones do not wake to it; silencers and quiet steps do not cut it.
func smell(at: Vector3, radius: float) -> int:
	var reacted := 0
	for z in list:
		var state: String = z["state"]
		if state in ["dead", "rising", "downed", "grab", "attack", "frozen", "waking", "chase"]:
			continue
		var reach := radius * float(game.weather.scent_mult(at, z["pos"]))
		if at.distance_to(z["pos"]) > reach:
			continue
		if state == "investigate" and int(z.get("clue", 0)) > SimNoise.Level.NORMAL and z["pos"].distance_to(z["target"]) > 1.2:
			continue
		if state == "wander" or state == "search":
			z["turn_t"] = game.rng.randf_range(0.4, 0.9)
		z["clue"] = SimNoise.Level.NORMAL
		z["state"] = "investigate"
		z["target"] = at
		z["linger"] = 8.0
		z["speed"] = SPEED_SHAMBLE
		z["path_t"] = 0.0
		reacted += 1
	return reacted


func wake(z: Dictionary) -> void:
	if z["state"] != "frozen":
		return
	z["state"] = "waking"
	z["t"] = WAKE_TIME
	game.on_frozen_wake(z)


func update(delta: float) -> void:
	var people: Array = game.people_alive()
	_people = people
	for z in list:
		z["age"] += delta
		z["cooldown"] = maxf(0.0, z["cooldown"] - delta)
		z["stun"] = maxf(0.0, z["stun"] - delta)
		match z["state"]:
			"dead", "frozen":
				continue
			"rising":
				z["rise_t"] -= delta
				if z["rise_t"] <= 0.0:
					z["state"] = "wander"
					z["home"] = z["pos"]
					game.on_risen(z)
				continue
			"waking":
				z["t"] -= delta
				if z["t"] <= 0.0:
					z["kind"] = "dead"
					z["state"] = "wander"
				continue
			"downed":
				z["t"] -= delta
				if z["t"] <= 0.0:
					z["state"] = "wander"
					z["home"] = z["pos"]
				continue
			"grab":
				_update_grab(z, delta)
				continue
			"attack":
				_update_attack(z, delta)
				continue
		if z["kind"] == "fresh" and z["age"] > FRESH_STIFFEN:
			z["kind"] = "dead"
		if z["stun"] > 0.0:
			continue
		_sense(z, people, delta)
		_move(z, delta)


func _sense(z: Dictionary, people: Array, delta: float) -> void:
	# Far dead keep their errand; near ones look (forward cone), feel (arm's
	# reach all round) and smell blood. Senses tick at ~6 Hz per zombie.
	# Far from every person (not just the player) and not chasing: skip.
	if z["state"] != "chase":
		var anyone_near := false
		for q in people:
			if z["pos"].distance_squared_to(q.position) <= NEAR * NEAR:
				anyone_near = true
				break
		if not anyone_near:
			return
	z["sense_t"] = float(z.get("sense_t", 0.0)) - delta
	if z["sense_t"] > 0.0 and z["state"] != "chase":
		return
	z["sense_t"] = 0.15 + game.rng.randf() * 0.05
	# Weather cuts sight for both sides (body_injury 8.3); dusk cuts it again.
	var sight: float = SIGHT * float(game.weather.sight_mult(game.clock.is_dark()))
	var best = null
	var best_d := 999.0
	var forward := Vector3(sin(z["angle"]), 0, cos(z["angle"]))
	var zl: int = game.level_of(z["pos"])
	var lg = game.grid_at(z["pos"])
	for p in people:
		# The dead do not look up through floors or out of upstairs windows.
		if game.level_of(p.position) != zl:
			continue
		var d: float = z["pos"].distance_to(p.position)
		var reach: float = sight * float(p.smell_mult()) * float(game.weather.downwind(p.position, z["pos"]) if p.smell > 0 else 1.0)
		if p.crouched:
			reach *= 0.55
		var to_p: Vector3 = (p.position - z["pos"])
		to_p.y = 0
		var in_cone := d < FEEL or (to_p.length() > 0.01 and forward.dot(to_p.normalized()) >= CONE_COS)
		# Already chasing: keeps tracking a moving target a bit outside the cone.
		if z["state"] == "chase" and z["victim"] == p and d < reach:
			in_cone = true
		if not in_cone or d > reach or d > best_d:
			continue
		if d > FEEL and not lg.line_clear(FieldGrid.cell_of(z["pos"]), FieldGrid.cell_of(p.position)):
			continue
		best = p
		best_d = d
	if best != null:
		if z["state"] != "chase":
			z["path_t"] = 0.0
			_call_neighbours(z, best.position)
		z["turn_t"] = 0.0
		z["state"] = "chase"
		z["victim"] = best
		z["seen_t"] = 0.0
		z["last_seen"] = best.position
		z["target"] = best.position
		if best_d <= ATTACK_RANGE and z["cooldown"] <= 0.0 and can_reach(z, best):
			z["state"] = "attack"
			z["windup"] = WINDUP
			z["angle"] = atan2(best.position.x - z["pos"].x, best.position.z - z["pos"].z)
		return
	if z["state"] == "chase":
		# Memory holds only the spot it saw; it never reads where the target is now,
		# except up or down a stair it just watched them take: it hears the steps.
		z["seen_t"] += 0.17
		z["target"] = z["last_seen"]
		var v = z["victim"]
		if v != null and v.is_alive() and game.level_of(v.position) != zl and z["seen_t"] < 2.0:
			var lseen: Vector3 = z["last_seen"]
			if Vector2(v.position.x - lseen.x, v.position.z - lseen.z).length() < 3.0:
				z["target"] = v.position
				z["last_seen"] = v.position
				z["path_t"] = 0.0
				return
		if z["pos"].distance_to(z["last_seen"]) < 1.0:
			_begin_search(z, z["last_seen"])
		elif z["seen_t"] > MEMORY:
			z["state"] = "wander"
			z["home"] = z["pos"]
			z["t"] = 2.0
		return
	# Blood: fresh trail points pull the dead (body_injury 8.1: heavy bleeding reaches far).
	if z["state"] != "investigate" or float(z.get("smell_lock", 0.0)) <= 0.0:
		var scent: Dictionary = game.strongest_scent(z["pos"])
		if not scent.is_empty():
			z["state"] = "investigate"
			z["target"] = scent["pos"]
			z["linger"] = 8.0
			z["speed"] = SPEED_SHAMBLE
			z["path_t"] = 0.0
			z["smell_lock"] = 3.0
	z["smell_lock"] = maxf(0.0, float(z.get("smell_lock", 0.0)) - 0.17)


## Lost the target: walk to where it was last seen, then poke around nearby.
func _begin_search(z: Dictionary, around: Vector3) -> void:
	z["state"] = "search"
	z["home"] = around
	z["target"] = around
	z["search_left"] = 2
	z["search_t"] = SEARCH_TIME
	z["linger"] = 1.0
	z["path_t"] = 0.0


## Herd behaviour: dead that see a neighbour lurch after something follow it.
func _call_neighbours(z: Dictionary, toward: Vector3) -> void:
	for o in list:
		if o == z or o["state"] in ["dead", "rising", "frozen", "waking", "downed", "chase", "attack", "grab"]:
			continue
		if o["pos"].distance_to(z["pos"]) > HERD:
			continue
		o["state"] = "investigate"
		o["target"] = toward + Vector3(game.rng.randf_range(-1.5, 1.5), 0, game.rng.randf_range(-1.5, 1.5))
		o["linger"] = 6.0
		o["speed"] = SPEED_SHAMBLE
		o["path_t"] = game.rng.randf() * 0.6


func _speed(z: Dictionary) -> float:
	if z["crawl"]:
		return SPEED_CRAWL
	var s := SPEED_WANDER
	match z["state"]:
		"chase":
			s = SPEED_FRESH if z["kind"] == "fresh" else SPEED_HURRY
		"investigate":
			s = maxf(float(z["speed"]), SPEED_SHAMBLE)
		"search":
			s = SPEED_SHAMBLE
		"horde":
			s = SPEED_SHAMBLE
	return s * float(FieldGrid.FLOOR_SPEED[game.grid_at(z["pos"]).floor_at(FieldGrid.cell_of(z["pos"]))])


func _move(z: Dictionary, delta: float) -> void:
	var state: String = z["state"]
	var target: Vector3 = z["target"]
	var at: Vector3 = z["pos"]
	if state == "wander":
		if at.distance_to(target) < 0.5:
			z["t"] -= delta
			if z["t"] <= 0.0:
				# Most of the dead stand and sway, turning now and then; some drift.
				if z.get("stander", false) and game.rng.randf() < 0.7:
					z["t"] = game.rng.randf_range(4.0, 10.0)
					z["angle"] += game.rng.randf_range(-1.2, 1.2)
					return
				z["t"] = game.rng.randf_range(3.0, 8.0)
				var off := Vector3(game.rng.randf_range(-5, 5), 0, game.rng.randf_range(-5, 5))
				var home: Vector3 = Vector3(z["home"].x, at.y, z["home"].z)
				var c: Vector2i = game.grid_at(at).nearest_walkable(FieldGrid.cell_of(home + off), true, 2)
				z["target"] = game.lift(c, game.level_of(at))
				z["path"] = PackedVector3Array()
			return
	elif state == "investigate":
		if at.distance_to(target) < 1.2:
			z["linger"] -= delta
			if z["linger"] <= 0.0:
				z["state"] = "wander"
				z["home"] = at
				z["t"] = 2.0
			elif game.rng.randf() < delta * 0.5:
				z["angle"] += game.rng.randf_range(-1.5, 1.5)
			return
	elif state == "search":
		z["search_t"] = float(z.get("search_t", SEARCH_TIME)) - delta
		if z["search_t"] <= 0.0:
			z["state"] = "wander"
			z["home"] = at
			z["t"] = 2.0
			return
		if at.distance_to(target) < 1.0:
			z["linger"] -= delta
			if game.rng.randf() < delta * 1.5:
				z["angle"] += game.rng.randf_range(-1.6, 1.6)
			if z["linger"] <= 0.0:
				z["search_left"] = int(z["search_left"]) - 1
				if z["search_left"] <= 0:
					z["state"] = "wander"
					z["t"] = 3.0
					return
				var off := Vector3(game.rng.randf_range(-3, 3), 0, game.rng.randf_range(-3, 3))
				z["target"] = game.walkable_near(z["home"] + off, true, 2)
				z["linger"] = 1.0
				z["path_t"] = 0.0
			return
	elif state == "horde":
		if at.distance_to(target) < 2.0:
			z["state"] = "investigate"
			z["linger"] = 40.0
			z["speed"] = SPEED_SHAMBLE
	if float(z.get("turn_t", 0.0)) > 0.0:
		z["turn_t"] = float(z["turn_t"]) - delta
		var want := atan2(target.x - at.x, target.z - at.z)
		z["angle"] = lerp_angle(float(z["angle"]), want, minf(1.0, delta * 6.0))
		return
	# Path refresh: straight when clear, otherwise A* on the people grid
	# (closed doors are planned through and then banged on).
	z["path_t"] -= delta
	z["no_way_t"] = maxf(0.0, float(z.get("no_way_t", 0.0)) - delta)
	var path: PackedVector3Array = z["path"]
	# The wait holds only for the cell that had no way: a new target is looked for at once.
	var waiting: bool = float(z["no_way_t"]) > 0.0 and z.get("no_way_cell") == FieldGrid.cell_of(target)
	if (z["path_t"] <= 0.0 or path.is_empty()) and not waiting:
		z["no_way_t"] = 0.0
		var near := at.distance_to(game.player.position) < NEAR
		z["path_t"] = (0.6 if near else 2.5) + game.rng.randf() * 0.4
		if game.level_of(at) == game.level_of(target) and game.grid_at(at).clear_walk(FieldGrid.cell_of(at), FieldGrid.cell_of(target), true):
			path = PackedVector3Array([target])
		else:
			path = game.find_path(at, target, false)
			# Walled off (a locked room, up a ladder): the search that finds no way
			# is the dearest one, and with nowhere left to walk every one of the
			# crowd ran it again each frame, which slowed the whole field (build 89).
			# They stand where they got to and ask again a little later.
			if path.is_empty() or FieldGrid.cell_of(path[path.size() - 1]) != FieldGrid.cell_of(target):
				z["no_way_t"] = NO_WAY_WAIT + game.rng.randf() * 0.5
				z["no_way_cell"] = FieldGrid.cell_of(target)
		z["path"] = path
	if path.is_empty():
		return
	var next := path[0]
	var dir := next - at
	dir.y = 0
	if dir.length() < 0.25:
		# Stairs: the next point is the same spot a floor up or down.
		z["pos"] = Vector3(at.x, game.level_y(game.level_of(next)), at.z)
		path.remove_at(0)
		z["path"] = path
		return
	var step := dir.normalized() * _speed(z) * delta
	var dest := at + step
	var dc := FieldGrid.cell_of(dest)
	var lg = game.grid_at(at)
	if lg.blocks_body(dc):
		if lg == game.grid and game.grid.doors.has(dc):
			_bang(z, dc, delta)
		else:
			dest = _slide(at, step)
	z["angle"] = atan2(dir.x, dir.z)
	z["pos"] = _avoid_people(z, dest)


func _bang(z: Dictionary, c: Vector2i, delta: float) -> void:
	z["bang_t"] -= delta
	if z["bang_t"] > 0.0:
		return
	z["bang_t"] = 1.3
	game.on_door_banged(c)


func _slide(at: Vector3, step: Vector3) -> Vector3:
	var lg = game.grid_at(at)
	var r := at
	var cand := r + Vector3(step.x, 0, 0)
	if not lg.blocks_body(FieldGrid.cell_of(cand)):
		r.x = cand.x
	cand = r + Vector3(0, 0, step.z)
	if not lg.blocks_body(FieldGrid.cell_of(cand)):
		r.z = cand.z
	return r


func _avoid_people(z: Dictionary, dest: Vector3) -> Vector3:
	for p in _people:
		var d: float = dest.distance_to(p.position)
		if d < 0.55 and d > 0.001:
			dest = p.position + (dest - p.position).normalized() * 0.55
	return dest


## Same floor and nothing that stops a blow between (a wall corner, a shut door, whole glass).
func can_reach(z: Dictionary, victim) -> bool:
	if game.level_of(z["pos"]) != game.level_of(victim.position):
		return false
	return game.grid_at(z["pos"]).body_line_clear(FieldGrid.cell_of(z["pos"]), FieldGrid.cell_of(victim.position))


func _update_attack(z: Dictionary, delta: float) -> void:
	var victim = z["victim"]
	if victim == null or not victim.is_alive():
		z["state"] = "wander"
		return
	z["windup"] -= delta
	var d: float = z["pos"].distance_to(victim.position)
	if d > ATTACK_RANGE + 0.4 or not can_reach(z, victim):
		z["state"] = "chase"
		return
	if z["windup"] > 0.0:
		return
	z["cooldown"] = 1.6
	var outcome: String = game.zombie_reaches(z, victim)
	if outcome == "grab":
		z["state"] = "grab"
	else:
		z["state"] = "chase"


func _update_grab(z: Dictionary, delta: float) -> void:
	var victim = z["victim"]
	if victim == null or not victim.is_alive():
		z["state"] = "wander"
		return
	z["pos"] = victim.position + (z["pos"] - victim.position).normalized() * 0.5
	z["angle"] = atan2(victim.position.x - z["pos"].x, victim.position.z - z["pos"].z)


## Release a grab (shoved off or victim died). Shove pushes the body back.
func release(z: Dictionary, push_from: Vector3, knock: bool) -> void:
	if z.is_empty() or z["state"] == "dead":
		return
	# Whoever it held is let go, knocked down or not (release_grab is safe to repeat).
	if z["state"] == "grab" and z["victim"] != null:
		z["victim"].release_grab(z)
	var away: Vector3 = z["pos"] - push_from
	away.y = 0
	if away.length() < 0.01:
		away = Vector3(0, 0, 1)
	z["pos"] = _slide(z["pos"], away.normalized() * 1.3)
	z["cooldown"] = 1.8
	if knock:
		knock_down(z)
	else:
		z["state"] = "chase"
		z["stun"] = 1.0


func knock_down(z: Dictionary) -> void:
	# Knocked off its victim: the victim is let go, or the grab still bites.
	if z["state"] == "grab" and z["victim"] != null:
		z["victim"].release_grab(z)
	z["state"] = "downed"
	z["t"] = game.rng.randf_range(GET_UP.x, GET_UP.y)
	z["victim"] = null


func kill(z: Dictionary) -> void:
	if z["state"] == "grab" and z["victim"] != null:
		z["victim"].release_grab(z)
	z["state"] = "dead"
	z["victim"] = null
	game.on_zombie_killed(z)


## Visible-only drawing with CPU frustum test, one MultiMesh per look.
func render(camera: Camera3D, seen: Dictionary, mask_on: bool) -> void:
	var counts := {"dead": 0, "clothed": 0, "fresh": 0, "frozen": 0, "corpse": 0}
	var marks := 0
	for z in list:
		var at: Vector3 = z["pos"]
		if mask_on and not seen.has(game.seen_key(at)):
			continue
		if not game.level_shown(game.level_of(at)):
			continue
		if not camera.is_position_in_frustum(at + Vector3(0, 0.6, 0)):
			continue
		var look: String = z["kind"]
		var state: String = z["state"]
		var basis := Basis(Vector3.UP, z["angle"])
		var pos := at
		var frozen_anim := 0.0
		var shade := 1.0
		if state == "dead":
			look = "corpse"
		if state == "dead" or state == "downed" or state == "rising" or z["crawl"]:
			basis = basis * Basis(Vector3.RIGHT, -PI * 0.5)
			pos.y = at.y + 0.18
			frozen_anim = 1.0 if state != "downed" or not z["crawl"] else 0.0
		if state == "frozen":
			look = "frozen"
			frozen_anim = 1.0
			basis = basis * Basis(Vector3.RIGHT, -0.5)
			pos.y = at.y - 0.55
		elif state == "waking":
			look = "frozen"
			pos.y = at.y - 0.55 * clampf(float(z["t"]) / WAKE_TIME, 0, 1) + sin(z["t"] * 40.0) * 0.04
		if state == "rising" and marks < 32:
			markers.multimesh.set_instance_transform(marks, Transform3D(Basis.IDENTITY, at + Vector3(0, 0.05, 0)))
			marks += 1
		if z["kind"] == "clothed":
			basis = basis.scaled(Vector3(1.3, 1.0, 1.35))
		if z["stun"] > 0.0:
			shade = 0.8
		var n: int = counts[look]
		if n >= MAX_DRAW:
			continue
		var mm: MultiMesh = draw[look].multimesh
		mm.set_instance_transform(n, Transform3D(basis, pos))
		var clip := 1.0 if state == "chase" or state == "attack" or state == "grab" else 0.0
		mm.set_instance_custom_data(n, Color(z["phase"], clip, frozen_anim, shade))
		counts[look] = n + 1
	drawn_count = 0
	for look in counts:
		draw[look].multimesh.visible_instance_count = counts[look]
		if look != "corpse":
			drawn_count += counts[look]
	markers.multimesh.visible_instance_count = marks
