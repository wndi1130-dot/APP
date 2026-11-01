extends "res://addons/gut/test.gd"
## Decisions 531/532: reusable glass motion, outside taps and sleeping bag HUD.
## These tests use the same HUD input entry point as the neighboring touch tests.

const FieldGame = preload("res://game/field_game.gd")
const FieldHud = preload("res://game/ui/field_hud.gd")
const GlassPane = preload("res://game/ui/glass_pane.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")


func _game() -> FieldGame:
	var game: FieldGame = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "arrive": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	return game


func _settle() -> void:
	await get_tree().create_timer(0.25).timeout
	for node: Node in get_tree().root.find_children("Pane", "", true, false):
		if node is GlassPane:
			_land(node as GlassPane)


## Fixed 1/60 s steps of a pane's slide, the wall clock out of it.
func _steps(pane: GlassPane, count: int) -> void:
	pane.set_process(false)
	for _i in range(count):
		pane.motion_step(1.0 / 60.0)


func _land(pane: GlassPane) -> void:
	pane.set_process(false)
	for _i in range(120):
		if not pane.is_sliding():
			return
		pane.motion_step(1.0 / 60.0)


func _touch(hud: FieldHud, at: Vector2, pressed: bool, index: int = 0, canceled: bool = false) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	event.canceled = canceled
	hud._input(event)


func _drag(hud: FieldHud, at: Vector2, index: int = 0) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = at
	hud._input(event)


func _mouse(hud: FieldHud, at: Vector2, pressed: bool, emulated: bool = false) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = pressed
	event.device = InputEvent.DEVICE_ID_EMULATION if emulated else 0
	hud._input(event)


func _outside(hud: FieldHud) -> Vector2:
	return Vector2(4.0 if hud.modal_pane.motion_direction.x > 0.0 else hud._view_size().x - 4.0, hud._view_size().y - 4.0)


func _assert_no_field_input(hud: FieldHud) -> void:
	assert_eq(hud.stick_index, -1)
	assert_eq(hud.game.player.stick, Vector2.ZERO)
	assert_true(hud.fingers.is_empty())
	assert_false(hud.pressing or hud.aiming or hud.auto_aim)


func _assert_ignored(node: Node) -> void:
	if node is Control:
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for child: Node in node.get_children():
		_assert_ignored(child)


func _box(game: FieldGame) -> String:
	for id: String in game.data["containers"]:
		var box: Dictionary = game.data["containers"][id]
		if int(box.get("level", 0)) == 0 and not bool(box.get("locked", false)) and not box.has("pick") and not game.FieldMaps.by_train(game.data, box["cell"], "unloading"):
			box["searched"] = true
			box["items"] = ["food_pack"]
			game.player.position = game.actions._container_at(box)
			game.player.stop()
			return id
	fail_test("a searched box is available in the fixed map")
	return ""


func _start_take(game: FieldGame) -> String:
	game.player.items.clear()
	var id: String = _box(game)
	game.hud.loot(id)
	var rows: Node = game.hud.modal.find_child("Near", true, false)
	for node: Node in rows.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if String(button.get_meta("item_id", "")) == "food_pack":
			button.pressed.emit()
			return id
	fail_test("the food row starts the take")
	return id


func test_bag_enters_from_right_and_fades_before_it_stops() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	hud.bag_panel()
	var pane: GlassPane = hud.modal_pane
	var shade: ColorRect = hud.modal.get_node("Shade") as ColorRect
	pane.set_process(false)
	assert_almost_eq(pane.position.x, hud._view_size().x, 1.0, "the first picture is one pane width outside")
	assert_almost_eq(pane.modulate.a, 0.0, 0.001)
	assert_almost_eq(shade.modulate.a, 0.0, 0.001)
	pane.motion_step(0.5)
	assert_almost_eq(pane.position.x, hud._view_size().x, 1.0, "the frame that built it does not move it")
	_steps(pane, 6)
	assert_almost_eq(pane.modulate.a, 1.0, 0.02, "the pane fades in during the first half")
	assert_gt(shade.modulate.a, 0.0)
	assert_gt(pane.position.x, pane.resting_position().x + 0.5, "still coming in at 100 ms")
	_steps(pane, 6)
	assert_almost_eq(pane.position.x, pane.resting_position().x, 0.5)
	assert_almost_eq(shade.modulate.a, 1.0, 0.001)
	assert_false(pane.is_moving())


