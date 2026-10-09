extends Node3D
## Graybox visuals for the stop map. Ground, walls and props share one material
## that reads the low-resolution sight mask. Walls of the building the player is
## in are cut down so the rooms stay readable from the oblique camera.
## Each floor hangs under its own root: upstairs floors show only once the
## player climbs to them, and the cellar shows alone.

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WALL_H: float = 2.1
const LEVEL_H: float = 3.0
const CUT_H: float = 0.35
const FLOOR_COLORS: Array[Color] = [
	Color(0.66, 0.68, 0.71), Color(0.36, 0.36, 0.37), Color(0.48, 0.47, 0.45), Color(0.40, 0.34, 0.29),
	Color(0.30, 0.28, 0.27), Color(0.74, 0.76, 0.79), Color(0.58, 0.66, 0.72), Color(0.45, 0.44, 0.42),
]

var grid: FieldGrid
var data: Dictionary
var material: ShaderMaterial
var vis_image: Image
var vis_texture: ImageTexture
var vis_bytes := PackedByteArray()
var vis_lit := PackedInt32Array()
var wall_nodes: Dictionary = {}   # Vector2i(building id, level) -> MeshInstance3D
var cut_building: int = -2
var cut_level: int = 0
var levels: Dictionary = {}       # level -> FieldGrid
var level_roots: Dictionary = {}  # level -> Node3D
var shown_level: int = -99
var door_nodes: Dictionary = {}   # Vector2i -> MeshInstance3D
var window_nodes: Dictionary = {}
var container_nodes: Dictionary = {}
var spot_nodes: Dictionary = {}
var stove_nodes: Array = []
var manhole_nodes: Dictionary = {}
var label_nodes: Array = []             # [Label3D, cell]


func setup(map_data: Dictionary) -> void:
	data = map_data
	grid = data["grid"]
	levels = data.get("levels", {0: grid})
	for lv in levels:
		var root := Node3D.new()
		root.name = "Level%d" % lv
		add_child(root)
		level_roots[lv] = root
	vis_image = Image.create(grid.width, grid.height, false, Image.FORMAT_RG8)
	vis_image.fill(Color(0, 0, 0))
	vis_texture = ImageTexture.create_from_image(vis_image)
	material = ShaderMaterial.new()
	material.shader = preload("res://game/world/world_vis.gdshader")
	material.set_shader_parameter("vis", vis_texture)
	material.set_shader_parameter("map_size", Vector2(grid.width, grid.height))
	_build_ground()
	_build_walls()
	_build_blocks()
	for lv in levels:
		if lv != 0:
			_build_level(lv)
	_build_stairs()
	for c in grid.doors:
		var node := _mesh_node()
		door_nodes[c] = node
		update_door(c)
	for c in grid.windows:
		var node := _mesh_node()
		window_nodes[c] = node
		update_window(c)
	for id in data["containers"]:
		var node := _mesh_node(int(data["containers"][id].get("level", 0)))
		container_nodes[id] = node
		update_container(id)
	for id in data["spots"]:
		var node := _mesh_node()
		spot_nodes[id] = node
		update_spot(id)
	for stove in data["stoves"]:
		var lv: int = int(stove.get("level", 0))
		var node := _mesh_node(lv)
		stove_nodes.append(node)
		var st := _begin()
		var base := FieldGrid.center(stove["cell"]) + Vector3(0, lv * LEVEL_H, 0)
		box(st, Vector3(0.8, 0.9, 0.8), base + Vector3(0, 0.45, 0), Color(0.25, 0.24, 0.23))
		if stove["lit"]:
			box(st, Vector3(0.5, 0.06, 0.5), base + Vector3(0, 0.93, 0), Color(0.95, 0.55, 0.25))
		node.mesh = st.commit()
	for key in data["manholes"]:
		var lv: int = int(data.get("manhole_levels", {}).get(key, 0))
		var node := _mesh_node(lv)
		node.position = FieldGrid.center(data["manholes"][key]) + Vector3(0, lv * LEVEL_H, 0)
		manhole_nodes[key] = node
		update_manhole(key, false)
	# What the people who fled underground left at the culvert mouth: a wooden
	# crate, a wet blanket, a burnt-out oil lamp. Shown, never explained
	# (field_unified 6 하수도). No bundles or shoes here (금지선).
	if data["manholes"].has("culvert"):
		var st := _begin()
		var at := FieldGrid.center(data["manholes"]["culvert"])
		box(st, Vector3(0.6, 0.4, 0.45), at + Vector3(1.6, 0.2, 0.4), Color(0.4, 0.32, 0.22))
		box(st, Vector3(1.0, 0.06, 0.7), at + Vector3(1.2, 0.03, 1.3), Color(0.35, 0.3, 0.36))
		box(st, Vector3(0.12, 0.22, 0.12), at + Vector3(2.1, 0.11, 1.0), Color(0.3, 0.29, 0.27))
		var remains := _mesh_node()
		remains.mesh = st.commit()
	for label in data["labels"]:
		var text := Label3D.new()
		text.text = label["text"]
		text.font_size = 40
		text.pixel_size = 0.012
		text.modulate = Color(0.85, 0.82, 0.76, 0.75)
		text.outline_size = 0
		text.rotation_degrees = Vector3(-90, 0, 0)
		var lv: int = int(label.get("level", 0))
		text.position = FieldGrid.center(label["cell"]) + Vector3(0, lv * LEVEL_H + 0.03, 0)
		text.no_depth_test = false
		text.visible = false
		level_roots[lv].add_child(text)
		label_nodes.append([text, label["cell"], lv])


