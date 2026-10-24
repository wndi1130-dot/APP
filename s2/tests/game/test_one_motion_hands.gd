extends "res://addons/gut/test.gd"
## One body does one thing at a time (decision 420, hands side): no work of the
## hands starts while a blow or a shove is on. Asked for meanwhile, it waits and
## is done once, as soon as the blow is over; a body taken meanwhile drops it.

const FieldGame = preload("res://game/field_game.gd")

var game
var p
var id: String
var container: Dictionary


func _start() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 1, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	id = game.data["containers"].keys()[0]
	container = game.data["containers"][id]
	container["locked"] = false
	container["searched"] = false
	container["busy"] = false
	p = game.player
	p.position = game.lift(container["cell"], int(container.get("level", 0)))


## Runs the fight clock until the blow or shove is over (at most 3 s).
func _finish_blow() -> void:
	for i in range(60):
		if not game.actions.striking(p):
			return
		game.combat.update(0.05)


func test_without_a_blow_a_search_starts_at_once() -> void:
	_start()
	assert_false(game.actions.striking(p))
	game.actions.search(p, id)
	assert_eq(p.action, "search", "as before")


func test_a_search_asked_mid_blow_waits_for_the_blow() -> void:
	_start()
	game.combat.start_swing(p, {})
	assert_true(game.actions.striking(p), "the weapon is drawn back")
	game.actions.search(p, id)
	assert_eq(p.action, "", "nothing starts mid-blow")
	assert_false(bool(container["busy"]), "the box is not taken meanwhile")
	game.actions.update(0.0)
	assert_eq(p.action, "", "still in the blow")
	_finish_blow()
	game.actions.update(0.0)
	assert_eq(p.action, "search", "done once the blow is over")
	assert_true(game.actions.after_blow.is_empty())


func test_no_work_can_start_while_the_hands_are_in_a_blow() -> void:
	_start()
	var at: Vector3 = p.position
	assert_true(game.actions._can_start(p, at))
	game.combat.start_shove(p)
	assert_false(game.actions._can_start(p, at), "a shove is on")
	_finish_blow()
	assert_true(game.actions._can_start(p, at))


func test_a_goal_reached_mid_blow_is_done_after_it() -> void:
	_start()
	p.brain["goal"] = {"kind": "container", "key": id, "at": p.position, "verb": ""}
	p.path = PackedVector3Array()
	game.combat.start_swing(p, {})
	game.actions.update(0.0)
	assert_true(p.brain.has("goal"), "the goal waits")
	assert_eq(p.action, "")
	_finish_blow()
	game.actions.update(0.0)
	assert_false(p.brain.has("goal"))
	assert_eq(p.action, "search")


func test_a_bandage_asked_mid_shove_is_done_once() -> void:
	_start()
	p.body.apply_cut(true, 0.0, "arm_left")
	assert_gt(p.body.bleed, 0)
	game.combat.start_shove(p)
	game.actions.self_bandage(p)
	game.actions.self_bandage(p)
	assert_eq(p.action, "", "the arms are in the shove")
	assert_eq(game.actions.after_blow.size(), 1, "pressed twice, waits once")
	_finish_blow()
	game.actions.update(0.0)
	assert_eq(p.action, "treat")
	assert_true(game.actions.after_blow.is_empty())


func test_asking_for_work_mid_blow_lets_the_fight_go() -> void:
	_start()
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.8, 0, 0))
	game.combat.fight(p, z, true)
	game.combat.start_swing(p, z)
	assert_true(game.combat.fighting(p))
	game.actions.search(p, id)
	assert_false(game.combat.fighting(p), "the fight is let go for the search")


func test_taken_while_waiting_the_work_is_dropped() -> void:
	_start()
	game.combat.start_swing(p, {})
	game.actions.search(p, id)
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.5, 0, 0))
	z["state"] = "grab"
	z["victim"] = p
	p.grabbers.append(z)
	p.grab_left = 1.0
	game.actions.update(0.0)
	assert_true(game.actions.after_blow.is_empty(), "grabbed: the search is dropped")
	assert_eq(p.action, "")
