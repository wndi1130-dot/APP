extends SceneTree
## Pictures and gauges for the land going by the train (결정 495 6절), same spot before and
## after. The slice's first train step with the diagonal view of train-3d's mockup ②
## (orthographic, turned 45°, looking down 35°, the roofs cut at 2.2 m, a low front
## wall), at the guard car: before = the mockup's plain snow sheet, after = the journey
## (journey.gd) laid round the train; each outside event forced once and shot; draw
## calls, primitives and frame time over 150 frames each way. With --stop: from 「정차
## 고르기」 to the field standing, the screen's brightness every frame and the longest
## run of black frames (the stop scene's hand-over).
##   godot --path s2 --resolution 1688x780 -s res://tools/journey_shots.gd -- --out=<folder> [--tag=1688] [--stop [--no-kit]]
## --no-kit: the stop scene's own corridor of firs and poles (the before of the hand-over).
## --lit: the views lit by the stretch's own daylight (Atmosphere.light of its look, as
## the stop scene lights its world) — a preview: the train screen's own light is mood's.
## --long=<s>: after the before/after, the frame times over <s> seconds with the land
## running, the frames a piece was laid in apart (one every 15 s: 150 frames miss them).
## --enter[=<s>]: the side view going over to the diagonal one (as train-3d's view_mode
## does) <s> seconds (1 by default; 0: the diagonal view from the start) after the land is
## hung: the frames before the switch (the kit's models read a model a frame) and from
## it, and how many till the land is shown.

const Journey = preload("res://game/train/journey/journey.gd")
const Atmosphere = preload("res://fx/atmosphere.gd")
const CUT_H: float = 2.2
const WALL_H: float = 0.9
const YAW: float = 45.0
const PITCH: float = 35.0
const SIZE: float = 22.82
const CAM_DIST: float = 30.0
const CLUSTER: Array = ["dining", "guard", "captain", "front"]
## Darker than this on average is a black frame (0..1 of white).
const BLACK: float = 0.03
const EVENTS: Array = [["dead_rush", "chasers"], ["crows_rise", "field_clump"], ["dead_wagons", "mixed"], ["dead_rush", "walkers"]]

