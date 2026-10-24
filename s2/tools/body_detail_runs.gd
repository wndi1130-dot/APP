extends SceneTree
## Reproducible field trials and bounded rule checks. All output stays local.
## --phase before|after --seeds 1:20 --seconds 300 --hz 10 --mode both
## --check runs the same assertions without requiring a test addon.
## --report rebuilds the Markdown table from the saved trials without a simulation.

const REPORT := "res://../_measure_pz_body.md"
const CACHE := "res://.godot/body_detail"
const RUN_PREFIX := "paired_"
const WALK_CELLS := [Vector2i(80, 12), Vector2i(90, 32), Vector2i(60, 40),
	Vector2i(30, 32), Vector2i(30, 12), Vector2i(50, 6)]
const BODY_FILES := ["game/sim/body_state.gd", "game/sim/treatment.gd", "game/sim/body_heat.gd",
	"game/sim/motion.gd", "game/sim/carry.gd", "game/actors/person.gd"]
const SHARED_FILES := ["game/field_game.gd", "game/field_actions.gd", "game/field_combat.gd",
	"game/field_ai.gd", "game/actors/zombies.gd", "game/sim/weapons.gd", "game/sim/weather.gd",
	"game/sim/horde_director.gd", "game/sim/noise.gd"]
var phase := "before"
var hz := 10
var seconds := 300.0
var first_seed := 1
var last_seed := 20
var modes: Array[String] = ["walk", "holdout"]
var check_only := false
var report_only := false
var resources: Array[Resource] = []
var game_script: GDScript
var body_script: GDScript
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _arguments():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(CACHE)
	if report_only:
		_write_report()
		quit(0)
		return
	if check_only:
		_checks()
		quit(0 if failures == 0 else 1)
		return
	if not _prepare():
		quit(2)
		return
	var output := CACHE.path_join(RUN_PREFIX + phase + ".jsonl")
	if FileAccess.file_exists(output):
		push_error("Phase output already exists; choose a fresh phase or preserve the existing run first.")
		quit(2)
		return
	var config := {"kind": "config", "phase": phase, "engine": Engine.get_version_info()["string"],
		"seeds": [first_seed, last_seed], "seconds": seconds, "hz": hz, "modes": modes,
		"raiders": false, "auto_pause": false, "sources": {}, "shared": {}}
	for path in BODY_FILES:
		var backup := CACHE.path_join("before_sources").path_join(path)
		config["sources"][path] = FileAccess.get_sha256(backup if phase == "before" else "res://" + path)
		if phase == "before" and not FileAccess.file_exists(backup):
			DirAccess.make_dir_recursive_absolute(backup.get_base_dir())
			var f := FileAccess.open(backup, FileAccess.WRITE)
			f.store_buffer(FileAccess.get_file_as_bytes("res://" + path))
	for path in SHARED_FILES:
		config["shared"][path] = FileAccess.get_sha256("res://" + path)
	config["added_sources"] = {}
	if phase != "before":
		for path in ["game/sim/stamina.gd", "game/sim/injury_rules.gd"]:
			config["added_sources"][path] = FileAccess.get_sha256("res://" + path)
	_record(config)
	for mode in modes:
		for run_seed in range(first_seed, last_seed + 1):
			var row := _trial(run_seed, mode)
			_record(row)
			print(JSON.stringify(row))
			await process_frame
	_write_report()
	quit(0)


func _arguments() -> bool:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i] == "--report":
			report_only = true
			i += 1
			continue
		if args[i] == "--check":
			check_only = true
			i += 1
			continue
		if i + 1 >= args.size():
			return false
		var value := args[i + 1]
		match args[i]:
			"--phase": phase = value
			"--hz": hz = value.to_int()
			"--seconds": seconds = value.to_float()
			"--seeds":
				var span := value.split(":")
				first_seed = span[0].to_int()
				last_seed = span[-1].to_int()
			"--mode":
				if value != "both":
					modes.assign([value])
			_: return false
		i += 2
	return not phase.is_empty() and phase.is_valid_filename() and hz > 0 and seconds > 0 and first_seed > 0 and last_seed >= first_seed and modes.all(func(m): return m in ["walk", "holdout"])


