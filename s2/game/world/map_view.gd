extends Node3D
## Graybox visuals for the stop map. Ground, walls and props share one material
## that reads the low-resolution sight mask. Walls of the building the player is
## in are cut down so the rooms stay readable from the oblique camera.
## Each floor hangs under its own root: upstairs floors show only once the
## player climbs to them, and the cellar shows alone.

const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldWork = preload("res://game/field_work.gd")
const BuildingRules = preload("res://game/sim/building_rules.gd")
const LampLight = preload("res://game/sim/lamp_light.gd")
const TrainModels = preload("res://game/world/train_model_kit.gd")
const PropModels = preload("res://game/world/prop_models.gd")
const PropKinds = preload("res://game/world/prop_kinds.gd")
const EdgeBand = preload("res://game/world/edge_band.gd")
const TrackView = preload("res://game/world/track_view.gd")
const PropFit = preload("res://game/world/prop_fit.gd")
const BuildingUses = preload("res://game/world/building_uses.gd")
const FurnitureTints = preload("res://game/world/furniture_tints.gd")
const ObjectRules = preload("res://game/sim/object_rules.gd")
const SearchRules = preload("res://game/sim/search_rules.gd")
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
const Atmosphere = preload("res://fx/atmosphere.gd")
const ParticlePool = preload("res://fx/particle_pool.gd")
const PUFF_SHADER = preload("res://fx/shaders/blood_burst.gdshader")
const CONTACT_SHADER = preload("res://fx/shaders/contact_shade.gdshader")
const BuildingView = preload("res://game/world/building_view.gd")
const BuildPace = preload("res://game/world/build_pace.gd")
const GroundLook = preload("res://game/world/ground_look.gd")
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
var vis_upload_count: int = 0        # texture uploads after setup
var _lit_mark := PackedInt32Array()  # cell -> the update_vis call that last lit it
var _vis_call: int = 0
var track_wait: Dictionary = {}      # snow marks handed over, written at the next sight update
var win_image: Image                 # low sun through the windows, one byte a texel (LampLight.window_cells)
var win_texture: ImageTexture
var light_nodes: Dictionary = {}     # light kind -> MeshInstance3D (the glowing face itself)
var light_mats: Dictionary = {}      # light kind -> StandardMaterial3D
var wall_nodes: Dictionary = {}   # Vector2i(building id, level) -> MeshInstance3D
var buildings: Node3D             # the building kit (building_view.gd); null draws grey boxes
var train_node: MeshInstance3D    # the train, its doors and the way over it
var train_models: Node3D          # the train kit (train_model_kit.gd): the cars' models and their lit windows
var car_windows_lit := false
var cut_building: int = -2
var cut_level: int = 0
var levels: Dictionary = {}       # level -> FieldGrid
var level_roots: Dictionary = {}  # level -> Node3D
var shown_level: int = -99
## What the edge band drew (counts, for the build log and tests).
var edge_band: Dictionary = {}
var prop_batches: Dictionary = {} # 모델 경로 -> {items, nodes(LOD -> MultiMeshInstance3D)}
var object_gray: Array = [] # Individually removable fallbacks for interactive furniture.
var stove_glows: Dictionary = {}
var modelled_prop_cells: Dictionary = {} # 땅 층에서 모델로 그리는 칸: 회색 덩이 제외용
var prop_fit_counts: Dictionary = {"placed": 0, "turned": 0, "shrunk": 0} # 지도 facing과 다르게 돌린 수, 줄인 수
var _prop_memory := PackedByteArray()
var _prop_seen_now: Dictionary = {}
var _props_mask_on: bool = true
var _prop_tile_culling: bool = true # Tests can compare with the full item scan.
var _prop_tile_y: Dictionary = {}  # Vector3i(tile x, tile y, level) -> Vector2(lowest, highest item y), all batches
## How deep the sight mask is drawn, 0..1: 1 in full, less while it comes in
## over a field just handed over from the stop scene (field_game.gd
## MASK_IN_S). Picture only: what is in sight is the same either way.
var mask_shade: float = 1.0
var _prop_elapsed: float = 0.0
var door_nodes: Dictionary = {}   # Vector2i -> MeshInstance3D
var window_nodes: Dictionary = {}
var container_nodes: Dictionary = {} # id -> Node3D, only containers with a Prop model
var container_chunks: Dictionary = {} # Vector3i(tile x, tile y, level) -> {node, ids}
var _container_chunk: Dictionary = {} # id -> chunk key
var _container_batching: bool = false
var ground_nodes: Dictionary = {}       # level -> MeshInstance3D (what lies on the ground, ground_look.gd; its rims a child "Rim")
var _ground_sig: int = 0
var _contact_materials: Dictionary = {}   # "rim" / "prop" / "box" -> ShaderMaterial (contact_shade.gdshader)
## Every prop's contact shade (T0-6) in one MultiMesh, filled with the props in refresh_props.
var prop_shades: MultiMeshInstance3D = null
var spot_nodes: Dictionary = {}
var dig_nodes: Dictionary = {}
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
## The ground and the floors (by level) were laid from the stop loader's arrays (2a).
var ground_from_loader: bool = false
var floor_from_loader: Dictionary = {}


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
	material.set_shader_parameter("ground_layers", preload("res://fx/textures/ground/ground_layers.png"))
	material.set_shader_parameter("ground_layers_on", true)
	material.set_shader_parameter("region_band", int(Atmosphere.region_key(str(data.get("region_band", Atmosphere.DEFAULT_REGION))).substr(1)))
	win_image = Image.create(grid.width * LampLight.WINDOW_TEXELS, grid.height * LampLight.WINDOW_TEXELS, false, Image.FORMAT_R8)
	win_texture = ImageTexture.create_from_image(win_image)
	material.set_shader_parameter("win", win_texture)
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
	# 지도 칸 밖: 숲 띠·눈둑·밖으로 이어지는 길과 선로(edge_band.gd, 결정 448 17번).
	edge_band = await EdgeBand.build(level_roots[0], grid, data, material, FLOOR_COLORS, pace)
	# 선로 칸의 침목과 레일, 지도 밖으로 이어지는 것까지, 건널목 판자(track_view.gd, 결정 476·M1).
	TrackView.build(level_roots[0], grid, material, edge_band.get("rail_runs", []), data.get("rail_crossings", []))
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
	_container_batching = true
	for id: String in data["containers"]:
		add_container(id)
		await BuildPace.rest(pace)
	_container_batching = false
	for key: Vector3i in container_chunks:
		_bake_container_chunk(key)
		await BuildPace.rest(pace)
	for id in data["spots"]:
		var node := _mesh_node()
		spot_nodes[id] = node
		update_spot(id)
	for stove in data["stoves"]:
		var lv: int = int(stove.get("level", 0))
		var node := _mesh_node(lv)
		stove_nodes.append(node)
		update_stove(stove_nodes.size() - 1)
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
	material.set_shader_parameter("mask_on", mask_shade if on else 0.0)
	_props_mask_on = on
	refresh_props()


func set_mask_shade(k: float) -> void:
	mask_shade = clampf(k, 0.0, 1.0)
	if _props_mask_on:
		material.set_shader_parameter("mask_on", mask_shade)


## seen_now: sight key (level slice * cells + cell index) -> true; memory:
## PackedByteArray of seen-before flags by the same key. The mask is one
## layer for all floors (only one floor's worth is on screen at a time).
## lamp: cell index -> byte of warm light (LampLight), written to the B channel.
## Only cells that changed since last call are touched.
func update_vis(seen_now: Dictionary, memory: PackedByteArray, lamp: Dictionary = {}) -> void:
	_prop_memory = memory
	_prop_seen_now = seen_now
	var n: int = grid.width * grid.height
	# Changed cells in a packed list, a cell lit this call marked with the call's
	# number (no dictionaries: this runs every 0.1 s over every cell in sight).
	var changed := PackedInt32Array()
	var everything := false
	if vis_bytes.size() != n * 4:
		vis_bytes.resize(n * 4)
		vis_bytes.fill(0)
		for i in range(n):
			vis_bytes[i * 4 + 3] = 255
		for k in range(memory.size()):
			if memory[k]:
				vis_bytes[(k % n) * 4 + 1] = 255
		_lit_mark.resize(n)
		_lit_mark.fill(-1)
		everything = true
	_vis_call += 1
	var lit := PackedInt32Array()
	for key: int in seen_now:
		var i: int = key % n
		if _lit_mark[i] == _vis_call:
			continue
		_lit_mark[i] = _vis_call
		lit.append(i)
		if vis_bytes[i * 4] != 255 or vis_bytes[i * 4 + 1] != 255:
			vis_bytes[i * 4] = 255
			vis_bytes[i * 4 + 1] = 255
			changed.append(i)
	for i: int in vis_lit:
		if _lit_mark[i] != _vis_call and vis_bytes[i * 4] != 0:
			vis_bytes[i * 4] = 0
			changed.append(i)
	vis_lit = lit
	for i: int in track_wait:
		if vis_bytes[i * 4 + 3] != int(track_wait[i]):
			vis_bytes[i * 4 + 3] = int(track_wait[i])
			changed.append(i)
	track_wait = {}
	for i: int in lamp_lit:
		if not lamp.has(i) and vis_bytes[i * 4 + 2] != 0:
			vis_bytes[i * 4 + 2] = 0
			changed.append(i)
	for i: int in lamp:
		if vis_bytes[i * 4 + 2] != int(lamp[i]):
			vis_bytes[i * 4 + 2] = int(lamp[i])
			changed.append(i)
	lamp_lit = PackedInt32Array(lamp.keys())
	if everything or not changed.is_empty():
		vis_image.set_data(grid.width, grid.height, false, Image.FORMAT_RGBA8, vis_bytes)
		vis_texture.update(vis_image)
		vis_upload_count += 1
		if buildings:
			if everything:
				changed = PackedInt32Array(range(n))
			buildings.update_seen(vis_bytes, changed)
	refresh_props()


## Snow marks (SnowTracks.take_changed: cell index -> byte, 255 untouched) for
## the A channel. Uploaded with the next sight update, so it costs no extra upload.
func update_tracks(changed: Dictionary) -> void:
	for i in changed:
		track_wait[i] = changed[i]


