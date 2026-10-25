extends Node3D
## 건물을 조립식 조각 키트로 그린다(명세 건물 v1 3·4·5장). map_view가 회색 상자 대신 붙인다.
## 지도 자료만 읽는다: 층마다 FieldGrid의 solid·building·doors·windows와 stairs·stoves·buildings.
## 그래서 술레후프와 짠 지도들이 한 그리기로 간다. 대응표나 조각 하나라도 못 읽으면
## can_draw()가 거짓이 되고 map_view가 회색 상자를 그린다.
##
## 건물 × 층마다 메시 넷: 바깥 턱 줄(남쪽을 보는 가로 줄, 3 m와 턱 두 메시를 바꿔 낌),
## 바깥 서는 줄(북쪽 가로 줄과 세로 줄, 1층 기단), 안 턱 줄(가로 안벽, 늘 턱), 안 서는 줄
## (세로 안벽과 계단). 지붕은 건물마다 하나. 문짝과 유리만 낱 노드다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const BuildingRules = preload("res://game/sim/building_rules.gd")
const BuildingShader = preload("res://game/world/building.gdshader")
const BuildPace = preload("res://game/world/build_pace.gd")
const S = FieldGrid.Solid
const CATALOG_PATH := "res://models/building_kit/catalog.json"
const MODE_SETTING := "visuals/building_models_enabled"
const LEVEL_H: float = 3.0
const CUT_H: float = 0.35
const EXT_T: float = 0.45          # 바깥벽 두께, 칸 가운데
const INT_HALF: float = 0.1        # 안벽 두께의 반
const FACE_IN: float = 0.275       # 칸 가장자리에서 바깥벽 바깥면까지
const ROOF_SPAN: float = 10.0      # roof_gable을 만든 경간(바깥면에서 바깥면)
const ROOF_RISE: float = 3.501     # 그 경간의 용마루 높이
const ROOF_TAN: float = 0.7002075  # tan 35°
const OVERHANG: float = 0.25       # 박공 끝 내밈
const FLAT_LIFT: float = 0.02      # 평지붕을 벽 윗면보다 띄워 겹친 면이 깜박이지 않게
const CHIMNEY_BACK: float = 0.8    # 굴뚝을 용마루에서 북쪽 경사로 물린 거리
const FADE_S: float = 0.15         # 들고 날 때 점박이(3.4, 가안)
const HOLE_R: float = 3.5          # 가림 구멍 반지름(3.3, 가안)
const PIECES: Array[String] = [
	"ext_wall", "ext_wall_cut", "ext_plinth", "ext_plinth_corner", "ext_plinth_corner_in",
	"ext_corner", "ext_corner_in", "ext_corner_cut", "ext_corner_in_cut", "wall_end_cap",
	"ext_window", "ext_window_cut", "window_glass", "window_glass_broken", "window_glass_floor",
	"ext_door", "door_leaf", "door_leaf_broken", "door_leaf_cut", "door_frame_cut",
	"int_wall", "int_wall_cut", "int_door", "roof_gable", "roof_gable_end", "roof_flat",
	"roof_parapet", "chimney", "stair_steep", "stair_well", "window_boards", "ladder",
]
const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)
const EAST := Vector2i(1, 0)
const WEST := Vector2i(-1, 0)
const DIRS: Array[Vector2i] = [NORTH, EAST, SOUTH, WEST]
const DIAGS: Array[Vector2i] = [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
## 벽면 칠(rgb)과 지붕 갈래(a: 0 슬레이트, 1 기와). 결정 408에서 시안 그림을 보고 정함.
const PAINTS: Array[Color] = [
	Color(0.60, 0.57, 0.51, 0.0), Color(0.56, 0.52, 0.44, 1.0),
	Color(0.50, 0.53, 0.51, 0.0), Color(0.58, 0.49, 0.43, 1.0),
]
## 생활 색(사용자 2026-10-24, 분위기 틀): 바깥 문짝·덧문·창틀에 남은 칠, a는 남은 정도
## (0 칠 없음). 바랜 색만 두고 셰이더가 한 번 더 누른다(흰 눈 위에서 튀지 않게).
const ACCENTS: Array[Color] = [
	Color(0.30, 0.42, 0.32, 0.85), Color(0.44, 0.27, 0.20, 0.8), Color(0.62, 0.50, 0.22, 0.75),
	Color(0.22, 0.40, 0.42, 0.85), Color(0.70, 0.66, 0.55, 0.7), Color(0.38, 0.27, 0.18, 0.9),
	Color(0.33, 0.40, 0.55, 0.75), Color(0.0, 0.0, 0.0, 0.0),
]
## 정점 색으로 쓰는 칠 구역(R 1자리, G 2자리, B 4자리, A 날씨 받음).
const ZONE_METAL_OUT := Color(1, 0, 1, 1)
const ZONE_METAL_IN := Color(1, 0, 1, 0)
const ZONE_WOOD_OUT := Color(0, 1, 0, 1)
const ZONE_WOOD_IN := Color(0, 1, 0, 0)
## 커튼 천: 안쪽 벽지 칠(구역 0, 날씨 안 받음)을 빌린다. 셰이더에 천 구역이 생기면 바꾼다.
const ZONE_CLOTH := Color(0, 0, 0, 0)
## 판자는 문·창의 면에서 이만큼 떨어져 붙는다(building_rules 면 0·1).
const FACE_OFF := 0.11
## 문 판자 높이(m)와 기울기(도): 한 면 넷까지(building_rules.PLANKS_PER_FACE).
const DOOR_PLANKS: Array = [[1.55, 4.0], [0.65, -5.0], [1.1, 3.0], [1.9, -3.0]]

static var _arrays: Dictionary = {}   # 조각 id -> [자리, 법선, 색, 순번]
static var _board_slots: Array = []   # 창 판자 자리 [{"height_m", "roll_deg"}](catalog.json board_slots)
static var _state: int = 0            # 0 아직, 1 씀, -1 못 씀

var material: ShaderMaterial
var world_material: ShaderMaterial
var levels: Dictionary = {}
var shells: Dictionary = {}       # Vector2i(건물, 층) -> {"cut", "stand", "int_cut", "int_stand"} 노드
var cut_meshes: Dictionary = {}   # Vector2i(건물, 층) -> [3 m 메시, 턱 메시]
var roofs: Dictionary = {}        # 건물 -> 노드
var door_nodes: Dictionary = {}   # Vector3i(x, y, 층) -> {"node", "plan", "cut"}
var window_nodes: Dictionary = {}
var outer_cells: Dictionary = {}  # 건물 -> 바깥벽 칸 번호들(지붕 시야)
var outer_doors: Dictionary = {}  # 건물 -> 1층 바깥 문 칸들(문가에서는 열림을 둔다)
var footprints: Dictionary = {}   # 건물 -> Rect2i(1층 사각형)
var drawn_cells: Dictionary = {}  # 층 -> 실제 키트가 맡은 벽·문·창 칸
var open_b: int = -1
var open_lv: int = 0
var player_lv: int = 0
var _want := Vector2i(-2, 0)
var _holding := false
var _instant := true
var _fades: Dictionary = {}       # 노드 -> [시작, 끝, 지난 몫]
var _seen: Dictionary = {}        # 건물 -> Vector2
var _focus_cell := Vector2i(-99, -99)
var _synced: Dictionary = {}


# ---------------------------------------------------------------- 대응표와 조각

static func models_enabled() -> bool:
	return bool(ProjectSettings.get_setting(MODE_SETTING, true))


## 설정이 켜져 있고 대응표와 조각을 다 읽었을 때만 참.
static func can_draw() -> bool:
	if not models_enabled():
		return false
	if _state == 0:
		_state = 1 if _load_pieces() else -1
	return _state == 1


## 대응표를 읽고 격자 약속이 이 그리기와 같은지 본다. 어긋나면 빈 사전.
static func load_catalog(path: String = CATALOG_PATH) -> Dictionary:
	var json := JSON.new()
	var problem := ""
	if not FileAccess.file_exists(path):
		problem = "파일 없음"
	elif json.parse(FileAccess.get_file_as_string(path)) != OK:
		problem = "문법 오류 %d줄" % json.get_error_line()
	elif not (json.data is Dictionary and json.data.get("assets") is Dictionary and json.data.get("grid") is Dictionary):
		problem = "assets·grid 없음"
	else:
		var grid: Dictionary = json.data["grid"]
		var roof: Dictionary = json.data.get("roof", {})
		if not is_equal_approx(float(grid.get("level_m", 0)), LEVEL_H) or not is_equal_approx(float(grid.get("cut_m", 0)), CUT_H):
			problem = "층·턱 높이"
		elif not is_equal_approx(float(grid.get("ext_wall_m", 0)), EXT_T) or not is_equal_approx(float(grid.get("int_wall_m", 0)), INT_HALF * 2.0):
			problem = "벽 두께"
		elif not is_equal_approx(float(roof.get("nominal_span_m", 0)), ROOF_SPAN) or absf(float(roof.get("rise_m", 0)) - ROOF_RISE) > 0.002:
			problem = "지붕 경간"
	if problem != "":
		push_warning("건물 조각 대응표를 쓰지 않고 건물을 상자로 그린다: %s (%s)" % [problem, path])
		return {}
	return json.data


static func _load_pieces() -> bool:
	var book := load_catalog()
	if book.is_empty():
		return false
	for id: String in PIECES:
		var asset: Dictionary = book["assets"].get(id, {})
		var path: String = asset.get("path", "")
		if asset.get("status") != "ready" or not ResourceLoader.exists(path):
			push_warning("건물 조각 %s 없음: 건물을 상자로 그린다" % id)
			return false
		var scene := load(path) as PackedScene
		var root: Node = scene.instantiate() if scene else null
		var found := _first_mesh(root, Transform3D.IDENTITY) if root else []
		if root:
			root.free()
		if found.is_empty():
			push_warning("건물 조각 %s에 메시 없음: 건물을 상자로 그린다" % id)
			return false
		_arrays[id] = found
	_board_slots = (book.get("board_slots", {}) as Dictionary).get("window", []).duplicate(true)
	return true


static func _first_mesh(node: Node, xf: Transform3D) -> Array:
	var here: Transform3D = xf * (node as Node3D).transform if node is Node3D else xf
	if node is MeshInstance3D and node.mesh and node.mesh.get_surface_count() > 0:
		var a: Array = node.mesh.surface_get_arrays(0)
		var pos := PackedVector3Array()
		var nrm := PackedVector3Array()
		var nb: Basis = here.basis.inverse().transposed()
		var src_p: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var src_n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		for k in range(src_p.size()):
			pos.append(here * src_p[k])
			nrm.append((nb * src_n[k]).normalized())
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(pos.size()))
		var col: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		if col.size() != pos.size():
			return []
		return [pos, nrm, col, idx]
	for child in node.get_children():
		var found := _first_mesh(child, here)
		if not found.is_empty():
			return found
	return []


