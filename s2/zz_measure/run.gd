extends Node
## Measuring build only (never merged): on the phone, play each map size in
## turn with sixty dead in sight and print what the frames were.
##   adb logcat -s godot | grep S2MEASURE
## The same lines go to user://measure.txt.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const Tall = preload("res://zz_measure/tall_map.gd")

## name, map script (null: the first stop), rows put in above the track
const CASES: Array = [
	["sulechow_170x100", null, 0],
	["town_180x155", Tall, 45],
	["town_180x110", Tall, 0],
	["town_180x200", Tall, 90],
	["sulechow_170x100_again", null, 0],
]
const SETTLE: float = 4.0
const SAMPLE: float = 40.0
const DEAD: int = 60

var boot
var lines: Array = []


func _ready() -> void:
	# Measured without sound: the phone sits by the person while it runs.
	AudioServer.set_bus_mute(0, true)
	_run.call_deferred()


func _say(text: String) -> void:
	print("S2MEASURE " + text)
	lines.append(text)
	var f := FileAccess.open("user://measure.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines) + "\n")
		f.close()


func _run() -> void:
	_say("start sound=muted model=%s screen=%s refresh=%.0f" % [OS.get_model_name(), str(DisplayServer.screen_get_size()), DisplayServer.screen_get_refresh_rate()])
	for row: Array in CASES:
		await _one(row)
	_say("done")
	boot._show_menu()
	queue_free()


func _one(row: Array) -> void:
	Tall.extra = int(row[2])
	var mem0: int = OS.get_static_memory_usage()
	var t0: int = Time.get_ticks_msec()
	var game = FieldGame.new()
	var opts: Dictionary = boot.settings.duplicate(true)
	opts["squad"] = game.default_squad(String(boot.settings["pipe_quality"]))
	opts["seed"] = 5
	opts["raiders"] = false
	opts["auto_pause"] = false
	game.opts = opts
	if row[1] != null:
		game.map_script = row[1]
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var open_ms: int = Time.get_ticks_msec() - t0
	await get_tree().create_timer(SETTLE).timeout
	var stood: int = _stand(game, DEAD)
	await get_tree().create_timer(2.0).timeout
	var times: Array = []
	var last: int = Time.get_ticks_usec()
	var left: float = SAMPLE
	var seen_most: int = 0
	while left > 0.0 and not game.ended:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = (now - last) / 1000.0
		last = now
		times.append(ms)
		left -= ms / 1000.0
		seen_most = maxi(seen_most, int(game.zombies.drawn_count))
	times.sort()
	var total: float = 0.0
	var slow: int = 0
	for ms: float in times:
		total += ms
		if ms > 1000.0 / 55.0:
			slow += 1
	var n: int = maxi(times.size(), 1)
	var g: FieldGrid = game.grid
	_say("%s cells=%dx%d levels=%d open_ms=%d frames=%d secs=%.1f fps_avg=%.1f frame_avg_ms=%.2f p99_ms=%.2f worst_ms=%.2f low1_fps=%.1f slow_under55=%d (%.1f%%) dead=%d stood=%d drawn_most=%d tris=%d draws=%d static_mb=%.0f video_mb=%.0f ended=%s" % [
		row[0], g.width, g.height, game.levels.size(), open_ms, times.size(), total / 1000.0, 1000.0 * n / maxf(total, 1.0), total / n,
		times[int(n * 0.99) - 1] if n > 1 else 0.0, times[n - 1] if not times.is_empty() else 0.0,
		1000.0 / maxf(times[int(n * 0.99) - 1], 0.001) if n > 1 else 0.0, slow, 100.0 * slow / n,
		game.zombies.list.size(), stood, seen_most,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		(OS.get_static_memory_usage() - mem0) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, str(game.ended)])
	game.queue_free()
	Engine.max_fps = 60
	await get_tree().create_timer(3.0).timeout


## As the test key of the debug panel does: the dead stood on cells the chief sees.
func _stand(game, want: int) -> int:
	var at: Vector3 = game.player.position
	var here: Vector2i = FieldGrid.cell_of(at)
	var cells: Array = []
	for dx in range(-14, 15):
		for dy in range(-14, 15):
			var c := here + Vector2i(dx, dy)
			var spot := FieldGrid.center(c)
			spot.y = at.y
			if dx * dx + dy * dy >= 6 and game.grid.inside(c) and game.grid.dead_can_walk(c) and game.seen_now.has(game.seen_key(spot)):
				cells.append([dx * dx + dy * dy, spot])
	cells.sort_custom(func(a, b): return a[0] < b[0])
	var n: int = 0
	for round in 3:
		for cell in cells:
			if n < want:
				game.zombies.spawn("dead", cell[1] + Vector3(0.3, 0, 0.3) * float(round))
				n += 1
	return n
