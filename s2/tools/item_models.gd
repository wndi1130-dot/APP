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
	# The kit's fish is orange; a frozen one is a cold silver-blue.
	"it_fish": {"glb": SURVIVAL + "fish.glb", "tint": [
		{"h": [0.0, 0.2], "s": [0.25, 1.0], "to_h": 0.56, "to_s": 0.26, "v": 0.62}]},
	"document": {"shape": "papers"},
	# 겉모습 2판 A (11-04): plain shapes for the things with no CC0 model in hand.
	"wood": {"shape": "planks"},
	"scrap": {"shape": "scrap"},
	"flare": {"shape": "flare"},
	"can_empty": {"shape": "tin_open"},
	"medkit": {"shape": "medkit"},
	"it_apple": {"shape": "apple"},
	"it_apple_wilted": {"shape": "apple_wilted"},
	"it_meat": {"shape": "meat"},
	"it_meat_bad": {"shape": "meat_bad"},
	"it_hare": {"shape": "hare"},
	"it_bread_moldy": {"shape": "bread_moldy"},
	"it_tube": {"shape": "tube"},
	"it_toilet_paper": {"shape": "toilet_paper"},
	"it_soap": {"shape": "soap"},
	"it_child_clothes": {"shape": "child_clothes"},
	"it_old_clothes": {"shape": "old_clothes"},
	"it_razor": {"shape": "razor"},
	"gear": {"shape": "gears"},
	"it_nails": {"shape": "nails"},
	"it_opener": {"shape": "opener"},
	"it_fuel": {"shape": "fuel"},
	"it_spring": {"shape": "spring"},
	"it_record": {"shape": "record"},
	"it_violin": {"shape": "violin"},
	"ammo_pistol": {"shape": "ammo_pistol"},
	"ammo_shell": {"shape": "ammo_shell"},
	"it_bottle_broken": {"shape": "bottle_broken"},
	"it_stake": {"shape": "stake"},
	"pack": {"shape": "pack"},
	"it_wire": {"shape": "wire"},
	"it_syrup": {"shape": "syrup"},
	"clock": {"shape": "clock"},
	"it_pocket_watch": {"shape": "pocket_watch"},
	"it_sewing_kit": {"shape": "sewing_kit"},
	"it_needle": {"shape": "needle"},
	"it_doctor_box": {"shape": "doctor_box"},
	# The herbal's line icon is "book", which is also the plain book's id: its own name.
	"herbal_book": {"shape": "book"},
	"it_saline": {"shape": "saline"},
	"it_toy": {"shape": "teddy"},
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
			"apple":
				_apple(root)
			"apple_wilted":
				_apple_wilted(root)
			"meat":
				_meat(root)
			"meat_bad":
				_meat_bad(root)
			"hare":
				_hare(root)
			"bread_moldy":
				_bread_moldy(root)
			"tube":
				_tube(root)
			"toilet_paper":
				_toilet_paper(root)
			"soap":
				_soap(root)
			"child_clothes":
				_child_clothes(root)
			"old_clothes":
				_old_clothes(root)
			"razor":
				_razor(root)
			"gears":
				_gears(root)
			"nails":
				_nails(root)
			"opener":
				_opener(root)
			"fuel":
				_fuel(root)
			"spring":
				_spring(root)
			"record":
				_record(root)
			"violin":
				_violin(root)
			"ammo_pistol":
				_ammo_pistol(root)
			"ammo_shell":
				_ammo_shell(root)
			"bottle_broken":
				_bottle_broken(root)
			"stake":
				_stake(root)
			"pack":
				_pack(root)
			"wire":
				_wire(root)
			"syrup":
				_syrup(root)
			"clock":
				_clock(root)
			"pocket_watch":
				_pocket_watch(root)
			"sewing_kit":
				_sewing_kit(root)
			"needle":
				_needle(root)
			"doctor_box":
				_doctor_box(root)
			"book":
				_book(root)
			"saline":
				_saline(root)
			"teddy":
				_teddy(root)
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


## A slightly flattened faded red apple, a short stalk and one broad leaf.
static func _apple(root: Node3D) -> void:
	var fruit: SphereMesh = SphereMesh.new()
	fruit.radius = 0.113
	fruit.height = 0.195
	fruit.radial_segments = 16
	fruit.rings = 8
	var stalk: CylinderMesh = CylinderMesh.new()
	stalk.top_radius = 0.011
	stalk.bottom_radius = 0.011
	stalk.height = 0.055
	stalk.radial_segments = 8
	var leaf: PrismMesh = PrismMesh.new()
	leaf.size = Vector3(0.079, 0.047, 0.014)

	var fruit_part_1: MeshInstance3D = _part(root, fruit, Color("a3645d"), Vector3(0, 0.0975, 0))
	fruit_part_1.scale = Vector3(1, 1, 0.94)
	_part(root, stalk, Color("706349"), Vector3(0.005, 0.211, 0), Vector3(0, 0, -16))
	_part(root, leaf, Color("7c8b70"), Vector3(0.046, 0.227, -0.012), Vector3(90, -20, -14))


## A lopsided shrivelled apple made of uneven lobes, with broad brown bruises.
static func _apple_wilted(root: Node3D) -> void:
	var core: SphereMesh = SphereMesh.new()
	core.radius = 0.091
	core.height = 0.169
	core.radial_segments = 16
	core.rings = 8
	var lobe: SphereMesh = SphereMesh.new()
	lobe.radius = 0.044
	lobe.height = 0.127
	lobe.radial_segments = 16
	lobe.rings = 8
	var bruise: SphereMesh = SphereMesh.new()
	bruise.radius = 0.029
	bruise.height = 0.012
	bruise.radial_segments = 16
	bruise.rings = 8
	var stalk: CylinderMesh = CylinderMesh.new()
	stalk.top_radius = 0.01
	stalk.bottom_radius = 0.01
	stalk.height = 0.046
	stalk.radial_segments = 8

	var core_part_1: MeshInstance3D = _part(root, core, Color("8b5b49"), Vector3(0, 0.09798, 0), Vector3(0, 0, -9))
	core_part_1.scale = Vector3(1.02, 1, 0.95)
	_part(root, lobe, Color("805746"), Vector3(-0.062, 0.08248, 0.015), Vector3(0, 0, 8))
	var lobe_part_1: MeshInstance3D = _part(root, lobe, Color("805746"), Vector3(0.06, 0.09648, -0.017), Vector3(0, 0, 8))
	lobe_part_1.scale = Vector3(0.9, 1, 0.9)
	var bruise_part_1: MeshInstance3D = _part(root, bruise, Color("6b4d3e"), Vector3(0.03, 0.17748, 0.018), Vector3(0, 0, -12))
	bruise_part_1.scale = Vector3(1.1, 1, 0.8)
	_part(root, bruise, Color("6b4d3e"), Vector3(-0.071, 0.11948, 0.058), Vector3(52, 0, 26))
	_part(root, stalk, Color("68583f"), Vector3(0.011, 0.19848, -0.01), Vector3(0, 0, 22))


## A frozen red cut of meat with thick pale fat seams and a broad frost patch.
static func _meat(root: Node3D) -> void:
	var cut: SphereMesh = SphereMesh.new()
	cut.radius = 0.136
	cut.height = 0.115
	cut.radial_segments = 16
	cut.rings = 8
	var lobe: SphereMesh = SphereMesh.new()
	lobe.radius = 0.077
	lobe.height = 0.097
	lobe.radial_segments = 16
	lobe.rings = 8
	var fat: CapsuleMesh = CapsuleMesh.new()
	fat.radius = 0.013
	fat.height = 0.21
	fat.radial_segments = 12
	fat.rings = 6
	var patch: SphereMesh = SphereMesh.new()
	patch.radius = 0.048
	patch.height = 0.012
	patch.radial_segments = 16
	patch.rings = 8

	var cut_part_1: MeshInstance3D = _part(root, cut, Color("804840"), Vector3(-0.024, 0.068949, 0), Vector3(0, -10, 0))
	cut_part_1.scale = Vector3(1, 1, 0.78)
	var lobe_part_1: MeshInstance3D = _part(root, lobe, Color("8b5046"), Vector3(0.096, 0.063449, 0.014), Vector3(0, 0, 12))
	lobe_part_1.scale = Vector3(1, 1, 0.93)
	_part(root, fat, Color("c5b696"), Vector3(-0.01, 0.116449, 0.018), Vector3(0, -12, 90))
	_part(root, fat, Color("c5b696"), Vector3(-0.038, 0.102449, -0.057), Vector3(0, 18, 90))
	var patch_part_1: MeshInstance3D = _part(root, patch, Color("c4cbc3"), Vector3(-0.048, 0.127449, -0.012))
	patch_part_1.scale = Vector3(1.25, 1, 0.7)
	var patch_part_2: MeshInstance3D = _part(root, patch, Color("c4cbc3"), Vector3(0.074, 0.110449, 0.038), Vector3(0, 0, 12))
	patch_part_2.scale = Vector3(0.7, 1, 0.7)


## The same meat silhouette, discoloured grey green with dark red spoilage.
static func _meat_bad(root: Node3D) -> void:
	var cut: SphereMesh = SphereMesh.new()
	cut.radius = 0.136
	cut.height = 0.115
	cut.radial_segments = 16
	cut.rings = 8
	var lobe: SphereMesh = SphereMesh.new()
	lobe.radius = 0.077
	lobe.height = 0.097
	lobe.radial_segments = 16
	lobe.rings = 8
	var fat: CapsuleMesh = CapsuleMesh.new()
	fat.radius = 0.013
	fat.height = 0.21
	fat.radial_segments = 12
	fat.rings = 6
	var patch: SphereMesh = SphereMesh.new()
	patch.radius = 0.048
	patch.height = 0.012
	patch.radial_segments = 16
	patch.rings = 8

	var cut_part_1: MeshInstance3D = _part(root, cut, Color("707755"), Vector3(-0.024, 0.068949, 0), Vector3(0, -10, 0))
	cut_part_1.scale = Vector3(1, 1, 0.78)
	var lobe_part_1: MeshInstance3D = _part(root, lobe, Color("666e4d"), Vector3(0.096, 0.063449, 0.014), Vector3(0, 0, 12))
	lobe_part_1.scale = Vector3(1, 1, 0.93)
	_part(root, fat, Color("8b9372"), Vector3(-0.01, 0.116449, 0.018), Vector3(0, -12, 90))
	_part(root, fat, Color("8b9372"), Vector3(-0.038, 0.102449, -0.057), Vector3(0, 18, 90))
	var patch_part_1: MeshInstance3D = _part(root, patch, Color("633b3d"), Vector3(-0.048, 0.127449, -0.012))
	patch_part_1.scale = Vector3(1.25, 1, 0.7)
	var patch_part_2: MeshInstance3D = _part(root, patch, Color("633b3d"), Vector3(0.074, 0.110449, 0.038), Vector3(0, 0, 12))
	patch_part_2.scale = Vector3(0.7, 1, 0.7)