## How strong the lamp light shows on the ground: faint by day, full at night.
## reveal: how far a lamp's pool out of doors shows through the sight mask
## (0 by day, 1 at night, decision 474 B9). floor_level: the player's floor,
## whose floor the lamps light besides the ground.
## Out of doors by day the sight mask is round and soft about the eye (decision
## 491): where the eye stands (x z), the sight's reach in metres, how much day there
## is (0 leaves the cells to rule, as at night and indoors) and the floor out there.
## The buildings' outside faces and roofs take the same.
func set_sight_round(eye: Vector2, reach: float, day: float, floor_level: float) -> void:
	var mats: Array = [material]
	if buildings != null and buildings.get("material") is ShaderMaterial:
		mats.append(buildings.material)
	for m: ShaderMaterial in mats:
		m.set_shader_parameter("eye_xz", eye)
		m.set_shader_parameter("eye_r", reach)
		m.set_shader_parameter("round_day", clampf(day, 0.0, 1.0))
		m.set_shader_parameter("round_floor", floor_level)


func set_lamp_gain(gain: float, reveal: float = 0.0, floor_level: int = 0) -> void:
	material.set_shader_parameter("lamp_gain", clampf(gain, 0.0, 1.0))
	material.set_shader_parameter("lamp_reveal", clampf(reveal, 0.0, 1.0))
	material.set_shader_parameter("lamp_floor", floor_level * LEVEL_H)


## The low sun's pools through the windows (texel index -> byte) and their colour.
func update_window_light(texels: Dictionary, color: Color) -> void:
	var bytes := PackedByteArray()
	bytes.resize(win_image.get_width() * win_image.get_height())
	for i in texels:
		bytes[int(i)] = int(texels[i])
	win_image.set_data(win_image.get_width(), win_image.get_height(), false, Image.FORMAT_R8, bytes)
	win_texture.update(win_image)
	material.set_shader_parameter("win_color", color)


## The glowing faces themselves (car windows, the firebox door, the gap in the
## hideout boards): lit ones show amber, unlit car windows stay as dark glass.
## The model coaches light their own panes (the train kit); a car window face is
## left only on a car the kit could not draw.
func set_light_on(kind: String, on: bool) -> void:
	if kind == "car_window":
		car_windows_lit = on
		if train_models != null:
			train_models.set_windows_lit(on)
	if not light_nodes.has(kind):
		return
	if kind == "car_window":
		light_mats[kind].albedo_color = FxState.LAMP if on else WINDOW_DARK
	else:
		light_nodes[kind].visible = on


func light_is_on(kind: String) -> bool:
	if kind == "car_window":
		return car_windows_lit
	if not light_nodes.has(kind):
		return false
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
	_planks(st, c, door, horizontal, [0.65, 1.1, 1.55, 1.9])
	node.mesh = st.commit()


## Boards on each face of a door or window (J08), a plank a height.
func _planks(st: SurfaceTool, c: Vector2i, d: Dictionary, horizontal: bool, heights: Array) -> void:
	var sides := grid.faces(c)
	for f in 2:
		var dir := Vector3(sides[f].x - c.x, 0, sides[f].y - c.y) * 0.13
		for i in range(mini(BuildingRules.planks(d, f), heights.size())):
			box(st, Vector3(1.0, 0.12, 0.04) if horizontal else Vector3(0.04, 0.12, 1.0), FieldGrid.center(c) + dir + Vector3(0, float(heights[i]), 0), Color(0.42, 0.33, 0.24))


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
		if win["broken"] or win.get("open", false):
			box(st, size * Vector3(1, 1, 1) + Vector3(0, 0.0, 0), at + Vector3(0, WALL_H - 0.05, 0), Color(0.4, 0.4, 0.42))
		else:
			box(st, (Vector3(1.0, 1.0, 0.08) if horizontal else Vector3(0.08, 1.0, 1.0)), at + Vector3(0, 1.3, 0), Color(0.62, 0.72, 0.78))
			box(st, size, at + Vector3(0, WALL_H - 0.05, 0), Color(0.4, 0.4, 0.42))
		_planks(st, c, win, horizontal, [1.6, 1.0, 1.3, 1.85])
		if BuildingRules.has_curtain(win):
			var outer := grid.outer_face(c)
			var sides := grid.faces(c)
			var f := 1 - outer if outer >= 0 else 1
			var in_off := Vector3(sides[f].x - c.x, 0, sides[f].y - c.y) * 0.2
			if String(win["curtain"]) == "closed":
				box(st, Vector3(0.95, 1.1, 0.03) if horizontal else Vector3(0.03, 1.1, 0.95), at + in_off + Vector3(0, 1.35, 0), Color(0.24, 0.22, 0.24))
			else:
				var along := Vector3(0.4, 0, 0) if horizontal else Vector3(0, 0, 0.4)
				for k in [-1.0, 1.0]:
					box(st, Vector3(0.14, 1.1, 0.04) if horizontal else Vector3(0.04, 1.1, 0.14), at + in_off + along * k + Vector3(0, 1.35, 0), Color(0.24, 0.22, 0.24))
	var shards: Array = [at] if win["glass"] else []
	for fell: Vector2i in grid.floor_glass:
		if grid.floor_glass[fell] == c:
			shards.append(FieldGrid.center(fell))
	for spot: Vector3 in shards:
		for k in range(5):
			var o := Vector3(fmod(k * 0.37, 0.8) - 0.4, 0.02, fmod(k * 0.53, 0.8) - 0.4)
			box(st, Vector3(0.12, 0.03, 0.08), spot + o, Color(0.8, 0.9, 0.95))
	node.mesh = st.commit()


## A container that was not there when the map was drawn (a heap left by work).
func add_container(id: String) -> void:
	if has_container(id):
		update_container(id)
		return
	var box_data: Dictionary = data["containers"][id]
	var lv: int = int(box_data.get("level", 0))
	var holder: Node3D = Node3D.new()
	var at: Vector3 = FieldGrid.center(box_data["cell"]) + Vector3(0, lv * LEVEL_H, 0)
	if PropModels.attach(holder, id, at, String(box_data.get("name", ""))):
		level_roots[lv].add_child(holder)
		container_nodes[id] = holder
		_shade_container(holder, box_data)
	else:
		holder.free()
	var key: Vector3i = _container_key(box_data)
	_join_container_chunk(id, key)
	if not _container_batching:
		_bake_container_chunk(key)


## Model parents are optional; these also cover boxes drawn only in a chunk.
func has_container(id: String) -> bool:
	return _container_chunk.has(id)


## Every box drawn, model or not (a copy: safe to remove while walking it).
func container_ids() -> Array:
	return _container_chunk.keys()


func container_mesh(id: String) -> Mesh:
	if not has_container(id):
		return null
	var node: MeshInstance3D = container_chunks[_container_chunk[id]]["node"] as MeshInstance3D
	return node.mesh


func _container_key(box_data: Dictionary) -> Vector3i:
	var cell: Vector2i = box_data["cell"] as Vector2i
	return Vector3i(floori(cell.x / float(TILE)), floori(cell.y / float(TILE)), int(box_data.get("level", 0)))


func _join_container_chunk(id: String, key: Vector3i) -> void:
	if not container_chunks.has(key):
		container_chunks[key] = {"node": _mesh_node(key.z), "ids": {}}
	container_chunks[key]["ids"][id] = true
	_container_chunk[id] = key


func update_container(id: String) -> void:
	if not has_container(id):
		add_container(id)
		return
	var box_data: Dictionary = data["containers"][id]
	var old_key: Vector3i = _container_chunk[id] as Vector3i
	var key: Vector3i = _container_key(box_data)
	if old_key != key:
		container_chunks[old_key]["ids"].erase(id)
		_join_container_chunk(id, key)
		_bake_container_chunk(old_key)
	if container_nodes.has(id):
		var holder: Node3D = container_nodes[id] as Node3D
		if holder.get_parent() != level_roots[key.z]:
			holder.reparent(level_roots[key.z], false)
		(holder.get_node("Prop") as Node3D).position = FieldGrid.center(box_data["cell"]) + Vector3(0, key.z * LEVEL_H, 0)
		_shade_container(holder, box_data)
	_bake_container_chunk(key)


func _bake_container_chunk(key: Vector3i) -> void:
	var chunk: Dictionary = container_chunks[key] as Dictionary
	var node: MeshInstance3D = chunk["node"] as MeshInstance3D
	if (chunk["ids"] as Dictionary).is_empty():
		node.free()
		container_chunks.erase(key)
		return
	var st: SurfaceTool = _begin()
	var rims: SurfaceTool = _begin()
	var marked := false
	for id: String in chunk["ids"]:
		marked = _bake_container(st, rims, id) or marked
	node.mesh = st.commit()
	# The empty marks' dark rims, a child drawn with contact_shade (as update_ground's).
	var rim_node := node.get_node_or_null("Rim") as MeshInstance3D
	if marked and rim_node == null:
		rim_node = MeshInstance3D.new()
		rim_node.name = "Rim"
		rim_node.material_override = _contact_material("rim")
		rim_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(rim_node)
	if rim_node != null:
		rim_node.mesh = rims.commit() if marked else null


## One box into its chunk's mesh; true when it shows empty (its mark's rims went into `rims`).
func _bake_container(st: SurfaceTool, rims: SurfaceTool, id: String) -> bool:
	var box_data: Dictionary = data["containers"][id]
	var at := FieldGrid.center(box_data["cell"]) + Vector3(0, int(box_data.get("level", 0)) * LEVEL_H, 0)
	var color := Color(0.62, 0.5, 0.3) if not box_data["searched"] else Color(0.35, 0.32, 0.28)
	if container_nodes.has(id) or box_data.has("furniture"):
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
	# Nothing to take, seen before it is opened (card P3 가, decision 472): four
	# corners on the floor round the box, in its chunk mesh — so they show only
	# where the box does (the floor shown, the sight mask over it).
	if SearchRules.shows_empty(box_data) and box_data["id"] != "bell":
		_empty_corners(st, at)
		var level := int(box_data.get("level", 0))
		_empty_rims(rims, at, sky_alpha(grid, box_data["cell"]) if level == 0 else 0.0)
		return true
	return false


## The empty mark's four corners round a box's cell, a cold pale grey low on the
## floor (a stand-in; art3d gives it its look). Vertex colours are sRGB here, as
## the floors' are (world_vis.gdshader makes them linear). Alpha 0: no snow, rain
## or ground grain over it (that shader reads vertex alpha as open to the sky), so
## the mark reads the same in every season, indoors and out, as the things on
## the ground do (decision 472).
const EMPTY_MARK := Color(0.58, 0.62, 0.70, 0.0)


func _empty_corners(st: SurfaceTool, at: Vector3) -> void:
	for bar: Array in _empty_bars(at):
		box(st, bar[0], bar[1], EMPTY_MARK)


