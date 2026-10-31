extends RefCounted
## 참고 화면 마당 셈(10-30). 기존 줄·상자·실내는 두고 바깥 소품만 덧붙인다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")
const PropKinds = preload("res://game/world/prop_kinds.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const LOT: int = 5
const TARGET_PER_100: float = 6.5
const MAX_PATH_TRIES: int = 12
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
## props_field 장부의 footprint_m / bounds_godot를 올림한 칸 크기. 긴 축은 facing 0의 X.
const SIZES: Dictionary = {
	"bush_juniper": Vector2i(1, 1), "dry_bush": Vector2i(2, 2),
	"bush_dry": Vector2i(2, 2), "fern_dry": Vector2i(2, 2), "dry_grass": Vector2i(2, 2),
	"garden_bed": Vector2i(4, 2), "herb_bed": Vector2i(4, 2),
	"boulder": Vector2i(2, 2), "stump_cluster": Vector2i(4, 4),
	"firewood_pile": Vector2i(2, 1), "water_barrel": Vector2i(2, 2),
	"laundry_line": Vector2i(6, 1), "bench": Vector2i(3, 1),
}
const LABELS: Dictionary = {
	"bush_juniper": "향나무 덤불", "dry_bush": "마른 잔가지", "bush_dry": "마른 덤불",
	"fern_dry": "마른 고사리", "dry_grass": "마른 풀", "garden_bed": "텃밭",
	"herb_bed": "약초 꽃밭", "boulder": "바위", "stump_cluster": "그루터기",
	"firewood_pile": "장작", "water_barrel": "물통", "laundry_line": "빈 빨랫줄", "bench": "벤치",
}
const LOW_KINDS: Array[String] = ["boulder", "firewood_pile", "water_barrel", "laundry_line", "bench"]
## 지금 모형이 결함으로 읽혀(텃밭은 흰 통, 빨랫줄은 굵은 기둥 둘과 땅 판) 집 차리기에서 꺼 둔 갈래.
## 모형이 바뀌면 켠다(_place 자체는 그대로 쓸 수 있다).
const ROLES_OFF: Array[String] = ["garden", "laundry"]
## 모형 발(가장 낮은 곳 꼭짓점 상자)이 모형 전체를 덮어 접지 그늘이 눈 위에 네모 판으로 보이는 갈래:
## 줄에 shade=false를 달아 map_view가 그늘을 깔지 않게 한다.
const NO_SHADE_KINDS: Array[String] = ["dry_grass", "stump_cluster"]


static func _roll(seed_value: int, purpose: int, ordinal: int = 0) -> int:
	return int(rand_from_seed(hash([seed_value, purpose, ordinal]))[0])


static func _unit(seed_value: int, purpose: int, ordinal: int = 0) -> float:
	return float(_roll(seed_value, purpose, ordinal) % 1000) / 1000.0


## 네모에 들어 있으면 0, 밖이면 가장 가까운 건물 칸까지의 4이웃 거리.
static func _distance(cell: Vector2i, rect: Rect2i) -> int:
	return maxi(maxi(rect.position.x - cell.x, cell.x - rect.end.x + 1), 0) \
		+ maxi(maxi(rect.position.y - cell.y, cell.y - rect.end.y + 1), 0)


static func _rect_cells(rect: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row_y in range(rect.position.y, rect.end.y):
		for col_x in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(col_x, row_y))
	return cells


## 문 칸 옆의 건물 밖 칸 모두. 내부 문·윗층 문은 이 목록에 들어오지 않는다.
static func door_fronts(grid: FieldGrid) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var door_cells: Array = grid.doors.keys()
	door_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return grid.index(a) < grid.index(b))
	for door: Vector2i in door_cells:
		for direction: Vector2i in DIRS:
			var outside: Vector2i = door + direction
			if grid.inside(outside) and grid.building_at(outside) < 0:
				out.append({"door": door, "cell": outside, "normal": direction,
					"building": int(grid.doors[door].get("building", grid.building_at(door)))})
	return out


