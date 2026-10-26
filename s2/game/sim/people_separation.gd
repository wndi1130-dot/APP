extends RefCounted
## The living keep out of each other's bodies (decision 442: the motion card's
## recommendation on people standing in each other). Two closer than
## SEPARATION_R are eased apart as the dead are (dead_separation.gd): pure and
## simultaneous, the summed push held to a share of the body's own pace. A fixed
## body is never moved and the other takes the whole gap; two fixed ones are left
## as they are. Callers choose who takes part and who is fixed (field_game.gd:
## those standing still; the player, a worker, a carrier and a fighter fixed) and
## check every destination.

const SEPARATION_R: float = 0.6
const MAX_STEP_SHARE: float = 0.5
const CELL_SIZE: float = SEPARATION_R


static func pushes(positions: PackedVector3Array, floors: PackedInt32Array, ids: PackedInt64Array,
		speeds: PackedFloat32Array, fixed: PackedByteArray, delta: float) -> PackedVector3Array:
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
					if j <= i or (fixed[i] and fixed[j]):
						continue
					var away := positions[i] - positions[j]
					away.y = 0.0
					var distance_squared := away.length_squared()
					if distance_squared >= radius_squared:
						continue
					var distance := sqrt(distance_squared)
					var direction := away / distance if distance > 0.0 else _apart(ids[i], ids[j])
					var gap := SEPARATION_R - distance
					if fixed[j]:
						result[i] += direction * gap
					elif fixed[i]:
						result[j] -= direction * gap
					else:
						result[i] += direction * (gap * 0.5)
						result[j] -= direction * (gap * 0.5)
	# Limit the sum, never each pair separately. No random generator is used.
	for i in range(result.size()):
		if fixed[i]:
			result[i] = Vector3.ZERO
		else:
			result[i] = result[i].limit_length(maxf(0.0, speeds[i]) * delta * MAX_STEP_SHARE)
	return result


## A stable, antisymmetric direction for an exact coincidence, independent of
## list order (as dead_separation.gd has it).
static func _apart(a: int, b: int) -> Vector3:
	var salt := (mini(a, b) * 73856093) ^ (maxi(a, b) * 19349663)
	var angle := float(posmod(salt, 4096)) * TAU / 4096.0
	var direction := Vector3(cos(angle), 0, sin(angle))
	return direction if a < b else -direction
