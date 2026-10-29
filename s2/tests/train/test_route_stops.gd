extends "res://addons/gut/test.gd"
## The no-fire flag rides the route's place, not the map (route_stops.gd; first_leg_story.md 7.4):
## the first leg's fifth stop has it whichever map comes there, the other stops do not.

const RouteStops = preload("res://game/train/route_stops.gd")
const FieldGame = preload("res://game/field_game.gd")


func test_only_the_fifth_stop_keeps_fire_out() -> void:
	var with_flag: Array = []
	for seg in range(1, 25):
		if bool(RouteStops.flags(seg).get("no_fire", false)):
			with_flag.append(seg)
	assert_eq(with_flag, [5], "아일렌부르크 물데강 앞 화물 구내(첫 구간 다섯째 정차)만")


## Decision 494: a first-leg stop reads the season table's stretch of 13 km it stands in
## (counted up, as the journey map), not the row with its own number.
func test_each_stop_reads_the_season_stretch_it_stands_in() -> void:
	var rows: Array = []
	for stop in range(1, 6):
		rows.append(RouteStops.season_seg(stop))
	assert_eq(rows, [5, 10, 11, 13, 23], "54·125·142·163·287 km")
	assert_eq(RouteStops.season_seg(0), 5, "before the first: the first's")
	assert_eq(RouteStops.season_seg(9), 23, "past the fifth: the fifth's")


func test_the_stop_made_at_the_fifth_place_carries_it_on_its_map() -> void:
	for place: String in ["freight_01", "freight_04", "factory_02"]:
		assert_true(bool(_game(place, 5).data.get("no_fire", false)), place + ": 다섯째 정차면 어느 지도든 불 없음")
	assert_false(bool(_game("freight_01", 4).data.get("no_fire", false)), "넷째 정차는 깃발 없음")


func _game(place: String, seg: int):
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "place": place, "departure": {"segment": seg}}
	add_child_autofree(game)
	game.set_process(false)
	return game
