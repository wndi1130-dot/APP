extends RefCounted

static func contains(point: Vector2, origin: Vector2, radius: float) -> bool:
	return radius >= 0.0 and point.distance_squared_to(origin) <= radius * radius

static func affected(points: PackedVector2Array, origin: Vector2, radius: float) -> PackedInt32Array:
	var result := PackedInt32Array()
	for index in range(points.size()):
		if contains(points[index], origin, radius):
			result.append(index)
	return result
