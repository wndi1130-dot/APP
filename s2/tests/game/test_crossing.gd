extends "res://addons/gut/test.gd"
## Over the train at a coupling (user decision 122): one at a time, three
## seconds, five with a load; the hurt go round; a grab brings you down.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldActions = preload("res://game/field_actions.gd")
const CrossingMap = preload("res://tests/game/fixtures/crossing_map.gd")

var game
var above: Vector2i
var below: Vector2i


func before_each() -> void:
	game = FieldGame.new()
	game.opts = {"seed": 4, "auto_pause": false, "raiders": false}
	game.map_script = CrossingMap
	add_child_autofree(game)
	game.set_process(false)
	var train: Rect2i = game.data["train"]
	above = Vector2i(CrossingMap.WAY_X, train.position.y - 1)
	below = Vector2i(CrossingMap.WAY_X, train.end.y)


func _labels(p) -> Array:
	return game.actions.context(p).map(func(row): return String(row["label"]))


func _mate():
	for p in game.squad:
		if p != game.player:
			return p
	return null


func test_the_ends_of_a_way_are_the_ground_on_each_side() -> void:
	assert_eq(FieldActions.crossing_ends(game.data["crossings"][0]), [above, below])


func test_the_chief_goes_over_in_three_seconds() -> void:
	var p = game.player
	p.position = FieldGrid.center(below) + Vector3(0, 0, 3.0)
	assert_false(_labels(p).has("열차 넘기 3초"), "not from out in the field")
	p.position = FieldGrid.center(below)
	assert_true(_labels(p).has("열차 넘기 3초"))
	var way: Dictionary = game.actions.crossing_at(p)
	assert_eq(way["to"], above)
	assert_true(game.actions.cross_train(p, way))
	assert_eq(p.action, "climb")
	assert_almost_eq(p.action_t, FieldActions.CROSS_TIME, 0.01)
	game._step(2.9)
	assert_eq(FieldGrid.cell_of(p.position), below, "not over yet")
	game._step(0.2)
	assert_eq(FieldGrid.cell_of(p.position), above, "down on the other side")
	assert_eq(p.action, "")
	assert_true(_labels(p).has("열차 넘기 3초"), "and back the same way")


func test_a_load_makes_it_five() -> void:
	var p = game.player
	p.position = FieldGrid.center(below)
	p.items = {"scrap": int(ceil(p.carry_limit() * 0.75))}
	assert_eq(p.carry_state(), 1, "more than half the pack")
	assert_almost_eq(game.actions.cross_seconds(p), FieldActions.CROSS_LOADED, 0.01)
	assert_true(_labels(p).has("열차 넘기 5초"))
	assert_true(game.actions.cross_train(p, game.actions.crossing_at(p)), "a load still goes over")


func test_the_hurt_do_not_go_over() -> void:
	var p = game.player
	p.position = FieldGrid.center(below)
	var way: Dictionary = game.actions.crossing_at(p)
	p.body.leg_fracture = true
	assert_ne(game.actions.cross_refused(p, way), "")
	assert_false(game.actions.cross_train(p, way))
	assert_eq(p.action, "")


func test_one_at_a_time_and_the_companions_come_after_the_chief() -> void:
	var p = game.player
	var mate = _mate()
	for o in game.squad:
		o.position = FieldGrid.center(below + Vector2i(0, 4))
		o.command = "wait" if o != p and o != mate else o.command
	p.position = FieldGrid.center(below)
	mate.position = FieldGrid.center(below + Vector2i(1, 1))
	mate.command = "follow"
	var way: Dictionary = game.actions.crossing_at(p)
	game.actions.cross_train(p, way)
	assert_ne(game.actions.cross_refused(mate, way), "", "the way is taken")
	game._step(3.1)
	assert_eq(FieldGrid.cell_of(p.position), above)
	assert_true(mate.brain.has("cross"), "the one who follows is told to come over")
	for i in 80:
		game._step(0.1)
		if FieldGrid.cell_of(mate.position).y < game.data["train"].position.y:
			break
	assert_lt(FieldGrid.cell_of(mate.position).y, game.data["train"].position.y, "and comes over the same way")
	assert_false(mate.brain.has("cross"))


func test_grabbed_half_way_you_come_down_where_you_started() -> void:
	var p = game.player
	p.position = FieldGrid.center(below)
	game.actions.cross_train(p, game.actions.crossing_at(p))
	game._step(1.0)
	var z: Dictionary = game.zombies.spawn("dead", p.position + Vector3(0.5, 0, 0.5))
	p.grabbers.append(z)
	game.actions.update(0.02)
	assert_eq(p.action, "", "the climb is over")
	assert_gt(p.fallen_t, 0.0, "down on the ground")
	assert_eq(FieldGrid.cell_of(p.position), below)
	assert_false(p.brain.has("crossing"))


func test_the_dead_still_go_round_the_train() -> void:
	# The cells of the way stay blocked: nothing walks through the coupling.
	for c: Vector2i in game.data["crossings"][0]["cells"]:
		assert_false(game.grid.dead_can_walk(c))
