extends "res://addons/gut/test.gd"
## The train's home (UI 시안 2차 01 내정): the carriage's pane (car_pane.gd)
## reads the train's own numbers, says cold under the threshold of 45 and
## asks for a lever without setting it; the keys along the bottom
## (home_bar.gd) stand where the mockup's do.

const CarPane = preload("res://game/ui/car_pane.gd")
const HomeBar = preload("res://game/ui/home_bar.gd")
const StopPickCard = preload("res://game/ui/stop_pick_card.gd")
const St = preload("res://game/train/train_state.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")

const TAIL := {"id": "tail1", "kind": "comm", "comm": "tail", "name": "꼬리칸 1", "plate": "꼬리"}


func _pane(g: Dictionary, t: Dictionary) -> Control:
	var pane = CarPane.new()
	add_child_autofree(pane)
	pane.show_car(TAIL, g, t)
	return pane


func test_the_pane_says_the_cars_own_numbers() -> void:
	var s: Array = StopPickCard.sample()
	var g: Dictionary = s[0]
	var t: Dictionary = s[1]
	var m: Dictionary = CarPane.model(g, t, TAIL)
	var sit: Array = St.situation(g, t, "tail")
	assert_eq(m["name"], "꼬리칸 1")
	assert_eq(m["pop"], int(g["comms"]["tail"]["pop"]))
	assert_eq(m["warm"], int(round(float(sit[0]))))
	for i in 3:
		assert_eq(m["stats"][i]["n"], int(round(float(sit[i + 1]))), String(m["stats"][i]["word"]))
	assert_eq(m["levers"][0]["step"], int(g["comms"]["tail"]["heat"]))
	assert_eq(m["levers"][1]["step"], int(g["comms"]["tail"]["ration"]))
	assert_eq(CarPane.model(g, t, {"id": "engine", "kind": "engine", "name": "기관실"}), {}, "a car with no people of its own has no pane")


func test_cold_is_under_the_threshold_of_45() -> void:
	var s: Array = StopPickCard.sample()
	var t: Dictionary = s[1]
	var seen: Dictionary = {}
	for heat in 5:
		var g: Dictionary = (s[0] as Dictionary).duplicate(true)
		g["comms"]["tail"]["heat"] = heat
		var warm: float = float(St.situation(g, t, "tail")[0])
		var m: Dictionary = CarPane.model(g, t, TAIL)
		assert_eq(m["cold"], warm < 45.0, "heat %d, warmth %.1f" % [heat, warm])
		assert_eq(m["say"], "밤사이 앓는 사람 늘어남" if warm < 45.0 else "견딜 만함")
		seen[warm < 45.0] = true
	assert_eq(seen.size(), 2, "the heating lever takes the tail across the threshold")


func test_the_lever_word_reads_s1_gauge_value() -> void:
	assert_eq(CarPane.need_of(37.4), "부족", "(37.4 − 45) / 25 is past −.3")
	assert_eq(CarPane.need_of(37.6), "적정")
	assert_eq(CarPane.need_of(45.0), "적정")
	assert_eq(CarPane.need_of(70.0), "적정")
	assert_eq(CarPane.need_of(77.4), "적정")
	assert_eq(CarPane.need_of(77.6), "여유", "(77.6 − 70) / 25 is past .3")


func test_each_bar_turns_amber_on_the_bad_side_of_its_mark() -> void:
	var s: Array = StopPickCard.sample()
	var sit: Array = St.situation(s[0], s[1], "tail")
	var m: Dictionary = CarPane.model(s[0], s[1], TAIL)
	assert_eq(m["stats"][0]["bad"], float(sit[1]) < 45.0, "ration: under 45")
	assert_eq(m["stats"][1]["bad"], float(sit[2]) > 60.0, "crowding: over 60")
	assert_eq(m["stats"][2]["bad"], float(sit[3]) > 50.0, "exposure: over 50")


func test_the_pane_draws_what_the_model_says() -> void:
	var s: Array = StopPickCard.sample()
	var g: Dictionary = (s[0] as Dictionary).duplicate(true)
	var t: Dictionary = s[1]
	g["comms"]["tail"]["heat"] = 0
	var pane := _pane(g, t)
	var m: Dictionary = CarPane.model(g, t, TAIL)
	assert_true(bool(m["cold"]), "no heating: cold")
	assert_eq((pane.find_child("Warmth", true, false) as Label).text, str(m["warm"]))
	assert_not_null(pane.find_child("Tag", true, false), "the paper tag hangs when cold")
	assert_eq((pane.find_child("Need_heat", true, false) as Label).text, m["levers"][0]["need"])
	g["comms"]["tail"]["heat"] = 4
	pane.refresh(g, t)
	await wait_frames(1)
	if not bool(CarPane.model(g, t, TAIL)["cold"]):
		assert_null(pane.find_child("Tag", true, false), "warm: no tag")


func test_a_step_asks_for_the_lever_and_one_under_the_laws_floor_does_not() -> void:
	var s: Array = StopPickCard.sample()
	var g: Dictionary = (s[0] as Dictionary).duplicate(true)
	var t: Dictionary = (s[1] as Dictionary).duplicate(true)
	t["LAWS_RES"]["test_heat_floor"] = {"heatFloor": 2}
	var passed: Dictionary = g.get("passed", {})
	passed["test_heat_floor"] = 1
	g["passed"] = passed
	g["comms"]["tail"]["heat"] = 2
	var pane := _pane(g, t)
	watch_signals(pane)
	var slot: Control = pane.find_child("Slot_heat", true, false)
	(slot.get_node("Step1") as Button).pressed.emit()
	assert_signal_not_emitted(pane, "lever_set", "under the law's floor: it shakes instead")
	(slot.get_node("Step2") as Button).pressed.emit()
	assert_signal_not_emitted(pane, "lever_set", "the step it is on: nothing to ask")
	(slot.get_node("Step3") as Button).pressed.emit()
	assert_signal_emitted_with_parameters(pane, "lever_set", ["tail", "heat", 3])


func test_fold_asks_to_fold() -> void:
	var s: Array = StopPickCard.sample()
	var pane := _pane(s[0], s[1])
	watch_signals(pane)
	(pane.find_child("Fold", true, false) as Button).pressed.emit()
	assert_signal_emitted(pane, "folded")


func test_the_keys_stand_where_the_mockups_do() -> void:
	var holder := Control.new()
	holder.size = Vector2(844.0, 390.0) * UiFonts.K
	add_child_autofree(holder)
	var bar = HomeBar.new()
	bar.main_word = "정차 고르기"
	holder.add_child(bar)
	await wait_frames(2)
	var k: float = UiFonts.K
	# Measured off 01_내정_나눔가_B1 (.hud--bot, mockup px).
	var want: Dictionary = {"Key_menu": 12.0, "Key_book": 64.0, "Room_papers": 126.0, "Room_wrench": 211.8,
		"Room_gear": 297.6, "Room_people": 383.4, "Room_scale": 469.2, "Room_bed": 555.0, "Key_overview": 632.0, "Main": 684.0}
	for key: String in want:
		var c: Control = bar.get_node(key)
		assert_almost_eq(c.position.x / k, float(want[key]), 1.5, key)
	assert_almost_eq((bar.get_node("Main") as Control).size.x / k, 148.0, 1.0, "the main key 148 wide")


func test_the_care_room_counts_who_is_hurt_or_sick() -> void:
	assert_eq(HomeBar.badges({}), ["", "", "", "", "", ""])
	assert_eq(HomeBar.badges({"injured": 2, "sickCount": 1}), ["", "", "", "", "", "3"])