## The mark's eight bars, [size, centre]: two at each corner of the box's cell.
static func _empty_bars(at: Vector3) -> Array:
	var out: Array = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var corner := at + Vector3(sx * 0.42, 0.012, sz * 0.42)
			out.append([Vector3(0.24, 0.015, 0.06), corner + Vector3(-sx * 0.09, 0, 0)])
			out.append([Vector3(0.06, 0.015, 0.24), corner + Vector3(0, 0, -sz * 0.09)])
	return out


## A dark rim round each of the mark's bars, as the ground things have (T0-6):
## the pale bars alone sink into a pale floor (an oatmeal carpet at night 0.020
## against loot-feel's 0.085), on their rims they stand off any of them.
static func _empty_rims(st: SurfaceTool, at: Vector3, sky: float) -> void:
	for bar: Array in _empty_bars(at):
		var rim: Dictionary = GroundLook.rim({"lv": 0, "size": bar[0], "at": bar[1]})
		rim["sky"] = sky
		_rim_quad(st, rim)


## What lies on the ground (game.ground_items, shapes from ground_look.gd): one
## mesh a level, made again only when the list has changed; under it the things'
## dark rims (ground_look.rim), a child mesh drawn with contact_shade.gdshader.
func update_ground(items: Array) -> void:
	var sig := items.hash()
	if sig == _ground_sig or level_roots.is_empty():
		return
	_ground_sig = sig
	var tools: Dictionary = {}
	var rims: Dictionary = {}
	for piece: Dictionary in GroundLook.pieces(items):
		var lv: int = piece["lv"]
		if not level_roots.has(lv):
			continue
		if not tools.has(lv):
			tools[lv] = _begin()
			rims[lv] = _begin()
		box(tools[lv], piece["size"], piece["at"], piece["color"])
		var rim: Dictionary = GroundLook.rim(piece)
		rim["sky"] = sky_alpha(grid, FieldGrid.cell_of(piece["at"])) if lv == 0 else 0.0
		_rim_quad(rims[lv], rim)
	for lv in ground_nodes:
		ground_nodes[lv].mesh = null
		(ground_nodes[lv].get_node("Rim") as MeshInstance3D).mesh = null
	for lv in tools:
		if not ground_nodes.has(lv):
			ground_nodes[lv] = _mesh_node(lv)
			var rim_node := MeshInstance3D.new()
			rim_node.name = "Rim"
			rim_node.material_override = _contact_material("rim")
			rim_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ground_nodes[lv].add_child(rim_node)
		ground_nodes[lv].mesh = tools[lv].commit()
		(ground_nodes[lv].get_node("Rim") as MeshInstance3D).mesh = rims[lv].commit()


## One rim quad (ground_look.rim) flat on the floor: the thing's share of it, the
## strength and whether it lies open to the sky (rim "sky", 1 if not given; 0
## under a roof, as the floors' vertex alpha) go in the vertex colour
## (contact_shade.gdshader keeps it full indoors whatever the season).
static func _rim_quad(st: SurfaceTool, rim: Dictionary, strength: float = GroundLook.RIM_STRENGTH) -> void:
	var at: Vector3 = rim["at"]
	var h: Vector2 = (rim["size"] as Vector2) * 0.5
	var inner: Vector2 = rim["inner"]
	var c := Color(inner.x, inner.y, strength, float(rim.get("sky", 1.0)))
	var corners := [Vector3(-h.x, 0, -h.y), Vector3(h.x, 0, -h.y), Vector3(h.x, 0, h.y), Vector3(-h.x, 0, h.y)]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_color(c)
		st.set_uv(uvs[idx])
		st.set_normal(Vector3.UP)
		st.add_vertex(at + corners[idx])


## The contact shades' materials: "rim" round the things on the ground (a crisp
## core, then the last pixel smoothed), "prop" for the props' MultiMesh and "box"
## under a container's own model (soft from the footprint out). First of the
## see-through things, so rain, snow and blood draw over them.
func _contact_material(kind: String) -> ShaderMaterial:
	if not _contact_materials.has(kind):
		var m := ShaderMaterial.new()
		m.shader = CONTACT_SHADER
		m.set_shader_parameter("core", 0.6 if kind == "rim" else SHADE_CORE)
		m.set_shader_parameter("per_instance", kind == "prop")
		m.set_shader_parameter("rect_custom", kind == "box")
		m.render_priority = Material.RENDER_PRIORITY_MIN
		_contact_materials[kind] = m
	return _contact_materials[kind]


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
			var color: Color = Color(0.9, 0.76, 0.4) if spot["state"] == "ready" else Color(0.45, 0.45, 0.45)
			box(st, Vector3(1.2, 0.05, 1.2), at + Vector3(0, 0.03, 0), color)
			var filled: int = clampi(roundi(float(spot.get("work_share", 0.0)) * FieldWork.SHARE_CELLS), 0, FieldWork.SHARE_CELLS)
			for i in FieldWork.SHARE_CELLS:
				var angle: float = float(i) * TAU / FieldWork.SHARE_CELLS
				var offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * 0.95
				var tint: Color = Color(0.95, 0.6, 0.18) if i < filled else Color(0.24, 0.23, 0.21)
				box(st, Vector3(0.22, 0.05, 0.22), at + offset + Vector3(0, 0.04, 0), tint)
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
		"core":
			# A stopped machine (core_scenes.gd): a dark casing with its panel off. Only a core
			# still in it shows, a dull brass lump; a hidden one looks as stripped as the rest.
			# Its back to the wall, its open side ("face") to the room.
			var casing := Color(0.3, 0.3, 0.31)
			var f: Vector2i = spot.get("face", Vector2i(0, 1))
			var out := Vector3(f.x, 0, f.y)
			var side := Vector3(absf(out.z), 0, absf(out.x))   # along the wall
			box(st, Vector3(0.95, 1.0, 0.95), at - out * 0.02 + Vector3(0, 0.5, 0), casing)
			box(st, Vector3(0.5, 0.3, 0.5), at - out * 0.22 + Vector3(0, 1.15, 0), casing.darkened(0.2))
			box(st, side * 0.6 + out.abs() * 0.4 + Vector3(0, 0.05, 0), at + out * 0.75 + side * 0.15 + Vector3(0, 0.03, 0), casing.lightened(0.1))
			if spot["state"] == "core":
				# In the open hatch on top, so the camera sees it from any side.
				box(st, side * 0.4 + out.abs() * 0.3 + Vector3(0, 0.14, 0), at + out * 0.2 + Vector3(0, 1.07, 0), Color(0.5, 0.43, 0.28))
	node.mesh = st.commit()


## Six boxes above the wagon's work cell; the same filled count keeps the same mesh.
func update_dig(id: String, work_cell: Vector2i, filled: int) -> void:
	var node: MeshInstance3D = dig_nodes.get(id)
	if filled < 0:
		if node != null:
			node.visible = false
		return
	if node == null:
		node = _mesh_node()
		dig_nodes[id] = node
	node.position = FieldGrid.center(work_cell) + Vector3(0, 1.6, 0)
	node.visible = true
	if int(node.get_meta("cells", -1)) == filled:
		return
	var st := _begin()
	for i in FieldWork.DIG_CELLS:
		var offset: float = (float(i) - float(FieldWork.DIG_CELLS - 1) * 0.5) * 0.28
		var tint: Color = Color(0.95, 0.6, 0.18) if i < filled else Color(0.24, 0.23, 0.21)
		box(st, Vector3(0.22, 0.08, 0.14), Vector3(offset, 0, 0), tint)
	node.mesh = st.commit()
	node.set_meta("cells", filled)


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


## A road this wide across or more is a street: a centre line, pavement beside it.
const STREET_WIDTH: int = 4
## Narrower than this across: a footpath, paved like the pavement.
const PATH_WIDTH: int = 3

