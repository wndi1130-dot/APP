extends "res://addons/gut/test.gd"
## The squad keeps 1.3 times farther from the chief while following (coordinator under decision 442,
## inside the decision 406 formation; player review round 1 item 9). Only the 14 spacing constants move,
## and a companion at the farthest place it may keep still goes for one of the dead biting the chief.

const FieldGame = preload("res://game/field_game.gd")
const FieldAi = preload("res://game/field_ai.gd")
const Zombies = preload("res://game/actors/zombies.gd")

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
