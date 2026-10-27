extends SceneTree
## Same seeds, same input, before and after a rule change (decision 420: one
## body does one thing at a time). The field_game runs headless at a fixed
## step; the player walks a fixed round (walk) or the holdout runs (holdout),
## the companions play by their own AI. Prints one JSON line per trial.
## --seeds 1:20 --seconds 300 --hz 30 --mode both|walk|holdout --label before|after
## --bot counter|none: the player fights back what is on it (counter, _counter:
## where it stands in the holdout, stopping on its round in the walk) or lets
## it be as the runs before it did (none).
## No imports, no saves, no files written.

const WALK_CELLS := [Vector2i(80, 12), Vector2i(90, 32), Vector2i(60, 40),
	Vector2i(30, 32), Vector2i(30, 12), Vector2i(50, 6)]
## How often the player looks round, as a thumb on the pad would.
const REACT_S := 0.25
const Weapons = preload("res://game/sim/weapons.gd")

var keep: Array = []
var game_script: GDScript
var hz := 30
var seconds := 300.0
var seed_first := 1
var seed_last := 20
var modes: Array[String] = ["walk", "holdout"]
var label := "after"
var bot := "counter"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _arguments():
		quit(1)
		return
	# Raw files go into the resource cache in memory only: nothing is imported.
	for name in DirAccess.get_files_at("res://game/ui/tex"):
		if name.ends_with(".png"):
			var path := "res://game/ui/tex/" + name
			var png := Image.new()
			png.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
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
		quit(1)
		return
	keep.append(train_script)
	game_script = GDScript.new()
	game_script.source_code = 'extends "res://game/field_game.gd"\nfunc _save(_result: Dictionary) -> void:\n\tpass\n'
	if game_script.reload() != OK:
		quit(1)
		return
	print(JSON.stringify({"kind": "config", "label": label, "seeds": [seed_first, seed_last], "seconds": seconds,
		"hz": hz, "modes": modes, "bot": bot, "engine": Engine.get_version_info()["string"],
		"field_actions_sha256": FileAccess.get_sha256("res://game/field_actions.gd"),
		"field_combat_sha256": FileAccess.get_sha256("res://game/field_combat.gd")}))
	for mode in modes:
		for run_seed in range(seed_first, seed_last + 1):
			print(JSON.stringify(_trial(run_seed, mode)))
			await process_frame
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
			"--hz": hz = value.to_int()
			"--seconds": seconds = value.to_float()
			"--label": label = value
			"--bot": bot = value
			"--mode":
				if value != "both":
					modes.assign([value])
			"--seeds":
				var bounds := value.split(":")
				seed_first = bounds[0].to_int()
				seed_last = bounds[-1].to_int()
			_:
				push_error("Unknown argument: " + args[i])
				return false
		i += 2
	return hz > 0 and seconds > 0 and seed_last >= seed_first and bot in ["counter", "none"] \
		and modes.all(func(m): return m in ["walk", "holdout"])


static func _striking(p) -> bool:
	return p.swing_t > 0.0 or p.strike_t > 0.0 or p.shove_t > 0.0


## The player at the pad, fighting back what is on it (the plain melee loop):
## grabbed, it shoves free; one dead on its feet in reach, it shoves it (one
## alone is put down, then finished on the ground, never swung at on its
## feet); two or more, it swings at the nearest; none standing, it ends a
## rising one or one lying in reach. It never walks after one: a target that
## drifts out of reach is let go. No dice of its own (game.rng only), so seeds
## still repeat. True while there is a fight at hand: the walk waits for it.
func _counter(game, counts: Dictionary) -> bool:
	var p = game.player
	var combat = game.combat
	if game.ended or not p.is_alive():
		return false
	if not p.grabbers.is_empty():
		if combat.break_grab(p):
			counts["bot_frees"] += 1
		return true
	if not p.can_act() or combat.striking(p):
		return true
	var reach: float = float(Weapons.get_data(p.weapon_id()).get("reach", 0.9)) + combat.MELEE_SLACK
	if not p.target_zombie.is_empty():
		if p.target_zombie["state"] != "dead" and p.position.distance_to(p.target_zombie["pos"]) <= reach:
			return true
		combat.stop_fight(p)
	var up: Array = []
	var rising: Dictionary = {}
	var lying: Dictionary = {}
	for z in game.zombies.in_radius(p.position, maxf(reach, combat.SHOVE_REACH)):
		if combat.melee_blocked(p, z["pos"]):
			continue
		var d: float = p.position.distance_to(z["pos"])
		match String(z["state"]):
			"dead", "frozen":
				pass
			"rising":
				if d <= reach and (rising.is_empty() or d < p.position.distance_to(rising["pos"])):
					rising = z
			"downed":
				if d <= reach and (lying.is_empty() or d < p.position.distance_to(lying["pos"])):
					lying = z
			_:
				up.append(z)
	up.sort_custom(func(a, b): return p.position.distance_to(a["pos"]) < p.position.distance_to(b["pos"]))
	if up.size() == 1 and p.position.distance_to(up[0]["pos"]) <= combat.SHOVE_REACH:
		p.face_point(up[0]["pos"])
		combat.start_shove(p)
		counts["bot_shoves"] += 1
	elif up.size() > 1 and p.position.distance_to(up[0]["pos"]) <= reach:
		combat.fight(p, up[0], false)
		counts["bot_swings"] += 1
	elif up.is_empty() and not rising.is_empty():
		combat.fight(p, rising, false)
		counts["bot_swings"] += 1
	elif up.is_empty() and not lying.is_empty():
		combat.fight(p, lying, false)
		counts["bot_finishes"] += 1
	else:
		return false
	return true


