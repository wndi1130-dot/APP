extends GutTest

const RouteState = preload("res://game/train/route_state.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const SliceSave = preload("res://game/sim/slice_save.gd")
const STARTS: String = "res://tests/game/fixtures/campaign_starts.json"
## A folder of this run's own, as test_field_save.gd keeps: another run of the trials at the same
## time (another working copy) shares the user folder and would clear or write over the same slots.
static var DIR: String = "user://test_world_seed_1a_%d" % OS.get_process_id()
static var TRAIN_PATH: String = DIR + "/train.json"
static var FIX2_SLICE: String = DIR + "/fix2_slice.json"
static var FIX2_TRAIN: String = DIR + "/fix2_train.json"
static var FIX2_FIELD: String = DIR + "/fix2_field.json"


class FlowProbe extends SliceFlow:
	func _departure() -> Dictionary:
		return {}

	func _guard_ids(_d: Dictionary) -> Array:
		return []


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func after_each() -> void:
	for path: String in [TRAIN_PATH, FIX2_SLICE, FIX2_TRAIN, FIX2_FIELD]:
		SliceSave.clear(path)


func after_all() -> void:
	DirAccess.remove_absolute(DIR)


func _started() -> Dictionary:
	return RouteState.start({"phase": "travel"}, "run_1a", "-9223372036854775808")


func test_start_stores_values_without_mutating_input() -> void:
	var input: Dictionary = {"phase": "travel"}
	var first: Dictionary = RouteState.start(input, "run_1a", "123")
	assert_eq(first, RouteState.start(input, "run_1a", "123"))
	assert_false(input.has("campaign"))
	assert_eq(first["campaign"]["world_seed"], "123")
	assert_eq(first["campaign"]["seed_rule"], 1)
	assert_eq(first["campaign"]["furnish_rule"], 0)


func test_world_seed_text_boundaries_and_round_trip() -> void:
	var cases: Array = [
		[PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0]), "0"],
		[PackedByteArray([255, 255, 255, 255, 255, 255, 255, 255]), "-1"],
		[PackedByteArray([0, 0, 0, 0, 0, 0, 0, 128]), "-9223372036854775808"],
		[PackedByteArray([255, 255, 255, 255, 255, 255, 255, 127]), "9223372036854775807"],
		[PackedByteArray([1, 0, 0, 0, 0, 0, 0, 0]), "1"],
	]
	for row: Array in cases:
		var text: String = RouteState.world_seed_text(row[0])
		assert_eq(text, row[1])
		assert_eq(str(FieldSave._int_of_text(text)), text)
	assert_eq(RouteState.world_seed_text(PackedByteArray()), "")
	assert_eq(RouteState.world_seed_text(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0])), "")


func test_world_seed_for_run_is_deterministic_and_valid() -> void:
	var runs: Array[String] = ["run_1a", "run_1b", "run_1c", ""]
	var expected: Array[String] = ["984539240965475773", "924050262981133378", "5163729525108465354", "365184263539992657"]
	var seen: Dictionary = {}
	for i: int in runs.size():
		var text: String = RouteState.world_seed_for_run(runs[i])
		assert_eq(text, expected[i])
		assert_eq(text, RouteState.world_seed_for_run(runs[i]))
		assert_not_null(FieldSave._int_of_text(text))
		assert_false(seen.has(text))
		seen[text] = true


func test_new_campaign_saves_seed_for_each_run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STARTS))
	assert_true(parsed is Array and not parsed.is_empty(), "campaign starting boards")
	if not parsed is Array or parsed.is_empty():
		return
	var seeds: Array[String] = []
	var runs: Array[String] = ["run_1a", "run_1b", "run_1a"]
	var expected: Array[String] = ["984539240965475773", "924050262981133378", "984539240965475773"]
	for i: int in runs.size():
		for path: String in [FIX2_SLICE, FIX2_TRAIN, FIX2_FIELD]:
			SliceSave.clear(path)
		var flow: FlowProbe = FlowProbe.new()
		flow.opts = {"mode": "campaign", "save": true, "seed": 1, "run": runs[i],
			"start_board": parsed[0], "cinema": false, "map_threads": false, "still": true,
			"slice_save_path": FIX2_SLICE, "train_save_path": FIX2_TRAIN, "field_save_path": FIX2_FIELD}
		add_child(flow)
		flow.set_process(false)
		assert_eq(flow.campaign_error, "")
		assert_eq(flow.save_error, "")
		var saved: Dictionary = SliceSave._parse(FIX2_TRAIN)
		var campaign: Dictionary = saved.get("campaign", {})
		var seed: String = String(campaign.get("world_seed", ""))
		assert_eq(seed, expected[i])
		assert_eq(seed, RouteState.world_seed_for_run(runs[i]))
		seeds.append(seed)
		flow.free()
	assert_ne(seeds[0], seeds[1])
	assert_eq(seeds[0], seeds[2])
	for path: String in [FIX2_SLICE, FIX2_TRAIN, FIX2_FIELD]:
		SliceSave.clear(path)


