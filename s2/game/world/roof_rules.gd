extends RefCounted
## 옥상(docs/design/briefs/house_layout.md 6장, 결정 423): 평지붕 건물만, 도시 지도(주택가·관청·
## 병원·공장)마다 1~2곳. 고른 건물은 맨 위가 낮은 담을 두른 평지붕으로 그려지고(building_view),
## 그 위 한 층(맨 위층 + 1)에 걸을 수 있는 지붕 칸이 생긴다. 오르는 길은 맨 위층 방 안 천창의
## 접이 사다리 하나(6.1의 셋째 길)이고, 신호소 사다리 규칙을 그대로 쓴다(field_actions.gd).
## 사다리는 길 찾기가 건너뛰므로 망자는 오르지 못한다(6.1). 지붕 둘레 칸은 허공 그대로라
## 걸어서 떨어지지 않는다(6.3, 낮은 담).
##
## 지도 짓기에서 가구 규칙보다 먼저 돈다: 사다리 칸은 계단 칸이라 그 둘레를 가구가 비운다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## 옥상을 두는 지도 종류.
const KINDS: Dictionary = {"houses": true, "office": true, "hospital": true, "factory": true}
## 층 번호는 -1~2까지다(field_game.level_of). 지붕 층이 2를 넘지 않는 건물만.
const TOP_LEVEL_MAX: int = 2
## 옥상이 될 만큼 넓은 맨 위층(건물 칸 수). 둘째 옥상은 더 넓을 때만.
const MIN_TOP_CELLS: int = 120
const SECOND_MIN_CELLS: int = 200
const ROOFS_MAX: int = 2
## 오두막·헛간·차고처럼 지붕에 오를 까닭이 없는 건물.
const SKIP_WORDS: Array[String] = ["헛간", "차고", "온실", "정자", "사일로", "오두막", "움막", "광", "탑"]


## 옥상을 고르고 지붕 칸과 사다리를 지도 자료에 넣는다. 돌려주는 값과 data["rooftops"]:
## [{"building", "level"(지붕 층), "ladder"(칸), "cells"}].
static func plan(data: Dictionary) -> Array:
	data["rooftops"] = []
	if not KINDS.has(String(data.get("place_kind", ""))):
		return []
	var levels: Dictionary = data.get("levels", {})
	var names: Dictionary = {}
	for row: Variant in data.get("buildings", []):
		if row is Dictionary:
			names[int(row.get("id", -1))] = String(row.get("name", ""))
	var tops: Dictionary = {}  # 건물 -> [맨 위층, 그 층 칸 수]
	var lvs: Array = levels.keys()
	lvs.sort()
	for lv: int in lvs:
		if lv < 0:
			continue
		var g: FieldGrid = levels[lv]
		var count: Dictionary = {}
		for i in range(g.building.size()):
			var b := g.building[i]
			if b >= 0:
				count[b] = int(count.get(b, 0)) + 1
		for b: int in count:
			tops[b] = [lv, count[b]]
	var cands: Array = []
	for b: int in tops:
		var top: int = tops[b][0]
		if top + 1 > TOP_LEVEL_MAX or not levels.has(top + 1) or int(tops[b][1]) < MIN_TOP_CELLS:
			continue
		if _skipped(String(names.get(b, ""))):
			continue
		cands.append([b, top, int(tops[b][1])])
	cands.sort_custom(func(p: Array, q: Array) -> bool: return p[2] > q[2] or (p[2] == q[2] and p[0] < q[0]))
	var out: Array = []
	for row: Array in cands:
		if out.size() >= ROOFS_MAX or (out.size() == 1 and int(row[2]) < SECOND_MIN_CELLS):
			break
		var made := _make(data, int(row[0]), int(row[1]))
		if not made.is_empty():
			out.append(made)
	data["rooftops"] = out
	return out


static func _skipped(name: String) -> bool:
	for w: String in SKIP_WORDS:
		if w == "광":
			if Array(name.split(" ")).has("광"):
				return true
		elif name.find(w) >= 0:
			return true
	return false


## 건물 b의 맨 위층(top) 위를 지붕 칸으로(바깥벽 둘레는 빼고 안벽 위는 넣어 한 판으로 잇는다),
## 맨 위층 방 하나에 천창 사다리.
static func _make(data: Dictionary, b: int, top: int) -> Dictionary:
	var levels: Dictionary = data["levels"]
	var g: FieldGrid = levels[top]
	var roof: FieldGrid = levels[top + 1]
	var cells: Array[Vector2i] = []
	for i in range(g.building.size()):
		if g.building[i] != b:
			continue
		var c := Vector2i(i % g.width, i / g.width)
		var ring := false
		for y in range(-1, 2):
			for x in range(-1, 2):
				var n := c + Vector2i(x, y)
				ring = ring or not g.inside(n) or g.building_at(n) != b
		if not ring and roof.solid_at(c) == S.AIR and roof.building_at(c) < 0:
			cells.append(c)
	if cells.size() < MIN_TOP_CELLS / 2:
		return {}
	var stairs_here: Dictionary = {}
	for st: Dictionary in data.get("stairs", []):
		stairs_here[st["cell"]] = true
	var ladder := _ladder_cell(g, cells, stairs_here)
	if ladder.x < 0:
		return {}
	for c in cells:
		roof.set_solid(c, S.NONE)
	data["stairs"].append({"cell": ladder, "low": top, "high": top + 1, "ladder": true, "roof": b})
	return {"building": b, "level": top + 1, "ladder": ladder, "cells": cells.size()}


## 천창 자리: 맨 위층 빈 칸 가운데 한 변만 벽에 붙고(사다리를 벽에 기댄다) 맞은편이 비었으며,
## 둘레 두 칸 안에 문·창·계단이 없는 칸. 칸 차례로 첫 것.
static func _ladder_cell(g: FieldGrid, cells: Array[Vector2i], stairs: Dictionary) -> Vector2i:
	var mine: Dictionary = {}
	for c in cells:
		mine[c] = true
	var sorted := cells.duplicate()
	sorted.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return p.y < q.y or (p.y == q.y and p.x < q.x))
	for c: Vector2i in sorted:
		if g.solid_at(c) != S.NONE or stairs.has(c):
			continue
		var walls := 0
		var back := Vector2i.ZERO
		for d in DIRS:
			if g.solid_at(c + d) == S.WALL:
				walls += 1
				back = d
		if walls != 1 or not mine.has(c - back) or g.solid_at(c - back) != S.NONE:
			continue
		var clear := true
		for y in range(-2, 3):
			for x in range(-2, 3):
				var n := c + Vector2i(x, y)
				if g.doors.has(n) or g.windows.has(n) or stairs.has(n):
					clear = false
		if clear:
			return c
	return Vector2i(-1, -1)


## 사다리를 기댄 벽 쪽(천창 칸에서 벽 칸으로). 없으면 ZERO.
static func wall_side(g: FieldGrid, c: Vector2i) -> Vector2i:
	for d in DIRS:
		if g.solid_at(c + d) == S.WALL:
			return d
	return Vector2i.ZERO
