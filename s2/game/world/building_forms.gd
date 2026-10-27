extends RefCounted
## 건물 꼴 1가(결정 478, docs/art/building_forms.md): 용도·지역으로 벽 재질·색 판·지붕(박공 물매·
## 평지붕)·굴뚝을 고른다. 새 조각 없이 셰이더(벽 재질, building.gdshader wall_kind)와 있는 조각
## (박공을 물매로 늘림, 평지붕)만 쓴다. 지역을 모르는 지도(시험 지도)는 지금 꼴 그대로다.
## 같은 용도 안에서는 건물 번호로 색 판·지붕 색을 굴린다(통제된 무작위).

const Uses = preload("res://game/world/building_uses.gd")

## 벽 재질(building.gdshader wall_kind; PLINTH를 더하면 땅층 아래 0.6 m 돌 기단 띠).
const RENDER := 0
const BRICK := 1
const BOARDS := 2       # 세로 판자(헛간·창고·산골 일터)
const CLAPBOARD := 3    # 가로 판자(물가 집)
const LOG := 4          # 통나무(높은 산)
const CORRUGATED := 5   # 골함석
const PLINTH := 8
const WALL_NAMES: Array[String] = ["render", "brick", "boards", "clapboard", "log", "corrugated"]

## 지역 -> 용도("*"는 나머지) -> [재질, 돌 기단, 색 판]. 색 판 "town"은 지금 칠(building_view.PAINTS).
const WALLS: Dictionary = {
	"town": {
		"*": [RENDER, false, "town"], "clinic": [RENDER, false, "white"], "office": [BRICK, true, "brick"],
		"church": [BRICK, true, "brick"], "bell_tower": [BRICK, true, "brick"], "station": [BRICK, false, "brick"],
		"works": [BRICK, false, "brick"], "depot": [BRICK, false, "brick"], "store": [CORRUGATED, false, "metal"],
		"barn": [BOARDS, false, "barn"], "shed": [BOARDS, false, "weathered"], "shelter": [BOARDS, false, "weathered"],
	},
	"rail_works": {
		"*": [BRICK, false, "brick"], "home": [RENDER, false, "soot"], "hall": [RENDER, false, "soot"],
		"office": [BRICK, true, "brick"], "store": [CORRUGATED, false, "metal"], "barn": [BOARDS, false, "weathered"],
		"shed": [CORRUGATED, false, "metal"], "shelter": [BOARDS, false, "weathered"],
	},
	"mountain_works": {
		"*": [BOARDS, false, "creosote"], "headframe": [BRICK, false, "brick"], "works": [CORRUGATED, false, "metal"],
		"store": [CORRUGATED, false, "metal"], "shed": [CORRUGATED, false, "metal"], "office": [BOARDS, true, "creosote"],
	},
	"high_mountain": {
		"*": [LOG, true, "log"], "shed": [BOARDS, false, "creosote"], "store": [BOARDS, false, "creosote"],
		"depot": [BOARDS, true, "creosote"], "barn": [BOARDS, false, "creosote"],
	},
	"waterside": {
		"*": [CLAPBOARD, false, "lake"], "store": [BOARDS, false, "weathered"], "shed": [BOARDS, false, "weathered"],
		"works": [BOARDS, false, "weathered"], "office": [CLAPBOARD, true, "lake"],
	},
	"bare_line": {"*": [CORRUGATED, false, "metal"], "home": [BOARDS, false, "weathered"]},
}
## 색 판(sRGB로 적고 고를 때 선형으로 바꿔 넘긴다 — 셰이더 paint는 집 칠 PAINTS처럼 선형 값).
## 판자·통나무·벽돌은 그늘에서도 V 0.15 밑으로 꺼지지 않게 실측 범위 위쪽(결정 470), 흰 회칠은 0.9 밑.
const PALETTES: Dictionary = {
	"white": [Color(0.88, 0.87, 0.82), Color(0.84, 0.84, 0.80)],
	"brick": [Color(0.66, 0.42, 0.34), Color(0.60, 0.40, 0.34), Color(0.74, 0.62, 0.46)],
	"soot": [Color(0.70, 0.66, 0.59), Color(0.64, 0.62, 0.58), Color(0.74, 0.68, 0.56)],
	"metal": [Color(0.66, 0.67, 0.68), Color(0.64, 0.50, 0.40), Color(0.56, 0.64, 0.58)],
	"barn": [Color(0.66, 0.36, 0.29), Color(0.60, 0.48, 0.37)],
	"weathered": [Color(0.64, 0.61, 0.56), Color(0.60, 0.52, 0.44)],
	"creosote": [Color(0.60, 0.48, 0.37), Color(0.55, 0.45, 0.36)],
	"log": [Color(0.62, 0.48, 0.34), Color(0.57, 0.46, 0.35)],
	"lake": [Color(0.88, 0.86, 0.80), Color(0.68, 0.76, 0.82), Color(0.66, 0.38, 0.31), Color(0.84, 0.77, 0.58)],
}
## 지역 -> 지붕 색(building.gdshader ROOFS 번호). 읍내는 지금 굴림(0~3) 그대로.
const ROOF_COLOURS: Dictionary = {
	"rail_works": [4, 7, 1], "mountain_works": [5, 7, 6], "high_mountain": [6, 4],
	"waterside": [2, 1, 0], "bare_line": [5, 7],
}
## 박공 물매 배수(기본 35°): 1.7 ≈ 50°, 2.2 ≈ 57°, 1.45 ≈ 45°, 0.75 ≈ 28°.
const PITCH_OF_USE: Dictionary = {"church": 1.7, "bell_tower": 2.2, "lodge": 1.7, "barn": 1.45}
const STEEP_REGION := 1.7
const LOW := 0.75
const LOW_USES: Array[String] = ["works", "depot", "store", "shed", "sawmill", "shelter"]
## 굴뚝을 다는 용도(연기는 없음). 난로가 있는 건물은 용도와 상관없이 단다.
const CHIMNEY_USES: Array[String] = ["home", "lodge", "hall"]
## 평지붕이 되는 크기: 일터는 이 칸 수 이상, 가게는 2층 이상(큰길 상가).
const FLAT_WORKS_CELLS := 160


