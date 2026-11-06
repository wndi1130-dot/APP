extends RefCounted
## 파밍 창의 옷 47종. 기본 도형만 쓰며 생성한 루트의 소유자는 호출자다.
## 단위 m, 펼친 앞면은 +Y, 목은 -Z. 장면 트리·파일·난수에 의존하지 않는다.
## GDScript는 Godot이 요구하는 플랫폼 코드다(공통 규칙 E14 예외).

const Models = preload("res://tools/item_models.gd")
const Wear = preload("res://game/sim/wear.gd")

const SIDES: Array[float] = [-1.0, 1.0]
const TOP_Z: float = -0.2
const DETAIL_WIDTH: float = 0.014
const DETAIL_DEPTH: float = 0.012
const PATTERN_DEPTH: float = 0.006
const BUTTON_RADIUS: float = 0.01
const NECK_STEPS: int = 8
const ARC_STEPS: int = 12
const RADIAL_SEGMENTS: int = 16
const SPHERE_RINGS: int = 8
const CAPSULE_RINGS: int = 4
const TORUS_RINGS: int = 24
const TORUS_SEGMENTS: int = 8
const BUTTON_COLOUR: Color = Color("b8aa80")
const STEEL_COLOUR: Color = Color("a5b3b8")
const DARK_COLOUR: Color = Color("343d43")
const REFLECTOR_COLOUR: Color = Color("c1c5a5")
const FUR_COLOUR: Color = Color("b5a888")

## tint가 없는 옷은 재료별 한 팔레트에서 고른다. 몸판 S=0.25~0.75, V=0.35~0.66.
const PALETTES: Dictionary = {
	"cotton": [Color("a89e7d"), Color("708da0"), Color("936b5e"), Color("596f89"), Color("737c54")],
	"wool": [Color("8d7b68"), Color("526f59"), Color("a39275"), Color("776080"), Color("775e59")],
	"leather": [Color("826347"), Color("68503e")],
	"oilcloth": [Color("7d8056"), Color("887c59")],
	"padded": [Color("536f89"), Color("626f87")],
}
const ROUGHNESS: Dictionary = {"cotton": 0.92, "wool": 0.96, "leather": 0.42, "oilcloth": 0.28, "padded": 0.86}

## 크기는 이 표에서 조정한다. 목부터의 몸판 길이와 소매 길이는 별개다.
const CUTS: Dictionary = {
	"shirt": {"width": 0.25, "length": 0.36, "depth": 0.02, "neck": 0.09, "drop": 0.065, "sleeve": 0.19, "arm": 0.085},
	"sweater": {"width": 0.28, "length": 0.38, "depth": 0.026, "neck": 0.1, "drop": 0.075, "sleeve": 0.2, "arm": 0.105},
	"sweater_thick": {"width": 0.3, "length": 0.4, "depth": 0.032, "neck": 0.105, "drop": 0.078, "sleeve": 0.21, "arm": 0.12},
	"jacket": {"width": 0.3, "length": 0.34, "depth": 0.026, "neck": 0.1, "drop": 0.08, "sleeve": 0.2, "arm": 0.115},
	"leather": {"width": 0.31, "length": 0.45, "depth": 0.026, "neck": 0.11, "drop": 0.09, "sleeve": 0.2, "arm": 0.11},
	"coat": {"width": 0.32, "length": 0.576, "depth": 0.028, "neck": 0.11, "drop": 0.09, "sleeve": 0.2, "arm": 0.12},
	"rain": {"width": 0.34, "length": 0.61, "depth": 0.024, "neck": 0.11, "drop": 0.09, "sleeve": 0.21, "arm": 0.12},
	"fire": {"width": 0.34, "length": 0.6, "depth": 0.028, "neck": 0.11, "drop": 0.09, "sleeve": 0.21, "arm": 0.13},
	"vest": {"width": 0.28, "shoulder": 0.2, "length": 0.34, "depth": 0.024, "neck": 0.1, "drop": 0.13},
	"under": {"width": 0.23, "shoulder": 0.155, "length": 0.32, "depth": 0.018, "neck": 0.095, "drop": 0.14},
	"coverall": {"width": 0.27, "length": 0.3, "depth": 0.024, "neck": 0.09, "drop": 0.065, "sleeve": 0.18, "arm": 0.09},
	"long_johns": {"width": 0.22, "length": 0.3, "depth": 0.018, "neck": 0.08, "drop": 0.055, "sleeve": 0.14, "arm": 0.065},
	"dress": {"width": 0.22, "length": 0.23, "depth": 0.022, "neck": 0.09, "drop": 0.055, "sleeve": 0.085, "arm": 0.07},
}
const FINGER_X: Array[float] = [-0.0495, -0.0165, 0.0165, 0.0495]
const FINGER_TIPS: Array[float] = [-0.065, -0.08, -0.08, -0.06]
const SCARF_PATH: Array[Vector2] = [
	Vector2(-0.08, -0.25), Vector2(-0.14, -0.18), Vector2(-0.1, -0.1),
	Vector2(0.06, -0.04), Vector2(0.13, 0.05), Vector2(0.1, 0.13),
	Vector2(-0.04, 0.19), Vector2(-0.09, 0.27),
]
const SHOE_CUTS: Dictionary = {
	"shoe": {"shaft": 0.035, "width": 0.09, "laces": 3},
	"work": {"shaft": 0.13, "width": 0.115, "laces": 4},
	"rubber": {"shaft": 0.29, "width": 0.12, "laces": 0},
	"fur": {"shaft": 0.19, "width": 0.13, "laces": 0},
}

## 옷 id를 손으로 명시한다. Wear.KINDS와의 집합 일치는 별도 시험이 지킨다.
## tone은 재료 팔레트의 번호, value는 원본 tint의 H를 보존한 몸판 명도다.
const RECIPES: Dictionary = {
	"undershirt_cotton": {"shape": "undershirt", "tone": 0},
	"undershirt_wool": {"shape": "undershirt", "tone": 2, "pattern": "knit"},
	"drawers_cotton": {"shape": "drawers", "tone": 0},
	"long_johns": {"shape": "long_johns", "tone": 0},
	"shirt_cotton": {"shape": "shirt", "tone": 0},
	"shirt_flannel": {"shape": "shirt", "tone": 2, "pattern": "check"},
	"shirt_work": {"shape": "shirt", "tone": 3, "pockets": true},
	"shirt_wool": {"shape": "shirt", "tone": 1, "pattern": "knit"},
	"sweater_wool": {"shape": "sweater", "tone": 1, "pattern": "knit"},
	"sweater_thick": {"shape": "sweater", "cut": "sweater_thick", "tone": 2, "pattern": "cable"},
	"vest_knit": {"shape": "vest", "tone": 0, "style": "knit"},
	"jacket_short": {"shape": "outer", "cut": "jacket", "front": "double", "value": 0.48},
	"jacket_plain": {"shape": "outer", "cut": "jacket", "front": "buttons", "pattern": "check", "value": 0.6},
	"jacket_work": {"shape": "outer", "cut": "jacket", "front": "zip", "pockets": true, "value": 0.54},
	"coat_leather": {"shape": "outer", "cut": "leather", "front": "buttons", "wide_collar": true, "value": 0.51},
	"vest_quilted": {"shape": "vest", "tone": 0, "style": "quilt"},
	"coat_long": {"shape": "outer", "cut": "coat", "front": "double", "belt": true, "value": 0.53},
	"coat_padded": {"shape": "outer", "cut": "coat", "front": "zip", "pattern": "quilt", "value": 0.56},
	"coat_wool_long": {"shape": "outer", "cut": "coat", "front": "buttons", "wide_collar": true, "value": 0.64},
	"raincoat": {"shape": "outer", "cut": "rain", "front": "toggle", "hood": true, "value": 0.59},
	"fire_suit": {"shape": "outer", "cut": "fire", "front": "zip", "reflectors": true, "value": 0.52},
	"vest_armor": {"shape": "vest", "style": "armor", "value": 0.49},
	"trousers_cotton": {"shape": "trousers", "tone": 1},
	"trousers_work": {"shape": "trousers", "tone": 3, "knees": true},
	"trousers_wool": {"shape": "trousers", "tone": 0, "crease": true},
	"overtrousers_oil": {"shape": "trousers", "tone": 0, "wide": true, "cord": true},
	"bib_work": {"shape": "bib", "tone": 4},
	"socks_cotton": {"shape": "socks", "tone": 0},
	"socks_wool": {"shape": "socks", "tone": 0, "thick": true},
	"shoes_leather": {"shape": "footwear", "tone": 0, "style": "shoe"},
	"boots_work": {"shape": "footwear", "tone": 1, "style": "work"},
	"boots_rubber": {"shape": "footwear", "tone": 1, "style": "rubber"},
	"boots_fur": {"shape": "footwear", "tone": 0, "style": "fur"},
	"hat_knit": {"shape": "hat", "style": "knit", "value": 0.6},
	"hat_earflap": {"shape": "hat", "style": "earflap", "value": 0.48},
	"cap_brim": {"shape": "hat", "style": "cap", "value": 0.54},
	"hood": {"shape": "hood", "value": 0.56},
	"hood_wool": {"shape": "hood", "pattern": "knit", "value": 0.64},
	"scarf_wool": {"shape": "scarf", "tone": 4},
	"scarf_thick": {"shape": "scarf", "tone": 1, "thick": true},
	"mask_cloth": {"shape": "mask", "tone": 1},
	"gloves": {"shape": "gloves", "tone": 1, "pattern": "knit"},
	"gloves_cotton": {"shape": "gloves", "value": 0.65, "seams": true},
	"gloves_leather": {"shape": "gloves", "value": 0.51, "seams": true},
	"mittens": {"shape": "gloves", "style": "mitten", "value": 0.59, "pattern": "knit"},
	"coverall": {"shape": "coverall", "tone": 3},
	"dress_wool": {"shape": "dress", "tone": 3},
}


