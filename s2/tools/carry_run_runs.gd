extends SceneTree
## Running with a load (decision 448-19, card G): the same stops, the player
## carrying four loads in turn, running a fixed round of the stop whenever the
## body lets it. Run on the rules before and after a change, the same seeds.
## Prints a Markdown table after each stop; nothing is written.
## godot --headless --path s2 -s tools/carry_run_runs.gd -- --seeds 1:8 --seconds 120

const FieldGame = preload("res://game/field_game.gd")
const ROUND := [Vector2i(80, 12), Vector2i(90, 32), Vector2i(60, 40), Vector2i(30, 32), Vector2i(30, 12), Vector2i(50, 6)]
const HZ := 10
## What is in the pack: light (a quarter), past half, over the limit, one big thing.
const LOADS := {"가벼움": {"scrap": 2}, "절반 넘음": {"scrap": 6}, "넘침": {"scrap": 10}, "종 하나": {"symbol_bell": 1}}
var first_seed := 1
var last_seed := 8
var seconds := 120.0


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
	var rows := {}
	for load: String in LOADS:
		rows[load] = []
	# The table so far after every stop, so a run cut short still leaves one.
	for s in range(first_seed, last_seed + 1):
		for load: String in LOADS:
			rows[load].append(_trial(s, LOADS[load]))
		print("\n" + _table(rows))
	quit(0)


func _trial(run_seed: int, load: Dictionary) -> Dictionary:
	var game = FieldGame.new()
	game.opts = {"seed": run_seed, "raiders": false, "auto_pause": false}
	root.add_child(game)
	game.set_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var p = game.player
	p.items.clear()
	for id: String in load:
		p.add_item(id, int(load[id]))
	var dt := 1.0 / HZ
	var out := {"run_s": 0.0, "metres": 0.0, "locks": 0, "state": p.carry_state()}
	var leg := 0
	var locked := false
	var at: Vector3 = p.position
	for tick in roundi(seconds * HZ):
		if tick % (HZ * 2) == 0 and p.can_act() and p.action == "" and p.path.is_empty():
			var goal: Vector2i = ROUND[leg % ROUND.size()]
			leg += 1
			p.go_to(game.find_path(p.position, game.lift(goal, 0)), true)
		p.running = not p.path.is_empty() and p.body.can_run()
		# The load stays as it is: nothing put aboard by the train on the way round.
		for id: String in load:
			p.items[id] = int(load[id])
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
	game.free()
	return out


func _mean(rows: Array, key: String) -> String:
	var total := 0.0
	for r: Dictionary in rows:
		total += float(r[key])
	return "%.1f" % (total / rows.size()) if not rows.is_empty() else "-"


func _table(rows: Dictionary) -> String:
	var n: int = (rows.values()[0] as Array).size()
	var lines := ["| %d판, %d초 | 짐 단계 | 뛴 초 | 간 거리(m) | 숨이 막혀 멈춘 번 |" % [n, int(seconds)], "|---|---|---|---|---|"]
	for load: String in rows:
		var r: Array = rows[load]
		lines.append("| %s | %d | %s | %s | %s |" % [load, int(r[0]["state"]), _mean(r, "run_s"), _mean(r, "metres"), _mean(r, "locks")])
	return "\n".join(lines)
