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

const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGame = preload("res://game/field_game.gd")
const BuildingView = preload("res://game/world/building_view.gd")
const MapView = preload("res://game/world/map_view.gd")
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


func _ready() -> void:
	set_process(false)


## Start on the map of `place_id` (the default map when there is none). The
## same place again keeps what is under way.
func prepare(place_id: String) -> void:
	var id: String = FieldMaps.resolve(place_id)
	if _state != "idle" and id == place:
		return
	place = id
	data = {}
	_path = FieldMaps.path_of(place)
	_data_from = Time.get_ticks_usec()
	if not threaded:
		_take(FieldMaps.build(place))
		return
	if ResourceLoader.load_threaded_request(_path, "", false) != OK:
		_start_task(load(_path))
		return
	_state = "loading"
	set_process(true)


func has_data() -> bool:
	return _state == "ready"


## Build the field of the prepared place under `parent`, out of sight and
## standing still, with `opts` (the field's own: squad, seed, departure); it is
## handed over by field_built. Waits for the map first if it is not done.
func build_field(parent: Node, opts: Dictionary) -> void:
	if _state == "idle":
		prepare(String(opts.get("place", "")))
	if not has_data():
		await data_ready
	var o: Dictionary = opts.duplicate()
	o["place"] = place
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
	if f != field:
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
	if _state == "loading":
		var status: int = ResourceLoader.load_threaded_get_status(_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_start_task(ResourceLoader.load_threaded_get(_path))
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_start_task(load(_path))
	elif _state == "building" and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		var built: Variant = _box.get("data")
		if _box.get("vat") is Dictionary:
			vat = _box["vat"]
		_take(built if built is Dictionary and not (built as Dictionary).is_empty() else FieldMaps.build(place))
	if is_instance_valid(field) and not field.is_built:
		var now: int = Time.get_ticks_usec()
		stats["longest_frame_ms"] = maxf(float(stats.get("longest_frame_ms", 0.0)), float(now - _last_frame) / 1000.0)
		stats["frames"] = int(stats.get("frames", 0)) + 1
		_last_frame = now
		_pace_budget()


func _start_task(script: Script) -> void:
	_box = {}
	_state = "building"
	_task = WorkerThreadPool.add_task(_build_off_thread.bind(_box, script, VAT_VERTICES if vat.is_empty() else 0), false, "stop map")
	set_process(true)


## On the worker: the map script's static build, the plan of its buildings
## (building_view.gd plan reads the map alone) and what the ground draws on each
## cell (map_view.gd ground_details), nothing in the scene tree.
static func _build_off_thread(box: Dictionary, script: Script, vat_vertices: int) -> void:
	var d: Dictionary = FieldMaps.build_from(script)
	d["_building_plan"] = BuildingView.plan(d)
	d["_ground_details"] = MapView.ground_details(d["grid"])
	box["data"] = d
	if vat_vertices > 0:
		box["vat"] = VatBaker.build(vat_vertices)


func _take(d: Dictionary) -> void:
	data = d
	_state = "ready"
	stats["data_ms"] = float(Time.get_ticks_usec() - _data_from) / 1000.0
	data_ready.emit()


func _pace_budget() -> void:
	if is_instance_valid(field) and field.pace != null:
		field.pace.budget_usec = BUDGET_RESTING_USEC if resting else BUDGET_MOVING_USEC
		field.pace.still = resting


func _exit_tree() -> void:
	# A task still running finishes before the loader goes; its map is dropped.
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
