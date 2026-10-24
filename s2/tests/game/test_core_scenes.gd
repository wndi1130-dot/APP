extends "res://addons/gut/test.gd"
## 코어 장면(결정 426 D②, core_scenes.gd): 화물역·공장·탄광 지도마다 기계 건물 하나에 멈춘 기계 하나,
## 판마다 코어가 남았는지 굴림(보임 15%, 숨음 15%), 떼는 데 30초, 코어는 영수증 items.gained로.

const FieldGame = preload("res://game/field_game.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const CoreScenes = preload("res://game/world/core_scenes.gd")
const S = FieldGrid.Solid

## 지도마다 고른 장면(건물 이름 낱말 차례, core_scenes.gd SCENES).
const EXPECTED: Dictionary = {
	"freight_01": "멈춘 증기 기관", "freight_02": "부서진 기관차", "freight_03": "부서진 기관차",
	"freight_04": "멈춘 냉동기", "freight_05": "멈춘 증기 기관", "freight_06": "멈춘 증기 기관",
	"factory_01": "멈춘 발전기", "factory_02": "뜯다 만 기관", "factory_03": "멈춘 증기 기관",
	"factory_04": "뜯다 만 기관차", "factory_05": "멈춘 변압기", "factory_06": "뜯다 만 기관",
	"mine_01": "멈춘 권양기", "mine_02": "멈춘 권양기", "mine_03": "멈춘 권양기",
	"mine_04": "멈춘 권양기", "mine_05": "멈춘 권양기", "mine_06": "멈춘 권양기",
	"mine_07": "멈춘 권양기", "mine_08": "멈춘 권양기", "mine_09": "멈춘 권양기",
}


func test_every_freight_yard_works_and_mine_has_one_machine_inside_a_machine_building() -> void:
	for id: String in EXPECTED:
		var d := FieldMaps.build(id)
		var spot := CoreScenes.place(d)
		assert_false(spot.is_empty(), id)
		if spot.is_empty():
			continue
		assert_eq(spot["name"], EXPECTED[id], id)
		assert_eq(d["spots"][CoreScenes.SPOT], spot, id + ": 지점 하나")
		var g: FieldGrid = d["levels"][0]
		var c: Vector2i = spot["cell"]
		assert_eq(g.building_at(c), int(spot["building"]), id + ": 그 건물 땅층 안")
		assert_eq(g.solid_at(c), S.NONE, id + ": 가구 없는 바닥")
		assert_true(CoreScenes._steps_from_train(d, g).has(c), id + ": 열차에서 걸어 닿음")
		for y in range(-1, 2):
			for x in range(-1, 2):
				var n := c + Vector2i(x, y)
				assert_false(g.doors.has(n) or g.windows.has(n), id + ": 문·창 곁이 아님")
		for box_id: Variant in d["containers"]:
			var box: Dictionary = d["containers"][box_id]
			assert_false(int(box.get("level", 0)) == 0 and box["cell"] == c, id + ": 상자 자리가 아님")
		assert_true(CoreScenes.CORE_ITEMS.has(spot["item"]), id)


func test_other_places_have_no_core_scene() -> void:
	for id: String in [FieldMaps.DEFAULT_PLACE, "houses_01", "hospital_01", "church_01", "office_01", "lake_01", "lodge_01", "sawmill_01", "summit_01", "bare_line_01"]:
		var d := FieldMaps.build(id)
		assert_eq(CoreScenes.place(d), {}, id)
		assert_false(d["spots"].has(CoreScenes.SPOT), id)


func test_the_dice_are_the_s1_rate_and_the_same_seed_gives_the_same_core() -> void:
	var counts := {"core": 0, "hidden": 0, "bare": 0}
	for s in range(4000):
		var state := CoreScenes.roll(("%d:core:factory_01" % s).hash())
		counts[state] += 1
		assert_eq(CoreScenes.roll(("%d:core:factory_01" % s).hash()), state)
	assert_almost_eq(counts["core"] / 4000.0, CoreScenes.P_CORE, 0.02, "보이는 코어 15%(S1 BYPRODUCT)")
	assert_almost_eq(counts["hidden"] / 4000.0, CoreScenes.P_HIDDEN, 0.02, "숨은 코어 15%(기관 전문가 몫)")


func test_the_count_takes_every_core_and_nothing_else() -> void:
	assert_eq(CoreScenes.count(["plow_core", "core_engine", "core_engine", "info_telegraph", "core_electric"]), 4)
	assert_eq(CoreScenes.count([]), 0)


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


func _board(game) -> void:
	var r: Rect2i = game.data["boarding"][0]
	for q in game.squad:
		q.position = game.lift(r.position + Vector2i(r.size.x / 2, 0), 0)


func test_a_core_left_in_the_machine_comes_away_in_half_a_minute_and_onto_the_receipt() -> void:
	var game = _game("factory_01")
	var spot: Dictionary = game.data["spots"][CoreScenes.SPOT]
	assert_true(String(spot["state"]) in ["core", "hidden", "bare"], "판 시작에 굴림")
	assert_true(game.receipt.to_dict()["placeState"].has("coreScene"), "굴린 것은 장소 상태에")
	spot["state"] = "core"
	var p = game.player
	p.position = game.lift(spot["cell"], 0)
	game.actions.core_scene(p, CoreScenes.SPOT)
	assert_eq(p.action, "salvage")
	_work(game, p, CoreScenes.DETACH_SECONDS - 1.0)
	assert_eq(spot["state"], "core", "30초 전에는 아직")
	# 손일은 몸의 손 곱을 받는다(추위·상처면 더 걸린다): 끝날 때까지 더 일한다.
	var t := 0.0
	while spot["state"] == "core" and t < CoreScenes.DETACH_SECONDS:
		_work(game, p, 0.5)
		t += 0.5
	assert_eq(spot["state"], "taken")
	assert_eq(int(p.items.get(spot["item"], 0)), 1, "코어 하나")
	_board(game)
	game.finish("departed")
	var gained: Array = game.receipt.to_dict()["items"]["gained"]
	assert_eq(CoreScenes.count(gained), 1, "영수증 얻은 물건에 코어 하나")
	assert_eq(Array(game.Receipt.check(game.receipt.to_dict())), [], "영수증 형식 그대로")


func test_a_hidden_core_looks_stripped_and_leaves_one_line_on_the_receipt() -> void:
	var game = _game("freight_03")
	var spot: Dictionary = game.data["spots"][CoreScenes.SPOT]
	spot["state"] = "hidden"
	var p = game.player
	p.position = game.lift(spot["cell"], 0)
	game.actions.core_scene(p, CoreScenes.SPOT)
	assert_eq(p.action, "", "들여다보기만")
	assert_eq(spot["state"], "seen_hidden")
	assert_eq(int(p.items.get(spot["item"], 0)), 0, "기관 전문가 없이는 못 뗀다")
	_board(game)
	game.finish("departed")
	assert_eq(game.receipt.to_dict()["placeState"].get("coreHint"), true)


func test_two_cores_are_two_entries() -> void:
	var game = _game("freight_03")
	game.player.add_item("core_engine", 2)
	_board(game)
	game.finish("departed")
	assert_eq(CoreScenes.count(game.receipt.to_dict()["items"]["gained"]), 2)


func test_a_stop_receipt_carries_the_count_in_its_extras() -> void:
	# 정차 영수증(id가 있는 영수증)이면 코어 수가 extras.coreCount에도 들어간다(set_extras는 한 곳).
	var game = _game("freight_03")
	assert_true(game.receipt.set_ids("ret_sulechow_01", "stop_sulechow"))
	game.player.add_item("core_engine")
	game.player.add_item("plow_core")
	_board(game)
	game.finish("departed")
	var d: Dictionary = game.receipt.to_dict()
	assert_eq(int(d["extras"]["coreCount"]), 2)
	assert_eq(Array(game.Receipt.check(d)), [], "정차 영수증 형식 그대로")


func test_a_field_receipt_without_ids_keeps_its_old_shape() -> void:
	var game = _game("freight_03")
	game.player.add_item("core_electric")
	_board(game)
	game.finish("departed")
	var d: Dictionary = game.receipt.to_dict()
	assert_false(d.has("receiptId"), "id 없는 필드 영수증은 정차 영수증이 되지 않는다")
	assert_eq(CoreScenes.count(d["items"]["gained"]), 1)