func test_rebuilding_or_switching_panes_does_not_slide() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	hud.bag_panel()
	var first: Control = hud.modal
	hud.bag_panel()
	assert_ne(hud.modal, first)
	assert_almost_eq(hud.modal_pane.position.x, hud.modal_pane.resting_position().x, 0.5)
	assert_eq(hud.modal_pane.modulate.a, 1.0)
	assert_false(hud.modal_pane.is_moving())
	assert_null(hud.closing_modal)
	hud.body_panel()
	assert_eq(hud.modal_pane.position.x, 0.0)
	assert_eq(hud.modal_pane.modulate.a, 1.0)
	hud.bag_panel()
	assert_almost_eq(hud.modal_pane.position.x, hud.modal_pane.resting_position().x, 0.5)
	assert_eq(hud.modal_pane.modulate.a, 1.0)
	await _settle()
	assert_almost_eq(hud.modal_pane.position.x, hud.modal_pane.resting_position().x, 0.5)


func test_close_restores_state_at_once_and_frees_the_exit_picture() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	hud.bag_panel()
	_land(hud.modal_pane)
	var old: Control = hud.modal
	var pane: GlassPane = hud.modal_pane
	var from_x: float = pane.position.x
	pane.folded.emit()
	pane.set_process(false)
	assert_null(hud.modal)
	assert_false(hud.modal_open)
	assert_false(game.paused)
	assert_eq(game.slow, 1.0)
	assert_eq(hud.closing_modal, old)
	_assert_ignored(old)
	_steps(pane, 4)
	assert_gt(pane.position.x, from_x)
	assert_lt(pane.modulate.a, 1.0)
	_steps(pane, 6)
	assert_true(old.is_queued_for_deletion())
	assert_null(hud.closing_modal)
	await get_tree().process_frame
	assert_false(is_instance_valid(old))


func test_fresh_field_touches_work_while_the_picture_leaves() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	hud.bag_panel()
	await _settle()
	hud._close_modal()
	assert_not_null(hud.closing_modal)
	var home: Vector2 = hud.stick_home()
	_touch(hud, home, true, 2)
	_drag(hud, home + Vector2(hud.STICK_R, 0.0), 2)
	assert_eq(hud.stick_index, 2)
	assert_ne(game.player.stick, Vector2.ZERO)
	_touch(hud, home + Vector2(hud.STICK_R, 0.0), false, 2)
	var run_at: Vector2 = hud.run_button.get_global_rect().get_center()
	var running: bool = hud.run_button.button_pressed
	_touch(hud, run_at, true, 3)
	_touch(hud, run_at, false, 3)
	assert_ne(hud.run_button.button_pressed, running, "a fresh HUD press works during the exit too")


func test_reopening_drops_the_old_picture_and_enters_again() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	hud.bag_panel()
	_land(hud.modal_pane)
	hud._close_modal()
	var old: Control = hud.closing_modal
	hud.bag_panel()
	assert_false(old.visible)
	assert_true(old.is_queued_for_deletion())
	assert_null(hud.closing_modal)
	assert_true(hud.modal_open and game.paused)
	assert_almost_eq(hud.modal_pane.position.x, hud._view_size().x, 1.0)
	assert_eq(hud.modal_pane.modulate.a, 0.0)
	_land(hud.modal_pane)
	await get_tree().process_frame
	assert_false(is_instance_valid(old))
	assert_almost_eq(hud.modal_pane.position.x, hud.modal_pane.resting_position().x, 0.5)


