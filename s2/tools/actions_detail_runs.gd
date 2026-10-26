extends SceneTree
## Equal inputs and a fixed simulation horizon; observers do not draw random numbers.
## --phase before|after|smoke --seeds 1:20 --seconds 300 --hz 30 --mode both

const FieldGrid = preload("res://game/world/field_grid.gd")
const REPORT := "res://../_measure_pz_actions.md"
const WALK_CELLS := [Vector2i(80, 12), Vector2i(90, 32), Vector2i(60, 40),
	Vector2i(30, 32), Vector2i(30, 12), Vector2i(50, 6)]
const METRICS := ["searched", "found", "interrupted", "doors_open", "doors_broken",
	"windows_broken", "windows_crossed", "sounds", "reactions", "fallen", "bites", "deaths", "tick_ms"]
const LABELS := ["뒤진 수납", "찾은 물건", "뒤지기 중단", "문 열림", "문 파괴", "창 파괴",
	"창 통과", "소음 사건", "청각 반응", "쓰러뜨린 망자", "사람 물림", "분대 사망", "틱 ms"]

var phase := "smoke"
var hz := 30
var seconds := 300.0
var first_seed := 1
var last_seed := 20
var modes: Array[String] = ["walk", "holdout"]
var resources: Array[Resource] = []
var game_script: GDScript
var sound_script: GDScript
var action_script: GDScript
var rows: Array = []
var checks_only := false
var check_count := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _arguments() or not _baseline_ok():
		quit(1)
		return
	if not _prepare():
		quit(1)
		return
	if checks_only:
		quit(_checks())
		return
	if phase == "before" and not FileAccess.file_exists(REPORT):
		_append("# 필드 행동 전후 측정\n\n")
	if phase != "smoke":
		_append("\n## %s\n\n씨앗 %d~%d, 각 %.1f초, %dHz, raiders=false, auto_pause=false.\n\n" % [phase, first_seed, last_seed, seconds, hz])
		_append("|판|씨앗|수납|물건|중단|문 열림|문 파괴|창 파괴|창 통과|소음|반응|쓰러뜨림|물림|분대 사망|틱 ms|첫 종료 초|\n|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n")
	print("CONFIG ", JSON.stringify({"phase": phase, "seeds": [first_seed, last_seed], "seconds": seconds,
		"hz": hz, "engine": Engine.get_version_info()["string"]}))
	for mode in modes:
		for run_seed in range(first_seed, last_seed + 1):
			var row := _trial(run_seed, mode)
			rows.append(row)
			print("RUN ", JSON.stringify(row))
			if phase != "smoke":
				var cells: Array[String] = [mode, str(run_seed)]
				for key in METRICS:
					cells.append("%.6f" % float(row[key]) if key == "tick_ms" else str(row[key]))
				cells.append("%.3f" % float(row["first_end"]))
				_append("|" + "|".join(cells) + "|\n")
			_save_cache()
			await process_frame
	if phase != "smoke":
		_summary()
	print("DONE ", phase, " trials=", rows.size())
	quit(0)


func _arguments() -> bool:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i] == "--checks-only":
			checks_only = true
			i += 1
			continue
		if i + 1 >= args.size():
			return false
		var value := args[i + 1]
		match args[i]:
			"--phase": phase = value
			"--seconds": seconds = float(value)
			"--hz": hz = int(value)
			"--seeds":
				var parts := value.split(":")
				first_seed = int(parts[0])
				last_seed = int(parts[1]) if parts.size() > 1 else first_seed
			"--mode":
				if value != "both":
					modes = [value]
			_: return false
		i += 2
	return phase in ["before", "after", "smoke"] and hz > 0 and seconds > 0 and first_seed > 0 and last_seed >= first_seed and modes.all(func(m): return m in ["walk", "holdout"])


func _baseline_ok() -> bool:
	if phase != "before":
		return true
	var snapshot = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/actions_detail_initial.json"))
	if not snapshot is Dictionary or not snapshot.get("mismatch", [1]).is_empty():
		push_error("A verified initial snapshot is required for before.")
		return false
	for file: String in snapshot["inventory"]:
		if not file.begins_with("s2/"):
			continue
		if FileAccess.get_sha256("res://" + file.trim_prefix("s2/")) != snapshot["inventory"][file]:
			push_error("Before source changed: " + file)
			return false
	return true


