extends GutTest
## Run by the calling session. This worktree must not launch Godot or GUT.

const Scene = preload("res://game/train/train_scene.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Catalog = preload("res://game/train/train_catalog.gd")
const Context = preload("res://game/train/train_context.gd")
const TrainLight = preload("res://game/train/train_light.gd")
const TrainDecor = preload("res://game/train/train_decor.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const Dom = preload("res://game/train/train_dom.gd")
const Mods = preload("res://game/train/train_mods.gd")
const MAX_FRAMES: int = 600
const PART_NAMES: Array[String] = ["Interior", "Stove", "StovePipeLow", "StovePipeTop", "Lamp0", "LampPool"]
const ACTIVE_KEYS: Array[String] = ["home_stage", "stove_share", "stove_light", "steam", "lamp",
	"lamp_pool", "lamp_color", "lamp_energy", "lamp_sway"]


func _scene(home: Dictionary) -> Scene:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1688, 780)
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	var s := Scene.new()
	s.rules = Rules.load_default()
	s.rules["train"]["home"] = home
	s.rules["view"]["daytime"] = "night"
	s.opts = {"seed": 7, "panel": false, "baked_people": false, "view_mode": "section"}
	viewport.add_child(s)
	s.set_process(false)  # invoke the same scheduler once at each observed process_frame
	return s


func _frame(s: Scene, budget_usec: int = Scene.RESTAGE_BUDGET_USEC) -> void:
	await get_tree().process_frame
	s._step_restages(budget_usec)


func _drain(s: Scene) -> void:
	var frames: int = 0
	while s.restaging() and frames < MAX_FRAMES:
		await _frame(s)
		frames += 1
	assert_false(s.restaging(), "all queued cars finish within the test's frame limit")


func _request(s: Scene, id: String, target_stage: int) -> void:
	s.rules["train"]["home"][id] = target_stage
	s.apply_rules()


func _active_snapshot(c: Dictionary) -> Dictionary:
	var snapshot: Dictionary = {}
	for key: String in ACTIVE_KEYS:
		snapshot[key] = c.get(key)
	return snapshot


func _assert_pending_hidden(s: Scene, id: String, old_root: Node3D, old_stage: int) -> void:
	assert_eq(int(s.car(id)["home_stage"]), old_stage, "only publication changes the active tier")
	assert_true(old_root.is_visible_in_tree(), "the old room is still effectively visible")
	assert_eq(s.life.rooms[id].root, old_root, "life still owns the complete old room")
	var job: Dictionary = s._restage_jobs[id]
	if is_instance_valid(job["bundle"]):
		var bundle: Node3D = job["bundle"]
		assert_false(bundle.is_visible_in_tree(), "the whole candidate is hidden through its parent")
		assert_false((job["room"].root as Node3D).is_visible_in_tree(), "the candidate Interior is hidden too")
		for child: Node in bundle.get_children():
			if child is Node3D:
				assert_false((child as Node3D).is_visible_in_tree(), "pending stove, lights and pool are hidden")


func _assert_one_room(s: Scene, id: String) -> void:
	var c: Dictionary = s.car(id)
	var car_node: Node3D = c["node"]
	for part: String in PART_NAMES:
		var found: int = car_node.get_children().filter(func(child: Node) -> bool:
			return String(child.name) == part or String(child.name).begins_with("@%s@" % part)).size()
		assert_eq(found, 1, id + ": exactly one " + part)
	assert_eq(car_node.get_children().filter(func(child: Node) -> bool: return child is OmniLight3D).size(), 2,
		id + ": one stove light and one lamp")
	assert_eq(car_node.find_children("PendingRoomDecoration*", "Node3D", true, false).size(), 0,
		id + ": no pending or retired holder remains attached")
	assert_eq((c["shell_top"] as Array).count(c["stove_top"]), 1, "the new upper pipe is registered once")
	for part_node: Node in c["room_nodes"]:
		assert_true(is_instance_valid(part_node), "all published references survive retirement")
		assert_eq(part_node.get_parent(), car_node, "legacy direct-child paths remain usable")
	assert_true((s.life.rooms[id].root as Node3D).is_visible_in_tree())
	assert_eq(s.life.rooms[id].dress.mesh.get_surface_count(), 1, "all dress rows still share one surface")


func _assert_budget(s: Scene) -> void:
	assert_gt((s.restage_stats["frames"] as Array).size(), 0)
	for sample: Dictionary in s.restage_stats["frames"]:
		if bool(sample["forced"]):
			continue
		assert_gt(int(sample["units"]), 0)
		assert_true(int(sample["usec"]) <= int(sample["budget_usec"]) + int(sample["max_unit_usec"]),
			"shared frame work <= budget + its largest indivisible dispatch: " + str(sample))
		assert_true(int(sample["usec"]) <= Scene.RESTAGE_BUDGET_USEC + int(sample["max_unit_usec"]))
		assert_ne(String(sample["max_unit_name"]), "")
		var accounted: int = 0
		for usec: int in (sample["job_usec"] as Dictionary).values():
			accounted += usec
		assert_eq(accounted, int(sample["usec"]), "every car shares one measured span, with no per-car budgets")
	for stats: Dictionary in (s.restage_stats["jobs"] as Dictionary).values():
		assert_gt(int(stats["frames"]), 0)
		assert_gt(int(stats["max_unit_usec"]), 0)
		assert_ne(String(stats["max_unit_name"]), "")


func _after_retirement(s: Scene, ids: Array[String]) -> void:
	for frame_index: int in range(6):
		await get_tree().process_frame
		for id: String in ids:
			_assert_one_room(s, id)
		assert_false(s.restaging(), "no work reappears after retirement frame %d" % frame_index)


func _flow() -> SliceFlow:
	var f := SliceFlow.new()
	f.opts = {"skip_field": true, "cinema": false}
	add_child_autofree(f)
	await get_tree().process_frame
	f.train.set_process(false)
	f.train_g["dom"] = Dom.start()
	f._select("guard", false)
	f.train_g["phase"] = "travel"
	f.paper.set_folded(true)
	return f


func _furnish_guard(f: SliceFlow) -> void:
	var store: Dictionary = TrainDecor.read_store(f.train_g)
	for kind: String in ["chair", "table"]:
		TrainDecor.add_stored(store, kind)
	assert_true(f.open_decor("guard"))
	for kind: String in ["chair", "table"]:
		assert_true(bool(Mods.place(f.train_g, "guard", kind, "floor")["ok"]))
	assert_eq(TrainDecor.tier_of(f.train_g, "guard"), 1)
	f.leave_decor()


func test_request_only_registers_and_equal_targets_coalesce() -> void:
	var s := _scene({"guard": 0})
	var c: Dictionary = s.car("guard")
	var before: Dictionary = _active_snapshot(c)
	var root_before: Node3D = s.life.rooms["guard"].root
	var child_count: int = (c["node"] as Node3D).get_child_count()
	_request(s, "guard", 3)
	assert_true(s.restaging())
	assert_eq(_active_snapshot(c), before)
	assert_eq((c["node"] as Node3D).get_child_count(), child_count, "registration builds no nodes")
	var job: Dictionary = s._restage_jobs["guard"]
	assert_null(job["bundle"])
	assert_eq(int(job["target_stage"]), 3)
	_request(s, "guard", 3)
	assert_eq(String(s._restage_jobs["guard"]["stats_key"]), String(job["stats_key"]))
	assert_eq(s._restage_queue.size(), 1)
	assert_eq((s.restage_stats["jobs"] as Dictionary).size(), 1)
	_assert_pending_hidden(s, "guard", root_before, 0)
	await _drain(s)
	_assert_budget(s)
	await _after_retirement(s, ["guard"])


func test_each_pending_frame_keeps_the_old_room_and_swap_keeps_latest_traces() -> void:
	var s := _scene({"tail1": 0})
	var c: Dictionary = s.car("tail1")
	var before: Dictionary = _active_snapshot(c)
	var old_root: Node3D = s.life.rooms["tail1"].root
	var old_nodes: Array = (c["room_nodes"] as Array).duplicate()
	var completed: Array[String] = []
	s.room_restaged.connect(func(id: String) -> void: completed.append(id))
	_request(s, "tail1", 3)
	# A tiny test budget guarantees that the edit happens after the hidden holder is made.
	await _frame(s, 1)
	assert_true(s.is_car_restaging("tail1"))
	assert_true(is_instance_valid(s._restage_jobs["tail1"]["bundle"]))
	s.life.rooms["tail1"].traces["sacks"]["overturned"] = true
	s.life.rooms["tail1"].traces["sacks"]["scorched"] = true
	var frames: int = 0
	while s.restaging() and frames < MAX_FRAMES:
		_assert_pending_hidden(s, "tail1", old_root, 0)
		assert_eq(_active_snapshot(c), before, "building never publishes any new lighting field")
		await _frame(s)
		frames += 1
	assert_false(s.restaging())
	assert_eq(completed, ["tail1"])
	assert_eq(int(c["home_stage"]), 3)
	assert_ne(s.life.rooms["tail1"].root, old_root)
	assert_true(bool(s.life.rooms["tail1"].traces["sacks"]["overturned"]))
	assert_true(bool(s.life.rooms["tail1"].traces["sacks"]["scorched"]))
	assert_almost_eq((s.life.rooms["tail1"].props["sacks"] as Node3D).rotation.z,
		float(Catalog.tuning("trace_tilt")), 0.0001)
	_assert_one_room(s, "tail1")
	_assert_budget(s)
	await _after_retirement(s, ["tail1"])
	for old_node: Variant in old_nodes:
		assert_false(is_instance_valid(old_node), "retired nodes are reclaimed, not only detached")


func test_three_shared_tier_cars_use_one_frame_budget_and_all_finish() -> void:
	var f: SliceFlow = await _flow()
	var s: Scene = f.train as Scene
	var ids: Array[String] = ["guard", "captain", "dining"]
	var old_roots: Dictionary = {}
	for id: String in ids:
		old_roots[id] = s.life.rooms[id].root
	_furnish_guard(f)
	assert_eq(s._restage_jobs.size(), 3)
	var completed: Array[String] = []
	s.room_restaged.connect(func(id: String) -> void: completed.append(id))
	var calls: int = 0
	while s.restaging() and calls < MAX_FRAMES:
		for id: String in ids:
			if s.is_car_restaging(id):
				_assert_pending_hidden(s, id, old_roots[id], 0)
		await _frame(s)
		calls += 1
	assert_false(s.restaging())
	assert_eq((s.restage_stats["frames"] as Array).size(), calls, "one sample per scheduler frame, not per car")
	assert_eq(completed.size(), 3)
	for id: String in ids:
		assert_eq(completed.count(id), 1)
		assert_eq(int(s.car(id)["home_stage"]), 1)
	_assert_budget(s)
	await _after_retirement(s, ids)


func test_a_new_target_rejects_and_reclaims_the_previous_generation() -> void:
	var s := _scene({"guard": 0})
	var completed: Array[String] = []
	s.room_restaged.connect(func(id: String) -> void: completed.append(id))
	_request(s, "guard", 3)
	await _frame(s, 1)
	var discarded: Dictionary = s._restage_jobs["guard"]
	var pending: Node3D = discarded["bundle"]
	var pending_root: Node3D = discarded["room"].root
	_request(s, "guard", 2)
	assert_eq(String(discarded["stats"]["state"]), "cancelled")
	assert_false(s._valid_restage(discarded))
	assert_false(s._swap_restage(discarded), "a discarded result cannot publish")
	assert_eq(int(s.car("guard")["home_stage"]), 0)
	assert_eq(int(s._restage_jobs["guard"]["target_stage"]), 2)
	await _drain(s)
	assert_eq(completed, ["guard"])
	assert_eq(int(s.car("guard")["home_stage"]), 2)
	await _after_retirement(s, ["guard"])
	assert_false(is_instance_valid(pending))
	assert_false(is_instance_valid(pending_root))


func test_returning_to_the_applied_stage_cancels_without_losing_a_later_request() -> void:
	var s := _scene({"guard": 0})
	var old_root: Node3D = s.life.rooms["guard"].root
	var completed: Array[String] = []
	s.room_restaged.connect(func(id: String) -> void: completed.append(id))
	_request(s, "guard", 3)
	await _frame(s, 1)
	var pending: Node3D = s._restage_jobs["guard"]["bundle"]
	_request(s, "guard", 0)
	assert_false(s.restaging())
	assert_eq(s.life.rooms["guard"].root, old_root)
	assert_eq(completed.size(), 0)
	await _after_retirement(s, ["guard"])
	assert_false(is_instance_valid(pending))
	_request(s, "guard", 1)
	assert_true(s.restaging(), "cancelled work did not advance home_stage")
	s.finish_restage_now()
	assert_eq(int(s.car("guard")["home_stage"]), 1)
	assert_eq(completed, ["guard"])


func test_rebuild_invalidates_before_freeing_the_old_car_nodes() -> void:
	var s := _scene({"guard": 0})
	_request(s, "guard", 3)
	await _frame(s, 1)
	var discarded: Dictionary = s._restage_jobs["guard"]
	var old_car: Node3D = discarded["node"]
	var pending: Node3D = discarded["bundle"]
	var batch: int = s._restage_batch
	s._rebuild_layout()
	s.apply_rules()
	assert_gt(s._restage_batch, batch)
	assert_false(s.restaging())
	assert_false(is_instance_valid(old_car))
	assert_false(s._valid_restage(discarded))
	assert_false(s._swap_restage(discarded))
	assert_eq(String(discarded["stats"]["reason"]), "layout")
	assert_eq(int(s.car("guard")["home_stage"]), 3)
	await _after_retirement(s, ["guard"])
	assert_false(is_instance_valid(pending))


func test_leaving_the_tree_discards_work_and_reentry_uses_a_new_generation() -> void:
	var s := _scene({"guard": 0})
	_request(s, "guard", 3)
	await _frame(s, 1)
	var discarded: Dictionary = s._restage_jobs["guard"]
	var pending: Node3D = discarded["bundle"]
	var old_root: Node3D = s.life.rooms["guard"].root
	var parent: Node = s.get_parent()
	parent.remove_child(s)
	assert_false(s.restaging())
	assert_false(s._valid_restage(discarded))
	assert_false(s._swap_restage(discarded))
	assert_eq(int(s.car("guard")["home_stage"]), 0)
	assert_eq(String(discarded["stats"]["reason"]), "tree_exit")
	parent.add_child(s)
	assert_eq(s.life.rooms["guard"].root, old_root)
	s.apply_rules()
	assert_true(s.restaging())
	assert_ne(String(s._restage_jobs["guard"]["stats_key"]), String(discarded["stats_key"]))
	await _drain(s)
	await _after_retirement(s, ["guard"])
	assert_false(is_instance_valid(pending))


func test_car_node_identity_rejects_a_result_even_with_matching_ids_and_generations() -> void:
	var s := _scene({"guard": 0})
	var c: Dictionary = s.car("guard")
	var original: Node3D = c["node"]
	_request(s, "guard", 3)
	await _frame(s, 1)
	var discarded: Dictionary = s._restage_jobs["guard"]
	var pending: Node3D = discarded["bundle"]
	var replacement := Node3D.new()
	s.train.add_child(replacement)
	c["node"] = replacement
	assert_false(s._valid_restage(discarded))
	assert_false(s._swap_restage(discarded))
	await _frame(s)
	c["node"] = original
	replacement.queue_free()
	assert_false(s.restaging())
	assert_eq(int(c["home_stage"]), 0)
	await _after_retirement(s, ["guard"])
	assert_false(is_instance_valid(pending))


func test_reopening_waits_and_retries_once_in_the_swap_frame() -> void:
	var f: SliceFlow = await _flow()
	var s: Scene = f.train as Scene
	_furnish_guard(f)
	var old_root: Node3D = s.life.rooms["guard"].root
	var stats_key: String = String(s._restage_jobs["guard"]["stats_key"])
	assert_false(f.open_decor("guard"))
	assert_false(f.open_decor("guard"), "repeated taps coalesce into the same wait")
	assert_eq(String(s._restage_jobs["guard"]["stats_key"]), stats_key, "reopen does not drain or restart the latest build")
	assert_eq(f.decor_id, "")
	assert_null(f.decor_pane)
	assert_true(old_root.is_visible_in_tree())
	var frames: int = 0
	while s.is_car_restaging("guard") and frames < MAX_FRAMES:
		await _frame(s)
		frames += 1
	assert_false(s.is_car_restaging("guard"))
	assert_eq(f.decor_id, "guard", "the callback opens in this scheduler call, with no deferred frame")
	assert_eq(s.decorating(), "guard")
	assert_true(f._decor_restage_wait.is_empty())
	var pane_before: Control = f.decor_pane
	f._on_decor_room_restaged("guard")
	assert_eq(f.decor_pane, pane_before, "the consumed wait cannot open twice")
	await _drain(s)
	f.leave_decor()
	await _after_retirement(s, ["guard", "captain", "dining"])


func test_another_car_opens_immediately_and_cancels_the_old_reopen_intent() -> void:
	var f: SliceFlow = await _flow()
	var s: Scene = f.train as Scene
	_furnish_guard(f)
	assert_false(f.open_decor("guard"))
	assert_true(f.open_decor("front"), "an unrelated complete room is immediately editable")
	assert_true(f._decor_restage_wait.is_empty())
	await _drain(s)
	assert_eq(f.decor_id, "front", "guard completion cannot steal another car's editor")
	assert_eq(s.decorating(), "front")
	s.exit_decor()  # schedules closing the old front pane on a deferred callback
	f.leave_decor()
	assert_true(f.open_decor("guard"))
	await get_tree().process_frame
	assert_eq(f.decor_id, "guard", "an old deferred close cannot close the newly opened pane")
	assert_eq(s.decorating(), "guard")
	f.leave_decor()
	await _after_retirement(s, ["guard", "captain", "dining"])


func test_leaving_while_waiting_cancels_the_retry_but_finishes_hidden_work() -> void:
	var f: SliceFlow = await _flow()
	var s: Scene = f.train as Scene
	_furnish_guard(f)
	assert_false(f.open_decor("guard"))
	f.leave_decor()
	assert_true(f._decor_restage_wait.is_empty())
	assert_true(s.is_car_restaging("guard"))
	await _drain(s)
	assert_eq(f.decor_id, "")
	assert_eq(s.decorating(), "")
	await _after_retirement(s, ["guard", "captain", "dining"])


func test_reverting_the_waited_target_does_not_open_on_a_later_unrelated_completion() -> void:
	var f: SliceFlow = await _flow()
	var s: Scene = f.train as Scene
	_furnish_guard(f)
	assert_false(f.open_decor("guard"))
	_request(s, "guard", 0)
	assert_false(s.is_car_restaging("guard"))
	assert_true(f._decor_restage_wait.is_empty(), "a cancelled target cannot leave a dormant editor retry")
	await _drain(s)
	_request(s, "guard", 1)
	await _drain(s)
	assert_eq(f.decor_id, "")
	assert_eq(s.decorating(), "")
	await _after_retirement(s, ["guard", "captain", "dining"])


func test_layout_and_tree_exit_cancel_pending_editor_callbacks() -> void:
	for reason: String in ["layout", "tree_exit"]:
		var f: SliceFlow = await _flow()
		var s: Scene = f.train as Scene
		_furnish_guard(f)
		await _frame(s, 1)
		assert_false(f.open_decor("guard"))
		if reason == "layout":
			s._rebuild_layout()
		else:
			var parent: Node = s.get_parent()
			parent.remove_child(s)
			parent.add_child(s)
		assert_true(f._decor_restage_wait.is_empty(), reason + ": no callback survives the old lifetime")
		s.apply_rules()
		await _drain(s)
		assert_eq(f.decor_id, "")
		assert_eq(s.decorating(), "")
		await _after_retirement(s, ["guard", "captain", "dining"])


func test_swap_uses_latest_context_view_easing_and_the_actual_reseat_time() -> void:
	var s := _scene({"guard": 0})
	s.room_ease = 3.0
	s.room_lead = 0.75
	_request(s, "guard", 3)
	await _frame(s, 1)
	var c: Dictionary = s.car("guard")
	c["reseat_at"] = 0.0
	s._step_reseat()
	assert_true(c.has("reseat_at"), "even an overdue reseat waits for the replacement")
	s.rules["view"]["daytime"] = "day"
	s.rules["view"]["motion"] = "stopped"
	s.rules["train"]["coal"] = 0.0
	s.apply_rules()
	s.set_view_mode("section")
	s.clock = 50.0
	var visible_look: Dictionary = (c["room_vis"] as Dictionary).duplicate()
	s.finish_restage_now()
	assert_false(s.restaging())
	assert_eq((s.life.rooms["guard"].root as Node3D).get_meta("context"), Context.read(s.rules, c["def"]))
	assert_eq(c["room_vis"], visible_look, "room_ease keeps the current appearance, not its old start point")
	assert_almost_eq(float(c["reseat_at"]), 50.75, 0.0001)
	assert_almost_eq((c["stove_light"] as OmniLight3D).light_energy, 0.0, 0.0001, "latest coal context wins")
	assert_false((c["steam"] as GPUParticles3D).emitting)
	assert_almost_eq(float(c["lamp_sway"]), float(Catalog.tuning("stopped_sway")), 0.0001)
	assert_almost_eq((c["lamp"] as OmniLight3D).omni_range, float(TrainLight.spec(3, "day")["lamps"][0]["range"]), 0.0001)
	assert_true((c["stove_top"] as Node3D).visible, "latest section view shows the new upper pipe")
	assert_true(s.life.rooms["guard"].dress.visible)
	assert_true((c["lamp_pool"] as Node3D).visible)
	assert_true(s.enter_decor("guard"))
	s.step(1.0)
	assert_true(c.has("reseat_at"), "a same-frame reopen protects the editor's existing people")
	s.exit_decor()
	s._step_reseat()
	assert_false(c.has("reseat_at"))
	await _after_retirement(s, ["guard"])
