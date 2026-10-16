class_name TrainModelKit
extends Node3D
## 겉몸만 담당한다. 칸 안, 충돌, 칸 편성, 문과 승하차 자료는 바꾸지 않는다.

const CATALOG_PATH := "res://game/world/train_model_catalog.json"
const MODE_SETTING := "visuals/train_models_enabled"
const Graybox = preload("res://scripts/graybox.gd")
const Weathered = preload("res://fx/shaders/weathered.gdshader")
## 대응표 맨 위에 꼭 있어야 하는 키와 허용하는 값의 꼴.
const CATALOG_SHAPE := {
	"near_distance_m": [TYPE_INT, TYPE_FLOAT],
	"far_distance_m": [TYPE_INT, TYPE_FLOAT],
	"assets": [TYPE_DICTIONARY],
	"kinds": [TYPE_DICTIONARY],
	"part_rules": [TYPE_DICTIONARY],
	"stage_kinds": [TYPE_ARRAY],
}
const ASSET_KEYS := ["status", "category", "path", "dimensions_m", "lod0_tris", "triangle_limit"]
const KIND_KEYS := ["assets", "people", "parts"]
const RULE_KEYS := ["kinds", "site", "requires", "forbids"]
static var _catalog: Dictionary = {}
static var _libraries: Dictionary = {}
static var _cuts: Dictionary = {}
var _batches: Dictionary = {}


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		_catalog = load_catalog(CATALOG_PATH)
	return _catalog


## 읽기·문법·필수 키 검사 가운데 하나라도 실패하면 빈 대응표를 돌려준다.
## 빈 대응표에서는 어떤 종류도 모델로 바뀌지 않으므로 정차·홈·필드가 모두 상자를 그린다.
static func load_catalog(path: String) -> Dictionary:
	var empty := {"assets": {}, "kinds": {}, "part_rules": {}, "stage_kinds": []}
	var json := JSON.new()
	var problem := ""
	if not FileAccess.file_exists(path):
		problem = "파일 없음"
	elif json.parse(FileAccess.get_file_as_string(path)) != OK:
		problem = "문법 오류 %d줄" % json.get_error_line()
	elif not (json.data is Dictionary):
		problem = "맨 위가 사전이 아님"
	else:
		problem = _catalog_problem(json.data)
	if problem != "":
		push_warning("열차 모델 대응표를 쓰지 않고 모든 칸을 상자로 그린다: %s (%s)" % [problem, path])
		return empty
	return json.data


static func _catalog_problem(book: Dictionary) -> String:
	for key: String in CATALOG_SHAPE:
		if not book.has(key) or typeof(book[key]) not in CATALOG_SHAPE[key]:
			return "키 %s" % key
	for id: String in book["assets"]:
		var asset: Variant = book["assets"][id]
		if not (asset is Dictionary and asset.has_all(ASSET_KEYS)) or not (asset["dimensions_m"] is Array and asset["dimensions_m"].size() == 3):
			return "자산 %s" % id
	for kind: String in book["kinds"]:
		var entry: Variant = book["kinds"][kind]
		if not (entry is Dictionary and entry.has_all(KIND_KEYS)) or not (entry["assets"] is Array and entry["parts"] is Array):
			return "종류 %s" % kind
		for id: Variant in entry["assets"]:
			if not book["assets"].has(id):
				return "종류 %s의 자산 %s" % [kind, id]
	for part: String in book["part_rules"]:
		var rule: Variant = book["part_rules"][part]
		if not (rule is Dictionary and rule.has_all(RULE_KEYS)):
			return "부품 규칙 %s" % part
	return ""


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


## body_id는 부품이 붙을 본체다. 본체가 하나인 칸은 비워 두면 그 본체로 보고,
## 기관차와 탄수차처럼 본체가 둘인 칸은 둘 중 어느 본체의 장착 자리인지 반드시 정해야 한다.
static func part_allowed(kind: String, part: String, site: Dictionary, used_tris: int = -1, body_id: String = "") -> bool:
	var data := catalog()
	var rule: Dictionary = data["part_rules"].get(part, {})
	var asset: Dictionary = data["assets"].get(part, {})
	var plan := model_plan(kind)
	if body_id == "" and plan.size() == 1:
		body_id = plan[0]
	if body_id not in plan or asset.get("status") != "ready" or rule.is_empty():
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
	var body: Dictionary = data["assets"][body_id]
	var already := int(body["lod0_tris"]) if used_tris < 0 else used_tris
	return already + int(asset["lod0_tris"]) <= int(body["triangle_limit"])