static func forbidden_cells(data: Dictionary) -> Dictionary:
	var grid: FieldGrid = data["grid"]
	var forbidden: Dictionary = {}
	for front: Dictionary in door_fronts(grid):
		var normal: Vector2i = front["normal"]
		var tangent: Vector2i = Vector2i(-normal.y, normal.x)
		# 문 바깥 칸 + 앞 두 칸, 각 줄의 양옆도 보호하는 폭 3 / 깊이 3 띠.
		for depth in range(3):
			for lateral in range(-1, 2):
				forbidden[front["cell"] + normal * depth + tangent * lateral] = true
	# 지도 밖 철길도 안쪽 세 칸에 영향을 주므로 원본 표에는 폭 3의 여백을 둔다.
	var rail_bounds: Rect2i = Rect2i(-3, -3, grid.width + 6, grid.height + 6)
	var rail_width: int = rail_bounds.size.x
	var rail_mask: PackedByteArray = PackedByteArray()
	rail_mask.resize(rail_width * rail_bounds.size.y)
	for rail_y in range(grid.height):
		for rail_x in range(grid.width):
			if grid.floor[rail_y * grid.width + rail_x] in [F.RAIL, F.PLATFORM]:
				rail_mask[(rail_y + 3) * rail_width + rail_x + 3] = 1
	for crossing: Dictionary in data.get("crossings", []):
		for crossing_cell: Vector2i in crossing.get("cells", []):
			if rail_bounds.has_point(crossing_cell):
				rail_mask[(crossing_cell.y + 3) * rail_width + crossing_cell.x + 3] = 1
	for rail_rect_key: String in ["platform", "train"]:
		if data.get(rail_rect_key) is Rect2i:
			var rail_rect: Rect2i = data[rail_rect_key].intersection(rail_bounds)
			for rect_y in range(rail_rect.position.y, rail_rect.end.y):
				for rect_x in range(rail_rect.position.x, rail_rect.end.x):
					rail_mask[(rect_y + 3) * rail_width + rect_x + 3] = 1
	# 가로·세로 폭 7 창의 합. 결과를 읽는 마당 칸은 모두 지도 안이다.
	var horizontal: PackedByteArray = PackedByteArray()
	horizontal.resize(grid.width * rail_bounds.size.y)
	for padded_y in range(rail_bounds.size.y):
		var row_offset: int = padded_y * rail_width
		var horizontal_count: int = 0
		for initial_x in range(6):
			horizontal_count += rail_mask[row_offset + initial_x]
		for expanded_x in range(grid.width):
			horizontal_count += rail_mask[row_offset + expanded_x + 6]
			horizontal[padded_y * grid.width + expanded_x] = int(horizontal_count > 0)
			horizontal_count -= rail_mask[row_offset + expanded_x]
	for protected_x in range(grid.width):
		var vertical_count: int = 0
		for initial_y in range(6):
			vertical_count += horizontal[initial_y * grid.width + protected_x]
		for protected_y in range(grid.height):
			vertical_count += horizontal[(protected_y + 6) * grid.width + protected_x]
			if vertical_count > 0:
				forbidden[Vector2i(protected_x, protected_y)] = true
			vertical_count -= horizontal[protected_y * grid.width + protected_x]
	# 새 막힘 때문에 등장 위치를 런타임에서 옮기는 일이 없도록 기존 등장 칸도 비워 둔다.
	for spawn_list: Variant in data.get("spawns", {}).values():
		if spawn_list is Array:
			for spawn_cell: Variant in spawn_list:
				if spawn_cell is Vector2i:
					forbidden[spawn_cell] = true
	return forbidden


static func _homes(data: Dictionary) -> Array[Dictionary]:
	var levels: Dictionary = data.get("levels", {0: data["grid"]})
	var classes: Dictionary = data.get("density_classes", {})
	var selected: Dictionary = {}
	for class_key: String in classes:
		if classes[class_key] != "bed":
			continue
		var parts: PackedStringArray = class_key.split(":")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			continue
		var level: int = int(parts[0])
		var room_index: int = int(parts[1])
		if level < 0 or not levels.has(level):
			continue
		var level_grid: FieldGrid = levels[level]
		var room_map: Dictionary = RoomFurnish._rooms(data, level, level_grid)
		var rooms: Array = room_map["rooms"]
		if room_index >= 0 and room_index < rooms.size():
			selected[int(rooms[room_index]["building"])] = true
	var homes: Array[Dictionary] = []
	var buildings: Array = data.get("buildings", [])
	for building_index in range(buildings.size()):
		var building: Dictionary = buildings[building_index]
		var building_id: int = int(building.get("id", building_index))
		if selected.has(building_id) and building.get("rect") is Rect2i:
			homes.append({"building": building_id, "rect": building["rect"],
				"name": String(building.get("name", "살림집")), "cells": [], "front": Vector2i.DOWN})
	homes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["building"] < b["building"])
	return homes


static func _owner(cell: Vector2i, homes: Array[Dictionary]) -> int:
	var owner: int = -1
	var best_distance: int = 2147483647
	for home: Dictionary in homes:
		var home_rect: Rect2i = home["rect"]
		if not home_rect.grow(LOT).has_point(cell):
			continue
		var distance: int = _distance(cell, home_rect)
		if distance < best_distance:
			best_distance = distance
			owner = int(home["building"])
	return owner


## 작은 건물 번호부터 거리를 갱신하고, 같은 거리에서는 먼저 정한 주인을 둔다.
static func _owner_map(grid: FieldGrid, homes: Array[Dictionary]) -> PackedInt32Array:
	var owners: PackedInt32Array = PackedInt32Array()
	owners.resize(grid.width * grid.height)
	owners.fill(-1)
	var distances: PackedInt32Array = PackedInt32Array()
	distances.resize(owners.size())
	distances.fill(2147483647)
	var bounds: Rect2i = Rect2i(0, 0, grid.width, grid.height)
	for home: Dictionary in homes:
		var house: Rect2i = home["rect"]
		var lot: Rect2i = house.grow(LOT).intersection(bounds)
		for lot_y in range(lot.position.y, lot.end.y):
			for lot_x in range(lot.position.x, lot.end.x):
				var cell_index: int = lot_y * grid.width + lot_x
				var distance: int = _distance(Vector2i(lot_x, lot_y), house)
				if distance < distances[cell_index]:
					distances[cell_index] = distance
					owners[cell_index] = int(home["building"])
	return owners


