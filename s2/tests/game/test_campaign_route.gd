extends "res://addons/gut/test.gd"
## Real fields, ten train boards, and six cuts at the second stop.

const SliceFlow = preload("res://game/slice_flow.gd")
const SliceSave = preload("res://game/sim/slice_save.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const TrainSave = preload("res://game/politics/save_slot.gd")
const TrainAdvance = preload("res://game/train/train_advance.gd")
const RouteState = preload("res://game/train/route_state.gd")
const Catalog = preload("res://game/train/campaign_route.gd")
const StopLoader = preload("res://game/stop_loader.gd")
const ArrivalSheet = preload("res://game/ui/arrival_sheet.gd")
const Boot = preload("res://game/boot.gd")
const STARTS: String = "res://tests/game/fixtures/campaign_starts.json"
const SLICE: String = "user://test_campaign_slice.json"
const TRAIN: String = "user://test_campaign_train.json"
const FIELD: String = "user://test_campaign_field.json"
const RESUME_BOARDS: int = 10
const CUTS: Array[String] = ["entry", "contract", "field", "ended_before_train", "train_before_meta", "receipt"]
var roots: Array = []
var starts: Array = []


class CampaignProbe extends SliceFlow:
	var cut_before_meta: bool = false
	var field_entries: int = 0
	var applied_returns: int = 0
	var real_receipts: Array[String] = []

	func _save_slice() -> bool:
		if cut_before_meta and bool(opts.get("save", false)) and step >= 0:
			return SliceSave.write_train(train_g, String(opts["train_save_path"]))
		return super._save_slice()

	func _start_field() -> void:
		field_entries += 1
		super._start_field()

	func _field_done(said: Dictionary) -> void:
		if said.get("receipt") is Dictionary and is_instance_valid(field) and field.ended:
			real_receipts.append(String(said["receipt"]["receiptId"]))
		super._field_done(said)

	func _apply_return(said: Dictionary) -> bool:
		var before: int = SliceSave.applied_ids(train_g).size()
		var accepted: bool = super._apply_return(said)
		applied_returns += SliceSave.applied_ids(train_g).size() - before
		return accepted


class BootProbe extends Boot:
	var opened: Node = null

	func _start_slice(resume: Dictionary = {}) -> void:
		opened = _make_slice(resume)
		opened.opts["cinema"] = false
		opened.opts["map_threads"] = false
		add_child(opened)
		opened.set_process(false)


func before_each() -> void:
	_clear_slots()
	if starts.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STARTS))
		assert_true(parsed is Array, "S1 generated the campaign starts")
		if parsed is Array:
			starts = parsed


func after_each() -> void:
	for node: Variant in roots:
		if is_instance_valid(node):
			node.free()
	roots.clear()
	_clear_slots()
	await get_tree().process_frame


func _clear_slots() -> void:
	for path: String in [SLICE, TRAIN, FIELD]:
		SliceSave.clear(path)


func _flow(board_index: int = 0, extra: Dictionary = {}) -> CampaignProbe:
	var flow: CampaignProbe = CampaignProbe.new()
	flow.opts = {"mode": "campaign", "save": true, "seed": board_index + 1,
		"run": "campaign_test_%02d" % board_index, "start_board": starts[board_index],
		"cinema": false, "map_threads": false, "still": true,
		"slice_save_path": SLICE, "train_save_path": TRAIN, "field_save_path": FIELD}
	flow.opts.merge(extra, true)
	roots.append(flow)
	add_child(flow)
	flow.set_process(false)
	return flow


func _drop(node: Node) -> void:
	roots.erase(node)
	node.free()