## 조각 여럿을 한 메시로 굽는다. 늘인 조각의 법선은 역전치로 돌린다.
class Bake:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()

	func add(a: Array, xf: Transform3D) -> void:
		var base := pos.size()
		var nb := xf.basis.inverse().transposed()
		var p: PackedVector3Array = a[0]
		var n: PackedVector3Array = a[1]
		for k in range(p.size()):
			pos.append(xf * p[k])
			nrm.append((nb * n[k]).normalized())
		col.append_array(a[2])
		for i: int in a[3]:
			idx.append(base + i)

	## 칠 구역 색 하나의 상자(쇠 빗장, 계단 구멍 같은 작은 것).
	func box(xf: Transform3D, half: Vector3, colour: Color) -> void:
		var faces := [
			[Vector3.UP, [Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
			[Vector3.BACK, [Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, -1, 1)]],
			[Vector3.FORWARD, [Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, -1)]],
			[Vector3.RIGHT, [Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(1, -1, -1)]],
			[Vector3.LEFT, [Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, 1, 1), Vector3(-1, -1, 1)]],
		]
		for face in faces:
			var base := pos.size()
			var normal: Vector3 = (xf.basis * face[0]).normalized()
			for v: Vector3 in face[1]:
				pos.append(xf * (v * half))
				nrm.append(normal)
				col.append(colour)
			for i in [0, 1, 2, 0, 2, 3]:
				idx.append(base + i)

	func mesh() -> ArrayMesh:
		if pos.is_empty():
			return null
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = pos
		arrays[Mesh.ARRAY_NORMAL] = nrm
		arrays[Mesh.ARRAY_COLOR] = col
		arrays[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m


# ---------------------------------------------------------------- 놓는 규칙 (4.5)

static func yaw_of(n: Vector2i) -> float:
	return atan2(float(n.x), float(n.y))


## 모서리 조각은 바깥 대각 (-1, +1)을 보고 만들었다.
static func corner_yaw(d: Vector2i) -> float:
	return atan2(float(d.x), float(d.y)) + PI * 0.25


static func _xf(at: Vector3, yaw: float, scale: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scale), at)


static func _wallish(lg: FieldGrid, c: Vector2i, b: int) -> bool:
	if lg.building_at(c) != b:
		return false
	var k := lg.solid_at(c)
	return k == S.WALL or k == S.DOOR or k == S.WINDOW


## 벽 칸 하나의 갈래: "ext"(곧은 바깥벽, n = 바깥을 보는 쪽), "corner"(바깥 모서리),
## "inner"(안으로 꺾인 모서리, d = 바깥 대각), "int"(안벽).
static func cell_kind(lg: FieldGrid, c: Vector2i, b: int) -> Dictionary:
	var outs: Array[Vector2i] = []
	for d in DIRS:
		if lg.building_at(c + d) != b:
			outs.append(d)
	if outs.size() == 1:
		return {"kind": "ext", "n": outs[0]}
	if outs.size() == 2 and outs[0] + outs[1] != Vector2i.ZERO:
		return {"kind": "corner", "d": outs[0] + outs[1]}
	if outs.size() >= 2:
		# 한 칸 두께로 밖과 밖 사이에 선 벽이나 끝: 남쪽(없으면 첫) 쪽을 바깥으로 본다.
		return {"kind": "ext", "n": SOUTH if outs.has(SOUTH) else outs[0]}
	for d in DIAGS:
		if lg.building_at(c + d) != b and _wallish(lg, c + Vector2i(d.x, 0), b) and _wallish(lg, c + Vector2i(0, d.y), b):
			return {"kind": "inner", "d": d}
	return {"kind": "int"}


## 가로 줄이 북쪽 바깥 줄이 아니면 턱 줄이다(남쪽 바깥 줄, 남쪽을 보는 꺾인 줄, 안의 가로 줄).
static func cut_line(kind: Dictionary) -> bool:
	match kind["kind"]:
		"ext":
			return kind["n"].y > 0
		"corner", "inner":
			return kind["d"].y > 0
	return false


