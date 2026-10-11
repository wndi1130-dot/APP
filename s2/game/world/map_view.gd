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
const FxState = preload("res://fx/fx_state.gd")
## Unlit car windows: dark glass. Lit ones take FxState.LAMP.
const WINDOW_DARK := Color(0.16, 0.16, 0.17)
## Size (along the wall, up, thickness) and height of each glowing face.
const LIGHT_FACES: Dictionary = {
	"car_window": {"size": Vector3(0.9, 0.7, 0.08), "y": 1.9},
	"firebox": {"size": Vector3(0.6, 0.4, 0.08), "y": 0.6},
	"hideout": {"size": Vector3(0.12, 0.5, 0.08), "y": 1.4},
}
const FLOOR_COLORS: Array[Color] = [
	Color(0.66, 0.68, 0.71), Color(0.36, 0.36, 0.37), Color(0.48, 0.47, 0.45), Color(0.40, 0.34, 0.29),
	Color(0.30, 0.28, 0.27), Color(0.74, 0.76, 0.79), Color(0.40, 0.54, 0.66), Color(0.45, 0.44, 0.42),
]

var grid: FieldGrid
var data: Dictionary
var material: ShaderMaterial
var vis_image: Image
var vis_texture: ImageTexture
var vis_bytes := PackedByteArray()
var vis_lit := PackedInt32Array()
var lamp_lit := PackedInt32Array()   # cells the lamp channel was written to last time
var track_wait: Dictionary = {}      # snow marks handed over, written at the next sight update
var light_nodes: Dictionary = {}     # light kind -> MeshInstance3D (the glowing face itself)
var light_mats: Dictionary = {}      # light kind -> StandardMaterial3D
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
const LEVEL_WAYS := {-1: "지하로", 0: "1층으로", 1: "2층으로", 2: "3층으로"}
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
	# R seen now, G seen before, B warm lamp light, A kept for cell snow (weather_fx 12.2).
	vis_image = Image.create(grid.width, grid.height, false, Image.FORMAT_RGBA8)
	vis_image.fill(Color(0, 0, 0, 1))
	vis_texture = ImageTexture.create_from_image(vis_image)
	material = ShaderMaterial.new()
	material.shader = preload("res://game/world/world_vis.gdshader")
	material.set_shader_parameter("vis", vis_texture)
	material.set_shader_parameter("map_size", Vector2(grid.width, grid.height))
	material.set_shader_parameter("lamp_color", FxState.LAMP)
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


