extends RefCounted
## Read and validate once per name (misses included); cache its triangles as
## plain unindexed arrays. No builders, nodes or materials are loaded at runtime.
## A floor still has one opaque draw surface: a Batch gathers each thing's arrays,
## turned and moved whole in native code (Transform3D * PackedVector3Array), and
## commit() makes the one mesh. No SurfaceTool and no per-vertex GDScript on a
## rebuild — 11-07 with SurfaceTool.append_from a floor of 17 things took 30-38 ms
## and one of 300 took 0.5 s (the grey boxes: 1-2 ms and 11 ms).

const ItemArt = preload("res://game/ui/item_art.gd")
const Carry = preload("res://game/sim/carry.gd")
const PATH: String = "res://assets/ground_items/%s.res"
## Pending the coordinator's answer: one policy shared by baking and drawing.
const BOX_ONLY_IDS: Dictionary = {
	"food_pack": true, "med_box": true, "luxury_pack": true, "medkit": true, "ammo_box": true,
}
static var _templates: Dictionary = {}
## unit_box()'s arrays, made on first use.
static var _unit_box: Dictionary = {}


static func box_only(id: String) -> bool:
	return BOX_ONLY_IDS.has(id) or Carry.FieldItems.bag_of(id) != ""


static func valid_name(item_name: String) -> bool:
	return not item_name.is_empty() and item_name.is_valid_filename() and item_name not in [".", ".."] and item_name == item_name.strip_edges() and not item_name.ends_with(".")


static func resolve(id: String, icon: String = "") -> String:
	if box_only(id):
		return ""
	for candidate: String in ItemArt.candidates(id, icon):
		if not template(candidate).is_empty():
			return candidate
	return ""


static func template(item_name: String) -> Dictionary:
	if not valid_name(item_name):
		return {}
	if _templates.has(item_name):
		return _templates[item_name]
	var mesh: ArrayMesh = null
	if ResourceLoader.exists(PATH % item_name):
		mesh = ResourceLoader.load(PATH % item_name) as ArrayMesh
	cache_template(item_name, mesh)
	return _templates[item_name]


## Cache injection also validates fixtures exactly as disk templates are checked.
static func cache_template(item_name: String, mesh: ArrayMesh) -> bool:
	if not valid_name(item_name):
		return false
	var data: Dictionary = arrays_of(mesh)
	if not data.is_empty():
		data.merge(_flat_triangles(data))
	_templates[item_name] = data
	return not data.is_empty()


static func cache_snapshot() -> Dictionary:
	return _templates.duplicate(true)


static func restore_cache(snapshot: Dictionary) -> void:
	_templates = snapshot.duplicate(true)


## A corrupt or empty resource becomes a cached miss and is drawn as a box.
static func arrays_of(mesh: ArrayMesh) -> Dictionary:
	if mesh == null or mesh.get_surface_count() != 1 or mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
		return {}
	var arrays: Array = mesh.surface_get_arrays(0)
	if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
		return {}
	if not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array or not arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
		return {}
	if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		return {}
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if vertices.is_empty() or normals.size() != vertices.size() or colors.size() != vertices.size():
		return {}
	var count: int = indices.size() if not indices.is_empty() else vertices.size()
	if count % 3 != 0:
		return {}
	for index: int in indices:
		if index < 0 or index >= vertices.size():
			return {}
	var lo: Vector3 = vertices[0]
	var hi: Vector3 = lo
	for index: int in vertices.size():
		var vertex: Vector3 = vertices[index]
		var normal: Vector3 = normals[index]
		var color: Color = colors[index]
		if not vertex.is_finite() or not normal.is_finite() or normal.is_zero_approx():
			return {}
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or color.a != 0.0:
			return {}
		lo = lo.min(vertex)
		hi = hi.max(vertex)
	var size: Vector3 = hi - lo
	if size.x <= 0.0 or size.z <= 0.0 or absf(lo.y) > 0.0001 or absf(lo.x + hi.x) > 0.0001 or absf(lo.z + hi.z) > 0.0001:
		return {}
	return {"vertices": vertices, "normals": normals, "colors": colors, "indices": indices, "size": size, "triangles": floori(float(count) / 3.0)}


