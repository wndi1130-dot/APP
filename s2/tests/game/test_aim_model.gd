extends "res://addons/gut/test.gd"

const Aim = preload("res://game/sim/aim_model.gd")
const W = preload("res://game/sim/weapons.gd")

# skill 5 gives skill factor 1.0, so pistol floor = 1.2
const BASE := {"skill": 5}


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _run(a: Aim, seconds: float, mods: Dictionary) -> void:
	var steps: int = int(round(seconds / 0.05))
	for _i in range(steps):
		a.tick(0.05, mods)


func test_start_sets_start_deg_and_spread() -> void:
	var a := Aim.new()
	a.start("pistol", BASE)
	assert_true(a.active)
	assert_eq(a.weapon_id, "pistol")
	assert_almost_eq(a.deg, 9.0, 0.0001)
	assert_almost_eq(a.floor_deg, 1.2, 0.0001)
	a.start("shotgun", {"spread": 1.5})
	assert_almost_eq(a.deg, 10.5, 0.0001)


func test_standing_shrinks_to_floor_in_shrink_time() -> void:
	var a := Aim.new()
	a.start("pistol", BASE)
	_run(a, 0.5, BASE)
	assert_almost_eq(a.deg, 9.0 - 7.8 * 0.5, 0.01)
	_run(a, 0.5, BASE)
	assert_almost_eq(a.deg, 1.2, 0.01)
	_run(a, 2.0, BASE)
	assert_almost_eq(a.deg, 1.2, 0.0001)


func test_shrink_mult_slows() -> void:
	var a := Aim.new()
	var mods := {"skill": 5, "shrink_mult": 0.5}
	a.start("pistol", mods)
	_run(a, 1.0, mods)
	assert_almost_eq(a.deg, 9.0 - 3.9, 0.01)
	_run(a, 1.0, mods)
	assert_almost_eq(a.deg, 1.2, 0.01)


func test_floor_mods_min_mult_enemy_close_quality() -> void:
	var a := Aim.new()
	a.start("pistol", BASE)
	assert_almost_eq(a.compute_floor({"skill": 5, "min_mult": 2.0}), 2.4, 0.0001)
	assert_almost_eq(a.compute_floor({"skill": 5, "enemy_close": true}), 2.4, 0.0001)
	assert_almost_eq(a.compute_floor({"skill": 5, "min_mult": 2.0, "enemy_close": true}), 4.8, 0.0001)
	a.start("pipe_shotgun", BASE)
	assert_almost_eq(a.compute_floor({"skill": 5, "quality": "crude"}), 3.6, 0.0001)
	# floor never exceeds the bloom cap
	assert_almost_eq(a.compute_floor({"skill": 0, "min_mult": 3.0, "enemy_close": true, "quality": "crude"}), 9.0 * 1.6, 0.0001)


func test_floor_matches_weapons_min_deg() -> void:
	var a := Aim.new()
	a.start("bow", {"skill": 1})
	assert_almost_eq(a.floor_deg, W.min_deg("bow", "factory", 1), 0.0001)


func test_enemy_closing_opens_circle() -> void:
	var a := Aim.new()
	a.start("pistol", BASE)
	_run(a, 2.0, BASE)
	var close := {"skill": 5, "enemy_close": true}
	_run(a, 1.0, close)
	assert_almost_eq(a.deg, 2.4, 0.01)


func test_moving_grows_toward_one_and_half_start() -> void:
	var a := Aim.new()
	a.start("pistol", BASE)
	_run(a, 2.0, BASE)
	var mv := {"skill": 5, "moving": true}
	_run(a, 0.5, mv)
	assert_almost_eq(a.deg, 1.2 + 4.5, 0.01)
	_run(a, 3.0, mv)
	assert_almost_eq(a.deg, 13.5, 0.0001)


func test_fire_blooms_and_caps() -> void:
	var a := Aim.new()
	a.start("pistol", BASE)
	_run(a, 2.0, BASE)
	a.fire()
	assert_almost_eq(a.deg, 7.2, 0.0001)
	a.fire()
	a.fire()
	assert_almost_eq(a.deg, 14.4, 0.0001)
	a.start("bow", BASE)
	_run(a, 3.0, BASE)
	var settled: float = a.deg
	a.fire()
	assert_almost_eq(a.deg, settled + 2.0, 0.0001)


func test_inactive_does_not_tick() -> void:
	var a := Aim.new()
	a.start("pistol", BASE)
	a.stop()
	_run(a, 1.0, BASE)
	assert_almost_eq(a.deg, 9.0, 0.0001)


func test_radius_at() -> void:
	var a := Aim.new()
	a.start("pistol", BASE)
	a.deg = 45.0
	assert_almost_eq(a.radius_at(10.0), 10.0, 0.0001)
	assert_eq(a.radius_at(0.0), 0.0)
	a.deg = 1.2
	assert_almost_eq(a.radius_at(20.0), 20.0 * tan(deg_to_rad(1.2)), 0.0001)


func test_roll_small_circle_is_always_head() -> void:
	var r := _rng(3)
	for _i in range(200):
		assert_eq(Aim.roll(r, 0.12), "head")
	assert_eq(Aim.roll(r, 0.0), "head")


func test_roll_distribution_matches_area() -> void:
	var r := _rng(5)
	var n := {"head": 0, "body": 0, "miss": 0}
	var total := 20000
	for _i in range(total):
		n[Aim.roll(r, 1.0)] += 1
	assert_between(n["head"] / float(total), 0.0169 - 0.004, 0.0169 + 0.004)
	assert_between(n["body"] / float(total), 0.0987 - 0.008, 0.0987 + 0.008)


func test_roll_custom_radii() -> void:
	var r := _rng(9)
	for _i in range(100):
		assert_ne(Aim.roll(r, 0.3, 0.0, 0.3), "miss")


func test_pellet_hits() -> void:
	var r := _rng(21)
	assert_eq(Aim.pellet_hits(r, 0.0, 0.0, 8), {"head": 8, "body": 0})
	assert_eq(Aim.pellet_hits(r, 0.5, 0.5, 0), {"head": 0, "body": 0})
	var hits: Dictionary = Aim.pellet_hits(r, 0.05, 0.25, 8)
	assert_true(hits["head"] + hits["body"] <= 8)
	assert_true(hits["head"] + hits["body"] >= 1)
	# far away: wide spread, few pellets land
	var far_sum := 0
	for _i in range(200):
		var h: Dictionary = Aim.pellet_hits(r, 3.0, 1.5, 8)
		far_sum += h["head"] + h["body"]
	assert_lt(far_sum / 200.0, 1.0)