func _prepare() -> bool:
	if phase == "before" and not check_only:
		# Reload the actual pre-edit snapshots, without replacing working files.
		for path in ["game/sim/carry.gd", "game/sim/motion.gd", "game/sim/body_heat.gd", "game/sim/body_state.gd", "game/actors/person.gd", "game/sim/treatment.gd"]:
			var backup := CACHE.path_join("before_sources").path_join(path)
			if not FileAccess.file_exists(backup):
				push_error("Missing pre-edit snapshot: " + path)
				return false
			var original := GDScript.new()
			original.source_code = FileAccess.get_file_as_string(backup)
			original.take_over_path("res://" + path)
			if original.reload() != OK:
				return false
			resources.append(original)
	# Raw resources are cached in memory; no editor import or sidecar writes.
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
		+ 'var bleed_deaths: Array = []\nvar completed_care := 0\nvar completed_care_seconds := 0.0\n'
		+ 'func _save(_result: Dictionary) -> void:\n\tpass\n'
		+ 'func _on_body_event(p, ev: String) -> void:\n'
		+ '\tif ev == "died":\n\t\tbleed_deaths.append(p.pid)\n'
		+ '\tsuper._on_body_event(p, ev)\n'
		+ 'func _update_person(p: Person, delta: float) -> void:\n'
		+ '\tvar care: bool = p.action in ["treat", "splint", "bandage"]\n'
		+ '\tvar previous: Callable = p.action_done\n'
		+ '\tvar before_count := 0\n\tif care:\n\t\tfor patient in squad:\n\t\t\tbefore_count += patient.body.care_count\n'
		+ '\tif care:\n\t\tp.brain["body_measure_care_s"] = float(p.brain.get("body_measure_care_s", 0.0)) + delta\n'
		+ '\tsuper._update_person(p, delta)\n'
		+ '\tif care:\n\t\tvar after_count := 0\n\t\tfor patient in squad:\n\t\t\tafter_count += patient.body.care_count\n'
		+ '\t\tif after_count > before_count:\n\t\t\tcompleted_care += 1\n\t\t\tcompleted_care_seconds += float(p.brain.get("body_measure_care_s", 0.0))\n'
		+ '\tif not care or p.action == "" or p.action_done != previous:\n\t\tp.brain["body_measure_care_s"] = 0.0\n'
		+ 'func _update_zone(delta: float) -> void:\n'
		+ '\tvar z := grid.zone_at(FieldGrid.cell_of(player.position))\n'
		+ '\tif z != zone_now:\n\t\tzone_now = z\n\t\ttelemetry.zone_enter(z, clock.elapsed)\n'
		+ '\ttelemetry.zone_tick(z, delta)\n'
		+ '\tvar looted := false\n\tfor id in player.items:\n\t\tif STOCK_OF.has(id):\n\t\t\tlooted = true\n'
		+ '\tif looted and player.moving:\n\t\ttelemetry.carry_time(delta)\n')
	if game_script.reload() != OK:
		return false
	body_script = GDScript.new()
	body_script.source_code = ('extends "res://game/sim/body_state.gd"\n'
		+ 'var measured_person = null\nvar care_count := 0\nvar care_seconds := 0.0\nvar care_nested := false\n'
		+ 'func _care_record() -> void:\n\tif care_nested:\n\t\treturn\n\tcare_count += 1\n'
		+ '\tcare_seconds += float(measured_person.brain.get("body_measure_care_s", 0.0)) if measured_person != null else 0.0\n')
	for name in ["bandage_wound", "splint_wound", "tourniquet_wound", "pull_wound", "suture_wound", "disinfect"]:
		var result_type := "int" if name == "bandage_wound" else "bool"
		body_script.source_code += ('func ' + name + '(index: int = -1) -> ' + result_type + ':\n'
			+ '\tvar result = super.' + name + '(index)\n\tif result:\n\t\t_care_record()\n\treturn result\n')
	body_script.source_code += ('func bandage(count: int = 1) -> bool:\n'
		+ '\tcare_nested = true\n\tvar result := super.bandage(count)\n\tcare_nested = false\n\tif result:\n\t\t_care_record()\n\treturn result\n'
		+ 'func use_kit() -> bool:\n\tvar result := super.use_kit()\n\tif result:\n\t\t_care_record()\n\treturn result\n')
	body_script.source_code += 'func splint() -> void:\n\tvar had := _top_fracture() >= 0\n\tsuper.splint()\n\tif had:\n\t\t_care_record()\n'
	return body_script.reload() == OK


