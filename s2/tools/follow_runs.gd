extends SceneTree
## Decision 486: observe follow failures before changing the rules.
## --seeds 1:10 --hz 30 --label before [--follow-walk-turn]
## Like one_motion_runs: raw resources in memory, manual fixed _step, no saves.

const FieldGrid = preload("res://game/world/field_grid.gd")
const LEG_SECONDS := 40.0
## The narrow leg starts where the building leg ended, often 60 m or more from the corridor: at 40 s
## seven of ten runs were still walking up to it (decision 486, round 5), so it gets room to cross it.
const NARROW_SECONDS := 90.0
const STAND_SECONDS := 6.0
const REACHED_M := 0.15
const STUCK_MOVE_M := 0.15
const STUCK_SECONDS := 1.5
const JAM_RADIUS_M := 1.5
const JAM_MOVE_M := 0.2
const JAM_SECONDS := 3.0
const STILL_SECONDS := 1.5
const ROUTE_ATTEMPTS := 128
const NARROW_W := 2   # a way at most this many cells wide between walls is narrow

var keep: Array = []
var game_script: GDScript
var hz := 30
var seed_first := 1
var seed_last := 10
var label := "before"
var follow_walk_turn: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _arguments():
		quit(1)
		return
	print(JSON.stringify({"kind": "config", "label": label,
		"seeds": [seed_first, seed_last], "hz": hz,
		"follow_walk_turn": follow_walk_turn,
		"stop_reason_method": "observed state at moving true->false; not a mover event log",
		"stop_context_key": "leg|reason|queue/formation|corner/straight",
		"player_reversal": "successive nonzero displacement directions have dot < -0.5",
		"face_camera_axis": "horizontal camera basis.z; legacy face_camera remains position based",
		"engine": Engine.get_version_info()["string"],
		"field_ai_sha256": FileAccess.get_sha256("res://game/field_ai.gd"),
		"leg_limit_seconds": LEG_SECONDS, "narrow_limit_seconds": NARROW_SECONDS, "stand_seconds": STAND_SECONDS,
		"stuck_seconds": STUCK_SECONDS, "stuck_move_per_think_m": STUCK_MOVE_M,
		"route_rng": "independent; seed = trial seed; plan before stepping",
		"p95": "nearest_rank; pooled samples",
		"overlap_unit": "unique overlapping people per tick, including player",
		"door_jam_seconds": "whole episode, counted only once it exceeds 3 seconds",
		"narrow_max_cells_wide": NARROW_W}))
	if not _prepare():
		print(JSON.stringify({"kind": "summary", "label": label, "trials": 0,
			"state": "failed", "failure_code": "F-SCRIPT-LOAD"}))
		quit(1)
		return
	var total := _new_metrics()
	var by_mate: Dictionary = {}
	var counts := {"completed": 0, "timeout": 0, "skipped": 0, "interrupted": 0}
	var trial_seconds := 0.0
	var player_overlap := 0.0
	var pair_overlap := 0.0
	var failed := 0
	for run_seed in range(seed_first, seed_last + 1):
		var row := _trial(run_seed, total, by_mate)
		print(JSON.stringify(row))
		trial_seconds += float(row["seconds"])
		player_overlap += float(row["overlap"]["player_person_seconds"])
		pair_overlap += float(row["overlap"]["pair_seconds"])
		for leg in row["legs"]:
			counts[leg["state"]] += 1
		if row["failure_code"] != "":
			failed += 1
		await process_frame
	var summary := _metrics_row(total, trial_seconds)
	summary.merge({"kind": "summary", "label": label,
		"trials": seed_last - seed_first + 1, "failed_trials": failed,
		"seconds": trial_seconds, "leg_states": counts,
		"state": "completed" if failed == 0 else "failed", "per_mate": []})
	_add_player_overlap(summary, player_overlap, pair_overlap)
	for pid in by_mate:
		var entry: Dictionary = by_mate[pid]
		var mate_row := _metrics_row(entry["metrics"], float(entry["metrics"]["observed_s"]))
		mate_row.merge({"id": pid, "role": entry["role"]})
		summary["per_mate"].append(mate_row)
	print(JSON.stringify(summary))
	quit(0 if failed == 0 else 1)


