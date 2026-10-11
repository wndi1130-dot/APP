extends RefCounted
## The first stop pushed down 45 rows, with doors and a way in added on the
## new ground above the train: how a map with the track along its top edge
## becomes a map with ground on both sides.

const FieldGrid = preload("res://game/world/field_grid.gd")
const MapShift = preload("res://game/world/map_shift.gd")
const Sulehuf = preload("res://game/world/sulehuf_map.gd")

const PLACE_ID: String = "freight_98"
const ROWS: int = 45


static func build() -> Dictionary:
	var d: Dictionary = MapShift.shift_rows(Sulehuf.build(), ROWS)
	var g: FieldGrid = d["grid"]
	var train: Rect2i = d["train"]
	var upper: Array = []
	for c: Vector2i in d["spawns"]["train_door"]:
		upper.append(Vector2i(c.x, train.position.y - 1))
	d["train_doors"] = {"lower": d["spawns"]["train_door"].duplicate(), "upper": upper}
	d["entries"]["upper_field"] = [Vector2i(60, 0), Vector2i(61, 0)]
	d["entry_gap"]["upper_field"] = 0.6
	# The old top edge (the row above the track) was the map's rim; it is ground now.
	for x in range(g.width):
		g.set_solid(Vector2i(x, ROWS), FieldGrid.Solid.NONE)
	for lv in d["levels"]:
		d["levels"][lv].refresh_paths()
	return d
