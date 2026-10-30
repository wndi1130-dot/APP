extends RefCounted
## The decorating view of one car (결정 506 직접 놓기, 510 꾸미기 화면 — the mock-up as drawn, its
## people faint; 511 the eight cars): the camera straight along the car looked down on at 55°, the car's length across
## the screen; the front wall away; the 0.5 m floor grid over the floor (decor_grid.gd) with its
## marks — a thing or the stove red, the walking line blue, a door's way grey, a free cell a faint
## white square — the wall places in sky blue, the surface places in yellow, and the cell a thing
## is held over green (it may go there) or red (it may not). The rules and the strip of things are
## the domestic side's (TrainMods, decor_strip.gd); this only draws and finds the place under a finger.

const DecorGrid = preload("res://game/train/decor_grid.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")

const PITCH: float = 55.0
## The car's length and a little of its neighbours across the screen.
const WIDTH_M: float = 16.6
## What the camera looks at in the car's own space: its middle, a little over the floor.
const LOOK := Vector3(8.0, 0.6, 0.0)
## The band the car sits in, in the mock-up's CSS px: under the exit and title row (46) and over
## the store strip (134); the floor's middle sits this far under the band's middle so the walls rising
## behind it fill the band, as the approved mock-up has it (decor_cam_1688.png: its grid lines at
## 309, 349, 390, 431, 472 px of 780).
const TOP_CSS: float = 46.0
const BOTTOM_CSS: float = 134.0
const WALLS_UP_CSS: float = 17.0
## The people while a car is dressed: seen, but through (train_people_view.gd set_faded).
const PEOPLE_FADE: float = 0.6
## Wall places: a square on the back wall's cell, this high. The camera looks straight along the car,
## so an end wall is seen edge on: its two places stand against it as the same squares turned to the
## camera, one at each cell's middle across the car, and are found on that square, not on the wall.
const WALL_PLACE_Y: float = 1.45
const WALL_PLACE_H: float = 0.6
const BACK_Z: float = -1.29
const END_X: Array[float] = [0.12, 15.88]
const WALL_LOW: float = 0.6
const WALL_HIGH: float = 2.2
const MARK_COLORS := {
	".": Color(1.0, 1.0, 1.0, 0.06), "#": Color(0.85, 0.25, 0.2, 0.28), "S": Color(0.85, 0.25, 0.2, 0.28),
	"D": Color(0.5, 0.5, 0.5, 0.22), "W": Color(0.3, 0.55, 0.9, 0.2),
}
const LINE_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const WALL_COLOR := Color(0.4, 0.8, 0.9, 0.22)
const SURFACE_COLOR := Color(0.95, 0.85, 0.4, 0.35)
const OK_COLOR := Color(0.35, 0.85, 0.4, 0.45)
const NO_COLOR := Color(0.9, 0.3, 0.25, 0.45)

var car: Dictionary = {}
var cells: Dictionary = {}
var marks: Node3D
var cursor: MeshInstance3D
var _faded: Dictionary = {}          # GeometryInstance3D -> its transparency before


## Builds the marks in the car and fades the people; the scene places the camera (place_camera).
func enter(scene, c: Dictionary) -> bool:
	cells = DecorGrid.of(String(c["id"]))
	if cells.is_empty():
		return false
	car = c
	var node: Node3D = c["node"]
	marks = Node3D.new()
	marks.name = "DecorMarks"
	node.add_child(marks)
	_floor_marks()
	_wall_marks()
	cursor = _quad(Vector2(DecorGrid.CELL * 0.94, DecorGrid.CELL * 0.94), OK_COLOR)
	cursor.name = "DecorCursor"
	cursor.visible = false
	marks.add_child(cursor)
	_fade_people(scene, true)
	return true


func exit(scene) -> void:
	_fade_people(scene, false)
	if is_instance_valid(marks):
		# Out of the car at once, so a car opened again this frame takes the name back.
		if marks.get_parent() != null:
			marks.get_parent().remove_child(marks)
		marks.queue_free()
	marks = null
	cursor = null
	car = {}