## Manhole lid, or the culvert mouth; blocked shows a heavy plank stack on the lid.
func update_manhole(key: String, blocked: bool) -> void:
	var node: MeshInstance3D = manhole_nodes[key]
	var st := _begin()
	if key == "cellar":
		# A drain grate in the cellar floor.
		box(st, Vector3(0.9, 0.05, 0.9), Vector3(0, 0.03, 0), Color(0.12, 0.12, 0.13))
		for k in range(4):
			box(st, Vector3(0.08, 0.07, 0.8), Vector3(-0.3 + k * 0.2, 0.05, 0), Color(0.3, 0.3, 0.32))
	elif key == "culvert":
		box(st, Vector3(2.0, 0.9, 0.5), Vector3(0, 0.45, -0.4), Color(0.32, 0.31, 0.3))
		box(st, Vector3(1.4, 0.7, 0.2), Vector3(0, 0.35, -0.12), Color(0.05, 0.05, 0.06))
	else:
		box(st, Vector3(1.1, 0.06, 1.1), Vector3(0, 0.03, 0), Color(0.18, 0.18, 0.2))
		box(st, Vector3(0.9, 0.02, 0.15), Vector3(0, 0.07, 0), Color(0.3, 0.3, 0.32))
		if blocked:
			box(st, Vector3(1.2, 0.25, 0.9), Vector3(0, 0.2, 0), Color(0.5, 0.4, 0.28))
	node.mesh = st.commit()


## Room names show once the room has been seen (no free map knowledge).
func update_labels(memory: PackedByteArray, mask_on: bool) -> void:
	var n := grid.width * grid.height
	for row in label_nodes:
		var c: Vector2i = row[1]
		row[0].visible = not mask_on or memory[(int(row[2]) + 1) * n + grid.index(c)] > 0


func set_mask_enabled(on: bool) -> void:
	material.set_shader_parameter("mask_on", 1.0 if on else 0.0)


## seen_now: sight key (level slice * cells + cell index) -> true; memory:
## PackedByteArray of seen-before flags by the same key. The mask is one
## layer for all floors (only one floor's worth is on screen at a time).
## Only cells that changed since last call are touched.
func update_vis(seen_now: Dictionary, memory: PackedByteArray) -> void:
	var n := grid.width * grid.height
	if vis_bytes.size() != n * 2:
		vis_bytes.resize(n * 2)
		vis_bytes.fill(0)
		for k in range(memory.size()):
			if memory[k]:
				vis_bytes[(k % n) * 2 + 1] = 255
	for i in vis_lit:
		vis_bytes[i * 2] = 0
	vis_lit = PackedInt32Array()
	for key in seen_now:
		var i: int = key % n
		vis_bytes[i * 2] = 255
		vis_bytes[i * 2 + 1] = 255
		vis_lit.append(i)
	vis_image.set_data(grid.width, grid.height, false, Image.FORMAT_RG8, vis_bytes)
	vis_texture.update(vis_image)