static func ids() -> Array:
	return RECIPES.keys()


static func build(id: String) -> Node3D:
	if not RECIPES.has(id):
		return null
	var recipe: Dictionary = RECIPES[id]
	var root: Node3D = Node3D.new()
	root.name = id
	var colour: Color = _cloth_colour(id, recipe)
	match String(recipe["shape"]):
		"undershirt":
			_undershirt(root, colour, recipe)
		"drawers":
			_drawers(root, colour)
		"long_johns":
			_long_johns(root, colour)
		"shirt":
			_shirt(root, colour, recipe)
		"sweater":
			_sweater(root, colour, recipe)
		"outer":
			_outer(root, colour, recipe)
		"vest":
			_vest(root, colour, recipe)
		"trousers":
			_trousers(root, colour, recipe)
		"bib":
			_bib(root, colour)
		"coverall":
			_coverall(root, colour)
		"dress":
			_dress(root, colour)
		"socks":
			_socks(root, colour, recipe)
		"footwear":
			_footwear(root, colour, recipe)
		"gloves":
			_gloves(root, colour, recipe)
		"hat":
			_hat(root, colour, recipe)
		"hood":
			_hood(root, colour, recipe)
		"scarf":
			_scarf(root, colour, recipe)
		"mask":
			_mask(root, colour)
		_:
			root.free()
			return null
	var kind: Dictionary = Wear.KINDS[id]
	_apply_finish(root, float(ROUGHNESS[String(kind["stuff"])]))
	return root


static func _cloth_colour(id: String, recipe: Dictionary) -> Color:
	var look: Dictionary = Wear.look(id)
	var tint: Array = look.get("look_tint", [])
	if tint.size() == 3:
		var srgb: Color = Color(float(tint[0]), float(tint[1]), float(tint[2])).linear_to_srgb()
		return Color.from_hsv(srgb.h, clampf(srgb.s, 0.25, 0.75), clampf(float(recipe.get("value", 0.56)), 0.35, 0.66))
	var kind: Dictionary = Wear.KINDS[id]
	var palette: Array = PALETTES[String(kind["stuff"])]
	return palette[int(recipe.get("tone", 0))]


static func _shade(colour: Color, value_change: float) -> Color:
	return Color.from_hsv(colour.h, minf(colour.s, 0.75), clampf(colour.v + value_change, 0.12, 0.78))


static func _apply_finish(node: Node, roughness: float) -> void:
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		var material: StandardMaterial3D = instance.material_override as StandardMaterial3D
		if material != null and material.metallic == 0.0:
			material.roughness = roughness
	for child: Node in node.get_children():
		_apply_finish(child, roughness)


## bottom은 바닥으로부터의 높이. 모든 도움 함수는 y=0 아래로 내려가지 않는다.
static func _box(parent: Node3D, colour: Color, size: Vector3, at: Vector2, bottom: float = 0.0, yaw: float = 0.0) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return Models._part(parent, mesh, colour, Vector3(at.x, bottom + size.y * 0.5, at.y), Vector3(0, yaw, 0))


static func _oval(parent: Node3D, colour: Color, size: Vector3, at: Vector2, bottom: float = 0.0) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = RADIAL_SEGMENTS
	mesh.rings = SPHERE_RINGS
	var instance: MeshInstance3D = Models._part(parent, mesh, colour, Vector3(at.x, bottom + size.y * 0.5, at.y))
	instance.scale = size
	return instance


## XZ를 잇는 납작한 캡슐. 회전 뒤 월드 Y가 되는 로컬 Z만 눌러 두께를 지킨다.
static func _stroke(parent: Node3D, colour: Color, start: Vector2, finish: Vector2, width: float, depth: float, bottom: float = 0.0) -> MeshInstance3D:
	var delta: Vector2 = finish - start
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = width * 0.5
	mesh.height = delta.length() + width
	mesh.radial_segments = RADIAL_SEGMENTS
	mesh.rings = CAPSULE_RINGS
	var middle: Vector2 = (start + finish) * 0.5
	var instance: MeshInstance3D = Models._part(parent, mesh, colour,
		Vector3(middle.x, bottom + depth * 0.5, middle.y), Vector3(90, rad_to_deg(atan2(delta.x, delta.y)), 0))
	instance.scale = Vector3(1, 1, depth / width)
	return instance


static func _tapered(parent: Node3D, colour: Color, start: Vector2, finish: Vector2, start_width: float, end_width: float, depth: float) -> void:
	var delta: Vector2 = finish - start
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = start_width * 0.5
	mesh.top_radius = end_width * 0.5
	mesh.height = delta.length()
	mesh.radial_segments = RADIAL_SEGMENTS
	var middle: Vector2 = (start + finish) * 0.5
	var instance: MeshInstance3D = Models._part(parent, mesh, colour,
		Vector3(middle.x, depth * 0.5, middle.y), Vector3(90, rad_to_deg(atan2(delta.x, delta.y)), 0))
	instance.scale = Vector3(1, 1, depth / maxf(start_width, end_width))


static func _triangle(parent: Node3D, colour: Color, width: float, length: float, depth: float, at: Vector2, apex: float) -> void:
	var mesh: PrismMesh = PrismMesh.new()
	mesh.size = Vector3(width, length, depth)
	mesh.left_to_right = apex
	Models._part(parent, mesh, colour, Vector3(at.x, depth * 0.5, at.y), Vector3(-90, 0, 0))


static func _trapezoid(parent: Node3D, colour: Color, top_width: float, hem_width: float, length: float, depth: float, at: Vector2) -> void:
	_box(parent, colour, Vector3(top_width, depth, length), at)
	var flare: float = (hem_width - top_width) * 0.5
	for side: float in SIDES:
		_triangle(parent, colour, flare, length, depth,
			at + Vector2(side * (top_width + flare) * 0.5, 0), 0.0 if side > 0.0 else 1.0)


static func _group(parent: Node3D, at: Vector2, bottom: float = 0.0, yaw: float = 0.0) -> Node3D:
	var result: Node3D = Node3D.new()
	result.position = Vector3(at.x, bottom, at.y)
	result.rotation_degrees.y = yaw
	parent.add_child(result)
	return result


static func _disc(parent: Node3D, colour: Color, at: Vector2, bottom: float, radius: float = BUTTON_RADIUS, metal: bool = false) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = DETAIL_DEPTH
	mesh.radial_segments = RADIAL_SEGMENTS
	var instance: MeshInstance3D = Models._part(parent, mesh, colour, Vector3(at.x, bottom + DETAIL_DEPTH * 0.5, at.y))
	if metal:
		var material: StandardMaterial3D = instance.material_override as StandardMaterial3D
		material.metallic = 0.35
		material.roughness = 0.4


static func _ring(parent: Node3D, colour: Color, at: Vector2, inner: float, outer: float, depth: float, bottom: float = 0.0, stretch: Vector2 = Vector2.ONE) -> void:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = TORUS_RINGS
	mesh.ring_segments = TORUS_SEGMENTS
	var instance: MeshInstance3D = Models._part(parent, mesh, colour, Vector3(at.x, bottom + depth * 0.5, at.y))
	instance.scale = Vector3(stretch.x, depth / (outer - inner), stretch.y)


static func _arc(parent: Node3D, colour: Color, at: Vector2, radii: Vector2, start_angle: float, end_angle: float, width: float, bottom: float) -> void:
	for index: int in ARC_STEPS:
		var first: float = lerpf(start_angle, end_angle, float(index) / float(ARC_STEPS))
		var last: float = lerpf(start_angle, end_angle, float(index + 1) / float(ARC_STEPS))
		var start: Vector2 = at + Vector2(cos(first) * radii.x, sin(first) * radii.y)
		var finish: Vector2 = at + Vector2(cos(last) * radii.x, sin(last) * radii.y)
		_stroke(parent, colour, start, finish, width, DETAIL_DEPTH, bottom)


## 아래 몸판과 분리된 어깨 조각이 실제 목 구멍을 남긴다.
## 민소매의 어깨 폭은 몸판보다 좁아 양옆 팔 구멍도 비워 둔다.
static func _torso(parent: Node3D, colour: Color, cut: Dictionary, rounded: bool, top: float = TOP_Z) -> void:
	var width: float = float(cut["width"])
	var shoulder: float = float(cut.get("shoulder", width))
	var length: float = float(cut["length"])
	var depth: float = float(cut["depth"])
	var neck: float = float(cut["neck"])
	var drop: float = float(cut["drop"])
	_box(parent, colour, Vector3(width, depth, length - drop), Vector2(0, top + (length + drop) * 0.5))
	if rounded:
		var row_length: float = drop / float(NECK_STEPS)
		for row: int in NECK_STEPS:
			var ratio: float = (float(row) + 0.5) / float(NECK_STEPS)
			var opening: float = neck * 0.5 * sqrt(1.0 - ratio * ratio)
			var panel_width: float = shoulder * 0.5 - opening
			for side: float in SIDES:
				_box(parent, colour, Vector3(panel_width, depth, row_length),
					Vector2(side * (opening + panel_width * 0.5), top + (float(row) + 0.5) * row_length))
	else:
		var side_width: float = (shoulder - neck) * 0.5
		for side: float in SIDES:
			_box(parent, colour, Vector3(side_width, depth, drop), Vector2(side * (neck + side_width) * 0.5, top + drop * 0.5))
			_triangle(parent, colour, neck * 0.5, drop, depth, Vector2(side * neck * 0.25, top + drop * 0.5), 1.0 if side > 0.0 else 0.0)