func test_left_pane_leaves_left_and_restores_the_body_rate() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	hud.body_panel()
	assert_almost_eq(hud.modal_pane.position.x, -UiFonts.px(GlassPane.IN_FROM), 0.5)
	_land(hud.modal_pane)
	var old: Control = hud.modal
	var pane: GlassPane = hud.modal_pane
	hud._close_modal()
	pane.set_process(false)
	assert_null(hud.modal)
	assert_eq(game.slow, 1.0)
	assert_false(game.paused)
	_steps(pane, 4)
	assert_lt(pane.position.x, 0.0)
	assert_gte(pane.position.x, -UiFonts.px(GlassPane.IN_FROM) - 0.5)
	assert_lt(pane.modulate.a, 1.0)
	_steps(pane, 6)
	assert_true(old.is_queued_for_deletion())
	await get_tree().process_frame
	assert_false(is_instance_valid(old))


func test_outside_taps_fold_bag_body_and_settings_without_field_input() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	var target: Dictionary = game.zombies.spawn("dead", game.player.position + Vector3(3.0, 0.0, 0.0))
	game.player.target_zombie = target
	for open: Callable in [hud.bag_panel, hud.body_panel, hud.settings_panel]:
		open.call()
		await _settle()
		var at: Vector2 = _outside(hud)
		var running: bool = hud.run_button.button_pressed
		var lamps: bool = game.lamps_on()
		_touch(hud, at, true)
		assert_true(hud.modal_open, "only a lift can fold it")
		_touch(hud, at, false)
		assert_null(hud.modal)
		assert_false(hud.modal_open)
		assert_eq(hud.run_button.button_pressed, running)
		assert_eq(game.lamps_on(), lamps)
		assert_eq(game.player.target_zombie, target, "no field tap called off the target")
		_assert_no_field_input(hud)


func test_settings_outside_tap_returns_to_the_pause_screen() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	game.paused = true
	hud.settings_panel()
	await _settle()
	var at: Vector2 = _outside(hud)
	_mouse(hud, at, true)
	_mouse(hud, at, false)
	assert_null(hud.modal)
	assert_true(game.paused)
	hud.tick(0.016)
	assert_true(hud.settings_button.visible)
	_assert_no_field_input(hud)


func test_sleeping_hud_taps_only_fold_the_bag() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	for control: Control in [hud.run_button, hud.lamp_button, hud.bag_button, hud.portrait, hud.pause_button]:
		hud.bag_panel()
		hud.lamp_button.visible = true
		await _settle()
		var at: Vector2 = control.get_global_rect().get_center()
		assert_false(hud.modal_pane.get_global_rect().has_point(at))
		var running: bool = hud.run_button.button_pressed
		var lamps: bool = game.lamps_on()
		_touch(hud, at, true)
		_touch(hud, at, false)
		assert_null(hud.modal, "the sleeping key only folds the bag")
		assert_eq(hud.run_button.button_pressed, running)
		assert_eq(game.lamps_on(), lamps)
		assert_false(game.paused, "the sleeping pause key did not toggle")
		_assert_no_field_input(hud)


func test_inside_start_outside_lift_does_not_fold() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	hud.bag_panel()
	await _settle()
	var inside: Vector2 = hud.modal_pane.get_global_rect().get_center()
	var outside: Vector2 = _outside(hud)
	for index: int in [0, 1]:
		_touch(hud, inside, true, index)
		_drag(hud, outside, index)
		_touch(hud, outside, false, index)
		assert_true(hud.modal_open)
	_assert_no_field_input(hud)


func test_outside_drag_long_hold_cancel_and_inside_lift_do_not_fold() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	hud.bag_panel()
	await _settle()
	var at: Vector2 = _outside(hud)
	_touch(hud, at, true)
	_drag(hud, at + Vector2(hud.DRAG_PX * 2.0, 0.0))
	_drag(hud, at)
	_touch(hud, at, false)
	assert_true(hud.modal_open, "returning after a drag is not a tap")
	_touch(hud, at, true)
	hud.modal_fingers[0]["ms"] = Time.get_ticks_msec() - 400
	_touch(hud, at, false)
	assert_true(hud.modal_open, "a long hold is not a short tap")
	_touch(hud, at, true)
	_touch(hud, at, false, 0, true)
	assert_true(hud.modal_open, "a cancel is not a lift")
	_touch(hud, at, true)
	_touch(hud, hud.modal_pane.get_global_rect().get_center(), false)
	assert_true(hud.modal_open, "the lift must also be outside")
	_assert_no_field_input(hud)