## Show the floors the player can see from where they stand: the cellar
## alone, or the ground and every floor up to theirs.
func show_levels(player_level: int) -> void:
	if player_level == shown_level:
		return
	shown_level = player_level
	for lv in level_roots:
		level_roots[lv].visible = lv == -1 if player_level < 0 else lv >= 0 and lv <= player_level


## Lower the walls of the building the player is inside, on their floor (−1 = none).
func cut_away(building_id: int, level: int = 0) -> void:
	if building_id == cut_building and level == cut_level:
		return
	cut_building = building_id
	cut_level = level
	for key in wall_nodes:
		var node: MeshInstance3D = wall_nodes[key]
		var cut: bool = key.x == building_id and key.y == level
		node.scale = Vector3(1, CUT_H / WALL_H if cut else 1.0, 1)
	for c in door_nodes:
		update_door(c)
	for c in window_nodes:
		update_window(c)


func update_door(c: Vector2i) -> void:
	var door: Dictionary = grid.doors[c]
	var node: MeshInstance3D = door_nodes[c]
	var st := _begin()
	var at := FieldGrid.center(c)
	var h := WALL_H * (CUT_H / WALL_H if door["building"] == cut_building and cut_level == 0 else 1.0)
	var horizontal := not grid.blocks_body(c + Vector2i(1, 0)) or not grid.blocks_body(c + Vector2i(-1, 0))
	horizontal = grid.solid_at(c + Vector2i(1, 0)) == S.WALL or grid.solid_at(c + Vector2i(-1, 0)) == S.WALL
	var state: String = door["state"]
	match state:
		"closed":
			box(st, Vector3(1.0, h, 0.16) if horizontal else Vector3(0.16, h, 1.0), at + Vector3(0, h * 0.5, 0), Color(0.5, 0.38, 0.27))
		"locked":
			box(st, Vector3(1.0, h, 0.2) if horizontal else Vector3(0.2, h, 1.0), at + Vector3(0, h * 0.5, 0), Color(0.33, 0.25, 0.18))
			box(st, Vector3(0.22, 0.22, 0.3), at + Vector3(0.2, 1.0, 0), Color(0.65, 0.62, 0.35))
		"open":
			var off := Vector3(-0.42, 0, 0.42) if horizontal else Vector3(0.42, 0, -0.42)
			box(st, Vector3(0.12, h, 0.9) if horizontal else Vector3(0.9, h, 0.12), at + off + Vector3(0, h * 0.5, 0), Color(0.5, 0.38, 0.27))
		"broken":
			box(st, Vector3(0.8, 0.12, 0.5), at + Vector3(0, 0.06, 0), Color(0.4, 0.3, 0.22))
	box(st, Vector3(1.0, 0.04, 1.0), at + Vector3(0, 0.02, 0), Color(0.35, 0.3, 0.26))
	node.mesh = st.commit()


func update_window(c: Vector2i) -> void:
	var win: Dictionary = grid.windows[c]
	var node: MeshInstance3D = window_nodes[c]
	var st := _begin()
	var at := FieldGrid.center(c)
	var cut: bool = win["building"] == cut_building and cut_level == 0
	var horizontal := grid.solid_at(c + Vector2i(1, 0)) == S.WALL or grid.solid_at(c + Vector2i(-1, 0)) == S.WALL
	var size := Vector3(1.0, 0.1, 0.25) if horizontal else Vector3(0.25, 0.1, 1.0)
	box(st, size + Vector3(0, 0.75, 0), at + Vector3(0, 0.4, 0), Color(0.4, 0.4, 0.42))
	if not cut:
		if win["broken"]:
			box(st, size * Vector3(1, 1, 1) + Vector3(0, 0.0, 0), at + Vector3(0, WALL_H - 0.05, 0), Color(0.4, 0.4, 0.42))
		else:
			box(st, (Vector3(1.0, 1.0, 0.08) if horizontal else Vector3(0.08, 1.0, 1.0)), at + Vector3(0, 1.3, 0), Color(0.62, 0.72, 0.78))
			box(st, size, at + Vector3(0, WALL_H - 0.05, 0), Color(0.4, 0.4, 0.42))
	if win["glass"]:
		for k in range(5):
			var o := Vector3(fmod(k * 0.37, 0.8) - 0.4, 0.02, fmod(k * 0.53, 0.8) - 0.4)
			box(st, Vector3(0.12, 0.03, 0.08), at + o, Color(0.8, 0.9, 0.95))
	node.mesh = st.commit()


