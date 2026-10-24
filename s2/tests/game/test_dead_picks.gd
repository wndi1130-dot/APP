extends GutTest
## Decision 422: the dead's motions 17..26 are picked from what the rules
## note (beating on a shut door, struck on the head, turning round to a sound,
## wandering on a slow walk), and a folder without them draws as before.

const DeadBody = preload("res://game/actors/dead_body.gd")
const BodyBake = preload("res://scripts/body_bake.gd")
const Motion = preload("res://game/sim/motion.gd")
const FieldGame = preload("res://game/field_game.gd")
const PersonVisual = preload("res://game/actors/person_visual.gd")
const Person = preload("res://game/actors/person.gd")
const Pose = preload("res://game/actors/person_pose.gd")
const Zombies = preload("res://game/actors/zombies.gd")

const ONCE: Array = [DeadBody.HIT_LEFT, DeadBody.HIT_RIGHT, DeadBody.HIT_TOP, DeadBody.HIT_UPPER, DeadBody.TURN_LEFT, DeadBody.TURN_RIGHT]


func before_each() -> void:
	DeadBody.rounds = {}
	DeadBody.table = []


func after_all() -> void:
	DeadBody.rounds = {}
	DeadBody.table = []


## A folder's table of `n` motions, 32 frames each, as long as the baked ones.
func _table(n: int = 27) -> void:
	DeadBody.table = []
	for i in n:
		var seconds := 1.0
		if i == DeadBody.THUMP or i == DeadBody.CLAW:
			seconds = 1.3
		elif i >= DeadBody.HIT_LEFT and i <= DeadBody.HIT_UPPER:
			seconds = 0.4
		DeadBody.table.append([i * 32, 32, not ONCE.has(i), seconds])


func _body(state: String = "wander", phase: float = 0.37) -> Dictionary:
	return {"state": state, "phase": phase, "crawl": false, "age": 10.0, "pos": Vector3(3, 0, 4), "t": 0.0, "angle": 0.0}


func _motion(z: Dictionary) -> int:
	return DeadBody.motion_in(DeadBody.custom(z, 0.0, 0.0, 1.0, true).g)


func _phase_for(motion: int) -> float:
	for n in 100:
		if DeadBody.door_motion(_body("investigate", float(n) / 100.0)) == motion:
			return float(n) / 100.0
	return -1.0


func test_the_baked_bodies_have_the_lengths_the_picks_go_by() -> void:
	var got := BodyBake.load_baked(DeadBody.BUILT_IN)
	DeadBody.table = DeadBody.table_of(got)
	assert_gt(DeadBody.table.size(), DeadBody.WALK_E, "the body carried in the build has them")
	assert_almost_eq(DeadBody.seconds_of(DeadBody.THUMP, 0.0), float(Motion.row("dead_thump")["len"]), 0.001, "a beat at the door is the rules' bang time")
	assert_almost_eq(DeadBody.seconds_of(DeadBody.CLAW, 0.0), float(Motion.row("dead_thump")["len"]), 0.001)
	assert_almost_eq(DeadBody.seconds_of(DeadBody.HIT_LEFT, 0.0), 0.4, 0.001)
	# The slow walks at the wanderer's pace go near their own; at a hurry's they would race.
	var rounds := DeadBody.rounds_of(got)
	for walk in [DeadBody.WALK_D, DeadBody.WALK_E]:
		var own := float(rounds[walk]) / DeadBody.seconds_of(walk, 1.0)
		assert_between(Zombies.SPEED_WANDER / own, 0.5, 1.5, "wandering, walk %d" % walk)
		assert_gt(Zombies.SPEED_SHAMBLE / own, 1.5, "hurrying, walk %d is not used" % walk)
		assert_true(DeadBody.STRIDE.has(walk), "a folder without its round still has one")
		assert_eq(DeadBody.mix_time(walk), 0.35)


