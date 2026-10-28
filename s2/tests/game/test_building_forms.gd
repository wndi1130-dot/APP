extends "res://addons/gut/test.gd"
## 건물 꼴 1가(결정 478): 용도·지역으로 벽 재질·색·지붕(물매·평지붕)·굴뚝을 고른다.

const BuildingForms = preload("res://game/world/building_forms.gd")
const Uses = preload("res://game/world/building_uses.gd")

const PAINT := Color(0.66, 0.60, 0.50, 2.0)


func _row(name: String, cells: Vector2i = Vector2i(8, 6), id: int = 3) -> Dictionary:
	return {"id": id, "name": name, "rect": Rect2i(Vector2i(10, 10), cells)}


func test_an_unknown_map_keeps_todays_look() -> void:
	var look := BuildingForms.pick(_row("주택"), "", PAINT)
	assert_eq(look["wall"], "render")
	assert_eq(look["wall_kind"], 0.0)
	assert_eq(look["paint"], PAINT, "the paint roll building_view gave, roof colour and all")
	assert_eq(look["roof"], "gable")
	assert_eq(look["silhouette"], "gable")
	assert_eq(look["dormers"], 0)
	assert_eq(look["pitch"], 1.0)
	assert_true(look["chimney"], "a house has its chimney anywhere")


func test_town_houses_keep_their_paint_and_public_buildings_turn_to_brick() -> void:
	var home := BuildingForms.pick(_row("살림집"), "houses_01", PAINT)
	assert_eq(home["use"], "home")
	assert_eq(home["wall"], "render")
	assert_eq(home["paint"], PAINT, "town homes keep the paint roll")
	assert_true(home["chimney"], "every home has a chimney now, not only those named 주택")
	var hall := BuildingForms.pick(_row("시청 본관", Vector2i(14, 10)), "office_01", PAINT)
	assert_eq(hall["use"], "office")
	assert_eq(hall["wall"], "brick")
	assert_eq(int(hall["wall_kind"]) & BuildingForms.PLINTH, BuildingForms.PLINTH, "a stone plinth")
	var church := BuildingForms.pick(_row("교회 본당"), "church_02", PAINT)
	assert_gt(float(church["pitch"]), 1.5, "a steep gable")
	assert_false(church["chimney"])


func test_regions_give_their_own_walls_and_roofs() -> void:
	assert_eq(BuildingForms.pick(_row("산장 본채"), "lodge_03", PAINT)["wall"], "log")
	assert_gt(float(BuildingForms.pick(_row("산장 본채"), "lodge_03", PAINT)["pitch"]), 1.5)
	assert_eq(BuildingForms.pick(_row("호숫가 집"), "lake_02", PAINT)["wall"], "clapboard")
	assert_eq(BuildingForms.pick(_row("선로 창고"), "bare_line_01", PAINT)["wall"], "corrugated")
	assert_eq(BuildingForms.pick(_row("제재동"), "sawmill_01", PAINT)["wall"], "boards")
	assert_eq(BuildingForms.pick(_row("권양기동"), "mine_02", PAINT)["wall"], "brick", "the headframe house is brick")
	var shed := BuildingForms.pick(_row("부품 창고"), "factory_01", PAINT)
	assert_eq(shed["wall"], "corrugated")
	assert_lt(float(shed["pitch"]), 0.9, "a low roof on a rail-yard store")
	var roof := int(BuildingForms.pick(_row("기관고"), "freight_01", PAINT)["paint"].a)
	assert_true(roof in BuildingForms.ROOF_COLOURS["rail_works"], "rail-yard roof colours")


func test_flat_roofs_follow_the_use() -> void:
	assert_eq(BuildingForms.pick(_row("내과동"), "hospital_01", PAINT)["roof"], "flat", "a clinic")
	assert_eq(BuildingForms.pick(_row("조립 공장", Vector2i(16, 12)), "factory_02", PAINT)["roof"], "flat", "a big works hall")
	assert_eq(BuildingForms.pick(_row("조립 공장", Vector2i(8, 6)), "factory_02", PAINT)["roof"], "gable", "a small one keeps its gable")
	assert_eq(BuildingForms.pick(_row("빵집"), "houses_02", PAINT, 2)["roof"], "flat", "a two-storey shop in town")
	assert_eq(BuildingForms.pick(_row("빵집"), "houses_02", PAINT, 1)["roof"], "gable")


func test_one_use_rolls_its_colour_by_building() -> void:
	var seen: Dictionary = {}
	for b in range(12):
		var look := BuildingForms.pick(_row("어구 창고", Vector2i(6, 4), b), "lake_01", PAINT)
		assert_eq(look["wall"], "boards")
		seen[Color(look["paint"].r, look["paint"].g, look["paint"].b)] = true
	assert_gt(seen.size(), 1, "the same use is not one colour")


func test_the_head_word_names_the_use() -> void:
	var use := func(name: String) -> String: return Uses.use_of({"name": name, "group": "church"})
	assert_eq(use.call("성당 관리인 집"), "home", "the last word wins over 성당·관리")
	assert_eq(use.call("학교 숙직 헛간"), "barn")
	assert_eq(use.call("공구 창고"), "store")
	assert_eq(use.call("식품 집하 창고"), "store", "집하 is not 집")
	assert_eq(use.call("우편 집배소"), "office", "a one-letter word only at the end of a word")
	assert_eq(use.call("저장 광 가"), "store", "the 가 tag comes off")
	assert_eq(use.call("장작 광"), "barn")
	assert_eq(use.call("판매 홀"), "shop")
	assert_eq(use.call("가게 겸 집"), "shop")
	assert_eq(use.call("빵집"), "shop")
	assert_eq(use.call("우물집"), "shelter")
	assert_eq(use.call("펌프 집"), "works", "spaced like 펌프집")
	assert_eq(use.call("양치기 집"), "home")
	assert_eq(use.call("갱구 관리동"), "headframe")
	assert_eq(Uses.use_of({"name": "농가", "role": "store"}), "home", "role store is read by name")