func _prepare() -> bool:
	# Keep resource imports in memory; neither user saves nor asset sidecars are written.
	_cache_raw("res://game/ui/tex")
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
	resources.append(train_script)
	game_script = GDScript.new()
	game_script.source_code = ('extends "res://game/field_game.gd"\n'
		+ 'var observed_tag: String = "other"\n'
		+ 'func _save(_result: Dictionary) -> void:\n\tpass\n'
		+ 'func make_sound(at: Vector3, level: int, tag: String, from: Person = null) -> void:\n'
		+ '\tvar previous := observed_tag\n\tobserved_tag = tag\n\tsuper.make_sound(at, level, tag, from)\n\tobserved_tag = previous\n'
		+ 'func _footsteps(p: Person, delta: float, cell: Vector2i) -> void:\n'
		+ '\tvar previous := observed_tag\n\tobserved_tag = "run" if p.is_running_now() else ("crouch" if p.crouched else "walk")\n'
		+ '\tsuper._footsteps(p, delta, cell)\n\tobserved_tag = previous\n')
	if game_script.reload() != OK:
		return false
	sound_script = GDScript.new()
	sound_script.source_code = ('extends "res://game/actors/zombies.gd"\n'
		+ 'var observed_events: int = 0\nvar observed_reactions: int = 0\nvar observed_tags: Dictionary = {}\n'
		+ 'func hear(at: Vector3, level: int, radius: float, wind = null) -> int:\n'
		+ '\tvar n := super.hear(at, level, radius, wind)\n\tobserved_events += 1\n\tobserved_reactions += n\n'
		+ '\tvar tag: String = game.observed_tag\n\tvar row: Dictionary = observed_tags.get(tag, {"events": 0, "reactions": 0})\n'
		+ '\trow["events"] += 1\n\trow["reactions"] += n\n\tobserved_tags[tag] = row\n\treturn n\n')
	if sound_script.reload() != OK:
		return false
	action_script = GDScript.new()
	action_script.source_code = ('extends "res://game/field_actions.gd"\n'
		+ 'var observed_crossings: int = 0\n'
		+ 'func _init(field_game = null) -> void:\n\tsuper(field_game)\n'
		+ 'func vault_window(p, c: Vector2i) -> void:\n'
		+ '\tvar allowed: bool = p.can_act() and game.grid.windows.has(c) and game.grid.windows[c]["broken"]\n'
		+ '\tsuper.vault_window(p, c)\n\tif allowed:\n\t\tobserved_crossings += 1\n')
	return action_script.reload() == OK


