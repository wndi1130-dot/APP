extends SceneTree
## Headless ground templates, in metres, sharing the icon builders and sources.
## godot --headless --path s2 -s res://tools/ground_bake.gd -- <out_dir> <list_file> [<list_file> ...]
## Glass keeps its sRGB colour but is OPAQUE on the ground: the whole floor is
## one opaque world_vis surface. Vertex alpha is always 0 (no snow/rain on it).
## Albedo/texture/vertex RGB stay sRGB; world_vis.floor_to_linear does the only
## conversion. Icon camera angles and margins never change ground geometry.

const Models = preload("res://game/world/ground_models.gd")
const MAX_VERTICES: int = 800
## Below about one pixel at zoom 18. Test the longest WORLD-space extent after
## all parent transforms; exactly 0.02 m stays, and hidden parts are not counted.
const MIN_PART_EXTENT: float = 0.02
const LOD_MERGE_ANGLE: float = 60.0
const LOD_SPLIT_ANGLE: float = 25.0
## When no LOD stage fits: grid clustering (cluster_to_limit), recorded as this
## stage. It starts at 1/CLUSTER_DIVISIONS of the longest side (a 0.2 m pistol:
## 1.6 mm) and grows the cell CLUSTER_GROWTH-fold a try, CLUSTER_TRIES at most
## (to about 2/5 of the side at the last, far coarser than the few pixels the
## thing is drawn in — a mesh still over then fails).
const CLUSTERED_LOD: int = -1
const CLUSTER_DIVISIONS: float = 128.0
const CLUSTER_GROWTH: float = 1.3
const CLUSTER_TRIES: int = 16
const RECORD: String = "ground_baked.txt"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("GROUND_BAKE_FAIL usage: -- <out_dir> <list_file> [<list_file> ...]")
		quit(1)
		return
	var out_dir: String = ProjectSettings.globalize_path(args[0])
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(out_dir)
	if directory_error != OK:
		printerr("GROUND_BAKE_FAIL output: " + error_string(directory_error))
		quit(1)
		return
	var entries: Array[Dictionary] = []
	var failures: Array[String] = []
	var names: Dictionary = {}
	for list_index: int in range(1, args.size()):
		var file := FileAccess.open(args[list_index], FileAccess.READ)
		if file == null:
			failures.append("list %s: %s" % [args[list_index], error_string(FileAccess.get_open_error())])
			continue
		var line_number: int = 0
		var entry_start: int = entries.size()
		while file.get_position() < file.get_length():
			line_number += 1
			var entry: Dictionary = parse_line(file.get_line(), line_number)
			var read_error: Error = file.get_error()
			if read_error != OK and read_error != ERR_FILE_EOF:
				failures.append("list %s: %s" % [args[list_index], error_string(read_error)])
				break
			if entry.is_empty():
				continue
			entries.append(entry)
			if entry.has("error"):
				continue
			var item_name: String = entry["name"]
			var name_key: String = item_name.to_lower()
			if names.has(name_key):
				entry["error"] = "duplicate name across lists"
				continue
			names[name_key] = true
			if Models.box_only(item_name):
				entry["skipped"] = "BOX_ONLY"
				continue
			var baked: Dictionary = bake_source(item_name, entry["path"])
			entry["dropped"] = int(baked.get("dropped", 0))
			if baked.has("error"):
				entry["error"] = baked["error"]
				continue
			var mesh: ArrayMesh = baked["mesh"]
			var target: String = out_dir.path_join(item_name + ".res")
			var temporary: String = out_dir.path_join("%s.%d.tmp.res" % [item_name, OS.get_process_id()])
			var save_error: Error = ResourceSaver.save(mesh, temporary)
			if save_error == OK:
				save_error = DirAccess.rename_absolute(temporary, target)
			if save_error != OK:
				entry["error"] = "save: " + error_string(save_error)
				continue
			entry.merge({"saved": true, "vertices": baked["vertices"], "triangles": baked["triangles"], "size": baked["size"],
				"lod": baked["lod"], "reduced": baked["reduced"], "cluster": baked["cluster"]})
		file.close()
		if entries.size() == entry_start:
			failures.append("list %s: no entries" % args[list_index])
	clear_stale(out_dir, entries)
	var record_error: Error = write_record(out_dir.path_join(RECORD), record_lines(entries, failures))
	if record_error != OK:
		failures.append("record: " + error_string(record_error))
	for line: String in record_lines(entries, failures):
		print(line)
	var code: int = exit_code(entries, failures)
	print("GROUND_BAKE_DONE entries=%d exit=%d" % [entries.size(), code])
	quit(code)