static func create_stage(parent: Node3D, cutaway: bool = false) -> Node3D:
	var kit := TrainModelKit.new()
	kit.name = "TrainModels"
	parent.add_child(kit)
	var kinds: Array = catalog()["stage_kinds"]
	# 손잡이를 끄거나 대응표를 못 읽어 정차 칸 목록이 비면 원래의 상자 여섯 칸을 그린다.
	if not models_enabled() or kinds.is_empty():
		for i in 6:
			kit._graybox_car((float(i) - 2.5) * 4.0)
		return kit
	for i in kinds.size():
		# Four coaches and the engine/tender pair share one metres-to-stage scale.
		# Five logical slots retain the original train's total 23.7m display span.
		var at := Vector3((float(i) - 2.0) * 4.8, 0.2, 0)
		if not kit._append_slot(kinds[i], at, Vector3(4.5, 2.5, 2.2), 1.0, cutaway):
			kit._graybox_car(at.x)
	kit._finish()
	return kit


## 필드 칸마다 겉몸 모델을 붙인다. 모델로 바꾸지 못한 칸의 train_cars 번호는
## meta "fallback_cars"로 돌려준다. 필드 상자는 호출자가 이 목록만 보고 그린다.
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
	var cars: Array = data["train_cars"]
	var fallback: Array[int] = []
	for index in cars.size():
		var rect: Rect2i = cars[index]["rect"]
		var at := Vector3(rect.position.x + rect.size.x * 0.5, 0, train.position.y + 1.5)
		if not kit._append_slot(cars[index]["kind"], at, Vector3(rect.size.x - 0.6, 3.0, 2.8), heading, false):
			fallback.append(index)
	kit.set_meta("fallback_cars", fallback)
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
	var offsets: Dictionary = {}
	var used: Dictionary = {}
	var span := 0.4 if plan.size() > 1 else 0.0
	var height := 0.0
	var width := 0.0
	for id: String in plan:
		var asset: Dictionary = data["assets"][id]
		span += float(asset["dimensions_m"][0])
		height = maxf(height, float(asset["dimensions_m"][1]))
		width = maxf(width, float(asset["dimensions_m"][2]))
		used[id] = int(asset["lod0_tris"])
	var cursor := -span * 0.5
	for id: String in plan:
		var length := float(data["assets"][id]["dimensions_m"][0])
		offsets[id] = Vector3(cursor + length * 0.5, 0, 0)
		placements.append({"asset": id, "at": offsets[id]})
		cursor += length + 0.4
	for request in data["kinds"][kind]["parts"]:
		# 본체가 둘인 칸의 요청은 "body"로 붙을 본체를 정한다. 정하지 않으면 붙이지 않는다.
		var body_id: String = request.get("body", plan[0] if plan.size() == 1 else "")
		var site: Dictionary = data["assets"].get(body_id, {}).get("attachment_sites", {}).get(request["site"], {})
		var part: String = request["asset"]
		if not part_allowed(kind, part, site, int(used.get(body_id, -1)), body_id):
			continue
		var problem := part_problem(part)
		if problem != "":
			# 부품만 빼고 본체는 그대로 그린다. 빠진 부품은 meta "skipped_parts"에 남긴다.
			push_warning("열차 부품 %s를 %s 칸에 붙이지 못했다: %s" % [part, kind, problem])
			_record("skipped_parts", {"kind": kind, "asset": part, "reason": problem})
			continue
		var p: Array = site["position"]
		placements.append({"asset": part, "at": offsets[body_id] + Vector3(p[0], p[1], p[2])})
		used[body_id] += int(data["assets"][part]["lod0_tris"])
		height = maxf(height, float(p[1]) + float(data["assets"][part]["dimensions_m"][1]))
	# 배율은 길이로만 정해 모델이 칸의 논리 길이를 채운다(양 끝이 칸 끝에서 envelope.x와의 차의 절반만큼 안).
	# 높이·폭은 실측 비율을 지키므로 봉투를 넘을 수 있고, 넘으면 meta "envelope_overflow"에 남긴다.
	var scale_factor := envelope.x / span
	if height * scale_factor > envelope.y or width * scale_factor > envelope.z:
		_record("envelope_overflow", {"kind": kind, "height_m": height * scale_factor, "width_m": width * scale_factor, "envelope_m": envelope})
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


## 부품을 배치에 넣기 전에 파일이 있는지와 두 LOD에 실제 메시가 있는지 본다. 빈 글이면 붙여도 된다.
static func part_problem(part: String) -> String:
	var asset: Dictionary = catalog()["assets"].get(part, {})
	if not ResourceLoader.exists(str(asset.get("path", ""))):
		return "파일 없음"
	var library := asset_meshes(part)
	if library[0].is_empty() or library[1].is_empty():
		return "LOD 메시 없음"
	return ""


func _record(key: String, entry: Dictionary) -> void:
	var list: Array = get_meta(key, [])
	list.append(entry)
	set_meta(key, list)


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
