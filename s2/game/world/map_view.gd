extends Node3D
## Graybox visuals for the stop map. Ground, walls and props share one material
## that reads the low-resolution sight mask. Walls of the building the player is
## in are cut down so the rooms stay readable from the oblique camera.
## Each floor hangs under its own root: upstairs floors show only once the
## player climbs to them, and the cellar shows alone.

const FieldGrid = preload("res://game/world/field_grid.gd")
const TrainModels = preload("res://game/world/train_model_kit.gd")
const PropModels = preload("res://game/world/prop_models.gd")
const PropKinds = preload("res://game/world/prop_kinds.gd")
const PropFit = preload("res://game/world/prop_fit.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WALL_H: float = 2.1
const LEVEL_H: float = 3.0
const CUT_H: float = 0.35
## 카메라가 보는 층 바닥의 중심에서 잰 수평 거리(m). 최대 가로 78칸 이내.
const PROP_CULL_DISTANCE: float = 39.0
const PROP_LOD_DISTANCE: float = 18.0
const PROP_REFRESH_SECONDS: float = 0.1
const FxState = preload("res://fx/fx_state.gd")
const ParticlePool = preload("res://fx/particle_pool.gd")
const PUFF_SHADER = preload("res://fx/shaders/blood_burst.gdshader")
const BuildingView = preload("res://game/world/building_view.gd")
const BuildPace = preload("res://game/world/build_pace.gd")
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
var buildings: Node3D             # the building kit (building_view.gd); null draws grey boxes
var train_node: MeshInstance3D    # the train, its doors and the way over it
var cut_building: int = -2
var cut_level: int = 0
var levels: Dictionary = {}       # level -> FieldGrid
var level_roots: Dictionary = {}  # level -> Node3D
var shown_level: int = -99
var prop_batches: Dictionary = {} # 모델 경로 -> {items, nodes(LOD -> MultiMeshInstance3D)}
var modelled_prop_cells: Dictionary = {} # 땅 층에서 모델로 그리는 칸: 회색 덩이 제외용
var prop_fit_counts: Dictionary = {"placed": 0, "turned": 0, "shrunk": 0} # 지도 facing과 다르게 돌린 수, 줄인 수
var _prop_memory := PackedByteArray()
var _prop_seen_now: Dictionary = {}
var _props_mask_on: bool = true
var _prop_elapsed: float = 0.0
var door_nodes: Dictionary = {}   # Vector2i -> MeshInstance3D
var window_nodes: Dictionary = {}
var container_nodes: Dictionary = {}
var spot_nodes: Dictionary = {}
var stove_nodes: Array = []
var manhole_nodes: Dictionary = {}
var lid_nodes: Dictionary = {}          # manhole key -> its lid (and any planks on it), a node of its own so it can move
var lid_anim: Dictionary = {}           # manhole key -> {"kind": "open" or "jolt", "t": seconds in}
var _lid_puff: ParticlePool                   # the snow a dropped lid throws up (ParticlePool), made the first time
## A lid pushed open by one of the dead coming up (decision 422 M9), in seconds
## from the start of its climb: lifted from under and tipped up on the side the
## hands push, dragged aside, dropped in a puff of snow. Where it ends is where
## an open lid always lay. A blocked lid only jolts under its planks and settles.
const LID_OPEN_TIME: float = 0.8
const LID_LIFT_END: float = 0.18
const LID_DROP_AT: float = 0.66
const LID_LIFT: float = 0.14           # metres up from under
const LID_TIP: float = 0.22            # radians; the far edge stays off the ground
const LID_ASIDE: Vector3 = Vector3(1.0, 0.02, 0.25)
const LID_JOLT_TIME: float = 0.6
const LID_JOLT: float = 0.07           # metres, the first of two jolts
const LID_PUFF: Dictionary = {"style": 5, "life": 0.45, "speed": 0.8, "size": 0.18, "gravity": Vector3(0, -1.2, 0), "spread": 70.0, "color": Color(0.70, 0.71, 0.73, 0.5)}
const LEVEL_WAYS := {-1: "지하로", 0: "1층으로", 1: "2층으로", 2: "3층으로"}
var label_nodes: Array = []             # [Label3D, cell]
## Set by a staged stop (field_game.gd): setup then waits a frame between
## pieces (build_pace.gd). Null: all of it in one call.
var pace = null


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
	if BuildingView.can_draw():
		buildings = BuildingView.new()
		buildings.name = "Buildings"
		add_child(buildings)
		await buildings.setup(data, material, pace)
		for key: Vector2i in buildings.shells:
			if buildings.cut_node(key.x, key.y):
				wall_nodes[key] = buildings.cut_node(key.x, key.y)
	await BuildPace.rest(pace)
	await _build_ground()
	_build_walls()
	await BuildPace.rest(pace)
	await _build_props()
	await _build_blocks()
	for lv in levels:
		if lv != 0:
			await _build_level(lv)
	_build_stairs()
	await BuildPace.rest(pace)
	for c in grid.doors:
		if buildings and buildings.draws_cell(c):
			continue
		var node := _mesh_node()
		door_nodes[c] = node
		update_door(c)
	await BuildPace.rest(pace)
	for c in grid.windows:
		if buildings and buildings.draws_cell(c):
			continue
		var node := _mesh_node()
		window_nodes[c] = node
		update_window(c)
	await BuildPace.rest(pace)
	for id in data["containers"]:
		add_container(id)
		await BuildPace.rest(pace)
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
## lid, open shows the lid pushed aside and the dark of the hole. A lid that
## goes from shut to open is pushed aside over LID_OPEN_TIME (advance_lids);
## one that shuts is back at once, as before.
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
	else:
		# The dark of the hole lies under the lid; the lid is drawn on its own node.
		box(st, Vector3(1.0, 0.02, 1.0), Vector3(0, 0.01, 0), Color(0.03, 0.03, 0.04))
		var lid := _lid_node(key, node)
		var ls := _begin()
		box(ls, Vector3(1.1, 0.06, 1.1), Vector3(0, 0.03, 0), Color(0.18, 0.18, 0.2))
		box(ls, Vector3(0.9, 0.02, 0.15), Vector3(0, 0.07, 0), Color(0.3, 0.3, 0.32))
		if blocked:
			box(ls, Vector3(1.2, 0.25, 0.9), Vector3(0, 0.2, 0), Color(0.5, 0.4, 0.28))
		lid.mesh = ls.commit()
		var was_open: bool = lid.get_meta("open", false)
		lid.set_meta("open", open)
		if open and not was_open:
			lid_anim[key] = {"kind": "open", "t": 0.0}
		elif not open:
			lid_anim.erase(key)
			lid.transform = Transform3D.IDENTITY
	node.mesh = st.commit()


func _lid_node(key: String, hole: MeshInstance3D) -> MeshInstance3D:
	if lid_nodes.has(key):
		return lid_nodes[key]
	var lid := MeshInstance3D.new()
	lid.material_override = material
	hole.add_child(lid)
	lid_nodes[key] = lid
	return lid


## The dead under a blocked lid push at it and it holds (decision 422 M9):
## it jolts twice under its planks and settles. Nothing else changes.
func jolt_manhole(key: String) -> void:
	if not lid_nodes.has(key) or (lid_anim.has(key) and lid_anim[key]["kind"] == "open"):
		return
	lid_anim[key] = {"kind": "jolt", "t": 0.0}


## Moves the lids being pushed (field time, from _process; tests call it).
func advance_lids(delta: float) -> void:
	for key in lid_anim.keys():
		var anim: Dictionary = lid_anim[key]
		anim["t"] = float(anim["t"]) + delta
		var lid: MeshInstance3D = lid_nodes[key]
		var t: float = anim["t"]
		if anim["kind"] == "open":
			lid.transform = lid_open_pose(t)
			if t >= LID_OPEN_TIME:
				lid_anim.erase(key)
				_puff(lid.global_position, LID_ASIDE)
		else:
			lid.transform = lid_jolt_pose(t)
			if t >= LID_JOLT_TIME:
				lid_anim.erase(key)
	if _lid_puff != null:
		_lid_puff.advance(delta)


## Where an opening lid is (in its hole's frame), t seconds after the body under
## it began to climb.
static func lid_open_pose(t: float) -> Transform3D:
	var up := Vector3(0, LID_LIFT, 0)
	var tip_axis := Vector3.UP.cross(Vector3(LID_ASIDE.x, 0, LID_ASIDE.z)).normalized()
	var at := Vector3.ZERO
	var tip := 0.0
	if t <= 0.0:
		return Transform3D.IDENTITY
	if t < LID_LIFT_END:
		var k := smoothstep(0.0, LID_LIFT_END, t)
		at = up * k
		tip = LID_TIP * k
	elif t < LID_DROP_AT:
		var k := smoothstep(LID_LIFT_END, LID_DROP_AT, t)
		at = up.lerp(LID_ASIDE + up * 0.6, k)
		tip = lerpf(LID_TIP, LID_TIP * 0.5, k)
	elif t < LID_OPEN_TIME:
		var k := smoothstep(LID_DROP_AT, LID_OPEN_TIME, t)
		at = (LID_ASIDE + up * 0.6).lerp(LID_ASIDE, k)
		tip = lerpf(LID_TIP * 0.5, 0.0, k)
	else:
		return Transform3D(Basis.IDENTITY, LID_ASIDE)
	return Transform3D(Basis(tip_axis, tip), at)


## A blocked lid t seconds after the push: two jolts, the second smaller.
static func lid_jolt_pose(t: float) -> Transform3D:
	if t <= 0.0 or t >= LID_JOLT_TIME:
		return Transform3D.IDENTITY
	var beat := t / (LID_JOLT_TIME * 0.5)
	var size := LID_JOLT if beat < 1.0 else LID_JOLT * 0.5
	var y := size * sin(fposmod(beat, 1.0) * PI)
	return Transform3D(Basis(Vector3.RIGHT, y * 1.5), Vector3(0, y, 0))


func _puff(at: Vector3, away: Vector3) -> void:
	if _lid_puff == null:
		_lid_puff = ParticlePool.new()
		add_child(_lid_puff)
		_lid_puff.prepare(2, PUFF_SHADER)
	_lid_puff.burst(at + Vector3(0, 0.05, 0), Vector3(away.x, 0, away.z).normalized() + Vector3.UP * 0.4, 10, int(at.x * 131.0 + at.z * 17.0), LID_PUFF)


## Room names show once the room has been seen (no free map knowledge).
func update_labels(memory: PackedByteArray, mask_on: bool) -> void:
	var n := grid.width * grid.height
	for row in label_nodes:
		var c: Vector2i = row[1]
		row[0].visible = not mask_on or memory[(int(row[2]) + 1) * n + grid.index(c)] > 0


func set_mask_enabled(on: bool) -> void:
	material.set_shader_parameter("mask_on", 1.0 if on else 0.0)
	_props_mask_on = on
	refresh_props()


## seen_now: sight key (level slice * cells + cell index) -> true; memory:
## PackedByteArray of seen-before flags by the same key. The mask is one
## layer for all floors (only one floor's worth is on screen at a time).
## lamp: cell index -> byte of warm light (LampLight), written to the B channel.
## Only cells that changed since last call are touched.
func update_vis(seen_now: Dictionary, memory: PackedByteArray, lamp: Dictionary = {}) -> void:
	_prop_memory = memory
	_prop_seen_now = seen_now
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
	if buildings:
		buildings.update_seen(vis_bytes)
	refresh_props()


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
	if buildings:
		buildings.show_levels(player_level)
	for lv in level_roots:
		level_roots[lv].visible = lv == -1 if player_level < 0 else lv >= 0 and lv <= player_level
	refresh_props()


## Lower the walls of the building the player is inside, on their floor (−1 = none).
func cut_away(building_id: int, level: int = 0) -> void:
	if building_id == cut_building and level == cut_level:
		return
	cut_building = building_id
	cut_level = level
	if buildings:
		buildings.cut_away(building_id, level)
	for key in wall_nodes:
		if buildings and key.x >= 0:
			continue
		var node: MeshInstance3D = wall_nodes[key]
		var cut: bool = building_id >= 0 and key.x == building_id and key.y == level
		node.scale = Vector3(1, CUT_H / WALL_H if cut else 1.0, 1)
	for c in door_nodes:
		update_door(c)
	for c in window_nodes:
		update_window(c)
	refresh_props()


func update_door(c: Vector2i) -> void:
	if buildings and buildings.draws_cell(c):
		buildings.update_door(c)
		return
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
	if buildings and buildings.draws_cell(c):
		buildings.update_window(c)
		return
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


## A container that was not there when the map was drawn (a heap left by work).
func add_container(id: String) -> void:
	var box_data: Dictionary = data["containers"][id]
	container_nodes[id] = _mesh_node(int(box_data.get("level", 0)))
	PropModels.attach(container_nodes[id], id, FieldGrid.center(box_data["cell"]) + Vector3(0, int(box_data.get("level", 0)) * LEVEL_H, 0), String(box_data.get("name", "")))
	update_container(id)


func update_container(id: String) -> void:
	var box_data: Dictionary = data["containers"][id]
	var node: MeshInstance3D = container_nodes[id]
	var st := _begin()
	var at := FieldGrid.center(box_data["cell"]) + Vector3(0, int(box_data.get("level", 0)) * LEVEL_H, 0)
	var color := Color(0.62, 0.5, 0.3) if not box_data["searched"] else Color(0.35, 0.32, 0.28)
	if node.has_node("Prop") or box_data.has("furniture"):
		# The furniture stands in for the box (a model of its own, or the wardrobe
		# or shelf it was put in by room_furnish); a floor mat keeps the searched colour.
		box(st, Vector3(0.6, 0.02, 0.6), at + Vector3(0, 0.01, 0), color)
	elif box_data["id"] == "bell":
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
static func wall_runs(g: FieldGrid, excluded: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	var single: Dictionary = {}   # cell -> building, the cells that made no row
	for y in range(g.height):
		var start := -1
		var of := 0
		for x in range(g.width + 1):
			var c := Vector2i(x, y)
			var wall: bool = x < g.width and g.solid_at(c) == S.WALL and not excluded.has(c)
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
		await BuildPace.rest(pace)
	for y in range(grid.height):
		await BuildPace.rest(pace)
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
		await BuildPace.rest(pace)


func _build_walls() -> void:
	var runs: Dictionary = wall_runs(grid, buildings.drawn_cells.get(0, {}) if buildings else {})
	for b in runs:
		var st := _begin()
		for r: Rect2i in runs[b]:
			box(st, Vector3(r.size.x, WALL_H, r.size.y), Vector3(r.position.x + r.size.x * 0.5, WALL_H * 0.5, r.position.y + r.size.y * 0.5), Color(0.55, 0.53, 0.5))
		var node := _mesh_node()
		node.mesh = st.commit()
		wall_nodes[Vector2i(b, 0)] = node


## The train rolls this far along the track from where it stood, engine first
## (the stop's closing scene). Its doors go as they are drawn: open.
func slide_train(metres: float) -> void:
	train_node.position.x = metres * train_heading(data)
	# Its window glass and the firebox door are drawn apart: they go with it.
	for kind: String in ["car_window", "firebox"]:
		if light_nodes.has(kind):
			light_nodes[kind].position.x = train_node.position.x


## +1 if the engine is at the train's east end, -1 at its west.
static func train_heading(d: Dictionary) -> float:
	var train: Rect2i = d["train"]
	for car in d["train_cars"]:
		if car["kind"] == "engine":
			var r: Rect2i = car["rect"]
			return 1.0 if r.position.x + r.size.x * 0.5 >= train.position.x + train.size.x * 0.5 else -1.0
	return 1.0


func _build_blocks() -> void:
	var st := _begin()
	# Train: four cars and the engine at the east end; dark so the platform reads.
	# A node of its own, with its doors and the way over it, so it can roll away.
	var tt := _begin()
	var train: Rect2i = data["train"]
	train_node = _mesh_node()
	# 모델을 먼저 붙이고, 모델로 바꾸지 못했다고 돌려받은 칸만 상자로 그린다.
	var models := TrainModels.attach_field(train_node, data)
	await BuildPace.rest(pace)
	for index: int in models.get_meta("fallback_cars", []):
		var car: Dictionary = data["train_cars"][index]
		var r: Rect2i = car["rect"]
		box(tt, Vector3(r.size.x - 0.6, 3.0, 2.8), Vector3(r.position.x + r.size.x * 0.5, 1.5, train.position.y + 1.5), Color(0.3, 0.29, 0.28) if car["kind"] == "car" else Color(0.22, 0.22, 0.24))
	# Doors where people step down, on each side of the train that has them.
	for face in door_faces(data):
		box(tt, Vector3(1.0, 2.0, 0.1), Vector3(face["cell"].x + 0.5, 1.4, face["z"]), Color(0.42, 0.38, 0.33))
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
		box(tt, Vector3(0.9, 0.12, train.size.y), Vector3(at_x, top, train.position.y + train.size.y * 0.5), wood)
		for z: float in [train.position.y - 0.02, train.end.y + 0.02]:
			for k in int(top / 0.3):
				box(tt, Vector3(0.8, 0.07, 0.1), Vector3(at_x, 0.3 + 0.3 * k, z), wood)
	train_node.mesh = tt.commit()
	_build_lights()
	await BuildPace.rest(pace)
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
	await BuildPace.rest(pace)
	# What stands about the map goes by tile, as the ground does: a tree or a
	# stack far off is neither drawn nor made to throw a shadow.
	var tools: Dictionary = {}
	if not data["spots"].has("water_tower"):
		# Other maps: blocked ground out of doors (rock, a bank, a stack) is drawn
		# as it lies, a run of cells a box, so nothing that stops you is unseen.
		for r in outdoor_block_runs(grid, data):
			box(_tile_tool(tools, r.position), Vector3(r.size.x, OUTDOOR_BLOCK_H, 1), Vector3(r.position.x + r.size.x * 0.5, OUTDOOR_BLOCK_H * 0.5, r.position.y + 0.5), Color(0.44, 0.43, 0.42))
	for c in data["trees"]:
		if modelled_prop_cells.has(c):
			continue
		box(_tile_tool(tools, c), Vector3(0.5, 2.5, 0.5), FieldGrid.center(c) + Vector3(0, 1.25, 0), Color(0.3, 0.26, 0.22))
		box(_tile_tool(tools, c), Vector3(2.2, 1.8, 2.2), FieldGrid.center(c) + Vector3(0, 3.0, 0), Color(0.62, 0.66, 0.66))
	for r in data["low_blocks"]:
		var tall := 1.2 if r.size.x > 1 and r.size.y > 1 else 0.9
		for rest in remaining_low_rects(r, modelled_prop_cells):
			var mid := Vector3(rest.position.x + rest.size.x * 0.5, 0, rest.position.y + rest.size.y * 0.5)
			box(_tile_tool(tools, rest.position), Vector3(rest.size.x - 0.1, tall, rest.size.y - 0.1), mid + Vector3(0, tall * 0.5, 0), Color(0.42, 0.4, 0.38))
	await BuildPace.rest(pace)
	for tile in tools:
		var part := _mesh_node()
		part.mesh = tools[tile].commit()
		await BuildPace.rest(pace)


## 모델이 차지한 칸만 덜어낸다. 원래 low_blocks와 FieldGrid는 읽기 전용이다.
static func remaining_low_rects(r: Rect2i, covered: Dictionary) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var touched := false
	for c: Vector2i in covered:
		if r.has_point(c):
			touched = true
			break
	if not touched:
		out.append(r)
		return out
	for y in range(r.position.y, r.end.y):
		var start := -1
		for x in range(r.position.x, r.end.x + 1):
			var keep := x < r.end.x and not covered.has(Vector2i(x, y))
			if keep and start < 0:
				start = x
			elif not keep and start >= 0:
				out.append(Rect2i(start, y, x - start, 1))
				start = -1
	return out


func _build_props() -> void:
	if not PropModels.enabled():
		return
	var chosen: Dictionary = {}
	for prop: Dictionary in data.get("props", []):
		var kind := String(prop.get("kind", ""))
		if not chosen.has(kind):
			chosen[kind] = ""
			for path in PropKinds.candidates(kind):
				if ResourceLoader.exists(path) and not PropModels.batch_meshes(path).is_empty():
					chosen[kind] = path
					break
		var path: String = chosen[kind]
		var lv := int(prop.get("level", 0))
		await BuildPace.rest(pace)
		if path.is_empty() or not levels.has(lv) or not prop.get("rect") is Rect2i:
			continue
		var r: Rect2i = prop["rect"]
		var at := Vector3(r.position.x + r.size.x * 0.5, lv * LEVEL_H, r.position.y + r.size.y * 0.5)
		var lg: FieldGrid = levels[lv]
		var b := int(prop.get("building", lg.building_at(Vector2i(int(at.x), int(at.z)))))
		# 0은 원래 자세, 1~3은 위에서 보아 시계 방향으로 90도씩. 모델의 긴 축을 rect의
		# 긴 축에 맞추고, 남는 작은 넘침만 그 축으로 줄인다(prop_fit.gd). 칸은 그대로.
		var box: AABB = PropModels.batch_meshes(path)[0].get_aabb()
		var fit := PropFit.fit(box.position, box.end, r, int(prop.get("facing", 0)), lg)
		var turn := Basis(Vector3.UP, -float(fit["facing"]) * PI * 0.5)
		var xf := Transform3D(Basis.from_scale(fit["scale"]) * turn, at)
		prop_fit_counts["placed"] += 1
		if fit["turned"]:
			prop_fit_counts["turned"] += 1
		if fit["shrunk"]:
			prop_fit_counts["shrunk"] += 1
		if not prop_batches.has(path):
			prop_batches[path] = {"items": [], "nodes": {}}
		prop_batches[path]["items"].append({"xf": xf, "rect": r, "level": lv, "building": b})
		if lv == 0:
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					modelled_prop_cells[Vector2i(x, y)] = true
	for path: String in prop_batches:
		var batch: Dictionary = prop_batches[path]
		var meshes := PropModels.batch_meshes(path)
		for lod: int in meshes:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = meshes[lod]
			mm.instance_count = batch["items"].size()
			mm.visible_instance_count = 0
			var node := MultiMeshInstance3D.new()
			node.name = "Props_%s_LOD%d" % [path.get_file().get_basename(), lod]
			node.multimesh = mm
			add_child(node)
			batch["nodes"][lod] = node
		await BuildPace.rest(pace)


func _process(delta: float) -> void:
	if not lid_anim.is_empty() or _lid_puff != null:
		advance_lids(delta)
	_prop_elapsed += delta
	if _prop_elapsed >= PROP_REFRESH_SECONDS:
		_prop_elapsed = 0.0
		refresh_props()


## MultiMesh 전체의 거리 범위로는 지도 끝의 소품도 제출된다. 보이는 인스턴스만 앞에 채운다.
## 미리보기는 카메라를 옮긴 직후 같은 함수를 호출한다.
func refresh_props(camera: Camera3D = null) -> void:
	if prop_batches.is_empty() or not is_inside_tree():
		return
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := camera.global_position
	var ray := -camera.global_transform.basis.z
	for batch: Dictionary in prop_batches.values():
		var counts := {0: 0, 1: 0}
		for item: Dictionary in batch["items"]:
			var lv: int = item["level"]
			if not level_roots[lv].visible or (shown_level == -99 and lv != 0):
				continue
			if buildings and not buildings.interior_visible(item["building"], lv):
				continue
			if not _prop_is_seen(item["rect"], lv):
				continue
			var xf: Transform3D = item["xf"]
			var at := to_global(xf.origin)
			var focus := eye + ray * ((at.y - eye.y) / ray.y) if absf(ray.y) > 0.001 else eye
			var distance := Vector2(at.x - focus.x, at.z - focus.z).length()
			if distance > PROP_CULL_DISTANCE:
				continue
			var lod := 1 if distance >= PROP_LOD_DISTANCE and batch["nodes"].has(1) else 0
			var node: MultiMeshInstance3D = batch["nodes"][lod]
			node.multimesh.set_instance_transform(counts[lod], xf)
			counts[lod] += 1
		for lod: int in batch["nodes"]:
			batch["nodes"][lod].multimesh.visible_instance_count = counts[lod]


## 재질은 기존 소품 재질 그대로다. 아직 본 적 없는 층의 소품은 CPU에서 제외한다.
func _prop_is_seen(r: Rect2i, lv: int) -> bool:
	if not _props_mask_on:
		return true
	var n := grid.width * grid.height
	for y in range(maxi(0, r.position.y), mini(grid.height, r.end.y)):
		for x in range(maxi(0, r.position.x), mini(grid.width, r.end.x)):
			var key := (lv + 1) * n + grid.index(Vector2i(x, y))
			if _prop_seen_now.has(key) or (key >= 0 and key < _prop_memory.size() and _prop_memory[key] > 0):
				return true
	return false


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
	var runs: Dictionary = wall_runs(lg, buildings.drawn_cells.get(lv, {}) if buildings else {})
	for b in runs:
		tools[b] = _begin()
		for r: Rect2i in runs[b]:
			box(tools[b], Vector3(r.size.x, WALL_H, r.size.y), Vector3(r.position.x + r.size.x * 0.5, WALL_H * 0.5, r.position.y + r.size.y * 0.5), Color(0.55, 0.53, 0.5))
	for y in range(lg.height):
		await BuildPace.rest(pace)
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
			if kind == S.WINDOW and (buildings == null or not buildings.draws_cell(c, lv)):
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
		await BuildPace.rest(pace)
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
		# Named on both floors so the way up or down is found (H3 2026-10-09: never seen).
		_floor_label(LEVEL_WAYS.get(high, ""), c, low)
		_floor_label(LEVEL_WAYS.get(low, ""), c, high)
		if s.get("hatch", false):
			_build_hatch(c, s["into"])
		if buildings:
			continue
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
	_build_cellar_windows()


## A yard hatch into a big cellar (cellar_rules.hatches): a dark way down
## toward the house in a low timber curb, its leaf thrown open on the far side.
## The house's own stairs well is drawn by building_view; this one stands in
## the yard, outside any building, so the map draws it. Drawing only.
func _build_hatch(c: Vector2i, into: Vector2i) -> void:
	var st := _begin()
	var mid := FieldGrid.center(c)
	var wood := Color(0.36, 0.28, 0.2)
	box(st, Vector3(0.84, 0.02, 0.84), mid + Vector3(0, 0.015, 0), Color(0.05, 0.05, 0.05))
	var side := Vector2i(into.y, into.x)
	for k: int in [-1, 1]:
		var at := mid + Vector3(side.x, 0, side.y) * (0.45 * k) + Vector3(0, 0.09, 0)
		box(st, Vector3(0.1, 0.18, 0.9) if side.x != 0 else Vector3(0.9, 0.18, 0.1), at, wood)
	var back := mid - Vector3(into.x, 0, into.y) * 0.45 + Vector3(0, 0.09, 0)
	box(st, Vector3(0.9, 0.18, 0.1) if into.x == 0 else Vector3(0.1, 0.18, 0.9), back, wood)
	# The leaf, open, leans back on the yard side.
	var leaf := mid - Vector3(into.x, 0, into.y) * 0.56 + Vector3(0, 0.38, 0)
	box(st, Vector3(0.8, 0.6, 0.05) if into.x == 0 else Vector3(0.05, 0.6, 0.8), leaf, wood.darkened(0.15))
	_mesh_node(0).mesh = st.commit()


## Cellar windows: a low dark pane set in the foot of the outer wall on the
## ground floor where a cellar room lies behind it (cellar_rules.windows), so
## a cellar is seen before it is entered (house_layout.md 5.2). Drawing only.
const CELLAR_WINDOW_W: float = 0.7
const CELLAR_WINDOW_H: float = 0.22


func _build_cellar_windows() -> void:
	var rows: Array = data.get("cellar_windows", [])
	if rows.is_empty():
		return
	var st := _begin()
	for row: Dictionary in rows:
		var c: Vector2i = row["cell"]
		var out: Vector2i = row["out"]
		var along_x := out.y != 0
		var pane := Vector3(CELLAR_WINDOW_W, CELLAR_WINDOW_H, 0.03) if along_x else Vector3(0.03, CELLAR_WINDOW_H, CELLAR_WINDOW_W)
		var frame := pane + (Vector3(0.08, 0.06, 0.0) if along_x else Vector3(0.0, 0.06, 0.08))
		# The foot of the wall reaches the cell edge (the plinth), so the pane sits there.
		var face := FieldGrid.center(c) + Vector3(out.x, 0, out.y) * 0.5 + Vector3(0, 0.04 + CELLAR_WINDOW_H * 0.5, 0)
		box(st, frame, face + Vector3(out.x, 0, out.y) * 0.01, Color(0.27, 0.24, 0.21))
		box(st, pane, face + Vector3(out.x, 0, out.y) * 0.025, Color(0.05, 0.05, 0.06))
	_mesh_node(0).mesh = st.commit()


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
