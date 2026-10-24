extends SceneTree
## Fixed seeds and inputs; observations never consume simulation random numbers.
## --phase before|after --seeds 1:20 --seconds 300 --hz 30 --mode both
## --checks-only runs test bodies with a small in-memory assertion adapter.

const FieldGrid = preload("res://game/world/field_grid.gd")
const REPORT := "res://../_measure_pz_dead.md"
const WALK_CELLS := [Vector2i(80, 12), Vector2i(90, 32), Vector2i(60, 40),
	Vector2i(30, 32), Vector2i(30, 12), Vector2i(50, 6)]
const SOURCE_FILES := ["game/actors/zombies.gd", "game/sim/grab_rules.gd",
	"game/sim/lunger_rules.gd", "game/sim/horde_director.gd", "game/field_combat.gd",
	"game/sim/sense_rules.gd", "game/sim/dead_separation.gd", "game/field_game.gd",
	"game/field_actions.gd", "game/field_ai.gd", "game/actors/person.gd",
	"game/sim/body_state.gd", "game/sim/weather.gd", "game/sim/noise.gd"]
const BASELINE_DIR := "res://.godot/dead_detail_before/"
const BASELINE_FILES := ["game/sim/grab_rules.gd", "game/sim/lunger_rules.gd",
	"game/sim/horde_director.gd", "game/actors/zombies.gd", "game/field_combat.gd"]

var textures: Array[Resource] = []
var game_script: GDScript
var measured_zombies: GDScript
var phase := "before"
var hz := 30
var seconds := 300.0
var seed_first := 1
var seed_last := 20
var modes: Array[String] = ["walk", "holdout"]
var checks_only := false
var stdout_only := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _arguments() or not _prepare():
		quit(1)
		return
	if checks_only:
		quit(_checks())
		return
	var hashes: Dictionary = {}
	for file in SOURCE_FILES:
		var source: String = _source_path(file)
		if source != "" and FileAccess.file_exists(source):
			hashes[file] = FileAccess.get_sha256(source)
	_record({"kind": "config", "phase": phase, "seeds": [seed_first, seed_last],
		"seconds": seconds, "hz": hz, "modes": modes,
		"engine": Engine.get_version_info()["string"], "source_sha256": hashes,
		"source_identity_verified": true})
	for mode in modes:
		for run_seed in range(seed_first, seed_last + 1):
			_record(_trial(run_seed, mode))
			await process_frame
	quit(0)


func _prepare() -> bool:
	# Cache raw resources in memory; do not run the editor importer or write saves.
	for name in DirAccess.get_files_at("res://game/ui/tex"):
		if name.ends_with(".png"):
			var path := "res://game/ui/tex/" + name
			var png := Image.new()
			if png.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
				return false
			var texture := ImageTexture.create_from_image(png)
			texture.take_over_path(path)
			textures.append(texture)
	_cache_raw("res://game/ui/fonts")
	_cache_raw("res://audio")
	_cache_raw("res://models/weapons")
	for key in ["building_models", "train_models", "prop_models", "baked_dead", "baked_people"]:
		ProjectSettings.set_setting("visuals/" + key + "_enabled", false)
	var train_path := "res://game/world/train_model_kit.gd"
	var train_script := GDScript.new()
	train_script.source_code = FileAccess.get_file_as_string(train_path).replace(
		"var kit := TrainModelKit.new()", 'var kit = load("' + train_path + '").new()')
	train_script.take_over_path(train_path)
	if train_script.reload() != OK:
		return false
	textures.append(train_script)
	if phase == "before" and not checks_only and not _load_baseline():
		return false
	game_script = GDScript.new()
	game_script.source_code = """
extends "res://game/field_game.gd"
var detail_contacts: Array = []
var detail_releases: Dictionary = {}
var detail_last_grab: Dictionary = {}
func _save(_result: Dictionary) -> void:
	pass
func zombie_reaches(z: Dictionary, p) -> String:
	var held: bool = not p.grabbers.is_empty()
	var outcome: String = super.zombie_reaches(z, p)
	if outcome == "grab" and not held:
		var now: float = clock.elapsed
		detail_contacts.append({"t": now, "who": p.pid, "dead": z["id"],
			"gap": now - float(detail_last_grab.get(p.pid, now)),
			"release_gap": now - float(detail_releases.get(p.pid, now)),
			"repeat": detail_last_grab.has(p.pid)})
		detail_last_grab[p.pid] = now
	return outcome
"""
	if game_script.reload() != OK:
		return false
	measured_zombies = GDScript.new()
	measured_zombies.source_code = """
extends "res://game/actors/zombies.gd"
var detail_seen: int = 0
var detail_distance: float = 0.0
var detail_heard: int = 0
var detail_heard_ids: Dictionary = {}
var detail_usec: int = 0
func update(delta: float) -> void:
	var started := Time.get_ticks_usec()
	super.update(delta)
	detail_usec += Time.get_ticks_usec() - started
func _sense(z: Dictionary, people: Array, delta: float) -> void:
	var old_state: String = z["state"]
	var old_victim = z["victim"]
	super._sense(z, people, delta)
	if z["state"] in ["chase", "attack", "tell"] and z["victim"] != null:
		if old_state not in ["chase", "attack", "tell"] or old_victim != z["victim"]:
			detail_seen += 1
			detail_distance += z["pos"].distance_to(z["victim"].position)
func hear(at: Vector3, level: int, radius: float, wind = null) -> int:
	var old: Dictionary = {}
	for z in list:
		old[z["id"]] = [z["state"], z["target"], z["angle"], z.get("turn_t", 0.0)]
	var reacted: int = super.hear(at, level, radius, wind)
	detail_heard += reacted
	for z in list:
		if old.get(z["id"], []) != [z["state"], z["target"], z["angle"], z.get("turn_t", 0.0)]:
			detail_heard_ids[z["id"]] = true
	return reacted
func _remember_release(p) -> void:
	if p != null and p.grabbers.is_empty():
		game.detail_releases[p.pid] = game.clock.elapsed
func release(z: Dictionary, from: Vector3, knock: bool) -> void:
	var p = z.get("victim") if z.get("state") == "grab" else null
	super.release(z, from, knock)
	_remember_release(p)
func knock_down(z: Dictionary) -> void:
	var p = z.get("victim") if z.get("state") == "grab" else null
	super.knock_down(z)
	_remember_release(p)
func kill(z: Dictionary) -> void:
	var p = z.get("victim") if z.get("state") == "grab" else null
	super.kill(z)
	_remember_release(p)
"""
	if measured_zombies.reload() != OK:
		return false
	return _verify_sources()


