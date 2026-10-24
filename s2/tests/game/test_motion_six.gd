extends "res://addons/gut/test.gd"
## Decision 425: six rules from the reference game's motions, the user's
## answer to card 2 (every row 가). A blow holds the feet; at a run it is a
## shove; the dead draw back before the first blow on a door; one getting up
## can be shoved again; a crawler bites later and none bite one just seen;
## footsteps go by the walk.

const FieldGame = preload("res://game/field_game.gd")
const Zombies = preload("res://game/actors/zombies.gd")
const Motion = preload("res://game/sim/motion.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const W = preload("res://game/sim/weapons.gd")
const BodyBake = preload("res://scripts/body_bake.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")

var game
var p


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)


func _dead_at(at: Vector3, state: String = "wander") -> Dictionary:
	var z: Dictionary = game.zombies.spawn("dead", at)
	z["state"] = state
	return z


func test_a_blow_holds_the_feet_from_part_way_to_its_end() -> void:
	assert_eq(p.weapon_id(), "axe")
	var row: Dictionary = Motion.swing_row("axe")
	var mult: float = float(p.mults()["swing"])
	game.combat.start_swing(p, {})
	assert_false(game.combat.feet_held(p), "drawn back at first, the feet are free")
	game.clock.elapsed += (float(row["feet"].x) + 0.02) / mult
	assert_true(game.combat.feet_held(p), "from feet_from of the swing on, held")
	p.stick = Vector2(1, 0)
	var at: Vector3 = p.position
	game._drive(p, 0.1)
	assert_eq(p.position, at, "the stick does not walk it off")
	assert_false(p.moving)
	game.clock.elapsed += float(row["len"]) / mult
	assert_false(game.combat.feet_held(p), "after the swing they are free")
	p.strike_t = 0.0
	p.swing_t = 0.0
	game._drive(p, 0.1)
	assert_ne(p.position, at, "and it walks")
	# A knife holds them only for the back half of its swing.
	assert_almost_eq(float(Motion.swing_row("knife")["feet"].x) / float(W.get_data("knife")["swing"]), 0.5, 0.001)


func test_a_blow_holds_a_squad_members_feet_on_a_path_too() -> void:
	var a = game.squad[1] if game.squad.size() > 1 and game.squad[0] == p else game.squad[0]
	assert_ne(a, p)
	a.position = p.position + Vector3(3, 0, 0)
	a.set_weapon_slots([{"id": "axe", "quality": "factory", "condition": 1.0, "loaded": 0}])
	var row: Dictionary = Motion.swing_row("axe")
	var mult: float = float(a.mults()["swing"])
	game.combat.start_swing(a, {})
	game.clock.elapsed += (float(row["feet"].x) + 0.02) / mult
	assert_true(game.combat.feet_held(a))
	a.go_to(PackedVector3Array([a.position + Vector3(4, 0, 0)]))
	var at: Vector3 = a.position
	game._move_person(a, 0.1)
	assert_eq(a.position, at, "the AI's path does not walk it off mid-blow")
	assert_false(a.moving)
	game.clock.elapsed += float(row["len"]) / mult
	a.strike_t = 0.0
	a.swing_t = 0.0
	game._move_person(a, 0.1)
	assert_ne(a.position, at, "after the blow it goes on along the path")


func test_at_a_run_a_blow_goes_out_as_a_shove() -> void:
	p.running = true
	p.moving = true
	assert_true(p.is_running_now())
	game.combat.start_swing(p, {})
	assert_gt(p.shove_t, 0.0, "a shove")
	assert_eq(p.strike_t, 0.0, "not a swing")
	p.shove_t = 0.0
	p.swing_t = 0.0
	p.running = false
	game.combat.start_swing(p, {})
	assert_gt(p.strike_t, 0.0, "stopped, it swings")


func test_the_dead_draw_back_before_the_first_blow_on_a_door() -> void:
	var door := Vector2i(-1, -1)
	for c in game.grid.doors:
		if String(game.grid.doors[c]["state"]) == "closed":
			door = c
			break
	var z := _dead_at(p.position + Vector3(30, 0, 0))
	var row: Dictionary = Motion.row("dead_thump")
	var bangs: Array = []
	var t := 0.0
	var was: float = -1.0
	while t < 4.0:
		z["age"] = float(z["age"]) + 0.05
		game.zombies._bang(z, door, 0.05)
		t += 0.05
		if float(z["bang_t"]) > was + 0.5 and was >= 0.0:
			bangs.append(t)
		was = float(z["bang_t"])
	assert_gt(bangs.size(), 1)
	assert_almost_eq(float(bangs[0]), float(row["hit"]), 0.06, "the first blow lands as the picture's does")
	assert_almost_eq(float(bangs[1]) - float(bangs[0]), float(row["len"]), 0.06, "then one a round")
	# Gone from the door and back: it draws back again.
	z["age"] = float(z["age"]) + 2.0
	game.zombies._bang(z, door, 0.05)
	assert_almost_eq(float(z["bang_t"]), float(row["hit"]) - 0.05, 0.001)


