extends RefCounted
## The decor cells of a car a player dresses (결정 506 직접 놓기, 510 꾸미기 화면, 511 여덟 칸): its floor
## in 0.5 m cells (31 x 5, x 0.25~15.75 m, z -1.25~1.25 m, row 0 at the back wall), the back wall in the
## same columns and the end walls' two cells behind each door's way. decor_cells.json keeps the table the
## decorating rules read (open places) and this works the same table out of the car's layout rows;
## tools/decor_cells.py writes the json the same way, and test_decor_grid.gd keeps the two equal.
## Marks: . free, # a thing, S the stove, D a door's way, W the walking line, G a window.

const TABLE_PATH := "res://game/train/decor_cells.json"
const CELL: float = 0.5
const NX: int = 31
const NZ: int = 5
const X0: float = 0.25
const Z0: float = -1.25
const WALK_ROW: int = 3
## The walking line keeps this much from the edge of the things behind it: where a thing reaches into
## its row (the dining car's bench before the table) the row before it walks too, joined to z3 four ways.
const WALK_WIDTH: float = 0.5
## Where the train's people walk (train_scene.gd AISLE_Z): things whose edge stops short of it are behind the line.
const AISLE_Z: float = 0.65
const DOOR_Z := Vector2(0.2, 1.1)
## A thing stands on the floor when its bottom is under this; laid flat (a rug) when no taller than FLAT.
const FLOOR_BOTTOM: float = 0.4
const FLAT: float = 0.03
## A cell is blocked when a footprint covers more than this share of it.
const SHARE: float = 0.10
## A wall cell is taken by something hung (its bottom this high or more) or by a thing standing
## against that wall whose top rises above a wall place's foot (decor_view.gd: 1.45 m middle, 0.6 m high).
const HUNG: float = 0.6
const PLACE_LOW: float = 1.15
const BACK_WALL: float = -1.24
const END_WALLS := Vector2(0.15, 15.85)
## Ties (just a tenth of a cell, a bottom at just 0.4 m) go to free, as in the tool.
const EPS: float = 0.000001
const WINDOWS: Array[Vector2] = [Vector2(1.2, 2.8), Vector2(5.2, 6.8), Vector2(9.2, 10.8), Vector2(13.2, 14.8)]

static var _table: Dictionary = {}


static func table() -> Dictionary:
	if _table.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
		if parsed is Dictionary:
			_table = parsed
	return _table


## The car's cells as the table keeps them, or {} when it is not a car a player dresses.
static func of(car_id: String) -> Dictionary:
	return table().get("cars", {}).get(car_id, {})


## The middle of a floor cell in the car's own space, on the floor.
static func floor_center(ix: int, iz: int) -> Vector3:
	return Vector3(X0 + (ix + 0.5) * CELL, 0.0, Z0 + (iz + 0.5) * CELL)


## The floor cell under a point in the car's own space, or (-1, -1) off the grid.
static func floor_cell(at: Vector3) -> Vector2i:
	var ix := floori((at.x - X0) / CELL)
	var iz := floori((at.z - Z0) / CELL)
	if ix < 0 or ix >= NX or iz < 0 or iz >= NZ:
		return Vector2i(-1, -1)
	return Vector2i(ix, iz)


## The rows of a layout kept for this car (a row with "cars" only for those it names).
static func rows_for(rows: Array, car_id: String) -> Array:
	var mine: Array = []
	for row: Dictionary in rows:
		if row.has("cars") and not (row["cars"] as Array).has(car_id):
			continue
		mine.append(row)
	return mine


## A row's turned box: [x0, x1, z0, z1, bottom, top].
static func bounds(row: Dictionary) -> Array:
	var at: Array = row["at"]
	var size: Array = row.get("size", [0.8, 1.0, 0.8])
	var pts := _footprint(at, size, float(row.get("yaw", 0.0)))
	var b: Array = [INF, -INF, INF, -INF, float(at[1]) - float(size[1]) / 2.0, float(at[1]) + float(size[1]) / 2.0]
	for p: Array in pts:
		b[0] = minf(b[0], float(p[0]))
		b[1] = maxf(b[1], float(p[0]))
		b[2] = minf(b[2], float(p[1]))
		b[3] = maxf(b[3], float(p[1]))
	return b


static func on_floor(row: Dictionary) -> bool:
	var size: Array = row.get("size", [0.8, 1.0, 0.8])
	return float(size[1]) > FLAT + EPS and float(row["at"][1]) - float(size[1]) / 2.0 < FLOOR_BOTTOM - EPS


static func _blocks_wall(b: Array) -> bool:
	return float(b[4]) >= HUNG - EPS or float(b[5]) > PLACE_LOW + EPS


