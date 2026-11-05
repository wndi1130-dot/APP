extends RefCounted
## Small models of the things first found at a stop, for their window icons
## (decision 550) and later the ground. CC0 Kenney Food Kit / Survival Kit
## models (models/items/kenney_*, License.txt there) with their one colour map
## re-tinted per thing, and plain shapes where no CC0 model fits (sack, carton,
## papers). Colours are muted and cool, as the snow screen needs.

const FOOD: String = "res://models/items/kenney_food/"
const SURVIVAL: String = "res://models/items/kenney_survival/"

## id -> how it is made. "glb" + "tint" rules (hue ranges of the colour map,
## lo > hi wraps past red), "scale", or "shape" for the plain-shape builders.
const RECIPES: Dictionary = {
	"can_beans": {"glb": FOOD + "can.glb", "tint": [
		{"h": [0.95, 0.08], "s": [0.45, 1.0], "to_h": 0.065, "to_s": 0.52, "v": 0.82}]},
	"can_meat": {"glb": FOOD + "can-small.glb", "tint": [
		{"h": [0.62, 0.82], "s": [0.35, 1.0], "to_h": 0.985, "to_s": 0.55, "v": 0.72}]},
	"can_dented": {"glb": FOOD + "soda-can-crushed.glb", "tint": [
		{"h": [0.95, 0.08], "s": [0.45, 1.0], "to_h": 0.2, "to_s": 0.32, "v": 0.62}]},
	"hardtack": {"glb": FOOD + "chocolate.glb", "scale": Vector3(0.82, 1.6, 1.25), "tint": [
		{"h": [0.0, 0.12], "s": [0.3, 1.0], "to_h": 0.1, "to_s": 0.3, "v": 1.42}]},
	"sugar": {"glb": FOOD + "bag.glb", "scale": Vector3(1.0, 0.72, 1.0), "tint": [
		{"h": [0.0, 0.12], "s": [0.2, 1.0], "to_h": 0.11, "to_s": 0.07, "v": 1.0}]},
	"oats": {"shape": "sack"},
	"jar_jam": {"glb": FOOD + "honey.glb", "tint": [
		{"h": [0.0, 0.07], "s": [0.55, 1.0], "to_h": 0.975, "to_s": 0.6, "v": 0.62}]},
	"coffee": {"glb": FOOD + "can.glb", "scale": Vector3(1.18, 0.8, 1.18), "tint": [
		{"h": [0.95, 0.08], "s": [0.45, 1.0], "to_h": 0.075, "to_s": 0.42, "v": 0.42}]},
	"cigarettes": {"shape": "carton"},
	"antiseptic": {"glb": SURVIVAL + "bottle-large.glb", "tint": [
		{"h": [0.0, 0.1], "s": [0.3, 1.0], "to_h": 0.07, "to_s": 0.72, "v": 0.5}]},
	"painkillers": {"glb": FOOD + "shaker-salt.glb", "tint": [
		{"h": [0.0, 0.1], "s": [0.3, 1.0], "to_h": 0.085, "to_s": 0.8, "v": 1.2},
		{"h": [0.5, 0.75], "s": [0.0, 0.35], "to_h": 0.1, "to_s": 0.04, "v": 1.7}]},
	# The bedroll read as a white lump (결정 561 시안): a folded wool rag instead.
	"cloth": {"shape": "folded_cloth"},
	"bottle_spirit": {"glb": FOOD + "wine-red.glb", "tint": [
		{"h": [0.95, 0.08], "s": [0.45, 1.0], "to_h": 0.12, "to_s": 0.32, "v": 0.95}]},
	"bandage": {"glb": SURVIVAL + "bedroll-packed.glb", "scale": Vector3(0.7, 1.15, 1.15), "tint": [
		{"h": [0.04, 0.1], "s": [0.3, 1.0], "to_h": 0.08, "to_s": 0.28, "v": 0.82},
		{"h": [0.92, 0.04], "s": [0.3, 1.0], "to_h": 0.1, "to_s": 0.05, "v": 1.08}]},
	"document": {"shape": "papers"},
	# 겉모습 2판 A (11-04): plain shapes for the things with no CC0 model in hand.
	"wood": {"shape": "planks"},
	"scrap": {"shape": "scrap"},
	"flare": {"shape": "flare"},
	"can_empty": {"shape": "tin_open"},
	"medkit": {"shape": "medkit"},
}


static func ids() -> Array:
	return RECIPES.keys()


