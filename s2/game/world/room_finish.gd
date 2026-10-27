extends RefCounted
## 방 마감(결정 469 C3·477): 살림방 갈래마다 바닥 재질과 벽 칠을 집마다 굴려, 땅·건물 셰이더가
## 칸으로 읽는 그림 하나에 담는다(시야 그림 vis와 같은 길, filter_nearest).
## 방 갈래는 지도가 그 방에 놓은 가구로 읽는다(room_furnish가 방 이름·가구로 고른 묶음의 결과).
## 손으로 그린 지도(첫 정차)는 가구가 이름 붙은 물건 상자로만 있어 그 이름이 말하는 방으로 읽는다.
## 욕실·부엌·침실·거실 밖의 방은 0이라 지금 그림 그대로다.
## 층마다 채널 하나: 0층 R, 1층 G, 지하 B, 2층 A. 칸 값 = 갈래 + 8 × 판(0~2).
## 같은 집의 같은 갈래 방은 같은 판(한 집의 부엌은 한 마감), 집이 바뀌면 판이 굴러간다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")

const BED := 1
const KITCHEN := 2
const BATH := 3
const LIVING := 4
const VARIANTS := 3
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


## 지도 자료(levels·props)로 방 마감 그림. 첫 층 격자 크기.
static func build(data: Dictionary) -> Image:
	var levels: Dictionary = data.get("levels", {0: data["grid"]})
	var base: FieldGrid = levels.get(0, data["grid"])
	var w := base.width
	var h := base.height
	var bytes := PackedByteArray()
	bytes.resize(w * h * 4)
	bytes.fill(0)
	var signs := _signs()
	var marks: Dictionary = {}  # 층 -> [[칸, [갈래, 순위]], ...]
	for p: Variant in data.get("props", []):
		if not p is Dictionary or p.has("legacy_model") or not signs.has(String(p.get("kind", ""))) or not p.get("rect") is Rect2i:
			continue
		var r: Rect2i = p["rect"]
		_mark(marks, int(p.get("level", 0)), r.position + r.size / 2, signs[String(p["kind"])])
	for b: Variant in data.get("containers", {}).values():
		if not b is Dictionary or (b.has("furniture") and not b.get("object_legacy", false)) or not b.get("cell") is Vector2i:
			continue
		var said := LootDress.room_of_name(String(b.get("name", "")))
		if NAME_SIGNS.has(said):
			_mark(marks, int(b.get("level", 0)), b["cell"], NAME_SIGNS[said])
	for lv: int in levels:
		var g: FieldGrid = levels[lv]
		if not CHANNEL.has(lv) or not marks.has(lv) or g.width != w or g.height != h:
			continue
		var map := RoomFurnish.rooms_of(g)
		var of: PackedInt32Array = map["of"]
		var best: Dictionary = {}  # 방 번호 -> [갈래, 순위]
		for m: Array in marks[lv]:
			var c: Vector2i = m[0]
			if not g.inside(c):
				continue
			var ri := of[g.index(c)]
			var sign: Array = m[1]
			if ri >= 0 and (not best.has(ri) or int(sign[1]) < int(best[ri][1])):
				best[ri] = sign
		var ch: int = CHANNEL[lv]
		for ri: int in best:
			var room: Dictionary = map["rooms"][ri]
			var cls := int(best[ri][0])
			var code := cls + 8 * variant_for(int(room["building"]), cls)
			for c: Vector2i in room["cells"]:
				bytes[(c.y * w + c.x) * 4 + ch] = code
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)


static func _mark(marks: Dictionary, lv: int, cell: Vector2i, sign: Array) -> void:
	if not marks.has(lv):
		marks[lv] = []
	marks[lv].append([cell, sign])