func _pick() -> Dictionary:
	return SliceSave.pick(SLICE, TRAIN, starts[0]["tables"], FIELD)


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _type_gap(saved: Variant, back: Variant, at: String = "g") -> String:
	if typeof(saved) != typeof(back):
		return "%s: %s -> %s" % [at, type_string(typeof(saved)), type_string(typeof(back))]
	if saved is Dictionary:
		for key: Variant in saved:
			if not (back as Dictionary).has(key):
				return "%s.%s: missing" % [at, str(key)]
			var gap: String = _type_gap(saved[key], back[key], "%s.%s" % [at, str(key)])
			if gap != "":
				return gap
		if saved.size() != back.size():
			return at + ": keys differ"
	elif saved is Array:
		if saved.size() != back.size():
			return at + ": length differs"
		for i: int in saved.size():
			var gap: String = _type_gap(saved[i], back[i], "%s[%d]" % [at, i])
			if gap != "":
				return gap
	return ""


func _raw(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		file.store_string(content)
		file.close()


func _record_count(flow: SliceFlow) -> int:
	return (flow.train_g.get("fieldReturns", {}).get("records", []) as Array).size()


func _reach(flow: SliceFlow, wanted: String) -> void:
	for _turn: int in 32:
		if flow.current() == wanted or flow.campaign_error != "":
			break
		if not flow.current() in ["train", "travel"]:
			break
		if SliceFlow.papers_of(flow.train_g):
			flow._take(SliceFlow.pick_first(flow.train_g, flow.train_t))
		flow.train_on()
	assert_eq(flow.campaign_error, "")
	assert_eq(flow.port_error, "")
	assert_eq(flow.current(), wanted)


func _freeze_field(flow: SliceFlow) -> void:
	assert_not_null(flow.field)
	if is_instance_valid(flow.field):
		assert_true(flow.field.is_built)
		flow.field.set_process(false)
		flow.field.set_physics_process(false)


func _play_field(flow: SliceFlow) -> Dictionary:
	var before: int = _record_count(flow)
	var stop: Dictionary = RouteState.current_stop(flow.train_g)
	flow.next()
	assert_eq(flow.current(), "field")
	_freeze_field(flow)
	if not is_instance_valid(flow.field):
		return {}
	assert_eq(flow.contract["placeId"], stop["map"])
	assert_eq(flow.field.opts["place"], stop["map"])
	assert_eq(flow.field.data["place_id"], stop["map"])
	assert_eq(flow.field.data["place_kind"], stop["kind"])
	assert_eq(flow.field.opts["region"], stop["band"])
	assert_eq(flow.field.stop_form, stop["form"])
	flow.field.finish("departed")
	assert_true(flow._returned())
	assert_eq(_record_count(flow), before + 1)
	assert_eq(SliceSave.applied_ids(flow.train_g).size(), before + 1)
	assert_eq(FieldReturn.canonical(flow.field.receipt.to_dict()), FieldReturn.canonical(flow.receipt))
	var receipt: Dictionary = flow.receipt.duplicate(true)
	flow.next()
	assert_eq(flow.current(), "receipt")
	assert_eq((flow.card.find_child("Place", true, false) as Label).text, stop["name"])
	assert_eq(int(flow.card.seg), int(stop["number"]))
	return receipt


func _leave_first(flow: SliceFlow) -> void:
	flow.next()
	assert_eq(flow.current(), "council")
	if flow.train_g["phase"] == "council" and not flow.train_g["council"].get("result") is Dictionary:
		# This is an explicit test vote, through the same key the session uses.
		flow.card.cast()
	flow.next()
	assert_eq(flow.current(), "travel")


func _to_arrival(flow: SliceFlow) -> void:
	_reach(flow, "stop_pick")
	_play_field(flow)
	_leave_first(flow)
	_reach(flow, "arrive")
	assert_true(flow.card is ArrivalSheet)
	assert_eq(flow.card.go_word, "다음")


func _to_second(flow: SliceFlow) -> void:
	_to_arrival(flow)
	flow.next()
	assert_eq(flow.current(), "stop_pick")
	assert_eq(RouteState.current_stop(flow.train_g)["id"], "guben")
	assert_eq((flow.card.find_child("Place", true, false) as Label).text, "구벤")
	assert_eq(_record_count(flow), 1)
	assert_false(flow._returned())


func _finish_second(flow: SliceFlow) -> void:
	if flow.current() == "stop_pick":
		_play_field(flow)
	elif flow.current() == "field":
		_freeze_field(flow)
		if not flow.field.ended:
			flow.field.finish("departed")
		flow.next()
	assert_eq(flow.current(), "receipt")
	flow.next()
	assert_eq(flow.current(), "end")
	assert_eq(flow.title.text, "여기까지 — 다음 정차는 아직")
	assert_ne(flow.train_g.get("end", ""), "slice")
	assert_eq(int(flow.train_g["campaign"]["cursor"]), Catalog.size())
	assert_eq(RouteState.problem(flow.train_g), "")


func test_campaign_uses_ten_distinct_train_boards() -> void:
	assert_eq(starts.size(), 10)
	var seeds: Dictionary = {}
	var rng_states: Dictionary = {}
	var boards: Dictionary = {}
	for i: int in starts.size():
		var state: Dictionary = starts[i]["state"]
		assert_eq(state["seed"], "camp-%02d" % (i + 1))
		seeds[state["seed"]] = true
		rng_states[str(state["rng"]["state"])] = true
		boards[_json(state).sha256_text()] = true
	assert_eq(seeds.size(), 10)
	assert_eq(rng_states.size(), 10)
	assert_eq(boards.size(), 10)
	assert_eq(Catalog.validate(), "")
	assert_eq(Catalog.stop_at(0)["form"], "city")
	assert_eq(Catalog.stop_at(1)["form"], "edge")
	assert_true(Catalog.stop_at(1)["placeholder"])


func test_campaign_two_real_fields_apply_each_return_once() -> void:
	var entries: int = 0
	var returns: int = 0
	var quiet_returns: int = 0
	for i: int in 10:
		var flow: CampaignProbe = _flow(i, {"save": false})
		assert_false(flow.opts.has("skip_field"))
		assert_eq(_record_count(flow), 0)
		assert_eq(SliceSave.applied_ids(flow.train_g).size(), 0)
		_to_second(flow)
		var first_session: String = _json(flow.train_g["fieldReturns"].get("special"))
		_play_field(flow)
		assert_eq(_record_count(flow), 2)
		assert_eq(SliceSave.applied_ids(flow.train_g).size(), 2)
		assert_eq(_json(flow.train_g["fieldReturns"].get("special")), first_session)
		flow.next()
		assert_eq(flow.current(), "end")
		assert_eq(flow.title.text, "여기까지 — 다음 정차는 아직")
		assert_ne(flow.train_g.get("end", ""), "slice")
		entries += flow.field_entries
		returns += flow.applied_returns
		# Every applied id came from an actual FieldGame.finish signal.
		quiet_returns += flow.applied_returns - flow.real_receipts.size()
		for id: String in SliceSave.applied_ids(flow.train_g):
			assert_true(flow.real_receipts.has(id))
		_drop(flow)
	assert_eq(entries, 20)
	assert_eq(returns, 20)
	assert_eq(quiet_returns, 0)


func test_campaign_rejects_wrong_maps() -> void:
	var flow: CampaignProbe = _flow()
	_reach(flow, "stop_pick")
	var before: String = _json(flow.train_g)
	var before_step: int = flow.step
	for map_id: String in ["", "no_such_map", "houses_01"]:
		flow.opts["place"] = map_id
		flow.go(flow._index_of("field"))
		assert_true(flow.campaign_error.begins_with("F-CAMPAIGN-MAP"))
		assert_eq(_json(flow.train_g), before)
		assert_eq(flow.step, before_step)
		assert_eq(_record_count(flow), 0)
		assert_eq(flow.field_entries, 0)
	flow.opts.erase("place")
	for data: Dictionary in [{"place_id": "houses_01", "place_kind": "freight"}, {"place_id": "first_leg_01_sulechow", "place_kind": "houses"}]:
		flow.opts["map_data"] = data
		flow.go(flow._index_of("field"))
		assert_true(flow.campaign_error.begins_with("F-CAMPAIGN-MAP"))
		assert_eq(_json(flow.train_g), before)
		assert_eq(flow.step, before_step)
		assert_eq(flow.field_entries, 0)
	assert_eq(SliceSave.applied_ids(flow.train_g).size(), 0)
	flow.opts.erase("map_data")
	flow.go(-1)
	assert_eq(flow.step, before_step)
	flow.go(flow._index_of("receipt"))
	assert_eq(_json(flow.train_g), before)
	assert_eq(flow.receipt, {})
	assert_eq(flow.result, {})


func _assert_replays_do_not_change(flow: CampaignProbe, receipt: Dictionary, past: Dictionary) -> void:
	var before: String = _json(flow.train_g)
	var before_g: Dictionary = flow.train_g.duplicate(true)
	var before_receipt: String = _json(flow.receipt)
	assert_true(flow._apply_return(receipt.duplicate(true)))
	var changed: Dictionary = receipt.duplicate(true)
	changed["stock"]["food"] = float(changed["stock"].get("food", 0)) + 1.0
	assert_false(flow._apply_return(changed))
	var other: Dictionary = receipt.duplicate(true)
	other["receiptId"] = "ret_other_for_same_visit"
	assert_false(flow._apply_return(other))
	assert_false(flow._apply_return(past))
	assert_eq(_json(flow.train_g), before)
	assert_eq(_type_gap(before_g, flow.train_g), "")
	assert_eq(_json(flow.receipt), before_receipt)
	assert_eq(_record_count(flow), 2)
	assert_eq(SliceSave.applied_ids(flow.train_g).size(), 2)


func test_campaign_return_replay_is_idempotent() -> void:
	var flow: CampaignProbe = _flow()
	_to_second(flow)
	var first_id: String = String(flow.train_g["fieldReturns"]["records"][0]["receiptId"])
	var past: Dictionary = JSON.parse_string(flow.train_g["fieldReturns"]["applied"][first_id])
	var receipt: Dictionary = _play_field(flow)
	_assert_replays_do_not_change(flow, receipt, past)
	assert_true(flow._save_slice())
	_drop(flow)
	var picked: Dictionary = _pick()
	assert_false(picked.is_empty())
	if picked.is_empty():
		return
	var resumed: CampaignProbe = _flow(0, {"resume": picked})
	assert_eq(resumed.current(), "receipt")
	_assert_replays_do_not_change(resumed, receipt, past)
	assert_eq(resumed.applied_returns, 0, "no return was applied again")


func _cut_second(board_index: int, cut: String) -> void:
	var flow: CampaignProbe = _flow(board_index)
	_to_arrival(flow)
	assert_true(flow._begin_campaign_stop())
	assert_eq(flow.contract, {})
	assert_eq(flow.receipt, {})
	assert_eq(flow.result, {})
	assert_false(flow.passed)
	assert_eq(flow.council_g, {})
	assert_eq(flow.arrival_g, {})
	assert_eq(flow.field_resume, {})
	if cut != "entry":
		flow.go(flow._index_of("stop_pick"))
		assert_false(flow.contract.is_empty())
	if cut in ["field", "ended_before_train", "train_before_meta", "receipt"]:
		flow.next()
		_freeze_field(flow)
		flow.field.interrupt()
	if cut == "ended_before_train":
		flow.field.finished.disconnect(Callable(flow, "_field_done"))
		flow.field.finish("departed")
		assert_eq(FieldSave.read(FIELD).get("phase"), "ended")
		assert_false(flow._returned())
	elif cut == "train_before_meta":
		flow.cut_before_meta = true
		flow.field.finish("departed")
		assert_true(flow._returned())
		assert_eq(SliceSave.read(SLICE)["step"], "field")
	elif cut == "receipt":
		flow.field.finish("departed")
		flow.next()
		assert_eq(flow.current(), "receipt")
	_drop(flow)


func test_campaign_second_stop_resume_matches_uninterrupted() -> void:
	var checked: int = 0
	for i: int in RESUME_BOARDS:
		_clear_slots()
		var straight: CampaignProbe = _flow(i, {"save": false})
		_to_second(straight)
		_finish_second(straight)
		var expected: Dictionary = straight.train_g.duplicate(true)
		_drop(straight)
		for cut: String in CUTS:
			_clear_slots()
			_cut_second(i, cut)
			var picked: Dictionary = _pick()
			assert_false(picked.is_empty(), "%s board %d" % [cut, i])
			if picked.is_empty():
				return
			assert_eq(int(picked["g"]["campaign"]["cursor"]), 1)
			var resumed: CampaignProbe = _flow(i, {"resume": picked})
			_finish_second(resumed)
			assert_eq(_json(resumed.train_g), _json(expected), "%s board %d values" % [cut, i])
			assert_eq(_type_gap(expected, resumed.train_g), "", "%s board %d types" % [cut, i])
			assert_eq(_record_count(resumed), 2)
			assert_eq(SliceSave.applied_ids(resumed.train_g).size(), 2)
			_drop(resumed)
			checked += 1
	assert_eq(checked, 60)


func test_campaign_save_identity_and_shape() -> void:
	var flow: CampaignProbe = _flow()
	_to_arrival(flow)
	var old_meta: Dictionary = SliceSave.read(SLICE)
	var old_field: Dictionary = FieldSave.read(FIELD)
	assert_true(flow._begin_campaign_stop())
	var second: Dictionary = flow.train_g.duplicate(true)
	assert_true(SliceSave.write(old_meta, SLICE))
	var torn: Dictionary = _pick()
	assert_true(torn["reconciled"])
	assert_eq(torn["step"], "stop_pick")
	assert_eq(torn["receipt"], {})
	assert_eq(torn["contract"], {})
	assert_false(torn["passed"])
	SliceSave.clear(SLICE)
	var missing: Dictionary = _pick()
	assert_eq(missing["step"], "stop_pick")
	assert_eq(_json(missing["g"]), _json(second))
	assert_false(SliceSave.field_belongs(second, old_field))
	_drop(flow)
	var resumed: CampaignProbe = _flow(0, {"resume": missing})
	assert_eq(resumed.current(), "stop_pick")
	assert_null(resumed.field, "the first stop's field is ignored")
	assert_eq(resumed.receipt, {})
	assert_eq(_record_count(resumed), 1)
	var foreign: Dictionary = old_field.duplicate(true)
	foreign["start_opts"]["slice_run"] = "another_run"
	assert_false(SliceSave.field_belongs(resumed.train_g, foreign))
	foreign = old_field.duplicate(true)
	foreign["place"] = "houses_01"
	assert_false(SliceSave.field_belongs(resumed.train_g, foreign))
	SliceSave.clear(FIELD)
	_raw(FIELD, FieldSave.to_json(foreign))
	assert_eq(_pick()["step"], "stop_pick")
	var meta: Dictionary = SliceSave.capture(resumed)
	meta["contract"] = old_meta["contract"]
	meta["receipt"] = old_meta["receipt"]
	meta["passed"] = true
	assert_true(SliceSave.write(meta, SLICE))
	var recovered: Dictionary = _pick()
	assert_eq(_json(recovered["contract"]), _json(resumed.contract))
	assert_eq(recovered["receipt"], {})
	assert_false(recovered["passed"])
	var good: Dictionary = resumed.train_g.duplicate(true)
	var board_tables: Dictionary = resumed.train_t
	_drop(resumed)
	for change: Dictionary in [{"version": 2}, {"mode": "unknown"}, {"catalog": "unknown"}, {"cursor": -1}, {"cursor": 3}, {"run": "other_run"}, {"visit": []}, {"workshop_done": {}}, {"chosen": {"branch": 0}}]:
		var bad: Dictionary = good.duplicate(true)
		bad["campaign"].merge(change, true)
		assert_ne(RouteState.problem(bad), "")
		assert_not_null(TrainSave.shape_problem(bad, board_tables))
		SliceSave.clear(TRAIN)
		assert_true(SliceSave.write_train(bad, TRAIN))
		assert_eq(_pick(), {}, "invalid route is never adopted")


func test_campaign_passed_stop_advances_without_receipt() -> void:
	for choices: Array in [[true, true], [true, false], [false, true]]:
		_clear_slots()
		var flow: CampaignProbe = _flow()
		_reach(flow, "stop_pick")
		if bool(choices[0]):
			flow._pass_stop()
			assert_eq(_record_count(flow), 0)
			assert_eq(SliceSave.applied_ids(flow.train_g).size(), 0)
			assert_false(flow.train_g.get("fieldReturns", {}).has("special"))
		else:
			_play_field(flow)
			_leave_first(flow)
		assert_eq(flow.current(), "travel")
		_drop(flow)
		var picked: Dictionary = _pick()
		assert_eq(picked["passed"], bool(choices[0]))
		flow = _flow(0, {"resume": picked})
		_reach(flow, "arrive")
		assert_true(flow.card is ArrivalSheet)
		flow.next()
		assert_eq(flow.current(), "stop_pick")
		assert_false(flow.passed, "the new visit has no old pass flag")
		if bool(choices[1]):
			flow._pass_stop()
		else:
			_play_field(flow)
			_drop(flow)
			flow = _flow(0, {"resume": _pick()})
			assert_eq(flow.current(), "receipt")
			flow.next()
		assert_eq(flow.current(), "end")
		var expected: int = (0 if bool(choices[0]) else 1) + (0 if bool(choices[1]) else 1)
		assert_eq(_record_count(flow), expected)
		assert_eq(SliceSave.applied_ids(flow.train_g).size(), expected)
		assert_eq(_pick(), {}, "a completed trial is not resumed")
		assert_ne(flow.train_g.get("end", ""), "slice")
		if bool(choices[0]):
			assert_false(flow.train_g.get("fieldReturns", {}).has("special"))
		_drop(flow)


func test_campaign_departure_workshop_runs_once_after_resume() -> void:
	var flow: CampaignProbe = _flow()
	_reach(flow, "stop_pick")
	_play_field(flow)
	var departure_id: String = String(flow.train_g["campaign"]["visit"]["departure_id"])
	assert_true(RouteState.workshop_due(flow.train_g, departure_id))
	_leave_first(flow)
	assert_eq(flow.train_g["campaign"]["workshop_done"], [departure_id])
	assert_false(RouteState.workshop_due(flow.train_g, departure_id))
	var before: Dictionary = flow.train_g.duplicate(true)
	_drop(flow)
	var resumed: CampaignProbe = _flow(0, {"resume": _pick()})
	assert_eq(resumed.current(), "travel")
	assert_eq(_json(resumed.train_g), _json(before))
	resumed.go(resumed._index_of("travel"))
	resumed._take(resumed.train_g.duplicate(true))
	assert_eq(_json(resumed.train_g), _json(before), "no upkeep or work twice")
	assert_eq(_type_gap(before, resumed.train_g), "")
	assert_eq(resumed.train_g["campaign"]["workshop_done"].size(), 1)
	_reach(resumed, "arrive")
	resumed.next()
	assert_ne(resumed.train_g["campaign"]["visit"]["departure_id"], departure_id)
	assert_eq(resumed.train_g["campaign"]["workshop_done"], [departure_id])


func test_loader_does_not_reuse_another_stop_map() -> void:
	var loader: StopLoader = StopLoader.new()
	loader.threaded = false
	roots.append(loader)
	add_child(loader)
	loader.prepare("first_leg_01_sulechow", 91, "city", -1.0, "visit_a")
	assert_true(loader.has_data())
	assert_eq(loader.data["place_id"], "first_leg_01_sulechow")
	var built: Array = []
	loader.field_built.connect(func(built_game: Node) -> void: built.append(built_game))
	loader.build_field(self, {"place": "houses_01", "visit_id": "visit_b", "campaign_kind": "houses",
		"seed": 91, "stop_form": "edge", "vertices": 96, "cap": 0, "budget": 0})
	for _frame: int in 1800:
		if not built.is_empty() or loader.error != "":
			break
		await get_tree().process_frame
	assert_eq(loader.error, "")
	assert_eq(built.size(), 1)
	if built.is_empty():
		return
	var game: Node = built[0]
	roots.append(game)
	loader.field = null
	assert_eq(loader.place, "houses_01")
	assert_eq(loader.visit_for, "visit_b")
	assert_eq(game.opts["place"], "houses_01")
	assert_eq(game.opts["visit_id"], "visit_b")
	assert_eq(game.data["place_id"], "houses_01")
	assert_eq(game.data["place_kind"], "houses")
	loader.threaded = true
	loader.prepare("first_leg_01_sulechow", 92, "city", -1.0, "visit_c")
	loader._start_task(load("res://game/world/sulehuf_map.gd"))
	var old_generation: int = loader._generation
	loader.prepare("houses_01", 93, "edge", -1.0, "visit_d")
	assert_gt(loader._generation, old_generation)
	loader._take({"place_id": "first_leg_01_sulechow"}, old_generation)
	assert_true(loader.data.is_empty(), "a late old task is ignored")
	for _frame: int in 1800:
		if loader.has_data() or loader.error != "":
			break
		await get_tree().process_frame
	assert_eq(loader.error, "")
	assert_true(loader.has_data())
	assert_eq(loader.place, "houses_01")
	assert_eq(loader.visit_for, "visit_d")
	if loader.has_data():
		assert_eq(loader.data["place_id"], "houses_01")
	var before_place: String = loader.place
	loader.prepare("houses_01", 93, "edge", -1.0, "visit_e")
	assert_eq(loader.place, before_place)
	assert_eq(loader.visit_for, "visit_e", "the same map is a new visit")
	assert_gt(loader._generation, old_generation + 1)


func test_boot_keeps_slice_button_and_resumes_campaign_mode() -> void:
	var boot: BootProbe = BootProbe.new()
	boot.slice_save_path = SLICE
	boot.train_save_path = TRAIN
	boot.field_save_path = FIELD
	roots.append(boot)
	add_child(boot)
	var slice_button: Button = boot.find_child("SliceButton", true, false) as Button
	var campaign_button: Button = boot.find_child("CampaignButton", true, false) as Button
	assert_not_null(slice_button)
	assert_not_null(campaign_button)
	if slice_button != null and campaign_button != null:
		assert_eq(slice_button.text, "슬라이스 흐름(시험)")
		assert_eq(campaign_button.text, "캠페인(두 정차 시험)")
		assert_true(campaign_button.pressed.is_connected(Callable(boot, "_start_campaign")))
	_drop(boot)
	var flow: CampaignProbe = _flow()
	_to_second(flow)
	_drop(flow)
	var resumed_boot: BootProbe = BootProbe.new()
	resumed_boot.slice_save_path = SLICE
	resumed_boot.train_save_path = TRAIN
	resumed_boot.field_save_path = FIELD
	roots.append(resumed_boot)
	add_child(resumed_boot)
	assert_not_null(resumed_boot.opened)
	if resumed_boot.opened != null:
		assert_eq(resumed_boot.opened.opts["mode"], "campaign")
		assert_eq(resumed_boot.opened.current(), "stop_pick")
		assert_eq(RouteState.current_stop(resumed_boot.opened.train_g)["id"], "guben")


func test_campaign_trial_close_keeps_train_and_clears_only_owned_field() -> void:
	var flow: CampaignProbe = _flow()
	_to_second(flow)
	_finish_second(flow)
	var train_text: String = FileAccess.get_file_as_string(TRAIN)
	var foreign: Dictionary = FieldSave.read(FIELD).duplicate(true)
	assert_true(FileAccess.file_exists(SLICE))
	assert_true(FileAccess.file_exists(FIELD))
	flow._campaign_close_slots()
	assert_eq(SliceSave.read(SLICE), {})
	assert_eq(FieldSave.read(FIELD), {})
	assert_eq(FileAccess.get_file_as_string(TRAIN), train_text)
	assert_eq(_pick(), {})
	foreign["start_opts"]["slice_run"] = "other_run"
	_raw(FIELD, FieldSave.to_json(foreign))
	var other_text: String = FileAccess.get_file_as_string(FIELD)
	flow._campaign_close_slots()
	assert_eq(FileAccess.get_file_as_string(FIELD), other_text)
