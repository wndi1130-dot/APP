extends RefCounted
## Pure, simultaneous horizontal corrections. Callers choose eligible bodies,
## supply their current speeds/floors, then validate each proposed destination.

const SEPARATION_R: float = 0.55
const MAX_STEP_SHARE: float = 0.5
const CELL_SIZE: float = SEPARATION_R


static func pushes(positions: PackedVector3Array, floors: PackedInt32Array,
		ids: PackedInt64Array, speeds: PackedFloat32Array, delta: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	result.resize(positions.size())
	if positions.size() < 2 or delta <= 0.0:
		return result
	var grid: Dictionary = {}
	var cells: Array[Vector3i] = []
	for i in range(positions.size()):
		var at := positions[i]
		var cell := Vector3i(floori(at.x / CELL_SIZE), floors[i], floori(at.z / CELL_SIZE))
		cells.append(cell)
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(i)
	var radius_squared := SEPARATION_R * SEPARATION_R
	for i in range(positions.size()):
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for j in grid.get(cells[i] + Vector3i(dx, 0, dz), []):
					if j <= i:
						continue
					var away := positions[i] - positions[j]
					away.y = 0.0
					var distance_squared := away.length_squared()
					if distance_squared >= radius_squared:
						continue
					var distance := sqrt(distance_squared)
					var direction := away / distance if distance > 0.0 else _apart(ids[i], ids[j])
					var push := direction * ((SEPARATION_R - distance) * 0.5)
					result[i] += push
					result[j] -= push
	# Limit the sum, never each pair separately. No random generator is used.
	for i in range(result.size()):
		result[i] = result[i].limit_length(maxf(0.0, speeds[i]) * delta * MAX_STEP_SHARE)
	return result


## A stable, antisymmetric direction for an exact coincidence, independent of
## list order. Distinct IDs do not move the game's random stream.
static func _apart(a: int, b: int) -> Vector3:
	var salt := (mini(a, b) * 73856093) ^ (maxi(a, b) * 19349663)
	var angle := float(posmod(salt, 4096)) * TAU / 4096.0
	var direction := Vector3(cos(angle), 0, sin(angle))
	return direction if a < b else -direction