static func _ribbed_band(parent: Node3D, colour: Color, at: Vector2, width: float, length: float, bottom: float, yaw: float = 0.0) -> void:
	const RIB_PITCH: float = 0.028
	const RIB_RISE: float = 0.003
	var band: Node3D = _group(parent, at, bottom, yaw)
	_box(band, _shade(colour, -0.1), Vector3(width, DETAIL_DEPTH, length), Vector2.ZERO)
	var count: int = maxi(3, int(round(width / RIB_PITCH)))
	for rib: int in count:
		var x: float = -width * 0.5 + (float(rib) + 0.5) * width / float(count)
		_box(band, _shade(colour, 0.09), Vector3(DETAIL_WIDTH, DETAIL_DEPTH, length), Vector2(x, 0), RIB_RISE)


static func _sleeves(parent: Node3D, colour: Color, cut: Dictionary, ribbed: bool, top: float = TOP_Z) -> void:
	const LAYOUT: Dictionary = {"root_drop": 0.052, "end_drop": 0.17, "cuff_inset": 0.018, "rib_length": 0.04, "cuff_length": 0.035}
	var depth: float = float(cut["depth"])
	var width: float = float(cut["width"])
	var arm: float = float(cut["arm"])
	for side: float in SIDES:
		var start: Vector2 = Vector2(side * width * 0.42, top + float(LAYOUT["root_drop"]))
		var finish: Vector2 = Vector2(side * (width * 0.5 + float(cut["sleeve"])), top + float(LAYOUT["end_drop"]))
		_tapered(parent, colour, start, finish, arm, arm * 0.68, depth)
		var direction: Vector2 = (finish - start).normalized()
		var yaw: float = rad_to_deg(atan2(direction.x, direction.y))
		var cuff: Vector2 = finish - direction * float(LAYOUT["cuff_inset"])
		if ribbed:
			_ribbed_band(parent, colour, cuff, arm * 0.72, float(LAYOUT["rib_length"]), depth * 0.45, yaw)
		else:
			_box(parent, _shade(colour, -0.1), Vector3(arm * 0.72, DETAIL_DEPTH, float(LAYOUT["cuff_length"])), cuff, depth * 0.5, yaw)


static func _collar(parent: Node3D, colour: Color, neck: float, bottom: float, wide: bool = false, top: float = TOP_Z) -> void:
	const SIZES: Dictionary = {"plain": Vector2(0.05, 0.075), "wide": Vector2(0.075, 0.12)}
	const LAPEL_YAW: float = 18.0
	var size: Vector2 = SIZES["wide" if wide else "plain"]
	for side: float in SIDES:
		var flap: Node3D = _group(parent, Vector2(side * neck * 0.32, top + size.y * 0.42), bottom, side * -LAPEL_YAW)
		# 삼각 깃의 뾰족한 끝이 옷 아래쪽을 향한다.
		var mesh: PrismMesh = PrismMesh.new()
		mesh.size = Vector3(size.x, size.y, DETAIL_DEPTH)
		mesh.left_to_right = 0.5
		Models._part(flap, mesh, _shade(colour, 0.14), Vector3(0, DETAIL_DEPTH * 0.5, 0), Vector3(90, 0, 0))


static func _buttons(parent: Node3D, colour: Color, top: float, length: float, bottom: float, count: int = 5, rows: int = 1) -> void:
	const LAYOUT: Dictionary = {"row_spacing": 0.094, "placket_width": 0.025, "placket_extra": 0.025, "placket_sink": 0.008}
	for row: int in rows:
		var x: float = (float(row) - float(rows - 1) * 0.5) * float(LAYOUT["row_spacing"])
		if rows == 1:
			_box(parent, _shade(colour, -0.13), Vector3(float(LAYOUT["placket_width"]), DETAIL_DEPTH, length + float(LAYOUT["placket_extra"])), Vector2(x, top + length * 0.5), bottom - float(LAYOUT["placket_sink"]))
		for button: int in count:
			var z: float = top + length * float(button) / float(count - 1)
			_disc(parent, BUTTON_COLOUR, Vector2(x, z), bottom, BUTTON_RADIUS, true)


static func _zipper(parent: Node3D, at: Vector2, length: float, bottom: float) -> void:
	const LAYOUT: Dictionary = {"tape_width": 0.027, "tape_sink": 0.007, "teeth_sink": 0.004, "pull_inner": 0.006, "pull_outer": 0.019, "pull_rise": 0.007}
	_box(parent, DARK_COLOUR, Vector3(float(LAYOUT["tape_width"]), DETAIL_DEPTH, length), at, bottom - float(LAYOUT["tape_sink"]))
	_box(parent, STEEL_COLOUR, Vector3(DETAIL_WIDTH, DETAIL_DEPTH, length), at, bottom - float(LAYOUT["teeth_sink"]))
	_ring(parent, STEEL_COLOUR, at + Vector2(0, -length * 0.32), float(LAYOUT["pull_inner"]), float(LAYOUT["pull_outer"]), DETAIL_DEPTH, bottom + float(LAYOUT["pull_rise"]))


static func _pockets(parent: Node3D, colour: Color, spread: float, z: float, size: Vector2, bottom: float) -> void:
	const LAYOUT: Dictionary = {"flap_extra": 0.008, "flap_length": 0.018, "flap_rise": 0.009}
	for side: float in SIDES:
		_box(parent, _shade(colour, -0.1), Vector3(size.x, DETAIL_DEPTH, size.y), Vector2(side * spread, z), bottom)
		_box(parent, _shade(colour, 0.1), Vector3(size.x + float(LAYOUT["flap_extra"]), PATTERN_DEPTH, float(LAYOUT["flap_length"])),
			Vector2(side * spread, z - size.y * 0.34), bottom + float(LAYOUT["flap_rise"]))


static func _checks(parent: Node3D, colour: Color, width: float, length: float, top: float, bottom: float) -> void:
	const LAYOUT: Dictionary = {"vertical_width": 0.022, "vertical_sink": 0.002, "horizontal_width": 0.024, "horizontal_rise": 0.001}
	for column: int in 3:
		var x: float = (float(column) - 1.0) * width * 0.27
		_box(parent, _shade(colour, -0.19), Vector3(float(LAYOUT["vertical_width"]), PATTERN_DEPTH, length), Vector2(x, top + length * 0.5), bottom - float(LAYOUT["vertical_sink"]))
	for row: int in 3:
		var z: float = top + length * (float(row) + 0.5) / 3.0
		_box(parent, _shade(colour, 0.12), Vector3(width, PATTERN_DEPTH, float(LAYOUT["horizontal_width"])), Vector2(0, z), bottom + float(LAYOUT["horizontal_rise"]))


static func _knit(parent: Node3D, colour: Color, width: float, length: float, top: float, bottom: float, cable: bool) -> void:
	const LAYOUT: Dictionary = {"cable_bend": 0.018, "cable_width": 0.018, "cable_sink": 0.003, "wale_sink": 0.002}
	for column: int in 3:
		var x: float = (float(column) - 1.0) * width * 0.29
		if cable:
			for stitch: int in 5:
				var start_z: float = top + length * float(stitch) / 5.0
				var end_z: float = top + length * float(stitch + 1) / 5.0
				var bend: float = float(LAYOUT["cable_bend"]) * (1.0 if stitch % 2 == 0 else -1.0)
				_stroke(parent, _shade(colour, 0.12), Vector2(x - bend, start_z), Vector2(x + bend, end_z), float(LAYOUT["cable_width"]), DETAIL_DEPTH, bottom - float(LAYOUT["cable_sink"]))
		else:
			_stroke(parent, _shade(colour, 0.08), Vector2(x, top), Vector2(x, top + length), DETAIL_WIDTH, PATTERN_DEPTH, bottom - float(LAYOUT["wale_sink"]))


static func _quilts(parent: Node3D, colour: Color, width: float, length: float, top: float, bottom: float, rows: int) -> void:
	const LAYOUT: Dictionary = {"puff_width": 0.032, "puff_sink": 0.005, "seam_offset": 0.014, "seam_rise": 0.006}
	for row: int in rows:
		var z: float = top + (float(row) + 0.5) * length / float(rows)
		_stroke(parent, _shade(colour, 0.07), Vector2(-width * 0.45, z), Vector2(width * 0.45, z), float(LAYOUT["puff_width"]), DETAIL_DEPTH, bottom - float(LAYOUT["puff_sink"]))
		var seam_z: float = z + float(LAYOUT["seam_offset"])
		_stroke(parent, _shade(colour, 0.2), Vector2(-width * 0.45, seam_z), Vector2(width * 0.45, seam_z), DETAIL_WIDTH, PATTERN_DEPTH, bottom + float(LAYOUT["seam_rise"]))


static func _undershirt(root: Node3D, colour: Color, recipe: Dictionary) -> void:
	const LAYOUT: Dictionary = {
		"neck_radii": Vector2(0.0475, 0.14), "binding_bottom": 0.012,
		"hem_size": Vector3(0.23, 0.012, 0.028), "hem_at": Vector2(0, 0.106), "hem_bottom": 0.009,
		"knit_width": 0.18, "knit_length": 0.115, "knit_top": -0.035,
		"rib_at": Vector2(0, 0.104), "rib_length": 0.035,
	}
	var cut: Dictionary = CUTS["under"]
	_torso(root, colour, cut, true)
	_arc(root, _shade(colour, -0.13), Vector2(0, TOP_Z), LAYOUT["neck_radii"], 0, PI, DETAIL_WIDTH, float(LAYOUT["binding_bottom"]))
	_box(root, _shade(colour, -0.08), LAYOUT["hem_size"], LAYOUT["hem_at"], float(LAYOUT["hem_bottom"]))
	if String(recipe.get("pattern", "plain")) == "knit":
		_knit(root, colour, float(LAYOUT["knit_width"]), float(LAYOUT["knit_length"]), float(LAYOUT["knit_top"]), float(cut["depth"]), false)
		_ribbed_band(root, colour, LAYOUT["rib_at"], float(cut["width"]), float(LAYOUT["rib_length"]), float(LAYOUT["binding_bottom"]))


