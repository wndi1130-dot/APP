extends RefCounted
## 방 마감(결정 469 C3·477, 사용자 10-28 「바닥재질도 방마다 다르게, 색깔도 다양하게」): 살림집 방
## 갈래마다 바닥 재질과 벽 칠을 집마다·지역마다 굴려, 땅·건물 셰이더가 칸으로 읽는 그림 하나에
## 담는다(시야 그림 vis와 같은 길, filter_nearest).
## 방 갈래는 지도가 그 방에 놓은 가구로 읽는다: 가구에 적힌 그 방 갈래(rule)가 먼저, 없으면
## 가구 종류(room_furnish가 방 이름·가구로 고른 묶음의 결과). 식탁을 둔 거실 묶음 방은 식당(room_split
## DINING, 가구에 dining 표시), 벽장·찬방 선반(rule store)·창고 가구 방은 창고 칸, 살림집 안에서 가구
## 없이 좁거나(짧은 변 2칸 이하) 문이 셋 이상 난 방은 복도다.
## 손으로 그린 지도(첫 정차)는 가구가 이름 붙은 물건 상자로만 있어 그 이름이 말하는 방으로 읽는다.
## 살림집 밖(가게·일터)의 방은 0이라 지금 그림 그대로다.
## 층마다 채널 하나: 0층 R, 1층 G, 지하 B, 2층 A. 칸 값 = 갈래(1~7) + 8 × 판(0~29),
## 판 = 지역 × VARIANTS + 집마다 굴린 번호. 한 집에 같은 갈래 방이 여럿이면(농가의 침실 다섯, 연립의 부엌
## 여럿) 방마다 다음 판으로 넘어가 옆방끼리 같은 마감이 되풀이되지 않는다.
## 그림은 지도 폭의 두 배: 오른쪽 절반(x + 지도 폭)은 깔개 칸(room_furnish가 놓은 data.rugs의 look, 0은
## 없음). 셰이더가 이웃 칸으로 깔개 가장자리를 찾는다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")

const BuildingUses = preload("res://game/world/building_uses.gd")

const BED := 1
const KITCHEN := 2
const BATH := 3
const LIVING := 4
const HALL := 5
const DINING := 6
const UTILITY := 7
## 집마다 굴리는 판 수(지역 하나에). 판 값이 5 비트(0~31)라 지역 여섯 × 다섯 = 30.
const VARIANTS := 5
## 지역(결정 478 지역 무리, building_uses.gd) 차례. 셰이더가 판 / VARIANTS로 읽는다.
const REGIONS: Array[String] = ["town", "rail_works", "mountain_works", "high_mountain", "waterside", "bare_line"]
## 방 갈래를 알리는 가구(room_furnish PALETTE의 그 묶음 가구). 앞 줄이 이긴다: 욕실 가구가
## 있으면 욕실, 그다음 부엌·침실·거실. 뒤의 넷은 약한 신호로, 센 신호가 없는 방만 가른다
## (식탁만 놓인 방, 옷장만 놓인 방).
const SIGNS: Array = [
	[BATH, ["toilet", "bathtub", "washstand"]],
	[KITCHEN, ["sink", "counter", "fridge_open"]],
	[BED, ["bed", "dresser", "nightstand"]],
	[LIVING, ["settee", "armchair", "low_table", "cold_stove"]],
	[KITCHEN, ["dining_set"]],
	[BED, ["wardrobe"]],
	[LIVING, ["bookcase", "radio_set"]],
]
## 가구 없이 상자로만 놓인 물건(손으로 그린 지도, object_rules.objects): 상자 이름이 말하는 방
## (loot_dress 방 낱말 「부엌」「침실 서랍」「화장실 장」) -> [갈래, 순위]. 순위는 위의 센 신호와 같다.
## 그런 지도에서 object_rules가 지어낸 가구(legacy_model)는 찬장을 책장으로 읽어 쓰지 않는다.
const NAME_SIGNS: Dictionary = {"bathroom": [BATH, 0], "kitchen": [KITCHEN, 1], "bedroom": [BED, 2]}
## room_furnish가 가구마다 적은 그 방의 갈래(rule). 바깥 띠가 지도를 넓혀도 남는다(map-layout).
## 가게·창고·일터 같은 다른 갈래의 가구는 종류로 다시 가르지 않는다(가게 조리대는 부엌이 아니다).
const RULE_SIGNS: Dictionary = {"bath": [BATH, 0], "kitchen": [KITCHEN, 1], "bed": [BED, 2], "living": [LIVING, 3],
	"store": [UTILITY, 5], "storage": [UTILITY, 5]}