func _verify_sources() -> bool:
	var field: Dictionary = game_script.get_base_script().get_script_constant_map()
	var dead: Dictionary = field["Zombies"].get_script_constant_map()
	var combat: Dictionary = field["Combat"].get_script_constant_map()
	var pairs: Array = [[field["Zombies"], "game/actors/zombies.gd"],
		[field["Combat"], "game/field_combat.gd"],
		[dead["GrabRules"], "game/sim/grab_rules.gd"],
		[combat["GrabRules"], "game/sim/grab_rules.gd"]]
	if _source_path("game/sim/sense_rules.gd") != "":
		pairs.append([dead["SenseRules"], "game/sim/sense_rules.gd"])
	for pair in pairs:
		var actual: String = pair[0].source_code
		var expected := FileAccess.get_file_as_string(_source_path(pair[1]))
		if actual.replace("\r\n", "\n") != expected.replace("\r\n", "\n"):
			push_error("Loaded rules do not match the recorded source: " + str(pair[1]))
			return false
	return true


func _source_path(file: String) -> String:
	if phase == "before" and not checks_only:
		if file == "game/sim/sense_rules.gd":
			return ""
		if file in BASELINE_FILES:
			return BASELINE_DIR + file.get_file()
	return "res://" + file


## Reproduce the original rules without replacing any live source file.
## Failing to find the initial snapshot must not silently label current code before.
func _load_baseline() -> bool:
	for file in BASELINE_FILES:
		var path: String = _source_path(file)
		if not FileAccess.file_exists(path):
			push_error("Before phase needs its initial source snapshot: " + path)
			return false
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string(path)
		script.take_over_path("res://" + file)
		if script.reload() != OK:
			return false
		textures.append(script)
	return true


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
		if key == "--checks-only" or key == "--stdout-only":
			checks_only = checks_only or key == "--checks-only"
			stdout_only = stdout_only or key == "--stdout-only"
			i += 1
			continue
		if i + 1 >= args.size():
			return false
		var value := args[i + 1]
		match key:
			"--phase": phase = value
			"--hz": hz = value.to_int()
			"--seconds": seconds = value.to_float()
			"--mode":
				if value != "both": modes.assign([value])
			"--seeds":
				var bounds := value.split(":")
				seed_first = bounds[0].to_int()
				seed_last = bounds[-1].to_int()
			_: return false
		i += 2
	return phase in ["before", "after"] and hz > 0 and seconds > 0 and seed_last >= seed_first and modes.all(func(m): return m in ["walk", "holdout"])


