extends "res://addons/gut/test.gd"
## The train's papers on the slice's train steps, one at a time (the user 10-27: 「열차
## 단계에 서류가 오면 한 장씩 띄우고, 고르기 전엔 다음으로 못 가게 해」): the paper is up
## over the train, the main key goes nowhere till a way is chosen, then the train goes on.

const SliceFlow = preload("res://game/slice_flow.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const CarPane = preload("res://game/ui/car_pane.gd")


func _flow():
	var f = SliceFlow.new()
	f.opts = {"skip_field": true, "cinema": false}
	add_child_autofree(f)
	return f


func test_the_first_run_paper_holds_the_train_till_a_way_is_chosen() -> void:
	var f = _flow()
	assert_eq(f.current(), "train")
	assert_true(SliceFlow.papers_of(f.train_g), "the first run brings a paper")
	assert_true(is_instance_valid(f.paper), "it is up over the train")
	var uid: int = int(f.train_g["cards"][0]["uid"])
	assert_eq(int(f.paper.uid), uid, "the first one")
	f.train_on()
	assert_eq(f.current(), "train", "the main key goes nowhere with the paper up")
	assert_true(SliceFlow.papers_of(f.train_g))
	# Chosen as a hand would: its first key (a heavy way asks twice).
	for press in 2:
		if not is_instance_valid(f.paper) or int(f.paper.uid) != uid:
			break
		(f.paper.find_child("Key_1", true, false) as Button).pressed.emit()
	assert_false(SliceFlow.papers_of(f.train_g), "chosen, the paper is gone from the board")
	assert_eq(f.current(), "stop_pick", "and the train goes on to the stop, as the key was pulled")


func test_a_step_gone_to_straight_takes_each_paper_on_its_first_way() -> void:
	var f = _flow()
	var g: Dictionary = SliceFlow.pick_first(f.train_g, f.train_t)
	assert_false(SliceFlow.papers_of(g))
	assert_false(g.has("_turn_port_error"))
	assert_ne(JSON.stringify(g), JSON.stringify(f.train_g), "the way taken moves the board")


## On the narrow screen (1280 × 720, the test window) the paper stops short of the car
## pane's words (the coordinator 10-27), so the car's numbers stay in sight.
func test_on_a_narrow_screen_the_paper_stops_short_of_the_car_pane() -> void:
	var f = _flow()
	var screen: float = f.get_viewport().get_visible_rect().size.x / UiFonts.K
	var words_x: float = (screen - CarPane.CSS_SIZE.x + SliceFlow.PANE_WORDS_X) * UiFonts.K
	await get_tree().process_frame
	var sheet: Control = f.paper.sheet
	assert_lte(sheet.position.x + sheet.size.x, words_x, "the paper ends before the pane's words at %d wide" % int(screen * UiFonts.K))


## Folded to its edge (결정 508) the paper makes room: the picked car moves into the
## middle of what the edge and the car pane leave. The main key opens it again, as it
## is what holds the train; gone, the room goes back.
func test_a_folded_paper_makes_room_for_the_picked_car() -> void:
	var f = _flow()
	await get_tree().process_frame
	f.train.set_view_mode("diag")
	f._select(SliceFlow.FIRST_CAR)
	assert_eq(float(f.train.pane_left_px), 0.0, "an open paper moves nothing")
	var right: float = float(f.train.pane_px)
	f.paper.set_folded(true)
	assert_almost_eq(float(f.train.pane_left_px), float(f.paper.folded_edge()), 0.001)
	assert_almost_eq(float(f.train.pane_px), right, 0.001, "the car pane's room as it was")
	f.train_on()
	assert_eq(f.current(), "train", "the main key goes nowhere with the paper waiting")
	assert_false(bool(f.paper.folded), "and opens the folded paper")
	assert_eq(float(f.train.pane_left_px), 0.0)
	f.paper.set_folded(true)
	f._drop_paper()
	assert_eq(float(f.train.pane_left_px), 0.0, "gone, the room goes back")
