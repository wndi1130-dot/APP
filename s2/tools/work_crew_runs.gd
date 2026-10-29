extends SceneTree
## Decision 486: local, seeded trials of the old and new work-site gates.
## --maps freight_01,freight_02 --seeds 1:10 --seconds 1200 --hz 10
## --press new|old --out <json> writes one JSON object per line, then a summary.
## --budget lists every map's resource budget without making a field game.

const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldWork = preload("res://game/field_work.gd")
const WorkSpots = preload("res://game/world/work_spots.gd")
const PILOT_EVERY: float = 0.25
const PILOT_EXTRA_R: float = 5.0
const QUICK_S: float = 60.0

var maps: Array[String] = ["freight_01", "freight_02"]
var first_seed: int = 1
var last_seed: int = 10
var seconds: float = 1200.0
var hz: int = 10
var press: String = "new"
var output: String = "res://../_out/work_crew_runs.json"
var budget_only: bool = false
var game_script: GDScript
var resources: Array[Resource] = []
var file: FileAccess


func _initialize() -> void:
	_run.call_deferred()


func _arguments() -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		if args[i] == "--budget":
			budget_only = true
			i += 1
			continue
		if i + 1 >= args.size():
			return false
		var value: String = args[i + 1]
		match args[i]:
			"--maps": maps.assign(value.split(",", false))
			"--seeds":
				var span: PackedStringArray = value.split(":")
				if span.size() > 2 or not span[0].is_valid_int() or not span[-1].is_valid_int():
					return false
				first_seed = span[0].to_int()
				last_seed = span[-1].to_int()
			"--seconds":
				if not value.is_valid_float():
					return false
				seconds = value.to_float()
			"--hz":
				if not value.is_valid_int():
					return false
				hz = value.to_int()
			"--press": press = value
			"--out": output = value
			_: return false
		i += 2
	if maps.is_empty() or hz <= 0 or seconds <= 0.0 or first_seed <= 0 or last_seed < first_seed or press not in ["new", "old"] or output.is_empty():
		return false
	for id: String in maps:
		if not FieldMaps.has(id):
			return false
	return true


func _run() -> void:
	if not _arguments():
		push_error("Invalid work-crew arguments.")
		quit(2)
		return
	if FileAccess.file_exists(output):
		push_error("Output already exists; choose a fresh output path.")
		quit(2)
		return
	var folder: String = output.get_base_dir()
	if not folder.is_empty() and DirAccess.make_dir_recursive_absolute(folder) != OK:
		push_error("Cannot create output directory: " + folder)
		quit(2)
		return
	file = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot open output: " + output)
		quit(2)
		return
	if budget_only:
		for id: String in FieldMaps.ids():
			var data: Dictionary = FieldMaps.build(id)
			# The jobs the stop's dress puts on a map without coal wagons (work_spots.gd) count too.
			WorkSpots.dress(data, -1, 1)
			var budget: Dictionary = FieldWork.budget(data)
			var place: String = String(data.get("place_kind", ""))
			if not _record({"map": id, "place": place, "coal": budget["coal"], "wood": budget["wood"],
				"wood_table": FieldWork.WOOD_TABLE.get(place)}):
				file.close()
				quit(2)
				return
		file.close()
		quit(0)
		return
	if not _prepare():
		file.close()
		quit(2)
		return
	var rows: Array[Dictionary] = []
	for id: String in maps:
		for run_seed in range(first_seed, last_seed + 1):
			var row: Dictionary = _trial(id, run_seed)
			rows.append(row)
			if not _record(row):
				file.close()
				quit(2)
				return
			await process_frame
	var recorded: bool = _record(_summary(rows))
	file.close()
	quit(0 if recorded else 2)


## As in body_detail_runs: raw assets stay in memory and trials never save a run.
func _prepare() -> bool:
	for folder: String in ["res://game/ui/tex", "res://game/ui/fonts", "res://audio", "res://models/weapons"]:
		_cache_raw(folder)
	for key: String in ["building_models", "train_models", "prop_models", "baked_dead", "baked_people"]:
		ProjectSettings.set_setting("visuals/" + key + "_enabled", false)
	var train_path: String = "res://game/world/train_model_kit.gd"
	var train_script: GDScript = GDScript.new()
	train_script.source_code = FileAccess.get_file_as_string(train_path).replace(
		"var kit := TrainModelKit.new()", 'var kit = load("' + train_path + '").new()')
	train_script.take_over_path(train_path)
	if train_script.reload() != OK:
		return false
	resources.append(train_script)
	game_script = GDScript.new()
	game_script.source_code = ('extends "res://game/field_game.gd"\n'
		+ 'func _save(_result: Dictionary) -> void:\n\tpass\n')
	return game_script.reload() == OK