func test_at_a_shut_door_it_beats_on_it_and_the_blow_lands_as_the_door_is_banged() -> void:
	_table()
	var thump := _phase_for(DeadBody.THUMP)
	var claw := _phase_for(DeadBody.CLAW)
	assert_true(thump >= 0.0 and claw >= 0.0, "some thump, some claw")
	for want in [[thump, DeadBody.THUMP, 0.85], [claw, DeadBody.CLAW, DeadBody.CLAW_LANDS]]:
		var z := _body("investigate", want[0])
		z["bang_seen"] = z["age"]
		z["bang_t"] = 1.3                      # it has just banged on it
		var c := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
		assert_eq(DeadBody.motion_in(c.g), want[1])
		assert_almost_eq(c.r, float(want[2]), 0.001, "the blow is where the bang is")
		z["age"] += 0.65
		z["bang_seen"] = z["age"]
		z["bang_t"] = 0.65
		assert_almost_eq(DeadBody.custom(z, 0.0, 0.0, 1.0, true).r, fposmod(float(want[2]) + 0.5, 1.0), 0.001, "half a beat on")
		z["age"] += DeadBody.AT_DOOR + 0.01
		assert_false(_motion(z) in [DeadBody.THUMP, DeadBody.CLAW], "gone from the door, it is not at it")
	assert_eq(DeadBody.mix_time(DeadBody.THUMP), 0.2)
	# A folder without them: as before.
	_table(17)
	var old := _body("investigate", thump)
	old["bang_seen"] = old["age"]
	old["bang_t"] = 1.3
	assert_eq(_motion(old), DeadBody.walk_of(thump))


func test_struck_on_the_head_it_is_thrown_the_way_the_blow_came() -> void:
	_table()
	# It faces +z, the striker in front of it.
	for want in [["p_swing_one", DeadBody.HIT_LEFT], ["p_chop_side", DeadBody.HIT_LEFT], ["p_swing_back", DeadBody.HIT_RIGHT],
			["p_swing_axe", DeadBody.HIT_TOP], ["p_stab", DeadBody.HIT_UPPER], ["", DeadBody.HIT_LEFT]]:
		var z := _body("chase")
		z["hit_at"] = z["age"]
		z["hit_by"] = z["pos"] + Vector3(0, 0, 1)
		z["hit_way"] = want[0]
		assert_eq(_motion(z), want[1], "in front, " + String(want[0]))
	# Across from behind it comes in on its right; from either side, on that side.
	for want in [[Vector3(0, 0, -1), DeadBody.HIT_RIGHT], [Vector3(1, 0, 0), DeadBody.HIT_LEFT], [Vector3(-1, 0, 0), DeadBody.HIT_RIGHT]]:
		var z := _body("chase")
		z["hit_at"] = z["age"]
		z["hit_by"] = z["pos"] + want[0]
		z["hit_way"] = "p_swing_one"
		assert_eq(_motion(z), want[1], "from %s" % want[0])
	# Played once over its length, then it is done; the side is kept though it turns meanwhile.
	var z := _body("chase")
	z["hit_at"] = z["age"]
	z["hit_by"] = z["pos"] + Vector3(0, 0, 1)
	z["hit_way"] = "p_swing_one"
	assert_almost_eq(DeadBody.custom(z, 0.0, 0.0, 1.0, true).r, 0.0, 0.001)
	z["age"] += 0.2
	z["angle"] = PI
	var half := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_eq(DeadBody.motion_in(half.g), DeadBody.HIT_LEFT)
	assert_almost_eq(half.r, 0.5, 0.001)
	z["age"] += 0.21
	assert_false(_motion(z) in [DeadBody.HIT_LEFT, DeadBody.HIT_RIGHT, DeadBody.HIT_TOP, DeadBody.HIT_UPPER], "done")
	# Knocked down by it, it goes over; a shove after the blow is seen over it, not one before.
	var down := _body("downed")
	down["hit_at"] = down["age"]
	down["fell_at"] = down["age"]
	assert_true(DeadBody.motion_in(DeadBody.custom(down, 0.3, 0.0, 1.0, true).g) in [DeadBody.FALL, DeadBody.FALL_THROWN])
	var shoved_after := _body("chase")
	shoved_after["hit_at"] = shoved_after["age"] - 0.1
	shoved_after["shoved_t"] = float(Motion.row("dead_shoved")["len"]) - 0.05
	assert_eq(_motion(shoved_after), DeadBody.STAGGER)
	var shoved_before := _body("chase")
	shoved_before["hit_at"] = shoved_before["age"] - 0.02
	shoved_before["shoved_t"] = float(Motion.row("dead_shoved")["len"]) - 0.1
	assert_eq(_motion(shoved_before), DeadBody.HIT_LEFT)
	# A folder without them: as before, not the old struck pose either.
	_table(17)
	var old := _body("chase")
	old["hit_at"] = old["age"]
	old["hit_by"] = old["pos"] + Vector3(0, 0, 1)
	assert_eq(_motion(old), DeadBody.walk_of(0.37))


