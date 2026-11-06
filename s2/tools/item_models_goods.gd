extends RefCounted
## 파밍 물건 32종. 단위는 m, 발은 y = 0, 새 노드의 소유권은 호출자에게 있다.
## GDScript는 Godot 플랫폼 코드이므로 Rust 기본 규칙의 예외다.
## Kenney CC0 원본은 기존 models/items/의 License.txt를 따른다.

const Models = preload("res://tools/item_models.gd")
const RECIPES: Dictionary = {
	"frag_craft": {"shape": "blueprint", "stamp": "craft"},
	"frag_engine": {"shape": "blueprint", "stamp": "engine"},
	"frag_expedition": {"shape": "blueprint", "stamp": "expedition"},
	"frag_med": {"shape": "blueprint", "stamp": "med"},
	"frag_radio": {"shape": "blueprint", "stamp": "radio"},
	"junk_paper": {"shape": "newspaper"},
	"note_map": {"shape": "note"},
	"info_telegraph": {"shape": "telegraph"},
	"info_timetable": {"shape": "timetable"},
	"core_electric": {"shape": "electric"},
	"core_engine": {"shape": "engine"},
	"plow_core": {"shape": "auger"},
	"junk_nails": {"shape": "bent_nails"},
	"tweezers": {"shape": "tweezers"},
	"rare_saw_blades": {"shape": "saw_blades"},
	"rusk": {"shape": "rusk"},
	"jar_cabbage": {"shape": "cabbage"},
	"jar_honey": {"shape": "honey"},
	"flour": {"shape": "flour"},
	"peas": {"shape": "peas"},
	"rare_coffee_sack": {"shape": "coffee_sack"},
	"fever_pills": {"shape": "blister"},
	"food_pack": {"shape": "food_pack"},
	"herbs": {"shape": "herbs"},
	"med_box": {"shape": "med_box"},
	"plank": {"shape": "plank"},
	"rare_wine_case": {"shape": "wine_case"},
	"rare_silver_case": {"shape": "silver_case"},
	"junk_smokes": {"shape": "smokes"},
	"junk_rag": {"shape": "rag"},
	"luxury_pack": {"shape": "luxury_pack"},
	"it_key": {"shape": "house_key"},
}

const PAPER: Color = Color("c4bda5")
const NEWSPRINT: Color = Color("bbb08f")
const INK: Color = Color("484c4c")
const BLUEPRINT: Color = Color("416e91")
const SEAL_BLUE: Color = Color("304d68")
const CHALK: Color = Color("dedcc6")
const STEEL: Color = Color("9ca9ae")
const STEEL_EDGE: Color = Color("c0cbc9")
const IRON: Color = Color("555f65")
const COPPER: Color = Color("a57954")
const RUST: Color = Color("8d6045")
const WOOD: Color = Color("8d7050")
const WOOD_EDGE: Color = Color("ad916b")
const CORD: Color = Color("7b694f")
const BURLAP: Color = Color("947e5c")
const FLOUR_CLOTH: Color = Color("bfc2b3")
const PEA_GREEN: Color = Color("81936b")
const COFFEE: Color = Color("594637")
const CRUST: Color = Color("a47c4f")
const CRUMB: Color = Color("c6b592")
const LEAF: Color = Color("7c855b")
const DRY_LEAF: Color = Color("91916a")
const RED: Color = Color("a45c53")
const GOLD: Color = Color("b09a62")
const DARK_CLOTH: Color = Color("595364")
const RAG: Color = Color("8f8874")
const GLASS_TINT: Color = Color("b7c6b8")
const KENNEY_ALBEDO: Color = Color("b8b8b8")
const KENNEY_TEXTURE_VALUE: float = 0.85
const GLASS_ALPHA: float = 0.65
const GLASS_ROUGHNESS: float = 0.35
const METALNESS: float = 0.6
const METAL_ROUGHNESS: float = 0.42
const CYLINDER_SEGMENTS: int = 16
const ROUND_SEGMENTS: int = 20
const RING_SEGMENTS: int = 24
const TUBE_SEGMENTS: int = 8
const PAPER_THICKNESS: float = 0.008
const MARK_THICKNESS: float = 0.008
const HALF: float = 0.5
const RIGHT_ANGLE: float = 90.0
const JAR_ASSET: String = Models.FOOD + "honey.glb"
const BOTTLE_ASSET: String = Models.FOOD + "wine-red.glb"
const CAN_ASSET: String = Models.FOOD + "can-small.glb"
const BISCUIT_ASSET: String = Models.FOOD + "chocolate.glb"


static func ids() -> Array:
	return RECIPES.keys()