static func parse_line(text: String, line_number: int = 0) -> Dictionary:
	var line: String = text.trim_prefix("\ufeff").strip_edges()
	if line.is_empty() or line.begins_with("#"):
		return {}
	var entry: Dictionary = {"name": "line_%d" % line_number, "line": line_number}
	var first: String = line.replace("\t", " ").split(" ", false)[0]
	if Models.valid_name(first):
		entry["name"] = first
		entry["output_name"] = first
	var pattern := RegEx.new()
	var compiled: Error = pattern.compile("^(\\S+)\\s+(res://.+?\\.(?:glb|gltf|obj|tscn|scn|res|tres|gd))(?:\\s+(\\S+))?(?:\\s+(\\S+))?(?:\\s+(\\S+))?(?:\\s+(\\S+))?$")
	if compiled != OK:
		entry["error"] = "list pattern: " + error_string(compiled)
		return entry
	var matched: RegExMatch = pattern.search(line)
	if matched == null:
		entry["error"] = "expected: <name> <res://source> [yaw pitch roll margin]"
		return entry
	var item_name: String = matched.get_string(1)
	if not Models.valid_name(item_name):
		entry["error"] = "unsafe output name"
		return entry
	entry["name"] = item_name
	entry["path"] = matched.get_string(2)
	for group: int in range(3, 7):
		var number: String = matched.get_string(group)
		if not number.is_empty() and (not number.is_valid_float() or not is_finite(number.to_float())):
			entry["error"] = "invalid icon pose or margin"
			return entry
	return entry


static func low_poly(original: Mesh) -> Mesh:
	if not original is PrimitiveMesh:
		return original
	var copy := original.duplicate() as PrimitiveMesh
	if copy is CylinderMesh:
		var cylinder := copy as CylinderMesh
		cylinder.radial_segments = mini(cylinder.radial_segments, 8)
		cylinder.rings = mini(cylinder.rings, 1)
	elif copy is SphereMesh:
		var sphere := copy as SphereMesh
		sphere.radial_segments = mini(sphere.radial_segments, 8)
		sphere.rings = mini(sphere.rings, 4)
	elif copy is TorusMesh:
		var torus := copy as TorusMesh
		torus.rings = mini(torus.rings, 8)
		torus.ring_segments = mini(torus.ring_segments, 4)
	elif copy is CapsuleMesh:
		var capsule := copy as CapsuleMesh
		capsule.radial_segments = mini(capsule.radial_segments, 8)
		capsule.rings = mini(capsule.rings, 2)
	elif copy is BoxMesh:
		var box := copy as BoxMesh
		box.subdivide_width = 0
		box.subdivide_height = 0
		box.subdivide_depth = 0
	elif copy is PlaneMesh:
		var plane := copy as PlaneMesh
		plane.subdivide_width = 0
		plane.subdivide_depth = 0
	elif copy is PrismMesh:
		var prism := copy as PrismMesh
		prism.subdivide_width = 0
		prism.subdivide_height = 0
		prism.subdivide_depth = 0
	return copy


static func vertex_colour(albedo: Color, texel: Color, vertex: Color, use_vertex: bool) -> Color:
	var color: Color = albedo * texel
	if use_vertex:
		color *= vertex
	color.a = 0.0
	return color


static func sample_nearest(image: Image, uv: Vector2) -> Color:
	if image == null or image.is_empty():
		return Color.WHITE
	var x: int = clampi(floori(uv.x * float(image.get_width())), 0, image.get_width() - 1)
	var y: int = clampi(floori(uv.y * float(image.get_height())), 0, image.get_height() - 1)
	return image.get_pixel(x, y)


static func centered(vertices: PackedVector3Array) -> Dictionary:
	if vertices.is_empty():
		return {"error": "empty mesh"}
	var lo: Vector3 = vertices[0]
	var hi: Vector3 = lo
	for vertex: Vector3 in vertices:
		if not vertex.is_finite():
			return {"error": "non-finite vertex"}
		lo = lo.min(vertex)
		hi = hi.max(vertex)
	var size: Vector3 = hi - lo
	if size.x <= 0.0 or size.z <= 0.0 or not size.is_finite():
		return {"error": "zero or non-finite footprint"}
	if size.y < Models.MIN_HEIGHT:
		return {"error": "ground model below minimum height"}
	var origin := Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
	var shifted := PackedVector3Array()
	shifted.resize(vertices.size())
	for index: int in vertices.size():
		shifted[index] = vertices[index] - origin
	return {"vertices": shifted, "size": size}


