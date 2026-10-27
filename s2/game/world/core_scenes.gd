extends RefCounted
## 코어 장면(결정 426 D②): 드문 재료 코어는 장소에 고정된 장면에서 얻는다. 화물역·공장·탄광 지도마다
## 기계 건물 하나에 멈춘 기계 하나를 둔다. 자리는 지도로 정해져 늘 같고(「그 장소에 가야 한다」),
## 그 안에 코어가 남았는지는 판마다 굴린다. 보이는 코어는 정차를 넘는 덱(결정 474 S3·442, loot_dress.gd
## DECKS core_scene)으로, 코어 장면이 있는 정차 7곳 중 정확히 1곳에 남는다 — 한 판(24구간)에 장면 정차가
## 평균 7.25곳이라, 코어를 하나도 못 보는 판이 32%에서 8.5%로 준다(s3-link 셈). 새 묶음의 첫 장은
## 예전처럼 0.15로 굴려, 덱 상태 없이 굴리면 지금과 같다.
##
## 확률은 S1 장소 부산물(`s1/src/game/domestic/data.ts` BYPRODUCT core 0.15)이다. 탄광(들름)은 S1 표에
## 없지만 코디네이터 판단(10-25)으로 갱도 머리의 권양기에 같은 값을 쓴다. 기관 전문가의
## 몫(×2, field_unified 3장 「전문가 동행」 기관 줄)은 미리 같이 뽑아 둔 「숨은 코어」다. 뜯긴 기계와
## 똑같이 보이고 그 사람이 와야 알아본다. S2에는 기관 전문가가 아직 없어서, 숨은 코어를 들여다보면
## 영수증에 한 줄(coreHint)만 남는다. 떼는 데 30초, 보통 소리(같은 줄).
##
## 고개의 제설기 코어(결정 188)는 field_actions.gd 그대로이고, 코어 셈(CORE_ITEMS)에 같이 든다.
## 필드 영수증은 아직 id를 받지 않아(set_ids 없음) 코어는 items.gained로 간다. 영수증이 id를 받으면
## count(gained)를 extras.coreCount에 넣는다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")
const S = FieldGrid.Solid
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

const SPOT: String = "core_scene"
## 코어가 보이게 남았다 / 숨어 있다(기관 전문가 몫). 나머지는 이미 뜯긴 기계다.
const P_CORE: float = 0.15
const P_HIDDEN: float = 0.15
const DETACH_SECONDS: float = 30.0
const WEIGHT: float = 4.0        # 제설기 코어와 같다(결정 194)
const CORE_ITEMS: Array[String] = ["core_engine", "core_electric", "plow_core"]
const NAMES: Dictionary = {"core_engine": "기관 코어", "core_electric": "전기 코어"}

## 장소 종류마다 차례대로 찾는 건물 이름 낱말 → [장면 이름, 코어]. 처음 맞는 건물 하나에 둔다.
const SCENES: Dictionary = {
	"freight": [
		["기관고", "부서진 기관차", "core_engine"],
		["수선고", "부서진 기관차", "core_engine"],
		["동력실", "멈춘 증기 기관", "core_engine"],
		["엔진실", "멈춘 증기 기관", "core_engine"],
		["분해동", "뜯다 만 기관차", "core_engine"],
		["기계 수리", "뜯다 만 기관", "core_engine"],
		["정비", "뜯다 만 기관", "core_engine"],
		["냉동 기계", "멈춘 냉동기", "core_electric"],
		["냉장", "멈춘 냉동기", "core_electric"],
		["변전", "멈춘 변압기", "core_electric"],
	],
	"factory": [
		["터빈", "멈춘 발전기", "core_electric"],
		["제어실", "타 버린 배전반", "core_electric"],
		["엔진실", "멈춘 증기 기관", "core_engine"],
		["분해동", "뜯다 만 기관차", "core_engine"],
		["기계 수리", "뜯다 만 기관", "core_engine"],
		["정비", "뜯다 만 기관", "core_engine"],
		["변전", "멈춘 변압기", "core_electric"],
	],
	# 탄광은 지도마다 갱도 건물 하나: 그 땅층(갱도 머리)에 갱차를 올리던 권양기.
	"mine": [
		["권양", "멈춘 권양기", "core_engine"],
		["갱도", "멈춘 권양기", "core_engine"],
	],
}


## 장면을 놓고 이번 판의 코어를 굴린다. 돌려주는 값은 영수증 placeState의 coreScene(없으면 빈 사전).
## deck: 정차를 넘는 덱 상태(LootDress.dress가 돌려준 loot_deck) — 장면이 있는 정차만 한 장 넘기고 고친다.
static func apply(data: Dictionary, dice_seed: int, deck: Dictionary = {}) -> Dictionary:
	var spot := place(data)
	if spot.is_empty():
		return {}
	spot["state"] = roll(dice_seed, deck)
	return {"name": spot["name"], "item": spot["item"], "state": spot["state"]}