static func build(id: String) -> Node3D:
	if not RECIPES.has(id):
		return null
	var recipe: Dictionary = RECIPES[id]
	var root: Node3D = Node3D.new()
	root.name = id
	var geometry: Node3D = Node3D.new()
	geometry.name = "Geometry"
	root.add_child(geometry)
	var built: bool = true
	match String(recipe["shape"]):
		"blueprint":
			_blueprint(geometry, String(recipe["stamp"]))
		"newspaper":
			_newspaper(geometry)
		"note":
			_note(geometry)
		"telegraph":
			_telegraph(geometry)
		"timetable":
			_timetable(geometry)
		"electric":
			_electric(geometry)
		"engine":
			_engine(geometry)
		"auger":
			_auger(geometry)
		"bent_nails":
			_bent_nails(geometry)
		"tweezers":
			_tweezers(geometry)
		"saw_blades":
			_saw_blades(geometry)
		"rusk":
			_rusk(geometry)
		"cabbage":
			built = _cabbage(geometry)
		"honey":
			built = _honey(geometry)
		"flour":
			_flour(geometry)
		"peas":
			_peas(geometry)
		"coffee_sack":
			_coffee_sack(geometry)
		"blister":
			_blister(geometry)
		"food_pack":
			built = _food_pack(geometry)
		"herbs":
			_herbs(geometry)
		"med_box":
			_med_box(geometry)
		"plank":
			_plank(geometry)
		"wine_case":
			built = _wine_case(geometry)
		"silver_case":
			_silver_case(geometry)
		"smokes":
			_smokes(geometry)
		"rag":
			_rag(geometry)
		"luxury_pack":
			built = _luxury_pack(geometry)
		"house_key":
			_house_key(geometry)
		_:
			built = false
	if not built:
		root.free()
		return null
	var boxes: Array[AABB] = []
	_collect_bounds(geometry, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		root.free()
		return null
	# 모양·크기는 보존하고, 기울인 빵·천까지 가장 낮은 점만 바닥에 맞춘다.
	geometry.position.y = -_merged_bounds(boxes).position.y
	return root


## 표 한 줄: [도형, 치수, 중심, 색, 선택 회전(도)].
## 원통 치수는 (윗반지름, 높이, 아랫반지름), 고리는 (안, 밖, 높이)다.
static func _layout(root: Node3D, rows: Array, metal: bool = false) -> void:
	for row: Array in rows:
		var dimensions: Vector3 = row[1]
		var at: Vector3 = row[2]
		var color: Color = row[3]
		var turn: Vector3 = row[4] if row.size() > 4 else Vector3.ZERO
		var part: MeshInstance3D = null
		match String(row[0]):
			"box":
				part = _box(root, dimensions, color, at, turn)
			"cylinder":
				part = _cylinder(root, dimensions, color, at, turn)
			"ellipsoid":
				part = _ellipsoid(root, dimensions, color, at, turn)
			"ring":
				part = _ring(root, dimensions, color, at, turn)
			"wedge":
				var wedge: PrismMesh = PrismMesh.new()
				wedge.size = dimensions
				part = Models._part(root, wedge, color, at, turn)
		if part != null and metal:
			_metal(part)


static func _box(root: Node3D, dimensions: Vector3, color: Color, at: Vector3, turn: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	return Models._part(root, mesh, color, at, turn)


static func _cylinder(root: Node3D, dimensions: Vector3, color: Color, at: Vector3, turn: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = dimensions.x
	mesh.height = dimensions.y
	mesh.bottom_radius = dimensions.z
	mesh.radial_segments = CYLINDER_SEGMENTS
	return Models._part(root, mesh, color, at, turn)


static func _ellipsoid(root: Node3D, dimensions: Vector3, color: Color, at: Vector3, turn: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = HALF
	mesh.height = 1.0
	mesh.radial_segments = ROUND_SEGMENTS
	mesh.rings = TUBE_SEGMENTS
	var part: MeshInstance3D = Models._part(root, mesh, color, at, turn)
	part.scale = dimensions
	return part


static func _ring(root: Node3D, dimensions: Vector3, color: Color, at: Vector3, turn: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = dimensions.x
	mesh.outer_radius = dimensions.y
	mesh.rings = RING_SEGMENTS
	mesh.ring_segments = TUBE_SEGMENTS
	var part: MeshInstance3D = Models._part(root, mesh, color, at, turn)
	part.scale.y = dimensions.z / (dimensions.y - dimensions.x)
	return part


static func _metal(part: MeshInstance3D) -> void:
	var material: StandardMaterial3D = part.material_override as StandardMaterial3D
	material.metallic = METALNESS
	material.roughness = METAL_ROUGHNESS


static func _frame(root: Node3D, at: Vector3, turn: Vector3 = Vector3.ZERO) -> Node3D:
	var frame: Node3D = Node3D.new()
	frame.position = at
	frame.rotation_degrees = turn
	root.add_child(frame)
	return frame


## 원통의 긴 축을 두 점에 맞춘다. 새 노드를 쓰므로 공유 메시를 고치지 않는다.
static func _rod(root: Node3D, start: Vector3, finish: Vector3, diameter: float, color: Color, metal: bool = false) -> void:
	var delta: Vector3 = finish - start
	var radius: float = diameter * HALF
	var part: MeshInstance3D = _cylinder(root, Vector3(radius, delta.length(), radius), color, (start + finish) * HALF)
	part.quaternion = Quaternion(Vector3.UP, delta.normalized())
	if metal:
		_metal(part)


## xz 평면의 납작한 선: 핀셋·글줄·나뭇결에 같은 치수 규칙을 쓴다.
static func _bar(root: Node3D, start: Vector3, finish: Vector3, width: float, thickness: float, color: Color, metal: bool = false) -> void:
	var delta: Vector3 = finish - start
	var turn: Vector3 = Vector3(0, rad_to_deg(-atan2(delta.z, delta.x)), 0)
	var part: MeshInstance3D = _box(root, Vector3(delta.length(), thickness, width), color, (start + finish) * HALF, turn)
	if metal:
		_metal(part)


static func _triangle(vertices: Array[Vector3], normals: Array[Vector3], a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	# A ternary of two array literals is an untyped Array, which a typed variable refuses
	# at run time: each literal goes straight into the typed variable instead.
	var points: Array[Vector3] = [a, b, c]
	if (b - a).cross(c - a).dot(normal) > 0.0:
		points = [a, c, b]
	for point: Vector3 in points:
		vertices.append(point)
		normals.append(normal)


static func _quad(vertices: Array[Vector3], normals: Array[Vector3], a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_triangle(vertices, normals, a, b, c, normal)
	_triangle(vertices, normals, b, d, c, normal)


static func _surface(root: Node3D, vertices: Array[Vector3], normals: Array[Vector3], color: Color) -> MeshInstance3D:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return Models._part(root, mesh, color, Vector3.ZERO)


## 잘린 종이·톱니·빵 단면·해진 천을 같은 닫힌 판으로 만든다.
static func _sheet(root: Node3D, outline: PackedVector2Array, color: Color, thickness: float = PAPER_THICKNESS) -> void:
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	var vertices: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for index: int in range(0, indices.size(), 3):
		var a: Vector2 = outline[indices[index]]
		var b: Vector2 = outline[indices[index + 1]]
		var c: Vector2 = outline[indices[index + 2]]
		_triangle(vertices, normals, Vector3(a.x, thickness, a.y), Vector3(b.x, thickness, b.y), Vector3(c.x, thickness, c.y), Vector3.UP)
		_triangle(vertices, normals, Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(c.x, 0, c.y), Vector3.DOWN)
	var area: float = 0.0
	for index: int in outline.size():
		var point: Vector2 = outline[index]
		var next_point: Vector2 = outline[(index + 1) % outline.size()]
		area += point.cross(next_point)
	for index: int in outline.size():
		var point: Vector2 = outline[index]
		var next_point: Vector2 = outline[(index + 1) % outline.size()]
		var edge: Vector2 = next_point - point
		var normal: Vector3 = Vector3(edge.y, 0, -edge.x).normalized() * signf(area)
		_quad(vertices, normals, Vector3(point.x, 0, point.y), Vector3(next_point.x, 0, next_point.y), Vector3(point.x, thickness, point.y), Vector3(next_point.x, thickness, next_point.y), normal)
	_surface(root, vertices, normals, color)


static func _collect_bounds(node: Node, parent_pose: Transform3D, boxes: Array[AABB]) -> void:
	var pose: Transform3D = parent_pose
	if node is Node3D:
		var spatial: Node3D = node as Node3D
		pose = spatial.transform if spatial.top_level else parent_pose * spatial.transform
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance.mesh != null:
			var local_box: AABB = instance.mesh.get_aabb()
			var box: AABB = AABB(pose * local_box.get_endpoint(0), Vector3.ZERO)
			for corner: int in range(1, 8):
				box = box.expand(pose * local_box.get_endpoint(corner))
			boxes.append(box)
	for child: Node in node.get_children():
		_collect_bounds(child, pose, boxes)


static func _merged_bounds(boxes: Array[AABB]) -> AABB:
	var combined: AABB = boxes[0]
	for index: int in range(1, boxes.size()):
		combined = combined.merge(boxes[index])
	return combined


## 공개 원본을 균일하게 줄인다. 읽기 실패는 호출자에게 돌려준다.
static func _kenney(root: Node3D, asset_path: String, extent: float, at: Vector3, tint: Color, glass: bool = false) -> Node3D:
	var scene: PackedScene = load(asset_path) as PackedScene
	if scene == null:
		return null
	var content: Node = scene.instantiate()
	if not content is Node3D:
		content.free()
		return null
	var boxes: Array[AABB] = []
	_collect_bounds(content, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		content.free()
		return null
	var bounds: AABB = _merged_bounds(boxes)
	var longest: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if not is_finite(longest) or longest <= 0.0:
		content.free()
		return null
	var normalized: Node3D = _frame(root, at)
	normalized.scale = Vector3.ONE * (extent / longest)
	normalized.add_child(content)
	var spatial: Node3D = content as Node3D
	spatial.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var tint_rules: Array = [{"h": [0.0, 1.0], "s": [0.0, 1.0], "to_h": tint.h, "to_s": tint.s, "v": KENNEY_TEXTURE_VALUE}]
	var material: StandardMaterial3D = Models._tinted(asset_path.get_base_dir().path_join("Textures/colormap.png"), tint_rules)
	material.albedo_color = KENNEY_ALBEDO
	if glass:
		material.albedo_color.a = GLASS_ALPHA
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = GLASS_ROUGHNESS
	var meshes: Array[MeshInstance3D] = []
	if content is MeshInstance3D:
		meshes.append(content as MeshInstance3D)
	for node: Node in content.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	for instance: MeshInstance3D in meshes:
		instance.material_override = material
		if glass:
			instance.set_meta("goods_glass", true)
	return normalized


static func _blueprint(root: Node3D, motif: String) -> void:
	const OUTLINE: Array[Vector2] = [
		Vector2(-0.11, -0.14), Vector2(0.10, -0.14), Vector2(0.115, -0.08),
		Vector2(0.095, -0.04), Vector2(0.112, 0.015), Vector2(0.099, 0.07),
		Vector2(0.105, 0.14), Vector2(0.05, 0.125), Vector2(0.025, 0.145),
		Vector2(-0.03, 0.13), Vector2(-0.065, 0.15), Vector2(-0.112, 0.12),
	]
	const DRAFT: Array = [
		["box", Vector3(0.12, 0.008, 0.009), Vector3(-0.025, 0.012, -0.10), CHALK],
		["box", Vector3(0.009, 0.008, 0.09), Vector3(-0.08, 0.012, -0.06), CHALK],
		["box", Vector3(0.07, 0.008, 0.009), Vector3(-0.05, 0.012, -0.018), CHALK],
		["box", Vector3(0.045, 0.008, 0.009), Vector3(0.01, 0.012, -0.055), CHALK],
	]
	const STAMP_AT: Vector3 = Vector3(0.032, 0.012, 0.061)
	const SEAL_SIZE: Vector3 = Vector3(0.068, 0.008, 0.068)
	_sheet(root, PackedVector2Array(OUTLINE), BLUEPRINT)
	_layout(root, DRAFT)
	var stamp: Node3D = _frame(root, STAMP_AT)
	stamp.name = "Stamp"
	var seal: MeshInstance3D = _cylinder(stamp, SEAL_SIZE, SEAL_BLUE, Vector3.ZERO)
	seal.name = "Seal"
	match motif:
		"craft":
			_stamp_craft(stamp)
		"engine":
			_stamp_engine(stamp)
		"expedition":
			_stamp_expedition(stamp)
		"med":
			_stamp_med(stamp)
		"radio":
			_stamp_radio(stamp)


static func _stamp_craft(root: Node3D) -> void:
	const PARTS: Array = [
		["box", Vector3(0.018, 0.01, 0.085), Vector3(0.003, 0.011, 0.012), CHALK, Vector3(0, -22, 0)],
		["box", Vector3(0.083, 0.012, 0.029), Vector3(-0.014, 0.012, -0.03), CHALK, Vector3(0, -22, 0)],
	]
	_layout(root, PARTS)


static func _stamp_engine(root: Node3D) -> void:
	const HUB: Vector3 = Vector3(0.019, 0.035, 0.012)
	const TOOTH: Vector3 = Vector3(0.027, 0.012, 0.018)
	const CENTER: Vector3 = Vector3(0, 0.012, 0)
	const TOOTH_RADIUS: float = 0.038
	const TEETH: int = 8
	_ring(root, HUB, CHALK, CENTER)
	for index: int in TEETH:
		var angle: float = TAU * float(index) / float(TEETH)
		_box(root, TOOTH, CHALK, CENTER + Vector3(cos(angle), 0, sin(angle)) * TOOTH_RADIUS, Vector3(0, -rad_to_deg(angle), 0))


static func _stamp_expedition(root: Node3D) -> void:
	const NORTH: Array[Vector2] = [Vector2(0, -0.052), Vector2(0.024, 0.008), Vector2(-0.024, 0.008)]
	const SOUTH: Array[Vector2] = [Vector2(0, 0.052), Vector2(-0.013, -0.003), Vector2(0.013, -0.003)]
	const NEEDLE_AT: Vector3 = Vector3(0, 0.008, 0)
	const NEEDLE_TURN: Vector3 = Vector3(0, -20, 0)
	const PIN: Vector3 = Vector3(0.011, 0.012, 0.011)
	const PIN_AT: Vector3 = Vector3(0, 0.01, 0)
	var needle: Node3D = _frame(root, NEEDLE_AT, NEEDLE_TURN)
	_sheet(needle, PackedVector2Array(NORTH), CHALK, MARK_THICKNESS)
	_sheet(needle, PackedVector2Array(SOUTH), PAPER, MARK_THICKNESS)
	_cylinder(needle, PIN, SEAL_BLUE, PIN_AT)


static func _stamp_med(root: Node3D) -> void:
	const PARTS: Array = [
		["box", Vector3(0.09, 0.012, 0.027), Vector3(0, 0.012, 0), CHALK],
		["box", Vector3(0.027, 0.012, 0.09), Vector3(0, 0.012, 0), CHALK],
	]
	_layout(root, PARTS)


static func _stamp_radio(root: Node3D) -> void:
	const PARTS: Array = [
		["box", Vector3(0.014, 0.012, 0.06), Vector3(0, 0.012, 0.005), CHALK],
		["box", Vector3(0.048, 0.012, 0.012), Vector3(0, 0.012, 0.039), CHALK],
	]
	const WAVE_RADII: Array[float] = [0.028, 0.049]
	const WAVE_STEPS: int = 6
	const WAVE_CENTER: Vector3 = Vector3(0, 0.012, -0.018)
	const WAVE_DIAMETER: float = 0.009
	_layout(root, PARTS)
	for radius: float in WAVE_RADII:
		for step: int in WAVE_STEPS:
			var angle_a: float = PI + PI * float(step) / float(WAVE_STEPS)
			var angle_b: float = PI + PI * float(step + 1) / float(WAVE_STEPS)
			_rod(root, WAVE_CENTER + Vector3(cos(angle_a), 0, sin(angle_a)) * radius, WAVE_CENTER + Vector3(cos(angle_b), 0, sin(angle_b)) * radius, WAVE_DIAMETER, CHALK)


static func _newspaper(root: Node3D) -> void:
	const PARTS: Array = [
		["box", Vector3(0.25, 0.01, 0.20), Vector3(0, 0.005, 0), NEWSPRINT],
		["cylinder", Vector3(0.011, 0.25, 0.011), Vector3(0, 0.011, -0.10), NEWSPRINT, Vector3(0, 0, 90)],
		["box", Vector3(0.21, 0.008, 0.027), Vector3(0, 0.014, -0.068), INK],
		["box", Vector3(0.008, 0.008, 0.12), Vector3(0, 0.014, 0.025), INK],
	]
	const COLUMN_X: Array[float] = [-0.06, 0.06]
	const LINE_Z: Array[float] = [-0.024, 0.003, 0.030, 0.057, 0.084]
	const LINE_SIZE: Vector3 = Vector3(0.088, 0.008, 0.008)
	const LINE_Y: float = 0.014
	_layout(root, PARTS)
	for column_x: float in COLUMN_X:
		for line_z: float in LINE_Z:
			_box(root, LINE_SIZE, INK, Vector3(column_x, LINE_Y, line_z))


static func _note(root: Node3D) -> void:
	const PARTS: Array = [
		["box", Vector3(0.15, 0.008, 0.18), Vector3(0, 0.004, 0), PAPER],
		["box", Vector3(0.009, 0.008, 0.163), Vector3(0.012, 0.011, 0), NEWSPRINT],
		["wedge", Vector3(0.044, 0.048, 0.008), Vector3(0.053, 0.017, -0.067), NEWSPRINT, Vector3(82, 24, 0)],
	]
	const LINES: Array = [
		[Vector3(-0.056, 0.014, -0.045), Vector3(0.033, 0.014, -0.037)],
		[Vector3(-0.051, 0.014, -0.006), Vector3(0.045, 0.014, -0.012)],
		[Vector3(-0.055, 0.014, 0.033), Vector3(0.017, 0.014, 0.041)],
	]
	const INK_WIDTH: float = 0.009
	_layout(root, PARTS)
	for line: Array in LINES:
		_bar(root, line[0], line[1], INK_WIDTH, MARK_THICKNESS, INK)


static func _telegraph(root: Node3D) -> void:
	const PARTS: Array = [
		["cylinder", Vector3(0.047, 0.052, 0.047), Vector3(-0.132, 0.047, 0), PAPER, Vector3(90, 0, 0)],
		["cylinder", Vector3(0.015, 0.008, 0.015), Vector3(-0.132, 0.047, 0.029), CORD, Vector3(90, 0, 0)],
		["ring", Vector3(0.033, 0.041, 0.008), Vector3(-0.132, 0.047, 0.032), NEWSPRINT, Vector3(90, 0, 0)],
		["box", Vector3(0.29, 0.008, 0.052), Vector3(0.036, 0.008, 0.018), PAPER],
		["box", Vector3(0.06, 0.008, 0.052), Vector3(0.184, 0.021, 0.018), NEWSPRINT, Vector3(0, 0, 22)],
	]
	const MARKS: Array = [[-0.085, 0.01], [-0.052, 0.026], [-0.018, 0.01], [0.018, 0.026], [0.055, 0.026], [0.092, 0.01], [0.128, 0.01]]
	const MARK_Y: float = 0.016
	const MARK_Z: float = 0.018
	const MARK_DEPTH: float = 0.012
	_layout(root, PARTS)
	for mark: Array in MARKS:
		_box(root, Vector3(float(mark[1]), MARK_THICKNESS, MARK_DEPTH), INK, Vector3(float(mark[0]), MARK_Y, MARK_Z))


static func _timetable(root: Node3D) -> void:
	const PARTS: Array = [
		["box", Vector3(0.22, 0.009, 0.28), Vector3(0, 0.0045, 0), PAPER],
		["box", Vector3(0.20, 0.008, 0.035), Vector3(0, 0.014, -0.105), SEAL_BLUE],
	]
	const COLUMN_X: Array[float] = [-0.095, -0.034, 0.028, 0.095]
	const ROW_Z: Array[float] = [-0.078, -0.038, 0.002, 0.042, 0.082, 0.122]
	const COLUMN_SIZE: Vector3 = Vector3(0.008, 0.008, 0.208)
	const ROW_SIZE: Vector3 = Vector3(0.198, 0.008, 0.008)
	const GRID_Y: float = 0.014
	const GRID_Z: float = 0.022
	_layout(root, PARTS)
	for column_x: float in COLUMN_X:
		_box(root, COLUMN_SIZE, INK, Vector3(column_x, GRID_Y, GRID_Z))
	for row_z: float in ROW_Z:
		_box(root, ROW_SIZE, INK, Vector3(0, GRID_Y, row_z))


static func _electric(root: Node3D) -> void:
	const PARTS: Array = [
		["cylinder", Vector3(0.071, 0.24, 0.071), Vector3(0, 0.10, 0), IRON, Vector3(0, 0, 90)],
		["cylinder", Vector3(0.078, 0.018, 0.078), Vector3(-0.128, 0.10, 0), STEEL, Vector3(0, 0, 90)],
		["cylinder", Vector3(0.078, 0.018, 0.078), Vector3(0.128, 0.10, 0), STEEL, Vector3(0, 0, 90)],
		["cylinder", Vector3(0.014, 0.055, 0.014), Vector3(0.158, 0.10, -0.035), STEEL_EDGE, Vector3(0, 0, 90)],
		["cylinder", Vector3(0.014, 0.055, 0.014), Vector3(0.158, 0.10, 0.035), STEEL_EDGE, Vector3(0, 0, 90)],
	]
	const COIL_X: Array[float] = [-0.092, -0.055, -0.018, 0.019, 0.056, 0.093]
	const COIL_SIZE: Vector3 = Vector3(0.070, 0.091, 0.022)
	const COIL_Y: float = 0.10
	_layout(root, PARTS, true)
	for coil_x: float in COIL_X:
		_metal(_ring(root, COIL_SIZE, COPPER, Vector3(coil_x, COIL_Y, 0), Vector3(0, 0, RIGHT_ANGLE)))


static func _engine(root: Node3D) -> void:
	const PARTS: Array = [
		["box", Vector3(0.24, 0.025, 0.20), Vector3(0, 0.0125, 0), IRON],
		["cylinder", Vector3(0.083, 0.20, 0.083), Vector3(0, 0.12, 0), IRON],
		["box", Vector3(0.18, 0.025, 0.16), Vector3(0, 0.227, 0), STEEL],
	]
	const FIN_Y: Array[float] = [0.055, 0.089, 0.123, 0.157, 0.191]
	const FIN_SIZE: Vector3 = Vector3(0.225, 0.014, 0.185)
	const BOLT_X: Array[float] = [-0.066, 0.066]
	const BOLT_Z: Array[float] = [-0.052, 0.052]
	const BOLT_Y: float = 0.25
	const BOLT_RADIUS: float = 0.016
	const BOLT_HEIGHT: float = 0.02
	const BOLT_SIDES: int = 6
	_layout(root, PARTS, true)
	for fin_y: float in FIN_Y:
		_metal(_box(root, FIN_SIZE, STEEL, Vector3(0, fin_y, 0)))
	for bolt_x: float in BOLT_X:
		for bolt_z: float in BOLT_Z:
			var bolt: CylinderMesh = CylinderMesh.new()
			bolt.top_radius = BOLT_RADIUS
			bolt.bottom_radius = BOLT_RADIUS
			bolt.height = BOLT_HEIGHT
			bolt.radial_segments = BOLT_SIDES
			_metal(Models._part(root, bolt, STEEL_EDGE, Vector3(bolt_x, BOLT_Y, bolt_z)))


static func _auger(root: Node3D) -> void:
	const SHAFT: Array = [["cylinder", Vector3(0.026, 0.37, 0.026), Vector3(0, 0.108, 0), IRON, Vector3(0, 0, 90)]]
	const STEPS: int = 36
	const TURNS: float = 1.5
	const HALF_LENGTH: float = 0.14
	const AXIS_Y: float = 0.108
	const INNER_RADIUS: float = 0.025
	const OUTER_RADIUS: float = 0.092
	const HALF_BLADE: Vector3 = Vector3(0.006, 0, 0)
	const END_AT: Vector3 = Vector3(0.185, 0.108, 0)
	const END_TURN: Vector3 = Vector3(0, 0, 90)
	_layout(root, SHAFT, true)
	var vertices: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for step: int in STEPS:
		var ratio_a: float = float(step) / float(STEPS)
		var ratio_b: float = float(step + 1) / float(STEPS)
		var angle_a: float = TAU * TURNS * ratio_a
		var angle_b: float = TAU * TURNS * ratio_b
		var center_a: Vector3 = Vector3(lerpf(-HALF_LENGTH, HALF_LENGTH, ratio_a), AXIS_Y, 0)
		var center_b: Vector3 = Vector3(lerpf(-HALF_LENGTH, HALF_LENGTH, ratio_b), AXIS_Y, 0)
		var radial_a: Vector3 = Vector3(0, cos(angle_a), sin(angle_a))
		var radial_b: Vector3 = Vector3(0, cos(angle_b), sin(angle_b))
		var inner_a: Vector3 = center_a + radial_a * INNER_RADIUS
		var outer_a: Vector3 = center_a + radial_a * OUTER_RADIUS
		var inner_b: Vector3 = center_b + radial_b * INNER_RADIUS
		var outer_b: Vector3 = center_b + radial_b * OUTER_RADIUS
		var face_normal: Vector3 = (outer_a - inner_a).cross(inner_b - inner_a).normalized()
		if face_normal.x < 0.0:
			face_normal = -face_normal
		_quad(vertices, normals, inner_a + HALF_BLADE, outer_a + HALF_BLADE, inner_b + HALF_BLADE, outer_b + HALF_BLADE, face_normal)
		_quad(vertices, normals, inner_a - HALF_BLADE, outer_a - HALF_BLADE, inner_b - HALF_BLADE, outer_b - HALF_BLADE, -face_normal)
		var rim_normal: Vector3 = (radial_a + radial_b).normalized()
		_quad(vertices, normals, outer_a - HALF_BLADE, outer_b - HALF_BLADE, outer_a + HALF_BLADE, outer_b + HALF_BLADE, rim_normal)
		_quad(vertices, normals, inner_a - HALF_BLADE, inner_b - HALF_BLADE, inner_a + HALF_BLADE, inner_b + HALF_BLADE, -rim_normal)
		if step == 0:
			_quad(vertices, normals, inner_a - HALF_BLADE, outer_a - HALF_BLADE, inner_a + HALF_BLADE, outer_a + HALF_BLADE, Vector3(0, sin(angle_a), -cos(angle_a)))
		if step == STEPS - 1:
			_quad(vertices, normals, inner_b - HALF_BLADE, outer_b - HALF_BLADE, inner_b + HALF_BLADE, outer_b + HALF_BLADE, Vector3(0, -sin(angle_b), cos(angle_b)))
	_metal(_surface(root, vertices, normals, STEEL))
	var end: Node3D = _frame(root, END_AT, END_TURN)
	_saw_blade(end, 0.055, 10)


static func _bent_nails(root: Node3D) -> void:
	const NAILS: Array = [
		[Vector3(-0.035, 0.018, -0.078), -24.0], [Vector3(0.022, 0.026, -0.01), 35.0],
		[Vector3(-0.028, 0.014, 0.057), -12.0], [Vector3(0.034, 0.03, 0.10), 62.0],
	]
	const PATH: Array[Vector3] = [Vector3(-0.08, 0, 0), Vector3(0.012, 0, 0), Vector3(0.061, 0, 0.037)]
	const HEAD: Vector3 = Vector3(0.033, 0.014, 0.032)
	const SHAFT_DIAMETER: float = 0.014
	for placement: Array in NAILS:
		var nail: Node3D = _frame(root, placement[0], Vector3(0, float(placement[1]), 0))
		for index: int in PATH.size() - 1:
			_rod(nail, PATH[index], PATH[index + 1], SHAFT_DIAMETER, RUST, true)
		_metal(_ellipsoid(nail, HEAD, COPPER, PATH[0]))


static func _tweezers(root: Node3D) -> void:
	const ARMS: Array = [
		[Vector3(-0.165, 0.012, 0), Vector3(-0.07, 0.012, -0.039), Vector3(0.16, 0.012, -0.008)],
		[Vector3(-0.165, 0.012, 0), Vector3(-0.07, 0.012, 0.039), Vector3(0.16, 0.012, 0.008)],
	]
	const ARM_WIDTH: float = 0.021
	const ARM_THICKNESS: float = 0.012
	const EDGE_WIDTH: float = 0.008
	const EDGE_LIFT: Vector3 = Vector3(0, 0.009, 0)
	for arm: Array in ARMS:
		for index: int in arm.size() - 1:
			var start: Vector3 = arm[index]
			var finish: Vector3 = arm[index + 1]
			_bar(root, start, finish, ARM_WIDTH, ARM_THICKNESS, STEEL, true)
			_bar(root, start + EDGE_LIFT, finish + EDGE_LIFT, EDGE_WIDTH, MARK_THICKNESS, STEEL_EDGE, true)


static func _saw_blade(root: Node3D, radius: float, teeth: int) -> void:
	const INNER_RATIO: float = 0.17
	const RIM_RATIO: float = 0.84
	const EDGE_INNER_RATIO: float = 0.72
	const BLADE_HEIGHT: float = 0.012
	const EDGE_HEIGHT: float = 0.008
	const EDGE_Y: float = 0.007
	const TOOTH_Y: float = -0.006
	const TOOTH_BASE_RATIO: float = 0.80
	const TOOTH_WIDTH_RATIO: float = 0.13
	const TOOTH_HEIGHT_RATIO: float = 0.22
	_metal(_ring(root, Vector3(radius * INNER_RATIO, radius * RIM_RATIO, BLADE_HEIGHT), STEEL, Vector3.ZERO))
	_metal(_ring(root, Vector3(radius * EDGE_INNER_RATIO, radius * RIM_RATIO, EDGE_HEIGHT), STEEL_EDGE, Vector3(0, EDGE_Y, 0)))
	var tooth_outline: PackedVector2Array = PackedVector2Array([
		Vector2(-radius * TOOTH_WIDTH_RATIO, 0), Vector2(radius * TOOTH_WIDTH_RATIO, 0),
		Vector2(radius * TOOTH_WIDTH_RATIO, radius * TOOTH_HEIGHT_RATIO),
	])
	for index: int in teeth:
		var angle: float = TAU * float(index) / float(teeth)
		var tooth: Node3D = _frame(root, Vector3(sin(angle), 0, cos(angle)) * radius * TOOTH_BASE_RATIO + Vector3(0, TOOTH_Y, 0), Vector3(0, rad_to_deg(angle), 0))
		_sheet(tooth, tooth_outline, STEEL_EDGE, BLADE_HEIGHT)
		_metal(tooth.get_child(0) as MeshInstance3D)


static func _saw_blades(root: Node3D) -> void:
	const CENTERS: Array[Vector3] = [Vector3(-0.042, 0.012, -0.03), Vector3(0, 0.036, 0), Vector3(0.042, 0.06, 0.03)]
	const RADIUS: float = 0.105
	const TEETH: int = 16
	const CORDS: Array = [
		["box", Vector3(0.29, 0.014, 0.015), Vector3(0, 0.08, 0.015), CORD],
		["box", Vector3(0.015, 0.014, 0.255), Vector3(0, 0.082, 0.005), CORD],
		["ellipsoid", Vector3(0.03, 0.024, 0.025), Vector3(0, 0.095, 0.015), CORD],
	]
	for center: Vector3 in CENTERS:
		var blade: Node3D = _frame(root, center)
		_saw_blade(blade, RADIUS, TEETH)
	_layout(root, CORDS)


static func _rusk(root: Node3D) -> void:
	const OUTLINE: Array[Vector2] = [
		Vector2(-0.065, 0.08), Vector2(-0.065, -0.025), Vector2(-0.045, -0.07),
		Vector2(0, -0.085), Vector2(0.045, -0.07), Vector2(0.065, -0.025), Vector2(0.065, 0.08),
	]
	const SLICES: Array = [
		[Vector3(-0.073, 0.105, 0.01), Vector3(54, -8, -6)],
		[Vector3(0.008, 0.112, -0.005), Vector3(65, 5, 5)],
		[Vector3(0.085, 0.109, 0.007), Vector3(73, 17, 7)],
	]
	const CRUST_THICKNESS: float = 0.034
	const INNER_AT: Vector3 = Vector3(0, 0.034, 0)
	const INNER_SCALE: Vector3 = Vector3(0.81, 1, 0.82)
	const PORES: Array[Vector3] = [Vector3(-0.021, 0.048, -0.025), Vector3(0.025, 0.048, 0.015), Vector3(-0.015, 0.048, 0.047)]
	const PORE_SIZE: Vector3 = Vector3(0.013, 0.008, 0.011)
	for placement: Array in SLICES:
		var slice: Node3D = _frame(root, placement[0], placement[1])
		_sheet(slice, PackedVector2Array(OUTLINE), CRUST, CRUST_THICKNESS)
		var inside: Node3D = _frame(slice, INNER_AT)
		inside.scale = INNER_SCALE
		_sheet(inside, PackedVector2Array(OUTLINE), CRUMB, MARK_THICKNESS)
		for pore: Vector3 in PORES:
			_ellipsoid(slice, PORE_SIZE, WOOD_EDGE, pore)


static func _cabbage(root: Node3D) -> bool:
	const JAR_EXTENT: float = 0.24
	const PARTS: Array = [
		["cylinder", Vector3(0.087, 0.024, 0.087), Vector3(0, 0.231, 0), STEEL],
		["ring", Vector3(0.078, 0.09, 0.012), Vector3(0, 0.242, 0), STEEL_EDGE],
	]
	const FILL: Vector3 = Vector3(0.078, 0.15, 0.078)
	const FILL_AT: Vector3 = Vector3(0, 0.085, 0)
	const SHRED_Y: Array[float] = [0.043, 0.079, 0.115, 0.151, 0.18]
	const SHRED_X: Array[float] = [-0.028, 0.029]
	const SHRED_SIZE: Vector3 = Vector3(0.105, 0.014, 0.018)
	const SHRED_Z: float = 0.057
	const SHRED_TURNS: Array[float] = [-18.0, 22.0]
	if _kenney(root, JAR_ASSET, JAR_EXTENT, Vector3.ZERO, GLASS_TINT, true) == null:
		return false
	_layout(root, PARTS, true)
	var contents: Node3D = _frame(root, Vector3.ZERO)
	contents.name = "Contents"
	_cylinder(contents, FILL, PEA_GREEN, FILL_AT)
	for level: int in SHRED_Y.size():
		for shred_x: float in SHRED_X:
			_box(contents, SHRED_SIZE, DRY_LEAF, Vector3(shred_x, SHRED_Y[level], SHRED_Z), Vector3(0, SHRED_TURNS[level % SHRED_TURNS.size()], 0))
	return true


static func _honey(root: Node3D) -> bool:
	const JAR_EXTENT: float = 0.24
	const COVER: Array = [
		["ellipsoid", Vector3(0.177, 0.025, 0.177), Vector3(0, 0.235, 0), PAPER],
		["ring", Vector3(0.069, 0.081, 0.014), Vector3(0, 0.228, 0), CORD],
		["wedge", Vector3(0.085, 0.064, 0.012), Vector3(0.048, 0.219, 0.049), PAPER, Vector3(55, 25, 0)],
	]
	const DIPPER_START: Vector3 = Vector3(0.025, 0.21, 0)
	const DIPPER_END: Vector3 = Vector3(0.095, 0.355, -0.016)
	const HANDLE_DIAMETER: float = 0.016
	const DIPPER_DIAMETER: float = 0.045
	const GROOVE_RATIOS: Array[float] = [0.78, 0.86, 0.94]
	const GROOVE_SPAN: float = 0.03
	if _kenney(root, JAR_ASSET, JAR_EXTENT, Vector3.ZERO, CRUST) == null:
		return false
	_layout(root, COVER)
	_rod(root, DIPPER_START, DIPPER_END, HANDLE_DIAMETER, WOOD)
	for ratio: float in GROOVE_RATIOS:
		_rod(root, DIPPER_START.lerp(DIPPER_END, ratio - GROOVE_SPAN), DIPPER_START.lerp(DIPPER_END, ratio + GROOVE_SPAN), DIPPER_DIAMETER, WOOD_EDGE)
	return true


## 같은 자루 몸을 목 묶임 또는 넓은 열린 입으로 마무리한다.
static func _sack(root: Node3D, color: Color, open_mouth: bool) -> void:
	const BODY_SIZE: Vector3 = Vector3(0.088, 0.18, 0.10)
	const BODY_AT: Vector3 = Vector3(0, 0.09, 0)
	const SHOULDER_SIZE: Vector3 = Vector3(0.18, 0.09, 0.165)
	const SHOULDER_AT: Vector3 = Vector3(0, 0.172, 0)
	const OPENING: Array = [
		["cylinder", Vector3(0.068, 0.012, 0.068), Vector3(0, 0.215, 0), COFFEE],
		["ring", Vector3(0.068, 0.091, 0.018), Vector3(0, 0.216, 0), BURLAP],
	]
	const NECK: Array = [
		["cylinder", Vector3(0.029, 0.045, 0.045), Vector3(0, 0.225, 0), FLOUR_CLOTH],
		["cylinder", Vector3(0.06, 0.055, 0.029), Vector3(0, 0.273, 0), FLOUR_CLOTH],
		["ring", Vector3(0.027, 0.041, 0.014), Vector3(0, 0.239, 0), CORD],
	]
	_cylinder(root, BODY_SIZE, color, BODY_AT)
	_ellipsoid(root, SHOULDER_SIZE, color, SHOULDER_AT)
	if open_mouth:
		_layout(root, OPENING)
	else:
		_layout(root, NECK)


static func _flour(root: Node3D) -> void:
	const PRINT: Array = [
		["box", Vector3(0.142, 0.037, 0.012), Vector3(0, 0.115, 0.093), SEAL_BLUE],
		["box", Vector3(0.009, 0.13, 0.009), Vector3(-0.073, 0.094, 0.067), PAPER, Vector3(0, 0, -5)],
	]
	_sack(root, FLOUR_CLOTH, false)
	_layout(root, PRINT)


static func _peas(root: Node3D) -> void:
	const SACK_AT: Vector3 = Vector3(-0.10, 0.10, 0)
	const SACK_TURN: Vector3 = Vector3(0, 0, -78)
	const SACK_SCALE: Vector3 = Vector3(0.83, 0.83, 0.83)
	const PEA_SIZE: Vector3 = Vector3(0.028, 0.025, 0.026)
	const PEAS: Array[Vector3] = [
		Vector3(0.093, 0.074, 0), Vector3(0.105, 0.047, 0.016), Vector3(0.12, 0.015, 0.026),
		Vector3(0.15, 0.015, -0.015), Vector3(0.18, 0.015, 0.035), Vector3(0.208, 0.015, -0.033),
		Vector3(0.145, 0.015, 0.074), Vector3(0.234, 0.015, 0.02), Vector3(0.183, 0.015, -0.068),
	]
	var sack: Node3D = _frame(root, SACK_AT, SACK_TURN)
	sack.scale = SACK_SCALE
	_sack(sack, BURLAP, true)
	for pea: Vector3 in PEAS:
		_ellipsoid(root, PEA_SIZE, PEA_GREEN, pea)


static func _coffee_sack(root: Node3D) -> void:
	const WEAVE_X: Array[float] = [-0.06, 0.0, 0.06]
	const WEAVE_Y: Array[float] = [0.04, 0.075, 0.11, 0.145]
	const WEAVE_Z: float = 0.091
	const WEAVE_CENTER_Y: float = 0.095
	const VERTICAL: Vector3 = Vector3(0.008, 0.15, 0.008)
	const HORIZONTAL: Vector3 = Vector3(0.15, 0.008, 0.008)
	const BEAN_SIZE: Vector3 = Vector3(0.029, 0.02, 0.021)
	const BEANS: Array[Vector3] = [
		Vector3(-0.038, 0.226, -0.031), Vector3(0, 0.227, -0.038), Vector3(0.036, 0.228, -0.024),
		Vector3(-0.042, 0.228, 0.005), Vector3(-0.009, 0.235, 0.002), Vector3(0.031, 0.229, 0.008),
		Vector3(-0.027, 0.228, 0.036), Vector3(0.014, 0.23, 0.04), Vector3(0.046, 0.227, 0.03),
	]
	const GROOVE_SIZE: Vector3 = Vector3(0.008, 0.008, 0.018)
	const GROOVE_LIFT: Vector3 = Vector3(0, 0.01, 0)
	_sack(root, BURLAP, true)
	for weave_x: float in WEAVE_X:
		_box(root, VERTICAL, WOOD_EDGE, Vector3(weave_x, WEAVE_CENTER_Y, WEAVE_Z))
	for weave_y: float in WEAVE_Y:
		_box(root, HORIZONTAL, WOOD_EDGE, Vector3(0, weave_y, WEAVE_Z))
	for bean: Vector3 in BEANS:
		_ellipsoid(root, BEAN_SIZE, COFFEE, bean)
		_box(root, GROOVE_SIZE, WOOD, bean + GROOVE_LIFT)


static func _blister(root: Node3D) -> void:
	const BASE: Array = [["box", Vector3(0.155, 0.009, 0.285), Vector3(0, 0.0045, 0), STEEL]]
	const COLUMN_X: Array[float] = [-0.038, 0.038]
	const ROW_Z: Array[float] = [-0.112, -0.067, -0.022, 0.023, 0.068, 0.113]
	const WELL_SIZE: Vector3 = Vector3(0.052, 0.012, 0.035)
	const PILL_SIZE: Vector3 = Vector3(0.038, 0.022, 0.024)
	const WELL_Y: float = 0.014
	const PILL_Y: float = 0.024
	const EMPTY_CELLS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 4)]
	_layout(root, BASE, true)
	for column: int in COLUMN_X.size():
		for row: int in ROW_Z.size():
			_metal(_ellipsoid(root, WELL_SIZE, IRON, Vector3(COLUMN_X[column], WELL_Y, ROW_Z[row])))
			if not EMPTY_CELLS.has(Vector2i(column, row)):
				_ellipsoid(root, PILL_SIZE, PAPER, Vector3(COLUMN_X[column], PILL_Y, ROW_Z[row]))


static func _food_pack(root: Node3D) -> bool:
	const WRAP: Array = [
		["box", Vector3(0.25, 0.085, 0.19), Vector3(0, 0.0425, 0), BURLAP],
		["box", Vector3(0.014, 0.01, 0.195), Vector3(0, 0.091, 0), CORD],
		["box", Vector3(0.255, 0.01, 0.014), Vector3(0, 0.091, 0), CORD],
		["box", Vector3(0.014, 0.089, 0.01), Vector3(0, 0.043, 0.096), CORD],
		["box", Vector3(0.01, 0.089, 0.014), Vector3(0.126, 0.043, 0), CORD],
	]
	const CAN_AT: Vector3 = Vector3(-0.063, 0.097, -0.005)
	const CAN_EXTENT: float = 0.114
	const BISCUITS: Array[Vector3] = [Vector3(0.043, 0.098, 0.038), Vector3(0.071, 0.111, 0.025), Vector3(0.077, 0.097, -0.04)]
	const BISCUIT_EXTENT: float = 0.085
	_layout(root, WRAP)
	if _kenney(root, CAN_ASSET, CAN_EXTENT, CAN_AT, RED) == null:
		return false
	for at: Vector3 in BISCUITS:
		if _kenney(root, BISCUIT_ASSET, BISCUIT_EXTENT, at, CRUMB) == null:
			return false
	return true


static func _herbs(root: Node3D) -> void:
	const STEM_START: Vector3 = Vector3(0, 0.018, 0.145)
	const TIPS: Array[Vector3] = [Vector3(-0.12, 0.024, -0.12), Vector3(-0.046, 0.034, -0.16), Vector3(0.047, 0.025, -0.153), Vector3(0.13, 0.03, -0.103)]
	const LEAF_RATIOS: Array[float] = [0.48, 0.70, 0.88]
	const STEM_DIAMETER: float = 0.012
	const LEAF_SIZE: Vector3 = Vector3(0.047, 0.064, 0.014)
	const LEAF_OFFSET: float = 0.024
	const LEAF_Y: float = 0.012
	const LEAF_TURN: float = 36.0
	const TIE: Array = [
		["ring", Vector3(0.023, 0.037, 0.014), Vector3(0, 0.019, 0.081), CORD, Vector3(90, 0, 0)],
		["ellipsoid", Vector3(0.028, 0.022, 0.027), Vector3(0.016, 0.05, 0.082), CORD],
	]
	for tip_index: int in TIPS.size():
		var tip: Vector3 = TIPS[tip_index]
		_rod(root, STEM_START, tip, STEM_DIAMETER, WOOD)
		for ratio: float in LEAF_RATIOS:
			for side: float in [-1.0, 1.0]:
				var leaf_at: Vector3 = STEM_START.lerp(tip, ratio) + Vector3(side * LEAF_OFFSET, LEAF_Y, 0)
				var leaf_mesh: PrismMesh = PrismMesh.new()
				leaf_mesh.size = LEAF_SIZE
				var color: Color = LEAF if tip_index % 2 == 0 else DRY_LEAF
				Models._part(root, leaf_mesh, color, leaf_at, Vector3(RIGHT_ANGLE, side * LEAF_TURN, 0))
	_layout(root, TIE)


## 상자 바닥·옆판을 공통으로 두고, 뚜껑은 각 물건이 따로 붙인다.
static func _case_walls(root: Node3D, dimensions: Vector3, wall: float, color: Color, metal: bool = false) -> void:
	var bottom: MeshInstance3D = _box(root, Vector3(dimensions.x, wall, dimensions.z), color, Vector3(0, wall * HALF, 0))
	if metal:
		_metal(bottom)
	for side: float in [-1.0, 1.0]:
		var end: MeshInstance3D = _box(root, Vector3(wall, dimensions.y, dimensions.z), color, Vector3(side * (dimensions.x - wall) * HALF, dimensions.y * HALF, 0))
		var front: MeshInstance3D = _box(root, Vector3(dimensions.x - wall * 2.0, dimensions.y, wall), color, Vector3(0, dimensions.y * HALF, side * (dimensions.z - wall) * HALF))
		if metal:
			_metal(end)
			_metal(front)


static func _med_box(root: Node3D) -> void:
	const CASE_SIZE: Vector3 = Vector3(0.25, 0.10, 0.18)
	const WALL: float = 0.014
	const HINGE_AT: Vector3 = Vector3(0, 0.105, -0.09)
	const LID_TURN: Vector3 = Vector3(-24, 0, 0)
	const LID: Array = [
		["box", Vector3(0.255, 0.014, 0.185), Vector3(0, 0, 0.0925), PAPER],
		["box", Vector3(0.09, 0.009, 0.027), Vector3(0, 0.012, 0.0925), RED],
		["box", Vector3(0.027, 0.009, 0.09), Vector3(0, 0.012, 0.0925), RED],
	]
	_case_walls(root, CASE_SIZE, WALL, BURLAP)
	var lid: Node3D = _frame(root, HINGE_AT, LID_TURN)
	_layout(lid, LID)


static func _plank(root: Node3D) -> void:
	const PARTS: Array = [
		["box", Vector3(0.44, 0.028, 0.085), Vector3(0, 0.014, 0), WOOD],
		["box", Vector3(0.36, 0.008, 0.009), Vector3(-0.008, 0.031, -0.023), WOOD_EDGE, Vector3(0, 2, 0)],
		["box", Vector3(0.39, 0.008, 0.009), Vector3(0.012, 0.031, 0.014), CORD, Vector3(0, -1, 0)],
	]
	const HOLE_X: Array[float] = [-0.17, 0.17]
	const HOLE_SIZE: Vector3 = Vector3(0.01, 0.008, 0.01)
	const HOLE_Y: float = 0.031
	_layout(root, PARTS)
	for hole_x: float in HOLE_X:
		_cylinder(root, HOLE_SIZE, INK, Vector3(hole_x, HOLE_Y, 0))


static func _wine_case(root: Node3D) -> bool:
	const CASE_SIZE: Vector3 = Vector3(0.255, 0.142, 0.205)
	const WALL: float = 0.014
	const BOTTLES: Array[Vector3] = [Vector3(-0.058, 0.023, -0.047), Vector3(0.058, 0.023, -0.047), Vector3(-0.058, 0.023, 0.047), Vector3(0.058, 0.023, 0.047)]
	const BOTTLE_EXTENT: float = 0.255
	const WINE_SIZE: Vector3 = Vector3(0.025, 0.12, 0.025)
	const WINE_LIFT: Vector3 = Vector3(0, 0.07, 0)
	const CORK_SIZE: Vector3 = Vector3(0.012, 0.022, 0.012)
	const CORK_LIFT: Vector3 = Vector3(0, 0.259, 0)
	const STRAW_X: Array[float] = [-0.09, -0.045, 0, 0.045, 0.09]
	const STRAW_SIZE: Vector3 = Vector3(0.012, 0.016, 0.17)
	const STRAW_AT: Vector3 = Vector3(0, 0.026, 0)
	const STRAW_TURN: Vector3 = Vector3(0, -15, 0)
	const SEAM_Y: Array[float] = [0.052, 0.102]
	const SEAM_SIZE: Vector3 = Vector3(0.25, 0.008, 0.008)
	const SEAM_Z: float = 0.105
	_case_walls(root, CASE_SIZE, WALL, WOOD)
	for seam_y: float in SEAM_Y:
		_box(root, SEAM_SIZE, CORD, Vector3(0, seam_y, SEAM_Z))
	for straw_x: float in STRAW_X:
		_box(root, STRAW_SIZE, WOOD_EDGE, STRAW_AT + Vector3(straw_x, 0, 0), STRAW_TURN)
	var contents: Node3D = _frame(root, Vector3.ZERO)
	contents.name = "Contents"
	for bottle_at: Vector3 in BOTTLES:
		if _kenney(root, BOTTLE_ASSET, BOTTLE_EXTENT, bottle_at, GLASS_TINT, true) == null:
			return false
		_cylinder(contents, WINE_SIZE, RED, bottle_at + WINE_LIFT)
		_cylinder(root, CORK_SIZE, CORD, bottle_at + CORK_LIFT)
	return true


static func _cigarette(root: Node3D) -> void:
	const PARTS: Array = [
		["cylinder", Vector3(0.008, 0.108, 0.008), Vector3(-0.018, 0, 0), PAPER, Vector3(0, 0, 90)],
		["cylinder", Vector3(0.0085, 0.036, 0.0085), Vector3(0.054, 0, 0), WOOD, Vector3(0, 0, 90)],
		["cylinder", Vector3(0.008, 0.008, 0.008), Vector3(-0.074, 0, 0), IRON, Vector3(0, 0, 90)],
	]
	_layout(root, PARTS)


static func _silver_case(root: Node3D) -> void:
	const CASE_SIZE: Vector3 = Vector3(0.245, 0.032, 0.17)
	const WALL: float = 0.014
	const HINGE_AT: Vector3 = Vector3(0, 0.035, -0.085)
	const LID_TURN: Vector3 = Vector3(-55, 0, 0)
	const LID: Array = [
		["box", Vector3(0.245, 0.012, 0.17), Vector3(0, 0, 0.085), STEEL],
		["box", Vector3(0.22, 0.008, 0.012), Vector3(0, 0.009, 0.155), STEEL_EDGE],
		["box", Vector3(0.025, 0.009, 0.10), Vector3(-0.075, 0.01, 0.083), STEEL_EDGE, Vector3(0, -25, 0)],
	]
	const CIGARETTE_X: Array[float] = [-0.08, -0.048, -0.016, 0.016, 0.048, 0.08]
	const CIGARETTE_Y: float = 0.025
	_case_walls(root, CASE_SIZE, WALL, STEEL, true)
	var lid: Node3D = _frame(root, HINGE_AT, LID_TURN)
	_layout(lid, LID, true)
	for cigarette_x: float in CIGARETTE_X:
		var cigarette: Node3D = _frame(root, Vector3(cigarette_x, CIGARETTE_Y, 0), Vector3(0, RIGHT_ANGLE, 0))
		_cigarette(cigarette)


static func _smokes(root: Node3D) -> void:
	const PLACEMENTS: Array = [[Vector3(-0.02, 0.012, -0.054), -24.0], [Vector3(0.018, 0.022, 0.012), 18.0], [Vector3(0.015, 0.013, 0.075), 57.0]]
	for placement: Array in PLACEMENTS:
		var cigarette: Node3D = _frame(root, placement[0], Vector3(0, float(placement[1]), 0))
		_cigarette(cigarette)


static func _rag(root: Node3D) -> void:
	const OUTLINE: Array[Vector2] = [
		Vector2(-0.13, -0.065), Vector2(-0.063, -0.11), Vector2(-0.014, -0.086),
		Vector2(0.049, -0.114), Vector2(0.12, -0.049), Vector2(0.097, 0.014),
		Vector2(0.13, 0.079), Vector2(0.038, 0.112), Vector2(-0.014, 0.083),
		Vector2(-0.09, 0.117), Vector2(-0.112, 0.035),
	]
	const FOLDS: Array = [
		["wedge", Vector3(0.17, 0.10, 0.018), Vector3(-0.025, 0.027, 0.008), RAG, Vector3(72, 25, -8)],
		["wedge", Vector3(0.13, 0.095, 0.016), Vector3(0.034, 0.031, -0.015), NEWSPRINT, Vector3(67, -32, 5)],
		["ellipsoid", Vector3(0.07, 0.009, 0.05), Vector3(-0.066, 0.016, -0.037), CORD],
	]
	const FRINGE: Array = [
		[Vector3(-0.10, 0.014, 0.061), Vector3(-0.126, 0.012, 0.095)],
		[Vector3(-0.09, 0.015, 0.086), Vector3(-0.107, 0.019, 0.14)],
		[Vector3(0.068, 0.012, 0.09), Vector3(0.08, 0.019, 0.13)],
		[Vector3(0.098, 0.016, 0.07), Vector3(0.142, 0.013, 0.096)],
		[Vector3(-0.116, 0.015, -0.051), Vector3(-0.145, 0.015, -0.067)],
	]
	const FRINGE_WIDTH: float = 0.012
	_sheet(root, PackedVector2Array(OUTLINE), RAG, PAPER_THICKNESS)
	_layout(root, FOLDS)
	for strand: Array in FRINGE:
		_bar(root, strand[0], strand[1], FRINGE_WIDTH, MARK_THICKNESS, RAG)


static func _luxury_pack(root: Node3D) -> bool:
	const WRAP: Array = [
		["ellipsoid", Vector3(0.235, 0.115, 0.195), Vector3(-0.03, 0.0575, 0), DARK_CLOTH],
		["wedge", Vector3(0.15, 0.13, 0.025), Vector3(-0.032, 0.097, 0.01), DARK_CLOTH, Vector3(70, -20, 0)],
		["box", Vector3(0.016, 0.012, 0.19), Vector3(-0.03, 0.119, 0), GOLD],
		["box", Vector3(0.215, 0.012, 0.016), Vector3(-0.03, 0.121, 0), GOLD],
		["ring", Vector3(0.013, 0.028, 0.012), Vector3(-0.056, 0.136, 0), GOLD],
		["ring", Vector3(0.013, 0.028, 0.012), Vector3(-0.004, 0.136, 0), GOLD],
		["ellipsoid", Vector3(0.024, 0.025, 0.024), Vector3(-0.03, 0.14, 0), GOLD],
	]
	const BOTTLE_AT: Vector3 = Vector3(0.11, 0.014, 0.017)
	const BOTTLE_EXTENT: float = 0.16
	const FILL_SIZE: Vector3 = Vector3(0.015, 0.07, 0.015)
	const FILL_LIFT: Vector3 = Vector3(0, 0.045, 0)
	const STOPPER: Vector3 = Vector3(0.013, 0.02, 0.013)
	const STOPPER_LIFT: Vector3 = Vector3(0, 0.164, 0)
	_layout(root, WRAP)
	if _kenney(root, BOTTLE_ASSET, BOTTLE_EXTENT, BOTTLE_AT, GLASS_TINT, true) == null:
		return false
	var contents: Node3D = _frame(root, Vector3.ZERO)
	contents.name = "Contents"
	_cylinder(contents, FILL_SIZE, RED, BOTTLE_AT + FILL_LIFT)
	_metal(_cylinder(root, STOPPER, GOLD, BOTTLE_AT + STOPPER_LIFT))
	return true


static func _house_key(root: Node3D) -> void:
	# key_<번호>가 공유하는 작은 쇠 열쇠. 머리 구멍 위에는 판을 겹치지 않는다.
	const HEAD_SIZE: Vector3 = Vector3(0.009, 0.016, 0.008)
	const HEAD_AT: Vector3 = Vector3(-0.027, 0.004, 0)
	const METAL_PARTS: Array = [
		["box", Vector3(0.058, 0.008, 0.008), Vector3(0.011, 0.004, 0), STEEL],
		["box", Vector3(0.009, 0.008, 0.014), Vector3(0.020, 0.004, 0.009), STEEL],
		["box", Vector3(0.009, 0.008, 0.018), Vector3(0.035, 0.004, 0.010), STEEL],
		["box", Vector3(0.010, 0.009, 0.012), Vector3(-0.007, 0.0045, 0), IRON],
	]
	const TAG_AT: Vector3 = Vector3(-0.006, 0.004, -0.035)
	const TAG_TURN: Vector3 = Vector3(0, -12, 0)
	const TAG_PARTS: Array = [
		["box", Vector3(0.028, 0.008, 0.022), Vector3.ZERO, NEWSPRINT],
		["box", Vector3(0.017, 0.008, 0.008), Vector3(0, 0.008, 0), INK],
	]
	const TIE_SIZE: Vector3 = Vector3(0.003, 0.009, 0.006)
	const TIE_AT: Vector3 = Vector3(-0.023, 0.010, -0.018)
	var head: MeshInstance3D = _ring(root, HEAD_SIZE, STEEL, HEAD_AT)
	head.name = "Head"
	_metal(head)
	_layout(root, METAL_PARTS, true)
	var tag: Node3D = _frame(root, TAG_AT, TAG_TURN)
	tag.name = "Tag"
	_layout(tag, TAG_PARTS)
	_ring(root, TIE_SIZE, CORD, TIE_AT)
