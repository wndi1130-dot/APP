extends "res://addons/gut/test.gd"
## Zombie senses and sewer exits on the real field (headless, no rendering checks).

const FieldGame = preload("res://game/field_game.gd")
const SimNoise = preload("res://game/sim/noise.gd")

var game


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	# A quiet field: only the zombies a test places.
	game.zombies.list.clear()
	game.pending_spawn.clear()


func _zombie(at: Vector3) -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", at)
	z["angle"] = 0.0
	return z


func test_idle_dead_turn_before_walking_to_a_sound() -> void:
	var z := _zombie(Vector3(40.5, 0, 7.5))
	var start: Vector3 = z["pos"]
	game.zombies.hear(Vector3(46.5, 0, 7.5), SimNoise.Level.NORMAL, 12.0)
	assert_eq(z["state"], "investigate")
	assert_gt(float(z["turn_t"]), 0.0, "it turns first")
	game.zombies._move(z, 0.1)
	assert_eq(z["pos"], start, "no step while turning")
	for i in range(20):
		game.zombies._move(z, 0.1)
	assert_gt(z["pos"].distance_to(start), 0.3, "then walks")


func test_fainter_sound_does_not_steal_a_louder_clue() -> void:
	var z := _zombie(Vector3(40.5, 0, 7.5))
	var loud := Vector3(60.5, 0, 7.5)
	game.zombies.hear(loud, SimNoise.Level.LOUD, 35.0)
	game.zombies.hear(Vector3(43.5, 0, 7.5), SimNoise.Level.NORMAL, 12.0)
	assert_eq(z["target"], loud, "keeps walking to the gunshot")
	game.zombies.hear(Vector3(30.5, 0, 7.5), SimNoise.Level.VERY_LOUD, 200.0)
	assert_eq(z["target"], Vector3(30.5, 0, 7.5), "a louder one wins")


func test_chasing_dead_ignore_sounds() -> void:
	var z := _zombie(Vector3(40.5, 0, 7.5))
	z["state"] = "chase"
	z["target"] = Vector3(41.5, 0, 7.5)
	game.zombies.hear(Vector3(50.5, 0, 7.5), SimNoise.Level.LOUD, 35.0)
	assert_eq(z["state"], "chase")


func test_nobody_climbs_out_under_someone_the_other_exit_takes_it() -> void:
	var lid: Vector3 = game.FieldGrid.center(game.data["entries"]["manhole"][0])
	game.player.position = lid + Vector3(1, 0, 0)
	for q in game.squad:
		if q != game.player:
			q.position = Vector3(30, 0, 7)
	game.pending_spawn.append({"entry": "manhole", "pos": lid, "t": 0.0, "horde": 0, "target": Vector3(50, 0, 7)})
	var before: int = game.zombies.list.size()
	game.clock.elapsed = 1.0
	game._update_spawns(0.1)
	assert_eq(game.zombies.list.size(), before, "nothing climbs out at the player's feet")
	assert_eq(game.pending_spawn[0]["entry"], "culvert", "the culvert takes the share")
	for i in range(8):
		game.clock.elapsed += 0.5
		game._update_spawns(0.5)
	assert_eq(game.zombies.list.size(), before + 1, "it comes out of the culvert after its rattle")
	var z: Dictionary = game.zombies.list[game.zombies.list.size() - 1]
	assert_gt(z["pos"].distance_to(lid), 20.0)


func test_lost_target_search_is_short_then_wander() -> void:
	var z := _zombie(Vector3(40.5, 0, 7.5))
	game.zombies._begin_search(z, Vector3(40.5, 0, 7.5))
	for i in range(50):
		game.zombies._move(z, 0.1)
	assert_eq(z["state"], "wander", "four seconds of looking around, then back to wandering")


func test_blood_smell_pulls_to_the_spot_not_the_bleeder() -> void:
	var z := _zombie(Vector3(40.5, 0, 7.5))
	# Wind blows toward +x on this map: a bleeder upwind (west) reaches 12 x 0.6 x 1.5 m.
	var spot := Vector3(34.5, 0, 7.5)
	assert_eq(game.zombies.smell(spot, 12.0), 1)
	assert_eq(z["target"], spot)
	var frozen: Dictionary = game.zombies.spawn("frozen", Vector3(36.5, 0, 7.5))
	game.zombies.smell(spot, 12.0)
	assert_eq(frozen["state"], "frozen", "smell does not wake the frozen")


