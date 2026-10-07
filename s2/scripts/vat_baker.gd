extends RefCounted
## Six box parts, 144 vertices. Two clips x 32 frames, RGBA8 offsets.
## UV2.x stores the texel center for each vertex; no skeleton per instance.

const FRAMES: int = 32
const PARTS: int = 6
const VERTICES: int = PARTS * 24

static func build() -> Dictionary:
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var lookup := PackedVector2Array()
	var indices := PackedInt32Array()
	var centers: Array[Vector3] = [Vector3(0, 1.1, 0), Vector3(0, 1.65, 0), Vector3(-0.37, 1.08, 0), Vector3(0.37, 1.08, 0), Vector3(-0.16, 0.4, 0), Vector3(0.16, 0.4, 0)]
	var sizes: Array[Vector3] = [Vector3(0.5, 0.65, 0.3), Vector3(0.3, 0.3, 0.3), Vector3(0.16, 0.65, 0.18), Vector3(0.16, 0.65, 0.18), Vector3(0.2, 0.7, 0.24), Vector3(0.2, 0.7, 0.24)]
	for part in range(PARTS):
		var source := BoxMesh.new()
		source.size = sizes[part]
		var source_arrays := source.get_mesh_arrays()
		var source_positions: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = source_arrays[Mesh.ARRAY_NORMAL]
		var source_indices: PackedInt32Array = source_arrays[Mesh.ARRAY_INDEX]
		var base := positions.size()
		for vertex in range(source_positions.size()):
			positions.append(source_positions[vertex] + centers[part])
			normals.append(source_normals[vertex])
			lookup.append(Vector2((float(base + vertex) + 0.5) / VERTICES, 0))
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
	var image := Image.create(VERTICES, FRAMES * 2, false, Image.FORMAT_RGBA8)
	for clip in range(2):
		for frame in range(FRAMES):
			var phase := TAU * float(frame) / FRAMES
			for vertex in range(positions.size()):
				var part := vertex / 24
				var pivot := centers[part]
				var angle: float = 0.0
				var swing := sin(phase) * (0.42 if clip == 1 else 0.23)
				if part >= 4:
					pivot.y = 0.77
					angle = swing * (1.0 if part == 4 else -1.0)
				elif part >= 2:
					pivot.y = 1.4
					angle = swing * (-1.0 if part == 2 else 1.0) - (0.4 if clip == 1 else 0.0)
				var animated := pivot + Basis(Vector3.RIGHT, angle) * (positions[vertex] - pivot)
				animated.y += absf(sin(phase)) * 0.035
				var offset := animated - positions[vertex]
				image.set_pixel(vertex, clip * FRAMES + frame, Color(offset.x + 0.5, offset.y + 0.5, offset.z + 0.5, 1.0))
	var texture := ImageTexture.create_from_image(image)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/zombie_vat.gdshader")
	material.set_shader_parameter("vat", texture)
	mesh.surface_set_material(0, material)
	return {"mesh": mesh, "texture": texture, "vertices": positions.size()}
