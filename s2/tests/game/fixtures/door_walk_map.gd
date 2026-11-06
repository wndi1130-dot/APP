extends RefCounted
## A fixed corridor on the existing small save fixture; no generated doors.

const BareLine = preload("res://tests/game/fixtures/bare_line_map.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const PLACE_ID: String = BareLine.PLACE_ID
const FIRST := Vector2i(30, 8)
const SECOND := Vector2i(31, 8)
const WINDOW := Vector2i(29, 8)


static func build() -> Dictionary:
	var data: Dictionary = BareLine.build()
	var grid = data["grid"]
	for cell: Vector2i in [FIRST, SECOND]:
		grid.doors[cell] = {"state": "closed" if cell == FIRST else "open",
			"hp": 3, "building": -1, "key": "", "planks": [0, 0], "busy": false}
		grid.set_solid(cell, FieldGrid.Solid.DOOR)
	grid.refresh_paths()
	return data


static func add_window(grid, glass: bool = false) -> void:
	grid.windows[WINDOW] = {"broken": true, "glass": glass, "open": false,
		"building": -1, "latched": false, "stuck": false, "curtain": "",
		"planks": [0, 0], "busy": false}
	grid.set_solid(WINDOW, FieldGrid.Solid.WINDOW)
	grid.refresh_paths()
