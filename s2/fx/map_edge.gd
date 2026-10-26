extends Node3D
## Past the map's edge (결정 448 17, 사용자 「맵끝이 대놓고 랜더링 되있음」): the
## ground goes on a way in the edge cells' own colours, under the map's own
## material (snow, puddles, leaf, cloud shadow and the sight mask all as on the
## map; the mask takes each edge cell's sight outward), and low fog sheets thicken
## over it until nothing past the map reads. The fence or the wood along the
## edge is map-layout's; this only hides what lies beyond it. The fog keeps the
## reference game's sheets: patchy noise near, solid farther out, the hour's
## fog colour (fx/atmosphere.gd fog_color).
## A foggy day lays fog over the whole field as well (색감 루프 C5): one layer
## over the screen (field_fog.gdshader), thin round the eye, closing in from
## where sight ends in the fog. Nothing is drawn for it on other days.

const MapView = preload("res://game/world/map_view.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FOG_SHADER := preload("res://fx/shaders/map_edge_fog.gdshader")
const FIELD_FOG_SHADER := preload("res://fx/shaders/field_fog.gdshader")
## The fog's own brightness under the light (a pale grey, as the reference
## game's (0.9, 0.9, 0.95) fog reads lit).
const FOG_ALBEDO := 0.8

## How far past the edge the ground and the fog go (the camera never shows more
## than about 30 m past it).
const MARGIN := 48.0
## The edge cells' colours give way to the edge's mean colour over this far.
const BLEND := 10.0
## The fog sheets: height (m) and how much each covers. Three, low to high, so
## a roof or a fence at the edge goes into the fog too.
const SHEETS: Array = [[0.35, 0.55], [1.5, 0.5], [3.2, 0.45]]
## The fog starts this far inside the edge and is solid this far out.
const FOG_INSET := 2.5
const FOG_REACH := 12.0

var ground: MeshInstance3D
var sheets: Array[MeshInstance3D] = []
var fog_mats: Array[ShaderMaterial] = []
## The foggy day's layer over the screen; hidden unless the look has fog.
var field: MeshInstance3D
var field_mat: ShaderMaterial
var _map_mat: ShaderMaterial
var _mask := -1.0
var _room := Rect2i(0, 0, -1, -1)


func setup(grid: FieldGrid, map_material: ShaderMaterial) -> void:
	name = "MapEdge"
	_map_mat = map_material
	var size := Vector2(grid.width, grid.height)
	ground = MeshInstance3D.new()
	ground.name = "EdgeGround"
	ground.mesh = ground_mesh(grid)
	ground.material_override = map_material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	for s in SHEETS:
		var m := ShaderMaterial.new()
		m.shader = FOG_SHADER
		m.set_shader_parameter("map_size", size)
		m.set_shader_parameter("inset", FOG_INSET)
		m.set_shader_parameter("reach", FOG_REACH)
		m.set_shader_parameter("layer_k", float(s[1]))
		m.set_shader_parameter("vis", map_material.get_shader_parameter("vis"))
		var node := MeshInstance3D.new()
		node.name = "EdgeFog"
		node.mesh = frame_mesh(size, FOG_INSET, MARGIN)
		node.position.y = float(s[0])
		node.material_override = m
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		sheets.append(node)
		fog_mats.append(m)
	field_mat = ShaderMaterial.new()
	field_mat.shader = FIELD_FOG_SHADER
	field_mat.render_priority = 100
	field = MeshInstance3D.new()
	field.name = "FieldFog"
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	field.mesh = quad
	field.material_override = field_mat
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader puts it over the screen; never culled.
	field.extra_cull_margin = 16384.0
	field.visible = false
	add_child(field)


## The hour's fog colour (Atmosphere.light fog_color).
func set_fog(color: Color) -> void:
	for m in fog_mats:
		m.set_shader_parameter("fog_color", color)


## The foggy day's fog over the field: how thick (Atmosphere.field_fog, 0 hides
## the layer), how far sight reaches in it (m, the sight mask's radius) and the
## hour's light (Atmosphere.light). The fog is lit as a pale up-facing sheet
## would be: half the hour's fog hue, half the reference's cool white.
func set_field_fog(amount: float, sight_m: float, light: Dictionary) -> void:
	field.visible = amount > 0.0
	field_mat.set_shader_parameter("field_fog", clampf(amount, 0.0, 1.0))
	field_mat.set_shader_parameter("clear_r", sight_m)
	field_mat.set_shader_parameter("fog_albedo", fog_albedo(light))
	field_mat.set_shader_parameter("fog_light", fog_light(light))


## Where the eye stands (the player): the fog over the field thins round it.
func set_eye(at: Vector3) -> void:
	if field.visible:
		field_mat.set_shader_parameter("clear_at", Vector2(at.x, at.z))


## The building the eye is in, its walls cut away (building_view open_b), by
## its footprint: the reference game lays no fog in a room, so the fog over the
## field lifts there. An empty rect when outside.
func set_room(r: Rect2i) -> void:
	if r == _room:
		return
	_room = r
	var v := Vector4(r.position.x, r.position.y, r.end.x, r.end.y) if r.has_area() else Vector4(0, 0, -1, -1)
	field_mat.set_shader_parameter("room", v)


## The fog's own linear colour (Atmosphere.light keys): half the hour's fog hue,
## half the reference's cool white, at a pale fog's brightness.
static func fog_albedo(light: Dictionary) -> Vector3:
	var fc: Color = light.get("fog_color", Color(0.6, 0.6, 0.62))
	var top := maxf(fc.r, maxf(fc.g, maxf(fc.b, 0.05)))
	var hue := Color(fc.r / top, fc.g / top, fc.b / top).lerp(Color(0.95, 0.95, 1.0), 0.5).srgb_to_linear()
	return Vector3(hue.r, hue.g, hue.b) * FOG_ALBEDO


## The hour's light on an up-facing sheet, linear: the sun by how high it
## stands and the fill, as the ground takes them. The shader fades the fog's
## colour first (the tactical pause, as world_vis does) and lights it after.
static func fog_light(light: Dictionary) -> Vector3:
	var sun := Color(light.get("sun_color", Color.WHITE)).srgb_to_linear()
	var amb := Color(light.get("ambient_color", Color.WHITE)).srgb_to_linear()
	var up := sin(deg_to_rad(clampf(-float(light.get("sun_pitch", -45.0)), 0.0, 90.0)))
	var se := float(light.get("sun_energy", 1.0)) * up
	var ae := float(light.get("ambient_energy", 1.0))
	return Vector3(sun.r * se + amb.r * ae, sun.g * se + amb.g * ae, sun.b * se + amb.b * ae)


func _process(_delta: float) -> void:
	# The fog dims with the sight mask the way the ground under it does.
	if _map_mat == null:
		return
	var m = _map_mat.get_shader_parameter("mask_on")
	var k := float(m) if m != null else 1.0
	if k != _mask:
		_mask = k
		for f in fog_mats:
			f.set_shader_parameter("mask_on", k)
		field_mat.set_shader_parameter("mask_on", k)


## The edge cells' mean colour (outdoor ground the most), the colour the ground
## past the map settles to.
static func mean_edge_color(grid: FieldGrid) -> Color:
	var sum := Color(0, 0, 0, 0)
	var n := 0.0
	for c in edge_cells(grid):
		var col: Color = MapView.FLOOR_COLORS[grid.floor_at(c)]
		var w := 1.0 if MapView.sky_alpha(grid, c) > 0.5 else 0.25
		sum += col * w
		n += w
	if n <= 0.0:
		return MapView.FLOOR_COLORS[0]
	var out := sum / n
	return Color(out.r, out.g, out.b, 1.0)


static func edge_cells(grid: FieldGrid) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(grid.width):
		out.append(Vector2i(x, 0))
		out.append(Vector2i(x, grid.height - 1))
	for y in range(1, grid.height - 1):
		out.append(Vector2i(0, y))
		out.append(Vector2i(grid.width - 1, y))
	return out


## The floor kind most of the edge is (open to the sky counting most), for the
## bare look past the blend (world_vis bare_ground).
static func mean_edge_kind(grid: FieldGrid) -> int:
	var count := {}
	for c in edge_cells(grid):
		var f := grid.floor_at(c)
		count[f] = float(count.get(f, 0.0)) + (1.0 if MapView.sky_alpha(grid, c) > 0.5 else 0.25)
	var best := 0
	for f in count:
		if count[f] > float(count.get(best, 0.0)):
			best = f
	return best


## Strips out from each edge cell: its colour at the edge, the mean colour BLEND
## metres out, the mean to MARGIN; the corners in the mean. Up-facing, open to
## the sky (vertex alpha 1), no snow bank (UV 0). UV2.x is the floor kind + 1:
## the edge cell's on its blend strip, the edge's commonest past it.
static func ground_mesh(grid: FieldGrid) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mean := mean_edge_color(grid)
	var mk := mean_edge_kind(grid)
	var w := float(grid.width)
	var h := float(grid.height)
	for x in range(grid.width):
		var top := _cell_color(grid, Vector2i(x, 0))
		var bottom := _cell_color(grid, Vector2i(x, grid.height - 1))
		var x0 := float(x)
		var x1 := float(x + 1)
		_quad(st, Vector3(x0, 0, -BLEND), Vector3(x1, 0, -BLEND), Vector3(x1, 0, 0), Vector3(x0, 0, 0), mean, mean, top, top, grid.floor_at(Vector2i(x, 0)))
		_quad(st, Vector3(x0, 0, -MARGIN), Vector3(x1, 0, -MARGIN), Vector3(x1, 0, -BLEND), Vector3(x0, 0, -BLEND), mean, mean, mean, mean, mk)
		_quad(st, Vector3(x0, 0, h), Vector3(x1, 0, h), Vector3(x1, 0, h + BLEND), Vector3(x0, 0, h + BLEND), bottom, bottom, mean, mean, grid.floor_at(Vector2i(x, grid.height - 1)))
		_quad(st, Vector3(x0, 0, h + BLEND), Vector3(x1, 0, h + BLEND), Vector3(x1, 0, h + MARGIN), Vector3(x0, 0, h + MARGIN), mean, mean, mean, mean, mk)
	for y in range(grid.height):
		var left := _cell_color(grid, Vector2i(0, y))
		var right := _cell_color(grid, Vector2i(grid.width - 1, y))
		var y0 := float(y)
		var y1 := float(y + 1)
		_quad(st, Vector3(-BLEND, 0, y0), Vector3(0, 0, y0), Vector3(0, 0, y1), Vector3(-BLEND, 0, y1), mean, left, left, mean, grid.floor_at(Vector2i(0, y)))
		_quad(st, Vector3(-MARGIN, 0, y0), Vector3(-BLEND, 0, y0), Vector3(-BLEND, 0, y1), Vector3(-MARGIN, 0, y1), mean, mean, mean, mean, mk)
		_quad(st, Vector3(w, 0, y0), Vector3(w + BLEND, 0, y0), Vector3(w + BLEND, 0, y1), Vector3(w, 0, y1), right, mean, mean, right, grid.floor_at(Vector2i(grid.width - 1, y)))
		_quad(st, Vector3(w + BLEND, 0, y0), Vector3(w + MARGIN, 0, y0), Vector3(w + MARGIN, 0, y1), Vector3(w + BLEND, 0, y1), mean, mean, mean, mean, mk)
	for corner in [Vector2(-MARGIN, -MARGIN), Vector2(w, -MARGIN), Vector2(-MARGIN, h), Vector2(w, h)]:
		var a := Vector3(corner.x, 0, corner.y)
		_quad(st, a, a + Vector3(MARGIN, 0, 0), a + Vector3(MARGIN, 0, MARGIN), a + Vector3(0, 0, MARGIN), mean, mean, mean, mean, mk)
	return st.commit()


## A flat frame around the map: from `inset` inside the edge to `margin` out.
static func frame_mesh(size: Vector2, inset: float, margin: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var o0 := Vector2(-margin, -margin)
	var o1 := size + Vector2(margin, margin)
	var i0 := Vector2(inset, inset)
	var i1 := size - Vector2(inset, inset)
	var white := Color(1, 1, 1, 1)
	var rects := [
		[Vector2(o0.x, o0.y), Vector2(o1.x, i0.y)],   # north band, corner to corner
		[Vector2(o0.x, i1.y), Vector2(o1.x, o1.y)],   # south band
		[Vector2(o0.x, i0.y), Vector2(i0.x, i1.y)],   # west, between the bands
		[Vector2(i1.x, i0.y), Vector2(o1.x, i1.y)],   # east
	]
	for r in rects:
		var p: Vector2 = r[0]
		var q: Vector2 = r[1]
		_quad(st, Vector3(p.x, 0, p.y), Vector3(q.x, 0, p.y), Vector3(q.x, 0, q.y), Vector3(p.x, 0, q.y), white, white, white, white, -1)
	return st.commit()


static func _cell_color(grid: FieldGrid, c: Vector2i) -> Color:
	var col: Color = MapView.FLOOR_COLORS[grid.floor_at(c)]
	return Color(col.r, col.g, col.b, 1.0)


## Two triangles a, b, c / a, c, d, wound to face up (as map_view lays the ground).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color, kind: int) -> void:
	var pts := [a, b, c, a, c, d]
	var cols := [ca, cb, cc, ca, cc, cd]
	for i in 6:
		st.set_color(cols[i])
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2.ZERO)
		st.set_uv2(Vector2(kind + 1, 0))
		st.add_vertex(pts[i])
