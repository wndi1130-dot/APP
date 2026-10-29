extends "res://addons/gut/test.gd"
## Pushing a map down to make room above its train (the maps with ground on
## both sides of the track).

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const Sulehuf = preload("res://game/world/sulehuf_map.gd")
const Pushed = preload("res://tests/game/fixtures/pushed_down_map.gd")

const ROWS: int = 45


func test_every_cell_and_rect_moves_down_and_directions_do_not() -> void:
	var was: Dictionary = Sulehuf.build()
	var now: Dictionary = MapShift.shift_rows(Sulehuf.build(), ROWS)
	var down := Vector2i(0, ROWS)
	assert_eq(now["train"], Rect2i(was["train"].position + down, was["train"].size))
	assert_eq(now["platform"].position, was["platform"].position + down)
	assert_eq(now["manholes"]["manhole"], was["manholes"]["manhole"] + down)
	assert_eq(now["entries"]["south_road"][0], was["entries"]["south_road"][0] + down)
	assert_eq(now["spawns"]["squad"][0], was["spawns"]["squad"][0] + down)
	assert_eq(now["anchors"]["whistle"], was["anchors"]["whistle"] + down)
	assert_eq(now["buildings"][0]["rect"].position, was["buildings"][0]["rect"].position + down)
	assert_eq(now["stairs"][0]["cell"], was["stairs"][0]["cell"] + down)
	assert_eq(now["low_blocks"][0].position, was["low_blocks"][0].position + down)
	assert_eq(now["spots"]["water_tower"]["cell"], was["spots"]["water_tower"]["cell"] + down)
	var box: String = was["containers"].keys()[0]
	assert_eq(now["containers"][box]["cell"], was["containers"][box]["cell"] + down)
	assert_eq(now["lights"][0]["cell"], was["lights"][0]["cell"] + down)
	assert_eq(now["lights"][0].get("side", Vector2i.ZERO), was["lights"][0].get("side", Vector2i.ZERO), "which way a lamp faces is not a place")
	assert_eq(now["hole_faces"], was["hole_faces"], "nor which way a hole opens")
	assert_eq(now["zone_names"], was["zone_names"])
	assert_eq(now["entry_gap"], was["entry_gap"])
	assert_eq(now["manhole_levels"], was["manhole_levels"])


func test_the_grids_keep_what_they_held_under_empty_rows() -> void:
	var was: Dictionary = Sulehuf.build()
	var now: Dictionary = MapShift.shift_rows(Sulehuf.build(), ROWS)
	assert_eq(now["grid"], now["levels"][0])
	for lv in was["levels"]:
		var a: FieldGrid = was["levels"][lv]
		var b: FieldGrid = now["levels"][lv]
		assert_eq(b.width, a.width)
		assert_eq(b.height, a.height + ROWS)
		var same := true
		for i in range(a.width * a.height):
			var j: int = i + ROWS * a.width
			if a.solid[i] != b.solid[j] or a.floor[i] != b.floor[j] or a.building[i] != b.building[j] or a.zone[i] != b.zone[j] or a.walk_people[i] != b.walk_people[j] or a.opq[i] != b.opq[j]:
				same = false
				break
		assert_true(same, "level %d: every cell is where it was, %d rows down" % [lv, ROWS])
		assert_eq(b.doors.size(), a.doors.size())
		assert_eq(b.windows.size(), a.windows.size())
		for c: Vector2i in a.doors:
			assert_true(b.doors.has(c + Vector2i(0, ROWS)))
			break
	var ground: FieldGrid = now["grid"]
	assert_true(ground.people_can_walk(Vector2i(40, 10)), "the new rows of the ground are open snow")
	assert_eq(ground.floor_at(Vector2i(40, 10)), FieldGrid.Floor.SNOW)
	assert_eq(now["levels"][1].solid_at(Vector2i(40, 10)), FieldGrid.Solid.AIR, "open air upstairs")
	assert_eq(now["levels"][-1].solid_at(Vector2i(40, 10)), FieldGrid.Solid.BLOCK, "rock below")
	assert_false(ground.find_path(FieldGrid.center(Vector2i(40, 10)), FieldGrid.center(now["spawns"]["squad"][0])).is_empty(), "and one can walk from them round the train to the platform")


func test_no_rows_is_the_map_as_it_was() -> void:
	var d: Dictionary = Sulehuf.build()
	assert_same(MapShift.shift_rows(d, 0), d)


func test_the_field_plays_on_a_pushed_down_map() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	game.map_script = Pushed
	add_child_autofree(game)
	game.set_process(false)
	var train: Rect2i = game.data["train"]
	assert_eq(train.position.y, 1 + ROWS, "the train stands in the middle now")
	assert_eq(game.data["train_doors"]["upper"].size(), 3, "with doors the map added above")
	assert_eq(FieldGrid.cell_of(game.player.position).y, FieldGrid.cell_of(FieldGrid.center(game.data["spawns"]["squad"][0])).y)
	for i in range(60):
		game._step(0.1)
	game._start_horde({"index": 0, "size": 4, "entry": "upper_field"})
	for i in range(60):
		game._step(0.1)
	assert_gt(game.zombies.list.filter(func(z: Dictionary) -> bool: return int(z.get("horde", -1)) == 0).size(), 0, "a horde comes in over the new ground")
	game.finish("departed")
	assert_true(game.ended)


## Every cell's walk caches and both path grids' points (solid, weight), to compare.
static func _paths_of(g: FieldGrid) -> Array:
	var points := PackedFloat32Array()
	for y in range(g.height):
		for x in range(g.width):
			var c := Vector2i(x, y)
			points.append(1.0 if g.people_path.is_point_solid(c) else 0.0)
			points.append(1.0 if g.dead_path.is_point_solid(c) else 0.0)
			points.append(g.people_path.get_point_weight_scale(c))
	return [g.opq.duplicate(), g.walk_people.duplicate(), g.walk_dead.duplicate(), points]


## A finished map's paths are right on every floor; carried over (each cell's caches read
## only the cell, the band added round them the empty kind's) they are what a refresh makes.
func test_grown_paths_are_carried_over_as_a_refresh_would_make_them() -> void:
	var was: Dictionary = FieldMaps.build("houses_01")
	for lv in was["levels"]:
		var g: FieldGrid = was["levels"][lv]
		var built := _paths_of(g)
		g.refresh_paths()
		assert_eq(built, _paths_of(g), "level %d of the finished map is right as built" % lv)
	for sides: Array in [[30, 0, 0, 7], [0, 12, 25, 0]]:
		var now: Dictionary = MapShift.grow(was, sides[0], sides[1], sides[2], sides[3], true, true)
		for lv in now["levels"]:
			var g: FieldGrid = now["levels"][lv]
			assert_true(g.paths_ready(), "level %d" % lv)
			var carried := _paths_of(g)
			g.refresh_paths()
			assert_eq(carried, _paths_of(g), "level %d grown %s: carried paths are a refresh's" % [lv, str(sides)])
