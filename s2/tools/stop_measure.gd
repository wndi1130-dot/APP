extends SceneTree
## What a stop costs, map by map, for the open-world steps (결정 470 2장 가: a
## wide joined-up area at every stop). For each place: how big its ground is and
## in how many zones, how long each part takes to come up, and, the field
## standing, what a frame draws and what the stop holds in memory. The same
## places and seed before and after a change; one JSON ROW a place, all of them
## in --out. With --shots, pictures from the same spots: where the crew stands
## at the start, and with --edges the middle of each of the four edges.
##   Godot --path s2 --resolution 1688x780 --script res://tools/stop_measure.gd -- --places houses_01,mine_01 --seed 1 --out <rows.json> --shots <dir> --edges
## The parts are timed the way the game builds a stop (stop_loader.gd): the map
## (map_ms) and its buildings' plan (plan_ms) off the main thread, together
## data_ms; then on the main thread the map drawn alone (view_ms) and the whole
## field from that map (field_ms, in one go, the dead's bodies baked once
## beforehand as the loader does). Frames are measured at the field's opening
## zoom and at the widest the player can pull out to (field_hud.gd _zoom).
## Run it with a window: without one draw calls and video memory read 0, so it
## stops. A cell is a metre (field_grid.gd), so the sizes are metres too.
## --all takes every map there is; --size-only builds the maps alone (size,
## zones, map_ms, no field), headless too. --weather clear lifts the default
## fog off the pictures. The numbers are this PC's; the phone check comes in
## the test stage.

