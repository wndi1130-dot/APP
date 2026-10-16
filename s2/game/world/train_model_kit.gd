class_name TrainModelKit
extends Node3D
## 겉몸만 담당한다. 칸 안, 충돌, 칸 편성, 문과 승하차 자료는 바꾸지 않는다.

const CATALOG_PATH := "res://game/world/train_model_catalog.json"
const MODE_SETTING := "visuals/train_models_enabled"
const Graybox = preload("res://scripts/graybox.gd")
const Weathered = preload("res://fx/shaders/weathered.gdshader")
static var _catalog: Dictionary = {}
static var _libraries: Dictionary = {}
static var _cuts: Dictionary = {}
var _batches: Dictionary = {}


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		_catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	return _catalog


static func models_enabled() -> bool:
	return bool(ProjectSettings.get_setting(MODE_SETTING, true))


static func model_plan(kind: String, book: Dictionary = {}) -> Array:
	if not models_enabled():
		return []
	var data := catalog() if book.is_empty() else book
	var entry: Dictionary = data["kinds"].get(kind, {})
	var plan: Array = entry.get("assets", [])
	for id: String in plan:
		var asset: Dictionary = data["assets"].get(id, {})
		if asset.get("status") != "ready" or not ResourceLoader.exists(asset.get("path", "")):
			return []
	return plan.duplicate()


static func can_replace(kind: String) -> bool:
	var plan := model_plan(kind)
	if plan.is_empty():
		return false
	for id: String in plan:
		var library := asset_meshes(id)
		if library[0].is_empty() or library[1].is_empty():
			return false
	return true


static func part_allowed(kind: String, part: String, site: Dictionary, used_tris: int = -1) -> bool:
	var data := catalog()
	var rule: Dictionary = data["part_rules"].get(part, {})
	var asset: Dictionary = data["assets"].get(part, {})
	var plan := model_plan(kind)
	if plan.size() != 1 or asset.get("status") != "ready" or rule.is_empty():
		return false
	if kind not in rule["kinds"] or site.get("zone") != rule["site"]:
		return false
	for flag: String in rule["requires"]:
		if not site.get(flag, false):
			return false
	for flag: String in rule["forbids"]:
		if site.get(flag, false):
			return false
	var clearance: Array = site.get("clearance_m", [])
	if clearance.size() != 3 or not site.has("position"):
		return false
	for axis in 3:
		if float(clearance[axis]) < float(asset["dimensions_m"][axis]):
			return false
	var body: Dictionary = data["assets"][plan[0]]
	var already := int(body["lod0_tris"]) if used_tris < 0 else used_tris
	return already + int(asset["lod0_tris"]) <= int(body["triangle_limit"])


static func create_stage(parent: Node3D, cutaway: bool = false) -> Node3D:
	var kit := TrainModelKit.new()
	kit.name = "TrainModels"
	parent.add_child(kit)
	if not models_enabled():
		for i in 6:
			kit._graybox_car((float(i) - 2.5) * 4.0)
		return kit
	var kinds: Array = catalog()["stage_kinds"]
	for i in kinds.size():
		# Four coaches and the engine/tender pair share one metres-to-stage scale.
		# Five logical slots retain the original train's total 23.7m display span.
		var at := Vector3((float(i) - 2.0) * 4.8, 0.2, 0)
		if not kit._append_slot(kinds[i], at, Vector3(4.5, 2.5, 2.2), 1.0, cutaway):
			kit._graybox_car(at.x)
	kit._finish()
	return kit


static func attach_field(parent: Node3D, data: Dictionary) -> Node3D:
	var kit := TrainModelKit.new()
	kit.name = "TrainModels"
	parent.add_child(kit)
	var train: Rect2i = data["train"]
	var heading := 1.0
	for car in data["train_cars"]:
		if car["kind"] == "engine":
			var engine_rect: Rect2i = car["rect"]
			heading = 1.0 if engine_rect.get_center().x >= train.get_center().x else -1.0
	for car in data["train_cars"]:
		var rect: Rect2i = car["rect"]
		var at := Vector3(rect.position.x + rect.size.x * 0.5, 0, train.position.y + 1.5)
		kit._append_slot(car["kind"], at, Vector3(rect.size.x - 0.6, 3.0, 2.8), heading, false)
	kit._finish()
	return kit


func _graybox_car(x: float) -> void:
	# 기존의 열린 옆면과 바닥·뒷벽·지붕·끝벽·안쪽 상자를 유지한다.
	Graybox.box(self, Vector3(3.7, 0.25, 2.2), Vector3(x, 0.3, 0), 0.5)
	Graybox.box(self, Vector3(3.7, 2.1, 0.15), Vector3(x, 1.5, -1.0), 0.4)
	Graybox.box(self, Vector3(3.7, 0.15, 2.2), Vector3(x, 2.6, 0), 0.55)
	Graybox.box(self, Vector3(0.12, 2.1, 2.2), Vector3(x - 1.8, 1.5, 0), 0.35)
	Graybox.box(self, Vector3(0.55, 0.4, 0.9), Vector3(x, 0.65, -0.5), 0.6)
	set_meta("fallback_count", int(get_meta("fallback_count", 0)) + 1)