## The decorating camera, as the mock-up drew it, on the scene's own camera: set in the car's own
## space and carried out by its transform, so a car moved or turned in the train is seen the same.
func place_camera(scene) -> void:
	var cam: Camera3D = scene.camera
	var node: Node3D = car["node"]
	var view: Vector2 = scene.get_viewport().get_visible_rect().size
	var px_per_m: float = view.x / WIDTH_M
	var pitch := deg_to_rad(PITCH)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = view.y / px_per_m
	var to_world: Transform3D = node.global_transform
	var anchor: Vector3 = to_world * LOOK
	var eye: Vector3 = to_world * (LOOK + Vector3(0.0, sin(pitch), cos(pitch)) * 30.0)
	cam.global_transform = Transform3D(Basis.looking_at(anchor - eye, to_world.basis.y.normalized()), eye)
	cam.h_offset = 0.0
	var band_mid: float = (UiFonts.px(TOP_CSS) + view.y - UiFonts.px(BOTTOM_CSS)) * 0.5 + UiFonts.px(WALLS_UP_CSS)
	cam.v_offset = (band_mid - view.y * 0.5) / px_per_m


## The place under a point of the screen: {spot: "floor", at: [ix, iz]}, {spot: "wall", at: [ix, -1]}
## on the back wall or [-1 | 31, iz] on an end wall, or {} off the car. The nearest face the ray meets.
func pick(scene, screen: Vector2) -> Dictionary:
	var cam: Camera3D = scene.camera
	var node: Node3D = car["node"]
	var inv: Transform3D = node.global_transform.affine_inverse()
	var o: Vector3 = inv * cam.project_ray_origin(screen)
	var d: Vector3 = inv.basis * cam.project_ray_normal(screen)
	var best := {}
	var best_t := INF
	if absf(d.y) > 0.00001:
		var t := -o.y / d.y
		var cell := DecorGrid.floor_cell(o + d * t)
		if t > 0.0 and cell.x >= 0:
			best = {"spot": "floor", "at": [cell.x, cell.y]}
			best_t = t
	if absf(d.z) > 0.00001:
		var t := (BACK_Z - o.z) / d.z
		var p := o + d * t
		var ix := floori((p.x - DecorGrid.X0) / DecorGrid.CELL)
		if t > 0.0 and t < best_t and p.y > WALL_LOW and p.y < WALL_HIGH and ix >= 0 and ix < DecorGrid.NX:
			best = {"spot": "wall", "at": [ix, -1]}
			best_t = t
	if absf(d.z) > 0.00001:
		for iz: int in 2:
			for side: int in 2:
				var mark := place_of("wall", [-1 if side == 0 else DecorGrid.NX, iz])
				var t := (mark.origin.z - o.z) / d.z
				var p := o + d * t
				var on_mark: bool = absf(p.x - mark.origin.x) < DecorGrid.CELL * 0.45 and absf(p.y - mark.origin.y) < WALL_PLACE_H * 0.5
				if t > 0.0 and t < best_t and on_mark:
					best = {"spot": "wall", "at": [-1 if side == 0 else DecorGrid.NX, iz]}
					best_t = t
	return best


## The cell a thing is held over: green where it may go, red where it may not; spot "" hides it.
func hover(spot: String, at: Array, ok: bool) -> void:
	if cursor == null:
		return
	cursor.visible = spot != ""
	if spot == "":
		return
	(cursor.material_override as StandardMaterial3D).albedo_color = OK_COLOR if ok else NO_COLOR
	var place := place_of(spot, at)
	cursor.transform = place


## Where a place's mark lies in the car's own space, facing the camera's side of its face.
static func place_of(spot: String, at: Array) -> Transform3D:
	var ix := int(at[0])
	var iz := int(at[1])
	if spot == "floor":
		return Transform3D(Basis.IDENTITY, DecorGrid.floor_center(ix, iz) + Vector3(0.0, 0.016, 0.0))
	if iz == -1:
		var x := DecorGrid.X0 + (ix + 0.5) * DecorGrid.CELL
		return Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, WALL_PLACE_Y, BACK_Z + 0.02))
	var end_x: float = END_X[0] + DecorGrid.CELL * 0.5 if ix < 0 else END_X[1] - DecorGrid.CELL * 0.5
	return Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(end_x, WALL_PLACE_Y, DecorGrid.Z0 + (iz + 0.5) * DecorGrid.CELL))