## The template's triangles spelled out once, at cache fill (never while a floor
## is rebuilt): "flat_vertices", "flat_normals", "flat_colors", three per triangle.
static func _flat_triangles(data: Dictionary) -> Dictionary:
	var vertices: PackedVector3Array = data["vertices"]
	var normals: PackedVector3Array = data["normals"]
	var colors: PackedColorArray = data["colors"]
	var indices: PackedInt32Array = data["indices"]
	if indices.is_empty():
		return {"flat_vertices": vertices, "flat_normals": normals, "flat_colors": colors}
	var flat_vertices := PackedVector3Array()
	var flat_normals := PackedVector3Array()
	var flat_colors := PackedColorArray()
	flat_vertices.resize(indices.size())
	flat_normals.resize(indices.size())
	flat_colors.resize(indices.size())
	for offset: int in indices.size():
		var index: int = indices[offset]
		flat_vertices[offset] = vertices[index]
		flat_normals[offset] = normals[index]
		flat_colors[offset] = colors[index]
	return {"flat_vertices": flat_vertices, "flat_normals": flat_normals, "flat_colors": flat_colors}


## One floor's things on the way to its mesh: unindexed triangle arrays, a
## template's and a box's alike, so nothing is ever renumbered.
class Batch:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()


static func begin() -> Batch:
	return Batch.new()


## The template turned by `yaw` and set with its footprint centre on `at`.
static func append_template(batch: Batch, data: Dictionary, at: Vector3, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	batch.vertices.append_array(Transform3D(turn, at) * (data["flat_vertices"] as PackedVector3Array))
	batch.normals.append_array(Transform3D(turn, Vector3.ZERO) * (data["flat_normals"] as PackedVector3Array))
	batch.colors.append_array(data["flat_colors"] as PackedColorArray)


## A box of `size` standing on `at` (its footprint centre), turned by `yaw` as a
## model would be: the unit box (unit_box) scaled, turned and moved whole. Its
## faces keep their axis normals under the scale, so those are only turned.
static func append_box(batch: Batch, size: Vector3, at: Vector3, color: Color, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	var unit: Dictionary = unit_box()
	batch.vertices.append_array(Transform3D(turn * Basis.from_scale(size), at) * (unit["vertices"] as PackedVector3Array))
	batch.normals.append_array(Transform3D(turn, Vector3.ZERO) * (unit["normals"] as PackedVector3Array))
	var colors := PackedColorArray()
	colors.resize((unit["vertices"] as PackedVector3Array).size())
	colors.fill(color)
	batch.colors.append_array(colors)


## The floor's one mesh, or null when nothing was gathered.
static func commit(batch: Batch) -> ArrayMesh:
	if batch.vertices.is_empty():
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = batch.vertices
	arrays[Mesh.ARRAY_NORMAL] = batch.normals
	arrays[Mesh.ARRAY_COLOR] = batch.colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A 1 m box from y 0 to 1 round the origin's footprint: six faces, two
## triangles each, wound as the floors' boxes are (map_view.box), with normals.
static func unit_box() -> Dictionary:
	if not _unit_box.is_empty():
		return _unit_box
	const FACES: Array = [
		[Vector3.UP, [Vector3(-0.5, 1, -0.5), Vector3(0.5, 1, -0.5), Vector3(0.5, 1, 0.5), Vector3(-0.5, 1, 0.5)]],
		[Vector3.DOWN, [Vector3(-0.5, 0, 0.5), Vector3(0.5, 0, 0.5), Vector3(0.5, 0, -0.5), Vector3(-0.5, 0, -0.5)]],
		[Vector3.BACK, [Vector3(-0.5, 0, 0.5), Vector3(-0.5, 1, 0.5), Vector3(0.5, 1, 0.5), Vector3(0.5, 0, 0.5)]],
		[Vector3.FORWARD, [Vector3(0.5, 0, -0.5), Vector3(0.5, 1, -0.5), Vector3(-0.5, 1, -0.5), Vector3(-0.5, 0, -0.5)]],
		[Vector3.RIGHT, [Vector3(0.5, 0, 0.5), Vector3(0.5, 1, 0.5), Vector3(0.5, 1, -0.5), Vector3(0.5, 0, -0.5)]],
		[Vector3.LEFT, [Vector3(-0.5, 0, -0.5), Vector3(-0.5, 1, -0.5), Vector3(-0.5, 1, 0.5), Vector3(-0.5, 0, 0.5)]],
	]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for face: Array in FACES:
		var corners: Array = face[1]
		for index: int in [0, 1, 2, 0, 2, 3]:
			vertices.append(corners[index] as Vector3)
			normals.append(face[0] as Vector3)
	_unit_box = {"vertices": vertices, "normals": normals}
	return _unit_box
