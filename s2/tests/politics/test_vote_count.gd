extends "res://addons/gut/test.gd"
## Vote counting must match s1/src/game/politics.ts. The votes are real ones recorded from TS games
## by s1/tools/s3_dump.ts (vectors --only=data): blocs and RNG state in, tally and RNG state out.
## The table carries its own inputs, so it stays valid when the s1 numbers change.

const VoteCount = preload("res://game/politics/vote_count.gd")
const CouncilMath = preload("res://game/politics/council_math.gd")
const TABLE_PATH := "res://tests/game/fixtures/s3/calc_data.json"

var _table: Dictionary


func before_all() -> void:
	_table = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))


func _triples(rows: Array) -> Array:
	var out: Array = []
	for r: Array in rows:
		out.append([int(r[0]), int(r[1]), int(r[2])])
	return out


func _flips(rows: Array) -> Array:
	var out: Array = []
	for r: Array in rows:
		out.append([int(r[0]), bool(r[1])])
	return out


func test_table_covers_every_draw_path() -> void:
	var votes: Array = _table["votes"]
	var with_pool := 0
	var with_undecided := 0
	var failed := 0
	for v: Dictionary in votes:
		var pool := 0
		var und := 0
		for b: Dictionary in v["blocs"]:
			pool += int(b["pool"])
			und += int(b["und"])
		if pool > 0:
			with_pool += 1
		if und > 0:
			with_undecided += 1
		if not v["passed"]:
			failed += 1
	assert_gt(votes.size(), 30)
	assert_gt(with_pool, 0, "votes where a bought leader brings seats")
	assert_gt(with_undecided, 0, "votes with undecided seats")
	assert_gt(failed, 0, "votes that failed")


func test_votes_match_reference() -> void:
	var i := 0
	for v: Dictionary in _table["votes"]:
		var got := VoteCount.count(v["blocs"], int(v["rngBefore"]), int(v["need"]))
		var what := "vote %d (%s)" % [i, v["agenda"]]
		assert_eq(got["state"], int(v["rngAfter"]), what + " rng state")
		assert_eq(got["yes"], int(v["yes"]), what + " yes")
		assert_eq(got["no"], int(v["no"]), what + " no")
		assert_eq(got["absent"], int(v["absent"]), what + " absent")
		assert_eq(got["passed"], bool(v["passed"]), what + " passed")
		assert_eq(got["by_comm"], _triples(v["byComm"]), what + " by community")
		assert_eq(got["flips"], _flips(v["flips"]), what + " flip order")
		i += 1


func test_stage_of_matches_reference() -> void:
	for row: Dictionary in _table["stageOf"]:
		var got := CouncilMath.stage_of(float(row["rel"]), _table["stages"])
		assert_eq(got["index"], int(row["index"]), "rel %d index" % int(row["rel"]))
		assert_eq(got["band"], int(row["band"]), "rel %d band" % int(row["rel"]))
		assert_eq(got["name"], row["name"], "rel %d name" % int(row["rel"]))


func test_no_draws_leaves_state_alone() -> void:
	var bloc := {"yes": 12, "und": 0, "no": 8, "absent": 0, "pool": 0, "poolChance": 0.0, "score": 1}
	var got := VoteCount.count([bloc], 99, 11)
	assert_eq(got["state"], 99)
	assert_eq(got["yes"], 12)
	assert_true(got["passed"])
	assert_eq(got["flips"], [])
