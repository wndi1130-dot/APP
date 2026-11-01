extends RefCounted
## Keep future room models alive while the train has no room to rebuild.

const Catalog = preload("res://game/train/train_catalog.gd")
const Interior = preload("res://game/train/train_interior.gd")
const WARM_DELAY_FRAMES: int = 30
const WARM_IN_FLIGHT: int = 2
# Same fallback as train_scene.gd; avoid a circular script preload.
const STOVE_MODEL := "res://models/train_interior/stove.glb"
static var cfg_path := "user://train_warm.cfg"
static var held: Dictionary = {}

var state: String = "off"
var stats: Dictionary = {}
var requested: int = 0
var _scene: WeakRef
var _paths: Array = []
var _dress: Array = []
var _next_path: int = 0
var _next_dress: int = 0
var _in_flight: Array[String] = []
var _wait_frames: int = WARM_DELAY_FRAMES
var _began_usec: int = 0
var _static_bytes: float = 0.0


static func paths_for(defs: Array) -> Dictionary:
	var scenes: Dictionary = {}
	var dress: Dictionary = {}
	for def: Dictionary in defs:
		var id: String = String(def.get("id", ""))
		for row: Dictionary in Catalog.layout(def)["props"]:
			if row.has("cars") and not (row["cars"] as Array).has(id):
				continue
			var home: Array = row.get("home", [0, 3])
			var models: Dictionary = row.get("home_model", {})
			for stage: int in range(4):
				if stage < int(home[0]) or stage > int(home[1]):
					continue
				var model: String = String(models.get(str(stage), row["model"]))
				var is_dress: bool = bool(row.get("dress", false))
				var is_stove: bool = row.get("system", "") == "stove"
				if is_stove and not is_dress and ResourceLoader.exists(STOVE_MODEL):
					scenes[STOVE_MODEL] = true
				if not model.is_valid_identifier():
					continue
				var path: String = Interior.MODEL_ROOT + model + ".glb" \
					if is_dress or is_stove else Interior.model_path(model)
				if ResourceLoader.exists(path):
					scenes[path] = true
					if is_dress:
						dress[model] = true
	return {"scenes": scenes.keys(), "dress": dress.keys()}


func begin(scene: Node, defs: Array) -> void:
	_scene = weakref(scene)
	_began_usec = Time.get_ticks_usec()
	_static_bytes = Performance.get_monitor(Performance.MEMORY_STATIC)
	stats = {"paths": 0, "loaded": 0, "cached": 0, "failed": 0,
		"dress": 0, "ms": 0.0, "static_mb_delta": 0.0}
	var options: Dictionary = scene.get("opts")
	if not _enabled(options):
		state = "off"
		return
	var paths: Dictionary = paths_for(defs)
	_paths = paths["scenes"]
	_dress = paths["dress"]
	stats["paths"] = _paths.size()
	state = "waiting"


static func _enabled(options: Dictionary) -> bool:
	if options.get("warm") is bool:
		return bool(options["warm"])
	if not FileAccess.file_exists(cfg_path):
		return true
	var config := ConfigFile.new()
	if config.load(cfg_path) != OK:
		return true
	return bool(config.get_value("warm", "on", true))


func step() -> void:
	if state == "off" or state == "done":
		return
	var scene: Object = _scene.get_ref()
	if not is_instance_valid(scene) or bool(scene.call("restaging")):
		return
	if _wait_frames > 0:
		_wait_frames -= 1
		return
	state = "loading"
	for path: String in _in_flight.duplicate():
		var status: int = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_hold(path, ResourceLoader.load_threaded_get(path), "loaded")
			_in_flight.erase(path)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			stats["failed"] += 1
			_in_flight.erase(path)
	# Bound cached work too, so a second visit cannot collect everything in one frame.
	for _slot: int in range(WARM_IN_FLIGHT):
		if _in_flight.size() >= WARM_IN_FLIGHT or _next_path >= _paths.size():
			break
		var path: String = _paths[_next_path]
		_next_path += 1
		if ResourceLoader.has_cached(path):
			_hold(path, load(path), "cached")
		else:
			requested += 1
			if ResourceLoader.load_threaded_request(path) == OK:
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
			if Interior._dress_mesh(model) != null:
				stats["dress"] += 1
			else:
				stats["failed"] += 1
	if _next_dress == _dress.size():
		_finish()


func _hold(path: String, resource: Resource, counter: String) -> void:
	if resource is PackedScene:
		held[path] = resource
		stats[counter] += 1
	else:
		stats["failed"] += 1


func _finish() -> void:
	state = "done"
	stats["ms"] = float(Time.get_ticks_usec() - _began_usec) / 1000.0
	stats["static_mb_delta"] = (Performance.get_monitor(Performance.MEMORY_STATIC) - _static_bytes) / 1048576.0
	print("WARM done paths=%d loaded=%d cached=%d failed=%d dress=%d ms=%.1f static_mb_delta=%.2f" % [
		int(stats["paths"]), int(stats["loaded"]), int(stats["cached"]), int(stats["failed"]),
		int(stats["dress"]), float(stats["ms"]), float(stats["static_mb_delta"])])