func test_silhouette_candidates_follow_use_region_and_size() -> void:
	# 이름, 지도, 바닥 크기, 층, 후보(순서도 이웃 조정 계약).
	var cases: Array = [
		["살림집", "houses_01", Vector2i(8, 6), 1, ["gable", "hip", "half_hip"]],
		["살림집", "houses_01", Vector2i(10, 8), 2, ["gable", "hip", "half_hip", "mansard"]],
		["살림집", "houses_01", Vector2i(8, 6), 2, ["gable", "hip", "half_hip"]],
		["살림집", "factory_01", Vector2i(8, 6), 1, ["gable", "half_hip"]],
		["살림집", "lodge_01", Vector2i(8, 6), 1, ["gable", "half_hip"]],
		["산장 본채", "lodge_01", Vector2i(12, 8), 2, ["gable", "half_hip"]],
		["호숫가 집", "lake_01", Vector2i(8, 6), 1, ["gable", "hip"]],
		["살림집", "bare_line_01", Vector2i(8, 6), 1, ["gable", "shed"]],
		["살림집", "mine_01", Vector2i(8, 6), 1, ["gable"]],
		["마을 회관", "houses_01", Vector2i(12, 8), 1, ["hip", "mansard"]],
		["시청 본관", "office_01", Vector2i(12, 8), 2, ["hip", "mansard"]],
		["교회 본당", "church_01", Vector2i(12, 8), 1, ["gable"]],
		["내과동", "hospital_01", Vector2i(12, 8), 1, ["flat"]],
		["헛간", "houses_01", Vector2i(12, 8), 1, ["mansard"]],
		["공구 창고", "factory_01", Vector2i(6, 5), 1, ["shed"]],
		["공구 창고", "factory_01", Vector2i(6, 6), 1, ["gable"]],
		["차고", "factory_01", Vector2i(6, 5), 1, ["shed"]],
		["차고", "factory_01", Vector2i(12, 8), 1, ["gable"]],
		["우물 정자", "houses_01", Vector2i(6, 5), 1, ["shed"]],
		["조립 공장", "factory_01", Vector2i(12, 8), 1, ["gable"]],
		["조립 공장", "factory_01", Vector2i(16, 10), 1, ["flat"]],
	]
	for sample: Array in cases:
		var seen: Dictionary = {}
		for b: int in range(192):
			var look: Dictionary = BuildingForms.pick(_row(sample[0], sample[2], b), sample[1], PAINT, int(sample[3]))
			assert_eq(look["candidates"], sample[4], "%s %s" % [sample[0], sample[1]])
			assert_true(look["silhouette"] in sample[4])
			assert_eq(look["roof"], "flat" if sample[4] == ["flat"] else "gable", "기존 roof 계약")
			seen[look["silhouette"]] = true
		assert_eq(seen.size(), (sample[4] as Array).size(), "번호 해시가 모든 후보에 닿는다")
	var shed: Dictionary = {"id": 3, "role": "shed", "name": "바깥 창고", "rect": Rect2i(0, 0, 6, 5)}
	assert_eq(BuildingForms.pick(shed, "houses_01", PAINT)["silhouette"], "shed")


func test_home_pitch_is_a_stable_roll_on_the_existing_table() -> void:
	for sample: Array in [["houses_01", 1.0], ["factory_01", 1.0], ["lodge_01", 1.7], ["bare_line_01", 0.75]]:
		var seen: Dictionary = {}
		for b: int in range(128):
			var row: Dictionary = _row("살림집", Vector2i(8, 6), b)
			var look: Dictionary = BuildingForms.pick(row, sample[0], PAINT)
			var ratio: float = float(look["pitch"]) / float(sample[1])
			var matched: bool = false
			for factor: float in BuildingForms.HOME_PITCHES:
				matched = matched or is_equal_approx(ratio, factor)
			assert_true(matched)
			seen[snappedf(ratio, 0.01)] = true
			assert_eq(look, BuildingForms.pick(row, sample[0], PAINT))
		assert_eq(seen.size(), 4)


func test_dormer_rolls_obey_use_shape_length_and_upper_floor_bias() -> void:
	var one_total: int = 0
	var two_total: int = 0
	for b: int in range(192):
		var row: Dictionary = _row("살림집", Vector2i(8, 8), b)
		var one: Dictionary = BuildingForms.pick(row, "houses_01", PAINT, 1)
		var two: Dictionary = BuildingForms.pick(row, "houses_01", PAINT, 2)
		for look: Dictionary in [one, two]:
			assert_between(int(look["dormers"]), 0, 3)
			if String(look["silhouette"]) not in BuildingForms.DORMER_ROOFS:
				assert_eq(look["dormers"], 0)
		one_total += int(one["dormers"])
		two_total += int(two["dormers"])
		assert_eq(BuildingForms.pick(_row("살림집", Vector2i(7, 7), b), "houses_01", PAINT, 2)["dormers"], 0)
		assert_eq(BuildingForms.pick(_row("헛간", Vector2i(12, 8), b), "houses_01", PAINT)["dormers"], 0)
		for map_id: String in ["", "test_map"]:
			var legacy: Dictionary = BuildingForms.pick(row, map_id, PAINT, 2)
			assert_eq(legacy["silhouette"], "gable")
			assert_eq(legacy["dormers"], 0)
			assert_eq(legacy["pitch"], 1.0)
	assert_gt(one_total, 0)
	assert_gt(two_total, one_total, "위층 있는 집에 지붕창을 더 자주")