func _cache_raw(folder: String) -> void:
	for sub: String in DirAccess.get_directories_at(folder):
		_cache_raw(folder.path_join(sub))
	for name: String in DirAccess.get_files_at(folder):
		var path: String = folder.path_join(name)
		var resource: Resource
		match name.get_extension():
			"png":
				var png: Image = Image.new()
				if png.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
					continue
				resource = ImageTexture.create_from_image(png)
			"ttf":
				var font: FontFile = FontFile.new()
				font.data = FileAccess.get_file_as_bytes(path)
				resource = font
			"wav": resource = AudioStreamWAV.load_from_buffer(FileAccess.get_file_as_bytes(path))
			"ogg": resource = AudioStreamOggVorbis.load_from_buffer(FileAccess.get_file_as_bytes(path))
			"glb":
				var document: GLTFDocument = GLTFDocument.new()
				var state: GLTFState = GLTFState.new()
				if document.append_from_file(path, state) != OK:
					continue
				var node: Node = document.generate_scene(state)
				var scene: PackedScene = PackedScene.new()
				scene.pack(node)
				node.free()
				resource = scene
		if resource != null:
			resource.take_over_path(path)
			resources.append(resource)


func _trial(id: String, run_seed: int) -> Dictionary:
	var game: Variant = game_script.new()
	game.opts = {"place": id, "seed": run_seed, "raiders": false, "auto_pause": false, "field_save": false}
	root.add_child(game)
	game.set_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var row: Dictionary = {"map": id, "seed": run_seed, "t_old": -1.0, "t_new": -1.0, "t_open": -1.0,
		"t_sent": -1.0, "t_hold": -1.0, "t_retreat": -1.0, "quick_retreat": false,
		"player_dead": false, "end": "seconds", "_end_t": 0.0, "downed_near": -1}
	if not game.work.site_ids().has("work_site"):
		row["end"] = "no_work_site"
		game.free()
		return row
	# A site with nothing left to load (a yard whose wagons hold no coal) never lights: not a run of the gate.
	if game.work.remaining() <= FieldWork.EMPTY:
		row["end"] = "empty_site"
		game.free()
		return row
	var dt: float = 1.0 / hz
	var pilot_left: float = 0.0
	var pressed: bool = false
	var event_at: int = 0
	while game.clock.elapsed <= seconds:
		var now: float = game.clock.elapsed
		var old_open: bool = game.actions.site_clear()
		var new_open: bool = bool(game.work.safety()["open"])
		if old_open and float(row["t_old"]) < 0.0:
			row["t_old"] = now
		if new_open and float(row["t_new"]) < 0.0:
			row["t_new"] = now
			row["downed_near"] = _downed_near(game)
		if press == "new":
			## The player taps the key whenever it is lit and nobody has gone out yet.
			if float(row["t_sent"]) < 0.0 and game.work.phase() == "open":
				game.actions.start_work(game.player)
		elif not pressed and old_open:
			pressed = true
			game.actions.start_work(game.player)
		while event_at < game.telemetry.work_events.size():
			var event: Dictionary = game.telemetry.work_events[event_at]
			var key: String = "t_" + String(event["ev"])
			if event["site"] == "work_site" and row.has(key) and float(row[key]) < 0.0:
				row[key] = float(event["t"])
				if key == "t_retreat":
					row["why"] = String(game.work.sites.get("work_site", {}).get("why", ""))
			event_at += 1
		row["_end_t"] = now
		row["player_dead"] = not game.player.is_alive()
		if row["player_dead"] or game.ended or now >= seconds or game.work.phase() == "done":
			row["end"] = "player_dead" if row["player_dead"] else (game.telemetry.end_reason if game.ended else ("done" if game.work.phase() == "done" else "seconds"))
			break
		# Both gate numbers are known once a sent crew has had QUICK_S out: stop the run there.
		if float(row["t_sent"]) >= 0.0 and now >= float(row["t_sent"]) + QUICK_S + 1.0:
			row["end"] = "measured"
			break
		if pilot_left <= 0.0:
			_pilot(game)
			pilot_left += PILOT_EVERY
		var step: float = minf(dt, seconds - now)
		game._step(step)
		pilot_left -= step
	row["quick_retreat"] = float(row["t_sent"]) >= 0.0 and float(row["t_retreat"]) >= float(row["t_sent"]) and float(row["t_retreat"]) - float(row["t_sent"]) <= QUICK_S
	game.free()
	return row