static func vertex_limit_error(count: int, limit: int = MAX_VERTICES) -> String:
	if count <= 0:
		return "empty mesh"
	if count > limit:
		return "vertex limit: %d > %d" % [count, limit]
	return ""


static func bake_source(item_name: String, path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {"error": "resource missing: " + path}
	var resource: Resource = ResourceLoader.load(path)
	var source: Node = null
	if resource is Script:
		var can_build: bool = false
		for method: Dictionary in (resource as Script).get_script_method_list():
			if String(method["name"]) == "build":
				can_build = true
				break
		if can_build:
			source = resource.call("build", item_name) as Node
	elif resource is Mesh:
		var instance := MeshInstance3D.new()
		instance.mesh = resource as Mesh
		source = instance
	elif resource is PackedScene:
		source = (resource as PackedScene).instantiate()
	if source == null:
		return {"error": "expected a build(name) script, Mesh or PackedScene: " + path}
	var result: Dictionary = bake_node(source, paints_with_vertex_colours(path))
	source.free()
	return result


## Kept outside the tree, like icon_bake._copy_meshes: no callbacks or lights.
static func bake_node(source: Node, vertex_coloured: bool = false) -> Dictionary:
	if source == null:
		return {"error": "null source"}
	var data: Dictionary = {"vertices": PackedVector3Array(), "normals": PackedVector3Array(), "colors": PackedColorArray(), "indices": PackedInt32Array(), "dropped": 0}
	_collect(source, Transform3D.IDENTITY, true, vertex_coloured, data)
	if data.has("error"):
		return {"error": data["error"], "dropped": data["dropped"]}
	if (data["vertices"] as PackedVector3Array).is_empty():
		return {"error": "no visible parts remain", "dropped": data["dropped"]}
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_COLOR] = data["colors"]
	arrays[Mesh.ARRAY_INDEX] = data["indices"]
	var reduced: Dictionary = _reduce_geometry(arrays)
	if reduced.has("error"):
		reduced["dropped"] = data["dropped"]
		return reduced
	var final_arrays: Array = reduced["arrays"]
	if not Models.has_triangle_area(final_arrays[Mesh.ARRAY_VERTEX], final_arrays[Mesh.ARRAY_INDEX]):
		return {"error": "reduced mesh has no triangle area", "dropped": data["dropped"]}
	var centred: Dictionary = centered(final_arrays[Mesh.ARRAY_VERTEX])
	if centred.has("error"):
		return {"error": centred["error"], "dropped": data["dropped"]}
	final_arrays[Mesh.ARRAY_VERTEX] = centred["vertices"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, final_arrays)
	return {"mesh": mesh, "size": centred["size"], "vertices": reduced["vertices"], "triangles": reduced["triangles"],
		"dropped": data["dropped"], "lod": reduced["lod"], "reduced": reduced["reduced"], "cluster": float(reduced.get("cluster", 0.0))}


static func transformed_bounds(vertices: PackedVector3Array, pose: Transform3D) -> Dictionary:
	if vertices.is_empty() or not pose.origin.is_finite() or not pose.basis.is_finite():
		return {"error": "empty or non-finite part bounds"}
	# Translation cannot change extent; leave it out to avoid cancellation at
	# a distant source origin, while still checking that the origin is finite.
	var lo: Vector3 = pose.basis * vertices[0]
	var hi: Vector3 = lo
	for vertex: Vector3 in vertices:
		var posed: Vector3 = pose.basis * vertex
		if not posed.is_finite():
			return {"error": "non-finite part vertex"}
		lo = lo.min(posed)
		hi = hi.max(posed)
	var size: Vector3 = hi - lo
	if not size.is_finite():
		return {"error": "non-finite part size"}
	return {"size": size}


static func should_drop_part(size: Vector3) -> bool:
	# Positions use Vector3 precision, including the exact 0.02 m boundary.
	var threshold: float = Vector3(MIN_PART_EXTENT, 0, 0).x
	return maxf(size.x, maxf(size.y, size.z)) < threshold