func _cache_raw(folder: String) -> void:
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
					continue
				var node := document.generate_scene(state)
				var scene := PackedScene.new()
				scene.pack(node)
				node.free()
				resource = scene
		if resource != null:
			resource.take_over_path(path)
			resources.append(resource)


func _game(run_seed: int, mode: String):
	var game = game_script.new()
	game.opts = {"seed": run_seed, "raiders": false, "auto_pause": false}
	if mode == "holdout":
		game.opts["holdout"] = "start"
	root.add_child(game)
	game.set_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for p in game.squad:
		var measured = body_script.new()
		for prop in p.body.get_property_list():
			if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and prop["name"] not in ["bleed", "arm_fracture", "leg_fracture", "splinted", "bite_part"]:
				measured.set(prop["name"], p.body.get(prop["name"]))
		measured.measured_person = p
		p.body = measured
	return game


func _trial(run_seed: int, mode: String) -> Dictionary:
	var game = _game(run_seed, mode)
	var dt := 1.0 / hz
	var ticks := roundi(seconds * hz)
	var tick_us := 0
	var living_s := 0.0
	var tired_s := 0.0
	var overloaded_s := 0.0
	var warnings := 0
	var cold: Dictionary = {}
	var fallen: Dictionary = {}
	var initial_fallen: Dictionary = {}
	var first_end := -1.0
	for z in game.zombies.list:
		if z["state"] in ["dead", "downed", "rising"]:
			initial_fallen[z["id"]] = true
	for p in game.squad:
		cold[p.pid] = p.cold_level()
	for tick in ticks:
		if tick % (hz * 2) == 0:
			# Same self-care policy in both versions. No free tools or scripted wounds.
			for p in game.squad:
				if p.can_act() and p.action == "" and p.grabbers.is_empty():
					var urgent: int = p.body.most_urgent()
					if urgent >= 0:
						game.actions.treat_wound(p, p, p.body.wounds[urgent], "full")
			if mode == "walk" and game.player.can_act() and game.player.action == "":
				var goal: Vector2i = WALK_CELLS[mini(int(float(tick) / hz / 50.0), WALK_CELLS.size() - 1)]
				game.player.go_to(game.find_path(game.player.position, game.lift(goal, 0)), false)
		var started := Time.get_ticks_usec()
		game._step(dt)
		tick_us += Time.get_ticks_usec() - started
		if game.ended and first_end < 0:
			first_end = (tick + 1) * dt
		for p in game.squad:
			if p.is_alive():
				living_s += dt
				if p.body.exhaustion_level() > 0:
					tired_s += dt
				if p.carry_state() >= 2:
					overloaded_s += dt
				if p.cold_level() > int(cold.get(p.pid, 0)):
					warnings += 1
			cold[p.pid] = p.cold_level()
		for z in game.zombies.list:
			if z["state"] in ["dead", "downed"] and not initial_fallen.has(z["id"]):
				fallen[z["id"]] = true
	var scratches := 0
	var bites := 0
	var deaths: Array = []
	var care_count := 0
	var care_s := 0.0
	for p in game.squad:
		for wound in p.body.wounds:
			if wound["kind"] == "scratch":
				scratches += int(wound.get("hits", 1))
			elif wound["kind"] == "bite":
				bites += int(wound.get("hits", 1))
		if p.body.dead:
			deaths.append({"id": p.pid, "last_hurt": p.last_hurt_by, "bleed": p.body.bleed,
				"exhaustion": p.body.exhaustion, "breath": p.body.breath, "wounds": p.body.receipt_wounds()})
	care_count = game.completed_care
	care_s = game.completed_care_seconds
	var row := {"kind": "trial", "phase": phase, "mode": mode, "seed": run_seed, "ticks": ticks,
		"scratches": scratches, "bites": bites, "bleed_deaths": game.bleed_deaths.size(),
		"infection_deaths": 0, "care_count": care_count, "care_seconds": care_s,
		"care_mean_s": care_s / care_count if care_count > 0 else 0.0,
		"living_s": living_s, "tired_s": tired_s, "overloaded_s": overloaded_s,
		"tired_ratio": tired_s / living_s if living_s > 0 else 0.0,
		"overloaded_ratio": overloaded_s / living_s if living_s > 0 else 0.0,
		"cold_warnings": warnings, "fallen": fallen.size(), "deaths": deaths.size(),
		"death_detail": deaths, "tick_ms": float(tick_us) / ticks / 1000.0,
		"tick_ms_total": float(tick_us) / 1000.0, "first_end_s": first_end}
	game.free()
	return row


