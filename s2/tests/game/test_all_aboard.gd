extends "res://addons/gut/test.gd"
## One pad sends every companion back to the train (user 2026-10-11), in a
## drawer under a lever at the top middle with 따라와 and 대기 (user
## 2026-10-18, decision 408). The one-by-one 'retreat' order stays as it was.

const FieldGame = preload("res://game/field_game.gd")

var game
var hud


func _start(extra: Dictionary = {}) -> void:
	game = FieldGame.new()
	var opts := {"seed": 11, "raiders": false, "auto_pause": false}
	opts.merge(extra)
	game.opts = opts
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	hud = game.hud
	hud.tick(0.016)


func _allies() -> Array:
	return game.squad.filter(func(q) -> bool: return q != game.player)


func _press() -> void:
	hud.set_orders_open(true)
	var at: Vector2 = hud.all_aboard_button.get_global_rect().get_center()
	assert_true(hud.finger_down(3, at))
	hud.finger_up(3, at)


func test_one_press_sends_every_living_companion_to_the_train() -> void:
	_start()
	var allies := _allies()
	assert_gt(allies.size(), 1)
	var gone = allies[0]
	gone.body.dead = true
	gone.command = "wait"
	allies[1].brain["boarded"] = true
	var mine: String = game.player.command
	_press()
	for q in allies:
		if q == gone:
			assert_eq(q.command, "wait", "the dead are given no order")
		else:
			assert_eq(q.command, "retreat")
			assert_false(q.brain.get("boarded", false))
	assert_eq(game.player.command, mine, "the one you play is not a companion")


func test_the_work_crew_is_not_in_it() -> void:
	_start()
	_press()
	assert_false(game.ai.crew_recalled, "the crew has its own recall")


func test_it_works_with_a_thumb_on_the_stick_and_leaves_an_open_card_alone() -> void:
	_start()
	hud.finger_down(0, hud.stick_home())
	assert_eq(hud.stick_index, 0)
	_press()
	assert_eq(_allies()[0].command, "retreat", "a second finger takes it")
	assert_eq(hud.stick_index, 0, "the stick is still held")
	hud.finger_up(0, hud.stick_home())
	for q in _allies():
		q.command = "follow"
	hud.card("t", "고른다", [{"id": "a", "label": "하나"}], func(_c: String) -> void: pass)
	assert_true(hud.modal_open)
	hud._all_aboard()
	assert_true(hud.modal_open, "an open card is not shut by it")


func test_the_orders_sit_under_the_lever_at_the_top_middle_clear_of_every_other_key() -> void:
	_start()
	hud.context_button.visible = true
	hud.lamp_button.visible = true
	hud.blood_button.visible = true
	hud.crew_button.visible = true
	hud.set_orders_open(true)
	await get_tree().process_frame
	await get_tree().process_frame
	hud.tick(0.02)
	await get_tree().process_frame
	var view: Vector2 = hud._view_size()
	var lever: Rect2 = hud.lever_button.get_global_rect()
	# The lever at the very top middle (user 2026-10-18: 「가로 휴대폰 기준 정중앙 상단」).
	assert_almost_eq(lever.get_center().x, view.x * 0.5, 1.0, "the lever in the middle")
	assert_eq(lever.position.y, 0.0, "on the top edge")
	var orders: Array = [hud.all_aboard_button, hud.follow_button, hud.wait_button]
	for o: Button in orders:
		var r: Rect2 = o.get_global_rect()
		assert_true(Rect2(Vector2.ZERO, view).encloses(r), "on the screen")
		assert_gt(r.position.y, lever.end.y - 0.5, "under the lever")
		assert_lt(r.end.y, view.y * 0.25, "at the top")
		for b in hud.pads:
			if not orders.has(b):
				assert_false(r.intersects(b.get_global_rect()), "clear of " + b.text + b.tooltip_text)
		assert_false(r.intersects(hud.allies_box.get_global_rect()), "clear of the companions' row")
		assert_false(r.intersects(hud.portrait.get_global_rect()), "clear of the portrait")
		assert_false(r.intersects(hud.top_panel.get_global_rect()), "clear of the clock")
	assert_almost_eq(hud.all_aboard_button.get_global_rect().get_center().x, view.x * 0.5, 1.0, "'all aboard' in the middle")
	assert_null(hud.all_aboard_button.icon, "its word alone, no train mark")