func test_other_outside_fingers_and_emulated_mouse_cannot_leak_after_close() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	hud.bag_panel()
	await _settle()
	var at: Vector2 = hud.stick_home()
	_touch(hud, at, true)
	_mouse(hud, at, true, true)
	_touch(hud, at, true, 1)
	_touch(hud, at, false)
	assert_null(hud.modal)
	_mouse(hud, at, false, true)
	_drag(hud, at + Vector2(hud.STICK_R, 0.0), 1)
	_touch(hud, at + Vector2(hud.STICK_R, 0.0), false, 1)
	_assert_no_field_input(hud)
	assert_eq(hud.stick_tap_ms, -10000, "no swallowed lift became a field tap")


func test_cards_centered_choices_and_resume_block_outside_taps() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	var calls: Array[String] = []
	hud.card("motion-test", "고르기. 한 가지를 고른다.", [{"id": "keep", "label": "그대로"}], func(choice: String) -> void: calls.append(choice))
	var at: Vector2 = Vector2(2.0, hud._view_size().y - 2.0)
	_touch(hud, at, true)
	_touch(hud, at, false)
	assert_true(hud.modal_open)
	assert_true(calls.is_empty())
	hud.depart_card()
	_touch(hud, at, true, 1)
	_touch(hud, at, false, 1)
	assert_true(hud.modal_open)
	assert_false(game.ended)
	hud._open_modal()
	_mouse(hud, at, true)
	_mouse(hud, at, false)
	assert_true(hud.modal_open)
	hud.show_resume()
	_touch(hud, at, true)
	_touch(hud, at, false)
	assert_true(hud.modal_open and game.resume_pending)
	_assert_no_field_input(hud)
	game.resume_pending = false
	hud._close_modal()


func test_back_uses_the_same_close_path() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	var quit_before: bool = get_tree().is_quit_on_go_back()
	hud.bag_panel()
	var event: InputEventAction = InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	hud._input(event)
	assert_null(hud.modal)
	assert_not_null(hud.closing_modal)
	hud.bag_panel()
	assert_false(get_tree().is_quit_on_go_back())
	hud._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_null(hud.modal)
	assert_false(game.paused)
	await get_tree().process_frame
	assert_eq(get_tree().is_quit_on_go_back(), quit_before)
	hud.bag_panel()
	hud._open_modal()
	await get_tree().process_frame
	assert_eq(get_tree().is_quit_on_go_back(), quit_before, "a centered choice keeps its previous back behavior")


func test_opening_releases_a_held_stick_and_consumes_its_lift() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	var at: Vector2 = hud.stick_home()
	_touch(hud, at, true)
	_drag(hud, at + Vector2(hud.STICK_R, 0.0))
	assert_ne(game.player.stick, Vector2.ZERO)
	hud.bag_panel()
	_assert_no_field_input(hud)
	_touch(hud, at, false)
	assert_true(hud.modal_open, "a preexisting finger cannot fold the new pane")
	assert_eq(hud.stick_tap_ms, -10000)
	hud._close_modal()
	_mouse(hud, at, false, true)
	_assert_no_field_input(hud)


func test_bag_stick_drag_keeps_player_and_clock_still() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	hud.bag_panel()
	await _settle()
	var at: Vector2 = hud.stick_home()
	var before: Vector3 = game.player.position
	var elapsed: float = game.clock.elapsed
	_touch(hud, at, true)
	_drag(hud, at + Vector2(hud.STICK_R, 0.0))
	game._process(0.1)
	assert_eq(game.player.position, before)
	assert_eq(game.clock.elapsed, elapsed)
	assert_true(game.paused)
	_touch(hud, at + Vector2(hud.STICK_R, 0.0), false)
	assert_true(hud.modal_open)
	_assert_no_field_input(hud)


