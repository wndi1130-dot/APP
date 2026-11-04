extends "res://addons/gut/test.gd"
## Real fields, ten train boards, and six cuts at the second stop.

const SliceFlow = preload("res://game/slice_flow.gd")
const SliceSave = preload("res://game/sim/slice_save.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const FieldReceipt = preload("res://game/sim/receipt.gd")
const TrainSave = preload("res://game/politics/save_slot.gd")
const TrainAdvance = preload("res://game/train/train_advance.gd")
const RouteState = preload("res://game/train/route_state.gd")
const Catalog = preload("res://game/train/campaign_route.gd")
const StopLoader = preload("res://game/stop_loader.gd")
const ArrivalSheet = preload("res://game/ui/arrival_sheet.gd")
const Boot = preload("res://game/boot.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const STARTS: String = "res://tests/game/fixtures/campaign_starts.json"
const SLICE: String = "user://test_campaign_slice.json"
const TRAIN: String = "user://test_campaign_train.json"
const FIELD: String = "user://test_campaign_field.json"
const RESUME_BOARDS: int = 10
const CUTS: Array[String] = ["entry", "contract", "field", "ended_before_train", "train_before_meta", "receipt"]
var roots: Array = []
var starts: Array = []
## Each board's two stops played through without a break or a save, once for the script
## (_straight_run): board index -> the train at the end and what the run counted.
var straight: Dictionary = {}


class CampaignProbe extends SliceFlow:
	## The stops' maps as FieldMaps.build makes them, once for the script: a stop's map is a
	## function of its place and band, and the second stop's took seconds on the runner each time.
	static var built_maps: Dictionary = {}
	var cut_before_meta: bool = false
	var field_entries: int = 0
	var applied_returns: int = 0
	var real_receipts: Array[String] = []
	## Called once as the field's end reaches the train, before the train takes it in.
	var before_return: Callable = Callable()

	## The field step makes its map with FieldMaps.build (slice_flow.gd go); here it is handed a
	## copy of the one built for the script instead, unless the test asks for its own map.
	func go(i: int) -> void:
		var lent: bool = _is_campaign() and i >= 0 and i < STEPS.size() and String(STEPS[i][0]) == "field" \
			and not opts.has("map_data") and not opts.has("place") and not is_instance_valid(pending_field)
		if lent:
			opts["map_data"] = lend_map(_field_place(), _stop_band(_field_seg()))
		super.go(i)
		if lent:
			opts.erase("map_data")

	static func lend_map(place: String, band: String) -> Dictionary:
		var key: String = place + "|" + band
		if not built_maps.has(key):
			built_maps[key] = FieldMaps.build(place, band)
		return copy_map(built_maps[key])

	## A map the field may change as its own: Dictionary.duplicate does not copy the grids
	## (FieldGrid objects), so each is copied once and put back wherever it stood.
	static func copy_map(data: Dictionary) -> Dictionary:
		var out: Dictionary = data.duplicate(true)
		_own_grids(out, {})
		return out

	static func _own_grids(v: Variant, copies: Dictionary) -> void:
		if v is Dictionary:
			for key: Variant in (v as Dictionary).keys():
				if v[key] is FieldGrid:
					v[key] = _grid_copy(v[key], copies)
				else:
					_own_grids(v[key], copies)
		elif v is Array:
			for i: int in (v as Array).size():
				if v[i] is FieldGrid:
					v[i] = _grid_copy(v[i], copies)
				else:
					_own_grids(v[i], copies)

	static func _grid_copy(source: FieldGrid, copies: Dictionary) -> FieldGrid:
		var id: int = source.get_instance_id()
		if copies.has(id):
			return copies[id]
		var g := FieldGrid.new(source.width, source.height)
		for prop: Dictionary in source.get_property_list():
			if not int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				continue
			var value: Variant = source.get(prop["name"])
			if value is AStarGrid2D:
				continue
			if value is Dictionary or value is Array:
				value = value.duplicate(true)
			elif typeof(value) >= TYPE_PACKED_BYTE_ARRAY:
				value = value.duplicate()
			g.set(prop["name"], value)
		# The path grids from the walk caches, as a grown grid takes them (field_grid.gd adopt_paths);
		# that counts as a change there, and the copy keeps the source's count (saves carry it).
		if source.paths_ready():
			g.adopt_paths()
		g.revision = source.revision
		copies[id] = g
		return g

	func _save_slice() -> bool:
		if cut_before_meta and bool(opts.get("save", false)) and step >= 0:
			return SliceSave.write_train(train_g, String(opts["train_save_path"]))
		return super._save_slice()

	func _start_field() -> void:
		field_entries += 1
		super._start_field()

	func _field_done(said: Dictionary) -> void:
		if before_return.is_valid():
			var hook: Callable = before_return
			before_return = Callable()
			hook.call()
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


## A train board as its slot writes it (save_slot.gd slot_board): a supplies run is
## written as slot version 3 whatever version the board in hand carries, and a board
## read back carries the 3. Boards kept, read back or never cut are held side by side in
## the written form; anything else is itself. That puts the number read back out of these
## comparisons: `_version_gap` checks it.
func _slot(value: Variant) -> Variant:
	return TrainSave.slot_board(value) if value is Dictionary else value


## The slot version a board read back carries, against what slot_board writes for the board
## in hand, value and type (a supplies run's int 3), before `_slot` puts both in the written
## form. A train slot written without slot_board reads back as the board in hand and shows here.
func _version_gap(kept: Dictionary, back: Dictionary) -> String:
	var want: Variant = TrainSave.slot_board(kept).get("version")
	var got: Variant = back.get("version")
	if typeof(want) != typeof(got) or want != got:
		return "version: %s %s -> %s %s" % [type_string(typeof(want)), str(want), type_string(typeof(got)), str(got)]
	return ""


func _type_gap(saved: Variant, back: Variant, at: String = "g") -> String:
	if at == "g":
		saved = _slot(saved)
		back = _slot(back)
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


## The first place where a board read back from a save differs from the one kept in memory, or "".
## Types and every other value must match exactly; a float may come back one last bit off
## (Godot's JSON reader rounds some 17-digit numbers the other way), so floats match to 1e-12.
func _board_gap(kept: Variant, back: Variant, at: String = "g") -> String:
	if at == "g":
		kept = _slot(kept)
		back = _slot(back)
	if typeof(kept) != typeof(back):
		return "%s: %s -> %s" % [at, type_string(typeof(kept)), type_string(typeof(back))]
	if kept is Dictionary:
		if kept.size() != back.size():
			return at + ": keys differ"
		for key: Variant in kept:
			if not (back as Dictionary).has(key):
				return "%s.%s: missing" % [at, str(key)]
			var gap: String = _board_gap(kept[key], back[key], "%s.%s" % [at, str(key)])
			if gap != "":
				return gap
	elif kept is Array:
		if kept.size() != back.size():
			return at + ": length differs"
		for i: int in kept.size():
			var gap: String = _board_gap(kept[i], back[i], "%s[%d]" % [at, i])
			if gap != "":
				return gap
	elif kept is float:
		var a: float = kept
		var b: float = back
		if absf(a - b) > 1e-12 * maxf(1.0, absf(a)):
			return "%s: %s -> %s" % [at, str(a), str(b)]
	elif kept != back:
		return "%s: %s -> %s" % [at, str(kept), str(back)]
	return ""


## Waits until `done` says so, up to `seconds` (a field build takes many frames on a slow runner).
func _wait_until(done: Callable, seconds: float = 60.0) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not bool(done.call()) and Time.get_ticks_msec() < until:
		await get_tree().process_frame


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


## The first place where two maps differ, or "": values and types as _board_gap, a grid by its
## fields and both path grids cell by cell, and a grid that stands in two places in one map
## (grid and levels[0]) stands in the same two in the other.
func _map_gap(a: Variant, b: Variant) -> String:
	return _map_gap_at(a, b, "m", {})


func _map_gap_at(a: Variant, b: Variant, at: String, seen: Dictionary) -> String:
	if typeof(a) != typeof(b):
		return "%s: %s -> %s" % [at, type_string(typeof(a)), type_string(typeof(b))]
	if a is FieldGrid:
		var id: int = (a as Object).get_instance_id()
		if seen.has(id):
			return "" if is_same(seen[id], b) else at + ": shared grid split"
		if not b is FieldGrid:
			return at + ": not a grid"
		seen[id] = b
		for prop: Dictionary in (a as Object).get_property_list():
			if not int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				continue
			var name: String = prop["name"]
			if a.get(name) is AStarGrid2D:
				var pa: AStarGrid2D = a.get(name)
				var pb: AStarGrid2D = b.get(name)
				if pa.region != pb.region:
					return "%s.%s: region" % [at, name]
				for y: int in range(pa.region.position.y, pa.region.end.y):
					for x: int in range(pa.region.position.x, pa.region.end.x):
						var c := Vector2i(x, y)
						if pa.is_point_solid(c) != pb.is_point_solid(c) or pa.get_point_weight_scale(c) != pb.get_point_weight_scale(c):
							return "%s.%s: cell %s" % [at, name, str(c)]
			elif a.get(name) != b.get(name):
				return "%s.%s: differs" % [at, name]
		return ""
	if a is Object:
		return at + ": an object the map copy does not know: " + (a as Object).get_class()
	if a is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return at + ": keys differ"
		for key: Variant in a:
			if not (b as Dictionary).has(key):
				return "%s.%s: missing" % [at, str(key)]
			# How long the yard dressing took (yard_dress.gd): a clock reading, other on every build.
			if key is String and key == "yard_dress_ms":
				continue
			var gap: String = _map_gap_at(a[key], b[key], "%s.%s" % [at, str(key)], seen)
			if gap != "":
				return gap
		return ""
	if a is Array:
		if (a as Array).size() != (b as Array).size() or not (a as Array).is_same_typed(b):
			return at + ": length or type differs"
		for i: int in (a as Array).size():
			var gap: String = _map_gap_at(a[i], b[i], "%s[%d]" % [at, i], seen)
			if gap != "":
				return gap
		return ""
	return "" if a == b else "%s: %s -> %s" % [at, str(a), str(b)]


func test_campaign_shared_maps_match_fresh_builds() -> void:
	for i: int in Catalog.size():
		var stop: Dictionary = Catalog.stop_at(i)
		var lent: Dictionary = CampaignProbe.lend_map(stop["map"], stop["band"])
		assert_eq(_map_gap(FieldMaps.build(stop["map"], stop["band"]), lent), "", "%s is lent as built" % stop["map"])
		# A copy is the field's own: what one field does to it is not in the next one.
		var grid: FieldGrid = lent["grid"]
		assert_true(is_same(grid, lent["levels"][0]))
		grid.revision += 1
		lent["containers"].clear()
		var again: Dictionary = CampaignProbe.lend_map(stop["map"], stop["band"])
		assert_false(is_same(again["grid"], grid))
		assert_eq(_map_gap(CampaignProbe.built_maps[stop["map"] + "|" + stop["band"]], again), "", "%s: the next copy is as built" % stop["map"])
		assert_ne(_map_gap(lent, again), "", "%s: the changed copy is changed" % stop["map"])


## Board i played through both stops without a break or a save; kept for the script, so the
## resume test compares its cuts against the same runs this one checks.
func _straight_run(i: int) -> Dictionary:
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
	assert_eq(int(flow.train_g["campaign"]["cursor"]), Catalog.size())
	assert_eq(RouteState.problem(flow.train_g), "")
	# Every applied id came from an actual FieldGame.finish signal.
	for id: String in SliceSave.applied_ids(flow.train_g):
		assert_true(flow.real_receipts.has(id))
	var run: Dictionary = {"g": flow.train_g.duplicate(true), "entries": flow.field_entries,
		"returns": flow.applied_returns, "quiet": flow.applied_returns - flow.real_receipts.size()}
	_drop(flow)
	straight[i] = run
	return run


func test_campaign_two_real_fields_apply_each_return_once() -> void:
	var entries: int = 0
	var returns: int = 0
	var quiet_returns: int = 0
	for i: int in 10:
		var run: Dictionary = _straight_run(i)
		entries += int(run["entries"])
		returns += int(run["returns"])
		quiet_returns += int(run["quiet"])
	assert_eq(entries, 20)
	assert_eq(returns, 20)
	assert_eq(quiet_returns, 0)


func test_campaign_symbol_return_reaches_second_stop_without_second_session() -> void:
	var flow: CampaignProbe = _flow()
	_reach(flow, "stop_pick")
	flow.next()
	_freeze_field(flow)
	if not is_instance_valid(flow.field):
		return
	var carrier: String = String(flow.contract["roster"][0]["id"])
	flow.field.receipt.add_stock("symbol", 1)
	assert_true(flow.field.receipt.set_extras(1, [], 0))
	assert_true(flow.field.receipt.set_symbol("sym_tail_kettle", "tail", carrier))
	flow.field.finish("departed")
	assert_true(FieldReceipt.check(flow.receipt).is_empty())
	assert_true(flow._returned())
	assert_eq(_record_count(flow), 1)
	assert_null(flow.train_g["fieldReturns"]["records"][0]["symbol"]["use"])
	var sessions_before: int = int(flow.train_g["session"])
	flow.next()
	assert_eq(flow.current(), "receipt")
	flow.next()
	assert_eq(flow.current(), "council")
	assert_eq(flow.campaign_error, "")
	assert_eq(flow.train_g["phase"], "council")
	assert_eq(int(flow.train_g["session"]), sessions_before + 1)
	assert_eq(flow.train_g["fieldReturns"]["records"][0]["symbol"]["use"], "hang_before_session")
	var before_reopen: String = _json(flow.train_g)
	assert_true(flow._open_session())
	assert_eq(_json(flow.train_g), before_reopen, "the symbol is used once")
	assert_eq(_pick()["g"]["fieldReturns"]["records"][0]["symbol"]["use"], "hang_before_session")
	if flow.train_g["phase"] == "council" and not flow.train_g["council"].get("result") is Dictionary:
		flow.card.cast()
	flow.next()
	assert_eq(flow.current(), "travel")
	_reach(flow, "arrive")
	flow.next()
	assert_eq(flow.current(), "stop_pick")
	assert_eq(RouteState.current_stop(flow.train_g)["id"], "guben")
	var first_session: String = _json(flow.train_g["fieldReturns"]["special"])
	_play_field(flow)
	flow.next()
	assert_eq(flow.current(), "end")
	assert_eq(flow.campaign_error, "")
	assert_eq(_record_count(flow), 2)
	assert_eq(SliceSave.applied_ids(flow.train_g).size(), 2)
	assert_eq(flow.field_entries, 2)
	assert_eq(flow.real_receipts.size(), 2)
	assert_eq(_json(flow.train_g["fieldReturns"]["special"]), first_session)


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


## The three slots as a kill at this moment leaves them: each file with its .tmp, .bak and
## .broken, as bytes.
func _disk() -> Dictionary:
	var files: Dictionary = {}
	for path: String in [SLICE, TRAIN, FIELD]:
		for at: String in [path, path + ".tmp", path + ".bak", path + ".broken"]:
			if FileAccess.file_exists(at):
				files[at] = FileAccess.get_file_as_bytes(at)
	return files


## The slots put back as _disk found them, for a new start to pick up.
func _restore(files: Dictionary) -> void:
	_clear_slots()
	for at: String in files:
		var file: FileAccess = FileAccess.open(at, FileAccess.WRITE)
		assert_not_null(file)
		if file != null:
			file.store_buffer(files[at])
			file.close()


## Board i played to the second stop's receipt once, with the slots copied at each of the six
## cuts on the way. A kill at a cut leaves those files, and a run cut there takes the same steps
## up to it, so one run stands for six runs each stopped at its own cut. Two cuts fall inside
## the field's finish: its ended save is written before the train hears of it (field_game.gd
## finish), and the train's slot is written before the slice's.
func _cut_points(board_index: int) -> Dictionary:
	_clear_slots()
	var cuts: Dictionary = {}
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
	cuts["entry"] = _disk()
	flow.go(flow._index_of("stop_pick"))
	assert_false(flow.contract.is_empty())
	cuts["contract"] = _disk()
	flow.next()
	_freeze_field(flow)
	if not is_instance_valid(flow.field):
		_drop(flow)
		return cuts
	flow.field.interrupt()
	cuts["field"] = _disk()
	flow.before_return = func() -> void:
		assert_eq(FieldSave.read(FIELD).get("phase"), "ended")
		assert_false(flow._returned())
		cuts["ended_before_train"] = _disk()
	flow.cut_before_meta = true
	flow.field.finish("departed")
	assert_true(cuts.has("ended_before_train"))
	assert_true(flow._returned())
	assert_eq(SliceSave.read(SLICE)["step"], "field")
	cuts["train_before_meta"] = _disk()
	# The slice's write the cut held back, as the finish makes it without one.
	flow.cut_before_meta = false
	assert_true(flow._save_slice())
	flow.next()
	assert_eq(flow.current(), "receipt")
	cuts["receipt"] = _disk()
	_drop(flow)
	return cuts


func test_campaign_second_stop_resume_matches_uninterrupted() -> void:
	var checked: int = 0
	for i: int in RESUME_BOARDS:
		var expected: Dictionary = (straight[i] if straight.has(i) else _straight_run(i))["g"]
		var cuts: Dictionary = _cut_points(i)
		for cut: String in CUTS:
			assert_true(cuts.has(cut), "%s board %d" % [cut, i])
			if not cuts.has(cut):
				return
			_restore(cuts[cut])
			var picked: Dictionary = _pick()
			assert_false(picked.is_empty(), "%s board %d" % [cut, i])
			if picked.is_empty():
				return
			assert_eq(int(picked["g"]["campaign"]["cursor"]), 1)
			assert_eq(_version_gap(expected, picked["g"]), "", "%s board %d slot version" % [cut, i])
			var resumed: CampaignProbe = _flow(i, {"resume": picked})
			_finish_second(resumed)
			assert_eq(_board_gap(expected, resumed.train_g), "", "%s board %d values" % [cut, i])
			assert_eq(_type_gap(expected, resumed.train_g), "", "%s board %d types" % [cut, i])
			assert_eq(_record_count(resumed), 2)
			assert_eq(SliceSave.applied_ids(resumed.train_g).size(), 2)
			_drop(resumed)
			checked += 1
	assert_eq(checked, 60)


func test_campaign_save_identity_and_shape() -> void:
	var flow: CampaignProbe = _flow()
	_to_arrival(flow)
	var returned: Dictionary = flow.train_g.duplicate(true)
	var returned_receipt: Dictionary = flow.receipt.duplicate(true)
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
	assert_eq(_version_gap(second, missing["g"]), "")
	assert_eq(_board_gap(second, missing["g"]), "")
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
	assert_eq(_board_gap(resumed.contract, recovered["contract"]), "")
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
	var receipt_id: String = String(returned_receipt["receiptId"])
	var identity_only: Dictionary = {"receiptId": receipt_id, "departureId": returned_receipt["departureId"],
		"stopId": returned_receipt["stopId"], "place": {"id": returned_receipt["place"]["id"]}}
	assert_eq(identity_only.size(), 4)
	var bad_fingerprint: Dictionary = returned.duplicate(true)
	bad_fingerprint["fieldReturns"]["applied"][receipt_id] = FieldReturn.canonical(identity_only)
	assert_ne(RouteState.problem(bad_fingerprint, board_tables), "")
	assert_not_null(TrainSave.shape_problem(bad_fingerprint, board_tables))
	SliceSave.clear(TRAIN)
	assert_true(SliceSave.write_train(bad_fingerprint, TRAIN))
	assert_eq(_pick(), {}, "an identity without a receipt body is never adopted")
	var bad_match: Dictionary = returned.duplicate(true)
	bad_match["campaign"]["visit"]["contract"]["roster"][0]["id"] = "absent_from_receipt"
	assert_true(FieldReceipt.check(returned_receipt).is_empty())
	assert_true(FieldReturn.check_departure(bad_match["campaign"]["visit"]["contract"], board_tables).is_empty())
	assert_ne(RouteState.problem(bad_match, board_tables), "")
	assert_not_null(TrainSave.shape_problem(bad_match, board_tables))
	SliceSave.clear(TRAIN)
	assert_true(SliceSave.write_train(bad_match, TRAIN))
	assert_eq(_pick(), {}, "a valid receipt must match its saved contract")
	var wrong_comm: Dictionary = good["campaign"]["visit"]["contract"]["roster"][0].duplicate(true)
	wrong_comm["comm"] = "unknown"
	var bad_contracts: int = 0
	for roster_row: Dictionary in [wrong_comm, {"id": "captain"}]:
		var bad: Dictionary = good.duplicate(true)
		bad["campaign"]["visit"]["contract"]["roster"][0] = roster_row
		assert_ne(RouteState.problem(bad, board_tables), "")
		assert_not_null(TrainSave.shape_problem(bad, board_tables))
		SliceSave.clear(TRAIN)
		assert_true(SliceSave.write_train(bad, TRAIN))
		assert_eq(_pick(), {}, "an invalid departure is never adopted")
		bad_contracts += 1
	assert_eq(bad_contracts, 2)


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


## A run saved before every new run carried supplies: the keys Supplies.enable and the
## new run put on (slice_flow.gd _starting_board), taken off again. The start board is
## only read when the run begins, so the run goes on with supplies off, as such a save does.
func _supplies_off(flow: CampaignProbe) -> void:
	for key: String in ["supOn", "sup", "supCover", "shopSeen"]:
		flow.train_g.erase(key)


## An old save with supplies off: the departure's workshop works once as the train
## leaves (slice_flow.gd _take, RouteState.mark_workshop), and not again after a resume.
## A supplies run's workshop works inside the settlement instead (turn_settle.gd).
func test_campaign_departure_workshop_runs_once_after_resume() -> void:
	var flow: CampaignProbe = _flow()
	_supplies_off(flow)
	assert_false(bool(flow.train_g.get("supOn", false)), "an old save with supplies off")
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
	assert_eq(_version_gap(before, resumed.train_g), "", "supplies off: the board's own number")
	assert_eq(_board_gap(before, resumed.train_g), "")
	resumed.go(resumed._index_of("travel"))
	resumed._take(resumed.train_g.duplicate(true))
	assert_eq(_board_gap(before, resumed.train_g), "", "no upkeep or work twice")
	assert_eq(_type_gap(before, resumed.train_g), "")
	assert_eq(resumed.train_g["campaign"]["workshop_done"].size(), 1)
	_reach(resumed, "arrive")
	resumed.next()
	assert_ne(resumed.train_g["campaign"]["visit"]["departure_id"], departure_id)
	assert_eq(resumed.train_g["campaign"]["workshop_done"], [departure_id])


func test_loader_does_not_reuse_another_stop_map() -> void:
	# Off the main thread as the slice does: a map made there is made ready in its stop form too
	# (a field built on one made at once, without that, never finished).
	var loader: StopLoader = StopLoader.new()
	# The resting share per frame, as the loader's own test: a house map built at the moving
	# share under the 60 fps cap took more than a minute on the runner.
	loader.resting = true
	roots.append(loader)
	add_child(loader)
	loader.prepare("first_leg_01_sulechow", 91, "city", -1.0, "visit_a")
	await _wait_until(func() -> bool: return loader.has_data() or loader.error != "")
	assert_true(loader.has_data())
	assert_eq(loader.data["place_id"], "first_leg_01_sulechow")
	var built: Array = []
	loader.field_built.connect(func(built_game: Node) -> void: built.append(built_game))
	var holder := Node3D.new()
	roots.append(holder)
	add_child(holder)
	loader.build_field(holder, {"place": "houses_01", "visit_id": "visit_b", "campaign_kind": "houses",
		"seed": 91, "stop_form": "edge", "vertices": 96, "cap": 0, "budget": 0})
	await _wait_until(func() -> bool: return not built.is_empty() or loader.error != "", 120.0)
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
	assert_eq(loader._state, "loading")
	var old_path: String = loader._loading_path
	assert_false(old_path.is_empty())
	var old_generation: int = loader._generation
	loader.prepare("houses_01", 93, "edge", -1.0, "visit_d")
	assert_gt(loader._generation, old_generation)
	assert_eq(loader._retired_paths.size(), 1)
	assert_eq(loader._retired_paths[0], old_path)
	loader._take({"place_id": "first_leg_01_sulechow"}, old_generation)
	assert_true(loader.data.is_empty(), "a late old task is ignored")
	await _wait_until(func() -> bool: return (loader.has_data() and loader._retired_paths.is_empty()) or loader.error != "")
	assert_eq(loader.error, "")
	assert_true(loader.has_data())
	assert_eq(loader._retired_paths.size(), 0)
	assert_eq(loader._loading_path, "")
	assert_eq(ResourceLoader.load_threaded_get_status(old_path), ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	loader._process(0.0)
	assert_eq(loader._retired_paths.size(), 0, "a retired request is collected once")
	assert_eq(loader.place, "houses_01")
	assert_eq(loader.visit_for, "visit_d")
	if loader.has_data():
		assert_eq(loader.data["place_id"], "houses_01")
	var before_place: String = loader.place
	loader.prepare("houses_01", 93, "edge", -1.0, "visit_e")
	assert_eq(loader.place, before_place)
	assert_eq(loader.visit_for, "visit_e", "the same map is a new visit")
	assert_gt(loader._generation, old_generation + 1)
	var exit_path: String = loader._loading_path
	assert_false(exit_path.is_empty())
	_drop(loader)
	assert_eq(ResourceLoader.load_threaded_get_status(exit_path), ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)


func test_campaign_start_errors_keep_process_safe() -> void:
	var broken: CampaignProbe = _flow(0, {"save": false, "start_board": {"state": {}, "tables": {}}})
	assert_eq(broken.step, -1)
	assert_null(broken.marks)
	assert_true(broken.campaign_error.begins_with("F-CAMPAIGN-START"))
	broken._process(0.0)
	assert_true(broken.next_button.pressed.is_connected(Callable(broken, "next")))
	var bad_resume: Dictionary = {"run": "broken", "step": "train", "g": {"campaign": {"mode": "campaign", "version": 2}}}
	var resumed: CampaignProbe = _flow(0, {"save": false, "resume": bad_resume})
	assert_eq(resumed.step, -1)
	assert_null(resumed.marks)
	assert_true(resumed.campaign_error.begins_with("F-CAMPAIGN-ROUTE"))
	resumed._process(0.0)


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
