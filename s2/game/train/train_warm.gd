extends RefCounted
## Keep future room models alive while the train has no room to rebuild.

const Catalog = preload("res://game/train/train_catalog.gd")
const Interior = preload("res://game/train/train_interior.gd")
const WARM_DELAY_FRAMES: int = 30
const WARM_IN_FLIGHT: int = 2
# Same fallback as train_scene.gd; avoid a circular script preload.
const STOVE_MODEL := "res://models/train_interior/stove.glb"
static var cfg_path := "user://train_warm.cfg"
static var default_on: bool = not " ".join(OS.get_cmdline_args()).contains("gut_cmdln.gd")
static var held: Dictionary = {}
# Every started request has one owner here until its one get, even after tree exit.
static var _requests: Array[String] = []
static var _orphans: Array[String] = []
static var _reaper := OrphanReaper.new()


class OrphanReaper extends RefCounted:
	var _tree: SceneTree
	var _pending: Array[String] = []
	var _retired: Array[String] = []

	func start(tree: SceneTree, pending: Array[String], retired: Array[String]) -> void:
		_pending = pending
		_retired = retired
		_tree = tree
		if not _tree.process_frame.is_connected(_poll):
			_tree.process_frame.connect(_poll)

	func _poll() -> void:
		for path: String in _retired.duplicate():
			if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				continue
			# The departed train no longer needs even a successful result.
			ResourceLoader.load_threaded_get(path)
			_retired.erase(path)
			_pending.erase(path)
		if _retired.is_empty():
			_tree.process_frame.disconnect(_poll)
			_tree = null


var state: String = "off"
var stats: Dictionary = {}
var requested: int = 0
var _scene: WeakRef
var _cars: Array = []
var _next_car: int = 0
var _exists_paths: Dictionary = {}
var _collected_paths: Dictionary = {}
var _dress_models: Dictionary = {}
var _keep: Dictionary = {}
var _dress_added: Dictionary = {}
var _paths: Array = []
var _dress: Array = []
var _next_path: int = 0
var _next_dress: int = 0
var _in_flight: Array[String] = []
var _wait_frames: int = WARM_DELAY_FRAMES
var _began_usec: int = 0
var _static_bytes: float = 0.0


static func _exists(path: String, seen: Dictionary) -> bool:
	if not seen.has(path):
		seen[path] = ResourceLoader.exists(path)
	return bool(seen[path])


static func paths_for(cars: Array, seen: Dictionary = {}) -> Dictionary:
	var scenes: Dictionary = {}
	var dress: Dictionary = {}
	var keep: Dictionary = {}
	for car: Dictionary in cars:
		var def: Dictionary = car["def"]
		var id: String = String(def.get("id", ""))
		var next_stage: int = mini(int(car["home_stage"]) + 1, 3)
		var stages: Array[int] = [next_stage]
		for stage: int in range(4):
			if stage != next_stage:
				stages.append(stage)
		var rows: Array = Catalog.layout(def)["props"]
		for stage: int in stages:
			for row: Dictionary in rows:
				if row.has("cars") and not (row["cars"] as Array).has(id):
					continue
				var home: Array = row.get("home", [0, 3])
				if stage < int(home[0]) or stage > int(home[1]):
					continue
				var models: Dictionary = row.get("home_model", {})
				var model: String = String(models.get(str(stage), row["model"]))
				var is_dress: bool = bool(row.get("dress", false))
				var is_stove: bool = row.get("system", "") == "stove"
				if is_stove and not is_dress and _exists(STOVE_MODEL, seen):
					scenes[STOVE_MODEL] = true
					keep[STOVE_MODEL] = true
				if not model.is_valid_identifier():
					continue
				var path: String = Interior.MODEL_ROOT + model + ".glb"
				if not is_dress and not is_stove and not _exists(path, seen):
					path = Interior.COMMON_ROOT + model + ".glb"
				if _exists(path, seen):
					scenes[path] = true
					if is_dress:
						dress[model] = true
					else:
						keep[path] = true
	return {"scenes": scenes.keys(), "dress": dress.keys(), "keep": keep.keys()}


func begin(scene: Node, cars: Array) -> void:
	_scene = weakref(scene)
	_began_usec = Time.get_ticks_usec()
	_static_bytes = Performance.get_monitor(Performance.MEMORY_STATIC)
	stats = {"paths": 0, "loaded": 0, "cached": 0, "failed": 0,
		"dress": 0, "ms": 0.0, "static_mb_delta": 0.0,
		"max_step_ms": 0.0, "max_dress_ms": 0.0}
	var options: Dictionary = scene.get("opts")
	if not _enabled(options):
		state = "off"
		return
	_cars = cars
	state = "waiting"


