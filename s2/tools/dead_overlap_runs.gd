extends SceneTree
## Fixed-horizon, fixed-input comparison. No imports, saves, or extra output files.
## Before must be run on HEAD 3d074f4c8a6db0cbc25435192bc5e04829647ee1.
## --phase before|after --seeds 1:20 --seconds 300 --hz 30 --mode both
## --bench-only runs the 150-body, 1,000-tick separation benchmark.

const FieldGrid = preload("res://game/world/field_grid.gd")
const REPORT := "res://game/actors/_result_dead_sep.md"
const BEFORE_SHA256 := "f90d0ef58214a408aceee932a87f9a070df8ee2932f67090fe104611aaa1fd48"
const OVERLAP_R := 0.4
const WALK_CELLS := [Vector2i(80, 12), Vector2i(90, 32), Vector2i(60, 40),
	Vector2i(30, 32), Vector2i(30, 12), Vector2i(50, 6)]

var textures: Array[Resource] = []
var game_script: GDScript
var measured_zombies: GDScript
var phase := "after"
var hz := 30
var seconds := 300.0
var seed_first := 1
var seed_last := 20
var modes: Array[String] = ["walk", "holdout"]
var bench_only := false
var stdout_only := false
var skip_benchmark := false
var checks_only := false


class BenchWorld extends RefCounted:
	var grid = FieldGrid.new(64, 64)
	var stairs: Array = []
	var rng := RandomNumberGenerator.new()
	var opts := {"seed": 1}
	func level_of(at: Vector3) -> int:
		return roundi(at.y / 3.0)
	func level_y(lv: int) -> float:
		return lv * 3.0
	func grid_at(_at: Vector3):
		return grid


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _arguments():
		quit(1)
		return
	if checks_only:
		quit(_checks())
		return
	if phase == "before" and FileAccess.get_sha256("res://game/actors/zombies.gd") != BEFORE_SHA256:
		push_error("Before requires the recorded, unchanged HEAD zombies.gd (including checkout line endings).")
		quit(1)
		return
	# Raw PNGs enter the resource cache in memory: no .godot/imported writes.
	for name in DirAccess.get_files_at("res://game/ui/tex"):
		if name.ends_with(".png"):
			var path := "res://game/ui/tex/" + name
			var png := Image.new()
			png.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
			var texture := ImageTexture.create_from_image(png)
			texture.take_over_path(path)
			textures.append(texture)
	_cache_raw("res://game/ui/fonts")
	_cache_raw("res://audio")
	_cache_raw("res://models/weapons")
	# Drawing choices only; all simulation scripts and values remain unchanged.
	for key in ["building_models", "train_models", "prop_models", "baked_dead", "baked_people"]:
		ProjectSettings.set_setting("visuals/" + key + "_enabled", false)
	# This visual script alone refers to its global class name. Resolve its two
	# self-constructors by path when no editor class cache exists, in memory only.
	var train_path := "res://game/world/train_model_kit.gd"
	var train_script := GDScript.new()
	train_script.source_code = FileAccess.get_file_as_string(train_path).replace(
		"var kit := TrainModelKit.new()", 'var kit = load("' + train_path + '").new()')
	train_script.take_over_path(train_path)
	if train_script.reload() != OK:
		quit(1)
		return
	textures.append(train_script)
	game_script = GDScript.new()
	game_script.source_code = 'extends "res://game/field_game.gd"\nfunc _save(_result: Dictionary) -> void:\n\tpass\n'
	if game_script.reload() != OK:
		quit(1)
		return
	if phase == "after":
		measured_zombies = GDScript.new()
		measured_zombies.source_code = ('extends "res://game/actors/zombies.gd"\n'
			+ 'var separation_usec: int = 0\nvar separation_calls: int = 0\n'
			+ 'func _separate(delta: float, skip: Dictionary = {}) -> void:\n'
			+ '\tvar started := Time.get_ticks_usec()\n\tsuper._separate(delta, skip)\n'
			+ '\tseparation_usec += Time.get_ticks_usec() - started\n\tseparation_calls += 1\n'
			+ 'func _separation_exclusions() -> Dictionary:\n'
			+ '\tvar started := Time.get_ticks_usec()\n\tvar skip := super._separation_exclusions()\n'
			+ '\tseparation_usec += Time.get_ticks_usec() - started\n\treturn skip\n')
		if measured_zombies.reload() != OK:
			quit(1)
			return
	_record({"kind": "config", "phase": phase, "seeds": [seed_first, seed_last],
		"seconds": seconds, "hz": hz, "modes": modes,
		"engine": Engine.get_version_info()["string"],
		"zombies_sha256": FileAccess.get_sha256("res://game/actors/zombies.gd")})
	if not bench_only:
		for mode in modes:
			for run_seed in range(seed_first, seed_last + 1):
				var row := _trial(run_seed, mode)
				_record(row)
				# Release scene resources between trials; no wall-clock time enters _step.
				await process_frame
	if not skip_benchmark:
		_record(_benchmark())
	quit(0)


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
					push_error("Cannot read raw model: " + path)
					continue
				var node := document.generate_scene(state)
				var scene := PackedScene.new()
				scene.pack(node)
				node.free()
				resource = scene
		if resource != null:
			resource.take_over_path(path)
			textures.append(resource)