func test_one_getting_up_can_be_shoved_again_and_one_lying_cannot() -> void:
	var rise: float = float(Motion.row("dead_rise")["len"])
	var up := _dead_at(p.position + Vector3(sin(p.facing), 0, cos(p.facing)) * 0.8, "downed")
	up["t"] = rise * 0.5
	var low := _dead_at(p.position + Vector3(sin(p.facing), 0, cos(p.facing)) * 0.9, "downed")
	low["t"] = rise + 2.0
	assert_true(game.zombies.getting_up(up))
	assert_false(game.zombies.getting_up(low))
	game.combat.shove(p)
	assert_gt(float(up.get("shoved_t", 0.0)), 0.0, "getting up, it is shoved")
	assert_true(String(up["state"]) in ["chase", "downed"], "it reels, or goes down again by the shove's own chance")
	assert_eq(String(low["state"]), "downed", "lying, it is not")
	assert_eq(float(low.get("shoved_t", 0.0)), 0.0)
	var crawler := _dead_at(p.position, "downed")
	crawler["crawl"] = true
	crawler["t"] = rise * 0.5
	assert_false(game.zombies.getting_up(crawler), "a crawler does not get up")


func test_a_crawler_bites_later_and_none_bite_one_just_seen() -> void:
	assert_almost_eq(Zombies.WINDUP_CRAWL, Zombies.WINDUP * 2.5, 0.001)
	for crawl in [false, true]:
		var z := _dead_at(p.position + Vector3(0, 0, 0.5))
		z["crawl"] = crawl
		z["lunger"] = false
		z["angle"] = PI
		z["sense_t"] = 0.0
		game.zombies._sense(z, game.people_alive(), 0.1)
		assert_eq(String(z["state"]), "chase", "just seen: it comes on, it does not bite yet")
		z["age"] = float(z["age"]) + Zombies.SEEN_GRACE
		z["sense_t"] = 0.0
		game.zombies._sense(z, game.people_alive(), 0.1)
		assert_eq(String(z["state"]), "attack", "seen a while: it bites")
		assert_almost_eq(float(z["windup"]), Zombies.WINDUP_CRAWL if crawl else Zombies.WINDUP, 0.001)
		game.zombies.list.erase(z)


func test_footsteps_go_by_the_walk_and_the_drawn_feet_with_them() -> void:
	var own: Array = BodyBake.load_baked(PersonVisual.OWN_FOLDER).get("clips", [])
	for gait in [["walk", "p_walk"], ["run", "p_run"], ["crouch", "p_crouch_walk"]]:
		var n := PersonVisual.clip_named(own, String(gait[1]), -1)
		assert_almost_eq(float(SimNoise.STEP_ROUND[gait[0]]), float(own[n]["round"]), 0.01 * float(own[n]["round"]), String(gait[0]) + ": the round is the drawn one")
	p.brain.erase("step_r")
	var walk: float = float(SimNoise.STEP_ROUND["walk"])
	assert_eq(game.steps_in(p, walk * 0.1), 0, "not yet a foot down")
	assert_eq(game.steps_in(p, walk * 0.15), 1, "one at 0.2 of the round")
	assert_eq(game.steps_in(p, walk * 0.5), 1, "the other at 0.65")
	assert_eq(game.steps_in(p, walk * 1.0), 2, "two to a round")
	p.running = true
	p.moving = true
	var before := float(p.brain["step_r"])
	game.steps_in(p, 0.5)
	assert_almost_eq(fposmod(float(p.brain["step_r"]) - before, 1.0), 0.5 / float(SimNoise.STEP_ROUND["run"]), 0.001, "a run goes round by its own")
	# The drawn walk is where the footsteps are.
	p.running = false
	p.moving = false
	var note := {}
	PersonVisual.motion_of(p, note, 0.05, [], own)
	p.position += Vector3(0.1, 0, 0)
	p.brain["step_r"] = 0.42
	var c := PersonVisual.motion_of(p, note, 0.05, [], own)
	assert_eq(String(own[int(c.y)]["name"]), "p_walk")
	assert_almost_eq(c.x, 0.42, 0.001)
