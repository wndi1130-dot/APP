extends "res://addons/gut/test.gd"
## 상자 여는 시간을 크기로(카드 R1 가, 카드 H 뒤): 상자가 선 가구의 크기 — 작은 가구 0.5초,
## 서랍장·책상 1.5초, 옷장·조리대·궤짝과 가구 없는 상자 3초. 지도가 준 초는 더 안 본다.
## 솜씨는 전처럼 나눈다.

const FieldGame = preload("res://game/field_game.gd")
const SearchRules = preload("res://game/sim/search_rules.gd")
const Carry = preload("res://game/sim/carry.gd")
const RoomFurnish = preload("res://game/world/room_furnish.gd")


func test_the_size_of_a_box_sets_how_long_opening_takes() -> void:
	assert_eq(SearchRules.SIZE_SECONDS, {Carry.BOX_SMALL: 0.5, Carry.BOX_MID: 1.5, Carry.BOX_BIG: 3.0}, "the values in the PR")
	assert_almost_eq(SearchRules.box_seconds({"search": 4, "furniture": "nightstand"}), 0.5, 0.0001)
	assert_almost_eq(SearchRules.box_seconds({"search": 4, "furniture": "dresser"}), 1.5, 0.0001)
	assert_almost_eq(SearchRules.box_seconds({"search": 4, "furniture": "wardrobe"}), 3.0, 0.0001)
	assert_almost_eq(SearchRules.box_seconds({"search": 4}), 3.0, 0.0001, "a box of its own is a crate")
	assert_almost_eq(SearchRules.box_seconds({"search": 8, "furniture": "desk"}), 1.5, 0.0001, "the map's long search no longer counts")


## Open shelves, racks, an open fridge and bench tops show what they hold: a small cabinet's half
## second whatever their size (card R1, the coordinator's detail).
func test_what_stands_open_opens_at_a_glance() -> void:
	assert_almost_eq(SearchRules.box_seconds({"furniture": "shelf"}), 0.5, 0.0001, "a big open shelf")
	assert_almost_eq(SearchRules.box_seconds({"furniture": "fridge_open"}), 0.5, 0.0001)
	assert_almost_eq(SearchRules.box_seconds({"furniture": "bookcase"}), 0.5, 0.0001, "a middling one")
	assert_almost_eq(SearchRules.box_seconds({"furniture": "counter"}), 3.0, 0.0001, "a counter has doors")
	assert_almost_eq(SearchRules.box_seconds({"furniture": "glass_cabinet"}), 0.5, 0.0001, "small anyway")
	for kind: String in SearchRules.SEE_THROUGH:
		assert_true(Carry.BOX_LIMITS.has(kind), kind)


func test_the_searcher_waits_by_the_box_and_the_skill() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	var p = game.player
	var c := {"search": 4, "furniture": "nightstand"}
	var skill := int(p.skills["search"])
	assert_almost_eq(game.actions.search_time(p, c), 0.5 / (1.0 + SearchRules.SKILL_STEP * skill), 0.0001)
	c["furniture"] = "crate_stack"
	assert_almost_eq(game.actions.search_time(p, c), 3.0 / (1.0 + SearchRules.SKILL_STEP * skill), 0.0001)


## Every piece of furniture map-layout puts a box in has a size (Carry.BOX_LIMITS): a new one
## (the closets' small shelf) would otherwise fall to a drawer's.
func test_every_furniture_that_holds_a_box_has_a_size() -> void:
	for kind: String in RoomFurnish.HOLDER_KINDS:
		assert_true(Carry.BOX_LIMITS.has(kind), kind)
	assert_eq(Carry.box_limit({"furniture": "small_shelf"}), Carry.BOX_SMALL)

