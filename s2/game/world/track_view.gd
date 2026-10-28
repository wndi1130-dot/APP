extends RefCounted
## 필드 선로의 침목과 레일(결정 476 대각뷰 점검 7): 지도 RAIL 칸의 x 방향 줄기마다 0.7 m 조각
## (침목 하나 + 그 길이만큼의 레일 둘)을 MultiMesh로 되풀이한다 — 지도 안 하나, 지도 밖(edge_band.gd
## rail_runs) 하나라 그리기 호출은 둘이다. 재질은 지도 재질(world_vis)을 그대로 받아 시야 가림·기억
## 회색·눈이 땅과 같이 먹는다(셰이더가 MODEL_MATRIX로 자리를 잡아 인스턴스마다 맞다).
## 자료는 읽기만 한다: 선로 칸은 지도 쪽, 그림은 열차 쪽. 치수는 정차 장면(stop_cinema.gd)과 같다.
## 지도의 선로는 모두 x 방향이다(세로 선로·갈림길 없음). 길이 선로를 건너는 건널목(지도
## data["rail_crossings"], map-layout M1)에는 레일 사이와 바깥에 판자를 깐다 — 메시 하나, 그리기 호출 하나.

const FieldGrid = preload("res://game/world/field_grid.gd")
const F = FieldGrid.Floor

const STEP := 0.7
const GAUGE_HALF := 0.72
const SLEEPER := Vector3(0.24, 0.1, 2.5)
const SLEEPER_Y := 0.07
const RAIL := Vector3(STEP, 0.12, 0.08)
const RAIL_Y := 0.16
## 레일 윗면(바퀴가 서는 높이). 선로 위 열차와 화차를 이만큼 올린다.
const RAIL_TOP := RAIL_Y + RAIL.y * 0.5
const SLEEPER_COLOR := Color(0.24, 0.21, 0.19)
const STEEL := Color(0.25, 0.25, 0.27)
## 세로로 붙은 RAIL 칸 묶음은 이 칸 수마다 선로 한 벌(본선 3칸, 나란히 붙은 두 줄 6칸은 두 벌).
## 1~2칸 폭(곁선, 화차 밑 토막)은 그 가운데 한 벌.
const LINE_CELLS := 3
## 건널목 판자: 판 윗면은 레일 윗면 바로 밑(레일이 판 사이로 보인다), 판은 침목 위에 얹는다.
## 레일 안쪽은 바퀴 테 홈(FLANGEWAY)을 비우고, 바깥은 판 두 장 0.5 m씩.
const PLANK_TOP := RAIL_TOP - 0.01
const PLANK_BASE := SLEEPER_Y + SLEEPER.y * 0.5
const PLANK_GAP := 0.02
const FLANGEWAY := 0.06
const PLANK_COLORS := [Color(0.31, 0.27, 0.23), Color(0.27, 0.24, 0.21)]


## x 방향 선로 줄기 [{"x0", "x1", "z"}]: 같은 가운데 줄(z)을 가진 RAIL 칸이 x로 이어진 구간.
static func runs(grid: FieldGrid) -> Array:
	var open: Dictionary = {}   # z -> x0
	var out: Array = []
	for x in range(grid.width + 1):
		var here: Dictionary = {}
		var y := 0
		while x < grid.width and y < grid.height:
			if grid.floor_at(Vector2i(x, y)) != F.RAIL:
				y += 1
				continue
			var y0 := y
			while y < grid.height and grid.floor_at(Vector2i(x, y)) == F.RAIL:
				y += 1
			for z in lines(y0, y):
				here[z] = true
		for z: float in open.keys():
			if not here.has(z):
				out.append({"x0": float(open[z]), "x1": float(x), "z": z})
				open.erase(z)
		for z: float in here:
			if not open.has(z):
				open[z] = x
	return out


## 세로 칸 [y0, y1)에 놓이는 선로 가운데 줄들.
static func lines(y0: float, y1: float) -> Array[float]:
	var count := maxi(1, roundi((y1 - y0) / LINE_CELLS))
	var out: Array[float] = []
	for i in count:
		out.append(y0 + (float(i) + 0.5) * (y1 - y0) / float(count))
	return out


## 지도 밖 선로 사각형(x 방향만)을 지도 안과 같은 줄기 꼴로.
static func outside_runs(rects: Array) -> Array:
	var out: Array = []
	for r: Rect2 in rects:
		if r.size.x < r.size.y:
			continue
		for z in lines(r.position.y, r.end.y):
			out.append({"x0": r.position.x, "x1": r.end.x, "z": z})
	return out


## 건널목(지도 data["rail_crossings"], 칸 단위 Rect2i — x 폭 = 길이 선로를 건너는 폭, y = 그 RAIL 띠 줄)을
## 지나는 선로 줄기 토막 [{"x0", "x1", "z"}].
static func crossing_runs(line_runs: Array, crossings: Array) -> Array:
	var out: Array = []
	for r: Rect2i in crossings:
		for run: Dictionary in line_runs:
			var z := float(run["z"])
			if z < float(r.position.y) or z >= float(r.end.y):
				continue
			var x0 := maxf(float(run["x0"]), float(r.position.x))
			var x1 := minf(float(run["x1"]), float(r.end.x))
			if x1 > x0:
				out.append({"x0": x0, "x1": x1, "z": z})
	return out