func _pilot(game) -> void:
	var p: Variant = game.player
	if not p.can_act():
		return
	var at: Vector3 = game.work.position_of("work_site")
	var path: PackedVector3Array = game.work.route("work_site")
	var nearest: Dictionary = {}
	var distance: float = INF
	for z: Dictionary in game.zombies.list:
		# The ring the train counts, and the walk from the door it watches.
		if not game.work.awake(z) or (at.distance_to(z["pos"]) > FieldWork.RING_R + PILOT_EXTRA_R and not _near_path(path, z["pos"])):
			continue
		if p.position.distance_to(z["pos"]) < distance:
			nearest = z
			distance = p.position.distance_to(z["pos"])
	if nearest.is_empty():
		p.target_zombie = {}
		if p.position.distance_to(at) > FieldWork.BOARD_R:
			p.go_to(game.find_path(p.position, at), false)
		else:
			p.stop()
		return
	if distance > game.combat.melee_range(p):
		p.go_to(game.find_path(p.position, nearest["pos"]), true)
	else:
		p.stop()
	game.combat.melee_target(p, nearest, true)


## The downed in reach of the site when the gate opens: cleared now, up again later (decision 487).
func _downed_near(game) -> int:
	var at: Vector3 = game.work.position_of("work_site")
	var n: int = 0
	for z: Dictionary in game.zombies.list:
		if z["state"] == "downed" and at.distance_to(z["pos"]) <= FieldWork.NEAR_R:
			n += 1
	return n


func _near_path(path: PackedVector3Array, at: Vector3) -> bool:
	for i in path.size():
		var closest: Vector3 = path[i]
		if i > 0:
			closest = Geometry3D.get_closest_point_to_segment(at, path[i - 1], path[i])
		if closest.distance_to(at) <= FieldWork.PATH_R + PILOT_EXTRA_R:
			return true
	return false


## The gate's numbers over the runs that had something to load: when the key lit (a run that never
## lit counts as later than the stop, so it can only push the median up), and how many sent crews
## were called back within QUICK_S. Also one summary per map.
func _summary(rows: Array[Dictionary], label: String = "all") -> Dictionary:
	var lit: Array[float] = []
	var counted: int = 0
	var sent_count: int = 0
	var observed: int = 0
	var quick: int = 0
	var safe_lit: int = 0
	var downed_lit: int = 0
	for row: Dictionary in rows:
		if row["end"] in ["no_work_site", "empty_site"]:
			continue
		counted += 1
		if int(row.get("downed_near", -1)) >= 0:
			safe_lit += 1
			if int(row["downed_near"]) > 0:
				downed_lit += 1
		lit.append(float(row["t_open"]) if float(row["t_open"]) >= 0.0 else INF)
		if float(row["t_sent"]) >= 0.0:
			sent_count += 1
			if row["quick_retreat"] or float(row["_end_t"]) - float(row["t_sent"]) >= QUICK_S:
				observed += 1
				if row["quick_retreat"]:
					quick += 1
	var middle: Variant = _median(lit)
	var reached: bool = middle != null and is_finite(float(middle))
	var out: Dictionary = {"kind": "summary", "of": label, "press": press, "seconds": seconds, "hz": hz, "runs": rows.size(),
		"counted": counted, "lit": lit.filter(func(t: float) -> bool: return is_finite(t)).size(),
		"median_t_open": middle if reached else null, "median_unreached": middle != null and not reached,
		"median_over_seconds": float(middle) / seconds if reached else null,
		"median_over_1200": float(middle) / 1200.0 if reached else null,
		"sent": sent_count, "quick_retreat_observed": observed, "followup_under_60": sent_count - observed,
		"quick_retreat_share": float(quick) / observed if observed > 0 else null,
		"downed_near_lit": downed_lit, "downed_near_share": float(downed_lit) / safe_lit if safe_lit > 0 else null}
	if label == "all":
		var per_map: Dictionary = {}
		for row: Dictionary in rows:
			if not per_map.has(row["map"]):
				var fresh: Array[Dictionary] = []
				per_map[row["map"]] = fresh
			(per_map[row["map"]] as Array[Dictionary]).append(row)
		var maps_out: Array = []
		for id: String in per_map:
			maps_out.append(_summary(per_map[id], id))
		out["maps"] = maps_out
	return out


func _median(values: Array[float]) -> Variant:
	if values.is_empty():
		return null
	values.sort()
	var mid: int = floori(float(values.size()) / 2.0)
	return values[mid] if values.size() % 2 == 1 else (values[mid - 1] + values[mid]) / 2.0


func _record(row: Dictionary) -> bool:
	var public_row: Dictionary = row.duplicate(true)
	public_row.erase("_end_t")
	var line: String = JSON.stringify(public_row)
	file.store_line(line)
	file.flush()
	print(line)
	return file.get_error() == OK