func test_blood_smell_is_short_upwind() -> void:
	var z := _zombie(Vector3(40.5, 0, 7.5))
	assert_eq(game.zombies.smell(Vector3(46.5, 0, 7.5), 12.0), 0, "6 m upwind in the cold is out of reach")
	assert_eq(z["state"], "wander")


func test_dead_far_from_the_player_still_notice_a_companion_beside_them() -> void:
	var far: Vector3 = game.lift(Vector2i(130, 7), 0)
	for q in game.squad:
		q.position = far
	var ally = game.squad[1]
	ally.position = game.lift(Vector2i(20, 7), 0)
	var z := _zombie(ally.position + Vector3(1.5, 0, 0))
	assert_gt(z["pos"].distance_to(game.player.position), 32.0)
	for i in range(20):
		game.zombies.update(0.1)
	assert_true(z["state"] in ["chase", "attack", "grab"], "the companion is seen even with the player far away")


# ---------------------------------------------------------------- hordes and hiding

func test_a_horde_walks_to_the_last_loud_sound_not_to_the_player() -> void:
	game.player.position = Vector3(120.5, 0, 60.5)
	assert_eq(game.horde_target(), game.FieldGrid.center(game.HORDE_HOME), "no sound yet: the platform")
	game.make_sound(Vector3(30.5, 0, 33.5), SimNoise.Level.NORMAL, "step")
	assert_eq(game.horde_target(), game.FieldGrid.center(game.HORDE_HOME), "a normal sound is not followed")
	var bang := Vector3(80.5, 0, 33.5)
	game.make_sound(bang, SimNoise.Level.LOUD, "glass")
	game.zombies.list.clear()
	game._start_horde({"index": 0, "size": 6, "entry": "east_track"})
	assert_eq(game.pending_spawn.size(), 6)
	for s in game.pending_spawn:
		assert_eq(s["target"], bang)


func test_unseen_and_quiet_for_thirty_seconds_puts_the_next_horde_back() -> void:
	var d = game.director
	var z := _zombie(Vector3(40.5, 0, 7.5))
	z["state"] = "chase"
	z["victim"] = game.player
	game.clock.elapsed = 100.0
	game._update_hordes(0.1)
	assert_true(d.lost_armed, "something is after the squad")
	var due: float = d.next_arrival
	game.clock.elapsed = 140.0
	game._update_hordes(0.1)
	assert_almost_eq(d.next_arrival, due, 0.001, "still chased: no breather")
	z["state"] = "wander"
	game.clock.elapsed = 169.0
	game._update_hordes(0.1)
	assert_almost_eq(d.next_arrival, due, 0.001, "29 seconds is not enough")
	game.clock.elapsed = 171.0
	game._update_hordes(0.1)
	assert_almost_eq(d.next_arrival, due + d.LOST_REST, 0.001)
	assert_true(game.radio.contains("놓친"), "the driver says so")
	assert_eq(d.losses_left(), 2)


func test_a_loud_sound_starts_the_quiet_count_over() -> void:
	var d = game.director
	game.clock.elapsed = 100.0
	game.make_sound(Vector3(30.5, 0, 33.5), SimNoise.Level.LOUD, "glass")
	game.zombies.list.clear()
	var due: float = d.next_arrival
	game.clock.elapsed = 120.0
	game.make_sound(Vector3(30.5, 0, 33.5), SimNoise.Level.LOUD, "glass")
	game.zombies.list.clear()
	due = d.next_arrival
	game.clock.elapsed = 140.0
	game._update_hordes(0.1)
	assert_almost_eq(d.next_arrival, due, 0.001)
	game.clock.elapsed = 150.0
	game._update_hordes(0.1)
	assert_almost_eq(d.next_arrival, due + d.LOST_REST, 0.001)


func test_the_dead_after_a_raider_do_not_count() -> void:
	var z := _zombie(Vector3(40.5, 0, 7.5))
	z["state"] = "chase"
	var Person = preload("res://game/actors/person.gd")
	var r = Person.new()
	add_child_autofree(r)
	r.setup("r", "r", "raider", Vector3(41.5, 0, 7.5))
	z["victim"] = r
	assert_false(game._squad_hunted())
	z["victim"] = game.player
	assert_true(game._squad_hunted())

