extends "res://addons/gut/test.gd"
## The wind indoors (field_audio openness_at): heard through the building, not
## cut to a third at the door. Loud in a doorway, lower and more muffled the
## more air there is to the nearest opening, and going in or out it follows
## instead of stepping (user 2026-10-28: 「싸구려겜같음」).

const FieldGame = preload("res://game/field_game.gd")
const FieldAudio = preload("res://game/audio/field_audio.gd")
const Grid = preload("res://game/world/field_grid.gd")

const FRAME: float = 1.0 / 60.0
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var game


func before_each() -> void:
	seed(20261029)
	game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()


## A 5 x 5 room in a ring of wall on a 9 x 9 grid, building 0 inside and on its
## walls, a shut door in the west wall at (1, 4); open ground all round.
func _room() -> Grid:
	var g := Grid.new(9, 9)
	for y in range(1, 8):
		for x in range(1, 8):
			var c := Vector2i(x, y)
			g.building[g.index(c)] = 0
			if x == 1 or y == 1 or x == 7 or y == 7:
				g.solid[g.index(c)] = Grid.Solid.WALL
	var door := Vector2i(1, 4)
	g.solid[g.index(door)] = Grid.Solid.DOOR
	g.doors[door] = {"state": "closed", "hp": 3, "building": 0}
	return g


## One of the stop map's building doors on the ground with open ground outside it
## and two cells of floor in from it: [door, outside, one in, two in].
func _door_way() -> Array:
	var g = game.grid
	for c: Vector2i in g.doors:
		if int(g.doors[c].get("building", -1)) < 0:
			continue
		for d: Vector2i in DIRS:
			var out_c: Vector2i = c - d
			var in1: Vector2i = c + d
			var in2: Vector2i = c + d * 2
			if g.indoor(out_c) or not g.people_can_walk(out_c):
				continue
			if g.indoor(in1) and g.indoor(in2) and g.solid_at(in1) == Grid.Solid.NONE and g.solid_at(in2) == Grid.Solid.NONE:
				return [c, out_c, in1, in2]
	return []


## Every window of building b shut and whole, every door of it shut.
func _seal(b: int) -> void:
	var g = game.grid
	for c: Vector2i in g.windows:
		if int(g.windows[c].get("building", -1)) == b:
			g.windows[c]["broken"] = false
			g.windows[c]["open"] = false
	for c: Vector2i in g.doors:
		if int(g.doors[c].get("building", -1)) == b:
			g.doors[c]["state"] = "closed"
	g.revision += 1


func test_the_air_to_an_opening_is_counted_through_open_doors_and_broken_windows() -> void:
	var g := _room()
	assert_eq(FieldAudio.open_distance(g, Vector2i(4, 4)), INF, "a shut door lets no wind in")
	g.doors[Vector2i(1, 4)]["state"] = "open"
	assert_eq(FieldAudio.open_distance(g, Vector2i(2, 4)), 2.0, "in, the door, out")
	assert_eq(FieldAudio.open_distance(g, Vector2i(5, 4)), 5.0)
	g.doors[Vector2i(1, 4)]["state"] = "broken"
	assert_eq(FieldAudio.open_distance(g, Vector2i(2, 4)), 2.0, "a broken door is as open")
	g.doors[Vector2i(1, 4)]["state"] = "locked"
	var pane := Vector2i(4, 1)
	g.solid[g.index(pane)] = Grid.Solid.WINDOW
	g.windows[pane] = {"broken": true, "glass": true, "building": 0}
	assert_eq(FieldAudio.open_distance(g, Vector2i(4, 2)), 2.0, "a broken window lets it in")
	g.windows[pane]["planks"] = [2, 0]
	assert_eq(FieldAudio.open_distance(g, Vector2i(4, 2)), INF, "boarded up, it does not")
	# The nearest outside wall: from the room's middle three cells to any side.
	assert_almost_eq(FieldAudio.wall_distance(g, Vector2i(4, 4)), 3.0, 0.001)
	assert_almost_eq(FieldAudio.wall_distance(g, Vector2i(2, 4)), sqrt(2.0), 0.001, "the wall beside the door")


func test_deeper_inside_the_wind_is_lower_and_more_muffled() -> void:
	var doorway: float = FieldAudio.INDOOR_OPEN * FieldAudio.exposure(1.0, INF)
	var in_four: float = FieldAudio.INDOOR_OPEN * FieldAudio.exposure(4.0, INF)
	var by_wall: float = FieldAudio.INDOOR_OPEN * FieldAudio.exposure(INF, 1.0)
	var deep: float = FieldAudio.INDOOR_OPEN * FieldAudio.exposure(INF, INF)
	assert_gt(doorway, in_four)
	assert_gt(in_four, by_wall, "four metres from an open door is more than a wall")
	assert_gt(by_wall, deep, "a wall lets a little through")
	assert_eq(deep, 0.0)
	var db := func(o: float) -> float: return linear_to_db(FieldAudio.indoor_gain(o))
	assert_gt(db.call(doorway), -2.5, "in a doorway nearly all of it")
	assert_lt(db.call(deep), -15.0, "deep inside little of it")
	assert_gt(FieldAudio.wind_cutoff(1.0), 19000.0, "outdoors nothing is taken off")
	assert_lt(FieldAudio.wind_cutoff(deep), 600.0, "deep inside only its low rumble")
	assert_gt(FieldAudio.wind_cutoff(doorway), FieldAudio.wind_cutoff(in_four))
	assert_gt(FieldAudio.wind_cutoff(in_four), FieldAudio.wind_cutoff(by_wall))