static func _shirt(root: Node3D, colour: Color, recipe: Dictionary) -> void:
	const LAYOUT: Dictionary = {
		"check_size": Vector2(0.238, 0.27), "check_top": -0.12,
		"knit_size": Vector2(0.2, 0.23), "knit_top": -0.1,
		"pocket_spread": 0.072, "pocket_z": -0.075, "pocket_size": Vector2(0.072, 0.07),
		"collar_rise": 0.001, "button_top": -0.105, "button_length": 0.23, "button_rise": 0.007,
		"hem_size": Vector3(0.25, 0.012, 0.022), "hem_at": Vector2(0, 0.15), "hem_bottom": 0.01,
	}
	var cut: Dictionary = CUTS["shirt"]
	var depth: float = float(cut["depth"])
	var check_size: Vector2 = LAYOUT["check_size"]
	var knit_size: Vector2 = LAYOUT["knit_size"]
	_torso(root, colour, cut, false)
	_sleeves(root, colour, cut, false)
	match String(recipe.get("pattern", "plain")):
		"check":
			_checks(root, colour, check_size.x, check_size.y, float(LAYOUT["check_top"]), depth)
		"knit":
			_knit(root, colour, knit_size.x, knit_size.y, float(LAYOUT["knit_top"]), depth, false)
	if bool(recipe.get("pockets", false)):
		_pockets(root, colour, float(LAYOUT["pocket_spread"]), float(LAYOUT["pocket_z"]), LAYOUT["pocket_size"], depth)
	_collar(root, colour, float(cut["neck"]), depth + float(LAYOUT["collar_rise"]))
	_buttons(root, colour, float(LAYOUT["button_top"]), float(LAYOUT["button_length"]), depth + float(LAYOUT["button_rise"]))
	_box(root, _shade(colour, -0.07), LAYOUT["hem_size"], LAYOUT["hem_at"], float(LAYOUT["hem_bottom"]))


static func _sweater(root: Node3D, colour: Color, recipe: Dictionary) -> void:
	const LAYOUT: Dictionary = {"neck_width": 0.022, "binding_bottom": 0.018, "rib_length": 0.04, "rib_inset": 0.02, "knit_inset": 0.05, "knit_length": 0.2, "knit_top": -0.085}
	var cut: Dictionary = CUTS[String(recipe.get("cut", "sweater"))]
	var width: float = float(cut["width"])
	_torso(root, colour, cut, true)
	_sleeves(root, colour, cut, true)
	_arc(root, _shade(colour, 0.12), Vector2(0, TOP_Z), Vector2(float(cut["neck"]) * 0.5, float(cut["drop"])), 0, PI, float(LAYOUT["neck_width"]), float(LAYOUT["binding_bottom"]))
	_ribbed_band(root, colour, Vector2(0, TOP_Z + float(cut["length"]) - float(LAYOUT["rib_inset"])), width, float(LAYOUT["rib_length"]), float(LAYOUT["binding_bottom"]))
	_knit(root, colour, width - float(LAYOUT["knit_inset"]), float(LAYOUT["knit_length"]), float(LAYOUT["knit_top"]), float(cut["depth"]), String(recipe["pattern"]) == "cable")


static func _outer(root: Node3D, colour: Color, recipe: Dictionary) -> void:
	const LAYOUT: Dictionary = {
		"check_clearance": 0.1, "check_drop": 0.09, "quilt_clearance": 0.13, "quilt_drop": 0.11,
		"hood_offset": Vector2(0, -0.048), "hood_inner": 0.049, "hood_outer": 0.093,
		"hood_depth": 0.025, "hood_stretch": Vector2(1, 1.22),
		"hood_tie_start": Vector2(0.062, 0.005), "hood_tie_end": Vector2(0.08, 0.12),
		"front_drop": 0.13, "front_clearance": 0.18, "button_rise": 0.006,
		"toggle_ring_at": -0.02, "toggle_inner": 0.008, "toggle_outer": 0.022,
		"toggle_size": Vector3(0.062, 0.012, 0.018), "toggle_x": 0.012, "toggle_rise": 0.005, "toggle_yaw": -12.0,
		"pocket_spread": 0.092, "pocket_inset": 0.078, "pocket_size": Vector2(0.095, 0.105),
		"belt_extra": 0.008, "belt_length": 0.035, "buckle_inner": 0.011, "buckle_outer": 0.025, "buckle_rise": 0.009,
		"reflector_z": [0.08, 0.29], "reflector_extra": 0.004, "reflector_length": 0.044, "reflector_rise": 0.003,
		"hem_length": 0.024, "hem_inset": 0.012,
	}
	var cut: Dictionary = CUTS[String(recipe["cut"])]
	var depth: float = float(cut["depth"])
	var width: float = float(cut["width"])
	var length: float = float(cut["length"])
	var hem: float = TOP_Z + length
	_torso(root, colour, cut, false)
	_sleeves(root, colour, cut, false)
	match String(recipe.get("pattern", "plain")):
		"check":
			_checks(root, colour, width * 0.95, length - float(LAYOUT["check_clearance"]), TOP_Z + float(LAYOUT["check_drop"]), depth)
		"quilt":
			_quilts(root, colour, width, length - float(LAYOUT["quilt_clearance"]), TOP_Z + float(LAYOUT["quilt_drop"]), depth, 7)
	if bool(recipe.get("hood", false)):
		var hood_offset: Vector2 = LAYOUT["hood_offset"]
		var hood_frame: Node3D = _group(root, Vector2(0, TOP_Z) + hood_offset)
		_ring(hood_frame, colour, Vector2.ZERO, float(LAYOUT["hood_inner"]), float(LAYOUT["hood_outer"]), float(LAYOUT["hood_depth"]), 0.0, LAYOUT["hood_stretch"])
		var tie_start: Vector2 = LAYOUT["hood_tie_start"]
		var tie_end: Vector2 = LAYOUT["hood_tie_end"]
		for side: float in SIDES:
			_stroke(root, _shade(colour, 0.15), Vector2(side * tie_start.x, TOP_Z + tie_start.y), Vector2(side * tie_end.x, TOP_Z + tie_end.y), DETAIL_WIDTH, DETAIL_DEPTH, depth)
	else:
		_collar(root, colour, float(cut["neck"]), depth, bool(recipe.get("wide_collar", false)))
	var front_top: float = TOP_Z + float(LAYOUT["front_drop"])
	var front_length: float = length - float(LAYOUT["front_clearance"])
	match String(recipe["front"]):
		"double":
			_buttons(root, colour, front_top, front_length, depth, 5, 2)
		"buttons":
			_buttons(root, colour, front_top, front_length, depth + float(LAYOUT["button_rise"]))
		"zip":
			_zipper(root, Vector2(0, front_top + front_length * 0.5), front_length, depth)
		"toggle":
			for toggle: int in 4:
				var z: float = front_top + front_length * float(toggle) / 3.0
				_ring(root, _shade(colour, -0.18), Vector2(float(LAYOUT["toggle_ring_at"]), z), float(LAYOUT["toggle_inner"]), float(LAYOUT["toggle_outer"]), DETAIL_DEPTH, depth)
				_box(root, BUTTON_COLOUR, LAYOUT["toggle_size"], Vector2(float(LAYOUT["toggle_x"]), z), depth + float(LAYOUT["toggle_rise"]), float(LAYOUT["toggle_yaw"]))
	if bool(recipe.get("pockets", false)):
		_pockets(root, colour, float(LAYOUT["pocket_spread"]), hem - float(LAYOUT["pocket_inset"]), LAYOUT["pocket_size"], depth)
	if bool(recipe.get("belt", false)):
		_box(root, _shade(colour, -0.13), Vector3(width + float(LAYOUT["belt_extra"]), DETAIL_DEPTH, float(LAYOUT["belt_length"])), Vector2(0, TOP_Z + length * 0.53), depth)
		_ring(root, BUTTON_COLOUR, Vector2(0, TOP_Z + length * 0.53), float(LAYOUT["buckle_inner"]), float(LAYOUT["buckle_outer"]), DETAIL_DEPTH, depth + float(LAYOUT["buckle_rise"]))
	if bool(recipe.get("reflectors", false)):
		for band_z: float in LAYOUT["reflector_z"]:
			_box(root, REFLECTOR_COLOUR, Vector3(width + float(LAYOUT["reflector_extra"]), DETAIL_DEPTH, float(LAYOUT["reflector_length"])), Vector2(0, band_z), depth + float(LAYOUT["reflector_rise"]))
	_box(root, _shade(colour, -0.08), Vector3(width, DETAIL_DEPTH, float(LAYOUT["hem_length"])), Vector2(0, hem - float(LAYOUT["hem_inset"])), depth * 0.45)


