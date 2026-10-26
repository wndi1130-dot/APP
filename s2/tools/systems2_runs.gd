extends SceneTree
## Smell and weapon detail before/after runs: fixed seeds and inputs, and the
## observations never draw from the simulation's random numbers.
## --phase before|after --seeds 1:20 --seconds 300 --hz 30 --mode both
## [--weather rain --air 4]: the stop's weather kinds (comma list) and outside air.
## One JSON line per trial on stdout: the dead drawn by smell (the blood event
## and the trail), kills, swings and wear by weapon, squad deaths, exhaustion.

const WALK_CELLS := [Vector2i(80, 12), Vector2i(90, 32), Vector2i(60, 40),
	Vector2i(30, 32), Vector2i(30, 12), Vector2i(50, 6)]

var keep: Array[Resource] = []
var game_script: GDScript
var measured_zombies: GDScript
var measured_combat: GDScript
var phase := "before"
var hz := 30
var seconds := 300.0
var seed_first := 1
var seed_last := 20
var modes: Array[String] = ["walk", "holdout"]
var weather_kinds: Array = []
var air: float = INF


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _arguments() or not _prepare():
		quit(1)
		return
	print(JSON.stringify({"kind": "config", "phase": phase, "seeds": [seed_first, seed_last],
		"seconds": seconds, "hz": hz, "modes": modes, "weather": weather_kinds, "air": air if air != INF else null, "engine": Engine.get_version_info()["string"]}))
	for mode in modes:
		for run_seed in range(seed_first, seed_last + 1):
			print(JSON.stringify(_trial(run_seed, mode)))
			await process_frame
	quit(0)


func _prepare() -> bool:
	# Raw resources cached in memory: no editor import, no saves.
	for name in DirAccess.get_files_at("res://game/ui/tex"):
		if name.ends_with(".png"):
			var path := "res://game/ui/tex/" + name
			var png := Image.new()
			if png.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
				return false
			var texture := ImageTexture.create_from_image(png)
			texture.take_over_path(path)
			keep.append(texture)
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
	keep.append(train_script)
	game_script = GDScript.new()
	game_script.source_code = """
extends "res://game/field_game.gd"
func _save(_result: Dictionary) -> void:
	pass
"""
	if game_script.reload() != OK:
		return false
	measured_zombies = GDScript.new()
	measured_zombies.source_code = """
extends "res://game/actors/zombies.gd"
var m_event: int = 0
var m_trail: int = 0
var m_ids: Dictionary = {}
func smell(at: Vector3, radius: float) -> int:
	var before: Dictionary = {}
	for z in list:
		before[z["id"]] = [z["state"], z["target"]]
	var n: int = super.smell(at, radius)
	m_event += n
	for z in list:
		if before.get(z["id"], []) != [z["state"], z["target"]]:
			m_ids[z["id"]] = true
	return n
func _sense(z: Dictionary, people: Array, delta: float) -> void:
	var was: Array = [z["state"], z["target"]]
	super._sense(z, people, delta)
	if z["state"] == "investigate" and String(z.get("clue_kind", "")) == "scent" and was != [z["state"], z["target"]]:
		m_trail += 1
		m_ids[z["id"]] = true
"""
	if measured_zombies.reload() != OK:
		return false
	measured_combat = GDScript.new()
	measured_combat.source_code = """
extends "res://game/field_combat.gd"
var m_kills: Dictionary = {}
var m_wear: Dictionary = {}
var m_uses: Dictionary = {}
var m_broken: Dictionary = {}
func _kill(p, z: Dictionary, msg: String) -> void:
	if p != null and p.team != "raider":
		var wid: String = p.weapon_id()
		m_kills[wid] = int(m_kills.get(wid, 0)) + 1
	super._kill(p, z, msg)
func _wear(p, amount: float) -> void:
	if p.team != "raider" and not p.hands.is_empty():
		var wid: String = String(p.hands[0]["id"])
		var had: int = p.hands.size()
		m_wear[wid] = float(m_wear.get(wid, 0.0)) + amount
		m_uses[wid] = int(m_uses.get(wid, 0)) + 1
		super._wear(p, amount)
		if p.hands.size() < had:
			m_broken[wid] = int(m_broken.get(wid, 0)) + 1
		return
	super._wear(p, amount)
"""
	if measured_combat.reload() != OK:
		return false
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
	var i := 0
	while i + 1 < args.size():
		var value := args[i + 1]
		match args[i]:
			"--phase": phase = value
			"--hz": hz = value.to_int()
			"--seconds": seconds = value.to_float()
			"--mode":
				if value != "both": modes.assign([value])
			"--weather": weather_kinds.assign(value.split(","))
			"--air": air = value.to_float()
			"--seeds":
				var bounds := value.split(":")
				seed_first = bounds[0].to_int()
				seed_last = bounds[-1].to_int()
			_: return false
		i += 2
	return i == args.size() and hz > 0 and seconds > 0 and seed_last >= seed_first


## Swap a node's script for the measured one and keep what it already holds.
static func _swap(obj: Object, script: GDScript) -> void:
	var saved: Dictionary = {}
	for prop in obj.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			saved[prop["name"]] = obj.get(prop["name"])
	obj.set_script(script)
	for key in saved:
		obj.set(key, saved[key])


func _game(run_seed: int, mode: String):
	var game = game_script.new()
	game.opts = {"seed": run_seed, "raiders": false, "auto_pause": false}
	if mode == "holdout": game.opts["holdout"] = "start"
	if not weather_kinds.is_empty(): game.opts["weather"] = weather_kinds
	if air != INF: game.opts["ambient_c"] = air
	root.add_child(game)
	game.set_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_swap(game.zombies, measured_zombies)
	# The fight rules take the game in _init, so a new one is made and given
	# what the old one held (everything reads it through game.combat).
	var c = measured_combat.new(game)
	for prop in game.combat.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and not String(prop["name"]).begins_with("m_"):
			c.set(prop["name"], game.combat.get(prop["name"]))
	game.combat = c
	return game


func _trial(run_seed: int, mode: String) -> Dictionary:
	var game = _game(run_seed, mode)
	var delta := 1.0 / hz
	var ticks := roundi(seconds * hz)
	var dead_people: Dictionary = {}
	var started := Time.get_ticks_usec()
	for tick in range(ticks):
		if mode == "walk" and tick % (hz * 2) == 0 and game.player.can_act() and game.player.action == "":
			var goal: Vector2i = WALK_CELLS[mini(int(float(tick) / hz / 50.0), WALK_CELLS.size() - 1)]
			game.player.go_to(game.find_path(game.player.position, game.lift(goal, 0)), false)
		game._step(delta)
		for p in game.squad:
			if p.body.dead and not dead_people.has(p.pid):
				dead_people[p.pid] = game.clock.elapsed
	var tired := 0.0
	for p in game.squad:
		tired += float(p.body.exhaustion)
	var c = game.combat
	var row := {"kind": "trial", "phase": phase, "mode": mode, "seed": run_seed,
		"smell_event": game.zombies.m_event, "smell_trail": game.zombies.m_trail,
		"smell_dead": game.zombies.m_ids.size(), "kills": c.m_kills, "uses": c.m_uses,
		"wear": c.m_wear, "broken": c.m_broken, "kills_all": int(c.kills),
		"deaths": dead_people.size(), "death_at": dead_people, "exhaustion_sum": tired,
		"wall_s": float(Time.get_ticks_usec() - started) / 1000000.0}
	game.free()
	return row