## A crouched side-on hare: flattened round body, raised head, long ears, folded haunch and small forepaws.
static func _hare(root: Node3D) -> void:
	var body: SphereMesh = SphereMesh.new()
	body.radius = 0.1
	body.height = 0.15
	body.radial_segments = 16
	body.rings = 8
	var head: SphereMesh = SphereMesh.new()
	head.radius = 0.047
	head.height = 0.09
	head.radial_segments = 16
	head.rings = 8
	var ear: CapsuleMesh = CapsuleMesh.new()
	ear.radius = 0.015
	ear.height = 0.1
	ear.radial_segments = 12
	ear.rings = 6
	var inner_ear: CapsuleMesh = CapsuleMesh.new()
	inner_ear.radius = 0.006
	inner_ear.height = 0.078
	inner_ear.radial_segments = 12
	inner_ear.rings = 6
	var haunch: SphereMesh = SphereMesh.new()
	haunch.radius = 0.075
	haunch.height = 0.11
	haunch.radial_segments = 16
	haunch.rings = 8
	var rear_paw: CapsuleMesh = CapsuleMesh.new()
	rear_paw.radius = 0.025
	rear_paw.height = 0.11
	rear_paw.radial_segments = 12
	rear_paw.rings = 6
	var far_rear_paw: CapsuleMesh = CapsuleMesh.new()
	far_rear_paw.radius = 0.023
	far_rear_paw.height = 0.095
	far_rear_paw.radial_segments = 12
	far_rear_paw.rings = 6
	var front_leg: CapsuleMesh = CapsuleMesh.new()
	front_leg.radius = 0.015
	front_leg.height = 0.09
	front_leg.radial_segments = 12
	front_leg.rings = 6
	var far_front_leg: CapsuleMesh = CapsuleMesh.new()
	far_front_leg.radius = 0.014
	far_front_leg.height = 0.08
	far_front_leg.radial_segments = 12
	far_front_leg.rings = 6
	var front_paw: CapsuleMesh = CapsuleMesh.new()
	front_paw.radius = 0.018
	front_paw.height = 0.085
	front_paw.radial_segments = 12
	front_paw.rings = 6
	var far_front_paw: CapsuleMesh = CapsuleMesh.new()
	far_front_paw.radius = 0.016
	far_front_paw.height = 0.065
	far_front_paw.radial_segments = 12
	far_front_paw.rings = 6
	var tail: SphereMesh = SphereMesh.new()
	tail.radius = 0.024
	tail.height = 0.048
	tail.radial_segments = 16
	tail.rings = 8
	var muzzle: SphereMesh = SphereMesh.new()
	muzzle.radius = 0.018
	muzzle.height = 0.03
	muzzle.radial_segments = 16
	muzzle.rings = 8
	var nose: SphereMesh = SphereMesh.new()
	nose.radius = 0.008
	nose.height = 0.016
	nose.radial_segments = 16
	nose.rings = 8
	var frost_sheet: SphereMesh = SphereMesh.new()
	frost_sheet.radius = 0.048
	frost_sheet.height = 0.012
	frost_sheet.radial_segments = 16
	frost_sheet.rings = 8

	var body_part_1: MeshInstance3D = _part(root, body, Color("796a53"), Vector3(0, 0.09, -0.025))
	body_part_1.scale = Vector3(0.78, 1, 1.05)
	_part(root, head, Color("89745a"), Vector3(0.01, 0.17, 0.095))
	_part(root, ear, Color("796b55"), Vector3(0.028, 0.245, 0.08), Vector3(-20, 0, 0))
	_part(root, ear, Color("796b55"), Vector3(-0.02, 0.238, 0.069), Vector3(-35, 0, 0))
	_part(root, inner_ear, Color("996b64"), Vector3(0.04, 0.245, 0.08), Vector3(-20, 0, 0))
	_part(root, inner_ear, Color("996b64"), Vector3(-0.008, 0.238, 0.069), Vector3(-35, 0, 0))
	var haunch_part_1: MeshInstance3D = _part(root, haunch, Color("826f54"), Vector3(0.032, 0.062, -0.06))
	haunch_part_1.scale = Vector3(1, 1, 0.85)
	_part(root, rear_paw, Color("796a53"), Vector3(0.05, 0.025, -0.04), Vector3(90, 0, 0))
	_part(root, far_rear_paw, Color("796a53"), Vector3(-0.045, 0.024, -0.055), Vector3(90, 0, 0))
	_part(root, front_leg, Color("796a53"), Vector3(0.043, 0.055, 0.06))
	_part(root, far_front_leg, Color("796a53"), Vector3(-0.04, 0.06, 0.043))
	_part(root, front_paw, Color("8d785b"), Vector3(0.043, 0.018, 0.09), Vector3(90, 0, 0))
	_part(root, far_front_paw, Color("8d785b"), Vector3(-0.04, 0.025, 0.08), Vector3(90, 0, 0))
	_part(root, tail, Color("cbc9b7"), Vector3(0.01, 0.09, -0.145))
	_part(root, muzzle, Color("8d785b"), Vector3(0.013, 0.156, 0.139))
	_part(root, nose, Color("5e4e3c"), Vector3(0.013, 0.156, 0.159))
	var frost_sheet_part_1: MeshInstance3D = _part(root, frost_sheet, Color("b4b9ad"), Vector3(0, 0.164, -0.025))
	frost_sheet_part_1.scale = Vector3(0.85, 1, 1.1)


## A round stale loaf with three broad scores and green grey mould patches.
static func _bread_moldy(root: Node3D) -> void:
	var loaf: SphereMesh = SphereMesh.new()
	loaf.radius = 0.139
	loaf.height = 0.147
	loaf.radial_segments = 16
	loaf.rings = 8
	var score: CapsuleMesh = CapsuleMesh.new()
	score.radius = 0.009
	score.height = 0.13
	score.radial_segments = 12
	score.rings = 6
	var mould: SphereMesh = SphereMesh.new()
	mould.radius = 0.034
	mould.height = 0.013
	mould.radial_segments = 16
	mould.rings = 8

	var loaf_part_1: MeshInstance3D = _part(root, loaf, Color("aa9677"), Vector3(0, 0.0735, 0))
	loaf_part_1.scale = Vector3(1.1, 1, 0.86)
	_part(root, score, Color("736f5b"), Vector3(-0.066, 0.144, 0), Vector3(90, 0, 22))
	_part(root, score, Color("736f5b"), Vector3(0, 0.144, 0), Vector3(90, 0, 22))
	_part(root, score, Color("736f5b"), Vector3(0.066, 0.144, 0), Vector3(90, 0, 22))
	var mould_part_1: MeshInstance3D = _part(root, mould, Color("748371"), Vector3(-0.075, 0.127, 0.053), Vector3(0, 0, 18))
	mould_part_1.scale = Vector3(1, 1, 0.8)
	var mould_part_2: MeshInstance3D = _part(root, mould, Color("929d87"), Vector3(0.055, 0.139, -0.041), Vector3(0, 0, -14))
	mould_part_2.scale = Vector3(1.2, 1, 1)
	var mould_part_3: MeshInstance3D = _part(root, mould, Color("66776d"), Vector3(0.093, 0.108, 0.048), Vector3(0, 0, -28))
	mould_part_3.scale = Vector3(0.75, 1, 0.75)


## A flattened ointment tube with a blue band, a crimped tail and a ribbed cap.
static func _tube(root: Node3D) -> void:
	var body: CapsuleMesh = CapsuleMesh.new()
	body.radius = 0.047
	body.height = 0.238
	body.radial_segments = 12
	body.rings = 6
	var band: CylinderMesh = CylinderMesh.new()
	band.top_radius = 0.048
	band.bottom_radius = 0.048
	band.height = 0.085
	band.radial_segments = 12
	var seal: BoxMesh = BoxMesh.new()
	seal.size = Vector3(0.022, 0.08, 0.073)
	var crimp: BoxMesh = BoxMesh.new()
	crimp.size = Vector3(0.008, 0.069, 0.075)
	var cap: CylinderMesh = CylinderMesh.new()
	cap.top_radius = 0.034
	cap.bottom_radius = 0.034
	cap.height = 0.047
	cap.radial_segments = 12
	var cap_rib: CylinderMesh = CylinderMesh.new()
	cap_rib.top_radius = 0.037
	cap_rib.bottom_radius = 0.037
	cap_rib.height = 0.009
	cap_rib.radial_segments = 12

	var body_part_1: MeshInstance3D = _part(root, body, Color("c5c9bd"), Vector3(-0.013, 0.048, 0), Vector3(0, 0, 90))
	body_part_1.scale = Vector3(1, 1, 0.76)
	var band_part_1: MeshInstance3D = _part(root, band, Color("7c989d"), Vector3(0.015, 0.048, 0), Vector3(0, 0, 90))
	band_part_1.scale = Vector3(1, 1, 0.76)
	_part(root, seal, Color("a5b0aa"), Vector3(-0.133, 0.043, 0))
	_part(root, crimp, Color("788c8b"), Vector3(-0.142, 0.043, 0))
	_part(root, cap, Color("849797"), Vector3(0.13, 0.048, 0), Vector3(0, 0, 90))
	_part(root, cap_rib, Color("b0bdb5"), Vector3(0.118, 0.048, 0), Vector3(0, 0, 90))
	_part(root, cap_rib, Color("b0bdb5"), Vector3(0.135, 0.048, 0), Vector3(0, 0, 90))
	_part(root, cap_rib, Color("b0bdb5"), Vector3(0.151, 0.048, 0), Vector3(0, 0, 90))


## One aged grey-white paper cylinder on its side, a dark end hole and one loose sheet.
static func _toilet_paper(root: Node3D) -> void:
	var roll: CylinderMesh = CylinderMesh.new()
	roll.top_radius = 0.091
	roll.bottom_radius = 0.091
	roll.height = 0.175
	roll.radial_segments = 24
	var end_face: CylinderMesh = CylinderMesh.new()
	end_face.top_radius = 0.087
	end_face.bottom_radius = 0.087
	end_face.height = 0.012
	end_face.radial_segments = 24
	var core_hole: CylinderMesh = CylinderMesh.new()
	core_hole.top_radius = 0.029
	core_hole.bottom_radius = 0.029
	core_hole.height = 0.014
	core_hole.radial_segments = 16
	var loose_sheet: BoxMesh = BoxMesh.new()
	loose_sheet.size = Vector3(0.17, 0.012, 0.17)
	var loose_edge: CylinderMesh = CylinderMesh.new()
	loose_edge.top_radius = 0.012
	loose_edge.bottom_radius = 0.012
	loose_edge.height = 0.17
	loose_edge.radial_segments = 12

	_part(root, roll, Color("a8a47c"), Vector3(0, 0.091, 0), Vector3(0, 0, 90))
	_part(root, end_face, Color("9c9670"), Vector3(0.0885, 0.091, 0), Vector3(0, 0, 90))
	_part(root, core_hole, Color("635b42"), Vector3(0.098, 0.091, 0), Vector3(0, 0, 90))
	_part(root, loose_sheet, Color("bcb89b"), Vector3(-0.005, 0.006, 0.12))
	_part(root, loose_edge, Color("aaa682"), Vector3(-0.005, 0.012, 0.203), Vector3(0, 0, 90))