static func _vest(root: Node3D, colour: Color, recipe: Dictionary) -> void:
	const LAYOUT: Dictionary = {
		"arm_top": Vector2(0.1, -0.18), "arm_middle": Vector2(0.092, -0.1), "arm_bottom": Vector2(0.137, -0.055), "arm_rise": 0.015,
		"v_top_x": 0.052, "v_bottom": -0.068, "binding_width": 0.022, "binding_rise": 0.019,
		"rib_at": Vector2(0, 0.12), "rib_length": 0.04, "rib_rise": 0.018,
		"knit_width": 0.23, "knit_length": 0.125, "knit_top": -0.035,
		"quilt_width": 0.27, "quilt_length": 0.185, "quilt_top": -0.06,
		"zip_at": Vector2(0, 0.025), "zip_length": 0.2, "zip_rise": 0.026,
		"collar_size": Vector3(0.045, 0.028, 0.065), "collar_at": Vector2(0.047, -0.172), "collar_rise": 0.012, "collar_yaw": 20.0,
		"plate_size": Vector3(0.115, 0.036, 0.19), "plate_at": Vector2(0.067, 0.024), "plate_rise": 0.005,
		"strap_size": Vector3(0.055, 0.022, 0.13), "strap_at": Vector2(0.077, -0.125), "strap_rise": 0.015,
		"side_size": Vector3(0.085, 0.025, 0.035), "side_at": Vector2(0.153, 0.045), "side_rise": 0.008,
		"ring_at": Vector2(0.085, -0.135), "ring_inner": 0.009, "ring_outer": 0.024, "ring_rise": 0.038,
	}
	var cut: Dictionary = CUTS["vest"]
	var style: String = String(recipe["style"])
	var depth: float = float(cut["depth"])
	var arm_top: Vector2 = LAYOUT["arm_top"]
	var arm_middle: Vector2 = LAYOUT["arm_middle"]
	var arm_bottom: Vector2 = LAYOUT["arm_bottom"]
	_torso(root, colour, cut, style == "quilt")
	# 몸판보다 좁은 어깨와 안으로 들어간 팔 구멍의 가장자리.
	for side: float in SIDES:
		_stroke(root, _shade(colour, 0.08), Vector2(side * arm_top.x, arm_top.y), Vector2(side * arm_middle.x, arm_middle.y), DETAIL_WIDTH, DETAIL_DEPTH, float(LAYOUT["arm_rise"]))
		_stroke(root, _shade(colour, 0.08), Vector2(side * arm_middle.x, arm_middle.y), Vector2(side * arm_bottom.x, arm_bottom.y), DETAIL_WIDTH, DETAIL_DEPTH, float(LAYOUT["arm_rise"]))
	match style:
		"knit":
			for side: float in SIDES:
				_stroke(root, _shade(colour, 0.16), Vector2(side * float(LAYOUT["v_top_x"]), TOP_Z), Vector2(0, float(LAYOUT["v_bottom"])), float(LAYOUT["binding_width"]), DETAIL_DEPTH, float(LAYOUT["binding_rise"]))
			_ribbed_band(root, colour, LAYOUT["rib_at"], float(cut["width"]), float(LAYOUT["rib_length"]), float(LAYOUT["rib_rise"]))
			_knit(root, colour, float(LAYOUT["knit_width"]), float(LAYOUT["knit_length"]), float(LAYOUT["knit_top"]), depth, false)
		"quilt":
			_quilts(root, colour, float(LAYOUT["quilt_width"]), float(LAYOUT["quilt_length"]), float(LAYOUT["quilt_top"]), depth, 4)
			_zipper(root, LAYOUT["zip_at"], float(LAYOUT["zip_length"]), float(LAYOUT["zip_rise"]))
			var collar_at: Vector2 = LAYOUT["collar_at"]
			for side: float in SIDES:
				_box(root, _shade(colour, 0.12), LAYOUT["collar_size"], Vector2(side * collar_at.x, collar_at.y), float(LAYOUT["collar_rise"]), side * -float(LAYOUT["collar_yaw"]))
		"armor":
			var plate_at: Vector2 = LAYOUT["plate_at"]
			var strap_at: Vector2 = LAYOUT["strap_at"]
			var side_at: Vector2 = LAYOUT["side_at"]
			var ring_at: Vector2 = LAYOUT["ring_at"]
			for side: float in SIDES:
				_box(root, _shade(colour, -0.07), LAYOUT["plate_size"], Vector2(side * plate_at.x, plate_at.y), float(LAYOUT["plate_rise"]))
				_box(root, colour, LAYOUT["strap_size"], Vector2(side * strap_at.x, strap_at.y), float(LAYOUT["strap_rise"]))
				_box(root, _shade(colour, -0.16), LAYOUT["side_size"], Vector2(side * side_at.x, side_at.y), float(LAYOUT["side_rise"]))
				_ring(root, STEEL_COLOUR, Vector2(side * ring_at.x, ring_at.y), float(LAYOUT["ring_inner"]), float(LAYOUT["ring_outer"]), DETAIL_DEPTH, float(LAYOUT["ring_rise"]))


static func _legs(parent: Node3D, colour: Color, width: float, length: float, depth: float, top: float, wide: bool = false) -> void:
	const LAYOUT: Dictionary = {"hip_length": 0.1, "leg_drop": 0.065, "hem_length": 0.025, "hem_inset": 0.015, "hem_yaw": 8.0}
	var leg_width: float = width * (0.43 if wide else 0.36)
	_box(parent, colour, Vector3(width, depth, float(LAYOUT["hip_length"])), Vector2(0, top + float(LAYOUT["hip_length"]) * 0.5))
	for side: float in SIDES:
		_tapered(parent, colour, Vector2(side * width * 0.24, top + float(LAYOUT["leg_drop"])),
			Vector2(side * width * 0.46, top + length), leg_width, leg_width * 0.88, depth)
		_box(parent, _shade(colour, -0.07), Vector3(leg_width * 0.9, DETAIL_DEPTH, float(LAYOUT["hem_length"])), Vector2(side * width * 0.46, top + length - float(LAYOUT["hem_inset"])), depth * 0.5, side * float(LAYOUT["hem_yaw"]))


static func _waist(parent: Node3D, colour: Color, width: float, top: float, depth: float, cord: bool = false) -> void:
	const LAYOUT: Dictionary = {
		"band_extra": 0.015, "band_length": 0.045, "band_drop": 0.012, "band_rise": 0.005,
		"cord_tip": Vector2(0.043, 0.09), "cord_rise": 0.002,
		"loop_x": [-0.36, -0.16, 0.16, 0.36], "loop_size": Vector3(0.018, 0.012, 0.052),
		"fly_size": Vector3(0.02, 0.012, 0.105), "fly_drop": 0.067, "button_rise": 0.009,
	}
	var band_z: float = top + float(LAYOUT["band_drop"])
	_box(parent, _shade(colour, -0.12), Vector3(width + float(LAYOUT["band_extra"]), depth, float(LAYOUT["band_length"])), Vector2(0, band_z), float(LAYOUT["band_rise"]))
	if cord:
		_stroke(parent, BUTTON_COLOUR, Vector2(-width * 0.46, band_z), Vector2(width * 0.46, band_z), DETAIL_WIDTH, DETAIL_DEPTH, depth)
		var cord_tip: Vector2 = LAYOUT["cord_tip"]
		for side: float in SIDES:
			_stroke(parent, BUTTON_COLOUR, Vector2(0, band_z), Vector2(side * cord_tip.x, top + cord_tip.y), DETAIL_WIDTH, DETAIL_DEPTH, depth + float(LAYOUT["cord_rise"]))
	else:
		for loop_x: float in LAYOUT["loop_x"]:
			_box(parent, _shade(colour, 0.12), LAYOUT["loop_size"], Vector2(loop_x * width, band_z), depth)
		_box(parent, _shade(colour, -0.18), LAYOUT["fly_size"], Vector2(0, top + float(LAYOUT["fly_drop"])), depth)
		_disc(parent, BUTTON_COLOUR, Vector2(0, band_z), depth + float(LAYOUT["button_rise"]), BUTTON_RADIUS, true)


static func _trousers(root: Node3D, colour: Color, recipe: Dictionary) -> void:
	const LAYOUT: Dictionary = {
		"plain": Vector2(0.28, 0.43), "wide": Vector2(0.34, 0.46), "depth": 0.024, "top": -0.19,
		"knee_size": Vector3(0.087, 0.012, 0.105), "knee_at": Vector2(0.107, 0.085), "knee_yaw": 8.0,
		"crease_start": Vector2(0.08, -0.08), "crease_end": Vector2(0.126, 0.21), "crease_bottom": 0.022,
	}
	var wide: bool = bool(recipe.get("wide", false))
	var size: Vector2 = LAYOUT["wide" if wide else "plain"]
	var depth: float = float(LAYOUT["depth"])
	var top: float = float(LAYOUT["top"])
	_legs(root, colour, size.x, size.y, depth, top, wide)
	_waist(root, colour, size.x, top, depth, bool(recipe.get("cord", false)))
	if bool(recipe.get("knees", false)):
		var knee_at: Vector2 = LAYOUT["knee_at"]
		for side: float in SIDES:
			_box(root, _shade(colour, 0.16), LAYOUT["knee_size"], Vector2(side * knee_at.x, knee_at.y), depth, side * float(LAYOUT["knee_yaw"]))
	if bool(recipe.get("crease", false)):
		var crease_start: Vector2 = LAYOUT["crease_start"]
		var crease_end: Vector2 = LAYOUT["crease_end"]
		for side: float in SIDES:
			_stroke(root, _shade(colour, 0.09), Vector2(side * crease_start.x, crease_start.y), Vector2(side * crease_end.x, crease_end.y), DETAIL_WIDTH, PATTERN_DEPTH, float(LAYOUT["crease_bottom"]))


