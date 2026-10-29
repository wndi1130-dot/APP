extends RefCounted
## Submit adjacent, untextured UI triangles together without resampling them.
## The feather, capped joins and circle tessellation follow Godot 4.7's
## renderer_canvas_cull.cpp. Keep each original shape's triangle order: translucent
## shadows and crossing cracks must still composite in that order.
## No viewport, material, low-resolution image or animated-value texture cache.
## Geometry reference (including FEATHER_SIZE and open/closed strip caps):
## https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_canvas_cull.cpp

const FEATHER: float = 1.25
static var _medals: Dictionary = {}


class Batch:

	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()


	func append(vertices: PackedVector2Array, ink: PackedColorArray, triangles: PackedInt32Array) -> void:
		var base: int = points.size()
		points.append_array(vertices)
		if ink.size() == 1:
			for _i in vertices.size():
				colors.append(ink[0])
		else:
			colors.append_array(ink)
		for index in triangles:
			indices.append(base + index)


	func polygon(vertices: PackedVector2Array, ink: PackedColorArray) -> void:
		# The very same triangulator used by CanvasItem.draw_polygon.
		append(vertices, ink, Geometry2D.triangulate_polygon(vertices))


	func rect(box: Rect2, color: Color) -> void:
		append(PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]),
			PackedColorArray([color]), PackedInt32Array([0, 1, 2, 0, 2, 3]))


	func strip(vertices: PackedVector2Array, ink: PackedColorArray) -> void:
		var triangles := PackedInt32Array()
		for i in range(2, vertices.size()):
			triangles.append_array(PackedInt32Array([i - 2, i - 1, i] if i % 2 == 0 else [i - 1, i - 2, i]))
		append(vertices, ink, triangles)


	func draw(ci: CanvasItem) -> void:
		if not indices.is_empty():
			RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, points, colors)


	func circle(center: Vector2, radius: float, color: Color) -> void:
		var r: float = maxf(0.0, radius - FEATHER * 0.25)
		var border: float = FEATHER * (r if r * 2.0 < 1.0 else 1.0)
		var body := PackedVector2Array()
		var tris := PackedInt32Array()
		var edge := PackedVector2Array()
		var ink := PackedColorArray()
		for i in 65:
			var a: float = TAU * float(i) / 64.0
			var ray := Vector2(cos(a), sin(a))
			body.append(center + ray * r)
			edge.append(center + ray * r)
			edge.append(center + ray * (r + border))
			ink.append(color)
			ink.append(Color(color, 0.0))
			if i < 64:
				tris.append_array(PackedInt32Array([65, i, i + 1]))
		body.append(center)
		append(body, PackedColorArray([color]), tris)
		strip(edge, ink)


	func arc(center: Vector2, radius: float, start: float, end: float, count: int, color: Color, width: float) -> void:
		var path := PackedVector2Array()
		for i in count:
			var a: float = lerpf(start, end, float(i) / float(count - 1))
			path.append(center + Vector2(cos(a), sin(a)) * radius)
		polyline(path, PackedColorArray([color]), width)


	static func _width(width: float) -> float:
		if width <= FEATHER * 2.0 + 0.00001:
			return width * 0.5
		if width <= FEATHER * 4.0 + 0.00001:
			return remap(width, FEATHER * 2.0, FEATHER * 4.0, width * 0.5, width - FEATHER * 0.5)
		return width - FEATHER * 0.5


	static func _edge(direction: Vector2, previous: Vector2) -> Vector2:
		var bisector: Vector2 = (previous * direction.length() - direction * previous.length()).normalized()
		var sine: float = sin(atan2(bisector.cross(previous), bisector.dot(previous)))
		var reach: float = 1.0
		if not is_zero_approx(sine) and not direction.is_equal_approx(previous):
			reach = clampf(1.0 / sine, -3.0, 3.0)
		else:
			bisector = direction.orthogonal()
		if bisector.is_zero_approx():
			bisector = direction.orthogonal()
		return bisector * reach


	func polyline(path: PackedVector2Array, ink: PackedColorArray, width: float) -> void:
		if path.size() < 2:
			return
		var count: int = path.size()
		var loop: bool = path[0].is_equal_approx(path[count - 1])
		var first := Vector2.ZERO
		var last := Vector2.ZERO
		for i in range(1, count):
			first = (path[i] - path[i - 1]).normalized()
			if not first.is_zero_approx():
				break
		for i in range(count - 1, 0, -1):
			last = (path[i] - path[i - 1]).normalized()
			if not last.is_zero_approx():
				break
		var half: float = _width(width) * 0.5
		var feather: float = FEATHER * minf(1.0, half * 2.0)
		var mid := PackedVector2Array()
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var solid := PackedColorArray()
		var fade := PackedColorArray()
		mid.resize(count * 2 + (0 if loop else 4))
		left.resize(count * 2 + (0 if loop else 5))
		right.resize(left.size())
		solid.resize(mid.size())
		fade.resize(left.size())
		var previous := Vector2.ZERO
		var color := Color.WHITE
		for i in count:
			var direction: Vector2 = previous if i == count - 1 else (path[i + 1] - path[i]).normalized()
			if direction.is_zero_approx():
				direction = previous
			if loop and i == 0:
				previous = last
			elif loop and i == count - 1:
				previous = first
			var edge: Vector2 = _edge(direction, previous)
			if not loop and i == 0:
				edge = first.orthogonal()
			elif not loop and i == count - 1:
				edge = last.orthogonal()
			var offset: Vector2 = edge * half
			var border: Vector2 = edge * feather
			var pos: Vector2 = path[i]
			var j: int = i * 2 + (0 if loop else 2)
			mid[j] = pos + offset
			mid[j + 1] = pos - offset
			left[j] = pos + offset
			left[j + 1] = pos + offset + border
			right[j] = pos - offset
			right[j + 1] = pos - offset - border
			if i < ink.size():
				color = ink[i]
			var clear := Color(color, 0.0)
			solid[j] = color
			solid[j + 1] = color
			fade[j] = color
			fade[j + 1] = clear
			if not loop and i == 0:
				var cap: Vector2 = -direction * feather
				mid[0] = pos + offset + cap
				mid[1] = pos - offset + cap
				left[0] = pos + offset + cap
				left[1] = pos + offset + cap + border
				right[0] = pos - offset + cap
				right[1] = pos - offset + cap - border
				solid[0] = clear
				solid[1] = clear
				fade[0] = clear
				fade[1] = clear
			if not loop and i == count - 1:
				var cap: Vector2 = previous * feather
				var end_at: int = count * 2 + 2
				mid[end_at] = pos + offset + cap
				mid[end_at + 1] = pos - offset + cap
				solid[end_at] = clear
				solid[end_at + 1] = clear
				# Repeated corner keeps the original end-cap diagonal.
				left[end_at] = pos + offset
				left[end_at + 1] = pos + offset + cap + border
				left[end_at + 2] = pos + offset + cap
				right[end_at] = pos - offset
				right[end_at + 1] = pos - offset + cap - border
				right[end_at + 2] = pos - offset + cap
				fade[end_at] = color
				fade[end_at + 1] = clear
				fade[end_at + 2] = clear
			previous = direction
		strip(mid, solid)
		strip(left, fade)
		strip(right, fade)


## Only the static geometry's size, dim state and actual colours identify it.
## Float serialization avoids rounded keys aliasing two different pixel sizes.
static func medal_key(size: Vector2, radius: float, scale_px: float, dim: bool, ink: PackedColorArray) -> String:
	return var_to_bytes([size, radius, scale_px, dim, ink]).hex_encode()


static func medal(size: Vector2, radius: float, scale_px: float, dim: bool, ink: PackedColorArray) -> Batch:
	var key: String = medal_key(size, radius, scale_px, dim, ink)
	if _medals.has(key):
		return _medals[key] as Batch
	var batch := Batch.new()
	var center: Vector2 = size * 0.5
	for i in 3:
		batch.circle(center + Vector2(0, scale_px), radius + float(3 - i) * scale_px, ink[i])
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 48:
		var a: float = TAU * float(i) / 48.0
		var p: Vector2 = center + Vector2(cos(a), sin(a)) * radius
		pts.append(p)
		cols.append(ink[3].lerp(ink[4], (p.y - (center.y - radius)) / (radius * 2.0)))
	batch.polygon(pts, cols)
	batch.arc(center, radius - scale_px, 0.0, TAU, 64, ink[5], 2.0 * scale_px)
	_medals[key] = batch
	return batch
