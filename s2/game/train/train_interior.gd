extends RefCounted
## Furniture uses stable slot names; model files can replace a box without moving it.

const Catalog = preload("res://game/train/train_catalog.gd")
const Context = preload("res://game/train/train_context.gd")
const MODEL_ROOT := "res://models/train_interior/"
## The shared props (props_common/README.md) for what the train kit has not got.
const COMMON_ROOT := "res://models/props_common/"
const COMMON_DIM: float = 0.62
var root: Node3D
var props: Dictionary = {}
var rows: Dictionary = {}
var traces: Dictionary = {}
var fire_mark: MeshInstance3D
## The car's dress: the small things its layout marks "dress" (tools/blender/train_car_layers.py,
## the floor, the wall and the ceiling of a lived car) drawn as one mesh with one vertex-colour
## material, so they cost one draw call however many there are (결정 505 잰 값).
var dress: MeshInstance3D
var _materials: Dictionary = {}
static var _dress_meshes: Dictionary = {}
static var _dress_material: StandardMaterial3D
var _build_rows: Array = []
var _build_index: int = 0
var _build_stage: int = 1
var _build_car_id: String = ""
var _build_phase: String = "done"
var _dress_tool: SurfaceTool
var _dress_laid: int = 0


func build(parent: Node3D, car: Dictionary, stove_builder: Callable, stage: int = 1) -> void:
	begin_build(parent, car, stage)
	while building():
		build_step(stove_builder)


## The synchronous first build and the scene's budgeted restage use exactly the same units.
## The caller owns visibility: a restage's parent is hidden until every unit is complete.
func begin_build(parent: Node3D, car: Dictionary, stage: int = 1) -> void:
	root = Node3D.new()
	root.name = "Interior"
	parent.add_child(root)
	_build_rows = Catalog.layout(car)["props"]
	_build_index = 0
	_build_stage = stage
	_build_car_id = String(car.get("id", ""))
	_build_phase = "rows"
	_dress_laid = 0
	_dress_tool = SurfaceTool.new()
	_dress_tool.begin(Mesh.PRIMITIVE_TRIANGLES)


func building() -> bool:
	return _build_phase != "done"


## At most one source row, placeholder, or final mesh commit; never yields inside a unit.
func build_step(stove_builder: Callable) -> String:
	if _build_phase == "rows" and _build_index < _build_rows.size():
		var source: Dictionary = _build_rows[_build_index]
		_build_index += 1
		var row_id: String = String(source["id"])
		if source.has("cars") and not (source["cars"] as Array).has(_build_car_id):
			return "skip:" + row_id
		var home: Array = source.get("home", [0, 3])
		if _build_stage < int(home[0]) or _build_stage > int(home[1]):
			return "skip:" + row_id
		# Resolve without editing Catalog's shared rows, before any kind of construction.
		var row: Dictionary = source.duplicate()
		var models: Dictionary = source.get("home_model", {})
		var base_model: String = String(source["model"])
		var model: String = String(models.get(str(_build_stage), base_model))
		row["model"] = model
		if bool(row.get("dress", false)):
			_append_dress(row)
			return "dress:" + row_id
		if row.get("system", "") == "stove":
			var at: Vector3 = Catalog.vector(row["at"])
			var stove_model: String = model if model != base_model else ""
			if stove_builder.get_argument_count() == 1:
				stove_builder.call(at)
			else:
				stove_builder.call(at, stove_model)
			return "stove:" + row_id
		_build_prop(row)
		return "furniture:" + row_id
	if _build_phase == "rows":
		_build_fire_mark()
		_build_phase = "commit"
		return "fire_mark"
	if _build_phase == "commit":
		_commit_dress()
		_build_rows = []
		_dress_tool = null
		_build_phase = "done"
		return "dress_commit"
	return "done"


static func model_path(model: String) -> String:
	var path: String = MODEL_ROOT + model + ".glb"
	if not ResourceLoader.exists(path):
		path = COMMON_ROOT + model + ".glb"
	return path


func _build_prop(row: Dictionary) -> void:
	var model: String = String(row["model"])
	var at: Vector3 = Catalog.vector(row["at"])
	var node: Node3D
	var path: String = model_path(model)
	if model.is_valid_identifier() and ResourceLoader.exists(path):
		var packed = load(path)
		if packed is PackedScene:
			node = packed.instantiate() as Node3D
			if node != null and path.begins_with(COMMON_ROOT):
				_paint_common(node)
	var fitted: bool = node != null
	if node == null:
		node = _box(Catalog.vector(row["size"]), String(row["material"]))
	node.name = String(row["id"])
	node.position = at
	if fitted:
		_fit_to(node, at, Catalog.vector(row["size"]), float(row.get("grow", 1.0)))
	node.rotation.y = float(row["yaw"])
	node.set_meta("model_key", model)
	node.set_meta("reserved_size", Catalog.vector(row["size"]))
	root.add_child(node)
	props[row["id"]] = node
	rows[row["id"]] = row
	if bool(row.get("trace", false)):
		traces[row["id"]] = {"overturned": false, "scorched": false}