## 지도 하나의 놓을 자리. 그리지 않으니 시험이 바로 읽는다.
## pieces: {"id", "xf"(층 바닥 기준), "b", "lv", "slot"} 또는 {"box", "half", "colour", ...}
##   slot: cut_full·cut_low(바깥 턱 줄의 3 m·턱), stand, int_cut(열렸을 때만: 안 턱 줄과 마구리), int_stand
## roofs: {"id", "xf"(세계 기준), "b"}, doors·windows: {"cell", "lv", "b", "line", "yaw"}
static func plan(data: Dictionary) -> Dictionary:
	var out := {"pieces": [], "roofs": [], "doors": [], "windows": [], "outer": {}, "outer_doors": {}, "footprints": {}, "kinds": {}}
	var levels: Dictionary = data.get("levels", {0: data["grid"]})
	var areas := _areas(data, levels)
	var lvs: Array = levels.keys()
	lvs.sort()
	for b: int in areas:
		if not has_interior(data, levels, b):
			continue
		var area: Rect2i = areas[b]
		out["outer"][b] = {}
		for lv: int in lvs:
			_plan_level(out, levels[lv], lv, b, area, wall_rects(data, b, lv, area))
		_plan_roofs(out, data, levels, lvs, b, area)
	_plan_stairs(out, data, levels)
	return out


## 건물마다 살필 범위. 실제 칸은 wall_rects의 선언된 사각형 안에서만 고른다.
static func _areas(data: Dictionary, levels: Dictionary) -> Dictionary:
	var areas: Dictionary = {}
	for row: Dictionary in data.get("buildings", []):
		var b := int(row.get("id", -1))
		var r: Variant = row.get("rect")
		if b >= 0 and r is Rect2i:
			areas[b] = (areas[b] as Rect2i).merge(r) if areas.has(b) else r
	for row: Dictionary in data.get("upper_rects", []):
		var b := int(row.get("building", -1))
		if b >= 0 and row.get("rect") is Rect2i:
			areas[b] = (areas[b] as Rect2i).merge(row["rect"]) if areas.has(b) else row["rect"]
	if areas.is_empty():
		for lv in levels:
			var lg: FieldGrid = levels[lv]
			for i in range(lg.building.size()):
				var b: int = lg.building[i]
				if b >= 0:
					var c := Vector2i(i % lg.width, i / lg.width)
					var one := Rect2i(c, Vector2i.ONE)
					areas[b] = (areas[b] as Rect2i).merge(one) if areas.has(b) else one
	return areas


## 건물 번호만 붙은 산 덩어리는 문·창·방이 있는 건물로 취급하지 않는다.
static func has_interior(data: Dictionary, grids: Dictionary, b: int) -> bool:
	for row: Dictionary in data.get("buildings", []):
		if int(row.get("id", -1)) == b and not row.get("rooms", []).is_empty():
			return true
	for room: Dictionary in data.get("rooms", []):
		if int(room.get("building", -1)) == b:
			return true
	for lg: FieldGrid in grids.values():
		for openings: Dictionary in [lg.doors, lg.windows]:
			for row: Dictionary in openings.values():
				if int(row.get("building", -1)) == b:
					return true
	return false


## 위층 사각형이 따로 있으면 그것을 사용한다. 여러 사각형 사이의 빈틈도 제외한다.
static func wall_rects(data: Dictionary, b: int, lv: int, fallback: Rect2i) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	if lv > 0:
		for row: Dictionary in data.get("upper_rects", []):
			if int(row.get("building", -1)) == b and int(row.get("level", lv)) == lv:
				rects.append(row["rect"])
	if rects.is_empty():
		for row: Dictionary in data.get("buildings", []):
			if int(row.get("id", -1)) == b and row.get("rect") is Rect2i:
				rects.append(row["rect"])
	# 예전의 작은 시험 지도처럼 건물 표 자체가 없을 때만 격자 범위를 쓴다.
	if rects.is_empty() and data.get("buildings", []).is_empty():
		rects.append(fallback)
	return rects


static func inside_rects(c: Vector2i, rects: Array[Rect2i]) -> bool:
	for r in rects:
		if r.has_point(c):
			return true
	return false


static func _add(out: Dictionary, id: String, xf: Transform3D, b: int, lv: int, slot: String) -> void:
	out["pieces"].append({"id": id, "xf": xf, "b": b, "lv": lv, "slot": slot})


static func _plan_level(out: Dictionary, lg: FieldGrid, lv: int, b: int, area: Rect2i, rects: Array[Rect2i]) -> void:
	var kinds: Dictionary = {}
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var c := Vector2i(x, y)
			if inside_rects(c, rects) and _wallish(lg, c, b):
				kinds[c] = cell_kind(lg, c, b)
	if kinds.is_empty():
		return
	out["kinds"][Vector2i(b, lv)] = kinds
	var walls: Dictionary = {}    # Vector3i(n.x, n.y, 줄) -> 줄 따라 칸들(곧은 바깥벽)
	var plinths: Dictionary = {}
	var h_runs: Dictionary = {}   # 줄 y -> [[x0, x1]]
	var v_runs: Dictionary = {}
	var ground := lv == 0
	for c: Vector2i in kinds:
		var kind: Dictionary = kinds[c]
		var solid := lg.solid_at(c)
		var at := Vector3(c.x + 0.5, 0.0, c.y + 0.5)
		if kind["kind"] != "int":
			out["outer"][b][lg.index(c)] = true
		match kind["kind"]:
			"ext":
				var n: Vector2i = kind["n"]
				var key := Vector3i(n.x, n.y, c.y if n.y != 0 else c.x)
				var along := c.x if n.y != 0 else c.y
				if solid == S.WALL:
					if not walls.has(key):
						walls[key] = []
					walls[key].append(along)
				if ground and solid != S.DOOR:
					if not plinths.has(key):
						plinths[key] = []
					plinths[key].append(along)
				var xf := _xf(at, yaw_of(n))
				var cut := cut_line(kind)
				if solid == S.DOOR:
					out["doors"].append({"cell": c, "lv": lv, "b": b, "line": "cut" if cut else "stand", "yaw": yaw_of(n), "outer": true})
					if ground:
						if not out["outer_doors"].has(b):
							out["outer_doors"][b] = []
						out["outer_doors"][b].append(c)
				elif solid == S.WINDOW:
					out["windows"].append({"cell": c, "lv": lv, "b": b, "line": "cut" if cut else "stand", "yaw": yaw_of(n)})
				if solid != S.WALL:
					var full := "ext_door" if solid == S.DOOR else "ext_window"
					var low := "door_frame_cut" if solid == S.DOOR else "ext_window_cut"
					if cut:
						_add(out, full, xf, b, lv, "cut_full")
						_add(out, low, xf, b, lv, "cut_low")
					else:
						_add(out, full, xf, b, lv, "stand")
				# 선 세로 줄이 턱 모서리와 만나는 끝은 열렸을 때 마구리로 막는다. 마구리는 3 m라
				# 턱 줄 노드에 넣으면 그 노드가 낮아지지 않는다: 열렸을 때만 보이는 안 턱 줄에 둔다.
				if n.x != 0:
					for s: Vector2i in [NORTH, SOUTH]:
						var next: Dictionary = kinds.get(c + s, {})
						if not next.is_empty() and next["kind"] in ["corner", "inner"] and cut_line(next):
							var edge := at + Vector3(0, 0, s.y * 0.5)
							_add(out, "wall_end_cap", _xf(edge, atan2(float(s.y), float(-s.x))), b, lv, "int_cut")
			"corner", "inner":
				var d: Vector2i = kind["d"]
				var xf := _xf(at, corner_yaw(d))
				var inner: bool = kind["kind"] == "inner"
				var full := "ext_corner_in" if inner else "ext_corner"
				if cut_line(kind):
					_add(out, full, xf, b, lv, "cut_full")
					_add(out, full + "_cut", xf, b, lv, "cut_low")
				else:
					_add(out, full, xf, b, lv, "stand")
				if ground:
					_add(out, "ext_plinth_corner_in" if inner else "ext_plinth_corner", xf, b, lv, "stand")
			"int":
				_plan_inner(out, lg, kinds, c, b, lv, h_runs, v_runs)
	for key: Vector3i in walls:
		for run: Vector2i in _runs(walls[key]):
			var n := Vector2i(key.x, key.y)
			var xf := _run_xf(n, key.z, run)
			if n.y > 0:
				_add(out, "ext_wall", xf, b, lv, "cut_full")
				_add(out, "ext_wall_cut", xf, b, lv, "cut_low")
			else:
				_add(out, "ext_wall", xf, b, lv, "stand")
	for key: Vector3i in plinths:
		for run: Vector2i in _runs(plinths[key]):
			_add(out, "ext_plinth", _run_xf(Vector2i(key.x, key.y), key.z, run), b, lv, "stand")
	for y: int in h_runs:
		for span: Vector2 in _merge(h_runs[y]):
			_add(out, "int_wall_cut", _xf(Vector3((span.x + span.y) * 0.5, 0, y + 0.5), 0.0, Vector3(span.y - span.x, 1, 1)), b, lv, "int_cut")
	for x: int in v_runs:
		for span: Vector2 in _merge(v_runs[x]):
			_add(out, "int_wall", _xf(Vector3(x + 0.5, 0, (span.x + span.y) * 0.5), PI * 0.5, Vector3(span.y - span.x, 1, 1)), b, lv, "int_stand")


