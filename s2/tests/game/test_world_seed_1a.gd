extends GutTest

const RouteState = preload("res://game/train/route_state.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const SliceSave = preload("res://game/sim/slice_save.gd")
const TRAIN_PATH: String = "user://test_world_seed_1a_train.json"


class FlowProbe extends SliceFlow:
	func _departure() -> Dictionary:
		return {}

	func _guard_ids(_d: Dictionary) -> Array:
		return []


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
	var missing: Dictionary = _started()
	missing["campaign"].erase("world_seed")
	missing["campaign"]["furnish_rule"] = 1
	assert_ne(RouteState.problem(missing), "")


func test_field_opts_copies_present_campaign_keys_only() -> void:
	var flow: FlowProbe = FlowProbe.new()
	flow.step = 2
	flow.opts = {"mode": "campaign"}
	flow.train_g = _started()
	flow.train_g["campaign"]["visit"] = {"field_seed": 12, "id": "visit_1a"}
	var field: Dictionary = flow._field_opts()
	assert_eq(field.get("world_seed"), "-9223372036854775808")
	assert_eq(field.get("furnish_rule"), 0)
	flow.train_g["campaign"].erase("world_seed")
	flow.train_g["campaign"].erase("furnish_rule")
	field = flow._field_opts()
	assert_false(field.has("world_seed"))
	assert_false(field.has("furnish_rule"))
	flow.opts = {}
	flow.train_g = {"passed": {}}
	field = flow._field_opts()
	assert_false(field.has("world_seed"))
	assert_false(field.has("furnish_rule"))
	flow.free()