## "core"(보이는 코어) / "hidden"(숨은 코어) / "bare"(뜯긴 기계). 같은 씨앗·같은 덱은 같은 결과.
## 보이는 코어는 덱이 남긴 확률로(새 묶음의 첫 장은 P_CORE), 숨은 코어는 보이는 코어가 안 나온
## 나머지에서 제 몫(정차마다 P_HIDDEN)이 나오게 같은 주사위를 다시 읽는다. 덱 상태가 없으면 지금과
## 같다(0.15 / 다음 0.15 / 나머지). 숨은 코어는 진행을 막지 않아(영수증 한 줄) 덱에 넣지 않는다.
static func roll(dice_seed: int, deck: Dictionary = {}) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = dice_seed
	var r := rng.randf()
	var chance := LootDress.deck_chance(deck, "core_scene", P_CORE)
	LootDress.deck_count(deck, "core_scene", r < chance)
	if r < chance:
		return "core"
	return "hidden" if (r - chance) / (1.0 - chance) < P_HIDDEN / (1.0 - P_CORE) else "bare"


## 장면 자리: 장소 종류의 낱말 차례로 건물을 고르고, 그 건물 땅층에서 열차부터 걸어 닿는 가장 깊은 칸.
## 칸은 벽에 붙고, 문·창·계단 곁이 아니며, 가구·상자·다른 지점이 없다. 지점은 땅층에만 있다.
static func place(data: Dictionary) -> Dictionary:
	var rows: Array = SCENES.get(String(data.get("place_kind", "")), [])
	var levels: Dictionary = data.get("levels", {})
	if rows.is_empty() or not levels.has(0):
		return {}
	var g: FieldGrid = levels[0]
	var steps := _steps_from_train(data, g)
	for row: Array in rows:
		for b: Dictionary in data.get("buildings", []):
			if not String(b.get("name", "")).contains(String(row[0])):
				continue
			var c := _deepest(data, g, int(b["id"]), steps)
			if c.x < 0:
				continue
			var spot := {"kind": "core", "name": row[1], "cell": c, "item": row[2], "building": int(b["id"]), "state": "bare", "face": face(g, c)}
			data["spots"][SPOT] = spot
			return spot
	return {}


## 코어 셈: 얻은 물건 id 목록 가운데 코어.
static func count(items: Array) -> int:
	var n := 0
	for id: Variant in items:
		if CORE_ITEMS.has(String(id)):
			n += 1
	return n


static func _deepest(data: Dictionary, g: FieldGrid, b: int, steps: Dictionary) -> Vector2i:
	var taken := _taken(data)
	var best := Vector2i(-1, -1)
	var best_steps := -1
	for i in range(g.building.size()):
		if g.building[i] != b:
			continue
		var c := Vector2i(i % g.width, i / g.width)
		if not steps.has(c) or taken.has(c) or g.solid_at(c) != S.NONE or not _fits(g, c):
			continue
		var n: int = steps[c]
		if n > best_steps:
			best_steps = n
			best = c
	return best


## 기계가 보는 쪽: 붙은 벽의 반대(그림이 읽는다).
static func face(g: FieldGrid, c: Vector2i) -> Vector2i:
	for d: Vector2i in DIRS:
		if g.solid_at(c + d) == S.WALL:
			return -d
	return Vector2i(0, 1)


## 벽에 붙고(네 방향 가운데 벽 하나), 둘레 여덟 칸에 문·창이 없다.
static func _fits(g: FieldGrid, c: Vector2i) -> bool:
	var wall := false
	for d: Vector2i in DIRS:
		wall = wall or g.solid_at(c + d) == S.WALL
	if not wall:
		return false
	for y in range(-1, 2):
		for x in range(-1, 2):
			var n := c + Vector2i(x, y)
			if g.doors.has(n) or g.windows.has(n):
				return false
	return true


## 땅층에서 막힌 칸: 가구 둘레, 상자, 계단과 그 곁, 이미 있는 지점.
static func _taken(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for prop: Dictionary in data.get("props", []):
		if int(prop.get("level", 0)) == 0 and prop.get("rect") is Rect2i:
			var r: Rect2i = prop["rect"]
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					out[Vector2i(x, y)] = true
	for id: Variant in data.get("containers", {}):
		var box: Dictionary = data["containers"][id]
		if int(box.get("level", 0)) == 0:
			out[box["cell"]] = true
	for s: Dictionary in data.get("stairs", []):
		if int(s.get("low", 0)) == 0 or int(s.get("high", 0)) == 0:
			for y in range(-1, 2):
				for x in range(-1, 2):
					out[Vector2i(s["cell"]) + Vector2i(x, y)] = true
	for id: Variant in data.get("spots", {}):
		out[data["spots"][id]["cell"]] = true
	return out


## 열차 곁(타는 자리)에서 땅층을 걸어 몇 걸음인지. 잠긴 문은 지나지 않는다.
static func _steps_from_train(data: Dictionary, g: FieldGrid) -> Dictionary:
	var steps: Dictionary = {}
	var queue: Array[Vector2i] = []
	for rect: Rect2i in data.get("boarding", []):
		var r := rect.grow(1)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if not steps.has(c) and g.people_can_walk(c):
					steps[c] = 0
					queue.append(c)
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d: Vector2i in DIRS:
			var n := c + d
			if not steps.has(n) and g.people_can_walk(n):
				steps[n] = int(steps[c]) + 1
				queue.append(n)
	return steps
