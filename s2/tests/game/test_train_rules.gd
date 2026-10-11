extends "res://addons/gut/test.gd"
## The train's rule values: the default file loads whole, a missing file is
## empty, and check() catches a wrong shape.

const Rules = preload("res://game/train/train_rules.gd")


func _rules() -> Dictionary:
	return Rules.load_default().duplicate(true)


func _car(d: Dictionary, id: String) -> Dictionary:
	for c in d["cars"]:
		if c["id"] == id:
			return c
	return {}


func _assert_caught(d: Dictionary, what: String) -> void:
	assert_false(Rules.check(d).is_empty(), what)


# ---------------------------------------------------------------- the default file

func test_the_default_rules_load_and_pass_the_check() -> void:
	var d := Rules.load_default()
	assert_false(d.is_empty())
	assert_eq(Rules.check(d), PackedStringArray())


func test_every_errand_goes_to_a_car_that_exists() -> void:
	var d := _rules()
	var ids: Array = []
	for c in d["cars"]:
		ids.append(c["id"])
	for e in d["errands"]:
		assert_true(ids.has(e["to"]), String(e["id"]))


func test_a_missing_file_is_an_empty_rule_set() -> void:
	assert_true(Rules.load_file("res://game/train/no_such_rules.json").is_empty())


# ---------------------------------------------------------------- a wrong shape is caught

func test_a_rule_set_without_a_train_is_caught() -> void:
	var d := _rules()
	d.erase("train")
	_assert_caught(d, "no train")


func test_an_unknown_phase_is_caught() -> void:
	var d := _rules()
	d["train"]["phase"] = "nap"
	_assert_caught(d, "phase nap")


func test_a_situation_of_three_numbers_is_caught() -> void:
	var d := _rules()
	d["comms"]["tail"]["sit"] = [35, 40, 75]
	_assert_caught(d, "sit of three")


func test_a_situation_number_out_of_range_is_caught() -> void:
	var d := _rules()
	d["comms"]["tail"]["sit"][0] = 120
	_assert_caught(d, "sit 120")


func test_a_car_of_a_community_that_does_not_exist_is_caught() -> void:
	var d := _rules()
	d["cars"][0]["comm"] = "ghosts"
	_assert_caught(d, "car of no community")


func test_two_cars_with_one_id_are_caught() -> void:
	var d := _rules()
	d["cars"][1]["id"] = "tail1"
	_assert_caught(d, "tail1 twice")


func test_an_errand_to_a_car_that_does_not_exist_is_caught() -> void:
	var d := _rules()
	d["errands"][0]["to"] = "nowhere"
	_assert_caught(d, "errand to nowhere")


func test_an_errand_that_repeats_every_zero_seconds_is_caught() -> void:
	var d := _rules()
	d["errands"][0]["every"] = 0.0
	_assert_caught(d, "every 0")


func test_the_default_rules_give_every_community_its_three_axes() -> void:
	var d := _rules()
	for id in d["comms"]:
		assert_eq((d["ideo"][id] as Array).size(), 3, String(id))
	assert_gt(float(d["calls"]["every"]), 0.0)


func test_rules_without_axes_or_calls_still_pass() -> void:
	var d := _rules()
	d.erase("ideo")
	d.erase("calls")
	assert_eq(Rules.check(d), PackedStringArray())


func test_axes_of_two_numbers_or_of_nobody_are_caught() -> void:
	var d := _rules()
	d["ideo"]["tail"] = [1, -1]
	_assert_caught(d, "two axes")
	d = _rules()
	d["ideo"]["ghosts"] = [0, 0, 0]
	_assert_caught(d, "axes of no community")
	d = _rules()
	d["ideo"]["tail"] = [1, -1, 3]
	_assert_caught(d, "an axis of 3")


func test_calls_that_repeat_every_zero_seconds_are_caught() -> void:
	var d := _rules()
	d["calls"]["every"] = 0.0
	_assert_caught(d, "calls every 0")
	d = _rules()
	d["calls"].erase("stay")
	_assert_caught(d, "calls without a stay")


# ---------------------------------------------------------------- the community of a car

func test_a_community_car_gives_its_community_and_the_dining_car_none() -> void:
	var d := _rules()
	var comm: Dictionary = Rules.comm_of(d, _car(d, "tail1"))
	assert_eq(comm, d["comms"]["tail"])
	assert_eq(comm["name"], "꼬리칸")
	assert_true(Rules.comm_of(d, _car(d, "dining")).is_empty())
