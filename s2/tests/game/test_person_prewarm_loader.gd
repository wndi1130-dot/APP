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
	var ready_to_sample: Callable
	var samples: Array = []
	var frame_limit := 3

	func _process(_delta: float) -> void:
		if ready_to_sample.is_valid() and not ready_to_sample.call():
			return
		samples.append(sample.call())
		if samples.size() == frame_limit:
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


func _start(prepare_ms: int = -1, options: Dictionary = {}, clock_ms: Callable = Callable(), reuse = null) -> Dictionary:
	var loader = reuse if reuse != null else StopLoader.new()
	if reuse == null:
		add_child_autofree(loader)
		loaders.append(loader)
	else:
		loader.abandon()
		loader._generation += 1
	var options_now := OPTS.duplicate()
	options_now.merge(options, true)
	if prepare_ms >= 0:
		loader.set_meta("_test_person_prewarm_timeout_ms", prepare_ms)
	elif loader.has_meta("_test_person_prewarm_timeout_ms"):
		loader.remove_meta("_test_person_prewarm_timeout_ms")
	if clock_ms.is_valid():
		loader.set_meta("_test_person_prewarm_clock", clock_ms)
	elif loader.has_meta("_test_person_prewarm_clock"):
		loader.remove_meta("_test_person_prewarm_clock")
	loader.place = FieldMaps.resolve("")
	loader.seed_for = int(options_now["seed"])
	loader.band_for = FieldGame.region_for(options_now)
	loader.data = FieldMaps.build_from(BareLine, loader.band_for)
	if bool(options_now["arrive"]):
		loader.data["place_kind"] = "bare_line"
	assert_eq(loader.data["place_id"], BareLine.PLACE_ID)
	assert_eq(loader.data["place_kind"], "bare_line" if bool(options_now["arrive"]) else "mine")
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
		"ready_count": 0, "events": [], "failures": [], "logs": [], "ready_stats": {},
		"ready_snapshot": {}, "ready_frame": -1, "pending_bodies": -1, "build_frames": 0}
	var request_generation: int = loader._generation
	loader.set_meta("_test_person_prewarm_log", func(line: String) -> void: state["logs"].append(line))
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
			node.after_read = func(kind: String) -> void:
				var callback: Variant = state.get("after_read")
				if callback is Callable and callback.is_valid():
					callback.call(kind)
			state["visual"] = node
	get_tree().node_added.connect(hook)
	hooks.append(hook)
	loader.failed.connect(func(issue: String) -> void:
		if loader._generation == request_generation:
			state["failures"].append(issue)
	)
	loader.field_built.connect(func(f: Node) -> void:
		if not is_instance_valid(state.get("field")) or f != state["field"]:
			return
		state["ready_count"] += 1
		state["ready"] = true
		state["ready_frame"] = Engine.get_process_frames()
		state["ready_snapshot"] = _snapshot(f.people_look, f)
		state["ready_stats"] = loader.stats.duplicate(true)
		assert_false(f.visible)
		assert_true(f.standing_by)
	)
	loader.build_field(holder, options_now)
	var field = loader.field
	state["field"] = field
	assert_not_null(field)
	assert_false(field.is_built)
	field.built.connect(func() -> void:
		assert_false(state["ready"], "the loader must wait beyond the field build")
		state["build_frames"] = int(loader.stats.get("frames", 0))
		var taken: Dictionary = field.people_look.taken.duplicate()
		var pending := 0
		for p in field.squad:
			var body: String = BodyCast.pick(p.pid, p.role, taken)
			if not field.people_look.worn.has(body):
				pending += 1
		state["pending_bodies"] = pending
	)
	return state


func _snapshot(visual, field = null) -> Dictionary:
	var bodies := 0
	var garments := 0
	var body_keys: Array = []
	var keys := {}
	var drawn := 0
	var appearance := {"drawn": [], "incomplete": [], "missing": 0, "ambiguous": 0}
	if is_instance_valid(visual):
		if field == null:
			field = visual.game
		for event: Dictionary in visual.read_events:
			if event["kind"] == "body":
				bodies += 1
			else:
				garments += 1
		body_keys = visual.worn.keys()
		for body: String in visual.worn:
			keys[body] = (visual.worn[body]["wear"] as Dictionary).keys()
		for child: Node in visual.get_children():
			if child is MultiMeshInstance3D and child.is_visible_in_tree():
				var mm: MultiMesh = child.multimesh
				drawn += mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		if is_instance_valid(field):
			appearance = Observer.appearance(visual, field.people)
	var visible_people := 0
	if is_instance_valid(field):
		for p in field.people:
			if is_instance_valid(p) and p.visible and p.is_visible_in_tree():
				visible_people += 1
	return {"body_reads": bodies, "garment_reads": garments,
		"bodies": body_keys, "garments": keys, "frame": Engine.get_process_frames(),
		"visible": is_instance_valid(field) and field.is_visible_in_tree(),
		"standing_by": field.standing_by if is_instance_valid(field) else true,
		"visible_people": visible_people, "drawn_instances": drawn,
		"drawn_people": appearance["drawn"], "incomplete_people": appearance["incomplete"],
		"missing_shells": appearance["missing"], "ambiguous_bodies": appearance["ambiguous"]}


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


