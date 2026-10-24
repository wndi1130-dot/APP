extends RefCounted
## Furniture models for the first stop's containers: the box a container was
## drawn as becomes the shelf, desk or wardrobe its name says. A container with
## no model here, or whose file is missing, keeps its box. Looks only: the
## container's cell, search time and items do not change.

const Weathered = preload("res://fx/shaders/weathered.gdshader")
const DIR := "res://models/props_stop01/"
const MODE_SETTING := "visuals/prop_models_enabled"

## container id -> model file. Kinds follow the container's name (책상 desk,
## 선반 shelf, 옷장·사물함 wardrobe, 부엌 dining set, 찬장 bookcase-like
## cupboard, 서랍 drawer chest, 침실 bed, 공구함 toolbox). Crates, sacks, trunks,
## the safe, the bench and the bell stay boxes: nothing in the set fits them.
const BY_ID := {
	"office_desk": "office_desk", "flat_desk": "office_desk", "signal_desk": "office_desk",
	"shed_office_desk": "office_desk", "ten_w1_desk": "office_desk", "pharmacy_counter": "office_desk",
	"kiosk_shelf": "shop_shelf", "shop_shelf": "shop_shelf", "shop_back": "shop_shelf",
	"pharmacy_store": "shop_shelf", "south3_shelf": "shop_shelf",
	"flat_wardrobe": "wardrobe", "house1_closet": "wardrobe", "ten_w0_wardrobe": "wardrobe",
	"ten_e1_wardrobe": "wardrobe", "ten_e2_wardrobe": "wardrobe", "shed_foreman": "wardrobe",
	"flat_cupboard": "bookcase", "south2_pantry": "bookcase", "shed_files": "bookcase",
	"house1_kitchen": "dining_set", "house2_kitchen": "dining_set", "ten_w0_kitchen": "dining_set",
	"ten_e0_kitchen": "dining_set", "ten_w1_kitchen": "dining_set", "ten_e1_kitchen": "dining_set",
	"ten_w2_kitchen": "dining_set", "ten_e2_kitchen": "dining_set", "south1_kitchen": "dining_set",
	"house1_bedroom": "drawer_chest_spilled", "south1_bedroom": "iron_bed",
	"shed_cabinet": "toolbox",
}

## id 대응을 먼저 지킨다. 닫힌 궤·보관함·자재함에 맞는 모델은 없어 상자로 둔다.
const BY_SUFFIX: Dictionary = {
	"선반": "shop_shelf", "책상": "office_desk", "침대": "iron_bed",
	"옷장": "wardrobe", "공구함": "toolbox", "찬장": "bookcase",
	"궤": "", "보관함": "", "자재함": "", "상자": "", "묶음": "",
}

static var _rows: Dictionary = {}   # model name -> [{mesh, transform, material}]
static var _batches: Dictionary = {} # path -> LOD 번호별 합친 메시


static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(MODE_SETTING, true))


static func kind_for(id: String, label: String = "") -> String:
	if BY_ID.has(id):
		return BY_ID[id]
	var end := label.strip_edges()
	for suffix: String in BY_SUFFIX:
		if end.ends_with(suffix):
			return BY_SUFFIX[suffix]
	return ""


static func model_for(id: String, label: String = "") -> String:
	if not enabled():
		return ""
	var name := kind_for(id, label)
	return name if name != "" and not rows(name).is_empty() else ""


## Hang the model's meshes under `node` (the container's node). Returns false
## when the container keeps its box.
static func attach(node: Node3D, id: String, at: Vector3, label: String = "") -> bool:
	var name := model_for(id, label)
	if name == "":
		return false
	var holder := Node3D.new()
	holder.name = "Prop"
	holder.position = at
	node.add_child(holder)
	for row: Dictionary in rows(name):
		if row["lod"] != 0:
			continue
		var mesh := MeshInstance3D.new()
		mesh.mesh = row["mesh"]
		mesh.transform = row["transform"]
		mesh.material_override = row["material"]
		holder.add_child(mesh)
	return true


static func rows(name: String) -> Array:
	return rows_path(DIR + name + ".glb")


## 지도 소품과 수납이 같은 로더·재질을 쓴다. 없는 선택 파일은 조용히 되돌린다.
static func rows_path(path: String) -> Array:
	if _rows.has(path):
		return _rows[path]
	var found := []
	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene != null:
			var source := scene.instantiate()
			_collect(source, Transform3D.IDENTITY, found)
			source.free()
	_rows[path] = found
	return found


## 모델의 여러 노드도 LOD마다 메시 하나로 묶는다. 원래 재질과 노드 변환을 보존한다.
static func batch_meshes(path: String) -> Dictionary:
	if _batches.has(path):
		return _batches[path]
	var meshes: Dictionary = {}
	for row: Dictionary in rows_path(path):
		var lod: int = row["lod"]
		if not meshes.has(lod):
			meshes[lod] = ArrayMesh.new()
		var mesh: Mesh = row["mesh"]
		for surface in range(mesh.get_surface_count()):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.append_from(mesh, surface, row["transform"])
			st.set_material(row["material"])
			st.commit(meshes[lod])
	if not meshes.has(0):
		meshes.clear()
	_batches[path] = meshes
	return meshes


## 정점색을 가진 모델(들판 소품 GLB)은 셰이더가 그 색을 곱하게 한다. 임포터는
## 재질 플래그를 켜 주지 않아 메시 자료를 직접 본다. 색 속성이 없는 모델은 그대로.
static func _has_vertex_colors(mesh: Mesh) -> bool:
	for surface in range(mesh.get_surface_count()):
		if mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR] != null:
			return true
	return false


static func _collect(node: Node, parent_transform: Transform3D, found: Array, lod: int = 0) -> void:
	if String(node.name).ends_with("_LOD1"):
		lod = 1
	var transform: Transform3D = parent_transform * node.transform if node is Node3D else parent_transform
	if node is MeshInstance3D and node.mesh != null:
		var material := ShaderMaterial.new()
		material.shader = Weathered
		# Indoors: no snow or rime on the furniture.
		material.set_shader_parameter("sheltered", 1.0)
		var source: Material = node.get_active_material(0)
		if source is StandardMaterial3D:
			if source.albedo_texture != null:
				var embedded := source.albedo_texture as ImageTexture
				if embedded != null:
					var image: Image = embedded.get_image()
					if not image.has_mipmaps():
						image.generate_mipmaps()
						embedded.set_image(image)
				material.set_shader_parameter("albedo_tex", source.albedo_texture)
			material.set_shader_parameter("albedo", source.albedo_color)
		if _has_vertex_colors(node.mesh):
			material.set_shader_parameter("use_vertex_color", true)
		found.append({"mesh": node.mesh, "transform": transform, "material": material, "lod": lod})
	for child in node.get_children():
		_collect(child, transform, found, lod)