## Geometry choice is independent of ImporterMesh and its output order. More
## retained triangles means finer detail; vertex count breaks ties, then LOD id.
static func select_lod(vertex_count: int, levels: Array, limit: int = MAX_VERTICES) -> Dictionary:
	if vertex_count <= 0 or limit <= 0:
		return {"error": "invalid LOD vertex limit"}
	var chosen: Dictionary = {}
	for level: Dictionary in levels:
		var raw: Variant = level.get("indices")
		if not raw is PackedInt32Array:
			return {"error": "invalid LOD indices"}
		var indices: PackedInt32Array = raw
		var stage: int = int(level.get("lod", 0))
		if indices.is_empty() or indices.size() % 3 != 0 or stage < 0:
			return {"error": "empty or incomplete LOD triangles"}
		var used: Dictionary = {}
		for index: int in indices:
			if index < 0 or index >= vertex_count:
				return {"error": "LOD index out of range"}
			used[index] = true
		if used.size() > limit:
			continue
		var triangles: int = floori(float(indices.size()) / 3.0)
		var finer: bool = chosen.is_empty()
		if not finer:
			if triangles != int(chosen["triangles"]):
				finer = triangles > int(chosen["triangles"])
			elif used.size() != int(chosen["vertices"]):
				finer = used.size() > int(chosen["vertices"])
			else:
				finer = stage < int(chosen["lod"])
		if finer:
			chosen = {"lod": stage, "indices": indices, "vertices": used.size(), "triangles": triangles}
	return chosen if not chosen.is_empty() else {"error": "no LOD within vertex limit %d" % limit}


## Only references change: positions, normals and baked sRGB colours are copied
## exactly from each original vertex. No averaging, interpolation or recolour.
static func compact_vertices(arrays: Array, indices: PackedInt32Array) -> Dictionary:
	if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array or not arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
		return {"error": "invalid compacted attributes"}
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	if vertices.is_empty() or normals.size() != vertices.size() or colors.size() != vertices.size() or indices.is_empty() or indices.size() % 3 != 0:
		return {"error": "empty or inconsistent compacted arrays"}
	var remap: Dictionary = {}
	var kept_vertices := PackedVector3Array()
	var kept_normals := PackedVector3Array()
	var kept_colors := PackedColorArray()
	var kept_indices := PackedInt32Array()
	for index: int in indices:
		if index < 0 or index >= vertices.size():
			return {"error": "compacted index out of range"}
		if not remap.has(index):
			remap[index] = kept_vertices.size()
			kept_vertices.append(vertices[index])
			kept_normals.append(normals[index])
			kept_colors.append(colors[index])
		kept_indices.append(int(remap[index]))
	var packed: Array = []
	packed.resize(Mesh.ARRAY_MAX)
	packed[Mesh.ARRAY_VERTEX] = kept_vertices
	packed[Mesh.ARRAY_NORMAL] = kept_normals
	packed[Mesh.ARRAY_COLOR] = kept_colors
	packed[Mesh.ARRAY_INDEX] = kept_indices
	return {"arrays": packed, "vertices": kept_vertices.size(), "triangles": floori(float(kept_indices.size()) / 3.0)}


