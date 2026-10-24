extends "res://addons/gut/test.gd"
## 옥상(docs/design/briefs/house_layout.md 6장, 결정 423): 평지붕 건물만 도시 지도마다 1~2곳,
## 맨 위층 방 안 천창 사다리로 오르고, 신호소 사다리 규칙 그대로(빨리 3초 보통 소리, 조심히 6초).

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const RoofRules = preload("res://game/world/roof_rules.gd")
const S = FieldGrid.Solid
const TOWNS: Array[String] = ["houses_01", "office_01", "hospital_01", "factory_01"]


func _ladders(d: Dictionary) -> Array:
	var out: Array = []
	for s: Dictionary in d["stairs"]:
		if s.get("ladder", false) and s.has("roof"):
			out.append(s)
	return out


func test_a_town_map_gets_one_or_two_flat_roofs_to_climb() -> void:
	for id in TOWNS:
		var d := FieldMaps.build(id)
		var roofs: Array = d.get("rooftops", [])
		assert_between(roofs.size(), 1, RoofRules.ROOFS_MAX, id)
		assert_eq(_ladders(d).size(), roofs.size(), id + ": 옥상마다 사다리 하나")
		for row: Dictionary in roofs:
			var lv: int = row["level"]
			assert_lte(lv, RoofRules.TOP_LEVEL_MAX, id + ": 층 번호 안")
			var roof: FieldGrid = d["levels"][lv]
			var below: FieldGrid = d["levels"][lv - 1]
			var c: Vector2i = row["ladder"]
			assert_true(roof.people_can_walk(c), id + ": 사다리 위 지붕 칸")
			assert_true(below.people_can_walk(c), id + ": 사다리 발치")
			assert_eq(below.building_at(c), int(row["building"]))
			assert_lt(roof.building_at(c), 0, id + ": 지붕 칸은 건물 층이 아니다")
			assert_eq(roof.dead_path.is_point_solid(c), false)


func test_the_roof_is_walled_by_open_air() -> void:
	# 지붕 칸 둘레는 허공이라 걸어서 떨어지지 않는다(6.3 낮은 담).
	var d := FieldMaps.build("office_01")
	for row: Dictionary in d["rooftops"]:
		var roof: FieldGrid = d["levels"][row["level"]]
		var below: FieldGrid = d["levels"][int(row["level"]) - 1]
		var seen: Dictionary = {row["ladder"]: true}
		var queue: Array[Vector2i] = [row["ladder"]]
		while not queue.is_empty():
			var c: Vector2i = queue.pop_back()
			for dd: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := c + dd
				if not seen.has(n) and roof.people_can_walk(n):
					seen[n] = true
					queue.append(n)
		assert_eq(seen.size(), int(row["cells"]), "지붕 칸만 이어진다")
		for c: Vector2i in seen:
			assert_eq(below.building_at(c), int(row["building"]), "지붕 칸은 그 건물 위")


func test_no_roofs_on_the_first_stop_or_out_of_town() -> void:
	assert_eq(FieldMaps.build(FieldMaps.DEFAULT_PLACE).get("rooftops", []), [])
	assert_eq(FieldMaps.build("lake_01").get("rooftops", []), [])


func test_furniture_leaves_the_ladder_clear() -> void:
	for id in TOWNS:
		var d := FieldMaps.build(id)
		for s: Dictionary in _ladders(d):
			var g: FieldGrid = d["levels"][int(s["low"])]
			assert_eq(g.solid_at(s["cell"]), S.NONE, id + ": 사다리 칸에 가구 없음")


func _game(place: String):
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "place": place}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	return game


func _work(game, p, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		game._update_person(p, 0.1)
		t += 0.1


func test_up_the_skylight_ladder_and_down_by_the_signal_box_rule() -> void:
	var game = _game("office_01")
	var p = game.player
	var s: Dictionary = _ladders(game.data)[0]
	p.position = game.lift(s["cell"], int(s["low"]))
	game.actions.climb_ladder(p, s, "fast")
	assert_eq(p.action, "climb")
	assert_true(p.brain.get("on_ladder", false), "사다리 위: 잡히면 떨어질 수 있다")
	_work(game, p, game.actions.CLIMB_FAST + 0.3)
	assert_eq(game.level_of(p.position), int(s["high"]), "지붕 위")
	assert_false(p.brain.get("on_ladder", false))
	assert_eq(game.forecast_precision, 1, "예보 정밀도 한 단계")
	assert_true(game.roof_seen)
	game.actions.climb_ladder(p, s, "careful")
	_work(game, p, game.actions.CLIMB_FAST + 0.3)
	assert_eq(game.level_of(p.position), int(s["high"]), "조심히는 더 오래 걸린다")
	_work(game, p, game.actions.CLIMB_CAREFUL - game.actions.CLIMB_FAST)
	assert_eq(game.level_of(p.position), int(s["low"]), "다시 맨 위층")


func test_the_dead_find_no_way_up() -> void:
	var game = _game("office_01")
	var s: Dictionary = _ladders(game.data)[0]
	var foot: Vector3 = game.lift(s["cell"], int(s["low"]))
	var top: Vector3 = game.lift(s["cell"], int(s["high"]))
	var path: PackedVector3Array = game.find_path(foot, top, true)
	var reached := false
	for at in path:
		reached = reached or game.level_of(at) == int(s["high"])
	assert_false(reached, "망자는 사다리를 못 오른다")
