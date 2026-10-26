extends "res://addons/gut/test.gd"
## The living standing still keep out of each other's bodies (decision 442: the
## motion card's recommendation on people standing in each other): eased apart as
## the dead are, the player, a worker at a spot, a carrier and a fighter staying
## put while the other steps aside; one on the way passes through as before, and
## the lying, the held and the hidden take no part.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const Separation = preload("res://game/sim/people_separation.gd")
const DT := 1.0 / 30.0
const EPS := 0.000002

var game
var a
var b


func _start() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 11, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	game.player.position = game.lift(Vector2i(60, 7), 0)
	var others: Array = []
	for q in game.squad:
		if q != game.player:
			q.position = game.lift(Vector2i(30, 7), 0)
			others.append(q)
	a = others[0]
	b = others[1]


func _ticks(n: int) -> void:
	for i in range(n):
		game._separate_people(DT)


func _flat(p, q) -> float:
	return _off(p, q.position)


func _off(p, at: Vector3) -> float:
	var d: Vector3 = p.position - at
	d.y = 0.0
	return d.length()


func test_a_free_pair_splits_the_gap_and_the_sum_is_capped() -> void:
	var at := PackedVector3Array([Vector3(1, 0, 1), Vector3(1, 0, 1), Vector3(5, 0, 5)])
	var pushes := Separation.pushes(at, PackedInt32Array([0, 0, 0]), PackedInt64Array([1, 2, 3]),
		PackedFloat32Array([1.4, 1.4, 1.4]), PackedByteArray([0, 0, 0]), DT)
	var cap := 1.4 * DT * Separation.MAX_STEP_SHARE
	assert_almost_eq(pushes[0].length(), cap, EPS, "coincident: as far as the pace lets")
	assert_almost_eq((pushes[0] + pushes[1]).length(), 0.0, EPS, "each the other way")
	assert_eq(pushes[2], Vector3.ZERO, "one far off is left")


func test_a_fixed_body_stays_and_the_other_takes_the_whole_gap() -> void:
	var at := PackedVector3Array([Vector3(1, 0, 1), Vector3(1.5, 0, 1)])
	var pushes := Separation.pushes(at, PackedInt32Array([0, 0]), PackedInt64Array([1, 2]),
		PackedFloat32Array([1.4, 100.0]), PackedByteArray([1, 0]), 1.0)
	assert_eq(pushes[0], Vector3.ZERO, "the fixed one does not move")
	assert_almost_eq(pushes[1].x, Separation.SEPARATION_R - 0.5, EPS, "the other takes all of the gap")
	var both := Separation.pushes(at, PackedInt32Array([0, 0]), PackedInt64Array([1, 2]),
		PackedFloat32Array([1.4, 1.4]), PackedByteArray([1, 1]), 1.0)
	assert_eq(both[0] + both[1], Vector3.ZERO, "two fixed are left as they are")
	var floors := Separation.pushes(at, PackedInt32Array([0, 1]), PackedInt64Array([1, 2]),
		PackedFloat32Array([1.4, 1.4]), PackedByteArray([0, 0]), 1.0)
	assert_eq(floors[0] + floors[1], Vector3.ZERO, "a floor apart: no push")


func test_two_companions_on_one_spot_step_apart() -> void:
	_start()
	var at: Vector3 = game.lift(Vector2i(60, 9), 0)
	a.position = at
	b.position = at
	_ticks(90)
	assert_gte(_flat(a, b), Separation.SEPARATION_R - EPS)
	assert_lt(_off(a, at) + _off(b, at), Separation.SEPARATION_R + 0.05, "each went about half")


func test_the_player_is_never_pushed_the_companion_steps_aside() -> void:
	_start()
	var home: Vector3 = game.player.position
	a.position = home + Vector3(0.1, 0, 0)
	_ticks(90)
	assert_eq(game.player.position, home, "the player stays")
	assert_gte(_flat(a, game.player), Separation.SEPARATION_R - EPS, "the companion stepped out")


func test_a_worker_stays_at_the_spot_and_a_carrier_too() -> void:
	_start()
	var at: Vector3 = game.lift(Vector2i(60, 9), 0)
	a.position = at
	b.position = at + Vector3(0.2, 0, 0)
	a.action = "search"
	_ticks(90)
	assert_eq(a.position, at, "at work it keeps its place")
	assert_gte(_flat(a, b), Separation.SEPARATION_R - EPS)
	a.action = ""
	a.carrying_wounded = game.player
	b.position = at + Vector3(0.2, 0, 0)
	_ticks(90)
	assert_eq(a.position, at, "carrying someone it keeps its place")
	a.carrying_wounded = null


func test_one_on_the_way_passes_through_and_a_fighter_stays_put() -> void:
	_start()
	var at: Vector3 = game.lift(Vector2i(60, 9), 0)
	a.position = at
	b.position = at + Vector3(0.2, 0, 0)
	a.path = PackedVector3Array([at + Vector3(0, 0, 3)])
	_ticks(10)
	assert_eq(a.position, at, "on the way: not eased aside")
	assert_eq(b.position, at + Vector3(0.2, 0, 0), "and it pushes nobody")
	a.path = PackedVector3Array()
	a.target_zombie = {"id": 1, "pos": at + Vector3(0, 0, 1), "state": "chase"}
	_ticks(90)
	assert_eq(a.position, at, "in a fight it keeps its place")
	assert_gte(_flat(a, b), Separation.SEPARATION_R - EPS, "the other steps aside")
	a.target_zombie = {}


func test_the_lying_the_held_and_the_hidden_take_no_part() -> void:
	_start()
	var at: Vector3 = game.lift(Vector2i(60, 9), 0)
	for setup in ["downed", "held", "hidden"]:
		a.position = at
		b.position = at
		a.body.downed = setup == "downed"
		a.grabbers = [{}] if setup == "held" else []
		a.visible = setup != "hidden"
		_ticks(10)
		assert_eq(a.position, at, setup + ": not moved")
		assert_eq(b.position, at, setup + ": does not push")
	a.body.downed = false
	a.grabbers = []
	a.visible = true


func test_never_through_a_wall() -> void:
	_start()
	var at: Vector3 = game.lift(Vector2i(60, 9), 0)
	var wall := Vector2i(59, 9)
	game.grid.set_solid(wall, FieldGrid.Solid.WALL)
	var edge: Vector3 = FieldGrid.center(Vector2i(60, 9)) - Vector3(0.45, 0, 0)
	edge.y = at.y
	a.position = edge
	b.position = edge + Vector3(0.1, 0, 0)
	_ticks(90)
	assert_eq(FieldGrid.cell_of(a.position), Vector2i(60, 9), "not pushed into the wall")
	assert_eq(FieldGrid.cell_of(b.position).y, 9)