func test_turning_round_to_a_sound_the_body_comes_round_over_the_rules_turn() -> void:
	_table()
	var z := _body("investigate")
	z["target"] = z["pos"] + Vector3(5, 0, 0)      # on its left (it faces +z, its right is -x)
	assert_eq(DeadBody.yaw_of(z, true), 0.0, "drawn as it faced before it heard")
	z["turn_t"] = 0.6
	z["angle"] = 0.3                               # the rules have begun to turn it
	assert_almost_eq(DeadBody.yaw_of(z, true), 0.0, 0.001, "the body is drawn from where it faced")
	var first := DeadBody.custom(z, 0.0, 0.0, 1.0, true)
	assert_eq(DeadBody.motion_in(first.g), DeadBody.TURN_LEFT)
	assert_almost_eq(first.r, 0.0, 0.001)
	z["age"] += 0.3
	z["turn_t"] = 0.3
	z["angle"] = PI / 2.0                          # the rules face it already
	assert_almost_eq(DeadBody.yaw_of(z, true), PI / 4.0, 0.001, "half way round, drawn half way")
	assert_almost_eq(DeadBody.custom(z, 0.0, 0.0, 1.0, true).r, 0.5, 0.001)
	z["age"] += 0.31
	z["turn_t"] = 0.0
	assert_almost_eq(DeadBody.yaw_of(z, true), PI / 2.0, 0.001, "round as the rules' turn ends")
	assert_ne(_motion(z), DeadBody.TURN_LEFT, "and it goes on")
	assert_eq(DeadBody.mix_time(DeadBody.TURN_LEFT), 0.4)
	# On its right; and a turn too small for it is no turn.
	var right := _body("investigate")
	right["target"] = right["pos"] + Vector3(-5, 0, 0)
	DeadBody.yaw_of(right, true)
	right["turn_t"] = 0.5
	assert_eq(_motion(right), DeadBody.TURN_RIGHT)
	var small := _body("investigate")
	small["target"] = small["pos"] + Vector3(0.2, 0, 5)
	DeadBody.yaw_of(small, true)
	small["turn_t"] = 0.5
	small["angle"] = 0.04
	assert_ne(_motion(small), DeadBody.TURN_LEFT)
	assert_almost_eq(DeadBody.yaw_of(small, true), 0.04, 0.001, "it faces the rules' way")


func test_a_turn_cut_short_comes_the_rest_of_the_way_round_quickly() -> void:
	_table()
	var z := _body("investigate")
	z["target"] = z["pos"] + Vector3(5, 0, 0)
	DeadBody.yaw_of(z, true)
	z["turn_t"] = 0.6
	DeadBody.yaw_of(z, true)
	z["age"] += 0.12
	z["turn_t"] = 0.48
	z["angle"] = PI / 2.0
	var part := DeadBody.yaw_of(z, true)
	assert_between(part, 0.05, 0.3, "a little way round")
	# It saw someone (zombies.gd zeroes turn_t) and comes on at once.
	z["turn_t"] = 0.0
	z["state"] = "chase"
	assert_almost_eq(DeadBody.yaw_of(z, true), part, 0.001, "from where it was drawn")
	assert_ne(_motion(z), DeadBody.TURN_LEFT, "not turning round any more")
	z["age"] += DeadBody.TURN_CATCH * 0.5
	var catching := DeadBody.yaw_of(z, true)
	assert_almost_eq(catching, lerp_angle(part, PI / 2.0, 0.5), 0.001, "half the rest within half of TURN_CATCH")
	z["age"] += DeadBody.TURN_CATCH
	assert_almost_eq(DeadBody.yaw_of(z, true), PI / 2.0, 0.001, "then the rules' way")


