extends RefCounted
## 한 집이 함께 쓰는 네 가지 칠 판. 값은 sRGB이며 dress()가 srgb_to_linear()로 바꿔 싣는다.
## 셰이더 tint_sets_body/trim의 rgb는 선형, a는 칠 세기다. 판 수는 방 꾸밈(room_furnish TINT_SETS)과 같다.

const SETS: Array[Dictionary] = [
	# 바랜 회청 몸체와 검은 쇠 테두리.
	{"body": Color(0.38, 0.44, 0.49), "trim": Color(0.20, 0.22, 0.24)},
	# 짙은 녹회 몸체와 흙갈색 테두리.
	{"body": Color(0.34, 0.40, 0.36), "trim": Color(0.35, 0.31, 0.26)},
	# 탁한 적갈색 몸체와 짙은 갈색 테두리.
	{"body": Color(0.43, 0.33, 0.31), "trim": Color(0.27, 0.23, 0.20)},
	# 그늘진 회백색 몸체와 차가운 회청 테두리(0.62는 방 안에서 흰색으로 떠 0.50으로 누름).
	{"body": Color(0.50, 0.51, 0.49), "trim": Color(0.34, 0.39, 0.43)},
]
## 칠 세기: 몸체는 판 색이 거의 덮고, 테두리는 바탕 나뭇결·쇠붙이가 더 남는다.
const BODY_STRENGTH := 0.8
const TRIM_STRENGTH := 0.6
## 정점색 알파로 칠할 곳을 적어 구운 가구(props_stop01_cc0.py)만 칠한다.
const KINDS: Array[String] = ["wardrobe", "shop_shelf", "bookcase", "dining_set", "table_overturned",
	"workbench", "office_desk", "iron_bed", "drawer_chest_spilled", "toolbox"]


## 줄의 "tint"가 먼저, 다음은 건물 번호(줄의 "building", 없으면 놓인 자리의 건물), 둘 다 없을 때만 칸.
static func pick(row: Dictionary, cell: Vector2i, building: int = -1) -> int:
	if row.has("tint"):
		return posmod(int(row["tint"]), SETS.size())
	if row.has("building"):
		building = int(row["building"])
	if building >= 0:
		return roll("building:%d" % building)
	return roll("cell:%d:%d" % [cell.x, cell.y])


## 글 열쇠로 판 번호를 굴린다. String.hash()(djb2)는 끝 글자가 바뀌면 값이 그만큼만 바뀌어 아래
## 비트는 번호 자릿수 합, 위 비트는 거의 그대로라, PCG로 섞은 뒤 고른다(room_furnish.tint_for와 같이).
static func roll(key: String) -> int:
	return int(rand_from_seed(key.hash())[0]) % SETS.size()


static func applies(path: String) -> bool:
	return path.begins_with("res://models/props_stop01/") and path.get_file().get_basename() in KINDS


## 묶음 그리기 재질에 판 색을 싣는다. 칸마다 판 번호는 MultiMesh 사용자 자료로 간다.
static func dress(mesh: Mesh) -> void:
	var body: Array[Vector4] = []
	var trim: Array[Vector4] = []
	for row: Dictionary in SETS:
		var b: Color = (row["body"] as Color).srgb_to_linear()
		var t: Color = (row["trim"] as Color).srgb_to_linear()
		body.append(Vector4(b.r, b.g, b.b, BODY_STRENGTH))
		trim.append(Vector4(t.r, t.g, t.b, TRIM_STRENGTH))
	var ref := paint_ref(mesh)
	for surface in range(mesh.get_surface_count()):
		var material := mesh.surface_get_material(surface) as ShaderMaterial
		if material == null:
			continue
		material.set_shader_parameter("tint_from_custom", true)
		material.set_shader_parameter("tint_sets_body", body)
		material.set_shader_parameter("tint_sets_trim", trim)
		material.set_shader_parameter("tint_ref", ref)


## 칠할 몸체(정점색 알파 0.75 이상)와 테두리(0.25~0.75)의 넓이 평균 선형 밝기(재질 albedo 포함).
## 셰이더는 칠 색에 「바탕 밝기 / 이 값」을 곱해 결만 남기고 칠이 남긴 바탕도 판 밝기로 맞추므로,
## 밝은 원목 모형과 어두운 쇠 모형이 같은 판을 같은 밝기로 받는다. 칠할 곳이 없는 칸은 예전 기준
## 0.18. 묶음 메시는 정차마다 다시 쓰여 메시 메타에 한 번만 잰다.
static func paint_ref(mesh: Mesh) -> Vector2:
	if mesh.has_meta("paint_ref"):
		return mesh.get_meta("paint_ref")
	var sums := [0.0, 0.0]
	var areas := [0.0, 0.0]
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var colors = arrays[Mesh.ARRAY_COLOR]
		if colors == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index = arrays[Mesh.ARRAY_INDEX]
		var tint := Color(1, 1, 1)
		var material := mesh.surface_get_material(surface) as ShaderMaterial
		if material != null and material.get_shader_parameter("albedo") is Color:
			tint = (material.get_shader_parameter("albedo") as Color).srgb_to_linear()
		var count: int = index.size() if index != null else verts.size()
		for t in range(0, count - 2, 3):
			var i0: int = index[t] if index != null else t
			var i1: int = index[t + 1] if index != null else t + 1
			var i2: int = index[t + 2] if index != null else t + 2
			var c: Color = (colors[i0] + colors[i1] + colors[i2]) / 3.0
			var part := 0 if c.a >= 0.75 else (1 if c.a >= 0.25 else -1)
			if part < 0:
				continue
			var area := (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0]).length() * 0.5
			sums[part] += area * (0.2126 * c.r * tint.r + 0.7152 * c.g * tint.g + 0.0722 * c.b * tint.b)
			areas[part] += area
	var ref := Vector2(sums[0] / areas[0] if areas[0] > 0.0 else 0.18, sums[1] / areas[1] if areas[1] > 0.0 else 0.18)
	mesh.set_meta("paint_ref", ref)
	return ref
