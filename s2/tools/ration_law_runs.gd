extends SceneTree
## The emergency ration law in the field (decision 430): the same stops, run
## with and without the law, side by side. The player runs a fixed round of
## the stop for five minutes whenever the body lets it; the companions keep up
## as they do. Prints a Markdown table after each stop; nothing is written.
## godot --headless --path s2 -s tools/ration_law_runs.gd -- --seeds 1:40 --seconds 300

const FieldGame = preload("res://game/field_game.gd")
const ROUND := [Vector2i(80, 12), Vector2i(90, 32), Vector2i(60, 40), Vector2i(30, 32), Vector2i(30, 12), Vector2i(50, 6)]
const HZ := 10
var first_seed := 1
var last_seed := 40
var seconds := 300.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--seeds":
			var parts: PackedStringArray = args[i + 1].split(":")
			first_seed = int(parts[0])
			last_seed = int(parts[1])
		elif args[i] == "--seconds":
			seconds = float(args[i + 1])
	var rows := {"off": [], "on": []}
	# The table so far after every stop, so a run cut short still leaves one.
	for s in range(first_seed, last_seed + 1):
		for law: String in ["off", "on"]:
			rows[law].append(_trial(s, law == "on"))
		print("\n" + _table(rows))
	quit(0)


func _trial(run_seed: int, law: bool) -> Dictionary:
	var game = FieldGame.new()
	game.opts = {"seed": run_seed, "raiders": false, "auto_pause": false, "laws": ["emergency_ration"] if law else []}
	root.add_child(game)
	game.set_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var p = game.player
	var dt := 1.0 / HZ
	var out := {"run_s": 0.0, "metres": 0.0, "locks": 0, "first_tired": -1.0, "tired_s": 0.0, "heavy_s": 0.0, "hurt": 0, "dead": 0}
	var leg := 0
	var locked := false
	var at: Vector3 = p.position
	for tick in roundi(seconds * HZ):
		if tick % (HZ * 2) == 0 and p.can_act() and p.action == "" and p.path.is_empty():
			var goal: Vector2i = ROUND[leg % ROUND.size()]
			leg += 1
			p.go_to(game.find_path(p.position, game.lift(goal, 0)), true)
		p.running = not p.path.is_empty() and p.body.can_run()
		game._step(dt)
		if not p.is_alive():
			break
		if p.is_running_now():
			out["run_s"] += dt
		out["metres"] += Vector2(p.position.x - at.x, p.position.z - at.z).length()
		at = p.position
		if p.body.breath_locked and not locked:
			out["locks"] += 1
		locked = p.body.breath_locked
		var level: int = p.body.exhaustion_level()
		if level >= 1:
			out["tired_s"] += dt
			if out["first_tired"] < 0.0:
				out["first_tired"] = tick * dt
		if level >= 2:
			out["heavy_s"] += dt
	for q in game.squad:
		out["hurt"] += q.body.wounds.size()
		out["dead"] += int(q.body.dead)
	game.free()
	return out


func _mean(rows: Array, key: String, only_set: bool = false) -> String:
	var total := 0.0
	var n := 0
	for r: Dictionary in rows:
		if only_set and float(r[key]) < 0.0:
			continue
		total += float(r[key])
		n += 1
	return "%.1f" % (total / n) if n > 0 else "-"


func _count(rows: Array, key: String) -> int:
	return rows.filter(func(r: Dictionary) -> bool: return float(r[key]) >= 0.0).size()


func _table(rows: Dictionary) -> String:
	var lines := ["| %d판, %d초 | 법 없음 | 비상식량감축법 |" % [rows["off"].size(), int(seconds)], "|---|---|---|"]
	lines.append("| 뛴 초 | %s | %s |" % [_mean(rows["off"], "run_s"), _mean(rows["on"], "run_s")])
	lines.append("| 간 거리(m) | %s | %s |" % [_mean(rows["off"], "metres"), _mean(rows["on"], "metres")])
	lines.append("| 숨이 막혀 멈춘 번 | %s | %s |" % [_mean(rows["off"], "locks"), _mean(rows["on"], "locks")])
	lines.append("| 처음 지친 초(지친 판 수) | %s (%d) | %s (%d) |" % [_mean(rows["off"], "first_tired", true), _count(rows["off"], "first_tired"), _mean(rows["on"], "first_tired", true), _count(rows["on"], "first_tired")])
	lines.append("| 지친 초 | %s | %s |" % [_mean(rows["off"], "tired_s"), _mean(rows["on"], "tired_s")])
	lines.append("| 심하게 지친 초 | %s | %s |" % [_mean(rows["off"], "heavy_s"), _mean(rows["on"], "heavy_s")])
	lines.append("| 분대 상처 수 | %s | %s |" % [_mean(rows["off"], "hurt"), _mean(rows["on"], "hurt")])
	lines.append("| 분대 죽음 | %s | %s |" % [_mean(rows["off"], "dead"), _mean(rows["on"], "dead")])
	return "\n".join(lines)