func test_taking_runs_then_pauses_again_without_stick_input() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	var id: String = _start_take(game)
	assert_eq(game.player.action, "take")
	assert_eq(hud.taking_box, id)
	assert_false(game.paused)
	var elapsed: float = game.clock.elapsed
	game._process(0.05)
	assert_gt(game.clock.elapsed, elapsed)
	game.player.action_t = 0.001
	game._process(0.1)
	assert_eq(int(game.player.items.get("food_pack", 0)), 1)
	assert_true(hud.modal_open and game.paused)
	assert_eq(hud.taking_box, "")
	_assert_no_field_input(hud)


func test_app_away_stays_paused_even_if_the_taking_pane_closes() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	_start_take(game)
	assert_false(game.paused)
	game.interrupt()
	hud.tick(0.016)
	assert_true(game.paused)
	hud._close_modal()
	assert_true(game.paused, "closing cannot resume a background app")


## The coordinator's quality bars (HOQ): the bag comes in between 150 and 220 ms and
## goes in between 100 and 180 ms.
func test_hoq_bag_opens_in_150_to_220_ms_and_closes_in_100_to_180_ms() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	hud.bag_panel()
	var pane: GlassPane = hud.modal_pane
	pane.set_process(false)
	pane.motion_step(1.0 / 60.0)
	_steps(pane, 9)
	assert_true(pane.is_moving(), "still coming in at 150 ms (+ the frame it was built in)")
	assert_gt(pane.position.x, pane.resting_position().x + 0.5)
	_steps(pane, 3)
	assert_false(pane.is_moving(), "at rest at 200 ms (217 ms with the build frame)")
	assert_almost_eq(pane.position.x, pane.resting_position().x, 0.5)
	var old: Control = hud.modal
	pane.folded.emit()
	pane.set_process(false)
	_steps(pane, 6)
	assert_true(old.visible and not old.is_queued_for_deletion(), "still going out at 100 ms")
	_steps(pane, 4)
	assert_true(old.is_queued_for_deletion(), "gone by 167 ms")


## HOQ on a busy phone: a long frame after the build moves the slide by 50 ms at
## the most, so the pane never pops to its place.
func test_hoq_a_long_frame_does_not_skip_the_slide() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	hud.bag_panel()
	var pane: GlassPane = hud.modal_pane
	pane.set_process(false)
	pane.motion_step(0.5)
	pane.motion_step(0.5)
	assert_true(pane.is_moving())
	assert_gt(pane.position.x, pane.resting_position().x + 0.5)
	assert_lt(pane.position.x, hud._view_size().x - 0.5)


## HOQ: with the bag up, a held stick and a held finger on the attack pad move,
## swing and run the clock not at all; a finger held across the closing tap lifts
## into nothing.
func test_hoq_two_fingers_and_a_lift_after_closing_leak_nothing() -> void:
	var game: FieldGame = _game()
	var hud: FieldHud = game.hud
	var p = game.player
	hud.bag_panel()
	await _settle()
	var before: Vector3 = p.position
	var elapsed: float = game.clock.elapsed
	var stick: Vector2 = hud.stick_home()
	var attack: Vector2 = hud.attack_button.get_global_rect().get_center()
	_touch(hud, stick, true, 0)
	_drag(hud, stick + Vector2(hud.STICK_R, 0.0), 0)
	_touch(hud, attack, true, 1)
	for _i in range(3):
		game._process(0.1)
	assert_eq(p.position, before)
	assert_eq(game.clock.elapsed, elapsed)
	assert_eq(p.swing_t, 0.0)
	assert_false(p.hold_attack)
	assert_true(hud.modal_open)
	await get_tree().create_timer(0.4).timeout
	_touch(hud, attack, false, 1)
	_touch(hud, stick + Vector2(hud.STICK_R, 0.0), false, 0)
	assert_true(hud.modal_open, "long holds never fold the pane")
	# A finger on the attack pad, a short tap outside folds the pane, then that finger lifts.
	_touch(hud, attack, true, 2)
	var out: Vector2 = _outside(hud)
	_touch(hud, out, true, 3)
	_touch(hud, out, false, 3)
	assert_false(hud.modal_open)
	_touch(hud, attack, false, 2)
	for _i in range(3):
		game._process(0.1)
	assert_eq(p.swing_t, 0.0)
	assert_false(p.hold_attack)
	assert_eq(p.position, before)
	_assert_no_field_input(hud)