func test_the_lever_folds_the_orders_and_a_tap_or_a_pull_opens_them() -> void:
	_start()
	await get_tree().process_frame
	hud.tick(0.02)
	assert_true(hud.lever_button.visible)
	assert_false(hud.orders_open, "folded to begin with")
	assert_false(hud.all_aboard_button.visible)
	var lever: Vector2 = hud.lever_button.get_global_rect().get_center()
	# A tap flips it.
	assert_true(hud.finger_down(2, lever))
	hud.finger_up(2, lever)
	assert_true(hud.orders_open)
	for b: Button in [hud.all_aboard_button, hud.follow_button, hud.wait_button]:
		assert_true(b.visible)
	hud.finger_down(2, lever)
	hud.finger_up(2, lever)
	assert_false(hud.orders_open, "a second tap folds them")
	assert_false(hud.follow_button.visible)
	# Pulled down it opens as the thumb goes; pushed up it folds.
	hud.finger_down(2, lever)
	hud.finger_move(2, lever + Vector2(0, 30))
	assert_true(hud.orders_open, "pulled down")
	hud.finger_up(2, lever + Vector2(0, 30))
	assert_true(hud.orders_open, "the lift does not flip it back")
	hud.finger_down(2, lever)
	hud.finger_move(2, lever + Vector2(0, -20))
	hud.finger_up(2, lever + Vector2(0, -20))
	assert_false(hud.orders_open, "pushed up")
	# Folded, its orders take no finger.
	var at: Vector2 = hud.all_aboard_button.get_global_rect().get_center()
	for b in hud.pads:
		if b.is_visible_in_tree():
			assert_false(b.get_global_rect().has_point(at), "nothing under it: " + b.tooltip_text)


func test_follow_and_wait_give_every_living_companion_that_order() -> void:
	_start()
	hud.set_orders_open(true)
	var allies := _allies()
	var gone = allies[0]
	gone.body.dead = true
	gone.command = "retreat"
	var mine: String = game.player.command
	for pair in [[hud.wait_button, "wait"], [hud.follow_button, "follow"]]:
		var at: Vector2 = (pair[0] as Button).get_global_rect().get_center()
		assert_true(hud.finger_down(3, at))
		hud.finger_up(3, at)
		for q in allies:
			assert_eq(q.command, "retreat" if q == gone else String(pair[1]), "the dead are given no order")
	assert_eq(game.player.command, mine, "the one you play is not a companion")
	assert_eq(hud.follow_button.text, "따라와")
	assert_eq(hud.wait_button.text, "대기")


func test_a_radio_call_however_long_keeps_to_the_message_column() -> void:
	_start()
	hud.set_orders_open(true)
	var view: Vector2 = hud._view_size()
	for words in ["무리가 역 쪽으로 접근 중!", "무리 근접! 곧 출발! 모두 열차로! 무리 근접! 곧 출발! 모두 열차로! 무리 근접! 곧 출발!"]:
		hud.radio(words)
		hud.tick(0.02)
		await get_tree().process_frame
		hud.tick(0.02)
		assert_true(hud.radio_pill.visible, words)
		var radio: Rect2 = hud.radio_pill.get_global_rect()
		assert_true(Rect2(Vector2.ZERO, view).encloses(radio), "on the screen: " + words)
		for b: Button in [hud.lever_button, hud.all_aboard_button, hud.follow_button, hud.wait_button]:
			assert_false(radio.intersects(b.get_global_rect()), "clear of the orders: " + words)
		assert_lt(radio.end.x, hud.status_pads[0].get_global_rect().position.x, "left of the state icons: " + words)
	assert_gt(hud.radio_label.get_line_count(), 1, "the long call wrapped")


func test_the_one_by_one_order_can_be_shown_as_to_the_train() -> void:
	_start()
	var row: Array = hud.COMMANDS.filter(func(c) -> bool: return c[0] == "retreat")[0]
	assert_eq(hud.command_word(row), "후퇴")
	game.opts["retreat_name"] = "train"
	assert_eq(hud.command_word(row), "열차로")
	assert_eq(hud.command_word(hud.COMMANDS[0]), "따라와", "the others keep their words")