func _prepare() -> bool:
	# Keep the import-free setup and TrainModelKit cache shim of one_motion_runs.
	for name in DirAccess.get_files_at("res://game/ui/tex"):
		if name.ends_with(".png"):
			var path := "res://game/ui/tex/" + name
			var png := Image.new()
			png.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
			var texture := ImageTexture.create_from_image(png)
			texture.take_over_path(path)
			keep.append(texture)
	for folder in ["res://game/ui/fonts", "res://audio", "res://models/weapons"]:
		_cache_raw(folder)
	for key in ["building_models", "train_models", "prop_models", "baked_dead", "baked_people"]:
		ProjectSettings.set_setting("visuals/" + key + "_enabled", false)
	var train_path := "res://game/world/train_model_kit.gd"
	var train_script := GDScript.new()
	train_script.source_code = FileAccess.get_file_as_string(train_path).replace(
		"var kit := TrainModelKit.new()", 'var kit = load("' + train_path + '").new()')
	train_script.take_over_path(train_path)
	if train_script.reload() != OK:
		return false
	keep.append(train_script)
	game_script = GDScript.new()
	# Initial setup is unchanged (including its RNG draws). Only future spawn
	# execution and saving are suppressed in this in-memory instance subclass.
	game_script.source_code = ('extends "res://game/field_game.gd"\n'
		+ 'func _save(_result: Dictionary) -> void:\n\tpass\n'
		+ 'func _update_spawns(_delta: float) -> void:\n\tpending_spawn.clear()\n')
	return game_script.reload() == OK


func _cache_raw(folder: String) -> void:
	for sub in DirAccess.get_directories_at(folder):
		_cache_raw(folder.path_join(sub))
	for name in DirAccess.get_files_at(folder):
		var path := folder.path_join(name)
		var resource: Resource
		match name.get_extension():
			"ttf":
				var font := FontFile.new()
				font.data = FileAccess.get_file_as_bytes(path)
				resource = font
			"wav": resource = AudioStreamWAV.load_from_buffer(FileAccess.get_file_as_bytes(path))
			"ogg": resource = AudioStreamOggVorbis.load_from_buffer(FileAccess.get_file_as_bytes(path))
			"glb":
				var document := GLTFDocument.new()
				var state := GLTFState.new()
				if document.append_from_file(path, state) != OK:
					continue
				var node := document.generate_scene(state)
				var scene := PackedScene.new()
				scene.pack(node)
				node.free()
				resource = scene
		if resource != null:
			resource.take_over_path(path)
			keep.append(resource)


func _arguments() -> bool:
	var args := OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		if args[i] == "--follow-walk-turn":
			follow_walk_turn = true
			i += 1
			continue
		if i + 1 >= args.size():
			push_error("Missing argument value: " + args[i])
			return false
		var value := args[i + 1]
		match args[i]:
			"--hz":
				if not value.is_valid_int():
					return false
				hz = value.to_int()
			"--label": label = value
			"--seeds":
				var bounds := value.split(":")
				if bounds.size() > 2 or not bounds[0].is_valid_int() or not bounds[-1].is_valid_int():
					return false
				seed_first = bounds[0].to_int()
				seed_last = bounds[-1].to_int()
			_:
				push_error("Unknown argument: " + args[i])
				return false
		i += 2
	return hz > 0 and seed_last >= seed_first


func _xyz(at: Vector3) -> Array:
	return [at.x, at.y, at.z]


func _path_to(game, from: Vector3, to: Vector3) -> PackedVector3Array:
	var path: PackedVector3Array = game.find_path(from, to)
	# find_path can return a partial path or snap a blocked destination elsewhere.
	if path.is_empty() or path[path.size() - 1].distance_to(to) > REACHED_M:
		return PackedVector3Array()
	return path


func _reachable(game, from: Vector3, to: Vector3) -> bool:
	return from.distance_to(to) <= REACHED_M or not _path_to(game, from, to).is_empty()


func _move_leg(name: String, points: Array, run: bool = false) -> Dictionary:
	return {"name": name, "points": points, "run": run}


func _skip_leg(name: String, reason: String) -> Dictionary:
	return {"name": name, "points": [], "reason": reason}


func _far_leg(game, from: Vector3, route_rng: RandomNumberGenerator, name: String, run: bool) -> Dictionary:
	for attempt in range(ROUTE_ATTEMPTS):
		var angle := route_rng.randf_range(-PI, PI)
		var radius := route_rng.randf_range(23.0, 27.0)
		var near: Vector3 = game.walkable_near(from + Vector3(sin(angle), 0, cos(angle)) * radius)
		var target: Vector3 = game.lift(FieldGrid.cell_of(near), game.level_of(from))
		var distance := from.distance_to(target)
		if distance < 22.0 or distance > 28.0:
			continue
		if game.grid_at(target).people_can_walk(FieldGrid.cell_of(target)) and _reachable(game, from, target):
			return _move_leg(name, [target], run)
	# A failed random search does not establish that the ring is unreachable.
	var candidates: Array = []
	for y in range(maxi(0, floori(from.z - 28)), mini(game.grid.height, ceili(from.z + 28) + 1)):
		for x in range(maxi(0, floori(from.x - 28)), mini(game.grid.width, ceili(from.x + 28) + 1)):
			var target: Vector3 = game.lift(Vector2i(x, y), game.level_of(from))
			var distance := from.distance_to(target)
			if distance >= 22.0 and distance <= 28.0 and game.grid_at(target).people_can_walk(Vector2i(x, y)):
				candidates.append({"target": target, "cost": absf(distance - 25.0), "order": candidates.size()})
	candidates.sort_custom(func(a, b):
		return a["order"] < b["order"] if is_equal_approx(a["cost"], b["cost"]) else a["cost"] < b["cost"])
	for candidate in candidates:
		if _reachable(game, from, candidate["target"]):
			return _move_leg(name, [candidate["target"]], run)
	return _skip_leg(name, "no_reachable_target_22_to_28_m")


