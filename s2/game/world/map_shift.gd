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
