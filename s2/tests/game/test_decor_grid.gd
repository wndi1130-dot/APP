extends GutTest
## The decor cells table (decor_cells.json) is what the cars' layouts say, for the rules and the view alike.

const DecorGrid = preload("res://game/train/decor_grid.gd")
const Catalog = preload("res://game/train/train_catalog.gd")
const Rules = preload("res://game/train/train_rules.gd")
const Scene = preload("res://game/train/train_scene.gd")
const DRESSED: Array[String] = ["tail1", "tail2", "tail3", "medtech", "guard", "front", "captain", "dining"]


func _def(id: String) -> Dictionary:
	for car: Dictionary in Rules.load_default()["cars"]:
		if String(car["id"]) == id:
			return car
	return {}


func test_the_table_is_what_the_layouts_say() -> void:
	var table: Dictionary = DecorGrid.table()
	assert_eq(float(table.get("cell_m", 0.0)), DecorGrid.CELL)
	assert_eq([int(table["cells"][0]), int(table["cells"][1])], [DecorGrid.NX, DecorGrid.NZ])
	assert_eq((table["cars"] as Dictionary).keys().size(), DRESSED.size())
	for id: String in DRESSED:
		var kept: Dictionary = DecorGrid.of(id)
		assert_false(kept.is_empty(), id + " is in the table")
		if kept.is_empty():
			continue
		# The table names the layout the game gives the car (a car missing from the rules fails here,
		# not into the tail cars' default layout).
		assert_false(_def(id).is_empty(), id + " is a car in the rules")
		assert_eq(String(kept["layout"]), Catalog.layout_id(_def(id)), id + ": its layout")
		var got: Dictionary = DecorGrid.cells_of(Catalog.layout(_def(id))["props"], id)
		var hint := id + ": run tools/decor_cells.py after moving a layout row"
		assert_eq(Array(got["floor"]), kept["floor"], hint)
		assert_eq(got["back_wall"], kept["back_wall"], hint)
		assert_eq(got["end_walls"], kept["end_walls"], hint)
		assert_eq(got["floor_free"], int(kept["floor_free"]), hint)
		assert_eq(got["wall_free"], int(kept["wall_free"]), hint)


func test_the_walking_line_and_the_door_ways_stay_clear() -> void:
	for id: String in DRESSED:
		var floor_rows: Array = DecorGrid.of(id)["floor"]
		assert_eq(floor_rows.size(), DecorGrid.NZ)
		assert_false(String(floor_rows[DecorGrid.WALK_ROW]).contains("."), id + ": nothing goes on the walking line")
		for iz in DecorGrid.NZ:
			var z0: float = DecorGrid.Z0 + iz * DecorGrid.CELL
			if z0 < DecorGrid.DOOR_Z.y and z0 + DecorGrid.CELL > DecorGrid.DOOR_Z.x:
				for ix: int in [0, DecorGrid.NX - 1]:
					assert_ne(String(floor_rows[iz])[ix], ".", "%s: the door's way at (%d, %d)" % [id, ix, iz])


## Where the people walk (train_scene.gd AISLE_Z) there is 0.5 m between the things behind the line
## and the first cell a thing may be put in, in every column but the door's ways. Worked from the rows'
## boxes, not from the marks (the dining car's bench reaches into the walking row: the row before it walks).
func test_the_walking_line_keeps_half_a_metre_clear() -> void:
	var aisle: float = Scene.AISLE_Z
	assert_eq(DecorGrid.AISLE_Z, aisle, "the grid walks where the people walk")
	for id: String in DRESSED:
		var floor_rows: Array = DecorGrid.of(id)["floor"]
		var rows := DecorGrid.rows_for(Catalog.layout(_def(id))["props"], id)
		for ix in range(1, DecorGrid.NX - 1):
			var x0: float = DecorGrid.X0 + ix * DecorGrid.CELL
			var behind: float = DecorGrid.Z0 + DecorGrid.WALK_ROW * DecorGrid.CELL
			for row: Dictionary in rows:
				var b := DecorGrid.bounds(row)
				if DecorGrid.on_floor(row) and float(b[3]) < aisle and float(b[0]) < x0 + DecorGrid.CELL and float(b[1]) > x0:
					behind = maxf(behind, float(b[3]))
			# The first row past the walking row a thing may go in.
			var open_z: float = DecorGrid.Z0 + DecorGrid.NZ * DecorGrid.CELL
			for iz in range(DecorGrid.NZ - 1, DecorGrid.WALK_ROW, -1):
				if String(floor_rows[iz])[ix] == ".":
					open_z = DecorGrid.Z0 + iz * DecorGrid.CELL
			assert_gte(open_z - behind, 0.5 - 0.000001, "%s: column %d walks %.2f m" % [id, ix, open_z - behind])


## The way from door to door joins four ways only (코디 10-30: no step across a table's corner):
## from the door's way at one end the walked cells reach the other end's.
func test_the_way_goes_door_to_door_four_ways() -> void:
	for id: String in DRESSED:
		var floor_rows: Array = DecorGrid.of(id)["floor"]
		var seen := {}
		var todo: Array[Vector2i] = []
		for iz in DecorGrid.NZ:
			if String(floor_rows[iz])[0] in ["D", "W"]:
				todo.append(Vector2i(0, iz))
		while not todo.is_empty():
			var at: Vector2i = todo.pop_back()
			if seen.has(at):
				continue
			seen[at] = true
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var next: Vector2i = at + step
				var inside: bool = next.x >= 0 and next.x < DecorGrid.NX and next.y >= 0 and next.y < DecorGrid.NZ
				if inside and String(floor_rows[next.y])[next.x] in ["D", "W"]:
					todo.append(next)
		var reached := false
		for iz in DecorGrid.NZ:
			reached = reached or seen.has(Vector2i(DecorGrid.NX - 1, iz))
		assert_true(reached, id + ": the walked cells join the two doors four ways")


func test_a_point_finds_its_floor_cell() -> void:
	for ix: int in [0, 7, 15, DecorGrid.NX - 1]:
		for iz in DecorGrid.NZ:
			assert_eq(DecorGrid.floor_cell(DecorGrid.floor_center(ix, iz)), Vector2i(ix, iz))
	assert_eq(DecorGrid.floor_cell(Vector3(0.1, 0.0, 0.0)), Vector2i(-1, -1), "past the end wall")
	assert_eq(DecorGrid.floor_cell(Vector3(8.0, 0.0, 1.4)), Vector2i(-1, -1), "past the camera's side")
