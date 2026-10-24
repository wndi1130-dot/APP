extends "res://addons/gut/test.gd"
## Where the field HUD's pieces sit (user 2026-10-18): the pause key and the
## clock on one row with the portrait under it, the clock folding to its time,
## RUN right over the stick, the state icons in one column, the test keys on
## the right with the goals' and promises' keys beside them, the companions'
## faces in the bottom middle with a card each, the work crew beside them, the
## movement and use keys see-through, edge arrows off the HUD, and no piece
## over another on a busy screen. The orders' lever: test_all_aboard.

const FieldGame = preload("res://game/field_game.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")

var game
var hud


func _start(extra: Dictionary = {}) -> void:
	game = FieldGame.new()
	var opts := {"seed": 5, "raiders": false, "auto_pause": false}
	opts.merge(extra)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	hud = game.hud
	await _settle()


func _settle() -> void:
	for i in 2:
		hud.tick(0.016)
		await get_tree().process_frame


func _shown_states() -> Array:
	return hud.status_pads.filter(func(b: Button) -> bool: return b.visible)


func test_the_pause_key_and_the_clock_share_one_row_and_the_portrait_sits_under_it() -> void:
	await _start()
	var pause: Rect2 = hud.pause_button.get_global_rect()
	var clock: Rect2 = hud.clock_pill.get_global_rect()
	assert_almost_eq(clock.size.y, hud.TOP_ROW_H, 1.0, "the clock's glass is the row's height")
	assert_almost_eq(pause.get_center().y, clock.get_center().y, 1.0, "one middle line")
	assert_lt(pause.end.x, clock.position.x + 0.5, "side by side")
	var face: Rect2 = hud.portrait.get_global_rect()
	assert_lt(face.position.x, 20.0, "the portrait at the left edge")
	assert_gt(face.position.y, maxf(clock.end.y, pause.end.y), "under the row")
	assert_almost_eq(face.position.y - clock.end.y, hud.PORTRAIT_GAP, 1.0, "right under it, with room")


func test_run_sits_right_over_the_stick_with_room() -> void:
	await _start()
	var run: Rect2 = hud.run_button.get_global_rect()
	var home: Vector2 = hud.stick_home()
	assert_almost_eq(run.get_center().x, home.x, 1.0, "on the stick's middle line")
	assert_almost_eq(run.end.y + 4.0 * hud.PX_PER_MM, home.y - hud.STICK_RING, 1.0, "its ring of nothing ends where the stick's ring begins")


func test_the_state_icons_keep_one_column_and_shrink_from_four() -> void:
	await _start()
	var p = game.player
	p.body.add_wound("arm_left", "deep", game.clock.elapsed)
	p.body.infection = "bite"
	p.body.window_left = 240.0
	hud.tick(0.016)
	var shown: Array = _shown_states()
	assert_eq(shown.size(), 2)
	assert_almost_eq(shown[0].get_global_rect().size.x, float(hud.status_diameter()), 0.5, "full size while few")
	p.body.arm_fracture = true
	p.body.exhaustion = 0.9
	hud.tick(0.016)
	shown = _shown_states()
	assert_gte(shown.size(), 4)
	var x: float = shown[0].get_global_rect().position.x
	for b: Button in shown:
		var r: Rect2 = b.get_global_rect()
		assert_almost_eq(r.size.x, roundf(hud.status_diameter() * hud.STATUS_SMALL), 0.5, "smaller from four")
		assert_almost_eq(r.position.x, x, 0.5, "one column")
	assert_lt(shown[-1].get_global_rect().end.y, hud.crouch_button.get_global_rect().position.y, "above the crouch key")
	var span: Vector2 = hud._message_span()
	assert_almost_eq(span.y, hud._view_size().x + hud.STATUS_AT.x - hud.status_diameter() - UiFonts.px(hud.MESSAGE_GAP), 0.5, "the notes do not move as the icons shrink")


func test_the_test_keys_hug_the_right_edge_and_step_aside_for_the_gear() -> void:
	await _start()
	var view: Vector2 = hud._view_size()
	var keys: Rect2 = hud.test_keys.get_global_rect()
	assert_almost_eq(keys.end.x, view.x + hud.STATUS_AT.x, 1.0, "against the right edge")
	assert_lt(keys.end.y, hud.STATUS_AT.y + 0.5, "over the state icons")
	var a: Rect2 = hud.test_keys.get_child(0).get_global_rect()
	var b: Rect2 = hud.test_keys.get_child(1).get_global_rect()
	assert_almost_eq(b.position.x - a.end.x, 8.0, 0.5, "the gap kept")
	game.paused = true
	await _settle()
	assert_true(hud.settings_button.visible)
	assert_false(hud.test_keys.get_global_rect().intersects(hud.settings_button.get_global_rect()), "a step left of the gear")
	game.paused = false