func _append_slot(kind: String, at: Vector3, envelope: Vector3, heading: float, cutaway: bool) -> bool:
	if not can_replace(kind):
		return false
	var data := catalog()
	var plan := model_plan(kind)
	var placements: Array = []
	var span := 0.4 if plan.size() > 1 else 0.0
	var height := 0.0
	var width := 0.0
	var used := 0
	for id: String in plan:
		var asset: Dictionary = data["assets"][id]
		span += float(asset["dimensions_m"][0])
		height = maxf(height, float(asset["dimensions_m"][1]))
		width = maxf(width, float(asset["dimensions_m"][2]))
		used += int(asset["lod0_tris"])
	var cursor := -span * 0.5
	for id: String in plan:
		var length := float(data["assets"][id]["dimensions_m"][0])
		placements.append({"asset": id, "at": Vector3(cursor + length * 0.5, 0, 0)})
		cursor += length + 0.4
	if plan.size() == 1:
		var body: Dictionary = data["assets"][plan[0]]
		for request in data["kinds"][kind]["parts"]:
			var site: Dictionary = body.get("attachment_sites", {}).get(request["site"], {})
			var part: String = request["asset"]
			if part_allowed(kind, part, site, used):
				var p: Array = site["position"]
				placements.append({"asset": part, "at": Vector3(p[0], p[1], p[2])})
				used += int(data["assets"][part]["lod0_tris"])
				height = maxf(height, float(p[1]) + float(data["assets"][part]["dimensions_m"][1]))
	var scale_factor := minf(envelope.x / span, minf(envelope.y / height, envelope.z / width))
	var base := Transform3D(Basis(Vector3.UP, PI if heading < 0 else 0.0).scaled(Vector3.ONE * scale_factor), at)
	for placement in placements:
		var id: String = placement["asset"]
		var transform := base * Transform3D(Basis.IDENTITY, placement["at"])
		var sliced: bool = cutaway and bool(data["kinds"][kind]["people"]) and id == plan[0]
		for lod in 2:
			for row in asset_meshes(id)[lod]:
				var mesh: Mesh = cutaway_mesh(id, lod, row) if sliced else row["mesh"]
				var key := "%s:%d:%s:%d" % [id, lod, sliced, int(floor(at.x / 32.0))]
				if not _batches.has(key):
					_batches[key] = {"mesh": mesh, "material": row["material"], "lod": lod, "transforms": []}
				_batches[key]["transforms"].append(transform if sliced else transform * row["transform"])
	set_meta("model_count", int(get_meta("model_count", 0)) + 1)
	return true


static func asset_meshes(id: String) -> Array:
	if _libraries.has(id):
		return _libraries[id]
	var asset: Dictionary = catalog()["assets"].get(id, {})
	var rows: Array = [[], []]
	if asset.get("status") != "ready":
		return rows
	var scene := load(asset["path"]) as PackedScene
	if scene == null:
		return rows
	var source := scene.instantiate()
	_collect(source, Transform3D.IDENTITY, rows)
	source.free()
	if rows[1].is_empty() and asset["category"] == "parts":
		rows[1] = rows[0]
	_libraries[id] = rows
	return rows


static func _collect(node: Node, parent_transform: Transform3D, rows: Array) -> void:
	var transform: Transform3D = parent_transform * node.transform if node is Node3D else parent_transform
	if node is MeshInstance3D and node.mesh != null:
		var lod := 1 if str(node.name).ends_with("_LOD1") else 0
		var material := ShaderMaterial.new()
		material.shader = Weathered
		var source: Material = node.get_active_material(0)
		if source is StandardMaterial3D:
			if source.albedo_texture != null:
				# Embedded images avoid extracted source files. Generate mipmaps once
				# on the shared image for minification on the phone.
				var embedded := source.albedo_texture as ImageTexture
				if embedded != null:
					var image: Image = embedded.get_image()
					if not image.has_mipmaps():
						image.generate_mipmaps()
						embedded.set_image(image)
				material.set_shader_parameter("albedo_tex", source.albedo_texture)
			material.set_shader_parameter("albedo", source.albedo_color)
		rows[lod].append({"mesh": node.mesh, "transform": transform, "material": material})
	for child in node.get_children():
		_collect(child, transform, rows)


static func cutaway_mesh(id: String, lod: int, row: Dictionary) -> Mesh:
	var key := "%s:%d" % [id, lod]
	if _cuts.has(key):
		return _cuts[key]
	var mesh: Mesh = row["mesh"]
	var transform: Transform3D = row["transform"]
	var dims: Array = catalog()["assets"][id]["dimensions_m"]
	var result := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size():
				indices.append(i)
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		var kept := 0
		for i in range(0, indices.size(), 3):
			var a: Vector3 = transform * vertices[indices[i]]
			var b: Vector3 = transform * vertices[indices[i + 1]]
			var c: Vector3 = transform * vertices[indices[i + 2]]
			var center := (a + b + c) / 3.0
			# +Z is the side facing the home camera. Leave wheels and ends intact.
			if center.z > 0.0 and center.y > float(dims[1]) * 0.28 and absf(center.x) < float(dims[0]) * 0.45:
				continue
			for index in [indices[i], indices[i + 1], indices[i + 2]]:
				if not normals.is_empty():
					builder.set_normal((transform.basis.inverse().transposed() * normals[index]).normalized())
				if not uv.is_empty():
					builder.set_uv(uv[index])
				builder.add_vertex(transform * vertices[index])
			kept += 1
		if kept > 0:
			builder.index()
			builder.commit(result)
	_cuts[key] = result
	return result


func _finish() -> void:
	for key: String in _batches:
		var row: Dictionary = _batches[key]
		var node := MultiMeshInstance3D.new()
		node.name = key.replace(":", "_")
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = row["mesh"]
		multi.instance_count = row["transforms"].size()
		for i in multi.instance_count:
			multi.set_instance_transform(i, row["transforms"][i])
		node.multimesh = multi
		node.material_override = row["material"]
		var near_distance := float(catalog()["near_distance_m"])
		if row["lod"] == 0:
			node.visibility_range_end = near_distance
		else:
			node.visibility_range_begin = near_distance
			node.visibility_range_end = float(catalog()["far_distance_m"])
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