## A pale blue green soap bar with softly rounded sides and an oval top groove.
static func _soap(root: Node3D) -> void:
	var body: BoxMesh = BoxMesh.new()
	body.size = Vector3(0.2, 0.08, 0.12)
	var edge: CylinderMesh = CylinderMesh.new()
	edge.top_radius = 0.04
	edge.bottom_radius = 0.04
	edge.height = 0.2
	edge.radial_segments = 12
	var end: SphereMesh = SphereMesh.new()
	end.radius = 0.062
	end.height = 0.08
	end.radial_segments = 16
	end.rings = 8
	var groove: TorusMesh = TorusMesh.new()
	groove.inner_radius = 0.024
	groove.outer_radius = 0.035
	groove.rings = 20
	groove.ring_segments = 8

	_part(root, body, Color("a8bdb4"), Vector3(0, 0.04, 0))
	_part(root, edge, Color("b4c5bb"), Vector3(0, 0.04, -0.06), Vector3(0, 0, 90))
	_part(root, edge, Color("b4c5bb"), Vector3(0, 0.04, 0.06), Vector3(0, 0, 90))
	var end_part_1: MeshInstance3D = _part(root, end, Color("b4c5bb"), Vector3(-0.1, 0.04, 0))
	end_part_1.scale = Vector3(1, 1, 1.15)
	var end_part_2: MeshInstance3D = _part(root, end, Color("b4c5bb"), Vector3(0.1, 0.04, 0))
	end_part_2.scale = Vector3(1, 1, 1.15)
	var groove_part_1: MeshInstance3D = _part(root, groove, Color("7d9b93"), Vector3(0, 0.081, 0))
	groove_part_1.scale = Vector3(1.6, 0.7, 0.8)


## A small flat T-shaped child's shirt with two broad faded red stripes.
static func _child_clothes(root: Node3D) -> void:
	var body: BoxMesh = BoxMesh.new()
	body.size = Vector3(0.15, 0.028, 0.17)
	var shoulder: BoxMesh = BoxMesh.new()
	shoulder.size = Vector3(0.054, 0.028, 0.065)
	var sleeve: CapsuleMesh = CapsuleMesh.new()
	sleeve.radius = 0.031
	sleeve.height = 0.132
	sleeve.radial_segments = 12
	sleeve.rings = 6
	var hem: CylinderMesh = CylinderMesh.new()
	hem.top_radius = 0.014
	hem.bottom_radius = 0.014
	hem.height = 0.15
	hem.radial_segments = 12
	var stripe: BoxMesh = BoxMesh.new()
	stripe.size = Vector3(0.146, 0.012, 0.024)
	var collar: CylinderMesh = CylinderMesh.new()
	collar.top_radius = 0.019
	collar.bottom_radius = 0.019
	collar.height = 0.095
	collar.radial_segments = 12
	var side_edge: CylinderMesh = CylinderMesh.new()
	side_edge.top_radius = 0.014
	side_edge.bottom_radius = 0.014
	side_edge.height = 0.17
	side_edge.radial_segments = 12

	_part(root, body, Color("9c754e"), Vector3(0, 0.014, 0.03))
	_part(root, shoulder, Color("9c754e"), Vector3(-0.049, 0.014, -0.068))
	_part(root, shoulder, Color("9c754e"), Vector3(0.049, 0.014, -0.068))
	var sleeve_part_1: MeshInstance3D = _part(root, sleeve, Color("896342"), Vector3(-0.115, 0.014, -0.07), Vector3(0, 0, 90))
	sleeve_part_1.scale = Vector3(0.451613, 1, 1)
	var sleeve_part_2: MeshInstance3D = _part(root, sleeve, Color("896342"), Vector3(0.115, 0.014, -0.07), Vector3(0, 0, 90))
	sleeve_part_2.scale = Vector3(0.451613, 1, 1)
	_part(root, hem, Color("896342"), Vector3(0, 0.014, 0.115), Vector3(0, 0, 90))
	_part(root, stripe, Color("8c5043"), Vector3(0, 0.032, 0.013))
	_part(root, stripe, Color("8c5043"), Vector3(0, 0.032, 0.066))
	_part(root, collar, Color("9f8b62"), Vector3(0, 0.044, -0.075), Vector3(0, 0, 90))
	_part(root, side_edge, Color("9c754e"), Vector3(-0.075, 0.014, 0.03), Vector3(90, 0, 0))
	_part(root, side_edge, Color("9c754e"), Vector3(0.075, 0.014, 0.03), Vector3(90, 0, 0))


## Two crossed soft cloth folds, with a contrasting sewn repair patch.
static func _old_clothes(root: Node3D) -> void:
	var lower: BoxMesh = BoxMesh.new()
	lower.size = Vector3(0.28, 0.046, 0.207)
	var lower_fold: CylinderMesh = CylinderMesh.new()
	lower_fold.top_radius = 0.023
	lower_fold.bottom_radius = 0.023
	lower_fold.height = 0.28
	lower_fold.radial_segments = 12
	var upper: BoxMesh = BoxMesh.new()
	upper.size = Vector3(0.245, 0.047, 0.198)
	var upper_fold: CylinderMesh = CylinderMesh.new()
	upper_fold.top_radius = 0.0235
	upper_fold.bottom_radius = 0.0235
	upper_fold.height = 0.245
	upper_fold.radial_segments = 12
	var patch: BoxMesh = BoxMesh.new()
	patch.size = Vector3(0.079, 0.012, 0.069)
	var stitch: BoxMesh = BoxMesh.new()
	stitch.size = Vector3(0.012, 0.012, 0.022)

	_part(root, lower, Color("536c7b"), Vector3(0, 0.023, 0), Vector3(0, -9, 0))
	_part(root, lower_fold, Color("627c87"), Vector3(-0.016, 0.023, 0.102), Vector3(0, -9, 90))
	_part(root, upper, Color("7b624b"), Vector3(0.015, 0.071, 0.005), Vector3(0, 12, 0))
	_part(root, upper_fold, Color("8b7256"), Vector3(0.036, 0.071, 0.102), Vector3(0, 12, 90))
	_part(root, patch, Color("925d4c"), Vector3(0.05, 0.1, 0.021), Vector3(0, 12, 0))
	_part(root, stitch, Color("9b8061"), Vector3(0.023, 0.109, -0.004), Vector3(0, 12, 0))
	_part(root, stitch, Color("9b8061"), Vector3(0.023, 0.109, 0.043), Vector3(0, 12, 0))
	_part(root, stitch, Color("9b8061"), Vector3(0.079, 0.109, -0.004), Vector3(0, 12, 0))
	_part(root, stitch, Color("9b8061"), Vector3(0.079, 0.109, 0.043), Vector3(0, 12, 0))


## A 130 mm curved flat horn grip and a 100 mm blade opened 70 degrees about one brass hinge.
static func _razor(root: Node3D) -> void:
	var vertices: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var add_quad: Callable = func(corners: PackedVector3Array, face_normal: Vector3) -> void:
		var order: Array[int] = [0, 1, 2, 1, 3, 2]
		if (corners[1] - corners[0]).cross(corners[2] - corners[0]).dot(face_normal) > 0.0:
			order = [0, 2, 1, 1, 2, 3]
		for corner_index: int in order:
			vertices.append(corners[corner_index])
			normals.append(face_normal)
	var half_thickness: Vector3 = Vector3(0, 0.007, 0)
	for row: int in 12:
		var a_ratio: float = float(row) / 12.0
		var b_ratio: float = float(row + 1) / 12.0
		var center_a: Vector3 = Vector3(0.108 * a_ratio, 0.007, 0.004 * sin(PI * a_ratio))
		var center_b: Vector3 = Vector3(0.108 * b_ratio, 0.007, 0.004 * sin(PI * b_ratio))
		var a: Vector3 = center_a + Vector3(0, 0, -0.011)
		var b: Vector3 = center_a + Vector3(0, 0, 0.011)
		var c: Vector3 = center_b + Vector3(0, 0, -0.011)
		var d: Vector3 = center_b + Vector3(0, 0, 0.011)
		var outward: Vector3 = (center_b - center_a).cross(Vector3.UP).normalized()
		add_quad.call(PackedVector3Array([a + half_thickness, b + half_thickness, c + half_thickness, d + half_thickness]), Vector3.UP)
		add_quad.call(PackedVector3Array([a - half_thickness, b - half_thickness, c - half_thickness, d - half_thickness]), Vector3.DOWN)
		add_quad.call(PackedVector3Array([b + half_thickness, d + half_thickness, b - half_thickness, d - half_thickness]), outward)
		add_quad.call(PackedVector3Array([a + half_thickness, c + half_thickness, a - half_thickness, c - half_thickness]), -outward)
		if row == 0:
			add_quad.call(PackedVector3Array([a + half_thickness, b + half_thickness, a - half_thickness, b - half_thickness]), Vector3.LEFT)
		if row == 11:
			add_quad.call(PackedVector3Array([c + half_thickness, d + half_thickness, c - half_thickness, d - half_thickness]), Vector3.RIGHT)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	var handle: ArrayMesh = ArrayMesh.new()
	handle.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Keep grip and blade coplanar; only the whole open razor leans off the floor.
	var frame: Node3D = Node3D.new()
	frame.position = Vector3(0, 0.004298, 0)
	frame.rotation_degrees = Vector3(0, 0, 23)
	root.add_child(frame)
	_part(frame, handle, Color("73533b"), Vector3.ZERO)
	var grip_end: CylinderMesh = CylinderMesh.new()
	grip_end.top_radius = 0.011
	grip_end.bottom_radius = 0.011
	grip_end.height = 0.014
	grip_end.radial_segments = 12
	for end_x: float in [0.0, 0.108]:
		_part(frame, grip_end, Color("73533b"), Vector3(end_x, 0.007, 0))
	var blade: BoxMesh = BoxMesh.new()
	blade.size = Vector3(0.1, 0.014, 0.028)
	var spine: BoxMesh = BoxMesh.new()
	spine.size = Vector3(0.1, 0.012, 0.012)
	var hinge: CylinderMesh = CylinderMesh.new()
	hinge.top_radius = 0.009
	hinge.bottom_radius = 0.009
	hinge.height = 0.012
	hinge.radial_segments = 12
	var hinge_at: Vector3 = Vector3(0, 0.009, 0)
	var blade_pivot: Vector3 = Vector3(hinge_at.x, 0.009, hinge_at.z)
	var blade_turn: Vector3 = Vector3(0, -70, 0)
	var blade_basis: Basis = Basis(Vector3.UP, deg_to_rad(blade_turn.y))
	_part(frame, blade, Color("b8c2c2"), blade_pivot + blade_basis * Vector3(blade.size.x * 0.5, 0, 0), blade_turn)
	_part(frame, spine, Color("89979b"), blade_pivot + blade_basis * Vector3(0.05, 0.003, -0.008), blade_turn)
	_part(frame, hinge, Color("a18b56"), hinge_at)