## Vertex clustering: every vertex goes to the cell of a `cell`-metre grid it
## lies in (from the mesh's low corner); one vertex stands for each used cell, at
## the mean position, with the mean sRGB colour and the summed normal; triangles
## that fall to fewer than three cells are dropped. Deterministic, order kept.
static func cluster_vertices(arrays: Array, cell: float) -> Dictionary:
	if not is_finite(cell) or cell <= 0.0:
		return {"error": "invalid cluster cell"}
	if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array or not arrays[Mesh.ARRAY_COLOR] is PackedColorArray or not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		return {"error": "invalid cluster attributes"}
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty() or normals.size() != vertices.size() or colors.size() != vertices.size() or indices.is_empty() or indices.size() % 3 != 0:
		return {"error": "empty or inconsistent cluster arrays"}
	for index: int in indices:
		if index < 0 or index >= vertices.size():
			return {"error": "cluster index out of range"}
	# Every vertex contributes to a cell mean, including unreferenced vertices.
	for index: int in vertices.size():
		var color: Color = colors[index]
		if not vertices[index].is_finite() or not normals[index].is_finite() or not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a):
			return {"error": "non-finite cluster attributes"}
	var low: Vector3 = vertices[0]
	for vertex: Vector3 in vertices:
		low = low.min(vertex)
	var cell_of: Dictionary = {}     # Vector3i -> cluster id
	var cluster: PackedInt32Array = PackedInt32Array()
	cluster.resize(vertices.size())
	var sums: Array[Vector3] = []
	var normal_sums: Array[Vector3] = []
	var colour_sums: Array[Color] = []
	var counts: PackedInt32Array = PackedInt32Array()
	for index: int in vertices.size():
		var key := Vector3i(((vertices[index] - low) / cell).floor())
		if not cell_of.has(key):
			cell_of[key] = counts.size()
			sums.append(Vector3.ZERO)
			normal_sums.append(Vector3.ZERO)
			colour_sums.append(Color(0, 0, 0, 0))
			counts.append(0)
		var id: int = cell_of[key]
		cluster[index] = id
		sums[id] += vertices[index]
		normal_sums[id] += normals[index]
		colour_sums[id] += colors[index]
		counts[id] += 1
	var merged: Array = []
	merged.resize(Mesh.ARRAY_MAX)
	var merged_vertices := PackedVector3Array()
	var merged_normals := PackedVector3Array()
	var merged_colors := PackedColorArray()
	for id: int in counts.size():
		var share: float = 1.0 / float(counts[id])
		merged_vertices.append(sums[id] * share)
		var normal: Vector3 = normal_sums[id]
		merged_normals.append(normal.normalized() if not normal.is_zero_approx() else Vector3.UP)
		var colour: Color = colour_sums[id] * share
		colour.a = 0.0
		merged_colors.append(colour)
	var kept_indices := PackedInt32Array()
	for offset: int in range(0, indices.size(), 3):
		var a: int = cluster[indices[offset]]
		var b: int = cluster[indices[offset + 1]]
		var c: int = cluster[indices[offset + 2]]
		if a != b and b != c and a != c:
			var area: float = Models.triangle_area_twice(merged_vertices[a], merged_vertices[b], merged_vertices[c])
			if not is_finite(area):
				return {"error": "non-finite clustered triangle area"}
			if area <= Models.MIN_TRIANGLE_AREA_TWICE:
				continue
			kept_indices.append(a)
			kept_indices.append(b)
			kept_indices.append(c)
	if kept_indices.is_empty():
		return {"error": "clustering left no triangles"}
	merged[Mesh.ARRAY_VERTEX] = merged_vertices
	merged[Mesh.ARRAY_NORMAL] = merged_normals
	merged[Mesh.ARRAY_COLOR] = merged_colors
	merged[Mesh.ARRAY_INDEX] = kept_indices
	# Cells no kept triangle uses go too.
	return compact_vertices(merged, kept_indices)


## The finest grid (from a 1/CLUSTER_DIVISIONS of the longest side, growing by
## CLUSTER_GROWTH a try) that brings the mesh within MAX_VERTICES.
static func cluster_to_limit(arrays: Array, limit: int = MAX_VERTICES) -> Dictionary:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays.size() == Mesh.ARRAY_MAX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array else PackedVector3Array()
	if vertices.is_empty():
		return {"error": "no vertices to cluster"}
	var low: Vector3 = vertices[0]
	var high: Vector3 = low
	for vertex: Vector3 in vertices:
		low = low.min(vertex)
		high = high.max(vertex)
	var extent: Vector3 = high - low
	var cell: float = maxf(extent.x, maxf(extent.y, extent.z)) / CLUSTER_DIVISIONS
	if not is_finite(cell) or cell <= 0.0:
		return {"error": "no extent to cluster"}
	for _try: int in CLUSTER_TRIES:
		var result: Dictionary = cluster_vertices(arrays, cell)
		if result.has("error"):
			return result
		if int(result["vertices"]) <= limit:
			result["cluster"] = cell
			return result
		cell *= CLUSTER_GROWTH
	return {"error": "no clustering within vertex limit %d" % limit}


