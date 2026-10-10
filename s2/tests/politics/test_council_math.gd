extends "res://addons/gut/test.gd"
## Seats and bloc splits must match s1/src/game (state.ts seats, politics.ts split/undecidedChance).
## The table is written by s1/tools/s3_dump.ts (vectors --only=algo).

const CouncilMath = preload("res://game/politics/council_math.gd")
const TABLE_PATH := "res://tests/game/fixtures/s3/calc_algo.json"
## Relation stages as in s1/src/game/data.ts STAGES (the game reads them from the data tables).
const STAGES := [
	{"min": 70, "name": "헌신", "band": 2}, {"min": 40, "name": "지지", "band": 1},
	{"min": 15, "name": "호의", "band": 1}, {"min": -14, "name": "중립", "band": 0},
	{"min": -39, "name": "회의", "band": -1}, {"min": -69, "name": "반대", "band": -1},
	{"min": -100, "name": "적대", "band": -2},
]

var _table: Dictionary


func before_all() -> void:
	_table = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))


func _ints(values: Array) -> Array[int]:
	var out: Array[int] = []
	for v: Variant in values:
		out.append(int(v))
	return out


func test_seats_match_reference() -> void:
	assert_eq((_table["seats"] as Array).size(), 40)
	for row: Dictionary in _table["seats"]:
		var pops := _ints(row["pop"])
		assert_eq(CouncilMath.seats(pops), _ints(row["seats"]), "pop %s" % [pops])


func test_seats_always_hundred_and_ties_go_to_earlier() -> void:
	# 12.5 and 12.5: the spare seat goes to the earlier of the two.
	assert_eq(CouncilMath.seats([90, 30, 25, 30, 25]), _ints([45, 15, 13, 15, 12]))
	assert_eq(CouncilMath.seats([0, 0, 0, 0, 0]), _ints([20, 20, 20, 20, 20]))
	# 33.33 each: the one spare seat goes to the first community.
	assert_eq(CouncilMath.seats([1, 1, 1, 0, 0]), _ints([34, 33, 33, 0, 0]))


func test_split_matches_reference() -> void:
	for row: Dictionary in _table["split"]:
		var got := CouncilMath.split(int(row["score"]))
		for i: int in 3:
			assert_eq(got[i], float(row["split"][i]), "score %d part %d" % [int(row["score"]), i])


func test_undecided_chance_matches_reference() -> void:
	for row: Dictionary in _table["undecided"]:
		var score := int(row["score"])
		assert_eq(CouncilMath.undecided_chance(score), float(row["chance"]), "score %d" % score)


func test_stage_of_boundaries() -> void:
	assert_eq(CouncilMath.stage_of(70, STAGES), {"name": "헌신", "band": 2, "index": 0})
	assert_eq(CouncilMath.stage_of(69, STAGES)["name"], "지지")
	assert_eq(CouncilMath.stage_of(15, STAGES)["band"], 1)
	assert_eq(CouncilMath.stage_of(14, STAGES)["band"], 0)
	assert_eq(CouncilMath.stage_of(-14, STAGES)["name"], "중립")
	assert_eq(CouncilMath.stage_of(-15, STAGES)["name"], "회의")
	assert_eq(CouncilMath.stage_of(-70, STAGES), {"name": "적대", "band": -2, "index": 6})
	assert_eq(CouncilMath.stage_of(-150, STAGES)["index"], 6, "below every floor reads as the last stage")


func test_round_half_up_like_js() -> void:
	assert_eq(CouncilMath.round_half_up(2.5), 3)
	assert_eq(CouncilMath.round_half_up(-2.5), -2)
	assert_eq(CouncilMath.round_half_up(-2.51), -3)
	assert_eq(CouncilMath.round_half_up(0.49), 0)
