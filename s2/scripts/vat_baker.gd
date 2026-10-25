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

## A skinned body instead of the six boxes: any surface with bone weights, any
## number of clips, each with its own frame count. `source` is one surface's
## arrays. `clips` is [{"name", "loop", "length", "frames"}]; a frame is one
## Transform3D per bone (pose * inverse bind, mesh space). Clips stack downward
## in the order given, so "start" is a clip's first frame row. Offsets are
## metres in half floats: a fall moves a vertex well past the +-0.5 of RGBA8.
## Vertices at the same place with the same bones and weights (a body's are
## split at the colour picture's seams) move alike, so they share one column
## of the picture: "vertices" is the mesh's count, "columns" the picture's.
static func build_skinned(source: Array, clips: Array, max_width: int = MAX_WIDTH) -> Dictionary:
	var positions: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var bones = source[Mesh.ARRAY_BONES]
	var weights = source[Mesh.ARRAY_WEIGHTS]
	var total := positions.size()
	var per: int = bones.size() / total
	var column := PackedInt32Array()
	var held := PackedInt32Array()  # the vertex each column is worked out from
	var seen := {}
	for id in range(total):
		var key := [positions[id], bones.slice(id * per, id * per + per), weights.slice(id * per, id * per + per)]
		if not seen.has(key):
			seen[key] = held.size()
			held.append(id)
		column.append(int(seen[key]))
	var count := held.size()
	var width := mini(count, max_width)
	var rows_per_frame := ceili(float(count) / width)
	var lookup := PackedVector2Array()
	for id in range(total):
		lookup.append(Vector2((float(column[id] % width) + 0.5) / width, float(column[id] / width)))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_COLOR, Mesh.ARRAY_INDEX]:
		arrays[slot] = source[slot]
	arrays[Mesh.ARRAY_TEX_UV2] = lookup
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var frame_total: int = 0
	for clip in clips:
		frame_total += (clip["frames"] as Array).size()
	var image := Image.create(width, frame_total * rows_per_frame, false, Image.FORMAT_RGBH)
	var table: Array = []
	var start: int = 0
	for clip in clips:
		var frames: Array = clip["frames"]
		for frame in range(frames.size()):
			var skin: Array = frames[frame]
			var row := (start + frame) * rows_per_frame
			for at in range(count):
				var vertex := held[at]
				var rest := positions[vertex]
				var moved := Vector3.ZERO
				var weight_sum: float = 0.0
				for slot in range(per):
					var weight: float = weights[vertex * per + slot]
					if weight > 0.0:
						var bone: Transform3D = skin[bones[vertex * per + slot]]
						moved += (bone * rest) * weight
						weight_sum += weight
				# A vertex no bone holds stays where it rests.
				var offset := moved / weight_sum - rest if weight_sum > 0.0 else Vector3.ZERO
				image.set_pixel(at % width, row + at / width, Color(offset.x, offset.y, offset.z, 1.0))
		table.append({"name": clip.get("name", ""), "start": start, "frames": frames.size(), "loop": bool(clip.get("loop", true)), "length": float(clip.get("length", 1.0))})
		start += frames.size()
	return {"mesh": mesh, "texture": ImageTexture.create_from_image(image), "vertices": total, "columns": count, "width": width, "rows_per_frame": rows_per_frame, "height": image.get_height(), "image": image, "clips": table}

const TABLE_SIZE: int = 128
## Clips 16 and up go in the shader's upper part, sixteen to each step of
## UPPER (dead_vat.gdshader): 16..31 one step, 32..47 two, and so on to
## 112..127 seven. With a frame under 4096 and a share of 0..SHARE_MAX that is
## at most 2^24 - 1, which a float carries whole: 128 clips is as far as this
## packing goes. (Up to 2026-10-24 a share went to 63 and UPPER was twice
## this, which held 64 clips; the clip numbers are the same either way.)
const UPPER: float = 2097152.0
const SHARE_MAX: int = 31

## INSTANCE_CUSTOM.g for dead_vat.gdshader: the clip, and while a body changes
## motion the frame row it was in and how much of that it keeps (share 0..SHARE_MAX).
## Below sixteen it is the same number as clip + 16 * frame + 65536 * share.
static func pack_motion(clip: int, frame: int = 0, share: int = 0) -> float:
	return float(clip % 16) + 16.0 * float(frame) + 65536.0 * float(share) + UPPER * floorf(clip / 16.0)


## The clip table of a skinned bake as the shader parameters of
## game/actors/dead_vat.gdshader: where each clip starts, its frame count, its
## frames per second and whether it loops, padded to the shader's TABLE_SIZE slots.
static func shader_tables(assets: Dictionary) -> Dictionary:
	var starts := PackedFloat32Array()
	var counts := PackedFloat32Array()
	var rates := PackedFloat32Array()
	var loops := PackedFloat32Array()
	for clip in assets["clips"]:
		starts.append(float(clip["start"]))
		counts.append(float(clip["frames"]))
		rates.append(float(clip["frames"]) / maxf(float(clip["length"]), 0.001))
		loops.append(1.0 if clip["loop"] else 0.0)
	for table in [starts, counts, rates, loops]:
		table.resize(TABLE_SIZE)
	# A compacted bake (body_bake.gd compact) keeps each clip in 8 bits inside its own box.
	var lows := PackedVector3Array()
	var highs := PackedVector3Array()
	for clip in assets["clips"]:
		var lo: Array = clip.get("lo", [0.0, 0.0, 0.0])
		var hi: Array = clip.get("hi", [1.0, 1.0, 1.0])
		lows.append(Vector3(lo[0], lo[1], lo[2]))
		highs.append(Vector3(hi[0], hi[1], hi[2]))
	lows.resize(TABLE_SIZE)
	highs.resize(TABLE_SIZE)
	var out := {"clip_start": starts, "clip_frames": counts, "clip_rate": rates, "clip_loop": loops, "frame_rows": float(assets["height"]) / float(assets["rows_per_frame"]), "rows_per_frame": float(assets["rows_per_frame"]), "bias": 0.0,
		"quantized": str(assets.get("format", "")) == "rgb8q", "clip_lo": lows, "clip_hi": highs, "has_albedo": assets.get("albedo") is Texture2D}
	# A body that brings its colour picture (dead_body.gd with_albedo) is drawn with it.
	if out["has_albedo"]:
		out["albedo_tex"] = assets["albedo"]
	return out