const CUT_SHADER: String = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_tex = true;
uniform bool use_vcol = false;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
uniform float cut_y = 2.2;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	UV = UV * uv1_scale.xy + uv1_offset.xy;
}
void fragment() {
	if (wpos.y > cut_y) {
		discard;
	}
	vec3 c = albedo.rgb;
	if (use_tex) {
		c *= texture(albedo_tex, UV).rgb;
	}
	if (use_vcol) {
		c *= COLOR.rgb;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
"""

var out := ""
var tag := "1688"
var stop_mode := false
var no_kit := false
var lit := false
var long_s := 0.0
var enter_mode := false
var enter_s := 1.0
var flow = null
var t = null
var cam: Camera3D = null
var journey: Node3D = null
var snow_sheet: MeshInstance3D = null
var results: Dictionary = {}
var anchor := Vector3.ZERO
var floor_y := 0.0


func _initialize() -> void:
	create_timer(420.0).timeout.connect(func() -> void:
		print("WATCHDOG timeout")
		quit(3))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--tag="):
			tag = a.substr(6)
		elif a == "--stop":
			stop_mode = true
		elif a == "--no-kit":
			no_kit = true
		elif a == "--lit":
			lit = true
		elif a.begins_with("--long="):
			long_s = float(a.substr(7))
		elif a == "--enter" or a.begins_with("--enter="):
			enter_mode = true
			if a.begins_with("--enter="):
				enter_s = float(a.substr(8))
	DirAccess.make_dir_recursive_absolute(out)
	if stop_mode:
		_run_stop()
	else:
		_run_views()


func _run_views() -> void:
	flow = load("res://game/slice_flow.gd").new()
	flow.opts = {"skip_field": true}
	root.add_child(flow)
	await create_timer(1.0).timeout
	flow.go(0)
	await create_timer(5.0).timeout
	t = flow.train
	cam = t.camera
	_diagonal()
	if lit:
		_daylight(flow.outside.look if flow.outside != null else {})
	journey = Journey.attach(t, t, flow.outside.look if flow.outside != null else {}, 1,
		{"seed": 1, "remember": false, "running": true, "view": "side" if enter_mode else "diag"})
	journey.calm = true
	if enter_mode:
		await _measure_enter()
		_save()
		print("DONE")
		quit()
		return
	# Till the land is shown (the kit's models are read first, a model a frame), at most 10 s.
	var hung: int = Time.get_ticks_msec()
	while not journey.visible and Time.get_ticks_msec() - hung < 10000:
		await process_frame
	print("SHOWN after %.2f s" % (float(Time.get_ticks_msec() - hung) / 1000.0))
	await create_timer(1.0).timeout
	_show(false)
	await _shot("before_diag")
	await _measure("before")
	_show(true)
	await _shot("after_diag")
	await _measure("after")
	if long_s > 0.0:
		await _measure_long(long_s)
		_save()
		print("DONE")
		quit()
		return
	for e: Array in EVENTS:
		var actor: Node3D = journey.force_event(String(e[0]), String(e[1]))
		var waited := 0.0
		# Shot once it is well in sight: the dead running in, the crows going up.
		while waited < 12.0:
			await process_frame
			waited += 1.0 / maxf(Engine.get_frames_per_second(), 1.0)
			if actor == null or not is_instance_valid(actor):
				break
			if _in_sight(actor):
				break
		await create_timer(1.6).timeout
		await _shot("event_%s_%s" % [e[0], e[1]])
		await create_timer(6.0).timeout
	_save()
	print("DONE")
	quit()


## A forced event's place has come into the left of the screen (where the cars are seen).
func _in_sight(actor: Node3D) -> bool:
	var s := cam.unproject_position(actor.global_position + Vector3(10, 0, 0))
	var vis := root.get_visible_rect().size
	return s.x > 0.0 and s.x < vis.x * 0.62 and s.y > 0.0 and s.y < vis.y


func _show(after: bool) -> void:
	journey.visible = after
	journey.set_process(after)
	snow_sheet.visible = not after


func _shot(file: String) -> void:
	for key in ["card", "home", "paper", "marks"]:
		var cd = flow.get(key)
		if cd != null and is_instance_valid(cd) and cd is CanvasItem:
			(cd as CanvasItem).visible = false
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var img: Image = root.get_viewport().get_texture().get_image()
	var p := out.path_join("%s_%s.png" % [file, tag])
	img.save_png(p)
	print("SHOT ", p)


func _measure(key: String) -> void:
	var frames: int = 150
	var started: int = Time.get_ticks_usec()
	var worst: float = 0.0
	var last: int = started
	for i in frames:
		await process_frame
		var now: int = Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
	RenderingServer.force_draw()
	results[key] = {
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"frame_ms_mean": float(Time.get_ticks_usec() - started) / 1000.0 / frames,
		"frame_ms_worst": worst,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"fps": Engine.get_frames_per_second(),
		"journey_chunks": (journey.get("chunks") as Array).size() if journey != null else 0,
	}
	print("PERF ", key, " ", results[key])


## The side view gone over to the diagonal one: each frame's time from the switch, the
## worst, and the frames till the land is shown.
func _measure_enter() -> void:
	var Kit = load("res://game/train/journey/journey_kit.gd")
	var has_warm: bool = false
	for m: Dictionary in Kit.get_script_method_list():
		if String(m["name"]) == "warmed":
			has_warm = true
	var before: Array = []
	var warmed_at: int = -1
	var t0: int = Time.get_ticks_usec()
	var prev: int = t0
	while float(Time.get_ticks_usec() - t0) / 1000000.0 < enter_s:
		await process_frame
		var at: int = Time.get_ticks_usec()
		before.append(snappedf(float(at - prev) / 1000.0, 0.1))
		prev = at
		if has_warm and warmed_at < 0 and bool(Kit.call("warmed")):
			warmed_at = before.size()
	var bworst: float = 0.0
	for ms: float in before:
		bworst = maxf(bworst, ms)
	results["before_switch"] = {"seconds": enter_s, "frames": before.size(), "worst_ms": bworst,
		"over_50ms": before.filter(func(x: float) -> bool: return x > 50.0).size(),
		"models_read_by_frame": warmed_at}
	print("HUNG ", results["before_switch"])
	(journey.get("_opts") as Dictionary)["view"] = "diag"
	var frames: Array = []
	var shown_at: int = -1
	var last: int = Time.get_ticks_usec()
	for i in 120:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(snappedf(float(now - last) / 1000.0, 0.1))
		last = now
		if shown_at < 0 and journey.visible:
			shown_at = i + 1
	var worst: float = 0.0
	for ms: float in frames:
		worst = maxf(worst, ms)
	results["enter"] = {"first_frames_ms": frames.slice(0, 12), "worst_ms": worst,
		"over_33ms": frames.filter(func(x: float) -> bool: return x > 33.4).size(),
		"over_50ms": frames.filter(func(x: float) -> bool: return x > 50.0).size(),
		"shown_after_frames": shown_at, "chunks": (journey.get("chunks") as Array).size()}
	print("ENTER ", results["enter"])


## The frame times over `seconds` with the land running: the frames a piece was laid
## in (journey laid_to moved) and the rest, apart.
func _measure_long(seconds: float) -> void:
	var started: int = Time.get_ticks_usec()
	var last: int = started
	var laid: Array = []
	var other: Array = []
	var laid_before: float = float(journey.get("laid_to"))
	while float(Time.get_ticks_usec() - started) / 1000000.0 < seconds:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = float(now - last) / 1000.0
		last = now
		var laid_now: float = float(journey.get("laid_to"))
		if laid_now > laid_before:
			laid.append(snappedf(ms, 0.1))
			laid_before = laid_now
		else:
			other.append(ms)
	other.sort()
	var over_33: int = other.filter(func(x: float) -> bool: return x > 33.4).size()
	var over_50: int = other.filter(func(x: float) -> bool: return x > 50.0).size()
	results["long"] = {"seconds": seconds, "pieces_laid": laid.size(), "laid_frame_ms": laid,
		"other_frames": other.size(), "other_median_ms": float(other[other.size() / 2]) if not other.is_empty() else 0.0,
		"other_p99_ms": float(other[int(other.size() * 0.99)]) if not other.is_empty() else 0.0,
		"other_over_33ms": over_33, "other_over_50ms": over_50}
	print("LONG ", results["long"])


func _save() -> void:
	var f := FileAccess.open(out.path_join("measure_%s.json" % tag), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(results, "  "))
		f.close()


## train-3d's mockup ② (내정대각시안_20261028 diag_shots.gd): the shells' roofs cut, a
## low front wall, the plain snow sheet, the camera on the guard car.
func _diagonal() -> void:
	var feet: Array = []
	for a in t.life.actors.values():
		var body = a.get("body")
		if body != null and is_instance_valid(body):
			feet.append((body as Node3D).global_position.y)
	feet.sort()
	floor_y = float(feet[int(feet.size() * 0.5)]) if not feet.is_empty() else 0.0
	var mats: Dictionary = {}
	for c in t.cars:
		if c.get("shell_mat") != null:
			mats[c["shell_mat"]] = true
	var sh := Shader.new()
	sh.code = CUT_SHADER
	for n in t.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var src := mi.material_override as StandardMaterial3D
		if src == null or not mats.has(src):
			continue
		var cut := ShaderMaterial.new()
		cut.shader = sh
		cut.set_shader_parameter("albedo", src.albedo_color)
		cut.set_shader_parameter("use_tex", src.albedo_texture != null)
		if src.albedo_texture != null:
			cut.set_shader_parameter("albedo_tex", src.albedo_texture)
		cut.set_shader_parameter("use_vcol", src.vertex_color_use_as_albedo)
		cut.set_shader_parameter("uv1_scale", src.uv1_scale)
		cut.set_shader_parameter("uv1_offset", src.uv1_offset)
		cut.set_shader_parameter("cut_y", floor_y + CUT_H)
		mi.material_override = cut
	for n2 in t.find_children("*", "GeometryInstance3D", true, false):
		var gi := n2 as GeometryInstance3D
		if not (gi is MeshInstance3D or gi is MultiMeshInstance3D) or cam.is_ancestor_of(gi) or not gi.visible:
			continue
		var hb: AABB = gi.global_transform * gi.get_aabb()
		if hb.position.y > floor_y + CUT_H - 0.01 and hb.size.y < 6.0:
			gi.visible = false
	var bd = t.get("backdrop")
	if bd != null and is_instance_valid(bd):
		(bd as Node3D).visible = false
	if flow.outside != null:
		flow.outside.visible = false
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.34, 0.32, 0.30)
	wall_mat.roughness = 1.0
	var car_len: float = float(t.get_script().get_script_constant_map().get("CAR_LENGTH", 16.0))
	var cl: Array = []
	for c3 in t.cars:
		var gp3: Vector3 = (c3["node"] as Node3D).global_position
		var wall := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(car_len - 0.1, WALL_H + 0.05, 0.08)
		wall.mesh = bm
		wall.material_override = wall_mat
		t.add_child(wall)
		wall.global_position = Vector3(gp3.x + car_len * 0.5, floor_y + (WALL_H - 0.05) * 0.5, 1.44)
		if CLUSTER.has(String(c3["id"])):
			cl.append(gp3.x)
	cl.sort()
	anchor = Vector3((float(cl[1]) if cl.size() > 1 else 0.0) + car_len * 0.5, floor_y + 0.9, 0.0)
	snow_sheet = MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(600.0, 0.2, 300.0)
	snow_sheet.mesh = gm
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color(0.72, 0.76, 0.82)
	snow.roughness = 1.0
	snow_sheet.material_override = snow
	t.add_child(snow_sheet)
	snow_sheet.global_position = Vector3(anchor.x, -1.46 - 0.12, 0.0)
	var vis := root.get_visible_rect().size
	var panel_left: float = vis.x - 560.0
	var pn = flow.get("pane")
	if pn != null and is_instance_valid(pn) and pn is Control and (pn as Control).is_visible_in_tree():
		var prc := (pn as Control).get_global_rect()
		if prc.position.x > vis.x * 0.4:
			panel_left = prc.position.x
	cam.size = SIZE
	cam.h_offset = (vis.x - panel_left) * 0.5 * cam.size / vis.y
	var yaw := deg_to_rad(YAW)
	var pitch := deg_to_rad(PITCH)
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	cam.look_at_from_position(anchor + dir * CAM_DIST, anchor, Vector3.UP)
	# The journey lays its events ahead of the camera's middle along the train.
	t.cam_x = anchor.x
	print("DIAG anchor=%s size=%.2f h_off=%.2f floor_y=%.2f" % [str(anchor), cam.size, cam.h_offset, floor_y])


## The stretch's daylight over the train scene's own (a preview, see --lit).
func _daylight(look: Dictionary) -> void:
	if look.is_empty():
		return
	var light: Dictionary = Atmosphere.light(look)
	for n in t.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (n as WorldEnvironment).environment
		env.ambient_light_color = light["ambient_color"]
		env.ambient_light_energy = float(light["ambient_energy"]) * 1.15
		env.background_color = Color(light["fog_color"]).darkened(0.3)
		env.tonemap_exposure = float(light.get("exposure", Atmosphere.EXPOSURE))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(float(light["sun_pitch"]), float(light["sun_yaw"]), 0.0)
	sun.light_color = light["sun_color"]
	sun.light_energy = light["sun_energy"]
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	t.add_child(sun)
	print("LIT sun=%s energy=%.2f ambient=%.2f" % [str(sun.rotation_degrees), sun.light_energy, float(light["ambient_energy"])])


# ---------------------------------------------------------------- the stop hand-over

## From 「정차 고르기」 on the train to the field standing: every frame's mean
## brightness (a small copy of the screen), the longest run of black frames.
func _run_stop() -> void:
	if no_kit:
		ProjectSettings.set_setting("visuals/journey_corridor_enabled", false)
	flow = load("res://game/slice_flow.gd").new()
	flow.opts = {"cinema_seen": false, "map_threads": true}
	root.add_child(flow)
	await create_timer(1.0).timeout
	flow.go(0)
	await create_timer(4.0).timeout
	var lums: Array = []
	var black_run: int = 0
	var worst_run: int = 0
	var black_total: int = 0
	var started: int = Time.get_ticks_msec()
	var sent: bool = false
	var shots: Dictionary = {}
	# Where the time goes: each beat's start (s from 「정차 고르기」) and the heavy frames.
	var beats: Array = []
	var frame_last: int = Time.get_ticks_usec()
	var frame_worst: float = 0.0
	var over_50: int = 0
	var over_100: int = 0
	flow.go(flow._index_of("stop_pick"))
	while Time.get_ticks_msec() - started < 120000:
		await process_frame
		var frame_now: int = Time.get_ticks_usec()
		var frame_ms: float = float(frame_now - frame_last) / 1000.0
		frame_last = frame_now
		frame_worst = maxf(frame_worst, frame_ms)
		over_50 += 1 if frame_ms > 50.0 else 0
		over_100 += 1 if frame_ms > 100.0 else 0
		var cin_now = flow.get("cinema")
		if cin_now != null and is_instance_valid(cin_now):
			var b_now: String = String(cin_now.beat)
			if beats.is_empty() or String(beats[-1][0]) != b_now:
				beats.append([b_now, snappedf(float(Time.get_ticks_msec() - started) / 1000.0, 0.01)])
		var img: Image = root.get_viewport().get_texture().get_image()
		img.resize(64, 30, Image.INTERPOLATE_BILINEAR)
		var sum: float = 0.0
		for y in img.get_height():
			for x in img.get_width():
				sum += img.get_pixel(x, y).get_luminance()
		var lum: float = sum / float(img.get_width() * img.get_height())
		lums.append(snappedf(lum, 0.001))
		if lum < BLACK:
			black_run += 1
			black_total += 1
			worst_run = maxi(worst_run, black_run)
		else:
			black_run = 0
		var cin = flow.get("cinema")
		# The tool's window may not have the focus: the scene would hold where it is (J03).
		if cin != null and is_instance_valid(cin) and bool(cin.get("paused")):
			cin.call("_pause", false)
		# The same moments with and without the kit: on the roof as it runs, and slowing for the stop.
		if cin != null and is_instance_valid(cin):
			for want: Array in [["run", 1.4], ["near", 2.0]]:
				var key: String = String(want[0])
				if not shots.has(key) and String(cin.beat) == key and float(cin.t) >= float(want[1]):
					shots[key] = true
					var shot: Image = root.get_viewport().get_texture().get_image()
					shot.save_png(out.path_join("stop_%s_%s_%s.png" % [key, "firs" if no_kit else "kit", tag]))
					# The stop scene draws in its own viewport: the frame's totals count both.
					results["at_" + key] = {
						"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
						"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
						"fps": Engine.get_frames_per_second()}
		if not sent and cin != null and is_instance_valid(cin) and String(cin.beat) == "hold":
			await create_timer(1.2).timeout
			flow._send_crew()
			sent = true
		if sent and flow.current() == "field" and (cin == null or not is_instance_valid(cin)):
			for i in 20:
				await process_frame
			break
	results["stop"] = {"frames": lums.size(), "black_frames": black_total, "longest_black_run": worst_run,
		"min_lum": lums.min() if not lums.is_empty() else -1.0, "seconds": float(Time.get_ticks_msec() - started) / 1000.0,
		"frame_ms_worst": frame_worst, "frames_over_50ms": over_50, "frames_over_100ms": over_100, "beats": beats}
	print("STOP ", results["stop"])
	var f := FileAccess.open(out.path_join("stop_lum_%s_%s.json" % ["firs" if no_kit else "kit", tag]), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"summary": results["stop"], "run": results.get("at_run", {}), "near": results.get("at_near", {}), "lum": lums}))
		f.close()
	print("DONE")
	quit()
