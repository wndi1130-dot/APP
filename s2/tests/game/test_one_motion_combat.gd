extends "res://addons/gut/test.gd"
## One body does one thing at a time (decision 420, fight side): the shove key
## ends a one-press fight and, pressed mid-blow, goes once the blow is over; a
## blow drawn back when grabbed is lost on breaking free; a blow or a shove
## breaks off rummaging and the like, and waits out a climb.

const FieldGame = preload("res://game/field_game.gd")
const Combat = preload("res://game/field_combat.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")

var game
var p


func _start(extra: Dictionary = {}) -> void:
	game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false}
	opts.merge(extra)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	p = game.player
	p.position = game.lift(Vector2i(60, 7), 0)


func _dead_at(dx: float) -> Dictionary:
	return game.zombies.spawn("dead", p.position + Vector3(dx, 0, 0))


func _touched(z: Dictionary) -> bool:
	return not game.zombies.list.has(z) or String(z["state"]) in ["dead", "downed"] or float(z.get("stun", 0.0)) > 0.0


func _until_free(who) -> void:
	for i in range(80):
		if not game.combat.striking(who):
			return
		game.combat.update(0.05)


func test_the_shove_key_ends_a_one_press_fight() -> void:
	_start()
	var z := _dead_at(0.9)
	game.combat.fight(p, z, true)
	assert_true(game.combat.fighting(p))
	game.combat.start_shove(p)
	assert_false(game.combat.fighting(p), "the shove is the next thing, the swinging stops")
	assert_gt(p.shove_t, 0.0, "and the shove goes")


func test_a_shove_pressed_mid_blow_goes_once_after_it() -> void:
	_start()
	game.combat.start_swing(p, {})
	assert_true(game.combat.striking(p))
	game.combat.start_shove(p)
	game.combat.start_shove(p)
	assert_eq(p.shove_t, 0.0, "not in the middle of the blow")
	assert_eq(game.combat.shove_after.size(), 1, "pressed twice, remembered once")
	var shoves := 0
	for i in range(80):
		var was: float = p.shove_t
		game.combat.update(0.05)
		if was <= 0.0 and p.shove_t > 0.0:
			shoves += 1
	assert_eq(shoves, 1, "one shove once the blow is over")
	assert_true(game.combat.shove_after.is_empty())


func test_breaking_free_loses_the_blow_drawn_back() -> void:
	_start()
	var z := _dead_at(1.0)
	var g := _dead_at(-0.5)
	game.combat.start_swing(p, z)
	g["state"] = "grab"
	g["victim"] = p
	p.grabbers.append(g)
	p.grab_left = 1.0
	game.combat.update(0.10)
	assert_true(game.combat.break_grab(p))
	assert_eq(p.strike_t, 0.0, "the blow drawn back is lost")
	assert_gt(p.lunge_t, 0.0, "the arms are seen thrown out")
	game.combat.update(0.25)
	assert_false(_touched(z), "it does not land after breaking free")
	assert_almost_eq(p.swing_t, Combat.SHOVE_TIME - 0.25, 0.001, "the breaking-free lockout stands")


func test_with_nothing_breaking_a_blow_it_still_lands() -> void:
	_start({"melee_break": "none"})
	var z := _dead_at(1.0)
	var g := _dead_at(-0.5)
	game.combat.start_swing(p, z)
	g["state"] = "grab"
	g["victim"] = p
	p.grabbers.append(g)
	p.grab_left = 1.0
	game.combat.update(0.10)
	game.combat.break_grab(p)
	game.combat.update(0.25)
	assert_true(_touched(z), "melee_break none: the blow still lands")


func test_a_blow_breaks_off_rummaging() -> void:
	_start()
	for job in ["search", "loot", "treat"]:
		p.start_action(job, job, 5.0, func() -> void: pass)
		game.combat.start_swing(p, {})
		assert_eq(p.action, "", "%s is let go" % job)
		assert_gt(p.strike_t, 0.0, "and the blow is drawn back")
		_until_free(p)


func test_a_blow_waits_out_a_climb_and_a_swap() -> void:
	_start()
	for job in ["climb", "swap", "door", "window"]:
		p.start_action(job, job, 5.0, func() -> void: pass)
		game.combat.start_swing(p, {})
		assert_eq(p.action, job, "%s runs to its end" % job)
		assert_eq(p.strike_t, 0.0, "no blow meanwhile")
		game.combat.start_shove(p)
		assert_eq(p.shove_t, 0.0, "no shove meanwhile")
		p.cancel_action()


func test_a_companion_reflex_shove_breaks_off_its_search() -> void:
	_start()
	var mate = game.squad[1]
	mate.start_action("search", "뒤지기", 5.0, func() -> void: pass)
	game.combat.shove(mate)
	assert_eq(mate.action, "", "it lets go of the search to shove")
	assert_gt(mate.swing_t, 0.0)


func test_no_swap_starts_mid_blow() -> void:
	_start()
	p.hands = [{"id": "axe", "quality": "factory", "condition": 1.0, "loaded": 0}, {"id": "knife", "quality": "factory", "condition": 1.0, "loaded": 0}]
	game.combat.start_swing(p, {})
	game.combat.swap(p)
	assert_eq(p.action, "", "the swap waits for the blow")


func test_the_blow_breaks_what_the_stick_breaks_and_rummaging_a_body() -> void:
	var want: Array = FieldGame.STICK_BREAKS.duplicate()
	want.append("loot")
	assert_eq(Combat.BLOW_BREAKS, want)


## A dead body walking at a shut door bangs on it and stays on its side.
func test_a_dead_one_at_a_shut_door_stays_out_of_it() -> void:
	_start()
	var lg = game.grid
	var door := Vector2i(-1, -1)
	var a := Vector2i.ZERO
	var b := Vector2i.ZERO
	for c in lg.doors:
		if String(lg.doors[c]["state"]) != "closed":
			continue
		for o in [Vector2i(1, 0), Vector2i(0, 1)]:
			if lg.people_can_walk(c - o) and not lg.blocks_body(c - o) and lg.people_can_walk(c + o) and not lg.blocks_body(c + o):
				door = c
				a = c - o
				b = c + o
				break
		if door.x >= 0:
			break
	assert_true(door.x >= 0, "the map has a shut door between two floors")
	var z: Dictionary = game.zombies.spawn("dead", game.lift(a, 0))
	z["state"] = "investigate"
	z["clue_kind"] = ""
	z["linger"] = 30.0
	z["target"] = game.lift(b, 0)
	z["path"] = PackedVector3Array([FieldGrid.center(door), game.lift(b, 0)])
	z["path_t"] = 30.0
	var inside := false
	for i in range(120):
		game.zombies._move(z, 0.05)
		if FieldGrid.cell_of(z["pos"]) == door:
			inside = true
	assert_false(inside, "it never steps into the shut door")
	assert_eq(String(lg.doors[door]["state"]) in ["closed", "broken"], true)