## 안벽 칸: 가로로 이어지면 가로 토막(턱 줄), 세로로 이어지면 세로 토막(서는 줄).
## 토막은 칸 가운데를 지나고, 바깥벽에 닿으면 그 칸 가운데까지, 홀로 끝나면 칸 끝까지 간다.
static func _plan_inner(out: Dictionary, lg: FieldGrid, kinds: Dictionary, c: Vector2i, b: int, lv: int, h_runs: Dictionary, v_runs: Dictionary) -> void:
	var w := kinds.has(c + WEST)
	var e := kinds.has(c + EAST)
	var nn := kinds.has(c + NORTH)
	var ss := kinds.has(c + SOUTH)
	var solid := lg.solid_at(c)
	if solid == S.DOOR:
		var across := w or e
		var at := Vector3(c.x + 0.5, 0, c.y + 0.5)
		if across:
			_add(out, "door_frame_cut", _xf(at, 0.0), b, lv, "int_cut")
		else:
			_add(out, "int_door", _xf(at, PI * 0.5), b, lv, "int_stand")
		out["doors"].append({"cell": c, "lv": lv, "b": b, "line": "int_cut" if across else "int_stand", "yaw": 0.0 if across else PI * 0.5, "outer": false})
		return
	if w or e:
		var lo := -0.5 if w else (-INT_HALF if nn or ss else -0.5)
		var hi := 0.5 if e else (INT_HALF if nn or ss else 0.5)
		if w and _solid_outer(lg, kinds, c + WEST):
			lo = -1.0
		if e and _solid_outer(lg, kinds, c + EAST):
			hi = 1.0
		_push(h_runs, c.y, Vector2(c.x + 0.5 + lo, c.x + 0.5 + hi))
	if nn or ss or not (w or e):
		var lo := -0.5 if nn else (-INT_HALF if w or e else -0.5)
		var hi := 0.5 if ss else (INT_HALF if w or e else 0.5)
		if nn and _solid_outer(lg, kinds, c + NORTH):
			lo = -1.0
		if ss and _solid_outer(lg, kinds, c + SOUTH):
			hi = 1.0
		_push(v_runs, c.x, Vector2(c.y + 0.5 + lo, c.y + 0.5 + hi))


static func _solid_outer(lg: FieldGrid, kinds: Dictionary, c: Vector2i) -> bool:
	return kinds.has(c) and kinds[c]["kind"] != "int" and lg.solid_at(c) == S.WALL


static func _push(runs: Dictionary, key: int, span: Vector2) -> void:
	if not runs.has(key):
		runs[key] = []
	runs[key].append(span)


## 줄 따라 칸 번호들을 이어진 토막(처음, 끝)으로.
static func _runs(cells: Array) -> Array[Vector2i]:
	var sorted := cells.duplicate()
	sorted.sort()
	var out: Array[Vector2i] = []
	for a: int in sorted:
		if not out.is_empty() and out[-1].y == a - 1:
			out[-1].y = a
		else:
			out.append(Vector2i(a, a))
	return out


static func _merge(spans: Array) -> Array[Vector2]:
	var sorted := spans.duplicate()
	sorted.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var out: Array[Vector2] = []
	for s: Vector2 in sorted:
		if not out.is_empty() and s.x <= out[-1].y + 0.001:
			out[-1].y = maxf(out[-1].y, s.y)
		else:
			out.append(s)
	return out


## 곧은 바깥벽 토막: 줄 가운데에 놓고 X로 칸 수만큼 늘인다.
static func _run_xf(n: Vector2i, line: int, run: Vector2i) -> Transform3D:
	var mid := (run.x + run.y + 1) * 0.5
	var length := float(run.y - run.x + 1)
	var at := Vector3(mid, 0, line + 0.5) if n.y != 0 else Vector3(line + 0.5, 0, mid)
	return _xf(at, yaw_of(n), Vector3(length, 1, 1))