func _door_leg(game, from: Vector3) -> Dictionary:
	var doors: Array = game.grid.doors.keys()
	doors.sort_custom(func(a, b):
		var da := from.distance_squared_to(FieldGrid.center(a))
		var db := from.distance_squared_to(FieldGrid.center(b))
		return game.grid.index(a) < game.grid.index(b) if is_equal_approx(da, db) else da < db)
	var unlocked := 0
	for cell: Vector2i in doors:
		if game.grid.doors[cell]["state"] == "locked":
			continue
		unlocked += 1
		if not game.grid.people_can_walk(cell):
			continue
		var outer: int = game.grid.outer_face(cell)
		if outer < 0:
			continue
		var faces: Array = game.grid.faces(cell)
		var out_cell: Vector2i = faces[outer]
		var inward: Vector2i = cell - out_cell
		var inside_cell := cell + inward * 3
		var outside_cell := cell - inward * 3
		var valid := true
		for offset in range(-3, 4):
			var c := cell + inward * offset
			if not game.grid.people_can_walk(c):
				valid = false
			if offset < 0 and game.grid.indoor(c):
				valid = false
			if offset > 0 and (not game.grid.indoor(c) or game.grid.building_at(c) != game.grid.building_at(faces[1 - outer])):
				valid = false
		if not valid:
			continue
		var points: Array = [FieldGrid.center(out_cell), FieldGrid.center(cell),
			FieldGrid.center(inside_cell), FieldGrid.center(outside_cell)]
		var previous := from
		for point: Vector3 in points:
			if not _reachable(game, previous, point):
				valid = false
				break
			previous = point
		if valid:
			var leg := _move_leg("building", points)
			leg["door_cell"] = [cell.x, cell.y]
			return leg
	return _skip_leg("building", "no_doors" if doors.is_empty() else (
		"all_doors_locked" if unlocked == 0 else "no_reachable_unlocked_door_with_3_m_clearance"))


func _narrow_cell(grid, cell: Vector2i, axis: Vector2i) -> bool:
	if not grid.people_can_walk(cell):
		return false
	var side := Vector2i(-axis.y, axis.x)
	var width := 1
	for s: Vector2i in [side, -side]:
		var c: Vector2i = cell + s
		while grid.inside(c) and grid.people_can_walk(c):
			width += 1
			if width > NARROW_W:
				return false
			c += s
		# Map edges are not a wall pair: the way ends in a wall on both sides.
		if not grid.inside(c):
			return false
	return true


func _narrow_leg(game, from: Vector3) -> Dictionary:
	var candidates: Array = []
	for axis: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		for y in range(1, game.grid.height - 1):
			for x in range(1, game.grid.width - 1):
				var first := Vector2i(x, y)
				if not _narrow_cell(game.grid, first, axis) or _narrow_cell(game.grid, first - axis, axis):
					continue
				var end := first
				var length := 0
				while _narrow_cell(game.grid, end, axis):
					length += 1
					end += axis
				if length < 3 or not game.grid.people_can_walk(first - axis) or not game.grid.people_can_walk(end):
					continue
				var a := FieldGrid.center(first - axis)
				var b := FieldGrid.center(end)
				if from.distance_squared_to(b) < from.distance_squared_to(a):
					var swap := a
					a = b
					b = swap
				candidates.append({"points": [a, b], "length": length,
					"distance": from.distance_squared_to(a), "order": candidates.size()})
	candidates.sort_custom(func(a, b):
		return a["order"] < b["order"] if is_equal_approx(a["distance"], b["distance"]) else a["distance"] < b["distance"])
	for candidate in candidates:
		var points: Array = candidate["points"]
		if _reachable(game, from, points[0]) and _reachable(game, points[0], points[1]):
			var leg := _move_leg("narrow", points)
			leg["narrow_cells"] = candidate["length"]
			leg["seconds"] = NARROW_SECONDS
			return leg
	return _skip_leg("narrow", "no_reachable_corridor_3_cells_long_at_most_2_wide")


