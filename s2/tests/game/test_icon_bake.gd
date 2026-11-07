extends "res://addons/gut/test.gd"
## 물건 그림 굽기 도구(icon_bake.gd)의 칸 채움과 테두리(코디 2026-11-07): 그려진 부분을 재어 카메라를
## 옮기고 당겨 모든 물건이 칸을 같은 만큼 채우고, 어두운 선 바깥에 옅은 테두리를 둘러 어두운
## 유리 바탕에서도 갈린다. 굽기 자체는 그리는 창이 있어야 해서 시험은 순수한 셈만 본다.

const SIZE: int = 256


func _bake() -> Script:
	return load("res://tools/icon_bake.gd") as Script


func _const(name: String) -> Variant:
	return _bake().get_script_constant_map()[name]


func test_a_small_middle_drawing_is_zoomed_in_and_not_moved() -> void:
	var fit: Dictionary = _bake().call("refit", Rect2i(78, 78, 100, 100), SIZE, 0.12)
	assert_true(bool(fit["off"]))
	assert_almost_eq(float(fit["scale"]), 100.0 / (256.0 * 0.76), 0.0001, "the camera closes in")
	assert_eq(fit["shift"], Vector2.ZERO, "already in the middle")


func test_a_drawing_off_to_one_side_moves_the_camera_after_it() -> void:
	# 194 px wide at margin 0.12 (194.56 fills it), its middle 20 px right of the square's and 10 down.
	var fit: Dictionary = _bake().call("refit", Rect2i(51, 78, 194, 120), SIZE, 0.12)
	assert_eq(fit["shift"], Vector2(20, 10), "x right, y down, from the square's middle")
	assert_true(bool(fit["off"]))
	assert_almost_eq(float(fit["scale"]), 194.0 / 194.56, 0.0001)


func test_a_drawing_that_already_fills_the_square_is_left() -> void:
	var fit: Dictionary = _bake().call("refit", Rect2i(31, 60, 195, 136), SIZE, 0.12)
	assert_false(bool(fit["off"]), "within FIT_TOLERANCE: no more tries")


func test_a_drawing_cut_by_the_square_is_zoomed_out() -> void:
	var fit: Dictionary = _bake().call("refit", Rect2i(0, 20, 256, 210), SIZE, 0.12)
	assert_gt(float(fit["scale"]), 1.0, "the camera stands back to see all of it")


func test_the_room_left_to_the_edges_is_the_smallest_gap() -> void:
	var bake := _bake()
	assert_eq(bake.call("edge_room", Rect2i(15, 20, 226, 200), SIZE), 15, "left, as 256 - 241 is 15 too")
	assert_eq(bake.call("edge_room", Rect2i(30, 40, 100, 214), SIZE), 2, "two pixels under it")
	assert_eq(bake.call("edge_room", Rect2i(0, 40, 100, 100), SIZE), 0, "on the left edge")
	assert_eq(bake.call("edge_room", Rect2i(200, 40, 60, 100), SIZE), -4, "past the right edge")
	assert_gte(int(_const("EDGE_ROOM")), 2, "room for the dark line and the pale rim")


func test_a_run_succeeds_only_when_every_thing_was_saved() -> void:
	var bake := _bake()
	var saved: Dictionary = {"name": "rusk", "saved": true}
	var warned: Dictionary = {"name": "nails", "saved": true, "warning": "fit off"}
	var failed: Dictionary = {"name": "hardtack", "error": "one or more PNG writes failed"}
	assert_eq(bake.call("exit_code", [saved, warned], []), 0, "a fit warning alone does not fail the run")
	assert_eq(bake.call("exit_code", [saved, failed], []), 1, "one thing not saved fails it")
	assert_eq(bake.call("exit_code", [saved], ["sheet: viewport readback failed"]), 1, "the sheet failing fails it")
	assert_eq(bake.call("exit_code", [], []), 1, "a list with nothing on it is a failed run")


func test_the_record_says_what_this_run_saved_and_failed() -> void:
	var lines: PackedStringArray = _bake().call("record_lines", [
		{"name": "rusk", "saved": true},
		{"name": "nails", "saved": true, "warning": "fit off"},
		{"name": "hardtack", "error": "drawing reaches the edge"},
		{"name": "flour"},
	], ["sheet: viewport readback failed"])
	assert_eq(Array(lines), [
		"run_failed\tsheet: viewport readback failed",
		"saved\trusk",
		"warned\tnails\tfit off",
		"failed\thardtack\tdrawing reaches the edge",
		"failed\tflour\tnot reached",
	])


func test_the_dark_line_and_the_pale_rim_lie_round_the_thing_behind_it() -> void:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.fill_rect(Rect2i(100, 100, 56, 56), Color(0.4, 0.4, 0.4, 1.0))
	var bake := _bake()
	var muted: Image = bake.call("_make_muted", image)
	var inside: Color = muted.get_pixel(120, 120)
	assert_almost_eq(inside.a, 1.0, 0.001, "the thing itself as drawn")
	assert_almost_eq(inside.r, 0.4, 0.01)
	var line: Color = muted.get_pixel(99, 120)
	assert_almost_eq(line.a, 0.5, 0.01, "a dark line one pixel out, half strength")
	assert_almost_eq(line.r, (_const("OUTLINE") as Color).r, 0.01)
	var rim: Color = muted.get_pixel(98, 120)
	assert_almost_eq(rim.a, float(_const("RIM_ALPHA")), 0.01, "the pale rim one pixel further")
	assert_almost_eq(rim.r, (_const("RIM") as Color).r, 0.01)
	assert_eq(muted.get_pixel(96, 120).a, 0.0, "and nothing beyond")
	assert_almost_eq(muted.get_pixel(98, 98).a, float(_const("RIM_ALPHA")), 0.01, "round the corner too")