func _arguments() -> bool:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var key := args[i]
		if key in ["--bench-only", "--stdout-only", "--skip-benchmark", "--checks-only"]:
			match key:
				"--bench-only": bench_only = true
				"--stdout-only": stdout_only = true
				"--skip-benchmark": skip_benchmark = true
				"--checks-only": checks_only = true
			i += 1
			continue
		if i + 1 >= args.size():
			push_error("Missing value: " + key)
			return false
		var value := args[i + 1]
		match key:
			"--phase": phase = value
			"--hz": hz = value.to_int()
			"--seconds": seconds = value.to_float()
			"--mode":
				if value != "both":
					modes.assign([value])
			"--seeds":
				var bounds := value.split(":")
				seed_first = bounds[0].to_int()
				seed_last = bounds[-1].to_int()
			_:
				push_error("Unknown argument: " + key)
				return false
		i += 2
	return phase in ["before", "after"] and hz > 0 and seconds > 0 and seed_last >= seed_first and modes.all(func(m): return m in ["walk", "holdout"])


func _game(run_seed: int, mode: String):
	var game = game_script.new()
	game.opts = {"seed": run_seed, "raiders": false, "auto_pause": false}
	if mode == "holdout":
		game.opts["holdout"] = "start"
	root.add_child(game)
	game.set_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	if measured_zombies != null:
		# A profiling subclass, preserving every original script property.
		var saved: Dictionary = {}
		for prop in game.zombies.get_property_list():
			if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				saved[prop["name"]] = game.zombies.get(prop["name"])
		game.zombies.set_script(measured_zombies)
		for key in saved:
			game.zombies.set(key, saved[key])
	return game


func _trial(run_seed: int, mode: String) -> Dictionary:
	var game = _game(run_seed, mode)
	var delta := 1.0 / hz
	var ticks := roundi(seconds * hz)
	var total_pairs := 0
	var max_pairs := 0
	var streaks: Dictionary = {}
	var long_pairs: Dictionary = {}
	var fallen: Dictionary = {}
	var initially_fallen: Dictionary = {}
	var first_end := -1.0
	var max_dead := 0
	for z in game.zombies.list:
		if z["state"] in ["dead", "downed", "rising"]:
			initially_fallen[z["id"]] = true
	var started := Time.get_ticks_usec()
	for tick in range(ticks):
		if mode == "walk" and tick % (hz * 2) == 0 and game.player.can_act() and game.player.action == "":
			var goal: Vector2i = WALK_CELLS[mini(int(float(tick) / hz / 50.0), WALK_CELLS.size() - 1)]
			game.player.go_to(game.find_path(game.player.position, game.lift(goal, 0)), false)
		# Deliberately a 300-second simulation horizon, even if the UI has ended.
		# Record that first end separately; never change health, AI, or combat rules.
		game._step(delta)
		if game.ended and first_end < 0.0:
			first_end = (tick + 1) * delta
		var pairs := _overlaps(game)
		total_pairs += pairs.size()
		max_pairs = maxi(max_pairs, pairs.size())
		var next_streaks: Dictionary = {}
		for pair in pairs:
			var count := int(streaks.get(pair, 0)) + 1
			next_streaks[pair] = count
			if count > hz:
				long_pairs[pair] = true
		streaks = next_streaks
		max_dead = maxi(max_dead, game.zombies.list.size())
		for z in game.zombies.list:
			if z["state"] in ["downed", "dead"] and not initially_fallen.has(z["id"]):
				fallen[z["id"]] = true
	var bites := 0
	for injury in game.telemetry.injuries:
		if injury["kind"] == "bite":
			bites += 1
	var deaths := 0
	for p in game.squad:
		if p.body.dead:
			deaths += 1
	var cost := float(game.zombies.get("separation_usec")) / 1000.0 if phase == "after" else 0.0
	var row := {"kind": "trial", "phase": phase, "mode": mode, "seed": run_seed,
		"ticks": ticks, "pair_tick_sum": total_pairs, "pairs_mean": float(total_pairs) / ticks,
		"pairs_max": max_pairs, "long_pairs": long_pairs.size(), "fallen": fallen.size(),
		"bites": bites, "deaths": deaths, "separation_ms_total": cost,
		"separation_ms_mean": cost / ticks, "first_end_s": first_end, "max_dead": max_dead,
		"wall_s": float(Time.get_ticks_usec() - started) / 1000000.0}
	game.free()
	return row