## Two overlapping open-centred toothed metal discs, with broad bright steel teeth.
static func _gears(root: Node3D) -> void:
	var disc: TorusMesh = TorusMesh.new()
	disc.inner_radius = 0.025
	disc.outer_radius = 0.084
	disc.rings = 20
	disc.ring_segments = 8
	var tooth: BoxMesh = BoxMesh.new()
	tooth.size = Vector3(0.042, 0.035, 0.026)

	var disc_part_1: MeshInstance3D = _part(root, disc, Color("879394"), Vector3(-0.065, 0.0175, 0))
	disc_part_1.scale = Vector3(1, 0.48, 1)
	_part(root, tooth, Color("96a2a1"), Vector3(0.027, 0.0175, 0))
	_part(root, tooth, Color("96a2a1"), Vector3(0.014674, 0.0175, 0.046), Vector3(0, -30, 0))
	_part(root, tooth, Color("96a2a1"), Vector3(-0.019, 0.0175, 0.079674), Vector3(0, -60, 0))
	_part(root, tooth, Color("96a2a1"), Vector3(-0.065, 0.0175, 0.092), Vector3(0, -90, 0))
	_part(root, tooth, Color("96a2a1"), Vector3(-0.111, 0.0175, 0.079674), Vector3(0, -120, 0))
	_part(root, tooth, Color("96a2a1"), Vector3(-0.144674, 0.0175, 0.046), Vector3(0, -150, 0))
	_part(root, tooth, Color("96a2a1"), Vector3(-0.157, 0.0175, 0), Vector3(0, -180, 0))
	_part(root, tooth, Color("96a2a1"), Vector3(-0.144674, 0.0175, -0.046), Vector3(0, -210, 0))
	_part(root, tooth, Color("96a2a1"), Vector3(-0.111, 0.0175, -0.079674), Vector3(0, -240, 0))
	_part(root, tooth, Color("96a2a1"), Vector3(-0.065, 0.0175, -0.092), Vector3(0, -270, 0))
	_part(root, tooth, Color("96a2a1"), Vector3(-0.019, 0.0175, -0.079674), Vector3(0, -300, 0))
	_part(root, tooth, Color("96a2a1"), Vector3(0.014674, 0.0175, -0.046), Vector3(0, -330, 0))
	var disc_part_2: MeshInstance3D = _part(root, disc, Color("b0b9b2"), Vector3(0.072, 0.0565, 0.044))
	disc_part_2.scale = Vector3(1, 0.48, 1)
	_part(root, tooth, Color("bbc4ba"), Vector3(0.160865, 0.0565, 0.067811), Vector3(0, -15, 0))
	_part(root, tooth, Color("bbc4ba"), Vector3(0.137054, 0.0565, 0.109054), Vector3(0, -45, 0))
	_part(root, tooth, Color("bbc4ba"), Vector3(0.095811, 0.0565, 0.132865), Vector3(0, -75, 0))
	_part(root, tooth, Color("bbc4ba"), Vector3(0.048189, 0.0565, 0.132865), Vector3(0, -105, 0))
	_part(root, tooth, Color("bbc4ba"), Vector3(0.006946, 0.0565, 0.109054), Vector3(0, -135, 0))
	_part(root, tooth, Color("bbc4ba"), Vector3(-0.016865, 0.0565, 0.067811), Vector3(0, -165, 0))
	_part(root, tooth, Color("bbc4ba"), Vector3(-0.016865, 0.0565, 0.020189), Vector3(0, -195, 0))
	_part(root, tooth, Color("bbc4ba"), Vector3(0.006946, 0.0565, -0.021054), Vector3(0, -225, 0))
	_part(root, tooth, Color("bbc4ba"), Vector3(0.048189, 0.0565, -0.044865), Vector3(0, -255, 0))
	_part(root, tooth, Color("bbc4ba"), Vector3(0.095811, 0.0565, -0.044865), Vector3(0, -285, 0))
	_part(root, tooth, Color("bbc4ba"), Vector3(0.137054, 0.0565, -0.021054), Vector3(0, -315, 0))
	_part(root, tooth, Color("bbc4ba"), Vector3(0.160865, 0.0565, 0.020189), Vector3(0, -345, 0))


## Seven scattered steel nails, with 12 mm shafts, 30 mm heads and broad points.
static func _nails(root: Node3D) -> void:
	var shaft: CylinderMesh = CylinderMesh.new()
	shaft.top_radius = 0.006
	shaft.bottom_radius = 0.006
	shaft.height = 0.145
	shaft.radial_segments = 8
	var head: CylinderMesh = CylinderMesh.new()
	head.top_radius = 0.015
	head.bottom_radius = 0.015
	head.height = 0.014
	head.radial_segments = 10
	var tip: CylinderMesh = CylinderMesh.new()
	tip.top_radius = 0
	tip.bottom_radius = 0.006
	tip.height = 0.028
	tip.radial_segments = 8

	_part(root, shaft, Color("6f8799"), Vector3(-0.025, 0.015, -0.077), Vector3(0, -34, -90))
	_part(root, head, Color("8a9caa"), Vector3(-0.088007, 0.015, -0.119499), Vector3(0, -34, -90))
	_part(root, tip, Color("7f94a2"), Vector3(0.045468, 0.015, -0.029469), Vector3(0, -34, -90))
	_part(root, shaft, Color("6f8799"), Vector3(0.032, 0.036, -0.052), Vector3(0, 21, -90))
	_part(root, head, Color("8a9caa"), Vector3(-0.038952, 0.036, -0.024764), Vector3(0, 21, -90))
	_part(root, tip, Color("7f94a2"), Vector3(0.111354, 0.036, -0.082461), Vector3(0, 21, -90))
	_part(root, shaft, Color("6f8799"), Vector3(-0.043, 0.057, -0.027), Vector3(0, 66, -90))
	_part(root, head, Color("8a9caa"), Vector3(-0.073912, 0.057, 0.042429), Vector3(0, 66, -90))
	_part(root, tip, Color("7f94a2"), Vector3(-0.008427, 0.057, -0.104651), Vector3(0, 66, -90))
	_part(root, shaft, Color("6f8799"), Vector3(0.025, 0.015, -0.002), Vector3(0, -12, -90))
	_part(root, head, Color("8a9caa"), Vector3(-0.049339, 0.015, -0.017801), Vector3(0, -12, -90))
	_part(root, tip, Color("7f94a2"), Vector3(0.108143, 0.015, 0.015672), Vector3(0, -12, -90))
	_part(root, shaft, Color("6f8799"), Vector3(-0.012, 0.036, 0.023), Vector3(0, 43, -90))
	_part(root, head, Color("8a9caa"), Vector3(-0.067583, 0.036, 0.074832), Vector3(0, 43, -90))
	_part(root, tip, Color("7f94a2"), Vector3(0.050165, 0.036, -0.03497), Vector3(0, 43, -90))
	_part(root, shaft, Color("6f8799"), Vector3(0.043, 0.057, 0.048), Vector3(0, -55, -90))
	_part(root, head, Color("8a9caa"), Vector3(-0.000592, 0.057, -0.014256), Vector3(0, -55, -90))
	_part(root, tip, Color("7f94a2"), Vector3(0.091754, 0.057, 0.117628), Vector3(0, -55, -90))
	_part(root, shaft, Color("6f8799"), Vector3(0, 0.015, 0.073), Vector3(0, 9, -90))
	_part(root, head, Color("8a9caa"), Vector3(-0.075064, 0.015, 0.084889), Vector3(0, 9, -90))
	_part(root, tip, Color("7f94a2"), Vector3(0.083954, 0.015, 0.059703), Vector3(0, 9, -90))


## A low half-open tin with a ragged raised lid and the slim wooden lever resting diagonally across it.
static func _opener(root: Node3D) -> void:
	var lid_frame: Node3D = Node3D.new()
	lid_frame.position = Vector3(0, 0.114787, -0.099562)
	lid_frame.rotation_degrees = Vector3(55, 0, 0)
	root.add_child(lid_frame)
	var lever: Node3D = Node3D.new()
	lever.position = Vector3(0.02, 0.075, 0.015)
	lever.rotation_degrees = Vector3(0, -25, 10)
	root.add_child(lever)
	var tin: CylinderMesh = CylinderMesh.new()
	tin.top_radius = 0.075
	tin.bottom_radius = 0.075
	tin.height = 0.06
	tin.radial_segments = 20
	var inside: CylinderMesh = CylinderMesh.new()
	inside.top_radius = 0.066
	inside.bottom_radius = 0.066
	inside.height = 0.012
	inside.radial_segments = 20
	var rim: TorusMesh = TorusMesh.new()
	rim.inner_radius = 0.063
	rim.outer_radius = 0.078
	rim.rings = 20
	rim.ring_segments = 8
	var lid: CylinderMesh = CylinderMesh.new()
	lid.top_radius = 0.071
	lid.bottom_radius = 0.071
	lid.height = 0.014
	lid.radial_segments = 20
	var torn_edge: PrismMesh = PrismMesh.new()
	torn_edge.size = Vector3(0.018, 0.028, 0.014)
	torn_edge.left_to_right = 0.5
	var handle: CapsuleMesh = CapsuleMesh.new()
	handle.radius = 0.012
	handle.height = 0.12
	handle.radial_segments = 12
	handle.rings = 6
	var shank: BoxMesh = BoxMesh.new()
	shank.size = Vector3(0.055, 0.014, 0.028)
	var hook: BoxMesh = BoxMesh.new()
	hook.size = Vector3(0.028, 0.014, 0.064)

	_part(root, tin, Color("7f8b62"), Vector3(0, 0.03, 0))
	_part(root, inside, Color("4d5b44"), Vector3(0, 0.062, 0))
	_part(root, rim, Color("9aa886"), Vector3(0, 0.06, 0))
	_part(lid_frame, lid, Color("9aa886"), Vector3(0, 0, 0))
	_part(lid_frame, torn_edge, Color("9aa886"), Vector3(-0.055, 0.002, 0.04), Vector3(90, -35, 0))
	_part(lid_frame, torn_edge, Color("9aa886"), Vector3(-0.028, 0.002, 0.063), Vector3(90, -16, 0))
	_part(lid_frame, torn_edge, Color("9aa886"), Vector3(0, 0.002, 0.068), Vector3(90, 0, 0))
	_part(lid_frame, torn_edge, Color("9aa886"), Vector3(0.028, 0.002, 0.063), Vector3(90, 16, 0))
	_part(lid_frame, torn_edge, Color("9aa886"), Vector3(0.055, 0.002, 0.04), Vector3(90, 35, 0))
	_part(lever, handle, Color("785a40"), Vector3(-0.025, 0.0318, 0), Vector3(0, 0, -70))
	_part(lever, shank, Color("9ba8ad"), Vector3(0.052, 0.058, 0))
	_part(lever, hook, Color("9ba8ad"), Vector3(0.0795, 0.058, 0.019))


## A flat faded green jerrycan with three top grips, a spout and pressed X ribs.
static func _fuel(root: Node3D) -> void:
	var body: BoxMesh = BoxMesh.new()
	body.size = Vector3(0.23, 0.275, 0.128)
	var shoulder: BoxMesh = BoxMesh.new()
	shoulder.size = Vector3(0.218, 0.047, 0.12)
	var base_rim: BoxMesh = BoxMesh.new()
	base_rim.size = Vector3(0.238, 0.023, 0.136)
	var grip: BoxMesh = BoxMesh.new()
	grip.size = Vector3(0.124, 0.018, 0.018)
	var grip_post: BoxMesh = BoxMesh.new()
	grip_post.size = Vector3(0.018, 0.049, 0.018)
	var spout: CylinderMesh = CylinderMesh.new()
	spout.top_radius = 0.026
	spout.bottom_radius = 0.026
	spout.height = 0.046
	spout.radial_segments = 10
	var cap: CylinderMesh = CylinderMesh.new()
	cap.top_radius = 0.031
	cap.bottom_radius = 0.031
	cap.height = 0.018
	cap.radial_segments = 10
	var pressed_rib: BoxMesh = BoxMesh.new()
	pressed_rib.size = Vector3(0.017, 0.217, 0.012)

	_part(root, body, Color("788576"), Vector3(0, 0.1375, 0))
	_part(root, shoulder, Color("8b9783"), Vector3(0, 0.292, 0))
	_part(root, base_rim, Color("5f7067"), Vector3(0, 0.0115, 0))
	_part(root, grip, Color("a4ad96"), Vector3(0.025, 0.355, -0.038))
	_part(root, grip_post, Color("8d9c89"), Vector3(-0.028, 0.329, -0.038))
	_part(root, grip_post, Color("8d9c89"), Vector3(0.078, 0.329, -0.038))
	_part(root, grip, Color("a4ad96"), Vector3(0.025, 0.355, 0))
	_part(root, grip_post, Color("8d9c89"), Vector3(-0.028, 0.329, 0))
	_part(root, grip_post, Color("8d9c89"), Vector3(0.078, 0.329, 0))
	_part(root, grip, Color("a4ad96"), Vector3(0.025, 0.355, 0.038))
	_part(root, grip_post, Color("8d9c89"), Vector3(-0.028, 0.329, 0.038))
	_part(root, grip_post, Color("8d9c89"), Vector3(0.078, 0.329, 0.038))
	_part(root, spout, Color("8e9b84"), Vector3(-0.093, 0.323, 0), Vector3(0, 0, 24))
	_part(root, cap, Color("b0b79e"), Vector3(-0.106, 0.352, 0), Vector3(0, 0, 24))
	_part(root, pressed_rib, Color("a2af98"), Vector3(0, 0.144, 0.069), Vector3(0, 0, -42))
	_part(root, pressed_rib, Color("a2af98"), Vector3(0, 0.144, 0.069), Vector3(0, 0, 42))