## 식당 표시(room_furnish가 「식당」 이름표 방의 가구에 단 dining): 부엌을 갈라 뗀 식당(room_split
## DINING). 거실 신호보다 세다. 그냥 거실에 놓인 식탁은 거실 그대로.
const DINING_SIGN: Array = [DINING, 2]
## 살림집이라는 갈래(이 가운데 하나가 든 건물만 복도·창고 칸을 칠한다).
const HOME_KINDS: Array[int] = [BED, KITCHEN, BATH, LIVING, DINING]
## 층 -> 채널(R G B A).
const CHANNEL: Dictionary = {0: 0, 1: 1, -1: 2, 2: 3}


## 방 갈래 표(가구 종류 -> [갈래, 순위]).
static func _signs() -> Dictionary:
	var out: Dictionary = {}
	for rank in range(SIGNS.size()):
		for kind: String in SIGNS[rank][1]:
			out[kind] = [int(SIGNS[rank][0]), rank]
	return out


## 집·갈래마다 판. 번호를 섞어 이웃한 집이 차례로 같은 판을 되풀이하지 않게.
static func variant_for(building: int, cls: int) -> int:
	var h := (building * 2654435761 + cls * 40503 + 977) & 0xffffffff
	return (h >> 9) % VARIANTS


## 지도의 지역 번호(REGIONS 차례, 모르는 지역은 읍내 0).
static func region_index(data: Dictionary) -> int:
	return maxi(0, REGIONS.find(BuildingUses.region_of(String(data.get("place_id", "")))))


## 칸 값: 갈래 + 8 × (지역 × VARIANTS + 집의 판). `nth`는 그 집의 같은 갈래 방 가운데 몇째인가.
static func code_for(building: int, cls: int, region: int, nth: int = 0) -> int:
	return cls + 8 * (region * VARIANTS + (variant_for(building, cls) + nth) % VARIANTS)