## What the ground shader draws on each cell beyond its floor kind (world_vis
## bare_ground, 결정 469 C1·C4: road, pavement, yard soil, dry grass). Picture
## only: the floor kind stays the rule (sound, speed). The first width*height
## values are the cells:
##   open ground (SNOW, DEEP_SNOW) out of doors: 0 grass, -1 pavement along x,
##   -2 along z, -3 a pavement corner;
##   ROAD: bits 0~3 the sides (N, E, S, W) that meet open ground (kerb and
##   gutter), bit 4 a centre line along x, bit 5 along z, bits 6~8 where it lies
##   across the cell in quarter metres, bit 9 a footpath;
##   PLATFORM: bits 0~3 the sides at the rails (edge stripe), bit 4 laid along x,
##   bit 5 along z.
## Then one value a corner of the grid, (width+1)*(height+1): how much bare soil
## shows on grass there, 0..1 (trodden before doors, the strip at a wall's foot),
## so the soil fades out over the cells instead of stopping at their edges.
static func ground_details(g: FieldGrid) -> PackedFloat32Array:
	# Plain arrays and index sums only: this runs over every cell of the map
	# (48,000 on the largest), so no per-cell calls (stop load time).
	var w := g.width
	var h := g.height
	var n := w * h
	var fl := g.floor
	var so := g.solid
	var bu := g.building
	var out := PackedFloat32Array()
	out.resize(n + (w + 1) * (h + 1))
	# How far each road and platform cell runs along x and along z: from, to.
	var rx0 := PackedInt32Array()
	var rx1 := PackedInt32Array()
	var rz0 := PackedInt32Array()
	var rz1 := PackedInt32Array()
	rx0.resize(n)
	rx1.resize(n)
	rz0.resize(n)
	rz1.resize(n)
	for y in h:
		var row := y * w
		var x := 0
		while x < w:
			var k := fl[row + x]
			if k != F.ROAD and k != F.PLATFORM:
				x += 1
				continue
			var x1 := x
			while x1 + 1 < w and fl[row + x1 + 1] == k:
				x1 += 1
			for i in range(row + x, row + x1 + 1):
				rx0[i] = x
				rx1[i] = x1
			x = x1 + 1
	for x in w:
		var y := 0
		while y < h:
			var k := fl[y * w + x]
			if k != F.ROAD and k != F.PLATFORM:
				y += 1
				continue
			var y1 := y
			while y1 + 1 < h and fl[(y1 + 1) * w + x] == k:
				y1 += 1
			for yy in range(y, y1 + 1):
				rz0[yy * w + x] = y
				rz1[yy * w + x] = y1
			y = y1 + 1
	# Where each street runs (1 along x, 2 along z), for the pavement beside it.
	var street := PackedByteArray()
	street.resize(n)
	for y in h:
		for x in w:
			var i := y * w + x
			var f := fl[i]
			if f != F.ROAD and f != F.PLATFORM:
				continue
			var len_x := rx1[i] - rx0[i] + 1
			var len_z := rz1[i] - rz0[i] + 1
			var bits := 0
			# The sides N, E, S, W; off the map counts as more of the same.
			var nb: Array[int] = [i - w if y > 0 else -1, i + 1 if x + 1 < w else -1, i + w if y + 1 < h else -1, i - 1 if x > 0 else -1]
			for s in 4:
				var j: int = nb[s]
				if j < 0:
					continue
				var nf := fl[j]
				if f == F.ROAD and nf != F.ROAD and nf != F.RAIL and nf != F.PLATFORM and nf != F.ICE:
					bits |= 1 << s
				elif f == F.PLATFORM and nf == F.RAIL:
					bits |= 1 << s
			# Along the longer run; a crossing (both long) has no direction.
			var along := 0
			if len_x >= len_z * 2:
				along = 1
			elif len_z >= len_x * 2:
				along = 2
			if f == F.PLATFORM:
				bits |= along << 4
			else:
				var across := len_z if along == 1 else len_x if along == 2 else mini(len_x, len_z)
				if across < PATH_WIDTH:
					bits |= 1 << 9
				elif across >= STREET_WIDTH and along > 0:
					street[i] = along
					# The line at the middle of the street, in this cell or on its edge;
					# none where a side road joins (the street is wider there or beside it).
					var c0 := rz0 if along == 1 else rx0
					var c1 := rz1 if along == 1 else rx1
					var mid := (c0[i] + c1[i] + 1) * 0.5
					var at := mid - float(y if along == 1 else x)
					var even := true
					for j: int in ([nb[3], nb[1]] if along == 1 else [nb[0], nb[2]]):
						if j >= 0 and fl[j] == F.ROAD and (c0[j] != c0[i] or c1[j] != c1[i]):
							even = false
					if even and at >= 0.0 and at <= 1.0:
						bits |= (1 << 4) if along == 1 else (1 << 5)
						bits |= int(round(at * 4.0)) << 6
			out[i] = float(bits)
	# Walls (and the building behind them) and doors, for the soil at their feet.
	var wall := PackedByteArray()
	wall.resize(n)
	for i in n:
		var s := so[i]
		wall[i] = 2 if s == S.DOOR else 1 if (bu[i] >= 0 or s == S.WALL or s == S.WINDOW) else 0
	# Pavement: open ground out of doors beside a street (corners too).
	var soil := PackedFloat32Array()
	soil.resize(n)
	for y in h:
		var y0 := maxi(y - 1, 0)
		var y1 := mini(y + 1, h - 1)
		for x in w:
			var i := y * w + x
			var f := fl[i]
			if (f != F.SNOW and f != F.DEEP_SNOW) or bu[i] >= 0 or so[i] != S.NONE:
				continue
			var x0 := maxi(x - 1, 0)
			var x1 := mini(x + 1, w - 1)
			var along := 0
			var near := 0
			for yy in range(y0, y1 + 1):
				for xx in range(x0, x1 + 1):
					var j := yy * w + xx
					along |= street[j]
					near = maxi(near, wall[j])
			if along > 0:
				out[i] = -3.0 if along == 3 else -float(along)
			elif near == 2:
				soil[i] = 1.0
			elif near == 1:
				soil[i] = 0.7
	# Soil a corner: the mean of the cells that meet there (walls count as soil,
	# so the strip hugs them), read only by the grass cells around it.
	for y in h + 1:
		for x in w + 1:
			var sum := 0.0
			for yy in range(maxi(y - 1, 0), mini(y, h - 1) + 1):
				for xx in range(maxi(x - 1, 0), mini(x, w - 1) + 1):
					var j := yy * w + xx
					# A door in a building's wall counts as wall here.
					sum += 0.8 if wall[j] == 1 or (wall[j] == 2 and bu[j] >= 0) else soil[j]
			out[n + y * (w + 1) + x] = sum * 0.25
	return out


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


## A wagon the model kit has none for, as [size, centre, colour] boxes: a floor on its wheels and four
## low sides, open on top, its coal heaped inside a little over the sides. No closed wagon (map brief,
## ban list); the field's map and the stop scene both draw it so.
static func open_wagon_parts(w: Dictionary) -> Array:
	var r: Rect2i = w["rect"]
	var mid := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
	var lx: float = r.size.x - 0.2
	var lz: float = r.size.y - 0.2
	var body := Color(0.33, 0.3, 0.28)
	var out: Array = [[Vector3(lx, 0.3, lz), mid + Vector3(0, 0.75, 0), body]]
	for s: float in [-1.0, 1.0]:
		out.append([Vector3(lx, 1.0, 0.12), mid + Vector3(0, 1.4, s * (lz - 0.12) * 0.5), body])
		out.append([Vector3(0.12, 1.0, lz), mid + Vector3(s * (lx - 0.12) * 0.5, 1.4, 0), body])
	if float(w.get("coal", 0.0)) > 0.0:
		out.append([Vector3(lx - 0.6, 1.1, lz - 0.6), mid + Vector3(0, 1.45, 0), Color(0.12, 0.12, 0.13)])
	return out


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


## The ground's tiles are worked out from the map alone (2a), so the stop loader's
## worker makes them ahead (stop_loader.gd make_ready): `data["_ground_arrays"]`, one
## ground_tile a tile, with `_ground_key` the map they fit. Here only the meshes and
## nodes are made; a map without them, or changed since, is worked out here the same
## way, resting a row of banks and a tile at a time (a tile now takes less than one
## row of cells did through a SurfaceTool).
func _build_ground() -> void:
	var arrays: Dictionary = {}
	ground_from_loader = data.get("_ground_arrays") is Dictionary and data.get("_ground_key") == ground_key(grid)
	if ground_from_loader:
		arrays = data["_ground_arrays"]
	else:
		var banks := PackedVector2Array()
		for y in range(grid.height + 1):
			ground_bank_row(grid, y, banks)
			await BuildPace.rest(pace)
		var details: PackedFloat32Array = data["_ground_details"] if data.get("_ground_details") is PackedFloat32Array else ground_details(grid)
		for tile in ground_tiles(grid):
			await BuildPace.rest(pace)
			arrays[tile] = ground_tile(grid, details, banks, tile)
	# Read once; not kept with the map.
	for key: String in ["_ground_details", "_ground_arrays", "_ground_key"]:
		data.erase(key)
	for tile in arrays:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays[tile])
		var node := _mesh_node()
		node.mesh = mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		await BuildPace.rest(pace)


## Every tile of the ground's arrays at once (the loader's worker): {tile: arrays}.
static func ground_arrays(g: FieldGrid, details: PackedFloat32Array) -> Dictionary:
	var banks := PackedVector2Array()
	for y in range(g.height + 1):
		ground_bank_row(g, y, banks)
	var out: Dictionary = {}
	for tile in ground_tiles(g):
		out[tile] = ground_tile(g, details, banks, tile)
	return out


## The map a set of ground arrays fits: its size, floors and buildings and what stands
## out of doors (ground_details reads walls, doors and windows only there). Furniture
## the field paints in a room after the loader (room_stories.gd) changes none of it.
static func ground_key(g: FieldGrid) -> Array:
	var outdoors := PackedInt32Array()
	outdoors.resize(g.solid.size())
	for i in g.solid.size():
		if g.building[i] < 0:
			outdoors[i] = g.solid[i]
	return [g.width, g.height, hash(g.floor), hash(g.building), hash(outdoors)]


## The map an upper floor's or the cellar's floor arrays fit: its size, floors and
## which cells have a floor laid (level_floor_row).
static func floor_key(lg: FieldGrid) -> Array:
	var laid := PackedByteArray()
	laid.resize(lg.solid.size())
	for i in lg.solid.size():
		var kind: int = lg.solid[i]
		laid[i] = 0 if kind == S.AIR or (kind == S.BLOCK and lg.building[i] < 0) else 1
	return [lg.width, lg.height, hash(lg.floor), hash(laid)]


## One answer a corner, shared by the cells that meet there: corner row y. drift_uv
## over the plain arrays (a call a corner was most of the ground's time): change the
## two together (test_ground_arrays holds them to the same answer).
static func ground_bank_row(g: FieldGrid, y: int, banks: PackedVector2Array) -> void:
	var w := g.width
	var so := g.solid
	var bu := g.building
	var at := banks.size()
	banks.resize(at + w + 1)
	for x in range(w + 1):
		var side_x := 0
		var side_y := 0
		var open := false
		var door := false
		# The cells meeting at the corner, as drift_uv's (-1, -1), (0, -1), (-1, 0), (0, 0).
		for dy in [-1, 0]:
			var cy: int = y + dy
			if cy < 0 or cy >= g.height:
				continue
			for dx in [-1, 0]:
				var cx: int = x + dx
				if cx < 0 or cx >= w:
					continue
				var i := cy * w + cx
				var kind := so[i]
				if kind == S.DOOR:
					door = true
				elif kind == S.WALL or kind == S.BLOCK or kind == S.WINDOW:
					side_x += 1 + dx * 2
					side_y += 1 + dy * 2
				elif kind == S.NONE and bu[i] < 0:
					open = true
		banks[at + x] = Vector2(signi(side_x), signi(side_y)) if open and not door else Vector2.ZERO


## The ground's tiles, a row of them at a time (laid in tiles, so what is off the
## screen is not drawn).
static func ground_tiles(g: FieldGrid) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for ty in range(ceili(g.height / float(TILE))):
		for tx in range(ceili(g.width / float(TILE))):
			out.append(Vector2i(tx, ty))
	return out