func update_container(id: String) -> void:
	var box_data: Dictionary = data["containers"][id]
	var node: MeshInstance3D = container_nodes[id]
	var st := _begin()
	var at := FieldGrid.center(box_data["cell"]) + Vector3(0, int(box_data.get("level", 0)) * LEVEL_H, 0)
	var color := Color(0.62, 0.5, 0.3) if not box_data["searched"] else Color(0.35, 0.32, 0.28)
	if box_data["id"] == "bell":
		color = Color(0.75, 0.62, 0.25) if box_data["items"].size() > 0 else Color(0.3, 0.3, 0.3)
		box(st, Vector3(0.35, 0.45, 0.35), at + Vector3(0, 1.4, 0), color)
	else:
		box(st, Vector3(0.7, 0.55, 0.5), at + Vector3(0, 0.28, 0), color)
	if box_data["locked"]:
		box(st, Vector3(0.18, 0.18, 0.55), at + Vector3(0.18, 0.4, 0), Color(0.7, 0.66, 0.3))
	node.mesh = st.commit()


func update_spot(id: String) -> void:
	var spot: Dictionary = data["spots"][id]
	var node: MeshInstance3D = spot_nodes[id]
	var st := _begin()
	var at := FieldGrid.center(spot["cell"])
	match spot["kind"]:
		"water_tower":
			var lit: bool = spot["state"] == "fire"
			box(st, Vector3(1.4, 0.2, 1.0), at + Vector3(0, 0.1, 0), Color(0.3, 0.27, 0.25) if not lit else Color(0.95, 0.5, 0.2))
			if spot["state"] == "thawed":
				box(st, Vector3(0.5, 0.05, 0.5), at + Vector3(0.9, 0.03, 0), Color(0.4, 0.55, 0.65))
		"ladder":
			for k in range(6):
				box(st, Vector3(0.6, 0.06, 0.06), at + Vector3(0, 0.4 + k * 0.5, -0.3), Color(0.5, 0.42, 0.3))
			box(st, Vector3(0.06, 3.2, 0.06), at + Vector3(-0.28, 1.6, -0.3), Color(0.5, 0.42, 0.3))
			box(st, Vector3(0.06, 3.2, 0.06), at + Vector3(0.28, 1.6, -0.3), Color(0.5, 0.42, 0.3))
		"work_site":
			var color := Color(0.45, 0.45, 0.45) if spot["state"] == "closed" else Color(0.8, 0.7, 0.35)
			box(st, Vector3(1.2, 0.05, 1.2), at + Vector3(0, 0.03, 0), color)
		"salvage":
			if spot["state"] == "intact":
				box(st, Vector3(0.8, 0.3, 0.5), at + Vector3(0, 0.15, 0), Color(0.5, 0.48, 0.45) if spot["material"] == "scrap" else Color(0.55, 0.42, 0.28))
	node.mesh = st.commit()


func _mesh_node(lv: int = 0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.material_override = material
	level_roots[lv].add_child(node)
	return node


func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Append an axis-aligned box with a flat vertex colour.
## Vertex alpha the world shader reads as "open to the sky": 1 outdoors, 0 under
## a roof, so snow and wet stay off floors inside buildings.
static func sky_alpha(g: FieldGrid, c: Vector2i) -> float:
	return 0.0 if g.indoor(c) else 1.0


static func box(st: SurfaceTool, size: Vector3, at: Vector3, color: Color) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(0, 1, 0), [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3(0, 0, 1), [Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z)]],
		[Vector3(0, 0, -1), [Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z)]],
		[Vector3(1, 0, 0), [Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, -h.y, -h.z)]],
		[Vector3(-1, 0, 0), [Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, -h.y, h.z)]],
	]
	for face in faces:
		var n: Vector3 = face[0]
		var v: Array = face[1]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(color)
			st.set_normal(n)
			st.add_vertex(at + v[idx])