## 장애물을 무시한 ROAD까지의 L1 거리. 길이 없으면 기존 비교의 최댓값 그대로다.
static func _road_distances(grid: FieldGrid) -> PackedInt32Array:
	var distances: PackedInt32Array = PackedInt32Array()
	distances.resize(grid.width * grid.height)
	distances.fill(2147483647)
	for forward_index in range(distances.size()):
		if grid.floor[forward_index] == F.ROAD:
			distances[forward_index] = 0
		if forward_index % grid.width > 0:
			distances[forward_index] = mini(distances[forward_index], distances[forward_index - 1] + 1)
		if forward_index >= grid.width:
			distances[forward_index] = mini(distances[forward_index], distances[forward_index - grid.width] + 1)
	for backward_index in range(distances.size() - 1, -1, -1):
		if backward_index % grid.width < grid.width - 1:
			distances[backward_index] = mini(distances[backward_index], distances[backward_index + 1] + 1)
		if backward_index + grid.width < distances.size():
			distances[backward_index] = mini(distances[backward_index], distances[backward_index + grid.width] + 1)
	return distances


## 차린 뒤에도 원래의 배치 가능 면적을 복원해 재기 위한 읽기 전용 조사.
## region은 소품에 가린 칸도 포함(기존 줄을 세는 용도), owners는 원래 빈 마당 칸.
static func survey(data: Dictionary) -> Dictionary:
	var grid: FieldGrid = data["grid"]
	var homes: Array[Dictionary] = _homes(data)
	if homes.is_empty():
		return {"homes": homes, "owners": {}, "region": {}, "forbidden": {}, "fronts": []}
	var taken: Dictionary = {}
	var yard_low: Dictionary = {}
	for prop: Dictionary in data.get("props", []):
		if int(prop.get("level", 0)) != 0:
			continue
		if prop.get("yard", false):
			for low_cell: Vector2i in blocking_cells(prop):
				yard_low[low_cell] = true
		else:
			for prop_cell: Vector2i in _rect_cells(prop["rect"]):
				taken[prop_cell] = true
	var boxes: Variant = data.get("containers", {})
	for box: Dictionary in (boxes.values() if boxes is Dictionary else boxes):
		if int(box.get("level", 0)) == 0 and box.get("cell") is Vector2i:
			taken[box["cell"]] = true
	for tree: Vector2i in data.get("trees", []):
		taken[tree] = true
	var owners: Dictionary = {}
	var region: Dictionary = {}
	var owner_map: PackedInt32Array = _owner_map(grid, homes)
	var by_id: Dictionary = {}
	for indexed_home: Dictionary in homes:
		by_id[indexed_home["building"]] = indexed_home
	for scan_y in range(grid.height):
		for scan_x in range(grid.width):
			var cell_index: int = scan_y * grid.width + scan_x
			var floor_kind: int = grid.floor[cell_index]
			if grid.building[cell_index] >= 0 or floor_kind in [F.ROAD, F.RAIL, F.PLATFORM, F.ICE, F.DEEP_SNOW]:
				continue
			var owner: int = owner_map[cell_index]
			if owner < 0:
				continue
			var cell: Vector2i = Vector2i(scan_x, scan_y)
			region[cell] = owner
			if taken.has(cell) or (grid.solid[cell_index] != S.NONE and not yard_low.has(cell)):
				continue
			owners[cell] = owner
			by_id[owner]["cells"].append(cell)
	var fronts: Array[Dictionary] = door_fronts(grid)
	var road_distances: PackedInt32Array = _road_distances(grid)
	for oriented_home: Dictionary in homes:
		var best_road: int = 2147483647
		for home_front: Dictionary in fronts:
			if int(home_front["building"]) != int(oriented_home["building"]):
				continue
			var door_cell: Vector2i = home_front["door"]
			var road_distance: int = road_distances[grid.index(door_cell)]
			if road_distance < best_road:
				best_road = road_distance
				oriented_home["front"] = home_front["normal"]
	return {"homes": homes, "owners": owners, "region": region, "forbidden": forbidden_cells(data), "fronts": fronts}


static func _is_front(cell: Vector2i, home: Dictionary) -> bool:
	var rect: Rect2i = home["rect"]
	var normal: Vector2i = home["front"]
	var doubled: Vector2i = cell * 2 - (rect.position * 2 + rect.size - Vector2i.ONE)
	return doubled.x * normal.x + doubled.y * normal.y >= 0