## A new node holding the thing's model at the origin, foot on y = 0; null
## for an id with no recipe.
static func build(id: String) -> Node3D:
	if not RECIPES.has(id):
		return null
	var recipe: Dictionary = RECIPES[id]
	var root := Node3D.new()
	root.name = id
	if recipe.has("shape"):
		match String(recipe["shape"]):
			"sack":
				_sack(root)
			"carton":
				_carton(root)
			"papers":
				_papers(root)
			"planks":
				_planks(root)
			"scrap":
				_scrap(root)
			"flare":
				_flare(root)
			"tin_open":
				_tin_open(root)
			"medkit":
				_medkit(root)
			"folded_cloth":
				_folded_cloth(root)
		return root
	var scene: PackedScene = load(String(recipe["glb"])) as PackedScene
	if scene == null:
		root.free()
		return null
	var model: Node = scene.instantiate()
	root.add_child(model)
	if recipe.has("scale") and model is Node3D:
		(model as Node3D).scale = recipe["scale"]
	var map_path: String = String(recipe["glb"]).get_base_dir().path_join("Textures/colormap.png")
	var material := _tinted(map_path, recipe.get("tint", []))
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface: int in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(surface, material)
	return root


## The kit's colour map with each rule's hue range moved to its hue and
## saturation; value keeps the map's shading, times "v".
static func _tinted(map_path: String, rules: Array) -> StandardMaterial3D:
	var image := Image.load_from_file(ProjectSettings.globalize_path(map_path))
	image.convert(Image.FORMAT_RGBA8)
	if not rules.is_empty():
		for y: int in image.get_height():
			for x: int in image.get_width():
				var c: Color = image.get_pixel(x, y)
				for rule: Dictionary in rules:
					if _in(c.h, rule["h"]) and c.s >= float(rule["s"][0]) and c.s <= float(rule["s"][1]):
						c = Color.from_hsv(float(rule["to_h"]), float(rule["to_s"]), clampf(c.v * float(rule["v"]), 0.0, 1.0), c.a)
						break
				image.set_pixel(x, y, c)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.85
	return material


static func _in(h: float, span: Array) -> bool:
	var lo: float = float(span[0])
	var hi: float = float(span[1])
	return h >= lo and h <= hi if lo <= hi else (h >= lo or h <= hi)


static func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


static func _part(parent: Node3D, mesh: Mesh, color: Color, at: Vector3, turn_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = _flat(color)
	part.position = at
	part.rotation_degrees = turn_deg
	parent.add_child(part)
	return part


## A burlap sack tied at the neck.
static func _sack(root: Node3D) -> void:
	var burlap := Color("8b7656")
	var body := CylinderMesh.new()
	body.bottom_radius = 0.16
	body.top_radius = 0.125
	body.height = 0.26
	body.radial_segments = 9
	body.rings = 1
	_part(root, body, burlap, Vector3(0, 0.13, 0))
	var shoulder := SphereMesh.new()
	shoulder.radius = 0.126
	shoulder.height = 0.13
	shoulder.radial_segments = 9
	shoulder.rings = 3
	_part(root, shoulder, burlap.darkened(0.04), Vector3(0, 0.26, 0))
	var neck := CylinderMesh.new()
	neck.bottom_radius = 0.045
	neck.top_radius = 0.04
	neck.height = 0.04
	neck.radial_segments = 8
	_part(root, neck, Color("5b4a35"), Vector3(0, 0.335, 0))
	var tuft := CylinderMesh.new()
	tuft.bottom_radius = 0.035
	tuft.top_radius = 0.075
	tuft.height = 0.07
	tuft.radial_segments = 7
	_part(root, tuft, burlap.lightened(0.06), Vector3(0, 0.39, 0))
	var seam := BoxMesh.new()
	seam.size = Vector3(0.012, 0.22, 0.012)
	_part(root, seam, burlap.darkened(0.25), Vector3(0, 0.14, 0.152), Vector3(-8, 0, 0))


## A carton of cigarettes: a long flat box, a dark red band and a thin gilt line.
static func _carton(root: Node3D) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.34, 0.07, 0.14)
	_part(root, box, Color("cfc9bb"), Vector3(0, 0.035, 0))
	var band := BoxMesh.new()
	band.size = Vector3(0.11, 0.072, 0.142)
	_part(root, band, Color("7d2a27"), Vector3(0.09, 0.035, 0))
	var gilt := BoxMesh.new()
	gilt.size = Vector3(0.012, 0.073, 0.143)
	_part(root, gilt, Color("a38d55"), Vector3(0.027, 0.035, 0))