func _game(run_seed: int, mode: String):
	var game = game_script.new()
	game.opts = {"seed": run_seed, "raiders": false, "auto_pause": false}
	if mode == "holdout": game.opts["holdout"] = "start"
	root.add_child(game)
	game.set_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
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
	var fallen: Dictionary = {}
	var initially_fallen: Dictionary = {}
	var first_end := -1.0
	var step_usec := 0
	var death_events: Array = []
	var dead_people: Dictionary = {}
	for z in game.zombies.list:
		if z["state"] in ["dead", "downed", "rising"]:
			initially_fallen[z["id"]] = true
	var started := Time.get_ticks_usec()
	for tick in range(ticks):
		if mode == "walk" and tick % (hz * 2) == 0 and game.player.can_act() and game.player.action == "":
			var goal: Vector2i = WALK_CELLS[mini(int(float(tick) / hz / 50.0), WALK_CELLS.size() - 1)]
			game.player.go_to(game.find_path(game.player.position, game.lift(goal, 0)), false)
		var tick_start := Time.get_ticks_usec()
		game._step(delta)
		step_usec += Time.get_ticks_usec() - tick_start
		if game.ended and first_end < 0.0:
			first_end = (tick + 1) * delta
		for z in game.zombies.list:
			if z["state"] in ["downed", "dead"] and not initially_fallen.has(z["id"]):
				fallen[z["id"]] = true
		for p in game.squad:
			if p.body.dead and not dead_people.has(p.pid):
				dead_people[p.pid] = true
				death_events.append({"who": p.pid, "t": game.clock.elapsed})
	var counts := {"grab": 0, "bite": 0, "scratch": 0}
	for injury in game.telemetry.injuries:
		if counts.has(injury["kind"]): counts[injury["kind"]] += 1
	var gaps: Array = []
	var release_gaps: Array = []
	for contact in game.detail_contacts:
		if contact["repeat"]:
			gaps.append(contact["gap"])
			release_gaps.append(contact["release_gap"])
	var n: int = game.zombies.detail_seen
	var row := {"kind": "trial", "phase": phase, "mode": mode, "seed": run_seed,
		"ticks": ticks, "discoveries": n, "discovery_distance_sum": game.zombies.detail_distance,
		"discovery_distance_mean": game.zombies.detail_distance / n if n > 0 else 0.0,
		"noise_unique": game.zombies.detail_heard_ids.size(), "noise_reactions": game.zombies.detail_heard,
		"grabs": counts["grab"], "grab_episodes": game.detail_contacts.size(),
		"regrab_gaps": gaps, "release_gaps": release_gaps,
		"bites": counts["bite"], "scratches": counts["scratch"], "fallen": fallen.size(),
		"deaths": dead_people.size(), "death_events": death_events,
		"dead_ms_mean": float(game.zombies.detail_usec) / 1000.0 / ticks,
		"step_ms_mean": float(step_usec) / 1000.0 / ticks,
		"first_end_s": first_end, "wall_s": float(Time.get_ticks_usec() - started) / 1000000.0,
		"contacts": game.detail_contacts, "injuries": game.telemetry.injuries}
	game.free()
	return row


func _checks() -> int:
	var failed := 0
	var count := 0
	for file in ["test_sense_rules.gd", "test_grab_detail.gd", "test_bite_detail.gd", "test_horde_detail.gd"]:
		var path: String = "res://tests/game/" + file
		if not FileAccess.file_exists(path): continue
		var source := FileAccess.get_file_as_string(path).replace('extends "res://addons/gut/test.gd"', "extends Node")
		source += """
var check_failures: Array = []
var check_owned: Array = []
func add_child_autofree(node):
	add_child(node)
	check_owned.append(node)
func assert_eq(a, b, message = ""):
	if a != b: check_failures.append("eq: " + str(message) + " actual=" + str(a) + " expected=" + str(b))
func assert_ne(a, b, message = ""):
	if a == b: check_failures.append("ne: " + str(message))
func assert_true(a, message = ""):
	if not a: check_failures.append("true: " + str(message))
func assert_false(a, message = ""):
	if a: check_failures.append("false: " + str(message))
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
		if script.reload() != OK: return 1
		var suite = script.new()
		root.add_child(suite)
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"): continue
			count += 1
			suite.check_failures.clear()
			if suite.has_method("before_each"): suite.before_each()
			suite.call(name)
			var errors: Array = suite.check_failures.duplicate()
			failed += 1 if not errors.is_empty() else 0
			_record({"kind": "check", "file": file, "test": name, "failures": errors})
			if suite.has_method("after_each"): suite.after_each()
			for node in suite.check_owned: node.free()
			suite.check_owned.clear()
		suite.free()
	_record({"kind": "checks", "gut": "not_run", "adapter": "headless assertions, not GUT", "count": count, "failed": failed})
	return 1 if failed > 0 or count == 0 else 0


func _record(row: Dictionary) -> void:
	var line := JSON.stringify(row)
	print(line)
	if stdout_only: return
	var file := FileAccess.open(REPORT, FileAccess.READ_WRITE if FileAccess.file_exists(REPORT) else FileAccess.WRITE)
	if file == null:
		push_error("Cannot append the allowed report file.")
		quit(1)
		return
	file.seek_end()
	file.store_line("<!-- dead-detail " + line + " -->")