static func _back(rect: Rect2i, house: Rect2i) -> Vector2i:
	if rect.end.y == house.position.y and rect.position.x < house.end.x and rect.end.x > house.position.x:
		return Vector2i.DOWN
	if rect.position.y == house.end.y and rect.position.x < house.end.x and rect.end.x > house.position.x:
		return Vector2i.UP
	if rect.end.x == house.position.x and rect.position.y < house.end.y and rect.end.y > house.position.y:
		return Vector2i.RIGHT
	if rect.position.x == house.end.x and rect.position.y < house.end.y and rect.end.y > house.position.y:
		return Vector2i.LEFT
	return Vector2i.ZERO


static func _edge(cell: Vector2i, home: Dictionary, fence_cells: Dictionary) -> bool:
	var outer: Rect2i = home["rect"].grow(LOT)
	if cell.x in [outer.position.x, outer.end.x - 1] or cell.y in [outer.position.y, outer.end.y - 1]:
		return true
	for direction: Vector2i in DIRS:
		if fence_cells.has(cell + direction):
			return true
	return false


static func _fences(data: Dictionary) -> Dictionary:
	var cells: Dictionary = {}
	for prop: Dictionary in data.get("props", []):
		if int(prop.get("level", 0)) == 0 and prop.get("kind", "") in ["plank_fence", "fieldstone_wall"]:
			for cell: Vector2i in _rect_cells(prop["rect"]):
				cells[cell] = true
	return cells


## 집 네모·울타리·주인 칸은 차리는 동안 바뀌지 않는다.
static func _cache_home(home: Dictionary, state: Dictionary) -> void:
	var backs: Dictionary = {}
	var edges: Dictionary = {}
	for cell: Vector2i in home["cells"]:
		backs[cell] = _back(Rect2i(cell, Vector2i.ONE), home["rect"])
		edges[cell] = _edge(cell, home, state["fences"])
	state["back"] = backs
	state["edge"] = edges
	# 이 단계의 갈래에서 크기를 읽고, 같은 크기의 목록은 집마다 한 번만 만든다.
	var role_sizes: Dictionary = {
		"wall": [SIZES["bush_juniper"], SIZES["dry_bush"], SIZES["bush_dry"], SIZES["fern_dry"]],
		"edge": [SIZES["dry_bush"], SIZES["dry_grass"]],
	}
	var anchors: Dictionary = {}
	for role: String in role_sizes:
		var by_size: Dictionary = {}
		for size: Vector2i in role_sizes[role]:
			if by_size.has(size):
				continue
			var matching: Array[Vector2i] = []
			var rotated_size: Vector2i = Vector2i(size.y, size.x)
			for anchor: Vector2i in home["cells"]:
				if role == "wall":
					if _can_touch_house(anchor, size, home["rect"]) \
							or _can_touch_house(anchor, rotated_size, home["rect"]):
						matching.append(anchor)
				elif _can_cover_edge(anchor, size, edges) \
						or (rotated_size != size and _can_cover_edge(anchor, rotated_size, edges)):
					matching.append(anchor)
			by_size[size] = matching
		anchors[role] = by_size
	state["anchors"] = anchors


## edge의 _fits가 참이면 실제로 굴린 방향의 네모 안에는 반드시 가장자리 칸이 있다.
static func _can_cover_edge(anchor: Vector2i, size: Vector2i, edges: Dictionary) -> bool:
	for edge_y in range(anchor.y, anchor.y + size.y):
		for edge_x in range(anchor.x, anchor.x + size.x):
			if edges.get(Vector2i(edge_x, edge_y), false):
				return true
	return false


## _back과 같은 접촉 조건. facing을 굴리기 전에 두 크기 모두 불가능할 때만 거른다.
static func _can_touch_house(anchor: Vector2i, size: Vector2i, house: Rect2i) -> bool:
	var end_x: int = anchor.x + size.x
	var end_y: int = anchor.y + size.y
	return ((end_y == house.position.y or anchor.y == house.end.y) \
			and anchor.x < house.end.x and end_x > house.position.x) \
		or ((end_x == house.position.x or anchor.x == house.end.x) \
			and anchor.y < house.end.y and end_y > house.position.y)