## A few loose sheets, the top one written on and stamped.
static func _papers(root: Node3D) -> void:
	var sheet := BoxMesh.new()
	sheet.size = Vector3(0.21, 0.004, 0.28)
	var tones: Array[Color] = [Color("bfb59a"), Color("cfc6ab"), Color("ddd5bd")]
	var turns: Array[float] = [-11.0, 6.0, -2.0]
	for i: int in 3:
		_part(root, sheet, tones[i], Vector3(0.01 * (i - 1), 0.002 + 0.0045 * i, 0.008 * (1 - i)), Vector3(0, turns[i], 0))
	var top := Node3D.new()
	top.position = Vector3(0, 0.0135, 0)
	top.rotation_degrees = Vector3(0, turns[2], 0)
	root.add_child(top)
	var line := BoxMesh.new()
	line.size = Vector3(0.15, 0.001, 0.008)
	for k: int in 6:
		var width: float = 0.15 if k % 3 != 2 else 0.09
		var part := _part(top, line, Color("4b4a46"), Vector3(-0.015 + (0.15 - width) * -0.5, 0, -0.09 + 0.03 * k))
		part.scale = Vector3(width / 0.15, 1, 1)
	var stamp := CylinderMesh.new()
	stamp.top_radius = 0.025
	stamp.bottom_radius = 0.025
	stamp.height = 0.001
	stamp.radial_segments = 12
	_part(top, stamp, Color("6e2e2a"), Vector3(0.055, 0.0005, 0.095))


## Three short boards tied with a cord, the ends showing paler grain.
static func _planks(root: Node3D) -> void:
	var tones: Array[Color] = [Color("6b4d33"), Color("80603f"), Color("735538")]
	var board := BoxMesh.new()
	board.size = Vector3(0.36, 0.034, 0.075)
	for i: int in 3:
		var at := Vector3(0.012 * (i - 1), 0.017 + 0.036 * i, 0.082 * (i - 1) * 0.55)
		_part(root, board, tones[i], at, Vector3(0, 4.0 * (i - 1), 0))
		var end := BoxMesh.new()
		end.size = Vector3(0.004, 0.03, 0.07)
		_part(root, end, Color("a8885e"), at + Vector3(0.182, 0, 0), Vector3(0, 4.0 * (i - 1), 0))
	var cord := BoxMesh.new()
	cord.size = Vector3(0.016, 0.118, 0.17)
	_part(root, cord, Color("4a443c"), Vector3(-0.08, 0.055, 0))


## A bent piece of corrugated sheet with two bolts: rust over grey.
static func _scrap(root: Node3D) -> void:
	var sheet := Node3D.new()
	sheet.rotation_degrees = Vector3(0, 18, 12)
	root.add_child(sheet)
	var strip := BoxMesh.new()
	strip.size = Vector3(0.3, 0.006, 0.042)
	for k: int in 6:
		var color: Color = Color("6f767c") if k % 3 != 1 else Color("8a4b2e")
		_part(sheet, strip, color, Vector3(0, 0.03 + (0.012 if k % 2 == 0 else 0.0), -0.1 + 0.04 * k), Vector3(14.0 if k % 2 == 0 else -14.0, 0, 0))
	var bolt := CylinderMesh.new()
	bolt.top_radius = 0.016
	bolt.bottom_radius = 0.016
	bolt.height = 0.05
	bolt.radial_segments = 6
	_part(root, bolt, Color("4a5058"), Vector3(0.13, 0.025, 0.12), Vector3(0, 0, 90))
	_part(root, bolt, Color("56483c"), Vector3(-0.12, 0.022, 0.13), Vector3(90, 30, 0))


## A road flare: a dark red tube, a black cap and a pale striker end, lying aslant.
static func _flare(root: Node3D) -> void:
	var stick := Node3D.new()
	stick.rotation_degrees = Vector3(0, 30, 90)
	stick.position = Vector3(0, 0.032, 0)
	root.add_child(stick)
	var tube := CylinderMesh.new()
	tube.top_radius = 0.03
	tube.bottom_radius = 0.03
	tube.height = 0.26
	tube.radial_segments = 10
	_part(stick, tube, Color("8e3328"), Vector3.ZERO)
	var band := CylinderMesh.new()
	band.top_radius = 0.031
	band.bottom_radius = 0.031
	band.height = 0.03
	band.radial_segments = 10
	_part(stick, band, Color("cfc4a8"), Vector3(0, -0.06, 0))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.033
	cap.bottom_radius = 0.033
	cap.height = 0.05
	cap.radial_segments = 10
	_part(stick, cap, Color("26292d"), Vector3(0, 0.15, 0))
	var wick := CylinderMesh.new()
	wick.top_radius = 0.012
	wick.bottom_radius = 0.018
	wick.height = 0.025
	wick.radial_segments = 8
	_part(stick, wick, Color("b8aa86"), Vector3(0, -0.14, 0))