## Works the cells out of a layout's rows, as the table does.
static func cells_of(rows: Array, car_id: String) -> Dictionary:
	var mine := rows_for(rows, car_id)
	var grid: Array = []
	for iz in NZ:
		var line: Array = []
		line.resize(NX)
		line.fill(".")
		grid.append(line)
	var reach: Array = []
	reach.resize(NX)
	reach.fill(Z0 + WALK_ROW * CELL)
	for row: Dictionary in mine:
		if not on_floor(row):
			continue
		var poly := _footprint(row["at"], row.get("size", [0.8, 1.0, 0.8]), float(row.get("yaw", 0.0)))
		var b := bounds(row)
		var mark := "S" if String(row.get("system", "")) == "stove" else "#"
		for iz in NZ:
			for ix in NX:
				if _covered(poly, X0 + ix * CELL, Z0 + iz * CELL) > SHARE * CELL * CELL + EPS:
					grid[iz][ix] = mark
		if float(b[3]) < AISLE_Z:
			for ix in NX:
				var x0: float = X0 + ix * CELL
				if float(b[0]) < x0 + CELL - EPS and float(b[1]) > x0 + EPS:
					reach[ix] = maxf(float(reach[ix]), float(b[3]))
	for iz in NZ:
		var z0: float = Z0 + iz * CELL
		if z0 < DOOR_Z.y and z0 + CELL > DOOR_Z.x:
			for ix: int in [0, NX - 1]:
				if grid[iz][ix] == ".":
					grid[iz][ix] = "D"
	for ix in NX:
		for iz in range(WALK_ROW, NZ):
			var z0: float = Z0 + iz * CELL
			if (iz == WALK_ROW or z0 < float(reach[ix]) + WALK_WIDTH - EPS) and grid[iz][ix] == ".":
				grid[iz][ix] = "W"
	# The way walks four ways, never across a corner (코디 10-30): a run of a row past z3 walked for a
	# thing reaching into z3 joins z3 in its own end column, or else the column beside it walks that row too.
	for iz in range(WALK_ROW + 1, NZ):
		var ix := 0
		while ix < NX:
			if grid[iz][ix] != "W":
				ix += 1
				continue
			var a := ix
			while ix < NX and grid[iz][ix] == "W":
				ix += 1
			var b := ix - 1
			for pair: Array in [[a, a - 1], [b, b + 1]]:
				var end: int = pair[0]
				var side: int = pair[1]
				if not (String(grid[iz - 1][end]) in ["W", "D"]) and side >= 0 and side < NX and grid[iz][side] == ".":
					grid[iz][side] = "W"
					ix = maxi(ix, side + 1)
	var back := ""
	for ix in NX:
		var x0: float = X0 + ix * CELL
		var mark := "."
		for w: Vector2 in WINDOWS:
			if x0 < w.y and x0 + CELL > w.x:
				mark = "G"
		for row: Dictionary in mine:
			var b := bounds(row)
			if float(b[2]) <= BACK_WALL + EPS and _blocks_wall(b) and x0 < float(b[1]) - 0.05 and x0 + CELL > float(b[0]) + 0.05:
				mark = "#"
		back += mark
	var ends := ""
	for left: bool in [true, false]:
		for iz: int in [0, 1]:
			var z0: float = Z0 + iz * CELL
			var mark := "."
			for row: Dictionary in mine:
				var b := bounds(row)
				var near: bool = float(b[0]) <= END_WALLS.x + EPS if left else float(b[1]) >= END_WALLS.y - EPS
				if near and _blocks_wall(b) and z0 < float(b[3]) and z0 + CELL > float(b[2]):
					mark = "#"
			ends += mark
	var floor_rows := PackedStringArray()
	var floor_free := 0
	for line: Array in grid:
		var text := "".join(PackedStringArray(line))
		floor_rows.append(text)
		floor_free += text.count(".")
	return {"floor": floor_rows, "back_wall": back, "end_walls": ends, "floor_free": floor_free,
		"wall_free": back.count(".") + ends.count(".")}


## The turned footprint on the floor as [x, z] corners, turned about y as Godot turns (doubles, not Vector2).
static func _footprint(at: Array, size: Array, yaw: float) -> Array:
	var hx: float = float(size[0]) / 2.0
	var hz: float = float(size[2]) / 2.0
	var c := cos(yaw)
	var s := sin(yaw)
	var pts: Array = []
	for d: Array in [[-hx, -hz], [hx, -hz], [hx, hz], [-hx, hz]]:
		pts.append([float(at[0]) + d[0] * c + d[1] * s, float(at[2]) - d[0] * s + d[1] * c])
	return pts


## How much of the cell at (x0, z0) the footprint covers (Sutherland-Hodgman clip, then its area).
static func _covered(poly: Array, x0: float, z0: float) -> float:
	var p := poly
	for edge in 4:
		p = _clip(p, edge, x0, z0)
		if p.is_empty():
			return 0.0
	var twice := 0.0
	for i in p.size():
		var a: Array = p[i]
		var b: Array = p[(i + 1) % p.size()]
		twice += float(a[0]) * float(b[1]) - float(b[0]) * float(a[1])
	return absf(twice) / 2.0 if p.size() > 2 else 0.0


static func _side(q: Array, edge: int, x0: float, z0: float) -> float:
	match edge:
		0:
			return float(q[0]) - x0
		1:
			return x0 + CELL - float(q[0])
		2:
			return float(q[1]) - z0
	return z0 + CELL - float(q[1])


static func _clip(poly: Array, edge: int, x0: float, z0: float) -> Array:
	var out: Array = []
	for i in poly.size():
		var a: Array = poly[i]
		var b: Array = poly[(i + 1) % poly.size()]
		var fa := _side(a, edge, x0, z0)
		var fb := _side(b, edge, x0, z0)
		if fa >= 0.0:
			out.append(a)
		if (fa >= 0.0) != (fb >= 0.0):
			var t := fa / (fa - fb)
			out.append([float(a[0]) + (float(b[0]) - float(a[0])) * t, float(a[1]) + (float(b[1]) - float(a[1])) * t])
	return out