## 빨랫줄 전체는 예약하되 막힘은 두 끝의 기둥만.
static func blocking_cells(prop: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if prop.get("solid", "none") != "low":
		return out
	var rect: Rect2i = prop["rect"]
	if prop["kind"] == "laundry_line":
		out.append(rect.position)
		out.append(rect.end - Vector2i.ONE)
		return out
	return _rect_cells(rect)


## 경로 캐시와 별도로 NONE·DOOR만 통과하는 마당 검사용 표를 만든다.
static func _walk_mask(grid: FieldGrid) -> PackedByteArray:
	var walk: PackedByteArray = PackedByteArray()
	walk.resize(grid.width * grid.height)
	for cell_index in range(walk.size()):
		var solid_kind: int = grid.solid[cell_index]
		walk[cell_index] = int(solid_kind == S.NONE or solid_kind == S.DOOR)
	return walk


## 시작 칸·이웃 차례는 기존 BFS와 같다. 빌린 표의 임시 막힘은 반환 전에 복원한다.
static func _components(grid: FieldGrid, extra_blocked: Dictionary = {},
		walk: PackedByteArray = PackedByteArray()) -> PackedInt32Array:
	if walk.is_empty():
		walk = _walk_mask(grid)
	var restored: PackedInt32Array = PackedInt32Array()
	for blocked_cell: Vector2i in extra_blocked:
		if grid.inside(blocked_cell):
			var blocked_index: int = grid.index(blocked_cell)
			if walk[blocked_index] != 0:
				walk[blocked_index] = 0
				restored.append(blocked_index)
	var labels: PackedInt32Array = PackedInt32Array()
	labels.resize(grid.width * grid.height)
	labels.fill(-1)
	var queue: PackedInt32Array = PackedInt32Array()
	queue.resize(labels.size())
	var component: int = 0
	for start_index in range(labels.size()):
		if labels[start_index] >= 0 or walk[start_index] == 0:
			continue
		queue[0] = start_index
		labels[start_index] = component
		var head: int = 0
		var tail: int = 1
		while head < tail:
			var here: int = queue[head]
			head += 1
			var col_x: int = here % grid.width
			var neighbor: int = here + 1
			if col_x < grid.width - 1 and labels[neighbor] < 0 and walk[neighbor] != 0:
				labels[neighbor] = component
				queue[tail] = neighbor
				tail += 1
			neighbor = here - 1
			if col_x > 0 and labels[neighbor] < 0 and walk[neighbor] != 0:
				labels[neighbor] = component
				queue[tail] = neighbor
				tail += 1
			neighbor = here + grid.width
			if neighbor < labels.size() and labels[neighbor] < 0 and walk[neighbor] != 0:
				labels[neighbor] = component
				queue[tail] = neighbor
				tail += 1
			neighbor = here - grid.width
			if neighbor >= 0 and labels[neighbor] < 0 and walk[neighbor] != 0:
				labels[neighbor] = component
				queue[tail] = neighbor
				tail += 1
		component += 1
	for restored_index in restored:
		walk[restored_index] = 1
	return labels


## 각 문의 원래 성분에 속한 ROAD·끝 칸 전부를 보존한다(아무 길 하나만 남기는 검사가 아님).
static func path_guard(grid: FieldGrid, walk: PackedByteArray = PackedByteArray()) -> Dictionary:
	var labels: PackedInt32Array = _components(grid, {}, walk)
	var groups: Dictionary = {}
	for front: Dictionary in door_fronts(grid):
		var source: Vector2i = front["cell"]
		var component: int = labels[grid.index(source)]
		if component >= 0:
			if not groups.has(component):
				groups[component] = {"sources": [], "targets": []}
			groups[component]["sources"].append(source)
	for target_index in range(labels.size()):
		var target_group: int = labels[target_index]
		if not groups.has(target_group):
			continue
		var target_x: int = target_index % grid.width
		if grid.floor[target_index] == F.ROAD or target_x == 0 or target_x == grid.width - 1 \
				or target_index < grid.width or target_index >= labels.size() - grid.width:
			groups[target_group]["targets"].append(Vector2i(target_x, target_index / grid.width))
	return groups


## 둘레 여덟 칸(시계 차례 — 이웃끼리 4이웃으로 맞닿아 고리가 된다).
const RING: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]


## 막을 칸을 차례로 하나씩 막을 때, 칸마다 둘레 고리에서 걸을 수 있는 칸(NONE·DOOR, 앞서 막은 칸 빼고)이 고리를
## 따라 한 줄로 이어지면 참. 그러면 그 칸을 지나던 길은 고리로 돌아가므로 다른 어느 두 칸의 이어짐도 안 바뀐다
## (paths_preserved를 전체 지도로 다시 셀 필요 없음). 지도 끝 칸이거나 고리가 둘 이상으로 끊기면 거짓(전체 검사로).
static func ring_keeps_paths(grid: FieldGrid, block: Array[Vector2i]) -> bool:
	var done: Dictionary = {}
	for c: Vector2i in block:
		if c.x <= 0 or c.y <= 0 or c.x >= grid.width - 1 or c.y >= grid.height - 1:
			return false
		var walk: Array[bool] = []
		for d: Vector2i in RING:
			var n := c + d
			var s := grid.solid_at(n)
			walk.append((s == S.NONE or s == S.DOOR) and not done.has(n))
		var arcs := 0
		for i in range(RING.size()):
			if walk[i] and not walk[i - 1]:
				arcs += 1
		if arcs > 1:
			return false
		done[c] = true
	return true


