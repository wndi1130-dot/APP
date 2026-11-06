extends RefCounted
## Pure metre/second decisions for opening a door while following a route.
## A door's near cell edge, not its centre, is the physical threshold.

const FieldGrid = preload("res://game/world/field_grid.gd")
const CLEARANCE: float = 0.0001
const CLOCK_EPS: float = 0.000000001 # Roundoff only; not a gameplay time allowance.


static func should_start(distance: float, speed: float, seconds: float) -> bool:
	return is_finite(distance) and is_finite(speed) and is_finite(seconds) \
		and distance >= 0.0 and speed > 0.0 and seconds >= 0.0 \
		and distance <= speed * seconds


static func before_threshold(distance: float, threshold: float) -> float:
	return minf(maxf(0.0, distance), maxf(0.0, threshold - CLEARANCE))


static func finishes(remaining: float, elapsed: float, rate: float) -> bool:
	if not is_finite(remaining) or not is_finite(elapsed) or not is_finite(rate):
		return false
	if elapsed < 0.0 or rate <= 0.0:
		return false
	if elapsed == 0.0:
		return remaining <= 0.0
	return remaining <= elapsed * rate + CLOCK_EPS


## Return the first shut cell reached along the actual polyline, within limit.
## Only supplied door cells are visited; sparse/long steps cannot skip doors
## or turn a slow hand multiplier into an enormous rectangular grid scan.
## Stop at stairs: these doors belong to this floor only.
static func first_door(at: Vector3, path: PackedVector3Array, doors: Dictionary,
		limit: float) -> Dictionary:
	if not at.is_finite() or not is_finite(limit) or limit <= 0.0:
		return {}
	var from := at
	var travelled := 0.0
	for point: Vector3 in path:
		if not point.is_finite() or absf(point.y - from.y) > 0.001:
			break
		var step := point - from
		step.y = 0.0
		var length: float = step.length()
		if length <= 0.0:
			continue
		var span: float = minf(length, limit - travelled)
		if span <= 0.0:
			break
		var end: Vector3 = from + step * (span / length)
		var nearest: float = INF
		var found := Vector2i.ZERO
		for cell: Vector2i in doors:
			if String(doors[cell].get("state", "")) not in ["closed", "locked"]:
				continue
			# An actor already inside a shut cell may leave it (legacy saves).
			if travelled == 0.0 and cell == FieldGrid.cell_of(at):
				continue
			var entry: float = _entry_distance(from, end, cell)
			if entry < nearest:
				nearest = entry
				found = cell
		if nearest < INF:
			return {"cell": found, "distance": travelled + nearest}
		travelled += length
		if travelled >= limit:
			break
		from = point
	return {}


## Slab intersection against the unit cell, including a step ending at its edge.
static func _entry_distance(from: Vector3, to: Vector3, cell: Vector2i) -> float:
	var start := Vector2(from.x, from.z)
	var step := Vector2(to.x - from.x, to.z - from.z)
	var low := Vector2(cell)
	var enter := 0.0
	var leave := 1.0
	for axis: int in 2:
		if step[axis] == 0.0:
			if start[axis] < low[axis] or start[axis] >= low[axis] + 1.0:
				return INF
		else:
			var a: float = (low[axis] - start[axis]) / step[axis]
			var b: float = (low[axis] + 1.0 - start[axis]) / step[axis]
			enter = maxf(enter, minf(a, b))
			leave = minf(leave, maxf(a, b))
			if enter > leave or leave <= 0.0:
				return INF
	return enter * step.length()