## 지도 자료(levels·props)로 방 마감 그림. 첫 층 격자 크기.
static func build(data: Dictionary) -> Image:
	var levels: Dictionary = data.get("levels", {0: data["grid"]})
	var base: FieldGrid = levels.get(0, data["grid"])
	var w := base.width
	var h := base.height
	var bytes := PackedByteArray()
	bytes.resize(w * 2 * h * 4)
	bytes.fill(0)
	var signs := _signs()
	var marks: Dictionary = {}  # 층 -> [[칸, [갈래, 순위]], ...]
	for p: Variant in data.get("props", []):
		if not p is Dictionary or p.has("legacy_model") or not p.get("rect") is Rect2i:
			continue
		var sign: Variant = RULE_SIGNS.get(String(p["rule"])) if p.has("rule") else signs.get(String(p.get("kind", "")))
		if p.get("dining", false):
			sign = DINING_SIGN
		if sign == null:
			continue
		var r: Rect2i = p["rect"]
		_mark(marks, int(p.get("level", 0)), r.position + r.size / 2, sign)
	for b: Variant in data.get("containers", {}).values():
		if not b is Dictionary or (b.has("furniture") and not b.get("object_legacy", false)) or not b.get("cell") is Vector2i:
			continue
		var said := LootDress.room_of_name(String(b.get("name", "")))
		if NAME_SIGNS.has(said):
			_mark(marks, int(b.get("level", 0)), b["cell"], NAME_SIGNS[said])
	var region := region_index(data)
	var found: Dictionary = {}  # 층 -> [방 표, 방 번호 -> [갈래, 순위]]
	var homes: Dictionary = {}  # 살림 방이 든 건물
	for lv: int in levels:
		var g: FieldGrid = levels[lv]
		if not CHANNEL.has(lv) or g.width != w or g.height != h:
			continue
		var map := RoomFurnish.rooms_of(g)
		var of: PackedInt32Array = map["of"]
		var best: Dictionary = {}  # 방 번호 -> [갈래, 순위]
		for m: Array in marks.get(lv, []):
			var c: Vector2i = m[0]
			if not g.inside(c):
				continue
			var ri := of[g.index(c)]
			var sign: Array = m[1]
			if ri >= 0 and (not best.has(ri) or int(sign[1]) < int(best[ri][1])):
				best[ri] = sign
		for ri: int in best:
			if HOME_KINDS.has(int(best[ri][0])):
				homes[int(map["rooms"][ri]["building"])] = true
		found[lv] = [map, best]
	var nth: Dictionary = {}  # 건물 × 8 + 갈래 -> 지금까지 칠한 방 수
	for lv: int in found:
		var g: FieldGrid = levels[lv]
		var map: Dictionary = found[lv][0]
		var best: Dictionary = found[lv][1]
		var ch: int = CHANNEL[lv]
		for ri in range(map["rooms"].size()):
			var room: Dictionary = map["rooms"][ri]
			var b := int(room["building"])
			var cls := int(best[ri][0]) if best.has(ri) else 0
			if not homes.has(b):
				cls = cls if HOME_KINDS.has(cls) else 0
			elif cls == 0 and lv >= 0 and _hall(g, room["cells"]):
				# 복도 벽지·나무 허리는 땅 위 층만: 지하의 가구 없는 통로는 받지 않는다.
				cls = HALL
			if cls == 0:
				continue
			var code := code_for(b, cls, region, int(nth.get(b * 8 + cls, 0)))
			nth[b * 8 + cls] = int(nth.get(b * 8 + cls, 0)) + 1
			for c: Vector2i in room["cells"]:
				bytes[(c.y * w * 2 + c.x) * 4 + ch] = code
	for rug: Variant in data.get("rugs", []):
		if not rug is Dictionary or not CHANNEL.has(int(rug.get("level", 0))) or not rug.get("rect") is Rect2i:
			continue
		var ch: int = CHANNEL[int(rug.get("level", 0))]
		var rr: Rect2i = rug["rect"]
		for y in range(maxi(rr.position.y, 0), mini(rr.end.y, h)):
			for x in range(maxi(rr.position.x, 0), mini(rr.end.x, w)):
				bytes[(y * w * 2 + w + x) * 4 + ch] = clampi(int(rug.get("look", 1)), 1, 255)
	return Image.create_from_data(w * 2, h, false, Image.FORMAT_RGBA8, bytes)


static func _mark(marks: Dictionary, lv: int, cell: Vector2i, sign: Array) -> void:
	if not marks.has(lv):
		marks[lv] = []
	marks[lv].append([cell, sign])


## 가구 없는 살림집 방이 복도인가: 짧은 변이 2칸 이하이거나 문이 셋 이상 난 방.
static func _hall(g: FieldGrid, cells: Array) -> bool:
	if cells.is_empty():
		return false
	var lo: Vector2i = cells[0]
	var hi: Vector2i = cells[0]
	var inside: Dictionary = {}
	for c: Vector2i in cells:
		lo = lo.min(c)
		hi = hi.max(c)
		inside[c] = true
	var doors: Dictionary = {}
	for c: Vector2i in cells:
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if g.doors.has(c + d) and not inside.has(c + d):
				doors[c + d] = true
	return mini(hi.x - lo.x + 1, hi.y - lo.y + 1) <= 2 or doors.size() >= 3