static func paths_preserved(grid: FieldGrid, guard: Dictionary, blocked: Dictionary = {},
		walk: PackedByteArray = PackedByteArray()) -> bool:
	var labels: PackedInt32Array = _components(grid, blocked, walk)
	for group: Dictionary in guard.values():
		if group["targets"].is_empty():
			continue
		var first: Vector2i = group["sources"][0]
		var expected: int = labels[grid.index(first)]
		if expected < 0:
			return false
		for cell: Vector2i in group["sources"] + group["targets"]:
			if labels[grid.index(cell)] != expected:
				return false
	return true


static func _fits(rect: Rect2i, role: String, home: Dictionary, state: Dictionary) -> bool:
	var house: Rect2i = home["rect"]
	var back: Vector2i = _back(rect, house)
	if role in ["wall", "wood", "bench"] and back == Vector2i.ZERO:
		return false
	if role == "wood" and back == -Vector2i(home["front"]):
		return false
	if role == "corner":
		var corner_found: bool = false
		for corner: Vector2i in [house.position - Vector2i.ONE, Vector2i(house.end.x, house.position.y - 1),
				Vector2i(house.position.x - 1, house.end.y), house.end]:
			corner_found = corner_found or rect.has_point(corner)
		if not corner_found:
			return false
	var wall_coverage: int = 0
	var edge_coverage: int = 0
	for rect_y in range(rect.position.y, rect.end.y):
		for rect_x in range(rect.position.x, rect.end.x):
			var cell: Vector2i = Vector2i(rect_x, rect_y)
			if state["owners"].get(cell, -1) != home["building"] or state["forbidden"].has(cell) or state["used"].has(cell):
				return false
			if role in ["garden", "laundry"] and _is_front(cell, home):
				return false
			if role == "garden" and _distance(cell, house) < 2:
				return false
			if role == "bench":
				if not _is_front(cell, home):
					return false
				for front: Dictionary in state["fronts"]:
					var door: Vector2i = front["door"]
					if absi(cell.x - door.x) + absi(cell.y - door.y) < 3:
						return false
			if role == "wall":
				wall_coverage += int(state["back"][cell] != Vector2i.ZERO)
			elif role == "edge":
				edge_coverage += int(state["edge"][cell])
	if role == "wall" and wall_coverage > int(state["wall_left"]):
		return false
	if role == "edge" and (edge_coverage == 0 or edge_coverage > int(state["edge_left"])):
		return false
	return true


static func _place(data: Dictionary, home: Dictionary, state: Dictionary, kind: String, role: String,
		purpose: int, ordinal: int = 0) -> bool:
	if state["remaining"] <= 0 or not state["models"].get(kind, false):
		return false
	var grid: FieldGrid = data["grid"]
	var seed_value: int = home["seed"]
	var candidates: Array[Dictionary] = []
	var base_size: Vector2i = SIZES[kind]
	var anchors: Array = home["cells"]
	if role in ["wall", "edge"]:
		anchors = state["anchors"][role][base_size]
	for anchor: Vector2i in anchors:
		if state["owners"].get(anchor, -1) != home["building"] \
				or state["forbidden"].has(anchor) or state["used"].has(anchor):
			continue
		var anchor_index: int = grid.index(anchor)
		var size: Vector2i = base_size
		var facing: int = 0
		if role in ["wood", "bench"]:
			var anchor_back: Vector2i = state["back"][anchor]
			if anchor_back == Vector2i.ZERO:
				continue
			facing = RoomFurnish._facing_from_back(anchor_back)
		else:
			# 각 굴림은 입력 해시만 쓰므로 탈락 칸·덮어쓸 facing의 굴림을 생략해도 값은 같다.
			facing = _roll(seed_value, purpose + 1, anchor_index + ordinal * grid.width * grid.height) % 4
		if facing % 2 == 1:
			size = Vector2i(size.y, size.x)
		var rect: Rect2i = Rect2i(anchor, size)
		if not _fits(rect, role, home, state):
			continue
		var score: int = _roll(seed_value, purpose + 2, anchor_index + ordinal * grid.width * grid.height)
		var edge_priority: int = 0 if role == "rock" and state["edge"][anchor] else 1
		candidates.append({"rect": rect, "facing": facing, "score": score, "edge": edge_priority, "index": anchor_index})
	var attempts: int = 0
	while not candidates.is_empty():
		var best_index: int = 0
		var candidate: Dictionary = candidates[0]
		for candidate_index in range(1, candidates.size()):
			var challenger: Dictionary = candidates[candidate_index]
			if challenger["edge"] < candidate["edge"] \
					or (challenger["edge"] == candidate["edge"] and challenger["score"] < candidate["score"]) \
					or (challenger["edge"] == candidate["edge"] and challenger["score"] == candidate["score"] \
						and challenger["index"] < candidate["index"]):
				best_index = candidate_index
				candidate = challenger
		candidates.remove_at(best_index)
		var prop: Dictionary = {"kind": kind, "rect": candidate["rect"],
			"solid": "low" if LOW_KINDS.has(kind) else "none", "facing": candidate["facing"],
			"level": 0, "note": "%s 마당의 %s" % [home["name"], LABELS[kind]],
			"yard": true, "building": home["building"]}
		if NO_SHADE_KINDS.has(kind):
			prop["shade"] = false
		var block_cells: Array[Vector2i] = blocking_cells(prop)
		if not block_cells.is_empty():
			var blocked: Dictionary = {}
			for prospective: Vector2i in block_cells:
				blocked[prospective] = true
			attempts += 1
			if not ring_keeps_paths(grid, block_cells):
				state["full_checks"] += 1
				if not paths_preserved(grid, state["guard"], blocked, state["walk"]):
					if attempts >= MAX_PATH_TRIES:
						break
					continue
			for accepted: Vector2i in block_cells:
				grid.set_solid(accepted, S.LOW)
				state["walk"][grid.index(accepted)] = 0
			if kind == "laundry_line":
				for post: Vector2i in block_cells:
					data["low_blocks"].append(Rect2i(post, Vector2i.ONE))
			else:
				data["low_blocks"].append(prop["rect"])
		for reserved: Vector2i in _rect_cells(prop["rect"]):
			state["used"][reserved] = true
			if role == "wall":
				state["wall_left"] -= int(state["back"][reserved] != Vector2i.ZERO)
			elif role == "edge":
				state["edge_left"] -= int(state["edge"][reserved])
		data["props"].append(prop)
		state["remaining"] -= 1
		return true
	return false


