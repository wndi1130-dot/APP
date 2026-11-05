extends "res://addons/gut/test.gd"

const StopLoader = preload("res://game/stop_loader.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const BodyCast = preload("res://game/actors/body_cast.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const Observer = preload("res://tests/game/fixtures/person_prewarm_observer.gd")
const OPTS := {"seed": 7, "arrive": false, "raiders": false, "auto_pause": false}

var saved_settings: Dictionary = {}
var hooks: Array[Callable] = []
var loaders: Array = []


class _VisibleFrames:
	extends Node
	signal finished
	var sample: Callable
	var samples: Array = []

	func _process(_delta: float) -> void:
		samples.append(sample.call())
		if samples.size() == 3:
			set_process(false)
			finished.emit()


func before_each() -> void:
	for key: String in [PersonVisual.SETTING, PersonVisual.BODIES_SETTING]:
		saved_settings[key] = {"exists": ProjectSettings.has_setting(key),
			"value": ProjectSettings.get_setting(key)}
	ProjectSettings.set_setting(PersonVisual.SETTING, true)
	ProjectSettings.set_setting(PersonVisual.BODIES_SETTING, 0)


func after_each() -> void:
	for loader in loaders:
		if is_instance_valid(loader):
			loader.abandon()
	loaders.clear()
	for hook: Callable in hooks:
		if get_tree().node_added.is_connected(hook):
			get_tree().node_added.disconnect(hook)
	hooks.clear()
	for key: String in saved_settings:
		if saved_settings[key]["exists"]:
			ProjectSettings.set_setting(key, saved_settings[key]["value"])
		else:
			ProjectSettings.clear(key)
	saved_settings.clear()


func _start(prepare_ms: int = -1) -> Dictionary:
	var loader := StopLoader.new()
	add_child_autofree(loader)
	loaders.append(loader)
	if prepare_ms >= 0:
		loader.set_meta("_test_person_prewarm_timeout_ms", prepare_ms)
	loader.place = FieldMaps.resolve("")
	loader.seed_for = int(OPTS["seed"])
	loader.band_for = FieldGame.region_for(OPTS)
	loader.data = FieldMaps.build_from(BareLine, loader.band_for)
	assert_eq(loader.data["place_id"], BareLine.PLACE_ID)
	assert_eq(loader.data["place_kind"], "mine")
	assert_eq(loader.data["region_band"], loader.band_for)
	for key: String in ["grid", "levels", "stairs", "spawns", "train", "entries", "entry_gap",
			"platform", "unload", "boarding", "unloading", "anchors"]:
		assert_true(loader.data.has(key), key)
	for key: String in FieldMaps.OPTIONAL:
		assert_true(loader.data.has(key), key)
	loader._state = "ready"
	loader.resting = true
	var holder := Node3D.new()
	add_child_autofree(holder)
	var state := {"loader": loader, "holder": holder, "ready": false,
		"events": [], "failures": [], "ready_snapshot": {}, "ready_frame": -1, "pending_bodies": -1}
	var hook: Callable = func(node: Node) -> void:
		var f = state.get("field", loader.field)
		if not is_instance_valid(f) or node.get_parent() != f:
			return
		state["field"] = f
		if not state.has("paced") and f.pace != null:
			# Force the first build yield without depending on machine speed.
			f.pace.budget_usec = 0
			state["paced"] = true
		if node.get_script() == PersonVisual:
			node.set_script(Observer)
			node.read_events = state["events"]
			state["visual"] = node
	get_tree().node_added.connect(hook)
	hooks.append(hook)
	loader.failed.connect(func(issue: String) -> void: state["failures"].append(issue))
	loader.field_built.connect(func(f: Node) -> void:
		state["ready"] = true
		state["ready_frame"] = Engine.get_process_frames()
		state["ready_snapshot"] = _snapshot(f.people_look)
		assert_false(f.visible)
		assert_true(f.standing_by)
	)
	loader.build_field(holder, OPTS.duplicate())
	var field = loader.field
	state["field"] = field
	assert_not_null(field)
	assert_false(field.is_built)
	field.built.connect(func() -> void:
		assert_false(state["ready"], "the loader must wait beyond the field build")
		var taken: Dictionary = field.people_look.taken.duplicate()
		var pending := 0
		for p in field.squad:
			var body: String = BodyCast.pick(p.pid, p.role, taken)
			if not field.people_look.worn.has(body):
				pending += 1
		state["pending_bodies"] = pending
	)
	return state


func _snapshot(visual) -> Dictionary:
	var bodies := 0
	var garments := 0
	for event: Dictionary in visual.read_events:
		if event["kind"] == "body":
			bodies += 1
		else:
			garments += 1
	var keys := {}
	for body: String in visual.worn:
		keys[body] = (visual.worn[body]["wear"] as Dictionary).keys()
	return {"body_reads": bodies, "garment_reads": garments,
		"bodies": visual.worn.keys(), "garments": keys, "frame": Engine.get_process_frames()}


func _wait_ready(state: Dictionary) -> void:
	var until: int = Time.get_ticks_msec() + 60000
	for frame in 6000:
		if bool(state["ready"]):
			return
		if Time.get_ticks_msec() >= until or not is_instance_valid(state["field"]) or not state["failures"].is_empty():
			break
		assert_false(state["field"].visible)
		assert_true(state["field"].standing_by)
		await get_tree().process_frame
	assert_true(state["ready"], "the loader must finish before the bounded wait ends")


func test_staged_prewarm_yields_before_field_ready() -> void:
	var state := _start()
	await _wait_ready(state)
	if not state["ready"]:
		return
	assert_gt(int(state["pending_bodies"]), 0, "there were cold bodies before preparation")
	var by_frame := {}
	for event: Dictionary in state["events"]:
		if event["preparing"]:
			var frame: int = event["frame"]
			by_frame[frame] = int(by_frame.get(frame, 0)) + 1
	assert_gt(by_frame.size(), 1, "preparation must execute in distinct engine frames")
	for frame: int in by_frame:
		assert_lte(int(by_frame[frame]), PersonVisual.READS_PER_FRAME,
			"body and garment reads share one frame budget")
		assert_lte(frame, int(state["ready_frame"]))
	var snapshot: Dictionary = state["ready_snapshot"]
	assert_gt(int(snapshot["garment_reads"]), 0)
	var after := _snapshot(state["visual"])
	assert_eq(after["body_reads"], snapshot["body_reads"])
	assert_eq(after["garment_reads"], snapshot["garment_reads"])
	assert_eq(after["bodies"], snapshot["bodies"])
	assert_eq_deep(after["garments"], snapshot["garments"])
	var stats: Dictionary = state["loader"].stats
	assert_gt(int(stats.get("person_prewarm_frames", 0)), 1)
	assert_gte(float(stats["field_ms"]), float(stats.get("person_prewarm_ms", 0.0)))
	assert_gte(float(stats["longest_piece_ms"]), float(stats.get("person_prewarm_max_frame_ms", 0.0)))


func test_staged_arrival_first_three_visible_frames_have_no_body_reads() -> void:
	var state := _start()
	await _wait_ready(state)
	if not state["ready"]:
		return
	assert_gt(int(state["pending_bodies"]), 0)
	var visual = state["visual"]
	var before := _snapshot(visual)
	var probe := _VisibleFrames.new()
	probe.process_priority = 200
	probe.sample = func() -> Dictionary: return _snapshot(visual)
	state["holder"].add_child(probe)
	var field = state["field"]
	field.visible = true
	field.go_live()
	await wait_for_signal(probe.finished, 10)
	assert_eq(probe.samples.size(), 3)
	var previous_frame: int = int(before["frame"]) - 1
	for sample: Dictionary in probe.samples:
		assert_gt(int(sample["frame"]), previous_frame)
		previous_frame = sample["frame"]
		assert_eq(int(sample["body_reads"]) - int(before["body_reads"]), 0)
		assert_eq(int(sample["garment_reads"]) - int(before["garment_reads"]), 0)
		assert_eq(sample["bodies"], before["bodies"])
		assert_eq_deep(sample["garments"], before["garments"])


func test_abandoned_field_skips_person_prewarm() -> void:
	var state := _start()
	var field = state["field"]
	assert_false(field.is_built)
	state["loader"].abandon()
	await wait_process_frames(4)
	assert_false(state["ready"])
	assert_false(is_instance_valid(field))
	var extra_reads := 0
	for event: Dictionary in state["events"]:
		if event["preparing"] or event["kind"] == "garment":
			extra_reads += 1
	assert_eq(extra_reads, 0)


func test_abandon_during_person_preparation_stops_further_reads() -> void:
	var state := _start()
	var saw_read := false
	var until: int = Time.get_ticks_msec() + 60000
	for frame in 6000:
		if Time.get_ticks_msec() >= until:
			break
		for event: Dictionary in state["events"]:
			if event["preparing"]:
				saw_read = true
		if saw_read or state["ready"]:
			break
		await get_tree().process_frame
	assert_true(saw_read)
	assert_false(state["ready"])
	state["loader"].abandon()
	var reads: int = state["events"].size()
	await wait_process_frames(3)
	assert_eq(state["events"].size(), reads)
	assert_false(state["ready"])


func test_prewarm_timeout_hands_over_field_and_logs() -> void:
	var probe_visual := PersonVisual.new()
	var supports_preparation: bool = probe_visual.has_method("prepare_step")
	probe_visual.free()
	if not supports_preparation or not OS.is_debug_build():
		pending("requires staged preparation and debug timeout injection")
		return
	var state := _start(0)
	await _wait_ready(state)
	assert_true(state["failures"].is_empty())
	assert_true(state["ready"])
	if not state["ready"]:
		return
	var field = state["field"]
	assert_true(is_instance_valid(field))
	assert_false(field.is_queued_for_deletion())
	assert_same(state["loader"].field, field)
	var stats: Dictionary = state["loader"].stats
	assert_true(bool(stats.get("person_prewarm_late", false)))
	assert_gt(int(stats.get("person_prewarm_left", 0)), 0)
	var line: String = String(stats.get("person_prewarm_late_log", ""))
	assert_true(line.begins_with("PERSON_PREWARM_LATE "))
	var parsed: Variant = JSON.parse_string(line.trim_prefix("PERSON_PREWARM_LATE "))
	assert_true(parsed is Dictionary)
	if not parsed is Dictionary:
		return
	assert_eq(int(parsed["left"]), int(stats["person_prewarm_left"]))
	assert_eq(float(parsed["ms"]), float(stats["person_prewarm_ms"]))
	var visual = state["visual"]
	var before := _snapshot(visual)
	assert_eq(before["bodies"], [""])
	assert_eq(int(before["garment_reads"]), 0)
	assert_gt(int(state["pending_bodies"]), 0)
	var probe := _VisibleFrames.new()
	probe.process_priority = 200
	probe.sample = func() -> Dictionary: return _snapshot(visual)
	state["holder"].add_child(probe)
	field.visible = true
	field.go_live()
	await wait_for_signal(probe.finished, 10)
	assert_eq(probe.samples.size(), 3)
	var previous: Dictionary = before
	for sample: Dictionary in probe.samples:
		assert_lte(int(sample["body_reads"]) - int(previous["body_reads"]), PersonVisual.READS_PER_FRAME)
		assert_eq(sample["bodies"].size() - previous["bodies"].size(), PersonVisual.READS_PER_FRAME)
		previous = sample
	assert_gt(int(previous["body_reads"]) - int(before["body_reads"]), 0)
	assert_true(state["failures"].is_empty())