## Two silver coil springs, built from separated thick rings with visible dark gaps.
static func _spring(root: Node3D) -> void:
	var coil: TorusMesh = TorusMesh.new()
	coil.inner_radius = 0.038
	coil.outer_radius = 0.053
	coil.rings = 20
	coil.ring_segments = 8
	var end: CylinderMesh = CylinderMesh.new()
	end.top_radius = 0.007
	end.bottom_radius = 0.007
	end.height = 0.052
	end.radial_segments = 8

	_part(root, coil, Color("9ba9ab"), Vector3(-0.0675, 0.0075, 0))
	_part(root, coil, Color("9ba9ab"), Vector3(-0.0675, 0.0325, 0), Vector3(0, 11, 0))
	_part(root, coil, Color("9ba9ab"), Vector3(-0.0675, 0.0575, 0), Vector3(0, 22, 0))
	_part(root, coil, Color("9ba9ab"), Vector3(-0.0675, 0.0825, 0), Vector3(0, 33, 0))
	_part(root, coil, Color("9ba9ab"), Vector3(-0.0675, 0.1075, 0), Vector3(0, 44, 0))
	_part(root, coil, Color("9ba9ab"), Vector3(-0.0675, 0.1325, 0), Vector3(0, 55, 0))
	_part(root, coil, Color("bcc5bf"), Vector3(0.0675, 0.0195, 0.027))
	_part(root, coil, Color("bcc5bf"), Vector3(0.0675, 0.0445, 0.027), Vector3(0, 11, 0))
	_part(root, coil, Color("bcc5bf"), Vector3(0.0675, 0.0695, 0.027), Vector3(0, 22, 0))
	_part(root, coil, Color("bcc5bf"), Vector3(0.0675, 0.0945, 0.027), Vector3(0, 33, 0))
	_part(root, coil, Color("bcc5bf"), Vector3(0.0675, 0.1195, 0.027), Vector3(0, 44, 0))
	_part(root, coil, Color("bcc5bf"), Vector3(0.0675, 0.1445, 0.027), Vector3(0, 55, 0))
	_part(root, end, Color("c6cec6"), Vector3(-0.0435, 0.0095, 0), Vector3(0, 0, 90))
	_part(root, end, Color("c6cec6"), Vector3(0.0915, 0.0095, 0.027), Vector3(0, 0, 90))


## A charcoal record, pale centre label and circular grooves, half outside a paper sleeve.
static func _record(root: Node3D) -> void:
	var sleeve: BoxMesh = BoxMesh.new()
	sleeve.size = Vector3(0.238, 0.064, 0.255)
	var sleeve_edge: BoxMesh = BoxMesh.new()
	sleeve_edge.size = Vector3(0.014, 0.008, 0.229)
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.132
	disc.bottom_radius = 0.132
	disc.height = 0.014
	disc.radial_segments = 40
	var groove: TorusMesh = TorusMesh.new()
	groove.inner_radius = 0.101
	groove.outer_radius = 0.109
	groove.rings = 20
	groove.ring_segments = 8
	var outer_groove: TorusMesh = TorusMesh.new()
	outer_groove.inner_radius = 0.116
	outer_groove.outer_radius = 0.124
	outer_groove.rings = 20
	outer_groove.ring_segments = 8
	var label: CylinderMesh = CylinderMesh.new()
	label.top_radius = 0.045
	label.bottom_radius = 0.045
	label.height = 0.01
	label.radial_segments = 20
	var hole: CylinderMesh = CylinderMesh.new()
	hole.top_radius = 0.009
	hole.bottom_radius = 0.009
	hole.height = 0.008
	hole.radial_segments = 10

	_part(root, sleeve, Color("b3b0a1"), Vector3(-0.072, 0.032, -0.017), Vector3(0, -5, 0))
	_part(root, sleeve_edge, Color("d0c8b1"), Vector3(-0.173, 0.068, -0.019), Vector3(0, -5, 0))
	_part(root, disc, Color("30383d"), Vector3(0.07, 0.078, 0.038))
	_part(root, groove, Color("4b565a"), Vector3(0.07, 0.086, 0.038))
	_part(root, outer_groove, Color("465154"), Vector3(0.07, 0.086, 0.038))
	_part(root, label, Color("aaa68b"), Vector3(0.07, 0.091, 0.038))
	_part(root, hole, Color("3f4949"), Vector3(0.07, 0.1, 0.038))


## A worn brown violin: two overlapping lobes, a long neck, peg head and dark f-hole plates.
static func _violin(root: Node3D) -> void:
	var lower_lobe: CylinderMesh = CylinderMesh.new()
	lower_lobe.top_radius = 0.088
	lower_lobe.bottom_radius = 0.088
	lower_lobe.height = 0.055
	lower_lobe.radial_segments = 20
	var upper_lobe: CylinderMesh = CylinderMesh.new()
	upper_lobe.top_radius = 0.069
	upper_lobe.bottom_radius = 0.069
	upper_lobe.height = 0.055
	upper_lobe.radial_segments = 20
	var neck: BoxMesh = BoxMesh.new()
	neck.size = Vector3(0.154, 0.032, 0.034)
	var peg_head: CapsuleMesh = CapsuleMesh.new()
	peg_head.radius = 0.023
	peg_head.height = 0.065
	peg_head.radial_segments = 12
	peg_head.rings = 6
	var peg: CylinderMesh = CylinderMesh.new()
	peg.top_radius = 0.009
	peg.bottom_radius = 0.009
	peg.height = 0.065
	peg.radial_segments = 8
	var bridge: BoxMesh = BoxMesh.new()
	bridge.size = Vector3(0.014, 0.027, 0.056)
	var tailpiece: BoxMesh = BoxMesh.new()
	tailpiece.size = Vector3(0.056, 0.014, 0.027)
	var f_plate: CapsuleMesh = CapsuleMesh.new()
	f_plate.radius = 0.009
	f_plate.height = 0.044
	f_plate.radial_segments = 12
	f_plate.rings = 6
	var string: BoxMesh = BoxMesh.new()
	string.size = Vector3(0.278, 0.008, 0.008)

	var lower_lobe_part_1: MeshInstance3D = _part(root, lower_lobe, Color("987655"), Vector3(-0.078, 0.0275, 0))
	lower_lobe_part_1.scale = Vector3(1, 1, 0.96)
	var upper_lobe_part_1: MeshInstance3D = _part(root, upper_lobe, Color("a9855f"), Vector3(0.039, 0.0275, 0))
	upper_lobe_part_1.scale = Vector3(1, 1, 0.94)
	_part(root, neck, Color("735d49"), Vector3(0.148, 0.0355, 0))
	_part(root, peg_head, Color("a0835a"), Vector3(0.251, 0.0415, 0), Vector3(0, 0, 90))
	_part(root, peg, Color("675b4d"), Vector3(0.238, 0.0445, 0), Vector3(90, 0, 0))
	_part(root, peg, Color("675b4d"), Vector3(0.262, 0.0445, 0), Vector3(90, 0, 0))
	_part(root, bridge, Color("c4b595"), Vector3(-0.016, 0.0605, 0))
	_part(root, tailpiece, Color("65594c"), Vector3(-0.113, 0.0605, 0), Vector3(0, 7, 0))
	_part(root, f_plate, Color("4e4941"), Vector3(-0.031, 0.0595, -0.036), Vector3(0, -10.8, 90))
	_part(root, f_plate, Color("4e4941"), Vector3(-0.031, 0.0595, 0.036), Vector3(0, 10.8, 90))
	_part(root, string, Color("c2bba4"), Vector3(0.073, 0.0685, -0.011))
	_part(root, string, Color("c2bba4"), Vector3(0.073, 0.0685, 0))
	_part(root, string, Color("c2bba4"), Vector3(0.073, 0.0685, 0.011))


## Five upright brass pistol cartridges with rounded pale bullet noses.
static func _ammo_pistol(root: Node3D) -> void:
	var case: CylinderMesh = CylinderMesh.new()
	case.top_radius = 0.018
	case.bottom_radius = 0.018
	case.height = 0.111
	case.radial_segments = 12
	var bullet: SphereMesh = SphereMesh.new()
	bullet.radius = 0.018
	bullet.height = 0.045
	bullet.radial_segments = 16
	bullet.rings = 8
	var rim: CylinderMesh = CylinderMesh.new()
	rim.top_radius = 0.021
	rim.bottom_radius = 0.021
	rim.height = 0.012
	rim.radial_segments = 12

	_part(root, case, Color("b9a16f"), Vector3(-0.042, 0.065, -0.032))
	_part(root, bullet, Color("c4b69b"), Vector3(-0.042, 0.128, -0.032))
	_part(root, rim, Color("d0b987"), Vector3(-0.042, 0.006, -0.032))
	_part(root, case, Color("b9a16f"), Vector3(0, 0.065, -0.034))
	_part(root, bullet, Color("c4b69b"), Vector3(0, 0.128, -0.034))
	_part(root, rim, Color("d0b987"), Vector3(0, 0.006, -0.034))
	_part(root, case, Color("b9a16f"), Vector3(0.042, 0.065, -0.025))
	_part(root, bullet, Color("c4b69b"), Vector3(0.042, 0.128, -0.025))
	_part(root, rim, Color("d0b987"), Vector3(0.042, 0.006, -0.025))
	_part(root, case, Color("b9a16f"), Vector3(-0.023, 0.065, 0.026))
	_part(root, bullet, Color("c4b69b"), Vector3(-0.023, 0.128, 0.026))
	_part(root, rim, Color("d0b987"), Vector3(-0.023, 0.006, 0.026))
	_part(root, case, Color("b9a16f"), Vector3(0.026, 0.065, 0.028))
	_part(root, bullet, Color("c4b69b"), Vector3(0.026, 0.128, 0.028))
	_part(root, rim, Color("d0b987"), Vector3(0.026, 0.006, 0.028))