func _build_ground() -> void:
	var st := _begin()
	for y in range(grid.height):
		for x in range(grid.width):
			var c := Vector2i(x, y)
			var f := grid.floor_at(c)
			var color := FLOOR_COLORS[f]
			# Small checker noise so distance reads on a flat colour.
			var n := (float((x * 73 + y * 37) % 11) / 11.0 - 0.5) * 0.035
			color = Color(color.r + n, color.g + n, color.b + n)
			if f == F.RAIL and (x % 2 == 0):
				color = color.darkened(0.15)
			color.a = sky_alpha(grid, c)
			var a := Vector3(x, 0, y)
			var quad := [a, a + Vector3(1, 0, 0), a + Vector3(1, 0, 1), a + Vector3(0, 0, 1)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_color(color)
				st.set_normal(Vector3.UP)
				st.add_vertex(quad[idx])
	var node := _mesh_node()
	node.mesh = st.commit()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_walls() -> void:
	var tools: Dictionary = {}
	for y in range(grid.height):
		for x in range(grid.width):
			var c := Vector2i(x, y)
			if grid.solid_at(c) != S.WALL:
				continue
			var b := grid.building_at(c)
			if not tools.has(b):
				tools[b] = _begin()
			box(tools[b], Vector3(1, WALL_H, 1), Vector3(x + 0.5, WALL_H * 0.5, y + 0.5), Color(0.55, 0.53, 0.5))
	for b in tools:
		var node := _mesh_node()
		node.mesh = tools[b].commit()
		wall_nodes[Vector2i(b, 0)] = node


func _build_blocks() -> void:
	var st := _begin()
	# Train: four cars and the engine at the east end; dark so the platform reads.
	var train: Rect2i = data["train"]
	var cars := 4
	var car_len := float(train.size.x) / cars
	for k in range(cars):
		var x0 := train.position.x + k * car_len
		box(st, Vector3(car_len - 0.6, 3.0, 2.8), Vector3(x0 + car_len * 0.5, 1.5, train.position.y + 1.5), Color(0.3, 0.29, 0.28) if k < 3 else Color(0.22, 0.22, 0.24))
		for d in range(3):
			box(st, Vector3(1.0, 2.0, 0.1), Vector3(x0 + 3 + d * (car_len - 6) / 2.0, 1.4, train.position.y + 2.95), Color(0.42, 0.38, 0.33))
	for w in data["wagons"]:
		var r: Rect2i = w["rect"]
		var mid := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
		box(st, Vector3(r.size.x - 0.2, 1.9, r.size.y - 0.2), mid + Vector3(0, 0.95, 0), Color(0.33, 0.3, 0.28))
		if w["coal"] > 0.0:
			box(st, Vector3(r.size.x - 0.8, 0.5, r.size.y - 0.8), mid + Vector3(0, 2.05, 0), Color(0.12, 0.12, 0.13))
			box(st, Vector3(r.size.x - 1.2, 0.12, r.size.y - 1.2), mid + Vector3(0, 2.35, 0), Color(0.9, 0.92, 0.95))
	for y in range(grid.height):
		for x in range(grid.width):
			var c := Vector2i(x, y)
			if grid.solid_at(c) == S.BLOCK and grid.building_at(c) < 0 and x < 14 and y < 14:
				box(st, Vector3(1, 6.0, 1), Vector3(x + 0.5, 3.0, y + 0.5), Color(0.4, 0.37, 0.35))
	for c in data["trees"]:
		box(st, Vector3(0.5, 2.5, 0.5), FieldGrid.center(c) + Vector3(0, 1.25, 0), Color(0.3, 0.26, 0.22))
		box(st, Vector3(2.2, 1.8, 2.2), FieldGrid.center(c) + Vector3(0, 3.0, 0), Color(0.62, 0.66, 0.66))
	for r in data["low_blocks"]:
		var mid := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
		var tall := 1.2 if r.size.x > 1 and r.size.y > 1 else 0.9
		box(st, Vector3(r.size.x - 0.1, tall, r.size.y - 0.1), mid + Vector3(0, tall * 0.5, 0), Color(0.42, 0.4, 0.38))
	var node := _mesh_node()
	node.mesh = st.commit()


## An upper floor or the cellar: a floor where there is one, walls by building
## (so the player's own can be cut down), window frames.
func _build_level(lv: int) -> void:
	var lg: FieldGrid = levels[lv]
	var y0 := lv * LEVEL_H
	var floor_st := _begin()
	var tools: Dictionary = {}
	for y in range(lg.height):
		for x in range(lg.width):
			var c := Vector2i(x, y)
			var kind := lg.solid_at(c)
			if kind == S.AIR or (kind == S.BLOCK and lg.building_at(c) < 0):
				continue
			var color := FLOOR_COLORS[lg.floor_at(c)]
			var n := (float((x * 73 + y * 37) % 11) / 11.0 - 0.5) * 0.035
			color = Color(color.r + n, color.g + n, color.b + n)
			color.a = 0.0   # upper floors and the cellar are all under a roof
			var a := Vector3(x, y0, y)
			var quad := [a, a + Vector3(1, 0, 0), a + Vector3(1, 0, 1), a + Vector3(0, 0, 1)]
			for idx in [0, 1, 2, 0, 2, 3]:
				floor_st.set_color(color)
				floor_st.set_normal(Vector3.UP)
				floor_st.add_vertex(quad[idx])
			var b := lg.building_at(c)
			if kind == S.WALL:
				if not tools.has(b):
					tools[b] = _begin()
				box(tools[b], Vector3(1, WALL_H, 1), Vector3(x + 0.5, y0 + WALL_H * 0.5, y + 0.5), Color(0.55, 0.53, 0.5))
			elif kind == S.WINDOW:
				if not tools.has(b):
					tools[b] = _begin()
				var horizontal := lg.solid_at(c + Vector2i(1, 0)) == S.WALL or lg.solid_at(c + Vector2i(-1, 0)) == S.WALL
				var size := Vector3(1.0, 0.85, 0.25) if horizontal else Vector3(0.25, 0.85, 1.0)
				box(tools[b], size, Vector3(x + 0.5, y0 + 0.43, y + 0.5), Color(0.4, 0.4, 0.42))
				box(tools[b], Vector3(1.0, 0.9, 0.08) if horizontal else Vector3(0.08, 0.9, 1.0), Vector3(x + 0.5, y0 + 1.3, y + 0.5), Color(0.62, 0.72, 0.78))
				box(tools[b], size * Vector3(1, 0.12, 1), Vector3(x + 0.5, y0 + WALL_H - 0.05, y + 0.5), Color(0.4, 0.4, 0.42))
	var floor_node := _mesh_node(lv)
	floor_node.mesh = floor_st.commit()
	floor_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for b in tools:
		var node := _mesh_node(lv)
		node.mesh = tools[b].commit()
		wall_nodes[Vector2i(b, lv)] = node


## Stairs: steps going up on the lower floor, a dark well with a rail on the upper.
func _build_stairs() -> void:
	for s in data.get("stairs", []):
		if s["ladder"]:
			continue
		var c: Vector2i = s["cell"]
		var low: int = s["low"]
		var high: int = s["high"]
		var st := _begin()
		var base := Vector3(c.x + 0.5, low * LEVEL_H, c.y + 0.5)
		for k in range(4):
			box(st, Vector3(0.9, 0.3 + k * 0.3, 0.22), base + Vector3(0, (0.3 + k * 0.3) * 0.5, -0.33 + k * 0.22), Color(0.48, 0.4, 0.32))
		_mesh_node(low).mesh = st.commit()
		var up := _begin()
		var top := Vector3(c.x + 0.5, high * LEVEL_H, c.y + 0.5)
		box(up, Vector3(0.95, 0.03, 0.95), top + Vector3(0, 0.02, 0), Color(0.16, 0.15, 0.15))
		box(up, Vector3(0.06, 0.9, 0.95), top + Vector3(0.47, 0.45, 0), Color(0.48, 0.4, 0.32))
		_mesh_node(high).mesh = up.commit()