## One tile's arrays, a cell's two triangles after another, row by row: what a
## SurfaceTool given the same corners gives (commit_to_arrays), written straight
## into the arrays (the calls a corner were the rest of the ground's time).
static func ground_tile(g: FieldGrid, details: PackedFloat32Array, banks: PackedVector2Array, tile: Vector2i) -> Array:
	var w := g.width
	var fl := g.floor
	var bu := g.building
	var cells := w * g.height
	var bw := w + 1
	var x0 := tile.x * TILE
	var y0 := tile.y * TILE
	var x1 := mini(x0 + TILE, w)
	var y1 := mini(y0 + TILE, g.height)
	var n := (x1 - x0) * (y1 - y0) * 6
	var verts := PackedVector3Array()
	verts.resize(n)
	var normals := PackedVector3Array()
	normals.resize(n)
	normals.fill(Vector3.UP)
	var colors := PackedColorArray()
	colors.resize(n)
	var uv := PackedVector2Array()
	uv.resize(n)
	var uv2 := PackedVector2Array()
	uv2.resize(n)
	var at := 0
	for y in range(y0, y1):
		for x in range(x0, x1):
			var i := y * w + x
			var f := fl[i]
			# One colour a kind: the shader gives the grain (no cell checker, 결정 469 C4).
			var color := FLOOR_COLORS[f]
			color.a = 0.0 if bu[i] >= 0 else 1.0  # sky_alpha
			# The corners a, east, south-east, south; the triangles a, east, south-east and
			# a, south-east, south.
			var k0 := y * bw + x
			var k1 := k0 + 1
			var k2 := k0 + bw + 1
			var k3 := k0 + bw
			var p0 := Vector3(x, 0, y)
			var p2 := Vector3(x + 1, 0, y + 1)
			# The floor kind for world_vis bare_ground (0: not ground), and what is drawn
			# on it: open grass takes the soil weight of its corner (smooth), every other
			# cell its own code (ground_details).
			var kind := float(f + 1)
			var cell_detail := details[i]
			var d0 := Vector2(kind, cell_detail)
			var d1 := d0
			var d2 := d0
			var d3 := d0
			if cell_detail == 0.0 and (f == F.SNOW or f == F.DEEP_SNOW):
				d0.y = details[cells + k0]
				d1.y = details[cells + k1]
				d2.y = details[cells + k2]
				d3.y = details[cells + k3]
			verts[at] = p0
			verts[at + 1] = Vector3(x + 1, 0, y)
			verts[at + 2] = p2
			verts[at + 3] = p0
			verts[at + 4] = p2
			verts[at + 5] = Vector3(x, 0, y + 1)
			uv[at] = banks[k0]
			uv[at + 1] = banks[k1]
			uv[at + 2] = banks[k2]
			uv[at + 3] = banks[k0]
			uv[at + 4] = banks[k2]
			uv[at + 5] = banks[k3]
			uv2[at] = d0
			uv2[at + 1] = d1
			uv2[at + 2] = d2
			uv2[at + 3] = d0
			uv2[at + 4] = d2
			uv2[at + 5] = d3
			for j in 6:
				colors[at + j] = color
			at += 6
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	return arrays


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


## The trees standing on the map's tree cells (data["trees"]) are models chosen by the
## place (결정 478: map group -> region; user 10-28 「나무도 빠르게 바꿔야」): spruce in
## the forest and mountain stops, willow by water, leafless broadleaf, street and fruit
## trees in town. The cells and their solids stay as they are; with no model a tree is
## the grey trunk and box crown as before. Each model is made on a one-cell footprint,
## so its crown is widened by its spread, as the woods past the edge (edge_band.gd).
const TREE_SPRUCE := "res://models/props_field/spruce.glb"
const TREE_BARE := "res://models/props_common/bare_tree.glb"
const TREE_WILLOW := "res://models/props_field/bare_willow.glb"
const TREE_STREET := "res://models/props_field/street_tree.glb"
const TREE_ORCHARD := "res://models/props_field/bare_orchard_tree.glb"
## Shares of each model by region; a map with no group is mixed as the rail works.
const TREE_WOODS: Array = [[TREE_SPRUCE, 0.7], [TREE_BARE, 0.2], [TREE_WILLOW, 0.1]]
const TREE_MIX: Dictionary = {
	"town": [[TREE_BARE, 0.45], [TREE_STREET, 0.25], [TREE_SPRUCE, 0.2], [TREE_ORCHARD, 0.1]],
	"rail_works": [[TREE_BARE, 0.5], [TREE_SPRUCE, 0.35], [TREE_WILLOW, 0.15]],
	"waterside": [[TREE_SPRUCE, 0.55], [TREE_WILLOW, 0.25], [TREE_BARE, 0.2]],
	"mountain_works": TREE_WOODS, "high_mountain": TREE_WOODS, "bare_line": TREE_WOODS,
}
## Height range (m) and crown spread of each model.
const TREE_SIZE: Dictionary = {
	TREE_SPRUCE: [4.0, 6.0, 1.7], TREE_BARE: [4.5, 6.5, 1.8], TREE_WILLOW: [4.0, 5.5, 1.8],
	TREE_STREET: [4.5, 6.0, 1.8], TREE_ORCHARD: [2.6, 3.6, 1.8],
}
## Tree models go in pieces this many cells a side, fewer than the ground's tiles.
const TREE_PIECE: int = TILE * 2


## The tree on cell `c` of `place_id`'s map: {model, at, yaw, height, spread}, the same
## every time. Off the middle of its cell by a little, so a row of tree cells is no row.
static func tree_plant(place_id: String, c: Vector2i) -> Dictionary:
	var mix: Array = TREE_MIX.get(BuildingUses.region_of(place_id), TREE_MIX["rail_works"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:tree:%d:%d" % [place_id, c.x, c.y])
	var pick := rng.randf()
	var model: String = mix[-1][0]
	for row: Array in mix:
		pick -= float(row[1])
		if pick < 0.0:
			model = row[0]
			break
	var size: Array = TREE_SIZE[model]
	var at := FieldGrid.center(c) + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
	return {"model": model, "at": at, "yaw": rng.randf() * TAU, "height": rng.randf_range(size[0], size[1]), "spread": float(size[2])}


## One MultiMesh per tree model and TREE_PIECE square; they throw shadows as the
## box trees did. Returns the trees that had no model, for the grey boxes.
func _build_tree_models(cells: Array) -> Array:
	var place_id := String(data.get("place_id", ""))
	var meshes: Dictionary = {}
	var pieces: Dictionary = {}
	var left: Array = []
	for c: Vector2i in cells:
		var plant := tree_plant(place_id, c)
		var path := String(plant["model"])
		if not meshes.has(path):
			var ok := PropModels.enabled() and ResourceLoader.exists(path) and not PropModels.batch_meshes(path).is_empty()
			meshes[path] = PropModels.batch_meshes(path)[0] if ok else null
		if meshes[path] == null:
			left.append(c)
			continue
		var piece := c / TREE_PIECE
		var key := "%s|%d|%d" % [path, piece.x, piece.y]
		if not pieces.has(key):
			pieces[key] = []
		(pieces[key] as Array).append(plant)
	for key: String in pieces:
		var list: Array = pieces[key]
		var mesh: Mesh = meshes[String(key.get_slice("|", 0))]
		var mesh_h := maxf(mesh.get_aabb().size.y, 0.01)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			var plant: Dictionary = list[i]
			var up := float(plant["height"]) / mesh_h
			var across := up * float(plant["spread"])
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(plant["yaw"])).scaled(Vector3(across, up, across)), plant["at"]))
		var node := MultiMeshInstance3D.new()
		node.name = "Trees_%s_%s_%s" % [key.get_slice("|", 0).get_file().get_basename(), key.get_slice("|", 1), key.get_slice("|", 2)]
		node.multimesh = mm
		level_roots[0].add_child(node)
	return left


func _build_blocks() -> void:
	var st := _begin()
	# Train: four cars and the engine at the east end; dark so the platform reads.
	# A node of its own, with its doors and the way over it, so it can roll away.
	var tt := _begin()
	var train: Rect2i = data["train"]
	train_node = _mesh_node()
	# 선로 위면 바퀴가 레일 윗면에 서게 올린다(굴러가는 장면은 x만 바꾼다).
	train_node.position.y = TrackView.height_under(grid, train)
	# 모델을 먼저 붙이고, 모델로 바꾸지 못했다고 돌려받은 칸만 상자로 그린다.
	var models := TrainModels.attach_field(train_node, data)
	train_models = models
	models.set_windows_lit(car_windows_lit)
	await BuildPace.rest(pace)
	for index: int in models.get_meta("fallback_cars", []):
		var car: Dictionary = data["train_cars"][index]
		var r: Rect2i = car["rect"]
		box(tt, Vector3(r.size.x - 0.6, 3.0, 2.8), Vector3(r.position.x + r.size.x * 0.5, 1.5, train.position.y + 1.5), Color(0.3, 0.29, 0.28) if car["kind"] == "car" else Color(0.22, 0.22, 0.24))
	# Doors where people step down, on each side of the train that has them: the
	# kit's door pieces on the coaches' sides, a box only where it has none.
	var faces := door_faces(data)
	var doors := TrainModels.attach_doors(train_node, faces, data)
	for index: int in doors.get_meta("fallback_doors", []):
		var face: Dictionary = faces[index]
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
	# The window and firebox faces stand with the train on its rails (slide_train moves them along).
	for kind: String in ["car_window", "firebox"]:
		if light_nodes.has(kind):
			light_nodes[kind].position.y = train_node.position.y
	await BuildPace.rest(pace)
	# Wagons on the sidings: the kit's models, an open box only where it has none.
	var wagon_models := TrainModels.attach_wagons(level_roots[0], data["wagons"], TrackView.wagon_heights(grid, data["wagons"]))
	for index: int in wagon_models.get_meta("fallback_wagons", []):
		for part: Array in open_wagon_parts(data["wagons"][index]):
			box(st, part[0], part[1], part[2])
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
	var tree_cells: Array = []
	for c in data["trees"]:
		if not modelled_prop_cells.has(c):
			tree_cells.append(c)
	for c in _build_tree_models(tree_cells):
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
	var chosen: Dictionary = {}
	for prop: Dictionary in data.get("props", []):
		var kind := String(prop.get("kind", ""))
		if not chosen.has(kind):
			chosen[kind] = ""
			for path in PropKinds.candidates(kind):
				if PropModels.enabled() and ResourceLoader.exists(path) and not PropModels.batch_meshes(path).is_empty():
					chosen[kind] = path
					break
		var path: String = chosen[kind]
		var lv := int(prop.get("level", 0))
		if _interactive_prop(kind) and prop.get("rect") is Rect2i and levels.has(lv):
			# These cells never enter the static gray mesh: their own node moves.
			if lv == 0:
				for c in _object_cells(prop["rect"]):
					modelled_prop_cells[c] = true
			if path.is_empty():
				_draw_object_gray(prop)
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
			prop_batches[path] = {"items": [], "nodes": {}, "tiles": {}}
		var item: Dictionary = {"xf": xf, "rect": r, "level": lv, "building": b, "prop": prop, "remembered": false}
		if FurnitureTints.applies(path):
			# 한 집 가구는 한 칠 판(줄의 tint, 없으면 건물 번호, 둘 다 없으면 칸).
			item["tint"] = FurnitureTints.pick(prop, r.position, b)
		prop_batches[path]["items"].append(item)
		_index_prop(prop_batches[path], item)
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
			if FurnitureTints.applies(path):
				mm.use_custom_data = true
				FurnitureTints.dress(meshes[lod])
			mm.mesh = meshes[lod]
			mm.instance_count = batch["items"].size()
			mm.visible_instance_count = 0
			var node := MultiMeshInstance3D.new()
			node.name = "Props_%s_LOD%d" % [path.get_file().get_basename(), lod]
			node.multimesh = mm
			add_child(node)
			batch["nodes"][lod] = node
		await BuildPace.rest(pace)
	_make_prop_shades()