## An empty tin with its lid cut most of the way round and bent back.
static func _tin_open(root: Node3D) -> void:
	var tin := Color("8f989e")
	var body := CylinderMesh.new()
	body.top_radius = 0.09
	body.bottom_radius = 0.09
	body.height = 0.2
	body.radial_segments = 14
	_part(root, body, tin, Vector3(0, 0.1, 0))
	for y: float in [0.03, 0.17]:
		var rib := CylinderMesh.new()
		rib.top_radius = 0.093
		rib.bottom_radius = 0.093
		rib.height = 0.01
		rib.radial_segments = 14
		_part(root, rib, tin.darkened(0.18), Vector3(0, y, 0))
	var inside := CylinderMesh.new()
	inside.top_radius = 0.082
	inside.bottom_radius = 0.082
	inside.height = 0.004
	inside.radial_segments = 14
	_part(root, inside, Color("2f353b"), Vector3(0, 0.2, 0))
	var lid := CylinderMesh.new()
	lid.top_radius = 0.088
	lid.bottom_radius = 0.088
	lid.height = 0.006
	lid.radial_segments = 14
	_part(root, lid, tin.lightened(0.12), Vector3(0, 0.255, -0.085), Vector3(-62, 0, 0))
	var rust := BoxMesh.new()
	rust.size = Vector3(0.03, 0.05, 0.004)
	_part(root, rust, Color("8a4b2e"), Vector3(0.05, 0.06, 0.077), Vector3(0, 32, 0))


## A first-aid tin: a dull olive box with a pale band, a handle and a latch — no cross.
static func _medkit(root: Node3D) -> void:
	var olive := Color("5f6448")
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.16, 0.19)
	_part(root, box, olive, Vector3(0, 0.08, 0))
	var lid := BoxMesh.new()
	lid.size = Vector3(0.306, 0.018, 0.196)
	_part(root, lid, olive.lightened(0.08), Vector3(0, 0.152, 0))
	var band := BoxMesh.new()
	band.size = Vector3(0.302, 0.045, 0.192)
	_part(root, band, Color("cbc2a6"), Vector3(0, 0.085, 0))
	var latch := BoxMesh.new()
	latch.size = Vector3(0.04, 0.035, 0.012)
	_part(root, latch, Color("3b3d36"), Vector3(0, 0.13, 0.1))
	var grip := BoxMesh.new()
	grip.size = Vector3(0.12, 0.016, 0.02)
	_part(root, grip, Color("2e3033"), Vector3(0, 0.2, 0))
	var post := BoxMesh.new()
	post.size = Vector3(0.014, 0.04, 0.02)
	_part(root, post, Color("2e3033"), Vector3(-0.055, 0.178, 0))
	_part(root, post, Color("2e3033"), Vector3(0.055, 0.178, 0))


## A rag of faded wool folded in three, its top layer a little askew, a dull red
## stripe across and a fringe of loose threads drooping off the top layer's end in
## the wool's own colour — soft, not a box (dark sticks low down read as a plug's pins).
static func _folded_cloth(root: Node3D) -> void:
	var wool: Array[Color] = [Color("5f5447"), Color("74675a"), Color("8a7b66")]
	var layer := BoxMesh.new()
	layer.size = Vector3(0.34, 0.035, 0.22)
	var turns: Array[float] = [3.0, -4.0, 7.0]
	var top: Node3D = null
	for i: int in 3:
		var fold := Node3D.new()
		fold.position = Vector3(0.008 * (i - 1), 0.018 + 0.034 * i, -0.006 * i)
		fold.rotation_degrees = Vector3(0, turns[i], 0)
		root.add_child(fold)
		top = fold
		_part(fold, layer, wool[i], Vector3.ZERO)
		# the rounded edge where the cloth turns under, on the front
		var edge := CylinderMesh.new()
		edge.top_radius = 0.0175
		edge.bottom_radius = 0.0175
		edge.height = 0.34
		edge.radial_segments = 8
		_part(fold, edge, wool[i].darkened(0.08), Vector3(0, 0, 0.11), Vector3(0, 0, 90))
		var stripe := BoxMesh.new()
		stripe.size = Vector3(0.045, 0.036, 0.222)
		_part(fold, stripe, Color("7d4436"), Vector3(-0.04, 0.0005, 0))
	var lengths: Array[float] = [0.042, 0.05, 0.036, 0.048, 0.04, 0.052, 0.038]
	for k: int in lengths.size():
		var thread := BoxMesh.new()
		thread.size = Vector3(lengths[k], 0.007, 0.007)
		_part(top, thread, wool[2].lightened(0.06), Vector3(0.17 + lengths[k] * 0.45, -0.004, -0.09 + 0.03 * k), Vector3(0, -6.0 + 2.0 * k, -24.0))