## 지붕: 층마다 그 층에는 있고 위층에는 없는 칸을 사각형으로 덮는다. 더 높은 쪽에
## 붙은 사각형은 평지붕(역사·화물 창고의 낮은 쪽), 홀로 선 사각형은 박공지붕이다.
static func _plan_roofs(out: Dictionary, data: Dictionary, levels: Dictionary, lvs: Array, b: int, area: Rect2i) -> void:
	var prints: Dictionary = {}
	for lv: int in lvs:
		if lv >= 0:
			prints[lv] = _footprint(levels[lv], b, area, wall_rects(data, b, lv, area))
	if prints.has(0) and not prints[0].is_empty():
		out["footprints"][b] = _bounds(prints[0])
	var gables: Array = []
	# 오르는 옥상으로 고른 건물(roof_rules.gd)은 맨 위도 낮은 담을 두른 평지붕이다.
	var flat_top := false
	for row: Variant in data.get("rooftops", []):
		flat_top = flat_top or (row is Dictionary and int(row.get("building", -1)) == b)
	for lv: int in prints:
		var here: Dictionary = prints[lv]
		var above: Dictionary = prints.get(lv + 1, {})
		var region: Dictionary = {}
		for c in here:
			if not above.has(c):
				region[c] = true
		var top := (lv + 1) * LEVEL_H
		for r: Rect2i in _rects_of(region):
			if _touches(r, above) or (flat_top and above.is_empty()):
				_plan_flat(out, r, top, above, b)
			else:
				gables.append(_plan_gable(out, r, top, b))
	if gables.is_empty() or not _chimney_wanted(data, b):
		return
	# 굴뚝은 가장 높은 박공에 하나: 난로가 그 지붕 밑에 있으면 그 위, 없으면 가운데에서 조금 비켜.
	gables.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["top"] > q["top"])
	var g: Dictionary = gables[0]
	var r: Rect2i = g["rect"]
	var spot := Vector2(r.position.x + r.size.x * 0.5 + 1.5, r.position.y + r.size.y * 0.5)
	for stove: Dictionary in data.get("stoves", []):
		var sc: Vector2i = stove.get("cell", Vector2i(-1, -1))
		if int(stove.get("building", -1)) == b and r.has_point(sc):
			spot = Vector2(sc.x + 0.5, sc.y + 0.5)
	var along_x: bool = g["along_x"]
	var ridge: Vector2 = g["ridge"]
	var at := Vector2(spot.x, ridge.y - CHIMNEY_BACK) if along_x else Vector2(ridge.x + CHIMNEY_BACK, spot.y)
	at = Vector2(clampf(at.x, r.position.x + 1.0, r.end.x - 1.0), clampf(at.y, r.position.y + 1.0, r.end.y - 1.0))
	var base: float = g["top"] + g["k"] * ROOF_RISE - CHIMNEY_BACK * ROOF_TAN - 0.15
	out["roofs"].append({"id": "chimney", "xf": _xf(Vector3(at.x, base, at.y), 0.0), "b": b})


static func _chimney_wanted(data: Dictionary, b: int) -> bool:
	for stove: Dictionary in data.get("stoves", []):
		if int(stove.get("building", -1)) == b:
			return true
	for row: Dictionary in data.get("buildings", []):
		if int(row.get("id", -1)) == b and String(row.get("name", "")).contains("주택"):
			return true
	return false


static func _footprint(lg: FieldGrid, b: int, area: Rect2i, rects: Array[Rect2i]) -> Dictionary:
	var cells: Dictionary = {}
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var c := Vector2i(x, y)
			if inside_rects(c, rects) and lg.building_at(c) == b:
				cells[c] = true
	return cells


static func _bounds(cells: Dictionary) -> Rect2i:
	var r := Rect2i()
	var first := true
	for c: Vector2i in cells:
		r = Rect2i(c, Vector2i.ONE) if first else r.merge(Rect2i(c, Vector2i.ONE))
		first = false
	return r


## 칸 모음을 큰 사각형부터 덮는다(줄 따라 늘이고 아래로 늘인다).
static func _rects_of(region: Dictionary) -> Array[Rect2i]:
	var left := region.duplicate()
	var cells: Array = left.keys()
	cells.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return p.y < q.y or (p.y == q.y and p.x < q.x))
	var out: Array[Rect2i] = []
	for c: Vector2i in cells:
		if not left.has(c):
			continue
		var w := 1
		while left.has(c + Vector2i(w, 0)):
			w += 1
		var h := 1
		while true:
			var full := true
			for x in range(w):
				if not left.has(c + Vector2i(x, h)):
					full = false
					break
			if not full:
				break
			h += 1
		for y in range(h):
			for x in range(w):
				left.erase(c + Vector2i(x, y))
		out.append(Rect2i(c, Vector2i(w, h)))
	return out


static func _touches(r: Rect2i, cells: Dictionary) -> bool:
	for c: Vector2i in cells:
		if r.grow(1).has_point(c) and not r.has_point(c):
			var dx := c.x < r.position.x or c.x >= r.end.x
			var dy := c.y < r.position.y or c.y >= r.end.y
			if not (dx and dy):
				return true
	return false


static func _plan_gable(out: Dictionary, r: Rect2i, top: float, b: int) -> Dictionary:
	var along_x := r.size.x >= int(r.size.y * 0.75)
	var span := float(r.size.y if along_x else r.size.x) - 2.0 * FACE_IN
	var length := float(r.size.x if along_x else r.size.y) - 2.0 * FACE_IN + 2.0 * OVERHANG
	var k := span / ROOF_SPAN
	var mid := Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5)
	out["roofs"].append({"id": "roof_gable", "xf": _xf(Vector3(mid.x, top, mid.y), 0.0 if along_x else PI * 0.5, Vector3(length, k, k)), "b": b})
	for side in [-1, 1]:
		var at: Vector3
		var n: Vector2i
		if along_x:
			at = Vector3(r.position.x + 0.5 if side < 0 else r.end.x - 0.5, top, mid.y)
			n = Vector2i(side, 0)
		else:
			at = Vector3(mid.x, top, r.position.y + 0.5 if side < 0 else r.end.y - 0.5)
			n = Vector2i(0, side)
		out["roofs"].append({"id": "roof_gable_end", "xf": _xf(at, yaw_of(n), Vector3(k, k, 1)), "b": b})
	return {"rect": r, "top": top, "k": k, "along_x": along_x, "ridge": mid}


## 평지붕: 바깥면까지 덮고, 높은 쪽에 붙은 변은 그 벽 바깥면까지 늘인다. 낮은 벽은 붙지 않은 변에만.
static func _plan_flat(out: Dictionary, r: Rect2i, top: float, above: Dictionary, b: int) -> void:
	var sides := {}   # 쪽 -> 높은 쪽에 붙었나
	for d in DIRS:
		var touch := false
		var edge: Rect2i
		match d:
			NORTH:
				edge = Rect2i(r.position.x, r.position.y - 1, r.size.x, 1)
			SOUTH:
				edge = Rect2i(r.position.x, r.end.y, r.size.x, 1)
			WEST:
				edge = Rect2i(r.position.x - 1, r.position.y, 1, r.size.y)
			EAST:
				edge = Rect2i(r.end.x, r.position.y, 1, r.size.y)
		for c: Vector2i in above:
			if edge.has_point(c):
				touch = true
				break
		sides[d] = touch
	var x0 := r.position.x + (-FACE_IN if sides[WEST] else FACE_IN)
	var x1 := r.end.x - (-FACE_IN if sides[EAST] else FACE_IN)
	var z0 := r.position.y + (-FACE_IN if sides[NORTH] else FACE_IN)
	var z1 := r.end.y - (-FACE_IN if sides[SOUTH] else FACE_IN)
	var y := top + FLAT_LIFT
	out["roofs"].append({"id": "roof_flat", "xf": _xf(Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5), 0.0, Vector3(x1 - x0, 1, z1 - z0)), "b": b})
	# 가로 낮은 벽은 모서리까지, 세로 낮은 벽은 그 사이만(겹친 윗면이 깜박이지 않게).
	for d: Vector2i in [NORTH, SOUTH]:
		if not sides[d]:
			var z := r.position.y + 0.5 if d == NORTH else r.end.y - 0.5
			out["roofs"].append({"id": "roof_parapet", "xf": _xf(Vector3((x0 + x1) * 0.5, y, z), yaw_of(d), Vector3(x1 - x0, 1, 1)), "b": b})
	for d: Vector2i in [WEST, EAST]:
		if not sides[d]:
			var a0 := z0 + (EXT_T if not sides[NORTH] else 0.0)
			var a1 := z1 - (EXT_T if not sides[SOUTH] else 0.0)
			var x := r.position.x + 0.5 if d == WEST else r.end.x - 0.5
			out["roofs"].append({"id": "roof_parapet", "xf": _xf(Vector3(x, y, (a0 + a1) * 0.5), yaw_of(d), Vector3(a1 - a0, 1, 1)), "b": b})