## Manhole lid, or the culvert mouth; blocked shows a heavy plank stack on the
## lid, open shows the lid pushed aside and the dark of the hole.
func update_manhole(key: String, blocked: bool, open: bool = false) -> void:
	var node: MeshInstance3D = manhole_nodes[key]
	var st := _begin()
	if not key.begins_with("manhole") and not key.begins_with("culvert"):
		# A drain grate in the floor (the cellar's, or any hole a map names otherwise).
		box(st, Vector3(0.9, 0.05, 0.9), Vector3(0, 0.03, 0), Color(0.12, 0.12, 0.13))
		for k in range(4):
			box(st, Vector3(0.08, 0.07, 0.8), Vector3(-0.3 + k * 0.2, 0.05, 0), Color(0.3, 0.3, 0.32))
	elif key.begins_with("culvert"):
		box(st, Vector3(2.0, 0.9, 0.5), Vector3(0, 0.45, -0.4), Color(0.32, 0.31, 0.3))
		box(st, Vector3(1.4, 0.7, 0.2), Vector3(0, 0.35, -0.12), Color(0.05, 0.05, 0.06))
	elif open:
		box(st, Vector3(1.0, 0.02, 1.0), Vector3(0, 0.01, 0), Color(0.03, 0.03, 0.04))
		box(st, Vector3(1.1, 0.06, 1.1), Vector3(1.0, 0.05, 0.25), Color(0.18, 0.18, 0.2))
		box(st, Vector3(0.9, 0.02, 0.15), Vector3(1.0, 0.09, 0.25), Color(0.3, 0.3, 0.32))
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
## lamp: cell index -> byte of warm light (LampLight), written to the B channel.
## Only cells that changed since last call are touched.
func update_vis(seen_now: Dictionary, memory: PackedByteArray, lamp: Dictionary = {}) -> void:
	var n := grid.width * grid.height
	if vis_bytes.size() != n * 4:
		vis_bytes.resize(n * 4)
		vis_bytes.fill(0)
		for i in range(n):
			vis_bytes[i * 4 + 3] = 255
		for k in range(memory.size()):
			if memory[k]:
				vis_bytes[(k % n) * 4 + 1] = 255
	for i in vis_lit:
		vis_bytes[i * 4] = 0
	vis_lit = PackedInt32Array()
	for key in seen_now:
		var i: int = key % n
		vis_bytes[i * 4] = 255
		vis_bytes[i * 4 + 1] = 255
		vis_lit.append(i)
	for i in track_wait:
		vis_bytes[int(i) * 4 + 3] = int(track_wait[i])
	track_wait = {}
	for i in lamp_lit:
		vis_bytes[i * 4 + 2] = 0
	lamp_lit = PackedInt32Array()
	for i in lamp:
		vis_bytes[int(i) * 4 + 2] = int(lamp[i])
		lamp_lit.append(int(i))
	vis_image.set_data(grid.width, grid.height, false, Image.FORMAT_RGBA8, vis_bytes)
	vis_texture.update(vis_image)


## Snow marks (SnowTracks.take_changed: cell index -> byte, 255 untouched) for
## the A channel. Uploaded with the next sight update, so it costs no extra upload.
func update_tracks(changed: Dictionary) -> void:
	for i in changed:
		track_wait[i] = changed[i]


## How strong the lamp light shows on the ground: faint by day, full at night.
func set_lamp_gain(gain: float) -> void:
	material.set_shader_parameter("lamp_gain", clampf(gain, 0.0, 1.0))


## The glowing faces themselves (car windows, the firebox door, the gap in the
## hideout boards): lit ones show amber, unlit car windows stay as dark glass.
func set_light_on(kind: String, on: bool) -> void:
	if not light_nodes.has(kind):
		return
	if kind == "car_window":
		light_mats[kind].albedo_color = FxState.LAMP if on else WINDOW_DARK
	else:
		light_nodes[kind].visible = on


func light_is_on(kind: String) -> bool:
	if not light_nodes.has(kind):
		return false
	if kind == "car_window":
		return light_mats[kind].albedo_color == FxState.LAMP
	return light_nodes[kind].visible


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
		"inspect":
			# A thing to look at for this stop's goal: a post, paler once seen.
			var post := Color(0.42, 0.42, 0.44) if spot["state"] != "seen" else Color(0.7, 0.7, 0.66)
			box(st, Vector3(0.12, 1.6, 0.12), at + Vector3(0, 0.8, 0), post)
			box(st, Vector3(0.5, 0.3, 0.1), at + Vector3(0, 1.5, 0), post)
		"conveyor":
			# A belt on legs; paler while it is being mended, warm grey once it runs.
			var belt: Color = {"stopped": Color(0.36, 0.36, 0.38), "part": Color(0.5, 0.5, 0.5), "running": Color(0.72, 0.66, 0.5)}.get(spot["state"], Color(0.36, 0.36, 0.38))
			box(st, Vector3(2.6, 0.18, 0.7), at + Vector3(0, 0.75, 0), belt)
			box(st, Vector3(0.14, 0.7, 0.14), at + Vector3(-1.1, 0.35, 0), belt)
			box(st, Vector3(0.14, 0.7, 0.14), at + Vector3(1.1, 0.35, 0), belt)
		"deep":
			box(st, Vector3(1.0, 0.06, 1.0), at + Vector3(0, 0.03, 0), Color(0.3, 0.28, 0.26) if spot["state"] != "seen" else Color(0.6, 0.58, 0.52))
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
const OUTDOOR_BLOCK_H: float = 2.4
const TILE: int = 30   # cells a side of one piece of ground


