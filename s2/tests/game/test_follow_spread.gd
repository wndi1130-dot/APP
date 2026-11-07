extends "res://addons/gut/test.gd"
## The squad keeps 1.3 times farther from the chief while following (coordinator under decision 442,
## inside the decision 406 formation; player review round 1 item 9). The 14 spacing constants and
## the loud rescue shot threshold move; formation mates remain inside the unchanged rescue radius.

const FieldGame = preload("res://game/field_game.gd")
const FieldAi = preload("res://game/field_ai.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const Zombies = preload("res://game/actors/zombies.gd")
const Weapons = preload("res://game/sim/weapons.gd")

const SPREAD: float = 1.3
const EPS: float = 0.000001

var game
var ally


func _start() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.mask_on = false
	game.player.position = game.lift(Vector2i(60, 7), 0)
	game.player.facing = PI * 0.5        # looking along +x
	ally = null
	for q in game.squad:
		if q != game.player:
			q.position = game.lift(Vector2i(30, 7), 0)
			if ally == null:
				ally = q
	ally.facing = PI * 0.5
	ally.hands = [{"id": "knife", "quality": "factory", "condition": 1.0, "loaded": 0}]


func _after_chief(at: Vector3) -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", at)
	z["state"] = "chase"
	z["victim"] = game.player
	return z


func _near_v2(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) <= EPS


func test_the_spread_is_one_knob_over_exactly_the_fourteen_spacing_constants() -> void:
	# A script resource held in a variable: calling its methods on the class name is a parse error.
	# Read through the constant map so the file also loads on a field_ai.gd without the knob.
	var ai_script: GDScript = FieldAi
	var consts: Dictionary = ai_script.get_script_constant_map()
	assert_almost_eq(float(consts.get("FOLLOW_SPREAD", 1.0)), SPREAD, EPS, "FOLLOW_SPREAD")
	var offsets: Array = FieldAi.FOLLOW_OFFSETS
	var base_offsets: Array[Vector2] = [Vector2(-1.3, -1.2), Vector2(1.3, -1.2), Vector2(0.0, -2.4)]
	assert_eq(offsets.size(), base_offsets.size())
	for i: int in base_offsets.size():
		assert_true(_near_v2(offsets[i], base_offsets[i] * SPREAD), "FOLLOW_OFFSETS[%d]" % i)
	var floats := {"FOLLOW_POINT_SIDE": 2.1, "FOLLOW_REAR_BACK": 2.5, "FOLLOW_WALK_MIN": 2.0, "FOLLOW_WALK_MAX": 4.0,
		"FOLLOW_SIDE_MAX": 3.0, "FOLLOW_REAR_MAX": 3.5, "FOLLOW_IDLE_MIN": 1.5, "FOLLOW_IDLE_MAX": 2.5}
	var vectors := {"FOLLOW_SIDE": Vector2(2.4, -0.6), "FOLLOW_IDLE_POINT": Vector2(1.2, 1.6),
		"FOLLOW_IDLE_SIDE": Vector2(1.8, -0.8), "FOLLOW_IDLE_REAR": Vector2(0.0, -2.0), "FOLLOW_IDLE_ASIDE": Vector2(-2.0, -0.5)}
	for key: String in floats:
		assert_almost_eq(float(consts[key]), float(floats[key]) * SPREAD, EPS, key)
	for key: String in vectors:
		assert_true(_near_v2(consts[key], vectors[key] * SPREAD), key)
	assert_eq(1 + floats.size() + vectors.size(), 14, "the fourteen")
	# Timing, path and door constants keep their own values (the spread is spacing only).
	var kept := {"FOLLOW_LEAD_S": 1.0, "FOLLOW_BUFFER_S": 0.6, "FOLLOW_PATH_NEAR": 0.12, "FOLLOW_RUN_ON": 4.5,
		"FOLLOW_RUN_OFF": 2.5, "FOLLOW_ROOM": 0.95, "FOLLOW_SLOT_STEP": 1.0, "FOLLOW_SETTLE": 0.3,
		"FOLLOW_POINT_CLEAR": 1.5, "FOLLOW_TRAIL_STEP": 0.6, "FOLLOW_QUEUE_GAP": 1.25, "FOLLOW_QUEUE_WAIT": 0.9,
		"FOLLOW_QUEUE_RESUME": 1.45, "FOLLOW_DOOR_RECENT": 5.0}
	for key: String in kept:
		assert_almost_eq(float(consts[key]), float(kept[key]), EPS, key + " is not spacing")


func test_every_place_a_companion_keeps_is_within_reach_of_the_dead_biting_the_chief() -> void:
	var far: Array[float] = [FieldAi.FOLLOW_WALK_MAX, FieldAi.FOLLOW_SIDE_MAX, FieldAi.FOLLOW_REAR_MAX,
		FieldAi.FOLLOW_IDLE_MAX, FieldAi.FOLLOW_POINT_SIDE, FieldAi.FOLLOW_REAR_BACK]
	for v: Vector2 in FieldAi.FOLLOW_OFFSETS:
		far.append(v.length())
	for v: Vector2 in [FieldAi.FOLLOW_SIDE, FieldAi.FOLLOW_IDLE_POINT, FieldAi.FOLLOW_IDLE_SIDE,
			FieldAi.FOLLOW_IDLE_REAR, FieldAi.FOLLOW_IDLE_ASIDE]:
		far.append(v.length())
	var farthest: float = 0.0
	for d: float in far:
		farthest = maxf(farthest, d)
		# One of the dead biting the chief stands at most ATTACK_RANGE from him, on any side.
		assert_lte(d + Zombies.ATTACK_RANGE, FieldAi.ENGAGE_R, "%.3f m + bite reach inside ENGAGE_R" % d)
		assert_lte(d, FieldAi.LEASH_R, "%.3f m inside the leash" % d)
	assert_almost_eq(farthest, FieldAi.FOLLOW_WALK_MAX, EPS, "the walking band edge is the farthest")
	# Stopped, a companion also covers the dead that only stand by the chief (GUARD_R) on its far side.
	assert_lte(FieldAi.FOLLOW_IDLE_MAX + FieldAi.GUARD_R, FieldAi.ENGAGE_R, "idle edge + GUARD_R")


func test_a_companion_at_the_walking_band_edge_goes_for_the_dead_biting_the_chief_on_the_far_side() -> void:
	_start()
	ally.position = game.player.position + Vector3(-FieldAi.FOLLOW_WALK_MAX, 0, 0)   # behind him, facing him
	var z := _after_chief(game.player.position + Vector3(Zombies.ATTACK_RANGE, 0, 0))
	assert_almost_eq(ally.position.distance_to(z["pos"]), FieldAi.FOLLOW_WALK_MAX + Zombies.ATTACK_RANGE, 0.001)
	assert_eq(game.ai._squad_threat(ally), z, "within ENGAGE_R of the farthest companion")
	game.ai._companion(ally)
	assert_eq(ally.target_zombie, z, "goes for it")


func test_the_side_edge_reaches_round_the_chief_too() -> void:
	_start()
	ally.position = game.player.position + Vector3(0, 0, FieldAi.FOLLOW_SIDE_MAX)
	ally.facing = PI                      # looking along -z, toward the chief
	var z := _after_chief(game.player.position + Vector3(0, 0, -Zombies.ATTACK_RANGE))
	assert_eq(game.ai._squad_threat(ally), z, "side band edge, the dead on the chief's other side")


func test_the_check_is_live_past_engage_r_nothing_is_taken_up() -> void:
	# The same scene with the dead just past ENGAGE_R of the companion (still after the chief, inside
	# the leash) is left alone, so the two tests above measure ENGAGE_R and not some wider reach.
	_start()
	ally.position = game.player.position + Vector3(-FieldAi.FOLLOW_WALK_MAX, 0, 0)
	var past: float = FieldAi.ENGAGE_R + 0.25 - FieldAi.FOLLOW_WALK_MAX
	assert_lt(past, FieldAi.LEASH_R)
	_after_chief(game.player.position + Vector3(past, 0, 0))
	assert_true(game.ai._squad_threat(ally).is_empty(), "past ENGAGE_R: not taken up")


func _hand(id: String, loaded: int = 0) -> Dictionary:
	return {"id": id, "quality": "factory", "condition": 1.0, "loaded": loaded}


func _start_floor() -> Array:
	_start()
	# The same real grid and walkable_near path as test_follow_formation, without a map mock.
	game.grid = FieldGrid.new(40, 40)
	game.levels = {0: game.grid}
	game.grid.refresh_paths()
	game.player.position = Vector3(20.5, 0, 20.5)
	game.player.stop()
	game.player.aim.stop()
	var mates: Array = []
	for q in game.squad:
		if q == game.player:
			continue
		q.stop()
		q.cancel_action()
		q.aim.stop()
		q.brain.clear()
		q.command = "follow"
		q.hands = [_hand("knife")]
		q.skills["strength"] = 20 if mates.is_empty() else 0
		q.skills["melee"] = 0
		q.skills["shooting"] = 20 if mates.size() == 2 else 0
		q.position = Vector3(5.5, 0, 8.5 + mates.size() * 3.0)
		mates.append(q)
	return game.ai._follow_mates()


func _slots(mates: Array, fwd: Vector3) -> Array[Vector3]:
	var right := Vector3(fwd.z, 0, -fwd.x)
	var result: Array[Vector3] = []
	for q in mates:
		result.append(game.ai._follow_spot(q, mates, fwd, right))
	return result


func _assert_slot_distances(slots: Array[Vector3]) -> void:
	for i in range(slots.size()):
		assert_true(slots[i].is_finite(), "finite slot %d" % i)
		if not slots[i].is_finite():
			return
		assert_true(game.grid.people_can_walk(FieldGrid.cell_of(slots[i])), "walkable slot %d" % i)
		for j in range(i):
			assert_gt(slots[i].distance_to(slots[j]), FieldAi.FOLLOW_ROOM, "separate slots %d/%d" % [i, j])
			assert_lt(slots[i].distance_to(slots[j]), FieldAi.RESCUE_R, "rescue reach %d/%d" % [i, j])


func _require_ai_method(method: String) -> bool:
	# A missing helper on e434f7b4 is a normal failed assertion, never SCRIPT ERROR.
	var ai_script: GDScript = FieldAi
	var present: bool = ai_script.has_method(method)
	assert_true(present, method)
	return present


func _shifted_rescue_floor() -> Array:
	var mates := _start_floor()
	game.player.moving = true
	# The side mate's body rules out the point's base slot: +1 is still a full metre clear.
	mates[1].position = game.player.position + Vector3(FieldAi.FOLLOW_POINT_SIDE, 0, FieldAi.LEAD_AHEAD)
	# At the rear, the old first valid candidate is (-3, -3.25). The nearest-cell fallback
	# for -2 lands at (-3, -4), outside the rear band, so this exercises the real wall path.
	for z in range(16, 19):
		for x in range(18, 26):
			game.grid.set_solid(Vector2i(x, z), FieldGrid.Solid.WALL)
	game.grid.refresh_paths()
	return mates


func _grab_chief() -> Dictionary:
	var z := _after_chief(game.player.position)
	z["state"] = "grab"
	game.player.grabbers.append(z)
	game.player.grab_left = 2.0
	return z


func test_unit_spread_keeps_legacy_candidate_order_for_every_role() -> void:
	if not _require_ai_method("_follow_slot_shifts"):
		return
	var ai_script: GDScript = FieldAi
	var legacy: Array[int] = [0, 1, -1, 2, -2, 3, -3, 4, -4]
	for side in [2.1, 2.4, -2.4, 0.0, 1.2, 1.8, -2.0]:
		var minimum: float = FieldAi.FOLLOW_POINT_CLEAR if side == 2.1 else FieldAi.FOLLOW_ROOM
		var shifts: Array = ai_script.call("_follow_slot_shifts", side, minimum)
		assert_eq(shifts, legacy, "1.0 spread: side %.2f" % side)


func test_scaled_candidate_width_reaches_both_sides_in_near_first_order() -> void:
	if not _require_ai_method("_follow_slot_shifts"):
		return
	var ai_script: GDScript = FieldAi
	for side in [FieldAi.FOLLOW_POINT_SIDE, -FieldAi.FOLLOW_POINT_SIDE]:
		var shifts: Array = ai_script.call("_follow_slot_shifts", side, FieldAi.FOLLOW_POINT_CLEAR)
		var left := false
		var right := false
		for i in range(shifts.size()):
			var step: int = int(shifts[i])
			if i == 0:
				assert_eq(step, 0)
			elif i % 2 == 1:
				assert_eq(step, (i + 1) >> 1, "near first, positive first")
			else:
				assert_eq(step, -int(shifts[i - 1]), "then the matching negative step")
			var lateral: float = float(side) + float(step) * FieldAi.FOLLOW_SLOT_STEP
			left = left or lateral <= -FieldAi.FOLLOW_POINT_CLEAR
			right = right or lateral >= FieldAi.FOLLOW_POINT_CLEAR
		assert_true(left and right, "both sides clear the minimum")


func test_point_gets_a_left_front_slot_when_the_right_is_walled() -> void:
	var mates := _start_floor()
	game.player.moving = true
	for z in range(15, 29):
		for x in range(21, 29):
			game.grid.set_solid(Vector2i(x, z), FieldGrid.Solid.WALL)
	game.grid.refresh_paths()
	var spot: Vector3 = game.ai._follow_spot(mates[0], mates, Vector3.BACK, Vector3.RIGHT)
	var rel: Vector3 = spot - game.player.position
	assert_gt(rel.z, 0.0, "the point still leads")
	assert_lte(rel.x, -FieldAi.FOLLOW_POINT_CLEAR + FieldAi.FOLLOW_EPS, "the open left side")
	assert_true(game.grid.people_can_walk(FieldGrid.cell_of(spot)))


func test_multiple_fallbacks_clear_other_bodies_and_each_claimed_slot() -> void:
	var mates := _start_floor()
	game.player.moving = true
	game.ai._live_on = true
	for q in mates:
		game.ai._roles[q] = "point"
	# Every front slot is walled, and another mate already occupies the old shared fallback.
	mates[2].position = game.player.position - Vector3.BACK * FieldAi.FOLLOW_WALK_MIN
	for z in range(21, 29):
		for x in range(12, 29):
			game.grid.set_solid(Vector2i(x, z), FieldGrid.Solid.WALL)
	game.grid.refresh_paths()
	var slots := _slots(mates, Vector3.BACK)
	_assert_slot_distances(slots)
	for i in range(mates.size()):
		assert_lte(slots[i].z, game.player.position.z, "uses the rear fallback")
		for other in game.squad:
			if other != mates[i]:
				assert_gt(slots[i].distance_to(other.position), FieldAi.FOLLOW_ROOM, "clears a live body")


func test_no_free_walkable_slot_keeps_each_current_position_finite() -> void:
	var mates := _start_floor()
	game.player.moving = true
	game.grid.solid.fill(FieldGrid.Solid.WALL)
	for q in game.squad:
		game.grid.set_solid(FieldGrid.cell_of(q.position), FieldGrid.Solid.NONE)
	game.grid.refresh_paths()
	var slots := _slots(mates, Vector3.BACK)
	_assert_slot_distances(slots)
	for i in range(mates.size()):
		assert_eq(slots[i], mates[i].position, "no invented destination inside a wall or another body")


func test_shifted_front_and_rear_slots_stay_inside_rescue_reach() -> void:
	var mates := _shifted_rescue_floor()
	var slots := _slots(mates, Vector3.BACK)
	var expected_point: Vector3 = game.player.position + Vector3(FieldAi.FOLLOW_POINT_SIDE + 1.0, 0, FieldAi.LEAD_AHEAD)
	assert_lt(slots[0].distance_to(expected_point), FieldAi.FOLLOW_EPS, "point shift +1 fixture")
	_assert_slot_distances(slots)


func test_three_mate_slots_keep_rescue_reach_across_directions_and_roles() -> void:
	var roster := _start_floor()
	game.ai._live_on = true
	var role_sets: Array = [["point", "side", "rear"], ["rear", "point", "side"],
		["point", "point", "rear"], ["side", "side", "rear"]]
	for roles: Array in role_sets:
		for i in range(roster.size()):
			game.ai._roles[roster[i]] = roles[i]
		var mates: Array = game.ai._follow_mates()
		assert_eq(mates.size(), 3)
		for walking in [false, true]:
			game.player.moving = walking
			for aiming in [false, true]:
				game.player.aim.active = aiming
				for angle in [0.0, PI * 0.25, PI * 0.5, PI * 0.75, PI, PI * 1.25, PI * 1.5, PI * 1.75]:
					_assert_slot_distances(_slots(mates, Vector3(sin(angle), 0, cos(angle))))


func test_settled_formation_mates_can_select_each_held_mate() -> void:
	var mates := _shifted_rescue_floor()
	var slots := _slots(mates, Vector3.BACK)
	for held_index in range(mates.size()):
		for rescuer_index in range(mates.size()):
			if held_index == rescuer_index:
				continue
			for i in range(mates.size()):
				mates[i].position = slots[i]
				mates[i].grabbers.clear()
				mates[i].brain.erase("rescue")
			var held = mates[held_index]
			var rescuer = mates[rescuer_index]
			var away: Vector3 = (rescuer.position - held.position).normalized()
			rescuer.position += away * FieldAi.FOLLOW_SETTLE
			held.position -= away * FieldAi.FOLLOW_SETTLE
			var z: Dictionary = game.zombies.spawn("dead", held.position)
			z["state"] = "grab"
			z["victim"] = held
			held.grabbers.append(z)
			assert_lt(rescuer.position.distance_to(held.position), FieldAi.RESCUE_R)
			assert_eq(game.ai._held_mate(rescuer), held, "both settle errors still leave rescue reach")
			game.zombies.list.erase(z)


func test_slot_distance_rule_reserves_two_settle_errors_and_body_room() -> void:
	if not _require_ai_method("_follow_slot_clear"):
		return
	var ai_script: GDScript = FieldAi
	var occupied: Array[Vector3] = [Vector3.ZERO]
	var empty: Array[Vector3] = []
	assert_false(ai_script.call("_follow_slot_clear", Vector3.RIGHT * (FieldAi.FOLLOW_ROOM - 0.01), occupied, empty))
	assert_true(ai_script.call("_follow_slot_clear", Vector3.RIGHT * (FieldAi.FOLLOW_ROOM + 0.01), occupied, empty))
	var claimed: Array[Vector3] = [Vector3.ZERO]
	assert_false(ai_script.call("_follow_slot_clear", Vector3.ZERO, empty, claimed))
	var limit: float = FieldAi.RESCUE_R - 2.0 * FieldAi.FOLLOW_SETTLE
	assert_true(ai_script.call("_follow_slot_clear", Vector3.RIGHT * (limit - 0.01), empty, claimed))
	assert_false(ai_script.call("_follow_slot_clear", Vector3.RIGHT * limit, empty, claimed), "strict rescue radius after settling")
	assert_false(ai_script.call("_follow_slot_clear", Vector3.RIGHT * (limit + 0.01), empty, claimed))


func test_default_point_slot_uses_the_blade_in_the_rescue_weapon_decision() -> void:
	var mates := _start_floor()
	var point = mates[0]
	point.hands = [_hand("knife"), _hand("pistol", 8)]
	point.position = game.player.position + Vector3(FieldAi.FOLLOW_POINT_SIDE, 0, FieldAi.LEAD_AHEAD)
	var z := _grab_chief()
	var d: float = point.position.distance_to(z["pos"])
	assert_gt(int(Weapons.get_data("pistol")["sound"]), 0)
	assert_between(d, 4.0, 4.1, "the scaled default front slot is about 4.06 m away")
	assert_false(game.ai._should_shoot(point, z, d))
	assert_false(game.ai._should_shoot(point, z, 4.0 * SPREAD), "exactly 5.2 m still keeps the blade")
	# Test the weapon branch directly: _companion routes an actual grab to _rescue first.
	game.ai._engage(point, z)
	assert_false(point.aim.active)
	assert_eq(point.target_zombie, z, "walks in with the blade")
	assert_eq(point.weapon_id(), "knife")


func test_loud_rescue_shot_still_starts_beyond_the_scaled_threshold() -> void:
	var mates := _start_floor()
	var point = mates[0]
	point.hands = [_hand("pistol", 8), _hand("knife")]
	point.position = game.player.position + Vector3(4.0 * SPREAD + 0.1, 0, 0)
	var z := _grab_chief()
	assert_true(game.ai._should_shoot(point, z, point.position.distance_to(z["pos"])))
	game.ai._engage(point, z)
	assert_true(point.aim.active, "past 5.2 m the loud gun still comes up")
	assert_true(point.target_zombie.is_empty())


func test_actual_grab_keeps_rescue_priority_over_the_weapon_decision() -> void:
	var mates := _start_floor()
	var point = mates[0]
	point.hands = [_hand("pistol", 8), _hand("knife")]
	point.position = game.player.position + Vector3(FieldAi.FOLLOW_POINT_SIDE, 0, FieldAi.LEAD_AHEAD)
	_grab_chief()
	game.ai._companion(point)
	assert_eq(point.brain.get("rescue"), game.player)
	assert_false(point.path.is_empty())
	assert_false(point.aim.active, "actual grabs use the existing shove rescue on both revisions")


func test_save_far_scales_and_other_help_and_formation_limits_stay_fixed() -> void:
	assert_almost_eq(FieldAi.SAVE_FAR, 4.0 * SPREAD, EPS)
	assert_almost_eq(FieldAi.RESCUE_R, 9.0, EPS)
	assert_almost_eq(FieldAi.SAVE_NEAR, 2.0, EPS)
	assert_almost_eq(FieldAi.SHOOT_MIN, 3.0, EPS)
	assert_almost_eq(FieldAi.FOLLOW_POINT_CLEAR, 1.5, EPS)
	assert_almost_eq(FieldAi.FOLLOW_TRAIL_STEP, 0.6, EPS)
	assert_almost_eq(FieldAi.LEAD_AHEAD, 3.0, EPS)
	assert_eq(FieldAi.LOOK_KEYS, ["watch_point", "watch_side", "watch_rear", "watch_aside", "watch_escort"])
