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

static var _rows: Dictionary = {}   # model name -> [{mesh, transform, material}]


static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(MODE_SETTING, true))


static func model_for(id: String) -> String:
	if not enabled() or not BY_ID.has(id):
		return ""
	var name: String = BY_ID[id]
	return name if not rows(name).is_empty() else ""


## Hang the model's meshes under `node` (the container's node). Returns false
## when the container keeps its box.
static func attach(node: Node3D, id: String, at: Vector3) -> bool:
	var name := model_for(id)
	if name == "":
		return false
	var holder := Node3D.new()
	holder.name = "Prop"
	holder.position = at
	node.add_child(holder)
	for row: Dictionary in rows(name):
		var mesh := MeshInstance3D.new()
		mesh.mesh = row["mesh"]
		mesh.transform = row["transform"]
		mesh.material_override = row["material"]
		holder.add_child(mesh)
	return true


static func rows(name: String) -> Array:
	if _rows.has(name):
		return _rows[name]
	var found := []
	var path := DIR + name + ".glb"
	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene != null:
			var source := scene.instantiate()
			_collect(source, Transform3D.IDENTITY, found)
			source.free()
	_rows[name] = found
	return found


static func _collect(node: Node, parent_transform: Transform3D, found: Array) -> void:
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
		found.append({"mesh": node.mesh, "transform": transform, "material": material})
	for child in node.get_children():
		_collect(child, transform, found)