## 계단: 아래층 칸에 가파른 계단, 위층 같은 칸에 난간과 어두운 구멍. 오르는 쪽은
## 아래층 발치와 위층 나가는 칸이 둘 다 비어 있는 쪽. 사다리는 map_view의 자리 그림이 그린다.
static func _plan_stairs(out: Dictionary, data: Dictionary, levels: Dictionary) -> void:
	for s: Dictionary in data.get("stairs", []):
		if s.get("ladder", false):
			if s.has("roof"):
				_plan_roof_ladder(out, s, levels)
			continue
		var c: Vector2i = s["cell"]
		var low: int = s["low"]
		var high: int = s["high"]
		if not levels.has(low) or not levels.has(high):
			continue
		var lg: FieldGrid = levels[low]
		var hg: FieldGrid = levels[high]
		var b := lg.building_at(c)
		var way := Vector2i.ZERO
		for d in [SOUTH, NORTH, EAST, WEST]:
			if lg.solid_at(c - d) == S.NONE and hg.solid_at(c + d) == S.NONE:
				way = d
				break
		if way == Vector2i.ZERO:
			# 구석 계단: 발치만 비어 있으면 그쪽에서 오른다.
			way = SOUTH
			for d in [NORTH, SOUTH, EAST, WEST]:
				if lg.solid_at(c - d) == S.NONE:
					way = d
					break
		var xf := _xf(Vector3(c.x + 0.5, 0, c.y + 0.5), yaw_of(way))
		_add(out, "stair_steep", xf, b, low, "int_stand")
		_add(out, "stair_well", xf, hg.building_at(c), high, "int_stand")
		out["pieces"].append({"box": Vector3(0.47, 0.01, 0.47), "colour": ZONE_METAL_IN, "xf": _xf(Vector3(c.x + 0.5, 0.012, c.y + 0.5), 0.0), "b": hg.building_at(c), "lv": high, "slot": "int_stand"})


## 옥상 천창의 접이 사다리(house_layout.md 6.1): 맨 위층 방 안에서 벽에 기대 지붕 위로 0.9 m
## 나온다. 안을 열면 방 안에, 밖에서는 지붕 조각과 함께 그려 지붕 위로 나온 끝이 오를 자리를 알린다.
static func _plan_roof_ladder(out: Dictionary, s: Dictionary, levels: Dictionary) -> void:
	var c: Vector2i = s["cell"]
	var low: int = s["low"]
	if not levels.has(low):
		return
	var lg: FieldGrid = levels[low]
	var wall := Vector2i.ZERO
	for d in DIRS:
		if lg.solid_at(c + d) == S.WALL:
			wall = d
	var b := int(s["roof"])
	# 사다리 조각은 -Z 쪽에 붙어 있다: -Z가 벽을 보게 돌린다.
	var yaw := yaw_of(-wall) if wall != Vector2i.ZERO else 0.0
	_add(out, "ladder", _xf(Vector3(c.x + 0.5, 0, c.y + 0.5), yaw), b, low, "int_stand")
	out["roofs"].append({"id": "ladder", "xf": _xf(Vector3(c.x + 0.5, low * LEVEL_H, c.y + 0.5), yaw), "b": b})


# ---------------------------------------------------------------- 노드

## `pace` (build_pace.gd, staged stops): wait a frame between pieces; null: all at once.
func setup(map_data: Dictionary, world_mat: ShaderMaterial, pace = null) -> void:
	levels = map_data.get("levels", {0: map_data["grid"]})
	world_material = world_mat
	material = ShaderMaterial.new()
	material.shader = BuildingShader
	for key in ["vis", "map_size", "lamp_color"]:
		material.set_shader_parameter(key, world_mat.get_shader_parameter(key))
	material.set_shader_parameter("hole_radius", HOLE_R)
	# Planned off the main thread with the map, when it was (stop_loader.gd).
	var p: Dictionary = map_data["_building_plan"] if map_data.get("_building_plan") is Dictionary else plan(map_data)
	await BuildPace.rest(pace)
	for key: Vector2i in p["kinds"]:
		if not drawn_cells.has(key.y):
			drawn_cells[key.y] = {}
		for c: Vector2i in p["kinds"][key]:
			drawn_cells[key.y][c] = true
	for b: int in p["outer"]:
		outer_cells[b] = PackedInt32Array(p["outer"][b].keys())
	outer_doors = p["outer_doors"]
	footprints = p["footprints"]
	var bakes: Dictionary = {}
	for row: Dictionary in p["pieces"]:
		var key := "%d|%d|%s" % [row["b"], row["lv"], row["slot"]]
		if not bakes.has(key):
			bakes[key] = Bake.new()
		if row.has("box"):
			bakes[key].box(row["xf"], row["box"], row["colour"])
		else:
			bakes[key].add(_arrays[row["id"]], row["xf"])
		await BuildPace.rest(pace)
	var pairs: Dictionary = {}
	for key: String in bakes:
		await BuildPace.rest(pace)
		var bits := key.split("|")
		var shell := Vector2i(int(bits[0]), int(bits[1]))
		var slot := bits[2]
		if not shells.has(shell):
			shells[shell] = {}
		var m: ArrayMesh = bakes[key].mesh()
		if slot == "cut_full" or slot == "cut_low":
			if not pairs.has(shell):
				pairs[shell] = [null, null]
			pairs[shell][0 if slot == "cut_full" else 1] = m
			continue
		shells[shell][slot] = _node(shell.x, shell.y, m, slot == "stand")
	for shell: Vector2i in pairs:
		cut_meshes[shell] = pairs[shell]
		shells[shell]["cut"] = _node(shell.x, shell.y, pairs[shell][0], true)
	# 맨 위 층의 바깥벽이 처마 밑: 고드름이 거기에만 달린다(building.gdshader eave).
	var top_lv: Dictionary = {}
	for shell: Vector2i in shells:
		top_lv[shell.x] = maxi(int(top_lv.get(shell.x, shell.y)), shell.y)
	for shell: Vector2i in shells:
		if shell.y == int(top_lv[shell.x]):
			for slot in shells[shell]:
				(shells[shell][slot] as MeshInstance3D).set_instance_shader_parameter("eave", 1.0)
	var roof_bakes: Dictionary = {}
	for row: Dictionary in p["roofs"]:
		if not roof_bakes.has(row["b"]):
			roof_bakes[row["b"]] = Bake.new()
		roof_bakes[row["b"]].add(_arrays[row["id"]], row["xf"])
		await BuildPace.rest(pace)
	for b: int in roof_bakes:
		await BuildPace.rest(pace)
		var node := _node(b, 0, roof_bakes[b].mesh(), true)
		node.position.y = 0.0
		node.set_instance_shader_parameter("seen_fixed", Vector2.ZERO)
		roofs[b] = node
	for row: Dictionary in p["doors"]:
		var node := _node(row["b"], row["lv"], null, false)
		var key := Vector3i(row["cell"].x, row["cell"].y, row["lv"])
		door_nodes[key] = {"node": node, "plan": row, "cut": false}
		_draw_door(key)
		await BuildPace.rest(pace)
	for row: Dictionary in p["windows"]:
		var node := _node(row["b"], row["lv"], null, false)
		var key := Vector3i(row["cell"].x, row["cell"].y, row["lv"])
		window_nodes[key] = {"node": node, "plan": row, "cut": false}
		_draw_window(key)
		await BuildPace.rest(pace)
	_apply()
	_instant = false


