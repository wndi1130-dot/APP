extends "res://addons/gut/test.gd"
## The train's papers on the slice's train steps, one at a time (the user 10-27: 「열차
## 단계에 서류가 오면 한 장씩 띄우고, 고르기 전엔 다음으로 못 가게 해」): the paper is up
## over the train, the main key goes nowhere till a way is chosen, then the train goes on.

const SliceFlow = preload("res://game/slice_flow.gd")


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
