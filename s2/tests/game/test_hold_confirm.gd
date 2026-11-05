extends "res://addons/gut/test.gd"
## 길게 눌러 확정 (결정 559): the hold's timing with a clock of the test's own, and
## a key given a hold doing its work only when held full.

const HoldConfirm = preload("res://game/ui/hold_confirm.gd")
const STEP: float = 1.0 / 60.0


func _hold_for(seconds: float, s: Dictionary = HoldConfirm.fresh()) -> Dictionary:
	var fired: int = 0
	var t: float = 0.0
	while t + STEP <= seconds + 0.000001:
		s = HoldConfirm.hold_step(s, STEP, true)
		fired += 1 if bool(s["fired"]) else 0
		t += STEP
	s["fired_count"] = fired
	return s


func test_let_go_before_the_full_hold_does_nothing() -> void:
	var s: Dictionary = _hold_for(0.79)
	assert_eq(int(s["fired_count"]), 0, "0.79 s held: not yet")
	assert_lt(float(s["fill"]), 1.0)
	s = HoldConfirm.hold_step(s, STEP, false)
	assert_false(bool(s["fired"]), "let go: nothing happens")
	assert_lt(float(s["fill"]), 0.99, "the line winds back")


func test_a_full_hold_fires_once_and_once_only() -> void:
	var s: Dictionary = _hold_for(HoldConfirm.HOLD_S + STEP)
	assert_eq(int(s["fired_count"]), 1, "full at 0.8 s: one work")
	s = _hold_for(2.0, s)
	assert_eq(int(s["fired_count"]), 0, "held on past full: no second work")
	assert_true(bool(s["done"]))
	s = HoldConfirm.hold_step(s, STEP, false)
	assert_eq(float(s["fill"]), 0.0, "lifted after the work: back at rest")
	s = _hold_for(HoldConfirm.HOLD_S + STEP, s)
	assert_eq(int(s["fired_count"]), 1, "a new hold works again")


func test_the_line_fills_at_one_pace() -> void:
	var half: Dictionary = _hold_for(HoldConfirm.HOLD_S * 0.5)
	assert_almost_eq(float(half["fill"]), 0.5, 0.03, "half the time, half the edge")
	var quarter: Dictionary = _hold_for(HoldConfirm.HOLD_S * 0.25)
	assert_almost_eq(float(quarter["fill"]), 0.25, 0.03)


func test_let_go_it_winds_back_in_its_time_from_where_it_stood() -> void:
	var s: Dictionary = _hold_for(HoldConfirm.HOLD_S * 0.5)
	var from: float = float(s["fill"])
	var t: float = 0.0
	while float(s["fill"]) > 0.0 and t < 1.0:
		s = HoldConfirm.hold_step(s, STEP, false)
		t += STEP
		assert_false(bool(s["fired"]))
	assert_almost_eq(t, HoldConfirm.BACK_S, STEP * 1.5, "wound back from %.2f in its own time" % from)
	assert_eq(s, HoldConfirm.fresh(), "at rest again")


func test_pressed_again_while_winding_back_it_fills_on_from_there() -> void:
	var s: Dictionary = _hold_for(HoldConfirm.HOLD_S * 0.5)
	s = HoldConfirm.hold_step(s, HoldConfirm.BACK_S * 0.5, false)
	var mid: float = float(s["fill"])
	assert_almost_eq(mid, 0.25, 0.03)
	s = HoldConfirm.hold_step(s, STEP, true)
	assert_gt(float(s["fill"]), mid, "it fills on, not from nothing")
	s = _hold_for(HoldConfirm.HOLD_S * 0.8, s)
	assert_eq(int(s["fired_count"]), 1, "and closes in the time left")


func test_a_finger_slipping_off_by_more_than_the_slip_lets_go() -> void:
	var box := Vector2(100, 52)
	assert_true(HoldConfirm.holds(Vector2(50, 26), box, 16.0), "on the key")
	assert_true(HoldConfirm.holds(Vector2(115, 26), box, 16.0), "a little past its edge")
	assert_false(HoldConfirm.holds(Vector2(117, 26), box, 16.0), "past the slip")
	assert_false(HoldConfirm.holds(Vector2(50, -17), box, 16.0))