## Where the train's doors are drawn: {"cell", "z"}. A map with doors on both
## sides says so in "train_doors" (upper: the north face, lower: the south);
## the first stop has them on the platform side only.
static func door_faces(d: Dictionary) -> Array:
	var train: Rect2i = d["train"]
	var sides: Dictionary = d.get("train_doors", {})
	if sides.is_empty():
		sides = {"lower": d["spawns"]["train_door"]}
	var out: Array = []
	for c in sides.get("upper", []):
		out.append({"cell": c, "z": train.position.y + 0.05})
	for c in sides.get("lower", []):
		out.append({"cell": c, "z": train.position.y + train.size.y - 0.05})
	return out


## Blocked cells out of doors that nothing else draws (not the train, not a
## wagon, not a tree), as runs along a row: [Rect2i(x, y, length, 1)].
static func outdoor_block_runs(g: FieldGrid, d: Dictionary) -> Array[Rect2i]:
	var skip: Array[Rect2i] = [d["train"]]
	for w in d.get("wagons", []):
		skip.append(w["rect"])
	var trees: Dictionary = {}
	for c in d.get("trees", []):
		trees[c] = true
	var out: Array[Rect2i] = []
	for y in range(g.height):
		var start := -1
		for x in range(g.width + 1):
			var c := Vector2i(x, y)
			var mine: bool = x < g.width and g.solid_at(c) == S.BLOCK and g.building_at(c) < 0 and not trees.has(c)
			if mine:
				for r in skip:
					if r.has_point(c):
						mine = false
						break
			if mine and start < 0:
				start = x
			elif not mine and start >= 0:
				out.append(Rect2i(start, y, x - start, 1))
				start = -1
	return out


## The wall cells of one floor as few boxes as they make, by building:
## building id -> [Rect2i]. A row of wall cells is one box, and what is left
## standing alone in its row joins the cells under it. A big map is drawn (and
## throws its shadow) far faster so than a box a cell.
static func wall_runs(g: FieldGrid) -> Dictionary:
	var out: Dictionary = {}
	var single: Dictionary = {}   # cell -> building, the cells that made no row
	for y in range(g.height):
		var start := -1
		var of := 0
		for x in range(g.width + 1):
			var c := Vector2i(x, y)
			var wall: bool = x < g.width and g.solid_at(c) == S.WALL
			var b: int = g.building_at(c) if wall else 0
			if start >= 0 and (not wall or b != of):
				if x - start == 1:
					single[Vector2i(start, y)] = of
				else:
					if not out.has(of):
						out[of] = []
					out[of].append(Rect2i(start, y, x - start, 1))
				start = -1
			if wall and start < 0:
				start = x
				of = b
	for c: Vector2i in single.keys():
		if not single.has(c):
			continue
		var b: int = single[c]
		var n := 0
		while single.get(c + Vector2i(0, n), b - 1) == b:
			single.erase(c + Vector2i(0, n))
			n += 1
		if not out.has(b):
			out[b] = []
		out[b].append(Rect2i(c.x, c.y, 1, n))
	return out


static func sky_alpha(g: FieldGrid, c: Vector2i) -> float:
	return 0.0 if g.indoor(c) else 1.0