## Yellow places on the tops of the furniture things may stand on: [{at: Vector3 (car space), size: Vector2}].
func set_surfaces(places: Array) -> void:
	if marks == null:
		return
	var old := marks.get_node_or_null("Surfaces")
	if old != null:
		old.free()
	var holder := Node3D.new()
	holder.name = "Surfaces"
	marks.add_child(holder)
	for place: Dictionary in places:
		var q := _quad(place["size"], SURFACE_COLOR)
		q.position = place["at"]
		holder.add_child(q)


func _floor_marks() -> void:
	var floor_rows: Array = cells["floor"]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := PlaneMesh.new()
	quad.size = Vector2(DecorGrid.CELL * 0.94, DecorGrid.CELL * 0.94)
	mm.mesh = quad
	mm.instance_count = DecorGrid.NX * DecorGrid.NZ
	for iz in DecorGrid.NZ:
		for ix in DecorGrid.NX:
			var i := iz * DecorGrid.NX + ix
			var mark := String(floor_rows[iz])[ix]
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, DecorGrid.floor_center(ix, iz) + Vector3(0.0, 0.012, 0.0)))
			mm.set_instance_color(i, MARK_COLORS.get(mark, MARK_COLORS["."]))
	var draw := MultiMeshInstance3D.new()
	draw.name = "FloorCells"
	draw.multimesh = mm
	draw.material_override = _paint(Color.WHITE, true)
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marks.add_child(draw)
	var lines := PackedVector3Array()
	var x1: float = DecorGrid.X0 + DecorGrid.NX * DecorGrid.CELL
	var z1: float = DecorGrid.Z0 + DecorGrid.NZ * DecorGrid.CELL
	for ix in DecorGrid.NX + 1:
		var x: float = DecorGrid.X0 + ix * DecorGrid.CELL
		lines.append(Vector3(x, 0.015, DecorGrid.Z0))
		lines.append(Vector3(x, 0.015, z1))
	for iz in DecorGrid.NZ + 1:
		var z: float = DecorGrid.Z0 + iz * DecorGrid.CELL
		lines.append(Vector3(DecorGrid.X0, 0.015, z))
		lines.append(Vector3(x1, 0.015, z))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = lines
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var grid := MeshInstance3D.new()
	grid.name = "GridLines"
	grid.mesh = mesh
	grid.material_override = _paint(LINE_COLOR, false)
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marks.add_child(grid)


func _wall_marks() -> void:
	var back: String = cells["back_wall"]
	for ix in back.length():
		if back[ix] == ".":
			_wall_place([ix, -1])
	var ends: String = cells["end_walls"]
	for k in ends.length():
		if ends[k] == ".":
			_wall_place([-1 if k < 2 else DecorGrid.NX, k % 2])


func _wall_place(at: Array) -> void:
	var q := _quad(Vector2(DecorGrid.CELL * 0.9, WALL_PLACE_H), WALL_COLOR)
	q.name = "Wall_%d_%d" % [int(at[0]), int(at[1])]
	q.transform = place_of("wall", at)
	marks.add_child(q)


func _quad(size: Vector2, color: Color) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	var q := MeshInstance3D.new()
	q.mesh = plane
	q.material_override = _paint(color, false)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return q


static func _paint(color: Color, by_instance: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_color = color
	if by_instance:
		m.vertex_color_use_as_albedo = true
	return m


## Every body in the train seen through while decorating, and back as it was after: the baked
## bodies by their own shader (set_faded), the stand-ins by their nodes' transparency.
func _fade_people(scene, on: bool) -> void:
	if scene.people_view != null and scene.people_view.has_method("set_faded"):
		scene.people_view.set_faded(PEOPLE_FADE if on else 0.0)
	if not on:
		for geo in _faded:
			if is_instance_valid(geo):
				(geo as GeometryInstance3D).transparency = float(_faded[geo])
		_faded.clear()
		return
	if scene.people is Node:
		for geo: Node in (scene.people as Node).find_children("*", "GeometryInstance3D", true, false):
			_faded[geo] = (geo as GeometryInstance3D).transparency
			(geo as GeometryInstance3D).transparency = PEOPLE_FADE
