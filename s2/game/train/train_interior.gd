extends RefCounted
## Furniture uses stable slot names; model files can replace a box without moving it.

const Catalog = preload("res://game/train/train_catalog.gd")
const Context = preload("res://game/train/train_context.gd")
const MODEL_ROOT := "res://models/train_interior/"
var root: Node3D
var props: Dictionary = {}
var rows: Dictionary = {}
var traces: Dictionary = {}
var fire_mark: MeshInstance3D
var _materials: Dictionary = {}


func build(parent: Node3D, car: Dictionary, stove_builder: Callable) -> void:
	root = Node3D.new()
	root.name = "Interior"
	parent.add_child(root)
	for row in Catalog.layout(car)["props"]:
		var at := Catalog.vector(row["at"])
		if row.get("system", "") == "stove":
			stove_builder.call(at)
			continue
		var node: Node3D
		var model: String = String(row["model"])
		var path := MODEL_ROOT + model + ".glb"
		if model.is_valid_identifier() and ResourceLoader.exists(path):
			var packed = load(path)
			if packed is PackedScene:
				node = packed.instantiate() as Node3D
		if node == null:
			node = _box(Catalog.vector(row["size"]), String(row["material"]))
		node.name = String(row["id"])
		node.position = at
		node.rotation.y = float(row["yaw"])
		node.set_meta("model_key", model)
		node.set_meta("reserved_size", Catalog.vector(row["size"]))
		root.add_child(node)
		props[row["id"]] = node
		rows[row["id"]] = row
		if bool(row.get("trace", false)):
			traces[row["id"]] = {"overturned": false, "scorched": false}
	# The fire is only a stand-in prop, with no new light, particles or shader.
	fire_mark = _box(Catalog.vector(Catalog.tuning("fire_mark_size")), "ember")
	fire_mark.name = "FirePlaceholder"
	fire_mark.position = Catalog.vector(Catalog.tuning("fire_mark_at"))
	fire_mark.visible = false
	root.add_child(fire_mark)


func apply(c: Dictionary) -> void:
	for id in props:
		var node: Node3D = props[id]
		var row: Dictionary = rows[id]
		node.visible = Context.is_open(String(row.get("when", "always")), c)
		if traces.has(id):
			if int(c["stage"]) >= 4 and int(c["stage"]) <= 5:
				traces[id]["overturned"] = true
			if c["fire"]:
				traces[id]["scorched"] = true
			node.rotation.z = float(Catalog.tuning("trace_tilt")) if traces[id]["overturned"] else 0.0
			if node is MeshInstance3D and traces[id]["scorched"]:
				node.material_override = _material("iron")
	fire_mark.visible = bool(c["fire"])
	root.set_meta("context", c.duplicate(true))


func cleanup() -> void:
	for id in traces:
		traces[id]["overturned"] = false
		(props[id] as Node3D).rotation.z = 0.0
	# Scorch remains. No rule value or irreversible loss is manufactured here.


func _box(size: Vector3, material: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(material)
	return node


func _material(key: String) -> StandardMaterial3D:
	if not _materials.has(key):
		var rgb: Array = Catalog.data()["materials"][key]
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
		material.roughness = 1.0
		_materials[key] = material
	return _materials[key]
