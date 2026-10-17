extends "res://addons/gut/test.gd"
## Companions act like people beside you, not a bot on a string (decision 406):
## they go for what is after us without an order, fight with what suits the
## distance, put an empty gun away, walk ahead and hold the door.

const FieldGame = preload("res://game/field_game.gd")
const FieldAi = preload("res://game/field_ai.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")

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
	ally.position = game.lift(Vector2i(60, 9), 0)
	ally.facing = PI * 0.5
	ally.hands = [{"id": "knife", "quality": "factory", "condition": 1.0, "loaded": 0}]


func _hand(id: String, loaded: int = 0) -> Dictionary:
	return {"id": id, "quality": "factory", "condition": 1.0, "loaded": loaded}


func _after_chief(at: Vector3) -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", at)
	z["state"] = "chase"
	z["victim"] = game.player
	return z


func test_a_companion_goes_for_the_dead_after_the_chief_without_an_order() -> void:
	_start()
	var z := _after_chief(game.player.position + Vector3(5, 0, 0))
	assert_true(game.ai._threat_near(ally, FieldAi.THREAT_R).is_empty(), "not on the companion itself")
	game.ai._companion(ally)
	assert_eq(ally.target_zombie, z, "goes for it")


func test_a_loud_gun_waits_until_someone_is_about_to_be_caught() -> void:
	_start()
	ally.hands = [_hand("pipe_shotgun", 1), _hand("knife")]
	var z := _after_chief(game.player.position + Vector3(5, 0, 0))
	var d: float = ally.position.distance_to(z["pos"])
	assert_false(game.ai._should_shoot(ally, z, d), "far from the chief: the blade, no noise")
	game.ai._companion(ally)
	assert_false(ally.aim.active)
	assert_eq(ally.action, "swap", "the knife comes out")
	# One right at the chief and the companion too far to get there first: the gun.
	game.zombies.list.erase(z)
	ally.cancel_action()
	ally.position = game.player.position + Vector3(-6, 0, 0)
	var close := _after_chief(game.player.position + Vector3(1.5, 0, 0))
	assert_true(game.ai._should_shoot(ally, close, ally.position.distance_to(close["pos"])))


func test_the_quiet_bow_shoots_what_is_after_us() -> void:
	_start()
	ally.hands = [_hand("bow", 1), _hand("crowbar")]
	var z := _after_chief(game.player.position + Vector3(5, 0, 0))
	game.ai._companion(ally)
	assert_true(ally.aim.active, "the bow comes up")
	assert_true(ally.target_zombie.is_empty(), "no walking at it")


func test_an_empty_gun_with_nothing_to_load_goes_back_on_the_belt() -> void:
	_start()
	ally.hands = [_hand("pipe_shotgun", 0), _hand("knife")]
	game.ammo["shell"] = 0
	assert_eq(game.ai._gun_slot(ally), -1)
	game.ai._companion(ally)
	assert_eq(ally.action, "swap", "the knife comes out with nothing in sight")
	# Rounds in the pool: the gun still counts.
	game.ammo["shell"] = 2
	assert_eq(game.ai._gun_slot(ally), 0)


func test_sneaking_nobody_starts_a_fight_the_dead_have_not_started() -> void:
	_start()
	var z: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(2.0, 0, 0))
	z["state"] = "wander"
	assert_eq(game.ai._squad_threat(ally), z, "right by the chief: dealt with")
	game.player.crouched = true
	ally.brain.erase("seen_t")
	assert_true(game.ai._squad_threat(ally).is_empty(), "crouched: left alone")


func test_a_companion_does_not_chase_far_from_the_chief() -> void:
	_start()
	ally.position = game.player.position + Vector3(7, 0, 0)
	_after_chief(game.player.position + Vector3(11, 0, 0))
	assert_true(game.ai._squad_threat(ally).is_empty(), "past the leash")


func test_slow_work_is_dropped_when_one_gets_close() -> void:
	_start()
	ally.start_action("search", "뒤지기", 5.0, func() -> void: pass)
	var z: Dictionary = game.zombies.spawn("dead", ally.position + Vector3(1.5, 0, 0))
	z["state"] = "chase"
	z["victim"] = ally
	game.ai._companion(ally)
	assert_ne(ally.action, "search", "stopped searching")


func test_walking_the_strongest_blade_goes_ahead_and_the_bow_keeps_back() -> void:
	_start()
	var roles := {}
	for q in game.squad:
		if q != game.player:
			q.position = game.player.position + Vector3(-4, 0, 0)
			roles[q.pid] = game.ai._role(q)
	assert_eq(roles["p_tail_tomasz"], "point")
	assert_eq(roles["p_med_joanna"], "rear")
	assert_eq(roles["p_guard_marek"], "side")
	game.player.moving = true
	var fwd := Vector3(1, 0, 0)
	for q in game.squad:
		if q.pid == "p_tail_tomasz":
			game.ai._keep_formation(q)
			var dest: Vector3 = q.brain["dest"]
			assert_gt((dest - game.player.position).dot(fwd), 1.5, "walks ahead of the chief")
			# The chief's gun comes up: out of the way.
			game.player.aim.start("pistol", {})
			q.brain.erase("dest")
			game.ai._keep_formation(q)
			assert_lt((q.brain["dest"] - game.player.position).dot(fwd), 0.5, "steps aside")