## Which way the walls stand from a corner of the ground grid (the point where
## four cells meet): +1 or -1 on each axis, 0 for none or both. Snow banks up
## there when the wind blows that way (world_vis). Nothing next to a door, so
## the way in stays level; the shader keeps it off floors under a roof.
static func drift_uv(g: FieldGrid, corner: Vector2i) -> Vector2:
	var side := Vector2i.ZERO
	var open := false
	for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		var c: Vector2i = corner + d
		if not g.inside(c):
			continue
		var kind := g.solid_at(c)
		if kind == S.DOOR:
			return Vector2.ZERO
		if kind == S.WALL or kind == S.BLOCK or kind == S.WINDOW:
			side += Vector2i(1, 1) + d * 2
		elif kind == S.NONE and not g.indoor(c):
			open = true
	return Vector2(signi(side.x), signi(side.y)) if open else Vector2.ZERO


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
	# The ground is laid in tiles, so what is off the screen is not drawn.
	var tools: Dictionary = {}
	# One answer a corner, shared by the cells that meet there.
	var banks := PackedVector2Array()
	for y in range(grid.height + 1):
		for x in range(grid.width + 1):
			banks.append(drift_uv(grid, Vector2i(x, y)))
	for y in range(grid.height):
		for x in range(grid.width):
			var c := Vector2i(x, y)
			var tile := c / TILE
			if not tools.has(tile):
				tools[tile] = _begin()
			var st: SurfaceTool = tools[tile]
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
				st.set_uv(banks[int(quad[idx].z) * (grid.width + 1) + int(quad[idx].x)])
				st.add_vertex(quad[idx])
	for tile in tools:
		var node := _mesh_node()
		node.mesh = tools[tile].commit()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_walls() -> void:
	var runs: Dictionary = wall_runs(grid)
	for b in runs:
		var st := _begin()
		for r: Rect2i in runs[b]:
			box(st, Vector3(r.size.x, WALL_H, r.size.y), Vector3(r.position.x + r.size.x * 0.5, WALL_H * 0.5, r.position.y + r.size.y * 0.5), Color(0.55, 0.53, 0.5))
		var node := _mesh_node()
		node.mesh = st.commit()
		wall_nodes[Vector2i(b, 0)] = node