func _cache_raw(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for sub in DirAccess.get_directories_at(folder):
		_cache_raw(folder.path_join(sub))
	for name in DirAccess.get_files_at(folder):
		var path := folder.path_join(name)
		var resource: Resource
		match name.get_extension():
			"png":
				var png := Image.new()
				png.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
				resource = ImageTexture.create_from_image(png)
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
					push_error("Raw model could not be loaded: " + path)
					continue
				var node := document.generate_scene(state)
				var scene := PackedScene.new()
				scene.pack(node)
				node.free()
				resource = scene
		if resource != null:
			resource.take_over_path(path)
			resources.append(resource)


func _observe(object, script: GDScript) -> void:
	var saved: Dictionary = {}
	for property in object.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			saved[property["name"]] = object.get(property["name"])
	object.set_script(script)
	for key in saved:
		object.set(key, saved[key])


func _game(run_seed: int, mode: String):
	var game = game_script.new()
	game.opts = {"seed": run_seed, "raiders": false, "auto_pause": false}
	if mode == "holdout":
		game.opts["holdout"] = "start"
	root.add_child(game)
	game.set_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_observe(game.zombies, sound_script)
	_observe(game.actions, action_script)
	return game


func _trial(run_seed: int, mode: String) -> Dictionary:
	var game = _game(run_seed, mode)
	var row := {"phase": phase, "mode": mode, "seed": run_seed, "first_end": -1.0}
	for key in METRICS:
		row[key] = 0
	var containers: Dictionary = {}
	for id in game.data["containers"]:
		containers[id] = game.data["containers"][id]["searched"]
	var doors: Dictionary = {}
	for c in game.grid.doors:
		doors[c] = game.grid.doors[c]["state"]
	var windows: Dictionary = {}
	for c in game.grid.windows:
		windows[c] = game.grid.windows[c]["broken"]
	var fallen: Dictionary = {}
	var excluded: Dictionary = {}
	var body_seen: Dictionary = {}
	var holdout_broken: Dictionary = {}
	for z in game.zombies.list:
		if z["state"] in ["dead", "downed", "rising"]:
			excluded[z["id"]] = true
	var cost_usec := 0
	var ticks := roundi(seconds * hz)
	var delta := 1.0 / hz
	for tick in range(ticks):
		if mode == "walk" and tick % (hz * 2) == 0 and game.player.can_act() and game.player.action == "":
			var goal: Vector2i = WALK_CELLS[mini(int(float(tick) / hz / 50.0), WALK_CELLS.size() - 1)]
			game.player.go_to(game.find_path(game.player.position, game.lift(goal, 0)), false)
		var searching: Array = []
		for p in game.people:
			if p.action == "search":
				searching.append([p, p.action_busy])
		var amounts: Dictionary = {}
		for id in containers:
			if not containers[id]:
				amounts[id] = game.data["containers"][id]["items"].size()
		var pockets: Dictionary = {}
		for z in game.zombies.list:
			if not bool(z.get("searched", false)):
				var n := 0
				for item in z.get("loot", []):
					n += int(item.get("n", 1))
				pockets[z["id"]] = n
		var started := Time.get_ticks_usec()
		game._step(delta)
		cost_usec += Time.get_ticks_usec() - started
		if game.ended and float(row["first_end"]) < 0.0:
			row["first_end"] = (tick + 1) * delta
		for pair in searching:
			if pair[0].action != "search" and not bool(pair[1].get("searched", false)):
				row["interrupted"] += 1
		for id in containers:
			var now: bool = game.data["containers"][id]["searched"]
			if now and not containers[id]:
				row["searched"] += 1
				row["found"] += int(amounts.get(id, 0))
			containers[id] = now
		for c in doors:
			var state: String = game.grid.doors[c]["state"]
			if state != doors[c]:
				if state == "open": row["doors_open"] += 1
				if state == "broken": row["doors_broken"] += 1
			doors[c] = state
		for i in game.holdout.doors.size():
			if int(game.holdout.doors[i]["hp"]) <= 0 and not holdout_broken.has(i):
				holdout_broken[i] = true
				row["doors_broken"] += 1
		for c in windows:
			var broken: bool = game.grid.windows[c]["broken"]
			if broken and not windows[c]: row["windows_broken"] += 1
			windows[c] = broken
		for z in game.zombies.list:
			if z["state"] in ["downed", "dead"] and not excluded.has(z["id"]):
				fallen[z["id"]] = true
			if bool(z.get("searched", false)) and not body_seen.has(z["id"]):
				body_seen[z["id"]] = true
				row["found"] += int(pockets.get(z["id"], 0))
	row["windows_crossed"] = game.actions.observed_crossings
	row["sounds"] = game.zombies.observed_events
	row["reactions"] = game.zombies.observed_reactions
	row["by_sound"] = game.zombies.observed_tags.duplicate(true)
	row["fallen"] = fallen.size()
	for injury in game.telemetry.injuries:
		if injury["kind"] == "bite": row["bites"] += 1
	for p in game.squad:
		if p.body.dead: row["deaths"] += 1
	row["tick_ms"] = float(cost_usec) / 1000.0 / ticks
	game.free()
	return row


func _save_cache() -> void:
	var file := FileAccess.open("res://.godot/actions_detail_" + phase + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"phase": phase, "seconds": seconds, "hz": hz, "rows": rows}, "\t"))


func _append(text: String) -> void:
	var file := FileAccess.open(REPORT, FileAccess.READ_WRITE if FileAccess.file_exists(REPORT) else FileAccess.WRITE)
	file.seek_end()
	file.store_string(text)


func _summary() -> void:
	for mode in modes:
		_append("\n### %s %s 합과 가운데값\n\n|지표|합|가운데값|\n|---|---:|---:|\n" % [phase, mode])
		for i in METRICS.size():
			var values: Array = []
			var total := 0.0
			for row in rows:
				if row["mode"] == mode:
					values.append(float(row[METRICS[i]]))
					total += float(row[METRICS[i]])
			values.sort()
			var middle := values.size() / 2
			var median: float = (values[int((values.size() - 1) / 2)] + values[int(middle)]) / 2.0
			_append("|%s|%.6f|%.6f|\n" % [LABELS[i], total, median])


