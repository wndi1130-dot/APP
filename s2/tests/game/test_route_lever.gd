extends "res://addons/gut/test.gd"
## The stop ahead on the departure lever's small line (decisions 471 B0, 474 N2, 475; the user
## 10-27: 「노선표 아래 띠 끝과 열차 화면 출발 레버의 작은 줄 둘 다」): before the stop the
## train's main key is the lever, its small line the arrival and the weather the stop then has.

const SliceFlow = preload("res://game/slice_flow.gd")
const LeverKey = preload("res://game/ui/lever_key.gd")
const HomeBar = preload("res://game/ui/home_bar.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")


func test_the_lever_shows_the_stop_ahead_and_the_stop_keeps_it() -> void:
	var f = SliceFlow.new()
	f.opts = {"skip_field": true, "seed": 13, "cinema": false}
	add_child_autofree(f)
	assert_eq(f.current(), "train")
	var line: String = f.next_stop_line()
	assert_true(f.bar.main_key is LeverKey, "before the stop the main key is the departure lever")
	assert_eq(f.bar.lever_small, line, "its small line is the stop ahead")
	var w: Dictionary = f.stop_weather(f._season_seg(2))
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


## Both lines whole on the plate (the coordinator 10-27: 「정차 고르기」 and 「11:10 도착 · 진눈깨비」
## both uncut): the plate widens for the longest stop line, the word stays the act it was.
func test_the_plate_holds_both_lines_whole() -> void:
	for small in ["11:10 도착 · 진눈깨비", "00:00 도착 · 맑은 추위", "10:00 도착 · 비"]:
		var lk = LeverKey.new("정차 고르기", small)
		add_child_autofree(lk)
		var room: float = (lk.face_w - LeverKey.FACE_PAD * 2.0) * UiFonts.K
		assert_lte(lk.ink_w(lk.get_node("Body/Word")), room, "the word fits beside %s" % small)
		assert_lte(lk.ink_w(lk.get_node("Body/Small")), room, "%s fits" % small)
		assert_almost_eq(lk.custom_minimum_size.x, (lk.face_w + 46.0) * UiFonts.K, 0.01, "the housing rides at the plate's right")
	var vote = LeverKey.new("표결", "")
	add_child_autofree(vote)
	assert_eq(vote.face_w, LeverKey.FACE_CSS.x, "a word alone keeps the plate as drawn")


## On the narrowest phone (16:9, the 1280 × 720 the game is laid out on) and on
## 1688 × 780 (1558 wide), the wider lever pushes the overview left and the rooms'
## words keep 10 between them (the coordinator 10-27: not one run of words).
func test_the_band_makes_room_for_the_wider_lever() -> void:
	for wide in [1280.0, 1558.0]:
		var host := Control.new()
		host.size = Vector2(wide, 720.0)
		add_child_autofree(host)
		var b = HomeBar.new()
		b.main_word = "정차 고르기"
		b.lever = true
		b.lever_small = "00:00 도착 · 맑은 추위"
		host.add_child(b)
		var k: float = UiFonts.K
		var main: Control = b.get_node("Main")
		var over: Control = b.get_node("Key_overview")
		assert_almost_eq(main.position.x + main.size.x, wide - 12.0 * k, 0.5, "the lever ends 12 in at %d" % wide)
		assert_lte(over.position.x + 44.0 * k, main.position.x, "the overview clears the lever at %d" % wide)
		var rooms: Array = []
		for c in b.get_children():
			if String(c.name).begins_with("Room_"):
				rooms.append(c)
		assert_eq(rooms.size(), 6)
		for i in range(1, rooms.size()):
			var l0: Label = rooms[i - 1].get_node("Word")
			var l1: Label = rooms[i].get_node("Word")
			var gap: float = rooms[i].position.x + l1.position.x - (rooms[i - 1].position.x + l0.position.x + GlassParts.text_w(l0))
			assert_gte(gap, 10.0 * k, "%s and %s apart at %d" % [l0.text, l1.text, wide])
		assert_gte(over.position.x - (rooms[5].position.x + 47.0 * k), 12.0 * k - 0.5, "the last room clears the overview at %d" % wide)