## Four upright muted red shotgun shells with broad brass heads and closed crimps.
static func _ammo_shell(root: Node3D) -> void:
	var hull: CylinderMesh = CylinderMesh.new()
	hull.top_radius = 0.027
	hull.bottom_radius = 0.027
	hull.height = 0.126
	hull.radial_segments = 12
	var head: CylinderMesh = CylinderMesh.new()
	head.top_radius = 0.03
	head.bottom_radius = 0.03
	head.height = 0.034
	head.radial_segments = 12
	var crimp: CylinderMesh = CylinderMesh.new()
	crimp.top_radius = 0.025
	crimp.bottom_radius = 0.025
	crimp.height = 0.009
	crimp.radial_segments = 12

	_part(root, hull, Color("995f59"), Vector3(-0.037, 0.087, -0.034))
	_part(root, head, Color("b6a173"), Vector3(-0.037, 0.017, -0.034))
	_part(root, crimp, Color("b18173"), Vector3(-0.037, 0.151, -0.034))
	_part(root, hull, Color("995f59"), Vector3(0.034, 0.087, -0.029))
	_part(root, head, Color("b6a173"), Vector3(0.034, 0.017, -0.029))
	_part(root, crimp, Color("b18173"), Vector3(0.034, 0.151, -0.029))
	_part(root, hull, Color("995f59"), Vector3(-0.028, 0.087, 0.031))
	_part(root, head, Color("b6a173"), Vector3(-0.028, 0.017, 0.031))
	_part(root, crimp, Color("b18173"), Vector3(-0.028, 0.151, 0.031))
	_part(root, hull, Color("995f59"), Vector3(0.041, 0.087, 0.037))
	_part(root, head, Color("b6a173"), Vector3(0.041, 0.017, 0.037))
	_part(root, crimp, Color("b18173"), Vector3(0.041, 0.151, 0.037))


## A dark amber bottle with a large uneven broken neck, dark mouth and one muted highlight.
static func _bottle_broken(root: Node3D) -> void:
	var body: CylinderMesh = CylinderMesh.new()
	body.top_radius = 0.065
	body.bottom_radius = 0.065
	body.height = 0.175
	body.radial_segments = 14
	var shoulder: CylinderMesh = CylinderMesh.new()
	shoulder.top_radius = 0.033
	shoulder.bottom_radius = 0.065
	shoulder.height = 0.05
	shoulder.radial_segments = 14
	var neck: CylinderMesh = CylinderMesh.new()
	neck.top_radius = 0.032
	neck.bottom_radius = 0.032
	neck.height = 0.034
	neck.radial_segments = 12
	var mouth: CylinderMesh = CylinderMesh.new()
	mouth.top_radius = 0.022
	mouth.bottom_radius = 0.022
	mouth.height = 0.012
	mouth.radial_segments = 12
	var shard: PrismMesh = PrismMesh.new()
	shard.size = Vector3(0.028, 0.079, 0.026)
	var reflection: BoxMesh = BoxMesh.new()
	reflection.size = Vector3(0.012, 0.115, 0.012)

	_part(root, body, Color("6b5135"), Vector3(0, 0.0875, 0))
	_part(root, shoulder, Color("735838"), Vector3(0, 0.2, 0))
	_part(root, neck, Color("624a31"), Vector3(0, 0.239, 0))
	_part(root, mouth, Color("4a402e"), Vector3(0, 0.263, 0))
	_part(root, shard, Color("7c623c"), Vector3(-0.023, 0.284, 0.007), Vector3(0, -12, -13))
	_part(root, shard, Color("8a6d43"), Vector3(0.021, 0.309, -0.013), Vector3(0, 24, 16))
	_part(root, shard, Color("725332"), Vector3(0.003, 0.286, 0.027), Vector3(0, -28, -7))
	_part(root, reflection, Color("967e54"), Vector3(-0.022, 0.093, 0.063))


## A thick wooden stake with a four-sided sharpened point and pale carving marks.
static func _stake(root: Node3D) -> void:
	var timber: BoxMesh = BoxMesh.new()
	timber.size = Vector3(0.314, 0.076, 0.077)
	var point: CylinderMesh = CylinderMesh.new()
	point.top_radius = 0
	point.bottom_radius = 0.049
	point.height = 0.12
	point.radial_segments = 4
	var carving: BoxMesh = BoxMesh.new()
	carving.size = Vector3(0.073, 0.009, 0.045)
	var grain: BoxMesh = BoxMesh.new()
	grain.size = Vector3(0.22, 0.009, 0.01)

	_part(root, timber, Color("9a8668"), Vector3(-0.036, 0.069296, 0))
	_part(root, point, Color("c1ab82"), Vector3(0.181, 0.069296, 0), Vector3(45, 0, -90))
	_part(root, carving, Color("c6b38f"), Vector3(0.105, 0.110296, 0), Vector3(0, 0, -5))
	_part(root, carving, Color("b6a17c"), Vector3(0.083, 0.068296, 0.043), Vector3(90, 0, -12))
	_part(root, grain, Color("786b55"), Vector3(-0.041, 0.111296, 0.018), Vector3(0, 3, 0))


## A large plain blue pack with a top flap, front pocket, two side-visible shoulder straps and buckles.
static func _pack(root: Node3D) -> void:
	var body: BoxMesh = BoxMesh.new()
	body.size = Vector3(0.2, 0.25, 0.12)
	var base: BoxMesh = BoxMesh.new()
	base.size = Vector3(0.21, 0.02, 0.13)
	var flap: BoxMesh = BoxMesh.new()
	flap.size = Vector3(0.218, 0.035, 0.137)
	var flap_fold: CylinderMesh = CylinderMesh.new()
	flap_fold.top_radius = 0.0175
	flap_fold.bottom_radius = 0.0175
	flap_fold.height = 0.218
	flap_fold.radial_segments = 12
	var pocket: BoxMesh = BoxMesh.new()
	pocket.size = Vector3(0.14, 0.105, 0.045)
	var pocket_fold: CylinderMesh = CylinderMesh.new()
	pocket_fold.top_radius = 0.016
	pocket_fold.bottom_radius = 0.016
	pocket_fold.height = 0.14
	pocket_fold.radial_segments = 12
	var shoulder_strap: TorusMesh = TorusMesh.new()
	shoulder_strap.inner_radius = 0.047
	shoulder_strap.outer_radius = 0.063
	shoulder_strap.rings = 20
	shoulder_strap.ring_segments = 8
	var strap_mount: BoxMesh = BoxMesh.new()
	strap_mount.size = Vector3(0.03, 0.03, 0.04)
	var buckle: TorusMesh = TorusMesh.new()
	buckle.inner_radius = 0.007
	buckle.outer_radius = 0.02
	buckle.rings = 20
	buckle.ring_segments = 8
	var front_strap: BoxMesh = BoxMesh.new()
	front_strap.size = Vector3(0.016, 0.13, 0.014)

	_part(root, body, Color("4d6080"), Vector3(0, 0.135, 0))
	_part(root, base, Color("4d6080"), Vector3(0, 0.01, 0))
	_part(root, flap, Color("4d6080"), Vector3(0, 0.275, 0.005))
	_part(root, flap_fold, Color("4d6080"), Vector3(0, 0.275, 0.0735), Vector3(0, 0, 90))
	_part(root, pocket, Color("4d6080"), Vector3(0, 0.1, 0.076))
	_part(root, pocket_fold, Color("4d6080"), Vector3(0, 0.15, 0.099), Vector3(0, 0, 90))
	var shoulder_strap_part_1: MeshInstance3D = _part(root, shoulder_strap, Color("4d6080"), Vector3(-0.12, 0.15, -0.02), Vector3(0, 0, 90))
	shoulder_strap_part_1.scale = Vector3(1.6, 1, 0.8)
	var shoulder_strap_part_2: MeshInstance3D = _part(root, shoulder_strap, Color("4d6080"), Vector3(0.12, 0.15, -0.02), Vector3(0, 0, 90))
	shoulder_strap_part_2.scale = Vector3(1.6, 1, 0.8)
	_part(root, strap_mount, Color("4d6080"), Vector3(-0.105, 0.07, -0.035))
	_part(root, strap_mount, Color("4d6080"), Vector3(-0.105, 0.23, -0.035))
	_part(root, strap_mount, Color("4d6080"), Vector3(0.105, 0.07, -0.035))
	_part(root, strap_mount, Color("4d6080"), Vector3(0.105, 0.23, -0.035))
	_part(root, buckle, Color("a18b5b"), Vector3(-0.05, 0.175, 0.069), Vector3(90, 0, 0))
	_part(root, buckle, Color("a18b5b"), Vector3(0.05, 0.175, 0.069), Vector3(90, 0, 0))
	_part(root, front_strap, Color("4d6080"), Vector3(-0.05, 0.2, 0.068))
	_part(root, front_strap, Color("4d6080"), Vector3(0.05, 0.2, 0.068))


## Four loose copper wire coils and one thick projecting end.
static func _wire(root: Node3D) -> void:
	var coil: TorusMesh = TorusMesh.new()
	coil.inner_radius = 0.084
	coil.outer_radius = 0.1
	coil.rings = 20
	coil.ring_segments = 8
	var end_wire: CapsuleMesh = CapsuleMesh.new()
	end_wire.radius = 0.007
	end_wire.height = 0.14
	end_wire.radial_segments = 12
	end_wire.rings = 6

	_part(root, coil, Color("936c48"), Vector3(0, 0.008, 0))
	_part(root, coil, Color("936c48"), Vector3(0, 0.026, 0))
	_part(root, coil, Color("936c48"), Vector3(0, 0.044, 0))
	_part(root, coil, Color("936c48"), Vector3(0, 0.062, 0))
	_part(root, end_wire, Color("936c48"), Vector3(0.15, 0.044, 0.02), Vector3(0, -20, 90))


## A small brown cough-medicine bottle, plain pale label and dark screw cap.
static func _syrup(root: Node3D) -> void:
	var body: CylinderMesh = CylinderMesh.new()
	body.top_radius = 0.058
	body.bottom_radius = 0.058
	body.height = 0.15
	body.radial_segments = 16
	var shoulder: SphereMesh = SphereMesh.new()
	shoulder.radius = 0.058
	shoulder.height = 0.06
	shoulder.radial_segments = 16
	shoulder.rings = 8
	var neck: CylinderMesh = CylinderMesh.new()
	neck.top_radius = 0.025
	neck.bottom_radius = 0.025
	neck.height = 0.04
	neck.radial_segments = 12
	var label: CylinderMesh = CylinderMesh.new()
	label.top_radius = 0.059
	label.bottom_radius = 0.059
	label.height = 0.067
	label.radial_segments = 16
	var cap: CylinderMesh = CylinderMesh.new()
	cap.top_radius = 0.034
	cap.bottom_radius = 0.034
	cap.height = 0.032
	cap.radial_segments = 12
	var cap_rim: CylinderMesh = CylinderMesh.new()
	cap_rim.top_radius = 0.036
	cap_rim.bottom_radius = 0.036
	cap_rim.height = 0.012
	cap_rim.radial_segments = 12

	_part(root, body, Color("765337"), Vector3(0, 0.075, 0))
	_part(root, shoulder, Color("765337"), Vector3(0, 0.15, 0))
	_part(root, neck, Color("765337"), Vector3(0, 0.19, 0))
	_part(root, label, Color("ccc7ad"), Vector3(0, 0.085, 0))
	_part(root, cap, Color("383e43"), Vector3(0, 0.218, 0))
	_part(root, cap_rim, Color("383e43"), Vector3(0, 0.232, 0))