## 판자를 까는 가로(z) 구간 [시작, 끝, 판 수]: 레일 사이 하나, 양 바깥 둘(선로 가운데 줄에서 잰 값).
static func board_spans() -> Array:
	var inner := GAUGE_HALF - RAIL.z * 0.5 - FLANGEWAY
	var outer := GAUGE_HALF + RAIL.z * 0.5 + 0.04
	return [[-inner, inner, 5], [outer, outer + 0.5, 2], [-outer - 0.5, -outer, 2]]


## 건널목 판자 한 메시(건널목은 정차마다 몇 곳뿐이라 MultiMesh 없이 하나). 토막이 없으면 null.
static func crossing_mesh(pieces: Array) -> ArrayMesh:
	if pieces.is_empty():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for run: Dictionary in pieces:
		var x0 := float(run["x0"])
		var x1 := float(run["x1"])
		var k := 0
		for span: Array in board_spans():
			var n := int(span[2])
			var w := (float(span[1]) - float(span[0]) - PLANK_GAP * (n - 1)) / float(n)
			for i in n:
				var z := float(run["z"]) + float(span[0]) + w * 0.5 + (w + PLANK_GAP) * i
				_box(st, Vector3(x1 - x0, PLANK_TOP - PLANK_BASE, w), Vector3((x0 + x1) * 0.5, (PLANK_TOP + PLANK_BASE) * 0.5, z), PLANK_COLORS[k % 2])
				k += 1
	return st.commit()


## 지도 안 선로와 지도 밖 선로를 묶음 하나씩, 건널목이 있으면 판자 메시 하나. 모두 그림자를 드리우지
## 않는다: 0.22 m 높이라 그림자는 거의 안 보이는데, 그림자 그리기마다 조각이 다시 들어가 삼각형이 네 배가
## 됐다(첫 정차 지도 +5.8만).
static func build(parent: Node3D, grid: FieldGrid, material: Material, outside: Array = [], crossings: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = "Track"
	parent.add_child(root)
	var inside := runs(grid)
	for line: Array in [["TrackMap", inside], ["TrackOutside", outside_runs(outside)]]:
		var node := _instances(String(line[0]), line[1], material)
		if node != null:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(node)
	var boards := crossing_mesh(crossing_runs(inside, crossings))
	if boards != null:
		var node := MeshInstance3D.new()
		node.name = "TrackCrossings"
		node.mesh = boards
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
	return root


## 그 칸 사각형(열차·화차가 선 자리)의 가운데가 선로 위면 RAIL_TOP, 아니면 0.
static func height_under(grid: FieldGrid, rect: Rect2i) -> float:
	var c := rect.get_center()
	if c.x < 0 or c.y < 0 or c.x >= grid.width or c.y >= grid.height:
		return 0.0
	return RAIL_TOP if grid.floor_at(c) == F.RAIL else 0.0


## 화차마다 height_under(지도 data["wagons"]의 rect).
static func wagon_heights(grid: FieldGrid, wagons: Array) -> Array:
	var out: Array = []
	for w: Dictionary in wagons:
		out.append(height_under(grid, w["rect"]))
	return out


## 조각 자리: 온 세상에서 같은 간격(STEP)의 가운데 가운데 줄기 안에 드는 것만. 이웃 줄기(지도 끝의
## 안과 밖)가 맞닿아도 레일이 끊기거나 겹치지 않는다.
static func spots(line_runs: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for run: Dictionary in line_runs:
		# 자리는 칸 번호에서 바로 셈해(더해 가지 않아) 어느 줄기에서 와도 같은 값이다.
		var k := ceili(float(run["x0"]) / STEP - 0.5)
		while (float(k) + 0.5) * STEP < float(run["x1"]):
			out.append(Vector3((float(k) + 0.5) * STEP, 0.0, float(run["z"])))
			k += 1
	return out


## 조각 하나: 가운데 침목, 양쪽에 조각 길이만큼의 레일(이웃 조각과 맞닿아 이어진다 — 그래서 레일은
## 끝면 없이 윗면과 양옆만, 조각당 삼각형 22).
static func piece() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, SLEEPER, Vector3(0, SLEEPER_Y, 0), SLEEPER_COLOR)
	for side: float in [-1.0, 1.0]:
		_box(st, RAIL, Vector3(0, RAIL_Y, side * GAUGE_HALF), STEEL, false)
	return st.commit()


static func _instances(name: String, line_runs: Array, material: Material) -> MultiMeshInstance3D:
	var at := spots(line_runs)
	if at.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = piece()
	mm.instance_count = at.size()
	for i in at.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, at[i]))
	var node := MultiMeshInstance3D.new()
	node.name = name
	node.multimesh = mm
	node.material_override = material
	return node


## 바닥 없는 상자(위·옆 넷), map_view.gd box와 같은 꼴. 알파 1(하늘 아래: 눈이 윗면에 앉는다).
## ends: false면 x 쪽 두 끝면을 뺀다(이웃 조각과 맞닿는 레일).
static func _box(st: SurfaceTool, size: Vector3, at: Vector3, color: Color, ends: bool = true) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(0, 1, 0), [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3(0, 0, 1), [Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z)]],
		[Vector3(0, 0, -1), [Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z)]],
	]
	if ends:
		faces.append([Vector3(1, 0, 0), [Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, -h.y, -h.z)]])
		faces.append([Vector3(-1, 0, 0), [Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, -h.y, h.z)]])
	for face in faces:
		var n: Vector3 = face[0]
		var v: Array = face[1]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(color)
			st.set_normal(n)
			st.add_vertex(at + v[idx])
