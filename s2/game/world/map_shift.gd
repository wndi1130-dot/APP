extends RefCounted
## Push a whole map down by some rows, to make room above its train.
## A map written with the track along its top edge calls this at the end of
## its build() and then lays out the new ground above in the new coordinates:
##
##     data = MapShift.shift_rows(data, 45)
##     ...  # build the upper side on data["grid"], data["levels"][...]
##     for lv in data["levels"]:
##         data["levels"][lv].refresh_paths()
##
## Every level gets the rows put in at its top: open snow on the ground,
## open air upstairs, rock below. Every cell and rect in the data moves down
## with them. What says a direction and not a place stays as it is.

const FieldGrid = preload("res://game/world/field_grid.gd")

## Keys whose values are directions, not places.
const DIRECTIONS: Array[String] = ["hole_faces", "side", "facing"]


static func shift_rows(data: Dictionary, rows: int) -> Dictionary:
	if rows <= 0:
		return data
	var levels: Dictionary = {}
	for lv in data.get("levels", {}):
		levels[lv] = _taller(data["levels"][lv], rows, int(lv))
	if levels.is_empty():
		levels[0] = _taller(data["grid"], rows, 0)
	var out: Dictionary = _moved(data, rows, "")
	out["levels"] = levels
	out["grid"] = levels[0]
	return out


## The grid with `rows` empty rows put in at the top.
static func _taller(g: FieldGrid, rows: int, level: int) -> FieldGrid:
	var n := FieldGrid.new(g.width, g.height + rows)
	var empty: int = FieldGrid.Solid.NONE
	if level > 0:
		empty = FieldGrid.Solid.AIR
	elif level < 0:
		empty = FieldGrid.Solid.BLOCK
	var top: int = rows * g.width
	for i in range(top):
		n.solid[i] = empty
		n.floor[i] = FieldGrid.Floor.SNOW
	for i in range(g.width * g.height):
		n.solid[top + i] = g.solid[i]
		n.floor[top + i] = g.floor[i]
		n.building[top + i] = g.building[i]
		n.zone[top + i] = g.zone[i]
	for c: Vector2i in g.doors:
		n.doors[c + Vector2i(0, rows)] = g.doors[c]
	for c: Vector2i in g.windows:
		n.windows[c + Vector2i(0, rows)] = g.windows[c]
	n.refresh_paths()
	return n


## A copy of a value with every place in it moved down.
static func _moved(v, rows: int, key: String):
	if DIRECTIONS.has(key):
		return v
	if v is Vector2i:
		return v + Vector2i(0, rows)
	if v is Rect2i:
		return Rect2i(v.position + Vector2i(0, rows), v.size)
	if v is Vector3:
		return v + Vector3(0, 0, rows)
	if v is Dictionary:
		var out := {}
		for k in v:
			if k is String and (k == "grid" or k == "levels"):
				continue
			out[_moved(k, rows, "") if k is Vector2i else k] = _moved(v[k], rows, k if k is String else key)
		return out
	if v is Array:
		var arr := []
		for item in v:
			arr.append(_moved(item, rows, key))
		return arr
	return v


## Add ground on any side without changing the old cells or their identities.
## A direction stays a direction; dictionary keys and embedded positions move.
## refresh_ground false leaves the ground floor's paths to a caller that builds on it
## and refreshes once after (map_ring.gd, side_path.gd), as the other floors are refreshed here.
static func grow(data: Dictionary, left: int, top: int, right: int, bottom: int, refresh_ground: bool = true, carry_paths: bool = false) -> Dictionary:
	assert(mini(mini(left, top), mini(right, bottom)) >= 0)
	if left + top + right + bottom == 0:
		return data
	var offset := Vector2i(left, top)
	var levels: Dictionary = {}
	var source: Dictionary = data.get("levels", {})
	if source.is_empty():
		source = {0: data["grid"]}
	for lv in source:
		var g: FieldGrid = source[lv]
		var n := FieldGrid.new(g.width + left + right, g.height + top + bottom)
		# Whole rows at a time: a cell-by-cell copy of four floors took over a second on a town map.
		var empty: int = FieldGrid.Solid.AIR if int(lv) > 0 else (FieldGrid.Solid.BLOCK if int(lv) < 0 else FieldGrid.Solid.NONE)
		n.solid = _rows(g.solid, g.width, empty, left, top, right, bottom)
		n.floor = _rows(g.floor, g.width, FieldGrid.Floor.SNOW, left, top, right, bottom)
		n.building = _rows(g.building, g.width, -1, left, top, right, bottom)
		n.zone = _rows(g.zone, g.width, "", left, top, right, bottom)
		n.doors = _offset(g.doors, offset, "")
		n.windows = _offset(g.windows, offset, "")
		n.floor_glass = _offset(g.floor_glass, offset, "")
		# A cell's walk caches read only the cell (its solid, door or window), so when the
		# caller vouches every cell's caches are right (`carry_paths`: a finished map; a map
		# still being built writes solids after a refresh) they move with their cells, the
		# added band taking the empty kind's, and the path grids come from them in a few
		# calls (FieldGrid.adopt_paths).
		if carry_paths and g.paths_ready():
			var band := FieldGrid.new(1, 1)
			band.solid[0] = empty
			band.floor[0] = FieldGrid.Floor.SNOW
			band.refresh_paths()
			n.opq = _rows(g.opq, g.width, band.opq[0], left, top, right, bottom)
			n.walk_people = _rows(g.walk_people, g.width, band.walk_people[0], left, top, right, bottom)
			n.walk_dead = _rows(g.walk_dead, g.width, band.walk_dead[0], left, top, right, bottom)
			if int(lv) != 0 or refresh_ground:
				n.adopt_paths()
		elif int(lv) != 0 or refresh_ground:
			n.refresh_paths()
		n.revision = g.revision
		levels[lv] = n
	var out: Dictionary = _offset(data, offset, "")
	out["levels"] = levels
	out["grid"] = levels[0]
	return out


## A packed per-cell array, `width` cells a row, with `fill` rows and columns added round it.
## Untyped so one function serves the byte, int and string arrays of a grid.
static func _rows(src, width: int, fill, left: int, top: int, right: int, bottom: int):
	var rows: int = src.size() / width
	var out = src.slice(0, 0)
	var side = src.slice(0, 0)
	side.resize(width + left + right)
	side.fill(fill)
	var lpad = side.slice(0, left)
	var rpad = side.slice(0, right)
	for y in range(top):
		out.append_array(side)
	for y in range(rows):
		out.append_array(lpad)
		out.append_array(src.slice(y * width, (y + 1) * width))
		out.append_array(rpad)
	for y in range(bottom):
		out.append_array(side)
	return out


static func _offset(value, offset: Vector2i, key: String):
	if DIRECTIONS.has(key):
		return value.duplicate(true) if value is Dictionary or value is Array else value
	if value is Vector2i:
		return value + offset
	if value is Rect2i:
		return Rect2i(value.position + offset, value.size)
	if value is Vector3:
		return value + Vector3(offset.x, 0, offset.y)
	if value is Dictionary:
		var out := {}
		for k in value:
			if k is String and (k == "grid" or k == "levels"):
				continue
			out[_offset(k, offset, "") if k is Vector2i else k] = _offset(value[k], offset, k if k is String else key)
		return out
	if value is Array:
		var out := []
		for item in value:
			out.append(_offset(item, offset, key))
		return out
	return value
