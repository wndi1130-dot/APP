extends RefCounted
## 지도 소품 모델을 그 rect(소품의 충돌 칸)에 맞춰 놓는다. 그리는 모습만 바꾸고
## 칸·지도 자료는 그대로 둔다.
## 1) 모델의 긴 축을 rect의 긴 축에 맞춰 돌린다. 지도 facing이 맞으면 그대로 두고,
##    90도 돌려야 맞으면 같은 축의 두 방향 가운데 등이 벽에 닿고 앞이 트인 쪽을 고른다.
## 2) 그래도 넘치면 넘치는 축만 줄인다(최대 35%, 높이는 그대로).

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
## 한 변이 rect 변의 5% 또는 5 cm보다 더 나가면 넘침.
const TOL_RATIO := 0.05
const TOL_MIN := 0.05
const MIN_SCALE := 0.65


## lo, hi: 모델 경계(facing 0, rect 가운데 바닥 기준). 돌아온 값은 쓸 facing,
## 세계 축 기준 크기 배율 Vector3(x, 1, z), 지도 facing과 다르게 돌렸는지, 줄였는지.
static func fit(lo: Vector3, hi: Vector3, r: Rect2i, facing: int, grid: FieldGrid = null) -> Dictionary:
	var f := posmod(facing, 4)
	var w := float(r.size.x)
	var h := float(r.size.y)
	var turned := false
	# 돌려서 맞을 때만 돌린다. 어느 방향으로도 안 맞는 모델(깊은 옷장 등)은 지도 방향을
	# 지키고 줄이기만 한다: 돌리면 앞(문·서랍)이 옆을 보게 된다.
	if not fits(lo, hi, f, w, h):
		var alt := (f + 1) % 4
		if fits(lo, hi, alt, w, h):
			f = better_side(alt, (alt + 2) % 4, r, grid)
			turned = true
	var fp := footprint(lo, hi, f)
	var sx := _axis_scale(fp[0].x, fp[1].x, w)
	var sz := _axis_scale(fp[0].y, fp[1].y, h)
	return {"facing": f, "scale": Vector3(sx, 1.0, sz), "turned": turned, "shrunk": sx < 1.0 or sz < 1.0}


## 바닥 위에서 본 모델 발자국을 facing만큼 돌린 [최소, 최대](x, z).
static func footprint(lo: Vector3, hi: Vector3, facing: int) -> Array:
	var b := Basis(Vector3.UP, -float(facing) * PI * 0.5)
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for x in [lo.x, hi.x]:
		for z in [lo.z, hi.z]:
			var v := b * Vector3(x, 0, z)
			mn = Vector2(minf(mn.x, v.x), minf(mn.y, v.z))
			mx = Vector2(maxf(mx.x, v.x), maxf(mx.y, v.z))
	return [mn, mx]


## 왼·오른·위·아래로 rect 밖으로 나간 길이(m).
static func overflow(lo: Vector3, hi: Vector3, facing: int, w: float, h: float) -> Array:
	var fp := footprint(lo, hi, facing)
	return [maxf(0.0, -w * 0.5 - fp[0].x), maxf(0.0, fp[1].x - w * 0.5), maxf(0.0, -h * 0.5 - fp[0].y), maxf(0.0, fp[1].y - h * 0.5)]


static func overflow_sum(lo: Vector3, hi: Vector3, facing: int, w: float, h: float) -> float:
	var o := overflow(lo, hi, facing, w, h)
	return o[0] + o[1] + o[2] + o[3]


static func fits(lo: Vector3, hi: Vector3, facing: int, w: float, h: float) -> bool:
	var o := overflow(lo, hi, facing, w, h)
	var tx := maxf(TOL_MIN, w * TOL_RATIO)
	var tz := maxf(TOL_MIN, h * TOL_RATIO)
	return o[0] <= tx and o[1] <= tx and o[2] <= tz and o[3] <= tz


## 앞(+Z를 facing만큼 돌린 쪽)이 더 트이고 등이 더 막힌 쪽. 같으면 a.
static func better_side(a: int, b: int, r: Rect2i, grid: FieldGrid) -> int:
	if grid == null:
		return a
	var score_a := _blocked(grid, r, -front(a)) - _blocked(grid, r, front(a))
	var score_b := _blocked(grid, r, -front(b)) - _blocked(grid, r, front(b))
	return b if score_b > score_a else a


## facing의 앞 방향(칸 좌표: x 오른쪽, y 아래). 0 +Z, 1 -X, 2 -Z, 3 +X.
static func front(facing: int) -> Vector2i:
	return [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)][posmod(facing, 4)]


## rect의 한 변 바로 밖 칸 가운데 벽·막힘·창의 비율.
static func _blocked(g: FieldGrid, r: Rect2i, d: Vector2i) -> float:
	var cells: Array[Vector2i] = []
	if d.x != 0:
		var x := r.end.x if d.x > 0 else r.position.x - 1
		for y in range(r.position.y, r.end.y):
			cells.append(Vector2i(x, y))
	else:
		var y := r.end.y if d.y > 0 else r.position.y - 1
		for x in range(r.position.x, r.end.x):
			cells.append(Vector2i(x, y))
	if cells.is_empty():
		return 0.0
	var blocked := 0
	for c in cells:
		if not g.inside(c):
			blocked += 1
			continue
		var s := g.solid_at(c)
		if s == S.WALL or s == S.BLOCK or s == S.WINDOW:
			blocked += 1
	return float(blocked) / float(cells.size())


## 허용치 안이면 1. 넘치면 가운데에서 가장 먼 쪽이 rect 반 변에 닿도록, 최소 MIN_SCALE.
static func _axis_scale(lo: float, hi: float, side: float) -> float:
	var half := maxf(-lo, hi)
	if half <= 0.0 or half <= side * 0.5 + maxf(TOL_MIN, side * TOL_RATIO):
		return 1.0
	return maxf(MIN_SCALE, side * 0.5 / half)