func test_boxes_and_a_folder_without_the_turns_face_the_rules_way() -> void:
	var box := _body("investigate")
	box["target"] = box["pos"] + Vector3(5, 0, 0)
	box["turn_t"] = 0.6
	box["angle"] = 0.3
	assert_eq(DeadBody.yaw_of(box, false), 0.3)
	assert_false(box.has("body_yaw"), "nothing is noted on a box")
	_table(17)
	var old := _body("investigate")
	old["target"] = old["pos"] + Vector3(5, 0, 0)
	DeadBody.yaw_of(old, true)
	old["turn_t"] = 0.6
	old["angle"] = 0.3
	assert_almost_eq(DeadBody.yaw_of(old, true), 0.3, 0.001)
	assert_ne(_motion(old), DeadBody.TURN_LEFT)


func test_wandering_some_of_the_dead_shuffle_or_go_on_a_stiff_leg() -> void:
	_table()
	var seen := {}
	for n in 100:
		var phase := float(n) / 100.0
		seen[DeadBody.gait_of(_body("wander", phase))] = true
		assert_lt(DeadBody.gait_of(_body("investigate", phase)), DeadBody.WALKS, "hurrying, its own walk")
	assert_true(seen.has(DeadBody.WALK_D), "a shuffle")
	assert_true(seen.has(DeadBody.WALK_E), "a stiff leg")
	assert_true(seen.has(0) and seen.has(1) and seen.has(2), "the rest walk as they did")
	_table(17)
	for n in 100:
		assert_lt(DeadBody.gait_of(_body("wander", float(n) / 100.0)), DeadBody.WALKS, "a folder without them")


# The rules only note: where a body bangs on a door, and when, from where and
# with which way it was struck (the drawn way of the blow, when it was drawn).
func test_the_rules_note_the_door_and_the_blow() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	var p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)
	var door := Vector2i(-1, -1)
	for c in game.grid.doors:
		if String(game.grid.doors[c]["state"]) == "closed":
			door = c
			break
	assert_true(door.x >= 0, "a shut door to bang on")
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(1.0, 0, 0))
	z["age"] = 4.0
	game.zombies._bang(z, door, 0.1)
	assert_eq(float(z["bang_seen"]), 4.0)
	p.set_meta(Pose.BLOW_WAY, "p_swing_back")
	game.combat.start_swing(p, z)
	game.combat.update(1.0)
	assert_true(z.has("hit_at"), "struck")
	assert_eq(float(z["hit_at"]), float(z["age"]))
	assert_almost_eq((z["hit_by"] as Vector3).distance_to(p.position), 0.0, 0.001)
	assert_eq(String(z["hit_way"]), "p_swing_back")


func test_the_drawn_way_of_a_blow_is_noted_on_the_striker_while_it_swings() -> void:
	var own: Array = BodyBake.load_baked(PersonVisual.OWN_FOLDER).get("clips", [])
	var p := Person.new()
	add_child_autofree(p)
	p.setup("p_test", "시험", "companion", Vector3.ZERO)
	p.hands = [{"id": "crowbar", "quality": "factory", "condition": 1.0, "loaded": 0}]
	p.strike_kind = "swing"
	p.strike_at = {"state": "chase"}
	p.strike_total = 0.4
	p.strike_t = 0.4
	var note := {}
	PersonVisual.blow_of(p, own, note, 0.0)
	assert_eq(String(p.get_meta(Pose.BLOW_WAY, "")), "p_swing_one")
	p.strike_t = 0.0
	p.swing_t = 0.0
	PersonVisual.blow_of(p, own, note, 0.5)
	assert_false(p.has_meta(Pose.BLOW_WAY), "gone once the swing is over")
	p.strike_t = 0.4
	PersonVisual.blow_of(p, own, note, 0.6)
	assert_eq(String(p.get_meta(Pose.BLOW_WAY, "")), "p_swing_back", "the next blow the other way back")