func _supports_preparation_hooks() -> bool:
	var visual := PersonVisual.new()
	var supported: bool = visual.has_method("prepare_step") and OS.is_debug_build()
	visual.free()
	if not supported:
		pending("requires staged preparation and debug injection")
	return supported


func _missing(visual, field) -> Dictionary:
	var bodies := 0
	var garments := {}
	var people_missing_garments := 0
	for p in field.people.slice(0, PersonVisual.MAX_PEOPLE):
		if not visual.body_by.has(p) or not visual.worn.has(visual.body_by[p]):
			bodies += 1
			continue
		var d: Dictionary = visual.worn[visual.body_by[p]]
		if d["own_draw"] == null:
			continue
		var needs_shell := false
		for look: Dictionary in PersonVisual.looks_on(p) + PersonVisual.bag_on(p):
			if not d["wear"].has(look["shell"]):
				garments[String(d["wear_dir"]).path_join(look["shell"])] = true
				needs_shell = true
		if needs_shell:
			people_missing_garments += 1
	return {"bodies": bodies, "garments": garments.size(), "people": people_missing_garments}


func _wait_preparation_read(state: Dictionary) -> void:
	var until: int = Time.get_ticks_msec() + 60000
	for frame in 6000:
		for event: Dictionary in state["events"]:
			if event["preparing"]:
				return
		if state["ready"] or Time.get_ticks_msec() >= until:
			break
		await get_tree().process_frame
	fail_test("no preparation read before the bounded wait ended")


func test_staged_prewarm_yields_before_field_ready() -> void:
	var state := _start()
	await _wait_ready(state)
	if not state["ready"]:
		return
	assert_eq(state["ready_count"], 1)
	assert_eq(state["failures"].size(), 0)
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
	var state := _start(-1, {"arrive": true})
	await _wait_ready(state)
	if not state["ready"]:
		return
	assert_eq(state["ready_count"], 1)
	assert_eq(state["failures"].size(), 0)
	assert_gt(int(state["pending_bodies"]), 0)
	var visual = state["visual"]
	var field = state["field"]
	assert_gte(float(field.arrive_t), 0.0, "the arrival must actually run")
	var before := _snapshot(visual)
	var probe := _VisibleFrames.new()
	probe.process_priority = 200
	probe.sample = func() -> Dictionary: return _snapshot(visual)
	probe.ready_to_sample = func() -> bool: return field.arrive_t < 0.0
	state["holder"].add_child(probe)
	field.visible = true
	field.go_live()
	await wait_for_signal(probe.finished, 60)
	assert_eq(probe.samples.size(), 3)
	assert_true(field.is_visible_in_tree())
	assert_false(field.standing_by)
	var previous_frame: int = int(before["frame"]) - 1
	for sample: Dictionary in probe.samples:
		assert_true(sample["visible"])
		assert_false(sample["standing_by"])
		assert_gt(int(sample["visible_people"]), 0)
		assert_gt(int(sample["drawn_instances"]), 0)
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
	assert_eq(state["ready_count"], 1)
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


func test_timeout_during_garments_keeps_visible_frame_read_budget() -> void:
	if not _supports_preparation_hooks():
		return
	var clock := {"ms": 0}
	var state := _start(100, {}, func() -> int: return int(clock["ms"]))
	var field = state["field"]
	state["after_read"] = func(kind: String) -> void:
		if kind != "garment" or state["ready"] or int(clock["ms"]) > 0:
			return
		var missing: Dictionary = _missing(state["visual"], field)
		if int(missing["bodies"]) == 0 and int(missing["garments"]) > 1:
			clock["ms"] = 101
	await _wait_ready(state)
	if not state["ready"]:
		return
	var visual = state["visual"]
	var missing := _missing(visual, field)
	assert_eq(missing["bodies"], 0)
	assert_gt(int(missing["garments"]), 1)
	assert_gte(int(missing["people"]), 2, "more than one body is still waiting for shells")
	assert_eq(field.people.size(), 4, "four distinct squad bodies bound this fixture")
	# At most three shells per body, one shell-read slot per frame: twelve
	# frames suffice even if the timeout leaves every shell cold.
	var frame_limit := 12
	assert_lte(int(missing["garments"]), frame_limit)
	for p in field.people:
		assert_lte((PersonVisual.looks_on(p) + PersonVisual.bag_on(p)).size(), 3)
	assert_true(state["loader"].stats.get("person_prewarm_late", false))
	assert_eq(state["ready_count"], 1)
	assert_eq(state["failures"].size(), 0)
	var before := _snapshot(visual)
	var probe := _VisibleFrames.new()
	probe.process_priority = 200
	probe.frame_limit = frame_limit
	probe.sample = func() -> Dictionary: return _snapshot(visual)
	state["holder"].add_child(probe)
	field.visible = true
	field.go_live()
	await wait_for_signal(probe.finished, 60)
	assert_eq(probe.samples.size(), frame_limit)
	var previous: Dictionary = before
	var all_visible_frame := 0
	var frame := 0
	for sample: Dictionary in probe.samples:
		frame += 1
		assert_true(sample["visible"])
		assert_false(sample["standing_by"])
		assert_eq(sample["ambiguous_bodies"], 0)
		assert_eq(sample["missing_shells"], 0, "no drawn person has an uncached shell")
		assert_true(sample["incomplete_people"].is_empty(), "no bare frame after handover")
		assert_eq(int(sample["body_reads"]) - int(previous["body_reads"]), 0)
		assert_lte(int(sample["garment_reads"]) - int(previous["garment_reads"]), PersonVisual.READS_PER_FRAME)
		if sample["drawn_people"].size() == field.people.size() and all_visible_frame == 0:
			all_visible_frame = frame
		previous = sample
	assert_gt(int(previous["garment_reads"]) - int(before["garment_reads"]), 0)
	assert_gt(all_visible_frame, 0, "every person eventually appears fully dressed")
	assert_lte(all_visible_frame, frame_limit, "all four people appear within twelve frames")
	assert_eq(previous["drawn_people"].size(), field.people.size())


