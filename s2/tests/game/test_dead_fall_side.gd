extends "res://addons/gut/test.gd"
## Only the picture within each fall pair changes; the clocks and rules do not.
## The legacy hash below is frozen from 0841747c, not read from the new picker.

const DeadBody = preload("res://game/actors/dead_body.gd")
const DeadPose = preload("res://game/actors/dead_pose.gd")
const Zombies = preload("res://game/actors/zombies.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const BodyBake = preload("res://scripts/body_bake.gd")
const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const WAYS: Array[String] = ["shove", "axe_top", "stab", "other"]
const PAIRS: Dictionary = {
	"shove": [DeadBody.FALL_THROWN, DeadBody.FALL_FRONT],
	"axe_top": [DeadBody.FALL, DeadBody.FALL_SLUMP],
	"stab": [DeadBody.FALL_THROWN, DeadBody.FALL_FRONT],
}


class NearbyPerson extends RefCounted:
	var position := Vector3.ZERO
	var body := {"dead": false}


class World extends RefCounted:
	var grid = FieldGrid.new(32, 32)
	var stairs: Array = []
	var people: Array = []
	var rng := RandomNumberGenerator.new()
	var opts := {"seed": 413}
	var killed: Array[int] = []

	func level_of(at: Vector3) -> int:
		return roundi(at.y / 3.0)

	func level_y(level: int) -> float:
		return level * 3.0

	func grid_at(_at: Vector3):
		return grid

	func people_alive() -> Array:
		return people

	func on_zombie_killed(z: Dictionary) -> void:
		killed.append(int(z["id"]))


var world
var zombies
var _saved_table: Array
var _saved_rounds: Dictionary
var _saved_named: Dictionary


func before_each() -> void:
	_saved_table = DeadBody.table
	_saved_rounds = DeadBody.rounds
	_saved_named = DeadBody.named
	DeadBody.rounds = {}
	DeadBody.named = {}
	_table(DeadBody.FALL_SLUMP + 1)
	world = World.new()
	world.rng.seed = 413
	zombies = Zombies.new()
	zombies.game = world
	add_child_autofree(zombies)


func after_each() -> void:
	DeadBody.table = _saved_table
	DeadBody.rounds = _saved_rounds
	DeadBody.named = _saved_named


func _table(count: int) -> void:
	DeadBody.table = []
	for i in count:
		DeadBody.table.append([i * 32, 32, false, 0.75])


func _body(front: bool = false, phase: float = 0.1) -> Dictionary:
	zombies.list.clear()
	var z: Dictionary = zombies.spawn("dead", Vector3(10.5, 0, 10.5))
	z["state"] = "chase"
	z["angle"] = 0.0
	z["phase"] = phase
	z["age"] = 10.0
	z["loot"] = []  # Pocket rolls have their own tests; only game.rng is at issue here.
	var p := NearbyPerson.new()
	p.position = z["pos"] + Vector3(0, 0, -1.0 if front else 1.0)
	world.people = [p]
	zombies._people = world.people
	return z


func _hit(z: Dictionary, way: String, since: float = 0.0) -> void:
	z["hit_way"] = way
	z["hit_at"] = float(z["age"]) - since


func _legacy_motion(phase: float, front: bool) -> int:
	if fposmod(phase * 5.17, 1.0) < 0.5:
		return DeadBody.FALL_SLUMP if front else DeadBody.FALL_THROWN
	return DeadBody.FALL_FRONT if front else DeadBody.FALL


func _want(by: String, front: bool, phase: float) -> int:
	return int(PAIRS[by][1 if front else 0]) if PAIRS.has(by) else _legacy_motion(phase, front)


func _picture(z: Dictionary) -> Color:
	return DeadBody.picked(z, DeadPose.down_k(z), 0.0, 1.0, true)


func test_pure_variant_covers_all_eight_cells() -> void:
	# Dynamic call keeps this file loadable on 0841747c: it fails this assertion.
	var present := false
	for method: Dictionary in DeadBody.get_script_method_list():
		present = present or String(method["name"]) == "fall_variant"
	assert_true(present, "the pure fall_variant function exists")
	if not present:
		return
	for by in WAYS:
		for front in [false, true]:
			for phase in [0.0, 0.1, 0.37, 0.99]:
				assert_eq(int(DeadBody.call("fall_variant", by, front, phase)), _want(by, front, phase), "%s front=%s phase=%s" % [by, front, phase])


func test_fall_motion_uses_the_recorded_way_for_both_hash_halves() -> void:
	for by in WAYS:
		for front in [false, true]:
			for phase in [0.0, 0.1]:
				var z := {"phase": phase, "fall_by": by}
				assert_eq(DeadBody.fall_motion(z, front), _want(by, front, phase), "%s front=%s phase=%s" % [by, front, phase])


func test_other_missing_and_unknown_ways_keep_the_legacy_hash() -> void:
	for n in range(-20, 221):
		var phase := float(n) / 200.0
		for front in [false, true]:
			var z := {"phase": phase}
			var want := _legacy_motion(phase, front)
			assert_eq(DeadBody.fall_motion(z, front), want, "a body without the key")
			for by in ["other", "", "unrecognised"]:
				z["fall_by"] = by
				assert_eq(DeadBody.fall_motion(z, front), want, "unknown causes use the old hash")


func test_same_inputs_repeat_without_mutation_or_random_draws() -> void:
	for by in WAYS:
		var z := {"phase": 0.1, "fall_by": by}
		var before := z.duplicate(true)
		var rng_state: int = world.rng.state
		for front in [false, true]:
			var first := DeadBody.fall_motion(z, front)
			for _i in 20:
				assert_eq(DeadBody.fall_motion(z, front), first)
		assert_eq(z, before)
		assert_eq(world.rng.state, rng_state)


func test_missing_clips_use_each_sides_default_including_partial_tables() -> void:
	for count in [0, DeadBody.STAGGER + 1, DeadBody.FALL_THROWN + 1, DeadBody.FALL_SLUMP + 1]:
		_table(count)
		for by in WAYS:
			for front in [false, true]:
				for phase in [0.0, 0.1]:
					var chosen := _want(by, front, phase)
					var want := chosen if chosen < count else (DeadBody.FALL_FRONT if front else DeadBody.FALL)
					assert_eq(DeadBody.fall_motion({"phase": phase, "fall_by": by}, front), want, "count=%s %s front=%s" % [count, by, front])


func test_current_melee_is_recorded_by_real_knock_down_and_kill() -> void:
	for row in [["p_swing_axe", "axe_top"], ["p_stab", "stab"], ["p_swing", "other"], ["p_swing_back", "other"], ["", "other"], ["unknown", "other"]]:
		for lethal in [false, true]:
			for front in [false, true]:
				var z := _body(front)
				_hit(z, row[0])
				if lethal:
					zombies.kill(z)
				else:
					zombies.knock_down(z)
				assert_true(z.has("fall_by"), "the fall records a cause")
				assert_eq(String(z.get("fall_by", "missing")), row[1], "current %s lethal=%s" % [row[0], lethal])
				assert_eq(z["fell_fwd"], front, "only the people decide front/back")
				assert_eq(z["fell_at"], 10.0)
				z["age"] += 1.0
				assert_eq(int(_picture(z).g), _want(row[1], front, float(z["phase"])))


func test_stale_future_or_undated_melee_is_other_for_later_falls() -> void:
	for way in ["p_swing_axe", "p_stab"]:
		for since in [0.000001, 1.0, -0.000001]:
			for lethal in [false, true]:
				var z := _body()
				_hit(z, way, since)
				if lethal:
					zombies.kill(z)  # Guns do not stamp melee hit_at/hit_way.
				else:
					zombies.knock_down(z)
				assert_eq(String(z.get("fall_by", "missing")), "other", "only exact age equality counts")
		var undated := _body()
		undated["hit_way"] = way
		zombies.kill(undated)
		assert_eq(String(undated.get("fall_by", "missing")), "other", "a way without hit_at is not a current hit")


func test_immediate_and_delayed_shoves_record_shove_at_the_fall() -> void:
	for delayed in [false, true]:
		for front in [false, true]:
			var z := _body(front, 0.0 if delayed else 0.1)
			assert_eq(Zombies.reels_first(z), delayed, "fixture covers both real shove paths")
			_hit(z, "p_swing_axe")
			var at: Vector3 = z["pos"]
			var from: Vector3 = world.people[0].position
			var expected_rng := RandomNumberGenerator.new()
			expected_rng.state = world.rng.state
			var expected_t := expected_rng.randf_range(Zombies.GET_UP.x, Zombies.GET_UP.y)
			zombies.release(z, from, true)
			assert_eq(z["pos"], at + (at - from).normalized() * 1.3, "the rules' shove distance stays")
			if delayed:
				assert_false(z.has("fall_by"), "reeling is not a fall yet")
				assert_false(z.has("fell_at"))
				assert_eq(z["fall_in"], Zombies.SHOVED_TIME)
				zombies.update(Zombies.SHOVED_TIME)
				assert_almost_eq(float(z["t"]), expected_t - Zombies.SHOVED_TIME, 0.000001)
			else:
				assert_almost_eq(float(z["t"]), expected_t, 0.000001)
			assert_false(z.has("fall_in"))
			assert_eq(String(z.get("fall_by", "missing")), "shove", "the actual shove beats an old or same-tick hit")
			assert_eq(z["state"], "downed")
			assert_eq(z["fell_at"], z["age"], "the actual fall starts now")
			assert_eq(z["fell_fwd"], front)
			assert_eq(world.rng.state, expected_rng.state, "only the old get-up draw")


func test_another_cause_interrupts_a_pending_shove_without_becoming_shove() -> void:
	for lethal in [false, true]:
		for way in ["p_swing_axe", "p_stab", ""]:
			var z := _body(false, 0.0)
			zombies.release(z, world.people[0].position, true)
			_hit(z, way)
			if lethal:
				zombies.kill(z)
			else:
				zombies.knock_down(z)
			var want := "axe_top" if way == "p_swing_axe" else ("stab" if way == "p_stab" else "other")
			assert_eq(String(z.get("fall_by", "missing")), want)
			var fell_at: float = z["fell_at"]
			var rng_state: int = world.rng.state
			zombies.update(Zombies.SHOVED_TIME)
			assert_false(z.has("fall_in"))
			assert_eq(String(z.get("fall_by", "missing")), want, "the expired shove cannot replace a fall")
			assert_eq(z["fell_at"], fell_at)
			assert_eq(world.rng.state, rng_state, "no second knock-down draw")


func test_a_shove_without_a_fall_records_no_cause() -> void:
	var z := _body()
	zombies.release(z, world.people[0].position, false)
	zombies.update(0.1)
	assert_eq(z["state"], "chase")
	assert_false(z.has("fall_by"))
	assert_false(z.has("fell_at"))
	assert_false(z.has("fall_in"))


func test_mark_fall_default_does_not_infer_a_melee_cause() -> void:
	var z := _body()
	_hit(z, "p_swing_axe")
	DeadPose.mark_fall(z, world.people)
	assert_eq(String(z.get("fall_by", "missing")), "other", "restore callers use the default even with a hit stamp")


func test_already_down_and_crawling_bodies_do_not_replace_a_fall() -> void:
	for state in ["dead", "downed", "rising", "frozen", "waking", "chase"]:
		var z := _body()
		z["state"] = state
		z["crawl"] = state == "chase"
		z["fall_by"] = "shove"
		z["fell_at"] = 2.0
		z["fell_fwd"] = true
		_hit(z, "p_swing_axe")
		zombies.kill(z)
		assert_eq(z["fall_by"], "shove")
		assert_eq(z["fell_at"], 2.0)
		assert_true(z["fell_fwd"])


func test_getting_up_then_falling_again_replaces_the_cause() -> void:
	var z := _body()
	_hit(z, "p_swing_axe")
	zombies.knock_down(z)
	assert_eq(String(z.get("fall_by", "missing")), "axe_top")
	z["t"] = 0.01
	zombies.update(0.02)
	assert_eq(z["state"], "wander")
	assert_eq(DeadPose.down_k(z), 0.0)
	assert_false(z.has("fell_at"))
	var without_way := z.duplicate(true)
	without_way.erase("fall_by")
	assert_eq(_picture(z.duplicate(true)), _picture(without_way), "the retained cause is not used upright")
	zombies.knock_down(z)
	assert_eq(String(z.get("fall_by", "missing")), "other", "the first hit is now stale")
	z["t"] = 0.01
	zombies.update(0.02)
	_hit(z, "p_stab")
	zombies.kill(z)
	assert_eq(String(z.get("fall_by", "missing")), "stab", "a new fall replaces the old cause")


func test_fall_rules_match_the_prechange_clocks_positions_and_random_state() -> void:
	for front in [false, true]:
		for way in ["p_swing_axe", "p_stab", "p_swing", ""]:
			for lethal in [false, true]:
				var z := _body(front)
				_hit(z, way)
				var original := z.duplicate(true)
				var expected_rng := RandomNumberGenerator.new()
				expected_rng.state = world.rng.state
				var expected_t := 0.0 if lethal else expected_rng.randf_range(Zombies.GET_UP.x, Zombies.GET_UP.y)
				if lethal:
					zombies.kill(z)
				else:
					zombies.knock_down(z)
				assert_eq(world.rng.state, expected_rng.state)
				assert_eq(float(z["t"]), expected_t)
				assert_eq(z["fell_at"], original["age"])
				assert_eq(z["fell_fwd"], front)
				assert_eq(DeadPose.fall_side(z), 1.0 if front else -1.0)
				for key in ["pos", "home", "angle", "phase", "age", "cooldown", "stun", "loot"]:
					assert_eq(z[key], original[key], "unchanged rule field: %s" % key)
				# 0841747c's seen_pos offset, at several points of the unchanged fall.
				for since in [0.0, 0.3, 1.0]:
					z["age"] = float(original["age"]) + since
					var down := DeadPose.down_k(z)
					var turn := float(DeadPose.sprawl(float(z["phase"]))["turn"]) * down
					var expected: Vector3 = original["pos"]
					if not lethal:
						expected += Basis(Vector3.UP, turn) * Vector3(0, 0, (1.0 if front else -1.0) * 0.4 * down)
					assert_true(zombies.seen_pos(z).is_equal_approx(expected), "the 0.4 m lying hit point stays")
					_picture(z)
					assert_eq(world.rng.state, expected_rng.state, "drawing draws no game dice")


func test_rising_keeps_its_front_back_clip_for_every_cause() -> void:
	for front in [false, true]:
		for by in WAYS:
			for state in ["downed", "rising"]:
				var z := _body(front)
				z["state"] = state
				z["fell_fwd"] = front
				z["fell_at"] = 1.0
				z["fall_by"] = by
				z["t"] = 0.5
				z["rise_t"] = 0.5
				assert_eq(int(_picture(z).g), DeadBody.RISE_FRONT if front else DeadBody.RISE)


func _field():
	var game = FieldGame.new()
	game.opts = {"seed": 4, "raiders": false, "auto_pause": false}
	game.map_script = BareLine
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	_table(DeadBody.FALL_SLUMP + 1)
	return game


func test_capture_and_exact_restore_keep_the_cause_and_picture() -> void:
	var game = _field()
	var expected: Dictionary = {}
	for front in [false, true]:
		for by in WAYS:
			var z: Dictionary = game.zombies.spawn("dead", Vector3(8.5 + expected.size() * 2, 0, 8.5))
			z["angle"] = 0.0
			z["phase"] = 0.1
			z["age"] = 10.0
			z["loot"] = []
			game.player.position = z["pos"] + Vector3(0, 0, -1.0 if front else 1.0)
			game.zombies._people = [game.player]
			if by == "shove":
				game.zombies.release(z, game.player.position, true)
			else:
				_hit(z, "p_swing_axe" if by == "axe_top" else ("p_stab" if by == "stab" else "p_swing"))
				game.zombies.kill(z)
			z["age"] += 1.0
			z["shoved_t"] = 0.0
			assert_eq(String(z.get("fall_by", "missing")), by, "a real fall produced this saved cause")
			expected[z["id"]] = {"by": by, "front": front, "picture": _picture(z), "phase": z["phase"], "t": z["t"]}
	var saved := FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	assert_true(FieldSave.exact(saved))
	assert_true(FieldSave._grid_sizes_match(game, saved), "apply will take the exact branch")
	var rng_state: int = game.rng.state
	for z in game.zombies.list:
		z["fall_by"] = "tampered"
		z["phase"] = 0.0
	FieldSave.apply(game, saved)
	_table(DeadBody.FALL_SLUMP + 1)
	assert_eq(game.rng.state, rng_state)
	for id in expected:
		var back: Dictionary = game.zombies.find(int(id))
		var want: Dictionary = expected[id]
		assert_eq(String(back.get("fall_by", "missing")), want["by"])
		assert_eq(back["fell_fwd"], want["front"])
		assert_eq(back["phase"], want["phase"])
		assert_eq(back["t"], want["t"])
		assert_eq(_picture(back), want["picture"], "exact restore keeps the same drawn variant")


func test_old_exact_records_without_a_key_use_the_legacy_hash() -> void:
	var game = _field()
	var z: Dictionary = game.zombies.spawn("dead", Vector3(8.5, 0, 8.5))
	z["age"] = 10.0
	z["phase"] = 0.1
	z["loot"] = []
	game.zombies.kill(z)
	z["age"] += 1.0
	var saved := FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	assert_true(FieldSave.exact(saved))
	for row in saved["zombies"]:
		row.erase("fall_by")
	FieldSave.apply(game, saved)
	_table(DeadBody.FALL_SLUMP + 1)
	var back: Dictionary = game.zombies.find(int(z["id"]))
	assert_false(back.has("fall_by"), "an old exact record need not acquire a key")
	assert_eq(int(_picture(back).g), _legacy_motion(float(back["phase"]), bool(back["fell_fwd"])))


func test_fallback_restore_calls_mark_fall_with_other() -> void:
	var game = _field()
	var z: Dictionary = game.zombies.spawn("dead", Vector3(8.5, 0, 8.5))
	z["age"] = 10.0
	z["loot"] = []
	_hit(z, "p_swing_axe")
	game.zombies.kill(z)
	var saved := FieldSave.from_json(FieldSave.to_json(FieldSave.capture(game)))
	saved.erase("runtime")
	assert_false(FieldSave.exact(saved), "apply must use _put_zombies")
	FieldSave.apply(game, saved)
	_table(DeadBody.FALL_SLUMP + 1)
	var back: Dictionary = game.zombies.find(int(z["id"]))
	assert_eq(String(back.get("fall_by", "missing")), "other", "fallback spawns a new body without inferring a hit")
	back["age"] += 1.0
	assert_eq(int(_picture(back).g), _legacy_motion(float(back["phase"]), bool(back["fell_fwd"])))


func test_baked_last_frames_still_match_with_the_existing_tolerance() -> void:
	var baked: Dictionary = BodyBake.load_baked(DeadBody.BUILT_IN)
	assert_false(baked.is_empty())
	if baked.is_empty():
		return
	var clips: Array = baked["clips"]
	var img: Image = baked["image"]
	var look: PackedVector2Array = (baked["mesh"] as Mesh).surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	for pair in [[DeadBody.FALL, DeadBody.FALL_THROWN], [DeadBody.FALL_FRONT, DeadBody.FALL_SLUMP]]:
		var worst := 0.0
		for uv in look:
			var a := _last_offset(img, clips[pair[0]], int(baked["rows_per_frame"]), uv)
			var b := _last_offset(img, clips[pair[1]], int(baked["rows_per_frame"]), uv)
			worst = maxf(worst, a.distance_to(b))
		assert_lt(worst, 0.03, "same 0.03 m limit as test_dead_body.gd, not widened")


func _last_offset(img: Image, clip: Dictionary, rows: int, uv: Vector2) -> Vector3:
	var first := (int(clip["start"]) + int(clip["frames"]) - 1) * rows
	var c := img.get_pixel(int(uv.x * float(img.get_width())), first + int(uv.y))
	var lo := Vector3(clip["lo"][0], clip["lo"][1], clip["lo"][2])
	var hi := Vector3(clip["hi"][0], clip["hi"][1], clip["hi"][2])
	return lo + Vector3(c.r, c.g, c.b) * (hi - lo)