func _checks() -> int:
	var search_rules = load("res://game/sim/search_rules.gd")
	var door_rules = load("res://game/sim/door_rules.gd")
	var window_rules = load("res://game/sim/window_rules.gd")
	var noise = load("res://game/sim/noise.gd")
	_check(is_equal_approx(search_rules.seconds(7.0, 3), 7.0 / 1.45), "search skill seconds")
	_check(not search_rules.can_search({"busy": true}), "busy reservation")
	_check(not door_rules.can_toggle({"state": "broken"}, "open", true), "broken door stays broken")
	_check(not window_rules.can_cross({"broken": true}, 3), "immobile load")
	_check(is_equal_approx(noise.footstep_radius(false, 1.0, 1.0, true, 10, false, true), 0.45), "indoor crouch and stealth")
	_check(is_equal_approx(noise.footstep_radius(false, 1.0, 1.0, false, 0, true, true), 6.0), "indoor glass steps")
	var ledger = load("res://game/sim/noise_ledger.gd").new()
	ledger.add(noise.Level.NORMAL, 1.0, "run")
	for i in range(100):
		ledger.observe(noise.Level.NORMAL, "run", 12.0, 2)
	_check(ledger.total == 1 and ledger.history.size() == 1, "observations do not add pressure or step history")
	_check(ledger.sound_events == 100 and ledger.sound_reactions == 200, "sound counters")
	var game = _game(1, "walk")
	game.zombies.list.clear()
	var p = game.player
	var id: String = game.data["containers"].keys()[0]
	var c: Dictionary = game.data["containers"][id]
	c["locked"] = false
	c["searched"] = false
	c["busy"] = false
	c["search"] = 6.0
	c["items"] = ["cloth", "ammo_pistol"]
	p.position = game.lift(c["cell"], int(c.get("level", 0)))
	p.stop()
	p.stick = Vector2.ZERO
	p.drive_speed = 0.0
	var at: Vector3 = p.position
	var before_sound: int = game.zombies.observed_events
	game.actions.search(p, id)
	var total: float = p.action_total
	_check(p.action == "search" and c["busy"], "search reserves container")
	_check(game.zombies.observed_events == before_sound + 1, "search heard immediately")
	var unchanged: Array = c["items"].duplicate()
	game.actions.take_all(p, id)
	_check(c["items"] == unchanged and not c["searched"], "unrevealed loot cannot be taken")
	var q = game.squad[1]
	q.position = at
	game.actions.search(q, id)
	_check(q.action != "search", "second actor cannot steal reservation")
	game._update_person(p, 0.1)
	_check(p.action_t < total and c["items"] == unchanged, "time advances without early loot")
	p.stick = Vector2.RIGHT
	game._update_person(p, 0.1)
	_check(p.action == "" and not c["busy"] and not c["searched"], "stick cancels and frees reservation")
	p.stick = Vector2.ZERO
	p.drive_speed = 0.0
	p.position = at
	game.actions.search(p, id)
	_check(is_equal_approx(p.action_total, total), "interrupted search restarts in full")
	var stale: Callable = p.action_done
	p.cancel_action()
	stale.call()
	_check(not c["searched"], "cancelled callback cannot grant loot")
	game.actions.search(p, id)
	p.body.apply_cut(false, game.clock.elapsed, "arm_left")
	game._update_person(p, 0.1)
	_check(p.action == "" and not c["busy"], "fresh wound interrupts")
	p.body.wounds.clear()
	p.body.injured_at = -INF
	p.position = at
	game.actions.search(p, id)
	p.grabbers.append({"id": -1})
	p.grab_left = 10.0
	game._update_person(p, 0.1)
	_check(p.action == "" and not c["busy"], "grab interrupts before early return")
	p.grabbers.clear()
	game.actions.search(p, id)
	p.position = at + Vector3(3.0, 0, 0)
	game.actions.validate_work(p)
	_check(p.action == "" and not c["busy"], "walking away invalidates target")
	p.position = at
	game.actions.search(p, id)
	game.data["containers"].erase(id)
	game.actions.validate_work(p)
	_check(p.action == "" and not c["busy"], "removed target releases old reservation")
	game.data["containers"][id] = c
	game.actions.search(p, id)
	_finish_action(game, p)
	_check(c["searched"] and not c["busy"] and c["items"] == unchanged, "completion reveals exactly once")
	var dice: int = game.rng.state
	game.actions.search(p, id)
	_check(p.action == "" and game.rng.state == dice and c["items"] == unchanged, "revisit does not reroll")
	game.actions.take_all(p, id)
	# Each thing comes out by its weight's time (card R1), one after another.
	for i in range(c["items"].size() + 1):
		if p.action == "take":
			_finish_action(game, p)
	_check(c["items"].is_empty(), "all valid revealed items are taken")
	c["items"] = ["cloth"]
	p.position = at + Vector3(3.0, 0, 0)
	game.actions.take_all(p, id)
	_check(c["items"] == ["cloth"], "remote take-all terminates without loss")
	p.position = at
	c["searched"] = false
	c["items"] = ["ammo_pistol"]
	q.position = at
	var ammo_before: int = game.ammo["pistol"]
	game.actions.search(q, id)
	var second_id: String = game.data["containers"].keys()[1]
	var second: Dictionary = game.data["containers"][second_id]
	second["locked"] = false
	second["searched"] = false
	var helper = game.squad[2]
	helper.position = game.lift(second["cell"], int(second.get("level", 0)))
	game.actions.search(helper, second_id)
	_check(helper.action != "search" and q.action == "search", "only one companion searches")
	_finish_action(game, q)
	_check(game.ammo["pistol"] == ammo_before + 6 and not q.items.has("ammo_pistol"), "companion ammo uses squad pool")
	_check(c["items"].is_empty(), "companion removes received contents")
	c["searched"] = false
	game.actions._searched(p, id)
	_check(c["searched"], "existing direct completion notification remains usable")
	# Door completion races and occupied thresholds use the real game callbacks.
	var door_cell: Vector2i = game.grid.doors.keys()[0]
	p.position = FieldGrid.center(door_cell) + Vector3(1.0, 0, 0)
	q.position = at + Vector3(10.0, 0, 0)
	helper.position = q.position
	game.grid.set_door_state(door_cell, "closed")
	game.actions.door_default(p, door_cell, "")
	_check(p.action == "door", "door begins timed work")
	stale = p.action_done
	game.grid.set_door_state(door_cell, "broken")
	_finish_action(game, p)
	stale.call()
	_check(game.grid.doors[door_cell]["state"] == "broken", "destroyed door cannot be reopened by old callback")
	game.grid.set_door_state(door_cell, "open")
	q.position = FieldGrid.center(door_cell)
	game.actions.door_default(p, door_cell, "close")
	_finish_action(game, p)
	_check(game.grid.doors[door_cell]["state"] == "open", "person blocks closing")
	q.position += Vector3(3.0, 0, 0)
	game.actions.door_default(p, door_cell, "close")
	_finish_action(game, p)
	_check(game.grid.doors[door_cell]["state"] == "closed", "unoccupied door closes")
	game.grid.set_door_state(door_cell, "locked")
	p.hands = [{"id": "crowbar", "quality": "factory", "condition": 1.0, "loaded": 0}]
	game.actions.pry_door(p, door_cell)
	_check(p.action == "pry", "held tool starts prying")
	p.hands.clear()
	game.actions.validate_work(p)
	_check(p.action == "" and game.grid.doors[door_cell]["state"] == "locked", "lost tool cancels prying")
	game.grid.set_door_state(door_cell, "closed")
	p.path = PackedVector3Array([p.position + Vector3(3.0, 0, 0)])
	game.actions.open_door_on_way(p, door_cell)
	stale = p.action_done
	p.cancel_action()
	p.path = PackedVector3Array([p.position + Vector3(-3.0, 0, 0)])
	var chosen: PackedVector3Array = p.path.duplicate()
	game.grid.set_door_state(door_cell, "open")
	stale.call()
	_check(p.path == chosen, "cancelled door callback cannot restore an old route")
	p.stop()
	# Window checks leave injury values alone and exercise both movement entry paths.
	var window_cell: Vector2i = game.grid.windows.keys()[0]
	var window: Dictionary = game.grid.windows[window_cell]
	p.position = FieldGrid.center(window_cell)
	window["broken"] = false
	window["glass"] = true
	game.actions.window_default(p, window_cell, "break")
	_finish_action(game, p)
	_check(window["broken"] and window["glass"], "break window on completion")
	before_sound = game.zombies.observed_events
	game.actions._break_window(p, window_cell)
	_check(game.zombies.observed_events == before_sound, "duplicate smash makes no sound")
	game.actions.window_default(p, window_cell, "")
	_finish_action(game, p)
	_check(not window["glass"], "clear remaining glass on completion")
	window["broken"] = false
	p.position = FieldGrid.center(window_cell) - Vector3(1.0, 0, 0)
	p.facing = PI / 2.0
	p.hands = [{"id": "crowbar", "quality": "factory", "condition": 1.0, "loaded": 0}]
	game.combat._swing_empty(p)
	_check(window["broken"], "existing combat impact can break a window without a timed-work ticket")
	game.actions._clear_glass(window_cell)
	_check(game.actions.can_vault_window(p, window_cell), "clean broken frame is traversable")
	var origin := FieldGrid.center(window_cell) + Vector3(-1.0, 0, 0)
	# Open the adjacent test cell in memory only, then restore it before freeing the scene.
	var origin_cell := FieldGrid.cell_of(origin)
	var previous_solid: int = game.grid.solid[game.grid.index(origin_cell)]
	game.grid.solid[game.grid.index(origin_cell)] = FieldGrid.Solid.NONE
	for i in range(2):
		p.position = origin
		p.path = PackedVector3Array([FieldGrid.center(window_cell)])
		for j in range(30):
			game._move_person(p, 0.1)
	_check(game.actions.observed_crossings == 2, "reentry crosses once each, not each tick or once per lifetime")
	game.grid.solid[game.grid.index(origin_cell)] = previous_solid
	# Ground targeting remains stable when another item disappears during the approach.
	p.cancel_action()
	p.stop()
	p.position = Vector3(60.5, 0, 4.5)
	game.ground_items.clear()
	var target := {"pos": p.position + Vector3(4.0, 0, 0), "id": "cloth", "n": 1}
	game.ground_items.append({"pos": p.position, "id": "ammo_craft", "n": 1})
	game.ground_items.append(target)
	game.ground_items.append({"pos": target["pos"], "id": "food_pack", "n": 1})
	var cloth_before: int = p.items.get("cloth", 0)
	var food_before: int = p.items.get("food_pack", 0)
	game.actions.go_and_do(p, "item", 1, target["pos"])
	game.ground_items.remove_at(0)
	p.position = target["pos"]
	p.stop()
	game.actions._player_goal()
	_check(int(p.items.get("food_pack", 0)) == food_before and game.ground_items.size() == 2, "stale ground index cannot pick another item")
	game.actions.pick_up(p, 0)
	_check(int(p.items.get("cloth", 0)) == cloth_before + 1, "shifted target remains available for a new pickup")
	game.ground_items.clear()
	game.ground_items.append({"pos": p.position + Vector3(5.0, 0, 0), "id": "cloth", "n": 1})
	game.actions.pick_up(p, 0)
	_check(game.ground_items.size() == 1, "remote ground pickup refused")
	game.ground_items[0]["pos"] = p.position + Vector3(0, 3.0, 0)
	game.actions.pick_up(p, 0)
	_check(game.ground_items.size() == 1, "other-floor pickup refused")
	game.ground_items[0]["pos"] = p.position + Vector3(2.0, 0, 0)
	var barrier := FieldGrid.cell_of(p.position + Vector3(1.0, 0, 0))
	previous_solid = game.grid.solid[game.grid.index(barrier)]
	game.grid.solid[game.grid.index(barrier)] = FieldGrid.Solid.WALL
	game.actions.pick_up(p, 0)
	_check(game.ground_items.size() == 1, "pickup through wall refused")
	game.grid.solid[game.grid.index(barrier)] = previous_solid
	var weapon := {"id": "pistol", "quality": "factory", "condition": 0.2, "loaded": 3}
	game.ground_items = [{"pos": p.position, "id": "pistol", "n": 1, "weapon": weapon}]
	p.hands = [weapon.duplicate(), weapon.duplicate()]
	game.actions.pick_up(p, 0)
	_check(game.ground_items.size() == 1 and game.ground_items[0]["weapon"] == weapon, "full hands preserve ground weapon state")
	p.hands.clear()
	game.actions.pick_up(p, 0)
	_check(game.ground_items.is_empty() and p.hands[0]["condition"] == 0.2 and p.hands[0]["loaded"] == 3, "weapon state survives pickup")
	p.brain["step_t"] = 0.0
	p.running = false
	before_sound = game.zombies.observed_events
	for i in range(100):
		game._footsteps(p, 0.1, FieldGrid.cell_of(p.position))
	_check(game.zombies.observed_events - before_sound == 20, "step cadence keeps the fractional remainder")
	game.free()
	var result := {"checks": check_count, "failures": failures}
	var file := FileAccess.open("res://.godot/actions_detail_checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("CHECKS ", JSON.stringify(result))
	return 0 if failures.is_empty() else 1


func _finish_action(game, p) -> void:
	p.action_t = 0.001
	game._update_person(p, 0.1)


func _check(condition: bool, label: String) -> void:
	check_count += 1
	if not condition:
		failures.append(label)
		print("CHECK FAILED ", label)
