extends "res://addons/gut/test.gd"
## A dead body is seen going over, lying, and coming up again; the rules are
## as before (down at once, up when the time runs out).

const FieldGame = preload("res://game/field_game.gd")
const DeadPose = preload("res://game/actors/dead_pose.gd")
const Motion = preload("res://game/sim/motion.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()


func _one() -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(6.0, 0, 0))
	z["state"] = "wander"
	return z


func test_fall_starts_slow_and_ends_flat() -> void:
	var fall: float = float(Motion.row("dead_fall")["len"])
	assert_eq(DeadPose.fall_k(0.0), 0.0)
	assert_lt(DeadPose.fall_k(fall * 0.5), 0.5, "slow off the heels")
	assert_eq(DeadPose.fall_k(fall), 1.0)
	assert_eq(DeadPose.fall_k(9.0), 1.0)


func test_rise_is_flat_then_on_its_hands_then_up() -> void:
	var rise: float = float(Motion.row("dead_rise")["len"])
	assert_eq(DeadPose.rise_k(rise + 3.0), 1.0, "still flat with time to spare")
	assert_almost_eq(DeadPose.rise_k(rise * 0.5), DeadPose.SIT, 0.001)
	assert_almost_eq(DeadPose.rise_k(0.0), 0.0, 0.001)
	var last := 1.0
	for i in 25:
		var k := DeadPose.rise_k(rise * (1.0 - float(i) / 24.0))
		assert_lte(k, last + 0.0001, "it never dips back")
		last = k


func test_a_knocked_down_body_goes_over_lies_and_comes_up() -> void:
	var z := _one()
	assert_eq(DeadPose.down_k(z), 0.0)
	game.zombies.knock_down(z)
	assert_eq(z["state"], "downed", "down at once for the rules")
	assert_eq(DeadPose.down_k(z), 0.0, "seen still upright as it is hit")
	z["t"] = 5.0
	z["age"] += 0.2
	assert_between(DeadPose.down_k(z), 0.05, 0.95)
	z["age"] += 1.0
	assert_eq(DeadPose.down_k(z), 1.0)
	z["t"] = 0.6
	assert_between(DeadPose.down_k(z), 0.3, 0.8, "on its hands")
	game.zombies.update(0.7)
	assert_eq(z["state"], "wander", "up when the time runs out, as before")
	assert_eq(DeadPose.down_k(z), 0.0)
	assert_false(z.has("fell_at"))


func test_a_killed_body_goes_over_and_stays() -> void:
	var z := _one()
	game.zombies.kill(z)
	assert_eq(DeadPose.down_k(z), 0.0)
	z["age"] += 5.0
	assert_eq(DeadPose.down_k(z), 1.0)


func test_a_body_killed_on_the_ground_does_not_fall_twice() -> void:
	var z := _one()
	game.zombies.knock_down(z)
	z["age"] += 2.0
	game.zombies.kill(z)
	assert_eq(DeadPose.down_k(z), 1.0)


func test_a_crawler_and_a_corpse_laid_out_are_flat_from_the_start() -> void:
	var z := _one()
	z["crawl"] = true
	assert_eq(DeadPose.down_k(z), 1.0)
	game.zombies.kill(z)
	assert_eq(DeadPose.down_k(z), 1.0)
	var c: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(8.0, 0, 0))
	c["state"] = "dead"
	assert_eq(DeadPose.down_k(c), 1.0)


func test_a_rising_corpse_comes_up_before_it_walks() -> void:
	var z: Dictionary = game.zombies.add_rising(game.player.position + Vector3(7.0, 0, 0), "누군가")
	z["rise_t"] = 10.0
	assert_eq(DeadPose.down_k(z), 1.0)
	z["rise_t"] = 0.3
	assert_lt(DeadPose.down_k(z), DeadPose.SIT)


# ---------------------------------------------------------------- which way, and each its own

func test_struck_from_the_front_it_goes_on_its_back_from_behind_on_its_face() -> void:
	var p = game.player
	var z := _one()
	z["pos"] = p.position + Vector3(1.0, 0, 0)
	z["angle"] = -PI * 0.5            # facing the chief
	game.zombies.update(0.0)
	game.zombies.knock_down(z)
	assert_eq(DeadPose.fall_side(z), -1.0, "on its back")
	var z2 := _one()
	z2["pos"] = p.position + Vector3(1.0, 0, 0)
	z2["angle"] = PI * 0.5            # its back to the chief
	game.zombies.kill(z2)
	assert_eq(DeadPose.fall_side(z2), 1.0, "on its face")
	var far := _one()
	far["pos"] = p.position + Vector3(30.0, 0, 0)
	far["angle"] = PI * 0.5
	for q in game.squad:
		q.position = p.position
	game.zombies.kill(far)
	assert_eq(DeadPose.fall_side(far), -1.0, "nobody near: on its back, as before")


func test_each_body_has_its_own_carriage_and_keeps_it() -> void:
	var stoops := {}
	var limps := 0
	for i in 200:
		var phase := float(i) / 200.0
		var g: Dictionary = DeadPose.gait(phase)
		assert_eq(g, DeadPose.gait(phase), "it never changes")
		assert_between(float(g["stoop"]), 0.0, DeadPose.STOOP_MAX)
		stoops[snappedf(float(g["stoop"]), 0.02)] = true
		if g["limp"]:
			limps += 1
	assert_gt(stoops.size(), 6, "not all the same")
	assert_between(limps, 40, 100, "about one in three drags a leg")


func test_a_limping_body_rocks_only_while_it_walks() -> void:
	var z := _one()
	z["phase"] = 0.02
	for i in 100:
		if DeadPose.gait(float(z["phase"]))["limp"]:
			break
		z["phase"] += 0.01
	assert_true(DeadPose.gait(float(z["phase"]))["limp"])
	var still: Basis = DeadPose.gait_basis(z)
	assert_true(still.is_equal_approx(DeadPose.gait_basis(z)), "standing, it does not rock")
	z["pos"] += Vector3(0.2, 0, 0)
	assert_false(still.is_equal_approx(DeadPose.gait_basis(z)), "a step, and it does")
	var z2 := _one()
	z2["phase"] = z["phase"] + 0.37
	assert_false(DeadPose.gait_basis(z2).is_equal_approx(still), "another body stands another way")