func test_a_tap_on_the_clock_opens_the_day_and_the_weather_and_folds_them() -> void:
	await _start()
	# Folded to its time (user 2026-10-18: 「시계도 클릭으로 펼칠 수 있게」).
	assert_false(hud.clock_open)
	assert_false(hud.day_label.visible or hud.weather_label.visible)
	var narrow: float = hud.clock_pill.get_global_rect().size.x
	var at: Vector2 = hud.clock_pill.get_global_rect().get_center()
	assert_true(hud.finger_down(4, at))
	hud.finger_up(4, at)
	assert_true(hud.clock_open)
	assert_true(hud.day_label.visible and hud.weather_label.visible)
	await _settle()
	assert_gt(hud.clock_pill.get_global_rect().size.x, narrow + 40.0, "wider with the day and the weather")
	at = hud.clock_pill.get_global_rect().get_center()
	hud.finger_down(4, at)
	hud.finger_up(4, at)
	assert_false(hud.clock_open)
	await _settle()
	assert_almost_eq(hud.clock_pill.get_global_rect().size.x, narrow, 1.0, "back to its time")


func test_the_goals_and_the_promises_fold_to_keys_left_of_the_view_keys() -> void:
	await _start({"mission": "survey", "goal_line": true, "promises": [{"kind": "prologue", "subjects": ["a", "b"]}]})
	# On the clock's row a step left of the view keys (user 2026-10-18: 「시점
	# 조절 버튼 좌측에 바깥 설비 쪽 버튼」), the goals' key next to them.
	assert_true(hud.goal_key.visible and hud.promise_key.visible)
	var keys: Rect2 = hud.test_keys.get_global_rect()
	var fold: Rect2 = hud.fold_keys.get_global_rect()
	assert_almost_eq(fold.get_center().y, keys.get_center().y, 1.0, "one row")
	assert_almost_eq(keys.position.x - fold.end.x, 8.0, 0.5, "a step left of the view keys")
	assert_gt(hud.goal_key.get_global_rect().position.x, hud.promise_key.get_global_rect().position.x, "the goals' key next to them")
	# Both lines are up to begin with (「약속도 펼치거나 닫을 수 있도록」); a tap
	# on a key lets its line down and lights the key, a tap on the line takes
	# it up again.
	var goal: Control = hud.goal_label.get_parent()
	var glass: Control = hud.promise_label.get_parent()
	assert_false(goal.visible or glass.visible)
	var at: Vector2 = hud.promise_key.get_global_rect().get_center()
	assert_true(hud.finger_down(3, at))
	hud.finger_up(3, at)
	assert_true(hud.promise_open)
	assert_true(glass.visible, "let down")
	assert_true(hud.promise_key.button_pressed, "its key lit")
	assert_eq(hud.promise_label.get_theme_font_size("font_size"), UiFonts.size(10.5), "small")
	assert_eq(hud.promise_label.text.replace(UiFonts.WORD_JOINER, ""), "약속: 서막 2명 데려오기")
	await _settle()
	var line: Vector2 = glass.get_global_rect().get_center()
	assert_true(hud.finger_down(4, line))
	hud.finger_up(4, line)
	assert_false(hud.promise_open)
	assert_false(glass.visible, "taken up")
	assert_false(hud.promise_key.button_pressed)
	at = hud.goal_key.get_global_rect().get_center()
	hud.finger_down(3, at)
	hud.finger_up(3, at)
	assert_true(goal.visible, "the goals the same way")
	hud.set_promises([])
	assert_false(hud.promise_key.visible, "no promise, no key")