func _build_fire_mark() -> void:
	# The fire is only a stand-in prop, with no new light, particles or shader.
	fire_mark = _box(Catalog.vector(Catalog.tuning("fire_mark_size")), "ember")
	fire_mark.name = "FirePlaceholder"
	fire_mark.position = Catalog.vector(Catalog.tuning("fire_mark_at"))
	fire_mark.visible = false
	root.add_child(fire_mark)


## Each dress row's model stands where its row keeps it, as a prop would (_fit_to), all in one mesh.
func _append_dress(row: Dictionary) -> void:
	var mesh: Mesh = _dress_mesh(String(row["model"]))
	if mesh == null:
		push_warning("train_interior: dress model missing, row left out: " + String(row["id"]))
		return
	var reserved: Vector3 = Catalog.vector(row["size"])
	var box: AABB = mesh.get_aabb()
	var k: float = minf(maxf(float(row.get("grow", 1.0)), 1.0), reserved.y / box.size.y) if box.size.y > 0.0 else 1.0
	var at: Vector3 = Catalog.vector(row["at"])
	var place := Transform3D(Basis(Vector3.UP, float(row["yaw"])).scaled(Vector3.ONE * k),
		Vector3(at.x, at.y - reserved.y * 0.5 - box.position.y * k, at.z))
	_dress_tool.append_from(mesh, 0, place)
	_dress_laid += 1


func _commit_dress() -> void:
	if _dress_laid == 0:
		return
	dress = MeshInstance3D.new()
	dress.name = "Dress"
	dress.mesh = _dress_tool.commit()
	dress.material_override = _dress_paint()
	dress.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(dress)


## Up close the dress shows; on the wide view it is left out, as the budget there is spent.
func show_dress(on: bool) -> void:
	if dress != null:
		dress.visible = on


static func _dress_mesh(model: String) -> Mesh:
	if not _dress_meshes.has(model):
		var mesh: Mesh = null
		var path := MODEL_ROOT + model + ".glb"
		if model.is_valid_identifier() and ResourceLoader.exists(path):
			var packed = load(path)
			if packed is PackedScene:
				var node := (packed as PackedScene).instantiate()
				var found: Array = node.find_children("*", "MeshInstance3D", true, false)
				if node is MeshInstance3D:
					found.push_front(node)
				if not found.is_empty():
					mesh = (found[0] as MeshInstance3D).mesh
				node.free()
		_dress_meshes[model] = mesh
	return _dress_meshes[model]


## The kit's colours are in the vertices, linear (train_interior.py's import script does the same).
static func _dress_paint() -> StandardMaterial3D:
	if _dress_material == null:
		_dress_material = StandardMaterial3D.new()
		_dress_material.vertex_color_use_as_albedo = true
		_dress_material.vertex_color_is_srgb = false
		_dress_material.roughness = 1.0
	return _dress_material


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


## A model stands on the floor of the box its row keeps for it, and one taller
## than that box is made evenly smaller to fit its height: a crate kept under a
## bench fits under it, and one in a taller box does not float. Its length is
## left alone (a bench or a table keeps its seat height and its run). A row's
## `grow` lets a small model be made up to that much bigger to fill its box
## (a board or a tool hung on the wall).
static func _fit_to(node: Node3D, at: Vector3, reserved: Vector3, grow: float = 1.0) -> void:
	var box := _bounds_of(node)
	if box.size.y <= 0.0:
		return
	var k: float = minf(maxf(grow, 1.0), reserved.y / box.size.y)
	node.scale = Vector3.ONE * k
	node.position.y = at.y - reserved.y * 0.5 - box.position.y * k


static func _bounds_of(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		var local: AABB = mi.get_aabb()
		var t := Transform3D.IDENTITY
		var walk: Node = mi
		while walk != node and walk is Node3D:
			t = (walk as Node3D).transform * t
			walk = walk.get_parent()
		local = t * local
		box = local if first else box.merge(local)
		first = false
	return box


func _box(size: Vector3, material: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(material)
	return node


## A shared prop carries its palette in its vertex colours and no material of
## its own (props_common/README.md): it is drawn with them, a little dimmed to
## sit with the train kit's colours.
func _paint_common(node: Node3D) -> void:
	if not _materials.has("_common"):
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.albedo_color = Color(COMMON_DIM, COMMON_DIM, COMMON_DIM)
		material.roughness = 1.0
		_materials["_common"] = material
	for child in node.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = _materials["_common"]


func _material(key: String) -> StandardMaterial3D:
	if not _materials.has(key):
		var rgb: Array = Catalog.data()["materials"][key]
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
		material.roughness = 1.0
		_materials[key] = material
	return _materials[key]