## All non-corpse dead, including immovable states: residual overlap is visible.
## Same floor, horizontal distance < 0.4m; each unordered ID pair occurs once.
func _overlaps(game) -> Dictionary:
	var grid: Dictionary = {}
	var pairs: Dictionary = {}
	for z in game.zombies.list:
		if z["state"] in ["dead", "rising", "corpse"]:
			continue
		var at: Vector3 = z["pos"]
		var key := Vector3i(floori(at.x / OVERLAP_R), game.level_of(at), floori(at.z / OVERLAP_R))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for other in grid.get(key + Vector3i(dx, 0, dz), []):
					var to: Vector3 = other["pos"] - at
					if Vector2(to.x, to.z).length_squared() < OVERLAP_R * OVERLAP_R:
						pairs[Vector2i(mini(z["id"], other["id"]), maxi(z["id"], other["id"]))] = true
		if not grid.has(key):
			grid[key] = []
		grid[key].append(z)
	return pairs


func _benchmark() -> Dictionary:
	if phase == "before":
		return {"kind": "benchmark", "phase": phase, "bodies": 150, "ticks": 1000, "ms_mean": 0.0}
	var zombies = load("res://game/actors/zombies.gd").new()
	zombies.game = BenchWorld.new()
	var positions := PackedVector3Array()
	for i in range(150):
		var at := Vector3(20 + (i % 15) * 0.35, 0, 20 + int(i / 15.0) * 0.35)
		positions.append(at)
		zombies.spawn("dead", at, {"target": at + Vector3(10, 0, 0)})
	var micros := 0
	for tick in range(1100):
		for i in range(150):
			zombies.list[i]["pos"] = positions[i]
		var start := Time.get_ticks_usec()
		zombies._separate(1.0 / hz, zombies._separation_exclusions())
		var spent := Time.get_ticks_usec() - start
		if tick >= 100:
			micros += spent
	zombies.free()
	return {"kind": "benchmark", "phase": phase, "bodies": 150, "ticks": 1000,
		"warmup": 100, "spacing_m": 0.35, "ms_mean": float(micros) / 1000000.0}


## GUT itself remains not_run when absent. This deliberately small in-memory
## assertion adapter exercises the same test bodies without installing it.
func _checks() -> int:
	var source := FileAccess.get_file_as_string("res://tests/game/test_dead_separation.gd")
	source = source.replace('extends "res://addons/gut/test.gd"', "extends Node")
	source += """
var check_failures: Array = []
var check_owned: Array = []
func add_child_autofree(node):
	add_child(node)
	check_owned.append(node)
func assert_eq(a, b, message = ""):
	if a != b: check_failures.append("eq: " + str(message))
func assert_ne(a, b, message = ""):
	if a == b: check_failures.append("ne: " + str(message))
func assert_gte(a, b, message = ""):
	if a < b: check_failures.append("gte: " + str(message))
func assert_gt(a, b, message = ""):
	if a <= b: check_failures.append("gt: " + str(message))
func assert_lte(a, b, message = ""):
	if a > b: check_failures.append("lte: " + str(message))
func assert_almost_eq(a, b, tolerance, message = ""):
	if absf(a - b) > tolerance: check_failures.append("almost: " + str(message))
"""
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		return 1
	var suite = script.new()
	root.add_child(suite)
	var results: Array = []
	var failed := 0
	for method in script.get_script_method_list():
		var name: String = method["name"]
		if not name.begins_with("test_"):
			continue
		suite.check_failures.clear()
		suite.before_each()
		suite.call(name)
		var errors: Array = suite.check_failures.duplicate()
		failed += 1 if not errors.is_empty() else 0
		results.append({"test": name, "failures": errors})
		for node in suite.check_owned:
			node.free()
		suite.check_owned.clear()
	suite.free()
	_record({"kind": "checks", "gut": "not_run", "adapter": "headless assertions, not GUT", "cases": results, "failed": failed})
	return 1 if failed > 0 else 0


func _record(row: Dictionary) -> void:
	var text := JSON.stringify(row)
	print(text)
	if stdout_only:
		return
	var file := FileAccess.open(REPORT, FileAccess.READ_WRITE if FileAccess.file_exists(REPORT) else FileAccess.WRITE)
	if file == null:
		push_error("Cannot append the allowed report file.")
		quit(1)
		return
	file.seek_end()
	file.store_line("<!-- dead-overlap " + text + " -->")