## LOD 0 is the full geometry after tiny parts and unused vertices are removed.
## reduced is the fraction of that stage's referenced vertices removed (0..1).
static func _reduce_geometry(arrays: Array) -> Dictionary:
	var base: Dictionary = compact_vertices(arrays, arrays[Mesh.ARRAY_INDEX])
	if base.has("error"):
		return base
	var base_arrays: Array = base["arrays"]
	if not Models.has_triangle_area(base_arrays[Mesh.ARRAY_VERTEX], base_arrays[Mesh.ARRAY_INDEX]):
		return {"error": "source mesh has no triangle area"}
	var base_count: int = base["vertices"]
	var levels: Array[Dictionary] = [{"lod": 0, "indices": base_arrays[Mesh.ARRAY_INDEX]}]
	if base_count > MAX_VERTICES:
		var importer := ImporterMesh.new()
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, base_arrays)
		importer.generate_lods(LOD_MERGE_ANGLE, LOD_SPLIT_ANGLE, [])
		for lod_index: int in importer.get_surface_lod_count(0):
			levels.append({"lod": lod_index + 1, "indices": importer.get_surface_lod_indices(0, lod_index)})
	var chosen: Dictionary = select_lod(base_count, levels)
	if chosen.has("error"):
		# The simplifier keeps seams (a hard edge, a colour edge) and stops at its
		# error bound, so a dense kit gun can stay over the cap at every stage: then
		# the grid clustering below, coarse enough for a thing a few pixels long.
		var clustered: Dictionary = cluster_to_limit(base_arrays)
		if clustered.has("error"):
			return {"error": "%s; %s" % [chosen["error"], clustered["error"]]}
		clustered["lod"] = CLUSTERED_LOD
		clustered["reduced"] = 1.0 - float(clustered["vertices"]) / float(base_count)
		return clustered
	var result: Dictionary = compact_vertices(base_arrays, chosen["indices"])
	if result.has("error"):
		return result
	var result_arrays: Array = result["arrays"]
	if not Models.has_triangle_area(result_arrays[Mesh.ARRAY_VERTEX], result_arrays[Mesh.ARRAY_INDEX]):
		return {"error": "LOD mesh has no triangle area"}
	var limit_error: String = vertex_limit_error(result["vertices"])
	if not limit_error.is_empty():
		return {"error": limit_error}
	result["lod"] = chosen["lod"]
	result["reduced"] = 1.0 - float(result["vertices"]) / float(base_count)
	return result


static func _collect(node: Node, parent_pose: Transform3D, shown: bool, vertex_coloured: bool, data: Dictionary) -> void:
	if data.has("error"):
		return
	var pose: Transform3D = parent_pose
	if node is Node3D:
		var spatial := node as Node3D
		pose = spatial.transform if spatial.top_level else parent_pose * spatial.transform
		shown = shown and spatial.visible
	if node is MeshInstance3D and shown:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			var mesh: Mesh = low_poly(instance.mesh)
			var determinant: float = pose.basis.determinant()
			if not pose.origin.is_finite() or not pose.basis.is_finite() or not is_finite(determinant) or determinant == 0.0:
				data["error"] = "non-finite or singular mesh transform"
				return
			var part_vertices := PackedVector3Array()
			for surface: int in mesh.get_surface_count():
				if mesh is PointMesh or (mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES):
					data["error"] = "non-triangle surface"
					return
				var referenced: Dictionary = referenced_surface(mesh.surface_get_arrays(surface))
				if referenced.has("error"):
					data["error"] = referenced["error"]
					return
				var arrays: Array = referenced["arrays"]
				part_vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
			if not part_vertices.is_empty():
				var bounds: Dictionary = transformed_bounds(part_vertices, pose)
				if bounds.has("error"):
					data["error"] = bounds["error"]
					return
				if should_drop_part(bounds["size"]):
					data["dropped"] = int(data["dropped"]) + 1
				else:
					for surface: int in mesh.get_surface_count():
						_append_surface(mesh, surface, instance.get_active_material(surface), pose, vertex_coloured, data)
						if data.has("error"):
							return
	for child: Node in node.get_children():
		_collect(child, pose, shown, vertex_coloured, data)


## Preserve source order while removing unused positions and optional attributes.
static func referenced_surface(arrays: Array) -> Dictionary:
	if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
		return {"error": "invalid 3D vertex array"}
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return {"error": "empty surface"}
	if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		return {"error": "invalid triangle indices"}
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for index: int in vertices.size():
			indices.append(index)
	if indices.size() % 3 != 0:
		return {"error": "incomplete triangle indices"}
	var used: Dictionary = {}
	for index: int in indices:
		if index < 0 or index >= vertices.size():
			return {"error": "triangle index out of range"}
		used[index] = true
	var packed: Array = []
	packed.resize(Mesh.ARRAY_MAX)
	for slot: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV]:
		var values: Variant = arrays[slot]
		if values == null:
			continue
		var correct_type: bool = values is PackedColorArray if slot == Mesh.ARRAY_COLOR else (values is PackedVector2Array if slot == Mesh.ARRAY_TEX_UV else values is PackedVector3Array)
		if not correct_type:
			return {"error": "invalid surface attribute type"}
		if values.is_empty():
			continue
		if values.size() != vertices.size():
			return {"error": "inconsistent surface attributes"}
		var kept: Variant = values.slice(0, 0)
		for index: int in vertices.size():
			if used.has(index):
				if slot == Mesh.ARRAY_VERTEX and not vertices[index].is_finite():
					return {"error": "non-finite surface vertex"}
				kept.append(values[index])
		packed[slot] = kept
	var remap: Dictionary = {}
	for index: int in vertices.size():
		if used.has(index):
			remap[index] = remap.size()
	var kept_indices := PackedInt32Array()
	for index: int in indices:
		kept_indices.append(int(remap[index]))
	packed[Mesh.ARRAY_INDEX] = kept_indices
	return {"arrays": packed}


