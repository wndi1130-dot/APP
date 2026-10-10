extends "res://addons/gut/test.gd"
## The tables reader against a tables file written by s1/tools/s3_dump.ts (tables). The file here is
## a sample taken when this test was written; the game's own copy is taken when S3 starts.

const Tables = preload("res://game/politics/tables.gd")
const CouncilMath = preload("res://game/politics/council_math.gd")
const SAMPLE_PATH := "res://tests/game/fixtures/s3/tables_sample.json"

var _tables: Dictionary


func before_all() -> void:
	_tables = Tables.load_file(SAMPLE_PATH)


func test_sample_loads_with_no_problems() -> void:
	assert_eq(Tables.problems(FileAccess.get_file_as_string(SAMPLE_PATH)), [] as Array[String])
	for name: String in Tables.REQUIRED:
		assert_true(_tables.has(name), name)
	assert_eq((_tables["COMMS"] as Array).size(), 5)


func test_per_community_tables_come_out_in_community_order() -> void:
	var pops := Tables.ints_by_comm(_tables, "POP0")
	assert_eq(pops.size(), 5)
	var total := 0
	for i: int in pops.size():
		assert_eq(pops[i], int(_tables["POP0"][_tables["COMMS"][i]]))
		total += pops[i]
	assert_gt(total, 0)
	var seats := CouncilMath.seats(pops)
	var sum := 0
	for s: int in seats:
		sum += s
	assert_eq(sum, 100, "the starting train fills the council")


func test_tables_feed_the_council_arithmetic() -> void:
	var rels := Tables.ints_by_comm(_tables, "REL0")
	for rel: int in rels:
		var stage := CouncilMath.stage_of(rel, _tables["STAGES"])
		assert_between(stage["band"], -2, 2)
	for law: String in _tables["LAWS"]:
		assert_has([51, 67], Tables.law_need(_tables, law), law)


func test_bad_files_are_named_not_loaded() -> void:
	assert_eq(Tables.parse("[1, 2]"), {})
	assert_eq(Tables.problems("[1, 2]"), ["not a JSON object"] as Array[String])
	assert_eq(Tables.parse('{"format": "other", "tables": {}}'), {})
	assert_has(Tables.problems('{"format": "other", "tables": {}}'), "format is not s3-tables-v1")
	assert_has(Tables.problems('{"format": "s3-tables-v1", "tables": {"COMMS": ["a"], "POP0": {}}}'), "table POP0 has no entry for a")
	assert_eq(Tables.load_file("res://tests/game/fixtures/s3/no_such_file.json"), {})