const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldGame = preload("res://game/field_game.gd")
const MapView = preload("res://game/world/map_view.gd")
const BuildingView = preload("res://game/world/building_view.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const StopLoader = preload("res://game/stop_loader.gd")

## Frames the field runs before it is measured (the first still load and
## compile), the frames measured, how long the camera is given to come to rest
## over a new spot or zoom, and frames for a freed field to let go of its memory.
const WARM_FRAMES: int = 60
const MEASURE_FRAMES: int = 120
const SETTLE_S: float = 1.5
const FREE_FRAMES: int = 30
## The widest zoom the player can pull out to (field_hud.gd _zoom: 14 to 36).
const WIDEST: float = 36.0
## The four edges, as their pictures are named.
const SIDES: Array[String] = ["west", "east", "north", "south"]

var places: Array = ["first_leg_01_sulechow", "freight_02", "hospital_02", "houses_01", "mine_01"]
var seed_value: int = 1
var out: String = ""
var shots: String = ""
var edges: bool = false
var size_only: bool = false
## The field's own weather when empty (fog and snow); "clear" shows the edges.
var weather: Array = []
var vat: Dictionary = {}
var _held: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		var key := args[i]
		var value := ""
		if key.contains("="):
			value = key.get_slice("=", 1)
			key = key.get_slice("=", 0)
		elif i + 1 < args.size():
			value = args[i + 1]
		match key:
			"--places":
				places = Array(value.split(","))
			"--seed":
				seed_value = int(value)
			"--out":
				out = value
			"--shots":
				shots = value
			"--edges":
				edges = true
			"--all":
				places = Array(FieldMaps.ids())
			"--size-only":
				size_only = true
			"--weather":
				weather = Array(value.split(","))
	_run.call_deferred()


func _ms(from_us: int) -> float:
	return snappedf(float(Time.get_ticks_usec() - from_us) / 1000.0, 0.1)


func _map(place: String) -> Dictionary:
	return FieldMaps.build_from(load(FieldMaps.path_of(FieldMaps.resolve(place))))


func _field(place: String, data: Dictionary):
	var f = FieldGame.new()
	f.opts = {"place": place, "seed": seed_value, "arrive": false, "raiders": false, "auto_pause": false,
		"fps_cap": 0, "map_data": data, "vat": vat}
	if not weather.is_empty():
		f.opts["weather"] = weather
	return f


func _run() -> void:
	var rows: Array = []
	if size_only:
		for place: String in places:
			var t0 := Time.get_ticks_usec()
			var data := _map(place)
			var r: Dictionary = {"place": place, "map_ms": _ms(t0)}
			r.merge(size_row(data))
			print("ROW ", JSON.stringify(r))
			rows.append(r)
		_write(rows, {})
		quit(0)
		return
	if DisplayServer.get_name() == "headless":
		printerr("stop_measure: run it with a window (draw calls and video memory read 0 headless), or --size-only")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	# The dead's stand-in bodies, the same every stop: baked once (stop_loader.gd).
	var t0 := Time.get_ticks_usec()
	vat = VatBaker.build(StopLoader.VAT_VERTICES)
	var once := {"vat_ms": _ms(t0)}
	# Warm what every stop shares (the shaders' first load) on a throwaway map.
	var warm = _field("freight_01", _map("freight_01"))
	root.add_child(warm)
	if not warm.is_built:
		await warm.built
	for k in 5:
		await process_frame
	warm.queue_free()
	for k in FREE_FRAMES:
		await process_frame
	for place: String in places:
		var r: Dictionary = await _measure(place, vp)
		print("ROW ", JSON.stringify(r))
		rows.append(r)
	_write(rows, once)
	quit(0)


func _write(rows: Array, once: Dictionary) -> void:
	if out == "":
		return
	var head := {"adapter": RenderingServer.get_video_adapter_name(), "size": [root.size.x, root.size.y],
		"seed": seed_value, "rows": rows}
	head.merge(once)
	var file := FileAccess.open(out, FileAccess.WRITE)
	file.store_string(JSON.stringify(head, "  "))
	file.close()


func _measure(place: String, vp: RID) -> Dictionary:
	var r: Dictionary = {"place": place, "seed": seed_value}
	var before := memory()
	# Off the main thread in the game: the map, then its buildings' plan.
	var t0 := Time.get_ticks_usec()
	var data := _map(place)
	r["map_ms"] = _ms(t0)
	t0 = Time.get_ticks_usec()
	data["_building_plan"] = BuildingView.plan(data)
	r["plan_ms"] = _ms(t0)
	r["data_ms"] = snappedf(float(r["map_ms"]) + float(r["plan_ms"]), 0.1)
	# The map drawn alone (buildings, ground, edge woods, props, doors, boxes),
	# as stop_load_times.gd does, on a map of its own: drawing may write to it.
	var view = MapView.new()
	root.add_child(view)
	t0 = Time.get_ticks_usec()
	await view.setup(data)
	r["view_ms"] = _ms(t0)
	view.queue_free()
	await process_frame
	# The whole field in one go from a fresh map with its plan, as the loader hands it over.
	var fresh := _map(place)
	fresh["_building_plan"] = BuildingView.plan(fresh)
	var f = _field(place, fresh)
	t0 = Time.get_ticks_usec()
	root.add_child(f)
	if not f.is_built:
		await f.built
	r["field_ms"] = _ms(t0)
	r.merge(size_row(f.data))
	_held = 0
	for k in WARM_FRAMES:
		await process_frame
		_keep_running(f)
	r["cam_open"] = f.cam_size
	r.merge(await _frames(f, vp))
	var after := memory()
	r["memory"] = after
	var grew := {}
	for key: String in after:
		grew[key] = snappedf(float(after[key]) - float(before[key]), 0.1)
	r["memory_grew"] = grew
	# Pulled out as far as the player can.
	var opening: float = f.cam_size
	f.cam_size = WIDEST
	await _settle(f)
	r["widest"] = await _frames(f, vp)
	f.cam_size = opening
	await _settle(f)
	if shots != "":
		await _shot("%s_start" % place)
		if edges:
			# Round the edges: what the stop holds at each (the edge is where a
			# wider ground's memory jumps, card O1).
			var at_edges := {}
			for side in SIDES.size():
				f.player.position = FieldGrid.center(edge_spot(f.grid, side))
				await _settle(f)
				await _shot("%s_edge_%s" % [place, SIDES[side]])
				var m := memory()
				at_edges[SIDES[side]] = [m["static_mb"], m["video_mb"]]
			r["edge_memory_mb"] = at_edges
	r["held_frames"] = _held
	f.queue_free()
	for k in FREE_FRAMES:
		await process_frame
	return r


## How big a stop's ground is: metres a side and walkable, the zones it is
## named in, the old map inside its outer village (map_ring.gd) and what stands
## on it.
static func size_row(data: Dictionary) -> Dictionary:
	var g: FieldGrid = data["grid"]
	var zones: Dictionary = {}
	var walk := 0
	for y in g.height:
		for x in g.width:
			var c := Vector2i(x, y)
			if g.zone_at(c) != "":
				zones[g.zone_at(c)] = true
			if g.people_can_walk(c):
				walk += 1
	var ring: Dictionary = data.get("map_ring", {})
	var inner: Rect2i = ring.get("inner", Rect2i(0, 0, g.width, g.height))
	return {"width_m": g.width, "height_m": g.height, "area_m2": g.width * g.height, "walk_m2": walk,
		"zones": zones.size(), "inner_m": [inner.size.x, inner.size.y], "ring_m": int(ring.get("width", 0)),
		"buildings": data.get("buildings", []).size(), "containers": data.get("containers", {}).size(),
		"levels": data.get("levels", {0: g}).size(), "side_path": data.get("side_path") is Dictionary}


## Megabytes the program holds (and of it, the graphics card's) and how many
## nodes and objects there are. Static memory reads only in a debug build (the
## editor's binary is one).
static func memory() -> Dictionary:
	var mb := 1.0 / 1048576.0
	return {"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) * mb, 0.1),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) * mb, 0.1),
		"texture_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) * mb, 0.1),
		"buffer_mb": snappedf(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) * mb, 0.1),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT)}