static func _append_surface(mesh: Mesh, surface: int, material: Material, pose: Transform3D, vertex_coloured: bool, data: Dictionary) -> void:
	if mesh is PointMesh or (mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES):
		data["error"] = "non-triangle surface"
		return
	var referenced: Dictionary = referenced_surface(mesh.surface_get_arrays(surface))
	if referenced.has("error"):
		data["error"] = referenced["error"]
		return
	var arrays: Array = referenced["arrays"]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return
	var target_vertices: PackedVector3Array = data["vertices"]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for index: int in vertices.size():
			indices.append(index)
	if indices.size() % 3 != 0 or (not normals.is_empty() and normals.size() != vertices.size()) or (not colors.is_empty() and colors.size() != vertices.size()):
		data["error"] = "invalid triangle attributes"
		return
	for index: int in indices:
		if index < 0 or index >= vertices.size():
			data["error"] = "triangle index out of range"
			return
	var albedo: Color = Color.WHITE
	var texture: Texture2D = null
	var use_vertex: bool = vertex_coloured
	if material is BaseMaterial3D:
		var paint := material as BaseMaterial3D
		albedo = paint.albedo_color
		texture = paint.albedo_texture
		use_vertex = paint.vertex_color_use_as_albedo or (vertex_coloured and texture == null)
	elif material != null:
		data["error"] = "unsupported ground material: " + material.get_class()
		return
	elif not colors.is_empty():
		use_vertex = true
	var image: Image = null
	if texture != null:
		if uvs.size() != vertices.size():
			data["error"] = "albedo texture without vertex UVs"
			return
		image = texture.get_image()
		if image == null or image.is_empty():
			data["error"] = "albedo texture unreadable"
			return
		if image.is_compressed():
			image = image.duplicate() as Image
			if image.decompress() != OK:
				data["error"] = "albedo texture decompression failed"
				return
	var target_normals: PackedVector3Array = data["normals"]
	var target_colors: PackedColorArray = data["colors"]
	var target_indices: PackedInt32Array = data["indices"]
	var base: int = target_vertices.size()
	var normal_pose: Basis = pose.basis.inverse().transposed()
	var mirrored: bool = pose.basis.determinant() < 0.0
	if normals.is_empty():
		normals.resize(vertices.size())
		for offset: int in range(0, indices.size(), 3):
			var a: int = indices[offset]
			var b: int = indices[offset + 1]
			var c: int = indices[offset + 2]
			var normal: Vector3 = (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a]).normalized()
			for index: int in [a, b, c]:
				normals[index] += normal
	for index: int in vertices.size():
		var normal: Vector3 = (normal_pose * normals[index]).normalized()
		if not normal.is_finite() or normal.is_zero_approx():
			data["error"] = "invalid normal"
			return
		var uv: Vector2 = uvs[index] if image != null else Vector2.ZERO
		if not uv.is_finite():
			data["error"] = "non-finite UV"
			return
		var texel: Color = sample_nearest(image, uv)
		var vertex: Color = colors[index] if not colors.is_empty() else Color.WHITE
		var color: Color = vertex_colour(albedo, texel, vertex, use_vertex)
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b):
			data["error"] = "non-finite colour"
			return
		target_vertices.append(pose * vertices[index])
		target_normals.append(normal)
		target_colors.append(color)
	for offset: int in range(0, indices.size(), 3):
		target_indices.append(base + indices[offset])
		target_indices.append(base + indices[offset + (2 if mirrored else 1)])
		target_indices.append(base + indices[offset + (1 if mirrored else 2)])
	data["vertices"] = target_vertices
	data["normals"] = target_normals
	data["colors"] = target_colors
	data["indices"] = target_indices


