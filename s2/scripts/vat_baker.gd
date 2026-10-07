extends RefCounted
## Six box parts; subdivision raises vertices to the requested load (0 = 144).
## Two clips x 32 frames, RGBA8 offsets. UV2.x is the texel center in a row,
## UV2.y the folded row block; no skeleton per instance.

const FRAMES: int = 32
const PARTS: int = 6
const MAX_WIDTH: int = 4096
const MAX_SUBDIVIDE: int = 24
const CENTERS: Array[Vector3] = [Vector3(0, 1.1, 0), Vector3(0, 1.65, 0), Vector3(-0.37, 1.08, 0), Vector3(0.37, 1.08, 0), Vector3(-0.16, 0.4, 0), Vector3(0.16, 0.4, 0)]
const SIZES: Array[Vector3] = [Vector3(0.5, 0.65, 0.3), Vector3(0.3, 0.3, 0.3), Vector3(0.16, 0.65, 0.18), Vector3(0.16, 0.65, 0.18), Vector3(0.2, 0.7, 0.24), Vector3(0.2, 0.7, 0.24)]

static func _part_arrays(subdivide: int) -> Array:
	var result: Array = []
	for part in range(PARTS):
		var source := BoxMesh.new()
		source.size = SIZES[part]
		source.subdivide_width = subdivide
		source.subdivide_height = subdivide
		source.subdivide_depth = subdivide
		result.append(source.get_mesh_arrays())
	return result

static func _vertex_count(parts: Array) -> int:
	var total: int = 0
	for arrays in parts:
		total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return total

## target_vertices is a minimum: the smallest subdivision reaching it is used.
static func build(target_vertices: int = 144, max_width: int = MAX_WIDTH) -> Dictionary:
	var subdivide: int = 0
	var parts := _part_arrays(subdivide)
	while _vertex_count(parts) < target_vertices and subdivide < MAX_SUBDIVIDE:
		subdivide += 1
		parts = _part_arrays(subdivide)
	var total := _vertex_count(parts)
	var width := mini(total, max_width)
	var rows_per_frame := ceili(float(total) / width)
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var lookup := PackedVector2Array()
	var indices := PackedInt32Array()
	var part_of := PackedInt32Array()
	for part in range(PARTS):
		var source_arrays: Array = parts[part]
		var source_positions: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = source_arrays[Mesh.ARRAY_NORMAL]
		var source_indices: PackedInt32Array = source_arrays[Mesh.ARRAY_INDEX]
		var base := positions.size()
		for vertex in range(source_positions.size()):
			var id := base + vertex
			positions.append(source_positions[vertex] + CENTERS[part])
			normals.append(source_normals[vertex])
			lookup.append(Vector2((float(id % width) + 0.5) / width, float(id / width)))
			part_of.append(part)
		for index in source_indices:
			indices.append(base + index)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV2] = lookup
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var image := Image.create(width, FRAMES * 2 * rows_per_frame, false, Image.FORMAT_RGBA8)
	for clip in range(2):
		for frame in range(FRAMES):
			var phase := TAU * float(frame) / FRAMES
			var row := (clip * FRAMES + frame) * rows_per_frame
			var swing := sin(phase) * (0.42 if clip == 1 else 0.23)
			var bob := absf(sin(phase)) * 0.035
			# Pivot and rotation depend only on the part, so build six per frame.
			var pivots: Array[Vector3] = []
			var bases: Array[Basis] = []
			for part in range(PARTS):
				var pivot := CENTERS[part]
				var angle: float = 0.0
				if part >= 4:
					pivot.y = 0.77
					angle = swing * (1.0 if part == 4 else -1.0)
				elif part >= 2:
					pivot.y = 1.4
					angle = swing * (-1.0 if part == 2 else 1.0) - (0.4 if clip == 1 else 0.0)
				pivots.append(pivot)
				bases.append(Basis(Vector3.RIGHT, angle))
			for vertex in range(total):
				var part := part_of[vertex]
				var pivot := pivots[part]
				var animated := pivot + bases[part] * (positions[vertex] - pivot)
				animated.y += bob
				var offset := animated - positions[vertex]
				image.set_pixel(vertex % width, row + vertex / width, Color(offset.x + 0.5, offset.y + 0.5, offset.z + 0.5, 1.0))
	var texture := ImageTexture.create_from_image(image)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/zombie_vat.gdshader")
	material.set_shader_parameter("vat", texture)
	material.set_shader_parameter("rows_per_frame", float(rows_per_frame))
	mesh.surface_set_material(0, material)
	return {"mesh": mesh, "texture": texture, "vertices": total, "target": target_vertices, "subdivide": subdivide, "width": width, "rows_per_frame": rows_per_frame, "height": image.get_height(), "image": image}