func _node(b: int, lv: int, mesh: Mesh, shadow: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position.y = lv * LEVEL_H
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.set_instance_shader_parameter("paint", PAINTS[posmod(b, PAINTS.size())])
	node.set_instance_shader_parameter("building_id", float(b))
	node.set_instance_shader_parameter("accent", accent_for(b))
	return node


## 건물마다 남은 칠(ACCENTS). 이웃한 번호끼리 같은 색이 덜 붙게 건너뛰며 고른다.
static func accent_for(b: int) -> Color:
	return ACCENTS[posmod(b * 5 + 3, ACCENTS.size())]


## 바깥 턱 줄 노드(map_view.wall_nodes 자리, 회색 상자와 같은 열쇠).
func draws_cell(c: Vector2i, lv: int = 0) -> bool:
	return drawn_cells.get(lv, {}).has(c)


func interior_visible(b: int, lv: int) -> bool:
	return not shells.has(Vector2i(b, lv)) or _mode(b, lv) == 2


func cut_node(b: int, lv: int) -> MeshInstance3D:
	return shells.get(Vector2i(b, lv), {}).get("cut")


# ---------------------------------------------------------------- 보이는 규칙 (3장)

## 0 숨김, 1 닫힘(바깥 껍데기), 2 열림(턱과 안).
func _mode(b: int, lv: int) -> int:
	if player_lv < 0:
		if lv >= 0:
			return 0
		return 2 if b == open_b and lv == open_lv else 1
	if lv < 0:
		return 0
	if b != open_b:
		return 1
	if lv > open_lv:
		return 0
	return 2 if lv == open_lv else 1


func _low(b: int, lv: int) -> bool:
	return b == open_b and lv == open_lv


func _apply() -> void:
	for shell: Vector2i in shells:
		var mode := _mode(shell.x, shell.y)
		var parts: Dictionary = shells[shell]
		if parts.has("cut"):
			var low := _low(shell.x, shell.y)
			var node: MeshInstance3D = parts["cut"]
			node.mesh = cut_meshes[shell][1] if low else cut_meshes[shell][0]
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if low else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			_show(node, mode > 0)
		if parts.has("stand"):
			_show(parts["stand"], mode > 0)
		for slot in ["int_cut", "int_stand"]:
			if parts.has(slot):
				_show(parts[slot], mode == 2)
	for b: int in roofs:
		_show(roofs[b], player_lv >= 0 and b != open_b)
	for key: Vector3i in door_nodes:
		var row: Dictionary = door_nodes[key]
		var plan_row: Dictionary = row["plan"]
		var mode := _mode(plan_row["b"], key.z)
		var cut: bool = plan_row["line"] == "int_cut" or (plan_row["line"] == "cut" and _low(plan_row["b"], key.z))
		if cut != row["cut"]:
			row["cut"] = cut
			_draw_door(key)
		_show(row["node"], mode == 2 if plan_row["line"].begins_with("int") else mode > 0)
	for key: Vector3i in window_nodes:
		var row: Dictionary = window_nodes[key]
		var plan_row: Dictionary = row["plan"]
		var cut: bool = plan_row["line"] == "cut" and _low(plan_row["b"], key.z)
		if cut != row["cut"]:
			row["cut"] = cut
			_draw_window(key)
		_show(row["node"], _mode(plan_row["b"], key.z) > 0)
	var open := open_b >= 0 and footprints.has(open_b)
	material.set_shader_parameter("open_building", float(open_b) if open else -1.0)
	if open:
		var r: Rect2i = footprints[open_b]
		material.set_shader_parameter("open_rect", Vector4(r.position.x, r.position.y, r.end.x, r.end.y))
		material.set_shader_parameter("open_floor", open_lv * LEVEL_H + 0.3)


func _show(node: MeshInstance3D, on: bool) -> void:
	var target := 0.0 if on else 1.0
	if _instant:
		node.visible = on
		node.set_instance_shader_parameter("fade", 0.0)
		_fades.erase(node)
		return
	if _fades.has(node):
		var f: Array = _fades[node]
		if f[1] == target:
			return
		_fades[node] = [lerpf(f[0], f[1], f[2]), target, 0.0]
		return
	if node.visible == on:
		return
	node.visible = true
	node.set_instance_shader_parameter("fade", 1.0 - target)
	_fades[node] = [1.0 - target, target, 0.0]


func show_levels(player_level: int) -> void:
	if player_level == player_lv:
		return
	player_lv = player_level
	_apply()


## 플레이어가 든 건물과 층(−1 = 밖). 문 칸과 그 바깥 한 칸에서는 열림을 둔다(3.4, 가안).
func cut_away(building_id: int, level: int) -> void:
	_want = Vector2i(building_id, level)
	if building_id < 0 and open_b >= 0 and _near_door(open_b):
		_holding = true
		return
	_holding = false
	if building_id == open_b and level == open_lv:
		return
	open_b = building_id
	open_lv = level
	_apply()


func _near_door(b: int) -> bool:
	for c: Vector2i in outer_doors.get(b, []):
		if absi(c.x - _focus_cell.x) <= 1 and absi(c.y - _focus_cell.y) <= 1:
			return true
	return false


# ---------------------------------------------------------------- 문과 창

func update_door(c: Vector2i) -> void:
	for lv in levels:
		var key := Vector3i(c.x, c.y, lv)
		if door_nodes.has(key):
			_draw_door(key)


func update_window(c: Vector2i) -> void:
	for lv in levels:
		var key := Vector3i(c.x, c.y, lv)
		if window_nodes.has(key):
			_draw_window(key)


## 문짝: 경첩(대응표 hinge_m)이 기준이고 닫히면 문 칸을 가로지른다. 열리면 안쪽으로 90°.
func _draw_door(key: Vector3i) -> void:
	var row: Dictionary = door_nodes[key]
	var plan_row: Dictionary = row["plan"]
	var lg: FieldGrid = levels[key.z]
	var door: Dictionary = lg.doors.get(Vector2i(key.x, key.y), {})
	var yaw: float = plan_row["yaw"]
	var at := Vector3(key.x + 0.5, 0, key.y + 0.5)
	var hinge := at + Basis(Vector3.UP, yaw) * Vector3(-0.45, 0, 0)
	var cut: bool = row["cut"]
	var bake := Bake.new()
	match String(door.get("state", "closed")):
		"open":
			bake.add(_arrays["door_leaf_cut" if cut else "door_leaf"], _xf(hinge, yaw + PI * 0.5))
		"broken":
			if not cut:
				bake.add(_arrays["door_leaf_broken"], _xf(hinge, yaw))
		"locked":
			bake.add(_arrays["door_leaf_cut" if cut else "door_leaf"], _xf(hinge, yaw))
			# 자물쇠 판: 열쇠로 잠긴 집 문으로 읽게 안팎 같은 작은 판(결정 카드 4 가, 코디네이터
			# 10-25 — 바깥 쇠 빗장은 금지선 「밖에서 잠근 문」과 닿아 뺐다).
			var lock_y := 0.2 if cut else 1.0
			for side in [-1.0, 1.0]:
				bake.box(_xf(at + Basis(Vector3.UP, yaw) * Vector3(0.32, lock_y, 0.06 * side), yaw), Vector3(0.035, 0.07, 0.012), ZONE_METAL_OUT if side > 0.0 else ZONE_METAL_IN)
		_:
			bake.add(_arrays["door_leaf_cut" if cut else "door_leaf"], _xf(hinge, yaw))
	if not cut:
		_bake_door_planks(bake, lg, Vector2i(key.x, key.y), door, yaw)
	row["node"].mesh = bake.mesh()


## 문 판자(J08): 면마다 그 면 쪽에 DOOR_PLANKS 자리부터.
func _bake_door_planks(bake: Bake, lg: FieldGrid, c: Vector2i, door: Dictionary, yaw: float) -> void:
	var at := Vector3(c.x + 0.5, 0, c.y + 0.5)
	var sides := lg.faces(c)
	var outer := lg.outer_face(c)
	for f in 2:
		var dir := Vector3(sides[f].x - c.x, 0, sides[f].y - c.y)
		for i in range(mini(BuildingRules.planks(door, f), DOOR_PLANKS.size())):
			var slot: Array = DOOR_PLANKS[i]
			var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, deg_to_rad(float(slot[1]))), at + dir * FACE_OFF + Vector3(0, float(slot[0]), 0))
			bake.box(xf, Vector3(0.52, 0.07, 0.02), ZONE_WOOD_OUT if f == outer else ZONE_WOOD_IN)