func _plan(game, run_seed: int) -> Array:
	var route_rng := RandomNumberGenerator.new()
	route_rng.seed = run_seed
	var at: Vector3 = game.player.position
	var walk := _far_leg(game, at, route_rng, "walk", false)
	if not walk["points"].is_empty():
		at = walk["points"][-1]
	var run := _far_leg(game, at, route_rng, "run", true)
	if not run["points"].is_empty():
		at = run["points"][-1]
	var building := _door_leg(game, at)
	if not building["points"].is_empty():
		at = building["points"][-1]
	var narrow := _narrow_leg(game, at)
	return [walk, {"name": "stand_1", "stand": true, "points": []}, run,
		building, narrow, {"name": "stand_2", "stand": true, "points": []}]


func _new_metrics() -> Dictionary:
	return {"lag_values": [], "lag_sum": 0.0, "lag_max": 0.0, "moving_s": 0.0,
		"over_6_s": 0.0, "walk_s": 0.0, "fan_s": 0.0, "stuck": 0,
		"jam_count": 0, "jam_s": 0.0, "jam_excess_s": 0.0, "hold_excluded_s": 0.0,
		"overlap_s": 0.0, "block_s": 0.0, "moving_changes": 0, "running_changes": 0,
		"state_changes": 0, "jump": 0, "camera_s": 0.0, "camera_eligible_s": 0.0,
		"observed_s": 0.0, "stop_reasons": {}, "stop_contexts": {},
		"narrow_away_values": [], "narrow_away_max": 0.0, "narrow_outside_s": 0.0,
		"camera_axis_s": 0.0, "camera_axis_eligible_s": 0.0}


func _new_observer(game, mate) -> Dictionary:
	return {"person": mate, "role": game.ai._pick_role(mate), "metrics": _new_metrics(),
		"stuck_at": mate.position, "stuck_s": 0.0,
		"jam_cell": Vector2i(-1, -1), "jam_at": mate.position, "jam_s": 0.0, "jam_active": false}


func _snapshot(game, observers: Array, delta: float) -> Array:
	var rows: Array = []
	for i in range(observers.size()):
		var p = observers[i]["person"]
		var think_left: float = p.brain.get("think_t", game.ai.THINK * float(i) / 3.0)
		rows.append({"at": p.position, "moving": p.moving, "running": p.running,
			"path": not p.path.is_empty(), "path_points": p.path.size(), "action": p.action,
			"think_due": think_left - delta <= 0.0})
	return rows


func _observe_stuck(game, observer: Dictionary, before: Dictionary) -> void:
	var p = observer["person"]
	# Observe on the AI's staggered THINK cadence, not every video/physics tick.
	# Keep a separate timer: never call _watch_stuck or write its brain fields.
	if not before["think_due"]:
		return
	var moved: float = p.position.distance_to(observer["stuck_at"])
	observer["stuck_at"] = p.position
	if not p.is_alive() or not p.can_act() or before["action"] != "" or p.action != "" \
		or not before["path"] or (p.path.is_empty() and not p.brain.has("stuck_t")) \
		or moved > STUCK_MOVE_M:
		observer["stuck_s"] = 0.0
		return
	observer["stuck_s"] += game.ai.THINK
	if observer["stuck_s"] + 0.000001 >= STUCK_SECONDS:
		observer["metrics"]["stuck"] += 1
		observer["stuck_s"] = 0.0


func _observe_door(game, observer: Dictionary, delta: float) -> void:
	var p = observer["person"]
	var m: Dictionary = observer["metrics"]
	var cell := Vector2i(-1, -1)
	var nearest := JAM_RADIUS_M
	if game.level_of(p.position) == 0:
		# Only doors in the 5x5 neighbourhood can be within 1.5 m.
		var here := FieldGrid.cell_of(p.position)
		for y in range(here.y - 2, here.y + 3):
			for x in range(here.x - 2, here.x + 3):
				var c := Vector2i(x, y)
				if game.grid.doors.has(c):
					var distance: float = p.position.distance_to(FieldGrid.center(c))
					if distance <= nearest:
						nearest = distance
						cell = c
	if cell.x >= 0 and game.ai._pick_role(p) == "rear" and game.ai._holds_door(p):
		m["hold_excluded_s"] += delta
		cell = Vector2i(-1, -1)
	if cell.x < 0 or cell != observer["jam_cell"] or p.position.distance_to(observer["jam_at"]) > JAM_MOVE_M:
		observer["jam_cell"] = cell
		observer["jam_at"] = p.position
		observer["jam_s"] = 0.0
		observer["jam_active"] = false
	if cell.x < 0:
		return
	var previous: float = observer["jam_s"]
	observer["jam_s"] += delta
	var current: float = observer["jam_s"]
	if current > JAM_SECONDS + 0.000001:
		m["jam_excess_s"] += maxf(0.0, current - JAM_SECONDS) - maxf(0.0, previous - JAM_SECONDS)
		if not observer["jam_active"]:
			observer["jam_active"] = true
			m["jam_count"] += 1
			m["jam_s"] += current
		else:
			m["jam_s"] += delta