func _build_blocks() -> void:
	var st := _begin()
	# Train: four cars and the engine at the east end; dark so the platform reads.
	var train: Rect2i = data["train"]
	for car in data["train_cars"]:
		var r: Rect2i = car["rect"]
		box(st, Vector3(r.size.x - 0.6, 3.0, 2.8), Vector3(r.position.x + r.size.x * 0.5, 1.5, train.position.y + 1.5), Color(0.3, 0.29, 0.28) if car["kind"] == "car" else Color(0.22, 0.22, 0.24))
	# Doors where people step down, on each side of the train that has them.
	for face in door_faces(data):
		box(st, Vector3(1.0, 2.0, 0.1), Vector3(face["cell"].x + 0.5, 1.4, face["z"]), Color(0.42, 0.38, 0.33))
	# A way over the train: a plank across the gap between two cars and rungs
	# up to it on each side (over the roof if the way is not at a gap).
	var wood := Color(0.62, 0.5, 0.34)
	for crossing in data.get("crossings", []):
		var cx: int = crossing["cells"][0].x
		var at_x: float = cx + 0.5
		var top: float = 3.06
		for car in data["train_cars"]:
			var edge: int = car["rect"].position.x
			if edge > train.position.x and (edge == cx or edge == cx + 1):
				at_x = float(edge)
				top = 1.1
		box(st, Vector3(0.9, 0.12, train.size.y), Vector3(at_x, top, train.position.y + train.size.y * 0.5), wood)
		for z: float in [train.position.y - 0.02, train.end.y + 0.02]:
			for k in int(top / 0.3):
				box(st, Vector3(0.8, 0.07, 0.1), Vector3(at_x, 0.3 + 0.3 * k, z), wood)
	_build_lights()
	for w in data["wagons"]:
		var r: Rect2i = w["rect"]
		var mid := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
		box(st, Vector3(r.size.x - 0.2, 1.9, r.size.y - 0.2), mid + Vector3(0, 0.95, 0), Color(0.33, 0.3, 0.28))
		if w["coal"] > 0.0:
			box(st, Vector3(r.size.x - 0.8, 0.5, r.size.y - 0.8), mid + Vector3(0, 2.05, 0), Color(0.12, 0.12, 0.13))
			box(st, Vector3(r.size.x - 1.2, 0.12, r.size.y - 1.2), mid + Vector3(0, 2.35, 0), Color(0.9, 0.92, 0.95))
	if data["spots"].has("water_tower"):
		# The first stop: the blocked cells in its north-west corner are the water tower.
		for y in range(mini(14, grid.height)):
			for x in range(mini(14, grid.width)):
				var c := Vector2i(x, y)
				if grid.solid_at(c) == S.BLOCK and grid.building_at(c) < 0:
					box(st, Vector3(1, 6.0, 1), Vector3(x + 0.5, 3.0, y + 0.5), Color(0.4, 0.37, 0.35))
	var node := _mesh_node()
	node.mesh = st.commit()
	# What stands about the map goes by tile, as the ground does: a tree or a
	# stack far off is neither drawn nor made to throw a shadow.
	var tools: Dictionary = {}
	if not data["spots"].has("water_tower"):
		# Other maps: blocked ground out of doors (rock, a bank, a stack) is drawn
		# as it lies, a run of cells a box, so nothing that stops you is unseen.
		for r in outdoor_block_runs(grid, data):
			box(_tile_tool(tools, r.position), Vector3(r.size.x, OUTDOOR_BLOCK_H, 1), Vector3(r.position.x + r.size.x * 0.5, OUTDOOR_BLOCK_H * 0.5, r.position.y + 0.5), Color(0.44, 0.43, 0.42))
	for c in data["trees"]:
		box(_tile_tool(tools, c), Vector3(0.5, 2.5, 0.5), FieldGrid.center(c) + Vector3(0, 1.25, 0), Color(0.3, 0.26, 0.22))
		box(_tile_tool(tools, c), Vector3(2.2, 1.8, 2.2), FieldGrid.center(c) + Vector3(0, 3.0, 0), Color(0.62, 0.66, 0.66))
	for r in data["low_blocks"]:
		var mid := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
		var tall := 1.2 if r.size.x > 1 and r.size.y > 1 else 0.9
		box(_tile_tool(tools, r.position), Vector3(r.size.x - 0.1, tall, r.size.y - 0.1), mid + Vector3(0, tall * 0.5, 0), Color(0.42, 0.4, 0.38))
	for tile in tools:
		var part := _mesh_node()
		part.mesh = tools[tile].commit()


func _tile_tool(tools: Dictionary, c: Vector2i) -> SurfaceTool:
	var tile := c / TILE
	if not tools.has(tile):
		tools[tile] = _begin()
	return tools[tile]


## The faces that glow (weather_fx 12.1): one mesh per kind, unshaded, so they
## cost no light. The pool on the ground is the lamp channel of the sight mask.
func _build_lights() -> void:
	var tools: Dictionary = {}
	for l in data["lights"]:
		var kind := String(l["kind"])
		if not LIGHT_FACES.has(kind):
			continue
		if not tools.has(kind):
			tools[kind] = _begin()
		var face: Dictionary = LIGHT_FACES[kind]
		var side: Vector2i = l.get("side", Vector2i.ZERO)
		var at := FieldGrid.center(l["cell"]) + Vector3(side.x * 0.46, float(face["y"]), side.y * 0.46)
		var size: Vector3 = face["size"]
		box(tools[kind], size if side.y != 0 else Vector3(size.z, size.y, size.x), at, Color(1, 1, 1))
	for kind in tools:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = WINDOW_DARK if kind == "car_window" else FxState.LAMP
		var node := MeshInstance3D.new()
		node.name = "Light_%s" % kind
		node.mesh = tools[kind].commit()
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = kind == "car_window"
		level_roots[0].add_child(node)
		light_nodes[kind] = node
		light_mats[kind] = mat