## 건물 줄(data["buildings"]의 한 줄)과 지도 이름으로 꼴. `paint`는 지금 칠(building_view.paint_for),
## 지역을 모르면 그대로 돌려준다. 돌려주는 것: use, region, wall(이름), wall_kind, paint(rgb + 지붕 색
## 번호 a), roof("gable"·"flat"), pitch, chimney.
static func pick(row: Dictionary, place_id: String, paint: Color, levels: int = 1) -> Dictionary:
	var group := Uses.group_of(place_id)
	var region := String(Uses.REGION_OF_GROUP.get(group, "?"))
	var named := row.duplicate()
	named["group"] = group
	var use := Uses.use_of(named)
	var b := int(row.get("id", 0))
	var out := {"use": use, "region": region, "wall": "render", "wall_kind": float(RENDER), "paint": paint,
		"roof": "gable", "pitch": 1.0, "chimney": use in CHIMNEY_USES}
	if not WALLS.has(region):
		return out
	var table: Dictionary = WALLS[region]
	var wall: Array = table.get(use, table["*"])
	var h := (b * 2654435761 + 977) & 0xffffffff
	var colour := paint
	if String(wall[2]) != "town":
		var pal: Array = PALETTES[wall[2]]
		colour = (pal[(h >> 7) % pal.size()] as Color).srgb_to_linear()
	if ROOF_COLOURS.has(region):
		var roofs: Array = ROOF_COLOURS[region]
		colour.a = float(roofs[(h >> 13) % roofs.size()])
	else:
		colour.a = paint.a
	out["wall"] = WALL_NAMES[int(wall[0])]
	out["wall_kind"] = float(int(wall[0]) + (PLINTH if bool(wall[1]) else 0))
	out["paint"] = colour
	var pitch := float(PITCH_OF_USE.get(use, 1.0))
	if region == "high_mountain":
		pitch = maxf(pitch, STEEP_REGION if use not in LOW_USES else 1.0)
	elif pitch == 1.0 and use in LOW_USES and region in ["rail_works", "mountain_works", "bare_line"]:
		pitch = LOW
	out["pitch"] = pitch
	var cells := (row["rect"] as Rect2i).get_area() if row.get("rect") is Rect2i else 0
	if use == "clinic" or (use == "works" and cells >= FLAT_WORKS_CELLS) or (use == "shop" and region == "town" and levels >= 2):
		out["roof"] = "flat"
	return out