static func _bib(root: Node3D, colour: Color) -> void:
	const LAYOUT: Dictionary = {
		"width": 0.29, "leg_length": 0.43, "depth": 0.024, "waist_top": -0.08,
		"bib_size": Vector3(0.2, 0.024, 0.17), "bib_at": Vector2(0, -0.16),
		"strap_size": Vector3(0.034, 0.024, 0.13), "strap_at": Vector2(0.068, -0.29),
		"ring_z": -0.236, "ring_inner": 0.008, "ring_outer": 0.023,
		"pocket_size": Vector3(0.105, 0.012, 0.075), "pocket_bottom": 0.023,
	}
	var depth: float = float(LAYOUT["depth"])
	var bib_at: Vector2 = LAYOUT["bib_at"]
	var strap_at: Vector2 = LAYOUT["strap_at"]
	_legs(root, colour, float(LAYOUT["width"]), float(LAYOUT["leg_length"]), depth, float(LAYOUT["waist_top"]))
	_waist(root, colour, float(LAYOUT["width"]), float(LAYOUT["waist_top"]), depth)
	_box(root, colour, LAYOUT["bib_size"], bib_at)
	for side: float in SIDES:
		_box(root, _shade(colour, -0.08), LAYOUT["strap_size"], Vector2(side * strap_at.x, strap_at.y))
		_ring(root, STEEL_COLOUR, Vector2(side * strap_at.x, float(LAYOUT["ring_z"])), float(LAYOUT["ring_inner"]), float(LAYOUT["ring_outer"]), DETAIL_DEPTH, depth)
	_box(root, _shade(colour, 0.1), LAYOUT["pocket_size"], bib_at, float(LAYOUT["pocket_bottom"]))


static func _drawers(root: Node3D, colour: Color) -> void:
	const LAYOUT: Dictionary = {
		"waist_width": 0.27, "hip_width": 0.31, "hip_length": 0.105, "depth": 0.018, "hip_at": Vector2(0, -0.035),
		"leg_top_width": 0.125, "leg_hem_width": 0.14, "leg_length": 0.082, "leg_at": Vector2(0.088, 0.052),
		"hem_size": Vector3(0.14, 0.012, 0.018), "hem_z": 0.086, "hem_bottom": 0.009,
		"elastic_at": Vector2(0, -0.083), "elastic_width": 0.277, "elastic_length": 0.04, "elastic_bottom": 0.01,
	}
	# 긴 막대 대신 짧고 넓은 사다리꼴 두 다리, 가운데는 실제 빈 틈.
	var leg_at: Vector2 = LAYOUT["leg_at"]
	var depth: float = float(LAYOUT["depth"])
	_trapezoid(root, colour, float(LAYOUT["waist_width"]), float(LAYOUT["hip_width"]), float(LAYOUT["hip_length"]), depth, LAYOUT["hip_at"])
	for side: float in SIDES:
		_trapezoid(root, colour, float(LAYOUT["leg_top_width"]), float(LAYOUT["leg_hem_width"]), float(LAYOUT["leg_length"]), depth, Vector2(side * leg_at.x, leg_at.y))
		_box(root, _shade(colour, -0.1), LAYOUT["hem_size"], Vector2(side * leg_at.x, float(LAYOUT["hem_z"])), float(LAYOUT["hem_bottom"]))
	_ribbed_band(root, colour, LAYOUT["elastic_at"], float(LAYOUT["elastic_width"]), float(LAYOUT["elastic_length"]), float(LAYOUT["elastic_bottom"]))


static func _long_johns(root: Node3D, colour: Color) -> void:
	const LAYOUT: Dictionary = {
		"top": -0.3, "leg_length": 0.4, "waist_top": -0.025,
		"neck_radii": Vector2(0.04, 0.055), "binding_bottom": 0.012,
		"button_top": -0.217, "button_length": 0.21, "button_bottom": 0.023,
	}
	var cut: Dictionary = CUTS["long_johns"]
	var top: float = float(LAYOUT["top"])
	_torso(root, colour, cut, true, top)
	_sleeves(root, colour, cut, true, top)
	_legs(root, colour, float(cut["width"]), float(LAYOUT["leg_length"]), float(cut["depth"]), float(LAYOUT["waist_top"]))
	_arc(root, _shade(colour, -0.12), Vector2(0, top), LAYOUT["neck_radii"], 0, PI, DETAIL_WIDTH, float(LAYOUT["binding_bottom"]))
	_buttons(root, colour, float(LAYOUT["button_top"]), float(LAYOUT["button_length"]), float(LAYOUT["button_bottom"]))


static func _coverall(root: Node3D, colour: Color) -> void:
	const LAYOUT: Dictionary = {
		"top": -0.32, "leg_length": 0.43, "waist_top": -0.055,
		"zip_at": Vector2(0, -0.11), "zip_length": 0.31, "zip_bottom": 0.026,
		"pocket_spread": 0.077, "pocket_z": -0.168, "pocket_size": Vector2(0.067, 0.068),
		"waist_size": Vector3(0.275, 0.012, 0.026), "waist_at": Vector2(0, -0.018),
	}
	var cut: Dictionary = CUTS["coverall"]
	var top: float = float(LAYOUT["top"])
	var depth: float = float(cut["depth"])
	_torso(root, colour, cut, false, top)
	_sleeves(root, colour, cut, false, top)
	_legs(root, colour, float(cut["width"]), float(LAYOUT["leg_length"]), depth, float(LAYOUT["waist_top"]))
	_collar(root, colour, float(cut["neck"]), depth, false, top)
	_zipper(root, LAYOUT["zip_at"], float(LAYOUT["zip_length"]), float(LAYOUT["zip_bottom"]))
	_pockets(root, colour, float(LAYOUT["pocket_spread"]), float(LAYOUT["pocket_z"]), LAYOUT["pocket_size"], depth)
	_box(root, _shade(colour, -0.09), LAYOUT["waist_size"], LAYOUT["waist_at"], depth)


static func _dress(root: Node3D, colour: Color) -> void:
	const LAYOUT: Dictionary = {
		"top": -0.29, "neck_radii": Vector2(0.045, 0.055), "binding_bottom": 0.016,
		"waist_width": 0.18, "hem_width": 0.44, "skirt_length": 0.38, "skirt_at": Vector2(0, 0.12),
		"waist_at": Vector2(0, -0.058), "waist_band_width": 0.21, "waist_band_length": 0.036,
		"pleat_start_step": 0.031, "pleat_start_z": -0.04, "pleat_end_step": 0.083, "pleat_end_z": 0.295, "pleat_bottom": 0.021,
		"hem_size": Vector3(0.43, 0.012, 0.026), "hem_at": Vector2(0, 0.3), "hem_bottom": 0.012,
	}
	var cut: Dictionary = CUTS["dress"]
	var top: float = float(LAYOUT["top"])
	_torso(root, colour, cut, true, top)
	_sleeves(root, colour, cut, false, top)
	_arc(root, _shade(colour, 0.13), Vector2(0, top), LAYOUT["neck_radii"], 0, PI, DETAIL_WIDTH, float(LAYOUT["binding_bottom"]))
	_trapezoid(root, colour, float(LAYOUT["waist_width"]), float(LAYOUT["hem_width"]), float(LAYOUT["skirt_length"]), float(cut["depth"]), LAYOUT["skirt_at"])
	_ribbed_band(root, colour, LAYOUT["waist_at"], float(LAYOUT["waist_band_width"]), float(LAYOUT["waist_band_length"]), float(LAYOUT["binding_bottom"]))
	for pleat: int in 5:
		var spread: float = float(pleat) - 2.0
		_stroke(root, _shade(colour, 0.1), Vector2(spread * float(LAYOUT["pleat_start_step"]), float(LAYOUT["pleat_start_z"])), Vector2(spread * float(LAYOUT["pleat_end_step"]), float(LAYOUT["pleat_end_z"])), DETAIL_WIDTH, PATTERN_DEPTH, float(LAYOUT["pleat_bottom"]))
	_box(root, _shade(colour, -0.1), LAYOUT["hem_size"], LAYOUT["hem_at"], float(LAYOUT["hem_bottom"]))


static func _socks(root: Node3D, colour: Color, recipe: Dictionary) -> void:
	const LAYOUT: Dictionary = {
		"thin_width": 0.067, "thick_width": 0.085, "thin_depth": 0.018, "thick_depth": 0.028,
		"pair_origin": Vector2(-0.085, 0), "pair_step": Vector2(0.16, 0.055), "pair_rise": 0.008, "yaw": -6.0,
		"ankle_top": Vector2(-0.025, -0.14), "heel": Vector2(-0.025, 0.055), "toe": Vector2(0.08, 0.055),
		"rib_at": Vector2(-0.025, -0.125), "rib_extra": 0.008, "rib_length": 0.054,
		"toe_patch_start": Vector2(0.058, 0.055), "toe_patch_end": Vector2(0.087, 0.055), "toe_patch_extra": 0.002,
	}
	var thick: bool = bool(recipe.get("thick", false))
	var width: float = float(LAYOUT["thick_width" if thick else "thin_width"])
	var depth: float = float(LAYOUT["thick_depth" if thick else "thin_depth"])
	var pair_origin: Vector2 = LAYOUT["pair_origin"]
	var pair_step: Vector2 = LAYOUT["pair_step"]
	for pair: int in 2:
		var sock: Node3D = _group(root, pair_origin + pair_step * float(pair), float(pair) * float(LAYOUT["pair_rise"]), float(LAYOUT["yaw"]))
		_stroke(sock, colour, LAYOUT["ankle_top"], LAYOUT["heel"], width, depth)
		_stroke(sock, colour, LAYOUT["heel"], LAYOUT["toe"], width, depth)
		_ribbed_band(sock, colour, LAYOUT["rib_at"], width + float(LAYOUT["rib_extra"]), float(LAYOUT["rib_length"]), depth * 0.65)
		if thick:
			_stroke(sock, _shade(colour, -0.12), LAYOUT["toe_patch_start"], LAYOUT["toe_patch_end"], width + float(LAYOUT["toe_patch_extra"]), PATTERN_DEPTH, depth * 0.8)