func test_the_companions_are_faces_in_the_bottom_middle_and_a_tap_shows_their_card() -> void:
	await _start()
	var n: int = hud.ally_buttons.size()
	assert_gt(n, 0)
	var view: Vector2 = hud._view_size()
	# The middle one under the screen's middle, at its foot (user 2026-10-18:
	# 「가장 가운데 동료가 화면 정중앙 하단 중앙」).
	var row: Rect2 = hud.allies_box.get_global_rect()
	assert_almost_eq(row.get_center().x, view.x * 0.5, 1.0, "the row's middle on the screen's")
	if n % 2 == 1:
		var mid: Rect2 = (hud.ally_buttons[n / 2]["b"] as Control).get_global_rect()
		assert_almost_eq(mid.get_center().x, view.x * 0.5, 1.0, "the middle face in the middle")
	assert_gt(row.position.y, view.y * 0.8, "at the foot")
	# Their words hidden till a tap (「가릴 때는 안 보이게, 클릭하면 보일 수 있게」).
	for r in hud.ally_buttons:
		assert_false((r["card"] as Control).visible)
	var face: Control = hud.ally_buttons[0]["b"]
	var card: Control = hud.ally_buttons[0]["card"]
	var at: Vector2 = face.get_global_rect().get_center()
	assert_true(hud.finger_down(3, at))
	hud.finger_up(3, at)
	await _settle()
	assert_true(card.visible, "a tap shows the card")
	var c: Rect2 = card.get_global_rect()
	assert_lt(c.end.y, face.get_global_rect().position.y, "over the face")
	assert_eq(hud.ally_buttons[0]["name"].text, hud.ally_buttons[0]["p"].display_name)
	var stick := Rect2(hud.stick_home() - Vector2.ONE * hud.STICK_RING, Vector2.ONE * hud.STICK_RING * 2.0)
	assert_false(c.intersects(stick), "clear of the stick")
	if n > 1:
		var other: Control = hud.ally_buttons[1]["b"]
		hud.finger_down(3, other.get_global_rect().get_center())
		hud.finger_up(3, other.get_global_rect().get_center())
		assert_false(card.visible, "one card at a time")
		assert_true((hud.ally_buttons[1]["card"] as Control).visible)
		hud.finger_down(3, other.get_global_rect().get_center())
		hud.finger_up(3, other.get_global_rect().get_center())
		assert_false((hud.ally_buttons[1]["card"] as Control).visible, "a second tap hides it")
	# A tap on an open card: the companion's orders and state.
	hud._toggle_card(0)
	await _settle()
	at = card.get_global_rect().get_center()
	hud.finger_down(3, at)
	hud.finger_up(3, at)
	assert_true(hud.modal_open, "their orders and state")
	assert_false(card.visible, "the card folds as they open")
	hud._close_modal()


func test_the_movement_and_use_keys_are_see_through_and_the_orders_matte() -> void:
	await _start()
	# 「Run 과 같은 플레이어 이동과 상호작용 버튼은 반투명하게 … 출발과 밑에
	# 있는 버튼도」 (user 2026-10-18).
	for b: Button in [hud.run_button, hud.lamp_button, hud.crouch_button, hud.shove_button, hud.attack_button, hud.aim_button, hud.context_button, hud.depart_button]:
		var plate = b.get_theme_stylebox("normal")
		assert_almost_eq(plate.dim, hud.PAD_SEE, 0.001, "see-through: " + b.tooltip_text + b.text)
		assert_false(plate.over_ring, "no warm ground under its glass: " + b.tooltip_text + b.text)
	# 「따라와 대기 에 유광효과가 관측된다」: plain glass, no brass sweep.
	for b: Button in [hud.follow_button, hud.wait_button, hud.all_aboard_button]:
		assert_false(b.get_theme_stylebox("normal").brass_rim, b.text)


func test_the_crew_chip_stands_right_beside_the_companions() -> void:
	await _start()
	game.actions.work_started = true
	await _settle()
	assert_true(hud.crew_button.visible)
	var row: Rect2 = hud.allies_box.get_global_rect()
	var crew: Rect2 = hud.crew_button.get_global_rect()
	assert_almost_eq(crew.position.y, row.position.y, 0.5, "on the row")
	assert_gt(crew.position.x, row.end.x, "right of the companions")
	assert_lt(crew.position.x - row.end.x, 24.0, "right beside them")
	assert_gt(row.position.x, hud.stick_home().x + hud.STICK_RING, "clear of the stick's ring")
	for b in hud.pads:
		if b.is_visible_in_tree():
			assert_false(crew.intersects(b.get_global_rect()), "clear of " + b.text + b.tooltip_text)