static func _interactive_prop(kind: String) -> bool:
	return ObjectRules.WOOD_KINDS.has(kind)


static func _object_cells(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


func _draw_object_gray(prop: Dictionary) -> void:
	var lv := int(prop.get("level", 0))
	var r: Rect2i = prop["rect"]
	var node := _mesh_node(lv)
	var st := _begin()
	var height := 0.3 if bool(prop.get("fallen", false)) else 1.2
	var at := Vector3(r.position.x + r.size.x * 0.5, lv * LEVEL_H + height * 0.5, r.position.y + r.size.y * 0.5)
	box(st, Vector3(r.size.x - 0.1, height, r.size.y - 0.1), at, Color(0.42, 0.4, 0.38))
	node.mesh = st.commit()
	object_gray.append({"prop": prop, "node": node})


## Change one furnishing, refilling only its model-path batch (both LODs).
func update_prop(prop: Dictionary, removed: bool = false) -> void:
	for i in range(object_gray.size() - 1, -1, -1):
		if is_same(object_gray[i]["prop"], prop):
			object_gray[i]["node"].free()
			object_gray.remove_at(i)
	var modelled := false
	for path: String in prop_batches:
		var batch: Dictionary = prop_batches[path]
		var changed := false
		for i in range(batch["items"].size() - 1, -1, -1):
			var item: Dictionary = batch["items"][i]
			if not is_same(item.get("prop", {}), prop):
				continue
			changed = true
			modelled = true
			_unindex_prop(batch, item)
			if removed:
				batch["items"].remove_at(i)
			else:
				var lv: int = int(prop.get("level", 0))
				var lg: FieldGrid = levels[lv] as FieldGrid
				var rect: Rect2i = prop["rect"] as Rect2i
				item["rect"] = prop["rect"]
				item["xf"] = _object_transform(prop, path)
				item.erase("shade")
				item["level"] = lv
				item["building"] = int(prop.get("building", lg.building_at(rect.get_center())))
				item["remembered"] = false
				_index_prop(batch, item)
		if changed:
			for node: MultiMeshInstance3D in batch["nodes"].values():
				node.multimesh.instance_count = batch["items"].size()
				node.multimesh.visible_instance_count = 0
			break
	if not modelled and not removed:
		var path := String(prop.get("legacy_model", ""))
		if PropModels.enabled() and path != "" and ResourceLoader.exists(path) and not PropModels.batch_meshes(path).is_empty():
			_add_object_batch(prop, path)
		else:
			_draw_object_gray(prop)
	refresh_props()


func _add_object_batch(prop: Dictionary, path: String) -> void:
	if not prop_batches.has(path):
		prop_batches[path] = {"items": [], "nodes": {}, "tiles": {}}
	var batch: Dictionary = prop_batches[path]
	var item: Dictionary = {"prop": prop, "rect": prop["rect"], "level": int(prop.get("level", 0)),
		"building": int(prop.get("building", -1)), "xf": _object_transform(prop, path), "remembered": false}
	if FurnitureTints.applies(path):
		item["tint"] = FurnitureTints.pick(prop, (prop["rect"] as Rect2i).position, int(item["building"]))
	batch["items"].append(item)
	_index_prop(batch, item)
	var meshes := PropModels.batch_meshes(path)
	for lod: int in meshes:
		if not batch["nodes"].has(lod):
			var node := MultiMeshInstance3D.new()
			node.name = "Object_%s_LOD%d" % [path.get_file().get_basename(), lod]
			node.multimesh = MultiMesh.new()
			node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			if FurnitureTints.applies(path):
				node.multimesh.use_custom_data = true
				FurnitureTints.dress(meshes[lod])
			node.multimesh.mesh = meshes[lod]
			add_child(node)
			batch["nodes"][lod] = node
		batch["nodes"][lod].multimesh.instance_count = batch["items"].size()
		batch["nodes"][lod].multimesh.visible_instance_count = 0


## Tiles hold the same item dictionaries as the model-path batch.
func _index_prop(batch: Dictionary, item: Dictionary) -> void:
	var xf: Transform3D = item["xf"] as Transform3D
	var key: Vector3i = Vector3i(floori(xf.origin.x / float(TILE)), floori(xf.origin.z / float(TILE)), int(item["level"]))
	var tiles: Dictionary = batch["tiles"] as Dictionary
	if not tiles.has(key):
		tiles[key] = {"items": [], "min_y": xf.origin.y, "max_y": xf.origin.y}
	var tile: Dictionary = tiles[key] as Dictionary
	tile["items"].append(item)
	tile["min_y"] = minf(float(tile["min_y"]), xf.origin.y)
	tile["max_y"] = maxf(float(tile["max_y"]), xf.origin.y)
	item["tile"] = key
	# All batches' tiles in one table, so a refill tests each tile once. The
	# heights only grow (a wider span reaches further: never too few items).
	var span: Vector2 = _prop_tile_y.get(key, Vector2(xf.origin.y, xf.origin.y))
	_prop_tile_y[key] = Vector2(minf(span.x, xf.origin.y), maxf(span.y, xf.origin.y))


func _unindex_prop(batch: Dictionary, item: Dictionary) -> void:
	var key: Vector3i = item["tile"] as Vector3i
	var tiles: Dictionary = batch["tiles"] as Dictionary
	var tile: Dictionary = tiles[key] as Dictionary
	var items: Array = tile["items"] as Array
	for i in range(items.size()):
		if is_same(items[i], item):
			items.remove_at(i)
			break
	if items.is_empty():
		tiles.erase(key)
		return
	var min_y: float = INF
	var max_y: float = -INF
	for other: Dictionary in items:
		var xf: Transform3D = other["xf"] as Transform3D
		min_y = minf(min_y, xf.origin.y)
		max_y = maxf(max_y, xf.origin.y)
	tile["min_y"] = min_y
	tile["max_y"] = max_y


## Project a displacement along the camera ray onto the ground plane.
func _prop_ground_offset(offset: Vector3, ray: Vector3) -> Vector2:
	var flat: Vector2 = Vector2(offset.x, offset.z)
	if absf(ray.y) > 0.001:
		flat -= Vector2(ray.x, ray.z) * (offset.y / ray.y)
	return flat


func _nearby_prop_items(batch: Dictionary, eye: Vector3, ray: Vector3) -> Array:
	return _prop_items_in(batch, _near_prop_tiles(eye, ray))


## The tiles in reach of the camera, tested once a refill for all batches.
func _near_prop_tiles(eye: Vector3, ray: Vector3) -> Dictionary:
	var near: Dictionary = {}
	var focus: Vector3 = eye + ray * ((global_position.y - eye.y) / ray.y) if absf(ray.y) > 0.001 else eye
	var half_x: Vector2 = _prop_ground_offset(global_transform.basis.x * (TILE * 0.5), ray)
	var half_z: Vector2 = _prop_ground_offset(global_transform.basis.z * (TILE * 0.5), ray)
	var radius: float = maxf((half_x + half_z).length(), (half_x - half_z).length())
	var height_stride: float = _prop_ground_offset(global_transform.basis.y, ray).length()
	for key: Vector3i in _prop_tile_y:
		var span: Vector2 = _prop_tile_y[key]
		var at: Vector3 = to_global(Vector3((key.x + 0.5) * TILE, (span.x + span.y) * 0.5, (key.y + 0.5) * TILE))
		# With a level-zero item this is 39 m plus half a tile diagonal. Projecting
		# upper floors too keeps the bound conservative for their shifted focus.
		var reach: float = PROP_CULL_DISTANCE + radius + (span.y - span.x) * 0.5 * height_stride
		if _prop_ground_offset(at - focus, ray).length() <= reach + 0.001:
			near[key] = true
	return near


func _prop_items_in(batch: Dictionary, near: Dictionary) -> Array:
	if not _prop_tile_culling:
		return batch["items"] as Array
	var items: Array = []
	var tiles: Dictionary = batch["tiles"]
	for key: Vector3i in tiles:
		if near.has(key):
			items.append_array(tiles[key]["items"])
	return items


func _object_transform(prop: Dictionary, path: String) -> Transform3D:
	var lv := int(prop.get("level", 0))
	var r: Rect2i = prop["rect"]
	var at := Vector3(r.position.x + r.size.x * 0.5, lv * LEVEL_H, r.position.y + r.size.y * 0.5)
	var bounds: AABB = PropModels.batch_meshes(path)[0].get_aabb()
	var fit := PropFit.fit(bounds.position, bounds.end, r, int(prop.get("facing", 0)), levels[lv])
	var turn := Basis(Vector3.UP, -float(fit["facing"]) * PI * 0.5)
	if not bool(prop.get("fallen", false)):
		return Transform3D(Basis.from_scale(fit["scale"]) * turn, at)
	turn = Basis(Vector3.RIGHT, PI * 0.5) * turn
	var laid: AABB = Transform3D(turn, Vector3.ZERO) * bounds
	var scale0 := Vector3((r.size.x - 0.1) / maxf(laid.size.x, 0.01), 0.35 / maxf(laid.size.y, 0.01), (r.size.y - 0.1) / maxf(laid.size.z, 0.01))
	var offset := -laid.get_center() * scale0
	offset.y = -laid.position.y * scale0.y
	return Transform3D(Basis.from_scale(scale0) * turn, at + offset)


func move_object_container(id: String) -> void:
	if not has_container(id):
		return
	var box_data: Dictionary = data["containers"][id]
	if container_nodes.has(id) and bool(box_data.get("object_legacy", false)):
		container_nodes[id].free() # The moved furnishing now owns its batch.
		container_nodes.erase(id)
	update_container(id)


func remove_object_container(id: String) -> void:
	if not has_container(id):
		return
	if container_nodes.has(id):
		container_nodes[id].free()
		container_nodes.erase(id)
	var key: Vector3i = _container_chunk[id] as Vector3i
	container_chunks[key]["ids"].erase(id)
	_container_chunk.erase(id)
	_bake_container_chunk(key)


## Only the stove glows. Three broad, faint wisps sit just above its top;
## there is no emitter, chimney, vertical smoke trail or spreading fire.
func update_stove(idx: int) -> void:
	if idx < 0 or idx >= stove_nodes.size():
		return
	var stove: Dictionary = data["stoves"][idx]
	var lv := int(stove.get("level", 0))
	var node: MeshInstance3D = stove_nodes[idx]
	var base := FieldGrid.center(stove["cell"]) + Vector3(0, lv * LEVEL_H, 0)
	var st := _begin()
	box(st, Vector3(0.8, 0.9, 0.8), base + Vector3(0, 0.45, 0), Color(0.25, 0.24, 0.23))
	if stove["lit"]:
		box(st, Vector3(0.5, 0.06, 0.5), base + Vector3(0, 0.93, 0), Color(0.95, 0.55, 0.25))
	node.mesh = st.commit()
	if stove_glows.has(idx):
		stove_glows[idx].free()
		stove_glows.erase(idx)
	if not stove["lit"]:
		return
	var holder := Node3D.new()
	holder.name = "StoveWarmth%d" % idx
	level_roots[lv].add_child(holder)
	holder.position = base
	stove_glows[idx] = holder
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.58, 0.26)
	light.light_energy = ObjectRules.LIGHT_STRENGTH
	light.omni_range = ObjectRules.LIGHT_REACH
	light.shadow_enabled = false
	light.position.y = 1.0
	holder.add_child(light)
	var mist := StandardMaterial3D.new()
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist.albedo_color = Color(0.86, 0.87, 0.85, 0.055)
	for i in range(3):
		var puff := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.12
		puff.mesh = sphere
		puff.material_override = mist
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.position = Vector3((i - 1) * 0.16, 1.03 + (i % 2) * 0.08, (i - 1) * 0.06)
		holder.add_child(puff)
	_refresh_object_details()


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
	_refresh_object_details()
	if prop_batches.is_empty() or not is_inside_tree():
		return
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := camera.global_position
	var ray := -camera.global_transform.basis.z
	var near := _near_prop_tiles(eye, ray) if _prop_tile_culling else {}
	var shades: MultiMesh = prop_shades.multimesh if prop_shades != null else null
	var shaded := 0
	if shades != null:
		var total := 0
		for batch: Dictionary in prop_batches.values():
			total += (batch["items"] as Array).size()
		if shades.instance_count < total:
			shades.instance_count = total
	for path: String in prop_batches:
		var batch: Dictionary = prop_batches[path]
		var counts := {0: 0, 1: 0}
		for item: Dictionary in _prop_items_in(batch, near):
			var lv: int = item["level"]
			if not level_roots[lv].visible or (shown_level == -99 and lv != 0):
				continue
			if buildings and not buildings.interior_visible(item["building"], lv):
				continue
			if not _prop_is_seen(item["rect"], lv, item):
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
			if node.multimesh.use_custom_data:
				node.multimesh.set_instance_custom_data(counts[lod], Color(float(int(item.get("tint", -1)) + 1), 0.0, 0.0, 0.0))
			counts[lod] += 1
			if shades != null:
				if not item.has("shade"):
					item["shade"] = _prop_shade(path, item)
				var shade: Dictionary = item["shade"]
				if not shade.is_empty():
					shades.set_instance_transform(shaded, shade["xf"])
					shades.set_instance_custom_data(shaded, shade["foot"])
					shaded += 1
		for lod: int in batch["nodes"]:
			batch["nodes"][lod].multimesh.visible_instance_count = counts[lod]
	if shades != null:
		shades.visible_instance_count = shaded