static func _laces(parent: Node3D, centre: Vector2, count: int, along: Vector2, across: Vector2) -> void:
	const LAYOUT: Dictionary = {"eye_radius": 0.008, "eye_bottom": 0.028, "lace_bottom": 0.035}
	for lace: int in count:
		var at: Vector2 = centre + along * float(lace)
		_disc(parent, DARK_COLOUR, at - across * 0.5, float(LAYOUT["eye_bottom"]), float(LAYOUT["eye_radius"]))
		_disc(parent, DARK_COLOUR, at + across * 0.5, float(LAYOUT["eye_bottom"]), float(LAYOUT["eye_radius"]))
		_stroke(parent, STEEL_COLOUR, at - across * 0.5, at + across * 0.5 + along * 0.35, DETAIL_WIDTH, PATTERN_DEPTH, float(LAYOUT["lace_bottom"]))


static func _footwear(root: Node3D, colour: Color, recipe: Dictionary) -> void:
	const LAYOUT: Dictionary = {
		"pair_origin": Vector2(-0.1, -0.04), "pair_step": Vector2(0.19, 0.105), "pair_rise": 0.012, "yaw": -8.0,
		"vamp_size": Vector3(0.275, 0.032, 0.105), "vamp_at": Vector2(0.005, 0.095), "vamp_bottom": 0.003,
		"shaft_x": -0.082, "shaft_base_z": 0.105, "depth": 0.032,
		"sole_start": Vector2(-0.125, 0.145), "sole_end": Vector2(0.125, 0.145), "sole_thin": 0.021, "sole_thick": 0.029, "sole_depth": 0.028,
		"heel_size": Vector3(0.064, 0.028, 0.048), "heel_at": Vector2(-0.096, 0.144),
		"cuff_extra": 0.008, "cuff_length": 0.026, "cuff_inset": 0.01, "cuff_bottom": 0.022,
		"vamp_laces": Vector2(-0.025, 0.074), "vamp_lace_step": Vector2(0.028, 0), "vamp_lace_span": Vector2(0, 0.052),
		"shaft_laces": Vector2(-0.083, -0.085), "shaft_lace_step": Vector2(0, 0.035), "shaft_lace_span": Vector2(0.062, 0),
		"tread_size": Vector3(0.028, 0.012, 0.022), "tread_origin": Vector2(-0.095, 0.16), "tread_step": 0.047, "tread_bottom": 0.008,
		"fur_size": Vector3(0.029, 0.026, 0.052), "fur_start_x": -0.15, "fur_step": 0.0225, "fur_inset": 0.008, "fur_bottom": 0.019,
	}
	var style: String = String(recipe["style"])
	var cut: Dictionary = SHOE_CUTS[style]
	var shaft: float = float(cut["shaft"])
	var width: float = float(cut["width"])
	var pair_origin: Vector2 = LAYOUT["pair_origin"]
	var pair_step: Vector2 = LAYOUT["pair_step"]
	for pair: int in 2:
		# L자 옆면을 위로 눕힌 한 켤레. 긴 장화 목이 발끝을 가리지 않는다.
		var shoe: Node3D = _group(root, pair_origin + pair_step * float(pair), float(pair) * float(LAYOUT["pair_rise"]), float(LAYOUT["yaw"]))
		_oval(shoe, colour, LAYOUT["vamp_size"], LAYOUT["vamp_at"], float(LAYOUT["vamp_bottom"]))
		_tapered(shoe, colour, Vector2(float(LAYOUT["shaft_x"]), float(LAYOUT["shaft_base_z"])), Vector2(float(LAYOUT["shaft_x"]), -shaft), width * 0.9, width, float(LAYOUT["depth"]))
		_stroke(shoe, DARK_COLOUR, LAYOUT["sole_start"], LAYOUT["sole_end"], float(LAYOUT["sole_thin" if style == "shoe" else "sole_thick"]), float(LAYOUT["sole_depth"]))
		_box(shoe, _shade(colour, -0.17), LAYOUT["heel_size"], LAYOUT["heel_at"])
		_box(shoe, _shade(colour, 0.13), Vector3(width + float(LAYOUT["cuff_extra"]), DETAIL_DEPTH, float(LAYOUT["cuff_length"])), Vector2(float(LAYOUT["shaft_x"]), -shaft + float(LAYOUT["cuff_inset"])), float(LAYOUT["cuff_bottom"]))
		if int(cut["laces"]) > 0:
			_laces(shoe, LAYOUT["vamp_laces"], int(cut["laces"]), LAYOUT["vamp_lace_step"], LAYOUT["vamp_lace_span"])
		if style == "work":
			_laces(shoe, LAYOUT["shaft_laces"], 3, LAYOUT["shaft_lace_step"], LAYOUT["shaft_lace_span"])
			var tread_origin: Vector2 = LAYOUT["tread_origin"]
			for tread: int in 5:
				_box(shoe, _shade(colour, -0.2), LAYOUT["tread_size"], tread_origin + Vector2(float(tread) * float(LAYOUT["tread_step"]), 0), float(LAYOUT["tread_bottom"]))
		elif style == "fur":
			for tuft: int in 7:
				_oval(shoe, FUR_COLOUR, LAYOUT["fur_size"], Vector2(float(LAYOUT["fur_start_x"]) + float(tuft) * float(LAYOUT["fur_step"]), -shaft + float(LAYOUT["fur_inset"])), float(LAYOUT["fur_bottom"]))


static func _gloves(root: Node3D, colour: Color, recipe: Dictionary) -> void:
	const LAYOUT: Dictionary = {
		"pair_origin": Vector2(-0.054, 0), "pair_step": Vector2(0.108, 0.045), "pair_rise": 0.026, "yaw": 7.0,
		"mitten_start": Vector2(0, -0.035), "mitten_end": Vector2(0, 0.065), "mitten_width": 0.12, "mitten_depth": 0.03,
		"palm_size": Vector3(0.12, 0.024, 0.115), "palm_at": Vector2(0, 0.05),
		"finger_root_z": -0.005, "finger_width": 0.022, "depth": 0.024,
		"thumb_start": Vector2(0.05, 0.055), "thumb_end": Vector2(0.098, 0.004), "thumb_width": 0.035,
		"cuff_at": Vector2(0, 0.117), "cuff_width": 0.091, "cuff_length": 0.043, "cuff_bottom": 0.011,
		"knit_width": 0.088, "knit_length": 0.055, "knit_top": 0.02, "knit_bottom": 0.025,
		"seam_step": 0.027, "seam_top": 0.018, "seam_end": 0.07, "seam_bottom": 0.022,
	}
	var mitten: bool = String(recipe.get("style", "glove")) == "mitten"
	var pair_origin: Vector2 = LAYOUT["pair_origin"]
	var pair_step: Vector2 = LAYOUT["pair_step"]
	var thumb_start: Vector2 = LAYOUT["thumb_start"]
	var thumb_end: Vector2 = LAYOUT["thumb_end"]
	for pair: int in 2:
		var side: float = -1.0 if pair == 0 else 1.0
		var glove: Node3D = _group(root, pair_origin + pair_step * float(pair), float(pair) * float(LAYOUT["pair_rise"]), side * float(LAYOUT["yaw"]))
		if mitten:
			_stroke(glove, colour, LAYOUT["mitten_start"], LAYOUT["mitten_end"], float(LAYOUT["mitten_width"]), float(LAYOUT["mitten_depth"]))
		else:
			_box(glove, colour, LAYOUT["palm_size"], LAYOUT["palm_at"])
			for finger: int in FINGER_X.size():
				_stroke(glove, colour, Vector2(FINGER_X[finger], float(LAYOUT["finger_root_z"])), Vector2(FINGER_X[finger], FINGER_TIPS[finger]), float(LAYOUT["finger_width"]), float(LAYOUT["depth"]))
		_stroke(glove, colour, Vector2(side * thumb_start.x, thumb_start.y), Vector2(side * thumb_end.x, thumb_end.y), float(LAYOUT["thumb_width"]), float(LAYOUT["depth"]))
		_ribbed_band(glove, colour, LAYOUT["cuff_at"], float(LAYOUT["cuff_width"]), float(LAYOUT["cuff_length"]), float(LAYOUT["cuff_bottom"]))
		if String(recipe.get("pattern", "plain")) == "knit":
			_knit(glove, colour, float(LAYOUT["knit_width"]), float(LAYOUT["knit_length"]), float(LAYOUT["knit_top"]), float(LAYOUT["knit_bottom"]), false)
		elif bool(recipe.get("seams", false)):
			for seam: int in 3:
				var x: float = (float(seam) - 1.0) * float(LAYOUT["seam_step"])
				_stroke(glove, _shade(colour, 0.1), Vector2(x, float(LAYOUT["seam_top"])), Vector2(x, float(LAYOUT["seam_end"])), DETAIL_WIDTH, PATTERN_DEPTH, float(LAYOUT["seam_bottom"]))


