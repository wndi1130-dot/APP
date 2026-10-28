extends RefCounted
## 한 집이 함께 쓰는 네 가지 칠 판. 값은 sRGB이며 연결하는 쪽에서 srgb_to_linear()를 쓴다.
## tint_body/tint_trim의 rgb는 선형, a는 칠 세기다. 판 수는 방 꾸밈(room_furnish TINT_SETS)과 같다.

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
		return posmod(("building:%d" % building).hash(), SETS.size())
	return posmod(("cell:%d:%d" % [cell.x, cell.y]).hash(), SETS.size())


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
	for surface in range(mesh.get_surface_count()):
		var material := mesh.surface_get_material(surface) as ShaderMaterial
		if material == null:
			continue
		material.set_shader_parameter("tint_from_custom", true)
		material.set_shader_parameter("tint_sets_body", body)
		material.set_shader_parameter("tint_sets_trim", trim)