## Contact shade under the props (T0-6): how far it reaches past a prop's footprint
## (metres; more for a taller one) and how dark it is at the footprint (more for a
## taller one, contact_shade.gdshader).
const SHADE_MARGIN: float = 0.2
const SHADE_MARGIN_PER_M: float = 0.3
const SHADE_MARGIN_MAX: float = 0.5
const SHADE_STRENGTH: float = 0.5
const SHADE_STRENGTH_TALL: float = 0.65
## How much of the margin keeps the full strength before it fades (contact_shade core).
const SHADE_CORE: float = 0.2
## A model's foot: its vertices this far over its lowest (_shade_foot).
const SHADE_FOOT_H: float = 0.15
static var _shade_feet: Dictionary = {}
## Raised this far over its floor or more, a model hangs on a wall or stands on something: no shade.
const SHADE_FLOOR_GAP: float = 0.05


## One MultiMesh for every prop's shade: a flat quad (x and z from -0.5 to 0.5,
## UV across it), no shadow, drawn first of the see-through things.
func _make_prop_shades() -> void:
	var st := _begin()
	var corners := [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uvs[idx])
		st.set_normal(Vector3.UP)
		st.add_vertex(corners[idx])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = st.commit()
	mm.visible_instance_count = 0
	prop_shades = MultiMeshInstance3D.new()
	prop_shades.name = "ContactProps"
	prop_shades.multimesh = mm
	prop_shades.material_override = _contact_material("prop")
	prop_shades.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The quads are set every refresh: one box round the whole map and its storeys.
	prop_shades.custom_aabb = AABB(Vector3(0, -LEVEL_H - 1.0, 0), Vector3(grid.width, LEVEL_H * 4.0 + 2.0, grid.height))
	add_child(prop_shades)


## A prop's shade as placed (item["xf"]): {"xf" (the quad, its height the strength and one more
## under a roof, contact_shade.gdshader), "foot" (the
## footprint's rect in the quad)}. The footprint is the model's box as placed (turned in quarter
## turns, or laid down if fallen, so it stays square to the map); the margin stops at the side of its
## cells where a wall, anything solid or another building stands, so no shade shows through a wall.
## {} for a model that does not stand on its floor.
func _prop_shade(path: String, item: Dictionary) -> Dictionary:
	var meshes := PropModels.batch_meshes(path)
	if meshes.is_empty():
		return {}
	var xf: Transform3D = item["xf"]
	var mesh: Mesh = meshes[0]
	var placed: AABB = xf * mesh.get_aabb()
	var lo := placed.position
	var hi := placed.end
	var lv: int = item["level"]
	var floor_y := lv * LEVEL_H
	var prop: Dictionary = item.get("prop", {})
	if lo.y > floor_y + SHADE_FLOOR_GAP or String(prop.get("mount", "")) == "wall" or not levels.has(lv):
		return {}
	var tall := clampf(hi.y - floor_y, 0.0, 2.0)
	if xf.basis.y.normalized().y > 0.9:
		# Standing: round what touches the floor (a tree's trunk, a bench's legs), not its crown.
		var foot: AABB = xf * _shade_foot(path, mesh)
		lo = Vector3(foot.position.x, lo.y, foot.position.z)
		hi = Vector3(foot.end.x, hi.y, foot.end.z)
	var margin := minf(SHADE_MARGIN + SHADE_MARGIN_PER_M * tall, SHADE_MARGIN_MAX)
	var r: Rect2i = item["rect"]
	var lg: FieldGrid = levels[lv]
	var b: int = item["building"]
	var x0 := lo.x - margin
	var x1 := hi.x + margin
	var z0 := lo.z - margin
	var z1 := hi.z + margin
	if _shade_stops(lg, r, Vector2i(-1, 0), b):
		x0 = maxf(x0, minf(lo.x, r.position.x))
	if _shade_stops(lg, r, Vector2i(1, 0), b):
		x1 = minf(x1, maxf(hi.x, r.end.x))
	if _shade_stops(lg, r, Vector2i(0, -1), b):
		z0 = maxf(z0, minf(lo.z, r.position.y))
	if _shade_stops(lg, r, Vector2i(0, 1), b):
		z1 = minf(z1, maxf(hi.z, r.end.y))
	var w := x1 - x0
	var d := z1 - z0
	var strength := lerpf(SHADE_STRENGTH, SHADE_STRENGTH_TALL, clampf(tall / 1.5, 0.0, 1.0))
	var sky := sky_alpha(grid, r.position) if lv == 0 else 0.0
	var quad := Transform3D(Basis.from_scale(Vector3(w, strength + 1.0 - sky, d)), Vector3((x0 + x1) * 0.5, floor_y + 0.006, (z0 + z1) * 0.5))
	var foot := Color((lo.x - x0) / w, (lo.z - z0) / d, (hi.x - x0) / w, (hi.z - z0) / d)
	return {"xf": quad, "foot": foot}


## What of a model stands on its floor: its vertices up to SHADE_FOOT_H over its
## lowest, as a box in the model's space (the whole bottom of a box, the four legs
## of a bench, only the trunk of a bare tree). Once per model file.
static func _shade_foot(path: String, mesh: Mesh) -> AABB:
	if _shade_feet.has(path):
		return _shade_feet[path]
	var whole := mesh.get_aabb()
	var foot := whole
	var found := false
	for s in mesh.get_surface_count():
		for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if v.y > whole.position.y + SHADE_FOOT_H:
				continue
			foot = foot.expand(v) if found else AABB(v, Vector3.ZERO)
			found = true
	_shade_feet[path] = foot
	return foot


## A container's own model (PropModels.attach) gets the props' contact shade too:
## one quad under the model's box, a child of its "Prop" node (placed at its cell's
## centre) so it moves with it, cut at the sides of its cell where a wall, anything
## solid or another building stands, as _prop_shade cuts a prop's. Made again when
## the box moves (update_container), open to the sky or not as its new cell.
func _shade_container(holder: Node3D, box_data: Dictionary) -> void:
	var prop := holder.get_node_or_null("Prop") as Node3D
	if prop == null:
		return
	var old := prop.get_node_or_null("ContactShade")
	if old != null:
		old.free()
	var box := AABB()
	var found := false
	for child in prop.get_children():
		var mesh_node := child as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		var part: AABB = mesh_node.transform * mesh_node.mesh.get_aabb()
		box = box.merge(part) if found else part
		found = true
	if not found or box.position.y > SHADE_FLOOR_GAP:
		return
	var tall := clampf(box.end.y, 0.0, 2.0)
	var margin := minf(SHADE_MARGIN + SHADE_MARGIN_PER_M * tall, SHADE_MARGIN_MAX)
	var lo := box.position
	var hi := box.end
	var x0 := lo.x - margin
	var x1 := hi.x + margin
	var z0 := lo.z - margin
	var z1 := hi.z + margin
	var lv := int(box_data.get("level", 0))
	var cell: Vector2i = box_data["cell"]
	if levels.has(lv):
		# The cell's sides in the Prop node's space: half a metre round its centre.
		var lg: FieldGrid = levels[lv]
		var r := Rect2i(cell, Vector2i.ONE)
		var b := lg.building_at(cell)
		if _shade_stops(lg, r, Vector2i(-1, 0), b):
			x0 = maxf(x0, minf(lo.x, -0.5))
		if _shade_stops(lg, r, Vector2i(1, 0), b):
			x1 = minf(x1, maxf(hi.x, 0.5))
		if _shade_stops(lg, r, Vector2i(0, -1), b):
			z0 = maxf(z0, minf(lo.z, -0.5))
		if _shade_stops(lg, r, Vector2i(0, 1), b):
			z1 = minf(z1, maxf(hi.z, 0.5))
	var w := x1 - x0
	var d := z1 - z0
	var st := _begin()
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var c := Color(0.0, 0.0, lerpf(SHADE_STRENGTH, SHADE_STRENGTH_TALL, clampf(tall / 1.5, 0.0, 1.0)),
		sky_alpha(grid, cell) if lv == 0 else 0.0)
	var foot := Color((lo.x - x0) / w, (lo.z - z0) / d, (hi.x - x0) / w, (hi.z - z0) / d)
	var corners := [Vector3(x0, 0.006, z0), Vector3(x1, 0.006, z0), Vector3(x1, 0.006, z1), Vector3(x0, 0.006, z1)]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_color(c)
		st.set_custom(0, foot)
		st.set_uv(uvs[idx])
		st.set_normal(Vector3.UP)
		st.add_vertex(corners[idx])
	var shade := MeshInstance3D.new()
	shade.name = "ContactShade"
	shade.mesh = st.commit()
	shade.material_override = _contact_material("box")
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	prop.add_child(shade)