static func _hat(root: Node3D, colour: Color, recipe: Dictionary) -> void:
	const LAYOUT: Dictionary = {
		"cap_radius": 0.125, "cap_height": 0.24, "cap_bottom": 0.025,
		"cap_band_size": Vector3(0.25, 0.03, 0.22), "brim_size": Vector3(0.265, 0.026, 0.175), "brim_at": Vector2(0, 0.125), "brim_bottom": 0.005,
		"check_size": Vector2(0.18, 0.07), "check_top": 0.11, "check_bottom": 0.028, "button_radius": 0.014,
		"crown_size": Vector3(0.24, 0.16, 0.22), "crown_bottom": 0.015,
		"fold_radius": 0.1265, "fold_height": 0.06, "fold_z": 0.008, "fold_stretch": 0.91,
		"rib_radius": 0.007, "rib_height": 0.048, "rib_bottom": 0.006, "rib_count": 16,
		"pompom_size": Vector3(0.057, 0.057, 0.057), "pompom_at": Vector2(0, -0.012), "pompom_bottom": 0.166,
		"fur_size": Vector3(0.21, 0.024, 0.045), "fur_at": Vector2(0, 0.092), "fur_bottom": 0.025,
		"ear_top": Vector2(0.116, 0.015), "ear_end": Vector2(0.13, 0.145), "ear_width": 0.069, "ear_depth": 0.027,
		"tie_end": Vector2(0.106, 0.235), "tie_bottom": 0.007,
	}
	var style: String = String(recipe["style"])
	if style == "cap":
		var crown: SphereMesh = SphereMesh.new()
		crown.radius = float(LAYOUT["cap_radius"])
		crown.height = float(LAYOUT["cap_height"])
		crown.is_hemisphere = true
		crown.radial_segments = RADIAL_SEGMENTS
		crown.rings = SPHERE_RINGS
		var crown_bounds: AABB = crown.get_aabb()
		var crown_y: float = float(LAYOUT["cap_bottom"]) - crown_bounds.position.y
		Models._part(root, crown, colour, Vector3(0, crown_y, 0))
		_oval(root, _shade(colour, -0.09), LAYOUT["cap_band_size"], Vector2.ZERO)
		_oval(root, colour, LAYOUT["brim_size"], LAYOUT["brim_at"], float(LAYOUT["brim_bottom"]))
		var check_size: Vector2 = LAYOUT["check_size"]
		_checks(root, colour, check_size.x, check_size.y, float(LAYOUT["check_top"]), float(LAYOUT["check_bottom"]))
		_disc(root, _shade(colour, 0.13), Vector2.ZERO, float(LAYOUT["cap_bottom"]) + crown_bounds.size.y, float(LAYOUT["button_radius"]))
		return
	_oval(root, colour, LAYOUT["crown_size"], Vector2.ZERO, float(LAYOUT["crown_bottom"]))
	if style == "knit":
		# 접힌 단과 골지는 모자 둘레를 따라 붙여 공중에 뜬 직사각형 끝을 남기지 않는다.
		var fold: CylinderMesh = CylinderMesh.new()
		fold.top_radius = float(LAYOUT["fold_radius"])
		fold.bottom_radius = float(LAYOUT["fold_radius"])
		fold.height = float(LAYOUT["fold_height"])
		fold.radial_segments = RADIAL_SEGMENTS
		var fold_instance: MeshInstance3D = Models._part(root, fold, _shade(colour, -0.07), Vector3(0, fold.height * 0.5, float(LAYOUT["fold_z"])))
		fold_instance.scale.z = float(LAYOUT["fold_stretch"])
		var rib: CylinderMesh = CylinderMesh.new()
		rib.top_radius = float(LAYOUT["rib_radius"])
		rib.bottom_radius = float(LAYOUT["rib_radius"])
		rib.height = float(LAYOUT["rib_height"])
		rib.radial_segments = RADIAL_SEGMENTS
		for rib_index: int in int(LAYOUT["rib_count"]):
			var angle: float = TAU * float(rib_index) / float(LAYOUT["rib_count"])
			Models._part(root, rib, _shade(colour, 0.09), Vector3(cos(angle) * fold.top_radius,
				float(LAYOUT["rib_bottom"]) + rib.height * 0.5, float(LAYOUT["fold_z"]) + sin(angle) * fold.top_radius * float(LAYOUT["fold_stretch"])))
		_oval(root, _shade(colour, 0.16), LAYOUT["pompom_size"], LAYOUT["pompom_at"], float(LAYOUT["pompom_bottom"]))
	else:
		_box(root, FUR_COLOUR, LAYOUT["fur_size"], LAYOUT["fur_at"], float(LAYOUT["fur_bottom"]))
		var ear_top: Vector2 = LAYOUT["ear_top"]
		var ear_end: Vector2 = LAYOUT["ear_end"]
		var tie_end: Vector2 = LAYOUT["tie_end"]
		for side: float in SIDES:
			_stroke(root, colour, Vector2(side * ear_top.x, ear_top.y), Vector2(side * ear_end.x, ear_end.y), float(LAYOUT["ear_width"]), float(LAYOUT["ear_depth"]))
			_stroke(root, _shade(colour, 0.12), Vector2(side * ear_end.x, ear_end.y), Vector2(side * tie_end.x, tie_end.y), DETAIL_WIDTH, DETAIL_DEPTH, float(LAYOUT["tie_bottom"]))


static func _hood(root: Node3D, colour: Color, recipe: Dictionary) -> void:
	const LAYOUT: Dictionary = {
		"face_at": Vector2(0, -0.055), "face_inner": 0.068, "face_outer": 0.112, "face_depth": 0.026, "face_stretch": Vector2(1, 1.25),
		"cape_top_width": 0.15, "cape_hem_width": 0.34, "cape_length": 0.145, "cape_depth": 0.024, "cape_at": Vector2(0, 0.112),
		"binding_radii": Vector2(0.076, 0.095), "binding_bottom": 0.019,
		"tie_start": Vector2(0.078, 0.035), "tie_end": Vector2(0.108, 0.22), "tie_bottom": 0.018,
		"rib_at": Vector2(0, 0.164), "rib_width": 0.3, "rib_length": 0.039, "rib_bottom": 0.017,
	}
	# 얼굴 자리는 칠한 검은 원판이 아닌 빈 구멍이며, 뒤에 둥근 통을 두지 않는다.
	_ring(root, colour, LAYOUT["face_at"], float(LAYOUT["face_inner"]), float(LAYOUT["face_outer"]), float(LAYOUT["face_depth"]), 0.0, LAYOUT["face_stretch"])
	_trapezoid(root, colour, float(LAYOUT["cape_top_width"]), float(LAYOUT["cape_hem_width"]), float(LAYOUT["cape_length"]), float(LAYOUT["cape_depth"]), LAYOUT["cape_at"])
	_arc(root, _shade(colour, 0.15), LAYOUT["face_at"], LAYOUT["binding_radii"], PI, TAU, DETAIL_WIDTH, float(LAYOUT["binding_bottom"]))
	var tie_start: Vector2 = LAYOUT["tie_start"]
	var tie_end: Vector2 = LAYOUT["tie_end"]
	for side: float in SIDES:
		_stroke(root, _shade(colour, 0.18), Vector2(side * tie_start.x, tie_start.y), Vector2(side * tie_end.x, tie_end.y), DETAIL_WIDTH, DETAIL_DEPTH, float(LAYOUT["tie_bottom"]))
	if String(recipe.get("pattern", "plain")) == "knit":
		_ribbed_band(root, colour, LAYOUT["rib_at"], float(LAYOUT["rib_width"]), float(LAYOUT["rib_length"]), float(LAYOUT["rib_bottom"]))


static func _scarf(root: Node3D, colour: Color, recipe: Dictionary) -> void:
	const LAYOUT: Dictionary = {"thin_width": 0.07, "thick_width": 0.105, "thin_depth": 0.018, "thick_depth": 0.032, "stripe_width": 0.021, "stripe_sink": 0.002, "tassel_length": 0.048}
	var thick: bool = bool(recipe.get("thick", false))
	var width: float = float(LAYOUT["thick_width" if thick else "thin_width"])
	var depth: float = float(LAYOUT["thick_depth" if thick else "thin_depth"])
	for segment: int in SCARF_PATH.size() - 1:
		_stroke(root, colour, SCARF_PATH[segment], SCARF_PATH[segment + 1], width, depth)
	for end_index: int in [0, SCARF_PATH.size() - 1]:
		var neighbour: int = 1 if end_index == 0 else SCARF_PATH.size() - 2
		var end: Vector2 = SCARF_PATH[end_index]
		var outward: Vector2 = (end - SCARF_PATH[neighbour]).normalized()
		var across: Vector2 = Vector2(-outward.y, outward.x)
		_stroke(root, _shade(colour, 0.16), end - across * width * 0.42, end + across * width * 0.42, float(LAYOUT["stripe_width"]), PATTERN_DEPTH, depth - float(LAYOUT["stripe_sink"]))
		for tassel: int in 4:
			var start: Vector2 = end + outward * width * 0.28 + across * (float(tassel) - 1.5) * width * 0.23
			_stroke(root, colour, start, start + outward * float(LAYOUT["tassel_length"]), DETAIL_WIDTH, DETAIL_DEPTH, depth * 0.2)


static func _mask(root: Node3D, colour: Color) -> void:
	const LAYOUT: Dictionary = {
		"cloth_size": Vector3(0.235, 0.035, 0.125), "loop_x": 0.137, "loop_inner": 0.031, "loop_outer": 0.047,
		"loop_depth": 0.014, "loop_stretch": Vector2(0.8, 1.12),
		"fold_z": [-0.027, 0.027], "fold_half_width": 0.075, "fold_bottom": 0.026,
	}
	# 납작한 렌즈 모양은 가운데만 살짝 솟아 휜 천을 보인다.
	_oval(root, colour, LAYOUT["cloth_size"], Vector2.ZERO)
	for side: float in SIDES:
		_ring(root, _shade(colour, 0.12), Vector2(side * float(LAYOUT["loop_x"]), 0), float(LAYOUT["loop_inner"]), float(LAYOUT["loop_outer"]), float(LAYOUT["loop_depth"]), 0.0, LAYOUT["loop_stretch"])
	for fold_z: float in LAYOUT["fold_z"]:
		_stroke(root, _shade(colour, 0.1), Vector2(-float(LAYOUT["fold_half_width"]), fold_z), Vector2(float(LAYOUT["fold_half_width"]), fold_z), DETAIL_WIDTH, PATTERN_DEPTH, float(LAYOUT["fold_bottom"]))