static func _enabled(options: Dictionary) -> bool:
	if options.get("warm") is bool:
		return bool(options["warm"])
	if not FileAccess.file_exists(cfg_path):
		return default_on
	var config := ConfigFile.new()
	if config.load(cfg_path) != OK:
		push_warning("train warm: cannot read %s; using default" % cfg_path)
		return default_on
	var on: Variant = config.get_value("warm", "on", null)
	if not on is bool:
		push_warning("train warm: [warm] on must be a boolean; using default")
		return default_on
	return bool(on)


func step(busy: bool = false) -> void:
	if busy or state == "off" or state == "done" or state == "released":
		return
	var scene: Object = _scene.get_ref()
	if not is_instance_valid(scene):
		release()
		return
	if bool(scene.call("restaging")):
		return
	var began: int = Time.get_ticks_usec()
	_step()
	stats["max_step_ms"] = maxf(float(stats["max_step_ms"]), float(Time.get_ticks_usec() - began) / 1000.0)
	if state == "done":
		_finish()


func _collect_car() -> void:
	var paths: Dictionary = paths_for([_cars[_next_car]], _exists_paths)
	_next_car += 1
	for path: String in paths["scenes"]:
		if not _collected_paths.has(path):
			_collected_paths[path] = true
			_paths.append(path)
	for model: String in paths["dress"]:
		if not _dress_models.has(model):
			_dress_models[model] = true
			_dress.append(model)
	for path: String in paths["keep"]:
		_keep[path] = true
	stats["paths"] = _paths.size()


func _step() -> void:
	if _next_car < _cars.size():
		_collect_car()
		if _wait_frames > 0:
			_wait_frames -= 1
		return
	if _wait_frames > 0:
		_wait_frames -= 1
		return
	state = "loading"
	for path: String in _in_flight.duplicate():
		var status: int = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		var resource: Resource = ResourceLoader.load_threaded_get(path)
		_requests.erase(path)
		_in_flight.erase(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_hold(path, resource, "loaded")
		else:
			stats["failed"] += 1
	# Bound cached work too, so a second visit cannot collect everything in one frame.
	for _slot: int in range(WARM_IN_FLIGHT):
		if _requests.size() >= WARM_IN_FLIGHT or _next_path >= _paths.size():
			break
		var path: String = _paths[_next_path]
		if _requests.has(path):
			break  # Let the old train's reaper collect it before requesting it again.
		_next_path += 1
		if ResourceLoader.has_cached(path):
			_hold(path, load(path), "cached")
		else:
			requested += 1
			# Main load() waits for this same threaded read; it needs that read even without warming.
			if ResourceLoader.load_threaded_request(path) == OK:
				_requests.append(path)
				_in_flight.append(path)
			else:
				stats["failed"] += 1
	if _next_path < _paths.size() or not _in_flight.is_empty():
		return
	# Only touch a dress scene after its PackedScene has been retained.
	if _next_dress < _dress.size():
		var model: String = _dress[_next_dress]
		_next_dress += 1
		var path: String = Interior.MODEL_ROOT + model + ".glb"
		if held.get(path) is PackedScene:
			var had_mesh: bool = Interior._dress_meshes.has(model)
			var began: int = Time.get_ticks_usec()
			var mesh: Mesh = Interior._dress_mesh(model)
			stats["max_dress_ms"] = maxf(float(stats["max_dress_ms"]), float(Time.get_ticks_usec() - began) / 1000.0)
			if not had_mesh:
				_dress_added[model] = mesh
			if mesh != null:
				stats["dress"] += 1
			else:
				stats["failed"] += 1
		if not _keep.has(path):
			held.erase(path)
	if _next_dress == _dress.size():
		state = "done"


func release() -> void:
	if state == "released":
		return
	state = "released"
	for path: String in _in_flight:
		if not _orphans.has(path):
			_orphans.append(path)
	_in_flight.clear()
	held.clear()
	for model: String in _dress_added:
		if Interior._dress_meshes.get(model) == _dress_added[model]:
			Interior._dress_meshes.erase(model)
	_dress_added.clear()
	_cars = []
	_scene = null
	if not _orphans.is_empty():
		_reaper.start(Engine.get_main_loop() as SceneTree, _requests, _orphans)


func _hold(path: String, resource: Resource, counter: String) -> void:
	if resource is PackedScene:
		held[path] = resource
		stats[counter] += 1
	else:
		stats["failed"] += 1


func _finish() -> void:
	stats["ms"] = float(Time.get_ticks_usec() - _began_usec) / 1000.0
	stats["static_mb_delta"] = (Performance.get_monitor(Performance.MEMORY_STATIC) - _static_bytes) / 1048576.0
	print("WARM done paths=%d loaded=%d cached=%d failed=%d dress=%d ms=%.1f static_mb_delta=%.2f max_step_ms=%.3f max_dress_ms=%.3f" % [
		int(stats["paths"]), int(stats["loaded"]), int(stats["cached"]), int(stats["failed"]),
		int(stats["dress"]), float(stats["ms"]), float(stats["static_mb_delta"]),
		float(stats["max_step_ms"]), float(stats["max_dress_ms"])])
