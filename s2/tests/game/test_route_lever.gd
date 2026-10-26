extends "res://addons/gut/test.gd"
## The stop ahead on the departure lever's small line (decisions 471 B0, 474 N2, 475; the user
## 10-27: 「노선표 아래 띠 끝과 열차 화면 출발 레버의 작은 줄 둘 다」): before the stop the
## train's main key is the lever, its small line the arrival and the weather the stop then has.

const SliceFlow = preload("res://game/slice_flow.gd")
const LeverKey = preload("res://game/ui/lever_key.gd")


func test_the_lever_shows_the_stop_ahead_and_the_stop_keeps_it() -> void:
	var f = SliceFlow.new()
	f.opts = {"skip_field": true, "seed": 13, "cinema": false}
	add_child_autofree(f)
	assert_eq(f.current(), "train")
	var line: String = f.next_stop_line()
	assert_true(f.bar.main_key is LeverKey, "before the stop the main key is the departure lever")
	assert_eq(f.bar.lever_small, line, "its small line is the stop ahead")
	var w: Dictionary = f.stop_weather(2)
	var word: String = "비" if String(w["falls"]) == "rain" else String(SliceFlow.WEATHER_WORD[String(w["weather"])])
	f.next()
	assert_eq(f.current(), "stop_pick")
	var at := int(f._field_opts()["arrive_min"])
	assert_eq(line, "%02d:%02d 도착 · %s" % [floori(at / 60.0), at % 60, word], "the field comes in when and as the lever said")
	assert_eq(f.next_stop_line(), "", "at the stop the line is gone")


func test_a_told_arrival_is_the_one_shown() -> void:
	var f = SliceFlow.new()
	f.opts = {"skip_field": true, "seed": 13, "cinema": false, "arrive_min": 890}
	add_child_autofree(f)
	assert_string_starts_with(f.next_stop_line(), "14:50 도착 · ")
