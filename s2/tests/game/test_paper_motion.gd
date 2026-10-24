extends "res://addons/gut/test.gd"
## A sheet coming on and going off (paper_motion.gd, 사용자 2026-10-24): it
## starts below and folded, ends lying exactly where it lies (its corner, turn
## and shadow untouched), its keys answer the whole time, and seen before it
## takes half the time.

const PaperMotion = preload("res://game/ui/paper_motion.gd")
const PaperSheet = preload("res://game/ui/paper_sheet.gd")


func _sheet() -> Control:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child_autofree(host)
	var s = PaperSheet.new()
	s.position = Vector2(-10, 50)
	host.add_child(s)
	return s


func test_it_comes_in_folded_from_below_and_lies_down_where_it_lies() -> void:
	var s := _sheet()
	var at: Vector2 = s.position
	var turn: float = s.rotation
	var pivot: Vector2 = s.pivot_offset
	var shadow_at: Vector2 = s._shadow.position
	var tw := PaperMotion.open(s)
	assert_almost_eq(s.scale.x, PaperMotion.FOLDED, 0.001, "half shut along its crease as it starts")
	assert_gt(s.get_global_rect().position.y, at.y + 100.0, "down below where it will lie")
	assert_eq(s._paper.mouse_filter, Control.MOUSE_FILTER_STOP, "the paper still takes the finger")
	tw.custom_step(PaperMotion.OPEN_S * 0.55)
	assert_gt(s.scale.x, PaperMotion.FOLDED, "opening out")
	tw.custom_step(PaperMotion.OPEN_S)
	assert_false(tw.is_running())
	assert_eq(s.position, at, "where it lies")
	assert_eq(s.rotation, turn, "its own lean")
	assert_eq(s.pivot_offset, pivot, "its own corner")
	assert_eq(s.scale, Vector2.ONE)
	assert_eq(s._shadow.position, shadow_at, "its shadow settled under it")
	assert_eq(s.modulate.a, 1.0)


func test_it_folds_away_and_seen_before_both_take_half_the_time() -> void:
	var s := _sheet()
	var at: Vector2 = s.position
	var tw := PaperMotion.open(s, true)
	tw.custom_step(PaperMotion.OPEN_S * PaperMotion.SHORT + 0.01)
	assert_false(tw.is_running(), "seen before: in half the time")
	assert_eq(s.position, at)
	var out := PaperMotion.close(s)
	out.custom_step(PaperMotion.CLOSE_S * 0.5)
	assert_lt(s.scale.x, 1.0, "folding shut")
	out.custom_step(PaperMotion.CLOSE_S)
	assert_false(out.is_running())
	assert_almost_eq(s.modulate.a, 0.0, 0.001, "gone")
	assert_gt(s.get_global_rect().position.y, at.y + 100.0, "slid away below")


func test_closing_while_it_is_still_coming_in_takes_it_from_where_it_lies() -> void:
	var s := _sheet()
	var at: Vector2 = s.position
	var tw := PaperMotion.open(s)
	tw.custom_step(PaperMotion.OPEN_S * 0.3)
	var out := PaperMotion.close(s)
	assert_false(tw.is_valid() and tw.is_running(), "the coming in stops")
	out.custom_step(0.0001)
	assert_almost_eq(s.scale.x, 1.0, 0.01, "from lying flat, not half open")
	assert_almost_eq(s.position.distance_to(at), 0.0, 40.0)