## 겹친 기존 줄은 LOT 안 면적이 가장 큰 집에 한 번만 센다. 같으면 작은 건물 번호.
static func _row_owner(rect: Rect2i, region: Dictionary) -> int:
	var votes: Dictionary = {}
	for cell: Vector2i in _rect_cells(rect):
		if region.has(cell):
			var building: int = region[cell]
			votes[building] = int(votes.get(building, 0)) + 1
	var ids: Array = votes.keys()
	ids.sort()
	var owner: int = -1
	var most: int = 0
	for candidate_id: int in ids:
		if votes[candidate_id] > most:
			owner = candidate_id
			most = votes[candidate_id]
	return owner


static func census(data: Dictionary, surveyed: Dictionary = {}) -> Dictionary:
	var area: Dictionary = survey(data) if surveyed.is_empty() else surveyed
	var per_home: Dictionary = {}
	for home: Dictionary in area["homes"]:
		per_home[home["building"]] = {"old": 0, "new": 0, "kinds": {}}
	var kinds: Dictionary = {}
	var covered: Dictionary = {}
	var old_rows: int = 0
	var new_rows: int = 0
	var blocking: int = 0
	for prop: Dictionary in data.get("props", []):
		if int(prop.get("level", 0)) != 0:
			continue
		var rect: Rect2i = prop["rect"]
		for prop_cell: Vector2i in _rect_cells(rect):
			covered[prop_cell] = true
		var owner: int = int(prop["building"]) if prop.get("yard", false) else _row_owner(rect, area["region"])
		if not per_home.has(owner):
			continue
		var kind: String = String(prop["kind"])
		var is_new: bool = bool(prop.get("yard", false))
		per_home[owner]["new" if is_new else "old"] += 1
		per_home[owner]["kinds"][kind] = true
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		new_rows += int(is_new)
		old_rows += int(not is_new)
		blocking += int(prop.get("solid", "none") == "low")
	for tree: Vector2i in data.get("trees", []):
		if not covered.has(tree) and area["region"].has(tree):
			var tree_owner: int = area["region"][tree]
			per_home[tree_owner]["old"] += 1
			per_home[tree_owner]["kinds"]["bare_tree"] = true
			kinds["bare_tree"] = int(kinds.get("bare_tree", 0)) + 1
			old_rows += 1
	var variety: Array[int] = []
	for counts: Dictionary in per_home.values():
		variety.append(counts["kinds"].size())
	variety.sort()
	var median: float = 0.0
	if not variety.is_empty():
		var middle: int = variety.size() / 2
		median = float(variety[middle]) if variety.size() % 2 == 1 else float(variety[middle - 1] + variety[middle]) / 2.0
	var yard_cells: int = area["owners"].size()
	return {"homes": per_home.size(), "yard_cells": yard_cells, "old": old_rows, "new": new_rows,
		"per_100": 100.0 * float(old_rows + new_rows) / float(yard_cells) if yard_cells > 0 else 0.0,
		"median_kinds": median, "map_kinds": kinds.size(), "kinds": kinds,
		"blocking": blocking, "per_home": per_home, "home_variety": variety}