func _record(row: Dictionary) -> void:
	var path := CACHE.path_join(RUN_PREFIX + phase + ".jsonl")
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(JSON.stringify(row))


func _rows(tag: String) -> Array:
	var out: Array = []
	var path := CACHE.path_join(RUN_PREFIX + tag + ".jsonl")
	if not FileAccess.file_exists(path):
		return out
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var row = JSON.parse_string(line)
		if row is Dictionary and row.get("kind") == "trial":
			out.append(row)
	return out


func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	values.sort()
	var middle := values.size() / 2
	return float(values[middle]) if values.size() % 2 else (float(values[middle - 1]) + float(values[middle])) / 2.0


func _write_report() -> void:
	var f := FileAccess.open(REPORT, FileAccess.WRITE)
	f.store_string("# 몸 디테일 전후 측정\n\n씨앗 1~20, walk/holdout 각 300초, 고정 %dHz. 약탈자·자동 일시정지 없음.\n" % hz)
	f.store_string("판 구성은 test_holdout.gd의 _game()와 동일한 옵션이며, 걷기는 정해진 여섯 목표를 50초마다 바꾼다. 두 판 모두 2초마다 소지품으로 가능한 자기 처치를 시도한다. 인위적인 상처·보급은 없다. 종료 화면이 먼저 떠도 300초까지 _step을 계속 호출하며 첫 종료 시간을 원자료에 기록한다.\n\n")
	f.store_string("모든 몸 통계는 분대 기준이다. 처치는 성공한 처치 동작 수이며, 시간은 동작 시작부터 성공까지 실제 시뮬레이션 경과 시간이다(손 속도·장갑·부상 반영, 중단된 동작 제외). 여러 상처를 한 번에 감는 간편 처치는 한 번으로 센다. 처치가 없는 판의 평균은 0으로 두었다. 비율은 살아 있는 분대원 시간을 분모로 한다. 쓰러뜨림은 최초부터 누워 있던 망자를 제외한 고유 개체 수다. 감염 사망은 현행 규칙상 필드 300초 안에 발생하지 않는다(감염 창 480초, 사망은 열차 구간 처리). 틱 비용은 경로/처치 명령과 틱 뒤 통계 수집을 제외한 _step의 경과 시간이다. 몸 처치 계측 오버헤드는 포함한다. 두 버전 모두 _update_zone의 층 표시·벽 가림만 생략하고 구역·운반 기록은 실행했다. 실제 폰 프레임 시간이나 순수 CPU 사용량으로 해석하지 않는다.\n\n")
	f.store_string("| 판 | 시점 | 지표 | 20판 합 / 통합 비율·평균 | 20판 가운데값 |\n|---|---|---|---:|---:|\n")
	var labels := {"scratches": "긁힘", "bites": "물림", "bleed_deaths": "출혈 사망", "infection_deaths": "감염 사망",
		"care_count": "처치 단계 수", "care_mean_s": "처치 평균 초", "tired_ratio": "지친 시간 비율",
		"overloaded_ratio": "짐 초과 시간 비율", "cold_warnings": "체온 경고", "fallen": "쓰러뜨린 망자",
		"deaths": "분대 죽음", "tick_ms": "틱 비용 ms"}
	for mode in ["walk", "holdout"]:
		for tag in ["before", "after"]:
			var rows := _rows(tag).filter(func(r): return r["mode"] == mode)
			if rows.is_empty():
				continue
			for key in labels:
				var values: Array = []
				var sum := 0.0
				var numerator := 0.0
				var denominator := 0.0
				for row in rows:
					values.append(float(row[key]))
					sum += float(row[key])
					match key:
						"care_mean_s":
							numerator += float(row["care_seconds"])
							denominator += float(row["care_count"])
						"tired_ratio", "overloaded_ratio":
							numerator += float(row["tired_s" if key == "tired_ratio" else "overloaded_s"])
							denominator += float(row["living_s"])
						"tick_ms":
							numerator += float(row["tick_ms_total"])
							denominator += float(row["ticks"])
				if key in ["care_mean_s", "tired_ratio", "overloaded_ratio", "tick_ms"]:
					sum = numerator / denominator if denominator > 0 else 0.0
				f.store_line("| %s | %s (%d판) | %s | %.6f | %.6f |" % [mode, tag, rows.size(), labels[key], sum, _median(values)])
	f.store_string("\n## 씨앗별 분대 죽음 비교\n\n| 판 | 씨앗 | 전 | 후 | 변화 |\n|---|---:|---:|---:|---:|\n")
	for before in _rows("before"):
		for after in _rows("after"):
			if before["mode"] == after["mode"] and before["seed"] == after["seed"]:
				f.store_line("| %s | %d | %d | %d | %+d |" % [before["mode"], before["seed"], before["deaths"], after["deaths"], int(after["deaths"]) - int(before["deaths"])])
	f.store_string("\n## 명령\n\n```powershell\n$bodyLog = Join-Path (Get-Location) 's2/.godot/body_detail/paired_before.log'\n& ..\\..\\tools\\godot\\Godot_v4.7.2-stable_win64_console.exe --headless --path s2 --log-file $bodyLog -s res://tools/body_detail_runs.gd -- --phase before --seeds 1:20 --seconds 300 --hz 10 --mode both\n$bodyLog = Join-Path (Get-Location) 's2/.godot/body_detail/paired_after.log'\n& ..\\..\\tools\\godot\\Godot_v4.7.2-stable_win64_console.exe --headless --path s2 --log-file $bodyLog -s res://tools/body_detail_runs.gd -- --phase after --seeds 1:20 --seconds 300 --hz 10 --mode both\n```\n\n원자료: s2/.godot/body_detail/paired_before.jsonl, paired_after.jsonl. 각 파일 첫 줄에 엔진·설정·몸 파일 및 공용 파일 SHA-256이 있다. 수정 전 실행은 최초 수정 전에 저장한 before_sources의 여섯 스크립트를 메모리에 불러 사용했다. 초기 계측 점검용 before.jsonl·final_before.jsonl·smoke 자료는 최종 통계에서 제외했다.\n")