func _trial(run_seed: int, mode: String) -> Dictionary:
	var game = game_script.new()
	game.opts = {"seed": run_seed, "raiders": false, "auto_pause": false}
	if mode == "holdout":
		game.opts["holdout"] = "start"
	root.add_child(game)
	game.set_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var delta := 1.0 / hz
	var ticks := roundi(seconds * hz)
	var was: Dictionary = {}          # person -> [action, striking]
	var started := 0                  # timed actions begun
	var started_striking := 0         # begun while a blow or a shove was on
	var struck_acting := 0            # a blow or a shove begun while an action was on
	var both_ticks := 0               # ticks with a body doing both at once
	var searches := 0                 # boxes the squad began to search
	var empty_searches := 0           # of those, ones that held nothing (card P3: shown before)
	var search_s := 0.0               # seconds the squad spent searching
	var initially_fallen: Dictionary = {}
	var fallen: Dictionary = {}
	var first_end := -1.0
	for z in game.zombies.list:
		if z["state"] in ["dead", "downed", "rising"]:
			initially_fallen[z["id"]] = true
	var counts := {"bot_shoves": 0, "bot_swings": 0, "bot_finishes": 0, "bot_frees": 0}
	var react := maxi(1, roundi(REACT_S * hz))
	var clock := Time.get_ticks_usec()
	var beset := false                # a fight at hand: the walk waits for it
	for tick in range(ticks):
		if bot == "counter" and tick % react == 0:
			beset = _counter(game, counts)
		if mode == "walk" and tick % (hz * 2) == 0 and game.player.can_act() and game.player.action == "" and not beset:
			var goal: Vector2i = WALK_CELLS[mini(int(float(tick) / hz / 50.0), WALK_CELLS.size() - 1)]
			game.player.go_to(game.find_path(game.player.position, game.lift(goal, 0)), false)
		game._step(delta)
		if game.ended and first_end < 0.0:
			first_end = (tick + 1) * delta
		for p in game.squad:
			var now_action: String = p.action
			var now_striking := _striking(p)
			var before: Array = was.get(p, ["", false])
			if before[0] == "" and now_action != "" and now_action != "aim":
				started += 1
				# In a blow on both sides of the start: begun mid-blow, not as it ended.
				if before[1] and now_striking:
					started_striking += 1
			if not before[1] and now_striking and before[0] != "" and before[0] != "aim":
				struck_acting += 1
			if now_striking and now_action != "" and now_action != "aim":
				both_ticks += 1
			if now_action == "search":
				search_s += delta
				if before[0] != "search":
					searches += 1
					if (p.action_busy.get("items", []) as Array).is_empty():
						empty_searches += 1
			was[p] = [now_action, now_striking]
		for z in game.zombies.list:
			if z["state"] in ["downed", "dead"] and not initially_fallen.has(z["id"]):
				fallen[z["id"]] = true
	var bites := 0
	var bites_player := 0             # of the bites, the player's (the heavier number)
	var grabs_player := 0
	for injury in game.telemetry.injuries:
		var players: bool = injury["who"] == game.player.pid
		if injury["kind"] == "bite":
			bites += 1
			if players:
				bites_player += 1
		elif injury["kind"] == "grab" and players:
			grabs_player += 1
	var deaths := 0
	for p in game.squad:
		if p.body.dead:
			deaths += 1
	# Footsteps heard (field_game.gd _footsteps notes each on the ledger by gait).
	var steps := 0
	var step_reactions := 0
	for gait in ["walk", "run", "crouch"]:
		var noted: Dictionary = game.ledger.by_action.get(gait, {})
		steps += int(noted.get("events", 0))
		step_reactions += int(noted.get("reactions", 0))
	var row := {"kind": "trial", "label": label, "mode": mode, "seed": run_seed, "ticks": ticks,
		"actions_started": started, "started_while_striking": started_striking,
		"struck_while_acting": struck_acting, "both_ticks": both_ticks,
		"searches": searches, "empty_searches": empty_searches, "search_s": snappedf(search_s, 0.1),
		"fallen": fallen.size(), "kills": int(game.combat.kills), "bites": bites, "deaths": deaths,
		"steps": steps, "step_reactions": step_reactions,
		"first_end_s": first_end, "wall_s": float(Time.get_ticks_usec() - clock) / 1000000.0}
	row.merge(counts)
	# Dead contacts by side (decision 474 J1), where the rules count them.
	if game.combat.get("contacts") != null:
		row["contacts"] = game.combat.contacts.duplicate(true)
		row["crowd_most"] = int(game.combat.crowd_most)
		row["crowd_falls"] = int(game.combat.get("crowd_falls") if game.combat.get("crowd_falls") != null else 0)
	row["bites_player"] = bites_player
	row["grabs_player"] = grabs_player
	game.free()
	return row