## Does a side of a prop's cells (`side`: the way out) meet a wall, anything solid
## or another building's cell?
static func _shade_stops(lg: FieldGrid, r: Rect2i, side: Vector2i, building: int) -> bool:
	var cells: Array[Vector2i] = []
	if side.x != 0:
		var x := r.position.x - 1 if side.x < 0 else r.end.x
		for y in range(r.position.y, r.end.y):
			cells.append(Vector2i(x, y))
	else:
		var y := r.position.y - 1 if side.y < 0 else r.end.y
		for x in range(r.position.x, r.end.x):
			cells.append(Vector2i(x, y))
	for c in cells:
		if not lg.inside(c):
			return true
		var s := lg.solid_at(c)
		if s != FieldGrid.Solid.NONE and s != FieldGrid.Solid.LOW:
			return true
		if lg.building_at(c) != building:
			return true
	return false


func _refresh_object_details() -> void:
	for row: Dictionary in object_gray:
		var prop: Dictionary = row["prop"]
		var lv := int(prop.get("level", 0))
		var b := int(prop.get("building", levels[lv].building_at((prop["rect"] as Rect2i).position)))
		row["node"].visible = _prop_is_seen(prop["rect"], lv) and (not buildings or buildings.interior_visible(b, lv))
	for idx: int in stove_glows:
		var stove: Dictionary = data["stoves"][idx]
		var lv := int(stove.get("level", 0))
		stove_glows[idx].visible = _prop_is_seen(Rect2i(stove["cell"], Vector2i.ONE), lv) \
			and (not buildings or buildings.interior_visible(int(stove["building"]), lv))


## 재질은 기존 소품 재질 그대로다. 아직 본 적 없는 층의 소품은 CPU에서 제외한다.
func _prop_is_seen(r: Rect2i, lv: int, cache: Dictionary = {}) -> bool:
	if not _props_mask_on:
		return true
	if bool(cache.get("remembered", false)):
		return true
	var n := grid.width * grid.height
	var visible_now: bool = false
	for y in range(maxi(0, r.position.y), mini(grid.height, r.end.y)):
		for x in range(maxi(0, r.position.x), mini(grid.width, r.end.x)):
			var key := (lv + 1) * n + grid.index(Vector2i(x, y))
			if key >= 0 and key < _prop_memory.size() and _prop_memory[key] > 0:
				if not cache.is_empty():
					cache["remembered"] = true
				return true
			if _prop_seen_now.has(key):
				visible_now = true
	return visible_now


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
		# A model coach lights its own panes where its glass is (the train kit).
		if kind == "car_window" and train_models != null and train_models.lights_window_at(l["cell"]):
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
## Row y of an upper floor's or the cellar's floor cells into their tiles' SurfaceTools.
static func level_floor_row(lg: FieldGrid, lv: int, y: int, floors: Dictionary) -> void:
	var y0 := lv * LEVEL_H
	for x in range(lg.width):
		var c := Vector2i(x, y)
		var kind := lg.solid_at(c)
		if kind == S.AIR or (kind == S.BLOCK and lg.building_at(c) < 0):
			continue
		var tile := c / TILE
		if not floors.has(tile):
			var begun := SurfaceTool.new()
			begun.begin(Mesh.PRIMITIVE_TRIANGLES)
			floors[tile] = begun
		var floor_st: SurfaceTool = floors[tile]
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


## Every floor but the ground's at once (the loader's worker): {lv: {tile: arrays}},
## with the maps they fit in `keys` ({lv: ground_key}).
static func level_floor_arrays(levels_of: Dictionary, keys: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for lv in levels_of:
		if int(lv) == 0:
			continue
		var lg: FieldGrid = levels_of[lv]
		out[lv] = level_floor_tiles(lg, int(lv))
		keys[lv] = floor_key(lg)
	return out


## An upper floor's or the cellar's tiles at once: what level_floor_row gives row by row
## through SurfaceTools (the same arrays, the tiles in the order the rows first reach
## them), written straight into the arrays over the plain cells. An edge stop's floors
## are mostly air beyond the old map: a call a cell was most of their time. Which cells
## lay a floor, and how, is said here and in level_floor_row (and floor_key): change them
## together (test_ground_arrays holds the two to the same arrays).
static func level_floor_tiles(lg: FieldGrid, lv: int) -> Dictionary:
	var w := lg.width
	var h := lg.height
	var so := lg.solid
	var bu := lg.building
	var fl := lg.floor
	var tiles_x := ceili(w / float(TILE))
	# The cells each tile lays, and the tiles in the order a row-by-row walk meets them.
	var counts := PackedInt32Array()
	counts.resize(tiles_x * ceili(h / float(TILE)))
	var order: Array[Vector2i] = []
	for y in h:
		var row := y * w
		var ty := y / TILE
		for x in w:
			var kind := so[row + x]
			if kind == S.AIR or (kind == S.BLOCK and bu[row + x] < 0):
				continue
			var t := ty * tiles_x + x / TILE
			if counts[t] == 0:
				order.append(Vector2i(x / TILE, ty))
			counts[t] += 1
	var y0 := lv * LEVEL_H
	var out: Dictionary = {}
	for tile in order:
		var n := counts[tile.y * tiles_x + tile.x] * 6
		var verts := PackedVector3Array()
		verts.resize(n)
		var normals := PackedVector3Array()
		normals.resize(n)
		normals.fill(Vector3.UP)
		var colors := PackedColorArray()
		colors.resize(n)
		var at := 0
		for y in range(tile.y * TILE, mini((tile.y + 1) * TILE, h)):
			for x in range(tile.x * TILE, mini((tile.x + 1) * TILE, w)):
				var i := y * w + x
				var kind := so[i]
				if kind == S.AIR or (kind == S.BLOCK and bu[i] < 0):
					continue
				var color := FLOOR_COLORS[fl[i]]
				var tint := (float((x * 73 + y * 37) % 11) / 11.0 - 0.5) * 0.035
				# Upper floors and the cellar are all under a roof (alpha 0).
				color = Color(color.r + tint, color.g + tint, color.b + tint, 0.0)
				var p0 := Vector3(x, y0, y)
				var p2 := Vector3(x + 1, y0, y + 1)
				verts[at] = p0
				verts[at + 1] = Vector3(x + 1, y0, y)
				verts[at + 2] = p2
				verts[at + 3] = p0
				verts[at + 4] = p2
				verts[at + 5] = Vector3(x, y0, y + 1)
				for j in 6:
					colors[at + j] = color
				at += 6
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		out[tile] = arrays
	return out


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
	# The floors, made ahead by the stop loader's worker when they still fit (2a,
	# as the ground), else here row by row the same way.
	var ahead: Dictionary = data.get("_floor_arrays", {}).get(lv, {})
	var ahead_fits: bool = not ahead.is_empty() and data.get("_floor_keys", {}).get(lv) == floor_key(lg)
	if ahead_fits:
		floor_from_loader[lv] = true
	for y in range(lg.height):
		await BuildPace.rest(pace)
		if not ahead_fits:
			level_floor_row(lg, lv, y, floors)
		# The windows hang on how the building draws (building_view.gd): here.
		for x in range(lg.width):
			var c := Vector2i(x, y)
			var kind := lg.solid_at(c)
			var b := lg.building_at(c)
			if kind == S.WINDOW and (buildings == null or not buildings.draws_cell(c, lv)):
				if not tools.has(b):
					tools[b] = _begin()
				var horizontal := lg.solid_at(c + Vector2i(1, 0)) == S.WALL or lg.solid_at(c + Vector2i(-1, 0)) == S.WALL
				var size := Vector3(1.0, 0.85, 0.25) if horizontal else Vector3(0.25, 0.85, 1.0)
				box(tools[b], size, Vector3(x + 0.5, 0.43, y + 0.5), Color(0.4, 0.4, 0.42))
				box(tools[b], Vector3(1.0, 0.9, 0.08) if horizontal else Vector3(0.08, 0.9, 1.0), Vector3(x + 0.5, 1.3, y + 0.5), Color(0.62, 0.72, 0.78))
				box(tools[b], size * Vector3(1, 0.12, 1), Vector3(x + 0.5, WALL_H - 0.05, y + 0.5), Color(0.4, 0.4, 0.42))
	var floor_arrays: Dictionary = ahead if ahead_fits else {}
	# Read once; not kept with the map.
	for key: String in ["_floor_arrays", "_floor_keys"]:
		if data.get(key) is Dictionary:
			(data[key] as Dictionary).erase(lv)
			if (data[key] as Dictionary).is_empty():
				data.erase(key)
	if not ahead_fits:
		for tile in floors:
			floor_arrays[tile] = (floors[tile] as SurfaceTool).commit_to_arrays()
	for tile in floor_arrays:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, floor_arrays[tile])
		var floor_node := _mesh_node(lv)
		floor_node.mesh = mesh
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
			# A rooftop's skylight ladder (house_layout.md 6.1) is named like stairs; the kit draws it.
			if s.has("roof"):
				_floor_label("옥상으로", s["cell"], int(s["low"]))
				_floor_label(LEVEL_WAYS.get(int(s["low"]), ""), s["cell"], int(s["high"]))
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