## Decision 486: duplicate the projection here so observation cannot change AI state.
func _trail_projection(game, at: Vector3) -> Dictionary:
	var newer: Vector3 = game.player.position
	var walked: float = 0.0
	var best: float = INF
	var back: float = 0.0
	var trail: PackedVector3Array = game.ai._follow_trail
	for i in range(game.ai._follow_count):
		var older: Vector3 = trail[(game.ai._follow_head - 1 - i + trail.size()) % trail.size()]
		var way: Vector3 = older - newer
		var length: float = way.length()
		if length > 0.001 and game.level_of(at) == game.level_of(newer) and game.level_of(newer) == game.level_of(older):
			var share: float = clampf((at - newer).dot(way) / way.length_squared(), 0.0, 1.0)
			var distance: float = at.distance_squared_to(newer + way * share)
			if distance < best:
				best = distance
				back = walked + length * share
		walked += length
		newer = older
	if best == INF:
		var fwd: Vector3 = Vector3(sin(game.player.facing), 0, cos(game.player.facing))
		if game.player.moving and game.player.drive_speed > 0.0 and game.player.drive_dir.length_squared() > 0.0001:
			fwd = Vector3(game.player.drive_dir.x, 0, game.player.drive_dir.z).normalized()
		elif game.player.moving:
			for point: Vector3 in game.player.path:
				var way: Vector3 = point - game.player.position
				way.y = 0.0
				if way.length() > 0.12:
					fwd = way.normalized()
					break
		back = (game.player.position - at).dot(fwd)
		best = at.distance_squared_to(game.player.position - fwd * back)
	return {"back": back, "away": sqrt(best)}


## Decision 486: a corner flag means there is a walkable neighbour on both axes.
func _corner_cell(game) -> bool:
	var grid = game.grid_at(game.player.position)
	var cell: Vector2i = FieldGrid.cell_of(game.player.position)
	return (grid.people_can_walk(cell + Vector2i.LEFT) or grid.people_can_walk(cell + Vector2i.RIGHT)) \
		and (grid.people_can_walk(cell + Vector2i.UP) or grid.people_can_walk(cell + Vector2i.DOWN))


func _stop_reason(game, p, before: Dictionary) -> String:
	if game.combat.feet_held(p):
		return "feet_held"
	if not p.path.is_empty():
		return "turn_stop"
	if bool(p.brain.get("follow_waiting", false)) or bool(p.brain.get("follow_gap_waiting", false)):
		return "queue_wait"
	var slot: Variant = p.brain.get("follow_slot")
	if not game.player.moving and slot is Vector3 and p.position.distance_to(slot) <= 0.3:
		return "settled"
	if int(before["path_points"]) == 1:
		return "path_end"
	return "no_path"