func test_the_line_starts_at_twelve_and_goes_clockwise_round() -> void:
	var box := Vector2(100, 52)
	var whole: PackedVector2Array = HoldConfirm.edge_path(box, 6.0, 1.5, 1.0)
	assert_eq(whole[0], Vector2(50, 1.5), "twelve o'clock")
	assert_eq(whole[whole.size() - 1], whole[0], "round to where it began")
	var quarter: PackedVector2Array = HoldConfirm.edge_path(box, 6.0, 1.5, 0.25)
	var end: Vector2 = quarter[quarter.size() - 1]
	assert_gt(end.x, 50.0, "clockwise: to the right first")
	assert_eq(HoldConfirm.edge_path(box, 6.0, 1.5, 0.0).size(), 1, "nothing to draw at rest")


## 결정 561 ④: two holds owed the same work and both gone mid-flash before the
## frame ends do it twice, once each — not merged into one.
func test_two_holds_gone_mid_flash_each_do_their_work() -> void:
	var worked: Array = [0]
	var work := func() -> void: worked[0] += 1
	var keys: Array = []
	for i: int in 2:
		var key := Button.new()
		key.size = Vector2(100, 52)
		add_child(key)
		keys.append(key)
		var hold = HoldConfirm.attach(key, work)
		key.button_down.emit()
		hold.set_process(false)
		hold.advance(HoldConfirm.HOLD_S + STEP)
		assert_gt(float(hold.flash), 0.0, "full, it flashes")
	assert_eq(int(worked[0]), 0, "both still flashing")
	for key: Button in keys:
		key.free()
	assert_eq(int(worked[0]), 0, "owed, not yet done")
	await get_tree().process_frame
	assert_eq(int(worked[0]), 2, "each owed work done once")
	await get_tree().process_frame
	assert_eq(int(worked[0]), 2, "and no more")


## 결정 561 ④: gone mid-flash, the owed work runs at the frame's end — unless its
## owner went first (the HUD freed with its field), when it is dropped, quietly.
func test_an_owed_work_runs_unless_its_owner_went_first() -> void:
	for keeper_goes: bool in [false, true]:
		var keeper := Node.new()
		add_child(keeper)
		var key := Button.new()
		key.size = Vector2(100, 52)
		add_child(key)
		var hold = HoldConfirm.attach(key, keeper.set_meta.bind("worked", true))
		key.button_down.emit()
		hold.set_process(false)
		hold.advance(HoldConfirm.HOLD_S + STEP)
		assert_gt(float(hold.flash), 0.0, "full, it flashes")
		key.free()
		if keeper_goes:
			keeper.free()
			await get_tree().process_frame
			assert_false(is_instance_valid(keeper), "the keeper went first: the work is dropped")
		else:
			await get_tree().process_frame
			assert_true(bool(keeper.get_meta("worked", false)), "the keeper still there: the owed work ran")
			keeper.free()


func test_a_key_given_a_hold_works_only_when_held_full() -> void:
	var key := Button.new()
	key.size = Vector2(100, 52)
	add_child_autofree(key)
	var worked: Array = [0]
	var hold = HoldConfirm.attach(key, func() -> void: worked[0] += 1)
	key.pressed.emit()
	assert_eq(int(worked[0]), 0, "a tap does nothing")
	key.button_down.emit()
	for _i in range(int(ceil(HoldConfirm.HOLD_S * 0.5 / STEP))):
		hold.advance(STEP)
	key.button_up.emit()
	for _i in range(30):
		hold.advance(STEP)
	assert_eq(int(worked[0]), 0, "let go at half: nothing")
	assert_eq(float(hold.state["fill"]), 0.0, "wound back")
	key.button_down.emit()
	for _i in range(int(ceil(HoldConfirm.HOLD_S / STEP)) + 1):
		hold.advance(STEP)
	assert_gt(float(hold.flash), 0.0, "full: the face flashes first (결정 561 ④)")
	assert_eq(int(worked[0]), 0, "the work waits for the flash")
	for _i in range(int(ceil(HoldConfirm.FLASH_S / STEP)) + 2):
		hold.advance(STEP)
	assert_eq(float(hold.flash), 0.0)
	assert_eq(int(worked[0]), 1, "held full: the work, once, as the flash ends")
	key.button_up.emit()
	hold.advance(STEP)
	assert_eq(float(hold.state["fill"]), 0.0)