func test_problem_accepts_old_and_valid_campaigns() -> void:
	var g: Dictionary = _started()
	assert_eq(RouteState.problem(g), "")
	var decoded: Variant = FieldSave.decode_checked(JSON.parse_string(JSON.stringify(FieldSave._encode(g))))
	assert_true(decoded is Dictionary)
	if decoded is Dictionary:
		assert_eq(RouteState.problem(decoded), "")
	for key: String in ["world_seed", "seed_rule", "furnish_rule"]:
		g["campaign"].erase(key)
	assert_eq(RouteState.problem(g), "")


func test_train_save_and_field_resume_keep_seed() -> void:
	SliceSave.clear(TRAIN_PATH)
	var g: Dictionary = _started()
	assert_true(SliceSave.write_train(g, TRAIN_PATH))
	var loaded: Dictionary = SliceSave._parse(TRAIN_PATH)
	assert_eq(RouteState.problem(loaded), "")
	assert_eq(loaded.get("campaign", {}).get("world_seed"), "-9223372036854775808")
	assert_eq(loaded.get("campaign", {}).get("seed_rule"), 1)
	assert_eq(loaded.get("campaign", {}).get("furnish_rule"), 0)
	var start_opts: Dictionary = FieldSave._start_opts({"world_seed": "-1", "furnish_rule": 0})
	var options: Dictionary = FieldSave.resume_opts({"start_opts": start_opts})
	assert_eq(options.get("world_seed"), "-1")
	assert_eq(options.get("furnish_rule"), 0)
	SliceSave.clear(TRAIN_PATH)


func test_problem_rejects_bad_seed_and_rules() -> void:
	for value: Variant in [1, 1.0, "+1", "01", "-0", "9223372036854775808", "-9223372036854775809", ""]:
		var bad: Dictionary = _started()
		bad["campaign"]["world_seed"] = value
		assert_ne(RouteState.problem(bad), "", "invalid world_seed: %s" % str(value))
	for key: String in ["seed_rule", "furnish_rule"]:
		var upper: int = RouteState.SEED_RULE if key == "seed_rule" else RouteState.FURNISH_RULE
		for value: Variant in [-1, upper + 1, 0.0, "0"]:
			var bad: Dictionary = _started()
			bad["campaign"][key] = value
			assert_ne(RouteState.problem(bad), "", "invalid %s: %s" % [key, str(value)])


func test_missing_world_seed_error_for_supported_furnish_rule() -> void:
	var missing: Dictionary = _started()
	missing["campaign"].erase("world_seed")
	missing["campaign"]["furnish_rule"] = 1
	assert_eq(RouteState.problem(missing), "F-CAMPAIGN-ROUTE: furnish_rule")
	assert_eq(RouteState._seed_problem(missing["campaign"], 1), "F-CAMPAIGN-ROUTE: missing world seed")
	missing["campaign"]["world_seed"] = "0"
	assert_eq(RouteState._seed_problem(missing["campaign"], 1), "")


func test_field_opts_copies_present_campaign_keys_only() -> void:
	var flow: FlowProbe = FlowProbe.new()
	flow.step = 2
	flow.opts = {"mode": "campaign", "seed": 1}
	flow.train_g = _started()
	flow.train_g["seed"] = "camp-01"
	flow.train_g["campaign"]["visit"] = {"field_seed": 12, "id": "visit_1a"}
	var field: Dictionary = flow._field_opts()
	assert_eq(field.get("world_seed"), "-9223372036854775808")
	assert_eq(field.get("furnish_rule"), 0)
	flow.train_g["campaign"].erase("world_seed")
	flow.train_g["campaign"].erase("furnish_rule")
	field = flow._field_opts()
	assert_false(field.has("world_seed"))
	assert_false(field.has("furnish_rule"))
	flow.opts = {"seed": 1}
	flow.train_g = {"passed": {}}
	field = flow._field_opts()
	assert_false(field.has("world_seed"))
	assert_false(field.has("furnish_rule"))
	flow.free()