func _sample(game, observers: Array, before: Array, player_before: Vector3, clock: Dictionary, delta: float) -> void:
	var player = game.player
	var motion: Dictionary = clock["player_motion"]
	if bool(clock["player_was_moving"]) != player.moving:
		motion["moving_changes"] += 1
	var step: Vector3 = player.position - player_before
	step.y = 0.0
	if step.length_squared() > 0.000001:
		var last: Vector3 = clock["player_last_direction"]
		if last != Vector3.ZERO and last.dot(step.normalized()) < -0.5:
			motion["reversals"] += 1
		clock["player_last_direction"] = step.normalized()
	var corner: bool = _corner_cell(game)
	clock["still_s"] = 0.0 if player.moving else float(clock["still_s"]) + delta
	var forward: Vector3 = player.position - player_before
	forward.y = 0.0
	if forward.length_squared() < 0.000001 and not player.path.is_empty():
		forward = player.path[0] - player.position
		forward.y = 0.0
	if forward.length_squared() < 0.000001:
		forward = Vector3(sin(player.facing), 0, cos(player.facing))
	forward = forward.normalized()
	var overlaps: Dictionary = {}
	for i in range(game.squad.size()):
		for j in range(i + 1, game.squad.size()):
			if game.squad[i].position.distance_to(game.squad[j].position) < 0.5:
				overlaps[game.squad[i]] = true
				overlaps[game.squad[j]] = true
				clock["pair_overlap_s"] += delta
	if overlaps.has(player):
		clock["player_overlap_s"] += delta
	for i in range(observers.size()):
		var o: Dictionary = observers[i]
		var p = o["person"]
		var m: Dictionary = o["metrics"]
		var old: Dictionary = before[i]
		m["observed_s"] += delta
		var distance: float = p.position.distance_to(player.position)
		if player.moving:
			m["lag_values"].append(distance)
			m["lag_sum"] += distance
			m["lag_max"] = maxf(m["lag_max"], distance)
			m["moving_s"] += delta
			if distance > 6.0:
				m["over_6_s"] += delta
			if not player.running:
				m["walk_s"] += delta
				if distance >= 2.0 and distance <= 4.0:
					m["fan_s"] += delta
			var toward: Vector3 = p.position - player.position
			toward.y = 0.0
			if distance < 1.0 and (toward.length_squared() < 0.000001 or forward.dot(toward.normalized()) >= cos(deg_to_rad(35.0))):
				m["block_s"] += delta
		if overlaps.has(p):
			m["overlap_s"] += delta
		if bool(old["moving"]) != p.moving:
			m["moving_changes"] += 1
			if not p.moving:
				var reason: String = _stop_reason(game, p, old)
				var context: String = "%s|%s|%s|%s" % [clock["leg"], reason,
					"queue" if bool(p.brain.get("follow_queue", false)) else "formation",
					"corner" if corner else "straight"]
				m["stop_reasons"][reason] = int(m["stop_reasons"].get(reason, 0)) + 1
				m["stop_contexts"][context] = int(m["stop_contexts"].get(context, 0)) + 1
		if clock["leg"] == "narrow":
			var away: float = float(_trail_projection(game, p.position)["away"])
			m["narrow_away_values"].append(away)
			m["narrow_away_max"] = maxf(float(m["narrow_away_max"]), away)
			if away > 1.0:
				m["narrow_outside_s"] += delta
		if bool(old["running"]) != p.running:
			m["running_changes"] += 1
		if bool(old["moving"]) != p.moving or bool(old["running"]) != p.running:
			m["state_changes"] += 1
		if p.position.distance_to(old["at"]) > 1.0:
			m["jump"] += 1
		if float(clock["still_s"]) > STILL_SECONDS + 0.000001 and game.camera != null:
			var camera_axis: Vector3 = game.camera.global_transform.basis.z
			camera_axis.y = 0.0
			if camera_axis.length_squared() > 0.000001:
				m["camera_axis_eligible_s"] += delta
				var axis_angle: float = p.look if p.turn_rate > 0.0 else p.facing
				if Vector3(sin(axis_angle), 0, cos(axis_angle)).dot(camera_axis.normalized()) >= cos(deg_to_rad(45.0)):
					m["camera_axis_s"] += delta
			var to_camera: Vector3 = game.camera.global_position - p.global_position
			to_camera.y = 0.0
			if to_camera.length_squared() > 0.000001:
				m["camera_eligible_s"] += delta
				var shown: Variant = p.get("look")
				var angle: float = p.facing if shown == null or p.turn_rate <= 0.0 else float(shown)
				var gaze := Vector3(sin(angle), 0, cos(angle))
				if gaze.dot(to_camera.normalized()) >= cos(deg_to_rad(45.0)):
					m["camera_s"] += delta
		_observe_stuck(game, o, old)
		_observe_door(game, o, delta)


func _run_leg(game, leg: Dictionary, observers: Array, clock: Dictionary) -> Dictionary:
	# Decision 486: keep per-leg diagnostics without changing whole-trial accumulators.
	var prior: Array = []
	for observer: Dictionary in observers:
		prior.append(observer["metrics"])
		observer["metrics"] = _new_metrics()
	clock["leg"] = leg["name"]
	clock["player_motion"] = {"moving_changes": 0, "reversals": 0}
	clock["player_last_direction"] = Vector3.ZERO
	var row: Dictionary = _run_leg_body(game, leg, observers, clock)
	var combined: Dictionary = _new_metrics()
	for i in range(observers.size()):
		var metrics: Dictionary = observers[i]["metrics"]
		_merge_metrics(combined, metrics)
		_merge_metrics(prior[i], metrics)
		observers[i]["metrics"] = prior[i]
	row["metrics"] = _metrics_row(combined, float(row["seconds"]))
	row["player_motion"] = clock["player_motion"]
	return row


