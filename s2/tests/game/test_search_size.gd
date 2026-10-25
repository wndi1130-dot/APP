extends "res://addons/gut/test.gd"
## 뒤지기 시간을 상자 크기로(카드 H 가, ref-ops 실내 뒤지기 R1): 지도가 준 초에 상자가 선 가구의
## 크기 배율 — 작은 가구 0.5, 서랍장·책상 0.75, 옷장·조리대·궤짝과 가구 없는 상자는 그대로.
## 솜씨는 전처럼 나눈다.

const FieldGame = preload("res://game/field_game.gd")
const SearchRules = preload("res://game/sim/search_rules.gd")
const Carry = preload("res://game/sim/carry.gd")


func test_the_size_of_a_box_sets_how_long_a_look_takes() -> void:
	assert_eq(SearchRules.SIZE_FACTOR, {Carry.BOX_SMALL: 0.5, Carry.BOX_MID: 0.75, Carry.BOX_BIG: 1.0}, "the values in the PR")
	assert_almost_eq(SearchRules.box_seconds({"search": 4, "furniture": "nightstand"}), 2.0, 0.0001)
	assert_almost_eq(SearchRules.box_seconds({"search": 4, "furniture": "dresser"}), 3.0, 0.0001)
	assert_almost_eq(SearchRules.box_seconds({"search": 4, "furniture": "wardrobe"}), 4.0, 0.0001)
	assert_almost_eq(SearchRules.box_seconds({"search": 4}), 4.0, 0.0001, "a box of its own as the map says")
	assert_almost_eq(SearchRules.box_seconds({"search": 8, "furniture": "desk"}), 6.0, 0.0001, "a long search stays long by its share")


func test_the_searcher_waits_by_the_box_and_the_skill() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	var p = game.player
	var c := {"search": 4, "furniture": "nightstand"}
	var skill := int(p.skills["search"])
	assert_almost_eq(game.actions.search_time(p, c), 2.0 / (1.0 + SearchRules.SKILL_STEP * skill), 0.0001)
	c["furniture"] = "crate_stack"
	assert_almost_eq(game.actions.search_time(p, c), 4.0 / (1.0 + SearchRules.SKILL_STEP * skill), 0.0001)
