extends SceneTree
## Frame time of the field and of the running train, the same way before and
## after a picture change (the atmosphere frame, 2026-10-24). No vsync, no cap.
##   godot --path s2 --resolution 1688x780 -s res://tools/atmosphere_frames.gd -- --out=<file.json>
## Optional: --frames=600 --warm=120 --only=field_fog
## The numbers are this PC's; the phone check comes in the test stage.

const FieldGame = preload("res://game/field_game.gd")
const SliceFlow = preload("res://game/slice_flow.gd")

## name -> what to start. "field": a stop with these opts; "travel": the slice's
## train step. The field cases stand in the hardest cold (the most snow, ice and
## frost to draw); the before-build ignores "cold". field_autumn_rain: the
## prologue's first stop, rain on wet ground.
const CASES: Array = [
	["field_fog", "field", {"weather": ["fog", "snow"], "cold": 1.0}],
	["field_clear", "field", {"weather": ["clear"], "cold": 1.0}],
	["field_blizzard", "field", {"weather": ["blizzard"], "cold": 1.0}],
	["field_autumn_rain", "field", {"weather": ["fog", "snow"], "cold": 0.0}],
	["travel", "travel", {}],
]

var out := ""
var frames := 600
var warm := 120
var only := ""


func _initialize() -> void:
	_run()


func _arg(a: String, key: String) -> String:
	return a.substr(key.length()) if a.begins_with(key) else ""


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = _arg(a, "--out=")
		elif a.begins_with("--frames="):
			frames = int(_arg(a, "--frames="))
		elif a.begins_with("--warm="):
			warm = int(_arg(a, "--warm="))
		elif a.begins_with("--only="):
			only = _arg(a, "--only=")
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var results: Dictionary = {
		"adapter": RenderingServer.get_video_adapter_name(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"size": [root.size.x, root.size.y],
		"cases": {},
	}
	for row in CASES:
		if only != "" and String(row[0]) != only:
			continue
		var node: Node = _start(String(row[1]), row[2])
		results["cases"][row[0]] = await _measure(node, vp)
		node.queue_free()
		for _i in range(5):
			await process_frame
	var text := JSON.stringify(results, "  ")
	print(text)
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	quit()


func _start(kind: String, more: Dictionary) -> Node:
	if kind == "travel":
		var flow = SliceFlow.new()
		flow.opts = {"skip_field": true}
		root.add_child(flow)
		return flow
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "fps_cap": 0, "arrive": false}
	game.opts.merge(more, true)
	root.add_child(game)
	return game


func _measure(node: Node, vp: RID) -> Dictionary:
	for _i in range(warm):
		await process_frame
	Engine.max_fps = 0
	var deltas: Array[float] = []
	var gpu := 0.0
	var cpu := 0.0
	var last := Time.get_ticks_usec()
	for _i in range(frames):
		await process_frame
		var now := Time.get_ticks_usec()
		deltas.append((now - last) / 1000.0)
		last = now
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	deltas.sort()
	var total := 0.0
	for d in deltas:
		total += d
	return {
		"frame_ms_mean": snappedf(total / deltas.size(), 0.01),
		"frame_ms_p95": snappedf(deltas[int(deltas.size() * 0.95)], 0.01),
		"gpu_ms_mean": snappedf(gpu / frames, 0.01),
		"render_cpu_ms_mean": snappedf(cpu / frames, 0.01),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
	}