## Another window taking the focus pauses the field (field_game.gd interrupt)
## and nothing unpauses it: a paused field draws less and its picture fades.
## Run it on, and count the frames it had to be woken (held_frames in the row).
func _keep_running(f) -> void:
	if f.paused:
		f.paused = false
		f.away = false
		_held += 1


## Frame time and what a frame draws, over MEASURE_FRAMES with no cap.
func _frames(f, vp: RID) -> Dictionary:
	var deltas: Array[float] = []
	var gpu := 0.0
	var cpu := 0.0
	var draws := 0.0
	var objects := 0.0
	var primitives := 0.0
	var last := Time.get_ticks_usec()
	for k in MEASURE_FRAMES:
		await process_frame
		_keep_running(f)
		var now := Time.get_ticks_usec()
		deltas.append(float(now - last) / 1000.0)
		last = now
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	deltas.sort()
	var total := 0.0
	for d in deltas:
		total += d
	var n := float(MEASURE_FRAMES)
	return {"frame_ms_mean": snappedf(total / n, 0.01), "frame_ms_p95": snappedf(deltas[int(n * 0.95)], 0.01),
		"gpu_ms_mean": snappedf(gpu / n, 0.01),
		"render_cpu_ms_mean": snappedf(cpu / n, 0.01), "draw_calls": snappedf(draws / n, 0.1),
		"objects_drawn": snappedf(objects / n, 0.1), "primitives": roundi(primitives / n)}


## The walkable cell nearest the middle of an edge (0 west, 1 east, 2 north,
## 3 south), looking in from it; the middle itself when none is found.
static func edge_spot(g: FieldGrid, side: int) -> Vector2i:
	var start: Vector2i = [Vector2i(0, g.height / 2), Vector2i(g.width - 1, g.height / 2),
		Vector2i(g.width / 2, 0), Vector2i(g.width / 2, g.height - 1)][side]
	var inward: Vector2i = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP][side]
	var along := Vector2i(inward.y, inward.x)
	for depth in mini(g.width, g.height) / 2:
		for k in 24:
			var off := (k + 1) / 2 * (1 if k % 2 == 1 else -1)
			var c := start + inward * depth + along * off
			if g.people_can_walk(c):
				return c
	return start


## Give the camera time to follow the player or the zoom, the field running.
func _settle(f) -> void:
	var until := Time.get_ticks_msec() + int(SETTLE_S * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		_keep_running(f)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