## An upper floor or the cellar: a floor where there is one, walls by building
## (so the player's own can be cut down), window frames. The walls are built
## from their own floor up and the node is lifted, so cutting them down
## (a scale in y) leaves them standing on that floor, not sunk under it.
func _build_level(lv: int) -> void:
	var lg: FieldGrid = levels[lv]
	var y0 := lv * LEVEL_H
	var floors: Dictionary = {}
	var tools: Dictionary = {}
	var runs: Dictionary = wall_runs(lg)
	for b in runs:
		tools[b] = _begin()
		for r: Rect2i in runs[b]:
			box(tools[b], Vector3(r.size.x, WALL_H, r.size.y), Vector3(r.position.x + r.size.x * 0.5, WALL_H * 0.5, r.position.y + r.size.y * 0.5), Color(0.55, 0.53, 0.5))
	for y in range(lg.height):
		for x in range(lg.width):
			var c := Vector2i(x, y)
			var kind := lg.solid_at(c)
			if kind == S.AIR or (kind == S.BLOCK and lg.building_at(c) < 0):
				continue
			var floor_st: SurfaceTool = _tile_tool(floors, c)
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
			if kind == S.WINDOW:
				if not tools.has(b):
					tools[b] = _begin()
				var horizontal := lg.solid_at(c + Vector2i(1, 0)) == S.WALL or lg.solid_at(c + Vector2i(-1, 0)) == S.WALL
				var size := Vector3(1.0, 0.85, 0.25) if horizontal else Vector3(0.25, 0.85, 1.0)
				box(tools[b], size, Vector3(x + 0.5, 0.43, y + 0.5), Color(0.4, 0.4, 0.42))
				box(tools[b], Vector3(1.0, 0.9, 0.08) if horizontal else Vector3(0.08, 0.9, 1.0), Vector3(x + 0.5, 1.3, y + 0.5), Color(0.62, 0.72, 0.78))
				box(tools[b], size * Vector3(1, 0.12, 1), Vector3(x + 0.5, WALL_H - 0.05, y + 0.5), Color(0.4, 0.4, 0.42))
	for tile in floors:
		var floor_node := _mesh_node(lv)
		floor_node.mesh = floors[tile].commit()
		floor_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for b in tools:
		var node := _mesh_node(lv)
		node.mesh = tools[b].commit()
		node.position.y = y0
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
			box(st, Vector3(0.9, 0.3 + k * 0.3, 0.22), base + Vector3(0, (0.3 + k * 0.3) * 0.5, -0.33 + k * 0.22), Color(0.62, 0.55, 0.44))
		_mesh_node(low).mesh = st.commit()
		var up := _begin()
		var top := Vector3(c.x + 0.5, high * LEVEL_H, c.y + 0.5)
		box(up, Vector3(0.95, 0.03, 0.95), top + Vector3(0, 0.02, 0), Color(0.16, 0.15, 0.15))
		box(up, Vector3(0.06, 0.9, 0.95), top + Vector3(0.47, 0.45, 0), Color(0.48, 0.4, 0.32))
		_mesh_node(high).mesh = up.commit()
		# Named on both floors so the way up or down is found (H3 2026-10-09: never seen).
		_floor_label(LEVEL_WAYS.get(high, ""), c, low)
		_floor_label(LEVEL_WAYS.get(low, ""), c, high)


## A word on the floor, shown once its cell has been seen (as room names are).
func _floor_label(text: String, c: Vector2i, lv: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 44
	label.pixel_size = 0.012
	label.modulate = Color(0.93, 0.88, 0.7, 0.95)
	label.outline_size = 8
	label.outline_modulate = Color(0.1, 0.09, 0.08, 0.8)
	label.rotation_degrees = Vector3(-90, 0, 0)
	label.position = FieldGrid.center(c) + Vector3(0, lv * LEVEL_H + 1.3, 0)
	label.no_depth_test = false
	label.visible = false
	level_roots[lv].add_child(label)
	label_nodes.append([label, c, lv])