func _checks() -> void:
	if not _prepare():
		failures += 1
		return
	# Execute the actual focused test methods with a local assertion adapter.
	# This is not an installation or a substitute claim of a GUT run.
	var adapter := """
var local_failures: Array = []
var local_assertions := 0
var local_test := ""
func _expect(ok: bool, description: String) -> void:
	local_assertions += 1
	if not ok:
		local_failures.append(local_test + ": " + description)
func assert_true(value, message: String = "") -> void:
	_expect(bool(value), "expected true " + message)
func assert_false(value, message: String = "") -> void:
	_expect(not bool(value), "expected false " + message)
func assert_eq(a, b, message: String = "") -> void:
	_expect(a == b, str(a) + " != " + str(b) + " " + message)
func assert_almost_eq(a, b, epsilon: float, message: String = "") -> void:
	_expect(absf(float(a) - float(b)) <= epsilon, str(a) + " ~= " + str(b) + " " + message)
func assert_lt(a, b, message: String = "") -> void:
	_expect(a < b, str(a) + " not < " + str(b) + " " + message)
func assert_gt(a, b, message: String = "") -> void:
	_expect(a > b, str(a) + " not > " + str(b) + " " + message)
"""
	var receipt := {"gut": "not_run", "runner": "local_assertion_adapter", "tests": 0, "assertions": 0, "failures": []}
	for name in ["test_injury_rules", "test_treatment_detail", "test_stamina", "test_carry_detail"]:
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string("res://tests/game/" + name + ".gd").replace('extends "res://addons/gut/test.gd"', "extends RefCounted") + adapter
		if script.reload() != OK:
			failures += 1
			receipt["failures"].append(name + ": compile failed")
			continue
		var suite = script.new()
		for method in script.get_script_method_list():
			var method_name := String(method["name"])
			if method_name.begins_with("test_"):
				suite.local_test = name + "." + method_name
				suite.call(method_name)
				receipt["tests"] += 1
		failures += suite.local_failures.size()
		receipt["assertions"] += suite.local_assertions
		receipt["failures"].append_array(suite.local_failures)
	var f := FileAccess.open(CACHE.path_join("checks.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(receipt, "\t"))
	print(JSON.stringify(receipt))
