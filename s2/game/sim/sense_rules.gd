extends RefCounted
## Perception weights and a local-neighbour snapshot; no simulation random draws.

const STILL_MULT: float = 0.8
const WALK_MULT: float = 1.0
const RUN_MULT: float = 1.5
const CROUCH_MULT: float = 0.55
const TICK_MIN: float = 0.15
const TICK_JITTER: float = 0.05


static func posture_mult(crouched: bool, moving: bool, running: bool) -> float:
	if crouched:
		return CROUCH_MULT
	if not moving:
		return STILL_MULT
	return RUN_MULT if running else WALK_MULT


## Same floor-aware cell key as the body's separation grid. The separation
## grid is private to its correction pass; this snapshot serves sight calls.
static func cell(at: Vector3, floor_id: int, width: float) -> Vector3i:
	return Vector3i(floori(at.x / width), floor_id, floori(at.z / width))


static func index(bodies: Array, floor_of: Callable, width: float) -> Dictionary:
	var cells: Dictionary = {}
	for body in bodies:
		if body["state"] == "dead":
			continue
		var key := cell(body["pos"], int(floor_of.call(body["pos"])), width)
		if not cells.has(key):
			cells[key] = []
		cells[key].append(body)
	return cells


## Radius can include this tick's maximum movement, so bodies crossing a cell
## edge after the snapshot remain candidates. The caller checks exact distance.
static func neighbours(cells: Dictionary, at: Vector3, floor_id: int,
		width: float, radius: float) -> Array:
	var out: Array = []
	var low := cell(at - Vector3(radius, 0, radius), floor_id, width)
	var high := cell(at + Vector3(radius, 0, radius), floor_id, width)
	for x in range(low.x, high.x + 1):
		for z in range(low.z, high.z + 1):
			out.append_array(cells.get(Vector3i(x, floor_id, z), []))
	return out
