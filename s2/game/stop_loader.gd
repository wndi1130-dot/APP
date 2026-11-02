extends Node
## Gets a stop's field ready while the stop is still seen from the train
## (정차 연출, 결정 421-3). As soon as the next stop is known its map is built
## off the main thread (data only: the map script's own build, no nodes; the
## scene tree is touched on the main thread alone). Once the crew is sent the
## field is built under the slice over frames, out of sight and standing still,
## till the slice shows it. Building it so changes nothing in the stop: the
## same map, seed and order as the field built in one call (test_stop_loader.gd).

signal data_ready
signal field_built(field: Node)
signal failed(issue: String)

const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGame = preload("res://game/field_game.gd")
const BuildingView = preload("res://game/world/building_view.gd")
const MapView = preload("res://game/world/map_view.gd")
const RoomFinish = preload("res://game/world/room_finish.gd")
const EdgeBand = preload("res://game/world/edge_band.gd")
const WorkSpots = preload("res://game/world/work_spots.gd")
const SidePath = preload("res://game/world/side_path.gd")
const StopGround = preload("res://game/world/stop_ground.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
## The dead's stand-in bodies at the field's own count (field_game.gd opts
## "vertices", 1500): the same every stop, so baked once, off the main thread.
const VAT_VERTICES: int = 1500

## Microseconds of building one frame may take: while the camera moves, and
## once it has come to rest over the stop (a still picture bears a slower frame).
const BUDGET_MOVING_USEC: int = 8000
const BUDGET_RESTING_USEC: int = 30000

## The stop's place (FieldMaps id, resolved) and its map once built.
var place: String = ""
## The field seed the map is made for (-1: none known, the field puts the side path on).
var seed_for: int = -1
## The stop's form the map is made in (stop_ground.gd; "" as the map is) and the edge's
## walk-off asked for (-1: the seed's).
var form_for: String = ""
var form_m_for: float = -1.0
var band_for: String = ""
var data: Dictionary = {}
var vat: Dictionary = {}
var field: Node = null
## Off: the map is built at once on the main thread (tests that want no thread).
var threaded: bool = true
## The camera has come to rest over the stop: longer slices of the build.
var resting: bool = false
## What it took (ms), for the result notes: the map off the thread, the field
## over frames, the longest frame while the field was built and how many.
var stats: Dictionary = {}
var _state: String = "idle"          # idle, loading, building, ready
var _path: String = ""
var _task: int = -1
var _box: Dictionary = {}            # the worker writes the map here
var _data_from: int = 0
var _field_from: int = 0
var _last_frame: int = 0
var visit_for: String = ""
var error: String = ""
var _generation: int = 0
var _retired: Array[int] = []
var _loading_path: String = ""
var _retired_paths: Array[String] = []


func _ready() -> void:
	set_process(false)


## Start on the map of `place_id` (the default map when there is none), with the
## field's seed when it is known (its side path is then put on the map here; -1: the
## field puts it on), in the stop's form when it is known (its ground then goes on
## here, off the main thread, before the side path). The same place, seed, form and band
## again keeps what is under way.
func prepare(place_id: String, run_seed: int = -1, form: String = "", form_m: float = -1.0, visit_id: String = "", band: String = "") -> void:
	var strict: bool = not visit_id.is_empty()
	var id: String = place_id if strict else FieldMaps.resolve(place_id)
	if _state in ["loading", "building", "ready"] and id == place and visit_id == visit_for and run_seed == seed_for and form == form_for and form_m == form_m_for and band == band_for:
		return
	_generation += 1
	if not _loading_path.is_empty():
		_retired_paths.append(_loading_path)
		_loading_path = ""
		set_process(true)
	if _task >= 0:
		_retired.append(_task)
		_task = -1
	abandon()
	_state = "idle"
	error = ""
	place = id
	visit_for = visit_id
	seed_for = run_seed
	form_for = form
	form_m_for = form_m
	band_for = band
	data = {}
	if strict and (id.is_empty() or not FieldMaps.has(id)):
		error = "F-CAMPAIGN-MAP: unregistered loader map"
		_state = "failed"
		failed.emit(error)
		data_ready.emit()
		return
	_path = FieldMaps.path_of(place)
	_data_from = Time.get_ticks_usec()
	if not threaded:
		_take(FieldMaps.build(place, band))
		return
	if ResourceLoader.load_threaded_request(_path, "", false) != OK:
		_start_task(load(_path))
		return
	_loading_path = _path
	_state = "loading"
	set_process(true)


func has_data() -> bool:
	return _state == "ready"


## Build the field of the prepared place under `parent`, out of sight and
## standing still, with `opts` (the field's own: squad, seed, departure); it is
## handed over by field_built. Waits for the map first if it is not done.
func build_field(parent: Node, opts: Dictionary) -> void:
	# A map made for another field seed (another side path) is made again, here,
	# before the field is (never a whole map built in one frame). One made with no
	# seed has no side path yet: the field puts it on (field_game.gd with_side_path).
	var want: int = int(opts["seed"]) if opts.has("seed") else -1
	# So is one made in another form than the field's, so its ground goes on off the main thread too.
	var form := String(opts.get("stop_form", ""))
	var form_m := float(opts.get("stop_form_m", -1.0))
	var band := FieldGame.region_for(opts)
	var visit_id: String = String(opts.get("visit_id", ""))
	var requested: String = String(opts.get("place", ""))
	if visit_id.is_empty():
		requested = FieldMaps.resolve(requested)
	if _state == "idle" or requested != place or visit_id != visit_for or (seed_for >= 0 and want != seed_for) or form != form_for or form_m != form_m_for or band != band_for:
		prepare(requested, want, form, form_m, visit_id, band)
	var generation: int = _generation
	if _state == "failed":
		return
	if not has_data():
		await data_ready
	if generation != _generation or not has_data() or requested != place or visit_id != visit_for:
		return
	if not visit_id.is_empty() and (data.get("place_id") != requested or data.get("place_kind") != opts.get("campaign_kind")):
		error = "F-CAMPAIGN-MAP: loader data differs"
		failed.emit(error)
		return
	var o: Dictionary = opts.duplicate()
	o["place"] = requested
	o["map_data"] = data
	o["staged"] = true
	if not vat.is_empty() and int(o.get("vertices", VAT_VERTICES)) == VAT_VERTICES:
		o["vat"] = vat
	# The field changes its map as it is played: the next stop builds its own.
	data = {}
	_state = "idle"
	_field_from = Time.get_ticks_usec()
	_last_frame = _field_from
	stats["longest_frame_ms"] = 0.0
	stats["frames"] = 0
	field = FieldGame.new()
	field.opts = o
	field.visible = false
	set_process(true)
	parent.add_child(field)
	_pace_budget()
	var f: Node = field
	if not f.is_built:
		await f.built
	if generation != _generation or f != field:
		return
	stats["field_ms"] = float(Time.get_ticks_usec() - _field_from) / 1000.0
	stats["longest_piece_ms"] = float(f.pace.longest_usec) / 1000.0
	field_built.emit(f)


## The field is not wanted after all: a build under way finishes in one go at
## its next piece (a build stopped half way would wake to a freed node), then goes.
func abandon() -> void:
	if not is_instance_valid(field):
		field = null
		return
	var f: Node = field
	field = null
	if f.is_built:
		f.queue_free()
		return
	f.pace.on = false
	f.built.connect(f.queue_free, CONNECT_ONE_SHOT)


func _process(_delta: float) -> void:
	# Replaced resource requests still need one get when they finish.
	for i: int in range(_retired_paths.size() - 1, -1, -1):
		var retired_path: String = _retired_paths[i]
		if ResourceLoader.load_threaded_get_status(retired_path) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			ResourceLoader.load_threaded_get(retired_path)
			_retired_paths.remove_at(i)
	for i: int in range(_retired.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_retired[i]):
			WorkerThreadPool.wait_for_task_completion(_retired[i])
			_retired.remove_at(i)
	if _state == "loading":
		var status: int = ResourceLoader.load_threaded_get_status(_loading_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var loaded_script: Script = ResourceLoader.load_threaded_get(_loading_path)
			_loading_path = ""
			_start_task(loaded_script)
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			ResourceLoader.load_threaded_get(_loading_path)
			_loading_path = ""
			_start_task(load(_path))
	elif _state == "building" and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		var built: Variant = _box.get("data")
		if _box.get("vat") is Dictionary:
			vat = _box["vat"]
		var generation: int = int(_box.get("generation", -1))
		_take(built if built is Dictionary and not (built as Dictionary).is_empty() else FieldMaps.build(place, band_for), generation)
	if is_instance_valid(field) and not field.is_built:
		var now: int = Time.get_ticks_usec()
		stats["longest_frame_ms"] = maxf(float(stats.get("longest_frame_ms", 0.0)), float(now - _last_frame) / 1000.0)
		stats["frames"] = int(stats.get("frames", 0)) + 1
		_last_frame = now
		_pace_budget()


func _start_task(script: Script) -> void:
	_box = {"generation": _generation}
	_state = "building"
	_task = WorkerThreadPool.add_task(_build_off_thread.bind(_box, script, seed_for, form_for, form_m_for, band_for, VAT_VERTICES if vat.is_empty() else 0), false, "stop map")
	set_process(true)


## On the worker: the map and what is made ahead from it (make_ready), nothing in
## the scene tree.
static func _build_off_thread(box: Dictionary, script: Script, run_seed: int, form: String, form_m: float, band: String, vat_vertices: int) -> void:
	box["data"] = make_ready(script, run_seed, form, form_m, band)
	if vat_vertices > 0:
		box["vat"] = VatBaker.build(vat_vertices)


## The map script's static build; in the stop's form, its ground (stop_ground.gd: an
## edge stop grows the map out along the track); with the field's seed, the side path
## put on it next (side_path.gd: the same way the field would put it on, and it can grow
## and shift the map; FieldGame.shape_stop keeps the same order); then from the map as it
## now is the plan of its buildings
## (building_view.gd), the ground's and the floors' arrays (map_view.gd, 2a) with the
## maps they fit, the rooms' finish (room_finish.gd) and the plan of the woods round
## the map (edge_band.gd plan_ahead). Data only, no nodes.
static func make_ready(script: Script, run_seed: int, form: String = "", form_m: float = -1.0, band: String = "") -> Dictionary:
	var d: Dictionary = FieldMaps.build_from(script, band)
	if not form.is_empty():
		d = StopGround.apply(d, form, run_seed, form_m)
	d = StopGround.widen_view(d)
	if run_seed >= 0:
		d = SidePath.add(d, run_seed)
		d["_side_seed"] = run_seed
	d["_building_plan"] = BuildingView.plan(d)
	var g: FieldGrid = d["grid"]
	d["_ground_arrays"] = MapView.ground_arrays(g, MapView.ground_details(g))
	d["_ground_key"] = MapView.ground_key(g)
	var keys: Dictionary = {}
	d["_floor_arrays"] = MapView.level_floor_arrays(d.get("levels", {}), keys)
	d["_floor_keys"] = keys
	d["_room_finish"] = RoomFinish.build(d)
	d["_edge_plan"] = EdgeBand.plan_ahead(d)
	# The walk from the train doors and the clumps of trees to fell (work_spots.gd);
	# the field's dress adds the stretch's food depot from the same walk.
	WorkSpots.dress(d, -1, run_seed)
	return d


func _take(d: Dictionary, generation: int = -1) -> void:
	if generation >= 0 and generation != _generation:
		return
	if not visit_for.is_empty() and d.get("place_id") != place:
		error = "F-CAMPAIGN-MAP: prepared map differs"
		_state = "failed"
		failed.emit(error)
		data_ready.emit()
		return
	data = d
	_state = "ready"
	stats["data_ms"] = float(Time.get_ticks_usec() - _data_from) / 1000.0
	data_ready.emit()


func _pace_budget() -> void:
	if is_instance_valid(field) and field.pace != null:
		field.pace.budget_usec = BUDGET_RESTING_USEC if resting else BUDGET_MOVING_USEC
		field.pace.still = resting


func _exit_tree() -> void:
	if not _loading_path.is_empty():
		ResourceLoader.load_threaded_get(_loading_path)
		_loading_path = ""
	for retired_path: String in _retired_paths:
		ResourceLoader.load_threaded_get(retired_path)
	_retired_paths.clear()
	# A task still running finishes before the loader goes; its map is dropped.
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	for task: int in _retired:
		WorkerThreadPool.wait_for_task_completion(task)
	_retired.clear()
