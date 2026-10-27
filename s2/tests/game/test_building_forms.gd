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
	assert_eq(use.call("갱구 관리동"), "headframe")
	assert_eq(Uses.use_of({"name": "농가", "role": "store"}), "home", "role store is read by name")