## A wristwatch with two hands on a pale round dial and a complete leather strap loop.
static func _clock(root: Node3D) -> void:
	var strap: TorusMesh = TorusMesh.new()
	strap.inner_radius = 0.066
	strap.outer_radius = 0.084
	strap.rings = 20
	strap.ring_segments = 8
	var mount: BoxMesh = BoxMesh.new()
	mount.size = Vector3(0.1, 0.026, 0.02)
	var case_body: CylinderMesh = CylinderMesh.new()
	case_body.top_radius = 0.052
	case_body.bottom_radius = 0.052
	case_body.height = 0.022
	case_body.radial_segments = 24
	var dial: CylinderMesh = CylinderMesh.new()
	dial.top_radius = 0.045
	dial.bottom_radius = 0.045
	dial.height = 0.012
	dial.radial_segments = 24
	var minute_hand: BoxMesh = BoxMesh.new()
	minute_hand.size = Vector3(0.012, 0.043, 0.012)
	var hour_hand: BoxMesh = BoxMesh.new()
	hour_hand.size = Vector3(0.031, 0.012, 0.012)
	var pivot: CylinderMesh = CylinderMesh.new()
	pivot.top_radius = 0.008
	pivot.bottom_radius = 0.008
	pivot.height = 0.014
	pivot.radial_segments = 12

	_part(root, strap, Color("77563e"), Vector3(0, 0.084, 0), Vector3(90, 0, 0))
	_part(root, mount, Color("77563e"), Vector3(0, 0.151, 0.006))
	_part(root, case_body, Color("988158"), Vector3(0, 0.151, 0.025), Vector3(90, 0, 0))
	_part(root, dial, Color("c5c0a6"), Vector3(0, 0.151, 0.038), Vector3(90, 0, 0))
	_part(root, minute_hand, Color("494f3d"), Vector3(0.008745, 0.170641, 0.05), Vector3(0, 0, -24))
	_part(root, hour_hand, Color("494f3d"), Vector3(0.014048, 0.144449, 0.05), Vector3(0, 0, -25))
	_part(root, pivot, Color("494f3d"), Vector3(0, 0.151, 0.052), Vector3(90, 0, 0))


## A brass pocket watch with a pale dial, top loop and a loose chain of broad links.
static func _pocket_watch(root: Node3D) -> void:
	var case_body: CylinderMesh = CylinderMesh.new()
	case_body.top_radius = 0.088
	case_body.bottom_radius = 0.088
	case_body.height = 0.048
	case_body.radial_segments = 28
	var bezel: TorusMesh = TorusMesh.new()
	bezel.inner_radius = 0.071
	bezel.outer_radius = 0.09
	bezel.rings = 20
	bezel.ring_segments = 8
	var dial: CylinderMesh = CylinderMesh.new()
	dial.top_radius = 0.071
	dial.bottom_radius = 0.071
	dial.height = 0.012
	dial.radial_segments = 28
	var minute_hand: BoxMesh = BoxMesh.new()
	minute_hand.size = Vector3(0.014, 0.012, 0.057)
	var hour_hand: BoxMesh = BoxMesh.new()
	hour_hand.size = Vector3(0.047, 0.012, 0.014)
	var winder: CylinderMesh = CylinderMesh.new()
	winder.top_radius = 0.018
	winder.bottom_radius = 0.018
	winder.height = 0.042
	winder.radial_segments = 12
	var top_loop: TorusMesh = TorusMesh.new()
	top_loop.inner_radius = 0.017
	top_loop.outer_radius = 0.031
	top_loop.rings = 20
	top_loop.ring_segments = 8
	var chain_link: TorusMesh = TorusMesh.new()
	chain_link.inner_radius = 0.006
	chain_link.outer_radius = 0.019
	chain_link.rings = 20
	chain_link.ring_segments = 8

	_part(root, case_body, Color("a18b56"), Vector3(0, 0.024, 0))
	_part(root, bezel, Color("b09a67"), Vector3(0, 0.047, 0))
	_part(root, dial, Color("c5c0a6"), Vector3(0, 0.049, 0))
	_part(root, minute_hand, Color("554e38"), Vector3(-0.009, 0.06, -0.024), Vector3(0, 20, 0))
	_part(root, hour_hand, Color("554e38"), Vector3(0.019, 0.06, 0.005), Vector3(0, -15, 0))
	_part(root, winder, Color("927b4d"), Vector3(0, 0.029, -0.105), Vector3(90, 0, 0))
	_part(root, top_loop, Color("a18b56"), Vector3(0, 0.029, -0.139))
	_part(root, chain_link, Color("927b4d"), Vector3(0.018, 0.023, -0.169))
	_part(root, chain_link, Color("927b4d"), Vector3(0.045, 0.032, -0.183))
	_part(root, chain_link, Color("927b4d"), Vector3(0.07, 0.023, -0.193))
	_part(root, chain_link, Color("927b4d"), Vector3(0.095, 0.032, -0.19))
	_part(root, chain_link, Color("927b4d"), Vector3(0.117, 0.023, -0.174))
	_part(root, chain_link, Color("927b4d"), Vector3(0.129, 0.032, -0.15))
	_part(root, chain_link, Color("927b4d"), Vector3(0.134, 0.023, -0.124))
	_part(root, chain_link, Color("927b4d"), Vector3(0.129, 0.032, -0.098))


## An open shallow sewing tin, with three coloured spools and two silver scissor handle loops.
static func _sewing_kit(root: Node3D) -> void:
	var lid_frame: Node3D = Node3D.new()
	lid_frame.position = Vector3(0, 0.135505, -0.113809)
	lid_frame.rotation_degrees = Vector3(65, 0, 0)
	root.add_child(lid_frame)
	var tin: BoxMesh = BoxMesh.new()
	tin.size = Vector3(0.24, 0.06, 0.16)
	var inside: BoxMesh = BoxMesh.new()
	inside.size = Vector3(0.216, 0.012, 0.136)
	var rim_side: BoxMesh = BoxMesh.new()
	rim_side.size = Vector3(0.012, 0.018, 0.16)
	var rim_front: BoxMesh = BoxMesh.new()
	rim_front.size = Vector3(0.24, 0.018, 0.012)
	var lid: BoxMesh = BoxMesh.new()
	lid.size = Vector3(0.24, 0.014, 0.16)
	var hinge: CylinderMesh = CylinderMesh.new()
	hinge.top_radius = 0.008
	hinge.bottom_radius = 0.008
	hinge.height = 0.24
	hinge.radial_segments = 12
	var spool: CylinderMesh = CylinderMesh.new()
	spool.top_radius = 0.027
	spool.bottom_radius = 0.027
	spool.height = 0.054
	spool.radial_segments = 12
	var spool_end: CylinderMesh = CylinderMesh.new()
	spool_end.top_radius = 0.032
	spool_end.bottom_radius = 0.032
	spool_end.height = 0.012
	spool_end.radial_segments = 12
	var scissor_grip: TorusMesh = TorusMesh.new()
	scissor_grip.inner_radius = 0.012
	scissor_grip.outer_radius = 0.026
	scissor_grip.rings = 20
	scissor_grip.ring_segments = 8
	var scissor_blade: BoxMesh = BoxMesh.new()
	scissor_blade.size = Vector3(0.012, 0.012, 0.068)

	_part(root, tin, Color("7e8360"), Vector3(0, 0.03, 0))
	_part(root, inside, Color("685f45"), Vector3(0, 0.064, 0))
	_part(root, rim_side, Color("909b76"), Vector3(-0.12, 0.063, 0))
	_part(root, rim_side, Color("909b76"), Vector3(0.12, 0.063, 0))
	_part(root, rim_front, Color("909b76"), Vector3(0, 0.063, 0.08))
	_part(lid_frame, lid, Color("7e8360"), Vector3(0, 0, 0))
	_part(root, hinge, Color("909b76"), Vector3(0, 0.063, -0.08), Vector3(0, 0, 90))
	_part(root, spool, Color("507a73"), Vector3(-0.067, 0.095, -0.005))
	_part(root, spool, Color("965c49"), Vector3(0, 0.095, -0.005))
	_part(root, spool, Color("a08d55"), Vector3(0.067, 0.095, -0.005))
	_part(root, spool_end, Color("ac9772"), Vector3(-0.067, 0.07, -0.005))
	_part(root, spool_end, Color("ac9772"), Vector3(-0.067, 0.128, -0.005))
	_part(root, spool_end, Color("ac9772"), Vector3(0, 0.07, -0.005))
	_part(root, spool_end, Color("ac9772"), Vector3(0, 0.128, -0.005))
	_part(root, spool_end, Color("ac9772"), Vector3(0.067, 0.07, -0.005))
	_part(root, spool_end, Color("ac9772"), Vector3(0.067, 0.128, -0.005))
	_part(root, scissor_grip, Color("9baaa7"), Vector3(0.03, 0.079, 0.055))
	_part(root, scissor_grip, Color("9baaa7"), Vector3(0.088, 0.079, 0.055))
	_part(root, scissor_blade, Color("9baaa7"), Vector3(0.057, 0.076, 0.011), Vector3(0, 12, 0))


## One coloured thread spool, a thick silver needle with an open eye and a loose strand.
static func _needle(root: Node3D) -> void:
	var spool: CylinderMesh = CylinderMesh.new()
	spool.top_radius = 0.046
	spool.bottom_radius = 0.046
	spool.height = 0.1
	spool.radial_segments = 16
	var spool_end: CylinderMesh = CylinderMesh.new()
	spool_end.top_radius = 0.052
	spool_end.bottom_radius = 0.052
	spool_end.height = 0.015
	spool_end.radial_segments = 16
	var needle: CylinderMesh = CylinderMesh.new()
	needle.top_radius = 0.006
	needle.bottom_radius = 0.006
	needle.height = 0.22
	needle.radial_segments = 10
	var eye: TorusMesh = TorusMesh.new()
	eye.inner_radius = 0.005
	eye.outer_radius = 0.018
	eye.rings = 20
	eye.ring_segments = 8
	var loose_thread: CapsuleMesh = CapsuleMesh.new()
	loose_thread.radius = 0.007
	loose_thread.height = 0.16
	loose_thread.radial_segments = 12
	loose_thread.rings = 6

	_part(root, spool, Color("925c50"), Vector3(-0.055, 0.065, 0))
	_part(root, spool_end, Color("a18b61"), Vector3(-0.055, 0.0075, 0))
	_part(root, spool_end, Color("a18b61"), Vector3(-0.055, 0.1175, 0))
	_part(root, needle, Color("9baaaa"), Vector3(-0.015, 0.165, 0.012), Vector3(0, 0, -20))
	_part(root, eye, Color("9baaaa"), Vector3(0.027, 0.283, 0.012), Vector3(90, 0, 0))
	_part(root, loose_thread, Color("925c50"), Vector3(0.055, 0.014, 0.052), Vector3(0, -10, 90))