func test_last_preparation_step_crossing_deadline_is_reported_late() -> void:
	if not _supports_preparation_hooks():
		return
	var clock := {"ms": 0, "crossed": false}
	var state := _start(100, {}, func() -> int: return int(clock["ms"]))
	state["after_read"] = func(kind: String) -> void:
		if kind != "garment" or state["ready"]:
			return
		var missing: Dictionary = _missing(state["visual"], state["field"])
		if int(missing["bodies"]) == 0 and int(missing["garments"]) == 0:
			clock["ms"] = 101
			clock["crossed"] = true
	await _wait_ready(state)
	if not state["ready"]:
		return
	assert_true(clock["crossed"])
	var stats: Dictionary = state["loader"].stats
	assert_true(stats.get("person_prewarm_late", false))
	assert_eq(stats.get("person_prewarm_log_count", 0), 1)
	assert_eq(state["logs"].size(), 1)
	if state["logs"].size() == 1:
		assert_true(String(state["logs"][0]).begins_with("PERSON_PREWARM_LATE "))
		assert_eq(state["logs"][0], stats["person_prewarm_late_log"])
	assert_eq(stats["person_prewarm_ms"], 101.0)
	assert_eq(stats["person_prewarm_left"], 0)
	assert_eq(state["ready_count"], 1)
	assert_eq(state["failures"].size(), 0)
	assert_eq_deep(_missing(state["visual"], state["field"]), {"bodies": 0, "garments": 0, "people": 0})


func test_current_field_visual_cancellation_has_terminal_outcome() -> void:
	if not _supports_preparation_hooks():
		return
	for action: String in ["replace", "free", "disable"]:
		var state := _start()
		await _wait_preparation_read(state)
		assert_false(state["ready"])
		var field = state["field"]
		var old = field.people_look
		if action == "replace":
			var replacement := Observer.new()
			field.add_child(replacement)
			replacement.setup(field)
			field.people_look = replacement
			old.queue_free()
		elif action == "free":
			old.free()
		else:
			field.pace.on = false
		await _wait_ready(state)
		assert_eq(int(state["ready_count"]) + state["failures"].size(), 1)
		assert_eq(state["ready_count"], 1)
		assert_true(state["loader"].stats.get("person_prewarm_skipped", false))
		assert_eq(state["logs"].size(), 1)
		if state["logs"].size() == 1:
			assert_true(String(state["logs"][0]).begins_with("PERSON_PREWARM_SKIP "))
		state["loader"].abandon()
		assert_null(state["loader"].field)
		await wait_process_frames(2)
		assert_false(is_instance_valid(field))


func test_replaced_generation_does_not_publish_or_update_new_stats() -> void:
	if not _supports_preparation_hooks():
		return
	var a := _start()
	await _wait_preparation_read(a)
	assert_false(a["ready"])
	var a_reads: int = a["events"].size()
	var loader = a["loader"]
	var old_generation: int = loader._generation
	var b := _start(-1, {"seed": 8}, Callable(), loader)
	assert_gt(loader._generation, old_generation)
	await _wait_ready(b)
	if not b["ready"]:
		return
	await wait_process_frames(2)
	assert_eq(a["events"].size(), a_reads)
	assert_eq(a["ready_count"], 0)
	assert_eq(b["ready_count"], 1)
	assert_eq(b["failures"].size(), 0)
	var frames := {}
	for event: Dictionary in b["events"]:
		if event["preparing"]:
			frames[event["frame"]] = true
	assert_gt(frames.size(), 1)
	assert_eq(int(loader.stats["person_prewarm_frames"]), frames.size())
	assert_eq(int(loader.stats["frames"]), int(b["build_frames"]) + frames.size())
	assert_eq_deep(loader.stats, b["ready_stats"])
	var prepared: Dictionary = b["visual"].get("prepare_stats")
	assert_eq(loader.stats["person_prewarm_work_ms"], prepared["work_ms"])
	assert_eq(loader.stats["person_prewarm_max_frame_ms"], prepared["max_frame_ms"])
