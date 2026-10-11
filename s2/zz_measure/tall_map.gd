extends RefCounted
## Measuring only: hospital_02 pushed down by `extra` rows, the new rows above
## the track filled with a mirror of the town (walls and floors), so the train
## stands in the middle of a taller map with a town's load on both sides.

const FieldGrid = preload("res://game/world/field_grid.gd")
const Base = preload("res://zz_measure/hospital_02.gd")
const PLACE_ID: String = "hospital_98"
const SKIP: Array = ["side", "hole_faces", "facing"]

static var extra: int = 0
## Nearer what will be ordered: open ground above the track with eight houses,
## two dozen trees and forty things lying about, instead of a mirrored town.
static var real: bool = false


static func build() -> Dictionary:
	var d: Dictionary = Base.build()
	if extra <= 0:
		return d
	var levels: Dictionary = {}
	for lv in d["levels"]:
		levels[lv] = _taller(d["levels"][lv], lv == 0)
	var out: Dictionary = _shift(d, "")
	out["levels"] = levels
	out["grid"] = levels[0]
	if real:
		for i in 24:
			out["trees"].append(Vector2i(6 + (i * 37) % (levels[0].width - 12), 2 + (i * 11) % maxi(extra - 8, 1)))
		for i in 40:
			var c := Vector2i(4 + (i * 53) % (levels[0].width - 8), 3 + (i * 7) % maxi(extra - 9, 1))
			if levels[0].solid_at(c) == FieldGrid.Solid.NONE:
				out["low_blocks"].append(Rect2i(c, Vector2i(1, 1)))
	out["train_doors"]["upper"] = []
	for c: Vector2i in out["train_doors"]["lower"]:
		out["train_doors"]["upper"].append(Vector2i(c.x, out["train"].position.y - 1))
	return out


static func _taller(g: FieldGrid, mirror: bool) -> FieldGrid:
	var n := FieldGrid.new(g.width, g.height + extra)
	for y in range(n.height):
		var from: int = y - extra
		var copy := true
		if from < 0:
			from = clampi(g.height - 1 - y, 4, g.height - 1)
			copy = mirror and not real
			if real and mirror:
				for x in range(g.width):
					n.solid[n.index(Vector2i(x, y))] = FieldGrid.Solid.NONE
					n.floor[n.index(Vector2i(x, y))] = FieldGrid.Floor.SNOW
				continue
		for x in range(g.width):
			var a := n.index(Vector2i(x, y))
			var b := g.index(Vector2i(x, from))
			if copy:
				n.floor[a] = g.floor[b]
				n.solid[a] = g.solid[b]
				if y < extra and (g.solid[b] == FieldGrid.Solid.DOOR or g.solid[b] == FieldGrid.Solid.WINDOW):
					n.solid[a] = FieldGrid.Solid.WALL
				if y >= extra:
					n.building[a] = g.building[b]
					n.zone[a] = g.zone[b]
			else:
				n.solid[a] = g.solid[g.index(Vector2i(0, 0))]
	for c: Vector2i in g.doors:
		n.doors[c + Vector2i(0, extra)] = g.doors[c]
	for c: Vector2i in g.windows:
		n.windows[c + Vector2i(0, extra)] = g.windows[c]
	if real and mirror:
		for i in 8:
			var at := Vector2i(8 + i * 21, 6 if i % 2 == 0 else maxi(extra - 22, 6))
			for dy in 7:
				for dx in 10:
					var edge: bool = dx == 0 or dy == 0 or dx == 9 or dy == 6
					var c := at + Vector2i(dx, dy)
					if edge and not (dy == 6 and dx == 4) and c.y < extra - 4 and n.inside(c):
						n.solid[n.index(c)] = FieldGrid.Solid.WALL
	# Keep the three rows above the train and the train's ends walkable.
	n.refresh_paths()
	for y in range(n.height):
		for x in range(n.width):
			n.set_solid(Vector2i(x, y), n.solid[n.index(Vector2i(x, y))])
	n.refresh_paths()
	return n


static func _shift(v, key: String):
	if SKIP.has(key):
		return v
	if v is Vector2i:
		return v + Vector2i(0, extra)
	if v is Rect2i:
		return Rect2i(v.position + Vector2i(0, extra), v.size)
	if v is Dictionary:
		var out := {}
		for k in v:
			if k == "grid" or k == "levels":
				continue
			out[_shift(k, "") if k is Vector2i else k] = _shift(v[k], String(k) if k is String else "")
		return out
	if v is Array:
		var arr := []
		for item in v:
			arr.append(_shift(item, key))
		return arr
	return v
