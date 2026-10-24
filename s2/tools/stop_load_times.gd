extends SceneTree
## How long a stop's field takes to come up, map by map (정차 연출, 결정 421-3).
## "whole": the field built in one go, as the slice did before (FieldGame added
## in one frame), its pieces timed apart too. "staged": the map built off the
## main thread (stop_loader.gd), then the field over frames, the camera moving
## for the first MOVING_S seconds and at rest after (the slice's budgets).
## Run with a window to see frames as they are drawn:
##   Godot --path s2 --script res://tools/stop_load_times.gd -- --mode whole,staged --places a,b,c

const FieldMaps = preload("res://game/world/field_maps.gd")
const MapView = preload("res://game/world/map_view.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const FieldGame = preload("res://game/field_game.gd")
const StopLoader = preload("res://game/stop_loader.gd")
const StopCinema = preload("res://game/stop_cinema.gd")

## The camera moves from the send for at least the brakes and the way down.
const MOVING_S: float = StopCinema.BRAKE_MIN_S + StopCinema.DOWN_S

var places: Array = ["first_leg_01_sulechow", "freight_02", "hospital_02", "houses_01", "mine_01"]
var modes: Array = ["whole", "staged"]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--places" and i + 1 < args.size():
			places = Array(args[i + 1].split(","))
		if args[i] == "--mode" and i + 1 < args.size():
			modes = Array(args[i + 1].split(","))
	_run.call_deferred()


func _ms(from_us: int) -> float:
	return snappedf(float(Time.get_ticks_usec() - from_us) / 1000.0, 0.1)


func _run() -> void:
	# Warm what every stop shares (the dead's baked bodies, the shaders' first
	# load) on a throwaway map so the first place is not charged for it.
	var warm = FieldGame.new()
	warm.opts = {"place": "freight_01", "seed": 1, "arrive": false}
	root.add_child(warm)
	await process_frame
	warm.queue_free()
	await process_frame
	for mode: String in modes:
		for place: String in places:
			var r: Dictionary = {}
			if mode == "whole":
				r = await _whole(place)
			else:
				r = await _staged(place)
			r["mode"] = mode
			r["place"] = place
			print("ROW ", JSON.stringify(r))
			await process_frame
			await process_frame
	quit(0)


func _whole(place: String) -> Dictionary:
	var r := {}
	var t0: int = Time.get_ticks_usec()
	var script: Script = load(FieldMaps.path_of(FieldMaps.resolve(place)))
	r["load_ms"] = _ms(t0)
	t0 = Time.get_ticks_usec()
	var data: Dictionary = FieldMaps.build_from(script)
	r["data_ms"] = _ms(t0)
	var view = MapView.new()
	root.add_child(view)
	t0 = Time.get_ticks_usec()
	view.setup(data)
	r["view_ms"] = _ms(t0)
	view.queue_free()
	await process_frame
	var f = FieldGame.new()
	f.opts = {"place": place, "seed": 1, "arrive": false}
	t0 = Time.get_ticks_usec()
	root.add_child(f)
	r["field_ms"] = _ms(t0)
	r["longest_frame_ms"] = r["field_ms"]
	var frames: Array = []
	var last: int = Time.get_ticks_usec()
	for k in 4:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(snappedf(float(now - last) / 1000.0, 0.1))
		last = now
	r["frames_after_ms"] = frames
	f.queue_free()
	return r


func _staged(place: String) -> Dictionary:
	var r := {}
	var loader = StopLoader.new()
	root.add_child(loader)
	var t0: int = Time.get_ticks_usec()
	loader.prepare(place)
	var longest_wait: float = 0.0
	var last: int = Time.get_ticks_usec()
	while not loader.has_data():
		await process_frame
		var now: int = Time.get_ticks_usec()
		longest_wait = maxf(longest_wait, float(now - last) / 1000.0)
		last = now
	r["data_ms"] = _ms(t0)
	r["longest_frame_while_data_ms"] = snappedf(longest_wait, 0.1)
	t0 = Time.get_ticks_usec()
	var holder := Node3D.new()
	root.add_child(holder)
	loader.build_field(holder, {"seed": 1, "arrive": false})
	var frames: Array = []
	last = Time.get_ticks_usec()
	while loader.field == null or not loader.field.is_built:
		loader.resting = float(Time.get_ticks_usec() - t0) / 1000000.0 >= MOVING_S
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
	r["field_ms"] = _ms(t0)
	var moving: Array = []
	var resting: Array = []
	var at: float = 0.0
	for ms: float in frames:
		at += ms
		(moving if at <= MOVING_S * 1000.0 else resting).append(ms)
	r["frames"] = frames.size()
	r["longest_frame_ms"] = snappedf(frames.max() if not frames.is_empty() else 0.0, 0.1)
	r["longest_moving_ms"] = snappedf(moving.max() if not moving.is_empty() else 0.0, 0.1)
	r["longest_resting_ms"] = snappedf(resting.max() if not resting.is_empty() else 0.0, 0.1)
	var over: int = 0
	for ms: float in frames:
		if ms > 50.0:
			over += 1
	r["frames_over_50ms"] = over
	r["longest_piece_ms"] = snappedf(float(loader.field.pace.longest_usec) / 1000.0, 0.1)
	holder.queue_free()
	loader.queue_free()
	return r