func _draw_window(key: Vector3i) -> void:
	var row: Dictionary = window_nodes[key]
	var lg: FieldGrid = levels[key.z]
	var win: Dictionary = lg.windows.get(Vector2i(key.x, key.y), {})
	var xf := _xf(Vector3(key.x + 0.5, 0, key.y + 0.5), row["plan"]["yaw"])
	var bake := Bake.new()
	var c := Vector2i(key.x, key.y)
	var sides := lg.faces(c)
	var outer := lg.outer_face(c)
	var inner := 1 - outer if outer >= 0 else 1
	var in_dir := Vector3(sides[inner].x - c.x, 0, sides[inner].y - c.y)
	if not row["cut"]:
		if win.get("broken", false):
			bake.add(_arrays["window_glass_broken"], xf)
		elif win.get("open", false):
			bake.add(_arrays["window_glass"], _swung(xf, in_dir))
		else:
			bake.add(_arrays["window_glass"], xf)
		# 판자(J08): 면마다 그 면 쪽에 위 자리부터. 넷째 자리는 첫 두 자리 사이(판자 틈은 남는다).
		var slots := _window_plank_slots()
		for f in 2:
			var dir := Vector3(sides[f].x - c.x, 0, sides[f].y - c.y)
			var fx := Transform3D(xf.basis, xf.origin + dir * FACE_OFF)
			for i in range(mini(BuildingRules.planks(win, f), slots.size())):
				var slot: Dictionary = slots[i]
				bake.add(_arrays["window_boards"], fx * Transform3D(Basis(Vector3.BACK, deg_to_rad(float(slot["roll_deg"]))), Vector3(0, float(slot["height_m"]), 0)))
		# 커튼: 안쪽 면에. 닫히면 창을 덮고, 열리면 양옆에 모인다.
		if BuildingRules.has_curtain(win):
			var cloth_at := xf.origin + in_dir * (FACE_OFF + 0.05) + Vector3(0, 1.35, 0)
			if String(win["curtain"]) == "closed":
				bake.box(Transform3D(xf.basis, cloth_at), Vector3(0.46, 0.55, 0.015), ZONE_CLOTH)
			else:
				for side in [-1.0, 1.0]:
					bake.box(Transform3D(xf.basis, cloth_at + xf.basis.x * 0.4 * side), Vector3(0.07, 0.55, 0.02), ZONE_CLOTH)
	if win.get("glass", false):
		bake.add(_arrays["window_glass_floor"], xf)
	# 바닥에 떨어진 유리(깬 사람 반대쪽 칸).
	for fell: Vector2i in lg.floor_glass:
		if lg.floor_glass[fell] == c:
			bake.add(_arrays["window_glass_floor"], Transform3D(xf.basis, Vector3(fell.x + 0.5, xf.origin.y, fell.y + 0.5)))
	row["node"].mesh = bake.mesh()


## 연 창: 한쪽 경첩을 축으로 안쪽으로 80° 돌린 유리짝(여닫이창).
static func _swung(xf: Transform3D, in_dir: Vector3) -> Transform3D:
	var best := xf
	var best_d := INF
	for turn in [-1.0, 1.0]:
		var t := xf * Transform3D(Basis(), Vector3(-0.45, 0, 0)) * Transform3D(Basis(Vector3.UP, turn * deg_to_rad(80.0)), Vector3.ZERO) * Transform3D(Basis(), Vector3(0.45, 0, 0))
		var d := (t.origin - (xf.origin + in_dir)).length_squared()
		if d < best_d:
			best_d = d
			best = t
	return best


## 창 판자 자리 넷: 대응표의 셋에 넷째(첫 두 자리 사이, 반대로 기울게)를 더한다.
static func _window_plank_slots() -> Array:
	var out: Array = _board_slots.duplicate()
	if out.size() >= 2 and out.size() < BuildingRules.PLANKS_PER_FACE:
		out.append({"height_m": (float(out[0]["height_m"]) + float(out[1]["height_m"])) * 0.5, "roll_deg": -float(out[0]["roll_deg"])})
	return out


# ---------------------------------------------------------------- 시야와 매 틀

## 지붕은 바깥벽 칸 가운데 가장 밝게 본 값을 받는다(지붕 밑 칸은 늘 못 본 칸이라).
func update_seen(vis_bytes: PackedByteArray) -> void:
	for b: int in roofs:
		var now := 0
		var before := 0
		for i: int in outer_cells.get(b, PackedInt32Array()):
			now = maxi(now, vis_bytes[i * 4])
			before = maxi(before, vis_bytes[i * 4 + 1])
		var v := Vector2(now / 255.0, before / 255.0)
		if _seen.get(b, Vector2(-1, -1)) != v:
			_seen[b] = v
			roofs[b].set_instance_shader_parameter("seen_fixed", v)


func _process(delta: float) -> void:
	_sync("mask_on")
	_sync("lamp_gain")
	var cam := get_viewport().get_camera_3d()
	if cam:
		var back := cam.global_transform.basis.z.normalized()
		var plane := (player_lv if player_lv >= 0 else -1) * LEVEL_H
		if absf(back.y) > 0.01:
			var focus := cam.global_position - back * ((cam.global_position.y - plane) / back.y)
			_focus_cell = Vector2i(floori(focus.x), floori(focus.z))
			material.set_shader_parameter("hole_center", focus + Vector3(0, 0.9, 0))
			material.set_shader_parameter("cam_back", back)
	if _holding and not _near_door(open_b):
		_holding = false
		cut_away(_want.x, _want.y)
	for node: MeshInstance3D in _fades.keys():
		var f: Array = _fades[node]
		f[2] = minf(1.0, float(f[2]) + delta / FADE_S)
		node.set_instance_shader_parameter("fade", lerpf(f[0], f[1], f[2]))
		if f[2] >= 1.0:
			_fades.erase(node)
			if f[1] >= 1.0:
				node.visible = false


func _sync(key: String) -> void:
	var v: Variant = world_material.get_shader_parameter(key)
	if v != null and _synced.get(key) != v:
		_synced[key] = v
		material.set_shader_parameter(key, v)
