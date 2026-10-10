extends "res://addons/gut/test.gd"
## The GDScript RNG must draw what s1/src/core/rng.ts draws. The table is written by
## s1/tools/s3_dump.ts (vectors --only=algo) and s1/tests/s3_record.test.ts keeps it current.

const Rng = preload("res://game/politics/rng.gd")
const TABLE_PATH := "res://tests/game/fixtures/s3/calc_algo.json"

var _table: Dictionary


func before_all() -> void:
	_table = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))


func test_table_loaded() -> void:
	assert_eq(_table["format"], "s3-vectors-v1")
	assert_eq((_table["rng"] as Array).size(), 12)


func test_seed_state_matches_reference() -> void:
	for row: Dictionary in _table["rng"]:
		assert_eq(Rng.seed_state(row["seed"]), int(row["start"]), "seed %s" % [row["seed"]])
	assert_eq(Rng.seed_state(""), Rng.FNV_OFFSET, "empty text is the FNV offset")
	assert_eq(Rng.seed_state(-1), 0xFFFFFFFF)
	assert_eq(Rng.seed_state(0x100000000), 0)


func test_draws_match_reference() -> void:
	for row: Dictionary in _table["rng"]:
		var state := Rng.seed_state(row["seed"])
		var i := 0
		for d: Dictionary in row["draws"]:
			var got := Rng.next(state)
			state = got[1]
			assert_eq(state, int(d["state"]), "seed %s draw %d state" % [row["seed"], i])
			assert_eq(Rng.u32(state), int(d["u32"]), "seed %s draw %d u32" % [row["seed"], i])
			# The value is u32 / 2^32. Compare it as computed: Godot reads long JSON decimals a few ulp off.
			assert_eq(got[0], float(int(d["u32"])) / 4294967296.0, "seed %s draw %d value" % [row["seed"], i])
			assert_almost_eq(got[0], float(d["value"]), 1e-12, "seed %s draw %d value as written" % [row["seed"], i])
			i += 1


func test_int_draws_match_reference() -> void:
	var redrawn := 0
	for row: Dictionary in _table["rng"]:
		for d: Dictionary in row["ints"]:
			var from := int(d["from"])
			var lo := int(d["min"])
			var hi := int(d["max"])
			var got := Rng.next_int(from, lo, hi)
			assert_eq(got[0], int(d["value"]), "seed %s [%d, %d] value" % [row["seed"], lo, hi])
			assert_eq(got[1], int(d["state"]), "seed %s [%d, %d] state" % [row["seed"], lo, hi])
			if got[1] != Rng.step(from):
				redrawn += 1
	assert_gt(redrawn, 0, "the table holds at least one draw that fell in the uneven tail")


func test_imul_wraps_like_32_bit() -> void:
	assert_eq(Rng.imul(0xFFFFFFFF, 0xFFFFFFFF), 1)
	assert_eq(Rng.imul(0x811C9DC5, 0x01000193), (0x811C9DC5 * 0x01000193) & 0xFFFFFFFF)
	assert_eq(Rng.imul(0, 123), 0)


func test_one_value_range_still_moves_state() -> void:
	var got := Rng.next_int(7, 5, 5)
	assert_eq(got[0], 5)
	assert_eq(got[1], Rng.step(7))