func _run_leg_body(game, leg: Dictionary, observers: Array, clock: Dictionary) -> Dictionary:
	var row := {"name": leg["name"], "seconds": 0.0, "state": "completed", "waypoints": []}
	for point: Vector3 in leg["points"]:
		row["waypoints"].append(_xyz(point))
	for key in ["door_cell", "narrow_cells", "run"]:
		if leg.has(key):
			row[key] = leg[key]
	if leg.has("reason"):
		row.merge({"state": "skipped", "reason": leg["reason"]}, true)
		return row
	if clock["failure_code"] != "":
		row.merge({"state": "interrupted", "reason": clock["failure_code"]}, true)
		return row
	game.player.stop()
	var standing: bool = leg.get("stand", false)
	if standing:
		game.player.running = false
	var waypoint := 0
	var needs_path := true
	var delta := 1.0 / hz
	var limit := roundi((STAND_SECONDS if standing else float(leg.get("seconds", LEG_SECONDS))) * hz)
	for tick in range(limit):
		if not standing and needs_path:
			while waypoint < leg["points"].size() and game.player.position.distance_to(leg["points"][waypoint]) <= REACHED_M:
				waypoint += 1
			if waypoint == leg["points"].size():
				return row
			var path := _path_to(game, game.player.position, leg["points"][waypoint])
			if path.is_empty():
				row.merge({"state": "skipped", "reason": "waypoint_unreachable", "waypoint_index": waypoint}, true)
				return row
			game.player.go_to(path, bool(leg.get("run", false)))
			needs_path = false
		# train_guard has a second spawn queue, separate from pending_spawn.
		game.pending_spawn.clear()
		game.train_guard.fill_due.clear()
		var before := _snapshot(game, observers, delta)
		var player_before: Vector3 = game.player.position
		clock["player_was_moving"] = game.player.moving
		game._step(delta)
		# Later systems may queue a horde after _update_spawns; it must stay empty too.
		game.pending_spawn.clear()
		# _step advances look, but the normal _process owns camera movement.
		game._update_camera(delta)
		var rng_before: int = game.rng.state
		_sample(game, observers, before, player_before, clock, delta)
		if game.rng.state != rng_before:
			clock["failure_code"] = "F-MEASUREMENT-RNG"
			clock["rng_unchanged"] = false
		row["seconds"] = float(tick + 1) * delta
		clock["ticks"] += 1
		if not game.zombies.list.is_empty() or not game.pending_spawn.is_empty():
			clock["failure_code"] = "F-ZOMBIE-SPAWN"
		if game.ended:
			clock["failure_code"] = "F-FIELD-ENDED"
		if clock["failure_code"] != "":
			row.merge({"state": "interrupted", "reason": clock["failure_code"]}, true)
			return row
		if not standing and game.player.path.is_empty():
			if game.player.position.distance_to(leg["points"][waypoint]) <= REACHED_M:
				waypoint += 1
				needs_path = true
				if waypoint == leg["points"].size():
					return row
	if not standing:
		row.merge({"state": "timeout", "waypoint_index": waypoint}, true)
	game.player.stop()
	return row


func _trial(run_seed: int, total: Dictionary, by_mate: Dictionary) -> Dictionary:
	var game = game_script.new()
	game.opts = {"seed": run_seed, "raiders": false, "auto_pause": false, "follow_walk_turn": follow_walk_turn}
	root.add_child(game)
	game.set_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var trial := _new_metrics()
	var row := {"kind": "trial", "label": label, "seed": run_seed, "legs": [],
		"per_mate": [], "seconds": 0.0, "ticks": 0, "failure_code": ""}
	if game.player == null or game.squad.size() != 4:
		row.merge(_metrics_row(trial, 0.0))
		row["failure_code"] = "F-SQUAD-INIT"
		row["state"] = "failed"
		_add_player_overlap(row, 0.0, 0.0)
		game.free()
		return row
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.train_guard.fill_due.clear()
	var observers: Array = []
	for p in game.squad:
		if p != game.player:
			p.command = "follow"
			observers.append(_new_observer(game, p))
	var clock := {"ticks": 0, "still_s": 0.0, "player_overlap_s": 0.0,
		"pair_overlap_s": 0.0, "failure_code": "", "rng_unchanged": true}
	var rng_before: int = game.rng.state
	var plan := _plan(game, run_seed)
	if game.rng.state != rng_before:
		clock["failure_code"] = "F-ROUTE-RNG"
		clock["rng_unchanged"] = false
	for leg in plan:
		row["legs"].append(_run_leg(game, leg, observers, clock))
	# Optional geometry can be skipped, but missing the walk/run is an incomplete trial.
	for leg in row["legs"]:
		if leg["name"] in ["walk", "run"] and leg["state"] == "skipped" and clock["failure_code"] == "":
			clock["failure_code"] = "F-ROUTE-TARGET"
	var duration := float(clock["ticks"]) / hz
	for observer in observers:
		var p = observer["person"]
		var m: Dictionary = observer["metrics"]
		var mate_row := _metrics_row(m, duration)
		mate_row.merge({"id": p.pid, "role": observer["role"]})
		row["per_mate"].append(mate_row)
		_merge_metrics(trial, m)
		if not by_mate.has(p.pid):
			by_mate[p.pid] = {"role": observer["role"], "metrics": _new_metrics()}
		_merge_metrics(by_mate[p.pid]["metrics"], m)
	_merge_metrics(total, trial)
	row.merge(_metrics_row(trial, duration))
	row.merge({"seconds": duration, "ticks": clock["ticks"],
		"failure_code": clock["failure_code"], "state": "completed" if clock["failure_code"] == "" else "failed",
		"measurement_rng_unchanged": clock["rng_unchanged"]}, true)
	_add_player_overlap(row, float(clock["player_overlap_s"]), float(clock["pair_overlap_s"]))
	game.free()
	return row