func test_the_rear_one_holds_the_door_the_chief_went_in_by() -> void:
	_start()
	var g = game.grid
	var door := Vector2i(-1, -1)
	var outside := Vector2i.ZERO
	var inside := Vector2i.ZERO
	for dc in g.doors:
		if g.doors[dc]["state"] == "locked":
			continue
		var o_cell := Vector2i(-1, -1)
		var i_cell := Vector2i(-1, -1)
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = dc + o
			if not g.people_can_walk(n) or g.blocks_body(n):
				continue
			if g.building_at(n) < 0:
				o_cell = n
			else:
				i_cell = n
		if o_cell.x >= 0 and i_cell.x >= 0:
			door = dc
			outside = o_cell
			inside = i_cell
			break
	assert_gte(door.x, 0, "the map has a door with an outside and an inside")
	game.player.position = game.lift(outside, 0)
	game.ai._track_door()
	assert_true(game.ai.held_door.is_empty(), "outside: nothing held")
	game.player.position = game.lift(inside, 0)
	game.ai._track_door()
	assert_eq(game.ai.held_door.get("cell"), door)
	var out: Vector3 = game.ai.held_door["out"]
	assert_gt(out.dot(FieldGrid.center(outside) - FieldGrid.center(door)), 0.0, "faces the way he came in")
	game.player.position = game.lift(outside, 0)
	game.ai._track_door()
	assert_true(game.ai.held_door.is_empty(), "out again: forgotten")


func test_a_companion_stuck_on_the_way_finds_the_way_again() -> void:
	_start()
	ally.path = PackedVector3Array([ally.position + Vector3(5, 0, 0)])
	ally.brain["dest"] = ally.position + Vector3(5, 0, 0)
	for i in range(int(ceil(FieldAi.STUCK_T / FieldAi.THINK)) + 1):
		game.ai._watch_stuck(ally)
	assert_true(ally.path.is_empty(), "the old path is dropped")
	assert_false(ally.brain.has("dest"))


# ---------------------------------------------------------------- bundle 2: searching, picking up, handing over

## An unlocked, unsearched ground-floor container and the chief standing beside it.
func _by_a_box() -> String:
	for id in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		if c["locked"] or c["searched"] or c.has("pick") or int(c.get("level", 0)) != 0:
			continue
		game.player.position = game.walkable_near(game.lift(c["cell"], 0), false, 2)
		for q in game.squad:
			if q != game.player:
				q.position = game.player.position + Vector3(-1.5, 0, 0)
		return id
	return ""


func test_the_chief_stops_by_a_box_and_a_companion_takes_it() -> void:
	_start()
	var id := _by_a_box()
	assert_ne(id, "", "the map has a box to search")
	game.player.moving = false
	var helpers := 0
	for q in game.squad:
		if q == game.player:
			continue
		if game.ai._help_search(q):
			helpers += 1
			assert_ne(game.ai._role(q), "rear", "the rear one keeps watch")
	assert_gte(helpers, 1, "someone goes for it")
	var claims := {}
	for q in game.squad:
		if q.brain.has("help_c"):
			assert_false(claims.has(q.brain["help_c"]), "one each")
			claims[q.brain["help_c"]] = true


func test_nobody_stops_to_search_while_the_chief_walks_on() -> void:
	_start()
	_by_a_box()
	game.player.moving = true
	for q in game.squad:
		if q != game.player:
			assert_false(game.ai._help_search(q))


func test_an_arrow_on_the_ground_is_picked_up() -> void:
	_start()
	var before: int = int(game.ammo.get("craft", 0))
	game.ground_items.append({"pos": ally.position + Vector3(0.3, 0, 0), "id": "arrow", "n": 1})
	assert_true(game.ai._pick_ground(ally))
	assert_eq(int(game.ammo.get("craft", 0)), before + 1, "back in the quiver")
	assert_true(game.ground_items.is_empty())


func test_a_bandage_is_brought_to_the_chief_bleeding_without_one() -> void:
	_start()
	ally.medical = "none"
	ally.items = {"bandage": 2}
	game.player.items = {}
	game.player.body.bleed = 1
	game.player.position = ally.position + Vector3(1.0, 0, 0)
	assert_true(game.ai._hand_over(ally))
	assert_eq(int(game.player.items.get("bandage", 0)), 1)
	assert_eq(int(ally.items.get("bandage", 0)), 1)