static func _dress_home(data: Dictionary, home: Dictionary, state: Dictionary, old_count: int) -> void:
	_cache_home(home, state)
	var seed_value: int = ("%s|%d|yard" % [data.get("place_id", ""), home["building"]]).hash() & 0x7fffffff
	home["seed"] = seed_value
	state["remaining"] = maxi(0, floori(float(home["cells"].size()) * TARGET_PER_100 / 100.0) - old_count)
	# 큰 소품 자리를 먼저 확보해 덤불만으로 몫을 다 쓰지 않는다.
	if _unit(seed_value, 10) < 0.5 and not ROLES_OFF.has("garden"):
		_place(data, home, state, "garden_bed" if _roll(seed_value, 11) % 2 == 0 else "herb_bed", "garden", 100)
	if _unit(seed_value, 20) < 0.6:
		_place(data, home, state, "firewood_pile", "wood", 200)
	if _unit(seed_value, 30) < 0.4:
		_place(data, home, state, "water_barrel", "corner", 300)
	if _unit(seed_value, 40) < 0.3 and not ROLES_OFF.has("laundry"):
		_place(data, home, state, "laundry_line", "laundry", 400)
	if _unit(seed_value, 50) < 0.25:
		_place(data, home, state, "bench", "bench", 500)
	for rock_index in range(_roll(seed_value, 60) % 3):
		_place(data, home, state, "boulder" if _roll(seed_value, 61, rock_index) % 2 == 0 else "stump_cluster", "rock", 600, rock_index)
	var wall_cells: int = 0
	var edge_cells: int = 0
	for cell: Vector2i in home["cells"]:
		if state["forbidden"].has(cell):
			continue
		wall_cells += int(state["back"][cell] != Vector2i.ZERO)
		edge_cells += int(state["edge"][cell])
	var wall_wanted: int = roundi(float(wall_cells) * (0.25 + 0.15 * _unit(seed_value, 70)))
	var edge_wanted: int = roundi(float(edge_cells) * (0.10 + 0.10 * _unit(seed_value, 71)))
	state["wall_left"] = wall_wanted
	state["edge_left"] = edge_wanted
	var other_bush: String = ["dry_bush", "bush_dry", "fern_dry"][_roll(seed_value, 72) % 3]
	# 집마다 덤불은 작은 향나무와 고른 한 종류. 가장자리 풀은 별도 갈래다.
	for shrub_index in range(maxi(wall_wanted, edge_wanted)):
		if state["wall_left"] > 0:
			var wall_kind: String = other_bush if shrub_index % 3 == 0 else "bush_juniper"
			if not _place(data, home, state, wall_kind, "wall", 700, shrub_index) and wall_kind != "bush_juniper":
				_place(data, home, state, "bush_juniper", "wall", 700, shrub_index)
		if state["edge_left"] > 0:
			var edge_kind: String = "dry_bush" if other_bush == "dry_bush" and shrub_index % 3 == 1 else "dry_grass"
			_place(data, home, state, edge_kind, "edge", 800, shrub_index)


static func dress(data: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var area: Dictionary = survey(data)
	var stats: Dictionary = {"homes": area["homes"].size(), "yard_cells": area["owners"].size(),
		"rows": 0, "kinds": {}, "blocking": 0, "over_cap_homes": 0, "full_checks": 0}
	var old: Dictionary = census(data, area)
	for counted_home: Dictionary in area["homes"]:
		var cap: int = floori(float(counted_home["cells"].size()) * TARGET_PER_100 / 100.0)
		if int(old["per_home"][counted_home["building"]]["old"]) > cap:
			stats["over_cap_homes"] += 1
	# 실수로 두 번 불러도 쌓지 않는다. 지도마다 준비한 자료 두 벌의 결과도 같다.
	for existing: Dictionary in data.get("props", []):
		if existing.get("yard", false):
			var existing_kind: String = existing["kind"]
			stats["rows"] += 1
			stats["kinds"][existing_kind] = int(stats["kinds"].get(existing_kind, 0)) + 1
			stats["blocking"] += int(existing.get("solid", "none") == "low")
	if stats["rows"] > 0:
		return stats
	if area["owners"].is_empty():
		data["yard_dress_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
		return stats
	if not data.has("props"):
		data["props"] = []
	if not data.has("low_blocks"):
		data["low_blocks"] = []
	var before: int = data["props"].size()
	var models: Dictionary = {}
	for kind: String in SIZES:
		models[kind] = not PropKinds.model_path(kind).is_empty()
	var grid: FieldGrid = data["grid"]
	var walk: PackedByteArray = _walk_mask(grid)
	var state: Dictionary = {"owners": area["owners"], "forbidden": area["forbidden"],
		"fronts": area["fronts"], "fences": _fences(data), "used": {}, "models": models,
		"remaining": 0, "guard": path_guard(grid, walk), "walk": walk, "full_checks": 0}
	for home: Dictionary in area["homes"]:
		_dress_home(data, home, state, int(old["per_home"][home["building"]]["old"]))
	stats["full_checks"] = state["full_checks"]
	for prop_index in range(before, data["props"].size()):
		var prop: Dictionary = data["props"][prop_index]
		var prop_kind: String = prop["kind"]
		stats["rows"] += 1
		stats["kinds"][prop_kind] = int(stats["kinds"].get(prop_kind, 0)) + 1
		stats["blocking"] += int(prop["solid"] == "low")
	if stats["blocking"] > 0 and not data.get("_defer_paths", false):
		grid.refresh_paths()
	data["yard_dress_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	return stats