func _merge_metrics(into: Dictionary, source: Dictionary) -> void:
	for key in source:
		if key in ["lag_values", "narrow_away_values"]:
			into[key].append_array(source[key])
		elif key in ["lag_max", "narrow_away_max"]:
			into[key] = maxf(into[key], source[key])
		elif key in ["stop_reasons", "stop_contexts"]:
			for name: String in source[key]:
				into[key][name] = int(into[key].get(name, 0)) + int(source[key][name])
		else:
			into[key] += source[key]


func _ratio(numerator: float, denominator: float) -> Variant:
	return numerator / denominator if denominator > 0.0 else null


func _metrics_row(m: Dictionary, duration: float) -> Dictionary:
	var distances: Array = m["lag_values"].duplicate()
	distances.sort()
	var n := distances.size()
	var changes: int = m["moving_changes"] + m["running_changes"]
	var away: Array = m["narrow_away_values"].duplicate()
	away.sort()
	var reason_rows: Dictionary = {}
	for reason: String in ["turn_stop", "path_end", "queue_wait", "settled", "no_path", "feet_held"]:
		var count: int = int(m["stop_reasons"].get(reason, 0))
		reason_rows[reason] = {"count": count, "per_mate_minute": _ratio(count * 60.0, m["observed_s"])}
	var ai_stops: int = int(m["stop_reasons"].get("queue_wait", 0)) + int(m["stop_reasons"].get("settled", 0))
	reason_rows["ai_stop"] = {"count": ai_stops, "per_mate_minute": _ratio(ai_stops * 60.0, m["observed_s"])}
	return {"observed_mate_seconds": m["observed_s"],
		"stop_reasons": reason_rows, "stop_contexts": m["stop_contexts"],
		"narrow_away": {"samples": away.size(),
			"p95_m": away[ceili(0.95 * away.size()) - 1] if not away.is_empty() else null,
			"max_m": m["narrow_away_max"] if not away.is_empty() else null,
			"over_1_m_person_seconds": m["narrow_outside_s"]},
		"face_camera_axis": {"person_seconds": m["camera_axis_s"], "eligible_person_seconds": m["camera_axis_eligible_s"],
			"fraction": _ratio(m["camera_axis_s"], m["camera_axis_eligible_s"])},
		"lag": {"mean_m": _ratio(m["lag_sum"], n),
			"p95_m": distances[ceili(0.95 * n) - 1] if n > 0 else null,
			"max_m": m["lag_max"] if n > 0 else null, "samples": n,
			"moving_person_seconds": m["moving_s"], "over_6_m_person_seconds": m["over_6_s"]},
		"fan": {"fraction": _ratio(m["fan_s"], m["walk_s"]),
			"in_band_person_seconds": m["fan_s"], "walking_person_seconds": m["walk_s"]},
		"stuck": {"count": m["stuck"]},
		"door_jam": {"count": m["jam_count"], "person_seconds": m["jam_s"],
			"excess_person_seconds": m["jam_excess_s"], "rear_hold_excluded_seconds": m["hold_excluded_s"]},
		"overlap": {"person_seconds": m["overlap_s"]}, "block": {"person_seconds": m["block_s"]},
		"stop_go": {"changes": changes, "moving_changes": m["moving_changes"],
			"running_changes": m["running_changes"], "state_changes": m["state_changes"],
			"per_minute": _ratio(changes * 60.0, duration),
			"per_mate_minute": _ratio(changes * 60.0, m["observed_s"])},
		"jump": {"count": m["jump"]},
		"face_camera": {"person_seconds": m["camera_s"], "eligible_person_seconds": m["camera_eligible_s"],
			"fraction": _ratio(m["camera_s"], m["camera_eligible_s"])}}


func _add_player_overlap(row: Dictionary, player_seconds: float, pair_seconds: float) -> void:
	row["overlap"]["person_seconds"] += player_seconds
	row["overlap"]["player_person_seconds"] = player_seconds
	row["overlap"]["pair_seconds"] = pair_seconds