## Same glTF exception as icon_bake: files with no materials paint COLOR_0.
static func paints_with_vertex_colours(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var json_text: String = ""
	if path.ends_with(".gltf"):
		json_text = FileAccess.get_file_as_string(path)
	elif path.ends_with(".glb"):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() < 20 or file.get_32() != 0x46546C67:
			return false
		file.seek(12)
		var chunk_length: int = file.get_32()
		if file.get_32() != 0x4E4F534A or chunk_length > file.get_length() - 20:
			file.close()
			return false
		json_text = file.get_buffer(chunk_length).get_string_from_utf8()
		file.close()
	var gltf: Variant = JSON.parse_string(json_text) if not json_text.is_empty() else null
	if not gltf is Dictionary:
		return false
	var materials: Variant = (gltf as Dictionary).get("materials", [])
	return materials is Array and (materials as Array).is_empty()


static func stale_file_matches(item_name: String, file_name: String) -> bool:
	if not Models.valid_name(item_name) or file_name.get_file() != file_name:
		return false
	var key: String = item_name.to_lower()
	var candidate: String = file_name.to_lower()
	if candidate == key + ".res" or candidate == key + ".tmp.res":
		return true
	if candidate.begins_with(key + ".") and candidate.ends_with(".tmp.res"):
		var process: String = candidate.trim_prefix(key + ".").trim_suffix(".tmp.res")
		return process.is_valid_int() and process.to_int() > 0
	return false


## Every failed or skipped entry's old outputs go, but a name some entry saved
## this run is never cleared by another entry's failure (a duplicate line, the
## same name in a second list): that file is this run's good model.
static func clear_stale(out_dir: String, entries: Array) -> void:
	var saved_names: Dictionary = {}
	for entry: Dictionary in entries:
		if bool(entry.get("saved", false)):
			saved_names[String(entry["name"]).to_lower()] = true
	for entry: Dictionary in entries:
		if entry.has("output_name") and not saved_names.has(String(entry["output_name"]).to_lower()):
			remove_stale(out_dir, entry)


## Failed and skipped entries cannot leave an older model available to load.
static func remove_stale(out_dir: String, entry: Dictionary) -> void:
	if not entry.has("error") and not entry.has("skipped"):
		return
	var item_name: String = String(entry.get("output_name", entry.get("name", "")))
	if not Models.valid_name(item_name):
		return
	var directory := DirAccess.open(out_dir)
	if directory == null:
		entry["error"] = "%s; stale output: %s" % [entry.get("error", ""), error_string(DirAccess.get_open_error())]
		return
	for file_name: String in directory.get_files():
		if not stale_file_matches(item_name, file_name):
			continue
		var error: Error = directory.remove(file_name)
		if error != OK:
			entry["error"] = "%s; stale %s: %s" % [entry.get("error", ""), file_name, error_string(error)]
		else:
			entry["removed_stale"] = int(entry.get("removed_stale", 0)) + 1


static func exit_code(entries: Array, run_failures: Array) -> int:
	if entries.is_empty() or not run_failures.is_empty():
		return 1
	for entry: Dictionary in entries:
		if entry.has("error") or (not bool(entry.get("saved", false)) and String(entry.get("skipped", "")).is_empty()):
			return 1
	return 0


static func record_lines(entries: Array, run_failures: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	for failure: String in run_failures:
		lines.append("failed run " + failure.replace("\n", " ").replace("\r", " "))
	for entry: Dictionary in entries:
		var item_name: String = entry["name"]
		var stale: String = " removed_stale=%d" % int(entry["removed_stale"]) if entry.has("removed_stale") else ""
		if entry.has("error"):
			var dropped: String = " dropped=%d" % entry["dropped"] if entry.has("dropped") else ""
			lines.append("failed %s %s%s%s" % [item_name, String(entry["error"]).replace("\n", " ").replace("\r", " "), dropped, stale])
		elif entry.has("skipped"):
			lines.append("skipped %s %s%s" % [item_name, entry["skipped"], stale])
		elif bool(entry.get("saved", false)):
			var size: Vector3 = entry["size"]
			var clustered: String = " cluster=%.6f" % float(entry["cluster"]) if float(entry.get("cluster", 0.0)) > 0.0 else ""
			lines.append("saved %s %d %d %.6f %.6f %.6f dropped=%d lod=%d reduced=%.6f%s" % [item_name, entry["vertices"], entry["triangles"], size.x, size.z, size.y,
				int(entry.get("dropped", 0)), int(entry.get("lod", 0)), float(entry.get("reduced", 0.0)), clustered])
		else:
			lines.append("failed %s not reached" % item_name)
	return lines


static func write_record(path: String, lines: PackedStringArray) -> Error:
	var temporary: String = path + ".%d.tmp" % OS.get_process_id()
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	for line: String in lines:
		file.store_line(line)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	return DirAccess.rename_absolute(temporary, path)
