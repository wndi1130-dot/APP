extends GutTest
## The decor cells table (decor_cells.json) is what the cars' layouts say, for the rules and the view alike.

const DecorGrid = preload("res://game/train/decor_grid.gd")
const Catalog = preload("res://game/train/train_catalog.gd")
const Rules = preload("res://game/train/train_rules.gd")
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
		# The table names the layout the game gives the car.
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


func test_a_point_finds_its_floor_cell() -> void:
	for ix: int in [0, 7, 15, DecorGrid.NX - 1]:
		for iz in DecorGrid.NZ:
			assert_eq(DecorGrid.floor_cell(DecorGrid.floor_center(ix, iz)), Vector2i(ix, iz))
	assert_eq(DecorGrid.floor_cell(Vector3(0.1, 0.0, 0.0)), Vector2i(-1, -1), "past the end wall")
	assert_eq(DecorGrid.floor_cell(Vector3(8.0, 0.0, 1.4)), Vector2i(-1, -1), "past the camera's side")