func test_an_edge_arrow_slides_in_off_the_hud() -> void:
	await _start()
	var view: Vector2 = hud._view_size()
	var center: Vector2 = view * 0.5
	var east: Vector3 = game.screen_to_ground(center + Vector2(view.x, 0.0))
	# A horde's arrow shows its sound mark, no word (user 2026-10-18).
	var free: Vector2 = hud.edge_tip(center, view, east, "")
	assert_gt(free.x, view.x - 60.0, "at the edge with nothing in the way")
	var strip := Rect2(view.x - 120.0, 0.0, 120.0, view.y)
	var kept: Array[Rect2] = [strip]
	var tip: Vector2 = hud.edge_tip(center, view, east, "", kept)
	assert_lt(tip.x + 16.0, strip.position.x, "in off what covers the edge")
	assert_false(hud.hud_rects().is_empty())


## Every piece the HUD shows, by name (the orders open, the crew there).
func _pieces() -> Array:
	var rows: Array = []
	for b: Button in hud.pads:
		if b.is_visible_in_tree():
			rows.append([b.tooltip_text + b.text, b.get_global_rect()])
	for k: Control in hud.test_keys.get_children():
		rows.append(["test " + (k as Button).text, k.get_global_rect()])
	for k: Control in hud.fold_keys.get_children():
		if k.visible:
			rows.append(["fold " + (k as Button).tooltip_text, k.get_global_rect()])
	if hud.radio_pill.visible:
		rows.append(["radio", hud.radio_pill.get_global_rect()])
	var i := 0
	for t: Control in hud.toast_box.get_children():
		rows.append(["note%d" % i, t.get_global_rect()])
		i += 1
	for c: Control in hud.info_box.get_children():
		if c.visible:
			rows.append(["line%d" % c.get_index(), c.get_global_rect()])
	rows.append(["portrait", hud.portrait.get_global_rect()])
	rows.append(["bag", hud.bag_box.get_global_rect()])
	rows.append(["clock", hud.top_panel.get_global_rect()])
	var j := 0
	for row in hud.ally_buttons:
		rows.append(["ally%d" % j, (row["b"] as Control).get_global_rect()])
		j += 1
	if hud.crew_button.visible:
		rows.append(["crew", hud.crew_button.get_global_rect()])
	for row in hud.ally_buttons:
		if (row["card"] as Control).visible:
			rows.append(["card", (row["card"] as Control).get_global_rect()])
	var home: Vector2 = hud.stick_home()
	rows.append(["stick", Rect2(home - Vector2.ONE * hud.STICK_RING, Vector2.ONE * hud.STICK_RING * 2.0)])
	return rows


func test_a_busy_screen_has_no_two_pieces_over_each_other() -> void:
	await _start({"mission": "survey", "goal_line": true, "promises": [{"kind": "prologue", "subjects": ["a", "b"]}]})
	var p = game.player
	p.body.add_wound("arm_left", "deep", game.clock.elapsed)
	p.items["bandage"] = 2
	p.body.infection = "bite"
	p.body.window_left = 240.0
	p.body.arm_fracture = true
	p.body.exhaustion = 0.9
	game.clock.elapsed = (950.0 - 630.0) * 60.0 / 15.0
	game.actions.work_started = true
	hud.set_orders_open(true)
	# Everything that folds, open: the clock, the goals, the promises, a card.
	hud.set_clock_open(true)
	hud.set_goal_open(true)
	hud.set_promise_open(true)
	hud._toggle_card(hud.ally_buttons.size() / 2)
	hud.radio("무리 근접! 곧 출발! 모두 열차로!")
	hud.toast("등불 켬 · 1분마다 불빛 들킴")
	hud.toast("저장 실패 · 기기 공간 부족 · 눌러서 닫기", hud.TOAST_WARN)
	await _settle()
	await _settle()
	assert_true(hud.lamp_button.visible, "after dark: the lamp key too")
	assert_gte(_shown_states().size(), 4)
	var rows: Array = _pieces()
	var view := Rect2(Vector2.ZERO, hud._view_size())
	for a in rows.size():
		var ra: Rect2 = rows[a][1]
		assert_true(view.encloses(ra), "%s on the screen" % rows[a][0])
		for b in range(a + 1, rows.size()):
			var x: Rect2 = ra.intersection(rows[b][1])
			assert_false(x.size.x > 0.5 and x.size.y > 0.5, "%s over %s" % [rows[a][0], rows[b][0]])