func test_going_in_the_wind_follows_and_never_drops_in_one_step() -> void:
	# The rule before: outdoors 1, indoors 0.35 from the first frame in, a step of
	# 20 log 0.35 = -9.1 dB. Now from outdoors to two metres in, frame by frame.
	var target: float = FieldAudio.INDOOR_OPEN * FieldAudio.exposure(2.0, INF)
	var o: float = 1.0
	var worst: float = 0.0
	var was: float = linear_to_db(FieldAudio.indoor_gain(o))
	for k in range(90):
		o = FieldAudio.follow_open(o, target, FRAME)
		var now: float = linear_to_db(FieldAudio.indoor_gain(o))
		worst = maxf(worst, absf(now - was))
		was = now
	assert_lt(worst, 1.0, "no frame steps the wind by a decibel")
	assert_almost_eq(o, target, 0.01, "in a second and a half it is where it should be")
	assert_almost_eq(FieldAudio.follow_open(0.3, 0.3, FRAME), 0.3, 0.000001, "standing still, it stays")


func test_an_open_door_lets_the_wind_into_a_house_on_the_map() -> void:
	var way: Array = _door_way()
	assert_false(way.is_empty(), "the map has a door into a building with floor behind it")
	if way.is_empty():
		return
	var a = game.audio
	var g = game.grid
	var door: Vector2i = way[0]
	_seal(int(g.doors[door].get("building", -1)))
	var shut: float = a.openness_at(game.lift(way[3], 0))
	g.doors[door]["state"] = "open"
	g.revision += 1
	var near: float = a.openness_at(game.lift(way[2], 0))
	var two_in: float = a.openness_at(game.lift(way[3], 0))
	assert_gt(two_in, shut, "the open door lets the wind in")
	assert_gt(near, two_in, "nearer the door, more of it")
	assert_eq(a.openness_at(game.lift(way[1], 0)), 1.0, "outside, all of it")


func test_a_cellar_hears_a_little_of_the_floor_above() -> void:
	var way: Array = _door_way()
	assert_false(way.is_empty(), "the map has a door into a building with floor behind it")
	if way.is_empty():
		return
	var a = game.audio
	var g = game.grid
	var door: Vector2i = way[0]
	_seal(int(g.doors[door].get("building", -1)))
	g.doors[door]["state"] = "open"
	g.revision += 1
	var above: float = a.openness_at(game.lift(way[3], 0))
	var below: Vector3 = game.lift(way[3], -1)
	assert_eq(game.level_of(below), -1, "a place in the cellar")
	var down: float = a.openness_at(below)
	assert_almost_eq(down, FieldAudio.CELLAR_SHARE * above, 0.0001, "the floor above's, a little")
	assert_gt(down, 0.0, "an open door upstairs is heard down there")
	assert_almost_eq(a.openness_at(game.lift(way[1], -1)), FieldAudio.CELLAR_SHARE, 0.0001, "under open ground, the most a cellar hears")


func test_walking_in_through_the_door_the_wind_fades_and_its_bus_closes_in() -> void:
	var way: Array = _door_way()
	assert_false(way.is_empty(), "the map has a door into a building with floor behind it")
	if way.is_empty():
		return
	var a = game.audio
	var g = game.grid
	var i: int = AudioServer.get_bus_index(FieldAudio.WIND_BUS)
	assert_true(i >= 0, "the wind has a bus of its own")
	assert_eq(AudioServer.get_bus_send(i), &"SFX", "sent to SFX: it ducks with the rest")
	assert_true(AudioServer.get_bus_effect(i, 0) is AudioEffectLowPassFilter)
	assert_eq(String((a.bed_players[0] as AudioStreamPlayer).bus), FieldAudio.WIND_BUS)
	assert_false(a.bed_name == "", "the stop has a bed to hear")
	var door: Vector2i = way[0]
	_seal(int(g.doors[door].get("building", -1)))
	g.doors[door]["state"] = "open"
	g.revision += 1
	game.weather.wind = 0.6
	a.wind_up = 100.0   # long after getting down: the bed has come up
	var outside: Vector3 = game.lift(way[1], 0)
	var inside: Vector3 = game.lift(way[3], 0)
	for k in range(60):
		a._tick_wind(outside, FRAME)
	var out_db: float = a.bed_db()
	assert_gt(a.wind_cut, 19000.0, "outdoors the bus takes nothing off")
	var low := AudioServer.get_bus_effect(i, 0) as AudioEffectLowPassFilter
	assert_almost_eq(low.cutoff_hz, a.wind_cut, 0.5, "the bus's own low-pass is what is heard")
	var was: float = out_db
	var worst: float = 0.0
	for k in range(150):
		a._tick_wind(outside.lerp(inside, clampf(k / 60.0, 0.0, 1.0)), FRAME)
		var now: float = a.bed_db()
		worst = maxf(worst, absf(now - was))
		was = now
	assert_lt(worst, 1.5, "walking in, no frame steps the wind (the rule before: 9.1 dB at the door)")
	assert_lt(a.bed_db(), out_db - 2.0, "two in, it is lower")
	assert_lt(a.wind_cut, 8000.0, "and more muffled")
	assert_almost_eq(low.cutoff_hz, a.wind_cut, 0.5)
	for k in range(90):
		a._tick_wind(outside, FRAME)
	assert_gt(a.wind_cut, 19000.0, "back out, it opens again")