## A round-topped leather doctor's bag, one handle and brass clasps, with no emblem.
static func _doctor_box(root: Node3D) -> void:
	var body: BoxMesh = BoxMesh.new()
	body.size = Vector3(0.235, 0.16, 0.14)
	var rounded_top: CylinderMesh = CylinderMesh.new()
	rounded_top.top_radius = 0.073
	rounded_top.bottom_radius = 0.073
	rounded_top.height = 0.235
	rounded_top.radial_segments = 20
	var handle: TorusMesh = TorusMesh.new()
	handle.inner_radius = 0.032
	handle.outer_radius = 0.049
	handle.rings = 20
	handle.ring_segments = 8
	var clasp: BoxMesh = BoxMesh.new()
	clasp.size = Vector3(0.025, 0.035, 0.016)
	var top_seam: BoxMesh = BoxMesh.new()
	top_seam.size = Vector3(0.235, 0.014, 0.016)

	_part(root, body, Color("73553c"), Vector3(0, 0.08, 0))
	_part(root, rounded_top, Color("73553c"), Vector3(0, 0.16, 0), Vector3(0, 0, 90))
	var handle_part_1: MeshInstance3D = _part(root, handle, Color("624a35"), Vector3(0, 0.264, 0), Vector3(90, 0, 0))
	handle_part_1.scale = Vector3(1.2, 1, 1)
	_part(root, clasp, Color("a78b56"), Vector3(-0.055, 0.185, 0.075))
	_part(root, clasp, Color("a78b56"), Vector3(0.055, 0.185, 0.075))
	_part(root, top_seam, Color("624a35"), Vector3(0, 0.205, 0.045))


## A green herb book with a thick paper block and a raised three-leaf cover motif.
static func _book(root: Node3D) -> void:
	var cover: BoxMesh = BoxMesh.new()
	cover.size = Vector3(0.22, 0.016, 0.28)
	var pages: BoxMesh = BoxMesh.new()
	pages.size = Vector3(0.204, 0.06, 0.263)
	var spine: BoxMesh = BoxMesh.new()
	spine.size = Vector3(0.023, 0.086, 0.285)
	var plant_stem: CylinderMesh = CylinderMesh.new()
	plant_stem.top_radius = 0.006
	plant_stem.bottom_radius = 0.006
	plant_stem.height = 0.16
	plant_stem.radial_segments = 10
	var leaf: SphereMesh = SphereMesh.new()
	leaf.radius = 0.033
	leaf.height = 0.014
	leaf.radial_segments = 16
	leaf.rings = 8

	_part(root, cover, Color("52734d"), Vector3(0, 0.008, 0))
	_part(root, cover, Color("52734d"), Vector3(0, 0.084, 0))
	_part(root, pages, Color("c2b99d"), Vector3(0, 0.046, 0))
	_part(root, spine, Color("435d3e"), Vector3(-0.105, 0.047, 0))
	_part(root, plant_stem, Color("91a16b"), Vector3(0, 0.095, 0.02), Vector3(90, 0, 0))
	var leaf_part_1: MeshInstance3D = _part(root, leaf, Color("91a16b"), Vector3(-0.025, 0.094, -0.018), Vector3(0, -35, 0))
	leaf_part_1.scale = Vector3(0.65, 1, 1.2)
	var leaf_part_2: MeshInstance3D = _part(root, leaf, Color("91a16b"), Vector3(0.025, 0.094, 0.035), Vector3(0, 35, 0))
	leaf_part_2.scale = Vector3(0.65, 1, 1.2)
	var leaf_part_3: MeshInstance3D = _part(root, leaf, Color("91a16b"), Vector3(-0.018, 0.094, 0.076), Vector3(0, -25, 0))
	leaf_part_3.scale = Vector3(0.65, 1, 1.2)


## A pale blue-grey saline pouch with a hanging eye, two rubber ports, blank white label and one 12 mm tube.
static func _saline(root: Node3D) -> void:
	# Existing opaque flat colours suggest frosted PVC, the liquid level and sealed edges.
	var assembly: Node3D = Node3D.new()
	assembly.position = Vector3(0, 0.129311, 0)
	root.add_child(assembly)
	var pouch: BoxMesh = BoxMesh.new()
	pouch.size = Vector3(0.16, 0.21, 0.04)
	var side_edge: CylinderMesh = CylinderMesh.new()
	side_edge.top_radius = 0.02
	side_edge.bottom_radius = 0.02
	side_edge.height = 0.21
	side_edge.radial_segments = 12
	var bottom_fold: CylinderMesh = CylinderMesh.new()
	bottom_fold.top_radius = 0.02
	bottom_fold.bottom_radius = 0.02
	bottom_fold.height = 0.16
	bottom_fold.radial_segments = 12
	var top_seal: BoxMesh = BoxMesh.new()
	top_seal.size = Vector3(0.184, 0.022, 0.048)
	var hanger_eye: TorusMesh = TorusMesh.new()
	hanger_eye.inner_radius = 0.012
	hanger_eye.outer_radius = 0.026
	hanger_eye.rings = 20
	hanger_eye.ring_segments = 8
	var rubber_port: CylinderMesh = CylinderMesh.new()
	rubber_port.top_radius = 0.012
	rubber_port.bottom_radius = 0.012
	rubber_port.height = 0.045
	rubber_port.radial_segments = 12
	var liquid: BoxMesh = BoxMesh.new()
	liquid.size = Vector3(0.13, 0.09, 0.012)
	var label: BoxMesh = BoxMesh.new()
	label.size = Vector3(0.112, 0.077, 0.012)
	_part(assembly, pouch, Color("74979c"), Vector3(0, 0.14, 0))
	_part(assembly, side_edge, Color("74979c"), Vector3(-0.08, 0.14, 0))
	_part(assembly, side_edge, Color("74979c"), Vector3(0.08, 0.14, 0))
	_part(assembly, bottom_fold, Color("74979c"), Vector3(0, 0.035, 0), Vector3(0, 0, 90))
	_part(assembly, top_seal, Color("98b3b7"), Vector3(0, 0.239, 0))
	_part(assembly, hanger_eye, Color("98b3b7"), Vector3(0, 0.272, 0), Vector3(90, 0, 0))
	_part(assembly, rubber_port, Color("626f67"), Vector3(-0.039, 0.0165, 0))
	_part(assembly, rubber_port, Color("626f67"), Vector3(0.039, 0.0165, 0))
	_part(assembly, liquid, Color("6f929a"), Vector3(0, 0.095, 0.02))
	_part(assembly, label, Color("c6cbbf"), Vector3(0, 0.145, 0.023))
	# One closed 12 mm hose; rings share positions and normals along a smooth path.
	var vertices: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var add_triangle: Callable = func(corners: PackedVector3Array, face_normals: PackedVector3Array) -> void:
		var order: Array[int] = [0, 1, 2]
		if (corners[1] - corners[0]).cross(corners[2] - corners[0]).dot(face_normals[0]) > 0.0:
			order = [0, 2, 1]
		for corner_index: int in order:
			vertices.append(corners[corner_index])
			normals.append(face_normals[corner_index])
	var centers: Array[Vector3] = []
	for row: int in 13:
		var ratio: float = float(row) / 12.0
		centers.append(Vector3(0.039 + 0.045 * sin(PI * ratio * 0.5), -0.005 - 0.12 * ratio, 0.04 * sin(PI * ratio)))
	var tangents: Array[Vector3] = []
	var rings: Array[PackedVector3Array] = []
	var ring_normals: Array[PackedVector3Array] = []
	for row: int in centers.size():
		var tangent: Vector3 = (centers[mini(row + 1, centers.size() - 1)] - centers[maxi(row - 1, 0)]).normalized()
		tangents.append(tangent)
		var across: Vector3 = Vector3.BACK.cross(tangent).normalized()
		var around: Vector3 = tangent.cross(across).normalized()
		var ring_points: PackedVector3Array = PackedVector3Array()
		var radial_normals: PackedVector3Array = PackedVector3Array()
		for side: int in 8:
			var angle: float = TAU * float(side) / 8.0
			var radial: Vector3 = across * cos(angle) + around * sin(angle)
			ring_points.append(centers[row] + radial * 0.006)
			radial_normals.append(radial)
		rings.append(ring_points)
		ring_normals.append(radial_normals)
	for row: int in centers.size() - 1:
		for side: int in 8:
			var next_side: int = (side + 1) % 8
			var a: Vector3 = rings[row][side]
			var b: Vector3 = rings[row][next_side]
			var c: Vector3 = rings[row + 1][side]
			var d: Vector3 = rings[row + 1][next_side]
			var na: Vector3 = ring_normals[row][side]
			var nb: Vector3 = ring_normals[row][next_side]
			var nc: Vector3 = ring_normals[row + 1][side]
			var nd: Vector3 = ring_normals[row + 1][next_side]
			add_triangle.call(PackedVector3Array([a, b, c]), PackedVector3Array([na, nb, nc]))
			add_triangle.call(PackedVector3Array([b, d, c]), PackedVector3Array([nb, nd, nc]))
	for cap_row: int in [0, centers.size() - 1]:
		var cap_normal: Vector3 = -tangents[cap_row] if cap_row == 0 else tangents[cap_row]
		for side: int in 8:
			var next_side: int = (side + 1) % 8
			add_triangle.call(PackedVector3Array([centers[cap_row], rings[cap_row][side], rings[cap_row][next_side]]), PackedVector3Array([cap_normal, cap_normal, cap_normal]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	var tube: ArrayMesh = ArrayMesh.new()
	tube.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_part(assembly, tube, Color("77999b"), Vector3.ZERO)


## A worn teddy bear sitting up: round body and head, ears, muzzle, arms and
## legs forward, a faded red bow; warm brown plush, no face paint but two eyes.
static func _teddy(root: Node3D) -> void:
	var fur := Color("8a6a4c")
	var pale := Color("b89c7c")
	var body := SphereMesh.new()
	body.radius = 0.075
	body.height = 0.16
	_part(root, body, fur, Vector3(0, 0.08, 0))
	var belly := SphereMesh.new()
	belly.radius = 0.05
	belly.height = 0.1
	_part(root, belly, pale, Vector3(0, 0.08, 0.04)).scale = Vector3(1, 1, 0.6)
	var head := SphereMesh.new()
	head.radius = 0.062
	head.height = 0.12
	_part(root, head, fur, Vector3(0, 0.2, 0.01))
	var ear := SphereMesh.new()
	ear.radius = 0.024
	ear.height = 0.048
	for side: float in [-1.0, 1.0]:
		_part(root, ear, fur, Vector3(0.047 * side, 0.252, 0.0)).scale = Vector3(1, 1, 0.6)
		var arm := CapsuleMesh.new()
		arm.radius = 0.022
		arm.height = 0.09
		_part(root, arm, fur, Vector3(0.078 * side, 0.115, 0.02), Vector3(0, 0, 38.0 * side))
		var leg := CapsuleMesh.new()
		leg.radius = 0.027
		leg.height = 0.085
		_part(root, leg, fur, Vector3(0.042 * side, 0.028, 0.055), Vector3(80, 0, 0))
		var eye := SphereMesh.new()
		eye.radius = 0.008
		eye.height = 0.016
		_part(root, eye, Color("3a332c"), Vector3(0.022 * side, 0.214, 0.064))
	var muzzle := SphereMesh.new()
	muzzle.radius = 0.028
	muzzle.height = 0.04
	_part(root, muzzle, pale, Vector3(0, 0.188, 0.058))
	var nose := SphereMesh.new()
	nose.radius = 0.01
	nose.height = 0.016
	_part(root, nose, Color("3a332c"), Vector3(0, 0.196, 0.084))
	var bow := TorusMesh.new()
	bow.inner_radius = 0.05
	bow.outer_radius = 0.064
	_part(root, bow, Color("8e3328"), Vector3(0, 0.145, 0.005))
